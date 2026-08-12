import SwiftUI
import Shared
import FirebaseAuth
import FirebaseFirestore

// MARK: - Summary models (file-scope)

// מצב הסימון של המתאמן.
enum SummaryMark: String {
    case done
    case notDone

    static func fromStoredValue(
        _ value: String
    ) -> SummaryMark? {
        switch value
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased() {

        case "done", "mastered":
            return .done

        case "notdone", "not_done", "unknown":
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
     * coachStatus משמש את המאמן.
     */
    let mark: SummaryMark?
    let coachStatus: SummaryCoachStatus
}

struct SummaryTopicBlock: Identifiable {
    let id: String
    let title: String
    let items: [SummaryRowItem]

    var doneCount: Int {
        items.filter {
            $0.mark == .done
        }.count
    }

    var notDoneCount: Int {
        items.filter {
            $0.mark == .notDone
        }.count
    }

    var coachNotTaughtCount: Int {
        items.filter {
            $0.coachStatus == .notTaught
        }.count
    }

    var coachTaughtCount: Int {
        items.filter {
            $0.coachStatus == .taught
        }.count
    }

    var coachPracticedCount: Int {
        items.filter {
            $0.coachStatus == .practiced
        }.count
    }

    var coachNeedsReinforcementCount: Int {
        items.filter {
            $0.coachStatus == .needsReinforcement
        }.count
    }

    var coachMarkedCount: Int {
        coachTaughtCount
        + coachPracticedCount
        + coachNeedsReinforcementCount
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

    private var summaryBottomSurfaceColor: Color {
        isDarkMode
            ? Color(
                red: 0.025,
                green: 0.035,
                blue: 0.075
            )
            .opacity(0.98)
            : Color.white.opacity(0.96)
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
     * מזהה נפרד לכל סוג סיכום.
     *
     * כך נתוני המאמן לעולם לא ידרסו
     * את נתוני המתאמן של אותו משתמש.
     */
    private var summaryRoleId: String {
        effectiveIsCoach
            ? "coach"
            : "trainee"
    }

    private var comparisonGroupTitle: String {
        effectiveIsCoach
            ? tr(
                "מאמנים",
                "Coaches"
            )
            : tr(
                "מתאמנים",
                "Trainees"
            )
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

    private func loadCoachStatus(
        topicTitle: String,
        subTopicTitle: String?,
        item: String,
        index: Int
    ) -> SummaryCoachStatus {
        let topicKey =
            coachTopicKey(
                topicTitle: topicTitle,
                subTopicTitle: subTopicTitle
            )

        let statusId =
            coachStatusId(
                topicTitle: topicTitle,
                subTopicTitle: subTopicTitle,
                item: item,
                index: index
            )

        /*
         * המפתח זהה למפתח שנוצר בתוך
         * coachProgressKey ב־MaterialsView.
         */
        let preferenceKey = [
            "coach_material_progress",
            belt.id,
            topicKey,
            statusId
        ]
        .joined(separator: "_")
        + "_status"

        let storedValue =
            UserDefaults.standard.string(
                forKey: preferenceKey
            )

        return SummaryCoachStatus
            .fromStoredValue(storedValue)
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

        return TopicsEngine.shared
            .topicTitlesFor(belt: belt)
            .map { title in
                let cleanTitle =
                    title.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                var allItems: [SummaryRawItem] = []

                let directItems =
                    ContentRepo.shared.getAllItemsFor(
                        belt: belt,
                        topicTitle: cleanTitle,
                        subTopicTitle: nil
                    )

                allItems.append(
                    contentsOf:
                        directItems.enumerated().map {
                            index,
                            item in

                            SummaryRawItem(
                                title: item,
                                subTopicTitle: nil,
                                indexInStatusGroup: index
                            )
                        }
                )

                let subTopicTitles =
                    ContentRepo.shared.getSubTopicsFor(
                        belt: belt,
                        topicTitle: cleanTitle
                    )
                    .map {
                        $0.title.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                    }
                    .filter {
                        !$0.isEmpty
                    }

                for subTopicTitle in subTopicTitles {
                    let subItems =
                        ContentRepo.shared.getAllItemsFor(
                            belt: belt,
                            topicTitle: cleanTitle,
                            subTopicTitle: subTopicTitle
                        )

                    allItems.append(
                        contentsOf:
                            subItems.enumerated().map {
                                index,
                                item in

                                SummaryRawItem(
                                    title: item,
                                    subTopicTitle: subTopicTitle,
                                    indexInStatusGroup: index
                                )
                            }
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

                    let coachStatus =
                        loadCoachStatus(
                            topicTitle: topicBlock.title,
                            subTopicTitle:
                                raw.subTopicTitle,
                            item: raw.title,
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
                        coachStatus:
                            coachStatus
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
        coachTaughtCount
        + coachPracticedCount
        + coachNeedsReinforcementCount
    }

    private var markedCount: Int {
        effectiveIsCoach
            ? coachMarkedCount
            : doneCount + notDoneCount
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
                return effectiveIsCoach
                    ? tr(
                        "טוען נתוני השוואה מול מאמנים...",
                        "Loading coach comparison data..."
                    )
                    : tr(
                        "טוען נתוני השוואה...",
                        "Loading comparison data..."
                    )
            }

            guard comparisonHasEnoughData else {
                return effectiveIsCoach
                    ? tr(
                        "אין עדיין מספיק נתוני מאמנים להשוואה.",
                        "There is not enough coach data for comparison yet."
                    )
                    : tr(
                        "אין עדיין מספיק נתונים להשוואה מול מתאמנים אחרים.",
                        "There is not enough data yet to compare with other trainees."
                    )
            }

            if percentAll >=
                comparisonAveragePercent {

                return effectiveIsCoach
                    ? tr(
                        "התקדמות החומר שלך גבוהה משל \(comparisonBetterThanPercent)% מהמאמנים בחגורה הזאת.",
                        "Your material progress is above \(comparisonBetterThanPercent)% of coaches for this belt."
                    )
                    : tr(
                        "אתה מעל \(comparisonBetterThanPercent)% מהמתאמנים בחגורה שלך.",
                        "You are above \(comparisonBetterThanPercent)% of trainees in your belt."
                    )
            }

            return effectiveIsCoach
                ? tr(
                    "התקדמות החומר נמוכה מממוצע המאמנים בחגורה הזאת.",
                    "Material progress is below the coach average for this belt."
                )
                : tr(
                    "אתה מתחת לממוצע המתאמנים בחגורה שלך.",
                    "You are below the average for trainees in your belt."
                )
        }

    private func saveProgressAndLoadComparison() {
        guard totalCount > 0,
              let uid = Auth.auth().currentUser?.uid,
              !uid.isEmpty else {
            comparisonTraineesCount = 0
            comparisonAveragePercent = 0
            comparisonBetterThanPercent = 0
            isComparisonLoading = false
            return
        }

        isComparisonLoading = true

        let db = Firestore.firestore()
        let beltId = belt.id
        let progressData: [String: Any] = [
            "uid": uid,
            "userId": uid,
            "beltId": beltId,
            "summaryRole": summaryRoleId,
            "knownPercent": percentAll,
            "knownCount":
                effectiveIsCoach
                ? 0
                : doneCount,
            "notKnownCount":
                effectiveIsCoach
                ? 0
                : notDoneCount,
            "coachNotTaughtCount":
                effectiveIsCoach
                ? coachNotTaughtCount
                : 0,
            "coachTaughtCount":
                effectiveIsCoach
                ? coachTaughtCount
                : 0,
            "coachPracticedCount":
                effectiveIsCoach
                ? coachPracticedCount
                : 0,
            "coachNeedsReinforcementCount":
                effectiveIsCoach
                ? coachNeedsReinforcementCount
                : 0,
            "completedCount":
                effectiveIsCoach
                ? coachMarkedCount
                : doneCount,
            "totalCount": totalCount,
            "updatedAt":
                FieldValue.serverTimestamp()
        ]

        /*
         * לכל משתמש, חגורה ותפקיד נוצר מסמך נפרד:
         *
         * uid_belt_trainee
         * uid_belt_coach
         */
        let progressDocumentId =
            "\(uid)_\(beltId)_\(summaryRoleId)"

        db.collection("userProgress")
            .document(progressDocumentId)
            .setData(
                progressData,
                merge: true
            ) { _ in
                /*
                 * גם ההשוואה מסוננת לפי התפקיד.
                 *
                 * מאמן מושווה רק למאמנים,
                 * ומתאמן מושווה רק למתאמנים.
                 */
                db.collection("userProgress")
                    .whereField(
                        "beltId",
                        isEqualTo: beltId
                    )
                    .whereField(
                        "summaryRole",
                        isEqualTo: summaryRoleId
                    )
                    .getDocuments { snapshot, _ in
                        var percentByUser: [String: Int] = [:]

                        for document in
                            snapshot?.documents ?? [] {

                            let data =
                                document.data()

                            let storedRole =
                                data["summaryRole"]
                                as? String
                                ?? ""

                            /*
                             * בדיקת הגנה נוספת מעבר
                             * לסינון של שאילתת Firestore.
                             */
                            guard storedRole
                                == summaryRoleId else {
                                continue
                            }

                            let total =
                                (
                                    data["totalCount"]
                                    as? NSNumber
                                )?.intValue
                                ?? 0

                            let progressPercent =
                                (
                                    data["knownPercent"]
                                    as? NSNumber
                                )?.intValue
                                ?? -1

                            let storedUserId =
                                data["uid"] as? String
                                ?? data["userId"] as? String
                                ?? data["userUid"] as? String
                                ?? document.documentID

                            let userKey =
                                "\(storedUserId)_\(storedRole)"

                            if total > 0,
                               (0...100).contains(
                                    progressPercent
                               ) {
                                percentByUser[userKey] =
                                    progressPercent
                            }
                        }

                        let percentages = Array(percentByUser.values)

                        DispatchQueue.main.async {
                            comparisonTraineesCount = percentages.count

                            if percentages.isEmpty {
                                comparisonAveragePercent = 0
                                comparisonBetterThanPercent = 0
                            } else {
                                comparisonAveragePercent = percentages.reduce(0, +) / percentages.count
                                let belowOrEqual = percentages.filter { $0 <= percentAll }.count
                                comparisonBetterThanPercent = Int(
                                    Double(belowOrEqual) / Double(percentages.count) * 100.0
                                )
                            }

                            isComparisonLoading = false
                        }
                    }
            }
    }
    
    private var summaryTitle: String {
        "\(tr("סיכום", "Summary")) "
        + beltDisplayTitleForSummary()
    }
    
    private func beltDisplayTitleForSummary() -> String {
        let clean = belt.heb.trimmingCharacters(in: .whitespacesAndNewlines)

        if clean.hasPrefix("חגורה") {
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
            KmiGradientBackground(forceTraineeStyle: false)

            VStack(spacing: 0) {

                summaryTopControls

                ScrollView {
                    VStack(spacing: 12) {

                        if showComparisonCard {
                            WhiteCard {
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
                                    isCoach:
                                        effectiveIsCoach,
                                    isEnglish:
                                        isEnglish,
                                    onClose: {
                                        showComparisonCard = false
                                    }
                                )
                                .padding(.vertical, 12)
                                .padding(.horizontal, 12)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .transition(.opacity.combined(with: .move(edge: .top)))
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
                                        percent: markedPercentAll,
                                        doneCount:
                                            effectiveIsCoach
                                            ? coachMarkedCount
                                            : doneCount,
                                        notDoneCount:
                                            effectiveIsCoach
                                            ? 0
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
                                        LazyVGrid(
                                            columns: [
                                                GridItem(
                                                    .flexible(),
                                                    spacing: 8
                                                ),
                                                GridItem(
                                                    .flexible(),
                                                    spacing: 8
                                                )
                                            ],
                                            spacing: 8
                                        ) {
                                            SummaryStatusChip(
                                                title: tr(
                                                    "תורגל: \(coachPracticedCount)",
                                                    "Practiced: \(coachPracticedCount)"
                                                ),
                                                tint: Color(
                                                    red: 0.18,
                                                    green: 0.61,
                                                    blue: 0.31
                                                )
                                            )

                                            SummaryStatusChip(
                                                title: tr(
                                                    "נדרש חיזוק: \(coachNeedsReinforcementCount)",
                                                    "Reinforce: \(coachNeedsReinforcementCount)"
                                                ),
                                                tint: Color(
                                                    red: 0.20,
                                                    green: 0.47,
                                                    blue: 0.83
                                                )
                                            )

                                            SummaryStatusChip(
                                                title: tr(
                                                    "נלמד: \(coachTaughtCount)",
                                                    "Taught: \(coachTaughtCount)"
                                                ),
                                                tint: Color(
                                                    red: 0.95,
                                                    green: 0.63,
                                                    blue: 0.38
                                                )
                                            )

                                            SummaryStatusChip(
                                                title: tr(
                                                    "לא נלמד: \(coachNotTaughtCount)",
                                                    "Not taught: \(coachNotTaughtCount)"
                                                ),
                                                tint: Color(
                                                    red: 0.54,
                                                    green: 0.58,
                                                    blue: 0.62
                                                )
                                            )
                                        }
                                        .padding(.top, 2)
                                    } else {
                                        HStack(spacing: 8) {
                                            SummaryStatusChip(
                                                title: tr(
                                                    "יודע: \(doneCount)",
                                                    "Known: \(doneCount)"
                                                ),
                                                tint: Color(
                                                    red: 0.30,
                                                    green: 0.69,
                                                    blue: 0.31
                                                )
                                            )

                                            SummaryStatusChip(
                                                title: tr(
                                                    "לא יודע: \(notDoneCount)",
                                                    "Not known: \(notDoneCount)"
                                                ),
                                                tint: Color(
                                                    red: 0.90,
                                                    green: 0.22,
                                                    blue: 0.21
                                                )
                                            )

                                            SummaryStatusChip(
                                                title: tr(
                                                    "לא סומן: \(remainingCount)",
                                                    "Open: \(remainingCount)"
                                                ),
                                                tint: Color(
                                                    red: 0.60,
                                                    green: 0.64,
                                                    blue: 0.70
                                                )
                                            )
                                        }
                                        .padding(.top, 2)
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
                            WhiteCard {
                                VStack(spacing: 12) {
                                    ProgressView()
                                        .controlSize(.large)
                                        .tint(summaryPrimaryTextColor)

                                    Text(
                                        tr(
                                            "טוען את נתוני הסיכום...",
                                            "Loading summary data..."
                                        )
                                    )
                                    .kmiFont(
                                        size: 16,
                                        weight: .bold
                                    )
                                    .foregroundStyle(
                                        summaryPrimaryTextColor
                                    )
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
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
                            ForEach(blocks) { block in
                                TopicSummaryCard(
                                    block: block,
                                    isCoach:
                                        effectiveIsCoach,
                                    isEnglish:
                                        isEnglish
                                )
                                .padding(
                                    .horizontal,
                                    16
                                )
                            }
                        }

                        Spacer(minLength: 18)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 88)
                }
            }

            VStack {
                Spacer()

                VStack(spacing: 0) {
                    summaryBottomBackButton
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 10)
                }
                .background(
                    summaryBottomSurfaceColor
                        .ignoresSafeArea(edges: .bottom)
                )
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(
                            isDarkMode
                                ? Color.white.opacity(0.10)
                                : Color.black.opacity(0.07)
                        )
                        .frame(height: 1)
                }
            }
        }
        .environment(\.layoutDirection, screenLayoutDirection)
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
            }
        }
    }
    
    private var summaryTopControls: some View {
        HStack(spacing: 12) {
            summaryTopActionButton(
                title: tr("התקדמות", "Progress"),
                systemImage: "chart.line.uptrend.xyaxis",
                isOpen: showProgressCard
            ) {
                showComparisonCard = false
                showProgressCard.toggle()
            }

            summaryTopActionButton(
                title: tr("השוואה", "Compare"),
                systemImage: "chart.line.uptrend.xyaxis",
                isOpen: showComparisonCard
            ) {
                showProgressCard = false

                let willOpen = !showComparisonCard
                showComparisonCard = willOpen

                if willOpen {
                    saveProgressAndLoadComparison()
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 28)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private func summaryTopActionButton(
        title: String,
        systemImage: String,
        isOpen: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .kmiFont(
                        size: 15,
                        weight: .heavy
                    )
                    .foregroundStyle(
                        Color.orange.opacity(0.92)
                    )

                Text(title)
                    .kmiFont(
                        size: 17,
                        weight: .black
                    )
                    .foregroundStyle(
                        summaryPrimaryTextColor
                    )

                Image(
                    systemName:
                        isOpen
                        ? "chevron.up"
                        : "chevron.down"
                )
                .kmiFont(
                    size: 12,
                    weight: .black
                )
                .foregroundStyle(
                    summarySecondaryTextColor
                )
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background {
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors:
                            isDarkMode
                            ? [
                                Color(
                                    red: 0.10,
                                    green: 0.13,
                                    blue: 0.20
                                ),
                                isOpen
                                    ? Color.orange.opacity(0.18)
                                    : Color(
                                        red: 0.07,
                                        green: 0.10,
                                        blue: 0.16
                                    ),
                                Color.orange.opacity(0.08)
                            ]
                            : [
                                Color.white.opacity(0.98),
                                isOpen
                                    ? Color.orange.opacity(0.11)
                                    : Color.white.opacity(0.90),
                                Color.orange.opacity(0.06)
                            ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .stroke(
                    isOpen
                        ? Color.orange.opacity(0.32)
                        : (
                            isDarkMode
                            ? Color.white.opacity(0.12)
                            : Color.black.opacity(0.06)
                        ),
                    lineWidth: 1
                )
            }
            .shadow(
                color:
                    Color.black.opacity(
                        isDarkMode ? 0.28 : 0.10
                    ),
                radius: 7,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(.plain)
    }

    private var summaryBottomBackButton: some View {
        Button {
            nav.pop()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.50, green: 0.00, blue: 1.00),
                                Color(red: 0.25, green: 0.32, blue: 0.72),
                                Color(red: 0.02, green: 0.66, blue: 0.96)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .kmiFont(size: 15, weight: .black)

                    Text(tr("חזרה למסך הנושאים", "Back to topics screen"))
                        .kmiFont(size: 17, weight: .black)
                }
                .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }

    private func beltShortTextForSummary() -> String {
        switch belt {
        case .white:
            return "ל"
        case .yellow:
            return "צ"
        case .orange:
            return "כ"
        case .green:
            return "י"
        case .blue:
            return "כח"
        case .brown:
            return "ח"
        case .black:
            return "ש"
        default:
            return "ח"
        }
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
    
    private struct BeltComparisonStatusCard: View {
        let traineesCount: Int
        let averagePercent: Int
        let userPercent: Int
        let statusText: String
        let hasEnoughData: Bool
        let isCoach: Bool
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
                        isCoach
                            ? tr(
                                "התקדמות החומר בחגורה",
                                "Belt material progress"
                            )
                            : tr(
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
                                isCoach
                                ? tr(
                                    "עודכן",
                                    "Updated"
                                )
                                : tr(
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
                                isCoach
                                ? tr(
                                    "מאמנים",
                                    "Coaches"
                                )
                                : tr(
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

        private var notDonePart: CGFloat {
            guard totalCount > 0 else { return 0 }
            return CGFloat(notDoneCount) / CGFloat(totalCount)
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
                    .trim(from: 0, to: donePart)
                    .stroke(
                        Color(red: 0.30, green: 0.69, blue: 0.31),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Circle()
                    .trim(from: donePart, to: min(donePart + notDonePart, 1.0))
                    .stroke(
                        Color(red: 0.90, green: 0.22, blue: 0.21),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

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
                        ? "\(doneCount + notDoneCount) of \(totalCount)"
                        : "\(doneCount + notDoneCount) מתוך \(totalCount)"
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
            Text(title)
                .kmiFont(
                    size: 10,
                    weight: .black
                )
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
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
            isDarkMode
                ? [
                    Color(
                        red: 0.09,
                        green: 0.12,
                        blue: 0.19
                    ),
                    Color(
                        red: 0.06,
                        green: 0.09,
                        blue: 0.15
                    ),
                    Color(
                        red: 0.08,
                        green: 0.11,
                        blue: 0.18
                    )
                ]
                : [
                    Color.white.opacity(0.98),
                    Color.white.opacity(0.88),
                    Color.white.opacity(0.95)
                ]
        }
        
        @State private var expanded: Bool = true

        private var frameAlignment: Alignment {
            isEnglish ? .leading : .trailing
        }

        private var textAlignment: TextAlignment {
            isEnglish ? .leading : .trailing
        }
        
        var body: some View {
            VStack(spacing: 8) {
                Button {
                    withAnimation(.easeOut(duration: 0.14)) {
                        expanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        ButtonIcon(expanded: expanded)

                        Spacer(minLength: 0)

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
                    VStack(spacing: 0) {
                        ForEach(block.items) { item in
                            SummaryRow(
                                title: item.title,
                                mark: item.mark,
                                coachStatus:
                                    item.coachStatus,
                                isCoach: isCoach,
                                isEnglish: isEnglish
                            )

                            if item.id
                                != block.items.last?.id {
                                Divider()
                                    .opacity(0.14)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .transition(.opacity.combined(with: .move(edge: .top)))
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
                    cornerRadius: 18,
                    style: .continuous
                )
                .stroke(
                    isDarkMode
                        ? Color.white.opacity(0.12)
                        : Color.black.opacity(0.04),
                    lineWidth: 1
                )
            }
            .shadow(
                color:
                    Color.black.opacity(
                        isDarkMode ? 0.30 : 0.06
                    ),
                radius: 6,
                x: 0,
                y: 3
            )
        }

        private struct ButtonIcon: View {
            let expanded: Bool

            var body: some View {
                Image(
                    systemName:
                        expanded
                        ? "chevron.up"
                        : "chevron.down"
                )
                .kmiFont(
                    size: 15,
                    weight: .black
                )
                .foregroundStyle(.secondary)
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
        let coachStatus: SummaryCoachStatus
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

        private var coachStatusColor: Color {
            switch coachStatus {
            case .notTaught:
                return Color(
                    red: 0.54,
                    green: 0.58,
                    blue: 0.62
                )

            case .taught:
                return Color(
                    red: 0.95,
                    green: 0.63,
                    blue: 0.38
                )

            case .practiced:
                return Color(
                    red: 0.18,
                    green: 0.61,
                    blue: 0.31
                )

            case .needsReinforcement:
                return Color(
                    red: 0.20,
                    green: 0.47,
                    blue: 0.83
                )
            }
        }

        private var coachStatusSymbol: String {
            switch coachStatus {
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

        private var coachStatusTitle: String {
            switch coachStatus {
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
                    : "נדרש חיזוק"
            }
        }

        private var traineeStatusColor: Color {
            switch mark {
            case .done:
                return Color.green.opacity(0.85)

            case .notDone:
                return Color.red.opacity(0.80)

            case nil:
                return Color.gray.opacity(0.35)
            }
        }

        private var traineeSystemImage: String {
            switch mark {
            case .done:
                return "checkmark.circle.fill"

            case .notDone:
                return "xmark.circle.fill"

            case nil:
                return "circle.fill"
            }
        }

        var body: some View {
            HStack(spacing: 10) {
                if isCoach {
                    VStack(spacing: 3) {
                        ZStack {
                            Circle()
                                .fill(
                                    coachStatusColor
                                )
                                .frame(
                                    width: 30,
                                    height: 30
                                )

                            Text(
                                coachStatusSymbol
                            )
                            .kmiFont(
                                size: 15,
                                weight: .heavy
                            )
                            .foregroundStyle(
                                Color.white
                            )
                        }

                        Text(
                            coachStatusTitle
                        )
                        .kmiFont(
                            size: 9,
                            weight: .heavy
                        )
                        .foregroundStyle(
                            coachStatusColor
                        )
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                        .multilineTextAlignment(
                            .center
                        )
                    }
                    .frame(width: 76)
                } else {
                    Image(
                        systemName:
                            traineeSystemImage
                    )
                    .kmiFont(
                        size: 18,
                        weight: .heavy
                    )
                    .foregroundStyle(
                        traineeStatusColor
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
                    ? coachStatusColor.opacity(
                        coachStatus
                            == .notTaught
                            ? 0
                            : 0.07
                    )
                    : Color.clear
            )
        }
    }
}
