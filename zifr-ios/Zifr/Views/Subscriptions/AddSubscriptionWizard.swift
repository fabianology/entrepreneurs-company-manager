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
    @State private var subDraftIndex: Int? = nil
    @State private var isNewSubService = false

    @State private var showEmailHUD = false
    @State private var emailDraft = LinkedEmail()
    @State private var emailDraftIndex: Int? = nil
    @State private var isNewEmail = false
    @State private var hasSkippedEmail = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#171717").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Pricing toggle always visible at the top
                        Picker("Pricing Model", selection: $sub.pricingModel) {
                            Text("Paid").tag("paid")
                            Text("Free").tag("free")
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        
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
                                    Text("Add Subscription")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(canSubmit ? .white : Color.white.opacity(0.3))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 54)
                                        .background(canSubmit ? Color(hex: "#2B3A3B") : Color.white.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .disabled(!canSubmit)
                                .padding(.top, 16)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 60)
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
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    let canSave = completedSteps.contains(1)
                    Button("Save") {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        vm.saveSub(sub, appState: appState)
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(canSave ? Color.zifrGreen : Color.white.opacity(0.3))
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
                        if let idx = subDraftIndex {
                            services[idx] = subDraft
                        } else {
                            services.append(subDraft)
                        }
                        sub.subServices = services
                        showSubServiceHUD = false
                    },
                    onCancel: { showSubServiceHUD = false },
                    onDelete: {
                        if let idx = subDraftIndex {
                            sub.subServices.remove(at: idx)
                        }
                        showSubServiceHUD = false
                    }
                )
                .presentationDetents([.height(420)])
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
                .presentationDetents([.height(500)])
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
        
        var nextStep = step
        // If they chose free, and they hit next on step 1, jump to 3
        if nextStep == 2 && sub.pricingModel == "free" {
            nextStep = 3
            completedSteps.insert(2) // Auto-complete skipped step
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            currentStep = nextStep
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
                case 4: return "What emails should we link"
                default: return "All done"
                }
            }()
            let subtitle: String = {
                switch currentStep {
                case 1: return "Rich deep context across your org"
                case 2: return "Track costs and renewals"
                case 3: return "if you have a subscription within a subscription"
                case 4: return "if you use various emails or just one"
                default: return "more context for your org"
                }
            }()
            
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .id("headerTitle-\(currentStep)")
                .transition(.opacity)
                
            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.5))
                .id("headerSubtitle-\(currentStep)")
                .transition(.opacity)
                
            HStack(spacing: 8) {
                ForEach(1...4, id: \.self) { step in
                    Capsule()
                        .fill(step <= currentStep ? Color(hex: "#2B3A3B") : Color.white.opacity(0.1))
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
                    ZifrField(label: "SERVICE NAME", placeholder: "e.g. Shopify", text: $sub.name)
                    ZifrField(label: "WEBSITE", placeholder: "e.g. shopify.com", text: Binding(get: { sub.website ?? "" }, set: { sub.website = $0 }), keyboardType: .URL)
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
                
                nextButton(disabled: sub.name.isEmpty) { advanceToStep(2) }
            }
            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity.combined(with: .scale(scale: 0.9))))
        }
    }
    
    @ViewBuilder
    private var stepTwoBilling: some View {
        if currentStep == 2 {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("COST").zifrLabel()
                        HStack(spacing: 4) {
                            Text(sub.currency).font(.system(size: 14, weight: .bold)).foregroundStyle(Color.white.opacity(0.4))
                            DoubleField(placeholder: "0.00", value: $sub.cost)
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(Color(hex: "#111111")).clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AUTO PAY").zifrLabel()
                        HStack {
                            Text(sub.renew == "Auto" ? "Yes" : "No")
                                .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                            Spacer()
                            Toggle("", isOn: Binding(get: { sub.renew == "Auto" }, set: { sub.renew = $0 ? "Auto" : "Manual" }))
                                .labelsHidden()
                                .tint(Color.zifrGreen)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color(hex: "#111111")).clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("BILLING CYCLE").zifrLabel()
                    Picker("Billing Cycle", selection: $sub.billingCycle) {
                        Text("Monthly").tag("Monthly")
                        Text("Yearly").tag("Yearly")
                    }.pickerStyle(.segmented)
                }
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RENEWS ON").zifrLabel()
                        if sub.billingCycle == "Monthly" {
                            Picker("", selection: dayBinding) {
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
                        } else {
                            DatePicker("", selection: renewalDateBinding, displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .padding(.leading, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 44)
                                .background(Color(hex: "#111111"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("STATUS").zifrLabel()
                        HStack {
                            StatusDot(isGreen: sub.status == "Active", label: sub.status)
                            Spacer()
                            Toggle("", isOn: Binding(get: { sub.status == "Active" }, set: { sub.status = $0 ? "Active" : "Paused" }))
                                .labelsHidden()
                                .tint(Color.zifrGreen)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(Color(hex: "#111111")).clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("PAID FROM").zifrLabel()
                    NavigationLink {
                        PaymentMethodPickerView(
                            currentMethod: sub.paymentMethod ?? "",
                            companyId: sub.companyId,
                            institutions: institutions,
                            cards: cards,
                            onSelect: { sub.paymentMethod = $0 }
                        )
                    } label: {
                        HStack {
                            Image(systemName: "creditcard.fill").foregroundStyle(Color.white.opacity(0.5))
                            Text(sub.paymentMethod?.isEmpty == false ? sub.paymentMethod! : "Select Payment Method")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(sub.paymentMethod?.isEmpty == false ? .white : Color.white.opacity(0.3))
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.white.opacity(0.3))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Color(hex: "#111111")).clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                }
                
                ZifrField(label: "NOTES", placeholder: "Any internal notes...", text: Binding(get: { sub.notes ?? "" }, set: { sub.notes = $0 }))
                
                nextButton(disabled: false) { advanceToStep(3) }
            }
            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity.combined(with: .scale(scale: 0.9))))
        }
    }
    
    @ViewBuilder
    private var stepThreeSupplemental: some View {
        if currentStep == 3 {
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
                
                Button {
                    subDraft = SubService()
                    subDraftIndex = nil
                    isNewSubService = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showSubServiceHUD = true
                } label: {
                    HStack(spacing: 8) {
                        Text("💾").font(.system(size: 14))
                        Text("Add Supplemental Service")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color(hex: "#223E5A"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
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
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color(hex: "#223E5A"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
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
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(disabled ? Color.white.opacity(0.3) : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.05), lineWidth: 1))
        }
        .disabled(disabled)
        .padding(.top, 8)
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
                    .foregroundStyle(Color.zifrGreen)
                
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
            .background(Color(hex: "#111111"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
            .opacity(0.7)
        }
        .buttonStyle(.plain)
    }
}
