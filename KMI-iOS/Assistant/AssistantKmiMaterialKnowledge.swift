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
    static func searchHits(
        query: String,
        preferredBelt: Belt?,
        searchEngine: AssistantSearchEngine
    ) -> [AssistantSearchHit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return searchEngine.search(query: q, belt: preferredBelt)
    }

    static func formatHitsAsExerciseList(
        _ hits: [AssistantSearchHit],
        maxItems: Int = 8
    ) -> String {
        guard !hits.isEmpty else { return "" }

        return hits.prefix(maxItems).map { hit in
            let topicTitle = hit.topic
            let rawItem = hit.item ?? ""
            let displayName = displayName(for: rawItem).isEmpty ? topicTitle : displayName(for: rawItem)
            return "• \(displayName) (\(topicTitle) – חגורה \(hit.belt.heb))"
        }.joined(separator: "\n")
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
