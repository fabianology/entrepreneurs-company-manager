import SwiftUI
import SwiftData

struct EntityHomeView: View {
    let company: Company
    let subscriptions: [Subscription]
    let cards: [FinancialCard]
    let institutions: [Institution]
    let loans: [Loan]
    let documents: [CompanyDocument]
    let allCompanies: [Company]
    let allSubscriptions: [Subscription]
    let allCards: [FinancialCard]
    let allLoans: [Loan]
    @Bindable var vm: AppViewModel

    // MARK: – Design Tokens
    private let darkSurface = Color(hex: "#1c1c1e")
    private let dimSurface  = Color(hex: "#141414")
    private let subsColor   = Color(hex: "#2070BD")
    private let finColor    = Color(hex: "#1A7077")
    private let docsColor   = Color(hex: "#918457")
    private let homeColor   = Color.white.opacity(0.85)

    // MARK: – Computed Metrics (Subscriptions)
    private var activeSubscriptions: [Subscription] { subscriptions.filter { $0.status == "Active" } }
    private var monthlyBurn: Double {
        activeSubscriptions.reduce(0.0) { acc, sub in
            let base = sub.billingCycle == "Monthly" ? sub.cost : sub.cost / 12
            let extras = sub.subServices.filter { $0.status != .paused }.reduce(0.0) { $0 + $1.cost }
            return acc + base + extras
        }
    }
    private var yearlyBurn: Double { monthlyBurn * 12 }
    private var freeCount: Int { subscriptions.filter { $0.isFree }.count }
    private var pausedCount: Int { subscriptions.filter { $0.status == "Paused" }.count }
    private var cancelledCount: Int { subscriptions.filter { $0.status == "Cancelled" }.count }
    private var topCostliest: [(String, Double)] {
        activeSubscriptions
            .map { ($0.name, $0.billingCycle == "Monthly" ? $0.cost : $0.cost / 12) }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map { ($0.0, $0.1) }
    }

    // MARK: – Computed Metrics (Financial)
    private var creditCards: [FinancialCard] { cards.filter { $0.type == "Credit" } }
    private var totalDebt: Double {
        loans.filter { $0.role == "Bank Loan" }.reduce(0) { $0 + $1.remainingBalance }
        + creditCards.reduce(0) { $0 + $1.balance }
    }
    private var totalCreditLimit: Double { creditCards.reduce(0) { $0 + $1.limit } }
    private var totalCreditUsed: Double { creditCards.reduce(0) { $0 + $1.balance } }
    private var availableCredit: Double { max(0, totalCreditLimit - totalCreditUsed) }
    private var creditUtilization: Double {
        guard totalCreditLimit > 0 else { return 0 }
        return totalCreditUsed / totalCreditLimit
    }
    private var loanDebt: Double { loans.filter { $0.role == "Bank Loan" }.reduce(0) { $0 + $1.remainingBalance } }
    private var owedToMe: Double { loans.filter { $0.role == "I'm Lending" }.reduce(0) { $0 + $1.remainingBalance } }
    private var activePromos: Int {
        creditCards.filter { $0.promoApr == 0 && $0.promoEnds > Date() }.count
    }
    private var expiringPromos: [(String, Int)] {
        let thirtyDays = Date().addingTimeInterval(30 * 24 * 3600)
        return creditCards
            .filter { $0.promoApr == 0 && $0.promoEnds > Date() && $0.promoEnds <= thirtyDays }
            .map { card in
                let days = Calendar.current.dateComponents([.day], from: Date(), to: card.promoEnds).day ?? 0
                return (card.name, days)
            }
    }

    // MARK: – Computed Metrics (Documents)
    private var docCategories: [String] {
        company.structure == "Personal"
        ? CompanyDocument.personalTypes
        : CompanyDocument.businessTypes
    }
    private var coveredCategories: Set<String> { Set(documents.map(\.type)) }
    private var categoryCoverage: Int { coveredCategories.intersection(docCategories).count }

    // MARK: – Computed Metrics (Portfolio)
    private var portfolioMonthlyBurn: Double {
        allSubscriptions.filter { $0.status == "Active" }.reduce(0.0) { acc, sub in
            let base = sub.billingCycle == "Monthly" ? sub.cost : sub.cost / 12
            let extras = sub.subServices.filter { $0.status != .paused }.reduce(0.0) { $0 + $1.cost }
            return acc + base + extras
        }
    }
    private var portfolioSharePercent: Double {
        guard portfolioMonthlyBurn > 0 else { return 0 }
        return (monthlyBurn / portfolioMonthlyBurn) * 100
    }
    private var burnRank: Int {
        let ranked = allCompanies.sorted { c1, c2 in
            entityBurn(c1) > entityBurn(c2)
        }
        return (ranked.firstIndex(where: { $0.id == company.id }) ?? 0) + 1
    }

    private func entityBurn(_ c: Company) -> Double {
        allSubscriptions.filter { $0.companyId == c.id && $0.status == "Active" }.reduce(0.0) { acc, sub in
            let base = sub.billingCycle == "Monthly" ? sub.cost : sub.cost / 12
            let extras = sub.subServices.filter { $0.status != .paused }.reduce(0.0) { $0 + $1.cost }
            return acc + base + extras
        }
    }

    // MARK: – Alerts
    private var isZeroState: Bool {
        subscriptions.isEmpty && cards.isEmpty && institutions.isEmpty && loans.isEmpty && documents.isEmpty
    }

    private var alerts: [HomeAlert] {
        var result: [HomeAlert] = []

        // Promo APR expiring
        for (name, days) in expiringPromos {
            result.append(HomeAlert(
                icon: "exclamationmark.triangle.fill",
                color: .orange,
                text: "Promo APR on \(name) expires in \(days) days"
            ))
        }

        // High credit utilization
        if creditUtilization > 0.7 && totalCreditLimit > 0 {
            result.append(HomeAlert(
                icon: "creditcard.trianglebadge.exclamationmark.fill",
                color: .orange,
                text: "Credit utilization at \(Int(creditUtilization * 100))%"
            ))
        }

        // Missing critical documents
        let criticalMissing = docCategories.filter { !coveredCategories.contains($0) && $0 != "Other" }
        if !criticalMissing.isEmpty {
            result.append(HomeAlert(
                icon: "doc.badge.clock.fill",
                color: Color.white.opacity(0.5),
                text: "\(criticalMissing.count) document \(criticalMissing.count == 1 ? "category" : "categories") missing"
            ))
        }

        // Stale entity
        let daysSinceModified = Calendar.current.dateComponents([.day], from: company.lastModified, to: Date()).day ?? 0
        if daysSinceModified > 90 {
            result.append(HomeAlert(
                icon: "clock.arrow.circlepath",
                color: Color.white.opacity(0.4),
                text: "Not updated in \(daysSinceModified) days"
            ))
        }

        return result
    }

    // MARK: – Body
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {

                // ── ZONE 1: Vital Signs ──────────────────────────────
                vitalSignsSection

                // ── ZERO STATE BANNER ────────────────────────────────
                if isZeroState {
                    zeroStateBanner
                }

                // ── ZONE 2: Alerts ───────────────────────────────────
                if !alerts.isEmpty {
                    alertsSection
                }

                // ── ZONE 3: Cash Flow ────────────────────────────────
                cashFlowCard

                // ── ZONE 4: Financial Health ─────────────────────────
                financialHealthCard

                // ── ZONE 5: Document Vault ───────────────────────────
                documentVaultCard

                // ── ZONE 6: Portfolio Context ────────────────────────
                if allCompanies.count > 1 {
                    portfolioContextCard
                }

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.black)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: – Zone 1: Vital Signs
    // ══════════════════════════════════════════════════════════════════

    private var vitalSignsSection: some View {
        HStack(spacing: 8) {
            vitalCube(top: formatCurrency(monthlyBurn), bottom: "BURN/MO")
            vitalCube(top: formatCurrency(totalDebt), bottom: "TOTAL DEBT")
            vitalCube(top: formatCurrency(availableCredit), bottom: "AVAIL CREDIT")
            vitalCube(top: "\(documents.count)", bottom: "DOCUMENTS")
        }
    }

    private func vitalCube(top: String, bottom: String, highlight: Color? = nil) -> some View {
        VStack(spacing: 4) {
            Text(top)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(highlight ?? .white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(bottom)
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(Color.white.opacity(0.35))
                .tracking(0.5)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 68)
        .background(darkSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: – Zero State Banner
    // ══════════════════════════════════════════════════════════════════

    private var zeroStateBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.zifrGold)
                Text("Command Center Active")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
            }
            Text("Begin adding your entity's services, banks, cards, or documents using the tabs below to populate your dashboards.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.6))
                .lineSpacing(4)
        }
        .padding(16)
        .background(dimSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.zifrGold.opacity(0.2), lineWidth: 1))
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: – Zone 2: Alerts
    // ══════════════════════════════════════════════════════════════════

    private var alertsSection: some View {
        VStack(spacing: 6) {
            ForEach(alerts) { alert in
                HStack(spacing: 10) {
                    Image(systemName: alert.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(alert.color)
                    Text(alert.text)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.75))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(alert.color.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(alert.color.opacity(0.15), lineWidth: 1)
                )
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: – Zone 3: Cash Flow
    // ══════════════════════════════════════════════════════════════════

    private var cashFlowCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            cardHeader(title: "CASH FLOW", icon: "square.3.layers.3d", color: subsColor) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                vm.activeTab = .subscriptions
            }

            // Monthly / Yearly
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("RECURRING/MO")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .tracking(0.5)
                    HStack(spacing: 6) {
                        Text(formatCurrency(monthlyBurn))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                        Text("(\(activeSubscriptions.filter { $0.billingCycle == "Monthly" }.count))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                }
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1, height: 36)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("RECURRING/YR")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .tracking(0.5)
                    HStack(spacing: 6) {
                        Text(formatCurrency(yearlyBurn))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                        Text("(\(activeSubscriptions.filter { $0.billingCycle == "Yearly" }.count))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                }
            }

            // Counts row
            HStack(spacing: 8) {
                countPill(label: "ACTIVE", count: activeSubscriptions.count, color: .zifrGreen)
                countPill(label: "FREE", count: freeCount, color: .white)
                countPill(label: "PAUSED", count: pausedCount, color: .orange)
                countPill(label: "CANCELLED", count: cancelledCount, color: .red)
            }

            // Top 3 costliest
            if !topCostliest.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TOP SPEND")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .tracking(0.5)
                    ForEach(Array(topCostliest.enumerated()), id: \.offset) { idx, item in
                        HStack(spacing: 8) {
                            Text("\(idx + 1)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(subsColor.opacity(0.6))
                                .frame(width: 16)
                            Text(item.0)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Spacer()
                            Text("$\(String(format: "%.0f", item.1))/mo")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(darkSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: – Zone 4: Financial Health
    // ══════════════════════════════════════════════════════════════════

    private var financialHealthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            cardHeader(title: "FINANCIAL HEALTH", icon: "dollarsign.bank.building", color: finColor) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                vm.activeTab = .financial
            }

            // Entity counts
            HStack(spacing: 8) {
                countCube(emoji: "🏦", count: institutions.count, label: "BANKS")
                countCube(emoji: "💳", count: cards.count, label: "CARDS")
                countCube(emoji: "📑", count: loans.count, label: "LOANS")
            }

            // Debt vs Owed
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LOAN DEBT")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .tracking(0.5)
                    Text(formatCurrency(loanDebt))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1, height: 32)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("OWED TO ME")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .tracking(0.5)
                    Text(owedToMe > 0 ? formatCurrency(owedToMe) : "—")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(owedToMe > 0 ? .zifrGreen : Color.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 4)

            // Credit utilization bar
            if totalCreditLimit > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("CREDIT UTILIZATION")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.35))
                            .tracking(0.5)
                        Spacer()
                        Text("\(Int(creditUtilization * 100))%")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(utilizationColor)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(utilizationColor)
                                .frame(width: geo.size.width * min(1, creditUtilization), height: 8)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text(formatCurrency(totalCreditUsed) + " used")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.4))
                        Spacer()
                        Text(formatCurrency(availableCredit) + " available")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                }

                // Active promos
                if activePromos > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(finColor)
                        Text("\(activePromos) active 0% promo\(activePromos == 1 ? "" : "s")")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.6))
                        Spacer()
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(16)
        .background(darkSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }

    private var utilizationColor: Color {
        if creditUtilization > 0.7 { return .orange }
        if creditUtilization > 0.5 { return Color(hex: "#EBC351") }
        return .zifrGreen
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: – Zone 5: Document Vault
    // ══════════════════════════════════════════════════════════════════

    private var documentVaultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            cardHeader(title: "DOCUMENT VAULT", icon: "doc.text", color: docsColor) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                vm.activeTab = .documents
            }

            // File count
            HStack(spacing: 8) {
                Text("\(documents.count)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Text("FILES")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .tracking(0.5)
                Spacer()
                Text("\(categoryCoverage)/\(docCategories.filter { $0 != "Other" }.count) categories")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.4))
            }

            // Category grid
            let filteredCategories = docCategories.filter { $0 != "Other" }
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(filteredCategories, id: \.self) { category in
                    HStack(spacing: 6) {
                        Image(systemName: coveredCategories.contains(category) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(coveredCategories.contains(category) ? docsColor : Color.white.opacity(0.15))
                        Text(shortCategoryName(category))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(coveredCategories.contains(category) ? Color.white.opacity(0.7) : Color.white.opacity(0.25))
                            .lineLimit(1)
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .background(darkSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: – Zone 6: Portfolio Context
    // ══════════════════════════════════════════════════════════════════

    private var portfolioContextCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(homeColor)
                Text("PORTFOLIO")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .tracking(1.5)
                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("RANK BY SPEND")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .tracking(0.5)
                    Text("#\(burnRank) of \(allCompanies.count)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1, height: 32)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("PORTFOLIO SHARE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .tracking(0.5)
                    Text("\(Int(portfolioSharePercent))%")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            // Portfolio total
            HStack(spacing: 4) {
                Text("Total portfolio burn:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
                Text(formatCurrency(portfolioMonthlyBurn) + "/mo")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.6))
                Text("across \(allCompanies.count) entities")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
        }
        .padding(16)
        .background(dimSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: – Shared Components
    // ══════════════════════════════════════════════════════════════════

    private func cardHeader(title: String, icon: String, color: Color, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .tracking(1.5)
                Spacer()
                Text("VIEW")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(color.opacity(0.6))
                    .tracking(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(color.opacity(0.4))
            }
        }
        .buttonStyle(.plain)
    }

    private func countPill(label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(count > 0 ? color : Color.white.opacity(0.2))
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.3))
                .tracking(0.3)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func countCube(emoji: String, count: Int, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(emoji)
                    .font(.system(size: 15))
                Text("\(count)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(label)
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(Color.white.opacity(0.35))
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(dimSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: – Helpers

    private func formatCurrency(_ value: Double) -> String {
        if value == 0 { return "$0" }
        if value >= 1000 { return "$\(String(format: "%.1fk", value / 1000))" }
        return "$\(String(format: "%.0f", value))"
    }

    private func shortCategoryName(_ name: String) -> String {
        // Shorten long compound names for the grid
        name.replacingOccurrences(of: " & ", with: " & ")
            .components(separatedBy: " & ")
            .first ?? name
    }
}

// MARK: – Alert Model
struct HomeAlert: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let text: String
}
