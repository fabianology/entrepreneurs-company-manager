import SwiftUI

@Observable
final class MiloomDuoLayoutState {
    var isDuoDevice = false
    var isExpanded = false
    var isPartiallyOpen = false
    var dashboardRequest = 0
    var windowSize: CGSize = .zero
    enum SplitPane { case other, left, stacked }
    var splitPane: SplitPane = .other

    var usesStackedLayout: Bool {
        isDuoDevice && isExpanded && splitPane == .stacked
    }

    var usesLeftSplitToolbar: Bool {
        isDuoDevice && isExpanded && splitPane == .left
    }

    func placesSplitControlsOnLeadingEdge(in direction: LayoutDirection) -> Bool {
        usesLeftSplitToolbar && direction == .leftToRight
    }

    static func occupiesLeftSplitPane(window: CGRect, display: CGRect) -> Bool {
        let tolerance: CGFloat = 2
        return !window.isEmpty && !display.isEmpty
            && abs(window.minX - display.minX) <= tolerance
            && abs(window.minY - display.minY) <= tolerance
            && abs(window.maxY - display.maxY) <= tolerance
            && window.maxX < display.maxX - tolerance
    }

    static func splitPane(window: CGRect, display: CGRect, prefersLeftBar: Bool) -> SplitPane {
        // Use scene bounds, so keyboard and toolbar safe areas cannot turn a
        // full-screen window into a stacked pane. Allow the divider on either edge.
        let tolerance: CGFloat = 2
        if !window.isEmpty && !display.isEmpty,
           abs(window.minX - display.minX) <= tolerance,
           abs(window.maxX - display.maxX) <= tolerance,
           window.height < display.height - tolerance,
           abs(window.minY - display.minY) <= tolerance || abs(window.maxY - display.maxY) <= tolerance {
            return .stacked
        }
        return prefersLeftBar && occupiesLeftSplitPane(window: window, display: display) ? .left : .other
    }

    private var hasRoomForExpandedLayout: Bool {
        // Full Duo layouts keep space for two panes or the portrait filing
        // controls. Measure the app window so either side of Split View can
        // use the closed layout even while the hinge is open.
        isDuoDevice && isExpanded && !usesStackedLayout && windowSize.width >= 600
    }

    var usesCompactLayout: Bool {
        isDuoDevice && !hasRoomForExpandedLayout
    }

    var usesExpandedPortrait: Bool {
        hasRoomForExpandedLayout && windowSize.height > windowSize.width
    }

    var usesExpandedLandscape: Bool {
        hasRoomForExpandedLayout && windowSize.width >= windowSize.height
    }
}

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(MiloomDuoLayoutState.self) private var duoLayout
    @State private var vm: AppViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var compactColumn: NavigationSplitViewColumn = .detail

    init(vm: AppViewModel = AppViewModel()) {
        _vm = State(initialValue: vm)
    }

    private var splitViewVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(
            // The first layout can run before SwiftUI delivers the hinge
            // context or calls onChange. Keep the dashboard full-width immediately.
            get: { vm.path.isEmpty ? .detailOnly : columnVisibility },
            set: { visibility in
                // The portfolio already lists every entity. Do not let a sidebar
                // toggle or reveal gesture replace it with the same list again.
                guard !vm.path.isEmpty else { return }
                columnVisibility = visibility
            }
        )
    }

    var body: some View {
        rootSurface
    }

    @ViewBuilder
    private var rootSurface: some View {
        if duoLayout.isDuoDevice {
            // Duo uses the entity menu and section tabs instead of a duplicate
            // navigation column. Device identity stays stable across a fold,
            // keeping this single stack, its sheets and form state mounted.
            DashboardView(vm: vm)
                .tint(.white)
                .onChange(of: duoLayout.dashboardRequest) { _, _ in
                    vm.path = NavigationPath()
                }
        } else {
            legacySplitSurface
        }
    }

    private var legacySplitSurface: some View {
        NavigationSplitView(
            columnVisibility: splitViewVisibility,
            preferredCompactColumn: $compactColumn
        ) {
            entitySidebar
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 320)
        } detail: {
            DashboardView(vm: vm)
        }
        .navigationSplitViewStyle(.balanced)
        .tint(.white)
        .onChange(of: vm.path.isEmpty) { _, isDashboard in
            compactColumn = .detail
            columnVisibility = isDashboard ? .detailOnly : .all
        }
        .onChange(of: duoLayout.dashboardRequest) { _, _ in
            // Compact split navigation can already have emptied the bound path
            // while its entity destination remains visible. Reconcile both hosts.
            vm.path = NavigationPath()
            columnVisibility = .detailOnly
            compactColumn = .detail
        }
    }

    private var entitySidebar: some View {
        List {
            Section {
                Button {
                    vm.path = NavigationPath()
                    compactColumn = .detail
                } label: {
                    Label("All Entities", systemImage: "square.grid.2x2")
                        .foregroundStyle(.white)
                        .padding(.vertical, 4)
                }
                .listRowBackground(Color.white.opacity(0.02))
                .listRowSeparator(.hidden)
            }

            Section("Entities") {
                ForEach(appState.companies.sorted { $0.lastViewed > $1.lastViewed }) { company in
                    Button {
                        open(company)
                    } label: {
                        HStack(spacing: 12) {
                            CompanyAvatar(company: company, size: 36)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(company.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text(company.structure)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer(minLength: 0)
                            if isSelected(company) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundStyle(Color.zifrGold)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.white.opacity(isSelected(company) ? 0.08 : 0.02))
                    .accessibilityAddTraits(isSelected(company) ? .isSelected : [])
                    .listRowSeparator(.hidden)
                }
            }

            if let company = vm.selectedCompany, !vm.path.isEmpty {
                Section(company.name) {
                    ForEach(EntityHomeTab.allCases, id: \.self) { tab in
                        Button {
                            if vm.path != NavigationPath([company]) {
                                vm.path = NavigationPath([company])
                            }
                            vm.activeTab = tab
                            compactColumn = .detail
                        } label: {
                            Label(tab.rawValue, systemImage: tab.icon)
                                .foregroundStyle(vm.activeTab == tab ? Color.zifrGold : .white.opacity(0.65))
                                .padding(.vertical, 4)
                        }
                        .accessibilityAddTraits(vm.activeTab == tab ? .isSelected : [])
                        .listRowBackground(Color.white.opacity(0.02))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color.zifrBG)
        .navigationTitle("MILOOM")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(removing: vm.path.isEmpty ? .sidebarToggle : nil)
    }

    private func isSelected(_ company: Company) -> Bool {
        guard let selected = vm.selectedCompany else { return false }
        return selected.id == company.id && vm.path == NavigationPath([selected])
    }

    private func open(_ company: Company) {
        if !isSelected(company) {
            if vm.selectedCompany?.id != company.id {
                vm.activeTab = .financial
            }
            vm.selectedCompany = company
            vm.touchCompany(company, appState: appState)
            // Sidebar selection replaces the detail instead of stacking entities.
            vm.path = NavigationPath([company])
        }
        compactColumn = .detail
    }
}

/// Observe the whole window, not an entity's potentially narrow detail column.
struct MiloomDuoWindow: ViewModifier {
    @State private var layout = MiloomDuoLayoutState()

    func body(content: Content) -> some View {
        let isDuoDevice = layout.isDuoDevice
        content
            .environment(layout)
            .transformEnvironment(\.verticalScrollIndicatorVisibility) { visibility in
                if isDuoDevice { visibility = .never }
            }
            .background { layoutObservation }
    }

    @ViewBuilder
    private var layoutObservation: some View {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) {
            Color.clear
                .onHingeChange { _, context in
                    // A missing hinge context can be temporary during a scene
                    // transition. Keep the detected device and its last known pose.
                    guard let hinge = context.hinge else { return }

                    let expanded = hinge.status != .closed
                    let partial = hinge.status == .partiallyOpen
                    if !layout.isDuoDevice { layout.isDuoDevice = true }
                    if layout.isExpanded != expanded { layout.isExpanded = expanded }
                    if layout.isPartiallyOpen != partial { layout.isPartiallyOpen = partial }
                    if !expanded { layout.splitPane = .other }
                }
                .background {
                    if layout.isDuoDevice && layout.isExpanded {
                        DuoSplitPaneReader { pane in
                            if layout.isExpanded && layout.splitPane != pane {
                                layout.splitPane = pane
                            }
                        }
                    }
                }
                .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                    if layout.windowSize != size { layout.windowSize = size }
                }
        }
        #endif
    }
}

#if compiler(>=6.4)
@available(iOS 27.1, *)
private struct DuoSplitPaneReader: UIViewRepresentable {
    @Environment(\.toolbarVerticalEdge) private var toolbarEdge
    @Environment(\.layoutDirection) private var layoutDirection
    let onChange: (MiloomDuoLayoutState.SplitPane) -> Void

    func makeUIView(context: Context) -> SceneView {
        let view = SceneView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: SceneView, context: Context) {
        let left: HorizontalEdge = layoutDirection == .leftToRight ? .leading : .trailing
        view.prefersLeftBar = toolbarEdge == left
        view.onChange = onChange
        view.scheduleReport()
    }

    final class SceneView: UIView {
        var prefersLeftBar = false
        var onChange: (MiloomDuoLayoutState.SplitPane) -> Void = { _ in }
        private var reportedValue: MiloomDuoLayoutState.SplitPane?
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
                guard let window, let screen = window.windowScene?.screen else { return }
                let displaySpace = screen.coordinateSpace
                let frame = window.convert(window.bounds, to: displaySpace)
                let pane = MiloomDuoLayoutState.splitPane(
                    window: frame, display: displaySpace.bounds, prefersLeftBar: prefersLeftBar
                )
                guard reportedValue != pane else { return }
                reportedValue = pane
                onChange(pane)
            }
        }
    }
}
#endif

#if DEBUG && targetEnvironment(simulator) && MILOOM_LAYOUT_PREVIEW
    import UIKit

    enum MiloomLayoutPreviewData {
        static let ownerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        /// Local, visibly fictional files let the vault preview open a document
        /// without uploading fixtures or asking a server for a signed URL.
        static func documentURL(name: String, type: String, entity: String, index: Int) -> String? {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("miloom-sample-\(index).pdf")
            let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
            let data = renderer.pdfData { context in
                context.beginPage()
                let gold = UIColor(red: 0.76, green: 0.67, blue: 0.47, alpha: 1)
                gold.setFill()
                context.cgContext.fill(CGRect(x: 40, y: 40, width: 532, height: 6))
                ("MILOOM · SAMPLE DOCUMENT" as NSString).draw(
                    in: CGRect(x: 40, y: 70, width: 532, height: 30),
                    withAttributes: [.font: UIFont.boldSystemFont(ofSize: 15), .foregroundColor: gold])
                (name as NSString).draw(in: CGRect(x: 40, y: 128, width: 532, height: 100),
                    withAttributes: [.font: UIFont.boldSystemFont(ofSize: 28), .foregroundColor: UIColor.black])
                let body = "Entity: \(entity)\nCategory: \(type)\n\nThis fictional document is for the MILOOM layout preview.\nIt contains no real account, tax, identity, or legal information.\n\nSample reference: DEMO-\(String(format: "%03d", index))\n\nUse this page to preview document cards and the PDF viewer."
                (body as NSString).draw(in: CGRect(x: 40, y: 252, width: 532, height: 360),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 16), .foregroundColor: UIColor.darkGray])
            }
            do {
                try data.write(to: url, options: .atomic)
                return url.path
            } catch {
                return nil
            }
        }
    }

    // Opt-in QA executable, never a runtime authentication bypass. Normal Debug and
    // every Release build keep ZifrApp as the entry point. No app session loader or
    // push delegate is mounted here. Use only on a fresh, unauthenticated simulator:
    // existing child screens still contain their normal read/refresh actions.
    @main
    struct MiloomLayoutPreviewApp: App {
        @State private var appState: AppState
        @State private var vm: AppViewModel
        @State private var auth = AuthViewModel()
        @State private var onboarding = OnboardingStateManager()
        @State private var access = AccessController()

        init() {
            let owner = MiloomLayoutPreviewData.ownerID
            let studio = Company(userId: owner, name: "Northstar Studio", structure: "LLC", colorHex: "#1A7077")
            let home = Company(userId: owner, name: "Personal", structure: "Individual", colorHex: "#918457")
            let state = AppState()
            // Fixture identity only: no Auth session or production permission bypass.
            state.portfolioUserID = owner
            state.companies = [studio, home]
            let studioCard = FinancialCard(userId: owner, companyId: studio.id,
                name: "Studio Rewards", institutionName: "Northstar Bank", cardHolder: "Northstar Studio",
                last4: "4242", expiry: "08/29", limit: 12000, balance: 2400, moPayment: 120,
                notes: "Fictional preview card")
            let travelCard = FinancialCard(userId: owner, companyId: studio.id,
                name: "Business Travel", institutionName: "Harbor Credit Union", cardHolder: "Northstar Studio",
                last4: "8808", expiry: "11/28", network: "Mastercard", limit: 18000, balance: 865, moPayment: 75,
                notes: "Fictional preview card")
            let standaloneCard = FinancialCard(userId: owner, companyId: studio.id,
                name: "Creative Team Card", last4: "1066", expiry: "06/29", network: "Amex",
                limit: 5000, balance: 320, moPayment: 40, notes: "Fictional standalone card")
            let personalCard = FinancialCard(userId: owner, companyId: home.id,
                name: "Everyday Rewards", institutionName: "Meadow Bank", cardHolder: "Sample Owner",
                last4: "1357", expiry: "03/30", limit: 8000, balance: 485, moPayment: 35,
                notes: "Fictional preview card")
            state.cards = [studioCard, travelCard, standaloneCard, personalCard]
            state.institutions = [
                Institution(userId: owner, companyId: studio.id, name: "Northstar Bank", accounts: [
                    InstitutionAccount(id: "sample-studio-checking", name: "Business Checking", type: "Checking",
                        last4: "1032", balance: 28450, availableBalance: 28120),
                    InstitutionAccount(id: "sample-studio-savings", name: "Tax Reserve", type: "Savings",
                        last4: "2054", balance: 12500, apy: 3.75),
                    InstitutionAccount(name: studioCard.name, type: "Credit Card", last4: "4242",
                        balance: studioCard.balance, network: "Visa", limit: studioCard.limit,
                        linkedCardId: studioCard.id.uuidString)
                ]),
                Institution(userId: owner, companyId: studio.id, name: "Harbor Credit Union", accounts: [
                    InstitutionAccount(id: "sample-studio-reserve", name: "Growth Savings", type: "Savings",
                        last4: "4096", balance: 18750, apy: 4.1),
                    InstitutionAccount(name: travelCard.name, type: "Credit Card", last4: "8808",
                        balance: travelCard.balance, network: "Mastercard", limit: travelCard.limit,
                        linkedCardId: travelCard.id.uuidString)
                ]),
                Institution(userId: owner, companyId: home.id, name: "Meadow Bank", accounts: [
                    InstitutionAccount(id: "sample-personal-checking", name: "Everyday Checking", type: "Checking",
                        last4: "3017", balance: 6420),
                    InstitutionAccount(name: personalCard.name, type: "Credit Card", last4: "1357",
                        balance: personalCard.balance, network: "Visa", limit: personalCard.limit,
                        linkedCardId: personalCard.id.uuidString)
                ])
            ]
            let calendar = Calendar.current
            func renewal(_ days: Int) -> Date { calendar.date(byAdding: .day, value: days, to: Date()) ?? Date() }
            state.subscriptions = [
                Subscription(userId: owner, companyId: studio.id, name: "Studio Cloud", cost: 24,
                    paymentMethod: studioCard.name, paymentMethodId: studioCard.id, nextRenewalAt: renewal(5),
                    subServices: [
                        SubService(name: "Team Storage", paymentMethod: studioCard.name, paymentMethodId: studioCard.id,
                            cost: 12, renewsOn: renewal(5), purpose: "Shared project files", serviceType: .subscription),
                        SubService(name: "Meeting Rooms", paymentMethod: studioCard.name, paymentMethodId: studioCard.id,
                            cost: 8, renewsOn: renewal(5), purpose: "Video collaboration", serviceType: .subscription)
                    ], notes: "Fictional workspace service", serviceType: .subscription),
                Subscription(userId: owner, companyId: studio.id, name: "Creative Suite", cost: 59,
                    paymentMethod: standaloneCard.name, paymentMethodId: standaloneCard.id, nextRenewalAt: renewal(12),
                    subServices: [
                        SubService(name: "Stock Library", paymentMethod: standaloneCard.name, paymentMethodId: standaloneCard.id,
                            cost: 15, renewsOn: renewal(12), purpose: "Design resources", serviceType: .subscription),
                        SubService(name: "Review Portal", paymentMethod: standaloneCard.name, paymentMethodId: standaloneCard.id,
                            cost: 9, renewsOn: renewal(12), purpose: "Client approvals", serviceType: .subscription)
                    ], notes: "Fictional design tools", serviceType: .subscription),
                Subscription(userId: owner, companyId: studio.id, name: "Office Essentials", cost: 89,
                    paymentMethod: travelCard.name, paymentMethodId: travelCard.id, nextRenewalAt: renewal(3),
                    subServices: [
                        SubService(name: "Business Internet", paymentMethod: travelCard.name, paymentMethodId: travelCard.id,
                            cost: 65, renewsOn: renewal(3), purpose: "Studio connection", serviceType: .bill),
                        SubService(name: "Cloud Phone", paymentMethod: travelCard.name, paymentMethodId: travelCard.id,
                            cost: 18, renewsOn: renewal(3), purpose: "Business phone line", serviceType: .bill)
                    ], notes: "Fictional office bills", serviceType: .bill),
                Subscription(userId: owner, companyId: home.id, name: "Home Bundle", cost: 19,
                    paymentMethod: personalCard.name, paymentMethodId: personalCard.id, nextRenewalAt: renewal(8),
                    subServices: [
                        SubService(name: "Music", cost: 11, renewsOn: renewal(8), serviceType: .subscription),
                        SubService(name: "Family Storage", cost: 3, renewsOn: renewal(8), serviceType: .subscription)
                    ], notes: "Fictional personal service", serviceType: .subscription)
            ]
            let documentDate = Date().formatted(.iso8601.year().month().day().dateSeparator(.dash))
            let documentSpecs: [(Company, String, String)] = [
                (studio, "Studio Operating Agreement", "Legal"),
                (studio, "Quarterly Tax Summary", "Taxes"),
                (studio, "Equipment Purchase Receipt", "Receipts"),
                (studio, "Office Lease", "Estate"),
                (home, "Sample Identity Record", "Identity"),
                (home, "Home Inventory", "Other")
            ]
            state.documents = documentSpecs.enumerated().map { index, item in
                CompanyDocument(userId: owner, companyId: item.0.id, name: item.1, type: item.2,
                    url: MiloomLayoutPreviewData.documentURL(name: item.1, type: item.2, entity: item.0.name, index: index + 1),
                    uploadDate: documentDate, notes: "Fictional preview document — sample data only")
            }
            // Optional synthetic report QA data, inside MILOOM_LAYOUT_PREVIEW only.
            // Normal app entry points never read this argument or these fixtures.
            if ProcessInfo.processInfo.arguments.contains("-duoReportFixtures") {
                state.subscriptions += [
                    Subscription(userId: owner, companyId: studio.id, name: "Sample Cloud Workspace",
                        cost: 24, paymentMethod: "Studio Card", paymentMethodId: state.cards[0].id,
                        serviceType: .subscription),
                    Subscription(userId: owner, companyId: studio.id, name: "Sample Annual Insurance",
                        cost: 1200, billingCycle: "Yearly", serviceType: .bill),
                    Subscription(userId: owner, companyId: studio.id, name: "Sample EUR Service",
                        cost: 12, currency: "EUR", serviceType: .subscription)
                ]
            }
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let sampleDate = dateFormatter.string(from: Date())
            func sampleTransaction(companyID: UUID, name: String, amount: Double) -> Transaction {
                var transaction = Transaction()
                transaction.userId = owner
                transaction.companyId = companyID
                transaction.accountId = "sample-\(companyID)"
                transaction.name = name
                transaction.amount = amount
                transaction.date = sampleDate
                return transaction
            }
            state.transactions = [
                sampleTransaction(companyID: studio.id, name: "Sample Studio Income", amount: -2000),
                sampleTransaction(companyID: studio.id, name: "Sample Office Supplies", amount: 80),
                sampleTransaction(companyID: home.id, name: "Sample Personal Purchase", amount: 25)
            ]
            state.hasLoadedPortfolio = true
            let navigation = AppViewModel()
            navigation.selectedCompany = studio
            navigation.path = NavigationPath([studio])
            _appState = State(initialValue: state)
            _vm = State(initialValue: navigation)
        }

        var body: some Scene {
            WindowGroup {
                // A sibling label avoids changing nested navigation safe areas
                // when the dashboard removes its system sidebar toolbar.
                VStack(spacing: 0) {
                    Text("LAYOUT PREVIEW · SAMPLE DATA")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Color.zifrGold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    RootView(vm: vm)
                        .modifier(MiloomDuoWindow())
                }
                    .background(Color.zifrBG)
                    .preferredColorScheme(.dark)
                    .environment(appState)
                    .environment(vm)
                    .environment(auth)
                    .environment(onboarding)
                    .environment(access)
                    .environment(NotificationRouteCoordinator.shared)
                    .onAppear { onboarding.currentStep = .skipped }
            }
        }
    }
#endif
