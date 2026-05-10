import re

with open("Zifr/Views/Financial/FinancialView.swift", "r") as f:
    content = f.read()

# 1. Update copyableCredential label
content = content.replace('''                Text(isCopied ? "Copied ✓" : label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isCopied ? Color.orange : Color.white.opacity(0.5))''', '''                Text(isCopied ? "Copied ✓" : label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isCopied ? Color.orange : Color.white.opacity(0.5))
                    .textCase(.uppercase)''')

# 2. Update copyableCredential button
content = content.replace('''                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.05), lineWidth: 1))
            }
            .buttonStyle(.plain)''', '''                .background(Color(hex: "#2C2C2E"))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
            }
            .buttonStyle(PremiumButtonStyle())''')

# 3. Update the header button
content = content.replace('''                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ── Accordion ──────────────────────────────────────────────────''', '''                .contentShape(Rectangle())
            }
            .buttonStyle(PremiumButtonStyle())

            // ── Accordion ──────────────────────────────────────────────────''')

# 4. Update the account and loan buttons (inside the accordion loop)
content = content.replace('''                            .padding(.vertical, 12)
                            .background(Color(hex: "#2C2C2E"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.05), lineWidth: 1))
                        }
                        .buttonStyle(.plain)''', '''                            .padding(.vertical, 12)
                            .background(Color(hex: "#2C2C2E"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        }
                        .buttonStyle(PremiumButtonStyle())''')


with open("Zifr/Views/Financial/FinancialView.swift", "w") as f:
    f.write(content)
