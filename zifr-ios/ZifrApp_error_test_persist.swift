import Foundation
import SwiftData

struct InstitutionAccount: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var type: String = "Checking"
    var isCard: Bool { false }
}

@Model
final class Institution {
    var id: String = UUID().uuidString
    var companyId: String = ""
    var accountsData: Data = Data()
    init() {}
}

@Model
final class Subscription {
    var id: String = UUID().uuidString
    init() {}
}

@Model
final class FinancialCard {
    var id: String = UUID().uuidString
    init() {}
}

@Model
final class LoanPayment: Identifiable {
    var id: String = UUID().uuidString
    init() {}
}

@Model
final class Loan {
    var id: String = UUID().uuidString
    @Relationship(deleteRule: .cascade) var payments: [LoanPayment] = []
    init() {}
}

@Model
final class CompanyDocument {
    var id: String = UUID().uuidString
    init() {}
}

@Model
final class Company {
    var id: String = UUID().uuidString
    init() {}
}

@main
struct App {
    static func main() {
        let schema = Schema([
            Company.self,
            Subscription.self,
            FinancialCard.self,
            Institution.self,
            Loan.self,
            LoanPayment.self,
            CompanyDocument.self
        ])

        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let _ = try ModelContainer(for: schema, configurations: config)
            print("SUCCESS")
        } catch {
            print("ERROR: \(error)")
        }
    }
}
