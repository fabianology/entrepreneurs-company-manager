import sys

with open("Zifr/Views/Company/EntityHomeView.swift", "r") as f:
    content = f.read()

# Update the totalSubscriptionCost
cost_old = """    private var totalSubscriptionCost: Double {
        subscriptions.reduce(0) { total, sub in
            let extrasCost = sub.subServices.filter { $0.status != .paused }.reduce(0) { $0 + $1.cost }
            let totalSubCost = sub.cost + extrasCost
            let monthlyCost = sub.billingCycle == "Yearly" ? totalSubCost / 12.0 : totalSubCost
            return total + monthlyCost
        }
    }"""

cost_new = """    private var totalSubscriptionCost: Double {
        subscriptions.reduce(0) { total, sub in
            let subMonthlyCost = sub.billingCycle == "Yearly" ? sub.cost / 12.0 : sub.cost
            let extrasMonthlyCost = sub.subServices.filter { $0.status != .paused }.reduce(0) { sum, ss in
                let ssMonthlyCost = ss.billingCycle == .yearly ? ss.cost / 12.0 : ss.cost
                return sum + ssMonthlyCost
            }
            return total + subMonthlyCost + extrasMonthlyCost
        }
    }"""

content = content.replace(cost_old, cost_new)

# Update the footer loop
footer_old = """                        let pmTotal = pmSubs.reduce(0) { total, sub in
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
                                
                                ForEach(pmSubs) { sub in
                                    let subCycle = sub.billingCycle.lowercased()
                                    Text("    (1) \\(sub.name) \\(subCycle) subscription")
                                    
                                    ForEach(sub.subServices.filter { $0.status != .paused }, id: \\.id) { ss in
                                        Text("      (1) \\(ss.name) monthly supplemental service")
                                    }
                                }
                            }
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(fadedInk)
                        }"""

footer_new = """                        let pmTotal = pmSubs.reduce(0) { total, sub in
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
                                    Text("  - \\(pm.uppercased())")
                                    Spacer()
                                    Text("$\\(String(format: "%.2f", pmTotal))")
                                }
                                
                                ForEach(pmSubs) { sub in
                                    Text("    (1) \\(sub.name)")
                                    
                                    ForEach(sub.subServices.filter { $0.status != .paused }, id: \\.id) { ss in
                                        Text("      (1) \\(ss.name)")
                                    }
                                }
                            }
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(fadedInk)
                        }"""

content = content.replace(footer_old, footer_new)

with open("Zifr/Views/Company/EntityHomeView.swift", "w") as f:
    f.write(content)
