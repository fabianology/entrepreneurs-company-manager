import Foundation
import SwiftData

struct InstitutionAccount: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String = ""
    var type: String = "Checking"
    var last4: String = "0000"
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
        "Credit Card", "Debit Card", "Debit (Linked)", "FSA", "HSA",
        "401(k)", "Roth 401(k)", "IRA", "Roth IRA",
        "Rollover IRA", "SEP IRA", "529", "Other"
    ]

    var isCard: Bool {
        ["Credit Card", "Debit Card", "Debit (Linked)", "FSA", "HSA"].contains(type)
    }
}

@Model
final class Institution {
    var id: String
    var companyId: String
    var name: String
    var loginUrl: String
    var username: String
    var email: String
    var password: String
    var accountsData: Data  // JSON encoded [InstitutionAccount]

    init(
        id: String = UUID().uuidString,
        companyId: String,
        name: String = "New Bank",
        loginUrl: String = "",
        username: String = "",
        email: String = "",
        password: String = "",
        accounts: [InstitutionAccount] = []
    ) {
        self.id = id
        self.companyId = companyId
        self.name = name
        self.loginUrl = loginUrl
        self.username = username
        self.email = email
        self.password = password
        self.accountsData = (try? JSONEncoder().encode(accounts)) ?? Data()
    }

    var accounts: [InstitutionAccount] {
        get { (try? JSONDecoder().decode([InstitutionAccount].self, from: accountsData)) ?? [] }
        set { accountsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var nonCardAccounts: [InstitutionAccount] {
        accounts.filter { !$0.isCard }
    }
}
