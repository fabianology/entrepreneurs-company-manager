import Foundation

/// Search owns a projection of authorized records, never passwords or full account numbers.
/// This same projection feeds the search UI, Siri routing and assistant retrieval.
struct SearchRecord: Identifiable, Hashable, Sendable {
    enum Kind: String, CaseIterable, Codable, Sendable {
        case company, subscription, card, institution, account, loan, payment, transaction, document, obligation, expenseReview, notification, activity, settings, alert, sharing
        var label: String {
            switch self {
            case .subscription: return "Service"
            case .institution: return "Bank"
            case .expenseReview: return "Expense review"
            default: return rawValue.capitalized
            }
        }
        var icon: String {
            switch self {
            case .company: return "building.2"
            case .subscription: return "repeat"
            case .card: return "creditcard"
            case .institution, .account: return "building.columns"
            case .loan: return "banknote"
            case .payment, .transaction: return "arrow.left.arrow.right"
            case .document: return "doc.text"
            case .obligation: return "calendar.badge.clock"
            case .expenseReview: return "receipt"
            case .notification, .alert: return "bell"
            case .activity: return "clock"
            case .settings: return "gearshape"
            case .sharing: return "person.2"
            }
        }
    }
    enum Credential: String, Sendable { case none, available, locked }
    let id: String
    let kind: Kind
    let modelID: UUID
    var companyID: UUID?
    var company: String
    var title: String
    var detail: String
    var text: String
    var normalizedTitle: String
    var normalizedText: String
    var words: Set<String>
    var last4: String = ""
    var login: String = ""
    var credential: Credential = .none
    var date: Date?
    var dueDate: Date?
    var amount: Decimal?
    var availableAmount: Decimal?
    var balanceCategory: SearchBalanceCategory?
    var balanceIdentity: String?
    var balanceAliases: Set<String> = []
    var lastSyncedAt: Date?
    var financialFacts: [String: String] = [:]
    var currency: String = "USD"
    var flow: String = ""
    var pending = false
    var monthlyCost: Decimal?
    var serviceType: String?
    var parentServiceID: String?
    var category = ""
    var accountName = ""
    var safeDetails: [String: String] = [:]
    var activeService = false
    var page: Int?
    var destinationID: UUID?
    var destinationKind: Kind?
    // Presentation metadata is never included in assistant evidence.
    var website: String?
    var logoURL: String?
    var brandName: String?

    init(kind: Kind, modelID: UUID, companyID: UUID?, company: String, title: String,
         detail: String, text: String = "", suffix: String = "") {
        self.id = "\(kind.rawValue):\(modelID.uuidString)\(suffix)"
        self.kind = kind; self.modelID = modelID; self.companyID = companyID
        self.company = company; self.title = title; self.detail = detail; self.text = text
        self.normalizedTitle = SearchText.normalize(title)
        self.normalizedText = SearchText.normalize([title, detail, company, text, kind.label].joined(separator: " "))
        self.words = Set(normalizedText.split(separator: " ").map(String.init))
    }
}

/// Separate assets, borrowing and lending; these categories must never be netted together.
enum SearchBalanceCategory: String, Sendable {
    case cash = "Cash balances", investment = "Investment balances", credit = "Credit card balances"
    case loan = "Loan balances owed", receivable = "Loans receivable", other = "Other account balances"
    static func accountType(_ type: String) -> Self {
        let type = SearchText.normalize(type)
        if type.contains("credit") { return .credit }
        if type.contains("loan") || type.contains("mortgage") { return .loan }
        if ["checking", "savings", "debit", "cash", "money market"].contains(where: type.contains) { return .cash }
        if ["invest", "brokerage", "retirement", "ira", "401", "529", "cd"].contains(where: type.contains) { return .investment }
        return .other
    }
}

struct SearchHit: Identifiable, Sendable {
    var record: SearchRecord
    var score: Int
    var reason: String
    var snippet: String?
    var id: String { record.id }
}

struct SearchTotal: Identifiable, Sendable {
    var label: String
    var currency: String
    var amount: Decimal
    var sourceIDs: [String]
    var id: String { "\(label):\(currency)" }
    var formatted: String { SearchText.money(amount, currency: currency) }
}

struct SearchResponse: Sendable {
    var hits: [SearchHit] = []
    var totals: [SearchTotal] = []
    var interpretation: String = ""
    var coverage: String = ""
    var isCredentialRequest = false
    var metrics: [SearchMetric] = []
    var answerSummary: String? = nil
    var includesDetails = false

    /// Include allowlisted financial facts and safe excerpts; omit logins, notes and credentials.
    /// Evidence is bounded; totals are calculated from ALL matching records before truncation.
    func assistantEvidence(limit: Int = 12, offset: Int = 0) -> String {
        let offset = min(max(0, offset), max(hits.count, metrics.count, totals.count))
        let limit = min(max(1, limit), 12)
        let formatter = ISO8601DateFormatter()
        let records: [[String: Any]] = hits.dropFirst(offset).prefix(limit).map { hit in
            let record = hit.record
            var result: [String: Any] = ["sourceID": hit.id, "kind": record.kind.rawValue,
                "title": String(record.title.prefix(100)), "company": String(record.company.prefix(100)),
                "detail": String(record.detail.prefix(250)), "match": String(hit.reason.prefix(150))]
            result["excerpt"] = record.kind == .document ? (includesDetails ? String(record.text.prefix(6000)) : (hit.snippet ?? "")) : ""
            result["excerptTruncated"] = record.kind == .document && includesDetails && record.text.count > 6000
            result["serviceType"] = record.serviceType
            result["category"] = record.category
            result["account"] = record.accountName
            result["page"] = record.page
            result["details"] = record.safeDetails.filter { includesDetails || !["notes", "message", "linkedEmails", "context", "description"].contains($0.key) }.mapValues { String($0.prefix(includesDetails ? 1000 : 250)) }
            result["hasMoreDetails"] = !record.safeDetails.isEmpty
            result["financialFacts"] = record.financialFacts.mapValues { String($0.prefix(200)) }
            result["currency"] = record.currency
            result["balanceIdentity"] = record.balanceIdentity ?? hit.id
            result["dataBasis"] = "Saved app records; no live bank refresh was performed"
            result["lastSyncedAt"] = record.lastSyncedAt.map(formatter.string(from:)) ?? "Unknown"
            result["date"] = record.date.map(formatter.string(from:)) ?? ""
            result["dueDate"] = record.dueDate.map(formatter.string(from:)) ?? ""
            return result
        }
        let sums: [[String: Any]] = totals.dropFirst(totals.count > limit ? offset : 0).prefix(limit).map {
            ["label": $0.label, "currency": $0.currency, "amount": NSDecimalNumber(decimal: $0.amount).stringValue,
             "sourceCount": $0.sourceIDs.count, "sourceIDs": Array($0.sourceIDs.prefix(12)), "sourceIDsTruncated": $0.sourceIDs.count > 12]
        }
        let calculations: [[String: Any]] = metrics.dropFirst(offset).prefix(limit).map { metric in
            var item: [String: Any] = ["label": metric.label, "value": NSDecimalNumber(decimal: metric.value).stringValue, "formatted": metric.formatted, "sourceCount": metric.sourceIDs.count, "sourceIDs": Array(metric.sourceIDs.prefix(12)), "sourceIDsTruncated": metric.sourceIDs.count > 12]
            item["currency"] = metric.currency
            item["previousValue"] = metric.previousValue.map { NSDecimalNumber(decimal: $0).stringValue }
            if metric.sourceIDs.count == 1, let source = hits.first(where: { $0.id == metric.sourceIDs[0] })?.record {
                item["recordTitle"] = source.title
                item["company"] = source.company
                item["date"] = SearchText.day(source.date)
                item["account"] = source.accountName
                item["flow"] = source.flow
            }
            return item
        }
        let payload: [String: Any] = ["calculationCount": metrics.count, "hasMoreCalculations": max(metrics.count, totals.count) > offset + limit, "calculations": calculations, "answer": answerSummary ?? "", "records": records, "matchingRecordCount": hits.count,
            "totals": sums, "interpretation": interpretation, "coverage": coverage,
            "credentialRequest": isCredentialRequest, "returnedRecordCount": records.count, "hasMoreRecords": hits.count > offset + records.count, "offset": offset, "nextOffset": min(offset + limit, max(hits.count, metrics.count, totals.count))]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else { return "{}" }
        return json
    }
}

struct SearchFilters: Equatable, Sendable {
    var companyID: UUID?
    var kind: SearchRecord.Kind?
    var serviceType: String?
    var credentialsOnly = false
    var period: Period = .all
    enum Period: String, CaseIterable, Sendable {
        case all = "Any date", thisMonth = "This month", lastMonth = "Last month", nextMonth = "Next month"
    }
}

struct SearchDocumentPage: Hashable, Sendable {
    var documentID: UUID
    var page: Int
    var text: String
    var sourceURL: String? = nil
}

enum SearchText {
    static func fieldLabel(_ key: String) -> String {
        let labels = ["aprPercent": "APR (%)", "apyPercent": "APY (%)", "storedMonthlyPayment": "Saved monthly payment", "nextRenewal": "Next renewal", "expirationDate": "Expiration date", "paymentDue": "Payment due", "currentBalance": "Current balance", "creditLimit": "Credit limit", "storedInterestRate": "Interest rate", "currencyBasis": "Currency basis"]
        return labels[key] ?? key.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).replacingOccurrences(of: "_", with: " ").capitalized
    }
    static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }
    static func money(_ value: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value) \(currency)"
    }
    static func date(_ string: String, calendar: Calendar = .current) -> Date? {
        let pieces = string.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard pieces.count == 3 else { return nil }
        guard let date = calendar.date(from: DateComponents(year: pieces[0], month: pieces[1], day: pieces[2])) else { return nil }
        let actual = calendar.dateComponents([.year, .month, .day], from: date)
        guard actual.year == pieces[0], actual.month == pieces[1], actual.day == pieces[2] else { return nil }
        return date
    }
    static func decimal(_ value: Double?) -> Decimal? {
        guard let value, value.isFinite else { return nil }
        return Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX"))
    }
    static func number(_ value: Double?) -> String {
        decimal(value).map { NSDecimalNumber(decimal: $0).stringValue } ?? "Unavailable"
    }
    static func day(_ date: Date?, calendar: Calendar = .current) -> String {
        guard let date else { return "Unavailable" }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    static func typo(_ a: String, _ b: String) -> Bool {
        guard a.count >= 4, b.count >= 4, a.allSatisfy(\.isLetter), b.allSatisfy(\.isLetter), abs(a.count - b.count) <= 1 else { return false }
        let x = Array(a), y = Array(b)
        if x.count == y.count {
            let differing = x.indices.filter { x[$0] != y[$0] }
            return differing.count == 1 || (differing.count == 2 && differing[1] == differing[0] + 1
                && x[differing[0]] == y[differing[1]] && x[differing[1]] == y[differing[0]])
        }
        let short = x.count < y.count ? x : y, long = x.count < y.count ? y : x
        var i = 0, j = 0, skips = 0
        while i < short.count && j < long.count {
            if short[i] == long[j] { i += 1; j += 1 } else { skips += 1; j += 1; if skips > 1 { return false } }
        }
        return true
    }
}

/// Used only while projecting. Raw secret strings never survive in the resulting index.
struct SearchRedactor {
    private let values: [String]
    init(values: [String?]) { self.values = Array(Set(values.compactMap { $0 }.filter { !$0.isEmpty })).sorted { $0.count > $1.count } }
    func clean(_ text: String) -> String {
        var result = text
        for value in values { result = result.replacingOccurrences(of: value, with: "[protected]", options: .caseInsensitive) }
        // Free-form notes/documents can contain credentials too. Do not index labelled values or full PANs.
        result = result.replacingOccurrences(of: #"(?im)\b(password|passwd|passcode|secret|api[_ -]?key|access[_ -]?token|refresh[_ -]?token|cvv|cvc|pin|routing number|account number)\s*[:=]\s*[^\n]+"#, with: "$1: [protected]", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\b(?:\d[ -]?){12,18}\d\b"#, with: "[protected]", options: .regularExpression)
        return result
    }
}

/// Immutable value copies captured on the main actor. Index construction reads
/// only this snapshot, never the live observable AppState from a background task.
struct SearchIndexSnapshot: Sendable {
    let activityLogs: [ActivityLog]
    let alertRules: [AlertRule]
    let businessExpenseAccounts: [BusinessExpenseAccount]
    let businessExpenseJob: BusinessExpenseJob?
    let businessExpenseLoadError: String?
    let businessExpenseProfiles: [BusinessExpenseProfile]
    let businessExpenseReviews: [BusinessExpenseReview]
    let businessExpenseSettings: BusinessExpenseSettings
    let businessExpenseUserID: UUID?
    let cards: [FinancialCard]
    let companies: [Company]
    let documents: [CompanyDocument]
    let hasLoadedPortfolio: Bool
    let institutions: [Institution]
    let loans: [Loan]
    let localCompanyOverrides: [String: UUID]
    let notifications: [AppNotification]
    let obligations: [PortfolioObligation]
    let portfolioLoadIssue: String?
    let portfolioUserID: UUID?
    let resourceConnections: [ResourceConnection]
    let resourceShares: [ResourceShare]
    let searchDocumentPages: [SearchDocumentPage]
    let searchDocumentStatus: String
    let subscriptions: [Subscription]
    let transactionCategoryRules: [TransactionCategoryRule]
    let transactionOverrides: [TransactionOverride]
    let transactions: [Transaction]
    let userPreferences: UserPreferences?
    @MainActor init(_ state: AppState) {
        activityLogs = state.activityLogs
        alertRules = state.alertRules
        businessExpenseAccounts = state.businessExpenseAccounts
        businessExpenseJob = state.businessExpenseJob
        businessExpenseLoadError = state.businessExpenseLoadError
        businessExpenseProfiles = state.businessExpenseProfiles
        businessExpenseReviews = state.businessExpenseReviews
        businessExpenseSettings = state.businessExpenseSettings
        businessExpenseUserID = state.businessExpenseUserID
        cards = state.cards
        companies = state.companies
        documents = state.documents
        hasLoadedPortfolio = state.hasLoadedPortfolio
        institutions = state.institutions
        loans = state.loans
        localCompanyOverrides = state.localCompanyOverrides
        notifications = state.notifications
        obligations = state.obligations
        portfolioLoadIssue = state.portfolioLoadIssue
        portfolioUserID = state.portfolioUserID
        resourceConnections = state.resourceConnections
        resourceShares = state.resourceShares
        searchDocumentPages = state.searchDocumentPages
        searchDocumentStatus = state.searchDocumentStatus
        subscriptions = state.subscriptions
        transactionCategoryRules = state.transactionCategoryRules
        transactionOverrides = state.transactionOverrides
        transactions = state.transactions
        userPreferences = state.userPreferences
    }
}

struct UniversalSearchIndex: Sendable {
    var records: [SearchRecord] = []
    var links: [String: Set<String>] = [:]
    var coverage = "Waiting for portfolio data"
    var isLoaded = false

    @MainActor
    init(appState: AppState, userID: UUID, documentPages: [SearchDocumentPage] = []) {
        self.init(snapshot: SearchIndexSnapshot(appState), userID: userID, documentPages: documentPages)
    }

    init(snapshot appState: SearchIndexSnapshot, userID: UUID, documentPages: [SearchDocumentPage] = []) {
        guard !Task.isCancelled, appState.hasLoadedPortfolio, appState.portfolioUserID == userID else { return }
        isLoaded = true
        let shared = Set(appState.resourceShares.filter { $0.userId == userID }.map(\.resourceId))
        let companies = appState.companies.filter { $0.userId == userID || shared.contains($0.id) }
        let allowedCompanies = Set(companies.map(\.id))
        let companyNames = Dictionary(companies.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        func allowed(_ id: UUID, _ owner: UUID, _ company: UUID) -> Bool {
            owner == userID || shared.contains(id) || allowedCompanies.contains(company)
        }
        func companyID(_ id: UUID, _ fallback: UUID) -> UUID {
            let assigned = appState.localCompanyOverrides[id.uuidString] ?? fallback
            return allowedCompanies.contains(assigned) ? assigned : fallback
        }
        var secrets = appState.subscriptions.map(\.password) + appState.cards.map(\.password) + appState.institutions.map(\.password)
        secrets += appState.cards.map(\.cardNumber)
        secrets += appState.institutions.flatMap { $0.accounts.flatMap { [$0.accountNumber, $0.routingNumber, $0.wireRoutingNumber] } }
        let redactor = SearchRedactor(values: secrets)
        func make(_ kind: SearchRecord.Kind, _ id: UUID, _ company: UUID?, _ title: String, _ detail: String, _ text: String = "", suffix: String = "") -> SearchRecord {
            SearchRecord(kind: kind, modelID: id, companyID: company, company: redactor.clean(company.flatMap { companyNames[$0] } ?? "Unassigned"),
                title: redactor.clean(title), detail: redactor.clean(detail), text: redactor.clean(text), suffix: suffix)
        }
        func credential(_ value: String?) -> SearchRecord.Credential {
            guard let value, !value.isEmpty else { return .none }
            return SecurityService.isLockedValue(value) ? .locked : .available
        }
        func key(_ kind: SearchRecord.Kind, _ id: UUID) -> String { "\(kind.rawValue):\(id.uuidString)" }
        for company in companies {
            var record = make(.company, company.id, company.id, company.name, company.structure, [company.companyDescription, company.website].compactMap { $0 }.joined(separator: " "))
            record.safeDetails = ["description": redactor.clean(company.companyDescription ?? ""), "website": redactor.clean(company.website ?? ""), "structure": redactor.clean(company.structure)]
            record.website = company.website.map(redactor.clean)
            records.append(record)
        }
        let cards = appState.cards.filter { allowed($0.id, $0.userId, $0.companyId) }.map { c in
            var c = c; c.companyId = companyID(c.id, c.companyId); return c
        }
        let institutions = appState.institutions.filter { allowed($0.id, $0.userId, $0.companyId) }.map { i in
            var i = i; i.companyId = companyID(i.id, i.companyId); return i
        }
        // An alias may be shared by a linked card and its account. Retain both, never guess by last four.
        var accountAliases: [String: Set<String>] = [:]
        func aliases(_ values: [String?], _ recordID: String) {
            for value in values.compactMap({ $0 }) where !value.isEmpty { accountAliases[value, default: []].insert(recordID) }
        }
        for card in cards {
            let last4 = String((card.last4 ?? "").filter(\.isNumber).suffix(4))
            var r = make(.card, card.id, card.companyId, card.name,
                         [card.institutionName ?? "", card.network, card.type, last4.isEmpty ? "" : "•••• \(last4)", card.status].filter { !$0.isEmpty }.joined(separator: " · "),
                         [card.cardHolder, card.login, card.notes].compactMap { $0 }.joined(separator: " "))
            r.last4 = last4; r.login = redactor.clean(card.login ?? ""); r.credential = credential(card.password); r.date = card.expiresAt
            r.amount = SearchText.decimal(card.balance)
            r.balanceCategory = SearchBalanceCategory.accountType(card.type)
            r.balanceAliases = ["card:\(card.id.uuidString)"]
            if let plaid = card.plaidAccountId, !plaid.isEmpty { r.balanceAliases.insert("plaid:\(plaid)") }
            let linkedAccounts = institutions.flatMap { bank in bank.accounts.compactMap { account -> (Institution, InstitutionAccount)? in
                guard bank.companyId == card.companyId else { return nil }
                let explicitLink = account.linkedCardId.flatMap(UUID.init(uuidString:)) == card.id
                let samePlaid = card.plaidAccountId.map { !$0.isEmpty && $0 == account.plaidAccountId } ?? false
                return explicitLink || samePlaid ? (bank, account) : nil
            } }
            // Currency/available balance can come from one explicitly linked account, never a name/ending guess.
            if linkedAccounts.count == 1, let (bank, account) = linkedAccounts.first {
                r.website = bank.loginUrl.map(redactor.clean)
                r.currency = ExecutiveBriefingSnapshot.currency(account.currency)
                r.availableAmount = SearchText.decimal(account.availableBalance)
                r.financialFacts["availableBalance"] = SearchText.number(account.availableBalance)
                r.financialFacts["linkedBankBalance"] = SearchText.number(account.balance)
                if r.amount != SearchText.decimal(account.balance) { r.financialFacts["balanceDifference"] = "Saved card balance differs from linked bank balance; report both with the bank sync date" }
                r.financialFacts["linkedBankLastSyncedAt"] = bank.lastSyncedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "Unknown"
                r.financialFacts["bankConnection"] = bank.isDisconnected ? "Needs attention" : "Connected"
            } else { r.financialFacts["currencyBasis"] = "USD app default; card has no currency field" }
            r.financialFacts["currentBalance"] = SearchText.number(card.balance)
            r.financialFacts["balanceCategory"] = r.balanceCategory?.rawValue
            r.financialFacts["accountType"] = redactor.clean(card.type)
            if r.balanceCategory == .credit {
                r.financialFacts["creditLimit"] = SearchText.number(card.limit)
                r.financialFacts["storedMonthlyPayment"] = SearchText.number(card.moPayment)
                r.financialFacts["aprPercent"] = SearchText.number(card.apr)
                if let end = card.promoEnds {
                    r.financialFacts["promoAprPercent"] = SearchText.number(card.promoApr)
                    r.financialFacts["promoEnds"] = SearchText.day(end)
                }
            }
            r.financialFacts["paymentDue"] = redactor.clean(card.paidOn ?? "Unavailable")
            r.financialFacts["autopay"] = redactor.clean(card.autopay)
            r.safeDetails = ["notes": redactor.clean(card.notes ?? ""), "cardHolder": redactor.clean(card.cardHolder ?? ""), "expirationDate": SearchText.day(card.expiresAt), "paidFrom": redactor.clean(card.paidFrom ?? "")]
            r.brandName = redactor.clean(card.institutionName ?? card.name)
            records.append(r); aliases([card.id.uuidString, card.plaidAccountId], r.id)
        }
        for institution in institutions {
            var bank = make(.institution, institution.id, institution.companyId, institution.name,
                            institution.isDisconnected ? "Bank connection needs attention" : "Bank", [institution.username, institution.email, institution.loginUrl].compactMap { $0 }.joined(separator: " "))
            bank.login = redactor.clean(institution.username ?? institution.email ?? ""); bank.credential = credential(institution.password)
            bank.lastSyncedAt = institution.lastSyncedAt
            bank.website = institution.loginUrl.map(redactor.clean)
            bank.financialFacts = ["accountCount": String(institution.accounts.count), "bankConnection": institution.isDisconnected ? "Needs attention" : "Connected"]
            records.append(bank)
            for account in institution.accounts {
                var r = make(.account, institution.id, institution.companyId, account.name.isEmpty ? institution.name : account.name,
                    "\(institution.name) · \(account.type) · •••• \(account.last4)", "\(account.cardHolder) \(account.network)", suffix: ":\(account.id)")
                r.last4 = String(account.last4.filter(\.isNumber).suffix(4)); r.login = bank.login; r.credential = bank.credential
                r.website = bank.website; r.brandName = bank.title
                r.amount = SearchText.decimal(account.balance); r.currency = ExecutiveBriefingSnapshot.currency(account.currency)
                r.availableAmount = SearchText.decimal(account.availableBalance)
                r.balanceCategory = SearchBalanceCategory.accountType(account.type)
                r.balanceAliases = ["account:\(account.id)"]
                if let plaid = account.plaidAccountId, !plaid.isEmpty { r.balanceAliases.insert("plaid:\(plaid)") }
                if let persistentID = account.persistentAccountId, !persistentID.isEmpty { r.balanceAliases.insert("persistent:\(persistentID)") }
                if let linkedID = account.linkedCardId.flatMap(UUID.init(uuidString:)) { r.balanceAliases.insert("card:\(linkedID.uuidString)") }
                r.lastSyncedAt = institution.lastSyncedAt
                r.financialFacts = ["currentBalance": SearchText.number(account.balance), "availableBalance": SearchText.number(account.availableBalance),
                    "balanceCategory": r.balanceCategory!.rawValue, "accountType": redactor.clean(account.type),
                    "bankConnection": institution.isDisconnected ? "Needs attention" : "Connected"]
                if r.balanceCategory == .credit { r.financialFacts["creditLimit"] = SearchText.number(account.limit) }
                if let apy = account.apy { r.financialFacts["apyPercent"] = SearchText.number(apy) }
                if !account.paidOn.isEmpty { r.financialFacts["paymentDue"] = redactor.clean(account.paidOn) }
                r.financialFacts["autopay"] = redactor.clean(account.autopay)
                records.append(r); aliases([account.id, account.plaidAccountId], r.id)
                link(r.id, bank.id)
                if let cardID = account.linkedCardId.flatMap(UUID.init(uuidString:)) { link(r.id, key(.card, cardID)) }
            }
        }
        for sub in appState.subscriptions where allowed(sub.id, sub.userId, sub.companyId) {
            let cid = companyID(sub.id, sub.companyId)
            let detail = "\(SearchText.money(Decimal(sub.cost), currency: sub.currency)) / \(sub.billingCycle) · \(sub.status)"
            let text = [sub.loginId, sub.website, sub.notes, sub.paymentMethod].compactMap { $0 }.joined(separator: " ")
                + " " + sub.linkedEmails.map { "\($0.email) \($0.provider) \($0.usedFor)" }.joined(separator: " ")
                + " " + sub.subServices.map { "\($0.name) \($0.purpose)" }.joined(separator: " ")
            var r = make(.subscription, sub.id, cid, sub.name, "\(sub.resolvedServiceType.rawValue.capitalized) · " + detail, text)
            r.serviceType = sub.resolvedServiceType.rawValue
            r.website = sub.website.map(redactor.clean)
            r.safeDetails = ["website": redactor.clean(sub.website ?? ""), "notes": redactor.clean(sub.notes ?? ""), "paymentMethod": redactor.clean(sub.paymentMethod ?? "")]
            r.login = redactor.clean(sub.loginId ?? ""); r.credential = credential(sub.password)
            r.date = sub.nextRenewalAt ?? sub.nextRenewal.flatMap { SearchText.date($0) }; r.dueDate = r.date
            r.activeService = !["cancelled", "canceled", "paused"].contains(sub.status.lowercased())
            if let base = ExecutiveBriefingSnapshot.monthlyCost(sub), base.isFinite { r.monthlyCost = SearchText.decimal(base) }
            r.currency = ExecutiveBriefingSnapshot.currency(sub.currency)
            r.safeDetails["classificationSource"] = sub.serviceType == .automatic ? "Automatic classification" : "User-selected classification"
            r.safeDetails["renewalMode"] = redactor.clean(sub.renew)
            r.safeDetails["pricingModel"] = redactor.clean(sub.pricingModel)
            r.safeDetails["linkedEmails"] = redactor.clean(sub.linkedEmails.map { "\($0.email): \($0.usedFor)" }.joined(separator: "; "))
            r.financialFacts = ["billingAmount": SearchText.number(sub.cost), "billingCycle": redactor.clean(sub.billingCycle),
                "nextRenewal": SearchText.day(r.date), "status": redactor.clean(sub.status)]
            if let monthly = r.monthlyCost { r.financialFacts["monthlyEquivalent"] = NSDecimalNumber(decimal: monthly).stringValue }
            records.append(r)
            for addon in sub.subServices {
                var child = make(.subscription, sub.id, cid, addon.name, "\(addon.resolvedServiceType.rawValue.capitalized) · Add-on to \(sub.name) · \(SearchText.money(Decimal(addon.cost), currency: r.currency)) / \(addon.billingCycle.rawValue)", addon.purpose, suffix: ":addon:\(addon.id)")
                child.parentServiceID = r.id; child.serviceType = addon.resolvedServiceType.rawValue
                child.website = r.website; child.brandName = r.title
                child.activeService = r.activeService && addon.status == .active
                child.monthlyCost = SearchText.decimal(addon.cost).map { $0 / (addon.billingCycle == .yearly ? 12 : 1) }
                child.currency = r.currency; child.date = addon.renewsOn; child.dueDate = addon.renewsOn
                child.financialFacts = ["billingAmount": SearchText.number(addon.cost), "billingCycle": addon.billingCycle.rawValue, "status": addon.status.rawValue]
                let inheritsPayment = addon.paymentMethodId == nil && addon.paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                child.safeDetails = ["purpose": redactor.clean(addon.purpose), "parentService": redactor.clean(sub.name),
                    "paymentMethod": redactor.clean(inheritsPayment ? (sub.paymentMethod ?? "") : addon.paymentMethod), "renewalMode": addon.autoPay.rawValue]
                records.append(child); link(child.id, r.id)
                if let paymentID = addon.paymentMethodId {
                    for target in records where target.companyID == cid && target.modelID == paymentID && [.card, .institution].contains(target.kind) { link(child.id, target.id) }
                    for target in accountAliases[paymentID.uuidString] ?? [] { link(child.id, target) }
                } else if !inheritsPayment {
                    let candidates = records.filter { $0.companyID == cid && [.card, .account, .institution].contains($0.kind) && $0.normalizedTitle == SearchText.normalize(addon.paymentMethod) }
                    if candidates.count == 1 { link(child.id, candidates[0].id) }
                }
            }
            if let paymentID = sub.paymentMethodId {
                for target in records where target.modelID == paymentID && [.card, .institution].contains(target.kind) { link(r.id, target.id) }
                for target in accountAliases[paymentID.uuidString] ?? [] { link(r.id, target) }
            }
            if let plaidID = sub.plaidAccountId, let targets = accountAliases[plaidID] {
                for target in targets { link(r.id, target) }
            } else if sub.paymentMethodId == nil, let name = sub.paymentMethod, !name.isEmpty {
                let candidates = records.filter { $0.companyID == cid && [.card, .account, .institution].contains($0.kind) && $0.normalizedTitle == SearchText.normalize(name) }
                if candidates.count == 1 { link(r.id, candidates[0].id) }
            }
            let parentPayments = (links[r.id] ?? []).filter { id in records.contains { $0.id == id && [.card, .account, .institution].contains($0.kind) } }
            for addon in sub.subServices where addon.paymentMethodId == nil && addon.paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                for target in parentPayments { link(r.id + ":addon:" + addon.id, target) }
            }
        }
        for loan in appState.loans where allowed(loan.id, loan.userId, loan.companyId) {
            let cid = companyID(loan.id, loan.companyId)
            var r = make(.loan, loan.id, cid, loan.name, "\(loan.role) · \(loan.status)", "\(loan.lender ?? "") \(loan.notes ?? "")")
            r.date = loan.nextPaymentAt; r.dueDate = loan.nextPaymentAt
            r.amount = SearchText.decimal(loan.remainingBalance)
            r.balanceCategory = loan.role.lowercased() == "lender" ? .receivable : .loan
            r.balanceAliases = ["loan:\(loan.id.uuidString)"]
            if let plaid = loan.plaidAccountId, !plaid.isEmpty { r.balanceAliases.insert("plaid:\(plaid)") }
            r.financialFacts = ["currentBalance": SearchText.number(loan.remainingBalance), "principalAmount": SearchText.number(loan.principalAmount),
                "balanceCategory": r.balanceCategory!.rawValue, "role": redactor.clean(loan.role), "status": redactor.clean(loan.status),
                "interestType": redactor.clean(loan.interestType), "storedInterestRate": SearchText.number(loan.interestRate),
                "storedMonthlyPayment": SearchText.number(loan.monthlyPayment), "paymentFrequency": redactor.clean(loan.scheduleFrequency),
                "nextPayment": SearchText.day(loan.nextPaymentAt), "maturityDate": SearchText.day(loan.maturityDate),
                "currencyBasis": "USD app default; loan has no currency field"]
            r.safeDetails = ["notes": redactor.clean(loan.notes ?? ""), "lender": redactor.clean(loan.lender ?? ""), "term": redactor.clean(loan.term), "startDate": SearchText.day(loan.startDate), "paidOffDate": SearchText.day(loan.paidOffDate)]
            records.append(r)
            for payment in loan.payments ?? [] {
                var p = make(.payment, payment.id, cid, "\(loan.name) payment", "\(payment.date.formatted(date: .abbreviated, time: .omitted)) · \(payment.amount.formatted(.number.precision(.fractionLength(2))))", payment.source ?? "")
                p.amount = SearchText.decimal(payment.amount); p.financialFacts["paymentAmount"] = SearchText.number(payment.amount)
                p.date = payment.date; p.destinationID = loan.id; p.destinationKind = .loan
                records.append(p); link(p.id, r.id)
            }
        }
        // Union only durable identities, scoped by company, currency and balance category.
        // This prevents a bank account and its mirrored card from inflating totals.
        var balanceParents: [String: String] = [:]
        func root(_ value: String) -> String {
            var value = value
            while let parent = balanceParents[value], parent != value { value = parent }
            return value
        }
        for record in records where record.balanceCategory != nil {
            let scope = "\(record.companyID?.uuidString ?? "unassigned")|\(record.currency)|\(record.balanceCategory!.rawValue)|"
            let keys = record.balanceAliases.sorted().map { scope + $0 }
            guard let first = keys.first else { continue }
            for key in keys { balanceParents[root(key)] = root(first) }
        }
        var opaqueIdentities: [String: String] = [:]
        for index in records.indices where records[index].balanceCategory != nil {
            let record = records[index]
            let scope = "\(record.companyID?.uuidString ?? "unassigned")|\(record.currency)|\(record.balanceCategory!.rawValue)|"
            guard let alias = record.balanceAliases.sorted().first else { continue }
            let identity = root(scope + alias)
            // Only a source ID is exposed; never send bank/provider identifiers to the model.
            if opaqueIdentities[identity] == nil { opaqueIdentities[identity] = record.id }
            records[index].balanceIdentity = opaqueIdentities[identity]
        }
        let visibleDocuments = appState.documents.filter { allowed($0.id, $0.userId, $0.companyId) && ($0.visibility != "owner_private" || $0.userId == userID) }
        for doc in visibleDocuments {
            let cid = companyID(doc.id, doc.companyId)
            var r = make(.document, doc.id, cid, doc.name, doc.type, doc.notes ?? "")
            r.safeDetails = ["notes": redactor.clean(doc.notes ?? ""), "documentType": redactor.clean(doc.type), "expirationDate": SearchText.day(doc.expiresAt)]
            for (key, value) in doc.renewalMetadata { r.safeDetails[redactor.clean(key)] = redactor.clean(value) }
            r.date = doc.uploadDate.flatMap { SearchText.date($0) }; r.dueDate = doc.expiresAt; records.append(r)
            for page in documentPages where page.documentID == doc.id && page.sourceURL == doc.url {
                var p = make(.document, doc.id, cid, doc.name, "\(doc.type) · Page \(page.page)", page.text, suffix: ":page:\(page.page)")
                p.page = page.page; p.date = r.date; p.dueDate = doc.expiresAt; records.append(p); link(p.id, r.id)
            }
        }
        let transactions = appState.transactions.filter { t in
            t.userId == userID || (t.companyId.map(allowedCompanies.contains) ?? false)
        }
        let accountRecordsByID = Dictionary(records.filter { [.card, .account].contains($0.kind) }.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for resolved in TransactionIntelligence.resolveAll(transactions, companies: companies, institutions: institutions, cards: cards,
            overrides: appState.transactionOverrides.filter { $0.userId == userID }, categoryRules: appState.transactionCategoryRules.filter { $0.userId == userID }) {
            if Task.isCancelled { records = []; links = [:]; isLoaded = false; return }
            let t = resolved.transaction
            let aliasesForTransaction = [t.accountId, t.sourceAccountId, t.canonicalAccountId].compactMap { $0 }
            let targets = aliasesForTransaction.reduce(into: Set<String>()) { $0.formUnion(accountAliases[$1] ?? []) }
            let linkedAccounts = targets.compactMap { accountRecordsByID[$0] }
            // Opaque Plaid IDs are not account numbers; never present their suffix as a card ending.
            let accountName = linkedAccounts.isEmpty && resolved.accountName == "Account •••• \(t.accountId.suffix(4))" ? "Unassigned account" : resolved.accountName
            let linkedCompanyIDs = Set(linkedAccounts.compactMap(\.companyID))
            // A local reassignment also moves the related transaction in search.
            let cid = linkedCompanyIDs.count == 1 ? linkedCompanyIDs.first : resolved.companyId
            let amount = t.amount.flatMap { SearchText.decimal(abs($0)) }
            let value = amount.map { SearchText.money($0, currency: t.currency) } ?? "Amount unavailable"
            let flow = TransactionIntelligence.effectiveFlow(for: resolved).rawValue
            var r = make(.transaction, t.id, cid, TransactionIntelligence.displayName(for: resolved),
                "\(value) · \(t.date) · \(accountName)\(linkedAccounts.first.map { $0.last4.isEmpty ? "" : " •••• \($0.last4)" } ?? "") · \(t.pending == true ? "Pending" : flow.capitalized)",
                "\(resolved.institutionName) \(TransactionIntelligence.categoryPrimary(for: resolved) ?? "") \(resolved.override?.note ?? "")")
            r.category = redactor.clean(TransactionIntelligence.categoryPrimary(for: resolved) ?? "Uncategorized")
            r.logoURL = t.merchantLogoURL
            r.website = t.merchantWebsite.map(redactor.clean)
            r.accountName = redactor.clean(accountName)
            r.safeDetails = ["notes": redactor.clean(resolved.override?.note ?? ""), "institution": redactor.clean(resolved.institutionName)]
            r.amount = amount; r.currency = ExecutiveBriefingSnapshot.currency(t.currency); r.date = SearchText.date(t.date); r.flow = flow; r.pending = t.pending == true
            r.financialFacts = ["transactionAmount": amount.map { NSDecimalNumber(decimal: $0).stringValue } ?? "Unavailable", "flow": flow, "pending": r.pending ? "Yes" : "No"]
            records.append(r)
            for target in targets { link(r.id, target) }
            for account in linkedAccounts where account.kind == .account { link(r.id, key(.institution, account.modelID)) }
            if let institutionID = t.institutionId { link(r.id, key(.institution, institutionID)) }
        }
        for edge in appState.resourceConnections where edge.state == .confirmed && edge.relationshipType != .belongsTo {
            link("\(edge.sourceType.rawValue):\(edge.sourceId.uuidString)", "\(edge.targetType.rawValue):\(edge.targetId.uuidString)")
        }
        let sourceRecords = Dictionary(records.filter { $0.page == nil }.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for obligation in appState.obligations {
            let sourceID = "\(obligation.sourceType.rawValue):\(obligation.sourceId.uuidString)"
            guard let source = sourceRecords[sourceID] else { continue }
            var r = make(.obligation, obligation.id, source.companyID, obligation.title, obligation.severity.rawValue.capitalized, obligation.summary)
            r.safeDetails = ["state": obligation.state.rawValue, "summary": redactor.clean(obligation.summary), "snoozedUntil": SearchText.day(obligation.snoozedUntil)]
            r.date = obligation.dueAt; r.dueDate = obligation.dueAt; r.destinationID = source.modelID; r.destinationKind = source.kind
            records.append(r); link(r.id, sourceID)
        }
        // Supplement the primary records with the other user-visible portfolio areas.
        let authorizedIDs = Set(records.map(\.modelID))
        for review in appState.businessExpenseReviews where appState.businessExpenseUserID == userID {
            // Reviews have no owner field. Require the underlying authorized transaction;
            // manual reviews require an owned company, not merely a shared-company membership.
            let cid = review.allocation?.companyId ?? review.source.sourceCompanyId
            let sourceAllowed = review.transactionId.map(authorizedIDs.contains) ?? companies.contains { $0.id == cid && $0.userId == userID }
            guard sourceAllowed else { continue }
            var r = make(.expenseReview, review.id, cid, review.source.merchant, "Expense review · " + review.decision,
                [review.allocation?.purpose, review.allocation?.notes, review.allocation?.context, review.allocation?.category].compactMap { $0 }.joined(separator: " ") + " " + review.missing.joined(separator: " "))
            r.amount = review.businessAmount; r.currency = ExecutiveBriefingSnapshot.currency(review.source.currency ?? "USD")
            r.date = SearchText.date(review.source.date); r.accountName = redactor.clean(review.source.accountName)
            r.category = redactor.clean(review.allocation?.category ?? "")
            r.safeDetails = ["decision": redactor.clean(review.decision), "missing": redactor.clean(review.missing.joined(separator: ", ")), "purpose": redactor.clean(review.allocation?.purpose ?? ""), "notes": redactor.clean(review.allocation?.notes ?? ""), "receiptCount": String(review.documents.count)]
            records.append(r)
            if let id = review.transactionId { link(r.id, key(.transaction, id)) }
        }
        for notice in appState.notifications where notice.userId == userID {
            var r = make(.notification, notice.id, nil, notice.title, notice.isRead ? "Read notification" : "Unread notification", notice.body)
            r.date = notice.createdAt; r.safeDetails = ["message": redactor.clean(notice.body)]
            records.append(r)
        }
        for event in appState.activityLogs where event.userId == userID {
            var r = make(.activity, event.id, nil, event.actionType, event.message)
            r.date = event.createdAt; records.append(r)
        }
        for share in appState.resourceShares where share.userId == userID && authorizedIDs.contains(share.resourceId) {
            let source = records.first { $0.modelID == share.resourceId }
            var r = make(.sharing, share.id, source?.companyID, source?.title ?? "Shared record", "Your access: " + share.role, share.senderDisplayName ?? "")
            r.safeDetails = ["role": redactor.clean(share.role), "sharedBy": redactor.clean(share.senderDisplayName ?? "")]
            records.append(r)
            if let source { link(r.id, source.id) }
        }
        if let preferences = appState.userPreferences, preferences.userId == userID {
            var r = make(.settings, userID, nil, "Notification settings", "Reminders, messages, briefing and alerts", "preferences settings timezone")
            r.safeDetails = ["remindersEnabled": String(preferences.remindersEnabled), "messagesEnabled": String(preferences.messagesEnabled), "weeklyBriefingEnabled": preferences.weeklyBriefingEnabled.map(String.init) ?? "Not configured", "criticalAlertsEnabled": preferences.criticalAlertsEnabled.map(String.init) ?? "Not configured", "timeZone": redactor.clean(preferences.timezone ?? "Not configured")]
            records.append(r)
        }
        for rule in appState.alertRules where rule.userId == userID {
            var r = make(.alert, userID, nil, rule.ruleType.rawValue, rule.enabled ? "Alert enabled" : "Alert disabled", suffix: ":\(rule.ruleType.rawValue)")
            r.safeDetails = ["enabled": String(rule.enabled), "thresholdAmount": SearchText.number(rule.thresholdAmount), "thresholdPercent": SearchText.number(rule.thresholdPercent), "lookbackDays": rule.lookbackDays.map(String.init) ?? "Not configured", "leadDays": rule.leadDays.map(String.init) ?? "Not configured"]
            records.append(r)
        }
        // Index the same safe fields exposed by detail retrieval, including statuses and amounts.
        records = records.map { original in
            var record = original
            let fields = (record.safeDetails.keys.sorted().map { "\($0) \(record.safeDetails[$0]!)" } + record.financialFacts.keys.sorted().map { "\($0) \(record.financialFacts[$0]!)" }).joined(separator: " ")
            record.normalizedText = SearchText.normalize(record.normalizedText + " " + fields)
            record.words = Set(record.normalizedText.split(separator: " ").map(String.init))
            return record
        }
        if appState.businessExpenseUserID == userID {
            var settings = make(.settings, userID, nil, "Business expense settings", "Expense analysis and business profiles", "tax receipts scanning", suffix: ":business-expenses")
            settings.safeDetails = ["enabled": String(appState.businessExpenseSettings.enabled), "excludedAccounts": redactor.clean(appState.businessExpenseAccounts.filter { appState.businessExpenseSettings.excludedAccountIds.contains($0.exclusionKey) }.compactMap(\.name).joined(separator: ", "))]
            if let job = appState.businessExpenseJob {
                settings.safeDetails.merge(["latestScan": redactor.clean(job.state), "scannedCount": String(job.scanned), "suggestedCount": String(job.suggested), "dateFrom": job.dateFrom, "dateTo": job.dateTo], uniquingKeysWith: { a, _ in a })
            }
            records.append(settings)
            for profile in appState.businessExpenseProfiles where allowedCompanies.contains(profile.companyId) {
                var r = make(.settings, profile.companyId, profile.companyId, "Business profile", profile.activity, suffix: ":business-profile")
                r.safeDetails = ["activity": redactor.clean(profile.activity), "enabled": String(profile.enabled)]
                records.append(r)
            }
        }
        let ownedIDs = Set(appState.subscriptions.filter { $0.userId == userID }.map(\.id)
            + appState.institutions.filter { $0.userId == userID }.map(\.id)
            + appState.cards.filter { $0.userId == userID }.map(\.id))
        for i in records.indices where [.subscription, .institution, .account, .card].contains(records[i].kind) {
            let record = records[i]
            if ownedIDs.contains(record.modelID) { records[i].safeDetails["yourAccess"] = "Owner" }
            else if let share = appState.resourceShares.first(where: { $0.userId == userID && ($0.resourceId == record.modelID || $0.resourceId == record.companyID) }) {
                records[i].safeDetails["yourAccess"] = redactor.clean(share.role.capitalized)
                records[i].safeDetails["sharedBy"] = redactor.clean(share.senderDisplayName ?? "")
            }
        }
        let validIDs = Set(records.map(\.id))
        links = links.filter { validIDs.contains($0.key) }.mapValues { $0.intersection(validIDs) }
        let indexedDocs = Set(documentPages.map(\.documentID)).intersection(Set(visibleDocuments.map(\.id))).count
        coverage = "Loaded portfolio · \(transactions.count) transactions · document text \(indexedDocs)/\(visibleDocuments.count)"
        if appState.portfolioLoadIssue != nil { coverage += " · Refresh incomplete: answers may be partial" }
        if appState.businessExpenseLoadError != nil || appState.businessExpenseUserID != userID { coverage += " · Expense reviews unavailable or not yet loaded" }
        coverage += " · " + redactor.clean(appState.searchDocumentStatus)
        if institutions.contains(where: \.isDisconnected) { coverage += " · A bank connection needs attention" }
    }

    init(records: [SearchRecord], links: [String: Set<String>] = [:]) {
        self.records = records; self.links = links; self.isLoaded = true; self.coverage = "Loaded records"
    }

    private mutating func link(_ a: String, _ b: String) {
        guard a != b else { return }
        links[a, default: []].insert(b); links[b, default: []].insert(a)
    }

    func matching(_ query: String, filters: SearchFilters = .init(), now: Date = Date(), calendar: Calendar = .current) -> SearchResponse {
        let plan = SearchQuery(query, filters: filters, now: now, calendar: calendar)
        var response = SearchResponse(interpretation: plan.description, coverage: coverage, isCredentialRequest: plan.credentials)
        guard isLoaded, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !plan.tokens.isEmpty || query == "all records" || plan.kind != nil || plan.credentials || plan.renewals || plan.financial else { return response }
        if plan.balanceQuery, plan.dates != nil {
            response.interpretation = "Historical balances are unavailable. Search without a date for the latest saved balance."
            return response
        }
        func inScope(_ r: SearchRecord, checkKind: Bool = true) -> Bool {
            if let serviceType = filters.serviceType, r.serviceType != serviceType { return false }
            if let cid = filters.companyID, r.companyID != cid { return false }
            if let kind = filters.kind, kind != r.kind { return false }
            if checkKind, let kind = plan.kind, kind != r.kind {
                let financialAccount = plan.financial && r.kind == .account &&
                    (kind == .institution || (kind == .card && (r.balanceCategory == .credit || (r.financialFacts["accountType"] ?? "").lowercased().contains("debit"))) || (kind == .loan && r.balanceCategory == .loan))
                if !financialAccount { return false }
            }
            if plan.financial && ![.card, .account, .institution, .loan].contains(r.kind) { return false }
            if plan.debtOnly && ![.credit, .loan].contains(r.balanceCategory) { return false }
            if plan.creditOnly && r.balanceCategory != .credit { return false }
            if plan.cashOnly && r.balanceCategory != .cash { return false }
            if plan.credentials && r.credential == .none && r.login.isEmpty { return false }
            let matchedDate = plan.renewals && r.kind == .document ? r.dueDate : r.date
            if let range = plan.dates, !(matchedDate.map { $0 >= range.start && $0 < range.end } ?? false) { return false }
            if plan.renewals && ![.subscription, .loan, .card, .document, .obligation].contains(r.kind) { return false }
            if plan.renewals && r.kind == .subscription && !r.activeService { return false }
            return true
        }
        let direct = records.compactMap { r -> SearchHit? in
            guard !Task.isCancelled, inScope(r) else { return nil }
            var score = 0, fuzzy = false
            for token in plan.tokens {
                if token.count == 4, token.allSatisfy(\.isNumber), r.last4 == token { score += 1500 }
                else if r.words.contains(token) { score += r.normalizedTitle.split(separator: " ").contains(Substring(token)) ? 150 : 40 }
                else if !token.allSatisfy(\.isNumber), r.words.contains(where: { $0.hasPrefix(token) }) { score += 25 }
                else if r.words.contains(where: { SearchText.typo(token, $0) }) { score += 5; fuzzy = true }
                else { return nil }
            }
            if r.normalizedTitle == plan.tokens.joined(separator: " ") { score += 700 }
            if r.page != nil { score -= 5 }
            if plan.financial && r.amount != nil { score += 10 }
            let exactEnding = plan.tokens.contains { $0.count == 4 && $0.allSatisfy(\.isNumber) && $0 == r.last4 }
            let reason = exactEnding ? "Exact card/account ending" : fuzzy ? "Similar spelling" : plan.credentials ? "Saved login" : r.page != nil ? "Document contents" : "Matching \(r.kind.label.lowercased())"
            return SearchHit(record: r, score: score, reason: reason, snippet: snippet(r.text, tokens: plan.tokens))
        }
        guard !Task.isCancelled else { return response }
        var hits = Dictionary(direct.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        // One hop only, so a four-digit query cannot fan out through a bank to unrelated accounts.
        if !plan.credentials && plan.dates == nil && (plan.relationships || direct.contains { $0.reason == "Exact card/account ending" }) {
            let byID = Dictionary(records.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            for match in direct where match.record.kind != .transaction {
                for id in links[match.id] ?? [] {
                    guard hits[id] == nil, let r = byID[id], inScope(r, checkKind: false) else { continue }
                    hits[id] = SearchHit(record: r, score: -100, reason: "Linked to \(match.record.title) · \(match.record.company)")
                }
            }
        }
        response.hits = hits.values.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.record.date != $1.record.date { return ($0.record.date ?? .distantPast) > ($1.record.date ?? .distantPast) }
            if $0.record.title != $1.record.title { return $0.record.title.localizedStandardCompare($1.record.title) == .orderedAscending }
            return $0.id < $1.id
        }
        if plan.balanceQuery {
            let balances = response.hits.map(\.record).filter { $0.balanceCategory != nil }
            let groups = Dictionary(grouping: balances, by: { $0.balanceIdentity ?? $0.id })
            let unique = groups.values.compactMap { group in group.sorted {
                if ($0.kind == .account) != ($1.kind == .account) { return $0.kind == .account }
                if $0.lastSyncedAt != $1.lastSyncedAt { return ($0.lastSyncedAt ?? .distantPast) > ($1.lastSyncedAt ?? .distantPast) }
                return $0.id < $1.id
            }.first }
            for group in Dictionary(grouping: unique, by: { "\($0.currency)|\($0.balanceCategory!.rawValue)|\(plan.groupByCompany ? $0.companyID?.uuidString ?? "unassigned" : "all")" }).values {
                guard let first = group.first else { continue }
                let available = group.filter { plan.availableOnly ? $0.availableAmount != nil : $0.amount != nil }
                guard !available.isEmpty else { continue }
                let label = plan.availableOnly ? (first.balanceCategory == .credit ? "Available credit" : "Available · \(first.balanceCategory!.rawValue)") : first.balanceCategory!.rawValue
                response.totals.append(SearchTotal(label: label + (plan.groupByCompany ? " · \(first.company)" : ""), currency: first.currency,
                    amount: available.reduce(.zero) { $0 + (plan.availableOnly ? $1.availableAmount! : $1.amount!) }, sourceIDs: available.map(\.id)))
            }
            if unique.count < balances.count { response.interpretation += " · Linked account/card copies counted once; bank account balances preferred" }
            if unique.contains(where: { plan.availableOnly ? $0.availableAmount == nil : $0.amount == nil }) {
                response.interpretation += " · Totals are partial: unavailable balances excluded"
            }
            response.interpretation += " · Saved balances, not a live bank refresh; currencies and balance categories kept separate"
        } else if plan.kind == .transaction {
            let posted = response.hits.map(\.record).filter { !$0.pending && $0.amount != nil && ["expense", "income", "refund"].contains($0.flow) }
            for group in Dictionary(grouping: posted, by: { "\($0.currency)|\($0.flow)" }).values {
                guard let first = group.first else { continue }
                response.totals.append(SearchTotal(label: "Posted \(first.flow == "expense" ? "expenses" : first.flow == "refund" ? "refunds" : "income")", currency: first.currency,
                    amount: group.reduce(.zero) { $0 + ($1.amount ?? 0) }, sourceIDs: group.map(\.id)))
            }
            response.interpretation += " · Totals exclude pending, transfers and ignored transactions"
        } else if plan.monthlySpend {
            let services = response.hits.map(\.record).filter { $0.kind == .subscription && $0.activeService }
            for group in Dictionary(grouping: services.filter { $0.monthlyCost != nil }, by: { "\($0.currency)|\(plan.groupByCompany ? $0.companyID?.uuidString ?? "unassigned" : "all")" }).values {
                guard let first = group.first else { continue }
                response.totals.append(SearchTotal(label: "Monthly equivalent" + (plan.groupByCompany ? " · \(first.company)" : ""), currency: first.currency,
                    amount: group.reduce(.zero) { $0 + ($1.monthlyCost ?? 0) }, sourceIDs: group.map(\.id)))
            }
            if services.contains(where: { $0.monthlyCost == nil }) { response.interpretation += " · Unknown billing cycles excluded" }
        }
        response.totals.sort { $0.id < $1.id }
        return response
    }

    private func snippet(_ text: String, tokens: [String]) -> String? {
        guard !text.isEmpty, let token = tokens.first(where: { text.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }),
              let range = text.range(of: token, options: [.caseInsensitive, .diacriticInsensitive]) else { return nil }
        let start = text.index(range.lowerBound, offsetBy: -60, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: 140, limitedBy: text.endIndex) ?? text.endIndex
        return (start == text.startIndex ? "" : "…") + String(text[start..<end]).replacingOccurrences(of: "\n", with: " ") + (end == text.endIndex ? "" : "…")
    }
}

struct SearchQuery {
    var tokens: [String]
    var kind: SearchRecord.Kind?
    var credentials: Bool
    var relationships: Bool
    var renewals: Bool
    var monthlySpend: Bool
    var groupByCompany: Bool
    var financial: Bool
    var balanceQuery: Bool
    var availableOnly: Bool
    var debtOnly: Bool
    var creditOnly: Bool
    var cashOnly: Bool
    var dates: DateInterval?
    var description: String

    init(_ text: String, filters: SearchFilters, now: Date, calendar: Calendar) {
        let normalized = SearchText.normalize(text)
        var words = normalized.split(separator: " ").map(String.init)
        let set = Set(words)
        credentials = filters.credentialsOnly || !set.isDisjoint(with: ["password", "passwords", "login", "logins", "username", "credentials"])
        relationships = !set.isDisjoint(with: ["uses", "linked", "connected", "pays", "pay", "paid"])
        renewals = !set.isDisjoint(with: ["renew", "renews", "renewal", "renewals", "renewing", "due", "expires", "expiring"])
        balanceQuery = !credentials && (!set.isDisjoint(with: ["balance", "balances", "owe", "owed", "debt", "debts", "available"])
            || (!set.isDisjoint(with: ["money", "cash", "funds"]) && !set.isDisjoint(with: ["much", "have", "total"])))
        financial = balanceQuery || (!credentials && !set.isDisjoint(with: ["apr", "apy", "limit", "limits", "principal", "autopay", "interest"]))
            || (!credentials && !set.isDisjoint(with: ["payment", "payments"]) && !set.isDisjoint(with: ["monthly", "minimum", "next", "due"]))
        availableOnly = balanceQuery && set.contains("available")
        debtOnly = balanceQuery && !set.isDisjoint(with: ["owe", "owed", "debt", "debts"])
        creditOnly = financial && set.contains("credit")
        cashOnly = financial && !set.isDisjoint(with: ["cash", "money", "funds"])
        if financial && !set.isDisjoint(with: ["payment", "payments"]) { renewals = false }
        groupByCompany = normalized.contains("per company") || normalized.contains("by company")
        monthlySpend = !set.isDisjoint(with: ["subscriptions", "subscription", "services", "bills", "bill"]) && !set.isDisjoint(with: ["spend", "cost", "total", "spending"])
        kind = filters.kind
        let aliases: [(SearchRecord.Kind, Set<String>)] = [(.transaction, ["transaction", "transactions", "charge", "charges", "charged", "expense", "expenses", "income", "refunds", "transfers", "purchase", "purchases"]),
            (.subscription, ["subscription", "subscriptions", "service", "services", "bill", "bills"]), (.card, ["card", "cards"]),
            (.institution, ["bank", "banks"]), (.account, ["account", "accounts"]), (.payment, ["payment", "payments"]), (.loan, ["loan", "loans"]), (.document, ["document", "documents", "pdf", "file", "files"]), (.company, ["company", "companies", "entity", "entities"]), (.expenseReview, ["receipts", "receipt", "reviews", "expensereview"]), (.notification, ["notifications", "notification"]), (.activity, ["activity", "history"]), (.settings, ["settings", "preferences"]), (.alert, ["alerts", "alert"]), (.sharing, ["sharing", "shared"])]
        if !credentials, kind == nil { kind = aliases.first { !set.isDisjoint(with: $0.1) }?.0 }
        if monthlySpend { kind = .subscription }
        if financial && filters.kind == nil && [.payment, .company].contains(kind) { kind = nil }
        var period = filters.period
        let relative: [(String, SearchFilters.Period)] = [("last month", .lastMonth), ("this month", .thisMonth), ("next month", .nextMonth)]
        for (phrase, value) in relative where normalized.contains(phrase) {
            if filters.period == .all { period = value }
            for word in phrase.split(separator: " ") { words.removeAll { $0 == word } }
        }
        if period != .all, let month = calendar.dateInterval(of: .month, for: now) {
            let offset = period == .lastMonth ? -1 : period == .nextMonth ? 1 : 0
            if let start = calendar.date(byAdding: .month, value: offset, to: month.start), let end = calendar.date(byAdding: .month, value: 1, to: start) {
                dates = DateInterval(start: start, end: end)
            }
        }
        if dates == nil {
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
            let months = formatter.monthSymbols ?? []
            for (offset, month) in months.enumerated() where words.contains(month.lowercased()) {
                let yearToken = words.first { $0.count == 4 && Int($0).map { (2000...2100).contains($0) } == true }
                let year = yearToken.flatMap(Int.init) ?? calendar.component(.year, from: now)
                if let start = calendar.date(from: DateComponents(year: year, month: offset + 1, day: 1)), let end = calendar.date(byAdding: .month, value: 1, to: start) {
                    dates = DateInterval(start: start, end: end)
                    words.removeAll { $0 == month.lowercased() || $0 == yearToken }
                }
            }
        }
        let filler: Set<String> = ["what", "which", "where", "is", "are", "was", "were", "my", "the", "a", "an", "of", "for", "in", "on", "at", "from", "to", "with", "me", "show", "find", "search", "please", "how", "much", "do", "does", "i", "all", "and", "this", "that", "uses", "linked", "connected", "pays", "pay", "paid", "ending", "ends", "digits", "last", "credit", "debit", "password", "passwords", "login", "logins", "username", "credentials"]
        var ignored = filler
        aliases.forEach { ignored.formUnion($0.1) }
        if renewals { ignored.formUnion(["renew", "renews", "renewal", "renewals", "renewing", "due", "expires", "expiring"]) }
        if financial { ignored.formUnion(["balance", "balances", "owe", "owed", "debt", "debts", "available", "apr", "apy", "limit", "limits", "principal", "autopay", "interest", "rate", "rates", "payment", "payments", "monthly", "minimum", "next", "due", "total", "totals", "per", "by", "current", "currently", "have", "has", "remaining", "outstanding", "cash", "money", "funds", "today", "now", "right", "get", "give", "tell", "can", "you", "s"] ) }
        ignored.formUnion(["website", "notes", "note", "when", "will", "expire", "expiration"])
        if monthlySpend { ignored.formUnion(["spend", "cost", "total", "spending", "per", "by", "monthly"]) }
        if normalized == "all records" { ignored.formUnion(["records"]) }
        tokens = words.filter { !ignored.contains($0) }
        description = credentials ? "Choose a saved login to reveal or copy" : monthlySpend ? "Active services, normalized to a monthly equivalent" : financial ? "Saved financial details" : renewals ? "Renewals and due dates" : "Best matches"
        if let dates { description += " · \(dates.start.formatted(date: .abbreviated, time: .omitted))–\(calendar.date(byAdding: .day, value: -1, to: dates.end)!.formatted(date: .abbreviated, time: .omitted))" }
    }
}
