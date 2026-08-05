import Foundation

struct FinancialCard: Identifiable, Codable, Hashable {
    var id: UUID
    var userId: UUID
    var companyId: UUID
    var name: String
    var login: String?
    var password: String?
    var institutionName: String?
    var cardHolder: String?
    var cardNumber: String?
    var last4: String?
    var expiry: String?
    var network: String
    var type: String
    var status: String
    var limit: Double
    var paidFrom: String?
    var paidOn: String?
    var autopay: String
    var balance: Double
    var moPayment: Double
    var apr: Double
    var promoApr: Double
    var promoEnds: Date?
    var cardHolderType: String
    var notes: String?
    var plaidAccountId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case companyId = "company_id"
        case name
        case login
        case password
        case institutionName = "institution_name"
        case cardHolder = "card_holder"
        case cardNumber = "card_number"
        case last4
        case expiry
        case network
        case type
        case status
        case limit
        case paidFrom = "paid_from"
        case paidOn = "paid_on"
        case autopay
        case balance
        case moPayment = "mo_payment"
        case apr
        case promoApr = "promo_apr"
        case promoEnds = "promo_ends"
        case cardHolderType = "card_holder_type"
        case notes
        case plaidAccountId = "plaid_account_id"
    }
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        companyId: UUID,
        name: String = "",
        login: String? = nil,
        password: String? = nil,
        institutionName: String? = nil,
        cardHolder: String? = nil,
        cardNumber: String? = nil,
        last4: String? = nil,
        expiry: String? = nil,
        network: String = "Visa",
        type: String = "Credit",
        status: String = "Active",
        limit: Double = 0,
        paidFrom: String? = nil,
        paidOn: String? = nil,
        autopay: String = "Yes",
        balance: Double = 0,
        moPayment: Double = 0,
        apr: Double = 0,
        promoApr: Double = 0,
        promoEnds: Date? = nil,
        cardHolderType: String = "Mine",
        notes: String? = nil,
        plaidAccountId: String? = nil
    ) {
        self.id = id
        self.userId = userId
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
        self.plaidAccountId = plaidAccountId
    }

    static let networks = ["Visa", "Mastercard", "Amex", "Discover", "Other"]
    static let types = ["Credit", "Debit"]
    static let statuses = ["Active", "Frozen", "Expired"]
    static let autopayOptions = ["Yes", "No", "N/A"]
}
