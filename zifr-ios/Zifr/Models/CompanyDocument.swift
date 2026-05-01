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
        "Formation & Governance",
        "Tax & IRS",
        "Legal & IP",
        "Contracts & HR",
        "Compliance & Insurance",
        "Identity & Vital Records",
        "Property & Assets",
        "Estate & Medical",
        "Other"
    ]

    static let personalTypes = [
        "Medical",
        "Identity & Vital Docs",
        "Legal",
        "Taxes",
        "Property & Estate",
        "Other"
    ]

    static func types(for structure: String) -> [String] {
        if structure == "Personal" {
            return personalTypes
        } else {
            return businessTypes
        }
    }

    static func icon(for type: String) -> String {
        switch type {
        case "Formation & Governance": return "building.2.fill"
        case "Tax & IRS", "Taxes": return "dollarsign.circle"
        case "Legal & IP", "Legal": return "scale.3d"
        case "Contracts & HR": return "signature"
        case "Compliance & Insurance": return "checkmark.shield"
        case "Identity & Vital Records", "Identity & Vital Docs": return "person.text.rectangle"
        case "Property & Assets", "Property & Estate": return "house.fill"
        case "Estate & Medical", "Medical": return "cross.case.fill"
        default: return "doc"
        }
    }

    var typeIcon: String {
        Self.icon(for: type)
    }
}
