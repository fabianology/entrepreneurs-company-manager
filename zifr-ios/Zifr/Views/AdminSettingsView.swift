import SwiftUI
import Supabase
import LocalAuthentication

private struct AdminProButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .offset(y: configuration.isPressed ? 3 : 0)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct AdminSettingsView: View {
    @Bindable var vm: AppViewModel
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(AccessController.self) private var accessController
    @Environment(NotificationRouteCoordinator.self) private var notificationRouter
    
    @State private var userEmail: String = "Loading..."
    @AppStorage("autoLockTimeout") private var autoLockTimeout: Int = 0
    @AppStorage("aiConsentStatus") private var aiConsentStatus: String = "unset"
    @State private var showingExportAlert: Bool = false
    @State private var showingDeleteAccountSheet: Bool = false
    @State private var showingEditProfile: Bool = false
    @State private var showingPremiumUpgrade: Bool = false
    @State private var showingMessages: Bool = false
    @State private var showingNotificationPreferences: Bool = false
    @State private var showingLinkedAccounts: Bool = false
    @State private var showingCollaborators: Bool = false
    @State private var showingActiveSessions: Bool = false
    @State private var showingVaultSecurity: Bool = false
    
    private var activeInstitutions: [Institution] {
        let linkedInstitutionIds = Set(
            appState.plaidItems
                .filter(\.representsLinkedInstitution)
                .compactMap(\.institutionId)
        )
        return appState.institutions.filter { inst in
            linkedInstitutionIds.contains(inst.id)
                && appState.companies.contains { $0.id == inst.companyId }
        }
    }

    private var notificationPreferencesSummary: String {
        let weeklyEnabled = appState.userPreferences?.weeklyBriefingEnabled ?? true
        let immediateEnabled = appState.userPreferences?.criticalAlertsEnabled ?? false
        guard !appState.alertRules.isEmpty else { return "Loading alert preferences…" }
        let enabledRuleCount = appState.alertRules.filter(\.enabled).count

        let delivery: String
        switch (weeklyEnabled, immediateEnabled) {
        case (true, true): delivery = "Weekly + immediate"
        case (true, false): delivery = "Weekly push"
        case (false, true): delivery = "Immediate alerts"
        case (false, false): delivery = "In-app only"
        }

        let rules = "\(enabledRuleCount) alert rule\(enabledRuleCount == 1 ? "" : "s")"
        return "\(delivery) · \(rules)"
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.zifrBG.ignoresSafeArea()
            
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
                        ZStack {
                            // 1. Background Photo / Base
                            if let user = authVM.currentUser,
                               case let .string(avatarUrlString) = user.userMetadata["avatar_url"],
                               let avatarUrl = URL(string: avatarUrlString) {
                                AsyncImage(url: avatarUrl) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    default:
                                        Color.zifrTabBarFill.opacity(0.70)
                                    }
                                }
                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                                .clipped()
                                .overlay(
                                    LinearGradient(
                                        colors: [
                                            Color.black.opacity(0.15),
                                            Color.black.opacity(0.70)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            } else {
                                Color.zifrTabBarFill.opacity(0.70)
                                
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 72, height: 72)
                                    .foregroundStyle(Color.white.opacity(0.2))
                                    .offset(y: -20)
                            }
                            
                            // 2. Email and Edit Profile overlaid directly over the picture
                            VStack(spacing: 8) {
                                Spacer()
                                
                                Text(userEmail)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.white)
                                    .shadow(color: Color.black.opacity(0.9), radius: 6, x: 0, y: 2)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                
                                Text("EDIT PROFILE")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(0.5)
                                    .foregroundStyle(Color.white.opacity(0.85))
                                    .shadow(color: Color.black.opacity(0.9), radius: 4, x: 0, y: 1)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(Color.zifrTabBarFill.opacity(0.70))
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: "#918457"),
                                            Color(hex: "#918457").opacity(0.3)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 4)
                    }
                    .padding(.horizontal, 20)

                    // Premium Upgrade
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if !accessController.isBetaAccessActive {
                            showingPremiumUpgrade = true
                        }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.12))
                                    .frame(width: 46, height: 46)
                                Image(systemName: (accessController.hasProSubscription || accessController.isBetaAccessActive) ? "checkmark.seal.fill" : "star.fill")
                                    .foregroundStyle(Color(hex: "#171914"))
                                    .font(.system(size: 19, weight: .bold))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(accessController.isBetaAccessActive ? "MILOOM PRO — BETA ACCESS" : (accessController.hasProSubscription ? "MANAGE MILOOM PRO" : "UPGRADE TO MILOOM PRO"))
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color(hex: "#171914"))
                                Text(accessController.membershipSubtitle)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.black.opacity(0.62))
                            }
                            
                            Spacer()
                            
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.10))
                                    .frame(width: 34, height: 34)
                                Image(systemName: accessController.isBetaAccessActive ? "checkmark" : "chevron.right")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundStyle(Color(hex: "#171914"))
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 78)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#D1BE91"), Color.miloomGold],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.30), lineWidth: 1)
                        }
                        .shadow(color: Color.black.opacity(0.42), radius: 12, x: 0, y: 8)
                        .shadow(color: Color.miloomGold.opacity(0.22), radius: 18, x: 0, y: 5)
                    }
                    .buttonStyle(AdminProButtonStyle())
                    .padding(.horizontal, 20)
                    
                    // Inbox
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
                                Text("INBOX")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("Alerts, briefings, and activity")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            let unreadCount = appState.unreadInboxCount
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
                        .zifrCardBox(cornerRadius: 24)
                    }
                    .padding(.horizontal, 20)

                    // Notification Preferences
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingNotificationPreferences = true
                    } label: {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(Color.zifrGold)
                                .font(.system(size: 20, weight: .semibold))
                                .frame(width: 44, height: 44)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("NOTIFICATIONS & ALERTS")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                Text(notificationPreferencesSummary)
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
                        .zifrCardBox(cornerRadius: 24)
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
                            
                            Divider().background(Color.white.opacity(0.1)).padding(.leading, 56)
                            
                            ToggleRow(
                                icon: "wand.and.stars", 
                                title: "AI Document Processing", 
                                isOn: Binding(
                                    get: { aiConsentStatus == "yes" },
                                    set: { aiConsentStatus = $0 ? "yes" : "no" }
                                )
                            )
                        }
                        .zifrCardBox(cornerRadius: 24)
                        .padding(.horizontal, 20)
                    }

                    // Linked Accounts
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingVaultSecurity = true
                    } label: {
                        HStack {
                            Image(systemName: "key.viewfinder")
                                .foregroundStyle(Color.zifrGold)
                                .font(.system(size: 20, weight: .semibold))
                                .frame(width: 44, height: 44)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("PASSWORD VAULT")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("Encryption, recovery, and trusted devices")
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
                        .zifrCardBox(cornerRadius: 24)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .accessibilityHint("Opens password encryption and trusted device settings")

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
                        .zifrCardBox(cornerRadius: 24)
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
                        .zifrCardBox(cornerRadius: 24)
                    }
                    .padding(.horizontal, 20)
                    
                    // Active Sessions
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingActiveSessions = true
                    } label: {
                        HStack {
                            Image(systemName: "laptopcomputer.and.iphone")
                                .foregroundStyle(Color.zifrGold)
                                .font(.system(size: 20, weight: .semibold))
                                .frame(width: 44, height: 44)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("ACTIVE SESSIONS")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("Manage signed-in devices")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.6))
                            }

                            Spacer()

                            if authVM.isLoadingActiveSessions && authVM.activeSessions.isEmpty {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(Color.zifrGold)
                                    .accessibilityLabel("Loading active sessions")
                            } else if !authVM.activeSessions.isEmpty {
                                Text("\(authVM.activeSessions.count)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Capsule())
                                    .accessibilityLabel("\(authVM.activeSessions.count) active sessions")
                            }

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.4))
                                .padding(.leading, 8)
                        }
                        .padding(16)
                        .zifrCardBox(cornerRadius: 24)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .accessibilityHint("Opens signed-in device management")
                    
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
                                Text("Sign Out This Device")
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
                    .zifrCardBox(cornerRadius: 24)
                    .padding(.horizontal, 20)
                    
                }
                .padding(.bottom, 60)
            }
            .refreshable {
                await authVM.fetchActiveSessions()
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
            NotificationInboxView(vm: vm) { route in
                showingMessages = false
                dismiss()
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(250))
                    notificationRouter.enqueue(route)
                }
            }
        }
        .sheet(isPresented: $showingNotificationPreferences) {
            BriefingPreferencesSheet()
        }
        .sheet(isPresented: $showingLinkedAccounts) {
            LinkedAccountsSheet(vm: vm, appState: appState)
        }
        .sheet(isPresented: $showingCollaborators) {
            CollaboratorsSheet(vm: vm, appState: appState)
        }
        .sheet(isPresented: $showingActiveSessions) {
            ActiveSessionsSheet()
                .environment(authVM)
        }
        .sheet(isPresented: $showingVaultSecurity) {
            VaultSecuritySheet()
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

private enum VaultPresenceError: LocalizedError {
    case unavailable
    case notConfirmed

    var errorDescription: String? {
        switch self {
        case .unavailable: return "Face ID or your device passcode is required to manage the vault."
        case .notConfirmed: return "Your identity wasn’t confirmed. No vault changes were made."
        }
    }
}

@MainActor
@Observable
private final class VaultSecurityController {
    var overview: VaultOverview?
    var isLoading = false
    var activeOperation: String?
    var errorMessage: String?
    var recoveryCode: String?
    var recoveryInput = ""
    var migrationReport: VaultMigrationReport?

    var isInitialized: Bool { overview?.metadata != nil }
    var isUnlocked: Bool { overview?.isUnlocked == true }
    var currentDevice: VaultDeviceRecord? { overview?.currentDevice }
    var pendingDevices: [VaultDeviceRecord] {
        overview?.devices.filter { $0.status == "pending" && $0.id != currentDevice?.id } ?? []
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            overview = try await VaultService.shared.overview()
        } catch {
            AppDiagnostics.failure("vault", "load_settings", error: error)
            errorMessage = "Vault security couldn’t be loaded. Check your connection and try again."
        }
    }

    func setup() async {
        await perform("Setting Up Vault…", reason: "Set up encrypted password syncing for your Miloom account.") {
            let code = try await VaultService.shared.bootstrap()
            self.recoveryCode = code
            self.overview = try await VaultService.shared.overview()
        }
    }

    func requestAccess() async {
        await perform("Requesting Access…", reason: "Register this device with your encrypted password vault.") {
            try await VaultService.shared.registerCurrentDevice()
            self.overview = try await VaultService.shared.overview()
        }
    }

    func recover() async {
        guard !recoveryInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Enter the recovery code you saved when the vault was created."
            return
        }
        await perform("Recovering Vault…", reason: "Use your recovery code to unlock encrypted passwords on this device.") {
            try await VaultService.shared.recoverCurrentDevice(code: self.recoveryInput)
            self.recoveryInput = ""
            self.overview = try await VaultService.shared.overview()
        }
    }

    func approve(_ device: VaultDeviceRecord) async {
        await perform("Approving Device…", reason: "Approve \(device.label) to decrypt your Miloom passwords.") {
            try await VaultService.shared.approve(device: device)
            self.overview = try await VaultService.shared.overview()
        }
    }

    func revoke(_ device: VaultDeviceRecord) async {
        await perform(
            device.status == "pending" ? "Canceling Request…" : "Revoking Device & Rotating Key…",
            reason: device.status == "pending"
                ? "Cancel the vault access request from \(device.label)."
                : "Revoke \(device.label) and rotate encryption for your remaining trusted devices."
        ) {
            if device.status == "pending" {
                try await VaultService.shared.cancelPendingDevice(device)
            } else {
                let result = try await VaultService.shared.revokeAndRotate(device: device)
                self.recoveryCode = result.recoveryCode
                self.migrationReport = result.report
            }
            self.overview = try await VaultService.shared.overview()
        }
    }

    func rotateRecoveryCode() async {
        await perform("Rotating Recovery Code…", reason: "Replace your Miloom vault recovery code.") {
            self.recoveryCode = try await VaultService.shared.rotateRecoveryCode()
            self.overview = try await VaultService.shared.overview()
        }
    }

    func resumeRotation() async {
        await perform("Finishing Key Rotation…", reason: "Finish re-encrypting records after device revocation.") {
            self.migrationReport = try await VaultService.shared.resumeRotation()
            self.overview = try await VaultService.shared.overview()
        }
    }

    @discardableResult
    func migrate() async -> Bool {
        var completed = false
        await perform("Encrypting Existing Passwords…", reason: "Encrypt existing passwords with your synced Miloom vault key.") {
            self.migrationReport = try await VaultService.shared.migrateLegacySecrets()
            completed = true
        }
        return completed
    }

    private func perform(_ operation: String, reason: String, work: () async throws -> Void) async {
        activeOperation = operation
        errorMessage = nil
        defer { activeOperation = nil }
        do {
            try await confirmUserPresence(reason: reason)
            try await work()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch let error as VaultPresenceError {
            errorMessage = error.localizedDescription
        } catch {
            AppDiagnostics.failure("vault", operation, error: error)
            errorMessage = friendlyMessage(for: error)
        }
    }

    private func confirmUserPresence(reason: String) async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            throw VaultPresenceError.unavailable
        }
        guard try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) else {
            throw VaultPresenceError.notConfirmed
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        if case VaultCryptographyError.invalidRecoveryCode = error {
            return "That recovery code isn’t valid. Check the complete code and try again."
        }
        if case VaultCryptographyError.authenticationFailed = error {
            return "The vault couldn’t verify that key. No passwords were changed."
        }
        return "The vault change couldn’t be completed. Check your connection and try again."
    }
}

private struct VaultSecuritySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var controller = VaultSecurityController()
    @State private var showingMigrationConfirmation = false
    @State private var deviceToRevoke: VaultDeviceRecord?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statusCard

                    if let recoveryCode = controller.recoveryCode {
                        recoveryCodeCard(recoveryCode)
                    }

                    if controller.isInitialized && !controller.isUnlocked {
                        deviceAccessCard
                        recoveryCard
                    }

                    if controller.isUnlocked {
                        trustedDevicesCard
                        migrationCard
                        auditCard
                        secretSharingBoundaryCard
                    }

                    ZifrSheetCard(title: "ZERO-KNOWLEDGE SECURITY", icon: "lock.shield.fill") {
                        Text("Miloom stores encrypted vault-key wraps and public device keys. Your recovery code and plaintext vault key stay off the server.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.58))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color(hex: "#1C1C1E"))
            .navigationTitle("Password Vault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#1C1C1E"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Password Vault")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.zifrGold)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .overlay {
                if let operation = controller.activeOperation {
                    ZStack {
                        Color.black.opacity(0.32).ignoresSafeArea()
                        VStack(spacing: 14) {
                            ProgressView().tint(Color.zifrGold)
                            Text(operation)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(operation)
                }
            }
        }
        .task { await controller.load() }
        .refreshable { await controller.load() }
        .alert("Vault Security", isPresented: Binding(
            get: { controller.errorMessage != nil },
            set: { if !$0 { controller.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { controller.errorMessage = nil }
        } message: {
            Text(controller.errorMessage ?? "")
        }
        .confirmationDialog("Encrypt Existing Passwords?", isPresented: $showingMigrationConfirmation, titleVisibility: .visible) {
            Button("Encrypt Existing Passwords") {
                Task {
                    if await controller.migrate() {
                        await DataRepository.shared.fetchAllData(appState: appState)
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Miloom will migrate passwords this device can read. Locked legacy values will be skipped and never overwritten.")
        }
        .alert(item: $deviceToRevoke) { device in
            Alert(
                title: Text(device.status == "pending" ? "Cancel Device Request?" : "Revoke \(device.label)?"),
                message: Text(device.status == "pending"
                    ? "This pending device will need to request access again."
                    : "Miloom will revoke this device, end its linked sign-in session, rotate the account vault key, rewrap it for remaining devices, and re-encrypt protected records. Existing access tokens may remain valid briefly, and this cannot erase passwords the device already viewed."),
                primaryButton: .destructive(Text(device.status == "pending" ? "Cancel Request" : "Revoke & Rotate")) {
                    Task { await controller.revoke(device) }
                },
                secondaryButton: .cancel()
            )
        }
        .presentationDetents([.fraction(0.9), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }

    @ViewBuilder
    private var statusCard: some View {
        ZifrSheetCard(title: "VAULT STATUS", icon: "key.viewfinder") {
            if controller.isLoading && controller.overview == nil {
                HStack(spacing: 12) {
                    ProgressView().tint(Color.zifrGold)
                    Text("Checking vault security…").foregroundStyle(.secondary)
                }
                .frame(minHeight: 52)
            } else if !controller.isInitialized {
                VStack(alignment: .leading, spacing: 14) {
                    Label("Not set up", systemImage: "lock.open")
                        .font(.headline)
                        .foregroundStyle(Color.zifrGold)
                    Text("Create an account vault to sync encrypted passwords across devices without sending the plaintext key to Miloom.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Set Up Synced Vault") { Task { await controller.setup() } }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.zifrGold)
                        .foregroundStyle(Color.black)
                        .controlSize(.large)
                }
            } else {
                HStack(spacing: 14) {
                    Image(systemName: controller.isUnlocked ? "lock.shield.fill" : "lock.trianglebadge.exclamationmark")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(controller.isUnlocked ? Color.green : Color.orange)
                        .frame(width: 44, height: 44)
                        .background(.thinMaterial, in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(controller.isUnlocked ? "Vault Unlocked" : "This Device Needs Access")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(controller.isUnlocked ? "Passwords use your synced account key" : "Approve this device or use recovery")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
    }

    private func recoveryCodeCard(_ code: String) -> some View {
        ZifrSheetCard(title: "SAVE YOUR RECOVERY CODE", icon: "exclamationmark.shield.fill") {
            VStack(alignment: .leading, spacing: 14) {
                Text("This code is shown once. Store it in a trusted password manager before continuing.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(code)
                    .font(.system(.footnote, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.white)
                    .textSelection(.enabled)
                    .privacySensitive()
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Button {
                    UIPasteboard.general.string = code
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Label("Copy Recovery Code", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(Color.zifrGold)
                Button("I Saved This Code") { controller.recoveryCode = nil }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.zifrGold)
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var deviceAccessCard: some View {
        ZifrSheetCard(title: "THIS DEVICE", icon: "iphone") {
            VStack(alignment: .leading, spacing: 12) {
                if let device = controller.currentDevice {
                    Label(device.status == "pending" ? "Approval requested" : device.status.capitalized, systemImage: "clock.badge.exclamationmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.orange)
                    Text("Approve \(device.label) from an already trusted device, or use your recovery code below.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Register this iPhone so a trusted device can approve it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Request Device Access") { Task { await controller.requestAccess() } }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.zifrGold)
                        .foregroundStyle(Color.black)
                        .controlSize(.large)
                }
            }
        }
    }

    private var recoveryCard: some View {
        ZifrSheetCard(title: "RECOVER ACCESS", icon: "lifepreserver.fill") {
            VStack(spacing: 12) {
                TextField("Recovery code", text: $controller.recoveryInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                    .textContentType(.oneTimeCode)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .privacySensitive()
                Button("Recover This Device") { Task { await controller.recover() } }
                    .buttonStyle(.bordered)
                    .tint(Color.zifrGold)
                    .controlSize(.large)
                    .disabled(controller.recoveryInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var trustedDevicesCard: some View {
        ZifrSheetCard(title: "TRUSTED DEVICES", icon: "laptopcomputer.and.iphone") {
            VStack(spacing: 0) {
                ForEach(controller.overview?.devices ?? []) { device in
                    HStack(spacing: 12) {
                        Image(systemName: device.id == controller.currentDevice?.id ? "iphone.gen3" : "iphone")
                            .foregroundStyle(device.status == "approved" ? Color.zifrGold : Color.orange)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(device.label)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(device.id == controller.currentDevice?.id ? "This device" : device.status.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if device.status == "pending" {
                            HStack(spacing: 8) {
                                Button("Approve") { Task { await controller.approve(device) } }
                                    .buttonStyle(.bordered)
                                    .tint(Color.zifrGold)
                                    .controlSize(.small)
                                Button(role: .destructive) { deviceToRevoke = device } label: {
                                    Image(systemName: "xmark")
                                        .frame(width: 30, height: 30)
                                }
                                .buttonStyle(.bordered)
                                .accessibilityLabel("Cancel access request for \(device.label)")
                            }
                        } else if device.status == "approved" && device.id != controller.currentDevice?.id {
                            Button(role: .destructive) { deviceToRevoke = device } label: {
                                Image(systemName: "trash")
                                    .frame(width: 32, height: 32)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Revoke \(device.label)")
                        } else if device.status == "approved" {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Color.green)
                                .accessibilityLabel("Approved")
                        } else {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Revoked")
                        }
                    }
                    .frame(minHeight: 56)
                    if device.id != controller.overview?.devices.last?.id {
                        Divider().background(Color.white.opacity(0.1)).padding(.leading, 42)
                    }
                }
            }
        }
    }

    private var migrationCard: some View {
        ZifrSheetCard(title: "ENCRYPTION MIGRATION", icon: "arrow.triangle.2.circlepath") {
            VStack(alignment: .leading, spacing: 12) {
                if let report = controller.migrationReport {
                    Label("\(report.migratedFields) field\(report.migratedFields == 1 ? "" : "s") encrypted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                    if report.skippedLockedFields > 0 {
                        Text("\(report.skippedLockedFields) locked legacy field\(report.skippedLockedFields == 1 ? " was" : "s were") left unchanged.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if report.failedRecords > 0 {
                        Text("\(report.failedRecords) record\(report.failedRecords == 1 ? "" : "s") couldn’t be updated. You can safely retry.")
                            .font(.caption)
                            .foregroundStyle(Color.orange)
                    }
                } else {
                    Text("Move readable legacy passwords and account numbers to record-bound account encryption. Values locked to another device are preserved.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Button("Encrypt Existing Passwords") { showingMigrationConfirmation = true }
                    .buttonStyle(.bordered)
                    .tint(Color.zifrGold)
                    .controlSize(.large)
                if controller.overview?.metadata?.rotationStatus == "migrating" {
                    Button("Resume Key Rotation") { Task { await controller.resumeRotation() } }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.orange)
                        .controlSize(.large)
                    Text("The previous key remains encrypted under the current key until every old-version vault field has migrated.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Replace Recovery Code") { Task { await controller.rotateRecoveryCode() } }
                    .buttonStyle(.bordered)
                    .tint(Color.zifrGold)
                    .controlSize(.large)
            }
        }
    }

    private var auditCard: some View {
        ZifrSheetCard(title: "VAULT ACTIVITY", icon: "clock.arrow.circlepath") {
            if controller.overview?.auditEvents.isEmpty != false {
                Text("No vault security activity yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(controller.overview?.auditEvents.prefix(8).map { $0 } ?? []) { event in
                        HStack(spacing: 12) {
                            Image(systemName: auditIcon(event.eventType))
                                .foregroundStyle(Color.zifrGold)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(auditTitle(event.eventType))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(event.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .frame(minHeight: 52)
                    }
                }
            }
        }
    }

    private var secretSharingBoundaryCard: some View {
        ZifrSheetCard(title: "COLLABORATOR SECRET ACCESS", icon: "person.2.fill") {
            Label {
                Text("Company and resource sharing never includes passwords or account numbers. A future secret grant must be separate, resource-specific, and explicitly confirmed.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(Color.zifrGold)
            }
        }
    }

    private func auditTitle(_ type: String) -> String {
        switch type {
        case "vault_bootstrapped": return "Vault created"
        case "device_registration_requested": return "Device access requested"
        case "device_approved": return "Device approved"
        case "device_revoked": return "Device revoked"
        case "recovery_device_approved": return "Device recovered"
        case "recovery_rotated": return "Recovery code replaced"
        case "vault_key_rotated": return "Vault key rotated"
        case "vault_rotation_completed": return "Key rotation completed"
        default: return "Vault security updated"
        }
    }

    private func auditIcon(_ type: String) -> String {
        switch type {
        case "device_revoked": return "iphone.slash"
        case "recovery_rotated": return "lifepreserver"
        case "vault_key_rotated", "vault_rotation_completed": return "arrow.triangle.2.circlepath"
        case "device_approved", "recovery_device_approved": return "checkmark.shield.fill"
        default: return "lock.shield.fill"
        }
    }
}

struct ActiveSessionsSheet: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var sessionToRevoke: ActiveSession?
    @State private var showingSignOutOtherSessionsConfirmation = false

    private var otherActiveSessionCount: Int {
        authVM.activeSessions.filter { !$0.isCurrent }.count
    }

    private var sessionCountSubtitle: String {
        let count = authVM.activeSessions.count
        guard count > 0 else { return "signed-in devices" }
        return "\(count) active"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ZifrSheetCard(
                        title: "SIGNED-IN DEVICES",
                        icon: "laptopcomputer.and.iphone",
                        subtitle: sessionCountSubtitle,
                        contentHorizontalPadding: 0,
                        contentTopPadding: 0,
                        contentBottomPadding: 0,
                        contentSpacing: 0,
                        trailing: {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                Task { await authVM.fetchActiveSessions() }
                            } label: {
                                if authVM.isLoadingActiveSessions && !authVM.activeSessions.isEmpty {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(Color.zifrGold)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.zifrGold)
                                        .frame(width: 32, height: 32)
                                        .contentShape(Rectangle())
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(authVM.isLoadingActiveSessions)
                            .accessibilityLabel("Refresh active sessions")
                        }
                    ) {
                        sessionsContent
                    }

                    if otherActiveSessionCount > 0 {
                        ZifrSheetCard(
                            title: "ACTIONS",
                            icon: "slider.horizontal.3"
                        ) {
                            Button(role: .destructive) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                showingSignOutOtherSessionsConfirmation = true
                            } label: {
                                HStack(spacing: 12) {
                                    Group {
                                        if authVM.isSigningOutOtherSessions {
                                            ProgressView()
                                                .controlSize(.small)
                                                .tint(.red)
                                        } else {
                                            Image(systemName: "rectangle.stack.badge.minus")
                                                .font(.system(size: 17, weight: .semibold))
                                        }
                                    }
                                    .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(authVM.isSigningOutOtherSessions ? "Signing Out Other Devices…" : "Sign Out Other Devices")
                                            .font(.system(size: 15, weight: .semibold))
                                        Text("Keep this iPhone signed in")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.5))
                                    }

                                    Spacer()
                                }
                                .foregroundStyle(.red)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 56)
                                .background(Color.red.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.red.opacity(0.16), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(authVM.isSigningOutOtherSessions)
                            .accessibilityHint("Signs out every device except this one")
                        }
                    }

                    ZifrSheetCard(
                        title: "SESSION SECURITY",
                        icon: "lock.shield"
                    ) {
                        Label {
                            Text("Revoked devices can no longer refresh their sign-in. Existing access may continue briefly until the current security token expires.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.58))
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.zifrGold)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .refreshable {
                await authVM.fetchActiveSessions()
            }
            .background(Color(hex: "#1C1C1E"))
            .navigationTitle("Active Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#1C1C1E"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Active Sessions")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: "#C1AA78"))
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .task {
            await authVM.fetchActiveSessions()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, !authVM.activeSessions.isEmpty else { return }
            Task { await authVM.fetchActiveSessions() }
        }
        .alert(item: $sessionToRevoke) { session in
            let device = parseUserAgent(session.userAgent).name
            return Alert(
                title: Text("Revoke \(device)?"),
                message: Text("This device will no longer be able to refresh its sign-in. Its current access may continue briefly until its security token expires."),
                primaryButton: .destructive(Text("Revoke")) {
                    Task { await authVM.revokeSession(id: session.id) }
                },
                secondaryButton: .cancel()
            )
        }
        .alert("Sign Out Other Devices?", isPresented: $showingSignOutOtherSessionsConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out Other Devices", role: .destructive) {
                Task { await authVM.signOutOtherSessions() }
            }
        } message: {
            Text("Your current device will stay signed in. Every other device will need to sign in again after its current security token expires.")
        }
        .presentationDetents([.fraction(0.86), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }

    @ViewBuilder
    private var sessionsContent: some View {
        if authVM.isLoadingActiveSessions && authVM.activeSessions.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                    .tint(Color.zifrGold)
                Text("Loading signed-in devices…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Loading signed-in devices")
        } else if let error = authVM.activeSessionsError,
                  authVM.activeSessions.isEmpty {
            ActiveSessionsUnavailableView(message: error) {
                Task { await authVM.fetchActiveSessions() }
            }
        } else if authVM.activeSessions.isEmpty {
            ContentUnavailableView(
                "No Signed-In Devices",
                systemImage: "lock.shield",
                description: Text("Pull down to check again.")
            )
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        } else {
            ForEach(authVM.activeSessions) { session in
                SessionRow(
                    session: session,
                    isRevoking: authVM.revokingSessionID == session.id,
                    onRevoke: {
                        sessionToRevoke = session
                    }
                )

                if session.id != authVM.activeSessions.last?.id {
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.leading, 56)
                }
            }
        }

        if let notice = authVM.activeSessionsNotice {
            Divider().background(Color.white.opacity(0.1)).padding(.leading, 56)
            SessionFeedbackRow(
                icon: "checkmark.circle.fill",
                message: notice,
                color: .green
            )
        }

        if let error = authVM.activeSessionsError,
           !authVM.activeSessions.isEmpty {
            Divider().background(Color.white.opacity(0.1)).padding(.leading, 56)
            SessionFeedbackRow(
                icon: "exclamationmark.triangle.fill",
                message: error,
                color: .orange
            )
        }
    }
}

private struct ActiveSessionsUnavailableView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Color.zifrGold)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again", action: retry)
                .buttonStyle(.bordered)
                .tint(Color.zifrGold)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

private struct SessionFeedbackRow: View {
    let icon: String
    let message: String
    let color: Color

    var body: some View {
        Label(message, systemImage: icon)
            .font(.footnote)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .accessibilityElement(children: .combine)
    }
}

struct SessionRow: View {
    let session: ActiveSession
    let isRevoking: Bool
    var onRevoke: (() -> Void)? = nil

    private var deviceDetails: (name: String, icon: String) {
        parseUserAgent(session.userAgent)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: deviceDetails.icon)
                .font(.headline.weight(.semibold))
                .foregroundStyle(session.isCurrent ? Color.zifrGold : Color.white.opacity(0.72))
                .frame(width: 38, height: 38)
                .background(.thinMaterial, in: Circle())
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        sessionDeviceName
                        currentDeviceBadge
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        sessionDeviceName
                        currentDeviceBadge
                    }
                }

                Text(sessionLastActiveDescription(session.updatedAt))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let network = maskedSessionAddress(session.ipAddress) {
                    Text(network)
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.white.opacity(0.38))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(sessionAccessibilityLabel(session))
            
            Spacer()
            
            if !session.isCurrent {
                Button(role: .destructive) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onRevoke?()
                } label: {
                    if isRevoking {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.red)
                            .frame(minWidth: 58)
                    } else {
                        Text("Revoke")
                            .font(.subheadline.weight(.semibold))
                            .frame(minWidth: 58)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .frame(minHeight: 44)
                .disabled(isRevoking)
                .accessibilityLabel("Revoke \(deviceDetails.name) session")
                .accessibilityHint("Requires confirmation")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.clear)
    }

    private var sessionDeviceName: some View {
        Text(deviceDetails.name)
            .font(.headline)
            .foregroundStyle(.white)
    }

    @ViewBuilder
    private var currentDeviceBadge: some View {
        if session.isCurrent {
            Label("This Device", systemImage: "checkmark.circle.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color(hex: "#171914"))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.zifrGold)
                .clipShape(Capsule())
        }
    }
}

private func sessionLastActiveDescription(_ date: Date, relativeTo now: Date = Date()) -> String {
    if abs(date.timeIntervalSince(now)) < 60 {
        return "Active now"
    }

    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return "Last active \(formatter.localizedString(for: date, relativeTo: now))"
}

func maskedSessionAddress(_ address: String?) -> String? {
    guard let address, !address.isEmpty, address != "127.0.0.1", address != "::1" else {
        return nil
    }

    let ipv4Parts = address.split(separator: ".")
    if ipv4Parts.count == 4 {
        return "Network \(ipv4Parts[0]).\(ipv4Parts[1]).•••.•••"
    }

    let ipv6Parts = address.split(separator: ":", omittingEmptySubsequences: true)
    if ipv6Parts.count >= 2 {
        return "Network \(ipv6Parts[0]):\(ipv6Parts[1]):…"
    }

    return nil
}

private func sessionAccessibilityLabel(_ session: ActiveSession) -> String {
    let device = parseUserAgent(session.userAgent).name
    let current = session.isCurrent ? ", this device" : ""
    let activity = sessionLastActiveDescription(session.updatedAt)
    let network = maskedSessionAddress(session.ipAddress).map { ", \($0)" } ?? ""
    return "\(device)\(current), \(activity)\(network)"
}

func parseUserAgent(_ userAgent: String?) -> (name: String, icon: String) {
    guard let ua = userAgent?.lowercased() else {
        return ("Unknown Device", "laptopcomputer")
    }
    
    if ua.contains("iphone") {
        return ("iPhone", "iphone")
    } else if ua.contains("ipad") {
        return ("iPad", "ipad")
    } else if ua.contains("macintosh") || ua.contains("mac os x") || ua.contains("macos") || ua.contains("miloom app (mac)") {
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
    let plaidItem: PlaidItemSummary
    @Bindable var vm: AppViewModel
    let appState: AppState
    let onUnlinked: (String) -> Void
    @State private var showingUnlinkAlert = false
    @State private var isExpanded = false
    @State private var isUnlinking = false
    @State private var unlinkError: String?

    private var hasConnectionIssue: Bool {
        inst.isDisconnected || plaidItem.status != "active" || plaidItem.errorCode?.isEmpty == false
    }
    
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
                            .fill(hasConnectionIssue ? Color.red : Color.green)
                            .frame(width: 6, height: 6)
                        Text(hasConnectionIssue ? "Connection issue" : "Connected via Plaid")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(hasConnectionIssue ? .red : .green)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showingUnlinkAlert = true
                    } label: {
                        Group {
                            if isUnlinking {
                                ProgressView()
                                    .tint(.red)
                            } else {
                                Text("Unlink")
                                    .font(.system(size: 12, weight: .bold))
                            }
                        }
                        .foregroundStyle(.red)
                        .frame(minWidth: 50)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isUnlinking)
                    
                    DisclosureStateChevron(isExpanded: isExpanded)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.4))
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
            if hasConnectionIssue {
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
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "#918457"),
                            Color(hex: "#918457").opacity(0.3)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
        }
        .alert("Unlink Connection?", isPresented: $showingUnlinkAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Unlink", role: .destructive) {
                isUnlinking = true
                Task {
                    do {
                        try await vm.deleteInstitutionConfirmed(inst, appState: appState)
                        await MainActor.run {
                            isUnlinking = false
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            onUnlinked(inst.name)
                        }
                    } catch {
                        await MainActor.run {
                            isUnlinking = false
                            unlinkError = error.localizedDescription
                        }
                    }
                }
            }
        } message: {
            Text("This will permanently remove the Plaid connection for \(inst.name) and erase all linked card and bank account data.")
        }
        .alert("Could Not Unlink", isPresented: Binding(
            get: { unlinkError != nil },
            set: { if !$0 { unlinkError = nil } }
        )) {
            Button("OK", role: .cancel) { unlinkError = nil }
        } message: {
            Text(unlinkError ?? "The Plaid connection was not removed. Please try again.")
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
    @State private var unlinkConfirmation: String?
    
    private var activeInstitutions: [Institution] {
        let linkedInstitutionIds = Set(
            appState.plaidItems
                .filter(\.representsLinkedInstitution)
                .compactMap(\.institutionId)
        )
        return appState.institutions.filter { inst in
            linkedInstitutionIds.contains(inst.id)
                && appState.companies.contains { $0.id == inst.companyId }
        }
    }

    private func plaidItem(for institution: Institution) -> PlaidItemSummary? {
        appState.plaidItems
            .filter { $0.representsLinkedInstitution && $0.institutionId == institution.id }
            .sorted {
                if ($0.status == "active") != ($1.status == "active") {
                    return $0.status == "active"
                }
                return ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
            }
            .first
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if let unlinkConfirmation {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("\(unlinkConfirmation) was removed from Plaid and deleted from the server.")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    if activeInstitutions.isEmpty {
                        ContentUnavailableView(
                            "No Linked Accounts",
                            systemImage: "building.columns",
                            description: Text("Plaid-linked accounts will appear here.")
                        )
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                    } else {
                        ForEach(activeInstitutions) { inst in
                            if let item = plaidItem(for: inst) {
                                LinkedAccountRow(
                                    inst: inst,
                                    plaidItem: item,
                                    vm: vm,
                                    appState: appState,
                                    onUnlinked: { unlinkConfirmation = $0 }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color(hex: "#1C1C1E"))
            .navigationTitle("Linked Accounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#1C1C1E"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Linked Accounts")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: "#C1AA78"))
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.fraction(0.86), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }
}

// MARK: - Collaborators & Revocation Sheet

struct EntityCollaborators: Identifiable {
    var id: UUID { company.id }
    let company: Company
    var companyShares: [ManagedResourceAccess] = []
    var bankShares: [ManagedResourceAccess] = []
    var subscriptionShares: [ManagedResourceAccess] = []
    var documentShares: [ManagedResourceAccess] = []
    
    var isEmpty: Bool {
        companyShares.isEmpty && bankShares.isEmpty && subscriptionShares.isEmpty && documentShares.isEmpty
    }
}

struct CollaboratorsSheet: View {
    @Bindable var vm: AppViewModel
    let appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var collaborators: [ManagedResourceAccess] = []
    @State private var blockedCollaborators: [BlockedCollaborator] = []
    @State private var isLoading = false
    @State private var selectedAccess: ManagedResourceAccess?
    @State private var showingRevokeOptions = false
    @State private var selectedBlock: BlockedCollaborator?
    @State private var showingUnblockAlert = false
    @State private var errorMessage: String?
    @State private var resendingInvitationId: UUID?
    
    var groupedCollaborators: [EntityCollaborators] {
        var groups: [EntityCollaborators] = []
        
        for company in appState.companies {
            var companyShares: [ManagedResourceAccess] = []
            var bankShares: [ManagedResourceAccess] = []
            var subscriptionShares: [ManagedResourceAccess] = []
            var documentShares: [ManagedResourceAccess] = []
            
            for collab in collaborators {
                let type = collab.resourceType.lowercased()
                guard collab.companyId == company.id else { continue }

                if type == "company" {
                    companyShares.append(collab)
                } else if ["all_financials", "institution", "card", "loan"].contains(type) {
                    bankShares.append(collab)
                } else if ["all_subscriptions", "subscription"].contains(type) {
                    subscriptionShares.append(collab)
                } else if ["all_documents", "document"].contains(type) {
                    documentShares.append(collab)
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
    
    var uncategorizedShares: [ManagedResourceAccess] {
        collaborators.filter { access in
            guard let companyId = access.companyId else { return true }
            return !appState.companies.contains(where: { $0.id == companyId })
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack {
                        ProgressView()
                            .tint(Color.zifrGold)
                            .scaleEffect(1.2)
                        Text("Loading collaborators...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if collaborators.isEmpty && blockedCollaborators.isEmpty {
                    ContentUnavailableView(
                        "No Collaborators",
                        systemImage: "person.2.slash",
                        description: Text("People you share resources with will appear here.")
                    )
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(groupedCollaborators) { group in
                                EntityCollaboratorsCard(
                                    group: group,
                                    appState: appState,
                                    resendingInvitationId: resendingInvitationId,
                                    onResend: performResend
                                ) { collab in
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    selectedAccess = collab
                                    showingRevokeOptions = true
                                }
                            }
                            
                            if !uncategorizedShares.isEmpty {
                                UncategorizedCollaboratorsCard(
                                    shares: uncategorizedShares,
                                    resendingInvitationId: resendingInvitationId,
                                    onResend: performResend
                                ) { collab in
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    selectedAccess = collab
                                    showingRevokeOptions = true
                                }
                            }

                            if !blockedCollaborators.isEmpty {
                                BlockedCollaboratorsCard(blocks: blockedCollaborators) { block in
                                    selectedBlock = block
                                    showingUnblockAlert = true
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                    .refreshable {
                        await loadCollaborators()
                    }
                }
            }
            .background(Color(hex: "#1C1C1E"))
            .navigationTitle("Collaborators & Sharing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#1C1C1E"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Collaborators & Sharing")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: "#C1AA78"))
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .task {
            await loadCollaborators()
        }
        .confirmationDialog(
            "Manage \(selectedAccess?.email ?? "Collaborator")",
            isPresented: $showingRevokeOptions,
            titleVisibility: .visible
        ) {
            Button(selectedAccess?.accessKind == "invitation" ? "Cancel This Invitation" : "Remove from This Resource", role: .destructive) {
                performRevoke(scope: .resource)
            }
            Button("Remove from This Entity", role: .destructive) {
                performRevoke(scope: .entity)
            }
            .disabled(selectedAccess?.companyId == nil)
            Button("Block All Access for This Person", role: .destructive) {
                performRevoke(scope: .person)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose how broadly Miloom should remove access. Other independent shares remain unless you select a broader scope.")
        }
        .alert("Unblock Collaborator?", isPresented: $showingUnblockAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Unblock") {
                performUnblock()
            }
        } message: {
            Text("\(selectedBlock?.email ?? "This person") can be invited again after being unblocked.")
        }
        .alert("Access Couldn’t Be Updated", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
        .presentationDetents([.fraction(0.86), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }
    
    private func loadCollaborators() async {
        guard (try? await SupabaseService.shared.client.auth.session) != nil else { return }
        
        await MainActor.run { isLoading = true }
        
        do {
            async let access = DataRepository.shared.fetchManagedResourceAccess()
            async let blocks = DataRepository.shared.fetchBlockedCollaborators()
            let (list, blocked) = try await (access, blocks)
            
            await MainActor.run {
                self.collaborators = list
                self.blockedCollaborators = blocked
                self.isLoading = false
            }
        } catch {
            AppDiagnostics.failure("sharing", "fetch_active_shares", error: error)
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Collaborators couldn’t be loaded. Pull down to try again."
            }
        }
    }
    
    private func performRevoke(scope: AccessRevokeScope) {
        guard let access = selectedAccess else { return }
        Task {
            do {
                try await DataRepository.shared.revokeResourceAccess(
                    accessId: access.accessId,
                    accessKind: access.accessKind,
                    scope: scope
                )
                await DataRepository.shared.logSecurityEvent(
                    title: scope == .person ? "Collaborator Blocked" : "Access Revoked",
                    message: "You removed \(access.email)'s access with \(scope.rawValue) scope."
                )
                await loadCollaborators()
                await DataRepository.shared.fetchAllData(appState: appState)
                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    selectedAccess = nil
                }
            } catch {
                AppDiagnostics.failure("sharing", "revoke_share", error: error)
                await MainActor.run {
                    errorMessage = "Access couldn’t be updated. Please try again."
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    private func performUnblock() {
        guard let block = selectedBlock else { return }
        Task {
            do {
                try await DataRepository.shared.unblockCollaborator(blockId: block.id)
                await DataRepository.shared.logSecurityEvent(
                    title: "Collaborator Unblocked",
                    message: "You unblocked \(block.email)."
                )
                await loadCollaborators()
                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    selectedBlock = nil
                }
            } catch {
                AppDiagnostics.failure("sharing", "unblock_collaborator", error: error)
                await MainActor.run {
                    errorMessage = "The collaborator couldn’t be unblocked. Please try again."
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    private func performResend(_ access: ManagedResourceAccess) {
        guard access.accessKind == "invitation", resendingInvitationId == nil else { return }
        resendingInvitationId = access.id
        Task {
            do {
                try await DataRepository.shared.resendInvitation(id: access.id)
                await DataRepository.shared.logSecurityEvent(
                    title: "Invitation Resent",
                    message: "You resent \(access.email)'s invitation."
                )
                await loadCollaborators()
                await MainActor.run {
                    resendingInvitationId = nil
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                AppDiagnostics.failure("sharing", "resend_invitation", error: error)
                await MainActor.run {
                    resendingInvitationId = nil
                    errorMessage = "The invitation couldn’t be resent. Wait a moment and try again."
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }
}

struct EntityCollaboratorsCard: View {
    let group: EntityCollaborators
    let appState: AppState
    let resendingInvitationId: UUID?
    let onResend: (ManagedResourceAccess) -> Void
    let onRevoke: (ManagedResourceAccess) -> Void
    
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
                    
                    DisclosureStateChevron(isExpanded: isExpanded)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.5))
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
                                        NestedCollaboratorRow(collab: collab, resourceName: resourceName(for: collab), isResending: resendingInvitationId == collab.id, onResend: { onResend(collab) }, onRevoke: { onRevoke(collab) })
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
                                        NestedCollaboratorRow(collab: collab, resourceName: resourceName(for: collab), isResending: resendingInvitationId == collab.id, onResend: { onResend(collab) }, onRevoke: { onRevoke(collab) })
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
                                        NestedCollaboratorRow(collab: collab, resourceName: resourceName(for: collab), isResending: resendingInvitationId == collab.id, onResend: { onResend(collab) }, onRevoke: { onRevoke(collab) })
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
                                        NestedCollaboratorRow(collab: collab, resourceName: resourceName(for: collab), isResending: resendingInvitationId == collab.id, onResend: { onResend(collab) }, onRevoke: { onRevoke(collab) })
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
        .modifier(AdminSheetCardSurface(cornerRadius: 20))
    }

    private func resourceName(for access: ManagedResourceAccess) -> String {
        switch access.resourceType.lowercased() {
        case "company": return group.company.name
        case "all_financials": return "All Financials"
        case "all_subscriptions": return "All Subscriptions"
        case "all_documents": return "All Documents"
        case "institution": return appState.institutions.first(where: { $0.id == access.resourceId })?.name ?? "Financial Institution"
        case "card": return appState.cards.first(where: { $0.id == access.resourceId })?.name ?? "Financial Card"
        case "loan": return appState.loans.first(where: { $0.id == access.resourceId })?.name ?? "Loan"
        case "subscription": return appState.subscriptions.first(where: { $0.id == access.resourceId })?.name ?? "Subscription"
        case "document": return appState.documents.first(where: { $0.id == access.resourceId })?.name ?? "Document"
        default: return "Shared Resource"
        }
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
                
                DisclosureStateChevron(isExpanded: isExpanded)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.4))
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
    let collab: ManagedResourceAccess
    let resourceName: String
    let isResending: Bool
    let onResend: () -> Void
    let onRevoke: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(collab.email)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Text(collab.status.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(statusColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusColor.opacity(0.15))
                            .clipShape(Capsule())
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

            if collab.accessKind == "invitation" {
                Button(action: onResend) {
                    ZStack {
                        Circle()
                            .fill(Color.zifrGold.opacity(0.1))
                            .frame(width: 32, height: 32)
                        if isResending {
                            ProgressView()
                                .controlSize(.small)
                                .tint(Color.zifrGold)
                        } else {
                            Image(systemName: "envelope.arrow.triangle.branch")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.zifrGold)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isResending)
                .accessibilityLabel("Resend invitation to \(collab.email)")
            }

            Button(action: onRevoke) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.red.opacity(0.85))
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Manage access for \(collab.email)")
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

    private var statusColor: Color {
        switch collab.status.lowercased() {
        case "active", "accepted": return .green
        case "pending": return .orange
        default: return .red
        }
    }
}

struct UncategorizedCollaboratorsCard: View {
    let shares: [ManagedResourceAccess]
    let resendingInvitationId: UUID?
    let onResend: (ManagedResourceAccess) -> Void
    let onRevoke: (ManagedResourceAccess) -> Void
    
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
                    
                    DisclosureStateChevron(isExpanded: isExpanded)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.5))
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
                            NestedCollaboratorRow(
                                collab: collab,
                                resourceName: "Resource type: \(collab.resourceType.capitalized)",
                                isResending: resendingInvitationId == collab.id,
                                onResend: { onResend(collab) },
                                onRevoke: { onRevoke(collab) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 16)
            }
        }
        .modifier(AdminSheetCardSurface(cornerRadius: 20))
    }
}

struct BlockedCollaboratorsCard: View {
    let blocks: [BlockedCollaborator]
    let onUnblock: (BlockedCollaborator) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.red)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Blocked People")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text("They cannot receive new access")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.45))
                }

                Spacer()

                Text("\(blocks.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.red.opacity(0.12), in: Capsule())
            }
            .padding(16)

            Divider()
                .overlay(Color.white.opacity(0.08))
                .padding(.horizontal, 16)

            VStack(spacing: 8) {
                ForEach(blocks) { block in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(block.email)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("BLOCKED")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.12), in: Capsule())
                        }

                        Spacer()

                        Button("Unblock") {
                            onUnblock(block)
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .buttonStyle(.bordered)
                        .tint(Color(hex: "#C1AA78"))
                        .frame(minHeight: 44)
                        .accessibilityHint("Allows this person to be invited again")
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    }
                }
            }
            .padding(16)
        }
        .modifier(AdminSheetCardSurface(cornerRadius: 20))
    }
}

private struct AdminSheetCardSurface: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background(shape.fill(Color.black.opacity(0.70)))
            .background(.regularMaterial, in: shape)
            .clipShape(shape)
            .overlay {
                shape.stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "#918457"),
                            Color(hex: "#918457").opacity(0.3)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
            }
    }
}
