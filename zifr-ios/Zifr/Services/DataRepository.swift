import Foundation
import Supabase

class DataRepository {
    static let shared = DataRepository()
    private var client: SupabaseClient { SupabaseService.shared.client }
    
    // MARK: - Fetch All Data
    func fetchAllData(appState: AppState) async {
        await MainActor.run { appState.isLoading = true }
        do {
            async let fetchCompanies: [Company] = client.from("companies").select().execute().value
            async let fetchSubscriptions: [Subscription] = client.from("subscriptions").select().execute().value
            async let fetchInstitutions: [Institution] = client.from("institutions").select().execute().value
            async let fetchCards: [FinancialCard] = client.from("financial_cards").select().execute().value
            async let fetchLoans: [Loan] = client.from("loans").select().execute().value
            async let fetchDocuments: [CompanyDocument] = client.from("company_documents").select().execute().value
            async let fetchShares: [ResourceShare] = client.from("resource_shares").select().execute().value
            async let fetchActivityLogs: [ActivityLog] = client.from("activity_logs").select().order("created_at", ascending: false).execute().value
            async let fetchNotifications: [AppNotification] = client.from("app_notifications").select().order("created_at", ascending: false).execute().value
            async let fetchPreferences: [UserPreferences] = client.from("user_preferences").select().execute().value
            
            let (companies, subscriptions, institutions, cards, loans, documents, shares, activityLogs, notifications, preferences) = try await (
                fetchCompanies, fetchSubscriptions, fetchInstitutions, fetchCards, fetchLoans, fetchDocuments, fetchShares, fetchActivityLogs, fetchNotifications, fetchPreferences
            )
            
            await MainActor.run {
                appState.companies = companies
                appState.subscriptions = subscriptions
                appState.institutions = institutions
                appState.cards = cards
                appState.loans = loans
                appState.documents = documents
                appState.resourceShares = shares
                appState.activityLogs = activityLogs
                appState.notifications = notifications
                appState.userPreferences = preferences.first
                appState.isLoading = false
            }
        } catch {
            print("Failed to fetch data: \(error)")
            await MainActor.run {
                appState.error = error.localizedDescription
                appState.isLoading = false
            }
        }
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
        
        try await client.from("resource_shares")
            .delete()
            .eq("resource_id", value: resourceId)
            .eq("user_id", value: session.user.id)
            .execute()
    }
    
    // MARK: - Subscriptions
    func insertSubscription(_ sub: Subscription) async throws {
        try await client.from("subscriptions").insert(sub).execute()
    }
    func updateSubscription(_ sub: Subscription) async throws {
        if let session = try? await client.auth.session, sub.userId != session.user.id {
            let log = ActivityLog(userId: sub.userId, actorEmail: session.user.email ?? "Someone", actionType: "updated_subscription", message: "\(session.user.email ?? "Someone") updated the shared subscription '\(sub.name)'.", resourceId: sub.id, resourceType: "subscription")
            try? await insertActivityLog(log)
        }
        try await client.from("subscriptions").update(sub).eq("id", value: sub.id).execute()
    }
    func deleteSubscription(_ id: UUID) async throws {
        try await client.from("subscriptions").delete().eq("id", value: id).execute()
    }
    
    // MARK: - Financial Cards
    func insertCard(_ card: FinancialCard) async throws {
        try await client.from("financial_cards").insert(card).execute()
    }
    func updateCard(_ card: FinancialCard) async throws {
        if let session = try? await client.auth.session, card.userId != session.user.id {
            let log = ActivityLog(userId: card.userId, actorEmail: session.user.email ?? "Someone", actionType: "updated_card", message: "\(session.user.email ?? "Someone") updated the shared card '\(card.name)'.", resourceId: card.id, resourceType: "card")
            try? await insertActivityLog(log)
        }
        try await client.from("financial_cards").update(card).eq("id", value: card.id).execute()
    }
    func deleteCard(_ id: UUID) async throws {
        try await client.from("financial_cards").delete().eq("id", value: id).execute()
    }
    
    // MARK: - Institutions
    func insertInstitution(_ inst: Institution) async throws {
        try await client.from("institutions").insert(inst).execute()
    }
    func updateInstitution(_ inst: Institution) async throws {
        if let session = try? await client.auth.session, inst.userId != session.user.id {
            let log = ActivityLog(userId: inst.userId, actorEmail: session.user.email ?? "Someone", actionType: "updated_institution", message: "\(session.user.email ?? "Someone") updated the shared institution '\(inst.name)'.", resourceId: inst.id, resourceType: "institution")
            try? await insertActivityLog(log)
        }
        try await client.from("institutions").update(inst).eq("id", value: inst.id).execute()
    }
    func deleteInstitution(_ id: UUID) async throws {
        try await client.from("institutions").delete().eq("id", value: id).execute()
    }
    
    // MARK: - Loans
    func insertLoan(_ loan: Loan) async throws {
        try await client.from("loans").insert(loan).execute()
    }
    func updateLoan(_ loan: Loan) async throws {
        if let session = try? await client.auth.session, loan.userId != session.user.id {
            let log = ActivityLog(userId: loan.userId, actorEmail: session.user.email ?? "Someone", actionType: "updated_loan", message: "\(session.user.email ?? "Someone") updated the shared loan '\(loan.name)'.", resourceId: loan.id, resourceType: "loan")
            try? await insertActivityLog(log)
        }
        try await client.from("loans").update(loan).eq("id", value: loan.id).execute()
    }
    func deleteLoan(_ id: UUID) async throws {
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
    func deleteDocument(_ id: UUID) async throws {
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
    func uploadDocumentFile(fileData: Data, fileName: String, contentType: String) async throws -> URL {
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
            
            let publicUrl = try client.storage
                .from("CompanyDocuments")
                .getPublicURL(path: filePath)
            
            return publicUrl
        } catch {
            print("Supabase upload to 'CompanyDocuments' failed, trying local fallback: \(error)")
            // Fallback: save to app's local documents directory (just like how the scanner does it!)
            let fileManager = FileManager.default
            guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                throw error
            }
            let localURL = documentDirectory.appendingPathComponent(uniqueName)
            try fileData.write(to: localURL)
            return localURL
        }
    }
}
