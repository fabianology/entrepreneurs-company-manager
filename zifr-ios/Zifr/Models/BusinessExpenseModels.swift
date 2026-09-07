import Foundation

struct BusinessExpenseSource: Codable, Equatable {
    var merchant: String
    var date: String
    var amount: Decimal?
    var currency: String?
    var sourceAccountId: String?
    var canonicalAccountId: String?
    var sourceCompanyId: UUID?
    var accountName: String
    var institutionName: String
    enum CodingKeys: String, CodingKey {
        case merchant, date, amount, currency
        case sourceAccountId = "source_account_id", canonicalAccountId = "canonical_account_id"
        case sourceCompanyId = "source_company_id", accountName = "account_name", institutionName = "institution_name"
    }
}

struct BusinessExpenseAllocation: Codable, Equatable {
    var companyId: UUID
    var businessBasisPoints: Int = 10_000
    var purpose: String = ""
    var category: String = ""
    var receiptException: String = ""
    var context: String = ""
    var notes: String = ""
    var treatment: String = "undetermined"
    var professionalStatus: String = "not_requested"
    enum CodingKeys: String, CodingKey {
        case companyId = "company_id", businessBasisPoints = "business_basis_points"
        case purpose, category, context, notes, treatment
        case receiptException = "receipt_exception", professionalStatus = "professional_status"
    }
}

struct BusinessExpenseSuggestion: Codable, Identifiable, Equatable {
    var id: UUID
    var companyId: UUID
    var score: Decimal
    var confidence: String
    var explanation: String
    enum CodingKeys: String, CodingKey {
        case id, score, confidence, explanation
        case companyId = "company_id"
    }
}

struct BusinessExpenseDocument: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var path: String
}

struct BusinessExpenseReview: Codable, Identifiable, Equatable {
    var id: UUID
    var transactionId: UUID?
    var decision: String
    var origin: String? = nil
    var sourceState: String
    var source: BusinessExpenseSource
    var revision: Int
    var updatedAt: String
    var allocation: BusinessExpenseAllocation?
    var suggestions: [BusinessExpenseSuggestion]
    var documents: [BusinessExpenseDocument]
    var missing: [String]
    var exportedRevision: Int?
    enum CodingKeys: String, CodingKey {
        case id, decision, origin, source, revision, allocation, suggestions, documents, missing
        case transactionId = "transaction_id", sourceState = "source_state", updatedAt = "updated_at", exportedRevision = "exported_revision"
    }
    var isReady: Bool { decision == "confirmed" && missing.isEmpty }
    var changedSinceExport: Bool { exportedRevision.map { $0 < revision } ?? false }
    var businessAmount: Decimal? {
        guard let amount = source.amount, let allocation else { return nil }
        return BusinessExpensePolicy.businessAmount(amount, basisPoints: allocation.businessBasisPoints, currency: source.currency ?? "USD")
    }
    var statusLabel: String {
        if decision == "personal" { return "Personal" }
        if decision == "dismissed" { return "Dismissed" }
        if sourceState == "conflict" { return "Source conflict — needs review" }
        if sourceState == "changed" || sourceState == "removed" { return "Source needs attention" }
        switch decision {
        case "confirmed": return isReady ? "Ready for Tax Professional" : "Confirmed for Business"
        case "personal": return "Personal"
        case "dismissed": return "Dismissed"
        default: return "Worth Reviewing"
        }
    }
    func belongs(to companyId: UUID?) -> Bool {
        guard let companyId else { return true }
        if let allocation { return allocation.companyId == companyId }
        // Ambiguous purchases appear once, in All Entities, until the owner chooses.
        return suggestions.count == 1 && suggestions.first?.companyId == companyId
    }
}

struct BusinessExpenseSettings: Codable {
    var enabled: Bool = false
    var excludedAccountIds: [String] = []
    var revision: Int = 0
    enum CodingKeys: String, CodingKey {
        case enabled, revision
        case excludedAccountIds = "excluded_account_ids"
    }
}
struct BusinessExpenseProfile: Codable, Identifiable {
    var companyId: UUID
    var activity: String
    var enabled: Bool = true
    var id: UUID { companyId }
    enum CodingKeys: String, CodingKey { case companyId = "company_id", activity, enabled }
}
struct BusinessExpenseJob: Codable, Identifiable {
    var id: UUID
    var state: String
    var scanned: Int
    var suggested: Int
    var errorCode: String?
    var dateFrom: String
    var dateTo: String
    enum CodingKeys: String, CodingKey {
        case id, state, scanned, suggested
        case errorCode = "error_code", dateFrom = "date_from", dateTo = "date_to"
    }
    var isActive: Bool { state == "running" || state == "queued" }
}
struct BusinessExpenseExportItem: Codable {
    var reviewId: UUID
    var revision: Int
    var source: BusinessExpenseSource
    var allocation: BusinessExpenseAllocation
    var entityName: String
    var sourceState: String
    var decision: String
    var missing: [String]
    var documents: [BusinessExpenseDocument]
    enum CodingKeys: String, CodingKey {
        case revision, source, allocation, decision, missing, documents
        case reviewId = "review_id", entityName = "entity_name", sourceState = "source_state"
    }
}
struct BusinessExpenseExport: Codable, Identifiable {
    var id: UUID
    var companyId: UUID
    var incomplete: Bool
    var items: [BusinessExpenseExportItem]
    var createdAt: String
    enum CodingKeys: String, CodingKey {
        case id, incomplete, items
        case companyId = "company_id", createdAt = "created_at"
    }
}

enum BusinessExpenseFilter: String, CaseIterable, Identifiable {
    case needsReview = "Needs Review", confirmed = "Confirmed", missing = "Missing Documentation"
    case ready = "Ready for Tax Professional", exported = "Exported", dismissed = "Dismissed / Personal"
    var id: String { rawValue }
    func includes(_ review: BusinessExpenseReview) -> Bool {
        switch self {
        case .needsReview: return (review.decision == "unreviewed" && (review.origin != "ai" || !review.suggestions.isEmpty)) || (review.decision == "confirmed" && ["changed", "removed", "conflict"].contains(review.sourceState))
        case .confirmed: return review.decision == "confirmed"
        case .missing: return review.decision == "confirmed" && !review.missing.isEmpty
        case .ready: return review.isReady
        case .exported: return review.exportedRevision != nil
        case .dismissed: return ["personal", "dismissed"].contains(review.decision)
        }
    }
}

enum BusinessExpensePolicy {
    static let disclosure = "Miloom identifies and organizes potential business expenses based on your financial activity and information you provide. It does not determine tax deductibility or provide tax advice. Consult a qualified tax professional regarding your specific tax situation."
    static let categories = ["Software & services", "Office supplies", "Travel", "Meals", "Transportation", "Professional services", "Advertising", "Equipment", "Rent & utilities", "Other"]
    static let treatments = [("undetermined", "Undetermined — ask your accountant"), ("owner_paid", "Owner-paid business expense"), ("reimbursement", "Potential reimbursement"), ("contribution", "Potential owner contribution"), ("other", "Other — see notes")]
    static func defaultStart(now: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: calendar.component(.year, from: now) - 1, month: 1, day: 1)) ?? now
    }
    static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"; return formatter.string(from: date)
    }
    static func businessAmount(_ amount: Decimal, basisPoints: Int, currency: String) -> Decimal {
        let formatter = NumberFormatter(); formatter.numberStyle = .currency; formatter.currencyCode = currency
        let scale = formatter.maximumFractionDigits
        var value = amount * Decimal(basisPoints) / Decimal(10_000)
        var rounded = Decimal(); NSDecimalRound(&rounded, &value, scale, .plain); return rounded
    }
    static func money(_ amount: Decimal?, currency: String?) -> String {
        guard let amount else { return "Amount unavailable" }
        let formatter = NumberFormatter(); formatter.numberStyle = .currency; formatter.currencyCode = currency ?? "USD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
    static func csvCell(_ value: String) -> String {
        // Guard after leading whitespace as Excel may strip it before evaluation.
        let first = value.trimmingCharacters(in: .whitespacesAndNewlines).first
        let safe = first.map { "=+-@".contains($0) } == true ? "'" + value : value
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    static func csv(_ export: BusinessExpenseExport) -> String {
        let headers = ["Review ID", "Revision", "Date", "Merchant", "Currency", "Purchase amount", "Entity", "Category", "Business purpose", "Business-use percent", "Business-use amount", "Payment account", "Institution", "Source status", "Bookkeeping treatment (proposed)", "Receipt references", "Receipt exception", "Context", "Notes", "Review status", "Professional review (owner recorded)", "Missing information", "Disclosure"]
        let rows = export.items.map { item -> [String] in
            let source = item.source, allocation = item.allocation
            let amount = source.amount.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
            let business = source.amount.map { NSDecimalNumber(decimal: businessAmount($0, basisPoints: allocation.businessBasisPoints, currency: source.currency ?? "USD")).stringValue } ?? ""
            return [item.reviewId.uuidString, String(item.revision), source.date, source.merchant, source.currency ?? "", amount, item.entityName, allocation.category, allocation.purpose, NSDecimalNumber(decimal: Decimal(allocation.businessBasisPoints) / 100).stringValue, business, source.accountName, source.institutionName, item.sourceState, allocation.treatment, item.documents.map { "\($0.id.uuidString)-\($0.name)" }.joined(separator: "; "), allocation.receiptException, allocation.context, allocation.notes, item.decision, allocation.professionalStatus, item.missing.joined(separator: "; "), disclosure]
        }
        return ([headers] + rows).map { $0.map(csvCell).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }
}

struct BusinessExpenseAccount: Codable {
    var accountId: String
    var canonicalAccountId: String?
    var persistentAccountId: String?
    var name: String?
    enum CodingKeys: String, CodingKey {
        case accountId = "account_id", canonicalAccountId = "canonical_account_id", persistentAccountId = "persistent_account_id", name
    }
    var exclusionKey: String { persistentAccountId.map { "persistent:" + $0 } ?? canonicalAccountId ?? accountId }
}

// A receipt is one Vault document, enriched by its existing expense review.
struct ReceiptVaultItem: Identifiable {
    let document: CompanyDocument
    let review: BusinessExpenseReview?
    var id: UUID { document.id }
    var merchant: String { review?.source.merchant ?? document.name }
    var category: String {
        let value = review?.allocation?.category.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "Uncategorized" : value
    }
    var date: String { review?.source.date ?? document.uploadDate ?? "" }
    var month: String {
        let prefix = String(date.prefix(10))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard prefix.count == 10, formatter.date(from: prefix) != nil else { return "Undated" }
        return String(prefix.prefix(7))
    }
    var year: String { month == "Undated" ? "Undated" : String(month.prefix(4)) }
    var monthLabel: String {
        guard month != "Undated" else { return "Undated" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let value = formatter.date(from: month + "-01") else { return month }
        formatter.locale = .current
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: value)
    }
    func matches(_ query: String) -> Bool {
        let text = [merchant, document.name, category, document.notes ?? "", review?.source.accountName ?? "", review?.source.institutionName ?? "", review?.allocation?.purpose ?? "", date].joined(separator: " ")
        return query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.localizedCaseInsensitiveContains(query.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    static func items(documents: [CompanyDocument], reviews: [BusinessExpenseReview]) -> [ReceiptVaultItem] {
        let links = reviews.reduce(into: [UUID: BusinessExpenseReview]()) { result, review in
            for document in review.documents { result[document.id] = review }
        }
        return documents.filter { CompanyDocument.normalizeType($0.type) == "Receipts" }
            .map { ReceiptVaultItem(document: $0, review: links[$0.id]) }
            .sorted { lhs, rhs in
                if lhs.month == "Undated" && rhs.month != "Undated" { return false }
                if rhs.month == "Undated" && lhs.month != "Undated" { return true }
                if lhs.date != rhs.date { return lhs.date > rhs.date }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }
}
