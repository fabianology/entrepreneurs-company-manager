import Foundation

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
