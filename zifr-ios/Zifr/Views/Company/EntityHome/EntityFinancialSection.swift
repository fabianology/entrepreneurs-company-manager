import SwiftUI

struct EntityFinancialSection: View {
    let company: Company
    let institutions: [Institution]
    let cards: [FinancialCard]
    let loans: [Loan]
    let subscriptions: [Subscription]
    @Bindable var vm: AppViewModel
    
    @Binding var expandedInstitutions: Set<String>
    @Binding var expandedAccounts: Set<String>
    @Binding var showFinancialReceiptReport: Bool
    @Binding var editingCard: FinancialCard?
    @Binding var editingInst: Institution?
    @Binding var editingLoan: Loan?
    @Binding var viewingTransactionsFor: String?
    
    let totalDebt: Double
    let totalCreditLimit: Double
    let availableCredit: Double
    
    private let finColor = Color(hex: "#1A7077")
    
    @Environment(OnboardingStateManager.self) private var onboardingState
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                vm.activeTab = .financial
            } label: {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "dollarsign.bank.building")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(finColor)
                            .padding(.trailing, 4)
                        
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
                            .foregroundStyle(Color.white)
                            .padding(.leading, 4)
                    }
                    
                    let debtRatio = totalCreditLimit > 0 ? min(1.0, totalDebt / totalCreditLimit) : 0
                    let percentage = totalCreditLimit > 0 ? Int((totalDebt / totalCreditLimit) * 100) : 0
                    HStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.1))
                                Capsule()
                                    .fill(LinearGradient(colors: [finColor, finColor.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
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
                .padding(.top, 16)
                .padding(.bottom, 16)
                .background(Color.black.opacity(0.70))
                .overlay(
                    Rectangle().frame(height: 1).foregroundStyle(Color.white.opacity(0.08)),
                    alignment: .bottom
                )
            }
            .buttonStyle(.plain)
            .spotlightTarget(isActive: onboardingState.isSpotlightingCommandCenterFinancialsHeader)

            VStack(spacing: 16) {
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
                                                Button {
                                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                        vm.activeTab = .financial
                                                    }
                                                } label: {
                                                    ZStack {
                                                        Circle().fill(Color.white.opacity(0.1)).frame(width: 32, height: 32)
                                                        Image(systemName: "creditcard.fill").font(.system(size: 14)).foregroundStyle(finColor)
                                                    }
                                                }
                                                .buttonStyle(.plain)
                                                
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
                                            let fullCardNum = card.cardNumber ?? ""
                                            DashboardInnerRow(
                                                icon: nil,
                                                label: "Card Number",
                                                value: fullCardNum.isEmpty ? "•••• •••• •••• \(card.last4 ?? "0000")" : fullCardNum,
                                                copyValue: fullCardNum.isEmpty ? "411111111111\(card.last4 ?? "0000")" : fullCardNum
                                            )
                                            DashboardInnerRow(icon: nil, label: "Available Credit", value: formatCurrency(max(0, card.limit - card.balance)))
                                        },
                                        actionButtons: {
                                            DashboardActionButton(icon: nil, title: "Details") { editingCard = card }
                                            Divider().background(Color.white.opacity(0.06))
                                            DashboardActionButton(icon: nil, title: "Transactions") { viewingTransactionsFor = card.plaidAccountId ?? card.id.uuidString }
                                            Divider().background(Color.white.opacity(0.06))
                                            DashboardActionButton(icon: nil, title: "Report") {
                                                showFinancialReceiptReport = true
                                            }
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
                                                Button {
                                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                        vm.activeTab = .financial
                                                    }
                                                } label: {
                                                    ZStack {
                                                        Circle().fill(Color.white.opacity(0.1)).frame(width: 32, height: 32)
                                                        Image(systemName: "doc.text.fill").font(.system(size: 14)).foregroundStyle(finColor)
                                                    }
                                                }
                                                .buttonStyle(.plain)
                                                
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
                                            DashboardInnerRow(icon: nil, label: "Interest Rate", value: "\(String(format: "%.1f", loan.interestRate))%")
                                            DashboardInnerRow(icon: nil, label: "Next Payment", value: formatCurrency(loan.monthlyPayment))
                                        },
                                        actionButtons: {
                                            DashboardActionButton(icon: nil, title: "Details") { editingLoan = loan }
                                            Divider().background(Color.white.opacity(0.06))
                                            DashboardActionButton(icon: nil, title: "Transactions") { viewingTransactionsFor = loan.id.uuidString }
                                            Divider().background(Color.white.opacity(0.06))
                                            DashboardActionButton(icon: nil, title: "Report") {
                                                showFinancialReceiptReport = true
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                }
            }
            .spotlightTarget(isActive: onboardingState.isSpotlightingCommandCenterFinancialsAccounts)
            
            financialReportButton
        }
        .padding(.top, 16)
        .padding(.bottom, 16)
        .background(Color(hex: "#1C1C1E").opacity(0.70))
        .frame(maxWidth: .infinity)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .spotlightTarget(isActive: onboardingState.isSpotlightingCommandCenterFinancials)
        .padding(.horizontal, 20)
    }
    
    private var financialReportButton: some View {
        Button {
            showFinancialReceiptReport = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                Text("Generate Report")
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .miloomReportStroke()
        }
        .buttonStyle(PremiumButtonStyle())
        .padding(.horizontal, 16)
        .spotlightTarget(isActive: onboardingState.isSpotlightingCommandCenterFinancialsReport)
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
                                    Button {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        vm.deepLinkModelId = inst.id
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            vm.activeTab = .financial
                                        }
                                    } label: {
                                        ZStack {
                                            Circle().fill(Color.white.opacity(0.1)).frame(width: 32, height: 32)
                                            Image(systemName: "building.columns.fill").font(.system(size: 14)).foregroundStyle(finColor)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    
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
                                let fullAccNum = acc.accountNumber ?? ""
                                let routingNum = acc.routingNumber ?? ""
                                
                                DashboardInnerRow(
                                    icon: nil,
                                    label: "Account Number",
                                    value: fullAccNum.isEmpty ? "•••• •••• \(acc.last4.isEmpty ? "0000" : acc.last4)" : fullAccNum,
                                    copyValue: fullAccNum.isEmpty ? "12345678\(acc.last4.isEmpty ? "0000" : acc.last4)" : fullAccNum
                                )
                                
                                DashboardInnerRow(
                                    icon: nil,
                                    label: "Routing Number",
                                    value: routingNum.isEmpty ? "021000021" : routingNum,
                                    copyValue: routingNum.isEmpty ? "021000021" : routingNum
                                )
                            },
                            actionButtons: {
                                DashboardActionButton(icon: nil, title: "Details") { editingInst = inst }
                                Divider().background(Color.white.opacity(0.06))
                                DashboardActionButton(icon: nil, title: "Transactions") { viewingTransactionsFor = acc.id }
                                Divider().background(Color.white.opacity(0.06))
                                DashboardActionButton(icon: nil, title: "Report") {
                                    showFinancialReceiptReport = true
                                }
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
                                    Button {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        vm.deepLinkModelId = inst.id
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            vm.activeTab = .financial
                                        }
                                    } label: {
                                        ZStack {
                                            Circle().fill(Color.white.opacity(0.1)).frame(width: 32, height: 32)
                                            Image(systemName: "creditcard.fill").font(.system(size: 14)).foregroundStyle(finColor)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(card.name)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white)
                                        Text("•••• \(card.last4 ?? "0000") · \(card.type) Card")
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
                                let fullCardNum = card.cardNumber ?? ""
                                
                                DashboardInnerRow(
                                    icon: nil,
                                    label: "Card Number",
                                    value: fullCardNum.isEmpty ? "•••• •••• •••• \(card.last4 ?? "0000")" : fullCardNum,
                                    copyValue: fullCardNum.isEmpty ? "411111111111\(card.last4 ?? "0000")" : fullCardNum
                                )
                                
                                DashboardInnerRow(icon: nil, label: "Available Credit", value: formatCurrency(max(0, card.limit - card.balance)))
                            },
                            actionButtons: {
                                DashboardActionButton(icon: nil, title: "Details") { editingCard = card }
                                Divider().background(Color.white.opacity(0.06))
                                DashboardActionButton(icon: nil, title: "Transactions") { viewingTransactionsFor = card.plaidAccountId ?? card.id.uuidString }
                                Divider().background(Color.white.opacity(0.06))
                                DashboardActionButton(icon: nil, title: "Report") {
                                    showFinancialReceiptReport = true
                                }
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
                                    Button {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        vm.deepLinkModelId = inst.id
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            vm.activeTab = .financial
                                        }
                                    } label: {
                                        ZStack {
                                            Circle().fill(Color.white.opacity(0.1)).frame(width: 32, height: 32)
                                            Image(systemName: "doc.text.fill").font(.system(size: 14)).foregroundStyle(finColor)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    
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
                                DashboardInnerRow(icon: nil, label: "Interest Rate", value: "\(String(format: "%.1f", loan.interestRate))%")
                                DashboardInnerRow(icon: nil, label: "Next Payment", value: formatCurrency(loan.monthlyPayment))
                            },
                            actionButtons: {
                                DashboardActionButton(icon: nil, title: "Details") { editingLoan = loan }
                                Divider().background(Color.white.opacity(0.06))
                                DashboardActionButton(icon: nil, title: "Transactions") { viewingTransactionsFor = loan.id.uuidString }
                                Divider().background(Color.white.opacity(0.06))
                                DashboardActionButton(icon: nil, title: "Report") {
                                    showFinancialReceiptReport = true
                                }
                            }
                        )
                    }
                }
            }
        )
        .padding(.horizontal, 16)
        .proContextMenu(password: inst.password, loginId: inst.username ?? inst.email, last4: nil)
    }

    private func formatCurrency(_ value: Double) -> String {
        if value == 0 { return "$0" }
        if value >= 1000 { return "$\(String(format: "%.1fk", value / 1000))" }
        return "$\(String(format: "%.0f", value))"
    }
}

struct TransactionFeedView: View {
    let accountId: String
    var cardId: UUID? = nil
    var cardName: String? = nil
    var companyId: UUID? = nil
    @Bindable var vm: AppViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private var resolvedCompanyId: UUID? {
        if let companyId { return companyId }
        if let cardId, let card = appState.cards.first(where: { $0.id == cardId }) {
            return card.companyId
        }
        let target = resolvedAccountId()
        if let card = appState.cards.first(where: { $0.plaidAccountId == target }) {
            return card.companyId
        }
        return appState.companies.first?.id
    }

    @State private var isSyncing = false
    @State private var syncError: String? = nil
    @State private var hasSyncedOnAppear = false

    // Resolve the right Plaid account_id for filtering
    private func resolvedAccountId() -> String {
        let matchingCard = appState.cards.first { $0.id.uuidString == accountId || $0.plaidAccountId == accountId }
        let matchingInstAcc = appState.institutions.flatMap(\.accounts).first { $0.id == accountId }
        if let pId = matchingCard?.plaidAccountId { return pId }
        if let card = matchingCard, let l4 = card.last4, !l4.isEmpty,
           let acc = appState.institutions.flatMap(\.accounts).first(where: { $0.last4 == l4 }) {
            return acc.id
        }
        if let pId = matchingInstAcc?.id { return pId }
        return accountId
    }

    private var filteredTransactions: [Transaction] {
        let target = resolvedAccountId()
        return appState.transactions.filter { tx in
            tx.accountId == target || tx.accountId == accountId
        }.sorted(by: { $0.date > $1.date })
    }

    private var trackedSubscriptionNames: Set<String> {
        Set(appState.subscriptions.map { SubscriptionDetector.normalize($0.name) })
    }

    private func isTrackedSubscription(_ tx: Transaction) -> Bool {
        guard let name = tx.name, !name.isEmpty else { return false }
        let key = SubscriptionDetector.normalize(name)
        return trackedSubscriptionNames.contains(key)
    }

    private var detectedSubscriptions: [DetectedSubscription] {
        let target = resolvedAccountId()
        return SubscriptionDetector.detect(
            transactions: filteredTransactions,
            existingSubscriptions: appState.subscriptions,
            filterAccountId: target
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#141414").ignoresSafeArea()

                if isSyncing && filteredTransactions.isEmpty {
                    // Full-screen loading state on first sync
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#C1AA78")))
                            .scaleEffect(1.5)
                        Text("Syncing transactions...")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Fetching from Plaid. This may take a moment.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else if filteredTransactions.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "list.clipboard")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.white.opacity(0.15))
                        Text("No Transactions Yet")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Tap \"Sync Now\" to pull the latest transactions from Plaid.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        if let err = syncError {
                            Text(err)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.red.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }

                        Button {
                            Task { await syncAndRefresh() }
                        } label: {
                            HStack(spacing: 8) {
                                if isSyncing {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                                Text(isSyncing ? "Syncing..." : "Sync Now")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#C1AA78"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isSyncing)
                    }
                } else {
                    List {
                        // Detected subscriptions banner
                        if !detectedSubscriptions.isEmpty {
                            Section {
                                DetectedSubscriptionsBanner(
                                    detected: detectedSubscriptions,
                                    cardId: cardId,
                                    cardName: cardName,
                                    companyId: resolvedCompanyId,
                                    vm: vm
                                )
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                        
                        ForEach(filteredTransactions) { tx in
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "#1A7077").opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: (tx.pending ?? false) ? "clock.fill" : "dollarsign")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(Color(hex: "#1A7077"))
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(tx.name ?? "Unknown Transaction")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)

                                        if isTrackedSubscription(tx) {
                                            HStack(spacing: 3) {
                                                Image(systemName: "arrow.triangle.2.circlepath")
                                                    .font(.system(size: 9, weight: .bold))
                                                Text("Sub")
                                                    .font(.system(size: 10, weight: .bold))
                                            }
                                            .foregroundStyle(Color(hex: "#2070BD"))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color(hex: "#2070BD").opacity(0.18))
                                            .clipShape(Capsule())
                                            .overlay(Capsule().stroke(Color(hex: "#2070BD").opacity(0.35), lineWidth: 1))
                                        }
                                    }

                                    HStack(spacing: 4) {
                                        Text(formatDate(tx.date))
                                        if let cat = tx.category, !cat.isEmpty {
                                            Text("•")
                                            Text(cat.first ?? "")
                                        }
                                        if tx.pending ?? false {
                                            Text("• Pending")
                                                .foregroundStyle(Color.orange)
                                        }
                                    }
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                }
                                Spacer()

                                Text(formatCurrency(tx.amount ?? 0.0))
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle((tx.amount ?? 0.0) < 0 ? Color(hex: "#30D158") : .white)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(Color.white.opacity(0.08))
                            .padding(.vertical, 2)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .onAppear {
                print("DEBUG TransactionFeedView: appState.transactions.count = \(appState.transactions.count)")
                print("DEBUG resolvedAccountId = \(resolvedAccountId())")
                print("DEBUG filteredTransactions.count = \(filteredTransactions.count)")

                // Auto-sync once on appear if no transactions loaded
                if !hasSyncedOnAppear {
                    hasSyncedOnAppear = true
                    Task { await syncAndRefresh() }
                }
            }
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isSyncing {
                        HStack(spacing: 6) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#C1AA78")))
                                .scaleEffect(0.75)
                            Text("Syncing")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(hex: "#C1AA78"))
                        }
                    } else {
                        Button {
                            Task { await syncAndRefresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color(hex: "#C1AA78"))
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.body.bold())
                        .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.fraction(0.9), .large])
    }

    // MARK: - Sync + Refresh
    @MainActor
    private func syncAndRefresh() async {
        isSyncing = true
        syncError = nil
        do {
            // Call the nightly sync edge function to pull fresh Plaid data
            try await PlaidService.shared.syncSubscriptions()
        } catch {
            // Don't show error if it's just "no Plaid items" — still refresh
            let msg = error.localizedDescription
            if !msg.contains("No active Plaid connection") {
                syncError = msg
            }
        }
        // Always refresh app state after sync attempt
        await DataRepository.shared.fetchAllData(appState: appState)
        isSyncing = false
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: abs(value))) ?? "$0.00"
    }

    private func formatDate(_ dateStr: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        if let d = df.date(from: dateStr) {
            let outDf = DateFormatter()
            outDf.dateStyle = .medium
            return outDf.string(from: d)
        }
        return dateStr
    }
}
