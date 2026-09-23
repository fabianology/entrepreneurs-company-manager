import Foundation
import Supabase
import CryptoKit
import Security
import LocalAuthentication
#if canImport(UIKit)
import UIKit
#endif

private actor PortfolioLoadFailures {
    var names = Set<String>()
    func record(_ name: String) { names.insert(name) }
}

enum ShareInviteResult {
    case sharedDirectly
    case invitationEmailSent
    case invitationCreatedEmailFailed
}

class DataRepository {
    static let shared = DataRepository()
    private var client: SupabaseClient { SupabaseService.shared.client }
    private static let transactionPageSize = 1_000
    private static let companyRetryDelays: [Duration] = [
        .milliseconds(250),
        .milliseconds(750)
    ]

    private struct MutationReceipt: Decodable {
        let id: UUID
    }

    private func requireUpdatedRow(_ rows: [MutationReceipt], resource: String) throws {
        guard rows.count == 1 else {
            throw NSError(
                domain: "DataRepository",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "The \(resource) change was not accepted. Refresh your access and try again."]
            )
        }
    }

    // Keep this projection compatible with the production transaction schema.
    // `merchant_website` is optional enrichment and has not been deployed to every
    // environment; Transaction's custom decoder safely leaves it nil when omitted.
    private static let transactionColumns = "id,user_id,company_id,institution_id,plaid_transaction_id,account_id,canonical_account_id,amount,currency,date,authorized_date,name,merchant_name,merchant_website,merchant_logo_url,payment_channel,personal_finance_primary,personal_finance_detailed,personal_finance_confidence,category,pending"

    private func fetchCompanies() async -> Result<[Company], Error> {
        var lastError: Error?

        for attempt in 0...Self.companyRetryDelays.count {
            do {
                let companies: [Company] = try await client
                    .from("companies")
                    .select()
                    .execute()
                    .value
                return .success(companies)
            } catch {
                lastError = error
                guard attempt < Self.companyRetryDelays.count else { break }
                try? await Task.sleep(for: Self.companyRetryDelays[attempt])
            }
        }

        let error = lastError ?? CancellationError()
        AppDiagnostics.failure("data", "fetch_companies", error: error)
        return .failure(error)
    }

    private func refreshMyObligations() async -> Bool {
        do {
            try await client.rpc("refresh_my_miloom_obligations").execute()
            AppDiagnostics.event("briefing", "refresh_obligations", status: "success")
            return true
        } catch {
            AppDiagnostics.failure("briefing", "refresh_obligations", error: error)
            return false
        }
    }
    
    private func searchLoad<T>(_ name: String, failures: PortfolioLoadFailures, operation: () async throws -> [T]) async -> [T] {
        do { return try await operation() }
        catch { AppDiagnostics.failure("search", name, error: error); await failures.record(name); return [] }
    }

    // MARK: - Fetch All Data
    private func fetchTransactions() async throws -> [Transaction] {
        var transactions: [Transaction] = []
        var pageStart = 0

        while true {
            let page: [Transaction] = try await client
                .from("plaid_transactions")
                .select(Self.transactionColumns)
                .eq("is_superseded_duplicate", value: false)
                .eq("is_stale_pending_duplicate", value: false)
                .order("date", ascending: false)
                .order("id", ascending: false)
                .range(
                    from: pageStart,
                    to: pageStart + Self.transactionPageSize - 1
                )
                .execute()
                .value

            transactions.append(contentsOf: page)
            guard page.count == Self.transactionPageSize else { break }
            pageStart += Self.transactionPageSize
        }

        return transactions
    }

    private func safeFetchTransactions() async -> [Transaction] {
        do {
            return try await fetchTransactions()
        }
        catch { 
            AppDiagnostics.failure("plaid", "fetch_transactions", error: error)
            return [] 
        }
    }

    @MainActor
    func refreshTransactions(appState: AppState) async throws {
        let userID = try await client.auth.session.user.id
        let transactions: [Transaction] = try await measure("transactions") {
            try await fetchTransactions()
        }
        guard !Task.isCancelled, appState.portfolioUserID == userID, (try? await client.auth.session.user.id) == userID else { return }
        appState.transactions = transactions
    }

    private func safeFetchShares() async -> [ResourceShare] {
        do { return try await client.from("resource_shares").select().execute().value }
        catch {
            AppDiagnostics.failure("data", "fetch_resource_shares", error: error)
            return []
        }
    }

    /// A foreground check stays inexpensive when grants are unchanged, while
    /// refreshing all RLS-scoped records after a collaborator is added, removed,
    /// or assigned a different role. Never interpret a failed check as revocation.
    @MainActor
    func refreshPortfolioIfSharingChanged(appState: AppState) async {
        guard appState.hasLoadedPortfolio,
              let userID = appState.portfolioUserID,
              (try? await client.auth.session.user.id) == userID else { return }

        do {
            let shares: [ResourceShare] = try await client
                .from("resource_shares")
                .select()
                .execute()
                .value
            guard !Task.isCancelled,
                  appState.portfolioUserID == userID,
                  (try? await client.auth.session.user.id) == userID else { return }
            if Set(shares) != Set(appState.resourceShares) {
                await fetchAllData(appState: appState, force: true)
            }
        } catch {
            AppDiagnostics.failure("data", "refresh_sharing_on_foreground", error: error)
        }
    }

    private func safeFetchAlertRules() async -> [AlertRule] {
        do { return try await fetchAlertRules() }
        catch {
            AppDiagnostics.failure("briefing", "fetch_alert_rules", error: error)
            return []
        }
    }

    // The newer backend returns owner records intact and collaborator records
    // with credential fields redacted. Fall back only while that RPC has not
    // been deployed; a permission or network failure must not widen access.
    private func isMissingVisibleRecordsRPC(_ error: Error) -> Bool {
        (error as? PostgrestError)?.code == "PGRST202"
    }

    private func fetchVisibleSubscriptions() async throws -> [Subscription] {
        do {
            return try await client.rpc("miloom_visible_subscriptions").execute().value
        } catch {
            guard isMissingVisibleRecordsRPC(error) else { throw error }
            return try await client.from("subscriptions").select().execute().value
        }
    }

    private func fetchVisibleCards() async throws -> [FinancialCard] {
        do {
            return try await client.rpc("miloom_visible_financial_cards").execute().value
        } catch {
            guard isMissingVisibleRecordsRPC(error) else { throw error }
            return try await client.from("financial_cards").select().execute().value
        }
    }

    private func fetchVisibleInstitutions() async throws -> [Institution] {
        do {
            return try await client.rpc("miloom_visible_institutions").execute().value
        } catch {
            guard isMissingVisibleRecordsRPC(error) else { throw error }
            return try await client.from("institutions").select().execute().value
        }
    }

    func fetchAlertRules() async throws -> [AlertRule] {
        let rules: [AlertRule] = try await client
            .from("alert_rules")
            .select("user_id,rule_type,enabled,threshold_amount,threshold_percent,lookback_days,lead_days,created_at,updated_at")
            .execute()
            .value
        if !rules.isEmpty { return rules }

        let userId = try await client.auth.session.user.id
        let defaults = AlertRule.conservativeDefaults(userId: userId)
        try await saveAlertRules(defaults)
        return defaults
    }

    @MainActor
    func fetchAllData(appState: AppState, force: Bool = false) async {
        guard let loadingUserID = try? await client.auth.session.user.id else { return }
        if !force && appState.isLoading && appState.portfolioLoadingUserID == loadingUserID { return }
        if appState.portfolioUserID != loadingUserID {
            appState.clearSearchSession()
            appState.companies = []
        }
        let loadID = UUID()
        appState.portfolioLoadID = loadID
        appState.portfolioLoadingUserID = loadingUserID
        appState.isLoading = true
        defer { if appState.portfolioLoadID == loadID { appState.isLoading = false; appState.portfolioLoadingUserID = nil } }

        let searchLoadFailures = PortfolioLoadFailures()
        // Companies drive the first dashboard paint. Publish them immediately rather
        // than holding them until every secondary portfolio request has completed.
        let fetchedCompaniesResult = await measure("companies") { await fetchCompanies() }
        guard !Task.isCancelled, appState.portfolioLoadID == loadID, (try? await client.auth.session.user.id) == loadingUserID else { return }
        switch fetchedCompaniesResult {
        case .success(let fetchedCompanies):
            appState.companies = fetchedCompanies
            appState.portfolioLoadIssue = nil
        case .failure:
            // Preserve any already-rendered companies. A transient refresh failure
            // must never replace known-good portfolio data with an empty dashboard.
            appState.portfolioLoadIssue = "Companies could not be refreshed. Pull down to try again."
        }

        async let fSubscriptions: [Subscription] = measure("subscriptions") { await searchLoad("services", failures: searchLoadFailures) { try await fetchVisibleSubscriptions() } }
        async let fInstitutions: [Institution] = measure("institutions") { await searchLoad("bank accounts", failures: searchLoadFailures) { try await fetchVisibleInstitutions() } }
        async let fCards: [FinancialCard] = measure("cards") { await searchLoad("cards", failures: searchLoadFailures) { try await fetchVisibleCards() } }
        async let fLoans: [Loan] = measure("loans") { await searchLoad("loans", failures: searchLoadFailures) { try await client.from("loans").select().execute().value } }
        async let fLoanPayments: [LoanPayment] = measure("loan_payments") { await searchLoad("loan payments", failures: searchLoadFailures) { try await client.from("loan_payments").select().execute().value } }
        async let fDocuments: [CompanyDocument] = measure("documents") { await searchLoad("documents", failures: searchLoadFailures) { try await client.from("company_documents").select().execute().value } }
        async let fShares: [ResourceShare] = measure("shares") { await searchLoad("sharing permissions", failures: searchLoadFailures) { try await client.from("resource_shares").select().execute().value } }
        async let fActivity: [ActivityLog] = measure("activity_logs") { await searchLoad("activity", failures: searchLoadFailures) { try await client.from("activity_logs").select().order("created_at", ascending: false).execute().value } }
        async let fNotifications: [AppNotification] = measure("app_notifications") { await searchLoad("notifications", failures: searchLoadFailures) { try await client.from("app_notifications").select().order("created_at", ascending: false).execute().value } }
        async let fPrefs: [UserPreferences] = measure("user_preferences") { await searchLoad("preferences", failures: searchLoadFailures) { try await client.from("user_preferences").select().execute().value } }
        async let fAlertRules: [AlertRule] = measure("alert_rules") { await safeFetchAlertRules() }
        async let fPlaidItems: [PlaidItemSummary] = measure("plaid_items") {
            (try? await client
                .from("plaid_items")
                .select("id,company_id,institution_id,institution_name,status,error_code,last_synced_at,created_at")
                .execute()
                .value) ?? []
        }
        async let fConnections: [ResourceConnection] = measure("resource_connections") { await searchLoad("connections", failures: searchLoadFailures) { try await client.from("resource_connections").select().execute().value } }
        async let fObligations: [PortfolioObligation] = measure("obligations") { await searchLoad("reminders", failures: searchLoadFailures) { try await client.from("obligations").select().order("due_at", ascending: true).execute().value } }
        async let fObligationRefresh = refreshMyObligations()
        async let fTransactions = measure("transactions") { await searchLoad("transactions", failures: searchLoadFailures) { try await fetchTransactions() } }
        async let fTransactionOverrides: [TransactionOverride] = measure("transaction_overrides") {
            await searchLoad("transaction classifications", failures: searchLoadFailures) { try await client
                .from("plaid_transaction_overrides").select().execute().value }
        }
        async let fTransactionCategoryRules: [TransactionCategoryRule] = measure("transaction_category_rules") {
            await searchLoad("transaction classifications", failures: searchLoadFailures) { try await client
                .from("plaid_transaction_category_rules").select().execute().value }
        }
        
        let fetchedSubscriptions = await fSubscriptions
        let fetchedInstitutions = await fInstitutions
        let fetchedCards = await fCards
        let fetchedLoans = await fLoans
        let fetchedLoanPayments = await fLoanPayments
        let fetchedDocuments = await fDocuments
        let fetchedPlaidItems = await fPlaidItems
        let shares = await fShares
        let fetchedActivityLogs = await fActivity
        let fetchedNotifications = await fNotifications
        let fetchedPreferences = await fPrefs
        let fetchedAlertRules = await fAlertRules
        let fetchedConnections = await fConnections
        let initiallyFetchedObligations = await fObligations
        let obligationRefreshSucceeded = await fObligationRefresh
        let fetchedObligations: [PortfolioObligation]
        if obligationRefreshSucceeded {
            fetchedObligations = (try? await client.from("obligations").select().order("due_at", ascending: true).execute().value) ?? initiallyFetchedObligations
        } else {
            fetchedObligations = initiallyFetchedObligations
        }
        let transactions = await fTransactions
        let transactionOverrides = await fTransactionOverrides
        let transactionCategoryRules = await fTransactionCategoryRules
        
        await VaultService.shared.restoreSessionIfAvailable(for: loadingUserID)

        let secureSubs = fetchedSubscriptions.map { s -> Subscription in
            var m = s
            m.password = SecurityService.shared.decrypt(s.password, context: vaultContext(owner: s.userId, type: "subscription", id: s.id, field: "password"))
            return m
        }
        let normalizedSubscriptions = secureSubs.map { SubscriptionRenewalScheduler.normalized($0) }
        let subscriptionsNeedingRenewalUpdate = zip(secureSubs, normalizedSubscriptions).compactMap { pair in
            let (original, normalized) = pair
            return original == normalized ? nil : normalized
        }
        let secureInst = fetchedInstitutions.map { decryptInstitutionSecrets($0) }
        let secureCards = fetchedCards.map { c -> FinancialCard in
            var m = c
            m.password = SecurityService.shared.decrypt(c.password, context: vaultContext(owner: c.userId, type: "financial_card", id: c.id, field: "password"))
            return m
        }
        
        let paymentsByLoan = Dictionary(grouping: fetchedLoanPayments, by: { $0.loanId })
        let combinedLoans = fetchedLoans.map { loan -> Loan in
            var l = loan
            l.payments = paymentsByLoan[loan.id] ?? []
            return l
        }
        
        let session = try? await client.auth.session
        let currentUserId = session?.user.id
        guard !Task.isCancelled, appState.portfolioLoadID == loadID, currentUserId == loadingUserID else { return }
        appState.portfolioUserID = loadingUserID

        appState.subscriptions = normalizedSubscriptions
        appState.institutions = secureInst
        appState.cards = secureCards
        appState.loans = combinedLoans
        appState.documents = fetchedDocuments
        appState.plaidItems = fetchedPlaidItems
        appState.resourceShares = shares
        appState.activityLogs = fetchedActivityLogs
        appState.notifications = fetchedNotifications
        appState.userPreferences = fetchedPreferences.first
        appState.alertRules = fetchedAlertRules
        appState.transactions = transactions
        appState.transactionOverrides = transactionOverrides
        appState.transactionCategoryRules = transactionCategoryRules
        appState.resourceConnections = fetchedConnections
        appState.obligations = fetchedObligations

        // Keep next-due dates current in Supabase. A failed background write does
        // not block the portfolio from showing the correctly calculated date.
        for subscription in subscriptionsNeedingRenewalUpdate {
            guard !Task.isCancelled, appState.portfolioLoadID == loadID else { return }
            try? await updateSubscription(subscription)
        }

        guard !Task.isCancelled, appState.portfolioLoadID == loadID else { return }
        if let currentUserId {
            let generatedConnections = PortfolioConnectionEngine.buildConnections(appState: appState, ownerUserId: currentUserId)
            let existingEdges = Set(fetchedConnections.map(Self.connectionIdentity))
            let newConnections = generatedConnections.filter { !existingEdges.contains(Self.connectionIdentity($0)) }
            if !newConnections.isEmpty {
                try? await upsertConnections(newConnections)
                guard !Task.isCancelled, appState.portfolioLoadID == loadID else { return }
                appState.resourceConnections.append(contentsOf: newConnections)
            }

        }
        // Write count to a file we can read from the host
        if let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = docsDir.appendingPathComponent("tx_count.txt")
            try? "\(transactions.count)".write(to: fileURL, atomically: true, encoding: .utf8)
        }

        guard !Task.isCancelled, (try? await client.auth.session.user.id) == loadingUserID else {
            if appState.portfolioLoadID == loadID { appState.clearSearchSession(); appState.isLoading = false; appState.portfolioLoadingUserID = nil }
            return
        }
        guard appState.portfolioLoadID == loadID else { return }
        let unavailable = await searchLoadFailures.names.sorted()
        guard !Task.isCancelled, appState.portfolioLoadID == loadID else { return }
        if !unavailable.isEmpty {
            appState.portfolioLoadIssue = ([appState.portfolioLoadIssue].compactMap { $0 } + ["Could not load: " + unavailable.joined(separator: ", ") + ". Search and totals may be incomplete."]).joined(separator: " ")
        }
        appState.hasLoadedPortfolio = true

    }

    private static func connectionIdentity(_ connection: ResourceConnection) -> String {
        "\(connection.sourceType.rawValue):\(connection.sourceId):\(connection.targetType.rawValue):\(connection.targetId):\(connection.relationshipType.rawValue)"
    }

    // MARK: - Miloom Pro portfolio intelligence
    func upsertConnections(_ connections: [ResourceConnection]) async throws {
        guard !connections.isEmpty else { return }
        try await client.from("resource_connections").upsert(
            connections,
            onConflict: "owner_user_id,source_type,source_id,target_type,target_id,relationship_type"
        ).execute()
    }

    func updateConnection(_ connection: ResourceConnection) async throws {
        try await client.from("resource_connections")
            .update(connection)
            .eq("id", value: connection.id)
            .execute()
    }

    func insertConnection(_ connection: ResourceConnection) async throws {
        try await client.from("resource_connections").insert(connection).execute()
    }

    func updateObligation(_ obligation: PortfolioObligation) async throws {
        try await client.from("obligations")
            .update(obligation)
            .eq("id", value: obligation.id)
            .execute()
    }

    func assignPlaidTransaction(_ transactionId: UUID, to companyId: UUID) async throws {
        struct Parameters: Encodable {
            let transactionId: UUID
            let companyId: UUID

            enum CodingKeys: String, CodingKey {
                case transactionId = "p_transaction_id"
                case companyId = "p_company_id"
            }
        }

        try await client.rpc(
            "assign_plaid_transaction_company",
            params: Parameters(transactionId: transactionId, companyId: companyId)
        ).execute()
    }

    func upsertTransactionOverride(_ override: TransactionOverride) async throws -> TransactionOverride {
        let saved: [TransactionOverride] = try await client
            .from("plaid_transaction_overrides")
            .upsert(override, onConflict: "user_id,transaction_id")
            .select()
            .execute()
            .value
        guard let result = saved.first else {
            throw NSError(
                domain: "Miloom.TransactionOverride",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "The correction was saved but could not be reloaded."]
            )
        }
        return result
    }

    func deleteTransactionOverride(transactionId: UUID) async throws {
        try await client
            .from("plaid_transaction_overrides")
            .delete()
            .eq("transaction_id", value: transactionId)
            .execute()
    }

    func upsertTransactionCategoryRule(_ rule: TransactionCategoryRule) async throws -> TransactionCategoryRule {
        let saved: [TransactionCategoryRule] = try await client
            .from("plaid_transaction_category_rules")
            .upsert(rule, onConflict: "user_id,scope_key,merchant_key")
            .select()
            .execute()
            .value
        guard let result = saved.first else {
            throw NSError(
                domain: "Miloom.TransactionCategoryRule",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "The category rule was saved but could not be reloaded."]
            )
        }
        return result
    }

    func deleteTransactionCategoryRule(id: UUID) async throws {
        try await client
            .from("plaid_transaction_category_rules")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func registerPushToken(_ token: String, environment: String) async throws {
        guard let session = try? await client.auth.session else { return }
        let userId = session.user.id
        struct PushToken: Encodable {
            let userId: UUID
            let token: String
            let environment: String
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case token
                case environment
            }
        }
        try await client.from("device_push_tokens")
            .upsert(PushToken(userId: userId, token: token, environment: environment), onConflict: "user_id,token")
            .execute()
    }

    func unregisterPushToken(_ token: String) async throws {
        guard let userId = try? await client.auth.session.user.id else { return }
        try await client.from("device_push_tokens")
            .delete()
            .eq("user_id", value: userId)
            .eq("token", value: token)
            .execute()
    }

    func saveBriefingPreferences(
        weekday: Int,
        time: String,
        timezone: String,
        weeklyEnabled: Bool,
        criticalEnabled: Bool
    ) async throws {
        guard let session = try? await client.auth.session else { return }
        struct Payload: Encodable {
            let userId: UUID
            let remindersEnabled: Bool
            let securityEnabled: Bool
            let messagesEnabled: Bool
            let briefingWeekday: Int
            let briefingTime: String
            let timezone: String
            let weeklyBriefingEnabled: Bool
            let criticalAlertsEnabled: Bool
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case remindersEnabled = "reminders_enabled"
                case securityEnabled = "security_enabled"
                case messagesEnabled = "messages_enabled"
                case briefingWeekday = "briefing_weekday"
                case briefingTime = "briefing_time"
                case timezone
                case weeklyBriefingEnabled = "weekly_briefing_enabled"
                case criticalAlertsEnabled = "critical_alerts_enabled"
            }
        }
        let payload = Payload(
            userId: session.user.id,
            remindersEnabled: true,
            securityEnabled: true,
            messagesEnabled: true,
            briefingWeekday: weekday,
            briefingTime: time,
            timezone: timezone,
            weeklyBriefingEnabled: weeklyEnabled,
            criticalAlertsEnabled: criticalEnabled
        )
        try await client.from("user_preferences").upsert(payload, onConflict: "user_id").execute()
    }

    func saveAlertRules(_ rules: [AlertRule]) async throws {
        struct Payload: Encodable {
            let userId: UUID
            let ruleType: AlertRuleType
            let enabled: Bool
            let thresholdAmount: Double?
            let thresholdPercent: Double?
            let lookbackDays: Int?
            let leadDays: Int?

            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case ruleType = "rule_type"
                case enabled
                case thresholdAmount = "threshold_amount"
                case thresholdPercent = "threshold_percent"
                case lookbackDays = "lookback_days"
                case leadDays = "lead_days"
            }
        }

        let payloads = rules.map {
            Payload(
                userId: $0.userId,
                ruleType: $0.ruleType,
                enabled: $0.enabled,
                thresholdAmount: $0.thresholdAmount,
                thresholdPercent: $0.thresholdPercent,
                lookbackDays: $0.lookbackDays,
                leadDays: $0.leadDays
            )
        }
        try await client.from("alert_rules").upsert(payloads, onConflict: "user_id,rule_type").execute()
    }
    
    // MARK: - Companies
    func insertCompany(_ company: Company) async throws {
        try await client.from("companies").insert(company).execute()
    }
    func updateCompany(_ company: Company) async throws {
        let session = try? await client.auth.session
        let rows: [MutationReceipt] = try await client.from("companies")
            .update(company)
            .eq("id", value: company.id)
            .select("id")
            .execute().value
        try requireUpdatedRow(rows, resource: "company")
        if let session, company.userId != session.user.id {
            let log = ActivityLog(userId: company.userId, actorEmail: session.user.email ?? "Someone", actionType: "updated_company", message: "\(session.user.email ?? "Someone") updated the shared company '\(company.name)'.", resourceId: company.id, resourceType: "company")
            try? await insertActivityLog(log)
        }
    }
    func deleteCompany(_ id: UUID) async throws {
        try await client.from("companies").delete().eq("id", value: id).execute()
    }
    func leaveResource(resourceId: UUID, resourceType: String, resourceName: String, ownerId: UUID) async throws {
        let session = try await client.auth.session
        let log = ActivityLog(userId: ownerId, actorEmail: session.user.email ?? "Unknown", actionType: "left_resource", message: "\(session.user.email ?? "Someone") left the shared \(resourceType) '\(resourceName)'.", resourceId: resourceId, resourceType: resourceType)
        try? await insertActivityLog(log)
        
        // Use the secure backend RPC to atomically delete both shares and invitations case-insensitively
        struct LeaveRPCParams: Encodable {
            let p_resource_id: UUID
            let p_resource_type: String
        }
        let params = LeaveRPCParams(p_resource_id: resourceId, p_resource_type: resourceType)
        try await client.rpc("miloom_leave_resource", params: params).execute()
    }
    
    // MARK: - Subscriptions
    func insertSubscription(_ sub: Subscription) async throws {
        var secureSub = sub
        secureSub.password = SecurityService.shared.encrypt(secureSub.password, context: vaultContext(owner: sub.userId, type: "subscription", id: sub.id, field: "password"))
        try await client.from("subscriptions").insert(secureSub).execute()
    }
    func updateSubscription(_ sub: Subscription) async throws {
        let session = try? await client.auth.session
        var secureSub = sub
        if let session, sub.userId != session.user.id {
            // The backend preserves owner credentials on collaborator edits.
            secureSub.password = nil
        } else {
            secureSub.password = SecurityService.shared.encrypt(secureSub.password, context: vaultContext(owner: sub.userId, type: "subscription", id: sub.id, field: "password"))
        }
        let rows: [MutationReceipt] = try await client.from("subscriptions")
            .update(secureSub)
            .eq("id", value: sub.id)
            .select("id")
            .execute().value
        try requireUpdatedRow(rows, resource: "service")
        if let session, sub.userId != session.user.id {
            let log = ActivityLog(userId: sub.userId, actorEmail: session.user.email ?? "Someone", actionType: "updated_subscription", message: "\(session.user.email ?? "Someone") updated the shared subscription '\(sub.name)'.", resourceId: sub.id, resourceType: "subscription")
            try? await insertActivityLog(log)
        }
    }
    func deleteSubscription(_ id: UUID) async throws {
        try await client.from("subscriptions").delete().eq("id", value: id).execute()
    }
    
    // MARK: - Financial Cards
    func insertCard(_ card: FinancialCard) async throws {
        var secureCard = card
        secureCard.password = SecurityService.shared.encrypt(secureCard.password, context: vaultContext(owner: card.userId, type: "financial_card", id: card.id, field: "password"))
        try await client.from("financial_cards").insert(secureCard).execute()
    }
    func updateCard(_ card: FinancialCard) async throws {
        let session = try? await client.auth.session
        var secureCard = card
        if let session, card.userId != session.user.id {
            secureCard.password = nil
        } else {
            secureCard.password = SecurityService.shared.encrypt(secureCard.password, context: vaultContext(owner: card.userId, type: "financial_card", id: card.id, field: "password"))
        }
        let rows: [MutationReceipt] = try await client.from("financial_cards")
            .update(secureCard)
            .eq("id", value: card.id)
            .select("id")
            .execute().value
        try requireUpdatedRow(rows, resource: "card")
        if let session, card.userId != session.user.id {
            let log = ActivityLog(userId: card.userId, actorEmail: session.user.email ?? "Someone", actionType: "updated_card", message: "\(session.user.email ?? "Someone") updated the shared card '\(card.name)'.", resourceId: card.id, resourceType: "card")
            try? await insertActivityLog(log)
        }
    }
    func upsertCard(_ card: FinancialCard) async throws {
        var secureCard = card
        if let session = try? await client.auth.session, card.userId != session.user.id {
            secureCard.password = nil
        } else {
            secureCard.password = SecurityService.shared.encrypt(secureCard.password, context: vaultContext(owner: card.userId, type: "financial_card", id: card.id, field: "password"))
        }
        // INSERT ... ON CONFLICT DO UPDATE needs SELECT grants for every
        // updated column, including credentials. Keep those grants closed.
        let updated: [MutationReceipt] = try await client.from("financial_cards")
            .update(secureCard).eq("id", value: card.id).select("id").execute().value
        if !updated.isEmpty {
            try requireUpdatedRow(updated, resource: "card")
            return
        }
        do {
            try await client.from("financial_cards").insert(secureCard).execute()
        } catch let error as PostgrestError where error.code == "23505" {
            let retry: [MutationReceipt] = try await client.from("financial_cards")
                .update(secureCard).eq("id", value: card.id).select("id").execute().value
            try requireUpdatedRow(retry, resource: "card")
        }
    }
    func deleteCard(_ id: UUID) async throws {
        try await client.from("financial_cards").delete().eq("id", value: id).execute()
    }
    
    // MARK: - Institutions
    func insertInstitution(_ inst: Institution) async throws {
        let secureInst = encryptInstitutionSecrets(inst)
        try await client.from("institutions").insert(secureInst).execute()
    }
    func updateInstitution(_ inst: Institution) async throws {
        let session = try? await client.auth.session
        let secureInst: Institution
        if let session, inst.userId != session.user.id {
            secureInst = try await preservingStoredInstitutionSecrets(in: inst)
        } else {
            secureInst = encryptInstitutionSecrets(inst)
        }
        let rows: [MutationReceipt] = try await client.from("institutions")
            .update(secureInst)
            .eq("id", value: inst.id)
            .select("id")
            .execute().value
        try requireUpdatedRow(rows, resource: "bank")
        if let session, inst.userId != session.user.id {
            let log = ActivityLog(userId: inst.userId, actorEmail: session.user.email ?? "Someone", actionType: "updated_institution", message: "\(session.user.email ?? "Someone") updated the shared institution '\(inst.name)'.", resourceId: inst.id, resourceType: "institution")
            try? await insertActivityLog(log)
        }
    }
    func upsertInstitution(_ inst: Institution) async throws {
        let secureInst: Institution
        if let session = try? await client.auth.session, inst.userId != session.user.id {
            secureInst = try await preservingStoredInstitutionSecrets(in: inst)
        } else {
            secureInst = encryptInstitutionSecrets(inst)
        }
        let updated: [MutationReceipt] = try await client.from("institutions")
            .update(secureInst).eq("id", value: inst.id).select("id").execute().value
        if !updated.isEmpty {
            try requireUpdatedRow(updated, resource: "bank")
            return
        }
        do {
            try await client.from("institutions").insert(secureInst).execute()
        } catch let error as PostgrestError where error.code == "23505" {
            let retry: [MutationReceipt] = try await client.from("institutions")
                .update(secureInst).eq("id", value: inst.id).select("id").execute().value
            try requireUpdatedRow(retry, resource: "bank")
        }
    }

    private func preservingStoredInstitutionSecrets(in proposed: Institution) async throws -> Institution {
        guard let stored = try await fetchVisibleInstitutions().first(where: { $0.id == proposed.id }) else { return proposed }
        let storedAccounts = stored.accounts.reduce(into: [String: InstitutionAccount]()) { result, account in
            if result[account.id] == nil { result[account.id] = account }
        }
        var preserved = proposed
        preserved.password = stored.password
        preserved.accounts = proposed.accounts.map { account in
            guard let storedAccount = storedAccounts[account.id] else {
                var newAccount = account
                newAccount.accountNumber = nil
                newAccount.routingNumber = nil
                newAccount.wireRoutingNumber = nil
                return newAccount
            }
            var merged = account
            merged.accountNumber = storedAccount.accountNumber
            merged.routingNumber = storedAccount.routingNumber
            merged.wireRoutingNumber = storedAccount.wireRoutingNumber
            return merged
        }
        return preserved
    }

    private func encryptInstitutionSecrets(_ institution: Institution) -> Institution {
        var secured = institution
        secured.password = SecurityService.shared.encrypt(secured.password, context: vaultContext(owner: institution.userId, type: "institution", id: institution.id, field: "password"))
        secured.accounts = secured.accounts.map { account in
            var securedAccount = account
            let prefix = "accounts.\(account.id)"
            securedAccount.accountNumber = SecurityService.shared.encrypt(account.accountNumber, context: vaultContext(owner: institution.userId, type: "institution", id: institution.id, field: "\(prefix).account_number"))
            securedAccount.routingNumber = SecurityService.shared.encrypt(account.routingNumber, context: vaultContext(owner: institution.userId, type: "institution", id: institution.id, field: "\(prefix).routing_number"))
            securedAccount.wireRoutingNumber = SecurityService.shared.encrypt(account.wireRoutingNumber, context: vaultContext(owner: institution.userId, type: "institution", id: institution.id, field: "\(prefix).wire_routing_number"))
            return securedAccount
        }
        return secured
    }

    private func decryptInstitutionSecrets(_ institution: Institution) -> Institution {
        var decrypted = institution
        decrypted.password = SecurityService.shared.decrypt(decrypted.password, context: vaultContext(owner: institution.userId, type: "institution", id: institution.id, field: "password"))
        decrypted.accounts = decrypted.accounts.map { account in
            var decryptedAccount = account
            let prefix = "accounts.\(account.id)"
            decryptedAccount.accountNumber = SecurityService.shared.decrypt(account.accountNumber, context: vaultContext(owner: institution.userId, type: "institution", id: institution.id, field: "\(prefix).account_number"))
            decryptedAccount.routingNumber = SecurityService.shared.decrypt(account.routingNumber, context: vaultContext(owner: institution.userId, type: "institution", id: institution.id, field: "\(prefix).routing_number"))
            decryptedAccount.wireRoutingNumber = SecurityService.shared.decrypt(account.wireRoutingNumber, context: vaultContext(owner: institution.userId, type: "institution", id: institution.id, field: "\(prefix).wire_routing_number"))
            return decryptedAccount
        }
        return decrypted
    }

    private func vaultContext(owner: UUID, type: String, id: UUID, field: String) -> VaultFieldContext? {
        guard let snapshot = VaultKeySession.shared.snapshot(for: owner) else { return nil }
        return VaultFieldContext(ownerUserID: owner, resourceType: type, resourceID: id, fieldName: field, keyVersion: snapshot.keyVersion)
    }

    func collectOwnedResourceSecretCandidates(
        snapshot: VaultKeySession.Snapshot
    ) async throws -> ResourceSecretCandidateCollection {
        async let subscriptions = fetchVisibleSubscriptions()
        async let cards = fetchVisibleCards()
        async let institutions = fetchVisibleInstitutions()
        let (ownedSubscriptions, ownedCards, ownedInstitutions) = try await (
            subscriptions, cards, institutions
        )
        var result = ResourceSecretCandidateCollection()
        for subscription in ownedSubscriptions where subscription.userId == snapshot.userID {
            result.append { try ResourceSecretPreparation.candidate(for: subscription, snapshot: snapshot) }
        }
        for card in ownedCards where card.userId == snapshot.userID {
            result.append { try ResourceSecretPreparation.candidate(for: card, snapshot: snapshot) }
        }
        for institution in ownedInstitutions where institution.userId == snapshot.userID {
            result.append { try ResourceSecretPreparation.candidate(for: institution, snapshot: snapshot) }
        }
        return result
    }

    func migrateLegacyVaultSecrets(snapshot: VaultKeySession.Snapshot) async throws -> VaultMigrationReport {
        let owner = snapshot.userID
        let subscriptions = try await fetchVisibleSubscriptions().filter { $0.userId == owner }
        let cards = try await fetchVisibleCards().filter { $0.userId == owner }
        let institutions = try await fetchVisibleInstitutions().filter { $0.userId == owner }
        var report = VaultMigrationReport()

        struct PasswordPatch: Encodable { let password: String }
        for subscription in subscriptions {
            let context = VaultFieldContext(ownerUserID: owner, resourceType: "subscription", resourceID: subscription.id, fieldName: "password", keyVersion: snapshot.keyVersion)
            switch migrateSecret(subscription.password, using: snapshot.key, context: context) {
            case .migrated(let value):
                do {
                    try await client.from("subscriptions").update(PasswordPatch(password: value)).eq("id", value: subscription.id).eq("user_id", value: owner).execute()
                    report.migratedFields += 1
                } catch {
                    report.failedRecords += 1
                    AppDiagnostics.failure("vault", "migrate_subscription", error: error)
                }
            case .locked:
                report.skippedLockedFields += 1
            case .unchanged:
                break
            }
        }

        for card in cards {
            let context = VaultFieldContext(ownerUserID: owner, resourceType: "financial_card", resourceID: card.id, fieldName: "password", keyVersion: snapshot.keyVersion)
            switch migrateSecret(card.password, using: snapshot.key, context: context) {
            case .migrated(let value):
                do {
                    try await client.from("financial_cards").update(PasswordPatch(password: value)).eq("id", value: card.id).eq("user_id", value: owner).execute()
                    report.migratedFields += 1
                } catch {
                    report.failedRecords += 1
                    AppDiagnostics.failure("vault", "migrate_card", error: error)
                }
            case .locked:
                report.skippedLockedFields += 1
            case .unchanged:
                break
            }
        }

        struct InstitutionSecretsPatch: Encodable {
            let password: String?
            let accountsData: [InstitutionAccount]
            enum CodingKeys: String, CodingKey {
                case password
                case accountsData = "accounts_data"
            }
        }
        for institution in institutions {
            var password = institution.password
            var accounts = institution.accounts
            var migratedCount = 0
            var lockedCount = 0
            let passwordContext = VaultFieldContext(ownerUserID: owner, resourceType: "institution", resourceID: institution.id, fieldName: "password", keyVersion: snapshot.keyVersion)
            switch migrateSecret(password, using: snapshot.key, context: passwordContext) {
            case .migrated(let value): password = value; migratedCount += 1
            case .locked: lockedCount += 1
            case .unchanged: break
            }
            for index in accounts.indices {
                let prefix = "accounts.\(accounts[index].id)"
                let fields: [(String, WritableKeyPath<InstitutionAccount, String?>)] = [
                    ("account_number", \.accountNumber),
                    ("routing_number", \.routingNumber),
                    ("wire_routing_number", \.wireRoutingNumber)
                ]
                for (field, keyPath) in fields {
                    let context = VaultFieldContext(ownerUserID: owner, resourceType: "institution", resourceID: institution.id, fieldName: "\(prefix).\(field)", keyVersion: snapshot.keyVersion)
                    switch migrateSecret(accounts[index][keyPath: keyPath], using: snapshot.key, context: context) {
                    case .migrated(let value): accounts[index][keyPath: keyPath] = value; migratedCount += 1
                    case .locked: lockedCount += 1
                    case .unchanged: break
                    }
                }
            }
            report.skippedLockedFields += lockedCount
            guard migratedCount > 0 else { continue }
            do {
                try await client.from("institutions")
                    .update(InstitutionSecretsPatch(password: password, accountsData: accounts))
                    .eq("id", value: institution.id)
                    .eq("user_id", value: owner)
                    .execute()
                report.migratedFields += migratedCount
            } catch {
                report.failedRecords += 1
                AppDiagnostics.failure("vault", "migrate_institution", error: error)
            }
        }
        return report
    }

    func rotateVaultSecrets(
        snapshot: VaultKeySession.Snapshot,
        fromKeyVersion: Int
    ) async throws -> VaultMigrationReport {
        let owner = snapshot.userID
        let subscriptions = try await fetchVisibleSubscriptions().filter { $0.userId == owner }
        let cards = try await fetchVisibleCards().filter { $0.userId == owner }
        let institutions = try await fetchVisibleInstitutions().filter { $0.userId == owner }
        var report = VaultMigrationReport()

        struct PasswordPatch: Encodable { let password: String }
        for subscription in subscriptions {
            let context = VaultFieldContext(ownerUserID: owner, resourceType: "subscription", resourceID: subscription.id, fieldName: "password", keyVersion: snapshot.keyVersion)
            switch rotateSecret(subscription.password, snapshot: snapshot, fromKeyVersion: fromKeyVersion, context: context) {
            case .migrated(let value):
                do {
                    try await client.from("subscriptions").update(PasswordPatch(password: value)).eq("id", value: subscription.id).eq("user_id", value: owner).execute()
                    report.migratedFields += 1
                } catch {
                    report.failedRecords += 1
                    report.remainingOldVaultFields += 1
                    AppDiagnostics.failure("vault", "rotate_subscription", error: error)
                }
            case .oldVaultLocked: report.remainingOldVaultFields += 1
            case .legacyLocked: report.skippedLockedFields += 1
            case .unchanged: break
            }
        }

        for card in cards {
            let context = VaultFieldContext(ownerUserID: owner, resourceType: "financial_card", resourceID: card.id, fieldName: "password", keyVersion: snapshot.keyVersion)
            switch rotateSecret(card.password, snapshot: snapshot, fromKeyVersion: fromKeyVersion, context: context) {
            case .migrated(let value):
                do {
                    try await client.from("financial_cards").update(PasswordPatch(password: value)).eq("id", value: card.id).eq("user_id", value: owner).execute()
                    report.migratedFields += 1
                } catch {
                    report.failedRecords += 1
                    report.remainingOldVaultFields += 1
                    AppDiagnostics.failure("vault", "rotate_card", error: error)
                }
            case .oldVaultLocked: report.remainingOldVaultFields += 1
            case .legacyLocked: report.skippedLockedFields += 1
            case .unchanged: break
            }
        }

        struct InstitutionSecretsPatch: Encodable {
            let password: String?
            let accountsData: [InstitutionAccount]
            enum CodingKeys: String, CodingKey {
                case password
                case accountsData = "accounts_data"
            }
        }
        for institution in institutions {
            var password = institution.password
            var accounts = institution.accounts
            var migratedCount = 0
            var oldLockedCount = 0
            var legacyLockedCount = 0
            let passwordContext = VaultFieldContext(ownerUserID: owner, resourceType: "institution", resourceID: institution.id, fieldName: "password", keyVersion: snapshot.keyVersion)
            switch rotateSecret(password, snapshot: snapshot, fromKeyVersion: fromKeyVersion, context: passwordContext) {
            case .migrated(let encrypted): password = encrypted; migratedCount += 1
            case .oldVaultLocked: oldLockedCount += 1
            case .legacyLocked: legacyLockedCount += 1
            case .unchanged: break
            }
            for index in accounts.indices {
                let prefix = "accounts.\(accounts[index].id)"
                let fields: [(String, WritableKeyPath<InstitutionAccount, String?>)] = [
                    ("account_number", \.accountNumber),
                    ("routing_number", \.routingNumber),
                    ("wire_routing_number", \.wireRoutingNumber)
                ]
                for (field, keyPath) in fields {
                    let context = VaultFieldContext(ownerUserID: owner, resourceType: "institution", resourceID: institution.id, fieldName: "\(prefix).\(field)", keyVersion: snapshot.keyVersion)
                    var value = accounts[index][keyPath: keyPath]
                    switch rotateSecret(value, snapshot: snapshot, fromKeyVersion: fromKeyVersion, context: context) {
                    case .migrated(let encrypted): value = encrypted; migratedCount += 1
                    case .oldVaultLocked: oldLockedCount += 1
                    case .legacyLocked: legacyLockedCount += 1
                    case .unchanged: break
                    }
                    accounts[index][keyPath: keyPath] = value
                }
            }
            report.remainingOldVaultFields += oldLockedCount
            report.skippedLockedFields += legacyLockedCount
            guard migratedCount > 0 else { continue }
            do {
                try await client.from("institutions")
                    .update(InstitutionSecretsPatch(password: password, accountsData: accounts))
                    .eq("id", value: institution.id)
                    .eq("user_id", value: owner)
                    .execute()
                report.migratedFields += migratedCount
            } catch {
                report.failedRecords += 1
                report.remainingOldVaultFields += migratedCount
                AppDiagnostics.failure("vault", "rotate_institution", error: error)
            }
        }
        return report
    }

    private enum VaultSecretMigration {
        case unchanged
        case migrated(String)
        case locked
    }

    private enum VaultRotationSecret {
        case unchanged
        case migrated(String)
        case legacyLocked
        case oldVaultLocked
    }

    private func migrateSecret(_ value: String?, using key: SymmetricKey, context: VaultFieldContext) -> VaultSecretMigration {
        guard let value, !value.isEmpty else { return .unchanged }
        if value.hasPrefix(SecurityService.vaultEnvelopePrefix) { return .unchanged }
        let plaintext: String
        if value.hasPrefix("enc:") {
            guard let decrypted = SecurityService.shared.decryptLegacyStrict(value) else { return .locked }
            plaintext = decrypted
        } else {
            plaintext = value
        }
        guard let encrypted = try? VaultCryptography.encryptField(plaintext, using: key, context: context) else {
            return .locked
        }
        return .migrated(encrypted)
    }

    private func rotateSecret(
        _ value: String?,
        snapshot: VaultKeySession.Snapshot,
        fromKeyVersion: Int,
        context: VaultFieldContext
    ) -> VaultRotationSecret {
        guard let value, !value.isEmpty else { return .unchanged }
        let plaintext: String
        if value.hasPrefix(SecurityService.vaultEnvelopePrefix) {
            guard let version = VaultCryptography.fieldKeyVersion(in: value) else { return .oldVaultLocked }
            if version == snapshot.keyVersion { return .unchanged }
            guard version == fromKeyVersion,
                  let oldKey = snapshot.key(for: version),
                  let decrypted = try? VaultCryptography.decryptField(
                    value,
                    using: oldKey,
                    context: context.withKeyVersion(version)
                  ) else { return .oldVaultLocked }
            plaintext = decrypted
        } else if value.hasPrefix("enc:") {
            guard let decrypted = SecurityService.shared.decryptLegacyStrict(value) else { return .legacyLocked }
            plaintext = decrypted
        } else {
            plaintext = value
        }
        guard let encrypted = try? VaultCryptography.encryptField(plaintext, using: snapshot.key, context: context) else {
            return .oldVaultLocked
        }
        return .migrated(encrypted)
    }
    func deleteInstitution(_ id: UUID) async throws {
        struct Request: Encodable { let institution_id: UUID }
        struct Response: Decodable {
            let success: Bool
            let institution_deleted: Bool
            let remaining_items: Int
        }

        let session = try await client.auth.session
        let payload = try JSONEncoder().encode(Request(institution_id: id))
        let options = FunctionInvokeOptions(
            method: .post,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(session.accessToken)"
            ],
            body: payload
        )

        do {
            let response: Response = try await client.functions.invoke("remove-plaid-item", options: options)
            guard response.success, response.institution_deleted, response.remaining_items == 0 else {
                throw NSError(
                    domain: "DataRepository",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "The server could not confirm that the Plaid connection was removed."]
                )
            }
        } catch let FunctionsError.httpError(code, data) {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["error"] as? String {
                throw NSError(domain: "PlaidRemoval", code: code, userInfo: [NSLocalizedDescriptionKey: message])
            }
            throw FunctionsError.httpError(code: code, data: data)
        }
    }
    
    // MARK: - Loans
    func insertLoan(_ loan: Loan) async throws {
        try await client.from("loans").insert(loan).execute()
        if let payments = loan.payments, !payments.isEmpty {
            try? await client.from("loan_payments").insert(payments).execute()
        }
    }
    func updateLoan(_ loan: Loan) async throws {
        let session = try? await client.auth.session
        let rows: [MutationReceipt] = try await client.from("loans")
            .update(loan)
            .eq("id", value: loan.id)
            .select("id")
            .execute().value
        try requireUpdatedRow(rows, resource: "loan")
        if let session, loan.userId != session.user.id {
            let log = ActivityLog(userId: loan.userId, actorEmail: session.user.email ?? "Someone", actionType: "updated_loan", message: "\(session.user.email ?? "Someone") updated the shared loan '\(loan.name)'.", resourceId: loan.id, resourceType: "loan")
            try? await insertActivityLog(log)
        }
        
        // Sync loan payments
        try? await client.from("loan_payments").delete().eq("loan_id", value: loan.id).execute()
        if let payments = loan.payments, !payments.isEmpty {
            try? await client.from("loan_payments").insert(payments).execute()
        }
    }
    func upsertLoan(_ loan: Loan) async throws {
        try await client.from("loans").upsert(loan).execute()
        try? await client.from("loan_payments").delete().eq("loan_id", value: loan.id).execute()
        if let payments = loan.payments, !payments.isEmpty {
            try? await client.from("loan_payments").insert(payments).execute()
        }
    }
    func deleteLoan(_ id: UUID) async throws {
        try? await client.from("loan_payments").delete().eq("loan_id", value: id).execute()
        try await client.from("loans").delete().eq("id", value: id).execute()
    }
    
    // MARK: - Company Documents
    func insertDocument(_ doc: CompanyDocument) async throws {
        try await client.from("company_documents").insert(doc).execute()
    }
    func updateDocument(_ doc: CompanyDocument) async throws {
        let session = try? await client.auth.session
        let rows: [MutationReceipt] = try await client.from("company_documents")
            .update(doc)
            .eq("id", value: doc.id)
            .select("id")
            .execute().value
        try requireUpdatedRow(rows, resource: "document")
        if let session, doc.userId != session.user.id {
            let log = ActivityLog(userId: doc.userId, actorEmail: session.user.email ?? "Someone", actionType: "updated_document", message: "\(session.user.email ?? "Someone") updated the shared document '\(doc.name)'.", resourceId: doc.id, resourceType: "document")
            try? await insertActivityLog(log)
        }
    }
    func deleteDocument(_ id: UUID, fileURL: String? = nil) async throws {
        // Clean up the associated file before deleting the database record
        if let fileURL = fileURL, !fileURL.isEmpty {
            if fileURL.hasPrefix("file://") || fileURL.hasPrefix("/") {
                // Local file — delete from filesystem
                let path = fileURL.hasPrefix("file://")
                    ? URL(string: fileURL)?.path ?? fileURL
                    : fileURL
                try? FileManager.default.removeItem(atPath: path)
            } else if fileURL.contains("/CompanyDocuments/") {
                // Supabase storage — extract the storage path after "CompanyDocuments/"
                if let range = fileURL.range(of: "/CompanyDocuments/") {
                    let storagePath = String(fileURL[range.upperBound...])
                    try? await client.storage
                        .from("CompanyDocuments")
                        .remove(paths: [storagePath])
                }
            }
        }
        try await client.from("company_documents").delete().eq("id", value: id).execute()
    }
    
    // MARK: - Sharing
    func inviteUser(email: String, role: String, resourceId: UUID, resourceType: String) async throws -> ShareInviteResult {
        AppDiagnostics.event("sharing", "invite_user", status: "started")
        
        guard (try? await client.auth.session.user) != nil else {
            AppDiagnostics.failure("sharing", "invite_user_session")
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in."])
        }
        
        do {
            AppDiagnostics.event("sharing", "share_resource", status: "started")
            
            struct ShareRPCParams: Encodable {
                let p_email: String
                let p_role: String
                let p_resource_id: UUID
                let p_resource_type: String
            }
            
            struct ShareRPCResponse: Decodable {
                let status: String
                let invitationId: UUID?

                enum CodingKeys: String, CodingKey {
                    case status
                    case invitationId = "invitation_id"
                }
            }
            
            let params = ShareRPCParams(
                p_email: email,
                p_role: role,
                p_resource_id: resourceId,
                p_resource_type: resourceType
            )
            
            let response: ShareRPCResponse = try await client.rpc("miloom_share_resource", params: params).execute().value
            
            if response.status == "shared_directly" {
                AppDiagnostics.event("sharing", "share_resource", status: "shared_directly")
                return .sharedDirectly
            }
            
            AppDiagnostics.event("sharing", "share_resource", status: "invitation_created")

            do {
                guard let invitationId = response.invitationId else {
                    AppDiagnostics.failure("sharing", "find_created_invitation")
                    return .invitationCreatedEmailFailed
                }

                struct ShareEmailPayload: Encodable {
                    let invitationId: UUID
                }

                let encodedPayload = try JSONEncoder().encode(ShareEmailPayload(invitationId: invitationId))
                let options = FunctionInvokeOptions(
                    method: .post,
                    headers: ["Content-Type": "application/json"],
                    body: encodedPayload
                )

                try await client.functions.invoke("send-share-email", options: options)
                AppDiagnostics.event("sharing", "send_invitation_email", status: "sent")
                return .invitationEmailSent
            } catch {
                AppDiagnostics.failure("sharing", "send_invitation_email", error: error)
                return .invitationCreatedEmailFailed
            }
        } catch {
            AppDiagnostics.failure("sharing", "share_resource", error: error)
            throw error
        }
    }

    /// Entity Admins have a separate Viewer-only server endpoint. Never route
    /// their request through the Owner's broader role-management RPC.
    func inviteViewerAsEntityAdmin(email: String, resourceId: UUID, resourceType: String) async throws -> ShareInviteResult {
        struct Params: Encodable {
            let p_email: String
            let p_resource_id: UUID
            let p_resource_type: String
        }
        struct Response: Decodable {
            let status: String
            let invitationId: UUID?

            enum CodingKeys: String, CodingKey {
                case status
                case invitationId = "invitation_id"
            }
        }

        let response: Response = try await client.rpc(
            "miloom_admin_share_viewer",
            params: Params(p_email: email, p_resource_id: resourceId, p_resource_type: resourceType)
        ).execute().value
        if response.status == "shared_directly" { return .sharedDirectly }
        guard response.status == "invitation_created", let invitationId = response.invitationId else {
            throw NSError(domain: "Sharing", code: 500, userInfo: [NSLocalizedDescriptionKey: "The Viewer invitation could not be confirmed."])
        }
        do {
            try await resendInvitation(id: invitationId)
            return .invitationEmailSent
        } catch {
            AppDiagnostics.failure("sharing", "send_admin_viewer_invitation", error: error)
            return .invitationCreatedEmailFailed
        }
    }
    
    // MARK: - Activity Logs
    func insertActivityLog(_ log: ActivityLog) async throws {
        try await client.from("activity_logs").insert(log).execute()
    }
    
    func logSecurityEvent(title: String, message: String) async {
        guard let session = try? await client.auth.session else { return }
        let log = ActivityLog(
            userId: session.user.id,
            actorEmail: session.user.email ?? "Unknown",
            actionType: "security_alert",
            message: message
        )
        try? await insertActivityLog(log)
    }
    
    func markActivityLogRead(_ logId: UUID) async throws {
        try await client.from("activity_logs").update(["is_read": true]).eq("id", value: logId).execute()
    }
    
    func markActivityLogUnread(_ logId: UUID) async throws {
        try await client.from("activity_logs").update(["is_read": false]).eq("id", value: logId).execute()
    }
    
    func markAllActivityLogsRead() async throws {
        guard let userId = try? await client.auth.session.user.id else { return }
        try await client.from("activity_logs").update(["is_read": true]).eq("user_id", value: userId).execute()
    }

    // MARK: - Notification Inbox
    func fetchNotifications() async throws -> [AppNotification] {
        try await client.from("app_notifications")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    @MainActor
    func refreshNotifications(appState: AppState) async throws {
        appState.notifications = try await fetchNotifications()
    }

    func markNotificationRead(_ notificationId: UUID, isRead: Bool = true) async throws {
        try await client.from("app_notifications")
            .update(["is_read": isRead])
            .eq("id", value: notificationId)
            .execute()
    }

    func markAllNotificationsRead() async throws {
        guard let userId = try? await client.auth.session.user.id else { return }
        try await client.from("app_notifications")
            .update(["is_read": true])
            .eq("user_id", value: userId)
            .execute()
    }
    
    func deleteActivityLog(_ logId: UUID) async throws {
        try await client.from("activity_logs").delete().eq("id", value: logId).execute()
    }
    
    func deleteActivityLogs(ids: [UUID]) async throws {
        try await client.from("activity_logs").delete().in("id", values: ids).execute()
    }
    
    // MARK: - File Storage Upload
    func uploadDocumentFile(fileData: Data, fileName: String, contentType: String) async throws -> String {
        guard let session = try? await client.auth.session else {
            throw URLError(.userAuthenticationRequired)
        }
        let userId = session.user.id
        let fileExtension = URL(fileURLWithPath: fileName).pathExtension
        let uniqueName = "\(UUID().uuidString).\(fileExtension.isEmpty ? "bin" : fileExtension)"
        let filePath = "\(userId.uuidString)/\(uniqueName)"
        
        do {
            _ = try await client.storage
                .from("CompanyDocuments")
                .upload(
                    path: filePath,
                    file: fileData,
                    options: FileOptions(cacheControl: "3600", contentType: contentType, upsert: true)
                )
            
            return filePath
        } catch {
            AppDiagnostics.failure("documents", "upload_company_document", error: error)
            // Fallback: save to app's local documents directory (just like how the scanner does it!)
            let fileManager = FileManager.default
            guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                throw error
            }
            let localURL = documentDirectory.appendingPathComponent(uniqueName)
            try fileData.write(to: localURL)
            try fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: localURL.path)
            return localURL.absoluteString
        }
    }

    func getSignedUrl(for docUrl: String) async throws -> URL {
        let storagePath: String
        if docUrl.contains("/CompanyDocuments/") {
            if let range = docUrl.range(of: "/CompanyDocuments/") {
                storagePath = String(docUrl[range.upperBound...])
            } else {
                throw URLError(.badURL)
            }
        } else {
            storagePath = docUrl
        }
        
        return try await client.storage
            .from("CompanyDocuments")
            .createSignedURL(path: storagePath, expiresIn: 60)
    }
    
    // MARK: - Managed Shared Access
    func fetchManagedResourceAccess() async throws -> [ManagedResourceAccess] {
        try await client.rpc("miloom_list_managed_access").execute().value
    }

    func fetchEntityAdminAccess(companyId: UUID) async throws -> [ManagedResourceAccess] {
        struct Params: Encodable { let p_company_id: UUID }
        return try await client.rpc(
            "miloom_admin_list_entity_access",
            params: Params(p_company_id: companyId)
        ).execute().value
    }

    func fetchBlockedCollaborators() async throws -> [BlockedCollaborator] {
        try await client.rpc("miloom_list_access_blocks").execute().value
    }

    func fetchIncomingInvitations() async throws -> [IncomingResourceInvitation] {
        try await client.rpc("miloom_list_my_invitations").execute().value
    }

    func previewInvitation(token: String) async throws -> IncomingResourceInvitation {
        struct Params: Encodable { let p_token: String }
        let invitations: [IncomingResourceInvitation] = try await client
            .rpc("miloom_preview_invitation_token", params: Params(p_token: token))
            .execute()
            .value
        guard let invitation = invitations.first else {
            throw NSError(
                domain: "Invitation",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "This invitation is unavailable or has expired."]
            )
        }
        return invitation
    }

    func acceptInvitation(id: UUID) async throws -> InvitationDecisionResult {
        struct Params: Encodable { let p_invitation_id: UUID }
        return try await client
            .rpc("miloom_accept_invitation", params: Params(p_invitation_id: id))
            .execute()
            .value
    }

    func acceptInvitation(token: String) async throws -> InvitationDecisionResult {
        struct Params: Encodable { let p_token: String }
        return try await client
            .rpc("miloom_accept_invitation_token", params: Params(p_token: token))
            .execute()
            .value
    }

    func declineInvitation(id: UUID) async throws {
        struct Params: Encodable { let p_invitation_id: UUID }
        try await client
            .rpc("miloom_decline_invitation", params: Params(p_invitation_id: id))
            .execute()
    }

    func declineInvitation(token: String) async throws {
        struct Params: Encodable { let p_token: String }
        try await client
            .rpc("miloom_decline_invitation_token", params: Params(p_token: token))
            .execute()
    }

    func resendInvitation(id: UUID) async throws {
        struct Payload: Encodable { let invitationId: UUID }
        let payload = try JSONEncoder().encode(Payload(invitationId: id))
        let options = FunctionInvokeOptions(
            method: .post,
            headers: ["Content-Type": "application/json"],
            body: payload
        )
        try await client.functions.invoke("send-share-email", options: options)
    }

    func revokeResourceAccess(
        accessId: UUID,
        accessKind: String,
        scope: AccessRevokeScope
    ) async throws {
        struct Params: Encodable {
            let p_access_id: UUID
            let p_access_kind: String
            let p_scope: String
        }

        let params = Params(
            p_access_id: accessId,
            p_access_kind: accessKind,
            p_scope: scope.rawValue
        )
        try await client.rpc("miloom_revoke_access", params: params).execute()
    }

    func revokeViewerAsEntityAdmin(accessId: UUID, accessKind: String) async throws {
        struct Params: Encodable {
            let p_access_id: UUID
            let p_access_kind: String
        }
        try await client.rpc(
            "miloom_admin_revoke_viewer",
            params: Params(p_access_id: accessId, p_access_kind: accessKind)
        ).execute()
    }

    func unblockCollaborator(blockId: UUID) async throws {
        struct Params: Encodable {
            let p_block_id: UUID
        }
        try await client.rpc("miloom_unblock_collaborator", params: Params(p_block_id: blockId)).execute()
    }
}

enum TransactionFlowOverride: String, Codable, CaseIterable, Identifiable, Hashable {
    case expense
    case income
    case transfer
    case refund
    case ignored

    var id: String { rawValue }

    var label: String {
        switch self {
        case .expense: return "Expense"
        case .income: return "Income"
        case .transfer: return "Transfer"
        case .refund: return "Refund"
        case .ignored: return "Ignore"
        }
    }
}

struct TransactionOverride: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var userId: UUID
    var transactionId: UUID
    var merchantName: String?
    var categoryPrimary: String?
    var categoryDetailed: String?
    var flowOverride: TransactionFlowOverride?
    var note: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case transactionId = "transaction_id"
        case merchantName = "merchant_name"
        case categoryPrimary = "category_primary"
        case categoryDetailed = "category_detailed"
        case flowOverride = "flow_override"
        case note
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct TransactionCategoryRule: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var userId: UUID
    var scopeKey: String
    var merchantKey: String
    var merchantName: String
    var categoryPrimary: String
    var categoryDetailed: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case scopeKey = "scope_key"
        case merchantKey = "merchant_key"
        case merchantName = "merchant_name"
        case categoryPrimary = "category_primary"
        case categoryDetailed = "category_detailed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    static func scopeKey(companyId: UUID?) -> String {
        companyId.map { "company:\($0.uuidString.lowercased())" } ?? "unassigned"
    }
}

struct Transaction: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var userId: UUID = UUID()
    var companyId: UUID? = nil
    var institutionId: UUID? = nil
    var plaidTransactionId: String? = nil
    var accountId: String = ""
    var sourceAccountId: String? = nil
    var canonicalAccountId: String? = nil
    var amount: Double? = 0.0
    var currency: String = "USD"
    var date: String = ""
    var authorizedDate: String? = nil
    var name: String? = ""
    var merchantName: String? = nil
    var merchantWebsite: String? = nil
    var merchantLogoURL: String? = nil
    var paymentChannel: String? = nil
    var personalFinancePrimary: String? = nil
    var personalFinanceDetailed: String? = nil
    var personalFinanceConfidence: String? = nil
    var category: [String]? = nil
    var pending: Bool? = false
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case companyId = "company_id"
        case institutionId = "institution_id"
        case plaidTransactionId = "plaid_transaction_id"
        case accountId = "account_id"
        case canonicalAccountId = "canonical_account_id"
        case amount
        case currency
        case date
        case authorizedDate = "authorized_date"
        case name
        case merchantName = "merchant_name"
        case merchantWebsite = "merchant_website"
        case merchantLogoURL = "merchant_logo_url"
        case paymentChannel = "payment_channel"
        case personalFinancePrimary = "personal_finance_primary"
        case personalFinanceDetailed = "personal_finance_detailed"
        case personalFinanceConfidence = "personal_finance_confidence"
        case category
        case pending
    }
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle ID gracefully (could be Int or UUID or String)
        if let uuid = try? container.decodeIfPresent(UUID.self, forKey: .id) {
            self.id = uuid
        } else if let intId = try? container.decodeIfPresent(Int.self, forKey: .id) {
            self.id = UUID() // Generate a new UUID if it's an int ID
        } else if let strId = try? container.decodeIfPresent(String.self, forKey: .id), let parsed = UUID(uuidString: strId) {
            self.id = parsed
        } else {
            self.id = UUID()
        }
        
        self.userId = try container.decodeIfPresent(UUID.self, forKey: .userId) ?? UUID()
        self.companyId = try container.decodeIfPresent(UUID.self, forKey: .companyId)
        self.institutionId = try container.decodeIfPresent(UUID.self, forKey: .institutionId)
        self.plaidTransactionId = try container.decodeIfPresent(String.self, forKey: .plaidTransactionId)
        let sourceAccountId = try container.decodeIfPresent(String.self, forKey: .accountId) ?? ""
        self.sourceAccountId = sourceAccountId
        self.canonicalAccountId = try container.decodeIfPresent(String.self, forKey: .canonicalAccountId)
        if let canonicalAccountId, !canonicalAccountId.isEmpty {
            self.accountId = canonicalAccountId
        } else {
            self.accountId = sourceAccountId
        }
        self.amount = try container.decodeIfPresent(Double.self, forKey: .amount)
        self.currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "USD"
        self.date = try container.decodeIfPresent(String.self, forKey: .date) ?? ""
        self.authorizedDate = try container.decodeIfPresent(String.self, forKey: .authorizedDate)
        self.name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? "Unknown"
        self.merchantName = try container.decodeIfPresent(String.self, forKey: .merchantName)
        self.merchantWebsite = try container.decodeIfPresent(String.self, forKey: .merchantWebsite)
        self.merchantLogoURL = try container.decodeIfPresent(String.self, forKey: .merchantLogoURL)
        self.paymentChannel = try container.decodeIfPresent(String.self, forKey: .paymentChannel)
        self.personalFinancePrimary = try container.decodeIfPresent(String.self, forKey: .personalFinancePrimary)
        self.personalFinanceDetailed = try container.decodeIfPresent(String.self, forKey: .personalFinanceDetailed)
        self.personalFinanceConfidence = try container.decodeIfPresent(String.self, forKey: .personalFinanceConfidence)
        self.category = try container.decodeIfPresent([String].self, forKey: .category)
        self.pending = try container.decodeIfPresent(Bool.self, forKey: .pending)
    }
}

final class SecurityService {
    static let shared = SecurityService()
    static let lockedValueLabel = "Locked on this device"
    static let vaultEnvelopePrefix = "miloom:v1:"
    
    private let keyTag = "com.zifr.encryptionKey"
    private var symmetricKey: SymmetricKey?
    
    private init() {
        self.symmetricKey = loadOrGenerateKey()
    }
    
    private func loadOrGenerateKey() -> SymmetricKey {
        // Try to load existing key from Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyTag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecSuccess, let keyData = item as? Data {
            return SymmetricKey(data: keyData)
        }
        
        // Generate new key
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data(Array($0)) }
        
        // Save to Keychain
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyTag,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        SecItemAdd(addQuery as CFDictionary, nil)
        return newKey
    }
    
    func encrypt(_ string: String?) -> String? {
        Self.encryptValue(string, using: symmetricKey)
    }

    func encrypt(_ string: String?, context: VaultFieldContext?) -> String? {
        guard let string, !string.isEmpty else { return string }
        guard !Self.isLockedValue(string) else { return string }
        guard let context,
              let snapshot = VaultKeySession.shared.snapshot(for: context.ownerUserID),
              snapshot.keyVersion == context.keyVersion else {
            return encrypt(string)
        }
        return (try? VaultCryptography.encryptField(string, using: snapshot.key, context: context)) ?? string
    }

    func decrypt(_ string: String?) -> String? {
        let value = Self.decryptValue(string, using: symmetricKey)
        if Self.isLockedValue(value) {
            // Do not print the payload or crypto error. Returning the original
            // encrypted value preserves it through an unchanged edit/save.
            AppDiagnostics.event("encryption", "decrypt_protected_value", status: "locked")
        }
        return value
    }

    func decrypt(_ string: String?, context: VaultFieldContext?) -> String? {
        guard let string else { return nil }
        if string.hasPrefix(Self.vaultEnvelopePrefix) {
            guard let context,
                  let snapshot = VaultKeySession.shared.snapshot(for: context.ownerUserID),
                  let embeddedVersion = VaultCryptography.fieldKeyVersion(in: string),
                  let key = snapshot.key(for: embeddedVersion),
                  let value = try? VaultCryptography.decryptField(
                    string,
                    using: key,
                    context: context.withKeyVersion(embeddedVersion)
                  ) else {
                AppDiagnostics.event("encryption", "decrypt_vault_value", status: "locked")
                return string
            }
            return value
        }
        return decrypt(string)
    }

    static func isLockedValue(_ string: String?) -> Bool {
        guard let string else { return false }
        return string.hasPrefix("enc:") || string.hasPrefix(vaultEnvelopePrefix)
    }

    static func editableValue(_ string: String?) -> String {
        isLockedValue(string) ? "" : (string ?? "")
    }

    static func encryptValue(_ string: String?, using key: SymmetricKey?) -> String? {
        guard let string, !string.isEmpty, let key else { return string }
        guard !isLockedValue(string) else { return string }

        do {
            let sealedBox = try AES.GCM.seal(Data(string.utf8), using: key)
            guard let combined = sealedBox.combined else { return string }
            return "enc:" + combined.base64EncodedString()
        } catch {
            return string
        }
    }

    static func decryptValue(_ string: String?, using key: SymmetricKey?) -> String? {
        guard let string, string.hasPrefix("enc:"), let key else { return string }
        let base64 = String(string.dropFirst(4))
        guard let combined = Data(base64Encoded: base64) else { return string }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: combined)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return String(data: decryptedData, encoding: .utf8) ?? string
        } catch {
            return string
        }
    }

    func decryptLegacyStrict(_ string: String) -> String? {
        guard string.hasPrefix("enc:"), let key = symmetricKey else { return nil }
        let decrypted = Self.decryptValue(string, using: key)
        return decrypted == string ? nil : decrypted
    }
}

final class VaultKeySession: @unchecked Sendable {
    static let shared = VaultKeySession()

    struct Snapshot {
        let userID: UUID
        let deviceID: UUID
        let keyVersion: Int
        let key: SymmetricKey
        let keys: [Int: SymmetricKey]

        func key(for version: Int) -> SymmetricKey? { keys[version] }
    }

    private let lock = NSLock()
    private var current: Snapshot?

    private init() {}

    func install(userID: UUID, deviceID: UUID, keyVersion: Int, key: SymmetricKey) {
        install(userID: userID, deviceID: deviceID, currentKeyVersion: keyVersion, keys: [keyVersion: key])
    }

    func install(userID: UUID, deviceID: UUID, currentKeyVersion: Int, keys: [Int: SymmetricKey]) {
        guard let currentKey = keys[currentKeyVersion] else { return }
        lock.lock()
        current = Snapshot(
            userID: userID,
            deviceID: deviceID,
            keyVersion: currentKeyVersion,
            key: currentKey,
            keys: keys
        )
        lock.unlock()
    }

    func snapshot(for userID: UUID) -> Snapshot? {
        lock.lock()
        defer { lock.unlock() }
        guard current?.userID == userID else { return nil }
        return current
    }

    func clear() {
        lock.lock()
        current = nil
        lock.unlock()
    }
}

struct VaultAccountMetadata: Decodable {
    let userID: UUID
    let currentKeyVersion: Int
    let rotationStatus: String?
    let previousKeyVersion: Int?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case currentKeyVersion = "current_key_version"
        case rotationStatus = "rotation_status"
        case previousKeyVersion = "previous_key_version"
    }
}

struct VaultDeviceRecord: Decodable, Identifiable, Equatable {
    let deviceID: UUID
    let label: String
    let platform: String
    let agreementPublicKey: String
    let signingPublicKey: String
    let status: String
    let createdAt: Date?
    let approvedAt: Date?
    let revokedAt: Date?
    let lastSeenAt: Date?

    var id: UUID { deviceID }

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case label, platform, status
        case agreementPublicKey = "agreement_public_key"
        case signingPublicKey = "signing_public_key"
        case createdAt = "created_at"
        case approvedAt = "approved_at"
        case revokedAt = "revoked_at"
        case lastSeenAt = "last_seen_at"
    }
}

struct VaultDeviceWrapRecord: Decodable {
    let deviceID: UUID
    let keyVersion: Int
    let ephemeralPublicKey: String
    let wrappedKey: String

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case keyVersion = "key_version"
        case ephemeralPublicKey = "ephemeral_public_key"
        case wrappedKey = "wrapped_key"
    }
}

struct VaultRecoveryWrapRecord: Decodable {
    let keyVersion: Int
    let wrappedKey: String

    enum CodingKeys: String, CodingKey {
        case keyVersion = "key_version"
        case wrappedKey = "wrapped_key"
    }
}

struct VaultKeyTransitionRecord: Decodable {
    let fromKeyVersion: Int
    let toKeyVersion: Int
    let wrappedPreviousKey: String

    enum CodingKeys: String, CodingKey {
        case fromKeyVersion = "from_key_version"
        case toKeyVersion = "to_key_version"
        case wrappedPreviousKey = "wrapped_previous_key"
    }
}

private struct ResourceSecretOwnerWrapRecord: Decodable {
    let resourceType: String
    let resourceID: UUID
    let keyVersion: Int
    let ownerAccountKeyVersion: Int
    let ownerWrappedResourceKey: String

    enum CodingKeys: String, CodingKey {
        case resourceType = "resource_type"
        case resourceID = "resource_id"
        case keyVersion = "key_version"
        case ownerAccountKeyVersion = "owner_account_key_version"
        case ownerWrappedResourceKey = "owner_wrapped_resource_key"
    }
}

struct ResourceSecretAccessRequest: Decodable, Identifiable, Equatable {
    let requestID: UUID
    let resourceType: String
    let resourceID: UUID
    let keyVersion: Int
    let resourceTitle: String?
    let companyName: String
    let recipientUserID: UUID
    let recipientEmail: String
    let recipientDeviceID: UUID
    let recipientDeviceLabel: String
    let agreementPublicKey: String
    let requestedAt: Date

    var id: UUID { requestID }

    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case resourceType = "resource_type"
        case resourceID = "resource_id"
        case keyVersion = "key_version"
        case resourceTitle = "resource_title"
        case companyName = "company_name"
        case recipientUserID = "recipient_user_id"
        case recipientEmail = "recipient_email"
        case recipientDeviceID = "recipient_device_id"
        case recipientDeviceLabel = "recipient_device_label"
        case agreementPublicKey = "agreement_public_key"
        case requestedAt = "requested_at"
    }
}

struct LockedResourceSecret: Decodable, Identifiable, Equatable {
    let resourceType: String
    let resourceID: UUID
    let keyVersion: Int
    let resourceTitle: String?
    let companyName: String

    var id: String { "\(resourceType):\(resourceID.uuidString):\(keyVersion)" }

    enum CodingKeys: String, CodingKey {
        case resourceType = "resource_type"
        case resourceID = "resource_id"
        case keyVersion = "key_version"
        case resourceTitle = "resource_title"
        case companyName = "company_name"
    }
}

enum ResourceSecretRotationError: LocalizedError {
    case staleResource
    case invalidSecret
    case verificationFailed
    case postActivationVerificationUnavailable

    var errorDescription: String? {
        switch self {
        case .staleResource:
            return "This credential changed. Refresh Password Vault and try again."
        case .invalidSecret:
            return "The locked credential couldn't be verified. It was not replaced."
        case .verificationFailed:
            return "The replacement credential couldn't be verified. Access remains locked."
        case .postActivationVerificationUnavailable:
            return "The server accepted the new key, but this device couldn't confirm the final readback. Refresh Password Vault before trying again."
        }
    }
}

private struct OwnerResourceSecretRecord: Decodable {
    let resourceType: String
    let resourceID: UUID
    let keyVersion: Int
    let ownerAccountKeyVersion: Int
    let ownerWrappedResourceKey: String
    let encryptedFields: [String: String]
    let state: String
    let sourceSecretRevision: Int64?
    let currentSecretRevision: Int64?

    enum CodingKeys: String, CodingKey {
        case resourceType = "resource_type"
        case resourceID = "resource_id"
        case keyVersion = "key_version"
        case ownerAccountKeyVersion = "owner_account_key_version"
        case ownerWrappedResourceKey = "owner_wrapped_resource_key"
        case encryptedFields = "encrypted_fields"
        case state
        case sourceSecretRevision = "source_secret_revision"
        case currentSecretRevision = "current_secret_revision"
    }
}

struct DeviceResourceSecretRecord: Decodable {
    let ownerUserID: UUID
    let resourceType: String
    let resourceID: UUID
    let keyVersion: Int
    let encryptedFields: [String: String]
    let ephemeralPublicKey: String
    let wrappedResourceKey: String

    enum CodingKeys: String, CodingKey {
        case ownerUserID = "owner_user_id"
        case resourceType = "resource_type"
        case resourceID = "resource_id"
        case keyVersion = "key_version"
        case encryptedFields = "encrypted_fields"
        case ephemeralPublicKey = "ephemeral_public_key"
        case wrappedResourceKey = "wrapped_resource_key"
    }
}

struct ResourceSecretAccessStatus: Decodable {
    let status: String
}

enum ResourceSecretRevealError: LocalizedError {
    case deviceNeedsApproval
    case unavailable
    case invalidSecret

    var errorDescription: String? {
        switch self {
        case .deviceNeedsApproval:
            return "This device needs vault approval before it can request credentials."
        case .unavailable:
            return "These credentials are not available on this device. Access may need owner approval or key rotation."
        case .invalidSecret:
            return "Miloom couldn't verify these encrypted credentials. Nothing was revealed."
        }
    }
}

enum ResourceSecretUpdateError: LocalizedError {
    case invalidFields
    case verificationUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidFields:
            return "These credential fields could not be saved safely. Nothing was changed."
        case .verificationUnavailable:
            return "The server accepted the change, but this device couldn't confirm the readback. Refresh this resource before trying again."
        }
    }
}

enum ResourceSecretGrantError: LocalizedError {
    case confirmationUnavailable
    case confirmationCancelled
    case staleRequest
    case invalidSecret

    var errorDescription: String? {
        switch self {
        case .confirmationUnavailable:
            return "Face ID or your device passcode is required to approve credential access."
        case .confirmationCancelled:
            return "Approval was cancelled. No credential key was granted."
        case .staleRequest:
            return "This request changed or is no longer valid. Refresh the vault before approving."
        case .invalidSecret:
            return "Miloom couldn't verify the encrypted credentials. No key was granted."
        }
    }
}

struct ResourceSecretPreparationCandidate {
    let resourceType: String
    let resourceID: UUID
    let plaintextFields: [String: String]
}

struct ResourceSecretPreparationReport {
    var preparedRecords = 0
    var alreadyPreparedRecords = 0
    var skippedLockedRecords = 0
    var skippedEmptyRecords = 0
    var failedRecords = 0
    var deferredRecords = 0
}

struct ResourceSecretCandidateCollection {
    var candidates: [ResourceSecretPreparationCandidate] = []
    var skippedLockedRecords = 0
    var skippedEmptyRecords = 0
    var failedRecords = 0

    mutating func append(_ build: () throws -> ResourceSecretPreparationCandidate?) {
        do {
            if let candidate = try build() {
                candidates.append(candidate)
            } else {
                skippedEmptyRecords += 1
            }
        } catch ResourceSecretPreparationError.lockedValue {
            skippedLockedRecords += 1
        } catch {
            failedRecords += 1
            AppDiagnostics.failure("vault", "prepare_resource_candidate", error: error)
        }
    }
}

enum ResourceSecretPreparationError: Error {
    case lockedValue
    case activeResource
    case verificationFailed
}

private struct ResourceBankAccountCredentials: Codable, Equatable {
    let id: String
    let accountNumber: String?
    let routingNumber: String?
    let wireRoutingNumber: String?
}

enum ResourceSecretPreparation {
    // Never re-encrypt an unreadable legacy envelope as if its literal bytes
    // were a password. Leave the entire resource unchanged for owner review.
    static func verifiedPlaintext(
        _ value: String?, snapshot: VaultKeySession.Snapshot,
        storedResourceType: String, resourceID: UUID, fieldName: String
    ) throws -> String? {
        guard let value, !value.isEmpty else { return nil }
        if value.hasPrefix("miloom:") {
            guard let version = VaultCryptography.fieldKeyVersion(in: value),
                  let key = snapshot.key(for: version) else {
                throw ResourceSecretPreparationError.lockedValue
            }
            let context = VaultFieldContext(
                ownerUserID: snapshot.userID, resourceType: storedResourceType,
                resourceID: resourceID, fieldName: fieldName, keyVersion: version
            )
            guard let plaintext = try? VaultCryptography.decryptField(
                value, using: key, context: context
            ) else { throw ResourceSecretPreparationError.lockedValue }
            return plaintext
        }
        if value.hasPrefix("enc:") {
            guard let plaintext = SecurityService.shared.decryptLegacyStrict(value) else {
                throw ResourceSecretPreparationError.lockedValue
            }
            return plaintext
        }
        if value.hasPrefix("miloom-resource:") {
            throw ResourceSecretPreparationError.lockedValue
        }
        return value
    }

    static func candidate(
        for subscription: Subscription, snapshot: VaultKeySession.Snapshot
    ) throws -> ResourceSecretPreparationCandidate? {
        var fields: [String: String] = [:]
        func include(_ name: String, _ value: String?) throws {
            if let plaintext = try verifiedPlaintext(
                value, snapshot: snapshot, storedResourceType: "subscription",
                resourceID: subscription.id, fieldName: name
            ) { fields[name] = plaintext }
        }
        try include("login_id", subscription.loginId)
        try include("password", subscription.password)
        if subscription.twoFactorAuth != "None" {
            try include("two_factor_auth", subscription.twoFactorAuth)
        }
        try include("recovery_method", subscription.recoveryMethod)
        guard !fields.isEmpty else { return nil }
        return ResourceSecretPreparationCandidate(
            resourceType: "subscription", resourceID: subscription.id, plaintextFields: fields
        )
    }

    static func candidate(
        for card: FinancialCard, snapshot: VaultKeySession.Snapshot
    ) throws -> ResourceSecretPreparationCandidate? {
        var fields: [String: String] = [:]
        func include(_ name: String, _ value: String?, storedField: String? = nil) throws {
            if let plaintext = try verifiedPlaintext(
                value, snapshot: snapshot, storedResourceType: "financial_card",
                resourceID: card.id, fieldName: storedField ?? name
            ) { fields[name] = plaintext }
        }
        try include("login", card.login)
        try include("password", card.password)
        try include("card_number", card.cardNumber, storedField: "card_number")
        try include("expiry", card.expiry)
        guard !fields.isEmpty else { return nil }
        return ResourceSecretPreparationCandidate(
            resourceType: "card", resourceID: card.id, plaintextFields: fields
        )
    }

    static func candidate(
        for institution: Institution, snapshot: VaultKeySession.Snapshot
    ) throws -> ResourceSecretPreparationCandidate? {
        var fields: [String: String] = [:]
        func include(_ name: String, _ value: String?) throws {
            if let plaintext = try verifiedPlaintext(
                value, snapshot: snapshot, storedResourceType: "institution",
                resourceID: institution.id, fieldName: name
            ) { fields[name] = plaintext }
        }
        try include("login_url", institution.loginUrl)
        try include("username", institution.username)
        try include("email", institution.email)
        try include("password", institution.password)
        try include("two_factor", institution.twoFactor)

        var accountCredentials: [ResourceBankAccountCredentials] = []
        for account in institution.accounts {
            let prefix = "accounts.\(account.id)"
            let accountNumber = try verifiedPlaintext(
                account.accountNumber, snapshot: snapshot,
                storedResourceType: "institution", resourceID: institution.id,
                fieldName: "\(prefix).account_number"
            )
            let routingNumber = try verifiedPlaintext(
                account.routingNumber, snapshot: snapshot,
                storedResourceType: "institution", resourceID: institution.id,
                fieldName: "\(prefix).routing_number"
            )
            let wireRoutingNumber = try verifiedPlaintext(
                account.wireRoutingNumber, snapshot: snapshot,
                storedResourceType: "institution", resourceID: institution.id,
                fieldName: "\(prefix).wire_routing_number"
            )
            if accountNumber != nil || routingNumber != nil || wireRoutingNumber != nil {
                accountCredentials.append(ResourceBankAccountCredentials(
                    id: account.id, accountNumber: accountNumber,
                    routingNumber: routingNumber, wireRoutingNumber: wireRoutingNumber
                ))
            }
        }
        if !accountCredentials.isEmpty {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            fields["accounts_data"] = String(
                decoding: try encoder.encode(accountCredentials), as: UTF8.self
            )
        }
        guard !fields.isEmpty else { return nil }
        return ResourceSecretPreparationCandidate(
            resourceType: "institution", resourceID: institution.id, plaintextFields: fields
        )
    }
}

struct VaultAuditEventRecord: Decodable, Identifiable {
    let id: UUID
    let actorDeviceID: UUID?
    let targetDeviceID: UUID?
    let eventType: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case actorDeviceID = "actor_device_id"
        case targetDeviceID = "target_device_id"
        case eventType = "event_type"
        case createdAt = "created_at"
    }
}

struct VaultOverview {
    let metadata: VaultAccountMetadata?
    let devices: [VaultDeviceRecord]
    let currentDevice: VaultDeviceRecord?
    let isUnlocked: Bool
    let auditEvents: [VaultAuditEventRecord]
}

struct VaultMigrationReport: Equatable {
    var migratedFields = 0
    var skippedLockedFields = 0
    var failedRecords = 0
    var remainingOldVaultFields = 0
}

struct VaultRotationResult {
    let recoveryCode: String
    let report: VaultMigrationReport
    let completed: Bool
}

final class VaultService: @unchecked Sendable {
    static let shared = VaultService()

    private var client: SupabaseClient { SupabaseService.shared.client }

    private init() {}

    func restoreSessionIfAvailable(for userID: UUID) async {
        if VaultKeySession.shared.snapshot(for: userID) != nil { return }

        do {
            let identity = try VaultDeviceKeyStore.shared.loadOrCreateIdentity(for: userID)
            let devices = try await listDevices()
            guard let device = currentDevice(in: devices, identity: identity), device.status == "approved" else { return }
            let wraps: [VaultDeviceWrapRecord] = try await client
                .rpc("miloom_get_vault_device_wrap", params: ["p_device_id": device.deviceID.uuidString])
                .execute().value
            guard let wrap = wraps.first else { return }
            let envelope = VaultDeviceKeyWrapEnvelope(
                version: 1,
                keyVersion: wrap.keyVersion,
                ephemeralPublicKey: wrap.ephemeralPublicKey,
                wrappedKey: wrap.wrappedKey
            )
            let key = try VaultCryptography.unwrapVaultKey(
                envelope,
                using: identity.agreementPrivateKey,
                context: VaultKeyWrapContext(ownerUserID: userID, recipientDeviceID: device.deviceID, keyVersion: wrap.keyVersion)
            )
            var keys = [wrap.keyVersion: key]
            let transitions: [VaultKeyTransitionRecord] = try await client
                .from("vault_key_transitions")
                .select("from_key_version,to_key_version,wrapped_previous_key")
                .eq("user_id", value: userID)
                .eq("to_key_version", value: wrap.keyVersion)
                .is("completed_at", value: nil)
                .execute().value
            for transition in transitions {
                let previous = try VaultCryptography.unwrapPreviousVaultKey(
                    transition.wrappedPreviousKey,
                    using: key,
                    context: VaultKeyTransitionContext(
                        ownerUserID: userID,
                        fromKeyVersion: transition.fromKeyVersion,
                        toKeyVersion: transition.toKeyVersion
                    )
                )
                keys[transition.fromKeyVersion] = previous
            }
            VaultKeySession.shared.install(
                userID: userID,
                deviceID: device.deviceID,
                currentKeyVersion: wrap.keyVersion,
                keys: keys
            )
            try await bindCurrentSession(
                deviceID: device.deviceID,
                key: key
            )
        } catch {
            AppDiagnostics.failure("vault", "restore_device_key", error: error)
        }
    }

    func overview() async throws -> VaultOverview {
        let session = try await client.auth.session
        let userID = session.user.id
        let metadata: [VaultAccountMetadata] = try await client
            .from("account_vaults")
            .select("user_id,current_key_version,rotation_status,previous_key_version")
            .eq("user_id", value: userID)
            .limit(1)
            .execute().value
        guard metadata.first != nil else {
            VaultKeySession.shared.clear()
            return VaultOverview(metadata: nil, devices: [], currentDevice: nil, isUnlocked: false, auditEvents: [])
        }
        let identity = try VaultDeviceKeyStore.shared.loadOrCreateIdentity(for: userID)
        let devices = try await listDevices()
        await restoreSessionIfAvailable(for: userID)
        let current = currentDevice(in: devices, identity: identity)
        let auditEvents: [VaultAuditEventRecord] = try await client
            .from("vault_audit_events")
            .select("id,actor_device_id,target_device_id,event_type,created_at")
            .eq("user_id", value: userID)
            .order("created_at", ascending: false)
            .limit(20)
            .execute().value
        return VaultOverview(
            metadata: metadata.first,
            devices: devices,
            currentDevice: current,
            isUnlocked: VaultKeySession.shared.snapshot(for: userID) != nil,
            auditEvents: auditEvents
        )
    }

    func bootstrap() async throws -> String {
        let session = try await client.auth.refreshSession()
        let userID = session.user.id
        let identity = try VaultDeviceKeyStore.shared.loadOrCreateIdentity(for: userID)
        let deviceID = UUID()
        let keyVersion = 1
        let vaultKey = SymmetricKey(size: .bits256)
        let recoveryCode = try VaultCryptography.generateRecoveryCode()
        let deviceEnvelope = try VaultCryptography.wrapVaultKey(
            vaultKey,
            for: identity.publicKeys.agreementPublicKey,
            context: VaultKeyWrapContext(ownerUserID: userID, recipientDeviceID: deviceID, keyVersion: keyVersion)
        )
        let recoveryEnvelope = try VaultCryptography.wrapVaultKeyForRecovery(
            vaultKey,
            recoveryCode: recoveryCode,
            context: VaultRecoveryWrapContext(ownerUserID: userID, keyVersion: keyVersion)
        )
        let confirmation = VaultCryptography.keyConfirmation(for: vaultKey)

        struct Params: Encodable {
            let p_device_id: UUID
            let p_device_label: String
            let p_platform: String
            let p_agreement_public_key: String
            let p_signing_public_key: String
            let p_ephemeral_public_key: String
            let p_wrapped_vault_key: String
            let p_wrapped_recovery_key: String
            let p_key_confirmation: String
        }
        let params = Params(
            p_device_id: deviceID,
            p_device_label: deviceLabel,
            p_platform: "ios",
            p_agreement_public_key: identity.publicKeys.agreementPublicKey,
            p_signing_public_key: identity.publicKeys.signingPublicKey,
            p_ephemeral_public_key: deviceEnvelope.ephemeralPublicKey,
            p_wrapped_vault_key: deviceEnvelope.wrappedKey,
            p_wrapped_recovery_key: recoveryEnvelope.wrappedKey,
            p_key_confirmation: confirmation
        )
        try await client.rpc("miloom_bootstrap_account_vault_v2", params: params).execute()
        VaultKeySession.shared.install(userID: userID, deviceID: deviceID, keyVersion: keyVersion, key: vaultKey)
        try await bindCurrentSession(deviceID: deviceID, key: vaultKey)
        return recoveryCode
    }

    func registerCurrentDevice() async throws {
        let session = try await client.auth.refreshSession()
        let identity = try VaultDeviceKeyStore.shared.loadOrCreateIdentity(for: session.user.id)
        let devices = try await listDevices()
        if let device = currentDevice(in: devices, identity: identity), device.status != "revoked" {
            return
        }
        struct Params: Encodable {
            let p_device_label: String
            let p_platform: String
            let p_agreement_public_key: String
            let p_signing_public_key: String
        }
        try await client.rpc("miloom_register_vault_device", params: Params(
            p_device_label: deviceLabel,
            p_platform: "ios",
            p_agreement_public_key: identity.publicKeys.agreementPublicKey,
            p_signing_public_key: identity.publicKeys.signingPublicKey
        )).execute()
    }

    func approve(device target: VaultDeviceRecord) async throws {
        let session = try await client.auth.refreshSession()
        let userID = session.user.id
        guard let snapshot = VaultKeySession.shared.snapshot(for: userID) else {
            throw VaultCryptographyError.authenticationFailed
        }
        let identity = try VaultDeviceKeyStore.shared.loadOrCreateIdentity(for: userID)
        let devices = try await listDevices()
        guard let actor = currentDevice(in: devices, identity: identity), actor.status == "approved",
              target.status == "pending" else {
            throw VaultCryptographyError.authenticationFailed
        }
        let envelope = try VaultCryptography.wrapVaultKey(
            snapshot.key,
            for: target.agreementPublicKey,
            context: VaultKeyWrapContext(ownerUserID: userID, recipientDeviceID: target.deviceID, keyVersion: snapshot.keyVersion)
        )
        struct ChallengeParams: Encodable {
            let p_actor_device_id: UUID
            let p_target_device_id: UUID
        }
        struct Challenge: Decodable {
            let challengeID: UUID
            let nonce: String
            let keyVersion: Int
            enum CodingKeys: String, CodingKey {
                case challengeID = "challenge_id"
                case nonce
                case keyVersion = "key_version"
            }
        }
        let challenge: Challenge = try await client.rpc(
            "miloom_create_vault_approval_challenge",
            params: ChallengeParams(p_actor_device_id: actor.deviceID, p_target_device_id: target.deviceID)
        ).execute().value
        let payload = VaultCryptography.approvalChallenge(
            userID: userID,
            challengeID: challenge.challengeID,
            actorDeviceID: actor.deviceID,
            targetDeviceID: target.deviceID,
            keyVersion: challenge.keyVersion,
            nonce: challenge.nonce,
            ephemeralPublicKey: envelope.ephemeralPublicKey,
            wrappedVaultKey: envelope.wrappedKey
        )
        let signature = try VaultCryptography.sign(payload, using: identity).base64EncodedString()
        struct ApprovalBody: Encodable {
            let challenge_id: UUID
            let actor_device_id: UUID
            let target_device_id: UUID
            let key_version: Int
            let signature: String
            let ephemeral_public_key: String
            let wrapped_vault_key: String
        }
        let body = try JSONEncoder().encode(ApprovalBody(
            challenge_id: challenge.challengeID,
            actor_device_id: actor.deviceID,
            target_device_id: target.deviceID,
            key_version: challenge.keyVersion,
            signature: signature,
            ephemeral_public_key: envelope.ephemeralPublicKey,
            wrapped_vault_key: envelope.wrappedKey
        ))
        let options = FunctionInvokeOptions(
            method: .post,
            headers: ["Content-Type": "application/json", "Authorization": "Bearer \(session.accessToken)"],
            body: body
        )
        do {
            try await client.functions.invoke("approve-vault-device", options: options)
        } catch let FunctionsError.httpError(code, data) {
            let reason = Self.approvalFailureReason(from: data)
            AppDiagnostics.serviceFailure("vault", "approve_device", statusCode: code, reason: reason)
            throw VaultApprovalServiceError.remote(statusCode: code, reason: reason)
        } catch FunctionsError.relayError {
            AppDiagnostics.serviceFailure("vault", "approve_device", statusCode: 0, reason: "RELAY_UNAVAILABLE")
            throw VaultApprovalServiceError.relayUnavailable
        }
    }

    func recoverCurrentDevice(code: String) async throws {
        let session = try await client.auth.refreshSession()
        let userID = session.user.id
        let identity = try VaultDeviceKeyStore.shared.loadOrCreateIdentity(for: userID)
        var devices = try await listDevices()
        let localDevice = currentDevice(in: devices, identity: identity)
        if localDevice == nil || localDevice?.status == "revoked" {
            try await registerCurrentDevice()
            devices = try await listDevices()
        }
        guard let device = currentDevice(in: devices, identity: identity), device.status == "pending" else {
            throw VaultCryptographyError.authenticationFailed
        }
        let metadata: [VaultAccountMetadata] = try await client
            .from("account_vaults").select("user_id,current_key_version,rotation_status,previous_key_version")
            .eq("user_id", value: userID).limit(1).execute().value
        guard let vault = metadata.first else { throw VaultCryptographyError.invalidEnvelope }
        let wraps: [VaultRecoveryWrapRecord] = try await client
            .from("vault_recovery_key_wraps")
            .select("key_version,wrapped_key")
            .eq("user_id", value: userID)
            .eq("key_version", value: vault.currentKeyVersion)
            .is("revoked_at", value: nil)
            .limit(1).execute().value
        guard let wrap = wraps.first else { throw VaultCryptographyError.invalidEnvelope }
        let vaultKey = try VaultCryptography.unwrapVaultKeyFromRecovery(
            VaultRecoveryKeyWrapEnvelope(version: 1, keyVersion: wrap.keyVersion, wrappedKey: wrap.wrappedKey),
            recoveryCode: code.trimmingCharacters(in: .whitespacesAndNewlines),
            context: VaultRecoveryWrapContext(ownerUserID: userID, keyVersion: wrap.keyVersion)
        )
        let deviceEnvelope = try VaultCryptography.wrapVaultKey(
            vaultKey,
            for: identity.publicKeys.agreementPublicKey,
            context: VaultKeyWrapContext(ownerUserID: userID, recipientDeviceID: device.deviceID, keyVersion: wrap.keyVersion)
        )
        struct Params: Encodable {
            let p_device_id: UUID
            let p_key_version: Int
            let p_ephemeral_public_key: String
            let p_wrapped_vault_key: String
            let p_key_confirmation: String
        }
        try await client.rpc("miloom_recover_vault_device", params: Params(
            p_device_id: device.deviceID,
            p_key_version: wrap.keyVersion,
            p_ephemeral_public_key: deviceEnvelope.ephemeralPublicKey,
            p_wrapped_vault_key: deviceEnvelope.wrappedKey,
            p_key_confirmation: VaultCryptography.keyConfirmation(for: vaultKey)
        )).execute()
        VaultKeySession.shared.install(userID: userID, deviceID: device.deviceID, keyVersion: wrap.keyVersion, key: vaultKey)
        try await bindCurrentSession(deviceID: device.deviceID, key: vaultKey)
        // A recovery can occur while a revocation rotation is still migrating.
        // Reload so the encrypted transition also restores the previous key.
        VaultKeySession.shared.clear()
        await restoreSessionIfAvailable(for: userID)
        _ = try requireSnapshot(for: userID)
    }

    func revokeAndRotate(device target: VaultDeviceRecord) async throws -> VaultRotationResult {
        let session = try await client.auth.refreshSession()
        let userID = session.user.id
        guard target.status == "approved",
              let snapshot = VaultKeySession.shared.snapshot(for: userID),
              target.deviceID != snapshot.deviceID else {
            throw VaultCryptographyError.authenticationFailed
        }
        let devices = try await listDevices()
        guard devices.contains(where: { $0.deviceID == target.deviceID && $0.status == "approved" }) else {
            throw VaultCryptographyError.authenticationFailed
        }
        let remaining = devices.filter { $0.status == "approved" && $0.deviceID != target.deviceID }
        guard remaining.contains(where: { $0.deviceID == snapshot.deviceID }) else {
            throw VaultCryptographyError.authenticationFailed
        }

        let newVersion = snapshot.keyVersion + 1
        let newKey = SymmetricKey(size: .bits256)
        struct DeviceWrap: Encodable {
            let device_id: UUID
            let ephemeral_public_key: String
            let wrapped_key: String
        }
        var deviceWraps: [DeviceWrap] = []
        for device in remaining {
            let envelope = try VaultCryptography.wrapVaultKey(
                newKey,
                for: device.agreementPublicKey,
                context: VaultKeyWrapContext(ownerUserID: userID, recipientDeviceID: device.deviceID, keyVersion: newVersion)
            )
            deviceWraps.append(DeviceWrap(
                device_id: device.deviceID,
                ephemeral_public_key: envelope.ephemeralPublicKey,
                wrapped_key: envelope.wrappedKey
            ))
        }
        let recoveryCode = try VaultCryptography.generateRecoveryCode()
        let recovery = try VaultCryptography.wrapVaultKeyForRecovery(
            newKey,
            recoveryCode: recoveryCode,
            context: VaultRecoveryWrapContext(ownerUserID: userID, keyVersion: newVersion)
        )
        let transition = try VaultCryptography.wrapPreviousVaultKey(
            snapshot.key,
            using: newKey,
            context: VaultKeyTransitionContext(ownerUserID: userID, fromKeyVersion: snapshot.keyVersion, toKeyVersion: newVersion)
        )
        struct Params: Encodable {
            let p_actor_device_id: UUID
            let p_revoked_device_id: UUID
            let p_new_key_version: Int
            let p_device_wraps: [DeviceWrap]
            let p_wrapped_recovery_key: String
            let p_new_key_confirmation: String
            let p_current_key_confirmation: String
            let p_wrapped_previous_key: String
        }
        try await client.rpc("miloom_revoke_vault_device_and_rotate", params: Params(
            p_actor_device_id: snapshot.deviceID,
            p_revoked_device_id: target.deviceID,
            p_new_key_version: newVersion,
            p_device_wraps: deviceWraps,
            p_wrapped_recovery_key: recovery.wrappedKey,
            p_new_key_confirmation: VaultCryptography.keyConfirmation(for: newKey),
            p_current_key_confirmation: VaultCryptography.keyConfirmation(for: snapshot.key),
            p_wrapped_previous_key: transition
        )).execute()

        var keys = snapshot.keys
        keys[newVersion] = newKey
        VaultKeySession.shared.install(
            userID: userID,
            deviceID: snapshot.deviceID,
            currentKeyVersion: newVersion,
            keys: keys
        )
        let rotatedSnapshot = try requireSnapshot(for: userID)
        let report = try await DataRepository.shared.rotateVaultSecrets(
            snapshot: rotatedSnapshot,
            fromKeyVersion: snapshot.keyVersion
        )
        let completed = report.failedRecords == 0 && report.remainingOldVaultFields == 0
        if completed { try await completeRotation(snapshot: rotatedSnapshot) }
        return VaultRotationResult(recoveryCode: recoveryCode, report: report, completed: completed)
    }

    func cancelPendingDevice(_ target: VaultDeviceRecord) async throws {
        let session = try await client.auth.refreshSession()
        guard target.status == "pending",
              let snapshot = VaultKeySession.shared.snapshot(for: session.user.id) else {
            throw VaultCryptographyError.authenticationFailed
        }
        struct Params: Encodable {
            let p_actor_device_id: UUID
            let p_target_device_id: UUID
            let p_key_confirmation: String
        }
        try await client.rpc("miloom_revoke_pending_vault_device", params: Params(
            p_actor_device_id: snapshot.deviceID,
            p_target_device_id: target.deviceID,
            p_key_confirmation: VaultCryptography.keyConfirmation(for: snapshot.key)
        )).execute()
    }

    func rotateRecoveryCode() async throws -> String {
        let session = try await client.auth.refreshSession()
        let snapshot = try requireSnapshot(for: session.user.id)
        let code = try VaultCryptography.generateRecoveryCode()
        let recovery = try VaultCryptography.wrapVaultKeyForRecovery(
            snapshot.key,
            recoveryCode: code,
            context: VaultRecoveryWrapContext(ownerUserID: session.user.id, keyVersion: snapshot.keyVersion)
        )
        struct Params: Encodable {
            let p_actor_device_id: UUID
            let p_key_version: Int
            let p_wrapped_recovery_key: String
            let p_key_confirmation: String
        }
        try await client.rpc("miloom_rotate_vault_recovery", params: Params(
            p_actor_device_id: snapshot.deviceID,
            p_key_version: snapshot.keyVersion,
            p_wrapped_recovery_key: recovery.wrappedKey,
            p_key_confirmation: VaultCryptography.keyConfirmation(for: snapshot.key)
        )).execute()
        return code
    }

    func resumeRotation() async throws -> VaultMigrationReport {
        let userID = try await client.auth.session.user.id
        let snapshot = try requireSnapshot(for: userID)
        guard let previousVersion = snapshot.keys.keys.filter({ $0 < snapshot.keyVersion }).max() else {
            throw VaultCryptographyError.invalidKeyVersion
        }
        let report = try await DataRepository.shared.rotateVaultSecrets(
            snapshot: snapshot,
            fromKeyVersion: previousVersion
        )
        if report.failedRecords == 0 && report.remainingOldVaultFields == 0 {
            try await completeRotation(snapshot: snapshot)
        }
        return report
    }

    func migrateLegacySecrets() async throws -> VaultMigrationReport {
        let userID = try await client.auth.session.user.id
        guard let snapshot = VaultKeySession.shared.snapshot(for: userID) else {
            throw VaultCryptographyError.authenticationFailed
        }
        return try await DataRepository.shared.migrateLegacyVaultSecrets(snapshot: snapshot)
    }

    func listDevices() async throws -> [VaultDeviceRecord] {
        try await client.rpc("miloom_list_vault_devices").execute().value
    }

    func listPendingResourceSecretRequests() async throws -> [ResourceSecretAccessRequest] {
        let session = try await client.auth.refreshSession()
        let snapshot = try requireSnapshot(for: session.user.id)
        struct Params: Encodable {
            let p_actor_device_id: UUID
            let p_key_confirmation: String
        }
        return try await client.rpc("miloom_list_resource_secret_requests", params: Params(
            p_actor_device_id: snapshot.deviceID,
            p_key_confirmation: VaultCryptography.keyConfirmation(for: snapshot.key)
        )).execute().value
    }

    func listLockedResourceSecrets() async throws -> [LockedResourceSecret] {
        let session = try await client.auth.refreshSession()
        let snapshot = try requireSnapshot(for: session.user.id)
        struct Params: Encodable {
            let p_actor_device_id: UUID
            let p_key_confirmation: String
        }
        return try await client.rpc("miloom_list_owner_locked_resource_secrets", params: Params(
            p_actor_device_id: snapshot.deviceID,
            p_key_confirmation: VaultCryptography.keyConfirmation(for: snapshot.key)
        )).execute().value
    }

    func rotateLockedResourceSecret(_ displayed: LockedResourceSecret) async throws {
        try await confirmResourceSecretPresence(
            reason: "Replace the locked credential key for \(displayed.resourceTitle ?? displayed.resourceType)."
        )
        let session = try await client.auth.refreshSession()
        let snapshot = try requireSnapshot(for: session.user.id)
        let current = try await listLockedResourceSecrets()
        guard current.contains(displayed) else { throw ResourceSecretRotationError.staleResource }
        let confirmation = VaultCryptography.keyConfirmation(for: snapshot.key)
        struct OldParams: Encodable {
            let p_resource_type: String
            let p_resource_id: UUID
            let p_key_version: Int
            let p_actor_device_id: UUID
            let p_key_confirmation: String
        }
        let oldRows: [OwnerResourceSecretRecord] = try await client.rpc(
            "miloom_get_owner_resource_secret_version", params: OldParams(
                p_resource_type: displayed.resourceType,
                p_resource_id: displayed.resourceID,
                p_key_version: displayed.keyVersion,
                p_actor_device_id: snapshot.deviceID,
                p_key_confirmation: confirmation
            )
        ).execute().value
        guard oldRows.count == 1, let old = oldRows.first,
              old.state == "rotation_required",
              old.resourceType == displayed.resourceType,
              old.resourceID == displayed.resourceID,
              old.keyVersion == displayed.keyVersion else {
            throw ResourceSecretRotationError.staleResource
        }
        let plaintext: [String: String]
        do {
            plaintext = try plaintextFields(in: old, snapshot: snapshot)
        } catch {
            throw ResourceSecretRotationError.invalidSecret
        }
        let newVersion = old.keyVersion + 1
        var replacement = try await ownerResourceSecret(
            type: old.resourceType, id: old.resourceID, snapshot: snapshot
        )
        let reusable: Bool
        if let replacement, replacement.state == "staging",
           replacement.keyVersion == newVersion,
           replacement.ownerAccountKeyVersion == snapshot.keyVersion {
            reusable = (try? plaintextFields(in: replacement, snapshot: snapshot)) == plaintext
        } else {
            reusable = false
        }
        if !reusable {
            let resource = ResourceKeyContext(
                ownerUserID: snapshot.userID, resourceType: old.resourceType,
                resourceID: old.resourceID, keyVersion: newVersion
            )
            let resourceKey = SymmetricKey(size: .bits256)
            let wrap = try VaultCryptography.wrapResourceKeyForOwner(
                resourceKey, using: snapshot.key,
                context: ResourceOwnerWrapContext(
                    resource: resource, accountKeyVersion: snapshot.keyVersion
                )
            )
            var encrypted: [String: String] = [:]
            for (field, value) in plaintext {
                encrypted[field] = try VaultCryptography.encryptResourceSecret(
                    value, using: resourceKey,
                    context: ResourceSecretFieldContext(resource: resource, fieldName: field)
                )
            }
            struct StageParams: Encodable {
                let p_resource_type: String
                let p_resource_id: UUID
                let p_old_key_version: Int
                let p_new_owner_account_key_version: Int
                let p_new_owner_wrapped_resource_key: String
                let p_new_encrypted_fields: [String: String]
                let p_actor_device_id: UUID
                let p_key_confirmation: String
            }
            try await client.rpc("miloom_stage_rotated_resource_secret", params: StageParams(
                p_resource_type: old.resourceType,
                p_resource_id: old.resourceID,
                p_old_key_version: old.keyVersion,
                p_new_owner_account_key_version: snapshot.keyVersion,
                p_new_owner_wrapped_resource_key: wrap,
                p_new_encrypted_fields: encrypted,
                p_actor_device_id: snapshot.deviceID,
                p_key_confirmation: confirmation
            )).execute()
            replacement = try await ownerResourceSecret(
                type: old.resourceType, id: old.resourceID, snapshot: snapshot
            )
            guard replacement?.ownerWrappedResourceKey == wrap,
                  replacement?.encryptedFields == encrypted else {
                throw ResourceSecretRotationError.verificationFailed
            }
        }
        guard let replacement, replacement.state == "staging",
              replacement.resourceType == old.resourceType,
              replacement.resourceID == old.resourceID,
              replacement.keyVersion == newVersion,
              (try? plaintextFields(in: replacement, snapshot: snapshot)) == plaintext else {
            throw ResourceSecretRotationError.verificationFailed
        }
        struct ActivateParams: Encodable {
            let p_resource_type: String
            let p_resource_id: UUID
            let p_old_key_version: Int
            let p_expected_new_encrypted_fields: [String: String]
            let p_expected_new_owner_wrapped_resource_key: String
            let p_actor_device_id: UUID
            let p_key_confirmation: String
        }
        try await client.rpc("miloom_activate_rotated_resource_secret", params: ActivateParams(
            p_resource_type: old.resourceType,
            p_resource_id: old.resourceID,
            p_old_key_version: old.keyVersion,
            p_expected_new_encrypted_fields: replacement.encryptedFields,
            p_expected_new_owner_wrapped_resource_key: replacement.ownerWrappedResourceKey,
            p_actor_device_id: snapshot.deviceID,
            p_key_confirmation: confirmation
        )).execute()
        do {
            guard let activated = try await ownerResourceSecret(
                type: old.resourceType, id: old.resourceID, snapshot: snapshot
            ), activated.state == "active", activated.keyVersion == newVersion,
               (try? plaintextFields(in: activated, snapshot: snapshot)) == plaintext else {
                throw ResourceSecretRotationError.postActivationVerificationUnavailable
            }
        } catch {
            throw ResourceSecretRotationError.postActivationVerificationUnavailable
        }
    }

    func resourceSecretAccessStatus(type: String, id: UUID) async throws -> String {
        let session = try await client.auth.refreshSession()
        struct Params: Encodable {
            let p_resource_type: String
            let p_resource_id: UUID
            let p_device_id: UUID?
        }
        let rows: [ResourceSecretAccessStatus] = try await client.rpc(
            "miloom_resource_secret_access_status", params: Params(
                p_resource_type: type, p_resource_id: id,
                p_device_id: VaultKeySession.shared.snapshot(for: session.user.id)?.deviceID
            )
        ).execute().value
        guard rows.count == 1 else { throw ResourceSecretRevealError.unavailable }
        return rows[0].status
    }

    func requestResourceSecretAccess(type: String, id: UUID) async throws {
        let session = try await client.auth.refreshSession()
        let identity = try VaultDeviceKeyStore.shared.loadOrCreateIdentity(for: session.user.id)
        let devices = try await listDevices()
        guard let device = currentDevice(in: devices, identity: identity),
              device.status == "approved" else {
            throw ResourceSecretRevealError.deviceNeedsApproval
        }
        struct Params: Encodable {
            let p_resource_type: String
            let p_resource_id: UUID
            let p_recipient_device_id: UUID
        }
        try await client.rpc("miloom_request_resource_secret_access", params: Params(
            p_resource_type: type, p_resource_id: id,
            p_recipient_device_id: device.deviceID
        )).execute()
    }

    /// Reveal only one exact resource after device presence. Callers must keep
    /// the returned plaintext in ephemeral UI state and clear it on dismissal.
    func revealResourceSecret(
        type: String, id: UUID, expectedOwnerUserID: UUID
    ) async throws -> [String: String] {
        try await confirmResourceSecretPresence(
            reason: "Reveal credentials for this Miloom resource."
        )
        let material = try await loadResourceSecretMaterial(
            type: type, id: id, expectedOwnerUserID: expectedOwnerUserID
        )
        do { return try material.plaintextFields() }
        catch { throw ResourceSecretRevealError.invalidSecret }
    }

    /// The caller sends the complete edited field set; only resource-bound
    /// ciphertext crosses the network. Optimistic compare rejects stale edits.
    func updateResourceSecret(
        type: String, id: UUID, expectedOwnerUserID: UUID,
        plaintextFields: [String: String]
    ) async throws {
        try await confirmResourceSecretPresence(
            reason: "Save the encrypted credentials for this Miloom resource."
        )
        let material = try await loadResourceSecretMaterial(
            type: type, id: id, expectedOwnerUserID: expectedOwnerUserID
        )
        let allowed: Set<String>
        switch type {
        case "institution":
            allowed = ["login_url", "username", "email", "password", "two_factor", "accounts_data"]
        case "card":
            allowed = ["login", "password", "card_number", "expiry"]
        case "subscription":
            allowed = ["login_id", "password", "two_factor_auth", "recovery_method"]
        default:
            throw ResourceSecretUpdateError.invalidFields
        }
        guard !plaintextFields.isEmpty,
              Set(plaintextFields.keys).isSubset(of: allowed),
              !plaintextFields.values.contains(where: { $0.isEmpty }) else {
            throw ResourceSecretUpdateError.invalidFields
        }
        if let accountJSON = plaintextFields["accounts_data"] {
            guard let data = accountJSON.data(using: .utf8),
                  (try? JSONDecoder().decode([ResourceBankAccountCredentials].self, from: data)) != nil else {
                throw ResourceSecretUpdateError.invalidFields
            }
        }
        let oldPlaintext: [String: String]
        do { oldPlaintext = try material.plaintextFields() }
        catch { throw ResourceSecretRevealError.invalidSecret }
        if oldPlaintext == plaintextFields { return }

        var encrypted: [String: String] = [:]
        for (field, value) in plaintextFields {
            encrypted[field] = try VaultCryptography.encryptResourceSecret(
                value, using: material.key,
                context: ResourceSecretFieldContext(resource: material.resource, fieldName: field)
            )
        }
        struct Params: Encodable {
            let p_resource_type: String
            let p_resource_id: UUID
            let p_key_version: Int
            let p_expected_encrypted_fields: [String: String]
            let p_new_encrypted_fields: [String: String]
            let p_actor_device_id: UUID
        }
        try await client.rpc("miloom_update_resource_secret", params: Params(
            p_resource_type: type, p_resource_id: id,
            p_key_version: material.resource.keyVersion,
            p_expected_encrypted_fields: material.encryptedFields,
            p_new_encrypted_fields: encrypted,
            p_actor_device_id: material.deviceID
        )).execute()
        do {
            let readback = try await loadResourceSecretMaterial(
                type: type, id: id, expectedOwnerUserID: expectedOwnerUserID
            )
            guard readback.resource.keyVersion == material.resource.keyVersion,
                  readback.encryptedFields == encrypted,
                  try readback.plaintextFields() == plaintextFields else {
                throw ResourceSecretUpdateError.verificationUnavailable
            }
        } catch {
            throw ResourceSecretUpdateError.verificationUnavailable
        }
    }

    private struct ResourceSecretMaterial {
        let resource: ResourceKeyContext
        let key: SymmetricKey
        let deviceID: UUID
        let encryptedFields: [String: String]

        func plaintextFields() throws -> [String: String] {
            var result: [String: String] = [:]
            for (field, ciphertext) in encryptedFields {
                result[field] = try VaultCryptography.decryptResourceSecret(
                    ciphertext, using: key,
                    context: ResourceSecretFieldContext(resource: resource, fieldName: field)
                )
            }
            return result
        }
    }

    private func loadResourceSecretMaterial(
        type: String, id: UUID, expectedOwnerUserID: UUID
    ) async throws -> ResourceSecretMaterial {
        let session = try await client.auth.refreshSession()
        if session.user.id == expectedOwnerUserID {
            let snapshot = try requireSnapshot(for: session.user.id)
            guard let record = try await ownerResourceSecret(
                type: type, id: id, snapshot: snapshot
            ), record.state == "active", !record.encryptedFields.isEmpty else {
                throw ResourceSecretRevealError.unavailable
            }
            do {
                guard let accountKey = snapshot.key(for: record.ownerAccountKeyVersion) else {
                    throw ResourceSecretRevealError.invalidSecret
                }
                let resource = ResourceKeyContext(
                    ownerUserID: session.user.id, resourceType: type,
                    resourceID: id, keyVersion: record.keyVersion
                )
                let key = try VaultCryptography.unwrapResourceKeyForOwner(
                    record.ownerWrappedResourceKey, using: accountKey,
                    context: ResourceOwnerWrapContext(
                        resource: resource,
                        accountKeyVersion: record.ownerAccountKeyVersion
                    )
                )
                return ResourceSecretMaterial(
                    resource: resource, key: key, deviceID: snapshot.deviceID,
                    encryptedFields: record.encryptedFields
                )
            } catch {
                throw ResourceSecretRevealError.invalidSecret
            }
        }

        let identity = try VaultDeviceKeyStore.shared.loadOrCreateIdentity(for: session.user.id)
        let devices = try await listDevices()
        guard let device = currentDevice(in: devices, identity: identity),
              device.status == "approved" else {
            throw ResourceSecretRevealError.deviceNeedsApproval
        }
        struct Params: Encodable {
            let p_resource_type: String
            let p_resource_id: UUID
            let p_device_id: UUID
        }
        let records: [DeviceResourceSecretRecord] = try await client.rpc(
            "miloom_get_resource_secret_for_device", params: Params(
                p_resource_type: type, p_resource_id: id,
                p_device_id: device.deviceID
            )
        ).execute().value
        guard records.count <= 1, let record = records.first,
              record.ownerUserID == expectedOwnerUserID,
              record.resourceType == type, record.resourceID == id,
              !record.encryptedFields.isEmpty else {
            throw ResourceSecretRevealError.unavailable
        }
        let resource = ResourceKeyContext(
            ownerUserID: record.ownerUserID, resourceType: record.resourceType,
            resourceID: record.resourceID, keyVersion: record.keyVersion
        )
        let envelope = VaultDeviceKeyWrapEnvelope(
            version: 1, keyVersion: record.keyVersion,
            ephemeralPublicKey: record.ephemeralPublicKey,
            wrappedKey: record.wrappedResourceKey
        )
        do {
            let key = try VaultCryptography.unwrapResourceKeyForDevice(
                envelope, using: identity.agreementPrivateKey,
                context: ResourceDeviceWrapContext(
                    resource: resource, recipientUserID: session.user.id,
                    recipientDeviceID: device.deviceID
                )
            )
            return ResourceSecretMaterial(
                resource: resource, key: key, deviceID: device.deviceID,
                encryptedFields: record.encryptedFields
            )
        } catch {
            throw ResourceSecretRevealError.invalidSecret
        }
    }

    func approveResourceSecretRequest(_ displayedRequest: ResourceSecretAccessRequest) async throws {
        try await confirmResourceSecretPresence(
            reason: "Approve credential access for one trusted collaborator device."
        )
        let session = try await client.auth.refreshSession()
        let snapshot = try requireSnapshot(for: session.user.id)
        let pending = try await listPendingResourceSecretRequests()
        guard let request = pending.first(where: { $0.id == displayedRequest.id }),
              request == displayedRequest else {
            throw ResourceSecretGrantError.staleRequest
        }
        struct SecretParams: Encodable {
            let p_resource_type: String
            let p_resource_id: UUID
            let p_actor_device_id: UUID
            let p_key_confirmation: String
        }
        let confirmation = VaultCryptography.keyConfirmation(for: snapshot.key)
        let secrets: [OwnerResourceSecretRecord] = try await client.rpc(
            "miloom_get_owner_resource_secret", params: SecretParams(
                p_resource_type: request.resourceType,
                p_resource_id: request.resourceID,
                p_actor_device_id: snapshot.deviceID,
                p_key_confirmation: confirmation
            )
        ).execute().value
        guard let secret = secrets.first,
              secret.state == "active",
              secret.resourceType == request.resourceType,
              secret.resourceID == request.resourceID,
              secret.keyVersion == request.keyVersion,
              !secret.encryptedFields.isEmpty,
              let accountKey = snapshot.key(for: secret.ownerAccountKeyVersion) else {
            throw ResourceSecretGrantError.staleRequest
        }
        let resource = ResourceKeyContext(
            ownerUserID: snapshot.userID,
            resourceType: request.resourceType,
            resourceID: request.resourceID,
            keyVersion: request.keyVersion
        )
        let ownerContext = ResourceOwnerWrapContext(
            resource: resource, accountKeyVersion: secret.ownerAccountKeyVersion
        )
        let resourceKey: SymmetricKey
        do {
            resourceKey = try VaultCryptography.unwrapResourceKeyForOwner(
                secret.ownerWrappedResourceKey, using: accountKey, context: ownerContext
            )
            // A structurally valid wrap is not enough: check every field's
            // authenticated data before making the key available to a device.
            for (field, envelope) in secret.encryptedFields {
                _ = try VaultCryptography.decryptResourceSecret(
                    envelope, using: resourceKey,
                    context: ResourceSecretFieldContext(resource: resource, fieldName: field)
                )
            }
        } catch {
            throw ResourceSecretGrantError.invalidSecret
        }
        let deviceContext = ResourceDeviceWrapContext(
            resource: resource,
            recipientUserID: request.recipientUserID,
            recipientDeviceID: request.recipientDeviceID
        )
        let wrap = try VaultCryptography.wrapResourceKeyForDevice(
            resourceKey, for: request.agreementPublicKey, context: deviceContext
        )
        struct ApprovalParams: Encodable {
            let p_request_id: UUID
            let p_actor_device_id: UUID
            let p_key_confirmation: String
            let p_ephemeral_public_key: String
            let p_wrapped_resource_key: String
        }
        try await client.rpc("miloom_approve_resource_secret_access", params: ApprovalParams(
            p_request_id: request.id,
            p_actor_device_id: snapshot.deviceID,
            p_key_confirmation: confirmation,
            p_ephemeral_public_key: wrap.ephemeralPublicKey,
            p_wrapped_resource_key: wrap.wrappedKey
        )).execute()
    }

    func prepareOwnedResourceSecrets() async throws -> ResourceSecretPreparationReport {
        try await confirmResourceSecretPresence(
            reason: "Prepare encrypted copies of your credentials without sharing them."
        )
        let session = try await client.auth.refreshSession()
        let snapshot = try requireSnapshot(for: session.user.id)
        let collection = try await DataRepository.shared.collectOwnedResourceSecretCandidates(
            snapshot: snapshot
        )
        var report = ResourceSecretPreparationReport()
        report.skippedLockedRecords = collection.skippedLockedRecords
        report.skippedEmptyRecords = collection.skippedEmptyRecords
        report.failedRecords = collection.failedRecords
        for candidate in collection.candidates {
            if report.preparedRecords >= 25 {
                report.deferredRecords += 1
                continue
            }
            do {
                if try await stageAndVerifyResourceSecret(candidate, snapshot: snapshot) {
                    report.preparedRecords += 1
                } else {
                    report.alreadyPreparedRecords += 1
                }
            } catch {
                report.failedRecords += 1
                AppDiagnostics.failure("vault", "prepare_resource_secret", error: error)
            }
        }
        return report
    }

    private func stageAndVerifyResourceSecret(
        _ candidate: ResourceSecretPreparationCandidate,
        snapshot: VaultKeySession.Snapshot
    ) async throws -> Bool {
        guard !candidate.plaintextFields.isEmpty else {
            throw ResourceSecretPreparationError.verificationFailed
        }
        let existing = try await ownerResourceSecret(
            type: candidate.resourceType, id: candidate.resourceID, snapshot: snapshot
        )
        if let existing {
            guard existing.state == "staging" else {
                throw ResourceSecretPreparationError.activeResource
            }
            let revisionsMatch: Bool
            if let staged = existing.sourceSecretRevision,
               let current = existing.currentSecretRevision {
                revisionsMatch = staged >= 0 && staged == current
            } else {
                // 014 has no revision contract yet. It is safe to retain a
                // staged copy, but 016 must restamp it before activation.
                revisionsMatch = true
            }
            if revisionsMatch {
                if try plaintextFields(in: existing, snapshot: snapshot) == candidate.plaintextFields {
                    return false
                }
            }
        }
        let version = existing?.keyVersion ?? 1
        let resource = ResourceKeyContext(
            ownerUserID: snapshot.userID,
            resourceType: candidate.resourceType,
            resourceID: candidate.resourceID,
            keyVersion: version
        )
        let resourceKey = SymmetricKey(size: .bits256)
        let ownerWrap = try VaultCryptography.wrapResourceKeyForOwner(
            resourceKey, using: snapshot.key,
            context: ResourceOwnerWrapContext(
                resource: resource, accountKeyVersion: snapshot.keyVersion
            )
        )
        var ciphertext: [String: String] = [:]
        for (field, plaintext) in candidate.plaintextFields {
            ciphertext[field] = try VaultCryptography.encryptResourceSecret(
                plaintext, using: resourceKey,
                context: ResourceSecretFieldContext(resource: resource, fieldName: field)
            )
        }
        struct StageParams: Encodable {
            let p_resource_type: String
            let p_resource_id: UUID
            let p_key_version: Int
            let p_owner_account_key_version: Int
            let p_owner_wrapped_resource_key: String
            let p_encrypted_fields: [String: String]
            let p_actor_device_id: UUID
            let p_key_confirmation: String
        }
        try await client.rpc("miloom_stage_resource_secret", params: StageParams(
            p_resource_type: candidate.resourceType,
            p_resource_id: candidate.resourceID,
            p_key_version: version,
            p_owner_account_key_version: snapshot.keyVersion,
            p_owner_wrapped_resource_key: ownerWrap,
            p_encrypted_fields: ciphertext,
            p_actor_device_id: snapshot.deviceID,
            p_key_confirmation: VaultCryptography.keyConfirmation(for: snapshot.key)
        )).execute()
        guard let readback = try await ownerResourceSecret(
            type: candidate.resourceType, id: candidate.resourceID, snapshot: snapshot
        ), readback.state == "staging",
           readback.keyVersion == version,
           readback.ownerAccountKeyVersion == snapshot.keyVersion,
           readback.ownerWrappedResourceKey == ownerWrap,
           readback.encryptedFields == ciphertext,
           readback.sourceSecretRevision == nil ||
                (readback.sourceSecretRevision == readback.currentSecretRevision &&
                 (readback.sourceSecretRevision ?? -1) >= 0),
           try plaintextFields(in: readback, snapshot: snapshot) == candidate.plaintextFields else {
            throw ResourceSecretPreparationError.verificationFailed
        }
        return true
    }

    private func ownerResourceSecret(
        type: String, id: UUID, snapshot: VaultKeySession.Snapshot
    ) async throws -> OwnerResourceSecretRecord? {
        struct Params: Encodable {
            let p_resource_type: String
            let p_resource_id: UUID
            let p_actor_device_id: UUID
            let p_key_confirmation: String
        }
        let rows: [OwnerResourceSecretRecord] = try await client.rpc(
            "miloom_get_owner_resource_secret", params: Params(
                p_resource_type: type,
                p_resource_id: id,
                p_actor_device_id: snapshot.deviceID,
                p_key_confirmation: VaultCryptography.keyConfirmation(for: snapshot.key)
            )
        ).execute().value
        guard rows.count <= 1 else { throw ResourceSecretPreparationError.verificationFailed }
        guard let row = rows.first else { return nil }
        guard row.resourceType == type, row.resourceID == id else {
            throw ResourceSecretPreparationError.verificationFailed
        }
        return row
    }

    private func plaintextFields(
        in record: OwnerResourceSecretRecord, snapshot: VaultKeySession.Snapshot
    ) throws -> [String: String] {
        guard let accountKey = snapshot.key(for: record.ownerAccountKeyVersion),
              !record.encryptedFields.isEmpty else {
            throw ResourceSecretPreparationError.verificationFailed
        }
        let resource = ResourceKeyContext(
            ownerUserID: snapshot.userID,
            resourceType: record.resourceType,
            resourceID: record.resourceID,
            keyVersion: record.keyVersion
        )
        let resourceKey = try VaultCryptography.unwrapResourceKeyForOwner(
            record.ownerWrappedResourceKey, using: accountKey,
            context: ResourceOwnerWrapContext(
                resource: resource, accountKeyVersion: record.ownerAccountKeyVersion
            )
        )
        var result: [String: String] = [:]
        for (field, envelope) in record.encryptedFields {
            result[field] = try VaultCryptography.decryptResourceSecret(
                envelope, using: resourceKey,
                context: ResourceSecretFieldContext(resource: resource, fieldName: field)
            )
        }
        return result
    }

    @MainActor
    private func confirmResourceSecretPresence(reason: String) async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            throw ResourceSecretGrantError.confirmationUnavailable
        }
        do {
            guard try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            ) else {
                throw ResourceSecretGrantError.confirmationCancelled
            }
        } catch {
            throw ResourceSecretGrantError.confirmationCancelled
        }
    }

    private func currentDevice(in devices: [VaultDeviceRecord], identity: VaultDeviceIdentity) -> VaultDeviceRecord? {
        devices.first {
            $0.agreementPublicKey == identity.publicKeys.agreementPublicKey
                && $0.signingPublicKey == identity.publicKeys.signingPublicKey
        }
    }

    private func requireSnapshot(for userID: UUID) throws -> VaultKeySession.Snapshot {
        guard let snapshot = VaultKeySession.shared.snapshot(for: userID) else {
            throw VaultCryptographyError.authenticationFailed
        }
        return snapshot
    }

    private func completeRotation(snapshot: VaultKeySession.Snapshot) async throws {
        // The account transition key is intentionally discarded on completion.
        // Rewrap every staged or locked resource key first, and let the server
        // refuse completion if any owner wrap still names an older account key.
        try await rewrapResourceSecretsForRotation(snapshot: snapshot)
        struct Params: Encodable {
            let p_actor_device_id: UUID
            let p_key_version: Int
            let p_key_confirmation: String
        }
        try await client.rpc("miloom_complete_vault_rotation", params: Params(
            p_actor_device_id: snapshot.deviceID,
            p_key_version: snapshot.keyVersion,
            p_key_confirmation: VaultCryptography.keyConfirmation(for: snapshot.key)
        )).execute()
    }

    private func rewrapResourceSecretsForRotation(snapshot: VaultKeySession.Snapshot) async throws {
        let confirmation = VaultCryptography.keyConfirmation(for: snapshot.key)
        struct ListParams: Encodable {
            let p_actor_device_id: UUID
            let p_key_confirmation: String
        }
        let params = ListParams(
            p_actor_device_id: snapshot.deviceID,
            p_key_confirmation: confirmation
        )
        let wraps: [ResourceSecretOwnerWrapRecord] = try await client.rpc(
            "miloom_list_resource_secret_owner_wraps_for_rotation", params: params
        ).execute().value
        for wrap in wraps {
            guard let previousKey = snapshot.key(for: wrap.ownerAccountKeyVersion) else {
                throw VaultCryptographyError.invalidKeyVersion
            }
            let resource = ResourceKeyContext(
                ownerUserID: snapshot.userID,
                resourceType: wrap.resourceType,
                resourceID: wrap.resourceID,
                keyVersion: wrap.keyVersion
            )
            let oldContext = ResourceOwnerWrapContext(
                resource: resource,
                accountKeyVersion: wrap.ownerAccountKeyVersion
            )
            let resourceKey = try VaultCryptography.unwrapResourceKeyForOwner(
                wrap.ownerWrappedResourceKey, using: previousKey, context: oldContext
            )
            let newContext = ResourceOwnerWrapContext(
                resource: resource,
                accountKeyVersion: snapshot.keyVersion
            )
            let newWrap = try VaultCryptography.wrapResourceKeyForOwner(
                resourceKey, using: snapshot.key, context: newContext
            )
            struct RewrapParams: Encodable {
                let p_resource_type: String
                let p_resource_id: UUID
                let p_key_version: Int
                let p_expected_owner_account_key_version: Int
                let p_new_owner_wrapped_resource_key: String
                let p_actor_device_id: UUID
                let p_key_confirmation: String
            }
            try await client.rpc("miloom_rewrap_resource_secret_owner_key", params: RewrapParams(
                p_resource_type: wrap.resourceType,
                p_resource_id: wrap.resourceID,
                p_key_version: wrap.keyVersion,
                p_expected_owner_account_key_version: wrap.ownerAccountKeyVersion,
                p_new_owner_wrapped_resource_key: newWrap,
                p_actor_device_id: snapshot.deviceID,
                p_key_confirmation: confirmation
            )).execute()
        }
    }

    private func bindCurrentSession(deviceID: UUID, key: SymmetricKey) async throws {
        struct Params: Encodable {
            let p_device_id: UUID
            let p_key_confirmation: String
        }
        try await client.rpc("miloom_bind_vault_device_session", params: Params(
            p_device_id: deviceID,
            p_key_confirmation: VaultCryptography.keyConfirmation(for: key)
        )).execute()
    }

    private var deviceLabel: String {
        #if canImport(UIKit)
        let name = UIDevice.current.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((name.isEmpty ? "iPhone" : name).prefix(80))
        #else
        return "Apple Device"
        #endif
    }

    private static func approvalFailureReason(from data: Data) -> String {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let reason = object["error"] as? String,
            approvalFailureReasons.contains(reason)
        else {
            return "UNKNOWN"
        }
        return reason
    }

    private static let approvalFailureReasons: Set<String> = [
        "UNAUTHORIZED",
        "INVALID_APPROVAL_REQUEST",
        "INVALID_APPROVAL_CRYPTOGRAPHY",
        "APPROVAL_CHALLENGE_INVALID",
        "APPROVING_DEVICE_NOT_AUTHORIZED",
        "APPROVAL_SIGNATURE_INVALID",
        "APPROVAL_FINALIZATION_FAILED",
        "APPROVAL_REQUEST_FAILED",
    ]
}

enum VaultApprovalServiceError: Error, Equatable {
    case remote(statusCode: Int, reason: String)
    case relayUnavailable
}

enum VaultCryptographyError: Error, Equatable {
    case invalidEnvelope
    case unsupportedVersion
    case invalidKeyVersion
    case invalidPublicKey
    case invalidRecoveryCode
    case authenticationFailed
    case randomGenerationFailed
    case keychainFailure(OSStatus)
}

struct VaultFieldContext: Hashable {
    let ownerUserID: UUID
    let resourceType: String
    let resourceID: UUID
    let fieldName: String
    let keyVersion: Int

    fileprivate var authenticatedData: Data {
        Data([
            "miloom-field-v1",
            ownerUserID.uuidString.lowercased(),
            resourceType.lowercased(),
            resourceID.uuidString.lowercased(),
            fieldName.lowercased(),
            String(keyVersion)
        ].joined(separator: "|").utf8)
    }

    func withKeyVersion(_ version: Int) -> VaultFieldContext {
        VaultFieldContext(
            ownerUserID: ownerUserID,
            resourceType: resourceType,
            resourceID: resourceID,
            fieldName: fieldName,
            keyVersion: version
        )
    }
}

struct VaultKeyWrapContext: Hashable {
    let ownerUserID: UUID
    let recipientDeviceID: UUID
    let keyVersion: Int

    fileprivate var authenticatedData: Data {
        Data([
            "miloom-device-wrap-v1",
            ownerUserID.uuidString.lowercased(),
            recipientDeviceID.uuidString.lowercased(),
            String(keyVersion)
        ].joined(separator: "|").utf8)
    }
}

/// A resource key is never the account vault key. These contexts deliberately
/// use separate authenticated-data domains so a wrap or ciphertext copied from
/// another owner, resource, device, or version cannot be opened here.
struct ResourceKeyContext: Hashable {
    let ownerUserID: UUID
    let resourceType: String
    let resourceID: UUID
    let keyVersion: Int

    fileprivate var authenticatedData: Data {
        Data([
            "miloom-resource-secret-v1",
            ownerUserID.uuidString.lowercased(),
            resourceType.lowercased(),
            resourceID.uuidString.lowercased(),
            String(keyVersion)
        ].joined(separator: "|").utf8)
    }
}

struct ResourceSecretFieldContext: Hashable {
    let resource: ResourceKeyContext
    let fieldName: String

    fileprivate var authenticatedData: Data {
        Data("miloom-resource-field-v1|\(String(decoding: resource.authenticatedData, as: UTF8.self))|\(fieldName.lowercased())".utf8)
    }
}

struct ResourceOwnerWrapContext: Hashable {
    let resource: ResourceKeyContext
    let accountKeyVersion: Int

    fileprivate var authenticatedData: Data {
        Data("miloom-resource-owner-wrap-v1|\(String(decoding: resource.authenticatedData, as: UTF8.self))|\(accountKeyVersion)".utf8)
    }
}

struct ResourceDeviceWrapContext: Hashable {
    let resource: ResourceKeyContext
    let recipientUserID: UUID
    let recipientDeviceID: UUID

    fileprivate var authenticatedData: Data {
        Data("miloom-resource-device-wrap-v1|\(String(decoding: resource.authenticatedData, as: UTF8.self))|\(recipientUserID.uuidString.lowercased())|\(recipientDeviceID.uuidString.lowercased())".utf8)
    }
}

struct VaultRecoveryWrapContext: Hashable {
    let ownerUserID: UUID
    let keyVersion: Int

    fileprivate var authenticatedData: Data {
        Data([
            "miloom-recovery-wrap-v1",
            ownerUserID.uuidString.lowercased(),
            String(keyVersion)
        ].joined(separator: "|").utf8)
    }
}

struct VaultKeyTransitionContext: Hashable {
    let ownerUserID: UUID
    let fromKeyVersion: Int
    let toKeyVersion: Int

    fileprivate var authenticatedData: Data {
        Data([
            "miloom-key-transition-v1",
            ownerUserID.uuidString.lowercased(),
            String(fromKeyVersion),
            String(toKeyVersion)
        ].joined(separator: "|").utf8)
    }
}

struct VaultDeviceKeyWrapEnvelope: Codable, Equatable {
    let version: Int
    let keyVersion: Int
    let ephemeralPublicKey: String
    let wrappedKey: String
}

struct VaultRecoveryKeyWrapEnvelope: Codable, Equatable {
    let version: Int
    let keyVersion: Int
    let wrappedKey: String
}

struct VaultDevicePublicKeys: Codable, Equatable {
    let agreementPublicKey: String
    let signingPublicKey: String
}

struct VaultDeviceIdentity {
    let agreementPrivateKey: P256.KeyAgreement.PrivateKey
    let signingPrivateKey: P256.Signing.PrivateKey

    var publicKeys: VaultDevicePublicKeys {
        VaultDevicePublicKeys(
            agreementPublicKey: agreementPrivateKey.publicKey.x963Representation.base64EncodedString(),
            signingPublicKey: signingPrivateKey.publicKey.x963Representation.base64EncodedString()
        )
    }
}

enum VaultCryptography {
    static let fieldEnvelopePrefix = SecurityService.vaultEnvelopePrefix
    private static let deviceWrapSalt = Data("miloom-device-wrap-v1".utf8)
    private static let recoveryWrapSalt = Data("miloom-recovery-wrap-v1".utf8)
    private static let resourceDeviceWrapSalt = Data("miloom-resource-device-wrap-v1".utf8)

    static func encryptResourceSecret(_ plaintext: String, using resourceKey: SymmetricKey, context: ResourceSecretFieldContext) throws -> String {
        guard context.resource.keyVersion > 0, !context.fieldName.isEmpty else { throw VaultCryptographyError.invalidKeyVersion }
        let box = try AES.GCM.seal(Data(plaintext.utf8), using: resourceKey, authenticating: context.authenticatedData)
        guard let combined = box.combined else { throw VaultCryptographyError.invalidEnvelope }
        return "miloom-resource:v1:\(context.resource.keyVersion):\(combined.base64EncodedString())"
    }

    static func decryptResourceSecret(_ envelope: String, using resourceKey: SymmetricKey, context: ResourceSecretFieldContext) throws -> String {
        let parts = envelope.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 4, parts[0] == "miloom-resource", parts[1] == "v1",
              let embeddedVersion = Int(parts[2]), embeddedVersion == context.resource.keyVersion,
              let combined = Data(base64Encoded: String(parts[3])) else {
            throw VaultCryptographyError.invalidEnvelope
        }
        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            let data = try AES.GCM.open(box, using: resourceKey, authenticating: context.authenticatedData)
            guard let plaintext = String(data: data, encoding: .utf8) else { throw VaultCryptographyError.invalidEnvelope }
            return plaintext
        } catch let error as VaultCryptographyError {
            throw error
        } catch {
            throw VaultCryptographyError.authenticationFailed
        }
    }

    static func wrapResourceKeyForOwner(_ resourceKey: SymmetricKey, using accountKey: SymmetricKey, context: ResourceOwnerWrapContext) throws -> String {
        guard context.resource.keyVersion > 0, context.accountKeyVersion > 0 else { throw VaultCryptographyError.invalidKeyVersion }
        let rawKey = resourceKey.withUnsafeBytes { Data($0) }
        let box = try AES.GCM.seal(rawKey, using: accountKey, authenticating: context.authenticatedData)
        guard let combined = box.combined else { throw VaultCryptographyError.invalidEnvelope }
        return combined.base64EncodedString()
    }

    static func unwrapResourceKeyForOwner(_ wrappedKey: String, using accountKey: SymmetricKey, context: ResourceOwnerWrapContext) throws -> SymmetricKey {
        guard context.resource.keyVersion > 0, context.accountKeyVersion > 0,
              let combined = Data(base64Encoded: wrappedKey) else { throw VaultCryptographyError.invalidEnvelope }
        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            let rawKey = try AES.GCM.open(box, using: accountKey, authenticating: context.authenticatedData)
            guard rawKey.count == 32 else { throw VaultCryptographyError.invalidEnvelope }
            return SymmetricKey(data: rawKey)
        } catch let error as VaultCryptographyError {
            throw error
        } catch {
            throw VaultCryptographyError.authenticationFailed
        }
    }

    static func wrapResourceKeyForDevice(_ resourceKey: SymmetricKey, for publicKeyBase64: String, context: ResourceDeviceWrapContext) throws -> VaultDeviceKeyWrapEnvelope {
        guard context.resource.keyVersion > 0,
              let publicData = Data(base64Encoded: publicKeyBase64),
              let publicKey = try? P256.KeyAgreement.PublicKey(x963Representation: publicData) else {
            throw VaultCryptographyError.invalidPublicKey
        }
        let ephemeral = P256.KeyAgreement.PrivateKey()
        let sharedSecret = try ephemeral.sharedSecretFromKeyAgreement(with: publicKey)
        let wrappingKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self, salt: resourceDeviceWrapSalt,
            sharedInfo: context.authenticatedData, outputByteCount: 32
        )
        let rawKey = resourceKey.withUnsafeBytes { Data($0) }
        let box = try AES.GCM.seal(rawKey, using: wrappingKey, authenticating: context.authenticatedData)
        guard let combined = box.combined else { throw VaultCryptographyError.invalidEnvelope }
        return VaultDeviceKeyWrapEnvelope(version: 1, keyVersion: context.resource.keyVersion,
                                          ephemeralPublicKey: ephemeral.publicKey.x963Representation.base64EncodedString(),
                                          wrappedKey: combined.base64EncodedString())
    }

    static func unwrapResourceKeyForDevice(_ envelope: VaultDeviceKeyWrapEnvelope, using privateKey: P256.KeyAgreement.PrivateKey, context: ResourceDeviceWrapContext) throws -> SymmetricKey {
        guard envelope.version == 1 else { throw VaultCryptographyError.unsupportedVersion }
        guard context.resource.keyVersion > 0, envelope.keyVersion == context.resource.keyVersion else { throw VaultCryptographyError.invalidKeyVersion }
        guard let ephemeralData = Data(base64Encoded: envelope.ephemeralPublicKey),
              let ephemeralPublicKey = try? P256.KeyAgreement.PublicKey(x963Representation: ephemeralData),
              let combined = Data(base64Encoded: envelope.wrappedKey) else { throw VaultCryptographyError.invalidEnvelope }
        do {
            let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: ephemeralPublicKey)
            let wrappingKey = sharedSecret.hkdfDerivedSymmetricKey(
                using: SHA256.self, salt: resourceDeviceWrapSalt,
                sharedInfo: context.authenticatedData, outputByteCount: 32
            )
            let box = try AES.GCM.SealedBox(combined: combined)
            let rawKey = try AES.GCM.open(box, using: wrappingKey, authenticating: context.authenticatedData)
            guard rawKey.count == 32 else { throw VaultCryptographyError.invalidEnvelope }
            return SymmetricKey(data: rawKey)
        } catch let error as VaultCryptographyError {
            throw error
        } catch {
            throw VaultCryptographyError.authenticationFailed
        }
    }

    static func encryptField(
        _ plaintext: String,
        using vaultKey: SymmetricKey,
        context: VaultFieldContext
    ) throws -> String {
        guard context.keyVersion > 0 else { throw VaultCryptographyError.invalidKeyVersion }
        let box = try AES.GCM.seal(
            Data(plaintext.utf8),
            using: vaultKey,
            authenticating: context.authenticatedData
        )
        guard let combined = box.combined else { throw VaultCryptographyError.invalidEnvelope }
        return "\(fieldEnvelopePrefix)\(context.keyVersion):\(combined.base64EncodedString())"
    }

    static func decryptField(
        _ envelope: String,
        using vaultKey: SymmetricKey,
        context: VaultFieldContext
    ) throws -> String {
        let components = envelope.split(separator: ":", omittingEmptySubsequences: false)
        guard components.count == 4,
              components[0] == "miloom",
              components[1] == "v1",
              let embeddedVersion = Int(components[2]),
              embeddedVersion == context.keyVersion,
              let combined = Data(base64Encoded: String(components[3])) else {
            throw VaultCryptographyError.invalidEnvelope
        }

        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            let plaintext = try AES.GCM.open(
                box,
                using: vaultKey,
                authenticating: context.authenticatedData
            )
            guard let value = String(data: plaintext, encoding: .utf8) else {
                throw VaultCryptographyError.invalidEnvelope
            }
            return value
        } catch let error as VaultCryptographyError {
            throw error
        } catch {
            throw VaultCryptographyError.authenticationFailed
        }
    }

    static func fieldKeyVersion(in envelope: String) -> Int? {
        let components = envelope.split(separator: ":", omittingEmptySubsequences: false)
        guard components.count == 4, components[0] == "miloom", components[1] == "v1" else { return nil }
        return Int(components[2])
    }

    static func wrapPreviousVaultKey(
        _ previousKey: SymmetricKey,
        using currentKey: SymmetricKey,
        context: VaultKeyTransitionContext
    ) throws -> String {
        guard context.fromKeyVersion > 0, context.toKeyVersion == context.fromKeyVersion + 1 else {
            throw VaultCryptographyError.invalidKeyVersion
        }
        let rawKey = previousKey.withUnsafeBytes { Data($0) }
        let box = try AES.GCM.seal(rawKey, using: currentKey, authenticating: context.authenticatedData)
        guard let combined = box.combined else { throw VaultCryptographyError.invalidEnvelope }
        return combined.base64EncodedString()
    }

    static func unwrapPreviousVaultKey(
        _ wrappedKey: String,
        using currentKey: SymmetricKey,
        context: VaultKeyTransitionContext
    ) throws -> SymmetricKey {
        guard let combined = Data(base64Encoded: wrappedKey) else { throw VaultCryptographyError.invalidEnvelope }
        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            let rawKey = try AES.GCM.open(box, using: currentKey, authenticating: context.authenticatedData)
            guard rawKey.count == 32 else { throw VaultCryptographyError.invalidEnvelope }
            return SymmetricKey(data: rawKey)
        } catch let error as VaultCryptographyError {
            throw error
        } catch {
            throw VaultCryptographyError.authenticationFailed
        }
    }

    static func wrapVaultKey(
        _ vaultKey: SymmetricKey,
        for recipientPublicKeyBase64: String,
        context: VaultKeyWrapContext
    ) throws -> VaultDeviceKeyWrapEnvelope {
        guard context.keyVersion > 0,
              let publicKeyData = Data(base64Encoded: recipientPublicKeyBase64),
              let recipientPublicKey = try? P256.KeyAgreement.PublicKey(x963Representation: publicKeyData) else {
            throw VaultCryptographyError.invalidPublicKey
        }

        let ephemeralKey = P256.KeyAgreement.PrivateKey()
        let sharedSecret = try ephemeralKey.sharedSecretFromKeyAgreement(with: recipientPublicKey)
        let wrappingKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: deviceWrapSalt,
            sharedInfo: context.authenticatedData,
            outputByteCount: 32
        )
        let rawVaultKey = vaultKey.withUnsafeBytes { Data($0) }
        let box = try AES.GCM.seal(
            rawVaultKey,
            using: wrappingKey,
            authenticating: context.authenticatedData
        )
        guard let combined = box.combined else { throw VaultCryptographyError.invalidEnvelope }

        return VaultDeviceKeyWrapEnvelope(
            version: 1,
            keyVersion: context.keyVersion,
            ephemeralPublicKey: ephemeralKey.publicKey.x963Representation.base64EncodedString(),
            wrappedKey: combined.base64EncodedString()
        )
    }

    static func unwrapVaultKey(
        _ envelope: VaultDeviceKeyWrapEnvelope,
        using recipientPrivateKey: P256.KeyAgreement.PrivateKey,
        context: VaultKeyWrapContext
    ) throws -> SymmetricKey {
        guard envelope.version == 1 else { throw VaultCryptographyError.unsupportedVersion }
        guard envelope.keyVersion == context.keyVersion, context.keyVersion > 0 else {
            throw VaultCryptographyError.invalidKeyVersion
        }
        guard let ephemeralData = Data(base64Encoded: envelope.ephemeralPublicKey),
              let ephemeralPublicKey = try? P256.KeyAgreement.PublicKey(x963Representation: ephemeralData),
              let wrappedData = Data(base64Encoded: envelope.wrappedKey) else {
            throw VaultCryptographyError.invalidEnvelope
        }

        do {
            let sharedSecret = try recipientPrivateKey.sharedSecretFromKeyAgreement(with: ephemeralPublicKey)
            let wrappingKey = sharedSecret.hkdfDerivedSymmetricKey(
                using: SHA256.self,
                salt: deviceWrapSalt,
                sharedInfo: context.authenticatedData,
                outputByteCount: 32
            )
            let box = try AES.GCM.SealedBox(combined: wrappedData)
            let rawVaultKey = try AES.GCM.open(
                box,
                using: wrappingKey,
                authenticating: context.authenticatedData
            )
            guard rawVaultKey.count == 32 else { throw VaultCryptographyError.invalidEnvelope }
            return SymmetricKey(data: rawVaultKey)
        } catch let error as VaultCryptographyError {
            throw error
        } catch {
            throw VaultCryptographyError.authenticationFailed
        }
    }

    static func generateRecoveryCode() throws -> String {
        var bytes = Data(count: 32)
        let status = bytes.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, 32, buffer.baseAddress!)
        }
        guard status == errSecSuccess else { throw VaultCryptographyError.randomGenerationFailed }
        return base64URL(bytes)
    }

    static func wrapVaultKeyForRecovery(
        _ vaultKey: SymmetricKey,
        recoveryCode: String,
        context: VaultRecoveryWrapContext
    ) throws -> VaultRecoveryKeyWrapEnvelope {
        let recoveryMaterial = try decodeRecoveryCode(recoveryCode)
        let wrappingKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: recoveryMaterial),
            salt: recoveryWrapSalt,
            info: context.authenticatedData,
            outputByteCount: 32
        )
        let rawVaultKey = vaultKey.withUnsafeBytes { Data($0) }
        let box = try AES.GCM.seal(
            rawVaultKey,
            using: wrappingKey,
            authenticating: context.authenticatedData
        )
        guard let combined = box.combined else { throw VaultCryptographyError.invalidEnvelope }
        return VaultRecoveryKeyWrapEnvelope(
            version: 1,
            keyVersion: context.keyVersion,
            wrappedKey: combined.base64EncodedString()
        )
    }

    static func unwrapVaultKeyFromRecovery(
        _ envelope: VaultRecoveryKeyWrapEnvelope,
        recoveryCode: String,
        context: VaultRecoveryWrapContext
    ) throws -> SymmetricKey {
        guard envelope.version == 1 else { throw VaultCryptographyError.unsupportedVersion }
        guard envelope.keyVersion == context.keyVersion, context.keyVersion > 0 else {
            throw VaultCryptographyError.invalidKeyVersion
        }
        guard let wrappedData = Data(base64Encoded: envelope.wrappedKey) else {
            throw VaultCryptographyError.invalidEnvelope
        }
        let recoveryMaterial = try decodeRecoveryCode(recoveryCode)
        let wrappingKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: recoveryMaterial),
            salt: recoveryWrapSalt,
            info: context.authenticatedData,
            outputByteCount: 32
        )

        do {
            let box = try AES.GCM.SealedBox(combined: wrappedData)
            let rawVaultKey = try AES.GCM.open(
                box,
                using: wrappingKey,
                authenticating: context.authenticatedData
            )
            guard rawVaultKey.count == 32 else { throw VaultCryptographyError.invalidEnvelope }
            return SymmetricKey(data: rawVaultKey)
        } catch let error as VaultCryptographyError {
            throw error
        } catch {
            throw VaultCryptographyError.authenticationFailed
        }
    }

    static func sign(_ challenge: Data, using identity: VaultDeviceIdentity) throws -> Data {
        try identity.signingPrivateKey.signature(for: challenge).rawRepresentation
    }

    static func verify(
        signature: Data,
        challenge: Data,
        signingPublicKeyBase64: String
    ) -> Bool {
        guard let publicKeyData = Data(base64Encoded: signingPublicKeyBase64),
              let publicKey = try? P256.Signing.PublicKey(x963Representation: publicKeyData),
              let signature = try? P256.Signing.ECDSASignature(rawRepresentation: signature) else {
            return false
        }
        return publicKey.isValidSignature(signature, for: challenge)
    }

    static func keyConfirmation(for vaultKey: SymmetricKey) -> String {
        Data(HMAC<SHA256>.authenticationCode(
            for: Data("miloom-vault-key-confirmation-v1".utf8),
            using: vaultKey
        )).base64EncodedString()
    }

    static func approvalChallenge(
        userID: UUID,
        challengeID: UUID,
        actorDeviceID: UUID,
        targetDeviceID: UUID,
        keyVersion: Int,
        nonce: String,
        ephemeralPublicKey: String,
        wrappedVaultKey: String
    ) -> Data {
        Data([
            "miloom-vault-approval-v1",
            userID.uuidString.lowercased(),
            challengeID.uuidString.lowercased(),
            actorDeviceID.uuidString.lowercased(),
            targetDeviceID.uuidString.lowercased(),
            String(keyVersion),
            nonce,
            ephemeralPublicKey,
            wrappedVaultKey
        ].joined(separator: "|").utf8)
    }

    private static func decodeRecoveryCode(_ code: String) throws -> Data {
        var base64 = code.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64), data.count == 32 else {
            throw VaultCryptographyError.invalidRecoveryCode
        }
        return data
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

final class VaultDeviceKeyStore {
    static let shared = VaultDeviceKeyStore()

    private let service = "com.vibing.miloom.vault-device.v1"

    private init() {}

    func loadOrCreateIdentity(for userID: UUID) throws -> VaultDeviceIdentity {
        let agreementAccount = "\(userID.uuidString.lowercased()).agreement"
        let signingAccount = "\(userID.uuidString.lowercased()).signing"

        let agreementKey: P256.KeyAgreement.PrivateKey
        if let data = try load(account: agreementAccount) {
            agreementKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: data)
        } else {
            agreementKey = P256.KeyAgreement.PrivateKey()
            try save(agreementKey.rawRepresentation, account: agreementAccount)
        }

        let signingKey: P256.Signing.PrivateKey
        if let data = try load(account: signingAccount) {
            signingKey = try P256.Signing.PrivateKey(rawRepresentation: data)
        } else {
            signingKey = P256.Signing.PrivateKey()
            try save(signingKey.rawRepresentation, account: signingAccount)
        }

        return VaultDeviceIdentity(
            agreementPrivateKey: agreementKey,
            signingPrivateKey: signingKey
        )
    }

    private func load(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw VaultCryptographyError.keychainFailure(status)
        }
        return data
    }

    private func save(_ data: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw VaultCryptographyError.keychainFailure(status)
        }
    }
}

extension DataRepository {
    func measure<T>(_ name: String, _ operation: () async throws -> T) async rethrows -> T {
        let start = Date()
        let result = try await operation()
        let end = Date()
        let time = end.timeIntervalSince(start)
        AppDiagnostics.duration("data", name, seconds: time)
        
        return result
    }
}
