import SwiftUI
import UIKit
import FirebaseCore
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("✅ Firebase configured from AppDelegate")
        }

        KmiPushManager.shared.configure()

        let center = UNUserNotificationCenter.current()
        center.delegate = self

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        KmiPushManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        KmiPushManager.shared.didFailToRegisterForRemoteNotifications(error: error)
    }

    // כשהאפליקציה פתוחה – עדיין נציג באנר/צליל
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // לחיצה על התראה / אקשנים
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}

@main
struct KMI_iOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            KmiAppEntryRootView {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.01, green: 0.05, blue: 0.14),
                            Color(red: 0.07, green: 0.10, blue: 0.23),
                            Color(red: 0.11, green: 0.33, blue: 0.80)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    BirthdayGate {
                        AuthGateView()
                    }
                }
            }
        }
    }
}
