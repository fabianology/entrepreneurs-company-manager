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

    // Sub-service HUD state — lifted here to avoid nested-sheet dismissal bug
    @State private var showSubServiceHUD = false
    @State private var subDraft = SubService()
    @State private var subDraftIndex: Int? = nil

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

    var body: some View {
        NavigationStack {
            Form {

                // MARK: – Paid / Free toggle (top-level segmented control)
                Picker("Pricing", selection: Binding(get: { sub.pricingModel }, set: { sub.pricingModel = $0 })) {
                    Text("Paid").tag("paid")
                    Text("Free").tag("free")
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .listRowBackground(Color.clear)

                // MARK: – Identity
                Section {
                    LabeledContent("Name") {
                        TextField("Shopify", text: Binding(get: { sub.name }, set: { sub.name = $0 }))
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                    }
                    LabeledContent("Website") {
                        TextField("shopify.com", text: Binding(get: { sub.website }, set: { sub.website = $0 }))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    LabeledContent("Login ID") {
                        TextField("username or email", text: Binding(get: { sub.loginId }, set: { sub.loginId = $0 }))
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    LabeledContent("Password") {
                        HStack(spacing: 8) {
                            Group {
                                if showPassword {
                                    TextField("••••••••", text: Binding(get: { sub.password }, set: { sub.password = $0 }))
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                } else {
                                    SecureField("••••••••", text: Binding(get: { sub.password }, set: { sub.password = $0 }))
                                }
                            }
                            .multilineTextAlignment(.trailing)
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                                    .font(.footnote)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Picker("Status", selection: Binding(get: { sub.status }, set: { sub.status = $0 })) {
                        Text("Active").tag("Active")
                        Text("Paused").tag("Paused")
                    }
                } header: {
                    Text("Service")
                }

                // MARK: – Billing (Paid only)
                if !sub.isFree {
                    Section {
                        LabeledContent("Cost") {
                            HStack(spacing: 2) {
                                Text("$")
                                    .foregroundStyle(.secondary)
                                TextField("0.00", value: Binding(
                                    get: { sub.cost },
                                    set: { sub.cost = $0 }
                                ), format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            }
                        }
                        Picker("Cycle", selection: Binding(
                            get: { sub.billingCycle },
                            set: { newCycle in
                                // Reset renewal when switching cycles
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

                        // Renewal — adapts to cycle
                        if sub.billingCycle == "Monthly" {
                            Picker("Renews On", selection: dayBinding) {
                                ForEach(1...31, id: \.self) { day in
                                    Text(ordinal(day)).tag(day)
                                }
                            }
                        } else {
                            DatePicker(
                                "Renewal Date",
                                selection: renewalDateBinding,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                        }

                        // Paid From — Picker over known accounts, fallback to free text
                        if payableAccounts.isEmpty {
                            LabeledContent("Paid From") {
                                TextField("Card or account", text: Binding(get: { sub.paymentMethod }, set: { sub.paymentMethod = $0 }))
                                    .multilineTextAlignment(.trailing)
                                    .autocorrectionDisabled()
                            }
                        } else {
                            Picker("Paid From", selection: Binding(get: { sub.paymentMethod }, set: { sub.paymentMethod = $0 })) {
                                Text("None").tag("")
                                ForEach(payableAccounts) { account in
                                    Text(account.name.isEmpty ? account.type : account.name)
                                        .tag(account.name.isEmpty ? account.type : account.name)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        Toggle("Auto Pay", isOn: autoPayBinding)
                            .tint(.green)
                    } header: {
                        Text("Billing")
                    }
                }


                // MARK: – Security & Recovery
                Section {
                    Picker("Two-Factor Auth", selection: Binding(get: { sub.twoFactorAuth }, set: { sub.twoFactorAuth = $0 })) {
                        ForEach(twoFAOptions, id: \.self) { opt in
                            Text(opt).tag(opt)
                        }
                    }
                    .pickerStyle(.menu)
                    LabeledContent("Recovery") {
                        TextField("Phone, email…", text: Binding(get: { sub.recoveryMethod }, set: { sub.recoveryMethod = $0 }))
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                    }
                } header: {
                    Text("Security & Recovery")
                }

                // MARK: – Notes
                Section {
                    ZStack(alignment: .topLeading) {
                        // 3 ruled lines, each at 90 % of the row width
                        Canvas { ctx, size in
                            let rowH = size.height / 3
                            for i in 1...3 {
                                let y = rowH * CGFloat(i) - 0.5
                                var path = Path()
                                path.move(to: CGPoint(x: size.width * 0.05, y: y))
                                path.addLine(to: CGPoint(x: size.width * 0.95, y: y))
                                ctx.stroke(path,
                                           with: .color(.secondary.opacity(0.25)),
                                           lineWidth: 0.5)
                            }
                        }
                        .allowsHitTesting(false)

                        TextField("Add a note…",
                                  text: Binding(get: { sub.notes }, set: { sub.notes = $0 }),
                                  axis: .vertical)
                            .lineLimit(3)
                            .font(.body)
                    }
                    .frame(height: 84) // 3 rows × 28 pt
                } header: {
                    Text("Notes")
                }

                // MARK: – Supplemental Services
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
                LinkedEmailsSection(sub: sub)

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
            .onAppear { initialFingerprint = currentFingerprint }
            .navigationTitle(isNew ? "New Service" : "Edit Service")
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
                .presentationDetents([.height(400)])
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
            Button { onAdd() } label: {
                HStack {
                    Spacer()
                    Text("💾  Add Supplemental Service")
                        .font(.body)
                    Spacer()
                }
            }

            ForEach(sub.subServices.indices, id: \.self) { i in
                let ss = sub.subServices[i]
                Button {
                    onEdit(i, ss)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(ss.name.isEmpty ? "Unnamed Service" : ss.name)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                            HStack(spacing: 6) {
                                if ss.cost > 0 {
                                    Text("$\(ss.cost, specifier: "%.2f")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("·").foregroundStyle(.tertiary).font(.caption)
                                }
                                Text(ss.billingCycle.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("·").foregroundStyle(.tertiary).font(.caption)
                                Text(ss.autoPay == .auto ? "Auto Pay" : "Manual")
                                    .font(.caption)
                                    .foregroundStyle(ss.autoPay == .auto ? Color.green : Color.secondary)
                            }
                        }
                        Spacer()
                        Text(ss.status.rawValue)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(ss.status == .active
                                    ? Color.green.opacity(0.15)
                                    : Color.orange.opacity(0.15))
                            )
                            .foregroundStyle(ss.status == .active ? .green : .orange)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
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
                    // Name + Status toggle on the same row
                    HStack(spacing: 12) {
                        Text("Name")
                            .foregroundStyle(.secondary)
                        TextField("e.g. Premium Plan", text: $draft.name)
                            .autocorrectionDisabled()
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(draft.status == .active ? "Active" : "Paused")
                                .font(.caption)
                                .foregroundStyle(draft.status == .active ? .green : .red)
                            Toggle("", isOn: Binding(
                                get: { draft.status == .active },
                                set: { draft.status = $0 ? .active : .paused }
                            ))
                            .labelsHidden()
                            .tint(draft.status == .active ? .green : .red)
                        }
                    }

                    // Cost + Cycle in one row
                    HStack(spacing: 12) {
                        HStack(spacing: 2) {
                            Text("$")
                                .foregroundStyle(.secondary)
                            TextField("0.00", value: $draft.cost, format: .number)
                                .keyboardType(.decimalPad)
                                .frame(width: 64)
                        }
                        Divider()
                        Picker("", selection: $draft.billingCycle) {
                            Text("Monthly").tag(SubService.BillingCycle.monthly)
                            Text("Yearly").tag(SubService.BillingCycle.yearly)
                        }
                        .pickerStyle(.segmented)
                    }

                    // Auto Pay — toggle, green = on
                    Toggle(isOn: Binding(
                        get: { draft.autoPay == .auto },
                        set: { draft.autoPay = $0 ? .auto : .manual }
                    )) {
                        HStack(spacing: 4) {
                            Text("Auto Pay")
                            Text(draft.autoPay == .auto ? "· On" : "· Off")
                                .font(.caption)
                                .foregroundStyle(draft.autoPay == .auto ? Color.green : Color.secondary)
                        }
                    }
                    .tint(.green)
                }

                Section {
                    TextField("What is this service for?",
                              text: $draft.purpose,
                              axis: .vertical)
                        .lineLimit(3)
                        .font(.body)
                } header: {
                    Text("Purpose")
                }
            }
            .navigationTitle(isNew ? "New Service" : "Edit Service")
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

    var body: some View {
        Section {
            ForEach($sub.linkedEmails) { $email in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        TextField("Email address", text: $email.email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.body.weight(.medium))
                        Spacer()
                        Button(role: .destructive) {
                            withAnimation {
                                sub.linkedEmails.removeAll { $0.id == email.id }
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                    TextField("Purpose (e.g. Billing, Admin)", text: $email.usedFor)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("Access method (e.g. Google SSO)", text: $email.accessMethod)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

            }

            Button {
                withAnimation {
                    var emails = sub.linkedEmails
                    emails.append(LinkedEmail())
                    sub.linkedEmails = emails
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            } label: {
                HStack {
                    Spacer()
                    Text("📨  Add Linked Email")
                        .font(.body)
                    Spacer()
                }
            }
        } header: {
            Text("Linked Emails")
        }
    }
}
