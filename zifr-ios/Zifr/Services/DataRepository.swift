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
            
            let (companies, subscriptions, institutions, cards, loans, documents) = try await (
                fetchCompanies, fetchSubscriptions, fetchInstitutions, fetchCards, fetchLoans, fetchDocuments
            )
            
            await MainActor.run {
                appState.companies = companies
                appState.subscriptions = subscriptions
                appState.institutions = institutions
                appState.cards = cards
                appState.loans = loans
                appState.documents = documents
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
}
