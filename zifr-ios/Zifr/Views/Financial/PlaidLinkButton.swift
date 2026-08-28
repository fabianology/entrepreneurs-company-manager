import SwiftUI
import LinkKit

struct PlaidLinkButton: View {
    @SwiftUI.Environment(AppState.self) private var appState
    @SwiftUI.Environment(AuthViewModel.self) private var authVM
    @SwiftUI.Environment(AccessController.self) private var accessController
    let companyId: UUID
    var institutionId: UUID? = nil
    var buttonText: String = "Connect Bank via Plaid"
    var isReconnect: Bool = false
    let onSuccess: (String, [PlaidService.PlaidAccount], String?) -> Void
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var linkHandler: LinkKit.Handler?
    
    @State private var isExchangingToken = false
    @State private var showingPremiumUpgrade = false
    
    var body: some View {
        Group {
            if isExchangingToken {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#C1AA78")))
                        .scaleEffect(1.5)
                        .padding(.bottom, 4)
                    
                    Text("Connecting bank...")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Text("Almost done. Securing your connection.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            } else {
                Button {
                    if isReconnect || accessController.request(
                        .plaidConnection,
                        source: "plaid_link",
                        appState: appState,
                        userId: authVM.currentUser?.id
                    ) {
                        Task { await startLink() }
                    } else {
                        showingPremiumUpgrade = true
                    }
                } label: {
                    HStack(spacing: 12) {
                        if isLoading {
                            ProgressView().tint(isReconnect ? Color(hex: "#C1AA78") : .white)
                        } else {
                            Image(systemName: isReconnect ? "exclamationmark.triangle.fill" : "building.columns.fill")
                                .foregroundStyle(isReconnect ? Color(hex: "#C1AA78") : .white)
                        }
                        Text(isLoading ? (isReconnect ? "Preparing connection..." : "Preparing connection...") : buttonText)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isReconnect ? Color(hex: "#C1AA78") : .white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: isReconnect ? 44 : 56)
                    .background(isReconnect ? Color(hex: "#C1AA78").opacity(0.15) : Color(red: 59/255, green: 130/255, blue: 246/255))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(isLoading)
            }
        }
        .alert("Plaid Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            if let errorMessage { Text(errorMessage) }
        }
        .sheet(isPresented: $showingPremiumUpgrade) {
            PremiumUpgradeView(gate: accessController.pendingGate)
        }
    }
    
    private func startLink() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let linkToken = try await PlaidService.shared.createLinkToken(
                companyId: companyId,
                institutionId: institutionId
            )
            
            var config = LinkTokenConfiguration(token: linkToken) { success in
                // Clear handler when done
                self.linkHandler = nil
                self.isExchangingToken = true
                
                Task {
                    if isReconnect {
                        // Update mode complete, no token exchange needed
                        await MainActor.run { 
                            self.isExchangingToken = false
                            onSuccess(success.metadata.institution.name, [], nil) 
                        }
                    } else {
                        do {
                            let result = try await PlaidService.shared.exchangePublicToken(
                                publicToken: success.publicToken,
                                institutionName: success.metadata.institution.name,
                                institutionId: success.metadata.institution.id,
                                companyId: companyId
                            )
                            await MainActor.run { 
                                self.isExchangingToken = false
                                onSuccess(success.metadata.institution.name, result.accounts, result.item_id) 
                            }
                        } catch {
                            print("Plaid Exchange Error:", error)
                            await MainActor.run { 
                                self.isExchangingToken = false
                                errorMessage = error.localizedDescription 
                            }
                        }
                    }
                }
            }
            
            config.onExit = { exit in
                // Clear handler when done
                self.linkHandler = nil
                
                if let error = exit.error {
                    DispatchQueue.main.async {
                        errorMessage = "Plaid exited: \(error.errorMessage)"
                    }
                }
            }
            
            let result = Plaid.create(config)
            
            switch result {
            case .success(let handler):
                self.linkHandler = handler
                
                if let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = await windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                    
                    // Find top most view controller
                    var topVC = rootVC
                    while let presentedVC = topVC.presentedViewController {
                        topVC = presentedVC
                    }
                    
                    await MainActor.run {
                        handler.open(presentUsing: .viewController(topVC))
                    }
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
