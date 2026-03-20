import Foundation
import Combine
import FirebaseAuth

final class AuthDeviceGate: ObservableObject {
    static let shared = AuthDeviceGate()

    @Published private(set) var isChecking = false
    @Published private(set) var isAuthorized = false
    @Published private(set) var blockMessage: String?

    private init() {}

    // כל האימות מתבצע עכשיו דרך DeviceLockService והשרת

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
                self.blockMessage = reason ?? "הגישה נחסמה למכשיר זה"

            case .failed(let message):
                self.isAuthorized = false
                self.blockMessage = message
            }

            self.isChecking = false
        }
    }
}
