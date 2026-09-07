import SwiftUI

struct SubscriptionListView: View {
    let company: Company
    let subscriptions: [Subscription]
    let institutions: [Institution]
    let cards: [FinancialCard]
    @Bindable var vm: AppViewModel
    var hideActionBar: Bool = false
    @Environment(AppState.self) private var appState
    @Environment(OnboardingStateManager.self) private var onboardingState

    @State private var editingSub: Subscription? = nil
    @State private var newSub: Subscription? = nil
    @State private var showShareSheet = false
    @State private var shareResourceId: UUID = UUID()
    @State private var shareResourceType: String = "all_subscriptions"
    @State private var shareResourceTitle: String = "All Subscriptions"
    @State private var selectedServiceFilter = "All"

    private var filteredSubscriptions: [Subscription] {
        switch selectedServiceFilter {
        case "Bills":
            return subscriptions.filter { $0.resolvedServiceType == .bill }
        case "Subscriptions":
            return subscriptions.filter { $0.resolvedServiceType == .subscription }
        default:
            return subscriptions
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollViewReader { proxy in
                Group {
                    if subscriptions.isEmpty {
                        ScrollView {
                            VStack(spacing: 0) {
                                Spacer().frame(height: hideActionBar ? 82 : 70)
                                emptyState
                            }
                        }
                    } else {
                        StackedSubscriptionDeckView(
                            subscriptions: filteredSubscriptions,
                            allSubscriptions: subscriptions,
                            institutions: institutions,
                            cards: cards,
                            onEdit: { editingSub = $0 },
                            onBankTapped: { id in
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                vm.activeTab = .financial
                                vm.deepLinkModelId = id
                            },
                            onSave: { modifiedSub in
                                vm.saveSub(modifiedSub, appState: appState)
                            },
                            selectedServiceFilter: $selectedServiceFilter,
                            hideActionBar: hideActionBar
                        )
                    }
                }
                .sheet(item: $editingSub) { sub in
                    EditSubscriptionSheet(sub: sub, institutions: institutions, cards: cards, vm: vm, isNew: false)
                }
                .sheet(item: $newSub) { sub in
                    AddSubscriptionWizard(sub: sub, institutions: institutions, cards: cards, vm: vm)
                        .presentationDetents([.fraction(0.9), .large])
                }
                .onChange(of: vm.deepLinkModelId) { _, newValue in
                    handleDeepLink(id: newValue, proxy: proxy)
                }
                .onAppear {
                    handleDeepLink(id: vm.deepLinkModelId, proxy: proxy)
                }
                .sheet(isPresented: $showShareSheet) {
                    ShareEntitySheet(resourceId: shareResourceId, resourceType: shareResourceType, resourceTitle: shareResourceTitle)
                }
            }

            if !hideActionBar {
                subscriptionActionBar
                    .zIndex(100)
            }
        }
    }
    
    private var subscriptionActionBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: "#A2A2A2"))
                Text("Services")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "#A2A2A2"))
            }
            .padding(.leading, 16)

            Spacer()

            Menu {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    shareResourceId = company.id
                    shareResourceType = "all_subscriptions"
                    shareResourceTitle = "All Services"
                    showShareSheet = true
                } label: {
                    Label("All Services", systemImage: "folder.badge.person.crop")
                }
                
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    Task {
                        do {
                            try await PlaidService.shared.syncSubscriptions()
                            await DataRepository.shared.fetchAllData(appState: appState)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        } catch {
                            AppDiagnostics.failure("plaid", "sync_subscriptions", error: error)
                        }
                    }
                } label: {
                    Label("Refresh from Bank", systemImage: "arrow.triangle.2.circlepath")
                }
                
                if !subscriptions.isEmpty {
                    Section("Services") {
                        ForEach(subscriptions) { sub in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                shareResourceId = sub.id
                                shareResourceType = "subscription"
                                shareResourceTitle = sub.name.isEmpty ? "Service" : sub.name
                                showShareSheet = true
                            } label: {
                                Label(sub.name.isEmpty ? "Unnamed Service" : sub.name, systemImage: "person.crop.circle.badge.plus")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: "#A2A2A2"))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1, height: 20)

            Button {
                newSub = Subscription(userId: company.userId, companyId: company.id)
            } label: {
                HStack(spacing: 6) {
                    Text("ADD SERVICE")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.white)
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .frame(width: 164, height: 44)
                .contentShape(Rectangle())
            }
        }
        .premiumDarkBar(cornerRadius: 12)
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }
    
    private func handleDeepLink(id: UUID?, proxy: ScrollViewProxy) {
        guard let id = id else { return }
        if let s = subscriptions.first(where: { $0.id == id }) {
            selectedServiceFilter = "All"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    proxy.scrollTo(s.id, anchor: .center)
                }
            }
            vm.deepLinkModelId = nil
        }
    }

    @State private var dummyNetflix = Subscription(
        userId: UUID(),
        companyId: UUID(),
        name: "Netflix",
        cost: 22.99,
        billingCycle: "Monthly",
        paymentMethod: "Apple Card •••• 1234",
        nextRenewal: "15",
        status: "Active",
        website: "netflix.com",
        loginId: "founder@company.com",
        password: "••••••••",
        showSubServicesTab: false,
        showLinkedEmailsTab: false
    )

    private var emptyState: some View {
        Group {
            if onboardingState.isSpotlightingTutorialCommandSubs {
                // Tutorial mode: show demo subscription card un-blurred
                PremiumSubscriptionCard(
                    sub: dummyNetflix,
                    allSubscriptions: [],
                    institutions: [],
                    cards: [],
                    onEdit: {},
                    onSave: { modifiedSub in
                        dummyNetflix = modifiedSub
                    }
                )
                .allowsHitTesting(false)
                .padding(.horizontal, 20)
                .padding(.top, 24)
            } else {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    newSub = Subscription(userId: company.userId, companyId: company.id)
                }) {
                    DynamicGlassCard(cornerRadius: 24, height: 215) {
                        VStack(spacing: 16) {
                            ZifrPlusCircle(size: 44, iconSize: 18)
                            
                            VStack(spacing: 6) {
                                Text("ADD A SERVICE")
                                    .font(.system(size: 13, weight: .bold))
                                    .textCase(.uppercase)
                                    .tracking(2)
                                    .foregroundStyle(.white)
                                
                                Text("Link a subscription, service or login")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.6))
                                    .tracking(0.5)
                            }
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    }
                    .padding(.horizontal, 20)
                }
                .buttonStyle(.plain)
                .padding(.top, 24)
                .spotlightTarget(isActive: onboardingState.isSpotlightingReview)
            }
        }
    }
}

// MARK: - Card Height Preference Key
private struct CardHeightKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Stacked Subscription Deck View
struct StackedSubscriptionDeckView: View {
    let subscriptions: [Subscription]
    let allSubscriptions: [Subscription]
    let institutions: [Institution]
    let cards: [FinancialCard]
    let onEdit: (Subscription) -> Void
    let onBankTapped: (UUID) -> Void
    let onSave: (Subscription) -> Void
    @Binding var selectedServiceFilter: String
    var hideActionBar: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: hideActionBar ? 82 : 70) // 20pt gap below action bar (50->70) or slider tabs (62->82)

                CustomSegmentedControl(
                    options: ["All", "Bills", "Subscriptions"],
                    selection: $selectedServiceFilter
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 18)

                if subscriptions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: selectedServiceFilter == "Bills" ? "doc.text.fill" : "repeat.circle.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(Color(hex: "#C1AA78"))
                        Text("No \(selectedServiceFilter.lowercased()) yet")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Services classified as \(selectedServiceFilter.lowercased()) will appear here.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)
                    .padding(.top, 72)
                } else {
                    StackedServiceSection(
                        title: "",
                        systemImage: "",
                        services: subscriptions,
                        allSubscriptions: allSubscriptions,
                        institutions: institutions,
                        cards: cards,
                        onEdit: onEdit,
                        onBankTapped: onBankTapped,
                        onSave: onSave,
                        isFirstSection: true,
                        showsHeader: false,
                        bottomPadding: 0
                    )
                }
            }
            .padding(.bottom, 120)
        }
    }
}

private struct StackedServiceSection: View {
    let title: String
    let systemImage: String
    let services: [Subscription]
    let allSubscriptions: [Subscription]
    let institutions: [Institution]
    let cards: [FinancialCard]
    let onEdit: (Subscription) -> Void
    let onBankTapped: (UUID) -> Void
    let onSave: (Subscription) -> Void
    let isFirstSection: Bool
    var showsHeader: Bool = true
    var bottomPadding: CGFloat = 28

    @Environment(OnboardingStateManager.self) private var onboardingState

    @State private var revealLevels: [UUID: CardRevealLevel] = [:]
    @State private var draggingCardId: UUID? = nil
    @State private var dragOffset: CGFloat = 0
    @State private var cardHeights: [UUID: CGFloat] = [:]

    private let collapsedPeekOffset: CGFloat = 71
    private let dragCommitDistance: CGFloat = 24
    private let projectedDragCommitDistance: CGFloat = 64
    private let maximumDragPreview: CGFloat = 28

    private func level(for sub: Subscription, index: Int) -> CardRevealLevel {
        if let level = revealLevels[sub.id] { return level }
        return index == services.count - 1 ? .full : .headerOnly
    }

    var body: some View {
        VStack(spacing: 12) {
            if showsHeader {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(hex: "#C1AA78"))

                    Text(title.uppercased())
                        .font(.system(size: 13, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Color(hex: "#C1AA78"))

                    Spacer()

                    Text("\(services.count) \(services.count == 1 ? "service" : "services")")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
                .padding(.horizontal, 2)
            }

            ZStack(alignment: .top) {
                ForEach(Array(services.enumerated()), id: \.element.id) { index, sub in
                    let currentLevel = level(for: sub, index: index)
                    let yOffset = calculateYOffset(forIndex: index)
                    let extendsUnderNextCard = currentLevel != .full && index < services.count - 1
                    let showsBottomCorners = currentLevel == .full || !extendsUnderNextCard
                    let cardShape = UnevenRoundedRectangle(
                        topLeadingRadius: 24,
                        bottomLeadingRadius: showsBottomCorners ? 24 : 0,
                        bottomTrailingRadius: showsBottomCorners ? 24 : 0,
                        topTrailingRadius: 24
                    )

                    PremiumSubscriptionCard(
                        sub: sub,
                        allSubscriptions: allSubscriptions,
                        institutions: institutions,
                        cards: cards,
                        onEdit: { onEdit(sub) },
                        onBankTapped: onBankTapped,
                        onSave: onSave,
                        revealLevel: currentLevel,
                        isExplicitlyFull: currentLevel == .full,
                        extendsUnderNextCard: extendsUnderNextCard,
                        onExpand: {
                            withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                                expandOnly(sub)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        },
                        onCollapse: {
                            withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                                revealLevels[sub.id] = .headerOnly
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        },
                        onDragChanged: { value in
                            handleDragChange(value: value, index: index, sub: sub)
                        },
                        onDragEnded: { value in
                            handleDragEnd(value: value, index: index, sub: sub)
                        }
                    )
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                    .clipShape(cardShape)
                    .overlay(
                        cardShape
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#918457"),
                                        currentLevel == .full ? Color(hex: "#918457").opacity(0.3) : Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 4)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: CardHeightKey.self, value: [sub.id: geo.size.height])
                        }
                    )
                    .onPreferenceChange(CardHeightKey.self) { heights in
                        for (id, height) in heights where cardHeights[id] != height {
                            cardHeights[id] = height
                        }
                    }
                    .offset(y: yOffset)
                    .zIndex(Double(index))
                    .id(sub.id)
                    .spotlightTarget(isActive: onboardingState.isSpotlightingReview && isFirstSection && index == 0)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: totalStackHeight, alignment: .top)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, bottomPadding)
    }

    private func calculateYOffset(forIndex index: Int) -> CGFloat {
        var offset: CGFloat = 0
        for i in 0..<index {
            let sub = services[i]
            let lvl = level(for: sub, index: i)
            switch lvl {
            case .headerOnly, .statusRevealed:
                offset += collapsedPeekOffset
            case .full:
                offset += cardHeights[sub.id, default: 340] + 8
            }
        }

        // Apply live drag offset to cards below the dragged card
        if let dragId = draggingCardId,
           let dragIndex = services.firstIndex(where: { $0.id == dragId }) {
            if index > dragIndex {
                // Cards below follow the drag (clamped to positive for pull-down)
                offset += max(0, dragOffset)
            } else if index == dragIndex {
                // The dragged card itself moves with resistance
                offset += dragOffset * 0.3
            }
        }

        return offset
    }

    private var totalStackHeight: CGFloat {
        guard !services.isEmpty else { return 0 }
        let lastIndex = services.count - 1
        let lastSub = services[lastIndex]
        let lastLvl = level(for: lastSub, index: lastIndex)

        let lastHeight: CGFloat
        switch lastLvl {
        case .headerOnly, .statusRevealed: lastHeight = 80
        case .full: lastHeight = cardHeights[lastSub.id, default: 340] + 16
        }

        return calculateYOffset(forIndex: lastIndex) + lastHeight
    }

    private func handleDragChange(value: DragGesture.Value, index: Int, sub: Subscription) {
        guard abs(value.translation.height) > abs(value.translation.width) else { return }
        draggingCardId = sub.id
        dragOffset = limitedDragPreview(for: value.translation.height)
    }

    private func handleDragEnd(value: DragGesture.Value, index: Int, sub: Subscription) {
        let dx = value.translation.width
        let dy = value.translation.height
        let distance = hypot(dx, dy)
        let projectedDy = value.predictedEndTranslation.height

        // ── Tap detection (< 8pt movement) → no-op, sheet opens via header tap ──
        if distance < 8 {
            dragOffset = 0
            draggingCardId = nil
            return
        }

        guard abs(dy) > abs(dx) else {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                dragOffset = 0
                draggingCardId = nil
            }
            return
        }

        withAnimation(.spring(response: 0.36, dampingFraction: 0.86, blendDuration: 0)) {
            if dy > 0 && (dy > dragCommitDistance || projectedDy > projectedDragCommitDistance) {
                // ── Pulling DOWN on this card → expand this card to full ──
                let currentLvl = level(for: sub, index: index)
                if currentLvl != .full {
                    expandOnly(sub)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            } else if dy < 0 && (dy < -dragCommitDistance || projectedDy < -projectedDragCommitDistance) {
                // ── Pulling UP on this card → collapse the card ABOVE (index - 1) ──
                if index > 0 {
                    let aboveSub = services[index - 1]
                    let aboveLvl = level(for: aboveSub, index: index - 1)
                    if aboveLvl == .full {
                        revealLevels[aboveSub.id] = .headerOnly
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                }
                // Also collapse this card if it's expanded
                let currentLvl = level(for: sub, index: index)
                if currentLvl == .full {
                    revealLevels[sub.id] = .headerOnly
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }

            dragOffset = 0
            draggingCardId = nil
        }
    }

    /// Keeps the stack accordion-like: opening one card closes every other
    /// card, including the bottom card that starts open by default.
    private func expandOnly(_ sub: Subscription) {
        revealLevels = Dictionary(
            uniqueKeysWithValues: services.map { ($0.id, CardRevealLevel.headerOnly) }
        )
        revealLevels[sub.id] = .full
    }

    /// Gives the deck a short, rubber-banded preview without allowing the
    /// user's finger to pull an unlimited amount of empty space into the stack.
    private func limitedDragPreview(for translation: CGFloat) -> CGFloat {
        let direction: CGFloat = translation < 0 ? -1 : 1
        let magnitude = abs(translation)
        let resistedMagnitude = maximumDragPreview * (1 - exp(-magnitude / 28))
        return direction * min(resistedMagnitude, maximumDragPreview)
    }
}
