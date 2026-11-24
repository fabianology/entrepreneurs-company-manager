import Foundation

enum NotificationRoute: Hashable {
    case ownerBriefing
    case institution(UUID)
    case transaction(UUID)
    case transactionReview
    case subscriptionInServices(UUID)
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

// The inbox payload retains the scheduled day in the alert body. A resource's next
// payment can roll forward while this particular alert is still in the inbox.
struct InboxScheduledPayment {
    let name: String
    let kind: String
    let date: Date

    init?(_ notification: AppNotification, timeZone: TimeZone, dueOn: String? = nil) {
        guard notification.notificationType == "portfolio_alert" else { return nil }

        let separator: String
        switch notification.resourceType {
        case "subscription":
            kind = "Subscription payment"
            separator = " is scheduled for "
        case "loan":
            kind = "Loan payment"
            separator = " has a payment scheduled for "
        default:
            return nil
        }

        let body = notification.body.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = body.last == "." ? body.range(of: separator, options: .backwards) : nil
        let subject = parts.map { body[..<$0.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines) }
        let legacyDay = parts.map { String(body[$0.upperBound...].dropLast()) }
        guard let day = dueOn ?? legacyDay, let date = Self.parseDay(day, timeZone: timeZone) else { return nil }
        name = subject.flatMap { $0.isEmpty ? nil : $0 } ?? notification.title
        self.date = date
    }

    static func parseDay(_ day: String, timeZone: TimeZone) -> Date? {
        guard day.wholeMatch(of: #/[0-9]{4}-[0-9]{2}-[0-9]{2}/#) != nil else { return nil }
        let strategy = Date.ParseStrategy(
            format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)",
            locale: Locale(identifier: "en_US_POSIX"), timeZone: timeZone, isLenient: false
        )
        return try? Date(day, strategy: strategy)
    }

    static func deadline(_ notice: AppNotification, metadata: InboxAlertMetadata?, timeZone: TimeZone) -> Date? {
        if let day = metadata?.dueOn, let date = parseDay(day, timeZone: timeZone) { return date }
        if let payment = Self(notice, timeZone: timeZone) { return payment.date }
        guard metadata?.ruleType == nil, notice.notificationType == "portfolio_alert",
              ["card", "document"].contains(notice.resourceType ?? ""),
              let day = notice.body.split(separator: " expires by ").last, day.last == "."
        else { return nil }
        return parseDay(String(day.dropLast()), timeZone: timeZone)
    }

    func matchesServerDay(_ scheduled: Date, timeZone: TimeZone) -> Bool {
        let fields: Set<Calendar.Component> = [.year, .month, .day]
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone
        let shownDay = gregorian.dateComponents(fields, from: date)
        // The server derives the alert date from the UTC timestamp.
        gregorian.timeZone = TimeZone(secondsFromGMT: 0)!
        return shownDay == gregorian.dateComponents(fields, from: scheduled)
    }

    func daysUntil(from now: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
    }
}

enum InboxDates {
    static func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
            let whole = Date.ISO8601FormatStyle()
            // Legacy UTC responses can omit the time-zone suffix.
            for timestamp in [value, value + "Z"] {
                if let date = try? fractional.parse(timestamp) { return date }
                if let date = try? whole.parse(timestamp) { return date }
            }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid Inbox timestamp"))
        }
        return try decoder.decode(type, from: data)
    }
}

struct InboxAlertMetadata: Decodable {
    let id: UUID
    let ruleType: String?
    let severity: String?
    let dueOn: String?

    enum CodingKeys: String, CodingKey {
        case id, severity
        case ruleType = "rule_type"
        case dueOn = "due_on"
    }
}

struct InboxContext: Decodable {
    let timeZone: String
    let alerts: [InboxAlertMetadata]
    let inviteHistory: [InboxInvitationOutcome]

    enum CodingKeys: String, CodingKey {
        case timeZone = "time_zone"
        case alerts
        case inviteHistory = "invite_history"
    }
}

struct InboxInvitationOutcome: Decodable, Identifiable {
    enum Outcome: String, Decodable {
        case accepted, declined, expired

        var topic: InboxTopic {
            switch self {
            case .accepted: .accepted
            case .declined: .declined
            case .expired: .expired
            }
        }
    }

    let id: UUID
    let resourceType: String
    let resourceTitle: String?
    let role: String
    let inviterEmail: String?
    let outcome: Outcome
    let occurredAt: Date

    enum CodingKeys: String, CodingKey {
        case id, role, outcome
        case resourceType = "resource_type"
        case resourceTitle = "resource_title"
        case inviterEmail = "inviter_email"
        case occurredAt = "occurred_at"
    }

    init(invitation: IncomingResourceInvitation, outcome: Outcome, at date: Date) {
        id = invitation.id
        resourceType = invitation.resourceType
        resourceTitle = invitation.resourceTitle
        role = invitation.role
        inviterEmail = invitation.inviterEmail
        self.outcome = outcome
        occurredAt = date
    }

    var subject: String {
        resourceTitle ?? "\(resourceType.replacingOccurrences(of: "_", with: " ").capitalized) invitation"
    }
}

enum InboxTopic: String, CaseIterable, Hashable {
    case payments = "Payments"
    case briefings = "Weekly briefings"
    case balances = "Balance and transactions"
    case connections = "Bank connections"
    case security = "Security and expirations"
    case other = "Other alerts"
    case accepted = "Accepted"
    case declined = "Declined"
    case expired = "Expired"
    case access = "Access changes"
    case account = "Account and security"
    case records = "Changes to records"

    static func alert(_ row: AppNotification, metadata: InboxAlertMetadata?) -> Self {
        switch metadata?.ruleType {
        case "upcoming_payment": return .payments
        case "disconnected_institution": return .connections
        case "balance_change", "large_transaction", "possible_duplicate", "unusual_spending": return .balances
        case "expiring_item": return .security
        default: break
        }
        // Older deliveries may be missing event metadata.
        let type = row.notificationType
        let title = row.title.lowercased()
        if type == "owner_briefing" { return .briefings }
        if type == "security_alert" || title.contains("expiration") { return .security }
        if type == "disconnected_institution" || title == "bank reconnect required" || title == "bank connection disconnected" || title == "bank connection needs attention" {
            return .connections
        }
        if type == "transaction_review" || row.resourceType == "transaction" || title.contains("balance change") {
            return .balances
        }
        if type == "portfolio_alert", ["subscription", "loan"].contains(row.resourceType ?? "") { return .payments }
        return .other
    }

    static func activity(_ row: ActivityLog) -> Self {
        switch row.actionType.lowercased() {
        case "new_device", "security_alert", "login", "password_changed": .account
        case "shared", "left_resource", "unshared", "updated_role", "revoked_access": .access
        case let action where action.contains("invite") || action.contains("access") || action.contains("share"): .access
        case let action where action.contains("security") || action.contains("login"): .account
        default: .records
        }
    }
}

struct InboxHistoryGroup<Row: Identifiable>: Identifiable {
    let topic: InboxTopic
    let rows: [Row]
    var id: InboxTopic { topic }

    static func groups(_ rows: [Row], by topic: (Row) -> InboxTopic) -> [Self] {
        let grouped = Dictionary(grouping: rows, by: topic)
        return InboxTopic.allCases.compactMap { key in
            grouped[key].map { Self(topic: key, rows: $0) }
        }
    }
}

struct InboxAgePolicy {
    enum Placement { case current, older, expired }

    let now: Date
    let calendar: Calendar

    func daysSince(_ date: Date) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
    }

    func placement(for date: Date?, scheduled: Bool = false) -> Placement {
        guard let date else { return .current }
        let age = daysSince(date)
        if age > 14 { return .expired }
        if age > (scheduled ? 0 : 5) { return .older }
        return .current
    }
}

struct InboxTimeline {
    let reconnect: [Institution]
    let attention: [AppNotification]
    let upcoming: [AppNotification]
    let recentAlerts: [AppNotification]
    let olderAlerts: [InboxHistoryGroup<AppNotification>]
    let pendingInvites: [IncomingResourceInvitation]
    let recentInvites: [InboxInvitationOutcome]
    let olderInvites: [InboxHistoryGroup<InboxInvitationOutcome>]
    let recentActivity: [ActivityLog]
    let olderActivity: [InboxHistoryGroup<ActivityLog>]

    var alertUnreadCount: Int { (attention + upcoming + recentAlerts).filter { !$0.isRead }.count }

    init(notifications: [AppNotification], invitations: [IncomingResourceInvitation],
         history: [InboxInvitationOutcome], activity: [ActivityLog], banks: [Institution],
         metadata: [UUID: InboxAlertMetadata], age: InboxAgePolicy) {
        reconnect = banks.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let reconnectIDs = Set(banks.map(\.id))
        var dated: [(notification: AppNotification, due: Date)] = []
        var alertAttention: [AppNotification] = []
        var alertRecent: [AppNotification] = []
        var alertOlder: [(notification: AppNotification, date: Date)] = []
        let newestAlerts = notifications.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        for notice in newestAlerts {
            let info = metadata[notice.id]
            let topic = InboxTopic.alert(notice, metadata: info)
            let due = InboxScheduledPayment.deadline(notice, metadata: info, timeZone: age.calendar.timeZone)
            switch age.placement(for: due ?? notice.createdAt, scheduled: due != nil) {
            case .expired: continue
            case .older: alertOlder.append((notice, due ?? notice.createdAt ?? .distantPast))
            case .current:
                if topic == .connections, let id = notice.resourceId, reconnectIDs.contains(id) { continue }
                if let due {
                    dated.append((notice, due))
                } else if topic != .connections && (info?.severity == "urgent" || notice.notificationType == "security_alert") {
                    alertAttention.append(notice)
                } else {
                    alertRecent.append(notice)
                }
            }
        }
        dated.sort { $0.due < $1.due }
        upcoming = dated.map { $0.notification }
        attention = alertAttention
        recentAlerts = alertRecent
        let archivedAlerts = alertOlder.sorted { $0.date > $1.date }.map { $0.notification }
        olderAlerts = InboxHistoryGroup.groups(archivedAlerts) { InboxTopic.alert($0, metadata: metadata[$0.id]) }

        pendingInvites = invitations.filter { $0.expiresAt > age.now }.sorted { $0.expiresAt < $1.expiresAt }
        let pendingIDs = Set(pendingInvites.map(\.id))
        let outcomes = history.filter { !pendingIDs.contains($0.id) }.sorted { $0.occurredAt > $1.occurredAt }
        recentInvites = outcomes.filter { age.placement(for: $0.occurredAt) == .current }
        olderInvites = InboxHistoryGroup.groups(outcomes.filter { age.placement(for: $0.occurredAt) == .older }) {
            $0.outcome.topic
        }

        let feed = activity.filter { $0.inboxDismissedAt == nil }.sorted { $0.createdAt > $1.createdAt }
        recentActivity = feed.filter { age.placement(for: $0.createdAt) == .current }
        olderActivity = InboxHistoryGroup.groups(feed.filter { age.placement(for: $0.createdAt) == .older }, by: InboxTopic.activity)
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
