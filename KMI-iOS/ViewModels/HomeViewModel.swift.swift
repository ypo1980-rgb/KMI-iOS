import Foundation
import Combine
import Shared

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class HomeViewModel: ObservableObject {

    @Published var isLoading: Bool = false
    @Published var trainings: [TrainingSession] = []

    func loadUpcomingTrainings() async {

        isLoading = true
        defer { isLoading = false }

        #if canImport(FirebaseFirestore)

        do {
            let db = Firestore.firestore()

            let snap = try await db
                .collection("trainings")
                .order(by: "date")
                .limit(to: 10)
                .getDocuments()

            let items = snap.documents.compactMap { doc -> TrainingSession? in
                let data = doc.data()

                guard
                    let title = data["title"] as? String,
                    let place = data["place"] as? String,
                    let time = data["time"] as? String,
                    let date = data["date"] as? String
                else { return nil }

                return TrainingSession(
                    id: doc.documentID,
                    title: title,
                    dateLine: date,
                    timeLine: time,
                    place: place
                )
            }

            trainings = items

        } catch {
            print("Failed loading trainings:", error.localizedDescription)
        }

        #endif
    }
}
