import Foundation
import CryptoKit
import Security

/// Persist owner cards independently so a failed detail request cannot leave
/// the next launch without a company list. Shared access is rechecked online.
enum CompanyCardSection: Hashable { case financial, services, documents }

struct CompanyCardCounts: Codable, Equatable {
    var financial = 0
    var services = 0
    var documents = 0

    subscript(section: CompanyCardSection) -> Int {
        switch section {
        case .financial: return financial
        case .services: return services
        case .documents: return documents
        }
    }

    static func owned(companies: [Company], userID: UUID, institutions: [Institution],
                      services: [Subscription], documents: [CompanyDocument]) -> [UUID: Self] {
        var result = Dictionary(uniqueKeysWithValues: companies.filter { $0.userId == userID }.map { ($0.id, Self()) })
        // A mixed-owner total would disclose shared records after access changes.
        for row in institutions {
            if row.userId == userID { result[row.companyId]?.financial += 1 }
            else { result.removeValue(forKey: row.companyId) }
        }
        for row in services {
            if row.userId == userID { result[row.companyId]?.services += 1 }
            else { result.removeValue(forKey: row.companyId) }
        }
        for row in documents {
            if row.userId == userID { result[row.companyId]?.documents += 1 }
            else { result.removeValue(forKey: row.companyId) }
        }
        return result
    }
}

private struct SavedCardCounts: Codable {
    let savedAt: Date
    let totals: [UUID: CompanyCardCounts]
}

private struct SavedCompanyList: Codable {
    let userID: UUID
    static let maximumAge: TimeInterval = 7 * 24 * 60 * 60
    let savedAt: Date
    let companies: [Company]
}

enum CompanyCacheFile: String {
    case companies
    case logos
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

    private func companyListURL(for userID: UUID, file: CompanyCacheFile) -> URL {
        directory.appendingPathComponent(userID.uuidString + "." + file.rawValue + ".encrypted")
    }

    func loadCompanies(for userID: UUID, file: CompanyCacheFile = .companies, now: Date = Date()) throws -> [Company]? {
        guard let list: SavedCompanyList = try read(userID, url: companyListURL(for: userID, file: file), domain: file.rawValue),
              list.userID == userID, (-300...SavedCompanyList.maximumAge).contains(now.timeIntervalSince(list.savedAt)),
              list.companies.allSatisfy({ $0.userId == userID }) else { return nil }
        return list.companies
    }

    func saveCompanies(_ companies: [Company], for userID: UUID, generation: UUID, file: CompanyCacheFile = .companies) throws {
        let list = SavedCompanyList(userID: userID, savedAt: Date(), companies: companies.filter { $0.userId == userID })
        _ = try write(list, for: userID, generation: generation, url: companyListURL(for: userID, file: file), domain: file.rawValue)
    }

    private func countsURL(_ userID: UUID) -> URL {
        directory.appendingPathComponent(userID.uuidString + ".counts.encrypted")
    }

    func loadCardCounts(for userID: UUID, now: Date = Date()) throws -> [UUID: CompanyCardCounts]? {
        guard let saved: SavedCardCounts = try read(userID, url: countsURL(userID), domain: "counts"),
              (-300...SavedCompanyList.maximumAge).contains(now.timeIntervalSince(saved.savedAt)) else { return nil }
        return saved.totals
    }

    func saveCardCounts(_ totals: [UUID: CompanyCardCounts], for userID: UUID, generation: UUID) throws {
        _ = try write(SavedCardCounts(savedAt: Date(), totals: totals), for: userID, generation: generation,
                      url: countsURL(userID), domain: "counts")
    }

    private func context(_ domain: String, userID: UUID) -> Data {
        Data("miloom.\(domain).v1|\(userID.uuidString)".utf8)
    }

    private func read<T: Decodable>(_ userID: UUID, url: URL, domain: String) throws -> T? {
        guard FileManager.default.fileExists(atPath: url.path),
              let key = try key(userID, false) else { return nil }
        let sealed = try AES.GCM.SealedBox(combined: Data(contentsOf: url))
        let data = try AES.GCM.open(sealed, using: key, authenticating: context(domain, userID: userID))
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func write<T: Encodable>(_ value: T, for userID: UUID, generation: UUID, url: URL, domain: String) throws -> Bool {
        guard generations[userID] == generation,
              let key = try key(userID, true) else { return false }
        let data = try JSONEncoder().encode(value)
        let sealed = try AES.GCM.seal(data, using: key, authenticating: context(domain, userID: userID))
        guard let encrypted = sealed.combined else { return false }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.protectionKey: FileProtectionType.complete])
        var excludedDirectory = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try excludedDirectory.setResourceValues(values)
        try encrypted.write(to: url, options: [.atomic, .completeFileProtection])
        return true
    }

    func remove(for userID: UUID) {
        // Reject a delayed pre-sign-out save even if it reaches this actor later.
        generations[userID] = UUID()
        try? FileManager.default.removeItem(at: companyListURL(for: userID, file: .companies))
        try? FileManager.default.removeItem(at: companyListURL(for: userID, file: .logos))
        try? FileManager.default.removeItem(at: countsURL(userID))
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
