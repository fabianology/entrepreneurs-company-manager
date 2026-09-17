import SwiftUI

struct GlobalSearchView: View {
    @Bindable var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(AuthViewModel.self) private var auth
    @Environment(AccessController.self) private var access
    @FocusState private var searchFocused: Bool
    @State private var filters = SearchFilters()
    @State private var response = SearchResponse()
    @State private var searching = false
    @State private var visibleLimit = 40
    @State private var presentation: SheetRoute?
    @State private var related: RelatedSearch?
    @State private var answer: String?
    @State private var answering = false
    @State private var answerError: String?
    @State private var answerTask: Task<Void, Never>?

    private enum SheetRoute: Identifiable {
        case result(SearchPresentation), premium, coverage
        var id: String {
            switch self {
            case .result(let item): return item.id.uuidString
            case .premium: return "premium"
            case .coverage: return "coverage"
            }
        }
    }

    struct RelatedSearch: Hashable {
        var id: String
        var kind: SearchRecord.Kind
        var title: String
    }
    private var taskKey: String { "\(vm.searchQuery)|\(filters)|\(appState.searchRevision)|\(auth.currentUser?.id.uuidString ?? "")|\(String(describing: related))" }

    @State private var searchPresented = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var filterHeight = 44.0

    private var hasQuery: Bool { !vm.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || related != nil }
    private var visibleHits: [SearchHit] { Array(response.hits.prefix(visibleLimit)) }
    private var directHits: [SearchHit] { visibleHits.filter { $0.score != -100 } }
    private var relatedHits: [SearchHit] { visibleHits.filter { $0.score == -100 } }
    private var companyTitle: String {
        filters.companyID.flatMap { id in appState.companies.first { $0.id == id }?.name } ?? "All companies"
    }

    var body: some View {
        NavigationStack {
            searchContent
                .navigationTitle("Search")
                .navigationBarTitleDisplayMode(.inline)
                // Anchor child sheets inside navigation; the outer shell is itself presented.
                // Presenting from that shell stalls the iOS 17 sheet opening transition.
                .sheet(item: $presentation) { route in
                    switch route {
                    case .result(let item):
                        if item.credentials { CredentialSearchSheet(recordIDs: item.recordIDs) }
                        else if let record = item.record { SearchRecordDestinationView(record: record, vm: vm) }
                    case .premium: PremiumUpgradeView(gate: access.pendingGate)
                    case .coverage: coverageSheet
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: { Image(systemName: "xmark") }
                            .accessibilityLabel("Close search")
                    }
                    ToolbarItem(placement: .primaryAction) {
                        if hasQuery && !response.isCredentialRequest {
                            Menu {
                                Button { ask(useGemini: true) } label: { Label("Ask Gemini", systemImage: "sparkles") }
                                if SearchAnswerService.onDeviceAvailable {
                                    Button { ask(useGemini: false) } label: { Label("Ask on device", systemImage: "iphone") }
                                }
                            } label: { Label("Ask", systemImage: "sparkles") }
                            .disabled(searching || answering || !appState.hasLoadedPortfolio)
                            .accessibilityLabel("Ask about these search results")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { endEditing(); presentation = .coverage } label: { Image(systemName: "info.circle") }
                            .accessibilityLabel("Search coverage and document indexing")
                    }
                }
        }
        .modifier(SearchFieldConfiguration(query: $vm.searchQuery, presented: $searchPresented, focus: $searchFocused))
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .onSubmit(of: .search) { endEditing() }
        .tint(Color.zifrGold)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.regularMaterial)
        .task(id: taskKey) { await search() }
        .onAppear { if vm.searchQuery.isEmpty { searchPresented = true; searchFocused = true } }
        .onChange(of: vm.searchQuery) { _, _ in related = nil }
        .onDisappear {
            answerTask?.cancel()
            if presentation == nil { vm.searchQuery = "" }
        }
    }

    private var searchContent: some View {
        resultsList.safeAreaInset(edge: .top, spacing: 0) { filterBar }
    }

    private var resultsList: some View {
        List {
            if !appState.hasLoadedPortfolio {
                ContentUnavailableView("Loading your portfolio", systemImage: "arrow.triangle.2.circlepath",
                    description: Text("Your results will appear when your records are ready."))
                    .listRowBackground(Color.clear)
            } else if !hasQuery {
                suggestions
            } else {
                if let related {
                    Section {
                        Button { self.related = nil } label: {
                            Label("Back to all results", systemImage: "arrow.left")
                                .frame(minHeight: 44, alignment: .leading)
                        }
                        Text(related.title).font(.subheadline).foregroundStyle(.secondary)
                    }.listRowBackground(Color.zifrCard)
                }
                if let issue = appState.portfolioLoadIssue {
                    Label(issue, systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
                        .font(.subheadline).foregroundStyle(.orange)
                        .listRowBackground(Color.zifrCard)
                }
                if !response.totals.isEmpty { totals }
                if answering || answer != nil || answerError != nil { answerSection }
                if searching && response.hits.isEmpty {
                    HStack { Spacer(); ProgressView("Searching…"); Spacer() }
                        .padding(.vertical, 24).listRowBackground(Color.clear)
                } else if response.hits.isEmpty && !searching {
                    ContentUnavailableView {
                        Label("No results for “\(vm.searchQuery)”", systemImage: "magnifyingglass")
                    } description: {
                        Text("Try a name or card ending, or choose fewer filters.")
                    } actions: {
                        if filters != SearchFilters() { Button("Clear filters") { filters = .init() }.frame(minHeight: 44) }
                    }
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                }
                if !directHits.isEmpty {
                    Section {
                        ForEach(directHits) { hit in resultRow(hit) }
                    } header: {
                        resultHeading(related == nil ? "Best matches" : "Results", count: response.hits.filter { $0.score != -100 }.count)
                    }
                }
                if !relatedHits.isEmpty {
                    Section {
                        ForEach(relatedHits) { hit in resultRow(hit) }
                    } header: {
                        resultHeading("Related records", count: response.hits.filter { $0.score == -100 }.count)
                    }
                }
                if response.hits.count > visibleLimit {
                    Button("Show more results (\(response.hits.count - visibleLimit))") { visibleLimit += 40 }
                        .frame(maxWidth: .infinity, minHeight: 44).listRowBackground(Color.zifrCard)
                }
                if !response.interpretation.isEmpty && response.interpretation != "Best matches" {
                    Text(response.interpretation).font(.footnote).foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.zifrCard.opacity(0.65))
        .scrollDismissesKeyboard(.interactively)
    }

    private func resultHeading(_ title: String, count: Int) -> some View {
        HStack {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            if searching { ProgressView().controlSize(.small).accessibilityLabel("Updating results") }
            else { Text(count.formatted()).font(.subheadline).monospacedDigit().foregroundStyle(.secondary).fixedSize() }
        }.textCase(nil).accessibilityElement(children: .combine)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            SearchGlassControls {
                HStack(spacing: 10) {
                    Menu {
                        Picker("Company", selection: $filters.companyID) {
                            Text("All companies").tag(nil as UUID?)
                            ForEach(appState.companies) { company in Text(company.name).tag(Optional(company.id)) }
                        }
                    } label: { SearchFilterLabel(title: companyTitle, icon: "building.2", selected: filters.companyID != nil) }
                    .accessibilityLabel("Company filter").accessibilityValue(companyTitle)
                    Menu {
                        Button { filters.kind = nil; filters.credentialsOnly = false } label: {
                            Label("All types", systemImage: filters.kind == nil && !filters.credentialsOnly ? "checkmark" : "square.grid.2x2")
                        }
                        Button { filters.kind = nil; filters.credentialsOnly = true } label: {
                            Label("Saved logins", systemImage: filters.credentialsOnly ? "checkmark" : "key")
                        }
                        ForEach(SearchRecord.Kind.allCases, id: \.self) { kind in
                            Button { filters.kind = kind; filters.credentialsOnly = false } label: {
                                Label(kind.label, systemImage: filters.kind == kind ? "checkmark" : kind.icon)
                            }
                        }
                    } label: { SearchFilterLabel(title: filters.credentialsOnly ? "Saved logins" : filters.kind?.label ?? "All types", icon: "line.3.horizontal.decrease", selected: filters.kind != nil || filters.credentialsOnly) }
                    .accessibilityLabel("Record type filter")
                    Menu {
                        Picker("Date", selection: $filters.period) {
                            ForEach(SearchFilters.Period.allCases, id: \.self) { period in Text(period.rawValue).tag(period) }
                        }
                    } label: { SearchFilterLabel(title: filters.period.rawValue, icon: "calendar", selected: filters.period != .all) }
                    .accessibilityLabel("Date filter").accessibilityValue(filters.period.rawValue)
                    if filters != SearchFilters() {
                        Button { filters = .init() } label: { SearchFilterLabel(title: "Reset", icon: "arrow.counterclockwise", selected: false, showsChevron: false) }
                    }
                }
            }.buttonStyle(.plain).padding(.horizontal, 20).padding(.vertical, 10)
        }
        .frame(height: filterHeight + 20)
    }

    private var suggestions: some View {
        Group {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your portfolio, at a glance").font(.title2.weight(.semibold))
                    Text("Find a service, check a balance, or look up a saved password.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }.padding(.vertical, 8)
            }.listRowBackground(Color.clear)
            Section {
                suggestion("Balances", subtitle: "Accounts, cards and loans", icon: "creditcard")
                suggestion("Subscriptions", subtitle: "Services and recurring costs", icon: "repeat")
                suggestion("Charges last month", subtitle: "Recent spending", icon: "arrow.left.arrow.right")
                suggestion("Renewals next month", subtitle: "What’s coming up", icon: "calendar")
                suggestion("Passwords", subtitle: "Saved logins, ready to copy", icon: "key")
            } header: { Text("Explore").textCase(nil).font(.subheadline.weight(.semibold)) }
        }
    }

    private func suggestion(_ query: String, subtitle: String, icon: String) -> some View {
        Button { vm.searchQuery = query; endEditing() } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(Color.zifrGold).frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(query).font(.body.weight(.medium)).foregroundStyle(.primary)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.left").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }.padding(.vertical, 4).frame(minHeight: 44)
        }.buttonStyle(.plain).listRowBackground(Color.zifrCard)
    }

    private var totals: some View {
        Section {
            ForEach(response.totals) { total in
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        totalLabel(total)
                        Spacer()
                        Text(total.formatted).font(.title3.weight(.semibold)).monospacedDigit().fixedSize()
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        totalLabel(total)
                        Text(total.formatted).font(.title2.weight(.semibold)).monospacedDigit()
                    }
                }.padding(.vertical, 8).listRowBackground(Color.zifrGold.opacity(0.08))
            }
        } header: { Text("Summary").font(.subheadline.weight(.semibold)).textCase(nil) }
    }
    private func totalLabel(_ total: SearchTotal) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(total.label).font(.subheadline.weight(.medium))
            Text("\(total.sourceIDs.count) records · \(total.currency)").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var answerSection: some View {
        Section {
            if answering { ProgressView("Preparing your answer…").font(.subheadline).padding(.vertical, 8) }
            if let answer { Text(answer).font(.body).textSelection(.enabled).padding(.vertical, 8) }
            if let answerError { Text(answerError).font(.subheadline).foregroundStyle(.secondary) }
        } header: { Label("Answer", systemImage: "sparkles").foregroundStyle(Color.zifrGold).textCase(nil) }
        footer: { if answer != nil { Text("Based on the matching records below.") } }
        .listRowBackground(Color.zifrCard)
    }

    private func resultRow(_ hit: SearchHit) -> some View {
        let r = hit.record
        return VStack(alignment: .leading, spacing: 10) {
            Button { open(r) } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: r.kind.icon)
                        .font(.title3).foregroundStyle(Color.zifrGold)
                        .frame(width: 42, height: 42)
                        .background(Color.zifrGold.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(r.title).font(.headline).foregroundStyle(.primary)
                        Text("\(r.company) · \(r.kind.label)").font(.subheadline).foregroundStyle(Color.zifrGold)
                        Text(r.detail).font(.subheadline).foregroundStyle(.secondary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 4)
                        .accessibilityHidden(true)
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityHint(r.page.map { "Opens page \($0)" } ?? "Opens this record")
            if let balance = r.amount, r.balanceCategory != nil {
                VStack(alignment: .leading, spacing: 3) {
                    Text(SearchText.money(balance, currency: r.currency)).font(.title3.weight(.semibold)).monospacedDigit()
                        .accessibilityLabel("Balance, " + SearchText.money(balance, currency: r.currency))
                    if let available = r.availableAmount {
                        Text((r.balanceCategory == .credit ? "Available credit " : "Available ") + SearchText.money(available, currency: r.currency))
                            .font(.caption).foregroundStyle(.secondary)
                    } else { Text("Saved balance").font(.caption).foregroundStyle(.secondary) }
                }
            }
            if hit.score == -100 || hit.reason == "Similar spelling" {
                Label(hit.reason, systemImage: hit.score == -100 ? "link" : "text.magnifyingglass")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let snippet = hit.snippet { Text(snippet).font(.subheadline).foregroundStyle(.secondary).lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3) }
            if !r.login.isEmpty {
                Text(r.login).font(.subheadline).foregroundStyle(.secondary).textSelection(.enabled)
            }
            if !r.login.isEmpty || [.card, .account, .institution].contains(r.kind) {
                Group {
                    if dynamicTypeSize.isAccessibilitySize { VStack(alignment: .leading, spacing: 8) { recordActionButtons(r) } }
                    else { HStack(spacing: 8) { recordActionButtons(r) } }
                }.font(.caption.weight(.semibold)).buttonStyle(.borderless)
            }
            if r.credential == .available { SearchPasswordControls(recordID: r.id) }
            else if r.credential == .locked { Label(SecurityService.lockedValueLabel, systemImage: "lock").font(.caption).foregroundStyle(.secondary) }
        }
        .padding(.vertical, 10)
        .listRowBackground(Color.zifrCard)
        .listRowSeparatorTint(Color.zifrBorder)
    }

    @ViewBuilder private func recordActionButtons(_ r: SearchRecord) -> some View {
        if !r.login.isEmpty {
            Button { SearchCredentialAccess.copy(r.login) } label: {
                Label("Copy login", systemImage: "person.crop.circle").frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        if [.card, .account, .institution].contains(r.kind) {
            Button {
                filters.kind = nil
                related = .init(id: r.id, kind: .subscription, title: "Services using \(r.title)")
                endEditing()
            } label: { Label("Services", systemImage: "repeat").frame(maxWidth: .infinity, minHeight: 44) }
            Button {
                filters.kind = nil
                related = .init(id: r.id, kind: .transaction, title: "Transactions for \(r.title)")
                endEditing()
            } label: { Label("Transactions", systemImage: "arrow.left.arrow.right").frame(maxWidth: .infinity, minHeight: 44) }
        }
    }

    private var coverageSheet: some View {
        NavigationStack {
            List {
                Section("Available to search") {
                    Text(response.coverage.isEmpty ? "Your loaded portfolio" : response.coverage).font(.body)
                    Text("Search includes records you can access in this session. Balances reflect saved values in the app.")
                        .foregroundStyle(.secondary)
                    if let issue = appState.portfolioLoadIssue { Label(issue, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                }
                if !appState.documents.isEmpty {
                    Section("Documents") {
                        Text(appState.searchDocumentStatus)
                        Button("Update document search") {
                            guard let userID = auth.currentUser?.id else { return }
                            Task { await SearchDocumentIndexer.shared.index(appState: appState, userID: userID) }
                        }
                    }
                }
            }
            .navigationTitle("Search coverage").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { presentation = nil } } }
        }.tint(Color.zifrGold).preferredColorScheme(.dark).presentationDetents([.medium, .large])
    }

    private func endEditing() {
        searchFocused = false
        // iOS 17 doesn't have searchFocused. Resign focus without cancelling/clearing the query.
        if #unavailable(iOS 18.0) { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
    }
    private func open(_ record: SearchRecord) {
        endEditing()
        if response.isCredentialRequest && (!record.login.isEmpty || record.credential != .none) { presentation = .result(.init(recordIDs: [record.id])) }
        else if (record.destinationKind ?? record.kind) == .company, let company = appState.companies.first(where: { $0.id == (record.destinationID ?? record.modelID) }) { vm.selectedCompany = company; vm.path.append(company); dismiss() }
        else { presentation = .result(.init(record: record)) }
    }
    @MainActor private func search() async {
        answerTask?.cancel(); answer = nil; answerError = nil; answering = false; visibleLimit = 40
        guard let userID = auth.currentUser?.id, auth.isAuthenticated else { response = .init(); return }
        searching = true
        do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
        let index = appState.searchIndex(for: userID)
        let query = vm.searchQuery, selectedFilters = filters, drill = related
        let result = await Task.detached(priority: .userInitiated) {
            if let drill {
                let ids = index.links[drill.id] ?? []
                let records = index.records.filter { ids.contains($0.id) && $0.kind == drill.kind }
                let subset = UniversalSearchIndex(records: records)
                return subset.search(drill.kind == .transaction ? "Transactions" : "Services", filters: selectedFilters)
            }
            return index.search(query, filters: selectedFilters)
        }.value
        guard !Task.isCancelled, auth.currentUser?.id == userID else { return }
        response = result; searching = false
    }
    private func ask(useGemini: Bool) {
        if useGemini && !access.request(.aiAction, source: "universal_search", appState: appState, userId: auth.currentUser?.id) { presentation = .premium; return }
        endEditing(); answering = true; answerError = nil
        guard let userID = auth.currentUser?.id else { answering = false; return }
        let query = appState.searchRedactor().clean(vm.searchQuery), key = taskKey
        let index = appState.searchIndex(for: userID), selectedFilters = filters
        let originalResponse = response
        answerTask = Task { @MainActor in
            defer { if key == taskKey { answering = false } }
            do {
                var found = originalResponse
                if related == nil && (found.hits.isEmpty || query.split(separator: " ").count > 6) {
                    let rewritten = try await SearchAnswerService.searchQuery(for: query, useGemini: useGemini)
                    guard !Task.isCancelled, key == taskKey else { return }
                    found = index.search(rewritten, filters: selectedFilters)
                    found.interpretation = "Interpreted as ‘\(rewritten)’ · " + found.interpretation
                    response = found
                }
                if found.isCredentialRequest { return }
                let result = try await SearchAnswerService.answer(question: query, evidence: found.assistantEvidence(limit: useGemini ? 12 : 8), useGemini: useGemini)
                guard !Task.isCancelled, key == taskKey else { return }; answer = result
            } catch { if !Task.isCancelled, key == taskKey { answerError = "An AI answer is unavailable. Your search results and calculated totals are still available." } }
            if useGemini { await access.refresh() }
        }
    }
}

/// Use the system's search field and focus behavior instead of imitating its chrome.
private struct SearchFieldConfiguration: ViewModifier {
    @Binding var query: String
    @Binding var presented: Bool
    let focus: FocusState<Bool>.Binding
    private var placement: SearchFieldPlacement {
        if #available(iOS 26.0, *) { return .automatic }
        return .navigationBarDrawer(displayMode: .always)
    }
    func body(content: Content) -> some View {
        let field = content.searchable(text: $query, isPresented: $presented, placement: placement,
            prompt: "Search your portfolio")
        if #available(iOS 18.0, *) {
            field.searchFocused(focus).searchPresentationToolbarBehavior(.avoidHidingContent)
        } else if #available(iOS 17.1, *) {
            field.searchPresentationToolbarBehavior(.avoidHidingContent)
        } else { field }
    }
}

private struct SearchGlassControls<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        if #available(iOS 26.0, *) { GlassEffectContainer(spacing: 8) { content } }
        else { content }
    }
}

private struct SearchFilterLabel: View {
    let title: String
    let icon: String
    let selected: Bool
    var showsChevron = true
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        if reduceTransparency {
            label.background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
        } else if #available(iOS 26.0, *) {
            label.glassEffect(selected ? .regular.tint(Color.zifrGold.opacity(0.16)).interactive() : .regular.interactive(), in: Capsule())
        } else { label.background(.regularMaterial, in: Capsule()) }
    }
    private var label: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title).lineLimit(1)
            if showsChevron { Image(systemName: "chevron.down").font(.caption2.weight(.semibold)) }
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(selected ? Color.zifrGold : Color.primary)
        .padding(.horizontal, 14).padding(.vertical, 8).frame(minHeight: 44)
    }
}

struct SearchPresentation: Identifiable {
    let id = UUID()
    var record: SearchRecord?
    var recordIDs: [String] = []
    var credentials: Bool { record == nil }
}

struct SearchRecordDestinationView: View {
    let record: SearchRecord
    @Bindable var vm: AppViewModel
    @Environment(AppState.self) private var appState
    @Environment(AuthViewModel.self) private var auth
    private var id: UUID { record.destinationID ?? record.modelID }
    private var kind: SearchRecord.Kind { record.destinationKind ?? record.kind }
    private var stillAccessible: Bool {
        guard auth.isAuthenticated, let userID = auth.currentUser?.id else { return false }
        return appState.searchIndex(for: userID).records.contains { $0.id == record.id }
    }
    var body: some View {
        Group {
            if !stillAccessible { ContentUnavailableView("Item unavailable", systemImage: "lock", description: Text("The item or your access changed. Search again.")) }
            else {
                switch kind {
                case .transaction: PortfolioTransactionCenterView(vm: vm, initialTransactionID: id)
                case .subscription:
                    if let sub = appState.subscriptions.first(where: { $0.id == id }) { EditSubscriptionSheet(sub: sub, institutions: appState.institutions, cards: appState.cards, vm: vm, isNew: false, onSave: {}) }
                case .card:
                    if let card = appState.cards.first(where: { $0.id == id }) { EditCardSheet(card: card, vm: vm, institutions: appState.institutions, cards: appState.cards, isNew: false) }
                case .institution, .account:
                    if let bank = appState.institutions.first(where: { $0.id == id }) { EditInstitutionSheet(institution: bank, institutions: appState.institutions, cards: appState.cards, loans: appState.loans, vm: vm, isNew: false) }
                case .loan, .payment:
                    if let loan = appState.loans.first(where: { $0.id == id }) { EditLoanSheet(loan: loan, vm: vm, isNew: false, institutions: appState.institutions, cards: appState.cards) }
                case .document:
                    if let doc = appState.documents.first(where: { $0.id == id }) {
                        if let page = record.page { SearchDocumentViewer(document: doc, page: page) }
                        else { EditDocumentSheet(doc: doc, vm: vm, isNew: false, companyStructure: appState.companies.first(where: { $0.id == doc.companyId })?.structure ?? "LLC") }
                    }
                default: ContentUnavailableView("Open from portfolio", systemImage: record.kind.icon)
                }
            }
        }
    }
}
