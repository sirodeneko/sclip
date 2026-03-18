import AppKit
import Foundation

@MainActor
final class ClipboardHistoryStore: ObservableObject {
    @Published private(set) var entries: [ClipboardHistoryEntry] = []

    private var maxEntries: Int

    init(maxEntries: Int = 500) {
        self.maxEntries = max(1, maxEntries)
    }

    func loadFromDisk() {
        entries = readAllEntriesFromDisk()
    }

    func addSnapshot(from pasteboardItems: [NSPasteboardItem], sourceAppBundleIdentifier: String?) {
        guard let entry = persistEntry(from: pasteboardItems, sourceAppBundleIdentifier: sourceAppBundleIdentifier) else { return }
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            let overflow = Array(entries.suffix(from: maxEntries))
            entries.removeLast(entries.count - maxEntries)
            deleteFromDisk(entries: overflow)
        }
    }

    func updateMaxEntries(_ value: Int) {
        let next = max(1, value)
        maxEntries = next
        if entries.count > next {
            let overflow = Array(entries.suffix(from: next))
            entries.removeLast(entries.count - next)
            deleteFromDisk(entries: overflow)
        }
    }

    func delete(_ entry: ClipboardHistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        deleteFromDisk(entries: [entry])
    }

    func clearAll() {
        let existing = entries
        entries = []
        deleteFromDisk(entries: existing)
    }

    func writeEntryToPasteboard(_ entry: ClipboardHistoryEntry) {
        let pb = NSPasteboard.general
        pb.clearContents()

        let pbItems: [NSPasteboardItem] = entry.items.compactMap { storedItem in
            let pbItem = NSPasteboardItem()
            for (type, rep) in storedItem.representationsByType {
                guard let data = loadData(entryID: entry.id, fileName: rep.fileName) else { continue }
                pbItem.setData(data, forType: NSPasteboard.PasteboardType(type))
            }
            return pbItem
        }

        pb.writeObjects(pbItems)
    }

    func thumbnailImage(for entry: ClipboardHistoryEntry, maxSize: CGFloat) -> NSImage? {
        guard let rep = firstImageRepresentation(in: entry) else { return nil }
        guard let data = loadData(entryID: entry.id, fileName: rep.fileName) else { return nil }
        guard let image = NSImage(data: data) else { return nil }
        return image.resizedToFit(maxSize: maxSize)
    }

    private func readAllEntriesFromDisk() -> [ClipboardHistoryEntry] {
        do {
            let historyDir = try AppPaths.historyDirectory()
            let contents = (try? FileManager.default.contentsOfDirectory(at: historyDir, includingPropertiesForKeys: nil)) ?? []
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let entries: [ClipboardHistoryEntry] = contents.compactMap { entryDir in
                let manifestURL = entryDir.appendingPathComponent("manifest.json", isDirectory: false)
                guard let data = try? Data(contentsOf: manifestURL) else { return nil }
                return try? decoder.decode(ClipboardHistoryEntry.self, from: data)
            }
            return entries.sorted { $0.createdAt > $1.createdAt }
        } catch {
            return []
        }
    }

    private func persistEntry(from pasteboardItems: [NSPasteboardItem], sourceAppBundleIdentifier: String?) -> ClipboardHistoryEntry? {
        guard !pasteboardItems.isEmpty else { return nil }

        let preferredTypes: [NSPasteboard.PasteboardType] = [
            .string,
            .rtf,
            .html,
            .png,
            .tiff,
            NSPasteboard.PasteboardType("public.file-url"),
        ]

        let signature = computeSignature(items: pasteboardItems, preferredTypes: preferredTypes)

        if let latest = entries.first, latest.signature == signature {
            return nil
        }

        let id = UUID()
        let createdAt = Date()

        do {
            let entryDir = try AppPaths.historyDirectory().appendingPathComponent(id.uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: entryDir, withIntermediateDirectories: true)

            var storedItems: [ClipboardHistoryEntry.StoredPasteboardItem] = []

            for (index, item) in pasteboardItems.enumerated() {
                var reps: [String: ClipboardHistoryEntry.StoredRepresentation] = [:]
                for type in item.types {
                    guard let data = item.data(forType: type) else { continue }
                    let fileName = makeFileName(itemIndex: index, type: type.rawValue, data: data)
                    let fileURL = entryDir.appendingPathComponent(fileName, isDirectory: false)
                    do {
                        try data.write(to: fileURL, options: [.atomic])
                        reps[type.rawValue] = .init(fileName: fileName, size: data.count)
                    } catch {
                        continue
                    }
                }
                if !reps.isEmpty {
                    storedItems.append(.init(representationsByType: reps))
                }
            }

            guard !storedItems.isEmpty else {
                try? FileManager.default.removeItem(at: entryDir)
                return nil
            }

            let preview = makePreviewText(from: pasteboardItems.first, preferredTypes: preferredTypes)
            let entry = ClipboardHistoryEntry(
                id: id,
                createdAt: createdAt,
                sourceAppBundleIdentifier: sourceAppBundleIdentifier,
                previewText: preview,
                signature: signature,
                items: storedItems
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let manifest = try encoder.encode(entry)
            try manifest.write(to: entryDir.appendingPathComponent("manifest.json"), options: [.atomic])

            return entry
        } catch {
            return nil
        }
    }

    private func firstImageRepresentation(in entry: ClipboardHistoryEntry) -> ClipboardHistoryEntry.StoredRepresentation? {
        for item in entry.items {
            if let rep = item.representationsByType[NSPasteboard.PasteboardType.png.rawValue] {
                return rep
            }
            if let rep = item.representationsByType[NSPasteboard.PasteboardType.tiff.rawValue] {
                return rep
            }
        }
        return nil
    }

    private func deleteFromDisk(entries: [ClipboardHistoryEntry]) {
        do {
            let historyDir = try AppPaths.historyDirectory()
            for entry in entries {
                let dir = historyDir.appendingPathComponent(entry.id.uuidString, isDirectory: true)
                try? FileManager.default.removeItem(at: dir)
            }
        } catch {
            return
        }
    }

    private func loadData(entryID: UUID, fileName: String) -> Data? {
        do {
            let dir = try AppPaths.historyDirectory().appendingPathComponent(entryID.uuidString, isDirectory: true)
            return try Data(contentsOf: dir.appendingPathComponent(fileName))
        } catch {
            return nil
        }
    }

    private func makeFileName(itemIndex: Int, type: String, data: Data) -> String {
        let typeKey = safeFileComponent(type)
        let digest = Hashing.sha256Base64(data.prefix(1024))
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
        return "\(itemIndex)_\(typeKey)_\(digest.prefix(12)).bin"
    }

    private func safeFileComponent(_ input: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let mapped = input.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let s = String(mapped)
        if s.isEmpty { return "type" }
        return String(s.prefix(64))
    }

    private func computeSignature(items: [NSPasteboardItem], preferredTypes: [NSPasteboard.PasteboardType]) -> String {
        var accumulator = Data()

        for item in items {
            let types = item.types
            let typeStrings = types.map(\.rawValue).sorted()
            for t in typeStrings {
                accumulator.append(contentsOf: t.utf8)
                accumulator.append(0)
            }

            var hashed = false
            for preferred in preferredTypes {
                if types.contains(preferred), let data = item.data(forType: preferred) {
                    accumulator.append(data.prefix(1_048_576))
                    hashed = true
                    break
                }
            }

            if !hashed, let firstType = types.first, let data = item.data(forType: firstType) {
                accumulator.append(data.prefix(1_048_576))
            }
        }

        return Hashing.sha256Base64(accumulator)
    }

    private func makePreviewText(from item: NSPasteboardItem?, preferredTypes: [NSPasteboard.PasteboardType]) -> String? {
        guard let item else { return nil }

        if let s = item.string(forType: .string), !s.isEmpty {
            return s
        }

        if let rtfData = item.data(forType: .rtf) {
            if let attr = try? NSAttributedString(data: rtfData, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
                let s = attr.string.trimmingCharacters(in: .whitespacesAndNewlines)
                return s.isEmpty ? nil : s
            }
        }

        if let htmlData = item.data(forType: .html) {
            if let attr = try? NSAttributedString(data: htmlData, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
                let s = attr.string.trimmingCharacters(in: .whitespacesAndNewlines)
                return s.isEmpty ? nil : s
            }
        }

        if item.data(forType: .png) != nil || item.data(forType: .tiff) != nil {
            return L("kind.image")
        }

        return nil
    }
}
