import SwiftUI

/// The company card displayed on the Dashboard — mirrors CiFr mobile app layout exactly.
struct CompanyCardView: View {
    let company: Company
    let monthlyBurn: Double
    let onEdit: () -> Void
    let onViewSubscriptions: () -> Void
    let onViewFinancials: () -> Void
    let onViewDocuments: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // ── Top Row ─────────────────────────────────────────────────
            HStack(alignment: .center, spacing: 0) {
                // Logo
                CompanyAvatar(company: company, size: 56)
                    .padding(.trailing, 14)

                // Name + Structure
                VStack(alignment: .leading, spacing: 2) {
                    Text(company.name.isEmpty ? "New Entity" : company.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(company.structure)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Monthly burn (only shown when > 0)
                if monthlyBurn > 0 {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(monthlyBurn >= 1000
                             ? "$\(String(format: "%.1f", monthlyBurn / 1000))k"
                             : "$\(String(format: "%.0f", monthlyBurn))")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                        Text("mo. burn")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 18)

            // ── Bottom Row ───────────────────────────────────────────────
            HStack(alignment: .center) {

                // Time metadata (left)
                VStack(alignment: .leading, spacing: 5) {
                    metaRow(icon: "clock", label: "Modified:", value: company.lastModified.timeAgoDisplay())
                    metaRow(icon: "eye", label: "Viewed:", value: company.lastViewed.timeAgoDisplay())
                }

                Spacer()

                // Icon shortcuts (right) — exact CiFr: blue/green/amber
                HStack(spacing: 0) {
                    shortcutBtn(icon: "square.3.layers.3d", color: Color(hex: "#60A5FA"), action: onViewSubscriptions)
                    shortcutBtn(icon: "creditcard", color: Color(hex: "#22c55e"), action: onViewFinancials)
                    shortcutBtn(icon: "doc.text", color: Color(hex: "#FBBF24"), action: onViewDocuments)
                }
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 1))
                .padding(.trailing, -8)
                .padding(.bottom, -8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 1)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: "#1C1C1E"))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func metaRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.4))
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.4))
            + Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.8))
        }
    }

    private func shortcutBtn(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
        }
    }
}
