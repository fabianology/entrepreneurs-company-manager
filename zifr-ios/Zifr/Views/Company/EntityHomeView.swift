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
                        .padding(.top, 6)
                        .padding(.bottom, 8)
                    
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
        .background(Color.clear)
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
                newCard = vm.addCard(appState: appState, userId: company.userId, companyId: company.id)
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
                    let isOrphanedExpanded = expandedInstitutions.contains("orphaned")
                    let orphanedDebt = orphanedCards.reduce(0) { $0 + $1.balance } + orphanedLoans.reduce(0) { $0 + $1.remainingBalance }
                    let orphanedCredit = orphanedCards.reduce(0) { $0 + $1.limit }
                    
                    InstitutionDashboardCard(
                        isExpanded: isOrphanedExpanded,
                        onToggle: {
                            if isOrphanedExpanded { expandedInstitutions.remove("orphaned") }
                            else { expandedInstitutions.insert("orphaned") }
                        },
                        collapsedHeader: {
                            HStack {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8).fill(finColor).frame(width: 32, height: 32)
                                    Image(systemName: "building.columns").font(.system(size: 14)).foregroundStyle(.white)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Other Accounts")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                    Text("\(orphanedCards.count + orphanedLoans.count) Accounts")
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                }
                                .padding(.leading, 8)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Debt")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.4))
                                    Text(formatCurrency(orphanedDebt))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                                Divider().background(Color.white.opacity(0.2)).frame(height: 24).padding(.horizontal, 8)
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Credit")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.4))
                                    Text(formatCurrency(orphanedCredit))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.3))
                                    .rotationEffect(.degrees(isOrphanedExpanded ? 0 : 180))
                                    .padding(.leading, 8)
                            }
                        },
                        accountsContent: {
                            VStack(spacing: 0) {
                                ForEach(Array(orphanedCards.enumerated()), id: \.element.id) { idx, card in
                                    let isAccExpanded = expandedAccounts.contains(card.id.uuidString)
                                    let isLast = idx == orphanedCards.count - 1 && orphanedLoans.isEmpty
                                    AccountNestedRow(
                                        isExpanded: isAccExpanded,
                                        onToggle: {
                                            if isAccExpanded { expandedAccounts.remove(card.id.uuidString) }
                                            else { expandedAccounts.insert(card.id.uuidString) }
                                        },
                                        isLast: isLast,
                                        collapsedHeader: {
                                            HStack {
                                                ZStack {
                                                    Circle().fill(Color.white.opacity(0.1)).frame(width: 32, height: 32)
                                                    Image(systemName: "creditcard.fill").font(.system(size: 14)).foregroundStyle(finColor)
                                                }
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(card.name)
                                                        .font(.system(size: 14, weight: .bold))
                                                        .foregroundStyle(.white)
                                                    Text("•••• \(card.last4 ?? "0000")")
                                                        .font(.system(size: 11, weight: .regular))
                                                        .foregroundStyle(Color.white.opacity(0.5))
                                                }
                                                .padding(.leading, 8)
                                                Spacer()
                                                VStack(alignment: .trailing, spacing: 2) {
                                                    Text("Balance")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundStyle(Color.white.opacity(0.4))
                                                    Text(formatCurrency(card.balance))
                                                        .font(.system(size: 13, weight: .semibold))
                                                        .foregroundStyle(.white)
                                                }
                                                Image(systemName: "chevron.up")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(Color.white.opacity(0.3))
                                                    .rotationEffect(.degrees(isAccExpanded ? 0 : 180))
                                                    .padding(.leading, 8)
                                            }
                                        },
                                        innerRows: {
                                            DashboardInnerRow(icon: nil, label: "Account Type", value: "Credit Card")
                                            DashboardInnerRow(icon: nil, label: "Account Number", value: "•••• \(card.last4 ?? "0000")")
                                            DashboardInnerRow(icon: nil, label: "Available Credit", value: formatCurrency(max(0, card.limit - card.balance)))
                                        },
                                        actionButtons: {
                                            DashboardActionButton(icon: "list.bullet.rectangle", title: "View Details") { vm.activeTab = .financial }
                                        }
                                    )
                                }
                                
                                ForEach(Array(orphanedLoans.enumerated()), id: \.element.id) { idx, loan in
                                    let isAccExpanded = expandedAccounts.contains(loan.id.uuidString)
                                    let isLast = idx == orphanedLoans.count - 1
                                    AccountNestedRow(
                                        isExpanded: isAccExpanded,
                                        onToggle: {
                                            if isAccExpanded { expandedAccounts.remove(loan.id.uuidString) }
                                            else { expandedAccounts.insert(loan.id.uuidString) }
                                        },
                                        isLast: isLast,
                                        collapsedHeader: {
                                            HStack {
                                                ZStack {
                                                    Circle().fill(Color.white.opacity(0.1)).frame(width: 32, height: 32)
                                                    Image(systemName: "doc.text.fill").font(.system(size: 14)).foregroundStyle(finColor)
                                                }
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(loan.name)
                                                        .font(.system(size: 14, weight: .bold))
                                                        .foregroundStyle(.white)
                                                    Text("Loan")
                                                        .font(.system(size: 11, weight: .regular))
                                                        .foregroundStyle(Color.white.opacity(0.5))
                                                }
                                                .padding(.leading, 8)
                                                Spacer()
                                                VStack(alignment: .trailing, spacing: 2) {
                                                    Text("Remaining")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundStyle(Color.white.opacity(0.4))
                                                    Text(formatCurrency(loan.remainingBalance))
                                                        .font(.system(size: 13, weight: .semibold))
                                                        .foregroundStyle(.white)
                                                }
                                                Image(systemName: "chevron.up")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(Color.white.opacity(0.3))
                                                    .rotationEffect(.degrees(isAccExpanded ? 0 : 180))
                                                    .padding(.leading, 8)
                                            }
                                        },
                                        innerRows: {
                                            DashboardInnerRow(icon: nil, label: "Account Type", value: "Bank Loan")
                                            DashboardInnerRow(icon: nil, label: "Interest Rate", value: "\(String(format: "%.1f", loan.interestRate))%")
                                            DashboardInnerRow(icon: nil, label: "Next Payment", value: formatCurrency(loan.monthlyPayment))
                                        },
                                        actionButtons: {
                                            DashboardActionButton(icon: "list.bullet.rectangle", title: "View Details") { vm.activeTab = .financial }
                                        }
                                    )
                                }
                            }
                        }
                    )
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
        
        return InstitutionDashboardCard(
            isExpanded: isExpanded,
            onToggle: {
                if isExpanded { expandedInstitutions.remove(inst.id.uuidString) }
                else { expandedInstitutions.insert(inst.id.uuidString) }
            },
            collapsedHeader: {
                HStack {
                    if !(inst.loginUrl ?? "").isEmpty {
                        FaviconImage(website: inst.loginUrl ?? "", size: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8).fill(finColor).frame(width: 32, height: 32)
                            Image(systemName: "building.columns.fill").font(.system(size: 14)).foregroundStyle(.white)
                        }
                    }
                    Text(inst.name)
                        .font(.system(size: 14, weight: .bold))
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
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .rotationEffect(.degrees(isExpanded ? 0 : 180))
                        .padding(.leading, 8)
                }
            },
            accountsContent: {
                VStack(spacing: 0) {
                    ForEach(Array(inst.accounts.enumerated()), id: \.element.id) { idx, acc in
                        let nameToMatch = acc.name.isEmpty ? acc.type : acc.name
                        let isAccExpanded = expandedAccounts.contains(acc.id)
                        let isLast = idx == inst.accounts.count - 1 && instCards.isEmpty && instLoans.isEmpty
                        AccountNestedRow(
                            isExpanded: isAccExpanded,
                            onToggle: {
                                if isAccExpanded { expandedAccounts.remove(acc.id) }
                                else { expandedAccounts.insert(acc.id) }
                            },
                            isLast: isLast,
                            collapsedHeader: {
                                HStack {
                                    ZStack {
                                        Circle().fill(Color.white.opacity(0.1)).frame(width: 32, height: 32)
                                        Image(systemName: "building.columns.fill").font(.system(size: 14)).foregroundStyle(finColor)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(nameToMatch)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white)
                                        Text("•••• \(acc.last4.isEmpty ? "0000" : acc.last4)")
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundStyle(Color.white.opacity(0.5))
                                    }
                                    .padding(.leading, 8)
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("Balance")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(Color.white.opacity(0.4))
                                        Text(formatCurrency(acc.balance))
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.3))
                                        .rotationEffect(.degrees(isAccExpanded ? 0 : 180))
                                        .padding(.leading, 8)
                                }
                            },
                            innerRows: {
                                DashboardInnerRow(icon: nil, label: "Account Type", value: acc.type)
                                DashboardInnerRow(icon: nil, label: "Account Number", value: "•••• \(acc.last4.isEmpty ? "0000" : acc.last4)")
                            },
                            actionButtons: {
                                DashboardActionButton(icon: "list.bullet.rectangle", title: "View Details") { vm.activeTab = .financial }
                            }
                        )
                    }
                    
                    ForEach(Array(instCards.enumerated()), id: \.element.id) { idx, card in
                        let isAccExpanded = expandedAccounts.contains(card.id.uuidString)
                        let isLast = idx == instCards.count - 1 && instLoans.isEmpty
                        AccountNestedRow(
                            isExpanded: isAccExpanded,
                            onToggle: {
                                if isAccExpanded { expandedAccounts.remove(card.id.uuidString) }
                                else { expandedAccounts.insert(card.id.uuidString) }
                            },
                            isLast: isLast,
                            collapsedHeader: {
                                HStack {
                                    ZStack {
                                        Circle().fill(Color.white.opacity(0.1)).frame(width: 32, height: 32)
                                        Image(systemName: "creditcard.fill").font(.system(size: 14)).foregroundStyle(finColor)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(card.name)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white)
                                        Text("•••• \(card.last4 ?? "0000")")
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundStyle(Color.white.opacity(0.5))
                                    }
                                    .padding(.leading, 8)
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("Balance")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(Color.white.opacity(0.4))
                                        Text(formatCurrency(card.balance))
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.3))
                                        .rotationEffect(.degrees(isAccExpanded ? 0 : 180))
                                        .padding(.leading, 8)
                                }
                            },
                            innerRows: {
                                DashboardInnerRow(icon: nil, label: "Account Type", value: "Credit Card")
                                DashboardInnerRow(icon: nil, label: "Account Number", value: "•••• \(card.last4 ?? "0000")")
                                DashboardInnerRow(icon: nil, label: "Available Credit", value: formatCurrency(max(0, card.limit - card.balance)))
                            },
                            actionButtons: {
                                DashboardActionButton(icon: "list.bullet.rectangle", title: "View Details") { vm.activeTab = .financial }
                            }
                        )
                    }
                    
                    ForEach(Array(instLoans.enumerated()), id: \.element.id) { idx, loan in
                        let isAccExpanded = expandedAccounts.contains(loan.id.uuidString)
                        let isLast = idx == instLoans.count - 1
                        AccountNestedRow(
                            isExpanded: isAccExpanded,
                            onToggle: {
                                if isAccExpanded { expandedAccounts.remove(loan.id.uuidString) }
                                else { expandedAccounts.insert(loan.id.uuidString) }
                            },
                            isLast: isLast,
                            collapsedHeader: {
                                HStack {
                                    ZStack {
                                        Circle().fill(Color.white.opacity(0.1)).frame(width: 32, height: 32)
                                        Image(systemName: "doc.text.fill").font(.system(size: 14)).foregroundStyle(finColor)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(loan.name)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white)
                                        Text("Loan")
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundStyle(Color.white.opacity(0.5))
                                    }
                                    .padding(.leading, 8)
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("Remaining")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(Color.white.opacity(0.4))
                                        Text(formatCurrency(loan.remainingBalance))
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.3))
                                        .rotationEffect(.degrees(isAccExpanded ? 0 : 180))
                                        .padding(.leading, 8)
                                }
                            },
                            innerRows: {
                                DashboardInnerRow(icon: nil, label: "Account Type", value: "Bank Loan")
                                DashboardInnerRow(icon: nil, label: "Interest Rate", value: "\(String(format: "%.1f", loan.interestRate))%")
                                DashboardInnerRow(icon: nil, label: "Next Payment", value: formatCurrency(loan.monthlyPayment))
                            },
                            actionButtons: {
                                DashboardActionButton(icon: "list.bullet.rectangle", title: "View Details") { vm.activeTab = .financial }
                            }
                        )
                    }
                }
            }
        )
        .padding(.horizontal, 20)
        .proContextMenu(password: inst.password, loginId: inst.username ?? inst.email, last4: nil)
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

            VStack(spacing: 12) {
                ForEach(activeSubscriptions) { sub in
                    let isSubExpanded = expandedSubscriptions.contains(sub.id.uuidString)
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
                    
                    ExpandableDashboardCard(
                        isExpanded: isSubExpanded,
                        onToggle: {
                            if isSubExpanded { expandedSubscriptions.remove(sub.id.uuidString) }
                            else { expandedSubscriptions.insert(sub.id.uuidString) }
                        },
                        collapsedHeader: {
                            HStack {
                                if !(sub.website ?? "").isEmpty {
                                    FaviconImage(website: sub.website ?? "", size: 32)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8).fill(brandColor(sub.name).opacity(0.2)).frame(width: 32, height: 32)
                                        Text(sub.name.prefix(1).uppercased()).font(.system(size: 14, weight: .black)).foregroundStyle(brandColor(sub.name))
                                    }
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sub.name)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                    Text(sub.billingCycle)
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                }
                                .padding(.leading, 8)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Cost")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.4))
                                    Text(sub.cost == 0 ? "Free" : formatCurrency(sub.cost))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.3))
                                    .rotationEffect(.degrees(isSubExpanded ? 0 : 180))
                                    .padding(.leading, 8)
                            }
                        },
                        innerRows: {
                            DashboardInnerRow(
                                icon: "calendar",
                                label: "Due Date",
                                value: formattedDueOn(sub)
                            )
                            .padding(.vertical, 4)
                            DashboardInnerRow(
                                icon: "creditcard.fill",
                                label: "Paid From",
                                value: fullPayStr
                            )
                            .padding(.vertical, 4)
                        },
                        actionButtons: {
                            DashboardActionButton(icon: "list.bullet.rectangle", title: "View Details") {
                                vm.activeTab = .subscriptions
                            }
                            Divider().background(Color.white.opacity(0.06))
                            DashboardActionButton(icon: "pencil", title: "Edit") {
                                vm.activeTab = .subscriptions
                            }
                        }
                    )
                    .padding(.horizontal, 20)
                    .proContextMenu(password: sub.password, loginId: sub.loginId, last4: nil)
                }
                }
        }
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
                    
                    ExpandableDashboardCard(
                        isExpanded: isExpanded,
                        onToggle: {
                            if isExpanded { expandedCategories.remove(category) }
                            else { expandedCategories.insert(category) }
                        },
                        collapsedHeader: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(docsColor)
                                Text(category)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(docsInCategory.count) Docs")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.3))
                                    .rotationEffect(.degrees(isExpanded ? 0 : 180))
                                    .padding(.leading, 8)
                            }
                        },
                        innerRows: {
                            ForEach(docsInCategory) { doc in
                                DashboardInnerRow(
                                    icon: "doc.text.fill",
                                    label: doc.name,
                                    value: ""
                                )
                                .padding(.vertical, 4)
                            }
                        },
                        actionButtons: {
                            DashboardActionButton(icon: "list.bullet.rectangle", title: "View Details") {
                                vm.activeTab = .documents
                            }
                            Divider().background(Color.white.opacity(0.06))
                            DashboardActionButton(icon: "plus", title: "Add Document") {
                                newDoc = vm.addDocument(appState: appState, userId: company.userId, companyId: company.id)
                            }
                        }
                    )
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
