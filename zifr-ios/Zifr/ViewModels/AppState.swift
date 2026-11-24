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
    var plaidItems: [PlaidItemSummary] = [] { didSet { searchRevision &+= 1 } }
    var entitlementSnapshot: AccessSnapshot = .free
    var resourceConnections: [ResourceConnection] = [] { didSet { searchRevision &+= 1 } }
    var obligations: [PortfolioObligation] = [] { didSet { searchRevision &+= 1 } }
    var isShowingSavedPortfolio = false
    var hasLoadedCompanies = false
    var hasLoadedCompanyContent = false
    @ObservationIgnored var companyLogoTask: Task<Void, Never>?

    func publishCompanyCards(_ cards: [Company]) {
        let previous = Dictionary(companies.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        companies = cards.map { card in
            guard card.logoData == nil, let saved = previous[card.id],
                  saved.userId == card.userId, saved.lastModified == card.lastModified else { return card }
            var result = card
            result.logoData = saved.logoData
            return result
        }
    }

    func applyCompanyLogos(_ rows: [Company]) {
        let logos = Dictionary(rows.compactMap { row in
            row.logoData.map { (row.id, (row.userId, row.lastModified, $0)) }
        }, uniquingKeysWith: { first, _ in first })
        for index in companies.indices {
            let card = companies[index]
            guard card.logoData == nil, let (owner, modified, data) = logos[card.id],
                  card.userId == owner, card.lastModified == modified else { continue }
            companies[index].logoData = data
        }
    }

    var readyCardSections = Set<CompanyCardSection>()
    var savedCardCounts: [UUID: CompanyCardCounts] = [:]

    func cardCount(_ section: CompanyCardSection, for company: Company, live: Int) -> Int? {
        if readyCardSections.contains(section) || live > 0 { return live }
        guard company.userId == portfolioUserID else { return nil }
        return savedCardCounts[company.id]?[section]
    }

    var hasReceivedCompanyList = false
    var hasLoadedPortfolio: Bool = false { didSet { searchRevision &+= 1 } }
    
    var isLoading: Bool = false
    var portfolioLoadIssue: String? = nil { didSet { searchRevision &+= 1 } }
    var error: String? = nil
    
    // This session marker prevents old in-memory records from crossing account boundaries.
    var portfolioLoadingUserID: UUID?
    var portfolioLoadID = UUID()
    var portfolioUserID: UUID? {
        didSet {
            searchRevision &+= 1
            if oldValue != portfolioUserID { clearInstitutionLogoWebsites() }
        }
    }
    private enum InstitutionLogoWebsite {
        case loading(UUID, Task<Void, Never>)
        case resolved(String?)
        case retryAfter(Date)
    }
    // Artwork state belongs to the unlocked portfolio and never enters a record or a search cache.
    private var institutionLogoWebsites: [UUID: InstitutionLogoWebsite] = [:]

    @MainActor
    func institutionLogo(
        for institution: Institution, allowVaultWebsite: Bool
    ) -> (host: String?, fromVault: Bool) {
        if allowVaultWebsite, portfolioUserID == institution.userId,
           case let .resolved(host) = institutionLogoWebsites[institution.id] {
            return (host, true)
        }
        return (SearchBrand.websiteURL(institution.loginUrl)?.host, false)
    }

    @MainActor
    func setInstitutionLogoWebsite(_ website: String?, for institution: Institution) {
        guard portfolioUserID == institution.userId else { return }
        if case let .loading(_, task) = institutionLogoWebsites[institution.id] {
            task.cancel()
        }
        institutionLogoWebsites[institution.id] = .resolved(SearchBrand.websiteURL(website)?.host)
    }

    @MainActor
    func loadInstitutionLogoWebsiteIfNeeded(for institution: Institution) {
        let bankID = institution.id
        let ownerID = institution.userId
        guard hasLoadedPortfolio, portfolioUserID == ownerID,
              institution.loginUrl?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false else { return }
        switch institutionLogoWebsites[bankID] {
        case .loading, .resolved: return
        case .retryAfter(let date) where date > Date(): return
        default: break
        }

        let token = UUID()
        let task = Task { [weak self] in
            let result: InstitutionLogoWebsite
            do {
                let host = try await VaultService.shared.institutionLogoWebsiteHost(id: bankID, ownerUserID: ownerID)
                result = .resolved(SearchBrand.websiteURL(host)?.host)
            } catch {
                result = .retryAfter(Date().addingTimeInterval(30))
            }
            guard !Task.isCancelled, let self, self.portfolioUserID == ownerID,
                  case let .loading(currentToken, _) = self.institutionLogoWebsites[bankID],
                  currentToken == token else { return }
            self.institutionLogoWebsites[bankID] = result
        }
        institutionLogoWebsites[bankID] = .loading(token, task)
    }

    private func clearInstitutionLogoWebsites() {
        for case let .loading(_, task) in institutionLogoWebsites.values { task.cancel() }
        institutionLogoWebsites.removeAll()
    }
    var searchRevision: UInt64 = 0
    var searchDocumentPages: [SearchDocumentPage] = [] { didSet { searchRevision &+= 1 } }
    var searchDocumentStatus = "Document contents have not been indexed" { didSet { searchRevision &+= 1 } }
    var searchDocumentRevision: String {
        "\(portfolioUserID?.uuidString ?? "")|\(hasLoadedPortfolio)|" + documents.map { "\($0.id):\($0.url ?? ""):\($0.visibility ?? "")" }.joined(separator: "|") + "|\(resourceShares.hashValue)"
    }
    @ObservationIgnored private var cachedSearch: (user: UUID, revision: UInt64, stamp: SearchProjectionStamp, index: UniversalSearchIndex)?
    @ObservationIgnored private var pendingSearch: (user: UUID, revision: UInt64, stamp: SearchProjectionStamp, token: UUID, task: Task<UniversalSearchIndex, Never>)?

    func searchRedactor() -> SearchRedactor {
        var values = subscriptions.map(\.password) + cards.map(\.password) + institutions.map(\.password)
        values += cards.map(\.cardNumber)
        values += institutions.flatMap { $0.accounts.flatMap { [$0.accountNumber, $0.routingNumber, $0.wireRoutingNumber] } }
        return SearchRedactor(values: values)
    }

    func searchProjectionStamp(now: Date = Date(), calendar: Calendar = .current) -> SearchProjectionStamp {
        SearchProjectionStamp(institutions: institutions, items: plaidItems, now: now, calendar: calendar)
    }

    @MainActor
    func searchIndex(for userID: UUID, now: Date = Date(), calendar: Calendar = .current) -> UniversalSearchIndex {
        let stamp = searchProjectionStamp(now: now, calendar: calendar)
        if let cachedSearch, cachedSearch.user == userID, cachedSearch.revision == searchRevision, cachedSearch.stamp == stamp { return cachedSearch.index }
        let index = UniversalSearchIndex(snapshot: SearchIndexSnapshot(self), userID: userID, documentPages: searchDocumentPages, now: now, calendar: calendar)
        cachedSearch = (userID, searchRevision, stamp, index)
        return index
    }

    /// Reuse one background build while queries change. Publish only to the same
    /// user/revision; an old refresh must never replace the current session cache.
    @MainActor
    func searchIndexInBackground(for userID: UUID, now: Date? = nil, calendar: Calendar = .current) async throws -> UniversalSearchIndex {
        let reference = now ?? Date()
        let stamp = searchProjectionStamp(now: reference, calendar: calendar)
        try Task.checkCancellation()
        guard portfolioUserID == userID, hasLoadedPortfolio else { throw CancellationError() }
        let revision = searchRevision
        if let cachedSearch, cachedSearch.user == userID, cachedSearch.revision == revision, cachedSearch.stamp == stamp { return cachedSearch.index }
        let work: Task<UniversalSearchIndex, Never>
        let token: UUID
        if let pendingSearch, pendingSearch.user == userID, pendingSearch.revision == revision, pendingSearch.stamp == stamp {
            work = pendingSearch.task; token = pendingSearch.token
        } else {
            pendingSearch?.task.cancel()
            let snapshot = SearchIndexSnapshot(self)
            token = UUID()
            work = Task.detached(priority: .userInitiated) {
                UniversalSearchIndex(snapshot: snapshot, userID: userID, documentPages: snapshot.searchDocumentPages, now: reference, calendar: calendar)
            }
            pendingSearch = (userID, revision, stamp, token, work)
        }
        let index = await work.value
        guard portfolioUserID == userID, hasLoadedPortfolio, searchRevision == revision, searchProjectionStamp(now: now ?? Date(), calendar: calendar) == stamp, !work.isCancelled else { throw CancellationError() }
        if pendingSearch?.token == token {
            cachedSearch = (userID, revision, stamp, index)
            pendingSearch = nil
        }
        try Task.checkCancellation()
        return index
    }

    func clearSearchSession(keepingPortfolio: Bool = false) {
        companyLogoTask?.cancel()
        companyLogoTask = nil
        readyCardSections.removeAll()
        savedCardCounts.removeAll()
        portfolioLoadID = UUID()
        portfolioLoadingUserID = nil
        isLoading = false
        hasReceivedCompanyList = false
        if !keepingPortfolio {
            portfolioUserID = nil
            isShowingSavedPortfolio = false
            hasLoadedCompanies = false
            hasLoadedCompanyContent = false
        }
        hasLoadedPortfolio = false
        searchDocumentPages = []
        searchDocumentStatus = "Document contents have not been indexed"
        cachedSearch = nil
        pendingSearch?.task.cancel()
        pendingSearch = nil
    }

    /// Restore only into the matching authenticated load, before server data has
    /// arrived. This deliberately leaves search/history marked incomplete.
    @discardableResult
    func restoreSavedPortfolio(_ snapshot: PortfolioSnapshot, loadID: UUID, keepingCompanyList: Bool = false) -> Bool {
        guard portfolioLoadID == loadID, portfolioUserID == snapshot.userID,
              !hasReceivedCompanyList, !snapshot.companies.isEmpty,
              !hasLoadedCompanies || (keepingCompanyList && Set(companies.map(\.id)) == Set(snapshot.companies.map(\.id))),
              snapshot.isValid(for: snapshot.userID, now: Date()) else { return false }
        if !keepingCompanyList { companies = snapshot.companies }
        subscriptions = snapshot.subscriptions.map { SubscriptionRenewalScheduler.normalized($0) }
        institutions = snapshot.institutions
        cards = snapshot.cards
        loans = snapshot.loans
        documents = snapshot.documents
        hasLoadedCompanies = true
        hasLoadedCompanyContent = true
        isShowingSavedPortfolio = true
        return true
    }

    /// Clear all visible data before loading a different account. Progressive
    /// loading must never mix a new company's cards with the prior user's records.
    func clearPortfolio() {
        clearSearchSession()
        companies = []
        subscriptions = []
        institutions = []
        cards = []
        loans = []
        documents = []
        transactions = []
        transactionOverrides = []
        transactionCategoryRules = []
        resourceShares = []
        activityLogs = []
        notifications = []
        userPreferences = nil
        alertRules = []
        plaidItems = []
        resourceConnections = []
        obligations = []
        portfolioLoadIssue = nil
        clearBusinessExpenses()
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

    private var inboxAgePolicy: InboxAgePolicy {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = userPreferences?.timezone.flatMap(TimeZone.init(identifier:)) ?? .current
        return InboxAgePolicy(now: Date(), calendar: calendar)
    }

    var unreadNotificationCount: Int {
        let age = inboxAgePolicy
        let disconnected = Set(institutions.filter(\.isDisconnected).map(\.id))
            .union(plaidItems.filter(\.requiresReconnect).compactMap(\.institutionId))
        return notifications.lazy.filter { notice in
            guard !notice.isRead else { return false }
            if InboxTopic.alert(notice, metadata: nil) == .connections,
               let id = notice.resourceId, disconnected.contains(id) { return false }
            let due = InboxScheduledPayment.deadline(notice, metadata: nil, timeZone: age.calendar.timeZone)
            return age.placement(for: due ?? notice.createdAt, scheduled: due != nil) == .current
        }.count
    }

    var unreadInboxCount: Int {
        let age = inboxAgePolicy
        return unreadNotificationCount + activityLogs.lazy.filter {
            !$0.isRead && $0.inboxDismissedAt == nil && age.placement(for: $0.createdAt) == .current
        }.count
    }
}
