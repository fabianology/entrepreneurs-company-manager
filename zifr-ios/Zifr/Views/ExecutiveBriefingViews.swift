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

struct ClassicOwnerHealthBriefingDashboard: View {
    @Environment(AppState.self) private var appState
    @Bindable var vm: AppViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedScope: OwnerBriefingScope?
    @State private var selectedSection: ExecutiveBriefingSection?
    @State private var pendingNavigation: (() -> Void)?
    var onOpenResource: (PortfolioObligation) -> Void
    var onOpenHealthResource: (ResourceKind, UUID) -> Void
    var onExploreConnections: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 12) {
                ForEach(ExecutiveBriefingLayout.visibleScopes(companies: appState.companies)) { scope in
                    ExecutiveSummaryCard(
                        snapshot: ExecutiveBriefingSnapshot(appState: appState, scope: scope, now: context.date),
                        now: context.date,
                        urgentNotices: ExecutiveUrgentNotice.cardNotices(in: appState, scope: scope, now: context.date),
                        onOpenUrgent: openUrgent
                    ) { section in
                        selectedSection = section
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedScope = scope
                    }
                }

                Button(action: onExploreConnections) {
                    HStack(spacing: 10) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                        Text("Explore connections")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(MiloomSecondaryButtonStyle())
                .accessibilityLabel("Explore connections")
                .accessibilityHint("Opens the portfolio connection map")
            }
        }
        .sheet(item: $selectedScope, onDismiss: finishPendingNavigation) { scope in
            ExecutiveBreakdownView(
                scope: scope,
                vm: vm,
                initialSection: selectedSection,
                onOpenResource: { obligation in
                    pendingNavigation = { onOpenResource(obligation) }
                    selectedScope = nil
                },
                onOpenHealthResource: { kind, id in
                    pendingNavigation = { onOpenHealthResource(kind, id) }
                    selectedScope = nil
                }
            )
            .dynamicTypeSize(dynamicTypeSize)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
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

private enum BriefingReceiptTheme {
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
            detail: "Category totals and transactions for \(financialMonth.title())",
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

private struct ReceiptPaperShape: Shape {
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

private struct ReceiptMarkerSectionHeader: View {
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
    let detail: String
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
                    Text(detail)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.68))
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
    @Environment(\.dismiss) private var dismiss
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
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
                .background(BriefingReceiptTheme.paper)
                .clipShape(ReceiptPaperShape())
                .overlay {
                    ReceiptPaperShape()
                        .stroke(BriefingReceiptTheme.ink.opacity(0.14), lineWidth: 1)
                }
                .foregroundStyle(BriefingReceiptTheme.ink)
                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
            .background(Color.white.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(BriefingReceiptTheme.gold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .presentationBackground(Color.white)
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

struct ExecutiveSummaryCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let snapshot: ExecutiveBriefingSnapshot
    let metrics: ExecutiveCardMetrics
    let snapshotDate: Date
    let urgentNotices: [ExecutiveUrgentNotice]
    let onOpenUrgent: (ExecutiveUrgentNotice) -> Void
    var onBreakdown: (ExecutiveBriefingSection?) -> Void

    init(snapshot: ExecutiveBriefingSnapshot, now: Date, urgentNotices: [ExecutiveUrgentNotice],
        onOpenUrgent: @escaping (ExecutiveUrgentNotice) -> Void,
        onBreakdown: @escaping (ExecutiveBriefingSection?) -> Void) {
        self.snapshot = snapshot
        self.snapshotDate = now
        self.metrics = ExecutiveCardMetrics(snapshot: snapshot, now: now)
        self.urgentNotices = urgentNotices
        self.onOpenUrgent = onOpenUrgent
        self.onBreakdown = onBreakdown
    }
    private var cashFlow: [String: Double] {
        Dictionary(uniqueKeysWithValues: snapshot.financials.map { ($0.currency, $0.insight.current.net) })
    }
    private var hasServices: Bool { snapshot.activeSubscriptionCount + snapshot.activeBillCount > 0 }

    private var headerDetail: String {
        let entities = BriefingFormat.count(snapshot.companies.count, "entity", plural: "entities")
        guard snapshot.isLoaded else { return "\(entities) · Loading" }
        let partial = snapshot.loadIssue || snapshot.connectionIssueCount > 0 || metrics.hasStaleBankData
            || snapshot.unknownBillingCount > 0 || metrics.scheduleIncompleteCount > 0
        return "\(entities) · \(partial ? "Partial data · " : "")View breakdown"
    }

    private func amount(_ values: [String: Double], empty: String = "—", signed: Bool = false) -> String {
        guard snapshot.isLoaded else { return "—" }
        return BriefingFormat.cardAmounts(values, empty: empty, signed: signed)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button { onBreakdown(nil) } label: {
                HStack(spacing: 10) {
                    Image(systemName: snapshot.scope == .business ? "building.2" : "person.crop.circle")
                        .font(.title3).foregroundStyle(Color.miloomGold)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(snapshot.scope.rawValue) Summary")
                            .font(.headline).foregroundStyle(.white)
                        Text(headerDetail)
                            .font(.caption2).foregroundStyle(Color.miloomGold)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").font(.caption.weight(.semibold))
                        .foregroundStyle(Color.miloomGold)
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color.black)
            .accessibilityLabel("View \(snapshot.scope.rawValue.lowercased()) breakdown")
            .accessibilityHint("Shows financial, services, and vault details")

            VStack(spacing: 0) {
                summaryRow(.financial,
                    primary: amount(metrics.bankCash), primaryLabel: "Bank cash",
                    primaryDetail: BriefingFormat.amounts(metrics.bankCash, empty: "No checking or savings balances recorded"),
                    secondary: amount(cashFlow, signed: true), secondaryLabel: "Cash flow · MTD",
                    secondaryDetail: BriefingFormat.amounts(cashFlow, empty: "No transaction history available"))
                rowDivider
                summaryRow(.services,
                    primary: amount(snapshot.recurringCosts, empty: hasServices ? "Unknown" : "—"),
                    primaryLabel: snapshot.unknownBillingCount > 0 ? "Monthly · partial" : "Recurring / mo",
                    primaryDetail: BriefingFormat.amounts(snapshot.recurringCosts, empty: "No recurring costs available"),
                    secondary: amount(metrics.scheduledCosts, empty: metrics.scheduleIncompleteCount > 0 ? "Unknown" : (hasServices ? "None due" : "—")),
                    secondaryLabel: metrics.scheduleIncompleteCount > 0 ? "7 days · partial" : "Scheduled · 7d",
                    secondaryDetail: BriefingFormat.amounts(metrics.scheduledCosts, empty: "No known scheduled charges") + "; \(metrics.scheduleIncompleteCount) schedules unavailable")
                rowDivider
                summaryRow(.vault,
                    primary: documentValue(metrics.expiredDocuments.count), primaryLabel: "Expired",
                    primaryDetail: "\(metrics.expiredDocuments.count) tracked documents expired",
                    secondary: documentValue(metrics.expiringDocuments.count), secondaryLabel: "Expiring · 60d",
                    secondaryDetail: "\(metrics.expiringDocuments.count) tracked documents expire within 60 days")
                rowDivider
                attentionStrip
                Button { onBreakdown(nil) } label: {
                    Text("Breakdown")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
                }
                .buttonStyle(MiloomSecondaryButtonStyle())
                .accessibilityLabel("\(snapshot.scope.rawValue) breakdown")
                .accessibilityHint("Shows financial, services, and vault details")
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 16).padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(
            LinearGradient(colors: [Color(hex: "#918457"), Color(hex: "#918457").opacity(0.3)],
                startPoint: .top, endPoint: .bottom), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 4)
    }

    private var rowDivider: some View { Divider().overlay(Color.white.opacity(0.06)) }

    private func documentValue(_ count: Int) -> String {
        guard snapshot.isLoaded, metrics.datedDocumentCount > 0 else { return "—" }
        return String(count)
    }

    private func summaryRow(_ section: ExecutiveBriefingSection,
        primary: String, primaryLabel: String, primaryDetail: String,
        secondary: String, secondaryLabel: String, secondaryDetail: String) -> some View {
        Button { onBreakdown(section) } label: {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.rawValue).font(.caption.weight(.semibold)).foregroundStyle(Color.miloomGold)
                        metric(primary, label: primaryLabel)
                        metric(secondary, label: secondaryLabel)
                    }.padding(.vertical, 8)
                } else {
                    HStack(spacing: 8) {
                        Text(section.rawValue).font(.caption.weight(.semibold))
                            .foregroundStyle(Color.miloomGold).frame(width: 58, alignment: .leading)
                        metric(primary, label: primaryLabel)
                        metric(secondary, label: secondaryLabel)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(section.rawValue)
        .accessibilityValue(accessibilitySummary(section, primaryLabel: primaryLabel, primaryDetail: primaryDetail,
            secondaryLabel: secondaryLabel, secondaryDetail: secondaryDetail))
        .accessibilityHint("Opens the \(section.rawValue.lowercased()) breakdown")
    }

    private func accessibilitySummary(_ section: ExecutiveBriefingSection, primaryLabel: String,
        primaryDetail: String, secondaryLabel: String, secondaryDetail: String) -> String {
        if !snapshot.isLoaded { return "Loading" }
        if section == .vault && metrics.datedDocumentCount == 0 {
            return snapshot.documents.isEmpty ? "No documents added" : "No expiration dates recorded"
        }
        return "\(primaryLabel): \(primaryDetail). \(secondaryLabel): \(secondaryDetail)"
    }

    private func metric(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(.white)
            Text(label).font(.caption2).foregroundStyle(Color.white.opacity(0.66))
        }
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
        .minimumScaleFactor(0.85)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quietStatus: String {
        if let note = metrics.coverageNote(for: snapshot) { return note }
        if metrics.datedDocumentCount == 0 {
            return snapshot.documents.isEmpty ? "Vault · No documents added" : "Vault · No expiration dates tracked"
        }
        return "No flagged issues in tracked records"
    }

    @ViewBuilder private var attentionStrip: some View {
        if let notice = urgentNotices.first, snapshot.isLoaded {
            let overdue = notice.dueAt.map { Calendar.current.startOfDay(for: $0) < Calendar.current.startOfDay(for: snapshotDate) } ?? false
            let heading = notice.sourceType == .document && notice.dueAt != nil ? (overdue ? "Expired document" : "Document expiring") : (overdue ? "Overdue" : "Needs attention")
            let tint = overdue ? Color.red.opacity(0.9) : Color.miloomGold
            Button { onOpenUrgent(notice) } label: {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(tint)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(heading + (urgentNotices.count > 1 ? " · +\(urgentNotices.count - 1) more" : ""))
                            .font(.caption2.weight(.semibold)).foregroundStyle(tint)
                        Text(notice.entityName + " · " + notice.title)
                            .font(.caption2).foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Color.miloomGold)
                }
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Needs attention: \(notice.entityName), \(notice.title)")
            .accessibilityValue("\(urgentNotices.count) flagged items. " + (metrics.coverageNote(for: snapshot) ?? ""))
            .accessibilityHint("Opens this item")
        } else {
            Button { onBreakdown(nil) } label: {
                Label(quietStatus, systemImage: metrics.coverageNote(for: snapshot) == nil ? "info.circle" : "exclamationmark.circle")
                    .font(.caption2).foregroundStyle(Color.white.opacity(0.66))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }.buttonStyle(.plain)
        }
    }
}


private struct ExecutiveBreakdownView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let scope: OwnerBriefingScope
    @Bindable var vm: AppViewModel
    var initialSection: ExecutiveBriefingSection? = nil
    let onOpenResource: (PortfolioObligation) -> Void
    let onOpenHealthResource: (ResourceKind, UUID) -> Void
    @State private var companyID: UUID?
    @State private var showingReminders = false
    @State private var selectedDataSummary: OwnerHealthCategorySummary?
    @State private var selectedRecurringReview: RecurringSuggestionReview?
    @State private var ignoredDataIssueIDs = OwnerHealthDataIssueStore.load()
    @State private var nestedNavigation: (() -> Void)?
    @State private var isFinancialExpanded = false
    @State private var isServicesExpanded = false
    @State private var isVaultExpanded = false
    @State private var financialMonth: CashFlowMonth = .current

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#1C1C1E").ignoresSafeArea()

                TimelineView(.periodic(from: .now, by: 60)) { context in
                    let snapshot = ExecutiveBriefingSnapshot(appState: appState, scope: scope, companyID: companyID, now: context.date)
                    let health = OwnerHealthEngine.snapshot(appState: appState, scope: scope, now: context.date,
                        ignoredDataIssueIDs: ignoredDataIssueIDs, companyID: companyID)
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                breakdownHeader(snapshot, health: health)
                                financialCard(snapshot, now: context.date).id(ExecutiveBriefingSection.financial)
                                servicesCard(snapshot, health: health).id(ExecutiveBriefingSection.services)
                                vaultCard(snapshot, health: health).id(ExecutiveBriefingSection.vault)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .padding(.bottom, 36)
                        }
                        .scrollIndicators(.hidden)
                        .task {
                            guard let initialSection else { return }
                            isFinancialExpanded = initialSection == .financial
                            isServicesExpanded = initialSection == .services
                            isVaultExpanded = initialSection == .vault
                            await Task.yield()
                            proxy.scrollTo(initialSection, anchor: .top)
                        }
                    }
                }
            }
            .navigationTitle("\(scope.rawValue) breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#1C1C1E"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("\(scope.rawValue) breakdown")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.miloomGold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
            .sheet(isPresented: $showingReminders, onDismiss: finishNestedNavigation) {
                OwnerBriefingView(scope: scope, companyID: companyID) { obligation in
                    nestedNavigation = { onOpenResource(obligation) }
                    showingReminders = false
                }
            }
            .sheet(item: $selectedDataSummary, onDismiss: finishNestedNavigation) { summary in
                MissingDataDetailSheet(summary: summary, onOpen: { issue in
                    nestedNavigation = { onOpenHealthResource(issue.resourceType, issue.resourceID) }
                    selectedDataSummary = nil
                }, onIgnore: { issue in
                    ignoredDataIssueIDs.insert(issue.id)
                    OwnerHealthDataIssueStore.save(ignoredDataIssueIDs)
                }, onRestore: { issue in
                    ignoredDataIssueIDs.remove(issue.id)
                    OwnerHealthDataIssueStore.save(ignoredDataIssueIDs)
                })
            }
            .sheet(item: $selectedRecurringReview) { review in
                DetectedSubscriptionsSheet(detected: review.suggestions, cardId: nil,
                    cardName: "\(scope.rawValue.lowercased()) accounts", companyId: companyID, vm: vm,
                    onDismissAll: { selectedRecurringReview = nil }).environment(appState)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .presentationBackground(Color(hex: "#1C1C1E"))
        .preferredColorScheme(.dark)
    }

    private func finishNestedNavigation() {
        let action = nestedNavigation
        nestedNavigation = nil
        action?()
    }

    private func breakdownHeader(_ snapshot: ExecutiveBriefingSnapshot, health: OwnerHealthSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(scope == .business ? "Company" : "Profile", selection: $companyID) {
                Text(scope == .business ? "All businesses" : "All personal profiles").tag(nil as UUID?)
                ForEach(appState.companies.filter(scope.includes)) { company in
                    Text(company.name).tag(Optional(company.id))
                }
            }
            .tint(Color.zifrGold)
            Text(snapshot.coverage).briefingSecondary()
            if snapshot.unassignedTransactionCount > 0 {
                Text("\(snapshot.unassignedTransactionCount) unassigned transactions are excluded from these totals. Review their account assignments in Financial.")
                    .briefingSecondary()
            }
            DisclosureGroup("Entities & profile information") {
                ForEach(snapshot.companies) { company in
                    resourceRow(company.name, detail: company.structure, kind: .company, id: company.id)
                }
                dataReview(health, categories: [.company, .collaborator, .other])
            }
            .font(.system(size: 13, weight: .medium)).tint(Color.zifrGold)
            Button { showingReminders = true } label: {
                Label("Reminders & Complete Later", systemImage: "checklist")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity).padding(12)
            }
            .buttonStyle(MiloomSecondaryButtonStyle())
        }
    }

    private func financialCard(_ snapshot: ExecutiveBriefingSnapshot, now: Date) -> some View {
        let financials = ExecutiveBriefingSnapshot.financials(
            records: snapshot.records,
            now: now,
            month: financialMonth
        )
        return BreakdownSectionCard(
            title: "Financial",
            subtitle: "\(financialMonth.title()) · posted only",
            icon: "chart.bar.xaxis",
            isExpanded: $isFinancialExpanded
        ) {
            MiloomMonthPicker(selection: $financialMonth, anchorDate: now)
            if financials.isEmpty {
                Text("No transaction history available.").briefingSecondary()
            } else {
                ForEach(financials) { summary in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(summary.currency)
                            .font(.caption2.bold())
                            .tracking(0.8)
                            .foregroundStyle(Color.miloomGold)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), alignment: .leading)], spacing: 14) {
                            BriefingMetric(label: "Income", value: BriefingFormat.money(summary.income, summary.currency))
                            BriefingMetric(label: "Outflow", value: BriefingFormat.money(summary.insight.current.moneyOut, summary.currency))
                            BriefingMetric(
                                label: "Net cash flow",
                                value: BriefingFormat.money(summary.insight.current.net, summary.currency),
                                emphasized: true
                            )
                        }
                    }
                }
            }
        } details: {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(financials) { summary in
                    VStack(alignment: .leading, spacing: 12) {
                        BriefingMetric(label: "Refunds", value: BriefingFormat.money(summary.refunds, summary.currency))
                        if summary.insight.previous.transactionCount > 0 {
                            Text("Cash-flow change: \(BriefingFormat.money(summary.insight.netChange, summary.currency)) vs. \(financialMonth.previous(in: .current).title())")
                                .briefingSecondary()
                        } else {
                            Text("No previous-period activity available for comparison.").briefingSecondary()
                        }
                        ForEach(summary.insight.expenseCategories.prefix(3), id: \.key) { category in
                            detailLine(category.label, BriefingFormat.money(category.amount, summary.currency))
                        }
                        if let largest = summary.insight.largestExpense {
                            Text("Largest expense: \(TransactionIntelligence.displayName(for: largest)) · \(BriefingFormat.money(abs(largest.transaction.amount ?? 0), summary.currency))")
                                .briefingSecondary()
                        }
                        selectedMonthTransactions(summary)
                    }
                }
                Text("Net cash flow includes refunds. Transfers, ignored items, and pending transactions are excluded.")
                    .briefingSecondary()

                Divider().overlay(Color.white.opacity(0.08))

                BriefingMetric(label: "Recorded account balances", value: BriefingFormat.amounts(snapshot.balances, empty: "No account balances"))
                Text("Balances reflect saved account updates and may include investment accounts.").briefingSecondary()
                DisclosureGroup("Accounts, cards & loans (\(snapshot.institutions.count + snapshot.cards.count + snapshot.loans.count))") {
                    ForEach(snapshot.institutions) { bank in
                        resourceRow(bank.name, detail: "\(BriefingFormat.count(bank.accounts.count, "account"))\(bank.isDisconnected || appState.plaidItems.contains { $0.institutionId == bank.id && $0.requiresReconnect } ? " · Reconnect required" : "")", kind: .institution, id: bank.id)
                    }
                    ForEach(snapshot.cards) { card in
                        resourceRow(card.name, detail: "\(card.type) · \(card.status) · Balance \(card.balance.formatted())", kind: .card, id: card.id)
                    }
                    ForEach(snapshot.loans) { loan in
                        resourceRow(loan.name, detail: "\(loan.role) · Balance \(loan.remainingBalance.formatted())\(loan.nextPaymentAt.map { " · Due " + $0.formatted(date: .abbreviated, time: .omitted) } ?? "")", kind: .loan, id: loan.id)
                    }
                    if !snapshot.cards.isEmpty || !snapshot.loans.isEmpty {
                        Text("Card and loan records do not specify currency; their balances are shown individually.").briefingSecondary()
                    }
                }
                .font(.subheadline.weight(.medium))
                .tint(Color.miloomGold)
                dataReview(OwnerHealthEngine.snapshot(appState: appState, scope: scope, ignoredDataIssueIDs: ignoredDataIssueIDs, companyID: companyID), categories: [.institution, .card, .loan])
            }
        }
    }

    @ViewBuilder
    private func selectedMonthTransactions(_ summary: ExecutiveCurrencySummary) -> some View {
        if !summary.insight.records.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Transactions in \(financialMonth.title())")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                ForEach(groupedMonthRecords(summary.insight.records), id: \.date) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(formattedTransactionDate(group.date))
                            .font(.caption2.weight(.bold))
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .foregroundStyle(Color.white.opacity(0.52))
                        ForEach(group.records) { record in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(TransactionIntelligence.displayName(for: record))
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.white)
                                    Text(monthTransactionKind(record)).briefingSecondary()
                                }
                                Spacer(minLength: 8)
                                Text(monthTransactionAmount(record, currency: summary.currency))
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(monthTransactionColor(record))
                            }
                            .frame(minHeight: 44)
                        }
                    }
                }
            }
        } else {
            Text("No posted transactions in \(financialMonth.title()).")
                .briefingSecondary()
        }
    }

    private func groupedMonthRecords(_ records: [ResolvedTransaction]) -> [(date: String, records: [ResolvedTransaction])] {
        Dictionary(grouping: records, by: { $0.transaction.date })
            .map { (date: $0.key, records: $0.value) }
            .sorted { $0.date > $1.date }
    }

    private func monthTransactionKind(_ record: ResolvedTransaction) -> String {
        switch TransactionIntelligence.effectiveFlow(for: record) {
        case .income: return "Income"
        case .refund: return "Refund"
        case .expense: return "Expense"
        case .transfer: return "Transfer"
        case .ignored: return "Ignored"
        }
    }

    private func monthTransactionAmount(_ record: ResolvedTransaction, currency: String) -> String {
        let amount = BriefingFormat.money(abs(record.transaction.amount ?? 0), currency)
        switch TransactionIntelligence.effectiveFlow(for: record) {
        case .income, .refund: return "+\(amount)"
        case .expense: return "−\(amount)"
        case .transfer, .ignored: return amount
        }
    }

    private func monthTransactionColor(_ record: ResolvedTransaction) -> Color {
        switch TransactionIntelligence.effectiveFlow(for: record) {
        case .income, .refund: return Color.zifrGreen
        case .transfer: return Color.miloomGold
        case .expense, .ignored: return .white
        }
    }

    private func formattedTransactionDate(_ value: String) -> String {
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: value) else { return value }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private func servicesCard(_ snapshot: ExecutiveBriefingSnapshot, health: OwnerHealthSnapshot) -> some View {
        BreakdownSectionCard(
            title: "Services",
            subtitle: "Bills, subscriptions & add-ons",
            icon: "square.stack.3d.up",
            isExpanded: $isServicesExpanded
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), alignment: .leading)], spacing: 14) {
                BriefingMetric(label: "Active bills", value: "\(snapshot.activeBillCount)")
                BriefingMetric(label: "Subscriptions", value: "\(snapshot.activeSubscriptionCount)")
                BriefingMetric(label: "Add-ons", value: "\(snapshot.supplementalCount)")
                BriefingMetric(
                    label: "Monthly commitment",
                    value: BriefingFormat.amounts(snapshot.recurringCosts, empty: snapshot.activeSubscriptionCount + snapshot.activeBillCount > 0 ? "Unavailable" : "No active services"),
                    emphasized: true
                )
            }
        } details: {
            VStack(alignment: .leading, spacing: 16) {
                if snapshot.unknownBillingCount > 0 {
                    Text("\(snapshot.unknownBillingCount) unsupported billing periods excluded.").briefingSecondary()
                }
                Text("Active services only. Annual costs are spread over 12 months and are separate from actual spending.")
                    .briefingSecondary()
                Divider().overlay(Color.white.opacity(0.08))
                upcomingCoverage(snapshot.upcomingCoverage)
                if snapshot.subscriptions.isEmpty {
                    Text("Services you add will appear here.").briefingSecondary()
                }
                ForEach([RecurringServiceType.bill, .subscription]) { type in
                    let services = snapshot.subscriptions.filter { $0.resolvedServiceType == type }
                    if !services.isEmpty {
                        DisclosureGroup("\(type == .bill ? "Bills" : "Subscriptions") (\(services.count))") {
                            ForEach(services) { service in
                                VStack(alignment: .leading, spacing: 5) {
                                    resourceRow(service.name, detail: "\(service.status) · \(BriefingFormat.money(service.cost, service.currency)) / \(service.billingCycle.lowercased())", kind: .subscription, id: service.id)
                                    if let date = service.nextRenewalAt {
                                        Text("Renews \(date.formatted(date: .abbreviated, time: .omitted))").briefingSecondary()
                                    } else if let renewal = service.nextRenewal, !renewal.isEmpty {
                                        Text("Renews \(renewal)").briefingSecondary()
                                    }
                                    if let source = service.paymentMethod, !source.isEmpty {
                                        Text("Payment source: \(source)").briefingSecondary()
                                    }
                                    ForEach(service.subServices) { addon in
                                        Text("↳ \(addon.name) · \(addon.status.rawValue) · \(BriefingFormat.money(addon.cost, service.currency)) / \(addon.billingCycle.rawValue.lowercased())")
                                            .briefingSecondary()
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .font(.subheadline.weight(.medium))
                        .tint(Color.miloomGold)
                    }
                }
                if let summary = health.categories.first(where: { $0.category == .subscription }), !summary.recurringSuggestions.isEmpty {
                    Button { selectedRecurringReview = RecurringSuggestionReview(suggestions: summary.recurringSuggestions) } label: {
                        Label("Review \(summary.recurringSuggestions.count) detected recurring charges", systemImage: "sparkle.magnifyingglass")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(MiloomSecondaryButtonStyle())
                }
                dataReview(health, categories: [.subscription])
            }
        }
    }

    @ViewBuilder
    private func upcomingCoverage(_ projection: UpcomingCoverageProjection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Upcoming payments", systemImage: "checkmark.shield")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Text("\(projection.days) DAYS")
                    .font(.caption2.bold()).tracking(0.8)
                    .foregroundStyle(Color.white.opacity(0.62))
            }

            Text("Will your payment accounts have enough money for bills, subscriptions, and add-ons due in the next \(projection.days) days?")
                .briefingSecondary()

            if projection.groups.isEmpty {
                Text(projection.unscheduledCount > 0
                    ? "No dated charges fall in this window. Add renewal dates to check \(BriefingFormat.count(projection.unscheduledCount, "service or add-on"))."
                    : "No scheduled bills, subscriptions, or add-ons fall in the next \(projection.days) days.")
                    .briefingSecondary()
            } else {
                HStack(spacing: 10) {
                    coverageCount(projection.chargeCount, label: "Payments due", status: nil)
                    coverageCount(projection.atRiskCount, label: "May fall short", status: .atRisk)
                    coverageCount(projection.unknownCount, label: "Can't verify", status: .unknown)
                }

                ForEach(projection.groups) { group in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(group.charges) { charge in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(charge.name).font(.subheadline.weight(.medium))
                                        Text((charge.isSupplemental ? "Add-on · " : "") + charge.dueAt.formatted(date: .abbreviated, time: .omitted))
                                            .briefingSecondary()
                                    }
                                    Spacer(minLength: 8)
                                    Text(BriefingFormat.money(charge.amount, charge.currency))
                                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                                }
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(spacing: 8) {
                                Image(systemName: coverageIcon(group.status))
                                    .foregroundStyle(coverageColor(group.status))
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(group.sourceName).font(.subheadline.weight(.semibold))
                                    Text(group.sourceDetail).briefingSecondary()
                                    if !group.paymentRoutes.isEmpty {
                                        Text("Pays through \(group.paymentRoutes.joined(separator: ", "))")
                                            .briefingSecondary()
                                    }
                                }
                                Spacer(minLength: 8)
                                Text(coverageTitle(group.status))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(coverageColor(group.status))
                            }
                            Text(coverageDetail(group))
                                .font(.caption).foregroundStyle(Color.white.opacity(0.76))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 6)
                    }
                    .tint(Color.zifrGold)
                    .accessibilityLabel("\(group.sourceName), \(coverageTitle(group.status))")
                    .accessibilityValue(coverageDetail(group))
                }
                if projection.unscheduledCount > 0 {
                    Text("\(BriefingFormat.count(projection.unscheduledCount, "active service or add-on")) cannot be checked because a renewal date is missing.")
                        .briefingSecondary()
                }
            }

            Text("Estimate based on saved due dates and the latest available balances. Other spending and pending transactions can change the result.")
                .briefingSecondary()
        }
    }

    private func coverageCount(_ value: Int, label: String, status: UpcomingCoverageStatus?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)").font(.headline).monospacedDigit()
                .foregroundStyle(status.map(coverageColor) ?? Color.white)
            Text(label).font(.caption2).foregroundStyle(Color.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func coverageDetail(_ group: UpcomingCoverageGroup) -> String {
        let scheduled = BriefingFormat.money(group.totalDue, group.currency)
        if let reason = group.reason { return "\(scheduled) scheduled · \(reason)" }
        guard let available = group.availableAmount, let difference = group.difference else {
            return "\(scheduled) scheduled · Available funds unavailable"
        }
        let funds = BriefingFormat.money(available, group.currency)
        if difference >= 0 {
            return "\(scheduled) scheduled · \(group.availableLabel) \(funds) · \(BriefingFormat.money(difference, group.currency)) left after payments"
        }
        return "\(scheduled) scheduled · \(group.availableLabel) \(funds) · \(BriefingFormat.money(abs(difference), group.currency)) short"
    }

    private func coverageTitle(_ status: UpcomingCoverageStatus) -> String {
        switch status {
        case .covered: return "Enough funds"
        case .atRisk: return "May fall short"
        case .unknown: return "Can't verify"
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
        case .covered: return Color.green
        case .atRisk: return Color.red
        case .unknown: return Color.orange
        }
    }

    private func vaultCard(_ snapshot: ExecutiveBriefingSnapshot, health: OwnerHealthSnapshot) -> some View {
        BreakdownSectionCard(
            title: "Vault",
            subtitle: "Documents & expiration dates",
            icon: "lock.doc",
            isExpanded: $isVaultExpanded
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), alignment: .leading)], spacing: 14) {
                BriefingMetric(label: "Documents", value: "\(snapshot.documents.count)")
                BriefingMetric(label: "With expiration dates", value: "\(snapshot.documents.filter { $0.expiresAt != nil }.count)")
            }
        } details: {
            VStack(alignment: .leading, spacing: 14) {
                if snapshot.documents.isEmpty {
                    Text("Documents you add will appear here.").briefingSecondary()
                }
                ForEach(Array(Set(snapshot.documents.map { CompanyDocument.normalizeType($0.type) })).sorted(), id: \.self) { category in
                    let documents = snapshot.documents.filter { CompanyDocument.normalizeType($0.type) == category }
                    DisclosureGroup("\(category) (\(documents.count))") {
                        ForEach(documents.sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }) { document in
                            resourceRow(document.name, detail: document.expiresAt.map { "Expires " + $0.formatted(date: .abbreviated, time: .omitted) } ?? "No expiration date recorded", kind: .document, id: document.id)
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .tint(Color.miloomGold)
                }
                dataReview(health, categories: [.document])
            }
        }
    }

    private func dataReview(_ health: OwnerHealthSnapshot, categories: [BriefingResourceCategory]) -> some View {
        ForEach(health.categories.filter { categories.contains($0.category) && ($0.requiresAttention || !$0.dataIssues.isEmpty) }) { summary in
            if summary.requiresAttention {
                Label(summary.summary, systemImage: "exclamationmark.circle")
                    .font(.caption).foregroundStyle(summary.status == .critical ? Color.red : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
                if !summary.affectedEntityNames.isEmpty {
                    Text(summary.affectedEntityNames.joined(separator: " · ")).briefingSecondary()
                }
            }
            if !summary.dataIssues.isEmpty {
                Button { selectedDataSummary = summary } label: {
                    Label("\(summary.category.title): review data suggestions (\(summary.dataIssues.count))", systemImage: "info.circle")
                        .font(.caption.weight(.medium)).padding(.vertical, 8)
                }.tint(Color.zifrGold)
            }
        }
    }

    private func resourceRow(_ title: String, detail: String, kind: ResourceKind, id: UUID) -> some View {
        Button { onOpenHealthResource(kind, id) } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    Text(detail).briefingSecondary()
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.zifrGold)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func detailLine(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title).foregroundStyle(Color.white.opacity(0.65))
            Spacer()
            Text(value).monospacedDigit()
        }.font(.system(size: 12))
    }
}

private struct BreakdownSectionCard<Summary: View, Details: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    let subtitle: String
    let icon: String
    @Binding var isExpanded: Bool
    let summary: Summary
    let details: Details

    init(
        title: String,
        subtitle: String,
        icon: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder summary: () -> Summary,
        @ViewBuilder details: () -> Details
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        _isExpanded = isExpanded
        self.summary = summary()
        self.details = details()
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: toggleExpanded) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        Image(systemName: icon)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.86))
                    }
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.58))
                            .lineLimit(2)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.miloomGold)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                }
                .padding(.leading, 18)
                .padding(.trailing, 8)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint(isExpanded ? "Collapses details" : "Shows details")

            Divider().overlay(Color.white.opacity(0.08))

            VStack(alignment: .leading, spacing: 16) {
                summary

                if isExpanded {
                    Divider().overlay(Color.white.opacity(0.08))
                    details
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.70))
        )
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "#918457"), Color(hex: "#918457").opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 10, y: 4)
        .foregroundStyle(.white)
    }

    private func toggleExpanded() {
        if reduceMotion {
            isExpanded.toggle()
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                isExpanded.toggle()
            }
        }
    }
}

private struct BriefingMetric: View {
    let label: String
    let value: String
    let accessibilityValue: String
    let emphasized: Bool

    init(label: String, value: String, accessibilityValue: String? = nil, emphasized: Bool = false) {
        self.label = label
        self.value = value
        self.accessibilityValue = accessibilityValue ?? value
        self.emphasized = emphasized
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(emphasized ? .headline : .subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(2)
                .foregroundStyle(emphasized ? Color.zifrGold : Color.white)
            Text(label).font(.caption2).foregroundStyle(Color.white.opacity(0.66))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(accessibilityValue)
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

private extension View {
    func briefingSecondary() -> some View {
        font(.caption)
            .foregroundStyle(Color.white.opacity(0.58))
            .fixedSize(horizontal: false, vertical: true)
    }
}
