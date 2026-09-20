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
            AppDiagnostics.failure("auth", "decode_session_claims", error: error)
        }
        return nil
    }

    var isBiometricEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "isBiometricEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "isBiometricEnabled") }
    }

    private var currentNonce: String?
    private var authorizationController: ASAuthorizationController?
    private var authenticationAttemptID: UUID?

    @MainActor
    private func beginAuthenticationAttempt() -> UUID {
        let attemptID = UUID()
        authenticationAttemptID = attemptID
        isLoading = true
        authError = nil
        AppDiagnostics.event("auth", "interactive_sign_in", status: "started")

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled,
                  let self,
                  self.authenticationAttemptID == attemptID else { return }
            self.authenticationAttemptID = nil
            self.isLoading = false
            self.authError = "Sign in took too long. Check your connection and try again."
            AppDiagnostics.failure("auth", "interactive_sign_in_timeout")
        }
        return attemptID
    }

    @MainActor
    @discardableResult
    private func finishAuthenticationAttempt(_ attemptID: UUID) -> Bool {
        guard authenticationAttemptID == attemptID else { return false }
        authenticationAttemptID = nil
        isLoading = false
        return true
    }

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

        // Use the stored session directly when it is still valid. Besides making
        // launch instant, this avoids a redundant `/user` round trip and leaves
        // the authentication client free for an interactive sign-in.
        guard let cachedSession = SupabaseService.shared.client.auth.currentSession else {
            await MainActor.run {
                self.session = nil
                self.currentUser = nil
                self.hasCachedSession = false
                self.isAuthenticated = false
            }
            return
        }

        if !cachedSession.isExpired {
            await MainActor.run {
                self.applyRestoredSession(cachedSession)
            }
            AppDiagnostics.event("auth", "restore_cached_session", status: "success")
            return
        }

        AppDiagnostics.event("auth", "refresh_cached_session", status: "started")
        do {
            // `session` re-reads the latest stored value and coalesces with the
            // SDK's automatic refresh, preventing two uses of a rotating token.
            let refreshedSession = try await SupabaseService.shared.client.auth.session
            await MainActor.run {
                // Never let a launch-time restore overwrite a sign-in that the
                // user started while the refresh was in flight.
                guard self.authenticationAttemptID == nil, !self.isAuthenticated else { return }
                self.applyRestoredSession(refreshedSession)
            }
            AppDiagnostics.event("auth", "refresh_cached_session", status: "success")
        } catch {
            AppDiagnostics.failure("auth", "refresh_cached_session", error: error)
            await MainActor.run {
                guard self.authenticationAttemptID == nil, !self.isAuthenticated else { return }
                self.session = nil
                self.currentUser = nil
                self.hasCachedSession = false
                self.isAuthenticated = false
            }
        }
    }

    @MainActor
    private func applyRestoredSession(_ session: Session) {
        self.session = session
        self.currentUser = session.user
        self.hasCachedSession = true
        self.isAuthenticated = !(self.isBiometricEnabled && self.isBiometricsAvailable)
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
            AppDiagnostics.failure("auth", "sign_out", error: error)
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
            AppDiagnostics.failure("auth", "fetch_active_sessions", error: error)
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
            AppDiagnostics.failure("auth", "revoke_session", error: error)
        }
    }
    

    // MARK: - Email / Password Auth
    
    func signInWithEmail(email: String, password: String) async {
        let attemptID = await beginAuthenticationAttempt()
        do {
            let response = try await SupabaseService.shared.client.auth.signIn(email: email, password: password)
            await MainActor.run {
                guard self.finishAuthenticationAttempt(attemptID) else { return }
                self.session = response
                self.currentUser = response.user
                self.isBiometricEnabled = true
                self.hasCachedSession = true
                self.isAuthenticated = true
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
                guard self.finishAuthenticationAttempt(attemptID) else { return }
                if errorMsg.localizedCaseInsensitiveContains("confirm") || errorMsg.localizedCaseInsensitiveContains("verification") {
                    self.authError = "Please confirm your email address. We sent a verification link to your inbox. Tap the link to activate your account, then sign in."
                } else {
                    self.authError = errorMsg
                }
            }
        }
    }
    
    func signUpWithEmail(email: String, password: String) async {
        let attemptID = await beginAuthenticationAttempt()
        do {
            let response = try await SupabaseService.shared.client.auth.signUp(email: email, password: password)
            await MainActor.run {
                guard self.finishAuthenticationAttempt(attemptID) else { return }
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
            }
        } catch {
            await MainActor.run {
                guard self.finishAuthenticationAttempt(attemptID) else { return }
                self.authError = error.localizedDescription
            }
        }
    }

    func resetPassword(email: String) async -> Bool {
        let attemptID = await beginAuthenticationAttempt()
        do {
            let redirectURL = URL(string: "miloom://reset-password")
            try await SupabaseService.shared.client.auth.resetPasswordForEmail(email, redirectTo: redirectURL)
            return await MainActor.run { self.finishAuthenticationAttempt(attemptID) }
        } catch {
            return await MainActor.run {
                guard self.finishAuthenticationAttempt(attemptID) else { return false }
                self.authError = error.localizedDescription
                return false
            }
        }
    }
    
    // MARK: - Sign in with Google
    
    func startSignInWithGoogleFlow() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            AppDiagnostics.failure("auth", "google_presentation_context")
            return
        }
        
        let clientID = "473094376315-k0rd5eq6d6l4dvcddslmpuo1h9dkdr5f.apps.googleusercontent.com"
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        
        Task {
            let attemptID = await self.beginAuthenticationAttempt()
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
                
                guard let idToken = result.user.idToken?.tokenString else {
                    throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No ID token found"])
                }
                
                let response = try await SupabaseService.shared.client.auth.signInWithIdToken(
                    credentials: .init(provider: .google, idToken: idToken, nonce: nil)
                )
                
                await MainActor.run {
                    guard self.finishAuthenticationAttempt(attemptID) else { return }
                    self.session = response
                    self.currentUser = response.user
                    self.isAuthenticated = true
                }
            } catch {
                await MainActor.run {
                    guard self.finishAuthenticationAttempt(attemptID) else { return }
                    self.authError = error.localizedDescription
                }
                AppDiagnostics.failure("auth", "google_sign_in", error: error)
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
        guard let nonce = randomNonceString() else {
            authError = "Could not start Apple sign-in. Please try again."
            AppDiagnostics.failure("auth", "apple_nonce_generation")
            return
        }
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
    
    private func randomNonceString(length: Int = 32) -> String? {
        guard length > 0 else { return nil }
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            AppDiagnostics.failure("auth", "apple_nonce_random_bytes", error: NSError(domain: NSOSStatusErrorDomain, code: Int(errorCode)))
            return nil
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
                authError = "Apple sign-in could not be verified. Please try again."
                AppDiagnostics.failure("auth", "apple_nonce_missing")
                return
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                AppDiagnostics.failure("auth", "apple_identity_token_missing")
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                AppDiagnostics.failure("auth", "apple_identity_token_decode")
                return
            }
            
            Task {
                let attemptID = self.beginAuthenticationAttempt()
                do {
                    let response = try await SupabaseService.shared.client.auth.signInWithIdToken(
                        credentials: .init(provider: .apple, idToken: idTokenString, nonce: nonce)
                    )
                    await MainActor.run {
                        guard self.finishAuthenticationAttempt(attemptID) else { return }
                        self.session = response
                        self.currentUser = response.user
                        self.isAuthenticated = true
                    }
                } catch {
                    await MainActor.run {
                        guard self.finishAuthenticationAttempt(attemptID) else { return }
                        self.authError = error.localizedDescription
                    }
                    AppDiagnostics.failure("auth", "apple_supabase_sign_in", error: error)
                }
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        AppDiagnostics.failure("auth", "apple_authorization", error: error)
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
