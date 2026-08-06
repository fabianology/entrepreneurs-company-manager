import SwiftUI
struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(OnboardingStateManager.self) private var onboardingState
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
    
    // Shared Item states
    @State private var selectedSubscription: Subscription?
    @State private var selectedCard: FinancialCard?
    @State private var selectedInstitution: Institution?
    @State private var selectedLoan: Loan?
    @State private var selectedDocument: CompanyDocument? = nil
    @State private var showAssistant = false    
    
    private var currentUserId: UUID? { authViewModel.currentUser?.id }
    
    // Shared companies
    private var sharedCompanies: [Company] {
        guard let currentUserId = currentUserId else { return [] }
        return appState.companies.filter { $0.userId != currentUserId }
    }

    @State private var dummyCompany = Company(
        userId: UUID(),
        name: "Acme Holdings LLC",
        structure: "LLC"
    )

    // Tutorial target frames (captured in 'dashboard' coordinate space)
    @State private var tutorialEntityFrame: CGRect = .zero
    @State private var tutorialSearchFrame: CGRect = .zero
    @State private var tutorialAssistantFrame: CGRect = .zero

    var body: some View {
        NavigationStack(path: $vm.path) {
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()
                
                AnimatedHeaderBackground()
                    .ignoresSafeArea(edges: .top)

                List {
                // Header Group
                VStack(spacing: 0) {
                    headerSection
                        .padding(.top, 8)
                        .padding(.bottom, 40)

                    if let firstCompany = appState.companies.first, SandboxSeeder.isSandbox(companyId: firstCompany.id) {
                        HStack(spacing: 12) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color(hex: "#5AC8FA"))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Demo Mode Active")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("Explore features or set up your real business.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                showAddCompany = true
                            } label: {
                                Text("Set Up")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(
                                        LinearGradient(
                                            colors: [Color(hex: "#5AC8FA"), Color(hex: "#0A84FF")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#1C1C1E"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#5AC8FA").opacity(0.3), lineWidth: 1))
                        .padding(.bottom, 20)
                    }

                    dashboardHeader
                        .premiumDarkBar(cornerRadius: 12)
                        .padding(.bottom, 16)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))

                ForEach(Array(filteredCompanies.enumerated()), id: \.element.id) { index, company in
                    let row = companyCardRow(for: company)
                    let withFrame = row.background(tutorialFrameCapture(index: index))
                    withFrame
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 16, trailing: 20))
                        .swipeActions(edge: .leading) {
                            Button { editingCompany = company } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(Color.indigo)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { companyToDelete = company } label: {
                                Image(systemName: "trash")
                            }
                            .tint(.red)
                        }
                }

                // Add company button / tutorial demo card
                Group {
                    if companies.isEmpty {
                        // Un-blurred only while the tutorial is actively running.
                        // tutorialHasBeenRun is a stored @Observable Bool — reliably triggers re-render.
                        if onboardingState.tutorialHasBeenRun && onboardingState.isTutorialActive {
                            // Tutorial in progress: show demo card fully visible
                            CompanyCardView(
                                company: dummyCompany,
                                institutionsCount: 1,
                                subscriptionsCount: 3,
                                docsCount: 2,
                                onEdit: {}
                            )
                            .allowsHitTesting(false)
                            .padding(.top, 4)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.onAppear {
                                        tutorialEntityFrame = geo.frame(in: .named("dashboard"))
                                    }.onChange(of: geo.frame(in: .named("dashboard"))) { _, f in
                                        tutorialEntityFrame = f
                                    }
                                }
                            )
                        } else {
                            // Empty state (pre-tutorial, or after tutorial): blurred card + CTA
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                showAddCompany = true
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
                                        Text("+ CREATE YOUR FIRST BUSINESS")
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
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: orphanedSharedItems.isEmpty ? 120 : 16, trailing: 20))

                if !orphanedSharedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "tray.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color(hex: "#A2A2A2"))
                            Text("Shared With Me")
                                .font(.system(size: 13, weight: .black))
                                .tracking(1.5)
                                .textCase(.uppercase)
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                        
                        VStack(spacing: 12) {
                            ForEach(orphanedSharedItems, id: \.id) { share in
                                SharedItemCardView(title: share.title, type: share.type.capitalized, role: share.role, senderEmail: share.senderEmail, createdAt: share.createdAt)
                                    .onTapGesture {
                                        openSharedItem(share)
                                    }
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 120, trailing: 20))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .scrollIndicators(.hidden)
            .onAppear {
                onboardingState.evaluateState(appState: appState)
            }
            .onChange(of: appState.companies.count) { _, _ in
                let previousStep = onboardingState.currentStep
                onboardingState.evaluateState(appState: appState)
                
                if (previousStep == .needsEntity || previousStep == .notStarted) && onboardingState.currentStep == .needsBank {
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
            .navigationDestination(for: Company.self) { company in
                CompanyDetailView(company: company, vm: vm)
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
            .sheet(isPresented: $showAddCompany) {
                EditCompanySheet(vm: vm, company: nil)
            }
            .sheet(item: $editingCompany) { company in
                EditCompanySheet(vm: vm, company: company)
            }
            .sheet(isPresented: $vm.showSearch) {
                GlobalSearchView(
                    vm: vm, companies: companies, subscriptions: subscriptions,
                    cards: cards, institutions: institutions, loans: loans, documents: documents
                )
            }
            .fullScreenCover(isPresented: $showAssistant) {
                AssistantOnboardingView(vm: vm)
                    .environment(appState)
            }
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
            .sheet(item: $selectedDocument) { doc in
                EditDocumentSheet(doc: doc, vm: vm, isNew: false, companyStructure: companies.first(where: { $0.id == doc.companyId })?.structure ?? "LLC")
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
                        // CompanyDetailView's own onChange will set vm.activeTab = .home
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
                        vm.activeTab = .home
                    }

                // ── Done ──
                case .tutorialDone:
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        vm.path = NavigationPath()
                        vm.activeTab = .home
                    }

                default:
                    break
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        vm.path.append(AppViewModel.AppRoute.adminSettings)
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                            .background(Color(hex: "#1C1C1E"))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        vm.showSearch = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("Search")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .background(Color(hex: "#1C1C1E"))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
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
                    
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showAssistant = true
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(hex: "#5AC8FA"), Color(hex: "#0A84FF")]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: Color(hex: "#0A84FF").opacity(0.6), radius: 8, x: 0, y: 0)
                    }
                    .buttonStyle(.plain)
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
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
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
                                showAddCompany = true
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
                            showAddCompany = true
                        },
                        onExplore: {
                            onboardingState.exitTutorial(appState: appState)
                        }
                    )
                    .transition(.opacity)
                }
            }
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

    @ViewBuilder
    private var dashboardHeader: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: "#A2A2A2"))
                Text("Dashboard")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "#A2A2A2"))
            }
            .padding(.leading, 16)
            .allowsHitTesting(false)

            Spacer()

            // Share Button
            shareMenu

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1, height: 20)

            // Add Button
            addButton
        }
    }

    @ViewBuilder
    private var shareMenu: some View {
        Menu {
            ForEach(companies) { company in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    companyToShare = company
                } label: {
                    if company.name.isEmpty {
                        Label("Share Business", systemImage: "person.crop.circle.badge.plus")
                    } else {
                        Label("Share \(company.name)", systemImage: "person.crop.circle.badge.plus")
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
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var addButton: some View {
        Button {
            showAddCompany = true
        } label: {
            HStack(spacing: 6) {
                Text("ADD BUSINESS")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white)
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            .frame(width: 164, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        VStack(spacing: 12) {
            if let uiImage = UIImage(named: "logo.png") {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 50)
                    .background(
                        Ellipse()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 180, height: 80)
                            .blur(radius: 24)
                    )
            }

            if !vm.quote.isEmpty {
                let parts = vm.quote.components(separatedBy: " - ")
                VStack(spacing: 2) {
                    Text("\"\(parts.first ?? vm.quote)\"")
                        .font(.system(size: 14, weight: .light))
                        .italic()
                        .foregroundStyle(Color.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                    if parts.count > 1 {
                        Text("— \(parts[1])")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                }
                .padding(.horizontal, 32)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeInOut(duration: 0.6), value: vm.quote)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 220, height: 14)
                    .shimmer()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .task {
            if vm.quote.isEmpty { await vm.loadQuote() }
        }
    }
    
    @ViewBuilder
    private func companyCardRow(for company: Company) -> some View {
        let iCount = institutions.filter { $0.companyId == company.id }.count
        let sCount = subscriptions.filter { $0.companyId == company.id }.count
        let dCount = documents.filter { $0.companyId == company.id }.count
        
        let isSharedWithMe = (company.userId != currentUserId)
        let isSharedByMe = (company.userId == currentUserId) && appState.resourceShares.contains(where: { $0.resourceId == company.id })
        let role = appState.resourceShares.first(where: { $0.resourceId == company.id })?.role ?? "Viewer"

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
            shareRole: role,
            isSharedWithMe: isSharedWithMe,
            isSharedByMe: isSharedByMe,
            onTapSubscriptions: { navigateAction(.subscriptions) },
            onTapInstitutions: { navigateAction(.financial) },
            onTapDocuments: { navigateAction(.documents) },
            onTapMain: { navigateAction(.home) }
        )
    }

    // MARK: - Onboarding helpers

    private func handlePostBankNavigation() {
        switch onboardingState.currentStep {
        case .needsReview:
            vm.activeTab = .subscriptions
        case .needsAssistant, .completed:
            vm.path = NavigationPath()
            vm.activeTab = .home
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



// MARK: - Shared With Me View
import SwiftUI
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
                Color.black.ignoresSafeArea()
                
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
                        
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
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
