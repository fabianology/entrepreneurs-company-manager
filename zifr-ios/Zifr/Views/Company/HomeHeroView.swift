import SwiftUI

struct HomeHeroView: View {
    @State private var tickerService = TickerService()
    @State private var offset: CGFloat = 0
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(0..<2, id: \.self) { _ in
                        HStack(spacing: 16) {
                            ForEach(tickerService.tickers) { item in
                                tickerChip(item)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .offset(x: offset)
                .onAppear {
                    startAnimation()
                }
                .onChange(of: tickerService.tickers) { _, _ in
                    startAnimation()
                }
            }
            .frame(height: 36)
        }
        .padding(.vertical, 8)
        .task {
            await tickerService.fetchTickers()
        }
    }
    
    private func startAnimation() {
        guard !tickerService.tickers.isEmpty && !isAnimating else { return }
        
        let singleSetWidth = CGFloat(tickerService.tickers.count) * 140
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { // Delayed start to prevent navigation glitch
            withAnimation(.linear(duration: Double(tickerService.tickers.count) * 3.5).repeatForever(autoreverses: false)) {
                offset = -singleSetWidth
            }
            isAnimating = true
        }
    }
    
    private func tickerChip(_ item: TickerItem) -> some View {
        let isPositive = item.changePercent >= 0
        return HStack(spacing: 6) {
            Text(item.label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .fixedSize()
            Text("$\(String(format: "%.2f", item.price))")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.8))
                .fixedSize()
            HStack(spacing: 2) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                Text("\(String(format: "%.2f", abs(item.changePercent)))%")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(isPositive ? Color.green : Color.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }
}
