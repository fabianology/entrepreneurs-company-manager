import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Company.lastViewed, order: .forward) private var companies: [Company]
    @Query private var subscriptions: [Subscription]
    @Query private var cards: [FinancialCard]
    @Query private var institutions: [Institution]
    @Query private var loans: [Loan]
    @Query private var documents: [CompanyDocument]

    @Bindable var vm: AppViewModel
    @State private var showAddCompany = false
    @State private var editingCompany: Company? = nil
    @State private var companyToDelete: Company? = nil
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List {
                // Header Group
                VStack(spacing: 0) {
                    headerSection
                        .padding(.top, 8)
                        .padding(.bottom, 40)

                    Text("Your Companies")
                        .font(.system(size: 12, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(4)
                        .foregroundStyle(Color.white.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 16)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))

                // Company cards
                ForEach(filteredCompanies) { company in
                    CompanyCardView(
                        company: company,
                        monthlyBurn: vm.monthlyBurn(for: company, subscriptions: subscriptions),
                        onEdit: { editingCompany = company },
                        onViewSubscriptions: {
                            vm.selectedCompany = company
                            vm.activeTab = .subscriptions
                            vm.touchCompany(company, context: context)
                            path.append(company)
                        },
                        onViewFinancials: {
                            vm.selectedCompany = company
                            vm.activeTab = .financial
                            vm.touchCompany(company, context: context)
                            path.append(company)
                        },
                        onViewDocuments: {
                            vm.selectedCompany = company
                            vm.activeTab = .documents
                            vm.touchCompany(company, context: context)
                            path.append(company)
                        }
                    )
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        editingCompany = company
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
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }

                // Add company button
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showAddCompany = true
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 26, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.4))
                        Text("Create New Entity")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                            .foregroundStyle(Color.white.opacity(0.2))
                    )
                }
                .padding(.top, 4)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 120, trailing: 20))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .scrollIndicators(.hidden)
            .navigationDestination(for: Company.self) { company in
                CompanyDetailView(company: company, vm: vm)
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
            .confirmationDialog(
                "Delete Company",
                isPresented: Binding(
                    get: { companyToDelete != nil },
                    set: { isPresented in
                        if !isPresented { companyToDelete = nil }
                    }
                ),
                titleVisibility: .visible
            ) {
                if let companyName = companyToDelete?.name {
                    Button("Delete \(companyName)", role: .destructive) {
                        if let company = companyToDelete {
                            withAnimation {
                                vm.deleteCompany(company, context: context)
                            }
                            companyToDelete = nil
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    companyToDelete = nil
                }
            } message: {
                Text("This will permanently delete this company and all associated data. This action cannot be undone.")
            }
            .overlay(alignment: .bottom) {
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

    private var headerSection: some View {
        VStack(spacing: 12) {
            // "CiFr" style — all-lowercase brand name, big & bold, tight tracking
            Text("Zifr")
                .font(.system(size: 48, weight: .black))
                .foregroundStyle(.white)
                .tracking(-1)

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
}
