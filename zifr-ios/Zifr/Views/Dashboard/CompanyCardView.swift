import SwiftUI

/// The company card displayed on the Dashboard — mirrors CiFr mobile app layout exactly.
struct CompanyCardView: View {
    let company: Company
    let cardsCount: Int
    let institutionsCount: Int
    let loansCount: Int
    let subscriptionsCount: Int
    let docsCount: Int
    let onEdit: () -> Void
    let onViewSubscriptions: () -> Void
    let onViewFinancials: () -> Void
    let onViewDocuments: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // ── Top Section ───────────────────────────────────────────────
            VStack(spacing: 0) {
                // ── Top Row ─────────────────────────────────────────────────
            HStack(alignment: .top, spacing: 0) {
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
                
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Count Data Grid (5 Columns)
            HStack {
                countColumn(title: "Cards", count: cardsCount)
                Spacer()
                countColumn(title: "Inst", count: institutionsCount)
                Spacer()
                countColumn(title: "Loans", count: loansCount)
                Spacer()
                countColumn(title: "Subs", count: subscriptionsCount)
                Spacer()
                countColumn(title: "Docs", count: docsCount)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            }
            .overlay(
                UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 24)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
            .zIndex(1)

            // ── Bottom Section ───────────────────────────────────────────────
            VStack(spacing: 0) {
                // Icon shortcuts (Full Width)
                HStack(spacing: 0) {
                    shortcutBtn(icon: "square.3.layers.3d", label: "Subscriptions", color: Color(hex: "#2070BD"), action: onViewSubscriptions)
                    Divider().background(Color.white.opacity(0.1))
                    shortcutBtn(icon: "dollarsign.bank.building", label: "Institutions", color: Color(hex: "#1A7077"), action: onViewFinancials)
                    Divider().background(Color.white.opacity(0.1))
                    shortcutBtn(icon: "doc.text", label: "Documents", color: Color(hex: "#918457"), action: onViewDocuments)
                }
                .frame(height: 48)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(hex: "#121212"))
        }
        .background(Color(hex: "#0A0A0A"))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func countColumn(title: String, count: Int) -> some View {
        VStack(spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.4))
            
            Text("\(count)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private func shortcutBtn(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            action()
        }) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(color)
                
                Text(label.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }
}
