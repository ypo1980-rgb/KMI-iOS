import Foundation
import Shared

struct AssistantMaterialAnswer: Hashable {
    let text: String
    let hits: [AssistantSearchHit]

    init(
        text: String,
        hits: [AssistantSearchHit] = []
    ) {
        self.text = text
        self.hits = hits
    }
}

enum AssistantKmiMaterialKnowledge {

    private static var isEnglish: Bool {
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

    static func searchHits(
        query: String,
        preferredBelt: Belt?,
        searchEngine: AssistantSearchEngine
    ) -> [AssistantSearchHit] {
        let cleanQuery = cleanMaterialQuery(query)

        guard !cleanQuery.isEmpty else {
            return []
        }

        return searchEngine.search(
            query: cleanQuery,
            belt: preferredBelt
        )
    }

    private static func cleanMaterialQuery(
        _ value: String
    ) -> String {
        var result = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let requestPhrases = [
            "תן לי רשימה של",
            "תני לי רשימה של",
            "תן רשימה של",
            "תני רשימה של",
            "תראה לי את",
            "תראי לי את",
            "תמצא לי את",
            "תחפש לי את",
            "חפש בחומר",
            "חפש את",
            "רשימה של",
            "כל התרגילים של",
            "כל התרגילים בנושא",
            "תרגילים בנושא",
            "תרגיל בנושא",
            "בחומר ק.מ.י",
            "בחומר קמי",
            "show me",
            "find",
            "search for",
            "list all",
            "give me a list of",
            "exercises about"
        ]

        for phrase in requestPhrases.sorted(
            by: { $0.count > $1.count }
        ) {
            result = result.replacingOccurrences(
                of: phrase,
                with: " ",
                options: .caseInsensitive
            )
        }

        result = result
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

        return result
    }

    static func formatHitsAsExerciseList(
        _ hits: [AssistantSearchHit],
        maxItems: Int = 8
    ) -> String {
        guard !hits.isEmpty,
              maxItems > 0 else {
            return ""
        }

        var seen = Set<String>()
        var lines: [String] = []

        for hit in hits {
            let topicTitle = hit.topic.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            let rawItem = hit.item ?? ""
            let formattedName = displayName(for: rawItem)

            let exerciseName = formattedName.isEmpty
                ? topicTitle
                : formattedName

            guard !exerciseName.isEmpty else {
                continue
            }

            let dedupeKey = [
                hit.belt.id,
                normalizedText(topicTitle),
                normalizedText(exerciseName)
            ]
            .joined(separator: "|")

            guard seen.insert(dedupeKey).inserted else {
                continue
            }

            let beltName =
                AssistantBeltDetector.localizedName(
                    hit.belt,
                    isEnglish: isEnglish
                )

            if isEnglish {
                lines.append(
                    "• \(exerciseName) " +
                    "(\(topicTitle) – \(beltName) belt)"
                )
            } else {
                lines.append(
                    "• \(exerciseName) " +
                    "(\(topicTitle) – חגורה \(beltName))"
                )
            }

            if lines.count >= maxItems {
                break
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func normalizedText(
        _ value: String
    ) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "־", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
    }

    static func answer(
        question: String,
        preferredBelt: Belt? = nil,
        searchEngine: AssistantSearchEngine
    ) -> AssistantMaterialAnswer? {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return nil }

        if looksLikeExplainRequest(q) {
            let hint = """
            נשמע שביקשת הסבר לתרגיל.

            כדי לקבל הסבר מדויק, עבור למצב "מידע / הסבר על תרגיל" ואז כתוב:
            • "תן הסבר על- <שם תרגיל>"

            אם תרצה, תכתוב כאן רק את שם התרגיל ואני אחפש אותו בחומר ק.מ.י.
            """
            return AssistantMaterialAnswer(text: hint, hits: [])
        }

        let hits = searchHits(query: q, preferredBelt: preferredBelt, searchEngine: searchEngine)

        if hits.isEmpty {
            let beltLine = preferredBelt.map { " לחגורה \($0.heb)" } ?? ""
            let text = """
            לא מצאתי בחומר ק.מ.י תוצאות שמתאימות לבקשה שלך\(beltLine).

            נסה ניסוח קצר יותר, למשל:
            • "בעיטות" / "מרפקים" / "הגנות חיצוניות"
            • "רשימה של שחרורים מחביקות"
            • "תרגיל בעיטת מיאגרי"
            """
            return AssistantMaterialAnswer(text: text, hits: [])
        }

        let beltLine = preferredBelt.map { " לחגורה \($0.heb)" } ?? ""
        let listText = formatHitsAsExerciseList(hits, maxItems: 10)

        let text = """
        מצאתי בחומר ק.מ.י\(beltLine) תוצאות שקשורות לבקשה שלך:

        \(listText)

        אם תרצה הסבר, כתוב:
        • "תן הסבר ל- <שם תרגיל>"
        """

        return AssistantMaterialAnswer(text: text, hits: hits)
    }

    private static func looksLikeExplainRequest(_ text: String) -> Bool {
        let low = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let explainTriggers = [
            "הסבר", "תסביר", "תסבירי", "תן הסבר", "תני הסבר",
            "איך עושים", "איך לבצע", "איך מבצעים", "שלב שלב", "צעד צעד",
            "דגשים", "טיפים", "פירוט"
        ]
        return explainTriggers.contains(where: { low.contains($0) })
    }

    private static func displayName(for rawItem: String) -> String {
        if rawItem.contains("::") {
            let parts = rawItem.components(separatedBy: "::")
            if parts.count == 2 {
                let a = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let b = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                if a.range(of: "^[a-zA-Z0-9_\\-]+$", options: .regularExpression) != nil,
                   b.range(of: "^[a-zA-Z0-9_\\-]+$", options: .regularExpression) == nil {
                    return b
                }
                if b.range(of: "^[a-zA-Z0-9_\\-]+$", options: .regularExpression) != nil,
                   a.range(of: "^[a-zA-Z0-9_\\-]+$", options: .regularExpression) == nil {
                    return a
                }
                return b
            }
        }
        return rawItem.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
