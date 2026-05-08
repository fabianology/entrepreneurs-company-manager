import SwiftUI
import SwiftData
// ── Wallet Sleeve Component ──
struct AggressiveSleeveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius: CGFloat = 20
        let topYLeft: CGFloat = 35
        let topYRight: CGFloat = 0
        
        path.move(to: CGPoint(x: 0, y: topYLeft))
        path.addLine(to: CGPoint(x: rect.width, y: topYRight))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - radius))
        path.addArc(center: CGPoint(x: rect.width - radius, y: rect.height - radius),
                    radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: radius, y: rect.height))
        path.addArc(center: CGPoint(x: radius, y: rect.height - radius),
                    radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: 0, y: topYLeft))
        
        return path
    }
}

struct WalletSleeveView: View {
    var body: some View {
        ZStack {
            // Main Leather Body (Matte Finish)
            AggressiveSleeveShape()
                .fill(Color(hex: "#121212"))
                // Subtle overlay to simulate deep matte leather finish
                .overlay(
                    AggressiveSleeveShape()
                        .fill(Color.black.opacity(0.15))
                        .blendMode(.multiply)
                )
                .shadow(color: .black.opacity(0.6), radius: 10, y: -4)
            
            // Premium Stitching
            AggressiveSleeveShape()
                .stroke(Color(hex: "#2B3A3B"), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .padding(6)
                
            // Edge highlight
            AggressiveSleeveShape()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
        .frame(height: 120)
    }
}

// ── Shared Card Visual (Mini overlapping view for stack) ──
struct FinancialCardVisual: View {
    let card: FinancialCard
    let isPopped: Bool
    
    @Environment(AppState.self) private var appState
    
    private var subscriptions: [Subscription] { appState.subscriptions }
    
    private var paysForServices: [(name: String, cost: Double)] {
        let cardName = card.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cardName.isEmpty else { return [] }
        var results: [(name: String, cost: Double)] = []
        for sub in subscriptions {
            if (sub.paymentMethod ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == cardName {
                results.append((name: sub.name.isEmpty ? "Unnamed Service" : sub.name, cost: sub.cost))
            }
            for subSvc in sub.subServices {
                if (subSvc.paymentMethod ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == cardName {
                    results.append((name: subSvc.name.isEmpty ? "Unnamed Sub-service" : subSvc.name, cost: subSvc.cost))
                }
            }
        }
        return results
    }

    private var promoEndsString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yy"
        return formatter.string(from: card.promoEnds ?? Date())
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(
                    colors: card.cardGradientHex.map { Color(hex: $0) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(isPopped ? Color.white.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
            
            let isLight = card.cardGradientHex.first?.uppercased() == "#FFFFFF"
            let primaryColor = isLight ? Color.black : Color.white
            let secondaryColor = isLight ? Color.black.opacity(0.7) : Color.white.opacity(0.7)
            
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(card.name.isEmpty ? "Card" : card.name)
                            .font(.system(size: isPopped ? 16 : 12, weight: .bold))
                            .foregroundStyle(primaryColor)
                        
                        if !(card.last4 ?? "").isEmpty {
                            Text("•••• \(card.last4 ?? "")")
                                .font(.system(size: isPopped ? 14 : 10, weight: .semibold))
                                .foregroundStyle(secondaryColor)
                        }
                    }
                    Spacer()
                    Text("\(card.network) \(card.type)")
                        .font(.system(size: isPopped ? 14 : 12, weight: .semibold))
                        .foregroundStyle(secondaryColor)
                        .italic()
                }
                
                Spacer(minLength: 0)
                
                if isPopped {
                    HStack {
                        Text((card.cardHolder ?? "").isEmpty ? "Name on Card" : (card.cardHolder ?? ""))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isLight ? Color.black.opacity(0.6) : Color.white.opacity(0.6))
                        Spacer()
                        Text((card.expiry ?? "").isEmpty ? "—" : (card.expiry ?? ""))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(isLight ? Color.black.opacity(0.6) : Color.white.opacity(0.6))
                    }
                    .padding(.bottom, 6)
                    
                    let services = paysForServices
                    let hasFinancials = card.limit > 0 || card.balance > 0 || card.apr > 0 || card.promoApr > 0 || (card.autopay != "N/A" && !card.autopay.isEmpty)
                    
                    if hasFinancials || !(card.paidFrom ?? "").isEmpty || !services.isEmpty {
                        Divider()
                            .background(isLight ? Color.black.opacity(0.1) : Color.white.opacity(0.06))
                            .padding(.bottom, 6)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            // --- Financials Grid ---
                            if hasFinancials {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                                    if card.balance > 0 { cardMetric(title: "BALANCE", value: "$\(String(format: "%.0f", card.balance))", isLight: isLight, primaryColor: primaryColor) }
                                    if card.limit > 0 { cardMetric(title: "LIMIT", value: "$\(String(format: "%.0f", card.limit))", isLight: isLight, primaryColor: primaryColor) }
                                    if card.apr > 0 { cardMetric(title: "APR", value: "\(String(format: "%.1f", card.apr))%", isLight: isLight, primaryColor: primaryColor) }
                                    if card.promoApr > 0 { 
                                        cardMetric(title: "PROMO", value: "\(String(format: "%.1f", card.promoApr))%", isLight: isLight, primaryColor: primaryColor) 
                                        cardMetric(title: "PROMO END", value: promoEndsString, isLight: isLight, primaryColor: primaryColor)
                                    }
                                    if card.autopay != "N/A" && !card.autopay.isEmpty { cardMetric(title: "AUTO PAY", value: card.autopay, isLight: isLight, primaryColor: primaryColor) }
                                }
                                
                                if !(card.paidFrom ?? "").isEmpty || !services.isEmpty {
                                    Divider()
                                        .background(isLight ? Color.black.opacity(0.1) : Color.white.opacity(0.06))
                                }
                            }
                            
                            if !(card.paidFrom ?? "").isEmpty {
                                HStack {
                                    Text("PAY FROM")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(isLight ? Color.black.opacity(0.4) : Color.white.opacity(0.4))
                                    Spacer()
                                    Text(card.paidFrom ?? "")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(primaryColor)
                                }
                            }
                            
                            if !(card.paidFrom ?? "").isEmpty && !services.isEmpty {
                                Divider()
                                    .background(isLight ? Color.black.opacity(0.1) : Color.white.opacity(0.06))
                            }
                            
                            if !services.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("PAYS FOR")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(isLight ? Color.black.opacity(0.4) : Color.white.opacity(0.4))
                                    
                                    ForEach(Array(services.prefix(2).enumerated()), id: \.offset) { index, svc in
                                        HStack {
                                            Text(svc.name)
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(primaryColor)
                                                .lineLimit(1)
                                            Spacer()
                                            Text("$\(String(format: "%.0f", svc.cost))")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(primaryColor)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .contentShape(Rectangle())
    }
    
    @ViewBuilder
    private func cardMetric(title: String, value: String, isLight: Bool, primaryColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(isLight ? Color.black.opacity(0.4) : Color.white.opacity(0.4))
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(primaryColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

