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
            if let title = builtInEnglishTitle(for: candidate) {
                return title
            }

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

    private static func builtInEnglishTitle(for value: String) -> String? {
        switch value {
        case "general":
            return "General"

        case "defense_root", "defenses_root", "defenses", "defense", "הגנות":
            return "Defenses"

        case "def_internal", "def_internal_punch", "def_internal_punches", "הגנות פנימיות":
            return "Internal Defenses"

        case "def_internal_kick", "def_internal_kicks":
            return "Internal Defenses - Kicks"

        case "def_external", "def_external_punch", "def_external_punches", "הגנות חיצוניות":
            return "External Defenses"

        case "def_external_kick", "def_external_kicks":
            return "External Defenses - Kicks"

        case "kicks_hard", "הגנות נגד בעיטות":
            return "Defenses Against Kicks"

        case "knife_defense", "הגנות מסכין":
            return "Knife Defenses"

        case "gun_threat_defense", "הגנות מאיום אקדח":
            return "Gun Threat Defenses"

        case "stick_defense", "הגנות נגד מקל":
            return "Stick Defenses"

        case "הגנות עם רובה נגד דקירות סכין":
            return "Rifle Defenses Against Knife Stabs"

        case "הגנות נגד מספר תוקפים":
            return "Multiple Attackers Defense"

        case "hands_all", "hands_root", "עבודת ידיים":
            return "Hand Techniques"

        case "hands_strikes", "מכות יד":
            return "Hand Strikes"

        case "hands_elbows", "מכות מרפק":
            return "Elbow Strikes"

        case "hands_stick_rifle", "מכות במקל / רובה", "מכות במקל קצר":
            return "Stick / Rifle Strikes"

        case "releases", "releases_root", "שחרורים":
            return "Releases"

        case "releases_hands_hair_shirt", "שחרור מתפיסות ידיים / שיער / חולצה":
            return "Releases from Hand / Hair / Shirt Grabs"

        case "releases_chokes", "שחרור מחניקות":
            return "Choke Releases"

        case "releases_hugs", "שחרור מחביקות":
            return "Hug Releases"

        case "חביקות גוף":
            return "Body Hugs"

        case "חביקות צואר", "חביקות צוואר":
            return "Neck Hugs"

        case "חביקות זרוע":
            return "Arm Hugs"

        case "kicks", "topic_kicks", "בעיטות":
            return "Kicks"

        case "topic_ready_stance", "עמידת מוצא":
            return "Ready Stance"

        case "topic_ground_prep", "עבודת קרקע", "הכנה לעבודת קרקע":
            return "Groundwork Preparation"

        case "topic_kavaler", "kavaler", "קוואלר":
            return "Kavaler"

        case "topic_breakfalls_rolls", "rolls_breakfalls", "בלימות וגלגולים", "גלגולים ובלימות":
            return "Breakfalls and Rolls"

        case "throws_root", "הטלות":
            return "Throws"

        default:
            return nil
        }
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
