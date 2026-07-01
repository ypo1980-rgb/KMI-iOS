import SwiftUI
import UIKit
import FirebaseCore
import UserNotifications
import GoogleSignIn

private enum FirebaseBootstrap {
    private static var didConfigure = false

    static func configureIfNeeded() {
        guard !didConfigure else { return }

        FirebaseApp.configure()
        didConfigure = true
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {

    static var pendingLaunchRemoteNotification: [AnyHashable: Any]?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        FirebaseBootstrap.configureIfNeeded()

        if let remoteNotification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            AppDelegate.pendingLaunchRemoteNotification = remoteNotification
        }

        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
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
}

@main
struct KMI_iOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var didRunPostLaunchSetup = false

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
            .preferredColorScheme(.light)
            .task {
                guard !didRunPostLaunchSetup else { return }
                didRunPostLaunchSetup = true

                await Task.yield()

                try? await Task.sleep(nanoseconds: 250_000_000)

                await MainActor.run {
                    KmiPushManager.shared.configure()

                    if let remoteNotification = AppDelegate.pendingLaunchRemoteNotification {
                        AppDelegate.pendingLaunchRemoteNotification = nil
                        KmiPushManager.shared.handleRemoteNotification(userInfo: remoteNotification)
                    }

                    KmiPushManager.shared.savePendingFcmTokenAfterLoginIfNeeded()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                KmiPushManager.shared.refreshAndSaveFcmTokenIfPossible()
                KmiPushManager.shared.savePendingFcmTokenAfterLoginIfNeeded()
            }
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
