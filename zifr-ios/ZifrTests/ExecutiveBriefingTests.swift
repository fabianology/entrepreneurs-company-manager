import XCTest
@testable import Zifr

final class ExecutiveBriefingTests: XCTestCase {
    private let owner = UUID()
    private var now: Date { ISO8601DateFormatter().date(from: "2027-08-30T12:00:00Z")! }

    func testScopeAndCompanyFilterPreserveInventoryAndConnections() {
        let state = AppState()
        let business = Company(userId: owner, name: "Business", structure: "LLC")
        let other = Company(userId: owner, name: "Other", structure: "LLC")
        let personal = Company(userId: owner, name: "Personal", structure: "Household")
        state.companies = [business, other, personal]
        state.hasLoadedPortfolio = true
        state.subscriptions = [business, other, personal].map { Subscription(userId: owner, companyId: $0.id, name: $0.name, cost: 10) }
        state.transactions = [business, other, personal].map { transaction(company: $0.id, amount: 20) }
        state.resourceConnections = [ResourceConnection(ownerUserId: owner,
            sourceType: .subscription, sourceId: state.subscriptions[0].id,
            targetType: .company, targetId: business.id, relationshipType: .dependsOn,
            origin: .manual, confidence: 1, state: .confirmed)]
        let before = state.subscriptions
        let connections = state.resourceConnections
        XCTAssertEqual(ExecutiveBriefingSnapshot(appState: state, scope: .business, now: now).activeSubscriptionCount, 2)
        XCTAssertEqual(ExecutiveBriefingSnapshot(appState: state, scope: .personal, now: now).activeSubscriptionCount, 1)
        let scoped = ExecutiveBriefingSnapshot(appState: state, scope: .business, companyID: business.id, now: now)
        XCTAssertEqual(scoped.companies.map(\.id), [business.id])
        XCTAssertEqual(scoped.financials.first?.insight.current.moneyOut, 20)
        XCTAssertEqual(state.subscriptions, before)
        XCTAssertEqual(state.resourceConnections, connections)
        XCTAssertEqual(state.transactions.count, 3)
    }

    func testCashFlowSeparatesRefundsCurrenciesAndExcludedTransactions() throws {
        let state = AppState()
        let company = Company(userId: owner, name: "Business", structure: "LLC")
        state.companies = [company]
        let income = transaction(company: company.id, amount: -400)
        let expense = transaction(company: company.id, amount: 100)
        let refund = transaction(company: company.id, amount: -25)
        let transfer = transaction(company: company.id, amount: 1000)
        let ignored = transaction(company: company.id, amount: 500)
        var pending = transaction(company: company.id, amount: 200)
        pending.pending = true
        var euro = transaction(company: company.id, amount: 70)
        euro.currency = "EUR"
        var old = transaction(company: company.id, amount: 10)
        old.date = "2027-07-10"
        state.transactions = [income, expense, refund, transfer, ignored, pending, euro, old]
        state.transactionOverrides = [(refund, TransactionFlowOverride.refund), (transfer, .transfer), (ignored, .ignored)].map { record, flow in
            TransactionOverride(userId: owner, transactionId: record.id, flowOverride: flow)
        }
        let snapshot = ExecutiveBriefingSnapshot(appState: state, scope: .business, now: now)
        let usd = try XCTUnwrap(snapshot.financials.first { $0.currency == "USD" })
        XCTAssertEqual(usd.income, 400)
        XCTAssertEqual(usd.refunds, 25)
        XCTAssertEqual(usd.insight.current.moneyOut, 100)
        XCTAssertEqual(usd.insight.current.net, 325)
        XCTAssertEqual(snapshot.financials.first { $0.currency == "EUR" }?.insight.current.net, -70)
    }

    func testRecurringCommitmentCountsOnlyActiveServicesAndAddonsOnce() {
        let state = AppState()
        let company = Company(userId: owner, name: "Business", structure: "LLC")
        state.companies = [company]
        var active = Subscription(userId: owner, companyId: company.id, name: "Software", cost: 120, billingCycle: "Yearly", serviceType: .subscription)
        active.subServices = [
            SubService(name: "Active monthly", cost: 5),
            SubService(name: "Active yearly", cost: 24, billingCycle: .yearly),
            SubService(name: "Cancelled", cost: 100, status: .cancelled),
            SubService(name: "Paused", cost: 100, status: .paused),
            SubService(name: "Pending", cost: 100, status: .pending)
        ]
        var cancelled = active
        cancelled.id = UUID(); cancelled.status = "Cancelled"
        state.subscriptions = [active, cancelled,
            Subscription(userId: owner, companyId: company.id, name: "Utility", cost: 20, serviceType: .bill),
            Subscription(userId: owner, companyId: company.id, name: "Euro service", cost: 8, currency: "EUR"),
            Subscription(userId: owner, companyId: company.id, name: "Unknown cycle", cost: 999, billingCycle: "Custom")]
        let result = ExecutiveBriefingSnapshot(appState: state, scope: .business)
        XCTAssertEqual(result.activeSubscriptionCount, 3)
        XCTAssertEqual(result.activeBillCount, 1)
        XCTAssertEqual(result.supplementalCount, 2)
        XCTAssertEqual(result.recurringCosts["USD"], 37)
        XCTAssertEqual(result.recurringCosts["EUR"], 8)
        XCTAssertEqual(result.unknownBillingCount, 1)
    }

    func testLocalAssignmentMovesBothResourceAndItsTransactionsWithoutSaving() {
        let state = AppState()
        let previous = state.localCompanyOverrides
        defer { state.localCompanyOverrides = previous }
        let business = Company(userId: owner, name: "Business", structure: "LLC")
        let personal = Company(userId: owner, name: "Personal", structure: "Individual")
        let bank = Institution(userId: owner, companyId: business.id, name: "Bank", accounts: [InstitutionAccount(id: "account")])
        state.companies = [business, personal]
        state.institutions = [bank]
        state.localCompanyOverrides[bank.id.uuidString] = personal.id
        var value = transaction(company: business.id, amount: 35)
        value.accountId = "account"; value.institutionId = bank.id
        state.transactions = [value]
        XCTAssertTrue(ExecutiveBriefingSnapshot(appState: state, scope: .business, now: now).records.isEmpty)
        XCTAssertEqual(ExecutiveBriefingSnapshot(appState: state, scope: .personal, now: now).financials.first?.insight.current.moneyOut, 35)
        XCTAssertEqual(state.institutions[0].companyId, business.id)
        XCTAssertEqual(state.transactions[0].companyId, business.id)
    }

    func testUrgentNoticesDeduplicateBrokenBankAndExcludeRoutineAndDeferredItems() {
        let state = AppState()
        let company = Company(userId: owner, name: "Business", structure: "LLC")
        let bank = Institution(userId: owner, companyId: company.id, name: "Bank", isDisconnected: true)
        state.companies = [company]; state.institutions = [bank]
        state.plaidItems = [PlaidItemSummary(id: UUID(), companyId: company.id, institutionId: bank.id, status: "requires_reauth")]
        let reconnect = obligation(bank: bank, kind: "bank_connection", severity: .urgent)
        let deadline = obligation(bank: bank, kind: "critical_deadline", severity: .urgent)
        let routine = obligation(bank: bank, kind: "routine", severity: .info)
        var deferred = obligation(bank: bank, kind: "deferred", severity: .urgent)
        deferred.state = .deferred
        state.obligations = [reconnect, deadline, deadline, routine, deferred]
        let result = ExecutiveUrgentNotice.notices(in: state)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.filter { $0.obligation == nil }.count, 1)
        XCTAssertEqual(result.compactMap(\.obligation).map(\.id), [deadline.id])
        XCTAssertTrue(result.allSatisfy { $0.entityName == "Business · Business" })
        XCTAssertEqual(state.obligations.count, 5)
    }

    func testCoverageDoesNotTreatUnloadedOrFailedDataAsHealthy() {
        let state = AppState()
        XCTAssertEqual(ExecutiveBriefingSnapshot(appState: state, scope: .business).coverage, "Waiting for portfolio data")
        state.hasLoadedPortfolio = true; state.portfolioLoadIssue = "Unavailable"
        XCTAssertEqual(ExecutiveBriefingSnapshot(appState: state, scope: .business).coverage, "Some portfolio data is unavailable")
        XCTAssertTrue(ExecutiveBriefingSnapshot(appState: state, scope: .business).financials.isEmpty)
    }

    func testBusinessSummaryIsHiddenWhenThereAreNoBusinessProfiles() {
        let personal = Company(userId: owner, name: "Personal", structure: "Individual")
        XCTAssertEqual(ExecutiveBriefingLayout.visibleScopes(companies: [personal]), [.personal])

        let business = Company(userId: owner, name: "Studio", structure: "LLC")
        XCTAssertEqual(ExecutiveBriefingLayout.visibleScopes(companies: [personal, business]), [.business, .personal])
    }

    func testUrgentNoticesAreAssignedToTheirExecutiveSummary() {
        let state = AppState()
        let business = Company(userId: owner, name: "Studio", structure: "LLC")
        let personal = Company(userId: owner, name: "Personal", structure: "Individual")
        let businessBank = Institution(userId: owner, companyId: business.id, name: "Studio Bank", isDisconnected: true)
        let personalBank = Institution(userId: owner, companyId: personal.id, name: "Personal Bank", isDisconnected: true)
        state.companies = [business, personal]
        state.institutions = [businessBank, personalBank]

        let notices = ExecutiveUrgentNotice.notices(in: state)
        XCTAssertEqual(notices.filter { $0.belongs(to: .business, in: state) }.map(\.title), ["Reconnect Studio Bank"])
        XCTAssertEqual(notices.filter { $0.belongs(to: .personal, in: state) }.map(\.title), ["Reconnect Personal Bank"])
    }

    func testUnassignedUrgentNoticeRemainsVisibleWithoutBusinessProfile() {
        let state = AppState()
        state.companies = [Company(userId: owner, name: "Personal", structure: "Individual")]
        let notice = ExecutiveUrgentNotice(
            id: "unassigned", title: "Review connection", detail: "Action needed",
            entityName: "Unassigned", companyID: nil, sourceType: .collaborator,
            sourceID: UUID(), obligation: nil, dueAt: nil
        )

        XCTAssertTrue(notice.belongs(to: .personal, in: state))
        XCTAssertFalse(notice.belongs(to: .business, in: state))
    }

    func testHealthFilterAndRemindersFollowEffectiveAssignment() {
        let state = AppState()
        let previous = state.localCompanyOverrides
        defer { state.localCompanyOverrides = previous }
        let business = Company(userId: owner, name: "Business", structure: "LLC")
        let personal = Company(userId: owner, name: "Personal", structure: "Individual")
        let bank = Institution(userId: owner, companyId: business.id, name: "Moved bank", isDisconnected: true)
        state.companies = [business, personal]; state.institutions = [bank]
        state.localCompanyOverrides[bank.id.uuidString] = personal.id
        let notice = obligation(bank: bank, kind: "bank_connection", severity: .urgent)
        state.obligations = [notice]
        XCTAssertEqual(ExecutiveBriefingSnapshot.companyID(for: notice, in: state), personal.id)
        let businessHealth = OwnerHealthEngine.snapshot(appState: state, scope: .business, companyID: business.id)
        let personalHealth = OwnerHealthEngine.snapshot(appState: state, scope: .personal, companyID: personal.id)
        XCTAssertEqual(businessHealth.categories.first { $0.category == .institution }?.status, .notApplicable)
        XCTAssertEqual(personalHealth.categories.first { $0.category == .institution }?.status, .critical)
        XCTAssertEqual(ExecutiveUrgentNotice.notices(in: state).first?.entityName, "Personal · Personal")
    }

    func testUnassignedTransactionsAndMissingSyncRemainExplicit() {
        let state = AppState()
        let company = Company(userId: owner, name: "Business", structure: "LLC")
        state.companies = [company]; state.hasLoadedPortfolio = true
        var unassigned = transaction(company: company.id, amount: 100)
        unassigned.companyId = nil
        state.transactions = [unassigned]
        let snapshot = ExecutiveBriefingSnapshot(appState: state, scope: .business, now: now)
        XCTAssertEqual(snapshot.unassignedTransactionCount, 1)
        XCTAssertTrue(snapshot.financials.isEmpty)
        XCTAssertEqual(snapshot.coverage, "No transaction history available")
    }

    func testUnknownBillingDoesNotCreateAFalseZeroAndFreeAddonsAreIncluded() {
        let state = AppState()
        let company = Company(userId: owner, name: "Business", structure: "LLC")
        state.companies = [company]
        state.subscriptions = [Subscription(userId: owner, companyId: company.id, cost: 50, billingCycle: "Custom")]
        let unknown = ExecutiveBriefingSnapshot(appState: state, scope: .business)
        XCTAssertTrue(unknown.recurringCosts.isEmpty)
        XCTAssertEqual(unknown.unknownBillingCount, 1)
        XCTAssertEqual(unknown.activeSubscriptionCount, 1)
        state.subscriptions = [Subscription(userId: owner, companyId: company.id, cost: 500,
            subServices: [SubService(name: "Paid add-on", cost: 5)], pricingModel: "free")]
        XCTAssertEqual(ExecutiveBriefingSnapshot(appState: state, scope: .business).recurringCosts["USD"], 5)
    }

    func testUpcomingCoverageGroupsChargesBySavedBankAccountAndUsesAvailableBalance() throws {
        let institutionID = UUID()
        let account = InstitutionAccount(
            id: "checking", name: "Operating", type: "Checking", last4: "4242",
            balance: 140, availableBalance: 100, currency: "USD"
        )
        let institution = Institution(
            id: institutionID, userId: owner, companyId: UUID(), name: "Community Bank",
            accounts: [account]
        )
        let first = Subscription(
            userId: owner, companyId: institution.companyId, name: "Internet", cost: 60,
            paymentMethod: "Operating", paymentMethodId: institutionID,
            nextRenewalAt: now.addingTimeInterval(5 * 86_400), serviceType: .bill
        )
        let second = Subscription(
            userId: owner, companyId: institution.companyId, name: "Software", cost: 50,
            paymentMethod: "Operating", paymentMethodId: institutionID,
            nextRenewalAt: now.addingTimeInterval(12 * 86_400), serviceType: .subscription
        )

        let result = UpcomingCoverageEngine.project(
            subscriptions: [first, second], institutions: [institution], cards: [], plaidItems: [], now: now
        )
        let group = try XCTUnwrap(result.groups.first)
        XCTAssertEqual(result.groups.count, 1)
        XCTAssertEqual(group.charges.map(\.name), ["Internet", "Software"])
        XCTAssertEqual(group.totalDue, 110, accuracy: 0.001)
        XCTAssertEqual(group.availableAmount, 100)
        XCTAssertEqual(group.status, .atRisk)
        XCTAssertEqual(group.difference, -10)
        XCTAssertEqual(group.sourceName, "Operating ••••4242")
    }

    func testUpcomingCoverageMarksDisconnectedStaleAndUnlinkedSourcesUnknown() {
        let companyID = UUID()
        let institution = Institution(
            userId: owner, companyId: companyID, name: "Bank",
            accounts: [InstitutionAccount(id: "linked", plaidAccountId: "plaid-1", name: "Checking", balance: 500)],
            lastSyncedAt: now.addingTimeInterval(-10 * 86_400)
        )
        let stale = Subscription(
            userId: owner, companyId: companyID, name: "Rent", cost: 100,
            paymentMethod: "Checking", paymentMethodId: institution.id,
            nextRenewalAt: now.addingTimeInterval(2 * 86_400), serviceType: .bill,
            plaidAccountId: "plaid-1"
        )
        let unlinked = Subscription(
            userId: owner, companyId: companyID, name: "Membership", cost: 20,
            paymentMethod: "Old card", nextRenewalAt: now.addingTimeInterval(3 * 86_400)
        )

        let result = UpcomingCoverageEngine.project(
            subscriptions: [stale, unlinked], institutions: [institution], cards: [], plaidItems: [], now: now
        )
        XCTAssertEqual(result.unknownCount, 2)
        XCTAssertTrue(result.groups.allSatisfy { $0.status == .unknown })
        XCTAssertTrue(result.groups.contains { $0.reason == "Connected balance is out of date" })
        XCTAssertTrue(result.groups.contains { $0.reason == "Link its payment account to verify funds" })

        var disconnected = institution
        disconnected.isDisconnected = true
        disconnected.lastSyncedAt = now
        let brokenResult = UpcomingCoverageEngine.project(
            subscriptions: [stale], institutions: [disconnected], cards: [], plaidItems: [], now: now
        )
        XCTAssertEqual(brokenResult.groups.first?.reason, "Bank connection needs attention")
    }

    func testUpcomingCoverageUsesAvailableCreditAndAddonInheritsParentSource() throws {
        let companyID = UUID()
        let card = FinancialCard(
            userId: owner, companyId: companyID, name: "Rewards", last4: "9999",
            type: "Credit", limit: 1_000, balance: 200
        )
        let addon = SubService(
            name: "Extra seat", cost: 25, renewsOn: now.addingTimeInterval(4 * 86_400)
        )
        let service = Subscription(
            userId: owner, companyId: companyID, name: "Workspace", cost: 0,
            paymentMethod: "Rewards", paymentMethodId: card.id,
            subServices: [addon], pricingModel: "free"
        )

        let result = UpcomingCoverageEngine.project(
            subscriptions: [service], institutions: [], cards: [card], plaidItems: [], now: now
        )
        let group = try XCTUnwrap(result.groups.first)
        XCTAssertEqual(group.status, .covered)
        XCTAssertEqual(group.availableAmount, 800)
        XCTAssertEqual(group.totalDue, 25)
        XCTAssertEqual(group.charges.map(\.name), ["Extra seat"])
        XCTAssertEqual(result.unscheduledCount, 1)
    }

    func testUpcomingCoverageUsesLinkedBankAccountForCardAndCountsItsBalanceOnce() throws {
        let companyID = UUID()
        let card = FinancialCard(
            userId: owner, companyId: companyID, name: "Visa", last4: "9225",
            type: "Credit", limit: 10_000, balance: 100
        )
        let account = InstitutionAccount(
            id: "sofi-checking", name: "SoFi Checking", type: "Checking", last4: "5181",
            balance: 225, availableBalance: 200, currency: "USD",
            linkedCardId: card.id.uuidString
        )
        let institution = Institution(
            userId: owner, companyId: companyID, name: "SoFi", accounts: [account]
        )
        let cardPayment = Subscription(
            userId: owner, companyId: companyID, name: "Phone", cost: 150,
            paymentMethod: "Visa", paymentMethodId: card.id,
            nextRenewalAt: now.addingTimeInterval(2 * 86_400), serviceType: .bill
        )
        let directPayment = Subscription(
            userId: owner, companyId: companyID, name: "Internet", cost: 100,
            paymentMethod: "SoFi Checking", paymentMethodId: institution.id,
            nextRenewalAt: now.addingTimeInterval(3 * 86_400), serviceType: .bill
        )

        let result = UpcomingCoverageEngine.project(
            subscriptions: [cardPayment, directPayment], institutions: [institution],
            cards: [card], plaidItems: [], now: now
        )
        let group = try XCTUnwrap(result.groups.first)
        XCTAssertEqual(result.groups.count, 1)
        XCTAssertEqual(group.sourceName, "SoFi Checking ••••5181")
        XCTAssertEqual(group.paymentRoutes, ["Visa ••••9225"])
        XCTAssertEqual(group.availableAmount, 200)
        XCTAssertEqual(group.totalDue, 250)
        XCTAssertEqual(group.status, .atRisk)
        XCTAssertEqual(group.difference, -50)
    }

    private func transaction(company: UUID, amount: Double) -> Zifr.Transaction {
        var value = Zifr.Transaction()
        value.userId = owner; value.companyId = company; value.amount = amount
        value.date = "2027-08-20"; value.name = "Fixture"
        return value
    }

    private func obligation(bank: Institution, kind: String, severity: ObligationSeverity) -> PortfolioObligation {
        PortfolioObligation(id: UUID(), ownerUserId: owner, companyId: bank.companyId,
            sourceType: .institution, sourceId: bank.id, kind: kind, severity: severity,
            title: "Notice", summary: "Action needed", actionType: "open_source", state: .open,
            fingerprint: UUID().uuidString, createdAt: now, updatedAt: now)
    }
}
