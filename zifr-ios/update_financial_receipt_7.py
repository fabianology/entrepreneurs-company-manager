import sys

with open("Zifr/Views/Company/EntityHomeView.swift", "r") as f:
    content = f.read()

old_debt = """            HStack(alignment: .bottom) {
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

new_debt = """            HStack(alignment: .firstTextBaseline) {
                Text("TOTAL DEBT")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                Spacer()
                Text("Avail CR: $\\(String(format: "%.0f", availableCredit))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(fadedInk)
                Text("$\\(String(format: "%.2f", totalDebt))")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
            }"""

content = content.replace(old_debt, new_debt)

with open("Zifr/Views/Company/EntityHomeView.swift", "w") as f:
    f.write(content)
