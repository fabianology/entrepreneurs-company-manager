import Foundation
import Observation
import StoreKit
import Supabase

@MainActor
@Observable
final class AccessController {
    private(set) var snapshot: AccessSnapshot
    var pendingGate: PremiumGate?
    var isLoading = false
    var lastError: String?

    private let cacheKey = "miloom.access-snapshot.v1"
    private let offlineProWindow: TimeInterval = 72 * 60 * 60
    private var debugOverrideActive = false

    init() {
        #if DEBUG
        if let debugSnapshot = Self.debugSnapshotFromLaunchArguments() {
            snapshot = debugSnapshot
            debugOverrideActive = true
            return
        }
        #endif
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode(AccessSnapshot.self, from: data),
           Date().timeIntervalSince(cached.validatedAt) <= offlineProWindow {
            snapshot = cached
        } else {
            snapshot = .free
        }
    }

    var isPro: Bool { snapshot.hasProAccess }

    func requiresDowngradeSelection(appState: AppState) -> Bool {
        guard snapshot.productId != nil,
              snapshot.status == .grace || snapshot.status == .expired || snapshot.status == .revoked else { return false }
        return (appState.companies.count > 1 && snapshot.selectedFreeCompanyId == nil)
            || (appState.plaidItems.filter { $0.status == "active" }.count > 1 && snapshot.selectedFreePlaidItemId == nil)
    }

    var membershipSubtitle: String {
        switch snapshot.status {
        case .trial:
            return "Miloom Pro Trial — \(snapshot.trialDaysRemaining ?? 0) days remaining"
        case .active where isPro:
            return "Miloom Pro — Manage Subscription"
        case .grace where isPro:
            return "Action required to keep Pro active"
        default:
            return "See every connection. Stay ahead of every detail."
        }
    }

    func refresh() async {
        #if DEBUG
        if debugOverrideActive { return }
        #endif
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            var fetched: AccessSnapshot = try await SupabaseService.shared.client
                .rpc("get_miloom_access_snapshot")
                .execute()
                .value
            fetched.validatedAt = Date()
            apply(fetched)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            await refreshFromStoreKitIfNeeded()
        }
    }

    func refreshFromStoreKitIfNeeded() async {
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil,
                  ["com.miloom.premium.monthly", "com.miloom.premium.yearly"].contains(transaction.productID),
                  transaction.expirationDate.map({ $0 > Date() }) ?? true else { continue }
            applyLocallyVerified(
                productID: transaction.productID,
                expirationDate: transaction.expirationDate,
                isTrial: false // The server snapshot is authoritative for introductory-offer status.
            )
            return
        }
    }

    func applyLocallyVerified(productID: String, expirationDate: Date?, isTrial: Bool) {
        apply(AccessSnapshot(
            tier: .pro,
            status: isTrial ? .trial : .active,
            productId: productID,
            trialEndsAt: isTrial ? expirationDate : nil,
            renewsAt: expirationDate,
            limits: .pro
        ))
    }

    func applyServerVerified(_ verifiedSnapshot: AccessSnapshot) {
        var snapshot = verifiedSnapshot
        snapshot.validatedAt = Date()
        apply(snapshot)
    }

    func request(_ feature: PremiumFeature, source: String, appState: AppState, userId: UUID?) -> Bool {
        guard permits(feature, appState: appState, userId: userId) else {
            pendingGate = PremiumGate(feature: feature, source: source)
            return false
        }
        return true
    }

    func permits(_ feature: PremiumFeature, appState: AppState, userId: UUID?) -> Bool {
        if isPro {
            switch feature {
            case .plaidConnection:
                return connectedPlaidCount(in: appState) < snapshot.limits.plaidItems
            case .documentUpload:
                return appState.documents.filter { !($0.url ?? "").isEmpty }.count < snapshot.limits.documents
            case .aiAction:
                return snapshot.aiActions < snapshot.limits.aiActions
            case .liveVoice:
                return snapshot.voiceSeconds < snapshot.limits.voiceSeconds
            default:
                return true
            }
        }

        switch feature {
        case .additionalCompany:
            guard let userId else { return appState.companies.isEmpty }
            return appState.companies.filter { $0.userId == userId }.count < snapshot.limits.companies
        case .plaidConnection:
            return connectedPlaidCount(in: appState) < snapshot.limits.plaidItems
        case .documentUpload:
            return appState.documents.filter { !($0.url ?? "").isEmpty }.count < snapshot.limits.documents
        case .aiAction:
            return snapshot.aiActions < snapshot.limits.aiActions
        case .liveVoice:
            return snapshot.voiceSeconds < snapshot.limits.voiceSeconds
        case .guestCollaboration, .connectedPortfolio, .ownerBriefing:
            return false
        }
    }

    func consume(_ feature: PremiumFeature, amount: Int = 1) async -> Bool {
        let kind: String
        switch feature {
        case .aiAction: kind = "ai_actions"
        case .liveVoice: kind = "voice_seconds"
        default: return true
        }

        struct Params: Encodable {
            let pKind: String
            let pAmount: Int
            enum CodingKeys: String, CodingKey {
                case pKind = "p_kind"
                case pAmount = "p_amount"
            }
        }

        do {
            let decision: UsageDecision = try await SupabaseService.shared.client
                .rpc("consume_miloom_usage", params: Params(pKind: kind, pAmount: amount))
                .execute()
                .value
            if decision.allowed {
                if feature == .aiAction { snapshot.aiActions = decision.used }
                if feature == .liveVoice { snapshot.voiceSeconds = decision.used }
                cache()
            }
            return decision.allowed
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func selectFreeResources(companyId: UUID, plaidItemId: UUID?) async throws {
        struct Params: Encodable {
            let companyId: UUID
            let plaidItemId: UUID?
            enum CodingKeys: String, CodingKey {
                case companyId = "p_company_id"
                case plaidItemId = "p_plaid_item_id"
            }
        }
        try await SupabaseService.shared.client
            .rpc("select_miloom_free_resources", params: Params(companyId: companyId, plaidItemId: plaidItemId))
            .execute()
        snapshot.selectedFreeCompanyId = companyId
        snapshot.selectedFreePlaidItemId = plaidItemId
        cache()
    }

    private func connectedPlaidCount(in appState: AppState) -> Int {
        appState.institutions.filter {
            $0.username == "plaid-connected" || $0.accounts.contains { !$0.id.isEmpty && !$0.last4.isEmpty }
        }.count
    }

    private func apply(_ newSnapshot: AccessSnapshot) {
        snapshot = newSnapshot
        cache()
    }

    private func cache() {
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    #if DEBUG
    private static func debugSnapshotFromLaunchArguments() -> AccessSnapshot? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-MiloomEntitlementState"), arguments.indices.contains(index + 1) else {
            // Debug builds are permanently unlocked by default so day-to-day feature
            // development never depends on StoreKit or a server entitlement.
            return debugProSnapshot
        }
        switch arguments[index + 1].lowercased() {
        case "trial":
            return AccessSnapshot(tier: .pro, status: .trial, productId: "debug", trialEndsAt: Date().addingTimeInterval(9 * 86_400), limits: .pro)
        case "pro", "active":
            return debugProSnapshot
        case "expired":
            return AccessSnapshot(tier: .free, status: .expired, productId: "debug", limits: .free)
        case "free":
            return .free
        case "server", "storekit", "real":
            return nil
        default:
            return debugProSnapshot
        }
    }

    private static var debugProSnapshot: AccessSnapshot {
        AccessSnapshot(
            tier: .pro,
            status: .active,
            productId: "debug-unlocked",
            limits: .pro
        )
    }
    #endif
}
