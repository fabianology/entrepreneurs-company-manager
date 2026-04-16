import Foundation
import SwiftData

@Model
final class Loan {
    var id: String
    var companyId: String
    var role: String
    var lender: String
    var name: String
    var principalAmount: Double
    var remainingBalance: Double
    var interestType: String
    var interestRate: Double
    var term: String
    var termYears: Int
    var termMonths: Int
    var scheduleFrequency: String
    var monthlyPayment: Double
    var startDate: String
    var maturityDate: String
    var paidOffDate: String
    var status: String

    init(
        id: String = UUID().uuidString,
        companyId: String,
        role: String = "Lendee",
        lender: String = "",
        name: String = "New Loan",
        principalAmount: Double = 0,
        remainingBalance: Double = 0,
        interestType: String = "Percentage",
        interestRate: Double = 0,
        term: String = "36 months",
        termYears: Int = 0,
        termMonths: Int = 36,
        scheduleFrequency: String = "Monthly",
        monthlyPayment: Double = 0,
        startDate: String = "",
        maturityDate: String = "",
        paidOffDate: String = "",
        status: String = "Active"
    ) {
        self.id = id
        self.companyId = companyId
        self.role = role
        self.lender = lender
        self.name = name
        self.principalAmount = principalAmount
        self.remainingBalance = remainingBalance
        self.interestType = interestType
        self.interestRate = interestRate
        self.term = term
        self.termYears = termYears
        self.termMonths = termMonths
        self.scheduleFrequency = scheduleFrequency
        self.monthlyPayment = monthlyPayment
        self.startDate = startDate
        self.maturityDate = maturityDate
        self.paidOffDate = paidOffDate
        self.status = status
    }

    var progressPercent: Double {
        guard principalAmount > 0 else { return 0 }
        return max(0, min(1, (principalAmount - remainingBalance) / principalAmount))
    }

    static let roles = ["Lendee", "Lender"]
    static let statuses = ["Active", "Paid Off", "Default"]
    static let frequencies = ["Weekly", "Monthly", "Yearly"]
    static let interestTypes = ["Percentage", "Fixed"]
}
