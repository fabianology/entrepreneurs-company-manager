import SwiftUI
import SwiftData

struct LoanPaymentsLedgerView: View {
    @Binding var loan: Loan
    @Binding var editingPaymentId: String?
    @Binding var paymentDraft: LoanPayment
    @Binding var showPaymentHUD: Bool

    var body: some View {
        ZifrSheetCard(
            title: "PAYMENT LEDGER",
            icon: "list.bullet.rectangle",
            subtitle: "recorded payments · running balance",
            badgeCount: (loan.payments ?? []).count
        ) {
            VStack(spacing: 0) {
                ledgerHeaderRow
                ledgerListItems
            }
            .background(Color(hex: "#1A1A1A"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                editingPaymentId = nil
                paymentDraft = LoanPayment(id: UUID(), userId: loan.userId, loanId: loan.id, date: Date(), amount: 0, source: "")
                showPaymentHUD = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add Payment")
                }
                .font(.system(size: 13, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(MiloomSecondaryButtonStyle())
        }
    }

    private var ledgerHeaderRow: some View {
        HStack(spacing: 4) {
            Text("#").frame(width: 16, alignment: .leading)
            Text("DATE").frame(maxWidth: .infinity, alignment: .leading)
            Text("AMOUNT").frame(width: 70, alignment: .leading)
            Text("SOURCE").frame(maxWidth: .infinity, alignment: .leading)
            Text("TOTAL").frame(width: 70, alignment: .trailing)
        }
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(Color.white.opacity(0.4))
        .textCase(.uppercase)
        .tracking(1)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(hex: "#1C1C1E"))
    }

    @ViewBuilder
    private var ledgerListItems: some View {
        if (loan.payments ?? []).isEmpty {
            Text("No payments recorded yet.")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.4))
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
        } else {
            let sortedPayments = (loan.payments ?? []).sorted { $0.date < $1.date }
            ForEach(Array(sortedPayments.enumerated()), id: \.element.id) { index, payment in
                paymentRow(index: index + 1, payment: payment, cumulativeTotal: calculateCumulativeTotal(for: index, in: sortedPayments))
                
                if payment.id != sortedPayments.last?.id {
                    Divider().background(Color.white.opacity(0.05))
                }
            }
        }
    }

    private func calculateCumulativeTotal(for index: Int, in payments: [LoanPayment]) -> Double {
        let prefix = payments.prefix(index + 1)
        return prefix.reduce(0.0) { $0 + $1.amount }
    }
    
    private func paymentRow(index: Int, payment: LoanPayment, cumulativeTotal: Double) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            editingPaymentId = payment.id.uuidString
            paymentDraft = LoanPayment(id: payment.id, userId: loan.userId, loanId: loan.id, date: payment.date, amount: payment.amount, source: payment.source)
            showPaymentHUD = true
        } label: {
            HStack(spacing: 4) {
                Text("\(index)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .frame(width: 16, alignment: .leading)
                
                Text(payment.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(payment.amount.currencyString)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 70, alignment: .leading)
                
                Text((payment.source ?? "").isEmpty ? "None" : (payment.source ?? ""))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle((payment.source ?? "").isEmpty ? Color.white.opacity(0.4) : .white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                Text(cumulativeTotal.currencyString)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(hex: "#C1AA78"))
                    .frame(width: 70, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color(hex: "#2C2C2E").opacity(0.4))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation {
                    if let pId = payment.id as UUID? {
                        loan.payments?.removeAll(where: { $0.id == pId })
                        loan.recalculateBalance()
                    }
                }
            } label: {
                Label("Delete Payment", systemImage: "trash")
            }
        }
    }
}
