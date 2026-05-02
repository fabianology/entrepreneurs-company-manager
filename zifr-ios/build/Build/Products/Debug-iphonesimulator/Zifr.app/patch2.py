import sys

file_path = "Views/Financial/FinancialView.swift"
with open(file_path, "r") as f:
    lines = f.readlines()

# Find the start and end of InstitutionCardView
start_idx = -1
end_idx = -1

for i, line in enumerate(lines):
    if line.startswith("// MARK: - Institution Card"):
        start_idx = i
    # the next block is // MARK: - Financial Card View
    if line.startswith("// MARK: - Financial Card View"):
        end_idx = i
        break

if start_idx != -1 and end_idx != -1:
    new_code = """// MARK: - Institution Card
struct InstitutionCardView: View {
    let institution: Institution
    let totalMonthlyPayment: Double
    let cardCount: Int
    let loanCount: Int
    let onEdit: () -> Void
    @State private var expanded = false
    @State private var copiedField: String? = nil
    @State private var passwordRevealed = false

    var body: some View {
        VStack(spacing: 0) {
            // ── Tappable header (triggers edit sheet) ──────────────────────
            Button(action: onEdit) {
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16).fill(Color.clear).frame(width: 56, height: 56)
                            if !institution.loginUrl.isEmpty {
                                FaviconImage(website: institution.loginUrl, size: 36)
                            } else {
                                Image(systemName: "building.columns")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.8))
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(institution.name.isEmpty ? "New Bank" : institution.name)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)

                            HStack(spacing: 14) {
                                costColumn(value: totalMonthlyPayment, label: "mo. payment")
                            }
                            .padding(.top, 4)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 12)

                    // ── Counts row styled like Status row ──────────────
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.zifrGold)
                            .frame(width: 6, height: 6)
                        Text("\\(institution.accounts.count) Accounts")
                            .font(.system(size: 11, weight: .semibold))
                            .textCase(.uppercase)
                            .tracking(0.3)
                            .foregroundStyle(Color.zifrGold)
                        statusPipe()
                        Text("\\(cardCount) Cards")
                            .font(.system(size: 11, weight: .semibold))
                            .textCase(.uppercase)
                            .tracking(0.3)
                            .foregroundStyle(Color.zifrGold)
                        statusPipe()
                        Text("\\(loanCount) Loans")
                            .font(.system(size: 11, weight: .semibold))
                            .textCase(.uppercase)
                            .tracking(0.3)
                            .foregroundStyle(Color.zifrGold)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)

                    // ── Credentials (tap-to-copy) ────
                    HStack(spacing: 12) {
                        copyableCredential(
                            id: institution.id,
                            label: "Login ID",
                            value: institution.username.isEmpty ? (institution.email.isEmpty ? "—" : institution.email) : institution.username,
                            field: "login"
                        )
                        copyableCredential(
                            id: institution.id,
                            label: "Password",
                            value: institution.password,
                            field: "password",
                            isPassword: true
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ── Accordion ──────────────────────────────────────────────────
            accordionDivider()
            accordionToggle(label: expanded ? "Less Details" : "More Details", count: institution.accounts.count + loanCount, expanded: expanded) {
                withAnimation(.spring(response: 0.35)) { expanded.toggle() }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            
            if expanded {
                LazyVStack(spacing: 12) {
                    ForEach(institution.accounts) { acc in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(acc.type == "Credit Card" ? Color.orange : (acc.type == "Checking" ? Color.zifrGold : Color.green))
                                .frame(width: 6, height: 6)
                            Text(acc.name.isEmpty ? "Account" : acc.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.85))
                            Text(acc.type)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.35))
                            Spacer()
                            if !acc.last4.isEmpty {
                                Text("••\\(acc.last4)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.zifrGold)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(hex: "#1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }

    private func costColumn(value: Double, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("$\\(String(format: "%.0f", value))")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.4))
        }
    }

    private func statusPipe() -> some View {
        Text("|")
            .font(.system(size: 10))
            .foregroundStyle(Color.white.opacity(0.2))
    }

    private func accordionDivider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.05))
            .frame(height: 1)
    }

    private func accordionToggle(label: String, count: Int? = nil, expanded: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if let count = count, count > 0 {
                    Text("\\(label) ")
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(0.2)
                        .foregroundStyle(Color.white.opacity(0.5))
                    + Text("(\\(count))")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.2))
                } else {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(0.2)
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .padding(.horizontal, 24)
            .frame(height: 47)
        }
    }

    private func copyableCredential(id: String, label: String, value: String, field: String, isPassword: Bool = false) -> some View {
        let isCopied = copiedField == field
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(isCopied ? "Copied ✓" : label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isCopied ? Color.orange : Color.white.opacity(0.5))
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
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.05), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }
}

"""
    new_lines = lines[:start_idx] + [new_code] + lines[end_idx:]
    with open(file_path, "w") as f:
        f.writelines(new_lines)
    print("Successfully replaced InstitutionCardView")
else:
    print(f"Failed to find boundary markers. start_idx={start_idx}, end_idx={end_idx}")

