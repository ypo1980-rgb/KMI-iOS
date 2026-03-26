import Foundation
import FirebaseAuth
import FirebaseFirestore

enum AdminAccessService {
    static func isCurrentUserAdmin() async -> Bool {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            print("KMI_ADMIN iOS: no uid (not signed in)")
            return false
        }

        do {
            print("KMI_ADMIN iOS: checking admins/\(uid) ...")

            let snapshot = try await Firestore.firestore()
                .collection("admins")
                .document(uid)
                .getDocument()

            let enabled = snapshot.data()?["enabled"] as? Bool == true

            print("KMI_ADMIN iOS: exists=\(snapshot.exists) enabled=\(enabled) data=\(snapshot.data() ?? [:])")

            return snapshot.exists && enabled
        } catch {
            print("KMI_ADMIN iOS: FAILED to read admins/\(uid) error=\(error)")
            return false
        }
    }
}
