import SwiftUI
import SwiftData

// MARK: - Institution Cards Section
struct InstitutionCardsSection: View {
    @Environment(AppState.self) private var appState
    let cards: [FinancialCard]
    let onAdd: () -> Void
    let onEdit: (FinancialCard) -> Void
    let onDelete: (FinancialCard) -> Void

    var body: some View {
        Section {
            Button { onAdd() } label: {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Add Card")
                    }
                    .font(.system(size: 13, weight: .bold))
                    
                    Text("credit card · debit card")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(MiloomSecondaryButtonStyle())

                ForEach(cards, id: \.id) { card in
                    Button { onEdit(card) } label: {
                        HStack(spacing: 12) {
                            Text("💳").font(.system(size: 18))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(card.name.isEmpty ? "Unnamed Card" : card.name)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                    
                                    HStack(spacing: 4) {
                                        Text(card.type)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.45))
                                        Text("·").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.2))
                                        Text(card.network == "Amex" ? "••• \(card.last4 ?? "")" : "•••• \(card.last4 ?? "")")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Color.white.opacity(0.45))
                                    }
                                }
                                
                                if card.type.lowercased() == "debit" && hasLinkedAccount(for: card) {
                                    HStack(spacing: 4) {
                                        Text("LINKED TO:")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(Color(hex: "#C1AA78"))
                                        Image(systemName: "link")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(Color.zifrGreen)
                                        Text(linkedAccountText(for: card))
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(Color(hex: "#7D7D7D"))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                } else {
                                    Text((card.paidFrom ?? "").isEmpty ? "No payment source" : "Paid from \(paidFromWithInstitution(for: card))")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.2))
                                .padding(.leading, 4)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#2C2C2E"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            withAnimation { onDelete(card) }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.red)
                    }
                }
        } header: { 
            HStack(spacing: 6) {
                Image(systemName: "creditcard")
                    .font(.system(size: 12, weight: .bold))
                Text("CARDS")
                    .font(.system(size: 12, weight: .black))
                    .tracking(1.5)
            }
            .foregroundStyle(Color.white.opacity(0.6))
            .padding(.top, 24)
            .padding(.bottom, 8)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
        .listRowSeparator(.hidden)
    }
    
    private func paidFromWithInstitution(for card: FinancialCard) -> String {
        guard let paidFrom = card.paidFrom, !paidFrom.isEmpty else { return "" }
        let normalizedPaidFrom = paidFrom.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Search in cards
        for c in appState.cards {
            if c.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedPaidFrom {
                let instName = (c.institutionName ?? "").isEmpty ? "" : c.institutionName!
                if !instName.isEmpty {
                    return "\(instName) · \(paidFrom)"
                }
            }
        }
        
        // 2. Search in institutions accounts
        for inst in appState.institutions {
            for acc in inst.accounts {
                let accName = acc.name.isEmpty ? acc.type : acc.name
                if accName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedPaidFrom {
                    let instName = inst.name.isEmpty ? "" : inst.name
                    if !instName.isEmpty {
                        return "\(instName) · \(paidFrom)"
                    }
                }
            }
        }
        return paidFrom
    }
    
    private func hasLinkedAccount(for card: FinancialCard) -> Bool {
        let cardIdString = card.id.uuidString
        return appState.institutions.contains { inst in
            inst.accounts.contains { acc in
                acc.linkedCardId == cardIdString
            }
        }
    }
    
    private func linkedAccountText(for card: FinancialCard) -> String {
        // Reverse lookup: find any account whose linkedCardId matches this card's ID
        let cardIdString = card.id.uuidString
        for inst in appState.institutions {
            for acc in inst.accounts {
                if let linkedId = acc.linkedCardId, linkedId == cardIdString {
                    return acc.name.isEmpty ? acc.type : acc.name
                }
            }
        }
        return ""
    }
}
