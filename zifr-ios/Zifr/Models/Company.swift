import Foundation
import SwiftUI

struct Company: Identifiable, Codable, Hashable {
    var id: UUID
    var userId: UUID
    var name: String
    var structure: String
    var companyDescription: String?
    var colorHex: String
    var logoData: Data?
    var website: String?
    var lastModified: Date
    var lastViewed: Date

    var brandColor: Color {
        let hex = colorHex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if hex.isEmpty {
            let uuidString = id.uuidString
            let charSum = uuidString.utf8.reduce(0) { $0 + Int($1) }
            let fallbackColors = ["#4f46e5", "#10b981", "#f59e0b", "#ef4444", "#14b8a6", "#8b5cf6", "#3b82f6", "#ec4899"]
            let chosen = fallbackColors[charSum % fallbackColors.count]
            return Color(hex: chosen)
        }
        return Color(hex: hex)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case structure
        case companyDescription = "company_description"
        case colorHex = "color_hex"
        case logoData = "logo_data"
        case website
        case lastModified = "last_modified"
        case lastViewed = "last_viewed"
    }
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        name: String = "",
        structure: String = "LLC",
        companyDescription: String? = nil,
        colorHex: String = "#4f46e5",
        logoData: Data? = nil,
        website: String? = nil,
        lastModified: Date = Date(),
        lastViewed: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.structure = structure
        self.companyDescription = companyDescription
        self.colorHex = colorHex
        self.logoData = logoData
        self.website = website
        self.lastModified = lastModified
        self.lastViewed = lastViewed
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        structure = try container.decode(String.self, forKey: .structure)
        companyDescription = try container.decodeIfPresent(String.self, forKey: .companyDescription)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        website = try container.decodeIfPresent(String.self, forKey: .website)
        lastModified = try container.decode(Date.self, forKey: .lastModified)
        lastViewed = try container.decode(Date.self, forKey: .lastViewed)
        
        // SAFE DECODE: handle Base64, Postgres BYTEA hex strings (\x...), or raw Data
        if let str = try? container.decodeIfPresent(String.self, forKey: .logoData) {
            if str.hasPrefix("\\x") {
                logoData = Data(hexString: String(str.dropFirst(2)))
            } else {
                logoData = Data(base64Encoded: str)
            }
        } else {
            logoData = try? container.decodeIfPresent(Data.self, forKey: .logoData)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(name, forKey: .name)
        try container.encode(structure, forKey: .structure)
        try container.encodeIfPresent(companyDescription, forKey: .companyDescription)
        try container.encode(colorHex, forKey: .colorHex)
        try container.encodeIfPresent(logoData?.base64EncodedString(), forKey: .logoData)
        try container.encodeIfPresent(website, forKey: .website)
        try container.encode(lastModified, forKey: .lastModified)
        try container.encode(lastViewed, forKey: .lastViewed)
    }
}

// MARK: - Supporting Types
extension Company {
    var initial: String {
        String(name.prefix(1)).uppercased()
    }

    static let structures = [
        "LLC", "S-Corp", "C-Corp", "Small Business",
        "Sole Proprietorship", "Partnership",
        "Holding Company", "Non-Profit", "Household", "Individual", "Other"
    ]

    static let brandColors = [
        "#4f46e5", "#10b981", "#f59e0b", "#ef4444",
        "#3b82f6", "#8b5cf6", "#ec4899", "#64748b", "#000000"
    ]
}

// MARK: - Sharing Models

struct ResourceInvitation: Identifiable, Codable, Hashable {
    var id: UUID
    var resourceId: UUID
    var resourceType: String
    var email: String
    var role: String
    var invitedBy: UUID
    var senderEmail: String?
    var senderDisplayName: String?
    var createdAt: Date
    var status: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case resourceId = "resource_id"
        case resourceType = "resource_type"
        case email
        case role
        case invitedBy = "invited_by"
        case senderEmail = "sender_email"
        case senderDisplayName = "sender_display_name"
        case createdAt = "created_at"
        case status
    }
    
    init(
        id: UUID = UUID(),
        resourceId: UUID,
        resourceType: String,
        email: String,
        role: String = "Viewer",
        invitedBy: UUID,
        senderEmail: String? = nil,
        senderDisplayName: String? = nil,
        createdAt: Date = Date(),
        status: String = "Pending"
    ) {
        self.id = id
        self.resourceId = resourceId
        self.resourceType = resourceType
        self.email = email
        self.role = role
        self.invitedBy = invitedBy
        self.senderEmail = senderEmail
        self.senderDisplayName = senderDisplayName
        self.createdAt = createdAt
        self.status = status
    }
}

struct ResourceShare: Identifiable, Codable, Hashable {
    var id: UUID
    var resourceId: UUID
    var resourceType: String
    var userId: UUID
    var role: String
    var senderEmail: String?
    var senderDisplayName: String?
    var recipientEmail: String?
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case resourceId = "resource_id"
        case resourceType = "resource_type"
        case userId = "user_id"
        case role
        case senderEmail = "sender_email"
        case senderDisplayName = "sender_display_name"
        case recipientEmail = "recipient_email"
        case createdAt = "created_at"
    }
    
    init(
        id: UUID = UUID(),
        resourceId: UUID,
        resourceType: String,
        userId: UUID,
        role: String = "Viewer",
        senderEmail: String? = nil,
        senderDisplayName: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.resourceId = resourceId
        self.resourceType = resourceType
        self.userId = userId
        self.role = role
        self.senderEmail = senderEmail
        self.senderDisplayName = senderDisplayName
        self.createdAt = createdAt
    }
}

// MARK: - Hex Data Decoder
extension Data {
    init?(hexString: String) {
        let cleanHex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanHex.count % 2 == 0 else { return nil }
        var data = Data(capacity: cleanHex.count / 2)
        var index = cleanHex.startIndex
        for _ in 0..<(cleanHex.count / 2) {
            let nextIndex = cleanHex.index(index, offsetBy: 2)
            let bytes = cleanHex[index..<nextIndex]
            if let byte = UInt8(bytes, radix: 16) {
                data.append(byte)
            } else {
                return nil
            }
            index = nextIndex
        }
        self = data
    }
}
