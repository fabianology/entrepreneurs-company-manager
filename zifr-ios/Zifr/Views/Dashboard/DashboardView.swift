import SwiftUI
struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(MiloomDuoLayoutState.self) private var duoLayout
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(OnboardingStateManager.self) private var onboardingState
    @Environment(AccessController.self) private var accessController
    @Environment(NotificationRouteCoordinator.self) private var notificationRouter
    private var companies: [Company] { appState.companies.sorted { $0.lastViewed > $1.lastViewed } }
    private var subscriptions: [Subscription] { appState.subscriptions }
    private var cards: [FinancialCard] { appState.cards }
    private var institutions: [Institution] { appState.institutions }
    private var loans: [Loan] { appState.loans }
    private var documents: [CompanyDocument] { appState.documents }

    @Bindable var vm: AppViewModel
    @State private var showAddCompany = false
    @State private var showSharedWithMe = false
    @State private var editingCompany: Company?
    @State private var companyToDelete: Company?
    @State private var companyToShare: Company?
    @State private var duoSharingRequest: DuoDashboardSharingRequest?
    
    // Shared Item states
    @State private var selectedSubscription: Subscription?
    @State private var selectedCard: FinancialCard?
    @State private var selectedInstitution: Institution?
    @State private var selectedLoan: Loan?
    @State private var selectedDocument: CompanyDocument? = nil
    @State private var showAssistant = false    
    @State private var showPremiumUpgrade = false
    @State private var showDowngradeSelection = false
    @State private var showConnectionGraph = false
    @State private var duoBriefing = DuoBriefingStore()
    @State private var usesDuoSideToolbar = false
    @State private var isDuoDevice = false
    @State private var usesDuoLandscapeDashboard = false
    @State private var duoBottomToolbarCenterY: CGFloat?
    @State private var duoBottomControlsWindowCenterY: CGFloat?
    @State private var duoBottomToolbarWindowCenterY: CGFloat?
    @State private var showBriefing = false
    @State private var showNotificationInbox = false
    @State private var showTransactionCenter = false
    @State private var taxReviewCompany: Company?
    @State private var initialTransactionID: UUID?
    @State private var initiallyShowsTransactionReview = false
    
    private var currentUserId: UUID? { authViewModel.currentUser?.id }
    
    // Shared companies
    private var sharedCompanies: [Company] {
        guard let currentUserId = currentUserId else { return [] }
        return appState.companies.filter { $0.userId != currentUserId }
    }

    @State private var dummyCompany = Company(
        userId: UUID(),
        name: "ARK (dummy)",
        structure: "LLC",
        companyDescription: "ARK Investment & Innovation LLC.",
        colorHex: "#f59e0b",
        website: "ark.com"
    )

    // Tutorial target frames (captured in 'dashboard' coordinate space)
    @State private var tutorialEntityFrame: CGRect = .zero
    @State private var tutorialSearchFrame: CGRect = .zero
    @State private var tutorialAssistantFrame: CGRect = .zero

    private func openPendingSearch() {
        guard appState.hasLoadedPortfolio, let request = SearchRouteCoordinator.shared.pending else { return }
        vm.searchQuery = request.query
        vm.showSearch = true
        SearchRouteCoordinator.shared.clear()
    }

    var body: some View {
        NavigationStack(path: $vm.path) {
            dashboardWithToolbar
        }
    }

    @ViewBuilder
    private var dashboardWithToolbar: some View {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) {
            dashboardSurface.modifier(DuoSideToolbar(
                usesSideToolbar: $usesDuoSideToolbar,
                bottomControlCenterY: $duoBottomToolbarCenterY,
                bottomControlWindowCenterY: $duoBottomToolbarWindowCenterY,
                isLandscapeExpanded: $usesDuoLandscapeDashboard,
                reportsDuoDevice: $isDuoDevice,
                isActive: vm.path.isEmpty,
                admin: dashboardAdminButton,
                primaryAction: dashboardShareControl.frame(width: 52, height: 52),
                add: plusCommandMenu,
                entities: EmptyView()
            ))
        } else {
            dashboardSurface
        }
        #else
        dashboardSurface
        #endif
    }

    private var dashboardSurface: some View {
            ZStack(alignment: .top) {
                Color.zifrBG.ignoresSafeArea()

                VStack(spacing: 0) {
                    if !usesDuoLandscapeDashboard { dashboardHeader }
                    portfolioPresentedPanels
            }
            .safeAreaInset(edge: .bottom) {
                if !usesDuoLandscapeDashboard { dashboardBottomControls }
            }
            } // End ZStack
            .coordinateSpace(name: "dashboard")
            // ── Real onboarding spotlights (needsEntity / needsAssistant) ──
            .overlayPreferenceValue(SpotlightBoundsKey.self) { anchors in
                if !anchors.isEmpty {
                    if onboardingState.isSpotlightingEntity {
                        SpotlightOverlayView(
                            anchors: anchors,
                            message: "Welcome! Let's start by adding your first business entity or individual account.",
                            stepIndex: 1, totalSteps: 8,
                            onSkip: { onboardingState.skipOnboarding() },
                            onTapTarget: {
                                onboardingState.currentStep = .notStarted
                                requestAddCompany()
                            }
                        )
                    } else if onboardingState.isSpotlightingAssistant {
                        SpotlightOverlayView(
                            anchors: anchors,
                            message: "Meet your AI Assistant! It can help you manage your entity, answer questions, and even add accounts for you.",
                            onSkip: { onboardingState.skipOnboarding() },
                            onTapTarget: {
                                onboardingState.completeOnboarding()
                                showAssistant = true
                            }
                        )
                    }
                }
            }
            // ── Tutorial spotlight overlay (steps 1–4 and 15) on Dashboard ──
            .overlay {
                if onboardingState.isTutorialActive && !onboardingState.isTutorialDone {
                    let isDashboardStep: Bool = {
                        switch onboardingState.currentStep {
                        case .tutorialEntityCard, .tutorialQuickActions,
                             .tutorialSearch, .tutorialAssistant:
                            return true
                        default: return false
                        }
                    }()

                    if isDashboardStep {
                        let targetFrame: CGRect = {
                            switch onboardingState.currentStep {
                            case .tutorialEntityCard, .tutorialQuickActions:
                                return tutorialEntityFrame
                            case .tutorialSearch:
                                return tutorialSearchFrame
                            case .tutorialAssistant:
                                return tutorialAssistantFrame
                            default:
                                return .zero
                            }
                        }()

                        if targetFrame != .zero {
                            TutorialSpotlightOverlayView(
                                anchor: targetFrame,
                                stepIndex: onboardingState.tutorialStepIndex,
                                totalSteps: onboardingState.tutorialTotalSteps,
                                title: tutorialTitle(for: onboardingState.currentStep),
                                message: tutorialMessage(for: onboardingState.currentStep),
                                segment: onboardingState.tutorialSegmentLabel,
                                onBack: onboardingState.tutorialStepIndex > 1 ? { onboardingState.tutorialBack() } : nil,
                                onNext: { onboardingState.tutorialNext() },
                                onSkip: { onboardingState.exitTutorial(appState: appState) }
                            )
                            .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                        }
                    }
                }
            }
            // ── Step 8: Completion overlay ──
            .overlay {
                if onboardingState.isTutorialDone {
                    TutorialCompletionOverlay(
                        onGetStarted: {
                            onboardingState.exitTutorial(appState: appState)
                            requestAddCompany()
                        },
                        onExplore: {
                            onboardingState.exitTutorial(appState: appState)
                        }
                    )
                    .transition(.opacity)
                }
            }
    }



    private var alignsClosedDuoSearch: Bool {
        usesDuoSideToolbar && !usesDuoLandscapeDashboard
    }

    private var closedDuoSearchOffset: CGFloat {
        guard alignsClosedDuoSearch,
              let bottomControlY = duoBottomToolbarWindowCenterY,
              let rowY = duoBottomControlsWindowCenterY else { return 0 }
        let adjustment = bottomControlY - rowY
        // Ignore measurements from different fold/rotation passes until both
        // hosts have settled. The final alignment is less than one hit target.
        return abs(adjustment) <= 44 ? adjustment : 0
    }

    @ViewBuilder
    private var dashboardBottomControls: some View {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) {
            dashboardBottomControlsRow
                .background {
                    DuoDashboardWindowCenterReader { value in
                        duoBottomControlsWindowCenterY = value
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        } else {
            dashboardBottomControlsRow
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        #else
        dashboardBottomControlsRow
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        #endif
    }

    private var dashboardBottomControlsRow: some View {
        HStack(spacing: 10) {
            if !usesDuoSideToolbar { dashboardAdminButton }
            dashboardSearchButton
                .offset(y: closedDuoSearchOffset)
            dashboardAssistantButton
                .offset(y: closedDuoSearchOffset)
            if !usesDuoSideToolbar {
                plusCommandMenu
            }
        }
    }

    private var dashboardHeader: some View {
        headerSection
            .padding(.top, 3)
            .padding(.bottom, 7)
    }

    private var dashboardAdminButton: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            vm.path.append(AppViewModel.AppRoute.adminSettings)
        } label: {
            ZStack {
                bottomControlGlass(Circle())
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
        .accessibilityLabel("Admin settings")
    }

    private var dashboardSearchButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            vm.showSearch = true
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
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(bottomControlGlass(Capsule()))
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
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background(
            Group {
                if onboardingState.isTutorialActive {
                    GeometryReader { geo in
                        Color.clear.onAppear {
                            tutorialSearchFrame = geo.frame(in: .global)
                        }.onChange(of: geo.frame(in: .global)) { _, f in
                            tutorialSearchFrame = f
                        }
                    }
                }
            }
        )
    }

    private var dashboardAssistantButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showAssistant = true
        } label: {
            dashboardGeminiIcon
                .frame(width: isDuoDevice ? 44 : 52, height: isDuoDevice ? 44 : 52)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Gemini Live")
        .accessibilityHint("Starts a voice conversation with Miloom")
        .spotlightTarget(isActive: onboardingState.isSpotlightingAssistant)
        .background(
            Group {
                if onboardingState.isTutorialActive {
                    GeometryReader { geo in
                        Color.clear.onAppear {
                            tutorialAssistantFrame = geo.frame(in: .global)
                        }.onChange(of: geo.frame(in: .global)) { _, f in
                            tutorialAssistantFrame = f
                        }
                    }
                }
            }
        )
    }


    private var portfolioLifecyclePanels: some View {
        portfolioPanels
            .task {
                // Fallback for OAuth/root-view timing: the dashboard should never
                // remain on its placeholder simply because the first auth callback
                // arrived before the app-level loader attached.
                if appState.companies.isEmpty {
                    await DataRepository.shared.fetchAllData(appState: appState)
                }
            }
            .onAppear {
                onboardingState.evaluateState(appState: appState)
            }
            .onChange(of: appState.companies.count) { _, _ in
                let previousStep = onboardingState.currentStep
                onboardingState.evaluateState(appState: appState)

                if (previousStep == .needsEntity || previousStep == .notStarted)
                    && onboardingState.currentStep == .needsBank
                    && !showAddCompany {
                    // Automatically jump to the new entity's financial tab
                    if let newCompany = appState.companies.sorted(by: { $0.lastModified > $1.lastModified }).first {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            vm.selectedCompany = newCompany
                            vm.activeTab = .financial
                            vm.touchCompany(newCompany, appState: appState)
                            vm.path.append(newCompany)
                        }
                    }
                }
            }
            .onChange(of: appState.institutions.count) { _, _ in
                let previousStep = onboardingState.currentStep
                onboardingState.evaluateState(appState: appState)
                guard previousStep == .needsBank else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    handlePostBankNavigation()
                }
            }
            .refreshable {
                await DataRepository.shared.fetchAllData(appState: appState)
            }
            .confirmationDialog(
                companyToDelete?.userId != currentUserId ? "Leave Company" : "Delete Company",
                isPresented: Binding(
                    get: { companyToDelete != nil },
                    set: { if !$0 { companyToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(companyToDelete?.userId != currentUserId ? "Leave" : "Delete", role: .destructive) {
                    if let company = companyToDelete {
                        vm.deleteCompany(company, appState: appState, currentUserId: currentUserId)
                    }
                    companyToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    companyToDelete = nil
                }
            } message: {
                if companyToDelete?.userId != currentUserId {
                    Text("Are you sure you want to leave this company? It will be removed from your dashboard.")
                } else {
                    Text("Are you sure you want to delete this company? All associated data will be removed for everyone.")
                }
            }
            // Only the legacy host has a sidebar toggle to remove. Duo uses a
            // single stack; removing a native item there can hide its Share label.
            .navigationBarBackButtonHidden(true)
            .toolbar(removing: !isDuoDevice && vm.path.isEmpty ? .sidebarToggle : nil)
            .navigationDestination(for: Company.self) { company in
                CompanyDetailView(
                    company: company,
                    vm: vm,
                    onShowAllEntities: { showBriefing = false }
                )
                .id(company.id)
            }
            .navigationDestination(for: AppViewModel.AppRoute.self) { route in
                if route == .adminSettings {
                    AdminSettingsView(vm: vm)
                }
            }
            .navigationDestination(isPresented: $showSharedWithMe) {
                if let uid = currentUserId {
                    SharedWithMeView(vm: vm, currentUserId: uid)
                }
            }
            .sheet(item: $companyToShare) { company in
                ShareEntitySheet(resourceId: company.id, resourceType: "company", resourceTitle: company.name)
            }
            .sheet(item: $duoSharingRequest) { request in
                ShareEntitySheet(
                    resourceId: request.company.id, resourceType: request.scope.rawValue,
                    resourceTitle: request.scope == .company ? request.company.name : request.scope.title
                )
            }
            .sheet(isPresented: $showAddCompany) {
                NewEntitySheet(vm: vm) { company in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        vm.selectedCompany = company
                        vm.activeTab = .financial
                        vm.touchCompany(company, appState: appState)
                        vm.path.append(company)
                    }
                }
            }
            .sheet(isPresented: $showPremiumUpgrade) {
                PremiumUpgradeView(gate: accessController.pendingGate)
            }
            .sheet(isPresented: $showDowngradeSelection) {
                DowngradeSelectionView()
            }
            .sheet(item: $editingCompany) { company in
                NewEntitySheet(vm: vm, company: company) { _ in }
            }
            .sheet(isPresented: $vm.showSearch) {
                GlobalSearchView(vm: vm)
            }
            .sheet(isPresented: $showBriefing) {
                GeometryReader { geometry in
                    ZStack {
                        receiptSheetBackground
                        ScrollView(.vertical) {
                            OwnerHealthBriefingDashboard(
                                vm: vm,
                                onOpenResource: { obligation in
                                    dismissBriefing {
                                        openBriefingResource(obligation)
                                    }
                                },
                                onOpenHealthResource: { kind, resourceID in
                                    dismissBriefing {
                                        openHealthResource(kind, resourceID)
                                    }
                                },
                                onExploreConnections: {
                                    dismissBriefing {
                                        showConnectionGraph = true
                                    }
                                }
                            )
                            .frame(width: max(geometry.size.width - 40, 0))
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                        }
                        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                        .scrollIndicators(.hidden)
                        .clipped()
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(hex: "#1C1C1E"))
                .preferredColorScheme(.light)
            }
            .fullScreenCover(isPresented: $showAssistant) {
                AssistantOnboardingView(vm: vm)
                    .environment(appState)
            }
            .fullScreenCover(isPresented: $showConnectionGraph) {
                ConnectionGraphView { reference in
                    openHealthResource(reference.kind, reference.resourceId)
                }
                .environment(appState)
            }
    }

    private var portfolioPresentedPanels: some View {
        portfolioLifecyclePanels
            .sheet(item: $selectedSubscription) { sub in
                EditSubscriptionSheet(sub: sub, institutions: institutions, cards: cards, vm: vm, isNew: false, onSave: {})
            }
            .sheet(item: $selectedCard) { card in
                EditCardSheet(card: card, vm: vm, institutions: institutions, cards: cards, isNew: false)
            }
            .sheet(item: $selectedInstitution) { inst in
                EditInstitutionSheet(institution: inst, institutions: institutions, cards: cards, loans: loans, vm: vm, isNew: false)
            }
            .sheet(item: $selectedLoan) { loan in
                EditLoanSheet(loan: loan, vm: vm, isNew: false, institutions: institutions, cards: cards)
            }
            .sheet(item: $taxReviewCompany) { company in TaxOpportunitiesView(initialCompanyId: company.id) }
            .sheet(item: $selectedDocument) { doc in
                EditDocumentSheet(doc: doc, vm: vm, isNew: false, companyStructure: companies.first(where: { $0.id == doc.companyId })?.structure ?? "LLC")
            }
            .sheet(isPresented: $showNotificationInbox) {
                NotificationInboxView(vm: vm) { route in
                    showNotificationInbox = false
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(250))
                        notificationRouter.enqueue(route)
                    }
                }
            }
            .sheet(isPresented: $showTransactionCenter) {
                PortfolioTransactionCenterView(
                    vm: vm,
                    initialTransactionID: initialTransactionID,
                    initiallyShowsReviewQueue: initiallyShowsTransactionReview
                )
                .environment(appState)
            }
            // Tutorial navigation coordinator
            .onChange(of: onboardingState.currentStep) { _, step in
                switch step {
                // ── Command Center steps: push into entity, home tab ──
                case .tutorialCommandCenter, .tutorialCommandQuickAdd,
                     .tutorialCommandFinancials, .tutorialCommandSubscriptions,
                     .tutorialCommandDocuments:
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        let entity = appState.companies.first ?? dummyCompany
                        vm.selectedCompany = entity
                        if vm.path.isEmpty {
                            vm.path.append(entity)
                        }
                        // CompanyDetailView will render the Control Center
                    }

                // ── Financial steps (incl. tabBar step): push into entity, financial tab ──
                case .tutorialCommandTabBar,
                     .tutorialFinancialPage, .tutorialFinancialWallet,
                     .tutorialFinancialCardTap, .tutorialFinancialSwipe:
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        let entity = appState.companies.first ?? dummyCompany
                        vm.selectedCompany = entity
                        if vm.path.isEmpty {
                            vm.path.append(entity)
                        }
                        // CompanyDetailView's own onChange will set vm.activeTab = .financial
                    }

                // ── Back from step 5 → Dashboard steps resume (pop path so DashboardView shows overlay) ──
                case .tutorialEntityCard, .tutorialQuickActions,
                     .tutorialSearch, .tutorialAssistant, .tutorialSwipeHint:
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        vm.path = NavigationPath()
                        vm.activeTab = .financial
                    }

                // ── Done ──
                case .tutorialDone:
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        vm.path = NavigationPath()
                        vm.activeTab = .financial
                    }

                default:
                    break
                }
            }
            .task(id: appState.searchDocumentRevision) {
                if let userID = authViewModel.currentUser?.id { await SearchDocumentIndexer.shared.index(appState: appState, userID: userID) }
            }
            .onChange(of: SearchRouteCoordinator.shared.pending) { _, _ in openPendingSearch() }
            .onChange(of: notificationRouter.pendingRoute) { _, _ in
                openPendingNotificationRouteIfReady()
            }
            .onChange(of: appState.hasLoadedPortfolio) { _, _ in
                openPendingNotificationRouteIfReady()
                openPendingSearch()
            }
            .onChange(of: showNotificationInbox) { _, isPresented in
                if !isPresented { openPendingNotificationRouteIfReady() }
            }
            .onAppear {
                checkDowngradeSelection()
                openPendingNotificationRouteIfReady()
                openPendingSearch()
            }
            .onChange(of: appState.companies.count) { _, _ in checkDowngradeSelection() }
            .onChange(of: appState.portfolioUserID) { _, _ in duoBriefing.invalidate() }
            .onChange(of: accessController.effectiveSnapshot) { _, _ in duoBriefing.invalidate() }
            .onChange(of: accessController.snapshot.status) { _, _ in checkDowngradeSelection() }
    }

    @ViewBuilder
    private var portfolioPanels: some View {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) {
            DuoDashboardPanels(
                bottomControlCenterY: duoBottomToolbarCenterY,
                cards: { expanded in entityList(isDuoExpanded: expanded) },
                receipt: { inlineBriefingPanel },
                header: { dashboardHeader },
                footer: { dashboardBottomControls }
            )
        } else {
            entityList()
        }
        #else
        entityList()
        #endif
    }

    @ViewBuilder
    private var inlineBriefingPanel: some View {
        if accessController.permits(.ownerBriefing, appState: appState, userId: currentUserId) {
            DuoInlineBriefingView(
                vm: vm, store: duoBriefing, isActive: vm.path.isEmpty,
                onOpenResource: openBriefingResource,
                onOpenHealthResource: openHealthResource,
                onExploreConnections: { showConnectionGraph = true }
            )
        } else {
            ScrollView {
                DuoBriefingPlaceholder(
                    message: "Your executive briefing is available with Miloom Pro.",
                    action: { presentBriefing(source: "duo_dashboard_inline") }
                )
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private func entityList(isDuoExpanded: Bool = false) -> some View {
        if duoLayout.isDuoDevice && duoLayout.isExpanded && !duoLayout.isLandscape
            && !companies.isEmpty && !onboardingState.isTutorialActive {
            ScrollView {
                VStack(spacing: 16) {
                    if let issue = appState.portfolioLoadIssue {
                        Button {
                            Task { await DataRepository.shared.fetchAllData(appState: appState) }
                        } label: {
                            Label(issue, systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                                .font(.footnote).foregroundStyle(Color.zifrGold)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Retry loading entities: \(issue)")
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                        ForEach(filteredCompanies) { company in
                            companyCardRow(for: company, compact: true).frame(maxWidth: .infinity)
                        }
                    }
                    .accessibilityIdentifier("duo.portraitEntityGrid")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
        } else {
            legacyEntityList(isDuoExpanded: isDuoExpanded)
        }
    }

    private func legacyEntityList(isDuoExpanded: Bool = false) -> some View {
                    List {
                        if let loadIssue = appState.portfolioLoadIssue {
                            Button {
                                Task { await DataRepository.shared.fetchAllData(appState: appState) }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                                        .foregroundStyle(Color.zifrGold)
                                    Text(loadIssue)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.78))
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 4)
                                    Text("RETRY")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Color.zifrGold)
                                }
                                .padding(12)
                                .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 10, trailing: 20))
                        }

                        ForEach(Array(filteredCompanies.enumerated()), id: \.element.id) { index, company in
                            let row = companyCardRow(for: company)
                            let isLast = index == filteredCompanies.count - 1
                            let hasPlaceholder = companies.isEmpty || (onboardingState.tutorialHasBeenRun && onboardingState.isTutorialActive)
                            row
                                .background(tutorialFrameCapture(index: index))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: (isLast && !hasPlaceholder) ? (isDuoExpanded ? 16 : 120) : 16, trailing: 20))
                        }

                        // Add company button / empty state placeholder under the dummy company
                        Group {
                            if companies.isEmpty || (onboardingState.tutorialHasBeenRun && onboardingState.isTutorialActive) {
                                // Un-blurred only while the tutorial is actively running.
                                if onboardingState.tutorialHasBeenRun && onboardingState.isTutorialActive {
                                    // Tutorial in progress: show demo card fully visible
                                    CompanyCardView(
                                        company: dummyCompany,
                                        institutionsCount: 2,
                                        subscriptionsCount: 4,
                                        docsCount: 3,
                                        onEdit: {}
                                    )
                                    .allowsHitTesting(false)
                                    .padding(.top, 4)
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.onAppear {
                                                tutorialEntityFrame = geo.frame(in: .global)
                                            }.onChange(of: geo.frame(in: .global)) { _, f in
                                                tutorialEntityFrame = f
                                            }
                                        }
                                    )
                                } else {
                                    // Empty state (pre-tutorial, or after tutorial): blurred card + CTA
                                    Button {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        requestAddCompany()
                                    } label: {
                                        ZStack {
                                            CompanyCardView(
                                                company: dummyCompany,
                                                institutionsCount: 0,
                                                subscriptionsCount: 0,
                                                docsCount: 0,
                                                onEdit: {}
                                            )
                                            .allowsHitTesting(false)
                                            .blur(radius: 3)
                                            .opacity(0.8)

                                            VStack(spacing: 16) {
                                                Image(systemName: "plus.app.fill")
                                                    .font(.system(size: 28))
                                                    .foregroundStyle(.white)
                                                Text("ADD YOUR COMPANY OR ENTITY")
                                                    .font(.system(size: 11, weight: .black))
                                                    .textCase(.uppercase)
                                                    .tracking(2)
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                    }
                                    .padding(.top, 4)
                                    .spotlightTarget(isActive: onboardingState.isSpotlightingEntity)
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: isDuoExpanded ? 16 : 120, trailing: 20))
                    }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .scrollIndicators(.hidden)
    }

    private var filteredCompanies: [Company] {
        let baseList = companies
        
        guard !vm.searchQuery.isEmpty else { return baseList }
        let q = vm.searchQuery.lowercased()
        return baseList.filter { $0.name.lowercased().contains(q) || $0.structure.lowercased().contains(q) }
    }

    struct SharedItem: Identifiable {
        let id: UUID
        let title: String
        let type: String
        let role: String
        let createdAt: Date
        let senderEmail: String
        let rawItem: Any
    }

    private var receiptSheetBackground: some View {
        Color(hex: "#1C1C1E")
            .ignoresSafeArea()
    }

    @ViewBuilder
    private func bottomControlGlass<S: Shape>(_ shape: S) -> some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(
                    .clear
                        .tint(Color.zifrTabBarFill.opacity(0.28))
                        .interactive(),
                    in: shape
                )
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay(
                    shape.fill(Color.zifrTabBarFill.opacity(0.35))
                )
        }
    }

    private var dashboardGeminiIcon: some View {
        ZStack {
            bottomControlGlass(Circle())
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
                .allowsHitTesting(false)

            // Gemini's four-point sparkle, rendered sharply at every display scale.
            MiloomGeminiSparkle()
        }
        .frame(width: 44, height: 44)
    }

    @ViewBuilder
    private var plusCommandMenu: some View {
        if isDuoDevice {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                requestAddCompany()
            } label: {
                dashboardPlusLabel
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add entity")
        } else {
            legacyPlusCommandMenu
        }
    }

    private var legacyPlusCommandMenu: some View {
        Menu {
            if !companies.isEmpty {
                Section("Share Entity") {
                    ForEach(companies) { company in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            companyToShare = company
                        } label: {
                            Label(company.name.isEmpty ? "New Business" : company.name, systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        } label: {
            dashboardPlusLabel
        } primaryAction: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            requestAddCompany()
        }
        .buttonStyle(.plain)
    }

    private var dashboardPlusLabel: some View {
        ZStack {
            bottomControlGlass(Circle())
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
    }

    private var shareableDuoCompanies: [Company] {
        companies.filter { company in
            AppViewModel.resourceAllowsSharing(
                appState.resourceShares, actorID: appState.portfolioUserID,
                ownerID: company.userId, companyID: company.id
            )
        }
    }

    private var dashboardShareControl: some View {
        Menu {
            Section("Share Entity") {
                ForEach(shareableDuoCompanies) { company in
                    Menu(company.name.isEmpty ? "New Business" : company.name) {
                        ForEach(EntitySharingScope.allCases) { scope in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                duoSharingRequest = DuoDashboardSharingRequest(company: company, scope: scope)
                            } label: {
                                Label(scope.title, systemImage: scope.icon)
                            }
                        }
                    }
                }
            }
        } label: {
            MiloomCircularToolbarLabel {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
        }
        .buttonStyle(.plain)
        .disabled(shareableDuoCompanies.isEmpty)
        .accessibilityLabel("Share access")
        .accessibilityHint("Choose an entity and which records to share")
    }

    private func requestAddCompany() {
        if accessController.request(
            .additionalCompany,
            source: "dashboard_add_company",
            appState: appState,
            userId: currentUserId
        ) {
            showAddCompany = true
        } else {
            showPremiumUpgrade = true
        }
    }

    private func presentBriefing(source: String = "dashboard_briefing_button") {
        guard accessController.request(
            .ownerBriefing,
            source: source,
            appState: appState,
            userId: currentUserId
        ) else {
            showPremiumUpgrade = true
            return
        }
        showBriefing = true
    }

    private func dismissBriefing(then action: @escaping () -> Void) {
        showBriefing = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: action)
    }

    private func checkDowngradeSelection() {
        showDowngradeSelection = accessController.requiresDowngradeSelection(appState: appState)
    }

    private func openBriefingResource(_ obligation: PortfolioObligation) {
        if obligation.actionType == "open_tax_opportunities" {
            taxReviewCompany = appState.companies.first { $0.id == obligation.companyId }
            return
        }
        openHealthResource(obligation.sourceType, obligation.sourceId)
    }

    private func openHealthResource(_ resourceType: ResourceKind, _ resourceID: UUID) {
        switch resourceType {
        case .company:
            if let company = appState.companies.first(where: { $0.id == resourceID }) {
                vm.path.append(company)
            }
        case .subscription:
            selectedSubscription = appState.subscriptions.first { $0.id == resourceID }
        case .card:
            selectedCard = appState.cards.first { $0.id == resourceID }
        case .institution:
            selectedInstitution = appState.institutions.first { $0.id == resourceID }
        case .loan:
            selectedLoan = appState.loans.first { $0.id == resourceID }
        case .document:
            selectedDocument = appState.documents.first { $0.id == resourceID }
        case .collaborator:
            break
        }
    }

    private func openPendingNotificationRouteIfReady() {
        guard authViewModel.isAuthenticated,
              appState.hasLoadedPortfolio,
              !showNotificationInbox,
              let route = notificationRouter.takePendingRoute() else { return }
        openNotificationRoute(route)
    }

    private func openNotificationRoute(_ route: NotificationRoute) {
        switch route {
        case .ownerBriefing:
            presentBriefing(source: "notification_owner_briefing")
        case .institution(let institutionID):
            guard let institution = appState.institutions.first(where: { $0.id == institutionID }) else {
                appState.error = "This institution is no longer available."
                return
            }
            selectedInstitution = institution
        case .transaction(let transactionID):
            initialTransactionID = transactionID
            initiallyShowsTransactionReview = false
            showTransactionCenter = true
        case .transactionReview:
            initialTransactionID = nil
            initiallyShowsTransactionReview = true
            showTransactionCenter = true
        case .resource(let kind, let resourceID):
            openHealthResource(kind, resourceID)
        }
    }

    private func openSharedItem(_ share: SharedItem) {
        // Load the full object from DataRepository and set it to the appropriate selected state
        let lowercasedType = share.type.lowercased()
        if lowercasedType == "subscription" {
            if let sub = appState.subscriptions.first(where: { $0.id == share.id }) {
                selectedSubscription = sub
            }
        } else if lowercasedType == "card" {
            if let card = appState.cards.first(where: { $0.id == share.id }) {
                selectedCard = card
            }
        } else if lowercasedType == "loan" {
            if let loan = appState.loans.first(where: { $0.id == share.id }) {
                selectedLoan = loan
            }
        } else if lowercasedType == "document" {
            if let doc = appState.documents.first(where: { $0.id == share.id }) {
                selectedDocument = doc
            }
        } else if lowercasedType == "institution" {
            if let inst = appState.institutions.first(where: { $0.id == share.id }) {
                selectedInstitution = inst
            }
        }
    }

    private var orphanedSharedItems: [SharedItem] {
        var items: [SharedItem] = []
        let localCompanyIds = Set(appState.companies.map { $0.id })
        
        func process<T: Identifiable>(list: [T], type: String, titleKeyPath: KeyPath<T, String>, companyIdKeyPath: KeyPath<T, UUID>) {
            for item in list {
                let cid = item[keyPath: companyIdKeyPath]
                let effectiveCid = appState.localCompanyOverrides[(item.id as! UUID).uuidString] ?? cid
                
                if !localCompanyIds.contains(effectiveCid) {
                    if let share = appState.resourceShares.first(where: { $0.resourceId == (item.id as! UUID) || $0.resourceId == effectiveCid }) {
                        let role = share.role
                        let sEmail = share.senderEmail ?? "Unknown Sender"
                        let createdAt = share.createdAt
                        
                        items.append(SharedItem(
                            id: item.id as! UUID, 
                            title: item[keyPath: titleKeyPath], 
                            type: type, 
                            role: role, 
                            createdAt: createdAt,
                            senderEmail: sEmail,
                            rawItem: item
                        ))
                    }
                }
            }
        }
        
        process(list: appState.subscriptions, type: "Subscription", titleKeyPath: \.name, companyIdKeyPath: \.companyId)
        process(list: appState.cards, type: "Card", titleKeyPath: \.name, companyIdKeyPath: \.companyId)
        process(list: appState.institutions, type: "Institution", titleKeyPath: \.name, companyIdKeyPath: \.companyId)
        process(list: appState.loans, type: "Loan", titleKeyPath: \.name, companyIdKeyPath: \.companyId)
        process(list: appState.documents, type: "Document", titleKeyPath: \.name, companyIdKeyPath: \.companyId)
        
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    private var headerSection: some View {
        ZStack {
            GeometryReader { geometry in
                Image("miloom_text_embossed")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width * 0.35)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            }

            HStack(spacing: 8) {
                Spacer()
                if isDuoDevice && !usesDuoSideToolbar { dashboardShareControl }
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    presentBriefing(source: "dashboard_header_receipt")
                } label: {
                    Image(systemName: "receipt")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.82))
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.32), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Executive briefing receipt")
                .accessibilityHint("Opens the personal or business monthly briefing")

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showNotificationInbox = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: appState.unreadNotificationCount > 0 ? "bell.fill" : "bell")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.82))
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.32), in: Circle())

                        if appState.unreadNotificationCount > 0 {
                            Text(appState.unreadNotificationCount > 99 ? "99+" : "\(appState.unreadNotificationCount)")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .frame(minWidth: 17, minHeight: 17)
                                .background(Color.red, in: Capsule())
                                .offset(x: 3, y: -2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Notification inbox")
                .accessibilityValue(appState.unreadNotificationCount == 0
                    ? "No unread alerts"
                    : "\(appState.unreadNotificationCount) unread alerts")
            }
            .padding(.trailing, 20)
        }
        .frame(height: 52)
    }
    
    @ViewBuilder
    private func companyCardRow(for company: Company, compact: Bool = false) -> some View {
        let iCount = institutions.filter { $0.companyId == company.id }.count
        let sCount = subscriptions.filter { $0.companyId == company.id }.count
        let dCount = documents.filter { $0.companyId == company.id }.count
        
        #if DEBUG && targetEnvironment(simulator) && MILOOM_LAYOUT_PREVIEW
        // Show fixture ownership only in the labeled simulator preview. Do not
        // create an authenticated session or alter any persistence authorization.
        let cardViewerID: UUID? = MiloomLayoutPreviewData.ownerID
        #else
        let cardViewerID = currentUserId
        #endif
        let isSharedWithMe = (company.userId != cardViewerID)
        let isSharedByMe = (company.userId == cardViewerID) && appState.resourceShares.contains(where: { $0.resourceId == company.id })
        let role = appState.resourceShares.first(where: {
            $0.resourceType == "company" && $0.resourceId == company.id && $0.userId == cardViewerID
        })?.role ?? "Limited access"
        let canEdit = !isSharedWithMe || ["Editor", "Admin"].contains(role)

        let navigateAction: (AppViewModel.CompanyTab) -> Void = { tab in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            vm.selectedCompany = company
            vm.activeTab = tab
            vm.touchCompany(company, appState: appState)
            vm.path.append(company)
        }

        CompanyCardView(
            company: company,
            institutionsCount: iCount,
            subscriptionsCount: sCount,
            docsCount: dCount,
            onEdit: { editingCompany = company },
            canEdit: canEdit,
            onShare: isDuoDevice || isSharedWithMe ? nil : { companyToShare = company },
            shareRole: role,
            isSharedWithMe: isSharedWithMe,
            isSharedByMe: isSharedByMe,
            onTapSubscriptions: { navigateAction(.subscriptions) },
            onTapInstitutions: { navigateAction(.financial) },
            onTapDocuments: { navigateAction(.documents) },
            onTapMain: { navigateAction(.financial) },
            usesCompactLayout: compact
        )
    }

    // MARK: - Onboarding helpers

    private func handlePostBankNavigation() {
        switch onboardingState.currentStep {
        case .needsReview:
            vm.activeTab = .subscriptions
        case .needsAssistant, .completed:
            vm.path = NavigationPath()
            vm.activeTab = .financial
        default:
            break
        }
    }

    // MARK: - Tutorial helpers


    @ViewBuilder
    private func tutorialFrameCapture(index: Int) -> some View {
        if index == 0 && onboardingState.isTutorialActive {
            GeometryReader { geo in
                Color.clear
                    .onAppear { tutorialEntityFrame = geo.frame(in: .global) }
                    .onChange(of: geo.frame(in: .global)) { _, f in tutorialEntityFrame = f }
            }
        }
    }

    private func tutorialTitle(for step: OnboardingStep) -> String {
        switch step {
        case .tutorialEntityCard:    return "Your Entity"
        case .tutorialQuickActions:  return "Quick Actions"
        case .tutorialSearch:        return "Global Search"
        case .tutorialAssistant:     return "AI Assistant"
        case .tutorialSwipeHint:     return "Navigate & Edit"
        default:                     return ""
        }
    }

    private func tutorialMessage(for step: OnboardingStep) -> String {
        switch step {
        case .tutorialEntityCard:
            return "This is your entity — a company, LLC, or personal account. Everything you track lives inside it."
        case .tutorialQuickActions:
            return "Tap the entity card to open its Command Center with Subscriptions, Financials, and Documents."
        case .tutorialSearch:
            return "Instantly find any entity, subscription, financial record, or document across all your accounts."
        case .tutorialAssistant:
            return "Your AI assistant can add accounts, answer questions about your finances, and keep you organised."
        case .tutorialSwipeHint:
            return "Swipe left on an entity card to edit it. Swipe right to archive. Long-press to share."
        default:
            return ""
        }
    }
}

private struct DuoDashboardSharingRequest: Identifiable {
    let company: Company
    let scope: EntitySharingScope
    var id: String { "\(company.id)-\(scope.rawValue)" }
}



/// Shared vector glyph; dashboard and Duo entity controls use the same mark.
struct MiloomGeminiSparkle: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 12, y: 0))
            path.addCurve(to: CGPoint(x: 24, y: 12),
                          control1: CGPoint(x: 13.8, y: 7.8),
                          control2: CGPoint(x: 16.2, y: 10.2))
            path.addCurve(to: CGPoint(x: 12, y: 24),
                          control1: CGPoint(x: 16.2, y: 13.8),
                          control2: CGPoint(x: 13.8, y: 16.2))
            path.addCurve(to: CGPoint(x: 0, y: 12),
                          control1: CGPoint(x: 10.2, y: 16.2),
                          control2: CGPoint(x: 7.8, y: 13.8))
            path.addCurve(to: CGPoint(x: 12, y: 0),
                          control1: CGPoint(x: 7.8, y: 10.2),
                          control2: CGPoint(x: 10.2, y: 7.8))
            path.closeSubpath()
        }
        .fill(LinearGradient(
            colors: [Color(hex: "#4CA6FF"), Color(hex: "#8D8BFF"), Color(hex: "#D495D9")],
            startPoint: .bottomLeading, endPoint: .topTrailing
        ))
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}

// MARK: - Shared Duo toolbar
import SwiftUI
#if compiler(>=6.4)
@available(iOS 27.1, *)
struct DuoSideToolbar<Admin: View, PrimaryAction: View, Add: View, Entities: View>: ViewModifier {
    @Environment(MiloomDuoLayoutState.self) private var layout
    @Binding var usesSideToolbar: Bool
    @Binding var bottomControlCenterY: CGFloat?
    @Binding var bottomControlWindowCenterY: CGFloat?
    @Binding var isLandscapeExpanded: Bool
    @Binding var reportsDuoDevice: Bool
    let isActive: Bool
    let admin: Admin
    let primaryAction: PrimaryAction
    let add: Add
    let entities: Entities
    var showsPrimaryActions = true

    // Do not gate native toolbar creation on its own emitted edge: the edge
    // can briefly disappear during a fold and prevent the items returning.
    private var hasNativeSideToolbar: Bool { layout.isDuoDevice && (!layout.isExpanded || layout.isLandscape) }
    private var hasPortraitToolbar: Bool { layout.isDuoDevice && layout.isExpanded && !layout.isLandscape }
    private var hasSideToolbar: Bool { hasNativeSideToolbar || hasPortraitToolbar }
    private var hasLandscapeDashboard: Bool { layout.isDuoDevice && layout.isExpanded && layout.isLandscape }

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .trailing, spacing: 8) {
                if hasPortraitToolbar && isActive {
                    VStack(spacing: 16) {
                        if showsPrimaryActions {
                            primaryAction
                            add
                        }
                        Spacer(minLength: 24)
                        entities
                        measuredAdmin
                    }
                    .frame(width: 52)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .padding(.trailing, 12)
                    .frame(maxHeight: .infinity)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("duo.portraitToolbar")
                }
            }
            .toolbar {
                if hasNativeSideToolbar && isActive {
                    if showsPrimaryActions {
                        ToolbarItem(placement: .topBarLeading) {
                            VStack(spacing: 16) {
                                primaryAction
                                add
                            }
                        }
                        .axisBehavior(.verticalPreferred)
                        .sharedBackgroundVisibility(.hidden)
                    }

                    ToolbarItemGroup(placement: .bottomBar) {
                        Spacer()
                        entities
                        measuredAdmin
                    }
                    .axisBehavior(.verticalPreferred)
                    .sharedBackgroundVisibility(.hidden)
                }
            }
            .onChange(of: layout.isDuoDevice, initial: true) { _, next in
                if reportsDuoDevice != next { reportsDuoDevice = next }
            }
            .onChange(of: hasLandscapeDashboard, initial: true) { _, value in
                if isActive { isLandscapeExpanded = value }
            }
            .onChange(of: isActive) { _, value in
                // Reconcile once on return from a navigation destination, even
                // if the root pane's orientation did not change while hidden.
                if value {
                    isLandscapeExpanded = hasLandscapeDashboard
                    usesSideToolbar = hasSideToolbar
                }
            }
            .onChange(of: hasSideToolbar, initial: true) { _, value in
                usesSideToolbar = value
            }
    }

    private var measuredAdmin: some View {
        admin
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.frame(in: .global).midY
            } action: { bottomControlCenterY = $0 }
            .background {
                DuoDashboardWindowCenterReader { bottomControlWindowCenterY = $0 }
            }
    }
}

/// Native toolbar items and collapsed content can have different SwiftUI global
/// coordinate roots. Compare window coordinates for the closed alignment only.
@available(iOS 27.1, *)
struct DuoDashboardWindowCenterReader: UIViewRepresentable {
    let onChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> CenterView {
        let view = CenterView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: CenterView, context: Context) {
        view.onChange = onChange
        view.scheduleReport()
    }

    final class CenterView: UIView {
        var onChange: (CGFloat) -> Void = { _ in }
        private var previousCenter: CGFloat?
        private var reportQueued = false

        override func didMoveToWindow() {
            super.didMoveToWindow()
            scheduleReport()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            scheduleReport()
        }

        func scheduleReport() {
            guard !reportQueued else { return }
            reportQueued = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                reportQueued = false
                guard window != nil else { return }
                let center = convert(CGPoint(x: bounds.midX, y: bounds.midY), to: nil).y
                guard previousCenter != center else { return }
                previousCenter = center
                onChange(center)
            }
        }
    }
}
#endif

struct SharedWithMeView: View {
    @Bindable var vm: AppViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    let currentUserId: UUID
    
    // Grouped data structure
    struct SharedItem: Identifiable {
        let id: UUID
        let title: String
        let type: String
        let role: String
        let createdAt: Date
    }
    
    struct SenderGroup: Identifiable {
        let id: String // sender email
        let displayName: String?
        var items: [SharedItem]
    }
    
    private var senderGroups: [SenderGroup] {
        var groups = [String: SenderGroup]()
        
        let localCompanyIds = Set(appState.companies.map { $0.id })
        
        // Helper to process items
        func process<T: Identifiable>(items: [T], type: String, titleKeyPath: KeyPath<T, String>, companyIdKeyPath: KeyPath<T, UUID>) {
            for item in items {
                let cid = item[keyPath: companyIdKeyPath]
                if !localCompanyIds.contains(cid) {
                    // It's orphaned! Look up its share record
                    if let share = appState.resourceShares.first(where: { $0.resourceId == (item.id as! UUID) || $0.resourceId == cid }) {
                        let role = share.role
                        let sEmail = share.senderEmail ?? "Unknown Sender"
                        let sName = share.senderDisplayName
                        let createdAt = share.createdAt
                        
                        let sharedItem = SharedItem(id: item.id as! UUID, title: item[keyPath: titleKeyPath], type: type, role: role, createdAt: createdAt)
                        
                        if groups[sEmail] != nil {
                            groups[sEmail]!.items.append(sharedItem)
                        } else {
                            groups[sEmail] = SenderGroup(id: sEmail, displayName: sName, items: [sharedItem])
                        }
                    }
                }
            }
        }
        
        process(items: appState.subscriptions, type: "Subscription", titleKeyPath: \.name, companyIdKeyPath: \.companyId)
        process(items: appState.cards, type: "Card", titleKeyPath: \.name, companyIdKeyPath: \.companyId)
        process(items: appState.institutions, type: "Institution", titleKeyPath: \.name, companyIdKeyPath: \.companyId)
        process(items: appState.loans, type: "Loan", titleKeyPath: \.name, companyIdKeyPath: \.companyId)
        process(items: appState.documents, type: "Document", titleKeyPath: \.name, companyIdKeyPath: \.companyId)
        
        return Array(groups.values).sorted { ($0.displayName ?? $0.id) < ($1.displayName ?? $1.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.zifrBG.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        if senderGroups.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "tray")
                                    .font(.system(size: 48))
                                    .foregroundStyle(Color.white.opacity(0.3))
                                Text("No shared items")
                                    .font(.headline)
                                    .foregroundStyle(Color.white.opacity(0.6))
                            }
                            .padding(.top, 100)
                        } else {
                            ForEach(senderGroups) { group in
                                MiloomFolderView(group: group)
                            }
                        }
                    }
                    .padding(20)
                }
                .refreshable {
                    await DataRepository.shared.fetchAllData(appState: appState)
                }
            }
            .navigationTitle("Shared Inbox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct MiloomFolderView: View {
    let group: SharedWithMeView.SenderGroup
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "#4f46e5").opacity(0.2))
                            .frame(width: 48, height: 48)
                        Image(systemName: "folder.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color(hex: "#4f46e5"))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.displayName ?? group.id)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                        if group.displayName != nil {
                            Text(group.id)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                    }
                    
                    Spacer()
                    
                    Text("\(group.items.count)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .padding(.trailing, 8)
                        
                    DisclosureStateChevron(isExpanded: isExpanded)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                .padding(16)
                .background(Color(hex: "#1C1C1E"))
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(spacing: 0) {
                    Divider().background(Color.white.opacity(0.1))
                    ForEach(group.items) { item in
                        HStack(spacing: 12) {
                            Image(systemName: iconFor(item.type))
                                .font(.system(size: 16))
                                .foregroundStyle(Color.white.opacity(0.5))
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text(item.type)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.white.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(item.role)
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(hex: "#4f46e5").opacity(0.3))
                                    .foregroundStyle(Color(hex: "#818cf8"))
                                    .clipShape(Capsule())
                                
                                Text(item.createdAt, style: .date)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.white.opacity(0.4))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        
                        if item.id != group.items.last?.id {
                            Divider().background(Color.white.opacity(0.05)).padding(.leading, 52)
                        }
                    }
                }
                .background(Color(hex: "#151516"))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    
    private func iconFor(_ type: String) -> String {
        switch type {
        case "Subscription": return "repeat.circle"
        case "Card": return "creditcard"
        case "Institution": return "building.columns"
        case "Loan": return "dollarsign.circle"
        case "Document": return "doc.text"
        default: return "doc"
        }
    }
}
