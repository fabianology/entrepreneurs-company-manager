import sys

with open("Zifr/Views/Company/EntityHomeView.swift", "r") as f:
    content = f.read()

# First, remove APR from the trailing VStack
apr_code_trailing = """                                    if card.type == "Credit" {
                                        Text("Avail: $\\(String(format: "%.0f", avail)) | Lim: $\\(String(format: "%.0f", card.limit))")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(fadedInk)
                                    }
                                    if card.apr > 0 || card.promoApr > 0 {
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

clean_trailing = """                                    if card.type == "Credit" {
                                        Text("Avail: $\\(String(format: "%.0f", avail)) | Lim: $\\(String(format: "%.0f", card.limit))")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(fadedInk)
                                    }"""

content = content.replace(apr_code_trailing, clean_trailing)

# Now, add APR to the leading VStack under network row
network_row = """                                    HighlightedTypeView(text: "\\(networkStr)\\(typeStr)", fadedInk: fadedInk)
                                }"""

network_row_with_apr = """                                    HighlightedTypeView(text: "\\(networkStr)\\(typeStr)", fadedInk: fadedInk)
                                    if card.apr > 0 || card.promoApr > 0 {
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
                                    }
                                }"""

content = content.replace(network_row, network_row_with_apr)

# Now update the footer to separate subscriptions and supplemental services
footer_old = """                        if pmTotal > 0 {
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
                        }"""

footer_new = """                        if pmTotal > 0 {
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

content = content.replace(footer_old, footer_new)

with open("Zifr/Views/Company/EntityHomeView.swift", "w") as f:
    f.write(content)
