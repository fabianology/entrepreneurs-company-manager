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
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case remindersEnabled = "reminders_enabled"
        case securityEnabled = "security_enabled"
        case messagesEnabled = "messages_enabled"
        case updatedAt = "updated_at"
    }
}
