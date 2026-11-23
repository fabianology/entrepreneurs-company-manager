import SwiftUI

/// A reveal response is usable only by the still-current, active presentation.
/// Kept independent of networking so delayed completions can be tested exactly.
struct ResourceCredentialRevealGate {
    private(set) var operationID = UUID()

    static func authenticatedViewer(
        signedInUserID: UUID?, portfolioUserID: UUID?, isUnlocked: Bool, isActive: Bool
    ) -> UUID? {
        guard isUnlocked, isActive, let signedInUserID, signedInUserID == portfolioUserID else { return nil }
        return signedInUserID
    }

    mutating func invalidate() { operationID = UUID() }

    func allows(_ token: UUID, isActive: Bool) -> Bool {
        token == operationID && isActive
    }
}

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

/// Loads credentials only while this exact resource is shown in an unlocked app.
/// Plaintext is kept in this presentation and cleared when it stops being active.
struct ResourceCredentialAccessCard: View {
    let resourceType: String
    let resourceID: UUID
    let ownerUserID: UUID
    var onStatusChange: ((String) -> Void)? = nil
    var onCredentialsChange: ((RevealedResourceCredentials?, UUID, Bool) -> Void)? = nil

    @Environment(AppState.self) private var appState
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.scenePhase) private var scenePhase
    @State private var status: String?
    @State private var presentation: Presentation?
    @State private var refreshID = UUID()
    @State private var revealed: RevealedResourceCredentials?
    @State private var canEdit = false
    @State private var showingVaultAccess = false
    private var plaintextFields: [String: String] { revealed?.fields ?? [:] }
    @State private var draftFields: [String: String] = [:]
    @State private var draftAccounts: [AccountCredentials] = []
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var revealGate = ResourceCredentialRevealGate()
    private var operationID: UUID { revealGate.operationID }
    private struct Presentation: Equatable {
        let resourceType: String
        let resourceID: UUID
        let ownerUserID: UUID
        let viewerUserID: UUID
    }

    private struct LoadRequest: Equatable {
        let presentation: Presentation?
        let refreshID: UUID
    }

    private var activePresentation: Presentation? {
        guard let viewer = ResourceCredentialRevealGate.authenticatedViewer(
            signedInUserID: auth.currentUser?.id, portfolioUserID: appState.portfolioUserID,
            isUnlocked: auth.isAuthenticated, isActive: scenePhase == .active
        ) else { return nil }
        return Presentation(
            resourceType: resourceType, resourceID: resourceID,
            ownerUserID: ownerUserID, viewerUserID: viewer
        )
    }

    private var hasCurrentPresentation: Bool {
        guard let activePresentation else { return false }
        return presentation == activePresentation
    }

    private struct AccountCredentials: Codable, Identifiable {
        let id: String
        var accountNumber: String?
        var routingNumber: String?
        var wireRoutingNumber: String?
    }

    private var accounts: [AccountCredentials]? {
        guard let value = plaintextFields["accounts_data"],
              let data = value.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([AccountCredentials].self, from: data)
    }

    private var accountsForEditing: [AccountCredentials] {
        let saved = accounts ?? []
        guard resourceType == "institution",
              let bank = appState.institutions.first(where: { $0.id == resourceID }) else { return saved }
        let missing = bank.accounts.filter { account in !saved.contains { $0.id == account.id } }
        return saved + missing.map { AccountCredentials(id: $0.id) }
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

    private var editableFields: [(String, String)] {
        switch resourceType {
        case "institution":
            return [("login_url", "Website"), ("username", "Login ID"),
                    ("email", "Email"), ("password", "Password"),
                    ("two_factor", "Two-factor method")]
        case "card":
            return [("login", "Login ID"), ("password", "Password"),
                    ("card_number", "Card number"), ("expiry", "Expiry")]
        case "subscription":
            return [("login_id", "Login ID"), ("password", "Password"),
                    ("two_factor_auth", "Two-factor method"),
                    ("recovery_method", "Recovery method")]
        default:
            return []
        }
    }

    var body: some View {
        if hasCurrentPresentation && (onCredentialsChange == nil || revealed == nil) {
            credentialContent
        }
        Color.clear.frame(height: 0)
            .modifier(VaultAccessPrompt(isPresented: $showingVaultAccess, onReady: refresh))
            .task(id: LoadRequest(presentation: activePresentation, refreshID: refreshID)) {
                guard let activePresentation else { return }
                await startLoading(activePresentation)
            }
            .onChange(of: activePresentation) { _, current in
                if current == nil { resetPresentation() }
            }
            .onDisappear { resetPresentation() }
    }

    @ViewBuilder
    private var credentialContent: some View {
        if let status, status != "not_ready", status != "unavailable" {
            ZifrSheetCard(title: "SECURE CREDENTIALS", icon: "lock.shield") {
                VStack(alignment: .leading, spacing: 14) {
                    switch status {
                    case "ready":
                        if isEditing {
                            Text("These edits update the credentials saved in Miloom. To change your password at the service, visit the service directly.")
                                .foregroundStyle(.secondary)
                            ForEach(editableFields, id: \.0) { field in
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(field.1.uppercased())
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(Color(hex: "#C1AA78"))
                                    if field.0 == "password" {
                                        SecureField(field.1, text: binding(for: field.0))
                                    } else {
                                        TextField(field.1, text: binding(for: field.0))
                                            .textInputAutocapitalization(.never)
                                    }
                                }
                                .textFieldStyle(.roundedBorder)
                            }
                            ForEach(draftAccounts.indices, id: \.self) { index in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("ACCOUNT \(index + 1)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color(hex: "#C1AA78"))
                                    TextField("Account number", text: accountBinding(index, \.accountNumber))
                                    TextField("Routing number", text: accountBinding(index, \.routingNumber))
                                    TextField("Wire routing number", text: accountBinding(index, \.wireRoutingNumber))
                                }
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                            }
                            HStack {
                                actionButton("Cancel", symbol: "xmark", action: clearEditor)
                                actionButton("Save", symbol: "checkmark", action: save)
                            }
                            .disabled(isSaving)
                        } else if revealed == nil {
                            if errorMessage == nil {
                                ProgressView("Loading credentials…")
                            } else {
                                actionButton("Try Again", symbol: "arrow.clockwise", action: refresh)
                            }
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
                            if !canEdit {
                                Text("You can view and copy these details in Miloom. The service controls what a person can do with its password.")
                                    .foregroundStyle(.secondary)
                            }
                            if canEdit && (plaintextFields["accounts_data"] == nil || accounts != nil) {
                                actionButton("Edit", symbol: "pencil") {
                                    guard hasCurrentPresentation else { return }
                                    draftFields = plaintextFields
                                    draftAccounts = accountsForEditing
                                    isEditing = true
                                }
                            }
                        }
                    case "pending":
                        Text("Waiting for an approved device belonging to the owner to share credentials. Miloom will finish automatically when it connects.")
                            .foregroundStyle(.secondary)
                        actionButton("Check Again", symbol: "arrow.clockwise", action: refresh)
                    case "device_needed":
                        Text("Set up Password Vault or approve this device to see the saved credentials.")
                            .foregroundStyle(.secondary)
                        actionButton("Open Password Vault", symbol: "iphone") { showingVaultAccess = true }
                    case "locked":
                        Text("Miloom is updating access to these credentials. Check again after an approved device belonging to the owner connects.")
                            .foregroundStyle(.secondary)
                        actionButton("Check Again", symbol: "arrow.clockwise", action: refresh)
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
        } else if status == "not_ready",
                  let actorID = appState.portfolioUserID, actorID != ownerUserID {
            ZifrSheetCard(title: "SECURE CREDENTIALS", icon: "lock.shield") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("There are no saved credentials available for this item yet.")
                        .foregroundStyle(.secondary)
                    actionButton("Check Again", symbol: "arrow.clockwise", action: refresh)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.subheadline)
            }
        } else if let errorMessage {
            ZifrSheetCard(title: "SECURE CREDENTIALS", icon: "lock.shield") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                    actionButton("Try Again", symbol: "arrow.clockwise", action: refresh)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func credentialRow(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color(hex: "#C1AA78"))
            HStack {
                Text(value)
                    .font(.body.monospaced())
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    guard hasCurrentPresentation else { return }
                    SearchCredentialAccess.copy(value)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Copy \(title)")
            }
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
        .disabled(isSaving)
    }

    private func clearEditor() {
        draftFields.removeAll()
        draftAccounts.removeAll()
        isEditing = false
    }

    private func resetPresentation() {
        if let presentation, revealed != nil {
            onCredentialsChange?(nil, presentation.viewerUserID, false)
        }
        revealGate.invalidate()
        presentation = nil
        status = nil
        canEdit = false
        isSaving = false
        errorMessage = nil
        revealed = nil
        clearEditor()
    }

    private func isCurrent(_ scope: Presentation, token: UUID) -> Bool {
        !Task.isCancelled && presentation == scope &&
            revealGate.allows(token, isActive: activePresentation == scope)
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { draftFields[key] ?? "" },
            set: { draftFields[key] = $0 }
        )
    }

    private func accountBinding(
        _ index: Int, _ keyPath: WritableKeyPath<AccountCredentials, String?>
    ) -> Binding<String> {
        Binding(
            get: { draftAccounts.indices.contains(index) ? draftAccounts[index][keyPath: keyPath] ?? "" : "" },
            set: { value in
                guard draftAccounts.indices.contains(index) else { return }
                draftAccounts[index][keyPath: keyPath] = value.isEmpty ? nil : value
            }
        )
    }

    private func save() {
        guard !isSaving, canEdit, let scope = activePresentation,
              presentation == scope, let revealed else { return }
        let token = operationID
        var updated = draftFields.filter { !$0.value.isEmpty && $0.key != "accounts_data" }
        if !draftAccounts.isEmpty,
           draftAccounts.contains(where: {
               $0.accountNumber != nil || $0.routingNumber != nil || $0.wireRoutingNumber != nil
           }) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            guard let data = try? encoder.encode(draftAccounts) else {
                errorMessage = "Account details couldn't be encoded. Nothing was changed."
                return
            }
            updated["accounts_data"] = String(decoding: data, as: UTF8.self)
        }
        isSaving = true
        errorMessage = nil
        Task {
            do {
                let saved = try await VaultService.shared.updateResourceSecret(
                    type: scope.resourceType, id: scope.resourceID,
                    expectedOwnerUserID: scope.ownerUserID, expectedViewerUserID: scope.viewerUserID,
                    plaintextFields: updated, previous: revealed
                )
                guard isCurrent(scope, token: token) else { return }
                self.revealed = saved
                if scope.resourceType == "institution",
                   let bank = appState.institutions.first(where: { $0.id == scope.resourceID }) {
                    appState.setInstitutionLogoWebsite(saved.fields["login_url"], for: bank)
                }
                clearEditor()
            } catch {
                guard isCurrent(scope, token: token) else { return }
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }

    private func refresh() {
        guard !isSaving, activePresentation != nil else { return }
        refreshID = UUID()
    }

    private func startLoading(_ scope: Presentation) async {
        guard !Task.isCancelled, activePresentation == scope else { return }
        resetPresentation()
        presentation = scope
        onStatusChange?("checking")
        let token = operationID
        await loadCredentials(for: scope, token: token)
        while isCurrent(scope, token: token), status == "pending" || status == "locked" {
            do { try await Task.sleep(for: .seconds(10)) }
            catch { return }
            guard isCurrent(scope, token: token) else { return }
            await loadCredentials(for: scope, token: token)
        }
    }

    private func loadCredentials(for scope: Presentation, token: UUID) async {
        do {
            let result = try await VaultService.shared.resourceSecretAccessStatus(
                type: scope.resourceType, id: scope.resourceID
            )
            guard isCurrent(scope, token: token) else { return }
            status = result.status
            canEdit = result.canEdit
            errorMessage = nil
            onStatusChange?(result.status)
            guard result.status == "ready" else { return }
        } catch {
            guard isCurrent(scope, token: token) else { return }
            status = "unavailable"
            canEdit = false
            onStatusChange?("check_failed")
            if case ProtectedResourceSaveError.backendUpdateRequired = error {
                errorMessage = "This server needs the Password Vault update before credentials can be added or opened."
            } else {
                errorMessage = "Credential access couldn’t be checked. Try again when connected."
            }
            return
        }

        do {
            let credentials = try await VaultService.shared.readResourceCredentials(
                type: scope.resourceType, id: scope.resourceID,
                expectedOwnerUserID: scope.ownerUserID, expectedViewerUserID: scope.viewerUserID
            )
            guard isCurrent(scope, token: token) else { return }
            revealed = credentials
            onCredentialsChange?(credentials, scope.viewerUserID, canEdit)
        } catch {
            guard isCurrent(scope, token: token) else { return }
            errorMessage = error.localizedDescription
        }
    }
}
