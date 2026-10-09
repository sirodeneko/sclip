import AppKit
import SwiftUI

@MainActor
final class PopupWindowController: NSObject, NSWindowDelegate {
    private let store: ClipboardHistoryStore
    private let preferences: PreferencesModel
    private let onSelect: (ClipboardHistoryEntry) -> Void

    private var panel: NSPanel?
    private var hostingView: NSHostingView<HistoryPopupView>?
    private var localEventMonitor: Any?
    private var openToken: Int = 0

    init(
        store: ClipboardHistoryStore,
        preferences: PreferencesModel,
        onSelect: @escaping (ClipboardHistoryEntry) -> Void
    ) {
        self.store = store
        self.preferences = preferences
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
        openToken &+= 1
        hostingView?.rootView = makeRootView(openToken: openToken)
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

        let hosting = NSHostingView(rootView: makeRootView(openToken: openToken))
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
        self.hostingView = hosting
        return panel
    }

    private func makeRootView(openToken: Int) -> HistoryPopupView {
        HistoryPopupView(
            store: store,
            preferences: preferences,
            openToken: openToken,
            onSelect: { [weak self] entry in
                guard let self else { return }
                self.onSelect(entry)
                self.close()
            },
            onHorizontalScroll: { [weak self] direction, fast, target in
                self?.postHorizontalScrollEvent(direction: direction, fast: fast, target: target)
            }
        )
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
            if event.type == .keyDown {
                // Only Escape is handled here; horizontal-scroll shortcut keys
                // are consumed by the popup view's first-responder keyDown.
                if event.keyCode == 53 {
                    self.close()
                    return nil
                }
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

    // MARK: Keyboard -> scrollWheel event synthesis

    private func postHorizontalScrollEvent(direction: Int, fast: Bool, target: NSScrollView?) {
        guard let panel else { return }

        // Negate: a positive scrollWheel delta pans content right (browse
        // left), but the arrow key should browse in its own direction.
        let pixelDelta = -Int32((fast ? 120 : 16) * direction)

        guard let cgEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: 0,
            wheel2: pixelDelta,
            wheel3: 0
        ) else { return }

        cgEvent.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        cgEvent.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: Int64(pixelDelta))

        guard let nsEvent = NSEvent(cgEvent: cgEvent) else { return }

        // Preferred: deliver the real NSEvent straight to the scroll view that
        // actually owns the horizontal axis, and let IT scroll itself (the
        // same method AppKit invokes for a trackpad).
        if let target {
            let before = target.contentView.bounds.origin.x
            target.scrollWheel(with: nsEvent)
            let after = target.contentView.bounds.origin.x
            if after != before { return }

            // It ignored the event; try its document view (responder chain).
            if let doc = target.documentView {
                doc.scrollWheel(with: nsEvent)
                if target.contentView.bounds.origin.x != before { return }
            }
        }

        // Fallback A: hit-test the popup center and deliver there.
        if let contentView = panel.contentView {
            let gp = CGPoint(x: panel.frame.midX, y: panel.frame.midY)
            let wp = CGPoint(x: gp.x - panel.frame.origin.x, y: gp.y - panel.frame.origin.y)
            let cp = contentView.convert(wp, from: nil)
            if let hit = contentView.hitTest(cp) {
                hit.scrollWheel(with: nsEvent)
                return
            }
            panel.sendEvent(nsEvent)
            return
        }

        // Fallback B: post the raw CGEvent at system level.
        let pid = pid_t(ProcessInfo.processInfo.processIdentifier)
        if AXIsProcessTrusted() {
            cgEvent.post(tap: .cghidEventTap)
        } else {
            cgEvent.postToPid(pid)
        }
    }

    private func stopEventMonitor() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
    }
}
