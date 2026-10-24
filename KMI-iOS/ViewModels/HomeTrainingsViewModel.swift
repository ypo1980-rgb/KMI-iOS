import Foundation
import Combine

@MainActor
final class HomeTrainingsViewModel: ObservableObject {

    @Published var upcomingTrainings: [TrainingData] = []
    @Published var statusMessage: String? = nil

    func loadForCurrentUser(auth: AuthViewModel? = nil) {
        let defaults = UserDefaults.standard

        let languageCode = (
            defaults.string(forKey: "kmi_app_language") ?? "he"
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

        let isEnglish =
            languageCode == "en" || languageCode == "english"

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

        let assignedSources: [(branch: String, group: String)] =
            (auth?.userBranchAssignments ?? []).flatMap { assignment in
                let branch = clean(assignment.branch)

                guard !branch.isEmpty else {
                    return [(branch: String, group: String)]()
                }

                return uniqueValues(assignment.groups).map { group in
                    (branch: branch, group: group)
                }
            }

        let trainingSources: [(branch: String, group: String)]

        let assignmentsKey =
            RegistrationFormState
                .BranchAssignmentsCodec
                .preferenceKey

        let hasStoredAssignments =
            defaults.object(
                forKey: assignmentsKey
            ) != nil

        if !assignedSources.isEmpty {
            trainingSources = assignedSources

            branches = uniqueValues(
                assignedSources.map { $0.branch }
            )

            groups = uniqueValues(
                assignedSources.map { $0.group }
            )
        } else if hasStoredAssignments {
            /*
             * שיוך מפורש וריק אינו מאפשר
             * חזרה לסניפים ולקבוצות ישנים.
             */
            trainingSources = []
            branches = []
            groups = []
        } else if branches.count == 1,
                  let branch = branches.first {
            /*
             * תאימות לנתונים ישנים:
             * ניתן להסיק שיוך רק בסניף יחיד.
             */
            trainingSources = groups.map { group in
                (branch: branch, group: group)
            }
        } else {
            statusMessage = isEnglish
                ? "Branch and group assignments must be updated in your profile."
                : "יש לעדכן בפרופיל את שיוך הקבוצות לסניפים."

            upcomingTrainings = []
            return
        }

        guard !region.isEmpty else {
            statusMessage = isEnglish
                ? "No region is configured for this user."
                : "לא הוגדר אזור למשתמש"
            upcomingTrainings = []
            return
        }

        guard !branches.isEmpty else {
            statusMessage = isEnglish
                ? "No branch is configured for this user."
                : "לא הוגדר סניף למשתמש"
            upcomingTrainings = []
            return
        }

        guard !groups.isEmpty else {
            statusMessage = isEnglish
                ? "No group is configured for this user."
                : "לא הוגדרה קבוצה למשתמש"
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
         * כאשר קיימים שיוכים, כל קבוצה נטענת
         * רק עבור הסניף שאליו שויכה.
         */
        var loadedSourceKeys = Set<[String]>()

        for source in trainingSources {
            let sourceKey = [
                source.branch,
                source.group
            ]

            guard loadedSourceKeys.insert(
                sourceKey
            ).inserted else {
                continue
            }

            let matchingTrainings =
                TrainingCatalogIOS.upcomingFor(
                    region: region,
                    branch: source.branch,
                    group: source.group,
                    count: 50
                )

            collectedTrainings += matchingTrainings
        }

        /*
         * אותו אימון יכול להגיע דרך יותר מקבוצה אחת.
         * המפתח מתאר אימון פיזי לפי זמן, מקום וכתובת.
         */
        var seenTrainingKeys = Set<String>()

        func completenessScore(
            _ training: TrainingData
        ) -> Int {
            [
                training.place,
                training.address,
                training.coach,
                training.endText
            ]
            .filter {
                !$0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty
            }
            .count
        }

        let uniqueTrainings =
            collectedTrainings
                .sorted { left, right in
                    if left.date == right.date {
                        return completenessScore(left)
                            > completenessScore(right)
                    }

                    return left.date < right.date
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

        statusMessage = uniqueTrainings.isEmpty
            ? (
                isEnglish
                    ? "No upcoming trainings were found."
                    : "לא נמצאו אימונים קרובים"
            )
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
