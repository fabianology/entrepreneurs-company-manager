import Foundation

struct InstitutionAccount: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String = ""
    var type: String = "Checking"
    var last4: String = ""
    var accountNumber: String? = nil
    var balance: Double = 0
    var currency: String = "USD"
    var cardHolder: String = ""
    var expiry: String = ""
    var network: String = ""
    var status: String = "Active"
    var limit: Double = 0
    var paidFrom: String = ""
    var paidOn: String = ""
    var autopay: String = "N/A"

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
        accounts: [InstitutionAccount] = []
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
    }

    var accounts: [InstitutionAccount] {
        get { accountsData }
        set { accountsData = newValue }
    }

    var nonCardAccounts: [InstitutionAccount] {
        accounts.filter { !$0.isCard }
    }
}
