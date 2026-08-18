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
    
    // Interactive drag state
    @State private var dragPositionX: CGFloat? = nil
    @State private var hoveredIndex: Int = 0
    @State private var lastHapticIndex: Int = 0
    
    // Legacy props (kept for call-site compatibility)
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
    
    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let innerPadding: CGFloat = 4
            let availableWidth = max(0, totalWidth - (innerPadding * 2))
            let tabWidth = availableWidth / CGFloat(tabs.count)
            let tabHeight: CGFloat = 46
            
            // Calculate pill X offset based on active state or active drag
            let restingPillX = innerPadding + (CGFloat(currentIndex) * tabWidth)
            let currentPillX: CGFloat = {
                if let dragX = dragPositionX {
                    let minX = innerPadding
                    let maxX = innerPadding + (CGFloat(tabs.count - 1) * tabWidth)
                    let centerOffset = dragX - (tabWidth / 2)
                    
                    if centerOffset < minX {
                        return minX - ((minX - centerOffset) * 0.2) // Rubberband left
                    } else if centerOffset > maxX {
                        return maxX + ((centerOffset - maxX) * 0.2) // Rubberband right
                    } else {
                        return centerOffset
                    }
                } else {
                    return restingPillX
                }
            }()
            
            ZStack(alignment: .leading) {
                // 1. Sliding Pill (Active Indicator)
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.zifrTabBarFill.opacity(0.70))
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
                    .frame(width: tabWidth, height: tabHeight)
                    .offset(x: currentPillX)
                    .animation(dragPositionX == nil ? .spring(response: 0.32, dampingFraction: 0.82) : nil, value: currentPillX)
                
                // 2. Tab Labels (Interactive Grid)
                HStack(spacing: 0) {
                    ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                        let isHighlighted = (dragPositionX != nil ? hoveredIndex == index : activeTab == tab)
                        
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(isHighlighted ? tab.color : Color.zifrTabBarFill)
                            
                            Text(tab.rawValue.uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(isHighlighted ? .white : Color.zifrTabBarFill)
                                .lineLimit(1)
                        }
                        .frame(width: tabWidth, height: tabHeight)
                        .contentShape(Rectangle())
                        .animation(.easeInOut(duration: 0.15), value: isHighlighted)
                    }
                }
                .padding(.horizontal, innerPadding)
            }
            .frame(width: totalWidth, height: tabHeight + (innerPadding * 2), alignment: .leading)
            .contentShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 16,
                    bottomTrailingRadius: 16,
                    topTrailingRadius: 0
                )
            )
            // Gesture recognizer for fluid direct sliding + instant tapping
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        let touchX = value.location.x
                        dragPositionX = touchX
                        
                        let relativeX = max(0, min(availableWidth, touchX - innerPadding))
                        let newIndex = min(tabs.count - 1, max(0, Int(relativeX / tabWidth)))
                        
                        if newIndex != hoveredIndex {
                            hoveredIndex = newIndex
                            if newIndex != lastHapticIndex {
                                lastHapticIndex = newIndex
                                selectionFeedback.selectionChanged()
                                selectionFeedback.prepare()
                            }
                        }
                    }
                    .onEnded { value in
                        let predictedX = value.location.x + (value.velocity.width * 0.08)
                        let relativeX = max(0, min(availableWidth, predictedX - innerPadding))
                        let finalIndex = min(tabs.count - 1, max(0, Int(round(relativeX / tabWidth))))
                        
                        dragPositionX = nil
                        hoveredIndex = finalIndex
                        lastHapticIndex = finalIndex
                        
                        impactFeedback.impactOccurred()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            activeTab = tabs[finalIndex]
                        }
                    }
            )
        }
        .frame(height: 54)
        .padding(.horizontal, 20)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 16,
                topTrailingRadius: 0
            )
            .fill(Color.zifrTabBarFill.opacity(0.40))
            .padding(.top, -30)
            .padding(.horizontal, 20)
        )
        .onAppear {
            hoveredIndex = currentIndex
            lastHapticIndex = currentIndex
            selectionFeedback.prepare()
            impactFeedback.prepare()
        }
    }
}
