import SwiftUI
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
    var deepLinkModelId: String? = nil
    var path = NavigationPath()

    enum CompanyTab: String, CaseIterable {
        case subscriptions = "Services"
        case financial = "Financial"
        case documents = "Docs"

        var icon: String {
            switch self {
            case .subscriptions: return "square.3.layers.3d"
            case .financial:     return "dollarsign.bank.building"
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
        let id = company.id
        
        // Manual Cascade Delete: SwiftData's native cascade occasionally leaves orphaned records if they are faulted.
        // Explicitly deleting them by companyId guarantees the database is clean and global search drops them.
        if let subs = try? context.fetch(FetchDescriptor<Subscription>(predicate: #Predicate { $0.companyId == id })) {
            subs.forEach { context.delete($0) }
        }
        if let insts = try? context.fetch(FetchDescriptor<Institution>(predicate: #Predicate { $0.companyId == id })) {
            insts.forEach { context.delete($0) }
        }
        if let cards = try? context.fetch(FetchDescriptor<FinancialCard>(predicate: #Predicate { $0.companyId == id })) {
            cards.forEach { context.delete($0) }
        }
        if let loans = try? context.fetch(FetchDescriptor<Loan>(predicate: #Predicate { $0.companyId == id })) {
            loans.forEach { context.delete($0) }
        }
        if let docs = try? context.fetch(FetchDescriptor<CompanyDocument>(predicate: #Predicate { $0.companyId == id })) {
            docs.forEach { context.delete($0) }
        }

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
        if let company = try? context.fetch(FetchDescriptor<Company>(predicate: #Predicate { $0.id == companyId })).first {
            sub.company = company
        }
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
        if let company = try? context.fetch(FetchDescriptor<Company>(predicate: #Predicate { $0.id == companyId })).first {
            card.company = company
        }
        context.insert(card)
        return card
    }

    func saveCard(_ card: FinancialCard, context: ModelContext) {
        try? context.save()
    }

    func deleteCard(_ card: FinancialCard, context: ModelContext) {
        cleanUpCustomPaymentMethod(name: card.name)
        context.delete(card)
        try? context.save()
    }

    // MARK: - CRUD: Institutions
    func addInstitution(context: ModelContext, companyId: String) -> Institution {
        let inst = Institution(companyId: companyId)
        if let company = try? context.fetch(FetchDescriptor<Company>(predicate: #Predicate { $0.id == companyId })).first {
            inst.company = company
        }
        context.insert(inst)
        return inst
    }

    func saveInstitution(_ inst: Institution, context: ModelContext) {
        try? context.save()
    }

    func deleteInstitution(_ inst: Institution, context: ModelContext) {
        let instName = inst.name
        let instCompanyId = inst.companyId
        
        // Clean up accounts and cards from custom methods
        for acc in inst.accounts {
            cleanUpCustomPaymentMethod(name: acc.name.isEmpty ? acc.type : acc.name)
        }
        
        if let allCards = try? context.fetch(FetchDescriptor<FinancialCard>()) {
            for c in allCards where c.companyId == instCompanyId && c.institutionName == instName {
                cleanUpCustomPaymentMethod(name: c.name)
                context.delete(c)
            }
        }
        
        if let allLoans = try? context.fetch(FetchDescriptor<Loan>()) {
            for l in allLoans where l.companyId == instCompanyId && l.lender == instName {
                context.delete(l)
            }
        }
        
        context.delete(inst)
        try? context.save()
    }
    
    func cleanUpCustomPaymentMethod(name: String) {
        guard !name.isEmpty else { return }
        let key = "userCustomPaymentMethods"
        let stored = UserDefaults.standard.string(forKey: key) ?? ""
        var methods = stored.split(separator: ",").map(String.init)
        if let idx = methods.firstIndex(where: { $0.lowercased() == name.lowercased() }) {
            methods.remove(at: idx)
            UserDefaults.standard.set(methods.joined(separator: ","), forKey: key)
        }
    }

    // MARK: - CRUD: Loans
    func addLoan(context: ModelContext, companyId: String) -> Loan {
        let loan = Loan(companyId: companyId)
        if let company = try? context.fetch(FetchDescriptor<Company>(predicate: #Predicate { $0.id == companyId })).first {
            loan.company = company
        }
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
        if let company = try? context.fetch(FetchDescriptor<Company>(predicate: #Predicate { $0.id == companyId })).first {
            doc.company = company
        }
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

    func totalDebt(for company: Company, loans: [Loan], cards: [FinancialCard]) -> Double {
        let loanDebt = loans.filter { $0.companyId == company.id }.reduce(0) { $0 + $1.remainingBalance }
        let cardDebt = cards.filter { $0.companyId == company.id && $0.type == "Credit" }.reduce(0) { $0 + $1.balance }
        return loanDebt + cardDebt
    }

    func totalCredit(for company: Company, cards: [FinancialCard]) -> Double {
        cards.filter { $0.companyId == company.id && $0.type == "Credit" }.reduce(0) { $0 + $1.limit }
    }

    private let localQuotes = [
        "The best way to predict the future is to create it. - Peter Drucker",
        "The way to get started is to quit talking and begin doing. - Walt Disney",
        "Your time is limited, so don't waste it living someone else's life. - Steve Jobs",
        "If you are not embarrassed by the first version of your product, you've launched too late. - Reid Hoffman",
        "Risk more than others think is safe. Dream more than others think is practical. - Howard Schultz",
        "Ideas are cheap. Execution is everything. - Chris Sacca",
        "Done is better than perfect. - Sheryl Sandberg",
        "Chase the vision, not the money. - Tony Hsieh",
        "Don't find customers for your products, find products for your customers. - Seth Godin",
        "Quality is the best business plan. - John Lasseter",
        "It’s not about ideas. It’s about making ideas happen. - Scott Belsky",
        "If you can't feed a team with two pizzas, it's too large. - Jeff Bezos",
        "Do not be embarrassed by your failures, learn from them and start again. - Richard Branson",
        "Growth and comfort do not coexist. - Ginni Rometty",
        "A brand for a company is like a reputation for a person. - Jeff Bezos",
        "We suffer more often in imagination than in reality. - Seneca",
        "You have power over your mind - not outside events. Realize this, and you will find strength. - Marcus Aurelius",
        "First say to yourself what you would be; and then do what you have to do. - Epictetus",
        "The impediment to action advances action. What stands in the way becomes the way. - Marcus Aurelius",
        "Waste no more time arguing what a good man should be. Be one. - Marcus Aurelius"
    ]

    // MARK: - Quotes
    func loadQuote() async {
        let q = localQuotes.randomElement() ?? ""
        await MainActor.run { self.quote = q }
    }

    // MARK: - Global Search Results
    struct SearchResult: Identifiable {
        let id = UUID()
        let type: SearchResultType
        let title: String
        let subtitle: String
        let companyId: String
        let modelId: String
        let tab: CompanyTab
        var password: String? = nil
        var loginId: String? = nil
        var logoData: Data? = nil
        var externalWebsite: String? = nil
        var isFree: Bool? = nil
        var cost: Double? = nil
        var status: String? = nil
        var last4: String? = nil
        var network: String? = nil
        var paysFor: [String]? = nil
        var cardType: String? = nil

        init(type: SearchResultType, title: String, subtitle: String, companyId: String, modelId: String, tab: CompanyTab, password: String? = nil, loginId: String? = nil, logoData: Data? = nil, externalWebsite: String? = nil, isFree: Bool? = nil, cost: Double? = nil, status: String? = nil, last4: String? = nil, network: String? = nil, paysFor: [String]? = nil, cardType: String? = nil) {
            self.type = type
            self.title = title
            self.subtitle = subtitle
            self.companyId = companyId
            self.modelId = modelId
            self.tab = tab
            self.password = password
            self.loginId = loginId
            self.logoData = logoData
            self.externalWebsite = externalWebsite
            self.isFree = isFree
            self.cost = cost
            self.status = status
            self.last4 = last4
            self.network = network
            self.paysFor = paysFor
            self.cardType = cardType
        }
    }

    enum SearchResultType { case company, subscription, financial, document }

    func globalSearch(query: String, companies: [Company], subscriptions: [Subscription], cards: [FinancialCard], institutions: [Institution], loans: [Loan], documents: [CompanyDocument]) -> [SearchResult] {
        guard !query.isEmpty else { return [] }
        let q = query.lowercased()
        let tokens = q.split(separator: " ").map { String($0) }
        var results: [SearchResult] = []

        let isSubQuery = ["subscription", "subscriptions", "service", "services", "recurring", "monthly", "yearly", "annual", "saas"].contains(q)
        let isBankQuery = ["bank", "banks", "institution", "institutions", "account", "accounts"].contains(q)
        let isCardQuery = ["card", "cards", "credit", "debit", "payment"].contains(q) || q.contains("credit card") || q.contains("debit card")
        let isLoanQuery = ["loan", "loans", "debt", "financing", "borrow"].contains(q)

        func matches(_ payload: String) -> Bool {
            let p = payload.lowercased()
            return tokens.allSatisfy { p.contains($0) }
        }

        for c in companies {
            let payload = [c.name, c.structure, c.companyDescription, c.website].joined(separator: " ")
            if matches(payload) {
                results.append(.init(type: .company, title: c.name, subtitle: c.structure, companyId: c.id, modelId: c.id, tab: .subscriptions, logoData: c.logoData))
            }
        }
        
        for s in subscriptions {
            let companyName = companies.first { $0.id == s.companyId }?.name ?? ""
            var payloadArr: [String] = [s.name, s.loginId, s.paymentMethod, companyName, s.website, s.status, s.billingCycle, s.pricingModel, s.recoveryMethod, s.twoFactorAuth]
            payloadArr.append(s.notes)
            
            payloadArr.append(contentsOf: s.subServices.map { $0.name })
            payloadArr.append(contentsOf: s.subServices.map { $0.purpose })
            payloadArr.append(contentsOf: s.linkedEmails.map { $0.email })
            payloadArr.append(contentsOf: s.linkedEmails.map { $0.provider })
            payloadArr.append(contentsOf: s.linkedEmails.map { $0.usedFor })
            
            let payload = payloadArr.joined(separator: " ")
            
            if isSubQuery || matches(payload) {
                let company = companies.first { $0.id == s.companyId }
                results.append(.init(type: .subscription, title: s.name, subtitle: company?.name ?? "", companyId: s.companyId, modelId: s.id, tab: .subscriptions, password: s.password.isEmpty ? nil : s.password, loginId: s.loginId.isEmpty ? nil : s.loginId, logoData: company?.logoData, externalWebsite: s.website, isFree: s.isFree, cost: s.cost, status: s.status))
            }
        }
        
        for card in cards {
            let companyName = companies.first { $0.id == card.companyId }?.name ?? ""
            let paysForMatch = subscriptions.contains { $0.paymentMethod == card.name && matches($0.name + " " + $0.loginId) }
            
            var payloadArr = [card.name, card.institutionName, card.network, card.last4, card.type, card.status, card.paidFrom, card.cardHolder, card.notes, companyName, card.type + " card", card.type + " cards"]
            payloadArr.append("apr \(card.apr)% \(card.apr)")
            if card.promoApr > 0 || card.promoEnds > Date() {
                payloadArr.append("promo apr \(card.promoApr)% \(card.promoApr)")
                if card.promoApr == 0 {
                    payloadArr.append("0% 0")
                }
            }
            
            let payload = payloadArr.joined(separator: " ")
            
            if isBankQuery || isCardQuery || paysForMatch || matches(payload) {
                let company = companies.first { $0.id == card.companyId }
                let inst = institutions.first { $0.name.lowercased() == card.institutionName.lowercased() }
                results.append(.init(type: .financial, title: card.name, subtitle: company?.name ?? "", companyId: card.companyId, modelId: card.id, tab: .financial, password: card.password.isEmpty ? nil : card.password, loginId: card.login.isEmpty ? nil : card.login, logoData: company?.logoData, externalWebsite: inst?.loginUrl, status: card.status, last4: card.last4, network: card.network, paysFor: subscriptions.filter { $0.paymentMethod == card.name }.map { $0.name }, cardType: card.type))
            }
        }
        
        for inst in institutions {
            let paysForMatch = subscriptions.contains { sub in (sub.paymentMethod == inst.name || inst.accounts.contains { $0.name == sub.paymentMethod }) && matches(sub.name + " " + sub.loginId) }
            let companyName = companies.first { $0.id == inst.companyId }?.name ?? ""
            let cardPaysForMatch = cards.contains { card in card.institutionName.lowercased() == inst.name.lowercased() && subscriptions.contains { sub in sub.paymentMethod == card.name && matches(sub.name + " " + sub.loginId) } }
            
            var payloadArr = [inst.name, inst.username, inst.email, inst.loginUrl, companyName]
            payloadArr.append(contentsOf: inst.accounts.map { $0.name })
            payloadArr.append(contentsOf: inst.accounts.map { $0.type })
            payloadArr.append(contentsOf: inst.accounts.map { $0.last4 })
            payloadArr.append(contentsOf: inst.accounts.map { $0.cardHolder })
            payloadArr.append(contentsOf: inst.accounts.map { $0.network })
            let payload = payloadArr.joined(separator: " ")
            
            if isBankQuery || paysForMatch || cardPaysForMatch || matches(payload) {
                let company = companies.first { $0.id == inst.companyId }
                let loginId = !inst.username.isEmpty ? inst.username : (!inst.email.isEmpty ? inst.email : nil)
                results.append(.init(type: .financial, title: inst.name, subtitle: company?.name ?? "", companyId: inst.companyId, modelId: inst.id, tab: .financial, password: inst.password.isEmpty ? nil : inst.password, loginId: loginId, logoData: company?.logoData, externalWebsite: inst.loginUrl, paysFor: subscriptions.filter { sub in inst.accounts.contains { acc in sub.paymentMethod == acc.name } || sub.paymentMethod == inst.name }.map { $0.name }))
            }
        }
        
        for loan in loans {
            let companyName = companies.first { $0.id == loan.companyId }?.name ?? ""
            let payload = [loan.name, loan.lender, loan.role, loan.interestType, loan.term, loan.scheduleFrequency, loan.status, loan.notes, companyName].joined(separator: " ")
            
            if isLoanQuery || matches(payload) {
                let company = companies.first { $0.id == loan.companyId }
                let inst = institutions.first { $0.name.lowercased() == loan.lender.lowercased() }
                results.append(.init(type: .financial, title: loan.name, subtitle: company?.name ?? "", companyId: loan.companyId, modelId: loan.id, tab: .financial, logoData: company?.logoData, externalWebsite: inst?.loginUrl))
            }
        }
        
        for doc in documents {
            let companyName = companies.first { $0.id == doc.companyId }?.name ?? ""
            let payload = [doc.name, doc.type, doc.notes, companyName].joined(separator: " ")
            
            if matches(payload) {
                let company = companies.first { $0.id == doc.companyId }
                results.append(.init(type: .document, title: doc.name, subtitle: company?.name ?? "", companyId: doc.companyId, modelId: doc.id, tab: .documents, logoData: company?.logoData))
            }
        }
        return results
    }

    // MARK: - AI Search
    func askGeminiSearch(query: String, companies: [Company], subscriptions: [Subscription], cards: [FinancialCard], institutions: [Institution]) async -> String {
        var minifiedData = ""
        for company in companies {
            minifiedData += "Company: \(company.name)\n"
            let coSubs = subscriptions.filter { $0.companyId == company.id }
            if !coSubs.isEmpty {
                minifiedData += "- Subs: " + coSubs.map { "\($0.name)($\($0.cost)/\($0.billingCycle) renews \($0.nextRenewal) login: \($0.loginId.isEmpty ? "none" : $0.loginId))" }.joined(separator: ", ") + "\n"
            }
            let coCards = cards.filter { $0.companyId == company.id }
            if !coCards.isEmpty {
                minifiedData += "- Cards: " + coCards.map { "\($0.name)(ends \($0.last4))" }.joined(separator: ", ") + "\n"
            }
            let coInst = institutions.filter { $0.companyId == company.id }
            if !coInst.isEmpty {
                minifiedData += "- Banks: " + coInst.map { "\($0.name)(user: \($0.username.isEmpty ? "none" : $0.username) email: \($0.email.isEmpty ? "none" : $0.email))" }.joined(separator: ", ") + "\n"
            }
        }
        return await GeminiService.shared.askPortfolioQuestion(data: minifiedData, question: query)
    }
}
