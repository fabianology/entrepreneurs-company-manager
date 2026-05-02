import SwiftUI
import SwiftData

struct LoanPaymentsLedgerView: View {
    @Binding var loan: Loan
    @Binding var editingPaymentId: String?
    @Binding var paymentDraft: LoanPayment
    @Binding var showPaymentHUD: Bool

    var body: some View {
        let isPaymentsEmpty = (loan.payments ?? []).isEmpty
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("PAYMENT LEDGER")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .tracking(1)
            }
            
            VStack(spacing: 0) {
                ledgerHeaderRow
                ledgerListItems
            }
            .padding(.top, isPaymentsEmpty ? 0 : 4)
            .background(Color(hex: "#1A1A1A"))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
        }
    }

    private var ledgerHeaderRow: some View {
        HStack(spacing: 4) {
            Text("#").frame(width: 16, alignment: .leading)
            Text("DATE").frame(maxWidth: .infinity, alignment: .leading)
            Text("AMOUNT").frame(width: 80, alignment: .trailing)
        }
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(Color.white.opacity(0.4))
        .textCase(.uppercase)
        .tracking(1)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text((payment.source ?? "").isEmpty ? "None" : (payment.source ?? ""))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle((payment.source ?? "").isEmpty ? Color.white.opacity(0.4) : .white)
                .frame(maxWidth: .infinity, alignment: .leading)
                
            Text(cumulativeTotal.currencyString)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(Color.zifrGold)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .modifier(ZifrSwipeActionsModifier(
            onEdit: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                editingPaymentId = payment.id.uuidString
                paymentDraft = LoanPayment(id: payment.id, userId: loan.userId, loanId: loan.id, date: payment.date, amount: payment.amount, source: payment.source)
                showPaymentHUD = true
            },
            onDelete: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation {
                    if let pId = payment.id as UUID? {
                        loan.payments?.removeAll(where: { $0.id == pId })
                    }
                }
            }
        ))
    }
}
