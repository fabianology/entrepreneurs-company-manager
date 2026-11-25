import SwiftUI

/// One shared indicator for report preparation and refresh. The surrounding control supplies its label.
struct ReportLoadingArtwork: View {
    var width: CGFloat = 108
    var active = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var start = Date()

    var body: some View {
        Group {
            if reduceMotion || !active || scenePhase != .active {
                ReportLoadingReel(beat: Double(ReportLoadingMark.miloom.rawValue), width: width)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 60)) { clock in
                    // Start with Financial already visible, even for a very short fetch.
                    let beat = max(0, clock.date.timeIntervalSince(start)) / 0.95
                    ReportLoadingReel(beat: beat, width: width)
                }
            }
        }
        .frame(width: width, height: width * 0.64)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

private enum ReportLoadingMark: Int, CaseIterable {
    case financial, services, documents, miloom

    @ViewBuilder
    var image: some View {
        switch self {
        case .financial: Image(systemName: EntityHomeTab.financial.icon).resizable()
        case .services: Image(systemName: EntityHomeTab.subscriptions.icon).resizable()
        case .documents: Image(systemName: "doc.text").resizable()
        case .miloom: Image("miloom_emblem").renderingMode(.original).resizable()
        }
    }
}

private struct ReportLoadingReel: View {
    let beat: Double
    let width: CGFloat

    // Move one detent up, overshoot by a few points, then settle back into the notch.
    private func advance(at phase: Double) -> Double {
        func ease(_ fraction: Double) -> Double {
            let t = min(max(fraction, 0), 1)
            return t * t * (3 - 2 * t)
        }
        return 1.055 * ease((phase - 0.46) / 0.38) - 0.055 * ease((phase - 0.84) / 0.16)
    }

    var body: some View {
        let marks = ReportLoadingMark.allCases
        let index = Int(beat) % marks.count
        let phase = beat - floor(beat)
        let advance = advance(at: phase)
        let pitch = width * 0.66
        let trailingOffset = pitch * (advance - self.advance(at: phase - 0.026))

        ZStack {
            slot(marks[index], distance: -advance, pitch: pitch, trail: trailingOffset)
            if advance > 0 {
                slot(marks[(index + 1) % marks.count], distance: 1 - advance, pitch: pitch, trail: trailingOffset)
            }
        }
        .frame(width: width, height: width * 0.64)
        .clipped()
    }

    private func slot(_ mark: ReportLoadingMark, distance: Double, pitch: CGFloat, trail: CGFloat) -> some View {
        let edge = min(abs(distance), 1)
        let softness = abs(trail) * 0.25
        let glyph = mark.image
            .scaledToFit()
            .frame(height: width * (mark == .miloom ? 0.34 : 0.36))
            .foregroundStyle(LinearGradient(colors: [Color(red: 0.30, green: 0.67, blue: 0.64),
                                                       Color(red: 0.09, green: 0.43, blue: 0.46)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing))
        return ZStack {
            if abs(trail) > 0.25 {
                glyph.blur(radius: softness).opacity(0.24).offset(y: trail)
            }
            glyph.blur(radius: softness * 0.48)
        }
        .scaleEffect(x: 1, y: 1 - 0.32 * edge * edge)
        .opacity(1 - 0.58 * edge * edge)
        .offset(y: distance * pitch)
    }
}

#if canImport(UIKit)
import UIKit

/// Keeps the native pull threshold, haptic and release behavior, with the same loading
/// artwork that appears during the initial fetch.
struct CashFlowPullToRefresh: UIViewRepresentable {
    var sync: @MainActor () async -> Void

    func makeUIView(context: Context) -> Anchor {
        let anchor = Anchor()
        anchor.isUserInteractionEnabled = false
        return anchor
    }

    func updateUIView(_ anchor: Anchor, context: Context) {
        anchor.sync = sync
        anchor.attach()
    }

    static func dismantleUIView(_ anchor: Anchor, coordinator: ()) {
        anchor.detach()
    }

    final class Anchor: UIView {
        var sync: (@MainActor () async -> Void)?
        private weak var scroll: UIScrollView?
        private var refreshObservation: NSKeyValueObservation?
        private var previousVerticalBounce = false
        private let control = UIRefreshControl()
        private var artwork: UIView?
        private var task: Task<Void, Never>?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil {
                detach()
            } else {
                // SwiftUI configures the scroll view during the same layout pass.
                DispatchQueue.main.async { [weak self] in self?.attach() }
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            // A SwiftUI scroll view may finish configuring itself after window attachment.
            if let scroll, scroll.refreshControl === control { return }
            DispatchQueue.main.async { [weak self] in self?.attach() }
        }

        func attach() {
            guard window != nil else { return }
            if let scroll, scroll.refreshControl === control { return }
            var ancestor = superview
            while let view = ancestor {
                if let list = view as? UIScrollView {
                    guard list.refreshControl == nil else { return }
                    if scroll !== list {
                        scroll = list
                        previousVerticalBounce = list.alwaysBounceVertical
                        control.tintColor = .clear
                        control.accessibilityLabel = "Refresh transactions"
                        control.addTarget(self, action: #selector(refresh), for: .valueChanged)
                        // SwiftUI can clear the native refresh control when it updates its scroll view.
                        refreshObservation = list.observe(\.refreshControl) { [weak self, weak list] _, _ in
                            Task { @MainActor in
                                guard let self, let list, self.scroll === list,
                                      list.refreshControl == nil else { return }
                                self.attach()
                            }
                        }
                    }
                    list.alwaysBounceVertical = true
                    list.refreshControl = control
                    if artwork == nil { showArtwork(moving: false) }
                    return
                }
                ancestor = view.superview
            }
        }

        func detach() {
            refreshObservation?.invalidate()
            refreshObservation = nil
            control.removeTarget(self, action: #selector(refresh), for: .valueChanged)
            if let scroll, scroll.refreshControl === control {
                control.endRefreshing()
                scroll.refreshControl = nil
                scroll.alwaysBounceVertical = previousVerticalBounce
            }
            artwork?.removeFromSuperview()
            artwork = nil
            scroll = nil
        }

        private func showArtwork(moving: Bool) {
            artwork?.removeFromSuperview()
            let graphic = UIHostingConfiguration {
                ReportLoadingArtwork(width: 56, active: moving)
            }.margins(.all, 0).makeContentView()
            graphic.backgroundColor = .clear
            graphic.isUserInteractionEnabled = false
            graphic.translatesAutoresizingMaskIntoConstraints = false
            control.addSubview(graphic)
            NSLayoutConstraint.activate([
                graphic.centerXAnchor.constraint(equalTo: control.centerXAnchor),
                graphic.centerYAnchor.constraint(equalTo: control.centerYAnchor),
                graphic.widthAnchor.constraint(equalToConstant: 56),
                graphic.heightAnchor.constraint(equalToConstant: 36)
            ])
            artwork = graphic
        }

        @objc private func refresh() {
            guard task == nil else { return }
            showArtwork(moving: true)
            task = Task {
                await sync?()
                control.endRefreshing()
                if scroll != nil { showArtwork(moving: false) }
                task = nil
            }
        }
    }
}
#endif
