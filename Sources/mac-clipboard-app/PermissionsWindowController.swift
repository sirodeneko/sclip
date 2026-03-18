import AppKit
import Combine
import SwiftUI

@MainActor
final class PermissionsWindowController {
    private let model = PermissionStatusModel()
    private var window: NSWindow?
    private var cancellable: AnyCancellable?

    func show() {
        if let window {
            window.title = L("permissions.title")
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            model.refresh()
            return
        }

        let view = PermissionsView(model: model) { [weak self] in
            self?.close()
        }
        let hosting = NSHostingView(rootView: view)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = L("permissions.title")
        window.contentView = hosting
        window.isReleasedWhenClosed = false

        self.window = window
        cancellable = LocalizationCenter.shared.$language
            .sink { [weak self] _ in
                self?.window?.title = L("permissions.title")
            }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        model.refresh()
    }

    func close() {
        window?.close()
        window = nil
        cancellable = nil
    }
}
