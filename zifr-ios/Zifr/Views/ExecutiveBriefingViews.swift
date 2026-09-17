import SwiftUI

struct OwnerHealthBriefingDashboard: View {
    @Environment(AppState.self) private var appState
    @Bindable var vm: AppViewModel
    @State private var selectedScope: OwnerBriefingScope = .personal
    @State private var financialMonth: CashFlowMonth = .current
    @State private var activeHUD: BriefingReceiptHUD?
    @State private var showingReminders = false
    @State private var selectedRecurringReview: RecurringSuggestionReview?
    @State private var queuedRecurringReview: RecurringSuggestionReview?
    @State private var ignoredDataIssueIDs = OwnerHealthDataIssueStore.load()
    @State private var pendingNavigation: (() -> Void)?
    var onOpenResource: (PortfolioObligation) -> Void
    var onOpenHealthResource: (ResourceKind, UUID) -> Void
    var onExploreConnections: () -> Void

    private var visibleScopes: [OwnerBriefingScope] {
        let available = ExecutiveBriefingLayout.visibleScopes(companies: appState.companies)
        return [.personal, .business].filter(available.contains)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let snapshot = ExecutiveBriefingSnapshot(
                appState: appState,
                scope: selectedScope,
                now: context.date
            )
            let health = OwnerHealthEngine.snapshot(
                appState: appState,
                scope: selectedScope,
                now: context.date,
                ignoredDataIssueIDs: ignoredDataIssueIDs
            )
            let notices = ExecutiveUrgentNotice.cardNotices(
                in: appState,
                scope: selectedScope,
                now: context.date
            )

            ExecutiveBriefingReceipt(
                snapshot: snapshot,
                health: health,
                notices: notices,
                selectedScope: $selectedScope,
                financialMonth: $financialMonth,
                visibleScopes: visibleScopes,
                now: context.date,
                onShowTransactions: { activeHUD = .transactions },
                onShowCategories: { activeHUD = .categories },
                onShowAccounts: { activeHUD = .accounts },
                onShowReview: { activeHUD = .review },
                onShowReminders: { showingReminders = true },
                onExploreConnections: onExploreConnections,
                onOpenResource: onOpenHealthResource,
                onOpenUrgent: openUrgent
            )
        }
        .onAppear { keepScopeAvailable() }
        .onChange(of: appState.companies) { _, _ in keepScopeAvailable() }
        .sheet(item: $activeHUD, onDismiss: finishHUD) { hud in
            let snapshot = ExecutiveBriefingSnapshot(appState: appState, scope: selectedScope, now: Date())
            let health = OwnerHealthEngine.snapshot(
                appState: appState,
                scope: selectedScope,
                ignoredDataIssueIDs: ignoredDataIssueIDs
            )
            switch hud {
            case .transactions:
                BriefingTransactionsReceipt(
                    snapshot: snapshot,
                    month: financialMonth,
                    now: Date()
                )
            case .categories:
                BriefingSpendingCategoriesReceipt(
                    summaries: ExecutiveBriefingSnapshot.financials(
                        records: snapshot.records,
                        now: Date(),
                        month: financialMonth
                    ),
                    month: financialMonth
                )
            case .accounts:
                BriefingAccountsReceipt(snapshot: snapshot) { kind, id in
                    pendingNavigation = { onOpenHealthResource(kind, id) }
                    activeHUD = nil
                }
            case .review:
                BriefingReviewReceipt(
                    health: health,
                    onOpen: { issue in
                        pendingNavigation = { onOpenHealthResource(issue.resourceType, issue.resourceID) }
                        activeHUD = nil
                    },
                    onIgnore: { issue in
                        ignoredDataIssueIDs.insert(issue.id)
                        OwnerHealthDataIssueStore.save(ignoredDataIssueIDs)
                    },
                    onReviewRecurring: { suggestions in
                        queuedRecurringReview = RecurringSuggestionReview(suggestions: suggestions)
                        activeHUD = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showingReminders, onDismiss: finishPendingNavigation) {
            OwnerBriefingView(scope: selectedScope) { obligation in
                pendingNavigation = { onOpenResource(obligation) }
                showingReminders = false
            }
        }
        .sheet(item: $selectedRecurringReview) { review in
            DetectedSubscriptionsSheet(
                detected: review.suggestions,
                cardId: nil,
                cardName: "\(selectedScope.rawValue.lowercased()) accounts",
                companyId: nil,
                vm: vm,
                onDismissAll: { selectedRecurringReview = nil }
            )
            .environment(appState)
        }
    }

    private func keepScopeAvailable() {
        if !visibleScopes.contains(selectedScope) {
            selectedScope = visibleScopes.first ?? .personal
        }
    }

    private func finishHUD() {
        if let review = queuedRecurringReview {
            queuedRecurringReview = nil
            selectedRecurringReview = review
            return
        }
        finishPendingNavigation()
    }

    private func finishPendingNavigation() {
        let action = pendingNavigation
        pendingNavigation = nil
        action?()
    }

    private func openUrgent(_ notice: ExecutiveUrgentNotice) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if let obligation = notice.obligation { onOpenResource(obligation) }
        else { onOpenHealthResource(notice.sourceType, notice.sourceID) }
    }
}

private enum BriefingReceiptHUD: String, Identifiable {
    case transactions
    case categories
    case accounts
    case review

    var id: String { rawValue }
}

enum BriefingReceiptTheme {
    static let paper = Color.white
    static let ink = Color(hex: "#1A1A1A")
    static let fadedInk = Color(hex: "#1A1A1A").opacity(0.64)
    static let gold = Color(hex: "#918457")
}

private struct ExecutiveBriefingReceipt: View {
    let snapshot: ExecutiveBriefingSnapshot
    let health: OwnerHealthSnapshot
    let notices: [ExecutiveUrgentNotice]
    @Binding var selectedScope: OwnerBriefingScope
    @Binding var financialMonth: CashFlowMonth
    let visibleScopes: [OwnerBriefingScope]
    let now: Date
    let onShowTransactions: () -> Void
    let onShowCategories: () -> Void
    let onShowAccounts: () -> Void
    let onShowReview: () -> Void
    let onShowReminders: () -> Void
    let onExploreConnections: () -> Void
    let onOpenResource: (ResourceKind, UUID) -> Void
    let onOpenUrgent: (ExecutiveUrgentNotice) -> Void
    @State private var billsExpanded = false
    @State private var subscriptionsExpanded = false

    private var financials: [ExecutiveCurrencySummary] {
        ExecutiveBriefingSnapshot.financials(records: snapshot.records, now: now, month: financialMonth)
    }

    private var transactionCount: Int {
        financials.reduce(0) { $0 + $1.insight.records.count }
    }

    private var accountCount: Int {
        snapshot.institutions.reduce(0) { $0 + $1.accounts.count } + snapshot.cards.count + snapshot.loans.count
    }

    private var reviewCount: Int {
        health.categories.reduce(0) { $0 + $1.dataIssues.count + $1.recurringSuggestions.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            receiptHeader
            dashedDivider
            selectors
            Text(snapshot.coverage)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(BriefingReceiptTheme.fadedInk)
                .fixedSize(horizontal: false, vertical: true)

            receiptSection(title: "FINANCIAL", icon: "chart.bar.xaxis", highlighted: true) {
                financialContent
            }
            receiptSection(title: "SERVICES", icon: "square.stack.3d.up", highlighted: true) {
                servicesContent
            }
            receiptSection(title: "VAULT", icon: "lock.doc", highlighted: true) {
                vaultContent
            }
            receiptSection(title: "ATTENTION", icon: "exclamationmark.circle", highlighted: false) {
                attentionContent
            }

            dashedDivider
            ReceiptActionButton(
                title: reviewCount == 0 ? "DATA REVIEW COMPLETE" : "REVIEW DATA SUGGESTIONS",
                detail: reviewCount == 0 ? "No suggestions" : "\(reviewCount) to review",
                icon: reviewCount == 0 ? "checkmark.circle" : "text.badge.checkmark",
                enabled: reviewCount > 0,
                action: onShowReview
            )
            ReceiptActionButton(
                title: "REMINDERS & COMPLETE LATER",
                detail: "Open owner briefing tasks",
                icon: "checklist",
                action: onShowReminders
            )
            ReceiptActionButton(
                title: "EXPLORE CONNECTIONS",
                detail: "See how records are linked",
                icon: "point.3.connected.trianglepath.dotted",
                action: onExploreConnections
            )

            VStack(spacing: 4) {
                Text("BASED ON SAVED RECORDS")
                Text("BALANCES AND CONNECTIONS REMAIN UNCHANGED")
            }
            .font(.system(.caption2, design: .monospaced).weight(.medium))
            .foregroundStyle(BriefingReceiptTheme.fadedInk)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .padding(22)
        .background(BriefingReceiptTheme.paper)
        .clipShape(ReceiptPaperShape())
        .overlay {
            ReceiptPaperShape()
                .stroke(BriefingReceiptTheme.ink.opacity(0.14), lineWidth: 1)
        }
        .foregroundStyle(BriefingReceiptTheme.ink)
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }

    private var receiptHeader: some View {
        VStack(spacing: 5) {
            Text("EXECUTIVE BRIEFING")
                .font(.system(.headline, design: .monospaced).weight(.bold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(Color(hex: "#3A3A3C"))
            Text(now.formatted(date: .numeric, time: .shortened))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(BriefingReceiptTheme.fadedInk)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var selectors: some View {
        VStack(spacing: 10) {
            Menu {
                ForEach(visibleScopes) { scope in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        selectedScope = scope
                    } label: {
                        if selectedScope == scope {
                            Label(scope.rawValue, systemImage: "checkmark")
                        } else {
                            Text(scope.rawValue)
                        }
                    }
                }
            } label: {
                ReceiptPickerLabel(label: "BRIEFING", value: selectedScope.rawValue)
            }
            .accessibilityLabel("Briefing profile")
            .accessibilityValue(selectedScope.rawValue)

            Menu {
                ForEach(CashFlowMonth.recent(count: 12, from: now)) { month in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        financialMonth = month
                    } label: {
                        if financialMonth == month {
                            Label(month.title(), systemImage: "checkmark")
                        } else {
                            Text(month.title())
                        }
                    }
                }
            } label: {
                ReceiptPickerLabel(label: "MONTH", value: financialMonth.title())
            }
            .accessibilityLabel("Report month")
            .accessibilityValue(financialMonth.title())
        }
    }

    @ViewBuilder
    private var financialContent: some View {
        if transactionCount == 0 {
            receiptNote("No posted transactions in \(financialMonth.title()).")
        } else {
            ForEach(financials) { summary in
                if financials.count > 1 || summary.currency != "USD" {
                    receiptSubheading(summary.currency)
                }
                receiptRow("Income", receiptMoney(summary.income, summary.currency))
                receiptRow("Outflow", receiptMoney(summary.insight.current.moneyOut, summary.currency))
                receiptRow("Refunds", receiptMoney(summary.refunds, summary.currency))
                receiptTotal("NET CASH FLOW", receiptMoney(summary.insight.current.net, summary.currency))
                spendingComparison(summary)

                highlightedReceiptSubheading("3 LARGEST EXPENSES")
                let largestExpenses = summary.insight.expenseRecords.sorted {
                    abs($0.transaction.amount ?? 0) > abs($1.transaction.amount ?? 0)
                }.prefix(3)
                if largestExpenses.isEmpty {
                    receiptNote("No expenses recorded this month.")
                } else {
                    ForEach(Array(largestExpenses)) { record in
                        receiptRow(
                            TransactionIntelligence.displayName(for: record),
                            receiptMoney(abs(record.transaction.amount ?? 0), summary.currency),
                            detail: largestExpenseDetail(record)
                        )
                    }
                }

                if !summary.insight.expenseCategories.isEmpty {
                    highlightedReceiptSubheading("TOP SPENDING CATEGORIES")
                    ForEach(summary.insight.expenseCategories.prefix(3), id: \.key) { category in
                        receiptRow(category.label, receiptMoney(category.amount, summary.currency))
                    }
                }
            }
        }
        ReceiptActionButton(
            title: "SEE ALL SPENDING CATEGORIES",
            detail: nil,
            icon: "chart.pie",
            enabled: financials.contains { !$0.insight.expenseCategories.isEmpty },
            action: onShowCategories
        )
        ReceiptActionButton(
            title: "VIEW TRANSACTIONS",
            detail: "\(transactionCount) in \(financialMonth.title())",
            icon: "list.bullet.rectangle",
            action: onShowTransactions
        )

        highlightedReceiptSubheading("FINANCIAL POSITION")
        receiptRow("Cash", receiptAmounts(cashBalances, empty: "—"))
        receiptRow("Savings", receiptAmounts(savingsBalances, empty: "—"))
        receiptRow("Retirement", receiptAmounts(retirementBalances, empty: "—"))
        receiptRow("Debt", receiptMoney(totalDebt, "USD"))
        receiptRow(
            "Credit available",
            receiptMoney(availableCredit, "USD"),
            detail: "Debt-to-credit ratio · \(debtToCreditRatio)"
        )
        ReceiptActionButton(
            title: "ACCOUNTS, CARDS & LOANS",
            detail: "\(accountCount) financial records",
            icon: "wallet.bifold",
            action: onShowAccounts
        )
        if snapshot.unassignedTransactionCount > 0 {
            receiptNote("\(snapshot.unassignedTransactionCount) unassigned transactions are excluded from totals.")
        }
    }

    private var activeAccounts: [InstitutionAccount] {
        snapshot.institutions
            .flatMap(\.accounts)
            .filter { ExecutiveBriefingSnapshot.isActive($0.status) }
    }

    private var cashBalances: [String: Double] {
        accountBalances(matching: { type in
            ["checking", "cash management", "depository"].contains(type)
        })
    }

    private var savingsBalances: [String: Double] {
        accountBalances(matching: { type in
            ["savings", "cd", "money market"].contains(type)
        })
    }

    private var retirementBalances: [String: Double] {
        accountBalances(matching: { type in
            type.contains("401") || type.contains("ira") || type.contains("retirement") || type.contains("pension")
        })
    }

    private var activeCreditCards: [FinancialCard] {
        snapshot.cards.filter {
            ExecutiveBriefingSnapshot.isActive($0.status) && $0.type.lowercased().contains("credit")
        }
    }

    private var totalDebt: Double {
        activeCreditCards.reduce(0) { $0 + max(0, $1.balance) }
            + snapshot.loans.filter { $0.isLender && ExecutiveBriefingSnapshot.isActive($0.status) }
                .reduce(0) { $0 + max(0, $1.remainingBalance) }
    }

    private var totalCreditLimit: Double {
        activeCreditCards.reduce(0) { $0 + max(0, $1.limit) }
    }

    private var availableCredit: Double {
        activeCreditCards.reduce(0) { $0 + max(0, $1.limit - $1.balance) }
    }

    private var debtToCreditRatio: String {
        guard totalCreditLimit > 0 else { return "—" }
        return (totalDebt / totalCreditLimit).formatted(.percent.precision(.fractionLength(0)))
    }

    private func accountBalances(matching predicate: (String) -> Bool) -> [String: Double] {
        activeAccounts.filter {
            predicate($0.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        }.reduce(into: [:]) { result, account in
            result[ExecutiveBriefingSnapshot.currency(account.currency), default: 0] += account.balance
        }
    }

    @ViewBuilder
    private func spendingComparison(_ summary: ExecutiveCurrencySummary) -> some View {
        let current = summary.insight.current.moneyOut
        let previous = summary.insight.previous.moneyOut
        if current > 0 || previous > 0 {
            let change = current - previous
            if abs(change) < 0.005 {
                receiptNote("Spent the same amount as last month.")
            } else {
                receiptNote(
                    "Spent \(receiptMoney(abs(change), summary.currency)) \(change > 0 ? "more" : "less") than last month."
                )
            }
        }
    }

    private func largestExpenseDetail(_ record: ResolvedTransaction) -> String {
        let rawCategory = TransactionIntelligence.categoryPrimary(for: record)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let category = rawCategory.isEmpty ? "Uncategorized" : rawCategory
        return "\(category.capitalized) · \(record.transaction.date)"
    }

    @ViewBuilder
    private var servicesContent: some View {
        receiptRow("Active bills", "\(snapshot.activeBillCount)")
        receiptRow("Subscriptions", "\(snapshot.activeSubscriptionCount)")
        receiptRow("Add-ons", "\(snapshot.supplementalCount)")
        receiptTotal("MONTHLY RECURRING", receiptAmounts(monthlyRecurringTotals, empty: "—"))
        receiptTotal("YEARLY RECURRING", receiptAmounts(yearlyRecurringTotals, empty: "—"))

        let projection = ExecutiveCardMetrics(snapshot: snapshot, now: now).upcoming
        highlightedReceiptSubheading("UPCOMING PAYMENTS · NEXT 7 DAYS")
        receiptRow("Payments due", "\(projection.chargeCount)")
        receiptRow("May fall short", "\(projection.atRiskCount)")
        receiptRow("Unable to verify", "\(projection.unknownCount)")
        if projection.groups.isEmpty {
            receiptNote(projection.unscheduledCount > 0
                ? "No dated payments in this window. \(projection.unscheduledCount) services need a renewal date."
                : "No scheduled payments in this window.")
        } else {
            ForEach(projection.groups.prefix(4)) { group in
                coverageRow(group)
            }
            if projection.groups.count > 4 {
                receiptNote("+\(projection.groups.count - 4) more payment sources")
            }
        }

        serviceDisclosure(.bill)
        serviceDisclosure(.subscription)
        if snapshot.unknownBillingCount > 0 {
            receiptNote("\(snapshot.unknownBillingCount) billing cycles could not be included in the monthly estimate.")
        }
    }

    private var activeServices: [Subscription] {
        snapshot.subscriptions.filter { ExecutiveBriefingSnapshot.isActive($0.status) }
    }

    private var monthlyRecurringTotals: [String: Double] {
        recurringTotals(forCycle: "monthly")
    }

    private var yearlyRecurringTotals: [String: Double] {
        recurringTotals(forCycle: "yearly")
    }

    private func recurringTotals(forCycle cycle: String) -> [String: Double] {
        activeServices.reduce(into: [:]) { result, service in
            let currency = ExecutiveBriefingSnapshot.currency(service.currency)
            let normalizedCycle = service.billingCycle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalizedCycle == cycle && !service.isFree {
                result[currency, default: 0] += service.cost
            }
            for addOn in service.subServices where addOn.status == .active {
                let matches = cycle == "monthly" ? addOn.billingCycle == .monthly : addOn.billingCycle == .yearly
                if matches { result[currency, default: 0] += addOn.cost }
            }
        }
    }

    private func monthlyEquivalentTotals(for services: [Subscription]) -> [String: Double] {
        services.reduce(into: [:]) { result, service in
            let currency = ExecutiveBriefingSnapshot.currency(service.currency)
            if let base = ExecutiveBriefingSnapshot.monthlyCost(service) {
                result[currency, default: 0] += base
            }
            for addOn in service.subServices where addOn.status == .active {
                result[currency, default: 0] += addOn.billingCycle == .yearly ? addOn.cost / 12 : addOn.cost
            }
        }
    }

    @ViewBuilder
    private func serviceDisclosure(_ type: RecurringServiceType) -> some View {
        let services = activeServices.filter { $0.resolvedServiceType == type }
        let isExpanded = type == .bill ? billsExpanded : subscriptionsExpanded
        let title = type == .bill ? "BILLS" : "SUBSCRIPTIONS"

        if !services.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if type == .bill { billsExpanded.toggle() }
                        else { subscriptionsExpanded.toggle() }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(title)
                        Text("\(services.count) \(services.count == 1 ? "ITEM" : "ITEMS")")
                            .foregroundStyle(BriefingReceiptTheme.fadedInk)
                        Spacer(minLength: 8)
                        Text(receiptAmounts(monthlyEquivalentTotals(for: services), empty: "—") + "/MO")
                            .multilineTextAlignment(.trailing)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundStyle(BriefingReceiptTheme.ink)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(BriefingReceiptTheme.paper, in: RoundedRectangle(cornerRadius: 7))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(BriefingReceiptTheme.gold.opacity(0.75), lineWidth: 1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

                if isExpanded {
                    ForEach(services) { service in
                        receiptResourceRow(
                            service.name,
                            receiptMoney(service.cost, service.currency),
                            detail: service.nextRenewalAt.map { "Due \($0.formatted(date: .abbreviated, time: .omitted))" }
                                ?? service.nextRenewal.map { "Due \($0)" }
                                ?? service.billingCycle,
                            kind: .subscription,
                            id: service.id
                        )
                    }
                }
            }
            .padding(.horizontal, 10)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(BriefingReceiptTheme.ink.opacity(0.15), lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private var vaultContent: some View {
        let metrics = ExecutiveCardMetrics(snapshot: snapshot, now: now)
        receiptRow("Documents", "\(snapshot.documents.count)")
        receiptRow("With expiration dates", "\(metrics.datedDocumentCount)")
        receiptRow("Expired", "\(metrics.expiredDocuments.count)")
        receiptRow("Expiring in 60 days", "\(metrics.expiringDocuments.count)")

        let categories = Array(Set(snapshot.documents.map { CompanyDocument.normalizeType($0.type) })).sorted()
        if categories.isEmpty {
            receiptNote("No vault documents added.")
        } else {
            receiptSubheading("DOCUMENT CATEGORIES")
            ForEach(categories, id: \.self) { category in
                receiptRow(category, "\(snapshot.documents.filter { CompanyDocument.normalizeType($0.type) == category }.count)")
            }
        }
        let sortedDocuments = snapshot.documents.sorted {
            ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture)
        }
        if !sortedDocuments.isEmpty {
            receiptSubheading("DOCUMENTS")
            ForEach(sortedDocuments) { document in
                receiptResourceRow(
                    document.name,
                    document.expiresAt?.formatted(date: .abbreviated, time: .omitted)
                        ?? CompanyDocument.normalizeType(document.type),
                    kind: .document,
                    id: document.id
                )
            }
        }
    }

    @ViewBuilder
    private var attentionContent: some View {
        if notices.isEmpty {
            Label("No urgent notices", systemImage: "checkmark.circle.fill")
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(Color.zifrGreen)
                .frame(minHeight: 44)
        } else {
            ForEach(notices.prefix(5)) { notice in
                Button { onOpenUrgent(notice) } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(Color.red)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(notice.title.uppercased())
                                .font(.system(.caption, design: .monospaced).weight(.bold))
                            Text("\(notice.entityName) · \(notice.detail)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(BriefingReceiptTheme.fadedInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                    }
                    .foregroundStyle(BriefingReceiptTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func coverageRow(_ group: UpcomingCoverageGroup) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: coverageIcon(group.status))
                    .foregroundStyle(coverageColor(group.status))
                Text(group.sourceName)
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                Spacer(minLength: 6)
                Text(coverageTitle(group.status))
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundStyle(coverageColor(group.status))
            }
            Text(coverageDetail(group))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(BriefingReceiptTheme.fadedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 5)
    }

    private func coverageTitle(_ status: UpcomingCoverageStatus) -> String {
        switch status {
        case .covered: return "FUNDED"
        case .atRisk: return "SHORT"
        case .unknown: return "CHECK LINK"
        }
    }

    private func coverageIcon(_ status: UpcomingCoverageStatus) -> String {
        switch status {
        case .covered: return "checkmark.circle.fill"
        case .atRisk: return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    private func coverageColor(_ status: UpcomingCoverageStatus) -> Color {
        switch status {
        case .covered: return Color.zifrGreen
        case .atRisk: return Color.red
        case .unknown: return Color.red
        }
    }

    private func coverageDetail(_ group: UpcomingCoverageGroup) -> String {
        let due = BriefingFormat.money(group.totalDue, group.currency)
        if let reason = group.reason { return "\(due) due · \(reason)" }
        guard let available = group.availableAmount, let difference = group.difference else {
            return "\(due) due · available funds unavailable"
        }
        let availableText = BriefingFormat.money(available, group.currency)
        let result = difference >= 0
            ? "\(BriefingFormat.money(difference, group.currency)) left"
            : "\(BriefingFormat.money(abs(difference), group.currency)) short"
        let route = group.paymentRoutes.isEmpty ? "" : " via \(group.paymentRoutes.joined(separator: ", "))"
        return "\(due) due · \(group.availableLabel) \(availableText) · \(result)\(route)"
    }

    private func receiptSection<Content: View>(
        title: String,
        icon: String,
        highlighted: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            dashedDivider
            ReceiptMarkerSectionHeader(title: title, icon: icon, highlighted: highlighted)
            content()
        }
    }

    private var dashedDivider: some View {
        Text(String(repeating: "- ", count: 45))
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(BriefingReceiptTheme.fadedInk)
            .lineLimit(1)
            .accessibilityHidden(true)
    }

    private func receiptSubheading(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption2, design: .monospaced).weight(.bold))
            .tracking(0.7)
            .foregroundStyle(BriefingReceiptTheme.fadedInk)
            .padding(.top, 3)
            .accessibilityAddTraits(.isHeader)
    }

    private func highlightedReceiptSubheading(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption2, design: .monospaced).weight(.bold))
            .tracking(0.7)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
            .background(Color(hex: "#3A3A3C"))
            .accessibilityAddTraits(.isHeader)
    }

    private func receiptRow(_ label: String, _ value: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label)
                Spacer(minLength: 8)
                Text(value).fontWeight(.semibold).multilineTextAlignment(.trailing)
            }
            if let detail {
                Text(detail)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(BriefingReceiptTheme.fadedInk)
            }
        }
        .font(.system(.caption, design: .monospaced))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func receiptTotal(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
            Spacer(minLength: 8)
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.system(.caption, design: .monospaced).weight(.bold))
        .padding(.vertical, 7)
        .overlay(alignment: .top) { Rectangle().frame(height: 1).foregroundStyle(BriefingReceiptTheme.ink) }
        .overlay(alignment: .bottom) { Rectangle().frame(height: 1).foregroundStyle(BriefingReceiptTheme.ink) }
    }

    private func receiptResourceRow(
        _ label: String,
        _ value: String,
        detail: String? = nil,
        kind: ResourceKind,
        id: UUID
    ) -> some View {
        Button { onOpenResource(kind, id) } label: {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                    if let detail {
                        Text(detail)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(BriefingReceiptTheme.fadedInk)
                    }
                }
                Spacer(minLength: 8)
                Text(value).fontWeight(.semibold).multilineTextAlignment(.trailing)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(BriefingReceiptTheme.gold)
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(BriefingReceiptTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func receiptNote(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(BriefingReceiptTheme.fadedInk)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func receiptMoney(_ value: Double, _ currency: String) -> String {
        guard currency != "Unknown currency" else { return value.formatted() }
        let formatted = value.formatted(
            .currency(code: currency).precision(.fractionLength(0...2))
        )
        return currency == "USD" ? formatted : "\(formatted) \(currency)"
    }

    private func receiptAmounts(_ values: [String: Double], empty: String) -> String {
        guard !values.isEmpty else { return empty }
        return values.keys.sorted().map { receiptMoney(values[$0] ?? 0, $0) }.joined(separator: "\n")
    }
}

struct ReceiptPaperShape: Shape {
    private let toothWidth: CGFloat = 12
    private let toothDepth: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + toothDepth))

        var x = rect.minX
        var pointsUp = true
        while x < rect.maxX {
            x = min(x + toothWidth / 2, rect.maxX)
            path.addLine(to: CGPoint(x: x, y: rect.minY + (pointsUp ? 0 : toothDepth)))
            pointsUp.toggle()
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct ReceiptMarkerSectionHeader: View {
    let title: String
    let icon: String
    let highlighted: Bool
    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(.subheadline, design: .monospaced).weight(.bold))
        .padding(.horizontal, highlighted ? 7 : 0)
        .padding(.vertical, 3)
        .background(alignment: .leading) {
            if highlighted {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(hex: "#FFF09A").opacity(0.72))
                    .rotationEffect(.degrees(-0.8))
                    .scaleEffect(x: isRevealed ? 1 : 0.02, y: 1, anchor: .leading)
            }
        }
        .accessibilityAddTraits(.isHeader)
        .onAppear {
            guard highlighted else { return }
            withAnimation(.easeOut(duration: 1.25).delay(0.12)) {
                isRevealed = true
            }
        }
    }
}

private struct ReceiptPickerLabel: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .foregroundStyle(BriefingReceiptTheme.fadedInk)
            Text(value.uppercased())
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundStyle(BriefingReceiptTheme.ink)
            Spacer(minLength: 6)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2.weight(.bold))
                .foregroundStyle(BriefingReceiptTheme.gold)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(BriefingReceiptTheme.paper, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(BriefingReceiptTheme.gold.opacity(0.75), lineWidth: 1)
        }
        .contentShape(Rectangle())
    }
}

private struct ReceiptActionButton: View {
    let title: String
    let detail: String?
    let icon: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.68))
                    }
                }
                Spacer(minLength: 6)
                if enabled {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(BriefingReceiptTheme.gold)
                }
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(BriefingReceiptTheme.ink, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(BriefingReceiptTheme.gold.opacity(0.7), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.7)
    }
}

private struct ReceiptHUDShell<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(hex: "#1C1C1E")
                    .ignoresSafeArea()

                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(spacing: 4) {
                            Text(title.uppercased())
                                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                            Text(subtitle.uppercased())
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(BriefingReceiptTheme.fadedInk)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isHeader)

                        ReceiptDash()
                        content
                        ReceiptDash()
                        Text("END OF REPORT")
                            .font(.system(.caption2, design: .monospaced).weight(.medium))
                            .foregroundStyle(BriefingReceiptTheme.fadedInk)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(22)
                    .frame(width: max(geometry.size.width - 40, 0))
                    .background(BriefingReceiptTheme.paper)
                    .clipShape(ReceiptPaperShape())
                    .overlay {
                        ReceiptPaperShape()
                            .stroke(BriefingReceiptTheme.ink.opacity(0.14), lineWidth: 1)
                    }
                    .foregroundStyle(BriefingReceiptTheme.ink)
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                .scrollIndicators(.hidden)
                .clipped()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .presentationBackground(Color(hex: "#1C1C1E"))
        .preferredColorScheme(.light)
    }
}

private struct ReceiptDash: View {
    var body: some View {
        Text(String(repeating: "- ", count: 45))
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(BriefingReceiptTheme.fadedInk)
            .lineLimit(1)
            .accessibilityHidden(true)
    }
}

private struct BriefingTransactionsReceipt: View {
    let snapshot: ExecutiveBriefingSnapshot
    let month: CashFlowMonth
    let now: Date

    private var financials: [ExecutiveCurrencySummary] {
        ExecutiveBriefingSnapshot.financials(records: snapshot.records, now: now, month: month)
    }

    var body: some View {
        ReceiptHUDShell(title: "Transactions", subtitle: "\(snapshot.scope.rawValue) · \(month.title())") {
            if financials.allSatisfy({ $0.insight.records.isEmpty }) {
                Text("NO POSTED TRANSACTIONS")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 88)
            } else {
                ForEach(financials) { summary in
                    transactionSummary(summary)
                    ForEach(grouped(summary.insight.records), id: \.date) { group in
                        Text(formattedDate(group.date).uppercased())
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                            .tracking(0.6)
                            .foregroundStyle(BriefingReceiptTheme.fadedInk)
                            .padding(.top, 6)
                        ForEach(group.records) { record in
                            transactionRow(record, currency: summary.currency)
                        }
                    }
                    ReceiptDash()
                }
                Text("Posted transactions only. Transfers, ignored items, and pending transactions are excluded from cash flow totals.")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(BriefingReceiptTheme.fadedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func transactionSummary(_ summary: ExecutiveCurrencySummary) -> some View {
        VStack(spacing: 5) {
            Text(summary.currency)
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            compactRow("INCOME", BriefingFormat.money(summary.income, summary.currency))
            compactRow("OUTFLOW", BriefingFormat.money(summary.insight.current.moneyOut, summary.currency))
            compactRow("NET", BriefingFormat.money(summary.insight.current.net, summary.currency), bold: true)
        }
    }

    private func transactionRow(_ record: ResolvedTransaction, currency: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(TransactionIntelligence.displayName(for: record))
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(flowName(record)) · \(record.accountName)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(BriefingReceiptTheme.fadedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text(flowAmount(record, currency: currency))
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }

    private func compactRow(_ label: String, _ value: String, bold: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
            Spacer(minLength: 8)
            Text(value)
        }
        .font(.system(.caption2, design: .monospaced).weight(bold ? .bold : .regular))
        .padding(.vertical, bold ? 5 : 0)
        .overlay(alignment: bold ? .top : .center) {
            if bold { Rectangle().frame(height: 1) }
        }
    }

    private func grouped(_ records: [ResolvedTransaction]) -> [(date: String, records: [ResolvedTransaction])] {
        Dictionary(grouping: records, by: { $0.transaction.date })
            .map { (date: $0.key, records: $0.value) }
            .sorted { $0.date > $1.date }
    }

    private func formattedDate(_ value: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: value) else { return value }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private func flowName(_ record: ResolvedTransaction) -> String {
        switch TransactionIntelligence.effectiveFlow(for: record) {
        case .income: return "Income"
        case .refund: return "Refund"
        case .expense: return "Expense"
        case .transfer: return "Transfer"
        case .ignored: return "Ignored"
        }
    }

    private func flowAmount(_ record: ResolvedTransaction, currency: String) -> String {
        let amount = BriefingFormat.money(abs(record.transaction.amount ?? 0), currency)
        switch TransactionIntelligence.effectiveFlow(for: record) {
        case .income, .refund: return "+\(amount)"
        case .expense: return "−\(amount)"
        case .transfer, .ignored: return amount
        }
    }
}

private struct BriefingSpendingCategoriesReceipt: View {
    let summaries: [ExecutiveCurrencySummary]
    let month: CashFlowMonth
    @State private var expandedCategoryIDs: Set<String> = []

    var body: some View {
        ReceiptHUDShell(title: "Spending by category", subtitle: month.title()) {
            if summaries.allSatisfy({ $0.insight.expenseCategories.isEmpty }) {
                Text("NO SPENDING IN THIS MONTH")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 88)
            } else {
                ForEach(summaries) { summary in
                    if summaries.count > 1 || summary.currency != "USD" {
                        Text(summary.currency)
                            .font(.system(.caption, design: .monospaced).weight(.bold))
                    }
                    compactRow("TOTAL SPENT", money(summary.insight.current.moneyOut, summary.currency), bold: true)

                    ForEach(summary.insight.expenseCategories, id: \.key) { category in
                        categoryDisclosure(category, summary: summary)
                    }
                    ReceiptDash()
                }
            }

            Text("Posted spending only. Transfers, payments, ignored items, and pending transactions are excluded.")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(BriefingReceiptTheme.fadedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func categoryDisclosure(
        _ category: CashFlowExpenseConcentration,
        summary: ExecutiveCurrencySummary
    ) -> some View {
        let categoryID = "\(summary.currency):\(category.key)"
        let expanded = expandedCategoryIDs.contains(categoryID)
        let transactions = categoryTransactions(category, summary: summary)

        return VStack(alignment: .leading, spacing: 5) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expanded { expandedCategoryIDs.remove(categoryID) }
                    else { expandedCategoryIDs.insert(categoryID) }
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.label.uppercased())
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                        Text("\(category.transactionCount) \(category.transactionCount == 1 ? "transaction" : "transactions") · \(Int((category.share * 100).rounded()))%")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(BriefingReceiptTheme.fadedInk)
                    }
                    Spacer(minLength: 8)
                    Text(money(category.amount, summary.currency))
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .foregroundStyle(BriefingReceiptTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(expanded ? "Expanded" : "Collapsed")

            if expanded {
                ForEach(transactions) { record in
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(TransactionIntelligence.displayName(for: record))
                                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                            Text("\(record.transaction.date) · \(record.accountName)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(BriefingReceiptTheme.fadedInk)
                        }
                        Spacer(minLength: 8)
                        Text(money(abs(record.transaction.amount ?? 0), summary.currency))
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                    }
                    .padding(.leading, 10)
                    .padding(.vertical, 4)
                }
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().frame(height: 1).foregroundStyle(BriefingReceiptTheme.ink.opacity(0.12))
        }
    }

    private func categoryTransactions(
        _ category: CashFlowExpenseConcentration,
        summary: ExecutiveCurrencySummary
    ) -> [ResolvedTransaction] {
        summary.insight.expenseRecords.filter { record in
            let raw = TransactionIntelligence.categoryPrimary(for: record)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return (raw.isEmpty ? "OTHER" : raw).uppercased() == category.key
        }.sorted {
            if $0.transaction.date == $1.transaction.date { return $0.id.uuidString < $1.id.uuidString }
            return $0.transaction.date > $1.transaction.date
        }
    }

    private func compactRow(_ label: String, _ value: String, bold: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
            Spacer(minLength: 8)
            Text(value)
        }
        .font(.system(.caption, design: .monospaced).weight(bold ? .bold : .regular))
        .padding(.vertical, 6)
        .overlay(alignment: .top) { if bold { Rectangle().frame(height: 1) } }
        .overlay(alignment: .bottom) { if bold { Rectangle().frame(height: 1) } }
    }

    private func money(_ value: Double, _ currency: String) -> String {
        guard currency != "Unknown currency" else { return value.formatted() }
        let formatted = value.formatted(.currency(code: currency).precision(.fractionLength(0...2)))
        return currency == "USD" ? formatted : "\(formatted) \(currency)"
    }
}

private struct BriefingAccountsReceipt: View {
    let snapshot: ExecutiveBriefingSnapshot
    let onOpen: (ResourceKind, UUID) -> Void

    var body: some View {
        ReceiptHUDShell(title: "Financial records", subtitle: "\(snapshot.scope.rawValue) accounts, cards & loans") {
            if snapshot.institutions.isEmpty && snapshot.cards.isEmpty && snapshot.loans.isEmpty {
                Text("NO FINANCIAL RECORDS")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 88)
            }

            ForEach(snapshot.institutions) { institution in
                resourceButton(
                    institution.name,
                    detail: institution.isDisconnected ? "RECONNECT REQUIRED" : "\(institution.accounts.count) ACCOUNTS",
                    icon: "building.columns",
                    kind: .institution,
                    id: institution.id
                )
                ForEach(institution.accounts) { account in
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("↳ \((account.name.isEmpty ? account.type : account.name).uppercased())")
                                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                            Text("\(account.type) · ••••\(account.last4.isEmpty ? "—" : account.last4)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(BriefingReceiptTheme.fadedInk)
                        }
                        Spacer(minLength: 8)
                        Text(BriefingFormat.money(account.availableBalance ?? account.balance, account.currency))
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.leading, 8)
                    .padding(.vertical, 4)
                }
                ReceiptDash()
            }

            if !snapshot.cards.isEmpty {
                sectionLabel("CARDS")
                ForEach(snapshot.cards) { card in
                    resourceButton(
                        card.name + ((card.last4 ?? "").isEmpty ? "" : " · ••••\(card.last4!)"),
                        detail: "\(card.type) · \(card.status) · BAL \(card.balance.formatted())",
                        icon: "creditcard",
                        kind: .card,
                        id: card.id
                    )
                }
            }

            if !snapshot.loans.isEmpty {
                sectionLabel("LOANS")
                ForEach(snapshot.loans) { loan in
                    resourceButton(
                        loan.name,
                        detail: "\(loan.role) · BAL \(loan.remainingBalance.formatted())",
                        icon: "banknote",
                        kind: .loan,
                        id: loan.id
                    )
                }
            }

            Text("Account balances use the latest saved values. Card and loan records show their stored balance without assuming a currency.")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(BriefingReceiptTheme.fadedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(.caption, design: .monospaced).weight(.bold))
            .tracking(0.7)
            .padding(.top, 4)
            .accessibilityAddTraits(.isHeader)
    }

    private func resourceButton(
        _ title: String,
        detail: String,
        icon: String,
        kind: ResourceKind,
        id: UUID
    ) -> some View {
        Button { onOpen(kind, id) } label: {
            HStack(spacing: 10) {
                Image(systemName: icon).frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased())
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(BriefingReceiptTheme.fadedInk)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(BriefingReceiptTheme.gold)
            }
            .foregroundStyle(BriefingReceiptTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct BriefingReviewReceipt: View {
    let health: OwnerHealthSnapshot
    let onOpen: (OwnerHealthDataIssue) -> Void
    let onIgnore: (OwnerHealthDataIssue) -> Void
    let onReviewRecurring: ([DetectedSubscription]) -> Void
    @State private var ignoredInSheet: Set<String> = []

    private var issues: [OwnerHealthDataIssue] {
        health.categories.flatMap(\.dataIssues).filter { !ignoredInSheet.contains($0.id) }
    }

    private var recurring: [DetectedSubscription] {
        var seen = Set<String>()
        return health.categories.flatMap(\.recurringSuggestions).filter { seen.insert($0.id).inserted }
    }

    var body: some View {
        ReceiptHUDShell(title: "Review data", subtitle: "\(health.scope.rawValue) suggestions") {
            Text("Optional details that can make reports and reminders more complete.")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(BriefingReceiptTheme.fadedInk)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(health.categories.filter { $0.requiresAttention }) { summary in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: summary.category.icon)
                        .foregroundStyle(summary.status == .critical ? Color.red : Color.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(summary.category.title.uppercased())
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                        Text(summary.summary)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(BriefingReceiptTheme.fadedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
            }

            if issues.isEmpty && recurring.isEmpty {
                Label("SUGGESTIONS CLEARED", systemImage: "checkmark.circle.fill")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundStyle(Color.zifrGreen)
                    .frame(maxWidth: .infinity, minHeight: 88)
            }

            ForEach(issues) { issue in
                ReceiptDash()
                VStack(alignment: .leading, spacing: 9) {
                    Text(issue.resourceName.uppercased())
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                    Text(issue.entityName)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(BriefingReceiptTheme.fadedInk)
                    ForEach(issue.missingFields, id: \.self) { field in
                        Text("• \(field)")
                            .font(.system(.caption2, design: .monospaced))
                    }
                    HStack(spacing: 10) {
                        smallButton("ADD INFORMATION", filled: true) { onOpen(issue) }
                        smallButton("IGNORE", filled: false) {
                            ignoredInSheet.insert(issue.id)
                            onIgnore(issue)
                        }
                    }
                }
            }

            if !recurring.isEmpty {
                ReceiptDash()
                Text("DETECTED RECURRING CHARGES")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                ForEach(recurring) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name.uppercased())
                                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                            Text("\(item.frequency) · \(item.occurrences) charges")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(BriefingReceiptTheme.fadedInk)
                        }
                        Spacer(minLength: 8)
                        Text(BriefingFormat.money(item.amount, item.currency))
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                    }
                }
                ReceiptActionButton(
                    title: "REVIEW RECURRING CHARGES",
                    detail: "\(recurring.count) possible services",
                    icon: "sparkle.magnifyingglass"
                ) {
                    onReviewRecurring(recurring)
                }
            }
        }
    }

    private func smallButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .foregroundStyle(filled ? Color.white : BriefingReceiptTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(filled ? BriefingReceiptTheme.gold : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(BriefingReceiptTheme.gold, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

enum BriefingFormat {
    static func cardAmounts(_ values: [String: Double], empty: String, signed: Bool = false) -> String {
        guard !values.isEmpty else { return empty }
        guard values.count == 1 else { return "\(values.count) currencies" }
        let currency = values.keys.first!
        guard currency != "Unknown currency" else { return "Unknown" }
        let value = values[currency]!
        return (signed && value > 0 ? "+" : "") + compactMoney(value, currency)
    }

    static func count(_ value: Int, _ singular: String, plural: String? = nil) -> String {
        "\(value) \(value == 1 ? singular : plural ?? singular + "s")"
    }

    static func money(_ value: Double, _ currency: String) -> String {
        guard currency != "Unknown currency" else { return "\(value.formatted()) · currency unknown" }
        return value.formatted(.currency(code: currency).precision(.fractionLength(0...2))) + " \(currency)"
    }
    static func compactMoney(_ value: Double, _ currency: String) -> String {
        guard currency != "Unknown currency" else { return "—" }
        let absolute = abs(value)
        let scale: Double
        let magnitude: String
        switch absolute {
        case 1_000_000_000...: scale = 1_000_000_000; magnitude = "B"
        case 1_000_000...: scale = 1_000_000; magnitude = "M"
        case 10_000...: scale = 1_000; magnitude = "K"
        default: scale = 1; magnitude = ""
        }
        let code = currency == "USD" ? "" : " \(currency)"
        return (value / scale).formatted(
            .currency(code: currency).precision(.fractionLength(0...1))
        ) + magnitude + code
    }
    static func amounts(_ values: [String: Double], empty: String) -> String {
        values.isEmpty ? empty : values.keys.sorted().map { money(values[$0] ?? 0, $0) }.joined(separator: "\n")
    }
    static func compactAmounts(_ values: [String: Double], empty: String) -> String {
        values.isEmpty ? empty : values.keys.sorted().map { compactMoney(values[$0] ?? 0, $0) }.joined(separator: "\n")
    }
}
