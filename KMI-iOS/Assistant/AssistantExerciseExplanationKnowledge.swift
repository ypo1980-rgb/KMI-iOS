import Foundation
import Shared

enum AssistantExerciseExplanationKnowledge {
    struct ExplainRequest: Hashable {
        let rawQuestion: String
        let exerciseName: String
        let belt: Belt?
    }

    private static let explainTriggers: [String] = [
        "תסביר בבקשה על", "איך עושים",
        "תן בבקשה הסבר על",
        "תתן בבקשה את ההסבר על",
        "תתן הסבר", "תן לי בבקשה הסבר",
        "הסבר", "תסביר", "תסבירי", "תסביר לי",
        "תן הסבר", "תני הסבר", "תן לי הסבר", "תני לי הסבר",
        "תן פירוט", "תני פירוט", "פירוט",
        "איך עושים", "איך לעשות", "איך לבצע", "איך מבצעים", "איך לבצע את",
        "שלב שלב", "צעד צעד", "הדרכה", "הדריך",
        "מה זה", "מהו", "מה היא", "מה פירוש", "מה המשמעות",
        "תן דוגמה", "תני דוגמה", "דוגמה", "דוגמא",
        "טיפים", "דגשים", "מה חשוב", "מה לשים לב"
    ]

    private static let mentionsExerciseTokens: [String] = [
        "תרגיל", "תרגילים", "טכניקה", "טכניקת",
        "בעיטה", "אגרוף", "הגנה", "חניקה",
        "הטלה", "בריח", "שחרור", "אחיזה"
    ]

    private static let tailNoise: [String] = [
        "הזה", "הזאת", "בבקשה", "תודה",
        "תן", "תני", "הסבר", "פירוט",
        "שלב", "איך", "מה"
    ]

    static func answer(
        question: String,
        preferredBelt: Belt? = nil,
        searchEngine: AssistantSearchEngine
    ) -> String? {
        guard let req = tryParse(question: question, preferredBelt: preferredBelt) else { return nil }
        return answer(req: req, searchEngine: searchEngine)
    }

    static func answer(
        req: ExplainRequest,
        searchEngine: AssistantSearchEngine
    ) -> String? {
        let primaryBelt = req.belt ?? .yellow

        if let direct = findExplanationAcrossBelts(
            primaryBelt: primaryBelt,
            exerciseName: req.exerciseName,
            allowAllBelts: req.belt == nil
        ) {
            let cleaned = cleanExplanation(direct.1)
            return "ההסבר לתרגיל \"\(req.exerciseName)\":\n\n\(cleaned)\n\nהאם אני יכול לעזור לך בעוד משהו?"
        }

        let best = searchEngine.search(query: req.rawQuestion, belt: primaryBelt).first
        if let best, let rawItem = best.item {
            let displayKey = canonToExplanationKey(rawItem)
            if let exp = findExplanationAcrossBelts(
                primaryBelt: best.belt,
                exerciseName: displayKey,
                allowAllBelts: false
            )?.1 {
                let cleaned = cleanExplanation(exp)
                return "ההסבר לתרגיל \"\(displayKey)\":\n\n\(cleaned)\n\nהאם אני יכול לעזור לך בעוד משהו?"
            }
        }

        return nil
    }

    static func tryParse(question: String, preferredBelt: Belt? = nil) -> ExplainRequest? {
        let norm = HebrewNormalize.normalize(question)

        let hasTrigger = explainTriggers.contains { trig in
            norm.hasPrefix(trig) || " \(norm) ".contains(" \(trig) ")
        }

        guard hasTrigger else { return nil }

        guard let name = extractExerciseName(original: question, normalized: norm), name.count >= 2 else {
            return nil
        }

        return ExplainRequest(
            rawQuestion: question,
            exerciseName: name,
            belt: preferredBelt
        )
    }

    private static func findExplanationAcrossBelts(
        primaryBelt: Belt,
        exerciseName: String,
        allowAllBelts: Bool
    ) -> (Belt, String)? {
        func tryGet(belt: Belt, name: String) -> String? {
            let value = Explanations().get(belt: belt, item: name).trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty || looksLikeNoData(value) { return nil }
            return value
        }

        let candidates = Array(Set([
            exerciseName.trimmingCharacters(in: .whitespacesAndNewlines),
            exerciseName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "–", with: "-")
                .replacingOccurrences(of: "—", with: "-")
                .replacingOccurrences(of: "  ", with: " ")
        ]))

        for candidate in candidates {
            if let value = tryGet(belt: primaryBelt, name: candidate) {
                return (primaryBelt, value)
            }
        }

        guard allowAllBelts else { return nil }

        let beltsToTry: [Belt] = [.green, .orange, .yellow, .blue, .brown, .black]
        for belt in beltsToTry where belt != primaryBelt {
            for candidate in candidates {
                if let value = tryGet(belt: belt, name: candidate) {
                    return (belt, value)
                }
            }
        }

        return nil
    }

    private static func canonToExplanationKey(_ rawItem: String) -> String {
        let value = rawItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.contains("::") else { return value }

        let parts = value.components(separatedBy: "::")
        guard parts.count == 2 else { return parts.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? value }

        let a = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let b = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

        func isLatinTag(_ s: String) -> Bool {
            s.range(of: "^[a-z0-9_\\-]+$", options: .regularExpression) != nil
        }

        if isLatinTag(a) && !isLatinTag(b) { return b }
        if isLatinTag(b) && !isLatinTag(a) { return a }
        return b
    }

    private static func extractExerciseName(original: String, normalized: String) -> String? {
        if let quoted = extractQuoted(original) {
            let cleaned = cleanName(quoted)
            if !cleaned.isEmpty { return cleaned }
        }

        if let trigger = explainTriggers.sorted(by: { $0.count > $1.count }).first(where: { normalized.hasPrefix($0) }) {
            let candidate = cleanName(String(normalized.dropFirst(trigger.count)).trimmingCharacters(in: .whitespacesAndNewlines))
            if !candidate.isEmpty { return candidate }
        }

        let candidates = [
            afterToken(normalized, token: "תרגיל"),
            afterToken(normalized, token: "טכניקה"),
            afterToken(normalized, token: "טכניקת"),
            afterToken(normalized, token: "הסבר על"),
            afterToken(normalized, token: "הסבר ל"),
            afterColon(original)
        ]
            .compactMap { $0 }
            .map(cleanName)
            .filter { !$0.isEmpty }

        if let best = candidates.max(by: { $0.count < $1.count }) {
            return best
        }

        if mentionsExerciseTokens.contains(where: { normalized.contains($0) }) {
            let cleaned = cleanName(normalized)
            if cleaned.count >= 2 { return cleaned }
        }

        return nil
    }

    private static func afterToken(_ normalized: String, token: String) -> String? {
        guard let range = normalized.range(of: token) else { return nil }
        return String(normalized[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func afterColon(_ original: String) -> String? {
        guard let idx = original.firstIndex(of: ":") else { return nil }
        return String(original[original.index(after: idx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanName(_ value: String) -> String {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "?", with: " ")
            .replacingOccurrences(of: "!", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        for prefix in ["את", "על", "של"] where text.hasPrefix(prefix) {
            text = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        for tail in tailNoise {
            if text == tail { text = "" }
            if text.hasSuffix(" \(tail)") {
                text = String(text.dropLast(tail.count + 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return text
    }

    private static func extractQuoted(_ original: String) -> String? {
        let quotes: [Character] = ["\"", "״"]
        for q in quotes {
            guard let start = original.firstIndex(of: q) else { continue }
            let rest = original.index(after: start)
            guard let end = original[rest...].firstIndex(of: q) else { continue }
            return String(original[rest..<end])
        }
        return nil
    }

    private static func looksLikeNoData(_ value: String) -> Bool {
        value.hasPrefix("הסבר מפורט על") || value.hasPrefix("אין כרגע")
    }

    private static func cleanExplanation(_ value: String) -> String {
        if let range = value.range(of: "::") {
            return String(value[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
