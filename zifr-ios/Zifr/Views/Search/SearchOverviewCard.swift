import SwiftUI

struct SearchResultLogo: View {
    let record: SearchRecord
    var size: CGFloat = 42
    @Environment(AppState.self) private var appState
    private var initial: String { String((record.brandName ?? record.title).prefix(1)).uppercased() }
    var body: some View {
        Group {
            if record.kind == .company, let company = appState.companies.first(where: { $0.id == record.modelID }) {
                CompanyAvatar(company: company, size: size)
            } else if let url = SearchBrand.websiteURL(record.logoURL) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFit() }
                    else { brand }
                }
            } else { brand }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityHidden(true)
    }
    @ViewBuilder private var brand: some View {
        if let domain = SearchBrand.domain(for: record) {
            FaviconImage(website: domain, size: size, fallbackInitial: initial)
        } else {
            Text(initial.isEmpty ? "?" : initial)
                .font(.system(size: size * 0.45, weight: .semibold, design: .rounded))
                .frame(width: size, height: size)
                .foregroundStyle(Color.zifrGold)
                .background(Color.zifrGold.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct SearchOverviewCard: View {
    let overview: SearchOverview
    var open: (SearchRecord) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var expanded: Set<String>
    @State private var historyLimit = 3
    init(overview: SearchOverview, open: @escaping (SearchRecord) -> Void) {
        self.overview = overview; self.open = open
        _expanded = State(initialValue: overview.expandedChildIDs)
    }
    private var root: SearchRecord { overview.root }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button { open(root) } label: {
                HStack(spacing: 12) {
                    SearchResultLogo(record: root, size: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(root.title).font(.title3.weight(.semibold)).foregroundStyle(.primary)
                        Text(root.company + " · " + (root.kind == .institution ? "Bank" : (overview.children.isEmpty ? root.serviceType?.capitalized ?? "Service" : "Service account")))
                            .font(.subheadline).foregroundStyle(.secondary)
                        if let status = root.financialFacts["status"], status != "Active" {
                            Text(status).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }.frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain)

            credentials
            ForEach(overview.additionalLogins) { record in
                DisclosureGroup("Saved login · " + record.title) {
                    VStack(alignment: .leading, spacing: 8) {
                        if !record.login.isEmpty {
                            Text(record.login).font(.subheadline).foregroundStyle(.secondary).lineLimit(nil).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                            Button("Copy login") { SearchCredentialAccess.copy(record.login) }.font(.subheadline).frame(minHeight: 44)
                        }
                        if record.credential == .available { SearchPasswordControls(recordID: record.id) }
                        else if record.credential == .locked { Text(SecurityService.lockedValueLabel).font(.caption).foregroundStyle(.secondary) }
                    }.padding(.vertical, 8)
                }.font(.subheadline)
            }
            if root.kind == .subscription {
                if overview.children.isEmpty { serviceFacts(root, prominent: true) }
                else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(overview.monthlyTotals) { total in
                            Text(total.formatted + (overview.hasNonMonthlyCycle ? " / month equivalent" : " / month"))
                                .font(.title2.weight(.semibold)).monospacedDigit()
                        }
                        Text("\(overview.children.count) subservices" + (billingAmount(root) > 0 ? " + base service" : ""))
                            .font(.subheadline).foregroundStyle(.secondary)
                        if overview.hasUnknownCycle { Text("Partial total · a billing cycle is unknown").font(.caption).foregroundStyle(.secondary) }
                        if overview.hasNonMonthlyCycle { Text("Annual and other billing periods are converted for comparison.").font(.caption).foregroundStyle(.secondary) }
                    }
                    if billingAmount(root) > 0 { serviceFacts(root, prominent: false) }
                    ForEach(overview.children.prefix(3)) { child in childRow(child) }
                    if overview.children.count > 3 {
                        DisclosureGroup("More subservices (\(overview.children.count - 3))") {
                            ForEach(overview.children.dropFirst(3)) { child in childRow(child) }
                        }.font(.subheadline)
                    }
                }
            }
            if !overview.balances.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(overview.balances.prefix(3)) { balance in balanceRow(balance) }
                    if overview.balances.count > 3 {
                        DisclosureGroup("All accounts (\(overview.balances.count))") {
                            ForEach(overview.balances.dropFirst(3)) { balance in balanceRow(balance) }
                        }.font(.subheadline)
                    }
                }
            }
            if root.financialFacts["bankConnection"] == "Needs attention" {
                Label("Bank connection needs attention", systemImage: "exclamationmark.triangle")
                    .font(.subheadline).foregroundStyle(.orange)
            }
            if !overview.paidServices.isEmpty {
                DisclosureGroup("Pays for · \(overview.paidServices.count) services") {
                    ForEach(overview.paidServices) { service in
                        Button { open(service) } label: {
                            HStack(spacing: 10) {
                                SearchResultLogo(record: service, size: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(service.parentServiceID == nil ? service.title : (service.safeDetails["parentService"] ?? "Service") + " · " + service.title).foregroundStyle(.primary)
                                    Text((service.serviceType?.capitalized ?? "Service") + " · " + billingLabel(service)).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.caption)
                            }.font(.subheadline).frame(minHeight: 44)
                        }.buttonStyle(.plain)
                    }
                }.font(.subheadline)
            }
            if let role = root.safeDetails["yourAccess"] {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Miloom access · " + role).font(.subheadline).foregroundStyle(.secondary)
                    if let sender = root.safeDetails["sharedBy"], !sender.isEmpty {
                        Text("Shared by " + sender).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Divider().overlay(Color.zifrBorder)
            DisclosureGroup {
                history(overview.transactions)
                if overview.transactions.count > historyLimit {
                    Button("Show more transactions (\(overview.transactions.count - historyLimit))") { historyLimit += 10 }
                        .font(.subheadline).frame(minHeight: 44)
                }
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(root.kind == .institution ? "Transactions" : "Charge history").font(.subheadline.weight(.medium))
                    if let latest = overview.transactions.first {
                        Text("Latest: " + transactionLabel(latest)).font(.caption).foregroundStyle(.secondary)
                    }
                }.frame(minHeight: 44, alignment: .leading)
            }
            if !overview.documents.isEmpty {
                DisclosureGroup("Documents (\(overview.documents.count))") {
                    ForEach(overview.documents) { document in
                        Button(document.title) { open(document) }.frame(minHeight: 44).font(.subheadline)
                    }
                }.font(.subheadline)
            }
            Button("All " + (root.kind == .institution ? "bank" : "service") + " details") { open(root) }
                .font(.subheadline.weight(.medium)).frame(minHeight: 44)
            if root.kind == .institution {
                Text(root.lastSyncedAt.map { "Bank updated " + $0.formatted(date: .abbreviated, time: .shortened) } ?? "Saved balances · bank update time unavailable")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
        .tint(Color.zifrGold)
        .buttonStyle(.borderless)
        .accessibilityIdentifier("search-overview-" + root.id)
    }

    @ViewBuilder private var credentials: some View {
        if !root.login.isEmpty || root.website != nil {
            VStack(alignment: .leading, spacing: 4) {
                if !root.login.isEmpty { Text(root.login).font(.subheadline).foregroundStyle(.secondary).lineLimit(nil).fixedSize(horizontal: false, vertical: true).textSelection(.enabled) }
                let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 16))
                layout {
                    if !root.login.isEmpty {
                        Button { SearchCredentialAccess.copy(root.login) } label: { Label("Copy login", systemImage: "doc.on.doc").frame(minHeight: 44) }
                    }
                    if let url = SearchBrand.websiteURL(root.website) {
                        Link(destination: url) { Label("Open website", systemImage: "arrow.up.right.square").frame(minHeight: 44) }
                    }
                }.font(.subheadline)
            }
        }
        if root.credential == .available { SearchPasswordControls(recordID: root.id) }
        else if root.credential == .locked { Text(SecurityService.lockedValueLabel).font(.caption).foregroundStyle(.secondary) }
    }

    private func childRow(_ child: SearchRecord) -> some View {
        DisclosureGroup(isExpanded: Binding(get: { expanded.contains(child.id) }, set: { value in
            if value { expanded.insert(child.id) } else { expanded.remove(child.id) }
        })) {
            VStack(alignment: .leading, spacing: 10) {
                if let purpose = child.safeDetails["purpose"], !purpose.isEmpty { Text(purpose).font(.subheadline).foregroundStyle(.secondary) }
                if let renewal = child.safeDetails["renewalMode"] { Text("Payment mode · " + renewal).font(.caption).foregroundStyle(.secondary) }
                paymentLinks(child)
                let transactions = overview.linked(to: child, kinds: [.transaction]).sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
                history(transactions)
                if transactions.count > historyLimit {
                    Button("Show more transactions") { historyLimit += 10 }.font(.subheadline).frame(minHeight: 44)
                }
                Button("Service details") { open(child) }.font(.subheadline).frame(minHeight: 44)
            }.padding(.top, 8)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    SearchResultLogo(record: child, size: 28)
                    Text(child.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                }
                Text((child.serviceType?.capitalized ?? "Service") + " · " + billingLabel(child))
                    .font(.subheadline).foregroundStyle(.primary)
                schedule(child)
                if !expanded.contains(child.id) { paymentSummary(child) }
                if child.financialFacts["status"] != "Active" { Text(child.financialFacts["status"] ?? "").font(.caption).foregroundStyle(.secondary) }
            }.padding(.vertical, 6)
        }.accessibilityIdentifier("search-subservice-" + child.id)
    }
    private func serviceFacts(_ record: SearchRecord, prominent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(billingLabel(record)).font(prominent ? .title2.weight(.semibold) : .headline).monospacedDigit()
            schedule(record)
            paymentLinks(record)
            if let status = record.financialFacts["status"], status != "Active" { Text(status).font(.caption).foregroundStyle(.secondary) }
        }
    }
    private func schedule(_ record: SearchRecord) -> some View {
        Text(record.dueDate.map { (record.serviceType == "bill" ? "Next payment: " : "Renews: ") + $0.formatted(date: .abbreviated, time: .omitted) } ?? "Next payment date not saved")
            .font(.caption).foregroundStyle(.secondary)
    }
    private func paymentSummary(_ record: SearchRecord) -> some View {
        let sources = overview.paymentSources(for: record)
        let text = sources.isEmpty ? record.safeDetails["paymentMethod"] ?? "" : sources.map(paymentName).joined(separator: ", ")
        return Text(text.isEmpty ? "Payment method not saved" : "Paid with: " + text).font(.caption).foregroundStyle(.secondary)
    }
    @ViewBuilder private func paymentLinks(_ record: SearchRecord) -> some View {
        let sources = overview.paymentSources(for: record)
        if sources.isEmpty { paymentSummary(record) }
        else {
            ForEach(sources) { source in
                Button { open(source) } label: {
                    HStack(spacing: 8) {
                        SearchResultLogo(record: source, size: 24)
                        Text("Paid with: " + paymentName(source)).font(.subheadline)
                        Image(systemName: "chevron.right").font(.caption2)
                    }.frame(minHeight: 44)
                }
            }
        }
    }
    private func balanceRow(_ record: SearchRecord) -> some View {
        Button { open(record) } label: {
            VStack(alignment: .leading, spacing: 4) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        Text(paymentName(record)).font(.subheadline)
                        Spacer(minLength: 8)
                        balanceValue(record).fixedSize()
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(paymentName(record)).font(.subheadline)
                        balanceValue(record)
                    }
                }.foregroundStyle(.primary)
                if let type = record.financialFacts["accountType"], SearchText.normalize(type) != record.normalizedTitle {
                    Text(type).font(.caption).foregroundStyle(.secondary)
                }
                if let available = record.availableAmount {
                    Text((record.balanceCategory == .credit ? "Available credit: " : "Available: ") + SearchText.money(available, currency: record.currency))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.vertical, 4).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
    private func balanceValue(_ record: SearchRecord) -> some View {
        Text(record.amount.map { SearchText.money($0, currency: record.currency) + balanceSuffix(record) } ?? "Balance unavailable")
            .font(.headline).monospacedDigit()
    }
    private func balanceSuffix(_ record: SearchRecord) -> String {
        switch record.balanceCategory { case .credit: return " owed"; case .loan: return " remaining"; case .receivable: return " receivable"; default: return "" }
    }
    private func paymentName(_ record: SearchRecord) -> String { record.title + (record.last4.isEmpty ? "" : " ••" + record.last4) }
    private func billingAmount(_ record: SearchRecord) -> Decimal { record.financialFacts["billingAmount"].flatMap { Decimal(string: $0) } ?? 0 }
    private func billingLabel(_ record: SearchRecord) -> String {
        if record.safeDetails["pricingModel"] == "free" { return "Free" }
        guard let value = record.financialFacts["billingAmount"], let amount = Decimal(string: value) else { return "Amount unavailable" }
        let cycle = record.financialFacts["billingCycle"]?.lowercased() ?? "unknown billing cycle"
        let unit = ["monthly": "month", "yearly": "year", "annual": "year", "annually": "year", "weekly": "week", "quarterly": "quarter"][cycle] ?? cycle
        return SearchText.money(amount, currency: record.currency) + " / " + unit
    }
    private func transactionLabel(_ record: SearchRecord) -> String {
        let amount = record.amount.map { SearchText.money($0, currency: record.currency) } ?? "Amount unavailable"
        return amount + (record.date.map { " · " + $0.formatted(date: .abbreviated, time: .omitted) } ?? " · Date unavailable") + (record.pending ? " · Pending" : (record.flow.isEmpty ? "" : " · " + record.flow.capitalized))
    }
    @ViewBuilder private func history(_ records: [SearchRecord]) -> some View {
        if records.isEmpty { Text("No linked transactions in the loaded history.").font(.caption).foregroundStyle(.secondary).padding(.vertical, 8) }
        else {
            ForEach(records.prefix(historyLimit)) { record in
                Button { open(record) } label: {
                    HStack(spacing: 10) {
                        SearchResultLogo(record: record, size: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(record.title).foregroundStyle(.primary)
                            Text(transactionLabel(record)).foregroundStyle(.secondary)
                        }.font(.subheadline)
                    }.frame(minHeight: 44)
                }.buttonStyle(.plain)
            }
        }
    }
}
