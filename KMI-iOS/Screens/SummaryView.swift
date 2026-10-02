import SwiftUI
import Shared

// MARK: - Summary models (file-scope)

// מצב הסימון של המתאמן.
enum SummaryMark: String {
    case done
    case partiallyKnown
    case notDone

    static func fromStoredValue(
        _ value: String
    ) -> SummaryMark? {

        switch value
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .lowercased() {

        case "done",
             "mastered",
             "known":
            return .done

        case "partiallyknown",
             "partially_known",
             "partial":
            return .partiallyKnown

        case "notdone",
             "not_done",
             "unknown":
            return .notDone

        default:
            return nil
        }
    }
}

/*
 * סטטוסי המאמן זהים לסטטוסים שנשמרים
 * מתוך MaterialsView.
 */
enum SummaryCoachStatus: String, CaseIterable {
    case notTaught = "not_taught"
    case taught = "taught"
    case practiced = "practiced"
    case needsReinforcement =
        "needs_reinforcement"

    static func fromStoredValue(
        _ value: String?
    ) -> SummaryCoachStatus {
        guard let value else {
            return .notTaught
        }

        return SummaryCoachStatus(
            rawValue: value
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()
        ) ?? .notTaught
    }
}

struct SummaryRowItem: Identifiable {
    let id: String
    let title: String
    let subTopicTitle: String?
    let indexInStatusGroup: Int

    /*
     * mark משמש את המתאמן.
     *
     * במצב מאמן ניתן לבחור עד שני סטטוסים
     * מתוך:
     * נלמד / תורגל / נדרש חיזוק.
     *
     * Set ריק = לא נלמד.
     */
    let mark: SummaryMark?

    let coachStatuses:
        Set<SummaryCoachStatus>
}

struct SummaryTopicBlock: Identifiable {
    let id: String
    let title: String
    let items: [SummaryRowItem]

    var doneCount: Int {
        items.filter {
            $0.mark == .done
        }
        .count
    }

    var partiallyKnownCount: Int {
        items.filter {
            $0.mark == .partiallyKnown
        }
        .count
    }

    var notDoneCount: Int {
        items.filter {
            $0.mark == .notDone
        }
        .count
    }

    var coachNotTaughtCount: Int {
        items.filter {
            $0.coachStatuses.isEmpty
        }
        .count
    }

    var coachTaughtCount: Int {
        items.filter {
            $0.coachStatuses.contains(
                .taught
            )
        }
        .count
    }

    var coachPracticedCount: Int {
        items.filter {
            $0.coachStatuses.contains(
                .practiced
            )
        }
        .count
    }

    var coachNeedsReinforcementCount: Int {
        items.filter {
            $0.coachStatuses.contains(
                .needsReinforcement
            )
        }
        .count
    }

    /*
     * חשוב:
     * תרגיל עם שני סטטוסים נספר כאן פעם אחת בלבד.
     */
    var coachMarkedCount: Int {
        items.filter {
            !$0.coachStatuses.isEmpty
        }
        .count
    }

    var totalCount: Int {
        items.count
    }

    func percent(
        isCoach: Bool
    ) -> Int {
        guard totalCount > 0 else {
            return 0
        }

        let completedCount =
            isCoach
            ? coachMarkedCount
            : doneCount

        return Int(
            round(
                (
                    Double(completedCount)
                    / Double(totalCount)
                ) * 100.0
            )
        )
    }
}

struct SummaryView: View {
    let belt: Belt
    var topic: String? = nil
    var subTopic: String? = nil
    
    @ObservedObject var nav: AppNavModel
    @Environment(\.colorScheme)
    private var colorScheme

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var summaryPrimaryTextColor: Color {
        isDarkMode
            ? Color.white.opacity(0.94)
            : Color.black.opacity(0.84)
    }

    private var summarySecondaryTextColor: Color {
        isDarkMode
            ? Color.white.opacity(0.64)
            : Color.black.opacity(0.56)
    }

    @State private var showProgressCard: Bool = false
    @State private var showComparisonCard: Bool = false
    @State private var marksRevision: Int = 0

    @State private var cachedBlocks: [SummaryTopicBlock] = []
    @State private var isSummaryLoading: Bool = true

    @State private var comparisonTraineesCount: Int = 0
    @State private var comparisonAveragePercent: Int = 0
    @State private var comparisonBetterThanPercent: Int = 0
    @State private var isComparisonLoading: Bool = false

    /*
     * שגיאת טעינת ההשוואה נשמרת בנפרד
     * ממצב שבו באמת אין מספיק נתונים.
     */
    @State private var comparisonHasError: Bool = false

    /*
     * נתוני הקבוצות של המאמן נטענים דרך
     * UserProgressRepository הגלובלי.
     */
    @State private var coachGroupProgress:
        CoachGroupProgressSummary?

    @State private var coachGroupProgressLoaded:
        Bool = false

    /*
     * שגיאת טעינה נשמרת בנפרד ממצב
     * שבו באמת אין נתונים.
     */
    @State private var coachGroupProgressHasError:
        Bool = false

    /*
     * התפקיד שעבורו נטען הסיכום הנוכחי.
     * משמש לניקוי מוחלט במעבר בין מאמן למתאמן.
     */
    @State private var loadedSummaryRoleId: String = ""

    @AppStorage("kmi_app_language")
    private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"
    @AppStorage("selected_language_code") private var selectedLanguageCode: String = "he"

    private var effectiveLanguageCode: String {
        let values = [
            kmiAppLanguageCode,
            selectedLanguageCode,
            appLanguageRaw,
            initialLanguageCode
        ]

        for raw in values {
            let clean = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            if clean == "en" || clean == "english" {
                return "en"
            }

            if clean == "he" || clean == "hebrew" || clean == "עברית" {
                return "he"
            }
        }

        return "he"
    }

    private var isEnglish: Bool {
        effectiveLanguageCode == "en"
    }

    private var screenLayoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    private var screenTextAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var screenFrameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private func tr(
        _ he: String,
        _ en: String
    ) -> String {
        isEnglish ? en : he
    }
    
    /*
     * מקור האמת לתפקיד הפעיל זהה לזה
     * שבו משתמש MaterialsView.
     */
    private var effectiveIsCoach: Bool {
        let defaults =
            UserDefaults.standard

        let rawRole =
            defaults.string(
                forKey: "user_role"
            )
            ?? defaults.string(
                forKey: "role"
            )
            ?? ""

        switch rawRole
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased() {

        case "coach",
             "trainer",
             "מאמן",
             "מדריך":
            return true

        case "trainee",
             "student",
             "מתאמן":
            return false

        default:
            return false
        }
    }

    /*
     * מזהה מקומי של מצב הסיכום הפעיל.
     * משמש רק לזיהוי מעבר בין מאמן למתאמן
     * ולא כמפתח Firestore.
     */
    private var summaryRoleId: String {
        effectiveIsCoach
            ? "coach"
            : "trainee"
    }

    private func normalizedSummaryText(
        _ value: String
    ) -> String {
        value
            .replacingOccurrences(of: "\u{200F}", with: "")
            .replacingOccurrences(of: "\u{200E}", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "־", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )
            .lowercased()
    }

    private func summarySafePart(_ value: String) -> String {
        normalizedSummaryText(value)
    }

    private func loadMark(
        topicTitle: String,
        subTopicTitle: String?,
        item: String,
        index: Int
    ) -> SummaryMark? {
        let defaults = UserDefaults.standard

        let beltId = belt.id
        let cleanTopic = summarySafePart(topicTitle)
        let cleanSubTopic = subTopicTitle.map(summarySafePart) ?? ""
        let cleanItem = summarySafePart(item)

        let topicKey = cleanSubTopic.isEmpty
            ? cleanTopic
            : "\(cleanTopic)__\(cleanSubTopic)"

        let directStringKeys = [
            "mark.status_\(beltId)_\(topicTitle)_\(index)_\(item)",
            "mark.status_\(beltId)_\(topicTitle)_\(index)_\(cleanItem)",

            "mark.status_\(beltId)_\(topicKey)_\(index)_\(item)",
            "mark.status_\(beltId)_\(topicKey)_\(index)_\(cleanItem)",

            "kmi.mark.\(beltId).\(topicTitle).\(item)",
            "kmi.mark.\(beltId).\(cleanTopic).\(cleanItem)",
            "kmi.mark.\(beltId).\(topicKey).\(cleanItem)"
        ]

        for key in directStringKeys {
            if let raw = defaults.string(forKey: key),
               let mark = SummaryMark.fromStoredValue(raw) {
                return mark
            }
        }

        let directBoolKeys = [
            "exercise_\(beltId)_\(item)",
            "exercise_\(beltId)_\(cleanItem)",

            "status_\(beltId)_\(topicTitle)_\(index)_\(item)",
            "status_\(beltId)_\(topicTitle)_\(index)_\(cleanItem)",

            "status_\(beltId)_\(topicKey)_\(index)_\(item)",
            "status_\(beltId)_\(topicKey)_\(index)_\(cleanItem)",

            "\(beltId)_\(topicTitle)_\(item)",
            "\(beltId)_\(topicKey)_\(item)",
            "\(beltId)_\(cleanTopic)_\(cleanItem)",
            "\(beltId)_\(topicKey)_\(cleanItem)"
        ]

        for key in directBoolKeys {
            if defaults.object(forKey: key) != nil {
                return defaults.bool(forKey: key) ? .done : .notDone
            }
        }

        for entry in defaults.dictionaryRepresentation() {
            let normalizedKey = summarySafePart(entry.key)

            guard normalizedKey.contains(beltId),
                  normalizedKey.contains(cleanItem) else {
                continue
            }

            if let raw = entry.value as? String,
               let mark = SummaryMark.fromStoredValue(raw) {
                return mark
            }

            if let boolValue = entry.value as? Bool {
                return boolValue ? .done : .notDone
            }
        }

        return nil
    }

    /*
     * נורמליזציה זהה לזו שבה משתמש
     * statusIdForStorage בתוך MaterialsView.
     *
     * כאן לא הופכים את הטקסט לאותיות קטנות,
     * כדי שמפתח השמירה יישאר זהה לחלוטין.
     */
    private func normalizeCoachStatusPart(
        _ value: String
    ) -> String {
        value
            .replacingOccurrences(
                of: "\u{200F}",
                with: ""
            )
            .replacingOccurrences(
                of: "\u{200E}",
                with: ""
            )
            .replacingOccurrences(
                of: "\u{00A0}",
                with: " "
            )
            .replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
    }

    private func coachTopicKey(
        topicTitle: String,
        subTopicTitle: String?
    ) -> String {
        let cleanTopic =
            topicTitle.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let cleanSubTopic =
            subTopicTitle?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            ?? ""

        if cleanSubTopic.isEmpty {
            return cleanTopic
        }

        return "\(cleanTopic)__\(cleanSubTopic)"
    }

    private func coachStatusId(
        topicTitle: String,
        subTopicTitle: String?,
        item: String,
        index: Int
    ) -> String {
        let topicKey =
            coachTopicKey(
                topicTitle: topicTitle,
                subTopicTitle: subTopicTitle
            )

        let cleanItem =
            normalizeCoachStatusPart(item)

        return [
            "status",
            belt.id,
            topicKey,
            String(index),
            cleanItem
        ]
        .joined(separator: "_")
    }

    private func loadCoachStatuses(
        topicTitle: String,
        subTopicTitle: String?,
        item: String,
        index: Int
    ) -> Set<SummaryCoachStatus> {

        let topicKey =
            coachTopicKey(
                topicTitle:
                    topicTitle,
                subTopicTitle:
                    subTopicTitle
            )

        let statusId =
            coachStatusId(
                topicTitle:
                    topicTitle,
                subTopicTitle:
                    subTopicTitle,
                item:
                    item,
                index:
                    index
            )

        /*
         * אותו base key בדיוק של MaterialsView.
         */
        let baseKey =
            [
                "coach_material_progress",
                belt.id,
                topicKey,
                statusId
            ]
            .joined(
                separator:
                    "_"
            )

        let defaults =
            UserDefaults.standard

        let selectableStatuses:
            [SummaryCoachStatus] = [
                .taught,
                .practiced,
                .needsReinforcement
            ]

        let selectedStatuses =
            selectableStatuses.filter {
                status in

                defaults.bool(
                    forKey:
                        "\(baseKey)_\(status.rawValue)_selected"
                )
            }

        /*
         * המבנה החדש קיים.
         */
        if !selectedStatuses.isEmpty {

            return Set(
                selectedStatuses.prefix(
                    2
                )
            )
        }

        /*
         * fallback לנתונים הישנים:
         * <baseKey>_status
         */
        let legacyStatus =
            SummaryCoachStatus
                .fromStoredValue(
                    defaults.string(
                        forKey:
                            "\(baseKey)_status"
                    )
                )

        if legacyStatus ==
            .notTaught {

            return []
        }

        return [
            legacyStatus
        ]
    }

    // MARK: - Model for UI

    private struct SummaryRawItem {
        let title: String
        let subTopicTitle: String?
        let indexInStatusGroup: Int
    }

    private struct SummaryRawTopic {
        let title: String
        let items: [SummaryRawItem]
    }

    private var catalogTopics: [SummaryRawTopic] {
        _ = marksRevision

        let requestedTopics =
            TopicsEngine.shared
                .topicTitlesFor(
                    belt:
                        belt
                )

        return requestedTopics
            .map { title in
                let cleanTitle =
                    title.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                var allItems:
                    [SummaryRawItem] = []

                let directItems =
                    ContentRepo.shared.getAllItemsFor(
                        belt:
                            belt,
                        topicTitle:
                            cleanTitle,
                        subTopicTitle:
                            nil
                    )

                let subTopicTitles =
                    ContentRepo.shared
                        .getSubTopicsFor(
                            belt:
                                belt,
                            topicTitle:
                                cleanTitle
                        )
                        .map {
                            $0.title
                                .trimmingCharacters(
                                    in:
                                        .whitespacesAndNewlines
                                )
                        }
                        .filter {
                            !$0.isEmpty
                        }

                /*
                 * קודם טוענים את תתי־הנושאים.
                 *
                 * getAllItemsFor(..., subTopicTitle: nil)
                 * עשוי לכלול גם את אותם תרגילים,
                 * ולכן אסור להוסיף אותו ראשון.
                 */
                var subTopicItemKeys =
                    Set<String>()

                for subTopicTitle in
                    subTopicTitles {

                    let subItems =
                        ContentRepo.shared
                            .getAllItemsFor(
                                belt:
                                    belt,
                                topicTitle:
                                    cleanTitle,
                                subTopicTitle:
                                    subTopicTitle
                            )

                    for (
                        index,
                        item
                    ) in subItems.enumerated() {

                        let cleanItem =
                            item.trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )

                        guard !cleanItem.isEmpty else {
                            continue
                        }

                        let itemKey =
                            normalizedSummaryText(
                                cleanItem
                            )

                        /*
                         * אותו תרגיל נכנס פעם אחת בלבד,
                         * תוך שמירת תת־הנושא האמיתי שלו.
                         */
                        guard subTopicItemKeys.insert(
                            itemKey
                        ).inserted else {
                            continue
                        }

                        allItems.append(
                            SummaryRawItem(
                                title:
                                    cleanItem,
                                subTopicTitle:
                                    subTopicTitle,
                                indexInStatusGroup:
                                    index
                            )
                        )
                    }
                }

                /*
                 * מוסיפים גם תרגילים ישירים של הנושא
                 * שאינם קיימים כבר בתתי־הנושאים.
                 */
                for (
                    index,
                    item
                ) in directItems.enumerated() {

                    let cleanItem =
                        item.trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )

                    guard !cleanItem.isEmpty else {
                        continue
                    }

                    let itemKey =
                        normalizedSummaryText(
                            cleanItem
                        )

                    guard !subTopicItemKeys.contains(
                        itemKey
                    ) else {
                        continue
                    }

                    allItems.append(
                        SummaryRawItem(
                            title:
                                cleanItem,
                            subTopicTitle:
                                nil,
                            indexInStatusGroup:
                                index
                        )
                    )
                }

                return SummaryRawTopic(
                    title: cleanTitle,
                    items: allItems
                )
            }
    }
    
    private var blocks: [SummaryTopicBlock] {
        cachedBlocks
    }

    private func buildSummaryBlocks() -> [SummaryTopicBlock] {
        catalogTopics.map { topicBlock in
            var seen = Set<String>()

            let uniqueItems =
                topicBlock.items
                    .map { raw in
                        SummaryRawItem(
                            title:
                                raw.title.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                ),
                            subTopicTitle:
                                raw.subTopicTitle,
                            indexInStatusGroup:
                                raw.indexInStatusGroup
                        )
                    }
                    .filter {
                        !$0.title.isEmpty
                    }
                    .filter { raw in
                        let uniqueKey = [
                            raw.subTopicTitle ?? "",
                            raw.title
                        ]
                        .joined(separator: "||")

                        return seen.insert(uniqueKey).inserted
                    }

            let rows: [SummaryRowItem] =
                uniqueItems.map { raw in
                    let mark =
                        loadMark(
                            topicTitle: topicBlock.title,
                            subTopicTitle:
                                raw.subTopicTitle,
                            item: raw.title,
                            index:
                                raw.indexInStatusGroup
                        )

                    let coachStatuses =
                        loadCoachStatuses(
                            topicTitle:
                                topicBlock.title,
                            subTopicTitle:
                                raw.subTopicTitle,
                            item:
                                raw.title,
                            index:
                                raw.indexInStatusGroup
                        )

                    return SummaryRowItem(
                        id:
                            "\(topicBlock.title)||"
                            + "\(raw.subTopicTitle ?? "")||"
                            + raw.title,
                        title:
                            raw.title,
                        subTopicTitle:
                            raw.subTopicTitle,
                        indexInStatusGroup:
                            raw.indexInStatusGroup,
                        mark:
                            mark,
                        coachStatuses:
                            coachStatuses
                    )
                }

            return SummaryTopicBlock(
                id: topicBlock.title,
                title: topicBlock.title,
                items: rows
            )
        }
    }
    
    private var totalCount: Int {
        blocks.reduce(0) {
            $0 + $1.totalCount
        }
    }

    private var doneCount: Int {
        blocks.reduce(0) {
            $0 + $1.doneCount
        }
    }

    private var partiallyKnownCount: Int {
        blocks.reduce(0) {
            $0 + $1.partiallyKnownCount
        }
    }

    private var notDoneCount: Int {
        blocks.reduce(0) {
            $0 + $1.notDoneCount
        }
    }

    private var coachNotTaughtCount: Int {
        blocks.reduce(0) {
            $0 + $1.coachNotTaughtCount
        }
    }

    private var coachTaughtCount: Int {
        blocks.reduce(0) {
            $0 + $1.coachTaughtCount
        }
    }

    private var coachPracticedCount: Int {
        blocks.reduce(0) {
            $0 + $1.coachPracticedCount
        }
    }

    private var coachNeedsReinforcementCount: Int {
        blocks.reduce(0) {
            $0 + $1.coachNeedsReinforcementCount
        }
    }

    private var coachMarkedCount: Int {
        blocks.reduce(0) {
            $0 + $1.coachMarkedCount
        }
    }

    /*
     * לצורך טבעת ההתקדמות בלבד כל תרגיל מאמן
     * נכנס לקטגוריה אחת.
     *
     * עדיפות זהה ל-Android:
     * חיזוק ← תורגל ← נלמד.
     *
     * הספירות הרגילות למעלה נשארות ללא שינוי,
     * ולכן תרגיל עם שני סטטוסים עדיין מופיע
     * בשני מוני הסטטוסים הרלוונטיים.
     */
    private var coachMeterReinforcementCount: Int {
        blocks.reduce(0) {
            result,
            block in

            result
            + block.items.filter {
                $0.coachStatuses.contains(
                    .needsReinforcement
                )
            }
            .count
        }
    }

    private var coachMeterPracticedCount: Int {
        blocks.reduce(0) {
            result,
            block in

            result
            + block.items.filter {
                !$0.coachStatuses.contains(
                    .needsReinforcement
                )
                && $0.coachStatuses.contains(
                    .practiced
                )
            }
            .count
        }
    }

    private var coachMeterTaughtCount: Int {
        blocks.reduce(0) {
            result,
            block in

            result
            + block.items.filter {
                !$0.coachStatuses.contains(
                    .needsReinforcement
                )
                && !$0.coachStatuses.contains(
                    .practiced
                )
                && $0.coachStatuses.contains(
                    .taught
                )
            }
            .count
        }
    }

    private var markedCount: Int {
        effectiveIsCoach
            ? coachMarkedCount
            : doneCount
                + partiallyKnownCount
                + notDoneCount
    }

    private var remainingCount: Int {
        effectiveIsCoach
            ? coachNotTaughtCount
            : max(
                totalCount - markedCount,
                0
            )
    }

    private var percentAll: Int {
        guard totalCount > 0 else {
            return 0
        }

        let completedCount =
            effectiveIsCoach
            ? coachMarkedCount
            : doneCount

        return Int(
            round(
                (
                    Double(completedCount)
                    / Double(totalCount)
                ) * 100.0
            )
        )
    }

    private var markedPercentAll: Int {
        guard totalCount > 0 else {
            return 0
        }

        return Int(
            round(
                (
                    Double(markedCount)
                    / Double(totalCount)
                ) * 100.0
            )
        )
    }
    
    private var comparisonHasEnoughData: Bool {
        comparisonTraineesCount >= 2
    }

    private var comparisonStatusText: String {

        if isComparisonLoading {

            return tr(
                "טוען נתוני השוואה...",
                "Loading comparison data..."
            )
        }

        if comparisonHasError {

            return tr(
                "לא ניתן לטעון כרגע את נתוני ההשוואה. נסה שוב מאוחר יותר.",
                "Comparison data cannot be loaded right now. Please try again later."
            )
        }

        guard comparisonHasEnoughData else {

            return tr(
                "אין עדיין מספיק נתונים להשוואה מול מתאמנים אחרים.",
                "There is not enough data yet to compare with other trainees."
            )
        }

        if percentAll >=
            comparisonAveragePercent {

            return tr(
                "אתה מעל \(comparisonBetterThanPercent)% מהמתאמנים בחגורה שלך.",
                "You are above \(comparisonBetterThanPercent)% of trainees in your belt."
            )
        }

        return tr(
            "אתה מתחת לממוצע המתאמנים בחגורה שלך.",
            "You are below the average for trainees in your belt."
        )
    }

    private func loadCoachGroupProgress() {

        coachGroupProgressLoaded =
            false

        coachGroupProgress =
            nil

        coachGroupProgressHasError =
            false

        Task {

            do {

                let result =
                    try await UserProgressRepository
                        .loadCoachGroupsBeltProgress(
                            beltId:
                                belt.id
                        )

                await MainActor.run {

                    coachGroupProgress =
                        result

                    coachGroupProgressHasError =
                        false

                    coachGroupProgressLoaded =
                        true
                }

            } catch {

                /*
                 * לא מציגים Exception גולמי של
                 * Firestore למשתמש, אבל גם לא
                 * הופכים שגיאת טעינה ל"אין נתונים".
                 */
                await MainActor.run {

                    coachGroupProgress =
                        nil

                    coachGroupProgressHasError =
                        true

                    coachGroupProgressLoaded =
                        true
                }
            }
        }
    }
        
    private func saveCalculatedProgress() {

        let cleanTopic =
            topic?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        let cleanSubTopic =
            subTopic?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        /*
         * userProgress/{uid}__{beltId}
         * מייצג את כל חומר החגורה.
         *
         * לכן אסור לסיכום של נושא/תת־נושא
         * לדרוס אותו בנתוני scope חלקיים.
         */
        guard
            !effectiveIsCoach,
            cleanTopic.isEmpty,
            cleanSubTopic.isEmpty,
            totalCount > 0
        else {
            return
        }

        let currentBeltId =
            belt.id

        let currentKnownPercent =
            percentAll

        let currentKnownCount =
            doneCount

        let currentTotalCount =
            totalCount

        Task {

            /*
             * שמירה בלבד.
             * כשל רשת אינו משנה את מצב המסך
             * ואינו מוצג כ-Exception למשתמש.
             */
            try? await UserProgressRepository
                .saveUserProgress(
                    beltId:
                        currentBeltId,
                    knownPercent:
                        currentKnownPercent,
                    knownCount:
                        currentKnownCount,
                    totalCount:
                        currentTotalCount
                )
        }
    }

    private func saveProgressAndLoadComparison() {

        let cleanTopic =
            topic?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        let cleanSubTopic =
            subTopic?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        guard
            cleanTopic.isEmpty,
            cleanSubTopic.isEmpty,
            totalCount > 0
        else {

            comparisonTraineesCount = 0
            comparisonAveragePercent = 0
            comparisonBetterThanPercent = 0
            isComparisonLoading = false

            return
        }

        comparisonHasError =
            false

        isComparisonLoading =
            true

        Task {

            do {

                /*
                 * השמירה וההשוואה עוברות דרך
                 * UserProgressRepository בלבד.
                 */
                try await UserProgressRepository
                    .saveUserProgress(
                        beltId:
                            belt.id,
                        knownPercent:
                            percentAll,
                        knownCount:
                            doneCount,
                        totalCount:
                            totalCount
                    )

                let comparison =
                    try await UserProgressRepository
                        .loadBeltComparison(
                            beltId:
                                belt.id,
                            userKnownPercent:
                                percentAll
                        )

                await MainActor.run {

                    comparisonTraineesCount =
                        comparison?
                            .usersCount
                        ?? 0

                    comparisonAveragePercent =
                        comparison?
                            .averageKnownPercent
                        ?? 0

                    comparisonBetterThanPercent =
                        comparison?
                            .percentileAbove
                        ?? 0

                    comparisonHasError =
                        false

                    isComparisonLoading =
                        false
                }

            } catch {

                /*
                 * שגיאת Firestore אינה מוצגת
                 * למשתמש כ-Exception גולמי.
                 */
                await MainActor.run {

                    comparisonTraineesCount =
                        0

                    comparisonAveragePercent =
                        0

                    comparisonBetterThanPercent =
                        0

                    comparisonHasError =
                        true

                    isComparisonLoading =
                        false
                }
            }
        }
    }

    private var summaryTitle: String {
        "\(tr("סיכום", "Summary")) "
        + beltDisplayTitleForSummary()
    }
    
    private func beltDisplayTitleForSummary() -> String {

        if isEnglish {

            switch belt {

            case .white:
                return "White Belt"

            case .yellow:
                return "Yellow Belt"

            case .orange:
                return "Orange Belt"

            case .green:
                return "Green Belt"

            case .blue:
                return "Blue Belt"

            case .brown:
                return "Brown Belt"

            case .black:
                return "Black Belt"

            default:
                return "Belt"
            }
        }

        let clean =
            belt.heb.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        if clean.hasPrefix(
            "חגורה"
        ) {
            return clean
        }

        return "חגורה \(clean)"
    }

    private func postSummaryTopTitleOverride() {
        NotificationCenter.default.post(
            name: Notification.Name("KMI_TOP_TITLE_OVERRIDE"),
            object: summaryTitle
        )
    }

    var body: some View {
        ZStack {
            KmiAppBackground()

            VStack(spacing: 0) {

                summaryTopControls

                ScrollView {
                    VStack(
                        spacing:
                            0
                    ) {

                        if showComparisonCard &&
                            effectiveIsCoach {

                            CoachGroupsProgressCardIOS(
                                summary:
                                    coachGroupProgress,
                                isLoaded:
                                    coachGroupProgressLoaded,
                                hasError:
                                    coachGroupProgressHasError,
                                beltAccent:
                                    beltAccentForSummary(),
                                isEnglish:
                                    isEnglish,
                                onClose: {
                                    showComparisonCard =
                                        false
                                }
                            )

                        } else if showComparisonCard {

                            BeltComparisonStatusCard(
                                traineesCount:
                                    comparisonTraineesCount,
                                averagePercent:
                                    comparisonAveragePercent,
                                userPercent:
                                    percentAll,
                                statusText:
                                    comparisonStatusText,
                                hasEnoughData:
                                    comparisonHasEnoughData,
                                isEnglish:
                                    isEnglish,
                                onClose: {
                                    showComparisonCard = false
                                }
                            )
                            .padding(.vertical, 16)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: 22,
                                    style: .continuous
                                )
                                .fill(
                                    isDarkMode
                                        ? Color(
                                            red: 0.055,
                                            green: 0.075,
                                            blue: 0.125
                                        )
                                        .opacity(0.98)
                                        : Color.white.opacity(0.96)
                                )
                            )
                            .overlay(
                                RoundedRectangle(
                                    cornerRadius: 22,
                                    style: .continuous
                                )
                                .stroke(
                                    isDarkMode
                                        ? Color.white.opacity(0.12)
                                        : Color.black.opacity(0.07),
                                    lineWidth: 1
                                )
                            )
                            .shadow(
                                color: Color.black.opacity(
                                    isDarkMode ? 0.24 : 0.10
                                ),
                                radius: 12,
                                x: 0,
                                y: 5
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .transition(
                                .opacity.combined(
                                    with: .move(edge: .top)
                                )
                            )
                        }
                        
                        if showProgressCard {
                            WhiteCard {
                                VStack(spacing: 10) {
                                    HStack {
                                        Spacer()

                                        Button {
                                            showProgressCard = false
                                        } label: {
                                            Image(systemName: "xmark")
                                                .kmiFont(
                                                    size: 13,
                                                    weight: .black
                                                )
                                                .foregroundStyle(
                                                    summarySecondaryTextColor
                                                )
                                                .frame(width: 32, height: 32)
                                                .background(
                                                    Circle()
                                                        .fill(
                                                            isDarkMode
                                                                ? Color.white.opacity(0.10)
                                                                : Color.black.opacity(0.06)
                                                        )
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    Text(
                                        tr(
                                            "מד התקדמות",
                                            "Progress meter"
                                        )
                                    )
                                    .kmiFont(
                                        size: 22,
                                        weight: .black
                                    )
                                    .foregroundStyle(
                                        summaryPrimaryTextColor
                                    )
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: screenFrameAlignment
                                    )
                                    .multilineTextAlignment(
                                        screenTextAlignment
                                    )
                                    
                                    ProgressRing(
                                        percent:
                                            markedPercentAll,
                                        doneCount:
                                            effectiveIsCoach
                                            ? coachMeterTaughtCount
                                            : doneCount,
                                        partiallyKnownCount:
                                            effectiveIsCoach
                                            ? coachMeterPracticedCount
                                            : partiallyKnownCount,
                                        notDoneCount:
                                            effectiveIsCoach
                                            ? coachMeterReinforcementCount
                                            : notDoneCount,
                                        remainingCount:
                                            remainingCount,
                                        totalCount:
                                            totalCount,
                                        isCoach:
                                            effectiveIsCoach,
                                        isEnglish:
                                            isEnglish
                                    )
                                    .frame(
                                        width: 194,
                                        height: 194
                                    )
                                    .padding(.vertical, 4)

                                    Text(
                                        isEnglish
                                        ? "Marked \(markedCount) of \(totalCount)"
                                        : "סומנו \(markedCount) מתוך \(totalCount)"
                                    )
                                    .kmiFont(
                                        size: 14,
                                        weight: .bold
                                    )
                                    .foregroundStyle(
                                        summarySecondaryTextColor
                                    )

                                    if effectiveIsCoach {
                                        HStack(
                                            spacing:
                                                8
                                        ) {

                                            SummaryStatusChip(
                                                title:
                                                    tr(
                                                        "נלמד: \(coachTaughtCount)",
                                                        "Taught: \(coachTaughtCount)"
                                                    ),
                                                tint:
                                                    Color(
                                                        red:
                                                            0.30,
                                                        green:
                                                            0.69,
                                                        blue:
                                                            0.31
                                                    )
                                            )

                                            SummaryStatusChip(
                                                title:
                                                    tr(
                                                        "תורגל: \(coachPracticedCount)",
                                                        "Practiced: \(coachPracticedCount)"
                                                    ),
                                                tint:
                                                    Color(
                                                        red:
                                                            242 / 255,
                                                        green:
                                                            140 / 255,
                                                        blue:
                                                            40 / 255
                                                    )
                                            )

                                            SummaryStatusChip(
                                                title:
                                                    tr(
                                                        "חיזוק: \(coachNeedsReinforcementCount)",
                                                        "Reinforce: \(coachNeedsReinforcementCount)"
                                                    ),
                                                tint:
                                                    Color(
                                                        red:
                                                            0.90,
                                                        green:
                                                            0.22,
                                                        blue:
                                                            0.21
                                                    )
                                            )

                                            SummaryStatusChip(
                                                title:
                                                    tr(
                                                        "לא נלמד: \(coachNotTaughtCount)",
                                                        "Not taught: \(coachNotTaughtCount)"
                                                    ),
                                                tint:
                                                    Color(
                                                        red:
                                                            0.60,
                                                        green:
                                                            0.64,
                                                        blue:
                                                            0.70
                                                    )
                                            )
                                        }
                                        .padding(
                                            .top,
                                            2
                                        )
                                    } else {
                                        HStack(
                                            spacing:
                                                8
                                        ) {

                                            SummaryStatusChip(
                                                title:
                                                    tr(
                                                        "יודע: \(doneCount)",
                                                        "Known: \(doneCount)"
                                                    ),
                                                tint:
                                                    Color(
                                                        red:
                                                            0.30,
                                                        green:
                                                            0.69,
                                                        blue:
                                                            0.31
                                                    )
                                            )

                                            SummaryStatusChip(
                                                title:
                                                    tr(
                                                        "חלקית: \(partiallyKnownCount)",
                                                        "Partial: \(partiallyKnownCount)"
                                                    ),
                                                tint:
                                                    Color(
                                                        red:
                                                            242 / 255,
                                                        green:
                                                            140 / 255,
                                                        blue:
                                                            40 / 255
                                                    )
                                            )

                                            SummaryStatusChip(
                                                title:
                                                    tr(
                                                        "לא יודע: \(notDoneCount)",
                                                        "No: \(notDoneCount)"
                                                    ),
                                                tint:
                                                    Color(
                                                        red:
                                                            0.90,
                                                        green:
                                                            0.22,
                                                        blue:
                                                            0.21
                                                    )
                                            )

                                            SummaryStatusChip(
                                                title:
                                                    tr(
                                                        "לא סומן: \(remainingCount)",
                                                        "Open: \(remainingCount)"
                                                    ),
                                                tint:
                                                    Color(
                                                        red:
                                                            0.60,
                                                        green:
                                                            0.64,
                                                        blue:
                                                            0.70
                                                    )
                                            )
                                        }
                                        .padding(
                                            .top,
                                            2
                                        )
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 12)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if isSummaryLoading {

                            Color.clear
                                .frame(
                                    height:
                                        1
                                )

                        } else if blocks.isEmpty {
                            WhiteCard {
                                VStack(spacing: 10) {
                                    Text(
                                        tr(
                                            "אין נתוני סיכום להצגה",
                                            "No summary data to display"
                                        )
                                    )
                                    .kmiFont(
                                        size: 20,
                                        weight: .heavy
                                    )
                                    .foregroundStyle(
                                        summaryPrimaryTextColor
                                    )

                                    Text(
                                        tr(
                                            "עדיין אין תרגילים להצגה עבור החגורה הנוכחית",
                                            "There are no exercises to display for the current belt yet"
                                        )
                                    )
                                    .kmiFont(
                                        size: 15,
                                        weight: .semibold
                                    )
                                    .foregroundStyle(
                                        summarySecondaryTextColor
                                    )
                                    .multilineTextAlignment(.center)
                                }
                                .padding(.vertical, 18)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        } else {
                            VStack(
                                spacing:
                                    0
                            ) {

                                ForEach(
                                    Array(
                                        blocks.enumerated()
                                    ),
                                    id:
                                        \.element.id
                                ) {
                                    index,
                                    block in

                                    TopicSummaryCard(
                                        block:
                                            block,
                                        beltAccent:
                                            beltAccentForSummary(),
                                        isCoach:
                                            effectiveIsCoach,
                                        isEnglish:
                                            isEnglish
                                    )

                                    if index <
                                        blocks.count - 1 {

                                        Rectangle()
                                            .fill(
                                                beltAccentForSummary()
                                                    .opacity(
                                                        0.28
                                                    )
                                            )
                                            .frame(
                                                height:
                                                    1
                                            )
                                    }
                                }
                            }
                            .padding(
                                .horizontal,
                                16
                            )
                        }

                        Spacer(
                            minLength:
                                18
                        )
                    }
                    .padding(
                        .top,
                        8
                    )
                    .padding(
                        .bottom,
                        18
                    )
                }
            }

            if isSummaryLoading ||
                isComparisonLoading ||
                (
                    showComparisonCard &&
                    effectiveIsCoach &&
                    !coachGroupProgressLoaded
                ) {

                KmiLoadingOverlay()
            }
        }
        .environment(
            \.layoutDirection,
            screenLayoutDirection
        )
        .onAppear {
            loadedSummaryRoleId =
                summaryRoleId

            postSummaryTopTitleOverride()

            isSummaryLoading = true

            DispatchQueue.main.async {
                cachedBlocks =
                    buildSummaryBlocks()

                isSummaryLoading = false

                postSummaryTopTitleOverride()

                saveCalculatedProgress()
            }

            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.12
            ) {
                postSummaryTopTitleOverride()
            }
        }
        .onChange(of: percentAll) { _, _ in
            postSummaryTopTitleOverride()

            DispatchQueue.main.async {
                postSummaryTopTitleOverride()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UserDefaults.didChangeNotification
            )
        ) { _ in
            let currentRoleId =
                summaryRoleId

            /*
             * אם התפקיד השתנה, מנקים את כל
             * מצב התצוגה השייך לתפקיד הקודם.
             */
            if !loadedSummaryRoleId.isEmpty,
               loadedSummaryRoleId
                != currentRoleId {

                showProgressCard = false
                showComparisonCard = false

                comparisonTraineesCount = 0
                comparisonAveragePercent = 0
                comparisonBetterThanPercent = 0
                isComparisonLoading = false
                comparisonHasError = false

                coachGroupProgress =
                    nil

                coachGroupProgressLoaded =
                    false

                coachGroupProgressHasError =
                    false
            }

            loadedSummaryRoleId =
                currentRoleId

            /*
             * מרענן פעם אחת את מטמון הסיכום וקורא
             * רק את הסימונים של התפקיד הפעיל.
             */
            marksRevision &+= 1
            isSummaryLoading = true

            DispatchQueue.main.async {
                cachedBlocks =
                    buildSummaryBlocks()

                isSummaryLoading = false

                postSummaryTopTitleOverride()

                saveCalculatedProgress()
            }
        }
    }
    
    private var summaryTopControls:
        some View {

        HStack(
            spacing:
                0
        ) {

            summaryTopTab(
                title:
                    tr(
                        "התקדמות",
                        "Progress"
                    ),
                isSelected:
                    showProgressCard
            ) {
                guard !isSummaryLoading else {
                    return
                }

                showComparisonCard = false
                showProgressCard.toggle()
            }

            Rectangle()
                .fill(
                    Color.white.opacity(
                        0.65
                    )
                )
                .frame(
                    width:
                        1,
                    height:
                        30
                )

            summaryTopTab(
                title:
                    effectiveIsCoach
                    ? tr(
                        "נתוני הקבוצות",
                        "Group data"
                    )
                    : tr(
                        "השוואה",
                        "Compare"
                    ),
                isSelected:
                    showComparisonCard
            ) {
                guard !isSummaryLoading else {
                    return
                }

                showProgressCard = false

                let willOpen =
                    !showComparisonCard

                showComparisonCard =
                    willOpen

                if willOpen {

                    if effectiveIsCoach {

                        if !coachGroupProgressLoaded {
                            loadCoachGroupProgress()
                        }

                    } else {
                        saveProgressAndLoadComparison()
                    }
                }
            }
        }
        .frame(
            maxWidth:
                .infinity
        )
        .frame(
            height:
                54
        )
        .background(
            KmiAppTheme
                .sectionHeaderBrush
        )
        .environment(
            \.layoutDirection,
            .leftToRight
        )
    }

    private func summaryTopTab(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {

        Button(
            action:
                action
        ) {

            ZStack(
                alignment:
                    .bottom
            ) {

                Text(
                    title
                )
                .kmiTypography(
                    .caption
                )
                .fontWeight(
                    .heavy
                )
                .foregroundStyle(
                    Color.white
                )
                .multilineTextAlignment(
                    .center
                )
                .lineLimit(
                    2
                )
                .minimumScaleFactor(
                    0.78
                )
                .frame(
                    maxWidth:
                        .infinity,
                    maxHeight:
                        .infinity
                )
                .padding(
                    .horizontal,
                    12
                )
                .padding(
                    .top,
                    4
                )
                .padding(
                    .bottom,
                    8
                )

                if isSelected {

                    Capsule()
                        .fill(
                            Color.white
                        )
                        .frame(
                            width:
                                50,
                            height:
                                3
                        )
                        .padding(
                            .bottom,
                            5
                        )
                }
            }
        }
        .buttonStyle(
            .plain
        )
        .frame(
            maxWidth:
                .infinity,
            maxHeight:
                .infinity
        )
    }

    private func beltAccentForSummary() -> Color {
        switch belt {
        case .white:
            return Color.gray.opacity(0.80)
        case .yellow:
            return Color(red: 0.95, green: 0.82, blue: 0.18)
        case .orange:
            return Color(red: 0.96, green: 0.62, blue: 0.16)
        case .green:
            return Color(red: 0.22, green: 0.76, blue: 0.35)
        case .blue:
            return Color(red: 0.22, green: 0.52, blue: 0.92)
        case .brown:
            return Color(red: 0.57, green: 0.38, blue: 0.24)
        case .black:
            return Color(red: 0.42, green: 0.42, blue: 0.46)
        default:
            return Color.black.opacity(0.45)
        }
    }
    
    // MARK: - UI pieces

    private struct CoachGroupsProgressCardIOS:
        View {

        let summary:
            CoachGroupProgressSummary?

        let isLoaded: Bool
        let hasError: Bool
        let beltAccent: Color
        let isEnglish: Bool
        let onClose: () -> Void

        @Environment(\.colorScheme)
        private var colorScheme

        private var isDarkMode: Bool {
            colorScheme == .dark
        }

        private var primaryTextColor:
            Color {

            isDarkMode
                ? Color.white.opacity(
                    0.94
                )
                : Color.black.opacity(
                    0.84
                )
        }

        private var secondaryTextColor:
            Color {

            isDarkMode
                ? Color.white.opacity(
                    0.68
                )
                : Color.black.opacity(
                    0.56
                )
        }

        private func tr(
            _ he: String,
            _ en: String
        ) -> String {

            isEnglish
                ? en
                : he
        }

        var body: some View {

            VStack(
                spacing:
                    10
            ) {

                HStack(
                    spacing:
                        8
                ) {

                    Button {
                        onClose()
                    } label: {

                        Image(
                            systemName:
                                "xmark"
                        )
                        .kmiFont(
                            size:
                                15,
                            weight:
                                .heavy
                        )
                        .foregroundStyle(
                            secondaryTextColor
                        )
                        .frame(
                            width:
                                34,
                            height:
                                34
                        )
                    }
                    .buttonStyle(
                        .plain
                    )

                    Text(
                        tr(
                            "נתוני הקבוצות",
                            "Group data"
                        )
                    )
                    .kmiFont(
                        size:
                            20,
                        weight:
                            .black
                    )
                    .foregroundStyle(
                        primaryTextColor
                    )
                    .frame(
                        maxWidth:
                            .infinity,
                        alignment:
                            isEnglish
                                ? .leading
                                : .trailing
                    )
                    .multilineTextAlignment(
                        isEnglish
                            ? .leading
                            : .trailing
                    )
                }
                .environment(
                    \.layoutDirection,
                    isEnglish
                        ? .leftToRight
                        : .rightToLeft
                )

                if !isLoaded {

                    Color.clear
                        .frame(
                            maxWidth:
                                .infinity
                        )
                        .frame(
                            height:
                                138
                        )

                } else if hasError {

                    Text(
                        tr(
                            "לא ניתן לטעון כרגע את נתוני הקבוצות. נסה שוב מאוחר יותר.",
                            "Group data cannot be loaded right now. Please try again later."
                        )
                    )
                    .kmiFont(
                        size:
                            15,
                        weight:
                            .semibold
                    )
                    .foregroundStyle(
                        secondaryTextColor
                    )
                    .multilineTextAlignment(
                        .center
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                    .padding(
                        .vertical,
                        24
                    )

                } else if
                    summary == nil ||
                    summary?.totalTrainees == 0 {

                    Text(
                        tr(
                            "לא נמצאו מתאמנים בקבוצות שאליהן אתה משויך.",
                            "No trainees were found in the groups assigned to you."
                        )
                    )
                    .kmiFont(
                        size:
                            15,
                        weight:
                            .semibold
                    )
                    .foregroundStyle(
                        secondaryTextColor
                    )
                    .multilineTextAlignment(
                        .center
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                    .padding(
                        .vertical,
                        24
                    )

                } else if let summary {

                    ZStack {

                        Circle()
                            .fill(
                                beltAccent.opacity(
                                    0.16
                                )
                            )
                            .overlay {

                                Circle()
                                    .stroke(
                                        beltAccent.opacity(
                                            0.55
                                        ),
                                        lineWidth:
                                            2
                                    )
                            }

                        VStack(
                            spacing:
                                3
                        ) {

                            Text(
                                "\(summary.averageKnownPercent)%"
                            )
                            .kmiFont(
                                size:
                                    26,
                                weight:
                                    .black
                            )
                            .foregroundStyle(
                                primaryTextColor
                            )

                            Text(
                                tr(
                                    "ידיעת החומר",
                                    "Average knowledge"
                                )
                            )
                            .kmiFont(
                                size:
                                    11,
                                weight:
                                    .bold
                            )
                            .foregroundStyle(
                                secondaryTextColor
                            )
                            .multilineTextAlignment(
                                .center
                            )
                        }
                    }
                    .frame(
                        width:
                            138,
                        height:
                            138
                    )

                    Text(
                        tr(
                            "ממוצע ידיעת החומר בחגורה",
                            "Average knowledge of the belt material"
                        )
                    )
                    .kmiFont(
                        size:
                            14,
                        weight:
                            .bold
                    )
                    .foregroundStyle(
                        primaryTextColor
                    )
                    .multilineTextAlignment(
                        .center
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )

                    HStack(
                        spacing:
                            8
                    ) {

                        CoachGroupMetricBox(
                            value:
                                "\(summary.groupsCount)",
                            title:
                                tr(
                                    "קבוצות",
                                    "Groups"
                                ),
                            tint:
                                beltAccent
                        )

                        CoachGroupMetricBox(
                            value:
                                "\(summary.totalTrainees)",
                            title:
                                tr(
                                    "מתאמנים",
                                    "Trainees"
                                ),
                            tint:
                                beltAccent
                        )

                        CoachGroupMetricBox(
                            value:
                                "\(summary.traineesWithProgress)",
                            title:
                                tr(
                                    "עם נתונים",
                                    "With data"
                                ),
                            tint:
                                beltAccent
                        )
                    }

                    if !summary.hasProgressData {

                        Text(
                            tr(
                                "המתאמנים עדיין לא שמרו נתוני התקדמות בחגורה זו.",
                                "The trainees have not saved progress for this belt yet."
                            )
                        )
                        .kmiFont(
                            size:
                                11,
                            weight:
                                .semibold
                        )
                        .foregroundStyle(
                            secondaryTextColor
                        )
                        .multilineTextAlignment(
                            .center
                        )
                        .frame(
                            maxWidth:
                                .infinity
                        )

                    } else if
                        summary.traineesWithoutProgress > 0 {

                        Text(
                            isEnglish
                                ? "\(summary.traineesWithoutProgress) trainees do not yet have progress data for this belt."
                                : "ל־\(summary.traineesWithoutProgress) מתאמנים עדיין אין נתוני התקדמות בחגורה זו."
                        )
                        .kmiFont(
                            size:
                                11,
                            weight:
                                .semibold
                        )
                        .foregroundStyle(
                            secondaryTextColor
                        )
                        .multilineTextAlignment(
                            .center
                        )
                        .frame(
                            maxWidth:
                                .infinity
                        )
                    }
                }
            }
            .padding(
                .horizontal,
                14
            )
            .padding(
                .vertical,
                12
            )
            .frame(
                maxWidth:
                    .infinity
            )
            .background {

                RoundedRectangle(
                    cornerRadius:
                        24,
                    style:
                        .continuous
                )
                .fill(
                    isDarkMode
                        ? Color(
                            red:
                                0.055,
                            green:
                                0.075,
                            blue:
                                0.125
                        )
                        : Color.white.opacity(
                            0.96
                        )
                )
            }
            .overlay {

                RoundedRectangle(
                    cornerRadius:
                        24,
                    style:
                        .continuous
                )
                .stroke(
                    beltAccent.opacity(
                        0.28
                    ),
                    lineWidth:
                        1
                )
            }
            .padding(
                .horizontal,
                16
            )
            .padding(
                .top,
                8
            )
            .padding(
                .bottom,
                10
            )
        }
    }

    private struct CoachGroupMetricBox:
        View {

        let value: String
        let title: String
        let tint: Color

        @Environment(\.colorScheme)
        private var colorScheme

        var body: some View {

            VStack(
                spacing:
                    4
            ) {

                Text(
                    value
                )
                .kmiFont(
                    size:
                        20,
                    weight:
                        .black
                )
                .foregroundStyle(
                    colorScheme == .dark
                        ? Color.white
                        : tint
                )

                Text(
                    title
                )
                .kmiFont(
                    size:
                        11,
                    weight:
                        .bold
                )
                .foregroundStyle(
                    colorScheme == .dark
                        ? Color.white.opacity(
                            0.74
                        )
                        : Color.black.opacity(
                            0.58
                        )
                )
                .lineLimit(
                    2
                )
                .minimumScaleFactor(
                    0.72
                )
                .multilineTextAlignment(
                    .center
                )
            }
            .frame(
                maxWidth:
                    .infinity
            )
            .frame(
                height:
                    72
            )
            .background {

                RoundedRectangle(
                    cornerRadius:
                        16,
                    style:
                        .continuous
                )
                .fill(
                    colorScheme == .dark
                        ? Color.white.opacity(
                            0.08
                        )
                        : tint.opacity(
                            0.09
                        )
                )
            }
        }
    }

    private struct BeltComparisonStatusCard: View {
        let traineesCount: Int
        let averagePercent: Int
        let userPercent: Int
        let statusText: String
        let hasEnoughData: Bool
        let isEnglish: Bool
        let onClose: () -> Void

        @Environment(\.colorScheme)
        private var colorScheme

        private var isDarkMode: Bool {
            colorScheme == .dark
        }

        private var primaryTextColor: Color {
            isDarkMode
                ? Color.white.opacity(0.94)
                : Color(red: 0.12, green: 0.17, blue: 0.24)
        }

        private var secondaryTextColor: Color {
            isDarkMode
                ? Color.white.opacity(0.68)
                : Color.black.opacity(0.58)
        }

        private var messageSurfaceColor: Color {
            isDarkMode
                ? Color.white.opacity(0.08)
                : Color.white.opacity(0.72)
        }

        private func tr(
            _ he: String,
            _ en: String
        ) -> String {
            isEnglish ? en : he
        }
        
        var body: some View {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .kmiFont(
                                size: 17,
                                weight: .heavy
                            )
                            .foregroundStyle(secondaryTextColor)
                            .frame(width: 34, height: 34)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)

                    Text(
                        tr(
                            "המצב שלך בחגורה",
                            "Your belt progress"
                        )
                    )
                    .kmiFont(
                        size: 22,
                        weight: .black
                    )
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                }
                .padding(.horizontal, 4)

                if hasEnoughData {
                    HStack(spacing: 8) {
                        ComparisonMetricBox(
                            value:
                                "\(userPercent)%",
                            title:
                                tr(
                                    "אתה יודע",
                                    "You know"
                                ),
                            tint:
                                Color.green.opacity(0.82)
                        )

                        ComparisonMetricBox(
                            value: "\(averagePercent)%",
                            title: tr("ממוצע", "Average"),
                            tint: Color.blue.opacity(0.72)
                        )

                        ComparisonMetricBox(
                            value:
                                "\(traineesCount)",
                            title:
                                tr(
                                    "מתאמנים",
                                    "Trainees"
                                ),
                            tint:
                                Color.gray.opacity(0.72)
                        )
                    }

                    Text(statusText)
                        .kmiFont(
                            size: 21,
                            weight: .black
                        )
                        .foregroundStyle(
                            isDarkMode
                                ? Color.green.opacity(0.94)
                                : Color.green.opacity(0.84)
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.top, 2)
                } else {
                    Text(statusText)
                        .kmiFont(
                            size: 15,
                            weight: .semibold
                        )
                        .foregroundStyle(secondaryTextColor)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(
                                cornerRadius: 16,
                                style: .continuous
                            )
                            .fill(messageSurfaceColor)
                        )
                        .overlay(
                            RoundedRectangle(
                                cornerRadius: 16,
                                style: .continuous
                            )
                            .stroke(
                                isDarkMode
                                    ? Color.white.opacity(0.12)
                                    : Color.black.opacity(0.06),
                                lineWidth: 1
                            )
                        )
                }
            }
        }
    }

    private struct ComparisonMetricBox: View {
        let value: String
        let title: String
        let tint: Color

        @Environment(\.colorScheme)
        private var colorScheme

        private var titleColor: Color {
            colorScheme == .dark
                ? Color.white.opacity(0.76)
                : Color(red: 0.25, green: 0.34, blue: 0.42)
        }

        var body: some View {
            VStack(spacing: 5) {
                Text(value)
                    .kmiFont(
                        size: 20,
                        weight: .black
                    )
                    .foregroundStyle(tint)

                Text(title)
                    .kmiFont(
                        size: 14,
                        weight: .black
                    )
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .fill(
                    colorScheme == .dark
                        ? tint.opacity(0.18)
                        : tint.opacity(0.12)
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .stroke(
                    colorScheme == .dark
                        ? tint.opacity(0.38)
                        : tint.opacity(0.26),
                    lineWidth: 1
                )
            )
        }
    }
    
    private struct ProgressRing: View {
        let percent: Int
        let doneCount: Int
        let partiallyKnownCount: Int
        let notDoneCount: Int
        let remainingCount: Int
        let totalCount: Int
        let isCoach: Bool
        let isEnglish: Bool

        @Environment(\.colorScheme)
        private var colorScheme

        private var isDarkMode: Bool {
            colorScheme == .dark
        }

        private var ringSurfaceColor: Color {
            isDarkMode
                ? Color(
                    red: 0.075,
                    green: 0.095,
                    blue: 0.145
                )
                : Color.white.opacity(0.98)
        }

        private var ringPrimaryTextColor: Color {
            isDarkMode
                ? Color.white.opacity(0.94)
                : Color(red: 0.12, green: 0.17, blue: 0.24)
        }

        private var ringSecondaryTextColor: Color {
            isDarkMode
                ? Color.white.opacity(0.62)
                : Color.black.opacity(0.55)
        }

        private var donePart: CGFloat {
            guard totalCount > 0 else { return 0 }
            return CGFloat(doneCount) / CGFloat(totalCount)
        }

        private var partiallyKnownPart: CGFloat {
            guard totalCount > 0 else {
                return 0
            }

            return CGFloat(
                partiallyKnownCount
            ) / CGFloat(
                totalCount
            )
        }

        private var notDonePart: CGFloat {
            guard totalCount > 0 else {
                return 0
            }

            return CGFloat(
                notDoneCount
            ) / CGFloat(
                totalCount
            )
        }

        private var remainingPart: CGFloat {
            guard totalCount > 0 else { return 1 }
            return CGFloat(remainingCount) / CGFloat(totalCount)
        }

        var body: some View {
            ZStack {
                Circle()
                    .fill(ringSurfaceColor)
                    .shadow(
                        color: Color.black.opacity(
                            isDarkMode ? 0.32 : 0.06
                        ),
                        radius: 5,
                        x: 0,
                        y: 3
                    )

                Circle()
                    .trim(from: 0, to: max(remainingPart, 0.001))
                    .stroke(
                        isDarkMode
                            ? Color.white.opacity(0.18)
                            : Color(red: 0.85, green: 0.85, blue: 0.89),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Circle()
                    .trim(
                        from:
                            0,
                        to:
                            donePart
                    )
                    .stroke(
                        Color(
                            red:
                                0.30,
                            green:
                                0.69,
                            blue:
                                0.31
                        ),
                        style:
                            StrokeStyle(
                                lineWidth:
                                    16,
                                lineCap:
                                    .round
                            )
                    )
                    .rotationEffect(
                        .degrees(
                            -90
                        )
                    )

                Circle()
                    .trim(
                        from:
                            donePart,
                        to:
                            min(
                                donePart
                                    + partiallyKnownPart,
                                1.0
                            )
                    )
                    .stroke(
                        Color(
                            red:
                                242 / 255,
                            green:
                                140 / 255,
                            blue:
                                40 / 255
                        ),
                        style:
                            StrokeStyle(
                                lineWidth:
                                    16,
                                lineCap:
                                    .round
                            )
                    )
                    .rotationEffect(
                        .degrees(
                            -90
                        )
                    )

                Circle()
                    .trim(
                        from:
                            donePart
                                + partiallyKnownPart,
                        to:
                            min(
                                donePart
                                    + partiallyKnownPart
                                    + notDonePart,
                                1.0
                            )
                    )
                    .stroke(
                        Color(
                            red:
                                0.90,
                            green:
                                0.22,
                            blue:
                                0.21
                        ),
                        style:
                            StrokeStyle(
                                lineWidth:
                                    16,
                                lineCap:
                                    .round
                            )
                    )
                    .rotationEffect(
                        .degrees(
                            -90
                        )
                    )

                Circle()
                    .fill(ringSurfaceColor)
                    .frame(width: 128, height: 128)

                VStack(spacing: 5) {
                    Text("\(percent)%")
                        .kmiFont(
                            size: 25,
                            weight: .black
                        )
                        .foregroundStyle(ringPrimaryTextColor)

                    Text(
                        isCoach
                            ? (
                                isEnglish
                                ? "Updated"
                                : "עודכנו"
                            )
                            : (
                                isEnglish
                                ? "Marked"
                                : "סומנו"
                            )
                    )
                    .kmiFont(
                        size: 14,
                        weight: .black
                    )
                    .foregroundStyle(
                        Color(
                            red: 0.30,
                            green: 0.69,
                            blue: 0.31
                        )
                    )

                    Text(
                        isEnglish
                        ? "\(doneCount + partiallyKnownCount + notDoneCount) of \(totalCount)"
                        : "\(doneCount + partiallyKnownCount + notDoneCount) מתוך \(totalCount)"
                    )
                    .kmiFont(
                        size: 13,
                        weight: .bold
                    )
                    .foregroundStyle(ringSecondaryTextColor)
                }
            }
        }
    }
    
    private struct SummaryStatusChip: View {
        let title: String
        let tint: Color

        var body: some View {
            Text(
                title
            )
            .kmiFont(
                size:
                    10,
                weight:
                    .black
            )
            .foregroundStyle(
                tint
            )
            .multilineTextAlignment(
                .center
            )
            .lineLimit(
                1
            )
            .minimumScaleFactor(
                0.58
            )
            .allowsTightening(
                true
            )
            .frame(
                maxWidth:
                    .infinity
            )
            .frame(
                height:
                    44
            )
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tint.opacity(0.26), lineWidth: 1)
                )
        }
    }
    
    private struct TopicSummaryCard: View {
        let block: SummaryTopicBlock

        let beltAccent:
            Color

        let isCoach: Bool
        let isEnglish: Bool

        @Environment(\.colorScheme)
        private var colorScheme

        private var isDarkMode: Bool {
            colorScheme == .dark
        }

        private var primaryTextColor: Color {
            isDarkMode
                ? Color.white.opacity(0.94)
                : Color.black.opacity(0.84)
        }

        private var cardColors: [Color] {

            if isDarkMode {

                return [
                    Color(
                        red:
                            0.09,
                        green:
                            0.12,
                        blue:
                            0.19
                    ),
                    beltAccent.opacity(
                        0.13
                    ),
                    Color(
                        red:
                            0.08,
                        green:
                            0.11,
                        blue:
                            0.18
                    )
                ]
            }

            return [
                Color.white.opacity(
                    0.96
                ),
                beltAccent.opacity(
                    0.16
                ),
                Color.white.opacity(
                    0.94
                )
            ]
        }
        
        @State private var expanded: Bool = false

        private struct SubTopicGroup:
            Identifiable {

            let id: String
            let title: String?
            let items: [SummaryRowItem]
        }

        private var subTopicGroups:
            [SubTopicGroup] {

            var order:
                [String] = []

            var grouped:
                [String: [SummaryRowItem]] = [:]

            for item in block.items {

                let cleanTitle =
                    item.subTopicTitle?
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                    ?? ""

                /*
                 * מפתח ריק = תרגילים ישירים של הנושא.
                 * לא ממציאים עבורם תת־נושא.
                 */
                let key =
                    cleanTitle

                if grouped[key] == nil {
                    order.append(
                        key
                    )

                    grouped[key] = []
                }

                grouped[key]?.append(
                    item
                )
            }

            return order.map {
                key in

                SubTopicGroup(
                    id:
                        key.isEmpty
                            ? "__direct__"
                            : key,
                    title:
                        key.isEmpty
                            ? nil
                            : key,
                    items:
                        grouped[key]
                        ?? []
                )
            }
        }

        private var frameAlignment: Alignment {
            isEnglish ? .leading : .trailing
        }

        private var textAlignment: TextAlignment {
            isEnglish ? .leading : .trailing
        }

        private func percent(
            for items:
                [SummaryRowItem]
        ) -> Int {

            guard !items.isEmpty else {
                return 0
            }

            let completedCount =
                items.filter {
                    item in

                    if isCoach {
                        return !item
                            .coachStatuses
                            .isEmpty
                    }

                    /*
                     * זהה ל-Android:
                     * אחוז הידיעה של מתאמן מבוסס
                     * על "יודע" בלבד.
                     */
                    return item.mark
                        == .done
                }
                .count

            return Int(
                round(
                    (
                        Double(
                            completedCount
                        )
                        / Double(
                            items.count
                        )
                    )
                    * 100.0
                )
            )
        }

        var body: some View {
            VStack(spacing: 8) {
                Button {
                    withAnimation(.easeOut(duration: 0.14)) {
                        expanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        ButtonIcon(
                            expanded:
                                expanded,
                            tint:
                                beltAccent
                        )

                        Spacer(
                            minLength:
                                0
                        )

                        Text(
                            "\(block.title) — "
                            + "\(block.percent(isCoach: isCoach))%"
                        )
                        .kmiFont(
                            size: 18,
                            weight: .black
                        )
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(
                            maxWidth: .infinity,
                            alignment: frameAlignment
                        )
                        .multilineTextAlignment(textAlignment)
                    }
                    .environment(
                        \.layoutDirection,
                        .leftToRight
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                if expanded {

                    VStack(
                        spacing:
                            8
                    ) {

                        ForEach(
                            subTopicGroups
                        ) {
                            group in

                            VStack(
                                spacing:
                                    0
                            ) {

                                if let subTopicTitle =
                                    group.title,
                                   subTopicTitle
                                    .trimmingCharacters(
                                        in:
                                            .whitespacesAndNewlines
                                    )
                                    != block.title
                                        .trimmingCharacters(
                                            in:
                                                .whitespacesAndNewlines
                                        ) {

                                    let subTopicPercent =
                                        percent(
                                            for:
                                                group.items
                                        )

                                    let subTopicDisplayTitle =
                                        "\(subTopicTitle) — \(subTopicPercent)%"

                                    Text(
                                        subTopicDisplayTitle
                                    )
                                    .kmiFont(
                                        size:
                                            15,
                                        weight:
                                            .heavy
                                    )
                                    .foregroundStyle(
                                        beltAccent
                                    )
                                    .frame(
                                        maxWidth:
                                            .infinity,
                                        alignment:
                                            frameAlignment
                                    )
                                    .multilineTextAlignment(
                                        textAlignment
                                    )
                                    .lineLimit(
                                        2
                                    )
                                    .minimumScaleFactor(
                                        0.78
                                    )
                                    .padding(
                                        .horizontal,
                                        10
                                    )
                                    .padding(
                                        .vertical,
                                        8
                                    )
                                    .background {

                                        RoundedRectangle(
                                            cornerRadius:
                                                12,
                                            style:
                                                .continuous
                                        )
                                        .fill(
                                            beltAccent.opacity(
                                                isDarkMode
                                                    ? 0.12
                                                    : 0.07
                                            )
                                        )
                                    }
                                    .overlay {

                                        RoundedRectangle(
                                            cornerRadius:
                                                12,
                                            style:
                                                .continuous
                                        )
                                        .stroke(
                                            beltAccent.opacity(
                                                0.12
                                            ),
                                            lineWidth:
                                                1
                                        )
                                    }
                                    .padding(
                                        .bottom,
                                        6
                                    )
                                }

                                ForEach(
                                    Array(
                                        group.items.enumerated()
                                    ),
                                    id:
                                        \.element.id
                                ) {
                                    index,
                                    item in

                                    SummaryRow(
                                        title:
                                            item.title,
                                        mark:
                                            item.mark,
                                        coachStatuses:
                                            item.coachStatuses,
                                        isCoach:
                                            isCoach,
                                        isEnglish:
                                            isEnglish
                                    )

                                    if index <
                                        group.items.count - 1 {

                                        Divider()
                                            .opacity(
                                                0.14
                                            )
                                    }
                                }
                            }
                        }
                    }
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius:
                                12,
                            style:
                                .continuous
                        )
                    )
                    .transition(
                        .opacity.combined(
                            with:
                                .move(
                                    edge:
                                        .top
                                )
                        )
                    )
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
            .background {
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: cardColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius:
                        18,
                    style:
                        .continuous
                )
                .stroke(
                    isDarkMode
                        ? Color.white.opacity(
                            0.12
                        )
                        : Color.black.opacity(
                            0.04
                        ),
                    lineWidth:
                        1
                )
            }
        }

        private struct ButtonIcon: View {
            let expanded: Bool
            let tint: Color

            var body: some View {
                Image(
                    systemName:
                        expanded
                        ? "chevron.up"
                        : "chevron.down"
                )
                .kmiFont(
                    size:
                        15,
                    weight:
                        .black
                )
                .foregroundStyle(
                    tint
                )
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(
                            Color.primary.opacity(0.08)
                        )
                )
            }
        }
    }

    private struct SummaryRow: View {
        let title: String
        let mark: SummaryMark?

        let coachStatuses:
            Set<SummaryCoachStatus>

        let isCoach: Bool
        let isEnglish: Bool

        @Environment(\.colorScheme)
        private var colorScheme

        private var rowTextColor: Color {
            colorScheme == .dark
                ? Color.white.opacity(0.88)
                : Color.black.opacity(0.78)
        }
        
        private var frameAlignment: Alignment {
            isEnglish
                ? .leading
                : .trailing
        }

        private func coachStatusColor(
            _ status:
                SummaryCoachStatus
        ) -> Color {

            switch status {

            case .notTaught:
                return Color(
                    red:
                        0.54,
                    green:
                        0.58,
                    blue:
                        0.62
                )

            case .taught:
                return Color(
                    red:
                        0.95,
                    green:
                        0.63,
                    blue:
                        0.38
                )

            case .practiced:
                return Color(
                    red:
                        0.18,
                    green:
                        0.61,
                    blue:
                        0.31
                )

            case .needsReinforcement:
                return Color(
                    red:
                        0.20,
                    green:
                        0.47,
                    blue:
                        0.83
                )
            }
        }

        private func coachStatusSymbol(
            _ status:
                SummaryCoachStatus
        ) -> String {

            switch status {

            case .notTaught:
                return "—"

            case .taught:
                return "✓"

            case .practiced:
                return "↻"

            case .needsReinforcement:
                return "!"
            }
        }

        private func coachStatusTitle(
            _ status:
                SummaryCoachStatus
        ) -> String {

            switch status {

            case .notTaught:
                return isEnglish
                    ? "Not taught"
                    : "לא נלמד"

            case .taught:
                return isEnglish
                    ? "Taught"
                    : "נלמד"

            case .practiced:
                return isEnglish
                    ? "Practiced"
                    : "תורגל"

            case .needsReinforcement:
                return isEnglish
                    ? "Reinforce"
                    : "חיזוק"
            }
        }

        private var orderedCoachStatuses:
            [SummaryCoachStatus] {

            let order:
                [SummaryCoachStatus] = [
                    .taught,
                    .practiced,
                    .needsReinforcement
                ]

            return order.filter {
                coachStatuses.contains(
                    $0
                )
            }
        }

        private var traineeStatusColor: Color {
            switch mark {

            case .done:
                return Color.green.opacity(
                    0.85
                )

            case .partiallyKnown:
                return Color.orange.opacity(
                    0.88
                )

            case .notDone:
                return Color.red.opacity(
                    0.80
                )

            case nil:
                return Color.gray.opacity(
                    0.35
                )
            }
        }

        private var traineeSystemImage: String {
            switch mark {

            case .done:
                return "checkmark.circle.fill"

            case .partiallyKnown:
                return "circle.lefthalf.filled"

            case .notDone:
                return "xmark.circle.fill"

            case nil:
                return "circle.fill"
            }
        }

        private var traineeStatusTitle:
            String {

            switch mark {

            case .done:
                return isEnglish
                    ? "Known"
                    : "יודע"

            case .partiallyKnown:
                return isEnglish
                    ? "Partially known"
                    : "יודע חלקית"

            case .notDone:
                return isEnglish
                    ? "Not known"
                    : "לא יודע"

            case nil:
                return isEnglish
                    ? "Unmarked"
                    : "לא סומן"
            }
        }
        
        var body: some View {
            HStack(spacing: 10) {
                if isCoach {

                    if orderedCoachStatuses.isEmpty {

                        coachStatusBadge(
                            .notTaught
                        )

                    } else {

                        HStack(
                            spacing:
                                6
                        ) {

                            ForEach(
                                orderedCoachStatuses,
                                id:
                                    \.rawValue
                            ) {
                                status in

                                coachStatusBadge(
                                    status
                                )
                            }
                        }
                    }

                } else {

                    VStack(
                        spacing:
                            3
                    ) {

                        Image(
                            systemName:
                                traineeSystemImage
                        )
                        .kmiFont(
                            size:
                                18,
                            weight:
                                .heavy
                        )
                        .foregroundStyle(
                            traineeStatusColor
                        )

                        Text(
                            traineeStatusTitle
                        )
                        .kmiFont(
                            size:
                                9,
                            weight:
                                .heavy
                        )
                        .foregroundStyle(
                            traineeStatusColor
                        )
                        .lineLimit(
                            2
                        )
                        .minimumScaleFactor(
                            0.72
                        )
                        .multilineTextAlignment(
                            .center
                        )
                    }
                    .frame(
                        width:
                            76
                    )
                }

                Text(title)
                    .kmiFont(
                        size: 16,
                        weight: .semibold
                    )
                    .foregroundStyle(rowTextColor)
                    .frame(
                        maxWidth: .infinity,
                        alignment: frameAlignment
                    )
                    .multilineTextAlignment(
                        isEnglish
                            ? .leading
                            : .trailing
                    )
            }
            .environment(
                \.layoutDirection,
                isEnglish
                    ? .rightToLeft
                    : .leftToRight
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                isCoach
                    ? coachRowBackgroundColor
                    : Color.clear
            )
        }

        private var coachRowBackgroundColor:
            Color {

            guard let primaryStatus =
                orderedCoachStatuses.first else {

                return Color.clear
            }

            return coachStatusColor(
                primaryStatus
            )
            .opacity(
                0.07
            )
        }

        private func coachStatusBadge(
            _ status:
                SummaryCoachStatus
        ) -> some View {

            let color =
                coachStatusColor(
                    status
                )

            return VStack(
                spacing:
                    3
            ) {

                ZStack {

                    Circle()
                        .fill(
                            color
                        )
                        .frame(
                            width:
                                30,
                            height:
                                30
                        )

                    Text(
                        coachStatusSymbol(
                            status
                        )
                    )
                    .kmiFont(
                        size:
                            15,
                        weight:
                            .heavy
                    )
                    .foregroundStyle(
                        Color.white
                    )
                }

                Text(
                    coachStatusTitle(
                        status
                    )
                )
                .kmiFont(
                    size:
                        9,
                    weight:
                        .heavy
                )
                .foregroundStyle(
                    color
                )
                .lineLimit(
                    2
                )
                .minimumScaleFactor(
                    0.72
                )
                .multilineTextAlignment(
                    .center
                )
            }
            .frame(
                width:
                    66
            )
        }
    }
}
