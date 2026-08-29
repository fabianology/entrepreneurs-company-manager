import SwiftUI

struct AddSubscriptionWizard: View {
    @State var sub: Subscription
    let institutions: [Institution]
    let cards: [FinancialCard]
    @Bindable var vm: AppViewModel
    
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var currentStep: Int = 1
    @State private var completedSteps: Set<Int> = []
    
    // HUD states
    @State private var showSubServiceHUD = false
    @State private var subDraft = SubService()
    @State private var subDraftID: String? = nil
    @State private var isNewSubService = false

    @State private var showEmailHUD = false
    @State private var emailDraft = LinkedEmail()
    @State private var emailDraftIndex: Int? = nil
    @State private var isNewEmail = false
    @State private var hasSkippedEmail = false
    @State private var hasManuallyEditedWebsite = false

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
                            stepOneLogin
                            stepTwoBilling
                            stepThreeSupplemental
                            stepFourEmails
                            
                            if currentStep >= 4 {
                                let canSubmit = !sub.name.isEmpty && (!sub.linkedEmails.isEmpty || hasSkippedEmail)
                                Button {
                                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                    vm.saveSub(sub, appState: appState)
                                    dismiss()
                                } label: {
                                    Text("Done")
                                        .font(.system(size: 16, weight: .bold))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 54)
                                }
                                .disabled(!canSubmit)
                                .buttonStyle(MiloomPrimaryButtonStyle())
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
                    let canSave = completedSteps.contains(1)
                    Button("Save") {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        vm.saveSub(sub, appState: appState)
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(canSave ? Color(hex: "#30D158") : Color.white.opacity(0.3))
                    .disabled(!canSave)
                }
            }
            // HUDs
            .sheet(isPresented: $showSubServiceHUD) {
                SubServiceHUD(
                    draft: $subDraft,
                    isNew: isNewSubService,
                    companyId: sub.companyId,
                    institutions: institutions,
                    cards: cards,
                    onSave: {
                        var services = sub.subServices
                        if let subDraftID {
                            guard let idx = services.firstIndex(where: { $0.id == subDraftID }) else {
                                showSubServiceHUD = false
                                return
                            }
                            services[idx] = subDraft
                        } else {
                            services.append(subDraft)
                        }
                        sub.subServices = services
                        showSubServiceHUD = false
                    },
                    onCancel: { showSubServiceHUD = false },
                    onDelete: {
                        if let subDraftID {
                            sub.subServices.removeAll { $0.id == subDraftID }
                        }
                        showSubServiceHUD = false
                    }
                )
                .presentationDetents([.fraction(0.70), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
            .sheet(isPresented: $showEmailHUD) {
                LinkedEmailHUD(
                    draft: $emailDraft,
                    isNew: isNewEmail,
                    onSave: {
                        var emails = sub.linkedEmails
                        if let idx = emailDraftIndex {
                            emails[idx] = emailDraft
                        } else {
                            emails.append(emailDraft)
                        }
                        sub.linkedEmails = emails
                        showEmailHUD = false
                    },
                    onCancel: { showEmailHUD = false },
                    onDelete: {
                        if let idx = emailDraftIndex {
                            sub.linkedEmails.remove(at: idx)
                        }
                        showEmailHUD = false
                    }
                )
                .presentationDetents([.fraction(0.70), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
        }
    }

    // MARK: - Bindings
    private var dayBinding: Binding<Int> {
        Binding(
            get: { Int(sub.nextRenewal ?? "") ?? 1 },
            set: { sub.nextRenewal = "\($0)" }
        )
    }

    private var renewalDateBinding: Binding<Date> {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return Binding(
            get: {
                let parsed = df.date(from: sub.nextRenewal ?? "") ?? Date()
                let currentYear = Calendar.current.component(.year, from: Date())
                var comps = Calendar.current.dateComponents([.month, .day, .hour, .minute], from: parsed)
                comps.year = currentYear
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { sub.nextRenewal = df.string(from: $0) }
        )
    }
    
    private func ordinal(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
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
        // Focus mode: collapse everything after
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            currentStep = step
            // remove completed status for steps >= current
            completedSteps = completedSteps.filter { $0 < step }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 8) {
            let title: String = {
                switch currentStep {
                case 1: return "Add a subscription"
                case 2: return "Billing information"
                case 3: return "Connect a secondary service"
                case 4: return "What emails do you use"
                default: return "\(sub.name.isEmpty ? "Subscription" : sub.name) added"
                }
            }()
            let subtitle: String = {
                switch currentStep {
                case 1: return "Rich deep context across your org"
                case 2: return "Track costs, renewals, and payment methods"
                case 3: return "if you have a subscription within a subscription"
                case 4: return "Reasons and use for the emails"
                default: return "more context for your org"
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
                ForEach(1...4, id: \.self) { step in
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
    
    @ViewBuilder
    private var collapsedStepsView: some View {
        VStack(spacing: 12) {
            if completedSteps.contains(1) {
                CollapsedSectionBar(
                    icon: "📋",
                    label: "Login",
                    summary: "\(sub.name.isEmpty ? "Unnamed" : sub.name) · \(sub.loginId?.isEmpty == false ? sub.loginId! : "No ID")",
                    onExpand: { expandStep(1) }
                )
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity.combined(with: .scale(scale: 0.9))))
            }
            if completedSteps.contains(2) {
                CollapsedSectionBar(
                    icon: "💰",
                    label: "Billing",
                    summary: "$\(String(format: "%.2f", sub.cost)) · \(sub.billingCycle)",
                    onExpand: { expandStep(2) }
                )
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity.combined(with: .scale(scale: 0.9))))
            }
            if completedSteps.contains(3) {
                CollapsedSectionBar(
                    icon: "💾",
                    label: "Supplemental",
                    summary: sub.subServices.isEmpty ? "None added" : "\(sub.subServices.count) services",
                    onExpand: { expandStep(3) }
                )
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity.combined(with: .scale(scale: 0.9))))
            }
            if completedSteps.contains(4) {
                CollapsedSectionBar(
                    icon: "✉️",
                    label: "Emails",
                    summary: sub.linkedEmails.isEmpty ? "Skipped" : "\(sub.linkedEmails.count) emails",
                    onExpand: { expandStep(4) }
                )
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity.combined(with: .scale(scale: 0.9))))
            }
        }
    }
    
    // MARK: - Steps
    
    @ViewBuilder
    private var stepOneLogin: some View {
        if currentStep == 1 {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ZifrField(label: "SERVICE NAME", placeholder: "e.g. Shopify", text: Binding(get: {
                        sub.name
                    }, set: { newName in
                        sub.name = newName
                        if !hasManuallyEditedWebsite {
                            let cleanName = newName.lowercased().replacingOccurrences(of: " ", with: "")
                            sub.website = cleanName.isEmpty ? "" : cleanName + ".com"
                        }
                    }))
                    ZifrField(label: "WEBSITE", placeholder: "e.g. shopify.com", text: Binding(get: {
                        sub.website ?? ""
                    }, set: { newWebsite in
                        sub.website = newWebsite
                        hasManuallyEditedWebsite = true
                    }), keyboardType: .URL)
                }
                
                HStack(spacing: 12) {
                    ZifrAutocompleteField(
                        label: "LOGIN ID",
                        placeholder: "email or username",
                        text: Binding(get: { sub.loginId ?? "" }, set: { sub.loginId = $0 }),
                        keyboardType: .emailAddress,
                        textContentType: .username,
                        suggestions: Array(Set(appState.subscriptions.compactMap(\.loginId))).sorted()
                    )
                    ZifrField(
                        label: "PASSWORD",
                        placeholder: "••••••••",
                        text: Binding(get: { sub.password ?? "" }, set: { sub.password = $0 }),
                        isSecure: true,
                        textContentType: .password
                    )
                }
                
                DynamicLoginLabelView(loginId: sub.loginId ?? "", ignoreSubscriptionId: sub.id.uuidString)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                
                PremiumInputField(label: "PURPOSE & NOTES", placeholder: "e.g. Design tool used by marketing...", text: Binding(get: { sub.notes ?? "" }, set: { sub.notes = $0 }))
                
                nextButton(disabled: sub.name.isEmpty) { advanceToStep(2) }
            }
            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity.combined(with: .scale(scale: 0.9))))
        }
    }
    
    @ViewBuilder
    private var stepTwoBilling: some View {
        if currentStep == 2 {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PRICING MODEL")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.45))
                    
                    CustomSegmentedControl(options: ["paid", "free"], selection: $sub.pricingModel)
                }
                
                if sub.pricingModel == "paid" {
                    PremiumRow {
                        PremiumDoubleField(label: "COST", placeholder: "0.00", currency: sub.currency, value: $sub.cost)
                    } right: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("AUTO PAY")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.45))
                            
                            HStack {
                                Text(sub.renew == "Auto" ? "Yes" : "No")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Toggle("", isOn: Binding(get: { sub.renew == "Auto" }, set: { sub.renew = $0 ? "Auto" : "Manual" }))
                                    .labelsHidden()
                                    .toggleStyle(PremiumToggleStyle())
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 44)
                            .background(Color(hex: "#2C2C2E"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BILLING CYCLE")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.45))
                        
                        CustomSegmentedControl(options: ["Monthly", "Yearly"], selection: $sub.billingCycle)
                    }
                    
                    PremiumRow {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("RENEWS ON")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.45))
                            
                            HStack {
                                if sub.billingCycle == "Monthly" {
                                    Picker("", selection: dayBinding) {
                                        ForEach(1...31, id: \.self) { day in
                                            Text(ordinal(day)).tag(day)
                                        }
                                    }
                                    .labelsHidden()
                                    .padding(.leading, 6)
                                } else {
                                    DatePicker("", selection: renewalDateBinding, displayedComponents: .date)
                                        .labelsHidden()
                                        .datePickerStyle(.compact)
                                        .padding(.leading, 10)
                                }
                                Spacer()
                            }
                            .frame(height: 44)
                            .background(Color(hex: "#2C2C2E"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        }
                    } right: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("STATUS")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.45))
                            
                            HStack {
                                HStack(spacing: 6) {
                                    Circle().fill(sub.status == "Active" ? Color(hex: "#30D158") : Color.gray)
                                        .frame(width: 8, height: 8)
                                    Text(sub.status)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(sub.status == "Active" ? Color(hex: "#30D158") : Color.white.opacity(0.65))
                                }
                                Spacer()
                                Toggle("", isOn: Binding(get: { sub.status == "Active" }, set: { sub.status = $0 ? "Active" : "Paused" }))
                                    .labelsHidden()
                                    .toggleStyle(PremiumToggleStyle())
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 44)
                            .background(Color(hex: "#2C2C2E"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PAID FROM")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.45))
                        
                        NavigationLink {
                            PaymentMethodPickerView(
                                currentMethod: sub.paymentMethod ?? "",
                                companyId: sub.companyId,
                                institutions: institutions,
                                cards: cards,
                                onSelect: { id, name in
                                    sub.paymentMethodId = id
                                    sub.paymentMethod = name
                                }
                            )
                        } label: {
                            HStack {
                                Image(systemName: "creditcard.fill").foregroundStyle(Color.white.opacity(0.45))
                                Text(sub.paymentMethod?.isEmpty == false ? paymentMethodWithInstitution : "Select Payment Method")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(sub.paymentMethod?.isEmpty == false ? .white : Color.white.opacity(0.45))
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.white.opacity(0.3))
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 44)
                            .background(Color(hex: "#2C2C2E"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("STATUS")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.45))
                        
                        HStack {
                            HStack(spacing: 6) {
                                Circle().fill(sub.status == "Active" ? Color(hex: "#30D158") : Color.gray)
                                    .frame(width: 8, height: 8)
                                Text(sub.status)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(sub.status == "Active" ? Color(hex: "#30D158") : Color.white.opacity(0.65))
                            }
                            Spacer()
                            Toggle("", isOn: Binding(get: { sub.status == "Active" }, set: { sub.status = $0 ? "Active" : "Paused" }))
                                .labelsHidden()
                                .toggleStyle(PremiumToggleStyle())
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(Color(hex: "#2C2C2E"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                    }
                }
                nextButton(disabled: false) { advanceToStep(3) }
            }
            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity.combined(with: .scale(scale: 0.9))))
        }
    }
    
    @ViewBuilder
    private var stepThreeSupplemental: some View {
        if currentStep == 3 {
            VStack(spacing: 12) {
                Button {
                    subDraft = SubService()
                    subDraftID = nil
                    isNewSubService = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showSubServiceHUD = true
                } label: {
                    HStack(spacing: 8) {
                        Text("💾").font(.system(size: 14))
                        Text("Add Supplemental Service")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                }
                .buttonStyle(MiloomSecondaryButtonStyle())
                
                ForEach(sub.subServices) { ss in
                    Button {
                        subDraft = ss
                        subDraftID = ss.id
                        isNewSubService = false
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showSubServiceHUD = true
                    } label: {
                        HStack {
                            Text(ss.name.isEmpty ? "Unnamed" : ss.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("$\(String(format: "%.0f", ss.cost))")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Color(hex: "#111111"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.05), lineWidth: 1))
                    }
                }
                
                nextButton(disabled: false) { advanceToStep(4) }
                
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
            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity.combined(with: .scale(scale: 0.9))))
        }
    }
    
    @ViewBuilder
    private var stepFourEmails: some View {
        if currentStep == 4 {
            VStack(spacing: 12) {
                Button {
                    emailDraft = LinkedEmail()
                    emailDraftIndex = nil
                    isNewEmail = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showEmailHUD = true
                } label: {
                    HStack(spacing: 8) {
                        Text("✉️").font(.system(size: 14))
                        Text("Add Linked Email")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                }
                .buttonStyle(MiloomSecondaryButtonStyle())
                
                ForEach(sub.linkedEmails.indices, id: \.self) { i in
                    let email = sub.linkedEmails[i]
                    Button {
                        emailDraft = email
                        emailDraftIndex = i
                        isNewEmail = false
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showEmailHUD = true
                    } label: {
                        HStack {
                            Text(email.email.isEmpty ? "No Address" : email.email)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)
                            Spacer()
                            Text(email.usedFor.isEmpty ? "Unassigned" : email.usedFor)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Color(hex: "#111111"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.05), lineWidth: 1))
                    }
                }
                
                if !sub.linkedEmails.isEmpty {
                    nextButton(disabled: false) { advanceToStep(5) }
                } else if sub.linkedEmails.isEmpty && !hasSkippedEmail {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            hasSkippedEmail = true
                            advanceToStep(5)
                        }
                    } label: {
                        Text("Skip")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
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

    private var paymentMethodWithInstitution: String {
        guard let paymentMethod = sub.paymentMethod, !paymentMethod.isEmpty else { return "" }
        let normalizedMethod = paymentMethod.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Search in cards
        for c in appState.cards {
            if c.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedMethod {
                let instName = (c.institutionName ?? "").isEmpty ? "" : c.institutionName!
                if !instName.isEmpty {
                    return "\(instName) · \(paymentMethod)"
                }
            }
        }
        
        // 2. Search in institutions accounts
        for inst in appState.institutions {
            for acc in inst.accounts {
                let accName = acc.name.isEmpty ? acc.type : acc.name
                if accName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedMethod {
                    let instName = inst.name.isEmpty ? "" : inst.name
                    if !instName.isEmpty {
                        return "\(instName) · \(paymentMethod)"
                    }
                }
            }
        }
        return paymentMethod
    }
}

struct CollapsedSectionBar: View {
    let icon: String
    let label: String
    let summary: String
    let onExpand: () -> Void
    
    var body: some View {
        Button(action: onExpand) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: "#2F5051"))
                
                Text(icon)
                    .font(.system(size: 14))
                
                HStack(spacing: 4) {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("·")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.4))
                    Text(summary)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(Color(hex: "#050505"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#2F5051"), lineWidth: 1))
            .opacity(0.7)
        }
        .buttonStyle(.plain)
    }
}
