import SwiftUI

/// One ledger powers the receipt detail, source breakdown, and totals so a
/// supplemental charge cannot inherit its parent's frequency or payment source.
struct SubscriptionReceiptSummary {
    struct Source: Hashable {
        let id: String
        let label: String
        var matchedSavedLabel = false
    }

    struct Charge: Identifiable {
        let id: String
        let subscriptionId: UUID
        let name: String
        let amount: Double
        let cycle: SubService.BillingCycle
        let currency: String
        let source: Source
        let serviceType: RecurringServiceType

        var annualAmount: Double { cycle == .monthly ? amount * 12 : amount }
    }

    let charges: [Charge]
    var currencies: [String] { Array(Set(charges.map(\.currency))).sorted() }
    var sources: [Source] {
        Dictionary(grouping: charges, by: { $0.source.id }).values.map { group in
            var source = group[0].source
            source.matchedSavedLabel = group.contains { $0.source.matchedSavedLabel }
            return source
        }.sorted { ($0.label, $0.id) < ($1.label, $1.id) }
    }

    func total(_ cycle: SubService.BillingCycle, currency: String, serviceType: RecurringServiceType? = nil) -> Double {
        charges.filter {
            $0.cycle == cycle && $0.currency == currency && (serviceType == nil || $0.serviceType == serviceType)
        }.reduce(0) { $0 + $1.amount }
    }

    func annualTotal(currency: String) -> Double {
        total(.monthly, currency: currency) * 12 + total(.yearly, currency: currency)
    }

    init(subscriptions: [Subscription], institutions: [Institution], cards: [FinancialCard]) {
        var charges: [Charge] = []
        for sub in subscriptions where sub.status == "Active" {
            let name = sub.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let currency = sub.currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let code = currency.isEmpty ? "USD" : currency
            if !sub.isFree, sub.cost != 0 {
                charges.append(Charge(
                    id: "\(sub.id):base", subscriptionId: sub.id,
                    name: name.isEmpty ? "Unnamed Service" : name, amount: sub.cost,
                    cycle: sub.billingCycle == "Yearly" ? .yearly : .monthly, currency: code,
                    source: Self.source(paymentMethod: sub.paymentMethod, paymentMethodId: sub.paymentMethodId,
                                        plaidAccountId: sub.plaidAccountId, institutions: institutions, cards: cards),
                    serviceType: sub.resolvedServiceType
                ))
            }
            for (index, service) in sub.subServices.enumerated() where service.status == .active && service.cost != 0 {
                charges.append(Charge(
                    id: "\(sub.id):service:\(index)", subscriptionId: sub.id,
                    name: "\(name.isEmpty ? "Unnamed Service" : name) · \(service.name.isEmpty ? "Unnamed Service" : service.name)",
                    amount: service.cost, cycle: service.billingCycle, currency: code,
                    source: Self.source(paymentMethod: service.paymentMethod, paymentMethodId: service.paymentMethodId,
                                        plaidAccountId: nil, institutions: institutions, cards: cards),
                    serviceType: service.resolvedServiceType
                ))
            }
        }
        self.charges = charges
    }

    static func source(paymentMethod: String?, paymentMethodId: UUID?, plaidAccountId: String?,
                       institutions: [Institution], cards: [FinancialCard]) -> Source {
        func cardSource(_ card: FinancialCard, matchedLabel: Bool = false) -> Source {
            let bank = (card.institutionName ?? "").isEmpty ? "Paid From" : card.institutionName!
            let suffix = (card.last4 ?? "").isEmpty ? "" : " ••••\(card.last4!)"
            return Source(id: "card:\(card.id)", label: "\(bank) • \(card.name)\(suffix)", matchedSavedLabel: matchedLabel)
        }
        let label = (paymentMethod ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        func accountSource(_ institution: Institution, _ account: InstitutionAccount) -> Source {
            let name = account.name.isEmpty ? account.type : account.name
            let suffix = account.last4.isEmpty ? "" : " ••••\(account.last4)"
            return Source(id: "account:\(institution.id):\(account.id)",
                          label: "\(institution.name) • \(name)\(suffix)")
        }
        if let card = PaymentSourceResolver.card(paymentMethod: nil, paymentMethodId: paymentMethodId,
                                                plaidAccountId: plaidAccountId, cards: cards) {
            return cardSource(card)
        }
        let accounts = institutions.flatMap { institution in institution.accounts.map { (institution, $0) } }
        if let plaidAccountId, !plaidAccountId.isEmpty {
            let matches = accounts.filter { $0.1.id == plaidAccountId || $0.1.plaidAccountId == plaidAccountId }
            if matches.count == 1 { return accountSource(matches[0].0, matches[0].1) }
        }
        if let institution = institutions.first(where: { $0.id == paymentMethodId }) {
            let matches = institution.accounts.filter {
                ($0.name.isEmpty ? $0.type : $0.name).trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare(label) == .orderedSame
            }
            if matches.count == 1 { return accountSource(institution, matches[0]) }
            if institution.accounts.count == 1 { return accountSource(institution, institution.accounts[0]) }
        }
        // Recover display-only matches after a card was replaced/relinked. Never
        // override a current explicit selection, or guess from the last four alone.
        let knownSelection = cards.contains { $0.id == paymentMethodId || (plaidAccountId != nil && $0.plaidAccountId == plaidAccountId) }
            || institutions.contains { $0.id == paymentMethodId || $0.accounts.contains { account in
                plaidAccountId != nil && (account.id == plaidAccountId || account.plaidAccountId == plaidAccountId)
            } }
        if !knownSelection, !label.isEmpty {
            let candidates = cards.filter { card in
                if card.name.caseInsensitiveCompare(label) == .orderedSame { return true }
                guard let last4 = card.last4, last4.count == 4, card.network != "Other" else { return false }
                let compact = label.lowercased().filter { !$0.isWhitespace }
                let prefix = card.network.lowercased().filter { !$0.isWhitespace }
                return ["••••", "****", "xxxx"].contains { compact == "\(prefix)\($0)\(last4)" }
            }
            let accountCandidates = accounts.filter {
                ($0.1.name.isEmpty ? $0.1.type : $0.1.name).trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare(label) == .orderedSame
            }
            if candidates.count == 1, accountCandidates.isEmpty { return cardSource(candidates[0], matchedLabel: true) }
            if candidates.isEmpty, accountCandidates.count == 1, paymentMethodId == nil,
               (plaidAccountId ?? "").isEmpty {
                return accountSource(accountCandidates[0].0, accountCandidates[0].1)
            }
        }
        return Source(id: "unresolved:\(paymentMethodId?.uuidString ?? ""):\(plaidAccountId ?? ""):\(label.lowercased())",
                      label: label.isEmpty ? "Unknown payment source" : "Saved payment label • \(label)")
    }
}

struct SubscriptionReceiptView: View {
    let company: Company
    let subscriptions: [Subscription]
    let institutions: [Institution]
    let cards: [FinancialCard]

    private var activeSubscriptions: [Subscription] {
        subscriptions.filter { $0.status == "Active" }
    }

    private var summary: SubscriptionReceiptSummary {
        SubscriptionReceiptSummary(subscriptions: activeSubscriptions, institutions: institutions, cards: cards)
    }

    private let ink = BriefingReceiptTheme.ink
    private let muted = BriefingReceiptTheme.fadedInk

    var body: some View {
        ScrollView(.vertical) {
            reportContent
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollIndicators(.hidden)
        .background(Color(hex: "#1C1C1E").ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .presentationBackground(Color(hex: "#1C1C1E"))
        .preferredColorScheme(.light)
    }

    // Also used by rendering tests, without a navigation or scrolling container.
    var reportContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            reportHeader
            sectionHeader("SERVICES", icon: "square.stack.3d.up")
            if activeSubscriptions.isEmpty {
                note("No active services.")
            }
            VStack(spacing: 0) {
                ForEach(Array(activeSubscriptions.enumerated()), id: \.element.id) { index, sub in
                    if !sub.subServices.isEmpty,
                       index == 0 || activeSubscriptions[index - 1].subServices.isEmpty {
                        supplementalGroupDivider
                    }
                    mainService(sub)
                    if !sub.subServices.isEmpty {
                        Text("SUPPLEMENTAL SERVICES (\(sub.subServices.count)) · \(sub.name.isEmpty ? "Unnamed Service" : sub.name)")
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .background(ink.opacity(0.06))
                            .padding(.top, 6)
                            .accessibilityAddTraits(.isHeader)
                    }
                    ForEach(sub.subServices) { service in
                        supplementalService(service, parent: sub)
                    }
                    if !sub.subServices.isEmpty { supplementalGroupDivider }
                }
            }
            sectionHeader("PAYMENT SOURCES", icon: "creditcard")
            paymentBreakdown
            sectionHeader("CHARGE SUMMARY", icon: "sum")
            reportFooter
            Text("END OF REPORT")
                .font(.system(.caption2, design: .monospaced).weight(.medium))
                .foregroundStyle(muted)
                .frame(maxWidth: .infinity)
        }
        .padding(22)
        .background(BriefingReceiptTheme.paper)
        .clipShape(ReceiptPaperShape())
        .overlay {
            ReceiptPaperShape().stroke(ink.opacity(0.14), lineWidth: 1)
        }
        .foregroundStyle(ink)
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }

    private var reportHeader: some View {
        VStack(spacing: 5) {
            Text("SUBSCRIPTION REPORT")
                .font(.system(.headline, design: .monospaced).weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(Color(hex: "#3A3A3C"))
            Text(company.name.uppercased())
                .font(.system(.caption, design: .monospaced).weight(.semibold))
            Text(Date().formatted(date: .numeric, time: .shortened))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(muted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle().fill(ink.opacity(0.22)).frame(height: 1)
            ReceiptMarkerSectionHeader(title: title, icon: icon, highlighted: true)
        }
    }

    private func mainService(_ sub: Subscription) -> some View {
        serviceRow(
            name: sub.name.isEmpty ? "Unnamed Service" : sub.name,
            amount: sub.isFree ? "FREE" : chargeAmount(sub.cost, currency: sub.currency, yearly: sub.billingCycle == "Yearly"),
            type: sub.resolvedServiceType,
            source: sub.isFree ? nil : SubscriptionReceiptSummary.source(
                paymentMethod: sub.paymentMethod, paymentMethodId: sub.paymentMethodId,
                plaidAccountId: sub.plaidAccountId, institutions: institutions, cards: cards).label,
            schedule: sub.isFree ? nil : "Auto-pay: \(sub.renew == "Manual" ? "No" : "Yes") · Due: \(sub.billingCycle == "Yearly" ? (sub.nextRenewal ?? "—") : (sub.nextRenewal?.withOrdinal ?? "—"))",
            prominent: true
        ) {
            if let purpose = sub.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !purpose.isEmpty {
                note("Purpose: \(purpose)")
            }
            if !sub.linkedEmails.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    note("Linked emails (\(sub.linkedEmails.count))")
                    ForEach(sub.linkedEmails.indices, id: \.self) { index in
                        let email = sub.linkedEmails[index]
                        note(email.email)
                        if !email.usedFor.isEmpty { note("Purpose: \(email.usedFor)") }
                        if !email.notes.isEmpty { note("Notes: \(email.notes.joined(separator: ", "))") }
                    }
                }
            }
        }
    }

    private func supplementalService(_ service: SubService, parent: Subscription) -> some View {
        serviceRow(
            name: "- \(service.name.isEmpty ? "Unnamed Service" : service.name)",
            amount: chargeAmount(service.cost, currency: parent.currency, yearly: service.billingCycle == .yearly),
            type: service.resolvedServiceType,
            source: SubscriptionReceiptSummary.source(
                paymentMethod: service.paymentMethod, paymentMethodId: service.paymentMethodId,
                plaidAccountId: nil, institutions: institutions, cards: cards).label,
            schedule: "Auto-pay: \(service.autoPay == .manual ? "No" : "Yes") · Due: \(service.renewsOn?.formatted(date: .abbreviated, time: .omitted) ?? "—")",
            context: "Supplemental · \(parent.name.isEmpty ? "Unnamed Service" : parent.name)",
            status: service.status,
            showsDivider: service.id != parent.subServices.last?.id
        ) {
            let purpose = service.purpose.trimmingCharacters(in: .whitespacesAndNewlines)
            if !purpose.isEmpty { note("Purpose: \(purpose)") }
        }
    }

    private var supplementalGroupDivider: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0.5))
                path.addLine(to: CGPoint(x: geometry.size.width, y: 0.5))
            }
            .stroke(muted, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        }
        .frame(height: 1)
        .padding(.vertical, 4)
        .accessibilityHidden(true)
    }

    // Parent services carry more visual weight while supplemental rows remain compact.
    private func serviceRow<Details: View>(
        name: String, amount: String, type: RecurringServiceType,
        source: String?, schedule: String?, context: String? = nil,
        status: SubService.ServiceStatus = .active,
        showsDivider: Bool = true,
        prominent: Bool = false,
        @ViewBuilder details: () -> Details
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            valueRow(name, amount, emphasized: true, prominent: prominent)
            note([type.title, context].compactMap { $0 }.joined(separator: " · "))
            if let source { note("Paid from: \(source)") }
            if let schedule { note(schedule) }
            if status != .active { note("\(status.rawValue) · Excluded from totals") }
            details()
        }
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            if showsDivider { Rectangle().fill(ink.opacity(0.12)).frame(height: 0.5) }
        }
    }

    private var paymentBreakdown: some View {
        let ledger = summary
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(ledger.sources, id: \.id) { source in
                VStack(alignment: .leading, spacing: 5) {
                    Text(source.label)
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(ledger.currencies, id: \.self) { currency in
                        ForEach(SubService.BillingCycle.allCases, id: \.self) { cycle in
                            let items = ledger.charges.filter { $0.source.id == source.id && $0.currency == currency && $0.cycle == cycle }
                            if !items.isEmpty {
                                valueRow(
                                    cycle.rawValue.uppercased(),
                                    chargeAmount(items.reduce(0) { $0 + $1.amount }, currency: currency, yearly: cycle == .yearly),
                                    emphasized: true
                                )
                                ForEach(items) { item in
                                    valueRow(item.name, money(item.amount, currency: currency))
                                        .foregroundStyle(muted)
                                }
                            }
                        }
                    }
                    if source.matchedSavedLabel {
                        note("Payment source may need confirmation.")
                    }
                }
            }
            if ledger.charges.isEmpty { note("No active paid charges.") }
        }
    }

    private var reportFooter: some View {
        let ledger = summary
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(ledger.currencies.isEmpty ? ["USD"] : ledger.currencies, id: \.self) { currency in
                VStack(alignment: .leading, spacing: 10) {
                    if ledger.currencies.count > 1 {
                        Text(currency).font(.system(.caption, design: .monospaced).weight(.bold))
                    }
                    ForEach(SubService.BillingCycle.allCases, id: \.self) { cycle in
                        VStack(spacing: 5) {
                            Text("\(cycle.rawValue.uppercased()) CHARGES")
                                .font(.system(.caption2, design: .monospaced).weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
                                .background(Color(hex: "#3A3A3C"))
                            valueRow("Subscriptions", money(ledger.total(cycle, currency: currency, serviceType: .subscription), currency: currency))
                            valueRow("Bills", money(ledger.total(cycle, currency: currency, serviceType: .bill), currency: currency))
                            valueRow("TOTAL", chargeAmount(ledger.total(cycle, currency: currency), currency: currency, yearly: cycle == .yearly), emphasized: true)
                                .padding(.top, 5)
                                .overlay(alignment: .top) { Rectangle().fill(ink).frame(height: 1) }
                        }
                    }
                    valueRow("Est. annual total", money(ledger.annualTotal(currency: currency), currency: currency), emphasized: true)
                    valueRow("Avg. monthly equivalent", money(ledger.annualTotal(currency: currency) / 12, currency: currency))
                }
            }
            note("Annual total = monthly charges × 12 + yearly charges. Only active charges are included. Each supplemental service uses its own type, payment source, and billing cycle.")
        }
    }

    private func money(_ amount: Double, currency: String) -> String {
        let code = currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let formatted = amount.formatted(.currency(code: code.isEmpty ? "USD" : code))
        return code.isEmpty || code == "USD" ? formatted : "\(formatted) \(code)"
    }

    private func chargeAmount(_ amount: Double, currency: String, yearly: Bool) -> String {
        "\(money(amount, currency: currency)) / \(yearly ? "YR" : "MO")"
    }

    private func valueRow(
        _ title: String,
        _ value: String,
        emphasized: Bool = false,
        prominent: Bool = false
    ) -> some View {
        ReceiptValueRow(title: title, value: value, emphasized: emphasized, prominent: prominent)
    }

    private struct ReceiptValueRow: View {
        let title: String
        let value: String
        let emphasized: Bool
        let prominent: Bool
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize

        var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(value).fontWeight(.semibold)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Text(value)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                }
            }
        }
        .font(.system(prominent ? .footnote : .caption, design: .monospaced).weight(emphasized ? .bold : .regular))
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}
