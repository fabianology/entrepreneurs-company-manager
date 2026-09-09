import SwiftUI
import StoreKit
import Observation

struct PremiumUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(AuthViewModel.self) private var authVM
    @Environment(AccessController.self) private var accessController

    var gate: PremiumGate? = nil

    @State private var isYearly = false
    @State private var isShowingAllBenefits = false
    @State private var introEligibleProductIDs: Set<Product.ID> = []
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?
    @State private var store = StoreService.shared

    private var selectedProduct: Product? {
        let productId = isYearly ? "com.miloom.premium.yearly" : "com.miloom.premium.monthly"
        return store.products.first { $0.id == productId }
    }

    var body: some View {
        ConversionPaywallContent(
            gate: gate,
            isPro: accessController.isPro,
            membershipSubtitle: accessController.membershipSubtitle,
            isYearly: $isYearly,
            isShowingAllBenefits: $isShowingAllBenefits,
            isEligibleForTrial: selectedProduct.map { introEligibleProductIDs.contains($0.id) } ?? false,
            isPurchasing: isPurchasing,
            isRestoring: isRestoring,
            monthlyProduct: product(forYearly: false),
            yearlyProduct: product(forYearly: true),
            loadError: store.loadError,
            dismiss: { dismiss() },
            purchase: { Task { await purchase() } },
            restore: {
                Task {
                    guard !isRestoring else { return }
                    isRestoring = true
                    defer { isRestoring = false }
                    do {
                        let restored = try await store.restore(accessController: accessController)
                        if !restored {
                            errorMessage = "No active Miloom Pro subscription was found for this Apple ID."
                        }
                    }
                    catch { errorMessage = error.localizedDescription }
                }
            },
            manageSubscription: {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") { openURL(url) }
            }
        )
        .task { await loadProducts() }
        .alert("Miloom Pro", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private func product(forYearly yearly: Bool) -> Product? {
        let id = yearly ? "com.miloom.premium.yearly" : "com.miloom.premium.monthly"
        return store.products.first { $0.id == id }
    }

    private func loadProducts() async {
        await store.fetchProducts()
        if product(forYearly: true) == nil, product(forYearly: false) != nil {
            isYearly = false
        } else if product(forYearly: false) == nil, product(forYearly: true) != nil {
            isYearly = true
        }
        var eligibleIDs: Set<Product.ID> = []
        for product in store.products {
            guard product.subscription?.introductoryOffer?.paymentMode == .freeTrial,
                  let subscription = product.subscription else { continue }
            if await subscription.isEligibleForIntroOffer {
                eligibleIDs.insert(product.id)
            }
        }
        introEligibleProductIDs = eligibleIDs
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
            switch outcome {
            case .purchased:
                dismiss()
            case .pending:
                errorMessage = "Your purchase is pending approval. Miloom Pro will unlock automatically when the App Store completes it."
            case .cancelled:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct RaisedMiloomButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color(hex: "#171914"))
            .background(
                LinearGradient(
                    colors: [Color(hex: "#D1BE91"), Color.miloomGold],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.32), lineWidth: 1)
            }
            .shadow(
                color: configuration.isPressed ? Color.black.opacity(0.22) : Color.black.opacity(0.46),
                radius: configuration.isPressed ? 4 : 10,
                x: 0,
                y: configuration.isPressed ? 2 : 7
            )
            .shadow(color: Color.miloomGold.opacity(configuration.isPressed ? 0.12 : 0.24), radius: 14, y: 5)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct ConversionPaywallContent: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let gate: PremiumGate?
    let isPro: Bool
    let membershipSubtitle: String
    @Binding var isYearly: Bool
    @Binding var isShowingAllBenefits: Bool
    let isEligibleForTrial: Bool
    let isPurchasing: Bool
    let isRestoring: Bool
    let monthlyProduct: Product?
    let yearlyProduct: Product?
    let loadError: String?
    let dismiss: () -> Void
    let purchase: () -> Void
    let restore: () -> Void
    let manageSubscription: () -> Void

    private var selectedProduct: Product? { isYearly ? yearlyProduct : monthlyProduct }

    var body: some View {
        ZStack {
            Color(hex: "#1A1B1A").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    topBar
                    headline.padding(.top, 4)
                    productPreview.padding(.top, 14)

                    if isPro {
                        activeMembership.padding(.top, 18)
                    } else {
                        comparison.padding(.top, 16)
                        allBenefits
                        planSelector.padding(.top, 18)
                        billingTimeline.padding(.top, 16)
                        primaryAction.padding(.top, 12)
                    }

                    footer.padding(.top, 8).padding(.bottom, 24)
                }
                .padding(.horizontal, 22)
            }
            .background(Color(hex: "#0B0D0C"))
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .stroke(Color(hex: "#35352E"), lineWidth: 1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .statusBarHidden(true)
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Text("miloom")
                .font(.system(size: 21, weight: .semibold))
                .tracking(-0.7)
                .foregroundStyle(Color.white.opacity(0.95))

            Text("PRO")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(Color.miloomGold)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.miloomGold.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.miloomGold.opacity(0.30), lineWidth: 1)
                }

            Spacer()

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.045))
                    .clipShape(Circle())
                    .overlay { Circle().stroke(Color.white.opacity(0.12), lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.top, 10)
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 9) {
            (
                Text(headlinePrimary).foregroundStyle(Color.white.opacity(0.96))
                + Text("\n\(headlineAccent)").foregroundStyle(Color.miloomGold)
            )
            .font(.system(size: 34, weight: .semibold))
            .tracking(-1.2)

            Text(headlineSubtitle)
                .font(.system(size: 14))
                .foregroundStyle(Color.white.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
    }

    private var productPreview: some View {
        ZStack {
            Color(hex: "#1B2E2C")

            Ellipse()
                .fill(Color.miloomGold.opacity(0.08))
                .overlay {
                    Ellipse().stroke(Color.miloomGold.opacity(0.31), lineWidth: 20)
                }
                .frame(width: 220, height: 154)
                .rotationEffect(.degrees(-25))
                .offset(x: 116, y: -54)

            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 8) {
                    Image(systemName: "checklist.checked")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Owner Briefing")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("EXAMPLE")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(0.6)
                        .foregroundStyle(Color.white.opacity(0.70))
                }

                HStack(spacing: 8) {
                    Text("Software renewal")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text("Due tomorrow")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "#E9E5BC"))
                }
            }
            .foregroundStyle(Color.white.opacity(0.92))
            .padding(.horizontal, 15)
            .padding(.vertical, 14)
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(Color(hex: "#25382E"))
                } else {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(Color.white.opacity(0.32), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.26), radius: 16, y: 8)
            .padding(12)
        }
        .frame(minHeight: 104)
        .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Owner Briefing example. Software renewal due tomorrow.")
    }

    private var comparison: some View {
        VStack(spacing: 0) {
            ConversionComparisonRow(feature: "Your upgrade", free: "Free", pro: "Pro", isHeader: true)
            ConversionComparisonRow(feature: "Companies", free: "1", pro: "Unlimited")
            ConversionComparisonRow(feature: "Live institutions", free: "1", pro: "10")
            ConversionComparisonRow(feature: "Owner Briefing", free: "—", pro: "Included")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Miloom Free and Pro comparison")
    }

    private var allBenefits: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isShowingAllBenefits.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isShowingAllBenefits ? "chevron.down" : "play.fill")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 10)
                    Text("See everything included in Pro")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                }
                .foregroundStyle(Color.white.opacity(0.66))
                .contentShape(Rectangle())
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)

            if isShowingAllBenefits {
                VStack(alignment: .leading, spacing: 9) {
                    ConversionBenefitBullet(text: "500 uploaded documents, up from 20 on Free")
                    ConversionBenefitBullet(text: "Up to 3 guests")
                    ConversionBenefitBullet(text: "Portfolio-aware AI and live voice, subject to fair use")
                    ConversionBenefitBullet(text: "Connections between companies, accounts, subscriptions, documents, and people")
                }
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1)
        }
    }

    private var planSelector: some View {
        HStack(spacing: 9) {
            ConversionPlanChoice(
                title: "Yearly",
                price: priceText(yearly: true),
                detail: yearlyEquivalentText,
                savings: annualSavingsText,
                isSelected: isYearly,
                isAvailable: yearlyProduct != nil
            ) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isYearly = true }
            }

            ConversionPlanChoice(
                title: "Monthly",
                price: priceText(yearly: false),
                detail: "Billed monthly",
                savings: nil,
                isSelected: !isYearly,
                isAvailable: monthlyProduct != nil
            ) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isYearly = false }
            }
        }
    }

    private var billingTimeline: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                ConversionBillingStep(
                    title: hasTrial ? "Today · \(zeroPrice)" : "Today · \(selectedProduct?.displayPrice ?? "App Store price")",
                    detail: "Full Pro access"
                )
                ConversionBillingStep(
                    title: hasTrial ? "In \(introductoryPeriodText)" : "In \(renewalPeriodText)",
                    detail: "\(selectedProduct?.displayPrice ?? "App Store price"), then \(isYearly ? "yearly" : "monthly")"
                )
            }

            Text(cancelDisclosure)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.60))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
    }

    private var primaryAction: some View {
        Button(action: purchase) {
            HStack(spacing: 12) {
                if isPurchasing {
                    ProgressView().tint(Color(hex: "#1B271A"))
                }
                Text(isPurchasing ? "Processing…" : purchaseButtonTitle)
                    .font(.system(size: 16, weight: .bold))
                if !isPurchasing {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .foregroundStyle(Color(hex: "#1B271A"))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#EEF0DF"), Color(hex: "#DBE1C7")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(Capsule())
            .overlay { Capsule().stroke(Color.white.opacity(0.72), lineWidth: 1) }
            .shadow(color: Color(hex: "#DBE1C7").opacity(0.12), radius: 18, y: 5)
        }
        .buttonStyle(ConversionCTAButtonStyle())
        .disabled(isPurchasing || selectedProduct == nil)
        .opacity(selectedProduct == nil ? 0.55 : 1)
    }

    private var activeMembership: some View {
        VStack(spacing: 14) {
            Label(membershipSubtitle, systemImage: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.miloomGold)

            Button(action: manageSubscription) {
                HStack(spacing: 10) {
                    Text("Manage Subscription")
                        .font(.system(size: 16, weight: .bold))
                    Spacer(minLength: 12)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .black))
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
            }
            .buttonStyle(RaisedMiloomButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            HStack(spacing: 20) {
                if !isPro {
                    Button(action: restore) {
                        HStack(spacing: 6) {
                            if isRestoring { ProgressView().controlSize(.small) }
                            Text(isRestoring ? "Restoring…" : "Restore")
                        }
                    }
                    .disabled(isRestoring || isPurchasing)
                }
                Link("Terms", destination: URL(string: "https://miloom.com/terms")!)
                Link("Privacy", destination: URL(string: "https://miloom.com/privacy")!)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.58))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)

            if !isPro, loadError != nil {
                Text("App Store pricing is unavailable. Check your connection and try again.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.miloomGold.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var headlinePrimary: String {
        switch gate?.feature {
        case .additionalCompany: return "Your next company."
        case .ownerBriefing: return "Know what needs"
        default: return "Every company."
        }
    }

    private var headlineAccent: String {
        switch gate?.feature {
        case .additionalCompany: return "Already connected."
        case .ownerBriefing: return "your attention."
        default: return "One clear picture."
        }
    }

    private var headlineSubtitle: String {
        switch gate?.feature {
        case .additionalCompany:
            return "Free includes one company. Bring every business into a single portfolio with Pro."
        case .ownerBriefing:
            return "Bring renewals, expirations, and stale accounts into one Owner Briefing."
        case .some(let feature):
            return feature.upgradeReason
        case .none:
            return "See what’s connected—and what needs your attention—across your businesses."
        }
    }

    private var hasTrial: Bool {
        guard isEligibleForTrial,
              let offer = selectedProduct?.subscription?.introductoryOffer else { return false }
        return offer.paymentMode == .freeTrial
    }

    private var purchaseButtonTitle: String {
        hasTrial ? "Start \(introductoryPeriodText) free trial" : "Subscribe to Pro"
    }

    private var introductoryPeriodText: String {
        selectedProduct?.subscription?.introductoryOffer.map { periodText($0.period) } ?? "trial"
    }

    private var renewalPeriodText: String {
        selectedProduct?.subscription.map { periodText($0.subscriptionPeriod) } ?? (isYearly ? "1 year" : "1 month")
    }

    private var zeroPrice: String {
        guard let selectedProduct else { return "$0" }
        return Decimal.zero.formatted(selectedProduct.priceFormatStyle)
    }

    private var cancelDisclosure: String {
        if hasTrial {
            return "Auto-renews. To avoid a charge, cancel in App Store settings at least 24 hours before your trial ends."
        }
        return "Auto-renews \(isYearly ? "yearly" : "monthly"). Cancel in App Store settings at least 24 hours before renewal."
    }

    private func priceText(yearly: Bool) -> String {
        let product = yearly ? yearlyProduct : monthlyProduct
        guard let product else { return "Loading…" }
        return product.displayPrice + (yearly ? "/year" : "/month")
    }

    private var yearlyEquivalentText: String {
        guard let yearlyProduct else { return "App Store price" }
        return "\((yearlyProduct.price / 12).formatted(yearlyProduct.priceFormatStyle))/mo equivalent"
    }

    private var annualSavingsText: String? {
        guard let yearlyProduct, let monthlyProduct else { return nil }
        let monthlyAnnualized = NSDecimalNumber(decimal: monthlyProduct.price * 12).doubleValue
        let annual = NSDecimalNumber(decimal: yearlyProduct.price).doubleValue
        guard monthlyAnnualized > 0, annual < monthlyAnnualized else { return nil }
        return "Save \(Int(((1 - annual / monthlyAnnualized) * 100).rounded()))%"
    }

    private func periodText(_ period: Product.SubscriptionPeriod) -> String {
        let value = period.value
        let unit: String
        switch period.unit {
        case .day: unit = value == 1 ? "day" : "days"
        case .week: unit = value == 1 ? "week" : "weeks"
        case .month: unit = value == 1 ? "month" : "months"
        case .year: unit = value == 1 ? "year" : "years"
        @unknown default: unit = "days"
        }
        return "\(value) \(unit)"
    }
}

private struct ConversionComparisonRow: View {
    let feature: String
    let free: String
    let pro: String
    var isHeader = false

    var body: some View {
        HStack(spacing: 8) {
            Text(feature)
                .foregroundStyle(isHeader ? Color.white.opacity(0.90) : Color.white.opacity(0.78))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(free)
                .foregroundStyle(Color.white.opacity(0.50))
                .frame(width: 52, alignment: .center)
            Text(pro)
                .foregroundStyle(Color.miloomGold)
                .frame(width: 88, alignment: .trailing)
        }
        .font(.system(size: isHeader ? 11 : 12, weight: isHeader ? .medium : .regular))
        .padding(.vertical, isHeader ? 8 : 10)
        .overlay(alignment: .top) {
            if !isHeader {
                Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1)
            }
        }
    }
}

private struct ConversionBenefitBullet: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.miloomGold)
                .frame(width: 4, height: 4)
                .padding(.top, 7)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ConversionPlanChoice: View {
    let title: String
    let price: String
    let detail: String
    let savings: String?
    let isSelected: Bool
    let isAvailable: Bool
    let action: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(title)
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        ZStack {
                            Circle()
                                .stroke(isSelected ? Color.miloomGold : Color.white.opacity(0.42), lineWidth: 1)
                                .frame(width: 18, height: 18)
                            if isSelected {
                                Circle().fill(Color.miloomGold).frame(width: 18, height: 18)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(Color(hex: "#20251A"))
                            }
                        }
                    }

                    Text(price)
                        .font(.system(size: 18, weight: .semibold))
                        .tracking(-0.4)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.64))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .foregroundStyle(Color.white.opacity(isSelected ? 0.94 : 0.72))
                .padding(.horizontal, 12)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
                .background(isSelected ? Color(hex: "#20231B") : Color(hex: "#151815"))
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(isSelected ? Color.miloomGold : Color.white.opacity(0.16), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .disabled(!isAvailable)
            .opacity(isAvailable ? 1 : 0.55)

            if let savings {
                Text(savings)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color(hex: "#22261B"))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.miloomGold)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .offset(x: -11, y: -9)
            }
        }
    }
}

private struct ConversionBillingStep: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Rectangle()
                .fill(Color.white.opacity(0.25))
                .frame(height: 1)
                .overlay(alignment: .leading) {
                    Circle().fill(Color.miloomGold).frame(width: 7, height: 7)
                }
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.90))
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.62))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ConversionCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
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

    @discardableResult
    func restore(accessController: AccessController) async throws -> Bool {
        try await AppStore.sync()
        var restored = false
        for await result in StoreKit.Transaction.currentEntitlements {
            let transaction = try checkVerified(result)
            guard productIDs.contains(transaction.productID), transaction.revocationDate == nil else { continue }
            try await sync(transactionResult: result, transaction: transaction, accessController: accessController)
            restored = true
        }
        if !restored { await accessController.refresh() }
        return restored
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
