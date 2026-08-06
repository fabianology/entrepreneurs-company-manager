import SwiftUI
import SwiftData

// MARK: - Institution Accounts Section
struct InstitutionAccountsSection: View {
    @State var institution: Institution
    @Bindable var vm: AppViewModel
    let onAdd: () -> Void
    let onEdit: (Int, InstitutionAccount) -> Void

    var body: some View {
        Section {
            Button { onAdd() } label: {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Add Account")
                    }
                    .font(.system(size: 13, weight: .bold))
                    
                    Text("checking · savings · investing · 401(k) · more")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(MiloomSecondaryButtonStyle())

                ForEach(institution.accounts.indices, id: \.self) { i in
                    let acc = institution.accounts[i]
                    Button { onEdit(i, acc) } label: {
                        HStack(spacing: 12) {

                            VStack(alignment: .leading, spacing: 4) {
                                Text(acc.name.isEmpty ? "Unnamed Account" : acc.name.cleanAccountName)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                HStack(spacing: 6) {
                                    Text(acc.type)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                    Text("·").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.2))
                                    Text("••\(acc.last4)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.6))
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
                        .background(Color(hex: "#2C2C2E"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            withAnimation {
                                let acc = institution.accounts[i]
                                vm.cleanUpCustomPaymentMethod(name: acc.name.isEmpty ? acc.type : acc.name)
                                var accs = institution.accounts
                                accs.remove(at: i)
                                institution.accounts = accs
                            }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.red)
                    }
                }
        } header: { 
            HStack(spacing: 6) {
                Image(systemName: "building.columns")
                    .font(.system(size: 12, weight: .bold))
                Text("ACCOUNTS")
                    .font(.system(size: 12, weight: .black))
                    .tracking(1.5)
            }
            .foregroundStyle(Color(hex: "#C1AA78"))
            .padding(.top, 24)
            .padding(.bottom, 8)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
        .listRowSeparator(.hidden)
    }
}
