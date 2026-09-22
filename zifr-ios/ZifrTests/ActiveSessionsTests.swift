import XCTest
import SwiftUI
import CryptoKit
@testable import Zifr

final class ActiveSessionsTests: XCTestCase {
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
}
