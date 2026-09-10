import SwiftUI

struct OwnerHealthBriefingDashboard: View {
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
                .accessibilityHint("Opens the existing portfolio connection map")
            }
        }
        .sheet(item: $selectedScope, onDismiss: {
            let action = pendingNavigation
            pendingNavigation = nil
            action?()
        }) { scope in
            ExecutiveBreakdownView(scope: scope, vm: vm, initialSection: selectedSection, onOpenResource: { obligation in
                pendingNavigation = { onOpenResource(obligation) }
                selectedScope = nil
            }, onOpenHealthResource: { kind, id in
                pendingNavigation = { onOpenHealthResource(kind, id) }
                selectedScope = nil
            })
            .dynamicTypeSize(dynamicTypeSize)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private func openUrgent(_ notice: ExecutiveUrgentNotice) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if let obligation = notice.obligation { onOpenResource(obligation) }
        else { onOpenHealthResource(notice.sourceType, notice.sourceID) }
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
        font(.caption).foregroundStyle(Color.white.opacity(0.58))
            .fixedSize(horizontal: false, vertical: true)
    }
}
