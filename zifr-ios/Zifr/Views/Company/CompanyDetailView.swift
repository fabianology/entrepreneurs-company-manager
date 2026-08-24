import SwiftUI

struct CompanyDetailView: View {
    @State var company: Company
    @Bindable var vm: AppViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(OnboardingStateManager.self) private var onboardingState

    private var allCompanies: [Company] { appState.companies.sorted { $0.name < $1.name } }
    private var allSubscriptions: [Subscription] { appState.subscriptions }
    private var allCards: [FinancialCard] { appState.cards }
    private var allInstitutions: [Institution] { appState.institutions }
    private var allLoans: [Loan] { appState.loans }
    private var allDocuments: [CompanyDocument] { appState.documents }

    var subscriptions: [Subscription] {
        let filtered = allSubscriptions.filter { $0.companyId == company.id }
        guard !vm.searchQuery.isEmpty else { return filtered }
        let q = vm.searchQuery.lowercased()
        return filtered.filter { ($0.name ?? "").lowercased().contains(q) || ($0.loginId ?? "").lowercased().contains(q) || ($0.paymentMethod ?? "").lowercased().contains(q) }
    }
    var cards: [FinancialCard] {
        let filtered = allCards.filter { $0.companyId == company.id }
        guard !vm.searchQuery.isEmpty else { return filtered }
        let q = vm.searchQuery.lowercased()
        return filtered.filter { ($0.name ?? "").lowercased().contains(q) || ($0.institutionName ?? "").lowercased().contains(q) || ($0.network ?? "").lowercased().contains(q) || ($0.last4 ?? "").lowercased().contains(q) }
    }
    var institutions: [Institution] {
        let filtered = allInstitutions.filter { $0.companyId == company.id }
        guard !vm.searchQuery.isEmpty else { return filtered }
        let q = vm.searchQuery.lowercased()
        return filtered.filter { ($0.name ?? "").lowercased().contains(q) || ($0.username ?? "").lowercased().contains(q) || ($0.email ?? "").lowercased().contains(q) }
    }
    var loans: [Loan] {
        let filtered = allLoans.filter { $0.companyId == company.id }
        guard !vm.searchQuery.isEmpty else { return filtered }
        let q = vm.searchQuery.lowercased()
        return filtered.filter { ($0.name ?? "").lowercased().contains(q) || ($0.lender ?? "").lowercased().contains(q) }
    }
    var documents: [CompanyDocument] {
        let filtered = allDocuments.filter { $0.companyId == company.id }
        guard !vm.searchQuery.isEmpty else { return filtered }
        let q = vm.searchQuery.lowercased()
        return filtered.filter { $0.name.lowercased().contains(q) }
    }

    @State private var showEditCompany = false
    @State private var swipeHandled = false
    @State private var tabBounces: [EntityHomeTab: Int] = [:]
    @State private var searchBounce: Int = 0

    @State private var newSub: Subscription? = nil
    @State private var newCard: FinancialCard? = nil
    @State private var newDoc: CompanyDocument? = nil
    @State private var newLoan: Loan? = nil
    @State private var wizardInstitution: Institution? = nil
    @State private var showAssistant = false
    @State private var assistantStrokeRotation: Double = 0.0
    @State private var showFinancialReport = false
    @State private var showSubscriptionReport = false

    // Tutorial frame targets — populated by TutorialFrameKey preferences
    @State private var tutFrameHeader: CGRect = .zero
    @State private var tutFrameQuickAdd: CGRect = .zero
    @State private var tutFrameFinancials: CGRect = .zero
    @State private var tutFrameSubscriptions: CGRect = .zero
    @State private var tutFrameDocuments: CGRect = .zero
    @State private var tutFrameTabBar: CGRect = .zero
    @State private var tutFrameFinancialActionBar: CGRect = .zero

    private var currentTabIndex: Int {
        EntityHomeTab.allCases.firstIndex(of: vm.activeTab) ?? 0
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.zifrBG.ignoresSafeArea()
            
            AnimatedHeaderBackground()
                .ignoresSafeArea(edges: .top)

            VStack(spacing: 0) {
                // ── Entity Command Plate ─────────────────────────────────────
                companyHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .zIndex(10)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: TutorialFrameKey.self,
                                value: ["header": geo.frame(in: .global)]
                            )
                        }
                    )
                
            // ── Content ──────────────────────────────────────────────────
            ZStack(alignment: .top) {
                mainContentSection
            }
        }
        .coordinateSpace(name: "commandCenter")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditCompany) {
            EditCompanySheet(vm: vm, company: company)
        }
        .sheet(item: $newSub) { sub in
            AddSubscriptionWizard(sub: sub, institutions: institutions, cards: cards, vm: vm)
                .presentationDetents([.fraction(0.9), .large])
        }
        .sheet(item: $newCard) { c in
            EditCardSheet(card: c, vm: vm, institutions: institutions, cards: cards, isNew: true)
        }
        .sheet(item: $newDoc) { doc in
            EditDocumentSheet(doc: doc, vm: vm, isNew: true, companyStructure: company.structure)
        }
        .sheet(item: $wizardInstitution) { inst in
            AddFinancialWizard(institution: inst, vm: vm, isCommandCenterContext: true, allInstitutions: institutions)
        }
        .sheet(item: $newLoan) { l in
            EditLoanSheet(loan: l, vm: vm, isNew: true, institutions: institutions, cards: cards)
        }
        .sheet(isPresented: $showFinancialReport) {
            FinancialReceiptView(
                company: company,
                institutions: institutions,
                cards: cards,
                loans: loans,
                subscriptions: subscriptions
            )
        }
        .sheet(isPresented: $showSubscriptionReport) {
            SubscriptionReceiptView(
                company: company,
                subscriptions: subscriptions,
                institutions: institutions,
                cards: cards
            )
        }
        .fullScreenCover(isPresented: $showAssistant) {
            AssistantOnboardingView(vm: vm)
                .environment(appState)
        }
        .overlayPreferenceValue(SpotlightBoundsKey.self) { anchors in
            buildSpotlightOverlay(for: anchors)
        }
        .onPreferenceChange(TutorialFrameKey.self) { frames in
            if let f = frames["header"]              { tutFrameHeader = f }
            if let f = frames["quickAdd"]            { tutFrameQuickAdd = f }
            if let f = frames["financials"]          { tutFrameFinancials = f }
            if let f = frames["subscriptions"]       { tutFrameSubscriptions = f }
            if let f = frames["documents"]           { tutFrameDocuments = f }
            if let f = frames["tabBar"]              { tutFrameTabBar = f }
            if let f = frames["financialActionBar"]  { tutFrameFinancialActionBar = f }
        }
        .onChange(of: appState.companies) { _, newCompanies in
            if let updated = newCompanies.first(where: { $0.id == company.id }) {
                company = updated
            }
        }
        .onChange(of: appState.institutions.count) { _, _ in
            onboardingState.evaluateState(appState: appState)
        }
        .onChange(of: wizardInstitution) { _, inst in
            if inst == nil {
                onboardingState.evaluateState(appState: appState)
            }
        }
        .onChange(of: newSub) { _, sub in
            if sub == nil {
                onboardingState.evaluateState(appState: appState)
            }
        }
        .onChange(of: newDoc) { _, doc in
            if doc == nil {
                onboardingState.evaluateState(appState: appState)
            }
        }
        .onChange(of: appState.subscriptions.count) { _, _ in
            if onboardingState.currentStep == .needsReview {
                onboardingState.completeOnboarding()
            }
        }
        .onChange(of: appState.documents.count) { _, _ in
            if onboardingState.currentStep == .needsNotes {
                onboardingState.completeOnboarding()
            }
        }
        .onChange(of: onboardingState.currentStep, initial: true) { _, newStep in
            handleOnboardingStepChange(newStep)
        }
        .onAppear {
            handleOnAppear()
        }
        .overlay(alignment: .bottom) {
            bottomBarInset
        }
        .overlay {
            tutorialOverlaySection
        }
        .ignoresSafeArea(edges: .bottom)
        .gesture(edgeSwipeGesture)
        .navigationBarBackButtonHidden(true)
        }
    }

    // MARK: - Body Sub-expressions
    @ViewBuilder
    private var mainContentSection: some View {
        EntityHomeView(
            company: company,
            subscriptions: subscriptions,
            cards: cards,
            institutions: institutions,
            loans: loans,
            documents: documents,
            allCompanies: allCompanies,
            allSubscriptions: allSubscriptions,
            allCards: allCards,
            allLoans: allLoans,
            vm: vm,
            activeInternalTab: $vm.activeTab
        )
    }

    @ViewBuilder
    private var tutorialOverlaySection: some View {
        if onboardingState.isInCommandCenterTutorial || onboardingState.isInFinancialTutorial {
            let walletFrame = onboardingState.tutorialFinancialWalletFrame
            let institutionFrame = onboardingState.tutorialFinancialInstitutionFrame
            let targetFrame: CGRect = {
                switch onboardingState.currentStep {
                case .tutorialCommandCenter:         return tutFrameHeader
                case .tutorialCommandQuickAdd:       return tutFrameQuickAdd != .zero ? tutFrameQuickAdd : tutFrameHeader
                case .tutorialCommandFinancials:     return tutFrameFinancials != .zero ? tutFrameFinancials : tutFrameHeader
                case .tutorialCommandSubscriptions:  return tutFrameSubscriptions != .zero ? tutFrameSubscriptions : tutFrameHeader
                case .tutorialCommandDocuments:      return tutFrameDocuments != .zero ? tutFrameDocuments : tutFrameHeader
                case .tutorialCommandTabBar:         return tutFrameTabBar != .zero ? tutFrameTabBar : tutFrameHeader
                case .tutorialFinancialPage:         return tutFrameFinancialActionBar != .zero ? tutFrameFinancialActionBar : tutFrameHeader
                case .tutorialFinancialWallet:       return walletFrame != .zero ? walletFrame : tutFrameHeader
                case .tutorialFinancialCardTap:      return institutionFrame != .zero ? institutionFrame : walletFrame
                default:                             return .zero
                }
            }()
            let frame = targetFrame != .zero ? targetFrame : tutFrameHeader
            if frame != .zero {
                TutorialSpotlightOverlayView(
                    anchor: frame,
                    stepIndex: onboardingState.tutorialStepIndex,
                    totalSteps: onboardingState.tutorialTotalSteps,
                    title: commandCenterTutorialTitle(for: onboardingState.currentStep),
                    message: commandCenterTutorialMessage(for: onboardingState.currentStep),
                    segment: onboardingState.tutorialSegmentLabel,
                    onBack: { onboardingState.tutorialBack() },
                    onNext: { onboardingState.tutorialNext() },
                    onSkip: { onboardingState.exitTutorial(appState: appState) }
                )
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }
        }
    }

    private var edgeSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .global)
            .onChanged { value in
                if swipeHandled { return }
                
                let screenWidth = UIScreen.main.bounds.width
                let startX = value.startLocation.x
                
                let isEdgeSwipe = startX < 50 || startX > screenWidth - 50
                if !isEdgeSwipe { return }
                
                let transX = value.translation.width
                let transY = value.translation.height
                
                if abs(transX) > 40 && abs(transY) < 60 {
                    swipeHandled = true
                    
                    let tabs = EntityHomeTab.allCases
                    let currentIndex = tabs.firstIndex(of: vm.activeTab) ?? 0
                    
                    if transX < 0 {
                        // Swipe Left (from right edge towards left -> Next tab: Financial -> Services -> Vault)
                        if currentIndex < tabs.count - 1 {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                vm.activeTab = tabs[currentIndex + 1]
                            }
                        }
                    } else {
                        // Swipe Right (from left edge towards right -> Previous tab: Vault -> Services -> Financial)
                        if currentIndex > 0 {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                vm.activeTab = tabs[currentIndex - 1]
                            }
                        } else if vm.activeTab == .financial {
                            // From Financial (left-most tab), swipe right from the left edge returns to Dashboard
                            triggerDoubleHaptic()
                            if !vm.path.isEmpty {
                                vm.path.removeLast()
                            }
                            dismiss()
                        }
                    }
                }
            }
            .onEnded { _ in
                swipeHandled = false
            }
    }

    @ViewBuilder
    private var bottomBarInset: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // 1. Profile / Admin Button (far left)
            profileControlButton

            // 2. Search Button (center pill)
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                vm.showSearch = true
                searchBounce += 1
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.85))
                    Text("search")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.5))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(
                    Capsule()
                        .fill(Color.zifrTabBarFill.opacity(0.70))
                )
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#918457"),
                                    Color(hex: "#918457").opacity(0.3)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)

            // 3. Entities Button (instead of Apple Intelligence)
            entitiesControlMenu

            // 4. Plus Button (far right quick add menu)
            plusControlMenu
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(
            Group {
                if onboardingState.isInFinancialTutorial || onboardingState.isInCommandCenterTutorial {
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { tutFrameTabBar = geo.frame(in: .global) }
                            .onChange(of: geo.frame(in: .global)) { _, f in tutFrameTabBar = f }
                    }
                }
            }
        )
    }

    private func handleOnboardingStepChange(_ newStep: OnboardingStep) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            switch newStep {
            case .needsBank:
                vm.activeTab = .financial
            case .needsReview:
                vm.activeTab = .subscriptions
            case .needsNotes:
                vm.activeTab = .documents
            case .needsCommandCenterQuickAdd, .needsCommandCenterFinancialsHeader,
                 .needsCommandCenterFinancialsAccounts, .needsCommandCenterFinancialsReport:
                vm.activeTab = .financial
            case .needsCommandCenterSubscriptions:
                vm.activeTab = .subscriptions
            case .needsCommandCenterDocuments:
                vm.activeTab = .documents
            case .tutorialCommandCenter, .tutorialCommandQuickAdd,
                 .tutorialCommandFinancials:
                vm.activeTab = .financial
            case .tutorialCommandSubscriptions:
                vm.activeTab = .subscriptions
            case .tutorialCommandDocuments:
                vm.activeTab = .documents
            case .tutorialCommandTabBar,
                 .tutorialFinancialPage, .tutorialFinancialWallet,
                 .tutorialFinancialCardTap:
                vm.activeTab = .financial
            default:
                break
            }
        }
    }

    private func handleOnAppear() {
        onboardingState.evaluateState(appState: appState)
    }

    // MARK: - Entity Command Plate
    private var companyHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                CompanyAvatar(company: company, size: 48)
            }
            .frame(width: 52, height: 52)
            .contentShape(Rectangle())
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showEditCompany = true
            }

            VStack(alignment: .leading, spacing: 4) {
                // Top row: Company name & Receipt Icon
                HStack(alignment: .center) {
                    Text(company.name.isEmpty ? "Company" : company.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    headerActionMenu
                }

                // Dynamic metrics sub-line per tab (full width below)
                metricSubLine
            }
        }
        .padding(.vertical, 12)
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.zifrBG)
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.zifrTabBarFill.opacity(0.70))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "#918457"),
                            Color(hex: "#918457").opacity(0.3)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(0.45), radius: 6, x: 0, y: 3)
    }

    @ViewBuilder
    private var headerActionMenu: some View {
        Menu {
            Button {
                showFinancialReport = true
            } label: {
                Label("Financial Report", systemImage: "dollarsign.circle")
            }
            Button {
                showSubscriptionReport = true
            } label: {
                Label("Subscription Report", systemImage: "arrow.triangle.2.circlepath")
            }
        } label: {
            Image(systemName: "receipt")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.45))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private var profileControlButton: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            vm.path.append(AppViewModel.AppRoute.adminSettings)
        } label: {
            ZStack {
                Circle()
                    .fill(Color.zifrTabBarFill.opacity(0.70))
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#918457"),
                                        Color(hex: "#918457").opacity(0.3)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)

                Image(systemName: "person.crop.circle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var entitiesControlMenu: some View {
        Menu {
            if !allCompanies.isEmpty {
                Section("Jump to Entity") {
                    ForEach(allCompanies) { c in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            company = c
                            vm.touchCompany(c, appState: appState)
                        } label: {
                            if c.id == company.id {
                                Label(c.name, systemImage: "checkmark")
                            } else {
                                Text(c.name)
                            }
                        }
                    }
                }
            }
            Button {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                dismiss()
            } label: {
                Label("All Entities", systemImage: "square.grid.2x2")
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.zifrTabBarFill.opacity(0.70))
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#918457"),
                                        Color(hex: "#918457").opacity(0.3)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)

                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var plusButtonLabel: some View {
        ZStack {
            Circle()
                .fill(Color.zifrTabBarFill.opacity(0.70))
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#918457"),
                                    Color(hex: "#918457").opacity(0.3)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)

            Image(systemName: "plus")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.85))
        }
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var plusControlMenu: some View {
        switch vm.activeTab {
        case .financial:
            Menu {
                if !institutions.isEmpty {
                    Button {
                        newLoan = vm.addLoan(appState: appState, userId: company.userId, companyId: company.id)
                    } label: {
                        Label("Add Loan", systemImage: "dollarsign.circle")
                    }
                    Button {
                        newCard = vm.addCard(appState: appState, userId: company.userId, companyId: company.id)
                    } label: {
                        Label("Add Card", systemImage: "creditcard")
                    }
                }
                Button {
                    wizardInstitution = Institution(userId: company.userId, companyId: company.id)
                } label: {
                    Label("Add Account", systemImage: "building.columns")
                }
            } label: {
                plusButtonLabel
            }
            .buttonStyle(.plain)

        case .subscriptions:
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                newSub = Subscription(userId: company.userId, companyId: company.id)
            } label: {
                plusButtonLabel
            }
            .buttonStyle(.plain)

        case .documents:
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                newDoc = CompanyDocument(userId: company.userId, companyId: company.id)
            } label: {
                plusButtonLabel
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var metricSubLine: some View {
        switch vm.activeTab {
        case .subscriptions:
            let active = subscriptions.filter { $0.status == "Active" }
            let moTotal = active.reduce(0.0) { $0 + $1.monthlyTotal }
            let yrTotal = active.reduce(0.0) { $0 + $1.yearlyTotal }
            let moCount = active.filter { $0.billingCycle == "Monthly" }.count
            let yrCount = active.filter { $0.billingCycle == "Yearly" }.count

            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tabColor(.subscriptions))
                metricPair(label: "mo.", value: moTotal, count: moCount)
                Text("•").font(.system(size: 13, weight: .black)).foregroundStyle(Color.white.opacity(0.2))
                metricPair(label: "yr.", value: yrTotal, count: yrCount)
            }

        case .financial:
            let creditCards = cards.filter { $0.type == "Credit" }
            let totalDebt = loans.filter { $0.isLender }.reduce(0.0) { $0 + $1.remainingBalance } + creditCards.reduce(0.0) { $0 + $1.balance }
            let totalCredit = creditCards.reduce(0.0) { $0 + $1.limit }

            HStack(spacing: 8) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tabColor(.financial))
                financialMetricPair(label: "Debt", value: totalDebt)
                Text("•").font(.system(size: 13, weight: .black)).foregroundStyle(Color.white.opacity(0.2))
                financialMetricPair(label: "Credit", value: totalCredit)
            }

        case .documents:
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tabColor(.documents))
                Text("\(documents.count) Documents")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "#C1AA78"))
            }
        }
    }

    private func metricPair(label: String, value: Double, count: Int) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "#C1AA78"))
            Text("$\(String(format: "%.0f", value))")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Text("(\(count))")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "#C1AA78"))
        }
    }

    private func financialMetricPair(label: String, value: Double) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "#C1AA78"))
            Text("$\(String(format: "%.0f", value))")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private func formatHeaderCurrency(_ value: Double) -> String {
        if value >= 1000 { return "$\(String(format: "%.1fk", value / 1000))" }
        return "$\(String(format: "%.0f", value))"
    }

    private func tabColor(_ tab: EntityHomeTab) -> Color {
        switch tab {
        case .subscriptions: return Color(hex: "#2070BD")
        case .financial:     return Color(hex: "#1A7077")
        case .documents:     return Color(hex: "#918457")
        }
    }

    @ViewBuilder
    private func buildSpotlightOverlay(for anchors: [Anchor<CGRect>]) -> some View {
        if anchors.isEmpty {
            EmptyView()
        } else {
            switch onboardingState.currentStep {
            case .needsBank:
                SpotlightOverlayView(
                    anchors: anchors,
                    message: "Connect your bank account securely. We'll automatically find your subscriptions and organize your financials.",
                    stepIndex: 2, totalSteps: 8,
                    onSkip: { onboardingState.skipOnboarding() },
                    onTapTarget: {
                        onboardingState.currentStep = .notStarted // Temporary hide so tap goes through
                        wizardInstitution = Institution(userId: company.userId, companyId: company.id)
                    }
                )
            case .needsReview:
                SpotlightOverlayView(
                    anchors: anchors,
                    message: subscriptions.isEmpty ? "Now let's add your first subscription or service. You can track all recurring costs here." : "Magic! ✨ We found your active subscriptions. You can review them or add documents anytime.",
                    stepIndex: 3, totalSteps: 8,
                    onSkip: { onboardingState.completeOnboarding() },
                    onTapTarget: {
                        if subscriptions.isEmpty {
                            newSub = Subscription(userId: company.userId, companyId: company.id)
                        } else {
                            onboardingState.completeOnboarding()
                        }
                    }
                )
            case .needsNotes:
                SpotlightOverlayView(
                    anchors: anchors,
                    message: "Add your first document. You can store articles of incorporation, tax forms, and notes securely in your vault.",
                    stepIndex: 4, totalSteps: 8,
                    onSkip: { onboardingState.completeOnboarding() },
                    onTapTarget: {
                        newDoc = vm.addDocument(appState: appState, userId: company.userId, companyId: company.id)
                    }
                )
            case .needsCommandCenterQuickAdd:
                SpotlightOverlayView(
                    anchors: anchors,
                    message: "This is your Command Center. Use this top row to quickly add services, accounts, and documents from anywhere.",
                    stepIndex: 5, totalSteps: 8,
                    onBack: { onboardingState.currentStep = .needsNotes },
                    onNext: { onboardingState.currentStep = .needsCommandCenterFinancialsHeader },
                    onSkip: { onboardingState.currentStep = .completed },
                    onTapTarget: { onboardingState.currentStep = .needsCommandCenterFinancialsHeader }
                )
            case .needsCommandCenterFinancialsHeader:
                SpotlightOverlayView(
                    anchors: anchors,
                    message: "Click here to go to your financial page.",
                    stepIndex: 6, totalSteps: 8,
                    onBack: { onboardingState.currentStep = .needsCommandCenterQuickAdd },
                    onNext: { onboardingState.currentStep = .needsCommandCenterFinancialsAccounts },
                    onSkip: { onboardingState.currentStep = .completed },
                    onTapTarget: { onboardingState.currentStep = .needsCommandCenterFinancialsAccounts }
                )
            case .needsCommandCenterFinancialsAccounts:
                SpotlightOverlayView(
                    anchors: anchors,
                    message: "See all your financial accounts here.",
                    stepIndex: 6, totalSteps: 8,
                    onBack: { onboardingState.currentStep = .needsCommandCenterFinancialsHeader },
                    onNext: { onboardingState.currentStep = .needsCommandCenterFinancialsReport },
                    onSkip: { onboardingState.currentStep = .completed },
                    onTapTarget: { onboardingState.currentStep = .needsCommandCenterFinancialsReport }
                )
            case .needsCommandCenterFinancialsReport:
                SpotlightOverlayView(
                    anchors: anchors,
                    message: "Generate a single page easy to read report.",
                    stepIndex: 6, totalSteps: 8,
                    onBack: { onboardingState.currentStep = .needsCommandCenterFinancialsAccounts },
                    onNext: { onboardingState.currentStep = .needsCommandCenterSubscriptions },
                    onSkip: { onboardingState.currentStep = .completed },
                    onTapTarget: { onboardingState.currentStep = .needsCommandCenterSubscriptions }
                )
            case .needsCommandCenterSubscriptions:
                SpotlightOverlayView(
                    anchors: anchors,
                    message: "Your active subscriptions and monthly costs are summarized in this card.",
                    stepIndex: 7, totalSteps: 8,
                    onBack: { onboardingState.currentStep = .needsCommandCenterFinancialsReport },
                    onNext: { onboardingState.currentStep = .needsCommandCenterDocuments },
                    onSkip: { onboardingState.currentStep = .completed },
                    onTapTarget: { onboardingState.currentStep = .needsCommandCenterDocuments }
                )
            case .needsCommandCenterDocuments:
                SpotlightOverlayView(
                    anchors: anchors,
                    message: "And finally, your document vault summary. You're all set!",
                    stepIndex: 8, totalSteps: 8,
                    onBack: { onboardingState.currentStep = .needsCommandCenterSubscriptions },
                    onNext: { onboardingState.currentStep = .completed },
                    onSkip: { onboardingState.currentStep = .completed },
                    onTapTarget: { onboardingState.currentStep = .completed }
                )
            default:
                EmptyView()
            }
        }
    }

    // MARK: - Tutorial Copy Helpers (Command Center + Financial)

    private func tabLabelText(for tab: EntityHomeTab) -> String {
        switch tab {
        case .subscriptions: return "subs"
        case .financial: return "finance"
        case .documents: return "docs"
        }
    }

    private func commandCenterTutorialTitle(for step: OnboardingStep) -> String {
        switch step {
        case .tutorialCommandCenter:       return "Command Center"
        case .tutorialCommandQuickAdd:     return "Quick Add"
        case .tutorialCommandFinancials:   return "Financials Summary"
        case .tutorialCommandSubscriptions: return "Subscriptions"
        case .tutorialCommandDocuments:    return "Document Vault"
        case .tutorialCommandTabBar:       return "Navigate Between Pages"
        case .tutorialFinancialPage:       return "Financial Page"
        case .tutorialFinancialWallet:     return "Your Wallet"
        case .tutorialFinancialCardTap:    return "Tap an Institution"
        default:                           return ""
        }
    }

    private func commandCenterTutorialMessage(for step: OnboardingStep) -> String {
        switch step {
        case .tutorialCommandCenter:
            return "This is your entity’s Command Center — a living dashboard of every subscription, financial account, and document tied to this business."
        case .tutorialCommandQuickAdd:
            return "Add a service, bank account, or document instantly from this bar. No digging through menus."
        case .tutorialCommandFinancials:
            return "See your total debt, available credit, and all linked bank accounts at a glance. Tap any row to expand."
        case .tutorialCommandSubscriptions:
            return "Every active subscription is tracked here — monthly burn, yearly total, and upcoming renewals front and center."
        case .tutorialCommandDocuments:
            return "Store articles of incorporation, tax documents, or any notes here. Everything organized by category."
        case .tutorialCommandTabBar:
            return "These icons switch between Command Center, Subscriptions, Financials, and Documents. Tap to jump, or swipe the icon cluster left and right to cycle pages."
        case .tutorialFinancialPage:
            return "Connect banks, credit cards, and loans here. Use the top bar to add a new account — or sync automatically via Plaid."
        case .tutorialFinancialWallet:
            return "Accounts stack like a wallet. Each institution groups its cards on top. Tap any card to pop it open and see full details."
        case .tutorialFinancialCardTap:
            return "Tap any institution row to expand it and see its cards, loans, and totals. Long-press to edit details or remove the account."
        default:
            return ""
        }
    }

    @ViewBuilder
    private func tabIconView(
        tab: EntityHomeTab,
        isFront: Bool,
        scale: CGFloat,
        xOffset: CGFloat,
        opacity: Double,
        layerZIndex: Double
    ) -> some View {
        ZStack {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                var nextTab = tab
                if tab == .subscriptions { nextTab = .financial }
                else if tab == .financial { nextTab = .documents }
                else if tab == .documents { nextTab = .subscriptions }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    vm.activeTab = nextTab
                }
                tabBounces[nextTab, default: 0] += 1
            } label: {
                VStack(spacing: 1) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 20, weight: isFront ? .semibold : .medium))
                        .foregroundStyle(isFront ? tabColor(tab) : .secondary)
                        .symbolEffect(.bounce, value: tabBounces[tab, default: 0])
                        .frame(width: 32, height: isFront ? 26 : 44)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.black)
                                .frame(width: 20, height: 20)
                        )
                    if isFront {
                        Text(tabLabelText(for: tab))
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(tabColor(tab))
                    }
                }
                .frame(width: 32, height: 44)
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                    guard isFront else { return }
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    if tab == .subscriptions {
                        newSub = Subscription(userId: company.userId, companyId: company.id)
                    } else if tab == .documents {
                        newDoc = vm.addDocument(appState: appState, userId: company.userId, companyId: company.id)
                    } else if tab == .financial {
                        wizardInstitution = Institution(userId: company.userId, companyId: company.id)
                    }
                }
            )
        }
        .zIndex(layerZIndex)
        .scaleEffect(scale)
        .offset(x: xOffset)
        .opacity(opacity)
        .allowsHitTesting(isFront)
    }

    private func triggerDoubleHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            generator.impactOccurred()
        }
    }
}
