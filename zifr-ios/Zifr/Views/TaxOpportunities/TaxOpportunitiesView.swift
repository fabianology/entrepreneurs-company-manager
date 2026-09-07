import SwiftUI

struct TaxOpportunitiesButton: View {
    var count: Int
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "doc.text.magnifyingglass").font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(Color.zifrGold).frame(width: 30, height: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tax Opportunities").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    Text(count > 0 ? "\(count) potential business expenses to review" : "Find and organize potential business expenses")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.75))
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
            }
            .padding(.horizontal, 16).padding(.vertical, 14).frame(minHeight: 64)
            .background(Color.zifrBG, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain).accessibilityIdentifier("taxOpportunitiesButton")
        .accessibilityHint("Opens business expense review across your accounts")
    }
}

struct TaxOpportunitiesView: View {
    var initialCompanyId: UUID? = nil
    @Environment(AppState.self) private var state
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var model = TaxOpportunitiesViewModel()
    @State private var companyId: UUID?
    @State private var filter = BusinessExpenseFilter.needsReview
    @State private var selectedReview: BusinessExpenseReview?
    @State private var showSettings = false
    @State private var showExport = false
    @State private var showTransactions = false
    private var companies: [Company] { state.companies.filter { $0.userId == auth.currentUser?.id } }
    private var scoped: [BusinessExpenseReview] { state.businessExpenseReviews.filter { $0.belongs(to: companyId) } }
    private var filtered: [BusinessExpenseReview] { scoped.filter { filter.includes($0) } }
    var body: some View {
        NavigationStack {
            List {
                if let error = model.error { Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange); Button("Try again") { Task { await model.refresh(state) } } } }
                Section {
                    Picker("Entity", selection: $companyId) {
                        Text("All Entities").tag(nil as UUID?)
                        ForEach(companies) { Text($0.name).tag(Optional($0.id)) }
                    }
                    Picker("Show", selection: $filter) { ForEach(BusinessExpenseFilter.allCases) { Text($0.rawValue).tag($0) } }
                }
                Section {
                    Text("\(scoped.filter { BusinessExpenseFilter.needsReview.includes($0) }.count) purchases need review")
                    ForEach(confirmedTotals, id: \.0) { currency, total in
                        LabeledContent("Confirmed · \(currency)", value: BusinessExpensePolicy.money(total, currency: currency))
                    }
                    if let companyId {
                        let outside = scoped.filter { $0.source.sourceCompanyId != companyId && BusinessExpenseFilter.needsReview.includes($0) }.count
                        if outside > 0 { Text("\(outside) potential expenses found outside this Entity’s accounts").font(.footnote).foregroundStyle(.secondary) }
                    }
                } footer: { Text("Confirmed amounts reflect business use. They are not tax deductions or estimated savings.") }
                if let job = state.businessExpenseJob {
                    Section("Latest scan") {
                        LabeledContent(job.state.capitalized, value: "\(job.scanned) checked · \(job.suggested) suggested")
                        Text("Scan range: \(job.dateFrom) through \(job.dateTo)").font(.caption).foregroundStyle(.secondary)
                        if job.isActive { ProgressView("Screening available transactions…") }
                        if let code = job.errorCode { Text(scanMessage(code)).font(.footnote).foregroundStyle(.orange) }
                    }
                }
                Section(filter.rawValue) {
                    if filtered.isEmpty {
                        Text("No expenses in this view. You can review a purchase manually from Transactions or enable AI screening in Settings.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(filtered) { review in
                        Button { selectedReview = review } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { Text(review.source.merchant).fontWeight(.semibold); Spacer(); Text(BusinessExpensePolicy.money(review.source.amount, currency: review.source.currency)) }
                                Text("\(review.source.accountName) · \(review.source.date)").font(.caption).foregroundStyle(.secondary)
                                Text(review.statusLabel).font(.caption).foregroundStyle(Color.zifrGold)
                                if review.changedSinceExport { Text("Changed since export").font(.caption).foregroundStyle(.orange) }
                                if let allocation = review.allocation {
                                    Text("\(companies.first { $0.id == allocation.companyId }?.name ?? "Entity") · \(Double(allocation.businessBasisPoints) / 100, specifier: "%.2f")% business use").font(.caption)
                                } else if review.suggestions.count > 1 { Text("Choose which Entity this was for").font(.caption) }
                            }
                        }.foregroundStyle(.primary)
                    }
                }
                Section { Text(BusinessExpensePolicy.disclosure).font(.caption).foregroundStyle(.secondary) }
            }
            .scrollContentBackground(.hidden).background(Color(hex: "#1C1C1E"))
            .navigationTitle("Tax Opportunities").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showExport = true } label: { Image(systemName: "square.and.arrow.up") }.accessibilityLabel("Accountant export")
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }.accessibilityLabel("Screening settings")
                }
            }
            .sheet(item: $selectedReview) { BusinessExpenseReviewSheet(initialReview: $0) }
            .sheet(isPresented: $showSettings) { TaxScreeningSetupSheet() }
            .sheet(isPresented: $showExport) { BusinessExpenseExportSheet(initialCompanyId: companyId) }
            .refreshable { await model.refresh(state) }
            .task {
                companyId = initialCompanyId
                await model.refresh(state)
            }
            .task(id: state.businessExpenseJob?.id) {
                while let job = state.businessExpenseJob, job.isActive, !Task.isCancelled {
                    do {
                        try await DataRepository.shared.processBusinessExpenseScan(jobId: job.id)
                        await model.refresh(state)
                        try await Task.sleep(for: .seconds(3))
                    } catch {
                        if !Task.isCancelled { model.error = TaxOpportunitiesViewModel.message(error) }
                        break
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    private var confirmedTotals: [(String, Decimal)] {
        var totals: [String: Decimal] = [:]
        for review in scoped where review.decision == "confirmed" && ["active", "disconnected"].contains(review.sourceState) {
            if let amount = review.businessAmount, let currency = review.source.currency { totals[currency, default: 0] += amount }
        }
        return totals.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }
    private func scanMessage(_ code: String) -> String {
        switch code {
        case "usage_limit": return "AI allowance reached. Existing reviews and export remain available. Start another scan when your allowance resets."
        case "configuration_required": return "AI screening needs server configuration. Manual review remains available."
        case "no_profiles": return "Add a business activity in Screening Settings."
        default: return "Some transactions could not be screened. Your saved reviews are safe. Start another scan to retry."
        }
    }
}

struct TaxScreeningSetupSheet: View {
    @Environment(AppState.self) private var state
    @Environment(AuthViewModel.self) private var auth
    @Environment(AccessController.self) private var access
    @Environment(\.dismiss) private var dismiss
    @State private var model = TaxOpportunitiesViewModel()
    @State private var settings = BusinessExpenseSettings()
    @State private var profiles: [BusinessExpenseProfile] = []
    @State private var start = BusinessExpensePolicy.defaultStart()
    @State private var end = Date()
    @State private var resetLearning = false
    @State private var showDeleteHistory = false
    private var accounts: [(String, String)] {
        let records = TransactionIntelligence.resolveAll(state.transactions.filter { $0.userId == auth.currentUser?.id }, companies: state.companies, institutions: state.institutions, cards: state.cards)
        var labels: [String: String] = [:]
        for r in records {
            let account = state.institutions.filter { $0.userId == auth.currentUser?.id }.flatMap(\.accounts).first { $0.id == r.accountId || $0.plaidAccountId == r.accountId }
            let key = state.businessExpenseAccounts.first { $0.accountId == r.accountId || $0.canonicalAccountId == r.accountId }?.exclusionKey ?? account?.persistentAccountId.map { "persistent:" + $0 } ?? r.accountId
            labels[key] = "\(r.institutionName) · \(r.accountName)"
        }
        for institution in state.institutions where institution.userId == auth.currentUser?.id {
            for account in institution.accounts {
                let key = state.businessExpenseAccounts.first { $0.accountId == account.id || $0.accountId == account.plaidAccountId }?.exclusionKey ?? account.persistentAccountId.map { "persistent:" + $0 } ?? account.plaidAccountId ?? account.id
                labels[key] = "\(institution.name) · \(account.name)"
            }
        }
        return labels.sorted { $0.value < $1.value }.map { ($0.key, $0.value) }
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Find potential business expenses", isOn: $settings.enabled)
                    Text("Miloom scans your connected accounts, including personal accounts, using transaction details and your business context. Newly connected accounts are included automatically. You decide whether each suggestion is business-related.").font(.footnote)
                    Text("AI receives merchant, amount, category, recurrence, and relevant business context. Account credentials, account numbers, and receipt images are excluded.").font(.footnote).foregroundStyle(.secondary)
                    if !access.isPro { Text("Automated screening requires Pro. Manual review, documentation, and export remain available.").font(.footnote).foregroundStyle(Color.zifrGold) }
                } header: { Text("One feature-level opt-in") }
                Section("Business context") {
                    ForEach($profiles) { $profile in
                        VStack(alignment: .leading) {
                            Toggle(state.companies.first { $0.id == profile.companyId }?.name ?? "Entity", isOn: $profile.enabled)
                            if profile.enabled { TextField("What does this business do?", text: $profile.activity, axis: .vertical).lineLimit(2...4) }
                        }
                    }
                    if profiles.isEmpty { Text("Create a business Entity before enabling screening.") }
                }
                Section {
                    ForEach(accounts, id: \.0) { account in
                        Toggle(account.1, isOn: Binding(get: { settings.excludedAccountIds.contains(account.0) }, set: { excluded in
                            let aliases = state.businessExpenseAccounts.filter { $0.exclusionKey == account.0 }.flatMap { [$0.accountId, $0.canonicalAccountId].compactMap { $0 } }
                            settings.excludedAccountIds.removeAll { $0 == account.0 || aliases.contains($0) }
                            if excluded { settings.excludedAccountIds.append(account.0) }
                        }))
                    }
                } header: { Text("Exclude accounts (optional)") } footer: { Text("Turn on an exclusion to keep that account out of screening. This does not delete existing review records.") }
                Section("Historical scan") {
                    DatePicker("From", selection: $start, in: ...end, displayedComponents: .date)
                    DatePicker("Through", selection: $end, in: start...Date(), displayedComponents: .date)
                    Text("Only available posted history is analyzed. One AI action covers up to 25 eligible purchases; unchanged results are reused.").font(.caption).foregroundStyle(.secondary)
                    Button("Save and scan available history") { save(scan: true) }
                        .disabled(!access.isPro || !settings.enabled || profiles.filter { $0.enabled && !$0.activity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.isEmpty || model.isBusy)
                }
                Section {
                    Toggle("Reset learned associations when saving", isOn: $resetLearning)
                    Text("Keeps your review and export history. Earlier confirmations will no longer influence future suggestions.").font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Button("Delete Tax Opportunities history", role: .destructive) { showDeleteHistory = true }.disabled(model.isBusy)
                } footer: { Text("Deletes business reviews, learning history, private linked receipts, and server export snapshots. Your financial transactions remain unchanged.") }
                if let error = model.error { Section { Text(error).foregroundStyle(.orange) } }
                Section { Text(BusinessExpensePolicy.disclosure).font(.caption) }
            }
            .navigationTitle("Screening Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(model.isBusy) }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save(scan: false) }.disabled(model.isBusy) }
            }
            .confirmationDialog("Delete all Tax Opportunities history?", isPresented: $showDeleteHistory, titleVisibility: .visible) {
                Button("Delete history and pause screening", role: .destructive) {
                    Task { if await model.perform(state, operation: { try await DataRepository.shared.deleteBusinessExpenseHistory() }) { dismiss() } }
                }
            } message: { Text("This removes review records, linked private receipts, and server export snapshots. Previously downloaded files cannot be recalled.") }
            .onAppear {
                settings = state.businessExpenseSettings
                profiles = state.companies.filter { $0.userId == auth.currentUser?.id && OwnerBriefingScope.business.includes($0) }.map { company in
                    state.businessExpenseProfiles.first { $0.companyId == company.id } ?? BusinessExpenseProfile(companyId: company.id, activity: company.companyDescription ?? "")
                }
            }
        }.preferredColorScheme(.dark)
    }
    private func save(scan: Bool) {
        Task {
            if await model.perform(state, operation: {
                try await DataRepository.shared.configureBusinessExpenses(settings: settings, profiles: profiles, resetLearning: resetLearning)
                if scan { _ = try await DataRepository.shared.startBusinessExpenseScan(from: start, to: end) }
            }) { dismiss() }
        }
    }
}
