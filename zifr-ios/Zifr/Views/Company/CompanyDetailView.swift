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
    @State private var tabBounces: [AppViewModel.CompanyTab: Int] = [:]
    @State private var searchBounce: Int = 0

    @State private var newSub: Subscription? = nil
    @State private var newCard: FinancialCard? = nil
    @State private var newDoc: CompanyDocument? = nil
    @State private var newLoan: Loan? = nil
    @State private var showFinancialWizard = false
    @State private var wizardInstitution: Institution? = nil
    @State private var showAssistant = false
    @State private var assistantStrokeRotation: Double = 0.0

    // Tutorial frame targets — populated by TutorialFrameKey preferences
    @State private var tutFrameHeader: CGRect = .zero
    @State private var tutFrameQuickAdd: CGRect = .zero
    @State private var tutFrameFinancials: CGRect = .zero
    @State private var tutFrameSubscriptions: CGRect = .zero
    @State private var tutFrameDocuments: CGRect = .zero
    @State private var tutFrameTabBar: CGRect = .zero
    @State private var tutFrameFinancialActionBar: CGRect = .zero

    
    private var currentTabIndex: Int {
        AppViewModel.CompanyTab.allCases.firstIndex(of: vm.activeTab) ?? 0
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            
            AnimatedHeaderBackground()
                .ignoresSafeArea(edges: .top)

            VStack(spacing: 0) {
                // ── Entity Command Plate ─────────────────────────────────────
                companyHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
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
                switch vm.activeTab {
                case .home:
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
                        vm: vm
                    )
                case .subscriptions:
                    SubscriptionListView(company: company, subscriptions: subscriptions, institutions: institutions, cards: cards, vm: vm)
                case .financial:
                    FinancialView(company: company, cards: cards, institutions: institutions, loans: loans, vm: vm)
                case .documents:
                    DocumentListView(company: company, documents: documents, vm: vm)
                }
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
        .sheet(isPresented: $showFinancialWizard) {
            if let inst = wizardInstitution {
                AddFinancialWizard(institution: inst, vm: vm, isCommandCenterContext: true, allInstitutions: institutions)
            }
        }
        .sheet(item: $newLoan) { l in
            EditLoanSheet(loan: l, vm: vm, isNew: true, institutions: institutions, cards: cards)
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
        .onChange(of: appState.institutions.count) { _, _ in
            onboardingState.evaluateState(appState: appState)
        }
        .onChange(of: showFinancialWizard) { _, isPresented in
            if !isPresented {
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
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                switch newStep {
                // Real onboarding tab switches
                case .needsBank:
                    vm.activeTab = .financial
                case .needsReview:
                    vm.activeTab = .subscriptions
                case .needsNotes:
                    vm.activeTab = .documents
                case .needsCommandCenterQuickAdd, .needsCommandCenterFinancialsHeader,
                     .needsCommandCenterFinancialsAccounts, .needsCommandCenterFinancialsReport,
                     .needsCommandCenterSubscriptions, .needsCommandCenterDocuments:
                    vm.activeTab = .home
                // Tutorial tab switches
                case .tutorialCommandCenter, .tutorialCommandQuickAdd,
                     .tutorialCommandFinancials, .tutorialCommandSubscriptions,
                     .tutorialCommandDocuments:
                    vm.activeTab = .home
                // tutorialCommandTabBar is now on the financial page
                case .tutorialCommandTabBar,
                     .tutorialFinancialPage, .tutorialFinancialWallet,
                     .tutorialFinancialCardTap:
                    vm.activeTab = .financial
                default:
                    break
                }
            }
        }
        .onAppear {
            onboardingState.evaluateState(appState: appState)
        }
        // Popover moved to the button
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider().background(Color.white.opacity(0.1))
                HStack {
                    HStack(spacing: 20) { // Grouping left utilities
                        // Menu Button
                        Menu {
                            ControlGroup {
                                Button {
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    vm.path.append(AppViewModel.AppRoute.adminSettings)
                                } label: {
                                    Label("Admin", systemImage: "person.crop.circle")
                                }
                                Button {
                                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                                    generator.impactOccurred()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { generator.impactOccurred() }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { generator.impactOccurred() }
                                    
                                    dismiss()
                                } label: {
                                    Label("Dashboard", systemImage: "square.grid.2x2")
                                }
                            }
                            
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 32, height: 44) // slightly narrower footprint
                        }

                        // Search Button
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            vm.showSearch = true
                            searchBounce += 1
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(vm.showSearch ? .primary : .secondary)
                                .symbolEffect(.bounce, value: searchBounce)
                                .frame(width: 32, height: 44)
                        }

                        // Assistant Button
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showAssistant = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text("Assistant")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 34)
                            .background(Color.black)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(
                                    AngularGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: Color.gray.opacity(0.8), location: 0.0),
                                            .init(color: Color.black, location: 0.25),
                                            .init(color: Color(hex: "#9333EA"), location: 0.5),
                                            .init(color: Color.black, location: 0.75),
                                            .init(color: Color.gray.opacity(0.8), location: 1.0)
                                        ]),
                                        center: .center,
                                        angle: .degrees(assistantStrokeRotation)
                                    ),
                                    lineWidth: 0.8
                                )
                            )
                            .onAppear {
                                withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                                    assistantStrokeRotation = 360.0
                                }
                            }
                        }
                    }

                    Spacer()

                    // Tab Controls (Pages icons) aligned to the right
                    HStack(spacing: 28) { // Distributed equally
                        if vm.activeTab != .home {
                            let pageTabs: [AppViewModel.CompanyTab] = [.subscriptions, .financial, .documents]
                            let activeIndex = pageTabs.firstIndex(of: vm.activeTab) ?? 0
                            
                            ZStack {
                                ForEach(Array(pageTabs.enumerated()), id: \.element) { index, tab in
                                    let offsetIndex = (index - activeIndex + 3) % 3
                                    let isFront = offsetIndex == 0
                                    let scale: CGFloat = isFront ? 1.0 : 0.8
                                    let xOffset: CGFloat = isFront ? 0 : (offsetIndex == 1 ? 14 : -14)
                                    let opacity: Double = isFront ? 1.0 : 0.4
                                    let zIdx: Double = isFront ? 3 : 2
                                    tabIconView(tab: tab, isFront: isFront, scale: scale, xOffset: xOffset, opacity: opacity, layerZIndex: zIdx)
                                }
                            }
                            .frame(width: 32, height: 44)
                            .transition(.scale.combined(with: .opacity))
                            .highPriorityGesture(
                                DragGesture(minimumDistance: 10, coordinateSpace: .local)
                                    .onEnded { value in
                                        let transX = value.translation.width
                                        if abs(transX) > 10 {
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            var nextTab = vm.activeTab
                                            if transX < 0 {
                                                if vm.activeTab == .subscriptions { nextTab = .financial }
                                                else if vm.activeTab == .financial { nextTab = .documents }
                                                else if vm.activeTab == .documents { nextTab = .subscriptions }
                                            } else {
                                                if vm.activeTab == .subscriptions { nextTab = .documents }
                                                else if vm.activeTab == .financial { nextTab = .subscriptions }
                                                else if vm.activeTab == .documents { nextTab = .financial }
                                            }
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                vm.activeTab = nextTab
                                            }
                                            tabBounces[nextTab, default: 0] += 1
                                        }
                                    }
                            )
                        }
                        
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
                        } label: {
                            Image(systemName: AppViewModel.CompanyTab.home.icon)
                                .font(.system(size: 20, weight: vm.activeTab == .home ? .semibold : .medium))
                                .foregroundStyle(vm.activeTab == .home ? .white : .secondary)
                                .symbolEffect(.bounce, value: tabBounces[.home, default: 0])
                                .frame(width: 32, height: 44)
                        } primaryAction: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                vm.activeTab = .home
                            }
                            tabBounces[.home, default: 0] += 1
                        }
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                            }
                        )
                    }
                    .padding(.trailing, 12)
                }
                .padding(.horizontal, 20)
                .frame(height: 49) // Standard HIG TabBar Height
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
            .background(Color.black)
        }
        // ── Tutorial spotlight overlay — placed AFTER safeAreaInset so it draws above the tab bar ──
        .overlay {
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
                        onSkip: { onboardingState.exitTutorial() }
                    )
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .global)
                .onChanged { value in
                    if swipeHandled { return }
                    
                    let screenWidth = UIScreen.main.bounds.width
                    let startX = value.startLocation.x
                    
                    let isEdgeSwipe = startX < 120 || startX > screenWidth - 120
                    if !isEdgeSwipe { return }
                    
                    let transX = value.translation.width
                    let transY = value.translation.height
                    
                    if abs(transX) > 50 && abs(transY) < 60 {
                        swipeHandled = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        
                        if transX > 0 {
                            // Swipe Left to Right (Go Back)
                            if vm.activeTab == .home {
                                dismiss()
                            } else {
                                // From financial, subscription, and docs page, swiping right goes directly to command center
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { vm.activeTab = .home }
                            }
                        } else {
                            // Swipe Right to Left (Go Forward)
                            if vm.activeTab == .home {
                                // Swiping left from the command center goes to the dashboard
                                dismiss()
                            } else if vm.activeTab == .subscriptions {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { vm.activeTab = .financial }
                            } else if vm.activeTab == .financial {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { vm.activeTab = .documents }
                            }
                        }
                    }
                }
                .onEnded { _ in
                    swipeHandled = false
                }
        )
        .navigationBarBackButtonHidden(true)

    }
        }

    // MARK: - Entity Command Plate
    private var companyHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            CompanyAvatar(company: company, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                // Company name
                Text(company.name.isEmpty ? "Company" : company.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                // Dynamic metrics sub-line per tab
                metricSubLine
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#1C1C1E").opacity(0.70))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    @ViewBuilder
    private var metricSubLine: some View {
        switch vm.activeTab {
        case .home:
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tabColor(.home))
                Text("COMMAND CENTER")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "#C1AA78"))
                    .tracking(2)
            }

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
            let totalDebt = loans.filter { $0.role == "Bank Loan" }.reduce(0.0) { $0 + $1.remainingBalance } + creditCards.reduce(0.0) { $0 + $1.balance }
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
                Text("Document Vault")
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



    private func tabColor(_ tab: AppViewModel.CompanyTab) -> Color {
        switch tab {
        case .home:          return Color.white.opacity(0.85)
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
                        showFinancialWizard = true
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
        tab: AppViewModel.CompanyTab,
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
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: isFront ? .semibold : .medium))
                    .foregroundStyle(isFront ? tabColor(tab) : .secondary)
                    .symbolEffect(.bounce, value: tabBounces[tab, default: 0])
                    .frame(width: 32, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black)
                            .frame(width: 20, height: 20)
                    )
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
                        showFinancialWizard = true
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
}
