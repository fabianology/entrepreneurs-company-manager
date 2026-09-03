import SwiftUI

enum CardRevealLevel: Int, Comparable {
    case headerOnly = 0
    case statusRevealed = 1
    case full = 2

    static func < (lhs: CardRevealLevel, rhs: CardRevealLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct PremiumSubscriptionCard: View {
    let sub: Subscription
    let allSubscriptions: [Subscription]
    let institutions: [Institution]
    let cards: [FinancialCard]
    let onEdit: () -> Void
    var onBankTapped: ((UUID) -> Void)? = nil
    var onSave: ((Subscription) -> Void)? = nil
    var revealLevel: CardRevealLevel = .full
    var isExplicitlyFull: Bool = true
    var extendsUnderNextCard: Bool = false
    var onExpand: (() -> Void)? = nil
    var onCollapse: (() -> Void)? = nil
    var onDragChanged: ((DragGesture.Value) -> Void)? = nil
    var onDragEnded: ((DragGesture.Value) -> Void)? = nil

    @State private var expanded = false
    @State private var showSubServices = false
    @State private var showLinkedEmails = false
    @State private var copiedField: String? = nil // "login" | "password"
    @State private var passwordRevealed = false

    // Sub-service HUD state
    @State private var showSubServiceHUD = false
    @State private var subDraft = SubService()
    @State private var subDraftID: String? = nil
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
    var displayedPrimaryLabel: String {
        sub.billingCycle == "Monthly" ? "/mo" : "/yr"
    }
    var secondaryTotal: Double {
        sub.billingCycle == "Monthly" ? sub.yearlyTotal : sub.monthlyTotal
    }
    var displayedSecondaryLabel: String {
        sub.billingCycle == "Monthly" ? "/yr" : "/mo"
    }
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
        if (sub.paymentMethod ?? "").isEmpty && sub.paymentMethodId == nil { return nil }
        
        if let card = cards.first(where: { sub.paymentMethodId == $0.id || (sub.paymentMethodId == nil && $0.name == sub.paymentMethod) }) {
            let inst = (card.institutionName ?? "").isEmpty ? "Paid From" : card.institutionName!
            let suffix = (card.last4 ?? "").isEmpty ? "" : " ••••\(card.last4 ?? "")"
            return (inst, "\(card.name)\(suffix)", card.type, card.id)
        }
        
        for inst in institutions {
            if let acc = inst.accounts.first(where: { sub.paymentMethodId == UUID(uuidString: $0.id) || (sub.paymentMethodId == nil && ($0.name.isEmpty ? $0.type : $0.name) == sub.paymentMethod) }) {
                let instName = inst.name.isEmpty ? "Paid From" : inst.name
                let accName = acc.name.isEmpty ? acc.type : acc.name
                let suffix = (acc.last4 ?? "").isEmpty ? "" : " ••••\(acc.last4 ?? "")"
                return (instName, "\(accName)\(suffix)", acc.type, inst.id)
            }
        }
        
        return ("Paid From", sub.paymentMethod ?? "", "", nil)
    }

    var body: some View {
        let showsBottomCorners = revealLevel == .full || !extendsUnderNextCard
        let innerShape = UnevenRoundedRectangle(
            topLeadingRadius: 24,
            bottomLeadingRadius: showsBottomCorners ? 24 : 0,
            bottomTrailingRadius: showsBottomCorners ? 24 : 0,
            topTrailingRadius: 24
        )
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    // Logo + Name + Cost row
                    HStack(alignment: .center, spacing: 16) {
                        HStack(alignment: .top, spacing: 16) {
                            // Logo
                            if let website = sub.website, !website.isEmpty {
                                FaviconImage(website: website, size: 40)
                                    .frame(width: 56, height: 56)
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white.opacity(0.06))
                                        .frame(width: 56, height: 56)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                        )
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
                                    HStack(spacing: revealLevel == .full ? 10 : 14) {
                                        costColumn(value: primaryTotal, label: displayedPrimaryLabel)
                                        if secondaryTotal > 0 {
                                            dividerLine()
                                            costColumn(value: secondaryTotal, label: displayedSecondaryLabel)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 8)
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            if isExplicitlyFull {
                                if let onCollapse = onCollapse {
                                    onCollapse()
                                } else {
                                    onExpand?()
                                }
                            } else {
                                onExpand?()
                            }
                        }

                        if revealLevel == .full {
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onEdit()
                            } label: {
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 24, weight: .regular))
                                    .foregroundStyle(Color.white.opacity(0.8))
                                    .frame(width: 40, height: 40)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.leading, 24)
                    .padding(.trailing, 24)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    .overlay(alignment: .bottom) {
                        StackCardDragZone(
                            onChanged: { value in onDragChanged?(value) },
                            onEnded: { value in onDragEnded?(value) }
                        )
                    }

                        // Status row — Dot + pipes style
                        if revealLevel >= .statusRevealed && !sub.isFree {
                            Divider()
                                .background(Color.white.opacity(0.08))
                                .padding(.horizontal, 24)
                            
                            HStack(spacing: 8) {
                                let sTuple = statusRowTuple
                                if sub.status == "Paused" {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(alignment: .center, spacing: 5) {
                                            Text(sTuple.top)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(Color(hex: "#911c26"))
                                            statusDot(sub: sub)
                                        }
                                        if !sTuple.bottom.isEmpty {
                                            Text(sTuple.bottom)
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundStyle(Color(hex: "#911c26").opacity(0.7))
                                        }
                                    }
                                    .textCase(.uppercase)
                                    .tracking(0.3)
                                } else {
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(alignment: .center, spacing: 5) {
                                            Text(sTuple.top)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(.white)
                                            statusDot(sub: sub)
                                        }
                                        if !sTuple.bottom.isEmpty {
                                            Text(sTuple.bottom)
                                                .font(.system(size: 10, weight: .medium))
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
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundStyle(.white)
                                                if !accTuple.type.isEmpty {
                                                    Text("·")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundStyle(Color(hex: "#7D7D7D"))
                                                    Text(accTuple.type)
                                                        .font(.system(size: 11, weight: .medium))
                                                        .foregroundStyle(.white)
                                                }
                                            }
                                            Text(accTuple.account)
                                                .font(.system(size: 10, weight: .medium))
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
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .background(
                        UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 24)
                            .fill(Color.black.opacity(0.70))
                            .padding(.bottom, revealLevel == .full ? 0 : -80)
                            .overlay(
                                UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 24)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )

                    // Credentials row — tap-to-copy
                    if revealLevel == .full {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 12) {
                                copyableCredential(id: sub.id.uuidString, label: "Login ID", value: sub.loginId ?? "", field: "login")
                                copyableCredential(id: sub.id.uuidString, label: "Password", value: sub.password ?? "", field: "password", isPassword: true)
                            }
                            .padding(.top, 4)
                            
                            DynamicLoginLabelView(loginId: sub.loginId ?? "", ignoreSubscriptionId: sub.id.uuidString)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                    }
                }
                .contentShape(Rectangle())

            // ── Supplemental Services accordion ─────────────────────────
            if revealLevel == .full && sub.showSubServicesTab {
                MiloomAccordion(title: "Supplemental Services", count: sub.subServices.count, expanded: showSubServices, action: {
                    withAnimation(.easeInOut(duration: 0.2)) { showSubServices.toggle() }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                VStack(spacing: 0) {
                    ForEach(Array(sub.subServices.enumerated()), id: \.element.id) { i, ss in
                        Button {
                            subDraft = ss
                            subDraftID = ss.id
                            isNewSubService = false
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showSubServiceHUD = true
                        } label: {
                            VStack(spacing: 0) {
                                HStack(alignment: .firstTextBaseline) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Text(ss.name.isEmpty ? "Unnamed Service" : ss.name)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(.white)

                                            statusPipe()

                                            if ss.status == .paused {
                                                Text("Paused")
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundStyle(Color.red)

                                                Circle()
                                                    .fill(Color.red)
                                                    .frame(width: 6, height: 6)
                                            } else {
                                                Text(ss.autoPay == .auto ? "Auto Pay" : "Manual")
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundStyle(Color.white.opacity(0.6))

                                                Circle()
                                                    .fill(ss.autoPay == .auto ? Color.zifrGreen : Color(hex: "#EBC351"))
                                                    .frame(width: 6, height: 6)
                                            }
                                        }
                                        
                                        HStack(spacing: 6) {
                                            Text("billing:")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(Color.white.opacity(0.4))
                                                .textCase(.uppercase)
                                                .tracking(0.5)
                                                .layoutPriority(1)
                                            
                                            Text(ss.paymentMethod.isEmpty ? "No Card" : paymentMethodWithInstitution(for: ss.paymentMethod))
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(Color.white.opacity(0.6))
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                        }
                                        .lineLimit(1)

                                        if !ss.purpose.isEmpty {
                                            HStack(spacing: 6) {
                                                Text("PURPOSE:")
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundStyle(Color.white.opacity(0.4))
                                                    .layoutPriority(1)
                                                
                                                Text(ss.purpose)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundStyle(Color.white.opacity(0.6))
                                                    .lineLimit(1)
                                                    .truncationMode(.tail)
                                            }
                                            .lineLimit(1)
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
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                                .background(Color.clear)
                                
                                if i < sub.subServices.count - 1 {
                                    Divider()
                                        .background(Color.white.opacity(0.06))
                                        .padding(.horizontal, 8)
                                }
                            }
                        }
                        .buttonStyle(PremiumButtonStyle())
                    }
                    
                    Button {
                        subDraft = SubService()
                        subDraftID = nil
                        isNewSubService = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showSubServiceHUD = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                            Text("Add Service").font(.system(size: 13, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                    }
                    .buttonStyle(MiloomSecondaryButtonStyle())
                    .padding(.top, sub.subServices.isEmpty ? 0 : 12)
                }
                }
            }

            // ── Linked Emails accordion ──────────────────────────────────
            if revealLevel == .full && sub.showLinkedEmailsTab {
                MiloomAccordion(title: "Linked Emails", count: sub.linkedEmails.count, expanded: showLinkedEmails, action: {
                    withAnimation(.easeInOut(duration: 0.2)) { showLinkedEmails.toggle() }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                VStack(spacing: 0) {
                    ForEach(sub.linkedEmails.indices, id: \.self) { i in
                        let email = sub.linkedEmails[i]
                        Button {
                            emailDraft = email
                            emailDraftIndex = i
                            isNewEmail = false
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showEmailHUD = true
                        } label: {
                            VStack(spacing: 0) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 6) {
                                            Text(email.email.isEmpty ? "No Address" : email.email)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(.white)
                                                .lineLimit(1)
                                        }

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
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                                .background(Color.clear)
                                
                                if i < sub.linkedEmails.count - 1 {
                                    Divider()
                                        .background(Color.white.opacity(0.06))
                                        .padding(.horizontal, 8)
                                }
                            }
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
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                    }
                    .buttonStyle(MiloomSecondaryButtonStyle())
                    .padding(.top, sub.linkedEmails.isEmpty ? 0 : 12)
                }
                }
            }
        }
        // Match the financial deck: a collapsed rear card continues beneath
        // the next card so its bottom edge cannot show around the front card.
        .frame(minHeight: extendsUnderNextCard ? 148 : nil, alignment: .top)
        .background(
            innerShape
                .fill(Color(hex: "#1C1C1E").opacity(0.40))
        )
        .background(.regularMaterial, in: innerShape)
        .clipShape(innerShape)
        .overlay(
            innerShape
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
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
                    if let subDraftID {
                        guard let idx = services.firstIndex(where: { $0.id == subDraftID }) else {
                            showSubServiceHUD = false
                            return
                        }
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
                    if let subDraftID {
                        var modifiedSub = sub
                        modifiedSub.subServices.removeAll { $0.id == subDraftID }
                        onSave?(modifiedSub)
                    }
                    showSubServiceHUD = false
                }
            )
            .presentationDetents([.fraction(0.70), .large])
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
            .presentationDetents([.fraction(0.70), .large])
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
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: "#C1AA78"))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
    }

    private func dividerLine() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            // A flexible-height divider adopts the hidden card extension's
            // height and pulls two-column prices below the collapsed header.
            .frame(width: 1, height: 16)
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
        let isLocked = SecurityService.isLockedValue(value)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(isCopied ? "Copied ✓" : label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isCopied ? Color.orange : Color.white.opacity(0.5))
                    .textCase(.uppercase)
                if isPassword && !isLocked {
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
                guard !value.isEmpty, !isLocked else { return }
                UIPasteboard.general.string = value
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation { copiedField = field }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { copiedField = nil }
                }
            } label: {
                HStack {
                    Text(isLocked ? SecurityService.lockedValueLabel : (isPassword && !passwordRevealed ? "••••••••" : (value.isEmpty ? "—" : value)))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(value.isEmpty ? Color.white.opacity(0.3) : .white)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
            }
            .buttonStyle(PremiumButtonStyle())
            .disabled(isLocked)
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

struct DynamicLoginLabelView: View {
    let loginId: String
    var ignoreSubscriptionId: String? = nil
    var ignoreInstitutionId: String? = nil
    var vm: AppViewModel? = nil
    
    @Environment(AppState.self) private var appState
    private var allSubscriptions: [Subscription] { appState.subscriptions }
    private var allInstitutions: [Institution] { appState.institutions }
    
    @State private var selectedSubscription: Subscription? = nil
    @State private var selectedInstitution: Institution? = nil
    @State private var localVM = AppViewModel()
    
    private var effectiveVM: AppViewModel {
        vm ?? localVM
    }
    
    var body: some View {
        let normalizedLogin = loginId.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedLogin.isEmpty {
            let matchingSubs: [Subscription] = allSubscriptions.compactMap { s in
                if let ignoreId = ignoreSubscriptionId, s.id.uuidString == ignoreId { return nil }
                
                if (s.loginId ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedLogin {
                    return s
                } else if s.linkedEmails.contains(where: { e in e.email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedLogin }) {
                    return s
                }
                return nil
            }
            
            let matchingInsts: [Institution] = allInstitutions.compactMap { i in
                if let ignoreId = ignoreInstitutionId, i.id.uuidString == ignoreId { return nil }
                
                let instLogin = (i.username ?? "").isEmpty ? (i.email ?? "") : (i.username ?? "")
                if instLogin.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedLogin {
                    return i
                } else if (i.email ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedLogin && !(i.email ?? "").isEmpty {
                    return i
                }
                return nil
            }
            
            let allNames: [String] = (matchingInsts.map { $0.name.isEmpty ? "Unnamed Institution" : $0.name } + matchingSubs.map { $0.name.isEmpty ? "Unnamed Service" : $0.name }).reduce(into: [String]()) { result, name in
                if !result.contains(name) { result.append(name) }
            }
            
            if !matchingInsts.isEmpty || !matchingSubs.isEmpty {
                Menu {
                    if !matchingInsts.isEmpty {
                        Section("Institutions (\(matchingInsts.count))") {
                            ForEach(matchingInsts, id: \.id) { inst in
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    selectedInstitution = inst
                                } label: {
                                    Label(inst.name.isEmpty ? "Unnamed Institution" : inst.name, systemImage: "building.columns")
                                }
                            }
                        }
                    }
                    
                    if !matchingSubs.isEmpty {
                        Section("Services (\(matchingSubs.count))") {
                            ForEach(matchingSubs, id: \.id) { sub in
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    selectedSubscription = sub
                                } label: {
                                    Label(sub.name.isEmpty ? "Unnamed Service" : sub.name, systemImage: "sparkles")
                                }
                            }
                        }
                    }
                    
                    Section {
                        Button {
                            UIPasteboard.general.string = normalizedLogin
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        } label: {
                            Label("Copy Login (\(normalizedLogin))", systemImage: "doc.on.doc")
                        }
                    }
                } label: {
                    HStack(alignment: .center, spacing: 6) {
                        Text("LOGIN ALSO USED IN:")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(hex: "#C1AA78"))
                            .textCase(.uppercase)
                            .layoutPriority(1)
                        
                        HStack(spacing: 5) {
                            Image(systemName: "link")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.zifrGreen)
                            
                            Text(allNames.joined(separator: " · "))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color(hex: "#7D7D7D"))
                                .lineLimit(1)
                            
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.35))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
                .sheet(item: $selectedSubscription) { sub in
                    EditSubscriptionSheet(
                        sub: sub,
                        institutions: appState.institutions,
                        cards: appState.cards,
                        vm: effectiveVM,
                        isNew: false
                    )
                }
                .sheet(item: $selectedInstitution) { inst in
                    EditInstitutionSheet(
                        institution: inst,
                        institutions: appState.institutions,
                        cards: appState.cards,
                        loans: appState.loans,
                        vm: effectiveVM,
                        isNew: false
                    )
                }
            }
        }
    }
}
