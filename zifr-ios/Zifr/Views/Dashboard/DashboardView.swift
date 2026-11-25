import SwiftUI
struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(MiloomDuoLayoutState.self) private var duoLayout
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.layoutDirection) private var layoutDirection
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
    @State private var showBriefing = false
    @State private var showPortraitBriefing = false
    @State private var showNotificationInbox = false
    @State private var showPortraitInbox = false
    @State private var stackedDashboardTab: StackedDashboardTab = .entities
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showTransactionCenter = false
    @State private var taxReviewCompany: Company?
    @State private var initialTransactionID: UUID?
    @State private var initiallyShowsTransactionReview = false
    
    private var currentUserId: UUID? { authViewModel.currentUser?.id }
    private var isDuoDevice: Bool { duoLayout.isDuoDevice }
    private let duoControlSize: CGFloat = 48
    private let portraitBottomRowHeight: CGFloat = 52
    private let bottomControlInset: CGFloat = 12
    private let dashboardHeaderHeight: CGFloat = 52
    private let dashboardHeaderInsets = EdgeInsets(top: 3, leading: 0, bottom: 7, trailing: 0)
    @State private var adminCenterY: CGFloat?
    @State private var footerCenterY: CGFloat?
    
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
            portfolioPresentedPanels(dashboardWithToolbar)
        }
        .task {
            if !appState.hasLoadedCompanies {
                await DataRepository.shared.fetchAllData(appState: appState)
            }
        }
    }

    private enum StackedDashboardTab: CaseIterable {
        case entities, briefing, inbox

        var title: LocalizedStringKey {
            switch self {
            case .entities: "Entities"
            case .briefing: "Briefing"
            case .inbox: "Inbox"
            }
        }

        var icon: String {
            switch self {
            case .entities: "square.grid.2x2"
            case .briefing: "receipt"
            case .inbox: "bell"
            }
        }
    }

    @ViewBuilder
    private var dashboardWithToolbar: some View {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) {
            let showsPortraitToolbar = usesDuoPortraitDashboard && vm.path.isEmpty
            let showsStackedToolbar = duoLayout.usesStackedLayout && vm.path.isEmpty
            let showsCustomToolbar = showsPortraitToolbar || showsStackedToolbar
            let portraitControlsTopInset = duoLayout.portraitToolbarInsets.dashboard
            Group {
                if duoLayout.usesStackedLayout {
                    stackedDashboardTabs
                } else {
                    dashboardSurface
                }
            }
            .safeAreaInset(edge: .trailing, spacing: showsPortraitToolbar ? 8 : 0) {
                if showsPortraitToolbar {
                    portraitDashboardToolbar
                        .padding(.top, portraitControlsTopInset)
                }
            }
            .allowsHitTesting(!isPortraitDrawerOpen)
            .accessibilityHidden(isPortraitDrawerOpen)
            .toolbar(showsPortraitToolbar ? .hidden : .automatic, for: .navigationBar)
            .toolbar {
                if isDuoDevice && vm.path.isEmpty && !showsCustomToolbar {
                    if duoLayout.usesLeftSplitToolbar {
                        DuoLeftSplitToolbarClearance()
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        dashboardShareControl
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        dashboardAddControl
                    }
                    .visibilityPriority(.high)
                    if duoLayout.usesNativeSideToolbarGroups {
                        ToolbarSpacer(.fixed, placement: .topBarTrailing)
                            .axisBehavior(.verticalPreferred)
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                presentBriefing()
                            } label: {
                                Label("Executive Briefing", systemImage: "receipt")
                            }
                            Button(action: openDashboardInbox) {
                                Label("Notification inbox", systemImage: "bell")
                            }
                            .badge(appState.unreadNotificationCount)
                        }
                        .axisBehavior(.verticalPreferred)
                    }
                    ToolbarItem(placement: .bottomBar) {
                        if duoLayout.usesNativeSideToolbarGroups {
                            ZStack {
                                Button(action: openDashboardAdmin) {
                                    Label("Admin settings", systemImage: "person.crop.circle")
                                        .labelStyle(.iconOnly)
                                        .font(.system(size: 17, weight: .medium))
                                        .frame(width: duoControlSize, height: duoControlSize)
                                        .contentShape(Circle())
                                        .glassEffect(.regular.interactive(), in: Circle())
                                }
                                .buttonStyle(.plain)
                                .background {
                                    DuoWindowVerticalMeasurement { adminCenterY = $0 }
                                        .allowsHitTesting(false)
                                }
                            }
                        } else {
                            dashboardAdminControl
                        }
                    }
                    .axisBehavior(.verticalPreferred)
                    .sharedBackgroundVisibility(duoLayout.usesNativeSideToolbarGroups ? .hidden : .automatic)
                }
            }
            .overlay {
                if showsPortraitToolbar {
                    MiloomDuoBriefingFile(isPresented: $showPortraitBriefing, tabTopInset: portraitControlsTopInset,
                        additionalControls: AnyView(notificationInboxButton)) {
                        inlineBriefingPanel(isActive: vm.path.isEmpty)
                    }
                    .allowsHitTesting(!showPortraitInbox)
                    .accessibilityHidden(showPortraitInbox)
                }
            }
            .overlay { portraitInboxOverlay }
            .onChange(of: usesDuoPortraitDashboard) { _, portrait in
                if !portrait {
                    showPortraitBriefing = false
                    dismissPortraitInbox()
                }
            }
            .onChange(of: vm.path.isEmpty) { _, dashboard in
                if !dashboard {
                    showPortraitBriefing = false
                    dismissPortraitInbox()
                }
            }
        } else {
            dashboardSurface
        }
        #else
        dashboardSurface
        #endif
    }

    #if compiler(>=6.4)
    @available(iOS 27.1, *)
    private var stackedDashboardTabs: some View {
        TabView(selection: $stackedDashboardTab) {
            ForEach(StackedDashboardTab.allCases, id: \.self) { tab in
                Tab(tab.title, systemImage: tab.icon, value: tab) {
                    stackedDashboardPage(tab)
                        .modifier(StackedDashboardBars(
                            selection: $stackedDashboardTab,
                            isActive: vm.path.isEmpty,
                            showsActions: tab == .entities,
                            usesStackedPortrait: duoLayout.usesStackedPortraitLayout,
                            unreadCount: appState.unreadNotificationCount,
                            bottomRowHeight: portraitBottomRowHeight,
                            bottomControlInset: bottomControlInset,
                            share: dashboardShareControl,
                            add: dashboardAddControl,
                            admin: dashboardAdminControl
                        ))
                        .background(Color.zifrBG.ignoresSafeArea())
                }
                .badge(tab == .inbox ? appState.unreadNotificationCount : 0)
            }
        }
        .tabViewStyle(.tabBarOnly)
        .modifier(StackedDashboardNativeToolbar(
            isActive: vm.path.isEmpty,
            showsActions: stackedDashboardTab == .entities,
            usesStackedPortrait: duoLayout.usesStackedPortraitLayout,
            share: dashboardShareControl,
            add: dashboardAddControl,
            admin: dashboardAdminControl
        ))
    }

    @available(iOS 27.1, *)
    @ViewBuilder
    private func stackedDashboardPage(_ tab: StackedDashboardTab) -> some View {
        switch tab {
        case .entities:
            dashboardSurface
        case .briefing:
            inlineBriefingPanel(isActive: vm.path.isEmpty && stackedDashboardTab == .briefing)
        case .inbox:
            NotificationInboxView(vm: vm, presentation: .duoDrawer) { route in
                stackedDashboardTab = .entities
                notificationRouter.enqueue(route)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    @available(iOS 27.1, *)
    private struct StackedDashboardBars<Share: View, Add: View, Admin: View>: ViewModifier {
        @Environment(\.toolbarVerticalEdge) private var nativeBarEdge
        @Binding var selection: StackedDashboardTab
        let isActive: Bool
        let showsActions: Bool
        let usesStackedPortrait: Bool
        let unreadCount: Int
        let bottomRowHeight: CGFloat
        let bottomControlInset: CGFloat
        let share: Share
        let add: Add
        let admin: Admin

        func body(content: Content) -> some View {
            let showsLeadingTabs = isActive && !usesStackedPortrait
            let showsTrailingTabs = isActive && usesStackedPortrait && !showsActions
            let showsActionRail = isActive && showsActions && (usesStackedPortrait || nativeBarEdge == nil)
            let trailingSpacing: CGFloat = showsActionRail && !usesStackedPortrait ? 8 : 0
            content
                .toolbarVisibility(isActive ? .hidden : .automatic, for: .tabBar)
                .safeAreaInset(edge: .leading, spacing: showsLeadingTabs ? 8 : 0) {
                    if showsLeadingTabs {
                        tabRail
                            .frame(maxHeight: .infinity, alignment: nativeBarEdge == nil ? .top : .bottom)
                            .padding(.leading, 22)
                            .padding(.vertical, 12)
                    }
                }
                .safeAreaInset(edge: .trailing, spacing: trailingSpacing) {
                    if showsActionRail || showsTrailingTabs {
                        Group {
                            if showsActionRail {
                                VStack(spacing: 0) {
                                    actionGroup
                                    if usesStackedPortrait {
                                        Spacer(minLength: 12)
                                        admin.frame(height: bottomRowHeight)
                                    }
                                }
                            } else {
                                tabRail
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(width: 52)
                        .frame(maxHeight: .infinity, alignment: showsActionRail ? .top : .bottom)
                        .padding(.trailing, 22)
                        .padding(.top, 12)
                        .padding(.bottom, bottomControlInset)
                    }
                }
        }

        private var tabRail: some View {
            VStack(spacing: 8) {
                if !showsActions {
                    Button("Close", systemImage: "xmark", role: .close) {
                        selection = .entities
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .accessibilityLabel(selection == .inbox ? Text("Close Inbox") : Text("Close Briefing"))
                }
                DuoTabBar(
                    selection: $selection,
                    tabs: [.briefing, .inbox],
                    title: { Text($0.title) }, icon: { $0.icon },
                    badge: { $0 == .inbox ? unreadCount : 0 },
                    verticalInset: usesStackedPortrait || nativeBarEdge == nil ? 1 : 2
                )
                .buttonStyle(.plain)
            }
            .frame(width: 52)
        }

        private var actionGroup: some View {
            ViewThatFits(in: .vertical) {
                VStack(spacing: 0) {
                    share
                    add
                    if !usesStackedPortrait { admin }
                }
                VStack(spacing: 0) {
                    add
                    Menu {
                        share
                        if !usesStackedPortrait { admin }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 21.5, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                    }
                    .accessibilityLabel("More dashboard actions")
                }
            }
            .padding(1)
            .glassEffect(.regular.interactive(), in: Capsule())
        }
    }

    @available(iOS 27.1, *)
    private struct StackedDashboardNativeToolbar<Share: View, Add: View, Admin: View>: ViewModifier {
        @Environment(\.toolbarVerticalEdge) private var nativeBarEdge
        let isActive: Bool
        let showsActions: Bool
        let usesStackedPortrait: Bool
        let share: Share
        let add: Add
        let admin: Admin

        func body(content: Content) -> some View {
            let usesCustomBars = usesStackedPortrait || nativeBarEdge == nil
            content
                .toolbarVisibility(isActive && usesCustomBars ? .hidden : .automatic, for: .navigationBar)
                .toolbar {
                    if isActive && !usesCustomBars && showsActions {
                        ToolbarItem(placement: .topBarTrailing) { share }
                            .axisBehavior(.verticalPreferred)
                        ToolbarItem(placement: .topBarTrailing) { add }
                            .axisBehavior(.verticalPreferred)
                            .visibilityPriority(.high)
                        ToolbarItem(placement: .topBarTrailing) { admin }
                            .axisBehavior(.verticalPreferred)
                            .visibilityPriority(.low)
                    }
                }
        }

    }
    #endif

    private var usesDuoPortraitDashboard: Bool {
        duoLayout.usesExpandedPortrait
    }

    @available(iOS 26.0, *)
    private var portraitDashboardToolbar: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                dashboardShareControl
                dashboardAddControl
            }
            .padding(1)
            .glassEffect(.regular.interactive(), in: Capsule())
            Spacer(minLength: 24)
            dashboardAdminControl
                .frame(height: portraitBottomRowHeight)
        }
        .buttonStyle(.plain)
        .frame(width: 52)
        .padding(.trailing, 22)
        .padding(.bottom, bottomControlInset)
    }

    @ViewBuilder
    private func dashboardToolbarLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        if usesDuoPortraitDashboard || duoLayout.usesStackedLayout {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.system(size: 21.5, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: duoControlSize, height: duoControlSize)
                .contentShape(Rectangle())
        } else {
            Label(title, systemImage: systemImage)
        }
    }

    private var dashboardAddControl: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            requestAddCompany()
        } label: {
            dashboardToolbarLabel("Add entity", systemImage: "plus")
        }
    }

    private var dashboardAdminControl: some View {
        Button(action: openDashboardAdmin) {
            let label = dashboardToolbarLabel("Admin settings", systemImage: "person.crop.circle")
            if #available(iOS 26.0, *), usesDuoPortraitDashboard || duoLayout.usesStackedPortraitLayout {
                label.glassEffect(.regular.interactive(), in: Circle())
            } else {
                label
            }
        }
    }

    private var isPortraitDrawerOpen: Bool {
        usesDuoPortraitDashboard && vm.path.isEmpty && (showPortraitBriefing || showPortraitInbox)
    }

    private var portraitInboxAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.32)
    }

    @ViewBuilder
    private var portraitInboxOverlay: some View {
        if usesDuoPortraitDashboard && vm.path.isEmpty {
            GeometryReader { geometry in
                let frames = DuoBinderDrawerFrames.resolve(size: geometry.size, progress: 1, tabIndex: 0)
                ZStack(alignment: .topLeading) {
                    if showPortraitInbox {
                        Color.clear.contentShape(Rectangle())
                            .onTapGesture { dismissPortraitInbox() }
                            .accessibilityHidden(true)

                        MiloomDuoPortraitSheet(title: "Inbox", onClose: { dismissPortraitInbox() }, showsCard: false) {
                            NotificationInboxView(vm: vm, presentation: .duoDrawer) { route in
                                dismissPortraitInbox { notificationRouter.enqueue(route) }
                            }
                        }
                        .frame(width: frames.sheet.width, height: frames.sheet.height)
                        .transition(.move(edge: .leading))
                        .zIndex(1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
            }
            .allowsHitTesting(showPortraitInbox)
            .accessibilityHidden(!showPortraitInbox)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(showPortraitInbox ? .isModal : [])
        }
    }

    private func dismissPortraitInbox(then completion: (() -> Void)? = nil) {
        guard showPortraitInbox else {
            completion?()
            return
        }
        withAnimation(portraitInboxAnimation, completionCriteria: .logicallyComplete) {
            showPortraitInbox = false
        } completion: {
            completion?()
            openPendingNotificationRouteIfReady()
        }
    }

    private var usesDuoLandscapeDashboard: Bool {
        duoLayout.usesExpandedLandscape
    }

    private var dashboardSurface: some View {
            ZStack(alignment: .top) {
                if !duoLayout.usesStackedPortraitLayout {
                    Color.zifrBG.ignoresSafeArea()
                }

                VStack(spacing: 0) {
                    if !usesDuoLandscapeDashboard && !duoLayout.usesStackedPortraitLayout {
                        dashboardHeader
                    }
                    portfolioPanels
                }
                .safeAreaInset(edge: .bottom, spacing: duoLayout.usesStackedPortraitLayout ? 0 : nil) {
                    if !usesDuoLandscapeDashboard && !duoLayout.usesStackedPortraitLayout {
                        dashboardBottomControls
                    }
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



    @ViewBuilder
    private var dashboardBottomControls: some View {
        if usesDuoPortraitDashboard {
            GeometryReader { geometry in
                let frames = DuoPortraitFilingFrames.resolve(size: geometry.size)
                dashboardBottomControlsRow
                    .frame(width: max(0, frames.page.width - 40), height: portraitBottomRowHeight)
                    .offset(x: frames.page.minX + 20)
            }
            .frame(height: portraitBottomRowHeight)
            .padding(.bottom, bottomControlInset)
        } else {
            alignedDashboardBottomControlsRow
                .frame(height: duoLayout.usesStackedPortraitLayout ? portraitBottomRowHeight : nil)
                .padding(.horizontal, 20)
                .padding(.bottom, bottomControlInset)
        }
    }

    @ViewBuilder
    private var alignedDashboardBottomControlsRow: some View {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *), duoLayout.usesNativeSideToolbarGroups {
            dashboardBottomControlsRow
                .offset(y: nativeDashboardFooterOffset)
                .background {
                    DuoWindowVerticalMeasurement { footerCenterY = $0 }
                }
        } else {
            dashboardBottomControlsRow
        }
        #else
        dashboardBottomControlsRow
        #endif
    }

    private var nativeDashboardFooterOffset: CGFloat {
        guard let adminCenterY, let footerCenterY else { return 0 }
        let adjustment = adminCenterY - footerCenterY
        // The toolbar and footer report independently when folding or rotating.
        return abs(adjustment) <= 44 ? adjustment : 0
    }

    private var dashboardBottomControlsRow: some View {
        let assistantFirst = duoLayout.placesSplitControlsOnLeadingEdge(in: layoutDirection)
        return HStack(spacing: 10) {
            if !isDuoDevice { dashboardAdminButton }
            if assistantFirst {
                dashboardAssistantButton
            }
            dashboardSearchButton
            if !assistantFirst {
                dashboardAssistantButton
            }
            if !isDuoDevice {
                legacyPlusCommandMenu
            }
        }
    }

    private var dashboardHeader: some View {
        Group {
            if duoLayout.usesStackedLayout && !duoLayout.usesStackedPortraitLayout {
                Text("Entities")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            } else {
                headerSection
                    .padding(dashboardHeaderInsets)
            }
        }
    }

    private func openDashboardAdmin() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        vm.path.append(AppViewModel.AppRoute.adminSettings)
    }

    private var dashboardAdminButton: some View {
        Button(action: openDashboardAdmin) {
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
        MiloomDuoFooterButton(borderShape: .capsule) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            vm.showSearch = true
        } label: {
            Label("Search", systemImage: "magnifyingglass")
                .frame(maxWidth: .infinity, alignment: .leading)
        } legacyLabel: {
            dashboardSearchPill
        }
        .accessibilityLabel("Search")
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

    private var dashboardSearchPill: some View {
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

    private var dashboardAssistantButton: some View {
        MiloomDuoFooterButton(borderShape: .circle) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showAssistant = true
        } label: {
            Label("Open Gemini Live", systemImage: "sparkle")
                .labelStyle(.iconOnly)
        } legacyLabel: {
            dashboardGeminiIcon
                .frame(width: 52, height: 52)
                .contentShape(Rectangle())
        }
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

    private func portfolioLifecyclePanels<Content: View>(_ content: Content) -> some View {
        content
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
            .navigationBarBackButtonHidden(true)
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

    private func portfolioPresentedPanels<Content: View>(_ content: Content) -> some View {
        portfolioLifecyclePanels(content)
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
                    stackedDashboardTab = .entities
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
        if #available(iOS 27.1, *), duoLayout.usesStackedPortraitLayout {
            let headerHeight = dashboardHeaderHeight + dashboardHeaderInsets.top + dashboardHeaderInsets.bottom
            let footerHeight = portraitBottomRowHeight + bottomControlInset
            entityList(isDuoExpanded: true)
                .contentMargins(.top, headerHeight, for: .scrollContent)
                .contentMargins(.bottom, footerHeight, for: .scrollContent)
                .scrollEdgeEffectHidden(true, for: [.top, .bottom])
                .clipped()
                .mask {
                    VStack(spacing: 0) {
                        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                            .frame(height: headerHeight)
                        Color.black
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: footerHeight)
                    }
                }
                .overlay(alignment: .top) {
                    dashboardHeader
                }
                .overlay(alignment: .bottom) {
                    dashboardBottomControls
                }
        } else if duoLayout.usesStackedLayout {
            entityList(compactCards: true)
        } else if #available(iOS 27.1, *), usesDuoPortraitDashboard {
            GeometryReader { geometry in
                let frames = DuoPortraitFilingFrames.resolve(size: geometry.size)
                entityList(isDuoExpanded: true)
                    .frame(width: frames.page.width, height: frames.page.height)
                    .offset(x: frames.page.minX)
            }
        } else if #available(iOS 27.1, *) {
            DuoDashboardPanels(
                expanded: usesDuoLandscapeDashboard,
                bottomControlCenterY: nil,
                cards: { expanded in entityList(isDuoExpanded: expanded) },
                receipt: { inlineBriefingPanel(isActive: vm.path.isEmpty) },
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
    private func inlineBriefingPanel(isActive: Bool) -> some View {
        if accessController.permits(.ownerBriefing, appState: appState, userId: currentUserId) {
            DuoInlineBriefingView(
                vm: vm, store: duoBriefing, isActive: isActive,
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

    private func entityList(isDuoExpanded: Bool = false, compactCards: Bool = false) -> some View {
                    List {
                        if companies.isEmpty && !appState.hasLoadedCompanies && appState.portfolioLoadIssue == nil && !onboardingState.isTutorialActive {
                            ProgressView("Loading your companies…")
                                .tint(Color.zifrGold)
                                .font(.system(size: 14, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 48)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }

                        if let loadIssue = appState.portfolioLoadIssue {
                            Button {
                                Task { await DataRepository.shared.fetchAllData(appState: appState, force: true) }
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
                            let row = companyCardRow(for: company, compact: compactCards)
                            let isLast = index == filteredCompanies.count - 1
                            let hasPlaceholder = companies.isEmpty || (onboardingState.tutorialHasBeenRun && onboardingState.isTutorialActive)
                            let rowSpacing: CGFloat = compactCards ? 10 : 16
                            row
                                .background(tutorialFrameCapture(index: index))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: (isLast && !hasPlaceholder && !isDuoExpanded && !compactCards) ? 120 : rowSpacing, trailing: 20))
                        }

                        // Add company button / empty state placeholder under the dummy company
                        Group {
                            if (companies.isEmpty && appState.hasLoadedCompanies) || (onboardingState.tutorialHasBeenRun && onboardingState.isTutorialActive) {
                                // Un-blurred only while the tutorial is actively running.
                                if onboardingState.tutorialHasBeenRun && onboardingState.isTutorialActive {
                                    // Tutorial in progress: show demo card fully visible
                                    CompanyCardView(
                                        company: dummyCompany,
                                        institutionsCount: 2,
                                        subscriptionsCount: 4,
                                        docsCount: 3,
                                        onEdit: {},
                                        usesCompactLayout: compactCards
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
                                                onEdit: {},
                                                usesCompactLayout: compactCards
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
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: compactCards ? 10 : (isDuoExpanded ? 16 : 120), trailing: 20))
                    }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .scrollIndicators(.hidden)
            .refreshable {
                await DataRepository.shared.fetchAllData(appState: appState, force: true)
            }
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
            dashboardToolbarLabel("Share access", systemImage: "square.and.arrow.up")
        }
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
        if duoLayout.usesStackedLayout && vm.path.isEmpty { stackedDashboardTab = .briefing }
        else if usesDuoPortraitDashboard { showPortraitBriefing = true }
        else { showBriefing = true }
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
              !showNotificationInbox, !showPortraitInbox,
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
        case .subscriptionInServices(let id):
            openSubscriptionInServices(id)
        case .resource(let kind, let resourceID):
            openHealthResource(kind, resourceID)
        }
    }

    private func openSubscriptionInServices(_ id: UUID) {
        guard let subscription = appState.subscriptions.first(where: { $0.id == id }) else {
            appState.error = "This subscription is no longer available."
            return
        }
        guard let company = appState.companies.first(where: { $0.id == subscription.companyId }) else {
            // A subscription shared on its own may have no visible company page.
            selectedSubscription = subscription
            return
        }

        vm.selectedCompany = company
        vm.searchQuery = ""
        vm.activeTab = .subscriptions
        vm.deepLinkModelId = id
        vm.path = NavigationPath([company])
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

    private func openDashboardInbox() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if usesDuoPortraitDashboard && vm.path.isEmpty {
            withAnimation(portraitInboxAnimation) {
                showPortraitInbox = true
            }
        } else {
            showNotificationInbox = true
        }
    }

    private var notificationInboxButton: some View {
                Button(action: openDashboardInbox) {
                    ZStack(alignment: .topTrailing) {
                        dashboardHeaderShortcut(appState.unreadNotificationCount > 0 ? "bell.fill" : "bell")

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

    private func dashboardHeaderShortcut(_ symbol: String) -> some View {
        let size: CGFloat = usesDuoPortraitDashboard ? duoControlSize : 40
        return Image(systemName: symbol)
            .font(.system(size: usesDuoPortraitDashboard ? 21.5 : 17,
                          weight: usesDuoPortraitDashboard ? .medium : .semibold))
            .foregroundStyle(Color.white.opacity(usesDuoPortraitDashboard ? 1 : 0.82))
            .frame(width: size, height: size)
            .background(Color.black.opacity(usesDuoPortraitDashboard ? 0 : 0.32), in: Circle())
            .contentShape(Rectangle())
    }

    private var dashboardBriefingButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            presentBriefing(source: "dashboard_header_receipt")
        } label: {
            dashboardHeaderShortcut("receipt")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Executive briefing receipt")
        .accessibilityHint("Opens the personal or business monthly briefing")
    }

    private var headerSection: some View {
        ZStack {
            GeometryReader { geometry in
                let cardFrames = DuoPortraitFilingFrames.resolve(size: geometry.size)
                Image("miloom_text_embossed")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width * 0.35)
                    .position(x: usesDuoPortraitDashboard ? cardFrames.page.midX : geometry.size.width / 2,
                              y: geometry.size.height / 2)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
            .allowsHitTesting(!duoLayout.usesStackedPortraitLayout)

            HStack(spacing: 8) {
                Spacer()
                if duoLayout.usesStackedPortraitLayout {
                    #if compiler(>=6.4)
                    if #available(iOS 27.1, *), vm.path.isEmpty {
                        DuoTabBar(
                            selection: $stackedDashboardTab,
                            tabs: [.briefing, .inbox],
                            title: { Text($0.title) },
                            icon: { $0.icon },
                            badge: { $0 == .inbox ? appState.unreadNotificationCount : 0 },
                            verticalInset: 1,
                            axis: .horizontal
                        )
                        .buttonStyle(.plain)
                    }
                    #endif
                } else if !usesDuoPortraitDashboard && !duoLayout.usesNativeSideToolbarGroups {
                    dashboardBriefingButton
                    notificationInboxButton
                }
            }
            .padding(.trailing, 20)
        }
        .frame(height: dashboardHeaderHeight)
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
            institutionsCount: appState.hasLoadedCompanyContent ? iCount : nil,
            subscriptionsCount: appState.hasLoadedCompanyContent ? sCount : nil,
            docsCount: appState.hasLoadedCompanyContent ? dCount : nil,
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



/// Shared vector glyph for legacy Gemini controls.
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
private struct DuoLeftSplitToolbarClearance: ToolbarContent {
    var body: some ToolbarContent {
        // The native right pane starts below the status area. Reserve the same space on the left.
        ToolbarItem(placement: .topBarTrailing) {
            Color.clear
                .frame(width: 1, height: 78)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .axisBehavior(.verticalPreferred)
        .sharedBackgroundVisibility(.hidden)
        .visibilityPriority(.low)
    }
}

@available(iOS 27.1, *)
struct DuoSideToolbar<Admin: View, PrimaryAction: View, Add: View, Entities: View>: ViewModifier {
    @Environment(MiloomDuoLayoutState.self) private var layout
    @Environment(\.layoutDirection) private var layoutDirection
    @Binding var usesSideToolbar: Bool
    @Binding var bottomControlCenterY: CGFloat?
    @Binding var bottomControlWindowCenterY: CGFloat?
    @Binding var reportsDuoDevice: Bool
    let isActive: Bool
    let admin: Admin
    let primaryAction: PrimaryAction
    let add: Add
    let entities: Entities
    var showsPrimaryActions = true
    var portraitActionsTopInset: CGFloat = 16
    var reservesCompactContentWidth = false
    var usesSystemItems = false
    var showsStandalonePortraitEntitySwitcher = false
    var stackedEntityTabSelection: Binding<EntityHomeTab>? = nil
    var onStackedVaultCenterChange: ((CGFloat?) -> Void)?
    var nativeReportMenu: AnyView? = nil

    @State private var compactStatusAreaBottom: CGFloat?

    private let toolbarWidth: CGFloat = 52
    private let toolbarTrailingPadding: CGFloat = 22
    private let compactStatusAreaGap: CGFloat = 12

    private var hasNativeSideToolbar: Bool {
        if usesSystemItems {
            return layout.isDuoDevice && !layout.usesExpandedPortrait && !layout.usesStackedLayout
        }
        return layout.usesExpandedLandscape
    }
    private var hasCustomSideToolbar: Bool { layout.isDuoDevice && !hasNativeSideToolbar }
    private var railOnLeadingEdge: Bool { layout.placesSplitControlsOnLeadingEdge(in: layoutDirection) }
    private var railPaddingEdge: Edge.Set { railOnLeadingEdge ? .leading : .trailing }

    func body(content: Content) -> some View {
        let usesClosedRail = hasCustomSideToolbar && layout.usesCompactLayout && isActive
        let usesFixedWidthRail = usesClosedRail && (reservesCompactContentWidth || layout.usesStackedLayout)
        // Entity pages route drags from this empty strip to the selected tab.
        let reservesGestureMargin = usesClosedRail && layout.usesStackedLayout && reservesCompactContentWidth
        let closedRailEdges: Edge.Set = usesFixedWidthRail && layout.isExpanded ? .horizontal : railPaddingEdge
        content
            // Take the rail out of the content's width before the financial deck is measured.
            .padding(.leading, reservesGestureMargin ? 28 : 0)
            .padding(railPaddingEdge, usesFixedWidthRail ? toolbarWidth + toolbarTrailingPadding : 0)
            .background {
                if usesFixedWidthRail { Color.zifrBG.ignoresSafeArea() }
            }
            .overlay(alignment: railOnLeadingEdge ? .leading : .trailing) {
                if usesFixedWidthRail {
                    sideToolbar(isClosed: true)
                }
            }
            .safeAreaInset(edge: railOnLeadingEdge ? .leading : .trailing,
                           spacing: usesFixedWidthRail || layout.usesStackedLayout ? 0 : (usesClosedRail ? 22 : 8)) {
                if hasCustomSideToolbar && isActive && !usesFixedWidthRail {
                    sideToolbar(isClosed: usesClosedRail)
                }
            }
            // The fixed-width rail already reserves space for its controls.
            .ignoresSafeArea(.container, edges: usesClosedRail ? closedRailEdges : (layout.usesStackedLayout ? .horizontal : []))
            .background {
                if usesClosedRail && showsPrimaryActions {
                    Color.clear
                        .onGeometryChange(for: CGFloat?.self) { geometry in
                            let width = geometry.size.width
                            let top = geometry.frame(in: .global).minY
                            // The status area is a top occlusion on either side of the window.
                            return geometry.reservedRegions(kind: .occlusion)
                                .map(\.frame)
                                .filter {
                                    $0.minY <= 1 && $0.maxY > 0 && $0.width < width / 2
                                        && ($0.minX <= 1 || $0.maxX >= width - 1)
                                }
                                .map { top + $0.maxY }
                                .max()
                        } action: { compactStatusAreaBottom = $0 }
                        .ignoresSafeArea(.container, edges: [.top, .leading, .trailing])
                }
            }
            .toolbar(hasCustomSideToolbar && isActive ? .hidden : .automatic, for: .navigationBar)
            .toolbar {
                if hasNativeSideToolbar && isActive {
                    if usesSystemItems {
                        if layout.usesLeftSplitToolbar {
                            DuoLeftSplitToolbarClearance()
                        }
                        ToolbarItem(placement: .topBarTrailing) { primaryAction }
                            .axisBehavior(.verticalPreferred)
                        ToolbarItem(placement: .topBarTrailing) { add }
                            .axisBehavior(.verticalPreferred)
                            .visibilityPriority(.high)
                        if layout.usesNativeSideToolbarGroups, let nativeReportMenu {
                            ToolbarSpacer(.fixed, placement: .topBarTrailing)
                                .axisBehavior(.verticalPreferred)
                            ToolbarItem(placement: .topBarTrailing) { nativeReportMenu }
                                .axisBehavior(.verticalPreferred)
                            ToolbarSpacer(.fixed, placement: .topBarTrailing)
                                .axisBehavior(.verticalPreferred)
                            ToolbarItem(placement: .topBarTrailing) { entities }
                                .axisBehavior(.verticalPreferred)
                                .visibilityPriority(.high)
                        } else {
                            ToolbarItemGroup(placement: .topBarTrailing) {
                                entities
                                admin
                            }
                            .axisBehavior(.verticalPreferred)
                            .visibilityPriority(.low)
                        }
                    } else {
                        if showsPrimaryActions {
                            ToolbarItem(placement: .topBarLeading) {
                                VStack(spacing: 16) {
                                    primaryAction.frame(width: 52, height: 52)
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
            }
            .onChange(of: layout.isDuoDevice, initial: true) { _, next in
                if reportsDuoDevice != next { reportsDuoDevice = next }
            }
            .onChange(of: hasCustomSideToolbar || hasNativeSideToolbar, initial: true) { _, next in
                if usesSideToolbar != next { usesSideToolbar = next }
            }
    }

    @ViewBuilder
    private func sideToolbar(isClosed: Bool) -> some View {
        if isClosed && showsPrimaryActions {
            GeometryReader { geometry in
                let toolbarTop = geometry.frame(in: .global).minY
                let clearance = max(0, (compactStatusAreaBottom ?? toolbarTop) - toolbarTop)
                toolbarContents(topInset: clearance + compactStatusAreaGap, isClosed: true)
            }
            .frame(width: toolbarWidth + toolbarTrailingPadding)
        } else {
            toolbarContents(topInset: portraitActionsTopInset, isClosed: isClosed)
        }
    }

    private func toolbarContents(topInset: CGFloat, isClosed: Bool) -> some View {
        VStack(spacing: stackedEntityTabSelection == nil ? 16 : 4) {
            if usesSystemItems {
                if layout.usesExpandedPortrait && showsStandalonePortraitEntitySwitcher {
                    primaryActionGroup
                    entities
                        .padding(1)
                        .glassEffect(.regular.interactive(), in: Circle())
                    Spacer(minLength: 0)
                } else if let stackedEntityTabSelection {
                    if layout.usesStackedPortraitLayout {
                        primaryActionGroup
                        if let nativeReportMenu {
                            nativeReportMenu
                                .padding(1)
                                .glassEffect(.regular.interactive(), in: Circle())
                        }
                        entities
                            .padding(1)
                            .glassEffect(.regular.interactive(), in: Circle())
                    } else {
                        ViewThatFits(in: .vertical) {
                            entityActionGroup
                            stackedEntityActionGroup(includesShare: true)
                            stackedEntityActionGroup(includesShare: false)
                        }
                    }
                    Spacer(minLength: 12)
                    DuoTabBar(
                        selection: stackedEntityTabSelection, tabs: EntityHomeTab.allCases,
                        title: { Text($0.rawValue) }, icon: { $0.icon },
                        horizontalInset: 3,
                        onBottomTabCenterChange: onStackedVaultCenterChange
                    )
                    .layoutPriority(1)
                } else {
                    primaryActionGroup
                    Spacer(minLength: 24)
                    VStack(spacing: 0) {
                        entities
                        measuredAdmin
                    }
                    .padding(1)
                    .glassEffect(.regular.interactive(), in: Capsule())
                }
            } else {
                if showsPrimaryActions {
                    primaryAction.padding(.bottom, 4)
                    add
                }
                Spacer(minLength: 24)
                entities
                measuredAdmin
            }
        }
        .buttonStyle(.plain)
        .frame(width: toolbarWidth)
        .padding(.top, showsPrimaryActions ? topInset : 12)
        .padding(.bottom, isClosed ? 0 : 12)
        .padding(railPaddingEdge, toolbarTrailingPadding)
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(isClosed ? "duo.closedToolbar" : "duo.portraitToolbar")
    }

    private var primaryActionGroup: some View {
        VStack(spacing: 0) {
            primaryAction
            add
        }
        .padding(1)
        .glassEffect(.regular.interactive(), in: Capsule())
    }

    private var entityActionGroup: some View {
        VStack(spacing: 0) {
            primaryAction
            add
            entities
            measuredAdmin
        }
        .padding(1)
        .glassEffect(.regular.interactive(), in: Capsule())
    }

    private func stackedEntityActionGroup(includesShare: Bool) -> some View {
        VStack(spacing: 0) {
            if includesShare { primaryAction }
            add
            Menu {
                if !includesShare { primaryAction }
                entities
                admin
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 21.5, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("More entity actions")
        }
        .padding(1)
        .glassEffect(.regular.interactive(), in: Capsule())
    }

    private var measuredAdmin: some View {
        admin
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.frame(in: .global).midY
            } action: { bottomControlCenterY = $0 }
            .background {
                DuoWindowVerticalMeasurement { bottomControlWindowCenterY = $0 }
            }
    }
}

@available(iOS 27.1, *)
struct DuoTabBar<Tab: Hashable>: View {
    @Binding var selection: Tab
    let tabs: [Tab]
    let title: (Tab) -> Text
    let icon: (Tab) -> String
    var badge: (Tab) -> Int = { _ in 0 }
    var horizontalInset: CGFloat = 2
    var verticalInset: CGFloat = 2
    var axis: Axis = .vertical
    var glass: Glass = .regular
    var selectionFill = Color(hex: "#00613F")
    var revealsTitlesOnHold = false
    var onBottomTabCenterChange: ((CGFloat?) -> Void)?

    @State private var heldTab: Tab?

    var body: some View {
        let layout = axis == .horizontal ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
        layout {
            ForEach(tabs, id: \.self) { tab in
                let count = badge(tab)
                let button = Button {
                    selection = tab
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: icon(tab))
                            .symbolVariant(.fill)
                            .font(.system(size: 24, weight: .medium))
                        if heldTab != nil {
                            title(tab)
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .accessibilityHidden(true)
                        }
                    }
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 48)
                        .background {
                            if selection == tab {
                                Capsule().fill(selectionFill)
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            if count > 0 {
                                Text(count > 99 ? "99+" : "\(count)")
                                    .font(.system(size: 9, weight: .semibold))
                                    .padding(.horizontal, 3)
                                    .frame(minWidth: 15, minHeight: 15)
                                    .background(.red, in: Capsule())
                                    .accessibilityHidden(true)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(title(tab))
                .accessibilityValue(count > 0 ? Text("\(count) unread") : Text(""))
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
                .background {
                    if tab == tabs.last, let onBottomTabCenterChange {
                        DuoWindowVerticalMeasurement(onChange: onBottomTabCenterChange)
                    }
                }

                if revealsTitlesOnHold {
                    button.buttonStyle(TabHoldStyle { isHeld in
                        if isHeld {
                            heldTab = tab
                        } else if heldTab == tab {
                            heldTab = nil
                        }
                    })
                } else {
                    button
                }
            }
        }
        .padding(.horizontal, horizontalInset)
        .padding(.vertical, verticalInset)
        .glassEffect(glass.interactive(), in: Capsule())
    }

    private struct TabHoldStyle: ButtonStyle {
        let onHoldChange: (Bool) -> Void

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .onChange(of: configuration.isPressed) { _, isPressed in
                    if !isPressed { onHoldChange(false) }
                }
                .task(id: configuration.isPressed) {
                    guard configuration.isPressed else { return }
                    do {
                        try await Task.sleep(for: .milliseconds(350))
                    } catch {
                        return
                    }
                    guard !Task.isCancelled else { return }
                    onHoldChange(true)
                }
        }
    }
}

/// Native controls and SwiftUI content can have different global coordinate roots.
/// Measure within their common window after UIKit lays out its controls.
@available(iOS 27.1, *)
struct DuoWindowVerticalMeasurement: UIViewRepresentable {
    var measure: (UIView, UIWindow) -> CGFloat? = { view, window in
        view.convert(view.bounds, to: window).midY
    }
    let onChange: (CGFloat?) -> Void

    func makeUIView(context: Context) -> MeasurementView {
        let view = MeasurementView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: MeasurementView, context: Context) {
        view.measure = measure
        view.onChange = onChange
        view.scheduleReport()
    }

    final class MeasurementView: UIView {
        var measure: ((UIView, UIWindow) -> CGFloat?)?
        var onChange: (CGFloat?) -> Void = { _ in }
        private var previousValue: CGFloat?
        private var reportQueued = false

        override func didMoveToWindow() {
            super.didMoveToWindow()
            scheduleReport()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            scheduleReport()
        }

        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            scheduleReport()
        }

        func scheduleReport() {
            guard !reportQueued else { return }
            reportQueued = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                reportQueued = false
                let value = window.flatMap { self.measure?(self, $0) }
                guard previousValue != value else { return }
                previousValue = value
                onChange(value)
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
