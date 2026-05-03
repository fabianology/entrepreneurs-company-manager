import SwiftUI
import Supabase

struct AdminSettingsView: View {
    @Bindable var vm: AppViewModel
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss
    
    @State private var userEmail: String = "Loading..."

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
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
                            .font(.system(size: 13, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(Color.white.opacity(0.6))
                        
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
                            
                            Text("CIFR PRO")
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
                    .background(Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .padding(.horizontal, 20)
                    
                    // General Settings (Placeholders)
                    VStack(spacing: 0) {
                        SettingsRow(icon: "bell.badge.fill", title: "Notifications", value: "Enabled")
                        Divider().background(Color.white.opacity(0.1)).padding(.leading, 56)
                        SettingsRow(icon: "moon.fill", title: "Appearance", value: "Dark")
                        Divider().background(Color.white.opacity(0.1)).padding(.leading, 56)
                        SettingsRow(icon: "lock.shield.fill", title: "Security", value: "Face ID")
                    }
                    .background(Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .padding(.horizontal, 20)
                    
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
                            // Delete account action
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
                    .background(Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08), lineWidth: 1))
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
