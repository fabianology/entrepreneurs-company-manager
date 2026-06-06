import SwiftUI

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

@main
struct ZifrApp: App {
    @State private var authViewModel = AuthViewModel()
    @State private var appState = AppState()
    @State private var onboardingState = OnboardingStateManager()
    @Environment(\.scenePhase) var scenePhase
    @AppStorage("autoLockTimeout") private var autoLockTimeout: Int = 0
    @State private var backgroundDate: Date? = nil

    init() {
        // MARK: - Global UI Styling
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(hex: "#223E5A")
        UISegmentedControl.appearance().backgroundColor = UIColor(hex: "#111111")
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white.withAlphaComponent(0.5)], for: .normal)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    RootView()
                } else {
                    LoginView(authViewModel: authViewModel)
                }
            }
            .preferredColorScheme(.dark)
            .environment(authViewModel)
            .environment(appState)
            .environment(onboardingState)
            .task {
                await authViewModel.checkSession()
                if authViewModel.isAuthenticated {
                    await DataRepository.shared.fetchAllData(appState: appState)
                }
            }
            .onChange(of: authViewModel.isAuthenticated) { _, isAuth in
                if isAuth {
                    Task { await DataRepository.shared.fetchAllData(appState: appState) }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    backgroundDate = Date()
                } else if newPhase == .active {
                    if let bgDate = backgroundDate {
                        let timeElapsed = Date().timeIntervalSince(bgDate)
                        let timeoutSeconds = Double(autoLockTimeout * 60)
                        
                        if authViewModel.isBiometricEnabled && authViewModel.isBiometricsAvailable {
                            if autoLockTimeout == 0 || timeElapsed >= timeoutSeconds {
                                authViewModel.isAuthenticated = false
                            }
                        }
                    }
                    backgroundDate = nil
                }
            }
            .onOpenURL { url in
                Task {
                    do {
                        try await SupabaseService.shared.client.handle(url)
                        if url.absoluteString.contains("reset-password") {
                            await MainActor.run {
                                authViewModel.isRecoveringPassword = true
                            }
                        }
                    } catch {
                        print("Failed to handle deep link: \(error)")
                    }
                }
            }
            .sheet(isPresented: $authViewModel.isRecoveringPassword) {
                ResetPasswordSheet(authViewModel: authViewModel)
            }
            .alert("Error", isPresented: Binding(
                get: { appState.error != nil },
                set: { if !$0 { appState.error = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(appState.error ?? "An unknown error occurred.")
            }
        }
    }
}
