import SwiftUI

struct SubscriptionReceiptView: View {
    let company: Company
    let subscriptions: [Subscription]
    let institutions: [Institution]
    let cards: [FinancialCard]
    
    @Environment(\.dismiss) private var dismiss
    
    private var activeSubscriptions: [Subscription] {
        subscriptions.filter { $0.status == "Active" }
    }
    
    private var totalMonthlyBurn: Double {
        activeSubscriptions.reduce(0.0) { acc, sub in
            let base = sub.billingCycle == "Monthly" ? sub.cost : sub.cost / 12
            let extras = sub.subServices.filter { $0.status != .paused }.reduce(0.0) { $0 + $1.cost }
            return acc + base + extras
        }
    }
    
    private var totalAnnualBurn: Double {
        totalMonthlyBurn * 12
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
                        
                        ForEach(activeSubscriptions) { sub in
                            subscriptionItem(sub: sub)
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
            Text("ZIFR COMMAND CENTER")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
            Text("SUBSCRIPTION REPORT")
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
    
    private func subscriptionItem(sub: Subscription) -> some View {
        let baseCost = sub.billingCycle == "Monthly" ? sub.cost : sub.cost / 12
        let extras = sub.subServices.filter { $0.status != .paused }.reduce(0.0) { $0 + $1.cost }
        let totalSubMonthly = baseCost + extras
        let impactPct = totalMonthlyBurn > 0 ? (totalSubMonthly / totalMonthlyBurn) * 100 : 0
        
        let bankTuple = getBankAccountTuple(for: sub)
        
        return VStack(alignment: .leading, spacing: 10) {
            // Title & Cost
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sub.name.uppercased())
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                    if sub.isFree {
                        Text("FREE TIER")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(fadedInk)
                    } else {
                        Text("$\(String(format: "%.2f", sub.cost)) / \(sub.billingCycle.prefix(2).uppercased())")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(fadedInk)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f%%", impactPct))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                    Text("IMPACT")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(fadedInk)
                }
            }
            .foregroundStyle(inkColor)
            
            // Payment & Auto-pay Context
            if !sub.isFree {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        Text("PAID FROM:").frame(width: 80, alignment: .leading)
                        if let b = bankTuple {
                            Text("\(b.bank) • \(b.account)")
                        } else {
                            Text(sub.paymentMethod ?? "UNKNOWN")
                        }
                    }
                    HStack(alignment: .top) {
                        Text("AUTO-PAY:").frame(width: 80, alignment: .leading)
                        Text(sub.renew == "Manual" ? "NO" : "YES")
                    }
                    HStack(alignment: .top) {
                        Text("NEXT DUE:").frame(width: 80, alignment: .leading)
                        Text(sub.nextRenewal ?? "—")
                    }
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(fadedInk)
            }
            
            // Supplemental Services
            if !sub.subServices.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SUPPLEMENTAL SERVICES (\(sub.subServices.count)):")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                    ForEach(sub.subServices.indices, id: \.self) { i in
                        let ss = sub.subServices[i]
                        HStack {
                            Text("- \(ss.name)")
                            Spacer()
                            Text("$\(String(format: "%.0f", ss.cost))")
                        }
                    }
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(inkColor)
                .padding(.top, 2)
            }
            
            // Linked Emails
            if !sub.linkedEmails.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LINKED EMAILS (\(sub.linkedEmails.count)):")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                    ForEach(sub.linkedEmails.indices, id: \.self) { i in
                        let le = sub.linkedEmails[i]
                        VStack(alignment: .leading, spacing: 2) {
                            Text("- \(le.email)")
                            if !le.usedFor.isEmpty {
                                Text("  PURPOSE: \(le.usedFor)").foregroundStyle(fadedInk)
                            }
                            if !le.notes.isEmpty {
                                Text("  NOTES: \(le.notes)").foregroundStyle(fadedInk)
                            }
                        }
                    }
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(inkColor)
                .padding(.top, 2)
            }
        }
    }
    
    private var receiptFooter: some View {
        VStack(spacing: 8) {
            HStack {
                Text("TOTAL MONTHLY BURN")
                Spacer()
                Text("$\(String(format: "%.2f", totalMonthlyBurn))")
            }
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            
            HStack {
                Text("EST. ANNUAL BURN")
                Spacer()
                Text("$\(String(format: "%.2f", totalAnnualBurn))")
            }
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(fadedInk)
            
            Text("END OF REPORT")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .padding(.top, 16)
        }
        .foregroundStyle(inkColor)
    }
    
    // MARK: - Helpers
    
    private func getBankAccountTuple(for sub: Subscription) -> (bank: String, account: String)? {
        if (sub.paymentMethod ?? "").isEmpty { return nil }
        
        if let card = cards.first(where: { $0.name == sub.paymentMethod }) {
            let inst = (card.institutionName ?? "").isEmpty ? "Paid From" : card.institutionName!
            let suffix = (card.last4 ?? "").isEmpty ? "" : " ••••\(card.last4 ?? "")"
            return (inst, "\(card.name)\(suffix)")
        }
        
        for inst in institutions {
            if let acc = inst.accounts.first(where: { ($0.name.isEmpty ? $0.type : $0.name) == sub.paymentMethod }) {
                let instName = inst.name.isEmpty ? "Paid From" : inst.name
                let accName = acc.name.isEmpty ? acc.type : acc.name
                let suffix = (acc.last4 ?? "").isEmpty ? "" : " ••••\(acc.last4 ?? "")"
                return (instName, "\(accName)\(suffix)")
            }
        }
        return nil
    }
}
