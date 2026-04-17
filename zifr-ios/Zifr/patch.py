import sys

file_path = "Views/Financial/FinancialView.swift"
with open(file_path, "r") as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    if i >= 604:
        break
    
    if ".sheet(item: $newInst) { i in EditInstitutionSheet(institution: i, vm: vm, isNew: true) }" in line:
        new_lines.append("        .sheet(item: $newInst) { i in EditInstitutionSheet(institution: i, cards: cards, loans: loans, vm: vm, isNew: true) }\n")
        continue

    if ".sheet(item: $editingInst) { i in EditInstitutionSheet(institution: i, vm: vm, isNew: false) }" in line:
        new_lines.append("        .sheet(item: $editingInst) { i in EditInstitutionSheet(institution: i, cards: cards, loans: loans, vm: vm, isNew: false) }\n")
        continue

    new_lines.append(line)

new_code = """// MARK: - Edit Institution Sheet
struct EditInstitutionSheet: View {
    @Bindable var institution: Institution
    let cards: [FinancialCard]
    let loans: [Loan]
    @Bindable var vm: AppViewModel
    let isNew: Bool

    @Environment(\\.modelContext) private var context
    @Environment(\\.dismiss) private var dismiss

    @State private var showDeleteConfirm = false
    @State private var showPassword = false

    private var instCards: [FinancialCard] {
        cards.filter { $0.institutionName.lowercased() == institution.name.lowercased() && !institution.name.isEmpty }
    }
    private var instLoans: [Loan] {
        loans.filter { $0.lender.lowercased() == institution.name.lowercased() && !institution.name.isEmpty }
    }

    @State private var showAccountHUD = false
    @State private var accountDraft = InstitutionAccount()
    @State private var accountDraftIndex: Int? = nil

    @State private var showCardHUD = false
    @State private var cardDraft: FinancialCard? = nil

    @State private var showLoanHUD = false
    @State private var loanDraft: Loan? = nil

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Bank Identity
                Section {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            ZifrField(
                                label: "INSTITUTION",
                                placeholder: "e.g. Chase",
                                text: Binding(get: { institution.name }, set: { institution.name = $0 })
                            )
                            ZifrField(
                                label: "WEBSITE",
                                placeholder: "chase.com",
                                text: Binding(get: { institution.loginUrl }, set: { institution.loginUrl = $0 }),
                                keyboardType: .URL
                            )
                            .textInputAutocapitalization(.never)
                        }

                        HStack(spacing: 12) {
                            ZifrField(
                                label: "LOGIN ID",
                                placeholder: "username",
                                text: Binding(get: { institution.username.isEmpty ? institution.email : institution.username }, set: { institution.username = $0 })
                            )
                            .textInputAutocapitalization(.never)

                            ZStack(alignment: .bottomTrailing) {
                                ZifrField(
                                    label: "PASSWORD",
                                    placeholder: "••••••••",
                                    text: Binding(get: { institution.password }, set: { institution.password = $0 }),
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
                    .padding(.vertical, 4)
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)

                Section {
                    Rectangle()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 1)
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                .listRowSeparator(.hidden)

                // MARK: - Accounts Section
                InstitutionAccountsSection(
                    institution: institution,
                    onAdd: {
                        accountDraft = InstitutionAccount()
                        accountDraftIndex = nil
                        showAccountHUD = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    },
                    onEdit: { idx, acc in
                        accountDraft = acc
                        accountDraftIndex = idx
                        showAccountHUD = true
                    }
                )

                // MARK: - Cards Section
                InstitutionCardsSection(
                    cards: instCards,
                    onAdd: {
                        cardDraft = vm.addCard(context: context, companyId: institution.companyId)
                        cardDraft?.institutionName = institution.name 
                        showCardHUD = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    },
                    onEdit: { card in
                        cardDraft = card
                        showCardHUD = true
                    },
                    onDelete: { card in
                        vm.deleteCard(card, context: context)
                    }
                )

                // MARK: - Loans Section
                InstitutionLoansSection(
                    loans: instLoans,
                    onAdd: {
                        loanDraft = vm.addLoan(context: context, companyId: institution.companyId)
                        loanDraft?.lender = institution.name 
                        showLoanHUD = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    },
                    onEdit: { loan in
                        loanDraft = loan
                        showLoanHUD = true
                    },
                    onDelete: { loan in
                        vm.deleteLoan(loan, context: context)
                    }
                )

                if !isNew {
                    Section {
                        Button(role: .destructive) {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete \\(institution.name.isEmpty ? "Institution" : institution.name)")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    }
                }

            }
            .scrollDismissesKeyboard(.interactively)
            .listSectionSpacing(0)
            .navigationTitle(institution.name.isEmpty ? "New Bank" : institution.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isNew { vm.deleteInstitution(institution, context: context) }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.saveInstitution(institution, context: context)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog(
                "Delete Bank?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Bank", role: .destructive) {
                    vm.deleteInstitution(institution, context: context)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
            .interactiveDismissDisabled(isNew)
            .sheet(isPresented: $showAccountHUD) {
                InstitutionAccountHUD(
                    draft: $accountDraft,
                    isNew: accountDraftIndex == nil,
                    onSave: {
                        var accs = institution.accounts
                        if let idx = accountDraftIndex {
                            accs[idx] = accountDraft
                        } else {
                            accs.append(accountDraft)
                        }
                        institution.accounts = accs
                        showAccountHUD = false
                    },
                    onCancel: { showAccountHUD = false }
                )
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
            .sheet(item: $cardDraft, onDismiss: { 
                cardDraft = nil 
            }) { cd in
                EditCardSheet(card: cd, vm: vm, isNew: cd.name.isEmpty && cd.last4.isEmpty)
            }
            .sheet(item: $loanDraft, onDismiss: { 
                loanDraft = nil 
            }) { ld in
                EditLoanSheet(loan: ld, vm: vm, isNew: ld.name.isEmpty && ld.monthlyPayment == 0)
            }
        }
    }
}

// MARK: - Institution Accounts Section
struct InstitutionAccountsSection: View {
    @Bindable var institution: Institution
    let onAdd: () -> Void
    let onEdit: (Int, InstitutionAccount) -> Void

    var body: some View {
        Section {
            VStack(spacing: 12) {
                Button { onAdd() } label: {
                    HStack {
                        Spacer()
                        Text("🏦  Add Account")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color(hex: "#1A1A1A"))
                        Spacer()
                    }
                    .frame(height: 40)
                    .background(Color(hex: "#F7F6F2"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                ForEach(institution.accounts.indices, id: \\.self) { i in
                    let acc = institution.accounts[i]
                    Button { onEdit(i, acc) } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(acc.type == "Credit Card" ? Color.orange : (acc.type == "Checking" ? Color.zifrGold : Color.green))
                                .frame(width: 8, height: 8)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(acc.name.isEmpty ? "Unnamed Account" : acc.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                HStack(spacing: 6) {
                                    Text(acc.type)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                    Text("·").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.2))
                                    Text("••\\(acc.last4)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.zifrGold)
                                }
                            }
                            Spacer()
                            Text(acc.balance.currencyString)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.2))
                                .padding(.leading, 4)
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
                                var accs = institution.accounts
                                accs.remove(at: i)
                                institution.accounts = accs
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

// MARK: - Institution Cards Section
struct InstitutionCardsSection: View {
    let cards: [FinancialCard]
    let onAdd: () -> Void
    let onEdit: (FinancialCard) -> Void
    let onDelete: (FinancialCard) -> Void

    var body: some View {
        Section {
            VStack(spacing: 12) {
                Button { onAdd() } label: {
                    HStack {
                        Spacer()
                        Text("💳  Add Card")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color(hex: "#1A1A1A"))
                        Spacer()
                    }
                    .frame(height: 40)
                    .background(Color(hex: "#F7F6F2"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                ForEach(cards, id: \\.id) { card in
                    Button { onEdit(card) } label: {
                        HStack(spacing: 12) {
                            Text("💳").font(.system(size: 18))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(card.name.isEmpty ? "Unnamed Card" : card.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                HStack(spacing: 6) {
                                    Text(card.type)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                    Text("·").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.2))
                                    Text(card.network)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                    Text("·").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.2))
                                    Text("••\\(card.last4)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                }
                            }
                            Spacer()
                            Text(card.status.uppercased())
                                .font(.system(size: 9, weight: .black))
                                .tracking(0.5)
                                .foregroundStyle(card.status == "Active" ? Color.green : (card.status == "Frozen" ? Color.orange : Color.red))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background((card.status == "Active" ? Color.green : (card.status == "Frozen" ? Color.orange : Color.red)).opacity(0.12))
                                .clipShape(Capsule())
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.2))
                                .padding(.leading, 4)
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
                            withAnimation { onDelete(card) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        } header: { EmptyView() }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
        .listRowSeparator(.hidden)
    }
}

// MARK: - Institution Loans Section
struct InstitutionLoansSection: View {
    let loans: [Loan]
    let onAdd: () -> Void
    let onEdit: (Loan) -> Void
    let onDelete: (Loan) -> Void

    var body: some View {
        Section {
            VStack(spacing: 12) {
                Button { onAdd() } label: {
                    HStack {
                        Spacer()
                        Text("💸  Add Loan")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color(hex: "#1A1A1A"))
                        Spacer()
                    }
                    .frame(height: 40)
                    .background(Color(hex: "#F7F6F2"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                ForEach(loans, id: \\.id) { loan in
                    Button { onEdit(loan) } label: {
                        HStack(spacing: 12) {
                            Text("💸").font(.system(size: 18))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(loan.name.isEmpty ? "Unnamed Loan" : loan.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                HStack(spacing: 6) {
                                    Text("\\(loan.interestRate, specifier: "%.2f")% APR")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                    Text("·").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.2))
                                    Text(loan.monthlyPayment.currencyString + "/mo")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                }
                            }
                            Spacer()
                            Text(loan.remainingBalance.currencyString)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.zifrGold)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.2))
                                .padding(.leading, 4)
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
                            withAnimation { onDelete(loan) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        } header: { EmptyView() }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
        .listRowSeparator(.hidden)
    }
}

// MARK: - Institution Account HUD
struct InstitutionAccountHUD: View {
    @Binding var draft: InstitutionAccount
    let isNew: Bool
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            ZifrField(
                                label: "ACCOUNT NAME",
                                placeholder: "e.g. Primary Checking",
                                text: $draft.name
                            )
                            ZifrField(
                                label: "LAST 4",
                                placeholder: "1234",
                                text: $draft.last4,
                                keyboardType: .numberPad
                            )
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("TYPE")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                Picker("", selection: $draft.type) {
                                    ForEach(InstitutionAccount.allTypes, id: \\.self) { t in
                                        Text(t).tag(t)
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

                            VStack(alignment: .leading, spacing: 4) {
                                Text("BALANCE")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                HStack(spacing: 4) {
                                    Text("$")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                    DoubleField(placeholder: "0.00", value: $draft.balance)
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
                    }
                    .padding(.vertical, 4)
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)
            }
            .scrollDismissesKeyboard(.interactively)
            .listSectionSpacing(0)
            .navigationTitle(isNew ? "Add Account" : "Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Edit Card Sheet
struct EditCardSheet: View {
    @Bindable var card: FinancialCard
    @Bindable var vm: AppViewModel
    let isNew: Bool
    @Environment(\\.modelContext) private var context
    @Environment(\\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            ZifrField(label: "CARD NICKNAME", placeholder: "e.g. Sapphire", text: Binding(get: { card.name }, set: { card.name = $0 }))
                            ZifrField(label: "LAST 4", placeholder: "1234", text: Binding(get: { card.last4 }, set: { card.last4 = $0 }), keyboardType: .numberPad)
                        }

                        HStack(spacing: 12) {
                            cardPicker(label: "TYPE", sel: Binding(get: { card.type }, set: { card.type = $0 }), opts: FinancialCard.types)
                            cardPicker(label: "AUTOPAY", sel: Binding(get: { card.autopay }, set: { card.autopay = $0 }), opts: FinancialCard.autopayOptions)
                        }

                        HStack(spacing: 12) {
                            ZifrField(label: "NAME ON CARD", placeholder: "Jane Doe", text: Binding(get: { card.cardHolder }, set: { card.cardHolder = $0 }))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ROLE")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                HStack(spacing: 0) {
                                    Button(action: { card.cardHolderType = "Mine" }) {
                                        Text("MINE")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(card.cardHolderType == "Mine" ? .black : .white)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .background(card.cardHolderType == "Mine" ? .white : Color.clear)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    Button(action: { card.cardHolderType = "Assigned" }) {
                                        Text("ASSIGNED")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(card.cardHolderType == "Assigned" ? .black : .white)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .background(card.cardHolderType == "Assigned" ? .white : Color.clear)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                                .padding(2)
                                .frame(height: 44)
                                .background(Color(hex: "#111111"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("STATUS")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                Picker("", selection: Binding(get: { card.status }, set: { card.status = $0 })) {
                                    ForEach(FinancialCard.statuses, id: \\.self) { t in
                                        Text(t).tag(t)
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

                            ZifrField(label: "EXPIRY", placeholder: "MM/YY", text: Binding(get: { card.expiry }, set: { card.expiry = $0 }))
                        }

                        HStack(spacing: 12) {
                            moneyField(label: "BALANCE", value: Binding(get: { card.balance }, set: { card.balance = $0 }))
                            moneyField(label: "CREDIT LIMIT", value: Binding(get: { card.limit }, set: { card.limit = $0 }))
                        }

                        HStack(spacing: 12) {
                            moneyField(label: "MO. PAYMENT", value: Binding(get: { card.moPayment }, set: { card.moPayment = $0 }))
                            Color.clear.frame(maxWidth: .infinity)
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
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete \\(card.name.isEmpty ? "Card" : card.name)")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .listSectionSpacing(0)
            .navigationTitle(isNew ? "New Card" : card.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isNew { vm.deleteCard(card, context: context) }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.saveCard(card, context: context)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog("Delete Card?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete Card", role: .destructive) {
                    vm.deleteCard(card, context: context)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
            .interactiveDismissDisabled(isNew)
        }
    }

    private func cardPicker(label: String, sel: Binding<String>, opts: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            Picker("", selection: sel) {
                ForEach(opts, id: \\.self) { t in
                    Text(t).tag(t)
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

// MARK: - Edit Loan Sheet
struct EditLoanSheet: View {
    @Bindable var loan: Loan
    @Bindable var vm: AppViewModel
    let isNew: Bool
    @Environment(\\.modelContext) private var context
    @Environment(\\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            ZifrField(label: "LOAN NAME", placeholder: "e.g. Startup Loan", text: Binding(get: { loan.name }, set: { loan.name = $0 }))
                            ZifrField(label: "LENDER", placeholder: "e.g. Chase", text: Binding(get: { loan.lender }, set: { loan.lender = $0 }))
                        }

                        HStack(spacing: 12) {
                            moneyField(label: "PRINCIPAL", value: Binding(get: { loan.principalAmount }, set: { loan.principalAmount = $0 }))
                            moneyField(label: "REMAINING", value: Binding(get: { loan.remainingBalance }, set: { loan.remainingBalance = $0 }))
                        }

                        HStack(spacing: 12) {
                            moneyField(label: "MO. PAYMENT", value: Binding(get: { loan.monthlyPayment }, set: { loan.monthlyPayment = $0 }))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("RATE(%)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                HStack(spacing: 4) {
                                    DoubleField(placeholder: "0.00", value: Binding(get: { loan.interestRate }, set: { loan.interestRate = $0 }))
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

                        HStack(spacing: 12) {
                            ZifrField(label: "TERM", placeholder: "36 months", text: Binding(get: { loan.term }, set: { loan.term = $0 }))
                            ZifrField(label: "START DATE", placeholder: "MM/DD/YYYY", text: Binding(get: { loan.startDate }, set: { loan.startDate = $0 }))
                        }

                        HStack(spacing: 12) {
                            loanPicker(label: "ROLE", sel: Binding(get: { loan.role }, set: { loan.role = $0 }), opts: Loan.roles)
                            loanPicker(label: "STATUS", sel: Binding(get: { loan.status }, set: { loan.status = $0 }), opts: Loan.statuses)
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
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete \\(loan.name.isEmpty ? "Loan" : loan.name)")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .listSectionSpacing(0)
            .navigationTitle(isNew ? "New Loan" : loan.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isNew { vm.deleteLoan(loan, context: context) }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.saveLoan(loan, context: context)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog("Delete Loan?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete Loan", role: .destructive) {
                    vm.deleteLoan(loan, context: context)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
            .interactiveDismissDisabled(isNew)
        }
    }

    private func loanPicker(label: String, sel: Binding<String>, opts: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            Picker("", selection: sel) {
                ForEach(opts, id: \\.self) { t in
                    Text(t).tag(t)
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
"""

with open(file_path, "w") as f:
    f.writelines(new_lines)
    f.write(new_code)
