import SwiftUI
import Supabase

struct AdminSettingsView: View {
    @Bindable var vm: AppViewModel
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss
    
    @State private var userEmail: String = "Loading..."
    @AppStorage("requireBiometrics") private var requireBiometrics: Bool = false
    @AppStorage("autoLockTimeout") private var autoLockTimeout: Int = 0
    @State private var showingExportAlert: Bool = false
    @State private var showingDeleteAlert: Bool = false

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
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundStyle(Color.white.opacity(0.2))
                            .background(Color.white.opacity(0.05))
                            .clipShape(Circle())
                        
                        VStack(spacing: 6) {
                            Text(userEmail)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                            
                            Text("MILOOM PRO")
                                .font(.system(size: 11, weight: .black))
                                .tracking(1)
                                .foregroundStyle(Color(hex: "#3b82f6"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color(hex: "#3b82f6").opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .masonryGlass(cornerRadius: 24)
                    .padding(.horizontal, 20)
                    
                    // Security & Privacy
                    VStack(alignment: .leading, spacing: 16) {
                        Text("SECURITY & PRIVACY")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .padding(.leading, 40)
                            
                        VStack(spacing: 0) {
                            ToggleRow(icon: "faceid", title: "Require Face ID", isOn: $requireBiometrics)
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
                    
                    // Active Sessions
                    VStack(alignment: .leading, spacing: 16) {
                        Text("ACTIVE SESSIONS")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .padding(.leading, 40)
                            
                        VStack(spacing: 0) {
                            SessionRow(icon: "iphone", device: "Current Device", location: "San Francisco, CA", isCurrent: true)
                            Divider().background(Color.white.opacity(0.1)).padding(.leading, 56)
                            SessionRow(icon: "macbook.and.iphone", device: "MacBook Pro", location: "San Francisco, CA", isCurrent: false)
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
                            showingDeleteAlert = true
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
        .alert("Delete Account", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Permanently", role: .destructive) {
                // Trigger account deletion
            }
        } message: {
            Text("This action cannot be undone. All of your data, including shared companies and financial connections, will be permanently erased within 30 days.")
        }
        .task {
            if let session = try? await SupabaseService.shared.client.auth.session {
                await MainActor.run {
                    self.userEmail = session.user.email ?? "User"
                }
            } else {
                await MainActor.run { self.userEmail = "User" }
            }
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
