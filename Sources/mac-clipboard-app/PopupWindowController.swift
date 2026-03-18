import AppKit
import SwiftUI

@MainActor
final class PopupWindowController: NSObject, NSWindowDelegate {
    private let store: ClipboardHistoryStore
    private let onSelect: (ClipboardHistoryEntry) -> Void

    private var panel: NSPanel?
    private var localEventMonitor: Any?

    init(store: ClipboardHistoryStore, onSelect: @escaping (ClipboardHistoryEntry) -> Void) {
        self.store = store
        self.onSelect = onSelect
    }

    func toggle() {
        if panel?.isVisible == true {
            close()
        } else {
            show()
        }
    }

    func show() {
        let origin = CaretLocator.caretPoint() ?? NSEvent.mouseLocation
        show(at: origin)
    }

    func show(at point: CGPoint) {
        let panel = ensurePanel()
        position(panel: panel, near: point)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        startEventMonitor()
    }

    func close() {
        stopEventMonitor()
        panel?.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }

        let hosting = NSHostingView(rootView: HistoryPopupView(store: store) { [weak self] entry in
            guard let self else { return }
            self.onSelect(entry)
            self.close()
        })
        hosting.frame = CGRect(x: 0, y: 0, width: 520, height: 360)

        let panel = NSPanel(
            contentRect: hosting.frame,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        panel.delegate = self
        panel.contentView = hosting

        self.panel = panel
        return panel
    }

    private func position(panel: NSPanel, near point: CGPoint) {
        let size = panel.frame.size
        let padding: CGFloat = 12

        let screens = NSScreen.screens
        let screen = screens.first { $0.frame.contains(point) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)

        var x = point.x - size.width / 2
        var y = point.y - size.height - padding

        if y < visible.minY + padding {
            y = point.y + padding
        }

        x = min(max(x, visible.minX + padding), visible.maxX - size.width - padding)
        y = min(max(y, visible.minY + padding), visible.maxY - size.height - padding)

        panel.setFrameOrigin(CGPoint(x: x, y: y))
    }

    private func startEventMonitor() {
        guard localEventMonitor == nil else { return }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown, event.keyCode == 53 {
                self.close()
                return nil
            }
            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                if let panel = self.panel, panel.isVisible {
                    let loc = NSEvent.mouseLocation
                    if !panel.frame.contains(loc) {
                        self.close()
                        return event
                    }
                }
            }
            return event
        }
    }

    private func stopEventMonitor() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
    }
}

