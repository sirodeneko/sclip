import AppKit
import Combine
import SwiftUI

@MainActor
final class PreferencesWindowController {
    private let preferences: PreferencesModel
    private let onHotKeyChanged: (HotKeyManager.HotKey) -> Void
    private var window: NSWindow?
    private var cancellable: AnyCancellable?

    init(preferences: PreferencesModel, onHotKeyChanged: @escaping (HotKeyManager.HotKey) -> Void) {
        self.preferences = preferences
        self.onHotKeyChanged = onHotKeyChanged
    }

    func show() {
        if let window {
            window.title = L("settings.title")
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = PreferencesView(preferences: preferences, onHotKeyChanged: onHotKeyChanged)
        let hosting = NSHostingView(rootView: view)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = L("settings.title")
        window.contentView = hosting
        window.isReleasedWhenClosed = false

        self.window = window
        cancellable = LocalizationCenter.shared.$language
            .sink { [weak self] _ in
                self?.window?.title = L("settings.title")
            }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
