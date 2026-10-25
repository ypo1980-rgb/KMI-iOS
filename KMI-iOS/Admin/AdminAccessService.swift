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

            guard !Task.isCancelled,
                  Auth.auth().currentUser?.uid == uid,
                  snapshot.exists else {
                return false
            }

            return snapshot.data()?["enabled"] as? Bool == true
        } catch {
            return false
        }
    }
}
