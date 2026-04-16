import SwiftUI
import SwiftData

@main
struct ZifrApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([
            Company.self,
            Subscription.self,
            FinancialCard.self,
            Institution.self,
            Loan.self,
            CompanyDocument.self
        ])

        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            // Schema mismatch (e.g. new properties added). Wipe the store and start fresh.
            let storeURL = config.url
            do {
                try FileManager.default.removeItem(at: storeURL)
                // Also remove associated WAL/SHM files
                let wal = storeURL.appendingPathExtension("wal")
                let shm = storeURL.appendingPathExtension("shm")
                try? FileManager.default.removeItem(at: wal)
                try? FileManager.default.removeItem(at: shm)
                container = try ModelContainer(for: schema, configurations: config)
                print("⚠️ SwiftData store was reset due to schema change.")
            } catch {
                fatalError("Failed to create ModelContainer even after reset: \(error)")
            }
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
