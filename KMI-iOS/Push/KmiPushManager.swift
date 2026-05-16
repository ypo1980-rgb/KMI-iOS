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
                }

            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                    DispatchQueue.main.async {
                        if granted {
                            UIApplication.shared.registerForRemoteNotifications()
                        }
                    }
                }

            case .denied:
                break

            @unknown default:
                break
            }
        }
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        // APNS token received successfully.
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        // APNS registration failed.
    }

    func handleRemoteNotification(userInfo: [AnyHashable: Any]) {
        lastPayload = userInfo

        guard let route = extractRoute(from: userInfo) else {
            return
        }

        lastOpenedRoute = route

        guard let nav = KMI_iOS.AppNavModel.sharedInstance else {
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
                break
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
