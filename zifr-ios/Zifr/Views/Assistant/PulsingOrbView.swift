import SwiftUI

struct PulsingOrbView: View {
    var volume: Float
    @State private var phase: CGFloat = 0
    @State private var isBreathing = false
    
    var body: some View {
        let normalizedVolume = max(0.0, min(CGFloat(volume), 1.0))
        let targetScale = 1.0 + (normalizedVolume * 0.4) // max scale 1.4
        
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color(hex: "#0A84FF").opacity(0.6), Color.clear]),
                        center: .center,
                        startRadius: 20,
                        endRadius: 150
                    )
                )
                .frame(width: 250, height: 250)
                .scaleEffect(isBreathing ? targetScale * 1.05 : targetScale * 0.95)
                .opacity(0.4 + Double(normalizedVolume) * 0.6)
                
            // Inner Core
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "#5AC8FA"), Color(hex: "#0A84FF")]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .scaleEffect(isBreathing ? targetScale * 1.02 : targetScale * 0.98)
                .shadow(color: Color(hex: "#0A84FF").opacity(0.8), radius: 20 + CGFloat(normalizedVolume * 20), x: 0, y: 0)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                )
        }
        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: volume)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }
}
