import SwiftUI

// MARK: - Zifr Sheet Card
/// A reusable, high-fidelity card container matching the signature Institution Card aesthetic.
/// Features a dark frosted glass background, subtle indigo gradient border, and an optional
/// top dark header band with icon, gold/white tracking title, count badges, and action views.
struct ZifrSheetCard<Content: View, Trailing: View>: View {
    var title: String? = nil
    var icon: String? = nil
    var subtitle: String? = nil
    var badgeCount: Int? = nil
    var cornerRadius: CGFloat = 24
    var headerLeadingPadding: CGFloat = 20
    var headerTrailingPadding: CGFloat = 20
    var contentHorizontalPadding: CGFloat = 20
    var contentTopPadding: CGFloat = 16
    var contentBottomPadding: CGFloat = 20
    var contentSpacing: CGFloat = 16
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    init(
        title: String? = nil,
        icon: String? = nil,
        subtitle: String? = nil,
        badgeCount: Int? = nil,
        cornerRadius: CGFloat = 24,
        contentHorizontalPadding: CGFloat = 20,
        contentTopPadding: CGFloat = 16,
        contentBottomPadding: CGFloat = 20,
        contentSpacing: CGFloat = 16,
        @ViewBuilder trailing: @escaping () -> Trailing,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.subtitle = subtitle
        self.badgeCount = badgeCount
        self.cornerRadius = cornerRadius
        self.contentHorizontalPadding = contentHorizontalPadding
        self.contentTopPadding = contentTopPadding
        self.contentBottomPadding = contentBottomPadding
        self.contentSpacing = contentSpacing
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header Band ────────────────────────────────
            if let title = title, !title.isEmpty {
                HStack(alignment: .center, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(title)
                            .font(.system(size: 12, weight: .black))
                            .tracking(1.5)
                            .foregroundStyle(Color(hex: "#C1AA78"))
                            .textCase(.uppercase)

                        if let sub = subtitle, !sub.isEmpty {
                            Text(sub)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                    }

                    Spacer(minLength: 0)

                    trailing()
                }
                .padding(.horizontal, headerLeadingPadding)
                .padding(.vertical, 14)

                Divider()
                    .background(Color.white.opacity(0.08))
            }

            // ── Card Inner Content ──────────────────────────
            VStack(spacing: contentSpacing) {
                content()
            }
            .padding(.horizontal, contentHorizontalPadding)
            .padding(.top, (title != nil && !title!.isEmpty) ? contentTopPadding : 20)
            .padding(.bottom, contentBottomPadding)
        }
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(0.70))
        )
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
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
    }
}

// Convenience extension when no trailing view is provided
extension ZifrSheetCard where Trailing == EmptyView {
    init(
        title: String? = nil,
        icon: String? = nil,
        subtitle: String? = nil,
        badgeCount: Int? = nil,
        cornerRadius: CGFloat = 24,
        contentHorizontalPadding: CGFloat = 20,
        contentTopPadding: CGFloat = 16,
        contentBottomPadding: CGFloat = 20,
        contentSpacing: CGFloat = 16,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.subtitle = subtitle
        self.badgeCount = badgeCount
        self.cornerRadius = cornerRadius
        self.contentHorizontalPadding = contentHorizontalPadding
        self.contentTopPadding = contentTopPadding
        self.contentBottomPadding = contentBottomPadding
        self.contentSpacing = contentSpacing
        self.trailing = { EmptyView() }
        self.content = content
    }
}
