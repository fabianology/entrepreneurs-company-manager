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
    
    // Interactive drag & fling state
    @State private var dragTranslationX: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var startPillX: CGFloat = 0
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
            let tabHeight: CGFloat = 48
            
            // Resting pill X coordinate
            let restingPillX = innerPadding + (CGFloat(currentIndex) * tabWidth)
            
            // Dynamic pill position during drag or rest
            let currentPillX: CGFloat = {
                if isDragging {
                    let rawX = startPillX + dragTranslationX
                    let minX = innerPadding
                    let maxX = innerPadding + (CGFloat(tabs.count - 1) * tabWidth)
                    
                    if rawX < minX {
                        return minX + ((rawX - minX) * 0.25) // Rubberband left
                    } else if rawX > maxX {
                        return maxX + ((rawX - maxX) * 0.25) // Rubberband right
                    } else {
                        return rawX
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
                    .animation(isDragging ? nil : .spring(response: 0.28, dampingFraction: 0.84), value: currentPillX)
                
                // 2. Tab Labels (Interactive Grid)
                HStack(spacing: 0) {
                    ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                        let isHighlighted = (isDragging ? hoveredIndex == index : activeTab == tab)
                        
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(isHighlighted ? tab.color : Color.zifrTabBarFill)
                            
                            Text(tab.rawValue.uppercased())
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(isHighlighted ? .white : Color.zifrTabBarFill)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
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
            // Gesture recognizer for fluid relative sliding, fling velocity, and instant taps
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            startPillX = restingPillX
                            selectionFeedback.prepare()
                        }
                        dragTranslationX = value.translation.width
                        
                        let rawX = startPillX + dragTranslationX
                        let currentCenter = rawX + (tabWidth / 2)
                        let fractionalIndex = (currentCenter - innerPadding) / tabWidth
                        let activeHover = min(tabs.count - 1, max(0, Int(floor(fractionalIndex))))
                        
                        if activeHover != hoveredIndex {
                            hoveredIndex = activeHover
                            if activeHover != lastHapticIndex {
                                lastHapticIndex = activeHover
                                selectionFeedback.selectionChanged()
                                selectionFeedback.prepare()
                            }
                        }
                    }
                    .onEnded { value in
                        let velocityX = value.velocity.width
                        let translationX = value.translation.width
                        
                        var targetIndex = currentIndex
                        
                        // Fling gesture detection
                        if velocityX > 250 {
                            // Flinging Right -> next tab
                            targetIndex = min(tabs.count - 1, currentIndex + 1)
                        } else if velocityX < -250 {
                            // Flinging Left -> previous tab
                            targetIndex = max(0, currentIndex - 1)
                        } else if abs(translationX) > 10 {
                            // Drag release without high velocity: choose nearest tab
                            let currentCenter = (startPillX + translationX) + (tabWidth / 2)
                            let fractionalIndex = (currentCenter - innerPadding) / tabWidth
                            targetIndex = min(tabs.count - 1, max(0, Int(round(fractionalIndex))))
                        } else {
                            // Simple tap: calculate tab from tap location
                            let tapX = value.startLocation.x - innerPadding
                            let tappedIndex = min(tabs.count - 1, max(0, Int(tapX / tabWidth)))
                            targetIndex = tappedIndex
                        }
                        
                        isDragging = false
                        dragTranslationX = 0
                        hoveredIndex = targetIndex
                        lastHapticIndex = targetIndex
                        
                        impactFeedback.impactOccurred()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                            activeTab = tabs[targetIndex]
                        }
                    }
            )
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
        .onAppear {
            hoveredIndex = currentIndex
            lastHapticIndex = currentIndex
            selectionFeedback.prepare()
            impactFeedback.prepare()
        }
    }
}
