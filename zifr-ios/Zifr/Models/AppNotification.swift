import Foundation

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
