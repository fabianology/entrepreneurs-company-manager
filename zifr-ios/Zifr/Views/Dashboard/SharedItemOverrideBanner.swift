import SwiftUI

struct SharedItemOverrideBanner: View {
    let resourceId: UUID
    let defaultCompanyId: UUID
    @Environment(AppState.self) private var appState
    
    private var isSharedWithMe: Bool {
        appState.resourceShares.contains { $0.resourceId == resourceId || $0.resourceId == defaultCompanyId }
    }
    
    private var shareSender: String? {
        appState.resourceShares.first { $0.resourceId == resourceId || $0.resourceId == defaultCompanyId }?.senderEmail
    }
    
    var body: some View {
        if isSharedWithMe {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "person.2.fill")
                    Text("Shared by \(shareSender ?? "Unknown")")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(hex: "#818cf8"))
                
                Text("You can link this item to one of your own companies to view it seamlessly on your dashboard.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                
                Menu {
                    Button("Keep in Shared Inbox") {
                        appState.localCompanyOverrides.removeValue(forKey: resourceId.uuidString)
                    }
                    Divider()
                    ForEach(appState.companies) { comp in
                        Button(comp.name) {
                            appState.localCompanyOverrides[resourceId.uuidString] = comp.id
                        }
                    }
                } label: {
                    HStack {
                        let currentOverride = appState.localCompanyOverrides[resourceId.uuidString]
                        let selectedName = appState.companies.first(where: { $0.id == currentOverride })?.name ?? "Keep in Shared Inbox"
                        
                        Text(selectedName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(Color.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(16)
            .background(Color(hex: "#4f46e5").opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#4f46e5").opacity(0.3), lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }
}

/// Loads status only on the detail screen. Plaintext exists only in this view,
/// after a local device-presence check, and is discarded on hide/background.
struct ResourceCredentialAccessCard: View {
    let resourceType: String
    let resourceID: UUID
    let ownerUserID: UUID

    @Environment(\.scenePhase) private var scenePhase
    @State private var status: String?
    @State private var plaintextFields: [String: String] = [:]
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var operationID = UUID()

    private struct AccountCredentials: Decodable, Identifiable {
        let id: String
        let accountNumber: String?
        let routingNumber: String?
        let wireRoutingNumber: String?
    }

    private var accounts: [AccountCredentials]? {
        guard let value = plaintextFields["accounts_data"],
              let data = value.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([AccountCredentials].self, from: data)
    }

    private var fields: [(String, String)] {
        let titles = [
            "login_url": "Website", "username": "Login ID", "email": "Email",
            "password": "Password", "two_factor": "Two-factor method",
            "login": "Login ID", "card_number": "Card number", "expiry": "Expiry",
            "login_id": "Login ID", "two_factor_auth": "Two-factor method",
            "recovery_method": "Recovery method"
        ]
        return plaintextFields.keys.filter { $0 != "accounts_data" }.sorted().compactMap { key in
            guard let title = titles[key], let value = plaintextFields[key] else { return nil }
            return (title, value)
        }
    }

    var body: some View {
        if let status, status != "not_ready", status != "unavailable" {
            ZifrSheetCard(title: "SECURE CREDENTIALS", icon: "lock.shield") {
                VStack(alignment: .leading, spacing: 14) {
                    switch status {
                    case "ready":
                        if plaintextFields.isEmpty {
                            Text("Credentials are available for this resource only. Face ID or your passcode is required to reveal them.")
                                .foregroundStyle(.secondary)
                            actionButton("Reveal Credentials", symbol: "eye", action: reveal)
                        } else {
                            ForEach(Array(fields.enumerated()), id: \.offset) { _, field in
                                credentialRow(field.0, value: field.1)
                            }
                            if let accounts {
                                ForEach(accounts) { account in
                                    if let value = account.accountNumber {
                                        credentialRow("Account number", value: value)
                                    }
                                    if let value = account.routingNumber {
                                        credentialRow("Routing number", value: value)
                                    }
                                    if let value = account.wireRoutingNumber {
                                        credentialRow("Wire routing number", value: value)
                                    }
                                }
                            } else if plaintextFields["accounts_data"] != nil {
                                Text("Account details could not be displayed.")
                                    .foregroundStyle(.orange)
                            }
                            actionButton("Hide Credentials", symbol: "eye.slash") {
                                plaintextFields.removeAll()
                            }
                        }
                    case "request":
                        Text("Ask the owner to approve this device for this resource's credentials. Other resources stay private.")
                            .foregroundStyle(.secondary)
                        actionButton("Request Access", symbol: "person.badge.key", action: request)
                    case "pending":
                        Label("Waiting for owner approval on this device", systemImage: "clock")
                            .foregroundStyle(.secondary)
                        actionButton("Check Again", symbol: "arrow.clockwise", action: refresh)
                    case "device_needed":
                        Label("Approve this device in Password Vault first.", systemImage: "iphone")
                            .foregroundStyle(.secondary)
                    case "locked":
                        Label("The owner must replace this resource's key in Password Vault before access can resume.", systemImage: "lock.trianglebadge.exclamationmark")
                            .foregroundStyle(.orange)
                    default:
                        EmptyView()
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.subheadline)
            }
        } else if errorMessage != nil {
            ZifrSheetCard(title: "SECURE CREDENTIALS", icon: "lock.shield") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Credential access couldn't be checked. Try again when connected.")
                        .foregroundStyle(.secondary)
                    actionButton("Try Again", symbol: "arrow.clockwise", action: refresh)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        // Keep the whole card absent on older backends and for unactivated keys.
        Color.clear.frame(height: 0)
            .task(id: resourceID) { await loadStatus() }
            .onDisappear { clearPlaintext() }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { clearPlaintext() }
            }
    }

    private func credentialRow(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color(hex: "#C1AA78"))
            Text(value)
                .font(.body.monospaced())
                .foregroundStyle(.primary)
                .privacySensitive()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func actionButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(hex: "#C1AA78"))
        .disabled(isWorking)
    }

    private func clearPlaintext() {
        operationID = UUID()
        plaintextFields.removeAll()
    }

    private func loadStatus() async {
        let token = operationID
        do {
            let result = try await VaultService.shared.resourceSecretAccessStatus(
                type: resourceType, id: resourceID
            )
            guard !Task.isCancelled, token == operationID else { return }
            status = result
            errorMessage = nil
            if result != "ready" { plaintextFields.removeAll() }
        } catch {
            guard !Task.isCancelled, token == operationID else { return }
            // A missing RPC means this build is talking to an older backend.
            status = "unavailable"
            if !error.localizedDescription.contains("PGRST202") {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func refresh() {
        guard !isWorking else { return }
        isWorking = true
        Task {
            await loadStatus()
            isWorking = false
        }
    }

    private func request() {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        Task {
            do {
                try await VaultService.shared.requestResourceSecretAccess(
                    type: resourceType, id: resourceID
                )
                await loadStatus()
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func reveal() {
        guard !isWorking else { return }
        let token = operationID
        isWorking = true
        errorMessage = nil
        Task {
            do {
                let fields = try await VaultService.shared.revealResourceSecret(
                    type: resourceType, id: resourceID,
                    expectedOwnerUserID: ownerUserID
                )
                guard token == operationID, scenePhase == .active else {
                    isWorking = false
                    return
                }
                plaintextFields = fields
            } catch {
                guard token == operationID else {
                    isWorking = false
                    return
                }
                errorMessage = error.localizedDescription
                await loadStatus()
            }
            isWorking = false
        }
    }
}
