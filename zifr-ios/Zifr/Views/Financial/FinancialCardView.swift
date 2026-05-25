import SwiftUI
import SwiftData
// MARK: - Financial Card View
struct FinancialCardView: View {
    let card: FinancialCard
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(
                            colors: card.cardGradientHex.map { Color(hex: $0) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 44, height: 28)
                    Text(card.network == "Amex" ? "••• \(card.last4 ?? "")" : "•••• \(card.last4 ?? "")")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(card.cardGradientHex.first?.uppercased() == "#FFFFFF" ? .black : .white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(card.name.isEmpty ? "Card" : card.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    HStack(spacing: 6) {
                        Text(card.type)
                            .font(.system(size: 9, weight: .bold))
                            .textCase(.uppercase)
                            .foregroundStyle(Color.white.opacity(0.4))
                        Text("•")
                            .foregroundStyle(Color.white.opacity(0.2))
                        Text(card.network)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.4))
                        Text("•")
                            .foregroundStyle(Color.white.opacity(0.2))
                        Text((card.expiry ?? "").isEmpty ? "—" : (card.expiry ?? ""))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                }
                Spacer()
                Circle()
                    .fill(card.status.statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: card.status.statusColor, radius: 4)
            }
            .padding(14)
            .background(Color(hex: "#1C1C1E"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .proContextMenu(password: card.password, loginId: card.login, last4: card.last4)
    }
}

extension FinancialCard {
    var cardGradientHex: [String] {
        let inst = (institutionName ?? "").lowercased()
        
        // Known Institutions
        if inst.contains("apple") { return ["#FFFFFF", "#F0F0F5"] }
        if inst.contains("chase") { return ["#113b8a", "#0a2354"] }
        if inst.contains("america") || inst.contains("bofa") { return ["#E31837", "#9A0000"] }
        if inst.contains("wells fargo") { return ["#d71e28", "#8a0c13"] }
        if inst.contains("citi") { return ["#003B70", "#002040"] }
        if inst.contains("capital one") { return ["#00284f", "#001224"] }
        if inst.contains("american express") || inst.contains("amex") { return ["#005E9D", "#002D54"] }
        if inst.contains("discover") { return ["#FF6000", "#A84000"] }
        if inst.contains("mercury") { return ["#4A5568", "#1A202C"] }
        if inst.contains("stripe") { return ["#635BFF", "#3E38A3"] }
        if inst.contains("ramp") { return ["#D0F224", "#9DB814"] }
        if inst.contains("sofi") { return ["#23B5E8", "#0087B5"] } // Sky Blue to Deep Cyan

        // Fallback to Network
        switch network {
        case "Visa": return ["#101345", "#060824"]
        case "Mastercard": return ["#5C0000", "#2E0000"]
        case "Amex": return ["#004B7A", "#00233B"]
        case "Discover": return ["#B34700", "#662800"]
        default: return ["#1C1C1E", "#0A0A0C"]
        }
    }
}

