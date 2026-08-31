import XCTest
@testable import Zifr

final class PremiumEngineTests: XCTestCase {
    func testPlaidConnectionHealthDetectsReconnectAndStaleItems() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let reconnect = PlaidItemSummary(
            id: UUID(),
            companyId: UUID(),
            institutionId: UUID(),
            institutionName: "Example Bank",
            status: "requires_reauth",
            errorCode: "ITEM_LOGIN_REQUIRED",
            lastSyncedAt: now,
            createdAt: now
        )
        XCTAssertTrue(reconnect.requiresReconnect)
        XCTAssertFalse(reconnect.isStale(referenceDate: now))

        let stale = PlaidItemSummary(
            id: UUID(),
            companyId: UUID(),
            institutionId: UUID(),
            institutionName: "Example Bank",
            status: "active",
            errorCode: nil,
            lastSyncedAt: now.addingTimeInterval(-49 * 60 * 60),
            createdAt: now.addingTimeInterval(-60 * 60 * 60)
        )
        XCTAssertFalse(stale.requiresReconnect)
        XCTAssertTrue(stale.isStale(referenceDate: now))
    }

    func testTransactionDecodesWithoutOptionalMerchantWebsiteColumn() throws {
        let owner = UUID()
        let transactionId = UUID()
        let json = """
        {
          "id": "\(transactionId.uuidString)",
          "user_id": "\(owner.uuidString)",
          "account_id": "checking",
          "amount": 42.50,
          "currency": "USD",
          "date": "2026-08-30",
          "name": "Example Merchant",
          "merchant_name": "Example Merchant",
          "category": ["Shops"],
          "pending": false
        }
        """

        let transaction = try JSONDecoder().decode(Transaction.self, from: Data(json.utf8))

        XCTAssertEqual(transaction.id, transactionId)
        XCTAssertEqual(transaction.userId, owner)
        XCTAssertNil(transaction.merchantWebsite)
        XCTAssertEqual(transaction.merchantName, "Example Merchant")
    }

    func testTransactionUsesCanonicalAccountAfterPlaidReconnect() throws {
        let json = """
        {
          "account_id": "archived-source-account",
          "canonical_account_id": "current-visible-account",
          "amount": 19.99,
          "currency": "USD",
          "date": "2026-08-30",
          "name": "Example Merchant",
          "pending": false
        }
        """

        let transaction = try JSONDecoder().decode(Transaction.self, from: Data(json.utf8))

        XCTAssertEqual(transaction.sourceAccountId, "archived-source-account")
        XCTAssertEqual(transaction.canonicalAccountId, "current-visible-account")
        XCTAssertEqual(transaction.accountId, "current-visible-account")
    }

    func testEntitlementStatesRespectTrialGraceAndRevocation() {
        XCTAssertTrue(AccessSnapshot(tier: .pro, status: .trial, limits: .pro).hasProAccess)
        XCTAssertTrue(AccessSnapshot(tier: .pro, status: .active, limits: .pro).hasProAccess)
        XCTAssertTrue(AccessSnapshot(
            tier: .pro, status: .grace, graceEndsAt: Date().addingTimeInterval(60), limits: .pro
        ).hasProAccess)
        XCTAssertFalse(AccessSnapshot(
            tier: .pro, status: .grace, graceEndsAt: Date().addingTimeInterval(-60), limits: .pro
        ).hasProAccess)
        XCTAssertFalse(AccessSnapshot(tier: .pro, status: .revoked, limits: .pro).hasProAccess)
    }

    func testDeterministicPaymentBacklinkIsConfirmed() {
        let owner = UUID(), company = UUID(), cardId = UUID()
        let state = AppState()
        state.companies = [Company(id: company, userId: owner, name: "Studio", structure: "LLC")]
        state.cards = [FinancialCard(id: cardId, userId: owner, companyId: company, name: "Business Card")]
        state.subscriptions = [Subscription(
            userId: owner, companyId: company, name: "Figma", paymentMethodId: cardId
        )]

        let result = PortfolioConnectionEngine.buildConnections(appState: state, ownerUserId: owner)
        let edge = result.first { $0.relationshipType == .paidBy }
        XCTAssertEqual(edge?.state, .confirmed)
        XCTAssertEqual(edge?.targetId, cardId)
    }

    func testRejectedEmailSuggestionStaysSuppressed() {
        let owner = UUID(), company = UUID()
        let state = AppState()
        state.subscriptions = [Subscription(
            userId: owner, companyId: company, name: "Figma", loginId: "ADMIN@EXAMPLE.COM"
        )]
        state.institutions = [Institution(
            userId: owner, companyId: company, name: "Bank", email: "admin@example.com"
        )]
        let suggestion = PortfolioConnectionEngine.buildConnections(appState: state, ownerUserId: owner)
            .first { $0.relationshipType == .usesLogin }
        XCTAssertNotNil(suggestion)

        var rejected = suggestion!
        rejected.state = .rejected
        state.resourceConnections = [rejected]
        let regenerated = PortfolioConnectionEngine.buildConnections(appState: state, ownerUserId: owner)
        XCTAssertFalse(regenerated.contains { $0.relationshipType == .usesLogin })
    }

    func testConnectionGraphBuildsMaskedSharedEmailHub() {
        let owner = UUID(), companyA = UUID(), companyB = UUID()
        let subscriptionA = Subscription(userId: owner, companyId: companyA, name: "Figma", loginId: "admin@example.com")
        let subscriptionB = Subscription(userId: owner, companyId: companyB, name: "AWS", loginId: "ADMIN@example.com")
        let state = AppState()
        state.companies = [
            Company(id: companyA, userId: owner, name: "Studio", structure: "LLC"),
            Company(id: companyB, userId: owner, name: "Holdings", structure: "LLC")
        ]
        state.subscriptions = [subscriptionA, subscriptionB]
        state.resourceConnections = [ResourceConnection(
            ownerUserId: owner,
            sourceType: .subscription,
            sourceId: subscriptionA.id,
            targetType: .subscription,
            targetId: subscriptionB.id,
            relationshipType: .usesLogin,
            origin: .inferred,
            confidence: 0.92,
            state: .suggested,
            inferenceKey: "email:admin@example.com:subscription:\(subscriptionA.id):subscription:\(subscriptionB.id)"
        )]

        let graph = ConnectionGraphBuilder.build(appState: state)
        let emailNode = graph.nodes.first { $0.kind == .sharedEmail }
        XCTAssertEqual(emailNode?.displayName, "admin@example.com")
        XCTAssertEqual(emailNode?.canvasLabel, "a•••@example.com")
        XCTAssertEqual(emailNode.map { graph.edges(for: $0.id).count }, 2)
        XCTAssertTrue(emailNode.map { graph.edges(for: $0.id).allSatisfy { $0.state == .suggested } } ?? false)
    }

    func testConnectionGraphExcludesRejectedEmailHub() {
        let owner = UUID(), company = UUID()
        let subscription = Subscription(userId: owner, companyId: company, name: "Figma")
        let institution = Institution(userId: owner, companyId: company, name: "Bank")
        let state = AppState()
        state.companies = [Company(id: company, userId: owner, name: "Studio", structure: "LLC")]
        state.subscriptions = [subscription]
        state.institutions = [institution]
        state.resourceConnections = [ResourceConnection(
            ownerUserId: owner,
            sourceType: .subscription,
            sourceId: subscription.id,
            targetType: .institution,
            targetId: institution.id,
            relationshipType: .usesLogin,
            origin: .inferred,
            confidence: 0.92,
            state: .rejected,
            inferenceKey: "email:admin@example.com:subscription:\(subscription.id):institution:\(institution.id)"
        )]

        let graph = ConnectionGraphBuilder.build(appState: state)
        XCTAssertFalse(graph.nodes.contains { $0.kind == .sharedEmail })
        XCTAssertFalse(graph.edges.contains { $0.relationship == .usesLogin })
    }

    func testConnectionGraphDegreeSizingIsMonotonicAndCapped() {
        let isolated = ConnectionGraphBuilder.radius(kind: .resource(.company), degree: 0)
        let connected = ConnectionGraphBuilder.radius(kind: .resource(.company), degree: 4)
        let hub = ConnectionGraphBuilder.radius(kind: .resource(.company), degree: 10_000)
        XCTAssertLessThan(isolated, connected)
        XCTAssertLessThanOrEqual(connected, hub)
        XCTAssertEqual(hub, 52)
    }

    func testConnectionGraphLayoutIsDeterministicAndFinite() {
        let graph = ConnectionGraph(
            nodes: [
                ConnectionGraphNode(id: "a", kind: .resource(.company), reference: nil, displayName: "A", canvasLabel: "A"),
                ConnectionGraphNode(id: "b", kind: .resource(.subscription), reference: nil, displayName: "B", canvasLabel: "B")
            ],
            edges: [ConnectionGraphEdge(
                id: "a-b", sourceID: "a", targetID: "b", relationship: .belongsTo,
                state: .confirmed, connectionIDs: []
            )]
        )
        let first = ConnectionGraphLayoutEngine.positions(for: graph, iterations: 20)
        let second = ConnectionGraphLayoutEngine.positions(for: graph, iterations: 20)
        XCTAssertEqual(first, second)
        XCTAssertTrue(first.values.allSatisfy { $0.x.isFinite && $0.y.isFinite })
    }

    func testExpiringCardProducesOneConsolidatedImpactObligation() {
        let owner = UUID(), companyA = UUID(), companyB = UUID(), cardId = UUID()
        let state = AppState()
        state.cards = [FinancialCard(
            id: cardId, userId: owner, companyId: companyA, name: "Chase Business",
            expiresAt: Date().addingTimeInterval(28 * 86_400)
        )]
        state.subscriptions = [
            Subscription(userId: owner, companyId: companyA, name: "Figma", paymentMethodId: cardId),
            Subscription(userId: owner, companyId: companyB, name: "AWS", paymentMethodId: cardId),
        ]

        let result = PortfolioObligationEngine.buildObligations(appState: state, ownerUserId: owner)
            .filter { $0.kind == "card_expiration" }
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].summary.contains("2 subscriptions across 2 companies"))
    }

    func testPushCopyCannotContainPortfolioSecrets() {
        let body = PrivateBriefingNotification.body(itemCount: 3)
        XCTAssertEqual(body, "Miloom: 3 items need your attention this week.")
        XCTAssertFalse(body.contains("Chase"))
        XCTAssertFalse(body.contains("$"))
        XCTAssertFalse(body.contains("document"))
    }

    func testDeferredAgeBucketsUseExactElapsedDays() {
        let day: TimeInterval = 86_400
        let now = Date(timeIntervalSince1970: 100 * day)
        let expectations: [(Int, DeferredAgeBucket)] = [
            (0, .zeroToSeven),
            (7, .zeroToSeven),
            (8, .eightToFourteen),
            (14, .eightToFourteen),
            (15, .fifteenToThirty),
            (30, .fifteenToThirty),
            (31, .thirtyOnePlus),
        ]

        for (days, expected) in expectations {
            XCTAssertEqual(
                DeferredAgeBucket.bucket(deferredAt: now.addingTimeInterval(-Double(days) * day), now: now),
                expected,
                "Expected day \(days) to be in \(expected.title)"
            )
        }
        XCTAssertEqual(
            DeferredAgeBucket.bucket(deferredAt: now.addingTimeInterval(day), now: now),
            .zeroToSeven
        )
    }

    func testCompleteLaterUsesLegacyTimestampFallback() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let expectedDeferredAt = now.addingTimeInterval(-14 * 86_400)
        let legacy = makeObligation(
            state: .deferred,
            deferredAt: nil,
            snoozedUntil: expectedDeferredAt.addingTimeInterval(7 * 86_400),
            updatedAt: now
        )
        XCTAssertEqual(
            OwnerBriefingPresentation.effectiveDeferredAt(for: legacy),
            expectedDeferredAt
        )

        let missingLegacyDate = makeObligation(state: .deferred, updatedAt: expectedDeferredAt)
        XCTAssertEqual(
            OwnerBriefingPresentation.effectiveDeferredAt(for: missingLegacyDate),
            expectedDeferredAt
        )
    }

    func testBriefingCollectionsSeparateActiveAndDeferredStates() {
        let open = makeObligation(state: .open, severity: .attention)
        let deferred = makeObligation(state: .deferred)
        let handled = makeObligation(state: .handled)
        let dismissed = makeObligation(state: .dismissed)
        let values = [open, deferred, handled, dismissed]

        XCTAssertEqual(OwnerBriefingPresentation.activeObligations(in: values).map(\.id), [open.id])
        XCTAssertEqual(OwnerBriefingPresentation.deferredObligations(in: values).map(\.id), [deferred.id])

        let state = AppState()
        state.obligations = values
        XCTAssertEqual(state.openObligations.map(\.id), [open.id])
        XCTAssertEqual(state.deferredObligations.map(\.id), [deferred.id])
        XCTAssertEqual(state.unreadBriefingCount, 1)
    }

    func testDeferringAndUndoRestoreLifecycle() {
        let original = makeObligation(state: .open)
        let firstDeferral = Date(timeIntervalSince1970: 3_000_000)
        let deferred = OwnerBriefingPresentation.deferring(original, at: firstDeferral)
        XCTAssertEqual(deferred.state, .deferred)
        XCTAssertEqual(deferred.deferredAt, firstDeferral)
        XCTAssertEqual(deferred.snoozedUntil, firstDeferral.addingTimeInterval(7 * 86_400))

        let resetDate = firstDeferral.addingTimeInterval(10 * 86_400)
        let reset = OwnerBriefingPresentation.deferring(deferred, at: resetDate)
        XCTAssertEqual(reset.deferredAt, resetDate)

        let dismissed = OwnerBriefingPresentation.settingState(reset, to: .dismissed, at: resetDate)
        let restored = OwnerBriefingPresentation.restoringLifecycle(
            of: dismissed,
            from: reset,
            at: resetDate.addingTimeInterval(1)
        )
        XCTAssertEqual(restored.state, .deferred)
        XCTAssertEqual(restored.deferredAt, reset.deferredAt)
        XCTAssertEqual(restored.snoozedUntil, reset.snoozedUntil)
    }

    func testBriefingCategoryAndWireStateCompatibility() {
        XCTAssertEqual(ObligationState.deferred.rawValue, "snoozed")
        XCTAssertEqual(BriefingResourceCategory.category(for: .subscription), .subscription)
        XCTAssertEqual(BriefingResourceCategory.category(for: .institution), .institution)
        XCTAssertEqual(BriefingResourceCategory.category(for: .card), .card)
        XCTAssertEqual(BriefingResourceCategory.category(for: .loan), .loan)
        XCTAssertEqual(BriefingResourceCategory.category(for: .document), .document)

        var potentialSubscription = makeObligation(
            state: .open,
            sourceType: .institution,
            kind: "new_recurring_charge"
        )
        XCTAssertEqual(BriefingResourceCategory.category(for: potentialSubscription), .subscription)

        potentialSubscription.sourceType = .card
        XCTAssertEqual(BriefingResourceCategory.category(for: potentialSubscription), .subscription)
    }

    func testBriefingDateLabelUsesRequestedFormat() {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let date = calendar.date(from: DateComponents(year: 2027, month: 5, day: 5, hour: 12))!
        XCTAssertEqual(OwnerBriefingPresentation.dateLabel(for: date, timeZone: timeZone), "May 5 2027")
    }

    func testRecurringPaymentDetectionOnlyReturnsUntrackedSubscriptions() {
        let owner = UUID(), company = UUID()
        let transactions = [
            makeTransaction(owner: owner, company: company, name: "Netflix", amount: 19.99, date: "2027-03-05"),
            makeTransaction(owner: owner, company: company, name: "Netflix", amount: 19.99, date: "2027-04-05"),
            makeTransaction(owner: owner, company: company, name: "Figma", amount: 15, date: "2027-03-10"),
            makeTransaction(owner: owner, company: company, name: "Figma", amount: 15, date: "2027-04-10"),
        ]
        let tracked = Subscription(userId: owner, companyId: company, name: "Figma")

        let detected = SubscriptionDetector.detect(
            transactions: transactions,
            existingSubscriptions: [tracked]
        )

        XCTAssertEqual(detected.map(\.name), ["Netflix"])
        XCTAssertEqual(detected.first?.frequency, "Monthly")
        XCTAssertEqual(detected.first?.occurrences, 2)
    }

    func testTransactionIntelligenceResolvesCompanyAndAccountFromPlaidContext() {
        let owner = UUID()
        let company = Company(userId: owner, name: "Acme", structure: "LLC")
        let institution = Institution(
            userId: owner,
            companyId: company.id,
            name: "SoFi",
            accounts: [
                InstitutionAccount(
                    id: "plaid-checking",
                    name: "Operating Checking",
                    type: "Checking",
                    last4: "5525"
                )
            ]
        )
        var transaction = Transaction()
        transaction.userId = owner
        transaction.accountId = "plaid-checking"
        transaction.name = "Office Depot"

        let resolved = TransactionIntelligence.resolve(
            transaction,
            companies: [company],
            institutions: [institution],
            cards: []
        )

        XCTAssertEqual(resolved.companyId, company.id)
        XCTAssertEqual(resolved.companyName, "Acme")
        XCTAssertEqual(resolved.accountName, "Operating Checking")
        XCTAssertEqual(resolved.institutionName, "SoFi")
    }

    func testTransactionIntelligenceUsesCardContextWhenInstitutionAccountIsAbsent() {
        let owner = UUID()
        let company = Company(userId: owner, name: "Studio", structure: "LLC")
        let card = FinancialCard(
            userId: owner,
            companyId: company.id,
            name: "Citi Business",
            institutionName: "Citi",
            last4: "1001",
            plaidAccountId: "plaid-card"
        )
        var transaction = Transaction()
        transaction.userId = owner
        transaction.accountId = "plaid-card"
        transaction.name = "Figma"

        let resolved = TransactionIntelligence.resolve(
            transaction,
            companies: [company],
            institutions: [],
            cards: [card]
        )

        XCTAssertEqual(resolved.companyId, company.id)
        XCTAssertEqual(resolved.accountName, "Citi Business")
        XCTAssertEqual(resolved.institutionName, "Citi")
    }

    func testTransactionPortfolioSummarySeparatesMoneyInOutAndPending() {
        let owner = UUID(), companyId = UUID()
        var expense = makeTransaction(owner: owner, company: companyId, name: "Software", amount: 120, date: "2027-08-01")
        var income = makeTransaction(owner: owner, company: companyId, name: "Client payment", amount: -500, date: "2027-08-02")
        var pending = makeTransaction(owner: owner, company: companyId, name: "Pending meal", amount: 40, date: "2027-08-03")
        pending.pending = true
        expense.accountId = "checking"
        income.accountId = "checking"

        let records = [expense, income, pending].map {
            TransactionIntelligence.resolve($0, companies: [], institutions: [], cards: [])
        }
        let summary = TransactionIntelligence.summary(for: records)

        XCTAssertEqual(summary.moneyOut, 120)
        XCTAssertEqual(summary.moneyIn, 500)
        XCTAssertEqual(summary.pendingCount, 1)
        XCTAssertEqual(summary.financialMovementCount, 0)
    }

    func testTransactionPortfolioSummaryExcludesTransfersAndPayments() {
        let owner = UUID(), companyId = UUID()
        var purchase = makeTransaction(owner: owner, company: companyId, name: "Software", amount: 120, date: "2027-08-01")
        var transfer = makeTransaction(owner: owner, company: companyId, name: "Internal transfer", amount: 800, date: "2027-08-02")
        var cardPayment = makeTransaction(owner: owner, company: companyId, name: "Card autopay", amount: -500, date: "2027-08-03")
        purchase.category = ["Service", "Software"]
        transfer.category = ["Transfer", "Internal Account Transfer"]
        cardPayment.personalFinancePrimary = "TRANSFER_OUT"

        let records = [purchase, transfer, cardPayment].map {
            TransactionIntelligence.resolve($0, companies: [], institutions: [], cards: [])
        }
        let summary = TransactionIntelligence.summary(for: records)

        XCTAssertEqual(summary.moneyOut, 120)
        XCTAssertEqual(summary.moneyIn, 0)
        XCTAssertEqual(summary.financialMovementCount, 2)
    }

    func testTransactionSearchUsesCleanMerchantAndResolvedContext() {
        let owner = UUID(), companyId = UUID()
        var transaction = makeTransaction(
            owner: owner,
            company: companyId,
            name: "SQ *NOTION LABS 1234",
            amount: 20,
            date: "2027-08-01"
        )
        transaction.merchantName = "Notion"
        let record = ResolvedTransaction(
            transaction: transaction,
            companyId: companyId,
            companyName: "Design Studio",
            accountName: "Operating Checking",
            institutionName: "Mercury"
        )

        XCTAssertEqual(TransactionIntelligence.displayName(for: transaction), "Notion")
        XCTAssertTrue(TransactionIntelligence.matchesSearch(record, query: "notion"))
        XCTAssertTrue(TransactionIntelligence.matchesSearch(record, query: "mercury"))
        XCTAssertTrue(TransactionIntelligence.matchesSearch(record, query: "design"))
        XCTAssertFalse(TransactionIntelligence.matchesSearch(record, query: "airline"))
    }

    func testDuplicateChargeDetectorFindsNearlyIdenticalPostedChargesWithinThreeDays() {
        let owner = UUID(), company = UUID()
        var first = makeTransaction(owner: owner, company: company, name: "Figma", amount: 15.00, date: "2027-08-10")
        var second = makeTransaction(owner: owner, company: company, name: "FIGMA INC", amount: 15.01, date: "2027-08-12")
        first.merchantName = "Figma"
        second.merchantName = "Figma"
        first.plaidTransactionId = "plaid-first"
        second.plaidTransactionId = "plaid-second"
        let records = [first, second].map {
            TransactionIntelligence.resolve($0, companies: [], institutions: [], cards: [])
        }

        let alerts = DuplicateChargeDetector.detect(records: records)

        XCTAssertEqual(alerts.count, 1)
        XCTAssertEqual(alerts.first?.displayName, "Figma")
        XCTAssertEqual(alerts.first?.records.count, 2)
        XCTAssertEqual(alerts.first?.possibleDuplicateAmount, 15.00)
    }

    func testDuplicateChargeDetectorExcludesPendingTransfersAndDistantCharges() {
        let owner = UUID(), company = UUID()
        var pendingA = makeTransaction(owner: owner, company: company, name: "Pending Vendor", amount: 25, date: "2027-08-10")
        var pendingB = makeTransaction(owner: owner, company: company, name: "Pending Vendor", amount: 25, date: "2027-08-11")
        pendingA.pending = true
        pendingB.pending = true

        var transferA = makeTransaction(owner: owner, company: company, name: "Bank transfer", amount: 100, date: "2027-08-10")
        var transferB = makeTransaction(owner: owner, company: company, name: "Bank transfer", amount: 100, date: "2027-08-11")
        transferA.category = ["Transfer"]
        transferB.category = ["Transfer"]

        let distant = [
            makeTransaction(owner: owner, company: company, name: "Adobe", amount: 59.99, date: "2027-08-01"),
            makeTransaction(owner: owner, company: company, name: "Adobe", amount: 59.99, date: "2027-08-20")
        ]
        let records = ([pendingA, pendingB, transferA, transferB] + distant).map {
            TransactionIntelligence.resolve($0, companies: [], institutions: [], cards: [])
        }

        XCTAssertTrue(DuplicateChargeDetector.detect(records: records).isEmpty)
    }

    func testDuplicateChargeDetectorKeepsCompaniesSeparateAndPersistsDismissal() {
        let owner = UUID(), companyA = UUID(), companyB = UUID()
        let transactions = [companyA, companyB].flatMap { company in
            ["2027-08-10", "2027-08-11"].map {
                makeTransaction(owner: owner, company: company, name: "Notion", amount: 20, date: $0)
            }
        }
        let records = transactions.map {
            TransactionIntelligence.resolve($0, companies: [], institutions: [], cards: [])
        }
        let alerts = DuplicateChargeDetector.detect(records: records)
        XCTAssertEqual(alerts.count, 2)
        XCTAssertEqual(Set(alerts.compactMap(\.companyId)), Set([companyA, companyB]))

        let suiteName = "DuplicateChargeDismissalTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let dismissedAlert = alerts[0]
        XCTAssertFalse(DuplicateChargeDismissalStore.isDismissed(dismissedAlert, defaults: defaults))
        DuplicateChargeDismissalStore.dismiss(dismissedAlert, defaults: defaults)
        XCTAssertTrue(DuplicateChargeDismissalStore.isDismissed(dismissedAlert, defaults: defaults))
        DuplicateChargeDismissalStore.clear(dismissedAlert, defaults: defaults)
        XCTAssertFalse(DuplicateChargeDismissalStore.isDismissed(dismissedAlert, defaults: defaults))
    }

    func testRecurringSuggestionsAreCompanyScopedAndDisappearAfterImport() {
        let owner = UUID()
        let companyA = Company(userId: owner, name: "Alpha", structure: "LLC")
        let companyB = Company(userId: owner, name: "Beta", structure: "LLC")
        let transactions = [
            makeTransaction(owner: owner, company: companyA.id, name: "Notion", amount: 20, date: "2027-03-01"),
            makeTransaction(owner: owner, company: companyA.id, name: "Notion", amount: 20, date: "2027-04-01"),
            makeTransaction(owner: owner, company: companyB.id, name: "Notion", amount: 20, date: "2027-03-01"),
            makeTransaction(owner: owner, company: companyB.id, name: "Notion", amount: 20, date: "2027-04-01")
        ]
        let alphaSubscription = Subscription(userId: owner, companyId: companyA.id, name: "Notion")

        let allCompanySuggestions = SubscriptionDetector.detect(
            transactions: transactions,
            existingSubscriptions: []
        )
        XCTAssertEqual(allCompanySuggestions.count, 2)
        XCTAssertEqual(Set(allCompanySuggestions.map(\.id)).count, 2)

        let companyScoped = SubscriptionDetector.detect(
            transactions: transactions,
            existingSubscriptions: [alphaSubscription]
        )

        XCTAssertEqual(companyScoped.count, 1)
        XCTAssertEqual(companyScoped.first?.companyId, companyB.id)

        let state = AppState()
        state.companies = [companyA, companyB]
        state.transactions = transactions
        state.subscriptions = [alphaSubscription]
        let beforeImport = OwnerHealthEngine.snapshot(appState: state, scope: .business)
        let subscriptionHealth = beforeImport.categories.first { $0.category == .subscription }
        XCTAssertEqual(subscriptionHealth?.recurringSuggestions.count, 1)
        XCTAssertEqual(subscriptionHealth?.recurringSuggestions.first?.companyId, companyB.id)

        state.subscriptions.append(Subscription(userId: owner, companyId: companyB.id, name: "Notion"))
        let afterImport = OwnerHealthEngine.snapshot(appState: state, scope: .business)
        XCTAssertTrue(afterImport.categories.first { $0.category == .subscription }?.recurringSuggestions.isEmpty == true)
    }

    func testPendingTransactionsDoNotCreateRecurringSuggestions() {
        let owner = UUID(), company = UUID()
        var first = makeTransaction(owner: owner, company: company, name: "Pending Merchant", amount: 25, date: "2027-03-01")
        var second = makeTransaction(owner: owner, company: company, name: "Pending Merchant", amount: 25, date: "2027-04-01")
        first.pending = true
        second.pending = true

        XCTAssertTrue(SubscriptionDetector.detect(
            transactions: [first, second],
            existingSubscriptions: []
        ).isEmpty)
    }

    func testFinancialMovementsDoNotCreateRecurringSuggestions() {
        let owner = UUID(), company = UUID()
        let movements: [(String, [String])] = [
            ("Zelle payment", ["Transfer"]),
            ("ATM withdrawal", ["Cash"]),
            ("Payment To Auto Loan", ["Loan Payment"]),
            ("Citi Autopay", ["Payment"]),
            ("DLR AP Monthly Payment", [])
        ]
        let transactions = movements.flatMap { name, category in
            ["2027-03-01", "2027-04-01"].map { date -> Transaction in
                var transaction = makeTransaction(
                    owner: owner,
                    company: company,
                    name: name,
                    amount: 50,
                    date: date
                )
                transaction.category = category
                return transaction
            }
        }

        XCTAssertTrue(SubscriptionDetector.detect(
            transactions: transactions,
            existingSubscriptions: []
        ).isEmpty)
    }

    func testImportedTransactionStreamIsSuppressedOnlyForItsCompany() {
        let owner = UUID(), companyA = UUID(), companyB = UUID()
        let transactions = [companyA, companyB].flatMap { company in
            ["2027-03-01", "2027-04-01"].map {
                makeTransaction(
                    owner: owner,
                    company: company,
                    name: "Adobe Creative Cloud",
                    amount: 59.99,
                    date: $0
                )
            }
        }
        let imported = Subscription(
            userId: owner,
            companyId: companyA,
            name: "Creative tools",
            plaidStreamId: "detected_adobe creative cloud"
        )

        let detected = SubscriptionDetector.detect(
            transactions: transactions,
            existingSubscriptions: [imported]
        )

        XCTAssertEqual(detected.count, 1)
        XCTAssertEqual(detected.first?.companyId, companyB)
    }

    func testDismissedRecurringSuggestionReturnsAfterANewTransactionMonth() {
        let owner = UUID(), company = UUID()
        let suiteName = "RecurringSuggestionDismissalTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let augustTransactions = [
            makeTransaction(owner: owner, company: company, name: "Notion", amount: 20, date: "2027-07-12"),
            makeTransaction(owner: owner, company: company, name: "Notion", amount: 20, date: "2027-08-12")
        ]
        let initial = SubscriptionDetector.detect(
            transactions: augustTransactions,
            existingSubscriptions: [],
            dismissalDefaults: defaults
        )
        XCTAssertEqual(initial.count, 1)

        RecurringSuggestionDismissalStore.dismiss(initial[0], defaults: defaults)
        XCTAssertTrue(SubscriptionDetector.detect(
            transactions: augustTransactions,
            existingSubscriptions: [],
            dismissalDefaults: defaults
        ).isEmpty)

        let septemberTransaction = makeTransaction(
            owner: owner,
            company: company,
            name: "Notion",
            amount: 20,
            date: "2027-09-12"
        )
        XCTAssertEqual(SubscriptionDetector.detect(
            transactions: augustTransactions + [septemberTransaction],
            existingSubscriptions: [],
            dismissalDefaults: defaults
        ).count, 1)
    }

    func testDetectedSubscriptionImportAddsPaymentDayAndWebsite() {
        let owner = UUID(), company = UUID()
        var first = makeTransaction(owner: owner, company: company, name: "Adobe", amount: 59.99, date: "2027-03-17")
        var latest = makeTransaction(owner: owner, company: company, name: "Adobe", amount: 59.99, date: "2027-04-17")
        first.merchantWebsite = "https://adobe.com"
        latest.merchantWebsite = "https://adobe.com"
        let suggestion = SubscriptionDetector.detect(
            transactions: [first, latest],
            existingSubscriptions: []
        )[0]

        let imported = DetectedSubscriptionImportDefaults.make(
            for: suggestion,
            existingSubscriptions: []
        )

        XCTAssertEqual(imported.nextRenewal, "17")
        XCTAssertEqual(imported.website, "https://adobe.com")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        XCTAssertEqual(imported.nextRenewalAt.map(formatter.string), "2027-05-17")
    }

    func testOwnerHealthSeparatesBusinessAndPersonalScopes() {
        let owner = UUID()
        let business = Company(
            userId: owner,
            name: "Northstar LLC",
            structure: "LLC",
            companyDescription: "Consulting",
            website: "northstar.example"
        )
        let personal = Company(
            userId: owner,
            name: "Personal",
            structure: "Individual",
            companyDescription: "Personal portfolio",
            website: "personal.example"
        )
        let state = AppState()
        state.companies = [business, personal]
        state.subscriptions = [
            Subscription(
                userId: owner,
                companyId: business.id,
                name: "Business SaaS",
                cost: 25,
                paymentMethod: "Business Card",
                nextRenewalAt: Date().addingTimeInterval(10 * 86_400)
            ),
            Subscription(
                userId: owner,
                companyId: personal.id,
                name: "Personal Music",
                cost: 12,
                paymentMethod: "Personal Card",
                nextRenewalAt: Date().addingTimeInterval(10 * 86_400)
            )
        ]
        var potential = makeObligation(
            state: .open,
            severity: .attention,
            sourceType: .institution,
            kind: "new_recurring_charge"
        )
        potential.companyId = business.id
        state.obligations = [potential]
        state.transactions = [
            makeTransaction(owner: owner, company: business.id, name: "Shadow SaaS", amount: 40, date: "2027-03-01"),
            makeTransaction(owner: owner, company: business.id, name: "Shadow SaaS", amount: 40, date: "2027-04-01")
        ]

        let businessSnapshot = OwnerHealthEngine.snapshot(appState: state, scope: .business)
        let personalSnapshot = OwnerHealthEngine.snapshot(appState: state, scope: .personal)
        let businessSubscriptions = businessSnapshot.categories.first { $0.category == .subscription }
        let personalSubscriptions = personalSnapshot.categories.first { $0.category == .subscription }

        XCTAssertEqual(businessSnapshot.entityCount, 1)
        XCTAssertEqual(personalSnapshot.entityCount, 1)
        XCTAssertEqual(businessSubscriptions?.status, .needsAttention)
        XCTAssertEqual(businessSubscriptions?.affectedEntityNames, ["Northstar LLC"])
        XCTAssertEqual(personalSubscriptions?.status, .healthy)
        XCTAssertTrue(personalSnapshot.affectedEntityNames.isEmpty)
    }

    func testOwnerHealthKeepsMissingOptionalDataSeparateFromHealth() {
        let owner = UUID()
        let business = Company(userId: owner, name: "Studio", structure: "LLC")
        let state = AppState()
        state.companies = [business]
        state.cards = [FinancialCard(userId: owner, companyId: business.id, name: "Operating Card")]

        let snapshot = OwnerHealthEngine.snapshot(appState: state, scope: .business)
        let cards = snapshot.categories.first { $0.category == .card }

        XCTAssertEqual(cards?.status, .healthy)
        guard case .moreDataUseful(let count) = cards?.dataState else {
            return XCTFail("Expected incomplete card details to be informational")
        }
        XCTAssertEqual(count, 1)
        XCTAssertEqual(cards?.dataIssues.first?.resourceName, "Operating Card")
        XCTAssertTrue(cards?.dataIssues.first?.missingFields.contains("Expiration date") == true)

        let issueID = try! XCTUnwrap(cards?.dataIssues.first?.id)
        let ignoredSnapshot = OwnerHealthEngine.snapshot(
            appState: state,
            scope: .business,
            ignoredDataIssueIDs: [issueID]
        )
        let ignoredCards = ignoredSnapshot.categories.first { $0.category == .card }
        XCTAssertEqual(ignoredCards?.dataState, .complete)
        XCTAssertTrue(ignoredCards?.dataIssues.isEmpty == true)
    }

    func testOwnerHealthNamesEntityWithExpiredCard() {
        let owner = UUID()
        let business = Company(userId: owner, name: "Acme", structure: "S-Corp")
        let state = AppState()
        state.companies = [business]
        state.cards = [FinancialCard(
            userId: owner,
            companyId: business.id,
            name: "Corporate Card",
            expiresAt: Date().addingTimeInterval(-86_400),
            limit: 10_000
        )]

        let snapshot = OwnerHealthEngine.snapshot(appState: state, scope: .business)
        let cards = snapshot.categories.first { $0.category == .card }

        XCTAssertEqual(cards?.status, .critical)
        XCTAssertEqual(cards?.affectedEntityNames, ["Acme"])
        XCTAssertEqual(snapshot.status, .critical)
    }

    func testOwnerHealthCreditUtilizationExcludesDebitBalances() {
        let owner = UUID()
        let business = Company(userId: owner, name: "Acme", structure: "LLC")
        let state = AppState()
        state.companies = [business]
        state.cards = [
            FinancialCard(
                userId: owner,
                companyId: business.id,
                name: "Credit",
                type: "Credit",
                limit: 2_000,
                balance: 500
            ),
            FinancialCard(
                userId: owner,
                companyId: business.id,
                name: "Debit",
                type: "Debit",
                balance: 5_000
            )
        ]

        let snapshot = OwnerHealthEngine.snapshot(appState: state, scope: .business)
        let cards = snapshot.categories.first { $0.category == .card }
        let utilization = cards?.metrics.first { $0.label == "Utilization" }

        XCTAssertEqual(utilization?.value, "25%")
        XCTAssertEqual(cards?.status, .healthy)
    }

    @MainActor
    func testDowngradeMakesOnlySelectedCompanyEditable() {
        let owner = UUID()
        let selected = Company(userId: owner, name: "Selected", structure: "LLC")
        let readOnly = Company(userId: owner, name: "Read Only", structure: "LLC")
        let state = AppState()
        state.companies = [selected, readOnly]
        state.entitlementSnapshot = AccessSnapshot(
            tier: .free, status: .expired, productId: "test",
            selectedFreeCompanyId: selected.id, limits: .free
        )
        let viewModel = AppViewModel()
        var changed = readOnly
        changed.name = "Should Not Save"

        viewModel.updateCompany(changed, appState: state)

        XCTAssertEqual(state.companies.first(where: { $0.id == readOnly.id })?.name, "Read Only")
        XCTAssertNotNil(state.error)
    }

    private func makeObligation(
        state: ObligationState,
        severity: ObligationSeverity = .info,
        sourceType: ResourceKind = .subscription,
        kind: String = "subscription_renewal",
        deferredAt: Date? = nil,
        snoozedUntil: Date? = nil,
        updatedAt: Date = Date(timeIntervalSince1970: 1_000_000)
    ) -> PortfolioObligation {
        let id = UUID()
        return PortfolioObligation(
            id: id,
            ownerUserId: UUID(),
            companyId: nil,
            sourceType: sourceType,
            sourceId: UUID(),
            kind: kind,
            dueAt: nil,
            severity: severity,
            title: "Test reminder",
            summary: "Test summary",
            actionType: "open_source",
            state: state,
            deferredAt: deferredAt,
            snoozedUntil: snoozedUntil,
            fingerprint: id.uuidString,
            createdAt: updatedAt,
            updatedAt: updatedAt
        )
    }

    private func makeTransaction(
        owner: UUID,
        company: UUID,
        name: String,
        amount: Double,
        date: String
    ) -> Transaction {
        var transaction = Transaction()
        transaction.userId = owner
        transaction.companyId = company
        transaction.accountId = "checking"
        transaction.name = name
        transaction.amount = amount
        transaction.date = date
        return transaction
    }
}
