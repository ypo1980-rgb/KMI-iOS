import Foundation
import Shared

enum AssistantExerciseSearchFallback {
    static func buildBestHitExplanation(
        hits: [AssistantSearchHit],
        preferredBelt: Belt?
    ) -> String? {
        guard let first = hits.first else { return nil }

        let appBelt = first.belt
        let topic = first.topic
        let rawItem = first.item ?? ""
        let explanation = findExplanationForHit(belt: appBelt, rawItem: rawItem, topic: topic)
        let display = displayName(for: rawItem).isEmpty ? rawItem : displayName(for: rawItem)

        return "ההסבר לתרגיל \"\(display)\":\n\n\(explanation)"
    }

    private static func findExplanationForHit(
        belt: Belt,
        rawItem: String,
        topic: String
    ) -> String {
        let display = displayName(for: rawItem).isEmpty ? rawItem : displayName(for: rawItem)

        func clean(_ value: String) -> String {
            value
                .replacingOccurrences(of: "–", with: "-")
                .replacingOccurrences(of: "־", with: "-")
                .replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let candidates = Array(
            Set([
                rawItem,
                display,
                clean(display),
                clean(display.components(separatedBy: "(").first ?? display)
            ])
        )

        for candidate in candidates {
            let got = Explanations().get(belt: belt, item: candidate).trimmingCharacters(in: .whitespacesAndNewlines)
            if !got.isEmpty && !got.hasPrefix("הסבר מפורט על") && !got.hasPrefix("אין כרגע") {
                return got.contains("::") ? String(got.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false).last ?? Substring(got)).trimmingCharacters(in: .whitespacesAndNewlines) : got
            }
        }

        return "אין כרגע הסבר מפורט לתרגיל הזה במאגר."
    }

    private static func displayName(for rawItem: String) -> String {
        if rawItem.contains("::") {
            let parts = rawItem.split(separator: "::").map(String.init)
            if parts.count == 2 {
                let a = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let b = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let latin = try? NSRegularExpression(pattern: "^[a-zA-Z0-9_\\-]+$")
                let aIsTag = latin?.firstMatch(in: a, range: NSRange(location: 0, length: a.utf16.count)) != nil
                let bIsTag = latin?.firstMatch(in: b, range: NSRange(location: 0, length: b.utf16.count)) != nil
                if aIsTag && !bIsTag { return b }
                if bIsTag && !aIsTag { return a }
                return b
            }
        }
        return rawItem.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
