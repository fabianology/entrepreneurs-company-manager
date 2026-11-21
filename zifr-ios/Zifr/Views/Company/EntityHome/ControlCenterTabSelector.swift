import SwiftUI

private struct ActiveTabLensLabelMotion: AnimatableModifier {
    var position: CGFloat
    let destination: CGFloat
    let tabWidth: CGFloat
    let innerPadding: CGFloat

    var animatableData: CGFloat {
        get { position }
        set { position = newValue }
    }

    func body(content: Content) -> some View {
        let distance = min(1, abs(position - destination))
        let overlap = 1 - distance
        let rawReveal = max(0, min(1, (overlap - 0.5) / 0.5))
        let reveal = rawReveal * rawReveal * (3 - (2 * rawReveal))

        content
            .opacity(reveal)
            .blur(radius: (1 - reveal) * 3)
            .scaleEffect(0.96 + (0.04 * reveal))
            .offset(
                x: innerPadding + (position * tabWidth),
                y: (1 - reveal) * 1.5
            )
    }
}

enum EntityHomeTab: String, CaseIterable {
    case financial = "Financial"
    case subscriptions = "Services"
    case documents = "Vault"
    
    var icon: String {
        switch self {
        case .financial: return "dollarsign.bank.building"
        case .subscriptions: return "square.3.layers.3d"
        case .documents: return "doc.on.doc.fill"
        }
    }
    
    var color: Color {
        Color(hex: "#1A7077")
    }
}

struct ControlCenterTabSelector: View {
    @Binding var activeTab: EntityHomeTab
    // Optional standalone configuration for the Duo portrait report selector.
    // Defaults preserve the existing Financial/Services/Vault control.
    var labels: [EntityHomeTab: String] = [:]
    var icons: [EntityHomeTab: String] = [:]
    var isStandalone = false
    var backgroundTopExtension: CGFloat = 0
    var contentBottomInset: CGFloat?
    var usesReducedMotion = false

    private func title(for tab: EntityHomeTab) -> String { labels[tab] ?? tab.rawValue }
    private func icon(for tab: EntityHomeTab) -> String { icons[tab] ?? tab.icon }
    
    // Smooth interaction state
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var activeHover: Int? = nil
    @State private var lastHapticIndex: Int = -1
    
    // Legacy props
    var institutions: [Institution] = []
    var loans: [Loan] = []
    var subscriptions: [Subscription] = []
    var activeSubscriptions: [Subscription] = []
    var documents: [CompanyDocument] = []
    var totalDebt: Double = 0
    
    private let tabs = EntityHomeTab.allCases
    private let tabHeight: CGFloat = 48
    private let trackPadding: CGFloat = 4
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    
    private var currentIndex: Int {
        tabs.firstIndex(of: activeTab) ?? 0
    }

    @ViewBuilder
    private func tabBarGlassBackground<S: Shape>(
        _ shape: S,
        tintOpacity: Double = 0.28
    ) -> some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(
                    .clear
                        .tint(Color.zifrTabBarFill.opacity(tintOpacity))
                        .interactive(),
                    in: shape
                )
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay(
                    shape.fill(Color.zifrTabBarFill.opacity(tintOpacity))
                )
        }
    }

    private func selectTab(_ tab: EntityHomeTab) {
        impactFeedback.impactOccurred()
        guard tab != activeTab else { return }

        withAnimation(usesReducedMotion ? nil : .spring(response: 0.36, dampingFraction: 0.82)) {
            activeTab = tab
            dragOffset = 0
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            selector(width: geometry.size.width)
                .offset(y: contentBottomInset.map { trackPadding - $0 } ?? 0)
        }
        .frame(height: tabHeight + trackPadding * 2)
        .padding(.horizontal, 20)
        .background {
            if isStandalone {
                tabBarGlassBackground(RoundedRectangle(cornerRadius: 16))
                    .padding(.top, -backgroundTopExtension)
                    .padding(.horizontal, 20)
            } else {
                tabBarGlassBackground(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 16,
                        bottomTrailingRadius: 16,
                        topTrailingRadius: 0
                    )
                )
                .padding(.top, -30)
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            lastHapticIndex = currentIndex
        }
        .onChange(of: activeTab) { _, _ in
            dragOffset = 0
            isDragging = false
            activeHover = nil
        }
    }

    private func selector(width totalW: CGFloat) -> some View {
        let innerPadding = trackPadding
        let availableW = max(0, totalW - (innerPadding * 2))
        let tabW = max(1, availableW / CGFloat(tabs.count))
        
        let baseOffset = innerPadding + (CGFloat(currentIndex) * tabW)
        let targetOffset = baseOffset + dragOffset
        
        // Rubber banding calculation
        let minX = innerPadding
        let maxX = innerPadding + (CGFloat(tabs.count - 1) * tabW)
        let clampedOffset: CGFloat = {
            if targetOffset < minX {
                return minX - ((minX - targetOffset) * 0.25)
            } else if targetOffset > maxX {
                return maxX + ((targetOffset - maxX) * 0.25)
            } else {
                return targetOffset
            }
        }()
        let pillPosition = (clampedOffset - innerPadding) / tabW
        let displayedIndex = min(
            tabs.count - 1,
            max(0, Int(round(pillPosition)))
        )
        let displayedTab = tabs[displayedIndex]
        let pillAnimation: Animation? = usesReducedMotion ? nil : isDragging
            ? Animation.interactiveSpring(response: 0.15, dampingFraction: 0.86)
            : Animation.spring(response: 0.3, dampingFraction: 0.75)
        
        return ZStack(alignment: .leading) {
            // 1. Sliding Pill (Active Indicator) - Liquid Glass Pill
            tabBarGlassBackground(
                RoundedRectangle(cornerRadius: 14),
                tintOpacity: 0.42
            )
                .frame(width: tabW, height: tabHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#918457"),
                                    Color(hex: "#918457").opacity(0.3)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.black.opacity(0.45), radius: 6, x: 0, y: 3)
                .offset(x: clampedOffset)
                // When dragging, use interactiveSpring for instantaneous smooth tracking.
                // When released, use a bouncy spring to settle into the slot.
                .animation(pillAnimation, value: clampedOffset)
                // Render the glass above the labels so it refracts their pixels like a lens,
                // while allowing the buttons underneath to continue receiving interaction.
                .allowsHitTesting(false)
                .zIndex(1)
            
            // 2. Tab Labels (Tap targets)
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                    let isHighlighted = (activeHover != nil ? activeHover == index : currentIndex == index)
                    
                    Button(action: {
                        selectTab(tab)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: icon(for: tab))
                                .font(.system(size: 13.5, weight: .bold))
                                .foregroundStyle(isHighlighted ? tab.color : Color.white.opacity(0.40))
                            
                            Text(title(for: tab).uppercased())
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(isHighlighted ? .white : Color.white.opacity(0.45))
                                .lineLimit(isStandalone ? 2 : 1)
                                .minimumScaleFactor(0.85)
                                .multilineTextAlignment(.center)
                        }
                        .frame(width: tabW, height: tabHeight)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isStandalone && currentIndex == index ? .isSelected : [])
                    .animation(usesReducedMotion ? nil : .easeInOut(duration: 0.15), value: isHighlighted)
                }
            }
            .padding(.horizontal, innerPadding)
            .zIndex(0)

            // A crisp label floats over the lens. Its visibility is derived from how much
            // of the destination tab the pill actually covers, so it never pops in abruptly.
            HStack(spacing: 6) {
                Image(systemName: icon(for: displayedTab))
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(Color(hex: "#C1AA78"))

                Text(title(for: displayedTab).uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(isStandalone ? 2 : 1)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
            }
            .frame(width: tabW, height: tabHeight)
            .modifier(
                ActiveTabLensLabelMotion(
                    position: pillPosition,
                    destination: CGFloat(displayedIndex),
                    tabWidth: tabW,
                    innerPadding: innerPadding
                )
            )
            .animation(pillAnimation, value: clampedOffset)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .zIndex(2)
        }
        .frame(width: totalW, height: tabHeight + (innerPadding * 2), alignment: .leading)
        .contentShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 16,
                topTrailingRadius: 0
            )
        )
        // High priority drag gesture overrides parent scroll/swipe
        .highPriorityGesture(
            DragGesture(minimumDistance: 5, coordinateSpace: .local)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        selectionFeedback.prepare()
                        impactFeedback.prepare()
                    }
                    dragOffset = value.translation.width
                    
                    // Haptic feedback as it crosses tab boundaries
                    let center = clampedOffset + (tabW / 2) - innerPadding
                    let hover = min(tabs.count - 1, max(0, Int(center / tabW)))
                    
                    activeHover = hover
                    if hover != lastHapticIndex {
                        lastHapticIndex = hover
                        selectionFeedback.selectionChanged()
                        selectionFeedback.prepare()
                    }
                }
                .onEnded { value in
                    let velX = value.velocity.width
                    let flingX = value.predictedEndTranslation.width
                    
                    var targetIndex = currentIndex
                    
                    // Evaluate momentum fling
                    if velX > 200 || flingX > tabW * 0.4 {
                        targetIndex = min(tabs.count - 1, currentIndex + 1)
                    } else if velX < -200 || flingX < -tabW * 0.4 {
                        targetIndex = max(0, currentIndex - 1)
                    } else {
                        // Settle on nearest
                        let releaseCenter = clampedOffset + (tabW / 2) - innerPadding
                        targetIndex = min(tabs.count - 1, max(0, Int(round(releaseCenter / tabW))))
                    }
                    
                    lastHapticIndex = targetIndex
                    
                    impactFeedback.impactOccurred()
                    withAnimation(usesReducedMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75)) {
                        activeTab = tabs[targetIndex]
                        dragOffset = 0
                        isDragging = false
                        activeHover = nil
                    }
                }
        )
    }
}
