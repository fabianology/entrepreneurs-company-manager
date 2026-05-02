import SwiftUI
import SwiftData

// MARK: - Edit Institution Sheet
struct EditInstitutionSheet: View {
    @State var institution: Institution
    let institutions: [Institution]
    let cards: [FinancialCard]
    let loans: [Loan]
    @Bindable var vm: AppViewModel
    let isNew: Bool

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    private var allSubscriptions: [Subscription] { appState.subscriptions }

    @State private var showDeleteConfirm = false
    @State private var showPassword = false
    @State private var showShareSheet = false
    
    struct Snapshot: Equatable {
        var name, loginUrl, username, email, password, twoFactor: String
    }
    @State private var snapshot: Snapshot?

    private var currentSnapshot: Snapshot {
        Snapshot(name: institution.name ?? "", loginUrl: institution.loginUrl ?? "", username: institution.username ?? "", email: institution.email ?? "", password: institution.password ?? "", twoFactor: institution.twoFactor ?? "")
    }

    private var isDirty: Bool {
        guard let snap = snapshot else { return isNew && !institution.name.trimmingCharacters(in: .whitespaces).isEmpty }
        return snap != currentSnapshot
    }

    private var instCards: [FinancialCard] {
        cards.filter { ($0.institutionName ?? "").lowercased() == (institution.name ?? "").lowercased() && !(institution.name ?? "").isEmpty }
    }
    private var instLoans: [Loan] {
        loans.filter { ($0.lender ?? "").lowercased() == (institution.name ?? "").lowercased() && !(institution.name ?? "").isEmpty }
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
                                text: Binding(get: { institution.loginUrl ?? "" }, set: { institution.loginUrl = $0 }),
                                keyboardType: .URL,
                                textContentType: .URL
                            )
                            .textInputAutocapitalization(.never)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                ZifrAutocompleteField(
                                    label: "LOGIN ID",
                                    placeholder: "username",
                                    text: Binding(
                                        get: { (institution.username ?? "").isEmpty ? (institution.email ?? "") : (institution.username ?? "") },
                                        set: { newValue in
                                            let old = institution.username
                                            institution.username = newValue
                                            if newValue.contains("@") && ((institution.email ?? "").isEmpty || institution.email == old) {
                                                institution.email = newValue
                                            }
                                        }
                                    ),
                                    keyboardType: .emailAddress
                                )

                                ZStack(alignment: .bottomTrailing) {
                                    ZifrField(
                                        label: "PASSWORD",
                                        placeholder: "••••••••",
                                        text: Binding(get: { institution.password ?? "" }, set: { institution.password = $0 }),
                                        isSecure: !showPassword,
                                        textContentType: .password
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
                            
                            let loginValue = (institution.username ?? "").isEmpty ? (institution.email ?? "") : (institution.username ?? "")
                            DynamicLoginLabelView(loginId: loginValue, ignoreInstitutionId: institution.id.uuidString)
                        }
                        
                        HStack(spacing: 12) {
                            ZifrField(
                                label: "EMAIL",
                                placeholder: "name@company.com",
                                text: Binding(get: { institution.email ?? "" }, set: { institution.email = $0 }),
                                keyboardType: .emailAddress,
                                textContentType: .emailAddress
                            )
                            .textInputAutocapitalization(.never)

                            ZifrField(
                                label: "2FA",
                                placeholder: "Phone or App",
                                text: Binding(get: { institution.twoFactor ?? "" }, set: { institution.twoFactor = $0 })
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
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
                    vm: vm,
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

                Section {
                    Rectangle()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 1)
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                .listRowSeparator(.hidden)

                // MARK: - Cards Section
                InstitutionCardsSection(
                    cards: instCards,
                    onAdd: {
                        cardDraft = vm.addCard(appState: appState, userId: institution.userId, companyId: institution.companyId)
                        cardDraft?.institutionName = institution.name 
                        showCardHUD = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    },
                    onEdit: { card in
                        cardDraft = card
                        showCardHUD = true
                    },
                    onDelete: { card in
                        vm.deleteCard(card, appState: appState)
                    }
                )

                Section {
                    Rectangle()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 1)
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                .listRowSeparator(.hidden)

                // MARK: - Loans Section
                InstitutionLoansSection(
                    loans: instLoans,
                    onAdd: {
                        loanDraft = vm.addLoan(appState: appState, userId: institution.userId, companyId: institution.companyId)
                        loanDraft?.lender = institution.name 
                        showLoanHUD = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    },
                    onEdit: { loan in
                        loanDraft = loan
                        showLoanHUD = true
                    },
                    onDelete: { loan in
                        vm.deleteLoan(loan, appState: appState)
                    }
                )

                if !isNew {
                    Section {
                        // Share Institution
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showShareSheet = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "person.crop.circle.badge.plus")
                                Text("Share Institution")
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

                        // Delete Institution
                        Button(role: .destructive) {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("Delete \(institution.name.isEmpty ? "Institution" : institution.name)")
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
                            "Delete Bank?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible
                        ) {
                            Button("Delete Bank", role: .destructive) {
                                vm.deleteInstitution(institution, appState: appState)
                                dismiss()
                            }
                            Button("Cancel", role: .cancel) {}
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
            }
            .navigationTitle(institution.name.isEmpty ? "Institution" : institution.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        
                        if isNew { 
                            vm.deleteInstitution(institution, appState: appState) 
                        } else if let snap = snapshot {
                            institution.name = snap.name
                            institution.loginUrl = snap.loginUrl
                            institution.username = snap.username
                            institution.email = snap.email
                            institution.password = snap.password
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add Account" : "Save") {
                        vm.saveInstitution(institution, appState: appState)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(isDirty ? .green : nil)
                }
            }
            .interactiveDismissDisabled(isNew)
            .sheet(isPresented: $showShareSheet) {
                ShareEntitySheet(resourceId: institution.id, resourceType: "institution", resourceTitle: institution.name.isEmpty ? "Institution" : institution.name)
            }
            .sheet(isPresented: $showAccountHUD) {
                InstitutionAccountHUD(
                    draft: $accountDraft,
                    isNew: accountDraftIndex == nil,
                    institutionName: institution.name.isEmpty ? "Institution" : institution.name,
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
                    onCancel: { showAccountHUD = false },
                    onDelete: {
                        if let idx = accountDraftIndex {
                            let acc = institution.accounts[idx]
                            vm.cleanUpCustomPaymentMethod(name: acc.name.isEmpty ? acc.type : acc.name)
                            institution.accounts.remove(at: idx)
                        }
                        showAccountHUD = false
                    }
                )
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
            .sheet(item: $cardDraft, onDismiss: { 
                cardDraft = nil 
            }) { cd in
                EditCardSheet(card: cd, vm: vm, institutions: institutions, cards: cards, isNew: (cd.name ?? "").isEmpty && (cd.last4 ?? "").isEmpty, isInstitutionContext: true)
            }
            .sheet(item: $loanDraft, onDismiss: { 
                loanDraft = nil 
            }) { ld in
                EditLoanSheet(loan: ld, vm: vm, isNew: ld.name.isEmpty && ld.monthlyPayment == 0, institutions: institutions, cards: cards, isInstitutionContext: true)
            }
        }
    }
}
