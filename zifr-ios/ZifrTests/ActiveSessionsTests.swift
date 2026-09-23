import XCTest
import SwiftUI
import CryptoKit
@testable import Zifr

final class ActiveSessionsTests: XCTestCase {
    func testEntitySharingChoicesKeepDistinctServerScopes() {
        XCTAssertEqual(EntitySharingScope.allCases.map(\.rawValue), [
            "company", "all_institutions", "all_financials", "all_subscriptions", "all_documents"
        ])
        XCTAssertEqual(Set(EntitySharingScope.allCases.map(\.id)).count, 5)
        XCTAssertEqual(EntitySharingScope.institutions.title, "All Institutions")
        XCTAssertEqual(EntitySharingScope.financials.title, "All Financials")
        XCTAssertNil(EntitySharingScope(rawValue: "institution"))
        XCTAssertNil(EntitySharingScope(rawValue: "unknown"))
    }

    @MainActor
    func testDocumentSaveWaitsForReceiptAndRetainsDraftOnFailure() async throws {
        let state = AppState()
        let actor = UUID(), owner = UUID()
        let company = Company(userId: owner, name: "Shared")
        state.portfolioUserID = actor
        state.companies = [company]
        let original = CompanyDocument(userId: owner, companyId: company.id, name: "Original")
        state.documents = [original]
        state.resourceShares = [ResourceShare(resourceId: original.id, resourceType: "document", userId: actor, role: "Editor")]
        var draft = original
        draft.name = "Unsaved draft"
        let vm = AppViewModel()
        do {
            try await vm.saveDocumentConfirmed(draft, appState: state) { _, exists in
                XCTAssertTrue(exists)
                XCTAssertEqual(state.documents, [original])
                throw NSError(domain: "Documents", code: 403)
            }
            XCTFail("Server denial was swallowed")
        } catch { XCTAssertEqual((error as NSError).code, 403) }
        XCTAssertEqual(state.documents, [original])
        XCTAssertEqual(draft.name, "Unsaved draft")
        try await vm.saveDocumentConfirmed(draft, appState: state) { _, exists in XCTAssertTrue(exists) }
        XCTAssertEqual(state.documents, [draft])
        state.resourceShares = []
        do {
            try await vm.saveDocumentConfirmed(draft, appState: state) { _, _ in XCTFail("Revoked edit reached persistence") }
            XCTFail("Revoked edit succeeded")
        } catch { XCTAssertEqual((error as NSError).code, 403) }
        XCTAssertEqual(state.documents, [draft])
    }

    @MainActor
    func testDocumentCreateFailureAndAccountChangeDoNotPublishDraft() async throws {
        let state = AppState()
        let owner = UUID()
        let company = Company(userId: owner, name: "Owned")
        state.portfolioUserID = owner
        state.companies = [company]
        let draft = CompanyDocument(userId: owner, companyId: company.id)
        let vm = AppViewModel()
        do {
            try await vm.saveDocumentConfirmed(draft, appState: state) { _, exists in
                XCTAssertFalse(exists)
                throw URLError(.notConnectedToInternet)
            }
            XCTFail("Offline create succeeded")
        } catch { XCTAssertTrue(error is URLError) }
        XCTAssertTrue(state.documents.isEmpty)
        do {
            try await vm.saveDocumentConfirmed(draft, appState: state) { _, _ in state.portfolioUserID = UUID() }
            XCTFail("Saved data crossed account boundary")
        } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertTrue(state.documents.isEmpty)
    }

    func testLoanSaveRequestKeepsLedgerAndRevisionInOneContract() throws {
        var loan = Loan(userId: UUID(), companyId: UUID(), name: "Loan")
        let encoder = JSONEncoder()
        let draftJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(LoanSaveRequest(loan))) as? [String: Any])
        XCTAssertTrue(draftJSON["p_expected_revision"] is NSNull)
        XCTAssertEqual((draftJSON["p_payments"] as? [Any])?.count, 0)
        loan.revision = 9
        XCTAssertThrowsError(try LoanSaveRequest(loan), "An unloaded ledger must not become an empty replacement")
        loan.payments = [LoanPayment(userId: loan.userId, loanId: loan.id, amount: 25)]
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(LoanSaveRequest(loan))) as? [String: Any])
        XCTAssertEqual(json["p_expected_revision"] as? Int, 9)
        XCTAssertEqual((json["p_payments"] as? [[String: Any]])?.first?["amount"] as? Double, 25)
        XCTAssertNil((json["p_loan"] as? [String: Any])?["payments"])
    }

    func testLoanSnapshotRestoresLedgerAndReturnedRevision() throws {
        var loan = Loan(userId: UUID(), companyId: UUID(), name: "Loan")
        loan.revision = 12
        let payment = LoanPayment(userId: loan.userId, loanId: loan.id, amount: 25)
        struct WireSnapshot: Encodable { let loan: Loan; let payments: [LoanPayment] }
        let data = try JSONEncoder().encode(WireSnapshot(loan: loan, payments: [payment]))
        let snapshot = try JSONDecoder().decode(LoanSnapshot.self, from: data)
        XCTAssertEqual(snapshot.value.revision, 12)
        XCTAssertEqual(snapshot.value.payments, [payment])
        loan.revision = nil
        XCTAssertNil(try JSONDecoder().decode(Loan.self, from: JSONEncoder().encode(loan)).revision)
    }

    @MainActor
    func testLoanSaveWaitsForConfirmationAndPreservesStateOnFailure() async throws {
        let state = AppState()
        let actor = UUID(), owner = UUID()
        let company = Company(userId: owner, name: "Shared")
        state.portfolioUserID = actor
        state.companies = [company]
        var original = Loan(userId: owner, companyId: company.id, name: "Original", payments: [])
        original.revision = 3
        state.loans = [original]
        state.resourceShares = [ResourceShare(resourceId: original.id, resourceType: "loan", userId: actor, role: "Editor")]
        var draft = original
        draft.name = "Edited"
        draft.payments = [LoanPayment(userId: owner, loanId: draft.id, amount: 25)]
        let vm = AppViewModel()
        do {
            _ = try await vm.saveLoanConfirmed(draft, appState: state) { _ in
                XCTAssertEqual(state.loans, [original], "Unconfirmed data must not replace saved state")
                throw LoanSaveError.changed
            }
            XCTFail("Failure was swallowed")
        } catch { XCTAssertTrue(error is LoanSaveError) }
        XCTAssertEqual(state.loans, [original])
        let saved = try await vm.saveLoanConfirmed(draft, appState: state) { value in
            var confirmed = value
            confirmed.revision = 5
            return confirmed
        }
        XCTAssertEqual(state.loans, [saved])
        XCTAssertEqual(state.loans.first?.revision, 5)
        XCTAssertEqual(state.loans.first?.payments?.count, 1)
        state.resourceShares = []
        do {
            _ = try await vm.saveLoanConfirmed(draft, appState: state) { _ in
                XCTFail("Revoked edit reached persistence")
                return original
            }
            XCTFail("Revoked edit succeeded")
        } catch { XCTAssertTrue(error is LoanSaveError) }
        XCTAssertEqual(state.loans, [saved])
    }

    func testResourceEditorPresentationIsExactFailClosedAndOrderIndependent() {
        let actor = UUID(), owner = UUID(), company = UUID(), item = UUID(), sibling = UUID()
        let companyViewer = ResourceShare(resourceId: company, resourceType: "company", userId: actor, role: "Viewer")
        for type in ["institution", "card", "loan", "document"] {
            let editor = ResourceShare(resourceId: item, resourceType: type, userId: actor, role: "Editor")
            for shares in [[companyViewer, editor], [editor, companyViewer]] {
                func allows(_ resourceID: UUID, _ resourceType: String = type, _ userID: UUID? = actor) -> Bool {
                    AppViewModel.resourceAllowsEdit(
                        shares, actorID: userID, ownerID: owner, companyID: company,
                        resourceType: resourceType, resourceID: resourceID
                    )
                }
                XCTAssertTrue(allows(item), type)
                XCTAssertFalse(allows(sibling), type)
                XCTAssertFalse(allows(company, "company"), type)
                XCTAssertFalse(allows(item, type, nil), type)
                XCTAssertFalse(allows(item, type, UUID()), type)
                // An item ID with the wrong type must not match either.
                XCTAssertFalse(allows(item, "subscription"), type)
            }
        }
        XCTAssertFalse(AppViewModel.resourceAllowsEdit(
            [], actorID: actor, ownerID: owner, companyID: company,
            resourceType: "document", resourceID: item
        ))
        XCTAssertTrue(AppViewModel.resourceAllowsEdit(
            [], actorID: owner, ownerID: owner, companyID: company,
            resourceType: "document", resourceID: item
        ))
        XCTAssertFalse(AppViewModel.resourceAllowsEdit(
            [], actorID: owner, ownerID: owner, companyID: company,
            resourceType: "document", resourceID: item, ownerCanEdit: false
        ))
    }

    func testCollectionEditorsDoNotInheritVisualChildPermissions() {
        let actor = UUID(), owner = UUID(), company = UUID(), item = UUID()
        let scopes: [String: Set<String>] = [
            "all_institutions": ["institution"],
            "all_financials": ["institution", "card", "loan"],
            "all_documents": ["document"],
            "all_subscriptions": ["subscription"]
        ]
        for (scope, allowedTypes) in scopes {
            let shares = [ResourceShare(resourceId: company, resourceType: scope, userId: actor, role: "Editor")]
            for type in ["company", "institution", "card", "loan", "document", "subscription"] {
                XCTAssertEqual(AppViewModel.resourceAllowsEdit(
                    shares, actorID: actor, ownerID: owner, companyID: company,
                    resourceType: type, resourceID: item
                ), allowedTypes.contains(type), "\(scope) → \(type)")
            }
            XCTAssertFalse(AppViewModel.resourceAllowsEdit(
                shares, actorID: actor, ownerID: owner, companyID: UUID(),
                resourceType: allowedTypes.first!, resourceID: item
            ))
        }
    }

    func testSharingManagementAndOwnerPrivateDocumentsRemainSeparateFromEditing() {
        let actor = UUID(), owner = UUID(), company = UUID(), document = UUID()
        for (type, id, role, expected) in [
            ("company", company, "Admin", true),
            ("company", company, "Editor", false),
            ("company", company, "Viewer", false),
            ("all_documents", company, "Admin", false),
            ("document", document, "Editor", false),
            ("document", document, "Admin", false),
            ("company", UUID(), "Admin", false)
        ] {
            let shares = [ResourceShare(resourceId: id, resourceType: type, userId: actor, role: role)]
            XCTAssertEqual(AppViewModel.resourceAllowsSharing(
                shares, actorID: actor, ownerID: owner, companyID: company
            ), expected, "\(type) / \(role)")
            XCTAssertFalse(AppViewModel.resourceAllowsEdit(
                shares, actorID: actor, ownerID: owner, companyID: company,
                resourceType: "document", resourceID: document, isOwnerPrivate: true
            ))
            XCTAssertFalse(AppViewModel.resourceAllowsSharing(
                shares, actorID: actor, ownerID: owner, companyID: company, isOwnerPrivate: true
            ))
        }
        XCTAssertTrue(AppViewModel.resourceAllowsSharing([], actorID: owner, ownerID: owner, companyID: company))
        XCTAssertFalse(AppViewModel.resourceAllowsSharing([], actorID: nil, ownerID: owner, companyID: company))
        XCTAssertFalse(AppViewModel.resourceAllowsSharing([], actorID: owner, ownerID: owner, companyID: company, isOwnerPrivate: true))
    }

    func testSharedEditorScopesMatchTheExactResourceAndCollections() {
        let actor = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let otherActor = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let company = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let bank = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
        let card = UUID(uuidString: "40000000-0000-0000-0000-000000000001")!
        let document = UUID(uuidString: "60000000-0000-0000-0000-000000000001")!
        func share(_ type: String, _ id: UUID, _ role: String = "Editor", _ user: UUID? = nil) -> ResourceShare {
            ResourceShare(resourceId: id, resourceType: type, userId: user ?? actor, role: role)
        }
        func allows(_ shares: [ResourceShare], _ type: String, _ id: UUID) -> Bool {
            AppViewModel.shareAllowsEdit(
                shares, actorID: actor, companyID: company,
                resourceType: type, resourceID: id
            )
        }

        XCTAssertTrue(allows([share("document", document)], "document", document))
        XCTAssertFalse(allows([share("document", document)], "institution", bank))
        XCTAssertTrue(allows([share("institution", bank)], "institution", bank))
        XCTAssertFalse(allows([share("all_institutions", company)], "card", card))
        XCTAssertTrue(allows([share("all_institutions", company)], "institution", bank))
        XCTAssertTrue(allows([share("all_financials", company)], "card", card))
        XCTAssertFalse(allows([share("all_financials", company)], "document", document))
        XCTAssertFalse(allows([share("company", company, "Viewer")], "document", document))
        XCTAssertTrue(allows([
            share("company", company, "Viewer"), share("document", document)
        ], "document", document))
        XCTAssertFalse(allows([share("document", document, "Editor", otherActor)], "document", document))
        XCTAssertTrue(allows([share("company", company, "Admin")], "document", document))
        let service = UUID()
        let siblingService = UUID()
        XCTAssertTrue(allows([share("subscription", service)], "subscription", service))
        XCTAssertFalse(allows([share("subscription", service)], "subscription", siblingService))
        XCTAssertFalse(allows([share("subscription", service)], "company", company))
        XCTAssertTrue(allows([share("all_subscriptions", company)], "subscription", service))
        XCTAssertFalse(allows([share("all_subscriptions", company)], "company", company))
        XCTAssertFalse(allows([share("all_subscriptions", company)], "document", document))
        XCTAssertTrue(allows([
            share("company", company, "Viewer"), share("subscription", service)
        ], "subscription", service))
        XCTAssertFalse(allows([
            share("company", company, "Viewer"), share("subscription", service)
        ], "subscription", siblingService))
    }

    func testDocumentDeletionAcceptsOnlyAppGeneratedRelativeStoragePath() {
        let path = "00000000-0000-0000-0000-000000000001/document.pdf"
        XCTAssertEqual(DataRepository.companyDocumentStoragePath(path), path)
        XCTAssertNil(DataRepository.companyDocumentStoragePath(
            "https://example.com/CompanyDocuments/\(path)"
        ))
        XCTAssertNil(DataRepository.companyDocumentStoragePath("file:///private/tmp/document.pdf"))
        XCTAssertNil(DataRepository.companyDocumentStoragePath(
            "00000000-0000-0000-0000-000000000001/"
        ))
        XCTAssertNil(DataRepository.companyDocumentStoragePath("other/document.pdf"))
    }

    func testDocumentOpeningDistinguishesExternalLinksAndPrivateStorage() {
        let path = "00000000-0000-0000-0000-000000000001/document.pdf"
        XCTAssertEqual(DataRepository.companyDocumentStorageReadPath(path), path)
        XCTAssertEqual(DataRepository.companyDocumentStorageReadPath(
            "https://example.test/storage/v1/object/sign/CompanyDocuments/\(path)?token=old"
        ), path)
        XCTAssertEqual(DataRepository.companyDocumentStorageReadPath(
            "https://example.test/CompanyDocuments/\(path.replacingOccurrences(of: "/", with: "%2F"))#preview"
        ), path)
        XCTAssertNil(DataRepository.companyDocumentStorageReadPath("https://drive.example.test/report.pdf"))
        XCTAssertNil(DataRepository.companyDocumentStorageReadPath("file:///private/tmp/document.pdf"))
        XCTAssertEqual(DataRepository.externalDocumentURL("https://drive.example.test/report.pdf")?.host,
                       "drive.example.test")
        XCTAssertNil(DataRepository.externalDocumentURL(
            "https://example.test/CompanyDocuments/\(path)"
        ))
    }

    func testSessionDecodesServerCurrentFlag() throws {
        let data = Data(
            #"{"id":"25000000-0000-0000-0000-000000000001","created_at":0,"updated_at":0,"user_agent":"Miloom iOS App (iPhone; iOS 26.0)","ip_address":"203.0.113.10","is_current":true}"#.utf8
        )

        let session = try JSONDecoder().decode(ActiveSession.self, from: data)

        XCTAssertTrue(session.isCurrent)
        XCTAssertEqual(session.ipAddress, "203.0.113.10")
    }

    func testSessionDecodesLegacyResponseWithoutCurrentFlag() throws {
        let data = Data(
            #"{"id":"25000000-0000-0000-0000-000000000001","created_at":0,"updated_at":0,"user_agent":null,"ip_address":null}"#.utf8
        )

        let session = try JSONDecoder().decode(ActiveSession.self, from: data)

        XCTAssertFalse(session.isCurrent)
    }

    func testSessionIDDecodesFromAccessToken() {
        let expectedID = UUID(uuidString: "25000000-0000-0000-0000-000000000001")!
        let payload = Data(#"{"session_id":"25000000-0000-0000-0000-000000000001"}"#.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        XCTAssertEqual(sessionIDFromAccessToken("header.\(payload).signature"), expectedID)
        XCTAssertNil(sessionIDFromAccessToken("not-a-jwt"))
    }

    func testDeviceLabelsUseRecordedUserAgent() {
        XCTAssertEqual(parseUserAgent("Miloom iOS App (iPhone; iOS 26.0)").name, "iPhone")
        XCTAssertEqual(parseUserAgent("Miloom iOS App (iPad; iOS 26.0)").name, "iPad")
        XCTAssertEqual(parseUserAgent("Mozilla/5.0 (Macintosh; Intel Mac OS X)").name, "MacBook")
        XCTAssertEqual(parseUserAgent("Miloom App (Mac)").name, "MacBook")
        XCTAssertEqual(parseUserAgent(nil).name, "Unknown Device")
    }

    func testSessionAddressMasksFullIPAddress() {
        XCTAssertEqual(maskedSessionAddress("203.0.113.10"), "Network 203.0.•••.•••")
        XCTAssertEqual(maskedSessionAddress("2001:db8:1234:5678::1"), "Network 2001:db8:…")
        XCTAssertNil(maskedSessionAddress("127.0.0.1"))
        XCTAssertNil(maskedSessionAddress("::1"))
        XCTAssertNil(maskedSessionAddress("not-an-ip"))
    }

    @MainActor
    func testSessionRowExpandsForAccessibilityText() {
        let session = ActiveSession(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(),
            userAgent: "Miloom iOS App (iPhone; iOS 26.0)",
            ipAddress: "203.0.113.10",
            isCurrent: true
        )

        func fittedHeight(_ sizeCategory: ContentSizeCategory) -> CGFloat {
            let content = SessionRow(session: session, isRevoking: false)
                .environment(\.sizeCategory, sizeCategory)
            let host = UIHostingController(rootView: content)
            return host.sizeThatFits(in: CGSize(width: 350, height: 1_000)).height
        }

        XCTAssertGreaterThan(
            fittedHeight(.accessibilityExtraExtraExtraLarge),
            fittedHeight(.large),
            "The session row should grow rather than clip accessibility text."
        )
    }
}

final class ResourceVaultCryptographyTests: XCTestCase {
    private let owner = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let bank = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
    private let otherBank = UUID(uuidString: "30000000-0000-0000-0000-000000000002")!
    private let recipient = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let device = UUID(uuidString: "70000000-0000-0000-0000-000000000001")!

    func testResourceCiphertextIsBoundToOwnerResourceAndVersion() throws {
        let key = SymmetricKey(size: .bits256)
        let context = ResourceSecretFieldContext(resource: ResourceKeyContext(ownerUserID: owner, resourceType: "institution", resourceID: bank, keyVersion: 1), fieldName: "password")
        let ciphertext = try VaultCryptography.encryptResourceSecret("example-secret", using: key, context: context)
        XCTAssertEqual(try VaultCryptography.decryptResourceSecret(ciphertext, using: key, context: context), "example-secret")
        XCTAssertThrowsError(try VaultCryptography.decryptResourceSecret(ciphertext, using: key,
            context: ResourceSecretFieldContext(resource: ResourceKeyContext(ownerUserID: owner, resourceType: "institution", resourceID: otherBank, keyVersion: 1), fieldName: "password")))
        XCTAssertThrowsError(try VaultCryptography.decryptResourceSecret(ciphertext, using: key,
            context: ResourceSecretFieldContext(resource: ResourceKeyContext(ownerUserID: recipient, resourceType: "institution", resourceID: bank, keyVersion: 1), fieldName: "password")))
        XCTAssertThrowsError(try VaultCryptography.decryptResourceSecret(ciphertext, using: key,
            context: ResourceSecretFieldContext(resource: ResourceKeyContext(ownerUserID: owner, resourceType: "institution", resourceID: bank, keyVersion: 2), fieldName: "password")))
        XCTAssertThrowsError(try VaultCryptography.decryptResourceSecret(ciphertext, using: key,
            context: ResourceSecretFieldContext(resource: context.resource, fieldName: "username")))
    }

    func testResourceKeyWrapsCannotMoveToAnotherResourceOrDevice() throws {
        let resourceKey = SymmetricKey(size: .bits256)
        let accountKey = SymmetricKey(size: .bits256)
        let resource = ResourceKeyContext(ownerUserID: owner, resourceType: "institution", resourceID: bank, keyVersion: 1)
        let otherResource = ResourceKeyContext(ownerUserID: owner, resourceType: "institution", resourceID: otherBank, keyVersion: 1)
        let ownerContext = ResourceOwnerWrapContext(resource: resource, accountKeyVersion: 3)
        let ownerWrap = try VaultCryptography.wrapResourceKeyForOwner(resourceKey, using: accountKey, context: ownerContext)
        XCTAssertNoThrow(try VaultCryptography.unwrapResourceKeyForOwner(ownerWrap, using: accountKey, context: ownerContext))
        XCTAssertThrowsError(try VaultCryptography.unwrapResourceKeyForOwner(ownerWrap, using: accountKey,
            context: ResourceOwnerWrapContext(resource: otherResource, accountKeyVersion: 3)))
        XCTAssertThrowsError(try VaultCryptography.unwrapResourceKeyForOwner(ownerWrap, using: accountKey,
            context: ResourceOwnerWrapContext(resource: resource, accountKeyVersion: 4)))

        let identity = P256.KeyAgreement.PrivateKey()
        let deviceContext = ResourceDeviceWrapContext(resource: resource, recipientUserID: recipient, recipientDeviceID: device)
        let envelope = try VaultCryptography.wrapResourceKeyForDevice(resourceKey,
            for: identity.publicKey.x963Representation.base64EncodedString(), context: deviceContext)
        XCTAssertNoThrow(try VaultCryptography.unwrapResourceKeyForDevice(envelope, using: identity, context: deviceContext))
        XCTAssertThrowsError(try VaultCryptography.unwrapResourceKeyForDevice(envelope, using: identity,
            context: ResourceDeviceWrapContext(resource: otherResource, recipientUserID: recipient, recipientDeviceID: device)))
        XCTAssertThrowsError(try VaultCryptography.unwrapResourceKeyForDevice(envelope, using: identity,
            context: ResourceDeviceWrapContext(resource: resource, recipientUserID: recipient, recipientDeviceID: UUID())))
        XCTAssertThrowsError(try VaultCryptography.unwrapResourceKeyForDevice(envelope,
            using: P256.KeyAgreement.PrivateKey(), context: deviceContext))
    }

    func testDeviceSecretResponseDecodesAndRevealsOnlyBoundResource() throws {
        let identity = P256.KeyAgreement.PrivateKey()
        let key = SymmetricKey(size: .bits256)
        let resource = ResourceKeyContext(
            ownerUserID: owner, resourceType: "institution", resourceID: bank,
            keyVersion: 1
        )
        let context = ResourceDeviceWrapContext(
            resource: resource, recipientUserID: recipient, recipientDeviceID: device
        )
        let wrapped = try VaultCryptography.wrapResourceKeyForDevice(
            key, for: identity.publicKey.x963Representation.base64EncodedString(),
            context: context
        )
        let field = ResourceSecretFieldContext(resource: resource, fieldName: "password")
        let ciphertext = try VaultCryptography.encryptResourceSecret(
            "test-bank-secret", using: key, context: field
        )
        let response: [String: Any] = [
            "owner_user_id": owner.uuidString,
            "resource_type": "institution",
            "resource_id": bank.uuidString,
            "key_version": 1,
            "encrypted_fields": ["password": ciphertext],
            "ephemeral_public_key": wrapped.ephemeralPublicKey,
            "wrapped_resource_key": wrapped.wrappedKey
        ]
        let record = try JSONDecoder().decode(
            DeviceResourceSecretRecord.self,
            from: JSONSerialization.data(withJSONObject: response)
        )
        XCTAssertEqual(record.ownerUserID, owner)
        XCTAssertEqual(record.resourceID, bank)
        let deliveredKey = try VaultCryptography.unwrapResourceKeyForDevice(
            VaultDeviceKeyWrapEnvelope(
                version: 1, keyVersion: record.keyVersion,
                ephemeralPublicKey: record.ephemeralPublicKey,
                wrappedKey: record.wrappedResourceKey
            ), using: identity, context: context
        )
        XCTAssertEqual(try VaultCryptography.decryptResourceSecret(
            try XCTUnwrap(record.encryptedFields["password"]),
            using: deliveredKey, context: field
        ), "test-bank-secret")
        XCTAssertThrowsError(try VaultCryptography.decryptResourceSecret(
            ciphertext, using: deliveredKey,
            context: ResourceSecretFieldContext(
                resource: ResourceKeyContext(ownerUserID: owner,
                    resourceType: "institution", resourceID: otherBank,
                    keyVersion: 1), fieldName: "password"
            )
        ))
    }

    func testRotationReencryptsEveryFieldUnderNewVersion() throws {
        let originalKey = SymmetricKey(size: .bits256)
        let replacementKey = SymmetricKey(size: .bits256)
        let original = ResourceKeyContext(
            ownerUserID: owner, resourceType: "card", resourceID: bank,
            keyVersion: 1
        )
        let replacement = ResourceKeyContext(
            ownerUserID: owner, resourceType: "card", resourceID: bank,
            keyVersion: 2
        )
        let values = ["login": "test-user", "password": "test-password"]
        var rotated: [String: String] = [:]
        for (field, value) in values {
            let oldCiphertext = try VaultCryptography.encryptResourceSecret(
                value, using: originalKey,
                context: ResourceSecretFieldContext(resource: original, fieldName: field)
            )
            let recovered = try VaultCryptography.decryptResourceSecret(
                oldCiphertext, using: originalKey,
                context: ResourceSecretFieldContext(resource: original, fieldName: field)
            )
            rotated[field] = try VaultCryptography.encryptResourceSecret(
                recovered, using: replacementKey,
                context: ResourceSecretFieldContext(resource: replacement, fieldName: field)
            )
        }
        XCTAssertEqual(Set(rotated.keys), Set(values.keys))
        for (field, value) in values {
            let newCiphertext = try XCTUnwrap(rotated[field])
            XCTAssertEqual(try VaultCryptography.decryptResourceSecret(
                newCiphertext, using: replacementKey,
                context: ResourceSecretFieldContext(resource: replacement, fieldName: field)
            ), value)
            XCTAssertThrowsError(try VaultCryptography.decryptResourceSecret(
                newCiphertext, using: originalKey,
                context: ResourceSecretFieldContext(resource: replacement, fieldName: field)
            ))
        }
    }
}

final class ResourceSecretPreparationTests: XCTestCase {
    private let owner = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let device = UUID(uuidString: "70000000-0000-0000-0000-000000000001")!
    private let bank = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!

    private func snapshot() -> VaultKeySession.Snapshot {
        let key = SymmetricKey(size: .bits256)
        return VaultKeySession.Snapshot(
            userID: owner, deviceID: device, keyVersion: 1, key: key, keys: [1: key]
        )
    }

    func testReadableVaultFieldIsPreparedOnlyWithMatchingRecordContext() throws {
        let snapshot = snapshot()
        let field = VaultFieldContext(
            ownerUserID: owner, resourceType: "institution", resourceID: bank,
            fieldName: "password", keyVersion: 1
        )
        let encrypted = try VaultCryptography.encryptField(
            "test-password", using: snapshot.key, context: field
        )
        XCTAssertEqual(
            try ResourceSecretPreparation.verifiedPlaintext(
                encrypted, snapshot: snapshot, storedResourceType: "institution",
                resourceID: bank, fieldName: "password"
            ), "test-password"
        )
        XCTAssertThrowsError(try ResourceSecretPreparation.verifiedPlaintext(
            encrypted, snapshot: snapshot, storedResourceType: "institution",
            resourceID: bank, fieldName: "username"
        ))
        XCTAssertThrowsError(try ResourceSecretPreparation.verifiedPlaintext(
            encrypted, snapshot: snapshot, storedResourceType: "institution",
            resourceID: UUID(), fieldName: "password"
        ))
    }

    func testLockedFieldsSkipEntireResourceInsteadOfStagingLiteralCiphertext() throws {
        let snapshot = snapshot()
        let institution = Institution(
            userId: owner, companyId: UUID(), name: "Test Bank",
            username: "readable-user", password: "enc:not-a-readable-legacy-envelope"
        )
        var collection = ResourceSecretCandidateCollection()
        collection.append {
            try ResourceSecretPreparation.candidate(for: institution, snapshot: snapshot)
        }
        XCTAssertTrue(collection.candidates.isEmpty)
        XCTAssertEqual(collection.skippedLockedRecords, 1)
        XCTAssertEqual(collection.failedRecords, 0)
    }

    func testBankAccountNumbersAreBoundToAccountIdentityWithoutMetadata() throws {
        let snapshot = snapshot()
        let account = InstitutionAccount(
            id: "account-1", name: "Checking", accountNumber: "12345678",
            routingNumber: "021000021"
        )
        let institution = Institution(
            id: bank, userId: owner, companyId: UUID(), name: "Test Bank",
            accounts: [account]
        )
        let candidate = try XCTUnwrap(ResourceSecretPreparation.candidate(
            for: institution, snapshot: snapshot
        ))
        let json = try XCTUnwrap(candidate.plaintextFields["accounts_data"])
        XCTAssertEqual(candidate.resourceType, "institution")
        XCTAssertEqual(candidate.resourceID, bank)
        XCTAssertTrue(json.contains("account-1"))
        XCTAssertTrue(json.contains("12345678"))
        XCTAssertFalse(json.contains("Checking"))
        XCTAssertFalse(json.contains("Test Bank"))
    }
}
