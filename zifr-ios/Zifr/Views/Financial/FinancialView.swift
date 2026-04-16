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
struct EditInstitutionSheet: View {
    @Bindable var institution: Institution
    @Bindable var vm: AppViewModel
    let isNew: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showDelete = false
    @State private var showPassword = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "#1C1C1E").ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Title bar ──────────────────────────────────────────────
                HStack {
                    Text(isNew ? "Add Bank" : "Edit Bank")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        if isNew { vm.deleteInstitution(institution, context: context) }
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.45))
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        // ── 2-column field grid ────────────────────────────
                        HStack(spacing: 12) {
                            bankField(label: "Institution", placeholder: "Mercury",
                                      text: Binding(get: { institution.name }, set: { institution.name = $0 }))
                            bankField(label: "Website", placeholder: "bank.com",
                                      text: Binding(get: { institution.loginUrl }, set: { institution.loginUrl = $0 }))
                                .keyboardType(.URL)
                        }
                        HStack(spacing: 12) {
                            bankField(label: "Login ID", placeholder: "user_admin",
                                      text: Binding(get: { institution.username.isEmpty ? institution.email : institution.username },
                                                    set: { institution.username = $0 }))
                            bankField(label: "Password", placeholder: "······",
                                      text: Binding(get: { institution.password }, set: { institution.password = $0 }),
                                      isSecure: !showPassword)
                        }

                        // ── Action buttons ─────────────────────────────────
                        VStack(spacing: 10) {
                            addSubItemButton(emoji: "💳", label: "Add Card") {
                                _ = vm.addCard(context: context, companyId: institution.companyId ?? "")
                            }
                            addSubItemButton(emoji: "🏦", label: "Add Account") {
                                var accs = institution.accounts
                                accs.append(InstitutionAccount())
                                institution.accounts = accs
                            }
                            addSubItemButton(emoji: "💸", label: "Add Loan") {
                                _ = vm.addLoan(context: context, companyId: institution.companyId ?? "")
                            }
                        }

                        // ── Delete (edit mode only) ────────────────────────
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
                                    Label("Delete Institution", systemImage: "trash")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.red.opacity(0.7))
                                }
                                .padding(.top, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 110)
                }
            }

            // ── Sticky bottom bar ──────────────────────────────────────────
            VStack(spacing: 0) {
                Divider().background(Color.white.opacity(0.06))
                HStack(spacing: 0) {
                    Button("Cancel") {
                        if isNew { vm.deleteInstitution(institution, context: context) }
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .frame(maxWidth: .infinity)

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        vm.saveInstitution(institution, context: context)
                        dismiss()
                    } label: {
                        Text("Save Bank")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                    .padding(.trailing, 20)
                }
                .frame(height: 72)
                .background(Color(hex: "#1C1C1E"))
            }
        }
        .interactiveDismissDisabled(isNew)
    }

    private func bankField(label: String, placeholder: String, text: Binding<String>, isSecure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.4))
            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(.white)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity)
    }

    private func addSubItemButton(emoji: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 12) {
                Text(emoji).font(.system(size: 20))
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct EditCardSheet: View {
    @Bindable var card: FinancialCard
    @Bindable var vm: AppViewModel
    let isNew: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ZifrField(label: "Nickname", placeholder: "Amex Gold", text: Binding(get: { card.name }, set: { card.name = $0 }))
                    ZifrField(label: "Institution", placeholder: "American Express", text: Binding(get: { card.institutionName }, set: { card.institutionName = $0 }))
                    ZifrField(label: "Card Holder", placeholder: "John Doe", text: Binding(get: { card.cardHolder }, set: { card.cardHolder = $0 }))
                    HStack(spacing: 12) {
                        ZifrField(label: "Last 4", placeholder: "1234", text: Binding(get: { card.last4 }, set: { card.last4 = $0 })).keyboardType(.numberPad)
                        ZifrField(label: "Expiry", placeholder: "12/28", text: Binding(get: { card.expiry }, set: { card.expiry = $0 })).keyboardType(.numbersAndPunctuation)
                    }
                    HStack(spacing: 12) {
                        pickerCell(label: "Network", sel: Binding(get: { card.network }, set: { card.network = $0 }), opts: FinancialCard.networks)
                        pickerCell(label: "Type", sel: Binding(get: { card.type }, set: { card.type = $0 }), opts: FinancialCard.types)
                        pickerCell(label: "Status", sel: Binding(get: { card.status }, set: { card.status = $0 }), opts: FinancialCard.statuses)
                    }
                    ZifrField(label: "Login", placeholder: "username / email", text: Binding(get: { card.login }, set: { card.login = $0 }))
                    ZifrField(label: "Password", placeholder: "••••••••", text: Binding(get: { card.password }, set: { card.password = $0 }))
                    if !isNew {
                        if showDelete {
                            deleteConfirm { vm.deleteCard(card, context: context); dismiss() } cancel: { showDelete = false }
                        } else {
                            Button {
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                showDelete = true
                            } label: {
                                Label("Delete Card", systemImage: "trash")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                        }
                    }
                }
                .padding(20).padding(.bottom, 40)
            }
            .background(Color(hex: "#1C1C1E"))
            .navigationTitle(isNew ? "New Card" : "Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if isNew { vm.deleteCard(card, context: context) }; dismiss() }
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { vm.saveCard(card, context: context); dismiss() }
                        .font(.system(size: 15, weight: .black)).foregroundStyle(.white)
                }
            }
            .interactiveDismissDisabled(isNew)
        }
    }

    private func pickerCell(label: String, sel: Binding<String>, opts: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).zifrLabel()
            Picker(label, selection: sel) { ForEach(opts, id: \.self) { Text($0).tag($0) } }
                .pickerStyle(.menu).foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8).padding(.vertical, 8)
                .background(Color.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct EditLoanSheet: View {
    @Bindable var loan: Loan
    @Bindable var vm: AppViewModel
    let isNew: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ZifrField(label: "Loan Name", placeholder: "Startup Loan", text: Binding(get: { loan.name }, set: { loan.name = $0 }))
                    ZifrField(label: "Lender", placeholder: "Chase Bank", text: Binding(get: { loan.lender }, set: { loan.lender = $0 }))
                    HStack(spacing: 12) {
                        numField(label: "Principal", val: Binding(get: { loan.principalAmount }, set: { loan.principalAmount = $0 }))
                        numField(label: "Remaining", val: Binding(get: { loan.remainingBalance }, set: { loan.remainingBalance = $0 }))
                    }
                    HStack(spacing: 12) {
                        numField(label: "Monthly Payment", val: Binding(get: { loan.monthlyPayment }, set: { loan.monthlyPayment = $0 }))
                        numField(label: "Interest Rate", val: Binding(get: { loan.interestRate }, set: { loan.interestRate = $0 }))
                    }
                    HStack(spacing: 12) {
                        ZifrField(label: "Term", placeholder: "36 months", text: Binding(get: { loan.term }, set: { loan.term = $0 }))
                        ZifrField(label: "Start Date", placeholder: "MM/DD/YYYY", text: Binding(get: { loan.startDate }, set: { loan.startDate = $0 }))
                    }
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Role").zifrLabel()
                            Picker("Role", selection: Binding(get: { loan.role }, set: { loan.role = $0 })) {
                                ForEach(Loan.roles, id: \.self) { Text($0).tag($0) }
                            }.pickerStyle(.segmented)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Status").zifrLabel()
                            Picker("Status", selection: Binding(get: { loan.status }, set: { loan.status = $0 })) {
                                ForEach(Loan.statuses, id: \.self) { Text($0).tag($0) }
                            }.pickerStyle(.menu).foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8).padding(.vertical, 8)
                                .background(Color.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    if !isNew {
                        if showDelete {
                            deleteConfirm { vm.deleteLoan(loan, context: context); dismiss() } cancel: { showDelete = false }
                        } else {
                            Button {
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                showDelete = true
                            } label: {
                                Label("Delete Loan", systemImage: "trash")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                        }
                    }
                }
                .padding(20).padding(.bottom, 40)
            }
            .background(Color(hex: "#1C1C1E"))
            .navigationTitle(isNew ? "New Loan" : "Edit Loan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if isNew { vm.deleteLoan(loan, context: context) }; dismiss() }
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { vm.saveLoan(loan, context: context); dismiss() }
                        .font(.system(size: 15, weight: .black)).foregroundStyle(.white)
                }
            }
            .interactiveDismissDisabled(isNew)
        }
    }

    private func numField(label: String, val: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).zifrLabel()
            TextField("0", value: val, format: .number)
                .keyboardType(.decimalPad)
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.07), lineWidth: 1))
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
