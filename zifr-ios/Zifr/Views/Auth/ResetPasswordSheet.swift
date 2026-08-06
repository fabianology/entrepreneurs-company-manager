import SwiftUI
import Supabase

struct ResetPasswordSheet: View {
    @Bindable var authViewModel: AuthViewModel
    
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil
    @State private var showSuccess = false
    
    var body: some View {
        ZStack {
            // Premium blurred translucent background
            Color.black.opacity(0.4).ignoresSafeArea()
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            
            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button {
                        authViewModel.isRecoveringPassword = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color(hex: "#333333"))
                    }
                    .padding(.top, 16)
                    .padding(.trailing, 16)
                }
                
                Spacer()
                
                if showSuccess {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color(hex: "#30D158"))
                        
                        Text("Password Updated")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Text("Your new password has been securely saved. You can now use it to log in on any device.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(hex: "#A2A2A2"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            authViewModel.isRecoveringPassword = false
                        } label: {
                            Text("Continue to Miloom")
                                .font(.system(size: 15, weight: .heavy))
                                .tracking(1)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                        }
                        .buttonStyle(MiloomPrimaryButtonStyle())
                        .padding(.top, 16)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#171717"))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                        
                        Image(systemName: "lock.shield")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(Color.white)
                    }
                    
                    VStack(spacing: 8) {
                        Text("New Password")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Text("Please securely configure a new password for your Miloom account.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(hex: "#A2A2A2"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    VStack(spacing: 16) {
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("New Password")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(Color.white.opacity(0.4))
                            
                            SecureField("••••••••", text: $newPassword)
                                .padding(.horizontal, 16)
                                .frame(height: 52)
                                .background(Color(hex: "#1C1C1E").opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Confirm Password")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(Color.white.opacity(0.4))
                            
                            SecureField("••••••••", text: $confirmPassword)
                                .padding(.horizontal, 16)
                                .frame(height: 52)
                                .background(Color(hex: "#1C1C1E").opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                        
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            updatePassword()
                        } label: {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Save Password")
                                        .font(.system(size: 15, weight: .heavy))
                                        .tracking(1)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                        }
                        .buttonStyle(MiloomPrimaryButtonStyle())
                        .disabled(newPassword.isEmpty || confirmPassword.isEmpty || isSubmitting)
                        .opacity((newPassword.isEmpty || confirmPassword.isEmpty) ? 0.6 : 1.0)
                        .padding(.top, 8)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .presentationBackground(.thinMaterial)
        .presentationDetents([.fraction(0.55), .large])
    }
    
    private func updatePassword() {
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }
        guard newPassword.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        
        errorMessage = nil
        isSubmitting = true
        
        Task {
            do {
                _ = try await SupabaseService.shared.client.auth.update(user: UserAttributes(password: newPassword))
                await MainActor.run {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showSuccess = true
                    }
                    isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isSubmitting = false
                }
            }
        }
    }
}
