import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class CoachService: ObservableObject {

    @Published var isCoach: Bool = false
    @Published var isLoading: Bool = true

    static let shared = CoachService()

    private init() {}

    func checkCoach(userRole: String? = nil) async {
        isLoading = true

        let normalizedRole = normalizeRole(userRole)
        let normalizedEmail = normalizeEmail(Auth.auth().currentUser?.email)
        let normalizedPhone = normalizePhone(Auth.auth().currentUser?.phoneNumber)

        print("COACH CHECK role =", normalizedRole)
        print("COACH CHECK email =", normalizedEmail)
        print("COACH CHECK phone =", normalizedPhone)

        // 1) הרשאה לפי role מהפרופיל
        if isCoachRole(normalizedRole) {
            isCoach = true
            isLoading = false
            return
        }

        // 2) הרשאה מיוחדת למייל שלך לצורכי פיתוח/בדיקה
        if normalizedEmail == "ypo1980@gmail.com" {
            isCoach = true
            isLoading = false
            return
        }

        let db = Firestore.firestore()

        // 3) בדיקה לפי מספר טלפון במסמך coaches/{phone}
        if !normalizedPhone.isEmpty {
            do {
                let phoneDoc = try await db
                    .collection("coaches")
                    .document(normalizedPhone)
                    .getDocument()

                if phoneDoc.exists {
                    isCoach = true
                    isLoading = false
                    return
                }
            } catch {
                print("COACH CHECK phone lookup failed:", error.localizedDescription)
            }
        }

        // 4) fallback לפי אימייל בתוך collection coaches
        if !normalizedEmail.isEmpty {
            do {
                let emailSnap = try await db
                    .collection("coaches")
                    .whereField("emailLower", isEqualTo: normalizedEmail)
                    .limit(to: 1)
                    .getDocuments()

                if !emailSnap.documents.isEmpty {
                    isCoach = true
                    isLoading = false
                    return
                }

                let emailSnapAlt = try await db
                    .collection("coaches")
                    .whereField("email", isEqualTo: normalizedEmail)
                    .limit(to: 1)
                    .getDocuments()

                if !emailSnapAlt.documents.isEmpty {
                    isCoach = true
                    isLoading = false
                    return
                }
            } catch {
                print("COACH CHECK email lookup failed:", error.localizedDescription)
            }
        }

        isCoach = false
        isLoading = false
    }

    private func normalizeRole(_ value: String?) -> String {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }

    private func normalizeEmail(_ value: String?) -> String {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }

    private func normalizePhone(_ value: String?) -> String {
        (value ?? "").filter { $0.isNumber }
    }

    private func isCoachRole(_ role: String) -> Bool {
        role == "coach" || role == "trainer" || role == "מאמן"
    }
}
