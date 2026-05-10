import SwiftUI

struct SubscriptionListView: View {
    let company: Company
    let subscriptions: [Subscription]
    let institutions: [Institution]
    let cards: [FinancialCard]
    @Bindable var vm: AppViewModel
    @Environment(AppState.self) private var appState

    @State private var editingSub: Subscription? = nil
    @State private var newSub: Subscription? = nil
    @State private var showShareSheet = false
    @State private var shareResourceId: UUID = UUID()
    @State private var shareResourceType: String = "all_subscriptions"
    @State private var shareResourceTitle: String = "All Subscriptions"



    var body: some View {
        ScrollViewReader { proxy in
            MiloomListView {
                // ── Action Bar ──
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
                            Text("ADD SERVICE").font(.system(size: 13, weight: .bold)).tracking(1).foregroundStyle(.white)
                            Image(systemName: "plus").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.white.opacity(0.5))
                        }
                        .frame(width: 164, height: 44)
                        .contentShape(Rectangle())
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "#1C1C1E").opacity(0.70))
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .padding(.top, -10)
                .padding(.bottom, 8)

                if subscriptions.isEmpty {
                    emptyState
                } else {
                    ForEach(subscriptions) { sub in
                        SubscriptionCardView(
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
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            newSub = Subscription(userId: company.userId, companyId: company.id)
        }) {
            ZStack {
                SubscriptionCardView(
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
                    Text("ADD YOUR FIRST SERVICE")
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
    }
}

// MARK: - Subscription Card (exact CiFr layout)

struct SubscriptionCardView: View {
    let sub: Subscription
    let allSubscriptions: [Subscription]
    let institutions: [Institution]
    let cards: [FinancialCard]
    let onEdit: () -> Void
    var onBankTapped: ((UUID) -> Void)? = nil
    var onSave: ((Subscription) -> Void)? = nil

    @State private var expanded = false
    @State private var showSubServices = false
    @State private var showLinkedEmails = false
    @State private var copiedField: String? = nil // "login" | "password"
    @State private var passwordRevealed = false

    // Sub-service HUD state
    @State private var showSubServiceHUD = false
    @State private var subDraft = SubService()
    @State private var subDraftIndex: Int? = nil
    @State private var isNewSubService = false

    // Linked email HUD state
    @State private var showEmailHUD = false
    @State private var emailDraft = LinkedEmail()
    @State private var emailDraftIndex: Int? = nil
    @State private var isNewEmail = false

    // Billing totals — mirrors CiFr calcTotals()
    var primaryTotal: Double {
        sub.billingCycle == "Monthly" ? sub.monthlyTotal : sub.yearlyTotal
    }
    var primaryLabel: String { sub.billingCycle == "Monthly" ? "recur/mo." : "recur/yr." }
    var secondaryTotal: Double {
        sub.billingCycle == "Monthly" ? sub.yearlyTotal : sub.monthlyTotal
    }
    var secondaryLabel: String { sub.billingCycle == "Monthly" ? "recur/yr." : "recur/mo." }
    var totalAnnual: Double { (sub.monthlyTotal * 12) + sub.yearlyTotal }

    var formattedDueOn: String {
        guard !(sub.nextRenewal ?? "").isEmpty else { return "—" }
        func ordinal(_ n: Int) -> String {
            let tens = (n % 100) / 10
            if tens == 1 { return "\(n)th" }
            switch n % 10 {
            case 1: return "\(n)st"
            case 2: return "\(n)nd"
            case 3: return "\(n)rd"
            default: return "\(n)th"
            }
        }
        if sub.billingCycle == "Monthly" {
            if let day = Int(sub.nextRenewal ?? "") { return "\(ordinal(day)) of every month" }
            return (sub.nextRenewal ?? "") + " of every month"
        } else {
            let parts = (sub.nextRenewal ?? "").split(separator: " ")
            if parts.count == 2, let day = Int(parts[1]) {
                return "\(parts[0]) \(ordinal(day)) every year"
            }
            return (sub.nextRenewal ?? "") + " every year"
        }
    }

    var shortDueOn: String {
        guard !(sub.nextRenewal ?? "").isEmpty else { return "—" }
        func ordinal(_ n: Int) -> String {
            let tens = (n % 100) / 10
            if tens == 1 { return "\(n)th" }
            switch n % 10 {
            case 1: return "\(n)st"
            case 2: return "\(n)nd"
            case 3: return "\(n)rd"
            default: return "\(n)th"
            }
        }
        if sub.billingCycle == "Monthly" {
            if let day = Int(sub.nextRenewal ?? "") { return ordinal(day) }
            return (sub.nextRenewal ?? "")
        } else {
            let parts = (sub.nextRenewal ?? "").split(separator: " ")
            if parts.count == 2, let day = Int(parts[1]) {
                return "\(parts[0]) \(ordinal(day))"
            }
            return (sub.nextRenewal ?? "")
        }
    }

    var statusRowTuple: (top: String, bottom: String) {
        if sub.status == "Paused" { return ("Paused", "") }
        if sub.isFree { return ("Free", "") }
        let cycle = sub.billingCycle == "Monthly" ? "month" : "year"
        let verb = sub.renew == "Manual" ? "Manual pay on" : "Auto pay on"
        return (verb, "\(shortDueOn) every \(cycle)")
    }
    
    var bankAccountTuple: (bank: String, account: String, type: String, modelId: UUID?)? {
        if (sub.paymentMethod ?? "").isEmpty { return nil }
        
        if let card = cards.first(where: { $0.name == sub.paymentMethod }) {
            let inst = (card.institutionName ?? "").isEmpty ? "Paid From" : card.institutionName!
            let suffix = (card.last4 ?? "").isEmpty ? "" : " ••••\(card.last4 ?? "")"
            return (inst, "\(card.name)\(suffix)", card.type, card.id)
        }
        
        for inst in institutions {
            if let acc = inst.accounts.first(where: { ($0.name.isEmpty ? $0.type : $0.name) == sub.paymentMethod }) {
                let instName = inst.name.isEmpty ? "Paid From" : inst.name
                let accName = acc.name.isEmpty ? acc.type : acc.name
                let suffix = (acc.last4 ?? "").isEmpty ? "" : " ••••\(acc.last4 ?? "")"
                return (instName, "\(accName)\(suffix)", acc.type, inst.id)
            }
        }
        
        return ("Paid From", sub.paymentMethod ?? "", "", nil)
    }

    var body: some View {
        MiloomListCard {
            // ── Top: tap opens edit ──────────────────────────────────────
            Button(action: onEdit) {
                VStack(spacing: 0) {
                    // Logo + Name + Cost row
                    HStack(alignment: .top, spacing: 16) {
                        // Logo — 56×56 rounded-16 rgba(255,255,255,0.05) bg
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.clear)
                                .frame(width: 56, height: 56)
                            if !(sub.website ?? "").isEmpty {
                                FaviconImage(website: (sub.website ?? ""), size: 36)
                            } else {
                                Text(sub.name.isEmpty ? "?" : String(sub.name.prefix(1)).uppercased())
                                    .font(.system(size: 22, weight: .black))
                                    .foregroundStyle(Color.white.opacity(0.8))
                            }
                        }

                        // Name + costs
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sub.name.isEmpty ? "Service" : sub.name)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)

                            if sub.isFree {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(Color.zifrGreen)
                                        .frame(width: 6, height: 6)
                                        .shadow(color: Color.zifrGreen, radius: 3)
                                    Text("FREE")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.4))
                                }
                                .padding(.top, 2)
                            } else {
                                HStack(spacing: 14) {
                                    costColumn(value: primaryTotal, label: primaryLabel)
                                    if secondaryTotal > 0 {
                                        dividerLine()
                                        costColumn(value: secondaryTotal, label: secondaryLabel)
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .padding(.bottom, sub.isFree ? 4 : 10)

                    if sub.isFree {
                        // 80% width divider under logo row
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 1)
                            .padding(.leading, 24)
                            .padding(.trailing, 70) // Rough 80% of card width
                            .padding(.bottom, 10)
                    }

                    // Status row — CiFr dot + pipes style
                    if !sub.isFree {
                        VStack(spacing: 0) {
                            HStack(spacing: 8) {
                                statusDot(sub: sub)
                                
                                let sTuple = statusRowTuple
                                if sub.status == "Paused" {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(sTuple.top)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Color(hex: "#911c26"))
                                        if !sTuple.bottom.isEmpty {
                                            Text(sTuple.bottom)
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(Color(hex: "#911c26").opacity(0.7))
                                        }
                                    }
                                    .textCase(.uppercase)
                                    .tracking(0.3)
                                } else {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(sTuple.top)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.white)
                                        if !sTuple.bottom.isEmpty {
                                            Text(sTuple.bottom)
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(Color(hex: "#C1AA78"))
                                        }
                                    }
                                    .textCase(.uppercase)
                                    .tracking(0.3)
                                }
                                
                                if let accTuple = bankAccountTuple {
                                    statusPipe()
                                        .padding(.horizontal, 6)
                                    Button {
                                        if let id = accTuple.modelId {
                                            onBankTapped?(id)
                                        }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 4) {
                                                Text(accTuple.bank)
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundStyle(.white)
                                                if !accTuple.type.isEmpty {
                                                    Text("·")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundStyle(Color(hex: "#7D7D7D"))
                                                    Text(accTuple.type)
                                                        .font(.system(size: 11, weight: .semibold))
                                                        .foregroundStyle(.white)
                                                }
                                            }
                                            Text(accTuple.account)
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(Color(hex: "#C1AA78"))
                                        }
                                        .textCase(.uppercase)
                                        .tracking(0.3)
                                    }
                                    .buttonStyle(PremiumButtonStyle())
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color(hex: "#2C2C2E"))
                            .overlay(
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundStyle(Color.white.opacity(0.06)),
                                alignment: .top
                            )
                        }
                        .padding(.bottom, 12)
                    }

                    // Credentials row — tap-to-copy
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 12) {
                            copyableCredential(id: sub.id.uuidString, label: "Login ID", value: sub.loginId ?? "", field: "login")
                            copyableCredential(id: sub.id.uuidString, label: "Password", value: sub.password ?? "", field: "password", isPassword: true)
                        }
                        .padding(.top, 4)
                        
                        DynamicLoginLabelView(loginId: sub.loginId ?? "", ignoreSubscriptionId: sub.id.uuidString)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PremiumButtonStyle())



            // ── Supplemental Services accordion ─────────────────────────
            if sub.showSubServicesTab {
                MiloomAccordion(title: "Supplemental Services", count: sub.subServices.count, expanded: showSubServices, action: {
                    withAnimation(.easeInOut(duration: 0.2)) { showSubServices.toggle() }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                VStack(spacing: 12) {
                    ForEach(sub.subServices.indices, id: \.self) { i in
                        let ss = sub.subServices[i]
                        Button {
                            subDraft = ss
                            subDraftIndex = i
                            isNewSubService = false
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showSubServiceHUD = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(ss.name.isEmpty ? "Unnamed Service" : ss.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                    
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(ss.status == .active ? Color.zifrGreen : Color.red)
                                            .frame(width: 6, height: 6)
                                        
                                        statusPipe()
                                        
                                        Text(ss.paymentMethod.isEmpty ? "No Card" : ss.paymentMethod)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.6))

                                        statusPipe()
                                        
                                        Text(ss.autoPay == .auto ? "Auto Pay" : "Manual")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.6))
                                    }
                                }
                                Spacer()
                                HStack(alignment: .firstTextBaseline, spacing: 2) {
                                    Text("$\(String(format: "%.0f", ss.cost))")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(ss.status == .active ? .white : Color.white.opacity(0.4))
                                    Text("/\(ss.billingCycle == .monthly ? "mo" : "yr")")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#2C2C2E"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        }
                        .buttonStyle(PremiumButtonStyle())
                    }
                    
                    Button {
                        subDraft = SubService()
                        subDraftIndex = nil
                        isNewSubService = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showSubServiceHUD = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                            Text("Add Service").font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color.zifrGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(PremiumButtonStyle())
                    .padding(.top, sub.subServices.isEmpty ? 0 : 4)
                }
                }
            }

            // ── Linked Emails accordion ──────────────────────────────────
            if sub.showLinkedEmailsTab {
                MiloomAccordion(title: "Linked Emails", count: sub.linkedEmails.count, expanded: showLinkedEmails, action: {
                    withAnimation(.easeInOut(duration: 0.2)) { showLinkedEmails.toggle() }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                VStack(spacing: 12) {
                    ForEach(sub.linkedEmails.indices, id: \.self) { i in
                        let email = sub.linkedEmails[i]
                        Button {
                            emailDraft = email
                            emailDraftIndex = i
                            isNewEmail = false
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showEmailHUD = true
                        } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    // Email
                                    Text(email.email.isEmpty ? "No Address" : email.email)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)

                                    dynamicLabels(for: email)

                                    // Role row
                                    HStack(spacing: 6) {
                                        Text("USED FOR:")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Color.white.opacity(0.4))
                                        
                                        Text(email.usedFor.isEmpty ? "Unassigned" : email.usedFor)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.6))
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#2C2C2E"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        }
                        .buttonStyle(PremiumButtonStyle())
                    }
                    
                    Button {
                        emailDraft = LinkedEmail()
                        emailDraftIndex = nil
                        isNewEmail = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showEmailHUD = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                            Text("Add Email").font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color.zifrGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(PremiumButtonStyle())
                    .padding(.top, sub.linkedEmails.isEmpty ? 0 : 4)
                }
                }
            }
        }
        // ── Sub-service HUD ───────────────────────────────────────────────
        .sheet(isPresented: $showSubServiceHUD) {
            SubServiceHUD(
                draft: $subDraft,
                isNew: isNewSubService,
                companyId: sub.companyId,
                institutions: institutions,
                cards: cards,
                onSave: {
                    var modifiedSub = sub
                    var services = modifiedSub.subServices
                    if let idx = subDraftIndex {
                        services[idx] = subDraft
                    } else {
                        services.append(subDraft)
                    }
                    modifiedSub.subServices = services
                    onSave?(modifiedSub)
                    showSubServiceHUD = false
                },
                onCancel: { showSubServiceHUD = false },
                onDelete: {
                    if let idx = subDraftIndex {
                        var modifiedSub = sub
                        modifiedSub.subServices.remove(at: idx)
                        onSave?(modifiedSub)
                    }
                    showSubServiceHUD = false
                }
            )
            .presentationDetents([.height(420)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
        // ── Linked email HUD ─────────────────────────────────────────────
        .proContextMenu(password: sub.password, loginId: sub.loginId, last4: nil)
        .sheet(isPresented: $showEmailHUD) {
            LinkedEmailHUD(
                draft: $emailDraft,
                isNew: isNewEmail,
                onSave: {
                    var modifiedSub = sub
                    var emails = modifiedSub.linkedEmails
                    if let idx = emailDraftIndex {
                        emails[idx] = emailDraft
                    } else {
                        emails.append(emailDraft)
                    }
                    modifiedSub.linkedEmails = emails
                    onSave?(modifiedSub)
                    showEmailHUD = false
                },
                onCancel: { showEmailHUD = false },
                onDelete: {
                    if let idx = emailDraftIndex {
                        var modifiedSub = sub
                        modifiedSub.linkedEmails.remove(at: idx)
                        onSave?(modifiedSub)
                    }
                    showEmailHUD = false
                }
            )
            .presentationDetents([.height(500)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
    }

    // MARK: - Helpers

    private func costColumn(value: Double, label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("$\(String(format: "%.0f", value))")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: "#C1AA78"))
        }
    }

    private func dividerLine() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(width: 1)
            .padding(.vertical, 2)
    }

    private func statusDot(sub: Subscription) -> some View {
        Circle()
            .fill(sub.status == "Paused" ? Color.red : (sub.renew == "Manual" ? Color.red : Color.zifrGreen))
            .frame(width: 6, height: 6)
    }

    private func statusPipe() -> some View {
        Text("|")
            .font(.system(size: 10))
            .foregroundStyle(Color.white.opacity(0.2))
    }



    private func copyableCredential(id: String, label: String, value: String, field: String, isPassword: Bool = false) -> some View {
        let isCopied = copiedField == field
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(isCopied ? "Copied ✓" : label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isCopied ? Color.orange : Color.white.opacity(0.5))
                    .textCase(.uppercase)
                if isPassword {
                    Button {
                        passwordRevealed.toggle()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: passwordRevealed ? "eye.slash" : "eye")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                }
            }

            Button {
                guard !value.isEmpty else { return }
                UIPasteboard.general.string = value
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation { copiedField = field }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { copiedField = nil }
                }
            } label: {
                HStack {
                    Text(isPassword && !passwordRevealed ? "••••••••" : (value.isEmpty ? "—" : value))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(value.isEmpty ? Color.white.opacity(0.3) : .white)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(hex: "#2C2C2E"))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
            }
            .buttonStyle(PremiumButtonStyle())
        }
    }

    private func detailCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.5))
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: "#C1AA78"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func dynamicLabels(for email: LinkedEmail) -> some View {
        let normalizedEmail = email.email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedEmail.isEmpty {
            let computedServices: [UsedInEmailService] = allSubscriptions.compactMap { s in
                if (s.loginId ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedEmail {
                    return UsedInEmailService(name: s.name.isEmpty ? "Unnamed Service" : s.name, role: .primary)
                } else if s.linkedEmails.contains(where: { e in e.email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedEmail }) {
                    return UsedInEmailService(name: s.name.isEmpty ? "Unnamed Service" : s.name, role: .linked)
                }
                return nil
            }
            let legacyTags: [String] = email.usedIn.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { tag in 
                    !tag.isEmpty && !computedServices.contains { $0.name.lowercased() == tag.lowercased() }
                }
                
            let allTextTags = computedServices.map { svc in
                svc.name
            } + legacyTags
                
            if !allTextTags.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LINKED TO:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: "#C1AA78"))
                        .textCase(.uppercase)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.zifrGreen)
                        
                        Text(allTextTags.joined(separator: " | "))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(hex: "#7D7D7D"))
                            .lineLimit(2)
                    }
                }
            }
        }
    }
}

import SwiftUI

struct SubscriptionReceiptView: View {
    let company: Company
    let subscriptions: [Subscription]
    let institutions: [Institution]
    let cards: [FinancialCard]
    
    @Environment(\.dismiss) private var dismiss
    
    private var activeSubscriptions: [Subscription] {
        subscriptions.filter { $0.status == "Active" }
    }
    
    private var totalMonthlyBurn: Double {
        activeSubscriptions.reduce(0.0) { acc, sub in
            let base = sub.billingCycle == "Monthly" ? sub.cost : sub.cost / 12
            let extras = sub.subServices.filter { $0.status != .paused }.reduce(0.0) { $0 + $1.cost }
            return acc + base + extras
        }
    }
    
    private var totalAnnualBurn: Double {
        totalMonthlyBurn * 12
    }
    
    // Aesthetic tokens for the White Paper receipt
    private let paperColor = Color(hex: "#F8F9FA")
    private let inkColor = Color(hex: "#1A1A1A")
    private let fadedInk = Color(hex: "#1A1A1A").opacity(0.6)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Receipt Content
                    VStack(alignment: .leading, spacing: 16) {
                        receiptHeader
                        
                        dashedDivider
                        
                        ForEach(activeSubscriptions) { sub in
                            subscriptionItem(sub: sub)
                            dashedDivider
                        }
                        
                        paymentBreakdown
                        dashedDivider
                        
                        receiptFooter
                    }
                    .padding(24)
                    .background(paperColor)
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 16)
                .shadow(color: .white.opacity(0.1), radius: 20, x: 0, y: 10)
            }
            .background(Color(hex: "#121212").ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .font(.system(.body, design: .monospaced).bold())
                        .foregroundStyle(.white)
                }
            }
        }
    }
    
    // MARK: - Components
    
    private var dashedDivider: some View {
        Text(String(repeating: "- ", count: 50))
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(fadedInk)
            .lineLimit(1)
            .padding(.vertical, 8)
    }
    
    private var receiptHeader: some View {
        VStack(alignment: .center, spacing: 6) {
            Text("ZIFR COMMAND CENTER")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
            Text("SUBSCRIPTION REPORT")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
            
            Text(company.name.uppercased())
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .padding(.top, 4)
            
            Text(Date().formatted(date: .numeric, time: .shortened))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(fadedInk)
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(inkColor)
    }
    
    private func subscriptionItem(sub: Subscription) -> some View {
        let baseCost = sub.billingCycle == "Monthly" ? sub.cost : sub.cost / 12
        let extras = sub.subServices.filter { $0.status != .paused }.reduce(0.0) { $0 + $1.cost }
        let totalSubMonthly = baseCost + extras
        let impactPct = totalMonthlyBurn > 0 ? (totalSubMonthly / totalMonthlyBurn) * 100 : 0
        
        let bankTuple = getBankAccountTuple(for: sub)
        
        return VStack(alignment: .leading, spacing: 10) {
            // Title & Cost
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sub.name.uppercased())
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                    if sub.isFree {
                        Text("FREE TIER")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(fadedInk)
                    } else {
                        Text("$\(String(format: "%.2f", sub.cost)) / \(sub.billingCycle.prefix(2).uppercased())")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(fadedInk)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f%%", impactPct))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                    Text("IMPACT")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(fadedInk)
                }
            }
            .foregroundStyle(inkColor)
            
            // Payment & Auto-pay Context
            if !sub.isFree {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        Text("PAID FROM:").frame(width: 80, alignment: .leading)
                        if let b = bankTuple {
                            Text("\(b.bank) • \(b.account)")
                        } else {
                            Text(sub.paymentMethod ?? "UNKNOWN")
                        }
                    }
                    HStack(alignment: .top) {
                        Text("AUTO-PAY:").frame(width: 80, alignment: .leading)
                        Text(sub.renew == "Manual" ? "NO" : "YES")
                    }
                    HStack(alignment: .top) {
                        Text("NEXT DUE:").frame(width: 80, alignment: .leading)
                        Text(sub.nextRenewal ?? "—")
                    }
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(fadedInk)
            }
            
            // Supplemental Services
            if !sub.subServices.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SUPPLEMENTAL SERVICES (\(sub.subServices.count)):")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                    ForEach(sub.subServices.indices, id: \.self) { i in
                        let ss = sub.subServices[i]
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("- \(ss.name.isEmpty ? "Unnamed Service" : ss.name)")
                                Spacer()
                                Text("$\(String(format: "%.0f", ss.cost))")
                            }
                            if !ss.purpose.isEmpty {
                                Text("  PURPOSE: \(ss.purpose)").foregroundStyle(fadedInk)
                            }
                        }
                    }
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(inkColor)
                .padding(.top, 2)
            }
            
            // Linked Emails
            if !sub.linkedEmails.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LINKED EMAILS (\(sub.linkedEmails.count)):")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                    ForEach(sub.linkedEmails.indices, id: \.self) { i in
                        let le = sub.linkedEmails[i]
                        VStack(alignment: .leading, spacing: 2) {
                            Text("- \(le.email)")
                            if !le.usedFor.isEmpty {
                                Text("  PURPOSE: \(le.usedFor)").foregroundStyle(fadedInk)
                            }
                            if !le.notes.isEmpty {
                                Text("  NOTES: \(le.notes.joined(separator: ", "))").foregroundStyle(fadedInk)
                            }
                        }
                    }
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(inkColor)
                .padding(.top, 2)
            }
        }
    }
    
    private var receiptFooter: some View {
        VStack(spacing: 8) {
            HStack {
                Text("TOTAL MONTHLY BURN")
                Spacer()
                Text("$\(String(format: "%.2f", totalMonthlyBurn))")
            }
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            
            HStack {
                Text("EST. ANNUAL BURN")
                Spacer()
                Text("$\(String(format: "%.2f", totalAnnualBurn))")
            }
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(fadedInk)
            
            Text("END OF REPORT")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .padding(.top, 16)
        }
        .foregroundStyle(inkColor)
    }
    
    private var paymentBreakdown: some View {
        // Group subs by payment source
        var breakdown: [String: [(name: String, cost: Double)]] = [:]
        
        for sub in activeSubscriptions {
            let baseCost = sub.billingCycle == "Monthly" ? sub.cost : sub.cost / 12
            let extras = sub.subServices.filter { $0.status != .paused }.reduce(0.0) { $0 + $1.cost }
            let totalSubMonthly = baseCost + extras
            
            if totalSubMonthly == 0 { continue } // Skip free subs for the payment breakdown
            
            let sourceName: String
            if let tuple = getBankAccountTuple(for: sub) {
                sourceName = "\(tuple.bank) • \(tuple.account)"
            } else {
                sourceName = sub.paymentMethod?.isEmpty == false ? sub.paymentMethod! : "UNKNOWN SOURCE"
            }
            
            breakdown[sourceName, default: []].append((name: sub.name.isEmpty ? "Unnamed Service" : sub.name, cost: totalSubMonthly))
        }
        
        let sortedSources = breakdown.keys.sorted()
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("PAYMENT SOURCE BREAKDOWN")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .padding(.bottom, 4)
            
            ForEach(sortedSources, id: \.self) { source in
                let items = breakdown[source]!
                let totalCost = items.reduce(0.0) { $0 + $1.cost }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(source.uppercased())
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                        Spacer()
                        Text("$\(String(format: "%.2f", totalCost))")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    
                    ForEach(items.indices, id: \.self) { i in
                        let item = items[i]
                        HStack {
                            Text("- \(item.name)")
                            Spacer()
                            Text("$\(String(format: "%.2f", item.cost))")
                        }
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(fadedInk)
                    }
                }
            }
        }
        .foregroundStyle(inkColor)
    }

    // MARK: - Helpers
    
    private func getBankAccountTuple(for sub: Subscription) -> (bank: String, account: String)? {
        if (sub.paymentMethod ?? "").isEmpty { return nil }
        
        if let card = cards.first(where: { $0.name == sub.paymentMethod }) {
            let inst = (card.institutionName ?? "").isEmpty ? "Paid From" : card.institutionName!
            let suffix = (card.last4 ?? "").isEmpty ? "" : " ••••\(card.last4 ?? "")"
            return (inst, "\(card.name)\(suffix)")
        }
        
        for inst in institutions {
            if let acc = inst.accounts.first(where: { ($0.name.isEmpty ? $0.type : $0.name) == sub.paymentMethod }) {
                let instName = inst.name.isEmpty ? "Paid From" : inst.name
                let accName = acc.name.isEmpty ? acc.type : acc.name
                let suffix = (acc.last4 ?? "").isEmpty ? "" : " ••••\(acc.last4 ?? "")"
                return (instName, "\(accName)\(suffix)")
            }
        }
        return nil
    }
}
