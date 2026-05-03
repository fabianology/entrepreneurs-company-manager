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
    @State private var expandedCategories: Set<String> = []
    
    // Quick Add States
    @State private var newSub: Subscription? = nil
    @State private var newCard: FinancialCard? = nil
    @State private var newDoc: CompanyDocument? = nil

    // MARK: - Computed Metrics (Subscriptions)
    private var activeSubscriptions: [Subscription] { subscriptions.filter { $0.status == "Active" } }
    private var monthlyBurn: Double {
        activeSubscriptions.reduce(0.0) { acc, sub in
            let base = sub.billingCycle == "Monthly" ? sub.cost : sub.cost / 12
            let extras = sub.subServices.filter { $0.status != .paused }.reduce(0.0) { $0 + $1.cost }
            return acc + base + extras
        }
    }
    
    // MARK: - Computed Metrics (Financial)
    private var creditCards: [FinancialCard] { cards.filter { $0.type == "Credit" } }
    private var totalDebt: Double {
        loans.filter { $0.role == "Bank Loan" }.reduce(0) { $0 + $1.remainingBalance }
        + creditCards.reduce(0) { $0 + $1.balance }
    }
    private var totalCreditLimit: Double { creditCards.reduce(0) { $0 + $1.limit } }
    private var totalCreditUsed: Double { creditCards.reduce(0) { $0 + $1.balance } }
    private var availableCredit: Double { max(0, totalCreditLimit - totalCreditUsed) }
    private var creditUtilization: Double {
        guard totalCreditLimit > 0 else { return 0 }
        return totalCreditUsed / totalCreditLimit
    }
    private var expiringPromos: [(String, Int)] {
        let thirtyDays = Date().addingTimeInterval(30 * 24 * 3600)
        return creditCards
            .filter { $0.promoApr == 0 && ($0.promoEnds ?? .distantPast) > Date() && ($0.promoEnds ?? .distantFuture) <= thirtyDays }
            .map { card in
                let days = Calendar.current.dateComponents([.day], from: Date(), to: card.promoEnds ?? Date()).day ?? 0
                return (card.name, days)
            }
    }

    // MARK: - Computed Metrics (Documents)
    private var docCategories: [String] {
        company.structure == "Personal"
        ? CompanyDocument.personalTypes
        : CompanyDocument.businessTypes
    }
    private var coveredCategories: Set<String> { Set(documents.map(\.type)) }
    private var categoryCoverage: Int { coveredCategories.intersection(docCategories).count }

    // MARK: - Alerts
    private var isZeroState: Bool {
        subscriptions.isEmpty && cards.isEmpty && institutions.isEmpty && loans.isEmpty && documents.isEmpty
    }

    private var alerts: [HomeAlert] {
        var result: [HomeAlert] = []

        for (name, days) in expiringPromos {
            result.append(HomeAlert(icon: "exclamationmark.triangle.fill", color: .orange, text: "Promo APR on \(name) expires in \(days) days"))
        }

        if creditUtilization > 0.7 && totalCreditLimit > 0 {
            result.append(HomeAlert(icon: "creditcard.trianglebadge.exclamationmark.fill", color: .orange, text: "Credit utilization at \(Int(creditUtilization * 100))%"))
        }

        let criticalMissing = docCategories.filter { !coveredCategories.contains($0) && $0 != "Other" }
        if !criticalMissing.isEmpty {
            result.append(HomeAlert(icon: "doc.badge.clock.fill", color: Color.white.opacity(0.5), text: "\(criticalMissing.count) document \(criticalMissing.count == 1 ? "category" : "categories") missing"))
        }

        let daysSinceModified = Calendar.current.dateComponents([.day], from: company.lastModified, to: Date()).day ?? 0
        if daysSinceModified > 90 {
            result.append(HomeAlert(icon: "clock.arrow.circlepath", color: Color.white.opacity(0.4), text: "Not updated in \(daysSinceModified) days"))
        }

        return result
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    quickAddRow
                        .padding(.top, 15)
                    
                    if isZeroState {
                        zeroStateBanner
                            .padding(.horizontal, 20)
                    }

                    // FINANCIAL ACCORDION
                    financialSection

                    // SUBSCRIPTIONS (Timeline + Cards)
                    subscriptionSection

                    // DOCUMENTS ACCORDION
                    documentSection
                    
                    Spacer().frame(height: 40)
                }
            }
        }
        .background(Color.black)
        .sheet(item: $newSub) { sub in
            EditSubscriptionSheet(sub: sub, institutions: institutions, cards: cards, vm: vm, isNew: true)
        }
        .sheet(item: $newCard) { c in
            EditCardSheet(card: c, vm: vm, institutions: institutions, cards: cards, isNew: true, customTitle: "Add Account")
        }
        .sheet(item: $newDoc) { doc in
            EditDocumentSheet(doc: doc, vm: vm, isNew: true, companyStructure: company.structure)
        }
    }

    // MARK: - Shared Views
    private var quickAddRow: some View {
        HStack(spacing: 12) {
            quickAddButton(icon: "square.3.layers.3d", title: "Add Service", color: subsColor) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                newSub = vm.addSubscription(appState: appState, userId: company.userId, companyId: company.id)
            }
            quickAddButton(icon: "dollarsign.bank.building", title: "Add Account", color: finColor) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                newCard = vm.addCard(appState: appState, userId: company.userId, companyId: company.id)
            }
            quickAddButton(icon: "doc.text", title: "Add Doc", color: docsColor) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                newDoc = vm.addDocument(appState: appState, userId: company.userId, companyId: company.id)
            }
        }
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
            .padding(.vertical, 14)
            .background(Color(hex: "#111111"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
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


    // MARK: - Financial Section
    private var financialSection: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                vm.activeTab = .financial
            } label: {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "dollarsign.bank.building")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(finColor)
                        Text("FINANCIAL")
                            .font(.system(size: 13, weight: .black))
                            .tracking(1.5)
                            .foregroundStyle(.white)
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Text(formatCurrency(totalDebt)).font(.system(size: 14, weight: .bold)).foregroundStyle(.white) +
                            Text(" debt").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.white.opacity(0.5))
                            
                            Text(formatCurrency(availableCredit)).font(.system(size: 14, weight: .bold)).foregroundStyle(.white) +
                            Text(" avail").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.white.opacity(0.5))
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .padding(.leading, 4)
                    }
                    
                    let debtRatio = totalCreditLimit > 0 ? min(1.0, totalDebt / totalCreditLimit) : 0
                    let percentage = totalCreditLimit > 0 ? Int((totalDebt / totalCreditLimit) * 100) : 0
                    HStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.1))
                                Capsule().fill(finColor)
                                    .frame(width: geo.size.width * CGFloat(debtRatio))
                            }
                        }
                        .frame(height: 4)
                        
                        Text("\(percentage)% DTC")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .buttonStyle(.plain)

            // Institutions
            VStack(spacing: 12) {
                ForEach(institutions) { inst in
                    institutionRow(inst)
                }
                // Orphaned cards
                let orphanedCards = cards.filter { card in !institutions.contains { $0.name.lowercased() == (card.institutionName ?? "").lowercased() } }
                let orphanedLoans = loans.filter { loan in loan.role == "Bank Loan" && !institutions.contains { $0.name.lowercased() == (loan.lender ?? "").lowercased() } }
                
                if !orphanedCards.isEmpty || !orphanedLoans.isEmpty {
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "building.columns")
                                .font(.system(size: 20))
                                .foregroundStyle(finColor)
                                .frame(width: 32)
                            Text("Other Accounts")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(darkSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        
                        VStack(spacing: 0) {
                            ForEach(orphanedCards) { card in
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    vm.activeTab = .financial
                                } label: {
                                    cardRow(card)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                                Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 16)
                            }
                            ForEach(orphanedLoans) { loan in
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    vm.activeTab = .financial
                                } label: {
                                    loanRow(loan)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                                Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
    
    private func institutionRow(_ inst: Institution) -> some View {
        let isExpanded = expandedInstitutions.contains(inst.id.uuidString)
        let instCards = cards.filter { ($0.institutionName ?? "").lowercased() == (inst.name).lowercased() }
        let instLoans = loans.filter { $0.role == "Bank Loan" && ($0.lender ?? "").lowercased() == (inst.name).lowercased() }
        
        let instDebt = instLoans.reduce(0) { $0 + $1.remainingBalance } + instCards.reduce(0) { $0 + $1.balance }
        let instCredit = instCards.reduce(0) { $0 + $1.limit }
        
        return VStack(spacing: 0) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if isExpanded { expandedInstitutions.remove(inst.id.uuidString) }
                else { expandedInstitutions.insert(inst.id.uuidString) }
            } label: {
                HStack {
                    if !(inst.loginUrl ?? "").isEmpty, let url = URL(string: "https://www.google.com/s2/favicons?domain=\(inst.loginUrl ?? "")&sz=128") {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView().frame(width: 32, height: 32)
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill).frame(width: 32, height: 32).clipShape(Circle())
                            case .failure:
                                ZStack {
                                    Circle().fill(finColor).frame(width: 32, height: 32)
                                    Image(systemName: "building.columns.fill").font(.system(size: 14)).foregroundStyle(.white)
                                }
                            @unknown default:
                                ZStack {
                                    Circle().fill(finColor).frame(width: 32, height: 32)
                                    Image(systemName: "building.columns.fill").font(.system(size: 14)).foregroundStyle(.white)
                                }
                            }
                        }
                    } else {
                        ZStack {
                            Circle().fill(finColor).frame(width: 32, height: 32)
                            Image(systemName: "building.columns.fill").font(.system(size: 14)).foregroundStyle(.white)
                        }
                    }
                    Text(inst.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.leading, 4)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Debt")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.4))
                        Text(formatCurrency(instDebt))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Divider().background(Color.white.opacity(0.2)).frame(height: 24).padding(.horizontal, 8)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Credit")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.4))
                        Text(formatCurrency(instCredit))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .padding(.leading, 8)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(darkSurface)
                .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 0 : 14))
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(inst.accounts) { acc in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            vm.activeTab = .financial
                        } label: {
                            accountRow(acc)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 16)
                    }
                    ForEach(instCards) { card in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            vm.activeTab = .financial
                        } label: {
                            cardRow(card)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 16)
                    }
                    ForEach(instLoans) { loan in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            vm.activeTab = .financial
                        } label: {
                            loanRow(loan)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 16)
                    }
                }
                .background(darkSurface)
                .clipShape(RoundedCorner(radius: 14, corners: [.bottomLeft, .bottomRight]))
            }
        }
        .padding(.horizontal, 20)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
    
    private func accountRow(_ acc: InstitutionAccount) -> some View {
        let nameToMatch = acc.name.isEmpty ? acc.type : acc.name
        let paidSubs = subscriptions.filter { $0.paymentMethod == nameToMatch }
        return VStack(spacing: 8) {
            HStack {
                Text(accountEmoji(for: acc.type))
                    .font(.system(size: 14))
                VStack(alignment: .leading, spacing: 2) {
                    Text(nameToMatch)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                    Text("···\(acc.last4.isEmpty ? "0000" : acc.last4)")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                Spacer()
                Text("—")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .padding(.trailing, 24)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(acc.balance))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("available")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .frame(width: 70, alignment: .trailing)
            }
            if !paidSubs.isEmpty {
                HStack(spacing: 4) {
                    Text("Pays for:")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.3))
                    Text(paidSubs.map { $0.name }.joined(separator: ", "))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                }
            }
        }
    }
    
    private func cardRow(_ card: FinancialCard) -> some View {
        let paidSubs = subscriptions.filter { $0.paymentMethod == card.name }
        return VStack(spacing: 8) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.7))
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                    Text("···\(card.last4 ?? "") | \(card.cardHolder ?? "")")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(card.balance))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Balance")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .padding(.trailing, 16)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(card.limit))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("limit")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .frame(width: 70, alignment: .trailing)
            }
            if !paidSubs.isEmpty {
                HStack(spacing: 4) {
                    Text("Pays for:")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.3))
                    Text(paidSubs.map { $0.name }.joined(separator: ", "))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                }
            }
        }
    }
    
    private func loanRow(_ loan: Loan) -> some View {
        let paidSubs = subscriptions.filter { $0.paymentMethod == loan.name }
        return VStack(spacing: 8) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.7))
                VStack(alignment: .leading, spacing: 2) {
                    Text(loan.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                    Text("\(loan.term)")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(loan.remainingBalance))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Remaining")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .padding(.trailing, 16)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(loan.principalAmount))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("principal")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .frame(width: 70, alignment: .trailing)
            }
            if !paidSubs.isEmpty {
                HStack(spacing: 4) {
                    Text("Pays for:")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.3))
                    Text(paidSubs.map { $0.name }.joined(separator: ", "))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                }
            }
        }
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

    // MARK: - Subscription Section
    private var subscriptionSection: some View {
        VStack(spacing: 12) {
            // Header
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                vm.activeTab = .subscriptions
            } label: {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "square.3.layers.3d")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(subsColor)
                        Text("SUBSCRIPTIONS")
                            .font(.system(size: 13, weight: .black))
                            .tracking(1.5)
                            .foregroundStyle(.white)
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Text("\(activeSubscriptions.count)").font(.system(size: 14, weight: .bold)).foregroundStyle(.white) +
                            Text(" active").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.white.opacity(0.5))
                            
                            Text(formatCurrency(monthlyBurn)).font(.system(size: 14, weight: .bold)).foregroundStyle(.white) +
                            Text("/mo").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.white.opacity(0.5))
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .padding(.leading, 4)
                    }
                    
                    let autoRenewCount = activeSubscriptions.filter { $0.isAutoRenew }.count
                    let autoRenewRatio = activeSubscriptions.isEmpty ? 0.0 : Double(autoRenewCount) / Double(activeSubscriptions.count)
                    let autoRenewPct = Int(autoRenewRatio * 100)
                    
                    HStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.1))
                                Capsule().fill(subsColor)
                                    .frame(width: geo.size.width * CGFloat(autoRenewRatio))
                            }
                        }
                        .frame(height: 4)
                        
                        Text("\(autoRenewPct)% Auto-Renew")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .buttonStyle(.plain)

            let chunkedSubs = activeSubscriptions.chunked(into: 4)
            VStack(spacing: 12) {
                ForEach(Array(chunkedSubs.enumerated()), id: \.offset) { index, chunk in
                    MarqueeRow(items: chunk, reverse: index % 2 != 0) { sub in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            vm.activeTab = .subscriptions
                        } label: {
                            subscriptionCard(sub)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    private func subscriptionCard(_ sub: Subscription) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                if !(sub.website ?? "").isEmpty, let url = URL(string: "https://www.google.com/s2/favicons?domain=\(sub.website ?? "")&sz=128") {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView().frame(width: 28, height: 28)
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill).frame(width: 28, height: 28).clipShape(RoundedRectangle(cornerRadius: 6))
                        case .failure:
                            ZStack {
                                RoundedRectangle(cornerRadius: 6).fill(brandColor(sub.name).opacity(0.2)).frame(width: 28, height: 28)
                                Text(sub.name.prefix(1).uppercased()).font(.system(size: 14, weight: .black)).foregroundStyle(brandColor(sub.name))
                            }
                        @unknown default:
                            ZStack {
                                RoundedRectangle(cornerRadius: 6).fill(brandColor(sub.name).opacity(0.2)).frame(width: 28, height: 28)
                                Text(sub.name.prefix(1).uppercased()).font(.system(size: 14, weight: .black)).foregroundStyle(brandColor(sub.name))
                            }
                        }
                    }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6).fill(brandColor(sub.name).opacity(0.2)).frame(width: 28, height: 28)
                        Text(sub.name.prefix(1).uppercased()).font(.system(size: 14, weight: .black)).foregroundStyle(brandColor(sub.name))
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(sub.name)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(sub.cost == 0 ? "Free" : "$\(String(format: "%.0f", sub.cost))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                Spacer(minLength: 0)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 0) {
                    Text("Due: ")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))
                    Text(formattedDueOn(sub))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                }
                
                let payStr = (sub.paymentMethod ?? "").isEmpty ? "None" : (sub.paymentMethod ?? "")
                
                let instName: String = {
                    if let c = cards.first(where: { $0.name == sub.paymentMethod }), !(c.institutionName ?? "").isEmpty {
                        return c.institutionName ?? ""
                    }
                    if let inst = institutions.first(where: { inst in inst.accounts.contains(where: { ($0.name.isEmpty ? $0.type : $0.name) == sub.paymentMethod }) }), !inst.name.isEmpty {
                        return inst.name
                    }
                    return ""
                }()
                
                let fullPayStr = instName.isEmpty ? payStr : "\(instName) \(payStr)"
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Paid From:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))
                    Text(fullPayStr)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(darkSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func formatDue(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df.string(from: date)
    }
    
    private func formattedDueOn(_ sub: Subscription) -> String {
        guard !(sub.nextRenewal ?? "").isEmpty else { return "Unknown" }
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
            if let day = Int(sub.nextRenewal ?? "") { return "\(ordinal(day)) every mo." }
            return (sub.nextRenewal ?? "") + " every mo."
        } else {
            let parts = (sub.nextRenewal ?? "").split(separator: " ")
            if parts.count == 2, let day = Int(parts[1]) {
                return "\(parts[0]) \(ordinal(day)) every yr."
            }
            return (sub.nextRenewal ?? "") + " every yr."
        }
    }
    
    private func brandColor(_ name: String) -> Color {
        let hash = abs(name.unicodeScalars.reduce(0) { ($0 << 5) &+ $0 &+ Int($1.value) })
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.65, brightness: 0.75)
    }

    // MARK: - Documents Section
    private var documentSection: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                vm.activeTab = .documents
            } label: {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "doc.text")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(docsColor)
                        Text("DOCUMENTS")
                            .font(.system(size: 13, weight: .black))
                            .tracking(1.5)
                            .foregroundStyle(.white)
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Text("\(documents.count)").font(.system(size: 14, weight: .bold)).foregroundStyle(.white) +
                            Text(" docs").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.white.opacity(0.5))
                            
                            Text("\(coveredCategories.count)").font(.system(size: 14, weight: .bold)).foregroundStyle(.white) +
                            Text(" categories").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.white.opacity(0.5))
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .padding(.leading, 4)
                    }
                    
                    let completionRatio = docCategories.isEmpty ? 0.0 : Double(coveredCategories.count) / Double(docCategories.count)
                    let completionPct = Int(completionRatio * 100)
                    
                    HStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.1))
                                Capsule().fill(docsColor)
                                    .frame(width: geo.size.width * CGFloat(completionRatio))
                            }
                        }
                        .frame(height: 4)
                        
                        Text("\(completionPct)% Vault Completion")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .buttonStyle(.plain)

            // Categories Accordion
            VStack(spacing: 8) {
                ForEach(docCategories.filter { coveredCategories.contains($0) }, id: \.self) { category in
                    let docsInCategory = documents.filter { $0.type == category }
                    let isExpanded = expandedCategories.contains(category)
                    
                    VStack(spacing: 0) {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if isExpanded { expandedCategories.remove(category) }
                            else { expandedCategories.insert(category) }
                        } label: {
                            HStack {
                                Image(systemName: docsInCategory.isEmpty ? "circle" : "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(docsInCategory.isEmpty ? Color.white.opacity(0.2) : docsColor)
                                Text(category)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("(\(docsInCategory.count))")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.4))
                                Spacer()
                                if !docsInCategory.isEmpty {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.3))
                                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                                }
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .background(darkSurface)
                            .clipShape(RoundedRectangle(cornerRadius: isExpanded && !docsInCategory.isEmpty ? 0 : 12))
                        }
                        .buttonStyle(.plain)
                        .disabled(docsInCategory.isEmpty)
                        
                        if isExpanded && !docsInCategory.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(docsInCategory) { doc in
                                    HStack {
                                        Text(doc.name)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.8))
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 16)
                                }
                            }
                            .background(darkSurface)
                            .clipShape(RoundedCorner(radius: 12, corners: [.bottomLeft, .bottomRight]))
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Helpers
    private func formatCurrency(_ value: Double) -> String {
        if value == 0 { return "$0" }
        if value >= 1000 { return "$\(String(format: "%.1fk", value / 1000))" }
        return "$\(String(format: "%.0f", value))"
    }
}

// MARK: - Alert Model
struct HomeAlert: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let text: String
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
