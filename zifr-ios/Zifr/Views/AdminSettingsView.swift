import SwiftUI
import Supabase

struct AdminSettingsView: View {
    @Bindable var vm: AppViewModel
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    @State private var userEmail: String = "Loading..."
    @AppStorage("autoLockTimeout") private var autoLockTimeout: Int = 0
    @State private var showingExportAlert: Bool = false
    @State private var showingDeleteAccountSheet: Bool = false
    @State private var showingEditProfile: Bool = false
    @State private var showingPremiumUpgrade: Bool = false
    @State private var showingMessages: Bool = false
    @State private var showingLinkedAccounts: Bool = false
    @State private var showingCollaborators: Bool = false
    
    private var activeInstitutions: [Institution] {
        appState.institutions.filter { inst in
            appState.companies.contains { $0.id == inst.companyId }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            
            AnimatedHeaderBackground()
                .ignoresSafeArea(edges: .top)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        Text("ACCOUNT & SETTINGS")
                            .zifrLabel()
                        
                        Spacer()
                        
                        Color.clear.frame(width: 44, height: 44) // Balance
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // Profile Section
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingEditProfile = true
                    } label: {
                        VStack(spacing: 16) {
                            if let user = authVM.currentUser,
                               case let .string(avatarUrlString) = user.userMetadata["avatar_url"],
                               let avatarUrl = URL(string: avatarUrlString) {
                                AsyncImage(url: avatarUrl) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        Image(systemName: "person.crop.circle.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .foregroundStyle(Color.white.opacity(0.2))
                                    }
                                }
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .background(Circle().fill(Color.white.opacity(0.05)))
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .foregroundStyle(Color.white.opacity(0.2))
                                    .background(Color.white.opacity(0.05))
                                    .clipShape(Circle())
                            }
                            
                            VStack(spacing: 6) {
                                Text(userEmail)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.white)
                                
                                Text("EDIT PROFILE")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .masonryGlass(cornerRadius: 24)
                    }
                    .padding(.horizontal, 20)

                    // Premium Upgrade
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingPremiumUpgrade = true
                    } label: {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.white)
                                    .font(.system(size: 18))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("MILOOM PRO")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("Unlock all premium features")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.8))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.6))
                                .padding(.leading, 8)
                        }
                        .padding(16)
                        .background(.miloomSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .padding(.horizontal, 20)
                    
                    // Messages
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingMessages = true
                    } label: {
                        HStack {
                            Image(systemName: "tray.full.fill")
                                .foregroundStyle(Color(hex: "#4f46e5"))
                                .font(.system(size: 20, weight: .semibold))
                                .frame(width: 44, height: 44)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("MESSAGES")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("Activity and notifications")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            let unreadCount = appState.activityLogs.filter { !$0.isRead }.count
                            if unreadCount > 0 {
                                Text("\(unreadCount)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.4))
                                .padding(.leading, 8)
                        }
                        .padding(16)
                        .masonryGlass(cornerRadius: 24)
                    }
                    .padding(.horizontal, 20)
                    
                    // Security & Privacy
                    VStack(alignment: .leading, spacing: 16) {
                        Text("SECURITY & PRIVACY")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .padding(.leading, 40)
                            
                        VStack(spacing: 0) {
                            ToggleRow(
                                icon: "faceid", 
                                title: "Require Face ID", 
                                isOn: Binding(
                                    get: { authVM.isBiometricEnabled },
                                    set: { authVM.isBiometricEnabled = $0 }
                                )
                            )
                            Divider().background(Color.white.opacity(0.1)).padding(.leading, 56)
                            
                            Menu {
                                Button("Immediately") { autoLockTimeout = 0 }
                                Button("1 Minute") { autoLockTimeout = 1 }
                                Button("5 Minutes") { autoLockTimeout = 5 }
                            } label: {
                                SettingsRow(icon: "clock.fill", title: "Auto-Lock", value: autoLockTimeout == 0 ? "Immediately" : "\(autoLockTimeout) min")
                            }
                            
                            Divider().background(Color.white.opacity(0.1)).padding(.leading, 56)
                            
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showingExportAlert = true
                            } label: {
                                SettingsRow(icon: "square.and.arrow.down.fill", title: "Export My Data", value: "")
                            }
                        }
                        .masonryGlass(cornerRadius: 24)
                        .padding(.horizontal, 20)
                    }

                    // Linked Accounts
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingLinkedAccounts = true
                    } label: {
                        HStack {
                            Image(systemName: "building.columns.fill")
                                .foregroundStyle(Color(hex: "#1A7077"))
                                .font(.system(size: 20, weight: .semibold))
                                .frame(width: 44, height: 44)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("LINKED ACCOUNTS")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("Manage Plaid bank connections")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            if !activeInstitutions.isEmpty {
                                Text("\(activeInstitutions.count)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.4))
                                .padding(.leading, 8)
                        }
                        .padding(16)
                        .masonryGlass(cornerRadius: 24)
                    }
                    .padding(.horizontal, 20)
                    
                    // Collaborators & Sharing
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingCollaborators = true
                    } label: {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundStyle(Color(hex: "#4f46e5"))
                                .font(.system(size: 20, weight: .semibold))
                                .frame(width: 44, height: 44)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("COLLABORATORS & SHARING")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("Manage access and active shares")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.4))
                                .padding(.leading, 8)
                        }
                        .padding(16)
                        .masonryGlass(cornerRadius: 24)
                    }
                    .padding(.horizontal, 20)
                    
                    // Active Sessions
                    VStack(alignment: .leading, spacing: 16) {
                        Text("ACTIVE SESSIONS")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .padding(.leading, 40)
                            
                        VStack(spacing: 0) {
                            if authVM.activeSessions.isEmpty {
                                Text("No active sessions found")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.white.opacity(0.4))
                                    .padding(.vertical, 20)
                                    .frame(maxWidth: .infinity)
                            } else {
                                ForEach(authVM.activeSessions) { session in
                                    let isCurrent = session.id == authVM.currentSessionId
                                    let deviceDetails = parseUserAgent(session.userAgent)
                                    
                                    SessionRow(
                                        icon: deviceDetails.icon,
                                        device: deviceDetails.name,
                                        location: session.location ?? session.ipAddress ?? "Unknown IP",
                                        isCurrent: isCurrent,
                                        onRevoke: {
                                            Task {
                                                await authVM.revokeSession(id: session.id)
                                            }
                                        }
                                    )
                                    
                                    if session.id != authVM.activeSessions.last?.id {
                                        Divider().background(Color.white.opacity(0.1)).padding(.leading, 56)
                                    }
                                }
                            }
                        }
                        .masonryGlass(cornerRadius: 24)
                        .padding(.horizontal, 20)
                    }
                    
                    // Actions
                    VStack(spacing: 0) {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            Task {
                                await authVM.signOut()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.red)
                                    .frame(width: 24)
                                Text("Sign Out")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.red)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .frame(height: 56)
                        }
                        
                        Divider().background(Color.white.opacity(0.1)).padding(.leading, 56)
                        
                        Button {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            showingDeleteAccountSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(Color.red.opacity(0.7))
                                    .frame(width: 24)
                                Text("Delete Account")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.red.opacity(0.7))
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .frame(height: 56)
                        }
                    }
                    .masonryGlass(cornerRadius: 24)
                    .padding(.horizontal, 20)
                    
                }
                .padding(.bottom, 60)
            }
        }
        .navigationBarHidden(true)
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 50 && abs(value.translation.height) < 50 {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
                }
        )
        .alert("Export Data", isPresented: $showingExportAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Export (JSON)") {
                // Trigger export
            }
        } message: {
            Text("A secure download link containing all your company and financial data will be generated.")
        }
        .sheet(isPresented: $showingDeleteAccountSheet) {
            DeleteAccountView()
                .environment(authVM)
        }
        .task {
            if let session = try? await SupabaseService.shared.client.auth.session {
                await MainActor.run {
                    self.userEmail = session.user.email ?? "User"
                }
            } else {
                await MainActor.run { self.userEmail = "User" }
            }
            await authVM.fetchActiveSessions()
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView(userEmail: $userEmail)
                .environment(authVM)
        }
        .sheet(isPresented: $showingPremiumUpgrade) {
            PremiumUpgradeView()
                .environment(authVM)
        }
        .sheet(isPresented: $showingMessages) {
            ActivityLogsView(vm: vm)
        }
        .sheet(isPresented: $showingLinkedAccounts) {
            LinkedAccountsSheet(vm: vm, appState: appState)
        }
        .sheet(isPresented: $showingCollaborators) {
            CollaboratorsSheet(vm: vm, appState: appState)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.5))
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.4))
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.2))
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.clear)
    }
}

struct ToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.5))
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(Color(hex: "#3b82f6"))
                .labelsHidden()
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.clear)
    }
}

struct SessionRow: View {
    let icon: String
    let device: String
    let location: String
    let isCurrent: Bool
    var onRevoke: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.5))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(device)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                    if isCurrent {
                        Text("Current")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.4))
                            .clipShape(Capsule())
                    }
                }
                Text(location)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            
            Spacer()
            
            if !isCurrent {
                Button("Revoke") {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onRevoke?()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.clear)
    }
}

func parseUserAgent(_ userAgent: String?) -> (name: String, icon: String) {
    guard let ua = userAgent?.lowercased() else {
        return ("Unknown Device", "laptopcomputer")
    }
    
    if ua.contains("iphone") {
        return ("iPhone", "iphone")
    } else if ua.contains("ipad") {
        return ("iPad", "ipad")
    } else if ua.contains("macintosh") || ua.contains("mac os x") || ua.contains("macos") {
        return ("MacBook", "macbook.and.iphone")
    } else if ua.contains("android") {
        return ("Android Device", "phone")
    } else if ua.contains("windows") {
        return ("Windows PC", "laptopcomputer")
    } else if ua.contains("linux") {
        return ("Linux PC", "laptopcomputer")
    } else {
        return ("Web Session", "globe")
    }
}

struct LinkedAccountRow: View {
    let inst: Institution
    @Bindable var vm: AppViewModel
    let appState: AppState
    @State private var showingUnlinkAlert = false
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Header (Tappable to expand)
            HStack(spacing: 16) {
                if let loginUrl = inst.loginUrl, !loginUrl.isEmpty {
                    FaviconImage(website: loginUrl, size: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "#1A7077"))
                            .frame(width: 36, height: 36)
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(inst.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    
                    if let company = appState.companies.first(where: { $0.id == inst.companyId }) {
                        Text(company.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    } else {
                        Text("Unknown Entity")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(inst.isDisconnected ? Color.red : Color.green)
                            .frame(width: 6, height: 6)
                        Text(inst.isDisconnected ? "Connection issue" : "Connected")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(inst.isDisconnected ? .red : .green)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showingUnlinkAlert = true
                    } label: {
                        Text("Unlink")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }
            
            // Accordion expanded bank accounts
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.vertical, 14)
                    
                    if inst.accounts.isEmpty {
                        Text("No sub-accounts found")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 6)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(inst.accounts) { acc in
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white.opacity(0.05))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: acc.isCard ? "creditcard.fill" : "dollarsign.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(acc.isCard ? Color.orange : Color(hex: "#1A7077"))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(acc.name)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white)
                                        HStack(spacing: 6) {
                                            Text(acc.type)
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(Color.white.opacity(0.4))
                                            if !acc.last4.isEmpty {
                                                Text("•••• \(acc.last4)")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(Color.white.opacity(0.4))
                                            }
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Text(formatCurrency(acc.balance, code: acc.currency))
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Connection Fix Banner
            if inst.isDisconnected {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Action Required")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.red)
                        Text("Fix connection to sync recent bank updates.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    Spacer()
                    
                    PlaidLinkButton(
                        companyId: inst.companyId,
                        institutionId: inst.id,
                        buttonText: "Fix",
                        isReconnect: true,
                        onSuccess: { _, _, _ in
                            var updatedInst = inst
                            updatedInst.isDisconnected = false
                            vm.saveInstitution(updatedInst, appState: appState)
                        }
                    )
                    .frame(width: 80, height: 32)
                }
                .padding(12)
                .background(Color.red.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.15), lineWidth: 1))
                .padding(.top, 14)
            }
        }
        .padding(16)
        .masonryGlass(cornerRadius: 20)
        .alert("Unlink Connection?", isPresented: $showingUnlinkAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Unlink", role: .destructive) {
                vm.deleteInstitution(inst, appState: appState)
            }
        } message: {
            Text("This will permanently remove the Plaid connection for \(inst.name) and erase all linked card and bank account data.")
        }
    }
    
    private func formatCurrency(_ value: Double, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}

struct LinkedAccountsSheet: View {
    @Bindable var vm: AppViewModel
    let appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    private var activeInstitutions: [Institution] {
        appState.institutions.filter { inst in
            appState.companies.contains { $0.id == inst.companyId }
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#171717").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("LINKED ACCOUNTS")
                        .zifrLabel()
                    
                    Spacer()
                    
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 16)
                
                if activeInstitutions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "building.columns")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(Color.white.opacity(0.3))
                        Text("No linked accounts yet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(activeInstitutions) { inst in
                                LinkedAccountRow(inst: inst, vm: vm, appState: appState)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
    }
}

// MARK: - Collaborators & Revocation Sheet

struct EntityCollaborators: Identifiable {
    var id: UUID { company.id }
    let company: Company
    var companyShares: [ResourceInvitation] = []
    var bankShares: [ResourceInvitation] = []
    var subscriptionShares: [ResourceInvitation] = []
    var documentShares: [ResourceInvitation] = []
    
    var isEmpty: Bool {
        companyShares.isEmpty && bankShares.isEmpty && subscriptionShares.isEmpty && documentShares.isEmpty
    }
}

struct CollaboratorsSheet: View {
    @Bindable var vm: AppViewModel
    let appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var collaborators: [ResourceInvitation] = []
    @State private var isLoading = false
    @State private var revokingId: UUID? = nil
    @State private var showingRevokeAlert = false
    @State private var revokingEmail = ""
    
    var groupedCollaborators: [EntityCollaborators] {
        var groups: [EntityCollaborators] = []
        
        for company in appState.companies {
            var companyShares: [ResourceInvitation] = []
            var bankShares: [ResourceInvitation] = []
            var subscriptionShares: [ResourceInvitation] = []
            var documentShares: [ResourceInvitation] = []
            
            for collab in collaborators {
                let type = collab.resourceType.lowercased()
                if type == "company" && collab.resourceId == company.id {
                    companyShares.append(collab)
                } else if type == "institution" || type == "card" || type == "loan" {
                    if type == "institution" {
                        if let inst = appState.institutions.first(where: { $0.id == collab.resourceId }), inst.companyId == company.id {
                            bankShares.append(collab)
                        }
                    } else if type == "card" {
                        if let card = appState.cards.first(where: { $0.id == collab.resourceId }), card.companyId == company.id {
                            bankShares.append(collab)
                        }
                    } else if type == "loan" {
                        if let loan = appState.loans.first(where: { $0.id == collab.resourceId }), loan.companyId == company.id {
                            bankShares.append(collab)
                        }
                    }
                } else if type == "subscription" {
                    if let sub = appState.subscriptions.first(where: { $0.id == collab.resourceId }), sub.companyId == company.id {
                        subscriptionShares.append(collab)
                    }
                } else if type == "document" {
                    if let doc = appState.documents.first(where: { $0.id == collab.resourceId }), doc.companyId == company.id {
                        documentShares.append(collab)
                    }
                }
            }
            
            let group = EntityCollaborators(
                company: company,
                companyShares: companyShares,
                bankShares: bankShares,
                subscriptionShares: subscriptionShares,
                documentShares: documentShares
            )
            
            if !group.isEmpty {
                groups.append(group)
            }
        }
        
        return groups
    }
    
    var uncategorizedShares: [ResourceInvitation] {
        collaborators.filter { collab in
            let type = collab.resourceType.lowercased()
            for company in appState.companies {
                if type == "company" && collab.resourceId == company.id {
                    return false
                } else if type == "institution" || type == "card" || type == "loan" {
                    if type == "institution" {
                        if let inst = appState.institutions.first(where: { $0.id == collab.resourceId }), inst.companyId == company.id {
                            return false
                        }
                    } else if type == "card" {
                        if let card = appState.cards.first(where: { $0.id == collab.resourceId }), card.companyId == company.id {
                            return false
                        }
                    } else if type == "loan" {
                        if let loan = appState.loans.first(where: { $0.id == collab.resourceId }), loan.companyId == company.id {
                            return false
                        }
                    }
                } else if type == "subscription" {
                    if let sub = appState.subscriptions.first(where: { $0.id == collab.resourceId }), sub.companyId == company.id {
                        return false
                    }
                } else if type == "document" {
                    if let doc = appState.documents.first(where: { $0.id == collab.resourceId }), doc.companyId == company.id {
                        return false
                    }
                }
            }
            return true
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#171717").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("COLLABORATORS")
                        .zifrLabel()
                    
                    Spacer()
                    
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 16)
                
                if isLoading {
                    VStack {
                        ProgressView()
                            .tint(Color(hex: "#4f46e5"))
                            .scaleEffect(1.2)
                        Text("Loading collaborators...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if collaborators.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(Color.white.opacity(0.3))
                        Text("No shared collaborators found")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(groupedCollaborators) { group in
                                EntityCollaboratorsCard(group: group, appState: appState) { collab in
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    revokingId = collab.id
                                    revokingEmail = collab.email
                                    showingRevokeAlert = true
                                }
                            }
                            
                            if !uncategorizedShares.isEmpty {
                                UncategorizedCollaboratorsCard(shares: uncategorizedShares) { collab in
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    revokingId = collab.id
                                    revokingEmail = collab.email
                                    showingRevokeAlert = true
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .task {
            await loadCollaborators()
        }
        .alert("Revoke Collaborator Access?", isPresented: $showingRevokeAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Revoke Access", role: .destructive) {
                if let id = revokingId {
                    performRevoke(invitationId: id)
                }
            }
        } message: {
            Text("This will instantly and permanently revoke \(revokingEmail)'s access to the shared resource and remove it from their dashboard.")
        }
    }
    
    private func loadCollaborators() async {
        guard let session = try? await SupabaseService.shared.client.auth.session else { return }
        let currentUserId = session.user.id
        
        await MainActor.run { isLoading = true }
        
        do {
            let list: [ResourceInvitation] = try await SupabaseService.shared.client.from("resource_invitations")
                .select()
                .eq("invited_by", value: currentUserId)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            await MainActor.run {
                self.collaborators = list
                self.isLoading = false
            }
        } catch {
            print("Failed to fetch active shares: \(error)")
            await MainActor.run { self.isLoading = false }
        }
    }
    
    private func performRevoke(invitationId: UUID) {
        Task {
            do {
                try await DataRepository.shared.revokeResourceShare(invitationId: invitationId)
                await DataRepository.shared.logSecurityEvent(title: "Access Revoked", message: "You permanently revoked \(revokingEmail)'s access to a shared resource.")
                await loadCollaborators()
                await DataRepository.shared.fetchAllData(appState: appState)
            } catch {
                print("Failed to revoke share: \(error)")
            }
        }
    }
}

struct EntityCollaboratorsCard: View {
    let group: EntityCollaborators
    let appState: AppState
    let onRevoke: (ResourceInvitation) -> Void
    
    @State private var isExpanded: Bool = false
    @State private var isCompanyExpanded: Bool = true
    @State private var isBanksExpanded: Bool = false
    @State private var isSubscriptionsExpanded: Bool = false
    @State private var isDocumentsExpanded: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    CompanyAvatar(company: group.company, size: 36)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.company.name.isEmpty ? "New Entity" : group.company.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Text(group.company.structure)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                    
                    Spacer()
                    
                    let totalSharesCount = group.companyShares.count + group.bankShares.count + group.subscriptionShares.count + group.documentShares.count
                    Text("\(totalSharesCount) \(totalSharesCount == 1 ? "share" : "shares")")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: "#4f46e5"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#4f46e5").opacity(0.15))
                        .clipShape(Capsule())
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                    
                    // 1. Company Level Access
                    if !group.companyShares.isEmpty {
                        VStack(spacing: 8) {
                            CollaboratorSubAccordionHeader(
                                title: "Company Access",
                                icon: "building.2.crop.circle",
                                count: group.companyShares.count,
                                isExpanded: isCompanyExpanded
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isCompanyExpanded.toggle()
                                }
                            }
                            
                            if isCompanyExpanded {
                                VStack(spacing: 8) {
                                    ForEach(group.companyShares) { collab in
                                        NestedCollaboratorRow(collab: collab, resourceName: group.company.name, onRevoke: { onRevoke(collab) })
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                                .padding(.leading, 8)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // 2. Shared Financials
                    if !group.bankShares.isEmpty {
                        VStack(spacing: 8) {
                            CollaboratorSubAccordionHeader(
                                title: "Banks / Financials",
                                icon: "dollarsign.circle",
                                count: group.bankShares.count,
                                isExpanded: isBanksExpanded
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isBanksExpanded.toggle()
                                }
                            }
                            
                            if isBanksExpanded {
                                VStack(spacing: 8) {
                                    ForEach(group.bankShares) { collab in
                                        let name = appState.institutions.first(where: { $0.id == collab.resourceId })?.name ?? "Bank Access"
                                        NestedCollaboratorRow(collab: collab, resourceName: name, onRevoke: { onRevoke(collab) })
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                                .padding(.leading, 8)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // 3. Shared Subscriptions
                    if !group.subscriptionShares.isEmpty {
                        VStack(spacing: 8) {
                            CollaboratorSubAccordionHeader(
                                title: "Subscriptions",
                                icon: "repeat.circle",
                                count: group.subscriptionShares.count,
                                isExpanded: isSubscriptionsExpanded
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isSubscriptionsExpanded.toggle()
                                }
                            }
                            
                            if isSubscriptionsExpanded {
                                VStack(spacing: 8) {
                                    ForEach(group.subscriptionShares) { collab in
                                        let name = appState.subscriptions.first(where: { $0.id == collab.resourceId })?.name ?? "Subscription Access"
                                        NestedCollaboratorRow(collab: collab, resourceName: name, onRevoke: { onRevoke(collab) })
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                                .padding(.leading, 8)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // 4. Shared Documents
                    if !group.documentShares.isEmpty {
                        VStack(spacing: 8) {
                            CollaboratorSubAccordionHeader(
                                title: "Documents",
                                icon: "doc.text",
                                count: group.documentShares.count,
                                isExpanded: isDocumentsExpanded
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isDocumentsExpanded.toggle()
                                }
                            }
                            
                            if isDocumentsExpanded {
                                VStack(spacing: 8) {
                                    ForEach(group.documentShares) { collab in
                                        let name = appState.documents.first(where: { $0.id == collab.resourceId })?.name ?? "Document Access"
                                        NestedCollaboratorRow(collab: collab, resourceName: name, onRevoke: { onRevoke(collab) })
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                                .padding(.leading, 8)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .background(Color(hex: "#1C1C1E").opacity(0.40))
        .masonryGlass(cornerRadius: 20)
    }
}

struct CollaboratorSubAccordionHeader: View {
    let title: String
    let icon: String
    let count: Int
    let isExpanded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "#4f46e5"))
                
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .tracking(0.5)
                
                Spacer()
                
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

struct NestedCollaboratorRow: View {
    let collab: ResourceInvitation
    let resourceName: String
    let onRevoke: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(collab.email)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    if collab.status.lowercased() == "pending" {
                        Text("PENDING")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                
                HStack(spacing: 6) {
                    Text(resourceName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .lineLimit(1)
                    
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.3))
                    
                    Text(collab.role.uppercased())
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(roleColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(roleColor.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
            
            Button(action: onRevoke) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.85))
                    .frame(width: 32, height: 32)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    private var roleColor: Color {
        switch collab.role {
        case "Admin": return .red
        case "Editor": return .green
        default: return Color(hex: "#3b82f6")
        }
    }
}

struct UncategorizedCollaboratorsCard: View {
    let shares: [ResourceInvitation]
    let onRevoke: (ResourceInvitation) -> Void
    
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 36, height: 36)
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Other Shared Items")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Text("Uncategorized or legacy shares")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                    
                    Spacer()
                    
                    Text("\(shares.count) \(shares.count == 1 ? "share" : "shares")")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                    
                    VStack(spacing: 8) {
                        ForEach(shares) { collab in
                            NestedCollaboratorRow(collab: collab, resourceName: "Resource type: \(collab.resourceType.capitalized)", onRevoke: { onRevoke(collab) })
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 16)
            }
        }
        .background(Color(hex: "#1C1C1E").opacity(0.40))
        .masonryGlass(cornerRadius: 20)
    }
}
