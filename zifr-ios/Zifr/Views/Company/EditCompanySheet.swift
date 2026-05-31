import SwiftUI
import PhotosUI

struct EditCompanySheet: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthViewModel.self) private var authViewModel
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
                VStack(spacing: 24) {
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
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, -8)
                    }

                    Group {
                    // Entity Name Row
                    HStack(spacing: 16) {
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
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            let colors = Company.brandColors
                            if let currentIndex = colors.firstIndex(of: colorHex) {
                                let nextIndex = (currentIndex + 1) % colors.count
                                withAnimation(.spring(response: 0.3)) {
                                    colorHex = colors[nextIndex]
                                }
                            } else {
                                colorHex = colors.first ?? "#000000"
                            }
                            logoData = nil // tapping color box clears logo to show color
                        }
                        
                        formSection {
                            PremiumInputField(label: "ENTITY NAME", placeholder: "Acme Holdings LLC", text: $name, textContentType: .organizationName)
                        }
                    }
                    .padding(.top, 8)

                    // Website Row
                    HStack(spacing: 16) {
                        formSection {
                            PremiumInputField(label: "WEBSITE", placeholder: "acme.com", text: $website, keyboardType: .URL, textContentType: .URL)
                        }
                        
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            VStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 20, weight: .semibold))
                                Text("UPLOAD")
                                    .font(.system(size: 9, weight: .black))
                                    .tracking(1)
                            }
                            .foregroundStyle(Color.white.opacity(0.8))
                            .frame(width: 76)
                            .frame(maxHeight: .infinity) // fills height of HStack defined by formSection
                            .background(Color(hex: "#2C2C2E"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        }
                        .onChange(of: selectedPhoto) { _, item in
                            Task {
                                if let data = try? await item?.loadTransferable(type: Data.self) {
                                    logoData = data
                                }
                            }
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true) // forces HStack to adhere to formSection's natural height

                    // Entity Category
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ENTITY CATEGORY")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.45))
                            .padding(.horizontal, 4)
                        
                        CustomSegmentedControl(options: ["Personal", "Business"], selection: $entityCategory)
                        .simultaneousGesture(TapGesture().onEnded {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        })
                        .onChange(of: entityCategory) { _, newValue in
                            // Reset structure when category changes
                            if newValue == "Personal" {
                                structure = "Individual"
                            } else {
                                structure = "LLC"
                            }
                        }
                    }

                    // Structure Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ENTITY STRUCTURE")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.45))
                            .padding(.horizontal, 4)
                        
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
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        .simultaneousGesture(DragGesture().onChanged { _ in
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        })
                    }
                    } // End Group
                    .disabled(isViewer)

                    VStack(spacing: 30) {
                        // App Navigators
                        VStack(alignment: .leading, spacing: 8) {
                            Text("APP NAVIGATORS")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.45))
                                .padding(.leading, 4)
                            
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    // Pop back to DashboardView, then start tutorial
                                    vm.path.removeLast(vm.path.count)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                        onboardingState.startTutorial()
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.circle")
                                        .font(.system(size: 14))
                                    Text("Tutorial")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .padding(.bottom, 4)
                            

                        }



                        // Share Entity
                        if isEditing && !isViewer {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showShareSheet = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                    Text("Share Entity")
                                }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(hex: "#4f46e5"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color(hex: "#4f46e5").opacity(0.1))
                                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color(hex: "#4f46e5").opacity(0.3), lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 22))
                            }
                            .buttonStyle(.plain)
                        }

                        // Delete
                        if isEditing {
                            Button(role: .destructive) {
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                showDeleteConfirm = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Image(systemName: company?.userId != authViewModel.currentUser?.id ? "rectangle.portrait.and.arrow.right" : "trash")
                                    Text(company?.userId != authViewModel.currentUser?.id ? "Leave Company" : "Delete \(name.isEmpty ? "Entity" : name)")
                                    Spacer()
                                }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.red)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .confirmationDialog(
                                company?.userId != authViewModel.currentUser?.id ? "Leave Company" : "Delete \"\(name.isEmpty ? "this entity" : name)\"?",
                                isPresented: $showDeleteConfirm,
                                titleVisibility: .visible
                            ) {
                                Button(company?.userId != authViewModel.currentUser?.id ? "Leave" : "Delete Entity", role: .destructive) {
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
                    }
                    .padding(.top, 10)
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(
                Color(hex: "#171717")
                    .ignoresSafeArea()
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
            )
            .navigationTitle(isEditing ? "Edit Entity" : "New Entity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !isViewer {
                        Button("Save") {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        save()
                        dismiss()
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
    }

    private var hasChanges: Bool {
        if let c = company {
            return name != c.name ||
                   structure != c.structure ||
                   entityCategory != ( (c.structure == "Individual" || c.structure == "Household") ? "Personal" : "Business" ) ||
                   colorHex != c.colorHex ||
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
        colorHex = c.colorHex
        website = c.website ?? ""
        logoData = c.logoData
    }

    private func save() {
        if let c = company {
            var updated = c
            updated.name = name; updated.structure = structure; updated.colorHex = colorHex
            updated.website = website; updated.logoData = logoData
            vm.updateCompany(updated, appState: appState)
        } else {
            // Get user ID synchronously from the AuthViewModel
            if let userId = authViewModel.currentUser?.id {
                vm.addCompany(appState: appState, userId: userId, name: name, structure: structure, colorHex: colorHex, logoData: logoData, website: website)
            } else {
                print("⚠️ [Save] No authenticated user found in AuthViewModel. Falling back to temporary UUID.")
                // Fallback to avoid breaking local app state if the user is in transition
                let fallbackId = UUID()
                vm.addCompany(appState: appState, userId: fallbackId, name: name, structure: structure, colorHex: colorHex, logoData: logoData, website: website)
            }
        }
    }


}

// MARK: - Helpers

private func formSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(spacing: 14) { content() }
}

// MARK: - Sharing UI

struct ShareEntitySheet: View {
    @Environment(\.dismiss) private var dismiss
    let resourceId: UUID
    let resourceType: String
    let resourceTitle: String
    
    @State private var email: String = ""
    @State private var senderDisplayName: String = ""
    @State private var role: String = "Viewer"
    @State private var isSending = false
    @State private var successMessage: String?
    @State private var errorMessage: String?
    
    let roles = ["Viewer", "Editor", "Admin"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header info
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#4f46e5").opacity(0.2))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: iconForResourceType(resourceType))
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundStyle(Color(hex: "#4f46e5"))
                            }
                            
                            VStack(spacing: 4) {
                                Text("Share \(resourceTitle)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                
                                Text("Invite collaborators to access this resource.")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, 24)
                        
                        VStack(spacing: 20) {
                            // Email Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Collaborator Email")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.white.opacity(0.6))
                                    .textCase(.uppercase)
                                
                                HStack {
                                    Image(systemName: "envelope.fill")
                                        .foregroundStyle(Color.white.opacity(0.5))
                                    TextField("Enter email address", text: $email)
                                        .keyboardType(.emailAddress)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .foregroundStyle(.white)
                                }
                                .padding(16)
                                .background(Color(hex: "#1A1A1C"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                            
                            // Send As Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Send As (Optional)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.white.opacity(0.6))
                                    .textCase(.uppercase)
                                
                                HStack {
                                    Image(systemName: "person.text.rectangle")
                                        .foregroundStyle(Color.white.opacity(0.5))
                                    TextField("e.g. Kris from Miloom", text: $senderDisplayName)
                                        .textInputAutocapitalization(.words)
                                        .foregroundStyle(.white)
                                }
                                .padding(16)
                                .background(Color(hex: "#1A1A1C"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                            
                            // Role Picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Permission Level")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.white.opacity(0.6))
                                    .textCase(.uppercase)
                                
                                Picker("Role", selection: $role) {
                                    ForEach(roles, id: \.self) { role in
                                        Text(role).tag(role)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .colorScheme(.dark)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Error/Success Messages
                        if let error = errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .padding(.horizontal)
                        }
                        if let success = successMessage {
                            Text(success)
                                .font(.footnote)
                                .foregroundStyle(.green)
                                .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.white.opacity(0.6))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        sendInvite()
                    } label: {
                        if isSending {
                            ProgressView()
                                .tint(.zifrGreen)
                        } else {
                            Text("Send")
                                .fontWeight(.bold)
                                .foregroundStyle(email.isEmpty ? Color.white.opacity(0.3) : .zifrGreen)
                        }
                    }
                    .disabled(email.isEmpty || isSending)
                }
            }
        }
    }
    
    private func sendInvite() {
        let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanedEmail.isEmpty else { return }
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
