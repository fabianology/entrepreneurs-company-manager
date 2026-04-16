import SwiftUI

struct SubscriptionListView: View {
    let company: Company
    let subscriptions: [Subscription]
    let institutions: [Institution]
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
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.black)
                            Text("SERVICE")
                                .font(.system(size: 9, weight: .black))
                                .tracking(1)
                                .foregroundStyle(.black)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 32)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                if subscriptions.isEmpty {
                    emptyState
                } else {
                    ForEach(subscriptions) { sub in
                        SubscriptionCardView(sub: sub, onEdit: { editingSub = sub })
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                    }
                }
            }
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $editingSub) { sub in
            EditSubscriptionSheet(sub: sub, institutions: institutions, vm: vm, isNew: false)
        }
        .sheet(item: $newSub) { sub in
            EditSubscriptionSheet(sub: sub, institutions: institutions, vm: vm, isNew: true)
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
            .background(Color(hex: "#1C1C1E").opacity(0.5))
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
    let sub: Subscription
    let onEdit: () -> Void

    @State private var expanded = false
    @State private var showSubServices = false
    @State private var showLinkedEmails = false
    @State private var copiedField: String? = nil // "login" | "password"
    @State private var passwordRevealed = false

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
                                .fill(Color.white.opacity(0.05))
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
                        VStack(alignment: .leading, spacing: 4) {
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
                                .padding(.top, 4)
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
                            statusPipe()
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
            }
            .buttonStyle(.plain)

            // ── More Details accordion ───────────────────────────────────
            if !sub.isFree {
                accordionDivider()
                accordionToggle(label: expanded ? "Less Details" : "More Details", expanded: expanded) {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                if expanded {
                    LazyVStack(spacing: 12) {
                        HStack(spacing: 16) {
                            detailCell(label: "Paid From", value: sub.paymentMethod.isEmpty ? "—" : sub.paymentMethod)
                            detailCell(label: "Due On", value: sub.nextRenewal.isEmpty ? "—" : sub.nextRenewal)
                        }
                        if !sub.notes.isEmpty {
                            detailCell(label: "Notes", value: sub.notes)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .transition(.opacity.combined(with: .move(edge: .top)))
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
                    ForEach(sub.subServices) { ss in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(ss.name.isEmpty ? "Unnamed" : ss.name.uppercased())
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white)
                                HStack(spacing: 8) {
                                    Text(ss.status == .active ? "Active" : "Paused")
                                        .font(.system(size: 9, weight: .black))
                                        .textCase(.uppercase)
                                        .tracking(1)
                                        .foregroundStyle(ss.status == .active ? Color.zifrGreen : Color.red)
                                    Text("|").foregroundStyle(Color.white.opacity(0.2))
                                    Text(ss.billingCycle == .monthly ? "Auto Pay" : "Manual")
                                        .font(.system(size: 9, weight: .black))
                                        .textCase(.uppercase)
                                        .tracking(1)
                                        .foregroundStyle(Color.zifrGreen)
                                }
                            }
                            Spacer()
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("$\(String(format: "%.2f", ss.cost))")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(ss.status == .active ? .white : Color.white.opacity(0.2))
                                Text("/\(ss.billingCycle == .monthly ? "mo" : "yr")")
                                    .font(.system(size: 9, weight: .black))
                                    .textCase(.uppercase)
                                    .tracking(1)
                                    .foregroundStyle(Color.white.opacity(0.4))
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // ── Linked Emails accordion ──────────────────────────────────
            accordionDivider()
            accordionToggle(label: "Linked Emails", count: sub.linkedEmails.count, expanded: showLinkedEmails) {
                withAnimation(.easeInOut(duration: 0.2)) { showLinkedEmails.toggle() }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            if showLinkedEmails {
                VStack(spacing: 0) {
                    ForEach(Array(sub.linkedEmails.enumerated()), id: \.element.id) { i, email in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Email")
                                    .font(.system(size: 8, weight: .black))
                                    .textCase(.uppercase)
                                    .tracking(2)
                                    .foregroundStyle(Color.white.opacity(0.4))
                                Text(email.email.isEmpty ? "—" : email.email)
                                    .font(.system(size: 12, weight: .black))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("Used For")
                                    .font(.system(size: 8, weight: .black))
                                    .textCase(.uppercase)
                                    .tracking(2)
                                    .foregroundStyle(Color.white.opacity(0.4))
                                Text(email.usedFor.isEmpty ? "—" : email.usedFor)
                                    .font(.system(size: 12, weight: .black))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 8)
                        if i < sub.linkedEmails.count - 1 {
                            Divider().background(Color.white.opacity(0.05))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        // ── Card container: #1C1C1E + border 5% ─────────────────────────
        .background(Color(hex: "#1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func costColumn(value: Double, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("$\(String(format: "%.2f", value))")
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
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isCopied ? Color.orange : Color.white.opacity(0.4))
                if isPassword {
                    Button {
                        passwordRevealed.toggle()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: passwordRevealed ? "eye.slash" : "eye")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.3))
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
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(value.isEmpty ? Color.white.opacity(0.2) : .white)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.03), lineWidth: 1))
            }
        }
    }

    private func detailCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.4))
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
