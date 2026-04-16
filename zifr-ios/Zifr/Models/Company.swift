import Foundation
import SwiftData

@Model
final class Company {
    var id: String
    var name: String
    var structure: String
    var companyDescription: String
    var colorHex: String
    var logoData: Data?
    var website: String
    var lastModified: Date
    var lastViewed: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        structure: String = "LLC",
        companyDescription: String = "",
        colorHex: String = "#4f46e5",
        logoData: Data? = nil,
        website: String = "",
        lastModified: Date = Date(),
        lastViewed: Date = Date()
    ) {
        self.id = id
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
        "Holding Company", "Non-Profit", "Personal", "Other"
    ]

    static let brandColors = [
        "#4f46e5", "#10b981", "#f59e0b", "#ef4444",
        "#3b82f6", "#8b5cf6", "#ec4899", "#64748b", "#000000"
    ]
}
