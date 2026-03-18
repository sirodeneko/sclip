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

    init() {
        self.hotKey = Self.loadHotKey() ?? .init(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey))
        self.autoPasteAfterSelection = UserDefaults.standard.object(forKey: Keys.autoPaste) as? Bool ?? true
        let savedLimit = UserDefaults.standard.object(forKey: Keys.historyLimit) as? Int
        self.historyLimit = max(1, savedLimit ?? 500)
    }

    private enum Keys {
        static let hotKeyKeyCode = "hotKey.keyCode"
        static let hotKeyModifiers = "hotKey.modifiers"
        static let autoPaste = "autoPasteAfterSelection"
        static let historyLimit = "clipboardHistory.maxEntries"
    }

    private static func loadHotKey() -> HotKeyManager.HotKey? {
        let keyCode = UserDefaults.standard.object(forKey: Keys.hotKeyKeyCode) as? Int
        let modifiers = UserDefaults.standard.object(forKey: Keys.hotKeyModifiers) as? Int
        guard let keyCode, let modifiers else { return nil }
        return .init(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers))
    }

    private func saveHotKey() {
        UserDefaults.standard.set(Int(hotKey.keyCode), forKey: Keys.hotKeyKeyCode)
        UserDefaults.standard.set(Int(hotKey.modifiers), forKey: Keys.hotKeyModifiers)
    }
}
