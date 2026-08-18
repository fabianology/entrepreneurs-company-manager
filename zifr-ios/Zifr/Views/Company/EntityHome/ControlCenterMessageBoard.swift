import SwiftUI

struct InsightItem: Identifiable, Equatable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let text: String
    let badge: String?
}

struct ControlCenterMessageBoard: View {
    let activeTab: EntityHomeTab
    let company: Company
    let cards: [FinancialCard]
    let institutions: [Institution]
    let loans: [Loan]
    let subscriptions: [Subscription]
    let documents: [CompanyDocument]
    
    @State private var currentIndex: Int = 0
    @State private var timer: Timer? = nil
    
    private var currentInsights: [InsightItem] {
        switch activeTab {
        case .financial:
            return generateFinancialInsights()
        case .subscriptions:
            return generateSubscriptionInsights()
        case .documents:
            return generateDocumentInsights()
        }
    }
    
    var body: some View {
        let insights = currentInsights
        let safeIndex = insights.isEmpty ? 0 : (currentIndex % insights.count)
        
        Group {
            if !insights.isEmpty {
                let currentItem = insights[safeIndex]
                
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    advanceInsight(insightsCount: insights.count)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: currentItem.icon)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(currentItem.iconColor)
                            .frame(width: 13, height: 13)
                        
                        Text(currentItem.text)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.85))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        Spacer(minLength: 4)
                        
                        if let badge = currentItem.badge {
                            Text(badge.uppercased())
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(currentItem.iconColor)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(currentItem.iconColor.opacity(0.18))
                                )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.35))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                    .id("\(activeTab.rawValue)-\(currentItem.id)")
                    .transition(
                        .asymmetric(
                            insertion: .push(from: .bottom).combined(with: .opacity),
                            removal: .push(from: .top).combined(with: .opacity)
                        )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 26)
        .clipped()
        .onChange(of: activeTab) { _, _ in
            currentIndex = 0
            restartTimer()
        }
        .onAppear {
            restartTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func advanceInsight(insightsCount: Int) {
        guard insightsCount > 0 else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
            currentIndex = (currentIndex + 1) % insightsCount
        }
        restartTimer()
    }
    
    private func restartTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 4.5, repeats: true) { _ in
            let count = currentInsights.count
            guard count > 1 else { return }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                currentIndex = (currentIndex + 1) % count
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Financial Insights Generator (Top 3)
    private func generateFinancialInsights() -> [InsightItem] {
        var list: [InsightItem] = []
        
        // 1. 0% APR Promo Expiring soon
        let now = Date()
        for card in cards where card.type == "Credit" && card.promoApr == 0 {
            if let promoEnd = card.promoEnds {
                let days = Calendar.current.dateComponents([.day], from: now, to: promoEnd).day ?? 0
                if days >= 0 && days <= 90 {
                    let balText = card.balance > 0 ? " ($\(String(format: "%.0f", card.balance)) bal)" : ""
                    list.append(
                        InsightItem(
                            icon: "bolt.fill",
                            iconColor: Color(hex: "#EBC351"),
                            text: "\(card.name): 0% APR ends in \(days)d\(balText)",
                            badge: "0% APR"
                        )
                    )
                }
            }
        }
        
        // 2. High utilization (> 75%)
        for card in cards where card.type == "Credit" && card.limit > 0 {
            let ratio = card.balance / card.limit
            if ratio >= 0.75 {
                list.append(
                    InsightItem(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: Color(hex: "#F87171"),
                        text: "\(card.name): \(Int(ratio * 100))% limit used ($\(String(format: "%.0f", card.balance))/$\(String(format: "%.0f", card.limit)))",
                        badge: "High Util"
                    )
                )
            }
        }
        
        // 3. Autopay Off with active balance
        for card in cards where card.autopay == "No" && card.balance > 0 {
            list.append(
                InsightItem(
                    icon: "creditcard.fill",
                    iconColor: Color(hex: "#F59E0B"),
                    text: "\(card.name): Manual payment required (Autopay OFF)",
                    badge: "Pay Due"
                )
            )
        }
        
        // 4. Active Loans with monthly payment
        for loan in loans where loan.status == "Active" && loan.remainingBalance > 0 && loan.monthlyPayment > 0 {
            list.append(
                InsightItem(
                    icon: "dollarsign.bank.building",
                    iconColor: Color(hex: "#1A7077"),
                    text: "\(loan.name): $\(String(format: "%.0f", loan.monthlyPayment))/mo (bal: $\(String(format: "%.0f", loan.remainingBalance)))",
                    badge: "Loan"
                )
            )
        }
        
        // Fallbacks to guarantee 3 items
        let creditCards = cards.filter { $0.type == "Credit" }
        let totalCredit = creditCards.reduce(0.0) { $0 + $1.limit }
        let totalUsed = creditCards.reduce(0.0) { $0 + $1.balance }
        let availCredit = max(0, totalCredit - totalUsed)
        
        list.append(
            InsightItem(
                icon: "checkmark.shield.fill",
                iconColor: Color(hex: "#10B981"),
                text: "Available Credit: $\(String(format: "%.0f", availCredit)) across \(creditCards.count) cards",
                badge: nil
            )
        )
        
        let totalDebt = loans.filter { $0.role == "Bank Loan" }.reduce(0.0) { $0 + $1.remainingBalance } + totalUsed
        list.append(
            InsightItem(
                icon: "chart.line.uptrend.xyaxis",
                iconColor: Color(hex: "#1A7077"),
                text: "Total Debt: $\(String(format: "%.0f", totalDebt)) across all liabilities",
                badge: nil
            )
        )
        
        list.append(
            InsightItem(
                icon: "building.columns.fill",
                iconColor: Color(hex: "#60A5FA"),
                text: "\(institutions.count) Financial Institutions linked & active",
                badge: nil
            )
        )
        
        return Array(list.prefix(3))
    }
    
    // MARK: - Subscription Insights Generator (Top 3)
    private func generateSubscriptionInsights() -> [InsightItem] {
        var list: [InsightItem] = []
        let activeSubs = subscriptions.filter { $0.status == "Active" }
        
        // 1. Manual Renewal Required
        for sub in activeSubs where sub.renew == "Manual" {
            list.append(
                InsightItem(
                    icon: "clock.badge.exclamationmark.fill",
                    iconColor: Color(hex: "#F59E0B"),
                    text: "\(sub.name): Manual renewal required ($\(String(format: "%.0f", sub.cost))/\(sub.billingCycle.prefix(2).lowercased()))",
                    badge: "Manual"
                )
            )
        }
        
        // 2. Top Expense Driver
        if let topSub = activeSubs.max(by: { $0.monthlyTotal < $1.monthlyTotal }), topSub.monthlyTotal > 0 {
            let totalMonthly = activeSubs.reduce(0.0) { $0 + $1.monthlyTotal }
            let pct = totalMonthly > 0 ? Int((topSub.monthlyTotal / totalMonthly) * 100) : 0
            list.append(
                InsightItem(
                    icon: "flame.fill",
                    iconColor: Color(hex: "#EF4444"),
                    text: "Top expense: \(topSub.name) ($\(String(format: "%.0f", topSub.monthlyTotal))/mo · \(pct)% of burn)",
                    badge: "Top Cost"
                )
            )
        }
        
        // 3. Next Upcoming Renewal
        for sub in activeSubs where sub.nextRenewal != nil && !sub.nextRenewal!.isEmpty {
            list.append(
                InsightItem(
                    icon: "calendar.badge.clock",
                    iconColor: Color(hex: "#3B82F6"),
                    text: "\(sub.name) renews on \(sub.nextRenewal!)",
                    badge: "Renews"
                )
            )
        }
        
        // Fallbacks to guarantee 3 items
        let monthlyBurn = activeSubs.reduce(0.0) { $0 + $1.monthlyTotal }
        let annualBurn = activeSubs.reduce(0.0) { $0 + $1.estimatedAnnualCost }
        
        list.append(
            InsightItem(
                icon: "arrow.triangle.2.circlepath",
                iconColor: Color(hex: "#2070BD"),
                text: "Projected annual burn: $\(String(format: "%.0f", annualBurn))/yr ($\(String(format: "%.0f", monthlyBurn))/mo)",
                badge: nil
            )
        )
        
        list.append(
            InsightItem(
                icon: "square.3.layers.3d",
                iconColor: Color(hex: "#10B981"),
                text: "\(activeSubs.count) active recurring services monitored",
                badge: nil
            )
        )
        
        let subToolsCount = activeSubs.reduce(0) { $0 + $1.subServices.count }
        list.append(
            InsightItem(
                icon: "link",
                iconColor: Color(hex: "#A855F7"),
                text: "\(subToolsCount) supplemental add-ons and sub-services active",
                badge: nil
            )
        )
        
        return Array(list.prefix(3))
    }
    
    // MARK: - Document Insights Generator (Top 3)
    private func generateDocumentInsights() -> [InsightItem] {
        var list: [InsightItem] = []
        let normalizedTypes = Set(documents.map { CompanyDocument.normalizeType($0.type) })
        
        // 1. Missing Corporate Gaps
        if !normalizedTypes.contains("Legal") {
            list.append(
                InsightItem(
                    icon: "exclamationmark.circle.fill",
                    iconColor: Color(hex: "#F59E0B"),
                    text: "No Formation or Legal filings stored in Vault",
                    badge: "Missing"
                )
            )
        }
        
        if !normalizedTypes.contains("Taxes") {
            list.append(
                InsightItem(
                    icon: "doc.text.fill",
                    iconColor: Color(hex: "#60A5FA"),
                    text: "No Tax or EIN records uploaded yet",
                    badge: "Missing"
                )
            )
        }
        
        // 2. Uncategorized Files
        let otherCount = documents.filter { CompanyDocument.normalizeType($0.type) == "Other" }.count
        if otherCount > 0 {
            list.append(
                InsightItem(
                    icon: "tray.full.fill",
                    iconColor: Color(hex: "#A855F7"),
                    text: "\(otherCount) file(s) in Vault need category assignment",
                    badge: "Organize"
                )
            )
        }
        
        // 3. Vault Breakdown
        let legalCount = documents.filter { CompanyDocument.normalizeType($0.type) == "Legal" }.count
        let taxCount = documents.filter { CompanyDocument.normalizeType($0.type) == "Taxes" }.count
        let recCount = documents.filter { CompanyDocument.normalizeType($0.type) == "Receipts" }.count
        
        list.append(
            InsightItem(
                icon: "folder.badge.gearshape",
                iconColor: Color(hex: "#C1AA78"),
                text: "Vault summary: \(legalCount) Legal · \(taxCount) Tax · \(recCount) Receipts",
                badge: "Files"
            )
        )
        
        // Fallbacks
        list.append(
            InsightItem(
                icon: "lock.shield.fill",
                iconColor: Color(hex: "#10B981"),
                text: "\(documents.count) encrypted documents safely secured in Vault",
                badge: nil
            )
        )
        
        list.append(
            InsightItem(
                icon: "checkmark.seal.fill",
                iconColor: Color(hex: "#918457"),
                text: "Company document vault in compliance",
                badge: nil
            )
        )
        
        return Array(list.prefix(3))
    }
}
