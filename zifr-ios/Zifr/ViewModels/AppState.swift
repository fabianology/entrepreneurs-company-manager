import Foundation
import SwiftUI
import Observation

@Observable
final class AppState {
    var companies: [Company] = []
    var subscriptions: [Subscription] = []
    var institutions: [Institution] = []
    var cards: [FinancialCard] = []
    var loans: [Loan] = []
    var documents: [CompanyDocument] = []
    var transactions: [Transaction] = []
    var transactionOverrides: [TransactionOverride] = []
    var resourceShares: [ResourceShare] = []
    var activityLogs: [ActivityLog] = []
    var notifications: [AppNotification] = []
    var userPreferences: UserPreferences? = nil
    var plaidItems: [PlaidItemSummary] = []
    var entitlementSnapshot: AccessSnapshot = .free
    var resourceConnections: [ResourceConnection] = []
    var obligations: [PortfolioObligation] = []
    
    var isLoading: Bool = false
    var error: String? = nil
    
    // Local Overrides: resourceId -> companyId
    var localCompanyOverrides: [String: UUID] = [:] {
        didSet {
            if let encoded = try? JSONEncoder().encode(localCompanyOverrides) {
                UserDefaults.standard.set(encoded, forKey: "localCompanyOverrides")
            }
        }
    }
    
    init() {
        if let data = UserDefaults.standard.data(forKey: "localCompanyOverrides"),
           let decoded = try? JSONDecoder().decode([String: UUID].self, from: data) {
            self.localCompanyOverrides = decoded
        }
    }
    
    // Derived properties for easy access
    private func effectiveCompanyId(for resourceId: UUID, defaultCompanyId: UUID) -> UUID {
        return localCompanyOverrides[resourceId.uuidString] ?? defaultCompanyId
    }

    func subscriptions(for companyId: UUID) -> [Subscription] {
        subscriptions.filter { effectiveCompanyId(for: $0.id ?? UUID(), defaultCompanyId: $0.companyId) == companyId }
    }
    
    func cards(for companyId: UUID) -> [FinancialCard] {
        cards.filter { effectiveCompanyId(for: $0.id ?? UUID(), defaultCompanyId: $0.companyId) == companyId }
    }
    
    func loans(for companyId: UUID) -> [Loan] {
        loans.filter { effectiveCompanyId(for: $0.id ?? UUID(), defaultCompanyId: $0.companyId) == companyId }
    }
    
    func institutions(for companyId: UUID) -> [Institution] {
        institutions.filter { effectiveCompanyId(for: $0.id ?? UUID(), defaultCompanyId: $0.companyId) == companyId }
    }
    
    func documents(for companyId: UUID) -> [CompanyDocument] {
        documents.filter { effectiveCompanyId(for: $0.id ?? UUID(), defaultCompanyId: $0.companyId) == companyId }
    }

    var confirmedConnectionCount: Int {
        resourceConnections.filter { $0.state == .confirmed }.count
    }

    var suggestedConnectionCount: Int {
        resourceConnections.filter { $0.state == .suggested }.count
    }

    var openObligations: [PortfolioObligation] {
        OwnerBriefingPresentation.activeObligations(in: obligations)
    }

    var deferredObligations: [PortfolioObligation] {
        OwnerBriefingPresentation.deferredObligations(in: obligations)
    }

    var unreadBriefingCount: Int {
        openObligations.filter { $0.severity != .info }.count
    }
}
