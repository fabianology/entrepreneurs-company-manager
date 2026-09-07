import Foundation

// MARK: - Embedded Structs (Codable, stored as JSON in Supabase)

struct SubService: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String = ""
    var paymentMethod: String = ""
    var paymentMethodId: UUID? = nil
    var cost: Double = 0
    var billingCycle: BillingCycle = .monthly
    var renewsOn: Date? = nil
    var purpose: String = ""
    var autoPay: AutoPay = .auto
    var status: ServiceStatus = .active

    enum BillingCycle: String, Codable, CaseIterable { case monthly = "Monthly"; case yearly = "Yearly" }
    enum AutoPay: String, Codable, CaseIterable { case auto = "Auto"; case manual = "Manual" }
    enum ServiceStatus: String, Codable, CaseIterable { case active = "Active"; case cancelled = "Cancelled"; case pending = "Pending"; case paused = "Paused" }
}

enum RecurringServiceType: String, Codable, CaseIterable, Identifiable {
    case automatic
    case bill
    case subscription

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// Classifies recurring services without sending financial data to an AI model.
/// A saved manual choice always wins; this classifier is only used for Automatic.
enum RecurringServiceClassifier {
    static func classify(
        name: String,
        website: String? = nil,
        categories: [String]? = nil
    ) -> RecurringServiceType {
        let merchantText = normalized([name, website ?? ""].joined(separator: " "))
        let categoryText = normalized((categories ?? []).joined(separator: " "))

        if containsAny(categoryText, terms: billCategoryTerms)
            || containsAny(merchantText, terms: billMerchantTerms) {
            return .bill
        }

        if containsAny(categoryText, terms: subscriptionCategoryTerms)
            || containsAny(merchantText, terms: subscriptionMerchantTerms) {
            return .subscription
        }

        // The Services area historically represented subscriptions. Keeping that
        // as the fallback avoids unexpectedly moving uncategorized existing data.
        return .subscription
    }

    private static let billCategoryTerms = [
        "utility", "utilities", "telecommunication", "telecommunications",
        "cable", "internet", "rent", "mortgage", "insurance"
    ]

    private static let billMerchantTerms = [
        "at&t", "att", "verizon", "t-mobile", "tmobile", "xfinity", "comcast",
        "spectrum", "cox", "frontier", "electric", "electricity", "energy",
        "water", "utility", "utilities", "insurance", "mortgage", "rent",
        "wireless", "internet", "phone", "google cloud", "amazon web services", "aws"
    ]

    private static let subscriptionCategoryTerms = [
        "subscription", "subscriptions", "software", "digital", "streaming",
        "entertainment", "membership", "memberships"
    ]

    private static let subscriptionMerchantTerms = [
        "google", "google one", "youtube", "netflix", "spotify", "adobe",
        "microsoft 365", "office 365", "icloud", "dropbox", "notion", "slack",
        "shopify", "canva", "hulu", "disney", "max", "peloton", "gym", "membership"
    ]

    private static func normalized(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9&]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsAny(_ value: String, terms: [String]) -> Bool {
        let words = Set(value.split(separator: " ").map(String.init))
        return terms.contains { term in
            let normalizedTerm = normalized(term)
            return normalizedTerm.contains(" ") || normalizedTerm.contains("&")
                ? value.contains(normalizedTerm)
                : words.contains(normalizedTerm)
        }
    }
}

enum SubscriptionRenewalScheduler {
    enum Cycle: Equatable {
        case monthly
        case yearly
    }

    static func nextDueDate(
        from renewalDate: Date,
        cycle: Cycle,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        let today = calendar.startOfDay(for: now)
        let components = calendar.dateComponents([.year, .month, .day], from: renewalDate)
        let month = components.month ?? calendar.component(.month, from: now)
        let anchorDay = components.day ?? calendar.component(.day, from: now)
        var year = components.year ?? calendar.component(.year, from: now)

        switch cycle {
        case .monthly:
            var candidateMonth = month
            var candidate = date(year: year, month: candidateMonth, day: anchorDay, calendar: calendar)
            while candidate < today {
                candidateMonth += 1
                if candidateMonth > 12 {
                    candidateMonth = 1
                    year += 1
                }
                candidate = date(year: year, month: candidateMonth, day: anchorDay, calendar: calendar)
            }
            return candidate
        case .yearly:
            var candidate = date(year: year, month: month, day: anchorDay, calendar: calendar)
            while candidate < today {
                year += 1
                candidate = date(year: year, month: month, day: anchorDay, calendar: calendar)
            }
            return candidate
        }
    }

    static func nextDueDate(
        monthlyDay: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        let components = calendar.dateComponents([.year, .month], from: now)
        let source = date(
            year: components.year ?? calendar.component(.year, from: now),
            month: components.month ?? calendar.component(.month, from: now),
            day: monthlyDay,
            calendar: calendar
        )
        return nextDueDate(from: source, cycle: .monthly, now: now, calendar: calendar)
    }

    static func normalized(_ subscription: Subscription, now: Date = Date(), calendar: Calendar = .current) -> Subscription {
        guard subscription.status == "Active" else { return subscription }

        var updated = subscription
        var didChange = false
        let cycle: Cycle = subscription.billingCycle == "Yearly" ? .yearly : .monthly

        if let sourceDate = subscription.nextRenewalAt ?? legacyDate(
            subscription.nextRenewal,
            cycle: cycle,
            now: now,
            calendar: calendar
        ) {
            let nextDue = nextDueDate(from: sourceDate, cycle: cycle, now: now, calendar: calendar)
            if updated.nextRenewalAt != nextDue {
                updated.nextRenewalAt = nextDue
                didChange = true
            }

            let displayValue: String
            switch cycle {
            case .monthly:
                displayValue = "\(calendar.component(.day, from: nextDue))"
            case .yearly:
                displayValue = yearlyDisplayDate(nextDue, calendar: calendar)
            }
            if updated.nextRenewal != displayValue {
                updated.nextRenewal = displayValue
                didChange = true
            }
        }

        let normalizedServices = subscription.subServices.map { service -> SubService in
            guard service.status == .active, let renewsOn = service.renewsOn else { return service }
            var updatedService = service
            updatedService.renewsOn = nextDueDate(
                from: renewsOn,
                cycle: service.billingCycle == .yearly ? .yearly : .monthly,
                now: now,
                calendar: calendar
            )
            return updatedService
        }
        if normalizedServices != subscription.subServices {
            updated.subServices = normalizedServices
            didChange = true
        }

        if didChange { updated.lastUpdated = now }
        return updated
    }

    static func yearlyDisplayDate(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private static func legacyDate(
        _ value: String?,
        cycle: Cycle,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        if cycle == .monthly, let day = Int(trimmed), (1...31).contains(day) {
            return nextDueDate(monthlyDay: day, now: now, calendar: calendar)
        }

        for formatter in legacyDateFormatters {
            if let parsed = formatter.date(from: trimmed) {
                let parsedComponents = calendar.dateComponents([.month, .day], from: parsed)
                guard let month = parsedComponents.month, let day = parsedComponents.day else { continue }
                let year = calendar.component(.year, from: now)
                return date(year: year, month: month, day: day, calendar: calendar)
            }
        }
        return nil
    }

    private static func date(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        var firstOfMonth = DateComponents()
        firstOfMonth.year = year
        firstOfMonth.month = month
        firstOfMonth.day = 1
        let monthDate = calendar.date(from: firstOfMonth) ?? Date()
        let lastDay = calendar.range(of: .day, in: .month, for: monthDate)?.count ?? day

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = min(day, lastDay)
        return calendar.startOfDay(for: calendar.date(from: components) ?? Date())
    }

    private static let legacyDateFormatters: [DateFormatter] = [
        "yyyy-MM-dd", "MM/dd/yyyy", "MMM d, yyyy", "MMM dd, yyyy", "MM-dd-yyyy", "MMM d", "MMM dd"
    ].map { format in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }
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
    var serviceType: RecurringServiceType
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
        self.serviceType = try container.decodeIfPresent(RecurringServiceType.self, forKey: .serviceType) ?? .automatic
        
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
        case serviceType = "service_type"
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
        serviceType: RecurringServiceType = .automatic,
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
        self.serviceType = serviceType
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

    var resolvedServiceType: RecurringServiceType {
        serviceType == .automatic
            ? RecurringServiceClassifier.classify(name: name, website: website)
            : serviceType
    }

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
