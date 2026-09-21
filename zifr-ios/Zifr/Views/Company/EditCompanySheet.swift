import SwiftUI
import PhotosUI
import Supabase

private enum NewEntityFlowStep: Int, CaseIterable {
    case identity
    case connect
    case review

    var title: String {
        switch self {
        case .identity: return "Entity"
        case .connect: return "Connect"
        case .review: return "Review"
        }
    }

    var icon: String {
        switch self {
        case .identity: return "building.2"
        case .connect: return "link"
        case .review: return "checkmark"
        }
    }
}

struct NewEntitySheet: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(AccessController.self) private var accessController
    @Environment(\.dismiss) private var dismiss

    @Bindable var vm: AppViewModel
    var onComplete: (Company) -> Void

    @State private var step: NewEntityFlowStep = .identity
    @State private var name = ""
    @State private var category = "Business"
    @State private var structure = "LLC"
    @State private var colorHex = Company.brandColors.first ?? "#4f46e5"
    @State private var logoData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var createdCompany: Company?

    @State private var plaidInstitutionName = ""
    @State private var plaidAccounts: [PlaidService.PlaidAccount] = []
    @State private var plaidItemId: String?
    @State private var selectedPlaidAccountIDs: Set<String> = []
    @State private var institutionID = UUID()

    @State private var isSavingEntity = false
    @State private var isFinalizing = false
    @State private var errorMessage: String?
    @State private var showingSkipConfirmation = false
    @State private var showingAbandonConnectionConfirmation = false
    @State private var showingDiscardConfirmation = false
    @State private var showingPremiumUpgrade = false
    @FocusState private var isNameFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isBusy: Bool {
        isSavingEntity || isFinalizing
    }

    private var selectedAccounts: [PlaidService.PlaidAccount] {
        plaidAccounts.filter { selectedPlaidAccountIDs.contains($0.account_id) }
    }

    private var businessStructures: [String] {
        Company.structures.filter { !["Household", "Individual"].contains($0) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                newEntityBackground

                ScrollView {
                    VStack(spacing: 24) {
                        flowProgress

                        Group {
                            switch step {
                            case .identity:
                                identityStep
                            case .connect:
                                connectStep
                            case .review:
                                reviewStep
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("New Entity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(createdCompany == nil ? "Cancel" : "Close") {
                        closeTapped()
                    }
                    .disabled(isBusy)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionShelf
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(isBusy || createdCompany != nil || !trimmedName.isEmpty || logoData != nil)
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run { logoData = data }
                }
            }
        }
        .alert("Couldn’t continue", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            if let errorMessage { Text(errorMessage) }
        }
        .confirmationDialog(
            "Finish without connecting an account?",
            isPresented: $showingSkipConfirmation,
            titleVisibility: .visible
        ) {
            Button("Finish without accounts") { completeFlow() }
            Button("Connect an account", role: .cancel) {}
        } message: {
            Text("Connected accounts make your financial dashboard useful immediately. You can still connect later from the entity’s Financial tab.")
        }
        .confirmationDialog(
            "Stop setting up this connection?",
            isPresented: $showingAbandonConnectionConfirmation,
            titleVisibility: .visible
        ) {
            Button("Stop account setup", role: .destructive) { completeFlow() }
            Button("Keep reviewing", role: .cancel) {}
        } message: {
            Text("The entity is already saved, but this bank and its accounts won’t be added. You can connect again from the Financial tab.")
        }
        .confirmationDialog(
            "Discard this entity draft?",
            isPresented: $showingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("The entity hasn’t been created yet.")
        }
        .sheet(isPresented: $showingPremiumUpgrade) {
            PremiumUpgradeView(gate: accessController.pendingGate)
        }
    }

    private var newEntityBackground: some View {
        ZStack {
            Color(hex: "#0B0D0C")
            RadialGradient(
                colors: [Color.zifrGreen.opacity(0.28), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 460
            )
            LinearGradient(
                colors: [Color.miloomGold.opacity(0.08), .clear, Color.black.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
        .onTapGesture { isNameFocused = false }
    }

    private var flowProgress: some View {
        HStack(spacing: 0) {
            ForEach(Array(NewEntityFlowStep.allCases.enumerated()), id: \.element.rawValue) { index, item in
                VStack(spacing: 7) {
                    ZStack {
                        Circle()
                            .fill(item.rawValue <= step.rawValue ? Color.miloomGold : Color.white.opacity(0.08))
                            .frame(width: 34, height: 34)

                        Image(systemName: item.rawValue < step.rawValue ? "checkmark" : item.icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(item.rawValue <= step.rawValue ? Color(hex: "#121212") : Color.white.opacity(0.45))
                    }

                    Text(item.title)
                        .font(.caption2.weight(item == step ? .semibold : .regular))
                        .foregroundStyle(item == step ? Color.white : Color.white.opacity(0.45))
                }
                .frame(width: 62)

                if index < NewEntityFlowStep.allCases.count - 1 {
                    Capsule()
                        .fill(item.rawValue < step.rawValue ? Color.miloomGold.opacity(0.8) : Color.white.opacity(0.1))
                        .frame(maxWidth: .infinity)
                        .frame(height: 2)
                        .offset(y: -10)
                }
            }
        }
        .padding(.horizontal, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step.rawValue + 1) of 3, \(step.title)")
    }

    private var identityStep: some View {
        VStack(spacing: 20) {
            stepHeading(
                eyebrow: "START WITH THE ESSENTIALS",
                title: "Who owns this financial life?",
                detail: "Create the entity first, then connect its accounts without leaving this flow."
            )

            contentCard {
                VStack(spacing: 22) {
                    HStack(alignment: .center, spacing: 16) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            entityMark
                                .overlay(alignment: .bottomTrailing) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color(hex: "#121212"))
                                        .frame(width: 28, height: 28)
                                        .background(Color.miloomGold, in: Circle())
                                        .overlay(Circle().stroke(Color.black.opacity(0.45), lineWidth: 1))
                                        .offset(x: 4, y: 4)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(logoData == nil ? "Choose entity logo" : "Change entity logo")

                        VStack(alignment: .leading, spacing: 5) {
                            Text("Logo or icon")
                                .font(.headline)
                            Text("Optional. A monogram and color are used when you don’t add a logo.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            if logoData != nil {
                                Button("Remove logo", role: .destructive) { logoData = nil }
                                    .font(.caption.weight(.semibold))
                            }
                        }
                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("ENTITY NAME")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField(category == "Business" ? "Acme Holdings" : "Personal finances", text: $name)
                            .textContentType(.organizationName)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.continue)
                            .focused($isNameFocused)
                            .onSubmit { saveIdentityAndContinue() }
                            .font(.body.weight(.medium))
                            .padding(.horizontal, 14)
                            .frame(height: 52)
                            .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(isNameFocused ? Color.miloomGold.opacity(0.9) : Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("CATEGORY")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Picker("Category", selection: $category) {
                            Text("Personal").tag("Personal")
                            Text("Business").tag("Business")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: category) { _, value in
                            structure = value == "Personal" ? "Individual" : "LLC"
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(category == "Business" ? "BUSINESS TYPE" : "PROFILE TYPE")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Menu {
                            ForEach(category == "Business" ? businessStructures : ["Individual", "Household"], id: \.self) { option in
                                Button {
                                    structure = option
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    if structure == option {
                                        Label(option, systemImage: "checkmark")
                                    } else {
                                        Text(option)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Label(structure, systemImage: category == "Business" ? "building.2" : "person.crop.circle")
                                    .font(.body.weight(.medium))
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 14)
                            .frame(height: 52)
                            .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    if logoData == nil {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ICON COLOR")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5),
                                spacing: 4
                            ) {
                                ForEach(Company.brandColors, id: \.self) { hex in
                                    Button {
                                        colorHex = hex
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    } label: {
                                        Circle()
                                            .fill(Color(hex: hex))
                                            .frame(width: 28, height: 28)
                                            .overlay {
                                                if colorHex.caseInsensitiveCompare(hex) == .orderedSame {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 11, weight: .black))
                                                        .foregroundStyle(.white)
                                                }
                                            }
                                            .overlay(Circle().stroke(Color.white.opacity(colorHex.caseInsensitiveCompare(hex) == .orderedSame ? 0.8 : 0.18), lineWidth: 1.5))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Select icon color")
                                    .accessibilityValue(colorHex.caseInsensitiveCompare(hex) == .orderedSame ? "Selected" : "")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var entityMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(hex: colorHex))

            if let logoData, let image = UIImage(data: logoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if trimmedName.isEmpty {
                Image(systemName: category == "Business" ? "building.2.fill" : "person.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
                Text(String(trimmedName.prefix(1)).uppercased())
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 84, height: 84)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1))
    }

    private var connectStep: some View {
        VStack(spacing: 20) {
            stepHeading(
                eyebrow: "RECOMMENDED",
                title: "Bring \(createdCompany?.name ?? "your entity") to life",
                detail: "Connect at least one account so balances, transactions, cards, and loans arrive already organized."
            )

            contentCard {
                VStack(spacing: 22) {
                    ZStack {
                        Circle()
                            .fill(Color.zifrGreen.opacity(0.2))
                            .frame(width: 88, height: 88)
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(Color.miloomGold)
                    }

                    VStack(spacing: 8) {
                        Text("Connect your first account")
                            .font(.title3.weight(.bold))
                        Text("Securely choose a bank with Plaid. You’ll review every account before anything is added to Miloom.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let company = createdCompany {
                        PlaidLinkButton(
                            companyId: company.id,
                            buttonText: "Connect an account",
                            accentColor: Color.miloomGold,
                            foregroundColor: Color(hex: "#121212")
                        ) { institutionName, accounts, itemId in
                            plaidInstitutionName = institutionName
                            plaidAccounts = accounts
                            plaidItemId = itemId
                            selectedPlaidAccountIDs = Set(accounts.map(\.account_id))
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                                step = .review
                            }
                        }
                    }

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(Color.zifrGreen)
                        Text("Miloom never receives your bank password. Plaid handles the secure sign-in and consent flow.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Color.miloomGold)
                Text("Most useful setup: one primary checking or credit account")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
        }
    }

    private var reviewStep: some View {
        VStack(spacing: 20) {
            stepHeading(
                eyebrow: "YOU’RE IN CONTROL",
                title: "Choose accounts to add",
                detail: "All accounts are selected. Turn off anything that doesn’t belong to this entity."
            )

            contentCard {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "building.columns.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.miloomGold)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(plaidInstitutionName.isEmpty ? "Connected institution" : plaidInstitutionName)
                                .font(.headline)
                            Text("\(selectedAccounts.count) of \(plaidAccounts.count) selected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(selectedAccounts.count == plaidAccounts.count ? "Clear" : "Select all") {
                            if selectedAccounts.count == plaidAccounts.count {
                                selectedPlaidAccountIDs.removeAll()
                            } else {
                                selectedPlaidAccountIDs = Set(plaidAccounts.map(\.account_id))
                            }
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                        .font(.caption.weight(.semibold))
                        .frame(minHeight: 44)
                    }
                    .padding(.bottom, 14)

                    Divider().overlay(Color.white.opacity(0.08))

                    ForEach(Array(plaidAccounts.enumerated()), id: \.element.account_id) { index, account in
                        accountSelectionRow(account)
                        if index < plaidAccounts.count - 1 {
                            Divider()
                                .overlay(Color.white.opacity(0.07))
                                .padding(.leading, 48)
                        }
                    }
                }
            }

            if selectedPlaidAccountIDs.isEmpty {
                Label("Select at least one account to finish connecting this bank.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(Color.miloomGold)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func accountSelectionRow(_ account: PlaidService.PlaidAccount) -> some View {
        let selected = selectedPlaidAccountIDs.contains(account.account_id)
        let currency = account.balances.iso_currency_code ?? account.balances.unofficial_currency_code ?? "USD"
        let balance = account.balances.current ?? account.balances.available

        return Button {
            if selected {
                selectedPlaidAccountIDs.remove(account.account_id)
            } else {
                selectedPlaidAccountIDs.insert(account.account_id)
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 23))
                    .foregroundStyle(selected ? Color.zifrGreen : Color.white.opacity(0.28))

                Image(systemName: accountIcon(account))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.miloomGold)
                    .frame(width: 28, height: 28)
                    .background(Color.miloomGold.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(account.official_name ?? account.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text([account.subtype?.capitalized ?? account.type.capitalized, account.mask.map { "••\($0)" }].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                if let balance {
                    Text(balance, format: .currency(code: currency))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(account.official_name ?? account.name), \(selected ? "selected" : "not selected")")
    }

    private func accountIcon(_ account: PlaidService.PlaidAccount) -> String {
        switch account.type.lowercased() {
        case "credit": return "creditcard.fill"
        case "loan": return "banknote.fill"
        case "investment": return "chart.line.uptrend.xyaxis"
        default: return "dollarsign.circle.fill"
        }
    }

    private func stepHeading(eyebrow: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(.caption2.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(Color.miloomGold)
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func contentCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }

    @ViewBuilder
    private var actionShelf: some View {
        VStack(spacing: 10) {
            switch step {
            case .identity:
                Button { saveIdentityAndContinue() } label: {
                    HStack(spacing: 8) {
                        if isSavingEntity {
                            ProgressView().tint(Color(hex: "#121212"))
                        } else {
                            Text("Continue to accounts")
                            Image(systemName: "arrow.right")
                        }
                    }
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                }
                .disabled(trimmedName.isEmpty || isSavingEntity)
                .buttonStyle(NewEntityPrimaryButtonStyle())

            case .connect:
                Button("Set up later") { showingSkipConfirmation = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .accessibilityHint("Finishes creating the entity without linked accounts")

            case .review:
                Button { saveSelectedAccounts() } label: {
                    HStack(spacing: 8) {
                        if isFinalizing {
                            ProgressView().tint(Color(hex: "#121212"))
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Add \(selectedAccounts.count) account\(selectedAccounts.count == 1 ? "" : "s")")
                        }
                    }
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                }
                .disabled(selectedAccounts.isEmpty || isFinalizing)
                .buttonStyle(NewEntityPrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(actionShelfBackground)
    }

    @ViewBuilder
    private var actionShelfBackground: some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular.tint(Color.black.opacity(0.16)), in: Rectangle())
        } else {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.24))
        }
    }

    private func closeTapped() {
        if createdCompany != nil, step == .review {
            showingAbandonConnectionConfirmation = true
        } else if createdCompany != nil {
            showingSkipConfirmation = true
        } else if !trimmedName.isEmpty || logoData != nil {
            showingDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    private func saveIdentityAndContinue() {
        guard !trimmedName.isEmpty, !isSavingEntity else { return }
        isNameFocused = false

        guard accessController.request(
            .additionalCompany,
            source: "new_entity_sheet",
            appState: appState,
            userId: authViewModel.currentUser?.id
        ) else {
            showingPremiumUpgrade = true
            return
        }

        guard let userID = authViewModel.currentUser?.id else {
            errorMessage = "Your session is no longer available. Please sign in again before creating an entity."
            return
        }

        if createdCompany != nil {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { step = .connect }
            return
        }

        let company = Company(
            userId: userID,
            name: trimmedName,
            structure: structure,
            colorHex: colorHex.lowercased(),
            logoData: logoData
        )

        isSavingEntity = true
        Task { @MainActor in
            do {
                try await DataRepository.shared.insertCompany(company)
                DummyDataSeeder.purge(appState: appState)
                appState.companies.append(company)
                createdCompany = company
                isSavingEntity = false
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { step = .connect }
            } catch {
                isSavingEntity = false
                errorMessage = "The entity couldn’t be created. Check your connection and try again."
            }
        }
    }

    private func saveSelectedAccounts() {
        guard let company = createdCompany,
              let userID = authViewModel.currentUser?.id,
              !selectedAccounts.isEmpty,
              !isFinalizing else { return }

        var institution = Institution(
            id: institutionID,
            userId: userID,
            companyId: company.id,
            name: plaidInstitutionName,
            loginUrl: inferredInstitutionURL(plaidInstitutionName),
            accounts: selectedAccounts.filter { $0.type != "credit" && $0.type != "loan" }.map(makeInstitutionAccount)
        )
        institution.isDisconnected = false

        let cards = selectedAccounts.filter { $0.type == "credit" }.map {
            makeCard($0, userID: userID, companyID: company.id)
        }
        let loans = selectedAccounts.filter { $0.type == "loan" }.map {
            makeLoan($0, userID: userID, companyID: company.id)
        }

        isFinalizing = true
        Task { @MainActor in
            do {
                try await vm.saveFinancialInstitutionCascade(
                    institution: institution,
                    cards: cards,
                    loans: loans,
                    appState: appState
                )

                if let plaidItemId {
                    struct LinkRequest: Encodable {
                        let item_id: String
                        let institution_id: String
                    }
                    let request = LinkRequest(item_id: plaidItemId, institution_id: institution.id.uuidString)
                    let options = FunctionInvokeOptions(body: try JSONEncoder().encode(request))
                    try await SupabaseService.shared.client.functions.invoke("link-plaid-institution", options: options)
                    try? await PlaidService.shared.syncLatestAvailableData(institutionId: institution.id)
                }

                isFinalizing = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                completeFlow()
            } catch {
                isFinalizing = false
                errorMessage = "Your entity is safe, but the selected accounts couldn’t be added. Try again to finish the connection."
            }
        }
    }

    private func makeInstitutionAccount(_ account: PlaidService.PlaidAccount) -> InstitutionAccount {
        InstitutionAccount(
            id: account.account_id,
            plaidAccountId: account.account_id,
            name: account.official_name ?? account.name,
            type: (account.subtype ?? account.type).capitalized,
            last4: account.mask ?? String(account.account_id.suffix(4)),
            accountNumber: account.account_number,
            routingNumber: account.routing_number,
            wireRoutingNumber: account.wire_routing_number,
            isTokenizedAccountNumber: account.is_tokenized_account_number,
            balance: account.balances.current ?? account.balances.available ?? 0,
            availableBalance: account.balances.available,
            currency: account.balances.iso_currency_code ?? account.balances.unofficial_currency_code ?? "USD",
            apy: account.apy,
            ownershipType: account.ownership_type,
            verificationStatus: account.verification_status,
            persistentAccountId: account.persistent_account_id
        )
    }

    private func makeCard(_ account: PlaidService.PlaidAccount, userID: UUID, companyID: UUID) -> FinancialCard {
        let dueDate = plaidDate(account.liability_details?.next_payment_due_date)
        return FinancialCard(
            userId: userID,
            companyId: companyID,
            name: account.name,
            institutionName: plaidInstitutionName,
            last4: account.mask ?? String(account.account_id.suffix(4)),
            type: "Credit",
            limit: account.balances.limit ?? 0,
            paidOn: dueDate.map { String(Calendar.current.component(.day, from: $0)) },
            balance: account.balances.current ?? account.balances.available ?? 0,
            moPayment: account.liability_details?.effectiveMinimumPayment ?? 0,
            apr: account.liability_details?.effectiveAPR ?? 0,
            plaidAccountId: account.account_id
        )
    }

    private func makeLoan(_ account: PlaidService.PlaidAccount, userID: UUID, companyID: UUID) -> Loan {
        let details = account.liability_details
        let balance = account.balances.current ?? account.balances.available ?? 0
        let term = details?.loan_term ?? "0 months"
        let parsedTerm = plaidTerm(term)
        return Loan(
            userId: userID,
            companyId: companyID,
            lender: plaidInstitutionName,
            name: details?.loan_name ?? account.name,
            principalAmount: details?.origination_principal_amount ?? balance,
            remainingBalance: balance,
            interestRate: details?.effectiveAPR ?? 0,
            term: term,
            termYears: parsedTerm.years,
            termMonths: parsedTerm.months,
            monthlyPayment: details?.effectiveMinimumPayment ?? 0,
            startDate: plaidDate(details?.origination_date) ?? Date(),
            maturityDate: plaidDate(details?.maturity_date ?? details?.expected_payoff_date),
            nextPaymentAt: plaidDate(details?.next_payment_due_date),
            plaidAccountId: account.account_id
        )
    }

    private func inferredInstitutionURL(_ value: String) -> String? {
        let cleaned = value.lowercased().filter { $0.isLetter || $0.isNumber }
        return cleaned.isEmpty ? nil : cleaned + ".com"
    }

    private func plaidDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func plaidTerm(_ value: String) -> (years: Int, months: Int) {
        let number = Int(value.split(separator: " ").first ?? "") ?? 0
        if value.lowercased().contains("year") { return (number, 0) }
        return (number / 12, number % 12)
    }

    private func completeFlow() {
        guard let createdCompany else { return }
        dismiss()
        onComplete(createdCompany)
    }
}

private struct NewEntityPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? Color(hex: "#121212") : Color.white.opacity(0.34))
            .background(
                isEnabled ? Color.miloomGold : Color.white.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct EditCompanySheet: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(AccessController.self) private var accessController
    @Environment(\.dismiss) private var dismiss
    @Environment(OnboardingStateManager.self) private var onboardingState
    @Bindable var vm: AppViewModel
    var company: Company?

    @State private var name: String = ""
    @State private var structure: String = "Individual"
    @State private var entityCategory: String = "Personal"
    @State private var colorHex: String = "#000000"
    @State private var website: String = ""
    @State private var logoData: Data? = nil
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var showDeleteConfirm = false
    @State private var showShareSheet = false
    @State private var showPremiumUpgrade = false

    var isEditing: Bool { company != nil }

    private var isViewer: Bool {
        shareRole == "Viewer"
    }

    private var shareRole: String? {
        guard let cId = company?.id else { return nil }
        return appState.resourceShares.first(where: { $0.resourceId == cId })?.role
    }

    private var sharedBy: String? {
        guard let cId = company?.id else { return nil }
        return appState.resourceShares.first(where: { $0.resourceId == cId })?.senderEmail
    }

    private var isSharedWithMe: Bool {
        guard let company = company, let currentUserId = authViewModel.currentUser?.id else { return false }
        return company.userId != currentUserId
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isSharedWithMe {
                        HStack(spacing: 8) {
                            Image(systemName: "person.2.fill")
                            Text("Shared with you • \(shareRole ?? "Viewer")")
                            Spacer()
                            if let sender = sharedBy {
                                Text(sender)
                                    .lineLimit(1)
                                    .foregroundStyle(Color.white.opacity(0.6))
                            }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: "#818cf8"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#4f46e5").opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#818cf8").opacity(0.3), lineWidth: 1))
                    }

                    if let company {
                        ResourceConnectionsSection(
                            reference: ResourceReference(kind: .company, resourceId: company.id)
                        )
                    }

                    Group {
                        // MARK: - Business Identity Card
                        ZifrSheetCard(title: "BUSINESS IDENTITY", icon: "building.2.fill") {
                            VStack(spacing: 14) {
                                // Entity Name Row
                                HStack(spacing: 14) {
                                    ZStack {
                                        if let data = logoData, let ui = UIImage(data: data) {
                                            Image(uiImage: ui)
                                                .resizable()
                                                .scaledToFill()
                                        } else {
                                            ZStack {
                                                Color(hex: colorHex)
                                                Text(name.isEmpty ? "?" : String(name.prefix(1)).uppercased())
                                                    .font(.system(size: 28, weight: .black, design: .rounded))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        
                                        if logoData != nil {
                                            Button { logoData = nil } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.red, .white)
                                                    .font(.system(size: 20))
                                            }
                                            .padding(4)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                            .offset(x: 8, y: -8)
                                        }
                                    }
                                    .frame(width: 70, height: 70)
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                    .onTapGesture {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        let colors = Company.brandColors
                                        if let currentIndex = colors.firstIndex(where: { $0.caseInsensitiveCompare(colorHex) == .orderedSame }) {
                                            let nextIndex = (currentIndex + 1) % colors.count
                                            withAnimation(.spring(response: 0.3)) {
                                                colorHex = colors[nextIndex]
                                            }
                                        } else {
                                            colorHex = colors.first ?? "#4f46e5"
                                        }
                                        logoData = nil // tapping color box clears logo to show color
                                    }
                                    
                                    formSection {
                                        PremiumInputField(label: "BUSINESS NAME", placeholder: "Acme Holdings LLC", text: $name, textContentType: .organizationName)
                                    }
                                }

                                // Website Row
                                HStack(spacing: 12) {
                                    formSection {
                                        PremiumInputField(label: "WEBSITE", placeholder: "acme.com", text: $website, keyboardType: .URL, textContentType: .URL)
                                    }
                                    
                                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                        VStack(spacing: 4) {
                                            Image(systemName: "square.and.arrow.up")
                                                .font(.system(size: 18, weight: .semibold))
                                            Text("UPLOAD")
                                                .font(.system(size: 9, weight: .black))
                                                .tracking(1)
                                        }
                                        .foregroundStyle(Color.white.opacity(0.8))
                                        .frame(width: 72)
                                        .frame(maxHeight: .infinity)
                                        .background(Color(hex: "#2C2C2E"))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                                    }
                                    .onChange(of: selectedPhoto) { _, item in
                                        Task {
                                            if let data = try? await item?.loadTransferable(type: Data.self) {
                                                logoData = data
                                            }
                                        }
                                    }
                                }
                                .fixedSize(horizontal: false, vertical: true)

                                // Entity Category
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("BUSINESS CATEGORY")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                        .padding(.horizontal, 2)
                                    
                                    CustomSegmentedControl(options: ["Personal", "Business"], selection: $entityCategory)
                                    .simultaneousGesture(TapGesture().onEnded {
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    })
                                    .onChange(of: entityCategory) { _, newValue in
                                        if newValue == "Personal" {
                                            structure = "Individual"
                                        } else {
                                            structure = "LLC"
                                        }
                                    }
                                }

                                // Structure Picker
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("BUSINESS STRUCTURE")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                        .padding(.horizontal, 2)
                                    
                                    Picker("Select Structure", selection: $structure) {
                                        if entityCategory == "Personal" {
                                            Text("Household").tag("Household")
                                            Text("Individual").tag("Individual")
                                        } else {
                                            ForEach(Company.structures.filter { $0 != "Personal" && $0 != "Household" && $0 != "Individual" }, id: \.self) { s in
                                                Text(s).tag(s)
                                            }
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(height: 120)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(hex: "#2C2C2E"))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                                    .simultaneousGesture(DragGesture().onChanged { _ in
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    })
                                }
                            }
                        }

                        // MARK: - App Navigation Card
                        ZifrSheetCard(title: "APP NAVIGATION", icon: "arrow.triangle.turn.up.right.diamond.fill") {
                            VStack(spacing: 12) {
                                // Demo Account Toggle
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Demo Account")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white)
                                        Text("Show dummy demo account data across the app")
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundStyle(Color.white.opacity(0.5))
                                    }
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: {
                                            appState.companies.contains(where: { $0.id == DummyDataSeeder.dummyCompanyId })
                                        },
                                        set: { enable in
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            if enable {
                                                let userId = authViewModel.currentUser?.id ?? UUID()
                                                DummyDataSeeder.seed(appState: appState, userId: userId, force: true)
                                            } else {
                                                DummyDataSeeder.purge(appState: appState)
                                                if company?.id == DummyDataSeeder.dummyCompanyId {
                                                    dismiss()
                                                }
                                            }
                                        }
                                    ))
                                    .labelsHidden()
                                    .tint(Color.zifrGreen)
                                }
                                .padding(.horizontal, 14)
                                .frame(height: 52)
                                .background(Color(hex: "#2C2C2E"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))

                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    dismiss()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        vm.path = NavigationPath()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                            onboardingState.startTutorial()
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "play.circle")
                                            .font(.system(size: 16))
                                        Text("Replay Tutorial")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(MiloomSecondaryButtonStyle())
                            }
                        }

                        // MARK: - Actions Card
                        if isEditing && !isViewer {
                            ZifrSheetCard(title: "ACTIONS", icon: "slider.horizontal.3") {
                                VStack(spacing: 12) {
                                    // Share Entity
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        showShareSheet = true
                                    } label: {
                                        VStack(spacing: 4) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "person.crop.circle.badge.plus")
                                                Text("Share Business")
                                            }
                                            .font(.system(size: 13, weight: .semibold))
                                            Text("Invite collaborators to access this business")
                                                .font(.system(size: 10, weight: .regular))
                                                .foregroundStyle(Color.white.opacity(0.6))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(MiloomSecondaryButtonStyle())
                                }
                            }
                        }

                        if isEditing {
                            // ── Unencapsulated Bottom Delete / Leave Button ─────
                            Button(role: .destructive) {
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                showDeleteConfirm = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Image(systemName: company?.userId != authViewModel.currentUser?.id ? "rectangle.portrait.and.arrow.right" : "trash")
                                    Text(company?.userId != authViewModel.currentUser?.id ? "Leave Company" : "Delete \(name.isEmpty ? "Business" : name)")
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
                                company?.userId != authViewModel.currentUser?.id ? "Leave Company" : "Delete \"\(name.isEmpty ? "this business" : name)\"?",
                                isPresented: $showDeleteConfirm,
                                titleVisibility: .visible
                            ) {
                                Button(company?.userId != authViewModel.currentUser?.id ? "Leave" : "Delete Business", role: .destructive) {
                                    if let company { vm.deleteCompany(company, appState: appState, currentUserId: authViewModel.currentUser?.id) }
                                    dismiss()
                                }
                                Button("Cancel", role: .cancel) {}
                            } message: {
                                if company?.userId != authViewModel.currentUser?.id {
                                    Text("Are you sure you want to leave this company? It will be removed from your dashboard.")
                                } else {
                                    Text("This will permanently delete this entity and all associated data for everyone. This action cannot be undone.")
                                }
                            }
                        }
                    } // End Group
                    .disabled(isViewer)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(
                Color(hex: "#1C1C1E")
                    .ignoresSafeArea()
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
            )
            .navigationTitle(isEditing ? "Edit Business" : "New Business")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(isEditing ? "Edit Business" : "New Business")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: "#C1AA78"))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !isViewer {
                        Button("Save") {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            if save() { dismiss() }
                        }
                        .fontWeight(.semibold)
                        .tint((hasChanges && !name.isEmpty) ? .green : nil)
                        .disabled(!hasChanges || name.isEmpty)
                    }
                }
            }
        }
        .onAppear { prefill() }
        .sheet(isPresented: $showShareSheet) {
            if let c = company {
                ShareEntitySheet(resourceId: c.id, resourceType: "company", resourceTitle: c.name)
            }
        }
        .sheet(isPresented: $showPremiumUpgrade) {
            PremiumUpgradeView(gate: accessController.pendingGate)
        }
    }

    private var hasChanges: Bool {
        if let c = company {
            let colorChanged = colorHex.caseInsensitiveCompare(c.colorHex) != .orderedSame
            return name != c.name ||
                   structure != c.structure ||
                   entityCategory != ( (c.structure == "Individual" || c.structure == "Household") ? "Personal" : "Business" ) ||
                   colorChanged ||
                   website != c.website ||
                   logoData != c.logoData
        } else {
            return !name.isEmpty
        }
    }

    private func prefill() {
        guard let c = company else { return }
        name = c.name
        structure = c.structure
        entityCategory = (c.structure == "Individual" || c.structure == "Household") ? "Personal" : "Business"
        colorHex = c.colorHex.lowercased()
        website = c.website ?? ""
        logoData = c.logoData
    }

    @discardableResult
    private func save() -> Bool {
        let normalizedHex = colorHex.lowercased()
        if let c = company {
            var updated = c
            updated.name = name; updated.structure = structure; updated.colorHex = normalizedHex
            updated.website = website; updated.logoData = logoData
            vm.updateCompany(updated, appState: appState)
        } else {
            guard accessController.request(
                .additionalCompany,
                source: "company_editor",
                appState: appState,
                userId: authViewModel.currentUser?.id
            ) else {
                showPremiumUpgrade = true
                return false
            }
            // Get user ID synchronously from the AuthViewModel
            if let userId = authViewModel.currentUser?.id {
                vm.addCompany(appState: appState, userId: userId, name: name, structure: structure, colorHex: normalizedHex, logoData: logoData, website: website)
            } else {
                AppDiagnostics.failure("company", "create_without_authenticated_user")
                appState.error = "Your session is no longer available. Please sign in again before creating a company."
                return false
            }
        }
        return true
    }


}

// MARK: - Helpers

private func formSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(spacing: 14) { content() }
}

// MARK: - Sharing UI

struct ShareEntitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(AuthViewModel.self) private var authVM
    @Environment(AccessController.self) private var accessController
    let resourceId: UUID
    let resourceType: String
    let resourceTitle: String
    
    @State private var email: String = ""
    @State private var senderDisplayName: String = ""
    @State private var role: String = "Viewer"
    @State private var isSending = false
    @State private var successMessage: String?
    @State private var errorMessage: String?
    @State private var showingPremiumUpgrade = false
    
    let roles = ["Viewer", "Editor", "Admin"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ZifrSheetCard(title: "SHARE RESOURCE", icon: iconForResourceType(resourceType)) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(hex: "#2C2C2E"))

                                Image(systemName: iconForResourceType(resourceType))
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(Color(hex: "#C1AA78"))
                            }
                            .frame(width: 52, height: 52)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(resourceTitle)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)

                                Text("Invite a collaborator to access this resource.")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(Color.white.opacity(0.48))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 0)
                        }
                    }

                    ZifrSheetCard(title: "INVITE COLLABORATOR", icon: "envelope.badge") {
                        VStack(spacing: 14) {
                            ZifrField(
                                label: "COLLABORATOR EMAIL",
                                placeholder: "name@example.com",
                                text: $email,
                                keyboardType: .emailAddress,
                                textContentType: .emailAddress
                            )

                            ZifrField(
                                label: "SEND AS (OPTIONAL)",
                                placeholder: "e.g. Kris from Miloom",
                                text: $senderDisplayName,
                                textContentType: .name
                            )
                        }
                    }

                    ZifrSheetCard(title: "ACCESS LEVEL", icon: "person.badge.key") {
                        VStack(alignment: .leading, spacing: 12) {
                            CustomSegmentedControl(options: roles, selection: $role)

                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color(hex: "#C1AA78").opacity(0.8))
                                    .padding(.top, 1)

                                Text(roleDescription)
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundStyle(Color.white.opacity(0.48))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    if let error = errorMessage {
                        shareStatusBanner(
                            message: error,
                            systemImage: "exclamationmark.triangle.fill",
                            color: .red
                        )
                    }

                    if let success = successMessage {
                        shareStatusBanner(
                            message: success,
                            systemImage: "checkmark.circle.fill",
                            color: .green
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(hex: "#1C1C1E").ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#1C1C1E"), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Share \(resourceTitle)")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: "#C1AA78"))
                        .lineLimit(1)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        sendInvite()
                    } label: {
                        if isSending {
                            ProgressView()
                                .tint(.green)
                        } else {
                            Text("Send")
                                .fontWeight(.semibold)
                        }
                    }
                    .tint(canSend && !isSending ? .green : nil)
                    .disabled(!canSend || isSending)
                }
            }
        }
        .sheet(isPresented: $showingPremiumUpgrade) {
            PremiumUpgradeView(gate: accessController.pendingGate)
        }
    }

    private var canSend: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var roleDescription: String {
        switch role {
        case "Admin":
            return "Can view, edit, share, and manage collaborator access."
        case "Editor":
            return "Can view and edit this resource, but cannot manage access."
        default:
            return "Can view this resource without making changes."
        }
    }

    private func shareStatusBanner(message: String, systemImage: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)

            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.35), lineWidth: 1)
        )
    }
    
    private func sendInvite() {
        let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanedEmail.isEmpty else { return }
        guard accessController.request(
            .guestCollaboration,
            source: "share_invitation",
            appState: appState,
            userId: authVM.currentUser?.id
        ) else {
            showingPremiumUpgrade = true
            return
        }
        isSending = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                try await DataRepository.shared.inviteUser(email: cleanedEmail, role: role, resourceId: resourceId, resourceType: resourceType, senderDisplayName: senderDisplayName.isEmpty ? nil : senderDisplayName)
                await DataRepository.shared.logSecurityEvent(title: "Resource Shared", message: "You shared \(resourceTitle) with \(cleanedEmail).")
                await MainActor.run {
                    isSending = false
                    successMessage = "Invitation sent successfully!"
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    // Dismiss after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    errorMessage = error.localizedDescription
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }
}

private func iconForResourceType(_ type: String) -> String {
    switch type {
    case "company": return "building.2.crop.circle"
    case "all_subscriptions", "subscription": return "repeat.circle"
    case "all_documents", "document": return "doc.text"
    case "all_financials", "institution", "card", "loan": return "dollarsign.circle"
    default: return "person.crop.circle.badge.plus"
    }
}
