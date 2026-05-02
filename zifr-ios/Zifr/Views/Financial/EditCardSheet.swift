import SwiftUI
import SwiftData

// MARK: - Edit Card Sheet
struct EditCardSheet: View {
    @State var card: FinancialCard
    @Bindable var vm: AppViewModel
    let institutions: [Institution]
    let cards: [FinancialCard]
    let isNew: Bool
    var isInstitutionContext: Bool = false
    var customTitle: String? = nil
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var showShareSheet = false
    @State private var showDeleteInstitutionConfirm = false
    @State private var institutionToDelete: Institution? = nil
    
    private var subscriptions: [Subscription] { appState.subscriptions }
    
    @State private var showFinancials = false
    @State private var showPaymentPicker = false
    @State private var isNewInstitution: Bool = false
    
    // Institution Draft
    @State private var instWebsite: String = ""
    @State private var instLogin: String = ""
    @State private var instPass: String = ""
    @State private var instEmail: String = ""
    @State private var instTwoFactor: String = ""
    @State private var showInstPassword = false
    @State private var isEditingInstitution = true

    private var allLogins: [String] {
        let subLogins = subscriptions.map { $0.loginId }
        let instUsers = institutions.map { $0.username }
        let instEmails = institutions.map { $0.email }
        return (subLogins + instUsers + instEmails).compactMap { $0 }.filter { !$0.isEmpty }
    }
    private var autoPayBinding: Binding<Bool> {
        Binding(
            get: { card.autopay == "Yes" },
            set: { card.autopay = $0 ? "Yes" : "No" }
        )
    }
    
    private let ordinalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .ordinal
        return f
    }()

    private func ordinal(_ n: Int) -> String {
        ordinalFormatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private var paidOnBinding: Binding<Int> {
        Binding(
            get: { Int(card.paidOn ?? "") ?? 1 },
            set: { card.paidOn = "\($0)" }
        )
    }
    
    struct Snapshot: Equatable {
        var name, last4, network, type, autopay, cardHolder, cardHolderType, expiry, notes: String
        var balance, limit, moPayment, apr, promoApr: Double
        var promoEnds: Date
    }
    @State private var snapshot: Snapshot?

    private var currentSnapshot: Snapshot {
        Snapshot(name: card.name ?? "", last4: card.last4 ?? "", network: card.network ?? "", type: card.type ?? "", autopay: card.autopay, cardHolder: card.cardHolder ?? "", cardHolderType: card.cardHolderType ?? "", expiry: card.expiry ?? "", notes: card.notes ?? "", balance: card.balance, limit: card.limit, moPayment: card.moPayment, apr: card.apr, promoApr: card.promoApr, promoEnds: card.promoEnds ?? Date())
    }

    private var isDirty: Bool {
        guard let snap = snapshot else { return isNew && !card.name.trimmingCharacters(in: .whitespaces).isEmpty }
        return snap != currentSnapshot
    }

    @ViewBuilder private var institutionDetailsSection: some View {
        VStack(spacing: 16) {
            if !isNewInstitution {
                HStack {
                    Text("INSTITUTION DETAILS")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(Color.white.opacity(0.5))
                    Spacer()
                    Button {
                        withAnimation { isEditingInstitution.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isEditingInstitution ? "lock" : "edit")
                                .font(.system(size: 10, weight: .bold))
                                .textCase(.uppercase)
                            Image(systemName: isEditingInstitution ? "lock.open.fill" : "lock.fill")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(.white)
                    }
                }
                .padding(.bottom, 4)
            }

            Group {
                if isNewInstitution {
                    VStack(alignment: .leading, spacing: 8) {
                        ZifrField(label: "INSTITUTION NAME", placeholder: "e.g. Chase Bank", text: Binding(get: { card.institutionName ?? "" }, set: { card.institutionName = $0 }))
                        
                        let matches = institutions.filter { ($0.name ?? "").lowercased().contains((card.institutionName ?? "").lowercased()) && ($0.name ?? "").lowercased() != (card.institutionName ?? "").lowercased() }
                        
                        if !matches.isEmpty && !(card.institutionName ?? "").isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(matches.prefix(3)) { inst in
                                        Button {
                                            isNewInstitution = false
                                            card.institutionName = inst.name
                                            instWebsite = inst.loginUrl ?? ""
                                            instLogin = inst.username ?? ""
                                            instPass = inst.password ?? ""
                                            instEmail = inst.email ?? ""
                                            instTwoFactor = inst.twoFactor ?? ""
                                            isEditingInstitution = false
                                        } label: {
                                            Text("Switch to \(inst.name)")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(Color.green)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.green.opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                
                ZifrField(label: "WEBSITE", placeholder: "chase.com", text: $instWebsite, keyboardType: .URL, textContentType: .URL)
                    .textInputAutocapitalization(.never)
                
                HStack(spacing: 12) {
                    ZifrAutocompleteField(label: "LOGIN ID", placeholder: "username", text: $instLogin, keyboardType: .emailAddress, textContentType: nil, suggestions: allLogins)
                    
                    ZStack(alignment: .bottomTrailing) {
                        ZifrField(label: "PASSWORD", placeholder: "••••••••", text: $instPass, isSecure: !showInstPassword, textContentType: .password)
                            .textInputAutocapitalization(.never)

                        Button {
                            showInstPassword.toggle()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: showInstPassword ? "eye.slash.fill" : "eye.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.4))
                                .padding()
                        }
                        .padding(.bottom, 2)
                        .disabled(!isEditingInstitution)
                    }
                }
                
                HStack(spacing: 12) {
                    ZifrAutocompleteField(label: "EMAIL", placeholder: "name@company.com", text: $instEmail, keyboardType: .emailAddress, textContentType: .emailAddress, suggestions: allLogins)
                        .textInputAutocapitalization(.never)

                    ZifrField(label: "2FA", placeholder: "Phone or App", text: $instTwoFactor)
                }
            }
            .disabled(!isEditingInstitution)
            .opacity(!isEditingInstitution ? 0.25 : 1.0)
        }
    }

    @ViewBuilder private var institutionSelectorRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FINANCIAL INSTITUTION")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(Color.white.opacity(0.5))
            
            VStack(spacing: 0) {
                if !institutions.isEmpty {
                    Picker("Institution Mode", selection: $isNewInstitution) {
                        Text("Select Existing").tag(false)
                        Text("Create New").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 12)
                }
                
                if !isNewInstitution && !institutions.isEmpty {
                    Menu {
                        ForEach(institutions) { inst in
                            Button(inst.name.isEmpty ? "Unnamed" : inst.name) {
                                card.institutionName = inst.name
                                instWebsite = inst.loginUrl ?? ""
                                instLogin = inst.username ?? ""
                                instPass = inst.password ?? ""
                                instEmail = inst.email ?? ""
                                instTwoFactor = inst.twoFactor ?? ""
                                isEditingInstitution = false
                            }
                        }
                    } label: {
                        HStack {
                            Text((card.institutionName ?? "").isEmpty ? "Select Institution..." : (card.institutionName ?? ""))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle((card.institutionName ?? "").isEmpty ? Color.white.opacity(0.4) : .white)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.bottom, 16)
                }
                
                if isNewInstitution || !(card.institutionName ?? "").isEmpty {
                    institutionDetailsSection
                }
            }
        }
    }

    @ViewBuilder private var row1: some View {
        HStack(spacing: 12) {
            ZifrField(label: "CARD NICKNAME", placeholder: "e.g. Sapphire", text: Binding(get: { card.name ?? "" }, set: { card.name = $0 }))
            ZifrField(label: "NAME ON CARD", placeholder: "Jane Doe", text: Binding(get: { card.cardHolder ?? "" }, set: { card.cardHolder = $0 }), textContentType: .name)
        }
    }

    @ViewBuilder private var row2: some View {
        VStack(spacing: 12) {
            ZifrField(label: "CARD NUMBER", placeholder: "0000 0000 0000 0000", text: Binding(get: { card.cardNumber ?? "" }, set: { card.cardNumber = $0 }), keyboardType: .numberPad)
                .onChange(of: card.cardNumber) { old, new in
                    let newStr = new ?? ""
                    let filtered = newStr.filter { $0.isNumber }
                    if (card.cardNumber ?? "") != filtered { card.cardNumber = filtered }
                    
                    if let first = filtered.first {
                        if first == "4" { card.network = "Visa" }
                        else if first == "5" { card.network = "Mastercard" }
                        else if first == "3" { card.network = "Amex" }
                        else if first == "6" { card.network = "Discover" }
                    }
                    
                    let maxLen = card.network == "Amex" ? 5 : 4
                    if filtered.count >= maxLen {
                        card.last4 = String(filtered.suffix(maxLen))
                    } else {
                        card.last4 = filtered
                    }
                }
            
            HStack(spacing: 12) {
                cardPicker(label: "TYPE", sel: Binding(get: { card.type }, set: { card.type = $0 }), opts: FinancialCard.types)
                cardPicker(label: "NETWORK", sel: Binding(get: { card.network }, set: { card.network = $0 }), opts: FinancialCard.networks)
            }
        }
    }

    @ViewBuilder private var row3: some View {
        GeometryReader { geo in
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AUTOPAY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.5))
                    HStack {
                        Text(autoPayBinding.wrappedValue ? "Enabled" : "Disabled")
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
                .frame(width: (geo.size.width - 12) * 0.6)

                VStack(alignment: .leading, spacing: 4) {
                    Text("PAID ON")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.5))
                    HStack {
                        Picker("", selection: paidOnBinding) {
                            ForEach(1...31, id: \.self) { day in
                                Text(ordinal(day)).tag(day)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .tint(.white)
                        Spacer()
                    }
                    .padding(.leading, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 44)
                    .background(Color(hex: "#111111"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .frame(width: (geo.size.width - 12) * 0.4)
            }
        }
        .frame(height: 64)
    }

    @ViewBuilder private var row4: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PAID FROM")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            
            Button {
                showPaymentPicker = true
            } label: {
                HStack {
                    Text((card.paidFrom ?? "").isEmpty ? "None" : (card.paidFrom ?? ""))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle((card.paidFrom ?? "").isEmpty ? Color.white.opacity(0.4) : .white)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color(hex: "#111111"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder private var row5: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ROLE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.5))
                VStack(spacing: 0) {
                    Spacer()
                    Picker("Role", selection: Binding(get: { card.cardHolderType }, set: { card.cardHolderType = $0 })) {
                        Text("Mine").tag("Mine")
                        Text("Assigned").tag("Assigned")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    Spacer()
                }
                .frame(height: 44)
            }
            
            ZifrField(label: "EXPIRES", placeholder: "MM/YY", text: Binding(get: { card.expiry ?? "" }, set: { card.expiry = $0 }), keyboardType: .numberPad)
                .onChange(of: card.expiry) { old, new in
                    var filtered = (new ?? "").filter { $0.isNumber }
                    if (old ?? "").count == 3 && (old ?? "").hasSuffix("/") && (new ?? "").count == 2 {
                        filtered = String(filtered.prefix(1))
                    }
                    if filtered.count > 2 {
                        filtered.insert("/", at: filtered.index(filtered.startIndex, offsetBy: 2))
                    }
                    if filtered.count > 5 {
                        filtered = String(filtered.prefix(5))
                    }
                    if (card.expiry ?? "") != filtered { card.expiry = filtered }
                }
        }
    }

    private var paysForServices: [(name: String, cost: Double)] {
        let cardName = card.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cardName.isEmpty else { return [] }
        var results: [(name: String, cost: Double)] = []
        for sub in subscriptions {
            if (sub.paymentMethod ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == cardName {
                results.append((name: sub.name.isEmpty ? "Unnamed Service" : sub.name, cost: sub.cost))
            }
            for subSvc in sub.subServices {
                if (subSvc.paymentMethod ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == cardName {
                    results.append((name: subSvc.name.isEmpty ? "Unnamed Sub-service" : subSvc.name, cost: subSvc.cost))
                }
            }
        }
        return results
    }

    @ViewBuilder private var paysForRow: some View {
        let services = paysForServices
        VStack(alignment: .leading, spacing: 12) {
            Text("PAYS FOR")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
                .padding(.leading, 6)
            
            if services.isEmpty {
                Text("No linked services")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(Color(hex: "#111111"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
            } else {
                ForEach(Array(services.enumerated()), id: \.offset) { index, svc in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(svc.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.zifrGreen)
                                    .frame(width: 6, height: 6)
                                
                                Text("|")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.white.opacity(0.2))
                                
                                Text("Paid with \(card.name)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.6))
                            }
                        }
                        Spacer()
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("$\(String(format: "%.0f", svc.cost))")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("/mo")
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
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        if !isInstitutionContext {
                            institutionSelectorRow
                        }
                        row1
                        row2
                        if card.type.lowercased() != "debit" {
                            row3
                            row4
                        }
                        row5
                        paysForRow
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)

                // MARK: - Financial Details
                Section {
                    VStack(spacing: 0) {
                        HStack {
                            Rectangle()
                                .fill(Color.white.opacity(0.07))
                                .frame(height: 1)
                            Text("FINANCIALS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.25))
                                .fixedSize()
                            Rectangle()
                                .fill(Color.white.opacity(0.07))
                                .frame(height: 1)
                        }
                        .padding(.bottom, 8)

                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    moneyField(label: "BALANCE", value: Binding(get: { card.balance }, set: { card.balance = $0 }))
                                    if card.type == "Credit" {
                                        moneyField(label: "CREDIT LIMIT", value: Binding(get: { card.limit }, set: { card.limit = $0 }))
                                    } else {
                                        Color.clear.frame(maxWidth: .infinity)
                                    }
                                }

                                HStack(spacing: 12) {
                                    moneyField(label: "MO. PAYMENT", value: Binding(get: { card.moPayment }, set: { card.moPayment = $0 }))
                                    Color.clear.frame(maxWidth: .infinity)
                                }

                                if card.type == "Credit" {
                                    HStack(spacing: 12) {
                                        aprField(label: "APR%", value: $card.apr)
                                            .frame(maxWidth: .infinity)
                                            .frame(width: (UIScreen.main.bounds.width - 64) * 0.28)
                                        
                                        aprField(label: "PROMO APR%", value: $card.promoApr)
                                            .frame(maxWidth: .infinity)
                                            .frame(width: (UIScreen.main.bounds.width - 64) * 0.28)
                                        
                                        datePicker(label: "ENDS", selection: Binding(get: { card.promoEnds ?? Date() }, set: { card.promoEnds = $0 }))
                                    }
                                }
                            }
                        }
                    } header: { EmptyView() }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowSeparator(.hidden)
                // MARK: - Notes
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NOTES")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .padding(.leading, 6)
                        
                        TextField("Add notes...", text: Binding(get: { card.notes ?? "" }, set: { card.notes = $0 }), axis: .vertical)
                            .lineLimit(3...6)
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Color(hex: "#111111"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)

                if !isNew {
                    Section {
                        // Share Card
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showShareSheet = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "person.crop.circle.badge.plus")
                                Text("Share Card")
                                Spacer()
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(hex: "#4f46e5"))
                            .padding(.vertical, 14)
                            .background(Color(hex: "#4f46e5").opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#4f46e5").opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 8)

                        // Delete Card
                        Button(role: .destructive) {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("Delete \(card.name.isEmpty ? "Card" : card.name)")
                                Spacer()
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.red)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .confirmationDialog("Delete Card?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                            Button("Delete Card", role: .destructive) {
                                let instNameStr = card.institutionName ?? ""
                                vm.deleteCard(card, appState: appState)
                                
                                let remainingCards = cards.filter { ($0.institutionName ?? "").lowercased() == instNameStr.lowercased() && $0.id != card.id }
                                if let orphanedInst = institutions.first(where: { $0.name.lowercased() == instNameStr.lowercased() }) {
                                    if remainingCards.isEmpty && orphanedInst.accounts.isEmpty {
                                        institutionToDelete = orphanedInst
                                        
                                        // Slight delay so the first sheet closes cleanly before showing second
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            showDeleteInstitutionConfirm = true
                                        }
                                    } else {
                                        dismiss()
                                    }
                                } else {
                                    dismiss()
                                }
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                        .confirmationDialog("Delete Empty Institution?", isPresented: $showDeleteInstitutionConfirm, titleVisibility: .visible) {
                            Button("Yes, Delete", role: .destructive) {
                                if let inst = institutionToDelete {
                                    vm.deleteInstitution(inst, appState: appState)
                                }
                                dismiss()
                            }
                            Button("No, Keep It", role: .cancel) { dismiss() }
                        } message: {
                            Text("This was the last item for \(institutionToDelete?.name ?? "this institution"). Do you want to delete the institution profile too?")
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
                if isNew {
                    isNewInstitution = institutions.isEmpty
                } else {
                    isNewInstitution = (card.institutionName ?? "").isEmpty || !institutions.contains(where: { $0.name.lowercased() == (card.institutionName ?? "").lowercased() })
                }
                if snapshot == nil { snapshot = currentSnapshot }
            }
            .navigationTitle(customTitle ?? (isNew ? "New Card" : card.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isNew { 
                            vm.deleteCard(card, appState: appState) 
                        } else if let snap = snapshot {
                            card.name = snap.name
                            card.last4 = snap.last4
                            card.network = snap.network
                            card.type = snap.type
                            card.autopay = snap.autopay
                            card.cardHolder = snap.cardHolder
                            card.cardHolderType = snap.cardHolderType
                            card.expiry = snap.expiry
                            card.notes = snap.notes
                            card.balance = snap.balance
                            card.limit = snap.limit
                            card.moPayment = snap.moPayment
                            card.apr = snap.apr
                            card.promoApr = snap.promoApr
                            card.promoEnds = snap.promoEnds
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveInstitutionData()
                        vm.saveCard(card, appState: appState)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(isDirty ? .green : nil)
                }
            }
            .interactiveDismissDisabled(isNew)
            .sheet(isPresented: $showShareSheet) {
                ShareEntitySheet(resourceId: card.id, resourceType: "card", resourceTitle: card.name.isEmpty ? "Card" : card.name)
            }
            .sheet(isPresented: $showPaymentPicker) {
                NavigationStack {
                    PaymentMethodPickerView(
                        currentMethod: card.paidFrom ?? "",
                        companyId: card.companyId,
                        institutions: institutions,
                        cards: cards
                    ) { method in
                        card.paidFrom = method
                    }
                }
            }
        }
    }

    private func datePicker(label: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            
            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 44)
        }
    }

    private func aprField(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            HStack(spacing: 4) {
                DoubleField(placeholder: "0.00", value: value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text("%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 44)
            .background(Color(hex: "#111111"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    private func cardPicker(label: String, sel: Binding<String>, opts: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            HStack {
                Picker("", selection: sel) {
                    ForEach(opts, id: \.self) { t in
                        Text(t).tag(t)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(.white)
                
                Spacer()
            }
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 44)
            .background(Color(hex: "#111111"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func saveInstitutionData() {
        if isNewInstitution {
            var newInst = vm.addInstitution(appState: appState, userId: card.userId, companyId: card.companyId)
            newInst.name = card.institutionName ?? ""
            newInst.loginUrl = instWebsite
            newInst.username = instLogin
            newInst.password = instPass
            newInst.email = instEmail
            newInst.twoFactor = instTwoFactor
            vm.saveInstitution(newInst, appState: appState)
        } else {
            let instName = (card.institutionName ?? "").lowercased()
            if !instName.isEmpty {
                if var existing = institutions.first(where: { $0.name.lowercased() == instName }) {
                    existing.loginUrl = instWebsite
                    existing.username = instLogin
                    existing.password = instPass
                    existing.email = instEmail
                    existing.twoFactor = instTwoFactor
                    vm.saveInstitution(existing, appState: appState)
                }
            }
        }
    }

    private func moneyField(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            HStack(spacing: 4) {
                Text("$")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.5))
                DoubleField(placeholder: "0.00", value: value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 44)
            .background(Color(hex: "#111111"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }
}
