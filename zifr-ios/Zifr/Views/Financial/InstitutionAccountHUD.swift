import SwiftUI
import SwiftData

// MARK: - Institution Account HUD
struct InstitutionAccountHUD: View {
    @Binding var draft: InstitutionAccount
    let isNew: Bool
    let institutionName: String
    let onSave: () -> Void
    let onCancel: () -> Void
    var onDelete: (() -> Void)? = nil
    
    @State private var initialDraft: InstitutionAccount? = nil
    
    private var isDirty: Bool {
        guard let initial = initialDraft else { return isNew && !draft.name.isEmpty }
        return draft.name != initial.name ||
               draft.last4 != initial.last4 ||
               draft.type != initial.type ||
               draft.balance != initial.balance
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TYPE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.5))
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
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)

                    ZifrField(
                        label: "ACCOUNT NAME",
                        placeholder: "e.g. Primary Checking",
                        text: $draft.name
                    )
                    .padding(.vertical, 4)

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
                    .padding(.vertical, 4)

                    ZifrField(
                        label: "ROUTING NUMBER",
                        placeholder: "e.g. 021000021",
                        text: Binding(
                            get: { draft.routingNumber ?? "" },
                            set: { draft.routingNumber = $0 }
                        ),
                        keyboardType: .numberPad
                    )
                    .padding(.vertical, 4)

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
                        .background(Color(hex: "#2C2C2E"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)

                if !isNew {
                    Section {
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
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 20, trailing: 20))
                    .listRowSeparator(.hidden)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#1C1C1E"))
            .listSectionSpacing(0)
            .onAppear {
                initialDraft = draft
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(draft.name.isEmpty ? (isNew ? "Add Account" : "Edit Account") : draft.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        Text(institutionName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Save", action: onSave)
                        .fontWeight(.semibold)
                        .tint(isDirty ? .green : nil)
                        .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
