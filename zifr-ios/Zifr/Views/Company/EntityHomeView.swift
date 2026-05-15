import SwiftUI

struct EntityHomeView: View {
    let company: Company
    let subscriptions: [Subscription]
    let cards: [FinancialCard]
    let institutions: [Institution]
    let loans: [Loan]
    let documents: [CompanyDocument]
    let allCompanies: [Company]
    let allSubscriptions: [Subscription]
    let allCards: [FinancialCard]
    let allLoans: [Loan]
    @Bindable var vm: AppViewModel

    // MARK: - Design Tokens
    private let darkSurface = Color(hex: "#1c1c1e")
    private let dimSurface  = Color(hex: "#141414")
    private let subsColor   = Color(hex: "#2070BD")
    private let finColor    = Color(hex: "#1A7077")
    private let docsColor   = Color(hex: "#918457")
    private let homeColor   = Color.white.opacity(0.85)

    @Environment(AppState.self) private var appState

    @State private var expandedInstitutions: Set<String> = []
    @State private var expandedAccounts: Set<String> = []
    @State private var expandedSubscriptions: Set<String> = []
    @State private var expandedCategories: Set<String> = []
    
    // Quick Add States
    @State private var newSub: Subscription? = nil
    @State private var newCard: FinancialCard? = nil
    @State private var newDoc: CompanyDocument? = nil
    @State private var wizardInstitution: Institution? = nil
    
    // Prototype States
    @State private var sheetSub: Subscription? = nil
    @State private var expandedHeroSubId: UUID? = nil
    @Namespace private var heroAnimation
    
    @State private var flippedHeroIndex: Int? = nil
    @Namespace private var flipAnimation
    @State private var showReceiptReport = false
    @State private var showFinancialReceiptReport = false
    @State private var coverFlowSnappedIndex: Int = 0

    // Edit Item States
    @State private var editingCard: FinancialCard? = nil
    @State private var editingInst: Institution? = nil
    @State private var editingLoan: Loan? = nil
    @State private var editingDoc: CompanyDocument? = nil

    // MARK: - ViewModel
    private var model: EntityHomeViewModel {
        EntityHomeViewModel(company: company, subscriptions: subscriptions, cards: cards, institutions: institutions, loans: loans, documents: documents)
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    quickAddRow
                        .padding(.top, 6)
                        .padding(.bottom, 8)
                    
                    if model.isZeroState {
                        zeroStateBanner
                            .padding(.horizontal, 20)
                    }

                    // FINANCIAL ACCORDION
                    EntityFinancialSection(
                        company: company,
                        institutions: institutions,
                        cards: cards,
                        loans: loans,
                        subscriptions: subscriptions,
                        vm: vm,
                        expandedInstitutions: $expandedInstitutions,
                        expandedAccounts: $expandedAccounts,
                        showFinancialReceiptReport: $showFinancialReceiptReport,
                        editingCard: $editingCard,
                        editingInst: $editingInst,
                        editingLoan: $editingLoan,
                        totalDebt: model.totalDebt,
                        totalCreditLimit: model.totalCreditLimit,
                        availableCredit: model.availableCredit
                    )

                    // SUBSCRIPTIONS (Timeline + Cards)
                    EntitySubscriptionSection(
                        company: company,
                        activeSubscriptions: model.activeSubscriptions,
                        subscriptions: subscriptions,
                        institutions: institutions,
                        cards: cards,
                        monthlyBurn: model.monthlyBurn,
                        vm: vm,
                        flippedHeroIndex: $flippedHeroIndex,
                        showReceiptReport: $showReceiptReport,
                        coverFlowSnappedIndex: $coverFlowSnappedIndex,
                        flipAnimation: flipAnimation
                    )

                    // DOCUMENTS ACCORDION
                    EntityDocumentSection(
                        company: company,
                        documents: documents,
                        vm: vm,
                        expandedCategories: $expandedCategories,
                        newDoc: $newDoc,
                        editingDoc: $editingDoc
                    )
                    
                    Spacer().frame(height: 40)
                }
            }
        }
        .background(Color.clear)
        .sheet(item: $newSub) { sub in
            AddSubscriptionWizard(sub: sub, institutions: institutions, cards: cards, vm: vm)
                .presentationDetents([.fraction(0.9), .large])
        }
        .sheet(item: $newCard) { c in
            EditCardSheet(card: c, vm: vm, institutions: institutions, cards: cards, isNew: true, customTitle: "Add Account")
        }
        .sheet(item: $newDoc) { doc in
            EditDocumentSheet(doc: doc, vm: vm, isNew: true, companyStructure: company.structure)
        }
        .sheet(item: $wizardInstitution) { inst in
            AddFinancialWizard(institution: inst, vm: vm, isCommandCenterContext: true, allInstitutions: institutions)
        }
        .sheet(item: $sheetSub) { sub in
            EditSubscriptionSheet(sub: sub, institutions: institutions, cards: cards, vm: vm, isNew: false, onSave: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    flippedHeroIndex = nil
                }
            })
        }
        .sheet(item: $editingCard) { c in
            EditCardSheet(card: c, vm: vm, institutions: institutions, cards: cards, isNew: false)
        }
        .sheet(item: $editingInst) { i in
            EditInstitutionSheet(institution: i, institutions: institutions, cards: cards, loans: loans, vm: vm, isNew: false)
        }
        .sheet(item: $editingLoan) { l in
            EditLoanSheet(loan: l, vm: vm, isNew: false, institutions: institutions, cards: cards)
        }
        .sheet(item: $editingDoc) { doc in
            EditDocumentSheet(doc: doc, vm: vm, isNew: false, companyStructure: company.structure)
        }
        .sheet(isPresented: $showReceiptReport) {
            SubscriptionReceiptView(
                company: company,
                subscriptions: subscriptions,
                institutions: institutions,
                cards: cards
            )
        }
        .sheet(isPresented: $showFinancialReceiptReport) {
            FinancialReceiptView(
                company: company,
                institutions: institutions,
                cards: cards,
                loans: loans,
                subscriptions: subscriptions
            )
        }
        .overlay {
            if let heroId = expandedHeroSubId, let sub = model.activeSubscriptions.first(where: { $0.id == heroId }) {
                ZStack {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                expandedHeroSubId = nil
                            }
                        }
                    
                    VStack(spacing: 16) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(Color(hue: 0.6, saturation: 0.6, brightness: 0.8).opacity(0.2)).frame(width: 48, height: 48)
                                Text(sub.name.prefix(1).uppercased()).font(.system(size: 20, weight: .black)).foregroundStyle(Color(hue: 0.6, saturation: 0.6, brightness: 0.8))
                                    .matchedGeometryEffect(id: "logo-\(sub.id)", in: heroAnimation)
                            }
                            VStack(alignment: .leading) {
                                Text(sub.name).font(.title2.bold()).foregroundStyle(.white)
                                    .matchedGeometryEffect(id: "title-\(sub.id)", in: heroAnimation)
                                Text("$\(String(format: "%.2f", sub.cost))/mo").font(.subheadline).foregroundStyle(.gray)
                                    .matchedGeometryEffect(id: "cost-\(sub.id)", in: heroAnimation)
                            }
                            Spacer()
                        }
                        
                        Divider().background(Color.white.opacity(0.2))
                        
                        DashboardInnerRow(icon: "calendar", label: "Due Date", value: sub.nextRenewal ?? "—")
                        DashboardInnerRow(icon: "creditcard.fill", label: "Paid From", value: sub.paymentMethod ?? "—")
                        
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                expandedHeroSubId = nil
                            }
                        } label: {
                            Text("Close Details")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(hex: "#2C2C2E"))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(.top, 8)
                    }
                    .padding(20)
                    .background(Color(hex: "#1C1C1E"))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .matchedGeometryEffect(id: "bg-\(sub.id)", in: heroAnimation)
                    .padding(24)
                }
            }
            if let heroIndex = flippedHeroIndex {
                let infiniteSubs = Array(repeating: model.activeSubscriptions, count: 100).flatMap { $0 }
                if heroIndex < infiniteSubs.count {
                    let sub = infiniteSubs[heroIndex]
                    ZStack {
                        Color.black.opacity(0.6)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    flippedHeroIndex = nil
                                }
                            }
                        
                        DemoFlipCardExpanded(
                            sub: sub,
                            index: heroIndex,
                            animation: flipAnimation,
                            flippedHeroIndex: $flippedHeroIndex,
                            totalMonthlyBurn: model.monthlyBurn,
                            institutions: institutions,
                            cards: cards,
                            onEdit: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                sheetSub = sub
                            }
                        )
                    }
                    .zIndex(2)
                }
            }
        }
    }

    // MARK: - Shared Views
    private var quickAddRow: some View {
        HStack(spacing: 0) {
            quickAddButton(icon: "square.3.layers.3d", title: "Add Service", color: subsColor) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                newSub = vm.addSubscription(appState: appState, userId: company.userId, companyId: company.id)
            }
            
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1, height: 24)
            
            quickAddButton(icon: "dollarsign.bank.building", title: "Add Account", color: finColor) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                wizardInstitution = Institution(userId: company.userId, companyId: company.id)
            }
            
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1, height: 24)
            
            quickAddButton(icon: "doc.text", title: "Add Doc", color: docsColor) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                newDoc = vm.addDocument(appState: appState, userId: company.userId, companyId: company.id)
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#1C1C1E").opacity(0.70))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .padding(.horizontal, 20)
    }
    
    private func quickAddButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var zeroStateBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.zifrGreen)
                Text("Command Center Active")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
            }
            Text("Begin adding your entity's services, banks, cards, or documents using the tabs below to populate your dashboards.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.6))
                .lineSpacing(4)
        }
        .padding(16)
        .background(dimSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.zifrGreen.opacity(0.2), lineWidth: 1))
    }
}


// MARK: - Prototypes

struct CoverFlowItem: Equatable {
    let index: Int
    let distance: CGFloat
}

struct CoverFlowCenterPreference: PreferenceKey {
    static var defaultValue: [CoverFlowItem] = []
    static func reduce(value: inout [CoverFlowItem], nextValue: () -> [CoverFlowItem]) {
        value.append(contentsOf: nextValue())
    }
}

struct DemoFlipCard: View {
    let sub: Subscription
    let index: Int
    @Binding var flippedHeroIndex: Int?
    var animation: Namespace.ID
    
    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                if let website = sub.website, !website.isEmpty {
                    FaviconImage(website: website, size: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(getBrandColor(sub.name).opacity(0.2)).frame(width: 40, height: 40)
                        Text(sub.name.prefix(1).uppercased()).font(.system(size: 16, weight: .black)).foregroundStyle(getBrandColor(sub.name))
                    }
                }
                Text(sub.name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if secondaryTotal > 0 {
                    Text("$\(String(format: "%.0f", primaryTotal)) | $\(String(format: "%.0f", secondaryTotal))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: "#C1AA78"))
                } else {
                    Text("$\(String(format: "%.0f", primaryTotal))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: "#C1AA78"))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(12)
            .background(Color(hex: "#1C1C1E"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .matchedGeometryEffect(id: "flipBg-\(index)", in: animation)
        .onTapGesture {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                flippedHeroIndex = index
            }
        }
    }
    
    private func getBrandColor(_ name: String) -> Color {
        let hash = abs(name.unicodeScalars.reduce(0) { ($0 << 5) &+ $0 &+ Int($1.value) })
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.65, brightness: 0.75)
    }
    
    var primaryTotal: Double {
        sub.billingCycle == "Monthly" ? sub.monthlyTotal : sub.yearlyTotal
    }
    var secondaryTotal: Double {
        sub.billingCycle == "Monthly" ? sub.yearlyTotal : sub.monthlyTotal
    }
}

struct DemoFlipCardExpanded: View {
    let sub: Subscription
    let index: Int
    var animation: Namespace.ID
    @Binding var flippedHeroIndex: Int?
    let totalMonthlyBurn: Double
    let institutions: [Institution]
    let cards: [FinancialCard]
    var onEdit: () -> Void
    
    @State private var isFlipped = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Front
                VStack(spacing: 8) {
                    if let website = sub.website, !website.isEmpty {
                        FaviconImage(website: website, size: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(getBrandColor(sub.name).opacity(0.2)).frame(width: 40, height: 40)
                            Text(sub.name.prefix(1).uppercased()).font(.system(size: 16, weight: .black)).foregroundStyle(getBrandColor(sub.name))
                        }
                    }
                    Text(sub.name)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("$\(String(format: "%.0f", sub.cost))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: "#C1AA78"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(12)
                .background(Color(hex: "#1C1C1E"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .opacity(isFlipped ? 0 : 1)
                
                // Back
                VStack(spacing: 0) {
                    // Logo + Name + Cost row
                    HStack(alignment: .top, spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.clear)
                                .frame(width: 48, height: 48)
                            if let website = sub.website, !website.isEmpty {
                                FaviconImage(website: website, size: 32)
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14).fill(getBrandColor(sub.name).opacity(0.2)).frame(width: 48, height: 48)
                                    Text(sub.name.prefix(1).uppercased()).font(.system(size: 20, weight: .black)).foregroundStyle(getBrandColor(sub.name))
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sub.name.isEmpty ? "Service" : sub.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                            
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                (Text(primaryExtraCount > 0 ? "(\(primaryCount)) " : "")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                + Text("$\(String(format: "%.0f", primaryTotal))")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white))
                                Text(primaryLabel)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color(hex: "#C1AA78"))
                                
                                if secondaryTotal > 0 {
                                    Text("•")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.white.opacity(0.3))
                                    (Text(secondaryCount > 0 ? "(\(secondaryCount)) " : "")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                    + Text("$\(String(format: "%.0f", secondaryTotal))")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white))
                                    Text(secondaryLabel)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color(hex: "#C1AA78"))
                                }
                            }
                        }
                        .padding(.top, 6)
                        Spacer(minLength: 0)
                        
                        Button {
                            onEdit()
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.6))
                                .padding(8)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    
                    Rectangle().frame(height: 1).foregroundStyle(Color.white.opacity(0.06))
                        .padding(.horizontal, 20)
                    
                    // Quick Glance Info
                    let bankTuple = getBankAccountTuple()
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            glanceBox(title: "ACTIVE", value: shortDueOn)
                            glanceBox(title: "PAID FROM", value: bankTuple?.bank ?? (sub.paymentMethod?.isEmpty == false ? sub.paymentMethod! : "—"))
                            glanceBox(title: "NEXT DUE", value: sub.nextRenewal?.withOrdinal ?? "—")
                        }
                        HStack(spacing: 12) {
                            glanceBox(title: "AUTO-PAY", value: sub.renew == "Manual" ? "NO" : "YES", highlight: sub.renew != "Manual")
                            glanceBox(title: "SERVICES", value: "\(sub.subServices.count)", highlight: !sub.subServices.isEmpty)
                            glanceBox(title: "EMAILS", value: "\(sub.linkedEmails.count)", highlight: !sub.linkedEmails.isEmpty)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "#1C1C1E"))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
            }
            .matchedGeometryEffect(id: "flipBg-\(index)", in: animation)
            .frame(width: geo.size.width * 0.85, height: 230)
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isFlipped = true
                    }
                }
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isFlipped = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        flippedHeroIndex = nil
                    }
                }
            }
        }
    }
    
    private func glanceBox(title: String, value: String, highlight: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.4))
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(highlight ? Color(hex: "#C1AA78") : .white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(Color(hex: "#2C2C2E"))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Computed Properties for Formatting
    var primaryTotal: Double {
        sub.billingCycle == "Monthly" ? sub.monthlyTotal : sub.yearlyTotal
    }
    var primaryCount: Int {
        let baseCount = sub.cost > 0 ? 1 : 0
        return baseCount + primaryExtraCount
    }
    var primaryExtraCount: Int {
        sub.subServices.filter { $0.status != .paused && $0.billingCycle.rawValue == sub.billingCycle && $0.cost > 0 }.count
    }
    var primaryLabel: String { sub.billingCycle == "Monthly" ? "mo" : "yr" }
    
    var secondaryTotal: Double {
        sub.billingCycle == "Monthly" ? sub.yearlyTotal : sub.monthlyTotal
    }
    var secondaryCount: Int {
        let otherCycle = sub.billingCycle == "Monthly" ? "Yearly" : "Monthly"
        return sub.subServices.filter { $0.status != .paused && $0.billingCycle.rawValue == otherCycle && $0.cost > 0 }.count
    }
    var secondaryLabel: String { sub.billingCycle == "Monthly" ? "yr" : "mo" }
    
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

    private func getBankAccountTuple() -> (bank: String, account: String)? {
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

    private func getBrandColor(_ name: String) -> Color {
        let hash = abs(name.unicodeScalars.reduce(0) { ($0 << 5) &+ $0 &+ Int($1.value) })
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.65, brightness: 0.75)
    }
}

struct DemoHeroCard: View {
    let sub: Subscription
    @Binding var expandedHeroSubId: UUID?
    var animation: Namespace.ID
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color(hue: 0.6, saturation: 0.6, brightness: 0.8).opacity(0.2)).frame(width: 40, height: 40)
                Text(sub.name.prefix(1).uppercased()).font(.system(size: 16, weight: .black)).foregroundStyle(Color(hue: 0.6, saturation: 0.6, brightness: 0.8))
                    .matchedGeometryEffect(id: "logo-\(sub.id)", in: animation)
            }
            Text(sub.name)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .matchedGeometryEffect(id: "title-\(sub.id)", in: animation)
            Text("$\(String(format: "%.0f", sub.cost))")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: "#C1AA78"))
                .matchedGeometryEffect(id: "cost-\(sub.id)", in: animation)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#1C1C1E"))
                .matchedGeometryEffect(id: "bg-\(sub.id)", in: animation)
        )
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .frame(height: 110)
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                expandedHeroSubId = sub.id
            }
        }
    }
}

struct DemoSheetCard: View {
    let sub: Subscription
    @Binding var sheetSub: Subscription?
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color(hue: 0.6, saturation: 0.6, brightness: 0.8).opacity(0.2)).frame(width: 40, height: 40)
                Text(sub.name.prefix(1).uppercased()).font(.system(size: 16, weight: .black)).foregroundStyle(Color(hue: 0.6, saturation: 0.6, brightness: 0.8))
            }
            Text(sub.name)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text("$\(String(format: "%.0f", sub.cost))")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: "#C1AA78"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
        .background(Color(hex: "#1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .frame(height: 110)
        .onTapGesture {
            sheetSub = sub
        }
    }
}



// MARK: - View Extension
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Array Extension for Chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Marquee Row View
struct MarqueeRow<Item: Identifiable & Equatable, Content: View>: View {
    let items: [Item]
    let reverse: Bool
    @ViewBuilder let content: (Item) -> Content
    
    @State private var offset: CGFloat = 0
    @State private var isAnimating = false
    @State private var isKilled = false
    
    var body: some View {
        GeometryReader { geo in
            let totalWidth = CGFloat(items.count) * 156 + CGFloat(max(0, items.count - 1)) * 12
            let maxOffset = max(0, totalWidth - geo.size.width)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        content(item)
                            .frame(width: 156) // Fixed width for marquee predictability
                    }
                }
                .offset(x: isKilled ? 0 : (reverse ? -maxOffset + offset : -offset))
                .animation(.linear(duration: 0.1), value: isKilled)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 15)
                    .onChanged { _ in
                        if !isKilled {
                            isKilled = true
                        }
                    }
            )
            .onAppear {
                startAnimation(maxOffset: maxOffset)
            }
        }
        .frame(height: 120) // Adjusted height to accommodate VStack and prevent clipping
        .clipped()
    }
    
    private func startAnimation(maxOffset: CGFloat) {
        guard !items.isEmpty && !isAnimating && maxOffset > 0 else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.linear(duration: Double(items.count) * 6.0).repeatForever(autoreverses: true)) {
                offset = maxOffset
            }
            isAnimating = true
        }
    }
}

// MARK: - Expandable Cards
struct ExpandableAccountCard: View {
    let acc: InstitutionAccount
    let subscriptions: [Subscription]
    let vm: AppViewModel
    @State private var isExpanded = false
    
    var body: some View {
        let nameToMatch = acc.name.isEmpty ? acc.type : acc.name
        let paidSubs = subscriptions.filter { $0.paymentMethod == nameToMatch }
        
        ExpandableDashboardCard(
            isExpanded: isExpanded,
            onToggle: { isExpanded.toggle() },
            collapsedHeader: {
                HStack {
                    Text(accountEmoji(for: acc.type)).font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(nameToMatch).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                        Text("···\(acc.last4.isEmpty ? "0000" : acc.last4)").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.5))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Balance").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.white.opacity(0.4))
                        Text(formatCurrency(acc.balance)).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                    }
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "#5ED6C1"))
                        .rotationEffect(.degrees(isExpanded ? -90 : 90))
                        .padding(.leading, 8)
                }
            },
            innerRows: {
                DashboardInnerRow(icon: "creditcard", label: "Account Type", value: acc.type)
                DashboardInnerRow(icon: "number", label: "Account Number", value: "···\(acc.last4.isEmpty ? "0000" : acc.last4)")
                if !paidSubs.isEmpty {
                    DashboardInnerRow(icon: "link", label: "Pays for", value: paidSubs.map { $0.name }.joined(separator: ", "))
                }
            },
            actionButtons: {
                DashboardActionButton(icon: "list.bullet.rectangle.portrait", title: "View Details") { vm.activeTab = .financial }
                Divider().background(Color.white.opacity(0.1))
                DashboardActionButton(icon: "pencil", title: "Edit") { vm.activeTab = .financial }
                Divider().background(Color.white.opacity(0.1))
                DashboardActionButton(icon: "arrow.left.arrow.right", title: "Transactions") { vm.activeTab = .financial }
            }
        )
    }
    
    private func accountEmoji(for type: String) -> String {
        switch type {
        case "Checking": return "🏦"
        case "Savings": return "💰"
        case "CD": return "📀"
        case "Investing": return "📈"
        case "401(k)", "Roth 401(k)", "IRA", "Roth IRA", "Rollover IRA", "SEP IRA": return "🪺"
        case "529": return "🎓"
        default: return "📋"
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        if value == 0 { return "$0" }
        if value >= 1000 { return "$\(String(format: "%.1fk", value / 1000))" }
        return "$\(String(format: "%.0f", value))"
    }
}

struct ExpandableCardRow: View {
    let card: FinancialCard
    let subscriptions: [Subscription]
    let vm: AppViewModel
    @State private var isExpanded = false
    
    var body: some View {
        let paidSubs = subscriptions.filter { $0.paymentMethod == card.name }
        
        ExpandableDashboardCard(
            isExpanded: isExpanded,
            onToggle: { isExpanded.toggle() },
            collapsedHeader: {
                HStack {
                    Image(systemName: "creditcard.fill").font(.system(size: 20)).foregroundStyle(Color.white.opacity(0.8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                        Text("···\(card.last4 ?? "")").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.5))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Balance").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.white.opacity(0.4))
                        Text(formatCurrency(card.balance)).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                    }
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "#5ED6C1"))
                        .rotationEffect(.degrees(isExpanded ? -90 : 90))
                        .padding(.leading, 8)
                }
            },
            innerRows: {
                DashboardInnerRow(icon: "creditcard", label: "Card Type", value: card.type)
                DashboardInnerRow(icon: "number", label: "Card Number", value: "···\(card.last4 ?? "")")
                DashboardInnerRow(icon: "dollarsign.circle", label: "Available Credit", value: formatCurrency(max(0, card.limit - card.balance)))
                DashboardInnerRow(icon: "calendar", label: "Statement Date", value: "Unknown")
                if !paidSubs.isEmpty {
                    DashboardInnerRow(icon: "link", label: "Pays for", value: paidSubs.map { $0.name }.joined(separator: ", "))
                }
            },
            actionButtons: {
                DashboardActionButton(icon: "list.bullet.rectangle.portrait", title: "View Details") { vm.activeTab = .financial }
                Divider().background(Color.white.opacity(0.1))
                DashboardActionButton(icon: "pencil", title: "Edit") { vm.activeTab = .financial }
                Divider().background(Color.white.opacity(0.1))
                DashboardActionButton(icon: "arrow.left.arrow.right", title: "Transactions") { vm.activeTab = .financial }
            }
        )
    }
    
    private func formatCurrency(_ value: Double) -> String {
        if value == 0 { return "$0" }
        if value >= 1000 { return "$\(String(format: "%.1fk", value / 1000))" }
        return "$\(String(format: "%.0f", value))"
    }
}

struct ExpandableLoanRow: View {
    let loan: Loan
    let subscriptions: [Subscription]
    let vm: AppViewModel
    @State private var isExpanded = false
    
    var body: some View {
        ExpandableDashboardCard(
            isExpanded: isExpanded,
            onToggle: { isExpanded.toggle() },
            collapsedHeader: {
                HStack {
                    Image(systemName: "doc.text.fill").font(.system(size: 20)).foregroundStyle(Color.white.opacity(0.8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loan.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                        Text("\(loan.term)").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.5))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Remaining").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.white.opacity(0.4))
                        Text(formatCurrency(loan.remainingBalance)).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                    }
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "#5ED6C1"))
                        .rotationEffect(.degrees(isExpanded ? -90 : 90))
                        .padding(.leading, 8)
                }
            },
            innerRows: {
                DashboardInnerRow(icon: "dollarsign.circle", label: "Principal", value: formatCurrency(loan.principalAmount))
                DashboardInnerRow(icon: "calendar", label: "Term", value: loan.term)
            },
            actionButtons: {
                DashboardActionButton(icon: "list.bullet.rectangle.portrait", title: "View Details") { vm.activeTab = .financial }
                Divider().background(Color.white.opacity(0.1))
                DashboardActionButton(icon: "pencil", title: "Edit") { vm.activeTab = .financial }
                Divider().background(Color.white.opacity(0.1))
                DashboardActionButton(icon: "arrow.left.arrow.right", title: "Transactions") { vm.activeTab = .financial }
            }
        )
    }
    
    private func formatCurrency(_ value: Double) -> String {
        if value == 0 { return "$0" }
        if value >= 1000 { return "$\(String(format: "%.1fk", value / 1000))" }
        return "$\(String(format: "%.0f", value))"
    }
}


