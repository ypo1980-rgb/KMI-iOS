import Foundation
import Combine
import FirebaseAuth

final class AuthDeviceGate: ObservableObject {
    static let shared = AuthDeviceGate()

    @Published private(set) var isChecking = false
    @Published private(set) var isAuthorized = false
    @Published private(set) var blockMessage: String?

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
        await MainActor.run {
            self.isChecking = true
            self.blockMessage = nil
        }

        guard Auth.auth().currentUser != nil else {
            await MainActor.run {
                self.isAuthorized = false
                self.blockMessage = "אין משתמש מחובר"
                self.isChecking = false
            }
            return
        }

        guard let user = Auth.auth().currentUser else {
            await MainActor.run {
                self.isAuthorized = false
                self.blockMessage = "אין משתמש מחובר"
                self.isChecking = false
            }
            return
        }

        print("KMI_AUTH email =", user.email ?? "nil")
        print("KMI_AUTH uid =", user.uid)

        let result = await DeviceLockService.shared.verifyCurrentUserDevice()

        await MainActor.run {
            switch result {
            case .allowed:
                self.isAuthorized = true
                self.blockMessage = nil

            case .denied(let reason):
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
