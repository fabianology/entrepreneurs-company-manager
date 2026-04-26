import Foundation
import SwiftData

@Model
final class CompanyDocument {
    var id: String = UUID().uuidString
    var companyId: String = ""
    var name: String = "New Document"
    var type: String = "Other"
    var url: String = ""
    var uploadDate: String = ""
    var notes: String = ""
    var company: Company?

    init(
        id: String = UUID().uuidString,
        companyId: String = "",
        name: String = "New Document",
        type: String = "Other",
        url: String = "",
        uploadDate: String = "",
        notes: String = ""
    ) {
        self.id = id
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
