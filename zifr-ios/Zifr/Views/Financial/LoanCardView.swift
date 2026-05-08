import SwiftUI
import SwiftData
// MARK: - Loan Card View
struct LoanCardView: View {
    let loan: Loan
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            let amort = loan.amortization
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text((loan.name ?? "").isEmpty ? "Loan" : loan.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text((loan.lender ?? "").isEmpty ? "—" : (loan.lender ?? ""))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        let rateStr = String(format: loan.interestRate.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f%%" : "%.2f%%", loan.interestRate)
                        Text(rateStr)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("rate")
                            .zifrLabel()
                    }
                    .padding(.trailing, 12)
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(amort.totalPrincipal.currencyString)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("principal")
                            .zifrLabel()
                    }
                }

                // Progress Bar
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color(hex: "#545454"))
                                .frame(width: geo.size.width * (amort.principalPct / 100))
                            Rectangle()
                                .fill(Color(hex: "#742C2D"))
                        }
                    }
                    .frame(height: 8)
                    .clipShape(Capsule())
                    .background(Color.white.opacity(0.05))
                }

                HStack {
                    let freqLabel = loan.scheduleFrequency == "Weekly" ? "Wk Pmt" : (loan.scheduleFrequency == "Yearly" ? "Yr Pmt" : "Mo Pmt")
                    statBadge(label: freqLabel, value: amort.monthlyPayment.currencyString)
                    Spacer()
                    statBadge(label: "Interest", value: amort.totalInterest.currencyString)
                    Spacer()
                    statBadge(label: "Total Cost", value: amort.totalCost.currencyString)
                }

                HStack {
                    statBadge(label: "Remaining", value: loan.remainingBalance.currencyString)
                    Spacer()
                    statBadge(label: "Start", value: loan.startDate.numericDisplay)
                    Spacer()
                    if let maturity = loan.maturityDate {
                        statBadge(label: "Maturity", value: maturity.numericDisplay)
                    } else {
                        statBadge(label: "Maturity", value: "—")
                    }
                }
            }
            .padding(16)
            .background(Color(hex: "#2C2C2E")).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func statBadge(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).zifrLabel()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

















