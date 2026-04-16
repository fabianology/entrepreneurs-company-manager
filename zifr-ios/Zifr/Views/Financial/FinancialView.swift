import SwiftUI

struct FinancialView: View {
    let company: Company
    let cards: [FinancialCard]
    let institutions: [Institution]
    let loans: [Loan]
    @Bindable var vm: AppViewModel
    @Environment(\.modelContext) private var context

    @State private var editingCard: FinancialCard? = nil
    @State private var editingInst: Institution? = nil
    @State private var editingLoan: Loan? = nil
    @State private var showAddCard = false
    @State private var showAddInst = false
    @State private var showAddLoan = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Institutions
                sectionBlock(
                    title: "Banks & Institutions",
                    count: institutions.count,
                    onAdd: { showAddInst = true }
                ) {
                    ForEach(institutions) { inst in
                        InstitutionCardView(institution: inst, onEdit: { editingInst = inst })
                    }
                }

                // Cards
                sectionBlock(
                    title: "Payment Cards",
                    count: cards.count,
                    onAdd: { showAddCard = true }
                ) {
                    ForEach(cards) { card in
                        FinancialCardView(card: card, onEdit: { editingCard = card })
                    }
                }

                // Loans
                sectionBlock(
                    title: "Loans & Financing",
                    count: loans.count,
                    onAdd: { showAddLoan = true }
                ) {
                    ForEach(loans) { loan in
                        LoanCardView(loan: loan, onEdit: { editingLoan = loan })
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        // Institution sheet
        .sheet(isPresented: $showAddInst) {
            let i = vm.addInstitution(context: context, companyId: company.id)
            EditInstitutionSheet(institution: i, vm: vm, isNew: true)
        }
        .sheet(item: $editingInst) { i in
            EditInstitutionSheet(institution: i, vm: vm, isNew: false)
        }
        // Card sheet
        .sheet(isPresented: $showAddCard) {
            let c = vm.addCard(context: context, companyId: company.id)
            EditCardSheet(card: c, vm: vm, isNew: true)
        }
        .sheet(item: $editingCard) { c in
            EditCardSheet(card: c, vm: vm, isNew: false)
        }
        // Loan sheet
        .sheet(isPresented: $showAddLoan) {
            let l = vm.addLoan(context: context, companyId: company.id)
            EditLoanSheet(loan: l, vm: vm, isNew: true)
        }
        .sheet(item: $editingLoan) { l in
            EditLoanSheet(loan: l, vm: vm, isNew: false)
        }
    }

    @ViewBuilder
    private func sectionBlock<Content: View>(title: String, count: Int, onAdd: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(3)
                    .foregroundStyle(Color.white.opacity(0.4))
                Spacer()
                Button(action: { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); onAdd() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.black)
                        Text("ADD")
                            .font(.system(size: 9, weight: .black))
                            .tracking(1)
                            .foregroundStyle(.black)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 28)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
            }
            content()
        }
    }
}

// MARK: - Institution Card
struct InstitutionCardView: View {
    let institution: Institution
    let onEdit: () -> Void
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onEdit) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.zifrGold.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "building.columns")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.zifrGold)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(institution.name.isEmpty ? "New Bank" : institution.name)
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(.white)
                        Text("\(institution.accounts.count) accounts")
                            .zifrLabel()
                    }
                    Spacer()
                    Image(systemName: "pencil")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.25))
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if !institution.accounts.isEmpty {
                Divider().background(Color.white.opacity(0.06))
                Button {
                    withAnimation(.spring(response: 0.35)) { expanded.toggle() }
                } label: {
                    HStack {
                        Text(expanded ? "Hide Accounts" : "Show Accounts")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.35))
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.25))
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                }

                if expanded {
                    VStack(spacing: 8) {
                        ForEach(institution.accounts) { acc in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(acc.name.isEmpty ? "Account" : acc.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("\(acc.type) • ••\(acc.last4)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.4))
                                }
                                Spacer()
                                Text(acc.balance.currencyString)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.zifrGold)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .glassCard(cornerRadius: 20)
    }
}

// MARK: - Financial Card View
struct FinancialCardView: View {
    let card: FinancialCard
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: card.colorHex))
                        .frame(width: 44, height: 28)
                    Text("••\(card.last4)")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(card.name.isEmpty ? "Card" : card.name)
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.white)
                    HStack(spacing: 6) {
                        Text(card.type)
                            .font(.system(size: 9, weight: .bold))
                            .textCase(.uppercase)
                            .foregroundStyle(Color.white.opacity(0.4))
                        Text("•")
                            .foregroundStyle(Color.white.opacity(0.2))
                        Text(card.network)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.4))
                        Text("•")
                            .foregroundStyle(Color.white.opacity(0.2))
                        Text(card.expiry.isEmpty ? "—" : card.expiry)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                }
                Spacer()
                Circle()
                    .fill(card.status.statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: card.status.statusColor, radius: 4)
            }
            .padding(14)
            .glassCard(cornerRadius: 18)
        }
        .buttonStyle(.plain)
    }
}

private extension FinancialCard {
    var colorHex: String {
        switch network {
        case "Visa": return "#1A1F71"
        case "Mastercard": return "#8B0000"
        case "Amex": return "#007BC1"
        case "Discover": return "#FF6600"
        default: return "#2A2A2E"
        }
    }
}

// MARK: - Loan Card View
struct LoanCardView: View {
    let loan: Loan
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(loan.name.isEmpty ? "Loan" : loan.name)
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(.white)
                        Text(loan.lender.isEmpty ? "—" : loan.lender)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(loan.remainingBalance.currencyString)
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.zifrGold)
                        Text("remaining")
                            .zifrLabel()
                    }
                }

                // CiFr-style principal vs interest bar (gold / orange)
                VStack(spacing: 4) {
                    HStack {
                        Text("Principal")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.zifrGold)
                        Spacer()
                        Text("Interest")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.orange)
                    }
                    GeometryReader { geo in
                        let principal = loan.principalAmount > 0 ? loan.remainingBalance / loan.principalAmount : 0
                        let interest = 1.0 - principal
                        HStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.zifrGold)
                                .frame(width: geo.size.width * principal, height: 5)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.orange)
                                .frame(width: geo.size.width * interest, height: 5)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    .frame(height: 5)
                }

                HStack {
                    statBadge(label: "Monthly", value: loan.monthlyPayment.currencyString)
                    Spacer()
                    statBadge(label: "Rate", value: "\(loan.interestRate)%")
                    Spacer()
                    Text(loan.status)
                        .font(.system(size: 9, weight: .black))
                        .textCase(.uppercase)
                        .foregroundStyle(loan.status.statusColor)
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 20)
        }
        .buttonStyle(.plain)
    }

    private func statBadge(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).zifrLabel()
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Edit Sheets (Institution, Card, Loan)
struct EditInstitutionSheet: View {
    @Bindable var institution: Institution
    @Bindable var vm: AppViewModel
    let isNew: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    ZifrField(label: "Bank / Institution Name", placeholder: "Chase Bank", text: Binding(get: { institution.name }, set: { institution.name = $0 }))
                    ZifrField(label: "Login URL", placeholder: "chase.com/login", text: Binding(get: { institution.loginUrl }, set: { institution.loginUrl = $0 })).keyboardType(.URL)
                    ZifrField(label: "Username", placeholder: "username", text: Binding(get: { institution.username }, set: { institution.username = $0 }))
                    ZifrField(label: "Email", placeholder: "email@example.com", text: Binding(get: { institution.email }, set: { institution.email = $0 })).keyboardType(.emailAddress)
                    ZifrField(label: "Password", placeholder: "••••••••", text: Binding(get: { institution.password }, set: { institution.password = $0 }))

                    Divider().background(Color.white.opacity(0.06))

                    // Accounts
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Accounts").zifrLabel()
                            Spacer()
                            Button {
                                var accs = institution.accounts
                                accs.append(InstitutionAccount())
                                institution.accounts = accs
                            } label: {
                                Image(systemName: "plus").foregroundStyle(Color.zifrGold)
                            }
                        }
                        ForEach($institution.accounts) { $acc in
                            VStack(spacing: 8) {
                                HStack {
                                    TextField("Account name", text: $acc.name)
                                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                                    Spacer()
                                    Button { institution.accounts.removeAll { $0.id == acc.id } } label: {
                                        Image(systemName: "xmark").font(.system(size: 10)).foregroundStyle(Color.white.opacity(0.3))
                                    }
                                }
                                HStack(spacing: 8) {
                                    TextField("Last 4", text: $acc.last4).keyboardType(.numberPad)
                                        .font(.system(size: 12)).foregroundStyle(.white)
                                    TextField("Balance", value: $acc.balance, format: .currency(code: "USD"))
                                        .keyboardType(.decimalPad).font(.system(size: 12)).foregroundStyle(.white)
                                }
                                Picker("Type", selection: $acc.type) {
                                    ForEach(InstitutionAccount.allTypes, id: \.self) { Text($0).tag($0) }
                                }
                                .pickerStyle(.menu).foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    if !isNew {
                        if showDelete {
                            deleteConfirm {
                                vm.deleteInstitution(institution, context: context)
                                dismiss()
                            } cancel: { showDelete = false }
                        } else {
                            Button {
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                showDelete = true
                            } label: {
                                Label("Delete Institution", systemImage: "trash")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                        }
                    }
                }
                .padding(20).padding(.bottom, 40)
            }
            .background(Color(hex: "#1C1C1E"))
            .navigationTitle(isNew ? "New Institution" : "Edit Institution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isNew { vm.deleteInstitution(institution, context: context) }
                        dismiss()
                    }.foregroundStyle(Color.white.opacity(0.5))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { vm.saveInstitution(institution, context: context); dismiss() }
                        .font(.system(size: 15, weight: .black)).foregroundStyle(.white)
                }
            }
        }
    }
}

struct EditCardSheet: View {
    @Bindable var card: FinancialCard
    @Bindable var vm: AppViewModel
    let isNew: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ZifrField(label: "Nickname", placeholder: "Amex Gold", text: Binding(get: { card.name }, set: { card.name = $0 }))
                    ZifrField(label: "Institution", placeholder: "American Express", text: Binding(get: { card.institutionName }, set: { card.institutionName = $0 }))
                    ZifrField(label: "Card Holder", placeholder: "John Doe", text: Binding(get: { card.cardHolder }, set: { card.cardHolder = $0 }))
                    HStack(spacing: 12) {
                        ZifrField(label: "Last 4", placeholder: "1234", text: Binding(get: { card.last4 }, set: { card.last4 = $0 })).keyboardType(.numberPad)
                        ZifrField(label: "Expiry", placeholder: "12/28", text: Binding(get: { card.expiry }, set: { card.expiry = $0 })).keyboardType(.numbersAndPunctuation)
                    }
                    HStack(spacing: 12) {
                        pickerCell(label: "Network", sel: Binding(get: { card.network }, set: { card.network = $0 }), opts: FinancialCard.networks)
                        pickerCell(label: "Type", sel: Binding(get: { card.type }, set: { card.type = $0 }), opts: FinancialCard.types)
                        pickerCell(label: "Status", sel: Binding(get: { card.status }, set: { card.status = $0 }), opts: FinancialCard.statuses)
                    }
                    ZifrField(label: "Login", placeholder: "username / email", text: Binding(get: { card.login }, set: { card.login = $0 }))
                    ZifrField(label: "Password", placeholder: "••••••••", text: Binding(get: { card.password }, set: { card.password = $0 }))
                    if !isNew {
                        if showDelete {
                            deleteConfirm { vm.deleteCard(card, context: context); dismiss() } cancel: { showDelete = false }
                        } else {
                            Button {
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                showDelete = true
                            } label: {
                                Label("Delete Card", systemImage: "trash")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                        }
                    }
                }
                .padding(20).padding(.bottom, 40)
            }
            .background(Color(hex: "#1C1C1E"))
            .navigationTitle(isNew ? "New Card" : "Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if isNew { vm.deleteCard(card, context: context) }; dismiss() }
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { vm.saveCard(card, context: context); dismiss() }
                        .font(.system(size: 15, weight: .black)).foregroundStyle(.white)
                }
            }
        }
    }

    private func pickerCell(label: String, sel: Binding<String>, opts: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).zifrLabel()
            Picker(label, selection: sel) { ForEach(opts, id: \.self) { Text($0).tag($0) } }
                .pickerStyle(.menu).foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8).padding(.vertical, 8)
                .background(Color.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct EditLoanSheet: View {
    @Bindable var loan: Loan
    @Bindable var vm: AppViewModel
    let isNew: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ZifrField(label: "Loan Name", placeholder: "Startup Loan", text: Binding(get: { loan.name }, set: { loan.name = $0 }))
                    ZifrField(label: "Lender", placeholder: "Chase Bank", text: Binding(get: { loan.lender }, set: { loan.lender = $0 }))
                    HStack(spacing: 12) {
                        numField(label: "Principal", val: Binding(get: { loan.principalAmount }, set: { loan.principalAmount = $0 }))
                        numField(label: "Remaining", val: Binding(get: { loan.remainingBalance }, set: { loan.remainingBalance = $0 }))
                    }
                    HStack(spacing: 12) {
                        numField(label: "Monthly Payment", val: Binding(get: { loan.monthlyPayment }, set: { loan.monthlyPayment = $0 }))
                        numField(label: "Interest Rate", val: Binding(get: { loan.interestRate }, set: { loan.interestRate = $0 }))
                    }
                    HStack(spacing: 12) {
                        ZifrField(label: "Term", placeholder: "36 months", text: Binding(get: { loan.term }, set: { loan.term = $0 }))
                        ZifrField(label: "Start Date", placeholder: "MM/DD/YYYY", text: Binding(get: { loan.startDate }, set: { loan.startDate = $0 }))
                    }
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Role").zifrLabel()
                            Picker("Role", selection: Binding(get: { loan.role }, set: { loan.role = $0 })) {
                                ForEach(Loan.roles, id: \.self) { Text($0).tag($0) }
                            }.pickerStyle(.segmented)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Status").zifrLabel()
                            Picker("Status", selection: Binding(get: { loan.status }, set: { loan.status = $0 })) {
                                ForEach(Loan.statuses, id: \.self) { Text($0).tag($0) }
                            }.pickerStyle(.menu).foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8).padding(.vertical, 8)
                                .background(Color.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    if !isNew {
                        if showDelete {
                            deleteConfirm { vm.deleteLoan(loan, context: context); dismiss() } cancel: { showDelete = false }
                        } else {
                            Button {
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                showDelete = true
                            } label: {
                                Label("Delete Loan", systemImage: "trash")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                        }
                    }
                }
                .padding(20).padding(.bottom, 40)
            }
            .background(Color(hex: "#1C1C1E"))
            .navigationTitle(isNew ? "New Loan" : "Edit Loan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if isNew { vm.deleteLoan(loan, context: context) }; dismiss() }
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { vm.saveLoan(loan, context: context); dismiss() }
                        .font(.system(size: 15, weight: .black)).foregroundStyle(.white)
                }
            }
        }
    }

    private func numField(label: String, val: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).zifrLabel()
            TextField("0", value: val, format: .number)
                .keyboardType(.decimalPad)
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.07), lineWidth: 1))
        }
    }
}

// MARK: - Shared Delete Helpers

private func deleteConfirm(confirm: @escaping () -> Void, cancel: @escaping () -> Void) -> some View {
    HStack(spacing: 20) {
        Text("Sure?").font(.system(size: 12, weight: .bold)).foregroundStyle(.red)
        Button("Yes, Delete") { confirm() }
            .font(.system(size: 12, weight: .black)).foregroundStyle(.red)
        Button("Cancel") { cancel() }
            .font(.system(size: 12, weight: .bold)).foregroundStyle(Color.white.opacity(0.4))
    }
    .padding(14).glassCard(cornerRadius: 14)
}
