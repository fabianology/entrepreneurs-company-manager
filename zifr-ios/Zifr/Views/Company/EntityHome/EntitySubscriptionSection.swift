import SwiftUI

struct EntitySubscriptionSection: View {
    let company: Company
    let activeSubscriptions: [Subscription]
    let subscriptions: [Subscription]
    let institutions: [Institution]
    let cards: [FinancialCard]
    let monthlyBurn: Double
    @Bindable var vm: AppViewModel

    @Binding var flippedHeroIndex: Int?
    @Binding var coverFlowSnappedIndex: Int
    
    var flipAnimation: Namespace.ID

    @Environment(OnboardingStateManager.self) private var onboardingState

    private let subsColor = Color(hex: "#2070BD")

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                vm.activeTab = .subscriptions
            } label: {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "square.3.layers.3d")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(subsColor)
                            .padding(.trailing, 4)
                        
                        Text("SUBSCRIPTIONS")
                            .font(.system(size: 13, weight: .black))
                            .tracking(1.5)
                            .foregroundStyle(.white)
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Text("\(activeSubscriptions.count)").font(.system(size: 14, weight: .bold)).foregroundStyle(.white) +
                            Text(" active").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.white.opacity(0.5))
                            
                            Text(formatCurrency(monthlyBurn)).font(.system(size: 14, weight: .bold)).foregroundStyle(.white) +
                            Text("/mo").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.white.opacity(0.5))
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(.leading, 4)
                    }
                    
                    let autoRenewCount = activeSubscriptions.filter { $0.isAutoRenew }.count
                    let autoRenewRatio = activeSubscriptions.isEmpty ? 0.0 : Double(autoRenewCount) / Double(activeSubscriptions.count)
                    let autoRenewPct = Int(autoRenewRatio * 100)
                    
                    HStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.1))
                                Capsule()
                                    .fill(LinearGradient(colors: [subsColor, subsColor.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * CGFloat(autoRenewRatio))
                            }
                        }
                        .frame(height: 4)
                        
                        let pctString = String(autoRenewPct)
                        Text("\(pctString)% Auto-Renew")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .background(Color.black.opacity(0.70))
                .overlay(
                    Rectangle().frame(height: 1).foregroundStyle(Color.white.opacity(0.08)),
                    alignment: .bottom
                )
            }
            .buttonStyle(.plain)

            VStack(spacing: 10) {
                VStack(spacing: 0) {
                if activeSubscriptions.isEmpty {
                    Text("No subscriptions")
                        .foregroundStyle(.gray)
                        .padding(.vertical, 20)
                } else {
                    let loopCount = max(5, 150 / max(1, activeSubscriptions.count))
                    let infiniteSubs = Array(repeating: activeSubscriptions, count: loopCount).flatMap { $0 }
                    let startIndex = (loopCount / 2) * activeSubscriptions.count
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(infiniteSubs.enumerated()), id: \.offset) { index, sub in
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                            flippedHeroIndex = index
                                        }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 6) {
                                            if let website = sub.website, !website.isEmpty {
                                                FaviconImage(website: website, size: 24)
                                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                            } else {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 6).fill(brandColor(sub.name).opacity(0.2)).frame(width: 24, height: 24)
                                                    Text(sub.name.prefix(1).uppercased()).font(.system(size: 10, weight: .black)).foregroundStyle(brandColor(sub.name))
                                                }
                                            }
                                            
                                            Text(sub.name)
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(.white)
                                                .lineLimit(1)
                                            
                                            Text(formatCurrency(sub.cost))
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(.white.opacity(0.8))
                                        }
                                        .padding(8)
                                        .frame(width: 80, height: 90, alignment: .leading)
                                        .background(Color(hex: "#1C1C1E"))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                        .matchedGeometryEffect(id: "flipBg-\(index)", in: flipAnimation)
                                    }
                                    .buttonStyle(.plain)
                                    .id(index)
                                }
                            }
                            .scrollTargetLayout()
                            .padding(.horizontal, 20)
                        }
                        .scrollTargetBehavior(.viewAligned)
                        .frame(height: 106)
                        .onAppear {
                            proxy.scrollTo(startIndex, anchor: .center)
                        }
                    }
                }
            }
            
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color(hex: "#1C1C1E").opacity(0.70))
        .frame(maxWidth: .infinity)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .spotlightTarget(isActive: onboardingState.isSpotlightingCommandCenterSubscriptions)
        .padding(.horizontal, 20)
        .zIndex(1)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        if value == 0 { return "$0" }
        if value >= 1000 { return "$\(String(format: "%.1fk", value / 1000))" }
        return "$\(String(format: "%.0f", value))"
    }

    private func formatDue(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df.string(from: date)
    }
    
    private func formattedDueOn(_ sub: Subscription) -> String {
        guard !(sub.nextRenewal ?? "").isEmpty else { return "Unknown" }
        func ordinal(_ n: Int) -> String {
            let tens = (n % 100) / 10
            if tens == 1 { return "\(n)th" }
            switch n % 10 {
            case 1: return "\(n)st"
            case 2: return "\(n)nd"
            case 3: return "\(n)rd"
            default: return "\(n)th"
            }
        }
        if sub.billingCycle == "Monthly" {
            if let day = Int(sub.nextRenewal ?? "") { return "\(ordinal(day)) every mo." }
            return (sub.nextRenewal ?? "") + " every mo."
        } else {
            let parts = (sub.nextRenewal ?? "").split(separator: " ")
            if parts.count == 2, let day = Int(parts[1]) {
                return "\(parts[0]) \(ordinal(day)) every yr."
            }
            return (sub.nextRenewal ?? "") + " every yr."
        }
    }
    
    private func brandColor(_ name: String) -> Color {
        let hash = abs(name.unicodeScalars.reduce(0) { ($0 << 5) &+ $0 &+ Int($1.value) })
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.65, brightness: 0.75)
    }
}
