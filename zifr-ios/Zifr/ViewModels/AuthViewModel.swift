import SwiftUI
import Supabase
import AuthenticationServices
import CryptoKit
import GoogleSignIn

@Observable
final class AuthViewModel: NSObject {
    var isAuthenticated = false
    var isLoading = false
    var authError: String?

    private var currentNonce: String?
    private var authorizationController: ASAuthorizationController?

    func checkSession() async {
        do {
            let session = try await SupabaseService.shared.client.auth.session
            await MainActor.run {
                self.isAuthenticated = true
            }
        } catch {
            await MainActor.run {
                self.isAuthenticated = false
            }
        }
    }

    func signOut() async {
        do {
            try await SupabaseService.shared.client.auth.signOut()
            await MainActor.run {
                self.isAuthenticated = false
            }
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    

    // MARK: - Email / Password Auth
    
    func signInWithEmail(email: String, password: String) async {
        await MainActor.run { self.isLoading = true; self.authError = nil }
        do {
            _ = try await SupabaseService.shared.client.auth.signIn(email: email, password: password)
            await MainActor.run {
                self.isAuthenticated = true
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.authError = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func signUpWithEmail(email: String, password: String) async {
        await MainActor.run { self.isLoading = true; self.authError = nil }
        do {
            _ = try await SupabaseService.shared.client.auth.signUp(email: email, password: password)
            await MainActor.run {
                self.isAuthenticated = true
                self.isLoading = false
                // Depending on Supabase settings, email confirmation might be required
            }
        } catch {
            await MainActor.run {
                self.authError = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Sign in with Google
    
    func startSignInWithGoogleFlow() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("Could not find root view controller")
            return
        }
        
        let clientID = "473094376315-k0rd5eq6d6l4dvcddslmpuo1h9dkdr5f.apps.googleusercontent.com"
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        
        Task {
            await MainActor.run { self.isLoading = true; self.authError = nil }
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
                
                guard let idToken = result.user.idToken?.tokenString else {
                    throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No ID token found"])
                }
                
                _ = try await SupabaseService.shared.client.auth.signInWithIdToken(
                    credentials: .init(provider: .google, idToken: idToken, nonce: nil)
                )
                
                await MainActor.run {
                    self.isAuthenticated = true
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.authError = error.localizedDescription
                    self.isLoading = false
                }
                print("Google Sign In error: \(error)")
            }
        }
    }

    // MARK: - Sign in with Apple
    
    func startSignInWithAppleFlow() {
        let nonce = randomNonceString()
        currentNonce = nonce
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        self.authorizationController = ASAuthorizationController(authorizationRequests: [request])
        self.authorizationController?.delegate = self
        self.authorizationController?.presentationContextProvider = self
        self.authorizationController?.performRequests()
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { charset[Int($0) % charset.count] }
        return String(nonce)
    }

    @available(iOS 13, *)
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }
}

extension AuthViewModel: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                print("Unable to fetch identity token")
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                return
            }
            
            Task {
                await MainActor.run { self.isLoading = true }
                do {
                    _ = try await SupabaseService.shared.client.auth.signInWithIdToken(
                        credentials: .init(provider: .apple, idToken: idTokenString, nonce: nonce)
                    )
                    await MainActor.run {
                        self.isAuthenticated = true
                        self.isLoading = false
                    }
                } catch {
                    await MainActor.run {
                        self.authError = error.localizedDescription
                        self.isLoading = false
                    }
                    print("Supabase auth error: \(error)")
                }
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Sign in with Apple errored: \(error.localizedDescription)")
    }
}

extension AuthViewModel: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
