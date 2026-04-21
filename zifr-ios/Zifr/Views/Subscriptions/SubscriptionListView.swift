import SwiftUI

struct SubscriptionListView: View {
    let company: Company
    let subscriptions: [Subscription]
    let institutions: [Institution]
    let cards: [FinancialCard]
    @Bindable var vm: AppViewModel
    @Environment(\.modelContext) private var context

    @State private var editingSub: Subscription? = nil
    @State private var newSub: Subscription? = nil



    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Add button row — exact CiFr style
                HStack {
                    Spacer()
                    Button(action: { 
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        newSub = vm.addSubscription(context: context, companyId: company.id) 
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color(hex: "#A2A2A2"))
                            Text("SERVICE")
                                .font(.system(size: 12, weight: .heavy))
                                .tracking(1)
                                .foregroundStyle(Color(hex: "#A2A2A2"))
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 36)
                        .background(Color(hex: "#222E2F"))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                if subscriptions.isEmpty {
                    emptyState
                } else {
                    ForEach(subscriptions) { sub in
                        SubscriptionCardView(sub: sub, allSubscriptions: subscriptions, institutions: institutions, cards: cards, onEdit: { editingSub = sub })
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                    }
                }
            }
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $editingSub) { sub in
            EditSubscriptionSheet(sub: sub, institutions: institutions, cards: cards, vm: vm, isNew: false)
        }
        .sheet(item: $newSub) { sub in
            EditSubscriptionSheet(sub: sub, institutions: institutions, cards: cards, vm: vm, isNew: true)
        }
    }

    private var emptyState: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            newSub = vm.addSubscription(context: context, companyId: company.id)
        }) {
            VStack(spacing: 16) {
                Text("🌐")
                    .font(.system(size: 28))
                Text("+ Add Your First Service")
                    .font(.system(size: 9, weight: .black))
                    .textCase(.uppercase)
                    .tracking(3)
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(Color(hex: "#171717").opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [6]))
                    .foregroundStyle(Color.white.opacity(0.2))
            )
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Subscription Card (exact CiFr layout)

struct SubscriptionCardView: View {
    @Bindable var sub: Subscription
    let allSubscriptions: [Subscription]
    let institutions: [Institution]
    let cards: [FinancialCard]
    let onEdit: () -> Void

    @State private var expanded = false
    @State private var showSubServices = false
    @State private var showLinkedEmails = false
    @State private var copiedField: String? = nil // "login" | "password"
    @State private var passwordRevealed = false

    // Sub-service HUD state
    @State private var showSubServiceHUD = false
    @State private var subDraft = SubService()
    @State private var subDraftIndex: Int? = nil
    @State private var isNewSubService = false

    // Linked email HUD state
    @State private var showEmailHUD = false
    @State private var emailDraft = LinkedEmail()
    @State private var emailDraftIndex: Int? = nil
    @State private var isNewEmail = false

    // Billing totals — mirrors CiFr calcTotals()
    var primaryTotal: Double {
        sub.billingCycle == "Monthly" ? sub.monthlyTotal : sub.yearlyTotal
    }
    var primaryLabel: String { sub.billingCycle == "Monthly" ? "recur/mo." : "recur/yr." }
    var secondaryTotal: Double {
        sub.billingCycle == "Monthly" ? sub.yearlyTotal : sub.monthlyTotal
    }
    var secondaryLabel: String { sub.billingCycle == "Monthly" ? "recur/yr." : "recur/mo." }
    var totalAnnual: Double { (sub.monthlyTotal * 12) + sub.yearlyTotal }

    var formattedDueOn: String {
        guard !sub.nextRenewal.isEmpty else { return "—" }
        func ordinal(_ n: Int) -> String {
            let tens = (n % 100) / 10
            if tens == 1 { return "\(n)th" }
            switch n % 10 {
            case 1: return "\(n)st"
            case 2: return "\(n)nd"
            case 3: return "\(n)rd"
            default: return "\(n)th"
            }
        }
        if sub.billingCycle == "Monthly" {
            if let day = Int(sub.nextRenewal) { return "\(ordinal(day)) of every month" }
            return sub.nextRenewal + " of every month"
        } else {
            let parts = sub.nextRenewal.split(separator: " ")
            if parts.count == 2, let day = Int(parts[1]) {
                return "\(parts[0]) \(ordinal(day)) every year"
            }
            return sub.nextRenewal + " every year"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Top: tap opens edit ──────────────────────────────────────
            Button(action: onEdit) {
                VStack(spacing: 0) {
                    // Logo + Name + Cost row
                    HStack(alignment: .top, spacing: 16) {
                        // Logo — 56×56 rounded-16 rgba(255,255,255,0.05) bg
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.clear)
                                .frame(width: 56, height: 56)
                            if !sub.website.isEmpty {
                                FaviconImage(website: sub.website, size: 36)
                            } else {
                                Text(sub.name.isEmpty ? "?" : String(sub.name.prefix(1)).uppercased())
                                    .font(.system(size: 22, weight: .black))
                                    .foregroundStyle(Color.white.opacity(0.8))
                            }
                        }

                        // Name + costs
                        VStack(alignment: .leading, spacing: 0) {
                            Text(sub.name.isEmpty ? "Service" : sub.name)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)

                            if !sub.isFree {
                                HStack(spacing: 14) {
                                    costColumn(value: primaryTotal, label: primaryLabel)
                                    if secondaryTotal > 0 {
                                        dividerLine()
                                        costColumn(value: secondaryTotal, label: secondaryLabel)
                                    }
                                    dividerLine()
                                    costColumn(value: totalAnnual, label: "est. yearly")
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, sub.isFree ? 18 : 4)

                    // Status row — CiFr dot + pipes style
                    if !sub.isFree {
                        HStack(spacing: 8) {
                            statusDot(sub: sub)
                            Text(sub.isFree ? "Free" : (sub.renew == "Manual" ? "Manual" : "Auto Renew"))
                                .font(.system(size: 11, weight: .semibold))
                                .textCase(.uppercase)
                                .tracking(0.3)
                                .foregroundStyle(sub.renew == "Manual" ? Color.red : Color.zifrGreen)
                            statusPipe()
                            Text(sub.isFree ? "Active" : "Paid")
                                .font(.system(size: 11, weight: .semibold))
                                .textCase(.uppercase)
                                .tracking(0.3)
                                .foregroundStyle(Color.zifrGreen)
                            statusPipe()
                            Text(sub.status)
                                .font(.system(size: 11, weight: .semibold))
                                .textCase(.uppercase)
                                .tracking(0.3)
                                .foregroundStyle(Color.zifrGreen)
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                    }

                    // Credentials row — tap-to-copy
                    HStack(spacing: 12) {
                        copyableCredential(id: sub.id, label: "Login ID", value: sub.loginId, field: "login")
                        copyableCredential(id: sub.id, label: "Password", value: sub.password, field: "password", isPassword: true)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ── Billing Details accordion ───────────────────────────────────
            if !sub.isFree {
                accordionDivider()
                accordionToggle(label: expanded ? "Hide Billing" : "Billing Details", expanded: expanded) {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                if expanded {
                    VStack(spacing: 12) {
                        HStack(spacing: 16) {
                            detailCell(label: "Paid From", value: sub.paymentMethod.isEmpty ? "—" : sub.paymentMethod)
                            detailCell(label: "Due On", value: formattedDueOn)
                        }
                        if !sub.notes.isEmpty {
                            detailCell(label: "Notes", value: sub.notes)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .clipped()
                }
            }

            // ── Supplemental Services accordion ─────────────────────────
            accordionDivider()
            accordionToggle(label: "Supplemental Services", count: sub.subServices.count, expanded: showSubServices) {
                withAnimation(.easeInOut(duration: 0.2)) { showSubServices.toggle() }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            if showSubServices {
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
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(ss.name.isEmpty ? "Unnamed Service" : ss.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                    
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(ss.status == .active ? Color.zifrGreen : Color.red)
                                            .frame(width: 6, height: 6)
                                        
                                        statusPipe()
                                        
                                        Text(ss.paymentMethod.isEmpty ? "No Card" : ss.paymentMethod)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.6))

                                        statusPipe()
                                        
                                        Text(ss.autoPay == .auto ? "Auto Pay" : "Manual")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.6))
                                    }
                                }
                                Spacer()
                                HStack(alignment: .firstTextBaseline, spacing: 2) {
                                    Text("$\(String(format: "%.0f", ss.cost))")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(ss.status == .active ? .white : Color.white.opacity(0.4))
                                    Text("/\(ss.billingCycle == .monthly ? "mo" : "yr")")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#111111"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.05), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button {
                        subDraft = SubService()
                        subDraftIndex = nil
                        isNewSubService = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showSubServiceHUD = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                            Text("Add Service").font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(Color.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, sub.subServices.isEmpty ? 0 : 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .clipped()
            }

            // ── Linked Emails accordion ──────────────────────────────────
            accordionDivider()
            accordionToggle(label: "Linked Emails", count: sub.linkedEmails.count, expanded: showLinkedEmails) {
                withAnimation(.easeInOut(duration: 0.2)) { showLinkedEmails.toggle() }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            if showLinkedEmails {
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
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    // Email
                                    Text(email.email.isEmpty ? "No Address" : email.email)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)

                                    dynamicLabels(for: email)

                                    // Role row
                                    HStack(spacing: 6) {
                                        Text("USED FOR:")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Color.white.opacity(0.4))
                                        
                                        Text(email.usedFor.isEmpty ? "Unassigned" : email.usedFor)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.6))
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#111111"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.05), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button {
                        emailDraft = LinkedEmail()
                        emailDraftIndex = nil
                        isNewEmail = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showEmailHUD = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                            Text("Add Email").font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(Color.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, sub.linkedEmails.isEmpty ? 0 : 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .clipped()
            }
        }
        // ── Card container: #171717 + border 5% ─────────────────────────
        .background(Color(hex: "#171717"))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        // ── Sub-service HUD ───────────────────────────────────────────────
        .sheet(isPresented: $showSubServiceHUD) {
            SubServiceHUD(
                draft: $subDraft,
                isNew: isNewSubService,
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
        // ── Linked email HUD ─────────────────────────────────────────────
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
                    if let idx = emailDraftIndex { sub.linkedEmails.remove(at: idx) }
                    showEmailHUD = false
                }
            )
            .presentationDetents([.height(500)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
    }

    // MARK: - Helpers

    private func costColumn(value: Double, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("$\(String(format: "%.0f", value))")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.4))
        }
    }

    private func dividerLine() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.05))
            .frame(width: 1)
            .padding(.vertical, 2)
    }

    private func statusDot(sub: Subscription) -> some View {
        Circle()
            .fill(sub.status == "Paused" ? Color.red : (sub.renew == "Manual" ? Color.red : Color.zifrGreen))
            .frame(width: 6, height: 6)
    }

    private func statusPipe() -> some View {
        Text("|")
            .font(.system(size: 10))
            .foregroundStyle(Color.white.opacity(0.2))
    }

    private func accordionDivider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.05))
            .frame(height: 1)
    }

    private func accordionToggle(label: String, count: Int? = nil, expanded: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if let count {
                    Text("\(label) ")
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(0.2)
                        .foregroundStyle(Color.white.opacity(0.5))
                    + Text("(\(count))")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.2))
                } else {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(0.2)
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .padding(.horizontal, 24)
            .frame(height: 47)
        }
    }

    private func copyableCredential(id: String, label: String, value: String, field: String, isPassword: Bool = false) -> some View {
        let isCopied = copiedField == field
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(isCopied ? "Copied ✓" : label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isCopied ? Color.orange : Color.white.opacity(0.5))
                if isPassword {
                    Button {
                        passwordRevealed.toggle()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: passwordRevealed ? "eye.slash" : "eye")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                }
            }

            Button {
                guard !value.isEmpty else { return }
                UIPasteboard.general.string = value
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation { copiedField = field }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { copiedField = nil }
                }
            } label: {
                HStack {
                    Text(isPassword && !passwordRevealed ? "••••••••" : (value.isEmpty ? "—" : value))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(value.isEmpty ? Color.white.opacity(0.3) : .white)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.05), lineWidth: 1))
            }
        }
    }

    private func detailCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.5))
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func dynamicLabels(for email: LinkedEmail) -> some View {
        let normalizedEmail = email.email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedEmail.isEmpty {
            let computedServices: [UsedInEmailService] = allSubscriptions.compactMap { s in
                if s.loginId.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedEmail {
                    return UsedInEmailService(name: s.name.isEmpty ? "Unnamed Service" : s.name, role: .primary)
                } else if s.linkedEmails.contains(where: { e in e.email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedEmail }) {
                    return UsedInEmailService(name: s.name.isEmpty ? "Unnamed Service" : s.name, role: .linked)
                }
                return nil
            }
            let legacyTags: [String] = email.usedIn.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { tag in 
                    !tag.isEmpty && !computedServices.contains { $0.name.lowercased() == tag.lowercased() }
                }
                
            let allTextTags = computedServices.map { svc in
                svc.name
            } + legacyTags
                
            if !allTextTags.isEmpty {
                HStack(spacing: 4) {
                    Text("LINKED TO:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .textCase(.uppercase)
                    
                    Image(systemName: "link")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(hex: "#545454"))
                    
                    Text(allTextTags.joined(separator: " | "))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: "#545454"))
                        .lineLimit(2)
                }
            }
        }
    }
}
