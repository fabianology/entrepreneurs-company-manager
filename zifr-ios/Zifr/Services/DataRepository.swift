import Foundation
import Supabase
import CryptoKit
import Security

class DataRepository {
    static let shared = DataRepository()
    private var client: SupabaseClient { SupabaseService.shared.client }
    private static let transactionPageSize = 1_000

    // Keep this projection compatible with the production transaction schema.
    // `merchant_website` is optional enrichment and has not been deployed to every
    // environment; Transaction's custom decoder safely leaves it nil when omitted.
    private static let transactionColumns = "id,user_id,company_id,institution_id,plaid_transaction_id,account_id,canonical_account_id,amount,currency,date,authorized_date,name,merchant_name,merchant_website,merchant_logo_url,payment_channel,personal_finance_primary,personal_finance_detailed,personal_finance_confidence,category,pending"

    private func fetchCompanies() async -> Result<[Company], Error> {
        do {
            let companies: [Company] = try await client
                .from("companies")
                .select()
                .execute()
                .value
            return .success(companies)
        } catch {
            print("Failed to fetch companies: \(error)")
            return .failure(error)
        }
    }

    private func refreshMyObligations() async -> Bool {
        do {
            try await client.rpc("refresh_my_miloom_obligations").execute()
            return true
        } catch {
            print("Failed to refresh owner briefing obligations: \(error)")
            return false
        }
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
            print("Failed to fetch transactions! Error details: \(String(describing: error))")
            if let decodingError = error as? DecodingError {
                print("Decoding error: \(decodingError)")
            }
            if let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileURL = docsDir.appendingPathComponent("tx_error.txt")
                try? "\(error)".write(to: fileURL, atomically: true, encoding: .utf8)
            }
            return [] 
        }
    }

    @MainActor
    func refreshTransactions(appState: AppState) async throws {
        let transactions: [Transaction] = try await measure("transactions") {
            try await fetchTransactions()
        }
        appState.transactions = transactions
    }

    private func safeFetchShares() async -> [ResourceShare] {
        do { return try await client.from("resource_shares").select().execute().value }
        catch {
            print("Failed to fetch resource shares! (Table may not exist yet): \(error)")
            return []
        }
    }

    @MainActor
    func fetchAllData(appState: AppState) async {
        if appState.isLoading { return }
        appState.isLoading = true
        defer { appState.isLoading = false }

        // Companies drive the first dashboard paint. Publish them immediately rather
        // than holding them until every secondary portfolio request has completed.
        let fetchedCompaniesResult = await measure("companies") { await fetchCompanies() }
        if case .success(let fetchedCompanies) = fetchedCompaniesResult {
            appState.companies = fetchedCompanies
        }

        async let fSubscriptions: [Subscription] = measure("subscriptions") { (try? await client.from("subscriptions").select().execute().value) ?? [] }
        async let fInstitutions: [Institution] = measure("institutions") { (try? await client.from("institutions").select().execute().value) ?? [] }
        async let fCards: [FinancialCard] = measure("cards") { (try? await client.from("financial_cards").select().execute().value) ?? [] }
        async let fLoans: [Loan] = measure("loans") { (try? await client.from("loans").select().execute().value) ?? [] }
        async let fLoanPayments: [LoanPayment] = measure("loan_payments") { (try? await client.from("loan_payments").select().execute().value) ?? [] }
        async let fDocuments: [CompanyDocument] = measure("documents") { (try? await client.from("company_documents").select().execute().value) ?? [] }
        async let fShares = measure("shares") { await safeFetchShares() }
        async let fActivity: [ActivityLog] = measure("activity_logs") { (try? await client.from("activity_logs").select().order("created_at", ascending: false).execute().value) ?? [] }
        async let fNotifications: [AppNotification] = measure("app_notifications") { (try? await client.from("app_notifications").select().order("created_at", ascending: false).execute().value) ?? [] }
        async let fPrefs: [UserPreferences] = measure("user_preferences") { (try? await client.from("user_preferences").select().execute().value) ?? [] }
        async let fPlaidItems: [PlaidItemSummary] = measure("plaid_items") {
            (try? await client
                .from("plaid_items")
                .select("id,company_id,institution_id,institution_name,status,error_code,last_synced_at,created_at")
                .execute()
                .value) ?? []
        }
        async let fConnections: [ResourceConnection] = measure("resource_connections") { (try? await client.from("resource_connections").select().execute().value) ?? [] }
        async let fObligations: [PortfolioObligation] = measure("obligations") { (try? await client.from("obligations").select().order("due_at", ascending: true).execute().value) ?? [] }
        async let fObligationRefresh = refreshMyObligations()
        async let fTransactions = measure("transactions") { await safeFetchTransactions() }
        
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
        
        let secureSubs = fetchedSubscriptions.map { s -> Subscription in var m = s; m.password = SecurityService.shared.decrypt(s.password); return m }
        let secureInst = fetchedInstitutions.map { decryptInstitutionSecrets($0) }
        let secureCards = fetchedCards.map { c -> FinancialCard in var m = c; m.password = SecurityService.shared.decrypt(c.password); return m }
        
        let paymentsByLoan = Dictionary(grouping: fetchedLoanPayments, by: { $0.loanId })
        let combinedLoans = fetchedLoans.map { loan -> Loan in
            var l = loan
            l.payments = paymentsByLoan[loan.id] ?? []
            return l
        }
        
        let session = try? await client.auth.session
        let currentUserId = session?.user.id
        
        appState.subscriptions = secureSubs
        appState.institutions = secureInst
        appState.cards = secureCards
        appState.loans = combinedLoans
        appState.documents = fetchedDocuments
        appState.plaidItems = fetchedPlaidItems
        appState.resourceShares = shares
        appState.activityLogs = fetchedActivityLogs
        appState.notifications = fetchedNotifications
        appState.userPreferences = fetchedPreferences.first
        appState.transactions = transactions
        appState.resourceConnections = fetchedConnections
        appState.obligations = fetchedObligations

        if let currentUserId {
            let generatedConnections = PortfolioConnectionEngine.buildConnections(appState: appState, ownerUserId: currentUserId)
            let existingEdges = Set(fetchedConnections.map(Self.connectionIdentity))
            let newConnections = generatedConnections.filter { !existingEdges.contains(Self.connectionIdentity($0)) }
            if !newConnections.isEmpty {
                try? await upsertConnections(newConnections)
                appState.resourceConnections.append(contentsOf: newConnections)
            }

        }
        // Write count to a file we can read from the host
        if let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = docsDir.appendingPathComponent("tx_count.txt")
            try? "\(transactions.count)".write(to: fileURL, atomically: true, encoding: .utf8)
        }

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
    
    // MARK: - Companies
    func insertCompany(_ company: Company) async throws {
        try await client.from("companies").insert(company).execute()
    }
    func updateCompany(_ company: Company) async throws {
        if let session = try? await client.auth.session, company.userId != session.user.id {
            let log = ActivityLog(userId: company.userId, actorEmail: session.user.email ?? "Someone", actionType: "updated_company", message: "\(session.user.email ?? "Someone") updated the shared company '\(company.name)'.", resourceId: company.id, resourceType: "company")
            try? await insertActivityLog(log)
        }
        try await client.from("companies").update(company).eq("id", value: company.id).execute()
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
        }
        let params = LeaveRPCParams(p_resource_id: resourceId)
        try await client.rpc("leave_resource", params: params).execute()
    }
    
    // MARK: - Subscriptions
    func insertSubscription(_ sub: Subscription) async throws {
        var secureSub = sub; secureSub.password = SecurityService.shared.encrypt(secureSub.password)
        try await client.from("subscriptions").insert(secureSub).execute()
    }
    func updateSubscription(_ sub: Subscription) async throws {
        if let session = try? await client.auth.session, sub.userId != session.user.id {
            let log = ActivityLog(userId: sub.userId, actorEmail: session.user.email ?? "Someone", actionType: "updated_subscription", message: "\(session.user.email ?? "Someone") updated the shared subscription '\(sub.name)'.", resourceId: sub.id, resourceType: "subscription")
            try? await insertActivityLog(log)
        }
        var secureSub = sub; secureSub.password = SecurityService.shared.encrypt(secureSub.password)
        try await client.from("subscriptions").update(secureSub).eq("id", value: sub.id).execute()
    }
    func deleteSubscription(_ id: UUID) async throws {
        try await client.from("subscriptions").delete().eq("id", value: id).execute()
    }
    
    // MARK: - Financial Cards
    func insertCard(_ card: FinancialCard) async throws {
        var secureCard = card; secureCard.password = SecurityService.shared.encrypt(secureCard.password)
        try await client.from("financial_cards").insert(secureCard).execute()
    }
    func updateCard(_ card: FinancialCard) async throws {
        if let session = try? await client.auth.session, card.userId != session.user.id {
            let log = ActivityLog(userId: card.userId, actorEmail: session.user.email ?? "Someone", actionType: "updated_card", message: "\(session.user.email ?? "Someone") updated the shared card '\(card.name)'.", resourceId: card.id, resourceType: "card")
            try? await insertActivityLog(log)
        }
        var secureCard = card; secureCard.password = SecurityService.shared.encrypt(secureCard.password)
        try await client.from("financial_cards").update(secureCard).eq("id", value: card.id).execute()
    }
    func upsertCard(_ card: FinancialCard) async throws {
        var secureCard = card
        secureCard.password = SecurityService.shared.encrypt(secureCard.password)
        try await client.from("financial_cards").upsert(secureCard).execute()
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
        if let session = try? await client.auth.session, inst.userId != session.user.id {
            let log = ActivityLog(userId: inst.userId, actorEmail: session.user.email ?? "Someone", actionType: "updated_institution", message: "\(session.user.email ?? "Someone") updated the shared institution '\(inst.name)'.", resourceId: inst.id, resourceType: "institution")
            try? await insertActivityLog(log)
        }
        let secureInst = encryptInstitutionSecrets(inst)
        try await client.from("institutions").update(secureInst).eq("id", value: inst.id).execute()
    }
    func upsertInstitution(_ inst: Institution) async throws {
        let secureInst = encryptInstitutionSecrets(inst)
        try await client.from("institutions").upsert(secureInst).execute()
    }

    private func encryptInstitutionSecrets(_ institution: Institution) -> Institution {
        var secured = institution
        secured.password = SecurityService.shared.encrypt(secured.password)
        secured.accounts = secured.accounts.map { account in
            var securedAccount = account
            securedAccount.accountNumber = SecurityService.shared.encrypt(account.accountNumber)
            securedAccount.routingNumber = SecurityService.shared.encrypt(account.routingNumber)
            securedAccount.wireRoutingNumber = SecurityService.shared.encrypt(account.wireRoutingNumber)
            return securedAccount
        }
        return secured
    }

    private func decryptInstitutionSecrets(_ institution: Institution) -> Institution {
        var decrypted = institution
        decrypted.password = SecurityService.shared.decrypt(decrypted.password)
        decrypted.accounts = decrypted.accounts.map { account in
            var decryptedAccount = account
            decryptedAccount.accountNumber = SecurityService.shared.decrypt(account.accountNumber)
            decryptedAccount.routingNumber = SecurityService.shared.decrypt(account.routingNumber)
            decryptedAccount.wireRoutingNumber = SecurityService.shared.decrypt(account.wireRoutingNumber)
            return decryptedAccount
        }
        return decrypted
    }
    func deleteInstitution(_ id: UUID) async throws {
        // Optional Plaid backend cleanup
        struct Request: Encodable { let institution_id: UUID }
        if let payload = try? JSONEncoder().encode(Request(institution_id: id)) {
            let options = FunctionInvokeOptions(
                method: .post,
                headers: ["Content-Type": "application/json"],
                body: payload
            )
            _ = try? await client.functions.invoke("remove-plaid-item", options: options)
        }
        
        // Delete from institutions table
        try await client.from("institutions").delete().eq("id", value: id).execute()
    }
    
    // MARK: - Loans
    func insertLoan(_ loan: Loan) async throws {
        try await client.from("loans").insert(loan).execute()
        if let payments = loan.payments, !payments.isEmpty {
            try? await client.from("loan_payments").insert(payments).execute()
        }
    }
    func updateLoan(_ loan: Loan) async throws {
        if let session = try? await client.auth.session, loan.userId != session.user.id {
            let log = ActivityLog(userId: loan.userId, actorEmail: session.user.email ?? "Someone", actionType: "updated_loan", message: "\(session.user.email ?? "Someone") updated the shared loan '\(loan.name)'.", resourceId: loan.id, resourceType: "loan")
            try? await insertActivityLog(log)
        }
        try await client.from("loans").update(loan).eq("id", value: loan.id).execute()
        
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
        if let session = try? await client.auth.session, doc.userId != session.user.id {
            let log = ActivityLog(userId: doc.userId, actorEmail: session.user.email ?? "Someone", actionType: "updated_document", message: "\(session.user.email ?? "Someone") updated the shared document '\(doc.name)'.", resourceId: doc.id, resourceType: "document")
            try? await insertActivityLog(log)
        }
        try await client.from("company_documents").update(doc).eq("id", value: doc.id).execute()
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
    func inviteUser(email: String, role: String, resourceId: UUID, resourceType: String, senderDisplayName: String?) async throws {
        print("🚀 [Sharing] Initiating invitation for \(email) with role: \(role) to resource \(resourceType): \(resourceId)")
        
        guard let currentUser = try? await client.auth.session.user else {
            print("❌ [Sharing] Failed to get current user session.")
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in."])
        }
        
        print("✅ [Sharing] Current user identified: \(currentUser.id)")
        
        let invitation = ResourceInvitation(
            resourceId: resourceId,
            resourceType: resourceType,
            email: email,
            role: role,
            invitedBy: currentUser.id,
            senderEmail: currentUser.email,
            senderDisplayName: senderDisplayName
        )
        
        do {
            print("⏳ [Sharing] Calling secure RPC to process share or invitation...")
            
            struct ShareRPCParams: Encodable {
                let p_email: String
                let p_role: String
                let p_resource_id: UUID
                let p_resource_type: String
                let p_invited_by: UUID
                let p_sender_email: String?
                let p_sender_display_name: String?
            }
            
            struct ShareRPCResponse: Decodable {
                let status: String
            }
            
            let params = ShareRPCParams(
                p_email: email,
                p_role: role,
                p_resource_id: resourceId,
                p_resource_type: resourceType,
                p_invited_by: currentUser.id,
                p_sender_email: currentUser.email,
                p_sender_display_name: senderDisplayName
            )
            
            let response: ShareRPCResponse = try await client.rpc("share_resource", params: params).execute().value
            
            if response.status == "shared_directly" {
                print("✅ [Sharing] User already has an account. Shared directly to their dashboard. No email needed.")
                return // Skip email
            }
            
            print("✅ [Sharing] User not found. Invitation created. Proceeding to send email.")
            
            // Invoke the edge function to send the email
            struct ShareEmailPayload: Encodable {
                let email: String
                let role: String
                let resourceType: String
                let inviterId: UUID
            }
            
            let payload = ShareEmailPayload(
                email: email,
                role: role,
                resourceType: resourceType,
                inviterId: currentUser.id
            )
            
            print("⏳ [Sharing] Invoking 'send-share-email' edge function...")
            if let encodedPayload = try? JSONEncoder().encode(payload) {
                let options = FunctionInvokeOptions(method: .post, headers: ["Content-Type": "application/json"], body: encodedPayload)
                do {
                    try await client.functions.invoke("send-share-email", options: options)
                    print("✅ [Sharing] Successfully invoked edge function.")
                } catch {
                    print("⚠️ [Sharing] Edge function failed (likely unverified Resend domain), but invitation was saved: \(error.localizedDescription)")
                    // We don't throw here so the UI still shows success for the database insertion
                }
            }
            
        } catch {
            print("❌ [Sharing] Database RPC or edge function failed: \(error.localizedDescription)")
            throw error
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
            print("Supabase upload to 'CompanyDocuments' failed, trying local fallback: \(error)")
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
    
    // MARK: - Revoke Shared Access
    func revokeResourceShare(invitationId: UUID) async throws {
        try await client.from("resource_invitations")
            .delete()
            .eq("id", value: invitationId)
            .execute()
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
        guard let string = string, !string.isEmpty, let key = symmetricKey else { return string }
        
        // Don't double encrypt
        if string.starts(with: "enc:") { return string }
        
        do {
            let data = Data(string.utf8)
            let sealedBox = try AES.GCM.seal(data, using: key)
            if let combined = sealedBox.combined {
                return "enc:" + combined.base64EncodedString()
            }
        } catch {
            print("Encryption error: \(error)")
        }
        return string
    }
    
    func decrypt(_ string: String?) -> String? {
        guard let string = string, string.starts(with: "enc:") else { return string }
        guard let key = symmetricKey else { return nil }
        
        let base64 = String(string.dropFirst(4))
        guard let combined = Data(base64Encoded: base64) else { return string }
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: combined)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            print("Decryption error: \(error)")
            return nil
        }
    }
}

extension DataRepository {
    func measure<T>(_ name: String, _ operation: () async throws -> T) async rethrows -> T {
        let start = Date()
        let result = try await operation()
        let end = Date()
        let time = end.timeIntervalSince(start)
        print("⏱️ [DataRepository] \(name) took \(time) seconds")
        
        return result
    }
}
