import SwiftUI
import UIKit

struct SubscriptionListView: View {
    let company: Company
    let subscriptions: [Subscription]
    let institutions: [Institution]
    let cards: [FinancialCard]
    @Bindable var vm: AppViewModel
    var hideActionBar: Bool = false
    var topContentInset: CGFloat?
    var canEdit: Bool = true
    var canAccessCredentials: Bool = true
    @Environment(AppState.self) private var appState
    @Environment(OnboardingStateManager.self) private var onboardingState

    @State private var editingSub: Subscription? = nil
    @State private var newSub: Subscription? = nil
    @State private var showShareSheet = false
    @State private var shareResourceId: UUID = UUID()
    @State private var shareResourceType: String = "all_subscriptions"
    @State private var shareResourceTitle: String = "All Subscriptions"
    @State private var selectedServiceFilter = "All"

    // Existing-item edits are independent of company-level creation rights.
    // An exact Editor grant must not unlock sibling services.
    private var editableSubscriptionIDs: Set<UUID> {
        guard let actorID = appState.portfolioUserID else { return [] }
        return Set(subscriptions.filter { sub in
            if company.userId == actorID { return canEdit }
            return AppViewModel.shareAllowsEdit(
                appState.resourceShares, actorID: actorID, companyID: company.id,
                resourceType: "subscription", resourceID: sub.id
            )
        }.map(\.id))
    }

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
            Group {
                if subscriptions.isEmpty {
                    ScrollView {
                        VStack(spacing: 0) {
                            Spacer().frame(height: topContentInset ?? (hideActionBar ? 82 : 70))
                            emptyState
                        }
                        .duoSideScrollTarget(.subscriptions)
                    }
                } else {
                    StackedSubscriptionDeckView(
                        subscriptions: filteredSubscriptions,
                        allSubscriptions: subscriptions,
                        institutions: institutions,
                        cards: cards,
                        onEdit: { if editableSubscriptionIDs.contains($0.id) { editingSub = $0 } },
                        onBankTapped: { id in
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            vm.activeTab = .financial
                            vm.deepLinkModelId = id
                        },
                        onSave: { modifiedSub in
                            if editableSubscriptionIDs.contains(modifiedSub.id) {
                                vm.saveSub(modifiedSub, appState: appState)
                            }
                        },
                        selectedServiceFilter: $selectedServiceFilter,
                        deepLinkModelId: $vm.deepLinkModelId,
                        hideActionBar: hideActionBar,
                        topContentInset: topContentInset,
                        editableSubscriptionIDs: editableSubscriptionIDs,
                        canAccessCredentials: canAccessCredentials
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
            .sheet(isPresented: $showShareSheet) {
                ShareEntitySheet(resourceId: shareResourceId, resourceType: shareResourceType, resourceTitle: shareResourceTitle)
            }

            if !hideActionBar && canEdit {
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
                            try await PlaidService.shared.syncLatestAvailableData()
                            await DataRepository.shared.fetchAllData(appState: appState)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        } catch {
                            AppDiagnostics.failure("plaid", "sync_subscriptions", error: error)
                        }
                    }
                } label: {
                    Label("Sync Available Data", systemImage: "arrow.triangle.2.circlepath")
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
                .modifier(PhoneCommandCenterContentWidth())
                .padding(.horizontal, PhoneCommandCenterContentWidth.sideInset)
                .padding(.top, 24)
            } else if canEdit {
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
                    .modifier(PhoneCommandCenterContentWidth())
                    .padding(.horizontal, PhoneCommandCenterContentWidth.sideInset)
                }
                .buttonStyle(.plain)
                .padding(.top, 24)
                .spotlightTarget(isActive: onboardingState.isSpotlightingReview)
            } else {
                DynamicGlassCard(cornerRadius: 24, height: 190) {
                    VStack(spacing: 14) {
                        Image(systemName: "square.3.layers.3d")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(Color(hex: "#C1AA78"))
                        Text("NO SERVICES SHARED")
                            .font(.system(size: 13, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(.white)
                        Text("You can view services here when the owner adds them.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 28)
                }
                .modifier(PhoneCommandCenterContentWidth())
                .padding(.horizontal, PhoneCommandCenterContentWidth.sideInset)
                .padding(.top, 24)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

// MARK: - Stacked Subscription Deck View
private struct ServiceCardFocus: Equatable {
    let subscriptionID: UUID
    let requestID = UUID()
}

private struct StackedSubscriptionDeckView: View {
    let subscriptions: [Subscription]
    let allSubscriptions: [Subscription]
    let institutions: [Institution]
    let cards: [FinancialCard]
    let onEdit: (Subscription) -> Void
    let onBankTapped: (UUID) -> Void
    let onSave: (Subscription) -> Void
    @Binding var selectedServiceFilter: String
    @Binding var deepLinkModelId: UUID?
    var hideActionBar: Bool = false
    var topContentInset: CGFloat?
    var editableSubscriptionIDs: Set<UUID> = []
    var canAccessCredentials: Bool = true

    @State private var focus: ServiceCardFocus?

    private let bottomInset: CGFloat = 120
    private let filterHeight: CGFloat = 36
    private let filterSpacing: CGFloat = 18

    private var headerInset: CGFloat { topContentInset ?? (hideActionBar ? 82 : 70) }

    var body: some View {
        GeometryReader { viewport in
            deck(viewportHeight: viewport.size.height)
        }
        .onChange(of: deepLinkModelId, initial: true) { _, id in
            guard let id, allSubscriptions.contains(where: { $0.id == id }) else { return }
            selectedServiceFilter = "All"
            focus = ServiceCardFocus(subscriptionID: id)
            deepLinkModelId = nil
        }
    }

    private func deck(viewportHeight: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: headerInset)

                CustomSegmentedControl(
                    options: ["All", "Bills", "Subscriptions"],
                    selection: $selectedServiceFilter
                )
                .modifier(PhoneCommandCenterContentWidth())
                .padding(.horizontal, PhoneCommandCenterContentWidth.sideInset)
                .padding(.bottom, filterSpacing)

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
                        editableSubscriptionIDs: editableSubscriptionIDs,
                        canAccessCredentials: canAccessCredentials,
                        isFirstSection: true,
                        showsHeader: false,
                        bottomPadding: 0,
                        focus: focus,
                        viewportHeight: viewportHeight,
                        deckTopInset: headerInset + filterHeight + filterSpacing,
                        deckBottomInset: bottomInset
                    )
                }
            }
            .padding(.bottom, bottomInset)
            .duoSideScrollTarget(.subscriptions)
        }
    }
}

// Measure the card itself. The overlapping deck's scroll targets can include
// the vertical space used to position a card within the stack.
private struct ServiceCardCenteringView: UIViewRepresentable {
    let focus: ServiceCardFocus

    func makeUIView(context: Context) -> Marker {
        let marker = Marker()
        marker.isUserInteractionEnabled = false
        marker.accessibilityElementsHidden = true
        return marker
    }

    func updateUIView(_ marker: Marker, context: Context) {
        marker.updateFocus(focus)
    }

    final class Marker: UIView {
        private var focus: ServiceCardFocus?
        private var centeringTask: Task<Void, Never>?

        func updateFocus(_ request: ServiceCardFocus) {
            guard focus != request else { return }
            focus = request
            scheduleCentering()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            scheduleCentering()
        }

        private func scheduleCentering() {
            centeringTask?.cancel()
            guard focus != nil, window != nil else { return }
            centeringTask = Task { @MainActor [weak self] in
                // Recheck after the navigation transition settles. Some layouts
                // change the scroll view's bounds during the transition.
                for delay in [0, 80, 240, 200] {
                    do {
                        try await Task.sleep(for: .milliseconds(delay))
                    } catch {
                        return
                    }
                    guard let self, self.window != nil else { return }
                    guard let scroll = self.enclosingScrollView else { continue }
                    guard !scroll.isTracking, !scroll.isDragging, !scroll.isDecelerating else { return }
                    self.centerCard(in: scroll)
                }
            }
        }

        private var enclosingScrollView: UIScrollView? {
            var ancestor = superview
            while let view = ancestor, !(view is UIScrollView) {
                ancestor = view.superview
            }
            return ancestor as? UIScrollView
        }

        private func centerCard(in scroll: UIScrollView) {
            scroll.layoutIfNeeded()
            guard bounds.height > 0, scroll.bounds.height > 0 else { return }
            let rect = convert(bounds, to: scroll)
            let minY = -scroll.adjustedContentInset.top
            let maxY = max(minY, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
            let targetY = min(maxY, max(minY, rect.midY - scroll.bounds.height / 2))
            if abs(targetY - scroll.contentOffset.y) > 1 {
                scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: targetY), animated: false)
            }
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
    var editableSubscriptionIDs: Set<UUID> = []
    var canAccessCredentials: Bool = true
    let isFirstSection: Bool
    var showsHeader: Bool = true
    var bottomPadding: CGFloat = 28
    let focus: ServiceCardFocus?
    let viewportHeight: CGFloat
    let deckTopInset: CGFloat
    let deckBottomInset: CGFloat

    @Environment(OnboardingStateManager.self) private var onboardingState

    @State private var selectedServiceID: UUID?
    @State private var draggingCardId: UUID? = nil
    @State private var dragOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var focusedHeight: CGFloat = 0

    private let collapsedPeekOffset: CGFloat = 71
    private let dragCommitDistance: CGFloat = 24
    private let projectedDragCommitDistance: CGFloat = 64
    private let maximumDragPreview: CGFloat = 28

    private var focusedCardIndex: Int? {
        guard let focus,
              let index = services.firstIndex(where: { $0.id == focus.subscriptionID }),
              selectedServiceID == focus.subscriptionID else { return nil }
        return index
    }

    private var centeringInsets: (top: CGFloat, bottom: CGFloat) {
        guard let index = focusedCardIndex, focusedHeight > 0 else { return (0, 0) }
        // Focusing opens just this service. All other cards occupy their header peek.
        let desiredSpace = max(0, (viewportHeight - focusedHeight) / 2)
        let before = CGFloat(index) * collapsedPeekOffset
        let remaining = services.count - index - 1
        let after: CGFloat = remaining == 0 ? 16 : 8 + CGFloat(remaining - 1) * collapsedPeekOffset + 80
        return (max(0, desiredSpace - before - deckTopInset),
                max(0, desiredSpace - after - deckBottomInset))
    }

    var body: some View {
        let expandedID = services.first { $0.id == selectedServiceID }?.id ?? services.last?.id
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

            VStack(spacing: 0) {
                ForEach(Array(services.enumerated()), id: \.element.id) { index, sub in
                    let currentLevel: CardRevealLevel = sub.id == expandedID ? .full : .headerOnly
                    let extendsUnderNextCard = currentLevel != .full && index < services.count - 1
                    PremiumSubscriptionCard(
                        sub: sub,
                        allSubscriptions: allSubscriptions,
                        institutions: institutions,
                        cards: cards,
                        onEdit: { onEdit(sub) },
                        onBankTapped: onBankTapped,
                        onSave: onSave,
                        canEdit: editableSubscriptionIDs.contains(sub.id),
                        canAccessCredentials: canAccessCredentials,
                        revealLevel: currentLevel,
                        isExplicitlyFull: currentLevel == .full,
                        extendsUnderNextCard: extendsUnderNextCard,
                        onExpand: {
                            withAnimation(reduceMotion ? nil : .cardDeckReveal) {
                                selectedServiceID = sub.id
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        },
                        onCollapse: {
                            withAnimation(reduceMotion ? nil : .cardDeckReveal) {
                                selectedServiceID = nil
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
                    .modifier(PhoneCommandCenterContentWidth())
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 4)
                    .background {
                        if let focus, focus.subscriptionID == sub.id, selectedServiceID == sub.id {
                            ServiceCardCenteringView(focus: focus)
                                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                                    focusedHeight = height
                                }
                        }
                    }
                    .padding(.bottom, bottomSpacing(level: currentLevel, isLast: index == services.count - 1))
                    .offset(y: dragPreviewOffset(for: index))
                    .zIndex(Double(index))
                    .id(sub.id)
                    .spotlightTarget(isActive: onboardingState.isSpotlightingReview && isFirstSection && index == 0)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .modifier(PhoneCommandCenterContentWidth())
        .padding(.horizontal, PhoneCommandCenterContentWidth.sideInset)
        .padding(.top, centeringInsets.top)
        .padding(.bottom, bottomPadding + centeringInsets.bottom)
        .onChange(of: focus, initial: true) { _, request in
            guard let request, let service = services.first(where: { $0.id == request.subscriptionID }) else { return }
            selectedServiceID = service.id
        }
    }

    private func bottomSpacing(level: CardRevealLevel, isLast: Bool) -> CGFloat {
        if level == .full { return isLast ? 16 : 8 }
        if isLast { return 4 }
        // The 76-point header exposes 71 points before the next card overlaps it.
        return collapsedPeekOffset - 76 - PremiumSubscriptionCard.underlap
    }

    private func dragPreviewOffset(for index: Int) -> CGFloat {
        guard let draggingCardId, let dragged = services.firstIndex(where: { $0.id == draggingCardId })
        else { return 0 }
        if index == dragged { return dragOffset * 0.3 }
        return index > dragged ? max(0, dragOffset) : 0
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

        withAnimation(reduceMotion ? nil : .cardDeckReveal) {
            if dy > 0 && (dy > dragCommitDistance || projectedDy > projectedDragCommitDistance) {
                // ── Pulling DOWN on this card → expand this card to full ──
                if selectedServiceID != sub.id {
                    selectedServiceID = sub.id
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            } else if dy < 0 && (dy < -dragCommitDistance || projectedDy < -projectedDragCommitDistance) {
                let aboveID = index > 0 ? services[index - 1].id : nil
                if let selectedServiceID, selectedServiceID == sub.id || selectedServiceID == aboveID {
                    self.selectedServiceID = nil
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }

            dragOffset = 0
            draggingCardId = nil
        }
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
