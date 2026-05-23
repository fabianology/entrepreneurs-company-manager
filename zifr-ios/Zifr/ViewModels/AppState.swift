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
    var resourceShares: [ResourceShare] = []
    
    var isLoading: Bool = false
    var error: String? = nil
    
    // Derived properties for easy access
    func subscriptions(for companyId: UUID) -> [Subscription] {
        subscriptions.filter { $0.companyId == companyId }
    }
    
    func cards(for companyId: UUID) -> [FinancialCard] {
        cards.filter { $0.companyId == companyId }
    }
    
    func loans(for companyId: UUID) -> [Loan] {
        loans.filter { $0.companyId == companyId }
    }
    
    func institutions(for companyId: UUID) -> [Institution] {
        institutions.filter { $0.companyId == companyId }
    }
    
    func documents(for companyId: UUID) -> [CompanyDocument] {
        documents.filter { $0.companyId == companyId }
    }
}
