import SwiftUI

struct FinancialView: View {
    let company: Company
    let cards: [FinancialCard]
    let institutions: [Institution]
    let loans: [Loan]
    @Bindable var vm: AppViewModel
    @Environment(\.modelContext) private var context

    @State private var editingCard: FinancialCard? = nil
    @State private var editingInst: Institution? = nil
    @State private var editingLoan: Loan? = nil
    @State private var newCard: FinancialCard? = nil
    @State private var newInst: Institution? = nil
    @State private var newLoan: Loan? = nil
    @State private var poppedCardId: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // ── Action Bar ──
                HStack(spacing: 8) {
                    actionButton(icon: "plus", label: "Card") {
                        newCard = vm.addCard(context: context, companyId: company.id)
                    }
                    actionButton(icon: "plus", label: "Loan") {
                        newLoan = vm.addLoan(context: context, companyId: company.id)
                    }
                    Spacer()
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        newInst = vm.addInstitution(context: context, companyId: company.id)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundStyle(Color(hex: "#A2A2A2"))
                            Text("Institution").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(hex: "#A2A2A2"))
                        }
                        .padding(.horizontal, 18)
                        .frame(height: 36)
                        .background(Color(hex: "#222E2F"))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
                .padding(.bottom, 24)
                
                // ── Main Wallet Stack ──
                LazyVStack(spacing: 24) {
                    if institutions.isEmpty && cards.isEmpty && loans.isEmpty {
                        // Empty State
                        Button {
                            newInst = vm.addInstitution(context: context, companyId: company.id)
                        } label: {
                            VStack(spacing: 12) {
                                Text("🏦").font(.system(size: 40))
                                Text("+ Add Your First Institution")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.5))
                            }
                            .frame(width: 300, height: 200)
                            .background(Color(hex: "#171717").opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [6])))
                        }
                        .padding(.top, 20)
                    } else {
                        // Institutions Block
                        if !institutions.isEmpty {
                                ForEach(institutions) { inst in
                                    let instCards = cards.filter { $0.institutionName.lowercased() == inst.name.lowercased() }
                                    let instLoans = loans.filter { $0.lender.lowercased() == inst.name.lowercased() }
                                    walletStackForInstitution(inst: inst, instCards: instCards, instLoans: instLoans)
                                }
                            }
                        
                        // Remaining standalone accounts block
                        let standaloneCards = cards.filter { c in !institutions.contains { $0.name.lowercased() == c.institutionName.lowercased() } }
                        let standaloneLoans = loans.filter { l in !institutions.contains { $0.name.lowercased() == l.lender.lowercased() } }
                        
                        if !standaloneCards.isEmpty || !standaloneLoans.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Other Standalone Accounts")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.3))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 24)
                                    .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.white.opacity(0.08)), alignment: .top)
                                
                                standaloneWalletStack(cards: standaloneCards)
                                ForEach(standaloneLoans) { loan in
                                    LoanCardView(loan: loan, onEdit: { editingLoan = loan })
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            }
        }
        .scrollIndicators(.hidden)
        .sheet(item: $newInst) { i in EditInstitutionSheet(institution: i, cards: cards, loans: loans, vm: vm, isNew: true) }
        .sheet(item: $editingInst) { i in EditInstitutionSheet(institution: i, cards: cards, loans: loans, vm: vm, isNew: false) }
        .sheet(item: $newCard) { c in EditCardSheet(card: c, vm: vm, isNew: true) }
        .sheet(item: $editingCard) { c in EditCardSheet(card: c, vm: vm, isNew: false) }
        .sheet(item: $newLoan) { l in EditLoanSheet(loan: l, vm: vm, isNew: true) }
        .sheet(item: $editingLoan) { l in EditLoanSheet(loan: l, vm: vm, isNew: false) }
    }
    
    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(Color.white.opacity(0.4))
                Text(label).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            }
            .padding(.horizontal, 18)
            .frame(height: 36)
            .background(Color(hex: "#171717"))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }
    
    @ViewBuilder
    private func walletStackForInstitution(inst: Institution, instCards: [FinancialCard], instLoans: [Loan]) -> some View {
        let peekOffset: CGFloat = 36
        let cardH: CGFloat = 110
        let fullCardH: CGFloat = 210
        
        ZStack(alignment: .top) {
            if !instCards.isEmpty {
                ForEach(Array(instCards.enumerated()), id: \.element.id) { index, card in
                        let isPopped = poppedCardId == card.id
                        let yOffset = isPopped ? 16.0 : -(peekOffset + CGFloat(index) * peekOffset)
                        let scale = isPopped ? 1.0 : max(0.85, 1.0 - CGFloat(index) * 0.03)
                        
                        FinancialCardVisual(card: card, isPopped: isPopped)
                            .frame(height: isPopped ? fullCardH : cardH)
                            .scaleEffect(scale)
                            .offset(y: yOffset)
                            .zIndex(isPopped ? 25 : Double(instCards.count - index))
                            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isPopped)
                            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: poppedCardId)
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                if poppedCardId == card.id { poppedCardId = nil } else { poppedCardId = card.id }
                            }
                            .onLongPressGesture {
                                editingCard = card
                            }
                    }
            }
            
            InstitutionCardView(
                institution: inst,
                totalMonthlyPayment: instLoans.reduce(0) { $0 + $1.monthlyPayment },
                cardCount: instCards.count,
                loanCount: instLoans.count,
                onEdit: { editingInst = inst }
            )
            .zIndex(20)
        }
        .padding(.top, instCards.isEmpty ? 0 : CGFloat(instCards.count) * peekOffset + 16)
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private func standaloneWalletStack(cards: [FinancialCard]) -> some View {
        let peekOffset: CGFloat = 36
        let cardH: CGFloat = 110
        let fullCardH: CGFloat = 210
        
        if !cards.isEmpty {
            ZStack(alignment: .bottom) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    let isPopped = poppedCardId == card.id
                    let yOffset = isPopped ? 0.0 : -(CGFloat(index) * peekOffset)
                    let scale = isPopped ? 1.0 : max(0.85, 1.0 - CGFloat(index) * 0.03)
                    
                    FinancialCardVisual(card: card, isPopped: isPopped)
                        .frame(height: isPopped ? fullCardH : cardH)
                        .scaleEffect(scale)
                        .offset(y: yOffset)
                        .zIndex(isPopped ? 25 : Double(cards.count - index))
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isPopped)
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: poppedCardId)
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if poppedCardId == card.id { poppedCardId = nil } else { poppedCardId = card.id }
                        }
                        .onLongPressGesture {
                            editingCard = card
                        }
                }
            }
            .padding(.top, CGFloat(cards.count) * peekOffset + 8)
            .padding(.bottom, 16)
        }
    }
}

// ── Shared Card Visual (Mini overlapping view for stack) ──
struct FinancialCardVisual: View {
    let card: FinancialCard
    let isPopped: Bool
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: card.colorHex))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(isPopped ? Color.white.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
            
            let isLight = card.colorHex.uppercased() == "#FFFFFF"
            let primaryColor = isLight ? Color.black : Color.white
            let secondaryColor = isLight ? Color.black.opacity(0.7) : Color.white.opacity(0.7)
            
            VStack {
                HStack(alignment: .top) {
                    Text(card.name.isEmpty ? "Card" : card.name)
                        .font(.system(size: isPopped ? 16 : 12, weight: .bold))
                        .foregroundStyle(primaryColor)
                    Spacer()
                    Text(card.network)
                        .font(.system(size: isPopped ? 16 : 12, weight: .semibold))
                        .foregroundStyle(secondaryColor)
                        .italic()
                }
                Spacer()
                if isPopped {
                    Text("•••• •••• •••• \(card.last4)")
                        .font(.system(size: 18, weight: .regular, design: .monospaced))
                        .foregroundStyle(isLight ? Color.black.opacity(0.85) : Color.white.opacity(0.85))
                        .tracking(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 12)
                    
                    HStack {
                        Text(card.cardHolder.isEmpty ? "Name on Card" : card.cardHolder)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(isLight ? Color.black.opacity(0.6) : Color.white.opacity(0.6))
                        Spacer()
                        Text(card.expiry.isEmpty ? "—" : card.expiry)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(isLight ? Color.black.opacity(0.6) : Color.white.opacity(0.6))
                    }
                }
            }
            .padding(isPopped ? 24 : 14)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Institution Card
struct InstitutionCardView: View {
    let institution: Institution
    let totalMonthlyPayment: Double
    let cardCount: Int
    let loanCount: Int
    let onEdit: () -> Void
    @State private var expanded = false
    @State private var copiedField: String? = nil
    @State private var passwordRevealed = false

    var body: some View {
        VStack(spacing: 0) {
            // ── Tappable header (triggers edit sheet) ──────────────────────
            Button(action: onEdit) {
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16).fill(Color.clear).frame(width: 56, height: 56)
                            if !institution.loginUrl.isEmpty {
                                FaviconImage(website: institution.loginUrl, size: 36)
                            } else {
                                Image(systemName: "building.columns")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.8))
                            }
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            Text(institution.name.isEmpty ? "New Bank" : institution.name)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)

                            HStack(spacing: 14) {
                                costColumn(value: totalMonthlyPayment, label: "mo. payment")
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 12)

                    // ── Counts row styled like Status row ──────────────
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Text("\(institution.accounts.count)").foregroundStyle(.white)
                            Text("Accounts").foregroundStyle(Color.white.opacity(0.4))
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.3)
                        
                        statusPipe()
                        
                        HStack(spacing: 4) {
                            Text("\(cardCount)").foregroundStyle(.white)
                            Text("Cards").foregroundStyle(Color.white.opacity(0.4))
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.3)
                        
                        statusPipe()
                        
                        HStack(spacing: 4) {
                            Text("\(loanCount)").foregroundStyle(.white)
                            Text("Loans").foregroundStyle(Color.white.opacity(0.4))
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.3)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)

                    // ── Credentials (tap-to-copy) ────
                    HStack(spacing: 12) {
                        copyableCredential(
                            id: institution.id,
                            label: "Login ID",
                            value: institution.username.isEmpty ? (institution.email.isEmpty ? "—" : institution.email) : institution.username,
                            field: "login"
                        )
                        copyableCredential(
                            id: institution.id,
                            label: "Password",
                            value: institution.password,
                            field: "password",
                            isPassword: true
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ── Accordion ──────────────────────────────────────────────────
            accordionDivider()
            accordionToggle(label: expanded ? "Hide Accounts" : "Account Details", count: institution.accounts.count + loanCount, expanded: expanded) {
                withAnimation(.spring(response: 0.35)) { expanded.toggle() }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .zIndex(1)
            
            if expanded {
                VStack(spacing: 12) {
                    ForEach(institution.accounts) { acc in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(acc.type == "Credit Card" ? Color.orange : (acc.type == "Checking" ? Color.zifrGold : Color.green))
                                .frame(width: 6, height: 6)
                            Text(acc.name.isEmpty ? "Account" : acc.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.85))
                            Text(acc.type)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.35))
                            Spacer()
                            if !acc.last4.isEmpty {
                                Text("••\(acc.last4)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.zifrGold)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .clipped()
            }
        }
        .background(Color(hex: "#171717"))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }

    private func costColumn(value: Double, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("$\(String(format: "%.0f", value))")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.4))
        }
    }

    private func statusPipe() -> some View {
        Text("|")
            .font(.system(size: 10))
            .foregroundStyle(Color.white.opacity(0.2))
    }

    private func accordionDivider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.05))
            .frame(height: 1)
    }

    private func accordionToggle(label: String, count: Int? = nil, expanded: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if let count = count, count > 0 {
                    Text("\(label) ")
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(0.2)
                        .foregroundStyle(Color.white.opacity(0.5))
                    + Text("(\(count))")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.2))
                } else {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(0.2)
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .padding(.horizontal, 24)
            .frame(height: 47)
        }
    }

    private func copyableCredential(id: String, label: String, value: String, field: String, isPassword: Bool = false) -> some View {
        let isCopied = copiedField == field
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(isCopied ? "Copied ✓" : label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isCopied ? Color.orange : Color.white.opacity(0.5))
                if isPassword {
                    Button {
                        passwordRevealed.toggle()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: passwordRevealed ? "eye.slash" : "eye")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                }
            }

            Button {
                guard !value.isEmpty else { return }
                UIPasteboard.general.string = value
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation { copiedField = field }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { copiedField = nil }
                }
            } label: {
                HStack {
                    Text(isPassword && !passwordRevealed ? "••••••••" : (value.isEmpty ? "—" : value))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(value.isEmpty ? Color.white.opacity(0.3) : .white)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.05), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Financial Card View
struct FinancialCardView: View {
    let card: FinancialCard
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: card.colorHex))
                        .frame(width: 44, height: 28)
                    Text("••\(card.last4)")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(card.name.isEmpty ? "Card" : card.name)
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.white)
                    HStack(spacing: 6) {
                        Text(card.type)
                            .font(.system(size: 9, weight: .bold))
                            .textCase(.uppercase)
                            .foregroundStyle(Color.white.opacity(0.4))
                        Text("•")
                            .foregroundStyle(Color.white.opacity(0.2))
                        Text(card.network)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.4))
                        Text("•")
                            .foregroundStyle(Color.white.opacity(0.2))
                        Text(card.expiry.isEmpty ? "—" : card.expiry)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                }
                Spacer()
                Circle()
                    .fill(card.status.statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: card.status.statusColor, radius: 4)
            }
            .padding(14)
            .glassCard(cornerRadius: 18)
        }
        .buttonStyle(.plain)
    }
}

private extension FinancialCard {
    var colorHex: String {
        let inst = institutionName.lowercased()
        if inst.contains("apple") { return "#FFFFFF" }
        if inst.contains("chase") { return "#1a3f8f" }
        if inst.contains("america") || inst.contains("bofa") { return "#8f1a1a" }
        if inst.contains("wells fargo") { return "#8f1a1a" }
        if inst.contains("citi") { return "#1a6a8f" }
        if inst.contains("capital one") { return "#1a1a8f" }
        if inst.contains("american express") || inst.contains("amex") { return "#1a7a8a" }
        if inst.contains("discover") { return "#b85000" }
        if inst.contains("mercury") { return "#1a3a8f" }
        if inst.contains("stripe") { return "#3a1a8f" }
        if inst.contains("ramp") { return "#3a7a00" }

        switch network {
        case "Visa": return "#1A1F71"
        case "Mastercard": return "#8B0000"
        case "Amex": return "#007BC1"
        case "Discover": return "#FF6600"
        default: return "#2A2A2E"
        }
    }
}

// MARK: - Loan Card View
struct LoanCardView: View {
    let loan: Loan
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(loan.name.isEmpty ? "Loan" : loan.name)
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(.white)
                        Text(loan.lender.isEmpty ? "—" : loan.lender)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(loan.remainingBalance.currencyString)
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.zifrGold)
                        Text("remaining")
                            .zifrLabel()
                    }
                }

                // CiFr-style principal vs interest bar (gold / orange)
                VStack(spacing: 4) {
                    HStack {
                        Text("Principal")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.zifrGold)
                        Spacer()
                        Text("Interest")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.orange)
                    }
                    GeometryReader { geo in
                        let principal = loan.principalAmount > 0 ? loan.remainingBalance / loan.principalAmount : 0
                        let interest = 1.0 - principal
                        HStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.zifrGold)
                                .frame(width: geo.size.width * principal, height: 5)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.orange)
                                .frame(width: geo.size.width * interest, height: 5)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    .frame(height: 5)
                }

                HStack {
                    statBadge(label: "Monthly", value: loan.monthlyPayment.currencyString)
                    Spacer()
                    statBadge(label: "Rate", value: "\(loan.interestRate)%")
                    Spacer()
                    Text(loan.status)
                        .font(.system(size: 9, weight: .black))
                        .textCase(.uppercase)
                        .foregroundStyle(loan.status.statusColor)
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 20)
        }
        .buttonStyle(.plain)
    }

    private func statBadge(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).zifrLabel()
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Edit Institution Sheet
struct EditInstitutionSheet: View {
    @Bindable var institution: Institution
    let cards: [FinancialCard]
    let loans: [Loan]
    @Bindable var vm: AppViewModel
    let isNew: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirm = false
    @State private var showPassword = false
    
    struct Snapshot: Equatable {
        var name, loginUrl, username, email, password: String
    }
    @State private var snapshot: Snapshot?

    private var currentSnapshot: Snapshot {
        Snapshot(name: institution.name, loginUrl: institution.loginUrl, username: institution.username, email: institution.email, password: institution.password)
    }

    private var isDirty: Bool {
        guard let snap = snapshot else { return isNew && !institution.name.trimmingCharacters(in: .whitespaces).isEmpty }
        return snap != currentSnapshot
    }

    private var instCards: [FinancialCard] {
        cards.filter { $0.institutionName.lowercased() == institution.name.lowercased() && !institution.name.isEmpty }
    }
    private var instLoans: [Loan] {
        loans.filter { $0.lender.lowercased() == institution.name.lowercased() && !institution.name.isEmpty }
    }

    @State private var showAccountHUD = false
    @State private var accountDraft = InstitutionAccount()
    @State private var accountDraftIndex: Int? = nil

    @State private var showCardHUD = false
    @State private var cardDraft: FinancialCard? = nil

    @State private var showLoanHUD = false
    @State private var loanDraft: Loan? = nil

    @State private var hasOpenedHUD = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Bank Identity
                Section {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            ZifrField(
                                label: "INSTITUTION",
                                placeholder: "e.g. Chase",
                                text: Binding(get: { institution.name }, set: { institution.name = $0 })
                            )
                            ZifrField(
                                label: "WEBSITE",
                                placeholder: "chase.com",
                                text: Binding(get: { institution.loginUrl }, set: { institution.loginUrl = $0 }),
                                keyboardType: .URL
                            )
                            .textInputAutocapitalization(.never)
                        }

                        HStack(spacing: 12) {
                            ZifrField(
                                label: "LOGIN ID",
                                placeholder: "username",
                                text: Binding(get: { institution.username.isEmpty ? institution.email : institution.username }, set: { institution.username = $0 })
                            )
                            .textInputAutocapitalization(.never)

                            ZStack(alignment: .bottomTrailing) {
                                ZifrField(
                                    label: "PASSWORD",
                                    placeholder: "••••••••",
                                    text: Binding(get: { institution.password }, set: { institution.password = $0 }),
                                    isSecure: !showPassword
                                )
                                .textInputAutocapitalization(.never)

                                Button {
                                    showPassword.toggle()
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.white.opacity(0.4))
                                        .padding()
                                }
                                .padding(.bottom, 2)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)

                Section {
                    Rectangle()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 1)
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                .listRowSeparator(.hidden)

                // MARK: - Accounts Section
                InstitutionAccountsSection(
                    institution: institution,
                    onAdd: {
                        accountDraft = InstitutionAccount()
                        accountDraftIndex = nil
                        hasOpenedHUD = true
                        showAccountHUD = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    },
                    onEdit: { idx, acc in
                        accountDraft = acc
                        accountDraftIndex = idx
                        hasOpenedHUD = true
                        showAccountHUD = true
                    }
                )

                Section {
                    Rectangle()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 1)
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                .listRowSeparator(.hidden)

                // MARK: - Cards Section
                InstitutionCardsSection(
                    cards: instCards,
                    onAdd: {
                        cardDraft = vm.addCard(context: context, companyId: institution.companyId)
                        cardDraft?.institutionName = institution.name 
                        hasOpenedHUD = true
                        showCardHUD = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    },
                    onEdit: { card in
                        cardDraft = card
                        hasOpenedHUD = true
                        showCardHUD = true
                    },
                    onDelete: { card in
                        vm.deleteCard(card, context: context)
                    }
                )

                Section {
                    Rectangle()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 1)
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                .listRowSeparator(.hidden)

                // MARK: - Loans Section
                InstitutionLoansSection(
                    loans: instLoans,
                    onAdd: {
                        loanDraft = vm.addLoan(context: context, companyId: institution.companyId)
                        loanDraft?.lender = institution.name 
                        hasOpenedHUD = true
                        showLoanHUD = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    },
                    onEdit: { loan in
                        loanDraft = loan
                        hasOpenedHUD = true
                        showLoanHUD = true
                    },
                    onDelete: { loan in
                        vm.deleteLoan(loan, context: context)
                    }
                )

                if !isNew {
                    Section {
                        Button(role: .destructive) {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete \(institution.name.isEmpty ? "Institution" : institution.name)")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    }
                }

            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#171717"))
            .listSectionSpacing(0)
            .onAppear {
                snapshot = currentSnapshot
            }
            .navigationTitle(institution.name.isEmpty ? "New Bank" : institution.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(hasOpenedHUD ? "Close" : "Cancel") {
                        if hasOpenedHUD {
                            dismiss()
                            return
                        }
                        
                        if isNew { 
                            vm.deleteInstitution(institution, context: context) 
                        } else if let snap = snapshot {
                            institution.name = snap.name
                            institution.loginUrl = snap.loginUrl
                            institution.username = snap.username
                            institution.email = snap.email
                            institution.password = snap.password
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.saveInstitution(institution, context: context)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(isDirty ? .green : nil)
                }
            }
            .confirmationDialog(
                "Delete Bank?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Bank", role: .destructive) {
                    vm.deleteInstitution(institution, context: context)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
            .interactiveDismissDisabled(isNew)
            .sheet(isPresented: $showAccountHUD) {
                InstitutionAccountHUD(
                    draft: $accountDraft,
                    isNew: accountDraftIndex == nil,
                    onSave: {
                        var accs = institution.accounts
                        if let idx = accountDraftIndex {
                            accs[idx] = accountDraft
                        } else {
                            accs.append(accountDraft)
                        }
                        institution.accounts = accs
                        showAccountHUD = false
                    },
                    onCancel: { showAccountHUD = false }
                )
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
            .sheet(item: $cardDraft, onDismiss: { 
                cardDraft = nil 
            }) { cd in
                EditCardSheet(card: cd, vm: vm, isNew: cd.name.isEmpty && cd.last4.isEmpty)
            }
            .sheet(item: $loanDraft, onDismiss: { 
                loanDraft = nil 
            }) { ld in
                EditLoanSheet(loan: ld, vm: vm, isNew: ld.name.isEmpty && ld.monthlyPayment == 0)
            }
        }
    }
}

// MARK: - Institution Accounts Section
struct InstitutionAccountsSection: View {
    @Bindable var institution: Institution
    let onAdd: () -> Void
    let onEdit: (Int, InstitutionAccount) -> Void

    var body: some View {
        Section {
            Button { onAdd() } label: {
                HStack {
                        Spacer()
                        Text("🏦  Add Account")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color(hex: "#A2A2A2"))
                        Spacer()
                    }
                    .frame(height: 40)
                    .background(Color(hex: "#222E2F"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                ForEach(institution.accounts.indices, id: \.self) { i in
                    let acc = institution.accounts[i]
                    Button { onEdit(i, acc) } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(acc.type == "Credit Card" ? Color.orange : (acc.type == "Checking" ? Color.zifrGold : Color.green))
                                .frame(width: 8, height: 8)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(acc.name.isEmpty ? "Unnamed Account" : acc.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                HStack(spacing: 6) {
                                    Text(acc.type)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                    Text("·").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.2))
                                    Text("••\(acc.last4)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.zifrGold)
                                }
                            }
                            Spacer()
                            Text(acc.balance.currencyString)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.2))
                                .padding(.leading, 4)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#111111"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            withAnimation {
                                var accs = institution.accounts
                                accs.remove(at: i)
                                institution.accounts = accs
                            }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.red)
                    }
                }
        } header: { EmptyView() }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
        .listRowSeparator(.hidden)
    }
}

// MARK: - Institution Cards Section
struct InstitutionCardsSection: View {
    let cards: [FinancialCard]
    let onAdd: () -> Void
    let onEdit: (FinancialCard) -> Void
    let onDelete: (FinancialCard) -> Void

    var body: some View {
        Section {
            Button { onAdd() } label: {
                HStack {
                        Spacer()
                        Text("💳  Add Card")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color(hex: "#A2A2A2"))
                        Spacer()
                    }
                    .frame(height: 40)
                    .background(Color(hex: "#222E2F"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                ForEach(cards, id: \.id) { card in
                    Button { onEdit(card) } label: {
                        HStack(spacing: 12) {
                            Text("💳").font(.system(size: 18))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(card.name.isEmpty ? "Unnamed Card" : card.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                HStack(spacing: 6) {
                                    Text(card.type)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                    Text("·").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.2))
                                    Text(card.network)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                    Text("·").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.2))
                                    Text("••\(card.last4)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                }
                            }
                            Spacer()
                            Text(card.status.uppercased())
                                .font(.system(size: 9, weight: .black))
                                .tracking(0.5)
                                .foregroundStyle(card.status == "Active" ? Color.green : (card.status == "Frozen" ? Color.orange : Color.red))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background((card.status == "Active" ? Color.green : (card.status == "Frozen" ? Color.orange : Color.red)).opacity(0.12))
                                .clipShape(Capsule())
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.2))
                                .padding(.leading, 4)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#111111"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            withAnimation { onDelete(card) }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.red)
                    }
                }
        } header: { EmptyView() }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
        .listRowSeparator(.hidden)
    }
}

// MARK: - Institution Loans Section
struct InstitutionLoansSection: View {
    let loans: [Loan]
    let onAdd: () -> Void
    let onEdit: (Loan) -> Void
    let onDelete: (Loan) -> Void

    var body: some View {
        Section {
            Button { onAdd() } label: {
                HStack {
                        Spacer()
                        Text("💸  Add Loan")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color(hex: "#A2A2A2"))
                        Spacer()
                    }
                    .frame(height: 40)
                    .background(Color(hex: "#222E2F"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                ForEach(loans, id: \.id) { loan in
                    Button { onEdit(loan) } label: {
                        HStack(spacing: 12) {
                            Text("💸").font(.system(size: 18))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(loan.name.isEmpty ? "Unnamed Loan" : loan.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                HStack(spacing: 6) {
                                    Text("\(loan.interestRate, specifier: "%.2f")% APR")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                    Text("·").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.2))
                                    Text(loan.monthlyPayment.currencyString + "/mo")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                }
                            }
                            Spacer()
                            Text(loan.remainingBalance.currencyString)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.zifrGold)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.2))
                                .padding(.leading, 4)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#111111"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            withAnimation { onDelete(loan) }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.red)
                    }
                }
        } header: { EmptyView() }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
        .listRowSeparator(.hidden)
    }
}

// MARK: - Institution Account HUD
struct InstitutionAccountHUD: View {
    @Binding var draft: InstitutionAccount
    let isNew: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @State private var initialDraft: InstitutionAccount? = nil
    
    private var isDirty: Bool {
        guard let initial = initialDraft else { return isNew && !draft.name.isEmpty }
        return draft.name != initial.name ||
               draft.last4 != initial.last4 ||
               draft.type != initial.type ||
               draft.balance != initial.balance
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            ZifrField(
                                label: "ACCOUNT NAME",
                                placeholder: "e.g. Primary Checking",
                                text: $draft.name
                            )
                            ZifrField(
                                label: "LAST 4",
                                placeholder: "1234",
                                text: $draft.last4,
                                keyboardType: .numberPad
                            )
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("TYPE")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                Picker("", selection: $draft.type) {
                                    ForEach(InstitutionAccount.allTypes, id: \.self) { t in
                                        Text(t).tag(t)
                                    }
                                }
                                .labelsHidden()
                                .padding(.leading, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 44)
                                .background(Color(hex: "#111111"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("BALANCE")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                HStack(spacing: 4) {
                                    Text("$")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                    DoubleField(placeholder: "0.00", value: $draft.balance)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 44)
                                .background(Color(hex: "#111111"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#171717"))
            .listSectionSpacing(0)
            .navigationTitle(isNew ? "Add Account" : "Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                initialDraft = draft
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Save", action: onSave)
                        .fontWeight(.semibold)
                        .tint(isDirty ? .green : nil)
                        .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Card Sheet
struct EditCardSheet: View {
    @Bindable var card: FinancialCard
    @Bindable var vm: AppViewModel
    let isNew: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    
    struct Snapshot: Equatable {
        var name, last4, type, autopay, cardHolder, cardHolderType, status, expiry: String
        var balance, limit, moPayment: Double
    }
    @State private var snapshot: Snapshot?

    private var currentSnapshot: Snapshot {
        Snapshot(name: card.name, last4: card.last4, type: card.type, autopay: card.autopay, cardHolder: card.cardHolder, cardHolderType: card.cardHolderType, status: card.status, expiry: card.expiry, balance: card.balance, limit: card.limit, moPayment: card.moPayment)
    }

    private var isDirty: Bool {
        guard let snap = snapshot else { return isNew && !card.name.trimmingCharacters(in: .whitespaces).isEmpty }
        return snap != currentSnapshot
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            ZifrField(label: "CARD NICKNAME", placeholder: "e.g. Sapphire", text: Binding(get: { card.name }, set: { card.name = $0 }))
                            ZifrField(label: "LAST 4", placeholder: "1234", text: Binding(get: { card.last4 }, set: { card.last4 = $0 }), keyboardType: .numberPad)
                        }

                        HStack(spacing: 12) {
                            cardPicker(label: "TYPE", sel: Binding(get: { card.type }, set: { card.type = $0 }), opts: FinancialCard.types)
                            cardPicker(label: "AUTOPAY", sel: Binding(get: { card.autopay }, set: { card.autopay = $0 }), opts: FinancialCard.autopayOptions)
                        }

                        HStack(spacing: 12) {
                            ZifrField(label: "NAME ON CARD", placeholder: "Jane Doe", text: Binding(get: { card.cardHolder }, set: { card.cardHolder = $0 }))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ROLE")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                HStack(spacing: 0) {
                                    Button(action: { card.cardHolderType = "Mine" }) {
                                        Text("MINE")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(card.cardHolderType == "Mine" ? .black : .white)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .background(card.cardHolderType == "Mine" ? .white : Color.clear)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    Button(action: { card.cardHolderType = "Assigned" }) {
                                        Text("ASSIGNED")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(card.cardHolderType == "Assigned" ? .black : .white)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .background(card.cardHolderType == "Assigned" ? .white : Color.clear)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                                .padding(2)
                                .frame(height: 44)
                                .background(Color(hex: "#111111"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("STATUS")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                Picker("", selection: Binding(get: { card.status }, set: { card.status = $0 })) {
                                    ForEach(FinancialCard.statuses, id: \.self) { t in
                                        Text(t).tag(t)
                                    }
                                }
                                .labelsHidden()
                                .padding(.leading, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 44)
                                .background(Color(hex: "#111111"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }

                            ZifrField(label: "EXPIRY", placeholder: "MM/YY", text: Binding(get: { card.expiry }, set: { card.expiry = $0 }))
                        }

                        HStack(spacing: 12) {
                            moneyField(label: "BALANCE", value: Binding(get: { card.balance }, set: { card.balance = $0 }))
                            moneyField(label: "CREDIT LIMIT", value: Binding(get: { card.limit }, set: { card.limit = $0 }))
                        }

                        HStack(spacing: 12) {
                            moneyField(label: "MO. PAYMENT", value: Binding(get: { card.moPayment }, set: { card.moPayment = $0 }))
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 4)
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)

                if !isNew {
                    Section {
                        Button(role: .destructive) {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete \(card.name.isEmpty ? "Card" : card.name)")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#171717"))
            .listSectionSpacing(0)
            .onAppear {
                snapshot = currentSnapshot
            }
            .navigationTitle(isNew ? "New Card" : card.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isNew { 
                            vm.deleteCard(card, context: context) 
                        } else if let snap = snapshot {
                            card.name = snap.name
                            card.last4 = snap.last4
                            card.type = snap.type
                            card.autopay = snap.autopay
                            card.cardHolder = snap.cardHolder
                            card.cardHolderType = snap.cardHolderType
                            card.status = snap.status
                            card.expiry = snap.expiry
                            card.balance = snap.balance
                            card.limit = snap.limit
                            card.moPayment = snap.moPayment
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.saveCard(card, context: context)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(isDirty ? .green : nil)
                }
            }
            .confirmationDialog("Delete Card?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete Card", role: .destructive) {
                    vm.deleteCard(card, context: context)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
            .interactiveDismissDisabled(isNew)
        }
    }

    private func cardPicker(label: String, sel: Binding<String>, opts: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            Picker("", selection: sel) {
                ForEach(opts, id: \.self) { t in
                    Text(t).tag(t)
                }
            }
            .labelsHidden()
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 44)
            .background(Color(hex: "#111111"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    private func moneyField(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            HStack(spacing: 4) {
                Text("$")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.5))
                DoubleField(placeholder: "0.00", value: value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 44)
            .background(Color(hex: "#111111"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }
}

// MARK: - Edit Loan Sheet
struct EditLoanSheet: View {
    @Bindable var loan: Loan
    @Bindable var vm: AppViewModel
    let isNew: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    
    struct Snapshot: Equatable {
        var name, lender, term, startDate, role, status: String
        var principalAmount, remainingBalance, monthlyPayment, interestRate: Double
    }
    @State private var snapshot: Snapshot?

    private var currentSnapshot: Snapshot {
        Snapshot(name: loan.name, lender: loan.lender, term: loan.term, startDate: loan.startDate, role: loan.role, status: loan.status, principalAmount: loan.principalAmount, remainingBalance: loan.remainingBalance, monthlyPayment: loan.monthlyPayment, interestRate: loan.interestRate)
    }

    private var isDirty: Bool {
        guard let snap = snapshot else { return isNew && !loan.name.trimmingCharacters(in: .whitespaces).isEmpty }
        return snap != currentSnapshot
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            ZifrField(label: "LOAN NAME", placeholder: "e.g. Startup Loan", text: Binding(get: { loan.name }, set: { loan.name = $0 }))
                            ZifrField(label: "LENDER", placeholder: "e.g. Chase", text: Binding(get: { loan.lender }, set: { loan.lender = $0 }))
                        }

                        HStack(spacing: 12) {
                            moneyField(label: "PRINCIPAL", value: Binding(get: { loan.principalAmount }, set: { loan.principalAmount = $0 }))
                            moneyField(label: "REMAINING", value: Binding(get: { loan.remainingBalance }, set: { loan.remainingBalance = $0 }))
                        }

                        HStack(spacing: 12) {
                            moneyField(label: "MO. PAYMENT", value: Binding(get: { loan.monthlyPayment }, set: { loan.monthlyPayment = $0 }))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("RATE(%)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                HStack(spacing: 4) {
                                    DoubleField(placeholder: "0.00", value: Binding(get: { loan.interestRate }, set: { loan.interestRate = $0 }))
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                    Text("%")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                }
                                .padding(.horizontal, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 44)
                                .background(Color(hex: "#111111"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }
                        }

                        HStack(spacing: 12) {
                            ZifrField(label: "TERM", placeholder: "36 months", text: Binding(get: { loan.term }, set: { loan.term = $0 }))
                            ZifrField(label: "START DATE", placeholder: "MM/DD/YYYY", text: Binding(get: { loan.startDate }, set: { loan.startDate = $0 }))
                        }

                        HStack(spacing: 12) {
                            loanPicker(label: "ROLE", sel: Binding(get: { loan.role }, set: { loan.role = $0 }), opts: Loan.roles)
                            loanPicker(label: "STATUS", sel: Binding(get: { loan.status }, set: { loan.status = $0 }), opts: Loan.statuses)
                        }
                    }
                    .padding(.vertical, 4)
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)

                if !isNew {
                    Section {
                        Button(role: .destructive) {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete \(loan.name.isEmpty ? "Loan" : loan.name)")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#171717"))
            .listSectionSpacing(0)
            .onAppear {
                snapshot = currentSnapshot
            }
            .navigationTitle(isNew ? "New Loan" : loan.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isNew { 
                            vm.deleteLoan(loan, context: context) 
                        } else if let snap = snapshot {
                            loan.name = snap.name
                            loan.lender = snap.lender
                            loan.term = snap.term
                            loan.startDate = snap.startDate
                            loan.role = snap.role
                            loan.status = snap.status
                            loan.principalAmount = snap.principalAmount
                            loan.remainingBalance = snap.remainingBalance
                            loan.monthlyPayment = snap.monthlyPayment
                            loan.interestRate = snap.interestRate
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.saveLoan(loan, context: context)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(isDirty ? .green : nil)
                }
            }
            .confirmationDialog("Delete Loan?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete Loan", role: .destructive) {
                    vm.deleteLoan(loan, context: context)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
            .interactiveDismissDisabled(isNew)
        }
    }

    private func loanPicker(label: String, sel: Binding<String>, opts: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            Picker("", selection: sel) {
                ForEach(opts, id: \.self) { t in
                    Text(t).tag(t)
                }
            }
            .labelsHidden()
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 44)
            .background(Color(hex: "#111111"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    private func moneyField(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            HStack(spacing: 4) {
                Text("$")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.5))
                DoubleField(placeholder: "0.00", value: value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 44)
            .background(Color(hex: "#111111"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }
}
