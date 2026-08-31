import SwiftUI
import Foundation
import Observation

@Observable
final class AppViewModel {
    // MARK: - Navigation State
    var selectedCompany: Company?
    var activeTab: EntityHomeTab = .financial
    var searchQuery: String = ""
    var showSearch: Bool = false
    var deepLinkModelId: UUID? = nil
    var path = NavigationPath()

    enum AppRoute: Hashable {
        case adminSettings
    }

    typealias CompanyTab = EntityHomeTab

    // CRUD: Companies
    func addCompany(appState: AppState, userId: UUID, name: String, structure: String, colorHex: String, logoData: Data?, website: String) {
        guard appState.entitlementSnapshot.hasProAccess || appState.companies.filter({ $0.userId == userId }).isEmpty else {
            appState.error = "Free includes one editable company. Upgrade to add another."
            return
        }
        DummyDataSeeder.purge(appState: appState)
        let company = Company(userId: userId, name: name, structure: structure, companyDescription: nil, colorHex: colorHex, logoData: logoData, website: website)
        appState.companies.append(company)
        Task {
            do { try await DataRepository.shared.insertCompany(company) }
            catch {
                await MainActor.run {
                    appState.companies.removeAll { $0.id == company.id }
                    appState.error = "Failed to add company."
                }
            }
        }
    }

    func updateCompany(_ company: Company, appState: AppState) {
        guard canEdit(companyId: company.id, appState: appState) else { return }
        guard let idx = appState.companies.firstIndex(where: { $0.id == company.id }) else { return }
        let original = appState.companies[idx]
        var mutableCompany = company
        mutableCompany.lastModified = Date()
        appState.companies[idx] = mutableCompany
        if selectedCompany?.id == company.id {
            selectedCompany = mutableCompany
        }
        Task {
            do { try await DataRepository.shared.updateCompany(mutableCompany) }
            catch { await MainActor.run { if let currentIdx = appState.companies.firstIndex(where: { $0.id == company.id }) { appState.companies[currentIdx] = original }; if self.selectedCompany?.id == company.id { self.selectedCompany = original }; appState.error = "Failed to update company." } }
        }
    }

    func deleteCompany(_ company: Company, appState: AppState, currentUserId: UUID?) {
        let originalCompanies = appState.companies
        appState.companies.removeAll { $0.id == company.id }
        Task {
            do {
                if company.userId != currentUserId {
                    try await DataRepository.shared.leaveResource(resourceId: company.id, resourceType: "company", resourceName: company.name, ownerId: company.userId)
                } else {
                    try await DataRepository.shared.deleteCompany(company.id)
                }
                await MainActor.run { if self.selectedCompany?.id == company.id { self.selectedCompany = nil } }
            } catch {
                await MainActor.run { appState.companies = originalCompanies; appState.error = "Failed to delete company." }
            }
        }
    }

    func touchCompany(_ company: Company, appState: AppState) {
        guard canEdit(companyId: company.id, appState: appState) else { return }
        guard let idx = appState.companies.firstIndex(where: { $0.id == company.id }) else { return }
        let original = appState.companies[idx]
        var mutableCompany = company
        mutableCompany.lastViewed = Date()
        appState.companies[idx] = mutableCompany
        Task {
            do { try await DataRepository.shared.updateCompany(mutableCompany) }
            catch { await MainActor.run { if let currentIdx = appState.companies.firstIndex(where: { $0.id == company.id }) { appState.companies[currentIdx] = original } } }
        }
    }

    // CRUD: Subscriptions
    func addSubscription(appState: AppState, userId: UUID, companyId: UUID) -> Subscription {
        return Subscription(userId: userId, companyId: companyId)
    }

    func saveSub(_ sub: Subscription, appState: AppState) {
        guard canEdit(companyId: sub.companyId, appState: appState) else { return }
        var mutableSub = sub
        mutableSub.lastUpdated = Date()
        if let idx = appState.subscriptions.firstIndex(where: { $0.id == sub.id }) {
            let original = appState.subscriptions[idx]
            appState.subscriptions[idx] = mutableSub
            Task {
                do { try await DataRepository.shared.updateSubscription(mutableSub) }
                catch { await MainActor.run { if let currentIdx = appState.subscriptions.firstIndex(where: { $0.id == sub.id }) { appState.subscriptions[currentIdx] = original }; appState.error = "Failed to update service." } }
            }
        } else {
            appState.subscriptions.append(mutableSub)
            Task {
                do { try await DataRepository.shared.insertSubscription(mutableSub) }
                catch { await MainActor.run { appState.subscriptions.removeAll { $0.id == sub.id }; appState.error = "Failed to save service." } }
            }
        }
    }

    func deleteSub(_ sub: Subscription, appState: AppState) {
        let original = appState.subscriptions
        appState.subscriptions.removeAll { $0.id == sub.id }
        Task {
            do { try await DataRepository.shared.deleteSubscription(sub.id) }
            catch { await MainActor.run { appState.subscriptions = original; appState.error = "Failed to delete service." } }
        }
    }

    // CRUD: Financial Cards
    func addCard(appState: AppState, userId: UUID, companyId: UUID) -> FinancialCard {
        return FinancialCard(userId: userId, companyId: companyId)
    }

    func saveCard(_ card: FinancialCard, appState: AppState) {
        guard canEdit(companyId: card.companyId, appState: appState) else { return }
        if let idx = appState.cards.firstIndex(where: { $0.id == card.id }) {
            let original = appState.cards[idx]
            appState.cards[idx] = card
            Task {
                do { try await DataRepository.shared.updateCard(card) }
                catch { await MainActor.run { if let currentIdx = appState.cards.firstIndex(where: { $0.id == card.id }) { appState.cards[currentIdx] = original }; appState.error = "Failed to update card." } }
            }
        } else {
            appState.cards.append(card)
            Task {
                do { try await DataRepository.shared.insertCard(card) }
                catch { await MainActor.run { appState.cards.removeAll { $0.id == card.id }; appState.error = "Failed to add card." } }
            }
        }
    }

    func deleteCard(_ card: FinancialCard, appState: AppState) {
        cleanUpCustomPaymentMethod(name: card.name)
        let original = appState.cards
        appState.cards.removeAll { $0.id == card.id }
        Task {
            do { try await DataRepository.shared.deleteCard(card.id) }
            catch { await MainActor.run { appState.cards = original; appState.error = "Failed to delete card." } }
        }
    }

    // CRUD: Institutions
    func addInstitution(appState: AppState, userId: UUID, companyId: UUID) -> Institution {
        return Institution(userId: userId, companyId: companyId)
    }

    func saveInstitution(_ inst: Institution, appState: AppState) {
        guard canEdit(companyId: inst.companyId, appState: appState) else { return }
        if let idx = appState.institutions.firstIndex(where: { $0.id == inst.id }) {
            let original = appState.institutions[idx]
            appState.institutions[idx] = inst
            Task {
                do { try await DataRepository.shared.updateInstitution(inst) }
                catch { await MainActor.run { if let currentIdx = appState.institutions.firstIndex(where: { $0.id == inst.id }) { appState.institutions[currentIdx] = original }; appState.error = "Failed to update bank." } }
            }
        } else {
            appState.institutions.append(inst)
            Task {
                do { try await DataRepository.shared.insertInstitution(inst) }
                catch { await MainActor.run { appState.institutions.removeAll { $0.id == inst.id }; appState.error = "Failed to add bank." } }
            }
        }
    }

    @MainActor
    func saveFinancialInstitutionCascade(institution: Institution, cards: [FinancialCard], loans: [Loan], appState: AppState) async throws {
        guard canEdit(companyId: institution.companyId, appState: appState) else {
            throw NSError(
                domain: "AppViewModel",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "You do not have permission to edit this company."]
            )
        }

        let originalInstitutions = appState.institutions
        let originalCards = appState.cards
        let originalLoans = appState.loans
        if let index = appState.institutions.firstIndex(where: { $0.id == institution.id }) {
            appState.institutions[index] = institution
        } else {
            appState.institutions.append(institution)
        }
        for card in cards {
            if let index = appState.cards.firstIndex(where: { $0.id == card.id }) {
                appState.cards[index] = card
            } else {
                appState.cards.append(card)
            }
        }
        for loan in loans {
            if let index = appState.loans.firstIndex(where: { $0.id == loan.id }) {
                appState.loans[index] = loan
            } else {
                appState.loans.append(loan)
            }
        }

        do {
            try await DataRepository.shared.upsertInstitution(institution)
            for card in cards {
                try await DataRepository.shared.upsertCard(card)
            }
            for loan in loans {
                try await DataRepository.shared.upsertLoan(loan)
            }
        } catch {
            appState.institutions = originalInstitutions
            appState.cards = originalCards
            appState.loans = originalLoans
            throw error
        }
    }

    func deleteInstitution(_ inst: Institution, appState: AppState) {
        let original = appState.institutions
        let instName = inst.name
        let instCompanyId = inst.companyId
        
        for acc in inst.accounts { cleanUpCustomPaymentMethod(name: acc.name.isEmpty ? acc.type : acc.name) }
        
        for c in appState.cards where c.companyId == instCompanyId && c.institutionName == instName {
            deleteCard(c, appState: appState)
        }
        
        for l in appState.loans where l.companyId == instCompanyId && l.lender == instName {
            deleteLoan(l, appState: appState)
        }
        
        appState.institutions.removeAll { $0.id == inst.id }
        Task {
            do { try await DataRepository.shared.deleteInstitution(inst.id) }
            catch { await MainActor.run { appState.institutions = original; appState.error = "Failed to delete bank." } }
        }
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

    // CRUD: Loans
    func addLoan(appState: AppState, userId: UUID, companyId: UUID) -> Loan {
        return Loan(userId: userId, companyId: companyId)
    }

    func saveLoan(_ loan: Loan, appState: AppState) {
        guard canEdit(companyId: loan.companyId, appState: appState) else { return }
        if let idx = appState.loans.firstIndex(where: { $0.id == loan.id }) {
            let original = appState.loans[idx]
            appState.loans[idx] = loan
            Task {
                do { try await DataRepository.shared.updateLoan(loan) }
                catch { await MainActor.run { if let currentIdx = appState.loans.firstIndex(where: { $0.id == loan.id }) { appState.loans[currentIdx] = original }; appState.error = "Failed to update loan." } }
            }
        } else {
            appState.loans.append(loan)
            Task {
                do { try await DataRepository.shared.insertLoan(loan) }
                catch { await MainActor.run { appState.loans.removeAll { $0.id == loan.id }; appState.error = "Failed to add loan." } }
            }
        }
    }

    func deleteLoan(_ loan: Loan, appState: AppState) {
        let original = appState.loans
        appState.loans.removeAll { $0.id == loan.id }
        Task {
            do { try await DataRepository.shared.deleteLoan(loan.id) }
            catch { await MainActor.run { appState.loans = original; appState.error = "Failed to delete loan." } }
        }
    }

    // CRUD: Documents
    func addDocument(appState: AppState, userId: UUID, companyId: UUID) -> CompanyDocument {
        return CompanyDocument(userId: userId, companyId: companyId)
    }

    func saveDoc(_ doc: CompanyDocument, appState: AppState) {
        guard canEdit(companyId: doc.companyId, appState: appState) else { return }
        if let idx = appState.documents.firstIndex(where: { $0.id == doc.id }) {
            let original = appState.documents[idx]
            appState.documents[idx] = doc
            Task {
                do { try await DataRepository.shared.updateDocument(doc) }
                catch { await MainActor.run { if let currentIdx = appState.documents.firstIndex(where: { $0.id == doc.id }) { appState.documents[currentIdx] = original }; appState.error = "Failed to update document." } }
            }
        } else {
            appState.documents.append(doc)
            Task {
                do { try await DataRepository.shared.insertDocument(doc) }
                catch { await MainActor.run { appState.documents.removeAll { $0.id == doc.id }; appState.error = "Failed to add document." } }
            }
        }
    }

    private func canEdit(companyId: UUID, appState: AppState) -> Bool {
        if appState.entitlementSnapshot.hasProAccess { return true }
        if appState.resourceShares.contains(where: {
            $0.resourceId == companyId && ["Editor", "Admin"].contains($0.role)
        }) { return true }
        let allowedId = appState.entitlementSnapshot.selectedFreeCompanyId
            ?? appState.companies
                .filter { company in
                    !appState.resourceShares.contains { $0.resourceId == company.id }
                }
                .sorted { $0.lastModified < $1.lastModified }
                .first?.id
        guard allowedId == companyId else {
            appState.error = "This company is read-only on Free. Choose it as your Free company or resubscribe to Pro."
            return false
        }
        return true
    }

    func deleteDoc(_ doc: CompanyDocument, appState: AppState) {
        let original = appState.documents
        appState.documents.removeAll { $0.id == doc.id }
        Task {
            do { try await DataRepository.shared.deleteDocument(doc.id, fileURL: doc.url) }
            catch { await MainActor.run { appState.documents = original; appState.error = "Failed to delete document." } }
        }
    }

    // Monthly Burn
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


    struct SearchResult: Identifiable {
        let id = UUID()
        let type: SearchResultType
        let title: String
        let subtitle: String
        let companyId: UUID
        let modelId: UUID
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

        init(type: SearchResultType, title: String, subtitle: String, companyId: UUID, modelId: UUID, tab: CompanyTab, password: String? = nil, loginId: String? = nil, logoData: Data? = nil, externalWebsite: String? = nil, isFree: Bool? = nil, cost: Double? = nil, status: String? = nil, last4: String? = nil, network: String? = nil, paysFor: [String]? = nil, cardType: String? = nil) {
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
            let payload = [c.name, c.structure, c.companyDescription ?? "", c.website ?? ""].joined(separator: " ")
            if matches(payload) {
                results.append(.init(type: .company, title: c.name, subtitle: c.structure, companyId: c.id, modelId: c.id, tab: .financial, logoData: c.logoData))
            }
        }
        
        for s in subscriptions {
            let companyName = companies.first { $0.id == s.companyId }?.name ?? ""
            var payloadArr: [String] = [s.name, s.loginId ?? "", s.paymentMethod ?? "", companyName, s.website ?? "", s.status, s.billingCycle, s.pricingModel, s.recoveryMethod ?? "", s.twoFactorAuth]
            payloadArr.append(s.notes ?? "")
            
            payloadArr.append(contentsOf: s.subServices.map { $0.name })
            payloadArr.append(contentsOf: s.subServices.map { $0.purpose })
            payloadArr.append(contentsOf: s.linkedEmails.map { $0.email })
            payloadArr.append(contentsOf: s.linkedEmails.map { $0.provider })
            payloadArr.append(contentsOf: s.linkedEmails.map { $0.usedFor })
            
            let payload = payloadArr.joined(separator: " ")
            
            if isSubQuery || matches(payload) {
                let company = companies.first { $0.id == s.companyId }
                results.append(.init(type: .subscription, title: s.name, subtitle: company?.name ?? "", companyId: s.companyId, modelId: s.id, tab: .subscriptions, password: s.password, loginId: s.loginId, logoData: company?.logoData, externalWebsite: s.website, isFree: s.isFree, cost: s.cost, status: s.status))
            }
        }
        
        for card in cards {
            let companyName = companies.first { $0.id == card.companyId }?.name ?? ""
            let paysForMatch = subscriptions.contains { ($0.paymentMethodId == card.id || ($0.paymentMethodId == nil && $0.paymentMethod == card.name)) && matches($0.name + " " + ($0.loginId ?? "")) }
            
            var payloadArr = [card.name, card.institutionName ?? "", card.network, card.last4 ?? "", card.type, card.status, card.paidFrom ?? "", card.cardHolder ?? "", card.notes ?? "", companyName, card.type + " card", card.type + " cards"]
            payloadArr.append("apr \(card.apr)% \(card.apr)")
            if card.promoApr > 0 || (card.promoEnds ?? Date()) > Date() {
                payloadArr.append("promo apr \(card.promoApr)% \(card.promoApr)")
                if card.promoApr == 0 {
                    payloadArr.append("0% 0")
                }
            }
            
            let payload = payloadArr.joined(separator: " ")
            
            if isBankQuery || isCardQuery || paysForMatch || matches(payload) {
                let company = companies.first { $0.id == card.companyId }
                let inst = institutions.first { $0.name.lowercased() == (card.institutionName?.lowercased() ?? "") }
                results.append(.init(type: .financial, title: card.name, subtitle: company?.name ?? "", companyId: card.companyId, modelId: card.id, tab: .financial, password: card.password, loginId: card.login, logoData: company?.logoData, externalWebsite: inst?.loginUrl, status: card.status, last4: card.last4, network: card.network, paysFor: subscriptions.filter { $0.paymentMethodId == card.id || ($0.paymentMethodId == nil && $0.paymentMethod == card.name) }.map { $0.name }, cardType: card.type))
            }
        }
        
        for inst in institutions {
            let paysForMatch = subscriptions.contains { sub in (sub.paymentMethodId == inst.id || inst.accounts.contains { acc in sub.paymentMethodId == UUID(uuidString: acc.id) } || (sub.paymentMethodId == nil && (sub.paymentMethod == inst.name || inst.accounts.contains { $0.name == sub.paymentMethod }))) && matches(sub.name + " " + (sub.loginId ?? "")) }
            let companyName = companies.first { $0.id == inst.companyId }?.name ?? ""
            let cardPaysForMatch = cards.contains { card in card.institutionName?.lowercased() == inst.name.lowercased() && subscriptions.contains { sub in (sub.paymentMethodId == card.id || (sub.paymentMethodId == nil && sub.paymentMethod == card.name)) && matches(sub.name + " " + (sub.loginId ?? "")) } }
            
            var payloadArr = [inst.name, inst.username ?? "", inst.email ?? "", inst.loginUrl ?? "", companyName]
            payloadArr.append(contentsOf: inst.accounts.map { $0.name })
            payloadArr.append(contentsOf: inst.accounts.map { $0.type })
            payloadArr.append(contentsOf: inst.accounts.map { $0.last4 })
            payloadArr.append(contentsOf: inst.accounts.map { $0.cardHolder })
            payloadArr.append(contentsOf: inst.accounts.map { $0.network })
            let payload = payloadArr.joined(separator: " ")
            
            if isBankQuery || paysForMatch || cardPaysForMatch || matches(payload) {
                let company = companies.first { $0.id == inst.companyId }
                let loginId = !(inst.username?.isEmpty ?? true) ? inst.username : (!(inst.email?.isEmpty ?? true) ? inst.email : nil)
                results.append(.init(type: .financial, title: inst.name, subtitle: company?.name ?? "", companyId: inst.companyId, modelId: inst.id, tab: .financial, password: inst.password, loginId: loginId, logoData: company?.logoData, externalWebsite: inst.loginUrl, paysFor: subscriptions.filter { sub in sub.paymentMethodId == inst.id || inst.accounts.contains { acc in sub.paymentMethodId == UUID(uuidString: acc.id) } || (sub.paymentMethodId == nil && (inst.accounts.contains { acc in sub.paymentMethod == acc.name } || sub.paymentMethod == inst.name)) }.map { $0.name }))
            }
        }
        
        for loan in loans {
            let companyName = companies.first { $0.id == loan.companyId }?.name ?? ""
            let payload = [loan.name, loan.lender ?? "", loan.role, loan.interestType, loan.term, loan.scheduleFrequency, loan.status, loan.notes ?? "", companyName].joined(separator: " ")
            
            if isLoanQuery || matches(payload) {
                let company = companies.first { $0.id == loan.companyId }
                let inst = institutions.first { $0.name.lowercased() == (loan.lender?.lowercased() ?? "") }
                results.append(.init(type: .financial, title: loan.name, subtitle: company?.name ?? "", companyId: loan.companyId, modelId: loan.id, tab: .financial, logoData: company?.logoData, externalWebsite: inst?.loginUrl))
            }
        }
        
        for doc in documents {
            let companyName = companies.first { $0.id == doc.companyId }?.name ?? ""
            let payload = [doc.name, doc.type, doc.notes ?? "", companyName].joined(separator: " ")
            
            if matches(payload) {
                let company = companies.first { $0.id == doc.companyId }
                results.append(.init(type: .document, title: doc.name, subtitle: company?.name ?? "", companyId: doc.companyId, modelId: doc.id, tab: .documents, logoData: company?.logoData))
            }
        }
        return results
    }

    // MARK: - AI Search & Context
    func generateMinifiedPortfolio(appState: AppState) -> String {
        var minifiedData = ""
        for company in appState.companies {
            minifiedData += "Company: \(company.name)\n"
            
            let coSubs = appState.subscriptions.filter { $0.companyId == company.id }
            if !coSubs.isEmpty {
                minifiedData += "- Subs: " + coSubs.map { sub in
                    let paymentInfo = sub.paymentMethodId != nil ? (appState.cards.first { $0.id == sub.paymentMethodId }?.name ?? sub.paymentMethod ?? "unknown card") : (sub.paymentMethod ?? "unknown card")
                    return "\(sub.name)($\(sub.cost)/\(sub.billingCycle) renews \(sub.nextRenewal ?? "") paid with: \(paymentInfo))"
                }.joined(separator: ", ") + "\n"
            }
            
            let coCards = appState.cards.filter { $0.companyId == company.id }
            if !coCards.isEmpty {
                minifiedData += "- Cards: " + coCards.map { "\($0.name)(ends \($0.last4 ?? ""), balance: $\($0.balance))" }.joined(separator: ", ") + "\n"
            }
            
            let coInst = appState.institutions.filter { $0.companyId == company.id }
            if !coInst.isEmpty {
                minifiedData += "- Banks: " + coInst.map { "\($0.name)(user: \(($0.username?.isEmpty ?? true) ? "none" : ($0.username ?? "")) email: \(($0.email?.isEmpty ?? true) ? "none" : ($0.email ?? "")))" }.joined(separator: ", ") + "\n"
            }
            
            let coLoans = appState.loans.filter { $0.companyId == company.id }
            if !coLoans.isEmpty {
                let loansString = coLoans.map { loan in
                    let lender = loan.lender ?? "none"
                    return "\(loan.name)(lender: \(lender), balance: $\(loan.remainingBalance), monthly payment: $\(loan.monthlyPayment))"
                }.joined(separator: ", ")
                minifiedData += "- Loans: \(loansString)\n"
            }
        }
        

        let detectedSubs = SubscriptionDetector.detect(transactions: appState.transactions, existingSubscriptions: appState.subscriptions)
        if !detectedSubs.isEmpty {
            minifiedData += "\nDetected Anomalies (Unracked Subscriptions in Transactions):\n"
            minifiedData += detectedSubs.map { "- \($0.name): $\($0.amount)/\($0.frequency) (charged \($0.occurrences)x)" }.joined(separator: "\n")
            minifiedData += "\nWhen you first greet the user, PROACTIVELY alert them if they have any un-tracked subscriptions or obvious duplicate charges (e.g., same service on multiple cards) and ask if they'd like you to draft them."
        }
        
        return minifiedData
    }
}
