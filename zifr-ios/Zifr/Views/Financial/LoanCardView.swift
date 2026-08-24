import SwiftUI
import SwiftData
// MARK: - Loan Card View
struct LoanCardView: View {
    let loan: Loan
    let onEdit: () -> Void
    var onAddPayment: (() -> Void)? = nil
    var onMarkPaid: (() -> Void)? = nil

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onEdit()
        }) {
            let amort = loan.amortization
            VStack(alignment: .leading, spacing: 12) {
                // ── HEADER: Hero Identity & Key Balance ───────────────
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Loan Name
                        Text((loan.name ?? "").isEmpty ? "Loan" : loan.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        // Counterparty (Borrower)
                        let borrowerName = (loan.borrower ?? "").isEmpty ? (loan.lender ?? "") : (loan.borrower ?? "")
                        let counterparty = borrowerName.isEmpty ? "—" : borrowerName
                        HStack(spacing: 4) {
                            Text("BORROWER")
                                .zifrLabel()
                                .foregroundStyle(Color(hex: "#C1AA78"))
                            
                            Text(counterparty)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.75))
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer(minLength: 12)
                    
                    // Right: Prominent Balance Display with LOAN AMOUNT & numerical value
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(loan.remainingBalance.currencyString)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(hex: "#C1AA78"))
                            .monospacedDigit()
                        
                        HStack(spacing: 4) {
                            Text("LOAN AMOUNT")
                                .zifrLabel()
                            Text(amort.totalPrincipal.currencyString)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.75))
                        }
                    }
                }

                // ── PROGRESS TELEMETRY: Status Bar & Payoff % ──────────
                VStack(spacing: 6) {
                    // Payoff Track: App Background Green (#166A4E) & Luminous Solid Gold (#C1AA78)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Track (App background green #166A4E)
                            Capsule()
                                .fill(Color(hex: "#166A4E"))
                            
                            // Fill (Solid Gold)
                            Capsule()
                                .fill(Color(hex: "#C1AA78"))
                                .frame(width: max(0, min(geo.size.width, geo.size.width * loan.progressPercent)))
                        }
                    }
                    .frame(height: 7)

                    // Micro-Telemetry Labels
                    HStack {
                        Spacer()
                        let pctText = String(format: "%.0f%% PAID OFF", loan.progressPercent * 100)
                        Text(pctText)
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(1)
                            .foregroundStyle(Color(hex: "#C1AA78"))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.zifrTabBarFill.opacity(0.70))
            )
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "#918457"),
                                Color(hex: "#918457").opacity(0.3)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(PremiumButtonStyle())
        .contextMenu {
            if let onAddPayment = onAddPayment {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onAddPayment()
                } label: {
                    Label("Add Payment", systemImage: "plus.circle")
                }
            }
            
            if let onMarkPaid = onMarkPaid {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onMarkPaid()
                } label: {
                    Label(loan.status == "Paid Off" ? "Mark as Active" : "Mark as Paid", systemImage: loan.status == "Paid Off" ? "arrow.counterclockwise" : "checkmark.circle.fill")
                }
            }
        }
    }
}

















