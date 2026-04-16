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
                            Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.black.opacity(0.5))
                            Text("Institution").font(.system(size: 13, weight: .semibold)).foregroundStyle(.black)
                        }
                        .padding(.horizontal, 18)
                        .frame(height: 36)
                        .background(Color.white)
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
                            .background(Color(hex: "#1C1C1E").opacity(0.5))
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
        .sheet(item: $newInst) { i in EditInstitutionSheet(institution: i, vm: vm, isNew: true) }
        .sheet(item: $editingInst) { i in EditInstitutionSheet(institution: i, vm: vm, isNew: false) }
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
            .background(Color(hex: "#1C1C1E"))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }
    
    @ViewBuilder
    private func walletStackForInstitution(inst: Institution, instCards: [FinancialCard], instLoans: [Loan]) -> some View {
        let peekOffset: CGFloat = 36
        let cardH: CGFloat = 110
        
        ZStack(alignment: .top) {
            if !instCards.isEmpty {
                ZStack(alignment: .top) {
                    ForEach(Array(instCards.enumerated()), id: \.element.id) { index, card in
                        let isPopped = poppedCardId == card.id
                        let yOffset = isPopped ? -(cardH + CGFloat(instCards.count) * peekOffset + 10) : -(peekOffset + CGFloat(index) * peekOffset)
                        let scale = isPopped ? 1.0 : max(0.85, 1.0 - CGFloat(index) * 0.03)
                        
                        FinancialCardVisual(card: card, isPopped: isPopped)
                            .frame(height: cardH)
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
                .zIndex(10)
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
        
        if !cards.isEmpty {
            ZStack(alignment: .bottom) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    let isPopped = poppedCardId == card.id
                    let yOffset = isPopped ? -(cardH + CGFloat(cards.count) * peekOffset + 10) : -(CGFloat(index) * peekOffset)
                    let scale = isPopped ? 1.0 : max(0.85, 1.0 - CGFloat(index) * 0.03)
                    
                    FinancialCardVisual(card: card, isPopped: isPopped)
                        .frame(height: cardH)
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
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(primaryColor)
                    Spacer()
                    Text(card.network)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(secondaryColor)
                        .italic()
                }
                Spacer()
                if isPopped {
                    Text("•••• •••• •••• \(card.last4)")
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundStyle(isLight ? Color.black.opacity(0.85) : Color.white.opacity(0.85))
                        .tracking(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 8)
                    
                    HStack {
                        Text(card.cardHolder.isEmpty ? "Name on Card" : card.cardHolder)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isLight ? Color.black.opacity(0.6) : Color.white.opacity(0.6))
                        Spacer()
                        Text(card.expiry.isEmpty ? "—" : card.expiry)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(isLight ? Color.black.opacity(0.6) : Color.white.opacity(0.6))
                    }
                }
            }
            .padding(14)
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
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 18) {
                    // Header Block
                    HStack(alignment: .top, spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.clear)
                                .frame(width: 56, height: 56)
                            if !institution.loginUrl.isEmpty {
                                FaviconImage(website: institution.loginUrl, size: 36)
                            } else {
                                Image(systemName: "building.columns")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.8))
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(institution.name.isEmpty ? "New Bank" : institution.name)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(totalMonthlyPayment.currencyString)
                                .font(.system(size: 17, weight: .black))
                                .foregroundStyle(.white)
                            Text("Mo. Payment")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.35))
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Credentials Block (Outside Main Edit Button)
            HStack(spacing: 12) {
                copyableCredential(id: institution.id, label: "Login ID", value: institution.username.isEmpty ? (institution.email.isEmpty ? "—" : institution.email) : institution.username, field: "login")
                copyableCredential(id: institution.id, label: "Password", value: institution.password, field: "password", isPassword: true)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
        
            // Accordion (Outside main button so it doesn't trigger edit)
            VStack(spacing: 0) {
                Divider().background(Color.white.opacity(0.05))
            Button {
                withAnimation(.spring(response: 0.35)) { expanded.toggle() }
            } label: {
                HStack(spacing: 0) {
                    Text(expanded ? "Less Details " : "More Details ")
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(0.2)
                        .foregroundStyle(Color.white.opacity(0.5))
                    + Text("(\(institution.accounts.count + loanCount))")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.2))
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .padding(.horizontal, 24)
                .frame(height: 47)
                .background(Color(hex: "#1C1C1E"))
            }
            .buttonStyle(.plain)

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
                .background(Color(hex: "#1C1C1E"))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        
        }
        .background(Color(hex: "#1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
    
    private func copyableCredential(id: String, label: String, value: String, field: String, isPassword: Bool = false) -> some View {
        let isCopied = copiedField == field
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(isCopied ? "Copied ✓" : label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isCopied ? Color.orange : Color.white.opacity(0.4))
                if isPassword {
                    Button {
                        passwordRevealed.toggle()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: passwordRevealed ? "eye.slash" : "eye")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.3))
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
                Text(value.isEmpty ? "—" : (isPassword && !passwordRevealed ? String(repeating: "•", count: Swift.min(value.count, 8)) : value))
                    .font(.system(size: 12, weight: .medium, design: isPassword ? .monospaced : .default))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.05), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private func countLabel(count: Int, label: String, showDivider: Bool) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.zifrGold)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.4))
            if showDivider {
                Text("|").foregroundStyle(Color.white.opacity(0.15)).padding(.horizontal, 4)
            }
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

// MARK: - Edit Sheets (Institution, Card, Loan)

// ─────────────────────────────────────────────
// MARK:  Institution Sheet
// ─────────────────────────────────────────────
struct EditInstitutionSheet: View {
    @Bindable var institution: Institution
    @Bindable var vm: AppViewModel
    let isNew: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showDelete = false
    @State private var showPassword = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // ── Top action row ──────────────────────────────
                        HStack {
                            Button { if isNew { vm.deleteInstitution(institution, context: context) }; dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                    .padding(10)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            Spacer()
                            Button { validate() } label: {
                                Text(isNew ? "SAVE BANK" : "SAVE CHANGES")
                                    .font(.system(size: 11, weight: .black))
                                    .tracking(1)
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 22)
                                    .padding(.vertical, 10)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                            }
                        }

                        // ── Hero name card ───────────────────────────────
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 14) {
                                if !institution.loginUrl.isEmpty {
                                    FaviconImage(website: institution.loginUrl, size: 44)
                                } else {
                                    Image(systemName: "building.columns")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                        .frame(width: 44, height: 44)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("INSTITUTION NAME")
                                        .font(.system(size: 10, weight: .black))
                                        .tracking(1.2)
                                        .foregroundStyle(Color.white.opacity(0.4))
                                    TextField("e.g. Chase Bank", text: Binding(get: { institution.name }, set: { institution.name = $0 }))
                                        .font(.system(size: 26, weight: .black))
                                        .foregroundStyle(.white)
                                        .tint(Color.zifrGold)
                                }
                            }
                        }
                        .padding(22)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "#1C1C1E"))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.05), lineWidth: 1))

                        // ── Web Credentials ──────────────────────────────
                        VStack(alignment: .leading, spacing: 0) {
                            Text("WEB CREDENTIALS")
                                .font(.system(size: 10, weight: .black))
                                .tracking(1.2)
                                .foregroundStyle(Color.white.opacity(0.4))
                                .padding(.horizontal, 4)
                                .padding(.bottom, 10)

                            VStack(spacing: 0) {
                                // Login URL
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("LOGIN URL")
                                        .font(.system(size: 10, weight: .black))
                                        .tracking(1)
                                        .foregroundStyle(Color.white.opacity(0.35))
                                    TextField("chase.com", text: Binding(get: { institution.loginUrl }, set: { institution.loginUrl = $0 }))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white)
                                        .keyboardType(.URL)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                        .tint(Color.zifrGold)
                                        .padding(.horizontal, 14).padding(.vertical, 12)
                                        .background(Color.black.opacity(0.4))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .padding(.horizontal, 20).padding(.vertical, 16)

                                Divider().background(Color.white.opacity(0.05))

                                // Username
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("USERNAME / LOGIN ID")
                                        .font(.system(size: 10, weight: .black))
                                        .tracking(1)
                                        .foregroundStyle(Color.white.opacity(0.35))
                                    TextField("admin@startup.com", text: Binding(get: { institution.username }, set: { institution.username = $0 }))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                        .tint(Color.zifrGold)
                                        .padding(.horizontal, 14).padding(.vertical, 12)
                                        .background(Color.black.opacity(0.4))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .padding(.horizontal, 20).padding(.vertical, 16)

                                Divider().background(Color.white.opacity(0.05))

                                // Password
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("PASSWORD")
                                            .font(.system(size: 10, weight: .black))
                                            .tracking(1)
                                            .foregroundStyle(Color.white.opacity(0.35))
                                        Spacer()
                                        Button { showPassword.toggle() } label: {
                                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                                .font(.system(size: 13))
                                                .foregroundStyle(Color.white.opacity(0.35))
                                        }
                                    }
                                    Group {
                                        if showPassword {
                                            TextField("••••••••", text: Binding(get: { institution.password }, set: { institution.password = $0 }))
                                        } else {
                                            SecureField("••••••••", text: Binding(get: { institution.password }, set: { institution.password = $0 }))
                                        }
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)
                                    .tint(Color.zifrGold)
                                    .padding(.horizontal, 14).padding(.vertical, 12)
                                    .background(Color.black.opacity(0.4))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .padding(.horizontal, 20).padding(.vertical, 16)
                            }
                            .background(Color(hex: "#1C1C1E"))
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.05), lineWidth: 1))
                        }

                        // ── Linked Accounts ──────────────────────────────
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("LINKED ACCOUNTS (\(institution.accounts.count))")
                                    .font(.system(size: 10, weight: .black))
                                    .tracking(1.2)
                                    .foregroundStyle(Color.white.opacity(0.4))
                                Spacer()
                                Button {
                                    var accs = institution.accounts
                                    accs.append(InstitutionAccount())
                                    institution.accounts = accs
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Text("+ Add")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.zifrGold)
                                }
                            }
                            .padding(.horizontal, 4)

                            VStack(spacing: 0) {
                                if institution.accounts.isEmpty {
                                    Text("No internal accounts tracked.")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.2))
                                        .frame(maxWidth: .infinity)
                                        .padding(24)
                                } else {
                                    ForEach(Array(institution.accounts.enumerated()), id: \.element.id) { idx, acc in
                                        VStack(spacing: 0) {
                                            if idx > 0 { Divider().background(Color.white.opacity(0.05)) }
                                            accountRow(idx: idx, acc: acc)
                                        }
                                    }
                                }
                            }
                            .background(Color(hex: "#1C1C1E"))
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.05), lineWidth: 1))
                        }

                        // ── Delete ───────────────────────────────────────
                        if !isNew {
                            if showDelete {
                                deleteConfirm {
                                    vm.deleteInstitution(institution, context: context)
                                    dismiss()
                                } cancel: { showDelete = false }
                            } else {
                                Button {
                                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                    showDelete = true
                                } label: {
                                    Text("Delete Institution")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.red)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.red.opacity(0.3), lineWidth: 1))
                                }
                            }
                        }

                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func validate() {
        guard !institution.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        vm.saveInstitution(institution, context: context)
        dismiss()
    }

    @ViewBuilder
    private func accountRow(idx: Int, acc: InstitutionAccount) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("Account name", text: Binding(
                    get: { acc.name },
                    set: { val in
                        var list = institution.accounts
                        list[idx].name = val
                        institution.accounts = list
                    }
                ))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .tint(Color.zifrGold)

                Spacer()

                Button {
                    var list = institution.accounts
                    list.remove(at: idx)
                    institution.accounts = list
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.red.opacity(0.6))
                }
            }

            HStack(spacing: 16) {
                // Last 4
                VStack(alignment: .leading, spacing: 3) {
                    Text("LAST 4").font(.system(size: 9, weight: .black)).tracking(0.8).foregroundStyle(Color.white.opacity(0.3))
                    TextField("x1234", text: Binding(
                        get: { acc.last4 },
                        set: { val in var l = institution.accounts; l[idx].last4 = val; institution.accounts = l }
                    ))
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    .keyboardType(.numberPad)
                    .tint(Color.zifrGold)
                    .frame(maxWidth: 60)
                    .padding(.bottom, 4)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1) }
                }

                // Balance
                VStack(alignment: .leading, spacing: 3) {
                    Text("BALANCE").font(.system(size: 9, weight: .black)).tracking(0.8).foregroundStyle(Color.white.opacity(0.3))
                    HStack(spacing: 2) {
                        Text("$").font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.4))
                        TextField("0.00", value: Binding(
                            get: { acc.balance },
                            set: { val in var l = institution.accounts; l[idx].balance = val; institution.accounts = l }
                        ), format: .number)
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        .keyboardType(.decimalPad)
                        .tint(Color.zifrGold)
                        .frame(maxWidth: 90)
                    }
                    .padding(.bottom, 4)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1) }
                }

                Spacer()

                // Type picker
                Picker("Type", selection: Binding(
                    get: { acc.type },
                    set: { val in var l = institution.accounts; l[idx].type = val; institution.accounts = l }
                )) {
                    ForEach(InstitutionAccount.allTypes, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.zifrGold)
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(18)
        .animation(.none, value: institution.accounts.count)
    }
}

// ─────────────────────────────────────────────
// MARK:  Card Sheet
// ─────────────────────────────────────────────
struct EditCardSheet: View {
    @Bindable var card: FinancialCard
    @Bindable var vm: AppViewModel
    let isNew: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showDelete = false

    // Derive a background gradient color from institution name (mirrors cifr JS logic)
    private var heroGradient: LinearGradient {
        let name = card.institutionName.lowercased()
        let top: Color
        let bot: Color
        if name.contains("chase") || name.contains("amex") || name.contains("citi") {
            top = Color(hex: "#1e3a5f"); bot = Color(hex: "#0f2040")
        } else if name.contains("bofa") || name.contains("bank of america") || name.contains("wells") {
            top = Color(hex: "#5f1e1e"); bot = Color(hex: "#3a0f0f")
        } else if name.contains("discover") {
            top = Color(hex: "#6b2d0f"); bot = Color(hex: "#3a1a08")
        } else if name.contains("td bank") || name.contains("fidelity") {
            top = Color(hex: "#0f3b25"); bot = Color(hex: "#082015")
        } else if card.network == "Amex" {
            top = Color(hex: "#2e3a4a"); bot = Color(hex: "#1a222d")
        } else {
            let hex = card.colorHex.isEmpty ? "#1C1C1E" : card.colorHex
            top = Color(hex: hex).opacity(0.9); bot = Color(hex: hex)
        }
        return LinearGradient(colors: [top, bot], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // ── Top action row ──────────────────────────────
                        HStack {
                            Button { if isNew { vm.deleteCard(card, context: context) }; dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                    .padding(10)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            Spacer()
                            Button { vm.saveCard(card, context: context); dismiss() } label: {
                                Text(isNew ? "SAVE CARD" : "SAVE CHANGES")
                                    .font(.system(size: 11, weight: .black))
                                    .tracking(1)
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 22).padding(.vertical, 10)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                            }
                        }

                        // ── Live card hero ───────────────────────────────
                        ZStack(alignment: .bottom) {
                            heroGradient
                            // Subtle noise overlay
                            RoundedRectangle(cornerRadius: 32)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)

                            VStack(spacing: 0) {
                                // Top row: nickname + network
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        TextField("CARD NICKNAME", text: Binding(get: { card.name }, set: { card.name = $0 }))
                                            .font(.system(size: 12, weight: .black))
                                            .tracking(1)
                                            .foregroundStyle(.white)
                                            .textCase(.uppercase)
                                            .tint(Color.zifrGold)
                                        TextField("Bank Name", text: Binding(get: { card.institutionName }, set: { card.institutionName = $0 }))
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.55))
                                            .tint(Color.zifrGold)
                                    }
                                    Spacer()
                                    TextField("Visa", text: Binding(get: { card.network }, set: { card.network = $0 }))
                                        .font(.system(size: 13, weight: .black))
                                        .italic()
                                        .foregroundStyle(Color.white.opacity(0.9))
                                        .multilineTextAlignment(.trailing)
                                        .tint(Color.zifrGold)
                                        .frame(maxWidth: 80)
                                }

                                Spacer()

                                // Card number row
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("•••• •••• ••••")
                                        .font(.system(size: 22, weight: .regular, design: .monospaced))
                                        .tracking(2)
                                        .foregroundStyle(Color.white.opacity(0.9))
                                    TextField("1234", text: Binding(get: { card.last4 }, set: { card.last4 = $0 }))
                                        .font(.system(size: 22, weight: .regular, design: .monospaced))
                                        .tracking(2)
                                        .foregroundStyle(Color.white.opacity(0.9))
                                        .keyboardType(.numberPad)
                                        .tint(Color.zifrGold)
                                        .frame(maxWidth: 70)
                                }
                                .padding(.bottom, 12)

                                // Bottom row: cardholder + expiry
                                HStack {
                                    TextField("CARDHOLDER NAME", text: Binding(get: { card.cardHolder }, set: { card.cardHolder = $0 }))
                                        .font(.system(size: 11, weight: .bold))
                                        .tracking(1)
                                        .foregroundStyle(Color.white.opacity(0.75))
                                        .textCase(.uppercase)
                                        .tint(Color.zifrGold)
                                    Spacer()
                                    TextField("MM/YY", text: Binding(get: { card.expiry }, set: { card.expiry = $0 }))
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.75))
                                        .multilineTextAlignment(.trailing)
                                        .keyboardType(.numbersAndPunctuation)
                                        .tint(Color.zifrGold)
                                        .frame(maxWidth: 55)
                                }
                            }
                            .padding(24)
                        }
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 32))
                        .shadow(color: .black.opacity(0.5), radius: 20, y: 10)

                        // ── Card Logistics ───────────────────────────────
                        VStack(alignment: .leading, spacing: 0) {
                            Text("CARD LOGISTICS")
                                .font(.system(size: 10, weight: .black))
                                .tracking(1.2)
                                .foregroundStyle(Color.white.opacity(0.4))
                                .padding(.horizontal, 4)
                                .padding(.bottom, 10)

                            VStack(spacing: 0) {
                                // Credit / Debit toggle
                                HStack(spacing: 0) {
                                    ForEach(FinancialCard.types, id: \.self) { t in
                                        Button { card.type = t } label: {
                                            Text(t == "Credit" ? "Credit Card" : "Debit")
                                                .font(.system(size: 11, weight: .black))
                                                .tracking(0.5)
                                                .foregroundStyle(card.type == t ? .black : Color.white.opacity(0.35))
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                                .background(card.type == t ? Color.white : Color.clear)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                    }
                                }
                                .padding(4)
                                .background(Color.black.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 4)

                                Divider().background(Color.white.opacity(0.05)).padding(.vertical, 16)

                                // Network + Status pickers
                                HStack(spacing: 12) {
                                    pickerCell(label: "NETWORK", sel: Binding(get: { card.network }, set: { card.network = $0 }), opts: FinancialCard.networks)
                                    pickerCell(label: "STATUS", sel: Binding(get: { card.status }, set: { card.status = $0 }), opts: FinancialCard.statuses)
                                }
                                .padding(.horizontal, 20).padding(.bottom, 18)

                                Divider().background(Color.white.opacity(0.05))

                                // Limit
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("LIMIT / AVAILABLE BALANCE")
                                        .font(.system(size: 10, weight: .black))
                                        .tracking(1)
                                        .foregroundStyle(Color.white.opacity(0.35))
                                    HStack {
                                        Text("$").font(.system(size: 16)).foregroundStyle(Color.white.opacity(0.4))
                                        TextField("0.00", value: Binding(get: { card.limit }, set: { card.limit = $0 }), format: .number)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(.white)
                                            .keyboardType(.decimalPad)
                                            .tint(Color.zifrGold)
                                    }
                                    .padding(.bottom, 4)
                                    .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1) }
                                }
                                .padding(.horizontal, 20).padding(.vertical, 18)
                            }
                            .background(Color(hex: "#1C1C1E"))
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.05), lineWidth: 1))
                        }

                        // ── Delete ───────────────────────────────────────
                        if !isNew {
                            if showDelete {
                                deleteConfirm { vm.deleteCard(card, context: context); dismiss() } cancel: { showDelete = false }
                            } else {
                                Button {
                                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                    showDelete = true
                                } label: {
                                    Text("Delete Card")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.red)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.red.opacity(0.3), lineWidth: 1))
                                }
                            }
                        }

                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, 20).padding(.top, 16)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func pickerCell(label: String, sel: Binding<String>, opts: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .black))
                .tracking(0.8)
                .foregroundStyle(Color.white.opacity(0.35))
            Picker(label, selection: sel) { ForEach(opts, id: \.self) { Text($0).tag($0) } }
                .pickerStyle(.menu)
                .foregroundStyle(Color.zifrGold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// ─────────────────────────────────────────────
// MARK:  Loan Sheet
// ─────────────────────────────────────────────
struct EditLoanSheet: View {
    @Bindable var loan: Loan
    @Bindable var vm: AppViewModel
    let isNew: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showDelete = false

    // Live amortization calculator (matches cifr JS logic exactly)
    private var amort: (monthly: Double, totalInterest: Double, totalCost: Double)? {
        let principal = loan.principalAmount
        let rate      = loan.interestRate
        let totalMo   = Double(loan.termYears) * 12.0 + Double(loan.termMonths)
        guard principal > 0, totalMo > 0 else { return nil }

        let perPeriod = (rate / 100.0) / 12.0
        let payment: Double
        if perPeriod <= 0 {
            payment = principal / totalMo
        } else {
            let factor = pow(1 + perPeriod, totalMo)
            payment = principal * (perPeriod * factor) / (factor - 1)
        }

        var balance = principal
        var totalInterest = 0.0
        for _ in 1...Int(totalMo) {
            let interest = balance * perPeriod
            balance -= (payment - interest)
            totalInterest += interest
        }
        return (payment, totalInterest, principal + totalInterest)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // ── Top action row ──────────────────────────────
                        HStack {
                            Button { if isNew { vm.deleteLoan(loan, context: context) }; dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                    .padding(10)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            Spacer()
                            Button { vm.saveLoan(loan, context: context); dismiss() } label: {
                                Text(isNew ? "SAVE LOAN" : "SAVE CHANGES")
                                    .font(.system(size: 11, weight: .black))
                                    .tracking(1)
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 22).padding(.vertical, 10)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                            }
                        }

                        // ── Hero card ────────────────────────────────────
                        VStack(alignment: .leading, spacing: 16) {
                            // Loan name + lender
                            VStack(alignment: .leading, spacing: 4) {
                                Text("LOAN NAME")
                                    .font(.system(size: 10, weight: .black))
                                    .tracking(1.2)
                                    .foregroundStyle(Color.white.opacity(0.4))
                                TextField("e.g. Equipment Financing", text: Binding(get: { loan.name }, set: { loan.name = $0 }))
                                    .font(.system(size: 26, weight: .black))
                                    .foregroundStyle(.white)
                                    .tint(Color.zifrGold)
                                TextField("Bank of America", text: Binding(get: { loan.lender }, set: { loan.lender = $0 }))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                    .tint(Color.zifrGold)
                            }

                            Divider().background(Color.white.opacity(0.06))

                            // Principal + Balance row
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("PRINCIPAL")
                                        .font(.system(size: 10, weight: .black))
                                        .tracking(1)
                                        .foregroundStyle(Color.white.opacity(0.35))
                                    HStack(spacing: 3) {
                                        Text("$").font(.system(size: 16)).foregroundStyle(Color.white.opacity(0.4))
                                        TextField("0.00", value: Binding(get: { loan.principalAmount }, set: { loan.principalAmount = $0 }), format: .number)
                                            .font(.system(size: 22, weight: .black)).foregroundStyle(.white)
                                            .keyboardType(.decimalPad).tint(Color.zifrGold)
                                    }
                                    .padding(.bottom, 4)
                                    .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1) }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("REMAINING")
                                        .font(.system(size: 10, weight: .black))
                                        .tracking(1)
                                        .foregroundStyle(Color.white.opacity(0.35))
                                    HStack(spacing: 3) {
                                        Text("$").font(.system(size: 16)).foregroundStyle(Color.red.opacity(0.5))
                                        TextField("0.00", value: Binding(get: { loan.remainingBalance }, set: { loan.remainingBalance = $0 }), format: .number)
                                            .font(.system(size: 22, weight: .black)).foregroundStyle(Color.red.opacity(0.85))
                                            .keyboardType(.decimalPad).tint(Color.zifrGold)
                                    }
                                    .padding(.bottom, 4)
                                    .overlay(alignment: .bottom) { Rectangle().fill(Color.red.opacity(0.2)).frame(height: 1) }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(22)
                        .background(Color(hex: "#1C1C1E"))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.05), lineWidth: 1))

                        // ── Amortization Details ─────────────────────────
                        VStack(alignment: .leading, spacing: 0) {
                            Text("AMORTIZATION DETAILS")
                                .font(.system(size: 10, weight: .black))
                                .tracking(1.2)
                                .foregroundStyle(Color.white.opacity(0.4))
                                .padding(.horizontal, 4)
                                .padding(.bottom, 10)

                            VStack(spacing: 0) {
                                // APR / Term years / Term months
                                HStack(spacing: 10) {
                                    amortField(label: "APR %", placeholder: "5.5",
                                        value: Binding(get: { loan.interestRate }, set: { loan.interestRate = $0 }))
                                    amortField(label: "TERM (YRS)", placeholder: "3",
                                        value: Binding(
                                            get: { Double(loan.termYears) },
                                            set: { loan.termYears = Int($0) }))
                                    amortField(label: "TERM (MO)", placeholder: "0",
                                        value: Binding(
                                            get: { Double(loan.termMonths) },
                                            set: { loan.termMonths = Int($0) }))
                                }
                                .padding(.horizontal, 20).padding(.vertical, 18)

                                Divider().background(Color.white.opacity(0.05))

                                // Calculated burn block
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("CALCULATED BURN")
                                        .font(.system(size: 10, weight: .black))
                                        .tracking(1)
                                        .foregroundStyle(Color.white.opacity(0.25))
                                        .padding(.bottom, 14)

                                    HStack {
                                        Text("Monthly Note").font(.system(size: 14, weight: .medium)).foregroundStyle(Color.white.opacity(0.7))
                                        Spacer()
                                        Text(amort != nil ? "$\(String(format: "%.2f", amort!.monthly))" : "$0.00")
                                            .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                                    }.padding(.bottom, 8)

                                    HStack {
                                        Text("Interest Over Life").font(.system(size: 14, weight: .medium)).foregroundStyle(Color.white.opacity(0.7))
                                        Spacer()
                                        Text(amort != nil ? "$\(String(format: "%.2f", amort!.totalInterest))" : "$0.00")
                                            .font(.system(size: 14, weight: .bold)).foregroundStyle(Color.red.opacity(0.85))
                                    }.padding(.bottom, 14)

                                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1).padding(.bottom, 14)

                                    HStack {
                                        Text("TOTAL COST")
                                            .font(.system(size: 11, weight: .black))
                                            .tracking(0.8)
                                            .foregroundStyle(Color.white.opacity(0.35))
                                        Spacer()
                                        Text(amort != nil ? "$\(String(format: "%.2f", amort!.totalCost))" : "$0.00")
                                            .font(.system(size: 20, weight: .black)).foregroundStyle(.white)
                                    }
                                }
                                .padding(.horizontal, 20).padding(.vertical, 20)
                            }
                            .background(Color(hex: "#1C1C1E"))
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.05), lineWidth: 1))
                        }

                        // ── Delete ───────────────────────────────────────
                        if !isNew {
                            if showDelete {
                                deleteConfirm { vm.deleteLoan(loan, context: context); dismiss() } cancel: { showDelete = false }
                            } else {
                                Button {
                                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                    showDelete = true
                                } label: {
                                    Text("Delete Loan")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.red)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.red.opacity(0.3), lineWidth: 1))
                                }
                            }
                        }

                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, 20).padding(.top, 16)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func amortField(label: String, placeholder: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .black))
                .tracking(0.8)
                .foregroundStyle(Color.white.opacity(0.35))
            TextField(placeholder, value: value, format: .number)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .keyboardType(.decimalPad)
                .tint(Color.zifrGold)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color.black.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Shared Delete Helpers

private func deleteConfirm(confirm: @escaping () -> Void, cancel: @escaping () -> Void) -> some View {
    HStack(spacing: 20) {
        Text("Sure?").font(.system(size: 12, weight: .bold)).foregroundStyle(.red)
        Button("Yes, Delete") { confirm() }
            .font(.system(size: 12, weight: .black)).foregroundStyle(.red)
        Button("Cancel") { cancel() }
            .font(.system(size: 12, weight: .bold)).foregroundStyle(Color.white.opacity(0.4))
    }
    .padding(14).glassCard(cornerRadius: 14)
}
