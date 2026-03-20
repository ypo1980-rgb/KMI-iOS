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

    func checkCoach() async {

        guard let phone = Auth.auth().currentUser?.phoneNumber else {
            isCoach = false
            isLoading = false
            return
        }

        let db = Firestore.firestore()

        do {
            let doc = try await db
                .collection("coaches")
                .document(phone)
                .getDocument()

            isCoach = doc.exists
        } catch {
            isCoach = false
        }

        isLoading = false
    }
}
