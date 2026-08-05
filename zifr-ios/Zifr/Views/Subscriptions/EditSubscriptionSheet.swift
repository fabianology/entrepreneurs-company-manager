import SwiftUI

// MARK: - Edit Subscription Sheet

struct EditSubscriptionSheet: View {
    @State var sub: Subscription
    let institutions: [Institution]
    let cards: [FinancialCard]
    @Bindable var vm: AppViewModel
    let isNew: Bool
    var onSave: (() -> Void)? = nil

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showDelete = false
    @State private var showShareSheet = false
    
    private var allSubscriptions: [Subscription] { appState.subscriptions }

    private var isViewer: Bool {
        let share = appState.resourceShares.first(where: { $0.resourceId == sub.id || $0.resourceId == sub.companyId })
        return share?.role == "Viewer"
    }

    @State private var showDeleteConfirm = false
    @State private var showPassword = false
    @State private var showSecurity = false

    // Sub-service HUD state — lifted here to avoid nested-sheet dismissal bug
    @State private var showSubServiceHUD = false
    @State private var subDraft = SubService()
    @State private var subDraftIndex: Int? = nil

    // Linked email HUD state — also lifted to NavigationStack level
    @State private var showEmailHUD = false
    @State private var emailDraft = LinkedEmail()
    @State private var emailDraftIndex: Int? = nil


    @State private var showPaymentPicker = false

    // Removed user preference for form density

    struct Snapshot: Equatable {
        var name, website, pricingModel, status, billingCycle, nextRenewal, paymentMethod, renew, loginId, password, twoFactorAuth, recoveryMethod, notes: String
        var cost: Double
        var showSubServicesTab: Bool
        var showLinkedEmailsTab: Bool
    }
    
    @State private var snapshot: Snapshot?

    private var currentSnapshot: Snapshot {
        Snapshot(
            name: sub.name, website: sub.website ?? "", pricingModel: sub.pricingModel ?? "", status: sub.status ?? "",
            billingCycle: sub.billingCycle ?? "", nextRenewal: sub.nextRenewal ?? "", paymentMethod: sub.paymentMethod ?? "",
            renew: sub.renew, loginId: sub.loginId ?? "", password: sub.password ?? "",
            twoFactorAuth: sub.twoFactorAuth ?? "", recoveryMethod: sub.recoveryMethod ?? "", notes: sub.notes ?? "",
            cost: sub.cost, showSubServicesTab: sub.showSubServicesTab, showLinkedEmailsTab: sub.showLinkedEmailsTab
        )
    }

    private var isDirty: Bool {
        guard let snap = snapshot else { return isNew && !sub.name.isEmpty }
        return snap != currentSnapshot
    }

    // Flat list of payable accounts from all passed institutions
    private var payableAccounts: [InstitutionAccount] {
        institutions.flatMap { $0.accounts }
    }

    // Derived binding: "Auto" / "Manual" → Bool Toggle
    private var autoPayBinding: Binding<Bool> {
        Binding(
            get: { sub.renew == "Auto" },
            set: { sub.renew = $0 ? "Auto" : "Manual" }
        )
    }

    private let twoFAOptions = ["None", "Authenticator", "SMS", "Email", "Hardware Key", "Backup Codes"]

    // Ordinal formatter: 1 → "1st", 15 → "15th", etc.
    private let ordinalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .ordinal
        return f
    }()

    private func ordinal(_ n: Int) -> String {
        ordinalFormatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    // Binding: Int day (1–31) ↔ String stored in nextRenewal
    private var dayBinding: Binding<Int> {
        Binding(
            get: { Int(sub.nextRenewal ?? "") ?? 1 },
            set: { sub.nextRenewal = "\($0)" }
        )
    }

    // Binding: Date ↔ "MMM d" string stored in nextRenewal (yearly)
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






    private var costCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("COST")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.45))
            HStack(spacing: 4) {
                Text("$")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.5))
                DoubleField(placeholder: "0.00", value: Binding(
                    get: { sub.cost },
                    set: { (val: Double) in sub.cost = val }
                ))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 44)
            .background(Color(hex: "#2C2C2E"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
    }

    private var autoPayCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("AUTO PAY")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.45))
            HStack {
                Text(autoPayBinding.wrappedValue ? "Enabled" : "Manual")
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
            .background(Color(hex: "#2C2C2E"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("STATUS")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.45))
            HStack {
                StatusDot(isGreen: sub.status == "Active")
                Text(sub.status == "Active" ? "Active" : "Paused")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { sub.status == "Active" },
                    set: { sub.status = $0 ? "Active" : "Paused" }
                ))
                .labelsHidden()
                .tint(.green)
                .scaleEffect(0.8)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color(hex: "#2C2C2E"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
    }

    private var billingCycleCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("BILLING CYCLE")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.45))
            CustomSegmentedControl(options: ["Monthly", "Yearly"], selection: Binding(
                get: { sub.billingCycle },
                set: { (newCycle: String) in
                    if newCycle != sub.billingCycle {
                        if newCycle == "Monthly" {
                            sub.nextRenewal = "1"
                        } else {
                            let df = DateFormatter()
                            df.dateFormat = "MMM d"
                            sub.nextRenewal = df.string(from: Date())
                        }
                    }
                    sub.billingCycle = newCycle
                }
            ))
        }
    }

    @ViewBuilder
    private var renewalCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("RENEWS ON")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.45))
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
                .background(Color(hex: "#2C2C2E"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
            } else {
                DatePicker("", selection: renewalDateBinding, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .padding(.leading, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 44)
                    .background(Color(hex: "#2C2C2E"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
            }
        }
    }

    private var paidFromCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PAID FROM")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.45))
            
            Button {
                showPaymentPicker = true
            } label: {
                HStack {
                    Text((sub.paymentMethod ?? "").isEmpty ? "N/A" : paymentMethodWithInstitution)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle((sub.paymentMethod ?? "").isEmpty ? Color.white.opacity(0.4) : .white)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Color(hex: "#2C2C2E"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
            }
            .buttonStyle(.borderless)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                SharedItemOverrideBanner(resourceId: sub.id, defaultCompanyId: sub.companyId)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                Group {
                    // MARK: – Top Controls
                VStack(spacing: 12) {
                    CustomSegmentedControl(options: ["paid", "free"], selection: Binding(get: { sub.pricingModel }, set: { sub.pricingModel = $0 }))
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .listRowBackground(Color.clear)

                // MARK: – Identity
                Section {
                     VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            ZifrField(
                                label: "SERVICE NAME",
                                placeholder: "e.g. Shopify",
                                text: Binding(get: { sub.name }, set: { sub.name = $0 })
                            )
                            ZifrField(
                                label: "WEBSITE",
                                placeholder: "shopify.com",
                                text: Binding(get: { sub.website ?? "" }, set: { sub.website = $0 }),
                                keyboardType: .URL,
                                textContentType: .URL
                            )
                            .textInputAutocapitalization(.never)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                ZifrAutocompleteField(
                                    label: "LOGIN ID",
                                    placeholder: "username or email",
                                    text: Binding(get: { sub.loginId ?? "" }, set: { sub.loginId = $0 }),
                                    keyboardType: .emailAddress,
                                    textContentType: .username,
                                    suggestions: allSubscriptions.compactMap { $0.loginId }.filter { !$0.isEmpty } + institutions.compactMap { $0.username }.filter { !$0.isEmpty } + institutions.compactMap { $0.email }.filter { !$0.isEmpty }
                                )
                                
                                ZStack(alignment: .bottomTrailing) {
                                    ZifrField(
                                        label: "PASSWORD",
                                        placeholder: "••••••••",
                                        text: Binding(get: { sub.password ?? "" }, set: { sub.password = $0 }),
                                        isSecure: !showPassword,
                                        textContentType: .password
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
                            
                            DynamicLoginLabelView(loginId: sub.loginId ?? "", ignoreSubscriptionId: sub.id.uuidString)
                        }

                    }
                    .padding(.vertical, 4)
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 12, weight: .bold))
                        Text("SERVICE DETAILS")
                            .font(.system(size: 12, weight: .black))
                            .tracking(1.5)
                    }
                    .foregroundStyle(Color.white.opacity(0.6))
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                .listRowSeparator(.hidden)

                // MARK: – Billing (Paid only)
                if !sub.isFree {

                    Section {
                        VStack(spacing: 16) {
                            HStack(spacing: 12) {
                                costCard
                                autoPayCard
                            }
                            billingCycleCard
                            HStack(spacing: 12) {
                                renewalCard
                                statusCard
                            }
                            paidFromCard
                        }
                        .padding(.vertical, 4)
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: "creditcard")
                                .font(.system(size: 12, weight: .bold))
                            Text("BILLING & RENEWAL")
                                .font(.system(size: 12, weight: .black))
                                .tracking(1.5)
                        }
                        .foregroundStyle(Color.white.opacity(0.6))
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .listRowSeparator(.hidden)
                }

                    // MARK: – Notes (before Security)
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PURPOSE & NOTES")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.45))
                            TextField("e.g. Design tool used by marketing...",
                                      text: Binding(get: { sub.notes ?? "" }, set: { sub.notes = $0 }),
                                      axis: .vertical)
                                .lineLimit(3...6)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(hex: "#2C2C2E"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        }
                    } header: { EmptyView() }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .listRowSeparator(.hidden)



                    // MARK: – Security & Recovery (below Notes)
                    // Reveal button — shown only when section is hidden
                    if !showSecurity {
                        Section {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { showSecurity = true }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "lock.shield")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.white.opacity(0.35))
                                    Text("ADD SECURITY INFO")
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
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .listRowSeparator(.hidden)
                    }

                    if showSecurity {
                        Section {
                        VStack(spacing: 0) {
                            // Tappable collapse row
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { showSecurity = false }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                HStack {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.07))
                                        .frame(height: 1)
                                    Text("SECURITY")
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

                            HStack(spacing: 12) {
                                // 2FA Picker card
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("2FA")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                    Picker("", selection: Binding(get: { sub.twoFactorAuth }, set: { sub.twoFactorAuth = $0 })) {
                                        ForEach(twoFAOptions, id: \.self) { opt in
                                            Text(opt).tag(opt)
                                        }
                                    }
                                    .labelsHidden()
                                    .padding(.leading, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(height: 44)
                                    .background(Color(hex: "#2C2C2E"))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
                                }

                                // Recovery TextField card
                                ZifrField(
                                    label: "RECOVERY",
                                    placeholder: "Phone, email…",
                                    text: Binding(get: { sub.recoveryMethod ?? "" }, set: { sub.recoveryMethod = $0 })
                                )
                                .autocorrectionDisabled()
                            }
                        }
                        } header: { EmptyView() }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .listRowSeparator(.hidden)
                    }


                    // MARK: – Supplemental Services
                    // Thin divider above SubServices


                    SubServicesSection(
                        sub: sub,
                        onAdd: {
                            subDraft = SubService()
                            subDraftIndex = nil
                            showSubServiceHUD = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        },
                        onEdit: { idx, service in
                            subDraft = service
                            subDraftIndex = idx
                            showSubServiceHUD = true
                        }
                    )

                    // MARK: – Linked Emails

                    LinkedEmailsSection(
                        sub: sub,
                        onAdd: {
                            emailDraft = LinkedEmail()
                            emailDraftIndex = nil
                            showEmailHUD = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        },
                        onEdit: { idx, email in
                            emailDraft = email
                            emailDraftIndex = idx
                            showEmailHUD = true
                        }
                    )

                // MARK: – Danger Zone
                if !isNew {
                    Section {
                        // Share Service (premium gradient)
                         Button {
                             UIImpactFeedbackGenerator(style: .light).impactOccurred()
                             showShareSheet = true
                         } label: {
                             VStack(spacing: 4) {
                                 HStack(spacing: 6) {
                                     Image(systemName: "person.crop.circle.badge.plus")
                                     Text("Share Service")
                                 }
                                 .font(.system(size: 13, weight: .semibold))
                                 Text("Generate a share link for collaborators")
                                     .font(.system(size: 10, weight: .regular))
                                     .foregroundStyle(Color.white.opacity(0.6))
                             }
                             .frame(maxWidth: .infinity)
                             .padding(.vertical, 10)
                         }
                         .buttonStyle(MiloomSecondaryButtonStyle())
                         .padding(.bottom, 8)

                        // Delete Service
                        Button(role: .destructive) {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("Delete \(sub.name.isEmpty ? "Service" : sub.name)")
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
                            "Delete \"\(sub.name.isEmpty ? "this service" : sub.name)\"?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible
                        ) {
                            Button("Delete Service", role: .destructive) {
                                vm.deleteSub(sub, appState: appState)
                                dismiss()
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This will permanently delete this service and all associated data. This action cannot be undone.")
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 20, trailing: 20))
                    .listRowSeparator(.hidden)
                }
                } // End Group
                .disabled(isViewer)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#1C1C1E"))
            .listSectionSpacing(0)
            .onAppear {
                if (sub.nextRenewal ?? "").isEmpty {
                    if sub.billingCycle == "Monthly" {
                        sub.nextRenewal = "1"
                    } else {
                        let df = DateFormatter()
                        df.dateFormat = "MMM d"
                        sub.nextRenewal = df.string(from: Date())
                    }
                }
                snapshot = currentSnapshot
                if sub.twoFactorAuth != "None" || !(sub.recoveryMethod ?? "").isEmpty {
                    showSecurity = true
                }
            }
            .navigationTitle(sub.name.isEmpty ? "New Service" : sub.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showPaymentPicker) {
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
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(sub.name.isEmpty ? "New Service" : sub.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: "#C1AA78"))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isNew { 
                            vm.deleteSub(sub, appState: appState) 
                        } else if let snap = snapshot {
                            sub.name = snap.name
                            sub.website = snap.website
                            sub.pricingModel = snap.pricingModel
                            sub.status = snap.status
                            sub.billingCycle = snap.billingCycle
                            sub.nextRenewal = snap.nextRenewal
                            sub.paymentMethod = snap.paymentMethod
                            sub.renew = snap.renew
                            sub.loginId = snap.loginId
                            sub.password = snap.password
                            sub.twoFactorAuth = snap.twoFactorAuth
                            sub.recoveryMethod = snap.recoveryMethod
                            sub.notes = snap.notes
                            sub.cost = snap.cost
                            sub.showSubServicesTab = snap.showSubServicesTab
                            sub.showLinkedEmailsTab = snap.showLinkedEmailsTab
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !isViewer {
                        Button("Save") {
                            vm.saveSub(sub, appState: appState)
                            onSave?()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .tint(isDirty ? .green : nil)
                        .disabled(sub.name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .interactiveDismissDisabled(isNew)
            .sheet(isPresented: $showSubServiceHUD) {
                SubServiceHUD(
                    draft: $subDraft,
                    isNew: subDraftIndex == nil,
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
                        if let idx = subDraftIndex { sub.subServices.remove(at: idx) }
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
                    isNew: emailDraftIndex == nil,
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
                        if let idx = emailDraftIndex { sub.linkedEmails.remove(at: idx) }
                        showEmailHUD = false
                    }
                )
                .presentationDetents([.height(500)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
            .sheet(isPresented: $showShareSheet) {
                ShareEntitySheet(resourceId: sub.id, resourceType: "subscription", resourceTitle: sub.name.isEmpty ? "Subscription" : sub.name)
            }
        }
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

// MARK: – Supplemental Services Section

struct SubServicesSection: View {
    @State var sub: Subscription
    let onAdd: () -> Void
    let onEdit: (Int, SubService) -> Void



    var body: some View {
        Section {
                Button { onAdd() } label: {
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text("Add Sub-Service")
                        }
                        .font(.system(size: 13, weight: .bold))
                        
                        Text("addons · extra licenses · premium tiers")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(MiloomSecondaryButtonStyle())

                ForEach(sub.subServices.indices, id: \.self) { i in
                    let ss = sub.subServices[i]
                    Button { onEdit(i, ss) } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ss.name.isEmpty ? "Unnamed Service" : ss.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                HStack(spacing: 6) {
                                    if ss.cost > 0 {
                                        Text("$\(ss.cost, specifier: "%.2f")")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.45))
                                        Text("·").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.2))
                                    }
                                    Text(ss.billingCycle.rawValue)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                    Text("·").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.2))
                                    Text(ss.autoPay == .auto ? "Auto" : "Manual")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(ss.autoPay == .auto ? 0.8 : 0.3))
                                }
                            }
                            Spacer()
                            // Status pill
                            Text(ss.status.rawValue.uppercased())
                                .font(.system(size: 9, weight: .black))
                                .tracking(0.5)
                                .foregroundStyle(ss.status == .active ? Color.green : Color.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background((ss.status == .active ? Color.green : Color.orange).opacity(0.12))
                                .clipShape(Capsule())
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.2))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#2C2C2E"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            withAnimation {
                                var services = sub.subServices
                                services.remove(at: i)
                                sub.subServices = services
                            }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.red)
                    }
                }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("SUB-SERVICES")
                    .font(.system(size: 12, weight: .black))
                    .tracking(1.5)
            }
            .foregroundStyle(Color.white.opacity(0.6))
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
        .listRowSeparator(.hidden)
    }
}


// MARK: – Sub Service HUD

struct SubServiceHUD: View {
    @Binding var draft: SubService
    let isNew: Bool
    let companyId: UUID
    let institutions: [Institution]
    let cards: [FinancialCard]
    let onSave: () -> Void
    let onCancel: () -> Void
    var onDelete: (() -> Void)? = nil

    @State private var initialDraft: SubService? = nil
    @State private var showPaymentPicker = false

    private var isDirty: Bool {
        guard let initial = initialDraft else { return isNew && !draft.name.isEmpty }
        return draft.name != initial.name ||
               draft.paymentMethod != initial.paymentMethod ||
               draft.cost != initial.cost ||
               draft.billingCycle != initial.billingCycle ||
               draft.autoPay != initial.autoPay ||
               draft.status != initial.status ||
               draft.purpose != initial.purpose
    }



    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {

                        // Row 1: Name + Paid From
                        HStack(spacing: 12) {
                            ZifrField(
                                label: "NAME",
                                placeholder: "e.g. Premium Plan",
                                text: $draft.name
                            )
                            .autocorrectionDisabled()

                            // Paid From card
                            VStack(alignment: .leading, spacing: 4) {
                                Text("PAID FROM")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(Color.white.opacity(0.45))
                                
                                Button {
                                    showPaymentPicker = true
                                } label: {
                                    HStack {
                                        Text(draft.paymentMethod.isEmpty ? "N/A" : paymentMethodWithInstitution(for: draft.paymentMethod))
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(draft.paymentMethod.isEmpty ? Color.white.opacity(0.4) : .white)
                                            .lineLimit(1)
                                        Spacer(minLength: 8)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color.white.opacity(0.3))
                                    }
                                    .padding(.horizontal, 16)
                                    .frame(height: 44)
                                    .background(Color(hex: "#2C2C2E"))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Row 2: Cost + Billing Cycle
                        HStack(spacing: 12) {
                            // Cost card
                            VStack(alignment: .leading, spacing: 4) {
                                Text("COST")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(Color.white.opacity(0.45))
                                HStack(spacing: 4) {
                                    Text("$")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                    DoubleField(placeholder: "0.00", value: $draft.cost)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 44)
                                .background(Color(hex: "#2C2C2E"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
                            }

                            // Billing Cycle card
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CYCLE")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(Color.white.opacity(0.45))
                                CustomSegmentedControl(options: ["Monthly", "Yearly"], selection: Binding(
                                    get: { draft.billingCycle == .monthly ? "Monthly" : "Yearly" },
                                    set: { draft.billingCycle = $0 == "Monthly" ? .monthly : .yearly }
                                ))
                            }
                        }

                        // Row 3: Auto Pay + Status
                        HStack(spacing: 12) {
                            // Auto Pay card
                            VStack(alignment: .leading, spacing: 4) {
                                Text("AUTO PAY")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(Color.white.opacity(0.45))
                                HStack {
                                    Text(draft.autoPay == .auto ? "Enabled" : "Manual")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.white)
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { draft.autoPay == .auto },
                                        set: { draft.autoPay = $0 ? .auto : .manual }
                                    ))
                                    .labelsHidden()
                                    .tint(.green)
                                    .scaleEffect(0.8)
                                }
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color(hex: "#2C2C2E"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
                            }

                            // Status card
                            VStack(alignment: .leading, spacing: 4) {
                                Text("STATUS")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(Color.white.opacity(0.45))
                                HStack {
                                    StatusDot(isGreen: draft.status == .active)
                                    Text(draft.status == .active ? "Active" : "Paused")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { draft.status == .active },
                                        set: { draft.status = $0 ? .active : .paused }
                                    ))
                                    .labelsHidden()
                                    .tint(.green)
                                    .scaleEffect(0.8)
                                }
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color(hex: "#2C2C2E"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
                            }
                        }

                        // Row 4: Purpose (full width)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PURPOSE")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.45))
                            TextField("What is this service for?",
                                      text: $draft.purpose,
                                      axis: .vertical)
                                .lineLimit(2...4)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(hex: "#2C2C2E"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
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
                                Text("Delete Service")
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
            .background(Color(hex: "#1C1C1E"))
            .listSectionSpacing(0)
            .navigationTitle(draft.name.isEmpty ? "New Service" : draft.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(draft.name.isEmpty ? "New Service" : draft.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: "#C1AA78"))
                }
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
            .onAppear { initialDraft = draft }
            .sheet(isPresented: $showPaymentPicker) {
                PaymentMethodPickerView(
                    currentMethod: draft.paymentMethod,
                    companyId: companyId,
                    institutions: institutions,
                    cards: cards,
                    onSelect: { id, name in
                        draft.paymentMethodId = id
                        draft.paymentMethod = name
                    }
                )
                .presentationDetents([.height(550)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
        }
    }

    private func paymentMethodWithInstitution(for method: String) -> String {
        guard !method.isEmpty else { return "" }
        let normalizedMethod = method.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Search in cards
        for c in cards {
            if c.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedMethod {
                let instName = (c.institutionName ?? "").isEmpty ? "" : c.institutionName!
                if !instName.isEmpty {
                    return "\(instName) · \(method)"
                }
            }
        }
        
        // 2. Search in institutions accounts
        for inst in institutions {
            for acc in inst.accounts {
                let accName = acc.name.isEmpty ? acc.type : acc.name
                if accName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedMethod {
                    let instName = inst.name.isEmpty ? "" : inst.name
                    if !instName.isEmpty {
                        return "\(instName) · \(method)"
                    }
                }
            }
        }
        return method
    }
}

// MARK: – Linked Email Helpers

struct UsedInEmailService: Hashable {
    let name: String
    let role: Role
    enum Role { case primary, linked }
}

struct LinkedEmailCardView: View {
    let em: LinkedEmail
    let allSubscriptions: [Subscription]
    let onEdit: () -> Void



    private var computedServices: [UsedInEmailService] {
        let normalizedEmail = em.email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty else { return [] }

        var results: [UsedInEmailService] = []
        var seen = Set<String>()

        for sub in allSubscriptions {
            let isPrimary = (sub.loginId ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedEmail
            let isLinked = sub.linkedEmails.contains { $0.email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedEmail }
            
            let sName = sub.name.isEmpty ? "Unnamed Service" : sub.name
            
            if isPrimary || isLinked {
                if !seen.contains(sName) {
                    results.append(UsedInEmailService(name: sName, role: isPrimary ? .primary : .linked))
                    seen.insert(sName)
                }
            }
        }
        return results
    }

    private var legacyTags: [String] {
        let computed = computedServices
        return em.usedIn.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { tag in 
                !tag.isEmpty && !computed.contains { $0.name.lowercased() == tag.lowercased() }
            }
    }

    var body: some View {
        Button { onEdit() } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(em.email.isEmpty ? "No address" : em.email)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    HStack(spacing: 6) {
                        if !em.provider.isEmpty {
                            Text(em.provider)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.45))
                            Text("·").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.2))
                        }
                        if !em.usedFor.isEmpty {
                            Text(em.usedFor)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.45))
                        }
                    }

                    if !computedServices.isEmpty || !legacyTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(computedServices, id: \.self) { svc in
                                    HStack(spacing: 4) {
                                        Text(svc.role == .primary ? "🔑" : "🔗")
                                            .font(.system(size: 9))
                                        Text("\(svc.name)\(svc.role == .primary ? " (Login)" : "")")
                                            .font(.system(size: 9, weight: .bold))
                                            .textCase(.uppercase)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background {
                                        if svc.role == .primary {
                                            Color.green.opacity(0.15)
                                        } else {
                                            Color.blue.opacity(0.15)
                                        }
                                    }
                                    .foregroundStyle(svc.role == .primary ? Color.green : Color.blue)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(svc.role == .primary ? Color.green.opacity(0.2) : Color.blue.opacity(0.2), lineWidth: 1))
                                }
                                
                                ForEach(legacyTags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 9, weight: .bold))
                                        .textCase(.uppercase)
                                        .tracking(0.5)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.05))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 1))
                                }
                            }
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.2))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(hex: "#2C2C2E"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: – Linked Emails Section

struct LinkedEmailsSection: View {
    @State var sub: Subscription
    let onAdd: () -> Void
    let onEdit: (Int, LinkedEmail) -> Void

    @Environment(AppState.self) private var appState
    private var allSubscriptions: [Subscription] { appState.subscriptions }



    var body: some View {
        Section {
                Button { onAdd() } label: {
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text("Add Linked Email")
                        }
                        .font(.system(size: 13, weight: .bold))
                        
                        Text("aliases · forwards · external accounts")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(MiloomSecondaryButtonStyle())

                ForEach(sub.linkedEmails.indices, id: \.self) { i in
                    let em = sub.linkedEmails[i]
                    LinkedEmailCardView(em: em, allSubscriptions: allSubscriptions, onEdit: { onEdit(i, em) })
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            withAnimation {
                                var emails = sub.linkedEmails
                                emails.remove(at: i)
                                sub.linkedEmails = emails
                            }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.red)
                    }
                }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("LINKED EMAILS")
                    .font(.system(size: 12, weight: .black))
                    .tracking(1.5)
            }
            .foregroundStyle(Color.white.opacity(0.6))
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
        .listRowSeparator(.hidden)
    }
}

// MARK: – Linked Email HUD

struct LinkedEmailHUD: View {
    @Binding var draft: LinkedEmail
    let isNew: Bool
    
    @Environment(AppState.self) private var appState
    private var allInstitutions: [Institution] { appState.institutions }
    
    private var allLogins: [String] {
        let subLogins = allSubscriptions.compactMap { $0.loginId }
        let instUsers = allInstitutions.compactMap { $0.username }
        let instEmails = allInstitutions.compactMap { $0.email }
        return (subLogins + instUsers + instEmails).compactMap { $0 }.filter { !$0.isEmpty }
    }
    let onSave: () -> Void
    let onCancel: () -> Void
    var onDelete: (() -> Void)? = nil

    @State private var initialDraft: LinkedEmail? = nil
    
    private var allSubscriptions: [Subscription] { appState.subscriptions }

    struct UsedInService: Hashable {
        let name: String
        let role: Role
        enum Role { case primary, linked }
    }

    private var computedServices: [UsedInService] {
        let normalizedEmail = draft.email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty else { return [] }

        var results: [UsedInService] = []
        var seen = Set<String>()

        for sub in allSubscriptions {
            let isPrimary = (sub.loginId ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedEmail
            let isLinked = sub.linkedEmails.contains { $0.email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedEmail }
            
            let sName = sub.name.isEmpty ? "Unnamed Service" : sub.name
            
            if isPrimary || isLinked {
                if !seen.contains(sName) {
                    results.append(UsedInService(name: sName, role: isPrimary ? .primary : .linked))
                    seen.insert(sName)
                }
            }
        }
        return results
    }

    private var legacyTags: [String] {
        let computed = computedServices
        return draft.usedIn.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { tag in 
                !tag.isEmpty && !computed.contains { $0.name.lowercased() == tag.lowercased() }
            }
    }

    private var isDirty: Bool {
        guard let initial = initialDraft else { return isNew && !draft.email.isEmpty }
        return draft.email != initial.email ||
               draft.provider != initial.provider ||
               draft.usedFor != initial.usedFor ||
               draft.accessMethod != initial.accessMethod ||
               draft.notes != initial.notes
    }

    // notes stored as [String]; bind as a single multiline string
    private var notesBinding: Binding<String> {
        Binding(
            get: { draft.notes.joined(separator: "\n") },
            set: { draft.notes = $0.components(separatedBy: "\n").compactMap { $0 }.filter { !$0.isEmpty } }
        )
    }

    private var usedInCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("USED IN")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.45))
            
            if computedServices.isEmpty && legacyTags.isEmpty {
                HStack {
                    Text("Auto-generates when linked to services...")
                        .font(.system(size: 11, weight: .medium, design: .serif).italic())
                        .foregroundStyle(Color.white.opacity(0.3))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Color(hex: "#2C2C2E"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(computedServices, id: \.self) { svc in
                            HStack(spacing: 4) {
                                Text(svc.role == .primary ? "🔑" : "🔗")
                                    .font(.system(size: 10))
                                Text("\(svc.name)\(svc.role == .primary ? " (Login)" : "")")
                                    .font(.system(size: 10, weight: .bold))
                                    .textCase(.uppercase)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background {
                                if svc.role == .primary {
                                    Color.green.opacity(0.15)
                                } else {
                                    Color.blue.opacity(0.15)
                                }
                            }
                            .foregroundStyle(svc.role == .primary ? Color.green : Color.blue)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(svc.role == .primary ? Color.green.opacity(0.2) : Color.blue.opacity(0.2), lineWidth: 1))
                        }
                        
                        ForEach(legacyTags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10, weight: .bold))
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.05))
                                .foregroundStyle(Color.white.opacity(0.5))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 44)
                .background(Color(hex: "#2C2C2E"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
            }
        }
    }


    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {

                        // Row 1: Address (full width)
                        ZifrAutocompleteField(
                            label: "EMAIL ADDRESS",
                            placeholder: "name@example.com",
                            text: $draft.email,
                            keyboardType: .emailAddress,
                            suggestions: allLogins
                        )

                        // Row 2: Provider + Access Method
                        HStack(spacing: 12) {
                            ZifrField(
                                label: "PROVIDER",
                                placeholder: "Gmail, iCloud…",
                                text: $draft.provider
                            )
                            .autocorrectionDisabled()

                            ZifrField(
                                label: "ACCESS METHOD",
                                placeholder: "Google SSO, Password…",
                                text: $draft.accessMethod
                            )
                            .autocorrectionDisabled()
                        }

                        // Row 3: Used For (full width)
                        ZifrField(
                            label: "USED FOR",
                            placeholder: "Billing, Admin…",
                            text: $draft.usedFor
                        )
                        .autocorrectionDisabled()

                        // Row 4: Used In (Auto-computed)
                        usedInCard

                        // Row 5: Notes (full width)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NOTES")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.45))
                            TextField("Add notes…", text: notesBinding, axis: .vertical)
                                .lineLimit(2...4)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(hex: "#2C2C2E"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
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
                                Text("Delete Email")
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
            .background(Color(hex: "#1C1C1E"))
            .listSectionSpacing(0)
            .navigationTitle(draft.email.isEmpty ? "New Email" : draft.email)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(draft.email.isEmpty ? "New Email" : draft.email)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: "#C1AA78"))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Save", action: onSave)
                        .fontWeight(.semibold)
                        .tint(isDirty ? .green : nil)
                        .disabled(draft.email.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { initialDraft = draft }
        }
    }
}

// MARK: - Payment Method Picker View

struct PaymentMethodPickerView: View {
    let currentMethod: String
    let currentMethodId: UUID? = nil
    let companyId: UUID
    let institutions: [Institution]
    let cards: [FinancialCard]
    let onSelect: (UUID?, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    private var allCompanies: [Company] { appState.companies }
    
    private var allInstitutions: [Institution] { appState.institutions }
    
    private var allCards: [FinancialCard] { appState.cards }

    @State private var searchText = ""
    @AppStorage("userCustomPaymentMethods") private var storedCustomMethods: String = ""

    @State private var itemToEdit: String? = nil
    @State private var editedItemName: String = ""
    @State private var showEditAlert = false
    
    @State private var selectedScope: String = "current"

    struct AccountDisplay: Identifiable {
        let id = UUID()
        let instName: String
        let companyId: UUID
        let account: InstitutionAccount
    }
    
    private var currentCompanyName: String {
        allCompanies.first { $0.id == companyId }?.name ?? "Current Entity"
    }

    private var effectiveInstitutions: [Institution] {
        selectedScope == "all" ? allInstitutions : institutions
    }
    
    private var effectiveCards: [FinancialCard] {
        selectedScope == "all" ? allCards : cards
    }

    var accountDisplays: [AccountDisplay] {
        effectiveInstitutions.flatMap { inst in
            inst.accounts.map { AccountDisplay(instName: inst.name, companyId: inst.companyId, account: $0) }
        }
    }

    var filteredAccounts: [AccountDisplay] {
        if searchText.isEmpty { return accountDisplays }
        return accountDisplays.filter { ($0.account.name + $0.account.type + ($0.account.last4 ?? "") + $0.instName).localizedCaseInsensitiveContains(searchText) }
    }

    var filteredCards: [FinancialCard] {
        if searchText.isEmpty { return effectiveCards }
        return effectiveCards.filter { ($0.name + $0.type + ($0.last4 ?? "") + ($0.institutionName ?? "")).localizedCaseInsensitiveContains(searchText) }
    }
    
    var allCustomMethods: [String] {
        let stored = storedCustomMethods.split(separator: ",").map(String.init)
        let predefinedAccounts = Set(accountDisplays.map { $0.account.name.isEmpty ? $0.account.type : $0.account.name })
        let predefinedCards = Set(effectiveCards.map(\.name))
        let allPredefined = predefinedAccounts.union(predefinedCards)
        
        return Array(Set(stored).subtracting(allPredefined)).sorted()
    }
    
    var filteredCustomMethods: [String] {
        if searchText.isEmpty { return allCustomMethods }
        return allCustomMethods.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var exactMatchExists: Bool {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return true }
        if accountDisplays.contains(where: { ($0.account.name.isEmpty ? $0.account.type : $0.account.name).lowercased() == q }) { return true }
        if effectiveCards.contains(where: { $0.name.lowercased() == q }) { return true }
        if allCustomMethods.contains(where: { $0.lowercased() == q }) { return true }
        return false
    }

    private func selectCustom(_ method: String) {
        if !method.isEmpty {
            var methods = storedCustomMethods.split(separator: ",").map(String.init)
            if !methods.contains(method) {
                methods.append(method)
                storedCustomMethods = methods.joined(separator: ",")
            }
        }
        onSelect(nil, method)
        dismiss()
    }

    private func selectStandard(id: UUID?, name: String) {
        onSelect(id, name)
        dismiss()
    }

    private func deleteCustom(_ method: String) {
        var methods = storedCustomMethods.split(separator: ",").map(String.init)
        if let idx = methods.firstIndex(of: method) {
            methods.remove(at: idx)
            storedCustomMethods = methods.joined(separator: ",")
            if currentMethod == method {
                onSelect(nil, "")
            }
        }
    }

    private func updateCustom(oldName: String, newName: String) {
        let trimmedNewName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNewName.isEmpty, trimmedNewName != oldName else { return }

        var methods = storedCustomMethods.split(separator: ",").map(String.init)
        if let idx = methods.firstIndex(of: oldName) {
            if !methods.contains(trimmedNewName) {
                methods[idx] = trimmedNewName
            } else {
                methods.remove(at: idx)
            }
            storedCustomMethods = methods.joined(separator: ",")
            if currentMethod == oldName {
                onSelect(nil, trimmedNewName)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("Enter custom or Search", text: $searchText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .liquidGlass(cornerRadius: 14)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            CustomSegmentedControl(options: [currentCompanyName, "All Entities"], selection: Binding(
                get: { selectedScope == "current" ? currentCompanyName : "All Entities" },
                set: { selectedScope = $0 == currentCompanyName ? "current" : "all" }
            ))
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            List {
            Section {
                Button {
                    selectStandard(id: nil, name: "")
                } label: {
                    HStack {
                        Text("N/A")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.5))
                        Spacer()
                        if currentMethod.isEmpty {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.zifrGreen)
                        }
                    }
                }
                .listRowBackground(Color(hex: "#2C2C2E"))
            }

            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !exactMatchExists {
                Section {
                    Button {
                        selectCustom(searchText.trimmingCharacters(in: .whitespacesAndNewlines))
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: "#2070BD").opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color(hex: "#2070BD"))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Use \"\(searchText)\"")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white)
                                Text("Add as custom entry")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.white.opacity(0.4))
                            }
                        }
                    }
                    .listRowBackground(Color(hex: "#2C2C2E"))
                }
            }
            
            if !filteredCustomMethods.isEmpty {
                Section("Custom Entries") {
                    ForEach(filteredCustomMethods, id: \.self) { customMethod in
                        Button {
                            selectCustom(customMethod)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(0.05))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "text.quote")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                }
                                Text(customMethod)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white)
                                Spacer()
                                if currentMethod == customMethod {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.zifrGreen)
                                }
                            }
                        }
                        .listRowBackground(Color(hex: "#2C2C2E"))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteCustom(customMethod)
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            } label: {
                                Image(systemName: "trash")
                            }
                            .tint(.red)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                itemToEdit = customMethod
                                editedItemName = customMethod
                                showEditAlert = true
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
            
            if !filteredAccounts.isEmpty {
                Section("Bank Accounts") {
                    ForEach(filteredAccounts) { display in
                        let acc = display.account
                        let name = acc.name.isEmpty ? acc.type : acc.name
                        Button {
                            selectStandard(id: UUID(uuidString: acc.id), name: name)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(0.05))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "building.columns.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(name)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(.white)
                                        if !acc.last4.isEmpty {
                                            Text("•• \(acc.last4)")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(Color.white.opacity(0.5))
                                        }
                                    }
                                    HStack(spacing: 4) {
                                        Text(display.instName)
                                            .foregroundStyle(Color.white.opacity(0.5))
                                        Text("•")
                                            .foregroundStyle(Color.white.opacity(0.2))
                                        Text(acc.type)
                                            .foregroundStyle(Color.white.opacity(0.5))
                                    }
                                    .font(.system(size: 12))
                                }
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    if currentMethod == name {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(Color.zifrGreen)
                                    }
                                    
                                    let compId = display.companyId
                                    if let company = allCompanies.first(where: { $0.id == compId }) {
                                        Text(company.name.isEmpty ? "" : company.name.uppercased())
                                            .font(.system(size: 10, weight: .semibold))
                                            .tracking(0.3)
                                            .foregroundStyle(Color(hex: "#2070BD"))
                                            .lineLimit(2)
                                            .multilineTextAlignment(.trailing)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                        .listRowBackground(Color(hex: "#2C2C2E"))
                    }
                }
            }
            
            if !filteredCards.isEmpty {
                Section("Cards") {
                    ForEach(filteredCards) { card in
                        Button {
                            selectStandard(id: card.id, name: card.name)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(0.05))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "creditcard.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(card.name)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(.white)
                                        if !(card.last4 ?? "").isEmpty {
                                            Text("•• \(card.last4 ?? "")")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(Color.white.opacity(0.5))
                                        }
                                    }
                                    HStack(spacing: 4) {
                                        Text(card.institutionName ?? "")
                                            .foregroundStyle(Color.white.opacity(0.5))
                                        Text("•")
                                            .foregroundStyle(Color.white.opacity(0.2))
                                        Text(card.type)
                                            .foregroundStyle(Color.white.opacity(0.5))
                                        Text("•")
                                            .foregroundStyle(Color.white.opacity(0.2))
                                        Text(card.cardHolderType)
                                            .foregroundStyle(Color.white.opacity(0.5))
                                    }
                                    .font(.system(size: 12))
                                }
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    if currentMethod == card.name {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(Color.zifrGreen)
                                    }
                                    
                                    if let company = allCompanies.first(where: { $0.id == card.companyId }) {
                                        Text(company.name.isEmpty ? "" : company.name.uppercased())
                                            .font(.system(size: 10, weight: .semibold))
                                            .tracking(0.3)
                                            .foregroundStyle(Color(hex: "#2070BD"))
                                            .lineLimit(2)
                                            .multilineTextAlignment(.trailing)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                        .listRowBackground(Color(hex: "#2C2C2E"))
                    }
                }
            }
            }
            .scrollContentBackground(.hidden)
        }
        .background(Color(hex: "#1C1C1E"))
        .navigationTitle("Paid From")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Paid From")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(hex: "#C1AA78"))
            }
        }
        .alert("Edit Custom Entry", isPresented: $showEditAlert) {
            TextField("Entry Name", text: $editedItemName)
            Button("Cancel", role: .cancel) {
                itemToEdit = nil
            }
            Button("Save") {
                if let oldName = itemToEdit {
                    updateCustom(oldName: oldName, newName: editedItemName)
                }
                itemToEdit = nil
            }
        }
    }
}
