import SwiftUI

struct FinancialView: View {
    let company: Company
    let cards: [FinancialCard]
    let institutions: [Institution]
    let loans: [Loan]
    @Bindable var vm: AppViewModel
    @Environment(AppState.self) private var appState

    @State private var editingCard: FinancialCard? = nil
    @State private var editingInst: Institution? = nil
    @State private var editingLoan: Loan? = nil
    @State private var newCard: FinancialCard? = nil
    @State private var newInst: Institution? = nil
    @State private var newLoan: Loan? = nil
    @State private var showWizard = false
    @State private var wizardInstitution: Institution? = nil
    @State private var shareResourceId: UUID = UUID()
    @State private var shareResourceType: String = "all_financials"
    @State private var shareResourceTitle: String = "All Financials"
    @State private var showShareSheet = false
    @State private var poppedCardId: String? = nil
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
            VStack(spacing: 0) {
                // ── Action Bar ──
                HStack(spacing: 0) {
                    HStack(spacing: 6) {
                        Image(systemName: "dollarsign.bank.building")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color(hex: "#A2A2A2"))
                        Text("Financial")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: "#A2A2A2"))
                    }
                    .padding(.leading, 16)

                    Spacer()

                    Menu {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            shareResourceId = company.id
                            shareResourceType = "all_financials"
                            shareResourceTitle = "All Financials"
                            showShareSheet = true
                        } label: {
                            Label("All Financials", systemImage: "folder.badge.person.crop")
                        }
                        
                        if !institutions.isEmpty {
                            Section("Institutions") {
                                ForEach(institutions) { inst in
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        shareResourceId = inst.id
                                        shareResourceType = "institution"
                                        shareResourceTitle = inst.name.isEmpty ? "Institution" : inst.name
                                        showShareSheet = true
                                    } label: {
                                        Label(inst.name.isEmpty ? "Unnamed" : inst.name, systemImage: "person.crop.circle.badge.plus")
                                    }
                                }
                            }
                        }
                        if !cards.isEmpty {
                            Section("Cards") {
                                ForEach(cards) { card in
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        shareResourceId = card.id
                                        shareResourceType = "card"
                                        shareResourceTitle = card.name.isEmpty ? "Card" : card.name
                                        showShareSheet = true
                                    } label: {
                                        Label(card.name.isEmpty ? "Unnamed" : card.name, systemImage: "person.crop.circle.badge.plus")
                                    }
                                }
                            }
                        }
                        if !loans.isEmpty {
                            Section("Loans") {
                                ForEach(loans) { loan in
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        shareResourceId = loan.id
                                        shareResourceType = "loan"
                                        shareResourceTitle = loan.name.isEmpty ? "Loan" : loan.name
                                        showShareSheet = true
                                    } label: {
                                        Label(loan.name.isEmpty ? "Unnamed" : loan.name, systemImage: "person.crop.circle.badge.plus")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color(hex: "#A2A2A2"))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }

                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 1, height: 20)

                    Menu {
                        Button {
                            wizardInstitution = Institution(userId: company.userId, companyId: company.id)
                            showWizard = true
                        } label: {
                            Label("Add Account", systemImage: "building.columns")
                        }
                        if !institutions.isEmpty {
                            Button {
                                newCard = vm.addCard(appState: appState, userId: company.userId, companyId: company.id)
                            } label: {
                                Label("Add Card", systemImage: "creditcard")
                            }
                            Button {
                                newLoan = vm.addLoan(appState: appState, userId: company.userId, companyId: company.id)
                            } label: {
                                Label("Add Loan", systemImage: "dollarsign.circle")
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("ADD ACCOUNT").font(.system(size: 13, weight: .bold)).tracking(1).foregroundStyle(.white)
                            Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.white.opacity(0.5))
                        }
                        .frame(width: 164, height: 44)
                        .contentShape(Rectangle())
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "#1C1C1E").opacity(0.70))
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 16)
                
                // ── Main Wallet Stack ──
                LazyVStack(spacing: 20) {
                    if institutions.isEmpty && cards.isEmpty && loans.isEmpty {
                        // Empty State — dummy Amex wallet with glass overlay
                        let dummyAmex = Institution(
                            id: UUID(),
                            userId: UUID(),
                            companyId: UUID(),
                            name: "American Express",
                            loginUrl: "americanexpress.com",
                            username: "founder@company.com",
                            password: "••••••••",
                            accounts: [
                                InstitutionAccount(name: "Amex Platinum", type: "Credit Card", last4: "1005", balance: 0, limit: 25000)
                            ]
                        )
                        let dummyCard1 = FinancialCard(
                            id: UUID(),
                            userId: UUID(),
                            companyId: UUID(),
                            name: "Amex Platinum",
                            institutionName: "American Express",
                            cardHolder: "Jane Founder",
                            last4: "1005",
                            expiry: "09/27",
                            network: "Amex",
                            type: "Credit",
                            limit: 25000,
                            autopay: "Yes",
                            apr: 29.99
                        )
                        
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            wizardInstitution = Institution(userId: company.userId, companyId: company.id)
                            showWizard = true
                        } label: {
                            ZStack {
                                // Dummy wallet stack
                                VStack(spacing: 0) {
                                    ZStack(alignment: .top) {
                                        FinancialCardVisual(card: dummyCard1, isPopped: false)
                                            .frame(height: 110)
                                            .offset(y: -36)
                                            .zIndex(2)
                                        InstitutionCardView(
                                            institution: dummyAmex,
                                            totalMonthlyPayment: 0,
                                            cardCount: 1,
                                            loanCount: 0,
                                            loans: [],
                                            vm: vm,
                                            onEdit: {},
                                            onEditLoan: { _ in }
                                        )
                                        .zIndex(3)
                                    }
                                    .padding(.top, 36)
                                }
                                .allowsHitTesting(false)
                                .blur(radius: 3)
                                
                                // Glass overlay
                                VStack(spacing: 16) {
                                    Image(systemName: "dollarsign.bank.building")
                                        .font(.system(size: 28))
                                        .foregroundStyle(.white)
                                    Text("ADD YOUR FIRST INSTITUTION")
                                        .font(.system(size: 11, weight: .black))
                                        .textCase(.uppercase)
                                        .tracking(2)
                                        .foregroundStyle(.white)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 24))
                            }
                        }
                        .padding(.top, 40)
                    } else {
                        // Institutions Block
                        if !institutions.isEmpty {
                                ForEach(institutions) { inst in
                                    let instCards = cards.filter { ($0.institutionName ?? "").lowercased() == inst.name.lowercased() }
                                    let instLoans = loans.filter { ($0.lender ?? "").lowercased() == inst.name.lowercased() }
                                    walletStackForInstitution(inst: inst, instCards: instCards, instLoans: instLoans)
                                }
                            }
                        
                        // Remaining standalone accounts block
                        let standaloneCards = cards.filter { c in !institutions.contains { ($0.name ?? "").lowercased() == (c.institutionName ?? "").lowercased() } }
                        let standaloneLoans = loans.filter { l in !institutions.contains { ($0.name ?? "").lowercased() == (l.lender ?? "").lowercased() } }
                        
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
                                        .id(loan.id)
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
        .sheet(isPresented: $showShareSheet) {
            ShareEntitySheet(resourceId: shareResourceId, resourceType: shareResourceType, resourceTitle: shareResourceTitle)
        }
        .sheet(isPresented: $showWizard) {
            if let inst = wizardInstitution {
                AddFinancialWizard(institution: inst, vm: vm)
            }
        }
        .sheet(item: $newInst) { i in EditInstitutionSheet(institution: i, institutions: institutions, cards: cards, loans: loans, vm: vm, isNew: true) }
        .sheet(item: $editingInst) { i in EditInstitutionSheet(institution: i, institutions: institutions, cards: cards, loans: loans, vm: vm, isNew: false) }
        .sheet(item: $newCard) { c in EditCardSheet(card: c, vm: vm, institutions: institutions, cards: cards, isNew: true) }
        .sheet(item: $editingCard) { c in EditCardSheet(card: c, vm: vm, institutions: institutions, cards: cards, isNew: false) }
        .sheet(item: $newLoan) { l in EditLoanSheet(loan: l, vm: vm, isNew: true, institutions: institutions, cards: cards) }
        .sheet(item: $editingLoan) { l in EditLoanSheet(loan: l, vm: vm, isNew: false, institutions: institutions, cards: cards) }
        .onChange(of: vm.deepLinkModelId) { _, newValue in
            handleDeepLink(id: newValue, proxy: proxy)
        }
        .onAppear {
            handleDeepLink(id: vm.deepLinkModelId, proxy: proxy)
        }
        }
    }
    
    private func handleDeepLink(id: UUID?, proxy: ScrollViewProxy) {
        guard let id = id else { return }
        if let c = cards.first(where: { $0.id == id }) {
            poppedCardId = c.id.uuidString
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    proxy.scrollTo(c.id, anchor: .center)
                }
            }
            vm.deepLinkModelId = nil
        } else if let i = institutions.first(where: { $0.id == id }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    proxy.scrollTo(i.id, anchor: .center)
                }
            }
            vm.deepLinkModelId = nil
        } else if let l = loans.first(where: { $0.id == id }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    proxy.scrollTo(l.id, anchor: .center)
                }
            }
            vm.deepLinkModelId = nil
        }
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
        let fullCardH: CGFloat = 210
        
        ZStack(alignment: .top) {
            if !instCards.isEmpty {
                ForEach(Array(instCards.enumerated()), id: \.element.id) { index, card in
                    let isPopped = poppedCardId == card.id.uuidString
                    let yOffset = isPopped ? 16.0 : -(peekOffset + CGFloat(index) * peekOffset)
                    let scale = isPopped ? 1.02 : max(0.88, 1.0 - CGFloat(index) * 0.03)
                    let rotationAngle: Double = isPopped ? 0 : -4 - Double(index) * 1.5
                    let shadowRadius: CGFloat = isPopped ? 20 : 4
                    let shadowOpacity: Double = isPopped ? 0.5 : 0.15
                    
                    FinancialCardVisual(card: card, isPopped: isPopped)
                        .id(card.id)
                        .frame(height: isPopped ? fullCardH : cardH)
                        .scaleEffect(scale, anchor: .bottom)
                        .rotation3DEffect(
                            .degrees(rotationAngle),
                            axis: (x: 1, y: 0, z: 0),
                            anchor: .bottom,
                            perspective: 0.3
                        )
                        .offset(y: yOffset)
                        .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, y: isPopped ? 12 : 2)
                        .zIndex(isPopped ? 25 : Double(instCards.count - index))
                        .animation(
                            isPopped
                                ? .spring(response: 0.55, dampingFraction: 0.78, blendDuration: 0.1)
                                : .spring(response: 0.4, dampingFraction: 0.82, blendDuration: 0.05),
                            value: isPopped
                        )
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.8),
                            value: poppedCardId
                        )
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if poppedCardId == card.id.uuidString { poppedCardId = nil } else { poppedCardId = card.id.uuidString }
                        }
                        .onLongPressGesture {
                            editingCard = card
                        }
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 10)
                                .onEnded { value in
                                    if isPopped && value.translation.height < -10 {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        poppedCardId = nil
                                    }
                                },
                            including: isPopped ? .gesture : .none
                        )
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
            .id(inst.id)
            .zIndex(20)
        }
        .padding(.top, instCards.isEmpty ? 0 : CGFloat(instCards.count) * peekOffset + 16)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func standaloneWalletStack(cards: [FinancialCard]) -> some View {
        let peekOffset: CGFloat = 36
        let fullCardH: CGFloat = 210
        
        if !cards.isEmpty {
            ZStack(alignment: .bottom) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    let isPopped = poppedCardId == card.id.uuidString
                    let yOffset = isPopped ? 0.0 : -(CGFloat(index) * peekOffset)
                    let scale = isPopped ? 1.02 : max(0.88, 1.0 - CGFloat(index) * 0.03)
                    let rotationAngle: Double = isPopped ? 0 : -3 - Double(index) * 1.0
                    let shadowRadius: CGFloat = isPopped ? 20 : 4
                    let shadowOpacity: Double = isPopped ? 0.5 : 0.15
                    
                    FinancialCardVisual(card: card, isPopped: isPopped)
                        .id(card.id)
                        .frame(height: fullCardH)
                        .scaleEffect(scale, anchor: .bottom)
                        .rotation3DEffect(
                            .degrees(rotationAngle),
                            axis: (x: 1, y: 0, z: 0),
                            anchor: .bottom,
                            perspective: 0.3
                        )
                        .offset(y: yOffset)
                        .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, y: isPopped ? 12 : 2)
                        .zIndex(isPopped ? 150 : Double(cards.count - index))
                        .animation(
                            isPopped
                                ? .spring(response: 0.55, dampingFraction: 0.78, blendDuration: 0.1)
                                : .spring(response: 0.4, dampingFraction: 0.82, blendDuration: 0.05),
                            value: isPopped
                        )
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.8),
                            value: poppedCardId
                        )
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if poppedCardId == card.id.uuidString { poppedCardId = nil } else { poppedCardId = card.id.uuidString }
                        }
                        .onLongPressGesture {
                            editingCard = card
                        }
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 10)
                                .onEnded { value in
                                    if isPopped && value.translation.height < -10 {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        poppedCardId = nil
                                    }
                                },
                            including: isPopped ? .gesture : .none
                        )
                }
                
                // Front Leather Sleeve
                WalletSleeveView()
                    .zIndex(100)
                    .allowsHitTesting(false)
            }
            .padding(.top, CGFloat(max(0, cards.count - 1)) * peekOffset + 4)
            .padding(.bottom, 16)
        }
    }
}

