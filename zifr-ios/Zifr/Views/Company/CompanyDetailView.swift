import SwiftUI

private enum DuoEntityReport: Hashable {
    case financial, subscriptions
}

private enum DuoEntitySection: String, CaseIterable, Hashable {
    case cashFlow = "Cash Flow", transactions = "Transactions", reports = "Reports"
}

private enum DuoPortraitSheet: Identifiable {
    case transactions
    case reports(DuoEntityReport)
    static let files: [Self] = [.reports(.financial), .reports(.subscriptions), .transactions]
    var title: String {
        switch self {
        case .transactions: return "Transactions"
        case .reports(.financial): return "Financial Report"
        case .reports(.subscriptions): return "Subscriptions Report"
        }
    }
    var icon: String {
        switch self {
        case .transactions: return "list.bullet.rectangle.portrait"
        case .reports(.financial): return EntityHomeTab.financial.icon
        case .reports(.subscriptions): return EntityHomeTab.subscriptions.icon
        }
    }
    var id: String {
        switch self {
        case .transactions: return "transactions"
        case .reports(let report): return report == .financial ? "financial-report" : "subscriptions-report"
        }
    }
}

/// The portrait page retains a landscape pane's measured point width. The
/// remaining left margin holds filing tabs; no lower pane is reserved.
struct DuoPortraitFilingFrames: Equatable {
    let page: CGRect
    let tabs: CGRect

    static func resolve(size: CGSize, landscapePageWidth: CGFloat? = nil) -> Self {
        let width = max(0, size.width), height = max(0, size.height)
        let rail = min(width, 124)
        let reference = landscapePageWidth ?? max(width, height) / 2 - 6
        let pageWidth = min(max(0, width - rail), max(0, reference * 1.2))
        let pageX = min(width - pageWidth, (width - pageWidth) / 2 + 44)
        let tabWidth = min(56, max(0, pageX))
        return Self(page: CGRect(x: pageX, y: 0, width: pageWidth, height: height),
                    tabs: CGRect(x: 0, y: min(16, height),
                                 width: tabWidth,
                                 height: max(0, height - 32)))
    }
}

/// Pure placement math, shared by the layout and its isolation/bounds tests.
struct DuoEntityPanelFrames: Equatable {
    let page: CGRect
    let panel: CGRect
    let divider: CGRect
    let sections: CGRect

    static func resolve(size: CGSize, expanded: Bool, portrait: Bool,
                        foldY: CGFloat? = nil, division: CGRect? = nil,
                        landscapePageWidth: CGFloat? = nil) -> Self {
        let width = max(0, size.width), height = max(0, size.height)
        if expanded && portrait {
            let files = DuoPortraitFilingFrames.resolve(size: size, landscapePageWidth: landscapePageWidth)
            return Self(page: files.page, panel: .zero, divider: .zero, sections: files.tabs)
        }
        guard expanded else {
            return Self(page: CGRect(x: 0, y: 0, width: width, height: height),
                        panel: .zero, divider: .zero, sections: .zero)
        }
        let frames = DuoDashboardPanelFrames.resolve(size: size, expanded: true, division: division)
        return Self(page: frames.cards, panel: frames.receipt, divider: .zero, sections: .zero)
    }
}

/// The existing entity menu, shared by entity pages and the Duo Admin toolbar.
struct MiloomEntitySwitcher: View {
    @Bindable var vm: AppViewModel
    @Environment(AppState.self) private var appState
    let selectedCompanyID: UUID?
    let onShowAllEntities: () -> Void

    var body: some View {
        Menu {
            if !appState.companies.isEmpty {
                Section("Jump to Entity") {
                    ForEach(appState.companies.sorted { $0.name < $1.name }) { company in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            vm.selectedCompany = company
                            vm.touchCompany(company, appState: appState)
                            vm.path = NavigationPath([company])
                        } label: {
                            if company.id == selectedCompanyID {
                                Label(company.name, systemImage: "checkmark")
                            } else {
                                Text(company.name)
                            }
                        }
                    }
                }
            }
            Button {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                onShowAllEntities()
            } label: {
                Label("All Entities", systemImage: "square.grid.2x2")
            }
        } label: {
            MiloomCircularToolbarLabel {
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Switch entity")
    }
}

struct MiloomCircularToolbarLabel<Icon: View>: View {
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        ZStack {
            controlGlass
                .overlay {
                    Circle().stroke(
                        LinearGradient(
                            colors: [Color(hex: "#918457"), Color(hex: "#918457").opacity(0.3)],
                            startPoint: .top, endPoint: .bottom
                        ), lineWidth: 1.5
                    )
                }
                .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)
            icon()
        }
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var controlGlass: some View {
        if #available(iOS 26.0, *) {
            Color.clear.glassEffect(
                .clear.tint(Color.zifrTabBarFill.opacity(0.28)).interactive(), in: Circle()
            )
        } else {
            Circle().fill(.ultraThinMaterial)
                .overlay(Circle().fill(Color.zifrTabBarFill.opacity(0.35)))
        }
    }
}

#if compiler(>=6.4)
@available(iOS 27.1, *)
private struct DuoEntityPanels<Page: View, Panel: View>: View {
    let isSplit: Bool
    let isPortrait: Bool
    @Environment(MiloomDuoLayoutState.self) private var layout
    @ViewBuilder let page: () -> Page
    @ViewBuilder let panel: () -> Panel
    @State private var hasShownPanel = false

    var body: some View {
        GeometryReader { geometry in
            let region = geometry.reservedRegions(kind: .division).first {
                $0.frame.height > $0.frame.width
            }
            let division = region.map {
                CGRect(x: $0.frame.minX - $0.margins.leading,
                       y: $0.frame.minY - $0.margins.top,
                       width: $0.frame.width + $0.margins.leading + $0.margins.trailing,
                       height: $0.frame.height + $0.margins.top + $0.margins.bottom)
            }
            let measuredWidth = isSplit && geometry.size.width >= geometry.size.height
                ? DuoDashboardPanelFrames.resolve(size: geometry.size, expanded: true, division: division).cards.width : nil
            DuoEntityPanelLayout(isSplit: isSplit, isPortrait: isPortrait, division: division,
                                 landscapePageWidth: layout.portraitEntityWidth) {
                page().contentShape(Rectangle())
                    .mask { Rectangle().padding(-64) }
                ZStack {
                    // Mount only when landscape first needs it, then retain its
                    // analysis and filters through subsequent folding/rotation.
                    if hasShownPanel || isSplit { panel() }
                }
                .clipped()
                .contentShape(Rectangle())
                .zIndex(1)
                .opacity(isSplit ? 1 : 0)
                .allowsHitTesting(isSplit)
                .accessibilityHidden(!isSplit)
                .accessibilityIdentifier("duo.entityPanel")
            }
            .onChange(of: measuredWidth, initial: true) { _, width in
                if let width, width > 0, layout.landscapeEntityWidth != width {
                    layout.landscapeEntityWidth = width
                }
            }
        }
        .background(Color.zifrBG.ignoresSafeArea())
        .onChange(of: isSplit, initial: true) { _, visible in
            if visible { hasShownPanel = true }
        }
    }
}

@available(iOS 27.1, *)
private struct DuoEntityPanelLayout: Layout {
    let isSplit: Bool
    let isPortrait: Bool
    let division: CGRect?
    let landscapePageWidth: CGFloat?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let frames = DuoEntityPanelFrames.resolve(size: bounds.size, expanded: isSplit || isPortrait,
            portrait: isPortrait, division: division, landscapePageWidth: landscapePageWidth)
        for (index, frame) in [frames.page, frames.panel].enumerated() {
            subviews[index].place(at: frame.offsetBy(dx: bounds.minX, dy: bounds.minY).origin, anchor: .topLeading,
                                  proposal: ProposedViewSize(frame.size))
        }
    }
}
#endif

struct CompanyDetailView: View {
    @State var company: Company
    @Bindable var vm: AppViewModel
    let onShowAllEntities: () -> Void
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(OnboardingStateManager.self) private var onboardingState
    @Environment(MiloomDuoLayoutState.self) private var duoLayout

    private var allCompanies: [Company] { appState.companies.sorted { $0.name < $1.name } }
    private var allSubscriptions: [Subscription] { appState.subscriptions }
    private var allCards: [FinancialCard] { appState.cards }
    private var allInstitutions: [Institution] { appState.institutions }
    private var allLoans: [Loan] { appState.loans }
    private var allDocuments: [CompanyDocument] { appState.documents }

    private var companyShare: ResourceShare? {
        guard let currentUserId = appState.portfolioUserID else { return nil }
        return appState.resourceShares.first {
            $0.resourceType == "company" && $0.resourceId == company.id && $0.userId == currentUserId
        }
    }

    private var canEditCompany: Bool {
        guard let currentUserId = appState.portfolioUserID else { return false }
        if company.userId == currentUserId { return true }
        guard let role = companyShare?.role else { return false }
        return ["Editor", "Admin"].contains(role)
    }

    private var canManageSharing: Bool {
        AppViewModel.resourceAllowsSharing(
            appState.resourceShares, actorID: appState.portfolioUserID,
            ownerID: company.userId, companyID: company.id
        )
    }

    private func canCreate(_ type: String) -> Bool {
        AppViewModel.resourceAllowsCreation(
            appState.resourceShares, actorID: appState.portfolioUserID,
            ownerID: company.userId, companyID: company.id, resourceType: type
        )
    }

    private var canAddInActiveTab: Bool {
        switch vm.activeTab {
        case .financial: return ["institution", "card", "loan"].contains { canCreate($0) }
        case .subscriptions: return canCreate("subscription")
        case .documents: return canCreate("document")
        }
    }

    /// Company collaboration grants access to business records, never to the
    /// owner's vault. Secret access remains owner-only until a separate,
    /// resource-specific secret grant exists.
    private var canAccessCompanyCredentials: Bool {
        guard let currentUserId = appState.portfolioUserID else { return false }
        return company.userId == currentUserId
    }

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
    @State private var sharingScope: EntitySharingScope?
    @State private var swipeHandled = false
    @State private var tabBounces: [EntityHomeTab: Int] = [:]
    @State private var searchBounce: Int = 0

    @State private var newSub: Subscription? = nil
    @State private var newCard: FinancialCard? = nil
    @State private var newDoc: CompanyDocument? = nil
    @State private var newLoan: Loan? = nil
    @State private var newManualInstitution: Institution?
    @State private var wizardInstitution: Institution? = nil
    @State private var showAssistant = false
    @State private var isDuoDevice = false
    @State private var usesDuoSideToolbar = false
    @State private var duoAdminWindowCenterY: CGFloat?
    @State private var duoSearchRowWindowCenterY: CGFloat?
    @State private var assistantStrokeRotation: Double = 0.0
    @State private var showFinancialReport = false
    @State private var showSubscriptionReport = false
    @State private var showTransactionCenter = false
    @State private var duoReport: DuoEntityReport?
    @State private var duoSection: DuoEntitySection = .cashFlow
    @State private var duoVaultCategory = "All"
    @State private var duoPortraitSheet: DuoPortraitSheet?
    @State private var duoBinderProgress: CGFloat = 0
    @State private var duoBinderIsDragging = false
    @State private var duoBinderDragStart: CGFloat = 0
    @State private var duoBinderAnimationGeneration = 0
    @Environment(\.accessibilityReduceMotion) private var reducePortraitMotion

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

    @ViewBuilder
    var body: some View {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) {
            companyWithLeftPanel
                .toolbar(usesDuoPortraitLayout ? .hidden : .automatic, for: .navigationBar)
                .modifier(DuoSideToolbar(
                usesSideToolbar: $usesDuoSideToolbar,
                bottomControlCenterY: .constant(nil),
                bottomControlWindowCenterY: $duoAdminWindowCenterY,
                reportsDuoDevice: $isDuoDevice,
                isActive: true,
                admin: profileControlButton,
                primaryAction: duoShareControl.frame(width: 52, height: 52),
                add: duoAddControl,
                entities: entitiesControlMenu
            ))
                .allowsHitTesting(duoPortraitSheet == nil || !usesDuoPortraitLayout)
                .accessibilityHidden(duoPortraitSheet != nil && usesDuoPortraitLayout)
                .overlay { portraitFilesOverlay }

        } else {
            companySurface
        }
        #else
        companySurface
        #endif
    }

    private var usesInlineEntityPanel: Bool {
        duoLayout.usesExpandedLandscape
    }

    private var usesDuoVaultSplit: Bool {
        usesInlineEntityPanel && vm.activeTab == .documents
    }

    private var usesDuoPortraitLayout: Bool {
        duoLayout.usesExpandedPortrait
    }

    @ViewBuilder
    private var companyWithLeftPanel: some View {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *), duoLayout.isDuoDevice {
            DuoEntityPanels(isSplit: usesInlineEntityPanel, isPortrait: usesDuoPortraitLayout) {
                companySurface
            } panel: {
                duoLeftPanel
            }
        } else {
            companySurface
        }
        #else
        companySurface
        #endif
    }

    private var duoLeftPanel: some View {
        let showsReport = !usesDuoVaultSplit && duoSection == .reports
        let showsCashFlow = !usesDuoVaultSplit && !showsReport
        return VStack(spacing: 8) {
            ZStack {
                // One analysis instance survives section/report/pose changes.
                PortfolioTransactionCenterView(
                    vm: vm, embeddedCompanyID: company.id,
                    embeddedSection: .all
                )
                .environment(appState)
                .opacity(showsCashFlow ? 1 : 0)
                .allowsHitTesting(showsCashFlow)
                .accessibilityHidden(!showsCashFlow)

                if usesDuoVaultSplit {
                    DocumentListView(
                        company: company,
                        documents: documents,
                        vm: vm,
                        hideActionBar: true,
                        canEdit: canEditCompany,
                        presentation: .attachments,
                        categorySelection: $duoVaultCategory
                    )
                } else if showsReport {
                    VStack(spacing: 0) {
                            HStack {
                                Button {
                                    duoSection = .cashFlow
                                } label: {
                                    Label("Cash Flow", systemImage: "arrow.left")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.zifrGold)
                                        .padding(.horizontal, 16)
                                        .frame(height: 44)
                                        .background(bottomControlGlass(Capsule()))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Back to cash flow")
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 12)

                        if let duoReport {
                            switch duoReport {
                            case .financial:
                                FinancialReceiptView(
                                    company: company, institutions: institutions, cards: cards,
                                    loans: loans, subscriptions: subscriptions, isEmbedded: true
                                )
                                .accessibilityIdentifier("duo.entityFinancialReport")
                            case .subscriptions:
                                SubscriptionReceiptView(
                                    company: company, subscriptions: subscriptions,
                                    institutions: institutions, cards: cards, isEmbedded: true
                                )
                                .accessibilityIdentifier("duo.entitySubscriptionReport")
                            }
                        } else {
                            VStack(spacing: 16) {
                                Text("Choose a report").font(.headline).foregroundStyle(Color.zifrGold)
                                Button("Financial Report") { duoReport = .financial }
                                Button("Subscription Report") { duoReport = .subscriptions }
                            }
                            .buttonStyle(.bordered)
                            .tint(Color.zifrGold)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private var portraitFilesOverlay: some View {
        if usesDuoPortraitLayout {
            GeometryReader { geometry in
                let activeIndex = DuoPortraitSheet.files.firstIndex { $0.id == duoPortraitSheet?.id } ?? 0
                let drawer = DuoBinderDrawerFrames.resolve(size: geometry.size,
                    progress: duoBinderProgress, tabIndex: activeIndex)
                ZStack(alignment: .topLeading) {
                    if let sheet = duoPortraitSheet {
                        Color.clear.contentShape(Rectangle())
                            .onTapGesture { settlePortraitFile(open: false) }
                            .accessibilityHidden(true)
                            .zIndex(1)
                        portraitSheet(sheet)
                            .id(sheet.id)
                            .frame(width: drawer.sheet.width, height: drawer.sheet.height)
                            .offset(x: drawer.sheet.minX)
                            .transition(.identity)
                            .zIndex(2)
                    }
                    portraitReportBar
                        .padding(.leading, 22)
                        .padding(.top, tutFrameHeader.height)
                        .allowsHitTesting(duoPortraitSheet == nil)
                        .accessibilityHidden(duoPortraitSheet != nil)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(duoPortraitSheet != nil ? .isModal : [])
                .onChange(of: duoPortraitSheet?.id) { _, id in
                    if id == nil { duoBinderProgress = 0 }
                    else if !duoBinderIsDragging { settlePortraitFile(open: true) }
                }
            }
        }
    }

    private var portraitReportBar: some View {
        MiloomDuoReportIconBar {
            ForEach(DuoPortraitSheet.files) { sheet in
                Button { togglePortraitFile(sheet) } label: {
                    Image(systemName: sheet.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.zifrGold)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(sheet.title)
            }
        }

        .accessibilityElement(children: .contain)
    }

    private func togglePortraitFile(_ sheet: DuoPortraitSheet) {
        if duoPortraitSheet?.id == sheet.id {
            settlePortraitFile(open: duoBinderProgress < 0.5)
        } else {
            duoBinderProgress = 0
            duoPortraitSheet = sheet
        }
    }

    private func dragPortraitFile(_ sheet: DuoPortraitSheet, translation: CGFloat, travel: CGFloat) {
        if !duoBinderIsDragging {
            duoBinderAnimationGeneration += 1
            duoBinderIsDragging = true
            duoBinderDragStart = duoPortraitSheet?.id == sheet.id ? duoBinderProgress : 0
            if duoPortraitSheet == nil { duoPortraitSheet = sheet }
        }
        // The divider stays at the edge while the sheet follows the pull.
        duoBinderProgress = min(1, max(0, duoBinderDragStart + translation / max(1, travel)))
    }

    private func settlePortraitFile(open: Bool) {
        duoBinderIsDragging = false
        duoBinderAnimationGeneration += 1
        let generation = duoBinderAnimationGeneration
        let fileID = duoPortraitSheet?.id
        withAnimation(reducePortraitMotion ? nil : .easeInOut(duration: 0.32), completionCriteria: .logicallyComplete) {
            duoBinderProgress = open ? 1 : 0
        } completion: {
            if !open && generation == duoBinderAnimationGeneration && duoPortraitSheet?.id == fileID {
                duoPortraitSheet = nil
            }
        }
    }

    @ViewBuilder
    private func portraitSheet(_ sheet: DuoPortraitSheet) -> some View {
        switch sheet {
        case .transactions:
            MiloomDuoPortraitSheet(title: sheet.title, onClose: { settlePortraitFile(open: false) }) {
                PortfolioTransactionCenterView(vm: vm, embeddedCompanyID: company.id,
                    embeddedSection: .all, usesHolographicStyle: true)
                    .environment(appState)
            }
        case .reports(let report):
            MiloomDuoPortraitSheet(title: sheet.title, onClose: { settlePortraitFile(open: false) }, showsCard: false) {
                switch report {
                case .financial:
                    FinancialReceiptView(company: company, institutions: institutions,
                        cards: cards, loans: loans, subscriptions: subscriptions,
                        isEmbedded: true, usesGlassSummaryStyle: true)
                case .subscriptions:
                    SubscriptionReceiptView(company: company, subscriptions: subscriptions,
                        institutions: institutions, cards: cards,
                        isEmbedded: true, usesGlassSummaryStyle: true)
                }
            }
        }
    }

    private func presentReport(_ report: DuoEntityReport) {
        if usesDuoPortraitLayout {
            duoPortraitSheet = .reports(report)
        } else if usesInlineEntityPanel && !usesDuoVaultSplit {
            duoReport = report
            duoSection = .reports
        } else {
            switch report {
            case .financial: showFinancialReport = true
            case .subscriptions: showSubscriptionReport = true
            }
        }
    }

    private var companySurface: some View {
        GeometryReader { geometry in
        ZStack(alignment: .top) {
            Color.zifrBG.ignoresSafeArea()
            
            AnimatedHeaderBackground()
                .ignoresSafeArea(edges: .top)

            VStack(spacing: 0) {
                // ── Entity Command Plate ─────────────────────────────────────
                companyHeader
                    .padding(.horizontal, 20)
                    .padding(.top, usesDuoPortraitLayout ? 0 : 8)
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
            NewEntitySheet(vm: vm, company: company) { _ in }
        }
        .sheet(item: $sharingScope) { scope in
            ShareEntitySheet(
                resourceId: company.id, resourceType: scope.rawValue,
                resourceTitle: scope == .company ? company.name : scope.title
            )
        }
        .sheet(item: $newSub) { sub in
            if appState.portfolioUserID == company.userId {
                AddSubscriptionWizard(sub: sub, institutions: institutions, cards: cards, vm: vm)
                    .presentationDetents([.fraction(0.9), .large])
            } else {
                // Collaborator creation must not prompt for owner-vault credentials.
                EditSubscriptionSheet(sub: sub, institutions: institutions, cards: cards, vm: vm, isNew: true)
            }
        }
        .sheet(item: $newCard) { c in
            EditCardSheet(card: c, vm: vm, institutions: institutions, cards: cards, isNew: true)
        }
        .sheet(item: $newManualInstitution) { institution in
            EditInstitutionSheet(institution: institution, institutions: institutions,
                                 cards: cards, loans: loans, vm: vm, isNew: true)
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
        .onChange(of: vm.activeTab) { oldTab, _ in
            if oldTab == .documents && duoLayout.isDuoDevice {
                duoVaultCategory = "All"
            }
        }
        .onChange(of: usesDuoPortraitLayout) { _, portrait in
            if !portrait {
                duoBinderAnimationGeneration += 1
                duoBinderIsDragging = false
                duoBinderProgress = 0
                duoPortraitSheet = nil
            }
        }
        .sheet(isPresented: $showTransactionCenter) {
            PortfolioTransactionCenterView(vm: vm)
                .environment(appState)
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
        .overlay {
            tutorialOverlaySection
        }
        .gesture(edgeSwipeGesture(width: geometry.size.width))
        .navigationBarBackButtonHidden(true)
        }
        .safeAreaInset(edge: .bottom) {
            bottomBarInset
        }
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
            canEdit: canEditCompany,
            canAccessCredentials: canAccessCompanyCredentials,
            vm: vm,
            activeInternalTab: $vm.activeTab,
            compactTopSpacing: false,
            vaultPresentation: usesDuoVaultSplit ? .categories : .combined,
            vaultCategorySelection: duoLayout.isDuoDevice ? $duoVaultCategory : nil
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

    private func edgeSwipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                if swipeHandled { return }
                
                let startX = value.startLocation.x
                
                let isEdgeSwipe = startX < 50 || startX > width - 50
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

    private var bottomBarInset: some View {
        bottomBarSurface
            .background {
                if onboardingState.isInFinancialTutorial || onboardingState.isInCommandCenterTutorial {
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { tutFrameTabBar = geo.frame(in: .global) }
                            .onChange(of: geo.frame(in: .global)) { _, f in tutFrameTabBar = f }
                    }
                }
            }
    }

    @ViewBuilder
    private var bottomBarSurface: some View {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) {
            ZStack {
                bottomBarRow.offset(y: duoSearchOffset)
            }
                .background {
                    DuoDashboardWindowCenterReader { duoSearchRowWindowCenterY = $0 }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        } else {
            bottomBarRow.padding(.horizontal, 20).padding(.bottom, 12)
        }
        #else
        bottomBarRow.padding(.horizontal, 20).padding(.bottom, 12)
        #endif
    }

    private var duoSearchOffset: CGFloat {
        guard usesDuoSideToolbar, let adminY = duoAdminWindowCenterY,
              let rowY = duoSearchRowWindowCenterY else { return 0 }
        let adjustment = adminY - rowY
        return abs(adjustment) <= 44 ? adjustment : 0
    }

    private var bottomBarRow: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // 1. Profile / Admin Button (far left)
            if !usesDuoSideToolbar { profileControlButton }

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

            if isDuoDevice { geminiControlButton }

            // 3. Entities Button (instead of Apple Intelligence)
            if !usesDuoSideToolbar { entitiesControlMenu }

            // 4. Quick add for editors; a passive role indicator for viewers.
            if !usesDuoSideToolbar {
                if isDuoDevice {
                    duoAddControl
                } else if canAddInActiveTab {
                    plusControlMenu
                } else {
                    readOnlyControl
                }
            }
        }
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
        vm.selectedCompany = company
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
                guard canEditCompany else { return }
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

                    if usesDuoPortraitLayout || (vm.activeTab == .financial && !usesInlineEntityPanel) {
                        transactionHeaderButton
                    }

                    // Keep Share reachable in any layout without a side toolbar.
                    if isDuoDevice && !usesDuoSideToolbar { duoShareControl }
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

    private var transactionHeaderButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if usesDuoPortraitLayout { duoPortraitSheet = .transactions }
            else { showTransactionCenter = true }
        } label: {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.70))
                .frame(width: usesDuoPortraitLayout ? 44 : 28, height: usesDuoPortraitLayout ? 44 : 28)
                .background {
                    if usesDuoPortraitLayout {
                        Circle().fill(.ultraThinMaterial)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(usesDuoPortraitLayout ? "Entity transactions" : "All transactions")
    }

    @ViewBuilder
    private var headerActionMenu: some View {
        if usesDuoPortraitLayout {
            Button {
                duoPortraitSheet = .reports(vm.activeTab == .subscriptions ? .subscriptions : .financial)
            } label: { headerReportIcon }
            .buttonStyle(.plain)
            .accessibilityLabel("Entity reports")
        } else {
            Menu {
                if !isDuoDevice { sharingMenuItems }
                Section("Reports") {
                    Button {
                        presentReport(.financial)
                    } label: {
                        Label("Financial Report", systemImage: "dollarsign.circle")
                    }
                    Button {
                        presentReport(.subscriptions)
                    } label: {
                        Label("Subscription Report", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            } label: { headerReportIcon }
            .accessibilityLabel(isDuoDevice ? "Entity reports" : "Entity actions")
            .accessibilityHint(!isDuoDevice && canManageSharing ? "Sharing scopes and reports" : "Entity reports")
        }
    }

    private var headerReportIcon: some View {
        Image(systemName: isDuoDevice ? "receipt" : "ellipsis")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Color(hex: "#C1AA78"))
            .frame(width: 44, height: 44)
            .background(.ultraThinMaterial, in: Circle())
            .contentShape(Circle())
    }

    @ViewBuilder
    private var sharingMenuItems: some View {
        if canManageSharing {
            Section("Share Access") {
                ForEach(EntitySharingScope.allCases) { scope in
                    Button {
                        sharingScope = scope
                    } label: {
                        Label(scope.title, systemImage: scope.icon)
                    }
                }
            }
        }
    }

    private var duoShareControl: some View {
        Menu {
            sharingMenuItems
        } label: {
            circularControlLabel {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
        }
        .buttonStyle(.plain)
        .disabled(!canManageSharing)
        .accessibilityLabel("Share access")
        .accessibilityHint(canManageSharing ? "Choose which entity records to share" : "You do not have permission to manage sharing")
    }

    @ViewBuilder
    private var profileControlButton: some View {
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

    @ViewBuilder
    private var entitiesControlMenu: some View {
        MiloomEntitySwitcher(vm: vm, selectedCompanyID: company.id) {
            onShowAllEntities()
            dismiss()
            if isDuoDevice { duoLayout.dashboardRequest &+= 1 }
        }
    }

    private func circularControlLabel<Icon: View>(@ViewBuilder icon: () -> Icon) -> some View {
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

            icon()
        }
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }

    private var plusButtonLabel: some View {
        circularControlLabel {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.85))
        }
    }

    private var geminiControlButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showAssistant = true
        } label: {
            circularControlLabel { MiloomGeminiSparkle() }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Gemini Live")
        .accessibilityHint("Starts a voice conversation with Miloom")
    }

    @ViewBuilder
    private var duoAddControl: some View {
        if canAddInActiveTab {
            plusControlMenu
        } else {
            // Keep the requested Duo glyph without granting creation permission.
            Button {} label: { plusButtonLabel }
                .buttonStyle(.plain)
                .disabled(true)
                .accessibilityLabel("Add item")
                .accessibilityHint("You do not have permission to add items in this section")
        }
    }

    private var readOnlyControl: some View {
        ZStack {
            bottomControlGlass(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "#918457"), Color(hex: "#918457").opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)

            Image(systemName: "eye")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.75))
        }
        .frame(width: 44, height: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Company access")
        .accessibilityValue("Cannot add items. Shared items may have separate edit access.")
    }

    @ViewBuilder
    private var plusControlMenu: some View {
        switch vm.activeTab {
        case .financial:
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
                        guard canCreate("institution") else { return }
                        let draft = Institution(userId: company.userId, companyId: company.id)
                        if appState.portfolioUserID == company.userId {
                            wizardInstitution = draft
                        } else {
                            // Bank linking and its multi-resource wizard remain owner-only.
                            newManualInstitution = draft
                        }
                    } label: {
                        Label(appState.portfolioUserID == company.userId ? "Add Account" : "Add Institution Manually",
                              systemImage: "building.columns")
                    }
                }
            } label: {
                plusButtonLabel
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add financial item")

        case .subscriptions:
            Button {
                guard canCreate("subscription") else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                newSub = Subscription(userId: company.userId, companyId: company.id)
            } label: {
                plusButtonLabel
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add service")

        case .documents:
            Button {
                guard canCreate("document") else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                newDoc = CompanyDocument(userId: company.userId, companyId: company.id)
            } label: {
                plusButtonLabel
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add document")
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
