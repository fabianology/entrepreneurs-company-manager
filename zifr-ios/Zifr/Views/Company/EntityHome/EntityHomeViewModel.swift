import SwiftUI
import Foundation

struct HomeAlert: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let text: String
}

struct EntityHomeViewModel {
    let company: Company
    let subscriptions: [Subscription]
    let cards: [FinancialCard]
    let institutions: [Institution]
    let loans: [Loan]
    let documents: [CompanyDocument]

    // MARK: - Computed Metrics (Subscriptions)
    var activeSubscriptions: [Subscription] { subscriptions.filter { $0.status == "Active" } }
    
    var monthlyBurn: Double {
        activeSubscriptions.reduce(0.0) { acc, sub in
            let base = sub.billingCycle == "Monthly" ? sub.cost : sub.cost / 12
            let extras = sub.subServices.filter { $0.status != .paused }.reduce(0.0) { $0 + $1.cost }
            return acc + base + extras
        }
    }
    
    // MARK: - Computed Metrics (Financial)
    var creditCards: [FinancialCard] { cards.filter { $0.type == "Credit" } }
    
    var totalDebt: Double {
        loans.filter { $0.isLender }.reduce(0) { $0 + $1.remainingBalance }
        + creditCards.reduce(0) { $0 + $1.balance }
    }
    
    var totalCreditLimit: Double { creditCards.reduce(0) { $0 + $1.limit } }
    
    var totalCreditUsed: Double { creditCards.reduce(0) { $0 + $1.balance } }
    
    var availableCredit: Double { max(0, totalCreditLimit - totalCreditUsed) }
    
    var creditUtilization: Double {
        guard totalCreditLimit > 0 else { return 0 }
        return totalCreditUsed / totalCreditLimit
    }
    
    var expiringPromos: [(String, Int)] {
        let thirtyDays = Date().addingTimeInterval(30 * 24 * 3600)
        return creditCards
            .filter { $0.promoApr == 0 && ($0.promoEnds ?? .distantPast) > Date() && ($0.promoEnds ?? .distantFuture) <= thirtyDays }
            .map { card in
                let days = Calendar.current.dateComponents([.day], from: Date(), to: card.promoEnds ?? Date()).day ?? 0
                return (card.name, days)
            }
    }

    // MARK: - Computed Metrics (Documents)
    var docCategories: [String] {
        company.structure == "Personal"
        ? CompanyDocument.personalTypes
        : CompanyDocument.businessTypes
    }
    
    var coveredCategories: Set<String> { Set(documents.map(\.type)) }
    
    var categoryCoverage: Int { coveredCategories.intersection(docCategories).count }

    // MARK: - Alerts
    var isZeroState: Bool {
        subscriptions.isEmpty && cards.isEmpty && institutions.isEmpty && loans.isEmpty && documents.isEmpty
    }

    var alerts: [HomeAlert] {
        var result: [HomeAlert] = []

        for (name, days) in expiringPromos {
            result.append(HomeAlert(icon: "exclamationmark.triangle.fill", color: .orange, text: "Promo APR on \(name) expires in \(days) days"))
        }

        if creditUtilization > 0.7 && totalCreditLimit > 0 {
            result.append(HomeAlert(icon: "creditcard.trianglebadge.exclamationmark.fill", color: .orange, text: "Credit utilization at \(Int(creditUtilization * 100))%"))
        }

        let criticalMissing = docCategories.filter { !coveredCategories.contains($0) && $0 != "Other" }
        if !criticalMissing.isEmpty {
            result.append(HomeAlert(icon: "doc.badge.clock.fill", color: Color.white.opacity(0.5), text: "\(criticalMissing.count) document \(criticalMissing.count == 1 ? "category" : "categories") missing"))
        }

        let daysSinceModified = Calendar.current.dateComponents([.day], from: company.lastModified, to: Date()).day ?? 0
        if daysSinceModified > 90 {
            result.append(HomeAlert(icon: "clock.arrow.circlepath", color: Color.white.opacity(0.4), text: "Not updated in \(daysSinceModified) days"))
        }

        return result
    }
}
