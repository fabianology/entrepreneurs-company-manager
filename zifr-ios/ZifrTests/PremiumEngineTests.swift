import XCTest
import CryptoKit
import class SwiftUI.ImageRenderer
import enum SwiftUI.DynamicTypeSize
@testable import Zifr

final class PremiumEngineTests: XCTestCase {
    func testReceiptSplitsMonthlyAndYearlyChargesByIndependentServiceType() {
        let owner = UUID(), company = UUID()
        let bill = Subscription(userId: owner, companyId: company, name: "Vehicle", cost: 400, subServices: [
            SubService(name: "Connectivity", cost: 200, billingCycle: .yearly, serviceType: .subscription),
            SubService(name: "Insurance", cost: 75, serviceType: .bill),
            SubService(name: "Paused", cost: 999, status: .paused, serviceType: .subscription)
        ], serviceType: .bill)
        let monthly = Subscription(userId: owner, companyId: company, name: "Streaming", cost: 20, serviceType: .subscription)
        let yearly = Subscription(userId: owner, companyId: company, name: "Annual bill", cost: 120, billingCycle: "Yearly", serviceType: .bill)
        let report = SubscriptionReceiptSummary(subscriptions: [bill, monthly, yearly], institutions: [], cards: [])
        XCTAssertEqual(report.total(.monthly, currency: "USD", serviceType: .bill), 475)
        XCTAssertEqual(report.total(.monthly, currency: "USD", serviceType: .subscription), 20)
        XCTAssertEqual(report.total(.yearly, currency: "USD", serviceType: .bill), 120)
        XCTAssertEqual(report.total(.yearly, currency: "USD", serviceType: .subscription), 200)
        for cycle in SubService.BillingCycle.allCases {
            XCTAssertEqual(report.total(cycle, currency: "USD"),
                           report.total(cycle, currency: "USD", serviceType: .bill)
                           + report.total(cycle, currency: "USD", serviceType: .subscription))
        }
    }

    @MainActor
    func testSubscriptionReportRendersCompactAndAccessibleLayouts() throws {
        let owner = UUID()
        let company = Company(userId: owner, name: "Personal")
        let card = FinancialCard(userId: owner, companyId: company.id, name: "Costco Citi",
                                 institutionName: "Citibank Online", last4: "9225", network: "Visa")
        let bank = Institution(userId: owner, companyId: company.id, name: "Schools First FCU",
                               accounts: [InstitutionAccount(name: "71 NEW CHECKING", last4: "9716")])
        let kia = Subscription(userId: owner, companyId: company.id, name: "KIA", cost: 413.88,
            paymentMethod: "71 NEW CHECKING", paymentMethodId: bank.id, nextRenewal: "15", subServices: [
                SubService(name: "Premium connectivity", paymentMethod: "Costco Citi", paymentMethodId: card.id,
                           cost: 200, billingCycle: .yearly, purpose: "Connected vehicle features", serviceType: .subscription)
            ], notes: "Family vehicle payment", serviceType: .bill)
        let netflix = Subscription(userId: owner, companyId: company.id, name: "Netflix", cost: 26.99,
                                    paymentMethod: "Costco Citi", paymentMethodId: card.id, nextRenewal: "5",
                                    notes: "Family entertainment", serviceType: .subscription)
        let view = SubscriptionReceiptView(company: company, subscriptions: [kia, netflix], institutions: [bank], cards: [card])
        for size in [DynamicTypeSize.large, .accessibility1] {
            let renderer = ImageRenderer(content: view.reportContent.frame(width: 353).environment(\.dynamicTypeSize, size))
            renderer.scale = 2
            let rendered = try XCTUnwrap(renderer.uiImage)
            XCTAssertEqual(rendered.size.width, 353)
            XCTAssertGreaterThan(rendered.size.height, 500)
            let attachment = XCTAttachment(image: rendered)
            attachment.name = "Subscription report - \(size)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testReceiptReconcilesAllDisplayedChargesBySourceAndCycle() {
        let owner = UUID(), company = UUID(), oldCardID = UUID()
        let citi = FinancialCard(userId: owner, companyId: company, name: "Costco Citi",
                                 institutionName: "Citibank Online", last4: "9225", network: "Visa")
        let checking = Institution(userId: owner, companyId: company, name: "Schools First FCU",
                                   accounts: [InstitutionAccount(name: "71 NEW CHECKING", last4: "9716")])
        let sofi = Institution(userId: owner, companyId: company, name: "SoFi",
                               accounts: [InstitutionAccount(name: "SoFi Checking", last4: "5181")])
        let oldCardCharges: [(String, Double)] = [
            ("Leon Jiu Jitsu", 155), ("At&t Bill Payment", 157), ("Google", 8.40), ("Chuke E. Cheese", 11.99)
        ]
        var subscriptions = oldCardCharges.map { name, cost in
            Subscription(userId: owner, companyId: company, name: name, cost: cost,
                         paymentMethod: "Visa •••• 9225", paymentMethodId: oldCardID, plaidAccountId: "old-card-account")
        }
        for (name, cost) in [("Cox Internet", 130.0), ("Netflix", 26.99), ("Knott's Berry Farm", 49.83)] {
            subscriptions.append(Subscription(userId: owner, companyId: company, name: name, cost: cost,
                                               paymentMethod: "Costco Citi", paymentMethodId: citi.id))
        }
        let kia = Subscription(userId: owner, companyId: company, name: "KIA", cost: 413.88,
                               paymentMethod: "71 NEW CHECKING", paymentMethodId: checking.id,
                               subServices: [SubService(name: "Premium connectivity", paymentMethod: "Costco Citi",
                                                        paymentMethodId: citi.id, cost: 200, billingCycle: .yearly)])
        subscriptions.append(kia)
        subscriptions.append(Subscription(userId: owner, companyId: company, name: "Tesla", cost: 283,
            paymentMethod: "Visa •••• 9225", paymentMethodId: oldCardID, subServices: [
                SubService(name: "Full Self Driving", paymentMethod: "Costco Citi", paymentMethodId: oldCardID, cost: 106),
                SubService(name: "Insurance", paymentMethod: "Costco Citi", paymentMethodId: oldCardID, cost: 279),
                SubService(name: "Premium connectivity", paymentMethod: "Costco Citi", paymentMethodId: oldCardID, cost: 120, billingCycle: .yearly)
            ]))
        for (name, cost) in [("Best Buy", 29.0), ("Moulton Water", 91.26)] {
            subscriptions.append(Subscription(userId: owner, companyId: company, name: name, cost: cost,
                                               paymentMethod: "SoFi Checking", paymentMethodId: sofi.id))
        }
        let report = SubscriptionReceiptSummary(subscriptions: subscriptions, institutions: [checking, sofi], cards: [citi])
        XCTAssertEqual(report.charges.count, 15)
        XCTAssertEqual(report.sources.count, 3)
        XCTAssertEqual(report.total(.monthly, currency: "USD"), 1741.35, accuracy: 0.001)
        XCTAssertEqual(report.total(.yearly, currency: "USD"), 320, accuracy: 0.001)
        XCTAssertEqual(report.annualTotal(currency: "USD"), 21216.20, accuracy: 0.001)
        let cardCharges = report.charges.filter { $0.source.id == "card:\(citi.id)" }
        XCTAssertEqual(cardCharges.filter { $0.cycle == .monthly }.reduce(0) { $0 + $1.amount }, 1207.21, accuracy: 0.001)
        XCTAssertEqual(cardCharges.filter { $0.cycle == .yearly }.reduce(0) { $0 + $1.amount }, 320, accuracy: 0.001)
        XCTAssertTrue(report.sources.first { $0.id == "card:\(citi.id)" }!.matchedSavedLabel)
        let kiaBase = report.charges.first { $0.name == "KIA" }!
        XCTAssertEqual(kiaBase.amount, 413.88)
        XCTAssertTrue(kiaBase.source.label.contains("71 NEW CHECKING"))
        let kiaExtra = report.charges.first { $0.name == "KIA · Premium connectivity" }!
        XCTAssertEqual(kiaExtra.amount, 200)
        XCTAssertEqual(kiaExtra.cycle, .yearly)
        XCTAssertEqual(kiaExtra.source.id, "card:\(citi.id)")
        for cycle in SubService.BillingCycle.allCases {
            let grouped = report.sources.reduce(0.0) { total, source in
                total + report.charges.filter { $0.source.id == source.id && $0.cycle == cycle }.reduce(0) { $0 + $1.amount }
            }
            XCTAssertEqual(grouped, report.total(cycle, currency: "USD"), accuracy: 0.001)
        }
    }

    func testReceiptExcludesInactiveChargesAndFreeBaseButKeepsPaidExtras() {
        let owner = UUID(), company = UUID()
        let free = Subscription(userId: owner, companyId: company, cost: 999, subServices: [
            SubService(name: "Paid Extra", cost: 120, billingCycle: .yearly),
            SubService(cost: 5, status: .paused), SubService(cost: 6, status: .cancelled), SubService(cost: 7, status: .pending)
        ], pricingModel: "free")
        let paused = Subscription(userId: owner, companyId: company, cost: 1000, status: "Paused", subServices: [SubService(cost: 100)])
        let report = SubscriptionReceiptSummary(subscriptions: [free, paused], institutions: [], cards: [])
        XCTAssertEqual(report.charges.count, 1)
        XCTAssertEqual(report.total(.monthly, currency: "USD"), 0)
        XCTAssertEqual(report.total(.yearly, currency: "USD"), 120)
        XCTAssertEqual(report.sources.first?.label, "Unknown payment source")
    }

    func testReceiptKeepsCurrenciesSeparateAndDoesNotInheritUnspecifiedChildSource() {
        let owner = UUID(), company = UUID()
        let card = FinancialCard(userId: owner, companyId: company, name: "Parent card")
        let usd = Subscription(userId: owner, companyId: company, cost: 10, paymentMethodId: card.id,
                               subServices: [SubService(name: "No source chosen", cost: 24, billingCycle: .yearly)])
        let eur = Subscription(userId: owner, companyId: company, cost: 120, currency: "EUR", billingCycle: "Yearly")
        let report = SubscriptionReceiptSummary(subscriptions: [usd, eur], institutions: [], cards: [card])
        XCTAssertEqual(report.currencies, ["EUR", "USD"])
        XCTAssertEqual(report.annualTotal(currency: "USD"), 144)
        XCTAssertEqual(report.annualTotal(currency: "EUR"), 120)
        XCTAssertEqual(report.charges.first { $0.name.contains("No source chosen") }?.source.label, "Unknown payment source")
    }

    func testReceiptDoesNotGuessAmbiguousCardsOrOverrideCurrentIdentifiers() {
        let owner = UUID(), company = UUID()
        let first = FinancialCard(userId: owner, companyId: company, name: "First card", last4: "9225", network: "Visa")
        let second = FinancialCard(userId: owner, companyId: company, name: "Second card", last4: "9225", network: "Visa")
        let unresolved = SubscriptionReceiptSummary.source(paymentMethod: "Visa •••• 9225", paymentMethodId: UUID(),
                                                           plaidAccountId: "old-account", institutions: [], cards: [first, second])
        XCTAssertTrue(unresolved.id.hasPrefix("unresolved:"))
        let explicit = SubscriptionReceiptSummary.source(paymentMethod: "First card", paymentMethodId: second.id,
                                                         plaidAccountId: nil, institutions: [], cards: [first, second])
        XCTAssertEqual(explicit.id, "card:\(second.id)")
        let lastFourOnly = SubscriptionReceiptSummary.source(paymentMethod: "9225", paymentMethodId: nil,
                                                             plaidAccountId: nil, institutions: [], cards: [first])
        XCTAssertTrue(lastFourOnly.id.hasPrefix("unresolved:"))
    }

    func testReceiptDoesNotMergeDuplicateNamesAndPrefersExactAccountID() {
        let owner = UUID(), company = UUID()
        let first = FinancialCard(userId: owner, companyId: company, name: "Visa")
        let second = FinancialCard(userId: owner, companyId: company, name: "Visa")
        let ambiguousCard = SubscriptionReceiptSummary.source(paymentMethod: "Visa", paymentMethodId: nil,
            plaidAccountId: nil, institutions: [], cards: [first, second])
        XCTAssertTrue(ambiguousCard.id.hasPrefix("unresolved:"))
        let bank = Institution(userId: owner, companyId: company, name: "Bank", accounts: [
            InstitutionAccount(name: "Checking", last4: "1111"),
            InstitutionAccount(name: "Checking", last4: "2222")
        ])
        for selectedInstitution in [nil, bank.id] {
            let ambiguousAccount = SubscriptionReceiptSummary.source(paymentMethod: "Checking", paymentMethodId: selectedInstitution,
                plaidAccountId: nil, institutions: [bank], cards: [])
            XCTAssertTrue(ambiguousAccount.id.hasPrefix("unresolved:"))
        }
        let explicit = SubscriptionReceiptSummary.source(paymentMethod: "Checking", paymentMethodId: bank.id,
            plaidAccountId: bank.accounts[1].id, institutions: [bank], cards: [])
        XCTAssertTrue(explicit.label.contains("2222"))
    }

    func testSupplementalServiceClassifiesIndependentlyAndRespectsManualChoice() {
        var addon = SubService(name: "Full Self Driving")
        let parent = Subscription(
            userId: UUID(), companyId: UUID(), name: "Tesla",
            subServices: [addon], notes: "Model 3 car payment"
        )
        XCTAssertEqual(parent.resolvedServiceType, .bill)
        XCTAssertEqual(parent.subServices[0].resolvedServiceType, .subscription)

        addon.name = "City Electric"
        XCTAssertEqual(addon.resolvedServiceType, .bill)
        addon.serviceType = .subscription
        XCTAssertEqual(addon.resolvedServiceType, .subscription)
        addon.serviceType = .automatic
        addon.name = "Model 3"
        addon.purpose = "Monthly car payment"
        XCTAssertEqual(addon.resolvedServiceType, .bill)
    }

    func testSupplementalServiceTypeRoundTripsInsideSubscription() throws {
        let addon = SubService(name: "Premium", serviceType: .bill)
        let parent = Subscription(
            userId: UUID(), companyId: UUID(), name: "Tesla", subServices: [addon]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(parent)
        let decoded = try JSONDecoder().decode(Subscription.self, from: data)
        XCTAssertEqual(decoded.subServices, [addon])
        XCTAssertEqual(decoded.subServices[0].resolvedServiceType, .bill)
    }

    func testLegacySupplementalServiceWithoutTypeStillDecodes() throws {
        let addon = SubService(name: "Water utility", cost: 45, billingCycle: .yearly)
        let encoded = try JSONEncoder().encode(addon)
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        payload.removeValue(forKey: "serviceType")
        let data = try JSONSerialization.data(withJSONObject: payload)
        let decoded = try JSONDecoder().decode(SubService.self, from: data)
        XCTAssertEqual(decoded, addon)
        XCTAssertEqual(decoded.serviceType, .automatic)
        XCTAssertEqual(decoded.resolvedServiceType, .bill)
    }

    func testRecurringServiceClassifierDistinguishesBillsAndSubscriptions() {
        XCTAssertEqual(
            RecurringServiceClassifier.classify(name: "AT&T Wireless"),
            .bill
        )
        XCTAssertEqual(
            RecurringServiceClassifier.classify(name: "Google One"),
            .subscription
        )
        XCTAssertEqual(
            RecurringServiceClassifier.classify(name: "City Services", categories: ["Utilities"]),
            .bill
        )
        XCTAssertEqual(
            RecurringServiceClassifier.classify(name: "Acme", categories: ["Software"]),
            .subscription
        )
    }

    func testManualRecurringServiceTypeOverridesAutomaticClassification() {
        var service = Subscription(userId: UUID(), companyId: UUID(), name: "AT&T Wireless")
        XCTAssertEqual(service.resolvedServiceType, .bill)

        service.serviceType = .subscription
        XCTAssertEqual(service.resolvedServiceType, .subscription)
    }

    func testRecurringServiceTypePersistsThroughSubscriptionCoding() throws {
        let service = Subscription(
            userId: UUID(),
            companyId: UUID(),
            name: "City Electric",
            serviceType: .bill
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(service)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(payload["service_type"] as? String, "bill")

        let decoded = try JSONDecoder().decode(Subscription.self, from: data)
        XCTAssertEqual(decoded.serviceType, .bill)
    }

    func testProtectedValueRoundTripWithCurrentKey() throws {
        let key = SymmetricKey(size: .bits256)
        let encrypted = try XCTUnwrap(SecurityService.encryptValue("secret", using: key))

        XCTAssertTrue(SecurityService.isLockedValue(encrypted))
        XCTAssertEqual(SecurityService.decryptValue(encrypted, using: key), "secret")
    }

    func testLegacyPlaintextRemainsAvailable() {
        let key = SymmetricKey(size: .bits256)
        XCTAssertEqual(SecurityService.decryptValue("legacy", using: key), "legacy")
        XCTAssertFalse(SecurityService.isLockedValue("legacy"))
    }

    func testCorruptedProtectedValueRemainsLockedAndPreserved() {
        let corrupted = "enc:not-valid-base64"
        let result = SecurityService.decryptValue(corrupted, using: SymmetricKey(size: .bits256))

        XCTAssertEqual(result, corrupted)
        XCTAssertTrue(SecurityService.isLockedValue(result))
        XCTAssertEqual(SecurityService.editableValue(result), "")
    }

    func testProtectedValueFromUnavailableKeyRemainsLockedAndPreserved() throws {
        let originalKey = SymmetricKey(size: .bits256)
        let replacementKey = SymmetricKey(size: .bits256)
        let encrypted = try XCTUnwrap(SecurityService.encryptValue("secret", using: originalKey))
        let result = SecurityService.decryptValue(encrypted, using: replacementKey)

        XCTAssertEqual(result, encrypted)
        XCTAssertTrue(SecurityService.isLockedValue(result))
        XCTAssertEqual(SecurityService.encryptValue(result, using: replacementKey), encrypted)
    }

    func testVersionedVaultFieldEnvelopeBindsCiphertextToItsRecordAndField() throws {
        let key = SymmetricKey(size: .bits256)
        let owner = UUID()
        let resource = UUID()
        let context = VaultFieldContext(
            ownerUserID: owner,
            resourceType: "subscription",
            resourceID: resource,
            fieldName: "password",
            keyVersion: 1
        )

        let envelope = try VaultCryptography.encryptField("correct horse battery staple", using: key, context: context)
        XCTAssertTrue(envelope.hasPrefix("miloom:v1:1:"))
        XCTAssertTrue(SecurityService.isLockedValue(envelope))
        XCTAssertEqual(SecurityService.decryptValue(envelope, using: key), envelope)
        XCTAssertEqual(try VaultCryptography.decryptField(envelope, using: key, context: context), "correct horse battery staple")

        let swappedField = VaultFieldContext(
            ownerUserID: owner,
            resourceType: "subscription",
            resourceID: resource,
            fieldName: "login_id",
            keyVersion: 1
        )
        XCTAssertThrowsError(try VaultCryptography.decryptField(envelope, using: key, context: swappedField)) {
            XCTAssertEqual($0 as? VaultCryptographyError, .authenticationFailed)
        }
    }

    func testVaultKeyWrapCanOnlyBeOpenedByTheTargetDevice() throws {
        let owner = UUID()
        let targetDevice = UUID()
        let targetIdentity = VaultDeviceIdentity(
            agreementPrivateKey: P256.KeyAgreement.PrivateKey(),
            signingPrivateKey: P256.Signing.PrivateKey()
        )
        let wrongIdentity = VaultDeviceIdentity(
            agreementPrivateKey: P256.KeyAgreement.PrivateKey(),
            signingPrivateKey: P256.Signing.PrivateKey()
        )
        let vaultKey = SymmetricKey(size: .bits256)
        let context = VaultKeyWrapContext(ownerUserID: owner, recipientDeviceID: targetDevice, keyVersion: 1)
        let envelope = try VaultCryptography.wrapVaultKey(
            vaultKey,
            for: targetIdentity.publicKeys.agreementPublicKey,
            context: context
        )

        let unwrapped = try VaultCryptography.unwrapVaultKey(
            envelope,
            using: targetIdentity.agreementPrivateKey,
            context: context
        )
        XCTAssertEqual(keyData(unwrapped), keyData(vaultKey))
        XCTAssertThrowsError(
            try VaultCryptography.unwrapVaultKey(
                envelope,
                using: wrongIdentity.agreementPrivateKey,
                context: context
            )
        ) {
            XCTAssertEqual($0 as? VaultCryptographyError, .authenticationFailed)
        }
    }

    func testRecoveryWrapRequiresTheGeneratedHighEntropyCode() throws {
        let vaultKey = SymmetricKey(size: .bits256)
        let context = VaultRecoveryWrapContext(ownerUserID: UUID(), keyVersion: 1)
        let recoveryCode = try VaultCryptography.generateRecoveryCode()
        let otherRecoveryCode = try VaultCryptography.generateRecoveryCode()
        let envelope = try VaultCryptography.wrapVaultKeyForRecovery(
            vaultKey,
            recoveryCode: recoveryCode,
            context: context
        )

        let recovered = try VaultCryptography.unwrapVaultKeyFromRecovery(
            envelope,
            recoveryCode: recoveryCode,
            context: context
        )
        XCTAssertEqual(keyData(recovered), keyData(vaultKey))
        XCTAssertThrowsError(
            try VaultCryptography.unwrapVaultKeyFromRecovery(
                envelope,
                recoveryCode: otherRecoveryCode,
                context: context
            )
        ) {
            XCTAssertEqual($0 as? VaultCryptographyError, .authenticationFailed)
        }
    }

    func testVaultDeviceSignatureRejectsChangedChallenge() throws {
        let identity = VaultDeviceIdentity(
            agreementPrivateKey: P256.KeyAgreement.PrivateKey(),
            signingPrivateKey: P256.Signing.PrivateKey()
        )
        let challenge = Data("approve-device|nonce-1".utf8)
        let signature = try VaultCryptography.sign(challenge, using: identity)

        XCTAssertTrue(VaultCryptography.verify(
            signature: signature,
            challenge: challenge,
            signingPublicKeyBase64: identity.publicKeys.signingPublicKey
        ))
        XCTAssertFalse(VaultCryptography.verify(
            signature: signature,
            challenge: Data("approve-device|nonce-2".utf8),
            signingPublicKeyBase64: identity.publicKeys.signingPublicKey
        ))
    }

    private func keyData(_ key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }

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

    func testOnlyAttachedServerPlaidItemsRepresentLinkedInstitutions() {
        let institutionId = UUID()
        let companyId = UUID()
        let active = PlaidItemSummary(
            id: UUID(), companyId: companyId, institutionId: institutionId,
            institutionName: "Example Bank", status: "active", errorCode: nil,
            lastSyncedAt: nil, createdAt: nil
        )
        let reconnect = PlaidItemSummary(
            id: UUID(), companyId: companyId, institutionId: institutionId,
            institutionName: "Example Bank", status: "requires_reauth",
            errorCode: "ITEM_LOGIN_REQUIRED", lastSyncedAt: nil, createdAt: nil
        )
        let archived = PlaidItemSummary(
            id: UUID(), companyId: companyId, institutionId: institutionId,
            institutionName: "Example Bank", status: "archived", errorCode: nil,
            lastSyncedAt: nil, createdAt: nil
        )
        let pending = PlaidItemSummary(
            id: UUID(), companyId: companyId, institutionId: nil,
            institutionName: "Example Bank", status: "pending_link", errorCode: nil,
            lastSyncedAt: nil, createdAt: nil
        )

        XCTAssertTrue(active.representsLinkedInstitution)
        XCTAssertTrue(reconnect.representsLinkedInstitution)
        XCTAssertFalse(archived.representsLinkedInstitution)
        XCTAssertFalse(pending.representsLinkedInstitution)
    }

    func testRenewalSchedulerAdvancesYearlyAndMonthlyDatesWithoutDrifting() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day))!
        }

        var monthlyService = SubService()
        monthlyService.billingCycle = .monthly
        monthlyService.renewsOn = date(2026, 8, 31)

        var yearlyService = SubService()
        yearlyService.billingCycle = .yearly
        yearlyService.renewsOn = date(2025, 9, 3)

        let subscription = Subscription(
            userId: UUID(),
            companyId: UUID(),
            billingCycle: "Yearly",
            nextRenewal: "Sep 3, 2025",
            nextRenewalAt: date(2025, 9, 3),
            subServices: [monthlyService, yearlyService]
        )
        let normalized = SubscriptionRenewalScheduler.normalized(
            subscription,
            now: date(2026, 9, 4),
            calendar: calendar
        )

        XCTAssertEqual(normalized.nextRenewalAt, date(2027, 9, 3))
        XCTAssertEqual(normalized.nextRenewal, "Sep 3, 2027")
        XCTAssertEqual(normalized.subServices[0].renewsOn, date(2026, 9, 30))
        XCTAssertEqual(normalized.subServices[1].renewsOn, date(2027, 9, 3))
    }

    func testRenewalSchedulerMovesLegacyMonthlyRenewalToTheNextMonth() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 4))!
        let subscription = Subscription(
            userId: UUID(), companyId: UUID(), billingCycle: "Monthly", nextRenewal: "3"
        )

        let normalized = SubscriptionRenewalScheduler.normalized(
            subscription,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(normalized.nextRenewal, "3")
        XCTAssertEqual(
            normalized.nextRenewalAt,
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 3))
        )
    }

    func testPaymentSourceResolverUsesPlaidAccountIdentityBeforeAccountName() {
        let owner = UUID(), company = UUID()
        let firstInstitution = Institution(
            userId: owner,
            companyId: company,
            name: "SoFi",
            accounts: [InstitutionAccount(
                id: "plaid-cash-account",
                plaidAccountId: "plaid-cash-account",
                name: "Cash Management",
                type: "Checking",
                last4: "4507"
            )]
        )
        let secondInstitution = Institution(
            userId: owner,
            companyId: company,
            name: "Schools First FCU",
            accounts: [InstitutionAccount(
                id: "plaid-schools-first-account",
                plaidAccountId: "plaid-schools-first-account",
                name: "Cash Management",
                type: "Checking",
                last4: "9921"
            )]
        )

        let source = PaymentSourceResolver.display(
            paymentMethod: "Cash Management",
            paymentMethodId: nil,
            plaidAccountId: "plaid-schools-first-account",
            institutions: [firstInstitution, secondInstitution],
            cards: []
        )

        XCTAssertEqual(source?.bank, "Schools First FCU")
        XCTAssertEqual(source?.account, "Cash Management ••••9921")
    }

    func testPaymentSourceResolverUsesInstitutionIdentityForManualBankSelections() {
        let owner = UUID(), company = UUID()
        let firstInstitution = Institution(
            userId: owner,
            companyId: company,
            name: "First Bank",
            accounts: [InstitutionAccount(name: "Business Checking", last4: "1111")]
        )
        let secondInstitution = Institution(
            userId: owner,
            companyId: company,
            name: "Second Bank",
            accounts: [InstitutionAccount(name: "Business Checking", last4: "2222")]
        )

        let source = PaymentSourceResolver.display(
            paymentMethod: "Business Checking",
            paymentMethodId: secondInstitution.id,
            plaidAccountId: firstInstitution.accounts[0].id,
            institutions: [firstInstitution, secondInstitution],
            cards: []
        )

        XCTAssertEqual(source?.bank, "Second Bank")
        XCTAssertEqual(source?.account, "Business Checking ••••2222")
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
        XCTAssertEqual(PrivateBriefingNotification.testBody, "Your private notifications are working.")
        XCTAssertFalse(PrivateBriefingNotification.testBody.contains("$"))
    }

    @MainActor
    func testNotificationRouteCoordinatorDefersAndConsumesExactlyOnce() {
        let coordinator = NotificationRouteCoordinator.shared
        coordinator.clear()
        let route = NotificationRoute.transaction(UUID())

        coordinator.enqueue(route)

        XCTAssertEqual(coordinator.pendingRoute, route)
        XCTAssertEqual(coordinator.takePendingRoute(), route)
        XCTAssertNil(coordinator.takePendingRoute())
    }

    func testNotificationRoutesResolveTypedDestinations() {
        let transactionID = UUID()
        let institutionID = UUID()
        let owner = UUID()
        let transactionAlert = AppNotification(
            id: UUID(),
            userId: owner,
            notificationType: "portfolio_alert",
            title: "Review transaction",
            body: "An item needs review.",
            resourceId: transactionID,
            resourceType: "transaction",
            isRead: false,
            createdAt: Date()
        )
        let briefing = AppNotification(
            id: UUID(),
            userId: owner,
            notificationType: "owner_briefing",
            title: "Briefing",
            body: "Items need attention.",
            resourceId: nil,
            resourceType: nil,
            isRead: false,
            createdAt: Date()
        )

        XCTAssertEqual(transactionAlert.route, .transaction(transactionID))
        XCTAssertEqual(briefing.route, .ownerBriefing)
        let reviewAlert = AppNotification(
            id: UUID(),
            userId: owner,
            notificationType: "portfolio_alert",
            title: "Review queue",
            body: "Items need review.",
            resourceId: nil,
            resourceType: "transaction_review",
            isRead: false,
            createdAt: Date()
        )
        XCTAssertEqual(reviewAlert.route, .transactionReview)
        XCTAssertEqual(
            NotificationRoute(pushUserInfo: [
                "route": "institution",
                "resource_id": institutionID.uuidString,
            ]),
            .institution(institutionID)
        )
        XCTAssertEqual(
            NotificationRoute(pushUserInfo: ["route": "transaction_review"]),
            .transactionReview
        )
    }

    func testInboxUnreadCountIncludesAlertsAndActivity() {
        let owner = UUID()
        let state = AppState()
        state.notifications = [AppNotification(
            id: UUID(), userId: owner, notificationType: "portfolio_alert",
            title: "Alert", body: "Review in Miloom.", resourceId: nil,
            resourceType: nil, isRead: false, createdAt: Date()
        )]
        state.activityLogs = [ActivityLog(
            userId: owner,
            actorEmail: "owner@example.com",
            actionType: "updated_company",
            message: "A company was updated."
        )]

        XCTAssertEqual(state.unreadNotificationCount, 1)
        XCTAssertEqual(state.unreadInboxCount, 2)
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

    func testTransactionOverrideUpdatesMerchantCategorySearchAndSummary() {
        let owner = UUID(), companyId = UUID()
        var transaction = makeTransaction(
            owner: owner,
            company: companyId,
            name: "Unrecognized ACH",
            amount: 250,
            date: "2027-08-01"
        )
        transaction.personalFinancePrimary = "GENERAL_SERVICES"
        var correction = TransactionOverride(userId: owner, transactionId: transaction.id)
        correction.merchantName = "Owner Transfer"
        correction.categoryPrimary = "TRANSFER"
        correction.categoryDetailed = "INTERNAL_ACCOUNT_TRANSFER"
        correction.flowOverride = .transfer
        correction.note = "Movement between company accounts"

        let record = TransactionIntelligence.resolveAll(
            [transaction],
            companies: [],
            institutions: [],
            cards: [],
            overrides: [correction]
        )[0]
        let summary = TransactionIntelligence.summary(for: [record])

        XCTAssertEqual(TransactionIntelligence.displayName(for: record), "Owner Transfer")
        XCTAssertEqual(TransactionIntelligence.categoryPrimary(for: record), "TRANSFER")
        XCTAssertEqual(TransactionIntelligence.categoryDetailed(for: record), "INTERNAL_ACCOUNT_TRANSFER")
        XCTAssertEqual(TransactionIntelligence.effectiveFlow(for: record), .transfer)
        XCTAssertTrue(TransactionIntelligence.matchesSearch(record, query: "company accounts"))
        XCTAssertEqual(summary.moneyOut, 0)
        XCTAssertEqual(summary.moneyIn, 0)
        XCTAssertEqual(summary.financialMovementCount, 1)
    }

    func testTransactionOverrideCanReclassifyIncomingAmountAsExpense() {
        let owner = UUID(), companyId = UUID()
        let transaction = makeTransaction(
            owner: owner,
            company: companyId,
            name: "Corrected debit",
            amount: -75,
            date: "2027-08-01"
        )
        var correction = TransactionOverride(userId: owner, transactionId: transaction.id)
        correction.flowOverride = .expense

        let record = TransactionIntelligence.resolveAll(
            [transaction],
            companies: [],
            institutions: [],
            cards: [],
            overrides: [correction]
        )[0]
        let summary = TransactionIntelligence.summary(for: [record])

        XCTAssertEqual(summary.moneyOut, 75)
        XCTAssertEqual(summary.moneyIn, 0)
    }

    func testRememberedMerchantCategoryAppliesWithinProfileAndExplicitOverrideWins() {
        let owner = UUID(), personalProfile = UUID(), businessProfile = UUID()
        var personalCharge = makeTransaction(
            owner: owner, company: personalProfile, name: "AYSO Soccer #418", amount: 95, date: "2027-08-01"
        )
        personalCharge.personalFinancePrimary = "GENERAL_SERVICES"
        var correctedCharge = makeTransaction(
            owner: owner, company: personalProfile, name: "AYSO Soccer #902", amount: 110, date: "2027-09-01"
        )
        correctedCharge.personalFinancePrimary = "GENERAL_SERVICES"
        var businessCharge = makeTransaction(
            owner: owner, company: businessProfile, name: "AYSO Soccer #512", amount: 75, date: "2027-09-01"
        )
        businessCharge.personalFinancePrimary = "GENERAL_SERVICES"

        let rule = TransactionCategoryRule(
            userId: owner,
            scopeKey: TransactionCategoryRule.scopeKey(companyId: personalProfile),
            merchantKey: "ayso soccer",
            merchantName: "AYSO Soccer",
            categoryPrimary: "Kids Sports"
        )
        var correction = TransactionOverride(userId: owner, transactionId: correctedCharge.id)
        correction.categoryPrimary = "Education"

        let records = TransactionIntelligence.resolveAll(
            [personalCharge, correctedCharge, businessCharge],
            companies: [],
            institutions: [],
            cards: [],
            overrides: [correction],
            categoryRules: [rule]
        )
        let personal = records.first { $0.id == personalCharge.id }!
        let corrected = records.first { $0.id == correctedCharge.id }!
        let business = records.first { $0.id == businessCharge.id }!

        XCTAssertEqual(TransactionIntelligence.categoryPrimary(for: personal), "Kids Sports")
        XCTAssertEqual(TransactionIntelligence.categoryPrimary(for: corrected), "Education")
        XCTAssertEqual(TransactionIntelligence.categoryPrimary(for: business), "GENERAL_SERVICES")
        XCTAssertEqual(personal.categoryRule?.id, rule.id)
        XCTAssertNil(business.categoryRule)
    }

    func testTransactionFlowOverridesProtectDuplicateAndRecurringDetection() {
        let owner = UUID(), companyId = UUID()
        let firstIncome = makeTransaction(
            owner: owner, company: companyId, name: "Client deposit", amount: 500, date: "2027-08-20"
        )
        let secondIncome = makeTransaction(
            owner: owner, company: companyId, name: "Client deposit", amount: 500, date: "2027-08-21"
        )
        var firstCorrection = TransactionOverride(userId: owner, transactionId: firstIncome.id)
        firstCorrection.flowOverride = .income
        var secondCorrection = TransactionOverride(userId: owner, transactionId: secondIncome.id)
        secondCorrection.flowOverride = .refund
        let records = TransactionIntelligence.resolveAll(
            [firstIncome, secondIncome],
            companies: [],
            institutions: [],
            cards: [],
            overrides: [firstCorrection, secondCorrection]
        )
        let enriched = TransactionIntelligence.enrichedTransactions(from: records)

        XCTAssertTrue(DuplicateChargeDetector.detect(records: records).isEmpty)
        XCTAssertEqual(enriched.map(\.amount), [-500, -500])
        XCTAssertTrue(SubscriptionDetector.detect(
            transactions: enriched,
            existingSubscriptions: []
        ).isEmpty)
    }

    func testEnrichedTransactionsNormalizeExpenseAndTransferOverrides() {
        let owner = UUID(), companyId = UUID()
        let correctedExpense = makeTransaction(
            owner: owner, company: companyId, name: "Corrected expense", amount: -75, date: "2027-08-20"
        )
        let correctedTransfer = makeTransaction(
            owner: owner, company: companyId, name: "Owner movement", amount: 200, date: "2027-08-21"
        )
        var expenseOverride = TransactionOverride(userId: owner, transactionId: correctedExpense.id)
        expenseOverride.flowOverride = .expense
        var transferOverride = TransactionOverride(userId: owner, transactionId: correctedTransfer.id)
        transferOverride.flowOverride = .transfer
        let records = TransactionIntelligence.resolveAll(
            [correctedExpense, correctedTransfer],
            companies: [],
            institutions: [],
            cards: [],
            overrides: [expenseOverride, transferOverride]
        )
        let enriched = TransactionIntelligence.enrichedTransactions(from: records)

        XCTAssertEqual(enriched.first(where: { $0.id == correctedExpense.id })?.amount, 75)
        XCTAssertEqual(enriched.first(where: { $0.id == correctedTransfer.id })?.category, ["Transfer"])
    }

    func testIgnoredTransactionsAreExcludedAndCanBeRestored() throws {
        let owner = UUID(), company = UUID()
        let transaction = makeTransaction(
            owner: owner, company: company, name: "Family purchase", amount: 500, date: "2027-08-20"
        )
        var correction = TransactionOverride(userId: owner, transactionId: transaction.id)
        correction.flowOverride = .ignored
        correction.note = "Purchase for Mom"
        let persisted = try JSONDecoder().decode(
            TransactionOverride.self, from: JSONEncoder().encode(correction)
        )
        XCTAssertEqual(persisted, correction)

        let state = AppState()
        state.transactions = [transaction]
        state.transactionOverrides = [persisted]
        XCTAssertTrue(state.transactionsForAnalysis.isEmpty)
        XCTAssertEqual(state.transactions, [transaction])

        let records = TransactionIntelligence.resolveAll(
            [transaction], companies: [], institutions: [], cards: [], overrides: [persisted]
        )
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(TransactionIntelligence.effectiveFlow(for: records[0]), .ignored)
        XCTAssertEqual(TransactionIntelligence.automaticFlow(for: transaction), .expense)
        XCTAssertTrue(TransactionIntelligence.enrichedTransactions(from: records).isEmpty)
        XCTAssertTrue(DuplicateChargeDetector.detect(records: records + records).isEmpty)
        let summary = TransactionIntelligence.summary(for: records)
        XCTAssertEqual(summary.moneyOut, 0)
        XCTAssertEqual(summary.moneyIn, 0)
        let insights = CashFlowInsightEngine.analyze(records: records, anchorDate: utcDate("2027-08-30"))
        XCTAssertFalse(insights.hasCurrentActivity)
        XCTAssertTrue(insights.expenseCategories.isEmpty)
        XCTAssertTrue(insights.expenseRecords.isEmpty)
        XCTAssertNil(insights.largestExpense)

        correction.flowOverride = nil
        state.transactionOverrides = [correction]
        XCTAssertEqual(state.transactionsForAnalysis, [transaction])
        let restored = TransactionIntelligence.resolveAll(
            [transaction], companies: [], institutions: [], cards: [], overrides: [correction]
        )
        XCTAssertEqual(TransactionIntelligence.summary(for: restored).moneyOut, 500)
        XCTAssertEqual(restored[0].override?.note, "Purchase for Mom")
    }

    func testCashFlowInsightsCompareMonthToDateWithSamePointLastMonthAndExcludeNoise() {
        let owner = UUID(), companyId = UUID()
        let currentExpense = makeTransaction(
            owner: owner, company: companyId, name: "Current expense", amount: 100, date: "2027-08-20"
        )
        let currentIncome = makeTransaction(
            owner: owner, company: companyId, name: "Client income", amount: -400, date: "2027-08-15"
        )
        var transfer = makeTransaction(
            owner: owner, company: companyId, name: "Internal transfer", amount: 2_000, date: "2027-08-18"
        )
        transfer.category = ["Transfer"]
        var pending = makeTransaction(
            owner: owner, company: companyId, name: "Pending expense", amount: 50, date: "2027-08-19"
        )
        pending.pending = true
        let previousExpense = makeTransaction(
            owner: owner, company: companyId, name: "Previous expense", amount: 200, date: "2027-07-20"
        )
        let previousIncome = makeTransaction(
            owner: owner, company: companyId, name: "Previous income", amount: -100, date: "2027-07-15"
        )
        let outsideComparableDays = makeTransaction(
            owner: owner, company: companyId, name: "End of previous month", amount: 900, date: "2027-07-31"
        )
        let records = [currentExpense, currentIncome, transfer, pending, previousExpense, previousIncome, outsideComparableDays].map {
            TransactionIntelligence.resolve($0, companies: [], institutions: [], cards: [])
        }

        let insights = CashFlowInsightEngine.analyze(
            records: records,
            anchorDate: utcDate("2027-08-30")
        )

        XCTAssertEqual(insights.current.moneyOut, 100)
        XCTAssertEqual(insights.current.moneyIn, 400)
        XCTAssertEqual(insights.current.net, 300)
        XCTAssertEqual(insights.current.transactionCount, 2)
        XCTAssertEqual(insights.previous.moneyOut, 200)
        XCTAssertEqual(insights.previous.moneyIn, 100)
        XCTAssertEqual(insights.previous.net, -100)
        XCTAssertEqual(insights.netChange, 400)
        XCTAssertEqual(insights.expenseCategories.reduce(0) { $0 + $1.amount }, 100)
        XCTAssertEqual(insights.expenseCategories.reduce(0) { $0 + $1.transactionCount }, 1)
        XCTAssertEqual(insights.expenseRecords.map(\.id), [currentExpense.id])
        XCTAssertEqual(Set(insights.records.map(\.id)), Set([currentExpense.id, currentIncome.id, transfer.id]))
    }

    func testCashFlowInsightsSelectOneCompleteHistoricalCalendarMonth() {
        let owner = UUID(), companyId = UUID()
        let may = makeTransaction(
            owner: owner, company: companyId, name: "May", amount: 99, date: "2027-05-20"
        )
        let june = makeTransaction(
            owner: owner, company: companyId, name: "June", amount: 10, date: "2027-06-05"
        )
        let endOfJune = makeTransaction(
            owner: owner, company: companyId, name: "End of June", amount: 30, date: "2027-06-30"
        )
        let july = makeTransaction(
            owner: owner, company: companyId, name: "July", amount: 500, date: "2027-07-01"
        )
        let records = [may, june, endOfJune, july].map {
            TransactionIntelligence.resolve($0, companies: [], institutions: [], cards: [])
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let insights = CashFlowInsightEngine.analyze(
            records: records,
            month: CashFlowMonth(year: 2027, month: 6),
            anchorDate: utcDate("2027-08-15"),
            calendar: calendar
        )

        XCTAssertEqual(insights.current.moneyOut, 40)
        XCTAssertEqual(insights.previous.moneyOut, 99)
        XCTAssertEqual(Set(insights.records.map(\.id)), Set([june.id, endOfJune.id]))
    }

    func testCashFlowMonthListCoversTheLatestTwelveNamedCalendarMonths() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let months = CashFlowMonth.recent(
            from: utcDate("2027-09-10"),
            calendar: calendar
        )

        XCTAssertEqual(months.count, 12)
        XCTAssertEqual(months.first, CashFlowMonth(year: 2027, month: 9))
        XCTAssertEqual(months.last, CashFlowMonth(year: 2026, month: 10))
        XCTAssertEqual(
            months.first?.title(calendar: calendar, locale: Locale(identifier: "en_US_POSIX")),
            "September 2027"
        )
    }

    func testCashFlowInsightsUseCorrectedCategoriesAndFindLargestExpense() {
        let owner = UUID(), companyId = UUID()
        var mealOne = makeTransaction(
            owner: owner, company: companyId, name: "Meal one", amount: 60, date: "2027-08-20"
        )
        mealOne.personalFinancePrimary = "GENERAL_MERCHANDISE"
        var mealTwo = makeTransaction(
            owner: owner, company: companyId, name: "Meal two", amount: 40, date: "2027-08-21"
        )
        mealTwo.personalFinancePrimary = "FOOD_AND_DRINK"
        var software = makeTransaction(
            owner: owner, company: companyId, name: "Software", amount: 80, date: "2027-08-22"
        )
        software.personalFinancePrimary = "GENERAL_SERVICES"
        var correction = TransactionOverride(userId: owner, transactionId: mealOne.id)
        correction.categoryPrimary = "FOOD_AND_DRINK"

        let records = TransactionIntelligence.resolveAll(
            [mealOne, mealTwo, software],
            companies: [],
            institutions: [],
            cards: [],
            overrides: [correction]
        )
        let insights = CashFlowInsightEngine.analyze(
            records: records,
            anchorDate: utcDate("2027-08-30")
        )

        XCTAssertEqual(insights.topExpenseCategory?.key, "FOOD_AND_DRINK")
        XCTAssertEqual(insights.topExpenseCategory?.label, "Food And Drink")
        XCTAssertEqual(insights.topExpenseCategory?.amount, 100)
        XCTAssertEqual(insights.topExpenseCategory?.transactionCount, 2)
        XCTAssertEqual(insights.topExpenseCategory?.share ?? 0, 100.0 / 180.0, accuracy: 0.0001)
        XCTAssertEqual(insights.expenseCategories.map(\.key), ["FOOD_AND_DRINK", "GENERAL_SERVICES"])
        XCTAssertEqual(insights.expenseCategories.map(\.amount), [100, 80])
        XCTAssertEqual(insights.expenseCategories.reduce(0) { $0 + $1.amount }, insights.current.moneyOut)
        XCTAssertEqual(insights.expenseCategories.reduce(0) { $0 + $1.share }, 1, accuracy: 0.0001)
        for category in insights.expenseCategories {
            let transactions = insights.expenseRecords.filter {
                TransactionIntelligence.categoryPrimary(for: $0) == category.key
            }
            XCTAssertEqual(transactions.count, category.transactionCount)
            XCTAssertEqual(transactions.reduce(0) { $0 + abs($1.transaction.amount ?? 0) }, category.amount)
        }
        XCTAssertEqual(TransactionIntelligence.displayName(for: insights.largestExpense!), "Software")
    }

    func testCashFlowInsightsReportNoActivityOutsideCurrentWindow() {
        let owner = UUID(), companyId = UUID()
        let oldExpense = makeTransaction(
            owner: owner, company: companyId, name: "Old expense", amount: 100, date: "2027-01-01"
        )
        let zeroAmount = makeTransaction(
            owner: owner, company: companyId, name: "Zero authorization", amount: 0, date: "2027-08-29"
        )
        let records = [oldExpense, zeroAmount].map {
            TransactionIntelligence.resolve($0, companies: [], institutions: [], cards: [])
        }

        let insights = CashFlowInsightEngine.analyze(
            records: records,
            anchorDate: utcDate("2027-08-30")
        )

        XCTAssertFalse(insights.hasCurrentActivity)
        XCTAssertTrue(insights.expenseCategories.isEmpty)
        XCTAssertTrue(insights.expenseRecords.isEmpty)
        XCTAssertNil(insights.topExpenseCategory)
        XCTAssertNil(insights.largestExpense)
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

    func testDuplicateChargeDetectorKeepsAccountsSeparate() {
        let owner = UUID(), company = UUID()
        var checkingCharge = makeTransaction(
            owner: owner,
            company: company,
            name: "Corner Market",
            amount: 42,
            date: "2027-08-10"
        )
        var creditCharge = makeTransaction(
            owner: owner,
            company: company,
            name: "Corner Market",
            amount: 42,
            date: "2027-08-10"
        )
        checkingCharge.accountId = "checking"
        creditCharge.accountId = "credit-card"

        let records = [checkingCharge, creditCharge].map {
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

    func testAutomationScheduleUsesMiloomMondayBasedWeekday() {
        let formatter = ISO8601DateFormatter()
        let sunday = formatter.date(from: "2026-08-30T12:00:00Z")!
        let next = AutomationSchedule.nextBriefingDate(
            weekday: 1,
            time: "08:30:00",
            timezone: "UTC",
            after: sunday
        )

        XCTAssertEqual(formatter.string(from: next!), "2026-08-31T08:30:00Z")
    }

    func testAlertRuleDefaultsRemainConservative() {
        let rules = AlertRule.conservativeDefaults(userId: UUID())
        XCTAssertEqual(rules.count, 7)
        XCTAssertFalse(rules.first { $0.ruleType == .unusualSpending }?.enabled ?? true)
        XCTAssertFalse(rules.first { $0.ruleType == .balanceChange }?.enabled ?? true)
        XCTAssertEqual(rules.first { $0.ruleType == .largeTransaction }?.thresholdAmount, 1_000)
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

    private func utcDate(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: "\(value)T12:00:00Z")!
    }
}
