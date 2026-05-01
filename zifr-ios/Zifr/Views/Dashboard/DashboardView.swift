import SwiftUI
struct DashboardView: View {
    @Environment(AppState.self) private var appState
    private var companies: [Company] { appState.companies.sorted { $0.lastViewed > $1.lastViewed } }
    private var subscriptions: [Subscription] { appState.subscriptions }
    private var cards: [FinancialCard] { appState.cards }
    private var institutions: [Institution] { appState.institutions }
    private var loans: [Loan] { appState.loans }
    private var documents: [CompanyDocument] { appState.documents }

    @Bindable var vm: AppViewModel
    @State private var showAddCompany = false
    @State private var showSharedWithMe = false
    @State private var editingCompany: Company? = nil
    @State private var companyToDelete: Company? = nil

    @State private var dummyCompany = Company(
        userId: UUID(),
        name: "Acme Holdings LLC",
        structure: "LLC"
    )

    var body: some View {
        NavigationStack(path: $vm.path) {
            List {
                // Header Group
                VStack(spacing: 0) {
                    headerSection
                        .padding(.top, 8)
                        .padding(.bottom, 40)

                    HStack(spacing: 8) {
                        Spacer()
                        
                        // Share Button
                        Menu {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                // Future cloudkit sharing
                            } label: {
                                Label("Entire Portfolio", systemImage: "folder.badge.person.crop")
                            }
                            Divider()
                            ForEach(companies) { company in
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    // Future cloudkit sharing for company
                                } label: {
                                    Label(company.name.isEmpty ? "Entity" : company.name, systemImage: "building.2")
                                }
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.gray)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                        }
                        
                        // Add Button
                        Button {
                            showAddCompany = true
                        } label: {
                            HStack(spacing: 6) {
                                Text("ADD ENTITY").font(.system(size: 12, weight: .semibold)).tracking(1).foregroundStyle(Color(hex: "#A2A2A2"))
                                Image(systemName: "plus").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.white.opacity(0.4))
                            }
                            .padding(.horizontal, 20)
                            .frame(height: 36)
                            .background(Color(hex: "#171717"))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                        }
                    }
                    .padding(.bottom, 16)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))

                // Company cards
                ForEach(filteredCompanies) { company in
                    companyCardRow(for: company)
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        vm.selectedCompany = company
                        vm.activeTab = .home
                        vm.touchCompany(company, appState: appState)
                        vm.path.append(company)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 16, trailing: 20))
                    .swipeActions(edge: .leading) {
                        Button {
                            editingCompany = company
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(Color.indigo)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            companyToDelete = company
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.red)
                    }
                }

                // Add company button
                Group {
                    if companies.isEmpty {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showAddCompany = true
                        } label: {
                            ZStack {
                                CompanyCardView(
                                    company: dummyCompany,
                                    cardsCount: 0,
                                    institutionsCount: 0,
                                    loansCount: 0,
                                    subscriptionsCount: 0,
                                    docsCount: 0,
                                    onEdit: {},
                                    onViewSubscriptions: {},
                                    onViewFinancials: {},
                                    onViewDocuments: {}
                                )
                                .allowsHitTesting(false)
                                .blur(radius: 3)
                                .opacity(0.8)

                                VStack(spacing: 16) {
                                    Image(systemName: "plus.app.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(.white)
                                    Text("+ CREATE YOUR FIRST ENTITY")
                                        .font(.system(size: 11, weight: .black))
                                        .textCase(.uppercase)
                                        .tracking(2)
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: hasOrphanedRecords ? 16 : 120, trailing: 20))

                if hasOrphanedRecords {
                    sharedWithMeRow
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .scrollIndicators(.hidden)
            .confirmationDialog(
                "Delete Company",
                isPresented: Binding(get: { companyToDelete != nil }, set: { if !$0 { companyToDelete = nil } }),
                titleVisibility: .visible,
                presenting: companyToDelete
            ) { company in
                Button("Delete \(company.name)", role: .destructive) {
                    withAnimation {
                        vm.deleteCompany(company, appState: appState)
                    }
                    companyToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    companyToDelete = nil
                }
            } message: { company in
                Text("This will permanently delete \(company.name) and all associated data. This action cannot be undone.")
            }
            .navigationDestination(for: Company.self) { company in
                CompanyDetailView(company: company, vm: vm)
            }
            .navigationDestination(isPresented: $showSharedWithMe) {
                SharedWithMeView(vm: vm)
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
            .safeAreaInset(edge: .bottom) {
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
                    .liquidGlass(cornerRadius: 22)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
    }

    private var filteredCompanies: [Company] {
        guard !vm.searchQuery.isEmpty else { return companies }
        let q = vm.searchQuery.lowercased()
        return companies.filter { $0.name.lowercased().contains(q) || $0.structure.lowercased().contains(q) }
    }

    @ViewBuilder
    private var sharedWithMeRow: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showSharedWithMe = true
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Color(hex: "#3b82f6")
                    Image(systemName: "tray.full.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Shared with Me")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Incoming items and inbox")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.2))
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 120, trailing: 20))
    }

    private var hasOrphanedRecords: Bool {
        let hasSubs = subscriptions.contains(where: { sub in !companies.contains(where: { $0.id == sub.companyId }) })
        let hasCards = cards.contains(where: { card in !companies.contains(where: { $0.id == card.companyId }) })
        let hasInsts = institutions.contains(where: { inst in !companies.contains(where: { $0.id == inst.companyId }) })
        let hasLoans = loans.contains(where: { loan in !companies.contains(where: { $0.id == loan.companyId }) })
        let hasDocs = documents.contains(where: { doc in !companies.contains(where: { $0.id == doc.companyId }) })
        return hasSubs || hasCards || hasInsts || hasLoans || hasDocs
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            if let uiImage = UIImage(named: "logo.png") {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 50)
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
        let cCount = cards.filter { $0.companyId == company.id }.count
        let iCount = institutions.filter { $0.companyId == company.id }.count
        let lCount = loans.filter { $0.companyId == company.id }.count
        let sCount = subscriptions.filter { $0.companyId == company.id }.count
        let dCount = documents.filter { $0.companyId == company.id }.count

        CompanyCardView(
            company: company,
            cardsCount: cCount,
            institutionsCount: iCount,
            loansCount: lCount,
            subscriptionsCount: sCount,
            docsCount: dCount,
            onEdit: { editingCompany = company },
            onViewSubscriptions: {
                vm.selectedCompany = company
                vm.activeTab = .subscriptions
                vm.touchCompany(company, appState: appState)
                vm.path.append(company)
            },
            onViewFinancials: {
                vm.selectedCompany = company
                vm.activeTab = .financial
                vm.touchCompany(company, appState: appState)
                vm.path.append(company)
            },
            onViewDocuments: {
                vm.selectedCompany = company
                vm.activeTab = .documents
                vm.touchCompany(company, appState: appState)
                vm.path.append(company)
            }
        )
    }
}


// MARK: - Shared With Me View
import SwiftUI
struct SharedWithMeView: View {
    @Bindable var vm: AppViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private var allCompanies: [Company] { appState.companies.sorted { $0.name < $1.name } }
    private var allSubscriptions: [Subscription] { appState.subscriptions }
    private var allCards: [FinancialCard] { appState.cards }
    private var allInstitutions: [Institution] { appState.institutions }
    private var allLoans: [Loan] { appState.loans }
    private var allDocuments: [CompanyDocument] { appState.documents }

    var subscriptions: [Subscription] { allSubscriptions.filter { sub in !allCompanies.contains(where: { $0.id == sub.companyId }) } }
    var cards: [FinancialCard] { allCards.filter { card in !allCompanies.contains(where: { $0.id == card.companyId }) } }
    var institutions: [Institution] { allInstitutions.filter { inst in !allCompanies.contains(where: { $0.id == inst.companyId }) } }
    var loans: [Loan] { allLoans.filter { loan in !allCompanies.contains(where: { $0.id == loan.companyId }) } }
    var documents: [CompanyDocument] { allDocuments.filter { doc in !allCompanies.contains(where: { $0.id == doc.companyId }) } }

    let sharedCompany = Company(id: UUID(), userId: UUID(), name: "Shared with Me", structure: "Inbox", colorHex: "#3b82f6", website: "")

    @State private var showCommandCenter = false
    @State private var showEditCompany = false
    @State private var dragOffset: CGFloat = 0
    @State private var swipeHandled = false
    
    @State private var tabBounces: [AppViewModel.CompanyTab: Int] = [:]
    @State private var searchBounce: Int = 0

    
    private var currentTabIndex: Int {
        AppViewModel.CompanyTab.allCases.firstIndex(of: vm.activeTab) ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── CiFr-style company header ────────────────────────────────
            companyHeader
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
                
            // ── Content ──────────────────────────────────────────────────
            ZStack(alignment: .top) {
                switch vm.activeTab {
                case .subscriptions, .home:
                    SubscriptionListView(company: sharedCompany, subscriptions: subscriptions, institutions: institutions, cards: cards, vm: vm)
                case .financial:
                    FinancialView(company: sharedCompany, cards: cards, institutions: institutions, loans: loans, vm: vm)
                case .documents:
                    DocumentListView(company: sharedCompany, documents: documents, vm: vm)
                }
                
                if showCommandCenter {
                    EntityHomeView(
                        company: sharedCompany,
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
                    .background(Color.black)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .zIndex(1)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 30, coordinateSpace: .local)
                            .onEnded { value in
                                let transY = value.translation.height
                                let predictedY = value.predictedEndTranslation.height
                                // Hard swipe up
                                if transY < -50 && predictedY < -400 {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showCommandCenter = false }
                                }
                            }
                    )
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showCommandCenter)
        }
        .background(Color.black)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditCompany) {
            // Disabled editing for Shared with Me
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider().background(Color.white.opacity(0.1))
                HStack {
                    HStack(spacing: 20) { // Grouping left utilities
                        // Menu Button
                        Menu {
                            Button {
                                dismiss()
                            } label: {
                                Label("Dashboard", systemImage: "square.grid.2x2")
                            }
                            Button {
                                // admin coming soon
                            } label: {
                                Label("Settings", systemImage: "gearshape")
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
                    }

                    Spacer()

                    // Tab Controls (Pages icons) aligned to the right
                    HStack(spacing: 28) { // Distributed equally
                        ForEach(AppViewModel.CompanyTab.allCases.filter { $0 != .home }, id: \.self) { tab in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                vm.activeTab = tab
                                showCommandCenter = false
                                tabBounces[tab, default: 0] += 1
                            } label: {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 20, weight: vm.activeTab == tab ? .semibold : .medium))
                                    .foregroundStyle(vm.activeTab == tab ? tabColor(tab) : .secondary)
                                    .symbolEffect(.bounce, value: tabBounces[tab, default: 0])
                                    .frame(width: 32, height: 44)
                            }
                        }
                    }
                    .padding(.trailing, 12)
                }
                .padding(.horizontal, 20)
                .frame(height: 49) // Standard HIG TabBar Height
            }
            .background(Color.black)
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
                            // Swipe Left to Right
                            if showCommandCenter {
                                dismiss()
                            } else if vm.activeTab == .subscriptions {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showCommandCenter = true }
                            } else if vm.activeTab == .financial {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { vm.activeTab = .subscriptions }
                            } else if vm.activeTab == .documents {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { vm.activeTab = .financial }
                            }
                        } else {
                            // Swipe Right to Left (Go Forward)
                            if showCommandCenter {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showCommandCenter = false }
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

    // MARK: - Company Header (mirrors CiFr's CompanyHeader.tsx)
    private var companyHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            // Logo tile
            CompanyAvatar(company: sharedCompany, size: 48)

            VStack(alignment: .leading, spacing: 3) {
                Button {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    showCommandCenter.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Text(sharedCompany.name)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                            .rotationEffect(.degrees(showCommandCenter ? 90 : 0))
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showCommandCenter)
                    }
                }
                .buttonStyle(.plain)

                // Dynamic metrics sub-line per tab
                metricSubLine
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var metricSubLine: some View {
        switch vm.activeTab {
        case .subscriptions, .home:
            let active = subscriptions.filter { $0.status == "Active" }
            let moTotal = active.reduce(0.0) { $0 + $1.monthlyTotal }
            let yrTotal = active.reduce(0.0) { $0 + $1.yearlyTotal }
            let moCount = active.filter { $0.billingCycle == "Monthly" }.count
            let yrCount = active.filter { $0.billingCycle == "Yearly" }.count

            HStack(spacing: 4) {
                Text("💵🔥 ")
                    .font(.system(size: 17))
                metricPair(label: "mo.", value: moTotal, count: moCount)
                Divider()
                    .frame(width: 1, height: 12)
                    .background(Color.white.opacity(0.1))
                    .padding(.horizontal, 10)
                metricPair(label: "yr.", value: yrTotal, count: yrCount)
            }

        case .financial:
            let creditCards = cards.filter { $0.type == "Credit" }
            let totalDebt = loans.filter { $0.role == "Bank Loan" }.reduce(0.0) { $0 + $1.remainingBalance } + creditCards.reduce(0.0) { $0 + $1.balance }
            let totalCredit = creditCards.reduce(0.0) { $0 + $1.limit }

            HStack(spacing: 10) {
                financialMetricPair(emoji: "💸", label: "Debt", value: totalDebt)
                financialMetricPair(emoji: "💰", label: "Credit", value: totalCredit)
            }

        case .documents:
            HStack(spacing: 8) {
                Text("📑")
                    .font(.system(size: 17))
                Text("Document Vault")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
    }

    private func metricPair(label: String, value: Double, count: Int) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.5))
            Text("$\(String(format: "%.0f", value))")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("(\(count))")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.5))
        }
    }

    private func emojiCount(_ emoji: String, _ n: Int) -> some View {
        HStack(spacing: 6) {
            Text(emoji).font(.system(size: 17))
            Text("(\(n))")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.5))
        }
    }

    private func financialMetricPair(emoji: String, label: String, value: Double) -> some View {
        HStack(spacing: 4) {
            Text(emoji).font(.system(size: 17))
            HStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
                Text("$\(String(format: "%.0f", value))")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }



    private func tabColor(_ tab: AppViewModel.CompanyTab) -> Color {
        switch tab {
        case .home:          return Color.white.opacity(0.85)
        case .subscriptions: return Color(hex: "#2070BD")
        case .financial:     return Color(hex: "#1A7077")
        case .documents:     return Color(hex: "#918457")
        }
    }

}
