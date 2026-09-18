import SwiftUI

struct SearchWebsiteButton: View {
    let record: SearchRecord
    var body: some View {
        if let url = SearchBrand.websiteURL(record.website) {
            Link(destination: url) {
                Image(systemName: "arrow.up.right.square")
                    .font(.subheadline).foregroundStyle(Color(white: 0.72))
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(record.title) website")
        }
    }
}

/// Native-cycle amounts share the same compact layout as the service cards.
struct SearchBillingAmounts: View {
    let totals: [SearchBillingTotal]
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                ForEach(Array(totals.enumerated()), id: \.element.id) { index, total in
                    if index > 0 { Rectangle().fill(Color.zifrBorder).frame(width: 1, height: 16) }
                    amount(total)
                }
            }.fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(totals) { amount($0) }
            }.fixedSize(horizontal: false, vertical: true)
        }.fixedSize(horizontal: false, vertical: true)
    }
    private func amount(_ total: SearchBillingTotal) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(total.formatted).font(.headline).monospacedDigit().foregroundStyle(.primary)
            Text("/" + total.suffix).font(.footnote.weight(.medium)).foregroundStyle(Color.zifrGold)
        }.accessibilityElement(children: .combine)
    }
}

struct SearchPaymentDetails: View {
    let sources: [SearchRecord]
    let fallback: String
    var open: (SearchRecord) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if sources.isEmpty {
                Text(fallback.isEmpty ? "Payment method not saved" : "Paid with: " + fallback)
                    .font(.footnote)
            } else {
                ForEach(sources) { source in
                    Button { open(source) } label: {
                        HStack(spacing: 5) {
                            Text("Paid with: " + source.title + (source.last4.isEmpty ? "" : " ••" + source.last4))
                                .fixedSize(horizontal: false, vertical: true)
                            Image(systemName: "chevron.right").font(.caption2)
                        }.font(.footnote).frame(minHeight: 44, alignment: .leading)
                    }.buttonStyle(.plain)
                }
            }
        }.foregroundStyle(Color.zifrGold).fixedSize(horizontal: false, vertical: true)
    }
}

struct SearchPaymentSchedule: View {
    let date: Date?
    var body: some View {
        Text(date.map { "Next payment: " + $0.formatted(date: .abbreviated, time: .omitted) } ?? "Next payment date not saved")
            .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}

struct SearchRecordSummary: View {
    let record: SearchRecord
    var paymentSources: [SearchRecord] = []
    var open: (SearchRecord) -> Void = { _ in }
    var body: some View {
        if record.kind == .subscription {
            VStack(alignment: .leading, spacing: 4) {
                if record.safeDetails["pricingModel"] == "free" { Text("Free").font(.headline) }
                else { SearchBillingAmounts(totals: SearchBillingTotal.totals(for: [record])) }
                SearchPaymentDetails(sources: paymentSources, fallback: record.safeDetails["paymentMethod"] ?? "", open: open)
                SearchPaymentSchedule(date: record.dueDate)
            }.fixedSize(horizontal: false, vertical: true)
        } else if let amount = record.amount, record.balanceCategory != nil {
            VStack(alignment: .leading, spacing: 4) {
                Text(SearchText.money(amount, currency: record.currency)).font(.headline).monospacedDigit()
                if let available = record.availableAmount {
                    Text((record.balanceCategory == .credit ? "Available credit: " : "Available: ") + SearchText.money(available, currency: record.currency))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }
}

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
            header
            SearchCredentialBoxes(record: root)
            ForEach(overview.additionalLogins) { record in
                DisclosureGroup("Saved login · " + record.title) {
                    SearchCredentialBoxes(record: record).padding(.vertical, 8)
                }.font(.subheadline)
            }
            if root.kind == .subscription {
                ForEach(overview.children.prefix(3)) { child in childRow(child) }
                if overview.children.count > 3 {
                    DisclosureGroup("More subservices (\(overview.children.count - 3))") {
                        ForEach(overview.children.dropFirst(3)) { child in childRow(child) }
                    }.font(.subheadline)
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
                                    Text((service.serviceType?.capitalized ?? "Service") + " · " + billingLabel(service)).font(.callout).foregroundStyle(.secondary)
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
                    Text("Miloom access · " + role).font(.callout).foregroundStyle(.secondary)
                    if let sender = root.safeDetails["sharedBy"], !sender.isEmpty {
                        Text("Shared by " + sender).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            Divider().overlay(Color.zifrBorder)
            DisclosureGroup {
                history(overview.transactions)
                if !overview.merchantMatchedTransactionIDs.isEmpty {
                    Text("Includes matching merchant charges for this company.").font(.footnote).foregroundStyle(.secondary)
                }
                if overview.transactions.count > historyLimit {
                    Button("Show more transactions (\(overview.transactions.count - historyLimit))") { historyLimit += 10 }
                        .font(.subheadline).frame(minHeight: 44)
                }
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(root.kind == .institution ? "Transactions" : "Charge history").font(.subheadline.weight(.medium))
                    if let latest = overview.transactions.first {
                        Text("Latest: " + transactionLabel(latest)).font(.footnote).foregroundStyle(.secondary)
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
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
        .tint(Color.zifrGold)
        .buttonStyle(.borderless)
        .accessibilityIdentifier("search-overview-" + root.id)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            SearchResultLogo(record: root, size: 40).frame(width: 56, height: 56).padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 2) {
                    Button { open(root) } label: {
                        Text(root.title).font(.headline).foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true).frame(minHeight: 44, alignment: .leading)
                    }.buttonStyle(.plain)
                    SearchWebsiteButton(record: root)
                    Spacer(minLength: 0)
                }
                if root.kind == .subscription && !overview.children.isEmpty {
                    if !overview.billingTotals.isEmpty { SearchBillingAmounts(totals: overview.billingTotals) }
                    else { Text(overview.hasUnknownAmount ? "Amount unavailable" : "No active charges").font(.headline) }
                    SearchPaymentDetails(sources: headerPaymentSources, fallback: root.safeDetails["paymentMethod"] ?? "", open: open)
                    SearchPaymentSchedule(date: ([root] + overview.children).filter { $0.activeService }.compactMap(\.dueDate).min())
                    Text("\(overview.children.count) subservices" + (billingAmount(root) > 0 ? " + base service" : ""))
                        .font(.footnote).foregroundStyle(.secondary)
                    if overview.hasUnknownAmount { Text("Partial total · an amount is not saved").font(.footnote).foregroundStyle(.secondary) }
                } else { SearchRecordSummary(record: root, paymentSources: overview.paymentSources(for: root), open: open) }
                Text(root.company + " · " + (root.kind == .institution ? "Bank" : (overview.children.isEmpty ? root.serviceType?.capitalized ?? "Service" : "Service account")))
                    .font(.footnote).foregroundStyle(.secondary)
                if let status = root.financialFacts["status"], status != "Active" {
                    Text(status).font(.footnote).foregroundStyle(.secondary)
                }
            }.fixedSize(horizontal: false, vertical: true)
        }.fixedSize(horizontal: false, vertical: true)
    }

    private var headerPaymentSources: [SearchRecord] {
        var seen = Set<String>()
        return ([root] + overview.children).filter { $0.activeService && billingAmount($0) > 0 }
            .flatMap { overview.paymentSources(for: $0) }
            .filter { seen.insert($0.balanceIdentity ?? $0.id).inserted }
    }

    private func childRow(_ child: SearchRecord) -> some View {
        DisclosureGroup(isExpanded: Binding(get: { expanded.contains(child.id) }, set: { value in
            if value { expanded.insert(child.id) } else { expanded.remove(child.id) }
        })) {
            VStack(alignment: .leading, spacing: 10) {
                if let purpose = child.safeDetails["purpose"], !purpose.isEmpty { Text(purpose).font(.callout).foregroundStyle(.secondary) }
                if let renewal = child.safeDetails["renewalMode"] { Text("Payment mode · " + renewal).font(.footnote).foregroundStyle(.secondary) }
                ForEach(overview.paymentSources(for: child)) { source in
                    Button("Open " + paymentName(source)) { open(source) }.font(.footnote).frame(minHeight: 44)
                }
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
                paymentSummary(child)
                schedule(child)
                if child.financialFacts["status"] != "Active" { Text(child.financialFacts["status"] ?? "").font(.footnote).foregroundStyle(.secondary) }
            }.padding(.vertical, 6)
        }.accessibilityIdentifier("search-subservice-" + child.id)
    }
    private func schedule(_ record: SearchRecord) -> some View { SearchPaymentSchedule(date: record.dueDate) }
    private func paymentSummary(_ record: SearchRecord) -> some View {
        let sources = overview.paymentSources(for: record)
        let text = sources.isEmpty ? record.safeDetails["paymentMethod"] ?? "" : sources.map(paymentName).joined(separator: ", ")
        return Text(text.isEmpty ? "Payment method not saved" : "Paid with: " + text).font(.footnote).foregroundStyle(Color.zifrGold)
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
                    Text(type).font(.footnote).foregroundStyle(.secondary)
                }
                if let available = record.availableAmount {
                    Text((record.balanceCategory == .credit ? "Available credit: " : "Available: ") + SearchText.money(available, currency: record.currency))
                        .font(.footnote).foregroundStyle(.secondary)
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
        if records.isEmpty { Text("No matching charges found in your loaded transactions.").font(.footnote).foregroundStyle(.secondary).padding(.vertical, 8) }
        else {
            ForEach(records.prefix(historyLimit)) { record in
                Button { open(record) } label: {
                    HStack(spacing: 10) {
                        SearchResultLogo(record: record, size: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(record.title).foregroundStyle(.primary)
                            Text(transactionLabel(record)).font(.callout).foregroundStyle(.secondary)
                        }.font(.subheadline)
                    }.frame(minHeight: 44)
                }.buttonStyle(.plain)
            }
        }
    }
}
