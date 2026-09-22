import SwiftUI
import Supabase

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
            AppDiagnostics.failure("sharing", "fetch_active_shares", error: error)
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
                AppDiagnostics.failure("sharing", "revoke_share", error: error)
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
        .zifrCardBox(cornerRadius: 20)
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
                            NestedCollaboratorRow(collab: collab, resourceName: "Resource type: \(collab.resourceType.capitalized)", onRevoke: { onRevoke(collab) })
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 16)
            }
        }
        .zifrCardBox(cornerRadius: 20)
    }
}
