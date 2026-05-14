import SwiftUI

/// The company card displayed on the Dashboard — mirrors CiFr mobile app layout exactly.
struct CompanyCardView: View {
    let company: Company
    let institutionsCount: Int
    let subscriptionsCount: Int
    let docsCount: Int
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // ── Top Row ─────────────────────────────────────────────────
            HStack(alignment: .center, spacing: 0) {
                // Logo
                CompanyAvatar(company: company, size: 48)
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
                
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onEdit()
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 16)

            // ── Status Row ───────────────────────────────────────────────
            HStack {
                statusItem(icon: "square.3.layers.3d", title: "Subscriptions", count: subscriptionsCount, color: Color(hex: "#2070BD"))
                Spacer()
                statusItem(icon: "building.columns", title: "Institutions", count: institutionsCount, color: Color(hex: "#1A7077"))
                Spacer()
                statusItem(icon: "doc.text", title: "Documents", count: docsCount, color: Color(hex: "#918457"))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .background(Color(hex: "#1C1C1E").opacity(0.70))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func statusItem(icon: String, title: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(color)
                
                Text("\(count)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.4))
        }
    }
}
