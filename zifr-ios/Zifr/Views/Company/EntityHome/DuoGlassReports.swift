import SwiftUI

// Content surfaces sit inside the existing Liquid Glass drawer.
enum DuoGlassReportStyle {
    static let panel = Color(hex: "#0D3729")
    static let tile = LinearGradient(
        colors: [Color.zifrGreen, panel],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )
    static let border = Color.white.opacity(0.15)
    static let muted = Color(red: 0.72, green: 0.83, blue: 0.77)

    static func amount(_ value: Double, currency: String = "USD") -> String {
        let amount = value.formatted(.currency(code: currency))
        return currency == "USD" ? amount : "\(amount) \(currency)"
    }

    static func currency(_ value: String) -> String {
        let code = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return code.isEmpty ? "USD" : code
    }
}

struct DuoGlassReportBody<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14, content: content)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DuoGlassReportStyle.panel, in: RoundedRectangle(cornerRadius: 19))
                .overlay {
                    RoundedRectangle(cornerRadius: 19)
                        .strokeBorder(DuoGlassReportStyle.border, lineWidth: 1)
                        .allowsHitTesting(false)
                }
        }
        .scrollBounceBehavior(.basedOnSize)
        .foregroundStyle(.white)
        .tint(.zifrGold)
        .environment(\.colorScheme, .dark)
    }
}

struct DuoGlassReportDisclosure<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        DisclosureGroup {
            content().padding(.top, 8)
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44, alignment: .leading)
        }
        .tint(.zifrGold)
    }
}

struct DuoGlassFinancialSummary: View {
    private enum Metric {
        case cash, cardBalances, availableCredit

        var heading: String {
            switch self {
            case .cash: return "Bank accounts"
            case .cardBalances: return "Card balances by card"
            case .availableCredit: return "Available credit by card"
            }
        }
    }

    private struct CashAccount: Identifiable {
        let bank: Institution
        let account: InstitutionAccount

        var id: String { "\(bank.id):\(account.id)" }
        var currency: String { DuoGlassReportStyle.currency(account.currency) }
    }

    let institutions: [Institution]
    let creditCards: [FinancialCard]
    let availableCredit: Double
    @State private var selectedMetric: Metric = .cash
    @State private var selectedCurrency: String?

    private var cashAccounts: [CashAccount] {
        institutions.flatMap { bank in
            bank.accounts
                .filter { account in
                    let type = account.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    return ["checking", "savings"].contains(type)
                        && ExecutiveBriefingSnapshot.isActive(account.status)
                }
                .map { CashAccount(bank: bank, account: $0) }
        }
    }

    var body: some View {
        let accounts = cashAccounts
        let currencies = Set(accounts.map(\.currency)).sorted()
        let currency = selectedCurrency.flatMap { currencies.contains($0) ? $0 : nil }
            ?? (currencies.contains("USD") ? "USD" : currencies.first ?? "USD")
        let shownAccounts = accounts.filter { $0.currency == currency }

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                DuoGlassReportHeading(title: "Financial report",
                    subtitle: Date.now.formatted(date: .abbreviated, time: .omitted))
                Spacer(minLength: 0)
                if currencies.count > 1 {
                    Menu(currency) {
                        ForEach(currencies, id: \.self) { code in
                            Button(code) { selectedCurrency = code; selectedMetric = .cash }
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.zifrGold)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Cash currency, \(currency)")
                }
            }

            Button {
                selectedMetric = .cash
            } label: {
                DuoGlassMetricTile(label: "Cash on hand",
                    value: shownAccounts.isEmpty ? "—" : DuoGlassReportStyle.amount(
                        shownAccounts.reduce(0) { $0 + $1.account.balance }, currency: currency
                    ),
                    prominent: true, selected: selectedMetric == .cash)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selectedMetric == .cash ? .isSelected : [])

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { creditMetrics }
                VStack(spacing: 8) { creditMetrics }
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(selectedMetric.heading)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.zifrGold)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.bottom, 3)

                if selectedMetric == .cash {
                    if shownAccounts.isEmpty { empty("No active checking or savings accounts.") }
                    ForEach(shownAccounts) { item in
                        DuoGlassReportRow(
                            name: item.account.name.isEmpty ? item.account.type : item.account.name,
                            subtitle: accountLabel(item.bank.name, last4: item.account.last4),
                            amount: DuoGlassReportStyle.amount(item.account.balance, currency: currency)
                        )
                    }
                } else {
                    if creditCards.isEmpty { empty("No credit cards.") }
                    ForEach(creditCards) { card in
                        DuoGlassReportRow(name: card.name,
                            subtitle: accountLabel(card.institutionName ?? "", last4: card.last4 ?? ""),
                            amount: DuoGlassReportStyle.amount(
                                selectedMetric == .cardBalances ? card.balance : card.limit - card.balance
                            ))
                    }
                }
            }
        }
    }

    @ViewBuilder private var creditMetrics: some View {
        metric(.cardBalances, title: "Card balances", value: creditCards.reduce(0) { $0 + $1.balance })
        metric(.availableCredit, title: "Available credit", value: availableCredit)
    }

    private func metric(_ metric: Metric, title: String, value: Double) -> some View {
        Button {
            selectedMetric = metric
        } label: {
            DuoGlassMetricTile(label: title,
                value: creditCards.isEmpty ? "—" : DuoGlassReportStyle.amount(value),
                selected: selectedMetric == metric)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedMetric == metric ? .isSelected : [])
    }

    private func accountLabel(_ bank: String, last4: String) -> String {
        [bank, last4.isEmpty ? "" : "••\(last4)"].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func empty(_ message: String) -> some View {
        Text(message).font(.subheadline).foregroundStyle(DuoGlassReportStyle.muted).padding(.vertical, 10)
    }
}

struct DuoGlassSubscriptionSummary: View {
    let summary: SubscriptionReceiptSummary
    var showsChargeHistory = false
    @State private var expandedChargeID: String?
    @State private var selectedType: RecurringServiceType?
    @State private var selectedCurrency: String?
    @State private var isAnnual = false

    private var currency: String {
        selectedCurrency.flatMap { summary.currencies.contains($0) ? $0 : nil }
            ?? summary.currencies.first ?? "USD"
    }

    var body: some View {
        let charges = summary.charges.filter { $0.currency == currency }
        let visibleCharges = charges.filter { selectedType == nil || $0.serviceType == selectedType }
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                DuoGlassReportHeading(title: "Subscription report",
                    subtitle: Date.now.formatted(.dateTime.month(.abbreviated).year()))
                Spacer(minLength: 0)
                if summary.currencies.count > 1 {
                    Menu(currency) {
                        ForEach(summary.currencies, id: \.self) { code in
                            Button(code) { selectedCurrency = code; selectedType = nil }
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.zifrGold)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Report currency, \(currency)")
                }
            }

            billingPeriodControl

            Button {
                selectedType = nil
            } label: {
                DuoGlassMetricTile(label: isAnnual ? "Annual recurring spend" : "Monthly equivalent",
                    value: amount(charges.reduce(0) { $0 + periodAmount($1) }),
                    prominent: true, selected: selectedType == nil)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selectedType == nil ? .isSelected : [])

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { categories(charges) }
                VStack(spacing: 8) { categories(charges) }
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(selectedType == .bill ? "Bills" : selectedType == .subscription ? "Subscriptions" : "Recurring charges")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.zifrGold)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.bottom, 3)

                if visibleCharges.isEmpty {
                    Text("No active paid charges.")
                        .font(.subheadline).foregroundStyle(DuoGlassReportStyle.muted).padding(.vertical, 10)
                }
                ForEach(visibleCharges) { charge in
                    let row = DuoGlassReportRow(name: charge.name,
                        subtitle: "\(charge.cycle.rawValue) · \(charge.source.label)",
                        amount: amount(periodAmount(charge)))
                    if showsChargeHistory {
                        let expanded = expandedChargeID == charge.serviceRecordID
                        Button {
                            expandedChargeID = expanded ? nil : charge.serviceRecordID
                        } label: {
                            HStack {
                                row
                                Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(expanded ? "Expanded" : "Collapsed")
                        if expanded {
                            DuoServiceChargeDetail(charge: charge)
                                .id(charge.serviceRecordID)
                        }
                    } else {
                        row
                    }
                }
            }
        }
    }

    @ViewBuilder private var billingPeriodControl: some View {
        if #available(iOS 26.0, *) {
            billingPeriodMenu
                .menuStyle(.button)
                .buttonStyle(.glass(.clear))
                .controlSize(.large)
        } else {
            billingPeriodMenu
        }
    }

    private var billingPeriodMenu: some View {
        Menu {
            Picker("Billing period", selection: $isAnnual) {
                Text("Monthly").tag(false)
                Text("Annual").tag(true)
            }
        } label: {
            Label(isAnnual ? "Annual" : "Monthly", systemImage: "calendar")
        }
        .accessibilityLabel("Billing period")
        .accessibilityValue(isAnnual ? "Annual" : "Monthly")
    }

    @ViewBuilder private func categories(_ charges: [SubscriptionReceiptSummary.Charge]) -> some View {
        category(.subscription, title: "Subscriptions", charges: charges)
        category(.bill, title: "Bills", charges: charges)
    }

    private func category(_ type: RecurringServiceType, title: String,
                          charges: [SubscriptionReceiptSummary.Charge]) -> some View {
        Button {
            selectedType = type
        } label: {
            DuoGlassMetricTile(label: title, value: amount(charges.reduce(0) {
                $0 + ($1.serviceType == type ? periodAmount($1) : 0)
            }), selected: selectedType == type)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedType == type ? .isSelected : [])
    }

    private func periodAmount(_ charge: SubscriptionReceiptSummary.Charge) -> Double {
        isAnnual ? charge.annualAmount : charge.annualAmount / 12
    }

    private func amount(_ value: Double) -> String {
        DuoGlassReportStyle.amount(value, currency: currency)
    }
}

private struct DuoServiceChargeDetail: View {
    let charge: SubscriptionReceiptSummary.Charge
    @Environment(AppState.self) private var appState
    @State private var history: [SearchRecord]?
    @State private var historyUnavailable = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Scheduled charge", value: DuoGlassReportStyle.amount(charge.amount,
                currency: charge.currency) + " · " + charge.cycle.rawValue)
            if let renewal = charge.renewal {
                LabeledContent("Renewal", value: renewal.formatted(date: .abbreviated, time: .omitted))
            }
            Text("Posted charges").fontWeight(.semibold)
            if let history {
                if history.isEmpty { Text("No linked posted charges.") }
                ForEach(history) { record in
                    LabeledContent(record.date?.formatted(date: .abbreviated, time: .omitted) ?? record.title,
                        value: SearchText.money(record.amount ?? 0, currency: record.currency))
                }
            } else if historyUnavailable {
                Text("Charge history unavailable.")
            } else {
                ProgressView()
            }
        }
        .font(.subheadline)
        .padding(.vertical, 8)
        .task(id: appState.searchRevision) {
            history = nil
            historyUnavailable = false
            guard let user = appState.portfolioUserID,
                  let index = try? await appState.searchIndexInBackground(for: user) else {
                if !Task.isCancelled { historyUnavailable = true }
                return
            }
            let id = charge.serviceRecordID
            let posted = await Task.detached(priority: .userInitiated) {
                index.postedServiceCharges(serviceID: id)
            }.value
            if !Task.isCancelled, user == appState.portfolioUserID { history = posted }
        }
    }
}

struct DuoGlassReportHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title2.bold()).accessibilityAddTraits(.isHeader)
            Text(subtitle).font(.caption).foregroundStyle(DuoGlassReportStyle.muted)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct DuoGlassMetricTile: View {
    let label: String
    let value: String
    var prominent = false
    let selected: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: prominent ? 15 : 11)
        VStack(alignment: .leading, spacing: prominent ? 4 : 5) {
            Text(label)
                .font(prominent ? .subheadline : .caption)
                .foregroundStyle(DuoGlassReportStyle.muted)
            Text(value)
                .font(prominent ? .largeTitle.bold() : .headline)
                .monospacedDigit()
                .foregroundStyle(prominent ? Color.zifrGold : .white)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(prominent ? 16 : 11)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .background {
            if selected {
                if #available(iOS 26.0, *) {
                    Color.clear.glassEffect(.clear, in: shape)
                } else {
                    shape.fill(.ultraThinMaterial)
                }
            } else {
                shape.fill(DuoGlassReportStyle.tile)
            }
        }
        .overlay {
            if selected {
                ZifrSheetCardOutline(shape: shape)
                    .allowsHitTesting(false)
            } else {
                shape.strokeBorder(DuoGlassReportStyle.border)
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct DuoGlassReportRow: View {
    let name: String
    let subtitle: String
    let amount: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 10) {
                account
                Spacer(minLength: 8)
                value.fixedSize(horizontal: true, vertical: false)
            }
            VStack(alignment: .leading, spacing: 4) {
                account
                value
            }
        }
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(DuoGlassReportStyle.border).frame(height: 0.5) }
        .accessibilityElement(children: .combine)
    }

    private var account: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name).font(.subheadline)
            if !subtitle.isEmpty {
                Text(subtitle).font(.caption).foregroundStyle(DuoGlassReportStyle.muted)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var value: some View {
        Text(amount).font(.subheadline.weight(.semibold)).monospacedDigit()
    }
}
