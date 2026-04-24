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

    static let types = ["Formation", "Legal", "Contract", "Finance", "Other"]

    var typeIcon: String {
        switch type {
        case "Formation": return "building.2"
        case "Legal": return "scale.3d"
        case "Contract": return "doc.text"
        case "Finance": return "chart.bar"
        default: return "doc"
        }
    }
}
