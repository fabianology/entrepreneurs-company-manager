import SwiftUI
import SwiftData

struct AddAccountSheet: View {
    let companyId: String
    let institutions: [Institution]
    @Bindable var vm: AppViewModel
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Query private var allSubscriptions: [Subscription]
    
    private var allLogins: [String] {
        let subLogins = allSubscriptions.map { $0.loginId }
        let instUsers = institutions.map { $0.username }
        let instEmails = institutions.map { $0.email }
        return (subLogins + instUsers + instEmails).filter { !$0.isEmpty }
    }
    
    // Account Draft
    @State private var accountName: String = ""
    @State private var accountType: String = "Checking"
    
    @State private var isEditingInstitution = true
    
    // Institution Selection
    @State private var selectedInstitutionId: String = "new"
    
    // Institution Draft
    @State private var institutionName: String = ""
    @State private var website: String = ""
    @State private var login: String = ""
    @State private var pass: String = ""
    @State private var email: String = ""
    @State private var twoFactor: String = ""
    
    @State private var showPassword = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Account Info
                Section {
                    VStack(spacing: 16) {
                        ZifrField(
                            label: "ACCOUNT NAME",
                            placeholder: "e.g. Primary Checking",
                            text: $accountName
                        )
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ACCOUNT TYPE")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(0.5)
                                .foregroundStyle(Color.white.opacity(0.5))
                            
                            Menu {
                                ForEach(InstitutionAccount.allTypes, id: \.self) { type in
                                    Button(type) { accountType = type }
                                }
                            } label: {
                                HStack {
                                    Text(accountType)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.white)
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
                        }
                    }
                    .padding(.vertical, 4)
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)
                
                // Institution Selection
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FINANCIAL INSTITUTION")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(Color.white.opacity(0.5))
                        
                        Menu {
                            Button("New Institution") {
                                selectedInstitutionId = "new"
                                populateInstitutionFields(from: nil)
                            }
                            Divider()
                            ForEach(institutions) { inst in
                                Button(inst.name.isEmpty ? "Unnamed Institution" : inst.name) {
                                    selectedInstitutionId = inst.id
                                    populateInstitutionFields(from: inst)
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedInstitutionName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white)
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
                    }
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)
                
                // Institution Details
                Section {
                    VStack(spacing: 16) {
                        if selectedInstitutionId != "new" {
                            HStack {
                                Text("INSTITUTION DETAILS")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(0.5)
                                    .foregroundStyle(Color.white.opacity(0.5))
                                Spacer()
                                Button {
                                    withAnimation {
                                        isEditingInstitution.toggle()
                                    }
                                } label: {
                                    Image(systemName: isEditingInstitution ? "lock.open.fill" : "lock.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(isEditingInstitution ? Color.green : Color.white.opacity(0.4))
                                }
                            }
                            .padding(.bottom, 4)
                        }

                        Group {
                            if selectedInstitutionId == "new" {
                                VStack(alignment: .leading, spacing: 8) {
                                    ZifrField(
                                        label: "INSTITUTION NAME",
                                        placeholder: "e.g. Chase",
                                        text: $institutionName
                                    )
                                    
                                    let matches = institutions.filter { $0.name.lowercased().contains(institutionName.lowercased()) && $0.name.lowercased() != institutionName.lowercased() }
                                    
                                    if !matches.isEmpty && !institutionName.isEmpty {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 8) {
                                                ForEach(matches.prefix(3)) { inst in
                                                    Button {
                                                        selectedInstitutionId = inst.id
                                                        institutionName = inst.name
                                                        website = inst.loginUrl
                                                        login = inst.username
                                                        pass = inst.password
                                                        email = inst.email
                                                        twoFactor = inst.twoFactor
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
                            
                            ZifrField(
                                label: "WEBSITE",
                                placeholder: "chase.com",
                                text: $website,
                                keyboardType: .URL,
                                textContentType: .URL
                            )
                            .textInputAutocapitalization(.never)
                            
                            HStack(spacing: 12) {
                                ZifrAutocompleteField(
                                    label: "LOGIN ID",
                                    placeholder: "username",
                                    text: $login,
                                    keyboardType: .emailAddress,
                                    suggestions: allLogins
                                )
                                
                                ZStack(alignment: .bottomTrailing) {
                                    ZifrField(
                                        label: "PASSWORD",
                                        placeholder: "••••••••",
                                        text: $pass,
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
                                    .disabled(!isEditingInstitution)
                                }
                            }
                            
                            HStack(spacing: 12) {
                                ZifrAutocompleteField(
                                    label: "EMAIL",
                                    placeholder: "name@company.com",
                                    text: $email,
                                    keyboardType: .emailAddress,
                                    textContentType: .emailAddress,
                                    suggestions: allLogins
                                )

                                ZifrField(
                                    label: "2FA",
                                    placeholder: "Phone or App",
                                    text: $twoFactor
                                )
                            }
                        }
                        .disabled(!isEditingInstitution)
                        .opacity(!isEditingInstitution ? 0.6 : 1.0)
                    }
                    .padding(.vertical, 4)
                } header: { EmptyView() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#171717"))
            .listSectionSpacing(0)
            .navigationTitle("Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAccount() }
                    .fontWeight(.semibold)
                    .tint(!accountName.isEmpty ? .green : nil)
                }
            }
        }
    }
    
    private var selectedInstitutionName: String {
        if selectedInstitutionId == "new" {
            return "New Institution"
        } else if let inst = institutions.first(where: { $0.id == selectedInstitutionId }) {
            return inst.name.isEmpty ? "Unnamed Institution" : inst.name
        }
        return "Select Institution"
    }
    
    private func populateInstitutionFields(from inst: Institution?) {
        if let inst = inst {
            institutionName = inst.name
            website = inst.loginUrl
            login = inst.username
            pass = inst.password
            email = inst.email
            twoFactor = inst.twoFactor
            isEditingInstitution = false
        } else {
            institutionName = ""
            website = ""
            login = ""
            pass = ""
            email = ""
            twoFactor = ""
            isEditingInstitution = true
        }
    }
    
    private func saveAccount() {
        var targetInstitution: Institution
        
        if selectedInstitutionId == "new" {
            let newInst = vm.addInstitution(context: context, companyId: companyId)
            newInst.name = institutionName
            newInst.loginUrl = website
            newInst.username = login
            newInst.email = email
            newInst.password = pass
            newInst.twoFactor = twoFactor
            targetInstitution = newInst
        } else if let existing = institutions.first(where: { $0.id == selectedInstitutionId }) {
            targetInstitution = existing
            targetInstitution.loginUrl = website
            targetInstitution.username = login
            targetInstitution.email = email
            targetInstitution.password = pass
            targetInstitution.twoFactor = twoFactor
        } else {
            return
        }
        
        var newAccount = InstitutionAccount()
        newAccount.name = accountName
        newAccount.type = accountType
        
        var accounts = targetInstitution.accounts
        accounts.append(newAccount)
        targetInstitution.accounts = accounts
        
        vm.saveInstitution(targetInstitution, context: context)
        
        dismiss()
    }
}
