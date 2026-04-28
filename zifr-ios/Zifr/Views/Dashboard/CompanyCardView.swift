import SwiftUI

/// The company card displayed on the Dashboard — mirrors CiFr mobile app layout exactly.
struct CompanyCardView: View {
    let company: Company
    let monthlyBurn: Double
    let totalDebt: Double
    let totalCredit: Double
    let onEdit: () -> Void
    let onViewSubscriptions: () -> Void
    let onViewFinancials: () -> Void
    let onViewDocuments: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // ── Top Section ───────────────────────────────────────────────
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
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Financial Data Grid (4 Columns)
            HStack {
                financialColumn(title: "Debt$", value: totalDebt)
                Spacer()
                financialColumn(title: "Credit$", value: totalCredit)
                Spacer()
                financialColumn(title: "recur/mo", value: monthlyBurn)
                Spacer()
                financialColumn(title: "recur/yr", value: monthlyBurn * 12)
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

    private func financialColumn(title: String, value: Double) -> some View {
        VStack(spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.4))
            
            Text(formatCurrency(value))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        if value == 0 {
            return "$0"
        } else if value >= 1000 {
            return "$\(String(format: "%.1fk", value / 1000))"
        } else {
            return "$\(String(format: "%.0f", value))"
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
