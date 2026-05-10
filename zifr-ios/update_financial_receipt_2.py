import sys

with open("Zifr/Views/Company/EntityHomeView.swift", "r") as f:
    content = f.read()

# Update HighlightedTypeView to accept indent
content = content.replace(
"""struct HighlightedTypeView: View {
    let text: String
    let fadedInk: Color
    
    @State private var drawHighlight = false
    
    var body: some View {
        HStack(spacing: 0) {
            Text("  ")
                .font(.system(size: 9, design: .monospaced))
            
            Text(text)""",
"""struct HighlightedTypeView: View {
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
            
            Text(text)"""
)

# Update the totalSubscriptionCost to handle yearly
content = content.replace(
"""    private var totalSubscriptionCost: Double {
        subscriptions.reduce(0) { total, sub in
            let extrasCost = sub.subServices.filter { $0.status != .paused }.reduce(0) { $0 + $1.cost }
            return total + sub.cost + extrasCost
        }
    }""",
"""    private var totalSubscriptionCost: Double {
        subscriptions.reduce(0) { total, sub in
            let extrasCost = sub.subServices.filter { $0.status != .paused }.reduce(0) { $0 + $1.cost }
            let totalSubCost = sub.cost + extrasCost
            let monthlyCost = sub.billingCycle == "Yearly" ? totalSubCost / 12.0 : totalSubCost
            return total + monthlyCost
        }
    }""")

# Update footer layout
footer_old = """            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("TOTAL MONTHLY SERVICES")
                    Spacer()
                    Text("$\\(String(format: "%.2f", totalSubscriptionCost))")
                }
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                
                if totalSubscriptionCost > 0 {
                    let paymentMethods = Set(subscriptions.map { $0.paymentMethod ?? "UNASSIGNED" })
                    ForEach(Array(paymentMethods).sorted(), id: \\.self) { pm in
                        let pmTotal = subscriptions.filter { ($0.paymentMethod ?? "UNASSIGNED") == pm }.reduce(0) { total, sub in
                            let extras = sub.subServices.filter { $0.status != .paused }.reduce(0) { $0 + $1.cost }
                            return total + sub.cost + extras
                        }
                        if pmTotal > 0 {
                            HStack {
                                Text("  - \\(pm.uppercased())")
                                Spacer()
                                Text("$\\(String(format: "%.2f", pmTotal))")
                            }
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(fadedInk)
                        }
                    }
                }
            }"""

footer_new = """            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("TOTAL MONTHLY SERVICES")
                    Spacer()
                    Text("$\\(String(format: "%.2f", totalSubscriptionCost))")
                }
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                
                if totalSubscriptionCost > 0 {
                    let paymentMethods = Set(subscriptions.map { $0.paymentMethod ?? "UNASSIGNED" })
                    ForEach(Array(paymentMethods).sorted(), id: \\.self) { pm in
                        let pmSubs = subscriptions.filter { ($0.paymentMethod ?? "UNASSIGNED") == pm }
                        
                        let yearlySubsCount = pmSubs.filter { $0.billingCycle == "Yearly" }.count
                        let yearlyExtrasCount = pmSubs.filter { $0.billingCycle == "Yearly" }.reduce(0) { $0 + $1.subServices.filter { ss in ss.status != .paused }.count }
                        let totalYearlyCount = yearlySubsCount + yearlyExtrasCount
                        
                        let monthlySubsCount = pmSubs.filter { $0.billingCycle != "Yearly" }.count
                        let monthlyExtrasCount = pmSubs.filter { $0.billingCycle != "Yearly" }.reduce(0) { $0 + $1.subServices.filter { ss in ss.status != .paused }.count }
                        let totalMonthlyCount = monthlySubsCount + monthlyExtrasCount
                        
                        let pmTotal = pmSubs.reduce(0) { total, sub in
                            let extras = sub.subServices.filter { $0.status != .paused }.reduce(0) { $0 + $1.cost }
                            let totalSubCost = sub.cost + extras
                            let monthlyCost = sub.billingCycle == "Yearly" ? totalSubCost / 12.0 : totalSubCost
                            return total + monthlyCost
                        }
                        
                        if pmTotal > 0 {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text("  - \\(pm.uppercased())")
                                    Spacer()
                                    Text("$\\(String(format: "%.2f", pmTotal))")
                                }
                                if totalYearlyCount > 0 {
                                    Text("    (\\(totalYearlyCount)) yearly sub/supplemental service")
                                }
                                if totalMonthlyCount > 0 {
                                    Text("    (\\(totalMonthlyCount)) monthly subscription")
                                }
                            }
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(fadedInk)
                        }
                    }
                }
            }
            
            dashedDivider"""

content = content.replace(footer_old, footer_new)

# Update card apr to highlight promo
apr_old = """                                    if card.apr > 0 || card.promoApr > 0 {
                                        let aprStr = card.apr > 0 ? "APR: \\(String(format: "%.1f", card.apr))%" : ""
                                        let promoStr = card.promoApr > 0 ? "Promo: \\(String(format: "%.1f", card.promoApr))%" : ""
                                        let endsStr = (card.promoApr > 0 && card.promoEnds != nil) ? " until \\(card.promoEnds!.formatted(date: .abbreviated, time: .omitted))" : ""
                                        let combined = [aprStr, promoStr.isEmpty ? "" : "\\(promoStr)\\(endsStr)"].filter { !$0.isEmpty }.joined(separator: " | ")
                                        Text(combined)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(fadedInk)
                                    }"""

apr_new = """                                    if card.apr > 0 || card.promoApr > 0 {
                                        HStack(spacing: 0) {
                                            Text("  ")
                                                .font(.system(size: 9, design: .monospaced))
                                            if card.apr > 0 {
                                                Text("APR: \\(String(format: "%.1f", card.apr))%")
                                                    .font(.system(size: 9, design: .monospaced))
                                                    .foregroundStyle(fadedInk)
                                            }
                                            if card.promoApr > 0 {
                                                if card.apr > 0 {
                                                    Text(" | ")
                                                        .font(.system(size: 9, design: .monospaced))
                                                        .foregroundStyle(fadedInk)
                                                }
                                                HighlightedTypeView(text: "Promo: \\(String(format: "%.1f", card.promoApr))%" + (card.promoEnds != nil ? " until \\(card.promoEnds!.formatted(date: .abbreviated, time: .omitted))" : ""), fadedInk: fadedInk, indent: false)
                                            }
                                        }
                                    }"""

content = content.replace(apr_old, apr_new)

with open("Zifr/Views/Company/EntityHomeView.swift", "w") as f:
    f.write(content)
