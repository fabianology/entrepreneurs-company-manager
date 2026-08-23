import SwiftUI
import AuthenticationServices
import LocalAuthentication

struct LoginView: View {
    @Bindable var authViewModel: AuthViewModel
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isPasswordRevealed = false
    @State private var showForgotPassword = false
    
    var body: some View {
        ZStack {
            // MARK: - Premium Animated Background
            AnimatedHeaderBackground()
                .ignoresSafeArea()
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            
            VStack(spacing: 0) {
                Spacer()
                
                // MARK: - Logo & Brand
                VStack(spacing: 20) {
                    Image("login_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 72)
                    
                    VStack(spacing: 8) {
                        Text("MILOOM")
                            .font(.system(size: 32, weight: .bold))
                            .tracking(8)
                            .foregroundStyle(Color.white)
                        
                        Text("Your entrepreneurial command center.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(hex: "#A2A2A2"))
                    }
                }
                
                Spacer()
                
                // MARK: - Auth Actions
                VStack(spacing: 16) {
                    if let error = authViewModel.authError {
                        Text(error)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    if authViewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                            .padding()
                    } else {
                        // Email & Password Fields
                        VStack(spacing: 12) {
                            // Email Field
                            TextField("Email Address", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .frame(height: 52)
                                .background(Color(hex: "#1C1C1E").opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                            
                            // Password Field with Eye Toggle
                            HStack {
                                Group {
                                    if isPasswordRevealed {
                                        TextField("Password", text: $password)
                                    } else {
                                        SecureField("Password", text: $password)
                                    }
                                }
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(.white)
                                
                                Button {
                                    isPasswordRevealed.toggle()
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Image(systemName: isPasswordRevealed ? "eye.slash.fill" : "eye.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.white.opacity(0.4))
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(Color(hex: "#1C1C1E").opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 32)
                        
                        // Forgot Password Link
                        if !isSignUp {
                            HStack {
                                Spacer()
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    showForgotPassword = true
                                } label: {
                                    Text("Forgot Password?")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color(hex: "#A2A2A2"))
                                }
                                .padding(.trailing, 4)
                            }
                            .padding(.horizontal, 32)
                            .padding(.top, 2)
                        }
                        
                        // Main Actions (Sign In + Biometrics)
                        HStack(spacing: 12) {
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                Task {
                                    if isSignUp {
                                        await authViewModel.signUpWithEmail(email: email, password: password)
                                    } else {
                                        await authViewModel.signInWithEmail(email: email, password: password)
                                    }
                                }
                            } label: {
                                Text(isSignUp ? "Create Account" : "Sign In")
                                    .font(.system(size: 15, weight: .heavy))
                                    .tracking(1)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                            }
                            .buttonStyle(MiloomPrimaryButtonStyle())
                            .disabled(email.isEmpty || password.isEmpty)
                            .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1.0)
                            
                            // Native Biometric Unlock Button
                            if !isSignUp && authViewModel.isBiometricsAvailable && authViewModel.isBiometricEnabled {
                                Button {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    Task {
                                        await authViewModel.authenticateWithBiometrics()
                                    }
                                } label: {
                                    Image(systemName: biometricIconName)
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 52, height: 52)
                                        .background(Color(hex: "#171717"))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                        
                        // Toggle Sign In / Sign Up
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isSignUp.toggle() }
                        } label: {
                            Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .padding(.top, 4)
                        
                        // OR Divider
                        HStack {
                            Rectangle().fill(Color(hex: "#333333")).frame(height: 1)
                            Text("OR")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(hex: "#A2A2A2"))
                            Rectangle().fill(Color(hex: "#333333")).frame(height: 1)
                        }
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        
                        // Social Auth
                        VStack(spacing: 12) {
                            // Apple Sign In
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                authViewModel.startSignInWithAppleFlow()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "applelogo")
                                        .font(.system(size: 18))
                                    Text("Continue with Apple")
                                        .font(.system(size: 15, weight: .bold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color(hex: "#171717"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                            }
                            
                            // Google Sign In
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                authViewModel.startSignInWithGoogleFlow()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "g.circle.fill")
                                        .font(.system(size: 18))
                                    Text("Continue with Google")
                                        .font(.system(size: 15, weight: .bold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color(hex: "#171717"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, 32)
                    }
                    
                    // Legal links
                    VStack(spacing: 4) {
                        Text("By continuing, your data is securely synced to your personal account.")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color(hex: "#A2A2A2"))
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 8) {
                            Link(destination: URL(string: "https://miloom.co/terms")!) {
                                Text("Terms of Service")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            
                            Text("•")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: "#666666"))
                            
                            Link(destination: URL(string: "https://miloom.co/privacy")!) {
                                Text("Privacy Policy")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 16)
                }
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordSheet(authViewModel: authViewModel, initialEmail: email)
        }
        .onAppear {
            authViewModel.checkBiometrics()
            // Auto trigger biometrics if cached session exists and biometrics are enabled
            if authViewModel.hasCachedSession && authViewModel.isBiometricEnabled && authViewModel.isBiometricsAvailable {
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    await authViewModel.authenticateWithBiometrics()
                }
            }
        }
        .onChange(of: authViewModel.hasCachedSession) { _, hasSession in
            if hasSession && authViewModel.isBiometricEnabled && authViewModel.isBiometricsAvailable {
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    await authViewModel.authenticateWithBiometrics()
                }
            }
        }
    }
    
    // MARK: - Biometric Icon Helper
    private var biometricIconName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .none:
            return "lock.shield"
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        @unknown default:
            return "lock.shield"
        }
    }
}
