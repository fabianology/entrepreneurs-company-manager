import SwiftUI
import SwiftData

struct CompanyDetailView: View {
    let company: Company
    @Bindable var vm: AppViewModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showEditCompany = true } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showEditCompany) {
            EditCompanySheet(vm: vm, company: company)
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 8) {
                // Menu Button (just dismisses back to dashboard for now)
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    dismiss()
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "#1C1C1E").opacity(0.85))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
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
                    .background(Color(hex: "#1C1C1E").opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.15), lineWidth: 1))
                }
                .buttonStyle(.plain)

                // Tab Bar
                cifrTabBar
                    .frame(width: 180)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
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
    private var cifrTabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppViewModel.CompanyTab.allCases, id: \.self) { tab in
                Button {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        vm.activeTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 15, weight: vm.activeTab == tab ? .semibold : .regular))
                            .foregroundStyle(vm.activeTab == tab ? tabColor(tab) : Color.white.opacity(0.4))
                    }
                    .frame(width: 60)
                    .frame(height: 36)
                    .background(
                        Group {
                            if vm.activeTab == tab {
                                // Glass pill on active
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.white.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                                    )
                            }
                        }
                    )
                }
            }
        }
        .frame(width: 180, height: 44)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(hex: "#1C1C1E").opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private func tabColor(_ tab: AppViewModel.CompanyTab) -> Color {
        switch tab {
        case .subscriptions: return Color(hex: "#60A5FA")
        case .financial:     return Color(hex: "#22c55e")
        case .documents:     return Color(hex: "#FBBF24")
        }
    }
}
