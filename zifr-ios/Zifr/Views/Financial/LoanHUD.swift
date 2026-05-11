import SwiftUI

struct LoanHUD: View {
    @Binding var draft: Loan
    let isNew: Bool
    let institutionName: String
    let onSave: () -> Void
    let onCancel: () -> Void
    var onDelete: (() -> Void)? = nil
    
    @State private var initialDraft: Loan? = nil
    
    private var isDirty: Bool {
        guard let initial = initialDraft else { return isNew && !draft.name.isEmpty }
        return draft.name != initial.name ||
               draft.principalAmount != initial.principalAmount ||
               draft.interestRate != initial.interestRate ||
               draft.termYears != initial.termYears ||
               draft.termMonths != initial.termMonths ||
               draft.scheduleFrequency != initial.scheduleFrequency ||
               draft.role != initial.role
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ZifrField(
                        label: "LOAN NAME",
                        placeholder: "e.g. Mortgage",
                        text: $draft.name
                    )
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("ROLE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.5))
                        Picker("", selection: $draft.role) {
                            ForEach(Loan.roles, id: \.self) { t in
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
                    .padding(.vertical, 4)

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PRINCIPAL")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.5))
                            HStack(spacing: 4) {
                                Text("$")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                DoubleField(placeholder: "0.00", value: $draft.principalAmount)
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
                            Text("INTEREST RATE")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.5))
                            HStack(spacing: 4) {
                                DoubleField(placeholder: "0.00", value: $draft.interestRate)
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
                    }
                    .padding(.vertical, 4)

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TERM YEARS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.5))
                            Picker("", selection: $draft.termYears) {
                                ForEach(0...40, id: \.self) { y in
                                    Text("\(y) Years").tag(y)
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
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TERM MONTHS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.5))
                            Picker("", selection: $draft.termMonths) {
                                ForEach(0...11, id: \.self) { m in
                                    Text("\(m) Months").tag(m)
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
                                Text("Delete Loan")
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
                        Text(draft.name.isEmpty ? (isNew ? "Add Loan" : "Edit Loan") : draft.name)
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
