import XCTest
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
    func testSearchScreenRendersExactMatchesAndRelatedActions() async throws {
        let (state, a, b) = fixture()
        let first = FinancialCard(userId: owner, companyId: a.id, name: "Travel Visa", password: "fixture-only", institutionName: "Chase", last4: "4242", limit: 10000, balance: 1234.56)
        let second = FinancialCard(userId: owner, companyId: b.id, name: "Business Visa", institutionName: "Chase", last4: "4242")
        state.cards = [first, second]
        var service = Subscription(userId: owner, companyId: a.id, name: "Figma", cost: 144)
        service.billingCycle = "Yearly"; service.paymentMethodId = first.id; service.loginId = "design@example.com"; service.password = "fixture-only"
        state.subscriptions = [service]
        let auth = AuthViewModel()
        auth.currentUser = User(id: owner, appMetadata: [:], userMetadata: [:], aud: "authenticated", createdAt: now, updatedAt: now)
        auth.isAuthenticated = true
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let variants: [(String, DynamicTypeSize, String)] = [
            ("4242", .large, "Exact ending"),
            ("Figma", .large, "Service and password actions"),
            ("Figma", .accessibility3, "Large accessibility text"),
            ("No matching record", .large, "No results"),
            ("", .large, "First open")
        ]
        for (query, size, label) in variants {
            let vm = AppViewModel(); vm.searchQuery = query
            let search = GlobalSearchView(vm: vm).environment(state).environment(auth).environment(AccessController())
                .environment(\.dynamicTypeSize, size)
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
            controller.dismiss(animated: false)
            window.isHidden = true; window.rootViewController = nil; previous?.makeKey()
        }
        XCTAssertEqual(state.searchIndex(for: owner).search("4242").hits.count, 3)
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
