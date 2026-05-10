import sys

with open("Zifr/Views/Company/EntityHomeView.swift", "r") as f:
    content = f.read()

# 1. Remove APR from the leading VStack (network row)
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

clean_network_row = """                                    HighlightedTypeView(text: "\\(networkStr)\\(typeStr)", fadedInk: fadedInk)
                                }"""

content = content.replace(network_row_with_apr, clean_network_row)

# 2. Add APR to the trailing VStack (balance / avail row)
clean_trailing = """                                    if card.type == "Credit" {
                                        Text("Avail: $\\(String(format: "%.0f", avail)) | Lim: $\\(String(format: "%.0f", card.limit))")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(fadedInk)
                                    }"""

apr_code_trailing = """                                    if card.type == "Credit" {
                                        Text("Avail: $\\(String(format: "%.0f", avail)) | Lim: $\\(String(format: "%.0f", card.limit))")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(fadedInk)
                                    }
                                    if card.apr > 0 || card.promoApr > 0 {
                                        HStack(spacing: 0) {
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

content = content.replace(clean_trailing, apr_code_trailing)

with open("Zifr/Views/Company/EntityHomeView.swift", "w") as f:
    f.write(content)
