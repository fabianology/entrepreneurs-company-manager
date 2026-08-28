import XCTest
@testable import Zifr

final class PremiumEngineTests: XCTestCase {
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
    }

    func testBriefingDateLabelUsesRequestedFormat() {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let date = calendar.date(from: DateComponents(year: 2027, month: 5, day: 5, hour: 12))!
        XCTAssertEqual(OwnerBriefingPresentation.dateLabel(for: date, timeZone: timeZone), "May 5 2027")
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
        deferredAt: Date? = nil,
        snoozedUntil: Date? = nil,
        updatedAt: Date = Date(timeIntervalSince1970: 1_000_000)
    ) -> PortfolioObligation {
        let id = UUID()
        return PortfolioObligation(
            id: id,
            ownerUserId: UUID(),
            companyId: nil,
            sourceType: .subscription,
            sourceId: UUID(),
            kind: "subscription_renewal",
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
}
