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
            return "הגישה נחסמה למשתמש זה"
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

        await MainActor.run {
            self.isChecking = true
            self.blockMessage = nil
        }

        print("KMI_AUTH device gate disabled")
        print("KMI_AUTH email =", user.email ?? "nil")
        print("KMI_AUTH uid =", user.uid)

        // ✅ חסימת מכשיר מבוטלת:
        // עדיין דורשים משתמש מחובר ב-Firebase,
        // אבל לא בודקים התאמת מכשיר מול השרת ולא חוסמים לפי device_mismatch.
        UserDefaults.standard.set(user.uid, forKey: self.authorizedUidKey)

        await MainActor.run {
            self.isAuthorized = true
            self.blockMessage = nil
            self.isChecking = false
        }
    }
}
