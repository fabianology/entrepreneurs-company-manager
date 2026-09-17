import Foundation
import AppIntents
import Observation

@MainActor @Observable
final class SearchRouteCoordinator {
    static let shared = SearchRouteCoordinator()
    struct Request: Equatable { let id = UUID(); let query: String }
    var pending: Request?
    func open(_ query: String) { pending = Request(query: String(query.prefix(1000))) }
    func clear() { pending = nil }
}

/// Siri/Shortcuts open the app's own search after device unlock. Portfolio data and
/// credentials are not donated to Spotlight or returned in a Siri spoken response.
struct SearchMiloomIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Miloom"
    static var description = IntentDescription("Search your companies, services, accounts, transactions and documents in Miloom.")
    static var openAppWhenRun: Bool = true
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    @Parameter(title: "Search", requestValueDialog: "What would you like to find in Miloom?") var query: String
    static var parameterSummary: some ParameterSummary { Summary("Search Miloom for \(\.$query)") }
    @MainActor func perform() async throws -> some IntentResult {
        SearchRouteCoordinator.shared.open(query)
        return .result()
    }
}

struct MiloomSearchShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: SearchMiloomIntent(), phrases: ["Search \(.applicationName)", "Find something in \(.applicationName)"], shortTitle: "Search Miloom", systemImageName: "magnifyingglass")
    }
}

@available(iOS 18.0, *)
@AssistantIntent(schema: .system.search)
struct SearchMiloomSystemIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Miloom records"
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    @Parameter(title: "Search") var criteria: StringSearchCriteria
    @MainActor func perform() async throws -> some IntentResult {
        SearchRouteCoordinator.shared.open(criteria.term)
        return .result()
    }
}
