import SwiftUI
import Combine
import Shared

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@MainActor
final class ExerciseFavoritesStore: ObservableObject {
    static let shared = ExerciseFavoritesStore()

    private let defaults = UserDefaults.standard
    private let storageKey = "kmi.exercise.favorites.global"
    private let removedKey = "kmi.exercise.favorites.removed"

    @Published private(set) var favorites: Set<String>

    private init() {
        let saved = UserDefaults.standard.stringArray(
            forKey: "kmi.exercise.favorites.global"
        ) ?? []

        favorites = Set(
            saved
                .map { Self.normalize($0) }
                .filter { !$0.isEmpty }
        )
    }

    static func normalize(_ raw: String) -> String {
        let displayName = ExerciseTitleFormatter.shared
            .displayName(raw: raw)

        return displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{200F}", with: "")
            .replacingOccurrences(of: "\u{200E}", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(
                of: "[\u{0591}-\u{05C7}]",
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    func contains(_ raw: String) -> Bool {
        let id = Self.normalize(raw)
        return !id.isEmpty && favorites.contains(id)
    }

    func set(_ raw: String, favorite: Bool) {
        let id = Self.normalize(raw)
        guard !id.isEmpty else { return }

        var updated = favorites
        var removed = Set(
            defaults.stringArray(forKey: removedKey) ?? []
        )

        if favorite {
            updated.insert(id)
            removed.remove(id)
        } else {
            updated.remove(id)
            removed.insert(id)
        }

        defaults.set(removed.sorted(), forKey: removedKey)

        guard updated != favorites else { return }

        favorites = updated
        defaults.set(updated.sorted(), forKey: storageKey)
    }

    func importLegacyFavorite(_ raw: String) {
        let id = Self.normalize(raw)
        guard !id.isEmpty else { return }

        let removed = Set(
            defaults.stringArray(forKey: removedKey) ?? []
        )

        guard !removed.contains(id),
              !favorites.contains(id) else {
            return
        }

        var updated = favorites
        updated.insert(id)

        favorites = updated
        defaults.set(updated.sorted(), forKey: storageKey)
    }

    func toggle(_ raw: String) {
        set(raw, favorite: !contains(raw))
    }
}

/*
 * זיהוי משותף לתרגיל ב-iOS.
 *
 * מבוסס על שלבי הזיהוי הראשיים של
 * ExerciseSyncStore באנדרואיד:
 * ניקוי, הסרת תחילית נושא, שם תצוגה ומזהה registry.
 *
 * הרכיב אינו קורא או משנה נתונים שמורים.
 */
enum ExerciseIdentityResolverIOS {

    struct Identity {
        let primaryID: String
        let displayTitle: String

        /*
         * מזהים אפשריים ששימשו עד כה ב-iOS.
         * אין להשתמש בהם לדריסה אוטומטית של הערה אחרת.
         */
        let previousIDs: Set<String>
    }

    private static func cleanText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{200F}", with: "")
            .replacingOccurrences(of: "\u{200E}", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func displayTitle(
        topic: String,
        rawItem: String
    ) -> String {
        let cleanTopic = cleanText(topic)
        var cleanRaw = cleanText(rawItem)

        if !cleanTopic.isEmpty,
           cleanRaw.hasPrefix("\(cleanTopic)::") {
            cleanRaw = String(
                cleanRaw.dropFirst(cleanTopic.count + 2)
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if !cleanTopic.isEmpty,
           cleanRaw.hasPrefix(cleanTopic) {
            cleanRaw = String(
                cleanRaw.dropFirst(cleanTopic.count)
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

            let separators = CharacterSet(
                charactersIn: "-–—:"
            )

            while let first = cleanRaw.unicodeScalars.first,
                  separators.contains(first) {
                cleanRaw.removeFirst()
            }

            cleanRaw = cleanRaw.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        }

        let formatted = ExerciseTitleFormatter.shared
            .displayName(raw: cleanRaw)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !formatted.isEmpty && formatted != "null" {
            return formatted
        }

        return cleanRaw
    }

    static func resolve(
        belt: Belt,
        topic: String,
        rawItem: String
    ) -> Identity? {
        let cleanTopic = cleanText(topic)
        let cleanRaw = cleanText(rawItem)

        guard !cleanTopic.isEmpty,
              !cleanRaw.isEmpty else {
            return nil
        }

        let title = displayTitle(
            topic: cleanTopic,
            rawItem: cleanRaw
        )

        guard !title.isEmpty else {
            return nil
        }

        let primaryID = ExerciseIdentityRegistry.shared.idFor(
            belt: belt,
            hebrewTitle: title,
            topicKey: cleanTopic
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !primaryID.isEmpty else {
            return nil
        }

        /*
         * המימוש הקודם של iOS העביר את השם המקורי.
         * שומרים את המזהה המוכר שלו כמועמד לקריאה,
         * בלי להעביר או לשנות את הנתונים בשלב הזה.
         */
        let previous = ExerciseIdentityRegistry.shared.resolve(
            belt: belt,
            hebrewTitle: cleanRaw,
            topicKey: cleanTopic
        )

        var previousIDs = Set<String>()

        if previous.isKnown {
            let previousID = previous.id.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            if !previousID.isEmpty && previousID != primaryID {
                previousIDs.insert(previousID)
            }
        }

        return Identity(
            primaryID: primaryID,
            displayTitle: title,
            previousIDs: previousIDs
        )
    }
}

@MainActor
final class ExerciseNotesStore: ObservableObject {
    static let shared = ExerciseNotesStore()

    private let defaults = UserDefaults.standard

    // מאפשר למסכים שמאזינים למנגנון להתעדכן לאחר שינוי.
    @Published private(set) var revision = 0

    private init() {}

    private func storageKey(
        userID: String,
        beltID: String,
        exerciseID: String
    ) -> String? {
        let parts = [userID, beltID, exerciseID].map {
            $0.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        }

        guard parts.allSatisfy({ !$0.isEmpty }),
              let data = try? JSONEncoder().encode(parts) else {
            return nil
        }

        return "kmi.exercise.note.\(data.base64EncodedString())"
    }

    func knownExerciseID(
        belt: Belt,
        title: String,
        topicKey: String? = nil
    ) -> String? {
        let cleanTitle = title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleanTitle.isEmpty else {
            return nil
        }

        let resolved = ExerciseIdentityRegistry.shared.resolve(
            belt: belt,
            hebrewTitle: cleanTitle,
            topicKey: topicKey
        )

        guard resolved.isKnown else {
            return nil
        }

        let id = resolved.id.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return id.isEmpty ? nil : id
    }

    func hasStoredValue(
        userID: String,
        beltID: String,
        exerciseID: String
    ) -> Bool {
        guard let key = storageKey(
            userID: userID,
            beltID: beltID,
            exerciseID: exerciseID
        ) else {
            return false
        }

        return defaults.object(forKey: key) != nil
    }

    enum CompatibleNoteResult {
        case missing
        case found(String)
        case conflict
    }

    /*
     * בודק את המזהה הראשי ואת המזהים הקודמים של
     * אותו משתמש וחגורה, ללא שינוי בנתונים השמורים.
     */
    func loadCompatible(
        userID: String,
        beltID: String,
        identity: ExerciseIdentityResolverIOS.Identity
    ) -> CompatibleNoteResult {
        guard let primaryKey = storageKey(
            userID: userID,
            beltID: beltID,
            exerciseID: identity.primaryID
        ) else {
            return .missing
        }

        /*
         * אם קיים ערך במזהה הראשי, הוא מקור הקריאה.
         * גם מחרוזת ריקה היא מחיקה מפורשת.
         */
        if defaults.object(forKey: primaryKey) != nil {
            guard let value = defaults.string(
                forKey: primaryKey
            ) else {
                return .conflict
            }

            return .found(value)
        }

        var previousValues = Set<String>()

        for previousID in identity.previousIDs {
            guard let key = storageKey(
                userID: userID,
                beltID: beltID,
                exerciseID: previousID
            ),
            defaults.object(forKey: key) != nil else {
                continue
            }

            guard let value = defaults.string(forKey: key) else {
                return .conflict
            }

            previousValues.insert(value)
        }

        if previousValues.count > 1 {
            return .conflict
        }

        if let value = previousValues.first {
            return .found(value)
        }

        return .missing
    }

    /*
     * מחזיר את הערכים הסותרים רק כאשר אפשר לקרוא
     * את כולם כמחרוזות ואין כבר ערך במזהה הראשי.
     *
     * nil פירושו שאין סתירה שניתן לפתור בפעולה זו.
     */
    func conflictingNoteValues(
        userID: String,
        beltID: String,
        identity: ExerciseIdentityResolverIOS.Identity
    ) -> [String]? {
        guard let primaryKey = storageKey(
            userID: userID,
            beltID: beltID,
            exerciseID: identity.primaryID
        ),
        defaults.object(forKey: primaryKey) == nil else {
            return nil
        }

        var values = Set<String>()

        for previousID in identity.previousIDs {
            guard let key = storageKey(
                userID: userID,
                beltID: beltID,
                exerciseID: previousID
            ) else {
                return nil
            }

            guard let storedValue = defaults.object(
                forKey: key
            ) else {
                continue
            }

            guard let value = storedValue as? String else {
                return nil
            }

            values.insert(value)
        }

        guard values.count > 1 else {
            return nil
        }

        return values.sorted()
    }

    /*
     * שומר את הבחירה רק אם גרסאות ההערה לא השתנו
     * מאז שהוצגו למשתמש. המזהים הישנים אינם נמחקים.
     *
     * על המסך הקורא לוודא בנפרד שהמשתמש המחובר
     * עדיין תואם ל-userID שלפיו הוצגו הגרסאות.
     */
    @discardableResult
    func resolveNoteConflict(
        selectedValue: String,
        expectedValues: [String],
        userID: String,
        beltID: String,
        identity: ExerciseIdentityResolverIOS.Identity
    ) -> Bool {
        guard let currentValues = conflictingNoteValues(
            userID: userID,
            beltID: beltID,
            identity: identity
        ),
        currentValues == expectedValues,
        currentValues.contains(selectedValue) else {
            return false
        }

        save(
            selectedValue,
            userID: userID,
            beltID: beltID,
            exerciseID: identity.primaryID
        )

        return true
    }

    func load(
        userID: String,
        beltID: String,
        exerciseID: String
    ) -> String {
        guard let key = storageKey(
            userID: userID,
            beltID: beltID,
            exerciseID: exerciseID
        ) else {
            return ""
        }

        return defaults.string(forKey: key) ?? ""
    }

    func save(
        _ note: String,
        userID: String,
        beltID: String,
        exerciseID: String
    ) {
        guard let key = storageKey(
            userID: userID,
            beltID: beltID,
            exerciseID: exerciseID
        ) else {
            return
        }

        let clean = note.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard defaults.string(forKey: key) != clean else {
            return
        }

        /*
         * גם מחיקה נשמרת כערך ריק, כדי שנוכל בהמשך
         * להבחין בין הערה שנמחקה לבין הערה שטרם הועברה.
         */
        defaults.set(clean, forKey: key)
        revision += 1
    }
}

fileprivate enum ExerciseMarkState: String {
    case unmarked
    case know
    case partiallyKnown
    case dontKnow
}

struct SubjectAcrossBeltsView: View {

    @Environment(\.colorScheme)
    private var colorScheme

    @EnvironmentObject
    private var auth: AuthViewModel

    @AppStorage("user_role")
    private var storedUserRole: String = ""

    @State private var coachStatusesCache:
        [String: Set<KmiCoachExerciseStatus>] = [:]

    @State private var coachDatesCache:
        [String: [KmiCoachExerciseStatus: Date]] = [:]

    private func coachDates(
        belt: Belt,
        item: UiItem
    ) -> [KmiCoachExerciseStatus: Date] {
        coachDatesCache[
            coachProgressKey(belt: belt, item: item)
        ] ?? [:]
    }

    private var isCoachUser: Bool {
        let storedRole = storedUserRole
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let role = storedRole.isEmpty
            ? auth.userRole
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            : storedRole

        return [
            "coach",
            "trainer",
            "instructor",
            "מאמן",
            "coach_user",
            "kmi_coach"
        ].contains(role)
    }

    private func coachProgressKey(
        belt: Belt,
        item: UiItem
    ) -> String {
        "kmi.subject.coach.\(markKey(belt: belt, item: item))"
    }

    private func coachStatuses(
        belt: Belt,
        item: UiItem
    ) -> Set<KmiCoachExerciseStatus> {
        let key = coachProgressKey(belt: belt, item: item)

        if let cached = coachStatusesCache[key] {
            return cached
        }

        let saved = UserDefaults.standard
            .stringArray(forKey: "\(key).selected") ?? []

        return Set(
            saved.compactMap {
                KmiCoachExerciseStatus(rawValue: $0)
            }
        )
    }

    private func toggleCoachStatus(
        _ status: KmiCoachExerciseStatus,
        belt: Belt,
        item: UiItem
    ) {
        let key = coachProgressKey(belt: belt, item: item)
        let defaults = UserDefaults.standard
        let dateKey = "\(key).\(status.rawValue).updatedAt"

        var selected = coachStatuses(belt: belt, item: item)
        var dates = coachDates(belt: belt, item: item)

        if selected.contains(status) {
            selected.remove(status)
            dates.removeValue(forKey: status)
            defaults.removeObject(forKey: dateKey)
        } else {
            guard selected.count < 2 else { return }

            let now = Date()

            selected.insert(status)
            dates[status] = now

            defaults.set(
                now.timeIntervalSince1970,
                forKey: dateKey
            )
        }

        defaults.set(
            selected.map(\.rawValue).sorted(),
            forKey: "\(key).selected"
        )

        coachDatesCache[key] = dates
        coachStatusesCache[key] = selected
    }

    private func coachStatusCount(
        belt: Belt,
        status: KmiCoachExerciseStatus
    ) -> Int {
        allItemsForBelt(belt).filter {
            coachStatuses(belt: belt, item: $0).contains(status)
        }.count
    }

    private func coachUnmarkedCount(belt: Belt) -> Int {
        allItemsForBelt(belt).filter {
            coachStatuses(belt: belt, item: $0).isEmpty
        }.count
    }

    let subject: KMI_iOS.SubjectTopic
    let forcedSectionTitle: String?

    init(subject: KMI_iOS.SubjectTopic, forcedSectionTitle: String? = nil) {
        self.subject = subject
        self.forcedSectionTitle = forcedSectionTitle
    }

    // סדר חגורות כמו אצלך באנדרואיד
    private let belts: [Belt] = [.yellow, .orange, .green, .blue, .brown, .black]
    @State private var selectedBelt: Belt = .orange
    @State private var exerciseMarks: [String: ExerciseMarkState] = [:]
    @State private var activeInfoExercise: ExerciseMenuContext? = nil
    @State private var activeNoteExercise: ExerciseMenuContext? = nil
    @State private var noteText: String = ""
    @State private var noteEditorOwnerUID: String? = nil
    @State private var noteProblemMessage = ""
    @State private var showNoteProblem = false

    @State private var noteSaveProblemMessage = ""
    @State private var showNoteSaveProblem = false

    @ObservedObject private var exerciseFavorites =
        ExerciseFavoritesStore.shared

    @ObservedObject private var exerciseNotes =
        ExerciseNotesStore.shared

    @State private var excludedExerciseIds: Set<String> = []

    @State private var cachedSectionsByBelt:
        [Belt: [UiSection]] = [:]

    @State private var didLoadSections = false

    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"

    private var isEnglish: Bool {
        let values = [
            kmiAppLanguageCode.lowercased(),
            appLanguageRaw.lowercased(),
            initialLanguageCode.lowercased()
        ]

        return values.contains("en") || values.contains("english")
    }

    private var screenLayoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    private var primaryTextAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var horizontalTextAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    // MARK: - Local UI models
    private struct UiItem: Identifiable, Hashable {
        let id: String
        let displayName: String
        let topicTitle: String

        // פרטי הזיהוי שמגיעים ממקור התוכן המשותף.
        // במסלולים אחרים הם נשארים nil עד לזיהוי מתאים.
        var canonicalId: String? = nil
        var itemKey: String? = nil
        var rawItem: String? = nil
        var sourceTopicTitle: String? = nil
        var sourceSubTopicTitle: String? = nil
    }

    private struct UiSection: Identifiable {
        let id: String
        let title: String
        let items: [UiItem]
    }

    private struct SectionsCacheKey: Hashable {
        let subject: KMI_iOS.SubjectTopic
        let forcedSectionTitle: String?
        let belt: Belt
    }

    @MainActor
    private enum SectionsMemoryCache {
        static var values:
            [SectionsCacheKey: [UiSection]] = [:]
    }

    private struct ExerciseMenuContext: Identifiable, Hashable {
        let id: String
        let belt: Belt
        let item: UiItem

        init(belt: Belt, item: UiItem) {
            self.belt = belt
            self.item = item
            self.id = "\(belt.id)::\(item.topicTitle)::\(item.displayName)"
        }
    }
    
    // MARK: - Filtering helpers (כמו SubjectTopicContentView)
    private func norm(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func hardSubjectId(for subject: KMI_iOS.SubjectTopic) -> String? {

        switch subject.id {

        case "topic_breakfalls_rolls", "rolls_breakfalls":
            return "topic_breakfalls_rolls"

        case "topic_ready_stance":
            return "topic_ready_stance"

        case "topic_ground_prep":
            return "topic_ground_prep"

        case "topic_kavaler", "kavaler":
            return "topic_kavaler"

        case "kicks", "topic_kicks":
            return "topic_kicks"

        case "kicks_hard":
            return "kicks_hard"

        case "releases", "releases_root":
            return "releases"

        // עבודת ידיים אינה נפתרת דרך HardSectionsCatalog.
        // היא ממשיכה למסלול SubjectItemsResolver,
        // שהוא מקור הרשימה החוצה־חגורות שמוצגת בפועל.
        case "hands_strikes",
             "topic_hands",
             "punches",
             "hands_elbows",
             "hands_stick_rifle",
             "hands_all":
            return nil

        case "knife_defense":
            return "knife_defense"

        case "knife_rifle_defense":
            return "knife_rifle_defense"

        case "multiple_attackers_defense":
            return "multiple_attackers_defense"

        case "gun_threat_defense":
            return "gun_threat_defense"

        case "stick_defense":
            return "stick_defense"

        case "def_internal",
             "def_internal_punch",
             "def_internal_punches",
             "def_internal_kick",
             "def_internal_kicks":
            return "def_internal"

        case "def_external",
             "def_external_punch",
             "def_external_punches",
             "def_external_kick",
             "def_external_kicks":
            return "def_external"

        default:
            return nil
        }
    }

    private func uiSubjectTitle() -> String {
        let cleanId = subject.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = subject.titleHeb.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isEnglish else { return cleanTitle }

        if let resolvedFromId = KmiEnglishTitleResolver.englishTitle(for: cleanId) {
            return resolvedFromId
        }

        return KmiEnglishTitleResolver.title(for: cleanTitle, isEnglish: true)
    }

    private func uiSectionTitle(_ title: String) -> String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isEnglish else { return clean }

        return KmiEnglishTitleResolver.englishTitle(for: clean) ?? clean
    }

    private func sectionDirectlyMatchesForcedSelection(
        _ section: HardSectionsCatalog.Section,
        forcedClean: String
    ) -> Bool {
        let idClean = section.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let titleClean = section.title.trimmingCharacters(in: .whitespacesAndNewlines)

        return idClean == forcedClean || titleClean == forcedClean
    }

    private func sectionTreeContainsForcedSelection(
        _ section: HardSectionsCatalog.Section,
        forcedClean: String
    ) -> Bool {
        if sectionDirectlyMatchesForcedSelection(section, forcedClean: forcedClean) {
            return true
        }

        return section.subSections.contains {
            sectionTreeContainsForcedSelection($0, forcedClean: forcedClean)
        }
    }

    private func sectionMatchesForcedSelection(
        _ section: HardSectionsCatalog.Section,
        forced: String?
    ) -> Bool {
        guard let forced,
              !forced.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return true
        }

        let forcedClean = forced.trimmingCharacters(in: .whitespacesAndNewlines)

        return sectionTreeContainsForcedSelection(section, forcedClean: forcedClean)
    }

    private func findForcedSection(
        in sections: [HardSectionsCatalog.Section],
        forcedClean: String
    ) -> HardSectionsCatalog.Section? {
        for section in sections {
            if sectionDirectlyMatchesForcedSelection(section, forcedClean: forcedClean) {
                return section
            }

            if let childMatch = findForcedSection(
                in: section.subSections,
                forcedClean: forcedClean
            ) {
                return childMatch
            }
        }

        return nil
    }

    private func displayTitleForForcedSection(_ forced: String) -> String {
        let clean = forced.trimmingCharacters(in: .whitespacesAndNewlines)

        if let hardId = hardSubjectId(for: subject),
           let hardSections = HardSectionsCatalog.shared.sectionsForSubject(subjectId: hardId),
           let match = findForcedSection(in: hardSections, forcedClean: clean) {
            return uiSectionTitle(match.title)
        }

        return uiSectionTitle(clean)
    }

    private func uiExerciseTitle(_ title: String) -> String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return KmiEnglishTitleResolver.title(for: clean, isEnglish: isEnglish)
    }

    private func exercisesCountText(_ count: Int) -> String {
        if isEnglish {
            return "exercises \(count)"
        } else {
            return "\(count) תרגילים"
        }
    }

    private var hasAnyExercises: Bool {
        belts.contains { belt in
            !sections(for: belt).isEmpty
        }
    }

    private func emptyExercisesMessage() -> String {
        let subjectTitle = uiSubjectTitle()

        if let forcedSectionTitle,
           !forcedSectionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let sectionTitle = displayTitleForForcedSection(forcedSectionTitle)

            return isEnglish
            ? "No exercises found for \"\(subjectTitle) / \(sectionTitle)\""
            : "לא נמצאו תרגילים עבור \"\(subjectTitle) / \(sectionTitle)\""
        }

        return isEnglish
        ? "No exercises found for \"\(subjectTitle)\""
        : "לא נמצאו תרגילים עבור \"\(subjectTitle)\""
    }

    private var totalExercisesAcrossBelts: Int {
        belts.reduce(0) { partial, belt in
            partial + sections(for: belt).reduce(0) { $0 + $1.items.count }
        }
    }

    private var visibleBeltsCount: Int {
        belts.filter { !sections(for: $0).isEmpty }.count
    }

    private func heroSubtitleText() -> String {
        if isEnglish {
            return "\(exercisesCountText(totalExercisesAcrossBelts)) · \(visibleBeltsCount) belts"
        }

        return "\(exercisesCountText(totalExercisesAcrossBelts)) · \(visibleBeltsCount) חגורות"
    }

    private func subjectSymbolName() -> String {
        let id = subject.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let title = subject.titleHeb.trimmingCharacters(in: .whitespacesAndNewlines)

        if id.contains("internal") || title.contains("פנימ") {
            return "arrow.down.left.and.arrow.up.right"
        }

        if id.contains("external") || title.contains("חיצונ") {
            return "arrow.up.forward.and.arrow.down.backward"
        }

        if id.contains("knife") || title.contains("סכין") {
            return "shield.lefthalf.filled"
        }

        if id.contains("gun") || title.contains("אקדח") {
            return "scope"
        }

        if id.contains("stick") || title.contains("מקל") || title.contains("רובה") {
            return "figure.fencing"
        }

        if id.contains("release") || title.contains("שחרור") || title.contains("חביקה") {
            return "hand.raised.fill"
        }

        if id.contains("kick") || title.contains("בעיטה") {
            return "figure.kickboxing"
        }

        if id.contains("hand") || id.contains("punch") || title.contains("יד") || title.contains("מרפק") {
            return "hand.tap.fill"
        }

        return "list.bullet.rectangle.fill"
    }
    
    private func containsAny(_ text: String, keywords: [String]) -> Bool {
        if keywords.isEmpty { return true }
        let t = norm(text)
        return keywords.contains { t.contains(norm($0)) }
    }

    private func containsAll(_ text: String, keywords: [String]) -> Bool {
        if keywords.isEmpty { return true }
        let t = norm(text)
        return keywords.allSatisfy { t.contains(norm($0)) }
    }

    private func containsNone(_ text: String, keywords: [String]) -> Bool {
        if keywords.isEmpty { return true }
        let t = norm(text)
        return !keywords.contains { t.contains(norm($0)) }
    }

    private func itemPasses(_ item: String, subTopicTitle: String?) -> Bool {
        let combined = (subTopicTitle ?? "") + " " + item

        if let hint = subject.subTopicHint, !hint.isEmpty {
            let ok = norm(subTopicTitle ?? "").contains(norm(hint)) || norm(item).contains(norm(hint))
            if !ok { return false }
        }

        if !subject.includeItemKeywords.isEmpty {
            if !containsAny(combined, keywords: subject.includeItemKeywords) { return false }
        }

        if !containsAll(combined, keywords: subject.requireAllItemKeywords) { return false }

        if !containsNone(combined, keywords: subject.excludeItemKeywords) { return false }

        return true
    }

    private func appendHardSectionTree(
        _ sec: HardSectionsCatalog.Section,
        belt: Belt,
        into out: inout [UiSection],
        parentPath: [String] = [],
        forcedClean: String? = nil
    ) {
        let currentPath = parentPath + [sec.title]

        let shouldIncludeCurrentSection: Bool = {
            guard let forcedClean,
                  !forcedClean.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return true
            }

            return sectionDirectlyMatchesForcedSelection(sec, forcedClean: forcedClean)
        }()

        let items = HardSectionsCatalog.shared.itemsFor(sec, belt: belt)

        if shouldIncludeCurrentSection, !items.isEmpty {
            let uiItems = items.map { raw in
                UiItem(
                    id: "\(belt.id)::\(sec.id)::\(raw)",
                    displayName: raw,
                    topicTitle: currentPath.joined(separator: " / ")
                )
            }

            out.append(
                UiSection(
                    id: "\(belt.id)::\(sec.id)",
                    title: sec.title,
                    items: uiItems
                )
            )
        }

        let childForcedSelection: String?

        if let forcedClean,
           sectionDirectlyMatchesForcedSelection(
               sec,
               forcedClean: forcedClean
           ) {
            childForcedSelection = nil
        } else {
            childForcedSelection = forcedClean
        }

        for child in sec.subSections {
            if let childForcedSelection,
               !childForcedSelection.isEmpty,
               !sectionTreeContainsForcedSelection(
                   child,
                   forcedClean: childForcedSelection
               ) {
                continue
            }

            appendHardSectionTree(
                child,
                belt: belt,
                into: &out,
                parentPath: currentPath,
                forcedClean: childForcedSelection
            )
        }
    }

    private func toSharedSubject(_ local: KMI_iOS.SubjectTopic) -> Shared.SubjectTopic {
        Shared.SubjectTopic(
            id: local.id,
            titleHeb: local.titleHeb,
            topicsByBelt: local.topicsByBelt,
            subTopicHint: local.subTopicHint,
            includeItemKeywords: local.includeItemKeywords,
            requireAllItemKeywords: local.requireAllItemKeywords,
            excludeItemKeywords: local.excludeItemKeywords
        )
    }
    
    private func sections(for belt: Belt) -> [UiSection] {
        cachedSectionsByBelt[belt] ?? []
    }

    private func loadSectionsIfNeeded() {
        guard !didLoadSections else {
            return
        }

        var loaded: [Belt: [UiSection]] = [:]

        for belt in belts {
            loaded[belt] = resolveSections(for: belt)
        }

        cachedSectionsByBelt = loaded
        didLoadSections = true
    }

    @MainActor
    private func resolveSections(for belt: Belt) -> [UiSection] {
        let cleanForcedTitle = forcedSectionTitle?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let key = SectionsCacheKey(
            subject: subject,
            forcedSectionTitle:
                cleanForcedTitle?.isEmpty == false
                    ? cleanForcedTitle
                    : nil,
            belt: belt
        )

        if let cached = SectionsMemoryCache.values[key] {
            return cached
        }

        let prepared = buildSections(
            for: belt
        )

        SectionsMemoryCache.values[key] = prepared

        return prepared
    }

    private func buildSections(for belt: Belt) -> [UiSection] {

        if let hardId = hardSubjectId(for: subject),
           let hardSections = HardSectionsCatalog.shared.sectionsForSubject(subjectId: hardId),
           !hardSections.isEmpty {

            let filteredHardSections: [HardSectionsCatalog.Section]
            if let forcedSectionTitle, !forcedSectionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                filteredHardSections = hardSections.filter {
                    sectionMatchesForcedSelection($0, forced: forcedSectionTitle)
                }
            } else {
                filteredHardSections = hardSections
            }

            var hardOut: [UiSection] = []

            let forcedClean = forcedSectionTitle?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            for sec in filteredHardSections {
                appendHardSectionTree(
                    sec,
                    belt: belt,
                    into: &hardOut,
                    forcedClean: forcedClean
                )
            }

            return hardOut
        }

        let sharedSubject = toSharedSubject(subject)

        let rawSections = SubjectItemsResolver.shared
            .resolveBySubject(belt: belt, subject: sharedSubject)

        let uiSections: [SubjectItemsResolver.UiSection]
        if let forcedSectionTitle, !forcedSectionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let forcedClean = forcedSectionTitle.trimmingCharacters(in: .whitespacesAndNewlines)

            uiSections = rawSections.filter { section in
                section.title.trimmingCharacters(in: .whitespacesAndNewlines) == forcedClean
            }
        } else {
            uiSections = rawSections
        }

        var out: [UiSection] = []

        for sec in uiSections {
            let items = sec.items

            if !items.isEmpty {
                let uiItems = items.enumerated().map { index, item in
                    UiItem(
                        id: "\(belt.id)::\(sec.title)::\(index)::\(item.displayName)",
                        displayName: item.displayName,
                        topicTitle: sec.title,
                        canonicalId: item.canonicalId,
                        itemKey: item.itemKey,
                        rawItem: item.rawItem,
                        sourceTopicTitle: item.topicTitle,
                        sourceSubTopicTitle: item.subTopicTitle
                    )
                }

                out.append(
                    UiSection(
                        id: "\(belt.id)::\(sec.title)",
                        title: sec.title,
                        items: uiItems
                    )
                )
            }
        }

        return out
    }

    @MainActor
    static func preloadSections(
        subject: KMI_iOS.SubjectTopic,
        forcedSectionTitle: String? = nil
    ) async {
        let resolverView = SubjectAcrossBeltsView(
            subject: subject,
            forcedSectionTitle: forcedSectionTitle
        )

        for belt in resolverView.belts {
            await Task.yield()

            guard !Task.isCancelled else {
                return
            }

            _ = resolverView.resolveSections(
                for: belt
            )
        }
    }

    @MainActor
    static func resolvedExerciseCount(
        subject: KMI_iOS.SubjectTopic,
        forcedSectionTitle: String? = nil
    ) -> Int {
        let resolverView = SubjectAcrossBeltsView(
            subject: subject,
            forcedSectionTitle: forcedSectionTitle
        )

        return resolverView.belts.reduce(0) { partial, belt in
            let sections = resolverView.resolveSections(for: belt)

            return partial + sections.reduce(0) { sectionPartial, section in
                sectionPartial + section.items.count
            }
        }
    }

    private var heroIcon: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.20),
                        Color.purple.opacity(0.08),
                        Color.white.opacity(0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 58, height: 54)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.purple.opacity(0.20), lineWidth: 1)
            )
            .overlay(
                Image(systemName: subjectSymbolName())
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(Color.purple.opacity(0.78))
            )
    }
    
    var body: some View {
        ZStack {
            KmiAppBackground()

            VStack(spacing: 0) {
                VStack(spacing: 3) {
                    Text(beltTitleText(selectedBelt))
                        .kmiFont(size: 20, weight: .heavy)
                        .foregroundStyle(
                            selectedBelt == .white ||
                            selectedBelt == .black
                                ? KmiAppTheme.sectionHeaderContentColor
                                : KmiBeltPalette.color(for: selectedBelt)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.80)
                        .multilineTextAlignment(.center)

                    Text(
                        exercisesCountText(
                            sections(for: selectedBelt)
                                .reduce(0) {
                                    $0 + $1.items.count
                                }
                        )
                    )
                    .kmiFont(size: 12, weight: .bold)
                    .lineLimit(1)
                }
                .foregroundStyle(
                    KmiAppTheme.sectionHeaderContentColor
                )
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: 68)
                .background(
                    KmiAppTheme.sectionHeaderBrush
                )
                .overlay {
                    Rectangle()
                        .stroke(
                            KmiAppTheme.sectionHeaderContentColor
                                .opacity(0.34),
                            lineWidth: 1
                        )
                }

                subjectStatsHeader

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {

               
                            if !hasAnyExercises {
                                VStack(spacing: 10) {
                                    Image(
                                        systemName: "doc.text.magnifyingglass"
                                    )
                                    .kmiIconSize(24)
                                    .fontWeight(.bold)
                                    .foregroundStyle(
                                        KmiAppTheme.primary(for: colorScheme)
                                    )
                                    .frame(width: 58, height: 54)
                                    .background(
                                        RoundedRectangle(
                                            cornerRadius: 17,
                                            style: .continuous
                                        )
                                        .fill(
                                            KmiAppTheme.surfaceVariant(
                                                for: colorScheme
                                            )
                                        )
                                    )

                                    Text(
                                        tr(
                                            "לא נמצאו תרגילים",
                                            "No exercises found"
                                        )
                                    )
                                    .kmiTypography(.body)
                                    .fontWeight(.bold)
                                    .foregroundStyle(
                                        KmiAppTheme.onSurface(
                                            for: colorScheme
                                        )
                                    )

                                    Text(emptyExercisesMessage())
                                        .kmiTypography(.caption)
                                        .foregroundStyle(
                                            KmiAppTheme.onSurfaceVariant(
                                                for: colorScheme
                                            )
                                        )
                                }
                                .multilineTextAlignment(.center)
                                .fixedSize(
                                    horizontal: false,
                                    vertical: true
                                )
                                .padding(16)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(
                                        cornerRadius: 16,
                                        style: .continuous
                                    )
                                    .fill(
                                        KmiAppTheme.surface(
                                            for: colorScheme
                                        )
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(
                                        cornerRadius: 16,
                                        style: .continuous
                                    )
                                    .stroke(
                                        KmiAppTheme.outlineVariant(
                                            for: colorScheme
                                        ),
                                        lineWidth: 1
                                    )
                                )
                            }

                        ForEach(belts, id: \.self) { belt in

                            let secs = sections(for: belt)

                            if !secs.isEmpty {

                                VStack(spacing: 12) {

                                    VStack(spacing: 10) {
                                        ForEach(secs) { sec in
                                            VStack(spacing: 8) {
                                                if secs.count > 1 {
                                                    sectionTitlePill(
                                                        sec.title,
                                                        accent: beltAccent(belt)
                                                    )
                                                }

                                                ForEach(sec.items) { item in
                                                    subjectExerciseCard(
                                                        belt: belt,
                                                        item: item
                                                    )
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 6)
                                .background {
                                    GeometryReader { geometry in
                                        Color.clear.preference(
                                            key:
                                                SubjectBeltPositionPreferenceKey.self,
                                            value: [
                                                belt:
                                                    geometry.frame(
                                                        in: .named(
                                                            "subjectExercisesScroll"
                                                        )
                                                    ).minY
                                            ]
                                        )
                                    }
                                }
                                .id(beltAnchorId(belt))
                            }
                        }

                        Spacer(minLength: 18)
                    }
                        .padding(.horizontal, 8)
                        .padding(.top, 5)
                        .padding(.bottom, 22)
                        }
                        .coordinateSpace(
                            name: "subjectExercisesScroll"
                        )
                        .onPreferenceChange(
                            SubjectBeltPositionPreferenceKey.self
                        ) { positions in
                            let currentBelt =
                                positions
                                    .filter { $0.value <= 8 }
                                    .max {
                                        $0.value < $1.value
                                    }?.key ??
                                positions
                                    .min {
                                        $0.value < $1.value
                                    }?.key

                            if let currentBelt,
                               selectedBelt != currentBelt {
                                selectedBelt = currentBelt
                            }
                        }
                    }
            }
        }
            .environment(\.layoutDirection, screenLayoutDirection)
            .onAppear {
                loadSectionsIfNeeded()
                preloadExerciseProgress()

                NotificationCenter.default.post(
                    name: Notification.Name("KMI_TOP_TITLE_OVERRIDE"),
                    object: uiSubjectTitle()
                )

                var loadedFavorites = Set<String>()
                var loadedExcluded = Set<String>()

                for belt in belts {
                    loadedFavorites.formUnion(
                        loadStringSet(
                            favoritesStorageKey(for: belt)
                        )
                    )

                    loadedExcluded.formUnion(
                        loadStringSet(
                            excludedStorageKey(for: belt)
                        )
                    )
                }

                if let firstVisibleBelt = belts.first(
                    where: {
                        !sections(for: $0).isEmpty
                    }
                ) {
                    selectedBelt = firstVisibleBelt
                }

                excludedExerciseIds = loadedExcluded

                for belt in belts {
                    for item in allItemsForBelt(belt) {
                        let legacyID = exerciseId(
                            belt: belt,
                            item: item
                        )

                        if loadedFavorites.contains(legacyID) {
                            exerciseFavorites.importLegacyFavorite(
                                item.rawItem ?? item.displayName
                            )
                        }
                    }
                }
            }
            .onDisappear {
            NotificationCenter.default.post(
                name: Notification.Name("KMI_TOP_TITLE_OVERRIDE"),
                object: ""
            )
        }
        .navigationDestination(item: $activeInfoExercise) { context in
            ExerciseDetailView(
                belt: context.belt,
                topicTitle: context.item.topicTitle,
                item: context.item.displayName
            )
        }
        .sheet(
            item: $activeNoteExercise,
            onDismiss: {
                noteEditorOwnerUID = nil
                noteText = ""
                noteSaveProblemMessage = ""
                showNoteSaveProblem = false
            }
        ) { context in
            ExerciseNoteSheet(
                title: uiExerciseTitle(context.item.displayName),
                noteText: $noteText,
                isEnglish: isEnglish,
                onSave: {
                    showNoteSaveProblem = false
                    noteSaveProblemMessage = ""

                    guard let ownerUID = noteEditorOwnerUID,
                          currentNoteUserID() == ownerUID else {
                        noteSaveProblemMessage = tr(
                            "החשבון השתנה. ההערה לא נשמרה.",
                            "The account changed. The note was not saved."
                        )
                        showNoteSaveProblem = true
                        return
                    }

                    if let identity = compatibleNoteIdentity(
                        belt: context.belt,
                        item: context.item
                    ),
                    case .conflict = exerciseNotes.loadCompatible(
                        userID: ownerUID,
                        beltID: context.belt.id,
                        identity: identity
                    ) {
                        noteSaveProblemMessage = tr(
                            "נמצאו הערות שונות לתרגיל. ההערות הקיימות לא שונו.",
                            "Different notes were found for this exercise. Existing notes were not changed."
                        )
                        showNoteSaveProblem = true
                        return
                    }

                    saveNote(
                        belt: context.belt,
                        item: context.item,
                        value: noteText
                    )
                },
                shouldDismissAfterSave: {
                    !showNoteSaveProblem
                }
            )
            .alert(
                tr(
                    "לא ניתן לשמור את ההערה",
                    "Unable to save note"
                ),
                isPresented: $showNoteSaveProblem
            ) {
                Button(
                    tr("אישור", "OK"),
                    role: .cancel
                ) {}
            } message: {
                Text(noteSaveProblemMessage)
            }
        }
        .alert(
            tr("לא ניתן לעדכן הערה", "Unable to update note"),
            isPresented: $showNoteProblem
        ) {
            Button(tr("אישור", "OK"), role: .cancel) {}
        } message: {
            Text(noteProblemMessage)
        }
    }

    private var screenTopTitleBar: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 44)

            Text(uiSubjectTitle())
                .font(.system(size: 27, weight: .black))
                .foregroundStyle(Color(red: 0.08, green: 0.11, blue: 0.18))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 44)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color.clear)
    }
    
    @ViewBuilder
    private var subjectStatsHeader: some View {
        if isCoachUser {
            coachStatsHeader
        } else {
            traineeStatsHeader
        }
    }

    private var coachStatsHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                subjectStatChip(
                    title: tr("לא סומן", "Unmarked"),
                    value: coachUnmarkedCount(belt: selectedBelt),
                    tint: KmiAppTheme.onSurfaceVariant(
                        for: colorScheme
                    )
                )

                subjectStatChip(
                    title: tr("לחיזוק", "Reinforcement"),
                    value: coachStatusCount(
                        belt: selectedBelt,
                        status: .needsReinforcement
                    ),
                    tint: KmiAppTheme.warning(for: colorScheme)
                )

                subjectStatChip(
                    title: tr("תורגל", "Practiced"),
                    value: coachStatusCount(
                        belt: selectedBelt,
                        status: .practiced
                    ),
                    tint: KmiAppTheme.primary(for: colorScheme)
                )

                subjectStatChip(
                    title: tr("נלמד", "Taught"),
                    value: coachStatusCount(
                        belt: selectedBelt,
                        status: .taught
                    ),
                    tint: Color(
                        red: 22.0 / 255.0,
                        green: 163.0 / 255.0,
                        blue: 106.0 / 255.0
                    )
                )
            }
            .environment(
                \.layoutDirection,
                screenLayoutDirection
            )
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(
                KmiAppTheme.surfaceVariant(
                    for: colorScheme
                ).opacity(0.55)
            )

            Rectangle()
                .fill(
                    selectedBelt == .black && colorScheme == .dark
                        ? Color.white.opacity(0.75)
                        : KmiBeltPalette.color(
                            for: selectedBelt
                        ).opacity(0.75)
                )
                .frame(height: 2)
        }
    }

    private var traineeStatsHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                subjectStatChip(
                    title: tr("לא סומן", "Unmarked"),
                    value: unmarkedCount(belt: selectedBelt),
                    tint: Color(
                        red: 100.0 / 255.0,
                        green: 116.0 / 255.0,
                        blue: 139.0 / 255.0
                    )
                )

                subjectStatChip(
                    title: tr("חלקי", "Partial"),
                    value: markCount(
                        belt: selectedBelt,
                        state: .partiallyKnown
                    ),
                    tint: KmiAppTheme.warning(
                        for: colorScheme
                    )
                )

                subjectStatChip(
                    title: tr("לא יודע", "Unknown"),
                    value: markCount(
                        belt: selectedBelt,
                        state: .dontKnow
                    ),
                    tint: Color(
                        red: 239.0 / 255.0,
                        green: 68.0 / 255.0,
                        blue: 68.0 / 255.0
                    )
                )

                subjectStatChip(
                    title: tr("יודע", "Known"),
                    value: markCount(
                        belt: selectedBelt,
                        state: .know
                    ),
                    tint: Color(
                        red: 22.0 / 255.0,
                        green: 163.0 / 255.0,
                        blue: 106.0 / 255.0
                    )
                )
            }
            .environment(
                \.layoutDirection,
                screenLayoutDirection
            )
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(
                KmiAppTheme.surfaceVariant(
                    for: colorScheme
                ).opacity(0.55)
            )

            Rectangle()
                .fill(
                    selectedBelt == .black &&
                    colorScheme == .dark
                        ? Color.white.opacity(0.75)
                        : KmiBeltPalette.color(
                            for: selectedBelt
                        ).opacity(0.75)
                )
                .frame(height: 2)
        }
    }

    private func subjectStatChip(
        title: String,
        value: Int,
        tint: Color
    ) -> some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .kmiFont(size: 18, weight: .bold)

            Text(title)
                .kmiFont(size: 11, weight: .bold)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 3)
        .padding(.top, 3)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 58)
        .background(
            KmiAppTheme.surface(for: colorScheme)
        )
        .overlay {
            LinearGradient(
                colors: [
                    tint.opacity(
                        colorScheme == .dark ? 0.03 : 0.06
                    ),
                    tint.opacity(
                        colorScheme == .dark ? 0.18 : 0.14
                    )
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(tint.opacity(0.85))
                .frame(height: 3)
                .allowsHitTesting(false)
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: 10,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 10,
                style: .continuous
            )
            .stroke(
                tint.opacity(
                    colorScheme == .dark ? 0.55 : 0.24
                ),
                lineWidth: 1
            )
            .allowsHitTesting(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(value)")
    }

    private func beltSectionHeader(_ belt: Belt, count: Int) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                if isEnglish {
                    beltHeaderIcon(belt)

                    Text(beltTitleText(belt))
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(beltAccent(belt))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(exercisesCountText(count))
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(beltAccent(belt))
                } else {
                    Text(exercisesCountText(count))
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(beltAccent(belt))

                    Text(beltTitleText(belt))
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(beltAccent(belt))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    beltHeaderIcon(belt)
                }
            }
            .environment(\.layoutDirection, .leftToRight)

            Text(tr("←→ הזז לצד כדי לראות עוד נתונים ←→", "←→ Swipe sideways to see more data ←→"))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.56))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    beltStatBox(
                        title: tr("יודע", "Know"),
                        value: "\(markCount(belt: belt, state: .know))",
                        fill: Color(red: 0.46, green: 0.78, blue: 0.55)
                    )

                    beltStatBox(
                        title: tr("לא יודע", "Don't know"),
                        value: "\(markCount(belt: belt, state: .dontKnow))",
                        fill: Color(red: 0.94, green: 0.58, blue: 0.38)
                    )

                    beltStatBox(
                        title: tr("מועדפים", "Favorites"),
                        value: "\(favoriteCount(belt: belt))",
                        fill: Color(red: 0.88, green: 0.45, blue: 0.66)
                    )

                    beltStatBox(
                        title: tr("מוחרגים", "Excluded"),
                        value: "\(excludedCount(belt: belt))",
                        fill: Color(red: 0.86, green: 0.42, blue: 0.50)
                    )
                    
                    beltStatBox(
                        title: tr("לא סומן", "Unmarked"),
                        value: "\(unmarkedCount(belt: belt))",
                        fill: Color(red: 0.84, green: 0.36, blue: 0.50)
                    )
                }
                .padding(.horizontal, 2)
            }
            .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }

    private func beltStatBox(
        title: String,
        value: String,
        fill: Color
    ) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.white)

            Text(title)
                .font(.system(size: 9.5, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(width: 70)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(fill.opacity(0.78))
        )
    }

    private func beltHeaderIcon(_ belt: Belt) -> some View {
        Circle()
            .fill(beltAccent(belt).opacity(0.16))
            .frame(width: 32, height: 32)
            .overlay(
                Circle()
                    .stroke(beltAccent(belt).opacity(0.22), lineWidth: 1)
            )
            .overlay(
                Text(beltShortBadgeText(belt))
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(beltAccent(belt))
                    .minimumScaleFactor(0.75)
            )
    }

    private func beltShortBadgeText(_ belt: Belt) -> String {
        switch belt {
        case .white:
            return isEnglish ? "W" : "ל"
        case .yellow:
            return isEnglish ? "Y" : "צ"
        case .orange:
            return isEnglish ? "O" : "כ"
        case .green:
            return isEnglish ? "G" : "י"
        case .blue:
            return isEnglish ? "B" : "כח"
        case .brown:
            return isEnglish ? "BR" : "ח"
        case .black:
            return isEnglish ? "BL" : "ש"
        default:
            return isEnglish ? "B" : "ח"
        }
    }

    private func sectionTitlePill(
        _ title: String,
        accent: Color
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .kmiIconSize(12)
                .fontWeight(.heavy)
                .foregroundStyle(
                    colorScheme == .dark
                        ? KmiAppTheme.onSurfaceVariant(
                            for: colorScheme
                        )
                        : accent
                )

            Text(uiSectionTitle(title))
                .kmiTypography(.caption)
                .fontWeight(.heavy)
                .foregroundStyle(
                    KmiAppTheme.onSurface(
                        for: colorScheme
                    )
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
        }
        .environment(
            \.layoutDirection,
            screenLayoutDirection
        )
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
            .fill(
                KmiAppTheme.surfaceVariant(
                    for: colorScheme
                )
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
            .stroke(
                KmiAppTheme.outlineVariant(
                    for: colorScheme
                ),
                lineWidth: 1
            )
        )
    }

    private func beltAnchorId(_ belt: Belt) -> String {
        "belt::\(belt.id)"
    }

    private func beltCardFill(_ belt: Belt) -> Color {
        switch belt {
        case .yellow:
            return Color(red: 1.00, green: 0.97, blue: 0.86)
        case .orange:
            return Color(red: 0.99, green: 0.93, blue: 0.84)
        case .green:
            return Color(red: 0.91, green: 0.97, blue: 0.91)
        case .blue:
            return Color(red: 0.90, green: 0.95, blue: 1.00)
        case .brown:
            return Color(red: 0.95, green: 0.91, blue: 0.86)
        case .black:
            return Color(red: 0.90, green: 0.90, blue: 0.92)
        default:
            return Color.white.opacity(0.94)
        }
    }

    private func beltAccent(_ belt: Belt) -> Color {
        KmiBeltPalette.color(for: belt)
    }

    private func markKey(
        belt: Belt,
        item: UiItem
    ) -> String {
        let topic = item.topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = item.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return "kmi.subject.mark.\(belt.id).\(topic).\(title)"
    }
    
    private func markState(
        belt: Belt,
        item: UiItem
    ) -> ExerciseMarkState {
        let key = markKey(belt: belt, item: item)

        if let state = exerciseMarks[key] {
            return state
        }

        if let raw = UserDefaults.standard.string(forKey: key),
           let savedState = ExerciseMarkState(rawValue: raw) {
            return savedState
        }

        return .unmarked
    }
    
        private func materialsMark(
            belt: Belt,
            item: UiItem
        ) -> MaterialsView.RowMark? {
            switch markState(belt: belt, item: item) {
            case .unmarked:
                return nil

            case .know:
                return .mastered

            case .partiallyKnown:
                return .partiallyKnown

            case .dontKnow:
                return .unknown
            }
        }

        private func traineeUpdatedAt(
            belt: Belt,
            item: UiItem
        ) -> Int64 {
            let timestamp = UserDefaults.standard.double(
                forKey: "\(markKey(belt: belt, item: item)).updatedAt"
            )

            guard timestamp.isFinite,
                  timestamp > 0,
                  timestamp < Double(Int64.max) / 1000 else {
                return 0
            }

            return Int64(timestamp * 1000)
        }

        private func saveMaterialsMark(
            _ selectedStatus: MaterialsView.RowMark?,
            belt: Belt,
            item: UiItem
        ) {
            let state: ExerciseMarkState

            switch selectedStatus {
            case .mastered:
                state = .know

            case .partiallyKnown:
                state = .partiallyKnown

            case .unknown:
                state = .dontKnow

            case nil:
                state = .unmarked
            }

            let key = markKey(belt: belt, item: item)
            let defaults = UserDefaults.standard

            exerciseMarks[key] = state

            /*
             * שומרים גם איפוס מפורש.
             * כך ניתן להבדיל בינו לבין תרגיל
             * שעדיין לא נשמר עבורו סימון.
             */
            defaults.set(state.rawValue, forKey: key)
            defaults.set(
                Date().timeIntervalSince1970,
                forKey: "\(key).updatedAt"
            )
        }
        
        private func subjectExerciseCard(
            belt: Belt,
            item: UiItem
        ) -> some View {
            let context = ExerciseMenuContext(
                belt: belt,
                item: item
            )

            let note = loadNote(
                belt: belt,
                item: item
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

            return MaterialsExerciseRow(
                title: uiExerciseTitle(item.displayName),
                beltColor: KmiBeltPalette.color(for: belt),
                isFavorite: isFavorite(belt: belt, item: item),
                isExcluded: isExcluded(belt: belt, item: item),
                mark: materialsMark(belt: belt, item: item),
                traineeUpdatedAt: traineeUpdatedAt(
                    belt: belt,
                    item: item
                ),
                coachProgress: materialsCoachProgress(
                    belt: belt,
                    item: item
                ),
                hasNote: !note.isEmpty,
                isCoach: isCoachUser,
                isEnglish: isEnglish,
                onToggleFavorite: {
                    toggleFavorite(belt: belt, item: item)
                },
                onToggleExcluded: {
                    toggleExcluded(belt: belt, item: item)
                },
                onShowInfo: {
                    activeInfoExercise = context
                },
                onEditNote: {
                    guard let userID = currentNoteUserID() else {
                        noteProblemMessage = tr(
                            "יש להתחבר כדי לערוך הערה.",
                            "Sign in to edit a note."
                        )
                        showNoteProblem = true
                        return
                    }

                    if let identity = compatibleNoteIdentity(
                        belt: belt,
                        item: item
                    ),
                    case .conflict = exerciseNotes.loadCompatible(
                        userID: userID,
                        beltID: belt.id,
                        identity: identity
                    ) {
                        noteProblemMessage = tr(
                            "נמצאו הערות שונות לתרגיל. לא בוצע שינוי בהערות.",
                            "Different notes were found for this exercise. No notes were changed."
                        )
                        showNoteProblem = true
                        return
                    }

                    noteEditorOwnerUID = userID
                    noteText = loadNote(belt: belt, item: item)
                    activeNoteExercise = context
                },
                onSelectTraineeStatus: { status in
                    saveMaterialsMark(
                        status,
                        belt: belt,
                        item: item
                    )
                },
                onSelectCoachStatus: { status in
                    switch status {
                    case .taught:
                        toggleCoachStatus(
                            .taught,
                            belt: belt,
                            item: item
                        )

                    case .practiced:
                        toggleCoachStatus(
                            .practiced,
                            belt: belt,
                            item: item
                        )

                    case .needsReinforcement:
                        toggleCoachStatus(
                            .needsReinforcement,
                            belt: belt,
                            item: item
                        )

                    case .notTaught:
                        break
                    }
                }
            )
        }

        private func materialsCoachProgress(
            belt: Belt,
            item: UiItem
        ) -> MaterialsView.CoachMaterialProgress {
            let selected = coachStatuses(belt: belt, item: item)
            let dates = coachDates(belt: belt, item: item)

            let mappings: [
                (
                    source: KmiCoachExerciseStatus,
                    target: MaterialsView.CoachMaterialStatus
                )
            ] = [
                (.taught, .taught),
                (.practiced, .practiced),
                (.needsReinforcement, .needsReinforcement)
            ]

            var statuses = Set<MaterialsView.CoachMaterialStatus>()
            var timestamps: [MaterialsView.CoachMaterialStatus: Int64] = [:]

            for mapping in mappings where selected.contains(mapping.source) {
                statuses.insert(mapping.target)

                if let date = dates[mapping.source] {
                    timestamps[mapping.target] = Int64(
                        date.timeIntervalSince1970 * 1000
                    )
                }
            }

            return MaterialsView.CoachMaterialProgress(
                selectedStatuses: statuses,
                updatedAtByStatus: timestamps
            )
        }

        private func preloadExerciseProgress() {
        let defaults = UserDefaults.standard

        var loadedMarks: [String: ExerciseMarkState] = [:]
        var loadedCoachStatuses:
            [String: Set<KmiCoachExerciseStatus>] = [:]
        var loadedCoachDates:
            [String: [KmiCoachExerciseStatus: Date]] = [:]

        for belt in belts {
            for item in allItemsForBelt(belt) {
                let traineeKey = markKey(
                    belt: belt,
                    item: item
                )

                let savedMark = defaults.string(
                    forKey: traineeKey
                )

                loadedMarks[traineeKey] = savedMark.flatMap {
                    ExerciseMarkState(rawValue: $0)
                } ?? .unmarked

                let coachKey = coachProgressKey(
                    belt: belt,
                    item: item
                )

                let savedStatuses = defaults.stringArray(
                    forKey: "\(coachKey).selected"
                ) ?? []

                let selected = Set(
                    savedStatuses.compactMap {
                        KmiCoachExerciseStatus(rawValue: $0)
                    }
                )

                var dates: [KmiCoachExerciseStatus: Date] = [:]

                for status in selected {
                    let timestamp = defaults.double(
                        forKey:
                            "\(coachKey).\(status.rawValue).updatedAt"
                    )

                    if timestamp.isFinite && timestamp > 0 {
                        dates[status] = Date(
                            timeIntervalSince1970: timestamp
                        )
                    }
                }

                loadedCoachStatuses[coachKey] = selected
                loadedCoachDates[coachKey] = dates
            }
        }

        exerciseMarks = loadedMarks
        coachDatesCache = loadedCoachDates
        coachStatusesCache = loadedCoachStatuses
    }

    private func allItemsForBelt(_ belt: Belt) -> [UiItem] {
        sections(for: belt).flatMap { $0.items }
    }

    private func markCount(
        belt: Belt,
        state: ExerciseMarkState
    ) -> Int {
        allItemsForBelt(belt).filter { item in
            markState(belt: belt, item: item) == state
        }.count
    }

    private func unmarkedCount(
        belt: Belt
    ) -> Int {
        markCount(belt: belt, state: .unmarked)
    }

    private func exerciseId(
        belt: Belt,
        item: UiItem
    ) -> String {
        markKey(belt: belt, item: item)
    }

    private func isFavorite(
        belt: Belt,
        item: UiItem
    ) -> Bool {
        exerciseFavorites.contains(
            item.rawItem ?? item.displayName
        )
    }

    private func isExcluded(
        belt: Belt,
        item: UiItem
    ) -> Bool {
        excludedExerciseIds.contains(
            exerciseId(belt: belt, item: item)
        )
    }
    
    private func favoritesStorageKey(for belt: Belt) -> String {
        "kmi.subject.favorites.\(belt.id)"
    }

    private func excludedStorageKey(for belt: Belt) -> String {
        "kmi.subject.excluded.\(belt.id)"
    }

    private func noteStorageKey(
        belt: Belt,
        item: UiItem
    ) -> String {
        "kmi.subject.note.\(exerciseId(belt: belt, item: item))"
    }

    private func currentNoteUserID() -> String? {
        #if canImport(FirebaseAuth)
        let uid = Auth.auth().currentUser?.uid
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return uid.isEmpty ? nil : uid
        #else
        return nil
        #endif
    }

    private func sharedNoteExerciseID(
        belt: Belt,
        item: UiItem
    ) -> String? {
        exerciseNotes.knownExerciseID(
            belt: belt,
            title: item.rawItem ?? item.displayName,
            topicKey: item.sourceTopicTitle
        )
    }

    private func compatibleNoteIdentity(
        belt: Belt,
        item: UiItem
    ) -> ExerciseIdentityResolverIOS.Identity? {
        guard let sourceTopic = item.sourceTopicTitle?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !sourceTopic.isEmpty,
              let resolved = ExerciseIdentityResolverIOS.resolve(
                belt: belt,
                topic: sourceTopic,
                rawItem: item.rawItem ?? item.displayName
              ) else {
            return nil
        }

        var previousIDs = resolved.previousIDs

        let localID =
            "subject-local:\(exerciseId(belt: belt, item: item))"

        if localID != resolved.primaryID {
            previousIDs.insert(localID)
        }

        if let previousKnownID = sharedNoteExerciseID(
            belt: belt,
            item: item
        ),
        previousKnownID != resolved.primaryID {
            previousIDs.insert(previousKnownID)
        }

        return ExerciseIdentityResolverIOS.Identity(
            primaryID: resolved.primaryID,
            displayTitle: resolved.displayTitle,
            previousIDs: previousIDs
        )
    }

    private func loadNote(
        belt: Belt,
        item: UiItem
    ) -> String {
        guard let userID = currentNoteUserID() else {
            return ""
        }

        if let identity = compatibleNoteIdentity(
            belt: belt,
            item: item
        ) {
            switch exerciseNotes.loadCompatible(
                userID: userID,
                beltID: belt.id,
                identity: identity
            ) {
            case .found(let value):
                return value

            case .missing, .conflict:
                return ""
            }
        }

        if let exerciseID = sharedNoteExerciseID(
            belt: belt,
            item: item
        ) {
            guard let userID = currentNoteUserID() else {
                return ""
            }

            return exerciseNotes.load(
                userID: userID,
                beltID: belt.id,
                exerciseID: exerciseID
            )
        }

        // לתרגיל לא מזוהה משתמשים במזהה המקומי של המסך,
        // אבל שומרים את ההערה בנפרד לכל משתמש.
        guard let userID = currentNoteUserID() else {
            return ""
        }

        return exerciseNotes.load(
            userID: userID,
            beltID: belt.id,
            exerciseID: "subject-local:\(exerciseId(belt: belt, item: item))"
        )
    }

    private func saveNote(
        belt: Belt,
        item: UiItem,
        value: String
    ) {
        if let userID = currentNoteUserID(),
           let identity = compatibleNoteIdentity(
                belt: belt,
                item: item
           ) {
            /*
             * המזהים הקודמים אינם נמחקים.
             * שמירה חדשה נכתבת למזהה הראשי בלבד.
             */
            exerciseNotes.save(
                value,
                userID: userID,
                beltID: belt.id,
                exerciseID: identity.primaryID
            )
            return
        }

        if let exerciseID = sharedNoteExerciseID(
            belt: belt,
            item: item
        ) {
            guard let userID = currentNoteUserID() else {
                return
            }

            exerciseNotes.save(
                value,
                userID: userID,
                beltID: belt.id,
                exerciseID: exerciseID
            )
            return
        }

        // גם הערה של תרגיל לא מזוהה מבודדת לפי המשתמש.
        guard let userID = currentNoteUserID() else {
            return
        }

        exerciseNotes.save(
            value,
            userID: userID,
            beltID: belt.id,
            exerciseID: "subject-local:\(exerciseId(belt: belt, item: item))"
        )
    }
    
    private func loadStringSet(_ key: String) -> Set<String> {
        let values = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(values)
    }

    private func saveStringSet(_ values: Set<String>, key: String) {
        UserDefaults.standard.set(Array(values), forKey: key)
    }
    
    private func toggleFavorite(
        belt: Belt,
        item: UiItem
    ) {
        exerciseFavorites.toggle(
            item.rawItem ?? item.displayName
        )
    }

    private func toggleExcluded(
        belt: Belt,
        item: UiItem
    ) {
        let id = exerciseId(belt: belt, item: item)
        let key = excludedStorageKey(for: belt)

        var values = loadStringSet(key)
        values.formSymmetricDifference([id])

        if values.contains(id) {
            excludedExerciseIds.insert(id)
        } else {
            excludedExerciseIds.remove(id)
        }

        saveStringSet(values, key: key)
    }
    
    private func favoriteCount(
        belt: Belt
    ) -> Int {
        allItemsForBelt(belt).filter {
            isFavorite(belt: belt, item: $0)
        }.count
    }

    private func excludedCount(
        belt: Belt
    ) -> Int {
        allItemsForBelt(belt).filter {
            isExcluded(belt: belt, item: $0)
        }.count
    }
    
    private func beltTitleText(_ belt: Belt) -> String {
        switch belt {
        case .white:
            return isEnglish ? "White Belt" : "חגורה לבנה"
        case .yellow:
            return isEnglish ? "Yellow Belt" : "חגורה צהובה"
        case .orange:
            return isEnglish ? "Orange Belt" : "חגורה כתומה"
        case .green:
            return isEnglish ? "Green Belt" : "חגורה ירוקה"
        case .blue:
            return isEnglish ? "Blue Belt" : "חגורה כחולה"
        case .brown:
            return isEnglish ? "Brown Belt" : "חגורה חומה"
        case .black:
            return isEnglish ? "Black Belt" : "חגורה שחורה"
        default:
            return isEnglish ? "Belt" : "חגורה"
        }
    }
}

private struct SubjectBeltPositionPreferenceKey:
    PreferenceKey {

    static let defaultValue: [Belt: CGFloat] = [:]

    static func reduce(
        value: inout [Belt: CGFloat],
        nextValue: () -> [Belt: CGFloat]
    ) {
        value.merge(
            nextValue(),
            uniquingKeysWith: { _, newValue in
                newValue
            }
        )
    }
}

struct ExerciseNoteSheet: View {
    let title: String
    @Binding var noteText: String
    let isEnglish: Bool
    let onSave: () -> Void
    var shouldDismissAfterSave: () -> Bool = { true }

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.colorScheme)
    private var colorScheme

    private var layoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KmiAppBackground()

                ScrollView {
                    VStack(spacing: 14) {
                        Text(title)
                            .kmiTypography(.body)
                            .fontWeight(.bold)
                            .foregroundStyle(
                                KmiAppTheme.onSurface(
                                    for: colorScheme
                                )
                            )
                            .multilineTextAlignment(textAlignment)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )

                        TextEditor(text: $noteText)
                            .kmiTypography(.body)
                            .foregroundStyle(
                                KmiAppTheme.onSurface(
                                    for: colorScheme
                                )
                            )
                            .multilineTextAlignment(textAlignment)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 220)
                            .padding(10)
                            .background(
                                KmiAppTheme.surface(
                                    for: colorScheme
                                )
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 14,
                                    style: .continuous
                                )
                            )
                            .overlay(
                                RoundedRectangle(
                                    cornerRadius: 14,
                                    style: .continuous
                                )
                                .stroke(
                                    KmiAppTheme.outlineVariant(
                                        for: colorScheme
                                    ),
                                    lineWidth: 1
                                )
                            )
                            .accessibilityLabel(
                                isEnglish
                                    ? "Exercise note"
                                    : "הערה לתרגיל"
                            )
                    }
                    .padding(18)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(
                isEnglish ? "Exercise note" : "הערה לתרגיל"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEnglish ? "Save" : "שמור") {
                        onSave()

                        if shouldDismissAfterSave() {
                            dismiss()
                        }
                    }
                    .kmiTypography(.body)
                    .fontWeight(.bold)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button(isEnglish ? "Close" : "סגור") {
                        dismiss()
                    }
                    .kmiTypography(.body)
                }
            }
        }
        .environment(\.layoutDirection, layoutDirection)
    }
}

// MARK: - Belt carousel (Snap + Center highlight)
private struct BeltCarousel: View {

    let belts: [Belt]
    @Binding var selectedBelt: Belt
    let isEnglish: Bool
    let hasContent: (Belt) -> Bool
    let onSelect: (Belt) -> Void

    @State private var scrollId: Belt?

    var body: some View {
        GeometryReader { outer in
            let midX = outer.frame(in: .global).midX

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: -10) {   // ✅ חפיפה (כמו גלגל)
                    ForEach(belts, id: \.self) { b in
                        BeltWheelItem(
                            belt: b,
                            selectedBelt: $selectedBelt,
                            enabled: hasContent(b),
                            midX: midX,
                            isEnglish: isEnglish
                        ) {
                            selectedBelt = b
                            scrollId = b
                            onSelect(b)
                        }
                        .id(b)
                    }
                }
                .padding(.horizontal, 22)
                .frame(height: 86) // ✅ מקום ל"קשת"
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollId, anchor: .center)
            .onAppear { scrollId = selectedBelt }
            .onChange(of: selectedBelt) { _, newValue in scrollId = newValue }
        }
        .frame(height: 90)
    }
}

// MARK: - Single item with arc effect
private struct BeltWheelItem: View {

    let belt: Belt
    @Binding var selectedBelt: Belt
    let enabled: Bool
    let midX: CGFloat
    let isEnglish: Bool
    let onTap: () -> Void

    private var isSelected: Bool { selectedBelt == belt }

    var body: some View {
        GeometryReader { geo in
            let x = geo.frame(in: .global).midX
            let dist = abs(x - midX)

            // ✅ נורמליזציה של המרחק (0 במרכז, 1+ בצד)
            let t = min(dist / 160.0, 1.0)

            // ✅ מרכז גדול, צדדים קטנים
            let scale = (1.18 - (t * 0.35))

            // ✅ קשת: צדדים "עולים" למעלה
            let y = -(t * 16.0)

            Button {
                guard enabled else { return }
                onTap()
            } label: {
                ZStack {
                    Circle()
                        .fill(beltColor(belt).opacity(isSelected ? 1.0 : 0.92))
                        .shadow(color: Color.black.opacity(isSelected ? 0.22 : 0.14),
                                radius: isSelected ? 10 : 7,
                                x: 0, y: isSelected ? 5 : 4)

                    // טבעת דקה כמו באנדרואיד
                    Circle()
                        .stroke(Color.black.opacity(0.18), lineWidth: 1)

                    Text(beltShortTitle(belt))
                        .font(
                            isEnglish
                            ? (isSelected ? .subheadline.weight(.heavy) : .caption.weight(.bold))
                            : (isSelected ? .headline.weight(.heavy) : .subheadline.weight(.bold))
                        )
                        .foregroundStyle(textColor(for: belt))
                        .minimumScaleFactor(0.82)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                }
                .frame(width: 60, height: 60)
                .opacity(enabled ? 1.0 : 0.30)
                .scaleEffect(scale)
                .offset(y: y)
                .animation(.easeInOut(duration: 0.16), value: isSelected)
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
        }
        .frame(width: 64, height: 86) // ✅ רוחב קטן + גובה לקשת
    }

    private func beltShortTitle(_ b: Belt) -> String {
        switch b {
        case .white:
            return isEnglish ? "WHT" : "לבן"

        case .yellow:
            return isEnglish ? "YLW" : "צהוב"

        case .orange:
            return isEnglish ? "ORG" : "כתום"

        case .green:
            return isEnglish ? "GRN" : "ירוק"

        case .blue:
            return isEnglish ? "BLU" : "כחול"

        case .brown:
            return isEnglish ? "BRN" : "חום"

        case .black:
            return isEnglish ? "BLK" : "שחור"

        default:
            return b.heb
        }
    }

    private func beltColor(_ b: Belt) -> Color {
        switch b {
        case .white:  return Color.white
        case .yellow: return Color(red: 0.98, green: 0.84, blue: 0.25)
        case .orange: return Color(red: 0.98, green: 0.62, blue: 0.20)
        case .green:  return Color(red: 0.20, green: 0.75, blue: 0.35)
        case .blue:   return Color(red: 0.22, green: 0.52, blue: 0.92)
        case .brown:  return Color(red: 0.55, green: 0.38, blue: 0.24)
        case .black:  return Color(red: 0.15, green: 0.15, blue: 0.16)
        default:      return Color.gray
        }
    }

    private func textColor(for b: Belt) -> Color {
        // טקסט כהה על לבן/צהוב/כתום, לבן על כחול/חום/שחור/ירוק
        switch b {
        case .white, .yellow, .orange:
            return Color.black.opacity(0.82)
        default:
            return Color.white.opacity(0.92)
        }
    }
}
