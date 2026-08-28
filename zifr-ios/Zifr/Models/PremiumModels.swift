import Foundation

enum PremiumTier: String, Codable, Hashable {
    case free
    case pro
}

enum MiloomEntitlementStatus: String, Codable, Hashable {
    case trial
    case active
    case grace
    case expired
    case revoked
}

struct PremiumLimits: Codable, Hashable {
    var companies: Int
    var plaidItems: Int
    var guests: Int
    var documents: Int
    var aiActions: Int
    var voiceSeconds: Int

    enum CodingKeys: String, CodingKey {
        case companies
        case plaidItems = "plaid_items"
        case guests
        case documents
        case aiActions = "ai_actions"
        case voiceSeconds = "voice_seconds"
    }

    static let free = PremiumLimits(
        companies: 1, plaidItems: 1, guests: 0,
        documents: 20, aiActions: 5, voiceSeconds: 300
    )

    static let pro = PremiumLimits(
        companies: -1, plaidItems: 10, guests: 3,
        documents: 500, aiActions: 300, voiceSeconds: 3_600
    )
}

struct AccessSnapshot: Codable, Hashable {
    var tier: PremiumTier
    var status: MiloomEntitlementStatus
    var productId: String?
    var trialEndsAt: Date?
    var renewsAt: Date?
    var graceEndsAt: Date?
    var selectedFreeCompanyId: UUID?
    var selectedFreePlaidItemId: UUID?
    var aiActions: Int
    var voiceSeconds: Int
    var limits: PremiumLimits
    var validatedAt: Date

    enum CodingKeys: String, CodingKey {
        case tier
        case status
        case productId = "product_id"
        case trialEndsAt = "trial_ends_at"
        case renewsAt = "renews_at"
        case graceEndsAt = "grace_ends_at"
        case selectedFreeCompanyId = "selected_free_company_id"
        case selectedFreePlaidItemId = "selected_free_plaid_item_id"
        case aiActions = "ai_actions"
        case voiceSeconds = "voice_seconds"
        case limits
        case validatedAt = "validated_at"
    }

    init(
        tier: PremiumTier,
        status: MiloomEntitlementStatus,
        productId: String? = nil,
        trialEndsAt: Date? = nil,
        renewsAt: Date? = nil,
        graceEndsAt: Date? = nil,
        selectedFreeCompanyId: UUID? = nil,
        selectedFreePlaidItemId: UUID? = nil,
        aiActions: Int = 0,
        voiceSeconds: Int = 0,
        limits: PremiumLimits,
        validatedAt: Date = Date()
    ) {
        self.tier = tier
        self.status = status
        self.productId = productId
        self.trialEndsAt = trialEndsAt
        self.renewsAt = renewsAt
        self.graceEndsAt = graceEndsAt
        self.selectedFreeCompanyId = selectedFreeCompanyId
        self.selectedFreePlaidItemId = selectedFreePlaidItemId
        self.aiActions = aiActions
        self.voiceSeconds = voiceSeconds
        self.limits = limits
        self.validatedAt = validatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tier = try container.decodeIfPresent(PremiumTier.self, forKey: .tier) ?? .free
        status = try container.decodeIfPresent(MiloomEntitlementStatus.self, forKey: .status) ?? .expired
        productId = try container.decodeIfPresent(String.self, forKey: .productId)
        trialEndsAt = try container.decodeIfPresent(Date.self, forKey: .trialEndsAt)
        renewsAt = try container.decodeIfPresent(Date.self, forKey: .renewsAt)
        graceEndsAt = try container.decodeIfPresent(Date.self, forKey: .graceEndsAt)
        selectedFreeCompanyId = try container.decodeIfPresent(UUID.self, forKey: .selectedFreeCompanyId)
        selectedFreePlaidItemId = try container.decodeIfPresent(UUID.self, forKey: .selectedFreePlaidItemId)
        aiActions = try container.decodeIfPresent(Int.self, forKey: .aiActions) ?? 0
        voiceSeconds = try container.decodeIfPresent(Int.self, forKey: .voiceSeconds) ?? 0
        limits = try container.decodeIfPresent(PremiumLimits.self, forKey: .limits) ?? (tier == .pro ? .pro : .free)
        validatedAt = try container.decodeIfPresent(Date.self, forKey: .validatedAt) ?? Date()
    }

    static let free = AccessSnapshot(tier: .free, status: .expired, limits: .free)

    var hasProAccess: Bool {
        guard tier == .pro else { return false }
        switch status {
        case .trial, .active:
            return true
        case .grace:
            return graceEndsAt.map { $0 >= Date() } ?? true
        case .expired, .revoked:
            return false
        }
    }

    var trialDaysRemaining: Int? {
        guard status == .trial, let trialEndsAt else { return nil }
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: trialEndsAt).day ?? 0)
    }
}

struct PlaidItemSummary: Identifiable, Codable, Hashable {
    var id: UUID
    var companyId: UUID
    var institutionName: String?
    var status: String

    enum CodingKeys: String, CodingKey {
        case id
        case companyId = "company_id"
        case institutionName = "institution_name"
        case status
    }
}

enum PremiumFeature: String, Identifiable, Codable, Hashable {
    case additionalCompany
    case plaidConnection
    case guestCollaboration
    case aiAction
    case liveVoice
    case documentUpload
    case connectedPortfolio
    case ownerBriefing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .additionalCompany: return "Unlimited Companies"
        case .plaidConnection: return "Connected Financial Portfolio"
        case .guestCollaboration: return "Trusted Guests"
        case .aiAction: return "AI Executive Assistant"
        case .liveVoice: return "Live Voice Assistant"
        case .documentUpload: return "Document Vault"
        case .connectedPortfolio: return "Every Connection"
        case .ownerBriefing: return "Owner Briefing"
        }
    }

    var upgradeReason: String {
        switch self {
        case .additionalCompany:
            return "Free includes one company. Pro connects every business in one portfolio."
        case .plaidConnection:
            return "Free includes one live institution. Pro connects up to ten."
        case .guestCollaboration:
            return "Invite up to three trusted partners, accountants, or assistants with Pro."
        case .aiAction:
            return "You have used this month's Free AI preview. Pro includes generous fair use."
        case .liveVoice:
            return "You have used this month's Free voice preview. Continue with Pro."
        case .documentUpload:
            return "Free includes 20 uploaded documents. Pro expands the vault to 500."
        case .connectedPortfolio:
            return "See what every account, subscription, document, and company connects to."
        case .ownerBriefing:
            return "Know what needs attention across every company before it becomes a problem."
        }
    }
}

struct PremiumGate: Identifiable, Hashable {
    let id = UUID()
    var feature: PremiumFeature
    var source: String
}

enum ResourceKind: String, Codable, CaseIterable, Hashable {
    case company
    case subscription
    case institution
    case card
    case loan
    case document
    case collaborator
}

enum ConnectionRelationship: String, Codable, CaseIterable, Hashable {
    case belongsTo = "belongs_to"
    case paidBy = "paid_by"
    case connectedAccount = "connected_account"
    case usesLogin = "uses_login"
    case documentFor = "document_for"
    case sharedWith = "shared_with"
    case dependsOn = "depends_on"

    var label: String {
        switch self {
        case .belongsTo: return "Belongs to"
        case .paidBy: return "Paid by"
        case .connectedAccount: return "Connected account"
        case .usesLogin: return "Uses login"
        case .documentFor: return "Document for"
        case .sharedWith: return "Shared with"
        case .dependsOn: return "Depends on"
        }
    }
}

enum ConnectionOrigin: String, Codable, Hashable {
    case direct
    case inferred
    case manual
}

enum ConnectionState: String, Codable, Hashable {
    case confirmed
    case suggested
    case rejected
}

struct ResourceReference: Codable, Hashable, Identifiable {
    var kind: ResourceKind
    var resourceId: UUID

    var id: String { "\(kind.rawValue):\(resourceId.uuidString)" }
}

struct ResourceConnection: Identifiable, Codable, Hashable {
    var id: UUID
    var ownerUserId: UUID
    var sourceType: ResourceKind
    var sourceId: UUID
    var targetType: ResourceKind
    var targetId: UUID
    var relationshipType: ConnectionRelationship
    var origin: ConnectionOrigin
    var confidence: Double
    var state: ConnectionState
    var inferenceKey: String?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserId = "owner_user_id"
        case sourceType = "source_type"
        case sourceId = "source_id"
        case targetType = "target_type"
        case targetId = "target_id"
        case relationshipType = "relationship_type"
        case origin
        case confidence
        case state
        case inferenceKey = "inference_key"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID = UUID(), ownerUserId: UUID,
        sourceType: ResourceKind, sourceId: UUID,
        targetType: ResourceKind, targetId: UUID,
        relationshipType: ConnectionRelationship,
        origin: ConnectionOrigin, confidence: Double,
        state: ConnectionState, inferenceKey: String? = nil,
        createdAt: Date = Date(), updatedAt: Date = Date()
    ) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.sourceType = sourceType
        self.sourceId = sourceId
        self.targetType = targetType
        self.targetId = targetId
        self.relationshipType = relationshipType
        self.origin = origin
        self.confidence = confidence
        self.state = state
        self.inferenceKey = inferenceKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var source: ResourceReference { ResourceReference(kind: sourceType, resourceId: sourceId) }
    var target: ResourceReference { ResourceReference(kind: targetType, resourceId: targetId) }
}

enum ObligationSeverity: String, Codable, Hashable {
    case info
    case attention
    case urgent
}

enum ObligationState: String, Codable, Hashable {
    case open
    case deferred = "snoozed"
    case handled
    case dismissed
}

struct PortfolioObligation: Identifiable, Codable, Hashable {
    var id: UUID
    var ownerUserId: UUID
    var companyId: UUID?
    var sourceType: ResourceKind
    var sourceId: UUID
    var kind: String
    var dueAt: Date?
    var severity: ObligationSeverity
    var title: String
    var summary: String
    var actionType: String
    var state: ObligationState
    var deferredAt: Date? = nil
    var snoozedUntil: Date?
    var fingerprint: String
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserId = "owner_user_id"
        case companyId = "company_id"
        case sourceType = "source_type"
        case sourceId = "source_id"
        case kind
        case dueAt = "due_at"
        case severity
        case title
        case summary
        case actionType = "action_type"
        case state
        case deferredAt = "deferred_at"
        case snoozedUntil = "snoozed_until"
        case fingerprint
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum OwnerBriefingTab: String, CaseIterable, Hashable {
    case current
    case completeLater
}

enum BriefingResourceCategory: String, CaseIterable, Identifiable, Hashable {
    case company
    case subscription
    case institution
    case card
    case loan
    case document
    case collaborator
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .company: return "Companies"
        case .subscription: return "Subscriptions"
        case .institution: return "Institutions"
        case .card: return "Cards"
        case .loan: return "Loans"
        case .document: return "Documents"
        case .collaborator: return "Collaborators"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .company: return "building.2.fill"
        case .subscription: return "arrow.triangle.2.circlepath"
        case .institution: return "building.columns.fill"
        case .card: return "creditcard.fill"
        case .loan: return "banknote.fill"
        case .document: return "doc.fill"
        case .collaborator: return "person.2.fill"
        case .other: return "exclamationmark.circle.fill"
        }
    }

    static func category(for sourceType: ResourceKind) -> BriefingResourceCategory {
        switch sourceType {
        case .company: return .company
        case .subscription: return .subscription
        case .institution: return .institution
        case .card: return .card
        case .loan: return .loan
        case .document: return .document
        case .collaborator: return .collaborator
        }
    }
}

enum DeferredAgeBucket: String, CaseIterable, Identifiable, Hashable {
    case zeroToSeven
    case eightToFourteen
    case fifteenToThirty
    case thirtyOnePlus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .zeroToSeven: return "0–7 Days"
        case .eightToFourteen: return "8–14 Days"
        case .fifteenToThirty: return "15–30 Days"
        case .thirtyOnePlus: return "31+ Days"
        }
    }

    static func bucket(deferredAt: Date, now: Date) -> DeferredAgeBucket {
        let elapsed = max(0, now.timeIntervalSince(deferredAt))
        let wholeDays = Int(floor(elapsed / 86_400))
        switch wholeDays {
        case ...7: return .zeroToSeven
        case 8...14: return .eightToFourteen
        case 15...30: return .fifteenToThirty
        default: return .thirtyOnePlus
        }
    }
}

enum OwnerBriefingPresentation {
    static func activeObligations(in obligations: [PortfolioObligation]) -> [PortfolioObligation] {
        obligations.filter { $0.state == .open }
    }

    static func deferredObligations(in obligations: [PortfolioObligation]) -> [PortfolioObligation] {
        obligations.filter { $0.state == .deferred }
    }

    static func effectiveDeferredAt(for obligation: PortfolioObligation) -> Date {
        if let deferredAt = obligation.deferredAt { return deferredAt }
        if let snoozedUntil = obligation.snoozedUntil {
            return snoozedUntil.addingTimeInterval(-7 * 86_400)
        }
        return obligation.updatedAt
    }

    static func deferring(_ obligation: PortfolioObligation, at date: Date) -> PortfolioObligation {
        var updated = obligation
        updated.state = .deferred
        updated.deferredAt = date
        updated.snoozedUntil = date.addingTimeInterval(7 * 86_400)
        updated.updatedAt = date
        return updated
    }

    static func settingState(
        _ obligation: PortfolioObligation,
        to state: ObligationState,
        at date: Date
    ) -> PortfolioObligation {
        var updated = obligation
        updated.state = state
        updated.updatedAt = date
        return updated
    }

    static func restoringLifecycle(
        of obligation: PortfolioObligation,
        from original: PortfolioObligation,
        at date: Date
    ) -> PortfolioObligation {
        var updated = obligation
        updated.state = original.state
        updated.deferredAt = original.deferredAt
        updated.snoozedUntil = original.snoozedUntil
        updated.updatedAt = date
        return updated
    }

    static func dateLabel(for date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "MMMM d yyyy"
        return formatter.string(from: date)
    }
}

struct UsageDecision: Codable {
    var allowed: Bool
    var used: Int
    var limit: Int
}
