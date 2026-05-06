import SwiftUI

struct FinancialView: View {
    let company: Company
    let cards: [FinancialCard]
    let institutions: [Institution]
    let loans: [Loan]
    @Bindable var vm: AppViewModel
    @Environment(AppState.self) private var appState

    @State private var editingCard: FinancialCard? = nil
    @State private var editingInst: Institution? = nil
    @State private var editingLoan: Loan? = nil
    @State private var newCard: FinancialCard? = nil
    @State private var newInst: Institution? = nil
    @State private var newLoan: Loan? = nil
    @State private var shareResourceId: UUID = UUID()
    @State private var shareResourceType: String = "all_financials"
    @State private var shareResourceTitle: String = "All Financials"
    @State private var showShareSheet = false
    @State private var poppedCardId: String? = nil
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
            VStack(spacing: 0) {
                // ── Action Bar ──
                HStack(spacing: 8) {
                    Spacer()

                    Menu {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            shareResourceId = company.id
                            shareResourceType = "all_financials"
                            shareResourceTitle = "All Financials"
                            showShareSheet = true
                        } label: {
                            Label("All Financials", systemImage: "folder.badge.person.crop")
                        }
                        
                        if !institutions.isEmpty {
                            Section("Institutions") {
                                ForEach(institutions) { inst in
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        shareResourceId = inst.id
                                        shareResourceType = "institution"
                                        shareResourceTitle = inst.name.isEmpty ? "Institution" : inst.name
                                        showShareSheet = true
                                    } label: {
                                        Label(inst.name.isEmpty ? "Unnamed" : inst.name, systemImage: "person.crop.circle.badge.plus")
                                    }
                                }
                            }
                        }
                        if !cards.isEmpty {
                            Section("Cards") {
                                ForEach(cards) { card in
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        shareResourceId = card.id
                                        shareResourceType = "card"
                                        shareResourceTitle = card.name.isEmpty ? "Card" : card.name
                                        showShareSheet = true
                                    } label: {
                                        Label(card.name.isEmpty ? "Unnamed" : card.name, systemImage: "person.crop.circle.badge.plus")
                                    }
                                }
                            }
                        }
                        if !loans.isEmpty {
                            Section("Loans") {
                                ForEach(loans) { loan in
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        shareResourceId = loan.id
                                        shareResourceType = "loan"
                                        shareResourceTitle = loan.name.isEmpty ? "Loan" : loan.name
                                        showShareSheet = true
                                    } label: {
                                        Label(loan.name.isEmpty ? "Unnamed" : loan.name, systemImage: "person.crop.circle.badge.plus")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.gray)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                    }

                    Menu {
                        Button {
                            newInst = vm.addInstitution(appState: appState, userId: company.userId, companyId: company.id)
                        } label: {
                            Label("Add Account", systemImage: "building.columns")
                        }
                        if !institutions.isEmpty {
                            Button {
                                newCard = vm.addCard(appState: appState, userId: company.userId, companyId: company.id)
                            } label: {
                                Label("Add Card", systemImage: "creditcard")
                            }
                            Button {
                                newLoan = vm.addLoan(appState: appState, userId: company.userId, companyId: company.id)
                            } label: {
                                Label("Add Loan", systemImage: "dollarsign.circle")
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("ADD ACCOUNT").font(.system(size: 12, weight: .semibold)).tracking(1).foregroundStyle(Color(hex: "#A2A2A2"))
                            Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.white.opacity(0.4))
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 36)
                        .background(Color(hex: "#1C1C1E"))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 15)
                .padding(.bottom, 20)
                
                // ── Main Wallet Stack ──
                LazyVStack(spacing: 20) {
                    if institutions.isEmpty && cards.isEmpty && loans.isEmpty {
                        // Empty State — dummy Amex wallet with glass overlay
                        let dummyAmex = Institution(
                            id: UUID(),
                            userId: UUID(),
                            companyId: UUID(),
                            name: "American Express",
                            loginUrl: "americanexpress.com",
                            username: "founder@company.com",
                            password: "••••••••",
                            accounts: [
                                InstitutionAccount(name: "Amex Platinum", type: "Credit Card", last4: "1005", balance: 0, limit: 25000)
                            ]
                        )
                        let dummyCard1 = FinancialCard(
                            id: UUID(),
                            userId: UUID(),
                            companyId: UUID(),
                            name: "Amex Platinum",
                            institutionName: "American Express",
                            cardHolder: "Jane Founder",
                            last4: "1005",
                            expiry: "09/27",
                            network: "Amex",
                            type: "Credit",
                            limit: 25000,
                            autopay: "Yes",
                            apr: 29.99
                        )
                        
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            newInst = vm.addInstitution(appState: appState, userId: company.userId, companyId: company.id)
                        } label: {
                            ZStack {
                                // Dummy wallet stack
                                VStack(spacing: 0) {
                                    ZStack(alignment: .top) {
                                        FinancialCardVisual(card: dummyCard1, isPopped: false)
                                            .frame(height: 110)
                                            .offset(y: -36)
                                            .zIndex(2)
                                        InstitutionCardView(
                                            institution: dummyAmex,
                                            totalMonthlyPayment: 0,
                                            cardCount: 1,
                                            loanCount: 0,
                                            loans: [],
                                            vm: vm,
                                            onEdit: {},
                                            onEditLoan: { _ in }
                                        )
                                        .zIndex(3)
                                    }
                                    .padding(.top, 36)
                                }
                                .allowsHitTesting(false)
                                .blur(radius: 3)
                                
                                // Glass overlay
                                VStack(spacing: 16) {
                                    Image(systemName: "dollarsign.bank.building")
                                        .font(.system(size: 28))
                                        .foregroundStyle(.white)
                                    Text("ADD YOUR FIRST INSTITUTION")
                                        .font(.system(size: 11, weight: .black))
                                        .textCase(.uppercase)
                                        .tracking(2)
                                        .foregroundStyle(.white)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 24))
                            }
                        }
                        .padding(.top, 40)
                    } else {
                        // Institutions Block
                        if !institutions.isEmpty {
                                ForEach(institutions) { inst in
                                    let instCards = cards.filter { ($0.institutionName ?? "").lowercased() == inst.name.lowercased() }
                                    let instLoans = loans.filter { ($0.lender ?? "").lowercased() == inst.name.lowercased() }
                                    walletStackForInstitution(inst: inst, instCards: instCards, instLoans: instLoans)
                                }
                            }
                        
                        // Remaining standalone accounts block
                        let standaloneCards = cards.filter { c in !institutions.contains { ($0.name ?? "").lowercased() == (c.institutionName ?? "").lowercased() } }
                        let standaloneLoans = loans.filter { l in !institutions.contains { ($0.name ?? "").lowercased() == (l.lender ?? "").lowercased() } }
                        
                        if !standaloneCards.isEmpty || !standaloneLoans.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Other Standalone Accounts")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.3))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 24)
                                    .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.white.opacity(0.08)), alignment: .top)
                                
                                standaloneWalletStack(cards: standaloneCards)
                                ForEach(standaloneLoans) { loan in
                                    LoanCardView(loan: loan, onEdit: { editingLoan = loan })
                                        .id(loan.id)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            }
    }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showShareSheet) {
            ShareEntitySheet(resourceId: shareResourceId, resourceType: shareResourceType, resourceTitle: shareResourceTitle)
        }
        .sheet(item: $newInst) { i in EditInstitutionSheet(institution: i, institutions: institutions, cards: cards, loans: loans, vm: vm, isNew: true) }
        .sheet(item: $editingInst) { i in EditInstitutionSheet(institution: i, institutions: institutions, cards: cards, loans: loans, vm: vm, isNew: false) }
        .sheet(item: $newCard) { c in EditCardSheet(card: c, vm: vm, institutions: institutions, cards: cards, isNew: true) }
        .sheet(item: $editingCard) { c in EditCardSheet(card: c, vm: vm, institutions: institutions, cards: cards, isNew: false) }
        .sheet(item: $newLoan) { l in EditLoanSheet(loan: l, vm: vm, isNew: true, institutions: institutions, cards: cards) }
        .sheet(item: $editingLoan) { l in EditLoanSheet(loan: l, vm: vm, isNew: false, institutions: institutions, cards: cards) }
        .onChange(of: vm.deepLinkModelId) { _, newValue in
            handleDeepLink(id: newValue, proxy: proxy)
        }
        .onAppear {
            handleDeepLink(id: vm.deepLinkModelId, proxy: proxy)
        }
        }
    }
    
    private func handleDeepLink(id: UUID?, proxy: ScrollViewProxy) {
        guard let id = id else { return }
        if let c = cards.first(where: { $0.id == id }) {
            poppedCardId = c.id.uuidString
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    proxy.scrollTo(c.id, anchor: .center)
                }
            }
            vm.deepLinkModelId = nil
        } else if let i = institutions.first(where: { $0.id == id }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    proxy.scrollTo(i.id, anchor: .center)
                }
            }
            vm.deepLinkModelId = nil
        } else if let l = loans.first(where: { $0.id == id }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    proxy.scrollTo(l.id, anchor: .center)
                }
            }
            vm.deepLinkModelId = nil
        }
    }
    
    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(Color.white.opacity(0.4))
                Text(label).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            }
            .padding(.horizontal, 18)
            .frame(height: 36)
            .background(Color(hex: "#1C1C1E"))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }
    
    @ViewBuilder
    private func walletStackForInstitution(inst: Institution, instCards: [FinancialCard], instLoans: [Loan]) -> some View {
        let peekOffset: CGFloat = 36
        let cardH: CGFloat = 110
        let fullCardH: CGFloat = 210
        
        ZStack(alignment: .top) {
            if !instCards.isEmpty {
                ForEach(Array(instCards.enumerated()), id: \.element.id) { index, card in
                        let isPopped = poppedCardId == card.id.uuidString
                        let yOffset = isPopped ? 16.0 : -(peekOffset + CGFloat(index) * peekOffset)
                        let scale = isPopped ? 1.0 : max(0.85, 1.0 - CGFloat(index) * 0.03)
                        
                        FinancialCardVisual(card: card, isPopped: isPopped)
                            .id(card.id)
                            .frame(height: isPopped ? fullCardH : cardH)
                            .scaleEffect(scale)
                            .offset(y: yOffset)
                            .zIndex(isPopped ? 25 : Double(instCards.count - index))
                            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isPopped)
                            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: poppedCardId)
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                if poppedCardId == card.id.uuidString { poppedCardId = nil } else { poppedCardId = card.id.uuidString }
                            }
                            .onLongPressGesture {
                                editingCard = card
                            }
                            .highPriorityGesture(
                                DragGesture(minimumDistance: 10)
                                    .onEnded { value in
                                        if isPopped && value.translation.height < -10 {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            poppedCardId = nil
                                        }
                                    },
                                including: isPopped ? .gesture : .none
                            )
                    }
            }
            
            InstitutionCardView(
                institution: inst,
                totalMonthlyPayment: instLoans.reduce(0) { $0 + $1.monthlyPayment },
                cardCount: instCards.count,
                loanCount: instLoans.count,
                loans: instLoans,
                vm: vm,
                onEdit: { editingInst = inst },
                onEditLoan: { editingLoan = $0 }
            )
            .id(inst.id)
            .zIndex(20)
        }
        .padding(.top, instCards.isEmpty ? 0 : CGFloat(instCards.count) * peekOffset + 16)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func standaloneWalletStack(cards: [FinancialCard]) -> some View {
        let peekOffset: CGFloat = 36
        let fullCardH: CGFloat = 210
        
        if !cards.isEmpty {
            ZStack(alignment: .bottom) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    let isPopped = poppedCardId == card.id.uuidString
                    let yOffset = isPopped ? 0.0 : -(CGFloat(index) * peekOffset)
                    let scale = isPopped ? 1.0 : max(0.85, 1.0 - CGFloat(index) * 0.03)
                    
                    FinancialCardVisual(card: card, isPopped: isPopped)
                        .id(card.id)
                        .frame(height: fullCardH)
                        .scaleEffect(scale)
                        .offset(y: yOffset)
                        .zIndex(isPopped ? 150 : Double(cards.count - index))
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isPopped)
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: poppedCardId)
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if poppedCardId == card.id.uuidString { poppedCardId = nil } else { poppedCardId = card.id.uuidString }
                        }
                        .onLongPressGesture {
                            editingCard = card
                        }
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 10)
                                .onEnded { value in
                                    if isPopped && value.translation.height < -10 {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        poppedCardId = nil
                                    }
                                },
                            including: isPopped ? .gesture : .none
                        )
                }
                
                // Front Leather Sleeve
                WalletSleeveView()
                    .zIndex(100)
                    .allowsHitTesting(false)
            }
            .padding(.top, CGFloat(max(0, cards.count - 1)) * peekOffset + 4)
            .padding(.bottom, 16)
        }
    }
}

// ── Wallet Sleeve Component ──
struct AggressiveSleeveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius: CGFloat = 20
        let topYLeft: CGFloat = 35
        let topYRight: CGFloat = 0
        
        path.move(to: CGPoint(x: 0, y: topYLeft))
        path.addLine(to: CGPoint(x: rect.width, y: topYRight))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - radius))
        path.addArc(center: CGPoint(x: rect.width - radius, y: rect.height - radius),
                    radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: radius, y: rect.height))
        path.addArc(center: CGPoint(x: radius, y: rect.height - radius),
                    radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: 0, y: topYLeft))
        
        return path
    }
}

struct WalletSleeveView: View {
    var body: some View {
        ZStack {
            // Main Leather Body (Matte Finish)
            AggressiveSleeveShape()
                .fill(Color(hex: "#121212"))
                // Subtle overlay to simulate deep matte leather finish
                .overlay(
                    AggressiveSleeveShape()
                        .fill(Color.black.opacity(0.15))
                        .blendMode(.multiply)
                )
                .shadow(color: .black.opacity(0.6), radius: 10, y: -4)
            
            // Premium Stitching
            AggressiveSleeveShape()
                .stroke(Color(hex: "#2B3A3B"), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .padding(6)
                
            // Edge highlight
            AggressiveSleeveShape()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
        .frame(height: 120)
    }
}

// ── Shared Card Visual (Mini overlapping view for stack) ──
struct FinancialCardVisual: View {
    let card: FinancialCard
    let isPopped: Bool
    
    @Environment(AppState.self) private var appState
    
    private var subscriptions: [Subscription] { appState.subscriptions }
    
    private var paysForServices: [(name: String, cost: Double)] {
        let cardName = card.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cardName.isEmpty else { return [] }
        var results: [(name: String, cost: Double)] = []
        for sub in subscriptions {
            if (sub.paymentMethod ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == cardName {
                results.append((name: sub.name.isEmpty ? "Unnamed Service" : sub.name, cost: sub.cost))
            }
            for subSvc in sub.subServices {
                if (subSvc.paymentMethod ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == cardName {
                    results.append((name: subSvc.name.isEmpty ? "Unnamed Sub-service" : subSvc.name, cost: subSvc.cost))
                }
            }
        }
        return results
    }

    private var promoEndsString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yy"
        return formatter.string(from: card.promoEnds ?? Date())
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(
                    colors: card.cardGradientHex.map { Color(hex: $0) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(isPopped ? Color.white.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
            
            let isLight = card.cardGradientHex.first?.uppercased() == "#FFFFFF"
            let primaryColor = isLight ? Color.black : Color.white
            let secondaryColor = isLight ? Color.black.opacity(0.7) : Color.white.opacity(0.7)
            
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(card.name.isEmpty ? "Card" : card.name)
                            .font(.system(size: isPopped ? 16 : 12, weight: .bold))
                            .foregroundStyle(primaryColor)
                        
                        if !(card.last4 ?? "").isEmpty {
                            Text("•••• \(card.last4 ?? "")")
                                .font(.system(size: isPopped ? 14 : 10, weight: .semibold))
                                .foregroundStyle(secondaryColor)
                        }
                    }
                    Spacer()
                    Text("\(card.network) \(card.type)")
                        .font(.system(size: isPopped ? 14 : 12, weight: .semibold))
                        .foregroundStyle(secondaryColor)
                        .italic()
                }
                
                Spacer(minLength: 0)
                
                if isPopped {
                    HStack {
                        Text((card.cardHolder ?? "").isEmpty ? "Name on Card" : (card.cardHolder ?? ""))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isLight ? Color.black.opacity(0.6) : Color.white.opacity(0.6))
                        Spacer()
                        Text((card.expiry ?? "").isEmpty ? "—" : (card.expiry ?? ""))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(isLight ? Color.black.opacity(0.6) : Color.white.opacity(0.6))
                    }
                    .padding(.bottom, 6)
                    
                    let services = paysForServices
                    let hasFinancials = card.limit > 0 || card.balance > 0 || card.apr > 0 || card.promoApr > 0 || (card.autopay != "N/A" && !card.autopay.isEmpty)
                    
                    if hasFinancials || !(card.paidFrom ?? "").isEmpty || !services.isEmpty {
                        Divider()
                            .background(isLight ? Color.black.opacity(0.1) : Color.white.opacity(0.06))
                            .padding(.bottom, 6)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            // --- Financials Grid ---
                            if hasFinancials {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                                    if card.balance > 0 { cardMetric(title: "BALANCE", value: "$\(String(format: "%.0f", card.balance))", isLight: isLight, primaryColor: primaryColor) }
                                    if card.limit > 0 { cardMetric(title: "LIMIT", value: "$\(String(format: "%.0f", card.limit))", isLight: isLight, primaryColor: primaryColor) }
                                    if card.apr > 0 { cardMetric(title: "APR", value: "\(String(format: "%.1f", card.apr))%", isLight: isLight, primaryColor: primaryColor) }
                                    if card.promoApr > 0 { 
                                        cardMetric(title: "PROMO", value: "\(String(format: "%.1f", card.promoApr))%", isLight: isLight, primaryColor: primaryColor) 
                                        cardMetric(title: "PROMO END", value: promoEndsString, isLight: isLight, primaryColor: primaryColor)
                                    }
                                    if card.autopay != "N/A" && !card.autopay.isEmpty { cardMetric(title: "AUTO PAY", value: card.autopay, isLight: isLight, primaryColor: primaryColor) }
                                }
                                
                                if !(card.paidFrom ?? "").isEmpty || !services.isEmpty {
                                    Divider()
                                        .background(isLight ? Color.black.opacity(0.1) : Color.white.opacity(0.06))
                                }
                            }
                            
                            if !(card.paidFrom ?? "").isEmpty {
                                HStack {
                                    Text("PAY FROM")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(isLight ? Color.black.opacity(0.4) : Color.white.opacity(0.4))
                                    Spacer()
                                    Text(card.paidFrom ?? "")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(primaryColor)
                                }
                            }
                            
                            if !(card.paidFrom ?? "").isEmpty && !services.isEmpty {
                                Divider()
                                    .background(isLight ? Color.black.opacity(0.1) : Color.white.opacity(0.06))
                            }
                            
                            if !services.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("PAYS FOR")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(isLight ? Color.black.opacity(0.4) : Color.white.opacity(0.4))
                                    
                                    ForEach(Array(services.prefix(2).enumerated()), id: \.offset) { index, svc in
                                        HStack {
                                            Text(svc.name)
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(primaryColor)
                                                .lineLimit(1)
                                            Spacer()
                                            Text("$\(String(format: "%.0f", svc.cost))")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(primaryColor)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .contentShape(Rectangle())
    }
    
    @ViewBuilder
    private func cardMetric(title: String, value: String, isLight: Bool, primaryColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(isLight ? Color.black.opacity(0.4) : Color.white.opacity(0.4))
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(primaryColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Institution Card
struct InstitutionCardView: View {
    @Environment(AppState.self) private var appState
    let institution: Institution
    let totalMonthlyPayment: Double
    let cardCount: Int
    let loanCount: Int
    let loans: [Loan]
    @Bindable var vm: AppViewModel
    let onEdit: () -> Void
    let onEditLoan: (Loan) -> Void
    @State private var expanded = false
    @State private var copiedField: String? = nil
    @State private var passwordRevealed = false

    @State private var editingAccount: InstitutionAccount? = nil
    @State private var accountDraft = InstitutionAccount()

    var body: some View {
        MiloomListCard {
            // ── Tappable header (triggers edit sheet) ──────────────────────
            Button(action: onEdit) {
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16).fill(Color.clear).frame(width: 56, height: 56)
                            if !(institution.loginUrl ?? "").isEmpty {
                                FaviconImage(website: institution.loginUrl ?? "", size: 36)
                            } else {
                                Image(systemName: "building.columns")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.8))
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(institution.name.isEmpty ? "Institution" : institution.name)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)

                            HStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Text("\(institution.accounts.count)").foregroundStyle(.white)
                                    Text("Accounts").foregroundStyle(Color(hex: "#C1AA78"))
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(0.3)
                                
                                statusPipe()
                                
                                HStack(spacing: 4) {
                                    Text("\(cardCount)").foregroundStyle(.white)
                                    Text("Cards").foregroundStyle(Color(hex: "#C1AA78"))
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(0.3)
                                
                                statusPipe()
                                
                                HStack(spacing: 4) {
                                    Text("\(loanCount)").foregroundStyle(.white)
                                    Text("Loans").foregroundStyle(Color(hex: "#C1AA78"))
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(0.3)
                            }
                        }
                        .padding(.top, 8)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 6)
                    
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color.white.opacity(0.08))
                        .frame(width: UIScreen.main.bounds.width * 0.8)
                        .padding(.bottom, 12)

                    // ── Credentials (tap-to-copy) ────
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            copyableCredential(
                                id: institution.id.uuidString,
                                label: "Login ID",
                                value: (institution.username ?? "").isEmpty ? ((institution.email ?? "").isEmpty ? "—" : (institution.email ?? "")) : (institution.username ?? ""),
                                field: "login"
                            )
                            copyableCredential(
                                id: institution.id.uuidString,
                                label: "Password",
                                value: institution.password ?? "",
                                field: "password",
                                isPassword: true
                            )
                        }
                        
                        let loginValue = (institution.username ?? "").isEmpty ? (institution.email ?? "") : (institution.username ?? "")
                        DynamicLoginLabelView(loginId: loginValue, ignoreInstitutionId: institution.id.uuidString)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PremiumButtonStyle())

            // ── Accordion ──────────────────────────────────────────────────
            MiloomAccordion(title: expanded ? "Hide Accounts" : "Loans & Accounts", count: institution.accounts.count + loanCount, expanded: expanded, action: {
                withAnimation(.spring(response: 0.35)) { expanded.toggle() }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                VStack(spacing: 12) {
                    ForEach(institution.accounts) { acc in
                        Button {
                            accountDraft = acc
                            editingAccount = acc
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(acc.name.isEmpty ? "Account" : acc.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                    
                                    HStack(spacing: 6) {
                                        Text(acc.type)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.6))
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(acc.balance.currencyString)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
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

                    ForEach(loans) { loan in
                        Button {
                            onEditLoan(loan)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text((loan.name ?? "").isEmpty ? "Loan" : loan.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                    
                                    HStack(spacing: 6) {
                                        Text(loan.role)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.6))
                                        Text("|")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.2))
                                        let rateStr = String(format: loan.interestRate.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f%%" : "%.2f%%", loan.interestRate)
                                        Text("\(rateStr) APR")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.6))
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(loan.principalAmount.currencyString)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
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
                }
            }
        }
        .sheet(item: $editingAccount) { _ in
            InstitutionAccountHUD(
                draft: $accountDraft,
                isNew: false,
                institutionName: institution.name.isEmpty ? "Institution" : institution.name,
                onSave: {
                    if let idx = institution.accounts.firstIndex(where: { $0.id == accountDraft.id }) {
                        var updatedInst = institution
                        updatedInst.accounts[idx] = accountDraft
                        vm.saveInstitution(updatedInst, appState: appState)
                    }
                    editingAccount = nil
                },
                onCancel: { editingAccount = nil },
                onDelete: {
                    if let idx = institution.accounts.firstIndex(where: { $0.id == accountDraft.id }) {
                        let acc = institution.accounts[idx]
                        vm.cleanUpCustomPaymentMethod(name: acc.name.isEmpty ? acc.type : acc.name)
                        var updatedInst = institution
                        updatedInst.accounts.remove(at: idx)
                        vm.saveInstitution(updatedInst, appState: appState)
                    }
                    editingAccount = nil
                }
            )
            .presentationDetents([.height(420)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
    }

    private func costColumn(value: Double, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("$\(String(format: "%.0f", value))")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(hex: "#C1AA78"))
        }
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
            .proContextMenu(password: institution.password, loginId: (institution.username ?? "").isEmpty ? (institution.email ?? "") : (institution.username ?? ""), last4: nil)
        }
    }
}

// MARK: - Financial Card View
struct FinancialCardView: View {
    let card: FinancialCard
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(
                            colors: card.cardGradientHex.map { Color(hex: $0) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 44, height: 28)
                    Text(card.network == "Amex" ? "••• \(card.last4 ?? "")" : "•••• \(card.last4 ?? "")")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(card.cardGradientHex.first?.uppercased() == "#FFFFFF" ? .black : .white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(card.name.isEmpty ? "Card" : card.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    HStack(spacing: 6) {
                        Text(card.type)
                            .font(.system(size: 9, weight: .bold))
                            .textCase(.uppercase)
                            .foregroundStyle(Color.white.opacity(0.4))
                        Text("•")
                            .foregroundStyle(Color.white.opacity(0.2))
                        Text(card.network)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.4))
                        Text("•")
                            .foregroundStyle(Color.white.opacity(0.2))
                        Text((card.expiry ?? "").isEmpty ? "—" : (card.expiry ?? ""))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                }
                Spacer()
                Circle()
                    .fill(card.status.statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: card.status.statusColor, radius: 4)
            }
            .padding(14)
            .background(Color(hex: "#2C2C2E")).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .proContextMenu(password: card.password, loginId: card.login, last4: card.last4)
    }
}

private extension FinancialCard {
    var cardGradientHex: [String] {
        let inst = (institutionName ?? "").lowercased()
        
        // Known Institutions
        if inst.contains("apple") { return ["#FFFFFF", "#F0F0F5"] }
        if inst.contains("chase") { return ["#113b8a", "#0a2354"] }
        if inst.contains("america") || inst.contains("bofa") { return ["#E31837", "#9A0000"] }
        if inst.contains("wells fargo") { return ["#d71e28", "#8a0c13"] }
        if inst.contains("citi") { return ["#003B70", "#002040"] }
        if inst.contains("capital one") { return ["#00284f", "#001224"] }
        if inst.contains("american express") || inst.contains("amex") { return ["#005E9D", "#002D54"] }
        if inst.contains("discover") { return ["#FF6000", "#A84000"] }
        if inst.contains("mercury") { return ["#4A5568", "#1A202C"] }
        if inst.contains("stripe") { return ["#635BFF", "#3E38A3"] }
        if inst.contains("ramp") { return ["#D0F224", "#9DB814"] }
        if inst.contains("sofi") { return ["#23B5E8", "#0087B5"] } // Sky Blue to Deep Cyan

        // Fallback to Network
        switch network {
        case "Visa": return ["#101345", "#060824"]
        case "Mastercard": return ["#5C0000", "#2E0000"]
        case "Amex": return ["#004B7A", "#00233B"]
        case "Discover": return ["#B34700", "#662800"]
        default: return ["#1C1C1E", "#0A0A0C"]
        }
    }
}

// MARK: - Loan Card View
struct LoanCardView: View {
    let loan: Loan
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            let amort = loan.amortization
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text((loan.name ?? "").isEmpty ? "Loan" : loan.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text((loan.lender ?? "").isEmpty ? "—" : (loan.lender ?? ""))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        let rateStr = String(format: loan.interestRate.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f%%" : "%.2f%%", loan.interestRate)
                        Text(rateStr)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("rate")
                            .zifrLabel()
                    }
                    .padding(.trailing, 12)
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(amort.totalPrincipal.currencyString)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("principal")
                            .zifrLabel()
                    }
                }

                // Progress Bar
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color(hex: "#545454"))
                                .frame(width: geo.size.width * (amort.principalPct / 100))
                            Rectangle()
                                .fill(Color(hex: "#742C2D"))
                        }
                    }
                    .frame(height: 8)
                    .clipShape(Capsule())
                    .background(Color.white.opacity(0.05))
                }

                HStack {
                    let freqLabel = loan.scheduleFrequency == "Weekly" ? "Wk Pmt" : (loan.scheduleFrequency == "Yearly" ? "Yr Pmt" : "Mo Pmt")
                    statBadge(label: freqLabel, value: amort.monthlyPayment.currencyString)
                    Spacer()
                    statBadge(label: "Interest", value: amort.totalInterest.currencyString)
                    Spacer()
                    statBadge(label: "Total Cost", value: amort.totalCost.currencyString)
                }

                HStack {
                    statBadge(label: "Remaining", value: loan.remainingBalance.currencyString)
                    Spacer()
                    statBadge(label: "Start", value: loan.startDate.numericDisplay)
                    Spacer()
                    if let maturity = loan.maturityDate {
                        statBadge(label: "Maturity", value: maturity.numericDisplay)
                    } else {
                        statBadge(label: "Maturity", value: "—")
                    }
                }
            }
            .padding(16)
            .background(Color(hex: "#2C2C2E")).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func statBadge(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).zifrLabel()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

















// MARK: - Custom Swipe to Delete for ScrollView
struct ZifrSwipeToDeleteModifier: ViewModifier {
    let action: () -> Void
    @State private var offset: CGFloat = 0
    
    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            Color.red
                .overlay(alignment: .trailing) {
                    Image(systemName: "trash")
                        .foregroundColor(.white)
                        .padding(.trailing, 20)
                }
            
            content
                .background(Color(hex: "#2C2C2E"))
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width < 0 {
                                offset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring()) {
                                if value.translation.width < -80 {
                                    action()
                                    offset = 0
                                } else {
                                    offset = 0
                                }
                            }
                        }
                )
        }
        .clipped()
    }
}

// MARK: - Custom Swipe Actions for ScrollView
struct ZifrSwipeActionsModifier: ViewModifier {
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var offset: CGFloat = 0
    
    func body(content: Content) -> some View {
        ZStack {
            // Edit Background (Leading)
            Color.blue
                .overlay(alignment: .leading) {
                    Image(systemName: "pencil")
                        .foregroundColor(.white)
                        .padding(.leading, 20)
                }
                .opacity(offset > 0 ? 1 : 0)
            
            // Delete Background (Trailing)
            Color.red
                .overlay(alignment: .trailing) {
                    Image(systemName: "trash")
                        .foregroundColor(.white)
                        .padding(.trailing, 20)
                }
                .opacity(offset < 0 ? 1 : 0)
            
            content
                .background(Color(hex: "#2C2C2E"))
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = value.translation.width
                        }
                        .onEnded { value in
                            withAnimation(.spring()) {
                                if value.translation.width < -80 {
                                    onDelete()
                                    offset = 0
                                } else if value.translation.width > 80 {
                                    onEdit()
                                    offset = 0
                                } else {
                                    offset = 0
                                }
                            }
                        }
                )
        }
        .clipped()
    }
}
