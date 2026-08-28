import Foundation

// MARK: - Embedded Structs (Codable, stored as JSON in Supabase)

struct SubService: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String = ""
    var paymentMethod: String = ""
    var paymentMethodId: UUID? = nil
    var cost: Double = 0
    var billingCycle: BillingCycle = .monthly
    var purpose: String = ""
    var autoPay: AutoPay = .auto
    var status: ServiceStatus = .active

    enum BillingCycle: String, Codable, CaseIterable { case monthly = "Monthly"; case yearly = "Yearly" }
    enum AutoPay: String, Codable, CaseIterable { case auto = "Auto"; case manual = "Manual" }
    enum ServiceStatus: String, Codable, CaseIterable { case active = "Active"; case cancelled = "Cancelled"; case pending = "Pending"; case paused = "Paused" }
}

struct LinkedEmail: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var email: String = ""
    var provider: String = ""       // e.g. Gmail, iCloud, Outlook
    var forwarding: String = ""
    var usedFor: String = ""
    var usedIn: String = ""         // tag infrastructure placeholder
    var accessMethod: String = ""
    var notes: [String] = []
}

// MARK: - Subscription Struct

struct Subscription: Identifiable, Codable, Hashable {
    var id: UUID
    var userId: UUID
    var companyId: UUID
    var name: String
    var cost: Double
    var currency: String
    var billingCycle: String
    var paymentMethod: String?
    var paymentMethodId: UUID?
    var nextRenewal: String?
    var nextRenewalAt: Date?
    var renew: String
    var status: String
    var subServicesData: [SubService]
    var linkedEmailsData: [LinkedEmail]
    var website: String?
    var loginId: String?
    var password: String?
    var twoFactorAuth: String
    var recoveryMethod: String?
    var notes: String?
    var pricingModel: String
    var lastUpdated: Date
    var showSubServicesTab: Bool
    var showLinkedEmailsTab: Bool
    var plaidStreamId: String?
    var plaidAccountId: String?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.userId = try container.decode(UUID.self, forKey: .userId)
        self.companyId = try container.decodeIfPresent(UUID.self, forKey: .companyId) ?? UUID()
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Unknown"
        self.cost = try container.decodeIfPresent(Double.self, forKey: .cost) ?? 0.0
        self.currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "USD"
        self.billingCycle = try container.decodeIfPresent(String.self, forKey: .billingCycle) ?? "Monthly"
        self.paymentMethod = try container.decodeIfPresent(String.self, forKey: .paymentMethod)
        self.paymentMethodId = try container.decodeIfPresent(UUID.self, forKey: .paymentMethodId)
        self.nextRenewal = try container.decodeIfPresent(String.self, forKey: .nextRenewal)
        self.nextRenewalAt = try container.decodeIfPresent(Date.self, forKey: .nextRenewalAt)
        self.renew = try container.decodeIfPresent(String.self, forKey: .renew) ?? "Auto"
        self.status = try container.decodeIfPresent(String.self, forKey: .status) ?? "Active"
        self.subServicesData = try container.decodeIfPresent([SubService].self, forKey: .subServicesData) ?? []
        self.linkedEmailsData = try container.decodeIfPresent([LinkedEmail].self, forKey: .linkedEmailsData) ?? []
        self.website = try container.decodeIfPresent(String.self, forKey: .website)
        self.loginId = try container.decodeIfPresent(String.self, forKey: .loginId)
        self.password = try container.decodeIfPresent(String.self, forKey: .password)
        self.twoFactorAuth = try container.decodeIfPresent(String.self, forKey: .twoFactorAuth) ?? "None"
        self.recoveryMethod = try container.decodeIfPresent(String.self, forKey: .recoveryMethod)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.pricingModel = try container.decodeIfPresent(String.self, forKey: .pricingModel) ?? "Flat"
        
        // Handle Date decoding flexibly (string or native Date)
        if let dateStr = try container.decodeIfPresent(String.self, forKey: .lastUpdated) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateStr) {
                self.lastUpdated = date
            } else {
                let fallback = ISO8601DateFormatter()
                self.lastUpdated = fallback.date(from: dateStr) ?? Date()
            }
        } else {
            self.lastUpdated = Date()
        }
        
        self.showSubServicesTab = try container.decodeIfPresent(Bool.self, forKey: .showSubServicesTab) ?? false
        self.showLinkedEmailsTab = try container.decodeIfPresent(Bool.self, forKey: .showLinkedEmailsTab) ?? false
        self.plaidStreamId = try container.decodeIfPresent(String.self, forKey: .plaidStreamId)
        self.plaidAccountId = try container.decodeIfPresent(String.self, forKey: .plaidAccountId)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case companyId = "company_id"
        case name
        case cost
        case currency
        case billingCycle = "billing_cycle"
        case paymentMethod = "payment_method"
        case paymentMethodId = "payment_method_id"
        case nextRenewal = "next_renewal"
        case nextRenewalAt = "next_renewal_at"
        case renew
        case status
        case subServicesData = "sub_services_data"
        case linkedEmailsData = "linked_emails_data"
        case website
        case loginId = "login_id"
        case password
        case twoFactorAuth = "two_factor_auth"
        case recoveryMethod = "recovery_method"
        case notes
        case pricingModel = "pricing_model"
        case lastUpdated = "last_updated"
        case showSubServicesTab = "show_sub_services_tab"
        case showLinkedEmailsTab = "show_linked_emails_tab"
        case plaidStreamId = "plaid_stream_id"
        case plaidAccountId = "plaid_account_id"
    }

    init(
        id: UUID = UUID(),
        userId: UUID,
        companyId: UUID,
        name: String = "",
        cost: Double = 0,
        currency: String = "USD",
        billingCycle: String = "Monthly",
        paymentMethod: String? = nil,
        paymentMethodId: UUID? = nil,
        nextRenewal: String? = nil,
        nextRenewalAt: Date? = nil,
        renew: String = "Auto",
        status: String = "Active",
        subServices: [SubService] = [],
        linkedEmails: [LinkedEmail] = [],
        website: String? = nil,
        loginId: String? = nil,
        password: String? = nil,
        twoFactorAuth: String = "None",
        recoveryMethod: String? = nil,
        notes: String? = nil,
        pricingModel: String = "paid",
        lastUpdated: Date = Date(),
        showSubServicesTab: Bool = true,
        showLinkedEmailsTab: Bool = true,
        plaidStreamId: String? = nil,
        plaidAccountId: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.companyId = companyId
        self.name = name
        self.cost = cost
        self.currency = currency
        self.billingCycle = billingCycle
        self.paymentMethod = paymentMethod
        self.paymentMethodId = paymentMethodId
        self.nextRenewal = nextRenewal
        self.nextRenewalAt = nextRenewalAt
        self.renew = renew
        self.status = status
        self.subServicesData = subServices
        self.linkedEmailsData = linkedEmails
        self.website = website
        self.loginId = loginId
        self.password = password
        self.twoFactorAuth = twoFactorAuth
        self.recoveryMethod = recoveryMethod
        self.notes = notes
        self.pricingModel = pricingModel
        self.lastUpdated = lastUpdated
        self.showSubServicesTab = showSubServicesTab
        self.showLinkedEmailsTab = showLinkedEmailsTab
        self.plaidStreamId = plaidStreamId
        self.plaidAccountId = plaidAccountId
    }

    var subServices: [SubService] {
        get { subServicesData }
        set { subServicesData = newValue }
    }

    var linkedEmails: [LinkedEmail] {
        get { linkedEmailsData }
        set { linkedEmailsData = newValue }
    }

    var isFree: Bool { pricingModel == "free" }
    var isAutoRenew: Bool { renew == "Auto" }

    var monthlyTotal: Double {
        let base = billingCycle == "Monthly" ? cost : 0
        let sub = subServices.filter { $0.status != .paused }.reduce(0.0) {
            $0 + ($1.billingCycle == .monthly ? $1.cost : 0)
        }
        return base + sub
    }

    var yearlyTotal: Double {
        let base = billingCycle == "Yearly" ? cost : 0
        let sub = subServices.filter { $0.status != .paused }.reduce(0.0) {
            $0 + ($1.billingCycle == .yearly ? $1.cost : 0)
        }
        return base + sub
    }

    var estimatedAnnualCost: Double {
        (monthlyTotal * 12) + yearlyTotal
    }
}
