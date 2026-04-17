import SwiftUI

// MARK: - Edit Subscription Sheet

struct EditSubscriptionSheet: View {
    @Bindable var sub: Subscription
    let institutions: [Institution]
    @Bindable var vm: AppViewModel
    let isNew: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

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

    // User preference for form density
    @AppStorage("subscriptionDetailLevel") private var detailLevel: String = "Detailed"

    // Dirty-state tracking — fingerprint of initial values captured on appear
    @State private var initialFingerprint = ""

    private var currentFingerprint: String {
        "\(sub.name)|\(sub.website)|\(sub.pricingModel)|\(sub.status)|\(sub.cost)|" +
        "\(sub.billingCycle)|\(sub.nextRenewal)|\(sub.paymentMethod)|\(sub.renew)|" +
        "\(sub.loginId)|\(sub.password)|\(sub.twoFactorAuth)|\(sub.recoveryMethod)|\(sub.notes)"
    }

    private var isDirty: Bool {
        isNew || currentFingerprint != initialFingerprint
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
            get: { Int(sub.nextRenewal) ?? 1 },
            set: { sub.nextRenewal = "\($0)" }
        )
    }

    // Binding: Date ↔ "MMM d" string stored in nextRenewal (yearly)
    private var renewalDateBinding: Binding<Date> {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return Binding(
            get: { df.date(from: sub.nextRenewal) ?? Date() },
            set: { sub.nextRenewal = df.string(from: $0) }
        )
    }

    private var detailSliderBinding: Binding<Double> {
        Binding<Double>(
            get: {
                switch detailLevel {
                case "Essentials": return 0.0
                case "Less Detail": return 1.0
                default: return 2.0
                }
            },
            set: { val in
                let newState = val < 0.5 ? "Essentials" : (val < 1.5 ? "Less Detail" : "Detailed")
                if newState != detailLevel {
                    UISelectionFeedbackGenerator().selectionChanged()
                    detailLevel = newState
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {

                // MARK: – Top Controls
                VStack(spacing: 12) {
                    Picker("Pricing", selection: Binding(get: { sub.pricingModel }, set: { sub.pricingModel = $0 })) {
                        Text("Paid").tag("paid")
                        Text("Free").tag("free")
                    }
                    .pickerStyle(.segmented)
                    
                    Slider(value: detailSliderBinding, in: 0...2, step: 1) {
                        Text("Detail Level")
                    } minimumValueLabel: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .foregroundStyle(Color.white.opacity(0.3))
                            .font(.system(size: 13, weight: .bold))
                    } maximumValueLabel: {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(Color.white.opacity(0.3))
                            .font(.system(size: 13, weight: .bold))
                    }
                    .tint(.black)
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
                            
                            if detailLevel != "Essentials" {
                                ZifrField(
                                    label: "WEBSITE",
                                    placeholder: "shopify.com",
                                    text: Binding(get: { sub.website }, set: { sub.website = $0 }),
                                    keyboardType: .URL
                                )
                                .textInputAutocapitalization(.never)
                            }
                        }
                        
                        if detailLevel != "Essentials" {
                            HStack(spacing: 12) {
                                ZifrField(
                                    label: "LOGIN ID",
                                    placeholder: "username or email",
                                    text: Binding(get: { sub.loginId }, set: { sub.loginId = $0 })
                                )
                                .textInputAutocapitalization(.never)
                                
                                ZStack(alignment: .bottomTrailing) {
                                    ZifrField(
                                        label: "PASSWORD",
                                        placeholder: "••••••••",
                                        text: Binding(get: { sub.password }, set: { sub.password = $0 }),
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
                        }

                        // Status — inline single row (below login)
                        HStack(spacing: 12) {
                            Text("STATUS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.5))
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
                        .background(Color(hex: "#111111"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        // Thin divider
                        Rectangle()
                            .fill(Color.white.opacity(0.07))
                            .frame(height: 1)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)

                // MARK: – Billing (Paid only)
                if !sub.isFree {
                    Section {
                        VStack(spacing: 16) {

                            // Row 1: Cost + Auto Pay
                            HStack(spacing: 12) {
                                // Cost card
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("COST")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                    HStack(spacing: 4) {
                                        Text("$")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(Color.white.opacity(0.5))
                                        DoubleField(placeholder: "0.00", value: Binding(
                                            get: { sub.cost },
                                            set: { sub.cost = $0 }
                                        ))
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                    }
                                    .padding(.horizontal, 16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(height: 44)
                                    .background(Color(hex: "#111111"))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }

                                // Auto Pay card
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("AUTO PAY")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                    HStack {
                                        Text(autoPayBinding.wrappedValue ? "Enabled" : "Manual")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(autoPayBinding.wrappedValue ? Color.green : Color.white)
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
                                }
                            }

                            // Row 2: Billing Cycle — styled segmented control card
                            VStack(alignment: .leading, spacing: 4) {
                                Text("BILLING CYCLE")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                Picker("Cycle", selection: Binding(
                                    get: { sub.billingCycle },
                                    set: { newCycle in
                                        if newCycle != sub.billingCycle {
                                            sub.nextRenewal = newCycle == "Monthly" ? "1" : ""
                                        }
                                        sub.billingCycle = newCycle
                                    }
                                )) {
                                    Text("Monthly").tag("Monthly")
                                    Text("Yearly").tag("Yearly")
                                }
                                .pickerStyle(.segmented)
                            }

                            // Row 3: Renewal + Paid From (detail levels only)
                            if detailLevel != "Essentials" {
                                HStack(spacing: 12) {
                                    // Renewal card
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("RENEWS ON")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Color.white.opacity(0.5))
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
                                        } else {
                                            DatePicker("", selection: renewalDateBinding, displayedComponents: .date)
                                                .labelsHidden()
                                                .datePickerStyle(.compact)
                                                .padding(.leading, 10)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .frame(height: 44)
                                                .background(Color(hex: "#111111"))
                                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                        }
                                    }

                                    // Paid From card
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("PAID FROM")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Color.white.opacity(0.5))
                                        if payableAccounts.isEmpty {
                                            TextField("Card or account", text: Binding(
                                                get: { sub.paymentMethod },
                                                set: { sub.paymentMethod = $0 }
                                            ))
                                            .autocorrectionDisabled()
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(Color(hex: "#111111"))
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                        } else {
                                            Picker("", selection: Binding(
                                                get: { sub.paymentMethod },
                                                set: { sub.paymentMethod = $0 }
                                            )) {
                                                Text("None").tag("")
                                                ForEach(payableAccounts) { account in
                                                    Text(account.name.isEmpty ? account.type : account.name)
                                                        .tag(account.name.isEmpty ? account.type : account.name)
                                                }
                                            }
                                            .labelsHidden()
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(Color(hex: "#111111"))
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                        }
                                    }
                                }
                            }

                        }
                        .padding(.vertical, 4)
                    } header: { EmptyView() }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowSeparator(.hidden)
                }

                if detailLevel == "Detailed" {
                    // MARK: – Notes (before Security)
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NOTES")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.5))
                            TextField("Add a note…",
                                      text: Binding(get: { sub.notes }, set: { sub.notes = $0 }),
                                      axis: .vertical)
                                .lineLimit(3...6)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(hex: "#111111"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                    } header: { EmptyView() }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 8, trailing: 20))
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
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
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
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                    Picker("", selection: Binding(get: { sub.twoFactorAuth }, set: { sub.twoFactorAuth = $0 })) {
                                        ForEach(twoFAOptions, id: \.self) { opt in
                                            Text(opt).tag(opt)
                                        }
                                    }
                                    .labelsHidden()
                                    .padding(.leading, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(height: 44)
                                    .background(Color(hex: "#111111"))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                }

                                // Recovery TextField card
                                ZifrField(
                                    label: "RECOVERY",
                                    placeholder: "Phone, email…",
                                    text: Binding(get: { sub.recoveryMethod }, set: { sub.recoveryMethod = $0 })
                                )
                                .autocorrectionDisabled()
                            }
                        }
                        } header: { EmptyView() }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowSeparator(.hidden)
                    }

                    // MARK: – Supplemental Services
                    // Thin divider above SubServices
                    Section {
                        Rectangle()
                            .fill(Color.white.opacity(0.07))
                            .frame(height: 1)
                    } header: { EmptyView() }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                    .listRowSeparator(.hidden)

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
                }

                // MARK: – Danger Zone
                if !isNew {
                    Section {
                        Button(role: .destructive) {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete \(sub.name.isEmpty ? "Service" : sub.name)")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .listSectionSpacing(0)
            .onAppear {
                initialFingerprint = currentFingerprint
                if sub.twoFactorAuth != "None" || !sub.recoveryMethod.isEmpty {
                    showSecurity = true
                }
            }
            .navigationTitle(sub.name.isEmpty ? "New Service" : sub.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isNew { vm.deleteSub(sub, context: context) }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.saveSub(sub, context: context)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(isDirty ? .green : nil)
                    .disabled(sub.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog(
                "Delete \"\(sub.name.isEmpty ? "this service" : sub.name)\"?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Service", role: .destructive) {
                    vm.deleteSub(sub, context: context)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete this service and all associated data. This action cannot be undone.")
            }
            .interactiveDismissDisabled(isNew)
            .sheet(isPresented: $showSubServiceHUD) {
                SubServiceHUD(
                    draft: $subDraft,
                    isNew: subDraftIndex == nil,
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
                    onCancel: { showSubServiceHUD = false }
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
                    onCancel: { showEmailHUD = false }
                )
                .presentationDetents([.height(500)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
        }
    }
}

// MARK: – Supplemental Services Section

struct SubServicesSection: View {
    @Bindable var sub: Subscription
    let onAdd: () -> Void
    let onEdit: (Int, SubService) -> Void

    var body: some View {
        Section {
            VStack(spacing: 12) {
                // Add button
                Button { onAdd() } label: {
                    HStack {
                        Spacer()
                        Text("💾  Add Supplemental Service")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color(hex: "#1A1A1A"))
                        Spacer()
                    }
                    .frame(height: 40)
                    .background(Color(hex: "#F7F6F2"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

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
                                        .foregroundStyle(ss.autoPay == .auto ? Color.green.opacity(0.8) : Color.white.opacity(0.3))
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
                        .background(Color(hex: "#111111"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
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
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        } header: { EmptyView() }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
        .listRowSeparator(.hidden)
    }
}


// MARK: – Sub Service HUD

struct SubServiceHUD: View {
    @Binding var draft: SubService
    let isNew: Bool
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var initialDraft: SubService? = nil

    private var isDirty: Bool {
        guard let initial = initialDraft else { return isNew && !draft.name.isEmpty }
        return draft.name != initial.name ||
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

                        // Row 1: Name + Status
                        HStack(spacing: 12) {
                            ZifrField(
                                label: "NAME",
                                placeholder: "e.g. Premium Plan",
                                text: $draft.name
                            )
                            .autocorrectionDisabled()

                            // Status card
                            VStack(alignment: .leading, spacing: 4) {
                                Text("STATUS")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
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
                                .background(Color(hex: "#111111"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }
                        }

                        // Row 2: Cost + Billing Cycle
                        HStack(spacing: 12) {
                            // Cost card
                            VStack(alignment: .leading, spacing: 4) {
                                Text("COST")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
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
                                .background(Color(hex: "#111111"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }

                            // Billing Cycle card
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CYCLE")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                Picker("", selection: $draft.billingCycle) {
                                    Text("Monthly").tag(SubService.BillingCycle.monthly)
                                    Text("Yearly").tag(SubService.BillingCycle.yearly)
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
                            }
                        }

                        // Row 3: Auto Pay card (full width)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AUTO PAY")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.5))
                            HStack {
                                Text(draft.autoPay == .auto ? "Enabled" : "Manual")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(draft.autoPay == .auto ? Color.green : Color.white)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { draft.autoPay == .auto },
                                    set: { draft.autoPay = $0 ? .auto : .manual }
                                ))
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

                        // Row 4: Purpose (full width)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PURPOSE")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.5))
                            TextField("What is this service for?",
                                      text: $draft.purpose,
                                      axis: .vertical)
                                .lineLimit(2...4)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
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
            .listSectionSpacing(0)
            .navigationTitle(draft.name.isEmpty ? "New Service" : draft.name)
            .navigationBarTitleDisplayMode(.inline)
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
            .onAppear { initialDraft = draft }
        }
    }
}

// MARK: – Linked Emails Section

struct LinkedEmailsSection: View {
    @Bindable var sub: Subscription
    let onAdd: () -> Void
    let onEdit: (Int, LinkedEmail) -> Void

    var body: some View {
        Section {
            VStack(spacing: 12) {
                // Add button
                Button { onAdd() } label: {
                    HStack {
                        Spacer()
                        Text("📨  Add Linked Email")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color(hex: "#1A1A1A"))
                        Spacer()
                    }
                    .frame(height: 40)
                    .background(Color(hex: "#F7F6F2"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                ForEach(sub.linkedEmails.indices, id: \.self) { i in
                    let em = sub.linkedEmails[i]
                    Button { onEdit(i, em) } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
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
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.2))
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
                                var emails = sub.linkedEmails
                                emails.remove(at: i)
                                sub.linkedEmails = emails
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        } header: { EmptyView() }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
        .listRowSeparator(.hidden)
    }
}

// MARK: – Linked Email HUD

struct LinkedEmailHUD: View {
    @Binding var draft: LinkedEmail
    let isNew: Bool
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var initialDraft: LinkedEmail? = nil

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
            set: { draft.notes = $0.components(separatedBy: "\n").filter { !$0.isEmpty } }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {

                        // Row 1: Address (full width)
                        ZifrField(
                            label: "EMAIL ADDRESS",
                            placeholder: "name@example.com",
                            text: $draft.email
                        )
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                        // Row 2: Provider + Used For
                        HStack(spacing: 12) {
                            ZifrField(
                                label: "PROVIDER",
                                placeholder: "Gmail, iCloud…",
                                text: $draft.provider
                            )
                            .autocorrectionDisabled()

                            ZifrField(
                                label: "USED FOR",
                                placeholder: "Billing, Admin…",
                                text: $draft.usedFor
                            )
                            .autocorrectionDisabled()
                        }

                        // Row 3: Access Method + Used In
                        HStack(spacing: 12) {
                            ZifrField(
                                label: "ACCESS METHOD",
                                placeholder: "Google SSO, Password…",
                                text: $draft.accessMethod
                            )
                            .autocorrectionDisabled()

                            ZifrField(
                                label: "USED IN",
                                placeholder: "Tag…",
                                text: $draft.usedIn
                            )
                            .autocorrectionDisabled()
                        }

                        // Row 4: Notes (full width)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NOTES")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.5))
                            TextField("Add notes…", text: notesBinding, axis: .vertical)
                                .lineLimit(2...4)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
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
            .listSectionSpacing(0)
            .navigationTitle(draft.email.isEmpty ? "New Email" : draft.email)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
