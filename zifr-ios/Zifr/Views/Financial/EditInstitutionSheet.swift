import SwiftUI
import SwiftData

// MARK: - Edit Institution Sheet
struct EditInstitutionSheet: View {
    @State var institution: Institution
    let institutions: [Institution]
    let cards: [FinancialCard]
    let loans: [Loan]
    @Bindable var vm: AppViewModel
    let isNew: Bool

    @Environment(AppState.self) private var appState
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var resourceCredentialStatus = "checking"
    @State private var vaultDraft: InstitutionVaultDraft?
    @State private var savedMetadata: Institution?
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showingVaultAccess = false
    
    private var allSubscriptions: [Subscription] { appState.subscriptions }

    private var isViewer: Bool {
        !AppViewModel.resourceAllowsEdit(
            appState.resourceShares, actorID: appState.portfolioUserID,
            ownerID: institution.userId, companyID: institution.companyId,
            resourceType: "institution", resourceID: institution.id
        )
    }

    private var canManageSharing: Bool {
        AppViewModel.resourceAllowsSharing(
            appState.resourceShares, actorID: appState.portfolioUserID,
            ownerID: institution.userId, companyID: institution.companyId
        )
    }

    private func canEditResource(_ type: String, _ id: UUID) -> Bool {
        AppViewModel.resourceAllowsEdit(
            appState.resourceShares, actorID: appState.portfolioUserID,
            ownerID: institution.userId, companyID: institution.companyId,
            resourceType: type, resourceID: id
        )
    }

    // Keep creation separate from editing an existing institution or child.
    private func canAddRelatedItem(_ type: String) -> Bool {
        !isNew && AppViewModel.resourceAllowsCreation(
            appState.resourceShares, actorID: appState.portfolioUserID,
            ownerID: institution.userId, companyID: institution.companyId, resourceType: type
        )
    }

    private var canEditLegacyCredentials: Bool {
        guard let currentUserId = appState.portfolioUserID else { return false }
        return institution.userId == currentUserId &&
            (isNew || resourceCredentialStatus == "not_ready" || resourceCredentialStatus == "legacy")
    }

    private var activeVaultDraft: InstitutionVaultDraft? {
        guard !isViewer, let draft = vaultDraft,
              ResourceCredentialRevealGate.authenticatedViewer(
                  signedInUserID: auth.currentUser?.id, portfolioUserID: appState.portfolioUserID,
                  isUnlocked: auth.isAuthenticated, isActive: scenePhase == .active
              ) == draft.viewerUserID else { return nil }
        return draft
    }

    private var canEditLogin: Bool {
        activeVaultDraft?.canEdit ?? canEditLegacyCredentials
    }

    private var canEditAccountCredentials: Bool {
        activeVaultDraft?.canEditAccountCredentials ?? canEditLegacyCredentials
    }

    private func loginField(_ field: String, legacy: WritableKeyPath<Institution, String?>) -> Binding<String> {
        Binding {
            if let draft = activeVaultDraft { return draft.fields[field] ?? "" }
            guard canEditLegacyCredentials else { return "" }
            let value = institution[keyPath: legacy]
            return field == "password" ? SecurityService.editableValue(value) : value ?? ""
        } set: { value in
            if let draft = activeVaultDraft, draft.canEdit {
                vaultDraft?.set(field, to: value)
            } else if canEditLegacyCredentials {
                institution[keyPath: legacy] = value
            }
        }
    }

    @ViewBuilder
    private func copyCredential(_ field: String, label: String) -> some View {
        if let value = activeVaultDraft?.fields[field], !value.isEmpty {
            Button("Copy \(label)", systemImage: "doc.on.doc") {
                guard let currentValue = activeVaultDraft?.fields[field] else { return }
                SearchCredentialAccess.copy(currentValue)
            }
        }
    }

    private func receiveCredentials(_ credentials: RevealedResourceCredentials?, viewerUserID: UUID, canEdit: Bool) {
        guard let credentials else {
            guard vaultDraft?.viewerUserID == viewerUserID else { return }
            vaultDraft = nil
            showPassword = false
            showAccountHUD = false
            accountDraft.accountNumber = nil
            accountDraft.routingNumber = nil
            accountDraft.wireRoutingNumber = nil
            return
        }
        vaultDraft = InstitutionVaultDraft(previous: credentials, viewerUserID: viewerUserID, canEdit: canEdit)
        showPassword = true
        appState.setInstitutionLogoWebsite(credentials.fields["login_url"], for: institution)
    }

    @State private var showDeleteConfirm = false
    @State private var showPassword = false
    @State private var showShareSheet = false
    
    @State private var isSyncing = false
    @State private var syncSuccess = false
    @State private var syncErrorMsg: String?
    
    struct Snapshot: Equatable {
        var name, loginUrl, username, email, password, twoFactor: String
    }
    @State private var snapshot: Snapshot?

    private var currentSnapshot: Snapshot {
        Snapshot(name: institution.name ?? "", loginUrl: institution.loginUrl ?? "", username: institution.username ?? "", email: institution.email ?? "", password: institution.password ?? "", twoFactor: institution.twoFactor ?? "")
    }

    private var isDirty: Bool {
        guard let snap = snapshot else { return isNew && !institution.name.trimmingCharacters(in: .whitespaces).isEmpty }
        return snap != currentSnapshot || activeVaultDraft?.hasChanges == true ||
            savedMetadata != ResourceSecretPreparation.metadata(for: institution)
    }

    private var institutionRelationships: InstitutionRelationships {
        InstitutionRelationships(institutions: institutions, cards: cards, loans: loans,
            connections: appState.resourceConnections, companyOverrides: appState.localCompanyOverrides)
    }

    private var instCards: [FinancialCard] {
        let relationships = institutionRelationships
        return cards.filter { relationships.banks(for: .card, id: $0.id).contains(institution.id) }
    }
    private var instLoans: [Loan] {
        let relationships = institutionRelationships
        return loans.filter { relationships.banks(for: .loan, id: $0.id).contains(institution.id) }
    }

    private struct SyncHealthPresentation {
        let title: String
        let detail: String
        let icon: String
        let color: Color
    }

    private var plaidItem: PlaidItemSummary? {
        let visibleItems = appState.plaidItems.filter {
            !["archived", "deleted"].contains($0.status)
        }
        if let exact = visibleItems.first(where: { $0.institutionId == institution.id }) {
            return exact
        }
        return visibleItems.first(where: {
            $0.companyId == institution.companyId &&
            ($0.institutionName ?? "").caseInsensitiveCompare(institution.name) == .orderedSame
        })
    }

    private var institutionTransactionCount: Int {
        appState.transactions.filter { $0.institutionId == institution.id }.count
    }

    private var syncHealth: SyncHealthPresentation? {
        guard let item = plaidItem else {
            if institution.isDisconnected {
                return SyncHealthPresentation(
                    title: "Reconnect required",
                    detail: "Plaid access needs attention",
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                )
            }
            return nil
        }

        let countText = institutionTransactionCount == 1
            ? "1 transaction"
            : "\(institutionTransactionCount) transactions"
        if institution.isDisconnected || item.requiresReconnect {
            return SyncHealthPresentation(
                title: "Reconnect required",
                detail: item.errorCode ?? "Plaid access needs attention",
                icon: "exclamationmark.triangle.fill",
                color: .red
            )
        }
        if item.status == "pending_link" {
            return SyncHealthPresentation(
                title: "Finishing connection",
                detail: "Account data will appear after setup completes",
                icon: "clock.fill",
                color: .orange
            )
        }
        if let errorCode = item.errorCode, !errorCode.isEmpty {
            return SyncHealthPresentation(
                title: "Sync needs attention",
                detail: errorCode.replacingOccurrences(of: "_", with: " ").capitalized,
                icon: "exclamationmark.circle.fill",
                color: .orange
            )
        }

        // Transaction imports and account snapshot retrieval have separate clocks.
        let lastSync = item.lastSyncedAt
        guard let lastSync else {
            return SyncHealthPresentation(
                title: "Waiting for first sync",
                detail: countText,
                icon: "clock.arrow.circlepath",
                color: .orange
            )
        }
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        let updated = "Transactions synced \(relative.localizedString(for: lastSync, relativeTo: Date()))"
        if item.isStale() {
            return SyncHealthPresentation(
                title: "Sync delayed",
                detail: "\(updated) • \(countText)",
                icon: "clock.badge.exclamationmark.fill",
                color: .orange
            )
        }
        return SyncHealthPresentation(
            title: "Connected to Plaid",
            detail: "\(updated) • \(countText)",
            icon: "checkmark.circle.fill",
            color: .zifrGreen
        )
    }

    private var balanceRetrievalDetail: String {
        guard let retrievedAt = institution.lastSyncedAt else {
            return "Balances reflect the latest available bank data. Bank updates may be delayed."
        }
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        return "Balances retrieved \(relative.localizedString(for: retrievedAt, relativeTo: Date())). Bank updates may be delayed."
    }

    @State private var showAccountHUD = false
    @State private var accountDraft = InstitutionAccount()
    @State private var accountDraftIndex: Int? = nil

    @State private var showCardHUD = false
    @State private var cardDraft: FinancialCard? = nil

    @State private var showLoanHUD = false
    @State private var loanDraft: Loan? = nil

    @MainActor
    private func save() {
        guard !isSaving, !isViewer else { return }
        let metadata = ResourceSecretPreparation.metadata(for: institution)
        let draft = activeVaultDraft
        // A vault draft can still exist during the transition to a locked scene.
        guard vaultDraft == nil || draft != nil else { return }
        let bank = institution
        let updateMetadata = metadata != savedMetadata
        let portfolioUserID = appState.portfolioUserID
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            var savedVaultEdits = false
            do {
                if let draft {
                    if draft.hasChanges, draft.canEdit {
                        let saved = try await VaultService.shared.updateResourceSecret(
                            type: "institution", id: bank.id,
                            expectedOwnerUserID: bank.userId, expectedViewerUserID: draft.viewerUserID,
                            plaintextFields: draft.fields, previous: draft.previous
                        )
                        guard appState.portfolioUserID == portfolioUserID,
                              auth.currentUser?.id == draft.viewerUserID else { return }
                        appState.setInstitutionLogoWebsite(saved.fields["login_url"], for: bank)
                        // Keep the verified baseline if the following metadata write fails.
                        if activeVaultDraft?.previous.ciphertext == draft.previous.ciphertext {
                            vaultDraft = InstitutionVaultDraft(
                                previous: saved, viewerUserID: draft.viewerUserID, canEdit: draft.canEdit
                            )
                        }
                        savedVaultEdits = true
                    }
                    if updateMetadata {
                        var scopedMetadata = metadata
                        scopedMetadata.hasScopedCredentials = true
                        try await vm.saveInstitutionConfirmed(scopedMetadata, appState: appState)
                    }
                } else {
                    try await vm.saveInstitutionConfirmed(bank, appState: appState)
                    if canEditLegacyCredentials {
                        appState.setInstitutionLogoWebsite(bank.loginUrl, for: bank)
                    }
                }
                dismiss()
            } catch ProtectedResourceSaveError.vaultAccessRequired {
                showingVaultAccess = true
            } catch {
                let message = if error is ResourceSecretUpdateError || error is ResourceSecretRevealError {
                    error.localizedDescription
                } else {
                    ResourceSaveFailure.message(for: error, resource: "bank")
                }
                saveError = savedVaultEdits ? "Your login details were saved. \(message)" : message
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    SharedItemOverrideBanner(resourceId: institution.id, defaultCompanyId: institution.companyId)

                    if !isNew {
                        ResourceConnectionsSection(
                            reference: ResourceReference(kind: .institution, resourceId: institution.id)
                        )
                        ResourceCredentialAccessCard(
                            resourceType: "institution", resourceID: institution.id,
                            ownerUserID: institution.userId,
                            onStatusChange: { resourceCredentialStatus = $0 },
                            onCredentialsChange: isViewer ? nil : receiveCredentials
                        )
                    }
                    
                    // ── Card 1: Bank Identity & Login ──────────────
                    ZifrSheetCard(title: "LOGIN & IDENTITY", icon: "lock.shield") {
                        VStack(spacing: 16) {
                            HStack(spacing: 12) {
                                ZifrField(
                                    label: "INSTITUTION",
                                    placeholder: "e.g. Chase",
                                    text: Binding(get: { institution.name }, set: { institution.name = $0 })
                                )
                                .disabled(isViewer)
                                ZifrField(
                                    label: "WEBSITE",
                                    placeholder: "chase.com",
                                    text: loginField("login_url", legacy: \.loginUrl),
                                    keyboardType: .URL,
                                    textContentType: .URL
                                )
                                .textInputAutocapitalization(.never)
                                .disabled(!canEditLogin)
                                .contextMenu { copyCredential("login_url", label: "Website") }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                let username = loginField("username", legacy: \.username)
                                let email = loginField("email", legacy: \.email)
                                HStack(spacing: 12) {
                                    ZifrAutocompleteField(
                                        label: "LOGIN ID",
                                        placeholder: "username",
                                        text: Binding(
                                            get: { username.wrappedValue.isEmpty ? email.wrappedValue : username.wrappedValue },
                                            set: { newValue in
                                                let old = username.wrappedValue
                                                username.wrappedValue = newValue
                                                if newValue.contains("@") && (email.wrappedValue.isEmpty || email.wrappedValue == old) {
                                                    email.wrappedValue = newValue
                                                }
                                            }
                                        ),
                                        keyboardType: .emailAddress
                                    )
                                    .disabled(!canEditLogin)
                                    .contextMenu { copyCredential("username", label: "Login ID") }

                                    ZStack(alignment: .bottomTrailing) {
                                        ZifrField(
                                            label: "PASSWORD",
                                            placeholder: "••••••••",
                                            text: loginField("password", legacy: \.password),
                                            isSecure: !showPassword,
                                            textContentType: .password
                                        )
                                        .textInputAutocapitalization(.never)
                                        .disabled(!canEditLogin)

                                        if canEditLegacyCredentials || activeVaultDraft != nil {
                                            SecretVisibilityToggle(isVisible: $showPassword)
                                                .padding(.bottom, 2)
                                        }
                                    }
                                    .contextMenu { copyCredential("password", label: "Password") }
                                    if canEditLegacyCredentials && SecurityService.isLockedValue(institution.password) {
                                        Image(systemName: "lock.trianglebadge.exclamationmark")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.gray)
                                            .accessibilityLabel("Password locked on this device")
                                    }
                                }

                                if canEditLegacyCredentials {
                                    let loginValue = username.wrappedValue.isEmpty ? email.wrappedValue : username.wrappedValue
                                    DynamicLoginLabelView(loginId: loginValue, ignoreInstitutionId: institution.id.uuidString)
                                }
                            }

                            HStack(spacing: 12) {
                                ZifrField(
                                    label: "EMAIL",
                                    placeholder: "name@company.com",
                                    text: loginField("email", legacy: \.email),
                                    keyboardType: .emailAddress
                                )
                                .textInputAutocapitalization(.never)
                                .disabled(!canEditLogin)
                                .contextMenu { copyCredential("email", label: "Email") }

                                ZifrField(
                                    label: "2FA",
                                    placeholder: "Phone or App",
                                    text: loginField("two_factor", legacy: \.twoFactor)
                                )
                                .disabled(!canEditLogin)
                                .contextMenu { copyCredential("two_factor", label: "2FA") }
                            }
                        }
                        .privacySensitive()
                    }

                    Group {
                        // ── Card 2: Accounts ───────────────────────────
                        InstitutionAccountsSection(
                            institution: $institution,
                            vm: vm,
                            onAdd: {
                                accountDraft = InstitutionAccount()
                                accountDraftIndex = nil
                                showAccountHUD = true
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            },
                            onEdit: { idx, acc in
                                accountDraft = activeVaultDraft?.accountForEditing(acc) ?? acc
                                accountDraftIndex = idx
                                showAccountHUD = true
                            }
                        )

                        // ── Card 3: Cards ──────────────────────────────
                        InstitutionCardsSection(
                            cards: instCards,
                            canAdd: canAddRelatedItem("card"),
                            editableCardIDs: Set(instCards.filter { canEditResource("card", $0.id) }.map(\.id)),
                            onAdd: {
                                guard canAddRelatedItem("card") else { return }
                                cardDraft = vm.addCard(appState: appState, userId: institution.userId, companyId: institution.companyId)
                                cardDraft?.institutionName = institution.name 
                                showCardHUD = true
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            },
                            onEdit: { card in
                                guard canEditResource("card", card.id) else { return }
                                cardDraft = card
                                showCardHUD = true
                            },
                            onDelete: { card in
                                guard canEditResource("card", card.id) else { return }
                                vm.deleteCard(card, appState: appState)
                            }
                        )

                        // ── Card 4: Loans ──────────────────────────────
                        InstitutionLoansSection(
                            loans: instLoans,
                            canAdd: canAddRelatedItem("loan"),
                            editableLoanIDs: Set(instLoans.filter { canEditResource("loan", $0.id) }.map(\.id)),
                            onAdd: {
                                guard canAddRelatedItem("loan") else { return }
                                loanDraft = vm.addLoan(appState: appState, userId: institution.userId, companyId: institution.companyId)
                                loanDraft?.lender = institution.name 
                                showLoanHUD = true
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            },
                            onEdit: { loan in
                                guard canEditResource("loan", loan.id) else { return }
                                loanDraft = loan
                                showLoanHUD = true
                            },
                            onDelete: { loan in
                                guard canEditResource("loan", loan.id) else { return }
                                vm.deleteLoan(loan, appState: appState)
                            }
                        )

                        // ── Card 5: Actions ────────────────────────────
                        if !isNew {
                            if canManageSharing {
                                ZifrSheetCard(title: "ACTIONS", icon: "slider.horizontal.3") {
                                    VStack(spacing: 12) {
                                        // Share Institution
                                        if canManageSharing {
                                            Button {
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                showShareSheet = true
                                            } label: {
                                                VStack(spacing: 4) {
                                                    HStack(spacing: 6) {
                                                        Image(systemName: "person.crop.circle.badge.plus")
                                                        Text("Share Institution")
                                                    }
                                                    .font(.system(size: 13, weight: .semibold))
                                                    Text("Generate a share link for collaborators")
                                                        .font(.system(size: 10, weight: .regular))
                                                        .foregroundStyle(Color.white.opacity(0.6))
                                                }
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                            }
                                            .buttonStyle(MiloomSecondaryButtonStyle())
                                        }

                                        // Sync Latest Data
                                        if institution.userId == appState.portfolioUserID {
                                            VStack(spacing: 6) {
                                                Button {
                                                    guard !isSyncing else { return }
                                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                    isSyncing = true
                                                    syncSuccess = false
                                                    Task {
                                                        do {
                                                            try await PlaidService.shared.syncLatestAvailableData(institutionId: institution.id)
                                                            await DataRepository.shared.fetchAllData(appState: appState)
                                                            if let updatedInst = appState.institutions.first(where: { $0.id == institution.id }) {
                                                                self.institution = updatedInst
                                                            }
                                                            isSyncing = false
                                                            syncSuccess = true
                                                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                                                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                                                            syncSuccess = false
                                                        } catch {
                                                            isSyncing = false
                                                            syncErrorMsg = error.localizedDescription
                                                            AppDiagnostics.failure("plaid", "sync_institution", error: error)
                                                        }
                                                    }
                                                } label: {
                                                    VStack(spacing: 4) {
                                                        HStack(spacing: 6) {
                                                            if isSyncing {
                                                                ProgressView()
                                                                    .tint(.white)
                                                                    .scaleEffect(0.8)
                                                                Text("Syncing...")
                                                            } else if syncSuccess {
                                                                Image(systemName: "checkmark.circle.fill")
                                                                    .foregroundStyle(Color.zifrGreen)
                                                                Text("Sync Complete")
                                                                    .foregroundStyle(Color.zifrGreen)
                                                            } else {
                                                                Image(systemName: "arrow.triangle.2.circlepath")
                                                                Text("Sync Available Data")
                                                            }
                                                        }
                                                        .font(.system(size: 13, weight: .semibold))
                                                        Text("Get the latest data available from Plaid")
                                                            .font(.system(size: 10, weight: .regular))
                                                            .foregroundStyle(Color.white.opacity(0.6))
                                                    }
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 10)
                                                }
                                                .buttonStyle(MiloomSecondaryButtonStyle())

                                                Text(balanceRetrievalDetail)
                                                    .font(.system(size: 10, weight: .regular))
                                                    .foregroundStyle(Color.white.opacity(0.6))
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .fixedSize(horizontal: false, vertical: true)

                                                if let syncHealth {
                                                    HStack(alignment: .top, spacing: 8) {
                                                        Image(systemName: syncHealth.icon)
                                                            .font(.system(size: 12, weight: .bold))
                                                            .foregroundStyle(syncHealth.color)
                                                            .padding(.top, 1)

                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text(syncHealth.title)
                                                                .font(.system(size: 12, weight: .semibold))
                                                                .foregroundStyle(syncHealth.color)
                                                            Text(syncHealth.detail)
                                                                .font(.system(size: 10, weight: .medium))
                                                                .foregroundStyle(Color.white.opacity(0.48))
                                                        }

                                                        Spacer(minLength: 0)
                                                    }
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 10)
                                                    .background(syncHealth.color.opacity(0.08))
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .stroke(syncHealth.color.opacity(0.2), lineWidth: 1)
                                                    )
                                                }
                                            }
                                        }
                                    }
                                }

                            }
                            // ── Unencapsulated Bottom Delete Button ─────
                            // Unlinking a bank also affects its Plaid connection and children.
                            if institution.userId == appState.portfolioUserID {
                                Button(role: .destructive) {
                                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                    showDeleteConfirm = true
                                } label: {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "trash")
                                        Text("Delete \(institution.name.isEmpty ? "Institution" : institution.name)")
                                        Spacer()
                                    }
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.red)
                                    .padding(.vertical, 14)
                                    .background(Color.white.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                                .confirmationDialog(
                                    "Delete Bank?",
                                    isPresented: $showDeleteConfirm,
                                    titleVisibility: .visible
                                ) {
                                    Button("Delete Bank", role: .destructive) {
                                        vm.deleteInstitution(institution, appState: appState)
                                        dismiss()
                                    }
                                    Button("Cancel", role: .cancel) {}
                                }
                            }
                        }
                    }
                    .disabled(isViewer)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(hex: "#1C1C1E"))
            .disabled(isSaving)
            .onAppear {
                snapshot = currentSnapshot
                savedMetadata = ResourceSecretPreparation.metadata(for: institution)
            }
            .navigationTitle(institution.name.isEmpty ? "Institution" : institution.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(institution.name.isEmpty ? "Institution" : institution.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: "#C1AA78"))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // The form owns a value-type draft, not a saved row.
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !isViewer {
                        Button(isSaving ? "Saving…" : "Save", action: save)
                        .disabled(isSaving)
                        .fontWeight(.semibold)
                        .tint(isDirty ? .green : nil)
                    }
                }
            }
            .interactiveDismissDisabled(isNew || isSaving)
            .modifier(VaultAccessPrompt(isPresented: $showingVaultAccess, onReady: save))
            .alert("Bank Not Saved", isPresented: Binding(
                get: { saveError != nil }, set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
            .sheet(isPresented: $showShareSheet) {
                ShareEntitySheet(resourceId: institution.id, resourceType: "institution", resourceTitle: institution.name.isEmpty ? "Institution" : institution.name)
            }
            .sheet(isPresented: $showAccountHUD) {
                InstitutionAccountHUD(
                    draft: $accountDraft,
                    isNew: accountDraftIndex == nil,
                    institutionName: institution.name.isEmpty ? "Institution" : institution.name,
                    institutionId: institution.id,
                    availableCards: appState.cards.filter { $0.companyId == institution.companyId },
                    canEnterProtectedDetails: canEditAccountCredentials,
                    showsWireRoutingNumber: activeVaultDraft != nil,
                    companyId: institution.companyId,
                    vm: vm,
                    onSave: {
                        guard scenePhase == .active, auth.isAuthenticated else { return }
                        var account = accountDraft
                        if !canEditLegacyCredentials {
                            if activeVaultDraft?.canEditAccountCredentials == true {
                                do {
                                    try vaultDraft?.setAccount(account)
                                } catch {
                                    saveError = error.localizedDescription
                                    return
                                }
                            }
                            account.accountNumber = nil
                            account.routingNumber = nil
                            account.wireRoutingNumber = nil
                        }
                        var accs = institution.accounts
                        if let idx = accountDraftIndex {
                            accs[idx] = account
                        } else {
                            accs.append(account)
                        }
                        institution.accounts = accs
                        showAccountHUD = false
                    },
                    onCancel: { showAccountHUD = false },
                    onDelete: {
                        if let idx = accountDraftIndex {
                            let acc = institution.accounts[idx]
                            var updatedInstitution = institution
                            updatedInstitution.accounts.remove(at: idx)
                            if !isNew {
                                Task {
                                    do {
                                        try await vm.saveFinancialInstitutionCascade(
                                            institution: updatedInstitution,
                                            cards: [],
                                            loans: [],
                                            appState: appState
                                        )
                                        institution = updatedInstitution
                                        vm.cleanUpCustomPaymentMethod(name: acc.name.isEmpty ? acc.type : acc.name)
                                        showAccountHUD = false
                                    } catch {
                                        appState.error = "The account could not be deleted. Please try again."
                                    }
                                }
                            } else {
                                institution = updatedInstitution
                                vm.cleanUpCustomPaymentMethod(name: acc.name.isEmpty ? acc.type : acc.name)
                                showAccountHUD = false
                            }
                        }
                    }
                )
                .presentationDetents([.fraction(0.70), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
            .sheet(item: $cardDraft, onDismiss: { 
                cardDraft = nil 
            }) { cd in
                EditCardSheet(card: cd, vm: vm, institutions: institutions, cards: cards, isNew: (cd.name ?? "").isEmpty && (cd.last4 ?? "").isEmpty, isInstitutionContext: true)
            }
            .sheet(item: $loanDraft, onDismiss: { 
                loanDraft = nil 
            }) { ld in
                EditLoanSheet(loan: ld, vm: vm, isNew: ld.name.isEmpty && ld.monthlyPayment == 0, institutions: institutions, cards: cards, isInstitutionContext: true)
            }
            .alert("Sync Failed", isPresented: Binding(
                get: { syncErrorMsg != nil },
                set: { if !$0 { syncErrorMsg = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(syncErrorMsg ?? "An unknown error occurred.")
            }
        }
    }
}


/// Plaintext bank details live only in the open bank editor. Every update starts
/// from the verified full set so editing a website preserves other vault fields.
struct InstitutionVaultDraft {
    let previous: RevealedResourceCredentials
    let viewerUserID: UUID
    let canEdit: Bool
    private(set) var fields: [String: String]

    init(previous: RevealedResourceCredentials, viewerUserID: UUID, canEdit: Bool) {
        self.previous = previous
        self.viewerUserID = viewerUserID
        self.canEdit = canEdit
        fields = previous.fields
    }

    var hasChanges: Bool { fields != previous.fields }
    var canEditAccountCredentials: Bool { canEdit && protectedAccounts != nil }

    private var protectedAccounts: [ResourceBankAccountCredentials]? {
        guard let accounts = fields["accounts_data"] else { return [] }
        return try? JSONDecoder().decode([ResourceBankAccountCredentials].self, from: Data(accounts.utf8))
    }

    mutating func set(_ field: String, to value: String) {
        guard canEdit else { return }
        fields[field] = value.isEmpty ? nil : value
    }

    func accountForEditing(_ account: InstitutionAccount) -> InstitutionAccount {
        let saved = canEditAccountCredentials ? protectedAccounts?.first { $0.id == account.id } : nil
        var draft = account
        draft.accountNumber = saved?.accountNumber
        draft.routingNumber = saved?.routingNumber
        draft.wireRoutingNumber = saved?.wireRoutingNumber
        return draft
    }

    mutating func setAccount(_ account: InstitutionAccount) throws {
        guard canEdit, let saved = protectedAccounts else { throw ResourceSecretUpdateError.invalidFields }
        func nonEmpty(_ value: String?) -> String? {
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        let entry = ResourceBankAccountCredentials(
            id: account.id,
            accountNumber: nonEmpty(account.accountNumber),
            routingNumber: nonEmpty(account.routingNumber),
            wireRoutingNumber: nonEmpty(account.wireRoutingNumber)
        )
        var updated = saved
        updated.removeAll { $0.id == entry.id }
        if entry.accountNumber != nil || entry.routingNumber != nil || entry.wireRoutingNumber != nil {
            if let index = saved.firstIndex(where: { $0.id == entry.id }) {
                updated.insert(entry, at: index)
            } else {
                updated.append(entry)
            }
        }
        guard updated != saved else { return }
        if updated.isEmpty {
            fields.removeValue(forKey: "accounts_data")
        } else {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            fields["accounts_data"] = String(decoding: try encoder.encode(updated), as: UTF8.self)
        }
    }
}
