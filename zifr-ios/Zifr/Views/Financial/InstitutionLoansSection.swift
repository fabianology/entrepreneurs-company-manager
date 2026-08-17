import SwiftUI
import SwiftData

// MARK: - Institution Loans Section
struct InstitutionLoansSection: View {
    let loans: [Loan]
    let onAdd: () -> Void
    let onEdit: (Loan) -> Void
    let onDelete: (Loan) -> Void

    var body: some View {
        ZifrSheetCard(
            title: "LOANS",
            icon: "doc.text",
            subtitle: "lending out · bank loan · custom loan",
            badgeCount: loans.count
        ) {
            if !loans.isEmpty {
                VStack(spacing: 8) {
                    ForEach(loans, id: \.id) { loan in
                        Button { 
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onEdit(loan) 
                        } label: {
                            HStack(spacing: 12) {
                                Text("💸").font(.system(size: 18))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text((loan.name ?? "").isEmpty ? "Unnamed Loan" : loan.name)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white)
                                        Text("|")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.2))
                                        let rateStr = String(format: loan.interestRate.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f", loan.interestRate)
                                        Text("\(rateStr)% APR")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.45))
                                    }
                                    let dateRange = loan.maturityDate != nil ? "\(loan.startDate.numericDisplay) → \(loan.maturityDate!.numericDisplay)" : "\(loan.startDate.numericDisplay)"
                                    Text(dateRange)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                }
                                Spacer()
                                Text(loan.principalAmount.currencyString)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.6))
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.2))
                                    .padding(.leading, 4)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#2C2C2E"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        }
                        .buttonStyle(PremiumButtonStyle())
                        .contextMenu {
                            Button(role: .destructive) {
                                withAnimation { onDelete(loan) }
                            } label: {
                                Label("Delete Loan", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Button { 
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onAdd() 
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add Loan")
                }
                .font(.system(size: 13, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(MiloomSecondaryButtonStyle())
        }
    }
}
