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
    @Environment(AppState.self) private var appState
    @FocusState private var searchFocused: Bool
    @State private var visiblePasswords: Set<UUID> = []
    @State private var isThinking = false
    @State private var aiResponse: String? = nil
    
    enum SearchScope { case global, company }
    @State private var searchScope: SearchScope = .global

    var results: [AppViewModel.SearchResult] {
        let allResults = vm.globalSearch(
            query: vm.searchQuery,
            companies: companies,
            subscriptions: subscriptions,
            cards: cards,
            institutions: institutions,
            loans: loans,
            documents: documents
        )
        
        if searchScope == .company, let selectedId = vm.selectedCompany?.id {
            return allResults.filter { $0.companyId == selectedId }
        }
        
        return allResults
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
                
                if !vm.path.isEmpty, let company = vm.selectedCompany {
                    Picker("Search Scope", selection: $searchScope) {
                        Text("Across Companies").tag(SearchScope.global)
                        Text("Across \(company.name)").tag(SearchScope.company)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }

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
                                    aiResponse = await vm.askGeminiSearch(query: vm.searchQuery, appState: appState)
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
                                let companyResults = results.filter { $0.type == .company }
                                let subResults = results.filter { $0.type == .subscription }
                                let finResults = results.filter { $0.type == .financial }
                                let docResults = results.filter { $0.type == .document }
                                
                                if !companyResults.isEmpty {
                                    searchSection(title: "ENTITIES", items: companyResults)
                                }
                                if !subResults.isEmpty {
                                    searchSection(title: "SERVICES", items: subResults)
                                }
                                if !finResults.isEmpty {
                                    searchSection(title: "FINANCIALS", items: finResults)
                                }
                                if !docResults.isEmpty {
                                    searchSection(title: "DOCUMENTS", items: docResults)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                    .scrollIndicators(.hidden)
                    .scrollDismissesKeyboard(.immediately)
                }
            }
            .background(Color.zifrBG)
            .navigationTitle(!vm.path.isEmpty && vm.selectedCompany != nil ? "Search \(vm.selectedCompany!.name.uppercased())" : "Search")
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
        .onAppear {
            searchFocused = true
            
            // Apply DESIGN.md colors to segmented picker
            UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(Color(hex: "#1c1c1e"))
            UISegmentedControl.appearance().backgroundColor = UIColor(Color(hex: "#111111"))
            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor(white: 1, alpha: 0.5)], for: .normal)
        }
    }



    @ViewBuilder
    private func searchSection(title: String, items: [AppViewModel.SearchResult]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .heavy))
                .tracking(1)
                .foregroundStyle(Color.white.opacity(0.4))
                .padding(.horizontal, 16)
                .padding(.top, 12)
            
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, result in
                    searchResultRow(result)
                    
                    if index < items.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 1)
                            .padding(.leading, 64)
                    }
                }
            }
            .glassCard(cornerRadius: 16)
        }
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func searchResultRow(_ result: AppViewModel.SearchResult) -> some View {
        Button {
            navigate(to: result)
        } label: {
            HStack(spacing: 14) {
                if let web = result.externalWebsite, !web.isEmpty {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.clear)
                            .frame(width: 38, height: 38)
                        FaviconImage(website: web, size: 24)
                    }
                } else if let logoData = result.logoData, let uiImage = UIImage(data: logoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 38, height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    ZStack {
                        Color.clear
                            .frame(width: 38, height: 38)
                        Image(systemName: resultIcon(result))
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(resultColor(result))
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(result.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            
                        if result.type == .subscription {
                            if let isFree = result.isFree, isFree {
                                Text("FREE")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.4))
                            } else if let cost = result.cost {
                                Text(String(format: "$%.2f/mo.", cost))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.4))
                            }
                        }
                            
                        if result.type == .financial {
                            if let cType = result.cardType {
                                Text(cType.uppercased())
                                    .font(.system(size: 11, weight: .semibold))
                                    .tracking(0.3)
                                    .foregroundStyle(Color.white.opacity(0.4))
                            }
                            
                            if let net = result.network, let l4 = result.last4, !net.isEmpty, !l4.isEmpty {
                                Text("·").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.2))
                                Text(net == "Amex" ? "••• \(l4)" : "•••• \(l4)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.4))
                            }
                        }
                    }
                    
                    if result.type == .financial, let paysFor = result.paysFor, !paysFor.isEmpty {
                        Text("PAYS FOR: \(paysFor.joined(separator: ", "))".uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(0.3)
                            .foregroundStyle(Color.white.opacity(0.45))
                            .lineLimit(1)
                    }
                    
                    if let loginId = result.loginId, !loginId.isEmpty {
                        Text("LOGIN: \(loginId)")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(0.3)
                            .foregroundStyle(Color.white.opacity(0.4))
                            .lineLimit(1)
                    }
                    
                    if let pwd = result.password, !pwd.isEmpty {
                        Text("PASSWORD: ••••••••")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(0.3)
                            .foregroundStyle(Color.white.opacity(0.4))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                
                if !result.subtitle.isEmpty {
                    let formattedSubtitle: String = {
                        let parts = result.subtitle.split(separator: " ", maxSplits: 1)
                        if parts.count >= 2 {
                            return "\(parts[0])\n\(parts[1])".uppercased()
                        }
                        return result.subtitle.uppercased()
                    }()
                    
                    Text(formattedSubtitle)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.3)
                        .foregroundStyle(Color(hex: "#223e5a"))
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.2))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let pwd = result.password, !pwd.isEmpty {
                Button {
                    UIPasteboard.general.string = pwd
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    Task { await DataRepository.shared.logSecurityEvent(title: "Password Copied", message: "A password for '\(result.title)' was copied to your clipboard.") }
                } label: {
                    Label("Copy Password", systemImage: "key.fill")
                }
            }
            if let loginId = result.loginId, !loginId.isEmpty {
                Button {
                    UIPasteboard.general.string = loginId
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Label("Copy Login ID", systemImage: "person.crop.circle")
                }
            }
            if let l4 = result.last4, !l4.isEmpty {
                Button {
                    UIPasteboard.general.string = l4
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Label("Copy Last 4", systemImage: "creditcard.fill")
                }
            }
            
            if (result.loginId != nil && !result.loginId!.isEmpty) || (result.password != nil && !result.password!.isEmpty) {
                let shareText = [
                    (result.loginId != nil && !result.loginId!.isEmpty) ? "Login: \(result.loginId!)" : nil,
                    (result.password != nil && !result.password!.isEmpty) ? "Password: \(result.password!)" : nil
                ].compactMap { $0 }.joined(separator: "\n")
                
                ShareLink(item: shareText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private func navigate(to result: AppViewModel.SearchResult) {
        if let company = companies.first(where: { $0.id == result.companyId }) {
            vm.selectedCompany = company
            vm.activeTab = (result.type == .company) ? .home : result.tab
            vm.deepLinkModelId = result.modelId
            vm.path.append(company)
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
