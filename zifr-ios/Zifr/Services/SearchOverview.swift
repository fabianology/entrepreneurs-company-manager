import Foundation

/// A local, authorized overview. Membership comes from saved IDs and confirmed links,
/// never from a shared merchant name or an assistant's guess.
struct SearchOverview: Identifiable, Sendable {
    var root: SearchRecord
    var children: [SearchRecord] = []
    var balances: [SearchRecord] = []
    var paidServices: [SearchRecord] = []
    var transactions: [SearchRecord] = []
    var documents: [SearchRecord] = []
    var additionalLogins: [SearchRecord] = []
    var connections: [String: [SearchRecord]] = [:]
    var expandedChildIDs: Set<String> = []
    var representedIDs: Set<String> = []
    var score: Int = 0
    var id: String { root.id }

    var monthlyTotals: [SearchTotal] {
        let components = ([root] + children).filter { $0.activeService && $0.monthlyCost != nil }
        return Dictionary(grouping: components, by: \.currency).map { currency, records in
            SearchTotal(label: "Monthly equivalent", currency: currency,
                amount: records.reduce(0) { $0 + ($1.monthlyCost ?? 0) }, sourceIDs: records.map(\.id))
        }.sorted { $0.currency < $1.currency }
    }
    var hasUnknownCycle: Bool { ([root] + children).contains { $0.activeService && $0.monthlyCost == nil } }
    var hasNonMonthlyCycle: Bool {
        ([root] + children).contains { $0.activeService && $0.monthlyCost != 0 && $0.financialFacts["billingCycle"]?.lowercased() != "monthly" }
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

extension UniversalSearchIndex {
    func overviews(for response: SearchResponse, request: PortfolioQuery, filters: SearchFilters) -> [SearchOverview] {
        // Explicit calculations, history, date and type filters retain their precise result list.
        let plan = SearchQuery(request.query, filters: filters, now: Date(), calendar: .current)
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
            return plan.tokens.contains { token in name.contains { $0.hasPrefix(token) || SearchText.typo(token, $0) } }
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
                let aliases = Set(accounts.compactMap(\.balanceIdentity))
                let linkedBalances = records.filter {
                    $0.companyID == root.companyID && $0.balanceIdentity.map(aliases.contains) == true
                }
                let candidates = accounts + directlyLinked.filter { [.card, .loan].contains($0.kind) } + linkedBalances
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
            overview.transactions = unique(relatedRecords.filter { $0.kind == .transaction }).sorted {
                if $0.date != $1.date { return ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
                return $0.id < $1.id
            }
            overview.documents = unique(relatedRecords.filter { $0.kind == .document && $0.page == nil })
            for member in unique(members + overview.paidServices) { overview.connections[member.id] = linked(member) }
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
