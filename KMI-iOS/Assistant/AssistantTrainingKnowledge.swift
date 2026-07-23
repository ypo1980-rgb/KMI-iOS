import Foundation

enum AssistantTrainingKnowledge {

    private static var isEnglish: Bool {
        let defaults = UserDefaults.standard

        let values = [
            defaults.string(forKey: "kmi_app_language") ?? "",
            defaults.string(forKey: "selected_language_code") ?? "",
            defaults.string(forKey: "app_language") ?? "",
            defaults.string(forKey: "initial_language_code") ?? ""
        ]
        .map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        }

        return values.contains("en") ||
            values.contains("english")
    }

    private static func tr(
        _ he: String,
        _ en: String
    ) -> String {
        isEnglish ? en : he
    }

    private static var currentTimeMillis: Int64 {
        Int64(Date().timeIntervalSince1970 * 1_000)
    }

    private static func futureTrainings(
        from trainings: [TrainingRow]
    ) -> [TrainingRow] {
        trainings
            .filter {
                $0.startAtMillis >= currentTimeMillis
            }
            .sorted {
                $0.startAtMillis < $1.startAtMillis
            }
    }

    private static func contextualTrainings(
        from trainings: [TrainingRow],
        memory: AssistantMemory
    ) -> [TrainingRow] {
        var result = trainings

        if let branch = memory.getLastBranch()?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !branch.isEmpty {

            let branchMatches = result.filter {
                normalized($0.branchName) == normalized(branch)
            }

            if !branchMatches.isEmpty {
                result = branchMatches
            }
        }

        if let group = memory.getLastGroup()?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !group.isEmpty {

            let groupMatches = result.filter {
                normalized($0.groupName) == normalized(group)
            }

            if !groupMatches.isEmpty {
                result = groupMatches
            }
        }

        return result.sorted {
            $0.startAtMillis < $1.startAtMillis
        }
    }

    private static func normalized(
        _ value: String
    ) -> String {
        HebrewNormalize.normalize(value)
            .lowercased()
            .replacingOccurrences(of: "־", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func durationMinutes(
        from timeRange: String
    ) -> Int? {
        let normalizedRange = timeRange
            .replacingOccurrences(of: "־", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")

        let parts = normalizedRange.components(
            separatedBy: "-"
        )

        guard parts.count == 2 else {
            return nil
        }

        func minutesFromMidnight(
            _ value: String
        ) -> Int? {
            let components = value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: ":")

            guard components.count == 2,
                  let hour = Int(components[0]),
                  let minute = Int(components[1]),
                  (0...23).contains(hour),
                  (0...59).contains(minute) else {
                return nil
            }

            return hour * 60 + minute
        }

        guard let start = minutesFromMidnight(parts[0]),
              var end = minutesFromMidnight(parts[1]) else {
            return nil
        }

        if end < start {
            end += 24 * 60
        }

        let duration = end - start

        return duration > 0 ? duration : nil
    }

    static func generateAnswer(
        question: String,
        memory: AssistantMemory,
        dataSource: AssistantTrainingDataSource
    ) -> String {
        let rawQuestion = question.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !rawQuestion.isEmpty else {
            return tr(
                "כתוב או אמור שאלה על האימונים.",
                "Type or say a question about training."
            )
        }

        let text = normalized(rawQuestion)
        let allTrainings = dataSource.allTrainings()
        let upcoming = futureTrainings(from: allTrainings)

        guard !allTrainings.isEmpty else {
            let answer = tr(
                """
                כרגע לא מצאתי אימונים במאגר.

                בדוק שהסניף והקבוצה שמורים נכון, ואז נסה שוב.
                """,
                """
                I couldn't find any training sessions.

                Check that your branch and group are saved correctly, then try again.
                """
            )

            memory.setTrainingContext(
                branch: nil,
                group: nil,
                day: nil,
                intent: "noTrainingsFound",
                answer: answer
            )

            return answer
        }

        let asksForNextTraining =
            text.contains("אימון הקרוב") ||
            text.contains("האימון הקרוב") ||
            text.contains("אימון הבא") ||
            text.contains("האימון הבא") ||
            text.contains("אימונים קרובים") ||
            text.contains("האימונים הקרובים") ||
            text.contains("next training") ||
            text.contains("next session") ||
            text.contains("upcoming training")

        if asksForNextTraining {
            guard let next = upcoming.first else {
                let answer = tr(
                    "לא מצאתי אימון עתידי קרוב.",
                    "I couldn't find an upcoming training session."
                )

                memory.setTrainingContext(
                    branch: nil,
                    group: nil,
                    day: nil,
                    intent: "askNextTraining",
                    answer: answer
                )

                return answer
            }

            let answer = tr(
                """
                האימון הקרוב:
                סניף: \(next.branchName)
                קבוצה: \(next.groupName)
                יום: \(next.dayName)
                שעה: \(next.timeRange)
                מקום: \(next.location)
                מאמן: \(next.coachName)
                """,
                """
                Your next training:
                Branch: \(next.branchName)
                Group: \(next.groupName)
                Day: \(next.dayName)
                Time: \(next.timeRange)
                Location: \(next.location)
                Coach: \(next.coachName)
                """
            )

            memory.setTrainingContext(
                branch: next.branchName,
                group: next.groupName,
                day: next.dayName,
                intent: "askNextTraining",
                answer: answer
            )

            return answer
        }

        let contextualUpcoming = contextualTrainings(
            from: upcoming.isEmpty ? allTrainings : upcoming,
            memory: memory
        )

        let asksForCoach =
            text.contains("מי המאמן") ||
            text.contains("מי מלמד") ||
            text.contains("מי המדריך") ||
            text.contains("who is the coach") ||
            text.contains("who teaches") ||
            text.contains("instructor")

        if asksForCoach {
            guard let relevant = contextualUpcoming.first else {
                return tr(
                    "לא מצאתי את שם המאמן.",
                    "I couldn't find the coach's name."
                )
            }

            let answer = tr(
                "המאמן באימון הזה הוא \(relevant.coachName).",
                "The coach for this training is \(relevant.coachName)."
            )

            memory.setTrainingContext(
                branch: relevant.branchName,
                group: relevant.groupName,
                day: relevant.dayName,
                intent: "askCoach",
                answer: answer
            )

            return answer
        }

        let asksForLocation =
            text.contains("איפה") ||
            text.contains("כתובת") ||
            text.contains("מיקום") ||
            text.contains("where") ||
            text.contains("address") ||
            text.contains("location")

        if asksForLocation {
            let relevantRows = contextualUpcoming.isEmpty
                ? allTrainings
                : contextualUpcoming

            let locations = Array(
                Set(
                    relevantRows
                        .map {
                            $0.location.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                        }
                        .filter { !$0.isEmpty }
                )
            )
            .sorted()

            guard !locations.isEmpty else {
                return tr(
                    "לא מצאתי את מיקום האימון.",
                    "I couldn't find the training location."
                )
            }

            let answer: String

            if locations.count == 1,
               let location = locations.first {
                answer = tr(
                    "מקום האימון הוא: \(location).",
                    "The training location is: \(location)."
                )
            } else {
                let list = locations
                    .map { "• \($0)" }
                    .joined(separator: "\n")

                answer = tr(
                    "מקומות האימון האפשריים:\n\(list)",
                    "Possible training locations:\n\(list)"
                )
            }

            let relevant = relevantRows.first

            memory.setTrainingContext(
                branch: relevant?.branchName,
                group: relevant?.groupName,
                day: relevant?.dayName,
                intent: "askLocation",
                answer: answer
            )

            return answer
        }

        let asksForDuration =
            text.contains("כמה זמן") ||
            text.contains("משך") ||
            text.contains("כמה נמשך") ||
            text.contains("how long") ||
            text.contains("duration")

        if asksForDuration {
            let relevantRows = contextualUpcoming.isEmpty
                ? allTrainings
                : contextualUpcoming

            let durations = relevantRows.compactMap {
                durationMinutes(from: $0.timeRange)
            }

            guard !durations.isEmpty else {
                return tr(
                    "לא הצלחתי לחשב את משך האימון.",
                    "I couldn't calculate the training duration."
                )
            }

            let average = durations.reduce(0, +) /
                durations.count

            let answer = tr(
                "משך האימון הוא בערך \(average) דקות.",
                "The training duration is approximately \(average) minutes."
            )

            let relevant = relevantRows.first

            memory.setTrainingContext(
                branch: relevant?.branchName,
                group: relevant?.groupName,
                day: relevant?.dayName,
                intent: "askDuration",
                answer: answer
            )

            return answer
        }

        let scheduleRows = upcoming.isEmpty
            ? allTrainings.sorted {
                $0.startAtMillis < $1.startAtMillis
            }
            : upcoming

        let grouped = Dictionary(
            grouping: scheduleRows
        ) {
            $0.branchName
        }

        let branchNames = grouped.keys.sorted()

        let schedule = branchNames.map { branch in
            let rows = (grouped[branch] ?? [])
                .sorted {
                    $0.startAtMillis < $1.startAtMillis
                }

            let lines = rows.map { row in
                tr(
                    "• \(row.dayName) – \(row.timeRange) – \(row.groupName) – מאמן: \(row.coachName)",
                    "• \(row.dayName) – \(row.timeRange) – \(row.groupName) – Coach: \(row.coachName)"
                )
            }
            .joined(separator: "\n")

            return tr(
                "סניף \(branch):\n\(lines)",
                "Branch \(branch):\n\(lines)"
            )
        }
        .joined(separator: "\n\n")

        let answer = tr(
            """
            להלן לוח האימונים שמצאתי:

            \(schedule)
            """,
            """
            Here is the training schedule I found:

            \(schedule)
            """
        )

        let first = scheduleRows.first

        memory.setTrainingContext(
            branch: first?.branchName,
            group: first?.groupName,
            day: first?.dayName,
            intent: "askSchedule",
            answer: answer
        )

        return answer
    }
}
