import SwiftUI
import SwiftData

// MARK: - Edit Subscription Sheet

struct EditSubscriptionSheet: View {
    @Bindable var sub: Subscription
    let institutions: [Institution]
    let cards: [FinancialCard]
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


    @State private var showPaymentPicker = false

    // User preference for form density
    @AppStorage("subscriptionDetailLevel") private var detailLevel: String = "Detailed"

    struct Snapshot: Equatable {
        var name, website, pricingModel, status, billingCycle, nextRenewal, paymentMethod, renew, loginId, password, twoFactorAuth, recoveryMethod, notes: String
        var cost: Double
    }
    
    @State private var snapshot: Snapshot?

    private var currentSnapshot: Snapshot {
        Snapshot(
            name: sub.name, website: sub.website, pricingModel: sub.pricingModel, status: sub.status,
            billingCycle: sub.billingCycle, nextRenewal: sub.nextRenewal, paymentMethod: sub.paymentMethod,
            renew: sub.renew, loginId: sub.loginId, password: sub.password,
            twoFactorAuth: sub.twoFactorAuth, recoveryMethod: sub.recoveryMethod, notes: sub.notes,
            cost: sub.cost
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
                default: return 1.0
                }
            },
            set: { val in
                let newState = val < 0.5 ? "Essentials" : "Detailed"
                if newState != detailLevel {
                    UISelectionFeedbackGenerator().selectionChanged()
                    detailLevel = newState
                }
            }
        )
    }




    private var costCard: some View {
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
                    set: { (val: Double) in sub.cost = val }
                ))
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
    }

    private var autoPayCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("AUTO PAY")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
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
            .background(Color(hex: "#111111"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("STATUS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
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
            .background(Color(hex: "#111111"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    private var billingCycleCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("BILLING CYCLE")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            Picker("Cycle", selection: Binding(
                get: { sub.billingCycle },
                set: { (newCycle: String) in
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
    }

    @ViewBuilder
    private var renewalCard: some View {
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
    }

    private var paidFromCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PAID FROM")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            
            Button {
                showPaymentPicker = true
            } label: {
                HStack {
                    Text(sub.paymentMethod.isEmpty ? "None" : sub.paymentMethod)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(sub.paymentMethod.isEmpty ? Color.white.opacity(0.4) : .white)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Color(hex: "#111111"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(.borderless)
        }
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
                    
                    Slider(value: detailSliderBinding, in: 0...1, step: 1) {
                        Text("Detail Level")
                    } minimumValueLabel: {
                        Text("ESSENTIALS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.2)) // Darker font
                    } maximumValueLabel: {
                        Text("ALL DATA")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.2)) // Darker font
                    }
                    .onAppear {
                        // Liquid glass effect for thumb
                        UISlider.appearance().thumbTintColor = UIColor(white: 1.0, alpha: 0.15)
                        UISlider.appearance().minimumTrackTintColor = .black
                        UISlider.appearance().maximumTrackTintColor = .black
                    }
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .listRowBackground(Color.clear)

                // MARK: – Identity
                Section {
                     VStack(spacing: 16) {
                        if detailLevel != "Essentials" {
                            HStack(spacing: 12) {
                                ZifrField(
                                    label: "SERVICE NAME",
                                    placeholder: "e.g. Shopify",
                                    text: Binding(get: { sub.name }, set: { sub.name = $0 })
                                )
                                ZifrField(
                                    label: "WEBSITE",
                                    placeholder: "shopify.com",
                                    text: Binding(get: { sub.website }, set: { sub.website = $0 }),
                                    keyboardType: .URL
                                )
                                .textInputAutocapitalization(.never)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            ZifrField(
                                label: "LOGIN ID",
                                placeholder: "username or email",
                                text: Binding(get: { sub.loginId }, set: { sub.loginId = $0 }),
                                keyboardType: .emailAddress
                            )
                            
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
                    .padding(.vertical, detailLevel == "Essentials" ? 2 : 4)
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: detailLevel == "Essentials" ? 4 : 8, leading: 20, bottom: detailLevel == "Essentials" ? 4 : 8, trailing: 20))
                .listRowSeparator(.hidden)

                // MARK: – Billing (Paid only)
                if !sub.isFree {
                    if detailLevel != "Essentials" {
                        Section {
                            Rectangle()
                                .fill(Color.white.opacity(0.07))
                                .frame(height: 1)
                        } header: { EmptyView() }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                        .listRowSeparator(.hidden)
                    }
                    Section {
                        VStack(spacing: detailLevel == "Essentials" ? 8 : 16) {
                            if detailLevel == "Essentials" {
                                HStack(spacing: 12) {
                                    costCard
                                    paidFromCard
                                }
                            } else {
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
                        }
                        .padding(.vertical, detailLevel == "Essentials" ? 2 : 4)
                    } header: { EmptyView() }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: detailLevel == "Essentials" ? 4 : 8, leading: 20, bottom: detailLevel == "Essentials" ? 4 : 8, trailing: 20))
                    .listRowSeparator(.hidden)
                }

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
                    .listRowInsets(EdgeInsets(top: detailLevel == "Essentials" ? 2 : 4, leading: 20, bottom: detailLevel == "Essentials" ? 4 : 8, trailing: 20))
                    .listRowSeparator(.hidden)

                if detailLevel == "Detailed" {
                    Section {
                        Rectangle()
                            .fill(Color.white.opacity(0.07))
                            .frame(height: 1)
                    } header: { EmptyView() }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 2.5, leading: 20, bottom: 2.5, trailing: 20))
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
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
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
                        .listRowInsets(EdgeInsets(top: 2.5, leading: 20, bottom: 2.5, trailing: 20))
                        .listRowSeparator(.hidden)
                    }
                } // End of detailLevel == "Detailed"

                    // MARK: – Supplemental Services
                    // Thin divider above SubServices
                    Section {
                        Rectangle()
                            .fill(Color.white.opacity(0.07))
                            .frame(height: 1)
                    } header: { EmptyView() }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 2.5, leading: 20, bottom: 2.5, trailing: 20))
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
                    Section {
                        Rectangle()
                            .fill(Color.white.opacity(0.07))
                            .frame(height: 1)
                    } header: { EmptyView() }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                    .listRowSeparator(.hidden)

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
                                vm.deleteSub(sub, context: context)
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
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#171717"))
            .listSectionSpacing(0)
            .onAppear {
                snapshot = currentSnapshot
                if sub.twoFactorAuth != "None" || !sub.recoveryMethod.isEmpty {
                    showSecurity = true
                }
            }
            .navigationTitle(sub.name.isEmpty ? "New Service" : sub.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showPaymentPicker) {
                PaymentMethodPickerView(
                    currentMethod: sub.paymentMethod,
                    institutions: institutions,
                    cards: cards,
                    onSelect: { sub.paymentMethod = $0 }
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isNew { 
                            vm.deleteSub(sub, context: context) 
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
                        }
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
            .interactiveDismissDisabled(isNew)
            .sheet(isPresented: $showSubServiceHUD) {
                SubServiceHUD(
                    draft: $subDraft,
                    isNew: subDraftIndex == nil,
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
        }
    }
}

// MARK: – Supplemental Services Section

struct SubServicesSection: View {
    @AppStorage("subscriptionDetailLevel") private var detailLevel: String = "Detailed"
    @Bindable var sub: Subscription
    let onAdd: () -> Void
    let onEdit: (Int, SubService) -> Void



    var body: some View {
        Section {
            if detailLevel != "Essentials" {
                Button { onAdd() } label: {
                    HStack {
                            Spacer()
                            Text("💾  Add Supplemental Service")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color(hex: "#A2A2A2"))
                            Spacer()
                        }
                        .frame(height: 40)
                        .background(Color(hex: "#222E2F"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

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
                            Image(systemName: "trash")
                        }
                        .tint(.red)
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
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                
                                Button {
                                    showPaymentPicker = true
                                } label: {
                                    HStack {
                                        Text(draft.paymentMethod.isEmpty ? "None" : draft.paymentMethod)
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
                                    .background(Color(hex: "#111111"))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
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

                        // Row 3: Auto Pay + Status
                        HStack(spacing: 12) {
                            // Auto Pay card
                            VStack(alignment: .leading, spacing: 4) {
                                Text("AUTO PAY")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
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
                                .background(Color(hex: "#111111"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }

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
            .sheet(isPresented: $showPaymentPicker) {
                PaymentMethodPickerView(
                    currentMethod: draft.paymentMethod,
                    institutions: institutions,
                    cards: cards,
                    onSelect: { draft.paymentMethod = $0 }
                )
                .presentationDetents([.height(550)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
        }
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

    @AppStorage("subscriptionDetailLevel") private var detailLevel: String = "Detailed"

    private var computedServices: [UsedInEmailService] {
        let normalizedEmail = em.email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty else { return [] }

        var results: [UsedInEmailService] = []
        var seen = Set<String>()

        for sub in allSubscriptions {
            let isPrimary = sub.loginId.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedEmail
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
                                        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
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
            .background(Color(hex: "#111111"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: – Linked Emails Section

struct LinkedEmailsSection: View {
    @AppStorage("subscriptionDetailLevel") private var detailLevel: String = "Detailed"
    @Bindable var sub: Subscription
    let onAdd: () -> Void
    let onEdit: (Int, LinkedEmail) -> Void

    @Query private var allSubscriptions: [Subscription]



    var body: some View {
        Section {
            if detailLevel != "Essentials" {
                Button { onAdd() } label: {
                    HStack {
                            Spacer()
                            Text("📨  Add Linked Email")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color(hex: "#A2A2A2"))
                            Spacer()
                        }
                        .frame(height: 40)
                        .background(Color(hex: "#222E2F"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

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
    var onDelete: (() -> Void)? = nil

    @State private var initialDraft: LinkedEmail? = nil
    @Query private var allSubscriptions: [Subscription]

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
            let isPrimary = sub.loginId.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedEmail
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
            set: { draft.notes = $0.components(separatedBy: "\n").filter { !$0.isEmpty } }
        )
    }

    private var usedInCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("USED IN")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            
            if computedServices.isEmpty && legacyTags.isEmpty {
                HStack {
                    Text("Auto-generates when linked to services...")
                        .font(.system(size: 11, weight: .medium, design: .serif).italic())
                        .foregroundStyle(Color.white.opacity(0.3))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Color(hex: "#111111"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
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
                                .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 44)
                .background(Color(hex: "#111111"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
        }
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
                            text: $draft.email,
                            keyboardType: .emailAddress
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

// MARK: - Payment Method Picker View

struct PaymentMethodPickerView: View {
    let currentMethod: String
    let institutions: [Institution]
    let cards: [FinancialCard]
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @AppStorage("userCustomPaymentMethods") private var storedCustomMethods: String = ""

    @State private var itemToEdit: String? = nil
    @State private var editedItemName: String = ""
    @State private var showEditAlert = false

    struct AccountDisplay: Identifiable {
        let id = UUID()
        let instName: String
        let account: InstitutionAccount
    }

    var accountDisplays: [AccountDisplay] {
        institutions.flatMap { inst in
            inst.accounts.map { AccountDisplay(instName: inst.name, account: $0) }
        }
    }

    var filteredAccounts: [AccountDisplay] {
        if searchText.isEmpty { return accountDisplays }
        return accountDisplays.filter { ($0.account.name + $0.account.type + $0.account.last4 + $0.instName).localizedCaseInsensitiveContains(searchText) }
    }

    var filteredCards: [FinancialCard] {
        if searchText.isEmpty { return cards }
        return cards.filter { ($0.name + $0.type + $0.last4 + $0.institutionName).localizedCaseInsensitiveContains(searchText) }
    }
    
    var allCustomMethods: [String] {
        let stored = storedCustomMethods.split(separator: ",").map(String.init)
        let predefinedAccounts = Set(accountDisplays.map { $0.account.name.isEmpty ? $0.account.type : $0.account.name })
        let predefinedCards = Set(cards.map(\.name))
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
        if cards.contains(where: { $0.name.lowercased() == q }) { return true }
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
        onSelect(method)
        dismiss()
    }

    private func selectStandard(_ method: String) {
        onSelect(method)
        dismiss()
    }

    private func deleteCustom(_ method: String) {
        var methods = storedCustomMethods.split(separator: ",").map(String.init)
        if let idx = methods.firstIndex(of: method) {
            methods.remove(at: idx)
            storedCustomMethods = methods.joined(separator: ",")
            if currentMethod == method {
                onSelect("")
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
                onSelect(trimmedNewName)
            }
        }
    }

    var body: some View {
        List {
            Section {
                Button {
                    selectStandard("")
                } label: {
                    HStack {
                        Text("None")
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
                .listRowBackground(Color(hex: "#111111"))
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
                    .listRowBackground(Color(hex: "#111111"))
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
                        .listRowBackground(Color(hex: "#111111"))
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
                            selectStandard(name)
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
                                if currentMethod == name {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.zifrGreen)
                                }
                            }
                        }
                        .listRowBackground(Color(hex: "#111111"))
                    }
                }
            }
            
            if !filteredCards.isEmpty {
                Section("Cards") {
                    ForEach(filteredCards) { card in
                        Button {
                            selectStandard(card.name)
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
                                        if !card.last4.isEmpty {
                                            Text("•• \(card.last4)")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(Color.white.opacity(0.5))
                                        }
                                    }
                                    HStack(spacing: 4) {
                                        Text(card.institutionName)
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
                                if currentMethod == card.name {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.zifrGreen)
                                }
                            }
                        }
                        .listRowBackground(Color(hex: "#111111"))
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(hex: "#171717"))
        .navigationTitle("Paid From")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search or enter custom")
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
