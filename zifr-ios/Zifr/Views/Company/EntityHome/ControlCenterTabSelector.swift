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
    
    var institutions: [Institution] = []
    var loans: [Loan] = []
    var subscriptions: [Subscription] = []
    var activeSubscriptions: [Subscription] = []
    var documents: [CompanyDocument] = []
    var totalDebt: Double = 0
    
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
                                .foregroundStyle(isActive ? tab.color : Color.zifrTabBarFill)
                            
                            Spacer()
                        }
                        
                        Text(tab.rawValue.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(isActive ? .white : Color.zifrTabBarFill)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(height: 54)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isActive ? Color.zifrTabBarFill.opacity(0.70) : Color.zifrTabBarFill.opacity(0.40))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
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
                    .shadow(color: Color.black.opacity(isActive ? 0.45 : 0.25), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }
}
