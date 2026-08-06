import SwiftUI

// MARK: - Detected Subscription Model
struct DetectedSubscription: Identifiable, Equatable {
    var id: String          // normalized merchant key
    var name: String        // display name
    var amount: Double      // average charge amount
    var currency: String
    var frequency: String   // "Monthly" or "Yearly"
    var accountId: String   // plaid account_id this belongs to
    var lastChargeDate: String
    var occurrences: Int
    var category: [String]?
}

// MARK: - Detection Engine
struct SubscriptionDetector {
    /// Analyses raw transactions and returns recurring charges not yet in subscriptions
    static func detect(
        transactions: [Transaction],
        existingSubscriptions: [Subscription],
        filterAccountId: String? = nil
    ) -> [DetectedSubscription] {
        
        let existingStreamIds = Set(existingSubscriptions.compactMap { $0.plaidStreamId })
        let existingNames = Set(existingSubscriptions.map { normalize($0.name.lowercased()) })
        
        // Group by normalized merchant name (optionally filtered to one account)
        var txByKey: [String: [Transaction]] = [:]
        for tx in transactions {
            guard let amount = tx.amount, amount > 0 else { continue }
            if let filterAcc = filterAccountId, tx.accountId != filterAcc { continue }
            let raw = tx.name ?? ""
            guard !raw.isEmpty else { continue }
            let key = normalize(raw)
            if key.isEmpty { continue }
            txByKey[key, default: []].append(tx)
        }
        
        var results: [DetectedSubscription] = []
        for (key, txs) in txByKey {
            guard txs.count >= 2 else { continue }
            
            let amounts = txs.compactMap { $0.amount }
            let avg = amounts.reduce(0, +) / Double(amounts.count)
            
            // Amounts must be within 25% of each other (recurring pattern)
            let isSimilar = amounts.allSatisfy { abs($0 - avg) / avg < 0.25 }
            guard isSimilar else { continue }
            
            let sorted = txs.sorted { $0.date > $1.date }
            let oldest = txs.sorted { $0.date < $1.date }.first!
            
            // Estimate frequency from date span
            let days = dateDiff(from: oldest.date, to: sorted.first!.date)
            let frequency: String
            if days >= 300 {
                frequency = "Yearly"
            } else if days >= 15 {
                frequency = "Monthly"
            } else {
                continue // too frequent to be a subscription (daily/weekly charges)
            }
            
            let displayName = cleanDisplayName(sorted.first?.name ?? key)
            
            let det = DetectedSubscription(
                id: key,
                name: displayName,
                amount: (avg * 100).rounded() / 100,
                currency: "USD",
                frequency: frequency,
                accountId: sorted.first?.accountId ?? "",
                lastChargeDate: sorted.first?.date ?? "",
                occurrences: txs.count,
                category: sorted.first?.category
            )
            results.append(det)
        }
        
        return results.sorted { $0.amount > $1.amount }
    }
    
    static func normalize(_ raw: String) -> String {
        var s = raw.lowercased()
        // Strip common prefixes
        for prefix in ["sq *", "tst*", "paypal *", "amzn mkt", "sp *", "apl*", "apl *", "apple.com/bill"] {
            if s.hasPrefix(prefix) { s = String(s.dropFirst(prefix.count)) }
        }
        // Strip noise suffixes
        s = s.replacingOccurrences(of: #"(\.com|digital|service|services|inc|llc|corp|ltd|co|payment|autopay|billing|recurring|#[0-9]+)"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"[^a-z0-9\s]"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        return s
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
    
    private static func dateDiff(from start: String, to end: String) -> Int {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        guard let d1 = df.date(from: start), let d2 = df.date(from: end) else { return 0 }
        return abs(Int(d2.timeIntervalSince(d1) / 86400))
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
                            .foregroundStyle(Color(hex: "#30D158"))
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
                                .background(Color(hex: "#30D158"))
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
            let existingNames = Set(appState.subscriptions.map { SubscriptionDetector.normalize($0.name) })
            let existingStreams = Set(appState.subscriptions.compactMap { $0.plaidStreamId })
            for det in detected {
                if existingNames.contains(det.id) || existingStreams.contains("detected_\(det.id)") {
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
        isAdding = det.id
        
        let session = try? await SupabaseService.shared.client.auth.session
        guard let userId = session?.user.id else {
            isAdding = nil
            return
        }
        
        // Find matching card from account id
        let matchCard = cardId != nil ? appState.cards.first(where: { $0.id == cardId }) :
            appState.cards.first(where: { $0.plaidAccountId == det.accountId })
        
        guard let targetCompanyId = companyId ?? matchCard?.companyId ?? appState.companies.first?.id else {
            isAdding = nil
            return
        }
        
        let newSub = Subscription(
            userId: userId,
            companyId: targetCompanyId,
            name: det.name,
            cost: det.amount,
            currency: det.currency,
            billingCycle: det.frequency,
            paymentMethod: matchCard.map { "\($0.network ?? "Card") •••• \($0.last4 ?? "")" },
            paymentMethodId: matchCard?.id,
            renew: "Auto",
            status: "Active",
            pricingModel: "paid",
            plaidStreamId: "detected_\(det.id)",
            plaidAccountId: det.accountId
        )
        
        do {
            // Insert directly so we get the real error if it fails
            try await DataRepository.shared.insertSubscription(newSub)
            await MainActor.run {
                appState.subscriptions.append(newSub)
                withAnimation(.spring(response: 0.35)) {
                    _ = added.insert(det.id)
                }
            }
        } catch {
            print("DetectedSubs addSubscription error: \(error)")
            await MainActor.run {
                appState.error = "Save failed: \(error.localizedDescription)"
            }
        }
        isAdding = nil
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
                    .background(isAdded ? Color(hex: "#30D158") : Color(hex: "#C1AA78"))
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
