import SwiftUI
import AuthenticationServices

struct LoginView: View {
    var authViewModel: AuthViewModel
    
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
                        
                        Image(systemName: "briefcase.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.white)
                    }
                    
                    VStack(spacing: 8) {
                        Text("MILOOM")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .tracking(8)
                            .foregroundStyle(Color.white)
                        
                        Text("Your entrepreneurial command center.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(hex: "#A2A2A2"))
                    }
                }
                
                Spacer()
                
                // MARK: - Auth Actions
                VStack(spacing: 20) {
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
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            authViewModel.startSignInWithAppleFlow()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "applelogo")
                                    .font(.system(size: 18))
                                Text("Sign in with Apple")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .clipShape(Capsule())
                        }
                        .padding(.horizontal, 32)
                    }
                    
                    Text("By signing in, your data is securely synced to your personal account.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color(hex: "#A2A2A2"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 8)
                }
                .padding(.bottom, 60)
            }
        }
    }
}
