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
    @State private var websiteFetchTask: Task<Void, Never>? = nil

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
                                    .onChange(of: website) { _, newValue in
                                        websiteFetchTask?.cancel()
                                        websiteFetchTask = Task {
                                            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s debounce
                                            guard !Task.isCancelled else { return }
                                            
                                            // Only auto-fetch if there is no custom logo
                                            guard logoData == nil else { return }
                                            
                                            var host = newValue.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                                            if host.isEmpty { return }
                                            if !host.hasPrefix("http") { host = "https://\(host)" }
                                            guard let url = URL(string: host), let domain = url.host else { return }
                                            
                                            let cleanDomain = domain.replacingOccurrences(of: "www.", with: "")
                                            let clearbitURL = URL(string: "https://logo.clearbit.com/\(cleanDomain)?size=256")!
                                            let googleURL = URL(string: "https://www.google.com/s2/favicons?domain=\(cleanDomain)&sz=256")!
                                            
                                            do {
                                                var fetchedData: Data? = nil
                                                var success = false
                                                
                                                // Try Clearbit first with a strict 1.5 second timeout
                                                do {
                                                    let config = URLSessionConfiguration.default
                                                    config.timeoutIntervalForRequest = 1.5
                                                    config.timeoutIntervalForResource = 1.5
                                                    let fastSession = URLSession(configuration: config)
                                                    
                                                    let (data, response) = try await fastSession.data(from: clearbitURL)
                                                    if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                                                        fetchedData = data
                                                        success = true
                                                    }
                                                } catch {
                                                    // Clearbit failed or timed out
                                                }
                                                
                                                // Fallback to Google if Clearbit failed (404, DNS error, timeout, etc)
                                                if !success {
                                                    let (data, response) = try await URLSession.shared.data(from: googleURL)
                                                    if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                                                        fetchedData = data
                                                    }
                                                }
                                                
                                                if let finalData = fetchedData {
                                                    await MainActor.run {
                                                        // Ensure user hasn't uploaded manually while we were fetching
                                                        if self.logoData == nil {
                                                            self.logoData = finalData
                                                        }
                                                    }
                                                }
                                            } catch {
                                                print("Logo auto-fetch completely failed: \(error)")
                                            }
                                        }
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

                        // MARK: - App Navigators Card
                        ZifrSheetCard(title: "APP NAVIGATORS", icon: "arrow.triangle.turn.up.right.diamond.fill") {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    vm.path = NavigationPath()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                        onboardingState.startTutorial(appState: appState, userId: authViewModel.currentUser?.id ?? UUID())
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

    private func save() {
        let normalizedHex = colorHex.lowercased()
        if let c = company {
            var updated = c
            updated.name = name; updated.structure = structure; updated.colorHex = normalizedHex
            updated.website = website; updated.logoData = logoData
            vm.updateCompany(updated, appState: appState)
        } else {
            // Get user ID synchronously from the AuthViewModel
            if let userId = authViewModel.currentUser?.id {
                vm.addCompany(appState: appState, userId: userId, name: name, structure: structure, colorHex: normalizedHex, logoData: logoData, website: website)
            } else {
                print("⚠️ [Save] No authenticated user found in AuthViewModel. Falling back to temporary UUID.")
                // Fallback to avoid breaking local app state if the user is in transition
                let fallbackId = UUID()
                vm.addCompany(appState: appState, userId: fallbackId, name: name, structure: structure, colorHex: normalizedHex, logoData: logoData, website: website)
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
    @Environment(AppState.self) private var appState
    let resourceId: UUID
    let resourceType: String
    let resourceTitle: String
    
    @State private var email: String = ""
    @State private var senderDisplayName: String = ""
    @State private var role: String = "Viewer"
    @State private var isSending = false
    @State private var successMessage: String?
    @State private var errorMessage: String?
    
    @State private var auditResult: String?
    @State private var isAuditing = false
    
    private var activeShares: [ResourceShare] {
        appState.resourceShares.filter { $0.resourceId == resourceId }
    }
    
    let roles = ["Viewer", "Editor", "Admin"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.zifrBG.ignoresSafeArea()
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
                        
                        if !activeShares.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Current Collaborators")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color.white.opacity(0.6))
                                        .textCase(.uppercase)
                                    Spacer()
                                    Button {
                                        runAudit()
                                    } label: {
                                        if isAuditing {
                                            ProgressView().scaleEffect(0.8)
                                        } else {
                                            HStack(spacing: 4) {
                                                Image(systemName: "sparkles")
                                                Text("AI Audit")
                                            }
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Color(hex: "#0A84FF"))
                                        }
                                    }
                                }
                                
                                if let audit = auditResult {
                                    HStack(alignment: .top) {
                                        Image(systemName: "exclamationmark.shield.fill")
                                            .foregroundStyle(Color(hex: "#0A84FF"))
                                            .padding(.top, 2)
                                        Text(audit)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(.white)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(12)
                                    .background(Color(hex: "#0A84FF").opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#0A84FF").opacity(0.3), lineWidth: 1))
                                }
                                
                                VStack(spacing: 8) {
                                    ForEach(activeShares) { share in
                                        HStack {
                                            ZStack {
                                                Circle().fill(Color.white.opacity(0.1)).frame(width: 36, height: 36)
                                                Image(systemName: "person.fill").font(.system(size: 16)).foregroundStyle(.white)
                                            }
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(share.recipientEmail ?? "User \(share.userId.uuidString.prefix(6))")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundStyle(.white)
                                                    .lineLimit(1)
                                                Text("\(share.role) • Added \(share.createdAt, format: .dateTime.month().day().year())")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(Color.white.opacity(0.5))
                                            }
                                            Spacer()
                                            Button("Revoke") {
                                                Task {
                                                    // Revoke functionality here (optional for now, or just an alert)
                                                }
                                            }
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.red)
                                        }
                                        .padding(12)
                                        .background(Color(hex: "#1A1A1C"))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            Divider()
                                .overlay(Color.white.opacity(0.1))
                                .padding(.vertical, 8)
                        }
                        
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
    
    private func runAudit() {
        guard !activeShares.isEmpty else { return }
        isAuditing = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        Task {
            let result = await GeminiService.shared.auditShares(shares: activeShares)
            await MainActor.run {
                self.auditResult = result
                self.isAuditing = false
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
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
