import AppKit
import Foundation

enum PermissionsCenter {
    static func isAccessibilityGranted() -> Bool {
        CaretLocator.isTrusted(promptIfNeeded: false)
    }

    @discardableResult
    static func requestAccessibilityIfNeeded() -> Bool {
        if isAccessibilityGranted() {
            return true
        }
        return CaretLocator.isTrusted(promptIfNeeded: true)
    }

    static func openAccessibilitySettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
        ]
        for s in candidates {
            if let url = URL(string: s), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
