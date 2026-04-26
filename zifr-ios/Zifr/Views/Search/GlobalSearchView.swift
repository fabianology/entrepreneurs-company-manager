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
    @State private var visiblePasswords: Set<UUID> = []
    @State private var isThinking = false
    @State private var aiResponse: String? = nil

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
                        .foregroundStyle(.secondary)
                    TextField("Search companies, services, cards...", text: $vm.searchQuery)
                        .focused($searchFocused)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                        .autocorrectionDisabled()
                    if !vm.searchQuery.isEmpty {
                        Button { vm.searchQuery = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
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
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            
                            // MARK: - Gemini Trigger
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                Task {
                                    isThinking = true
                                    aiResponse = await vm.askGeminiSearch(query: vm.searchQuery, companies: companies, subscriptions: subscriptions, cards: cards)
                                    isThinking = false
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Text("✨").font(.system(size: 16))
                                    Text("Ask Gemini:")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.zifrGold)
                                    Text("\"\(vm.searchQuery)\"")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.2))
                                }
                                .padding(14)
                                .glassCard(cornerRadius: 16)
                            }
                            .buttonStyle(.plain)
                            
                            // MARK: - Gemini Response
                            if isThinking {
                                HStack {
                                    Spacer()
                                    Text("✨ Gemini is analyzing...")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                    Spacer()
                                }
                                .padding(20)
                                .glassCard(cornerRadius: 16)
                            } else if let response = aiResponse {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("✨")
                                        Text("Gemini Insights")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(Color.zifrGold)
                                        Spacer()
                                    }
                                    Text(.init(response))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white)
                                        .tint(.blue)
                                }
                                .padding(16)
                                .glassCard(cornerRadius: 16)
                            }
                            
                            if results.isEmpty {
                                VStack(spacing: 12) {
                                    Text("No local results for")
                                        .font(.system(size: 14)).foregroundStyle(Color.white.opacity(0.3))
                                    Text("\"\(vm.searchQuery)\"")
                                        .font(.system(size: 18, weight: .black)).foregroundStyle(.white)
                                }
                                .padding(.top, 40)
                            } else {
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
                                                    .lineLimit(1)
                                                if !result.subtitle.isEmpty {
                                                    Text(result.subtitle)
                                                        .font(.system(size: 11, weight: .medium))
                                                        .foregroundStyle(Color.white.opacity(0.4))
                                                        .lineLimit(1)
                                                }
                                                if let loginId = result.loginId, !loginId.isEmpty {
                                                    Text(loginId)
                                                        .font(.system(size: 10, weight: .medium))
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(1)
                                                }
                                            }
                                            Spacer(minLength: 8)
                                            
                                            if let pwd = result.password, !pwd.isEmpty {
                                                HStack(spacing: 4) {
                                                    Button {
                                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                        if visiblePasswords.contains(result.id) {
                                                            visiblePasswords.remove(result.id)
                                                        } else {
                                                            visiblePasswords.insert(result.id)
                                                        }
                                                    } label: {
                                                        Image(systemName: visiblePasswords.contains(result.id) ? "eye.slash" : "eye")
                                                            .font(.system(size: 16))
                                                            .foregroundStyle(.secondary)
                                                    }
                                                    .frame(width: 36, height: 36)
                                                    .background(Color.white.opacity(0.05))
                                                    .clipShape(Circle())
                                                    
                                                    if visiblePasswords.contains(result.id) {
                                                        Text(pwd)
                                                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                                            .foregroundStyle(.white)
                                                            .padding(.horizontal, 8)
                                                        
                                                        Button {
                                                            UIPasteboard.general.string = pwd
                                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                        } label: {
                                                            Image(systemName: "doc.on.doc")
                                                                .font(.system(size: 14))
                                                                .foregroundStyle(.secondary)
                                                        }
                                                        .frame(width: 36, height: 36)
                                                        .background(Color.white.opacity(0.05))
                                                        .clipShape(Circle())
                                                    }
                                                }
                                            } else {
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundStyle(Color.white.opacity(0.2))
                                            }
                                        }
                                        .padding(14)
                                        .glassCard(cornerRadius: 16)
                                    }
                                    .buttonStyle(.plain)
                                }
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
            .onChange(of: vm.searchQuery) { _, _ in
                isThinking = false
                aiResponse = nil
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
