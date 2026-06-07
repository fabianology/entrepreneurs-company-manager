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

// MARK: - Liquid Glass Modifier (native HIG material)
struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Masonry Glass Modifier (Tinted Material Blur)
struct MasonryGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(hex: "#1C1C1E").opacity(0.40))
            )
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

// MARK: - Premium Dark Bar Modifier (70% Opacity Black)
struct PremiumDarkBarModifier: ViewModifier {
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.black.opacity(0.70))
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

// MARK: - Miloom Report Stroke Modifier
struct MiloomReportStrokeModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    @State private var rotation: Double = 0.0

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "#4f609a"), // Miloom Primary Start
                                Color(hex: "#f2ac5b"), // Miloom Primary End
                                Color(hex: "#15566a"), // Miloom Secondary Start
                                Color(hex: "#00544e"), // Miloom Secondary End
                                Color(hex: "#4f609a")  // Seamless loop point
                            ]),
                            center: .center,
                            angle: .degrees(rotation)
                        ),
                        lineWidth: 1.2
                    )
            )
            .onAppear {
                withAnimation(.linear(duration: 6.0).repeatForever(autoreverses: false)) {
                    rotation = 360.0
                }
            }
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

    func masonryGlass(cornerRadius: CGFloat = 12) -> some View {
        modifier(MasonryGlassModifier(cornerRadius: cornerRadius))
    }

    func premiumDarkBar(cornerRadius: CGFloat = 12) -> some View {
        modifier(PremiumDarkBarModifier(cornerRadius: cornerRadius))
    }

    func miloomReportStroke(cornerRadius: CGFloat = 12) -> some View {
        modifier(MiloomReportStrokeModifier(cornerRadius: cornerRadius))
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
