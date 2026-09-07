import XCTest
@testable import Zifr

final class BusinessExpenseTests: XCTestCase {
    func testMixedUseUsesDecimalAndCurrencyPrecision() {
        XCTAssertEqual(BusinessExpensePolicy.businessAmount(Decimal(string: "59.99")!, basisPoints: 6000, currency: "USD"), Decimal(string: "35.99"))
        XCTAssertEqual(BusinessExpensePolicy.businessAmount(100, basisPoints: 6000, currency: "USD"), 60)
        XCTAssertEqual(BusinessExpensePolicy.businessAmount(101, basisPoints: 5000, currency: "JPY"), 51)
    }
    func testCSVProtectsSpreadsheetFormulaAndQuotes() {
        XCTAssertEqual(BusinessExpensePolicy.csvCell("  =HYPERLINK(\"x\")"), "\"'  =HYPERLINK(\"\"x\"\")\"")
        XCTAssertEqual(BusinessExpensePolicy.csvCell("Adobe, Inc.\nSoftware"), "\"Adobe, Inc.\nSoftware\"")
    }
    func testDefaultHistoryStartsPreviousCalendarYear() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 7))!
        let from = BusinessExpensePolicy.defaultStart(now: now, calendar: calendar)
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: from), DateComponents(year: 2025, month: 1, day: 1))
    }
    func testReadinessAndExportAreIndependentOfConfirmation() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","transaction_id":null,"decision":"confirmed","source_state":"disconnected","revision":3,"updated_at":"2026-09-07","source":{"merchant":"Adobe","date":"2026-09-01","amount":100,"currency":"USD","account_name":"Personal Chase","institution_name":"Chase"},"allocation":{"company_id":"00000000-0000-0000-0000-000000000002","business_basis_points":6000,"purpose":"Design","category":"Software","receipt_exception":"Receipt unavailable","context":"","notes":"","treatment":"undetermined","professional_status":"not_requested"},"suggestions":[],"documents":[],"missing":[],"exported_revision":2}
        """
        var review = try JSONDecoder().decode(BusinessExpenseReview.self, from: Data(json.utf8))
        XCTAssertTrue(review.isReady); XCTAssertTrue(review.changedSinceExport)
        XCTAssertEqual(review.businessAmount, 60)
        review.missing = ["Receipt or missing-receipt explanation"]
        XCTAssertFalse(review.isReady); XCTAssertTrue(BusinessExpenseFilter.confirmed.includes(review)); XCTAssertTrue(BusinessExpenseFilter.exported.includes(review))
    }
}
