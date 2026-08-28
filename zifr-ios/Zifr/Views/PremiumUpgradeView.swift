import SwiftUI
import StoreKit
import Observation

struct PremiumUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(AuthViewModel.self) private var authVM
    @Environment(AccessController.self) private var accessController

    var gate: PremiumGate? = nil

    @State private var isYearly = true
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var store = StoreService.shared

    private var selectedProduct: Product? {
        let productId = isYearly ? "com.miloom.premium.yearly" : "com.miloom.premium.monthly"
        return store.products.first { $0.id == productId }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.zifrBG.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    header
                    benefitList.padding(.top, 32)

                    if accessController.isPro {
                        activeMembership.padding(.top, 32)
                    } else {
                        pricingSelector.padding(.top, 32)
                        purchaseButton.padding(.top, 18)
                    }

                    footerActions.padding(.top, 18).padding(.bottom, 34)
                }
                .padding(.horizontal, 24)
            }
            closeButton
        }
        .task { await store.fetchProducts() }
        .alert("Unable to Complete Purchase", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.zifrGold.opacity(0.16))
                    .frame(width: 132, height: 132)
                    .blur(radius: 24)
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(hex: "#E6D39C"), Color.zifrGold], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            .padding(.top, 44)

            Text("EVERY COMPANY. EVERY CONNECTION.")
                .font(.system(size: 27, weight: .black))
                .tracking(0.6)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            Text(gate?.feature.upgradeReason ?? "Every detail across your businesses, connected and at your fingertips.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.62))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var benefitList: some View {
        VStack(spacing: 18) {
            ProBenefitRow(
                icon: "link", title: "See what connects to what",
                description: "Follow backlinks between companies, accounts, subscriptions, documents, and people."
            )
            ProBenefitRow(
                icon: "checklist.checked", title: "Know what needs attention",
                description: "Get a private Owner Briefing for renewals, expirations, stale accounts, and connected risks."
            )
            ProBenefitRow(
                icon: "sparkles", title: "Handle the busywork faster",
                description: "Use portfolio-aware AI, live voice, document filing, and consolidated reports."
            )
            HStack(spacing: 8) {
                ProAllowancePill(text: "Unlimited companies")
                ProAllowancePill(text: "10 institutions")
                ProAllowancePill(text: "3 guests")
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08)))
    }

    private var pricingSelector: some View {
        HStack(spacing: 8) {
            PricingChoice(
                title: "Monthly", price: priceText(forYearly: false),
                detail: trialDetail(forYearly: false), isSelected: !isYearly
            ) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isYearly = false }
            }
            PricingChoice(
                title: "Yearly", price: priceText(forYearly: true),
                detail: trialDetail(forYearly: true), isSelected: isYearly
            ) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isYearly = true }
            }
        }
    }

    private var purchaseButton: some View {
        Button { Task { await purchase() } } label: {
            HStack(spacing: 10) {
                if isPurchasing { ProgressView().tint(.white) }
                Text(isPurchasing ? "Processing…" : purchaseButtonTitle)
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                LinearGradient(colors: [Color(hex: "#A08F5D"), Color(hex: "#6F623F")], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.zifrGold.opacity(0.28), radius: 14, y: 5)
        }
        .disabled(isPurchasing || selectedProduct == nil)
        .opacity(selectedProduct == nil ? 0.55 : 1)
    }

    private var activeMembership: some View {
        VStack(spacing: 14) {
            Label(accessController.membershipSubtitle, systemImage: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.zifrGold)
            Button("Manage Subscription") {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") { openURL(url) }
            }
            .buttonStyle(MiloomPrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.zifrGold.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var footerActions: some View {
        VStack(spacing: 14) {
            if !accessController.isPro {
                Button("Restore Purchases") {
                    Task {
                        do { try await store.restore(accessController: accessController) }
                        catch { errorMessage = error.localizedDescription }
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.72))
            }
            HStack(spacing: 18) {
                Link("Terms", destination: URL(string: "https://miloom.com/terms")!)
                Link("Privacy", destination: URL(string: "https://miloom.com/privacy")!)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.45))

            if let selectedProduct {
                Text(disclosure(for: selectedProduct))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.38))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else if store.loadError != nil {
                Text("App Store pricing is unavailable. Check your connection and try again.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.orange.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var closeButton: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            .padding(.trailing, 18)
            .padding(.top, 14)
        }
    }

    private var purchaseButtonTitle: String {
        guard let selectedProduct, let trial = freeTrialText(for: selectedProduct) else { return "Continue with Pro" }
        return "Start \(trial) Free Trial"
    }

    private func priceText(forYearly yearly: Bool) -> String {
        let id = yearly ? "com.miloom.premium.yearly" : "com.miloom.premium.monthly"
        guard let product = store.products.first(where: { $0.id == id }) else { return "Loading…" }
        return product.displayPrice + (yearly ? "/yr" : "/mo")
    }

    private func trialDetail(forYearly yearly: Bool) -> String {
        let id = yearly ? "com.miloom.premium.yearly" : "com.miloom.premium.monthly"
        guard let product = store.products.first(where: { $0.id == id }) else { return "App Store price" }
        return freeTrialText(for: product).map { "\($0) free" } ?? "Cancel anytime"
    }

    private func disclosure(for product: Product) -> String {
        let trial = freeTrialText(for: product).map { "After the \($0.lowercased()) free trial, " } ?? ""
        let period = isYearly ? "year" : "month"
        return "\(trial)your Apple ID will be charged \(product.displayPrice) per \(period). The subscription renews automatically unless canceled at least 24 hours before the end of the current period."
    }

    private func freeTrialText(for product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        let value = offer.period.value
        let unit: String
        switch offer.period.unit {
        case .day: unit = value == 1 ? "Day" : "Days"
        case .week: unit = value == 1 ? "Week" : "Weeks"
        case .month: unit = value == 1 ? "Month" : "Months"
        case .year: unit = value == 1 ? "Year" : "Years"
        @unknown default: unit = "Days"
        }
        return "\(value)-\(unit)"
    }

    private func purchase() async {
        guard let product = selectedProduct, let userId = authVM.currentUser?.id else {
            errorMessage = "App Store pricing is still loading. Please try again."
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let outcome = try await store.purchase(product, appAccountToken: userId, accessController: accessController)
            if outcome == .purchased { dismiss() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ProBenefitRow: View {
    let icon: String
    let title: String
    let description: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Color.zifrGold)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.54))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct ProAllowancePill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.white.opacity(0.74))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())
    }
}

private struct PricingChoice: View {
    let title: String
    let price: String
    let detail: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title).font(.system(size: 13, weight: .bold))
                Text(price).font(.system(size: 17, weight: .black))
                Text(detail).font(.system(size: 10, weight: .medium)).opacity(0.7)
            }
            .foregroundStyle(isSelected ? .white : Color.white.opacity(0.46))
            .frame(maxWidth: .infinity)
            .frame(height: 88)
            .background(isSelected ? Color.zifrGold.opacity(0.16) : Color.white.opacity(0.045))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(isSelected ? Color.zifrGold.opacity(0.7) : Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}

enum StorePurchaseOutcome: Equatable {
    case purchased
    case cancelled
    case pending
}

@MainActor
@Observable
final class StoreService {
    static let shared = StoreService()

    var products: [Product] = []
    var loadError: String?
    private var updatesTask: Task<Void, Never>?
    private let productIDs = ["com.miloom.premium.monthly", "com.miloom.premium.yearly"]

    private init() {}

    func startListening(accessController: AccessController) {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in StoreKit.Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.checkVerified(update)
                    try await self.sync(transactionResult: update, transaction: transaction, accessController: accessController)
                    await transaction.finish()
                } catch {
                    self.loadError = error.localizedDescription
                }
            }
        }
    }

    func fetchProducts() async {
        do {
            products = try await Product.products(for: productIDs).sorted { $0.price < $1.price }
            loadError = products.isEmpty ? "No subscription products were returned by the App Store." : nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    func purchase(_ product: Product, appAccountToken: UUID, accessController: AccessController) async throws -> StorePurchaseOutcome {
        let result = try await product.purchase(options: [.appAccountToken(appAccountToken)])
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            try await sync(transactionResult: verification, transaction: transaction, accessController: accessController)
            await transaction.finish()
            return .purchased
        case .userCancelled: return .cancelled
        case .pending: return .pending
        @unknown default: return .pending
        }
    }

    func restore(accessController: AccessController) async throws {
        try await AppStore.sync()
        var restored = false
        for await result in StoreKit.Transaction.currentEntitlements {
            let transaction = try checkVerified(result)
            guard productIDs.contains(transaction.productID), transaction.revocationDate == nil else { continue }
            try await sync(transactionResult: result, transaction: transaction, accessController: accessController)
            restored = true
        }
        if !restored { await accessController.refresh() }
    }

    private func sync(
        transactionResult: VerificationResult<StoreKit.Transaction>,
        transaction: StoreKit.Transaction,
        accessController: AccessController
    ) async throws {
        accessController.applyLocallyVerified(
            productID: transaction.productID,
            expirationDate: transaction.expirationDate,
            isTrial: false
        )

        guard let session = try? await SupabaseService.shared.client.auth.session else { return }
        let url = URL(string: "\(SupabaseService.shared.urlString)/functions/v1/sync-entitlement")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["signedTransaction": transactionResult.jwsRepresentation])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "Server verification failed."
            throw StoreError.serverVerification(message)
        }
        var verified = try JSONDecoder().decode(AccessSnapshot.self, from: data)
        verified.validatedAt = Date()
        accessController.applyServerVerified(verified)
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.failedVerification
        case .verified(let safe): return safe
        }
    }

    enum StoreError: LocalizedError {
        case failedVerification
        case serverVerification(String)
        var errorDescription: String? {
            switch self {
            case .failedVerification: return "The App Store transaction could not be verified."
            case .serverVerification(let message): return message
            }
        }
    }
}
