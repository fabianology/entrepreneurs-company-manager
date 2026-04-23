import SwiftUI
import SwiftData

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

@main
struct ZifrApp: App {
    let container: ModelContainer

    init() {
        // MARK: Global UI Styling
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(hex: "#223E5A")
        UISegmentedControl.appearance().backgroundColor = UIColor(hex: "#111111")
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white.withAlphaComponent(0.5)], for: .normal)
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
