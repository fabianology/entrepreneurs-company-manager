import SwiftUI
import SwiftData

// MARK: - Loan Payment HUD
struct LoanPaymentHUD: View {
    @State var draft: LoanPayment
    let isNew: Bool
    let institutions: [Institution]
    let cards: [FinancialCard]
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("AMOUNT")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(Color.white.opacity(0.45))
                                HStack(spacing: 4) {
                                    Text("$")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                    DoubleField(placeholder: "0.00", value: $draft.amount)
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
                                Text("DATE")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(Color.white.opacity(0.45))
                                DatePicker("", selection: $draft.date, displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(height: 44)
                                    .padding(.leading, 6)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PAID FROM")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.45))
                            
                            HStack {
                                TextField("e.g. Primary Checking", text: Binding(get: { draft.source ?? "" }, set: { draft.source = $0 }))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Spacer(minLength: 8)
                                
                                Menu {
                                    Section("Bank Accounts") {
                                        ForEach(institutions) { inst in
                                            ForEach(inst.accounts) { acc in
                                                let methodString = "\(acc.name) ••••\(acc.last4) (\(inst.name))"
                                                Button(methodString) { draft.source = methodString }
                                            }
                                        }
                                    }
                                    Section("Credit Cards") {
                                        ForEach(cards) { card in
                                            let methodString = "\(card.name) ••••\(card.last4 ?? "")"
                                            Button(methodString) { draft.source = methodString }
                                        }
                                    }
                                    Section("Other") {
                                        Button("None") { draft.source = "" }
                                    }
                                } label: {
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.3))
                                        .padding(.vertical, 10)
                                        .padding(.leading, 10)
                                }
                            }
                            .padding(.horizontal, 16)
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
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#1C1C1E"))
            .listSectionSpacing(0)
            .navigationTitle(isNew ? "Add Payment" : "Edit Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(isNew ? "Add Payment" : "Edit Payment")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: "#C1AA78"))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Save", action: onSave)
                        .fontWeight(.semibold)
                        .tint(.green)
                }
            }
        }
    }
}
