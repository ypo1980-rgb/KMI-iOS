import SwiftUI
import UIKit
import FirebaseCore
import UserNotifications
import GoogleSignIn

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // לא מעכבים את הצגת המסך הראשון בגלל הרשאות / Push.
        // ההגדרה תופעל מיד אחרי שהאפליקציה מתחילה להציג UI.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            KmiPushManager.shared.configure()
        }

        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
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

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("✅ Firebase configured from KMI_iOSApp.init")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                KmiLaunchBackground()

                KmiAppEntryRootView {
                    BirthdayGate {
                        AuthGateView()
                    }
                }
            }
            .background(Color.white.ignoresSafeArea())
        }
    }
}

private struct KmiLaunchBackground: View {
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            if let image = UIImage(named: "app_icon.png") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130, height: 130)
            } else if let image = UIImage(named: "app_icon") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130, height: 130)
            } else {
                Text("K.M.I")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
            }
        }
    }
}
