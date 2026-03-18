import Foundation

struct ClipboardHistoryEntry: Codable, Identifiable, Hashable {
    struct StoredRepresentation: Codable, Hashable {
        var fileName: String
        var size: Int
    }

    struct StoredPasteboardItem: Codable, Hashable {
        var representationsByType: [String: StoredRepresentation]
    }

    var id: UUID
    var createdAt: Date
    var sourceAppBundleIdentifier: String?
    var previewText: String?
    var signature: String
    var items: [StoredPasteboardItem]
}

