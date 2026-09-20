import Foundation

extension String {
    var cleanAccountName: String {
        var str = self
        while str.hasPrefix("-") || str.hasPrefix(" ") {
            str.removeFirst()
        }
        return str
    }
}

struct InstitutionAccount: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var plaidAccountId: String? = nil
    var name: String = ""
    var type: String = "Checking"
    var last4: String = ""
    var accountNumber: String? = nil
    var routingNumber: String? = nil
    var wireRoutingNumber: String? = nil
    var isTokenizedAccountNumber: Bool? = nil
    var balance: Double = 0
    var availableBalance: Double? = nil
    var currency: String = "USD"
    var apy: Double? = nil
    var ownershipType: String? = nil
    var verificationStatus: String? = nil
    var persistentAccountId: String? = nil
    var cardHolder: String = ""
    var expiry: String = ""
    var network: String = ""
    var status: String = "Active"
    var limit: Double = 0
    var paidFrom: String = ""
    var paidOn: String = ""
    var autopay: String = "N/A"
    var linkedCardId: String? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case plaidAccountId = "plaid_account_id"
        case name, type, last4, accountNumber, routingNumber, wireRoutingNumber
        case isTokenizedAccountNumber, balance, availableBalance, currency, apy
        case ownershipType, verificationStatus, persistentAccountId, cardHolder
        case expiry, network, status, limit, paidFrom, paidOn, autopay, linkedCardId
    }

    static let allTypes = [
        "Checking", "Savings", "Investing", "CD",
        "FSA", "HSA",
        "401(k)", "Roth 401(k)", "IRA", "Roth IRA",
        "Rollover IRA", "SEP IRA", "529", "Other"
    ]

    var isCard: Bool {
        ["Credit Card", "Debit Card", "Debit (Linked)", "FSA", "HSA"].contains(type)
    }
}

struct Institution: Identifiable, Codable, Hashable {
    var id: UUID
    var userId: UUID
    var companyId: UUID
    var name: String
    var loginUrl: String?
    var username: String?
    var email: String?
    var password: String?
    var twoFactor: String?
    var accountsData: [InstitutionAccount]
    var lastSyncedAt: Date?
    var isDisconnected: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case companyId = "company_id"
        case name
        case loginUrl = "login_url"
        case username
        case email
        case password
        case twoFactor = "two_factor"
        case accountsData = "accounts_data"
        case lastSyncedAt = "last_synced_at"
        case isDisconnected = "is_disconnected"
    }
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        companyId: UUID,
        name: String = "",
        loginUrl: String? = nil,
        username: String? = nil,
        email: String? = nil,
        password: String? = nil,
        twoFactor: String? = nil,
        accounts: [InstitutionAccount] = [],
        lastSyncedAt: Date? = nil,
        isDisconnected: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.companyId = companyId
        self.name = name
        self.loginUrl = loginUrl
        self.username = username
        self.email = email
        self.password = password
        self.twoFactor = twoFactor
        self.accountsData = accounts
        self.lastSyncedAt = lastSyncedAt
        self.isDisconnected = isDisconnected
    }

    var accounts: [InstitutionAccount] {
        get { accountsData }
        set { accountsData = newValue }
    }

    var nonCardAccounts: [InstitutionAccount] {
        accounts.filter { !$0.isCard }
    }
}

/// Local presentation associations, never persisted or promoted to confirmed connections.
/// Callers supply only the records visible in their authorized scope.
struct InstitutionRelationships {
    struct Bank {
        var id: UUID
        var companyID: UUID?
        var name: String
        var accountAliases: Set<String> = []
    }

    static func bankIDs(companyID: UUID?, savedName: String?, aliases: Set<String>,
                        explicitBankIDs: Set<UUID>, banks: [Bank], hasExplicitAssociation: Bool = false) -> Set<UUID> {
        let scoped = banks.filter { $0.companyID == companyID }
        let durable = scoped.filter { explicitBankIDs.contains($0.id) || !$0.accountAliases.isDisjoint(with: aliases) }
        if !durable.isEmpty { return Set(durable.map(\.id)) }
        // Even an unavailable explicit bank must not fall back to a contradictory name.
        guard explicitBankIDs.isEmpty, !hasExplicitAssociation else { return [] }
        func name(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        guard let savedName, !name(savedName).isEmpty else { return [] }
        let matches = scoped.filter { name($0.name) == name(savedName) }
        return matches.count == 1 ? Set(matches.map(\.id)) : []
    }

    private var associations: [String: Set<UUID>] = [:]

    func banks(for kind: ResourceKind, id: UUID) -> Set<UUID> {
        associations["\(kind.rawValue):\(id.uuidString)"] ?? []
    }

    init(institutions: [Institution], cards: [FinancialCard], loans: [Loan],
         connections: [ResourceConnection], companyOverrides: [String: UUID] = [:]) {
        func company(_ id: UUID, _ fallback: UUID) -> UUID { companyOverrides[id.uuidString] ?? fallback }
        let banks = institutions.map { bank in
            Bank(id: bank.id, companyID: company(bank.id, bank.companyId), name: bank.name,
                 accountAliases: Set(bank.accounts.flatMap { account -> [String] in
                     var aliases: [String] = []
                     if let card = account.linkedCardId.flatMap(UUID.init(uuidString:)) { aliases.append("card:\(card.uuidString)") }
                     if let plaid = account.plaidAccountId, !plaid.isEmpty { aliases.append("plaid:\(plaid)") }
                     return aliases
                 }))
        }
        func resolve(_ kind: ResourceKind, _ id: UUID, _ companyID: UUID, _ savedName: String?, _ plaid: String?) -> Set<UUID> {
            var aliases: Set<String> = ["\(kind.rawValue):\(id.uuidString)"]
            if let plaid, !plaid.isEmpty { aliases.insert("plaid:\(plaid)") }
            let explicit = Set(connections.compactMap { edge -> UUID? in
                guard edge.state == .confirmed, edge.relationshipType != .belongsTo else { return nil }
                if edge.sourceType == kind, edge.sourceId == id, edge.targetType == .institution { return edge.targetId }
                if edge.targetType == kind, edge.targetId == id, edge.sourceType == .institution { return edge.sourceId }
                return nil
            })
            return Self.bankIDs(companyID: company(id, companyID), savedName: savedName, aliases: aliases,
                                explicitBankIDs: explicit, banks: banks)
        }
        for card in cards { associations["card:\(card.id.uuidString)"] = resolve(.card, card.id, card.companyId, card.institutionName, card.plaidAccountId) }
        for loan in loans { associations["loan:\(loan.id.uuidString)"] = resolve(.loan, loan.id, loan.companyId, loan.lender, loan.plaidAccountId) }
    }
}
