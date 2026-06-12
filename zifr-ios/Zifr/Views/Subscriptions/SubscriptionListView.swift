import SwiftUI

struct SubscriptionListView: View {
    let company: Company
    let subscriptions: [Subscription]
    let institutions: [Institution]
    let cards: [FinancialCard]
    @Bindable var vm: AppViewModel
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
                MiloomListView {
                    Spacer().frame(height: 66)

                if subscriptions.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(subscriptions.enumerated()), id: \.element.id) { index, sub in
                        PremiumSubscriptionCard(
                            sub: sub, 
                            allSubscriptions: subscriptions, 
                            institutions: institutions, 
                            cards: cards, 
                            onEdit: { editingSub = sub },
                            onBankTapped: { id in
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                vm.activeTab = .financial
                                vm.deepLinkModelId = id
                            },
                            onSave: { modifiedSub in
                                vm.saveSub(modifiedSub, appState: appState)
                            }
                        )
                            .id(sub.id)
                            .spotlightTarget(isActive: onboardingState.isSpotlightingReview && index == 0)
                    }
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
            
            subscriptionActionBar
                .zIndex(100)
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
                .padding(.top, 40)
            } else {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    newSub = Subscription(userId: company.userId, companyId: company.id)
                }) {
                    ZStack {
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
                        .blur(radius: 3)
                        
                        VStack(spacing: 16) {
                            Image(systemName: "square.3.layers.3d")
                                .font(.system(size: 28))
                                .foregroundStyle(.white)
                            Text("ADD YOUR FIRST SUBSCRIPTION")
                                .font(.system(size: 11, weight: .black))
                                .textCase(.uppercase)
                                .tracking(2)
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 24))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .spotlightTarget(isActive: onboardingState.isSpotlightingReview)
            }
        }
    }
}




