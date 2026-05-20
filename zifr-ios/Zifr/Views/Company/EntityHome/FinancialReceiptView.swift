import SwiftUI

struct FinancialReceiptView: View {
    let company: Company
    let institutions: [Institution]
    let cards: [FinancialCard]
    let loans: [Loan]
    let subscriptions: [Subscription]
    
    @Environment(\.dismiss) private var dismiss
    
    private var creditCards: [FinancialCard] { cards.filter { $0.type == "Credit" } }
    
    private var totalDebt: Double {
        loans.filter { $0.role == "Bank Loan" }.reduce(0) { $0 + $1.remainingBalance }
        + creditCards.reduce(0) { $0 + $1.balance }
    }
    
    private var totalSubscriptionCost: Double {
        subscriptions.reduce(0) { total, sub in
            let subMonthlyCost = sub.billingCycle == "Yearly" ? sub.cost / 12.0 : sub.cost
            let extrasMonthlyCost = sub.subServices.filter { $0.status != .paused }.reduce(0) { sum, ss in
                let ssMonthlyCost = ss.billingCycle == .yearly ? ss.cost / 12.0 : ss.cost
                return sum + ssMonthlyCost
            }
            return total + subMonthlyCost + extrasMonthlyCost
        }
    }
    
    private var totalCreditLimit: Double {
        creditCards.reduce(0) { $0 + $1.limit }
    }
    
    private var availableCredit: Double {
        max(0, totalCreditLimit - creditCards.reduce(0) { $0 + $1.balance })
    }
    
    // Aesthetic tokens for the White Paper receipt
    private let paperColor = Color(hex: "#F8F9FA")
    private let inkColor = Color(hex: "#1A1A1A")
    private let fadedInk = Color(hex: "#1A1A1A").opacity(0.6)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Receipt Content
                    VStack(alignment: .leading, spacing: 16) {
                        receiptHeader
                        
                        dashedDivider
                        
                        ForEach(institutions) { inst in
                            institutionItem(inst: inst)
                            dashedDivider
                        }
                        
                        let orphanedCards = cards.filter { card in !institutions.contains { $0.name.lowercased() == (card.institutionName ?? "").lowercased() } }
                        let orphanedLoans = loans.filter { loan in loan.role == "Bank Loan" && !institutions.contains { $0.name.lowercased() == (loan.lender ?? "").lowercased() } }
                        
                        if !orphanedCards.isEmpty || !orphanedLoans.isEmpty {
                            otherAccountsItem(cards: orphanedCards, loans: orphanedLoans)
                            dashedDivider
                        }
                        
                        receiptFooter
                    }
                    .padding(24)
                    .background(paperColor)
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 16)
                .shadow(color: .white.opacity(0.1), radius: 20, x: 0, y: 10)
            }
            .background(Color(hex: "#121212").ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .font(.system(.body, design: .monospaced).bold())
                        .foregroundStyle(.white)
                }
            }
        }
    }
    
    // MARK: - Components
    
    private var dashedDivider: some View {
        Text(String(repeating: "- ", count: 50))
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(fadedInk)
            .lineLimit(1)
            .padding(.vertical, 8)
    }
    
    private var receiptHeader: some View {
        VStack(alignment: .center, spacing: 6) {
            Text("MILOOM COMMAND CENTER")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
            Text("FINANCIAL REPORT")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
            
            Text(company.name.uppercased())
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .padding(.top, 4)
            
            Text(Date().formatted(date: .numeric, time: .shortened))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(fadedInk)
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(inkColor)
    }
    
    private func institutionItem(inst: Institution) -> some View {
        let instCards = cards.filter { ($0.institutionName ?? "").lowercased() == (inst.name).lowercased() }
        let instLoans = loans.filter { $0.role == "Bank Loan" && ($0.lender ?? "").lowercased() == (inst.name).lowercased() }
        
        let instDebt = instLoans.reduce(0) { $0 + $1.remainingBalance } + instCards.reduce(0) { $0 + $1.balance }
        let instCredit = instCards.reduce(0) { $0 + $1.limit }
        let instAvailable = max(0, instCredit - instCards.reduce(0) { $0 + $1.balance })
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(inst.name.uppercased())
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                    Text("\(inst.accounts.count + instCards.count + instLoans.count) ACCOUNTS")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(fadedInk)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(String(format: "%.0f", instDebt))")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                    Text("DEBT")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(fadedInk)
                    
                    if instCredit > 0 {
                        Text("$\(String(format: "%.0f", instAvailable))")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .padding(.top, 4)
                        Text("AVAILABLE CREDIT")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(fadedInk)
                    }
                }
            }
            .foregroundStyle(inkColor)
            
            if !inst.accounts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BANK ACCOUNTS (\(inst.accounts.count)):")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                    ForEach(inst.accounts) { acc in
                        let nameToMatch = acc.name.isEmpty ? acc.type : acc.name
                        let paidSubs = subscriptions.filter { $0.paymentMethod == nameToMatch }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("- \(nameToMatch) (\(acc.last4.isEmpty ? "0000" : acc.last4))")
                                    HighlightedTypeView(text: acc.type, fadedInk: fadedInk)
                                }
                                Spacer()
                                Text("Bal: $\(String(format: "%.0f", acc.balance))")
                            }
                            if !paidSubs.isEmpty {
                                Text("  PAID SERVICES:").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(fadedInk)
                                ForEach(paidSubs) { sub in
                                    Text("  - \(sub.name): $\(String(format: "%.2f", sub.cost))/\(sub.billingCycle.prefix(2).uppercased())")
                                        .foregroundStyle(fadedInk)
                                    ForEach(sub.subServices.filter { $0.status != .paused }, id: \.id) { ss in
                                        Text("    - \(ss.name): $\(String(format: "%.2f", ss.cost))")
                                            .foregroundStyle(fadedInk)
                                    }
                                }
                            }
                        }
                    }
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(inkColor)
                .padding(.top, 4)
            }
            
            if !instCards.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CARDS (\(instCards.count)):")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                    ForEach(instCards) { card in
                        let paidSubs = subscriptions.filter { $0.paymentMethod == card.name }
                        let networkStr = card.network.isEmpty ? "" : "\(card.network) "
                        let typeStr = card.type == "Credit" ? "Credit Card" : (card.type == "Debit" ? "Debit Card" : card.type)
                        let avail = max(0, card.limit - card.balance)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("- \(card.name) (\(card.last4 ?? "0000"))")
                                    HighlightedTypeView(text: "\(networkStr)\(typeStr)", fadedInk: fadedInk)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Bal: $\(String(format: "%.0f", card.balance))")
                                    if card.type == "Credit" {
                                        Text("Avail: $\(String(format: "%.0f", avail)) | Lim: $\(String(format: "%.0f", card.limit))")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(fadedInk)
                                    }
                                    if card.apr > 0 || card.promoApr > 0 {
                                        HStack(spacing: 0) {
                                            if card.apr > 0 {
                                                Text("APR: \(String(format: "%.1f", card.apr))%")
                                                    .font(.system(size: 9, design: .monospaced))
                                                    .foregroundStyle(fadedInk)
                                            }
                                            if card.promoApr > 0 {
                                                if card.apr > 0 {
                                                    Text(" | ")
                                                        .font(.system(size: 9, design: .monospaced))
                                                        .foregroundStyle(fadedInk)
                                                }
                                                HighlightedTypeView(text: "Promo: \(String(format: "%.1f", card.promoApr))%" + (card.promoEnds != nil ? " until \(card.promoEnds!.formatted(date: .abbreviated, time: .omitted))" : ""), fadedInk: fadedInk, indent: false)
                                            }
                                        }
                                    }
                                }
                            }
                            if !paidSubs.isEmpty {
                                Text("  PAID SERVICES:").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(fadedInk)
                                ForEach(paidSubs) { sub in
                                    Text("  - \(sub.name): $\(String(format: "%.2f", sub.cost))/\(sub.billingCycle.prefix(2).uppercased())")
                                        .foregroundStyle(fadedInk)
                                    ForEach(sub.subServices.filter { $0.status != .paused }, id: \.id) { ss in
                                        Text("    - \(ss.name): $\(String(format: "%.2f", ss.cost))")
                                            .foregroundStyle(fadedInk)
                                    }
                                }
                            }
                        }
                    }
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(inkColor)
                .padding(.top, 4)
            }
            
            if !instLoans.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LOANS (\(instLoans.count)):")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                    ForEach(instLoans) { loan in
                        let paidSubs = subscriptions.filter { $0.paymentMethod == loan.name }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("- \(loan.name)")
                                    if loan.interestRate > 0 {
                                        let rateStr = loan.interestType == "Percentage" ? "\(String(format: "%.2f", loan.interestRate))% APR" : "$\(String(format: "%.2f", loan.interestRate)) Fixed Fee"
                                        Text(rateStr)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(fadedInk)
                                    }
                                }
                                Spacer()
                                Text("Rem: $\(String(format: "%.0f", loan.remainingBalance))")
                            }
                            if !paidSubs.isEmpty {
                                Text("  PAID SERVICES:").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(fadedInk)
                                ForEach(paidSubs) { sub in
                                    Text("  - \(sub.name): $\(String(format: "%.2f", sub.cost))/\(sub.billingCycle.prefix(2).uppercased())")
                                        .foregroundStyle(fadedInk)
                                    ForEach(sub.subServices.filter { $0.status != .paused }, id: \.id) { ss in
                                        Text("    - \(ss.name): $\(String(format: "%.2f", ss.cost))")
                                            .foregroundStyle(fadedInk)
                                    }
                                }
                            }
                        }
                    }
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(inkColor)
                .padding(.top, 4)
            }
        }
    }
    
    private func otherAccountsItem(cards: [FinancialCard], loans: [Loan]) -> some View {
        let orphanedDebt = cards.reduce(0) { $0 + $1.balance } + loans.reduce(0) { $0 + $1.remainingBalance }
        let orphanedCredit = cards.reduce(0) { $0 + $1.limit }
        let orphanedAvailable = max(0, orphanedCredit - cards.reduce(0) { $0 + $1.balance })
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("OTHER ACCOUNTS")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                    Text("\(cards.count + loans.count) ACCOUNTS")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(fadedInk)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(String(format: "%.0f", orphanedDebt))")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                    Text("DEBT")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(fadedInk)
                    
                    if orphanedCredit > 0 {
                        Text("$\(String(format: "%.0f", orphanedAvailable))")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .padding(.top, 4)
                        Text("AVAILABLE CREDIT")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(fadedInk)
                    }
                }
            }
            .foregroundStyle(inkColor)
            
            if !cards.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CARDS (\(cards.count)):")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                    ForEach(cards) { card in
                        let paidSubs = subscriptions.filter { $0.paymentMethod == card.name }
                        let networkStr = card.network.isEmpty ? "" : "\(card.network) "
                        let typeStr = card.type == "Credit" ? "Credit Card" : (card.type == "Debit" ? "Debit Card" : card.type)
                        let avail = max(0, card.limit - card.balance)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("- \(card.name) (\(card.last4 ?? "0000"))")
                                    HighlightedTypeView(text: "\(networkStr)\(typeStr)", fadedInk: fadedInk)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Bal: $\(String(format: "%.0f", card.balance))")
                                    if card.type == "Credit" {
                                        Text("Avail: $\(String(format: "%.0f", avail)) | Lim: $\(String(format: "%.0f", card.limit))")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(fadedInk)
                                    }
                                    if card.apr > 0 || card.promoApr > 0 {
                                        HStack(spacing: 0) {
                                            if card.apr > 0 {
                                                Text("APR: \(String(format: "%.1f", card.apr))%")
                                                    .font(.system(size: 9, design: .monospaced))
                                                    .foregroundStyle(fadedInk)
                                            }
                                            if card.promoApr > 0 {
                                                if card.apr > 0 {
                                                    Text(" | ")
                                                        .font(.system(size: 9, design: .monospaced))
                                                        .foregroundStyle(fadedInk)
                                                }
                                                HighlightedTypeView(text: "Promo: \(String(format: "%.1f", card.promoApr))%" + (card.promoEnds != nil ? " until \(card.promoEnds!.formatted(date: .abbreviated, time: .omitted))" : ""), fadedInk: fadedInk, indent: false)
                                            }
                                        }
                                    }
                                }
                            }
                            if !paidSubs.isEmpty {
                                Text("  PAID SERVICES:").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(fadedInk)
                                ForEach(paidSubs) { sub in
                                    Text("  - \(sub.name): $\(String(format: "%.2f", sub.cost))/\(sub.billingCycle.prefix(2).uppercased())")
                                        .foregroundStyle(fadedInk)
                                    ForEach(sub.subServices.filter { $0.status != .paused }, id: \.id) { ss in
                                        Text("    - \(ss.name): $\(String(format: "%.2f", ss.cost))")
                                            .foregroundStyle(fadedInk)
                                    }
                                }
                            }
                        }
                    }
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(inkColor)
                .padding(.top, 4)
            }
            
            if !loans.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LOANS (\(loans.count)):")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                    ForEach(loans) { loan in
                        let paidSubs = subscriptions.filter { $0.paymentMethod == loan.name }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("- \(loan.name)")
                                    if loan.interestRate > 0 {
                                        let rateStr = loan.interestType == "Percentage" ? "\(String(format: "%.2f", loan.interestRate))% APR" : "$\(String(format: "%.2f", loan.interestRate)) Fixed Fee"
                                        Text(rateStr)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(fadedInk)
                                    }
                                }
                                Spacer()
                                Text("Rem: $\(String(format: "%.0f", loan.remainingBalance))")
                            }
                            if !paidSubs.isEmpty {
                                Text("  PAID SERVICES:").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(fadedInk)
                                ForEach(paidSubs) { sub in
                                    Text("  - \(sub.name): $\(String(format: "%.2f", sub.cost))/\(sub.billingCycle.prefix(2).uppercased())")
                                        .foregroundStyle(fadedInk)
                                    ForEach(sub.subServices.filter { $0.status != .paused }, id: \.id) { ss in
                                        Text("    - \(ss.name): $\(String(format: "%.2f", ss.cost))")
                                            .foregroundStyle(fadedInk)
                                    }
                                }
                            }
                        }
                    }
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(inkColor)
                .padding(.top, 4)
            }
        }
    }
    
    private var receiptFooter: some View {
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("TOTAL MONTHLY SERVICES")
                    Spacer()
                    Text("$\(String(format: "%.2f", totalSubscriptionCost))")
                }
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                
                if totalSubscriptionCost > 0 {
                    let paymentMethods = Set(subscriptions.map { $0.paymentMethod ?? "UNASSIGNED" })
                    ForEach(Array(paymentMethods).sorted(), id: \.self) { pm in
                        let pmSubs = subscriptions.filter { ($0.paymentMethod ?? "UNASSIGNED") == pm }
                        
                        let yearlySubsCount = pmSubs.filter { $0.billingCycle == "Yearly" }.count
                        let yearlyExtrasCount = pmSubs.filter { $0.billingCycle == "Yearly" }.reduce(0) { $0 + $1.subServices.filter { ss in ss.status != .paused }.count }
                        let totalYearlyCount = yearlySubsCount + yearlyExtrasCount
                        
                        let monthlySubsCount = pmSubs.filter { $0.billingCycle != "Yearly" }.count
                        let monthlyExtrasCount = pmSubs.filter { $0.billingCycle != "Yearly" }.reduce(0) { $0 + $1.subServices.filter { ss in ss.status != .paused }.count }
                        let totalMonthlyCount = monthlySubsCount + monthlyExtrasCount
                        
                        let pmTotal = pmSubs.reduce(0) { total, sub in
                            let subMonthlyCost = sub.billingCycle == "Yearly" ? sub.cost / 12.0 : sub.cost
                            let extrasMonthlyCost = sub.subServices.filter { $0.status != .paused }.reduce(0) { sum, ss in
                                let ssMonthlyCost = ss.billingCycle == .yearly ? ss.cost / 12.0 : ss.cost
                                return sum + ssMonthlyCost
                            }
                            return total + subMonthlyCost + extrasMonthlyCost
                        }
                        
                        if pmTotal > 0 {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text("  - \(pm.uppercased())")
                                    Spacer()
                                    Text("$\(String(format: "%.2f", pmTotal))")
                                }
                                
                                ForEach(pmSubs) { sub in
                                    let subCycle = sub.billingCycle == "Yearly" ? " yearly" : ""
                                    Text("    (1) \(sub.name)\(subCycle)")
                                    
                                    ForEach(sub.subServices.filter { $0.status != .paused }, id: \.id) { ss in
                                        let ssCycle = ss.billingCycle == .yearly ? " yearly" : ""
                                        Text("      (1) \(ss.name)\(ssCycle)")
                                    }
                                }
                            }
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(fadedInk)
                        }
                    }
                }
            }
            
            dashedDivider
            
            HStack(alignment: .firstTextBaseline) {
                Text("TOTAL DEBT")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                Spacer()
                Text("Avail CR: $\(String(format: "%.0f", availableCredit))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(fadedInk)
                Text("$\(String(format: "%.2f", totalDebt))")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
            }
            
            if totalCreditLimit > 0 {
                let debtRatio = min(1.0, totalDebt / totalCreditLimit)
                HStack {
                    Text("DEBT-TO-CREDIT RATIO")
                    Spacer()
                    Text("\(Int(debtRatio * 100))%")
                }
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(fadedInk)
            }
            
            Text("END OF REPORT")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .padding(.top, 16)
        }
        .foregroundStyle(inkColor)
    }
}

struct HighlightedTypeView: View {
    let text: String
    let fadedInk: Color
    var indent: Bool = true
    
    @State private var drawHighlight = false
    
    var body: some View {
        HStack(spacing: 0) {
            if indent {
                Text("  ")
                    .font(.system(size: 9, design: .monospaced))
            }
            
            Text(text)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(fadedInk)
                .background(alignment: .leading) {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.yellow.opacity(0.4))
                            .frame(width: drawHighlight ? geo.size.width + 4 : 0)
                            .offset(x: -2)
                            .animation(.easeInOut(duration: 0.6).delay(Double.random(in: 0.2...0.5)), value: drawHighlight)
                    }
                }
                .onAppear {
                    drawHighlight = true
                }
        }
    }
}
