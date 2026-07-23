import Foundation
import Shared

enum AssistantLocalFallbackAnswer {

    private struct ClosureTrainingDataSource:
        AssistantTrainingDataSource {

        let provider: () -> [TrainingRow]

        func allTrainings() -> [TrainingRow] {
            provider()
        }
    }

    struct Params {
        let question: String
        let contextLabel: String?
        let getExternalDefenses: ((Belt) -> [String])?
        let getExerciseExplanation: ((String) -> String?)?
        let getUpcomingTrainings: (() -> [TrainingRow])?
        let searchEngine: AssistantSearchEngine
        let memory: AssistantMemory

        init(
            question: String,
            contextLabel: String?,
            getExternalDefenses: ((Belt) -> [String])?,
            getExerciseExplanation: ((String) -> String?)?,
            getUpcomingTrainings: (() -> [TrainingRow])?,
            searchEngine: AssistantSearchEngine,
            memory: AssistantMemory = AssistantMemory()
        ) {
            self.question = question
            self.contextLabel = contextLabel
            self.getExternalDefenses = getExternalDefenses
            self.getExerciseExplanation = getExerciseExplanation
            self.getUpcomingTrainings = getUpcomingTrainings
            self.searchEngine = searchEngine
            self.memory = memory
        }
    }

    static func answer(_ p: Params) -> String {
        let question = p.question
        let text = question.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let beltEnum =
            AssistantBeltDetector.detect(question)

        let isEnglish = currentLanguageIsEnglish()

        let beltDisplayName = beltEnum.map {
            AssistantBeltDetector.localizedName(
                $0,
                isEnglish: isEnglish
            )
        }

        let looksLikeExplanationQuestion =
            (text.contains("הסבר") || text.contains("תסביר") || text.contains("פירוט") || text.contains("איך עושים") || text.contains("איך מבצעים")) &&
            !(text.contains("אימון הקרוב") || text.contains("האימון הקרוב") || text.contains("אימון הבא") || text.contains("האימון הבא") ||
              text.contains("אימונים קרובים") || text.contains("האימונים הקרובים") || text.contains("לוח אימונים") ||
              text.contains("לו\"ז") || text.contains("לוז"))

        let trainingKeywords = [
            "אימון",
            "אימונים",
            "אימון הקרוב",
            "האימון הקרוב",
            "אימון הבא",
            "האימון הבא",
            "האימונים הקרובים",
            "האימונים הבאים",
            "לוח אימונים",
            "לו\"ז",
            "לוז",
            "שעות אימון",
            "שעת אימון",
            "קבוצת אימון",
            "קבוצה שלי",
            "next training",
            "next session",
            "training schedule",
            "training time"
        ]

        let trainingFollowUpKeywords = [
            "מי המאמן",
            "מי המדריך",
            "מי מלמד",
            "איפה זה",
            "איפה האימון",
            "מה הכתובת",
            "מה המיקום",
            "כמה זמן",
            "כמה נמשך",
            "מה משך האימון",
            "who is the coach",
            "who teaches",
            "where is it",
            "where is the training",
            "what is the address",
            "how long",
            "duration"
        ]

        let hasTrainingMemory =
            p.memory.getLastIntent() != nil &&
            (
                p.memory.getLastBranch() != nil ||
                p.memory.getLastGroup() != nil ||
                p.memory.getLastDay() != nil
            )

        let isDirectTrainingQuestion =
            trainingKeywords.contains {
                text.contains($0)
            }

        let isTrainingFollowUp =
            hasTrainingMemory &&
            trainingFollowUpKeywords.contains {
                text.contains($0)
            }

        let looksLikeTrainingQuestion =
            isDirectTrainingQuestion ||
            isTrainingFollowUp

        if let getUpcomingTrainings = p.getUpcomingTrainings,
           looksLikeTrainingQuestion,
           !looksLikeExplanationQuestion {

            let dataSource =
                ClosureTrainingDataSource(
                    provider: getUpcomingTrainings
                )

            return AssistantTrainingKnowledge.generateAnswer(
                question: question,
                memory: p.memory,
                dataSource: dataSource
            )
        }

        if text.contains("הגנות חיצוניות") {
            if let beltEnum, let getExternalDefenses = p.getExternalDefenses {
                let list = getExternalDefenses(beltEnum)
                if !list.isEmpty {
                    let titleBelt = beltDisplayName ?? AssistantBeltDetector.hebrewName(beltEnum)
                    let listText = list.map { "• \($0)" }.joined(separator: "\n")
                    return "הגנות חיצוניות בחגורה \(titleBelt):\n\n\(listText)\n"
                }
            }

            let beltLine = beltDisplayName.map { "בחגורה \($0)" } ?? "לרמה שלך"
            return "כרגע לא מצאתי רשימה מדויקת של הגנות חיצוניות \(beltLine), אבל במסכי הנושאים תמצא את כל ההגנות בחלוקה לפי נושאים ותתי נושאים.\n"
        }

        if looksLikeExplanationQuestion {
            if let officialAnswer =
                AssistantExerciseExplanationKnowledge.answer(
                    question: question,
                    preferredBelt: beltEnum,
                    searchEngine: p.searchEngine
                ),
               !officialAnswer.trimmingCharacters(
                    in: .whitespacesAndNewlines
               ).isEmpty {

                return officialAnswer
            }

            let exerciseName = extractExerciseNameFromText(
                question
            )

            if !exerciseName.isEmpty,
               let getExerciseExplanation =
                    p.getExerciseExplanation,
               let directExplanation =
                    getExerciseExplanation(exerciseName)?
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ),
               !directExplanation.isEmpty,
               !looksLikeMissingExplanation(
                    directExplanation
               ) {

                return """
                ההסבר לתרגיל "\(exerciseName)":

                \(directExplanation)
                """
            }

            return """
            לא מצאתי הסבר רשמי מדויק לתרגיל הזה.

            נסה לומר את שם התרגיל המדויק כפי שהוא מופיע במסכי התרגילים, ובמידת האפשר ציין גם חגורה.
            """
        }

        if (text.contains("רשימה") || text.contains("תן לי")) &&
            (text.contains("תרגיל") || text.contains("תרגילים") || text.contains("חימום")) {
            let hits = p.searchEngine.search(query: question, belt: beltEnum)
            if !hits.isEmpty {
                let beltStr = beltDisplayName.map { " לחגורה \($0)" } ?? ""
                let listText = AssistantKmiMaterialKnowledge.formatHitsAsExerciseList(hits)
                return """
                מצאתי עבורך תרגילים\(beltStr) שקשורים לשאלה שלך:

                \(listText)

                את כל התרגילים ניתן לראות במסכי הנושאים של החגורה.
                """
            }

            let beltStr = beltDisplayName.map { " לחגורה \($0)" } ?? ""
            return """
            לא הצלחתי למצוא תרגילים מדויקים\(beltStr) לשאלה הזאת.
            נסה לנסח מחדש עם שם נושא (למשל "בעיטות", "הגנות חיצוניות") או שם תרגיל מדויק.
            """
        }

        if text.contains("מה כדאי") || text.contains("מה לתרגל") || text.contains("להתקדם") || text.contains("איך להשתפר") {
            let hits = p.searchEngine.search(query: question, belt: beltEnum)

            if !hits.isEmpty {
                let beltLine = beltDisplayName.map { "לחגורה \($0) " } ?? ""
                let listText = AssistantKmiMaterialKnowledge.formatHitsAsExerciseList(hits, maxItems: 5)
                return """
                כדי להתקדם \(beltLine)מומלץ לעבוד באופן עקבי על התרגילים הבאים מתוך החומר הרשמי:

                \(listText)

                בחר 3–5 תרגילים מהרשימה, תרגל אותם כמעט בכל אימון, ועבור למסכים המתאימים באפליקציה כדי לראות פירוט ותמונות.
                """
            }

            return "לא מצאתי תרגילים מדויקים לשאלה הזאת, אבל כללית כדאי לבחור 3–5 תרגילים בסיסיים מהחגורה שלך ולתרגל אותם כמעט בכל אימון.\n"
        }

        if text.contains("הסבר") ||
            text.contains("מה זה") ||
            text.contains("תסביר") {

            if let officialAnswer =
                AssistantExerciseExplanationKnowledge.answer(
                    question: question,
                    preferredBelt: beltEnum,
                    searchEngine: p.searchEngine
                ) {
                return officialAnswer
            }

            return """
            לא מצאתי הסבר רשמי מדויק לשאלה הזאת.

            נסה לציין את שם התרגיל כפי שהוא מופיע בחומר הרשמי.
            """
        }

        let defaultHits = p.searchEngine.search(query: question, belt: beltEnum)
        if !defaultHits.isEmpty {
            let listText = AssistantKmiMaterialKnowledge.formatHitsAsExerciseList(defaultHits)
            let beltLine = beltDisplayName.map { " לחגורה \($0) " } ?? ""
            return """
            כשמחפשים מתוך חומר התרגילים שלך\(beltLine)מצאתי כמה תרגילים:

            \(listText)

            אם תרצה, אפשר לבקש הסבר מפורט על אחד מהם בשם המדויק שלו.
            """
        }

        return """
        אני יכול לעזור לך עם תרגילים אמיתיים מתוך החומר של ק.מ.י – לפי חגורה, נושא ותתי נושאים.

        אפשר לשאול למשל:
        • "תן לי רשימה של תרגילי חימום לחגורה צהובה"
        • "מה כדאי לי לתרגל כדי להשתפר בבעיטות?"
        • "תן את כל ההגנות החיצוניות בחגורה כתומה"
        • "תן את ההסבר לתרגיל בעיטת מיאגרי קדמית"
        """
    }

    private static func looksLikeMissingExplanation(
        _ value: String
    ) -> Bool {
        let clean = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return clean.isEmpty ||
            clean.hasPrefix("הסבר מפורט על") ||
            clean.hasPrefix("אין כרגע") ||
            clean.hasPrefix("Detailed explanation for:") ||
            clean.hasPrefix(
                "There is currently no explanation"
            )
    }
    
    private static func extractExerciseNameFromText(
        _ value: String
    ) -> String {
        var text = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let requestPrefixes = [
            "תתן בבקשה את ההסבר על",
            "תן בבקשה הסבר על",
            "תן לי בבקשה הסבר על",
            "תסביר בבקשה על",
            "תן לי הסבר על",
            "תני לי הסבר על",
            "אפשר הסבר על",
            "תסביר לי על",
            "תסביר על",
            "הסבר על תרגיל",
            "הסבר לתרגיל",
            "הסבר תרגיל",
            "הסבר על",
            "איך מבצעים את",
            "איך מבצעים",
            "איך עושים את",
            "איך עושים"
        ]

        for prefix in requestPrefixes.sorted(
            by: { $0.count > $1.count }
        ) {
            guard text.hasPrefix(prefix) else {
                continue
            }

            text = String(
                text.dropFirst(prefix.count)
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            break
        }

        if text.hasPrefix("תרגיל ") {
            text = String(
                text.dropFirst("תרגיל ".count)
            )
        }

        text = text
            .replacingOccurrences(of: "\"", with: " ")
            .replacingOccurrences(of: "״", with: " ")
            .replacingOccurrences(of: "?", with: " ")
            .replacingOccurrences(of: "!", with: " ")
            .replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let trailingWords = [
            "הזה",
            "הזאת",
            "בבקשה",
            "תודה"
        ]

        for word in trailingWords {
            if text.hasSuffix(" \(word)") {
                text = String(
                    text.dropLast(word.count + 1)
                )
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
        }

        return text
    }
    
    private static func currentLanguageIsEnglish() -> Bool {
        let defaults = UserDefaults.standard

        let values = [
            defaults.string(
                forKey: "kmi_app_language"
            ) ?? "",
            defaults.string(
                forKey: "selected_language_code"
            ) ?? "",
            defaults.string(
                forKey: "app_language"
            ) ?? "",
            defaults.string(
                forKey: "initial_language_code"
            ) ?? ""
        ]
        .map {
            $0.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()
        }

        return values.contains("en") ||
            values.contains("english")
    }
}
