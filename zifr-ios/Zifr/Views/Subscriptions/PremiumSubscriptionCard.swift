import SwiftUI

struct PremiumSubscriptionCard: View {
    let sub: Subscription
    let allSubscriptions: [Subscription]
    let institutions: [Institution]
    let cards: [FinancialCard]
    let onEdit: () -> Void
    var onBankTapped: ((UUID) -> Void)? = nil
    var onSave: ((Subscription) -> Void)? = nil

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
        guard !(sub.nextRenewal ?? "").isEmpty else { return "—" }
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
            if let day = Int(sub.nextRenewal ?? "") { return "\(ordinal(day)) of every month" }
            return (sub.nextRenewal ?? "") + " of every month"
        } else {
            let parts = (sub.nextRenewal ?? "").split(separator: " ")
            if parts.count == 2, let day = Int(parts[1]) {
                return "\(parts[0]) \(ordinal(day)) every year"
            }
            return (sub.nextRenewal ?? "") + " every year"
        }
    }

    var shortDueOn: String {
        guard !(sub.nextRenewal ?? "").isEmpty else { return "—" }
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
            if let day = Int(sub.nextRenewal ?? "") { return ordinal(day) }
            return (sub.nextRenewal ?? "")
        } else {
            let parts = (sub.nextRenewal ?? "").split(separator: " ")
            if parts.count == 2, let day = Int(parts[1]) {
                return "\(parts[0]) \(ordinal(day))"
            }
            return (sub.nextRenewal ?? "")
        }
    }

    var statusRowTuple: (top: String, bottom: String) {
        if sub.status == "Paused" { return ("Paused", "") }
        if sub.isFree { return ("Free", "") }
        let cycle = sub.billingCycle == "Monthly" ? "month" : "year"
        let verb = sub.renew == "Manual" ? "Manual pay on" : "Auto pay on"
        return (verb, "\(shortDueOn) every \(cycle)")
    }
    
    var bankAccountTuple: (bank: String, account: String, type: String, modelId: UUID?)? {
        if (sub.paymentMethod ?? "").isEmpty { return nil }
        
        if let card = cards.first(where: { $0.name == sub.paymentMethod }) {
            let inst = (card.institutionName ?? "").isEmpty ? "Paid From" : card.institutionName!
            let suffix = (card.last4 ?? "").isEmpty ? "" : " ••••\(card.last4 ?? "")"
            return (inst, "\(card.name)\(suffix)", card.type, card.id)
        }
        
        for inst in institutions {
            if let acc = inst.accounts.first(where: { ($0.name.isEmpty ? $0.type : $0.name) == sub.paymentMethod }) {
                let instName = inst.name.isEmpty ? "Paid From" : inst.name
                let accName = acc.name.isEmpty ? acc.type : acc.name
                let suffix = (acc.last4 ?? "").isEmpty ? "" : " ••••\(acc.last4 ?? "")"
                return (instName, "\(accName)\(suffix)", acc.type, inst.id)
            }
        }
        
        return ("Paid From", sub.paymentMethod ?? "", "", nil)
    }

    var body: some View {
        MiloomListCard {
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
                            if !(sub.website ?? "").isEmpty {
                                FaviconImage(website: (sub.website ?? ""), size: 36)
                            } else {
                                Text(sub.name.isEmpty ? "?" : String(sub.name.prefix(1)).uppercased())
                                    .font(.system(size: 22, weight: .black))
                                    .foregroundStyle(Color.white.opacity(0.8))
                            }
                        }

                        // Name + costs
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sub.name.isEmpty ? "Service" : sub.name)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)

                            if sub.isFree {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(Color.zifrGreen)
                                        .frame(width: 6, height: 6)
                                        .shadow(color: Color.zifrGreen, radius: 3)
                                    Text("FREE")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.4))
                                }
                                .padding(.top, 2)
                            } else {
                                HStack(spacing: 14) {
                                    costColumn(value: primaryTotal, label: primaryLabel)
                                    if secondaryTotal > 0 {
                                        dividerLine()
                                        costColumn(value: secondaryTotal, label: secondaryLabel)
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .padding(.bottom, sub.isFree ? 4 : 10)

                    if sub.isFree {
                        // 80% width divider under logo row
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 1)
                            .padding(.leading, 24)
                            .padding(.trailing, 70) // Rough 80% of card width
                            .padding(.bottom, 10)
                    }

                    // Status row — CiFr dot + pipes style
                    if !sub.isFree {
                        VStack(spacing: 0) {
                            HStack(spacing: 8) {
                                statusDot(sub: sub)
                                
                                let sTuple = statusRowTuple
                                if sub.status == "Paused" {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(sTuple.top)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Color(hex: "#911c26"))
                                        if !sTuple.bottom.isEmpty {
                                            Text(sTuple.bottom)
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(Color(hex: "#911c26").opacity(0.7))
                                        }
                                    }
                                    .textCase(.uppercase)
                                    .tracking(0.3)
                                } else {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(sTuple.top)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.white)
                                        if !sTuple.bottom.isEmpty {
                                            Text(sTuple.bottom)
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(Color(hex: "#C1AA78"))
                                        }
                                    }
                                    .textCase(.uppercase)
                                    .tracking(0.3)
                                }
                                
                                if let accTuple = bankAccountTuple {
                                    statusPipe()
                                        .padding(.horizontal, 6)
                                    Button {
                                        if let id = accTuple.modelId {
                                            onBankTapped?(id)
                                        }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 4) {
                                                Text(accTuple.bank)
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundStyle(.white)
                                                if !accTuple.type.isEmpty {
                                                    Text("·")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundStyle(Color(hex: "#7D7D7D"))
                                                    Text(accTuple.type)
                                                        .font(.system(size: 11, weight: .semibold))
                                                        .foregroundStyle(.white)
                                                }
                                            }
                                            Text(accTuple.account)
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(Color(hex: "#C1AA78"))
                                        }
                                        .textCase(.uppercase)
                                        .tracking(0.3)
                                    }
                                    .buttonStyle(PremiumButtonStyle())
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color(hex: "#2C2C2E"))
                            .overlay(
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundStyle(Color.white.opacity(0.06)),
                                alignment: .top
                            )
                        }
                        .padding(.bottom, 12)
                    }

                    // Credentials row — tap-to-copy
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 12) {
                            copyableCredential(id: sub.id.uuidString, label: "Login ID", value: sub.loginId ?? "", field: "login")
                            copyableCredential(id: sub.id.uuidString, label: "Password", value: sub.password ?? "", field: "password", isPassword: true)
                        }
                        .padding(.top, 4)
                        
                        DynamicLoginLabelView(loginId: sub.loginId ?? "", ignoreSubscriptionId: sub.id.uuidString)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PremiumButtonStyle())

            // ── Supplemental Services accordion ─────────────────────────
            if sub.showSubServicesTab {
                MiloomAccordion(title: "Supplemental Services", count: sub.subServices.count, expanded: showSubServices, action: {
                    withAnimation(.easeInOut(duration: 0.2)) { showSubServices.toggle() }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
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
                            .background(Color(hex: "#2C2C2E"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        }
                        .buttonStyle(PremiumButtonStyle())
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
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color.zifrGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(PremiumButtonStyle())
                    .padding(.top, sub.subServices.isEmpty ? 0 : 4)
                }
                }
            }

            // ── Linked Emails accordion ──────────────────────────────────
            if sub.showLinkedEmailsTab {
                MiloomAccordion(title: "Linked Emails", count: sub.linkedEmails.count, expanded: showLinkedEmails, action: {
                    withAnimation(.easeInOut(duration: 0.2)) { showLinkedEmails.toggle() }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
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
                            .background(Color(hex: "#2C2C2E"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        }
                        .buttonStyle(PremiumButtonStyle())
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
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color.zifrGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(PremiumButtonStyle())
                    .padding(.top, sub.linkedEmails.isEmpty ? 0 : 4)
                }
                }
            }
        }
        // ── Sub-service HUD ───────────────────────────────────────────────
        .sheet(isPresented: $showSubServiceHUD) {
            SubServiceHUD(
                draft: $subDraft,
                isNew: isNewSubService,
                companyId: sub.companyId,
                institutions: institutions,
                cards: cards,
                onSave: {
                    var modifiedSub = sub
                    var services = modifiedSub.subServices
                    if let idx = subDraftIndex {
                        services[idx] = subDraft
                    } else {
                        services.append(subDraft)
                    }
                    modifiedSub.subServices = services
                    onSave?(modifiedSub)
                    showSubServiceHUD = false
                },
                onCancel: { showSubServiceHUD = false },
                onDelete: {
                    if let idx = subDraftIndex {
                        var modifiedSub = sub
                        modifiedSub.subServices.remove(at: idx)
                        onSave?(modifiedSub)
                    }
                    showSubServiceHUD = false
                }
            )
            .presentationDetents([.height(420)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
        // ── Linked email HUD ─────────────────────────────────────────────
        .proContextMenu(password: sub.password, loginId: sub.loginId, last4: nil)
        .sheet(isPresented: $showEmailHUD) {
            LinkedEmailHUD(
                draft: $emailDraft,
                isNew: isNewEmail,
                onSave: {
                    var modifiedSub = sub
                    var emails = modifiedSub.linkedEmails
                    if let idx = emailDraftIndex {
                        emails[idx] = emailDraft
                    } else {
                        emails.append(emailDraft)
                    }
                    modifiedSub.linkedEmails = emails
                    onSave?(modifiedSub)
                    showEmailHUD = false
                },
                onCancel: { showEmailHUD = false },
                onDelete: {
                    if let idx = emailDraftIndex {
                        var modifiedSub = sub
                        modifiedSub.linkedEmails.remove(at: idx)
                        onSave?(modifiedSub)
                    }
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
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("$\(String(format: "%.0f", value))")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: "#C1AA78"))
        }
    }

    private func dividerLine() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
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



    private func copyableCredential(id: String, label: String, value: String, field: String, isPassword: Bool = false) -> some View {
        let isCopied = copiedField == field
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(isCopied ? "Copied ✓" : label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isCopied ? Color.orange : Color.white.opacity(0.5))
                    .textCase(.uppercase)
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
                .background(Color(hex: "#2C2C2E"))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
            }
            .buttonStyle(PremiumButtonStyle())
        }
    }

    private func detailCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.5))
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: "#C1AA78"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func dynamicLabels(for email: LinkedEmail) -> some View {
        let normalizedEmail = email.email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedEmail.isEmpty {
            let computedServices: [UsedInEmailService] = allSubscriptions.compactMap { s in
                if (s.loginId ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedEmail {
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("LINKED TO:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .textCase(.uppercase)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.zifrGreen)
                        
                        Text(allTextTags.joined(separator: " | "))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(hex: "#7D7D7D"))
                            .lineLimit(2)
                    }
                }
            }
        }
    }
}

struct DynamicLoginLabelView: View {
    let loginId: String
    var ignoreSubscriptionId: String? = nil
    var ignoreInstitutionId: String? = nil
    
    @Environment(AppState.self) private var appState
    private var allSubscriptions: [Subscription] { appState.subscriptions }
    
    private var allInstitutions: [Institution] { appState.institutions }
    
    var body: some View {
        let normalizedLogin = loginId.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedLogin.isEmpty {
            let subServices: [String] = allSubscriptions.compactMap { s in
                if let ignoreId = ignoreSubscriptionId, s.id.uuidString == ignoreId { return nil }
                
                if (s.loginId ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedLogin {
                    return s.name.isEmpty ? "Unnamed Service" : s.name
                } else if s.linkedEmails.contains(where: { e in e.email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedLogin }) {
                    return s.name.isEmpty ? "Unnamed Service" : s.name
                }
                return nil
            }
            
            let instServices: [String] = allInstitutions.compactMap { i in
                if let ignoreId = ignoreInstitutionId, i.id.uuidString == ignoreId { return nil }
                
                let instLogin = (i.username ?? "").isEmpty ? (i.email ?? "") : (i.username ?? "")
                if instLogin.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedLogin {
                    return i.name.isEmpty ? "Unnamed Institution" : i.name
                } else if (i.email ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedLogin && !(i.email ?? "").isEmpty {
                    return i.name.isEmpty ? "Unnamed Institution" : i.name
                }
                return nil
            }
            
            let allTextTags = (subServices + instServices).reduce(into: [String]()) { result, name in
                if !result.contains(name) { result.append(name) }
            }
            
            if !allTextTags.isEmpty {
                HStack(alignment: .center, spacing: 6) {
                    Text("LOGIN ALSO USED IN:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: "#C1AA78"))
                        .textCase(.uppercase)
                        .layoutPriority(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.zifrGreen)
                        
                        Text(allTextTags.joined(separator: " | "))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(hex: "#7D7D7D"))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
                .padding(.bottom, -10)
            }
        }
    }
}
