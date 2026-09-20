import XCTest
import Combine
import PDFKit
import UIKit
import SwiftUI
import Supabase
@testable import Zifr

@MainActor
final class UniversalSearchTests: XCTestCase {
    private let owner = UUID()
    private var originalAssignments: Data?
    override func setUp() { super.setUp(); originalAssignments = UserDefaults.standard.data(forKey: "localCompanyOverrides") }
    override func tearDown() { UserDefaults.standard.set(originalAssignments, forKey: "localCompanyOverrides"); super.tearDown() }
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!; return calendar
    }()
    private var now: Date { SearchText.date("2026-09-17", calendar: calendar)! }
    private func fixture() -> (AppState, Company, Company) {
        let state = AppState(); state.localCompanyOverrides = [:]
        let a = Company(userId: owner, name: "North Studio", structure: "LLC")
        let b = Company(userId: owner, name: "South Studio", structure: "LLC")
        state.companies = [a, b]; state.hasLoadedPortfolio = true; state.portfolioUserID = owner
        return (state, a, b)
    }
    private func transaction(_ company: UUID, card: FinancialCard? = nil, date: String = "2026-08-10", amount: Double = 20, currency: String = "USD") -> Zifr.Transaction {
        var t = Zifr.Transaction(); t.userId = owner; t.companyId = company; t.accountId = card?.plaidAccountId ?? "unassigned"
        t.name = "Adobe"; t.date = date; t.amount = amount; t.currency = currency
        return t
    }

    private func overviews(_ index: UniversalSearchIndex, _ query: String, filters: SearchFilters = .init()) -> [SearchOverview] {
        let request = PortfolioQuery.interpret(query)
        return index.overviews(for: index.execute(request, filters: filters), request: request, filters: filters)
    }

    func testDisclosureChevronUsesRightWhenCollapsedAndDownWhenExpanded() {
        XCTAssertEqual(DisclosureStateChevron.symbolName(isExpanded: false), "chevron.right")
        XCTAssertEqual(DisclosureStateChevron.symbolName(isExpanded: true), "chevron.down")
    }

    func testGenericMerchantChargeUsesUniqueSavedAmountAndPaymentSource() throws {
        let (state, a, _) = fixture()
        var card = FinancialCard(userId: owner, companyId: a.id, name: "Costco Citi"); card.plaidAccountId = "costco"
        state.cards = [card]
        var tesla = Subscription(userId: owner, companyId: a.id, name: "Tesla", cost: 283, paymentMethodId: card.id)
        tesla.subServices = [SubService(name: "Full Self-Driving", cost: 106.67), SubService(name: "Insurance", cost: 120)]
        state.subscriptions = [tesla]
        var driving = transaction(a.id, card: card, amount: 106.67); driving.name = "TESLA INC"
        var base = transaction(a.id, card: card, amount: 283); base.name = "Tesla"
        state.transactions = [driving, base]
        let index = state.searchIndex(for: owner)
        let overview = try XCTUnwrap(overviews(index, "Tesla").first)
        let child = try XCTUnwrap(overview.children.first { $0.title == "Full Self-Driving" })
        XCTAssertEqual(overview.serviceTransactions[child.id]?.map(\.modelID), [driving.id])
        XCTAssertEqual(overview.serviceTransactions[overview.root.id]?.map(\.modelID), [base.id])
        XCTAssertTrue(overview.representedIDs.contains("transaction:\(driving.id)"))
        let history = index.execute(PortfolioQuery.interpret("Tesla Full Self-Driving history"))
        XCTAssertEqual(history.hits.filter { $0.record.kind == .transaction }.map(\.record.modelID), [driving.id])
        XCTAssertFalse(index.links[child.id]?.contains("transaction:\(driving.id)") == true, "Inferred ownership must not persist a relationship")
        state.subscriptions[0].subServices.append(SubService(name: "Other package", cost: 106.67))
        let ambiguous = try XCTUnwrap(overviews(state.searchIndex(for: owner), "Tesla").first)
        XCTAssertTrue(ambiguous.serviceTransactions[child.id]?.isEmpty == true)
        XCTAssertEqual(ambiguous.transactions.count, 2)
        state.subscriptions[0].subServices.removeLast()
        state.subscriptions[0].cost = 106.67
        let baseTie = try XCTUnwrap(overviews(state.searchIndex(for: owner), "Tesla").first)
        XCTAssertTrue(baseTie.serviceTransactions[child.id]?.isEmpty == true, "Paid base must participate in ambiguity checks")
        XCTAssertTrue(baseTie.serviceTransactions[baseTie.root.id]?.isEmpty == true)
    }

    func testAmountAttributionPreservesSourceCurrencyFlowAndExplicitLinks() throws {
        let cid = UUID()
        var root = SearchRecord(kind: .subscription, modelID: UUID(), companyID: cid, company: "Entity", title: "Example", detail: "")
        root.financialFacts = ["billingAmount": "0", "billingCycle": "Monthly"]
        var child = SearchRecord(kind: .subscription, modelID: UUID(), companyID: cid, company: "Entity", title: "Package", detail: "")
        child.parentServiceID = root.id; child.currency = "USD"
        child.financialFacts = ["billingAmount": "106.6700001", "billingCycle": "Monthly"]
        let card = SearchRecord(kind: .card, modelID: UUID(), companyID: cid, company: "Entity", title: "Card", detail: "")
        let otherCard = SearchRecord(kind: .card, modelID: UUID(), companyID: cid, company: "Entity", title: "Other card", detail: "")
        let bank = SearchRecord(kind: .institution, modelID: UUID(), companyID: cid, company: "Entity", title: "Bank", detail: "")
        var charge = SearchRecord(kind: .transaction, modelID: UUID(), companyID: cid, company: "Entity", title: "Example", detail: "")
        charge.amount = Decimal(string: "106.67"); charge.currency = "USD"; charge.flow = "expense"; charge.date = now
        func assigned(_ transaction: SearchRecord, source: SearchRecord, saved: [String] = []) throws -> [SearchRecord] {
            let index = UniversalSearchIndex(records: [root, child, card, otherCard, bank, transaction], links: [
                root.id: [card.id], child.id: Set([card.id] + saved), transaction.id: [source.id, bank.id], card.id: [bank.id], otherCard.id: [bank.id]
            ])
            return try XCTUnwrap(overviews(index, "Example").first).serviceTransactions[child.id] ?? []
        }
        XCTAssertEqual(try assigned(charge, source: card).count, 1)
        XCTAssertTrue(try assigned(charge, source: otherCard).isEmpty, "Two cards at the same bank are not one payment source")
        XCTAssertTrue(try assigned(charge, source: bank).isEmpty, "Bank-only funding cannot prove the matching card")
        var noise = charge; noise.currency = "EUR"
        XCTAssertTrue(try assigned(noise, source: card).isEmpty)
        noise = charge; noise.amount = Decimal(string: "106.68")
        XCTAssertTrue(try assigned(noise, source: card).isEmpty, "Do not guess a tax or price difference")
        noise = charge; noise.pending = true
        XCTAssertTrue(try assigned(noise, source: card).isEmpty)
        for flow in ["refund", "income", "transfer", "ignored"] {
            noise = charge; noise.flow = flow
            XCTAssertTrue(try assigned(noise, source: card).isEmpty)
        }
        noise = charge; noise.companyID = UUID()
        XCTAssertTrue(try assigned(noise, source: card).isEmpty)
        noise = charge; noise.title = "Other merchant"; noise.normalizedTitle = SearchText.normalize(noise.title)
        XCTAssertTrue(try assigned(noise, source: card).isEmpty)
        noise = charge; noise.title = "Example Package"; noise.normalizedTitle = SearchText.normalize(noise.title); noise.amount = 120
        XCTAssertEqual(try assigned(noise, source: card).count, 1, "Specific merchant-name evidence survives price changes")
        noise = charge; noise.amount = 120
        XCTAssertEqual(try assigned(noise, source: card, saved: [noise.id]).count, 1, "Saved relationships outrank an amount mismatch")
        child.currency = "JPY"; child.financialFacts["billingAmount"] = "107"
        noise = charge; noise.currency = "JPY"; noise.amount = Decimal(string: "106.67")
        XCTAssertEqual(try assigned(noise, source: card).count, 1, "Compare at the currency's precision")
    }

    func testAmountsDisambiguateSameBrandAccountsWithoutCrossingEntities() throws {
        let (state, a, b) = fixture()
        var card = FinancialCard(userId: owner, companyId: a.id, name: "Card"); card.plaidAccountId = "one"
        state.cards = [card]
        let first = Subscription(userId: owner, companyId: a.id, name: "Netflix", cost: 26.99, paymentMethodId: card.id)
        let second = Subscription(userId: owner, companyId: a.id, name: "Netflix", cost: 10, paymentMethodId: card.id)
        state.subscriptions = [first, second, Subscription(userId: owner, companyId: b.id, name: "Netflix", cost: 26.99)]
        var charge = transaction(a.id, card: card, amount: 26.99); charge.name = "Netflix"
        state.transactions = [charge]
        let results = overviews(state.searchIndex(for: owner), "Netflix")
        XCTAssertEqual(results.first { $0.root.modelID == first.id }?.transactions.map(\.modelID), [charge.id])
        XCTAssertTrue(results.filter { $0.root.modelID != first.id }.allSatisfy { $0.transactions.isEmpty })
        state.subscriptions[1].cost = 26.99
        XCTAssertTrue(overviews(state.searchIndex(for: owner), "Netflix").allSatisfy { $0.transactions.isEmpty })
    }

    func testMoreMatchesYearGroupsUseTransactionDatesAndKeepUndatedRecords() {
        func hit(_ date: String?) -> SearchHit {
            var record = SearchRecord(kind: .transaction, modelID: UUID(), companyID: nil, company: "", title: "Tesla", detail: "")
            record.date = date.flatMap { SearchText.date($0, calendar: calendar) }
            return SearchHit(record: record, score: 100, reason: "Match")
        }
        let old = hit("2025-12-31"), recent = hit("2026-09-01"), early = hit("2026-01-01"), undated = hit(nil)
        let service = SearchHit(record: SearchRecord(kind: .subscription, modelID: UUID(), companyID: nil, company: "", title: "Tesla", detail: ""), score: 500, reason: "Match")
        let groups = SearchTransactionYearGroup.groups([old, early, service, undated, recent], calendar: calendar)
        XCTAssertEqual(groups.map(\.id), ["2026", "2025", "undated"])
        XCTAssertEqual(groups[0].hits.map(\.id), [recent.id, early.id])
        XCTAssertEqual(groups[2].hits.map(\.id), [undated.id])
        XCTAssertEqual(groups.flatMap(\.hits).count, 4)
    }

    func testSearchChargeSummaryUsesPostedComparablePeriods() throws {
        let company = UUID()
        var service = SearchRecord(kind: .subscription, modelID: UUID(), companyID: company, company: "Test", title: "Netflix", detail: "")
        service.financialFacts["billingCycle"] = "Monthly"
        func charge(_ day: String, _ amount: Decimal, source: String = "card-a", flow: String = "expense", pending: Bool = false, currency: String = "USD") -> SearchRecord {
            var record = SearchRecord(kind: .transaction, modelID: UUID(), companyID: company, company: "Test", title: "Netflix", detail: "")
            record.date = SearchText.date(day, calendar: calendar); record.amount = amount
            record.transactionSourceIdentity = source; record.flow = flow; record.pending = pending; record.currency = currency
            return record
        }
        let june = charge("2026-06-10", 20)
        let july = charge("2026-07-10", 22)
        let august = charge("2026-08-10", 22)
        let noise = [charge("2026-09-10", 99, flow: "refund"), charge("2026-09-11", 999, pending: true),
                     charge("2026-09-12", 999, flow: "transfer"), charge("2026-09-13", 999, flow: "ignored"),
                     charge("2026-09-14", 99, currency: "EUR")]
        let summary = SearchChargeSummary(record: service, transactions: [june, july, august, june] + noise, now: now, calendar: calendar)
        XCTAssertEqual(summary.latest?.id, august.id)
        XCTAssertEqual(summary.firstDate, june.date)
        XCTAssertEqual(summary.elapsedMonths, 3)
        XCTAssertEqual(summary.observedIncreases, 1)
        XCTAssertNil(SearchChargeSummary(record: service, transactions: [june, august], now: now, calendar: calendar).observedIncreases, "Missing billing periods cannot establish a price change")
        XCTAssertNil(SearchChargeSummary(record: service, transactions: [june, july, charge("2026-07-12", 3)], now: now, calendar: calendar).observedIncreases)
        XCTAssertNil(SearchChargeSummary(record: service, transactions: [june, charge("2026-07-10", 30, source: "card-b")], now: now, calendar: calendar).observedIncreases)
        XCTAssertEqual(SearchChargeSummary(record: service, transactions: [june, charge("2026-07-10", Decimal(string: "20.004")!)], now: now, calendar: calendar).observedIncreases, 0)
        service.financialFacts["billingCycle"] = "Yearly"
        XCTAssertEqual(SearchChargeSummary(record: service, transactions: [charge("2025-07-10", 100), charge("2026-07-10", 120)], now: now, calendar: calendar).observedIncreases, 1)
    }

    func testSearchCoverageIncludesOtherServicesDespiteSearchFilter() throws {
        let (state, a, b) = fixture()
        var card = FinancialCard(userId: owner, companyId: a.id, name: "Citi", limit: 100, balance: 0)
        card.plaidAccountId = "funding"
        var netflix = Subscription(userId: owner, companyId: a.id, name: "Netflix", cost: 60, paymentMethodId: card.id)
        netflix.nextRenewalAt = now
        var second = Subscription(userId: owner, companyId: a.id, name: "Other service", cost: 60, paymentMethodId: card.id)
        second.nextRenewalAt = now
        var unauthorized = Subscription(userId: UUID(), companyId: UUID(), name: "Private", cost: 999, paymentMethodId: card.id)
        unauthorized.nextRenewalAt = now
        state.cards = [card]; state.subscriptions = [netflix, second, unauthorized]
        func index() -> UniversalSearchIndex { UniversalSearchIndex(snapshot: SearchIndexSnapshot(state), userID: owner, now: now, calendar: calendar) }
        let result = try XCTUnwrap(overviews(index(), "Netflix", filters: .init(companyID: a.id)).first)
        XCTAssertEqual(result.root.fundingCoverage?.status, .atRisk)
        state.cards[0].limit = 120
        XCTAssertEqual(try XCTUnwrap(overviews(index(), "Netflix").first).root.fundingCoverage?.status, .covered)
        state.portfolioLoadIssue = "Incomplete fixture"
        XCTAssertEqual(try XCTUnwrap(overviews(index(), "Netflix").first).root.fundingCoverage?.status, .unknown)
        state.portfolioLoadIssue = nil
        state.subscriptions[0].billingCycle = "Yearly"
        state.subscriptions[0].nextRenewalAt = calendar.date(byAdding: .day, value: 60, to: now)
        XCTAssertNil(try XCTUnwrap(overviews(index(), "Netflix").first).root.fundingCoverage)
        XCTAssertTrue(overviews(index(), "Netflix", filters: .init(companyID: b.id)).isEmpty)
    }

    func testSearchCoverageHandlesStaleMissingAndInsufficientFunding() throws {
        let (state, a, _) = fixture()
        var account = InstitutionAccount(); account.name = "Checking"; account.balance = 100
        let bank = Institution(userId: owner, companyId: a.id, name: "Bank", accounts: [account])
        var sub = Subscription(userId: owner, companyId: a.id, name: "Netflix", cost: 20, paymentMethodId: bank.id)
        sub.nextRenewalAt = now
        state.institutions = [bank]; state.subscriptions = [sub]
        func coverage() throws -> SearchFundingCoverage? {
            let index = UniversalSearchIndex(snapshot: SearchIndexSnapshot(state), userID: owner, now: now, calendar: calendar)
            return try XCTUnwrap(overviews(index, "Netflix").first).root.fundingCoverage
        }
        XCTAssertEqual(try coverage()?.status, .covered)
        state.institutions[0].accounts[0].balance = 10
        XCTAssertEqual(try coverage()?.status, .atRisk)
        state.institutions[0].accounts[0].plaidAccountId = "stale-account"
        state.institutions[0].lastSyncedAt = calendar.date(byAdding: .day, value: -8, to: now)
        XCTAssertEqual(try coverage()?.status, .unknown)
        XCTAssertEqual(try coverage()?.reason, "Connected balance is out of date")
        state.institutions = []
        XCTAssertEqual(try coverage()?.status, .unknown)
    }

    func testPaidBaseRowsAndAmbiguousAccountHistoryStaySeparate() throws {
        let (state, a, _) = fixture()
        var source = FinancialCard(userId: owner, companyId: a.id, name: "Citi")
        source.plaidAccountId = "citi"
        var tesla = Subscription(userId: owner, companyId: a.id, name: "Tesla", cost: 30, paymentMethodId: source.id)
        tesla.subServices = [SubService(name: "Driving", cost: 100), SubService(name: "Insurance", cost: 120, serviceType: .bill)]
        var generic = transaction(a.id, card: source); generic.name = "Tesla"
        var child = transaction(a.id, card: source); child.name = "Tesla Insurance"
        state.cards = [source]; state.subscriptions = [tesla]; state.transactions = [generic, child]
        var result = try XCTUnwrap(overviews(state.searchIndex(for: owner), "Tesla").first)
        XCTAssertEqual(result.serviceRows.count, 3)
        XCTAssertEqual(result.serviceRows.first?.id, result.root.id)
        XCTAssertEqual(result.serviceCountsLabel, "1 Bill | 2 Subscriptions | 1 Payment source")
        XCTAssertEqual(result.transactions.count, 2)
        XCTAssertTrue(result.serviceTransactions[result.root.id]?.isEmpty == true)
        let insurance = try XCTUnwrap(result.children.first { $0.title == "Insurance" })
        XCTAssertEqual(result.serviceTransactions[insurance.id]?.map(\.modelID), [child.id])
        state.subscriptions[0].cost = 0
        result = try XCTUnwrap(overviews(state.searchIndex(for: owner), "Tesla").first)
        XCTAssertEqual(result.serviceRows.count, 2)
        XCTAssertEqual(result.serviceCountsLabel, "1 Bill | 1 Subscription | 1 Payment source")
    }

    func testStandaloneBillsAndSubscriptionsBothProduceOverviewCards() throws {
        let (state, company, _) = fixture()
        let bank = Institution(userId: owner, companyId: company.id, name: "Citibank Online", loginUrl: "citi.com")
        let card = FinancialCard(userId: owner, companyId: company.id, name: "Visa", institutionName: bank.name, last4: "9225")
        let att = Subscription(userId: owner, companyId: company.id, name: "At&t Bill Payment", cost: 157,
            paymentMethodId: card.id, website: "att.com")
        let bestBuy = Subscription(userId: owner, companyId: company.id, name: "Best Buy", cost: 29)
        state.institutions = [bank]; state.cards = [card]; state.subscriptions = [att, bestBuy]
        let index = state.searchIndex(for: owner)

        let attOverview = try XCTUnwrap(overviews(index, "att").first)
        let bestBuyOverview = try XCTUnwrap(overviews(index, "Best Buy").first)

        for overview in [attOverview, bestBuyOverview] {
            XCTAssertTrue(overview.children.isEmpty)
            XCTAssertEqual(overview.serviceRows.map(\.id), [overview.root.id])
        }
        XCTAssertEqual(attOverview.root.serviceType, "bill")
        XCTAssertEqual(bestBuyOverview.root.serviceType, "subscription")
        let paymentSource = try XCTUnwrap(attOverview.paymentSources(for: attOverview.root).first)
        XCTAssertEqual(paymentSource.title, "Visa")
        XCTAssertEqual(paymentSource.brandName, bank.name)
        XCTAssertEqual(SearchBrand.domain(for: paymentSource), "citi.com")
    }

    func testPastChargesStartsClosedAndShowsAllWithoutAffectingSibling() {
        var first = SearchHistoryDisplayState()
        let second = SearchHistoryDisplayState()
        XCTAssertEqual(first.visibleCount(12), 0)
        first.expanded = true
        XCTAssertEqual(first.visibleCount(12), 3)
        XCTAssertEqual(first.visibleCount(2), 2)
        first.showsAll = true
        XCTAssertEqual(first.visibleCount(12), 12)
        XCTAssertEqual(second.visibleCount(12), 0)
        first.expanded = false
        XCTAssertEqual(first.visibleCount(12), 0)
    }

    func testServiceOverviewGroupsSavedChildrenAndCountsActiveCostsOnce() throws {
        let (state, a, b) = fixture()
        var tesla = Subscription(userId: owner, companyId: a.id, name: "Tesla", cost: 0, website: "https://tesla.com", loginId: "driver@example.com", password: "test-only-secret")
        tesla.subServices = [SubService(name: "Connectivity", cost: 120, billingCycle: .yearly),
            SubService(name: "Driving", cost: 100), SubService(name: "Insurance", cost: 120, serviceType: .bill),
            SubService(name: "Paused feature", cost: 500, status: .paused)]
        state.subscriptions = [tesla, Subscription(userId: owner, companyId: b.id, name: "Tesla", cost: 50)]
        let index = state.searchIndex(for: owner)
        let all = overviews(index, "Tesla")
        XCTAssertEqual(all.count, 2)
        let card = try XCTUnwrap(all.first { $0.root.companyID == a.id })
        XCTAssertEqual(card.children.count, 4)
        XCTAssertEqual(card.billingTotals.map(\.cycle), ["monthly", "yearly"])
        XCTAssertEqual(card.billingTotals.map(\.amount), [220, 120])
        XCTAssertEqual(card.billingTotals.map(\.suffix), ["mo", "yr"])
        XCTAssertFalse(card.hasUnknownAmount)
        XCTAssertTrue(card.expandedChildIDs.isEmpty)
        XCTAssertEqual(card.children.first { $0.title == "Insurance" }?.serviceType, "bill")
        XCTAssertTrue(card.children.allSatisfy { $0.companyID == a.id })
        XCTAssertEqual(card.root.website, "https://tesla.com")
        XCTAssertFalse(index.search("Tesla").assistantEvidence().contains("test-only-secret"))
        XCTAssertEqual(overviews(index, "Tesla", filters: .init(companyID: b.id)).count, 1)
    }

    func testNamedChildOpensInsideItsParentAndExplicitQueriesStayPrecise() throws {
        let (state, a, _) = fixture()
        var tesla = Subscription(userId: owner, companyId: a.id, name: "Tesla")
        tesla.subServices = [SubService(name: "Insurance", cost: 120, serviceType: .bill), SubService(name: "Connectivity", cost: 10)]
        state.subscriptions = [tesla]
        let index = state.searchIndex(for: owner)
        let card = try XCTUnwrap(overviews(index, "Tesla insurance").first)
        XCTAssertEqual(card.children.first?.title, "Insurance")
        XCTAssertEqual(card.expandedChildIDs, [card.children[0].id])
        XCTAssertTrue(overviews(index, "Tesla transactions").isEmpty)
        XCTAssertTrue(overviews(index, "Tesla", filters: .init(serviceType: "bill")).isEmpty)
        XCTAssertTrue(overviews(index, "Tesla", filters: .init(period: .lastMonth)).isEmpty)
        XCTAssertTrue(overviews(index, "total Tesla services").isEmpty)
    }

    func testOverviewKeepsChildPaymentsDistinctAndDoesNotBorrowCardHistory() throws {
        let (state, a, _) = fixture()
        var citi = FinancialCard(userId: owner, companyId: a.id, name: "Citi", last4: "9225")
        citi.plaidAccountId = "citi-account"
        let sofi = FinancialCard(userId: owner, companyId: a.id, name: "SoFi", last4: "1234")
        state.cards = [citi, sofi]
        var tesla = Subscription(userId: owner, companyId: a.id, name: "Tesla", paymentMethodId: citi.id)
        tesla.subServices = [SubService(name: "Inherited", cost: 10),
            SubService(name: "Insurance", paymentMethodId: sofi.id, cost: 120),
            SubService(name: "Legacy name", paymentMethod: "SoFi", cost: 5),
            SubService(name: "Unknown", paymentMethod: "Unlinked card", cost: 3)]
        state.subscriptions = [tesla]; state.transactions = [transaction(a.id, card: citi)]
        let card = try XCTUnwrap(overviews(state.searchIndex(for: owner), "Tesla").first)
        func payment(_ title: String) -> [UUID] { card.paymentSources(for: card.children.first { $0.title == title }!).map(\.modelID) }
        XCTAssertEqual(payment("Inherited"), [citi.id])
        XCTAssertEqual(payment("Insurance"), [sofi.id])
        XCTAssertEqual(payment("Legacy name"), [sofi.id])
        XCTAssertTrue(payment("Unknown").isEmpty)
        XCTAssertTrue(card.transactions.isEmpty, "All charges on a funding card are not service charge history")
    }

    func testBankOverviewPrefersCanonicalAccountsAndNeverCombinesOwners() throws {
        let (state, a, b) = fixture()
        var checking = InstitutionAccount(); checking.name = "Checking"; checking.last4 = "1234"; checking.balance = 4250; checking.plaidAccountId = "checking"
        var credit = InstitutionAccount(); credit.name = "Credit"; credit.type = "Credit Card"; credit.balance = 640
        let mirror = FinancialCard(userId: owner, companyId: a.id, name: "SoFi card", login: "card@example.com", password: "card-test-only", last4: "9012", balance: 650)
        credit.linkedCardId = mirror.id.uuidString
        let bank = Institution(userId: owner, companyId: a.id, name: "SoFi", accounts: [checking, credit])
        state.institutions = [bank, Institution(userId: owner, companyId: b.id, name: "SoFi", accounts: [checking])]
        state.cards = [mirror]
        state.subscriptions = [Subscription(userId: owner, companyId: a.id, name: "Netflix", cost: 25, paymentMethodId: mirror.id)]
        let index = state.searchIndex(for: owner)
        let card = try XCTUnwrap(overviews(index, "SoFi").first { $0.root.companyID == a.id })
        XCTAssertEqual(card.balances.count, 2)
        XCTAssertEqual(card.bankCounts.label, "2 Accounts • 1 Card • 0 Loans")
        let otherBank = try XCTUnwrap(overviews(index, "SoFi").first { $0.root.companyID == b.id })
        XCTAssertEqual(otherBank.bankCounts.label, "1 Account • 0 Cards • 0 Loans")
        XCTAssertEqual(card.balances.first { $0.balanceCategory == .credit }?.amount, 640)
        XCTAssertEqual(card.paidServices.map(\.title), ["Netflix"])
        XCTAssertEqual(card.additionalLogins.map(\.modelID), [mirror.id])
        XCTAssertTrue(card.representedIDs.contains("card:\(mirror.id)"))
        XCTAssertTrue(card.balances.allSatisfy { $0.companyID == a.id })
        XCTAssertEqual(card.root.safeDetails["yourAccess"], "Owner")
        XCTAssertNil(card.root.safeDetails["sharedBy"])
        XCTAssertTrue(overviews(index, "1234").isEmpty, "Exact endings must not expand into sibling accounts")
    }

    func testBankHeaderCountsDeduplicateMirroredCardsAndLoans() throws {
        let (state, a, b) = fixture()
        var credit = InstitutionAccount(); credit.name = "Credit"; credit.type = "Credit Card"; credit.plaidAccountId = "credit"
        var mortgage = InstitutionAccount(); mortgage.name = "Mortgage"; mortgage.type = "Loan"; mortgage.plaidAccountId = "mortgage"
        var debit = InstitutionAccount(); debit.name = "Debit"; debit.type = "Debit (Linked)"; debit.plaidAccountId = "debit"
        var card = FinancialCard(userId: owner, companyId: a.id, name: "Bank credit card")
        card.plaidAccountId = "credit"; credit.linkedCardId = card.id.uuidString
        var loan = Loan(userId: owner, companyId: a.id, name: "Mortgage"); loan.plaidAccountId = "mortgage"
        state.cards = [card]; state.loans = [loan]
        state.institutions = [Institution(userId: owner, companyId: a.id, name: "SoFi", accounts: [credit, mortgage, debit]),
            Institution(userId: owner, companyId: b.id, name: "SoFi")]
        let results = overviews(state.searchIndex(for: owner), "SoFi")
        let bank = try XCTUnwrap(results.first { $0.root.companyID == a.id })
        XCTAssertEqual(bank.bankCounts.label, "3 Accounts • 2 Cards • 1 Loan")
        XCTAssertEqual(bank.balances.count, 3)
        XCTAssertEqual(results.first { $0.root.companyID == b.id }?.bankCounts.label, "0 Accounts • 0 Cards • 0 Loans")
    }

    func testBankOverviewIncludesSavedInstitutionNameWithoutSyncedAccounts() throws {
        let (state, a, b) = fixture()
        let first = Institution(userId: owner, companyId: a.id, name: "Citibank Online")
        let second = Institution(userId: owner, companyId: b.id, name: "Citibank Online")
        let costco = FinancialCard(userId: owner, companyId: a.id, name: "Costco Citi", institutionName: "Citibank Online")
        let otherCard = FinancialCard(userId: owner, companyId: b.id, name: "Citi Rewards", institutionName: "citibank online")
        let loan = Loan(userId: owner, companyId: a.id, lender: "Citibank Online", name: "Personal loan")
        state.institutions = [first, second]; state.cards = [costco, otherCard]; state.loans = [loan]
        state.subscriptions = [Subscription(userId: owner, companyId: a.id, name: "Netflix", cost: 25, paymentMethodId: costco.id)]
        var charge = transaction(a.id, card: costco); charge.accountId = costco.id.uuidString
        state.transactions = [charge]
        let index = state.searchIndex(for: owner)
        let results = overviews(index, "citi")
        let bank = try XCTUnwrap(results.first { $0.root.companyID == a.id })
        XCTAssertEqual(bank.bankCounts.label, "0 Accounts • 1 Card • 1 Loan")
        XCTAssertEqual(Set(bank.balances.map(\.modelID)), [costco.id, loan.id])
        XCTAssertEqual(bank.paidServices.map(\.title), ["Netflix"])
        XCTAssertEqual(bank.transactions.map(\.modelID), [charge.id])
        XCTAssertEqual(results.first { $0.root.companyID == b.id }?.bankCounts.label, "0 Accounts • 1 Card • 0 Loans")
        XCTAssertFalse(index.links[bank.id]?.contains("card:\(costco.id)") == true,
                       "The display association must not become a confirmed relationship")
        XCTAssertEqual(overviews(index, "citi", filters: .init(companyID: b.id)).first?.balances.map(\.modelID), [otherCard.id])
    }

    func testBankNameAssociationDoesNotGuessAmbiguousOrPartialMatches() throws {
        let (state, a, _) = fixture()
        state.institutions = [Institution(userId: owner, companyId: a.id, name: "Citibank Online"),
            Institution(userId: owner, companyId: a.id, name: "Citibank Online")]
        state.cards = [FinancialCard(userId: owner, companyId: a.id, name: "Costco Citi", institutionName: "Citibank Online")]
        XCTAssertTrue(overviews(state.searchIndex(for: owner), "citi").allSatisfy { $0.bankCounts.cards == 0 })
        state.institutions.removeLast()
        state.cards = [FinancialCard(userId: owner, companyId: a.id, name: "Citibank Online"),
            FinancialCard(userId: owner, companyId: a.id, name: "Costco Citi", institutionName: "Citi")]
        XCTAssertEqual(overviews(state.searchIndex(for: owner), "citi").first?.bankCounts.cards, 0,
                       "Only the saved full institution name establishes this fallback")
    }

    func testSyncedBankAssociationWinsOverStaleSavedInstitutionName() throws {
        let (state, a, _) = fixture()
        var card = FinancialCard(userId: owner, companyId: a.id, name: "Credit card", institutionName: "Citibank Online")
        card.plaidAccountId = "actual-bank-account"
        var account = InstitutionAccount(); account.type = "Credit Card"; account.plaidAccountId = card.plaidAccountId
        state.cards = [card]
        state.institutions = [Institution(userId: owner, companyId: a.id, name: "SoFi", accounts: [account]),
            Institution(userId: owner, companyId: a.id, name: "Citibank Online")]
        let index = state.searchIndex(for: owner)
        XCTAssertEqual(overviews(index, "citi").first?.bankCounts.cards, 0)
        XCTAssertEqual(overviews(index, "SoFi").first?.bankCounts.cards, 1)
        XCTAssertEqual(overviews(index, "SoFi").first?.balances.count, 1)
    }

    func testOverviewCombinesMerchantHistoryWithSavedLinksWithoutDuplicates() throws {
        let cid = UUID()
        let service = SearchRecord(kind: .subscription, modelID: UUID(), companyID: cid, company: "Personal", title: "Tesla", detail: "")
        let sameName = SearchRecord(kind: .transaction, modelID: UUID(), companyID: cid, company: "Personal", title: "Tesla", detail: "")
        let linked = SearchRecord(kind: .transaction, modelID: UUID(), companyID: cid, company: "Personal", title: "Saved charge", detail: "")
        let document = SearchRecord(kind: .document, modelID: UUID(), companyID: cid, company: "Personal", title: "Statement", detail: "")
        let index = UniversalSearchIndex(records: [service, sameName, linked, document], links: [service.id: [linked.id, document.id]])
        let card = try XCTUnwrap(overviews(index, "Tesla").first)
        XCTAssertEqual(Set(card.transactions.map(\.id)), [linked.id, sameName.id])
        XCTAssertEqual(card.documents.map(\.id), [document.id])
        XCTAssertTrue(card.representedIDs.contains(sameName.id), "Merchant history is removed from More matches")
        XCTAssertEqual(card.merchantMatchedTransactionIDs, [sameName.id])
    }

    func testServiceMerchantHistoryScopesAccountsCompaniesAndAmbiguousServices() throws {
        let (state, a, b) = fixture()
        var first = FinancialCard(userId: owner, companyId: a.id, name: "Card one"); first.plaidAccountId = "one"
        var second = FinancialCard(userId: owner, companyId: a.id, name: "Card two"); second.plaidAccountId = "two"
        state.cards = [first, second]
        let service = Subscription(userId: owner, companyId: a.id, name: "Netflix", paymentMethodId: first.id, website: "netflix.com")
        state.subscriptions = [service]
        var correct = transaction(a.id, card: first); correct.name = "NETFLIX.COM"
        var wrongCard = transaction(a.id, card: second); wrongCard.name = "Netflix"
        var otherCompany = transaction(b.id); otherCompany.name = "Netflix"
        var incidental = transaction(a.id, card: first); incidental.name = "Other merchant"
        var unrelatedName = transaction(a.id, card: first); unrelatedName.name = "Netflixish"
        var website = transaction(a.id, card: first); website.name = "Streaming charge"; website.merchantWebsite = "https://www.netflix.com"
        state.transactions = [correct, wrongCard, otherCompany, incidental, unrelatedName, website]
        var index = state.searchIndex(for: owner)
        let card = try XCTUnwrap(overviews(index, "Netflix").first)
        XCTAssertEqual(Set(card.transactions.map(\.modelID)), [correct.id, website.id])
        XCTAssertEqual(card.merchantMatchedTransactionIDs.count, 2)
        XCTAssertFalse(index.links["subscription:\(service.id)"]?.contains("transaction:\(correct.id)") == true, "Presentation matches must not become saved links")
        state.subscriptions.append(Subscription(userId: owner, companyId: a.id, name: "Netflix", paymentMethodId: first.id))
        index = state.searchIndex(for: owner)
        XCTAssertTrue(overviews(index, "Netflix").allSatisfy { $0.transactions.isEmpty }, "Duplicate service logins on the same payment card are ambiguous")
    }

    func testMerchantHistoryIncludesChildPaymentsWithoutGuessingEveryChild() throws {
        let (state, a, _) = fixture()
        var card = FinancialCard(userId: owner, companyId: a.id, name: "Card"); card.plaidAccountId = "tesla-funding"
        state.cards = [card]
        var tesla = Subscription(userId: owner, companyId: a.id, name: "Tesla", paymentMethodId: card.id)
        tesla.subServices = [SubService(name: "Insurance", cost: 100), SubService(name: "Connectivity", cost: 10)]
        state.subscriptions = [tesla]
        var insurance = transaction(a.id, card: card); insurance.name = "Tesla Insurance"
        var generic = transaction(a.id, card: card); generic.name = "Tesla"
        state.transactions = [insurance, generic]
        let overview = try XCTUnwrap(overviews(state.searchIndex(for: owner), "Tesla").first)
        XCTAssertEqual(overview.transactions.count, 2)
        let insuranceRecord = try XCTUnwrap(overview.children.first { $0.title == "Insurance" })
        let connectivity = try XCTUnwrap(overview.children.first { $0.title == "Connectivity" })
        XCTAssertEqual(overview.linked(to: insuranceRecord, kinds: [.transaction]).map(\.modelID), [insurance.id])
        XCTAssertTrue(overview.linked(to: connectivity, kinds: [.transaction]).isEmpty)
    }

    func testCredentialBoxesCopyCurrentValuesWithoutChangingVisibility() throws {
        let oldItems = UIPasteboard.general.items
        defer { UIPasteboard.general.items = oldItems }
        let (state, a, _) = fixture()
        var service = Subscription(userId: owner, companyId: a.id, name: "Service", loginId: "first@example.com", password: "test-copy-value")
        state.subscriptions = [service]
        let id = "subscription:\(service.id)"
        let controls = SearchCredentialBoxState()
        controls.copy(.password, recordID: id, appState: state, userID: owner)
        XCTAssertEqual(UIPasteboard.general.string, "test-copy-value")
        XCTAssertEqual(controls.copied, .password)
        XCTAssertNil(controls.revealed, "Copy must not reveal the secret")
        controls.togglePassword(recordID: id, appState: state, userID: owner)
        XCTAssertEqual(controls.revealed, "test-copy-value")
        service.loginId = "updated@example.com"; state.subscriptions = [service]
        controls.copy(.login, recordID: id, appState: state, userID: owner)
        XCTAssertEqual(UIPasteboard.general.string, "updated@example.com", "Copy resolves current authorized data")
        XCTAssertEqual(controls.copied, .login)
        controls.togglePassword(recordID: id, appState: state, userID: owner)
        XCTAssertNil(controls.revealed)
        XCTAssertEqual(UIPasteboard.general.string, "updated@example.com", "Eye must not copy")
        state.subscriptions = []
        controls.copy(.password, recordID: id, appState: state, userID: owner)
        XCTAssertNotNil(controls.error); XCTAssertNil(controls.copied); XCTAssertNil(controls.revealed)
        XCTAssertEqual(UIPasteboard.general.string, "updated@example.com", "Revoked access must not replace clipboard contents")
    }

    func testLogoSourcesUseSavedDomainsAndSafeFallbacks() {
        var record = SearchRecord(kind: .subscription, modelID: UUID(), companyID: nil, company: "", title: "Tesla", detail: "")
        XCTAssertEqual(SearchBrand.domain(for: record), "tesla.com")
        record.website = "https://login.example.com/private?query=ignored-for-artwork"
        XCTAssertEqual(SearchBrand.domain(for: record), "login.example.com")
        record.website = nil; record.title = "Unknown private service"
        XCTAssertNil(SearchBrand.domain(for: record))
        XCTAssertNil(SearchBrand.websiteURL("javascript:alert(1)"))
        XCTAssertNil(SearchBrand.websiteURL("https://user:password@example.com"))
        record.logoURL = "https://example.com/logo.png"
        let evidence = SearchResponse(hits: [.init(record: record, score: 1, reason: "")]).assistantEvidence()
        XCTAssertFalse(evidence.contains("logo.png"))
    }

    func testExactEndingsStayDistinctAndOnlyExpandSavedLinks() throws {
        let (state, a, b) = fixture()
        var first = FinancialCard(userId: owner, companyId: a.id, name: "Travel", last4: "4242")
        first.plaidAccountId = "plaid-north"
        let second = FinancialCard(userId: owner, companyId: b.id, name: "Travel", last4: "4242")
        let unrelated = FinancialCard(userId: owner, companyId: a.id, name: "Other", last4: "9999")
        state.cards = [first, second, unrelated]
        var service = Subscription(userId: owner, companyId: a.id, name: "Figma", cost: 15)
        service.paymentMethodId = first.id; state.subscriptions = [service]
        state.transactions = [transaction(a.id, card: first)]
        let index = state.searchIndex(for: owner)
        let result = index.search("4242")
        XCTAssertEqual(Set(result.hits.prefix(2).map(\.record.modelID)), [first.id, second.id])
        XCTAssertTrue(result.hits.contains { $0.record.modelID == service.id })
        XCTAssertTrue(result.hits.contains { $0.record.kind == .transaction })
        XCTAssertFalse(result.hits.contains { $0.record.modelID == unrelated.id })
        let scoped = index.search("4242", filters: .init(companyID: b.id))
        XCTAssertEqual(scoped.hits.map(\.record.modelID), [second.id])
        let cardOnly = index.search("4242", filters: .init(kind: .card))
        XCTAssertTrue(cardOnly.hits.allSatisfy { $0.record.kind == .card })
        let sourceKey = "card:\(first.id.uuidString)"
        XCTAssertTrue(index.links[sourceKey]?.contains("subscription:\(service.id.uuidString)") == true)
        XCTAssertFalse(index.links["card:\(second.id.uuidString)"]?.contains("subscription:\(service.id.uuidString)") == true)
        XCTAssertTrue(index.search("4243").hits.isEmpty, "Do not fuzzy-match numeric identifiers")
    }

    func testLegacyPaymentNamesNeverCrossCompaniesOrGuessAmbiguity() {
        let (state, a, b) = fixture()
        let cards = [a, a, b].map { FinancialCard(userId: owner, companyId: $0.id, name: "Shared name", last4: "1000") }
        state.cards = cards
        var service = Subscription(userId: owner, companyId: a.id, name: "Service", cost: 10)
        service.paymentMethod = "Shared name"; state.subscriptions = [service]
        XCTAssertNil(state.searchIndex(for: owner).links["subscription:\(service.id.uuidString)"])
        state.cards.remove(at: 1)
        let linked = state.searchIndex(for: owner).links["subscription:\(service.id.uuidString)"]
        XCTAssertEqual(linked, ["card:\(cards[0].id.uuidString)"])
    }

    func testPasswordsAndFullNumbersNeverEnterIndexOrAIEvidence() throws {
        let (state, a, _) = fixture()
        let password = "CANARY-secret-7X94"
        var sub = Subscription(userId: owner, companyId: a.id, name: "Figma", cost: 25)
        sub.password = password; sub.loginId = "owner@example.com"; sub.notes = "Old \(password). Password: other-hidden-value"
        state.subscriptions = [sub]
        var card = FinancialCard(userId: owner, companyId: a.id, name: "Visa", last4: "1234")
        card.cardNumber = "4111111111111234"; card.notes = card.cardNumber; state.cards = [card]
        let index = state.searchIndex(for: owner)
        XCTAssertTrue(index.search(password).hits.isEmpty)
        XCTAssertTrue(index.search(card.cardNumber!).hits.isEmpty)
        let response = index.search("Figma password")
        XCTAssertEqual(response.hits.count, 1)
        let text = response.assistantEvidence()
        XCTAssertFalse(text.contains(password)); XCTAssertFalse(text.contains("other-hidden-value")); XCTAssertFalse(text.contains("owner@example.com"))
        XCTAssertFalse(index.records.map(\.text).joined().contains(password))
        let key = response.hits[0].id
        XCTAssertEqual(try SearchCredentialAccess.resolve(recordID: key, appState: state, userID: owner), password)
        state.subscriptions.removeAll()
        XCTAssertThrowsError(try SearchCredentialAccess.resolve(recordID: key, appState: state, userID: owner))
    }

    func testCredentialPickerPreservesDuplicateNamesAndLockedState() {
        let (state, a, b) = fixture()
        state.subscriptions = [a, b].map { company in
            var sub = Subscription(userId: owner, companyId: company.id, name: "Figma", cost: 10)
            sub.password = company.id == a.id ? "device-value" : "enc:locked-ciphertext"; return sub
        }
        let response = state.searchIndex(for: owner).search("Figma password")
        XCTAssertEqual(response.hits.count, 2)
        XCTAssertEqual(Set(response.hits.map(\.record.companyID)), [a.id, b.id])
        XCTAssertTrue(response.hits.contains { $0.record.credential == .locked })
        XCTAssertEqual(state.searchIndex(for: owner).search("North Figma password").hits.count, 1)
    }

    func testCalendarTotalsSeparateCurrenciesAndExcludePendingTransfersIgnored() throws {
        let (state, a, _) = fixture()
        let expense = transaction(a.id, amount: 15)
        let euro = transaction(a.id, amount: 20, currency: "EUR")
        let refund = transaction(a.id, amount: -5)
        let transfer = transaction(a.id, amount: 1000)
        let ignored = transaction(a.id, amount: 3000)
        var pending = transaction(a.id, amount: 50); pending.pending = true
        let old = transaction(a.id, date: "2026-07-31", amount: 900)
        let new = transaction(a.id, date: "2026-09-01", amount: 800)
        let end = transaction(a.id, date: "2026-08-31", amount: 0.10)
        state.transactions = [expense, euro, refund, transfer, ignored, pending, old, new, end]
        state.transactionOverrides = [(refund, TransactionFlowOverride.refund), (transfer, .transfer), (ignored, .ignored)].map { TransactionOverride(userId: owner, transactionId: $0.0.id, flowOverride: $0.1) }
        let response = state.searchIndex(for: owner).search("Adobe charges last month", now: now, calendar: calendar)
        XCTAssertEqual(response.hits.count, 7)
        XCTAssertEqual(response.totals.first { $0.currency == "USD" && $0.label == "Posted expenses" }?.amount, Decimal(string: "15.1"))
        XCTAssertEqual(response.totals.first { $0.currency == "EUR" }?.amount, 20)
        XCTAssertEqual(response.totals.first { $0.label == "Posted refunds" }?.amount, 5)
        XCTAssertFalse(response.hits.contains { $0.record.modelID == old.id || $0.record.modelID == new.id })
        XCTAssertEqual(state.searchIndex(for: owner).search("Adobe charges August 2026", now: now, calendar: calendar).hits.count, 7)
    }

    func testMonthlyEquivalentUsesRealBillingCycleAndActiveAddons() throws {
        let (state, a, _) = fixture()
        var annual = Subscription(userId: owner, companyId: a.id, name: "Annual", cost: 120)
        annual.billingCycle = "Yearly"
        annual.subServices = [SubService(name: "Extra", cost: 24, billingCycle: .yearly), SubService(name: "Paused", cost: 200, status: .paused)]
        var cancelled = Subscription(userId: owner, companyId: a.id, name: "Cancelled", cost: 300); cancelled.status = "Cancelled"
        var unknown = Subscription(userId: owner, companyId: a.id, name: "Unknown", cost: 20); unknown.billingCycle = "Unspecified"
        state.subscriptions = [annual, cancelled, unknown]
        let result = state.searchIndex(for: owner).search("subscription spend")
        XCTAssertEqual(result.totals.first?.amount, 12)
        XCTAssertTrue(result.interpretation.contains("Unknown billing cycles excluded"))
        XCTAssertTrue(result.hits.first { $0.record.modelID == annual.id }!.record.detail.contains("Yearly"))
    }

    func testOwnerPrivateDocumentsAndSessionBoundaries() {
        let (state, a, _) = fixture()
        let other = UUID()
        var doc = CompanyDocument(userId: other, companyId: a.id, name: "Lease", notes: "Office renewal clause")
        doc.visibility = "owner_private"; state.documents = [doc]
        XCTAssertTrue(state.searchIndex(for: owner).search("lease").hits.isEmpty)
        state.documents[0].visibility = "company"
        XCTAssertEqual(state.searchIndex(for: owner).search("lease").hits.count, 1)
        XCTAssertTrue(state.searchIndex(for: other).search("lease").hits.isEmpty)
        state.clearSearchSession()
        XCTAssertTrue(state.searchIndex(for: owner).search("lease").hits.isEmpty)
    }

    func testIndividualSharesCanBeRevokedAndDoNotGrantOtherItems() {
        let (state, _, _) = fixture()
        let foreign = UUID(), company = UUID()
        var shared = Subscription(userId: foreign, companyId: company, name: "Shared", cost: 10); shared.password = "local-password"
        let hidden = Subscription(userId: foreign, companyId: company, name: "Hidden", cost: 10)
        state.subscriptions = [shared, hidden]
        state.resourceShares = [ResourceShare(resourceId: shared.id, resourceType: "subscription", userId: owner)]
        let index = state.searchIndex(for: owner)
        XCTAssertEqual(index.search("services").hits.map(\.record.modelID), [shared.id])
        state.resourceShares = []
        XCTAssertTrue(state.searchIndex(for: owner).search("services").hits.isEmpty)
    }

    func testFreshnessStableIDsAndLocalReassignment() {
        let (state, a, b) = fixture()
        var card = FinancialCard(userId: owner, companyId: a.id, name: "Café Travel", last4: "2000"); card.plaidAccountId = "account"
        state.cards = [card]; state.transactions = [transaction(a.id, card: card)]
        let original = state.searchIndex(for: owner).search("cafe travel").hits[0].id
        XCTAssertEqual(state.searchIndex(for: owner).search("cafe travle").hits[0].id, original)
        state.cards[0].name = "Renamed"; state.localCompanyOverrides[card.id.uuidString] = b.id
        let refreshed = state.searchIndex(for: owner)
        XCTAssertTrue(refreshed.search("cafe").hits.isEmpty)
        XCTAssertEqual(refreshed.search("Renamed").hits[0].id, original)
        XCTAssertEqual(refreshed.search("transactions", filters: .init(companyID: b.id)).hits.count, 1)
        XCTAssertTrue(refreshed.search("transactions", filters: .init(companyID: a.id)).hits.isEmpty)
    }

    func testDocumentSnippetsHavePagesAndIgnoreReplacedFiles() {
        let (state, a, _) = fixture()
        let doc = CompanyDocument(userId: owner, companyId: a.id, name: "Lease", url: "lease-v1.pdf")
        state.documents = [doc]
        state.searchDocumentPages = [.init(documentID: doc.id, page: 3, text: "The renewal clause requires sixty days notice.", sourceURL: doc.url)]
        let result = state.searchIndex(for: owner).search("renewal clause")
        XCTAssertEqual(result.hits.first?.record.page, 3)
        XCTAssertTrue(result.hits.first?.snippet?.contains("sixty days") == true)
        state.documents[0].url = "lease-v2.pdf"
        XCTAssertTrue(state.searchIndex(for: owner).search("renewal clause").hits.isEmpty)
    }

    func testPDFTextExtractionPreservesPageNumbers() throws {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 600))
        let data = renderer.pdfData { context in
            context.beginPage(); ("First page with lease details" as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
            context.beginPage(); ("Renewal clause: sixty days notice" as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
        }
        let result = try SearchDocumentIndexer.extract(data, documentID: UUID(), sourceURL: "fixture.pdf")
        XCTAssertEqual(result.pages.count, 2); XCTAssertEqual(result.pages[1].page, 2)
        XCTAssertTrue(result.pages[1].text.contains("Renewal clause")); XCTAssertFalse(result.limited)
    }

    func testRenewalsUseNextCalendarMonthAndSkipCancelledServices() {
        let (state, a, _) = fixture()
        state.subscriptions = ["2026-09-30", "2026-10-01", "2026-10-31", "2026-11-01"].map { date in
            var sub = Subscription(userId: owner, companyId: a.id, name: date, cost: 10); sub.nextRenewalAt = SearchText.date(date, calendar: calendar); return sub
        }
        state.subscriptions[2].status = "Cancelled"
        let result = state.searchIndex(for: owner).search("renewals next month", now: now, calendar: calendar)
        XCTAssertEqual(result.hits.map(\.record.title), ["2026-10-01"])
    }

    func testSearchPerformanceOnTenThousandTransactions() {
        let (state, a, _) = fixture()
        state.transactions = (0..<10_000).map { i in transaction(a.id, date: "2026-08-\(String(format: "%02d", i % 28 + 1))", amount: Double(i % 100)) }
        let index = state.searchIndex(for: owner)
        let start = CFAbsoluteTimeGetCurrent()
        let response = index.search("Adobe charges last month", now: now, calendar: calendar)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        XCTAssertEqual(response.hits.count, 10_000)
        XCTAssertLessThan(elapsed, 1.0, "Simulator regression ceiling; physical-device p95 is a separate release check")
    }
    func testGroupedHistoryPagingKeepsRemainingMatchesAndScales() {
        let company = UUID()
        let root = SearchRecord(kind: .subscription, modelID: UUID(), companyID: company, company: "Fixture", title: "Adobe", detail: "")
        let records = (0..<10_000).map { i in
            SearchRecord(kind: .transaction, modelID: UUID(), companyID: company, company: "Fixture", title: "Adobe \(i)", detail: "")
        }
        var response = SearchResponse()
        response.hits = records.enumerated().map { SearchHit(record: $0.element, score: $0.offset % 2 == 0 ? 100 : -100, reason: "Fixture") }
        let overview = SearchOverview(root: root, representedIDs: Set(records.prefix(9_900).map(\.id)))
        var timings: [Double] = []
        for _ in 0..<20 {
            let start = CFAbsoluteTimeGetCurrent()
            let page = SearchResultPage(response: response, overviews: [overview], limit: 40)
            timings.append(CFAbsoluteTimeGetCurrent() - start)
            XCTAssertEqual(page.directHits.count, 20)
            XCTAssertEqual(page.relatedHits.count, 20)
            XCTAssertEqual(page.directHits.first?.id, records[9_900].id)
            XCTAssertTrue(page.hasMore)
        }
        let p95 = timings.sorted()[18]
        print("Grouped 10,000-hit page p95: \(p95 * 1_000) ms")
        XCTAssertLessThan(p95, 0.1, "Grouping must not rebuild the represented-ID set for every hit")
        let all = SearchResultPage(response: response, overviews: [overview], limit: 100)
        XCTAssertEqual(all.directHits.count + all.relatedHits.count, 100)
        XCTAssertFalse(all.hasMore)
        let hidden = SearchResultPage(response: response, overviews: [overview], limit: 0)
        XCTAssertTrue(hidden.hasMore)
    }

    func testCancelledSearchSkipsRankingAndOverviewHistory() async {
        let record = SearchRecord(kind: .subscription, modelID: UUID(), companyID: UUID(), company: "Fixture", title: "Adobe", detail: "")
        let index = UniversalSearchIndex(records: [record])
        let work = Task.detached {
            while !Task.isCancelled { await Task.yield() }
            let request = PortfolioQuery.interpret("Adobe")
            let response = index.execute(request)
            return (response.hits.count, index.overviews(for: response, request: request, filters: .init()).count)
        }
        work.cancel()
        let result = await work.value
        XCTAssertEqual(result.0, 0)
        XCTAssertEqual(result.1, 0)
    }

    func testBackgroundIndexMatchesProjectionAndRejectsChangedSessions() async throws {
        let (state, a, _) = fixture()
        state.subscriptions = [Subscription(userId: owner, companyId: a.id, name: "Adobe", cost: 20)]
        state.transactions = (0..<1_000).map { _ in transaction(a.id) }
        let expected = UniversalSearchIndex(appState: state, userID: owner)
        let background = try await state.searchIndexInBackground(for: owner)
        XCTAssertEqual(background.records, expected.records)
        XCTAssertEqual(background.links, expected.links)
        state.subscriptions[0].name = "Renamed service"
        let refreshed = try await state.searchIndexInBackground(for: owner)
        XCTAssertTrue(refreshed.records.contains { $0.title == "Renamed service" })
        let snapshot = SearchIndexSnapshot(state)
        state.clearSearchSession()
        let old = UniversalSearchIndex(snapshot: snapshot, userID: owner)
        XCTAssertTrue(old.isLoaded, "Value snapshot remains internally consistent")
        do {
            _ = try await state.searchIndexInBackground(for: owner)
            XCTFail("A cleared session must not return the old snapshot")
        } catch is CancellationError { } catch { XCTFail("Unexpected error: \(error)") }
        XCTAssertFalse(state.searchIndex(for: owner).isLoaded)
    }

    func testTypingWithLargeGroupedHistoryDoesNotBlockMainActor() async throws {
        let (state, a, _) = fixture()
        state.subscriptions = [Subscription(userId: owner, companyId: a.id, name: "Adobe", cost: 20)]
        state.transactions = (0..<10_000).map { _ in transaction(a.id) }
        // Include the initial background build as well as repeated query updates.
        let auth = AuthViewModel()
        auth.currentUser = User(id: owner, appMetadata: [:], userMetadata: [:], aud: "authenticated", createdAt: now, updatedAt: now)
        auth.isAuthenticated = true
        let vm = AppViewModel(); vm.searchQuery = "Adobe"
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        let controller = UIHostingController(rootView: SearchSheetTestHost(content: GlobalSearchView(vm: vm).environment(state).environment(auth).environment(AccessController())))
        window.frame = scene.coordinateSpace.bounds; window.rootViewController = controller; window.makeKeyAndVisible()
        defer { controller.dismiss(animated: false); window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        var delays: [Double] = []
        for query in ["Adob", "Adobe", "Ado", "Adob", "Adobe", "A", "Ad", "Ado", "Adob", "Adobe", "Adob", "Adobe", "Ado", "Adobe", "Adobe", "Adobe", "Adobe", "Adobe", "Adobe", "Adobe"] {
            let start = CFAbsoluteTimeGetCurrent()
            vm.searchQuery = query
            try await Task.sleep(for: .milliseconds(150))
            delays.append(CFAbsoluteTimeGetCurrent() - start - 0.15)
        }
        let worst = delays.max() ?? 0
        print("10,000-charge typing: worst main-actor scheduling delay \(worst * 1_000) ms")
        XCTAssertLessThan(worst, 0.5, "Typing must not stall while existing grouped cards are rendered")
        XCTAssertEqual(vm.searchQuery, "Adobe")
    }

    func testSearchScreenRendersExactMatchesAndRelatedActions() async throws {
        let (state, a, b) = fixture()
        var first = FinancialCard(userId: owner, companyId: a.id, name: "Travel Visa", password: "fixture-only", institutionName: "Chase", last4: "4242", limit: 10000, balance: 1234.56)
        let second = FinancialCard(userId: owner, companyId: b.id, name: "Business Visa", institutionName: "Chase", last4: "4242")
        first.plaidAccountId = "render-card"
        state.cards = [first, second]
        var service = Subscription(userId: owner, companyId: a.id, name: "Figma", cost: 144)
        service.billingCycle = "Yearly"; service.paymentMethodId = first.id; service.loginId = "design@example.com"; service.password = "fixture-only"
        service.website = "https://figma.com"
        var tesla = Subscription(userId: owner, companyId: a.id, name: "Tesla", paymentMethodId: first.id,
            website: "https://tesla.com", loginId: "driver@example.com", password: "fixture-only")
        tesla.subServices = [SubService(name: "Premium Connectivity", cost: 120, billingCycle: .yearly, renewsOn: now),
            SubService(name: "Full Self-Driving", cost: 548, renewsOn: now),
            SubService(name: "Insurance", cost: 120, renewsOn: now, serviceType: .bill)]
        tesla.cost = 283; tesla.serviceType = .bill; tesla.nextRenewalAt = Date().addingTimeInterval(86400 * 11)
        var netflix = Subscription(userId: owner, companyId: a.id, name: "Netflix", cost: 26.99, paymentMethodId: first.id,
            website: "https://netflix.com", loginId: "viewer@example.com", password: "fixture-only")
        netflix.nextRenewalAt = Date().addingTimeInterval(86400 * 11)
        var secondNetflix = netflix; secondNetflix.id = UUID(); secondNetflix.companyId = b.id; secondNetflix.paymentMethodId = second.id
        var att = Subscription(userId: owner, companyId: a.id, name: "At&t Bill Payment", cost: 157, paymentMethodId: first.id,
            website: "att.com")
        att.nextRenewalAt = Date().addingTimeInterval(86400 * 11)
        var bestBuy = Subscription(userId: owner, companyId: a.id, name: "Best Buy", cost: 29, paymentMethodId: first.id)
        bestBuy.nextRenewalAt = Date().addingTimeInterval(86400 * 11)
        state.subscriptions = [service, tesla, netflix, secondNetflix, att, bestBuy]
        var checking = InstitutionAccount(); checking.name = "Checking"; checking.last4 = "1234"; checking.balance = 4250
        var savings = InstitutionAccount(); savings.name = "Savings"; savings.last4 = "5678"; savings.balance = 12800; savings.type = "Savings"
        var credit = InstitutionAccount(); credit.name = "Credit Card"; credit.type = "Credit Card"; credit.last4 = "9012"; credit.balance = 640
        var loan = InstitutionAccount(); loan.name = "Auto Loan"; loan.type = "Loan"; loan.last4 = "2345"; loan.balance = 15200
        state.institutions = [Institution(userId: owner, companyId: a.id, name: "SoFi", loginUrl: "https://sofi.com", username: "owner@example.com", password: "fixture-only", accounts: [checking, savings, credit, loan])]
        state.institutions.append(Institution(userId: owner, companyId: b.id, name: "SoFi", loginUrl: "https://sofi.com", accounts: [checking]))
        // Saved bank-name associations can exist without a mirrored synced account.
        state.institutions.append(Institution(userId: owner, companyId: a.id, name: "Citibank Online", loginUrl: "https://citi.com"))
        let citiPayment = FinancialCard(userId: owner, companyId: a.id, name: "Visa", institutionName: "Citibank Online", last4: "9225", balance: 640)
        state.cards.append(citiPayment)
        if let index = state.subscriptions.firstIndex(where: { $0.id == att.id }) {
            state.subscriptions[index].paymentMethodId = citiPayment.id
        }
        var charge = transaction(a.id, card: first, amount: 144); charge.name = "Figma"
        var insuranceCharge = transaction(a.id, card: first, amount: 120); insuranceCharge.name = "Tesla Insurance"
        state.transactions = [transaction(a.id, amount: 1400), charge, insuranceCharge]
        for date in ["2026-08-01", "2025-12-01", "2025-06-01", "2024-07-01"] {
            var unmatched = transaction(a.id, date: date, amount: 99); unmatched.name = "Tesla archived charge"
            state.transactions.append(unmatched)
        }
        for month in 4...8 {
            var payment = transaction(a.id, card: first, date: "2026-0\(month)-23", amount: month < 6 ? 24.99 : 26.99)
            payment.name = "Netflix"; state.transactions.append(payment)
        }
        let auth = AuthViewModel()
        auth.currentUser = User(id: owner, appMetadata: [:], userMetadata: [:], aud: "authenticated", createdAt: now, updatedAt: now)
        auth.isAuthenticated = true
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let variants: [(String, DynamicTypeSize, String)] = [
            ("4242", .large, "Exact ending"),
            ("Figma", .large, "Service and password actions"),
            ("Netflix", .large, "Netflix separate entity cards"),
            ("Netflix", .accessibility3, "Netflix accessibility"),
            ("att", .large, "Standalone bill layout"),
            ("Best Buy", .large, "Standalone subscription layout"),
            ("Figma", .accessibility3, "Large accessibility text"),
            ("Tesla", .large, "Grouped Tesla services"),
            ("Tesla", .accessibility3, "Large mixed billing"),
            ("Tesla insurance", .large, "Expanded Tesla insurance"),
            ("Tesla", .large, "Tesla yearly more matches"),
            ("SoFi", .large, "Bank overview"),
            ("SoFi", .accessibility3, "Bank accessibility"),
            ("citi", .large, "Citi saved card without synced accounts"),
            ("North Studio pending transactions last month", .large, "Inferred filters"),
            ("North Studio pending transactions last month", .accessibility3, "Inferred filters accessibility"),
            ("Netflix history", .large, "Netflix charge history"),
            ("No matching record", .large, "No results"),
            ("", .large, "First open"),
            ("largest transaction", .large, "Calculated answer")
        ]
        var pendingFixture = transaction(a.id, date: "2026-08-15"); pendingFixture.pending = true
        pendingFixture.name = "Pending fixture purchase"
        state.transactions.append(pendingFixture)
        for (query, size, label) in variants {
            let vm = AppViewModel(); vm.searchQuery = query
            let search = GlobalSearchView(vm: vm).environment(state).environment(auth).environment(AccessController())
                .environment(\.dynamicTypeSize, size)
                // A standalone UIHostingController does not inherit WindowGroup's active phase.
                .environment(\.scenePhase, .active)
            let host = SearchSheetTestHost(content: search)
            let controller = UIHostingController(rootView: host)
            controller.overrideUserInterfaceStyle = .dark
            let previous = scene.windows.first { $0.isKeyWindow }
            let window = UIWindow(windowScene: scene)
            window.frame = scene.coordinateSpace.bounds; window.windowLevel = .normal
            window.rootViewController = controller; window.makeKeyAndVisible()
            try await Task.sleep(for: .milliseconds(900))
            controller.view.layoutIfNeeded()
            XCTAssertNotNil(controller.presentedViewController, "Review the real system sheet, not a full-screen approximation")
            let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
            let image = renderer.image { _ in XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)) }
            let attachment = XCTAttachment(image: image); attachment.name = "Search sheet – " + label; attachment.lifetime = .keepAlways; add(attachment)
            XCTAssertEqual(vm.searchQuery, query, "Prefilled queries must survive sheet presentation and layout")
            // Optional simulator-only window for inspecting real taps with this synthetic portfolio.
            // TEST_RUNNER_MILOOM_SEARCH_DESIGN_REVIEW=1 enables it when invoking xcodebuild.
            if query == "Netflix", size == .large,
               ProcessInfo.processInfo.environment["MILOOM_SEARCH_DESIGN_REVIEW"] == "1" {
                print("Search design fixture ready for interactive review")
                try await Task.sleep(for: .seconds(90))
            }
            if label == "Tesla yearly more matches",
               ProcessInfo.processInfo.environment["MILOOM_SEARCH_YEAR_REVIEW"] == "1" {
                print("Search yearly fixture ready for interactive review")
                try await Task.sleep(for: .seconds(90))
            }
            if query == "North Studio pending transactions last month", size == .large,
               ProcessInfo.processInfo.environment["MILOOM_SEARCH_FILTER_REVIEW"] == "1" {
                print("Search filter fixture ready for interactive review")
                try await Task.sleep(for: .seconds(120))
            }
            controller.dismiss(animated: false)
            window.isHidden = true; window.rootViewController = nil; previous?.makeKey()
        }
        XCTAssertTrue(state.searchIndex(for: owner).search("4242").hits.contains { $0.record.modelID == service.id })
    }

    func testMonthlyCostBreakdownKeepsCompaniesSeparate() {
        let (state, a, b) = fixture()
        state.subscriptions = [Subscription(userId: owner, companyId: a.id, name: "North service", cost: 10), Subscription(userId: owner, companyId: b.id, name: "South service", cost: 20)]
        let result = state.searchIndex(for: owner).search("subscription spend per company")
        XCTAssertEqual(result.totals.count, 2)
        XCTAssertEqual(result.totals.first { $0.label.contains(a.name) }?.amount, 10)
        XCTAssertEqual(result.totals.first { $0.label.contains(b.name) }?.amount, 20)
    }

    func testExactLookupP95WithLargeIndex() {
        let company = UUID()
        let records = (0..<10_000).map { i in
            var r = SearchRecord(kind: .card, modelID: UUID(), companyID: company, company: "Fixture", title: "Card \(i)", detail: "Visa •••• \(String(format: "%04d", i))")
            r.last4 = String(format: "%04d", i); return r
        }
        let index = UniversalSearchIndex(records: records)
        var timings: [Double] = []
        for _ in 0..<20 {
            let start = CFAbsoluteTimeGetCurrent()
            XCTAssertEqual(index.search("4242").hits.first?.record.last4, "4242")
            timings.append((CFAbsoluteTimeGetCurrent() - start) * 1000)
        }
        let p95 = timings.sorted()[18]
        let attachment = XCTAttachment(string: "10,000 synthetic cards, 20 warm exact-ending lookups, simulator p95 \(p95) ms. Index construction excluded. Physical-device performance remains to be measured.")
        attachment.name = "Search performance"; attachment.lifetime = .keepAlways; add(attachment)
        XCTAssertLessThan(p95, 300)
    }

    func testDirectCredentialAccessUsesCurrentValueAndChecksSession() throws {
        let (state, a, _) = fixture()
        var sub = Subscription(userId: owner, companyId: a.id, name: "Figma", cost: 10); sub.password = "fixture-secret"
        state.subscriptions = [sub]
        let id = "subscription:\(sub.id.uuidString)"
        XCTAssertEqual(try SearchCredentialAccess.resolve(recordID: id, appState: state, userID: owner), "fixture-secret")
        state.subscriptions[0].password = "current-value"
        XCTAssertEqual(try SearchCredentialAccess.resolve(recordID: id, appState: state, userID: owner), "current-value")
        XCTAssertThrowsError(try SearchCredentialAccess.resolve(recordID: id, appState: state, userID: UUID()))
        state.subscriptions[0].password = "enc:unavailable"
        XCTAssertThrowsError(try SearchCredentialAccess.resolve(recordID: id, appState: state, userID: owner))
        state.subscriptions = []
        XCTAssertThrowsError(try SearchCredentialAccess.resolve(recordID: id, appState: state, userID: owner))
        state.subscriptions = [sub]; state.clearSearchSession()
        XCTAssertThrowsError(try SearchCredentialAccess.resolve(recordID: id, appState: state, userID: owner))
    }

    func testFinancialFactsReachLiveToolResponseWithoutSecrets() throws {
        let (state, a, _) = fixture()
        let card = FinancialCard(userId: owner, companyId: a.id, name: "Costco Citi", password: "CANARY-financial-secret",
            last4: "9225", limit: 18000, paidOn: "15th", autopay: "Yes", balance: 1234.56, moPayment: 85, apr: 24.99)
        state.cards = [card]
        let result = state.searchIndex(for: owner).search("what is my balance on Costco Citi 9225")
        XCTAssertEqual(result.hits.map(\.record.modelID), [card.id])
        let facts = try XCTUnwrap(result.hits.first?.record.financialFacts)
        XCTAssertEqual(facts["currentBalance"], "1234.56")
        XCTAssertEqual(facts["creditLimit"], "18000")
        XCTAssertEqual(facts["storedMonthlyPayment"], "85")
        XCTAssertEqual(facts["aprPercent"], "24.99")
        XCTAssertEqual(facts["paymentDue"], "15th")
        // Same FunctionResponse type and evidence payload used by Gemini Live, tested through wire encoding.
        let response = FunctionResponse(id: "fixture", name: "searchPortfolio", response: ["success": AnyCodable(true), "evidence": AnyCodable(result.assistantEvidence())])
        let data = try JSONEncoder().encode(response)
        let wire = try JSONDecoder().decode(FunctionResponse.self, from: data)
        let evidence = try XCTUnwrap(wire.response["evidence"]?.value as? String)
        XCTAssertTrue(evidence.contains("1234.56")); XCTAssertTrue(evidence.contains("18000")); XCTAssertTrue(evidence.contains("24.99"))
        XCTAssertFalse(evidence.contains("CANARY-financial-secret"))
        for question in ["Citi APR", "Citi credit limit", "Citi monthly payment", "how much do I owe on Citi", "what's my Citi balance right now"] {
            XCTAssertEqual(state.searchIndex(for: owner).search(question).hits.first?.record.modelID, card.id, question)
        }
        state.cards[0].balance = 987.65
        XCTAssertTrue(state.searchIndex(for: owner).search("Citi balance").assistantEvidence().contains("987.65"))
    }

    func testBankBalancesIncludeAccountsAndDeduplicateMirroredCards() throws {
        let (state, a, b) = fixture()
        var card = FinancialCard(userId: owner, companyId: a.id, name: "Chase Visa", last4: "1000", balance: 400)
        card.plaidAccountId = "durable-account"
        var credit = InstitutionAccount(); credit.name = "Chase Visa"; credit.type = "Credit Card"; credit.balance = 425
        credit.availableBalance = 575; credit.limit = 1000; credit.last4 = "1000"; credit.linkedCardId = card.id.uuidString; credit.plaidAccountId = card.plaidAccountId
        var cash = InstitutionAccount(); cash.name = "Operating"; cash.balance = 2500; cash.availableBalance = 2300; cash.last4 = "2000"
        let bank = Institution(userId: owner, companyId: a.id, name: "Chase", accounts: [credit, cash], lastSyncedAt: now, isDisconnected: true)
        var other = FinancialCard(userId: owner, companyId: b.id, name: "Chase Visa", last4: "1000", balance: 900)
        other.plaidAccountId = "different-account"
        state.cards = [card, other]; state.institutions = [bank]
        let index = state.searchIndex(for: owner)
        let result = index.search("Chase bank balances", filters: .init(companyID: a.id))
        XCTAssertEqual(result.hits.filter { $0.record.kind == .account }.count, 2)
        XCTAssertTrue(result.assistantEvidence().contains("2300")); XCTAssertTrue(result.assistantEvidence().contains("Needs attention"))
        XCTAssertTrue(result.assistantEvidence().contains(ISO8601DateFormatter().string(from: now)))
        let all = index.search("Chase balances", filters: .init(companyID: a.id))
        XCTAssertEqual(all.totals.first { $0.label == "Credit card balances" }?.amount, 425)
        XCTAssertEqual(all.totals.first { $0.label == "Cash balances" }?.amount, 2500)
        XCTAssertEqual(all.totals.first { $0.label == "Credit card balances" }?.sourceIDs.count, 1)
        XCTAssertEqual(Set(all.hits.filter { [.card, .account].contains($0.record.kind) && $0.record.last4 == "1000" }.compactMap(\.record.balanceIdentity)).count, 1)
        XCTAssertFalse(all.hits.contains { $0.record.companyID == b.id })
        XCTAssertFalse(all.assistantEvidence().contains("durable-account"))
        XCTAssertEqual(index.search("available Chase balance", filters: .init(companyID: a.id)).totals.first { $0.label == "Available credit" }?.amount, 575)
    }

    func testDebtCashAndCurrenciesStaySeparateAndUnavailableIsNotZero() throws {
        let (state, a, _) = fixture()
        state.cards = [FinancialCard(userId: owner, companyId: a.id, name: "Visa", balance: 125)]
        var euro = InstitutionAccount(); euro.name = "Europe"; euro.currency = "EUR"; euro.balance = 600
        var dollars = InstitutionAccount(); dollars.name = "Operating"; dollars.balance = 700; dollars.availableBalance = 650
        state.institutions = [Institution(userId: owner, companyId: a.id, name: "Bank", accounts: [euro, dollars])]
        let debt = Loan(userId: owner, companyId: a.id, name: "Equipment", principalAmount: 12000, remainingBalance: 5000, interestRate: 8.5, monthlyPayment: 200, nextPaymentAt: now)
        let receivable = Loan(userId: owner, companyId: a.id, role: "Lender", name: "Customer loan", remainingBalance: 8000)
        state.loans = [debt, receivable]
        let index = state.searchIndex(for: owner)
        let owing = index.search("how much do I owe")
        XCTAssertEqual(Set(owing.hits.map(\.record.modelID)), [state.cards[0].id, debt.id])
        XCTAssertEqual(owing.totals.count, 2)
        XCTAssertEqual(index.search("balances").totals.count, 5)
        XCTAssertEqual(index.search("how much money do I have").totals.count, 2)
        let available = index.search("available balances")
        XCTAssertEqual(available.totals.count, 1)
        XCTAssertEqual(available.totals.first?.amount, 650)
        XCTAssertTrue(available.interpretation.contains("partial"))
        XCTAssertTrue(index.search("available Visa balance").totals.isEmpty)
        let loanFacts = try XCTUnwrap(index.search("Equipment loan balance").hits.first?.record.financialFacts)
        XCTAssertEqual(loanFacts["principalAmount"], "12000"); XCTAssertEqual(loanFacts["storedInterestRate"], "8.5")
        XCTAssertEqual(loanFacts["storedMonthlyPayment"], "200"); XCTAssertEqual(loanFacts["nextPayment"], SearchText.day(now))
        let historical = index.search("balances last month", now: now, calendar: calendar)
        XCTAssertTrue(historical.hits.isEmpty); XCTAssertTrue(historical.interpretation.contains("Historical balances"))
    }

    func testFinancialEvidencePaginationPreservesCompleteTotals() throws {
        let (state, a, _) = fixture()
        state.cards = (0..<15).map { FinancialCard(userId: owner, companyId: a.id, name: "Card \($0)", balance: 100) }
        let result = state.searchIndex(for: owner).search("credit card balances")
        func payload(_ offset: Int) throws -> [String: Any] {
            try XCTUnwrap(JSONSerialization.jsonObject(with: Data(result.assistantEvidence(offset: offset).utf8)) as? [String: Any])
        }
        let first = try payload(0), second = try payload(12)
        let firstRecords = try XCTUnwrap(first["records"] as? [[String: Any]])
        let secondRecords = try XCTUnwrap(second["records"] as? [[String: Any]])
        XCTAssertEqual(firstRecords.count, 12); XCTAssertEqual(secondRecords.count, 3)
        XCTAssertEqual(first["hasMoreRecords"] as? Bool, true); XCTAssertEqual(second["hasMoreRecords"] as? Bool, false)
        XCTAssertEqual(first["nextOffset"] as? Int, 12)
        XCTAssertEqual(Set((firstRecords + secondRecords).compactMap { $0["sourceID"] as? String }).count, 15)
        XCTAssertEqual(result.totals.first?.amount, 1500)
        let total = try XCTUnwrap((second["totals"] as? [[String: Any]])?.first)
        XCTAssertEqual(total["amount"] as? String, "1500")
        XCTAssertEqual((total["sourceIDs"] as? [String])?.count, 12)
        XCTAssertEqual(total["sourceCount"] as? Int, 15)
        XCTAssertEqual(total["sourceIDsTruncated"] as? Bool, true)
    }

    func testDocumentDateFilterDistinguishesUploadAndExpiry() {
        let (state, a, _) = fixture()
        state.documents = [CompanyDocument(userId: owner, companyId: a.id, name: "Lease", uploadDate: "2026-08-12", expiresAt: SearchText.date("2026-10-15", calendar: calendar))]
        let index = state.searchIndex(for: owner)
        XCTAssertEqual(index.search("documents last month", now: now, calendar: calendar).hits.count, 1)
        XCTAssertEqual(index.search("documents renew next month", now: now, calendar: calendar).hits.count, 1)
        XCTAssertTrue(index.search("documents next month", now: now, calendar: calendar).hits.isEmpty)
    }

    func testLoanPaymentLookupOpensItsParentLedger() {
        let (state, a, _) = fixture()
        var loan = Loan(userId: owner, companyId: a.id, name: "Equipment")
        let payment = LoanPayment(userId: owner, loanId: loan.id, date: SearchText.date("2026-08-10", calendar: calendar)!, amount: 75)
        loan.payments = [payment]; state.loans = [loan]
        let result = state.searchIndex(for: owner).search("Equipment loan payments last month", now: now, calendar: calendar)
        XCTAssertEqual(result.hits.first?.record.modelID, payment.id)
        XCTAssertEqual(result.hits.first?.record.destinationID, loan.id)
    }

    func testImageOCRFindsDocumentContent() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 180))
        let image = renderer.image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1200, height: 180))
            ("RENEWAL CLAUSE: SIXTY DAYS NOTICE" as NSString).draw(at: CGPoint(x: 30, y: 60), withAttributes: [.font: UIFont.systemFont(ofSize: 40), .foregroundColor: UIColor.black])
        }
        let extracted = try SearchDocumentIndexer.extract(try XCTUnwrap(image.pngData()), documentID: UUID(), sourceURL: "scan.png")
        XCTAssertTrue(extracted.pages.first?.text.lowercased().contains("sixty days") == true)
    }

    func testLargestAcrossFullHistoryNotFirstPageAndKeepsTiesAndCurrencies() throws {
        let (state, a, _) = fixture()
        state.transactions = (0..<1100).map { i in transaction(a.id, date: i == 1099 ? "2020-01-01" : "2026-09-10", amount: i == 1099 ? 9000 : 10) }
        let winner = state.transactions.last!.id
        var pending = transaction(a.id, amount: 50000); pending.pending = true
        state.transactions.append(pending)
        state.transactions.append(transaction(a.id, amount: 9000))
        state.transactions.append(transaction(a.id, amount: 100, currency: "EUR"))
        let response = state.searchIndex(for: owner).search("What is my biggest transaction?", now: now, calendar: calendar)
        XCTAssertTrue(response.hits.contains { $0.record.modelID == winner })
        XCTAssertFalse(response.hits.contains { $0.record.modelID == pending.id })
        XCTAssertEqual(response.metrics.filter { $0.currency == "USD" }.map(\.value), [9000, 9000])
        XCTAssertEqual(response.metrics.filter { $0.currency == "EUR" }.map(\.value), [100])
        XCTAssertTrue(response.spokenAnswer.contains("9,000"))
        let payload = try JSONSerialization.jsonObject(with: Data(response.assistantEvidence().utf8)) as! [String: Any]
        XCTAssertEqual((payload["calculations"] as? [[String: Any]])?.count, 3)
    }

    func testBillSubscriptionClassificationAndMixedAddonsAreNeverCollapsed() throws {
        let (state, a, _) = fixture()
        var internet = Subscription(userId: owner, companyId: a.id, name: "Internet", cost: 100, serviceType: .bill)
        internet.subServices = [SubService(name: "Streaming add-on", cost: 12, serviceType: .subscription)]
        state.subscriptions = [internet, Subscription(userId: owner, companyId: a.id, name: "Netflix", cost: 20, serviceType: .subscription)]
        let index = state.searchIndex(for: owner)
        XCTAssertEqual(index.search("How much are my bills each month?").totals.first?.amount, 100)
        XCTAssertEqual(index.search("subscription spend").totals.first?.amount, 32)
        XCTAssertEqual(index.search("services cost").totals.first?.amount, 132)
        let payload = try JSONSerialization.jsonObject(with: Data(index.search("bills").assistantEvidence().utf8)) as! [String: Any]
        XCTAssertEqual((payload["records"] as? [[String: Any]])?.first?["serviceType"] as? String, "bill")
        state.subscriptions[0].serviceType = .subscription
        XCTAssertTrue(state.searchIndex(for: owner).search("bills").hits.isEmpty)
    }

    func testTypedQueriesValidateDatesScopesAndSourceAccess() throws {
        let (state, a, b) = fixture()
        state.transactions = [transaction(a.id, date: "2026-08-01", amount: 10), transaction(a.id, date: "2026-08-31", amount: 30), transaction(b.id, amount: 900)]
        var query = try JSONDecoder().decode(PortfolioQuery.self, from: Data("{\"query\":\"\",\"operation\":\"average\",\"kind\":\"transaction\",\"companyName\":\"North Studio\",\"startDate\":\"2026-08-01\",\"endDate\":\"2026-08-31\"}".utf8))
        let index = state.searchIndex(for: owner)
        XCTAssertEqual(index.execute(query).metrics.first?.value, 20)
        XCTAssertTrue(index.execute(query, filters: .init(companyID: b.id)).hits.isEmpty)
        query.operation = .details; query.sourceID = "transaction:\(UUID())"
        XCTAssertTrue(index.execute(query).hits.isEmpty)
        query.operation = .sum; query.endDate = "bad-date"
        XCTAssertTrue(index.execute(query).metrics.isEmpty)
        query.endDate = "2026-08-31"; query.limit = 1000
        XCTAssertTrue(index.execute(query).metrics.isEmpty)
        XCTAssertThrowsError(try JSONDecoder().decode(PortfolioQuery.self, from: Data("{\"operation\":\"runSQL\"}".utf8)))
    }

    func testGroupedTotalsAndCalendarMonthComparisonUseAllMatches() {
        let (state, a, _) = fixture()
        state.transactions = [transaction(a.id, date: "2026-08-01", amount: 25), transaction(a.id, date: "2026-08-31", amount: 75), transaction(a.id, date: "2026-09-01", amount: 130)]
        let index = state.searchIndex(for: owner)
        XCTAssertEqual(index.search("average expense last month", now: now, calendar: calendar).metrics.first?.value, 50)
        XCTAssertEqual(index.search("how many transactions last month", now: now, calendar: calendar).metrics.first?.value, 2)
        let compared = index.search("What increased since last month?", now: now, calendar: calendar)
        XCTAssertEqual(compared.metrics.first?.value, 30)
        XCTAssertEqual(compared.metrics.first?.previousValue, 100)
        XCTAssertTrue(compared.interpretation.contains("2026-08-01"))
    }

    func testFollowUpsPreserveMetricAndReplacePeriod() {
        let (state, a, b) = fixture()
        state.transactions = [transaction(a.id, date: "2026-08-10", amount: 100), transaction(a.id, date: "2026-09-10", amount: 50), transaction(b.id, amount: 999)]
        let first = PortfolioQuery.interpret("largest expense this month")
        let second = PortfolioQuery.interpret("only North Studio", previous: first)
        let third = PortfolioQuery.interpret("last month", previous: second)
        let index = state.searchIndex(for: owner)
        XCTAssertEqual(index.execute(second, now: now, calendar: calendar).metrics.first?.value, 50)
        XCTAssertEqual(index.execute(third, now: now, calendar: calendar).metrics.first?.value, 100)
        XCTAssertEqual(third.operation, .largest)
    }

    func testAdditionalRecordsRespectOwnershipRefreshAndSecretRedaction() throws {
        let (state, a, _) = fixture()
        let password = "HIDDEN-CANARY-591"
        state.subscriptions = [Subscription(userId: owner, companyId: a.id, name: "App", password: password)]
        let notice = AppNotification(id: UUID(), userId: owner, notificationType: "test", title: "Renewal notice", body: "Plan changed. Password: \(password)", isRead: false)
        state.notifications = [notice, AppNotification(id: UUID(), userId: UUID(), notificationType: "test", title: "Other user", body: "Private", isRead: false)]
        let index = state.searchIndex(for: owner)
        XCTAssertEqual(index.search("notifications").hits.count, 1)
        XCTAssertFalse(index.search("notifications").assistantEvidence().contains(password))
        state.notifications = []
        XCTAssertTrue(state.searchIndex(for: owner).search("notifications").hits.isEmpty)
        state.clearSearchSession()
        XCTAssertTrue(state.searchIndex(for: owner).search("App").hits.isEmpty)
    }

    func testSourceDetailsAndRelatedQueriesUseAuthorizedIndexOnly() {
        let (state, a, _) = fixture()
        let card = FinancialCard(userId: owner, companyId: a.id, name: "Visa", last4: "1234")
        var bill = Subscription(userId: owner, companyId: a.id, name: "Electricity", cost: 85, serviceType: .bill)
        bill.paymentMethodId = card.id; bill.notes = "Customer reference sunshine"
        state.cards = [card]; state.subscriptions = [bill]
        let index = state.searchIndex(for: owner)
        var query = PortfolioQuery(); query.operation = .related; query.sourceID = "card:\(card.id.uuidString)"; query.kind = .subscription
        XCTAssertEqual(index.execute(query).hits.map(\.record.modelID), [bill.id])
        query.operation = .details; query.sourceID = "subscription:\(bill.id.uuidString)"
        XCTAssertTrue(index.execute(query).assistantEvidence().contains("sunshine"))
        XCTAssertFalse(index.execute(query).assistantEvidence().contains("password"))
    }

    func testSiriBridgeRejectsLockedAndChangedSessions() {
        let (state, _, _) = fixture()
        let auth = AuthViewModel()
        auth.currentUser = User(id: owner, appMetadata: [:], userMetadata: [:], aud: "authenticated", createdAt: now, updatedAt: now)
        let bridge = SearchIntentSession(); bridge.appState = state; bridge.auth = auth
        auth.isAuthenticated = false
        XCTAssertNil(bridge.currentIndex())
        auth.isAuthenticated = true
        XCTAssertNotNil(bridge.currentIndex())
        state.portfolioUserID = UUID()
        XCTAssertNil(bridge.currentIndex())
        XCTAssertFalse(SearchResponse(isCredentialRequest: true).spokenAnswer.contains("fixture-secret"))
    }

    func testCalculationPagesAreBoundedButTotalsAreComplete() throws {
        let (state, a, _) = fixture()
        state.transactions = (0..<30).map { i in
            var t = transaction(a.id, amount: Double(i + 1)); t.name = "Merchant \(i)"; return t
        }
        var query = PortfolioQuery(); query.operation = .sum; query.kind = .transaction; query.groupBy = .merchant
        let response = state.searchIndex(for: owner).execute(query)
        XCTAssertEqual(response.metrics.count, 30)
        XCTAssertEqual(response.metrics.reduce(Decimal.zero) { $0 + $1.value }, 465)
        let page = try JSONSerialization.jsonObject(with: Data(response.assistantEvidence(offset: 12).utf8)) as! [String: Any]
        XCTAssertEqual((page["calculations"] as? [[String: Any]])?.count, 12)
        XCTAssertEqual(page["hasMoreCalculations"] as? Bool, true)
    }

    func testOptionalToolOperationPreservesExplicitFilters() throws {
        let request = try PortfolioQuery.toolRequest(["query": AnyCodable(""), "kind": AnyCodable("subscription"), "serviceType": AnyCodable("bill"), "includePending": AnyCodable(true)])
        XCTAssertEqual(request.kind, .subscription); XCTAssertEqual(request.serviceType, "bill")
        XCTAssertTrue(request.includePending)
        XCTAssertThrowsError(try PortfolioQuery.toolRequest(["kind": AnyCodable("invalid-kind")]))
    }

    func testFiltersAndInvalidCalendarDaysCannotBroadenQueries() {
        let (state, a, _) = fixture()
        state.subscriptions = [Subscription(userId: owner, companyId: a.id, name: "Netflix", cost: 20, serviceType: .subscription)]
        XCTAssertTrue(state.searchIndex(for: owner).search("subscriptions", filters: .init(kind: .subscription, serviceType: "bill")).hits.isEmpty)
        XCTAssertNil(SearchText.date("2026-02-31", calendar: calendar))
        XCTAssertNil(SearchText.date("2026-13-01", calendar: calendar))
        XCTAssertEqual(state.searchIndex(for: owner).search("North Studio").hits.first?.record.kind, .company)
    }

    func testMonthlyBillsPaidByCardCanBeCalculatedThroughSourceLink() {
        let (state, a, _) = fixture()
        let card = FinancialCard(userId: owner, companyId: a.id, name: "Visa", last4: "1234")
        var bill = Subscription(userId: owner, companyId: a.id, name: "Electricity", cost: 85, serviceType: .bill)
        bill.paymentMethodId = card.id
        state.cards = [card]; state.subscriptions = [bill]
        var query = PortfolioQuery(); query.operation = .sum; query.sourceID = "card:\(card.id.uuidString)"; query.kind = .subscription; query.serviceType = "bill"
        XCTAssertEqual(state.searchIndex(for: owner).execute(query).metrics.first?.value, 85)
    }

    func testMissingReceiptLookupExcludesAlreadyDocumentedReviews() {
        let (state, a, _) = fixture()
        state.businessExpenseUserID = owner
        let source = BusinessExpenseSource(merchant: "Office", date: "2026-09-01", amount: 100, currency: "USD", sourceCompanyId: a.id, accountName: "Visa", institutionName: "Bank")
        let incomplete = BusinessExpenseReview(id: UUID(), decision: "confirmed", sourceState: "active", source: source, revision: 1, updatedAt: "2026-09-01", allocation: BusinessExpenseAllocation(companyId: a.id), suggestions: [], documents: [], missing: ["Receipt or missing-receipt explanation"])
        var complete = incomplete; complete.id = UUID(); complete.missing = []
        state.businessExpenseReviews = [incomplete, complete]
        XCTAssertEqual(state.searchIndex(for: owner).search("Which expenses need receipts?").hits.map(\.record.modelID), [incomplete.id])
    }

    func testAuthenticatedTextAndLiveQueryToolsWhenOptedIn() async throws {
        guard ProcessInfo.processInfo.environment["MILOOM_QUERY_INTEGRATION"] == "1" else { throw XCTSkip("Enable MILOOM_QUERY_INTEGRATION for metered Gemini query verification.") }
        // Unsigned simulator builds may not persist Keychain sessions across test installation.
        // Opt in to a UI sign-in window; credentials never enter the test or its environment.
        if ProcessInfo.processInfo.environment["MILOOM_QUERY_WAIT_FOR_SIGN_IN"] == "1" {
            for _ in 0..<120 {
                if (try? await SupabaseService.shared.client.auth.session) != nil { break }
                try await Task.sleep(for: .seconds(1))
            }
        }
        guard (try? await SupabaseService.shared.client.auth.session) != nil else { throw XCTSkip("A signed-in simulator session is required for real Gemini text and voice verification.") }
        let (state, a, _) = fixture()
        var big = transaction(a.id, amount: 1400); big.name = "Archive"
        state.transactions = [transaction(a.id, amount: 10), big]
        state.subscriptions = [Subscription(userId: owner, companyId: a.id, name: "Internet", cost: 85, serviceType: .bill), Subscription(userId: owner, companyId: a.id, name: "Netflix", cost: 20, serviceType: .subscription)]
        let index = state.searchIndex(for: owner)
        let request = try await SearchAnswerService.queryRequest(for: "What is my biggest transaction?", useGemini: true)
        let ranked = index.execute(request)
        XCTAssertEqual(ranked.metrics.first?.value, 1400)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(ranked.assistantEvidence().utf8)) as? [String: Any])
        let calculation = try XCTUnwrap((payload["calculations"] as? [[String: Any]])?.first)
        XCTAssertEqual(calculation["recordTitle"] as? String, "Archive")
        XCTAssertEqual(calculation["company"] as? String, "North Studio")
        let textAnswer = try await SearchAnswerService.answer(question: "How much are my bills each month?", evidence: index.search("bills cost").assistantEvidence(), useGemini: true)
        XCTAssertTrue(textAnswer.contains("85"))
        let tools = [Tool(functionDeclarations: [FunctionDeclaration(name: "searchPortfolio", description: PortfolioQuery.assistantInstructions, parameters: Schema(type: "OBJECT", properties: PortfolioQuery.toolProperties, required: ["query"]))])]
        let client = GeminiLiveClient(systemInstruction: PortfolioQuery.assistantInstructions + " Always call searchPortfolio before answering. Reply briefly in English.", tools: tools)
        defer { client.disconnect() }
        let answered = expectation(description: "Gemini Live retrieves and speaks the largest transaction")
        var transcript = "", calls = 0, finished = false, heardAudio = false
        let listener = client.events.sink { event in
            switch event {
            case .tools(let envelope):
                for call in envelope.functionCalls {
                    calls += 1
                    guard calls <= 4 else { XCTFail("Exceeded query tool budget"); return }
                    do {
                        let query = try PortfolioQuery.toolRequest(call.args)
                        let result = index.execute(query)
                        client.sendToolResponse(response: FunctionResponse(id: call.id, name: call.name, response: ["success": AnyCodable(true), "evidence": AnyCodable(result.assistantEvidence())]))
                    } catch { XCTFail("Invalid structured query from Live") }
                }
            case .outputTranscript(let value): transcript += value.text ?? ""
            case .audio(let data): heardAudio = heardAudio || data.contains { $0 != 0 }
            case .turnComplete where !finished: finished = true; answered.fulfill()
            default: break
            }
        }
        defer { listener.cancel() }
        try await client.connect()
        client.sendTextMessage("What is my biggest transaction?")
        await fulfillment(of: [answered], timeout: 30)
        XCTAssertGreaterThan(calls, 0)
        XCTAssertTrue(heardAudio)
        let spoken = XCTAttachment(string: transcript); spoken.name = "Synthetic Gemini Live answer"; spoken.lifetime = .keepAlways; add(spoken)
        XCTAssertTrue(transcript.lowercased().contains("archive"), "Live should name the matching merchant")
        XCTAssertTrue(transcript.contains("1,400") || transcript.contains("1400") || transcript.lowercased().contains("fourteen hundred") || transcript.lowercased().contains("one thousand four hundred"))
    }

}

private struct SearchSheetTestHost<Content: View>: View {
    let content: Content
    @State private var showing = false
    var body: some View {
        Color.zifrBG.ignoresSafeArea()
            .overlay(alignment: .topLeading) { Text("Miloom").font(.largeTitle.bold()).padding(24) }
            .sheet(isPresented: $showing) { content }
            .task {
                try? await Task.sleep(for: .milliseconds(100))
                showing = true
            }
    }
}

// Regression coverage for the September 19 search audit.
extension UniversalSearchTests {
    func testRegressionLiteralNamesAndAccountsRemainSearches() {
        let (state, a, _) = fixture()
        state.subscriptions = [Subscription(userId: owner, companyId: a.id, name: "Topgolf", cost: 50)]
        XCTAssertEqual(PortfolioQuery.interpret("Topgolf").operation, .search)
        XCTAssertEqual(PortfolioQuery.interpret("accounts").operation, .search)
        XCTAssertEqual(state.searchIndex(for: owner).search("Topgolf").hits.count, 1)
    }
    func testRegressionServiceNameContainingPaymentFindsParent() {
        let (state, a, _) = fixture()
        var service = Subscription(userId: owner, companyId: a.id, name: "Tesla")
        service.subServices = [SubService(name: "Car Payment", cost: 283, serviceType: .bill)]
        state.subscriptions = [service]
        let result = overviews(state.searchIndex(for: owner), "Tesla Car Payment")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.expandedChildIDs, Set(result.first?.children.map(\.id) ?? []))
        XCTAssertFalse(result.first?.expandedChildIDs.isEmpty ?? true)
        XCTAssertTrue(overviews(state.searchIndex(for: owner), "Tesla").first?.expandedChildIDs.isEmpty ?? false)
    }
    func testRegressionPendingAndExcludedPendingTransactionQueries() {
        let (state, a, _) = fixture()
        let posted = transaction(a.id)
        var pending = transaction(a.id); pending.pending = true
        state.transactions = [posted, pending]
        let index = state.searchIndex(for: owner)
        XCTAssertEqual(index.search("pending transactions").hits.map(\.record.modelID), [pending.id])
        XCTAssertEqual(index.search("exclude pending transactions").hits.map(\.record.modelID), [posted.id])
    }
    func testRegressionFilteredBalanceSumUsesFilteredRecords() {
        let (state, a, _) = fixture()
        var first = InstitutionAccount(); first.name = "Checking"; first.balance = 50
        var second = InstitutionAccount(); second.name = "Savings"; second.balance = 150
        state.institutions = [Institution(userId: owner, companyId: a.id, name: "SoFi", accounts: [first, second])]
        var request = PortfolioQuery(); request.query = "balances"; request.operation = .sum; request.minAmount = "100"
        let response = state.searchIndex(for: owner).execute(request)
        XCTAssertEqual(response.hits.count, 1)
        XCTAssertEqual(response.totals.reduce(Decimal.zero) { $0 + $1.amount }, 150)
    }
    func testRegressionNextServicePaymentQueryKeepsSubscription() {
        let (state, a, _) = fixture()
        var service = Subscription(userId: owner, companyId: a.id, name: "Netflix", cost: 26.99)
        service.nextRenewalAt = now.addingTimeInterval(86400)
        state.subscriptions = [service]
        XCTAssertEqual(state.searchIndex(for: owner).search("Netflix next payment").hits.map(\.record.modelID), [service.id])
    }
    func testRegressionSharedChargeDoesNotBecomeTwoServiceSummaries() throws {
        let company = UUID()
        let parent = SearchRecord(kind: .subscription, modelID: UUID(), companyID: company, company: "Personal", title: "Tesla", detail: "")
        var first = SearchRecord(kind: .subscription, modelID: parent.modelID, companyID: company, company: "Personal", title: "Insurance", detail: "", suffix: ":one")
        first.parentServiceID = parent.id
        var second = SearchRecord(kind: .subscription, modelID: parent.modelID, companyID: company, company: "Personal", title: "Driving", detail: "", suffix: ":two")
        second.parentServiceID = parent.id
        var charge = SearchRecord(kind: .transaction, modelID: UUID(), companyID: company, company: "Personal", title: "Combined Tesla charge", detail: "")
        charge.date = now; charge.amount = 100; charge.flow = "expense"
        let index = UniversalSearchIndex(records: [parent, first, second, charge], links: [parent.id: [first.id, second.id], first.id: [parent.id, charge.id], second.id: [parent.id, charge.id], charge.id: [first.id, second.id]])
        let result = try XCTUnwrap(overviews(index, "Tesla").first)
        XCTAssertEqual(result.transactions.count, 1)
        XCTAssertNil(result.chargeSummaries[first.id]?.latest)
        XCTAssertNil(result.chargeSummaries[second.id]?.latest)
    }
}

extension UniversalSearchTests {
    func testCommandWordsRequireBoundariesAndRespectSavedNames() throws {
        let (state, a, _) = fixture()
        state.subscriptions = ["Topgolf", "Discount Tire", "Total Wine", "Bill", "Next Payment"].map {
            Subscription(userId: owner, companyId: a.id, name: $0, cost: 10)
        }
        let index = state.searchIndex(for: owner)
        for name in state.subscriptions.map(\.name) {
            XCTAssertEqual(index.search(name).hits.first?.record.title, name, name)
            XCTAssertEqual(overviews(index, name).first?.root.title, name, name)
        }
        XCTAssertEqual(PortfolioQuery.interpret("top 5 services").operation, .largest)
        XCTAssertEqual(PortfolioQuery.interpret("top 5 services").limit, 5)
        XCTAssertEqual(PortfolioQuery.interpret("how many accounts").operation, .count)
        var explicit = PortfolioQuery(); explicit.query = "Total Wine"; explicit.operation = .count; explicit.kind = .subscription
        XCTAssertEqual(index.execute(explicit).metrics.first?.value, 1, "An explicit tool operation is never replaced by literal search")
    }

    func testPendingStateAppliesToSearchCalculationsAndTools() throws {
        let (state, a, _) = fixture()
        var posted = transaction(a.id); posted.amount = 10
        var pending = transaction(a.id); pending.pending = true; pending.amount = 20
        state.transactions = [posted, pending]
        let index = state.searchIndex(for: owner)
        for phrase in ["only pending transactions", "pending transactions"] {
            XCTAssertEqual(index.search(phrase).hits.map(\.record.modelID), [pending.id], phrase)
        }
        for phrase in ["posted transactions", "excluding pending transactions", "transactions without pending"] {
            XCTAssertEqual(index.search(phrase).hits.map(\.record.modelID), [posted.id], phrase)
        }
        for phrase in ["transactions", "transactions including pending", "transactions with pending"] {
            XCTAssertEqual(index.search(phrase).hits.count, 2, phrase)
        }
        for (phrase, amount) in [("sum transactions", 10), ("sum pending transactions", 20), ("sum transactions including pending", 30)] {
            XCTAssertEqual(index.search(phrase).metrics.first?.value, Decimal(amount), phrase)
        }
        let decoded = try JSONDecoder().decode(PortfolioQuery.self, from: Data(#"{"query":"transactions","operation":"sum","transactionState":"pending"}"#.utf8))
        XCTAssertEqual(index.execute(decoded).metrics.first?.value, 20)
        let followUp = PortfolioQuery.interpret("only North Studio", previous: .interpret("pending transactions"))
        XCTAssertEqual(followUp.transactionState, .pending)
    }

    func testFilteredBalanceTotalsKeepCurrencyAndCanonicalSources() throws {
        let (state, a, _) = fixture()
        var card = FinancialCard(userId: owner, companyId: a.id, name: "Mirror", balance: 150)
        card.plaidAccountId = "mirror-account"
        var credit = InstitutionAccount(); credit.type = "Credit Card"; credit.balance = 150; credit.plaidAccountId = card.plaidAccountId
        var cash = InstitutionAccount(); cash.balance = 50
        var euro = InstitutionAccount(); euro.balance = 200; euro.currency = "EUR"
        state.cards = [card]
        state.institutions = [Institution(userId: owner, companyId: a.id, name: "Test Bank", accounts: [credit, cash, euro])]
        var request = PortfolioQuery(); request.query = "balances"; request.operation = .sum; request.minAmount = "100"
        let response = state.searchIndex(for: owner).execute(request)
        XCTAssertEqual(response.totals.count, 2)
        XCTAssertEqual(response.totals.first { $0.currency == "USD" }?.amount, 150)
        XCTAssertEqual(response.totals.first { $0.currency == "EUR" }?.amount, 200)
        let eligible = Set(response.hits.map(\.id))
        XCTAssertTrue(response.totals.allSatisfy { Set($0.sourceIDs).isSubset(of: eligible) })
        XCTAssertEqual(response.totals.flatMap(\.sourceIDs).count, 2)
    }

    func testInstitutionAndSearchShareEntityIdentityAndAmbiguityRules() throws {
        let (state, a, b) = fixture()
        let first = Institution(userId: owner, companyId: a.id, name: "Citibank Online")
        let second = Institution(userId: owner, companyId: b.id, name: "Citibank Online")
        var synced = InstitutionAccount(); synced.type = "Credit Card"; synced.plaidAccountId = "synced-card"
        let actual = Institution(userId: owner, companyId: a.id, name: "Actual Bank", accounts: [synced])
        var card = FinancialCard(userId: owner, companyId: a.id, name: "Card", institutionName: " Citibank Online ")
        let other = FinancialCard(userId: owner, companyId: b.id, name: "Other Card", institutionName: "citibank online")
        let loan = Loan(userId: owner, companyId: a.id, lender: "Citibank Online", name: "Loan")
        state.institutions = [first, second, actual]; state.cards = [card, other]; state.loans = [loan]
        func verify(_ expected: Set<UUID>) {
            let deck = InstitutionRelationships(institutions: state.institutions, cards: state.cards, loans: state.loans, connections: state.resourceConnections)
            XCTAssertEqual(deck.banks(for: .card, id: card.id), expected)
            let search = state.searchIndex(for: owner).institutionProductAssociations()
            XCTAssertEqual(Set(search.filter { $0.value.contains { $0.modelID == card.id } }.keys), expected)
            XCTAssertEqual(deck.banks(for: .card, id: other.id), [second.id])
            XCTAssertEqual(deck.banks(for: .loan, id: loan.id), [first.id])
        }
        verify([first.id])
        card.plaidAccountId = "synced-card"; state.cards[0] = card
        verify([actual.id])
        card.plaidAccountId = nil; state.cards[0] = card
        state.resourceConnections = [ResourceConnection(ownerUserId: owner, sourceType: .card, sourceId: card.id,
            targetType: .institution, targetId: actual.id, relationshipType: .connectedAccount,
            origin: .manual, confidence: 1, state: .confirmed)]
        verify([actual.id])
        state.resourceConnections[0].state = .suggested
        verify([first.id])
        state.resourceConnections = []
        state.institutions.append(Institution(userId: owner, companyId: a.id, name: "Citibank Online"))
        let deck = InstitutionRelationships(institutions: state.institutions, cards: state.cards, loans: state.loans, connections: [])
        XCTAssertTrue(deck.banks(for: .card, id: card.id).isEmpty)
        XCTAssertFalse(state.searchIndex(for: owner).institutionProductAssociations().values.contains { $0.contains { $0.modelID == card.id } })
    }

    func testParentChildSharedChargeRemainsOnlyInAccountHistory() throws {
        let company = UUID()
        let parent = SearchRecord(kind: .subscription, modelID: UUID(), companyID: company, company: "Personal", title: "Tesla", detail: "")
        var child = SearchRecord(kind: .subscription, modelID: parent.modelID, companyID: company, company: "Personal", title: "Insurance", detail: "", suffix: ":one")
        child.parentServiceID = parent.id
        var charge = SearchRecord(kind: .transaction, modelID: UUID(), companyID: company, company: "Personal", title: "Combined", detail: "")
        charge.date = now; charge.amount = 100; charge.flow = "expense"
        let index = UniversalSearchIndex(records: [parent, child, charge], links: [parent.id: [child.id, charge.id], child.id: [parent.id, charge.id]])
        let result = try XCTUnwrap(overviews(index, "Tesla").first)
        XCTAssertEqual(result.transactions.count, 1)
        XCTAssertTrue(result.serviceTransactions[parent.id]?.isEmpty ?? false)
        XCTAssertTrue(result.serviceTransactions[child.id]?.isEmpty ?? false)
        XCTAssertNil(result.chargeSummaries[child.id]?.latest)
    }
}

extension UniversalSearchTests {
    func testLiteralNameFollowUpRetainsCompanyConstraint() {
        let (state, a, b) = fixture()
        state.subscriptions = [Subscription(userId: owner, companyId: a.id, name: "Netflix", cost: 10),
                               Subscription(userId: owner, companyId: b.id, name: "Netflix", cost: 20)]
        let request = PortfolioQuery.interpret("only North Studio", previous: .interpret("Netflix"))
        let response = state.searchIndex(for: owner).execute(request)
        XCTAssertEqual(response.hits.count, 1)
        XCTAssertEqual(response.hits.first?.record.companyID, a.id)
    }

    func testServiceScheduleIntentAndExplicitTypeBoundary() {
        let (state, a, _) = fixture()
        var service = Subscription(userId: owner, companyId: a.id, name: "Netflix", cost: 26.99)
        service.nextRenewalAt = now.addingTimeInterval(86400)
        state.subscriptions = [service]
        let index = state.searchIndex(for: owner)
        for phrase in ["Netflix next payment", "when is my Netflix next payment", "Netflix autopay"] {
            XCTAssertEqual(index.search(phrase).hits.map(\.record.modelID), [service.id], phrase)
        }
        XCTAssertTrue(index.search("Netflix next payment").answerSummary?.contains(SearchText.day(service.nextRenewalAt)) ?? false)
        XCTAssertTrue(index.search("Netflix next payment", filters: .init(kind: .payment)).hits.isEmpty)
        XCTAssertTrue(index.search("Netflix minimum payment").hits.isEmpty, "Service billing is not a bank minimum due")
    }

    func testChargeSharedAcrossParentServicesDoesNotEstablishSummaryFacts() throws {
        let company = UUID()
        let first = SearchRecord(kind: .subscription, modelID: UUID(), companyID: company, company: "Personal", title: "Tesla", detail: "")
        let second = SearchRecord(kind: .subscription, modelID: UUID(), companyID: company, company: "Personal", title: "Insurance", detail: "")
        var charge = SearchRecord(kind: .transaction, modelID: UUID(), companyID: company, company: "Personal", title: "Combined", detail: "")
        charge.date = now; charge.amount = 100; charge.flow = "expense"
        let index = UniversalSearchIndex(records: [first, second, charge], links: [first.id: [charge.id], second.id: [charge.id]])
        let result = try XCTUnwrap(overviews(index, "Tesla").first)
        XCTAssertEqual(result.transactions.count, 1)
        XCTAssertTrue(result.serviceTransactions[first.id]?.isEmpty ?? false)
        XCTAssertNil(result.chargeSummaries[first.id]?.latest)
    }
}

extension UniversalSearchTests {
    func testInstitutionAssociationHonorsOverridesAndUnavailableExplicitBanks() {
        let (state, a, b) = fixture()
        let bank = Institution(userId: owner, companyId: b.id, name: "Bank")
        let card = FinancialCard(userId: owner, companyId: a.id, name: "Card", institutionName: "Bank")
        state.institutions = [bank]; state.cards = [card]
        state.localCompanyOverrides = [card.id.uuidString: b.id]
        func associated() -> (Set<UUID>, Set<UUID>) {
            let deck = InstitutionRelationships(institutions: state.institutions, cards: state.cards, loans: [],
                connections: state.resourceConnections, companyOverrides: state.localCompanyOverrides)
            let search = state.searchIndex(for: owner).institutionProductAssociations()
            return (deck.banks(for: .card, id: card.id), Set(search.keys))
        }
        XCTAssertEqual(associated().0, [bank.id]); XCTAssertEqual(associated().1, [bank.id])
        state.resourceConnections = [ResourceConnection(ownerUserId: owner, sourceType: .card, sourceId: card.id,
            targetType: .institution, targetId: UUID(), relationshipType: .connectedAccount,
            origin: .manual, confidence: 1, state: .confirmed)]
        XCTAssertTrue(associated().0.isEmpty); XCTAssertTrue(associated().1.isEmpty)
    }
}

extension UniversalSearchTests {
    func testSavedNamesStayLiteralInsideCommandsAndDates() {
        let (state, a, _) = fixture()
        var service = Subscription(userId: owner, companyId: a.id, name: "Total Wine", cost: 10)
        service.nextRenewalAt = SearchText.date("2026-08-10", calendar: calendar)
        state.subscriptions = [service]
        let index = state.searchIndex(for: owner, now: now, calendar: calendar)
        let plain = index.search("Total Wine last month", now: now, calendar: calendar)
        XCTAssertEqual(plain.hits.map(\.record.modelID), [service.id])
        XCTAssertTrue(plain.metrics.isEmpty)
        XCTAssertEqual(index.search("count Total Wine", now: now, calendar: calendar).metrics.first?.value, 1)
        let parent = index.interpretedRequest("Total Wine")
        let followUp = index.interpretedRequest("only North Studio", previous: parent)
        XCTAssertEqual(index.execute(followUp).hits.map(\.record.modelID), [service.id])
        XCTAssertEqual(index.search("accounts").interpretation, "Best matches")
    }

    func testInferredFiltersAreVisibleRemovableAndReplaceable() throws {
        let (state, a, b) = fixture()
        var first = transaction(a.id, date: "2026-08-10"); first.pending = true
        let posted = transaction(a.id, date: "2026-08-10")
        var other = transaction(b.id, date: "2026-08-10"); other.pending = true
        var september = transaction(a.id, date: "2026-09-10"); september.pending = true
        state.transactions = [first, posted, other, september]
        let index = state.searchIndex(for: owner)
        let query = "North Studio pending transactions last month"
        func search(_ filters: SearchFilters = .init()) -> SearchResponse { index.search(query, filters: filters, now: now, calendar: calendar) }
        let initial = search()
        XCTAssertEqual(initial.hits.map(\.record.modelID), [first.id])
        XCTAssertEqual(initial.appliedFilters.map(\.label), ["North Studio", "Last month", "Pending"])
        var filters = SearchFilters()
        filters.remove(try XCTUnwrap(initial.appliedFilters.first { $0.id == "company" }))
        XCTAssertEqual(Set(search(filters).hits.map(\.record.modelID)), [first.id, other.id])
        filters.remove(try XCTUnwrap(initial.appliedFilters.first { $0.id == "date" }))
        XCTAssertEqual(search(filters).hits.count, 3)
        filters.remove(try XCTUnwrap(initial.appliedFilters.first { $0.id == "state" }))
        XCTAssertEqual(search(filters).hits.count, 4)
        XCTAssertTrue(search(filters).appliedFilters.isEmpty)
        filters.companyID = b.id; filters.transactionState = .pending
        XCTAssertEqual(search(filters).hits.map(\.record.modelID), [other.id])
        filters.companyID = a.id; filters.period = .thisMonth
        XCTAssertEqual(search(filters).hits.map(\.record.modelID), [september.id])
        XCTAssertEqual(search(filters).appliedFilters.map(\.label), ["North Studio", "This month", "Pending"])
    }

    func testNamedMonthChipCanBeRemovedWithoutLeavingMonthAsSearchText() {
        let (state, a, _) = fixture()
        state.transactions = [transaction(a.id, date: "2026-08-10"), transaction(a.id, date: "2026-09-10")]
        let index = state.searchIndex(for: owner)
        let result = index.search("transactions August 2026", now: now, calendar: calendar)
        XCTAssertEqual(result.hits.count, 1)
        XCTAssertEqual(result.appliedFilters.first?.label, "August 2026")
        var filters = SearchFilters(); filters.ignoreInferredDate = true
        XCTAssertEqual(index.search("transactions August 2026", filters: filters, now: now, calendar: calendar).hits.count, 2)
        filters.period = .thisMonth
        XCTAssertEqual(index.search("transactions August 2026", filters: filters, now: now, calendar: calendar).hits.map(\.record.date), [SearchText.date("2026-09-10")])
    }

    func testServiceHistoryPhrasesKeepMerchantAndEntityBoundaries() {
        let (state, a, b) = fixture()
        var firstCard = FinancialCard(userId: owner, companyId: a.id, name: "First")
        firstCard.plaidAccountId = "first"
        var otherCard = FinancialCard(userId: owner, companyId: b.id, name: "Other")
        otherCard.plaidAccountId = "other"
        state.cards = [firstCard, otherCard]
        state.subscriptions = [Subscription(userId: owner, companyId: a.id, name: "Netflix", cost: 10, paymentMethodId: firstCard.id),
                               Subscription(userId: owner, companyId: b.id, name: "Netflix", cost: 20, paymentMethodId: otherCard.id)]
        var first = transaction(a.id, card: firstCard); first.name = "Netflix"
        var other = transaction(b.id, card: otherCard); other.name = "Netflix"
        let unrelated = transaction(a.id, card: firstCard)
        state.transactions = [first, other, unrelated]
        let index = state.searchIndex(for: owner)
        for query in ["Netflix history", "Netflix charge history", "past Netflix charges", "Netflix billing history"] {
            XCTAssertEqual(Set(index.search(query).hits.map(\.record.modelID)), [first.id, other.id], query)
            XCTAssertEqual(index.search(query, filters: .init(companyID: a.id)).hits.map(\.record.modelID), [first.id], query)
        }
        XCTAssertEqual(index.search("North Studio Netflix history last month", now: now, calendar: calendar).hits.map(\.record.modelID), [first.id])
        XCTAssertTrue(index.search("Netflix history this month", now: now, calendar: calendar).hits.isEmpty)
        XCTAssertTrue(index.search("history").hits.allSatisfy { $0.record.kind == .activity })
    }

    func testSearchCoverageCacheRefreshesWithoutRecordEdits() async throws {
        let (state, a, _) = fixture()
        var account = InstitutionAccount(); account.balance = 100; account.plaidAccountId = "clock-account"
        let sync = now.addingTimeInterval(-7 * 86400 + 10)
        let bank = Institution(userId: owner, companyId: a.id, name: "Bank", accounts: [account], lastSyncedAt: sync)
        var service = Subscription(userId: owner, companyId: a.id, name: "Netflix", cost: 20, paymentMethodId: bank.id)
        service.nextRenewalAt = now.addingTimeInterval(86400)
        state.institutions = [bank]; state.subscriptions = [service]
        let revision = state.searchRevision
        func status(_ index: UniversalSearchIndex) -> SearchFundingCoverage.Status? { index.records.first { $0.modelID == service.id }?.fundingCoverage?.status }
        XCTAssertEqual(status(state.searchIndex(for: owner, now: now, calendar: calendar)), .covered)
        XCTAssertEqual(status(state.searchIndex(for: owner, now: now.addingTimeInterval(11), calendar: calendar)), .unknown)
        XCTAssertEqual(state.searchRevision, revision, "Time alone invalidates the cache")
        let fresh = try await state.searchIndexInBackground(for: owner, now: now, calendar: calendar)
        XCTAssertEqual(status(fresh), .covered)
        let stale = try await state.searchIndexInBackground(for: owner, now: now.addingTimeInterval(11), calendar: calendar)
        XCTAssertEqual(status(stale), .unknown)
        let oldStamp = state.searchProjectionStamp(now: now, calendar: calendar)
        XCTAssertNotEqual(oldStamp, state.searchProjectionStamp(now: now.addingTimeInterval(86400), calendar: calendar))
        var otherCalendar = calendar; otherCalendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        XCTAssertNotEqual(oldStamp, state.searchProjectionStamp(now: now, calendar: otherCalendar))
        state.plaidItems = [PlaidItemSummary(id: UUID(), companyId: a.id, institutionId: bank.id, status: "active", lastSyncedAt: now.addingTimeInterval(-48 * 3600 + 10))]
        XCTAssertEqual(status(state.searchIndex(for: owner, now: now, calendar: calendar)), .covered)
        XCTAssertEqual(status(state.searchIndex(for: owner, now: now.addingTimeInterval(11), calendar: calendar)), .unknown)
    }
}

extension UniversalSearchTests {
    func testStructuredFiltersCanBeShownAndRemoved() {
        let (state, a, b) = fixture()
        var one = transaction(a.id, date: "2026-08-10"); one.pending = true
        state.transactions = [one, transaction(b.id, date: "2026-09-10")]
        let index = state.searchIndex(for: owner)
        var request = PortfolioQuery(); request.query = "transactions"; request.companyName = a.name
        request.startDate = "2026-08-01"; request.endDate = "2026-08-31"; request.transactionState = .pending
        let response = index.execute(request)
        XCTAssertEqual(response.appliedFilters.map(\.id), ["company", "date", "state"])
        var filters = SearchFilters()
        for chip in response.appliedFilters { filters.remove(chip) }
        XCTAssertEqual(index.execute(request, filters: filters).hits.count, 2)
        XCTAssertTrue(index.execute(request, filters: filters).appliedFilters.isEmpty)
    }

    func testHistoryPhraseDoesNotReplaceExactSavedHistoryNameOrAmbiguousChildCharges() {
        let (state, a, _) = fixture()
        state.subscriptions = [Subscription(userId: owner, companyId: a.id, name: "History", cost: 10)]
        XCTAssertEqual(state.searchIndex(for: owner).search("History").hits.first?.record.kind, .subscription)
        let parent = SearchRecord(kind: .subscription, modelID: UUID(), companyID: a.id, company: a.name, title: "Tesla", detail: "")
        var child = SearchRecord(kind: .subscription, modelID: parent.modelID, companyID: a.id, company: a.name, title: "Insurance", detail: "", suffix: ":child")
        child.parentServiceID = parent.id
        var charge = SearchRecord(kind: .transaction, modelID: UUID(), companyID: a.id, company: a.name, title: "Combined", detail: "")
        charge.amount = 100; charge.flow = "expense"; charge.date = now
        let index = UniversalSearchIndex(records: [parent, child, charge], links: [parent.id: [charge.id, child.id], child.id: [charge.id, parent.id]])
        XCTAssertEqual(index.search("Tesla history").hits.count, 1)
        XCTAssertTrue(index.search("Tesla Insurance history").hits.isEmpty)
    }
}

extension UniversalSearchTests {
    func testCoverageWindowMovesAtMidnightAndBalanceEditsRefreshImmediately() throws {
        let (state, a, _) = fixture()
        var account = InstitutionAccount(); account.balance = 100
        let bank = Institution(userId: owner, companyId: a.id, name: "Bank", accounts: [account])
        var service = Subscription(userId: owner, companyId: a.id, name: "Netflix", cost: 20, billingCycle: "Yearly", paymentMethodId: bank.id)
        service.nextRenewalAt = calendar.date(byAdding: .day, value: 31, to: now)
        state.institutions = [bank]; state.subscriptions = [service]
        func coverage(_ at: Date) -> SearchFundingCoverage.Status? {
            state.searchIndex(for: owner, now: at, calendar: calendar).records.first { $0.modelID == service.id }?.fundingCoverage?.status
        }
        XCTAssertNil(coverage(now), "The charge is beyond the existing inclusive 30-day window")
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        XCTAssertEqual(coverage(tomorrow), .covered)
        state.institutions[0].accounts[0].balance = 10
        XCTAssertEqual(coverage(tomorrow), .atRisk)
    }
}
