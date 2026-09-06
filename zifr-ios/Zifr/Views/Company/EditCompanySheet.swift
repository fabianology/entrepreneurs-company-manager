import SwiftUI
import PhotosUI

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
