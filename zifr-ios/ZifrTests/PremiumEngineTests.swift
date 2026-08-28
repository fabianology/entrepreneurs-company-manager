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
}
