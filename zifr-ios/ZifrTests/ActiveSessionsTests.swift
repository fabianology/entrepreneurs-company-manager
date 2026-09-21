import XCTest
import SwiftUI
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
