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
                            subscriptions: subscriptions,
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
                Text("Subscriptions")
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
                    shareResourceTitle = "All Subscriptions"
                    showShareSheet = true
                } label: {
                    Label("All Subscriptions", systemImage: "folder.badge.person.crop")
                }
                
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    Task {
                        do {
                            try await PlaidService.shared.syncSubscriptions()
                            await DataRepository.shared.fetchAllData(appState: appState)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        } catch {
                            print("Failed to sync subscriptions: \(error)")
                        }
                    }
                } label: {
                    Label("Refresh from Bank", systemImage: "arrow.triangle.2.circlepath")
                }
                
                if !subscriptions.isEmpty {
                    Section("Subscriptions") {
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
    let institutions: [Institution]
    let cards: [FinancialCard]
    let onEdit: (Subscription) -> Void
    let onBankTapped: (UUID) -> Void
    let onSave: (Subscription) -> Void
    var hideActionBar: Bool = false
    
    @Environment(OnboardingStateManager.self) private var onboardingState

    @State private var revealLevels: [UUID: CardRevealLevel] = [:]
    @State private var draggingCardId: UUID? = nil
    @State private var dragOffset: CGFloat = 0
    @State private var cardHeights: [UUID: CGFloat] = [:]

    private func level(for sub: Subscription, index: Int) -> CardRevealLevel {
        if let lvl = revealLevels[sub.id] { return lvl }
        // Default initial state (Pic 1): Last card in stack is .full, preceding cards are .headerOnly
        return index == subscriptions.count - 1 ? .full : .headerOnly
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: hideActionBar ? 82 : 70) // 20pt gap below action bar (50->70) or slider tabs (62->82)

                ZStack(alignment: .top) {
                    ForEach(Array(subscriptions.enumerated()), id: \.element.id) { index, sub in
                        let currentLevel = level(for: sub, index: index)
                        let yOffset = calculateYOffset(forIndex: index)
                        let cardShape = UnevenRoundedRectangle(
                            topLeadingRadius: 24,
                            bottomLeadingRadius: currentLevel == .full ? 24 : 0,
                            bottomTrailingRadius: currentLevel == .full ? 24 : 0,
                            topTrailingRadius: 24
                        )

                        PremiumSubscriptionCard(
                            sub: sub,
                            allSubscriptions: subscriptions,
                            institutions: institutions,
                            cards: cards,
                            onEdit: { onEdit(sub) },
                            onBankTapped: onBankTapped,
                            onSave: onSave,
                            revealLevel: currentLevel,
                            isExplicitlyFull: revealLevels[sub.id] == .full,
                            onExpand: {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                    revealLevels[sub.id] = .full
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                }
                            },
                            onCollapse: {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                    revealLevels.removeValue(forKey: sub.id)
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
                        // Keep the deck's explicit container height from being
                        // proposed back into the card and creating a growth loop.
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
                            for (id, h) in heights {
                                if cardHeights[id] != h {
                                    cardHeights[id] = h
                                }
                            }
                        }
                        .offset(y: yOffset)
                        .zIndex(Double(index))
                        .id(sub.id)
                        .spotlightTarget(isActive: onboardingState.isSpotlightingReview && index == 0)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: totalStackHeight, alignment: .top)
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            }
        }
    }

    private func calculateYOffset(forIndex index: Int) -> CGFloat {
        var offset: CGFloat = 0
        for i in 0..<index {
            let sub = subscriptions[i]
            let lvl = level(for: sub, index: i)
            switch lvl {
            case .headerOnly, .statusRevealed:
                offset += 68.0
            case .full:
                offset += cardHeights[sub.id, default: 340] + 8
            }
        }

        // Apply live drag offset to cards below the dragged card
        if let dragId = draggingCardId,
           let dragIndex = subscriptions.firstIndex(where: { $0.id == dragId }) {
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
        guard !subscriptions.isEmpty else { return 0 }
        let lastIndex = subscriptions.count - 1
        let lastSub = subscriptions[lastIndex]
        let lastLvl = level(for: lastSub, index: lastIndex)

        let lastHeight: CGFloat
        switch lastLvl {
        case .headerOnly, .statusRevealed: lastHeight = 80
        case .full: lastHeight = cardHeights[lastSub.id, default: 340] + 16
        }

        return calculateYOffset(forIndex: lastIndex) + lastHeight
    }

    private func handleDragChange(value: DragGesture.Value, index: Int, sub: Subscription) {
        draggingCardId = sub.id
        dragOffset = value.translation.height
    }

    private func handleDragEnd(value: DragGesture.Value, index: Int, sub: Subscription) {
        let dx = value.translation.width
        let dy = value.translation.height
        let distance = hypot(dx, dy)
        let velocity = value.predictedEndTranslation.height - value.translation.height

        // ── Tap detection (< 8pt movement) → no-op, sheet opens via header tap ──
        if distance < 8 {
            dragOffset = 0
            draggingCardId = nil
            return
        }

        let threshold: CGFloat = 35
        let velocityThreshold: CGFloat = 120

        withAnimation(.spring(response: 0.45, dampingFraction: 0.82, blendDuration: 0)) {
            if dy > 0 && (dy > threshold || velocity > velocityThreshold) {
                // ── Pulling DOWN on this card → expand this card to full ──
                let currentLvl = level(for: sub, index: index)
                if currentLvl != .full {
                    revealLevels[sub.id] = .full
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            } else if dy < 0 && (dy < -threshold || velocity < -velocityThreshold) {
                // ── Pulling UP on this card → collapse the card ABOVE (index - 1) ──
                if index > 0 {
                    let aboveSub = subscriptions[index - 1]
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
}



