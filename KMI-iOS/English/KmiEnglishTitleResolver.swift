import Foundation

enum KmiEnglishTitleResolver {

    static func title(
        for value: String,
        isEnglish: Bool
    ) -> String {
        guard isEnglish else {
            return value
        }

        return englishTitle(for: value) ?? value
    }

    static func englishTitle(for value: String) -> String? {
        let candidates = normalizedCandidates(for: value)

        for candidate in candidates {
            if let title = ExerciseTitlesEnAliases.map[candidate] {
                return title
            }

            if let title = ExerciseTitlesEnItems.map[candidate] {
                return title
            }

            if let title = ExerciseTitlesEnTopics.map[candidate] {
                return title
            }
        }

        return nil
    }

    static func hasEnglishTitle(for value: String) -> Bool {
        englishTitle(for: value) != nil
    }

    private static func normalizedCandidates(for value: String) -> [String] {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        let simpleDash = trimmed
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")

        let longDash = trimmed
            .replacingOccurrences(of: "-", with: "–")
            .replacingOccurrences(of: "—", with: "–")

        let normalizedSpaces = trimmed
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let neckWithVav = trimmed.replacingOccurrences(of: "צואר", with: "צוואר")
        let neckWithoutVav = trimmed.replacingOccurrences(of: "צוואר", with: "צואר")

        let simpleDashNeckWithVav = simpleDash.replacingOccurrences(of: "צואר", with: "צוואר")
        let simpleDashNeckWithoutVav = simpleDash.replacingOccurrences(of: "צוואר", with: "צואר")

        let candidates = [
            value,
            trimmed,
            normalizedSpaces,
            simpleDash,
            longDash,
            neckWithVav,
            neckWithoutVav,
            simpleDashNeckWithVav,
            simpleDashNeckWithoutVav
        ]

        var unique: [String] = []
        var seen = Set<String>()

        for candidate in candidates {
            let clean = candidate.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !clean.isEmpty else {
                continue
            }

            if !seen.contains(clean) {
                seen.insert(clean)
                unique.append(clean)
            }
        }

        return unique
    }
}
