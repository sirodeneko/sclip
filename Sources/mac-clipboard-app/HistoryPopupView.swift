import AppKit
import Carbon.HIToolbox
import SwiftUI

struct HistoryPopupView: View {
    @ObservedObject var store: ClipboardHistoryStore
    let openToken: Int
    var onSelect: (ClipboardHistoryEntry) -> Void
    @ObservedObject private var i18n = LocalizationCenter.shared

    @State private var query: String = ""
    @State private var selectionIndex: Int?
    @State private var searchVisible = false
    @State private var shouldFocusSearch = false

    private var filtered: [ClipboardHistoryEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return store.entries }
        return store.entries.filter { entry in
            (entry.previewText ?? "").localizedCaseInsensitiveContains(q)
            || (entry.sourceAppBundleIdentifier ?? "").localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                header
                list
            }
            .padding(12)
        }
        .frame(width: 520, height: 360)
        .background(KeyListenerView(shouldBeFirstResponder: !searchVisible) { event in
            handleKeyDown(event)
        })
        .onChange(of: query) { _ in
            ensureSelection()
        }
        .onChange(of: store.entries.count) { _ in
            ensureSelection()
        }
        .onChange(of: openToken) { _ in
            query = ""
            selectionIndex = nil
            searchVisible = false
            shouldFocusSearch = false
            DispatchQueue.main.async {
                ensureSelection()
            }
        }
        .onAppear {
            ensureSelection()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("\(store.entries.count)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                )
            Spacer()
            if searchVisible {
                SearchFieldView(text: $query, shouldFocus: $shouldFocusSearch)
                    .frame(width: 200)
            }
            Button("") {
                showSearch()
            }
            .keyboardShortcut("f", modifiers: .command)
            .buttonStyle(.plain)
            .frame(width: 0, height: 0)
            .opacity(0.01)
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, entry in
                        HistoryRow(entry: entry, store: store, isSelected: selectionIndex == index)
                            .id(entry.id)
                            .onTapGesture {
                                selectionIndex = index
                                onSelect(entry)
                            }
                    }
                }
            }
            .onChange(of: selectionIndex) { _ in
                guard let selectionIndex, selectionIndex >= 0, selectionIndex < filtered.count else { return }
                withAnimation(.easeOut(duration: 0.08)) {
                    proxy.scrollTo(filtered[selectionIndex].id, anchor: .center)
                }
            }
        }
        .id(openToken)
    }

    private func ensureSelection() {
        if filtered.isEmpty {
            selectionIndex = nil
            return
        }
        if let selectionIndex, selectionIndex < filtered.count {
            return
        }
        selectionIndex = 0
    }

    private func showSearch() {
        searchVisible = true
        shouldFocusSearch = true
        DispatchQueue.main.async {
            shouldFocusSearch = true
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), event.keyCode == UInt16(kVK_ANSI_F) {
            showSearch()
            return true
        }
        if event.keyCode == UInt16(kVK_UpArrow) {
            moveSelection(-1)
            return true
        }
        if event.keyCode == UInt16(kVK_DownArrow) {
            moveSelection(1)
            return true
        }
        if event.keyCode == UInt16(kVK_Return) {
            if let selectionIndex, selectionIndex < filtered.count {
                onSelect(filtered[selectionIndex])
            }
            return true
        }
        return false
    }

    private func moveSelection(_ delta: Int) {
        guard !filtered.isEmpty else {
            selectionIndex = nil
            return
        }
        let current = selectionIndex ?? 0
        let next = min(max(current + delta, 0), filtered.count - 1)
        selectionIndex = next
    }
}

private struct HistoryRow: View {
    let entry: ClipboardHistoryEntry
    let store: ClipboardHistoryStore
    let isSelected: Bool
    @State private var hovering: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(kindLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.primary.opacity(0.07))
                        )

                    if let bundle = entry.sourceAppBundleIdentifier {
                        Text(bundle)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Text(entry.createdAt, style: .time)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .onHover { hovering = $0 }
    }

    private var backgroundColor: Color {
        if isSelected { return Color.primary.opacity(0.16) }
        if hovering { return Color.primary.opacity(0.09) }
        return Color.primary.opacity(0.05)
    }

    private var borderColor: Color {
        if isSelected { return Color.primary.opacity(0.2) }
        return Color.primary.opacity(0.08)
    }

    private var titleText: String {
        let unknown = L("popup.unknown_content")
        let text = (entry.previewText ?? unknown).trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return unknown }
        return text.replacingOccurrences(of: "\n", with: " ")
    }

    private var kindLabel: String {
        for item in entry.items {
            if item.representationsByType[NSPasteboard.PasteboardType.png.rawValue] != nil { return L("kind.image") }
            if item.representationsByType[NSPasteboard.PasteboardType.tiff.rawValue] != nil { return L("kind.image") }
            if item.representationsByType[NSPasteboard.PasteboardType("public.file-url").rawValue] != nil { return L("kind.file") }
        }
        return L("kind.text")
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = store.thumbnailImage(for: entry, maxSize: 36) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.07))
                Text("T")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .frame(width: 36, height: 36)
        }
    }
}

private struct KeyListenerView: NSViewRepresentable {
    let shouldBeFirstResponder: Bool
    let onKeyDown: (NSEvent) -> Bool

    func makeNSView(context: Context) -> KeyListenerNSView {
        let view = KeyListenerNSView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: KeyListenerNSView, context: Context) {
        nsView.onKeyDown = onKeyDown
        if shouldBeFirstResponder, let window = nsView.window, window.firstResponder !== nsView {
            window.makeFirstResponder(nsView)
        }
    }
}

private final class KeyListenerNSView: NSView {
    var onKeyDown: ((NSEvent) -> Bool)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) == true { return }
        super.keyDown(with: event)
    }
}

@MainActor
private struct SearchFieldView: NSViewRepresentable {
    @Binding var text: String
    @Binding var shouldFocus: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, shouldFocus: $shouldFocus)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let field = SclipSearchField()
        field.placeholderString = L("popup.search_placeholder")
        field.sendsSearchStringImmediately = true
        field.delegate = context.coordinator
        context.coordinator.attach(field)
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        let placeholder = L("popup.search_placeholder")
        if nsView.placeholderString != placeholder {
            nsView.placeholderString = placeholder
        }
        let isEditing = nsView.currentEditor() != nil
        if !isEditing, nsView.stringValue != text {
            nsView.stringValue = text
        }
        context.coordinator.tryFocusIfNeeded()
        if let editor = nsView.currentEditor() as? NSTextView {
            let all = editor.string.count
            if all > 0, editor.selectedRange.length == all, context.coordinator.wasProgrammaticUpdateRecently {
                editor.setSelectedRange(NSRange(location: all, length: 0))
            }
        }
    }

    private final class SclipSearchField: NSSearchField {
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            if event.modifierFlags.contains(.command),
               let chars = event.charactersIgnoringModifiers?.lowercased() {
                switch chars {
                case "a":
                    return NSApp.sendAction(#selector(NSTextView.selectAll(_:)), to: nil, from: self)
                case "x":
                    return NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
                case "c":
                    return NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
                case "v":
                    return NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
                default:
                    break
                }
            }
            return super.performKeyEquivalent(with: event)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var text: Binding<String>
        var shouldFocus: Binding<Bool>
        private var pending: DispatchWorkItem?
        private var lastProgrammaticUpdateAt: CFTimeInterval = 0
        private weak var field: NSSearchField?
        private var focusAttempts: Int = 0

        init(text: Binding<String>, shouldFocus: Binding<Bool>) {
            self.text = text
            self.shouldFocus = shouldFocus
        }

        var wasProgrammaticUpdateRecently: Bool {
            (CACurrentMediaTime() - lastProgrammaticUpdateAt) < 0.45
        }

        func attach(_ field: NSSearchField) {
            self.field = field
        }

        func tryFocusIfNeeded() {
            guard shouldFocus.wrappedValue else { return }
            guard let field else { return }
            guard focusAttempts < 20 else { return }

            if let window = field.window {
                window.makeFirstResponder(field)
                field.selectText(nil)
                if let editor = field.currentEditor() as? NSTextView {
                    editor.selectAll(nil)
                }
                shouldFocus.wrappedValue = false
                focusAttempts = 0
                return
            }

            focusAttempts += 1
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 30_000_000)
                self?.tryFocusIfNeeded()
            }
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSSearchField else { return }
            let next = field.stringValue
            pending?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.lastProgrammaticUpdateAt = CACurrentMediaTime()
                self?.text.wrappedValue = next
            }
            pending = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        }
    }
}
