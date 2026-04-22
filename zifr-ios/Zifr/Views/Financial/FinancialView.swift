import SwiftUI
import SwiftData

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
                    Menu {
                        Button {
                            newCard = vm.addCard(context: context, companyId: company.id)
                        } label: {
                            Label("Add Card", systemImage: "creditcard")
                        }
                        Button {
                            newLoan = vm.addLoan(context: context, companyId: company.id)
                        } label: {
                            Label("Add Loan", systemImage: "dollarsign.circle")
                        }
                        Button {
                            newInst = vm.addInstitution(context: context, companyId: company.id)
                        } label: {
                            Label("Add Account", systemImage: "building.columns")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("SOLO CARD/LOAN").font(.system(size: 12, weight: .heavy)).tracking(1).foregroundStyle(Color(hex: "#A2A2A2"))
                            Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(Color.white.opacity(0.4))
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 36)
                        .background(Color(hex: "#171717"))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                    }

                    Spacer()
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        newInst = vm.addInstitution(context: context, companyId: company.id)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 13, weight: .bold)).foregroundStyle(Color(hex: "#A2A2A2"))
                            Text("INSTITUTION").font(.system(size: 12, weight: .heavy)).tracking(1).foregroundStyle(Color(hex: "#A2A2A2"))
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 36)
                        .background(Color(hex: "#223E5A"))
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
        .sheet(item: $newInst) { i in EditInstitutionSheet(institution: i, institutions: institutions, cards: cards, loans: loans, vm: vm, isNew: true) }
        .sheet(item: $editingInst) { i in EditInstitutionSheet(institution: i, institutions: institutions, cards: cards, loans: loans, vm: vm, isNew: false) }
        .sheet(item: $newCard) { c in EditCardSheet(card: c, vm: vm, institutions: institutions, cards: cards, isNew: true) }
        .sheet(item: $editingCard) { c in EditCardSheet(card: c, vm: vm, institutions: institutions, cards: cards, isNew: false) }
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
                loans: instLoans,
                vm: vm,
                onEdit: { editingInst = inst },
                onEditLoan: { editingLoan = $0 }
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
    let loans: [Loan]
    @Bindable var vm: AppViewModel
    let onEdit: () -> Void
    let onEditLoan: (Loan) -> Void
    @State private var expanded = false
    @State private var copiedField: String? = nil
    @State private var passwordRevealed = false

    @State private var editingAccount: InstitutionAccount? = nil
    @State private var accountDraft = InstitutionAccount()

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
            accordionToggle(label: expanded ? "Hide Accounts" : "Linked Accounts", count: institution.accounts.count + loanCount, expanded: expanded) {
                withAnimation(.spring(response: 0.35)) { expanded.toggle() }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .zIndex(1)
            
            if expanded {
                VStack(spacing: 12) {
                    ForEach(institution.accounts) { acc in
                        Button {
                            accountDraft = acc
                            editingAccount = acc
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(acc.name.isEmpty ? "Account" : acc.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                    
                                    HStack(spacing: 6) {
                                        Text(acc.type)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.6))
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(acc.balance.currencyString)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#111111"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.05), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(loans) { loan in
                        Button {
                            onEditLoan(loan)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(loan.name.isEmpty ? "Loan" : loan.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                    
                                    HStack(spacing: 6) {
                                        Text(loan.role)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.6))
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(loan.remainingBalance.currencyString)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#111111"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.05), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
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
        .sheet(item: $editingAccount) { _ in
            InstitutionAccountHUD(
                draft: $accountDraft,
                isNew: false,
                onSave: {
                    if let idx = institution.accounts.firstIndex(where: { $0.id == accountDraft.id }) {
                        var updated = institution.accounts
                        updated[idx] = accountDraft
                        institution.accounts = updated
                    }
                    editingAccount = nil
                },
                onCancel: { editingAccount = nil },
                onDelete: {
                    if let idx = institution.accounts.firstIndex(where: { $0.id == accountDraft.id }) {
                        let acc = institution.accounts[idx]
                        vm.cleanUpCustomPaymentMethod(name: acc.name.isEmpty ? acc.type : acc.name)
                        institution.accounts.remove(at: idx)
                    }
                    editingAccount = nil
                }
            )
            .presentationDetents([.height(420)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
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
    let institutions: [Institution]
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
                                text: Binding(get: { institution.username.isEmpty ? institution.email : institution.username }, set: { institution.username = $0 }),
                                keyboardType: .emailAddress
                            )

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
                    vm: vm,
                    onAdd: {
                        accountDraft = InstitutionAccount()
                        accountDraftIndex = nil
                        showAccountHUD = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    },
                    onEdit: { idx, acc in
                        accountDraft = acc
                        accountDraftIndex = idx
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
                        showCardHUD = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    },
                    onEdit: { card in
                        cardDraft = card
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
                        showLoanHUD = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    },
                    onEdit: { loan in
                        loanDraft = loan
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
                                Image(systemName: "trash")
                                Text("Delete \(institution.name.isEmpty ? "Institution" : institution.name)")
                                Spacer()
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.red)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
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
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 20, trailing: 20))
                    .listRowSeparator(.hidden)
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
                    Button("Cancel") {
                        
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
                    onCancel: { showAccountHUD = false },
                    onDelete: {
                        if let idx = accountDraftIndex {
                            let acc = institution.accounts[idx]
                            vm.cleanUpCustomPaymentMethod(name: acc.name.isEmpty ? acc.type : acc.name)
                            institution.accounts.remove(at: idx)
                        }
                        showAccountHUD = false
                    }
                )
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
            .sheet(item: $cardDraft, onDismiss: { 
                cardDraft = nil 
            }) { cd in
                EditCardSheet(card: cd, vm: vm, institutions: institutions, cards: cards, isNew: cd.name.isEmpty && cd.last4.isEmpty)
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
    @Bindable var vm: AppViewModel
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
                                let acc = institution.accounts[i]
                                vm.cleanUpCustomPaymentMethod(name: acc.name.isEmpty ? acc.type : acc.name)
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
    var onDelete: (() -> Void)? = nil
    
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
                                placeholder: "****",
                                text: $draft.last4,
                                keyboardType: .numberPad
                            )
                            .onChange(of: draft.last4) { old, new in
                                let filtered = new.filter { $0.isNumber }
                                let truncated = String(filtered.prefix(4))
                                if draft.last4 != truncated { draft.last4 = truncated }
                            }
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
                                .contentShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.borderless)

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

                if !isNew {
                    Section {
                        Button(role: .destructive) {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onDelete?()
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("Delete Account")
                                Spacer()
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.red)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 20, trailing: 20))
                    .listRowSeparator(.hidden)
                }
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
    let institutions: [Institution]
    let cards: [FinancialCard]
    let isNew: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    
    @Query private var subscriptions: [Subscription]
    
    @State private var showFinancials = false
    @State private var showPaymentPicker = false

    private var autoPayBinding: Binding<Bool> {
        Binding(
            get: { card.autopay == "Yes" },
            set: { card.autopay = $0 ? "Yes" : "No" }
        )
    }
    
    private let ordinalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .ordinal
        return f
    }()

    private func ordinal(_ n: Int) -> String {
        ordinalFormatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private var paidOnBinding: Binding<Int> {
        Binding(
            get: { Int(card.paidOn) ?? 1 },
            set: { card.paidOn = "\($0)" }
        )
    }
    
    struct Snapshot: Equatable {
        var name, last4, type, autopay, cardHolder, cardHolderType, expiry, notes: String
        var balance, limit, moPayment, apr, promoApr: Double
        var promoEnds: Date
    }
    @State private var snapshot: Snapshot?

    private var currentSnapshot: Snapshot {
        Snapshot(name: card.name, last4: card.last4, type: card.type, autopay: card.autopay, cardHolder: card.cardHolder, cardHolderType: card.cardHolderType, expiry: card.expiry, notes: card.notes, balance: card.balance, limit: card.limit, moPayment: card.moPayment, apr: card.apr, promoApr: card.promoApr, promoEnds: card.promoEnds)
    }

    private var isDirty: Bool {
        guard let snap = snapshot else { return isNew && !card.name.trimmingCharacters(in: .whitespaces).isEmpty }
        return snap != currentSnapshot
    }

    @ViewBuilder private var row1: some View {
        HStack(spacing: 12) {
            ZifrField(label: "CARD NICKNAME", placeholder: "e.g. Sapphire", text: Binding(get: { card.name }, set: { card.name = $0 }))
            ZifrField(label: "LAST 4", placeholder: "****", text: Binding(get: { card.last4 }, set: { card.last4 = $0 }), keyboardType: .numberPad)
                .onChange(of: card.last4) { old, new in
                    let filtered = new.filter { $0.isNumber }
                    let truncated = String(filtered.prefix(4))
                    if card.last4 != truncated { card.last4 = truncated }
                }
        }
    }

    @ViewBuilder private var row2: some View {
        HStack(spacing: 12) {
            ZifrField(label: "NAME ON CARD", placeholder: "Jane Doe", text: Binding(get: { card.cardHolder }, set: { card.cardHolder = $0 }))
            cardPicker(label: "TYPE", sel: Binding(get: { card.type }, set: { card.type = $0 }), opts: FinancialCard.types)
        }
    }

    @ViewBuilder private var row3: some View {
        GeometryReader { geo in
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AUTOPAY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.5))
                    HStack {
                        Text(autoPayBinding.wrappedValue ? "Enabled" : "Disabled")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.white)
                        Spacer()
                        Toggle("", isOn: autoPayBinding)
                            .labelsHidden()
                            .tint(.green)
                            .scaleEffect(0.8)
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(hex: "#111111"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                .frame(width: (geo.size.width - 12) * 0.6)

                VStack(alignment: .leading, spacing: 4) {
                    Text("PAID ON")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.5))
                    Picker("", selection: paidOnBinding) {
                        ForEach(1...31, id: \.self) { day in
                            Text(ordinal(day)).tag(day)
                        }
                    }
                    .labelsHidden()
                    .padding(.leading, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 44)
                    .background(Color(hex: "#111111"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .contentShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.borderless)
                .frame(width: (geo.size.width - 12) * 0.4)
            }
        }
        .frame(height: 64)
    }

    @ViewBuilder private var row4: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PAID FROM")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            
            Button {
                showPaymentPicker = true
            } label: {
                HStack {
                    Text(card.paidFrom.isEmpty ? "None" : card.paidFrom)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(card.paidFrom.isEmpty ? Color.white.opacity(0.4) : .white)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color(hex: "#111111"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder private var row5: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ROLE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.5))
                VStack(spacing: 0) {
                    Spacer()
                    Picker("Role", selection: Binding(get: { card.cardHolderType }, set: { card.cardHolderType = $0 })) {
                        Text("Mine").tag("Mine")
                        Text("Assigned").tag("Assigned")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    Spacer()
                }
                .frame(height: 44)
            }
            
            ZifrField(label: "EXPIRES", placeholder: "MM/YY", text: Binding(get: { card.expiry }, set: { card.expiry = $0 }), keyboardType: .numberPad)
                .onChange(of: card.expiry) { old, new in
                    var filtered = new.filter { $0.isNumber }
                    if old.count == 3 && old.hasSuffix("/") && new.count == 2 {
                        filtered = String(filtered.prefix(1))
                    }
                    if filtered.count > 2 {
                        filtered.insert("/", at: filtered.index(filtered.startIndex, offsetBy: 2))
                    }
                    if filtered.count > 5 {
                        filtered = String(filtered.prefix(5))
                    }
                    if card.expiry != filtered { card.expiry = filtered }
                }
        }
    }

    private var paysForServices: [(name: String, cost: Double)] {
        let cardName = card.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cardName.isEmpty else { return [] }
        var results: [(name: String, cost: Double)] = []
        for sub in subscriptions {
            if sub.paymentMethod.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == cardName {
                results.append((name: sub.name.isEmpty ? "Unnamed Service" : sub.name, cost: sub.cost))
            }
            for subSvc in sub.subServices {
                if subSvc.paymentMethod.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == cardName {
                    results.append((name: subSvc.name.isEmpty ? "Unnamed Sub-service" : subSvc.name, cost: subSvc.cost))
                }
            }
        }
        return results
    }

    @ViewBuilder private var paysForRow: some View {
        let services = paysForServices
        VStack(alignment: .leading, spacing: 12) {
            Text("PAYS FOR")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
                .padding(.leading, 6)
            
            if services.isEmpty {
                Text("No linked services")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(Color(hex: "#111111"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
            } else {
                ForEach(Array(services.enumerated()), id: \.offset) { index, svc in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(svc.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.zifrGreen)
                                    .frame(width: 6, height: 6)
                                
                                Text("|")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.white.opacity(0.2))
                                
                                Text("Paid with \(card.name)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.6))
                            }
                        }
                        Spacer()
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("$\(String(format: "%.0f", svc.cost))")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("/mo")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#111111"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.05), lineWidth: 1))
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        row1
                        row2
                        row3
                        row4
                        row5
                        paysForRow
                    }
                    .padding(.vertical, 4)
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)

                // MARK: - Financial Details
                if !showFinancials {
                    Section {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showFinancials = true
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "banknote.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.35))
                                Text("SHOW FINANCIAL DETAILS")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.35))
                                Spacer()
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.25))
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 36)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    } header: { EmptyView() }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                    .listRowSeparator(.hidden)
                }

                if showFinancials {
                    Section {
                        VStack(spacing: 0) {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showFinancials = false
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                HStack {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.07))
                                        .frame(height: 1)
                                    Text("FINANCIALS")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.25))
                                        .fixedSize()
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.2))
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.bottom, 8)

                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    moneyField(label: "BALANCE", value: Binding(get: { card.balance }, set: { card.balance = $0 }))
                                    moneyField(label: "CREDIT LIMIT", value: Binding(get: { card.limit }, set: { card.limit = $0 }))
                                }

                                HStack(spacing: 12) {
                                    moneyField(label: "MO. PAYMENT", value: Binding(get: { card.moPayment }, set: { card.moPayment = $0 }))
                                    Color.clear.frame(maxWidth: .infinity)
                                }

                                if card.type == "Credit" {
                                    HStack(spacing: 12) {
                                        aprField(label: "APR%", value: $card.apr)
                                            .frame(maxWidth: .infinity)
                                            .frame(width: (UIScreen.main.bounds.width - 64) * 0.28)
                                        
                                        aprField(label: "PROMO APR%", value: $card.promoApr)
                                            .frame(maxWidth: .infinity)
                                            .frame(width: (UIScreen.main.bounds.width - 64) * 0.28)
                                        
                                        datePicker(label: "ENDS", selection: $card.promoEnds)
                                    }
                                }
                            }
                        }
                    } header: { EmptyView() }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowSeparator(.hidden)
                }

                // MARK: - Notes
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NOTES")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .padding(.leading, 6)
                        
                        TextField("Add notes...", text: Binding(get: { card.notes }, set: { card.notes = $0 }), axis: .vertical)
                            .lineLimit(3...6)
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Color(hex: "#111111"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
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
                                Image(systemName: "trash")
                                Text("Delete \(card.name.isEmpty ? "Card" : card.name)")
                                Spacer()
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.red)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .confirmationDialog("Delete Card?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                            Button("Delete Card", role: .destructive) {
                                vm.deleteCard(card, context: context)
                                dismiss()
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 20, trailing: 20))
                    .listRowSeparator(.hidden)
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
                            card.expiry = snap.expiry
                            card.notes = snap.notes
                            card.balance = snap.balance
                            card.limit = snap.limit
                            card.moPayment = snap.moPayment
                            card.apr = snap.apr
                            card.promoApr = snap.promoApr
                            card.promoEnds = snap.promoEnds
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
            .interactiveDismissDisabled(isNew)
            .sheet(isPresented: $showPaymentPicker) {
                NavigationStack {
                    PaymentMethodPickerView(
                        currentMethod: card.paidFrom,
                        institutions: institutions,
                        cards: cards
                    ) { method in
                        card.paidFrom = method
                    }
                }
            }
        }
    }

    private func datePicker(label: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            
            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 44)
        }
    }

    private func aprField(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            HStack(spacing: 4) {
                DoubleField(placeholder: "0.00", value: value)
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
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.borderless)
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
        var name, lender, term, role, status, interestType, scheduleFrequency: String
        var principalAmount, remainingBalance, monthlyPayment, interestRate: Double
        var termYears, termMonths: Int
        var startDate: Date
        var maturityDate, paidOffDate: Date?
    }
    @State private var snapshot: Snapshot?
    @State private var showAmortizationTable = false

    private var currentSnapshot: Snapshot {
        Snapshot(
            name: loan.name,
            lender: loan.lender,
            term: loan.term,
            role: loan.role,
            status: loan.status,
            interestType: loan.interestType,
            scheduleFrequency: loan.scheduleFrequency,
            principalAmount: loan.principalAmount,
            remainingBalance: loan.remainingBalance,
            monthlyPayment: loan.monthlyPayment,
            interestRate: loan.interestRate,
            termYears: loan.termYears,
            termMonths: loan.termMonths,
            startDate: loan.startDate,
            maturityDate: loan.maturityDate,
            paidOffDate: loan.paidOffDate
        )
    }

    private var isDirty: Bool {
        guard let snap = snapshot else { return isNew && !loan.name.trimmingCharacters(in: .whitespaces).isEmpty }
        return snap != currentSnapshot
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    loanSummarySection()
                    
                    loanRoleSection()
                    
                    VStack(spacing: 12) {
                        loanPrincipalSection()
                        loanPaymentsLedgerSection()
                    }
                    .padding(.horizontal, 20)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)

                    if !isNew {
                        Button(role: .destructive) {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("Delete \(loan.name.isEmpty ? "Loan" : loan.name)")
                                Spacer()
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.red)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                        .buttonStyle(.plain)
                        .confirmationDialog("Delete Loan?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                            Button("Delete Loan", role: .destructive) {
                                vm.deleteLoan(loan, context: context)
                                dismiss()
                            }
                            Button("Cancel", role: .cancel) {}
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
                            loan.role = snap.role
                            loan.status = snap.status
                            loan.interestType = snap.interestType
                            loan.scheduleFrequency = snap.scheduleFrequency
                            loan.principalAmount = snap.principalAmount
                            loan.remainingBalance = snap.remainingBalance
                            loan.monthlyPayment = snap.monthlyPayment
                            loan.interestRate = snap.interestRate
                            loan.termYears = snap.termYears
                            loan.termMonths = snap.termMonths
                            loan.startDate = snap.startDate
                            loan.maturityDate = snap.maturityDate
                            loan.paidOffDate = snap.paidOffDate
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
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.borderless)
    }

    private func datePicker(label: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            
            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 44)
        }
    }

    private func aprField(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            HStack(spacing: 4) {
                if loan.interestType == "Fixed" {
                    Text("$")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                DoubleField(placeholder: loan.interestType == "Fixed" ? "0" : "0.00", value: value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                if loan.interestType != "Fixed" {
                    Text("%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 10)
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

    @ViewBuilder
    private func loanSummarySection() -> some View {
        let amort = loan.amortization
        VStack(spacing: 20) {
            // Header Stats
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(loan.name.isEmpty ? "Loan" : loan.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text(loan.lender.isEmpty ? "Lender Unknown" : loan.lender)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(loan.principalAmount.currencyString)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(.white)
                    Text("PRINCIPAL")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            }
            
            // Progress Bar
            VStack(spacing: 8) {
                HStack {
                    Text("Principal: \(amort.totalPrincipal.currencyString)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.zifrGold)
                    Spacer()
                    Text("\(loan.interestType == "Fixed" ? "Fee" : "Interest"): \(amort.totalInterest.currencyString)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange)
                }
                
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.zifrGold)
                            .frame(width: geo.size.width * (amort.principalPct / 100))
                        Rectangle()
                            .fill(Color.orange)
                    }
                }
                .frame(height: 8)
                .clipShape(Capsule())
                .background(Color.white.opacity(0.05))
            }
            
            // Stats Grid
            GeometryReader { geo in
                HStack(spacing: 0) {
                    summaryStatColumn(label: "INTEREST", value: amort.totalInterest.currencyString, width: geo.size.width / 3)
                    summaryStatColumn(label: "TOTAL COST", value: amort.totalCost.currencyString, width: geo.size.width / 3)
                    summaryStatColumn(label: "MO. PAYMENT", value: amort.monthlyPayment.currencyString, width: geo.size.width / 3)
                }
            }
            .frame(height: 40)
            
            if !amort.schedule.isEmpty {
                VStack(spacing: 12) {
                    Divider().background(Color.white.opacity(0.05))
                        .padding(.vertical, 4)
                        
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showAmortizationTable.toggle()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text(showAmortizationTable ? "Hide Schedule" : "Amortization Schedule")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.6))
                                .textCase(.uppercase)
                                .tracking(1.5)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.6))
                                .rotationEffect(.degrees(showAmortizationTable ? 180 : 0))
                            Spacer()
                        }
                        .frame(height: 36)
                        .background(Color.white.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    
                    if showAmortizationTable {
                        VStack(spacing: 0) {
                            HStack {
                                Text(loan.scheduleFrequency == "Weekly" ? "WK" : (loan.scheduleFrequency == "Yearly" ? "YR" : "MO"))
                                    .frame(width: 30, alignment: .leading)
                                Text("PMT")
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text("PRIN")
                                    .foregroundStyle(Color.zifrGold)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text("INT")
                                    .foregroundStyle(Color.orange)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text("BAL")
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .textCase(.uppercase)
                            .tracking(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(hex: "#1C1C1E"))
                            
                            Divider().background(Color.white.opacity(0.05))
                            
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(amort.schedule) { row in
                                        HStack {
                                            Text("\(row.month)")
                                                .foregroundStyle(Color.white.opacity(0.5))
                                                .frame(width: 30, alignment: .leading)
                                            Text("$\(Int(round(row.payment)))")
                                                .foregroundStyle(Color.white.opacity(0.9))
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                            Text("$\(Int(round(row.principal)))")
                                                .foregroundStyle(Color.zifrGold.opacity(0.8))
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                            Text("$\(Int(round(row.interest)))")
                                                .foregroundStyle(Color.orange.opacity(0.8))
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                            Text("$\(Int(round(row.balance)))")
                                                .foregroundStyle(Color.white)
                                                .fontWeight(.bold)
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                        }
                                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        
                                        if row.month != amort.schedule.last?.month {
                                            Divider().background(Color.white.opacity(0.03))
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 250)
                            .background(Color.black.opacity(0.2))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.03), lineWidth: 1))
                    }
                }
            }
        }
        .padding(24)
        .background(Color(hex: "#111111"))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.05), lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func summaryStatColumn(label: String, value: String, width: CGFloat) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .black))
                .tracking(1)
                .foregroundStyle(Color.white.opacity(0.4))
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: width)
    }

    @ViewBuilder
    private func loanRoleSection() -> some View {
        Picker("Role", selection: $loan.role) {
            ForEach(Loan.roles, id: \.self) { role in
                Text(role).tag(role)
            }
        }
        .pickerStyle(.segmented)
        .frame(height: 44)
        .padding(.horizontal, 20)
        .disabled(!isNew)
    }


    @ViewBuilder
    private func loanPrincipalSection() -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZifrField(
                    label: loan.role == "Lender" ? "LENT TO" : "LENDER", 
                    placeholder: loan.role == "Lender" ? "e.g. Acme Corp" : "e.g. Chase", 
                    text: $loan.lender
                )
                ZifrField(
                    label: loan.role == "Lender" ? "LOAN NAME" : "LOAN ID", 
                    placeholder: loan.role == "Lender" ? "e.g. Bridge Loan" : "e.g. Series A", 
                    text: $loan.name
                )
            }
            
            GeometryReader { geo in
                HStack(spacing: 12) {
                    moneyField(label: "PRINCIPAL", value: $loan.principalAmount)
                        .frame(width: geo.size.width * 0.3 - 6)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LOAN TERM")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.5))
                        HStack(spacing: 0) {
                            Picker("Years", selection: $loan.termYears) {
                                ForEach(0...30, id: \.self) { year in Text("\(year) \(year == 1 ? "Year" : "Years")").tag(year) }
                            }
                            .labelsHidden().tint(.white).frame(maxWidth: .infinity)
                            
                            Divider().background(Color.white.opacity(0.1)).padding(.vertical, 8)
                            
                            Picker("Months", selection: $loan.termMonths) {
                                ForEach(0...11, id: \.self) { month in Text("\(month) \(month == 1 ? "Month" : "Months")").tag(month) }
                            }
                            .labelsHidden().tint(.white).frame(maxWidth: .infinity)
                        }
                        .frame(height: 44)
                        .background(Color(hex: "#111111"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                    .frame(width: geo.size.width * 0.7 - 6)
                }
            }
            .frame(height: 64)
            
            if loan.role == "Lender" {
                HStack(spacing: 12) {
                    loanPicker(label: "INTEREST TYPE", sel: $loan.interestType, opts: Loan.interestTypes)
                }
            }
            
            HStack(spacing: 12) {
                aprField(label: loan.interestType == "Fixed" ? "FIXED FEE" : "YR APR", value: $loan.interestRate)
                loanPicker(label: "PAYMENT FREQUENCY", sel: $loan.scheduleFrequency, opts: Loan.frequencies)
            }
            
            HStack(spacing: 12) {
                datePicker(label: "START DATE", selection: $loan.startDate)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("MATURITY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.5))
                    
                    if let selection = Binding($loan.maturityDate) {
                        DatePicker("", selection: selection, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 44)
                    } else {
                        Button {
                            loan.maturityDate = Date()
                        } label: {
                            Text("Set Date")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.zifrGold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 44)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }

    @ViewBuilder
    private func loanPaymentsLedgerSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("PAYMENT LEDGER")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .tracking(1)
                
                Spacer()
                
                Button {
                    withAnimation {
                        let pmt = LoanPayment()
                        loan.payments.append(pmt)
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.zifrGold)
                        .padding(6)
                        .background(Color.zifrGold.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Text("DATE")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("AMOUNT")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text("FROM")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text("TOTAL")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.4))
                .textCase(.uppercase)
                .tracking(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(hex: "#1C1C1E"))
                
                Divider().background(Color.white.opacity(0.05))
                
                if loan.payments.isEmpty {
                    Text("No payments recorded yet.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ForEach($loan.payments) { $payment in
                        HStack(spacing: 4) {
                            DatePicker("", selection: $payment.date, displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .scaleEffect(0.75, anchor: .leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            TextField("0.00", value: $payment.amount, format: .currency(code: "USD"))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(maxWidth: .infinity)
                            
                            TextField("Source", text: $payment.source)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: .infinity)
                            
                            Text(payment.amount.currencyString)
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(Color.zifrGold)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        
                        if payment.id != loan.payments.last?.id {
                            Divider().background(Color.white.opacity(0.05))
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.03), lineWidth: 1))
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}
