import Foundation

enum PortfolioConnectionEngine {
    static func buildConnections(appState: AppState, ownerUserId: UUID) -> [ResourceConnection] {
        var generated: [ResourceConnection] = []

        func belongs(kind: ResourceKind, id: UUID, companyId: UUID) {
            generated.append(ResourceConnection(
                ownerUserId: ownerUserId,
                sourceType: kind, sourceId: id,
                targetType: .company, targetId: companyId,
                relationshipType: .belongsTo,
                origin: .direct, confidence: 1, state: .confirmed
            ))
        }

        appState.subscriptions.forEach { subscription in
            belongs(kind: .subscription, id: subscription.id, companyId: subscription.companyId)
            if let paymentId = subscription.paymentMethodId {
                let targetKind: ResourceKind = appState.cards.contains(where: { $0.id == paymentId }) ? .card : .institution
                generated.append(ResourceConnection(
                    ownerUserId: ownerUserId,
                    sourceType: .subscription, sourceId: subscription.id,
                    targetType: targetKind, targetId: paymentId,
                    relationshipType: .paidBy,
                    origin: .direct, confidence: 1, state: .confirmed
                ))
            }
            for subService in subscription.subServices {
                guard let paymentId = subService.paymentMethodId else { continue }
                let targetKind: ResourceKind = appState.cards.contains(where: { $0.id == paymentId }) ? .card : .institution
                generated.append(ResourceConnection(
                    ownerUserId: ownerUserId,
                    sourceType: .subscription, sourceId: subscription.id,
                    targetType: targetKind, targetId: paymentId,
                    relationshipType: .paidBy,
                    origin: .direct, confidence: 1, state: .confirmed
                ))
            }
        }
        appState.cards.forEach { belongs(kind: .card, id: $0.id, companyId: $0.companyId) }
        appState.institutions.forEach { institution in
            belongs(kind: .institution, id: institution.id, companyId: institution.companyId)
            for account in institution.accounts {
                guard let linkedCardId = account.linkedCardId, let cardId = UUID(uuidString: linkedCardId) else { continue }
                generated.append(ResourceConnection(
                    ownerUserId: ownerUserId,
                    sourceType: .institution, sourceId: institution.id,
                    targetType: .card, targetId: cardId,
                    relationshipType: .connectedAccount,
                    origin: .direct, confidence: 1, state: .confirmed
                ))
            }
        }
        appState.loans.forEach { belongs(kind: .loan, id: $0.id, companyId: $0.companyId) }
        appState.documents.forEach { belongs(kind: .document, id: $0.id, companyId: $0.companyId) }

        let rejectedKeys = Set(appState.resourceConnections.filter { $0.state == .rejected }.compactMap(\.inferenceKey))
        var emailResources: [String: [ResourceReference]] = [:]
        for subscription in appState.subscriptions {
            let emails = [subscription.loginId] + subscription.linkedEmails.map(\.email)
            for email in emails.compactMap({ normalizedEmail($0) }) {
                emailResources[email, default: []].append(ResourceReference(kind: .subscription, resourceId: subscription.id))
            }
        }
        for institution in appState.institutions {
            for email in [institution.email, institution.username].compactMap({ normalizedEmail($0) }) {
                emailResources[email, default: []].append(ResourceReference(kind: .institution, resourceId: institution.id))
            }
        }

        for (email, references) in emailResources where references.count > 1 {
            let unique = Array(Set(references)).sorted { $0.id < $1.id }
            for index in unique.indices {
                for otherIndex in unique.indices where otherIndex > index {
                    let source = unique[index]
                    let target = unique[otherIndex]
                    let key = "email:\(email):\(source.id):\(target.id)"
                    guard !rejectedKeys.contains(key) else { continue }
                    generated.append(ResourceConnection(
                        ownerUserId: ownerUserId,
                        sourceType: source.kind, sourceId: source.resourceId,
                        targetType: target.kind, targetId: target.resourceId,
                        relationshipType: .usesLogin,
                        origin: .inferred, confidence: 0.92, state: .suggested,
                        inferenceKey: key
                    ))
                }
            }
        }

        var seen = Set<String>()
        return generated.filter { connection in
            let key = edgeKey(connection)
            return seen.insert(key).inserted
        }
    }

    static func displayName(for reference: ResourceReference, appState: AppState) -> String {
        switch reference.kind {
        case .company: return appState.companies.first { $0.id == reference.resourceId }?.name ?? "Company"
        case .subscription: return appState.subscriptions.first { $0.id == reference.resourceId }?.name ?? "Subscription"
        case .institution: return appState.institutions.first { $0.id == reference.resourceId }?.name ?? "Institution"
        case .card:
            guard let card = appState.cards.first(where: { $0.id == reference.resourceId }) else { return "Card" }
            return card.name + ((card.last4 ?? "").isEmpty ? "" : " •••• \(card.last4 ?? "")")
        case .loan: return appState.loans.first { $0.id == reference.resourceId }?.name ?? "Loan"
        case .document: return appState.documents.first { $0.id == reference.resourceId }?.name ?? "Document"
        case .collaborator: return "Collaborator"
        }
    }

    static func connections(for reference: ResourceReference, in appState: AppState) -> [ResourceConnection] {
        appState.resourceConnections.filter {
            $0.state != .rejected && ($0.source == reference || $0.target == reference)
        }
    }

    static func otherReference(in connection: ResourceConnection, from reference: ResourceReference) -> ResourceReference {
        connection.source == reference ? connection.target : connection.source
    }

    private static func normalizedEmail(_ value: String?) -> String? {
        guard let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              normalized.contains("@"), normalized.count >= 5 else { return nil }
        return normalized
    }

    private static func edgeKey(_ connection: ResourceConnection) -> String {
        "\(connection.sourceType.rawValue):\(connection.sourceId):\(connection.targetType.rawValue):\(connection.targetId):\(connection.relationshipType.rawValue)"
    }
}

enum PortfolioObligationEngine {
    static func buildObligations(appState: AppState, ownerUserId: UUID, now: Date = Date()) -> [PortfolioObligation] {
        var results: [PortfolioObligation] = []
        let calendar = Calendar.current

        func append(
            sourceType: ResourceKind, sourceId: UUID, companyId: UUID?, kind: String,
            dueAt: Date?, title: String, summary: String, maximumDays: Int
        ) {
            guard let dueAt else { return }
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: dueAt)).day ?? 999
            guard days >= 0, days <= maximumDays else { return }
            let severity: ObligationSeverity = days <= 3 ? .urgent : days <= 14 ? .attention : .info
            let fingerprint = "\(sourceType.rawValue):\(sourceId):\(kind):\(calendar.startOfDay(for: dueAt).timeIntervalSince1970)"
            results.append(PortfolioObligation(
                id: UUID(), ownerUserId: ownerUserId, companyId: companyId,
                sourceType: sourceType, sourceId: sourceId, kind: kind,
                dueAt: dueAt, severity: severity, title: title, summary: summary,
                actionType: "open_source", state: .open, snoozedUntil: nil,
                fingerprint: fingerprint, createdAt: now, updatedAt: now
            ))
        }

        for subscription in appState.subscriptions where subscription.status == "Active" {
            let due = subscription.nextRenewalAt ?? renewalDate(subscription.nextRenewal, cycle: subscription.billingCycle, now: now)
            append(
                sourceType: .subscription, sourceId: subscription.id, companyId: subscription.companyId,
                kind: "subscription_renewal", dueAt: due,
                title: "\(subscription.name) renews soon",
                summary: "Review the renewal, payment method, and connected company.", maximumDays: 30
            )
        }

        for card in appState.cards where card.status == "Active" {
            let expiration = card.expiresAt ?? cardExpiration(card.expiry)
            let dependentSubscriptions = appState.subscriptions.filter { $0.paymentMethodId == card.id && $0.status == "Active" }
            let affectedCompanies = Set(dependentSubscriptions.map(\.companyId)).count
            let impact = dependentSubscriptions.isEmpty
                ? "Review this card before it expires."
                : "Used by \(dependentSubscriptions.count) subscription\(dependentSubscriptions.count == 1 ? "" : "s") across \(affectedCompanies) compan\(affectedCompanies == 1 ? "y" : "ies")."
            append(
                sourceType: .card, sourceId: card.id, companyId: card.companyId,
                kind: "card_expiration", dueAt: expiration,
                title: "\(card.name) expires soon", summary: impact, maximumDays: 60
            )
            append(
                sourceType: .card, sourceId: card.id, companyId: card.companyId,
                kind: "promo_apr_end", dueAt: card.promoEnds,
                title: "\(card.name) promotional APR ends soon",
                summary: "Review the balance and repayment plan.", maximumDays: 30
            )
        }

        for loan in appState.loans where loan.status == "Active" {
            append(
                sourceType: .loan, sourceId: loan.id, companyId: loan.companyId,
                kind: "loan_payment", dueAt: loan.nextPaymentAt,
                title: "\(loan.name) payment is approaching",
                summary: "Review the payment amount and funding source.", maximumDays: 14
            )
            append(
                sourceType: .loan, sourceId: loan.id, companyId: loan.companyId,
                kind: "loan_maturity", dueAt: loan.maturityDate,
                title: "\(loan.name) reaches maturity soon",
                summary: "Review the remaining balance and maturity plan.", maximumDays: 14
            )
        }

        for document in appState.documents {
            append(
                sourceType: .document, sourceId: document.id, companyId: document.companyId,
                kind: "document_expiration", dueAt: document.expiresAt,
                title: "\(document.name) expires soon",
                summary: "Review renewal or replacement requirements.", maximumDays: 90
            )
        }

        for institution in appState.institutions {
            if institution.isDisconnected {
                results.append(PortfolioObligation(
                    id: UUID(), ownerUserId: ownerUserId, companyId: institution.companyId,
                    sourceType: .institution, sourceId: institution.id, kind: "institution_disconnected",
                    dueAt: now, severity: .urgent,
                    title: "\(institution.name) needs to be reconnected",
                    summary: "Connected balances and subscriptions may be out of date.",
                    actionType: "reconnect_institution", state: .open, snoozedUntil: nil,
                    fingerprint: "institution:\(institution.id):disconnected", createdAt: now, updatedAt: now
                ))
            } else if let lastSyncedAt = institution.lastSyncedAt,
                      let staleDate = calendar.date(byAdding: .day, value: -7, to: now), lastSyncedAt < staleDate {
                results.append(PortfolioObligation(
                    id: UUID(), ownerUserId: ownerUserId, companyId: institution.companyId,
                    sourceType: .institution, sourceId: institution.id, kind: "institution_stale",
                    dueAt: now, severity: .attention,
                    title: "\(institution.name) has not synced recently",
                    summary: "Refresh the connection to keep portfolio details current.",
                    actionType: "sync_institution", state: .open, snoozedUntil: nil,
                    fingerprint: "institution:\(institution.id):stale", createdAt: now, updatedAt: now
                ))
            }
        }

        let existingNames = Set(appState.subscriptions.map { SubscriptionDetector.normalize($0.name) })
        for recurring in SubscriptionDetector.detect(
            transactions: appState.transactions,
            existingSubscriptions: appState.subscriptions
        ) where !existingNames.contains(SubscriptionDetector.normalize(recurring.name)) {
            let card = appState.cards.first { $0.plaidAccountId == recurring.accountId }
            let institution = appState.institutions.first { institution in
                institution.accounts.contains { $0.id == recurring.accountId }
            }
            guard let sourceId = card?.id ?? institution?.id,
                  let companyId = card?.companyId ?? institution?.companyId else { continue }
            results.append(PortfolioObligation(
                id: UUID(), ownerUserId: ownerUserId, companyId: companyId,
                sourceType: card == nil ? .institution : .card, sourceId: sourceId,
                kind: "new_recurring_charge", dueAt: now, severity: .attention,
                title: "New recurring charge detected",
                summary: "\(recurring.name) appears to recur \(recurring.frequency.lowercased()). Confirm it or add it as a subscription.",
                actionType: "review_recurring_charge", state: .open, snoozedUntil: nil,
                fingerprint: "recurring:\(recurring.accountId):\(recurring.id)", createdAt: now, updatedAt: now
            ))
        }

        let serverState = Dictionary(uniqueKeysWithValues: appState.obligations.map { ($0.fingerprint, $0) })
        return results.map { generated in
            guard let persisted = serverState[generated.fingerprint] else { return generated }
            return persisted
        }.filter { obligation in
            obligation.state == .open
        }.sorted {
            if $0.severity != $1.severity { return severityRank($0.severity) > severityRank($1.severity) }
            return ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture)
        }
    }

    private static func renewalDate(_ value: String?, cycle: String, now: Date) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        if let parsed = HomeRenewalParser.parse(value) {
            if parsed >= Calendar.current.startOfDay(for: now) { return parsed }
            let component: Calendar.Component = cycle == "Yearly" ? .year : .month
            return Calendar.current.date(byAdding: component, value: 1, to: parsed)
        }
        if let day = Int(value.filter(\.isNumber)), day >= 1, day <= 31 {
            var components = Calendar.current.dateComponents([.year, .month], from: now)
            components.day = min(day, Calendar.current.range(of: .day, in: .month, for: now)?.count ?? day)
            guard var date = Calendar.current.date(from: components) else { return nil }
            if date < Calendar.current.startOfDay(for: now) {
                date = Calendar.current.date(byAdding: .month, value: 1, to: date) ?? date
            }
            return date
        }
        return nil
    }

    private static func cardExpiration(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/yy"
        guard let month = formatter.date(from: value) else { return nil }
        return Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: month)
    }

    private static func severityRank(_ severity: ObligationSeverity) -> Int {
        switch severity {
        case .urgent: return 3
        case .attention: return 2
        case .info: return 1
        }
    }
}
