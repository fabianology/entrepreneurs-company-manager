import SwiftUI

struct FinancialView: View {
    let company: Company
    let cards: [FinancialCard]
    let institutions: [Institution]
    let loans: [Loan]
    @Bindable var vm: AppViewModel
    var hideActionBar: Bool = false
    var canEdit: Bool = true
    var canAccessCredentials: Bool = true
    
    @Environment(AppState.self) private var appState
    @Environment(AuthViewModel.self) private var authVM
    @Environment(OnboardingStateManager.self) private var onboardingState

    private func canEditResource(_ type: String, _ id: UUID) -> Bool {
        AppViewModel.resourceAllowsEdit(
            appState.resourceShares, actorID: appState.portfolioUserID,
            ownerID: company.userId, companyID: company.id,
            resourceType: type, resourceID: id, ownerCanEdit: canEdit
        )
    }

    private var editableInstitutionIDs: Set<UUID> {
        Set(institutions.filter { canEditResource("institution", $0.id) }.map(\.id))
    }

    private func canCreate(_ type: String) -> Bool {
        AppViewModel.resourceAllowsCreation(
            appState.resourceShares, actorID: appState.portfolioUserID,
            ownerID: company.userId, companyID: company.id,
            resourceType: type, ownerCanEdit: canEdit
        )
    }

    private var canCreateFinancialItem: Bool {
        ["institution", "card", "loan"].contains { canCreate($0) }
    }

    private func beginInstitutionCreation() {
        guard canCreate("institution") else { return }
        let draft = Institution(userId: company.userId, companyId: company.id)
        if appState.portfolioUserID == company.userId { wizardInstitution = draft }
        else { newInst = draft }
    }

    private var editableCardIDs: Set<UUID> {
        Set(cards.filter { canEditResource("card", $0.id) }.map(\.id))
    }

    private var editableLoanIDs: Set<UUID> {
        Set(loans.filter { canEditResource("loan", $0.id) }.map(\.id))
    }

    private var canManageSharing: Bool {
        guard let userId = authVM.currentUser?.id else { return false }
        if company.userId == userId { return true }
        return appState.resourceShares.contains {
            $0.userId == userId && $0.resourceId == company.id
                && $0.resourceType == "company" && $0.role == "Admin"
        }
    }

    @State private var editingCard: FinancialCard? = nil
    @State private var editingInst: Institution? = nil
    @State private var editingLoan: Loan? = nil
    @State private var newCard: FinancialCard? = nil
    @State private var newInst: Institution? = nil
    @State private var newLoan: Loan? = nil
    @State private var wizardInstitution: Institution? = nil
    @State private var shareResourceId: UUID = UUID()
    @State private var shareResourceType: String = "all_financials"
    @State private var shareResourceTitle: String = "All Financials"
    @State private var showShareSheet = false
    @State private var poppedCardId: String? = nil
    @State private var pullingUpCardId: String? = nil
    @State private var zIndexCardId: String? = nil
    @State private var paymentLoan: Loan? = nil
    @State private var paymentDraft = LoanPayment(id: UUID(), userId: UUID(), loanId: UUID(), date: Date(), amount: 0.0)
    @State private var showLoanPaymentHUD = false
    @State private var activeStandaloneLoansExpanded = false
    @State private var paidOffStandaloneLoansExpanded = false
    
    var body: some View {
        ZStack(alignment: .top) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // ── Main Wallet Stack ──
                        VStack(spacing: 0) {
                            Spacer().frame(height: hideActionBar ? 82 : 70) // Offset for tabs (82) or action bar (70) to maintain consistent 20pt card gap
                            if institutions.isEmpty && cards.isEmpty && loans.isEmpty {
                        // Empty State — dummy wallet
                        let dummyAmexId = UUID()
                        let dummyCard1Id = UUID()
                        let dummyCard2Id = UUID()

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
                            id: dummyCard1Id,
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
                        let dummyCard2 = FinancialCard(
                            id: dummyCard2Id,
                            userId: UUID(),
                            companyId: UUID(),
                            name: "Chase Sapphire Reserve",
                            institutionName: "Chase Bank",
                            cardHolder: "Jane Founder",
                            last4: "4242",
                            expiry: "03/28",
                            network: "Visa",
                            type: "Credit",
                            limit: 10000,
                            autopay: "Yes",
                            apr: 22.99
                        )
                        let dummyChase = Institution(
                            id: UUID(),
                            userId: UUID(),
                            companyId: UUID(),
                            name: "Chase Bank",
                            loginUrl: "chase.com",
                            username: "founder@company.com",
                            password: "••••••••",
                            accounts: [
                                InstitutionAccount(name: "Sapphire Reserve", type: "Credit Card", last4: "4242", balance: 0, limit: 10000)
                            ]
                        )
                        let dummyLoan = Loan(
                            id: UUID(),
                            userId: UUID(),
                            companyId: UUID(),
                            role: "Bank Loan",
                            lender: "Chase Bank",
                            name: "SBA Startup Loan",
                            principalAmount: 50000,
                            remainingBalance: 38500,
                            interestRate: 6.5,
                            monthlyPayment: 825
                        )

                    if onboardingState.isInFinancialTutorial {
                            // Tutorial mode: show full dummy wallet un-blurred
                            VStack(spacing: 20) {
                                // Amex wallet stack
                                VStack(spacing: 0) {
                                    ZStack(alignment: .top) {
                                        let isPopped = poppedCardId == dummyCard1Id.uuidString
                                        FinancialCardVisual(card: dummyCard1, isPopped: isPopped)
                                            .frame(height: isPopped ? 210 : 110)
                                            .offset(y: isPopped ? 16 : -20)
                                            .zIndex(2)
                                            .animation(.spring(response: 0.55, dampingFraction: 0.78), value: isPopped)
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
                                    .padding(.top, 20)
                                }
                                .background(
                                    GeometryReader { geo in
                                        Color.clear
                                            .onAppear {
                                                onboardingState.tutorialFinancialWalletFrame = geo.frame(in: .global)
                                            }
                                            .onChange(of: geo.frame(in: .global)) { _, newFrame in
                                                onboardingState.tutorialFinancialWalletFrame = newFrame
                                            }
                                    }
                                )

                                // Chase wallet stack with loan
                                VStack(spacing: 0) {
                                    ZStack(alignment: .top) {
                                        FinancialCardVisual(card: dummyCard2, isPopped: false)
                                            .frame(height: 110)
                                            .offset(y: -20)
                                            .zIndex(2)
                                        InstitutionCardView(
                                            institution: dummyChase,
                                            totalMonthlyPayment: dummyLoan.monthlyPayment,
                                            cardCount: 1,
                                            loanCount: 1,
                                            loans: [dummyLoan],
                                            vm: vm,
                                            onEdit: {},
                                            onEditLoan: { _ in }
                                        )
                                        .zIndex(3)
                                        .background(
                                            GeometryReader { geo in
                                                Color.clear
                                                    .onAppear {
                                                        onboardingState.tutorialFinancialInstitutionFrame = geo.frame(in: .global)
                                                    }
                                                    .onChange(of: geo.frame(in: .global)) { _, newFrame in
                                                        onboardingState.tutorialFinancialInstitutionFrame = newFrame
                                                    }
                                            }
                                        )
                                    }
                                    .padding(.top, 20)
                                }
                            }
                            .allowsHitTesting(false)
                            .padding(.top, 40)
                            .id("tutorialWallet")
                        } else if canCreate("institution") {
                            VStack(spacing: 0) {
                                Button {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    beginInstitutionCreation()
                                } label: {
                                    DynamicGlassCard(cornerRadius: 24, height: 215) {
                                        VStack(spacing: 16) {
                                            ZifrPlusCircle(size: 44, iconSize: 18)
                                            
                                            VStack(spacing: 6) {
                                                Text(appState.portfolioUserID == company.userId ? "CONNECT FINANCIAL INSTITUTION" : "ADD INSTITUTION MANUALLY")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .textCase(.uppercase)
                                                    .tracking(2)
                                                    .foregroundStyle(.white)
                                                
                                                Text(appState.portfolioUserID == company.userId ? "Link accounts, credit cards and loans" : "Add a manual record within your shared access")
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundStyle(Color.white.opacity(0.6))
                                                    .tracking(0.5)
                                            }
                                        }
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 24)
                                    }
                                    .padding(.horizontal, 20)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 24)
                                .spotlightTarget(isActive: onboardingState.isSpotlightingBank)
                            }
                        } else {
                            readOnlyEmptyState
                        }
                    } else {
                        // Institutions Block
                        if !institutions.isEmpty {
                            StackedInstitutionDeckView(
                                institutions: institutions,
                                cards: cards,
                                loans: loans,
                                vm: vm,
                                editableInstitutionIDs: editableInstitutionIDs,
                                editableCardIDs: editableCardIDs,
                                editableLoanIDs: editableLoanIDs,
                                canAccessCredentials: canAccessCredentials,
                                onEditInst: { if canEditResource("institution", $0.id) { editingInst = $0 } },
                                onEditCard: { if canEditResource("card", $0.id) { editingCard = $0 } },
                                onEditLoan: { if canEditResource("loan", $0.id) { editingLoan = $0 } }
                            )
                        }
                        
                        // Remaining standalone accounts block
                        let relationships = InstitutionRelationships(institutions: institutions, cards: cards, loans: loans,
                            connections: appState.resourceConnections, companyOverrides: appState.localCompanyOverrides)
                        let standaloneCards = cards.filter { relationships.banks(for: .card, id: $0.id).isEmpty }
                        let standaloneLoans = loans.filter { relationships.banks(for: .loan, id: $0.id).isEmpty }
                        let activeStandaloneLoans = standaloneLoans
                            .filter { !isLoanPaidOff($0) }
                            .sorted { ($0.maturityDate ?? .distantFuture) < ($1.maturityDate ?? .distantFuture) }
                        let paidOffStandaloneLoans = standaloneLoans
                            .filter { isLoanPaidOff($0) }
                            .sorted { ($0.paidOffDate ?? .distantPast) > ($1.paidOffDate ?? .distantPast) }
                        
                        if !standaloneCards.isEmpty || !standaloneLoans.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                if !standaloneCards.isEmpty {
                                    standaloneSectionHeading(
                                        "Standalone Cards",
                                        topPadding: 10
                                    )
                                    standaloneWalletStack(cards: standaloneCards)
                                }

                                if !standaloneLoans.isEmpty {
                                    standaloneSectionHeading(
                                        "Standalone Loans",
                                        topPadding: standaloneCards.isEmpty ? 10 : 0
                                    )
                                    standaloneLoanDeck(
                                        activeLoans: activeStandaloneLoans,
                                        paidOffLoans: paidOffStandaloneLoans
                                    )
                                }
                            }
                        }
                        
                        // Match Services: keep the final item fully above the floating search/action controls.
                        Spacer().frame(height: 120)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .scrollIndicators(.hidden)
        .onChange(of: onboardingState.currentStep) { _, step in
            // Scroll wallet into view for tutorial steps 11-13
            switch step {
            case .tutorialFinancialPage, .tutorialFinancialWallet,
                 .tutorialFinancialCardTap:
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo("tutorialWallet", anchor: .center)
                    }
                }
            default: break
            }
            // Auto-pop the first dummy card to illustrate expanded state
            if step == .tutorialFinancialCardTap {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                        poppedCardId = "tutorial-popped"
                    }
                }
            } else if step != .tutorialFinancialWallet {
                poppedCardId = nil
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareEntitySheet(resourceId: shareResourceId, resourceType: shareResourceType, resourceTitle: shareResourceTitle)
        }
        .sheet(item: $wizardInstitution) { inst in
            AddFinancialWizard(institution: inst, vm: vm, allInstitutions: institutions)
        }
        .sheet(item: $newInst) { i in EditInstitutionSheet(institution: i, institutions: institutions, cards: cards, loans: loans, vm: vm, isNew: true) }
        .sheet(item: $editingInst) { i in EditInstitutionSheet(institution: i, institutions: institutions, cards: cards, loans: loans, vm: vm, isNew: false) }
        .sheet(item: $newCard) { c in EditCardSheet(card: c, vm: vm, institutions: institutions, cards: cards, isNew: true) }
        .sheet(item: $editingCard) { c in EditCardSheet(card: c, vm: vm, institutions: institutions, cards: cards, isNew: false) }
        .sheet(item: $newLoan) { l in EditLoanSheet(loan: l, vm: vm, isNew: true, institutions: institutions, cards: cards) }
        .sheet(item: $editingLoan) { l in EditLoanSheet(loan: l, vm: vm, isNew: false, institutions: institutions, cards: cards) }
        .sheet(isPresented: $showLoanPaymentHUD) {
            if let pLoan = paymentLoan {
                LoanPaymentHUD(
                    draft: $paymentDraft,
                    isNew: true,
                    institutions: institutions,
                    cards: cards,
                    onSave: {
                        guard canEditResource("loan", pLoan.id) else { return }
                        var updatedLoan = pLoan
                        if updatedLoan.payments == nil { updatedLoan.payments = [] }
                        updatedLoan.payments?.append(paymentDraft)
                        updatedLoan.recalculateBalance()
                        if updatedLoan.remainingBalance <= 0 {
                            updatedLoan.status = "Paid Off"
                            updatedLoan.paidOffDate = Date()
                        }
                        vm.saveLoan(updatedLoan, appState: appState)
                        showLoanPaymentHUD = false
                        paymentLoan = nil
                    },
                    onCancel: {
                        showLoanPaymentHUD = false
                        paymentLoan = nil
                    }
                )
                .presentationDetents([.fraction(0.70), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
        }
        .onChange(of: vm.deepLinkModelId) { _, newValue in
            handleDeepLink(id: newValue, proxy: proxy)
        }
        .onAppear {
            handleDeepLink(id: vm.deepLinkModelId, proxy: proxy)
            // If we land on the financial tab during a wallet tutorial step, scroll into view
            let step = onboardingState.currentStep
            switch step {
            case .tutorialFinancialPage, .tutorialFinancialWallet, .tutorialFinancialCardTap:
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo("tutorialWallet", anchor: .center)
                    }
                }
            default: break
            }
            }
        }
            
            if !hideActionBar && (canCreateFinancialItem || canManageSharing) {
                financialActionBar
                    .zIndex(100)
            }
        }
        .frame(width: UIScreen.main.bounds.width)
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
            if isLoanPaidOff(l) {
                paidOffStandaloneLoansExpanded = true
            } else {
                activeStandaloneLoansExpanded = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    proxy.scrollTo(l.id, anchor: .center)
                }
            }
            vm.deepLinkModelId = nil
        }
    }

    private func isLoanPaidOff(_ loan: Loan) -> Bool {
        loan.status == "Paid Off"
            || (loan.principalAmount > 0 && loan.remainingBalance <= 0.005)
    }
    
    private func togglePop(for cardId: String) {
        if poppedCardId == cardId {
            // Collapsing the current card
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                pullingUpCardId = cardId
                poppedCardId = nil
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                if pullingUpCardId == cardId {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        pullingUpCardId = nil
                        zIndexCardId = nil
                    }
                }
            }
        } else {
            // If another card is popped, collapse it first
            let oldPoppedId = poppedCardId
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            
            if let oldId = oldPoppedId {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    pullingUpCardId = cardId
                    poppedCardId = nil
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    if pullingUpCardId == cardId {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            poppedCardId = cardId
                            zIndexCardId = cardId
                            pullingUpCardId = nil
                        }
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    if zIndexCardId == oldId {
                        zIndexCardId = nil
                    }
                }
            } else {
                // Standard pop open X (no card was popped)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    pullingUpCardId = cardId
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    if pullingUpCardId == cardId {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            poppedCardId = cardId
                            zIndexCardId = cardId
                            pullingUpCardId = nil
                        }
                    }
                }
            }
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
        let foremostPeekOffset: CGFloat = 20
        let stackedPeekOffset: CGFloat = 40
        let cardH: CGFloat = 110
        let fullCardH: CGFloat = 210
        
        ZStack(alignment: .top) {
            if !instCards.isEmpty {
                ForEach(Array(instCards.enumerated()), id: \.element.id) { index, card in
                    let isPopped = poppedCardId == card.id.uuidString
                    let isPulling = pullingUpCardId == card.id.uuidString
                    let isFront = zIndexCardId == card.id.uuidString
                    
                    let yOffset = isPopped ? 16.0 : (isPulling ? -140.0 : -(foremostPeekOffset + CGFloat(index) * stackedPeekOffset))
                    let scale = (isPopped || isPulling) ? 1.0 : max(0.88, 1.0 - CGFloat(index) * 0.03)
                    let rotationAngle: Double = isPopped ? 0 : (isPulling ? -1.0 : -4 - Double(index) * 1.5)
                    let shadowRadius: CGFloat = (isPopped || isPulling) ? 20 : 4
                    let shadowOpacity: Double = (isPopped || isPulling) ? 0.5 : 0.15
                    let zIndex = (isPopped || isFront) ? 25.0 : Double(instCards.count - index)
                    
                    FinancialCardVisual(card: card, isPopped: isPopped, canAccessCredentials: canAccessCredentials)
                        .id(card.id)
                        .frame(maxWidth: UIScreen.main.bounds.width - 40)
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
                        .zIndex(zIndex)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: poppedCardId)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: pullingUpCardId)
                        .onTapGesture {
                            togglePop(for: card.id.uuidString)
                        }
                        .onLongPressGesture {
                            if canEditResource("card", card.id) { editingCard = card }
                        }
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 10)
                                .onEnded { value in
                                    if isPopped && value.translation.height < -10 {
                                        togglePop(for: card.id.uuidString)
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
                onEdit: { if canEditResource("institution", inst.id) { editingInst = inst } },
                onEditLoan: { if canEditResource("loan", $0.id) { editingLoan = $0 } },
                canEdit: canEditResource("institution", inst.id),
                editableLoanIDs: editableLoanIDs,
                canAccessCredentials: canAccessCredentials
            )
            .id(inst.id)
            .zIndex(20)
        }
        .padding(.top, instCards.isEmpty ? 0 : (foremostPeekOffset + CGFloat(instCards.count - 1) * stackedPeekOffset) + 16)
        .padding(.bottom, 24)
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
                    let scale = isPopped ? 1.0 : max(0.88, 1.0 - CGFloat(index) * 0.03)
                    let rotationAngle: Double = isPopped ? 0 : -3 - Double(index) * 1.0
                    let shadowRadius: CGFloat = isPopped ? 20 : 4
                    let shadowOpacity: Double = isPopped ? 0.5 : 0.15
                    
                    FinancialCardVisual(card: card, isPopped: isPopped, canAccessCredentials: canAccessCredentials)
                        .id(card.id)
                        .frame(maxWidth: UIScreen.main.bounds.width - 40)
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
                            if poppedCardId == card.id.uuidString {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                poppedCardId = nil
                            } else {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                poppedCardId = card.id.uuidString
                            }
                        }
                        .onLongPressGesture {
                            if canEditResource("card", card.id) { editingCard = card }
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

    private func standaloneLoanGroup(
        loans: [Loan],
        isPaidOff: Bool,
        isExpanded: Binding<Bool>
    ) -> some View {
        StandaloneLoanGroupCard(
            loans: loans,
            isPaidOff: isPaidOff,
            isExpanded: isExpanded,
            editableLoanIDs: editableLoanIDs,
            onEdit: { if canEditResource("loan", $0.id) { editingLoan = $0 } },
            onAddPayment: { loan in
                guard canEditResource("loan", loan.id) else { return }
                paymentLoan = loan
                paymentDraft = LoanPayment(
                    id: UUID(),
                    userId: loan.userId,
                    loanId: loan.id,
                    date: Date(),
                    amount: 0.0,
                    source: ""
                )
                showLoanPaymentHUD = true
            },
            onTogglePaid: { loan in
                guard canEditResource("loan", loan.id) else { return }
                var updatedLoan = loan
                if updatedLoan.status == "Paid Off" {
                    updatedLoan.status = "Active"
                    updatedLoan.remainingBalance = updatedLoan.principalAmount
                    updatedLoan.paidOffDate = nil
                } else {
                    updatedLoan.status = "Paid Off"
                    updatedLoan.remainingBalance = 0
                    updatedLoan.paidOffDate = Date()
                }
                vm.saveLoan(updatedLoan, appState: appState)
            }
        )
    }

    private var readOnlyEmptyState: some View {
        DynamicGlassCard(cornerRadius: 24, height: 190) {
            VStack(spacing: 14) {
                Image(systemName: "building.columns")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color(hex: "#C1AA78"))

                VStack(spacing: 6) {
                    Text("NO FINANCIAL ACCOUNTS SHARED")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(.white)
                    Text("You can view accounts here when the owner adds them.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 28)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .accessibilityElement(children: .combine)
    }

    private func standaloneSectionHeading(
        _ title: String,
        topPadding: CGFloat
    ) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.3))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, topPadding)
    }

    private func standaloneLoanDeck(
        activeLoans: [Loan],
        paidOffLoans: [Loan]
    ) -> some View {
        VStack(spacing: paidOffStandaloneLoansExpanded ? 8 : -60) {
            standaloneLoanGroup(
                loans: paidOffLoans,
                isPaidOff: true,
                isExpanded: $paidOffStandaloneLoansExpanded
            )
            .zIndex(1)

            standaloneLoanGroup(
                loans: activeLoans,
                isPaidOff: false,
                isExpanded: $activeStandaloneLoansExpanded
            )
            .zIndex(2)
            .shadow(color: .black.opacity(0.28), radius: 10, y: 6)
        }
        .animation(
            .spring(response: 0.42, dampingFraction: 0.84),
            value: activeStandaloneLoansExpanded
        )
        .animation(
            .spring(response: 0.42, dampingFraction: 0.84),
            value: paidOffStandaloneLoansExpanded
        )
    }

    // Extracted to reduce body complexity for the Swift type-checker
    @ViewBuilder
    private var financialActionBar: some View {
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

            if canManageSharing {
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
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    shareResourceId = company.id
                    shareResourceType = "all_institutions"
                    shareResourceTitle = "All Institutions"
                    showShareSheet = true
                } label: {
                    Label("All Institutions", systemImage: "building.columns")
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
                                let cardName: String = card.name.isEmpty ? "Unnamed" : card.name
                                Label(cardName, systemImage: "person.crop.circle.badge.plus")
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
                                let loanName: String = loan.name.isEmpty ? "Unnamed" : loan.name
                                Label(loanName, systemImage: "person.crop.circle.badge.plus")
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
            }

            if canCreateFinancialItem {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1, height: 20)

            Menu {
                if canCreate("loan") {
                    Button {
                        guard canCreate("loan") else { return }
                        newLoan = vm.addLoan(appState: appState, userId: company.userId, companyId: company.id)
                    } label: {
                        Label("Add Loan", systemImage: "dollarsign.circle")
                    }
                }
                if canCreate("card") {
                    Button {
                        guard canCreate("card") else { return }
                        newCard = vm.addCard(appState: appState, userId: company.userId, companyId: company.id)
                    } label: {
                        Label("Add Card", systemImage: "creditcard")
                    }
                }
                if canCreate("institution") {
                    Button {
                        beginInstitutionCreation()
                    } label: {
                        Label(appState.portfolioUserID == company.userId ? "Add Account" : "Add Institution Manually", systemImage: "building.columns")
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text("ADD FINANCIAL ITEM").font(.system(size: 13, weight: .bold)).tracking(1).foregroundStyle(.white)
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.white.opacity(0.5))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            }
        }
        .premiumDarkBar(cornerRadius: 12)
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 16)
        .background(actionBarFrameCapture)
    }

    // Extracted to help the Swift type-checker on the deeply-nested action bar expression
    @ViewBuilder
    private var actionBarFrameCapture: some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: TutorialFrameKey.self,
                value: ["financialActionBar": geo.frame(in: .global)]
            )
        }
    }
}
