import Foundation

enum KmiEnglishTitleTranslator {

    static func title(
        _ hebrewTitle: String,
        isEnglish: Bool
    ) -> String {
        guard isEnglish else {
            return hebrewTitle
        }

        return englishTitle(for: hebrewTitle)
    }

    static func englishTitle(for hebrewTitle: String) -> String {
        let clean = normalize(hebrewTitle)

        if let exact = ExerciseTitlesEnItems.map[clean] {
            return exact
        }

        if let topic = ExerciseTitlesEnTopics.map[clean] {
            return topic
        }

        if let alias = ExerciseTitlesEnAliases.map[clean] {
            return alias
        }

        return hebrewTitle
    }

    static func topicTitle(
        _ hebrewTitle: String,
        isEnglish: Bool
    ) -> String {
        guard isEnglish else {
            return hebrewTitle
        }

        let clean = normalize(hebrewTitle)

        if let topic = ExerciseTitlesEnTopics.map[clean] {
            return topic
        }

        if let alias = ExerciseTitlesEnAliases.map[clean] {
            return alias
        }

        return hebrewTitle
    }

    static func exerciseTitle(
        _ hebrewTitle: String,
        isEnglish: Bool
    ) -> String {
        guard isEnglish else {
            return hebrewTitle
        }

        let clean = normalize(hebrewTitle)

        if let item = ExerciseTitlesEnItems.map[clean] {
            return item
        }

        if let alias = ExerciseTitlesEnAliases.map[clean] {
            return alias
        }

        return hebrewTitle
    }

    static func containsEnglishTranslation(for hebrewTitle: String) -> Bool {
        let clean = normalize(hebrewTitle)

        return ExerciseTitlesEnItems.map[clean] != nil ||
               ExerciseTitlesEnTopics.map[clean] != nil ||
               ExerciseTitlesEnAliases.map[clean] != nil
    }

    private static func normalize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "–", with: "–")
            .replacingOccurrences(of: "—", with: "–")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
