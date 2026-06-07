import SwiftUI
import SwiftData
// MARK: - Institution Card
struct InstitutionCardView: View {
    @Environment(AppState.self) private var appState
    let institution: Institution
    let totalMonthlyPayment: Double
    let cardCount: Int
    let loanCount: Int
    let loans: [Loan]
    @Bindable var vm: AppViewModel
    let onEdit: () -> Void
    let onEditLoan: (Loan) -> Void
    @State private var expanded = false
    @State private var copiedField: String? = nil
    @State private var passwordRevealed = false

    @State private var editingAccount: InstitutionAccount? = nil
    @State private var accountDraft = InstitutionAccount()

    var body: some View {
        MiloomListCard {
            // ── Tappable header (triggers edit sheet) ──────────────────────
            Button(action: onEdit) {
                VStack(spacing: 0) {
                    HStack(alignment: .center, spacing: 16) {
                        if let loginUrl = institution.loginUrl, !loginUrl.isEmpty {
                            FaviconImage(website: loginUrl, size: 40)
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
                                Image(systemName: "building.columns")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.8))
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(institution.name.isEmpty ? "Bank" : institution.name)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)

                            HStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Text("\(institution.accounts.count)").foregroundStyle(.white)
                                    Text("Accounts").foregroundStyle(Color(hex: "#C1AA78"))
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(0.3)
                                
                                statusPipe()
                                
                                HStack(spacing: 4) {
                                    Text("\(cardCount)").foregroundStyle(.white)
                                    Text("Cards").foregroundStyle(Color(hex: "#C1AA78"))
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(0.3)
                                
                                statusPipe()
                                
                                HStack(spacing: 4) {
                                    Text("\(loanCount)").foregroundStyle(.white)
                                    Text("Loans").foregroundStyle(Color(hex: "#C1AA78"))
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(0.3)
                                
                                if let syncedDate = institution.lastSyncedAt {
                                    statusPipe()
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                        Text(syncedDate, style: .relative)
                                            .foregroundStyle(Color(hex: "#C1AA78"))
                                    }
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.4))
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                    .background(
                        UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 24)
                            .fill(Color.black)
                            .overlay(
                                UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 24)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )

                    // ── Credentials (tap-to-copy) ────
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            copyableCredential(
                                id: institution.id.uuidString,
                                label: "Login ID",
                                value: (institution.username ?? "").isEmpty ? ((institution.email ?? "").isEmpty ? "—" : (institution.email ?? "")) : (institution.username ?? ""),
                                field: "login"
                            )
                            copyableCredential(
                                id: institution.id.uuidString,
                                label: "Password",
                                value: institution.password ?? "",
                                field: "password",
                                isPassword: true
                            )
                        }
                        
                        let loginValue = (institution.username ?? "").isEmpty ? (institution.email ?? "") : (institution.username ?? "")
                        DynamicLoginLabelView(loginId: loginValue, ignoreInstitutionId: institution.id.uuidString)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, institution.isDisconnected ? 16 : 24)
                    
                    if institution.isDisconnected {
                        PlaidLinkButton(
                            companyId: institution.companyId,
                            institutionId: institution.id,
                            buttonText: "Reconnect Bank",
                            isReconnect: true,
                            onSuccess: { _, _, _ in
                                var updatedInst = institution
                                updatedInst.isDisconnected = false
                                vm.saveInstitution(updatedInst, appState: appState)
                            }
                        )
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PremiumButtonStyle())

            // ── Accordion ──────────────────────────────────────────────────
            MiloomAccordion(title: expanded ? "Hide Accounts" : "Loans & Accounts", count: institution.accounts.count + loanCount, expanded: expanded, action: {
                withAnimation(.spring(response: 0.35)) { expanded.toggle() }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                VStack(spacing: 0) {
                    ForEach(institution.accounts) { acc in
                        Button {
                            accountDraft = acc
                            editingAccount = acc
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            VStack(spacing: 0) {
                                HStack(alignment: .firstTextBaseline) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Text("-")
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundStyle(Color(hex: "#C1AA78"))
                                            Text(acc.name.isEmpty ? "Account" : acc.name)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(.white)
                                        }
                                        
                                        HStack(spacing: 6) {
                                            Text(acc.type)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(Color.white.opacity(0.6))
                                        }
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(acc.balance.currencyString)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                                .background(Color.clear)
                                
                                if acc.id != institution.accounts.last?.id || !loans.isEmpty {
                                    Divider()
                                        .background(Color.white.opacity(0.06))
                                        .padding(.horizontal, 8)
                                }
                            }
                        }
                        .buttonStyle(PremiumButtonStyle())
                    }

                    ForEach(loans) { loan in
                        Button {
                            onEditLoan(loan)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            VStack(spacing: 0) {
                                HStack(alignment: .firstTextBaseline) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Text("-")
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundStyle(Color(hex: "#C1AA78"))
                                            Text((loan.name ?? "").isEmpty ? "Loan" : loan.name)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(.white)
                                        }
                                        
                                        HStack(spacing: 6) {
                                            Text(loan.role)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(Color.white.opacity(0.6))
                                            Text("|")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(Color.white.opacity(0.2))
                                            let rateStr = String(format: loan.interestRate.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f%%" : "%.2f%%", loan.interestRate)
                                            Text("\(rateStr) APR")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(Color.white.opacity(0.6))
                                        }

                                        if let notes = loan.notes, !notes.isEmpty {
                                            HStack(spacing: 6) {
                                                Text("PURPOSE:")
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundStyle(Color.white.opacity(0.4))
                                                Text(notes)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundStyle(Color.white.opacity(0.6))
                                            }
                                        }
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(loan.principalAmount.currencyString)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                                .background(Color.clear)
                                
                                if loan.id != loans.last?.id {
                                    Divider()
                                        .background(Color.white.opacity(0.06))
                                        .padding(.horizontal, 8)
                                }
                            }
                        }
                        .buttonStyle(PremiumButtonStyle())
                    }
                }
            }
        }
        .sheet(item: $editingAccount) { _ in
            InstitutionAccountHUD(
                draft: $accountDraft,
                isNew: false,
                institutionName: institution.name.isEmpty ? "Bank" : institution.name,
                onSave: {
                    if let idx = institution.accounts.firstIndex(where: { $0.id == accountDraft.id }) {
                        var updatedInst = institution
                        updatedInst.accounts[idx] = accountDraft
                        vm.saveInstitution(updatedInst, appState: appState)
                    }
                    editingAccount = nil
                },
                onCancel: { editingAccount = nil },
                onDelete: {
                    if let idx = institution.accounts.firstIndex(where: { $0.id == accountDraft.id }) {
                        let acc = institution.accounts[idx]
                        vm.cleanUpCustomPaymentMethod(name: acc.name.isEmpty ? acc.type : acc.name)
                        var updatedInst = institution
                        updatedInst.accounts.remove(at: idx)
                        vm.saveInstitution(updatedInst, appState: appState)
                    }
                    editingAccount = nil
                }
            )
            .presentationDetents([.height(420)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
    }

    private func costColumn(value: Double, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("$\(String(format: "%.0f", value))")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(hex: "#C1AA78"))
        }
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
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
            }
            .buttonStyle(PremiumButtonStyle())
            .proContextMenu(password: institution.password, loginId: (institution.username ?? "").isEmpty ? (institution.email ?? "") : (institution.username ?? ""), last4: nil)
        }
    }
}

