import Foundation
import Combine

@MainActor
final class HomeTrainingsViewModel: ObservableObject {

    @Published var upcomingTrainings: [TrainingData] = []
    @Published var statusMessage: String? = nil

    func loadForCurrentUser(auth: AuthViewModel? = nil) {
        let defaults = UserDefaults.standard

        let region = (
            auth?.userRegion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? auth?.userRegion
            : defaults.string(forKey: "kmi.user.region")
        ) ?? ""

        let branch = (
            auth?.userBranch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? auth?.userBranch
            : defaults.string(forKey: "kmi.user.branch")
        ) ?? ""

        let group = (
            auth?.userGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? auth?.userGroup
            : defaults.string(forKey: "kmi.user.group")
        ) ?? ""

        guard !region.isEmpty else {
            statusMessage = "לא הוגדר אזור למשתמש"
            upcomingTrainings = []
            return
        }

        guard !branch.isEmpty else {
            statusMessage = "לא הוגדר סניף למשתמש"
            upcomingTrainings = []
            return
        }

        guard !group.isEmpty else {
            statusMessage = "לא הוגדרה קבוצה למשתמש"
            upcomingTrainings = []
            return
        }

        if let holdMessage = TrainingCatalogIOS.regionStatusMessage(region) {
            statusMessage = holdMessage
            upcomingTrainings = []
            return
        }

        let list = TrainingCatalogIOS.upcomingFor(
            region: region,
            branch: branch,
            group: group,
            count: 3
        )

        statusMessage = list.isEmpty ? "לא נמצאו אימונים קרובים" : nil
        upcomingTrainings = list
    }
}
