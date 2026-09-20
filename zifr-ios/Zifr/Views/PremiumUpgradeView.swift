import SwiftUI
import StoreKit
import Observation

struct PremiumUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AuthViewModel.self) private var authVM
    @Environment(AccessController.self) private var accessController

    var gate: PremiumGate? = nil

    @State private var isYearly = false
    @State private var isShowingAllBenefits = false
    @State private var introEligibleProductIDs: Set<Product.ID> = []
    @State private var isLoadingProducts = true
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
            isPro: accessController.hasProSubscription,
            membershipSubtitle: accessController.membershipSubtitle,
            isYearly: $isYearly,
            isShowingAllBenefits: $isShowingAllBenefits,
            isEligibleForIntroOffer: selectedProduct.map { introEligibleProductIDs.contains($0.id) } ?? false,
            isLoadingProducts: isLoadingProducts,
            isPurchasing: isPurchasing,
            isRestoring: isRestoring,
            monthlyProduct: product(forYearly: false),
            yearlyProduct: product(forYearly: true),
            loadError: store.loadError,
            dismiss: { dismiss() },
            purchase: { Task { await purchase() } },
            restore: { Task { await restore() } },
            retry: { Task { await loadProducts() } },
            manageSubscription: {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") { openURL(url) }
            }
        )
        .task {
            if accessController.isBetaAccessActive {
                accessController.pendingGate = nil
                dismiss()
                return
            }
            await loadProducts()
            await store.retryUnfinishedTransactions(accessController: accessController)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, store.products.count < 2 else { return }
            Task { await loadProducts() }
        }
        .onChange(of: accessController.hasProSubscription) { wasPro, isPro in
            // An Ask to Buy approval can arrive while this paywall remains open.
            if !wasPro, isPro, !isPurchasing, !isRestoring {
                accessController.pendingGate = nil
                dismiss()
            }
        }
        .onChange(of: accessController.isBetaAccessActive) { _, hasBetaAccess in
            if hasBetaAccess {
                accessController.pendingGate = nil
                dismiss()
            }
        }
        .interactiveDismissDisabled(isPurchasing || isRestoring)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(36)
        .presentationBackground(Color(hex: "#0B0D0C"))
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
        isLoadingProducts = true
        introEligibleProductIDs = []
        defer { isLoadingProducts = false }
        await store.fetchProducts()
        if product(forYearly: true) == nil, product(forYearly: false) != nil {
            isYearly = false
        } else if product(forYearly: false) == nil, product(forYearly: true) != nil {
            isYearly = true
        }
        var eligibleIDs: Set<Product.ID> = []
        for product in store.products {
            guard let subscription = product.subscription,
                  subscription.introductoryOffer != nil else { continue }
            if await subscription.isEligibleForIntroOffer {
                eligibleIDs.insert(product.id)
            }
        }
        introEligibleProductIDs = eligibleIDs
    }

    private func purchase() async {
        guard !isPurchasing, !isRestoring, !isLoadingProducts else { return }
        guard let product = selectedProduct else {
            errorMessage = "App Store pricing is unavailable. Please try again."
            return
        }
        guard let userId = authVM.currentUser?.id else {
            errorMessage = "Please sign in to your Miloom account before subscribing."
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let outcome = try await store.purchase(product, appAccountToken: userId, accessController: accessController)
            switch outcome {
            case .purchased:
                accessController.pendingGate = nil
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

    private func restore() async {
        guard !isPurchasing, !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }
        do {
            if try await store.restore(accessController: accessController) {
                accessController.pendingGate = nil
                dismiss()
                return
            } else {
                errorMessage = "No active Miloom Pro subscription was found for this Apple ID."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        await loadProducts()
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

struct ConversionPaywallContent: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let gate: PremiumGate?
    let isPro: Bool
    let membershipSubtitle: String
    @Binding var isYearly: Bool
    @Binding var isShowingAllBenefits: Bool
    let isEligibleForIntroOffer: Bool
    let isLoadingProducts: Bool
    let isPurchasing: Bool
    let isRestoring: Bool
    let monthlyProduct: Product?
    let yearlyProduct: Product?
    let loadError: String?
    let dismiss: () -> Void
    let purchase: () -> Void
    let restore: () -> Void
    let retry: () -> Void
    let manageSubscription: () -> Void
    var reduceTransparencyOverride: Bool? = nil

    private var selectedProduct: Product? { isYearly ? yearlyProduct : monthlyProduct }

    private var billing: PaywallBillingTerms? {
        selectedProduct.map { PaywallBillingTerms(product: $0, isEligibleForIntroOffer: isEligibleForIntroOffer) }
    }
    private var isBusy: Bool { isPurchasing || isRestoring }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                topBar.padding(.bottom, 11)
                headline
                productPreview.padding(.top, 14)

                if isPro {
                    activeMembership.padding(.top, 18)
                } else {
                    comparison.padding(.top, 14)
                    allBenefits
                    planSelector.padding(.top, 17)
                    billingTimeline.padding(.top, 15)
                    primaryAction.padding(.top, 11)
                    continueFreeAction
                }

                footer.padding(.top, 3)
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 10)
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity)
        }
        .background(Color(hex: "#0B0D0C").ignoresSafeArea())
        .preferredColorScheme(.dark)
        .overlay(alignment: .topTrailing) {
            closeButton
                .padding(.top, 16)
                .padding(.trailing, 22)
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Text("miloom")
                .font(.system(size: 20, weight: .semibold))
                .tracking(-0.7)
                .foregroundStyle(Color.white.opacity(0.95))

            Text("PRO")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.7)
                .foregroundStyle(Color.paywallGold)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.paywallGold.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.paywallGold.opacity(0.30), lineWidth: 1)
                }

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
    }

    private var closeButton: some View {
        Button(action: dismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.78))
                .frame(width: 44, height: 44)
                .background(Color(hex: "#151815").opacity(0.96))
                .clipShape(Circle())
                .overlay { Circle().stroke(Color.white.opacity(0.16), lineWidth: 1) }
                .shadow(color: .black.opacity(0.32), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close and continue with Miloom Free")
        .accessibilityIdentifier("paywall.close")
        .disabled(isBusy)
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 10) {
            (
                Text(headlinePrimary).foregroundStyle(Color.white.opacity(0.96))
                + Text("\n\(headlineAccent)").foregroundStyle(Color.paywallGold)
            )
            .font(.system(size: 34, weight: .semibold))
            .lineSpacing(-4)
            .fixedSize(horizontal: false, vertical: true)
            .tracking(-1.2)

            Text(headlineSubtitle)
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "#B8BCB4"))
                .frame(maxWidth: 315, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
    }

    private var productPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.system(size: 15, weight: .semibold))
                Text("Owner Briefing")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("Example")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: "#E1E6D9"))
            }
            .frame(minHeight: 21)

            HStack(spacing: 8) {
                Text("Software renewal")
                    .font(.system(size: 12))
                Spacer()
                Text("Due tomorrow")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#E9E5BC"))
            }
            .frame(minHeight: 19)
        }
        .foregroundStyle(Color.white.opacity(0.92))
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 80)
        .background {
            if reduceTransparencyOverride ?? reduceTransparency {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color(hex: "#25382E"))
            } else {
                // Blur only the decorative backdrop, retaining the concept's clear tint on iOS 17.
                previewBackdrop(inset: 12)
                    .blur(radius: 7)
                    .overlay {
                        LinearGradient(colors: [.white.opacity(0.09), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(
                    LinearGradient(colors: [.white.opacity(0.68), .white.opacity(0.38)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
        }
        .shadow(color: Color.black.opacity(0.26), radius: 16, y: 8)
        .padding(12)
        .frame(minHeight: 104)
        .background { previewBackdrop() }
        .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Owner Briefing example. Software renewal due tomorrow.")
    }

    private func previewBackdrop(inset: CGFloat = 0) -> some View {
        Color(hex: "#1B2E2C")
            .overlay(alignment: .topTrailing) {
                Ellipse()
                    .fill(Color(hex: "#C4B677").opacity(0.09))
                    .overlay { Ellipse().strokeBorder(Color(hex: "#C4B677").opacity(0.45), lineWidth: 24) }
                    // The reference's 230×165 content box includes a 24pt border on each side.
                    .frame(width: 278, height: 213)
                    .rotationEffect(.degrees(-28))
                    .offset(x: 42 + inset, y: -46 - inset)
            }
            .clipped()
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
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    isShowingAllBenefits.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    DisclosureStateChevron(isExpanded: isShowingAllBenefits)
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 10)
                    Text("See everything included in Pro")
                        .font(.system(size: 11))
                    Spacer()
                }
                .foregroundStyle(Color.white.opacity(0.66))
                .contentShape(Rectangle())
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityValue(isShowingAllBenefits ? "Expanded" : "Collapsed")
            .accessibilityIdentifier("paywall.benefits")

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
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 16)) : AnyLayout(HStackLayout(spacing: 9))
        return layout {
            ConversionPlanChoice(
                title: "Yearly",
                price: priceText(yearly: true),
                detail: yearlyEquivalentText,
                savings: PaywallBillingTerms.annualSavings(monthly: monthlyProduct, yearly: yearlyProduct),
                isSelected: isYearly,
                isAvailable: yearlyProduct != nil && !isBusy && !isLoadingProducts
            ) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) { isYearly = true }
            }

            ConversionPlanChoice(
                title: "Monthly",
                price: priceText(yearly: false),
                detail: "Billed monthly",
                savings: nil,
                isSelected: !isYearly,
                isAvailable: monthlyProduct != nil && !isBusy && !isLoadingProducts
            ) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) { isYearly = false }
            }
        }
    }

    private var billingTimeline: some View {
        VStack(spacing: 11) {
            if let billing, !isLoadingProducts {
                HStack(alignment: .top, spacing: 10) {
                    ConversionBillingStep(title: billing.todayTitle, detail: billing.todayDetail)
                    ConversionBillingStep(title: billing.nextTitle, detail: billing.nextDetail)
                }
                Text(billing.disclosure)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "#ADB6A5"))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            } else {
                Text(isLoadingProducts ? "Loading App Store prices and offers…" : "Subscriptions aren’t available right now. Continue with Free or try loading prices again.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#ADB6A5"))
                    .frame(maxWidth: .infinity, minHeight: 62)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var primaryAction: some View {
        let shouldRetry = !isLoadingProducts && selectedProduct == nil
        return Button(action: shouldRetry ? retry : purchase) {
            HStack(spacing: 12) {
                if isPurchasing {
                    ProgressView().tint(Color(hex: "#1B271A"))
                }
                Text(
                    isPurchasing ? "Processing…"
                    : isLoadingProducts ? "Loading…"
                    : shouldRetry ? "Try loading prices again"
                    : billing?.buttonTitle ?? "Subscribe to Pro"
                )
                    .font(.system(size: 15, weight: .semibold))
                if !isPurchasing {
                    Image(systemName: shouldRetry ? "arrow.clockwise" : "arrow.right")
                        .font(.system(size: 17, weight: .regular))
                }
            }
            .foregroundStyle(Color(hex: "#1B271A"))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
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
        .disabled(isBusy || isLoadingProducts)
        .accessibilityIdentifier("paywall.purchase")
        .opacity(isLoadingProducts ? 0.55 : 1)
    }

    private var continueFreeAction: some View {
        Button(action: dismiss) {
            Text("Continue with Free")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.78))
                .frame(maxWidth: .infinity, minHeight: 46)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityHint("Closes this screen. You can upgrade later from Account.")
        .accessibilityIdentifier("paywall.continue-free")
    }

    private var activeMembership: some View {
        VStack(spacing: 14) {
            Label(membershipSubtitle, systemImage: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.paywallGold)

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
                Text("App Store pricing could not load. You can keep using Miloom Free and try again later.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.paywallGold.opacity(0.85))
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

    private func priceText(yearly: Bool) -> String {
        guard let product = yearly ? yearlyProduct : monthlyProduct else {
            return isLoadingProducts ? "Loading…" : "Unavailable"
        }
        return product.displayPrice + PaywallBillingTerms.priceSuffix(product)
    }

    private var yearlyEquivalentText: String {
        guard let yearlyProduct else { return "Billed yearly" }
        return "\((yearlyProduct.price / 12).formatted(yearlyProduct.priceFormatStyle))/mo equivalent"
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
                .frame(width: 48, alignment: .center)
            Text(pro)
                .foregroundStyle(Color.paywallGold)
                .frame(width: 90, alignment: .trailing)
        }
        .font(.system(size: isHeader ? 11 : 12, weight: isHeader ? .medium : .regular))
        .padding(.top, isHeader ? 0 : 9)
        .padding(.bottom, isHeader ? 8 : 9)
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
                .fill(Color.paywallGold)
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
                                .stroke(isSelected ? Color.paywallGold : Color.white.opacity(0.42), lineWidth: 1)
                                .frame(width: 18, height: 18)
                            if isSelected {
                                Circle().fill(Color.paywallGold).frame(width: 18, height: 18)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(Color(hex: "#20251A"))
                            }
                        }
                    }

                    Text(price)
                        .font(.system(size: 20, weight: .medium))
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
                        .stroke(isSelected ? Color.paywallGold : Color.white.opacity(0.16), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .disabled(!isAvailable)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityIdentifier("paywall.plan.\(title.lowercased())")
            .opacity(isAvailable ? 1 : 0.55)

            if let savings {
                Text(savings)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color(hex: "#22261B"))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.paywallGold)
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
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.25))
                .frame(height: 1)
                .overlay(alignment: .leading) {
                    Circle().fill(Color.paywallGold).frame(width: 7, height: 7)
                }
            Text(title)
                .padding(.top, 12)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.90))
            Text(detail)
                .padding(.top, 4)
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

/// StoreKit is the single source of truth for every price and introductory-offer claim.
struct PaywallBillingTerms {
    let product: Product
    let isEligibleForIntroOffer: Bool

    private var offer: Product.SubscriptionOffer? {
        isEligibleForIntroOffer ? product.subscription?.introductoryOffer : nil
    }
    var hasTrial: Bool { offer?.paymentMode == .freeTrial }
    private var cadence: String {
        guard let period = product.subscription?.subscriptionPeriod else { return "each billing period" }
        switch (period.unit, period.value) {
        case (.month, 1): return "monthly"
        case (.year, 1): return "yearly"
        case (.week, 1): return "weekly"
        default: return "every \(Self.periodText(period))"
        }
    }
    private var introDuration: String {
        guard let offer else { return "" }
        return Self.periodText(offer.period, count: offer.periodCount, expandWeeks: true)
    }
    var buttonTitle: String {
        guard hasTrial else { return "Subscribe to Pro" }
        let duration = introDuration.hasSuffix("s") ? String(introDuration.dropLast()) : introDuration
        return "Start \(duration.replacingOccurrences(of: " ", with: "-")) free trial"
    }
    var todayTitle: String {
        "Today · \(offer?.displayPrice ?? product.displayPrice)"
    }
    var todayDetail: String {
        guard let offer, offer.paymentMode == .payAsYouGo else { return "Full Pro access" }
        return "\(offer.displayPrice) every \(Self.periodText(offer.period)) for \(introDuration)"
    }
    var nextTitle: String {
        if offer != nil { return "In \(introDuration)" }
        guard let period = product.subscription?.subscriptionPeriod else { return "At renewal" }
        return "In \(Self.periodText(period))"
    }
    var nextDetail: String { "\(product.displayPrice), then \(cadence)" }
    var disclosure: String {
        if hasTrial {
            return "Auto-renews. To avoid a charge, cancel in App Store settings at least 24 hours before your trial ends."
        }
        if offer != nil {
            return "Introductory price for \(introDuration), then \(product.displayPrice) \(cadence). Auto-renews. Cancel in App Store settings at least 24 hours before renewal."
        }
        return "Auto-renews \(cadence). Cancel in App Store settings at least 24 hours before renewal."
    }

    static func priceSuffix(_ product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else { return "" }
        return "/" + periodText(period, omitOne: true)
    }

    static func annualSavings(monthly: Product?, yearly: Product?) -> String? {
        guard let monthly, let yearly,
              monthly.priceFormatStyle.currencyCode == yearly.priceFormatStyle.currencyCode,
              monthly.subscription?.subscriptionPeriod.value == 1,
              monthly.subscription?.subscriptionPeriod.unit == .month,
              yearly.subscription?.subscriptionPeriod.value == 1,
              yearly.subscription?.subscriptionPeriod.unit == .year,
              monthly.price > 0 else { return nil }
        let savings = NSDecimalNumber(decimal: (1 - yearly.price / (monthly.price * 12)) * 100).doubleValue
        let percent = Int(savings.rounded())
        return percent > 0 ? "Save \(percent)%" : nil
    }

    private static func periodText(_ period: Product.SubscriptionPeriod, count: Int = 1, expandWeeks: Bool = false, omitOne: Bool = false) -> String {
        let value = period.value * count * (expandWeeks && period.unit == .week ? 7 : 1)
        let unit: String
        switch period.unit {
        case .day: unit = "day"
        case .week: unit = expandWeeks ? "day" : "week"
        case .month: unit = "month"
        case .year: unit = "year"
        @unknown default: return "billing period"
        }
        if omitOne && value == 1 { return unit }
        return "\(value) \(unit)\(value == 1 ? "" : "s")"
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
    private(set) var syncError: String?
    @ObservationIgnored nonisolated(unsafe) private var updatesTask: Task<Void, Never>?
    private let serverVerifier: (String) async throws -> AccessSnapshot?
    private let productIDs = ["com.miloom.premium.monthly", "com.miloom.premium.yearly"]

    init(serverVerifier: @escaping (String) async throws -> AccessSnapshot? = StoreService.verifyOnServer) {
        self.serverVerifier = serverVerifier
    }

    deinit { updatesTask?.cancel() }

    private func isActive(_ transaction: StoreKit.Transaction) -> Bool {
        productIDs.contains(transaction.productID)
            && transaction.revocationDate == nil
            && !transaction.isUpgraded
            && (transaction.expirationDate.map { $0 > Date() } ?? false)
    }

    func startListening(accessController: AccessController) {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in StoreKit.Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.checkVerified(update)
                    guard self.productIDs.contains(transaction.productID) else { continue }
                    if await self.sync(transactionResult: update, transaction: transaction, accessController: accessController) {
                        await transaction.finish()
                    }
                } catch {
                    self.syncError = error.localizedDescription
                }
            }
        }
    }

    func retryUnfinishedTransactions(accessController: AccessController) async {
        for await result in StoreKit.Transaction.unfinished {
            do {
                let transaction = try checkVerified(result)
                guard productIDs.contains(transaction.productID) else { continue }
                if await sync(transactionResult: result, transaction: transaction, accessController: accessController) {
                    await transaction.finish()
                }
            } catch {
                syncError = error.localizedDescription
            }
        }
    }

    func fetchProducts() async {
        do {
            products = try await Product.products(for: productIDs).sorted { $0.price < $1.price }
            loadError = products.count < productIDs.count ? "Some subscription products are unavailable from the App Store." : nil
        } catch {
            products = []
            loadError = error.localizedDescription
        }
    }

    func purchase(_ product: Product, appAccountToken: UUID, accessController: AccessController) async throws -> StorePurchaseOutcome {
        let result = try await product.purchase(options: [.appAccountToken(appAccountToken)])
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            guard isActive(transaction) else { throw StoreError.inactiveSubscription }
            if await sync(transactionResult: verification, transaction: transaction, accessController: accessController) {
                await transaction.finish()
            }
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
            guard isActive(transaction) else { continue }
            if await sync(transactionResult: result, transaction: transaction, accessController: accessController) {
                await transaction.finish()
            }
            restored = true
        }
        if !restored { await accessController.refresh() }
        return restored
    }

    /// Deliver verified access immediately. Leave unfinished transactions for retry if server sync fails.
    private func sync(
        transactionResult: VerificationResult<StoreKit.Transaction>,
        transaction: StoreKit.Transaction,
        accessController: AccessController
    ) async -> Bool {
        if isActive(transaction) {
            accessController.applyLocallyVerified(
                productID: transaction.productID,
                expirationDate: transaction.expirationDate,
                isTrial: false // The server supplies the authoritative trial status on iOS 17.
            )
        } else {
            accessController.removeLocallyVerified(productID: transaction.productID, revoked: transaction.revocationDate != nil)
            // StoreKit's entitlement enumeration can lag the update that invalidated this transaction.
            await accessController.refreshFromStoreKitIfNeeded(excludingTransactionID: transaction.id)
        }
        do {
            guard let verified = try await serverVerifier(transactionResult.jwsRepresentation) else {
                return false // Retry when the account session becomes available.
            }
            accessController.applyServerVerified(verified)
            syncError = nil
            return true
        } catch {
            syncError = error.localizedDescription
            return false
        }
    }

    private static func verifyOnServer(_ signedTransaction: String) async throws -> AccessSnapshot? {
        guard let session = try? await SupabaseService.shared.client.auth.session else { return nil }
        let url = URL(string: "\(SupabaseService.shared.urlString)/functions/v1/sync-entitlement")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["signedTransaction": signedTransaction])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw StoreError.serverVerification("Your purchase is saved. Account synchronization will retry when the connection is available.")
        }
        var verified = try JSONDecoder().decode(AccessSnapshot.self, from: data)
        verified.validatedAt = Date()
        return verified
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.failedVerification
        case .verified(let safe): return safe
        }
    }

    enum StoreError: LocalizedError {
        case failedVerification
        case inactiveSubscription
        case serverVerification(String)
        var errorDescription: String? {
            switch self {
            case .failedVerification: return "The App Store transaction could not be verified."
            case .inactiveSubscription: return "This subscription is no longer active. Please choose a plan again."
            case .serverVerification(let message): return message
            }
        }
    }
}

private extension Color {
    // The final paywall uses a lighter champagne accent than the app's gold controls.
    static let paywallGold = Color(hex: "#D8C79E")
}
