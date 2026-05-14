import SwiftUI

struct CompanyDetailView: View {
    @State var company: Company
    @Bindable var vm: AppViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

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
                AddFinancialWizard(institution: inst, vm: vm)
            }
        }
        .sheet(item: $newLoan) { l in
            EditLoanSheet(loan: l, vm: vm, isNew: true, institutions: institutions, cards: cards)
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
                    }

                    Spacer()

                    // Tab Controls (Pages icons) aligned to the right
                    HStack(spacing: 28) { // Distributed equally
                        let visibleTabs: [AppViewModel.CompanyTab] = vm.activeTab == .home ? [.home] : [vm.activeTab, .home]
                        ForEach(visibleTabs, id: \.self) { tab in
                            Group {
                                if tab == .home {
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
                                        Image(systemName: tab.icon)
                                            .font(.system(size: 20, weight: vm.activeTab == tab ? .semibold : .medium))
                                            .foregroundStyle(vm.activeTab == tab ? .white : .secondary)
                                            .symbolEffect(.bounce, value: tabBounces[tab, default: 0])
                                            .frame(width: 32, height: 44)
                                    } primaryAction: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            vm.activeTab = tab
                                        }
                                        tabBounces[tab, default: 0] += 1
                                    }
                                    .simultaneousGesture(
                                        LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                                            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                                        }
                                    )
                                } else if tab == .financial {
                                    Menu {
                                        Button {
                                            wizardInstitution = Institution(userId: company.userId, companyId: company.id)
                                            showFinancialWizard = true
                                        } label: {
                                            Label("Add Account", systemImage: "building.columns")
                                        }
                                        if !institutions.isEmpty {
                                            Button {
                                                newCard = vm.addCard(appState: appState, userId: company.userId, companyId: company.id)
                                            } label: {
                                                Label("Add Card", systemImage: "creditcard")
                                            }
                                            Button {
                                                newLoan = vm.addLoan(appState: appState, userId: company.userId, companyId: company.id)
                                            } label: {
                                                Label("Add Loan", systemImage: "dollarsign.circle")
                                            }
                                        }
                                    } label: {
                                        Image(systemName: tab.icon)
                                            .font(.system(size: 20, weight: vm.activeTab == tab ? .semibold : .medium))
                                            .foregroundStyle(vm.activeTab == tab ? tabColor(tab) : .secondary)
                                            .symbolEffect(.bounce.up.byLayer, options: .nonRepeating, value: tabBounces[tab, default: 0])
                                            .frame(width: 32, height: 44)
                                    } primaryAction: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            if vm.activeTab == tab {
                                                vm.activeTab = .documents
                                            } else {
                                                vm.activeTab = tab
                                            }
                                        }
                                        tabBounces[tab, default: 0] += 1
                                    }
                                    .simultaneousGesture(
                                        LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                                            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                                        }
                                    )
                                } else {
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            if vm.activeTab == tab {
                                                if tab == .subscriptions {
                                                    vm.activeTab = .financial
                                                } else if tab == .documents {
                                                    vm.activeTab = .subscriptions
                                                } else {
                                                    vm.activeTab = tab
                                                }
                                            } else {
                                                vm.activeTab = tab
                                            }
                                        }
                                        tabBounces[tab, default: 0] += 1
                                    } label: {
                                        Image(systemName: tab.icon)
                                            .font(.system(size: 20, weight: vm.activeTab == tab ? .semibold : .medium))
                                            .foregroundStyle(vm.activeTab == tab ? tabColor(tab) : .secondary)
                                            .symbolEffect(.bounce, value: tabBounces[tab, default: 0])
                                            .frame(width: 32, height: 44)
                                    }
                                    .simultaneousGesture(
                                        LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                                            if vm.activeTab == tab {
                                                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                                                if tab == .subscriptions {
                                                    newSub = vm.addSubscription(appState: appState, userId: company.userId, companyId: company.id)
                                                } else if tab == .documents {
                                                    newDoc = vm.addDocument(appState: appState, userId: company.userId, companyId: company.id)
                                                }
                                            }
                                        }
                                    )
                                }
                            }
                            .transition(.scale.combined(with: .opacity))
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
}
