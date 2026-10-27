import SwiftUI

@Observable
final class MiloomDuoLayoutState {
    var isDuoDevice = false
    var isExpanded = false
    var isLandscape = false
    var dashboardRequest = 0
}

struct RootView: View {
    @Environment(AppState.self) private var appState
    @State private var vm: AppViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var compactColumn: NavigationSplitViewColumn = .detail
    @State private var duoLayout = MiloomDuoLayoutState()

    init(vm: AppViewModel = AppViewModel()) {
        _vm = State(initialValue: vm)
    }

    private var splitViewVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { columnVisibility },
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
            .environment(duoLayout)
            .background {
                Color.clear.modifier(MiloomDuoLayoutObserver(layout: duoLayout))
            }
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
        .onChange(of: vm.path.isEmpty, initial: true) { _, isDashboard in
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
private struct MiloomDuoLayoutObserver: ViewModifier {
    let layout: MiloomDuoLayoutState

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) {
            content
                .onHingeChange { _, context in
                    let isDuo = context.hinge != nil
                    let expanded = context.hinge.map { $0.status != .closed } ?? false
                    if layout.isDuoDevice != isDuo { layout.isDuoDevice = isDuo }
                    if layout.isExpanded != expanded { layout.isExpanded = expanded }
                }
                .onGeometryChange(for: Bool.self) { $0.size.width >= $0.size.height } action: {
                    if layout.isLandscape != $0 { layout.isLandscape = $0 }
                }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

#if DEBUG && targetEnvironment(simulator) && MILOOM_LAYOUT_PREVIEW
    enum MiloomLayoutPreviewData {
        static let ownerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
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
            state.cards = [
                FinancialCard(
                    userId: owner, companyId: studio.id, name: "Studio Card",
                    last4: "4242", limit: 12000, balance: 2400, moPayment: 120
                )
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
