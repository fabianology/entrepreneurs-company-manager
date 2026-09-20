import SwiftUI

struct GlobalSearchView: View {
    @Bindable var vm: AppViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(AuthViewModel.self) private var auth
    @Environment(AccessController.self) private var access
    @FocusState private var searchFocused: Bool
    @State private var filters = SearchFilters()
    @State private var response = SearchResponse()
    @State private var overviews: [SearchOverview] = []
    @State private var fundingSources: [String: [SearchRecord]] = [:]
    @State private var searching = false
    @State private var visibleLimit = 40
    @State private var expandedMatchYears: Set<String> = []
    @State private var presentation: SheetRoute?
    @State private var related: RelatedSearch?
    @State private var answer: String?
    @State private var answering = false
    @State private var answerError: String?
    @State private var submitTask: Task<Void, Never>?
    @State private var previousQuery: PortfolioQuery?
    @State private var lastExecutedQuery: PortfolioQuery?
    @State private var projectionStamp: SearchProjectionStamp?
    @State private var clockRevision = 0
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
    private var taskKey: String { "\(vm.searchQuery)|\(filters)|\(appState.searchRevision)|\(auth.currentUser?.id.uuidString ?? "")|\(String(describing: related))|\(clockRevision)" }

    @State private var searchPresented = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var hasQuery: Bool { !vm.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || related != nil }
    private var displayedCompanyID: UUID? {
        if let selected = filters.companyID { return selected }
        guard !filters.ignoreInferredCompany else { return nil }
        for filter in response.appliedFilters {
            if case .company(let id, _) = filter { return id }
        }
        return nil
    }
    private var companyTitle: String {
        displayedCompanyID.flatMap { id in appState.companies.first { $0.id == id }?.name } ?? "All companies"
    }

    var body: some View {
        NavigationStack {
            resultsList
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
                    ToolbarItem(placement: .topBarTrailing) {
                        companyPicker
                    }
                }
        }
        .modifier(SearchFieldConfiguration(query: $vm.searchQuery, presented: $searchPresented, focus: $searchFocused))
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .onSubmit(of: .search) {
            endEditing()
            submitTask?.cancel()
            let key = taskKey
            submitTask = Task { @MainActor in
                await search()
                guard !Task.isCancelled, key == taskKey else { return }
                previousQuery = lastExecutedQuery
                if response.hits.isEmpty && response.metrics.isEmpty && response.answerSummary == nil && vm.searchQuery.split(separator: " ").count > 3 && !response.isCredentialRequest { ask(useGemini: true) }
            }
        }
        .tint(Color.zifrGold)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.regularMaterial)
        .task(id: taskKey) { await search() }
        .onAppear { if vm.searchQuery.isEmpty { searchPresented = true; searchFocused = true } }
        .onChange(of: vm.searchQuery) { _, _ in
            related = nil
            expandedMatchYears = []
            filters.ignoreInferredCompany = false
            filters.ignoreInferredDate = false
            filters.ignoreInferredState = false
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                refreshClock()
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in refreshClock() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name.NSSystemTimeZoneDidChange)) { _ in refreshClock() }
        .onDisappear {
            answerTask?.cancel()
            submitTask?.cancel()
            if presentation == nil { vm.searchQuery = "" }
        }
    }

    private var resultsList: some View {
        let page = SearchResultPage(response: response, overviews: overviews, limit: visibleLimit)
        return List {
            if !appState.hasLoadedPortfolio {
                ContentUnavailableView("Loading your portfolio", systemImage: "arrow.triangle.2.circlepath",
                    description: Text("Your results will appear when your records are ready."))
                    .listRowBackground(Color.clear)
            } else if !hasQuery {
                suggestions
            } else {
                if !response.appliedFilters.isEmpty, related == nil {
                    appliedFilterControls
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowSeparator(.hidden)
                }
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
                if !response.metrics.isEmpty {
                    Section {
                        ForEach(response.metrics) { metric in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(metric.label).font(.subheadline).foregroundStyle(.secondary)
                                Text(metric.formatted).font(.title2.weight(.semibold)).monospacedDigit()
                            }.padding(.vertical, 4)
                        }
                        answerDetails
                    } header: { Text("Answer").textCase(nil) }.listRowBackground(Color.zifrCard)
                }
                if response.metrics.isEmpty && response.totals.isEmpty, let summary = response.answerSummary, !summary.isEmpty {
                    Section("Answer") {
                        Text(summary)
                        answerDetails
                    }.listRowBackground(Color.zifrCard)
                }
                if response.metrics.isEmpty && !response.totals.isEmpty { totals }
                if answering || answer != nil || answerError != nil { answerSection }
                if searching && response.hits.isEmpty {
                    HStack { Spacer(); ProgressView("Searching…"); Spacer() }
                        .padding(.vertical, 24).listRowBackground(Color.clear)
                } else if response.hits.isEmpty && !searching && response.metrics.isEmpty && response.answerSummary == nil {
                    ContentUnavailableView {
                        Label("No results for “\(vm.searchQuery)”", systemImage: "magnifyingglass")
                    } description: {
                        Text(vm.searchQuery.split(separator: " ").count > 3 ? "Press Search to ask Gemini to interpret this question, or try fewer filters." : "Try a name or card ending, or choose fewer filters.")
                    } actions: {
                        if filters != SearchFilters() || !response.appliedFilters.isEmpty {
                            Button("Clear filters") {
                                filters = .init()
                                for filter in response.appliedFilters { filters.remove(filter) }
                            }.frame(minHeight: 44)
                        }
                    }
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                }
                if !page.overviews.isEmpty {
                    ForEach(page.overviews) { overview in
                        Section {
                            SearchOverviewCard(overview: overview, open: open)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        } header: {
                            Text(overview.root.company.uppercased() + " • " + (overview.root.kind == .institution ? "BANK" : "SERVICE"))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if !page.directHits.isEmpty {
                    Section {
                        if overviews.isEmpty {
                            ForEach(page.directHits) { hit in resultRow(hit) }
                        } else {
                            ForEach(page.directHits.filter { $0.record.kind != .transaction }) { hit in resultRow(hit) }
                            ForEach(SearchTransactionYearGroup.groups(page.directHits)) { group in
                                DisclosureGroup(isExpanded: Binding(
                                    get: { expandedMatchYears.contains(group.id) },
                                    set: { if $0 { expandedMatchYears.insert(group.id) } else { expandedMatchYears.remove(group.id) } }
                                )) {
                                    ForEach(group.hits) { hit in resultRow(hit) }
                                } label: {
                                    Text(group.title).font(.headline)
                                }
                                .accessibilityIdentifier("search-more-matches-year-" + group.id)
                                .listRowBackground(Color.zifrCard)
                            }
                        }
                    } header: {
                        if !overviews.isEmpty { resultHeading("More matches") }
                        else if related != nil { resultHeading("Results") }
                    }
                }
                if !page.relatedHits.isEmpty {
                    Section {
                        ForEach(page.relatedHits) { hit in resultRow(hit) }
                    } header: {
                        resultHeading("Related records")
                    }
                }
                if page.hasMore {
                    Button("Show more results") { visibleLimit += 40 }
                        .frame(maxWidth: .infinity, minHeight: 44).listRowBackground(Color.zifrCard)
                }
                if response.metrics.isEmpty && response.answerSummary == nil && !response.interpretation.isEmpty && response.interpretation != "Best matches" {
                    Text(response.interpretation).font(.footnote).foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .disclosureGroupStyle(SearchDisclosureStyle())
        .contentMargins(.top, 8, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(Color.zifrCard.opacity(0.65))
        .scrollDismissesKeyboard(.immediately)
    }

    private func refreshClock() {
        let stamp = appState.searchProjectionStamp()
        guard stamp != projectionStamp else { return }
        projectionStamp = stamp
        clockRevision &+= 1
    }

    private var appliedFilterControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Filters").font(.caption).foregroundStyle(.secondary)
            SearchFilterFlowLayout { filterChips }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var filterChips: some View {
        ForEach(response.appliedFilters) { filter in
            HStack(spacing: 0) {
                Menu {
                    switch filter {
                    case .company:
                        Button("All companies") { filters.remove(filter) }
                        ForEach(appState.companies) { company in
                            Button(company.name) {
                                filters.companyID = company.id
                                filters.ignoreInferredCompany = true
                            }
                        }
                    case .date:
                        ForEach(SearchFilters.Period.allCases, id: \.self) { period in
                            Button(period.rawValue) { filters.period = period; filters.ignoreInferredDate = true }
                        }
                    case .transactionState:
                        Button("Posted + pending") { filters.transactionState = .all; filters.ignoreInferredState = true }
                        Button("Posted") { filters.transactionState = .posted; filters.ignoreInferredState = true }
                        Button("Pending") { filters.transactionState = .pending; filters.ignoreInferredState = true }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(filter.label).fixedSize(horizontal: false, vertical: true)
                        Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
                    }
                    .padding(.leading, 14)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("Change \(filter.id) filter: \(filter.label)")
                .accessibilityIdentifier("search.filter.\(filter.id)")
                Button { filters.remove(filter) } label: {
                    Image(systemName: "xmark").font(.caption.weight(.semibold))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .accessibilityLabel("Remove \(filter.label) filter")
                .accessibilityIdentifier("search.filter.remove.\(filter.id)")
            }
            .font(.subheadline)
            .foregroundStyle(Color.zifrGold)
            .background(Color.white.opacity(0.07), in: Capsule())
            .buttonStyle(.plain)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var answerDetails: some View {
        DisclosureGroup("About this answer") {
            Text(response.interpretation).font(.footnote).foregroundStyle(.secondary)
            Text(response.coverage).font(.footnote).foregroundStyle(.secondary)
        }.font(.subheadline)
    }

    private func resultHeading(_ title: String) -> some View {
        HStack {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            if searching { ProgressView().controlSize(.small).accessibilityLabel("Updating results") }
        }.textCase(nil).accessibilityElement(children: .combine)
    }

    private var companyPicker: some View {
        Menu {
            Picker("Company", selection: Binding(get: { displayedCompanyID }, set: {
                filters.companyID = $0; filters.ignoreInferredCompany = true
            })) {
                Text("All").tag(nil as UUID?)
                ForEach(appState.companies) { company in
                    Text(company.name).tag(Optional(company.id))
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(displayedCompanyID == nil ? "Companies" : companyTitle)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: 160, minHeight: 44)
            .foregroundStyle(.white)
        }
        .tint(.white)
        .accessibilityLabel("Company filter")
        .accessibilityValue(companyTitle)
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
            HStack(alignment: .top, spacing: 16) {
                SearchResultLogo(record: r, size: 40).frame(width: 56, height: 56).padding(.top, 5)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 2) {
                        Button { open(r) } label: {
                            Text(r.title).font(.headline).foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true).frame(minHeight: 44, alignment: .leading)
                        }.buttonStyle(.plain).accessibilityHint(r.page.map { "Opens page \($0)" } ?? "Opens this record")
                        SearchWebsiteButton(record: r)
                        Spacer(minLength: 0)
                    }
                    SearchRecordSummary(record: r, paymentSources: fundingSources[r.id] ?? [], open: open)
                    Text("\(r.company) · \(r.kind == .subscription ? r.serviceType?.capitalized ?? "Service" : r.kind.label)")
                        .font(.footnote).foregroundStyle(.secondary)
                    if r.kind != .subscription {
                        Text(r.detail).font(.callout).foregroundStyle(.secondary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    }
                }
            }
            if hit.score == -100 || hit.reason == "Similar spelling" {
                Label(hit.reason, systemImage: hit.score == -100 ? "link" : "text.magnifyingglass")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let snippet = hit.snippet { Text(snippet).font(.callout).foregroundStyle(.secondary).lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3) }
            SearchCredentialBoxes(record: r)
            if [.card, .account, .institution].contains(r.kind) {
                Group {
                    if dynamicTypeSize.isAccessibilitySize { VStack(alignment: .leading, spacing: 8) { recordActionButtons(r) } }
                    else { HStack(spacing: 8) { recordActionButtons(r) } }
                }.font(.caption.weight(.semibold)).buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 10)
        .listRowBackground(Color.zifrCard)
        .listRowSeparatorTint(Color.zifrBorder)
    }

    @ViewBuilder private func recordActionButtons(_ r: SearchRecord) -> some View {
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
        // Resign the native search field too, including systems where search focus lags UIKit.
        // Ending search presentation would clear the query, so leave it active.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    private func open(_ record: SearchRecord) {
        endEditing()
        if response.isCredentialRequest && (!record.login.isEmpty || record.credential != .none) { presentation = .result(.init(recordIDs: [record.id])) }
        else if (record.destinationKind ?? record.kind) == .company, let company = appState.companies.first(where: { $0.id == (record.destinationID ?? record.modelID) }) { vm.selectedCompany = company; vm.path.append(company); dismiss() }
        else { presentation = .result(.init(record: record)) }
    }
    @MainActor private func search() async {
        answerTask?.cancel(); answer = nil; answerError = nil; answering = false; visibleLimit = 40
        guard let userID = auth.currentUser?.id, auth.isAuthenticated else { response = .init(); overviews = []; fundingSources = [:]; return }
        let key = taskKey
        searching = true
        do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
        guard let index = try? await appState.searchIndexInBackground(for: userID), !Task.isCancelled, key == taskKey else { return }
        let request = index.interpretedRequest(vm.searchQuery, previous: previousQuery, filters: filters)
        let selectedFilters = filters, drill = related
        let work = Task.detached(priority: .userInitiated) {
            if let drill {
                let ids = index.links[drill.id] ?? []
                let records = index.records.filter { ids.contains($0.id) && $0.kind == drill.kind }
                let subset = UniversalSearchIndex(records: records)
                let found = subset.search(drill.kind == .transaction ? "Transactions" : "Services", filters: selectedFilters)
                return (found, [SearchOverview](), index.searchPaymentSources(for: found.hits))
            }
            let response = index.execute(request, filters: selectedFilters)
            return (response, index.overviews(for: response, request: request, filters: selectedFilters), index.searchPaymentSources(for: response.hits))
        }
        let result = await withTaskCancellationHandler {
            await work.value
        } onCancel: { work.cancel() }
        guard !Task.isCancelled, key == taskKey, auth.isAuthenticated, auth.currentUser?.id == userID else { return }
        response = result.0; overviews = result.1; fundingSources = result.2; lastExecutedQuery = request; searching = false
    }
    private func ask(useGemini: Bool) {
        if useGemini && !access.request(.aiAction, source: "universal_search", appState: appState, userId: auth.currentUser?.id) { presentation = .premium; return }
        endEditing(); answering = true; answerError = nil
        guard let userID = auth.currentUser?.id else { answering = false; return }
        let query = appState.searchRedactor().clean(vm.searchQuery), key = taskKey
        let selectedFilters = filters
        let originalResponse = response
        answerTask = Task { @MainActor in
            defer { if key == taskKey { answering = false } }
            do {
                let index = try await appState.searchIndexInBackground(for: userID)
                guard !Task.isCancelled, key == taskKey else { return }
                var found = originalResponse
                if related == nil && (found.hits.isEmpty || query.split(separator: " ").count > 6) {
                    let rewritten = try await SearchAnswerService.queryRequest(for: query, useGemini: useGemini)
                    guard !Task.isCancelled, key == taskKey else { return }
                    let work = Task.detached(priority: .userInitiated) {
                        let result = index.execute(rewritten, filters: selectedFilters)
                        return (result, index.overviews(for: result, request: rewritten, filters: selectedFilters), index.searchPaymentSources(for: result.hits))
                    }
                    let result = await withTaskCancellationHandler { await work.value } onCancel: { work.cancel() }
                    guard !Task.isCancelled, key == taskKey, auth.isAuthenticated, auth.currentUser?.id == userID else { return }
                    found = result.0
                    found.interpretation = "Interpreted question · " + found.interpretation
                    response = found; overviews = result.1; fundingSources = result.2
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
                case .expenseReview:
                    if let review = appState.businessExpenseReviews.first(where: { $0.id == id }) { BusinessExpenseReviewSheet(initialReview: review) }
                case .settings, .alert: AdminSettingsView(vm: vm)
                case .activity: ActivityLogsView(vm: vm)
                default:
                    NavigationStack {
                        List {
                            Text(record.title).font(.headline)
                            Text(record.detail)
                            ForEach(record.safeDetails.keys.sorted(), id: \.self) { key in
                                VStack(alignment: .leading) { Text(SearchText.fieldLabel(key)).font(.caption).foregroundStyle(.secondary); Text(record.safeDetails[key] ?? "") }
                            }
                        }.navigationTitle(record.kind.label)
                    }

                }
            }
        }
    }
}

/// Wrap native menu buttons without truncating names or shrinking accessibility text.
private struct SearchFilterFlowLayout: Layout {
    private let spacing: CGFloat = 8

    private func measure(_ subviews: Subviews, width: CGFloat) -> (CGSize, [CGRect]) {
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        var frames: [CGRect] = []
        for view in subviews {
            let ideal = view.sizeThatFits(.unspecified)
            let size = view.sizeThatFits(ProposedViewSize(width: min(width, ideal.width), height: nil))
            if x > 0 && x + size.width > width {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing; rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: width, height: y + rowHeight), frames)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        measure(subviews, width: proposal.width ?? 320).0
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = measure(subviews, width: bounds.width).1
        for (view, frame) in zip(subviews, frames) {
            view.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                       anchor: .topLeading, proposal: ProposedViewSize(frame.size))
        }
    }
}
