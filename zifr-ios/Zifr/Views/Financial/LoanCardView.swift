import SwiftUI
import SwiftData

// MARK: - Standalone Loan Group Card
struct StandaloneLoanGroupCard: View {
    let loans: [Loan]
    let isPaidOff: Bool
    @Binding var isExpanded: Bool
    let onEdit: (Loan) -> Void
    let onAddPayment: (Loan) -> Void
    let onTogglePaid: (Loan) -> Void

    private var title: String {
        isPaidOff ? "Paid Off Loans" : "Active Loans"
    }

    private var totalAmount: Double {
        loans.reduce(0) {
            $0 + (isPaidOff ? $1.principalAmount : $1.remainingBalance)
        }
    }

    private var totalLabel: String {
        isPaidOff ? "Paid" : "Remaining"
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: isPaidOff ? "checkmark.circle.fill" : "banknote.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(
                            isPaidOff
                                ? Color(hex: "#C1AA78").opacity(0.75)
                                : Color.zifrGreen
                        )
                        .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)

                        HStack(spacing: 6) {
                            Text("\(loans.count)")
                                .foregroundStyle(.white)
                            Text(loans.count == 1 ? "Loan" : "Loans")
                                .foregroundStyle(Color(hex: "#C1AA78"))

                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 3, height: 3)

                            Text(totalAmount.currencyString)
                                .foregroundStyle(.white)
                                .monospacedDigit()
                            Text(totalLabel)
                                .foregroundStyle(Color(hex: "#C1AA78"))
                        }
                        .font(.system(size: 12, weight: .medium))
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(PremiumButtonStyle())
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 24,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 24
                )
                .fill(Color.black.opacity(0.70))
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 24,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 24
                    )
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            )

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(isExpanded ? "Hide Loans" : "Show Loans")
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(0.2)
                        .foregroundStyle(Color.white.opacity(0.5))
                    Text("(\(loans.count))")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.2))
                    Spacer()
                }
                .padding(.horizontal, 24)
                .frame(height: 47)
                .contentShape(Rectangle())
            }
            .buttonStyle(PremiumButtonStyle())

            if isExpanded {
                VStack(spacing: 12) {
                    if loans.isEmpty {
                        Text(isPaidOff ? "Paid off loans will appear here." : "Active loans will appear here.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(loans) { loan in
                            LoanCardView(
                                loan: loan,
                                onEdit: { onEdit(loan) },
                                onAddPayment: isPaidOff ? nil : { onAddPayment(loan) },
                                onMarkPaid: { onTogglePaid(loan) }
                            )
                            .id(loan.id)
                        }
                    }
                }
                .padding(12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: "#1C1C1E").opacity(0.40))
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title), \(loans.count) \(loans.count == 1 ? "loan" : "loans")")
    }
}

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














