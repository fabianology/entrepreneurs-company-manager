import SwiftUI

struct AddFinancialWizard: View {
    @State var institution: Institution
    @State var accounts: [InstitutionAccount] = []
    @State var cards: [FinancialCard] = []
    @State var loans: [Loan] = []
    @Bindable var vm: AppViewModel
    var isCommandCenterContext: Bool = false
    var allInstitutions: [Institution] = []
    
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var currentStep: Int = 1
    @State private var completedSteps: Set<Int> = []
    
    // HUD states
    @State private var showAccountHUD = false
    @State private var accountDraft = InstitutionAccount()
    @State private var accountDraftIndex: Int? = nil
    @State private var isNewAccount = false

    @State private var showCardHUD = false
    @State private var cardDraft = FinancialCard(userId: UUID(), companyId: UUID())
    @State private var cardDraftIndex: Int? = nil
    @State private var isNewCard = false

    @State private var showLoanHUD = false
    @State private var loanDraft = Loan(userId: UUID(), companyId: UUID())
    @State private var loanDraftIndex: Int? = nil
    @State private var isNewLoan = false

    @State private var hasManuallyEditedWebsite = false
    @State private var isNewInstitution: Bool = true
    @State private var linkedPlaidItemId: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#1C1C1E").ignoresSafeArea()
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                
                ScrollView {
                    VStack(spacing: 24) {
                        if !completedSteps.isEmpty {
                            collapsedStepsView
                                .padding(.horizontal, 24)
                        }
                        
                        headerView
                        
                        VStack(spacing: 16) {
                            stepOneInstitution
                            stepTwoAccounts
                            stepThreeCards
                            stepFourLoans
                            
                            if currentStep >= (isCommandCenterContext ? 2 : 5) {
                                if isCommandCenterContext && (!accounts.isEmpty || !cards.isEmpty || !loans.isEmpty) {
                                    VStack(spacing: 8) {
                                        HStack(spacing: 8) {
                                            Text(addedItemsString)
                                                .font(.title2.weight(.semibold))
                                                .foregroundStyle(.white)
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundStyle(Color(hex: "#30D158"))
                                        }
                                        Text("To complete hit save below")
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundStyle(Color.white.opacity(0.65))
                                    }
                                    .padding(.top, 24)
                                    .padding(.bottom, 8)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                                }
                                
                                let canSaveBottom = !isCommandCenterContext || (!accounts.isEmpty || !cards.isEmpty || !loans.isEmpty) || isNewInstitution
                                Button {
                                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                    saveAllAndDismiss()
                                } label: {
                                    Text("Save")
                                        .font(.system(size: 16, weight: .bold))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 54)
                                }
                                .buttonStyle(MiloomPrimaryButtonStyle())
                                .disabled(!canSaveBottom)
                                .padding(.top, 16)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 60)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .onAppear {
                if isCommandCenterContext {
                    isNewInstitution = allInstitutions.isEmpty
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.65))
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    let hasItems = !accounts.isEmpty || !cards.isEmpty || !loans.isEmpty
                    let canSave = completedSteps.contains(1) && (!isCommandCenterContext || hasItems || isNewInstitution)
                    Button("Save") {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        saveAllAndDismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(canSave ? Color(hex: "#30D158") : Color.white.opacity(0.3))
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showAccountHUD) {
                InstitutionAccountHUD(
                    draft: $accountDraft,
                    isNew: isNewAccount,
                    institutionName: institution.name.isEmpty ? "New Institution" : institution.name,
                    onSave: {
                        if let idx = accountDraftIndex {
                            accounts[idx] = accountDraft
                        } else {
                            accounts.append(accountDraft)
                        }
                        showAccountHUD = false
                    },
                    onCancel: { showAccountHUD = false },
                    onDelete: {
                        if let idx = accountDraftIndex {
                            accounts.remove(at: idx)
                        }
                        showAccountHUD = false
                    }
                )
                .presentationDetents([.height(480)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
            .sheet(isPresented: $showCardHUD) {
                FinancialCardHUD(
                    draft: $cardDraft,
                    isNew: isNewCard,
                    institutionName: institution.name.isEmpty ? "New Institution" : institution.name,
                    onSave: {
                        if let idx = cardDraftIndex {
                            cards[idx] = cardDraft
                        } else {
                            cards.append(cardDraft)
                        }
                        showCardHUD = false
                    },
                    onCancel: { showCardHUD = false },
                    onDelete: {
                        if let idx = cardDraftIndex {
                            cards.remove(at: idx)
                        }
                        showCardHUD = false
                    }
                )
                .presentationDetents([.height(720), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
            .sheet(isPresented: $showLoanHUD) {
                LoanHUD(
                    draft: $loanDraft,
                    isNew: isNewLoan,
                    institutionName: institution.name.isEmpty ? "New Institution" : institution.name,
                    onSave: {
                        if let idx = loanDraftIndex {
                            loans[idx] = loanDraft
                        } else {
                            loans.append(loanDraft)
                        }
                        showLoanHUD = false
                    },
                    onCancel: { showLoanHUD = false },
                    onDelete: {
                        if let idx = loanDraftIndex {
                            loans.remove(at: idx)
                        }
                        showLoanHUD = false
                    }
                )
                .presentationDetents([.height(550)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
        }
    }

    // MARK: - Navigation Logic
    private func advanceToStep(_ step: Int) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        completedSteps.insert(currentStep)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            currentStep = step
        }
    }
    
    private func expandStep(_ step: Int) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            currentStep = step
            completedSteps = completedSteps.filter { $0 < step }
        }
    }

    private func saveAllAndDismiss() {
        // Prepare the institution and its accounts
        var instToSave = institution
        instToSave.accountsData.append(contentsOf: accounts)
        
        // Prepare cards and loans with the correct association
        var finalCards = cards
        for i in 0..<finalCards.count {
            finalCards[i].institutionName = instToSave.name
            finalCards[i].companyId = instToSave.companyId
            finalCards[i].userId = instToSave.userId
        }
        
        var finalLoans = loans
        for i in 0..<finalLoans.count {
            finalLoans[i].lender = instToSave.name
            finalLoans[i].companyId = instToSave.companyId
            finalLoans[i].userId = instToSave.userId
        }
        
        // Use VM to persist everything
        vm.saveFinancialInstitutionCascade(institution: instToSave, cards: finalCards, loans: finalLoans, appState: appState)
        
        if let plaidItemId = linkedPlaidItemId {
            Task {
                try? await SupabaseService.shared.client.from("plaid_items")
                    .update(["institution_id": instToSave.id.uuidString])
                    .eq("item_id", value: plaidItemId)
                    .execute()
            }
        }
        
        dismiss()
    }

    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 8) {
            let title: String = {
                if isCommandCenterContext && currentStep >= 2 { return "Add Financial Instruments" }
                switch currentStep {
                case 1: return "Add an Institution"
                case 2: return "Add Bank Accounts"
                case 3: return "Add Credit & Debit Cards"
                case 4: return "Add Loans"
                default: return "\(institution.name.isEmpty ? "Institution" : institution.name) added"
                }
            }()
            let subtitle: String = {
                if isCommandCenterContext && currentStep >= 2 { return "Accounts, Cards, and Loans" }
                switch currentStep {
                case 1: return "Securely store login and high-level details"
                case 2: return "Checking, Savings, and Investing"
                case 3: return "Manage lines of credit and cards"
                case 4: return "Track your liabilities and terms"
                default: return "Financial setup complete"
                }
            }()
            
            HStack(spacing: 8) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .id("headerTitle-\(currentStep)")
                    .transition(.opacity)
                
                if currentStep >= 5 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color(hex: "#30D158"))
                        .transition(.scale.combined(with: .opacity))
                }
            }
                
            Text(subtitle)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.65))
                .id("headerSubtitle-\(currentStep)")
                .transition(.opacity)
                
            HStack(spacing: 8) {
                let maxSteps = isCommandCenterContext ? 2 : 4
                ForEach(1...maxSteps, id: \.self) { step in
                    Capsule()
                        .fill(step <= currentStep ? Color(hex: "#2F5051") : Color.white.opacity(0.1))
                        .frame(width: step == currentStep ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentStep)
                }
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Collapsed Bars
    
    private var addedItemsString: String {
        var addedTypes: [String] = []
        let instName = institution.name.isEmpty ? "Institution" : institution.name
        
        for acc in accounts {
            let t = acc.type.isEmpty ? "Account" : acc.type
            addedTypes.append("\(instName) \(t)")
        }
        for card in cards {
            let t = card.type.isEmpty ? "Card" : card.type
            addedTypes.append("\(instName) \(t)")
        }
        for _ in loans {
            addedTypes.append("\(instName) Loan")
        }
        
        if addedTypes.isEmpty {
            return "\(instName) added"
        }
        
        var uniqueAdded: [String] = []
        for t in addedTypes {
            if !uniqueAdded.contains(t) {
                uniqueAdded.append(t)
            }
        }
        
        if uniqueAdded.count == 1 {
            return "\(uniqueAdded[0]) added"
        } else if uniqueAdded.count == 2 {
            return "\(uniqueAdded[0]) and \(uniqueAdded[1]) added"
        } else {
            let allButLast = uniqueAdded.dropLast().joined(separator: ", ")
            return "\(allButLast), and \(uniqueAdded.last!) added"
        }
    }
    
    @ViewBuilder
    private var collapsedStepsView: some View {
        VStack(spacing: 12) {
            if completedSteps.contains(1) {
                CollapsedSectionBar(
                    icon: "🏦",
                    label: "Institution",
                    summary: "\(institution.name.isEmpty ? "Unnamed" : institution.name) · \(institution.username?.isEmpty == false ? institution.username! : "No ID")",
                    onExpand: { expandStep(1) }
                )
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity.combined(with: .scale(scale: 0.9))))
            }
            if !isCommandCenterContext {
                if completedSteps.contains(2) {
                    CollapsedSectionBar(
                        icon: "💰",
                        label: "Accounts",
                        summary: accounts.isEmpty ? "Skipped" : "\(accounts.count) accounts",
                        onExpand: { expandStep(2) }
                    )
                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity.combined(with: .scale(scale: 0.9))))
                }
                if completedSteps.contains(3) {
                    CollapsedSectionBar(
                        icon: "💳",
                        label: "Cards",
                        summary: cards.isEmpty ? "Skipped" : "\(cards.count) cards",
                        onExpand: { expandStep(3) }
                    )
                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity.combined(with: .scale(scale: 0.9))))
                }
                if completedSteps.contains(4) {
                    CollapsedSectionBar(
                        icon: "📉",
                        label: "Loans",
                        summary: loans.isEmpty ? "Skipped" : "\(loans.count) loans",
                        onExpand: { expandStep(4) }
                    )
                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity.combined(with: .scale(scale: 0.9))))
                }
            }
        }
    }
    
    // MARK: - Steps
    
    @ViewBuilder
    private var stepOneInstitution: some View {
        if currentStep == 1 {
            VStack(spacing: 12) {
                if isCommandCenterContext && !allInstitutions.isEmpty {
                    CustomSegmentedControl(
                        options: ["Select Existing", "Create New"],
                        selection: Binding(
                            get: { isNewInstitution ? "Create New" : "Select Existing" },
                            set: { isNewInstitution = $0 == "Create New" }
                        )
                    )
                    .padding(.bottom, 12)
                }
                
                if !isNewInstitution && isCommandCenterContext && !allInstitutions.isEmpty {
                    Menu {
                        ForEach(allInstitutions) { inst in
                            Button(inst.name.isEmpty ? "Unnamed" : inst.name) {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                institution = inst
                                hasManuallyEditedWebsite = true
                            }
                        }
                    } label: {
                        HStack {
                            Text(institution.name.isEmpty ? "Select Institution..." : institution.name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(institution.name.isEmpty ? Color.white.opacity(0.4) : .white)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                    }
                }
                
                if isNewInstitution || !isCommandCenterContext {
                    PlaidLinkButton(companyId: institution.companyId) { instName, plaidAccounts, plaidItemId in
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        
                        self.linkedPlaidItemId = plaidItemId
                        
                        // Auto-fill institution details
                        let cleanName = instName.lowercased()
                            .replacingOccurrences(of: " ", with: "")
                            .replacingOccurrences(of: ",", with: "")
                            .replacingOccurrences(of: ".", with: "")
                            .replacingOccurrences(of: "&", with: "and")
                        
                        institution.name = instName
                        institution.loginUrl = cleanName.isEmpty ? "" : cleanName + ".com"
                        institution.username = "plaid-connected"
                        institution.password = "••••••••"
                        hasManuallyEditedWebsite = true
                        
                        // Convert Plaid accounts to our domain models
                        for pa in plaidAccounts {
                            let balance = pa.balances.current ?? pa.balances.available ?? 0.0
                            let apr = pa.liability_details?.effectiveAPR ?? 0.0
                            let minPayment = pa.liability_details?.effectiveMinimumPayment ?? 0.0
                            
                            let nextPaymentDateStr = pa.liability_details?.next_payment_due_date
                            var nextDate: Date? = nil
                            if let ds = nextPaymentDateStr {
                                let df = DateFormatter()
                                df.dateFormat = "yyyy-MM-dd"
                                nextDate = df.date(from: ds)
                            }
                            
                            if pa.type == "credit" {
                                var newCard = FinancialCard(userId: institution.userId, companyId: institution.companyId)
                                newCard.name = pa.name
                                newCard.type = "Credit"
                                newCard.last4 = String(pa.account_id.suffix(4))
                                newCard.balance = balance
                                newCard.apr = apr
                                newCard.moPayment = minPayment
                                newCard.institutionName = instName
                                cards.append(newCard)
                            } else if pa.type == "loan" {
                                var newLoan = Loan(userId: institution.userId, companyId: institution.companyId)
                                newLoan.name = pa.name
                                newLoan.lender = instName
                                newLoan.remainingBalance = balance
                                newLoan.interestRate = apr
                                newLoan.monthlyPayment = minPayment
                                loans.append(newLoan)
                            } else {
                                let newAcc = InstitutionAccount(
                                    name: pa.name,
                                    type: (pa.subtype ?? pa.type).capitalized,
                                    last4: String(pa.account_id.suffix(4)),
                                    balance: balance
                                )
                                accounts.append(newAcc)
                            }
                        }
                        
                        // Skip to step 2 automatically
                        advanceToStep(2)
                    }
                    .padding(.bottom, 16)
                    
                    HStack {
                        Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                        Text("OR ENTER MANUALLY").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.white.opacity(0.4))
                        Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                    }
                    .padding(.bottom, 16)
                    
                    HStack(spacing: 12) {
                        ZifrField(label: "INSTITUTION NAME", placeholder: "e.g. Chase Bank", text: Binding(get: {
                            institution.name
                        }, set: { newName in
                            institution.name = newName
                            if !hasManuallyEditedWebsite {
                                let cleanName = newName.lowercased().replacingOccurrences(of: " ", with: "")
                                institution.loginUrl = cleanName.isEmpty ? "" : cleanName + ".com"
                            }
                        }))
                        ZifrField(
                            label: "WEBSITE URL",
                            placeholder: "e.g. chase.com",
                            text: Binding(get: {
                                institution.loginUrl ?? ""
                            }, set: { newUrl in
                                institution.loginUrl = newUrl
                                hasManuallyEditedWebsite = true
                            }),
                            keyboardType: .URL
                        )
                    }
                    
                    HStack(spacing: 12) {
                        ZifrAutocompleteField(
                            label: "LOGIN ID",
                            placeholder: "email or username",
                            text: Binding(get: { institution.username ?? "" }, set: { institution.username = $0 }),
                            keyboardType: .emailAddress,
                            textContentType: .username,
                            suggestions: Array(Set(appState.institutions.compactMap(\.username))).sorted()
                        )
                        ZifrField(
                            label: "PASSWORD",
                            placeholder: "••••••••",
                            text: Binding(get: { institution.password ?? "" }, set: { institution.password = $0 }),
                            isSecure: true,
                            textContentType: .password
                        )
                    }
                    
                    DynamicLoginLabelView(loginId: institution.username ?? "", ignoreSubscriptionId: "")
                        .padding(.top, 4)
                        .padding(.bottom, 12)
                    
                    PremiumInputField(
                        label: "TWO FACTOR / NOTES",
                        placeholder: "e.g. 2FA is set to 123-456-7890",
                        text: Binding(get: { institution.twoFactor ?? "" }, set: { institution.twoFactor = $0 })
                    )
                }
                
                nextButton(disabled: institution.name.isEmpty) { advanceToStep(2) }
            }
            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity.combined(with: .scale(scale: 0.9))))
        }
    }
    
    @ViewBuilder
    private var stepTwoAccounts: some View {
        if currentStep == 2 {
            VStack(spacing: 12) {
                Button {
                    accountDraft = InstitutionAccount()
                    accountDraftIndex = nil
                    isNewAccount = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showAccountHUD = true
                } label: {
                    VStack(spacing: 3) {
                        Text("ADD ACCOUNT")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("checking · savings · investing · 401(k) · more")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                }
                .buttonStyle(MiloomSecondaryButtonStyle())
                
                ForEach(accounts.indices, id: \.self) { i in
                    let acc = accounts[i]
                    Button {
                        accountDraft = acc
                        accountDraftIndex = i
                        isNewAccount = false
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showAccountHUD = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(acc.name.isEmpty ? "Unnamed" : acc.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("••••\(acc.last4)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.6))
                            }
                            Spacer()
                            Text("$\(String(format: "%.2f", acc.balance))")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Color(hex: "#111111"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.05), lineWidth: 1))
                    }
                }
                
                if !isCommandCenterContext {
                    if !accounts.isEmpty {
                        nextButton(disabled: false) { advanceToStep(3) }
                    } else {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            advanceToStep(3)
                        } label: {
                            Text("Skip")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.4))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                    }
                }
            }
            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity.combined(with: .scale(scale: 0.9))))
        }
    }
    
    @ViewBuilder
    private var stepThreeCards: some View {
        if currentStep == 3 || (isCommandCenterContext && currentStep == 2) {
            VStack(spacing: 12) {
                Button {
                    cardDraft = FinancialCard(userId: institution.userId, companyId: institution.companyId)
                    cardDraftIndex = nil
                    isNewCard = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showCardHUD = true
                } label: {
                    VStack(spacing: 3) {
                        Text("ADD CARD")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("credit card · debit card")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                }
                .buttonStyle(MiloomSecondaryButtonStyle())
                
                ForEach(cards.indices, id: \.self) { i in
                    let card = cards[i]
                    Button {
                        cardDraft = card
                        cardDraftIndex = i
                        isNewCard = false
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showCardHUD = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.name.isEmpty ? "Unnamed" : card.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("\(card.network) ••••\(card.last4 ?? "N/A")")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.6))
                            }
                            Spacer()
                            Text("$\(String(format: "%.2f", card.balance))")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Color(hex: "#111111"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.05), lineWidth: 1))
                    }
                }
                
                if !isCommandCenterContext {
                    if !cards.isEmpty {
                        nextButton(disabled: false) { advanceToStep(4) }
                    } else {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            advanceToStep(4)
                        } label: {
                            Text("Skip")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.4))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                    }
                }
            }
            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity.combined(with: .scale(scale: 0.9))))
        }
    }
    
    @ViewBuilder
    private var stepFourLoans: some View {
        if currentStep == 4 || (isCommandCenterContext && currentStep == 2) {
            VStack(spacing: 12) {
                Button {
                    loanDraft = Loan(userId: institution.userId, companyId: institution.companyId)
                    loanDraftIndex = nil
                    isNewLoan = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showLoanHUD = true
                } label: {
                    VStack(spacing: 3) {
                        Text("ADD LOAN")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("lending out · bank loan · custom loan")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                }
                .buttonStyle(MiloomSecondaryButtonStyle())
                
                ForEach(loans.indices, id: \.self) { i in
                    let loan = loans[i]
                    Button {
                        loanDraft = loan
                        loanDraftIndex = i
                        isNewLoan = false
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showLoanHUD = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(loan.name.isEmpty ? "Unnamed" : loan.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("\(loan.termYears)Y \(loan.termMonths)M @ \(String(format: "%.2f", loan.interestRate))%")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.6))
                            }
                            Spacer()
                            Text("$\(String(format: "%.0f", loan.principalAmount))")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Color(hex: "#111111"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.05), lineWidth: 1))
                    }
                }
                
                if !isCommandCenterContext {
                    if !loans.isEmpty {
                        nextButton(disabled: false) { advanceToStep(5) }
                    } else {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            advanceToStep(5)
                        } label: {
                            Text("Skip")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.4))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                    }
                }
            }
            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity.combined(with: .scale(scale: 0.9))))
        }
    }
    
    // MARK: - Helpers
    private func nextButton(disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Next")
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
        }
        .disabled(disabled)
        .buttonStyle(MiloomPrimaryButtonStyle())
        .padding(.top, 8)
    }
}
