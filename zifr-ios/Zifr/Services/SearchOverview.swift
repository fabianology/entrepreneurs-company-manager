import Foundation


/// Search-only presentation facts. No balances, passwords or provider IDs enter assistant evidence.
struct SearchFundingCoverage: Hashable, Sendable {
    enum Status: String, Sendable { case covered = "Covered", atRisk = "At risk", unknown = "Coverage unknown" }
    let status: Status
    let reason: String?

    static func normalized(_ original: Subscription, now: Date, calendar: Calendar) -> Subscription {
        var value = original
        switch value.billingCycle.lowercased() {
        case "monthly": value.billingCycle = "Monthly"
        case "yearly", "annual", "annually": value.billingCycle = "Yearly"
        default: return value
        }
        return SubscriptionRenewalScheduler.normalized(value, now: now, calendar: calendar)
    }

    static func project(subscriptions: [Subscription], institutions: [Institution], cards: [FinancialCard],
                        plaidItems: [PlaidItemSummary], now: Date, calendar: Calendar,
                        incomplete: Bool = false) -> [String: Self] {
        let supported = subscriptions.filter { ["Monthly", "Yearly"].contains($0.billingCycle) }
        let projection = UpcomingCoverageEngine.project(subscriptions: supported, institutions: institutions,
            cards: cards, plaidItems: plaidItems, now: now, days: 30, calendar: calendar)
        let partial = incomplete || projection.unscheduledCount > 0
            || subscriptions.contains { $0.status == "Active" && !["Monthly", "Yearly"].contains($0.billingCycle) }
        var result: [String: Self] = [:]
        for group in projection.groups {
            let status: Status = group.status == .covered ? (partial ? .unknown : .covered)
                : (group.status == .atRisk ? .atRisk : .unknown)
            let reason = group.reason ?? (partial ? "Some scheduled charges or portfolio data are unavailable." : nil)
            for charge in group.charges { result[charge.id] = Self(status: status, reason: reason) }
        }
        return result
    }
}

struct SearchChargeSummary: Sendable {
    var latest: SearchRecord?
    var firstDate: Date?
    var elapsedMonths = 0
    var observedIncreases: Int?

    init(record: SearchRecord, transactions: [SearchRecord], now: Date = Date(), calendar: Calendar = .current) {
        var seen = Set<String>()
        let posted = transactions.filter {
            $0.companyID == record.companyID && $0.currency == record.currency && !$0.pending
                && $0.flow == "expense" && ($0.amount ?? 0) > 0 && $0.date != nil
                && $0.date! <= now && seen.insert($0.id).inserted
        }.sorted { ($0.date!, $0.id) < ($1.date!, $1.id) }
        latest = posted.last
        firstDate = posted.first?.date
        if let firstDate { elapsedMonths = max(0, calendar.dateComponents([.month], from: firstDate, to: now).month ?? 0) }
        let cycle = record.financialFacts["billingCycle"]?.lowercased() ?? ""
        let component: Calendar.Component
        switch cycle {
        case "monthly": component = .month
        case "yearly", "annual", "annually": component = .year
        default: return
        }
        // A duplicate in a billing period invalidates that period, even if it used another source.
        let periods = Dictionary(grouping: posted) { calendar.dateInterval(of: component, for: $0.date!)!.start }
        let starts = periods.keys.sorted()
        var comparisons = 0
        var increases = 0
        let formatter = NumberFormatter(); formatter.numberStyle = .currency; formatter.currencyCode = record.currency
        func rounded(_ amount: Decimal) -> Decimal {
            var input = amount, output = Decimal()
            NSDecimalRound(&output, &input, formatter.maximumFractionDigits, .plain)
            return output
        }
        for (previous, current) in zip(starts, starts.dropFirst()) {
            guard calendar.date(byAdding: component, value: 1, to: previous) == current,
                  let before = periods[previous], before.count == 1,
                  let after = periods[current], after.count == 1,
                  let source = before[0].transactionSourceIdentity,
                  source == after[0].transactionSourceIdentity else { continue }
            comparisons += 1
            if rounded(after[0].amount!) > rounded(before[0].amount!) { increases += 1 }
        }
        if comparisons > 0 { observedIncreases = increases }
    }
}

/// Saved billing amounts grouped by their actual cycle, without annualization.
struct SearchBillingTotal: Identifiable, Sendable {
    var currency: String
    var cycle: String
    var amount: Decimal
    var id: String { currency + ":" + cycle }
    var suffix: String {
        ["monthly": "mo", "yearly": "yr", "weekly": "wk", "quarterly": "qtr"][cycle] ?? cycle
    }
    var formatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount) \(currency)"
    }
    static func totals(for records: [SearchRecord]) -> [Self] {
        var totals: [String: Self] = [:]
        for record in records where record.safeDetails["pricingModel"] != "free" {
            guard let value = record.financialFacts["billingAmount"], let amount = Decimal(string: value) else { continue }
            let savedCycle = record.financialFacts["billingCycle"]?.lowercased() ?? "cycle not saved"
            let cycle = ["annual", "annually"].contains(savedCycle) ? "yearly" : savedCycle
            let total = Self(currency: record.currency, cycle: cycle, amount: amount)
            if totals[total.id] == nil { totals[total.id] = total }
            else { totals[total.id]?.amount += amount }
        }
        let order = ["monthly": 0, "yearly": 1, "weekly": 2, "quarterly": 3]
        return totals.values.sorted {
            if $0.currency != $1.currency { return $0.currency < $1.currency }
            if $0.cycle != $1.cycle { return (order[$0.cycle] ?? 4, $0.cycle) < (order[$1.cycle] ?? 4, $1.cycle) }
            return $0.id < $1.id
        }
    }
}

struct SearchBankCounts: Sendable {
    var accounts = 0
    var cards = 0
    var loans = 0

    init(records: [SearchRecord] = []) {
        accounts = Set(records.filter { $0.kind == .account }.map(\.id)).count
        // A synced credit/loan account and its saved card/loan represent one product.
        cards = Set(records.filter {
            $0.kind == .card || ($0.kind == .account && $0.isCardAccount)
        }.map { $0.balanceIdentity ?? $0.id }).count
        loans = Set(records.filter {
            $0.kind == .loan || ($0.kind == .account && $0.balanceCategory == .loan)
        }.map { $0.balanceIdentity ?? $0.id }).count
    }

    var label: String {
        "\(accounts) \(accounts == 1 ? "Account" : "Accounts") • \(cards) \(cards == 1 ? "Card" : "Cards") • \(loans) \(loans == 1 ? "Loan" : "Loans")"
    }
}

/// A local, authorized overview. Saved relationships are preserved; merchant history
/// is matched separately and never persisted as a confirmed relationship.
struct SearchOverview: Identifiable, Sendable {
    var root: SearchRecord
    var children: [SearchRecord] = []
    var balances: [SearchRecord] = []
    var bankCounts = SearchBankCounts()
    var paidServices: [SearchRecord] = []
    var transactions: [SearchRecord] = []
    var merchantMatchedTransactionIDs: Set<String> = []
    var documents: [SearchRecord] = []
    var additionalLogins: [SearchRecord] = []
    var connections: [String: [SearchRecord]] = [:]
    var expandedChildIDs: Set<String> = []
    var representedIDs: Set<String> = []
    var chargeSummaries: [String: SearchChargeSummary] = [:]
    var serviceTransactions: [String: [SearchRecord]] = [:]
    var score: Int = 0
    var id: String { root.id }

    var serviceRows: [SearchRecord] {
        let paidBase = root.safeDetails["pricingModel"] != "free"
            && (root.financialFacts["billingAmount"].flatMap { Decimal(string: $0) } ?? 0) > 0
        return (paidBase ? [root] : []) + children
    }
    var serviceCounts: (bills: Int, subscriptions: Int, paymentSources: Int) {
        let active = serviceRows.filter { $0.activeService }
        let bills = active.filter { $0.serviceType == "bill" }.count
        let subscriptions = active.filter { $0.serviceType != "bill" }.count
        var sources = Set<String>()
        for record in active {
            let linked = paymentSources(for: record)
            for source in linked { sources.insert(source.balanceIdentity ?? source.id) }
            if linked.isEmpty, let label = record.safeDetails["paymentMethod"], !label.isEmpty {
                sources.insert("label:" + SearchText.normalize(label))
            }
        }
        return (bills, subscriptions, sources.count)
    }
    var serviceCountsLabel: String {
        let counts = serviceCounts
        return "\(counts.bills) \(counts.bills == 1 ? "Bill" : "Bills") | \(counts.subscriptions) \(counts.subscriptions == 1 ? "Subscription" : "Subscriptions") | \(counts.paymentSources) \(counts.paymentSources == 1 ? "Payment source" : "Payment sources")"
    }

    var billingTotals: [SearchBillingTotal] {
        SearchBillingTotal.totals(for: ([root] + children).filter { $0.activeService }).filter { $0.amount != 0 }
    }
    var hasUnknownAmount: Bool {
        ([root] + children).contains { $0.activeService && $0.safeDetails["pricingModel"] != "free" && $0.financialFacts["billingAmount"].flatMap { Decimal(string: $0) } == nil }
    }
    func linked(to record: SearchRecord, kinds: Set<SearchRecord.Kind>) -> [SearchRecord] {
        (connections[record.id] ?? []).filter { kinds.contains($0.kind) }
    }
    func paymentSources(for record: SearchRecord) -> [SearchRecord] {
        let sources = linked(to: record, kinds: [.card, .account, .institution])
        let accounts = sources.filter { $0.kind == .account }
        return sources.filter { source in
            if source.kind == .institution { return !accounts.contains { $0.modelID == source.modelID } }
            if source.kind == .card, let identity = source.balanceIdentity { return !accounts.contains { $0.balanceIdentity == identity } }
            return true
        }
    }
}

/// Build once per render, never inside a hit predicate. A service may represent
/// thousands of charges, so rebuilding its ID set for every hit is quadratic.
struct SearchResultPage {
    let overviews: [SearchOverview]
    let directHits: [SearchHit]
    let relatedHits: [SearchHit]
    let hasMore: Bool

    init(response: SearchResponse, overviews: [SearchOverview], limit: Int) {
        self.overviews = Array(overviews.prefix(limit))
        let represented = self.overviews.reduce(into: Set<String>()) { $0.formUnion($1.representedIDs) }
        var direct: [SearchHit] = [], related: [SearchHit] = []
        var count = 0
        for hit in response.hits where !represented.contains(hit.id) {
            count += 1
            guard count <= limit else { break }
            if hit.score == -100 { related.append(hit) } else { direct.append(hit) }
        }
        directHits = direct; relatedHits = related
        hasMore = count > limit || overviews.count > limit
    }
}

struct SearchTransactionYearGroup: Identifiable {
    let year: Int?
    let hits: [SearchHit]
    var id: String { year.map(String.init) ?? "undated" }
    var title: String { year.map(String.init) ?? "Date unavailable" }

    static func groups(_ hits: [SearchHit], calendar: Calendar = .current) -> [Self] {
        Dictionary(grouping: hits.filter { $0.record.kind == .transaction }) { hit in
            hit.record.date.map { calendar.component(.year, from: $0) }
        }.map { year, hits in
            Self(year: year, hits: hits.sorted {
                if $0.record.date != $1.record.date { return ($0.record.date ?? .distantPast) > ($1.record.date ?? .distantPast) }
                return $0.id < $1.id
            })
        }.sorted { ($0.year ?? Int.min) > ($1.year ?? Int.min) }
    }
}

extension UniversalSearchIndex {
    /// Route service-history phrases through the same conservative attribution as overview history.
    func serviceHistorySelection(_ query: String, filters: SearchFilters, now: Date, calendar: Calendar) -> (ids: Set<String>, query: String, name: String)? {
        guard filters.kind == nil || filters.kind == .transaction else { return nil }
        let named = SearchNamedText(query, names: savedNames(filters: filters))
        let words = Set(named.masked.split(separator: " ").map(String.init))
        guard words.contains("history") || (!words.isDisjoint(with: ["past", "previous"]) && !words.isDisjoint(with: ["charges", "payments"])) else { return nil }
        let removed: Set<String> = ["history", "charge", "charges", "billing", "payment", "payments", "past", "previous"]
        let remainder = named.restoring(named.masked.split(separator: " ").map(String.init).filter { !removed.contains($0) }.joined(separator: " "))
        var nameFilters = filters; nameFilters.kind = nil
        let plan = queryPlan(remainder, filters: nameFilters, now: now, calendar: calendar)
        let name = plan.tokens.joined(separator: " ")
        guard !name.isEmpty else { return nil }
        let byID = Dictionary(records.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let services = records.filter { record in
            guard record.kind == .subscription, filters.companyID == nil || record.companyID == filters.companyID else { return false }
            if record.normalizedTitle == name { return true }
            return record.parentServiceID.flatMap { byID[$0] }.map { $0.normalizedTitle + " " + record.normalizedTitle == name } == true
        }
        guard !services.isEmpty else { return nil }
        var request = PortfolioQuery(); request.query = name
        let response = SearchResponse(hits: services.map { SearchHit(record: $0, score: 700, reason: "Saved service name") })
        let cards = overviews(for: response, request: request, filters: .init(companyID: filters.companyID))
        var ids = Set<String>()
        for service in services {
            guard let overview = cards.first(where: { $0.root.id == (service.parentServiceID ?? service.id) }) else { continue }
            let history = service.parentServiceID == nil ? overview.transactions : overview.serviceTransactions[service.id] ?? []
            ids.formUnion(history.map(\.id))
        }
        // Remove only the recognized service name; retain date phrases for the precise transaction query.
        let transactionQuery = SearchText.removingPhrase(name, from: SearchText.normalize(remainder)) + " transactions"
        return (ids, transactionQuery, services.map(\.title).sorted().first ?? name)
    }

    func overviews(for response: SearchResponse, request: PortfolioQuery, filters: SearchFilters) -> [SearchOverview] {
        let request = resolvedRequest(request, filters: filters)
        // Explicit calculations, history, date and type filters retain their precise result list.
        let plan = queryPlan(request.query, filters: filters, now: Date(), calendar: .current)
        guard request.operation == .search, request.startDate == nil, request.endDate == nil,
              filters.kind == nil, filters.serviceType == nil, filters.period == .all,
              request.serviceType == nil, plan.dates == nil,
              plan.kind == nil || [.subscription, .institution].contains(plan.kind!),
              !plan.tokens.isEmpty, !plan.tokens.contains(where: { $0.allSatisfy(\.isNumber) }) else { return [] }
        let byID = Dictionary(records.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        func linked(_ record: SearchRecord) -> [SearchRecord] {
            (links[record.id] ?? []).compactMap { byID[$0] }.filter { $0.companyID == record.companyID }
                .sorted { $0.id < $1.id }
        }
        func nameMatch(_ record: SearchRecord) -> Bool {
            let name = Set(record.normalizedTitle.split(separator: " ").map(String.init))
            let compactTitle = record.title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
                .filter(\.isLetter)
            let domain = SearchBrand.domain(for: record).map(SearchText.normalize) ?? ""
            let domainWords = Set(domain.split(separator: " ").map(String.init))
            return plan.tokens.contains { token in
                name.contains { $0.hasPrefix(token) || SearchText.typo(token, $0) }
                    || (token.count >= 3 && compactTitle.hasPrefix(token))
                    || domainWords.contains { $0.hasPrefix(token) }
            }
        }
        var roots: [String: (SearchRecord, Int)] = [:]
        let matched = Set(response.hits.filter { $0.score > 0 }.map(\.id))
        for hit in response.hits where hit.score > 0 && [.subscription, .institution, .account].contains(hit.record.kind) {
            let record = hit.record
            let rootID = record.parentServiceID ?? (record.kind == .account ? "institution:\(record.modelID.uuidString)" : record.id)
            guard let root = byID[rootID], nameMatch(record) || nameMatch(root),
                  filters.companyID == nil || root.companyID == filters.companyID else { continue }
            let score = max(roots[rootID]?.1 ?? 0, hit.score)
            roots[rootID] = (root, score)
        }
        guard !roots.isEmpty, !Task.isCancelled else { return [] }
        let institutionProducts = institutionProductAssociations()
        var savedChargeOwners: [String: Set<String>] = [:]
        for service in records where service.kind == .subscription {
            for transaction in linked(service) where transaction.kind == .transaction {
                savedChargeOwners[transaction.id, default: []].insert(service.id)
            }
        }
        let merchantHistory = roots.values.contains { $0.0.kind == .subscription } ? serviceMerchantHistory() : (accounts: [:], services: [:])
        guard !Task.isCancelled else { return [] }
        return roots.values.map { root, score in
            var overview = SearchOverview(root: root, score: score)
            let directlyLinked = linked(root)
            if root.kind == .subscription {
                overview.children = records.filter { $0.parentServiceID == root.id && $0.companyID == root.companyID }.sorted {
                    let left = matched.contains($0.id) && nameMatch($0)
                    let right = matched.contains($1.id) && nameMatch($1)
                    if left != right { return left }
                    if $0.activeService != $1.activeService { return $0.activeService }
                    if $0.dueDate != $1.dueDate { return ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
                    return $0.title.localizedStandardCompare($1.title) == .orderedAscending
                }
                // Generic parent queries stay compact; an explicitly named child opens immediately.
                if !plan.tokens.allSatisfy({ root.normalizedTitle.split(separator: " ").contains(Substring($0)) }) {
                    overview.expandedChildIDs = Set(overview.children.filter { matched.contains($0.id) && nameMatch($0) }.map(\.id))
                }
            }
            var members = [root] + overview.children
            if root.kind == .institution {
                let accounts = directlyLinked.filter { $0.kind == .account && $0.modelID == root.modelID }
                let candidates = accounts + (institutionProducts[root.modelID] ?? [])
                overview.bankCounts = SearchBankCounts(records: candidates)
                var seen = Set<String>()
                overview.balances = candidates.sorted {
                    if ($0.kind == .account) != ($1.kind == .account) { return $0.kind == .account }
                    return $0.id < $1.id
                }.filter { seen.insert($0.balanceIdentity ?? $0.id).inserted }.sorted {
                    if $0.balanceCategory != $1.balanceCategory { return balanceOrder($0) < balanceOrder($1) }
                    return $0.title.localizedStandardCompare($1.title) == .orderedAscending
                }
                members += candidates
            } else {
                overview.balances = directlyLinked.filter { $0.kind == .loan }
            }
            let relatedRecords = members.flatMap(linked)
            func unique(_ values: [SearchRecord]) -> [SearchRecord] {
                var ids = Set<String>(); return values.filter { ids.insert($0.id).inserted }
            }
            let services = unique(relatedRecords.filter { $0.kind == .subscription })
            overview.paidServices = root.kind == .institution ? services.filter { service in
                // A free umbrella account is not another paid service above its add-ons.
                !(service.monthlyCost == 0 && services.contains { $0.parentServiceID == service.id })
            }.sorted { $0.title < $1.title } : []
            overview.additionalLogins = unique(members.filter { $0.kind == .card && (!$0.login.isEmpty || $0.credential != .none) })
            let matchedHistory = root.kind == .subscription ? merchantHistory.accounts[root.id] ?? [] : []
            let confirmedIDs = Set(relatedRecords.filter { $0.kind == .transaction }.map(\.id))
            overview.merchantMatchedTransactionIDs = Set(matchedHistory.map(\.id)).subtracting(confirmedIDs)
            overview.transactions = unique(relatedRecords.filter { $0.kind == .transaction } + matchedHistory).sorted {
                if $0.date != $1.date { return ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
                return $0.id < $1.id
            }
            overview.documents = unique(relatedRecords.filter { $0.kind == .document && $0.page == nil })
            for member in unique(members + overview.paidServices) { overview.connections[member.id] = linked(member) }
            for child in overview.children {
                overview.connections[child.id] = unique((overview.connections[child.id] ?? []) + (merchantHistory.services[child.id] ?? []))
            }
            if root.kind == .subscription {
                // One saved charge cannot establish separate amounts for multiple services.
                // Keep ambiguous ownership in account-wide history only.
                var owners = savedChargeOwners
                for member in [root] + overview.children {
                    for transaction in overview.linked(to: member, kinds: [.transaction]) + (merchantHistory.services[member.id] ?? []) {
                        owners[transaction.id, default: []].insert(member.id)
                    }
                }
                let childTransactionIDs = Set(overview.children.flatMap { overview.linked(to: $0, kinds: [.transaction]) }.map(\.id))
                for member in [root] + overview.children {
                    let history: [SearchRecord]
                    if member.id == root.id {
                        // A generic merchant charge can belong to any add-on. Only confirmed base
                        // links may populate the paid base row; the account-wide list retains all.
                        history = overview.children.isEmpty ? overview.transactions
                            : unique(directlyLinked.filter { $0.kind == .transaction && !childTransactionIDs.contains($0.id) } + (merchantHistory.services[root.id] ?? []))
                    } else {
                        history = overview.linked(to: member, kinds: [.transaction]).filter { owners[$0.id]?.count == 1 }
                    }
                    let assigned = history.filter { (owners[$0.id]?.count ?? 0) <= 1 }
                    overview.serviceTransactions[member.id] = assigned.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
                    overview.chargeSummaries[member.id] = SearchChargeSummary(record: member, transactions: assigned)
                }
            }
            overview.representedIDs = Set((members + overview.balances + overview.transactions + overview.documents + (root.kind == .institution ? services : [])).map(\.id))
            // Funding accounts are navigation links, not additional search cards for the same match.
            if root.kind == .subscription {
                for member in members { overview.representedIDs.formUnion(overview.paymentSources(for: member).map(\.id)) }
            }
            return overview
        }.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.root.title != $1.root.title { return $0.root.title < $1.root.title }
            return $0.id < $1.id
        }
    }

    func searchPaymentSources(for hits: [SearchHit]) -> [String: [SearchRecord]] {
        let services = hits.filter { $0.record.kind == .subscription }
        guard !services.isEmpty, !Task.isCancelled else { return [:] }
        let byID = Dictionary(records.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var result: [String: [SearchRecord]] = [:]
        for hit in services {
            if Task.isCancelled { return [:] }
            let record = hit.record
            let linked = (links[record.id] ?? []).compactMap { byID[$0] }.filter { $0.companyID == record.companyID }
            result[record.id] = SearchOverview(root: record, connections: [record.id: linked]).paymentSources(for: record)
        }
        return result
    }

    /// Exact merchant/domain matches within one company. Known funding accounts must
    /// agree; duplicate service accounts are assigned only when the match is unique.
    private func serviceMerchantHistory() -> (accounts: [String: [SearchRecord]], services: [String: [SearchRecord]]) {
        let byID = Dictionary(records.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let services = records.filter { $0.kind == .subscription && $0.parentServiceID == nil }
        let servicesByCompany = Dictionary(grouping: services, by: \.companyID)
        let domains = Dictionary(uniqueKeysWithValues: services.compactMap { service -> (String, String)? in
            guard let host = SearchBrand.websiteURL(service.website)?.host?.lowercased() else { return nil }
            return (service.id, host.hasPrefix("www.") ? String(host.dropFirst(4)) : host)
        })
        let children = Dictionary(grouping: records.filter { $0.parentServiceID != nil }, by: { $0.parentServiceID! })
        func paymentKeys(_ record: SearchRecord, precise: Bool = false) -> Set<String> {
            var keys = Set<String>()
            for id in links[record.id] ?? [] {
                guard let source = byID[id], source.companyID == record.companyID,
                      [.card, .account, .institution].contains(source.kind),
                      !precise || source.kind != .institution else { continue }
                keys.insert(source.id)
                if let identity = source.balanceIdentity { keys.insert(identity) }
            }
            return keys
        }
        let funding = Dictionary(uniqueKeysWithValues: services.map { service in
            (service.id, ([service] + (children[service.id] ?? [])).reduce(into: Set<String>()) { $0.formUnion(paymentKeys($1)) })
        })
        let allServices = records.filter { $0.kind == .subscription }
        let preciseFunding = Dictionary(uniqueKeysWithValues: allServices.map { ($0.id, paymentKeys($0, precise: true)) })
        let precision = Dictionary(uniqueKeysWithValues: Set(allServices.map(\.currency)).map { currency in
            let formatter = NumberFormatter(); formatter.numberStyle = .currency; formatter.currencyCode = currency
            return (currency, formatter.maximumFractionDigits)
        })
        func rounded(_ amount: Decimal, currency: String) -> Decimal {
            var input = amount, output = Decimal()
            NSDecimalRound(&output, &input, precision[currency] ?? 2, .plain)
            return output
        }
        let billingAmounts = Dictionary(uniqueKeysWithValues: allServices.compactMap { service -> (String, Decimal)? in
            guard service.safeDetails["pricingModel"] != "free",
                  let text = service.financialFacts["billingAmount"], let amount = Decimal(string: text), amount > 0 else { return nil }
            return (service.id, rounded(amount, currency: service.currency))
        })
        func amountMatches(_ transaction: SearchRecord, members: [SearchRecord]) -> [SearchRecord] {
            // Amount-only attribution requires a known card/account, never merely the same bank.
            guard !transaction.pending, transaction.flow == "expense", let amount = transaction.amount, amount > 0 else { return [] }
            let sourceKeys = paymentKeys(transaction, precise: true)
            guard !sourceKeys.isEmpty else { return [] }
            return members.filter { service in
                service.currency == transaction.currency && billingAmounts[service.id] == rounded(amount, currency: transaction.currency)
                    && !(preciseFunding[service.id] ?? []).isDisjoint(with: sourceKeys)
            }
        }
        func merchantMatches(_ transaction: SearchRecord, _ service: SearchRecord, merchantHost: String?) -> Bool {
            let name = service.normalizedTitle
            if transaction.normalizedTitle == name || (name.count >= 3 && transaction.normalizedTitle.hasPrefix(name + " ")) { return true }
            guard let domain = domains[service.id] else { return false }
            if transaction.normalizedTitle == SearchText.normalize(domain) { return true }
            guard let merchantHost else { return false }
            return merchantHost == domain || merchantHost.hasSuffix("." + domain)
        }
        var result: (accounts: [String: [SearchRecord]], services: [String: [SearchRecord]]) = ([:], [:])
        for transaction in records where transaction.kind == .transaction && !["income", "transfer", "ignored"].contains(transaction.flow) {
            if Task.isCancelled { return ([:], [:]) }
            guard transaction.companyID != nil else { continue }
            if (links[transaction.id] ?? []).contains(where: { byID[$0]?.kind == .subscription }) { continue }
            let accountKeys = paymentKeys(transaction)
            let eligible = (servicesByCompany[transaction.companyID] ?? []).filter { service in
                let keys = funding[service.id] ?? []
                return keys.isEmpty || !keys.isDisjoint(with: accountKeys)
            }
            let merchantHost = SearchBrand.websiteURL(transaction.website)?.host?.lowercased()
            let names = Set(eligible.filter { merchantMatches(transaction, $0, merchantHost: merchantHost) }.map(\.normalizedTitle))
            // Missing a website on an otherwise identical service must not break an ambiguity tie.
            let candidates = eligible.filter { names.contains($0.normalizedTitle) }
            // Prefer a known account match over an otherwise indistinguishable unconfigured service.
            let accountMatches = candidates.filter { !(funding[$0.id] ?? []).isEmpty }
            let matches = accountMatches.isEmpty ? candidates : accountMatches
            let service: SearchRecord
            if matches.count == 1, let match = matches.first { service = match }
            else {
                let amounts = amountMatches(transaction, members: matches.flatMap { [$0] + (children[$0.id] ?? []) })
                guard amounts.count == 1, let member = amounts.first,
                      let parent = byID[member.parentServiceID ?? member.id] else { continue }
                service = parent
            }
            result.accounts[service.id, default: []].append(transaction)
            let matchingChildren = (children[service.id] ?? []).filter { child in
                let name = child.normalizedTitle
                let title = " " + transaction.normalizedTitle + " "
                let keys = paymentKeys(child)
                return !name.isEmpty && title.contains(" " + name + " ") && (keys.isEmpty || !keys.isDisjoint(with: accountKeys))
            }
            if matchingChildren.count == 1, let child = matchingChildren.first {
                result.services[child.id, default: []].append(transaction)
            } else if matchingChildren.isEmpty {
                let amounts = amountMatches(transaction, members: [service] + (children[service.id] ?? []))
                if amounts.count == 1, let member = amounts.first {
                    result.services[member.id, default: []].append(transaction)
                }
            }
        }
        return result
    }
    private func balanceOrder(_ record: SearchRecord) -> Int {
        switch record.balanceCategory {
        case .cash: return 0
        case .investment: return 1
        case .credit: return 2
        case .loan: return 3
        case .receivable: return 4
        default: return 5
        }
    }
}

enum SearchBrand {
    static func websiteURL(_ value: String?) -> URL? {
        guard let value, !value.isEmpty else { return nil }
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: text.contains("://") ? text : "https://" + text),
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, host.contains("."), url.user == nil, url.password == nil else { return nil }
        return url
    }
    static func domain(for record: SearchRecord) -> String? {
        if let host = websiteURL(record.website)?.host { return host }
        // Known brand artwork only. Never guess a domain from an arbitrary record name.
        let brands = ["tesla": "tesla.com", "netflix": "netflix.com", "sofi": "sofi.com", "citi": "citi.com",
            "citibank": "citi.com", "citibank online": "citi.com", "costco citi": "citi.com", "chase": "chase.com",
            "american express": "americanexpress.com", "amex": "americanexpress.com", "bank of america": "bankofamerica.com",
            "capital one": "capitalone.com", "wells fargo": "wellsfargo.com", "fidelity": "fidelity.com",
            "vanguard": "vanguard.com", "cox": "cox.com", "cox internet": "cox.com", "spotify": "spotify.com"]
        return brands[SearchText.normalize(record.brandName ?? record.title)]
    }
}

/// Cache identity includes every time-dependent coverage boundary, independently of edits.
struct SearchProjectionStamp: Equatable, Sendable {
    var day: Date
    var calendar: Calendar
    var staleBanks: Set<UUID>
    var staleItems: Set<UUID>

    init(institutions: [Institution], items: [PlaidItemSummary], now: Date, calendar: Calendar) {
        day = calendar.startOfDay(for: now); self.calendar = calendar
        staleBanks = Set(institutions.filter { bank in
            bank.lastSyncedAt.map { UpcomingCoverageEngine.isBankBalanceStale(lastSyncedAt: $0, now: now, calendar: calendar) } ?? false
        }.map(\.id))
        staleItems = Set(items.filter { $0.isStale(referenceDate: now) }.map(\.id))
    }
}
