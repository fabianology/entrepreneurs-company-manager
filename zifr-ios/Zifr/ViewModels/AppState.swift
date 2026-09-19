import Foundation
import SwiftUI
import Observation

@Observable
final class AppState {
    var companies: [Company] = [] { didSet { searchRevision &+= 1 } }
    var subscriptions: [Subscription] = [] { didSet { searchRevision &+= 1 } }
    var institutions: [Institution] = [] { didSet { searchRevision &+= 1 } }
    var cards: [FinancialCard] = [] { didSet { searchRevision &+= 1 } }
    var loans: [Loan] = [] { didSet { searchRevision &+= 1 } }
    var documents: [CompanyDocument] = [] { didSet { searchRevision &+= 1 } }
    var transactions: [Transaction] = [] { didSet { searchRevision &+= 1 } }
    var transactionOverrides: [TransactionOverride] = [] { didSet { searchRevision &+= 1 } }
    var transactionCategoryRules: [TransactionCategoryRule] = [] { didSet { searchRevision &+= 1 } }
    var businessExpenseReviews: [BusinessExpenseReview] = [] { didSet { searchRevision &+= 1 } }
    var businessExpenseUserID: UUID? { didSet { searchRevision &+= 1 } }
    var businessExpenseSettings = BusinessExpenseSettings() { didSet { searchRevision &+= 1 } }
    var businessExpenseProfiles: [BusinessExpenseProfile] = [] { didSet { searchRevision &+= 1 } }
    var businessExpenseAccounts: [BusinessExpenseAccount] = [] { didSet { searchRevision &+= 1 } }
    var businessExpenseJob: BusinessExpenseJob? { didSet { searchRevision &+= 1 } }
    var businessExpenseLoadError: String? { didSet { searchRevision &+= 1 } }

    func clearBusinessExpenses() {
        businessExpenseUserID = nil
        businessExpenseReviews = []
        businessExpenseSettings = BusinessExpenseSettings()
        businessExpenseProfiles = []
        businessExpenseAccounts = []
        businessExpenseJob = nil
        businessExpenseLoadError = nil
        let files = (try? FileManager.default.contentsOfDirectory(at: FileManager.default.temporaryDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix("miloom-expense-export-") {
            try? FileManager.default.removeItem(at: file)
        }
    }


    var transactionsForAnalysis: [Transaction] {
        let ignoredIDs = Set(transactionOverrides.filter { $0.flowOverride == .ignored }.map(\.transactionId))
        return transactions.filter { !ignoredIDs.contains($0.id) }
    }
    var resourceShares: [ResourceShare] = [] { didSet { searchRevision &+= 1 } }
    var activityLogs: [ActivityLog] = [] { didSet { searchRevision &+= 1 } }
    var notifications: [AppNotification] = [] { didSet { searchRevision &+= 1 } }
    var userPreferences: UserPreferences? = nil { didSet { searchRevision &+= 1 } }
    var alertRules: [AlertRule] = [] { didSet { searchRevision &+= 1 } }
    var plaidItems: [PlaidItemSummary] = []
    var entitlementSnapshot: AccessSnapshot = .free
    var resourceConnections: [ResourceConnection] = [] { didSet { searchRevision &+= 1 } }
    var obligations: [PortfolioObligation] = [] { didSet { searchRevision &+= 1 } }
    var hasLoadedPortfolio: Bool = false { didSet { searchRevision &+= 1 } }
    
    var isLoading: Bool = false
    var portfolioLoadIssue: String? = nil { didSet { searchRevision &+= 1 } }
    var error: String? = nil
    
    // This session marker prevents old in-memory records from crossing account boundaries.
    var portfolioLoadingUserID: UUID?
    var portfolioLoadID = UUID()
    var portfolioUserID: UUID? { didSet { searchRevision &+= 1 } }
    var searchRevision: UInt64 = 0
    var searchDocumentPages: [SearchDocumentPage] = [] { didSet { searchRevision &+= 1 } }
    var searchDocumentStatus = "Document contents have not been indexed" { didSet { searchRevision &+= 1 } }
    var searchDocumentRevision: String {
        "\(portfolioUserID?.uuidString ?? "")|\(hasLoadedPortfolio)|" + documents.map { "\($0.id):\($0.url ?? ""):\($0.visibility ?? "")" }.joined(separator: "|") + "|\(resourceShares.hashValue)"
    }
    @ObservationIgnored private var cachedSearch: (user: UUID, revision: UInt64, index: UniversalSearchIndex)?
    @ObservationIgnored private var pendingSearch: (user: UUID, revision: UInt64, token: UUID, task: Task<UniversalSearchIndex, Never>)?

    func searchRedactor() -> SearchRedactor {
        var values = subscriptions.map(\.password) + cards.map(\.password) + institutions.map(\.password)
        values += cards.map(\.cardNumber)
        values += institutions.flatMap { $0.accounts.flatMap { [$0.accountNumber, $0.routingNumber, $0.wireRoutingNumber] } }
        return SearchRedactor(values: values)
    }

    @MainActor
    func searchIndex(for userID: UUID) -> UniversalSearchIndex {
        if let cachedSearch, cachedSearch.user == userID, cachedSearch.revision == searchRevision { return cachedSearch.index }
        let index = UniversalSearchIndex(appState: self, userID: userID, documentPages: searchDocumentPages)
        cachedSearch = (userID, searchRevision, index)
        return index
    }

    /// Reuse one background build while queries change. Publish only to the same
    /// user/revision; an old refresh must never replace the current session cache.
    @MainActor
    func searchIndexInBackground(for userID: UUID) async throws -> UniversalSearchIndex {
        try Task.checkCancellation()
        guard portfolioUserID == userID, hasLoadedPortfolio else { throw CancellationError() }
        let revision = searchRevision
        if let cachedSearch, cachedSearch.user == userID, cachedSearch.revision == revision { return cachedSearch.index }
        let work: Task<UniversalSearchIndex, Never>
        let token: UUID
        if let pendingSearch, pendingSearch.user == userID, pendingSearch.revision == revision {
            work = pendingSearch.task; token = pendingSearch.token
        } else {
            pendingSearch?.task.cancel()
            let snapshot = SearchIndexSnapshot(self)
            token = UUID()
            work = Task.detached(priority: .userInitiated) {
                UniversalSearchIndex(snapshot: snapshot, userID: userID, documentPages: snapshot.searchDocumentPages)
            }
            pendingSearch = (userID, revision, token, work)
        }
        let index = await work.value
        guard portfolioUserID == userID, hasLoadedPortfolio, searchRevision == revision, !work.isCancelled else { throw CancellationError() }
        if pendingSearch?.token == token {
            cachedSearch = (userID, revision, index)
            pendingSearch = nil
        }
        try Task.checkCancellation()
        return index
    }

    func clearSearchSession() {
        portfolioLoadID = UUID()
        portfolioLoadingUserID = nil
        isLoading = false
        portfolioUserID = nil
        hasLoadedPortfolio = false
        searchDocumentPages = []
        searchDocumentStatus = "Document contents have not been indexed"
        cachedSearch = nil
        pendingSearch?.task.cancel()
        pendingSearch = nil
    }

    // Local Overrides: resourceId -> companyId
    var localCompanyOverrides: [String: UUID] = [:] {
        didSet {
            searchRevision &+= 1
            if let encoded = try? JSONEncoder().encode(localCompanyOverrides) {
                UserDefaults.standard.set(encoded, forKey: "localCompanyOverrides")
            }
        }
    }
    
    init() {
        if let data = UserDefaults.standard.data(forKey: "localCompanyOverrides"),
           let decoded = try? JSONDecoder().decode([String: UUID].self, from: data) {
            self.localCompanyOverrides = decoded
        }
    }
    
    // Derived properties for easy access
    private func effectiveCompanyId(for resourceId: UUID, defaultCompanyId: UUID) -> UUID {
        return localCompanyOverrides[resourceId.uuidString] ?? defaultCompanyId
    }

    func subscriptions(for companyId: UUID) -> [Subscription] {
        subscriptions.filter { effectiveCompanyId(for: $0.id ?? UUID(), defaultCompanyId: $0.companyId) == companyId }
    }
    
    func cards(for companyId: UUID) -> [FinancialCard] {
        cards.filter { effectiveCompanyId(for: $0.id ?? UUID(), defaultCompanyId: $0.companyId) == companyId }
    }
    
    func loans(for companyId: UUID) -> [Loan] {
        loans.filter { effectiveCompanyId(for: $0.id ?? UUID(), defaultCompanyId: $0.companyId) == companyId }
    }
    
    func institutions(for companyId: UUID) -> [Institution] {
        institutions.filter { effectiveCompanyId(for: $0.id ?? UUID(), defaultCompanyId: $0.companyId) == companyId }
    }
    
    func documents(for companyId: UUID) -> [CompanyDocument] {
        documents.filter { effectiveCompanyId(for: $0.id ?? UUID(), defaultCompanyId: $0.companyId) == companyId }
    }

    var confirmedConnectionCount: Int {
        resourceConnections.filter { $0.state == .confirmed }.count
    }

    var suggestedConnectionCount: Int {
        resourceConnections.filter { $0.state == .suggested }.count
    }

    var openObligations: [PortfolioObligation] {
        OwnerBriefingPresentation.activeObligations(in: obligations)
    }

    var deferredObligations: [PortfolioObligation] {
        OwnerBriefingPresentation.deferredObligations(in: obligations)
    }

    var unreadBriefingCount: Int {
        openObligations.filter { $0.severity != .info }.count
    }

    var unreadNotificationCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    var unreadInboxCount: Int {
        unreadNotificationCount + activityLogs.filter { !$0.isRead }.count
    }
}
