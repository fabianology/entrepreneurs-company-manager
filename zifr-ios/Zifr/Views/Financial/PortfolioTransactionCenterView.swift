import SwiftUI

enum TransactionFlowFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case moneyOut = "Money Out"
    case moneyIn = "Money In"

    var id: String { rawValue }
}

enum TransactionPostingFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case posted = "Posted"
    case pending = "Pending"

    var id: String { rawValue }
}

struct ResolvedTransaction: Identifiable, Equatable {
    let transaction: Transaction
    let companyId: UUID?
    let companyName: String
    let accountName: String
    let institutionName: String

    var id: UUID { transaction.id }
    var accountId: String { transaction.accountId }
}

struct TransactionPortfolioSummary: Equatable {
    let moneyOut: Double
    let moneyIn: Double
    let pendingCount: Int
    let financialMovementCount: Int
}

private struct TransactionCenterAnalysis {
    let records: [ResolvedTransaction]
    let detectedSubscriptions: [DetectedSubscription]
    let duplicateAlerts: [DuplicateChargeAlert]
}

struct DuplicateChargeAlert: Identifiable, Equatable {
    let merchantKey: String
    let displayName: String
    let amount: Double
    let currency: String
    let companyId: UUID?
    let records: [ResolvedTransaction]

    var id: String {
        records
            .map { $0.transaction.plaidTransactionId ?? $0.transaction.id.uuidString }
            .sorted()
            .joined(separator: ":")
    }

    var possibleDuplicateAmount: Double {
        amount * Double(max(records.count - 1, 0))
    }
}

enum DuplicateChargeDetector {
    private struct MerchantScope: Hashable {
        let merchantKey: String
        let companyId: UUID?
        let currency: String
    }

    static func detect(
        records: [ResolvedTransaction],
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> [DuplicateChargeAlert] {
        var calendar = calendar
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let eligible = records.filter { record in
            let transaction = record.transaction
            return transaction.pending != true
                && (transaction.amount ?? 0) > 0
                && !TransactionIntelligence.isFinancialMovement(transaction)
                && !SubscriptionDetector.normalize(TransactionIntelligence.displayName(for: transaction)).isEmpty
        }
        let scoped = Dictionary(grouping: eligible) { record in
            MerchantScope(
                merchantKey: SubscriptionDetector.normalize(TransactionIntelligence.displayName(for: record.transaction)),
                companyId: record.companyId,
                currency: record.transaction.currency
            )
        }

        var alerts: [DuplicateChargeAlert] = []
        for (scope, merchantRecords) in scoped {
            let sorted = merchantRecords.sorted { $0.transaction.date < $1.transaction.date }
            var consumed = Set<UUID>()

            for base in sorted where !consumed.contains(base.id) {
                guard let baseDate = parseDate(base.transaction.date, calendar: calendar),
                      let baseAmount = base.transaction.amount else { continue }
                var cluster = [base]

                for candidate in sorted where candidate.id != base.id && !consumed.contains(candidate.id) {
                    guard let candidateDate = parseDate(candidate.transaction.date, calendar: calendar),
                          let candidateAmount = candidate.transaction.amount else { continue }
                    let days = abs(calendar.dateComponents([.day], from: baseDate, to: candidateDate).day ?? 999)
                    guard days <= 3, amountsMatch(baseAmount, candidateAmount) else { continue }
                    let basePlaidId = base.transaction.plaidTransactionId
                    let candidatePlaidId = candidate.transaction.plaidTransactionId
                    guard basePlaidId == nil || candidatePlaidId == nil || basePlaidId != candidatePlaidId else { continue }
                    cluster.append(candidate)
                }

                guard cluster.count >= 2 else { continue }
                cluster.forEach { consumed.insert($0.id) }
                alerts.append(DuplicateChargeAlert(
                    merchantKey: scope.merchantKey,
                    displayName: TransactionIntelligence.displayName(for: cluster.last?.transaction ?? base.transaction),
                    amount: baseAmount,
                    currency: scope.currency,
                    companyId: scope.companyId,
                    records: cluster.sorted { $0.transaction.date > $1.transaction.date }
                ))
            }
        }

        return alerts.sorted {
            if $0.possibleDuplicateAmount == $1.possibleDuplicateAmount {
                return $0.displayName < $1.displayName
            }
            return $0.possibleDuplicateAmount > $1.possibleDuplicateAmount
        }
    }

    private static func amountsMatch(_ lhs: Double, _ rhs: Double) -> Bool {
        let tolerance = max(0.01, max(abs(lhs), abs(rhs)) * 0.005)
        return abs(lhs - rhs) <= tolerance
    }

    private static func parseDate(_ value: String, calendar: Calendar) -> Date? {
        let components = value.split(separator: "-", omittingEmptySubsequences: false)
        guard components.count == 3,
              let year = Int(components[0]),
              let month = Int(components[1]),
              let day = Int(components[2]) else { return nil }
        return calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day
        ))
    }

}

enum DuplicateChargeDismissalStore {
    private static let defaultsKey = "miloom.dismissedDuplicateChargeAlerts.v1"

    static func dismiss(_ alert: DuplicateChargeAlert, defaults: UserDefaults = .standard) {
        var dismissed = Set(defaults.stringArray(forKey: defaultsKey) ?? [])
        dismissed.insert(alert.id)
        defaults.set(Array(dismissed), forKey: defaultsKey)
    }

    static func isDismissed(_ alert: DuplicateChargeAlert, defaults: UserDefaults = .standard) -> Bool {
        Set(defaults.stringArray(forKey: defaultsKey) ?? []).contains(alert.id)
    }

    static func clear(_ alert: DuplicateChargeAlert, defaults: UserDefaults = .standard) {
        var dismissed = Set(defaults.stringArray(forKey: defaultsKey) ?? [])
        dismissed.remove(alert.id)
        defaults.set(Array(dismissed), forKey: defaultsKey)
    }
}

enum TransactionIntelligence {
    static func resolve(
        _ transaction: Transaction,
        companies: [Company],
        institutions: [Institution],
        cards: [FinancialCard]
    ) -> ResolvedTransaction {
        resolveAll(
            [transaction],
            companies: companies,
            institutions: institutions,
            cards: cards
        )[0]
    }

    static func resolveAll(
        _ transactions: [Transaction],
        companies: [Company],
        institutions: [Institution],
        cards: [FinancialCard]
    ) -> [ResolvedTransaction] {
        let companiesById = companies.reduce(into: [UUID: Company]()) { $0[$1.id] = $1 }
        let institutionsById = institutions.reduce(into: [UUID: Institution]()) { $0[$1.id] = $1 }
        var institutionsByAccountId: [String: Institution] = [:]
        var accountsByInstitutionId: [UUID: [String: InstitutionAccount]] = [:]
        for institution in institutions {
            var accountsById: [String: InstitutionAccount] = [:]
            for account in institution.accounts {
                accountsById[account.id] = account
                institutionsByAccountId[account.id] = institution
            }
            accountsByInstitutionId[institution.id] = accountsById
        }

        var cardsByAccountId: [String: FinancialCard] = [:]
        for card in cards {
            cardsByAccountId[card.id.uuidString] = card
            if let plaidAccountId = card.plaidAccountId?.nonEmpty {
                cardsByAccountId[plaidAccountId] = card
            }
        }

        return transactions
            .map { transaction in
                let card = cardsByAccountId[transaction.accountId]
                let institution = transaction.institutionId.flatMap { institutionsById[$0] }
                    ?? institutionsByAccountId[transaction.accountId]
                let account = institution.flatMap {
                    accountsByInstitutionId[$0.id]?[transaction.accountId]
                }
                let resolvedCompanyId = transaction.companyId ?? card?.companyId ?? institution?.companyId
                let companyName = resolvedCompanyId.flatMap { companiesById[$0]?.name } ?? "Unassigned"
                let accountName = account?.name.nonEmpty
                    ?? card?.name.nonEmpty
                    ?? transaction.accountId.suffixLabel
                let institutionName = institution?.name.nonEmpty
                    ?? card?.institutionName?.nonEmpty
                    ?? "Connected account"

                return ResolvedTransaction(
                    transaction: transaction,
                    companyId: resolvedCompanyId,
                    companyName: companyName,
                    accountName: accountName,
                    institutionName: institutionName
                )
            }
            .sorted {
                if $0.transaction.date == $1.transaction.date {
                    return displayName(for: $0.transaction) < displayName(for: $1.transaction)
                }
                return $0.transaction.date > $1.transaction.date
            }
    }

    static func enrichedTransactions(from records: [ResolvedTransaction]) -> [Transaction] {
        records.map { record in
            var transaction = record.transaction
            if transaction.companyId == nil {
                transaction.companyId = record.companyId
            }
            return transaction
        }
    }

    static func displayName(for transaction: Transaction) -> String {
        transaction.merchantName?.nonEmpty
            ?? transaction.name?.nonEmpty
            ?? "Unknown transaction"
    }

    static func isFinancialMovement(_ transaction: Transaction) -> Bool {
        let personalFinance = [
            transaction.personalFinancePrimary,
            transaction.personalFinanceDetailed
        ]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        let legacyCategory = (transaction.category ?? []).joined(separator: " ").lowercased()
        let classification = "\(personalFinance) \(legacyCategory)"
        if ["transfer", "payment", "cash", "deposit", "withdrawal"].contains(where: classification.contains) {
            return true
        }

        let name = displayName(for: transaction).lowercased()
        let patterns = [
            #"\bzelle\b"#,
            #"\batm\b"#,
            #"\bwithdrawal\b"#,
            #"\bpayment to\b"#,
            #"\bautopay\b"#,
            #"\bmonthly payment\b"#,
            #"\b(card|loan) payment\b"#,
            #"\btransfer (to|from)\b"#,
            #"\bmobile check deposit\b"#
        ]
        return patterns.contains { name.range(of: $0, options: .regularExpression) != nil }
    }

    static func summary(for records: [ResolvedTransaction]) -> TransactionPortfolioSummary {
        var moneyOut = 0.0
        var moneyIn = 0.0
        var pendingCount = 0
        var financialMovementCount = 0

        for record in records {
            let transaction = record.transaction
            if transaction.pending == true {
                pendingCount += 1
                continue
            }
            if isFinancialMovement(transaction) {
                financialMovementCount += 1
                continue
            }
            let amount = transaction.amount ?? 0
            if amount >= 0 {
                moneyOut += amount
            } else {
                moneyIn += abs(amount)
            }
        }

        return TransactionPortfolioSummary(
            moneyOut: moneyOut,
            moneyIn: moneyIn,
            pendingCount: pendingCount,
            financialMovementCount: financialMovementCount
        )
    }

    static func matchesSearch(_ record: ResolvedTransaction, query: String) -> Bool {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return true }
        let transaction = record.transaction
        let searchable = [
            displayName(for: transaction),
            transaction.name ?? "",
            record.companyName,
            record.accountName,
            record.institutionName,
            (transaction.category ?? []).joined(separator: " ")
        ].joined(separator: " ").lowercased()
        return searchable.contains(normalizedQuery)
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var suffixLabel: String {
        guard !isEmpty else { return "Unknown account" }
        return "Account •••• \(suffix(4))"
    }
}

struct PortfolioTransactionCenterView: View {
    @Bindable var vm: AppViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var flowFilter: TransactionFlowFilter = .all
    @State private var postingFilter: TransactionPostingFilter = .all
    @State private var selectedCompanyId: UUID?
    @State private var selectedAccountId: String?
    @State private var isSyncing = false
    @State private var syncError: String?
    @State private var showDuplicateReview = false
    @State private var showNeedsReviewOnly = false
    @State private var dismissedDuplicateIds: Set<String> = []
    @State private var assigningTransactionId: UUID?
    @State private var assignmentError: String?
    @State private var allRecords: [ResolvedTransaction] = []
    @State private var detectedSubscriptions: [DetectedSubscription] = []
    @State private var analyzedDuplicateAlerts: [DuplicateChargeAlert] = []
    @State private var isPreparing = true
    @State private var analysisRevision = UUID()

    private var filteredRecords: [ResolvedTransaction] {
        allRecords.filter { record in
            let transaction = record.transaction
            guard TransactionIntelligence.matchesSearch(record, query: searchText) else { return false }
            if showNeedsReviewOnly && record.companyId != nil && !record.accountId.isEmpty { return false }
            if let selectedCompanyId, record.companyId != selectedCompanyId { return false }
            if let selectedAccountId, record.accountId != selectedAccountId { return false }

            switch postingFilter {
            case .all: break
            case .posted where transaction.pending == true: return false
            case .pending where transaction.pending != true: return false
            default: break
            }

            let amount = transaction.amount ?? 0
            switch flowFilter {
            case .all: return true
            case .moneyOut: return amount >= 0
            case .moneyIn: return amount < 0
            }
        }
    }

    private var groupedRecords: [(date: String, records: [ResolvedTransaction])] {
        Dictionary(grouping: filteredRecords, by: { $0.transaction.date })
            .map { (date: $0.key, records: $0.value) }
            .sorted { $0.date > $1.date }
    }

    private var summary: TransactionPortfolioSummary {
        TransactionIntelligence.summary(for: filteredRecords)
    }

    private var duplicateAlerts: [DuplicateChargeAlert] {
        analyzedDuplicateAlerts.filter {
            !dismissedDuplicateIds.contains($0.id) && !DuplicateChargeDismissalStore.isDismissed($0)
        }
    }

    private var duplicateTransactionIds: Set<UUID> {
        Set(duplicateAlerts.flatMap { $0.records.map(\.id) })
    }

    private var needsReviewRecords: [ResolvedTransaction] {
        allRecords.filter { $0.companyId == nil || $0.accountId.isEmpty }
    }

    private var accountOptions: [(id: String, label: String)] {
        let grouped = Dictionary(grouping: allRecords, by: \.accountId)
        return grouped.compactMap { accountId, records in
            guard let first = records.first, !accountId.isEmpty else { return nil }
            return (accountId, "\(first.institutionName) · \(first.accountName)")
        }.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.zifrBG.ignoresSafeArea()

                if isPreparing {
                    loadingState("Preparing transactions…")
                } else if allRecords.isEmpty && isSyncing {
                    loadingState("Syncing all accounts…")
                } else if allRecords.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            summaryCard
                            searchAndFilters
                            reviewQueueCard

                            if !detectedSubscriptions.isEmpty {
                                DetectedSubscriptionsBanner(
                                    detected: detectedSubscriptions,
                                    cardId: nil,
                                    cardName: "your accounts",
                                    companyId: nil,
                                    vm: vm
                                )
                            }

                            if filteredRecords.isEmpty {
                                filteredEmptyState
                            } else {
                                ForEach(groupedRecords, id: \.date) { group in
                                    transactionSection(group)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 36)
                    }
                    .refreshable { await syncAndRefresh() }
                }
            }
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await syncAndRefresh() }
                    } label: {
                        if isSyncing {
                            ProgressView().tint(Color.zifrGold)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(Color.zifrGold)
                        }
                    }
                    .disabled(isSyncing)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showDuplicateReview) {
                DuplicateChargeReviewSheet(
                    alerts: duplicateAlerts,
                    onDismissAlert: { alert in
                        DuplicateChargeDismissalStore.dismiss(alert)
                        dismissedDuplicateIds.insert(alert.id)
                    }
                )
            }
        }
        .presentationDetents([.fraction(0.92), .large])
        .task {
            await rebuildAnalysis(showLoading: true)
        }
        .onChange(of: appState.transactions) { _, _ in
            Task { await rebuildAnalysis() }
        }
        .onChange(of: appState.companies) { _, _ in
            Task { await rebuildAnalysis() }
        }
        .onChange(of: appState.institutions) { _, _ in
            Task { await rebuildAnalysis() }
        }
        .onChange(of: appState.cards) { _, _ in
            Task { await rebuildAnalysis() }
        }
        .onChange(of: appState.subscriptions) { _, _ in
            Task { await rebuildAnalysis() }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ALL ACCOUNTS")
                        .font(.system(size: 11, weight: .black))
                        .tracking(1.6)
                        .foregroundStyle(Color.zifrGold)
                    Text("\(filteredRecords.count) transaction\(filteredRecords.count == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                Spacer()
                if let syncError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .accessibilityLabel(syncError)
                }
            }

            HStack(spacing: 10) {
                summaryMetric(title: "SPENT", value: formatCurrency(summary.moneyOut), color: .white)
                summaryMetric(title: "RECEIVED", value: formatCurrency(summary.moneyIn), color: Color.zifrGreen)
                summaryMetric(title: "PENDING", value: "\(summary.pendingCount)", color: .orange)
            }

            if summary.financialMovementCount > 0 {
                Label(
                    "Excludes \(summary.financialMovementCount) posted transfers and payments",
                    systemImage: "arrow.left.arrow.right"
                )
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.42))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.zifrGold.opacity(0.3), lineWidth: 1))
    }

    private func summaryMetric(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.42))
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var searchAndFilters: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.white.opacity(0.45))
                TextField("Search merchant, account, or company", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 13))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterMenu(
                        title: selectedCompanyId.flatMap { id in appState.companies.first { $0.id == id }?.name } ?? "All Companies",
                        icon: "building.2"
                    ) {
                        Button("All Companies") { selectedCompanyId = nil }
                        ForEach(appState.companies.sorted { $0.name < $1.name }) { company in
                            Button(company.name) { selectedCompanyId = company.id }
                        }
                    }

                    filterMenu(
                        title: selectedAccountId.flatMap { id in accountOptions.first { $0.id == id }?.label } ?? "All Accounts",
                        icon: "creditcard"
                    ) {
                        Button("All Accounts") { selectedAccountId = nil }
                        ForEach(accountOptions, id: \.id) { account in
                            Button(account.label) { selectedAccountId = account.id }
                        }
                    }
                }
            }

            Picker("Flow", selection: $flowFilter) {
                ForEach(TransactionFlowFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            Picker("Posting status", selection: $postingFilter) {
                ForEach(TransactionPostingFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            if showNeedsReviewOnly {
                Button {
                    showNeedsReviewOnly = false
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Needs Review")
                        Image(systemName: "xmark.circle.fill")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var reviewQueueCard: some View {
        if !duplicateAlerts.isEmpty || !needsReviewRecords.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("REVIEW QUEUE", systemImage: "checklist")
                        .font(.system(size: 11, weight: .black))
                        .tracking(1.2)
                        .foregroundStyle(.orange)
                    Spacer()
                    Text("No data is changed automatically")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.38))
                }

                if !duplicateAlerts.isEmpty {
                    Button {
                        showDuplicateReview = true
                    } label: {
                        reviewQueueRow(
                            icon: "rectangle.on.rectangle.badge.exclamationmark",
                            title: "\(duplicateAlerts.count) possible duplicate\(duplicateAlerts.count == 1 ? "" : "s")",
                            subtitle: "Review nearly identical charges within three days",
                            color: .orange
                        )
                    }
                    .buttonStyle(.plain)
                }

                if !needsReviewRecords.isEmpty {
                    Button {
                        showNeedsReviewOnly = true
                        selectedCompanyId = nil
                        selectedAccountId = nil
                        postingFilter = .all
                        flowFilter = .all
                        searchText = ""
                    } label: {
                        reviewQueueRow(
                            icon: "building.2.crop.circle",
                            title: "\(needsReviewRecords.count) unassigned transaction\(needsReviewRecords.count == 1 ? "" : "s")",
                            subtitle: "Plaid account or company context needs review",
                            color: Color.zifrGold
                        )
                    }
                    .buttonStyle(.plain)
                }

                if let assignmentError {
                    Label(assignmentError, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.045))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.2), lineWidth: 1))
        }
    }

    private func reviewQueueRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.12))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.3))
        }
    }

    private func filterMenu<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu(content: content) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                Text(title)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Color.white.opacity(0.065))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }

    private func transactionSection(_ group: (date: String, records: [ResolvedTransaction])) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sectionDate(group.date))
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Color.white.opacity(0.45))
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(group.records.enumerated()), id: \.element.id) { index, record in
                    transactionRow(record)
                    if index < group.records.count - 1 {
                        Divider().overlay(Color.white.opacity(0.07)).padding(.leading, 58)
                    }
                }
            }
            .background(Color.white.opacity(0.045))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func transactionRow(_ record: ResolvedTransaction) -> some View {
        let transaction = record.transaction
        let amount = transaction.amount ?? 0
        let assignableCompanies = appState.companies
            .filter { $0.userId == transaction.userId }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(transactionColor(transaction).opacity(0.16))
                        .frame(width: 42, height: 42)
                    Image(systemName: transactionIcon(transaction))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(transactionColor(transaction))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(TransactionIntelligence.displayName(for: transaction))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(record.companyName)
                        Text("·")
                        Text(record.accountName)
                        if transaction.pending == true {
                            Text("· Pending")
                                .foregroundStyle(.orange)
                        }
                        if duplicateTransactionIds.contains(record.id) {
                            Text("· Possible duplicate")
                                .foregroundStyle(.orange)
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(signedAmount(amount, currency: transaction.currency))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(amount < 0 ? Color.zifrGreen : .white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)

            if record.companyId == nil {
                Divider().overlay(Color.white.opacity(0.06)).padding(.leading, 58)
                HStack(spacing: 10) {
                    Label("Assign a company", systemImage: "building.2")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.orange)
                    Spacer()
                    if assigningTransactionId == record.id {
                        ProgressView().tint(Color.zifrGold).scaleEffect(0.8)
                    } else if assignableCompanies.isEmpty {
                        Text("No owned companies")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.4))
                    } else {
                        Menu {
                            ForEach(assignableCompanies) { company in
                                Button(company.name) {
                                    Task { await assign(record, to: company) }
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Text("Choose")
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 11)
                            .frame(height: 30)
                            .background(Color.zifrGold.opacity(0.22))
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(.leading, 58)
                .padding(.trailing, 12)
                .padding(.bottom, 10)
            } else if record.accountId.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Plaid account link is missing; reconnect this institution to repair it.")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.orange)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
    }

    private func loadingState(_ message: String) -> some View {
        VStack(spacing: 16) {
            ProgressView().tint(Color.zifrGold).scaleEffect(1.3)
            Text(message)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 42))
                .foregroundStyle(Color.white.opacity(0.18))
            Text("No Transactions Yet")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            Text(syncError ?? "Sync Plaid to pull transactions from every connected account.")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Button("Sync All Accounts") { Task { await syncAndRefresh() } }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.zifrGold)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var filteredEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 30))
                .foregroundStyle(Color.white.opacity(0.25))
            Text("No matching transactions")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Button("Clear Filters") {
                searchText = ""
                selectedCompanyId = nil
                selectedAccountId = nil
                flowFilter = .all
                postingFilter = .all
                showNeedsReviewOnly = false
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.zifrGold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    @MainActor
    private func syncAndRefresh() async {
        guard !isSyncing else { return }
        isSyncing = true
        syncError = nil
        do {
            try await PlaidService.shared.syncSubscriptions()
        } catch {
            let message = error.localizedDescription
            if !message.contains("No active Plaid connection") {
                syncError = message
            }
        }
        do {
            try await DataRepository.shared.refreshTransactions(appState: appState)
            await rebuildAnalysis()
        } catch {
            syncError = "Transactions could not be refreshed: \(error.localizedDescription)"
        }
        isSyncing = false
    }

    @MainActor
    private func rebuildAnalysis(showLoading: Bool = false) async {
        let revision = UUID()
        analysisRevision = revision
        if showLoading && allRecords.isEmpty {
            isPreparing = true
        }

        let transactions = appState.transactions
        let companies = appState.companies
        let institutions = appState.institutions
        let cards = appState.cards
        let subscriptions = appState.subscriptions

        let analysis = await Task.detached(priority: .userInitiated) {
            let records = TransactionIntelligence.resolveAll(
                transactions,
                companies: companies,
                institutions: institutions,
                cards: cards
            )
            return TransactionCenterAnalysis(
                records: records,
                detectedSubscriptions: SubscriptionDetector.detect(
                    transactions: TransactionIntelligence.enrichedTransactions(from: records),
                    existingSubscriptions: subscriptions
                ),
                duplicateAlerts: DuplicateChargeDetector.detect(records: records)
            )
        }.value

        guard !Task.isCancelled, analysisRevision == revision else { return }
        allRecords = analysis.records
        detectedSubscriptions = analysis.detectedSubscriptions
        analyzedDuplicateAlerts = analysis.duplicateAlerts
        isPreparing = false
    }

    @MainActor
    private func assign(_ record: ResolvedTransaction, to company: Company) async {
        guard record.transaction.userId == company.userId else {
            assignmentError = "Only a company you own can receive this transaction."
            return
        }

        assigningTransactionId = record.id
        assignmentError = nil
        defer { assigningTransactionId = nil }

        do {
            try await DataRepository.shared.assignPlaidTransaction(record.id, to: company.id)
            if let index = appState.transactions.firstIndex(where: { $0.id == record.id }) {
                appState.transactions[index].companyId = company.id
            }
        } catch {
            assignmentError = "Could not assign the transaction: \(error.localizedDescription)"
        }
    }

    private func transactionIcon(_ transaction: Transaction) -> String {
        if transaction.pending == true { return "clock.fill" }
        if (transaction.amount ?? 0) < 0 { return "arrow.down.left" }
        let category = (transaction.category ?? []).joined(separator: " ").lowercased()
        if category.contains("food") || category.contains("restaurant") { return "fork.knife" }
        if category.contains("travel") { return "airplane" }
        if TransactionIntelligence.isFinancialMovement(transaction) { return "arrow.left.arrow.right" }
        return "creditcard.fill"
    }

    private func transactionColor(_ transaction: Transaction) -> Color {
        if transaction.pending == true { return .orange }
        return (transaction.amount ?? 0) < 0 ? Color.zifrGreen : Color(hex: "#1A7077")
    }

    private func sectionDate(_ value: String) -> String {
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: value) else { return value }

        if Calendar.current.isDateInToday(date) { return "TODAY" }
        if Calendar.current.isDateInYesterday(date) { return "YESTERDAY" }
        let output = DateFormatter()
        output.dateFormat = "EEEE, MMM d"
        return output.string(from: date).uppercased()
    }

    private func signedAmount(_ amount: Double, currency: String) -> String {
        let absolute = formatCurrency(abs(amount), currency: currency)
        return amount < 0 ? "+\(absolute)" : "−\(absolute)"
    }

    private func formatCurrency(_ amount: Double, currency: String = "USD") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
}

private struct DuplicateChargeReviewSheet: View {
    let alerts: [DuplicateChargeAlert]
    let onDismissAlert: (DuplicateChargeAlert) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var dismissedIds: Set<String> = []

    private var remainingAlerts: [DuplicateChargeAlert] {
        alerts.filter { !dismissedIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.zifrBG.ignoresSafeArea()

                if remainingAlerts.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.zifrGreen)
                        Text("Review Complete")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Dismissed matches will stay hidden unless a new transaction creates a new pattern.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 34)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            VStack(spacing: 5) {
                                Text("Possible Duplicate Charges")
                                    .font(.system(size: 19, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("Miloom only flags posted charges with the same merchant, company, and nearly identical amount within three days.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 4)

                            ForEach(remainingAlerts) { alert in
                                duplicateCard(alert)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                    }
                }
            }
            .navigationTitle("Duplicate Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.fraction(0.86), .large])
    }

    private func duplicateCard(_ alert: DuplicateChargeAlert) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.14))
                        .frame(width: 42, height: 42)
                    Image(systemName: "rectangle.on.rectangle.badge.exclamationmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(alert.displayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text("\(alert.records.count) matching charges · \(alert.records.first?.companyName ?? "Unassigned")")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.45))
                }

                Spacer()

                Text(formatCurrency(alert.amount, currency: alert.currency))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 0) {
                ForEach(Array(alert.records.enumerated()), id: \.element.id) { index, record in
                    HStack(spacing: 10) {
                        Image(systemName: index == 0 ? "1.circle.fill" : "2.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(index == 0 ? Color.zifrGold : .orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.accountName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("\(record.institutionName) · \(formattedDate(record.transaction.date))")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.white.opacity(0.42))
                        }
                        Spacer()
                        Text(formatCurrency(record.transaction.amount ?? 0, currency: record.transaction.currency))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                    if index < alert.records.count - 1 {
                        Divider().overlay(Color.white.opacity(0.06)).padding(.leading, 36)
                    }
                }
            }
            .background(Color.black.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("POSSIBLE EXTRA SPEND")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.4))
                    Text(formatCurrency(alert.possibleDuplicateAmount, currency: alert.currency))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.orange)
                }
                Spacer()
                Button("Not a Duplicate") {
                    onDismissAlert(alert)
                    withAnimation(.spring(response: 0.3)) {
                        _ = dismissedIds.insert(alert.id)
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.orange.opacity(0.24), lineWidth: 1))
    }

    private func formattedDate(_ value: String) -> String {
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: value) else { return value }
        let output = DateFormatter()
        output.dateFormat = "MMM d, yyyy"
        return output.string(from: date)
    }

    private func formatCurrency(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
}
