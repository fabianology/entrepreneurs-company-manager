import SwiftUI

struct GlobalSearchView: View {
    @Bindable var vm: AppViewModel
    let companies: [Company]
    let subscriptions: [Subscription]
    let cards: [FinancialCard]
    let institutions: [Institution]
    let loans: [Loan]
    let documents: [CompanyDocument]

    @Environment(\.dismiss) private var dismiss
    @FocusState private var searchFocused: Bool

    var results: [AppViewModel.SearchResult] {
        vm.globalSearch(
            query: vm.searchQuery,
            companies: companies,
            subscriptions: subscriptions,
            cards: cards,
            institutions: institutions,
            loans: loans,
            documents: documents
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.4))
                    TextField("Search companies, services, cards...", text: $vm.searchQuery)
                        .focused($searchFocused)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .autocorrectionDisabled()
                    if !vm.searchQuery.isEmpty {
                        Button { vm.searchQuery = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.white.opacity(0.3))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .liquidGlass(cornerRadius: 14)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                if vm.searchQuery.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.white.opacity(0.1))
                        Text("Search Everything")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Color.white.opacity(0.3))
                        Text("Companies, services, cards, loans, documents")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.2))
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else if results.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Text("No results for")
                            .font(.system(size: 14)).foregroundStyle(Color.white.opacity(0.3))
                        Text("\"\(vm.searchQuery)\"")
                            .font(.system(size: 18, weight: .black)).foregroundStyle(.white)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(results) { result in
                                Button {
                                    navigate(to: result)
                                } label: {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(resultColor(result).opacity(0.15))
                                                .frame(width: 38, height: 38)
                                            Image(systemName: resultIcon(result))
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(resultColor(result))
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(result.title)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(.white)
                                            if !result.subtitle.isEmpty {
                                                Text(result.subtitle)
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundStyle(Color.white.opacity(0.4))
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Color.white.opacity(0.2))
                                    }
                                    .padding(14)
                                    .glassCard(cornerRadius: 16)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .background(Color.zifrBG)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        vm.searchQuery = ""
                        dismiss()
                    }
                    .foregroundStyle(Color.white.opacity(0.5))
                }
            }
        }
        .onAppear { searchFocused = true }
    }

    private func navigate(to result: AppViewModel.SearchResult) {
        if let company = companies.first(where: { $0.id == result.companyId }) {
            vm.selectedCompany = company
            vm.activeTab = result.tab
        }
        vm.searchQuery = ""
        dismiss()
    }

    private func resultIcon(_ r: AppViewModel.SearchResult) -> String {
        switch r.type {
        case .company: return "building.2"
        case .subscription: return "app.badge"
        case .financial: return "creditcard"
        case .document: return "doc.text"
        }
    }

    private func resultColor(_ r: AppViewModel.SearchResult) -> Color {
        switch r.type {
        case .company: return .white
        case .subscription: return .zifrGreen
        case .financial: return .zifrGold
        case .document: return .zifrBlue
        }
    }
}
