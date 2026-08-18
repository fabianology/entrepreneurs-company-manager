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
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var visualHoverIndex: Int = 0
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
            
            // Base offset for current active tab
            let baseOffset = innerPadding + (CGFloat(currentIndex) * tabWidth)
            
            // Continuous position with rubber-banding
            let pillOffset: CGFloat = {
                let target = baseOffset + dragOffset
                let minOffset = innerPadding
                let maxOffset = innerPadding + (CGFloat(tabs.count - 1) * tabWidth)
                
                if target < minOffset {
                    return minOffset - ((minOffset - target) * 0.22)
                } else if target > maxOffset {
                    return maxOffset + ((target - maxOffset) * 0.22)
                } else {
                    return target
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
                    .offset(x: pillOffset)
                    .animation(isDragging ? .interactiveSpring(response: 0.15, dampingFraction: 0.86) : .spring(response: 0.28, dampingFraction: 0.82), value: pillOffset)
                
                // 2. Tab Labels (Interactive Grid)
                HStack(spacing: 0) {
                    ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                        let isHighlighted = (isDragging ? visualHoverIndex == index : activeTab == tab)
                        
                        Button {
                            selectTab(index: index)
                        } label: {
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
                            .frame(width: tabWidth, height: tabHeight)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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
            // Gesture recognizer for direct sliding and fling
            .gesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .local)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            selectionFeedback.prepare()
                        }
                        dragOffset = value.translation.width
                        
                        // Calculate which tab the pill center is hovering over
                        let centerPosition = pillOffset + (tabWidth / 2) - innerPadding
                        let currentHover = min(tabs.count - 1, max(0, Int(centerPosition / tabWidth)))
                        
                        if currentHover != visualHoverIndex {
                            visualHoverIndex = currentHover
                            if currentHover != lastHapticIndex {
                                lastHapticIndex = currentHover
                                selectionFeedback.selectionChanged()
                                selectionFeedback.prepare()
                            }
                        }
                    }
                    .onEnded { value in
                        let flingX = value.predictedEndTranslation.width
                        let transX = value.translation.width
                        
                        var destinationIndex = currentIndex
                        
                        // Fling or Drag determination
                        if flingX > 35 || transX > tabWidth * 0.4 {
                            // Fling right -> advance to next tab
                            destinationIndex = min(tabs.count - 1, currentIndex + 1)
                        } else if flingX < -35 || transX < -tabWidth * 0.4 {
                            // Fling left -> retreat to previous tab
                            destinationIndex = max(0, currentIndex - 1)
                        } else {
                            // Settle on the closest tab to current position
                            let centerPosition = pillOffset + (tabWidth / 2) - innerPadding
                            destinationIndex = min(tabs.count - 1, max(0, Int(round(centerPosition / tabWidth))))
                        }
                        
                        isDragging = false
                        dragOffset = 0
                        visualHoverIndex = destinationIndex
                        lastHapticIndex = destinationIndex
                        
                        impactFeedback.impactOccurred()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            activeTab = tabs[destinationIndex]
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
            visualHoverIndex = currentIndex
            lastHapticIndex = currentIndex
            selectionFeedback.prepare()
            impactFeedback.prepare()
        }
        .onChange(of: activeTab) { _, newTab in
            let newIdx = tabs.firstIndex(of: newTab) ?? 0
            visualHoverIndex = newIdx
            lastHapticIndex = newIdx
        }
    }
    
    private func selectTab(index: Int) {
        let safeIndex = min(tabs.count - 1, max(0, index))
        guard safeIndex != currentIndex else { return }
        
        impactFeedback.impactOccurred()
        visualHoverIndex = safeIndex
        lastHapticIndex = safeIndex
        
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            dragOffset = 0
            isDragging = false
            activeTab = tabs[safeIndex]
        }
    }
}
