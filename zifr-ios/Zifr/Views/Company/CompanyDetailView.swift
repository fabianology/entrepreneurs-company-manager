import SwiftUI
import SwiftData

struct CompanyDetailView: View {
    @State var company: Company
    @Bindable var vm: AppViewModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Company.name) private var allCompanies: [Company]
    @Query private var allSubscriptions: [Subscription]
    @Query private var allCards: [FinancialCard]
    @Query private var allInstitutions: [Institution]
    @Query private var allLoans: [Loan]
    @Query private var allDocuments: [CompanyDocument]

    var subscriptions: [Subscription] { allSubscriptions.filter { $0.companyId == company.id } }
    var cards: [FinancialCard] { allCards.filter { $0.companyId == company.id } }
    var institutions: [Institution] { allInstitutions.filter { $0.companyId == company.id } }
    var loans: [Loan] { allLoans.filter { $0.companyId == company.id } }
    var documents: [CompanyDocument] { allDocuments.filter { $0.companyId == company.id } }

    @State private var showEditCompany = false
    @State private var swipeHandled = false
    @State private var showMenu = false

    var body: some View {
        VStack(spacing: 0) {
            // ── CiFr-style company header ────────────────────────────────
            companyHeader
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)

            // ── Content ──────────────────────────────────────────────────
            Group {
                switch vm.activeTab {
                case .subscriptions:
                    SubscriptionListView(company: company, subscriptions: subscriptions, institutions: institutions, vm: vm)
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
        .overlay {
            if showMenu {
                Color.black.opacity(0.001)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showMenu = false }
                    }
            }
        }
        .overlay(alignment: .bottomLeading) {
            if showMenu {
                quickMenuPopover
                    .padding(.leading, 20)
                    .padding(.bottom, 72)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottomLeading)))
            }
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 8) {
                // Menu Button
                Button {
                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.prepare()
                    gen.impactOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { gen.impactOccurred() }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { gen.impactOccurred() }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showMenu.toggle()
                    }
                } label: {
                    Image(systemName: showMenu ? "xmark" : "line.3.horizontal")
                        .font(.system(size: showMenu ? 16 : 20, weight: showMenu ? .bold : .regular))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(showMenu ? Color.white.opacity(0.25) : Color.clear)
                        .clipShape(Circle())
                        .liquidGlass(cornerRadius: 22)
                }
                .buttonStyle(.plain)

                // Search Bar
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    vm.showSearch = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.white.opacity(0.4))
                        Text("Search")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.white.opacity(0.5))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .liquidGlass(cornerRadius: 22)
                }
                .buttonStyle(.plain)

                // Inline Tab Navigator
                HStack(spacing: 0) {
                    ForEach(AppViewModel.CompanyTab.allCases, id: \.self) { tab in
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                vm.activeTab = tab
                            }
                        } label: {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14, weight: vm.activeTab == tab ? .bold : .medium))
                                .foregroundStyle(vm.activeTab == tab ? .white : Color.white.opacity(0.4))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(alignment: .leading) {
                    // Sliding indicator pill
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .offset(x: CGFloat(AppViewModel.CompanyTab.allCases.firstIndex(of: vm.activeTab) ?? 0) * 44.0)
                }
                .liquidGlass(cornerRadius: 22)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
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
                            // Swipe Left to Right (Go Back / Dismiss)
                            if vm.activeTab == .subscriptions {
                                dismiss()
                            } else if vm.activeTab == .financial {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { vm.activeTab = .subscriptions }
                            } else if vm.activeTab == .documents {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { vm.activeTab = .financial }
                            }
                        } else {
                            // Swipe Right to Left (Go Forward)
                            if vm.activeTab == .subscriptions {
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
        case .subscriptions:
            // 💵🔥 mo. $X (n) | yr. $X (n) — mirrors CiFr
            let monthlyActive = subscriptions.filter { $0.status == "Active" && $0.billingCycle == "Monthly" }
            let yearlyActive = subscriptions.filter { $0.status == "Active" && $0.billingCycle == "Yearly" }
            let moTotal = monthlyActive.reduce(0.0) { $0 + $1.cost } + yearlyActive.reduce(0.0) { $0 + $1.cost / 12 }
            let yrTotal = monthlyActive.reduce(0.0) { $0 + $1.cost * 12 } + yearlyActive.reduce(0.0) { $0 + $1.cost }

            HStack(spacing: 0) {
                Text("💵🔥 ")
                    .font(.system(size: 13))
                metricPair(label: "mo.", value: moTotal, count: monthlyActive.count)
                Divider()
                    .frame(width: 1, height: 12)
                    .background(Color.white.opacity(0.1))
                    .padding(.horizontal, 10)
                metricPair(label: "yr.", value: yrTotal, count: yearlyActive.count)
            }

        case .financial:
            HStack(spacing: 14) {
                emojiCount("🏦", institutions.count)
                emojiCount("💳", cards.count)
                emojiCount("📑", loans.count)
            }

        case .documents:
            HStack(spacing: 6) {
                Text("📑")
                    .font(.system(size: 13))
                Text("Document Vault")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
        }
    }

    private func metricPair(label: String, value: Double, count: Int) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.4))
            Text("$\(String(format: "%.0f", value))")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            Text("(\(count))")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.4))
        }
    }

    private func emojiCount(_ emoji: String, _ n: Int) -> some View {
        HStack(spacing: 5) {
            Text(emoji).font(.system(size: 13))
            Text("(\(n))")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.4))
        }
    }

    // MARK: - CiFr-style Tab Pill Bar

    // MARK: - Quick Menu Popover
    private var quickMenuPopover: some View {
        VStack(spacing: 0) {
            // Dashboard row
            HStack(spacing: 6) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showMenu = false }
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.white.opacity(0.65))
                        Text("Dashboard")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.85))
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    // admin coming soon
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .frame(width: 42, height: 42)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 6)

            // Companies List
            if !allCompanies.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Jump to Company")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .padding(.top, 4)

                    ForEach(allCompanies) { c in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                company = c
                                vm.touchCompany(c, context: context)
                                showMenu = false
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Text(c.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.7))
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(c.id == company.id ? Color.white.opacity(0.08) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(8)
        .frame(width: 240)
        .background(Color(red: 17/255, green: 17/255, blue: 17/255).opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.6), radius: 24, x: 0, y: 0)
    }
}
