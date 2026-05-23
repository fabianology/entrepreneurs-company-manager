import SwiftUI
struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthViewModel.self) private var authViewModel
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
    @State private var companyToShare: Company? = nil
    @State private var showAssistant = false    
    
    private var currentUserId: UUID? { authViewModel.currentUser?.id }
    
    // Shared companies
    private var sharedCompanies: [Company] {
        guard let currentUserId = currentUserId else { return [] }
        return appState.companies.filter { $0.userId != currentUserId }
    }

    @State private var dummyCompany = Company(
        userId: UUID(),
        name: "Acme Holdings LLC",
        structure: "LLC"
    )

    var body: some View {
        NavigationStack(path: $vm.path) {
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()
                
                AnimatedHeaderBackground()
                    .ignoresSafeArea(edges: .top)

                List {
                // Header Group
                VStack(spacing: 0) {
                    headerSection
                        .padding(.top, 8)
                        .padding(.bottom, 40)

                    HStack(spacing: 0) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.grid.2x2.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color(hex: "#A2A2A2"))
                            Text("Dashboard")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(hex: "#A2A2A2"))
                        }
                        .padding(.leading, 16)

                        Spacer()

                        // Share Button
                        Menu {
                            ForEach(companies) { company in
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    companyToShare = company
                                } label: {
                                    Label("Share \(company.name.isEmpty ? "Entity" : company.name)", systemImage: "person.crop.circle.badge.plus")
                                }
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color(hex: "#A2A2A2"))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }

                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 1, height: 20)

                        // Add Button
                        Button {
                            showAddCompany = true
                        } label: {
                            HStack(spacing: 6) {
                                Text("ADD ENTITY").font(.system(size: 13, weight: .bold)).tracking(1).foregroundStyle(.white)
                                Image(systemName: "plus").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.white.opacity(0.5))
                            }
                            .frame(width: 164, height: 44)
                            .contentShape(Rectangle())
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "#1C1C1E").opacity(0.70))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
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
                                    institutionsCount: 0,
                                    subscriptionsCount: 0,
                                    docsCount: 0,
                                    onEdit: {}
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
            .background(Color.clear)
            .scrollIndicators(.hidden)
            .refreshable {
                await DataRepository.shared.fetchAllData(appState: appState)
            }
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
            .navigationDestination(for: AppViewModel.AppRoute.self) { route in
                if route == .adminSettings {
                    AdminSettingsView(vm: vm)
                }
            }
            .navigationDestination(isPresented: $showSharedWithMe) {
                if let uid = currentUserId {
                    SharedWithMeView(vm: vm, currentUserId: uid)
                }
            }
            .sheet(item: $companyToShare) { company in
                ShareEntitySheet(resourceId: company.id, resourceType: "company", resourceTitle: company.name)
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
            .fullScreenCover(isPresented: $showAssistant) {
                AssistantOnboardingView(vm: vm)
                    .environment(appState)
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        vm.path.append(AppViewModel.AppRoute.adminSettings)
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                            .background(Color(hex: "#1C1C1E"))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)

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
                        .background(Color(hex: "#1C1C1E"))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showAssistant = true
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(hex: "#5AC8FA"), Color(hex: "#0A84FF")]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: Color(hex: "#0A84FF").opacity(0.6), radius: 8, x: 0, y: 0)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            } // End ZStack
        }
    }

    private var filteredCompanies: [Company] {
        let baseList = companies
        
        guard !vm.searchQuery.isEmpty else { return baseList }
        let q = vm.searchQuery.lowercased()
        return baseList.filter { $0.name.lowercased().contains(q) || $0.structure.lowercased().contains(q) }
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
                    .background(
                        Ellipse()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 180, height: 80)
                            .blur(radius: 24)
                    )
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
        let iCount = institutions.filter { $0.companyId == company.id }.count
        let sCount = subscriptions.filter { $0.companyId == company.id }.count
        let dCount = documents.filter { $0.companyId == company.id }.count
        
        let isSharedWithMe = (company.userId != currentUserId)
        let isSharedByMe = (company.userId == currentUserId) && appState.resourceShares.contains(where: { $0.resourceId == company.id })
        let role = appState.resourceShares.first(where: { $0.resourceId == company.id })?.role ?? "Viewer"

        CompanyCardView(
            company: company,
            institutionsCount: iCount,
            subscriptionsCount: sCount,
            docsCount: dCount,
            onEdit: { editingCompany = company }
        )
        .overlay(alignment: .topTrailing) {
            if isSharedWithMe || isSharedByMe {
                HStack(spacing: 4) {
                    Image(systemName: isSharedWithMe ? "person.2.fill" : "person.crop.circle.badge.checkmark")
                    Text(isSharedWithMe ? "Shared with you (\(role))" : "You are sharing")
                }
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSharedWithMe ? Color(hex: "#4f46e5") : Color(hex: "#059669"))
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .offset(x: -16, y: 16)
            }
        }
    }
}


// MARK: - Shared With Me View
import SwiftUI
struct SharedWithMeView: View {
    @Bindable var vm: AppViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    let currentUserId: UUID
    
    // Grouped data structure
    struct SharedItem: Identifiable {
        let id: UUID
        let title: String
        let type: String
        let role: String
        let createdAt: Date
    }
    
    struct SenderGroup: Identifiable {
        let id: String // sender email
        let displayName: String?
        var items: [SharedItem]
    }
    
    private var senderGroups: [SenderGroup] {
        var groups = [String: SenderGroup]()
        
        let localCompanyIds = Set(appState.companies.map { $0.id })
        
        // Helper to process items
        func process<T: Identifiable>(items: [T], type: String, titleKeyPath: KeyPath<T, String>, companyIdKeyPath: KeyPath<T, UUID>) {
            for item in items {
                let cid = item[keyPath: companyIdKeyPath]
                if !localCompanyIds.contains(cid) {
                    // It's orphaned! Look up its share record
                    let share = appState.resourceShares.first { $0.resourceId == (item.id as! UUID) || $0.resourceId == cid }
                    let role = share?.role ?? "Viewer"
                    let sEmail = share?.senderEmail ?? "Unknown Sender"
                    let sName = share?.senderDisplayName
                    let createdAt = share?.createdAt ?? Date()
                    
                    let sharedItem = SharedItem(id: item.id as! UUID, title: item[keyPath: titleKeyPath], type: type, role: role, createdAt: createdAt)
                    
                    if groups[sEmail] != nil {
                        groups[sEmail]!.items.append(sharedItem)
                    } else {
                        groups[sEmail] = SenderGroup(id: sEmail, displayName: sName, items: [sharedItem])
                    }
                }
            }
        }
        
        process(items: appState.subscriptions, type: "Subscription", titleKeyPath: \.name, companyIdKeyPath: \.companyId)
        process(items: appState.cards, type: "Card", titleKeyPath: \.name, companyIdKeyPath: \.companyId)
        process(items: appState.institutions, type: "Institution", titleKeyPath: \.name, companyIdKeyPath: \.companyId)
        process(items: appState.loans, type: "Loan", titleKeyPath: \.name, companyIdKeyPath: \.companyId)
        process(items: appState.documents, type: "Document", titleKeyPath: \.name, companyIdKeyPath: \.companyId)
        
        return Array(groups.values).sorted { ($0.displayName ?? $0.id) < ($1.displayName ?? $1.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        if senderGroups.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "tray")
                                    .font(.system(size: 48))
                                    .foregroundStyle(Color.white.opacity(0.3))
                                Text("No shared items")
                                    .font(.headline)
                                    .foregroundStyle(Color.white.opacity(0.6))
                            }
                            .padding(.top, 100)
                        } else {
                            ForEach(senderGroups) { group in
                                MiloomFolderView(group: group)
                            }
                        }
                    }
                    .padding(20)
                }
                .refreshable {
                    await DataRepository.shared.fetchAllData(appState: appState)
                }
            }
            .navigationTitle("Shared Inbox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct MiloomFolderView: View {
    let group: SharedWithMeView.SenderGroup
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "#4f46e5").opacity(0.2))
                            .frame(width: 48, height: 48)
                        Image(systemName: "folder.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color(hex: "#4f46e5"))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.displayName ?? group.id)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                        if group.displayName != nil {
                            Text(group.id)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                    }
                    
                    Spacer()
                    
                    Text("\(group.items.count)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .padding(.trailing, 8)
                        
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(16)
                .background(Color(hex: "#1C1C1E"))
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(spacing: 0) {
                    Divider().background(Color.white.opacity(0.1))
                    ForEach(group.items) { item in
                        HStack(spacing: 12) {
                            Image(systemName: iconFor(item.type))
                                .font(.system(size: 16))
                                .foregroundStyle(Color.white.opacity(0.5))
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text(item.type)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.white.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(item.role)
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(hex: "#4f46e5").opacity(0.3))
                                    .foregroundStyle(Color(hex: "#818cf8"))
                                    .clipShape(Capsule())
                                
                                Text(item.createdAt, style: .date)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.white.opacity(0.4))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        
                        if item.id != group.items.last?.id {
                            Divider().background(Color.white.opacity(0.05)).padding(.leading, 52)
                        }
                    }
                }
                .background(Color(hex: "#151516"))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    
    private func iconFor(_ type: String) -> String {
        switch type {
        case "Subscription": return "repeat.circle"
        case "Card": return "creditcard"
        case "Institution": return "building.columns"
        case "Loan": return "dollarsign.circle"
        case "Document": return "doc.text"
        default: return "doc"
        }
    }
}
