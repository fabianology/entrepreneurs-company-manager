import Foundation

enum NotificationRoute: Hashable {
    case ownerBriefing
    case institution(UUID)
    case transaction(UUID)
    case transactionReview
    case resource(ResourceKind, UUID)

    init?(pushUserInfo: [AnyHashable: Any]) {
        guard let rawRoute = pushUserInfo["route"] as? String else { return nil }
        let resourceID = (pushUserInfo["resource_id"] as? String).flatMap(UUID.init(uuidString:))

        switch rawRoute.lowercased() {
        case "owner_briefing":
            self = .ownerBriefing
        case "transaction_review", "transaction_review_queue":
            self = .transactionReview
        case "institution":
            guard let resourceID else { return nil }
            self = .institution(resourceID)
        case "transaction":
            guard let resourceID else { return nil }
            self = .transaction(resourceID)
        default:
            guard let resourceID,
                  let kind = ResourceKind(rawValue: rawRoute.lowercased()) else { return nil }
            self = .resource(kind, resourceID)
        }
    }
}

struct AppNotification: Identifiable, Codable {
    var id: UUID
    var userId: UUID
    var notificationType: String
    var title: String
    var body: String
    var resourceId: UUID?
    var resourceType: String?
    var isRead: Bool
    var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case notificationType = "notification_type"
        case title
        case body
        case resourceId = "resource_id"
        case resourceType = "resource_type"
        case isRead = "is_read"
        case createdAt = "created_at"
    }

    var route: NotificationRoute? {
        if notificationType == "owner_briefing" { return .ownerBriefing }
        if notificationType == "transaction_review" || resourceType == "transaction_review" {
            return .transactionReview
        }
        guard let resourceId, let resourceType else { return nil }
        switch resourceType.lowercased() {
        case "institution": return .institution(resourceId)
        case "transaction": return .transaction(resourceId)
        default:
            guard let kind = ResourceKind(rawValue: resourceType.lowercased()) else { return nil }
            return .resource(kind, resourceId)
        }
    }
}

struct UserPreferences: Codable {
    var userId: UUID
    var remindersEnabled: Bool
    var securityEnabled: Bool
    var messagesEnabled: Bool
    var updatedAt: Date?
    var briefingWeekday: Int?
    var briefingTime: String?
    var timezone: String?
    var weeklyBriefingEnabled: Bool?
    var criticalAlertsEnabled: Bool?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case remindersEnabled = "reminders_enabled"
        case securityEnabled = "security_enabled"
        case messagesEnabled = "messages_enabled"
        case updatedAt = "updated_at"
        case briefingWeekday = "briefing_weekday"
        case briefingTime = "briefing_time"
        case timezone
        case weeklyBriefingEnabled = "weekly_briefing_enabled"
        case criticalAlertsEnabled = "critical_alerts_enabled"
    }
}

enum AlertRuleType: String, Codable, CaseIterable, Identifiable {
    case largeTransaction = "large_transaction"
    case possibleDuplicate = "possible_duplicate"
    case unusualSpending = "unusual_spending"
    case balanceChange = "balance_change"
    case upcomingPayment = "upcoming_payment"
    case expiringItem = "expiring_item"
    case disconnectedInstitution = "disconnected_institution"

    var id: String { rawValue }
}

struct AlertRule: Codable, Identifiable, Equatable {
    var userId: UUID
    var ruleType: AlertRuleType
    var enabled: Bool
    var thresholdAmount: Double?
    var thresholdPercent: Double?
    var lookbackDays: Int?
    var leadDays: Int?
    var createdAt: Date?
    var updatedAt: Date?

    var id: AlertRuleType { ruleType }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case ruleType = "rule_type"
        case enabled
        case thresholdAmount = "threshold_amount"
        case thresholdPercent = "threshold_percent"
        case lookbackDays = "lookback_days"
        case leadDays = "lead_days"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    static func conservativeDefaults(userId: UUID) -> [AlertRule] {
        [
            AlertRule(userId: userId, ruleType: .largeTransaction, enabled: true, thresholdAmount: 1_000, lookbackDays: 3),
            AlertRule(userId: userId, ruleType: .possibleDuplicate, enabled: true, lookbackDays: 3),
            AlertRule(userId: userId, ruleType: .unusualSpending, enabled: false, thresholdAmount: 250, lookbackDays: 90),
            AlertRule(userId: userId, ruleType: .balanceChange, enabled: false, thresholdAmount: 500, thresholdPercent: 25),
            AlertRule(userId: userId, ruleType: .upcomingPayment, enabled: true, leadDays: 7),
            AlertRule(userId: userId, ruleType: .expiringItem, enabled: true, leadDays: 30),
            AlertRule(userId: userId, ruleType: .disconnectedInstitution, enabled: true)
        ]
    }
}

enum AutomationSchedule {
    static func nextBriefingDate(
        weekday: Int,
        time: String,
        timezone: String,
        after referenceDate: Date = Date()
    ) -> Date? {
        guard (1...7).contains(weekday) else { return nil }
        let timeParts = time.split(separator: ":").compactMap { Int($0) }
        guard timeParts.count >= 2 else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timezone) ?? .current
        // Miloom stores Monday as 1; Calendar stores Sunday as 1.
        let calendarWeekday = weekday == 7 ? 1 : weekday + 1
        return calendar.nextDate(
            after: referenceDate,
            matching: DateComponents(
                hour: timeParts[0],
                minute: timeParts[1],
                second: 0,
                weekday: calendarWeekday
            ),
            matchingPolicy: .nextTime,
            direction: .forward
        )
    }
}
