import Foundation
import FirebaseAuth
import FirebaseFirestore

enum AdminAccessService {

    static func isCurrentUserAdmin() async -> Bool {
        guard let uid = Auth.auth().currentUser?.uid,
              !uid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        do {
            let snapshot = try await Firestore.firestore()
                .collection("admins")
                .document(uid)
                .getDocument()

            guard snapshot.exists else {
                return false
            }

            let data = snapshot.data() ?? [:]

            let enabled = data["enabled"] as? Bool == true
            let role = (data["role"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() ?? ""

            let type = (data["type"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() ?? ""

            let isAdminRole =
                role == "admin" ||
                role == "super_admin" ||
                role == "owner" ||
                type == "admin" ||
                type == "super_admin" ||
                type == "owner"

            return enabled || isAdminRole
        } catch {
            return false
        }
    }
}
