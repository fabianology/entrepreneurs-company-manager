import SwiftUI

struct FinancialCardHUD: View {
    @Binding var draft: FinancialCard
    let isNew: Bool
    let institutionName: String
    let onSave: () -> Void
    let onCancel: () -> Void
    var onDelete: (() -> Void)? = nil
    
    @State private var initialDraft: FinancialCard? = nil
    
    private var isDirty: Bool {
        guard let initial = initialDraft else { return isNew && !draft.name.isEmpty }
        return draft.name != initial.name ||
               draft.cardHolder != initial.cardHolder ||
               draft.last4 != initial.last4 ||
               draft.network != initial.network ||
               draft.type != initial.type ||
               draft.limit != initial.limit ||
               draft.balance != initial.balance ||
               draft.apr != initial.apr ||
               draft.autopay != initial.autopay
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        ZifrField(label: "CARD NICKNAME", placeholder: "e.g. Sapphire", text: $draft.name)
                        ZifrField(label: "NAME ON CARD", placeholder: "Jane Doe", text: Binding(get: { draft.cardHolder ?? "" }, set: { draft.cardHolder = $0 }), textContentType: .name)
                    }
                    .padding(.vertical, 4)

                    ZifrField(label: "CARD NUMBER", placeholder: "0000 0000 0000 0000", text: Binding(get: { draft.cardNumber ?? "" }, set: { draft.cardNumber = $0 }), keyboardType: .numberPad)
                        .onChange(of: draft.cardNumber) { old, new in
                            let newStr = new ?? ""
                            let filtered = newStr.filter { $0.isNumber }
                            if (draft.cardNumber ?? "") != filtered { draft.cardNumber = filtered }
                            
                            if let first = filtered.first {
                                if first == "4" { draft.network = "Visa" }
                                else if first == "5" { draft.network = "Mastercard" }
                                else if first == "3" { draft.network = "Amex" }
                                else if first == "6" { draft.network = "Discover" }
                            }
                            
                            let maxLen = draft.network == "Amex" ? 5 : 4
                            if filtered.count >= maxLen {
                                draft.last4 = String(filtered.suffix(maxLen))
                            } else {
                                draft.last4 = filtered
                            }
                        }
                        .padding(.vertical, 4)

                    HStack(spacing: 12) {
                        cardPicker(label: "TYPE", sel: $draft.type, opts: FinancialCard.types)
                        cardPicker(label: "NETWORK", sel: $draft.network, opts: FinancialCard.networks)
                    }
                    .padding(.vertical, 4)

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ROLE")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.45))
                            VStack(spacing: 0) {
                                Spacer()
                                CustomSegmentedControl(
                                    options: ["Mine", "Assigned"],
                                    selection: Binding(get: { draft.cardHolderType ?? "Mine" }, set: { draft.cardHolderType = $0 })
                                )
                                .labelsHidden()
                                Spacer()
                            }
                            .frame(height: 44)
                        }
                        
                        ZifrField(label: "EXPIRES", placeholder: "MM/YY", text: Binding(get: { draft.expiry ?? "" }, set: { draft.expiry = $0 }), keyboardType: .numberPad)
                            .onChange(of: draft.expiry) { old, new in
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
                                if (draft.expiry ?? "") != filtered { draft.expiry = filtered }
                            }
                    }
                    .padding(.vertical, 4)
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("APR %")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.5))
                            HStack(spacing: 4) {
                                DoubleField(placeholder: "0.00", value: $draft.apr)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("%")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                            }
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 44)
                            .background(Color(hex: "#2C2C2E"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        }
                        
                        Color.clear.frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 4)

                    HStack(spacing: 12) {
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
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LIMIT")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.45))
                            HStack(spacing: 4) {
                                Text("$")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                DoubleField(placeholder: "0.00", value: $draft.limit)
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
                                Text("Delete Card")
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
                        Text(draft.name.isEmpty ? (isNew ? "Add Card" : "Edit Card") : draft.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(hex: "#C1AA78"))
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
            .background(Color(hex: "#2C2C2E"))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
