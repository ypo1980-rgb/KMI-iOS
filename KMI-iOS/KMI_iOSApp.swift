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
    @UIApplicationDelegateAdaptor(AppDelegate.self)
    private var delegate

    @StateObject
    private var displaySettings = KmiDisplaySettings()

    @AppStorage("theme_mode")
    private var themeMode: String = "system"

    @State
    private var didRunPostLaunchSetup = false

    private var preferredAppColorScheme: ColorScheme? {
        switch themeMode
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased() {

        case "light":
            return .light

        case "dark":
            return .dark

        default:
            return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()

                KmiLaunchBackground()

                KmiAppEntryRootView {
                    BirthdayGate {
                        AuthGateView()
                    }
                }
            }
            .background(
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
            )
            .preferredColorScheme(
                preferredAppColorScheme
            )
            .kmiDisplayScale(displaySettings)
            .task {
                guard !didRunPostLaunchSetup else {
                    return
                }

                didRunPostLaunchSetup = true

                displaySettings.reloadFromDefaults()

                await Task.yield()

                try? await Task.sleep(
                    nanoseconds: 250_000_000
                )

                await MainActor.run {
                    KmiPushManager.shared.configure()

                    if let remoteNotification =
                        AppDelegate.pendingLaunchRemoteNotification {
                        AppDelegate.pendingLaunchRemoteNotification = nil

                        KmiPushManager.shared
                            .handleRemoteNotification(
                                userInfo: remoteNotification
                            )
                    }

                    KmiPushManager.shared
                        .savePendingFcmTokenAfterLoginIfNeeded()
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.didBecomeActiveNotification
                )
            ) { _ in
                displaySettings.reloadFromDefaults()

                KmiPushManager.shared
                    .refreshAndSaveFcmTokenIfPossible()

                KmiPushManager.shared
                    .savePendingFcmTokenAfterLoginIfNeeded()
            }
        }
    }
}

private struct KmiLaunchBackground: View {
    @Environment(\.colorScheme)
    private var colorScheme

    private var launchBackgroundColor: Color {
        colorScheme == .dark
            ? Color(
                red: 0.015,
                green: 0.035,
                blue: 0.075
            )
            : Color.white
    }

    private var fallbackTextColor: Color {
        colorScheme == .dark
            ? Color.white
            : Color.black
    }

    var body: some View {
        ZStack {
            launchBackgroundColor
                .ignoresSafeArea()

            if let image = UIImage(
                named: "app_icon.png"
            ) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: 130,
                        height: 130
                    )
            } else if let image = UIImage(
                named: "app_icon"
            ) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: 130,
                        height: 130
                    )
            } else {
                Text("K.M.I")
                    .kmiFont(
                        size: 32,
                        weight: .black,
                        design: .rounded
                    )
                    .foregroundStyle(
                        fallbackTextColor
                    )
            }
        }
    }
}
