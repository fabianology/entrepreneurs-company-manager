import SwiftUI

// MARK: - Existing spotlight PreferenceKey (real first-run onboarding)

struct SpotlightBoundsKey: PreferenceKey {
    static var defaultValue: [Anchor<CGRect>] = []
    static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - Tutorial Frame PreferenceKey
// Bubbles named CGRects from EntityHomeView / FinancialView up to CompanyDetailView.

struct TutorialFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - View extensions

extension View {
    /// Tags a view as the spotlight target for first-run onboarding.
    func spotlightTarget(isActive: Bool) -> some View {
        self.transformAnchorPreference(key: SpotlightBoundsKey.self, value: .bounds) { value, anchor in
            if isActive {
                value.append(anchor)
            }
        }
    }

    /// Punches a hole in a mask layer (used for spotlight dimming).
    func reverseMask<Mask: View>(
        alignment: Alignment = .center,
        @ViewBuilder _ mask: () -> Mask
    ) -> some View {
        self.mask(
            ZStack {
                Rectangle()
                mask()
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
        )
    }
}

// MARK: - Original SpotlightOverlayView (real first-run onboarding)

struct SpotlightOverlayView: View {
    let anchors: [Anchor<CGRect>]
    let message: String
    var stepIndex: Int? = nil
    var totalSteps: Int? = nil
    var onBack: (() -> Void)? = nil
    var onNext: (() -> Void)? = nil
    let onSkip: () -> Void
    let onTapTarget: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Background dimming with hole
                Color.black.opacity(0.70)
                    .reverseMask {
                        ForEach(anchors.indices, id: \.self) { index in
                            let frame = proxy[anchors[index]]
                            RoundedRectangle(cornerRadius: 16)
                                .frame(width: frame.width + 16, height: frame.height + 16)
                                .position(x: frame.midX, y: frame.midY)
                        }
                    }
                    .ignoresSafeArea()
                    .onTapGesture { }

                ForEach(anchors.indices, id: \.self) { index in
                    let frame = proxy[anchors[index]]
                    let isOutermost = (index == anchors.count - 1)
                    if isOutermost {
                        let strokeColor = Color(hex: "#0A84FF")
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(strokeColor, lineWidth: 3)
                            .frame(width: frame.width + 16, height: frame.height + 16)
                            .shadow(color: strokeColor.opacity(0.8), radius: 15)
                            .position(x: frame.midX, y: frame.midY)
                            .allowsHitTesting(false)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(LinearGradient.miloomPrimary, lineWidth: 1.5)
                            .frame(width: frame.width - 4, height: frame.height - 4)
                            .position(x: frame.midX, y: frame.midY)
                            .allowsHitTesting(false)
                    }

                    // Tap-through zone over target
                    Color.black.opacity(0.001)
                        .frame(width: frame.width + 16, height: frame.height + 16)
                        .contentShape(Rectangle())
                        .position(x: frame.midX, y: frame.midY)
                        .onTapGesture { onTapTarget() }
                }

                // Tooltip
                if let firstAnchor = anchors.first {
                    let frame = proxy[firstAnchor]
                VStack(alignment: .leading, spacing: 12) {
                    if let stepIndex = stepIndex, let totalSteps = totalSteps {
                        // Step pill + progress dots row
                        HStack(spacing: 10) {
                            Text("\(stepIndex) of \(totalSteps)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(hex: "#5AC8FA"))

                            Spacer()

                            HStack(spacing: 8) {
                                ForEach(1...totalSteps, id: \.self) { i in
                                    Capsule()
                                        .fill(i == stepIndex ? Color(hex: "#5AC8FA") : (i < stepIndex ? Color(hex: "#5AC8FA").opacity(0.3) : Color.white.opacity(0.1)))
                                        .frame(width: i == stepIndex ? 24 : 8, height: 8)
                                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: stepIndex)
                                }
                            }
                        }
                        .padding(.bottom, 4)
                    }

                    Text(message)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    // Back / Next buttons
                    if onBack != nil || onNext != nil {
                        HStack(spacing: 10) {
                            if let onBack {
                                Button {
                                    withAnimation(.spring(response: 0.35)) { onBack() }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 11, weight: .bold))
                                        Text("Back")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundStyle(Color.white.opacity(0.55))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 34)
                                    .background(Color.white.opacity(0.07))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }

                            if let onNext {
                                Button {
                                    withAnimation(.spring(response: 0.35)) { onNext() }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(stepIndex == totalSteps ? "Done" : "Next")
                                            .font(.system(size: 13, weight: .bold))
                                        if stepIndex != totalSteps {
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 11, weight: .bold))
                                        }
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 34)
                                    .background(.miloomPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 4)
                    }

                    // Skip link
                    Button { onSkip() } label: {
                        Text("Skip Onboarding")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.35))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, onBack != nil || onNext != nil ? 10 : 4)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "#1C1C1E").opacity(0.95))
                            .shadow(color: .black.opacity(0.5), radius: 15)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 1))
                    )
                    .padding(.horizontal, 32)
                    .position(
                        x: proxy.size.width / 2,
                        y: frame.midY > proxy.size.height / 2
                            ? max(frame.minY - 160, 160)
                            : min(frame.maxY + 160, proxy.size.height - 160)
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - TutorialSpotlightOverlayView
// Accepts a plain CGRect captured via GeometryReader in the 'dashboard' coordinate space.
// No PreferenceKey / Anchor required — bypasses the List preference-swallowing issue.

struct TutorialSpotlightOverlayView: View {
    let anchor: CGRect          // Frame in coordinate space
    let stepIndex: Int          // 1-based
    let totalSteps: Int
    let title: String
    let message: String
    var segment: String? = nil  // Optional screen label, e.g. "COMMAND CENTER"
    let onBack: (() -> Void)?   // nil on step 1
    let onNext: () -> Void
    let onSkip: () -> Void

    // Maps segment labels to their index (0, 1, 2)
    private var segmentPageIndex: Int {
        switch segment {
        case "COMMAND CENTER": return 1
        case "FINANCIALS":     return 2
        default:               return 0  // DASHBOARD
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let frame = anchor
            // Determine if the spotlight is in the lower half
            let tooltipAbove = frame.midY > proxy.size.height * 0.5

            ZStack {
                // Dimming layer with hole punched over target
                Color.black.opacity(0.75)
                    .reverseMask {
                        RoundedRectangle(cornerRadius: 20)
                            .frame(width: frame.width + 20, height: frame.height + 20)
                            .position(x: frame.midX, y: frame.midY)
                    }
                    .ignoresSafeArea()
                    .onTapGesture { } // absorb scrim taps

                // Glowing blue border around spotlighted element
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "#5AC8FA"), Color(hex: "#0A84FF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: frame.width + 20, height: frame.height + 20)
                    .shadow(color: Color(hex: "#0A84FF").opacity(0.7), radius: 18)
                    .position(x: frame.midX, y: frame.midY)
                    .allowsHitTesting(false)

                // Tooltip card
                VStack(alignment: .leading, spacing: 0) {

                    // Top row: step counter (plain, no pill) + 3 segment dots
                    HStack(spacing: 10) {
                        // Segment label + step counter — plain text, no background
                        VStack(alignment: .leading, spacing: 2) {
                            if let segment = segment, !segment.isEmpty {
                                Text(segment)
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(Color(hex: "#5AC8FA").opacity(0.7))
                                    .tracking(1.5)
                                    .textCase(.uppercase)
                            }
                            Text("\(stepIndex) of \(totalSteps)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(hex: "#5AC8FA"))
                        }

                        Spacer()

                        // 3-dot page segment indicator (Dashboard · Command Center · Financials)
                        HStack(spacing: 8) {
                            ForEach(0..<3, id: \.self) { i in
                                Capsule()
                                    .fill(i == segmentPageIndex
                                          ? Color(hex: "#5AC8FA")
                                          : (i < segmentPageIndex
                                             ? Color(hex: "#5AC8FA").opacity(0.35)
                                             : Color.white.opacity(0.12)))
                                    .frame(width: i == segmentPageIndex ? 22 : 8, height: 6)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: segmentPageIndex)
                            }
                        }
                    }
                    .padding(.bottom, 10)

                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.bottom, 6)

                    Text(message)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                        .padding(.bottom, 18)

                    // Back / Next buttons
                    HStack(spacing: 10) {
                        if let onBack {
                            Button {
                                withAnimation(.spring(response: 0.35)) { onBack() }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 12, weight: .bold))
                                    Text("Back")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundStyle(Color.white.opacity(0.55))
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(Color.white.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            withAnimation(.spring(response: 0.35)) { onNext() }
                        } label: {
                            HStack(spacing: 4) {
                                Text(stepIndex == totalSteps ? "Done" : "Next")
                                    .font(.system(size: 14, weight: .bold))
                                if stepIndex < totalSteps {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#5AC8FA"), Color(hex: "#0A84FF")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }

                    // Skip link
                    Button { onSkip() } label: {
                        Text("Skip Tutorial")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.35))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(hex: "#1C1C1E"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.6), radius: 24, y: 8)
                )
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .position(
                    x: proxy.size.width / 2,
                    y: tooltipAbove
                        ? max(frame.minY - 150, 140)
                        : min(frame.maxY + 150, proxy.size.height - 140)
                )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - TutorialCompletionOverlay (Step 8 — full screen, no spotlight hole)

struct TutorialCompletionOverlay: View {
    let onGetStarted: () -> Void
    let onExplore: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: "#0A84FF").opacity(0.25), Color.clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#5AC8FA"), Color(hex: "#0A84FF")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(appeared ? 1 : 0.5)
                        .opacity(appeared ? 1 : 0)
                }
                .padding(.bottom, 28)

                Text("You're all set!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 10)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)

                Text("You now know the essentials.\nCreate your first entity to get started.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onGetStarted()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.app.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Create First Entity")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#5AC8FA"), Color(hex: "#0A84FF")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color(hex: "#0A84FF").opacity(0.45), radius: 16, y: 6)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onExplore()
                } label: {
                    Text("Explore on my own")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.1)) {
                appeared = true
            }
        }
    }
}
