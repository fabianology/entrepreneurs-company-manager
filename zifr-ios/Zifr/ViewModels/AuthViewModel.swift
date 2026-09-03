import SwiftUI
import Supabase
import AuthenticationServices
import CryptoKit
import GoogleSignIn
import LocalAuthentication

@Observable
final class AuthViewModel: NSObject {
    var isAuthenticated = false
    var isRecoveringPassword = false
    var isLoading = false
    var authError: String?
    var isBiometricsAvailable = false
    var hasCachedSession = false
    var session: Session?
    var currentUser: User?
    var activeSessions: [ActiveSession] = []
    
    var currentSessionId: UUID? {
        guard let token = session?.accessToken else { return nil }
        let parts = token.components(separatedBy: ".")
        guard parts.count > 1 else { return nil }
        
        var payload64 = parts[1]
        let remainder = payload64.count % 4
        if remainder > 0 {
            payload64 += String(repeating: "=", count: 4 - remainder)
        }
        
        guard let payloadData = Data(base64Encoded: payload64) else { return nil }
        
        struct JWTPayload: Codable {
            let sid: String?
        }
        
        do {
            let payload = try JSONDecoder().decode(JWTPayload.self, from: payloadData)
            if let sid = payload.sid {
                return UUID(uuidString: sid)
            }
        } catch {
            print("Error decoding JWT payload: \(error)")
        }
        return nil
    }

    var isBiometricEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "isBiometricEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "isBiometricEnabled") }
    }

    private var currentNonce: String?
    private var authorizationController: ASAuthorizationController?

    func checkBiometrics() {
        let context = LAContext()
        var error: NSError?
        isBiometricsAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    override init() {
        super.init()
        observeAuthState()
    }
    
    func observeAuthState() {
        Task {
            for await (event, _) in SupabaseService.shared.client.auth.authStateChanges {
                if event == .passwordRecovery {
                    await MainActor.run {
                        self.isRecoveringPassword = true
                    }
                }
            }
        }
    }

    func checkSession() async {
        checkBiometrics()
        do {
            // `session` performs one SDK-managed refresh only when needed. Calling
            // refreshSession() here races Supabase's automatic refresh and can rotate
            // the same refresh token twice, leaving startup requests unauthorized.
            let session = try await SupabaseService.shared.client.auth.session
            let verifiedUser = try await SupabaseService.shared.client.auth.user(jwt: session.accessToken)
            await MainActor.run {
                self.session = session
                self.currentUser = verifiedUser
                self.hasCachedSession = true
                if self.isBiometricEnabled && self.isBiometricsAvailable {
                    self.isAuthenticated = false
                } else {
                    self.isAuthenticated = true
                }
            }
        } catch {
            await MainActor.run {
                self.session = nil
                self.currentUser = nil
                self.hasCachedSession = false
                self.isAuthenticated = false
            }
        }
    }

    func authenticateWithBiometrics() async {
        checkBiometrics()
        guard isBiometricsAvailable else { return }
        let context = LAContext()
        let reason = "Unlock your business command center."
        
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            if success {
                await MainActor.run {
                    self.isAuthenticated = true
                    self.authError = nil
                }
            }
        } catch {
            await MainActor.run {
                self.authError = error.localizedDescription
            }
        }
    }

    func signOut() async {
        do {
            await PushNotificationService.shared.unregisterCurrentDevice()
            try await SupabaseService.shared.client.auth.signOut()
            await MainActor.run {
                self.session = nil
                self.currentUser = nil
                self.isBiometricEnabled = false
                self.hasCachedSession = false
                self.isAuthenticated = false
                UserDefaults.standard.removeObject(forKey: "onboardingStep")
            }
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    func deleteAccount() async throws {
        await MainActor.run { self.isLoading = true; self.authError = nil }
        do {
            try await SupabaseService.shared.deleteUserAccount()
            await MainActor.run {
                self.session = nil
                self.currentUser = nil
                self.isBiometricEnabled = false
                self.hasCachedSession = false
                self.isAuthenticated = false
                UserDefaults.standard.removeObject(forKey: "onboardingStep")
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.authError = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }
    
    // MARK: - Active Sessions
    func fetchActiveSessions() async {
        do {
            var sessions: [ActiveSession] = try await SupabaseService.shared.client.rpc("get_active_sessions").execute().value
            
            // Enrich with location based on IP
            for i in 0..<sessions.count {
                if let ip = sessions[i].ipAddress, !ip.isEmpty, ip != "127.0.0.1", ip != "::1" {
                    if let url = URL(string: "https://ipinfo.io/\(ip)/json"),
                       let (data, _) = try? await URLSession.shared.data(from: url) {
                        struct IPInfoResponse: Codable {
                            let city: String?
                            let region: String?
                            let country: String?
                        }
                        if let response = try? JSONDecoder().decode(IPInfoResponse.self, from: data) {
                            var components: [String] = []
                            if let city = response.city, !city.isEmpty { components.append(city) }
                            if let region = response.region, !region.isEmpty { components.append(region) }
                            if let country = response.country, !country.isEmpty { components.append(country) }
                            if !components.isEmpty {
                                sessions[i].location = components.joined(separator: ", ")
                            }
                        }
                    }
                }
            }
            
            let finalSessions = sessions
            await MainActor.run {
                self.activeSessions = finalSessions
            }
        } catch {
            print("Failed to fetch active sessions: \(error)")
        }
    }
    
    func revokeSession(id: UUID) async {
        struct RevokeParams: Encodable {
            let session_id: UUID
        }
        do {
            try await SupabaseService.shared.client.rpc("revoke_session", params: RevokeParams(session_id: id)).execute()
            await fetchActiveSessions()
        } catch {
            print("Failed to revoke session: \(error)")
        }
    }
    

    // MARK: - Email / Password Auth
    
    func signInWithEmail(email: String, password: String) async {
        await MainActor.run { self.isLoading = true; self.authError = nil }
        do {
            let response = try await SupabaseService.shared.client.auth.signIn(email: email, password: password)
            await MainActor.run {
                self.session = response
                self.currentUser = response.user
                self.isBiometricEnabled = true
                self.hasCachedSession = true
                self.isAuthenticated = true
                self.isLoading = false
            }
            
            // Record new login security alert
            Task {
                let userId = response.user.id
                var locationStr = "an unknown location"
                
                if let sessions: [ActiveSession] = try? await SupabaseService.shared.client.rpc("get_active_sessions").execute().value,
                   let latestSession = sessions.first, let ip = latestSession.ipAddress, !ip.isEmpty, ip != "127.0.0.1", ip != "::1" {
                    if let url = URL(string: "https://ipinfo.io/\(ip)/json"),
                       let (data, _) = try? await URLSession.shared.data(from: url) {
                        struct IPInfoResponse: Codable {
                            let city: String?
                            let region: String?
                        }
                        if let res = try? JSONDecoder().decode(IPInfoResponse.self, from: data) {
                            var components: [String] = []
                            if let city = res.city, !city.isEmpty { components.append(city) }
                            if let region = res.region, !region.isEmpty { components.append(region) }
                            if !components.isEmpty {
                                locationStr = components.joined(separator: ", ")
                            }
                        }
                    }
                }
                
                let log = ActivityLog(userId: userId, actorEmail: email, actionType: "security_alert", message: "New login detected from \(locationStr). If this wasn't you, go to Admin Settings to revoke the session immediately.")
                try? await DataRepository.shared.insertActivityLog(log)
            }
        } catch {
            let errorMsg = error.localizedDescription
            await MainActor.run {
                if errorMsg.localizedCaseInsensitiveContains("confirm") || errorMsg.localizedCaseInsensitiveContains("verification") {
                    self.authError = "Please confirm your email address. We sent a verification link to your inbox. Tap the link to activate your account, then sign in."
                } else {
                    self.authError = errorMsg
                }
                self.isLoading = false
            }
        }
    }
    
    func signUpWithEmail(email: String, password: String) async {
        await MainActor.run { self.isLoading = true; self.authError = nil }
        do {
            let response = try await SupabaseService.shared.client.auth.signUp(email: email, password: password)
            await MainActor.run {
                if let session = response.session {
                    self.session = session
                    self.currentUser = response.user
                    self.isBiometricEnabled = true
                    self.hasCachedSession = true
                    self.isAuthenticated = true
                } else {
                    // Supabase requires email confirmation, so no session is returned yet.
                    self.authError = "Account created! Please check your email to verify your account before signing in."
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.authError = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func resetPassword(email: String) async -> Bool {
        await MainActor.run { self.isLoading = true; self.authError = nil }
        do {
            let redirectURL = URL(string: "miloom://reset-password")
            try await SupabaseService.shared.client.auth.resetPasswordForEmail(email, redirectTo: redirectURL)
            await MainActor.run {
                self.isLoading = false
            }
            return true
        } catch {
            await MainActor.run {
                self.authError = error.localizedDescription
                self.isLoading = false
            }
            return false
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
                
                let response = try await SupabaseService.shared.client.auth.signInWithIdToken(
                    credentials: .init(provider: .google, idToken: idToken, nonce: nil)
                )
                
                await MainActor.run {
                    self.session = response
                    self.currentUser = response.user
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

    // MARK: - Profile Update
    
    func updateEmail(_ newEmail: String) async throws {
        let attributes = UserAttributes(email: newEmail)
        let response = try await SupabaseService.shared.client.auth.update(user: attributes)
        await MainActor.run {
            self.currentUser = response
        }
    }
    
    func uploadAvatar(imageData: Data) async throws {
        guard let userId = currentUser?.id else { throw URLError(.userAuthenticationRequired) }
        
        let fileName = "\(userId.uuidString)-\(Date().timeIntervalSince1970).jpg"
        let filePath = "\(userId.uuidString)/\(fileName)"
        
        _ = try await SupabaseService.shared.client.storage
            .from("Avatars")
            .upload(
                path: filePath,
                file: imageData,
                options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true)
            )
        
        let publicUrl = try SupabaseService.shared.client.storage
            .from("Avatars")
            .getPublicURL(path: filePath)
        
        let attributes = UserAttributes(data: ["avatar_url": .string(publicUrl.absoluteString)])
        let response = try await SupabaseService.shared.client.auth.update(user: attributes)
        
        await MainActor.run {
            self.currentUser = response
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
                    let response = try await SupabaseService.shared.client.auth.signInWithIdToken(
                        credentials: .init(provider: .apple, idToken: idTokenString, nonce: nonce)
                    )
                    await MainActor.run {
                        self.session = response
                        self.currentUser = response.user
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

// MARK: - Models

struct ActiveSession: Codable, Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    let updatedAt: Date
    let userAgent: String?
    let ipAddress: String?
    var location: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userAgent = "user_agent"
        case ipAddress = "ip_address"
    }
}
