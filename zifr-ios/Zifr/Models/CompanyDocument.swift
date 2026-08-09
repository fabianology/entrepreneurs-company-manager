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

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case companyId = "company_id"
        case name
        case type
        case url
        case uploadDate = "upload_date"
        case notes
    }
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        companyId: UUID,
        name: String = "New Document",
        type: String = "Other",
        url: String? = nil,
        uploadDate: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.companyId = companyId
        self.name = name
        self.type = type
        self.url = url
        self.uploadDate = uploadDate
        self.notes = notes
    }

    static let businessTypes = [
        "Formation",
        "Taxes",
        "Legal & IP",
        "Contracts",
        "Compliance",
        "Identity",
        "Property",
        "Estate",
        "Other"
    ]

    static let personalTypes = [
        "Medical",
        "Identity",
        "Legal",
        "Taxes",
        "Property",
        "Other"
    ]

    static func normalizeType(_ type: String) -> String {
        switch type {
        case "Formation & Governance": return "Formation"
        case "Tax & IRS": return "Taxes"
        case "Contracts & HR": return "Contracts"
        case "Compliance & Insurance": return "Compliance"
        case "Identity & Vital Records", "Identity & Vital Docs": return "Identity"
        case "Property & Assets", "Property & Estate": return "Property"
        case "Estate & Medical": return "Estate"
        default: return type
        }
    }

    static func types(for structure: String) -> [String] {
        if structure == "Personal" {
            return personalTypes
        } else {
            return businessTypes
        }
    }

    static func icon(for type: String) -> String {
        switch type {
        case "Formation", "Formation & Governance": return "building.2.fill"
        case "Taxes", "Tax & IRS": return "dollarsign.circle"
        case "Legal & IP", "Legal": return "scale.3d"
        case "Contracts", "Contracts & HR": return "signature"
        case "Compliance", "Compliance & Insurance": return "checkmark.shield"
        case "Identity", "Identity & Vital Records", "Identity & Vital Docs": return "person.text.rectangle"
        case "Property", "Property & Assets", "Property & Estate": return "house.fill"
        case "Estate", "Estate & Medical", "Medical": return "cross.case.fill"
        default: return "doc"
        }
    }

    var typeIcon: String {
        Self.icon(for: type)
    }
}
