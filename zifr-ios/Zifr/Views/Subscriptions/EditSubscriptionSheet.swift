import SwiftUI

// MARK: - Edit Subscription Sheet (mirrors CiFr pageSheet modal exactly)
struct EditSubscriptionSheet: View {
    @Bindable var sub: Subscription
    let institutions: [Institution]
    @Bindable var vm: AppViewModel
    let isNew: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showDelete = false
    @State private var showSecurity = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#1C1C1E").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // ── Free / Paid Toggle — gold pill, matches CiFr ──────
                        HStack(spacing: 0) {
                            ForEach(["free", "paid"], id: \.self) { model in
                                Button {
                                    sub.pricingModel = model
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Text(model == "free" ? "Free" : "Paid")
                                        .font(.system(size: 9, weight: .black))
                                        .textCase(.uppercase)
                                        .tracking(2)
                                        .foregroundStyle(sub.pricingModel == model ? .black : Color.white.opacity(0.4))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 24)
                                        .background(
                                            RoundedRectangle(cornerRadius: 100)
                                                .fill(sub.pricingModel == model ? Color.zifrGold : Color.clear)
                                        )
                                        .animation(.spring(response: 0.25), value: sub.pricingModel)
                                }
                            }
                        }
                        .padding(4)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.05), lineWidth: 1))
                        .frame(minWidth: 200)
                        .frame(maxWidth: .infinity, alignment: .center)

                        // ── Name + Website ────────────────────────────────────
                        HStack(spacing: 12) {
                            ZifrField(label: "Subscription", placeholder: "Shopify",
                                      text: Binding(get: { sub.name }, set: { sub.name = $0 }))
                            ZifrField(label: "Website", placeholder: "shopify.com",
                                      text: Binding(get: { sub.website }, set: { sub.website = $0 }),
                                      keyboardType: .URL)
                        }

                        // ── Cost + Due On + Cycle (paid only) ─────────────────
                        if !sub.isFree {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Cost")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                    HStack(spacing: 0) {
                                        Text("$")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.white.opacity(0.3))
                                            .padding(.leading, 12)
                                        TextField("0.00", value: Binding(
                                            get: { sub.cost },
                                            set: { sub.cost = $0 }
                                        ), format: .number)
                                        .keyboardType(.decimalPad)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.vertical, 14)
                                        .padding(.trailing, 12)
                                    }
                                    .background(Color(hex: "#111111"))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Due On")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                    ZifrField(label: "", placeholder: "15th", text: Binding(
                                        get: { sub.nextRenewal }, set: { sub.nextRenewal = $0 }
                                    ))
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Cycle")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                    HStack(spacing: 0) {
                                        ForEach(["Monthly", "Yearly"], id: \.self) { c in
                                            Button {
                                                sub.billingCycle = c
                                            } label: {
                                                Text(c.prefix(2))
                                                    .font(.system(size: 9, weight: .black))
                                                    .textCase(.uppercase)
                                                    .tracking(1)
                                                    .foregroundStyle(sub.billingCycle == c ? Color.zifrGold : Color.white.opacity(0.4))
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 14)
                                                    .background(sub.billingCycle == c ? Color.zifrGold.opacity(0.1) : Color.clear)
                                            }
                                        }
                                    }
                                    .background(Color.black.opacity(0.4))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.05), lineWidth: 1))
                                }
                            }
                        }

                        // ── Login + Password ──────────────────────────────────
                        HStack(spacing: 12) {
                            ZifrField(label: "Login ID", placeholder: "admin",
                                      text: Binding(get: { sub.loginId }, set: { sub.loginId = $0 }))
                            ZifrField(label: "Password", placeholder: "••••••••",
                                      text: Binding(get: { sub.password }, set: { sub.password = $0 }),
                                      isSecure: true)
                        }

                        // ── Active / Paused — gold→red shift like CiFr ────────
                        HStack(spacing: 0) {
                            ForEach(["Active", "Paused"], id: \.self) { s in
                                Button {
                                    sub.status = s
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Text(s)
                                        .font(.system(size: 9, weight: .black))
                                        .textCase(.uppercase)
                                        .tracking(2)
                                        .foregroundStyle(sub.status == s ? (s == "Paused" ? .white : .black) : Color.white.opacity(0.4))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(sub.status == s ? (s == "Paused" ? Color.red : Color.zifrGold) : Color.clear)
                                                .padding(4)
                                        )
                                        .animation(.spring(response: 0.25), value: sub.status)
                                }
                            }
                        }
                        .background(Color(hex: "#242426"))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05), lineWidth: 1))
                        .frame(width: 256)
                        .frame(maxWidth: .infinity, alignment: .center)

                        // ── Paid From + Auto Pay (paid only) ─────────────────
                        if !sub.isFree {
                            HStack(spacing: 12) {
                                ZifrField(label: "Paid From", placeholder: "Linked card...",
                                          text: Binding(get: { sub.paymentMethod }, set: { sub.paymentMethod = $0 }))

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Auto Pay")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                    HStack(spacing: 0) {
                                        ForEach([("Auto", "On"), ("Manual", "Off")], id: \.0) { val, lbl in
                                            Button {
                                                sub.renew = val
                                            } label: {
                                                Text(lbl)
                                                    .font(.system(size: 9, weight: .black))
                                                    .textCase(.uppercase)
                                                    .tracking(2)
                                                    .foregroundStyle(sub.renew == val ?
                                                        (val == "Auto" ? .black : .white) : Color.white.opacity(0.3))
                                                    .frame(maxWidth: .infinity)
                                                    .frame(height: 42)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 6)
                                                            .fill(sub.renew == val ? (val == "Auto" ? Color.zifrGold : Color.white.opacity(0.08)) : Color.clear)
                                                            .padding(4)
                                                    )
                                            }
                                        }
                                    }
                                    .background(Color.black.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.05), lineWidth: 1))
                                }
                            }
                        }

                        // ── Notes ─────────────────────────────────────────────
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notes")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.5))
                            TextEditor(text: Binding(get: { sub.notes }, set: { sub.notes = $0 }))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 80)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(hex: "#111111"))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }

                        // ── Security & Recovery accordion ─────────────────────
                        VStack(spacing: 0) {
                            Button {
                                withAnimation { showSecurity.toggle() }
                            } label: {
                                HStack {
                                    Text("Security & Recovery")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                    Spacer()
                                    Image(systemName: showSecurity ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.white.opacity(0.3))
                                }
                            }

                            if showSecurity {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("2FA Method")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.5))
                                        VStack(spacing: 0) {
                                            ForEach(["None", "Authenticator", "SMS", "Email", "Hardware Key", "Backup Codes"], id: \.self) { opt in
                                                Button {
                                                    sub.twoFactorAuth = opt
                                                } label: {
                                                    HStack(spacing: 8) {
                                                        Circle()
                                                            .fill(sub.twoFactorAuth == opt ? Color.zifrGold : Color.white.opacity(0.1))
                                                            .frame(width: 8, height: 8)
                                                        Text(opt)
                                                            .font(.system(size: 13, weight: .medium))
                                                            .foregroundStyle(sub.twoFactorAuth == opt ? Color.zifrGold : Color.white.opacity(0.5))
                                                        Spacer()
                                                    }
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 10)
                                                    .background(sub.twoFactorAuth == opt ? Color.zifrGold.opacity(0.1) : Color.clear)
                                                }
                                            }
                                        }
                                        .background(Color.black.opacity(0.2))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.05), lineWidth: 1))
                                    }
                                    ZifrField(label: "Recovery", placeholder: "Phone, email...",
                                              text: Binding(get: { sub.recoveryMethod }, set: { sub.recoveryMethod = $0 }))
                                }
                                .padding(.top, 16)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(.top, 4)

                        Divider().background(Color.white.opacity(0.05))

                        // ── Sub Services ──────────────────────────────────────
                        SubServicesEditor(sub: sub)

                        // ── Linked Emails ─────────────────────────────────────
                        LinkedEmailsEditor(sub: sub)

                        // ── Delete ────────────────────────────────────────────
                        if !isNew {
                            if showDelete {
                                HStack(spacing: 20) {
                                    Text("Delete this service?")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.red)
                                    Button("Yes") {
                                        vm.deleteSub(sub, context: context)
                                        dismiss()
                                    }
                                    .font(.system(size: 12, weight: .black)).foregroundStyle(.red)
                                    Button("No") { showDelete = false }
                                        .font(.system(size: 12, weight: .bold)).foregroundStyle(Color.white.opacity(0.4))
                                }
                                .padding(14)
                                .background(Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.3), lineWidth: 1))
                            } else {
                                Button {
                                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                    showDelete = true
                                } label: {
                                    HStack {
                                        Spacer()
                                        Text("Delete \(sub.name.isEmpty ? "Service" : sub.name)")
                                            .font(.system(size: 11, weight: .bold))
                                            .textCase(.uppercase)
                                            .tracking(2)
                                            .foregroundStyle(Color.red.opacity(0.7))
                                        Spacer()
                                    }
                                    .padding(.vertical, 16)
                                    .background(Color.red.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 24))
                                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.red.opacity(0.3), lineWidth: 1))
                                }
                            }
                        }
                    }
                    .padding(24)
                    .padding(.bottom, 40)
                }
            }
            // ── Navigation header — CiFr uppercase title + × close ───────
            .navigationTitle(isNew ? "NEW SERVICE" : "EDIT SERVICE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#1C1C1E"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if isNew { vm.deleteSub(sub, context: context) }
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.saveSub(sub, context: context)
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - Sub Services Editor
struct SubServicesEditor: View {
    @Bindable var sub: Subscription

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Supplemental Services")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
                Spacer()
                Button {
                    var services = sub.subServices
                    services.append(SubService())
                    sub.subServices = services
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.zifrGold)
                }
            }

            ForEach($sub.subServices) { $ss in
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        TextField("Service name", text: $ss.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            sub.subServices.removeAll { $0.id == ss.id }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.3))
                        }
                    }
                    HStack(spacing: 10) {
                        HStack {
                            Text("$").foregroundStyle(Color.white.opacity(0.3))
                            TextField("0.00", value: $ss.cost, format: .number)
                                .keyboardType(.decimalPad)
                        }
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                        Picker("Cycle", selection: $ss.billingCycle) {
                            Text("Mo").tag(SubService.BillingCycle.monthly)
                            Text("Yr").tag(SubService.BillingCycle.yearly)
                        }.pickerStyle(.segmented)
                        Picker("Status", selection: $ss.status) {
                            Text("Active").tag(SubService.ServiceStatus.active)
                            Text("Paused").tag(SubService.ServiceStatus.paused)
                        }.pickerStyle(.segmented)
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 1))
            }
        }
    }
}

// MARK: - Linked Emails Editor
struct LinkedEmailsEditor: View {
    @Bindable var sub: Subscription

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Linked Emails")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
                Spacer()
                Button {
                    var emails = sub.linkedEmails
                    emails.append(LinkedEmail())
                    sub.linkedEmails = emails
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.zifrGold)
                }
            }

            ForEach($sub.linkedEmails) { $email in
                VStack(spacing: 8) {
                    HStack {
                        TextField("Email address", text: $email.email)
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                            .keyboardType(.emailAddress)
                        Spacer()
                        Button { sub.linkedEmails.removeAll { $0.id == email.id } } label: {
                            Image(systemName: "xmark").font(.system(size: 10)).foregroundStyle(Color.white.opacity(0.3))
                        }
                    }
                    TextField("Used for (e.g. Billing, Admin)", text: $email.usedFor)
                        .font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.6))
                    TextField("Access method (e.g. Google SSO)", text: $email.accessMethod)
                        .font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.6))
                }
                .padding(12)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 1))
            }
        }
    }
}
