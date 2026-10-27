import Foundation
import CryptoKit
import Security

/// Last successful server response, before credential decryption. Shared records
/// are deliberately excluded: access to somebody else's data must be rechecked.
struct PortfolioSnapshot: Codable {
    static let maximumAge: TimeInterval = 7 * 24 * 60 * 60
    let version: Int
    let userID: UUID
    let savedAt: Date
    let companies: [Company]
    let subscriptions: [Subscription]
    let institutions: [Institution]
    let cards: [FinancialCard]
    let storedLoans: [StoredLoan]
    let documents: [CompanyDocument]

    // Loan's server encoder omits its ledger; preserve it separately so restoring
    // a revision can never produce an incomplete, writable loan snapshot.
    struct StoredLoan: Codable {
        let record: Loan
        let payments: [LoanPayment]?
        var value: Loan {
            var loan = record
            loan.payments = payments
            return loan
        }
    }
    var loans: [Loan] { storedLoans.map(\.value) }

    init(userID: UUID, savedAt: Date = Date(), companies: [Company],
         subscriptions: [Subscription], institutions: [Institution], cards: [FinancialCard],
         loans: [Loan], documents: [CompanyDocument]) {
        version = 1
        self.userID = userID
        self.savedAt = savedAt
        self.companies = companies.filter { $0.userId == userID }
        let companyIDs = Set(self.companies.map(\.id))
        self.subscriptions = subscriptions.filter { $0.userId == userID && companyIDs.contains($0.companyId) }
        self.institutions = institutions.filter { $0.userId == userID && companyIDs.contains($0.companyId) }
        self.cards = cards.filter { $0.userId == userID && companyIDs.contains($0.companyId) }
        storedLoans = loans.filter { $0.userId == userID && companyIDs.contains($0.companyId) }
            .map { StoredLoan(record: $0, payments: $0.payments) }
        self.documents = documents.filter { $0.userId == userID && companyIDs.contains($0.companyId) }
    }

    func isValid(for userID: UUID, now: Date) -> Bool {
        guard version == 1, self.userID == userID,
              now.timeIntervalSince(savedAt) >= -300,
              now.timeIntervalSince(savedAt) <= Self.maximumAge else { return false }
        let companyIDs = Set(companies.map(\.id))
        return companies.allSatisfy { $0.userId == userID }
            && subscriptions.allSatisfy { $0.userId == userID && companyIDs.contains($0.companyId) }
            && institutions.allSatisfy { $0.userId == userID && companyIDs.contains($0.companyId) }
            && cards.allSatisfy { $0.userId == userID && companyIDs.contains($0.companyId) }
            && storedLoans.allSatisfy { $0.record.userId == userID && companyIDs.contains($0.record.companyId) }
            && documents.allSatisfy { $0.userId == userID && companyIDs.contains($0.companyId) }
    }
}

/// All disk/crypto work is serialized off the main actor. A per-account Keychain
/// key and authenticated account ID prevent snapshots crossing account boundaries.
actor PortfolioCache {
    static let shared = PortfolioCache()
    private let directory: URL
    private let key: @Sendable (UUID, Bool) throws -> SymmetricKey?
    private let deleteKey: @Sendable (UUID) -> Void
    private var generations: [UUID: UUID] = [:]

    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PortfolioCache-v1", isDirectory: true),
         key: @escaping @Sendable (UUID, Bool) throws -> SymmetricKey? = { userID, create in
             try PortfolioCacheKeyStore.key(for: userID, create: create)
         },
         deleteKey: @escaping @Sendable (UUID) -> Void = { PortfolioCacheKeyStore.remove(for: $0) }) {
        self.directory = directory
        self.key = key
        self.deleteKey = deleteKey
    }

    func generation(for userID: UUID) -> UUID {
        if let generation = generations[userID] { return generation }
        let generation = UUID()
        generations[userID] = generation
        return generation
    }

    func fileURL(for userID: UUID) -> URL {
        directory.appendingPathComponent(userID.uuidString).appendingPathExtension("encrypted")
    }

    private func context(for userID: UUID) -> Data {
        Data("miloom.portfolio.v1|\(userID.uuidString)".utf8)
    }

    func load(for userID: UUID, now: Date = Date()) throws -> PortfolioSnapshot? {
        let url = fileURL(for: userID)
        guard FileManager.default.fileExists(atPath: url.path),
              let key = try key(userID, false) else { return nil }
        let sealed = try AES.GCM.SealedBox(combined: Data(contentsOf: url))
        let data = try AES.GCM.open(sealed, using: key, authenticating: context(for: userID))
        let snapshot = try JSONDecoder().decode(PortfolioSnapshot.self, from: data)
        guard snapshot.isValid(for: userID, now: now) else { return nil }
        return snapshot
    }

    @discardableResult
    func save(_ snapshot: PortfolioSnapshot, generation: UUID) throws -> Bool {
        guard generations[snapshot.userID] == generation,
              let key = try key(snapshot.userID, true) else { return false }
        let data = try JSONEncoder().encode(snapshot)
        let sealed = try AES.GCM.seal(data, using: key, authenticating: context(for: snapshot.userID))
        guard let encrypted = sealed.combined else { return false }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.protectionKey: FileProtectionType.complete])
        var excludedDirectory = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try excludedDirectory.setResourceValues(values)
        try encrypted.write(to: fileURL(for: snapshot.userID), options: [.atomic, .completeFileProtection])
        return true
    }

    func remove(for userID: UUID) {
        // Reject a delayed pre-sign-out save even if it reaches this actor later.
        generations[userID] = UUID()
        try? FileManager.default.removeItem(at: fileURL(for: userID))
        deleteKey(userID)
    }
}

private enum PortfolioCacheKeyStore {
    static var service: String { (Bundle.main.bundleIdentifier ?? "com.vibing.miloom") + ".portfolio-cache.v1" }

    static func query(_ userID: UUID) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: userID.uuidString]
    }

    static func key(for userID: UUID, create: Bool) throws -> SymmetricKey? {
        var read = query(userID)
        read[kSecReturnData as String] = true
        read[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(read as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data { return SymmetricKey(data: data) }
        guard status == errSecItemNotFound else { throw failure(status) }
        guard create else { return nil }
        let key = SymmetricKey(size: .bits256)
        var write = query(userID)
        write[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        write[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let added = SecItemAdd(write as CFDictionary, nil)
        if added == errSecDuplicateItem { return try self.key(for: userID, create: false) }
        guard added == errSecSuccess else { throw failure(added) }
        return key
    }

    static func remove(for userID: UUID) { SecItemDelete(query(userID) as CFDictionary) }

    static func failure(_ status: OSStatus) -> NSError {
        NSError(domain: "PortfolioCacheKeychain", code: Int(status))
    }
}
