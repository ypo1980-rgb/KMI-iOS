import Foundation
import Combine
import FirebaseAuth

final class AuthDeviceGate: ObservableObject {
    static let shared = AuthDeviceGate()

    @Published private(set) var isChecking = false
    @Published private(set) var isAuthorized = false
    @Published private(set) var blockMessage: String?

    private let authorizedUidKey = "kmi.device.authorized.uid"

    private init() {}

    private func displayMessage(for reason: String?) -> String {
        switch reason {
        case "device_mismatch":
            return "החשבון הזה כבר משויך למכשיר אחר."
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
        case "no_current_user":
            return "אין משתמש מחובר."
        case .some(let value) where !value.isEmpty:
            return value
        default:
            return "הגישה נחסמה למכשיר זה"
        }
    }

    func verifyCurrentSession() async {
        guard let user = Auth.auth().currentUser else {
            await MainActor.run {
                self.isAuthorized = false
                self.blockMessage = "אין משתמש מחובר"
                self.isChecking = false
            }
            return
        }

        let defaults = UserDefaults.standard
        let cachedAuthorizedUid = defaults.string(forKey: authorizedUidKey)

        // אם אותו משתמש כבר אושר במכשיר הזה – לא בודקים שוב מול השרת
        if cachedAuthorizedUid == user.uid {
            await MainActor.run {
                self.isAuthorized = true
                self.blockMessage = nil
                self.isChecking = false
            }
            return
        }

        await MainActor.run {
            self.isChecking = true
            self.blockMessage = nil
        }

        print("KMI_AUTH email =", user.email ?? "nil")
        print("KMI_AUTH uid =", user.uid)

        let result = await DeviceLockService.shared.verifyCurrentUserDevice()

        await MainActor.run {
            switch result {
            case .allowed:
                defaults.set(user.uid, forKey: self.authorizedUidKey)
                self.isAuthorized = true
                self.blockMessage = nil

            case .denied(let reason):
                defaults.removeObject(forKey: self.authorizedUidKey)
                self.isAuthorized = false
                self.blockMessage = self.displayMessage(for: reason)

            case .failed(let message):
                self.isAuthorized = false
                self.blockMessage = message
            }

            self.isChecking = false
        }
    }
}
