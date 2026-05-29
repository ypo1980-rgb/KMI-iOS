import Foundation
import UIKit
import UserNotifications
import FirebaseAuth
import FirebaseFirestore

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

@MainActor
final class KmiPushManager: NSObject {

    static let shared = KmiPushManager()

    var lastOpenedRoute: String? = nil
    var lastPayload: [AnyHashable: Any] = [:]

    private let db = Firestore.firestore()

    private override init() {
        super.init()
    }

    func configure() {
        UNUserNotificationCenter.current().delegate = self

        #if canImport(FirebaseMessaging)
        Messaging.messaging().delegate = self
        #endif

        requestPermissionIfNeeded()
        refreshAndSaveFcmTokenIfPossible()
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
        #if canImport(FirebaseMessaging)
        Messaging.messaging().apnsToken = deviceToken
        refreshAndSaveFcmTokenIfPossible()
        #endif
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        // ללא לוגים במסך אמת.
    }

    func refreshAndSaveFcmTokenIfPossible() {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().token { token, _ in
            guard let token, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }

            Task { @MainActor in
                self.saveFcmToken(token)
            }
        }
        #endif
    }

    func saveFcmToken(_ token: String) {
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanToken.isEmpty else {
            return
        }

        let currentUser = Auth.auth().currentUser
        let uid = currentUser?.uid ?? ""

        guard !uid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            UserDefaults.standard.set(cleanToken, forKey: "kmi_pending_fcm_token")
            return
        }

        let defaults = UserDefaults.standard

        let email = (
            currentUser?.email ??
            defaults.string(forKey: "email") ??
            defaults.string(forKey: "user_email") ??
            ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        let fullName = (
            defaults.string(forKey: "fullName") ??
            defaults.string(forKey: "name") ??
            defaults.string(forKey: "displayName") ??
            currentUser?.displayName ??
            ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        let branch = firstNonEmptyValue([
            defaults.string(forKey: "active_branch"),
            defaults.string(forKey: "activeBranch"),
            defaults.string(forKey: "branch"),
            defaults.string(forKey: "branchesCsv"),
            defaults.string(forKey: "coach_branch"),
            defaults.string(forKey: "selected_branch"),
            defaults.string(forKey: "current_branch")
        ])

        let groupKey = firstNonEmptyValue([
            defaults.string(forKey: "active_group"),
            defaults.string(forKey: "activeGroup"),
            defaults.string(forKey: "primaryGroup"),
            defaults.string(forKey: "groupKey"),
            defaults.string(forKey: "group_key"),
            defaults.string(forKey: "age_group"),
            defaults.string(forKey: "group"),
            defaults.string(forKey: "coach_groupKey"),
            defaults.string(forKey: "selected_groupKey"),
            defaults.string(forKey: "current_groupKey")
        ])

        let role = firstNonEmptyValue([
            defaults.string(forKey: "user_role"),
            defaults.string(forKey: "role"),
            defaults.string(forKey: "userRole"),
            defaults.string(forKey: "profile_role"),
            defaults.string(forKey: "userType"),
            defaults.string(forKey: "type")
        ])

        let tokenData: [String: Any] = [
            "token": cleanToken,
            "platform": "ios",
            "provider": "fcm",
            "uid": uid,
            "email": email,
            "fullName": fullName,
            "branch": branch,
            "groupKey": groupKey,
            "role": role,
            "app": "kmi-ios",
            "isActive": true,
            "updatedAt": FieldValue.serverTimestamp(),
            "updatedAtMillis": Int64(Date().timeIntervalSince1970 * 1000)
        ]

        let userUpdates: [String: Any] = [
            "fcmToken": cleanToken,
            "fcmPlatform": "ios",
            "pushEnabled": true,
            "pushUpdatedAt": FieldValue.serverTimestamp(),
            "pushUpdatedAtMillis": Int64(Date().timeIntervalSince1970 * 1000),
            "lastKnownBranch": branch,
            "lastKnownGroupKey": groupKey
        ]

        let userRef = db.collection("users").document(uid)

        userRef.setData(userUpdates, merge: true)

        userRef
            .collection("fcmTokens")
            .document(safeDocumentId(cleanToken))
            .setData(tokenData, merge: true)

        db.collection("fcmTokens")
            .document(safeDocumentId(cleanToken))
            .setData(tokenData, merge: true)

        if !branch.isEmpty || !groupKey.isEmpty {
            db.collection("pushTargets")
                .document("forum")
                .collection("tokens")
                .document(safeDocumentId(cleanToken))
                .setData(tokenData, merge: true)
        }

        defaults.removeObject(forKey: "kmi_pending_fcm_token")
    }

    func savePendingFcmTokenAfterLoginIfNeeded() {
        let pending = UserDefaults.standard
            .string(forKey: "kmi_pending_fcm_token")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !pending.isEmpty else {
            refreshAndSaveFcmTokenIfPossible()
            return
        }

        saveFcmToken(pending)
    }

    func handleRemoteNotification(userInfo: [AnyHashable: Any]) {
        lastPayload = userInfo

        prepareForumPayloadIfNeeded(userInfo)

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

            case "forum", "forumRoom", "forum_message", "forumMessage":
                // הפורום יקרא את נתוני הפתיחה מ־UserDefaults.
                // לא מוסיפים כאן AppRoute כדי לא לשבור Build אם שם ה־Route שונה בפרויקט.
                break

            default:
                break
            }
        }
    }

    func extractRoute(from userInfo: [AnyHashable: Any]) -> String? {
        if let route = stringValue(userInfo["route"]), !route.isEmpty {
            return normalizeRoute(route)
        }

        if let screen = stringValue(userInfo["screen"]), !screen.isEmpty {
            return normalizeRoute(screen)
        }

        if let type = stringValue(userInfo["type"]), !type.isEmpty {
            switch type {
            case "coach_message":
                return "coachMessages"

            case "admin_users":
                return "adminUsers"

            case "attendance":
                return "attendance"

            case "summary":
                return "trainingSummary"

            case "forum",
                 "forum_room",
                 "forum_message",
                 "forumMessage",
                 "forumRoom":
                return "forum"

            default:
                return normalizeRoute(type)
            }
        }

        if stringValue(userInfo["forum_push_message_id"]) != nil ||
            stringValue(userInfo["forum_push_room_id"]) != nil ||
            stringValue(userInfo["messageId"]) != nil {
            return "forum"
        }

        return nil
    }

    private func normalizeRoute(_ raw: String) -> String {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        switch clean {
        case "admin_users":
            return "adminUsers"

        case "training_summary", "summary":
            return "trainingSummary"

        case "forum_room", "forum_message", "forumMessage", "forumRoom":
            return "forum"

        default:
            return clean
        }
    }

    private func prepareForumPayloadIfNeeded(_ userInfo: [AnyHashable: Any]) {
        let route = extractRoute(from: userInfo) ?? ""

        let isForumPayload =
            route == "forum" ||
            stringValue(userInfo["forum_push_message_id"]) != nil ||
            stringValue(userInfo["forum_push_room_id"]) != nil ||
            stringValue(userInfo["messageId"]) != nil ||
            stringValue(userInfo["roomId"]) != nil

        guard isForumPayload else {
            return
        }

        let defaults = UserDefaults.standard

        let messageId =
            stringValue(userInfo["forum_push_message_id"]) ??
            stringValue(userInfo["messageId"]) ??
            stringValue(userInfo["message_id"]) ??
            ""

        let roomId =
            stringValue(userInfo["forum_push_room_id"]) ??
            stringValue(userInfo["roomId"]) ??
            stringValue(userInfo["room_id"]) ??
            ""

        let roomName =
            stringValue(userInfo["forum_push_room_name"]) ??
            stringValue(userInfo["roomName"]) ??
            stringValue(userInfo["room_name"]) ??
            ""

        let branch =
            stringValue(userInfo["forum_push_branch_id"]) ??
            stringValue(userInfo["branch"]) ??
            stringValue(userInfo["branchId"]) ??
            stringValue(userInfo["branch_id"]) ??
            ""

        let groupKey =
            stringValue(userInfo["forum_push_group_key"]) ??
            stringValue(userInfo["groupKey"]) ??
            stringValue(userInfo["group_key"]) ??
            stringValue(userInfo["group"]) ??
            ""

        let senderId =
            stringValue(userInfo["forum_push_sender_id"]) ??
            stringValue(userInfo["senderId"]) ??
            stringValue(userInfo["sender_id"]) ??
            stringValue(userInfo["authorUid"]) ??
            ""

        defaults.set(true, forKey: "forum_open_from_push")
        defaults.set(messageId, forKey: "forum_push_message_id")
        defaults.set(roomId, forKey: "forum_push_room_id")
        defaults.set(roomName, forKey: "forum_push_room_name")
        defaults.set(branch, forKey: "forum_push_branch_id")
        defaults.set(groupKey, forKey: "forum_push_group_key")
        defaults.set(senderId, forKey: "forum_push_sender_id")
        defaults.set(Int64(Date().timeIntervalSince1970 * 1000), forKey: "forum_push_received_at")
    }

    private func firstNonEmptyValue(_ values: [String?]) -> String {
        values
            .compactMap { $0 }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }

    private func stringValue(_ raw: Any?) -> String? {
        if let value = raw as? String {
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return clean.isEmpty ? nil : clean
        }

        if let value = raw, !(value is NSNull) {
            let clean = "\(value)".trimmingCharacters(in: .whitespacesAndNewlines)
            return clean.isEmpty || clean.lowercased() == "null" ? nil : clean
        }

        return nil
    }

    private func safeDocumentId(_ raw: String) -> String {
        let clean = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "־", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "\\s+", with: "_", options: .regularExpression)
            .replacingOccurrences(of: "[^a-z0-9א-ת_\\-]+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        return clean.isEmpty ? UUID().uuidString : clean
    }
}

#if canImport(FirebaseMessaging)
extension KmiPushManager: MessagingDelegate {
    nonisolated func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        guard let fcmToken, !fcmToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        Task { @MainActor in
            KmiPushManager.shared.saveFcmToken(fcmToken)
        }
    }
}
#endif

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
