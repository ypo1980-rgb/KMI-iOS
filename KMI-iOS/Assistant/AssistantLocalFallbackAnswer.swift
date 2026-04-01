import Foundation
import Shared

enum AssistantLocalFallbackAnswer {
    struct Params {
        let question: String
        let contextLabel: String?
        let getExternalDefenses: ((Belt) -> [String])?
        let getExerciseExplanation: ((String) -> String?)?
        let getUpcomingTrainings: (() -> [TrainingRow])?
        let searchEngine: AssistantSearchEngine
    }

    static func answer(_ p: Params) -> String {
        let question = p.question
        let text = question.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let beltEnum = AssistantBeltDetector.detect(question)
        let beltHeb = beltEnum.map(AssistantBeltDetector.hebrewName)

        let looksLikeExplanationQuestion =
            (text.contains("הסבר") || text.contains("תסביר") || text.contains("פירוט") || text.contains("איך עושים") || text.contains("איך מבצעים")) &&
            !(text.contains("אימון הקרוב") || text.contains("האימון הקרוב") || text.contains("אימון הבא") || text.contains("האימון הבא") ||
              text.contains("אימונים קרובים") || text.contains("האימונים הקרובים") || text.contains("לוח אימונים") ||
              text.contains("לו\"ז") || text.contains("לוז"))

        let trainingKeywords = [
            "אימון", "אימונים", "אימון הקרוב", "האימון הקרוב", "אימון הבא", "האימון הבא",
            "האימונים הקרובים", "האימונים הבאים", "לוח אימונים", "לו\"ז", "לוז",
            "שעות אימון", "שעת אימון", "קבוצת אימון", "קבוצה שלי"
        ]

        let looksLikeTrainingQuestion = trainingKeywords.contains(where: { text.contains($0) })

        if let getUpcomingTrainings = p.getUpcomingTrainings,
           looksLikeTrainingQuestion && !looksLikeExplanationQuestion {
            let upcoming = getUpcomingTrainings()
            if !upcoming.isEmpty {
                let listText = upcoming.map(formatUpcomingTraining).joined(separator: "\n\n")
                return """
                הנה האימונים הקרובים שלך לפי הסניף והקבוצה שנבחרו באפליקציה:

                \(listText)

                אם תרצה לראות אימונים מסניף אחר – שנה סניף וקבוצה במסך הרישום ואז שאל שוב.
                """
            }

            return """
            לא מצאתי אצלך כרגע אימונים קרובים לפי הסניף והקבוצה שנבחרו.

            בדוק במסך הרישום שבחרת סניף וקבוצת אימון, ואז נסה לשאול שוב "מה האימון הקרוב שלי?"
            """
        }

        if text.contains("הגנות חיצוניות") {
            if let beltEnum, let getExternalDefenses = p.getExternalDefenses {
                let list = getExternalDefenses(beltEnum)
                if !list.isEmpty {
                    let titleBelt = beltHeb ?? AssistantBeltDetector.hebrewName(beltEnum)
                    let listText = list.map { "• \($0)" }.joined(separator: "\n")
                    return "הגנות חיצוניות בחגורה \(titleBelt):\n\n\(listText)\n"
                }
            }

            let beltLine = beltHeb.map { "בחגורה \($0)" } ?? "לרמה שלך"
            return "כרגע לא מצאתי רשימה מדויקת של הגנות חיצוניות \(beltLine), אבל במסכי הנושאים תמצא את כל ההגנות בחלוקה לפי נושאים ותתי נושאים.\n"
        }

        if (text.contains("הסבר") || text.contains("תסביר")) && text.contains("תרגיל") {
            let exName = extractExerciseNameFromText(text)

            if !exName.isEmpty, let getExerciseExplanation = p.getExerciseExplanation, let real = getExerciseExplanation(exName), !real.isEmpty {
                return "ההסבר לתרגיל \"\(exName)\":\n\n\(real)\n"
            }

            let hits = p.searchEngine.search(query: question, belt: beltEnum)
            if let best = AssistantExerciseSearchFallback.buildBestHitExplanation(hits: hits, preferredBelt: beltEnum) {
                return best
            }

            let header = exName.isEmpty
                ? "הנה עקרונות כלליים לביצוע תרגיל:\n\n"
                : "לא מצאתי הסבר מדויק לתרגיל \"\(exName)\".\nהנה עקרונות כלליים לביצוע תרגיל:\n\n"

            return header + """
            1. עמידת מוצא: עמוד יציב, ברכיים מעט כפופות, גב ישר ומבט קדימה.
            2. בצע את התנועה לאט כמה פעמים, בלי כוח, כדי להבין את המסלול והכיוון.
            3. יד השמירה נשארת גבוהה ולא נופלת בזמן הביצוע.
            4. לא לנעול מרפקים או ברכיים – התנועה זורמת ורכה.
            5. אחרי שהטכניקה נקייה, אפשר להוסיף מהירות ועוצמה בהדרגה.
            """
        }

        if (text.contains("רשימה") || text.contains("תן לי")) &&
            (text.contains("תרגיל") || text.contains("תרגילים") || text.contains("חימום")) {
            let hits = p.searchEngine.search(query: question, belt: beltEnum)
            if !hits.isEmpty {
                let beltStr = beltHeb.map { " לחגורה \($0)" } ?? ""
                let listText = AssistantKmiMaterialKnowledge.formatHitsAsExerciseList(hits)
                return """
                מצאתי עבורך תרגילים\(beltStr) שקשורים לשאלה שלך:

                \(listText)

                את כל התרגילים ניתן לראות במסכי הנושאים של החגורה.
                """
            }

            let beltStr = beltHeb.map { " לחגורה \($0)" } ?? ""
            return """
            לא הצלחתי למצוא תרגילים מדויקים\(beltStr) לשאלה הזאת.
            נסה לנסח מחדש עם שם נושא (למשל "בעיטות", "הגנות חיצוניות") או שם תרגיל מדויק.
            """
        }

        if text.contains("מה כדאי") || text.contains("מה לתרגל") || text.contains("להתקדם") || text.contains("איך להשתפר") {
            let hits = p.searchEngine.search(query: question, belt: beltEnum)

            if !hits.isEmpty {
                let beltLine = beltHeb.map { "לחגורה \($0) " } ?? ""
                let listText = AssistantKmiMaterialKnowledge.formatHitsAsExerciseList(hits, maxItems: 5)
                return """
                כדי להתקדם \(beltLine)מומלץ לעבוד באופן עקבי על התרגילים הבאים מתוך החומר הרשמי:

                \(listText)

                בחר 3–5 תרגילים מהרשימה, תרגל אותם כמעט בכל אימון, ועבור למסכים המתאימים באפליקציה כדי לראות פירוט ותמונות.
                """
            }

            return "לא מצאתי תרגילים מדויקים לשאלה הזאת, אבל כללית כדאי לבחור 3–5 תרגילים בסיסיים מהחגורה שלך ולתרגל אותם כמעט בכל אימון.\n"
        }

        if text.contains("הסבר") || text.contains("מה זה") || text.contains("תסביר") {
            let hits = p.searchEngine.search(query: question, belt: beltEnum)
            if let best = AssistantExerciseSearchFallback.buildBestHitExplanation(hits: hits, preferredBelt: beltEnum) {
                return best
            }

            return """
            כדי לקבל הסבר מדויק לתרגיל ספציפי, חפש אותו במסכי התרגילים ולחץ על אייקון ה־ℹ️ ליד השם.
            באופן כללי חשוב לשים לב ל:
            • עמידת מוצא יציבה ונוחה.
            • נשימה רגועה לאורך כל התרגיל.
            • תנועה זורמת בלי לנעול מפרקים.
            • חזרה מהירה לעמדת הגנה בסיום כל תנועה.
            """
        }

        if text.contains("אימון הקרוב") ||
            text.contains("האימון הקרוב") ||
            text.contains("האימון הבא") ||
            text.contains("האימונים הקרובים") ||
            text.contains("האימונים הבאים") ||
            text.contains("אימונים קרובים") {
            if let getUpcomingTrainings = p.getUpcomingTrainings {
                let upcoming = getUpcomingTrainings()
                if !upcoming.isEmpty {
                    let listText = upcoming.map(formatUpcomingTraining).joined(separator: "\n\n")
                    return """
                    האימונים הקרובים שלך לפי הסניף והקבוצה שנבחרו:

                    \(listText)

                    אם תרצה לבדוק מרכז אחר – שנה סניף/קבוצה במסך הרישום.
                    """
                }
            }

            return """
            כרגע לא מצאתי אימונים קרובים בפרטי המשתמש שלך.
            ודא שבחרת סניף וקבוצת אימון במסך הרישום, ואז נסה שוב לשאול "מה האימון הקרוב שלי?"
            """
        }

        let defaultHits = p.searchEngine.search(query: question, belt: beltEnum)
        if !defaultHits.isEmpty {
            let listText = AssistantKmiMaterialKnowledge.formatHitsAsExerciseList(defaultHits)
            let beltLine = beltHeb.map { " לחגורה \($0) " } ?? ""
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

    private static func extractExerciseNameFromText(_ t: String) -> String {
        let cleaned = t
            .replacingOccurrences(of: "על תרגיל", with: "תרגיל")
            .replacingOccurrences(of: "על", with: "")

        guard let range = cleaned.range(of: "תרגיל") else { return "" }

        return String(cleaned[range.upperBound...])
            .replacingOccurrences(of: "הזה", with: "")
            .replacingOccurrences(of: "הזאת", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func formatUpcomingTraining(_ row: TrainingRow) -> String {
        """
        סניף: \(row.branchName)
        קבוצה: \(row.groupName)
        יום: \(row.dayName)
        שעה: \(row.timeRange)
        מקום: \(row.location)
        מאמן: \(row.coachName)
        """
    }
}
