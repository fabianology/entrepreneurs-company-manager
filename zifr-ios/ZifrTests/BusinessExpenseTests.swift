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
    func testVaultReceiptUsesPurchaseDateAndExpenseCategoryWithSourceSearch() {
        let owner = UUID(), business = UUID(), personal = UUID()
        let receipt = CompanyDocument(userId: owner, companyId: business, name: "scan.pdf", type: "Receipts", uploadDate: "2026-09-07")
        let source = BusinessExpenseSource(merchant: "Design Software", date: "2025-12-20", amount: 100, currency: "USD", sourceAccountId: "personal-card", canonicalAccountId: nil, sourceCompanyId: personal, accountName: "Personal Visa", institutionName: "QA Bank")
        let review = BusinessExpenseReview(id: UUID(), transactionId: UUID(), decision: "confirmed", sourceState: "active", source: source, revision: 1, updatedAt: "2026-09-07", allocation: BusinessExpenseAllocation(companyId: business, businessBasisPoints: 6000, category: "Software"), suggestions: [], documents: [BusinessExpenseDocument(id: receipt.id, name: receipt.name, path: "private/scan.pdf")], missing: [], exportedRevision: nil)
        let item = ReceiptVaultItem.items(documents: [receipt], reviews: [review])[0]
        XCTAssertEqual(item.year, "2025")
        XCTAssertEqual(item.month, "2025-12")
        XCTAssertEqual(item.category, "Software")
        XCTAssertEqual(item.document.companyId, business)
        XCTAssertEqual(item.review?.source.sourceCompanyId, personal)
        XCTAssertEqual(item.review?.businessAmount, 60)
        XCTAssertTrue(item.matches("personal visa"))
        XCTAssertTrue(item.matches(" SOFTWARE "))
        XCTAssertFalse(item.matches("Travel"))
    }

    func testVaultKeepsStandaloneAndUndatedReceiptsWithoutInventingClassification() {
        let owner = UUID(), company = UUID()
        let old = CompanyDocument(userId: owner, companyId: company, type: "Receipt", uploadDate: "2024-01-01")
        let recent = CompanyDocument(userId: owner, companyId: company, type: "Receipts", uploadDate: "2026-09-07T12:00:00Z")
        let undated = CompanyDocument(userId: owner, companyId: company, type: "Receipts")
        let other = CompanyDocument(userId: owner, companyId: company, type: "Taxes")
        let items = ReceiptVaultItem.items(documents: [undated, old, other, recent], reviews: [])
        XCTAssertEqual(items.map(\.id), [recent.id, old.id, undated.id])
        XCTAssertEqual(items.first?.month, "2026-09")
        XCTAssertEqual(items.last?.month, "Undated")
        XCTAssertTrue(items.allSatisfy { $0.review == nil && $0.category == "Uncategorized" })
    }

}
