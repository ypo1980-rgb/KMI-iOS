import Foundation
import UIKit
import UserNotifications

@MainActor
final class KmiPushManager: NSObject {
    static let shared = KmiPushManager()

    var lastOpenedRoute: String? = nil
    var lastPayload: [AnyHashable: Any] = [:]

    private override init() {
        super.init()
    }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
        requestPermissionIfNeeded()
    }

    func requestPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    print("KMI_PUSH iOS: already authorized -> registerForRemoteNotifications")
                }

            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                    DispatchQueue.main.async {
                        if let error {
                            print("KMI_PUSH iOS: permission request failed =", error.localizedDescription)
                        }
                        print("KMI_PUSH iOS: permission granted =", granted)
                        if granted {
                            UIApplication.shared.registerForRemoteNotifications()
                        }
                    }
                }

            case .denied:
                print("KMI_PUSH iOS: notifications denied by user")

            @unknown default:
                break
            }
        }
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("KMI_PUSH iOS: APNS device token =", tokenString)
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        print("KMI_PUSH iOS: failed to register for APNS =", error.localizedDescription)
    }

    func handleRemoteNotification(userInfo: [AnyHashable: Any]) {
        lastPayload = userInfo
        print("KMI_PUSH iOS: received payload =", userInfo)

        guard let route = extractRoute(from: userInfo) else {
            return
        }

        lastOpenedRoute = route
        print("KMI_PUSH iOS: extracted route =", route)

        guard let nav = KMI_iOS.AppNavModel.sharedInstance else {
            print("KMI_PUSH: nav model not ready")
            return
        }
        
        DispatchQueue.main.async {
            switch route {
            case "attendance":
                nav.push(KMI_iOS.AppRoute.attendance)

            case "trainingSummary":
                nav.push(KMI_iOS.AppRoute.trainingSummary(pickedDateIso: nil))

            case "adminUsers":
                nav.push(KMI_iOS.AppRoute.settings)

            default:
                print("KMI_PUSH: unknown route =", route)
            }
        }
    }

    func extractRoute(from userInfo: [AnyHashable: Any]) -> String? {
        if let route = userInfo["route"] as? String, !route.isEmpty {
            return route
        }

        if let screen = userInfo["screen"] as? String, !screen.isEmpty {
            return screen
        }

        if let type = userInfo["type"] as? String {
            switch type {
            case "coach_message":
                return "coachMessages"
            case "admin_users":
                return "adminUsers"
            case "attendance":
                return "attendance"
            case "summary":
                return "trainingSummary"
            default:
                return type
            }
        }

        return nil
    }
}

extension KmiPushManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor in
            self.handleRemoteNotification(userInfo: notification.request.content.userInfo)
        }
        completionHandler([.banner, .badge, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            self.handleRemoteNotification(userInfo: response.notification.request.content.userInfo)
        }
        completionHandler()
    }
}
