import SwiftUI

// MARK: - Glass Card Modifier
struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 24
    var padding: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(hex: "#1C1C1E"))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Liquid Glass Modifier (ultra-thin blur layer)
struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - CiFr Modal Field style
struct CifrFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 24) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }

    func liquidGlass(cornerRadius: CGFloat = 24) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius))
    }

    func cifrField() -> some View {
        modifier(CifrFieldModifier())
    }

    func zifrLabel() -> some View {
        self
            .font(.system(size: 9, weight: .black))
            .textCase(.uppercase)
            .tracking(1.5)
            .foregroundStyle(Color.white.opacity(0.35))
    }

    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        self.onTapGesture {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }
}

// MARK: - Shimmer effect for loading
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear, Color.white.opacity(0.15), .clear
                    ]),
                    startPoint: .init(x: phase - 0.3, y: 0),
                    endPoint: .init(x: phase + 0.3, y: 0)
                )
                .blendMode(.plusLighter)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
    }
}

extension View {
    func shimmer(active: Bool = true) -> some View {
        active ? AnyView(modifier(ShimmerModifier())) : AnyView(self)
    }
}
