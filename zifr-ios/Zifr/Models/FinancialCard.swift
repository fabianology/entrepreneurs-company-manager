import Foundation
import SwiftData

@Model
final class FinancialCard {
    var id: String = UUID().uuidString
    var companyId: String = ""
    var name: String = ""
    var login: String = ""
    var password: String = ""
    var institutionName: String = ""
    var cardHolder: String = ""
    var cardNumber: String = ""
    var last4: String = ""
    var expiry: String = ""
    var network: String = "Visa"
    var type: String = "Credit"
    var status: String = "Active"
    var limit: Double = 0
    var paidFrom: String = ""
    var paidOn: String = ""
    var autopay: String = "Yes"
    var balance: Double = 0.0
    var moPayment: Double = 0.0
    var apr: Double = 0.0
    var promoApr: Double = 0.0
    var promoEnds: Date = Date()
    var cardHolderType: String = "Mine"
    var notes: String = ""
    var company: Company?

    init(
        id: String = UUID().uuidString,
        companyId: String = "",
        name: String = "",
        login: String = "",
        password: String = "",
        institutionName: String = "",
        cardHolder: String = "",
        cardNumber: String = "",
        last4: String = "",
        expiry: String = "",
        network: String = "Visa",
        type: String = "Credit",
        status: String = "Active",
        limit: Double = 0,
        paidFrom: String = "",
        paidOn: String = "",
        autopay: String = "Yes",
        balance: Double = 0,
        moPayment: Double = 0,
        apr: Double = 0,
        promoApr: Double = 0,
        promoEnds: Date = Date(),
        cardHolderType: String = "Mine",
        notes: String = ""
    ) {
        self.id = id
        self.companyId = companyId
        self.name = name
        self.login = login
        self.password = password
        self.institutionName = institutionName
        self.cardHolder = cardHolder
        self.cardNumber = cardNumber
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
        self.apr = apr
        self.promoApr = promoApr
        self.promoEnds = promoEnds
        self.cardHolderType = cardHolderType
        self.notes = notes
    }

    static let networks = ["Visa", "Mastercard", "Amex", "Discover", "Other"]
    static let types = ["Credit", "Debit"]
    static let statuses = ["Active", "Frozen", "Expired"]
    static let autopayOptions = ["Yes", "No", "N/A"]
}
