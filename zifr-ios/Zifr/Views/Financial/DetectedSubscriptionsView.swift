import SwiftUI

// MARK: - Detected Subscription Model
struct DetectedSubscription: Identifiable, Hashable {
    var merchantKey: String // normalized merchant key used for import matching
    var name: String        // display name
    var amount: Double      // average charge amount
    var currency: String
    var frequency: String   // "Monthly" or "Yearly"
    var accountId: String   // plaid account_id this belongs to
    var companyId: UUID?    // company resolved from the transaction/account context
    var lastChargeDate: String
    var occurrences: Int
    var category: [String]?
    var website: String?

    /// Keeps identical merchants in different companies/accounts independent in SwiftUI.
    var id: String {
        "\(companyId?.uuidString ?? "unscoped"):\(accountId):\(merchantKey)" + (currency == "USD" ? "" : ":\(currency)")
    }
}

// MARK: - Detection Engine
struct SubscriptionDetector {
    private struct GroupKey: Hashable {
        let merchant: String
        let companyId: UUID?
        let accountId: String
        let currency: String
    }

    /// Analyses raw transactions and returns recurring charges not yet in subscriptions
    static func detect(
        transactions: [Transaction],
        existingSubscriptions: [Subscription],
        filterAccountId: String? = nil,
        companyId fallbackCompanyId: UUID? = nil,
        dismissalDefaults: UserDefaults = .standard
    ) -> [DetectedSubscription] {
        let existingNames = Set(existingSubscriptions.map { normalize($0.name) })
        let existingNamesByCompany = Dictionary(grouping: existingSubscriptions, by: \.companyId)
            .mapValues { Set($0.map { normalize($0.name) }) }
        let existingStreams = Set(existingSubscriptions.compactMap(\.plaidStreamId))
        let existingStreamsByCompany = Dictionary(grouping: existingSubscriptions, by: \.companyId)
            .mapValues { Set($0.compactMap(\.plaidStreamId)) }
        
        // Group by normalized merchant name (optionally filtered to one account)
        var txByKey: [GroupKey: [Transaction]] = [:]
        for tx in transactions {
            guard let amount = tx.amount, amount.isFinite, amount > 0 else { continue }
            guard tx.pending != true, parseChargeDate(tx.date) != nil else { continue }
            if let filterAcc = filterAccountId, tx.accountId != filterAcc { continue }
            let raw = merchantName(for: tx)
            guard !raw.isEmpty, !isExcludedFinancialMovement(tx) else { continue }
            let merchantKey = normalize(raw)
            let resolvedCompanyId = fallbackCompanyId ?? tx.companyId
            let trackedNames: Set<String>
            let trackedStreams: Set<String>
            if let resolvedCompanyId {
                trackedNames = existingNamesByCompany[resolvedCompanyId] ?? []
                trackedStreams = existingStreamsByCompany[resolvedCompanyId] ?? []
            } else {
                trackedNames = existingNames
                trackedStreams = existingStreams
            }
            if merchantKey.isEmpty
                || trackedNames.contains(merchantKey)
                || trackedStreams.contains("detected_\(merchantKey)")
                || trackedStreams.contains("detected_\(legacyNormalize(tx.name ?? raw))") { continue }
            txByKey[GroupKey(merchant: merchantKey, companyId: resolvedCompanyId, accountId: tx.accountId, currency: tx.currency), default: []].append(tx)
        }
        
        var results: [DetectedSubscription] = []
        for (key, txs) in txByKey {
            guard txs.count >= 2 else { continue }
            
            let amounts = txs.compactMap { $0.amount }
            let avg = amounts.reduce(0, +) / Double(amounts.count)
            
            let sorted = txs.sorted { $0.date > $1.date }
            guard let frequency = billingFrequency(transactions: txs) else { continue }

            let latest = sorted[0]
            let displayName = cleanDisplayName(merchantName(for: latest))
            let categories = (latest.category ?? [])
                + [latest.personalFinancePrimary, latest.personalFinanceDetailed].compactMap { $0 }
            let isBill = RecurringServiceClassifier.classify(
                name: displayName, website: latest.merchantWebsite, categories: categories
            ) == .bill
            let isSimilar = amounts.allSatisfy { abs($0 - avg) / avg < 0.25 }
            // Variable bills need cadence, not equal amounts. Other variable
            // merchants need three charges to establish a recurring pattern.
            guard isSimilar || isBill || Set(txs.map(\.date)).count >= 3 else { continue }

            let det = DetectedSubscription(
                merchantKey: key.merchant,
                name: displayName,
                amount: (avg * 100).rounded() / 100,
                currency: key.currency,
                frequency: frequency,
                accountId: sorted.first?.accountId ?? "",
                companyId: key.companyId,
                lastChargeDate: sorted.first?.date ?? "",
                occurrences: txs.count,
                category: categories,
                website: sorted.compactMap(\.merchantWebsite).first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            )
            results.append(det)
        }
        
        return results
            .filter { !RecurringSuggestionDismissalStore.isHidden($0, defaults: dismissalDefaults) }
            .sorted { $0.amount > $1.amount }
    }
    
    static func merchantName(for transaction: Transaction) -> String {
        [transaction.merchantName, transaction.name].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }

    static func normalize(_ raw: String) -> String {
        var s = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["sq *", "tst*", "paypal *", "amzn mkt", "sp *", "apl*", "apl *"] {
            if s.hasPrefix(prefix) { s = String(s.dropFirst(prefix.count)) }
        }
        // Remove labelled bank references, not digits in names like Microsoft 365.
        s = s.replacingOccurrences(of: #"\b(?:ref|reference|invoice|inv|id)\s*[:#-]?\s*[a-z0-9-]*[0-9][a-z0-9-]*\b|#[0-9]+"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\b[0-9]{6,}\b$"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\.com\b|\b(?:digital|services?|inc|llc|corp|ltd|co|payment|autopay|billing|recurring)\b"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"[^a-z0-9\s]"#, with: "", options: .regularExpression)
        return s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Read compatibility for streams imported before merchant normalization was fixed.
    static func legacyNormalize(_ raw: String) -> String {
        var value = raw.lowercased()
        for prefix in ["sq *", "tst*", "paypal *", "amzn mkt", "sp *", "apl*", "apl *", "apple.com/bill"] {
            if value.hasPrefix(prefix) { value = String(value.dropFirst(prefix.count)) }
        }
        value = value.replacingOccurrences(of: #"(\.com|digital|service|services|inc|llc|corp|ltd|co|payment|autopay|billing|recurring|#[0-9]+)"#, with: "", options: .regularExpression)
        value = value.replacingOccurrences(of: #"[^a-z0-9\s]"#, with: "", options: .regularExpression)
        return value.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// Subscription suggestions include recurring bills/loans. Keep this narrower
    /// than cash-flow exclusions, which intentionally also omit loan payments.
    static func isExcludedFinancialMovement(_ transaction: Transaction) -> Bool {
        let categories = ((transaction.category ?? [])
            + [transaction.personalFinancePrimary, transaction.personalFinanceDetailed].compactMap { $0 })
            .joined(separator: " ").lowercased()
        let categoryPatterns = [#"\btransfer"#, #"\bcash\b"#, #"\bdeposit"#, #"\bwithdrawal"#,
                                #"credit[ _]card[ _]payment"#, #"credit card"#]
        let name = TransactionIntelligence.displayName(for: transaction).lowercased()
        let namePatterns = [#"\bzelle\b"#, #"\batm\b"#, #"\bwithdrawal\b"#,
                            #"\b(?:credit card|card) payment\b"#, #"\bpayment to.*\b(?:credit card|card)\b"#,
                            #"\btransfer (?:to|from)\b"#, #"\bmobile check deposit\b"#]
        return categoryPatterns.contains { categories.range(of: $0, options: .regularExpression) != nil }
            || namePatterns.contains { name.range(of: $0, options: .regularExpression) != nil }
    }

    static func billingFrequency(transactions: [Transaction]) -> String? {
        let dates = Array(Set(transactions.compactMap { parseChargeDate($0.date) })).sorted()
        guard dates.count >= 2 else { return nil }
        let gaps = zip(dates, dates.dropFirst()).map { Int(($1.timeIntervalSince($0) / 86400).rounded()) }
        if gaps.allSatisfy({ (330...400).contains($0) }) { return "Yearly" }
        let monthlyGaps = gaps.filter { (24...38).contains($0) }.count
        // Permit a missing month or two, but require observed monthly intervals.
        if monthlyGaps * 2 >= gaps.count,
           gaps.allSatisfy({ (24...38).contains($0) || (52...70).contains($0) || (82...100).contains($0) }) {
            return "Monthly"
        }
        return nil
    }

    static func parseChargeDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter.date(from: value)
    }

    private static func cleanDisplayName(_ raw: String) -> String {
        // Title-case the first word, leave rest
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return raw }
        return trimmed.split(separator: " ")
            .map { word -> String in
                let w = String(word)
                return w.prefix(1).uppercased() + w.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }

}

// MARK: - Persistent suggestion lifecycle and import defaults
struct RecurringSuggestionDismissalStore {
    private static let defaultsKey = "miloom.recurringSuggestionDismissedMonths.v1"

    static func dismiss(_ suggestion: DetectedSubscription, defaults: UserDefaults = .standard) {
        guard let month = monthToken(for: suggestion.lastChargeDate) else { return }
        var records = defaults.dictionary(forKey: defaultsKey) as? [String: String] ?? [:]
        records[suggestion.id] = month
        defaults.set(records, forKey: defaultsKey)
    }

    static func isHidden(_ suggestion: DetectedSubscription, defaults: UserDefaults = .standard) -> Bool {
        guard let currentMonth = monthToken(for: suggestion.lastChargeDate),
              let dismissedMonth = (defaults.dictionary(forKey: defaultsKey) as? [String: String])?[suggestion.id]
        else { return false }
        return currentMonth <= dismissedMonth
    }

    static func clear(_ suggestion: DetectedSubscription, defaults: UserDefaults = .standard) {
        var records = defaults.dictionary(forKey: defaultsKey) as? [String: String] ?? [:]
        records.removeValue(forKey: suggestion.id)
        defaults.set(records, forKey: defaultsKey)
    }

    private static func monthToken(for dateString: String) -> String? {
        guard dateString.count >= 7 else { return nil }
        return String(dateString.prefix(7))
    }
}

struct DetectedSubscriptionImportDefaults {
    let nextRenewal: String?
    let nextRenewalAt: Date?
    let website: String?

    static func make(
        for suggestion: DetectedSubscription,
        existingSubscriptions: [Subscription],
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> DetectedSubscriptionImportDefaults {
        var calendar = calendar
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let chargeDate = parseDate(suggestion.lastChargeDate, calendar: calendar)

        let nextRenewal: String?
        let nextRenewalAt: Date?
        if suggestion.frequency == "Yearly", let chargeDate {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "MMM d"
            nextRenewal = formatter.string(from: chargeDate)
            nextRenewalAt = calendar.date(byAdding: .year, value: 1, to: chargeDate)
        } else if let chargeDate {
            let day = calendar.component(.day, from: chargeDate)
            nextRenewal = String(day)
            nextRenewalAt = calendar.nextDate(
                after: chargeDate,
                matching: DateComponents(day: day),
                matchingPolicy: .nextTimePreservingSmallerComponents,
                direction: .forward
            )
        } else {
            nextRenewal = nil
            nextRenewalAt = nil
        }

        return DetectedSubscriptionImportDefaults(
            nextRenewal: nextRenewal,
            nextRenewalAt: nextRenewalAt,
            website: resolvedWebsite(for: suggestion, existingSubscriptions: existingSubscriptions)
        )
    }

    private static func parseDate(_ value: String, calendar: Calendar) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private static func resolvedWebsite(
        for suggestion: DetectedSubscription,
        existingSubscriptions: [Subscription]
    ) -> String? {
        if let website = suggestion.website?.trimmingCharacters(in: .whitespacesAndNewlines), !website.isEmpty {
            return website
        }
        if let known = existingSubscriptions.first(where: {
            ($0.plaidStreamId == "detected_\(suggestion.merchantKey)"
                || SubscriptionDetector.normalize($0.name) == suggestion.merchantKey)
                && !($0.website ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        })?.website {
            return known
        }

        let domain = suggestion.name.lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]"#, with: "", options: .regularExpression)
        return domain.isEmpty ? nil : "\(domain).com"
    }
}

// MARK: - Detected Subscriptions Banner (inline card for Transaction view)
struct DetectedSubscriptionsBanner: View {
    let detected: [DetectedSubscription]
    let cardId: UUID?
    let cardName: String?
    var companyId: UUID? = nil
    @Bindable var vm: AppViewModel
    @Environment(AppState.self) private var appState
    
    @State private var showSheet = false
    @State private var dismissed = false
    
    var body: some View {
        if !dismissed && !detected.isEmpty {
            Button { showSheet = true } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#C1AA78").opacity(0.2))
                            .frame(width: 40, height: 40)
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(hex: "#C1AA78"))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(detected.count) subscription\(detected.count == 1 ? "" : "s") detected")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Tap to review & import automatically")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "#C1AA78"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hex: "#C1AA78").opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(hex: "#C1AA78").opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .sheet(isPresented: $showSheet) {
                DetectedSubscriptionsSheet(
                    detected: detected,
                    cardId: cardId,
                    cardName: cardName,
                    companyId: companyId,
                    vm: vm,
                    onDismissAll: { dismissed = true }
                )
                .environment(appState)
            }
        }
    }
}

// MARK: - Detected Subscriptions Sheet
struct DetectedSubscriptionsSheet: View {
    let detected: [DetectedSubscription]
    let cardId: UUID?
    let cardName: String?
    var companyId: UUID? = nil
    @Bindable var vm: AppViewModel
    let onDismissAll: () -> Void
    
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    @State private var snapshot: [DetectedSubscription] = []
    @State private var added: Set<String> = []
    @State private var skipped: Set<String> = []
    @State private var isAdding: String? = nil
    
    private var displayItems: [DetectedSubscription] {
        snapshot.isEmpty ? detected : snapshot
    }
    
    private var remaining: [DetectedSubscription] {
        displayItems.filter { !skipped.contains($0.id) }
    }
    
    private var unaddedCount: Int {
        remaining.filter { !added.contains($0.id) }.count
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#141414").ignoresSafeArea()
                
                if remaining.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Color.zifrGreen)
                        Text("All Done!")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                        Text(added.isEmpty ? "No subscriptions were added." : "\(added.count) subscription\(added.count == 1 ? "" : "s") added successfully.")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                        
                        Button("Done") {
                            onDismissAll()
                            dismiss()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                        .background(Color(hex: "#C1AA78"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.top, 8)
                    }
                    .padding(32)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Summary header
                            VStack(spacing: 6) {
                                Text("Detected Subscriptions")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("Found \(detected.count) recurring charge\(detected.count == 1 ? "" : "s") on \(cardName ?? "your card"). Add them to track automatically.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.white.opacity(0.55))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                            .padding(.top, 20)
                            .padding(.bottom, 16)
                            
                            // Add All button
                            if unaddedCount > 0 {
                                Button {
                                    Task {
                                        for det in remaining where !added.contains(det.id) {
                                            await addSubscription(det)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus.circle.fill")
                                        Text(added.isEmpty ? "Add All \(unaddedCount)" : "Add Remaining \(unaddedCount)")
                                            .font(.system(size: 15, weight: .semibold))
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(Color(hex: "#C1AA78"))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .padding(.horizontal, 20)
                                }
                                .padding(.bottom, 12)
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("All \(added.count) Added")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.zifrGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal, 20)
                                .padding(.bottom, 12)
                            }
                            
                            Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 20)
                            
                            // Individual cards
                            LazyVStack(spacing: 12) {
                                ForEach(remaining) { det in
                                    DetectedSubscriptionCard(
                                        det: det,
                                        isAdding: isAdding == det.id,
                                        isAdded: added.contains(det.id),
                                        onAdd: { Task<Void, Never> { await addSubscription(det) } },
                                        onSkip: {
                                            RecurringSuggestionDismissalStore.dismiss(det)
                                            withAnimation(.spring(response: 0.35)) {
                                                _ = skipped.insert(det.id)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.top, 12)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 32)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing:
                Button("Done") {
                    onDismissAll()
                    dismiss()
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(hex: "#C1AA78"))
            )
        }
        .onAppear {
            for det in detected {
                let targetCompanyId = det.companyId ?? companyId
                let relevantSubscriptions = appState.subscriptions.filter {
                    targetCompanyId == nil || $0.companyId == targetCompanyId
                }
                let existingNames = Set(relevantSubscriptions.map { SubscriptionDetector.normalize($0.name) })
                let existingStreams = Set(relevantSubscriptions.compactMap { $0.plaidStreamId })
                if existingNames.contains(det.merchantKey) || existingStreams.contains("detected_\(det.merchantKey)") {
                    _ = added.insert(det.id)
                }
            }
            if snapshot.isEmpty {
                snapshot = detected
            }
        }
        .presentationDetents([.fraction(0.85), .large])
        .presentationDragIndicator(.visible)
    }
    
    @MainActor
    private func addSubscription(_ det: DetectedSubscription) async {
        guard isAdding == nil else { return }
        isAdding = det.id
        
        let session = try? await SupabaseService.shared.client.auth.session
        guard let userId = session?.user.id else {
            isAdding = nil
            return
        }
        
        // Find matching card from account id
        let matchCard = cardId != nil ? appState.cards.first(where: { $0.id == cardId }) :
            appState.cards.first(where: { $0.plaidAccountId == det.accountId })
        
        guard let targetCompanyId = det.companyId ?? companyId ?? matchCard?.companyId ?? appState.companies.first?.id else {
            isAdding = nil
            return
        }
        // Two account-specific suggestions may resolve to the same service.
        // Recheck after each awaited import, including within Add All.
        if appState.subscriptions.contains(where: {
            $0.companyId == targetCompanyId && (SubscriptionDetector.normalize($0.name) == det.merchantKey
                || $0.plaidStreamId == "detected_\(det.merchantKey)")
        }) {
            added.insert(det.id)
            isAdding = nil
            return
        }
        let importDefaults = DetectedSubscriptionImportDefaults.make(
            for: det,
            existingSubscriptions: appState.subscriptions
        )
        
        let newSub = Subscription(
            userId: userId,
            companyId: targetCompanyId,
            name: det.name,
            cost: det.amount,
            currency: det.currency,
            billingCycle: det.frequency,
            paymentMethod: matchCard.map { "\($0.network ?? "Card") •••• \($0.last4 ?? "")" },
            paymentMethodId: matchCard?.id,
            nextRenewal: importDefaults.nextRenewal,
            nextRenewalAt: importDefaults.nextRenewalAt,
            renew: "Auto",
            status: "Active",
            website: importDefaults.website,
            pricingModel: "paid",
            serviceType: RecurringServiceClassifier.classify(
                name: det.name,
                website: importDefaults.website,
                categories: det.category
            ),
            plaidStreamId: "detected_\(det.merchantKey)",
            plaidAccountId: det.accountId
        )
        
        do {
            // Insert directly so we get the real error if it fails
            try await DataRepository.shared.insertSubscription(newSub)
            await MainActor.run {
                appState.subscriptions.append(newSub)
                RecurringSuggestionDismissalStore.clear(det)
                resolveRecurringObligations(for: det, companyId: targetCompanyId)
                withAnimation(.spring(response: 0.35)) {
                    _ = added.insert(det.id)
                }
            }
        } catch {
            AppDiagnostics.failure("subscriptions", "add_detected_subscription", error: error)
            await MainActor.run {
                appState.error = "Save failed: \(error.localizedDescription)"
            }
        }
        isAdding = nil
    }

    @MainActor
    private func resolveRecurringObligations(for det: DetectedSubscription, companyId: UUID) {
        let normalized = det.merchantKey.replacingOccurrences(of: " ", with: "")
        let matchingIndices = appState.obligations.indices.filter { index in
            let obligation = appState.obligations[index]
            guard obligation.kind == "new_recurring_charge", obligation.companyId == companyId else { return false }
            let fingerprintKey = obligation.fingerprint.split(separator: ":").last.map(String.init) ?? ""
            return fingerprintKey == det.merchantKey || fingerprintKey == normalized
        }

        for index in matchingIndices {
            appState.obligations[index] = OwnerBriefingPresentation.settingState(
                appState.obligations[index],
                to: .handled,
                at: Date()
            )
            let updated = appState.obligations[index]
            Task { try? await DataRepository.shared.updateObligation(updated) }
        }
    }
}

// MARK: - Individual Detected Subscription Card
struct DetectedSubscriptionCard: View {
    let det: DetectedSubscription
    let isAdding: Bool
    let isAdded: Bool
    let onAdd: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(det.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(formatCurrency(det.amount))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "#C1AA78"))
                    Text("/ \(det.frequency == "Yearly" ? "year" : "month")")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.45))
                    Text("•")
                        .foregroundStyle(Color.white.opacity(0.3))
                    Text("\(det.occurrences)x found")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                Button(action: onSkip) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                
                Button(action: onAdd) {
                    Group {
                        if isAdding {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.75)
                        } else if isAdded {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 32, height: 32)
                    .background(isAdded ? Color.zifrGreen : Color(hex: "#C1AA78"))
                    .clipShape(Circle())
                }
                .disabled(isAdding || isAdded)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity.combined(with: .scale(scale: 0.9))
        ))
    }
    
    private var iconName: String {
        let cats = det.category ?? []
        let name = det.name.lowercased()
        if cats.contains(where: { $0.lowercased().contains("entertainment") }) || name.contains("netflix") || name.contains("spotify") || name.contains("hulu") { return "play.circle.fill" }
        if cats.contains(where: { $0.lowercased().contains("software") }) || name.contains("adobe") || name.contains("microsoft") || name.contains("notion") { return "laptopcomputer" }
        if cats.contains(where: { $0.lowercased().contains("food") }) || name.contains("doordash") || name.contains("uber eats") { return "fork.knife" }
        if name.contains("gym") || name.contains("fitness") || name.contains("peloton") { return "figure.run" }
        if name.contains("cloud") || name.contains("dropbox") || name.contains("icloud") { return "cloud.fill" }
        return "arrow.clockwise.circle.fill"
    }
    
    private var iconColor: Color {
        let cats = det.category ?? []
        if cats.contains(where: { $0.lowercased().contains("entertainment") }) { return Color(hex: "#FF6B6B") }
        if cats.contains(where: { $0.lowercased().contains("software") }) { return Color(hex: "#4A9EFF") }
        return Color(hex: "#C1AA78")
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}
