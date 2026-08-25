import SwiftUI

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
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    
    private var currentIndex: Int {
        tabs.firstIndex(of: activeTab) ?? 0
    }

    @ViewBuilder
    private func tabBarGlassBackground<S: Shape>(_ shape: S) -> some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(
                    .clear
                        .tint(Color.zifrTabBarFill.opacity(0.28))
                        .interactive(),
                    in: shape
                )
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay(
                    shape.fill(Color.zifrTabBarFill.opacity(0.30))
                )
        }
    }
    
    var body: some View {
        // Calculate static widths
        let totalW = UIScreen.main.bounds.width - 40 // Based on .padding(.horizontal, 20)
        let innerPadding: CGFloat = 4
        let availableW = max(0, totalW - (innerPadding * 2))
        let tabW = availableW / CGFloat(tabs.count)
        let tabH: CGFloat = 48
        
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
        
        ZStack(alignment: .leading) {
            // 1. Sliding Pill (Active Indicator) - Liquid Glass Pill
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.zifrTabBarFill.opacity(0.70))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .clipShape(RoundedRectangle(cornerRadius: 14))
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
                .frame(width: tabW, height: tabH)
                .offset(x: clampedOffset)
                // When dragging, use interactiveSpring for instantaneous smooth tracking.
                // When released, use a bouncy spring to settle into the slot.
                .animation(isDragging ? .interactiveSpring(response: 0.15, dampingFraction: 0.86) : .spring(response: 0.3, dampingFraction: 0.75), value: clampedOffset)
            
            // 2. Tab Labels (Tap targets)
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                    let isHighlighted = (activeHover != nil ? activeHover == index : currentIndex == index)
                    
                    Button(action: {
                        impactFeedback.impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            activeTab = tab
                            dragOffset = 0
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13.5, weight: .bold))
                                .foregroundStyle(isHighlighted ? tab.color : Color.white.opacity(0.40))
                            
                            Text(tab.rawValue.uppercased())
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(isHighlighted ? .white : Color.white.opacity(0.45))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(width: tabW, height: tabH)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: isHighlighted)
                }
            }
            .padding(.horizontal, innerPadding)
        }
        .frame(width: totalW, height: tabH + (innerPadding * 2), alignment: .leading)
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
                    let transX = value.translation.width
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
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        activeTab = tabs[targetIndex]
                        dragOffset = 0
                        isDragging = false
                        activeHover = nil
                    }
                }
        )
        .frame(height: 56)
        .padding(.horizontal, 20)
        .background(
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
        )
        .onAppear {
            lastHapticIndex = currentIndex
        }
    }
}
