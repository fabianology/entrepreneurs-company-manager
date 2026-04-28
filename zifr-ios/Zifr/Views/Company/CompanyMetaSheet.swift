import SwiftUI
import SwiftData

struct CompanyMetaSheet: View {
    let company: Company
    let subscriptions: [Subscription]
    let institutions: [Institution]
    let cards: [FinancialCard]
    let loans: [Loan]
    let documents: [CompanyDocument]
    @Environment(\.dismiss) private var dismiss

    private let darkSurface = Color(hex: "#0d0d0d")
    private let dimSurface  = Color(hex: "#141414")
    private let subsColor   = Color(hex: "#2070BD")
    private let finColor    = Color(hex: "#1A7077")
    private let docsColor   = Color(hex: "#918457")

    // MARK: – Computed stats
    private var subEmails: Int    { Set(subscriptions.map(\.loginId).filter { !$0.isEmpty }).count }
    private var bankEmails: Int   { Set(institutions.map(\.email).filter { !$0.isEmpty }).count }
    private var supplementals: Int { subscriptions.reduce(0) { $0 + $1.subServices.count } }
    private var cardsInUse: Int   { Set(subscriptions.map(\.paymentMethod).filter { !$0.isEmpty }).count }
    private var banksLinked: Int  { Set(cards.map(\.paidFrom).filter { !$0.isEmpty }).count }
    private var creditCards: Int  { cards.filter { $0.type == "Credit" }.count }
    private var activePromos: Int { cards.filter { $0.type == "Credit" && $0.promoApr == 0 && $0.promoEnds > Date() }.count }
    private var activeLoans: Int  { loans.count }
    private var bankDebt: Double  { loans.filter { $0.role == "Bank Loan" }.reduce(0) { $0 + $1.remainingBalance } }
    private var owedToMe: Double  { loans.filter { $0.role == "I'm Lending" }.reduce(0) { $0 + $1.remainingBalance } }
    private var monthlyRecur: Double {
        subscriptions.reduce(0) { acc, sub in
            let base = sub.billingCycle == "Monthly" ? sub.cost : sub.cost / 12
            return acc + base
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {

                // ── Header ────────────────────────────────────────────────
                headerBanner

                // ── SUBSCRIPTIONS ─────────────────────────────────────────
                sectionLabel("SUBSCRIPTIONS", icon: "square.3.layers.3d", color: subsColor)

                // Row 1: 3-up cubes
                HStack(spacing: 8) {
                    cube(top: "\(subscriptions.count)", bottom: "TOTAL")
                    cube(top: "\(supplementals)", bottom: "ADD-ONS")
                    cube(top: "\(subEmails)", bottom: "LOGINS")
                }

                // Row 2: wide finance bar
                wideBar(left: "RECUR/MO", leftVal: formatCurrency(monthlyRecur),
                        right: "RECUR/YR", rightVal: formatCurrency(monthlyRecur * 12))

                // ── INSTITUTIONS ──────────────────────────────────────────
                sectionLabel("INSTITUTIONS", icon: "dollarsign.bank.building", color: finColor)

                HStack(spacing: 8) {
                    cube(top: "\(institutions.count)", bottom: "BANKS")
                    cube(top: "\(bankEmails)", bottom: "EMAILS")
                    cube(top: "\(banksLinked)", bottom: "LINKED")
                }

                HStack(spacing: 8) {
                    cube(top: "\(creditCards)", bottom: "CREDIT CARDS")
                    cube(top: "\(activePromos > 0 ? "\(activePromos)" : "—")", bottom: "0% PROMOS", highlight: activePromos > 0 ? finColor : nil)
                    cube(top: "\(cardsInUse)", bottom: "IN USE")
                }

                HStack(spacing: 8) {
                    cube(top: "\(activeLoans)", bottom: "LOANS")
                    wideRect(top: "LOAN DEBT", val: formatCurrency(bankDebt))
                }

                wideBar(left: "LOAN DEBT", leftVal: formatCurrency(bankDebt),
                        right: "OWED TO ME", rightVal: owedToMe > 0 ? formatCurrency(owedToMe) : "—")

                // ── DOCUMENTS ─────────────────────────────────────────────
                sectionLabel("DOCUMENTS", icon: "doc.text", color: docsColor)

                cube(top: "\(documents.count)", bottom: "FILES")
            }
            .padding(12)
        }
        .background(Color.clear)
    }

    // MARK: – Header

    private var headerBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("META VIEW")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                    .tracking(1)
            }
            Spacer()
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(i == 2 ? 0.5 : i == 1 ? 0.25 : 0.1))
                        .frame(width: i == 2 ? 18 : 8, height: 8)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(darkSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: – Section Label

    private func sectionLabel(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.4))
                .tracking(1.5)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    // MARK: – Cube (square data block)

    private func cube(top: String, bottom: String, highlight: Color? = nil) -> some View {
        VStack(spacing: 4) {
            Text(top)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(highlight ?? .white)
            Text(bottom)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.35))
                .tracking(0.5)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .background(darkSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: – Wide Rect (rectangle that fills remaining space)

    private func wideRect(top: String, val: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(top)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.35))
                .tracking(0.5)
            Text(val)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 72)
        .padding(.horizontal, 14)
        .background(darkSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: – Wide Bar (full-width 2-column rectangle)

    private func wideBar(left: String, leftVal: String, right: String, rightVal: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(left)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .tracking(0.5)
                Text(leftVal)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            Spacer()
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 1, height: 32)
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(right)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .tracking(0.5)
                Text(rightVal)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(dimSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: – Helpers

    private func formatCurrency(_ value: Double) -> String {
        if value == 0 { return "$0" }
        if value >= 1000 { return "$\(String(format: "%.1fk", value / 1000))" }
        return "$\(String(format: "%.0f", value))"
    }
}
