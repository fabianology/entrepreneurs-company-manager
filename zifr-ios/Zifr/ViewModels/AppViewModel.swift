import Foundation
import SwiftData
import Observation

@Observable
final class AppViewModel {
    // MARK: - Navigation State
    var selectedCompany: Company?
    var activeTab: CompanyTab = .subscriptions
    var searchQuery: String = ""
    var showSearch: Bool = false
    var quote: String = ""

    enum CompanyTab: String, CaseIterable {
        case subscriptions = "Services"
        case financial = "Financial"
        case documents = "Docs"

        var icon: String {
            switch self {
            case .subscriptions: return "square.3.layers.3d"
            case .financial:     return "creditcard"
            case .documents:     return "doc.text"
            }
        }
    }

    // MARK: - CRUD: Companies
    func addCompany(context: ModelContext, name: String, structure: String, colorHex: String, logoData: Data?, website: String) {
        let company = Company(name: name, structure: structure, colorHex: colorHex, logoData: logoData, website: website)
        context.insert(company)
        try? context.save()
    }

    func updateCompany(_ company: Company, context: ModelContext) {
        company.lastModified = Date()
        try? context.save()
    }

    func deleteCompany(_ company: Company, context: ModelContext) {
        context.delete(company)
        try? context.save()
        if selectedCompany?.id == company.id { selectedCompany = nil }
    }

    func touchCompany(_ company: Company, context: ModelContext) {
        company.lastViewed = Date()
        try? context.save()
    }

    // MARK: - CRUD: Subscriptions
    func addSubscription(context: ModelContext, companyId: String) -> Subscription {
        let sub = Subscription(companyId: companyId)
        context.insert(sub)
        return sub
    }

    func saveSub(_ sub: Subscription, context: ModelContext) {
        sub.lastUpdated = Date()
        try? context.save()
    }

    func deleteSub(_ sub: Subscription, context: ModelContext) {
        context.delete(sub)
        try? context.save()
    }

    // MARK: - CRUD: Financial Cards
    func addCard(context: ModelContext, companyId: String) -> FinancialCard {
        let card = FinancialCard(companyId: companyId)
        context.insert(card)
        return card
    }

    func saveCard(_ card: FinancialCard, context: ModelContext) {
        try? context.save()
    }

    func deleteCard(_ card: FinancialCard, context: ModelContext) {
        context.delete(card)
        try? context.save()
    }

    // MARK: - CRUD: Institutions
    func addInstitution(context: ModelContext, companyId: String) -> Institution {
        let inst = Institution(companyId: companyId)
        context.insert(inst)
        return inst
    }

    func saveInstitution(_ inst: Institution, context: ModelContext) {
        try? context.save()
    }

    func deleteInstitution(_ inst: Institution, context: ModelContext) {
        context.delete(inst)
        try? context.save()
    }

    // MARK: - CRUD: Loans
    func addLoan(context: ModelContext, companyId: String) -> Loan {
        let loan = Loan(companyId: companyId)
        context.insert(loan)
        return loan
    }

    func saveLoan(_ loan: Loan, context: ModelContext) {
        try? context.save()
    }

    func deleteLoan(_ loan: Loan, context: ModelContext) {
        context.delete(loan)
        try? context.save()
    }

    // MARK: - CRUD: Documents
    func addDocument(context: ModelContext, companyId: String) -> CompanyDocument {
        let doc = CompanyDocument(companyId: companyId)
        context.insert(doc)
        return doc
    }

    func saveDoc(_ doc: CompanyDocument, context: ModelContext) {
        try? context.save()
    }

    func deleteDoc(_ doc: CompanyDocument, context: ModelContext) {
        context.delete(doc)
        try? context.save()
    }

    // MARK: - Monthly Burn
    func monthlyBurn(for company: Company, subscriptions: [Subscription]) -> Double {
        subscriptions
            .filter { $0.companyId == company.id }
            .reduce(0) { acc, sub in
                let base = sub.billingCycle == "Monthly" ? sub.cost : sub.cost / 12
                let extras = sub.subServices.filter { $0.status != .paused }.reduce(0.0) { $0 + $1.cost }
                return acc + base + extras
            }
    }

    // MARK: - AI
    func loadQuote() async {
        let q = await GeminiService.shared.getEntrepreneurialQuote()
        await MainActor.run { self.quote = q }
    }

    // MARK: - Global Search Results
    struct SearchResult: Identifiable {
        let id = UUID()
        let type: SearchResultType
        let title: String
        let subtitle: String
        let companyId: String
        let tab: CompanyTab
    }

    enum SearchResultType { case company, subscription, financial, document }

    func globalSearch(query: String, companies: [Company], subscriptions: [Subscription], cards: [FinancialCard], institutions: [Institution], loans: [Loan], documents: [CompanyDocument]) -> [SearchResult] {
        guard !query.isEmpty else { return [] }
        let q = query.lowercased()
        var results: [SearchResult] = []

        for c in companies where c.name.lowercased().contains(q) {
            results.append(.init(type: .company, title: c.name, subtitle: c.structure, companyId: c.id, tab: .subscriptions))
        }
        for s in subscriptions where s.name.lowercased().contains(q) {
            let company = companies.first { $0.id == s.companyId }
            results.append(.init(type: .subscription, title: s.name, subtitle: company?.name ?? "", companyId: s.companyId, tab: .subscriptions))
        }
        for card in cards where card.name.lowercased().contains(q) || card.institutionName.lowercased().contains(q) {
            let company = companies.first { $0.id == card.companyId }
            results.append(.init(type: .financial, title: card.name, subtitle: company?.name ?? "", companyId: card.companyId, tab: .financial))
        }
        for inst in institutions where inst.name.lowercased().contains(q) {
            let company = companies.first { $0.id == inst.companyId }
            results.append(.init(type: .financial, title: inst.name, subtitle: company?.name ?? "", companyId: inst.companyId, tab: .financial))
        }
        for loan in loans where loan.name.lowercased().contains(q) || loan.lender.lowercased().contains(q) {
            let company = companies.first { $0.id == loan.companyId }
            results.append(.init(type: .financial, title: loan.name, subtitle: company?.name ?? "", companyId: loan.companyId, tab: .financial))
        }
        for doc in documents where doc.name.lowercased().contains(q) {
            let company = companies.first { $0.id == doc.companyId }
            results.append(.init(type: .document, title: doc.name, subtitle: company?.name ?? "", companyId: doc.companyId, tab: .documents))
        }
        return results
    }
}
