import Foundation
import Supabase

extension DataRepository {
    private var expenseClient: SupabaseClient { SupabaseService.shared.client }

    @MainActor
    func refreshBusinessExpenses(appState: AppState) async throws {
        let owner = try await expenseClient.auth.session.user.id
        async let reviews: [BusinessExpenseReview] = expenseClient.rpc("get_business_expense_reviews").execute().value
        async let settings: [BusinessExpenseSettings] = expenseClient.from("business_expense_settings").select().eq("user_id", value: owner).execute().value
        async let profiles: [BusinessExpenseProfile] = expenseClient.from("business_expense_profiles").select().eq("user_id", value: owner).execute().value
        async let jobs: [BusinessExpenseJob] = expenseClient.from("business_expense_jobs").select().eq("user_id", value: owner).order("created_at", ascending: false).limit(1).execute().value
        async let taxObligations: [PortfolioObligation] = expenseClient.from("obligations").select().eq("owner_user_id", value: owner).eq("kind", value: "business_expense_review").execute().value
        async let accounts: [BusinessExpenseAccount] = expenseClient.from("plaid_accounts").select("account_id,canonical_account_id,persistent_account_id,name").eq("user_id", value: owner).eq("status", value: "active").execute().value
        let fetched = try await (reviews, settings, profiles, jobs, taxObligations, accounts)
        guard (try? await expenseClient.auth.session.user.id) == owner else { return }
        appState.businessExpenseReviews = fetched.0
        appState.businessExpenseSettings = fetched.1.first ?? BusinessExpenseSettings()
        appState.businessExpenseProfiles = fetched.2
        appState.businessExpenseAccounts = fetched.5
        appState.businessExpenseJob = fetched.3.first
        appState.obligations.removeAll { $0.kind == "business_expense_review" }
        appState.obligations.append(contentsOf: fetched.4)
        appState.businessExpenseLoadError = nil
    }

    func deleteBusinessExpenseHistory() async throws {
        try await expenseClient.rpc("delete_business_expense_data").execute()
    }

    func configureBusinessExpenses(settings: BusinessExpenseSettings, profiles: [BusinessExpenseProfile], resetLearning: Bool = false) async throws {
        struct Params: Encodable {
            var p_enabled: Bool; var p_excluded_accounts: [String]; var p_profiles: [BusinessExpenseProfile]
            var p_expected_revision: Int; var p_reset_learning: Bool
        }
        try await expenseClient.rpc("configure_business_expenses", params: Params(p_enabled: settings.enabled, p_excluded_accounts: settings.excludedAccountIds, p_profiles: profiles, p_expected_revision: settings.revision, p_reset_learning: resetLearning)).execute()
    }

    func saveBusinessExpense(transactionId: UUID?, review: BusinessExpenseReview?, decision: String, allocation: BusinessExpenseAllocation?, acknowledge: Bool = false, mutationId: UUID) async throws -> UUID {
        struct Params: Encodable {
            var p_transaction_id: UUID?; var p_review_id: UUID?; var p_expected_revision: Int
            var p_mutation_id: UUID; var p_decision: String; var p_allocation: BusinessExpenseAllocation?
            var p_acknowledge_source: Bool
            enum CodingKeys: String, CodingKey { case p_transaction_id, p_review_id, p_expected_revision, p_mutation_id, p_decision, p_allocation, p_acknowledge_source }
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(p_transaction_id, forKey: .p_transaction_id); try c.encode(p_review_id, forKey: .p_review_id)
                try c.encode(p_expected_revision, forKey: .p_expected_revision); try c.encode(p_mutation_id, forKey: .p_mutation_id)
                try c.encode(p_decision, forKey: .p_decision); try c.encode(p_allocation, forKey: .p_allocation)
                try c.encode(p_acknowledge_source, forKey: .p_acknowledge_source)
            }
        }
        return try await expenseClient.rpc("save_business_expense", params: Params(p_transaction_id: transactionId, p_review_id: review?.id, p_expected_revision: review?.revision ?? 1, p_mutation_id: mutationId, p_decision: decision, p_allocation: allocation, p_acknowledge_source: acknowledge)).execute().value
    }

    func startBusinessExpenseScan(from: Date, to: Date) async throws -> UUID {
        struct Params: Encodable { var p_date_from: String; var p_date_to: String }
        return try await expenseClient.rpc("start_business_expense_scan", params: Params(p_date_from: BusinessExpensePolicy.dateString(from), p_date_to: BusinessExpensePolicy.dateString(to))).execute().value
    }
    func processBusinessExpenseScan(jobId: UUID) async throws {
        struct Body: Encodable { var job_id: UUID }
        try await expenseClient.functions.invoke("screen-business-expenses", options: FunctionInvokeOptions(body: Body(job_id: jobId)))
    }
    func attachBusinessExpenseReceipt(review: BusinessExpenseReview, data: Data, name: String, contentType: String) async throws {
        guard data.count <= 20 * 1024 * 1024 else { throw NSError(domain: "BusinessExpenses", code: 1, userInfo: [NSLocalizedDescriptionKey: "Choose a receipt smaller than 20 MB."]) }
        let owner = try await expenseClient.auth.session.user.id
        let ext = URL(fileURLWithPath: name).pathExtension.lowercased()
        let path = "\(owner.uuidString.lowercased())/expense-\(UUID().uuidString).\(ext.isEmpty ? "pdf" : ext)"
        // No local-file success fallback: only verified cloud evidence is attached.
        try await expenseClient.storage.from("CompanyDocuments").upload(path: path, file: data, options: FileOptions(contentType: contentType, upsert: false))
        struct Params: Encodable { var p_review_id: UUID; var p_name: String; var p_path: String; var p_expected_revision: Int }
        do {
            try await expenseClient.rpc("attach_business_expense_document", params: Params(p_review_id: review.id, p_name: name, p_path: path, p_expected_revision: review.revision)).execute()
        } catch {
            // A transport failure may follow a committed attachment. Keep the
            // object until server orphan cleanup can establish it is unreferenced.
            throw error
        }
    }
    func unlinkBusinessExpenseReceipt(review: BusinessExpenseReview, documentId: UUID) async throws {
        struct Params: Encodable { var p_review_id: UUID; var p_document_id: UUID; var p_expected_revision: Int }
        try await expenseClient.rpc("detach_business_expense_document", params: Params(p_review_id: review.id, p_document_id: documentId, p_expected_revision: review.revision)).execute()
    }
    func prepareBusinessExpenseExport(companyId: UUID, from: Date, to: Date, incomplete: Bool, mutationId: UUID) async throws -> BusinessExpenseExport {
        struct Params: Encodable {
            var p_company_id: UUID; var p_date_from: String; var p_date_to: String; var p_incomplete: Bool; var p_mutation_id: UUID
        }
        return try await expenseClient.rpc("prepare_business_expense_export", params: Params(p_company_id: companyId, p_date_from: BusinessExpensePolicy.dateString(from), p_date_to: BusinessExpensePolicy.dateString(to), p_incomplete: incomplete, p_mutation_id: mutationId)).execute().value
    }
}
