import SwiftUI
import SwiftData

// MARK: - Institution Account HUD
struct InstitutionAccountHUD: View {
    @Binding var draft: InstitutionAccount
    let isNew: Bool
    let institutionName: String
    var institutionId: UUID? = nil
    var availableCards: [FinancialCard] = []
    let companyId: UUID
    @Bindable var vm: AppViewModel
    let onSave: () -> Void
    let onCancel: () -> Void
    var onDelete: (() -> Void)? = nil
    
    @State private var initialDraft: InstitutionAccount? = nil
    @State private var showTransactions = false
    
    private var isDirty: Bool {
        guard let initial = initialDraft else { return isNew && !draft.name.isEmpty }
        return draft.name != initial.name ||
               draft.last4 != initial.last4 ||
               draft.type != initial.type ||
               draft.balance != initial.balance ||
               draft.accountNumber != initial.accountNumber ||
               draft.routingNumber != initial.routingNumber ||
               draft.wireRoutingNumber != initial.wireRoutingNumber ||
               draft.linkedCardId != initial.linkedCardId
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ZifrSheetCard(title: "ACCOUNT DETAILS", icon: "building.columns.fill") {
                        VStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("TYPE")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(Color.white.opacity(0.45))
                                Picker("", selection: $draft.type) {
                                    ForEach(InstitutionAccount.allTypes, id: \.self) { t in
                                        Text(t).tag(t)
                                    }
                                }
                                .labelsHidden()
                                .padding(.leading, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 44)
                                .background(Color(hex: "#2C2C2E"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                                .contentShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("LINKED DEBIT CARD")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(Color.white.opacity(0.45))
                                Picker("", selection: Binding(
                                    get: { draft.linkedCardId ?? "" },
                                    set: { draft.linkedCardId = $0.isEmpty ? nil : $0 }
                                )) {
                                    Text("None").tag("")
                                    ForEach(availableCards.filter { $0.type.lowercased().contains("debit") }) { card in
                                        Text("\(card.name.isEmpty ? "Card" : card.name) (•••• \(card.last4 ?? "0000"))").tag(card.id.uuidString)
                                    }
                                }
                                .labelsHidden()
                                .padding(.leading, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 44)
                                .background(Color(hex: "#2C2C2E"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                                .contentShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)

                            ZifrField(
                                label: "ACCOUNT NAME",
                                placeholder: "e.g. Primary Checking",
                                text: $draft.name
                            )

                            ZifrField(
                                label: "ACCOUNT NUMBER",
                                placeholder: "e.g. 1234567890",
                                text: Binding(
                                    get: { draft.accountNumber ?? "" },
                                    set: { newValue in
                                        draft.accountNumber = newValue
                                        let filtered = newValue.filter { $0.isNumber }
                                        if filtered.count >= 4 {
                                            draft.last4 = String(filtered.suffix(4))
                                        } else {
                                            draft.last4 = filtered
                                        }
                                    }
                                ),
                                keyboardType: .numberPad
                            )

                            ZifrField(
                                label: "ROUTING NUMBER",
                                placeholder: "e.g. 021000021",
                                text: Binding(
                                    get: { draft.routingNumber ?? "" },
                                    set: { draft.routingNumber = $0 }
                                ),
                                keyboardType: .numberPad
                            )

                            if !(draft.wireRoutingNumber ?? "").isEmpty {
                                ZifrField(
                                    label: "WIRE ROUTING NUMBER",
                                    placeholder: "Provided when different from ACH",
                                    text: Binding(
                                        get: { draft.wireRoutingNumber ?? "" },
                                        set: { draft.wireRoutingNumber = $0 }
                                    ),
                                    keyboardType: .numberPad
                                )
                            }

                            if draft.isTokenizedAccountNumber == true {
                                Label(
                                    "Plaid supplied a bank-issued tokenized ACH number. The recognizable account mask remains •••• \(draft.last4).",
                                    systemImage: "checkmark.shield.fill"
                                )
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.55))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("BALANCE")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(Color.white.opacity(0.45))
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
                                .background(Color(hex: "#2C2C2E"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                            }

                            if !isNew {
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    showTransactions = true
                                } label: {
                                    HStack {
                                        Text("TRANSACTIONS")
                                            .font(.system(size: 14, weight: .bold))
                                            .tracking(0.5)
                                            .foregroundStyle(.white)
                                        Spacer()
                                        Image(systemName: "receipt")
                                            .foregroundStyle(Color.white.opacity(0.4))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color(hex: "#2C2C2E"))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                                }
                                .buttonStyle(PremiumButtonStyle())
                                .padding(.top, 4)
                            }
                        }
                    }

                    if !isNew {
                        Button(role: .destructive) {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onDelete?()
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("Delete Account")
                                Spacer()
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.red)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(hex: "#1C1C1E"))
            .onAppear {
                initialDraft = draft
            }
            .sheet(isPresented: $showTransactions) {
                TransactionFeedView(
                    accountId: draft.plaidAccountId ?? draft.id,
                    companyId: companyId,
                    institutionId: institutionId,
                    vm: vm
                )
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(draft.name.isEmpty ? (isNew ? "Add Account" : "Edit Account") : draft.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(hex: "#C1AA78"))
                        Text(institutionName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    .padding(.top, 4)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .padding(.top, -6)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Save", action: onSave)
                        .fontWeight(.semibold)
                        .tint(isDirty ? .green : nil)
                        .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .padding(.top, -6)
                }
            }
        }
    }
}
