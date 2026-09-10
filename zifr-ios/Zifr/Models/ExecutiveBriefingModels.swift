import Foundation

enum ExecutiveBriefingSection: String, Hashable {
    case financial = "Financial"
    case services = "Services"
    case vault = "Vault"
}

/// Card-only values; the existing breakdown projections and saved records stay unchanged.
struct ExecutiveCardMetrics {
    let bankCash: [String: Double]
    let scheduledCosts: [String: Double]
    let upcoming: UpcomingCoverageProjection
    let scheduleIncompleteCount: Int
    let hasStaleBankData: Bool
    let expiredDocuments: [CompanyDocument]
    let expiringDocuments: [CompanyDocument]
    let datedDocumentCount: Int

    init(snapshot: ExecutiveBriefingSnapshot, now: Date, calendar: Calendar = .current) {
        bankCash = snapshot.institutions.flatMap(\.accounts).filter {
            ["checking", "savings"].contains($0.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
                && ExecutiveBriefingSnapshot.isActive($0.status)
        }.reduce(into: [:]) { result, account in
            result[ExecutiveBriefingSnapshot.currency(account.currency), default: 0] += account.balance
        }

        // The shared scheduler supports monthly/yearly recurrence. Do not guess dates for
        // other cycles or change their behavior elsewhere in the app.
        let active = snapshot.subscriptions.filter { ExecutiveBriefingSnapshot.isActive($0.status) }
        var unsupported = 0
        let schedulable = active.compactMap { original -> Subscription? in
            var service = original
            service.status = "Active"
            switch service.billingCycle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "monthly": service.billingCycle = "Monthly"
            case "yearly", "annual", "annually": service.billingCycle = "Yearly"
            default:
                unsupported += 1 + service.subServices.filter { $0.status == .active }.count
                return nil
            }
            return service
        }
        // The shared window is inclusive: today through day six is seven calendar days.
        upcoming = UpcomingCoverageEngine.project(subscriptions: schedulable,
            institutions: snapshot.institutions, cards: snapshot.cards, plaidItems: snapshot.plaidItems,
            now: now, days: 6, calendar: calendar)
        scheduledCosts = upcoming.groups.reduce(into: [:]) { result, group in
            result[group.currency, default: 0] += group.totalDue
        }
        scheduleIncompleteCount = upcoming.unscheduledCount + unsupported

        let today = calendar.startOfDay(for: now)
        let staleBefore = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        hasStaleBankData = snapshot.oldestSync.map { $0 < staleBefore } ?? false
        let lastDay = calendar.date(byAdding: .day, value: 60, to: today) ?? today
        datedDocumentCount = snapshot.documents.filter { $0.expiresAt != nil }.count
        expiredDocuments = snapshot.documents.filter {
            $0.expiresAt.map { calendar.startOfDay(for: $0) < today } ?? false
        }
        expiringDocuments = snapshot.documents.filter {
            guard let expiry = $0.expiresAt.map({ calendar.startOfDay(for: $0) }) else { return false }
            return expiry >= today && expiry <= lastDay
        }
    }

    func coverageNote(for snapshot: ExecutiveBriefingSnapshot) -> String? {
        if !snapshot.isLoaded { return "Loading tracked records" }
        if snapshot.loadIssue { return "Some data unavailable · totals incomplete" }
        if snapshot.connectionIssueCount > 0 { return "Bank connection issue · totals may be incomplete" }
        if hasStaleBankData { return "Bank balances out of date · review updates" }
        if snapshot.unknownBillingCount > 0 || scheduleIncompleteCount > 0 {
            return "Service estimates incomplete · review dates and cycles"
        }
        if snapshot.companies.isEmpty { return "No profiles added" }
        if snapshot.institutions.isEmpty && snapshot.subscriptions.isEmpty && snapshot.documents.isEmpty {
            return "No records added"
        }
        return nil
    }
}

/// A read-only projection. Resource ownership, persisted totals, and connection records are never mutated.
struct ExecutiveBriefingSnapshot {
    let scope: OwnerBriefingScope
    let companies: [Company]
    let subscriptions: [Subscription]
    let institutions: [Institution]
    let cards: [FinancialCard]
    let loans: [Loan]
    let documents: [CompanyDocument]
    let records: [ResolvedTransaction]
    let financials: [ExecutiveCurrencySummary]
    let recurringCosts: [String: Double]
    let unknownBillingCount: Int
    let activeSubscriptionCount: Int
    let activeBillCount: Int
    let supplementalCount: Int
    let connectionIssueCount: Int
    let oldestSync: Date?
    let isLoaded: Bool
    let loadIssue: Bool
    let unassignedTransactionCount: Int
    let upcomingCoverage: UpcomingCoverageProjection
    let plaidItems: [PlaidItemSummary]

    init(appState: AppState, scope: OwnerBriefingScope, companyID: UUID? = nil, now: Date = Date()) {
        self.scope = scope
        companies = appState.companies.filter { scope.includes($0) && (companyID == nil || $0.id == companyID) }
        let ids = Set(companies.map(\.id))
        func includes(_ id: UUID, _ owner: UUID) -> Bool {
            ids.contains(appState.localCompanyOverrides[id.uuidString] ?? owner)
        }
        subscriptions = appState.subscriptions.filter { includes($0.id, $0.companyId) }
        institutions = appState.institutions.filter { includes($0.id, $0.companyId) }
        cards = appState.cards.filter { includes($0.id, $0.companyId) }
        loans = appState.loans.filter { includes($0.id, $0.companyId) }
        documents = appState.documents.filter { includes($0.id, $0.companyId) }
        let active = subscriptions.filter { Self.isActive($0.status) }
        activeSubscriptionCount = active.filter { $0.resolvedServiceType == .subscription }.count
        activeBillCount = active.filter { $0.resolvedServiceType == .bill }.count
        supplementalCount = active.flatMap(\.subServices).filter { $0.status == .active }.count
        var costs: [String: Double] = [:]
        var unknown = 0
        for service in active {
            let currency = Self.currency(service.currency)
            if let monthly = Self.monthlyCost(service) {
                costs[currency, default: 0] += monthly
            } else {
                unknown += 1
            }
            for addon in service.subServices where addon.status == .active {
                costs[currency, default: 0] += addon.billingCycle == .yearly ? addon.cost / 12 : addon.cost
            }
        }
        recurringCosts = costs
        unknownBillingCount = unknown
        // Resolve with existing classification and override rules, then apply local resource moves.
        let resolved = TransactionIntelligence.resolveAll(
            appState.transactions, companies: appState.companies,
            institutions: appState.institutions, cards: appState.cards,
            overrides: appState.transactionOverrides
        ).map { record -> ResolvedTransaction in
            var owner = record.companyId
            if let card = appState.cards.first(where: { $0.id.uuidString == record.accountId || $0.plaidAccountId == record.accountId }),
               owner == card.companyId || owner == nil {
                owner = appState.localCompanyOverrides[card.id.uuidString] ?? owner
            } else if let bank = appState.institutions.first(where: {
                $0.id == record.transaction.institutionId || $0.accounts.contains { $0.id == record.accountId || $0.plaidAccountId == record.accountId }
            }), owner == bank.companyId || owner == nil {
                owner = appState.localCompanyOverrides[bank.id.uuidString] ?? owner
            }
            return ResolvedTransaction(transaction: record.transaction, companyId: owner,
                companyName: appState.companies.first { $0.id == owner }?.name ?? "Unassigned",
                accountName: record.accountName, institutionName: record.institutionName, override: record.override)
        }
        unassignedTransactionCount = resolved.filter { $0.companyId == nil }.count
        records = resolved.filter { $0.companyId.map(ids.contains) ?? false }
        financials = Self.financials(records: records, now: now)
        let bankIDs = Set(institutions.map(\.id))
        let brokenIDs = Set(institutions.filter(\.isDisconnected).map(\.id))
        let items = appState.plaidItems.filter { item in
            item.institutionId.map(bankIDs.contains) ?? ids.contains(item.companyId)
        }
        plaidItems = items
        upcomingCoverage = UpcomingCoverageEngine.project(
            subscriptions: subscriptions,
            institutions: institutions,
            cards: cards,
            plaidItems: items,
            now: now
        )
        connectionIssueCount = brokenIDs.union(items.filter(\.requiresReconnect).compactMap(\.institutionId)).count
            + items.filter { $0.requiresReconnect && $0.institutionId == nil }.count
        let syncDates = institutions.compactMap(\.lastSyncedAt) + items.compactMap(\.lastSyncedAt)
        oldestSync = syncDates.min()
        isLoaded = appState.hasLoadedPortfolio
        loadIssue = appState.portfolioLoadIssue != nil
    }

    static func companyID(for obligation: PortfolioObligation, in state: AppState) -> UUID? {
        if let override = state.localCompanyOverrides[obligation.sourceId.uuidString] { return override }
        switch obligation.sourceType {
        case .company: return obligation.sourceId
        case .institution: return state.institutions.first { $0.id == obligation.sourceId }?.companyId ?? obligation.companyId
        case .subscription: return state.subscriptions.first { $0.id == obligation.sourceId }?.companyId ?? obligation.companyId
        case .card: return state.cards.first { $0.id == obligation.sourceId }?.companyId ?? obligation.companyId
        case .loan: return state.loans.first { $0.id == obligation.sourceId }?.companyId ?? obligation.companyId
        case .document: return state.documents.first { $0.id == obligation.sourceId }?.companyId ?? obligation.companyId
        case .collaborator: return obligation.companyId
        }
    }

    static func isActive(_ status: String) -> Bool {
        status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "active"
    }

    static func currency(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return trimmed.isEmpty ? "Unknown currency" : trimmed
    }

    /// Base cost only. Supplemental services are added exactly once by the projection.
    static func monthlyCost(_ service: Subscription) -> Double? {
        if service.isFree { return 0 }
        switch service.billingCycle.lowercased() {
        case "monthly": return service.cost
        case "yearly", "annual", "annually": return service.cost / 12
        case "weekly": return service.cost * 52 / 12
        case "quarterly": return service.cost / 3
        default: return nil
        }
    }

    static func financials(
        records: [ResolvedTransaction],
        now: Date,
        month: CashFlowMonth? = nil
    ) -> [ExecutiveCurrencySummary] {
        let selectedMonth = month ?? CashFlowMonth(containing: now)
        return Dictionary(grouping: records, by: { currency($0.transaction.currency) }).map { code, values in
            let insight = CashFlowInsightEngine.analyze(records: values, month: selectedMonth, anchorDate: now)
            let incomeOnly = values.filter { TransactionIntelligence.effectiveFlow(for: $0) == .income }
            let refundsOnly = values.filter { TransactionIntelligence.effectiveFlow(for: $0) == .refund }
            return ExecutiveCurrencySummary(currency: code, insight: insight,
                income: CashFlowInsightEngine.analyze(records: incomeOnly, month: selectedMonth, anchorDate: now).current.moneyIn,
                refunds: CashFlowInsightEngine.analyze(records: refundsOnly, month: selectedMonth, anchorDate: now).current.moneyIn)
        }.sorted { $0.currency < $1.currency }
    }

    var coverage: String {
        if !isLoaded { return "Waiting for portfolio data" }
        if loadIssue { return "Some portfolio data is unavailable" }
        if companies.isEmpty { return "No \(scope == .business ? "business entities" : "personal profiles") added" }
        if connectionIssueCount > 0 { return "\(connectionIssueCount) bank connection\(connectionIssueCount == 1 ? " needs" : "s need") attention · totals may be incomplete" }
        if records.isEmpty { return "No transaction history available" }
        if let oldestSync {
            return "Oldest bank update \(oldestSync.formatted(date: .abbreviated, time: .shortened))"
        }
        return "Based on available records · bank sync time unavailable"
    }

    var balances: [String: Double] {
        institutions.flatMap(\.accounts).reduce(into: [:]) { result, account in
            result[Self.currency(account.currency), default: 0] += account.balance
        }
    }
}

enum UpcomingCoverageStatus: String {
    case covered
    case atRisk
    case unknown
}

struct UpcomingCoverageCharge: Identifiable {
    let id: String
    let name: String
    let dueAt: Date
    let amount: Double
    let currency: String
    let isSupplemental: Bool
}

struct UpcomingCoverageGroup: Identifiable {
    let id: String
    let sourceName: String
    let sourceDetail: String
    let currency: String
    let charges: [UpcomingCoverageCharge]
    let availableAmount: Double?
    let availableLabel: String
    let status: UpcomingCoverageStatus
    let reason: String?
    let paymentRoutes: [String]

    var totalDue: Double { charges.reduce(0) { $0 + $1.amount } }
    var difference: Double? { availableAmount.map { $0 - totalDue } }
}

struct UpcomingCoverageProjection {
    let days: Int
    let groups: [UpcomingCoverageGroup]
    let unscheduledCount: Int

    var chargeCount: Int { groups.reduce(0) { $0 + $1.charges.count } }
    var atRiskCount: Int { groups.filter { $0.status == .atRisk }.count }
    var unknownCount: Int { groups.filter { $0.status == .unknown }.count }
}

/// Cross-references scheduled recurring charges with their existing saved payment-source links.
/// This is a read-only estimate and never changes a subscription, account, card, or connection.
enum UpcomingCoverageEngine {
    private struct ResolvedCharge {
        let key: String
        let sourceName: String
        let sourceDetail: String
        let availableAmount: Double?
        let availableLabel: String
        let unknownReason: String?
        let paymentRoute: String?
        let charge: UpcomingCoverageCharge
    }

    static func project(
        subscriptions: [Subscription],
        institutions: [Institution],
        cards: [FinancialCard],
        plaidItems: [PlaidItemSummary],
        now: Date = Date(),
        days: Int = 30,
        calendar: Calendar = .current
    ) -> UpcomingCoverageProjection {
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: days, to: start) ?? start
        var resolved: [ResolvedCharge] = []
        var unscheduled = 0

        for original in subscriptions where ExecutiveBriefingSnapshot.isActive(original.status) {
            let service = SubscriptionRenewalScheduler.normalized(original, now: now, calendar: calendar)
            let currency = ExecutiveBriefingSnapshot.currency(service.currency)

            if let dueAt = service.nextRenewalAt {
                if isWithin(dueAt, start: start, end: end, calendar: calendar) {
                    let charge = UpcomingCoverageCharge(
                        id: "service:\(service.id)", name: service.name, dueAt: dueAt,
                        amount: max(0, service.isFree ? 0 : service.cost), currency: currency,
                        isSupplemental: false
                    )
                    resolved.append(resolve(
                        charge, paymentMethod: service.paymentMethod,
                        paymentMethodID: service.paymentMethodId, plaidAccountID: service.plaidAccountId,
                        institutions: institutions, cards: cards, plaidItems: plaidItems, now: now,
                        calendar: calendar
                    ))
                }
            } else {
                unscheduled += 1
            }

            for addon in service.subServices where addon.status == .active {
                guard let dueAt = addon.renewsOn else {
                    unscheduled += 1
                    continue
                }
                guard isWithin(dueAt, start: start, end: end, calendar: calendar) else { continue }
                let addonMethod = addon.paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines)
                let charge = UpcomingCoverageCharge(
                    id: "service:\(service.id):addon:\(addon.id)", name: addon.name, dueAt: dueAt,
                    amount: max(0, addon.cost), currency: currency, isSupplemental: true
                )
                resolved.append(resolve(
                    charge,
                    paymentMethod: addonMethod.isEmpty ? service.paymentMethod : addonMethod,
                    paymentMethodID: addon.paymentMethodId ?? service.paymentMethodId,
                    plaidAccountID: addon.paymentMethodId == nil && addonMethod.isEmpty ? service.plaidAccountId : nil,
                    institutions: institutions, cards: cards, plaidItems: plaidItems, now: now,
                    calendar: calendar
                ))
            }
        }

        let groups = Dictionary(grouping: resolved, by: \.key).values.map { values -> UpcomingCoverageGroup in
            let first = values[0]
            let charges = values.map(\.charge).sorted { $0.dueAt < $1.dueAt }
            let total = charges.reduce(0) { $0 + $1.amount }
            let status: UpcomingCoverageStatus
            if first.unknownReason != nil || first.availableAmount == nil {
                status = .unknown
            } else if (first.availableAmount ?? 0) >= total {
                status = .covered
            } else {
                status = .atRisk
            }
            return UpcomingCoverageGroup(
                id: first.key, sourceName: first.sourceName, sourceDetail: first.sourceDetail,
                currency: first.charge.currency, charges: charges,
                availableAmount: first.availableAmount, availableLabel: first.availableLabel,
                status: status, reason: first.unknownReason,
                paymentRoutes: Array(Set(values.compactMap(\.paymentRoute))).sorted()
            )
        }.sorted {
            if $0.status != $1.status {
                let rank: [UpcomingCoverageStatus: Int] = [.atRisk: 0, .unknown: 1, .covered: 2]
                return rank[$0.status, default: 3] < rank[$1.status, default: 3]
            }
            return ($0.charges.first?.dueAt ?? .distantFuture) < ($1.charges.first?.dueAt ?? .distantFuture)
        }

        return UpcomingCoverageProjection(days: days, groups: groups, unscheduledCount: unscheduled)
    }

    private static func resolve(
        _ charge: UpcomingCoverageCharge,
        paymentMethod: String?,
        paymentMethodID: UUID?,
        plaidAccountID: String?,
        institutions: [Institution],
        cards: [FinancialCard],
        plaidItems: [PlaidItemSummary],
        now: Date,
        calendar: Calendar
    ) -> ResolvedCharge {
        if let card = PaymentSourceResolver.card(
            paymentMethod: paymentMethod, paymentMethodId: paymentMethodID,
            plaidAccountId: plaidAccountID, cards: cards
        ) {
            let cardName = displayName(for: card)

            // A card explicitly linked to a funding account uses that account's money.
            // Grouping by the account also prevents its balance from being counted once per card.
            if let account = linkedFundingAccount(for: card, institutions: institutions) {
                return resolveAccount(
                    account, charge: charge, plaidItems: plaidItems, now: now,
                    calendar: calendar, paymentRoute: cardName
                )
            }

            // Retain the older paid-from name as a fallback for records saved before account links had IDs.
            if let paidFrom = card.paidFrom,
               let account = PaymentSourceResolver.account(
                    paymentMethod: paidFrom, paymentMethodId: nil,
                    plaidAccountId: nil, institutions: institutions
               ) {
                return resolveAccount(
                    account, charge: charge, plaidItems: plaidItems, now: now,
                    calendar: calendar, paymentRoute: cardName
                )
            }

            // A debit card's coverage comes from its backing account when that account is available.
            if !card.type.lowercased().contains("credit"),
               let account = PaymentSourceResolver.account(
                    paymentMethod: paymentMethod, paymentMethodId: paymentMethodID,
                    plaidAccountId: plaidAccountID, institutions: institutions
               ) {
                return resolveAccount(
                    account, charge: charge, plaidItems: plaidItems, now: now,
                    calendar: calendar, paymentRoute: cardName
                )
            }
            let active = ExecutiveBriefingSnapshot.isActive(card.status)
            let isUSD = charge.currency == "USD"
            let isCredit = card.type.lowercased().contains("credit")
            let available = isCredit && card.limit > 0 ? max(0, card.limit - card.balance) : nil
            let reason: String?
            if !active { reason = "Card is not active" }
            else if !isCredit { reason = "Backing account balance is unavailable" }
            else if !isUSD { reason = "Card currency is not recorded" }
            else if available == nil { reason = "Available credit is unavailable" }
            else { reason = nil }
            return ResolvedCharge(
                key: "card:\(card.id):\(charge.currency)", sourceName: cardName,
                sourceDetail: card.institutionName ?? card.type, availableAmount: available,
                availableLabel: isCredit ? "Available credit" : "Available funds",
                unknownReason: reason, paymentRoute: nil, charge: charge
            )
        }

        if let account = PaymentSourceResolver.account(
            paymentMethod: paymentMethod, paymentMethodId: paymentMethodID,
            plaidAccountId: plaidAccountID, institutions: institutions
        ) {
            return resolveAccount(account, charge: charge, plaidItems: plaidItems, now: now, calendar: calendar)
        }

        let label = paymentMethod?.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = (label?.isEmpty == false) ? label! : "Payment source not linked"
        return ResolvedCharge(
            key: "unlinked:\(source.lowercased()):\(charge.currency)", sourceName: source,
            sourceDetail: "No linked funding account", availableAmount: nil,
            availableLabel: "Available funds", unknownReason: "Link its payment account to verify funds",
            paymentRoute: nil, charge: charge
        )
    }

    private static func resolveAccount(
        _ source: (institution: Institution, account: InstitutionAccount),
        charge: UpcomingCoverageCharge,
        plaidItems: [PlaidItemSummary],
        now: Date,
        calendar: Calendar,
        paymentRoute: String? = nil
    ) -> ResolvedCharge {
        let account = source.account
        let suffix = account.last4.isEmpty ? "" : " ••••\(account.last4)"
        let accountName = (account.name.isEmpty ? account.type : account.name) + suffix
        let item = plaidItems.first { $0.institutionId == source.institution.id }
        let isLinked = item != nil || !(account.plaidAccountId ?? "").isEmpty
        let accountCurrency = ExecutiveBriefingSnapshot.currency(account.currency)
        let available: Double
        let availableLabel: String
        if account.isCard && account.limit > 0 {
            available = max(0, account.limit - account.balance)
            availableLabel = "Available credit"
        } else if let amount = account.availableBalance {
            available = amount
            availableLabel = "Available balance"
        } else {
            available = account.balance
            availableLabel = isLinked ? "Current balance" : "Recorded balance"
        }

        let reason: String?
        if source.institution.isDisconnected || item?.requiresReconnect == true {
            reason = "Bank connection needs attention"
        } else if !ExecutiveBriefingSnapshot.isActive(account.status) {
            reason = "Account is not active"
        } else if accountCurrency != charge.currency {
            reason = "Charge and account currencies do not match"
        } else if item?.isStale(referenceDate: now) == true {
            reason = "Connected balance is out of date"
        } else if isLinked, item == nil, let sync = source.institution.lastSyncedAt,
                  let staleDate = calendar.date(byAdding: .day, value: -7, to: now), sync < staleDate {
            reason = "Connected balance is out of date"
        } else if isLinked, item == nil, source.institution.lastSyncedAt == nil {
            reason = "Connected balance update time is unavailable"
        } else {
            reason = nil
        }

        return ResolvedCharge(
            key: "account:\(source.institution.id):\(account.id):\(charge.currency)",
            sourceName: accountName, sourceDetail: source.institution.name,
            availableAmount: available, availableLabel: availableLabel,
            unknownReason: reason, paymentRoute: paymentRoute, charge: charge
        )
    }

    private static func linkedFundingAccount(
        for card: FinancialCard,
        institutions: [Institution]
    ) -> (institution: Institution, account: InstitutionAccount)? {
        for institution in institutions {
            if let account = institution.accounts.first(where: { account in
                guard let linkedCardID = account.linkedCardId else { return false }
                return linkedCardID == card.id.uuidString || UUID(uuidString: linkedCardID) == card.id
            }) {
                return (institution, account)
            }
        }
        return nil
    }

    private static func displayName(for card: FinancialCard) -> String {
        let suffix = (card.last4 ?? "").isEmpty ? "" : " ••••\(card.last4!)"
        return card.name + suffix
    }

    private static func isWithin(_ date: Date, start: Date, end: Date, calendar: Calendar) -> Bool {
        let day = calendar.startOfDay(for: date)
        return day >= start && day <= end
    }
}

struct ExecutiveCurrencySummary: Identifiable {
    let currency: String
    let insight: CashFlowInsightSnapshot
    let income: Double
    let refunds: Double
    var id: String { currency }
}

enum ExecutiveBriefingLayout {
    static func visibleScopes(companies: [Company]) -> [OwnerBriefingScope] {
        var scopes: [OwnerBriefingScope] = []
        if companies.contains(where: OwnerBriefingScope.business.includes) {
            scopes.append(.business)
        }
        scopes.append(.personal)
        return scopes
    }
}

struct ExecutiveUrgentNotice: Identifiable {
    let id: String
    let title: String
    let detail: String
    let entityName: String
    let companyID: UUID?
    let sourceType: ResourceKind
    let sourceID: UUID
    let obligation: PortfolioObligation?
    let dueAt: Date?

    /// Position-plus-attention ordering is confined to the two summary cards.
    static func cardNotices(in state: AppState, scope: OwnerBriefingScope, now: Date,
        calendar: Calendar = .current) -> [Self] {
        let snapshot = ExecutiveBriefingSnapshot(appState: state, scope: scope, now: now)
        let metrics = ExecutiveCardMetrics(snapshot: snapshot, now: now, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        var ranked: [(rank: Int, notice: Self)] = notices(in: state).filter {
            $0.belongs(to: scope, in: state)
        }.map { notice in
            let overdue = notice.dueAt.map { calendar.startOfDay(for: $0) < today } ?? false
            return (overdue ? 0 : (notice.obligation == nil ? 3 : 1), notice)
        }

        func entityName(_ companyID: UUID?) -> String {
            state.companies.first { $0.id == companyID }?.name ?? "Unassigned"
        }
        var existingIDs = Set(ranked.compactMap { $0.notice.obligation?.id })
        for obligation in state.openObligations where !existingIDs.contains(obligation.id) {
            guard let due = obligation.dueAt, calendar.startOfDay(for: due) < today else { continue }
            let owner = ExecutiveBriefingSnapshot.companyID(for: obligation, in: state)
            let notice = Self(id: "overdue:\(obligation.id)", title: obligation.title,
                detail: obligation.summary, entityName: entityName(owner), companyID: owner,
                sourceType: obligation.sourceType, sourceID: obligation.sourceId,
                obligation: obligation, dueAt: due)
            if notice.belongs(to: scope, in: state) {
                existingIDs.insert(obligation.id)
                ranked.append((0, notice))
            }
        }

        for document in metrics.expiredDocuments + metrics.expiringDocuments {
            guard !ranked.contains(where: { $0.notice.sourceType == .document && $0.notice.sourceID == document.id }) else { continue }
            let expired = document.expiresAt.map { calendar.startOfDay(for: $0) < today } ?? false
            let owner = state.localCompanyOverrides[document.id.uuidString] ?? document.companyId
            ranked.append((expired ? 0 : 2, Self(id: "document:\(document.id)",
                title: "\(document.name) \(expired ? "expired" : "expires soon")",
                detail: document.expiresAt.map { "Recorded expiration: " + $0.formatted(date: .abbreviated, time: .omitted) } ?? "",
                entityName: entityName(owner), companyID: owner, sourceType: .document,
                sourceID: document.id, obligation: nil, dueAt: document.expiresAt)))
        }
        for group in metrics.upcoming.groups where group.status == .atRisk {
            guard let charge = group.charges.first,
                  let serviceID = charge.id.split(separator: ":").dropFirst().first.flatMap({ UUID(uuidString: String($0)) }),
                  let service = snapshot.subscriptions.first(where: { $0.id == serviceID }),
                  !ranked.contains(where: { $0.notice.sourceType == .subscription && $0.notice.sourceID == serviceID }) else { continue }
            let owner = state.localCompanyOverrides[service.id.uuidString] ?? service.companyId
            ranked.append((1, Self(id: "funding:\(group.id)", title: "Scheduled payments may exceed funds",
                detail: "Review \(group.sourceName) and its scheduled charges.", entityName: entityName(owner),
                companyID: owner, sourceType: .subscription, sourceID: service.id,
                obligation: nil, dueAt: charge.dueAt)))
        }
        return ranked.sorted {
            if $0.rank != $1.rank { return $0.rank < $1.rank }
            let lhs = $0.notice.dueAt ?? .distantFuture
            let rhs = $1.notice.dueAt ?? .distantFuture
            if lhs != rhs { return lhs < rhs }
            return $0.notice.id < $1.notice.id
        }.map(\.notice)
    }

    static func notices(in state: AppState) -> [Self] {
        func entity(_ companyID: UUID?, resourceID: UUID) -> String {
            let effective = state.localCompanyOverrides[resourceID.uuidString] ?? companyID
            guard let company = state.companies.first(where: { $0.id == effective }) else { return "Unassigned" }
            return "\(OwnerBriefingScope.personal.includes(company) ? "Personal" : "Business") · \(company.name)"
        }
        var notices: [Self] = []
        var brokenBankIDs = Set<UUID>()
        for bank in state.institutions where bank.isDisconnected || state.plaidItems.contains(where: { $0.institutionId == bank.id && $0.requiresReconnect }) {
            brokenBankIDs.insert(bank.id)
            notices.append(Self(id: "bank:\(bank.id)", title: "Reconnect \(bank.name)",
                detail: "Bank access needs attention. Open the account to reconnect.",
                entityName: entity(bank.companyId, resourceID: bank.id),
                companyID: state.localCompanyOverrides[bank.id.uuidString] ?? bank.companyId,
                sourceType: .institution,
                sourceID: bank.id, obligation: nil, dueAt: nil))
        }
        for item in state.plaidItems where item.requiresReconnect && !brokenBankIDs.contains(item.institutionId ?? item.id) {
            notices.append(Self(id: "item:\(item.id)", title: "Review \(item.institutionName ?? "bank connection")",
                detail: "This connection needs attention. Review its entity’s financial accounts.",
                entityName: entity(item.companyId, resourceID: item.companyId), companyID: item.companyId,
                sourceType: .company,
                sourceID: item.companyId, obligation: nil, dueAt: nil))
        }
        var seen = Set<String>()
        for obligation in state.openObligations.filter({ $0.severity == .urgent }).sorted(by: { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }) {
            let connectionNotice = ["connection", "reconnect", "reauth", "stale"].contains { obligation.kind.lowercased().contains($0) }
            if obligation.sourceType == .institution && brokenBankIDs.contains(obligation.sourceId) && connectionNotice { continue }
            let key = "\(obligation.sourceType.rawValue):\(obligation.sourceId):\(obligation.kind)"
            guard seen.insert(key).inserted else { continue }
            notices.append(Self(id: key, title: obligation.title, detail: obligation.summary,
                entityName: entity(obligation.companyId, resourceID: obligation.sourceId),
                companyID: ExecutiveBriefingSnapshot.companyID(for: obligation, in: state),
                sourceType: obligation.sourceType, sourceID: obligation.sourceId,
                obligation: obligation, dueAt: obligation.dueAt))
        }
        return notices
    }

    func belongs(to scope: OwnerBriefingScope, in state: AppState) -> Bool {
        guard let companyID,
              let company = state.companies.first(where: { $0.id == companyID })
        else {
            let hasBusiness = state.companies.contains(where: OwnerBriefingScope.business.includes)
            return scope == (hasBusiness ? .business : .personal)
        }
        return scope.includes(company)
    }
}
