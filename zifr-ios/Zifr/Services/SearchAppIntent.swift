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
        AppShortcut(intent: AskMiloomIntent(), phrases: ["Ask \(.applicationName)", "Check my portfolio in \(.applicationName)"], shortTitle: "Ask Miloom", systemImageName: "text.bubble")
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

/// Uses the foreground app's authenticated data. It never unlocks an app session or
/// exports portfolio records into Spotlight. Cold starts keep the existing search handoff.
@MainActor
final class SearchIntentSession {
    static let shared = SearchIntentSession()
    weak var appState: AppState?
    weak var auth: AuthViewModel?

    func currentIndex() -> UniversalSearchIndex? {
        guard let appState, let auth, auth.isAuthenticated, let userID = auth.currentUser?.id,
              appState.hasLoadedPortfolio, appState.portfolioUserID == userID else { return nil }
        return appState.searchIndex(for: userID)
    }

    func answer(_ query: String) async -> String {
        SearchRouteCoordinator.shared.open(query)
        // Launch and portfolio loading can finish after the intent starts.
        for _ in 0..<30 {
            if currentIndex() != nil { break }
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return "Search was cancelled." }
        }
        guard let userID = auth?.currentUser?.id, let index = currentIndex() else {
            return "Open and unlock Miloom to search your current portfolio. Your question is ready in Search."
        }
        let response = await Task.detached { index.search(query) }.value
        guard auth?.isAuthenticated == true, auth?.currentUser?.id == userID,
              appState?.portfolioUserID == userID else { return "Unlock Miloom to view this answer." }
        return response.spokenAnswer
    }
}

extension SearchResponse {
    var spokenAnswer: String {
        if isCredentialRequest { return "Your saved login can be revealed or copied inside Miloom. Passwords are not shared with Siri." }
        if let answerSummary, !answerSummary.isEmpty { return String((answerSummary + ". " + interpretation + ". " + coverage).prefix(1800)) }
        if !totals.isEmpty { return totals.prefix(5).map { "\($0.label): \($0.formatted)" }.joined(separator: ". ") + ". " + coverage }
        guard !hits.isEmpty else { return "No matching records were available. " + interpretation + ". " + coverage }
        return hits.prefix(3).map { "\($0.record.title), \($0.record.detail), \($0.record.company)" }.joined(separator: ". ") + (hits.count > 3 ? ". More results are in Miloom." : "") + ". " + coverage
    }
}

struct AskMiloomIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Miloom"
    static var description = IntentDescription("Find portfolio records, check balances, calculate spending or find your largest transaction.")
    static var openAppWhenRun = true
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    @Parameter(title: "Question", requestValueDialog: "What would you like to know?") var question: String
    static var parameterSummary: some ParameterSummary { Summary("Ask Miloom \(\.$question)") }
    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let answer = await SearchIntentSession.shared.answer(question)
        return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
    }
}

struct MiloomRecordEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Miloom record")
    static var defaultQuery = MiloomRecordQuery()
    let id: String
    @Property(title: "Name") var name: String
    @Property(title: "Company") var company: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)", subtitle: "\(company)") }
    init(_ record: SearchRecord) { id = record.id; name = record.title; company = record.company }
}

struct MiloomRecordQuery: EntityStringQuery {
    @MainActor func entities(for identifiers: [String]) async throws -> [MiloomRecordEntity] {
        guard let index = SearchIntentSession.shared.currentIndex() else { return [] }
        return index.records.filter { identifiers.contains($0.id) && $0.page == nil }.map(MiloomRecordEntity.init)
    }
    @MainActor func entities(matching string: String) async throws -> [MiloomRecordEntity] {
        guard let index = SearchIntentSession.shared.currentIndex() else { return [] }
        return index.search(string).hits.prefix(20).map { MiloomRecordEntity($0.record) }
    }
    func suggestedEntities() async throws -> [MiloomRecordEntity] { [] }
}

struct ReadMiloomRecordIntent: AppIntent {
    static var title: LocalizedStringResource = "Read Miloom record"
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    static var openAppWhenRun = true
    @Parameter(title: "Record") var record: MiloomRecordEntity
    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let index = SearchIntentSession.shared.currentIndex() else {
            return .result(value: "Unlock Miloom to read this record.", dialog: "Unlock Miloom to read this record.")
        }
        var query = PortfolioQuery(); query.operation = .details; query.sourceID = record.id
        let response = index.execute(query)
        SearchRouteCoordinator.shared.open(record.name)
        let answer = response.spokenAnswer
        return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
    }
}
