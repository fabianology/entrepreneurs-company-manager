import sys

with open("Zifr/Views/Company/EntityHomeView.swift", "r") as f:
    content = f.read()

# For cards in institutionItem and otherAccountsItem
# In both places we have:
#                                     if card.type == "Credit" {
#                                         Text("Avail: $\(String(format: "%.0f", avail)) | Lim: $\(String(format: "%.0f", card.limit))")
#                                             .font(.system(size: 9, design: .monospaced))
#                                             .foregroundStyle(fadedInk)
#                                     }

card_apr_code = """                                    if card.type == "Credit" {
                                        Text("Avail: $\\(String(format: "%.0f", avail)) | Lim: $\\(String(format: "%.0f", card.limit))")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(fadedInk)
                                    }
                                    if card.apr > 0 || card.promoApr > 0 {
                                        let aprStr = card.apr > 0 ? "APR: \\(String(format: "%.1f", card.apr))%" : ""
                                        let promoStr = card.promoApr > 0 ? "Promo: \\(String(format: "%.1f", card.promoApr))%" : ""
                                        let endsStr = (card.promoApr > 0 && card.promoEnds != nil) ? " until \\(card.promoEnds!.formatted(date: .abbreviated, time: .omitted))" : ""
                                        let combined = [aprStr, promoStr.isEmpty ? "" : "\\(promoStr)\\(endsStr)"].filter { !$0.isEmpty }.joined(separator: " | ")
                                        Text(combined)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(fadedInk)
                                    }"""

content = content.replace("""                                    if card.type == "Credit" {
                                        Text("Avail: $\\(String(format: "%.0f", avail)) | Lim: $\\(String(format: "%.0f", card.limit))")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(fadedInk)
                                    }""", card_apr_code)

# For loans in institutionItem and otherAccountsItem
#                             HStack {
#                                 Text("- \\(loan.name)")
#                                 Spacer()
#                                 Text("Rem: $\\(String(format: "%.0f", loan.remainingBalance))")
#                             }

loan_apr_code = """                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("- \\(loan.name)")
                                    if loan.interestRate > 0 {
                                        let rateStr = loan.interestType == "Percentage" ? "\\(String(format: "%.2f", loan.interestRate))% APR" : "$\\(String(format: "%.2f", loan.interestRate)) Fixed Fee"
                                        Text(rateStr)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(fadedInk)
                                    }
                                }
                                Spacer()
                                Text("Rem: $\\(String(format: "%.0f", loan.remainingBalance))")
                            }"""

content = content.replace("""                            HStack {
                                Text("- \\(loan.name)")
                                Spacer()
                                Text("Rem: $\\(String(format: "%.0f", loan.remainingBalance))")
                            }""", loan_apr_code)


# Footer breakdown
#             HStack {
#                 Text("TOTAL MONTHLY SERVICES")
#                 Spacer()
#                 Text("$\\(String(format: "%.2f", totalSubscriptionCost))")
#             }
#             .font(.system(size: 14, weight: .bold, design: .monospaced))

footer_code = """            VStack(alignment: .leading, spacing: 4) {
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

content = content.replace("""            HStack {
                Text("TOTAL MONTHLY SERVICES")
                Spacer()
                Text("$\\(String(format: "%.2f", totalSubscriptionCost))")
            }
            .font(.system(size: 14, weight: .bold, design: .monospaced))""", footer_code)

with open("Zifr/Views/Company/EntityHomeView.swift", "w") as f:
    f.write(content)
