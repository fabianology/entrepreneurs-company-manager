import Foundation
import SwiftData

@Model
final class Company {
    var id: String = UUID().uuidString
    var name: String = ""
    var structure: String = "LLC"
    var companyDescription: String = ""
    var colorHex: String = "#4f46e5"
    var logoData: Data? = nil
    var website: String = ""
    var lastModified: Date = Date()
    var lastViewed: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Institution.company) var institutions: [Institution]? = []
    @Relationship(deleteRule: .cascade, inverse: \Subscription.company) var subscriptions: [Subscription]? = []
    @Relationship(deleteRule: .cascade, inverse: \FinancialCard.company) var financialCards: [FinancialCard]? = []
    @Relationship(deleteRule: .cascade, inverse: \Loan.company) var loans: [Loan]? = []
    @Relationship(deleteRule: .cascade, inverse: \CompanyDocument.company) var documents: [CompanyDocument]? = []

    init(
        id: String = UUID().uuidString,
        name: String = "",
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
        "Holding Company", "Non-Profit", "Household", "Individual", "Other"
    ]

    static let brandColors = [
        "#4f46e5", "#10b981", "#f59e0b", "#ef4444",
        "#3b82f6", "#8b5cf6", "#ec4899", "#64748b", "#000000"
    ]
}
