import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Bindable var authViewModel: AuthViewModel
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    
    var body: some View {
        ZStack {
            Color(hex: "#000000").ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // MARK: - Logo & Brand
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#171717"))
                            .frame(width: 100, height: 100)
                            .shadow(color: Color.white.opacity(0.05), radius: 20, x: 0, y: 0)
                        
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                    }
                    
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
                            TextField("Email", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding()
                                .background(Color(hex: "#1A1A1A"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                            
                            SecureField("Password", text: $password)
                                .padding()
                                .background(Color(hex: "#1A1A1A"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 32)
                        
                        // Main Action Button
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
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                        
                        // Toggle Sign In / Sign Up
                        Button {
                            withAnimation { isSignUp.toggle() }
                        } label: {
                            Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(hex: "#A2A2A2"))
                        }
                        .padding(.top, 4)
                        
                        // OR Divider
                        HStack {
                            Rectangle().fill(Color(hex: "#333333")).frame(height: 1)
                            Text("OR")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(hex: "#666666"))
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
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color(hex: "#1A1A1A"))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(Color(hex: "#333333"), lineWidth: 1)
                                )
                            }
                            
                            // Google Sign In
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                authViewModel.startSignInWithGoogleFlow()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "g.circle.fill") // Fallback generic Google-like icon
                                        .font(.system(size: 18))
                                    Text("Continue with Google")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color(hex: "#1A1A1A"))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(Color(hex: "#333333"), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, 32)
                    }
                    
                    Text("By continuing, your data is securely synced to your personal account.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color(hex: "#666666"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 16)
                }
                .padding(.bottom, 40)
            }
        }
    }
}
