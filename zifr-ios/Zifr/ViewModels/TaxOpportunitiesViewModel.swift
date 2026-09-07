import Foundation
import Observation

@MainActor @Observable
final class TaxOpportunitiesViewModel {
    var isBusy = false
    var error: String?

    func refresh(_ state: AppState) async {
        do { try await DataRepository.shared.refreshBusinessExpenses(appState: state); error = nil }
        catch {
            self.error = Self.message(error)
            state.businessExpenseLoadError = self.error
        }
    }
    func perform(_ state: AppState, operation: () async throws -> Void) async -> Bool {
        guard !isBusy else { return false }
        isBusy = true; error = nil
        defer { isBusy = false }
        do {
            try await operation()
            try await DataRepository.shared.refreshBusinessExpenses(appState: state)
            return true
        } catch { self.error = Self.message(error); return false }
    }
    static func message(_ error: Error) -> String {
        let value = error.localizedDescription
        if value.contains("EXPENSE_REVISION_CONFLICT") { return "This expense changed on another device. Close and reopen it to review the latest version before saving." }
        if value.contains("EXPENSE_PRO_REQUIRED") { return "Automated screening requires Miloom Pro. You can still review, document, and export expenses." }
        if value.contains("EXPENSE_EXPORT_INCOMPLETE") { return "Some expenses need attention. Complete the missing information or choose an incomplete review export." }
        if value.contains("schema cache") || value.contains("does not exist") || value.contains("PGRST202") {
            return "Tax Opportunities is not available on this server yet. Your financial transactions are unchanged. Please try again after the service is updated."
        }
        return value
    }
}
