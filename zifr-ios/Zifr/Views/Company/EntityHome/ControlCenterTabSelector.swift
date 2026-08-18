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
    
    // Smooth 120Hz gesture state tracking
    @State private var pillX: CGFloat = 4
    @GestureState private var dragTranslation: CGFloat = 0
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
        GeometryReader { geo in
            let totalW = geo.size.width
            let innerPadding: CGFloat = 4
            let availableW = max(0, totalW - (innerPadding * 2))
            let tabW = availableW / CGFloat(tabs.count)
            let tabH: CGFloat = 48
            
            let rawX = pillX + dragTranslation
            let minX = innerPadding
            let maxX = innerPadding + (CGFloat(tabs.count - 1) * tabW)
            
            let currentX: CGFloat = {
                if rawX < minX {
                    return minX - ((minX - rawX) * 0.2)
                } else if rawX > maxX {
                    return maxX + ((rawX - maxX) * 0.2)
                } else {
                    return rawX
                }
            }()
            
            let activeHover: Int = {
                let center = currentX + (tabW / 2) - innerPadding
                return min(tabs.count - 1, max(0, Int(center / tabW)))
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
                    .frame(width: tabW, height: tabH)
                    .offset(x: currentX)
                
                // 2. Tab Labels
                HStack(spacing: 0) {
                    ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                        let isHighlighted = (dragTranslation != 0 ? activeHover == index : activeTab == tab)
                        
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13.5, weight: .bold))
                                .foregroundStyle(isHighlighted ? tab.color : Color.zifrTabBarFill)
                            
                            Text(tab.rawValue.uppercased())
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(isHighlighted ? .white : Color.zifrTabBarFill)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(width: tabW, height: tabH)
                        .contentShape(Rectangle())
                        .animation(.easeInOut(duration: 0.12), value: isHighlighted)
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
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .updating($dragTranslation) { value, state, _ in
                        state = value.translation.width
                    }
                    .onChanged { value in
                        let center = (pillX + value.translation.width) + (tabW / 2) - innerPadding
                        let hover = min(tabs.count - 1, max(0, Int(center / tabW)))
                        if hover != lastHapticIndex {
                            lastHapticIndex = hover
                            selectionFeedback.selectionChanged()
                            selectionFeedback.prepare()
                        }
                    }
                    .onEnded { value in
                        let flingX = value.predictedEndTranslation.width
                        let transX = value.translation.width
                        let velX = value.velocity.width
                        
                        var targetIndex = currentIndex
                        
                        // Tap detection
                        if abs(transX) < 6 {
                            let tapX = value.startLocation.x - innerPadding
                            targetIndex = min(tabs.count - 1, max(0, Int(tapX / tabW)))
                        }
                        // Fling detection (high velocity or high predicted travel)
                        else if velX > 180 || flingX > tabW * 0.30 {
                            targetIndex = min(tabs.count - 1, currentIndex + 1)
                        } else if velX < -180 || flingX < -tabW * 0.30 {
                            targetIndex = max(0, currentIndex - 1)
                        }
                        // Drag release (closest slot)
                        else {
                            let releaseCenter = (pillX + transX) + (tabW / 2) - innerPadding
                            targetIndex = min(tabs.count - 1, max(0, Int(round(releaseCenter / tabW))))
                        }
                        
                        let finalX = innerPadding + CGFloat(targetIndex) * tabW
                        lastHapticIndex = targetIndex
                        
                        impactFeedback.impactOccurred()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            pillX = finalX
                            activeTab = tabs[targetIndex]
                        }
                    }
            )
            .onAppear {
                let idx = tabs.firstIndex(of: activeTab) ?? 0
                pillX = innerPadding + CGFloat(idx) * tabW
                lastHapticIndex = idx
                selectionFeedback.prepare()
                impactFeedback.prepare()
            }
            .onChange(of: activeTab) { _, newTab in
                let idx = tabs.firstIndex(of: newTab) ?? 0
                let targetX = innerPadding + CGFloat(idx) * tabW
                if pillX != targetX {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        pillX = targetX
                    }
                }
            }
        }
        .frame(height: 56)
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
    }
}
