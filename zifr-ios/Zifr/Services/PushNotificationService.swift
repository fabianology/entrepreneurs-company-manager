import Foundation
import Observation
import UIKit
import UserNotifications

@MainActor
@Observable
final class NotificationRouteCoordinator {
    static let shared = NotificationRouteCoordinator()

    private(set) var pendingRoute: NotificationRoute?

    private init() {}

    func enqueue(_ route: NotificationRoute) {
        pendingRoute = route
    }

    func takePendingRoute() -> NotificationRoute? {
        defer { pendingRoute = nil }
        return pendingRoute
    }

    func clear() {
        pendingRoute = nil
    }

}

enum PrivateBriefingNotification {
    static let testBody = "Your private notifications are working."

    static func body(itemCount: Int) -> String {
        "Miloom: \(itemCount) \(itemCount == 1 ? "item needs" : "items need") your attention this week."
    }
}

enum PushRegistrationStatus: Equatable {
    case notRegistered
    case registering
    case registered
    case unavailableOnSimulator
    case failed
}

@MainActor
@Observable
final class PushNotificationService {
    static let shared = PushNotificationService()

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var registrationStatus: PushRegistrationStatus = .notRegistered
    private(set) var lastError: String?
    private let tokenKey = "miloom.pending-push-token"
    private let registeredTokenKey = "miloom.registered-push-token"

    private init() {
        #if targetEnvironment(simulator)
        registrationStatus = .unavailableOnSimulator
        #else
        if UserDefaults.standard.string(forKey: registeredTokenKey) != nil {
            registrationStatus = .registered
        } else if UserDefaults.standard.string(forKey: tokenKey) != nil {
            registrationStatus = .registering
        } else {
            registrationStatus = .notRegistered
        }
        #endif
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func enableWeeklyBriefings() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAuthorizationStatus()
            if granted {
                AppDiagnostics.event("push", "request_authorization", status: "granted")
                retryDeviceRegistration()
            } else {
                AppDiagnostics.event("push", "request_authorization", status: "denied")
            }
        } catch {
            AppDiagnostics.failure("push", "request_authorization", error: error)
            lastError = error.localizedDescription
        }
    }

    func sendPrivateTestNotification() async -> Bool {
        lastError = nil
        if authorizationStatus == .notDetermined {
            await enableWeeklyBriefings()
        } else {
            await refreshAuthorizationStatus()
        }
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            lastError = "Notifications are disabled for Miloom."
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = "Miloom"
        content.body = PrivateBriefingNotification.testBody
        content.sound = .default
        do {
            let request = UNNotificationRequest(
                identifier: "miloom-private-test-\(UUID().uuidString)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func registerPendingTokenIfNeeded() async {
        guard let token = UserDefaults.standard.string(forKey: tokenKey) else {
            refreshRegistrationStatus()
            return
        }
        registrationStatus = .registering
        do {
            #if DEBUG
            let environment = "development"
            #else
            let environment = "production"
            #endif
            try await DataRepository.shared.registerPushToken(token, environment: environment)
            UserDefaults.standard.set(token, forKey: registeredTokenKey)
            UserDefaults.standard.removeObject(forKey: tokenKey)
            registrationStatus = .registered
            lastError = nil
            AppDiagnostics.event("push", "register_device_token", status: "success")
        } catch {
            registrationStatus = .failed
            AppDiagnostics.failure("push", "register_device_token", error: error)
            lastError = error.localizedDescription
        }
    }

    func unregisterCurrentDevice() async {
        guard let token = UserDefaults.standard.string(forKey: registeredTokenKey) else { return }
        do {
            try await DataRepository.shared.unregisterPushToken(token)
            UserDefaults.standard.removeObject(forKey: registeredTokenKey)
            UserDefaults.standard.removeObject(forKey: tokenKey)
            registrationStatus = .notRegistered
            AppDiagnostics.event("push", "unregister_device_token", status: "success")
        } catch {
            // Signing out must remain available while offline. A stale token that
            // Apple later rejects is removed by the server delivery worker.
            AppDiagnostics.failure("push", "unregister_device_token", error: error)
            lastError = error.localizedDescription
        }
    }

    func registrationFailed(_ error: Error) {
        #if targetEnvironment(simulator)
        registrationStatus = .unavailableOnSimulator
        #else
        registrationStatus = .failed
        #endif
        AppDiagnostics.failure("push", "apns_registration", error: error)
        lastError = error.localizedDescription
    }

    func retryDeviceRegistration() {
        lastError = nil
        #if targetEnvironment(simulator)
        registrationStatus = .unavailableOnSimulator
        #else
        registrationStatus = .registering
        UIApplication.shared.registerForRemoteNotifications()
        #endif
    }

    private func refreshRegistrationStatus() {
        #if targetEnvironment(simulator)
        registrationStatus = .unavailableOnSimulator
        #else
        if UserDefaults.standard.string(forKey: registeredTokenKey) != nil {
            registrationStatus = .registered
        } else if UserDefaults.standard.string(forKey: tokenKey) != nil {
            registrationStatus = .registering
        } else {
            registrationStatus = .notRegistered
        }
        #endif
    }

    nonisolated func receivedDeviceToken(_ data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: tokenKey)
        Task { @MainActor in
            self.registrationStatus = .registering
            await self.registerPendingTokenIfNeeded()
        }
    }
}

final class MiloomAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushNotificationService.shared.receivedDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushNotificationService.shared.registrationFailed(error)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let route = NotificationRoute(
            pushUserInfo: response.notification.request.content.userInfo
        ) {
            Task { @MainActor in
                NotificationRouteCoordinator.shared.enqueue(route)
            }
        }
        completionHandler()
    }
}
