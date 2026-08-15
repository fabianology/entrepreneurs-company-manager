import SwiftUI

enum EntityHomeTab: String, CaseIterable {
    case financial = "Financial"
    case subscriptions = "Services"
    case documents = "Vault"
    
    var icon: String {
        switch self {
        case .financial: return "creditcard.fill"
        case .subscriptions: return "square.3.layers.3d"
        case .documents: return "doc.on.doc.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .financial: return Color(hex: "#1A7077")
        case .subscriptions: return Color(hex: "#2070BD")
        case .documents: return Color(hex: "#918457")
        }
    }
}

struct ControlCenterTabSelector: View {
    @Binding var activeTab: EntityHomeTab
    
    let institutions: [Institution]
    let loans: [Loan]
    let subscriptions: [Subscription]
    let activeSubscriptions: [Subscription]
    let documents: [CompanyDocument]
    let totalDebt: Double
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(EntityHomeTab.allCases, id: \.self) { tab in
                let isActive = activeTab == tab
                
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        activeTab = tab
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(isActive ? tab.color : .white)
                            
                            Spacer()
                        }
                        
                        Text(tab.rawValue.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(isActive ? tab.color : Color.white.opacity(0.7))
                            .lineLimit(1)
                        
                        // Micro Summary
                        Text(summaryText(for: tab))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(isActive ? tab.color.opacity(0.8) : Color.white.opacity(0.4))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 13)
                    .frame(height: 70)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isActive ? Color.black.opacity(0.40) : Color.black.opacity(0.70))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: isActive ? [
                                        tab.color,
                                        tab.color.opacity(0.3)
                                    ] : [
                                        Color(hex: "#3A2D6E"),
                                        Color(hex: "#16161E").opacity(0.2)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: isActive ? tab.color.opacity(0.2) : Color.black.opacity(0.4), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func summaryText(for tab: EntityHomeTab) -> String {
        switch tab {
        case .financial:
            let instCount = institutions.count
            return "\(instCount) Inst • $\(String(format: "%.0f", totalDebt)) Debt"
        case .subscriptions:
            let count = activeSubscriptions.count
            var totalMo: Double = 0
            for sub in activeSubscriptions {
                totalMo += (sub.billingCycle == "Yearly" ? (sub.cost / 12) : sub.cost)
            }
            return "\(count) Active • $\(String(format: "%.0f", totalMo))/mo"
        case .documents:
            return "\(documents.count) Files"
        }
    }
}
