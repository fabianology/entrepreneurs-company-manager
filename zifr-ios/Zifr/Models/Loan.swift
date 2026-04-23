import Foundation
import SwiftData

@Model
final class LoanPayment: Identifiable {
    var id: String
    var date: Date
    var amount: Double
    var source: String
    
    init(id: String = UUID().uuidString, date: Date = Date(), amount: Double = 0, source: String = "") {
        self.id = id
        self.date = date
        self.amount = amount
        self.source = source
    }
}

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
    var startDate: Date
    var maturityDate: Date?
    var paidOffDate: Date?
    var status: String
    var notes: String
    @Relationship(deleteRule: .cascade) var payments: [LoanPayment]

    init(
        id: String = UUID().uuidString,
        companyId: String,
        role: String = "Bank Loan",
        lender: String = "",
        name: String = "",
        principalAmount: Double = 0,
        remainingBalance: Double = 0,
        interestType: String = "Percentage",
        interestRate: Double = 0,
        term: String = "36 months",
        termYears: Int = 0,
        termMonths: Int = 36,
        scheduleFrequency: String = "Monthly",
        monthlyPayment: Double = 0,
        startDate: Date = Date(),
        maturityDate: Date? = nil,
        paidOffDate: Date? = nil,
        status: String = "Active",
        notes: String = "",
        payments: [LoanPayment] = []
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
        self.notes = notes
        self.payments = payments
    }

    var progressPercent: Double {
        guard principalAmount > 0 else { return 0 }
        return max(0, min(1, (principalAmount - remainingBalance) / principalAmount))
    }

    struct AmortizationRow: Identifiable {
        var id: Int { month }
        var month: Int
        var payment: Double
        var principal: Double
        var interest: Double
        var balance: Double
    }

    struct AmortizationResult {
        var monthlyPayment: Double
        var totalPrincipal: Double
        var totalInterest: Double
        var totalCost: Double
        var principalPct: Double
        var interestPct: Double
        var schedule: [AmortizationRow] = []
    }

    var amortization: AmortizationResult {
        let principal = principalAmount
        let rate = interestRate
        let isFixed = interestType == "Fixed"
        let totalMonths = Double(termYears * 12 + termMonths)
        
        if principal <= 0 { 
            return AmortizationResult(monthlyPayment: 0, totalPrincipal: 0, totalInterest: 0, totalCost: 0, principalPct: 0, interestPct: 0, schedule: []) 
        }
        
        if isFixed {
            let totalCost = principal + rate
            let pPct = totalCost > 0 ? (principal / totalCost) * 100 : 0
            let iPct = totalCost > 0 ? (rate / totalCost) * 100 : 0
            return AmortizationResult(monthlyPayment: 0, totalPrincipal: principal, totalInterest: rate, totalCost: totalCost, principalPct: pPct, interestPct: iPct, schedule: [])
        }
        
        if totalMonths <= 0 { 
            return AmortizationResult(monthlyPayment: 0, totalPrincipal: principal, totalInterest: 0, totalCost: principal, principalPct: 100, interestPct: 0, schedule: []) 
        }
        
        let periodsPerYear: Double = scheduleFrequency == "Weekly" ? 52 : (scheduleFrequency == "Yearly" ? 1 : 12)
        let totalPeriods = scheduleFrequency == "Weekly" ? (totalMonths / 12) * 52 : (scheduleFrequency == "Yearly" ? (totalMonths / 12) : totalMonths)
        
        let perPeriodRate = (rate / 100) / periodsPerYear
        
        var schedule: [AmortizationRow] = []
        var balance = principal
        let pmt: Double
        
        if perPeriodRate <= 0 {
            pmt = principal / totalPeriods
            for i in 1...max(1, Int(totalPeriods)) {
                balance -= pmt
                schedule.append(AmortizationRow(month: i, payment: pmt, principal: pmt, interest: 0, balance: max(0, balance)))
            }
            return AmortizationResult(monthlyPayment: pmt, totalPrincipal: principal, totalInterest: 0, totalCost: principal, principalPct: 100, interestPct: 0, schedule: schedule)
        } else {
            let compound = pow(1 + perPeriodRate, totalPeriods)
            pmt = principal * (perPeriodRate * compound) / (compound - 1)
            let totalCost = pmt * totalPeriods
            let totalInterest = totalCost - principal
            let pPct = totalCost > 0 ? (principal / totalCost) * 100 : 0
            let iPct = totalCost > 0 ? (totalInterest / totalCost) * 100 : 0
            
            for i in 1...max(1, Int(totalPeriods)) {
                let interestForPeriod = balance * perPeriodRate
                let principalForPeriod = pmt - interestForPeriod
                balance -= principalForPeriod
                schedule.append(AmortizationRow(month: i, payment: pmt, principal: principalForPeriod, interest: interestForPeriod, balance: max(0, balance)))
            }
            
            return AmortizationResult(monthlyPayment: pmt, totalPrincipal: principal, totalInterest: totalInterest, totalCost: totalCost, principalPct: pPct, interestPct: iPct, schedule: schedule)
        }
    }

    static let roles = ["Bank Loan", "I'm Lending"]
    static let statuses = ["Active", "Paid Off", "Default"]
    static let frequencies = ["Weekly", "Monthly", "Yearly"]
    static let interestTypes = ["Percentage", "Fixed"]
}
