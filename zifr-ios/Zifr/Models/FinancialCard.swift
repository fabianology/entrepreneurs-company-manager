import Foundation
import SwiftData

@Model
final class FinancialCard {
    var id: String
    var companyId: String
    var name: String
    var login: String
    var password: String
    var institutionName: String
    var cardHolder: String
    var last4: String
    var expiry: String
    var network: String
    var type: String
    var status: String
    var limit: Double
    var paidFrom: String
    var paidOn: String
    var autopay: String
    var balance: Double
    var moPayment: Double
    var cardHolderType: String

    init(
        id: String = UUID().uuidString,
        companyId: String,
        name: String = "",
        login: String = "",
        password: String = "",
        institutionName: String = "",
        cardHolder: String = "",
        last4: String = "0000",
        expiry: String = "12/99",
        network: String = "Visa",
        type: String = "Credit",
        status: String = "Active",
        limit: Double = 0,
        paidFrom: String = "",
        paidOn: String = "",
        autopay: String = "N/A",
        balance: Double = 0,
        moPayment: Double = 0,
        cardHolderType: String = "Mine"
    ) {
        self.id = id
        self.companyId = companyId
        self.name = name
        self.login = login
        self.password = password
        self.institutionName = institutionName
        self.cardHolder = cardHolder
        self.last4 = last4
        self.expiry = expiry
        self.network = network
        self.type = type
        self.status = status
        self.limit = limit
        self.paidFrom = paidFrom
        self.paidOn = paidOn
        self.autopay = autopay
        self.balance = balance
        self.moPayment = moPayment
        self.cardHolderType = cardHolderType
    }

    static let networks = ["Visa", "Mastercard", "Amex", "Discover", "Other"]
    static let types = ["Credit", "Debit"]
    static let statuses = ["Active", "Frozen", "Expired"]
    static let autopayOptions = ["Yes", "No", "N/A"]
}
