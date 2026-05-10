import sys

with open("Zifr/Views/Company/EntityHomeView.swift", "r") as f:
    content = f.read()

# 1. Update the loop for "yearly"
old_loop = """                                ForEach(pmSubs) { sub in
                                    Text("    (1) \\(sub.name)")
                                    
                                    ForEach(sub.subServices.filter { $0.status != .paused }, id: \\.id) { ss in
                                        Text("      (1) \\(ss.name)")
                                    }
                                }"""

new_loop = """                                ForEach(pmSubs) { sub in
                                    let subCycle = sub.billingCycle == "Yearly" ? " yearly" : ""
                                    Text("    (1) \\(sub.name)\\(subCycle)")
                                    
                                    ForEach(sub.subServices.filter { $0.status != .paused }, id: \\.id) { ss in
                                        let ssCycle = ss.billingCycle == .yearly ? " yearly" : ""
                                        Text("      (1) \\(ss.name)\\(ssCycle)")
                                    }
                                }"""

content = content.replace(old_loop, new_loop)


# 2. Update the total debt / available credit section
old_debt = """            HStack {
                Text("TOTAL DEBT")
                Spacer()
                Text("$\\(String(format: "%.2f", totalDebt))")
            }
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            
            HStack {
                Text("AVAILABLE CREDIT")
                Spacer()
                Text("$\\(String(format: "%.2f", availableCredit))")
            }
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(fadedInk)"""

new_debt = """            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL DEBT")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                    Text("AVAIL CREDIT: $\\(String(format: "%.2f", availableCredit))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(fadedInk)
                }
                Spacer()
                Text("$\\(String(format: "%.2f", totalDebt))")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
            }"""

content = content.replace(old_debt, new_debt)

with open("Zifr/Views/Company/EntityHomeView.swift", "w") as f:
    f.write(content)
