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
    var institutionId: UUID?
    var institutionName: String?
    var status: String
    var errorCode: String?
    var lastSyncedAt: Date?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case companyId = "company_id"
        case institutionId = "institution_id"
        case institutionName = "institution_name"
        case status
        case errorCode = "error_code"
        case lastSyncedAt = "last_synced_at"
        case createdAt = "created_at"
    }

    var requiresReconnect: Bool {
        status == "requires_reauth" || errorCode == "ITEM_LOGIN_REQUIRED"
    }

    func isStale(referenceDate: Date = Date()) -> Bool {
        guard status == "active", let lastSyncedAt else { return status == "active" }
        return referenceDate.timeIntervalSince(lastSyncedAt) > 48 * 60 * 60
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

    static func category(for obligation: PortfolioObligation) -> BriefingResourceCategory {
        // A recurring-charge candidate is a subscription blind spot even though
        // its navigation target remains the card or institution where it appeared.
        if obligation.kind == "new_recurring_charge" {
            return .subscription
        }
        return category(for: obligation.sourceType)
    }
}

enum OwnerBriefingScope: String, CaseIterable, Identifiable, Hashable {
    case business = "Business"
    case personal = "Personal"

    var id: String { rawValue }

    func includes(_ company: Company) -> Bool {
        let normalized = company.structure.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isPersonal = normalized == "individual" || normalized == "household"
        return self == .personal ? isPersonal : !isPersonal
    }
}

enum OwnerHealthStatus: String, Hashable {
    case critical
    case needsAttention
    case healthy
    case notApplicable

    var title: String {
        switch self {
        case .critical: return "Critical"
        case .needsAttention: return "Needs Attention"
        case .healthy: return "Healthy"
        case .notApplicable: return "No Data"
        }
    }

    var priority: Int {
        switch self {
        case .critical: return 3
        case .needsAttention: return 2
        case .healthy: return 1
        case .notApplicable: return 0
        }
    }
}

enum OwnerHealthDataState: Hashable {
    case complete
    case moreDataUseful(Int)
    case noData

    var title: String {
        switch self {
        case .complete: return "Data complete"
        case .moreDataUseful(let count):
            return "More data useful for \(count) item\(count == 1 ? "" : "s")"
        case .noData: return "No records added"
        }
    }
}

struct OwnerHealthMetric: Identifiable, Hashable {
    let label: String
    let value: String

    var id: String { "\(label):\(value)" }
}

struct OwnerHealthDataIssue: Identifiable, Hashable {
    let resourceType: ResourceKind
    let resourceID: UUID
    let resourceName: String
    let entityName: String
    let missingFields: [String]

    var id: String {
        let fields = missingFields.sorted().joined(separator: "|")
        return "\(resourceType.rawValue):\(resourceID.uuidString):\(fields)"
    }
}

struct OwnerHealthCategorySummary: Identifiable, Hashable {
    let category: BriefingResourceCategory
    let status: OwnerHealthStatus
    let dataState: OwnerHealthDataState
    let summary: String
    let metrics: [OwnerHealthMetric]
    let affectedEntityNames: [String]
    let dataIssues: [OwnerHealthDataIssue]
    let recurringSuggestions: [DetectedSubscription]

    var id: BriefingResourceCategory { category }
    var requiresAttention: Bool { status == .critical || status == .needsAttention }
}

struct OwnerHealthSnapshot: Hashable {
    let scope: OwnerBriefingScope
    let entityCount: Int
    let status: OwnerHealthStatus
    let affectedEntityNames: [String]
    let categories: [OwnerHealthCategorySummary]
}

enum OwnerHealthEngine {
    static func snapshot(
        appState: AppState,
        scope: OwnerBriefingScope,
        now: Date = Date(),
        ignoredDataIssueIDs: Set<String> = []
    ) -> OwnerHealthSnapshot {
        let scopedCompanies = appState.companies.filter(scope.includes)
        let scopedCompanyIDs = Set(scopedCompanies.map(\.id))
        let companiesByID = Dictionary(uniqueKeysWithValues: appState.companies.map { ($0.id, $0) })

        func effectiveCompanyID(resourceID: UUID, companyID: UUID) -> UUID {
            appState.localCompanyOverrides[resourceID.uuidString] ?? companyID
        }

        func isInScope(resourceID: UUID, companyID: UUID) -> Bool {
            scopedCompanyIDs.contains(effectiveCompanyID(resourceID: resourceID, companyID: companyID))
        }

        let subscriptions = appState.subscriptions.filter { isInScope(resourceID: $0.id, companyID: $0.companyId) }
        let institutions = appState.institutions.filter { isInScope(resourceID: $0.id, companyID: $0.companyId) }
        let cards = appState.cards.filter { isInScope(resourceID: $0.id, companyID: $0.companyId) }
        let loans = appState.loans.filter { isInScope(resourceID: $0.id, companyID: $0.companyId) }
        let documents = appState.documents.filter { isInScope(resourceID: $0.id, companyID: $0.companyId) }
        let scopedObligations = appState.openObligations.filter { obligation in
            guard let companyID = obligation.companyId else { return scope == .business }
            return scopedCompanyIDs.contains(companyID)
        }

        func categoryObligations(in category: BriefingResourceCategory) -> [PortfolioObligation] {
            scopedObligations.filter { BriefingResourceCategory.category(for: $0) == category }
        }

        func entityName(for companyID: UUID?) -> String? {
            guard let companyID else { return nil }
            return companiesByID[companyID]?.name
        }

        func entityNames(
            for categoryObligations: [PortfolioObligation],
            additionalCompanyIDs: Set<UUID> = []
        ) -> [String] {
            let obligationNames = categoryObligations.compactMap { entityName(for: $0.companyId) }
            let derivedNames = additionalCompanyIDs.compactMap { companiesByID[$0]?.name }
            return Array(Set(obligationNames + derivedNames)).sorted()
        }

        func status(
            resourceCount: Int,
            categoryObligations: [PortfolioObligation],
            hasCriticalCondition: Bool = false,
            hasAttentionCondition: Bool = false
        ) -> OwnerHealthStatus {
            if hasCriticalCondition || categoryObligations.contains(where: { $0.severity == .urgent }) {
                return .critical
            }
            if hasAttentionCondition || !categoryObligations.isEmpty {
                return .needsAttention
            }
            return resourceCount == 0 ? .notApplicable : .healthy
        }

        func visibleIssues(_ issues: [OwnerHealthDataIssue]) -> [OwnerHealthDataIssue] {
            issues.filter { !ignoredDataIssueIDs.contains($0.id) }
        }

        func dataState(resourceCount: Int, issues: [OwnerHealthDataIssue]) -> OwnerHealthDataState {
            guard resourceCount > 0 else { return .noData }
            return issues.isEmpty ? .complete : .moreDataUseful(issues.count)
        }

        func nonempty(_ value: String?) -> Bool {
            guard let value else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        let companyObligations = categoryObligations(in: .company)
        let companyIssues = visibleIssues(scopedCompanies.compactMap { company in
            var fields: [String] = []
            if !nonempty(company.name) { fields.append("Name") }
            if !nonempty(company.structure) { fields.append("Structure") }
            if !nonempty(company.website) { fields.append("Website") }
            if !nonempty(company.companyDescription) { fields.append("Description") }
            guard !fields.isEmpty else { return nil }
            return OwnerHealthDataIssue(
                resourceType: .company,
                resourceID: company.id,
                resourceName: nonempty(company.name) ? company.name : "Unnamed entity",
                entityName: nonempty(company.name) ? company.name : "Unassigned entity",
                missingFields: fields
            )
        })
        let companyStatus = status(resourceCount: scopedCompanies.count, categoryObligations: companyObligations)
        let companySummary = OwnerHealthCategorySummary(
            category: .company,
            status: companyStatus,
            dataState: dataState(resourceCount: scopedCompanies.count, issues: companyIssues),
            summary: companyStatus.requiresAttentionText(
                attention: "Company records need review.",
                healthy: "Your entity structure is organized.",
                empty: scope == .business ? "No business entities added." : "No personal profiles added."
            ),
            metrics: [
                OwnerHealthMetric(label: "Entities", value: "\(scopedCompanies.count)"),
                OwnerHealthMetric(label: "Complete", value: "\(max(0, scopedCompanies.count - companyIssues.count))")
            ],
            affectedEntityNames: entityNames(for: companyObligations),
            dataIssues: companyIssues,
            recurringSuggestions: []
        )

        // Transaction-derived candidates are canonical for recurring-charge blind spots.
        // Persisted recurring obligations can lag after an import, so only use them for
        // reminder lifecycle while this snapshot recalculates suggestions from live data.
        let subscriptionObligations = categoryObligations(in: .subscription).filter {
            $0.kind != "new_recurring_charge"
        }
        let activeSubscriptions = subscriptions.filter { $0.status.caseInsensitiveCompare("Active") == .orderedSame }
        func transactionCompanyID(_ transaction: Transaction) -> UUID? {
            if let companyId = transaction.companyId { return companyId }
            if let card = appState.cards.first(where: { $0.plaidAccountId == transaction.accountId }) {
                return effectiveCompanyID(resourceID: card.id, companyID: card.companyId)
            }
            if let institution = appState.institutions.first(where: {
                $0.id == transaction.institutionId || $0.accounts.contains(where: { $0.id == transaction.accountId })
            }) {
                return effectiveCompanyID(resourceID: institution.id, companyID: institution.companyId)
            }
            return nil
        }
        let recurringSuggestions = scopedCompanies.flatMap { company in
            let companyTransactions = appState.transactions.filter { transactionCompanyID($0) == company.id }
            let companySubscriptions = subscriptions.filter { $0.companyId == company.id }
            return SubscriptionDetector.detect(
                transactions: companyTransactions,
                existingSubscriptions: companySubscriptions,
                companyId: company.id
            )
        }
        let subscriptionIssues = visibleIssues(subscriptions.compactMap { subscription in
            var fields: [String] = []
            if !nonempty(subscription.name) { fields.append("Name") }
            if !subscription.isFree && subscription.cost <= 0 { fields.append("Cost") }
            if !nonempty(subscription.billingCycle) { fields.append("Billing cycle") }
            if !nonempty(subscription.paymentMethod) { fields.append("Payment method") }
            if subscription.nextRenewalAt == nil && !nonempty(subscription.nextRenewal) { fields.append("Next renewal") }
            if !nonempty(subscription.status) { fields.append("Status") }
            guard !fields.isEmpty else { return nil }
            let companyID = effectiveCompanyID(resourceID: subscription.id, companyID: subscription.companyId)
            return OwnerHealthDataIssue(
                resourceType: .subscription,
                resourceID: subscription.id,
                resourceName: nonempty(subscription.name) ? subscription.name : "Unnamed subscription",
                entityName: companiesByID[companyID]?.name ?? "Unknown entity",
                missingFields: fields
            )
        })
        let subscriptionStatus = status(
            resourceCount: subscriptions.count,
            categoryObligations: subscriptionObligations,
            hasAttentionCondition: !recurringSuggestions.isEmpty
        )
        let subscriptionSummaryText: String
        if !recurringSuggestions.isEmpty {
            subscriptionSummaryText = "\(recurringSuggestions.count) recurring charge\(recurringSuggestions.count == 1 ? " looks" : "s look") like a subscription."
        } else if subscriptions.isEmpty {
            subscriptionSummaryText = "No subscriptions added."
        } else if !subscriptionObligations.isEmpty {
            subscriptionSummaryText = "Subscription activity needs review."
        } else {
            subscriptionSummaryText = "Tracked subscriptions are caught up."
        }
        let subscriptionSummary = OwnerHealthCategorySummary(
            category: .subscription,
            status: subscriptionStatus,
            dataState: dataState(resourceCount: subscriptions.count, issues: subscriptionIssues),
            summary: subscriptionSummaryText,
            metrics: [
                OwnerHealthMetric(label: "Active", value: "\(activeSubscriptions.count)"),
                OwnerHealthMetric(label: "Monthly", value: currency(activeSubscriptions.reduce(0) { $0 + ($1.estimatedAnnualCost / 12) })),
                OwnerHealthMetric(label: "Suggested", value: "\(recurringSuggestions.count)")
            ],
            affectedEntityNames: Array(Set(
                entityNames(for: subscriptionObligations)
                    + recurringSuggestions.compactMap { $0.companyId.flatMap { companiesByID[$0]?.name } }
            )).sorted(),
            dataIssues: subscriptionIssues,
            recurringSuggestions: recurringSuggestions
        )

        let institutionObligations = categoryObligations(in: .institution)
        let disconnectedInstitutions = institutions.filter(\.isDisconnected)
        let negativeAccounts = institutions.flatMap(\.accounts).filter { $0.balance < 0 }
        let institutionAttentionIDs = Set(disconnectedInstitutions.map {
            effectiveCompanyID(resourceID: $0.id, companyID: $0.companyId)
        } + institutions.filter { institution in
            institution.accounts.contains(where: { $0.balance < 0 })
        }.map {
            effectiveCompanyID(resourceID: $0.id, companyID: $0.companyId)
        })
        let institutionIssues = visibleIssues(institutions.compactMap { institution in
            var fields: [String] = []
            if !nonempty(institution.name) { fields.append("Name") }
            if institution.accounts.isEmpty { fields.append("At least one account") }
            guard !fields.isEmpty else { return nil }
            let companyID = effectiveCompanyID(resourceID: institution.id, companyID: institution.companyId)
            return OwnerHealthDataIssue(
                resourceType: .institution,
                resourceID: institution.id,
                resourceName: nonempty(institution.name) ? institution.name : "Unnamed institution",
                entityName: companiesByID[companyID]?.name ?? "Unknown entity",
                missingFields: fields
            )
        })
        let institutionStatus = status(
            resourceCount: institutions.count,
            categoryObligations: institutionObligations,
            hasAttentionCondition: !disconnectedInstitutions.isEmpty || !negativeAccounts.isEmpty
        )
        let accountBalance = institutions.flatMap(\.accounts).reduce(0) { $0 + $1.balance }
        let institutionSummaryText: String
        if !disconnectedInstitutions.isEmpty {
            institutionSummaryText = "\(disconnectedInstitutions.count) institution connection\(disconnectedInstitutions.count == 1 ? "" : "s") need attention."
        } else if !negativeAccounts.isEmpty {
            institutionSummaryText = "\(negativeAccounts.count) account balance\(negativeAccounts.count == 1 ? "" : "s") are below zero."
        } else if institutions.isEmpty {
            institutionSummaryText = "No institutions added."
        } else {
            institutionSummaryText = "Connected accounts show no known issues."
        }
        let institutionSummary = OwnerHealthCategorySummary(
            category: .institution,
            status: institutionStatus,
            dataState: dataState(resourceCount: institutions.count, issues: institutionIssues),
            summary: institutionSummaryText,
            metrics: [
                OwnerHealthMetric(label: "Institutions", value: "\(institutions.count)"),
                OwnerHealthMetric(label: "Accounts", value: "\(institutions.flatMap(\.accounts).count)"),
                OwnerHealthMetric(label: "Balance", value: currency(accountBalance))
            ],
            affectedEntityNames: entityNames(for: institutionObligations, additionalCompanyIDs: institutionAttentionIDs),
            dataIssues: institutionIssues,
            recurringSuggestions: []
        )

        let cardObligations = categoryObligations(in: .card)
        let expiredCards = cards.filter {
            $0.status.caseInsensitiveCompare("Expired") == .orderedSame || ($0.expiresAt.map { $0 < now } ?? false)
        }
        let expiringCards = cards.filter {
            guard let expiry = $0.expiresAt else { return false }
            return expiry >= now && expiry <= now.addingTimeInterval(90 * 86_400)
        }
        let endingPromos = cards.filter {
            guard let end = $0.promoEnds else { return false }
            return end >= now && end <= now.addingTimeInterval(60 * 86_400)
        }
        let creditCards = cards.filter { $0.type.caseInsensitiveCompare("Credit") == .orderedSame }
        let highUtilizationCards = creditCards.filter { $0.limit > 0 && ($0.balance / $0.limit) >= 0.9 }
        let cardAttentionResources = expiredCards + expiringCards + endingPromos + highUtilizationCards
        let cardAttentionIDs = Set(cardAttentionResources.map {
            effectiveCompanyID(resourceID: $0.id, companyID: $0.companyId)
        })
        let cardIssues = visibleIssues(cards.compactMap { card in
            var fields: [String] = []
            if !nonempty(card.name) { fields.append("Name") }
            if !nonempty(card.last4) { fields.append("Last four digits") }
            if card.expiresAt == nil && !nonempty(card.expiry) { fields.append("Expiration date") }
            if !nonempty(card.institutionName) { fields.append("Institution") }
            if card.type.caseInsensitiveCompare("Credit") == .orderedSame && card.limit <= 0 { fields.append("Credit limit") }
            guard !fields.isEmpty else { return nil }
            let companyID = effectiveCompanyID(resourceID: card.id, companyID: card.companyId)
            return OwnerHealthDataIssue(
                resourceType: .card,
                resourceID: card.id,
                resourceName: nonempty(card.name) ? card.name : "Unnamed card",
                entityName: companiesByID[companyID]?.name ?? "Unknown entity",
                missingFields: fields
            )
        })
        let cardStatus = status(
            resourceCount: cards.count,
            categoryObligations: cardObligations,
            hasCriticalCondition: !expiredCards.isEmpty,
            hasAttentionCondition: !expiringCards.isEmpty || !endingPromos.isEmpty || !highUtilizationCards.isEmpty
        )
        let totalCardBalance = creditCards.reduce(0) { $0 + $1.balance }
        let totalCardLimit = creditCards.reduce(0) { $0 + $1.limit }
        let utilization = totalCardLimit > 0 ? (totalCardBalance / totalCardLimit) * 100 : 0
        let cardSummaryText: String
        if !expiredCards.isEmpty {
            cardSummaryText = "\(expiredCards.count) card\(expiredCards.count == 1 ? " is" : "s are") expired."
        } else if !expiringCards.isEmpty || !endingPromos.isEmpty {
            cardSummaryText = "Card or promotional deadlines are approaching."
        } else if !highUtilizationCards.isEmpty {
            cardSummaryText = "\(highUtilizationCards.count) card\(highUtilizationCards.count == 1 ? " has" : "s have") high utilization."
        } else if cards.isEmpty {
            cardSummaryText = "No cards added."
        } else {
            cardSummaryText = "No known card deadlines need attention."
        }
        let cardSummary = OwnerHealthCategorySummary(
            category: .card,
            status: cardStatus,
            dataState: dataState(resourceCount: cards.count, issues: cardIssues),
            summary: cardSummaryText,
            metrics: [
                OwnerHealthMetric(label: "Cards", value: "\(cards.count)"),
                OwnerHealthMetric(label: "Balance", value: currency(totalCardBalance)),
                OwnerHealthMetric(label: "Utilization", value: percent(utilization))
            ],
            affectedEntityNames: entityNames(for: cardObligations, additionalCompanyIDs: cardAttentionIDs),
            dataIssues: cardIssues,
            recurringSuggestions: []
        )

        let loanObligations = categoryObligations(in: .loan)
        let activeLoans = loans.filter {
            $0.status.caseInsensitiveCompare("Active") == .orderedSame && $0.remainingBalance > 0
        }
        let overdueLoans = activeLoans.filter { loan in
            (loan.nextPaymentAt.map { $0 < now } ?? false)
                || (loan.maturityDate.map { $0 < now } ?? false)
        }
        let loanAttentionIDs = Set(overdueLoans.map {
            effectiveCompanyID(resourceID: $0.id, companyID: $0.companyId)
        })
        let loanIssues = visibleIssues(loans.compactMap { loan in
            var fields: [String] = []
            if !nonempty(loan.name) { fields.append("Name") }
            if loan.role.caseInsensitiveCompare("Borrower") == .orderedSame && !nonempty(loan.lender) { fields.append("Lender") }
            if loan.principalAmount <= 0 { fields.append("Principal amount") }
            if loan.status.caseInsensitiveCompare("Active") == .orderedSame && loan.monthlyPayment <= 0 { fields.append("Monthly payment") }
            if loan.status.caseInsensitiveCompare("Active") == .orderedSame && loan.nextPaymentAt == nil { fields.append("Next payment date") }
            if loan.maturityDate == nil { fields.append("Maturity date") }
            guard !fields.isEmpty else { return nil }
            let companyID = effectiveCompanyID(resourceID: loan.id, companyID: loan.companyId)
            return OwnerHealthDataIssue(
                resourceType: .loan,
                resourceID: loan.id,
                resourceName: nonempty(loan.name) ? loan.name : "Unnamed loan",
                entityName: companiesByID[companyID]?.name ?? "Unknown entity",
                missingFields: fields
            )
        })
        let loanStatus = status(
            resourceCount: loans.count,
            categoryObligations: loanObligations,
            hasCriticalCondition: !overdueLoans.isEmpty
        )
        let outstandingBalance = activeLoans.reduce(0) { $0 + $1.remainingBalance }
        let monthlyPayments = activeLoans.reduce(0) { $0 + $1.monthlyPayment }
        let loanSummaryText: String
        if !overdueLoans.isEmpty {
            loanSummaryText = "\(overdueLoans.count) loan\(overdueLoans.count == 1 ? " has" : "s have") an overdue recorded date."
        } else if !loanObligations.isEmpty {
            loanSummaryText = "Loan activity needs review."
        } else if activeLoans.isEmpty {
            loanSummaryText = loans.isEmpty ? "No loans added." : "No active loan balances."
        } else {
            loanSummaryText = "No recorded loan payments are overdue."
        }
        let loanSummary = OwnerHealthCategorySummary(
            category: .loan,
            status: loanStatus,
            dataState: dataState(resourceCount: loans.count, issues: loanIssues),
            summary: loanSummaryText,
            metrics: [
                OwnerHealthMetric(label: "Active", value: "\(activeLoans.count)"),
                OwnerHealthMetric(label: "Outstanding", value: currency(outstandingBalance)),
                OwnerHealthMetric(label: "Monthly", value: currency(monthlyPayments))
            ],
            affectedEntityNames: entityNames(for: loanObligations, additionalCompanyIDs: loanAttentionIDs),
            dataIssues: loanIssues,
            recurringSuggestions: []
        )

        let documentObligations = categoryObligations(in: .document)
        let expiredDocuments = documents.filter { $0.expiresAt.map { $0 < now } ?? false }
        let expiringDocuments = documents.filter {
            guard let expiry = $0.expiresAt else { return false }
            return expiry >= now && expiry <= now.addingTimeInterval(60 * 86_400)
        }
        let documentAttentionResources = expiredDocuments + expiringDocuments
        let documentAttentionIDs = Set(documentAttentionResources.map {
            effectiveCompanyID(resourceID: $0.id, companyID: $0.companyId)
        })
        let documentIssues = visibleIssues(documents.compactMap { document in
            var fields: [String] = []
            if !nonempty(document.name) { fields.append("Name") }
            if !nonempty(document.url) { fields.append("Document file") }
            guard !fields.isEmpty else { return nil }
            let companyID = effectiveCompanyID(resourceID: document.id, companyID: document.companyId)
            return OwnerHealthDataIssue(
                resourceType: .document,
                resourceID: document.id,
                resourceName: nonempty(document.name) ? document.name : "Unnamed document",
                entityName: companiesByID[companyID]?.name ?? "Unknown entity",
                missingFields: fields
            )
        })
        let documentStatus = status(
            resourceCount: documents.count,
            categoryObligations: documentObligations,
            hasCriticalCondition: !expiredDocuments.isEmpty,
            hasAttentionCondition: !expiringDocuments.isEmpty
        )
        let documentSummaryText: String
        if !expiredDocuments.isEmpty {
            documentSummaryText = "\(expiredDocuments.count) document\(expiredDocuments.count == 1 ? " has" : "s have") expired."
        } else if !expiringDocuments.isEmpty {
            documentSummaryText = "\(expiringDocuments.count) document\(expiringDocuments.count == 1 ? " expires" : "s expire") within 60 days."
        } else if documents.isEmpty {
            documentSummaryText = "No documents added."
        } else {
            documentSummaryText = "No tracked documents expire soon."
        }
        let documentSummary = OwnerHealthCategorySummary(
            category: .document,
            status: documentStatus,
            dataState: dataState(resourceCount: documents.count, issues: documentIssues),
            summary: documentSummaryText,
            metrics: [
                OwnerHealthMetric(label: "Documents", value: "\(documents.count)"),
                OwnerHealthMetric(label: "Expiring", value: "\(expiringDocuments.count)"),
                OwnerHealthMetric(label: "Expired", value: "\(expiredDocuments.count)")
            ],
            affectedEntityNames: entityNames(for: documentObligations, additionalCompanyIDs: documentAttentionIDs),
            dataIssues: documentIssues,
            recurringSuggestions: []
        )

        func companyID(forSharedResource resourceID: UUID) -> UUID? {
            if scopedCompanyIDs.contains(resourceID) { return resourceID }
            if let item = appState.subscriptions.first(where: { $0.id == resourceID }) {
                return effectiveCompanyID(resourceID: item.id, companyID: item.companyId)
            }
            if let item = appState.institutions.first(where: { $0.id == resourceID }) {
                return effectiveCompanyID(resourceID: item.id, companyID: item.companyId)
            }
            if let item = appState.cards.first(where: { $0.id == resourceID }) {
                return effectiveCompanyID(resourceID: item.id, companyID: item.companyId)
            }
            if let item = appState.loans.first(where: { $0.id == resourceID }) {
                return effectiveCompanyID(resourceID: item.id, companyID: item.companyId)
            }
            if let item = appState.documents.first(where: { $0.id == resourceID }) {
                return effectiveCompanyID(resourceID: item.id, companyID: item.companyId)
            }
            return nil
        }

        let shares = appState.resourceShares.filter {
            guard let companyID = companyID(forSharedResource: $0.resourceId) else { return false }
            return scopedCompanyIDs.contains(companyID)
        }
        let collaboratorObligations = categoryObligations(in: .collaborator)
        let collaboratorStatus = status(resourceCount: shares.count, categoryObligations: collaboratorObligations)
        let collaboratorSummary = OwnerHealthCategorySummary(
            category: .collaborator,
            status: collaboratorStatus,
            dataState: shares.isEmpty ? .noData : .complete,
            summary: shares.isEmpty
                ? "No collaborators have access."
                : collaboratorObligations.isEmpty
                    ? "Collaborator access has no known issues."
                    : "Collaborator access needs review.",
            metrics: [
                OwnerHealthMetric(label: "People", value: "\(Set(shares.map(\.userId)).count)"),
                OwnerHealthMetric(label: "Shared items", value: "\(shares.count)")
            ],
            affectedEntityNames: entityNames(for: collaboratorObligations),
            dataIssues: [],
            recurringSuggestions: []
        )

        let otherObligations = categoryObligations(in: .other)
        let otherStatus = status(resourceCount: otherObligations.count, categoryObligations: otherObligations)
        let otherSummary = OwnerHealthCategorySummary(
            category: .other,
            status: otherStatus,
            dataState: otherObligations.isEmpty ? .noData : .complete,
            summary: otherObligations.isEmpty ? "No uncategorized issues." : "Uncategorized items need review.",
            metrics: [OwnerHealthMetric(label: "Items", value: "\(otherObligations.count)")],
            affectedEntityNames: entityNames(for: otherObligations),
            dataIssues: [],
            recurringSuggestions: []
        )

        let categories = [
            companySummary, subscriptionSummary, institutionSummary, cardSummary,
            loanSummary, documentSummary, collaboratorSummary, otherSummary
        ]
        let snapshotStatus = categories.map(\.status).max(by: { $0.priority < $1.priority }) ?? .notApplicable
        let affectedNames = Array(Set(categories.flatMap(\.affectedEntityNames))).sorted()

        return OwnerHealthSnapshot(
            scope: scope,
            entityCount: scopedCompanies.count,
            status: snapshotStatus,
            affectedEntityNames: affectedNames,
            categories: categories
        )
    }

    private static func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = abs(value) < 100 ? 2 : 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    private static func percent(_ value: Double) -> String {
        guard value.isFinite else { return "0%" }
        return "\(Int(value.rounded()))%"
    }
}

private extension OwnerHealthStatus {
    func requiresAttentionText(attention: String, healthy: String, empty: String) -> String {
        switch self {
        case .critical, .needsAttention: return attention
        case .healthy: return healthy
        case .notApplicable: return empty
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
