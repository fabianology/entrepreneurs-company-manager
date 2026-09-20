import XCTest
import StoreKit
import StoreKitTest
import SwiftUI
@testable import Zifr

/// Local StoreKit fixtures only. These prices/offers are never bundled in the shipping app.
@MainActor
final class PaywallStoreKitTests: XCTestCase {
    private var session: SKTestSession!
    private var store: StoreService!
    private var access: AccessController!
    private let monthlyID = "com.miloom.premium.monthly"
    private let yearlyID = "com.miloom.premium.yearly"

    override func setUp() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "MiloomPaywall", withExtension: "storekit"))
        session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        session.timeRate = .realTime
        // Exercise Apple's real local purchase/restore APIs, isolating the external server only.
        store = StoreService(serverVerifier: { _ in nil })
        access = AccessController()
        access.applyServerVerified(.free)
        await store.fetchProducts()
        XCTAssertEqual(store.products.count, 2)
    }

    override func tearDown() async throws {
        store = nil
        session.clearTransactions()
        session.resetToDefaultState()
        access.applyServerVerified(.free)
        session = nil
    }

    private func product(_ id: String) throws -> Product {
        try XCTUnwrap(store.products.first { $0.id == id })
    }

    func testDevelopmentUnlockDoesNotHidePurchasePaywall() {
        access.applyServerVerified(AccessSnapshot(tier: .pro, status: .active, productId: "debug-unlocked", limits: .pro))
        XCTAssertTrue(access.isPro, "Development features remain unlocked")
        XCTAssertFalse(access.hasProSubscription, "The simulator must still show plans and the purchase button")
        XCTAssertFalse(access.membershipSubtitle.contains("Manage Subscription"))

        access.applyLocallyVerified(productID: monthlyID, expirationDate: Date().addingTimeInterval(86_400), isTrial: false)
        XCTAssertTrue(access.hasProSubscription, "A verified subscription still presents management")
        access.applyServerVerified(.free)
        XCTAssertFalse(access.hasProSubscription)
    }

    func testBetaAccessIsLimitedToApplesSandboxEnvironment() {
        XCTAssertTrue(AccessController.grantsBetaAccess(for: .sandbox))
        XCTAssertFalse(AccessController.grantsBetaAccess(for: .production))
        XCTAssertFalse(AccessController.grantsBetaAccess(for: .xcode))
    }

    func testPricesSavingsAndEligibleTrial() async throws {
        let monthly = try product(monthlyID)
        let yearly = try product(yearlyID)
        let eligible = await yearly.subscription!.isEligibleForIntroOffer
        XCTAssertTrue(eligible)
        let terms = PaywallBillingTerms(product: yearly, isEligibleForIntroOffer: eligible)
        XCTAssertTrue(terms.hasTrial)
        XCTAssertEqual(terms.buttonTitle, "Start 7-day free trial")
        XCTAssertEqual(terms.nextTitle, "In 7 days")
        XCTAssertEqual(terms.nextDetail, "\(yearly.displayPrice), then yearly")
        XCTAssertEqual(PaywallBillingTerms.annualSavings(monthly: monthly, yearly: yearly), "Save 36%")
        XCTAssertNil(PaywallBillingTerms.annualSavings(monthly: nil, yearly: yearly))
        let returning = PaywallBillingTerms(product: monthly, isEligibleForIntroOffer: false)
        XCTAssertFalse(returning.hasTrial)
        XCTAssertEqual(returning.todayTitle, "Today · \(monthly.displayPrice)")
        XCTAssertEqual(returning.nextTitle, "In 1 month")
        XCTAssertEqual(returning.buttonTitle, "Subscribe to Pro")
    }

    func testPurchaseUnlocksAndPreservesAccountToken() async throws {
        let token = UUID()
        let outcome = try await store.purchase(product(yearlyID), appAccountToken: token, accessController: access)
        XCTAssertEqual(outcome, .purchased)
        XCTAssertTrue(access.isPro)
        let latest = await StoreKit.Transaction.latest(for: yearlyID)
        guard case .verified(let transaction) = latest else { return XCTFail("Missing verified purchase") }
        XCTAssertEqual(transaction.appAccountToken, token)
        let eligible = try await product(yearlyID).subscription!.isEligibleForIntroOffer
        XCTAssertFalse(eligible)
    }

    func testCancellationDoesNotUnlock() async throws {
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        let outcome = try await store.purchase(product(monthlyID), appAccountToken: UUID(), accessController: access)
        XCTAssertEqual(outcome, .cancelled)
        XCTAssertFalse(access.isPro)
    }

    func testPendingApprovalUnlocksThroughListener() async throws {
        session.askToBuyEnabled = true
        store.startListening(accessController: access)
        let outcome = try await store.purchase(product(monthlyID), appAccountToken: UUID(), accessController: access)
        XCTAssertEqual(outcome, .pending)
        XCTAssertFalse(access.isPro)
        let pending = try XCTUnwrap(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        for _ in 0..<50 {
            if access.isPro { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertTrue(access.isPro)
    }

    func testRestoreFindsPurchaseAndNoPurchase() async throws {
        let empty = try await store.restore(accessController: access)
        XCTAssertFalse(empty)
        _ = try await session.buyProduct(identifier: yearlyID)
        let restored = try await store.restore(accessController: access)
        XCTAssertTrue(restored)
        XCTAssertTrue(access.isPro)
        XCTAssertEqual(access.snapshot.productId, yearlyID)
    }

    func testExpiredAndRefundedPurchasesAreNotRestored() async throws {
        let transaction = try await session.buyProduct(identifier: monthlyID)
        try session.refundTransaction(identifier: UInt(transaction.id))
        let refunded = try await store.restore(accessController: access)
        XCTAssertFalse(refunded)
        session.clearTransactions()
        _ = try await session.buyProduct(identifier: yearlyID)
        try session.expireSubscription(productIdentifier: yearlyID)
        let expired = try await store.restore(accessController: access)
        XCTAssertFalse(expired)
        XCTAssertFalse(access.isPro)
    }

    func testServerFailurePreservesVerifiedPurchaseForRetry() async throws {
        store = StoreService(serverVerifier: { _ in throw URLError(.notConnectedToInternet) })
        await store.fetchProducts()
        let outcome = try await store.purchase(product(monthlyID), appAccountToken: UUID(), accessController: access)
        XCTAssertEqual(outcome, .purchased)
        XCTAssertTrue(access.isPro)
        XCTAssertNotNil(store.syncError)
        XCTAssertNil(store.loadError)
        var unfinished = false
        for await result in StoreKit.Transaction.unfinished {
            if case .verified(let transaction) = result, transaction.productID == monthlyID { unfinished = true }
        }
        XCTAssertTrue(unfinished)
    }

    func testUnavailablePricingClearsStaleProductsAndCanRetry() async throws {
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .loadProducts)
        await store.fetchProducts()
        XCTAssertTrue(store.products.isEmpty)
        XCTAssertNotNil(store.loadError)
        try await session.setSimulatedError(nil, forAPI: .loadProducts)
        await store.fetchProducts()
        XCTAssertEqual(store.products.count, 2)
        XCTAssertNil(store.loadError)
    }

    func testRestoreFailureDoesNotUnlock() async throws {
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .appStoreSync)
        do {
            _ = try await store.restore(accessController: access)
            XCTFail("Expected restore error")
        } catch { XCTAssertFalse(access.isPro) }
    }

    func testServerRetryFinishesTransaction() async throws {
        _ = try await store.purchase(product(yearlyID), appAccountToken: UUID(), accessController: access)
        let snapshot = access.snapshot
        var didVerify = false
        let retryStore = StoreService(serverVerifier: { signedTransaction in
            XCTAssertFalse(signedTransaction.isEmpty)
            didVerify = true
            return snapshot
        })
        await retryStore.retryUnfinishedTransactions(accessController: access)
        XCTAssertTrue(didVerify)
        var unfinished = false
        for await result in StoreKit.Transaction.unfinished {
            if case .verified(let transaction) = result, transaction.productID == yearlyID { unfinished = true }
        }
        XCTAssertFalse(unfinished)
        XCTAssertTrue(access.isPro)
    }

    func testRefundUpdateRemovesLocalAccess() async throws {
        store.startListening(accessController: access)
        _ = try await store.purchase(product(yearlyID), appAccountToken: UUID(), accessController: access)
        // Refund a completed delivery, as it would be after successful server synchronization.
        let latest = await StoreKit.Transaction.latest(for: yearlyID)
        guard case .verified(let transaction) = latest else { return XCTFail("Missing purchase to refund") }
        await transaction.finish()
        try session.refundTransaction(identifier: UInt(transaction.id))
        for _ in 0..<50 {
            if !access.isPro { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertFalse(access.isPro)
        XCTAssertEqual(access.snapshot.status, .revoked)
    }

    func testPaidIntroductoryOffersNeverClaimFreeTrial() async throws {
        let original = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "MiloomPaywall", withExtension: "storekit"))
        for mode in ["payAsYouGo", "payUpFront"] {
            session.clearTransactions()
            var config = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: original)) as? [String: Any])
            var groups = config["subscriptionGroups"] as! [[String: Any]]
            var products = groups[0]["subscriptions"] as! [[String: Any]]
            products[0]["introductoryOffer"] = ["internalID": UUID().uuidString, "paymentMode": mode,
                "subscriptionPeriod": "P1M", "numberOfPeriods": 3, "displayPrice": "2.99"]
            groups[0]["subscriptions"] = products
            config["subscriptionGroups"] = groups
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(mode).storekit")
            try JSONSerialization.data(withJSONObject: config).write(to: url)
            defer { try? FileManager.default.removeItem(at: url) }
            session = try SKTestSession(contentsOf: url)
            session.disableDialogs = true
            await store.fetchProducts()
            let monthly = try product(monthlyID)
            let offer = try XCTUnwrap(monthly.subscription?.introductoryOffer)
            let terms = PaywallBillingTerms(product: monthly, isEligibleForIntroOffer: true)
            XCTAssertFalse(terms.hasTrial)
            XCTAssertEqual(terms.buttonTitle, "Subscribe to Pro")
            XCTAssertEqual(terms.todayTitle, "Today · \(offer.displayPrice)")
            XCTAssertEqual(terms.nextTitle, "In 3 months")
            XCTAssertTrue(terms.disclosure.contains(monthly.displayPrice))
        }
    }

    func testPaywallVisualStates() async throws {
        for (name, width, yearly, eligible, expanded, reduced, feature) in [
            ("yearly-trial", 393.0, true, true, false, false, nil as PremiumFeature?),
            ("monthly-no-trial", 375.0, false, false, false, false, nil),
            ("company-expanded-reduced", 393.0, true, true, true, true, PremiumFeature.additionalCompany),
            ("briefing", 393.0, true, false, false, false, PremiumFeature.ownerBriefing)
        ] {
            let content = ConversionPaywallContent(
                gate: feature.map { PremiumGate(feature: $0, source: "test") },
                isPro: false, membershipSubtitle: "", isYearly: .constant(yearly),
                isShowingAllBenefits: .constant(expanded), isEligibleForIntroOffer: eligible,
                isLoadingProducts: false, isPurchasing: false, isRestoring: false,
                monthlyProduct: try product(monthlyID), yearlyProduct: try product(yearlyID),
                loadError: nil, dismiss: {}, purchase: {}, restore: {}, retry: {}, manageSubscription: {},
                reduceTransparencyOverride: reduced
            )
            let host = UIHostingController(rootView: content)
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
            let previousWindow = scene.windows.first { $0.isKeyWindow }
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: width, height: expanded ? 1050 : 900)
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.frame = window.bounds
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(200))
            let renderer = UIGraphicsImageRenderer(size: window.bounds.size)
            let image = renderer.image { _ in
                XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "paywall-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
            window.isHidden = true
            previousWindow?.makeKeyAndVisible()
        }
    }
}
