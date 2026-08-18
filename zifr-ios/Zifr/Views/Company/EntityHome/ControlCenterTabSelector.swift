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
    @State private var hoverIndex: Int = 0
    @State private var lastHapticIndex: Int = 0
    @State private var trackWidth: CGFloat = 0
    
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
    
    private let innerPadding: CGFloat = 4
    private let tabHeight: CGFloat = 48
    
    private var calculatedTabWidth: CGFloat {
        let baseWidth = (trackWidth > 0 ? trackWidth : (UIScreen.main.bounds.width - 40))
        let available = max(0, baseWidth - (innerPadding * 2))
        return available / CGFloat(tabs.count)
    }
    
    private var pillOffset: CGFloat {
        let tabW = calculatedTabWidth
        let base = innerPadding + (CGFloat(currentIndex) * tabW)
        if isDragging {
            let target = base + dragOffset
            let minOffset = innerPadding
            let maxOffset = innerPadding + (CGFloat(tabs.count - 1) * tabW)
            if target < minOffset {
                return minOffset - ((minOffset - target) * 0.22)
            } else if target > maxOffset {
                return maxOffset + ((target - maxOffset) * 0.22)
            } else {
                return target
            }
        } else {
            return base
        }
    }
    
    var body: some View {
        let tabW = calculatedTabWidth
        
        ZStack(alignment: .leading) {
            // 1. Track Background (attached seamlessly under header)
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 16,
                topTrailingRadius: 0
            )
            .fill(Color.zifrTabBarFill.opacity(0.40))
            .padding(.top, -30)
            
            // 2. Sliding Pill (Active Indicator)
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
                .frame(width: tabW, height: tabHeight)
                .offset(x: pillOffset)
            
            // 3. Tab Labels
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                    let isHighlighted = (isDragging ? hoverIndex == index : activeTab == tab)
                    
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
                    .frame(width: tabW, height: tabHeight)
                    .contentShape(Rectangle())
                    .animation(.easeInOut(duration: 0.15), value: isHighlighted)
                }
            }
            .padding(.horizontal, innerPadding)
        }
        .frame(height: 56)
        .padding(.horizontal, 20)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: TrackWidthKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(TrackWidthKey.self) { width in
            if width > 0 {
                trackWidth = width
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        selectionFeedback.prepare()
                        impactFeedback.prepare()
                    }
                    dragOffset = value.translation.width
                    
                    let center = pillOffset + (tabW / 2) - innerPadding
                    let hover = min(tabs.count - 1, max(0, Int(round(center / tabW))))
                    
                    if hover != hoverIndex {
                        hoverIndex = hover
                        if hover != lastHapticIndex {
                            lastHapticIndex = hover
                            selectionFeedback.selectionChanged()
                            selectionFeedback.prepare()
                        }
                    }
                }
                .onEnded { value in
                    let transX = value.translation.width
                    let predictedTransX = value.predictedEndTranslation.width
                    let velocityX = value.velocity.width
                    
                    var targetIndex = currentIndex
                    
                    // Tap detection (minimal movement)
                    if abs(transX) < 6 {
                        let tapX = value.startLocation.x - 20 - innerPadding
                        let tappedIdx = min(tabs.count - 1, max(0, Int(tapX / tabW)))
                        targetIndex = tappedIdx
                    }
                    // Fling detection (high velocity or high predicted travel)
                    else if velocityX > 200 || predictedTransX > tabW * 0.35 {
                        targetIndex = min(tabs.count - 1, currentIndex + 1)
                    } else if velocityX < -200 || predictedTransX < -tabW * 0.35 {
                        targetIndex = max(0, currentIndex - 1)
                    }
                    // Drag release based on position
                    else {
                        let finalCenter = pillOffset + (tabW / 2) - innerPadding
                        targetIndex = min(tabs.count - 1, max(0, Int(round(finalCenter / tabW))))
                    }
                    
                    isDragging = false
                    dragOffset = 0
                    hoverIndex = targetIndex
                    lastHapticIndex = targetIndex
                    
                    impactFeedback.impactOccurred()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        activeTab = tabs[targetIndex]
                    }
                }
        )
        .animation(isDragging ? nil : .spring(response: 0.28, dampingFraction: 0.78), value: activeTab)
        .onAppear {
            hoverIndex = currentIndex
            lastHapticIndex = currentIndex
            selectionFeedback.prepare()
            impactFeedback.prepare()
        }
        .onChange(of: activeTab) { _, newTab in
            let newIdx = tabs.firstIndex(of: newTab) ?? 0
            hoverIndex = newIdx
            lastHapticIndex = newIdx
        }
    }
}

private struct TrackWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
