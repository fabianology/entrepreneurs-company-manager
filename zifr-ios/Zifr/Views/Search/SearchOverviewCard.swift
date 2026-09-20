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
                        HStack(spacing: 6) {
                            SearchResultLogo(record: source, size: 22)
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

/// Animate the occupied height while keeping the content at its natural size and
/// anchored at the top. Clipping reveals it downward instead of fading or scaling.
private struct SearchAccordionLayout: Layout {
    var fraction: CGFloat
    var animatableData: CGFloat {
        get { fraction }
        set { fraction = newValue }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        let size = content.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: size.width, height: size.height * min(1, max(0, fraction)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, anchor: .topLeading,
                             proposal: ProposedViewSize(width: bounds.width, height: nil))
    }
}

private struct SearchAccordionContent<Content: View>: View {
    let isExpanded: Bool
    @ViewBuilder var content: Content

    var body: some View {
        SearchAccordionLayout(fraction: isExpanded ? 1 : 0) { content }
            .clipped()
            .allowsHitTesting(isExpanded)
            .accessibilityElement(children: .contain)
            .accessibilityHidden(!isExpanded)
    }
}

/// Touch-sized disclosure rows, retaining SwiftUI's independent expansion state.
/// Uses the same trailing chevrons and separators as the app's institution accordions.
struct SearchDisclosureStyle: DisclosureGroupStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().overlay(Color.white.opacity(0.06))
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    configuration.label
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(configuration.isExpanded ? -180 : 0))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.zifrGold)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(configuration.isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint(configuration.isExpanded ? "Hides details" : "Shows details")
            SearchAccordionContent(isExpanded: configuration.isExpanded) {
                VStack(alignment: .leading, spacing: 12) { configuration.content }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 12)
            }
        }
    }
}

struct SearchOverviewCard: View {
    let overview: SearchOverview
    var open: (SearchRecord) -> Void
    @State private var expanded: Set<String>
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(overview: SearchOverview, open: @escaping (SearchRecord) -> Void) {
        self.overview = overview; self.open = open
        _expanded = State(initialValue: overview.expandedChildIDs)
    }
    private var root: SearchRecord { overview.root }
    private var grouped: Bool { root.kind == .subscription && !overview.children.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            VStack(alignment: .leading, spacing: 24) {
                SearchCredentialBoxes(record: root)
                ForEach(overview.additionalLogins) { record in
                    DisclosureGroup("Saved login · " + record.title) {
                        SearchCredentialBoxes(record: record).padding(.vertical, 8)
                    }.font(.subheadline)
                }
                if grouped {
                    ForEach(overview.serviceRows) { service in serviceRow(service) }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Account Charge History").font(.subheadline.weight(.medium))
                        SearchPastCharges(records: overview.transactions, open: open)
                        if !overview.merchantMatchedTransactionIDs.isEmpty {
                            Text("Includes matching merchant charges for this entity. Unassigned charges remain in account history.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                } else if root.kind == .subscription {
                    chargeDetails(root)
                }
                if root.kind == .institution { bankDetails }
                supportingDetails
                Button("All " + (root.kind == .institution ? "bank" : "service") + " details") { open(root) }
                    .font(.subheadline.weight(.medium)).frame(minHeight: 44)
            }.padding(.horizontal, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.075), in: RoundedRectangle(cornerRadius: 26))
        .tint(Color.zifrGold)
        .buttonStyle(.borderless)
        .disclosureGroupStyle(SearchDisclosureStyle())
        .accessibilityIdentifier("search-overview-" + root.id)
        .onChange(of: overview.expandedChildIDs) { _, ids in expanded = ids }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                SearchResultLogo(record: root, size: 48)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 2) {
                        Button { open(root) } label: {
                            Text(root.title).font(.title3.weight(.semibold)).foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }.buttonStyle(.plain)
                        // Keep the website's 44-point touch target without making the title row taller.
                        if SearchBrand.websiteURL(root.website) != nil {
                            Color.clear.frame(width: 44, height: 24)
                                .overlay { SearchWebsiteButton(record: root) }
                        }
                        Spacer(minLength: 0)
                    }
                    if root.kind == .subscription {
                        if grouped {
                            if overview.billingTotals.isEmpty {
                                Text(overview.hasUnknownAmount ? "Amount unavailable" : "No active charges").font(.headline)
                            } else { SearchBillingAmounts(totals: overview.billingTotals) }
                        } else if root.safeDetails["pricingModel"] == "free" {
                            Text("Free").font(.headline)
                        } else { SearchBillingAmounts(totals: SearchBillingTotal.totals(for: [root])) }
                    } else {
                        bankCountsText.font(.footnote.weight(.medium))
                            .foregroundStyle(Color.zifrGold)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel(overview.bankCounts.label)
                    }
                }
                .frame(minHeight: 48, alignment: .top)
                .fixedSize(horizontal: false, vertical: true)
            }
            if root.kind == .subscription && !grouped {
                Text(SearchScheduleLabel.header(root)).font(.footnote).foregroundStyle(Color.zifrGold)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 62)
            }
            if grouped {
                Text(overview.serviceCountsLabel).font(.footnote.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                if overview.hasUnknownAmount {
                    Text("Partial total · an amount is not saved").font(.footnote).foregroundStyle(.secondary)
                }
            }
            if let status = root.financialFacts["status"], status != "Active" {
                Text(status).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 20))
    }

    private var bankCountsText: Text {
        let counts = overview.bankCounts
        return Text("\(Text(counts.accounts, format: .number).foregroundColor(.white)) \(counts.accounts == 1 ? "Account" : "Accounts") | \(Text(counts.cards, format: .number).foregroundColor(.white)) \(counts.cards == 1 ? "Card" : "Cards") | \(Text(counts.loans, format: .number).foregroundColor(.white)) \(counts.loans == 1 ? "Loan" : "Loans")")
    }

    private func serviceRow(_ record: SearchRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) {
                    if expanded.contains(record.id) { expanded.remove(record.id) }
                    else { expanded.insert(record.id) }
                }
            } label: {
                HStack(spacing: 10) {
                    SearchResultLogo(record: record, size: 30)
                    Text(record.title).font(.title3.weight(.medium)).foregroundStyle(.primary)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(expanded.contains(record.id) ? -180 : 0))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }.frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(expanded.contains(record.id) ? "Expanded" : "Collapsed")
            .accessibilityHint(expanded.contains(record.id) ? "Hides charge history" : "Shows charge history")
            .accessibilityIdentifier("search-subservice-" + record.id)
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 5))
            layout {
                HStack(spacing: 5) {
                    Circle().fill(record.activeService ? Color.zifrGreen : Color.secondary).frame(width: 4, height: 4)
                    Text((record.serviceType?.capitalized ?? "Service") + (dynamicTypeSize.isAccessibilitySize ? "" : " •"))
                        .font(.subheadline)
                }
                if record.safeDetails["pricingModel"] == "free" { Text("Free").font(.subheadline) }
                else { SearchBillingAmounts(totals: SearchBillingTotal.totals(for: [record])) }
            }
            SearchPaymentDetails(sources: overview.paymentSources(for: record),
                fallback: record.safeDetails["paymentMethod"] ?? "", open: open)
            schedule(record)
            if let purpose = record.safeDetails["purpose"], !purpose.isEmpty {
                Text("Purpose: " + purpose).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }
            if !record.activeService {
                Text(record.financialFacts["status"] ?? "Inactive").font(.footnote).foregroundStyle(.secondary)
            }
            SearchAccordionContent(isExpanded: expanded.contains(record.id)) {
                VStack(alignment: .leading, spacing: 4) {
                    chargeDetails(record).padding(.top, 12)
                    Button("Service details") { open(record) }.font(.subheadline).frame(minHeight: 44)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func schedule(_ record: SearchRecord) -> some View {
        Text(SearchScheduleLabel.text(record)).font(.footnote).fixedSize(horizontal: false, vertical: true)
    }

    private func chargeDetails(_ record: SearchRecord) -> some View {
        SearchChargeDetails(record: record, summary: overview.chargeSummaries[record.id],
            sources: overview.paymentSources(for: record), transactions: overview.serviceTransactions[record.id] ?? [], open: open)
            .id(record.id)
    }

    private var bankDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(overview.balances.prefix(3)) { balance in balanceRow(balance) }
            if overview.balances.count > 3 {
                DisclosureGroup("All accounts (\(overview.balances.count))") {
                    ForEach(overview.balances.dropFirst(3)) { balance in balanceRow(balance) }
                }.font(.subheadline)
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
                                Text(service.parentServiceID == nil ? service.title : (service.safeDetails["parentService"] ?? "Service") + " · " + service.title)
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.caption)
                            }.font(.subheadline).frame(minHeight: 44)
                        }.buttonStyle(.plain)
                    }
                }.font(.subheadline)
            }
            SearchPastCharges(records: overview.transactions, title: "Transactions", open: open)
            Text(root.lastSyncedAt.map { "Bank updated " + $0.formatted(date: .abbreviated, time: .shortened) } ?? "Saved balances · bank update time unavailable")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var supportingDetails: some View {
        if !overview.documents.isEmpty || root.safeDetails["yourAccess"] != nil {
            DisclosureGroup("More details") {
                VStack(alignment: .leading, spacing: 8) {
                    if let role = root.safeDetails["yourAccess"] {
                        Text("Miloom access · " + role).font(.footnote).foregroundStyle(.secondary)
                    }
                    if let sender = root.safeDetails["sharedBy"], !sender.isEmpty {
                        Text("Shared by " + sender).font(.footnote).foregroundStyle(.secondary)
                    }
                    ForEach(overview.documents) { document in
                        Button(document.title) { open(document) }.font(.subheadline).frame(minHeight: 44)
                    }
                }
            }.font(.subheadline)
        }
        if root.kind == .subscription && !overview.balances.isEmpty {
            DisclosureGroup("Linked loans") { ForEach(overview.balances) { balanceRow($0) } }.font(.subheadline)
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
}

enum SearchScheduleLabel {
    private static func autopay(_ record: SearchRecord) -> String {
        let mode = record.safeDetails["renewalMode"]?.lowercased()
        if mode == "auto" || mode == "automatic" { return " • Auto pay on" }
        return mode == "manual" ? " • Auto pay off" : ""
    }
    static func header(_ record: SearchRecord) -> String {
        guard let date = record.scheduledDueDate ?? record.dueDate else { return text(record) }
        let cycle = record.financialFacts["billingCycle"]?.lowercased() ?? ""
        let formatter = NumberFormatter(); formatter.numberStyle = .ordinal
        let day = Calendar.current.component(.day, from: date)
        let ordinal = formatter.string(from: NSNumber(value: day)) ?? String(day)
        if cycle == "monthly" { return "Due " + ordinal + " every month" + autopay(record) }
        return text(record)
    }
    static func text(_ record: SearchRecord) -> String {
        let due = (record.scheduledDueDate ?? record.dueDate).map { "Next payment: " + $0.formatted(date: .abbreviated, time: .omitted) }
            ?? "Next payment date not saved"
        return due + autopay(record)
    }
}

struct SearchChargeDetails: View {
    let record: SearchRecord
    let summary: SearchChargeSummary?
    let sources: [SearchRecord]
    let transactions: [SearchRecord]
    var open: (SearchRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Charge History").font(.subheadline.weight(.medium))
            SearchPaymentDetails(sources: sources, fallback: record.safeDetails["paymentMethod"] ?? "", open: open)
            VStack(alignment: .leading, spacing: 5) {
                Text(dueLabel + " • " + (record.fundingCoverage?.status.rawValue ?? "Coverage unavailable"))
                if let latest = summary?.latest {
                    Text("Last: " + SearchPastCharges.transactionLabel(latest))
                } else { Text("No posted charges found") }
                if let first = summary?.firstDate {
                    let months = summary?.elapsedMonths ?? 0
                    Text("Charge history since " + first.formatted(date: .abbreviated, time: .omitted)
                        + (months > 0 ? " (\(months) \(months == 1 ? "month" : "months"))" : ""))
                }
                if let count = summary?.observedIncreases {
                    Text(count == 0 ? "No charge increases observed" : "\(count) charge \(count == 1 ? "increase" : "increases") observed")
                } else { Text("Not enough history to compare charges") }
            }.font(.subheadline).fixedSize(horizontal: false, vertical: true)
            DisclosureGroup("Coverage details") {
                Text(record.fundingCoverage?.reason ?? (record.fundingCoverage == nil
                    ? "Coverage is unavailable for inactive services, missing dates, or payments outside the next 30 days."
                    : "Based on recorded available funds or credit for all known charges sharing this payment source in the next 30 days."))
                    .font(.footnote).foregroundStyle(.secondary)
                if record.fundingCoverage?.reason != nil {
                    Text("Coverage considers all known charges sharing this payment source in the next 30 days.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }.font(.footnote).padding(.top, 4)
            SearchPastCharges(records: transactions, open: open)
        }
    }
    private var dueLabel: String {
        guard let date = record.scheduledDueDate ?? record.dueDate else { return "Due date not saved" }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0
        if days == 0 { return "Due today" }
        if days < 0 { return "Overdue by \(-days) days" }
        return "Due in \(days) \(days == 1 ? "day" : "days")"
    }
}

struct SearchHistoryDisplayState {
    var expanded = false
    var showsAll = false
    func visibleCount(_ count: Int) -> Int { expanded ? (showsAll ? count : min(3, count)) : 0 }
}

struct SearchPastCharges: View {
    let records: [SearchRecord]
    var title = "Past charges"
    var open: (SearchRecord) -> Void
    @State private var display = SearchHistoryDisplayState()

    var body: some View {
        DisclosureGroup(isExpanded: $display.expanded) {
            if records.isEmpty {
                Text("No matching charges found in your loaded transactions.")
                    .font(.footnote).foregroundStyle(.secondary).padding(.vertical, 8)
            } else {
                LazyVStack(alignment: .leading, spacing: 6) {
                    // Retain the content's height while the accordion closes; its
                    // wrapper clips and hides collapsed rows from interaction/AX.
                    ForEach(records.prefix(display.showsAll ? records.count : 3)) { record in
                        Button { open(record) } label: {
                            HStack(spacing: 10) {
                                SearchResultLogo(record: record, size: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(record.title).foregroundStyle(.primary)
                                    Text(Self.transactionLabel(record)).font(.footnote).foregroundStyle(.secondary)
                                }.font(.subheadline)
                            }.frame(minHeight: 44)
                        }.buttonStyle(.plain)
                    }
                }
                if !display.showsAll && records.count > 3 {
                    Button("More (\(records.count - 3))") { display.showsAll = true }.frame(minHeight: 44)
                }
            }
        } label: { Text(title).font(.subheadline).frame(minHeight: 44, alignment: .leading) }
    }
    static func transactionLabel(_ record: SearchRecord) -> String {
        let amount = record.amount.map { SearchText.money($0, currency: record.currency) } ?? "Amount unavailable"
        return amount + (record.date.map { " • " + $0.formatted(date: .abbreviated, time: .omitted) } ?? " • Date unavailable")
            + (record.pending ? " • Pending" : (record.flow.isEmpty || record.flow == "expense" ? "" : " • " + record.flow.capitalized))
    }
}
