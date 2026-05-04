import SwiftUI
import SwiftData

// MARK: - Institution Cards Section
struct InstitutionCardsSection: View {
    let cards: [FinancialCard]
    let onAdd: () -> Void
    let onEdit: (FinancialCard) -> Void
    let onDelete: (FinancialCard) -> Void

    var body: some View {
        Section {
            Button { onAdd() } label: {
                VStack(spacing: 3) {
                    Text("ADD CARD")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("credit card · debit card")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .contentShape(RoundedRectangle(cornerRadius: 12))

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
                                
                                Text((card.paidFrom ?? "").isEmpty ? "No payment source" : "Paid from \((card.paidFrom ?? ""))")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.45))
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
        } header: { EmptyView() }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
        .listRowSeparator(.hidden)
    }
}
