import Foundation

enum AssistantTrainingKnowledge {

    static func generateAnswer(
        question: String,
        memory: AssistantMemory,
        dataSource: AssistantTrainingDataSource
    ) -> String {
        let raw = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = HebrewNormalize.normalize(raw).lowercased()

        let trainings = dataSource.allTrainings()

        if trainings.isEmpty {
            return """
            כרגע לא מצאתי אימונים במאגר.

            בדוק שהסניף והקבוצה שמורים נכון, ואז נסה שוב.
            """
        }

        if text.contains("אימון הקרוב") ||
            text.contains("האימון הקרוב") ||
            text.contains("אימון הבא") ||
            text.contains("האימון הבא") ||
            text.contains("אימונים קרובים") ||
            text.contains("האימונים הקרובים") {
            let sorted = trainings.sorted { $0.startAtMillis < $1.startAtMillis }

            guard let next = sorted.first else {
                return "לא מצאתי אימון קרוב."
            }

            memory.setLastBranch(next.branchName)
            memory.setLastGroup(next.groupName)
            memory.setLastDay(next.dayName)
            memory.setLastIntent("askNextTraining")

            return """
            האימון הקרוב:
            סניף: \(next.branchName)
            קבוצה: \(next.groupName)
            יום: \(next.dayName)
            שעה: \(next.timeRange)
            מקום: \(next.location)
            מאמן: \(next.coachName)
            """
        }

        if text.contains("מי המאמן") || text.contains("מי מלמד") || text.contains("מי המדריך") {
            let sorted = trainings.sorted { $0.startAtMillis < $1.startAtMillis }

            guard let next = sorted.first else {
                return "לא מצאתי את שם המאמן."
            }

            return "המאמן הוא \(next.coachName)."
        }

        if text.contains("איפה") || text.contains("כתובת") || text.contains("מיקום") {
            let locations = Array(Set(trainings.map(\.location))).sorted()

            if locations.isEmpty {
                return "לא מצאתי את מיקום האימון."
            }

            if locations.count == 1, let only = locations.first {
                return "המקום הוא: \(only)."
            }

            return "מקומות האימון האפשריים:\n" + locations.map { "• \($0)" }.joined(separator: "\n")
        }

        if text.contains("כמה זמן") || text.contains("משך") || text.contains("כמה נמשך") {
            let durations = trainings.compactMap { row -> Int? in
                let parts = row.timeRange.components(separatedBy: "–")
                guard parts.count == 2 else { return nil }

                let start = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let end = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

                func toMinutes(_ value: String) -> Int? {
                    let comps = value.components(separatedBy: ":")
                    guard comps.count == 2,
                          let h = Int(comps[0]),
                          let m = Int(comps[1]) else { return nil }
                    return h * 60 + m
                }

                guard let s = toMinutes(start), let e = toMinutes(end) else { return nil }
                return max(0, e - s)
            }

            guard !durations.isEmpty else {
                return "לא הצלחתי לחשב את משך האימון."
            }

            let avg = durations.reduce(0, +) / durations.count
            return "משך אימון ממוצע הוא בערך \(avg) דקות."
        }

        let grouped = Dictionary(grouping: trainings) { $0.branchName }
        let branchNames = grouped.keys.sorted()

        let answer = branchNames.map { branch in
            let rows = (grouped[branch] ?? []).sorted { $0.startAtMillis < $1.startAtMillis }
            let lines = rows.map {
                "• \($0.dayName) – \($0.timeRange) – \($0.groupName) – מאמן: \($0.coachName)"
            }.joined(separator: "\n")

            return "סניף \(branch):\n\(lines)"
        }
        .joined(separator: "\n\n")

        memory.setLastIntent("askSchedule")
        memory.setLastAnswerContext(answer)

        return """
        להלן לוח האימונים שמצאתי:

        \(answer)
        """
    }
}
