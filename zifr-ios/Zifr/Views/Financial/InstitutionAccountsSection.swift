import SwiftUI
import SwiftData

// MARK: - Institution Accounts Section
struct InstitutionAccountsSection: View {
    @State var institution: Institution
    @Bindable var vm: AppViewModel
    let onAdd: () -> Void
    let onEdit: (Int, InstitutionAccount) -> Void

    private enum AccountCategory: Int, CaseIterable, Identifiable {
        case cash
        case investments
        case health
        case other

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .cash: "Cash"
            case .investments: "Investments"
            case .health: "Health"
            case .other: "Other"
            }
        }

        var icon: String {
            switch self {
            case .cash: "banknote"
            case .investments: "chart.line.uptrend.xyaxis"
            case .health: "cross.case"
            case .other: "square.grid.2x2"
            }
        }

        static func category(for accountType: String) -> AccountCategory {
            let type = accountType
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            if ["checking", "savings", "cd", "money market", "cash management", "depository"].contains(type) {
                return .cash
            }

            if type == "investing"
                || type.contains("investment")
                || type.contains("brokerage")
                || type.contains("401")
                || type.contains("ira")
                || type.contains("529")
                || type.contains("retirement") {
                return .investments
            }

            if ["fsa", "hsa"].contains(type) {
                return .health
            }

            return .other
        }
    }

    private struct CategorizedAccount: Identifiable {
        let index: Int
        let account: InstitutionAccount

        var id: String { account.id }
    }

    private struct AccountGroup: Identifiable {
        let category: AccountCategory
        let accounts: [CategorizedAccount]

        var id: AccountCategory { category }
    }

    private var accountGroups: [AccountGroup] {
        let indexedAccounts = institution.accounts.enumerated().map {
            CategorizedAccount(index: $0.offset, account: $0.element)
        }

        return AccountCategory.allCases.compactMap { category in
            let accounts = indexedAccounts.filter {
                AccountCategory.category(for: $0.account.type) == category
            }
            guard !accounts.isEmpty else { return nil }
            return AccountGroup(category: category, accounts: accounts)
        }
    }

    var body: some View {
        ZifrSheetCard(
            title: "ACCOUNTS",
            icon: "building.columns",
            subtitle: "checking · savings · investing · 401(k)",
            badgeCount: institution.accounts.count
        ) {
            if !institution.accounts.isEmpty {
                VStack(spacing: 18) {
                    ForEach(accountGroups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 7) {
                                Image(systemName: group.category.icon)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.miloomGold)

                                Text(group.category.title.uppercased())
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.3)
                                    .foregroundStyle(Color.white.opacity(0.58))
                            }
                            .padding(.horizontal, 4)

                            VStack(spacing: 8) {
                                ForEach(group.accounts) { item in
                                    let acc = item.account
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        onEdit(item.index, acc)
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
                                                let accToDelete = institution.accounts[item.index]
                                                vm.cleanUpCustomPaymentMethod(name: accToDelete.name.isEmpty ? accToDelete.type : accToDelete.name)
                                                var accs = institution.accounts
                                                accs.remove(at: item.index)
                                                institution.accounts = accs
                                            }
                                        } label: {
                                            Label("Delete Account", systemImage: "trash")
                                        }
                                    }
                                }
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
