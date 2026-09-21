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
    var isLoadingActiveSessions = false
    var activeSessionsError: String?
    var activeSessionsNotice: String?
    var revokingSessionID: UUID?
    var isSigningOutOtherSessions = false

    var isBiometricEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "isBiometricEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "isBiometricEnabled") }
    }

    private var currentNonce: String?
    private var authorizationController: ASAuthorizationController?
    private var authenticationAttemptID: UUID?

    private var currentSessionID: UUID? {
        session.flatMap { sessionIDFromAccessToken($0.accessToken) }
    }

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

    @MainActor
    func signOut() async {
        await PushNotificationService.shared.unregisterCurrentDevice()
        do {
            // A plain Supabase signOut defaults to .global. The account-level
            // action in Miloom signs out only this device by design.
            try await SupabaseService.shared.client.auth.signOut(scope: .local)
        } catch {
            // The SDK clears its local session before making the network request.
            // Keep Miloom's local state consistent even when that request fails.
            AppDiagnostics.failure("auth", "sign_out_local", error: error)
        }

        session = nil
        currentUser = nil
        isBiometricEnabled = false
        hasCachedSession = false
        isAuthenticated = false
        activeSessions = []
        activeSessionsError = nil
        activeSessionsNotice = nil
        UserDefaults.standard.removeObject(forKey: "onboardingStep")
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
    @MainActor
    func fetchActiveSessions() async {
        isLoadingActiveSessions = true
        activeSessionsError = nil
        activeSessionsNotice = nil
        defer { isLoadingActiveSessions = false }

        do {
            activeSessions = try await requestActiveSessions()
        } catch {
            AppDiagnostics.failure("auth", "fetch_active_sessions", error: error)
            activeSessionsError = "Sessions couldn’t be loaded. Check your connection and try again."
        }
    }

    @MainActor
    @discardableResult
    func revokeSession(id: UUID) async -> Bool {
        guard activeSessions.first(where: { $0.id == id })?.isCurrent != true else {
            activeSessionsError = "This device can’t be revoked. Use Sign Out This Device instead."
            return false
        }

        struct RevokeParams: Encodable {
            let session_id: UUID
        }

        revokingSessionID = id
        activeSessionsError = nil
        activeSessionsNotice = nil
        defer { revokingSessionID = nil }

        do {
            try await SupabaseService.shared.client.rpc(
                "revoke_session",
                params: RevokeParams(session_id: id)
            ).execute()

            // Reflect the successful security action immediately, then reconcile
            // with the server without turning a refresh failure into a false
            // "revoke failed" message.
            activeSessions.removeAll { $0.id == id }
            activeSessionsNotice = "The session was revoked."
            if let refreshed = try? await requestActiveSessions() {
                activeSessions = refreshed
            }
            await DataRepository.shared.logSecurityEvent(
                title: "Session Revoked",
                message: "You revoked access for another signed-in device."
            )
            return true
        } catch {
            AppDiagnostics.failure("auth", "revoke_session", error: error)
            let description = error.localizedDescription
            if description.contains("CURRENT_SESSION_CANNOT_BE_REVOKED") {
                activeSessionsError = "This device can’t be revoked. Use Sign Out This Device instead."
            } else if description.contains("SESSION_NOT_FOUND") {
                activeSessionsError = "That session is no longer active. Refresh the list and try again."
            } else {
                activeSessionsError = "The session couldn’t be revoked. Check your connection and try again."
            }
            return false
        }
    }

    @MainActor
    @discardableResult
    func signOutOtherSessions() async -> Bool {
        guard !isSigningOutOtherSessions else { return false }
        isSigningOutOtherSessions = true
        activeSessionsError = nil
        activeSessionsNotice = nil
        defer { isSigningOutOtherSessions = false }
        do {
            try await SupabaseService.shared.client.auth.signOut(scope: .others)
            activeSessions.removeAll { !$0.isCurrent }
            activeSessionsNotice = "Other devices were signed out."
            if let refreshed = try? await requestActiveSessions() {
                activeSessions = refreshed
            }
            await DataRepository.shared.logSecurityEvent(
                title: "Other Sessions Signed Out",
                message: "You signed out every other device connected to your account."
            )
            return true
        } catch {
            AppDiagnostics.failure("auth", "sign_out_other_sessions", error: error)
            activeSessionsError = "Other devices couldn’t be signed out. Check your connection and try again."
            return false
        }
    }

    private func requestActiveSessions() async throws -> [ActiveSession] {
        var sessions: [ActiveSession] = try await SupabaseService.shared.client
            .rpc("get_active_sessions")
            .execute()
            .value

        // Older deployments do not return `is_current`. During a rolling
        // deployment, recover that marker from the already-authenticated local
        // JWT. The secured RPC remains authoritative once the migration lands.
        if let currentSessionID {
            for index in sessions.indices where sessions[index].id == currentSessionID {
                sessions[index].isCurrent = true
            }
        }

        return sessions
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
                let log = ActivityLog(
                    userId: userId,
                    actorEmail: email,
                    actionType: "security_alert",
                    message: "New login detected. If this wasn’t you, review Active Sessions in Account & Settings."
                )
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

func sessionIDFromAccessToken(_ accessToken: String) -> UUID? {
    let tokenParts = accessToken.split(separator: ".")
    guard tokenParts.count == 3 else { return nil }

    var payload = String(tokenParts[1])
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    let paddingCount = (4 - payload.count % 4) % 4
    payload.append(String(repeating: "=", count: paddingCount))

    struct Claims: Decodable {
        let sessionID: UUID?

        enum CodingKeys: String, CodingKey {
            case sessionID = "session_id"
        }
    }

    guard let payloadData = Data(base64Encoded: payload),
          let claims = try? JSONDecoder().decode(Claims.self, from: payloadData) else {
        return nil
    }
    return claims.sessionID
}

struct ActiveSession: Codable, Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    let updatedAt: Date
    let userAgent: String?
    let ipAddress: String?
    var isCurrent: Bool

    init(
        id: UUID,
        createdAt: Date,
        updatedAt: Date,
        userAgent: String?,
        ipAddress: String?,
        isCurrent: Bool
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.userAgent = userAgent
        self.ipAddress = ipAddress
        self.isCurrent = isCurrent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        userAgent = try container.decodeIfPresent(String.self, forKey: .userAgent)
        ipAddress = try container.decodeIfPresent(String.self, forKey: .ipAddress)
        isCurrent = try container.decodeIfPresent(Bool.self, forKey: .isCurrent) ?? false
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userAgent = "user_agent"
        case ipAddress = "ip_address"
        case isCurrent = "is_current"
    }
}
