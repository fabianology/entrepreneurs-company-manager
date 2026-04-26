import SwiftUI
import SwiftData

struct FinancialView: View {
    let company: Company
    let cards: [FinancialCard]
    let institutions: [Institution]
    let loans: [Loan]
    @Bindable var vm: AppViewModel
    @Environment(\.modelContext) private var context

    @State private var editingCard: FinancialCard? = nil
    @State private var editingInst: Institution? = nil
    @State private var editingLoan: Loan? = nil
    @State private var newCard: FinancialCard? = nil
    @State private var newInst: Institution? = nil
    @State private var newLoan: Loan? = nil
    @State private var poppedCardId: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // ── Action Bar ──
                HStack(spacing: 8) {
                    Menu {
                        Button {
                            newCard = vm.addCard(context: context, companyId: company.id)
                        } label: {
                            Label("Add Card", systemImage: "creditcard")
                        }
                        Button {
                            newLoan = vm.addLoan(context: context, companyId: company.id)
                        } label: {
                            Label("Add Loan", systemImage: "dollarsign.circle")
                        }
                        Button {
                            newInst = vm.addInstitution(context: context, companyId: company.id)
                        } label: {
                            Label("Add Account", systemImage: "building.columns")
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("SOLO CARD").font(.system(size: 12, weight: .semibold)).tracking(1).foregroundStyle(Color(hex: "#A2A2A2"))
                            Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.white.opacity(0.4))
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 36)
                        .background(Color(hex: "#171717"))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                    }

                    Spacer()
                    
                    Menu {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            print("Triggering CloudKit Sharing for All Financials")
                        } label: {
                            Label("All Financials", systemImage: "folder.badge.person.crop")
                        }
                        
                        Divider()
                        
                        if !institutions.isEmpty {
                            Section("Institutions") {
                                ForEach(institutions) { inst in
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        print("Triggering CloudKit Sharing for \(inst.name)")
                                    } label: {
                                        Label(inst.name.isEmpty ? "Institution" : inst.name, systemImage: "person.crop.circle.badge.plus")
                                    }
                                }
                            }
                        }
                        if !cards.isEmpty {
                            Section("Cards") {
                                ForEach(cards) { card in
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        print("Triggering CloudKit Sharing for \(card.name)")
                                    } label: {
                                        Label(card.name.isEmpty ? "Card" : card.name, systemImage: "person.crop.circle.badge.plus")
                                    }
                                }
                            }
                        }
                        if !loans.isEmpty {
                            Section("Loans") {
                                ForEach(loans) { loan in
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        print("Triggering CloudKit Sharing for \(loan.name)")
                                    } label: {
                                        Label(loan.name.isEmpty ? "Loan" : loan.name, systemImage: "person.crop.circle.badge.plus")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: "#A2A2A2"))
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                    }
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        newInst = vm.addInstitution(context: context, companyId: company.id)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 13, weight: .bold)).foregroundStyle(Color(hex: "#A2A2A2"))
                            Text("INSTITUTION").font(.system(size: 12, weight: .heavy)).tracking(1).foregroundStyle(Color(hex: "#A2A2A2"))
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 36)
                        .background(Color(hex: "#223E5A"))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
                .padding(.bottom, 24)
                
                // ── Main Wallet Stack ──
                LazyVStack(spacing: 20) {
                    if institutions.isEmpty && cards.isEmpty && loans.isEmpty {
                        // Empty State
                        Button {
                            newInst = vm.addInstitution(context: context, companyId: company.id)
                        } label: {
                            VStack(spacing: 12) {
                                Text("🏦").font(.system(size: 40))
                                Text("+ Add Your First Institution")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.5))
                            }
                            .frame(width: 300, height: 200)
                            .background(Color(hex: "#171717").opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [6])))
                        }
                        .padding(.top, 20)
                    } else {
                        // Institutions Block
                        if !institutions.isEmpty {
                                ForEach(institutions) { inst in
                                    let instCards = cards.filter { $0.institutionName.lowercased() == inst.name.lowercased() }
                                    let instLoans = loans.filter { $0.lender.lowercased() == inst.name.lowercased() }
                                    walletStackForInstitution(inst: inst, instCards: instCards, instLoans: instLoans)
                                }
                            }
                        
                        // Remaining standalone accounts block
                        let standaloneCards = cards.filter { c in !institutions.contains { $0.name.lowercased() == c.institutionName.lowercased() } }
                        let standaloneLoans = loans.filter { l in !institutions.contains { $0.name.lowercased() == l.lender.lowercased() } }
                        
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
        .sheet(item: $newInst) { i in EditInstitutionSheet(institution: i, institutions: institutions, cards: cards, loans: loans, vm: vm, isNew: true) }
        .sheet(item: $editingInst) { i in EditInstitutionSheet(institution: i, institutions: institutions, cards: cards, loans: loans, vm: vm, isNew: false) }
        .sheet(item: $newCard) { c in EditCardSheet(card: c, vm: vm, institutions: institutions, cards: cards, isNew: true) }
        .sheet(item: $editingCard) { c in EditCardSheet(card: c, vm: vm, institutions: institutions, cards: cards, isNew: false) }
        .sheet(item: $newLoan) { l in EditLoanSheet(loan: l, vm: vm, isNew: true, institutions: institutions, cards: cards) }
        .sheet(item: $editingLoan) { l in EditLoanSheet(loan: l, vm: vm, isNew: false, institutions: institutions, cards: cards) }
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
            .background(Color(hex: "#171717"))
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
                        let isPopped = poppedCardId == card.id
                        let yOffset = isPopped ? 16.0 : -(peekOffset + CGFloat(index) * peekOffset)
                        let scale = isPopped ? 1.0 : max(0.85, 1.0 - CGFloat(index) * 0.03)
                        
                        FinancialCardVisual(card: card, isPopped: isPopped)
                            .frame(height: isPopped ? fullCardH : cardH)
                            .scaleEffect(scale)
                            .offset(y: yOffset)
                            .zIndex(isPopped ? 25 : Double(instCards.count - index))
                            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isPopped)
                            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: poppedCardId)
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                if poppedCardId == card.id { poppedCardId = nil } else { poppedCardId = card.id }
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
                    let isPopped = poppedCardId == card.id
                    let yOffset = isPopped ? 0.0 : -(CGFloat(index) * peekOffset)
                    let scale = isPopped ? 1.0 : max(0.85, 1.0 - CGFloat(index) * 0.03)
                    
                    FinancialCardVisual(card: card, isPopped: isPopped)
                        .frame(height: fullCardH)
                        .scaleEffect(scale)
                        .offset(y: yOffset)
                        .zIndex(isPopped ? 150 : Double(cards.count - index))
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isPopped)
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: poppedCardId)
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if poppedCardId == card.id { poppedCardId = nil } else { poppedCardId = card.id }
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
                        colors: [Color.white.opacity(0.1), Color.clear],
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
    
    @Query private var subscriptions: [Subscription]
    
    private var paysForServices: [(name: String, cost: Double)] {
        let cardName = card.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cardName.isEmpty else { return [] }
        var results: [(name: String, cost: Double)] = []
        for sub in subscriptions {
            if sub.paymentMethod.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == cardName {
                results.append((name: sub.name.isEmpty ? "Unnamed Service" : sub.name, cost: sub.cost))
            }
            for subSvc in sub.subServices {
                if subSvc.paymentMethod.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == cardName {
                    results.append((name: subSvc.name.isEmpty ? "Unnamed Sub-service" : subSvc.name, cost: subSvc.cost))
                }
            }
        }
        return results
    }

    private var promoEndsString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yy"
        return formatter.string(from: card.promoEnds)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(
                    colors: card.cardGradientHex.map { Color(hex: $0) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(isPopped ? Color.white.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1))
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
                        
                        if !card.last4.isEmpty {
                            Text("•••• \(card.last4)")
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
                        Text(card.cardHolder.isEmpty ? "Name on Card" : card.cardHolder)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isLight ? Color.black.opacity(0.6) : Color.white.opacity(0.6))
                        Spacer()
                        Text(card.expiry.isEmpty ? "—" : card.expiry)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(isLight ? Color.black.opacity(0.6) : Color.white.opacity(0.6))
                    }
                    .padding(.bottom, 6)
                    
                    let services = paysForServices
                    let hasFinancials = card.limit > 0 || card.balance > 0 || card.apr > 0 || card.promoApr > 0 || (card.autopay != "N/A" && !card.autopay.isEmpty)
                    
                    if hasFinancials || !card.paidFrom.isEmpty || !services.isEmpty {
                        Divider()
                            .background(isLight ? Color.black.opacity(0.1) : Color.white.opacity(0.1))
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
                                
                                if !card.paidFrom.isEmpty || !services.isEmpty {
                                    Divider()
                                        .background(isLight ? Color.black.opacity(0.1) : Color.white.opacity(0.1))
                                }
                            }
                            
                            if !card.paidFrom.isEmpty {
                                HStack {
                                    Text("PAY FROM")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(isLight ? Color.black.opacity(0.4) : Color.white.opacity(0.4))
                                    Spacer()
                                    Text(card.paidFrom)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(primaryColor)
                                }
                            }
                            
                            if !card.paidFrom.isEmpty && !services.isEmpty {
                                Divider()
                                    .background(isLight ? Color.black.opacity(0.1) : Color.white.opacity(0.1))
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
        VStack(spacing: 0) {
            // ── Tappable header (triggers edit sheet) ──────────────────────
            Button(action: onEdit) {
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16).fill(Color.clear).frame(width: 56, height: 56)
                            if !institution.loginUrl.isEmpty {
                                FaviconImage(website: institution.loginUrl, size: 36)
                            } else {
                                Image(systemName: "building.columns")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.8))
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(institution.name.isEmpty ? "New Bank" : institution.name)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)

                            HStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Text("\(institution.accounts.count)").foregroundStyle(.white)
                                    Text("Accounts").foregroundStyle(Color.white.opacity(0.4))
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(0.3)
                                
                                statusPipe()
                                
                                HStack(spacing: 4) {
                                    Text("\(cardCount)").foregroundStyle(.white)
                                    Text("Cards").foregroundStyle(Color.white.opacity(0.4))
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(0.3)
                                
                                statusPipe()
                                
                                HStack(spacing: 4) {
                                    Text("\(loanCount)").foregroundStyle(.white)
                                    Text("Loans").foregroundStyle(Color.white.opacity(0.4))
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
                    .padding(.bottom, 12)

                    // ── Credentials (tap-to-copy) ────
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            copyableCredential(
                                id: institution.id,
                                label: "Login ID",
                                value: institution.username.isEmpty ? (institution.email.isEmpty ? "—" : institution.email) : institution.username,
                                field: "login"
                            )
                            copyableCredential(
                                id: institution.id,
                                label: "Password",
                                value: institution.password,
                                field: "password",
                                isPassword: true
                            )
                        }
                        
                        let loginValue = institution.username.isEmpty ? institution.email : institution.username
                        DynamicLoginLabelView(loginId: loginValue, ignoreInstitutionId: institution.id)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ── Accordion ──────────────────────────────────────────────────
            accordionDivider()
            accordionToggle(label: expanded ? "Hide Accounts" : "Linked Accounts", count: institution.accounts.count + loanCount, expanded: expanded) {
                withAnimation(.spring(response: 0.35)) { expanded.toggle() }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .zIndex(1)
            
            if expanded {
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
                            .background(Color(hex: "#111111"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.05), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(loans) { loan in
                        Button {
                            onEditLoan(loan)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(loan.name.isEmpty ? "Loan" : loan.name)
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
                            .background(Color(hex: "#111111"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.05), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .clipped()
            }
        }
        .background(Color(hex: "#171717"))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.05), lineWidth: 1))
        .sheet(item: $editingAccount) { _ in
            InstitutionAccountHUD(
                draft: $accountDraft,
                isNew: false,
                onSave: {
                    if let idx = institution.accounts.firstIndex(where: { $0.id == accountDraft.id }) {
                        var updated = institution.accounts
                        updated[idx] = accountDraft
                        institution.accounts = updated
                    }
                    editingAccount = nil
                },
                onCancel: { editingAccount = nil },
                onDelete: {
                    if let idx = institution.accounts.firstIndex(where: { $0.id == accountDraft.id }) {
                        let acc = institution.accounts[idx]
                        vm.cleanUpCustomPaymentMethod(name: acc.name.isEmpty ? acc.type : acc.name)
                        institution.accounts.remove(at: idx)
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
                .foregroundStyle(Color.white.opacity(0.4))
        }
    }

    private func statusPipe() -> some View {
        Text("|")
            .font(.system(size: 10))
            .foregroundStyle(Color.white.opacity(0.2))
    }

    private func accordionDivider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.05))
            .frame(height: 1)
    }

    private func accordionToggle(label: String, count: Int? = nil, expanded: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if let count = count, count > 0 {
                    Text("\(label) ")
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(0.2)
                        .foregroundStyle(Color.white.opacity(0.5))
                    + Text("(\(count))")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.2))
                } else {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(0.2)
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .padding(.horizontal, 24)
            .frame(height: 47)
        }
    }

    private func copyableCredential(id: String, label: String, value: String, field: String, isPassword: Bool = false) -> some View {
        let isCopied = copiedField == field
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(isCopied ? "Copied ✓" : label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isCopied ? Color.orange : Color.white.opacity(0.5))
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
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.05), lineWidth: 1))
            }
            .buttonStyle(.plain)
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
                    Text("••\(card.last4)")
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
                        Text(card.expiry.isEmpty ? "—" : card.expiry)
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
            .glassCard(cornerRadius: 18)
        }
        .buttonStyle(.plain)
    }
}

private extension FinancialCard {
    var cardGradientHex: [String] {
        let inst = institutionName.lowercased()
        
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
                        Text(loan.name.isEmpty ? "Loan" : loan.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(loan.lender.isEmpty ? "—" : loan.lender)
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
            .glassCard(cornerRadius: 20)
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

// MARK: - Edit Institution Sheet
struct EditInstitutionSheet: View {
    @Bindable var institution: Institution
    let institutions: [Institution]
    let cards: [FinancialCard]
    let loans: [Loan]
    @Bindable var vm: AppViewModel
    let isNew: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirm = false
    @State private var showPassword = false
    
    struct Snapshot: Equatable {
        var name, loginUrl, username, email, password, twoFactor: String
    }
    @State private var snapshot: Snapshot?

    private var currentSnapshot: Snapshot {
        Snapshot(name: institution.name, loginUrl: institution.loginUrl, username: institution.username, email: institution.email, password: institution.password, twoFactor: institution.twoFactor)
    }

    private var isDirty: Bool {
        guard let snap = snapshot else { return isNew && !institution.name.trimmingCharacters(in: .whitespaces).isEmpty }
        return snap != currentSnapshot
    }

    private var instCards: [FinancialCard] {
        cards.filter { $0.institutionName.lowercased() == institution.name.lowercased() && !institution.name.isEmpty }
    }
    private var instLoans: [Loan] {
        loans.filter { $0.lender.lowercased() == institution.name.lowercased() && !institution.name.isEmpty }
    }

    @State private var showAccountHUD = false
    @State private var accountDraft = InstitutionAccount()
    @State private var accountDraftIndex: Int? = nil

    @State private var showCardHUD = false
    @State private var cardDraft: FinancialCard? = nil

    @State private var showLoanHUD = false
    @State private var loanDraft: Loan? = nil



    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Bank Identity
                Section {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            ZifrField(
                                label: "INSTITUTION",
                                placeholder: "e.g. Chase",
                                text: Binding(get: { institution.name }, set: { institution.name = $0 })
                            )
                            ZifrField(
                                label: "WEBSITE",
                                placeholder: "chase.com",
                                text: Binding(get: { institution.loginUrl }, set: { institution.loginUrl = $0 }),
                                keyboardType: .URL
                            )
                            .textInputAutocapitalization(.never)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                ZifrField(
                                    label: "LOGIN ID",
                                    placeholder: "username",
                                    text: Binding(
                                        get: { institution.username.isEmpty ? institution.email : institution.username },
                                        set: { newValue in
                                            let old = institution.username
                                            institution.username = newValue
                                            if newValue.contains("@") && (institution.email.isEmpty || institution.email == old) {
                                                institution.email = newValue
                                            }
                                        }
                                    ),
                                    keyboardType: .emailAddress
                                )

                                ZStack(alignment: .bottomTrailing) {
                                    ZifrField(
                                        label: "PASSWORD",
                                        placeholder: "••••••••",
                                        text: Binding(get: { institution.password }, set: { institution.password = $0 }),
                                        isSecure: !showPassword
                                    )
                                    .textInputAutocapitalization(.never)

                                    Button {
                                        showPassword.toggle()
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    } label: {
                                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.white.opacity(0.4))
                                            .padding()
                                    }
                                    .padding(.bottom, 2)
                                }
                            }
                            
                            let loginValue = institution.username.isEmpty ? institution.email : institution.username
                            DynamicLoginLabelView(loginId: loginValue, ignoreInstitutionId: institution.id)
                        }
                        
                        HStack(spacing: 12) {
                            ZifrField(
                                label: "EMAIL",
                                placeholder: "name@company.com",
                                text: Binding(get: { institution.email }, set: { institution.email = $0 }),
                                keyboardType: .emailAddress
                            )
                            .textInputAutocapitalization(.never)

                            ZifrField(
                                label: "2FA",
                                placeholder: "Phone or App",
                                text: Binding(get: { institution.twoFactor }, set: { institution.twoFactor = $0 })
                            )
                        }
                    }
                    .padding(.vertical, 4)
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)

                Section {
                    Rectangle()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 1)
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                .listRowSeparator(.hidden)

                // MARK: - Accounts Section
                InstitutionAccountsSection(
                    institution: institution,
                    vm: vm,
                    onAdd: {
                        accountDraft = InstitutionAccount()
                        accountDraftIndex = nil
                        showAccountHUD = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    },
                    onEdit: { idx, acc in
                        accountDraft = acc
                        accountDraftIndex = idx
                        showAccountHUD = true
                    }
                )

                Section {
                    Rectangle()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 1)
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                .listRowSeparator(.hidden)

                // MARK: - Cards Section
                InstitutionCardsSection(
                    cards: instCards,
                    onAdd: {
                        cardDraft = vm.addCard(context: context, companyId: institution.companyId)
                        cardDraft?.institutionName = institution.name 
                        showCardHUD = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    },
                    onEdit: { card in
                        cardDraft = card
                        showCardHUD = true
                    },
                    onDelete: { card in
                        vm.deleteCard(card, context: context)
                    }
                )

                Section {
                    Rectangle()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 1)
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                .listRowSeparator(.hidden)

                // MARK: - Loans Section
                InstitutionLoansSection(
                    loans: instLoans,
                    onAdd: {
                        loanDraft = vm.addLoan(context: context, companyId: institution.companyId)
                        loanDraft?.lender = institution.name 
                        showLoanHUD = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    },
                    onEdit: { loan in
                        loanDraft = loan
                        showLoanHUD = true
                    },
                    onDelete: { loan in
                        vm.deleteLoan(loan, context: context)
                    }
                )

                if !isNew {
                    Section {
                        // Share Institution
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            // Placeholder for CloudKit sharing trigger
                            print("Triggering CloudKit Sharing for \(institution.name)")
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "person.crop.circle.badge.plus")
                                Text("Share Institution")
                                Spacer()
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(hex: "#4f46e5"))
                            .padding(.vertical, 14)
                            .background(Color(hex: "#4f46e5").opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#4f46e5").opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 8)

                        // Delete Institution
                        Button(role: .destructive) {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("Delete \(institution.name.isEmpty ? "Institution" : institution.name)")
                                Spacer()
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.red)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .confirmationDialog(
                            "Delete Bank?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible
                        ) {
                            Button("Delete Bank", role: .destructive) {
                                vm.deleteInstitution(institution, context: context)
                                dismiss()
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 20, trailing: 20))
                    .listRowSeparator(.hidden)
                }

            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#171717"))
            .listSectionSpacing(0)
            .onAppear {
                snapshot = currentSnapshot
            }
            .navigationTitle(institution.name.isEmpty ? "New Bank" : institution.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        
                        if isNew { 
                            vm.deleteInstitution(institution, context: context) 
                        } else if let snap = snapshot {
                            institution.name = snap.name
                            institution.loginUrl = snap.loginUrl
                            institution.username = snap.username
                            institution.email = snap.email
                            institution.password = snap.password
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.saveInstitution(institution, context: context)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(isDirty ? .green : nil)
                }
            }
            .interactiveDismissDisabled(isNew)
            .sheet(isPresented: $showAccountHUD) {
                InstitutionAccountHUD(
                    draft: $accountDraft,
                    isNew: accountDraftIndex == nil,
                    onSave: {
                        var accs = institution.accounts
                        if let idx = accountDraftIndex {
                            accs[idx] = accountDraft
                        } else {
                            accs.append(accountDraft)
                        }
                        institution.accounts = accs
                        showAccountHUD = false
                    },
                    onCancel: { showAccountHUD = false },
                    onDelete: {
                        if let idx = accountDraftIndex {
                            let acc = institution.accounts[idx]
                            vm.cleanUpCustomPaymentMethod(name: acc.name.isEmpty ? acc.type : acc.name)
                            institution.accounts.remove(at: idx)
                        }
                        showAccountHUD = false
                    }
                )
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
            .sheet(item: $cardDraft, onDismiss: { 
                cardDraft = nil 
            }) { cd in
                EditCardSheet(card: cd, vm: vm, institutions: institutions, cards: cards, isNew: cd.name.isEmpty && cd.last4.isEmpty)
            }
            .sheet(item: $loanDraft, onDismiss: { 
                loanDraft = nil 
            }) { ld in
                EditLoanSheet(loan: ld, vm: vm, isNew: ld.name.isEmpty && ld.monthlyPayment == 0, institutions: institutions, cards: cards, isInstitutionContext: true)
            }
        }
    }
}

// MARK: - Institution Accounts Section
struct InstitutionAccountsSection: View {
    @Bindable var institution: Institution
    @Bindable var vm: AppViewModel
    let onAdd: () -> Void
    let onEdit: (Int, InstitutionAccount) -> Void

    var body: some View {
        Section {
            Button { onAdd() } label: {
                HStack {
                        Spacer()
                        Text("🏦  Add Account")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color(hex: "#A2A2A2"))
                        Spacer()
                    }
                    .frame(height: 40)
                    .background(Color(hex: "#222E2F"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                ForEach(institution.accounts.indices, id: \.self) { i in
                    let acc = institution.accounts[i]
                    Button { onEdit(i, acc) } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(acc.type == "Credit Card" ? Color.orange : (acc.type == "Checking" ? Color.white.opacity(0.6) : Color.green))
                                .frame(width: 8, height: 8)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(acc.name.isEmpty ? "Unnamed Account" : acc.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                HStack(spacing: 6) {
                                    Text(acc.type)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                    Text("·").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.2))
                                    Text("••\(acc.last4)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.6))
                                }
                            }
                            Spacer()
                            Text(acc.balance.currencyString)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.2))
                                .padding(.leading, 4)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#111111"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            withAnimation {
                                let acc = institution.accounts[i]
                                vm.cleanUpCustomPaymentMethod(name: acc.name.isEmpty ? acc.type : acc.name)
                                var accs = institution.accounts
                                accs.remove(at: i)
                                institution.accounts = accs
                            }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.red)
                    }
                }
        } header: { EmptyView() }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
        .listRowSeparator(.hidden)
    }
}

// MARK: - Institution Cards Section
struct InstitutionCardsSection: View {
    let cards: [FinancialCard]
    let onAdd: () -> Void
    let onEdit: (FinancialCard) -> Void
    let onDelete: (FinancialCard) -> Void

    var body: some View {
        Section {
            Button { onAdd() } label: {
                HStack {
                        Spacer()
                        Text("💳  Add Card")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color(hex: "#A2A2A2"))
                        Spacer()
                    }
                    .frame(height: 40)
                    .background(Color(hex: "#222E2F"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                ForEach(cards, id: \.id) { card in
                    Button { onEdit(card) } label: {
                        HStack(spacing: 12) {
                            Text("💳").font(.system(size: 18))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(card.name.isEmpty ? "Unnamed Card" : card.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                HStack(spacing: 6) {
                                    Text(card.type)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                    Text("·").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.2))
                                    Text(card.network)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                    Text("·").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.2))
                                    Text("••\(card.last4)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                }
                            }
                            Spacer()
                            Text(card.status.uppercased())
                                .font(.system(size: 9, weight: .black))
                                .tracking(0.5)
                                .foregroundStyle(card.status == "Active" ? Color.green : (card.status == "Frozen" ? Color.orange : Color.red))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background((card.status == "Active" ? Color.green : (card.status == "Frozen" ? Color.orange : Color.red)).opacity(0.12))
                                .clipShape(Capsule())
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.2))
                                .padding(.leading, 4)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#111111"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            withAnimation { onDelete(card) }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.red)
                    }
                }
        } header: { EmptyView() }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
        .listRowSeparator(.hidden)
    }
}

// MARK: - Institution Loans Section
struct InstitutionLoansSection: View {
    let loans: [Loan]
    let onAdd: () -> Void
    let onEdit: (Loan) -> Void
    let onDelete: (Loan) -> Void

    var body: some View {
        Section {
            Button { onAdd() } label: {
                HStack {
                        Spacer()
                        Text("💸  Add Loan")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color(hex: "#A2A2A2"))
                        Spacer()
                    }
                    .frame(height: 40)
                    .background(Color(hex: "#222E2F"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                ForEach(loans, id: \.id) { loan in
                    Button { onEdit(loan) } label: {
                        HStack(spacing: 12) {
                            Text("💸").font(.system(size: 18))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(loan.name.isEmpty ? "Unnamed Loan" : loan.name)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                    Text("|")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.2))
                                    let rateStr = String(format: loan.interestRate.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f", loan.interestRate)
                                    Text("\(rateStr)% APR")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                }
                                let dateRange = loan.maturityDate != nil ? "\(loan.startDate.numericDisplay) → \(loan.maturityDate!.numericDisplay)" : "\(loan.startDate.numericDisplay)"
                                Text(dateRange)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.45))
                            }
                            Spacer()
                            Text(loan.principalAmount.currencyString)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.6))
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.2))
                                .padding(.leading, 4)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#111111"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            withAnimation { onDelete(loan) }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.red)
                    }
                }
        } header: { EmptyView() }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
        .listRowSeparator(.hidden)
    }
}

// MARK: - Institution Account HUD
struct InstitutionAccountHUD: View {
    @Binding var draft: InstitutionAccount
    let isNew: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    var onDelete: (() -> Void)? = nil
    
    @State private var initialDraft: InstitutionAccount? = nil
    
    private var isDirty: Bool {
        guard let initial = initialDraft else { return isNew && !draft.name.isEmpty }
        return draft.name != initial.name ||
               draft.last4 != initial.last4 ||
               draft.type != initial.type ||
               draft.balance != initial.balance
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            ZifrField(
                                label: "ACCOUNT NAME",
                                placeholder: "e.g. Primary Checking",
                                text: $draft.name
                            )
                            ZifrField(
                                label: "LAST 4",
                                placeholder: "****",
                                text: $draft.last4,
                                keyboardType: .numberPad
                            )
                            .onChange(of: draft.last4) { old, new in
                                let filtered = new.filter { $0.isNumber }
                                let truncated = String(filtered.prefix(4))
                                if draft.last4 != truncated { draft.last4 = truncated }
                            }
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("TYPE")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                Picker("", selection: $draft.type) {
                                    ForEach(InstitutionAccount.allTypes, id: \.self) { t in
                                        Text(t).tag(t)
                                    }
                                }
                                .labelsHidden()
                                .padding(.leading, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 44)
                                .background(Color(hex: "#111111"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                .contentShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.borderless)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("BALANCE")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                HStack(spacing: 4) {
                                    Text("$")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                    DoubleField(placeholder: "0.00", value: $draft.balance)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 44)
                                .background(Color(hex: "#111111"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)

                if !isNew {
                    Section {
                        Button(role: .destructive) {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onDelete?()
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("Delete Account")
                                Spacer()
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.red)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 20, trailing: 20))
                    .listRowSeparator(.hidden)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#171717"))
            .listSectionSpacing(0)
            .navigationTitle(isNew ? "Add Account" : "Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                initialDraft = draft
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Save", action: onSave)
                        .fontWeight(.semibold)
                        .tint(isDirty ? .green : nil)
                        .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Loan Payment HUD
struct LoanPaymentHUD: View {
    @Bindable var draft: LoanPayment
    let isNew: Bool
    let institutions: [Institution]
    let cards: [FinancialCard]
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("AMOUNT")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                HStack(spacing: 4) {
                                    Text("$")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                    DoubleField(placeholder: "0.00", value: $draft.amount)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 44)
                                .background(Color(hex: "#111111"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DATE")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                DatePicker("", selection: $draft.date, displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(height: 44)
                                    .padding(.leading, 6)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PAID FROM")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.5))
                            
                            HStack {
                                TextField("e.g. Primary Checking", text: $draft.source)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Spacer(minLength: 8)
                                
                                Menu {
                                    Section("Bank Accounts") {
                                        ForEach(institutions) { inst in
                                            ForEach(inst.accounts) { acc in
                                                let methodString = "\(acc.name) ••••\(acc.last4) (\(inst.name))"
                                                Button(methodString) { draft.source = methodString }
                                            }
                                        }
                                    }
                                    Section("Credit Cards") {
                                        ForEach(cards) { card in
                                            let methodString = "\(card.name) ••••\(card.last4)"
                                            Button(methodString) { draft.source = methodString }
                                        }
                                    }
                                    Section("Other") {
                                        Button("None") { draft.source = "" }
                                    }
                                } label: {
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.3))
                                        .padding(.vertical, 10)
                                        .padding(.leading, 10)
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .background(Color(hex: "#111111"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                    }
                    .padding(.vertical, 4)
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#171717"))
            .listSectionSpacing(0)
            .navigationTitle(isNew ? "Add Payment" : "Edit Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Save", action: onSave)
                        .fontWeight(.semibold)
                        .tint(.green)
                }
            }
        }
    }
}

// MARK: - Edit Card Sheet
struct EditCardSheet: View {
    @Bindable var card: FinancialCard
    @Bindable var vm: AppViewModel
    let institutions: [Institution]
    let cards: [FinancialCard]
    let isNew: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    
    @Query private var subscriptions: [Subscription]
    
    @State private var showFinancials = false
    @State private var showPaymentPicker = false

    private var autoPayBinding: Binding<Bool> {
        Binding(
            get: { card.autopay == "Yes" },
            set: { card.autopay = $0 ? "Yes" : "No" }
        )
    }
    
    private let ordinalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .ordinal
        return f
    }()

    private func ordinal(_ n: Int) -> String {
        ordinalFormatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private var paidOnBinding: Binding<Int> {
        Binding(
            get: { Int(card.paidOn) ?? 1 },
            set: { card.paidOn = "\($0)" }
        )
    }
    
    struct Snapshot: Equatable {
        var name, last4, network, type, autopay, cardHolder, cardHolderType, expiry, notes: String
        var balance, limit, moPayment, apr, promoApr: Double
        var promoEnds: Date
    }
    @State private var snapshot: Snapshot?

    private var currentSnapshot: Snapshot {
        Snapshot(name: card.name, last4: card.last4, network: card.network, type: card.type, autopay: card.autopay, cardHolder: card.cardHolder, cardHolderType: card.cardHolderType, expiry: card.expiry, notes: card.notes, balance: card.balance, limit: card.limit, moPayment: card.moPayment, apr: card.apr, promoApr: card.promoApr, promoEnds: card.promoEnds)
    }

    private var isDirty: Bool {
        guard let snap = snapshot else { return isNew && !card.name.trimmingCharacters(in: .whitespaces).isEmpty }
        return snap != currentSnapshot
    }

    @ViewBuilder private var row1: some View {
        HStack(spacing: 12) {
            ZifrField(label: "CARD NICKNAME", placeholder: "e.g. Sapphire", text: Binding(get: { card.name }, set: { card.name = $0 }))
            ZifrField(label: "NAME ON CARD", placeholder: "Jane Doe", text: Binding(get: { card.cardHolder }, set: { card.cardHolder = $0 }))
        }
    }

    @ViewBuilder private var row2: some View {
        HStack(spacing: 12) {
            ZifrField(label: "LAST 4", placeholder: "****", text: Binding(get: { card.last4 }, set: { card.last4 = $0 }), keyboardType: .numberPad)
                .onChange(of: card.last4) { old, new in
                    let filtered = new.filter { $0.isNumber }
                    let truncated = String(filtered.prefix(4))
                    if card.last4 != truncated { card.last4 = truncated }
                }
            cardPicker(label: "TYPE", sel: Binding(get: { card.type }, set: { card.type = $0 }), opts: FinancialCard.types)
            cardPicker(label: "NETWORK", sel: Binding(get: { card.network }, set: { card.network = $0 }), opts: FinancialCard.networks)
        }
    }

    @ViewBuilder private var row3: some View {
        GeometryReader { geo in
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AUTOPAY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.5))
                    HStack {
                        Text(autoPayBinding.wrappedValue ? "Enabled" : "Disabled")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.white)
                        Spacer()
                        Toggle("", isOn: autoPayBinding)
                            .labelsHidden()
                            .tint(.green)
                            .scaleEffect(0.8)
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(hex: "#111111"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                .frame(width: (geo.size.width - 12) * 0.6)

                VStack(alignment: .leading, spacing: 4) {
                    Text("PAID ON")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.5))
                    Picker("", selection: paidOnBinding) {
                        ForEach(1...31, id: \.self) { day in
                            Text(ordinal(day)).tag(day)
                        }
                    }
                    .labelsHidden()
                    .padding(.leading, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 44)
                    .background(Color(hex: "#111111"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .contentShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.borderless)
                .frame(width: (geo.size.width - 12) * 0.4)
            }
        }
        .frame(height: 64)
    }

    @ViewBuilder private var row4: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PAID FROM")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            
            Button {
                showPaymentPicker = true
            } label: {
                HStack {
                    Text(card.paidFrom.isEmpty ? "None" : card.paidFrom)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(card.paidFrom.isEmpty ? Color.white.opacity(0.4) : .white)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color(hex: "#111111"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder private var row5: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ROLE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.5))
                VStack(spacing: 0) {
                    Spacer()
                    Picker("Role", selection: Binding(get: { card.cardHolderType }, set: { card.cardHolderType = $0 })) {
                        Text("Mine").tag("Mine")
                        Text("Assigned").tag("Assigned")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    Spacer()
                }
                .frame(height: 44)
            }
            
            ZifrField(label: "EXPIRES", placeholder: "MM/YY", text: Binding(get: { card.expiry }, set: { card.expiry = $0 }), keyboardType: .numberPad)
                .onChange(of: card.expiry) { old, new in
                    var filtered = new.filter { $0.isNumber }
                    if old.count == 3 && old.hasSuffix("/") && new.count == 2 {
                        filtered = String(filtered.prefix(1))
                    }
                    if filtered.count > 2 {
                        filtered.insert("/", at: filtered.index(filtered.startIndex, offsetBy: 2))
                    }
                    if filtered.count > 5 {
                        filtered = String(filtered.prefix(5))
                    }
                    if card.expiry != filtered { card.expiry = filtered }
                }
        }
    }

    private var paysForServices: [(name: String, cost: Double)] {
        let cardName = card.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cardName.isEmpty else { return [] }
        var results: [(name: String, cost: Double)] = []
        for sub in subscriptions {
            if sub.paymentMethod.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == cardName {
                results.append((name: sub.name.isEmpty ? "Unnamed Service" : sub.name, cost: sub.cost))
            }
            for subSvc in sub.subServices {
                if subSvc.paymentMethod.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == cardName {
                    results.append((name: subSvc.name.isEmpty ? "Unnamed Sub-service" : subSvc.name, cost: subSvc.cost))
                }
            }
        }
        return results
    }

    @ViewBuilder private var paysForRow: some View {
        let services = paysForServices
        VStack(alignment: .leading, spacing: 12) {
            Text("PAYS FOR")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
                .padding(.leading, 6)
            
            if services.isEmpty {
                Text("No linked services")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(Color(hex: "#111111"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
            } else {
                ForEach(Array(services.enumerated()), id: \.offset) { index, svc in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(svc.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.zifrGreen)
                                    .frame(width: 6, height: 6)
                                
                                Text("|")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.white.opacity(0.2))
                                
                                Text("Paid with \(card.name)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.6))
                            }
                        }
                        Spacer()
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("$\(String(format: "%.0f", svc.cost))")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("/mo")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#111111"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.05), lineWidth: 1))
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        row1
                        row2
                        if card.type.lowercased() != "debit" {
                            row3
                            row4
                        }
                        row5
                        paysForRow
                    }
                    .padding(.vertical, 4)
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)

                // MARK: - Financial Details
                if !showFinancials {
                    Section {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showFinancials = true
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "banknote.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.35))
                                Text("SHOW FINANCIAL DETAILS")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.35))
                                Spacer()
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.25))
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 36)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    } header: { EmptyView() }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                    .listRowSeparator(.hidden)
                }

                if showFinancials {
                    Section {
                        VStack(spacing: 0) {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showFinancials = false
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                HStack {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.07))
                                        .frame(height: 1)
                                    Text("FINANCIALS")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.25))
                                        .fixedSize()
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.2))
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.bottom, 8)

                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    moneyField(label: "BALANCE", value: Binding(get: { card.balance }, set: { card.balance = $0 }))
                                    moneyField(label: "CREDIT LIMIT", value: Binding(get: { card.limit }, set: { card.limit = $0 }))
                                }

                                HStack(spacing: 12) {
                                    moneyField(label: "MO. PAYMENT", value: Binding(get: { card.moPayment }, set: { card.moPayment = $0 }))
                                    Color.clear.frame(maxWidth: .infinity)
                                }

                                if card.type == "Credit" {
                                    HStack(spacing: 12) {
                                        aprField(label: "APR%", value: $card.apr)
                                            .frame(maxWidth: .infinity)
                                            .frame(width: (UIScreen.main.bounds.width - 64) * 0.28)
                                        
                                        aprField(label: "PROMO APR%", value: $card.promoApr)
                                            .frame(maxWidth: .infinity)
                                            .frame(width: (UIScreen.main.bounds.width - 64) * 0.28)
                                        
                                        datePicker(label: "ENDS", selection: $card.promoEnds)
                                    }
                                }
                            }
                        }
                    } header: { EmptyView() }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowSeparator(.hidden)
                }

                // MARK: - Notes
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NOTES")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .padding(.leading, 6)
                        
                        TextField("Add notes...", text: Binding(get: { card.notes }, set: { card.notes = $0 }), axis: .vertical)
                            .lineLimit(3...6)
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Color(hex: "#111111"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)

                if !isNew {
                    Section {
                        // Share Card
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            // Placeholder for CloudKit sharing trigger
                            print("Triggering CloudKit Sharing for \(card.name)")
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "person.crop.circle.badge.plus")
                                Text("Share Card")
                                Spacer()
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(hex: "#4f46e5"))
                            .padding(.vertical, 14)
                            .background(Color(hex: "#4f46e5").opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#4f46e5").opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 8)

                        // Delete Card
                        Button(role: .destructive) {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("Delete \(card.name.isEmpty ? "Card" : card.name)")
                                Spacer()
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.red)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .confirmationDialog("Delete Card?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                            Button("Delete Card", role: .destructive) {
                                vm.deleteCard(card, context: context)
                                dismiss()
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 20, trailing: 20))
                    .listRowSeparator(.hidden)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#171717"))
            .listSectionSpacing(0)
            .onAppear {
                snapshot = currentSnapshot
            }
            .navigationTitle(isNew ? "New Card" : card.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isNew { 
                            vm.deleteCard(card, context: context) 
                        } else if let snap = snapshot {
                            card.name = snap.name
                            card.last4 = snap.last4
                            card.network = snap.network
                            card.type = snap.type
                            card.autopay = snap.autopay
                            card.cardHolder = snap.cardHolder
                            card.cardHolderType = snap.cardHolderType
                            card.expiry = snap.expiry
                            card.notes = snap.notes
                            card.balance = snap.balance
                            card.limit = snap.limit
                            card.moPayment = snap.moPayment
                            card.apr = snap.apr
                            card.promoApr = snap.promoApr
                            card.promoEnds = snap.promoEnds
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.saveCard(card, context: context)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(isDirty ? .green : nil)
                }
            }
            .interactiveDismissDisabled(isNew)
            .sheet(isPresented: $showPaymentPicker) {
                NavigationStack {
                    PaymentMethodPickerView(
                        currentMethod: card.paidFrom,
                        institutions: institutions,
                        cards: cards
                    ) { method in
                        card.paidFrom = method
                    }
                }
            }
        }
    }

    private func datePicker(label: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            
            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 44)
        }
    }

    private func aprField(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            HStack(spacing: 4) {
                DoubleField(placeholder: "0.00", value: value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text("%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 44)
            .background(Color(hex: "#111111"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    private func cardPicker(label: String, sel: Binding<String>, opts: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            Picker("", selection: sel) {
                ForEach(opts, id: \.self) { t in
                    Text(t).tag(t)
                }
            }
            .labelsHidden()
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 44)
            .background(Color(hex: "#111111"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.borderless)
    }

    private func moneyField(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            HStack(spacing: 4) {
                Text("$")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.5))
                DoubleField(placeholder: "0.00", value: value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 44)
            .background(Color(hex: "#111111"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }
}

// MARK: - Edit Loan Sheet
struct EditLoanSheet: View {
    @Bindable var loan: Loan
    @Bindable var vm: AppViewModel
    let isNew: Bool
    let institutions: [Institution]
    let cards: [FinancialCard]
    var isInstitutionContext: Bool = false
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    
    struct Snapshot: Equatable {
        var name, lender, term, role, status, interestType, scheduleFrequency, notes: String
        var principalAmount, remainingBalance, monthlyPayment, interestRate: Double
        var termYears, termMonths: Int
        var startDate: Date
        var maturityDate, paidOffDate: Date?
    }
    @State private var snapshot: Snapshot?
    @State private var showAmortizationTable = false
    @State private var isAutoUpdating = false
    @State private var showTermPicker = false
    @State private var showPaymentHUD = false
    @State private var paymentDraft = LoanPayment()
    @State private var editingPaymentId: String? = nil

    private var currentSnapshot: Snapshot {
        Snapshot(
            name: loan.name,
            lender: loan.lender,
            term: loan.term,
            role: loan.role,
            status: loan.status,
            interestType: loan.interestType,
            scheduleFrequency: loan.scheduleFrequency,
            notes: loan.notes,
            principalAmount: loan.principalAmount,
            remainingBalance: loan.remainingBalance,
            monthlyPayment: loan.monthlyPayment,
            interestRate: loan.interestRate,
            termYears: loan.termYears,
            termMonths: loan.termMonths,
            startDate: loan.startDate,
            maturityDate: loan.maturityDate,
            paidOffDate: loan.paidOffDate
        )
    }

    private var isDirty: Bool {
        guard let snap = snapshot else { return isNew && !loan.name.trimmingCharacters(in: .whitespaces).isEmpty }
        return snap != currentSnapshot
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    loanSummarySection()
                    
                    loanRoleSection()
                    
                    VStack(spacing: 12) {
                        loanPrincipalSection()
                        loanPaymentsLedgerSection()
                    }
                    .padding(.horizontal, 20)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)

                    if !isNew {
                        // Share Loan
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            // Placeholder for CloudKit sharing trigger
                            print("Triggering CloudKit Sharing for \(loan.name)")
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "person.crop.circle.badge.plus")
                                Text("Share Loan")
                                Spacer()
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(hex: "#4f46e5"))
                            .padding(.vertical, 14)
                            .background(Color(hex: "#4f46e5").opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#4f46e5").opacity(0.3), lineWidth: 1))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .buttonStyle(.plain)

                        // Delete Loan
                        Button(role: .destructive) {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("Delete \(loan.name.isEmpty ? "Loan" : loan.name)")
                                Spacer()
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.red)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                        .buttonStyle(.plain)
                        .confirmationDialog("Delete Loan?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                            Button("Delete Loan", role: .destructive) {
                                vm.deleteLoan(loan, context: context)
                                dismiss()
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#171717"))
            .listSectionSpacing(0)
            .onAppear {
                snapshot = currentSnapshot
            }
            .navigationTitle(isNew ? "New Loan" : loan.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isNew { 
                            vm.deleteLoan(loan, context: context) 
                        } else if let snap = snapshot {
                            loan.name = snap.name
                            loan.lender = snap.lender
                            loan.role = snap.role
                            loan.status = snap.status
                            loan.interestType = snap.interestType
                            loan.scheduleFrequency = snap.scheduleFrequency
                            loan.principalAmount = snap.principalAmount
                            loan.remainingBalance = snap.remainingBalance
                            loan.monthlyPayment = snap.monthlyPayment
                            loan.interestRate = snap.interestRate
                            loan.termYears = snap.termYears
                            loan.termMonths = snap.termMonths
                            loan.startDate = snap.startDate
                            loan.maturityDate = snap.maturityDate
                            loan.paidOffDate = snap.paidOffDate
                            loan.notes = snap.notes
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.saveLoan(loan, context: context)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(isDirty ? .green : nil)
                }
            }
            .interactiveDismissDisabled(isNew)
            .sheet(isPresented: $showTermPicker) {
                NavigationStack {
                    HStack(spacing: 0) {
                        Picker("Years", selection: $loan.termYears) {
                            ForEach(0...30, id: \.self) { year in Text("\(year) \(year == 1 ? "Year" : "Years")").tag(year) }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .onChange(of: loan.termYears) { _, _ in updateMaturityDate() }
                        
                        Picker("Months", selection: $loan.termMonths) {
                            ForEach(0...11, id: \.self) { month in Text("\(month) \(month == 1 ? "Month" : "Months")").tag(month) }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .onChange(of: loan.termMonths) { _, _ in updateMaturityDate() }
                    }
                    .navigationTitle("Loan Term")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showTermPicker = false }
                        }
                    }
                }
                .presentationDetents([.height(260)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showPaymentHUD) {
                LoanPaymentHUD(
                    draft: paymentDraft,
                    isNew: editingPaymentId == nil,
                    institutions: institutions,
                    cards: cards,
                    onSave: {
                        if let id = editingPaymentId, let idx = (loan.payments ?? []).firstIndex(where: { $0.id == id }) {
                            loan.payments?[idx].date = paymentDraft.date
                            loan.payments?[idx].amount = paymentDraft.amount
                            loan.payments?[idx].source = paymentDraft.source
                        } else {
                            if loan.payments == nil {
                                loan.payments = []
                            }
                            loan.payments?.append(paymentDraft)
                        }
                        showPaymentHUD = false
                        editingPaymentId = nil
                    },
                    onCancel: {
                        showPaymentHUD = false
                        editingPaymentId = nil
                    }
                )
                .presentationDetents([.height(280)])
            }
        }
    }

    private func loanPicker(label: String, sel: Binding<String>, opts: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            Picker("", selection: sel) {
                ForEach(opts, id: \.self) { t in
                    Text(t).tag(t)
                }
            }
            .labelsHidden()
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 44)
            .background(Color(hex: "#111111"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.borderless)
    }

    private func datePicker(label: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            
            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 44)
        }
    }

    private func aprField(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            HStack(spacing: 4) {
                if loan.interestType == "Fixed" {
                    Text("$")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                DoubleField(placeholder: loan.interestType == "Fixed" ? "0" : "0.00", value: value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                if loan.interestType != "Fixed" {
                    Text("%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 44)
            .background(Color(hex: "#111111"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    private func moneyField(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            HStack(spacing: 4) {
                Text("$")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.5))
                DoubleField(placeholder: "0.00", value: value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 44)
            .background(Color(hex: "#111111"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    @ViewBuilder
    private func loanSummarySection() -> some View {
        let amort = loan.amortization
        VStack(spacing: 20) {
            // Header Stats
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(loan.name.isEmpty ? "Loan" : loan.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text(loan.lender.isEmpty ? "Lender Unknown" : loan.lender)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(loan.principalAmount.currencyString)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(.white)
                    Text("PRINCIPAL")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(Color.white.opacity(0.4))
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
            
            // Stats Grid
            GeometryReader { geo in
                HStack(spacing: 0) {
                    summaryStatColumn(label: "INTEREST", value: amort.totalInterest.currencyString, width: geo.size.width / 3)
                    summaryStatColumn(label: "TOTAL COST", value: amort.totalCost.currencyString, width: geo.size.width / 3)
                    summaryStatColumn(label: "MO. PAYMENT", value: amort.monthlyPayment.currencyString, width: geo.size.width / 3)
                }
            }
            .frame(height: 40)
            
            if !amort.schedule.isEmpty {
                VStack(spacing: 12) {
                    Divider().background(Color.white.opacity(0.05))
                        .padding(.vertical, 4)
                        
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showAmortizationTable.toggle()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text(showAmortizationTable ? "Hide Schedule" : "Amortization Schedule")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.6))
                                .textCase(.uppercase)
                                .tracking(1.5)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.6))
                                .rotationEffect(.degrees(showAmortizationTable ? 180 : 0))
                            Spacer()
                        }
                        .frame(height: 36)
                        .background(Color.white.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    
                    if showAmortizationTable {
                        VStack(spacing: 0) {
                            HStack {
                                Text(loan.scheduleFrequency == "Weekly" ? "WK" : (loan.scheduleFrequency == "Yearly" ? "YR" : "MO"))
                                    .frame(width: 30, alignment: .leading)
                                Text("PMT")
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text("PRIN")
                                    .foregroundStyle(Color.white.opacity(0.5))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text("INT")
                                    .foregroundStyle(Color(hex: "#742C2D"))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text("BAL")
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .textCase(.uppercase)
                            .tracking(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(hex: "#1C1C1E"))
                            
                            Divider().background(Color.white.opacity(0.05))
                            
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(amort.schedule) { row in
                                        HStack {
                                            Text("\(row.month)")
                                                .foregroundStyle(Color.white.opacity(0.5))
                                                .frame(width: 30, alignment: .leading)
                                            Text("$\(Int(round(row.payment)))")
                                                .foregroundStyle(Color.white.opacity(0.9))
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                            Text("$\(Int(round(row.principal)))")
                                                .foregroundStyle(Color.white.opacity(0.7))
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                            Text("$\(Int(round(row.interest)))")
                                                .foregroundStyle(Color(hex: "#742C2D"))
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                            Text("$\(Int(round(row.balance)))")
                                                .foregroundStyle(Color.white)
                                                .fontWeight(.bold)
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                        }
                                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        
                                        if row.month != amort.schedule.last?.month {
                                            Divider().background(Color.white.opacity(0.03))
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 250)
                            .background(Color.black.opacity(0.2))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.03), lineWidth: 1))
                    }
                }
            }
        }
        .padding(24)
        .background(Color(hex: "#111111"))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.05), lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func summaryStatColumn(label: String, value: String, width: CGFloat) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .black))
                .tracking(1)
                .foregroundStyle(Color.white.opacity(0.4))
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: width)
    }

    @ViewBuilder
    private func loanRoleSection() -> some View {
        if !isInstitutionContext {
            Picker("Role", selection: $loan.role) {
                ForEach(Loan.roles, id: \.self) { role in
                    Text(role).tag(role)
                }
            }
            .pickerStyle(.segmented)
            .frame(height: 44)
            .padding(.horizontal, 20)
            .disabled(!isNew)
        }
    }

    @ViewBuilder
    private func loanPrincipalSection() -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZifrField(
                    label: (!isInstitutionContext && loan.role == "I'm Lending") ? "LENT TO" : "LENDER", 
                    placeholder: (!isInstitutionContext && loan.role == "I'm Lending") ? "e.g. Acme Corp" : "e.g. Chase", 
                    text: $loan.lender
                )
                ZifrField(
                    label: (!isInstitutionContext && loan.role == "I'm Lending") ? "LOAN NAME" : "LOAN ID", 
                    placeholder: (!isInstitutionContext && loan.role == "I'm Lending") ? "e.g. Bridge Loan" : "e.g. Series A", 
                    text: $loan.name
                )
            }
            
            GeometryReader { geo in
                HStack(spacing: 12) {
                    moneyField(label: "PRINCIPAL", value: $loan.principalAmount)
                        .frame(width: geo.size.width * 0.5 - 6)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LOAN TERM")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.5))
                        Button {
                            showTermPicker = true
                        } label: {
                            HStack {
                                Text("\(loan.termYears) \(loan.termYears == 1 ? "Yr" : "Yrs"), \(loan.termMonths) \(loan.termMonths == 1 ? "Mo" : "Mos")")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                            }
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 44)
                            .background(Color(hex: "#111111"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                    }
                    .frame(width: geo.size.width * 0.5 - 6)
                }
            }
            .frame(height: 64)
            
            if loan.role == "I'm Lending" {
                HStack(spacing: 12) {
                    loanPicker(label: "INTEREST TYPE", sel: $loan.interestType, opts: Loan.interestTypes)
                }
            }
            
            HStack(spacing: 12) {
                aprField(label: loan.interestType == "Fixed" ? "FIXED FEE" : "YR APR", value: $loan.interestRate)
                loanPicker(label: "PAYMENT FREQUENCY", sel: $loan.scheduleFrequency, opts: Loan.frequencies)
            }
            
            HStack(spacing: 12) {
                datePicker(label: "START DATE", selection: $loan.startDate)
                    .onChange(of: loan.startDate) { _, _ in updateMaturityDate() }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("MATURITY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.5))
                    
                    if let selection = Binding($loan.maturityDate) {
                        DatePicker("", selection: selection, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 44)
                            .onChange(of: loan.maturityDate) { _, _ in updateTerm() }
                    } else {
                        Button {
                            loan.maturityDate = Date()
                        } label: {
                            Text("Set Date")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.zifrGold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 44)
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("LOAN SUMMARY")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .padding(.leading, 6)
                
                TextField("Add notes...", text: Binding(get: { loan.notes }, set: { loan.notes = $0 }), axis: .vertical)
                    .lineLimit(3...6)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Color(hex: "#111111"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }

    @ViewBuilder
    private func paymentRow(index: Int, payment: LoanPayment, cumulativeTotal: Double) -> some View {
        HStack(spacing: 4) {
            Text("\(index)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.3))
                .frame(width: 16, alignment: .leading)
            
            Text(payment.date.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(payment.amount.currencyString)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(payment.source.isEmpty ? "None" : payment.source)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(payment.source.isEmpty ? Color.white.opacity(0.4) : .white)
                .frame(maxWidth: .infinity, alignment: .leading)
                
            Text(cumulativeTotal.currencyString)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(Color.zifrGold)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .modifier(ZifrSwipeActionsModifier(
            onEdit: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                editingPaymentId = payment.id
                paymentDraft = LoanPayment(id: payment.id, date: payment.date, amount: payment.amount, source: payment.source)
                showPaymentHUD = true
            },
            onDelete: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation {
                    loan.payments?.removeAll(where: { $0.id == payment.id })
                }
            }
        ))
    }

    @ViewBuilder
    private func loanPaymentsLedgerSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("PAYMENT LEDGER")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .tracking(1)
            }
            
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Text("#")
                        .frame(width: 16, alignment: .leading)
                    Text("DATE")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("AMOUNT")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("FROM")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("TOTAL")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.4))
                .textCase(.uppercase)
                .tracking(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(hex: "#1C1C1E"))
                
                Divider().background(Color.white.opacity(0.05))
                
                if (loan.payments ?? []).isEmpty {
                    Text("No payments recorded yet.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    let sortedPayments = (loan.payments ?? []).sorted { $0.date < $1.date }
                    ForEach(Array(sortedPayments.enumerated()), id: \.element.id) { index, payment in
                        let cumulativeTotal = sortedPayments[0...index].reduce(0) { $0 + $1.amount }
                        paymentRow(index: index + 1, payment: payment, cumulativeTotal: cumulativeTotal)
                        
                        if payment.id != sortedPayments.last?.id {
                            Divider().background(Color.white.opacity(0.05))
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.03), lineWidth: 1))
            
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                editingPaymentId = nil
                paymentDraft = LoanPayment()
                showPaymentHUD = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                    Text("Add Payment").font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.top, (loan.payments ?? []).isEmpty ? 0 : 4)
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
    
    private func updateMaturityDate() {
        if isAutoUpdating { return }
        var dateComponent = DateComponents()
        dateComponent.year = loan.termYears
        dateComponent.month = loan.termMonths
        if let newDate = Calendar.current.date(byAdding: dateComponent, to: loan.startDate) {
            if let current = loan.maturityDate, Calendar.current.isDate(current, inSameDayAs: newDate) { return }
            isAutoUpdating = true
            loan.maturityDate = newDate
            DispatchQueue.main.async { isAutoUpdating = false }
        }
    }

    private func updateTerm() {
        if isAutoUpdating { return }
        guard let maturity = loan.maturityDate else { return }
        let components = Calendar.current.dateComponents([.year, .month], from: loan.startDate, to: maturity)
        let y = min(max(components.year ?? 0, 0), 30)
        let m = min(max(components.month ?? 0, 0), 11)
        if loan.termYears == y && loan.termMonths == m { return }
        
        isAutoUpdating = true
        loan.termYears = y
        loan.termMonths = m
        DispatchQueue.main.async { isAutoUpdating = false }
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
                .background(Color(hex: "#111111"))
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
                .background(Color(hex: "#111111"))
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
