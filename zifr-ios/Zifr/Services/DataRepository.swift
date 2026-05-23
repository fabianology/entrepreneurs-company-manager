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
            
            let (companies, subscriptions, institutions, cards, loans, documents, shares) = try await (
                fetchCompanies, fetchSubscriptions, fetchInstitutions, fetchCards, fetchLoans, fetchDocuments, fetchShares
            )
            
            await MainActor.run {
                appState.companies = companies
                appState.subscriptions = subscriptions
                appState.institutions = institutions
                appState.cards = cards
                appState.loans = loans
                appState.documents = documents
                appState.resourceShares = shares
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
        try await client.from("companies").update(company).eq("id", value: company.id).execute()
    }
    func deleteCompany(_ id: UUID) async throws {
        try await client.from("companies").delete().eq("id", value: id).execute()
    }
    
    // MARK: - Subscriptions
    func insertSubscription(_ sub: Subscription) async throws {
        try await client.from("subscriptions").insert(sub).execute()
    }
    func updateSubscription(_ sub: Subscription) async throws {
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
}
