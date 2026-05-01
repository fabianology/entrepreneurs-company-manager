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
        .background(Color.black)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditCompany) {
            EditCompanySheet(vm: vm, company: company)
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
                                    // admin coming soon
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
                        ForEach(AppViewModel.CompanyTab.allCases, id: \.self) { tab in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                vm.activeTab = tab
                                tabBounces[tab, default: 0] += 1
                            } label: {
                                if tab == .financial {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 20, weight: vm.activeTab == tab ? .semibold : .medium))
                                        .foregroundStyle(vm.activeTab == tab ? tabColor(tab) : .secondary)
                                        .symbolEffect(.bounce.up.byLayer, options: .nonRepeating, value: tabBounces[tab, default: 0])
                                        .frame(width: 32, height: 44)
                                } else if tab == .home {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 20, weight: vm.activeTab == tab ? .semibold : .medium))
                                        .foregroundStyle(vm.activeTab == tab ? .white : .secondary)
                                        .symbolEffect(.bounce, value: tabBounces[tab, default: 0])
                                        .frame(width: 32, height: 44)
                                } else {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 20, weight: vm.activeTab == tab ? .semibold : .medium))
                                        .foregroundStyle(vm.activeTab == tab ? tabColor(tab) : .secondary)
                                        .symbolEffect(.bounce, value: tabBounces[tab, default: 0])
                                        .frame(width: 32, height: 44)
                                }
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
                            // Swipe Left to Right (Go Back)
                            if vm.activeTab == .home {
                                dismiss()
                            } else if vm.activeTab == .subscriptions {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { vm.activeTab = .home }
                            } else if vm.activeTab == .financial {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { vm.activeTab = .subscriptions }
                            } else if vm.activeTab == .documents {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { vm.activeTab = .financial }
                            }
                        } else {
                            // Swipe Right to Left (Go Forward)
                            if vm.activeTab == .home {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { vm.activeTab = .subscriptions }
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
            // Logo tile — 48×48 rounded-12 (matches CiFr exactly)
            CompanyAvatar(company: company, size: 48)

            VStack(alignment: .leading, spacing: 3) {
                // Company name — 28pt bold, matches CiFr
                Text(company.name.isEmpty ? "Company" : company.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                // Dynamic metrics sub-line per tab
                metricSubLine
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var metricSubLine: some View {
        switch vm.activeTab {
        case .home:
            Text("COMMAND CENTER")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.6))
                .tracking(2)

        case .subscriptions:
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
