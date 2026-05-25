import Foundation

struct ActivityLog: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var userId: UUID
    var actorEmail: String
    var actionType: String
    var message: String
    var resourceId: UUID?
    var resourceType: String?
    var isRead: Bool = false
    var createdAt: Date = Date()
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case actorEmail = "actor_email"
        case actionType = "action_type"
        case message
        case resourceId = "resource_id"
        case resourceType = "resource_type"
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}
