import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authVM
    
    @State private var confirmationText: String = ""
    @State private var isDeleting: Bool = false
    @State private var deleteError: String? = nil
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.zifrBG.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("DELETE ACCOUNT")
                        .zifrLabel()
                    
                    Spacer()
                    
                    Color.clear.frame(width: 44, height: 44) // Balance
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        
                        // Warning Icon & Header
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.1))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.red)
                            }
                            
                            Text("This action is permanent")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                        
                        // Details
                        VStack(alignment: .leading, spacing: 20) {
                            WarningRow(
                                icon: "building.columns.fill",
                                title: "Bank Connections Severed",
                                description: "All active Plaid connections will be permanently revoked and your sync data erased."
                            )
                            
                            WarningRow(
                                icon: "doc.text.fill",
                                title: "Data Erased",
                                description: "All your companies, transactions, subscriptions, and uploaded files will be deleted."
                            )
                            
                            WarningRow(
                                icon: "person.crop.circle.badge.xmark",
                                title: "Profile Deleted",
                                description: "Your login credentials and personal profile will be completely removed from our systems."
                            )
                        }
                        .padding(20)
                        .background(Color.red.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.2), lineWidth: 1))
                        
                        // Confirmation Input
                        VStack(alignment: .leading, spacing: 12) {
                            Text("To confirm, type \"DELETE\" below:")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.8))
                            
                            TextField("DELETE", text: $confirmationText)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(confirmationText == "DELETE" ? Color.red : Color.white.opacity(0.1), lineWidth: 1)
                                )
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.characters)
                        }
                        
                        if let error = deleteError {
                            Text(error)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.red)
                                .padding(.top, 8)
                        }
                        
                        // Action Button
                        Button {
                            guard confirmationText == "DELETE" else { return }
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            performDeletion()
                        } label: {
                            HStack {
                                if isDeleting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Permanently Delete Account")
                                        .font(.system(size: 16, weight: .bold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(confirmationText == "DELETE" ? Color.red : Color.white.opacity(0.1))
                            .foregroundStyle(confirmationText == "DELETE" ? .white : Color.white.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(confirmationText != "DELETE" || isDeleting)
                        .padding(.top, 16)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .interactiveDismissDisabled(isDeleting)
    }
    
    private func performDeletion() {
        isDeleting = true
        deleteError = nil
        
        Task {
            do {
                try await authVM.deleteAccount()
                // The auth state change will automatically route them to the login screen
                // because AppState handles `isAuthenticated`. We don't need to manually dismiss.
            } catch {
                await MainActor.run {
                    self.deleteError = error.localizedDescription
                    self.isDeleting = false
                }
            }
        }
    }
}

struct WarningRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.red.opacity(0.8))
                .frame(width: 24, alignment: .center)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                
                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
