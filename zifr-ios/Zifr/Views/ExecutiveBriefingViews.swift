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
    case accounts
    case review

    var id: String { rawValue }
}

private enum BriefingReceiptTheme {
    static let paper = Color(hex: "#F8F9FA")
    static let ink = Color(hex: "#1A1A1A")
    static let fadedInk = Color(hex: "#1A1A1A").opacity(0.64)
    static let gold = Color(hex: "#918457")
    static let backdrop = Color(hex: "#121212")
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
    let onShowAccounts: () -> Void
    let onShowReview: () -> Void
    let onShowReminders: () -> Void
    let onExploreConnections: () -> Void
    let onOpenResource: (ResourceKind, UUID) -> Void
    let onOpenUrgent: (ExecutiveUrgentNotice) -> Void

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

            receiptSection("01", title: "FINANCIAL", icon: "chart.bar.xaxis") {
                financialContent
            }
            receiptSection("02", title: "SERVICES", icon: "square.stack.3d.up") {
                servicesContent
            }
            receiptSection("03", title: "VAULT", icon: "lock.doc") {
                vaultContent
            }
            receiptSection("04", title: "ATTENTION", icon: "exclamationmark.circle") {
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
        .foregroundStyle(BriefingReceiptTheme.ink)
        .shadow(color: .black.opacity(0.38), radius: 18, y: 10)
    }

    private var receiptHeader: some View {
        VStack(spacing: 5) {
            Image(systemName: "receipt")
                .font(.title3.weight(.semibold))
            Text("MILOOM COMMAND CENTER")
                .font(.system(.headline, design: .monospaced).weight(.bold))
            Text("EXECUTIVE BRIEFING")
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
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
        if financials.isEmpty {
            receiptNote("No posted transactions in \(financialMonth.title()).")
        } else {
            ForEach(financials) { summary in
                receiptSubheading(summary.currency)
                receiptRow("Income", BriefingFormat.money(summary.income, summary.currency))
                receiptRow("Outflow", BriefingFormat.money(summary.insight.current.moneyOut, summary.currency))
                receiptRow("Refunds", BriefingFormat.money(summary.refunds, summary.currency))
                receiptTotal("NET CASH FLOW", BriefingFormat.money(summary.insight.current.net, summary.currency))
                if !summary.insight.expenseCategories.isEmpty {
                    receiptSubheading("TOP SPENDING CATEGORIES")
                    ForEach(summary.insight.expenseCategories.prefix(3), id: \.key) { category in
                        receiptRow(category.label, BriefingFormat.money(category.amount, summary.currency))
                    }
                }
            }
        }
        ReceiptActionButton(
            title: "VIEW TRANSACTIONS",
            detail: "\(transactionCount) in \(financialMonth.title())",
            icon: "list.bullet.rectangle",
            action: onShowTransactions
        )
        receiptRow("Recorded balances", BriefingFormat.amounts(snapshot.balances, empty: "—"))
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

    @ViewBuilder
    private var servicesContent: some View {
        receiptRow("Active bills", "\(snapshot.activeBillCount)")
        receiptRow("Subscriptions", "\(snapshot.activeSubscriptionCount)")
        receiptRow("Add-ons", "\(snapshot.supplementalCount)")
        receiptTotal("EST. MONTHLY COMMITMENT", BriefingFormat.amounts(snapshot.recurringCosts, empty: "—"))

        let projection = snapshot.upcomingCoverage
        receiptSubheading("PAYMENT FUNDING · NEXT \(projection.days) DAYS")
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

        ForEach([RecurringServiceType.bill, .subscription]) { type in
            let services = snapshot.subscriptions.filter {
                $0.resolvedServiceType == type && ExecutiveBriefingSnapshot.isActive($0.status)
            }
            if !services.isEmpty {
                receiptSubheading(type == .bill ? "BILLS" : "SUBSCRIPTIONS")
                ForEach(services) { service in
                    receiptResourceRow(
                        service.name,
                        BriefingFormat.money(service.cost, service.currency),
                        detail: service.nextRenewalAt.map { "Due \($0.formatted(date: .abbreviated, time: .omitted))" }
                            ?? service.nextRenewal.map { "Due \($0)" }
                            ?? service.billingCycle,
                        kind: .subscription,
                        id: service.id
                    )
                }
            }
        }
        if snapshot.unknownBillingCount > 0 {
            receiptNote("\(snapshot.unknownBillingCount) billing cycles could not be included in the monthly estimate.")
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
        case .unknown: return Color.orange
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
        _ number: String,
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            dashedDivider
            HStack(spacing: 8) {
                Text(number)
                    .foregroundStyle(BriefingReceiptTheme.gold)
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(.subheadline, design: .monospaced).weight(.bold))
            .accessibilityAddTraits(.isHeader)
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
        .background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                        .foregroundStyle(BriefingReceiptTheme.fadedInk)
                }
                Spacer(minLength: 6)
                if enabled {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(BriefingReceiptTheme.gold)
                }
            }
            .foregroundStyle(BriefingReceiptTheme.ink)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(BriefingReceiptTheme.ink.opacity(0.16), lineWidth: 1)
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
                        Image(systemName: "receipt")
                            .font(.title3.weight(.semibold))
                        Text("MILOOM")
                            .font(.system(.subheadline, design: .monospaced).weight(.bold))
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
                .foregroundStyle(BriefingReceiptTheme.ink)
                .shadow(color: .black.opacity(0.4), radius: 18, y: 10)
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
            .background(BriefingReceiptTheme.backdrop.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(BriefingReceiptTheme.backdrop, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .presentationBackground(BriefingReceiptTheme.backdrop)
        .preferredColorScheme(.dark)
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
