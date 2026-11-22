import SwiftUI
import UIKit

#if compiler(>=6.4)
enum DuoSideSwipe {
    enum Layout {
        case portrait, compact, leftSplitPane, split

        // The compact page and landscape pane already inset their visible content.
        private static let outerContentMargin: CGFloat = 16

        func acceptsStart(x: CGFloat, page: CGRect, leftPanel: CGRect?) -> Bool {
            guard page.width > 0 else { return false }
            if x >= page.maxX { return true }

            switch self {
            case .portrait:
                return x < page.minX
            case .compact:
                return x < page.minX + Self.outerContentMargin
            case .leftSplitPane:
                return x < page.minX + Self.outerContentMargin || x >= page.maxX - Self.outerContentMargin
            case .split:
                guard let leftPanel, leftPanel.width > 0 else { return false }
                return x < leftPanel.minX + Self.outerContentMargin
            }
        }
    }

    static func tab(from index: Int, count: Int, distance: CGFloat, velocity: CGFloat) -> Int? {
        let isFlick = abs(distance) >= 12 && abs(velocity) >= 330 && distance * velocity > 0
        guard abs(distance) >= 32 || isFlick else { return nil }
        let next = index + (distance < 0 ? 1 : -1)
        return (0..<count).contains(next) ? next : nil
    }
}

@MainActor
final class DuoSideGestures: NSObject, UIGestureRecognizerDelegate {
    enum Anchor: Hashable {
        case page, leftPanel
        case control(Control)
        case scroll(EntityHomeTab)
    }

    enum Control: Hashable {
        case share, add, entities, admin
        case report(String)
    }

    private lazy var pan: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        gesture.delegate = self
        gesture.maximumNumberOfTouches = 1
        gesture.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        gesture.cancelsTouchesInView = false
        return gesture
    }()

    var tab = EntityHomeTab.financial {
        didSet {
            if tab != oldValue { stopGlide() }
        }
    }

    private weak var scrolling: UIScrollView?
    private var touchStart: CGPoint = .zero
    private var isHorizontal = false
    private var lastDragY: CGFloat = 0
    private var glide: CADisplayLink?
    private var glideVelocity: CGFloat = 0

    func register(_ view: DuoSideGestureMarker.View, for anchor: Anchor) {
        markers[anchor] = WeakMarker(view: view)
        if anchor == .page, pan.view !== view.window {
            pan.view?.removeGestureRecognizer(pan)
            view.window?.addGestureRecognizer(pan)
        }
    }

    func unregister(_ view: DuoSideGestureMarker.View, for anchor: Anchor) {
        guard marker(anchor) === view else { return }
        markers[anchor] = nil
        if anchor == .page {
            pan.view?.removeGestureRecognizer(pan)
            stopGlide()
        }
    }

    private struct WeakMarker {
        weak var view: DuoSideGestureMarker.View?
    }

    private var markers: [Anchor: WeakMarker] = [:]

    private func marker(_ anchor: Anchor) -> DuoSideGestureMarker.View? {
        markers[anchor]?.view
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let window = pan.view as? UIWindow, let page = marker(.page), page.isActive,
              page.window === window, !UIAccessibility.isVoiceOverRunning,
              !page.hasPresentedController else { return false }

        stopGlide()
        let location = touch.location(in: window)
        let content = page.convert(page.bounds, to: window)
        let panel = marker(.leftPanel).flatMap { view in
            view.window === window ? view.convert(view.bounds, to: window) : nil
        }
        guard window.bounds.contains(location),
              location.y < window.bounds.maxY - window.safeAreaInsets.bottom,
              page.layout.acceptsStart(x: location.x, page: content, leftPanel: panel) else { return false }

        if #available(iOS 27.1, *) {
            for kind in [UIView.ReservedRegion.Kind.occlusion, .division] {
                if window.reservedRegions(kind: kind).contains(where: { $0.frame.contains(location) }) {
                    return false
                }
            }
        }

        for (anchor, marker) in markers {
            guard case .control = anchor, let view = marker.view, view.window === window else { continue }
            if view.convert(view.bounds, to: window).insetBy(dx: -4, dy: -4).contains(location) {
                return false
            }
        }
        touchStart = location
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
        // A scroll view may extend into an empty margin. Its pan yields only
        // for touches accepted by the side gesture.
        guard let scroll = other.view as? UIScrollView else { return false }
        return scroll.panGestureRecognizer === other
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let movement = displacement
        isHorizontal = abs(movement.x) > abs(movement.y) * 1.2
        if isHorizontal { return true }
        guard abs(movement.y) >= abs(movement.x),
              let scroll = marker(.scroll(tab))?.enclosingScrollView,
              scroll.isScrollEnabled else { return false }
        let range = scrollRange(scroll)
        guard range.lowerBound < range.upperBound else { return false }
        scrolling = scroll
        return true
    }

    // UIPanGestureRecognizer can reset its translation when it begins.
    // Measure from touch-down so a short flick still has its full displacement.
    private var displacement: CGPoint {
        let point = pan.location(in: pan.view)
        return CGPoint(x: point.x - touchStart.x, y: point.y - touchStart.y)
    }

    @objc private func handlePan() {
        let translation = displacement
        switch pan.state {
        case .began, .changed:
            guard !isHorizontal, let scrolling else { return }
            if pan.state == .began {
                if #available(iOS 17.4, *) { scrolling.stopScrollingAndZooming() }
                lastDragY = 0
            }
            move(scrolling, by: lastDragY - translation.y)
            lastDragY = translation.y
        case .ended:
            let velocity = pan.velocity(in: pan.view)
            if isHorizontal {
                marker(.page)?.onSwipe(translation.x, velocity.x)
            } else if let scrolling {
                move(scrolling, by: lastDragY - translation.y)
                if abs(velocity.y) >= 45 && !UIAccessibility.isReduceMotionEnabled {
                    glideVelocity = -velocity.y
                    let link = CADisplayLink(target: self, selector: #selector(advanceGlide(_:)))
                    glide = link
                    link.add(to: .main, forMode: .common)
                    return
                }
            }
            stopGlide()
        case .cancelled, .failed:
            stopGlide()
        default:
            break
        }
    }

    private func scrollRange(_ scroll: UIScrollView) -> ClosedRange<CGFloat> {
        let insets = scroll.adjustedContentInset
        let top = -insets.top
        return top...max(top, scroll.contentSize.height - scroll.bounds.height + insets.bottom)
    }

    @discardableResult
    private func move(_ scroll: UIScrollView, by distance: CGFloat) -> Bool {
        let range = scrollRange(scroll)
        let current = scroll.contentOffset
        let next = min(range.upperBound, max(range.lowerBound, current.y + distance))
        scroll.setContentOffset(CGPoint(x: current.x, y: next), animated: false)
        return next != range.lowerBound && next != range.upperBound
    }

    @objc private func advanceGlide(_ link: CADisplayLink) {
        guard let scrolling, scrolling.window != nil, !scrolling.isTracking,
              let page = marker(.page), page.isActive, !page.hasPresentedController else {
            stopGlide()
            return
        }

        // Apply the real scroll view's deceleration rate per millisecond.
        let elapsed = min(link.targetTimestamp - link.timestamp, 1.0 / 30.0)
        let decay = log(scrolling.decelerationRate.rawValue) * 1000
        let remaining = exp(decay * elapsed)
        let distance = glideVelocity * (remaining - 1) / decay
        glideVelocity *= remaining
        if !move(scrolling, by: distance) || abs(glideVelocity) < 15 { stopGlide() }
    }

    private func stopGlide() {
        glide?.invalidate()
        glide = nil
        scrolling = nil
    }
}

struct DuoSideGestureMarker: UIViewRepresentable {
    let gestures: DuoSideGestures
    let anchor: DuoSideGestures.Anchor
    var layout = DuoSideSwipe.Layout.compact
    var isActive = true
    var onSwipe: (CGFloat, CGFloat) -> Void = { _, _ in }

    func makeUIView(context: Context) -> View {
        let view = View()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: View, context: Context) {
        view.layout = layout
        view.isActive = isActive
        view.onSwipe = onSwipe
        view.configure(gestures, anchor: anchor)
    }

    static func dismantleUIView(_ view: View, coordinator: ()) {
        view.unregister()
    }

    final class View: UIView {
        private weak var gestures: DuoSideGestures?
        private var anchor: DuoSideGestures.Anchor = .page
        var layout = DuoSideSwipe.Layout.compact
        var isActive = true
        var onSwipe: (CGFloat, CGFloat) -> Void = { _, _ in }

        func configure(_ gestures: DuoSideGestures, anchor: DuoSideGestures.Anchor) {
            if self.gestures === gestures && self.anchor == anchor { return }
            unregister()
            self.gestures = gestures
            self.anchor = anchor
            if window != nil { gestures.register(self, for: anchor) }
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil {
                gestures?.register(self, for: anchor)
            } else {
                unregister()
            }
        }

        func unregister() {
            gestures?.unregister(self, for: anchor)
        }

        var enclosingScrollView: UIScrollView? {
            var view = superview
            while let ancestor = view {
                if let scroll = ancestor as? UIScrollView { return scroll }
                view = ancestor.superview
            }
            return nil
        }

        var hasPresentedController: Bool {
            var responder: UIResponder? = self
            while let current = responder {
                if let controller = current as? UIViewController,
                   controller.presentedViewController != nil { return true }
                responder = current.next
            }
            return window?.rootViewController?.presentedViewController != nil
        }
    }
}

private struct DuoSideScrollTarget: ViewModifier {
    @Environment(\.duoSideGestures) private var gestures
    let tab: EntityHomeTab

    func body(content: Content) -> some View {
        content.background {
            if let gestures {
                DuoSideGestureMarker(gestures: gestures, anchor: .scroll(tab))
            }
        }
    }
}

private struct DuoSideGesturesKey: EnvironmentKey {
    static let defaultValue: DuoSideGestures? = nil
}

extension EnvironmentValues {
    fileprivate var duoSideGestures: DuoSideGestures? {
        get { self[DuoSideGesturesKey.self] }
        set { self[DuoSideGesturesKey.self] = newValue }
    }
}
#endif

extension View {
    @ViewBuilder
    func duoSideScrollTarget(_ tab: EntityHomeTab) -> some View {
        #if compiler(>=6.4)
        modifier(DuoSideScrollTarget(tab: tab))
        #else
        self
        #endif
    }

    #if compiler(>=6.4)
    func duoSideScrollTargets(_ gestures: DuoSideGestures) -> some View {
        environment(\.duoSideGestures, gestures)
    }
    #endif
}
