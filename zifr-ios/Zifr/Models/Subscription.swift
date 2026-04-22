import Foundation
import SwiftData

// MARK: - Embedded Structs (Codable, stored as JSON in SwiftData)

struct SubService: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String = ""
    var paymentMethod: String = ""
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

// MARK: - Subscription @Model

@Model
final class Subscription {
    var id: String
    var companyId: String
    var name: String
    var cost: Double
    var currency: String
    var billingCycle: String
    var paymentMethod: String
    var nextRenewal: String
    var renew: String
    var status: String
    var subServicesData: Data   // JSON encoded [SubService]
    var linkedEmailsData: Data  // JSON encoded [LinkedEmail]
    var website: String
    var loginId: String
    var password: String
    var twoFactorAuth: String
    var recoveryMethod: String
    var notes: String
    var pricingModel: String
    var lastUpdated: Date
    var showSubServicesTab: Bool = true
    var showLinkedEmailsTab: Bool = true

    init(
        id: String = UUID().uuidString,
        companyId: String,
        name: String = "",
        cost: Double = 0,
        currency: String = "USD",
        billingCycle: String = "Monthly",
        paymentMethod: String = "",
        nextRenewal: String = "",
        renew: String = "Auto",
        status: String = "Active",
        subServices: [SubService] = [],
        linkedEmails: [LinkedEmail] = [],
        website: String = "",
        loginId: String = "",
        password: String = "",
        twoFactorAuth: String = "None",
        recoveryMethod: String = "",
        notes: String = "",
        pricingModel: String = "paid",
        lastUpdated: Date = Date(),
        showSubServicesTab: Bool = true,
        showLinkedEmailsTab: Bool = true
    ) {
        self.id = id
        self.companyId = companyId
        self.name = name
        self.cost = cost
        self.currency = currency
        self.billingCycle = billingCycle
        self.paymentMethod = paymentMethod
        self.nextRenewal = nextRenewal
        self.renew = renew
        self.status = status
        self.subServicesData = (try? JSONEncoder().encode(subServices)) ?? Data()
        self.linkedEmailsData = (try? JSONEncoder().encode(linkedEmails)) ?? Data()
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
    }

    var subServices: [SubService] {
        get { (try? JSONDecoder().decode([SubService].self, from: subServicesData)) ?? [] }
        set { subServicesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var linkedEmails: [LinkedEmail] {
        get { (try? JSONDecoder().decode([LinkedEmail].self, from: linkedEmailsData)) ?? [] }
        set { linkedEmailsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
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
