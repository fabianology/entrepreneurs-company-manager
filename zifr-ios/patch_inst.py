import re

with open("Zifr/Views/Financial/FinancialView.swift", "r") as f:
    content = f.read()

# 1. Replace VStack with MiloomListCard
content = content.replace('''    var body: some View {
        VStack(spacing: 0) {
            // ── Tappable header (triggers edit sheet) ──────────────────────''', '''    var body: some View {
        MiloomListCard {
            // ── Tappable header (triggers edit sheet) ──────────────────────''')

# 2. Replace accordion toggles
content = content.replace('''            // ── Accordion ──────────────────────────────────────────────────
            accordionDivider()
            accordionToggle(label: expanded ? "Hide Accounts" : "Loans & Accounts", count: institution.accounts.count + loanCount, expanded: expanded) {
                withAnimation(.spring(response: 0.35)) { expanded.toggle() }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .zIndex(1)
            
            if expanded {''', '''            // ── Accordion ──────────────────────────────────────────────────
            MiloomAccordion(title: expanded ? "Hide Accounts" : "Loans & Accounts", count: institution.accounts.count + loanCount, expanded: expanded, action: {
                withAnimation(.spring(response: 0.35)) { expanded.toggle() }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {''')

# 3. Remove clipping and padding at the end of accordion, and the background modifiers
content = content.replace('''                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .clipped()
            }
        }
        .background(Color(hex: "#1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.05), lineWidth: 1))''', '''            }
        }''')

with open("Zifr/Views/Financial/FinancialView.swift", "w") as f:
    f.write(content)
