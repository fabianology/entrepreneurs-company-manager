import Foundation

struct CompanyDocument: Identifiable, Codable, Hashable {
    var id: UUID
    var userId: UUID
    var companyId: UUID
    var name: String
    var type: String
    var url: String?
    var uploadDate: String?
    var notes: String?
    var expiresAt: Date?
    var renewalMetadata: [String: String]

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case companyId = "company_id"
        case name
        case type
        case url
        case uploadDate = "upload_date"
        case notes
        case expiresAt = "expires_at"
        case renewalMetadata = "renewal_metadata"
    }
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        companyId: UUID,
        name: String = "New Document",
        type: String = "Other",
        url: String? = nil,
        uploadDate: String? = nil,
        notes: String? = nil,
        expiresAt: Date? = nil,
        renewalMetadata: [String: String] = [:]
    ) {
        self.id = id
        self.userId = userId
        self.companyId = companyId
        self.name = name
        self.type = type
        self.url = url
        self.uploadDate = uploadDate
        self.notes = notes
        self.expiresAt = expiresAt
        self.renewalMetadata = renewalMetadata
    }

    static let businessTypes = [
        "Legal",
        "Taxes",
        "Identity",
        "Estate",
        "Other",
        "Receipts"
    ]

    static let personalTypes = [
        "Legal",
        "Taxes",
        "Identity",
        "Estate",
        "Other",
        "Receipts"
    ]

    static func normalizeType(_ type: String) -> String {
        switch type {
        case "Legal", "Legal & IP", "Contracts", "Contracts & HR", "Formation", "Formation & Governance", "Compliance", "Compliance & Insurance":
            return "Legal"
        case "Taxes", "Tax & IRS":
            return "Taxes"
        case "Identity", "Identity & Vital Records", "Identity & Vital Docs":
            return "Identity"
        case "Estate", "Estate & Medical", "Medical", "Property", "Property & Assets", "Property & Estate":
            return "Estate"
        case "Receipts", "Receipt":
            return "Receipts"
        case "Other":
            return "Other"
        default:
            return type
        }
    }

    static func types(for structure: String) -> [String] {
        return businessTypes
    }

    static func icon(for type: String) -> String {
        switch type {
        case "Legal", "Legal & IP", "Contracts", "Formation", "Compliance": return "scale.3d"
        case "Taxes", "Tax & IRS": return "dollarsign.circle"
        case "Identity", "Identity & Vital Records", "Identity & Vital Docs": return "person.text.rectangle"
        case "Estate", "Estate & Medical", "Medical", "Property": return "house.fill"
        case "Receipts", "Receipt": return "receipt"
        case "Other": return "doc"
        default: return "doc"
        }
    }

    var typeIcon: String {
        Self.icon(for: type)
    }
}
