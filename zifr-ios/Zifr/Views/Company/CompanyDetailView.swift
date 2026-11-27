import SwiftUI
import UIKit

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

/// Size the portrait page from its own window, reserving room for the filing
/// toolbar on the left and keeping the page clear of the trailing actions.
struct DuoPortraitFilingFrames: Equatable {
    let page: CGRect
    let tabs: CGRect

    static func resolve(size: CGSize) -> Self {
        let width = max(0, size.width), height = max(0, size.height)
        let rail = min(width, 124)
        let pageWidth = width - rail
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
                        foldY: CGFloat? = nil, division: CGRect? = nil) -> Self {
        let width = max(0, size.width), height = max(0, size.height)
        if expanded && portrait {
            let files = DuoPortraitFilingFrames.resolve(size: size)
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
    var usesSystemToolbar = false
    var companyTitle: String? = nil
    var isPhoneCommandCenter = false
    var onOpenAdmin: (() -> Void)? = nil
    let onShowAllEntities: () -> Void

    @ViewBuilder
    var body: some View {
        if usesSystemToolbar {
            menu
        } else {
            menu.buttonStyle(.plain)
        }
    }

    private var menu: some View {
        Menu {
            if !appState.companies.isEmpty {
                Section("Jump to Entity") {
                    ForEach(appState.companies.sorted { $0.name < $1.name }) { company in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            vm.selectedCompany = company
                            vm.touchCompany(company, appState: appState)
                            vm.openCompany(company, replacingPath: true)
                        } label: {
                            if company.id == selectedCompanyID, isPhoneCommandCenter,
                               let emblem = Self.activeEntityEmblem {
                                Label {
                                    Text(company.name)
                                } icon: {
                                    Image(uiImage: emblem)
                                }
                                .labelStyle(.titleAndIcon)
                            } else if company.id == selectedCompanyID {
                                Label(company.name, systemImage: "checkmark")
                            } else {
                                Text(company.name)
                            }
                        }
                    }
                }
            }
            if isPhoneCommandCenter { allEntitiesItem }
            if let onOpenAdmin {
                Button(action: onOpenAdmin) {
                    Label(isPhoneCommandCenter ? "Admin" : "Admin settings", systemImage: "person.crop.circle")
                }
            }
            if !isPhoneCommandCenter { allEntitiesItem }
        } label: {
            if let companyTitle {
                HStack(spacing: 5) {
                    Text(companyTitle)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 158)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .accessibilityHidden(true)
                }
            } else if usesSystemToolbar {
                DuoEntityToolbarLabel(title: "Switch entity", icon: "circle.grid.3x3.fill")
            } else {
                MiloomCircularToolbarLabel {
                    Image(systemName: "circle.grid.3x3.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
            }
        }
        .menuOrder(isPhoneCommandCenter ? .fixed : .automatic)
        .accessibilityLabel("Switch entity")
        .accessibilityValue(companyTitle ?? "")
    }

    private static let activeEntityEmblem: UIImage? = {
        guard let emblem = UIImage(named: "miloom_emblem") else { return nil }
        let width: CGFloat = 28
        let size = CGSize(width: width, height: width * emblem.size.height / emblem.size.width)
        let goldEmblem = emblem.withTintColor(UIColor(Color.zifrGold), renderingMode: .alwaysOriginal)
        return UIGraphicsImageRenderer(size: size).image { _ in
            goldEmblem.draw(in: CGRect(origin: .zero, size: size))
        }.withRenderingMode(.alwaysOriginal)
    }()

    private var allEntitiesItem: some View {
        Button {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            onShowAllEntities()
        } label: {
            Label("All Entities", systemImage: "square.grid.2x2")
        }
    }
}

private struct DuoEntityToolbarLabel: View {
    @Environment(MiloomDuoLayoutState.self) private var layout
    let title: LocalizedStringKey
    let icon: String

    var body: some View {
        let label = Label(title, systemImage: icon)
        if layout.isDuoDevice || layout.usesPadSideNavigation {
            label
                .labelStyle(.iconOnly)
                .font(.system(size: 21.5, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        } else {
            label
        }
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
private extension DuoEntityPanelFrames {
    static func resolve(in geometry: GeometryProxy, isSplit: Bool, isPortrait: Bool,
                        widthLimit: CGFloat? = nil) -> Self {
        let division = geometry.reservedRegions(kind: .division).first {
            $0.frame.height > $0.frame.width
        }.map {
            CGRect(x: $0.frame.minX - $0.margins.leading,
                   y: $0.frame.minY - $0.margins.top,
                   width: $0.frame.width + $0.margins.leading + $0.margins.trailing,
                   height: $0.frame.height + $0.margins.top + $0.margins.bottom)
        }
        let size = CGSize(width: min(geometry.size.width, widthLimit ?? geometry.size.width),
                          height: geometry.size.height)
        return resolve(size: size, expanded: isSplit || isPortrait,
                       portrait: isPortrait, division: division)
    }
}

@available(iOS 27.1, *)
private struct DuoEntityPanels<Page: View, Panel: View>: View {
    let isSplit: Bool
    @ViewBuilder let page: (CGFloat) -> Page
    @ViewBuilder let panel: () -> Panel

    var body: some View {
        GeometryReader { geometry in
            let frame = DuoEntityPanelFrames.resolve(in: geometry, isSplit: isSplit, isPortrait: false).panel
            // Keep the tab host full-width. Only the pages inside it use the pane geometry.
            page(geometry.size.width)
                .overlay(alignment: .topLeading) {
                    ZStack {
                        if isSplit { panel() }
                    }
                    .frame(width: frame.width, height: frame.height)
                    .clipped()
                    .contentShape(Rectangle())
                    .offset(x: frame.minX, y: frame.minY)
                    .opacity(isSplit ? 1 : 0)
                    .allowsHitTesting(isSplit)
                    .accessibilityHidden(!isSplit)
                    .accessibilityIdentifier("duo.entityPanel")
                }
        }
        .background(Color.zifrBG.ignoresSafeArea())
    }
}

#endif

@available(iOS 26.0, *)
private struct PhoneAddControlSource: UIViewRepresentable {
    enum Command: Equatable {
        case menu([String])
        case action
    }

    @Binding var referenceView: UIView?
    let command: Command?
    let makeMenu: (PhoneAddControlButton) -> UIMenu
    let performAction: () -> Void

    func makeUIView(context: Context) -> PhoneAddControlAnchor {
        let view = PhoneAddControlAnchor()
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async { referenceView = view }
        return view
    }

    func updateUIView(_ view: PhoneAddControlAnchor, context: Context) {
        view.button.directAction = command == .action ? performAction : nil
        if view.command != command {
            view.command = command
            if case .menu = command {
                view.button.menu = makeMenu(view.button)
                view.button.showsMenuAsPrimaryAction = true
            } else {
                view.button.showsMenuAsPrimaryAction = false
                view.button.menu = nil
            }
        }
        view.placeButton()
    }

    static func dismantleUIView(_ view: PhoneAddControlAnchor, coordinator: ()) {
        view.button.directAction = nil
        view.button.menu = nil
        view.button.removeFromSuperview()
    }
}

@available(iOS 26.0, *)
private final class PhoneAddControlAnchor: UIView {
    let button = PhoneAddControlButton()
    var command: PhoneAddControlSource.Command?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        placeButton()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        placeButton()
    }

    func placeButton() {
        guard command != nil, window != nil,
              let controller = sequence(first: self as UIResponder, next: { $0.next })
                .compactMap({ $0 as? UIViewController }).first,
              let host = (controller.tabBarController ?? controller).view,
              host.window != nil else {
            button.removeFromSuperview()
            return
        }

        let content = convert(bounds, to: host)
        let frame = controller.tabBarController?.tabs.last?.frame(in: host)
            ?? CGRect(x: content.maxX - 78, y: content.maxY, width: 60, height: 44)
        button.tabController = controller.tabBarController
        guard !frame.isEmpty, host.bounds.contains(frame) else {
            button.removeFromSuperview()
            return
        }
        if button.frame != frame {
            button.frame = frame
        }
        if button.superview !== host {
            host.addSubview(button)
        }
    }
}

@available(iOS 26.0, *)
private final class PhoneAddControlButton: UIButton {
    weak var tabController: UITabBarController?
    var directAction: (() -> Void)?
    var selectedAction: (() -> Void)?
    private weak var closingFade: UIView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = false
        preferredMenuElementOrder = .fixed
        addAction(UIAction { [weak self] _ in self?.directAction?() }, for: .primaryActionTriggered)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard super.point(inside: point, with: event) else { return false }
        // After a swipe, UIKit can give Add and the collapsed section icon the same frame.
        // Let the native tab bar receive taps on that icon so it can expand.
        guard let selectedFrame = tabController?.selectedTab?.frame(in: self) else { return true }
        return !selectedFrame.contains(point)
    }

    override func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                         willDisplayMenuFor configuration: UIContextMenuConfiguration,
                                         animator: (any UIContextMenuInteractionAnimating)?) {
        super.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: animator)
        closingFade?.removeFromSuperview()
    }

    override func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                         willEndFor configuration: UIContextMenuConfiguration,
                                         animator: (any UIContextMenuInteractionAnimating)?) {
        super.contextMenuInteraction(interaction, willEndFor: configuration, animator: animator)
        let finish = { [weak self] in
            guard let self else { return }
            let action = selectedAction
            selectedAction = nil
            action?()
        }
        if let animator {
            animateClosingFade()
            animator.addCompletion(finish)
        } else {
            DispatchQueue.main.async(execute: finish)
        }
    }

    private func animateClosingFade() {
        guard !UIAccessibility.isReduceMotionEnabled, let host = superview else { return }
        closingFade?.removeFromSuperview()
        // Carry the dismissing glass into a soft fade without redrawing the plus.
        let diameter = min(bounds.width, bounds.height)
        guard diameter > 0, let gradient = CGGradient(
            colorsSpace: nil,
            colors: [CGColor(gray: 0, alpha: 0.19), CGColor(gray: 0, alpha: 0.16),
                     CGColor(gray: 0, alpha: 0)] as CFArray,
            locations: [0, 0.65, 1]
        ) else { return }
        let radius = diameter / 2
        let center = CGPoint(x: radius, y: radius)
        let image = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter)).image { context in
            context.cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                                 endCenter: center, endRadius: radius, options: [])
        }
        let shade = UIImageView(image: image)
        shade.center = CGPoint(x: frame.midX, y: frame.midY)
        shade.isUserInteractionEnabled = false
        shade.accessibilityElementsHidden = true
        shade.transform = CGAffineTransform(translationX: 0, y: -6).scaledBy(x: 1.15, y: 1.15)
        host.insertSubview(shade, aboveSubview: self)
        closingFade = shade
        UIView.animate(withDuration: 0.48, delay: 0, options: [.curveLinear, .allowUserInteraction]) {
            shade.transform = .identity
            shade.alpha = 0
        } completion: { _ in
            shade.removeFromSuperview()
        }
    }
}

struct CompanyDetailView: View {
    private enum AddResource: String, Identifiable {
        case institution, card, loan, subscription, document

        var id: Self { self }

        func title(isOwner: Bool) -> String {
            switch self {
            case .institution: isOwner ? String(localized: "Add Account") : String(localized: "Add Institution Manually")
            case .card: String(localized: "Add Card")
            case .loan: String(localized: "Add Loan")
            case .subscription: String(localized: "Add Service")
            case .document: String(localized: "Add Document")
            }
        }

        var icon: String {
            switch self {
            case .institution: "building.columns"
            case .card: "creditcard"
            case .loan: "dollarsign.circle"
            case .subscription: "square.3.layers.3d"
            case .document: "doc.badge.plus"
            }
        }
    }

    @State var company: Company
    @Bindable var vm: AppViewModel
    let onShowAllEntities: () -> Void
    var phoneSection: EntityHomeTab? = nil
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(OnboardingStateManager.self) private var onboardingState
    @Environment(MiloomDuoLayoutState.self) private var duoLayout
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.layoutDirection) private var layoutDirection

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
    #if compiler(>=6.4)
    @State private var duoSideGestures = DuoSideGestures()
    #endif
    @State private var tabBounces: [EntityHomeTab: Int] = [:]
    @State private var searchBounce: Int = 0

    @State private var newSub: Subscription? = nil
    @State private var newCard: FinancialCard? = nil
    @State private var newDoc: CompanyDocument? = nil
    @State private var newLoan: Loan? = nil
    @State private var newManualInstitution: Institution?
    @State private var wizardInstitution: Institution? = nil
    @State private var showAssistant = false
    @State private var assistantStrokeRotation: Double = 0.0
    @State private var showFinancialReport = false
    @State private var showSubscriptionReport = false
    @State private var showTransactionCenter = false
    @State private var phoneAddReferenceView: UIView?
    @State private var showPhoneAddUnavailable = false
    @State private var showEntityCashFlow = false
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
    @State private var nativeTabContainerFrame: CGRect = .zero
    @State private var customVaultCenterY: CGFloat?
    @State private var footerCenterY: CGFloat?
    @State private var nativeFooterOffset: CGFloat?
    @State private var tutFrameFinancialActionBar: CGRect = .zero

    private var currentTabIndex: Int {
        EntityHomeTab.allCases.firstIndex(of: vm.activeTab) ?? 0
    }

    private var isDuoDevice: Bool { duoLayout.isDuoDevice }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *), duoLayout.usesPadSideNavigation {
            companySurface()
                .safeAreaInset(edge: .trailing, spacing: 8) {
                    padCommandRail
                }
                .toolbar(.hidden, for: .navigationBar)
                .allowsHitTesting(duoPortraitSheet == nil || !usesDuoPortraitLayout)
                .accessibilityHidden(duoPortraitSheet != nil && usesDuoPortraitLayout)
                .overlay { portraitFilesOverlay }
        } else if #available(iOS 26.0, *), phoneSection != nil {
            companySurface()
                .onChange(of: vm.phoneAddRequest) {
                    guard let phoneSection, vm.phoneTab == .section(phoneSection), vm.path.isEmpty else { return }
                    openPhoneAdd()
                }
                .background { phoneAddControl }
                .alert("Add unavailable", isPresented: $showPhoneAddUnavailable) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("You don’t have permission to add items to this entity.")
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { entitiesControlMenu }
                    ToolbarItem(placement: .topBarTrailing) { phoneReportsMenu }
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                    ToolbarItem(placement: .topBarTrailing) { duoShareControl }
                }
        } else if #available(iOS 26.0, *), duoLayout.usesPhoneAndPadGlassNavigation {
            companySurface()
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        duoProfileControl
                        entitiesControlMenu
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        duoToolbarReportsMenu
                        duoShareControl
                        duoAddControl
                    }
                }
        } else {
            adaptiveCompanySurface
        }
    }

    @ViewBuilder
    private var adaptiveCompanySurface: some View {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) {
            companyWithLeftPanel
                .modifier(DuoSideToolbar(
                usesSideToolbar: .constant(false),
                bottomControlCenterY: .constant(nil),
                bottomControlWindowCenterY: .constant(nil),
                reportsDuoDevice: .constant(false),
                isActive: true,
                admin: duoToolbarControl(duoProfileControl, anchor: .admin),
                primaryAction: duoToolbarControl(duoShareControl, anchor: .share),
                add: duoToolbarControl(duoAddControl, anchor: .add),
                entities: duoToolbarControl(entitiesControlMenu, anchor: .entities),
                portraitActionsTopInset: usesDuoPortraitLayout ? duoLayout.portraitToolbarInsets.commandCenter : tutFrameHeader.height,
                reservesCompactContentWidth: true,
                usesSystemItems: true,
                entityTabSelection: $vm.activeTab,
                onStackedVaultCenterChange: { customVaultCenterY = $0 },
                nativeReportMenu: duoLayout.usesExpandedLandscape && activeDuoReport != nil
                    ? nil : AnyView(duoToolbarReportsMenu)
            ))
                .overlay(alignment: .bottomTrailing) {
                    if usesDuoPortraitLayout {
                        VStack(spacing: 8) {
                            duoToolbarControl(entitiesControlMenu, anchor: .entities)
                                .glassEffect(.regular.interactive(), in: Circle())
                            portraitTabBar
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 22)
                        .padding(.bottom, 10)
                    }
                }
                .allowsHitTesting(duoPortraitSheet == nil || !usesDuoPortraitLayout)
                .accessibilityHidden(duoPortraitSheet != nil && usesDuoPortraitLayout)
                .overlay {
                    if isDuoDevice {
                        contextualReportOverlay
                    }
                }

        } else {
            companySurface()
        }
        #else
        companySurface()
        #endif
    }

    @available(iOS 26.0, *)
    private var padCommandRail: some View {
        VStack(spacing: 8) {
            VStack(spacing: 0) {
                duoShareControl
                duoAddControl
            }
            .padding(1)
            .glassEffect(.regular.interactive(), in: Capsule())
            if duoLayout.usesPadSplit {
                duoToolbarReportsMenu.glassEffect(.regular.interactive(), in: Circle())
            }
            Spacer(minLength: 8)
            entitiesControlMenu.glassEffect(.regular.interactive(), in: Circle())
            portraitTabBar
        }
        .buttonStyle(.plain)
        .padding(.top, duoLayout.padActionsTopInset)
        .padding(.trailing, 22)
        .padding(.bottom, 10)
    }

    private var usesInlineEntityPanel: Bool {
        duoLayout.usesExpandedLandscape || duoLayout.usesPadSplit
    }

    private var usesDuoVaultSplit: Bool {
        usesInlineEntityPanel && vm.activeTab == .documents
    }

    private var usesDuoPortraitLayout: Bool {
        duoLayout.usesExpandedPortrait || (duoLayout.usesPadSideNavigation && !duoLayout.usesPadSplit)
    }

    private var hidesManagedEntityTabBar: Bool {
        usesDuoPortraitLayout || duoLayout.usesStackedLayout || duoLayout.usesNativeSideToolbarGroups
    }

    private var showsCompanyHeader: Bool {
        if duoLayout.usesPhoneTabs {
            return false
        }
        return !duoLayout.usesPadSideNavigation && !duoLayout.usesNativeSideToolbarGroups && !usesDuoPortraitLayout && !duoLayout.usesStackedPortraitLayout
    }

    @ViewBuilder
    private var companyWithLeftPanel: some View {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *), duoLayout.isDuoDevice {
            DuoEntityPanels(isSplit: usesInlineEntityPanel) { contentWidth in
                companySurface(duoContentWidth: contentWidth)
            } panel: {
                if usesDuoVaultSplit {
                    vaultPanel.background {
                        DuoSideGestureMarker(gestures: duoSideGestures, anchor: .leftPanel)
                    }
                }
            }
        } else {
            companySurface()
        }
        #else
        companySurface()
        #endif
    }

    private var vaultPanel: some View {
        DocumentListView(company: company, documents: documents, vm: vm, hideActionBar: true,
            canEdit: canEditCompany, presentation: .attachments, categorySelection: $duoVaultCategory)
    }

    private var activeDuoReport: DuoEntityReport? {
        switch vm.activeTab {
        case .financial: .financial
        case .subscriptions: .subscriptions
        case .documents: nil
        }
    }

    #if compiler(>=6.4)
    @available(iOS 27.1, *)
    private var contextualReportOverlay: some View {
        let landscape = duoLayout.usesExpandedLandscape
        let portrait = duoLayout.usesExpandedPortrait
        return GeometryReader { geometry in
            let panel = DuoEntityPanelFrames.resolve(in: geometry, isSplit: true, isPortrait: false).panel
            let drawer = DuoBinderDrawerFrames.resolve(size: geometry.size, progress: duoBinderProgress, tabIndex: 0)
            let frame = landscape ? panel : drawer.sheet
            let visible = landscape || (portrait && duoPortraitSheet != nil)
            ZStack(alignment: .topLeading) {
                if portrait && duoPortraitSheet != nil {
                    Color.clear.contentShape(Rectangle()).onTapGesture { settlePortraitFile(open: false) }
                        .accessibilityHidden(true)
                }
                // Keep one report mounted while the open Duo changes orientation.
                if let report = activeDuoReport, landscape || portrait {
                    MiloomDuoPortraitSheet(title: DuoPortraitSheet.reports(report).title,
                        onClose: { settlePortraitFile(open: false) }, showsCard: false, isInline: landscape) {
                        contextualReport(report)
                    }
                    .id(company.id)
                    .frame(width: frame.width, height: frame.height)
                    .background {
                        if landscape { DuoSideGestureMarker(gestures: duoSideGestures, anchor: .leftPanel) }
                    }
                    .offset(x: frame.minX, y: frame.minY)
                    .opacity(visible ? 1 : 0)
                    .allowsHitTesting(visible)
                    .accessibilityHidden(!visible)
                }
                if portrait && duoPortraitSheet == nil, let report = activeDuoReport {
                    MiloomDuoReportIconBar {
                        portraitReportButton(.reports(report))
                    }
                    .padding(.leading, 22)
                    .padding(.top, duoLayout.portraitToolbarInsets.commandCenter)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
        }
        .onChange(of: duoPortraitSheet?.id) { _, id in
            if portrait, id != nil { settlePortraitFile(open: true) }
        }
        .onChange(of: activeDuoReport) { _, report in
            if portrait && duoPortraitSheet != nil {
                duoPortraitSheet = report.map { .reports($0) }
                if report == nil { duoBinderProgress = 0 }
            }
        }
        .onChange(of: duoLayout.usesExpandedLandscape) { wasLandscape, isLandscape in
            if wasLandscape && portrait, let report = activeDuoReport {
                duoBinderProgress = 1
                duoPortraitSheet = .reports(report)
            } else if isLandscape {
                duoBinderAnimationGeneration += 1
                duoPortraitSheet = nil
                duoBinderProgress = 0
            }
        }
    }
    #endif

    @ViewBuilder private func contextualReport(_ report: DuoEntityReport) -> some View {
        let banks = allInstitutions.filter { $0.companyId == company.id }
        let entityCards = allCards.filter { $0.companyId == company.id }
        let services = allSubscriptions.filter { $0.companyId == company.id }
        Group {
            switch report {
            case .financial:
                FinancialReceiptView(company: company, institutions: banks, cards: entityCards,
                    loans: allLoans.filter { $0.companyId == company.id }, subscriptions: services,
                    isEmbedded: true, usesGlassSummaryStyle: true, cashFlowViewModel: vm)
                    .accessibilityIdentifier("duo.entityFinancialReport")
            case .subscriptions:
                SubscriptionReceiptView(company: company, subscriptions: services, institutions: banks,
                    cards: entityCards, isEmbedded: true, usesGlassSummaryStyle: true, showsChargeHistory: true)
                    .accessibilityIdentifier("duo.entitySubscriptionReport")
            }
        }
        .scrollIndicators(.hidden)
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
                    vaultPanel
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
                        .padding(.top, duoLayout.usesPadSideNavigation ? duoLayout.padActionsTopInset : duoLayout.portraitToolbarInsets.commandCenter)
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
                portraitReportButton(sheet)
            }
        }

        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func portraitReportButton(_ sheet: DuoPortraitSheet) -> some View {
        let button = Button { togglePortraitFile(sheet) } label: {
            let icon = Image(systemName: sheet.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.zifrGold)
                .frame(width: 44, height: 44)
            if duoLayout.usesPadSideNavigation {
                icon.contentShape(Rectangle())
            } else {
                icon
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(sheet.title)

        #if compiler(>=6.4)
        duoToolbarControl(button, anchor: .report(sheet.id))
        #else
        button
        #endif
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
            MiloomDuoPortraitSheet(title: sheet.title, onClose: { settlePortraitFile(open: false) }, showsCard: false) {
                PortfolioTransactionCenterView(vm: vm, embeddedCompanyID: company.id,
                    embeddedSection: .all, usesGlassSummaryStyle: true)
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
        if isDuoDevice && (duoLayout.usesExpandedLandscape || duoLayout.usesExpandedPortrait) {
            vm.activeTab = report == .financial ? .financial : .subscriptions
            if duoLayout.usesExpandedPortrait { togglePortraitFile(.reports(report)) }
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

    private func companySurface(duoContentWidth: CGFloat? = nil) -> some View {
        GeometryReader { geometry in
        ZStack(alignment: .top) {
            Color.zifrBG.ignoresSafeArea()
            
            AnimatedHeaderBackground()
                .ignoresSafeArea(edges: .top)

            entityPages(duoContentWidth: duoContentWidth)
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
            if oldTab == .documents && (duoLayout.isDuoDevice || duoLayout.usesPadSideNavigation) {
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
        .sheet(isPresented: $showEntityCashFlow) {
            NavigationStack {
                PortfolioTransactionCenterView(vm: vm, embeddedCompanyID: company.id,
                    embeddedSection: .all, usesGlassSummaryStyle: true)
                    .navigationTitle("Cash Flow & Transactions")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showEntityCashFlow = false }
                        }
                    }
            }
            .presentationDragIndicator(.visible)
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
        .gesture(edgeSwipeGesture(width: geometry.size.width),
                 including: duoLayout.isDuoDevice ? .subviews : .all)
        .navigationBarBackButtonHidden(true)
        }
    }

    @ViewBuilder
    private func entityPages(duoContentWidth: CGFloat?) -> some View {
        if let phoneSection {
            entityPage(selection: .constant(phoneSection))
        } else if duoLayout.usesPadSideNavigation {
            HStack(spacing: 12) {
                if duoLayout.usesPadSplit {
                    duoLeftPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
                entityPage(selection: $vm.activeTab)
                    .frame(maxWidth: .infinity)
            }
            .padding(.leading, duoLayout.usesPadSplit ? 0 : 80)
        } else if #available(iOS 26.0, *), duoLayout.usesPhoneAndPadGlassNavigation {
            TabView(selection: $vm.activeTab) {
                ForEach(EntityHomeTab.allCases, id: \.self) { tab in
                    Tab(tab.rawValue, systemImage: tab.icon, value: tab) {
                        entityPage(selection: .constant(tab))
                            .background(Color.zifrBG.ignoresSafeArea())
                            .environment(\.horizontalSizeClass, horizontalSizeClass)
                    }
                }
            }
            .tabViewStyle(.tabBarOnly)
            // Regular-width iPad tabs omit their symbols. Use the native bottom
            // bar while keeping each page in the window's actual size class.
            .environment(\.horizontalSizeClass, .compact)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                nativeTabContainerFrame = frame
            }
        } else {
            adaptiveEntityPages(duoContentWidth: duoContentWidth)
        }
    }

    @ViewBuilder
    private func adaptiveEntityPages(duoContentWidth: CGFloat?) -> some View {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *), duoLayout.isDuoDevice {
            TabView(selection: $vm.activeTab) {
                ForEach(EntityHomeTab.allCases, id: \.self) { tab in
                    Tab(tab.rawValue, systemImage: tab.icon, value: tab) {
                        duoEntityPage(for: tab, widthLimit: duoContentWidth)
                            .background(Color.zifrBG.ignoresSafeArea())
                            .toolbarVisibility(hidesManagedEntityTabBar ? .hidden : .automatic, for: .tabBar)
                    }
                }
            }
            .tabViewStyle(.tabBarOnly)
            .onChange(of: vm.activeTab, initial: true) { _, tab in
                duoSideGestures.tab = tab
            }
        } else {
            entityPage(selection: $vm.activeTab)
        }
        #else
        entityPage(selection: $vm.activeTab)
        #endif
    }

    private func entityPage(selection: Binding<EntityHomeTab>) -> some View {
        VStack(spacing: 0) {
            if showsCompanyHeader {
                companyHeader
                    .padding(.horizontal, 20)
                    .padding(.top, companyHeaderTopInset)
                    .padding(.bottom, 4)
                    .zIndex(10)
                    .background {
                        GeometryReader { geometry in
                            Color.clear.preference(key: TutorialFrameKey.self,
                                                   value: ["header": geometry.frame(in: .global)])
                        }
                    }
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                        if duoLayout.isDuoDevice && vm.activeTab == selection.wrappedValue {
                            tutFrameHeader = frame
                        }
                    }
            }

            if !appState.hasLoadedCompanyContent && appState.isLoading {
                ProgressView("Loading company details…")
                    .tint(Color.zifrGold)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.vertical, 8)
            }

            mainContentSection(selection: selection)
                .background(alignment: .top) {
                    if !showsCompanyHeader {
                        // The headerless page introduces the first section during onboarding.
                        Color.clear
                            .frame(height: 64)
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                                if vm.activeTab == selection.wrappedValue {
                                    tutFrameHeader = frame
                                }
                            }
                    }
                }
        }
        .safeAreaInset(edge: .bottom, spacing: phoneSection == nil ? nil : 0) {
            if phoneSection == nil { bottomBarInset }
            else if onboardingState.isTutorialActive {
                Color.clear.frame(height: 0)
                    .onGeometryChange(for: CGRect.self) { geometry in
                        let edge = geometry.frame(in: .global)
                        return CGRect(x: edge.minX, y: edge.maxY, width: edge.width, height: 48)
                    } action: { frame in
                        tutFrameTabBar = frame
                        tutFrameQuickAdd = CGRect(x: frame.minX, y: frame.minY, width: 76, height: frame.height)
                    }
            }
        }
    }

    @available(iOS 26.0, *)
    private var portraitTabBar: some View {
        DuoTabBar(
            selection: $vm.activeTab, tabs: EntityHomeTab.allCases,
            title: { Text($0.rawValue) }, icon: { $0.icon },
            horizontalInset: 3,
            glass: .clear, selectionFill: .black.opacity(0.18), revealsTitlesOnHold: true,
            onBottomTabCenterChange: { customVaultCenterY = $0 }
        )
        .buttonStyle(.plain)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
            tutFrameTabBar = $0
        }
        .frame(width: 52)
    }

    #if compiler(>=6.4)
    @available(iOS 27.1, *)
    private func duoEntityPage(for tab: EntityHomeTab, widthLimit: CGFloat?) -> some View {
        GeometryReader { geometry in
            let frame = DuoEntityPanelFrames.resolve(in: geometry, isSplit: usesInlineEntityPanel,
                                                     isPortrait: usesDuoPortraitLayout,
                                                     widthLimit: widthLimit).page
            entityPage(selection: .constant(tab))
                .frame(width: frame.width, height: frame.height)
                .background {
                    if vm.activeTab == tab {
                        DuoSideGestureMarker(
                            gestures: duoSideGestures,
                            anchor: .page,
                            layout: duoGestureLayout,
                            isActive: duoPortraitSheet == nil && !onboardingState.isTutorialActive,
                            onSwipe: selectDuoTab
                        )
                    }
                }
                .offset(x: frame.minX, y: frame.minY)
        }
    }

    private var duoGestureLayout: DuoSideSwipe.Layout {
        if usesInlineEntityPanel { return .split }
        if usesDuoPortraitLayout { return .portrait }
        if duoLayout.usesStackedLayout { return .stacked }
        return duoLayout.usesLeftSplitToolbar ? .leftSplitPane : .compact
    }

    private func duoToolbarControl<Control: View>(_ control: Control, anchor: DuoSideGestures.Control) -> some View {
        control.background {
            if duoLayout.isDuoDevice {
                DuoSideGestureMarker(gestures: duoSideGestures, anchor: .control(anchor))
            }
        }
    }

    private func selectDuoTab(distance: CGFloat, velocity: CGFloat) {
        let tabs = EntityHomeTab.allCases
        guard let index = DuoSideSwipe.tab(from: currentTabIndex, count: tabs.count,
                                          distance: distance, velocity: velocity) else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(reducePortraitMotion ? nil : .interpolatingSpring(stiffness: 240, damping: 32)) {
            vm.activeTab = tabs[index]
        }
    }
    #endif

    // MARK: - Body Sub-expressions
    @ViewBuilder
    private func mainContentSection(selection: Binding<EntityHomeTab>) -> some View {
        let content = EntityHomeView(
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
            activeInternalTab: selection,
            usesNativeTabs: isDuoDevice || duoLayout.usesPhoneAndPadGlassNavigation,
            reservesTabRow: duoLayout.usesStackedLayout,
            compactTopSpacing: false,
            tabSelectorHeaderHeight: duoLayout.isDuoDevice && showsCompanyHeader ? max(0, tutFrameHeader.height - companyHeaderTopInset) : nil,
            tabSelectorBottomInset: duoLayout.isDuoDevice && showsCompanyHeader ? companyHeaderVerticalPadding : nil,
            vaultPresentation: usesInlineEntityPanel ? .categories : (duoLayout.usesStackedLayout ? .scrolling : .combined),
            vaultCategorySelection: (duoLayout.isDuoDevice || duoLayout.usesPadSplit) ? $duoVaultCategory : nil,
            vaultTopContentInset: showsCompanyHeader ? nil : 12
        )
        #if compiler(>=6.4)
        if #available(iOS 27.1, *), duoLayout.isDuoDevice {
            content.duoSideScrollTargets(duoSideGestures)
        } else {
            content
        }
        #else
        content
        #endif
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
                case .tutorialCommandTabBar:
                    // The native tabs occupy the space below the measured footer.
                    if duoLayout.usesPhoneAndPadGlassNavigation, !duoLayout.usesPadSideNavigation, !tutFrameTabBar.isEmpty,
                       nativeTabContainerFrame.maxY > tutFrameTabBar.maxY {
                        return CGRect(x: nativeTabContainerFrame.minX, y: tutFrameTabBar.maxY,
                                      width: nativeTabContainerFrame.width,
                                      height: nativeTabContainerFrame.maxY - tutFrameTabBar.maxY)
                    }
                    return tutFrameTabBar != .zero ? tutFrameTabBar : tutFrameHeader
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
                            if phoneSection != nil {
                                vm.returnToDashboard()
                            } else {
                                if !vm.path.isEmpty { vm.path.removeLast() }
                                dismiss()
                            }
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
                if !usesDuoPortraitLayout && !duoLayout.usesPadSideNavigation &&
                    (onboardingState.isInFinancialTutorial || onboardingState.isInCommandCenterTutorial) {
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { tutFrameTabBar = geo.frame(in: .global) }
                            .onChange(of: geo.frame(in: .global)) { _, f in tutFrameTabBar = f }
                    }
                }
            }
    }

    private var bottomBarSurface: some View {
        alignedBottomBarRow
            .padding(.horizontal, 20)
            .padding(.bottom, usesInlineEntityPanel ? 0 : 12)
    }

    @ViewBuilder
    private var alignedBottomBarRow: some View {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *), isDuoDevice {
            bottomBarRow
                .offset(y: duoFooterOffset)
                .background {
                    // Measure outside the offset so reconciliation cannot feed back into itself.
                    if hidesManagedEntityTabBar {
                        DuoWindowVerticalMeasurement { footerCenterY = $0 }
                    } else {
                        DuoWindowVerticalMeasurement(measure: { marker, window in
                            guard let vaultCenter = Self.nativeVaultCenter(in: window, window: window) else {
                                return nil
                            }
                            return vaultCenter - marker.convert(marker.bounds, to: window).midY
                        }) {
                            nativeFooterOffset = $0
                        }
                    }
                }
        } else {
            bottomBarRow
        }
        #else
        bottomBarRow
        #endif
    }

    private var duoFooterOffset: CGFloat {
        let adjustment: CGFloat?
        if hidesManagedEntityTabBar {
            adjustment = customVaultCenterY.flatMap { vault in footerCenterY.map { vault - $0 } }
        } else {
            adjustment = nativeFooterOffset
        }
        // One rail can finish laying out before the other when rotating or resizing.
        if let adjustment, abs(adjustment) <= 44 { return adjustment }
        return usesInlineEntityPanel ? 3 : 0
    }

    #if compiler(>=6.4)
    @available(iOS 27.1, *)
    private static func nativeVaultCenter(in view: UIView, window: UIWindow) -> CGFloat? {
        guard !view.isHidden, view.alpha > 0.01 else { return nil }

        // Native tabs have no public frame API. Use the system's accessible tab
        // controls and verify they form the three-item vertical rail.
        let controls = view.subviews.compactMap { $0 as? UIControl }.filter {
            $0.isAccessibilityElement && !$0.isHidden && $0.alpha > 0.01
        }
        if controls.count >= EntityHomeTab.allCases.count {
            let frames = EntityHomeTab.allCases.compactMap { tab in
                controls.first { $0.accessibilityLabel == tab.rawValue }
                    .map { $0.convert($0.bounds, to: window) }
            }
            if frames.count == EntityHomeTab.allCases.count,
               frames.allSatisfy({ !$0.isEmpty && window.bounds.intersects($0) }),
               zip(frames, frames.dropFirst()).allSatisfy({ upper, lower in
                   abs(upper.midX - lower.midX) <= 1 && upper.midY < lower.midY
               }) {
                return frames.last?.midY
            }
        }
        for child in view.subviews {
            if let center = nativeVaultCenter(in: child, window: window) { return center }
        }
        return nil
    }
    #endif

    private var bottomBarRow: some View {
        let geminiFirst = duoLayout.placesSplitControlsOnLeadingEdge(in: layoutDirection)
        let usesGlassControls = isDuoDevice || duoLayout.usesPhoneAndPadGlassNavigation
        return HStack(alignment: usesGlassControls ? .center : .bottom, spacing: 10) {
            if !usesGlassControls { profileControlButton }
            if isDuoDevice && geminiFirst { geminiControlButton }

            searchControlButton

            if usesGlassControls && !geminiFirst { geminiControlButton }

            if !usesGlassControls {
                entitiesControlMenu
                if canAddInActiveTab {
                    plusControlMenu.buttonStyle(.plain)
                } else {
                    readOnlyControl
                }
            }
        }
    }

    private var searchControlButton: some View {
        MiloomFooterButton(borderShape: .capsule) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            vm.showSearch = true
            searchBounce += 1
        } label: {
            Label("Search", systemImage: "magnifyingglass")
                .frame(maxWidth: .infinity, alignment: .leading)
        } legacyLabel: {
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
    private var companyHeaderVerticalPadding: CGFloat { duoLayout.usesStackedLayout ? 4 : 12 }

    private let companyHeaderTopInset: CGFloat = 8

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
                // Company name and shortcuts for layouts without the report toolbar
                HStack(alignment: .center) {
                    Text(company.name.isEmpty ? "Company" : company.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(duoLayout.isDuoDevice ? 0.78 : 1)

                    Spacer(minLength: 8)

                    if !duoLayout.usesPhoneAndPadGlassNavigation && !usesDuoPortraitLayout && !duoLayout.usesNativeSideToolbarGroups {
                        if vm.activeTab == .financial && !usesInlineEntityPanel && !duoLayout.usesStackedLayout {
                            transactionHeaderButton
                        }
                        headerActionMenu
                    }
                }

                if !duoLayout.isDuoDevice {
                    metricSubLine
                }
            }
        }
        .padding(.vertical, companyHeaderVerticalPadding)
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .background {
            if !duoLayout.isDuoDevice {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.zifrBG)
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.zifrTabBarFill.opacity(0.70))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            if !duoLayout.isDuoDevice {
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
            }
        }
        .shadow(color: duoLayout.isDuoDevice ? .clear : .black.opacity(0.45), radius: 6, x: 0, y: 3)
    }

    private var transactionHeaderButton: some View {
        Button(action: openAllTransactions) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.70))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("All transactions")
    }

    private func openAllTransactions() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showTransactionCenter = true
    }

    private var phoneReportsMenu: some View {
        Menu {
            Button(action: openAllTransactions) {
                Label("All transactions", systemImage: "list.bullet.rectangle.portrait")
            }
            reportMenuItems
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "receipt")
                    .accessibilityHidden(true)
                Text("Reports")
            }
            .font(.subheadline.weight(.semibold))
        }
        .accessibilityHint("Choose a report or view transactions")
    }

    private var duoToolbarReportsMenu: some View {
        Menu {
            if duoLayout.usesClosedStyleLayout || duoLayout.usesPhoneAndPadGlassNavigation {
                Button(action: openAllTransactions) {
                    Label("All transactions", systemImage: "list.bullet.rectangle.portrait")
                }
            } else if duoLayout.usesStackedPortraitLayout {
                stackedCashFlowReportButton
            }
            reportMenuItems
        } label: {
            DuoEntityToolbarLabel(title: "Entity reports", icon: "receipt")
        }
        .accessibilityLabel("Entity reports")
        .accessibilityHint(duoLayout.usesClosedStyleLayout || duoLayout.usesStackedPortraitLayout
                           ? "Choose a report or view transactions" : "Choose a report")
    }

    private var headerActionMenu: some View {
        Menu {
            if !isDuoDevice { sharingMenuItems }
            if duoLayout.usesStackedLayout {
                stackedCashFlowReportButton
            }
            reportMenuItems
        } label: { headerReportIcon }
        .accessibilityLabel(isDuoDevice ? "Entity reports" : "Entity actions")
        .accessibilityHint(!isDuoDevice && canManageSharing ? "Sharing scopes and reports" : "Entity reports")
    }

    private var stackedCashFlowReportButton: some View {
        Button {
            showEntityCashFlow = true
        } label: {
            Label("Cash Flow & Transactions", systemImage: "list.bullet.rectangle.portrait")
        }
    }

    private var reportMenuItems: some View {
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
            DuoEntityToolbarLabel(title: "Share access", icon: "square.and.arrow.up")
        }
        .disabled(!canManageSharing)
        .accessibilityLabel("Share access")
        .accessibilityHint(canManageSharing ? "Choose which entity records to share" : "You do not have permission to manage sharing")
    }

    private func openAdminSettings() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        vm.path.append(AppViewModel.AppRoute.adminSettings)
    }

    private var duoProfileControl: some View {
        Button(action: openAdminSettings) {
            DuoEntityToolbarLabel(title: "Admin settings", icon: "person.crop.circle")
        }
    }

    private var profileControlButton: some View {
        Button(action: openAdminSettings) {
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
        MiloomEntitySwitcher(vm: vm, selectedCompanyID: company.id, usesSystemToolbar: isDuoDevice || duoLayout.usesPhoneAndPadGlassNavigation,
                            companyTitle: phoneSection == nil ? nil : company.name,
                            isPhoneCommandCenter: phoneSection != nil,
                            onOpenAdmin: duoLayout.usesPadSideNavigation || phoneSection != nil ? openAdminSettings : nil) {
            onShowAllEntities()
            if phoneSection == nil { dismiss() }
            if isDuoDevice || duoLayout.usesPadSideNavigation { duoLayout.dashboardRequest &+= 1 }
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

    @ViewBuilder
    private var plusButtonLabel: some View {
        if isDuoDevice || duoLayout.usesPhoneAndPadGlassNavigation {
            DuoEntityToolbarLabel(title: "Add item", icon: "plus")
        } else {
            circularControlLabel {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
        }
    }

    private var geminiControlButton: some View {
        MiloomFooterButton(borderShape: .circle) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showAssistant = true
        } label: {
            Label("Open Gemini Live", systemImage: "sparkle")
                .labelStyle(.iconOnly)
        } legacyLabel: {
            circularControlLabel { MiloomGeminiSparkle() }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
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

    private var phoneAddResources: [AddResource] {
        let resources: [AddResource]
        switch phoneSection {
        case .financial: resources = [.institution, .card, .loan]
        case .subscriptions: resources = [.subscription]
        case .documents: resources = [.document]
        case nil: resources = []
        }
        return resources.filter { canCreate($0.rawValue) }
    }

    @available(iOS 26.0, *)
    private var phoneAddControl: some View {
        let resources = phoneAddResources
        let isOwner = appState.portfolioUserID == company.userId
        let active = phoneSection.map { vm.phoneTab == .section($0) } == true && vm.path.isEmpty
        let command: PhoneAddControlSource.Command? = if !active || resources.isEmpty {
            nil
        } else if phoneSection == .financial {
            .menu(resources.map { $0.title(isOwner: isOwner) })
        } else {
            .action
        }
        return PhoneAddControlSource(referenceView: $phoneAddReferenceView, command: command) { button in
            UIMenu(children: resources.map { resource in
                UIAction(title: resource.title(isOwner: isOwner),
                         image: UIImage(systemName: resource.icon)) { [weak button] _ in
                    button?.selectedAction = { add(resource) }
                }
            })
        } performAction: {
            if let resource = resources.first { add(resource) }
        }
    }

    @available(iOS 26.0, *)
    private func openPhoneAdd() {
        guard !phoneAddResources.isEmpty else {
            showPhoneAddUnavailable = true
            return
        }
        guard let anchor = phoneAddReferenceView as? PhoneAddControlAnchor else { return }
        anchor.placeButton()
        // VoiceOver can still activate the native tab beneath the direct touch target.
        DispatchQueue.main.async {
            anchor.button.performPrimaryAction()
        }
    }

    private func addService() {
        guard canCreate("subscription") else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        newSub = Subscription(userId: company.userId, companyId: company.id)
    }

    private func addDocument() {
        guard canCreate("document") else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        newDoc = CompanyDocument(userId: company.userId, companyId: company.id)
    }

    private func add(_ resource: AddResource) {
        guard canCreate(resource.rawValue) else { return }
        switch resource {
        case .institution:
            let draft = Institution(userId: company.userId, companyId: company.id)
            if appState.portfolioUserID == company.userId {
                wizardInstitution = draft
            } else {
                // Bank linking and its multi-resource wizard remain owner-only.
                newManualInstitution = draft
            }
        case .card:
            newCard = vm.addCard(appState: appState, userId: company.userId, companyId: company.id)
        case .loan:
            newLoan = vm.addLoan(appState: appState, userId: company.userId, companyId: company.id)
        case .subscription:
            addService()
        case .document:
            addDocument()
        }
    }

    private var financialAddChoices: some View {
        let resources: [AddResource] = [.loan, .card, .institution]
        return ForEach(resources.filter { canCreate($0.rawValue) }) { resource in
            Button { add(resource) } label: {
                Label(resource.title(isOwner: appState.portfolioUserID == company.userId),
                      systemImage: resource.icon)
            }
        }
    }

    @ViewBuilder
    private var plusControlMenu: some View {
        switch vm.activeTab {
        case .financial:
            Menu {
                financialAddChoices
            } label: {
                plusButtonLabel
            }
            .accessibilityLabel("Add financial item")

        case .subscriptions:
            Button(action: addService) {
                plusButtonLabel
            }
            .accessibilityLabel("Add service")

        case .documents:
            Button(action: addDocument) {
                plusButtonLabel
            }
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
            if duoLayout.usesPhoneAndPadGlassNavigation {
                return "Tap Financial, Services, or Vault to switch sections for this entity."
            }
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
