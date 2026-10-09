import AppKit
import SwiftUI

/// Read-only observer of the history list's backing NSScrollView.
///
/// Scrolling itself is performed by the system (synthesized scrollWheel
/// events from the keyboard, a real trackpad, or a mouse) — this object only
/// mirrors the resulting position to drive the visual indicator, so it can
/// never fight SwiftUI's layout system.
@MainActor
final class HorizontalScrollObserver: ObservableObject {
    @Published private(set) var offsetX: CGFloat = 0
    @Published private(set) var viewportWidth: CGFloat = 0
    @Published private(set) var contentWidth: CGFloat = 0
    @Published private(set) var feedbackActive: Bool = false

    private var boxes: [WeakBox] = []
    // Only touched on the Main Actor; nonisolated so deinit can unregister.
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []
    private var feedbackGeneration: Int = 0

    var hasHorizontalOverflow: Bool { contentWidth > viewportWidth + 1 }

    var scrollProgress: CGFloat {
        let maxOffset = max(contentWidth - viewportWidth, 1)
        return min(max(offsetX / maxOffset, 0), 1)
    }

    func register(scrollViews: [NSScrollView]) {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        boxes = scrollViews.map { WeakBox($0) }

        for scrollView in scrollViews {
            let clip = scrollView.contentView
            clip.postsBoundsChangedNotifications = true
            observers.append(
                NotificationCenter.default.addObserver(
                    forName: NSView.boundsDidChangeNotification,
                    object: clip,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor in
                        self?.refreshState()
                    }
                }
            )
        }
        refreshState()
    }

    /// The backing scroll view that can actually pan horizontally.
    func targetScrollView() -> NSScrollView? {
        horizontalScrollView()
    }

    private func horizontalScrollView() -> NSScrollView? {
        let live = boxes.compactMap { $0.value }
        if live.count != boxes.count { boxes = live.map { WeakBox($0) } }
        let overflowing = live.first { scrollView in
            (scrollView.documentView?.bounds.width ?? 0) > scrollView.contentView.bounds.width + 1
        }
        if overflowing != nil { return overflowing }
        return live.last
    }

    private func refreshState() {
        guard let scrollView = horizontalScrollView() else { return }
        let clip = scrollView.contentView
        viewportWidth = clip.bounds.width
        contentWidth = scrollView.documentView?.bounds.width ?? 0
        offsetX = clip.bounds.origin.x
        pingFeedback()
    }

    private func pingFeedback() {
        feedbackActive = true
        feedbackGeneration += 1
        let generation = feedbackGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self, self.feedbackGeneration == generation else { return }
            self.feedbackActive = false
        }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    private final class WeakBox {
        weak var value: NSScrollView?
        init(_ value: NSScrollView) { self.value = value }
    }
}

/// Zero-size bridge that locates the enclosing NSScrollView(链) and registers
/// them with the observer.
struct ScrollAnchorView: NSViewRepresentable {
    let observer: HorizontalScrollObserver

    func makeNSView(context: Context) -> ScrollAnchorNSView {
        let view = ScrollAnchorNSView()
        view.observer = observer
        return view
    }

    func updateNSView(_ nsView: ScrollAnchorNSView, context: Context) {
        nsView.observer = observer
        nsView.registerIfNeeded()
    }
}

final class ScrollAnchorNSView: NSView {
    weak var observer: HorizontalScrollObserver?

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        registerIfNeeded()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            self?.registerIfNeeded()
        }
    }

    func registerIfNeeded() {
        guard superview != nil else { return }
        var chain: [NSScrollView] = []
        var current: NSView? = superview
        while let view = current {
            if let scrollView = view as? NSScrollView {
                chain.append(scrollView)
            }
            current = view.superview
        }
        guard !chain.isEmpty else { return }
        MainActor.assumeIsolated {
            observer?.register(scrollViews: chain)
        }
    }
}
