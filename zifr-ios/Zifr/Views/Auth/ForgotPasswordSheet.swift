import SwiftUI

struct ForgotPasswordSheet: View {
    @Bindable var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var email: String
    @State private var showSuccess = false
    
    init(authViewModel: AuthViewModel, initialEmail: String = "") {
        self.authViewModel = authViewModel
        self._email = State(initialValue: initialEmail)
    }
    
    var body: some View {
        ZStack {
            Color.zifrBG.ignoresSafeArea()
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            
            VStack(spacing: 24) {
                // Drag Indicator
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)
                
                Spacer()
                
                // Icon Header
                ZStack {
                    Circle()
                        .fill(Color(hex: "#171717"))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                    
                    Image(systemName: "key.viewfinder")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Color.white)
                }
                
                VStack(spacing: 8) {
                    Text("Reset Password")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Text("Enter your email address and we'll send you a link to reset your password.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: "#A2A2A2"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                if showSuccess {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color(hex: "#30D158"))
                        
                        Text("Reset Link Sent!")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Text("Please check your inbox for instructions to securely configure your new password.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(hex: "#A2A2A2"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 20)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    VStack(spacing: 16) {
                        // Error message
                        if let error = authViewModel.authError {
                            Text(error)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        
                        // Email Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email Address")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(Color.white.opacity(0.4))
                            
                            TextField("name@company.com", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
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
                        
                        // Action Button
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            Task {
                                let success = await authViewModel.resetPassword(email: email)
                                if success {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        showSuccess = true
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                if authViewModel.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Send Reset Link")
                                        .font(.system(size: 15, weight: .heavy))
                                        .tracking(1)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                        }
                        .buttonStyle(MiloomPrimaryButtonStyle())
                        .disabled(email.isEmpty || authViewModel.isLoading)
                        .opacity(email.isEmpty ? 0.6 : 1.0)
                    }
                }
                
                Spacer()
                
                // Back to Login Button
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "#A2A2A2"))
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 32)
        }
    }
}
