import Foundation
import Combine
import FirebaseAuth

@MainActor
final class AuthDeviceGate: ObservableObject {
    static let shared = AuthDeviceGate()

    @Published private(set) var isChecking = false
    @Published private(set) var isAuthorized = false
    @Published private(set) var blockMessage: String?

    private let authorizedUidKey = "kmi.device.authorized.uid"

    private init() {}

    private func displayMessage(for reason: String?) -> String {
        switch reason {
        case "user_not_authorized":
            return "המשתמש הזה אינו מורשה להיכנס לאפליקציה."
        case "user_inactive":
            return "המשתמש הזה אינו פעיל כרגע."
        case "email_mismatch":
            return "כתובת האימייל אינה תואמת לרשומת ההרשאה."
        case "phone_mismatch":
            return "מספר הטלפון אינו תואם לרשומת ההרשאה."
        case "bundle_id_mismatch":
            return "גרסת האפליקציה או הזיהוי שלה אינם תואמים."
        case "device_mismatch":
            return "המשתמש הזה מחובר ממכשיר שאינו מורשה."
        case "no_current_user":
            return "אין משתמש מחובר."
        case .some(let value) where !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty:
            return value
        default:
            return "הגישה נחסמה למשתמש זה."
        }
    }

    func verifyCurrentSession() async {
        guard let user = Auth.auth().currentUser else {
            isAuthorized = false
            blockMessage = displayMessage(for: "no_current_user")
            isChecking = false
            UserDefaults.standard.removeObject(forKey: authorizedUidKey)
            return
        }

        isChecking = true
        blockMessage = nil

        let result = await DeviceLockService.shared.verifyCurrentUserDevice()

        switch result {
        case .allowed(_):
            UserDefaults.standard.set(user.uid, forKey: authorizedUidKey)
            isAuthorized = true
            blockMessage = nil
            isChecking = false

        case .denied(let reason):
            UserDefaults.standard.removeObject(forKey: authorizedUidKey)
            isAuthorized = false
            blockMessage = displayMessage(for: reason)
            isChecking = false

        case .failed(let message):
            UserDefaults.standard.removeObject(forKey: authorizedUidKey)
            isAuthorized = false
            blockMessage = message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? displayMessage(for: nil)
                : message
            isChecking = false
        }
    }

    func reset() {
        isChecking = false
        isAuthorized = false
        blockMessage = nil
        UserDefaults.standard.removeObject(forKey: authorizedUidKey)
    }
}
