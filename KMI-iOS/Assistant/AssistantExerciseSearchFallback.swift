import Foundation
import Shared

enum AssistantExerciseSearchFallback {
    static func buildBestHitExplanation(
        hits: [AssistantSearchHit],
        preferredBelt: Belt?
    ) -> String? {
        guard !hits.isEmpty else {
            return nil
        }

        let selectedHit: AssistantSearchHit?

        if let preferredBelt {
            /*
             * אם המשתמש ציין חגורה, אסור לבחור תוצאה
             * מחגורה אחרת רק משום שהיא הראשונה ברשימה.
             */
            selectedHit = hits.first {
                $0.belt == preferredBelt
            }
        } else {
            selectedHit = hits.first
        }

        guard let selectedHit,
              let rawItem = selectedHit.item?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
              !rawItem.isEmpty else {
            return nil
        }

        guard let explanation = findExplanationForHit(
            belt: selectedHit.belt,
            rawItem: rawItem
        ) else {
            /*
             * אין מחזור לתוצאה דומה אחרת.
             * אם לתוצאה המדורגת אין הסבר רשמי,
             * מחזירים nil למנוע הראשי.
             */
            return nil
        }

        let formattedName = displayName(for: rawItem)

        let display = formattedName.isEmpty
            ? rawItem
            : formattedName

        return """
        ההסבר לתרגיל "\(display)":

        \(explanation)
        """
    }

    private static func findExplanationForHit(
        belt: Belt,
        rawItem: String
    ) -> String? {
        let formattedName = displayName(for: rawItem)

        let display = formattedName.isEmpty
            ? rawItem
            : formattedName

        func normalizedCandidate(
            _ value: String
        ) -> String {
            value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "־", with: "-")
                .replacingOccurrences(of: "–", with: "-")
                .replacingOccurrences(of: "—", with: "-")
                .replacingOccurrences(
                    of: #"\s+"#,
                    with: " ",
                    options: .regularExpression
                )
        }

        var candidates: [String] = []

        func appendCandidate(
            _ value: String
        ) {
            let clean = normalizedCandidate(value)

            guard !clean.isEmpty,
                  !candidates.contains(clean) else {
                return
            }

            candidates.append(clean)
        }

        /*
         * הסדר חשוב:
         * קודם המפתח המקורי מהקטלוג,
         * אחר כך שם התצוגה,
         * ורק לבסוף שם ללא הערה בסוגריים.
         */
        appendCandidate(rawItem)
        appendCandidate(display)

        let withoutParentheses = display
            .components(separatedBy: "(")
            .first ?? display

        appendCandidate(withoutParentheses)

        for candidate in candidates {
            let rawExplanation = Explanations()
                .get(
                    belt: belt,
                    item: candidate
                )
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            guard !looksLikeMissingExplanation(
                rawExplanation
            ) else {
                continue
            }

            let cleanExplanation =
                stripInternalPrefix(rawExplanation)

            guard !cleanExplanation.isEmpty,
                  !looksLikeMissingExplanation(
                    cleanExplanation
                  ) else {
                continue
            }

            return cleanExplanation
        }

        return nil
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

    private static func stripInternalPrefix(
        _ value: String
    ) -> String {
        guard let range = value.range(of: "::") else {
            return sanitizeMarkup(value)
        }

        let content = String(
            value[range.upperBound...]
        )

        return sanitizeMarkup(content)
    }

    private static func sanitizeMarkup(
        _ value: String
    ) -> String {
        var result = value

        let patterns = [
            #"(?i)\[\[\s*/?\s*RED_BOLD\s*\]\]"#,
            #"(?i)\[\s*/?\s*RED_BOLD\s*\]"#,
            #"(?i)\[\[\s*/?\s*BOLD\s*\]\]"#,
            #"(?i)\[\s*/?\s*BOLD\s*\]"#,
            #"(?i)\[\[\s*/?\s*RED\s*\]\]"#,
            #"(?i)\[\s*/?\s*RED\s*\]"#
        ]

        for pattern in patterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }

        return result
            .replacingOccurrences(
                of: #"[ \t]+\n"#,
                with: "\n",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\n{3,}"#,
                with: "\n\n",
                options: .regularExpression
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
    }

    private static func displayName(
        for rawItem: String
    ) -> String {
        let clean = rawItem.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard clean.contains("::") else {
            return clean
        }

        let parts = clean.components(
            separatedBy: "::"
        )

        guard parts.count == 2 else {
            return parts.last?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                ) ?? clean
        }

        let first = parts[0].trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let second = parts[1].trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        func isInternalIdentifier(
            _ value: String
        ) -> Bool {
            value.range(
                of: #"^[a-zA-Z0-9_\-]+$"#,
                options: .regularExpression
            ) != nil
        }

        let firstIsIdentifier =
            isInternalIdentifier(first)

        let secondIsIdentifier =
            isInternalIdentifier(second)

        if firstIsIdentifier,
           !secondIsIdentifier {
            return second
        }

        if secondIsIdentifier,
           !firstIsIdentifier {
            return first
        }

        return second.isEmpty ? first : second
    }
}
