import Foundation
import Combine

@MainActor
final class HomeTrainingsViewModel: ObservableObject {

    @Published var upcomingTrainings: [TrainingData] = []
    @Published var statusMessage: String? = nil

    func loadForCurrentUser(auth: AuthViewModel? = nil) {
        let defaults = UserDefaults.standard

        func clean(_ value: String?) -> String {
            value?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                ) ?? ""
        }

        func splitStoredValues(_ raw: String) -> [String] {
            raw
                .replacingOccurrences(of: "[", with: "")
                .replacingOccurrences(of: "]", with: "")
                .split { character in
                    character == "," ||
                    character == ";" ||
                    character == "|" ||
                    character == "\n"
                }
                .map {
                    String($0)
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        .trimmingCharacters(
                            in: CharacterSet(
                                charactersIn: "\""
                            )
                        )
                }
                .filter { !$0.isEmpty }
        }

        func storedValues(
            for keys: [String]
        ) -> [String] {
            var result: [String] = []

            for key in keys {
                if let array = defaults.array(
                    forKey: key
                ) {
                    result += array
                        .map {
                            "\($0)".trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                        }
                        .filter { !$0.isEmpty }
                }

                if let rawValue = defaults.string(
                    forKey: key
                ) {
                    result += splitStoredValues(
                        rawValue
                    )
                }
            }

            return result
        }

        func uniqueValues(
            _ values: [String]
        ) -> [String] {
            var seen = Set<String>()

            return values
                .map {
                    $0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                }
                .filter { !$0.isEmpty }
                .filter { value in
                    let normalized =
                        value
                            .lowercased()
                            .replacingOccurrences(
                                of: "\\s+",
                                with: " ",
                                options: .regularExpression
                            )
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )

                    guard !seen.contains(normalized) else {
                        return false
                    }

                    seen.insert(normalized)
                    return true
                }
        }

        let authRegion = clean(
            auth?.userRegion
        )

        let region = [
            authRegion,
            clean(
                defaults.string(
                    forKey: "kmi.user.region"
                )
            ),
            clean(
                defaults.string(
                    forKey: "region"
                )
            ),
            clean(
                defaults.string(
                    forKey: "active_region"
                )
            )
        ]
        .first { !$0.isEmpty } ?? ""

        var branches: [String] = [
            clean(auth?.userBranch)
        ]

        branches += storedValues(
            for: [
                "branches",
                "branches_json",
                "selected_branches",
                "active_branch",
                "activeBranch",
                "branch",
                "kmi.user.branch",
                "branch2",
                "branch3"
            ]
        )

        branches = uniqueValues(branches)

        var groups: [String] = [
            clean(auth?.userGroup)
        ]

        groups += storedValues(
            for: [
                "groups",
                "groups_json",
                "selected_groups",
                "active_group",
                "activeGroup",
                "group",
                "groupKey",
                "age_group",
                "age_groups",
                "kmi.user.group"
            ]
        )

        groups = uniqueValues(groups)

        guard !region.isEmpty else {
            statusMessage =
                "לא הוגדר אזור למשתמש"
            upcomingTrainings = []
            return
        }

        guard !branches.isEmpty else {
            statusMessage =
                "לא הוגדר סניף למשתמש"
            upcomingTrainings = []
            return
        }

        guard !groups.isEmpty else {
            statusMessage =
                "לא הוגדרה קבוצה למשתמש"
            upcomingTrainings = []
            return
        }

        if let holdMessage =
            TrainingCatalogIOS
                .regionStatusMessage(region) {
            statusMessage = holdMessage
            upcomingTrainings = []
            return
        }

        var collectedTrainings: [TrainingData] = []

        /*
         * טוענים אימונים מכל הסניפים ומכל הקבוצות שנבחרו.
         * שילוב שאינו קיים בקטלוג פשוט יחזיר רשימה ריקה.
         */
        for branch in branches {
            for group in groups {
                let matchingTrainings =
                TrainingCatalogIOS.upcomingFor(
                    region: region,
                    branch: branch,
                    group: group,
                    count: 50
                )

                collectedTrainings += matchingTrainings
            }
        }

        /*
         * אותו אימון יכול להגיע דרך יותר מקבוצה אחת.
         * המפתח מתאר אימון פיזי לפי זמן, מקום וכתובת.
         */
        var seenTrainingKeys = Set<String>()

        let uniqueTrainings =
            collectedTrainings
                .sorted {
                    $0.date < $1.date
                }
                .filter { training in
                    let startMinute =
                        Int(
                            training.date
                                .timeIntervalSince1970
                            / 60
                        )

                    let key = [
                        String(startMinute),
                        training.endText
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                            .lowercased(),
                        training.place
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                            .lowercased(),
                        training.address
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                            .lowercased()
                    ]
                    .joined(separator: "|")

                    guard !seenTrainingKeys.contains(key) else {
                        return false
                    }

                    seenTrainingKeys.insert(key)
                    return true
                }

        statusMessage =
            uniqueTrainings.isEmpty
            ? "לא נמצאו אימונים קרובים"
            : nil

        upcomingTrainings = uniqueTrainings

        /*
         * בכל טעינה או שינוי של האימונים הקרובים,
         * מוחקים את התזכורות הישנות ובונים אותן מחדש.
         */
        TrainingReminderScheduler.shared.refresh(
            trainings: uniqueTrainings
        )
    }
}
