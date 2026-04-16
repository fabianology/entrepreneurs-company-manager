import SwiftUI
import SwiftData

@main
struct ZifrApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for:
                Company.self,
                Subscription.self,
                FinancialCard.self,
                Institution.self,
                Loan.self,
                CompanyDocument.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
