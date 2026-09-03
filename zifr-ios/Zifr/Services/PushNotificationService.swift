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
    static func body(itemCount: Int) -> String {
        "Miloom: \(itemCount) \(itemCount == 1 ? "item needs" : "items need") your attention this week."
    }
}

@MainActor
@Observable
final class PushNotificationService {
    static let shared = PushNotificationService()

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var lastError: String?
    private let tokenKey = "miloom.pending-push-token"

    private init() {}

    func refreshAuthorizationStatus() async {
        authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func enableWeeklyBriefings() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAuthorizationStatus()
            if granted { UIApplication.shared.registerForRemoteNotifications() }
        } catch {
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
        content.body = "Your private notifications are working."
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
        guard let token = UserDefaults.standard.string(forKey: tokenKey) else { return }
        do {
            #if DEBUG
            let environment = "development"
            #else
            let environment = "production"
            #endif
            try await DataRepository.shared.registerPushToken(token, environment: environment)
            UserDefaults.standard.removeObject(forKey: tokenKey)
        } catch {
            lastError = error.localizedDescription
        }
    }

    nonisolated func receivedDeviceToken(_ data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: tokenKey)
        Task { @MainActor in await self.registerPendingTokenIfNeeded() }
    }
}

final class MiloomAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushNotificationService.shared.receivedDeviceToken(deviceToken)
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
