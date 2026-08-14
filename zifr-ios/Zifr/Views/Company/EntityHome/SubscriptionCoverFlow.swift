import SwiftUI

struct SubscriptionCoverFlow: View {
    let activeSubscriptions: [Subscription]
    @Binding var flippedHeroIndex: Int?
    @Binding var coverFlowSnappedIndex: Int
    var flipAnimation: Namespace.ID

    var body: some View {
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

    private func formatCurrency(_ value: Double) -> String {
        if value == 0 { return "$0" }
        if value >= 1000 { return "$\(String(format: "%.1fk", value / 1000))" }
        return "$\(String(format: "%.0f", value))"
    }

    private func brandColor(_ name: String) -> Color {
        let hash = abs(name.unicodeScalars.reduce(0) { ($0 << 5) &+ $0 &+ Int($1.value) })
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.65, brightness: 0.75)
    }
}
