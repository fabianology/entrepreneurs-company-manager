import SwiftUI
import SwiftData

// MARK: - Institution Accounts Section
struct InstitutionAccountsSection: View {
    @State var institution: Institution
    @Bindable var vm: AppViewModel
    let onAdd: () -> Void
    let onEdit: (Int, InstitutionAccount) -> Void

    var body: some View {
        ZifrSheetCard(
            title: "ACCOUNTS",
            icon: "building.columns",
            subtitle: "checking · savings · investing · 401(k)",
            badgeCount: institution.accounts.count
        ) {
            if !institution.accounts.isEmpty {
                VStack(spacing: 8) {
                    ForEach(institution.accounts.indices, id: \.self) { i in
                        let acc = institution.accounts[i]
                        Button { 
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onEdit(i, acc) 
                        } label: {
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
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        }
                        .buttonStyle(PremiumButtonStyle())
                        .contextMenu {
                            Button(role: .destructive) {
                                withAnimation {
                                    let accToDelete = institution.accounts[i]
                                    vm.cleanUpCustomPaymentMethod(name: accToDelete.name.isEmpty ? accToDelete.type : accToDelete.name)
                                    var accs = institution.accounts
                                    accs.remove(at: i)
                                    institution.accounts = accs
                                }
                            } label: {
                                Label("Delete Account", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Button { 
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onAdd() 
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add Account")
                }
                .font(.system(size: 13, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(MiloomSecondaryButtonStyle())
        }
    }
}
