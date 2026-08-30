import Foundation

/// מחליף שמות בכינויי תצוגה כאשר מצב ההדגמה פעיל.
/// אינו משנה נתונים במסד הנתונים.
@MainActor
enum TraineeDisplayNameMapper {

    struct TraineeNameSource {
        let realName: String?
        let stableKey: String?
    }

    static func displayName(
        realName: String?,
        stableKey: String?,
        demoIndex: Int? = nil,
        isEnglish: Bool = false
    ) -> String {
        let cleanRealName = clean(realName)

        guard DemoPrivacy.shared.isEnabled else {
            return cleanRealName
        }

        let prefix = isEnglish ? "Trainee" : "מתאמן"

        if let demoIndex {
            // UInt מאפשר להוסיף 1 גם לערך Int.max בלי קריסה.
            let sequentialNumber = UInt(max(0, demoIndex)) + 1
            return "\(prefix) \(sequentialNumber)"
        }

        let providedKey = clean(stableKey)
        let resolvedKey = providedKey.isEmpty
            ? cleanRealName
            : providedKey

        guard !resolvedKey.isEmpty else {
            return prefix
        }

        let hash = javaStringHashCode(resolvedKey)

        let safeHash: Int64 = hash == Int32.min
            ? 0
            : abs(Int64(hash))

        let stableNumber = safeHash % 9_999 + 1

        return "\(prefix) \(stableNumber)"
    }

    /// שמות רציפים בהתאם לסדר הרשימה.
    static func displayNames(
        trainees: [TraineeNameSource],
        isEnglish: Bool = false
    ) -> [String] {
        trainees.enumerated().map { index, trainee in
            displayName(
                realName: trainee.realName,
                stableKey: trainee.stableKey,
                demoIndex: index,
                isEnglish: isEnglish
            )
        }
    }

    private static func clean(_ value: String?) -> String {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
    }

    /// חישוב תואם Java/Kotlin:
    /// יחידות UTF-16 וגלישת מספר שלם בן 32 סיביות.
    private static func javaStringHashCode(
        _ value: String
    ) -> Int32 {
        var hash: Int32 = 0

        for codeUnit in value.utf16 {
            hash = (hash &* 31) &+ Int32(codeUnit)
        }

        return hash
    }
}
