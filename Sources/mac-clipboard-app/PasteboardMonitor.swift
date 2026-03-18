import AppKit
import Foundation

@MainActor
final class PasteboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var ignoredChangeCount: Int?

    var onNewItems: (([NSPasteboardItem]) -> Void)?

    func start(pollInterval: TimeInterval = 0.4) {
        stop()
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func ignoreCurrentChangeCount() {
        ignoredChangeCount = NSPasteboard.general.changeCount
    }

    private func tick() {
        let pb = NSPasteboard.general
        let changeCount = pb.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        if ignoredChangeCount == changeCount {
            ignoredChangeCount = nil
            return
        }

        guard let items = pb.pasteboardItems, !items.isEmpty else { return }
        onNewItems?(items)
    }
}
