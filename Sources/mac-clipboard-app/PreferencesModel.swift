import Carbon.HIToolbox
import Foundation

@MainActor
final class PreferencesModel: ObservableObject {
    @Published var hotKey: HotKeyManager.HotKey {
        didSet { saveHotKey() }
    }

    @Published var autoPasteAfterSelection: Bool {
        didSet { UserDefaults.standard.set(autoPasteAfterSelection, forKey: Keys.autoPaste) }
    }

    @Published var historyLimit: Int {
        didSet { UserDefaults.standard.set(historyLimit, forKey: Keys.historyLimit) }
    }

    @Published var enableCopyFilePath: Bool {
        didSet { UserDefaults.standard.set(enableCopyFilePath, forKey: Keys.enableCopyFilePath) }
    }

    @Published var hScrollLeft: HotKeyManager.HotKey {
        didSet { saveHotKey(hScrollLeft, keyCodeKey: Keys.hScrollLeftKeyCode, modifiersKey: Keys.hScrollLeftModifiers) }
    }

    @Published var hScrollRight: HotKeyManager.HotKey {
        didSet { saveHotKey(hScrollRight, keyCodeKey: Keys.hScrollRightKeyCode, modifiersKey: Keys.hScrollRightModifiers) }
    }

    init() {
        self.hotKey = Self.loadHotKey(keyCodeKey: Keys.hotKeyKeyCode, modifiersKey: Keys.hotKeyModifiers)
            ?? .init(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey))
        self.autoPasteAfterSelection = UserDefaults.standard.object(forKey: Keys.autoPaste) as? Bool ?? true
        let savedLimit = UserDefaults.standard.object(forKey: Keys.historyLimit) as? Int
        self.historyLimit = max(1, savedLimit ?? 500)
        self.enableCopyFilePath = UserDefaults.standard.object(forKey: Keys.enableCopyFilePath) as? Bool ?? false
        self.hScrollLeft = Self.loadHotKey(keyCodeKey: Keys.hScrollLeftKeyCode, modifiersKey: Keys.hScrollLeftModifiers)
            ?? .init(keyCode: UInt32(kVK_LeftArrow), modifiers: UInt32(shiftKey))
        self.hScrollRight = Self.loadHotKey(keyCodeKey: Keys.hScrollRightKeyCode, modifiersKey: Keys.hScrollRightModifiers)
            ?? .init(keyCode: UInt32(kVK_RightArrow), modifiers: UInt32(shiftKey))
    }

    private enum Keys {
        static let hotKeyKeyCode = "hotKey.keyCode"
        static let hotKeyModifiers = "hotKey.modifiers"
        static let autoPaste = "autoPasteAfterSelection"
        static let historyLimit = "clipboardHistory.maxEntries"
        static let enableCopyFilePath = "settings.enableCopyFilePath"
        // v2 keys: defaults changed to Shift+arrows; old cmd+arrow saves ignored.
        static let hScrollLeftKeyCode = "hscroll2.left.keyCode"
        static let hScrollLeftModifiers = "hscroll2.left.modifiers"
        static let hScrollRightKeyCode = "hscroll2.right.keyCode"
        static let hScrollRightModifiers = "hscroll2.right.modifiers"
    }

    private static func loadHotKey(keyCodeKey: String, modifiersKey: String) -> HotKeyManager.HotKey? {
        let keyCode = UserDefaults.standard.object(forKey: keyCodeKey) as? Int
        let modifiers = UserDefaults.standard.object(forKey: modifiersKey) as? Int
        guard let keyCode, let modifiers else { return nil }
        return .init(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers))
    }

    private func saveHotKey() {
        saveHotKey(hotKey, keyCodeKey: Keys.hotKeyKeyCode, modifiersKey: Keys.hotKeyModifiers)
    }

    private func saveHotKey(_ hotKey: HotKeyManager.HotKey, keyCodeKey: String, modifiersKey: String) {
        UserDefaults.standard.set(Int(hotKey.keyCode), forKey: keyCodeKey)
        UserDefaults.standard.set(Int(hotKey.modifiers), forKey: modifiersKey)
    }
}
