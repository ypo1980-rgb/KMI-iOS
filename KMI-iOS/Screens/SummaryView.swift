import SwiftUI
import Shared
import CoreFoundation
import UIKit

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

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
             "known",
             "know":
            return .done

        case "partiallyknown",
             "partially_known",
             "partial":
            return .partiallyKnown

        case "notdone",
             "not_done",
             "unknown",
             "dontknow":
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

private struct SummarySelectedExercise: Identifiable, Hashable {
    let id: String
    let topicTitle: String
    let title: String
}

struct SummaryRowItem: Identifiable, Equatable {
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

    let coachUpdatedAt:
        [SummaryCoachStatus: Double]
}

struct SummaryTopicBlock: Identifiable, Equatable {
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
        KmiAppTheme.onSurface(for: colorScheme)
    }
    
    private var summarySecondaryTextColor: Color {
        KmiAppTheme.onSurfaceVariant(for: colorScheme)
    }
    
    @State private var showProgressCard: Bool = false
    @State private var showComparisonCard: Bool = false
    @State private var marksRevision: Int = 0
    
    @State private var isSummaryVisible = false
    @State private var isPreparingSummaryPDF = false
    @State private var summaryPDFRequestID = UUID()
    @State private var showSummaryShareSheet = false
    @State private var summaryShareItems: [Any] = []
    @State private var showSummaryPDFError = false
    
    @State private var selectedExercise:
    SummarySelectedExercise?
    
    @State private var selectedNoteExercise:
    SummarySelectedExercise?
    
    @State private var noteDraft = ""
    @State private var noteUserID = ""
    @State private var noteExerciseID = ""
    @State private var noteBeltID = ""
    @State private var noteIdentity:
    ExerciseIdentityResolverIOS.Identity?
    @State private var showNoteUnavailable = false
    @State private var noteSaveFailed = false
    
    @ObservedObject private var exerciseNotes =
    ExerciseNotesStore.shared
    
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
    @State private var comparisonRequestID = UUID()
    
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
    
    private struct SummaryStorageLocation: Hashable {
        let topicKey: String
        let statusID: String
    }

    private func summaryStorageLocations(
        topicTitle: String,
        subTopicTitle: String?,
        item: String,
        index: Int
    ) -> [SummaryStorageLocation] {
        let root = topicTitle.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let requestedItem = normalizeCoachStatusPart(item)

        var locations: [SummaryStorageLocation] = []
        var seen = Set<SummaryStorageLocation>()

        func add(
            topicKey: String,
            itemIndex: Int,
            rawItem: String
        ) {
            let statusID = [
                "status",
                belt.id,
                topicKey,
                String(itemIndex),
                normalizeCoachStatusPart(rawItem)
            ]
            .joined(separator: "_")

            let location = SummaryStorageLocation(
                topicKey: topicKey,
                statusID: statusID
            )

            if seen.insert(location).inserted {
                locations.append(location)
            }
        }

        func addMatchingItems(
            _ items: [String],
            topicKey: String
        ) {
            // זהה להסרת הכפילויות לפני יצירת rows ב־MaterialsView.
            var seenItems = Set<String>()
            let uniqueItems = items.filter {
                seenItems.insert($0).inserted
            }

            for (itemIndex, rawItem) in uniqueItems.enumerated() {
                guard normalizeCoachStatusPart(rawItem)
                    == requestedItem
                else {
                    continue
                }

                add(
                    topicKey: topicKey,
                    itemIndex: itemIndex,
                    rawItem: rawItem
                )
            }
        }

        // המזהה שבו השתמש הסיכום עד עכשיו נשאר נתמך.
        add(
            topicKey: coachTopicKey(
                topicTitle: root,
                subTopicTitle: subTopicTitle
            ),
            itemIndex: index,
            rawItem: item
        )

        // פתיחה ישירה של כל תרגילי הנושא.
        addMatchingItems(
            ContentRepo.shared.getAllItemsFor(
                belt: belt,
                topicTitle: root,
                subTopicTitle: nil
            ),
            topicKey: root
        )

        let subtopics = ContentRepo.shared.getSubTopicsFor(
            belt: belt,
            topicTitle: root
        )

        for subtopic in subtopics {
            let parent = subtopic.title.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard !parent.isEmpty else {
                continue
            }

            let parentKey = "\(root)__\(parent)"

            addMatchingItems(
                ContentRepo.shared.getAllItemsFor(
                    belt: belt,
                    topicTitle: root,
                    subTopicTitle: parent
                ),
                topicKey: parentKey
            )

            let nestedTitles =
                ContentRepo.shared.getNestedSubTopicTitles(
                    belt: belt,
                    topicTitle: root,
                    subTopicTitle: parent
                )

            var combinedNestedItems: [String] = []

            for nestedTitle in nestedTitles {
                let nested = nestedTitle.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

                guard !nested.isEmpty else {
                    continue
                }

                let nestedItems =
                    ContentRepo.shared.getNestedItemsFor(
                        belt: belt,
                        topicTitle: root,
                        subTopicTitle: parent,
                        nestedSubTopicTitle: nested
                    )

                combinedNestedItems.append(
                    contentsOf: nestedItems
                )

                addMatchingItems(
                    nestedItems,
                    topicKey: "\(parentKey)__\(nested)"
                )
            }

            // MaterialsView עשוי להציג את כל הילדים
            // יחד תחת מפתח תת־הנושא ההורה.
            addMatchingItems(
                combinedNestedItems,
                topicKey: parentKey
            )
        }

        return locations
    }

    private func latestSummaryMaterialMark(
        topicTitle: String,
        subTopicTitle: String?,
        item: String,
        index: Int
    ) -> (rawValue: String, timestamp: Double)? {
        let defaults = UserDefaults.standard

        var latest: (
            rawValue: String,
            timestamp: Double
        )?

        for location in summaryStorageLocations(
            topicTitle: topicTitle,
            subTopicTitle: subTopicTitle,
            item: item,
            index: index
        ) {
            guard let rawValue = defaults.string(
                forKey: "mark.\(location.statusID)"
            ) else {
                continue
            }

            let clean = rawValue.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).lowercased()

            guard clean == "unmarked"
                    || SummaryMark.fromStoredValue(rawValue) != nil
            else {
                continue
            }

            let dateKey = [
                "trainee_material_updated_at",
                belt.id,
                location.topicKey,
                location.statusID
            ]
            .joined(separator: "_")

            let storedTimestamp = defaults.double(
                forKey: dateKey
            )

            let timestamp = storedTimestamp.isFinite
                && storedTimestamp > 0
                ? storedTimestamp
                : 0

            if let current = latest {
                if timestamp > current.timestamp {
                    latest = (rawValue, timestamp)
                }
            } else {
                latest = (rawValue, timestamp)
            }
        }

        return latest
    }

    private func loadMark(
        topicTitle: String,
        subTopicTitle: String?,
        item: String,
        index: Int
    ) -> SummaryMark? {
        let defaults = UserDefaults.standard

        if let saved = latestSummaryMaterialMark(
            topicTitle: topicTitle,
            subTopicTitle: subTopicTitle,
            item: item,
            index: index
        ) {
            let subjectKey =
                "kmi.subject.mark.\(belt.id)."
                + topicTitle.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                + "."
                + item.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            let subjectTimestamp = defaults.double(
                forKey: "\(subjectKey).updatedAt"
            ) * 1_000

            if subjectTimestamp.isFinite,
               subjectTimestamp > saved.timestamp,
               let subjectRaw = defaults.string(
                    forKey: subjectKey
               ) {
                let cleanSubject = subjectRaw
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .lowercased()

                if cleanSubject == "unmarked" {
                    return nil
                }

                if let subjectMark =
                    SummaryMark.fromStoredValue(subjectRaw) {
                    return subjectMark
                }
            }

            // כולל unmarked: איפוס מפורש אינו נופל
            // לנתון ישן שנשמר במפתח אחר.
            return SummaryMark.fromStoredValue(
                saved.rawValue
            )
        }

        let beltId = belt.id
        let cleanTopic = summarySafePart(topicTitle)
        let cleanSubTopic = subTopicTitle.map(summarySafePart) ?? ""
        let cleanItem = summarySafePart(item)
        
        let topicKey = cleanSubTopic.isEmpty
        ? cleanTopic
        : "\(cleanTopic)__\(cleanSubTopic)"
        
        let materialsStatusID = coachStatusId(
            topicTitle: topicTitle,
            subTopicTitle: subTopicTitle,
            item: item,
            index: index
        )
        
        let materialsMarkKey = "mark.\(materialsStatusID)"
        
        let subjectMarkKey =
        "kmi.subject.mark.\(beltId)."
        + topicTitle.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        + "."
        + item.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        
        let materialsTopicKey = coachTopicKey(
            topicTitle: topicTitle,
            subTopicTitle: subTopicTitle
        )
        
        let materialsUpdatedAtKey = [
            "trainee_material_updated_at",
            beltId,
            materialsTopicKey,
            materialsStatusID
        ]
            .joined(separator: "_")
        
        /*
         * MaterialsView שומר זמן במילישניות;
         * מסך לפי נושא שומר זמן בשניות.
         */
        let materialsUpdatedAt = defaults.double(
            forKey: materialsUpdatedAtKey
        )
        
        let subjectUpdatedAt = defaults.double(
            forKey: "\(subjectMarkKey).updatedAt"
        ) * 1_000
        
        if defaults.object(forKey: materialsMarkKey) != nil,
           let subjectRaw = defaults.string(forKey: subjectMarkKey),
           materialsUpdatedAt.isFinite,
           subjectUpdatedAt.isFinite,
           materialsUpdatedAt > 0,
           subjectUpdatedAt > materialsUpdatedAt {
            
            let normalized = subjectRaw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            
            if normalized == "unmarked" {
                return nil
            }
            
            if let mark = SummaryMark.fromStoredValue(subjectRaw) {
                return mark
            }
        }
        
        let directStringKeys = [
            "mark.\(materialsStatusID)",
            
            "mark.status_\(beltId)_\(topicTitle)_\(index)_\(item)",
            "mark.status_\(beltId)_\(topicTitle)_\(index)_\(cleanItem)",
            
            "mark.status_\(beltId)_\(topicKey)_\(index)_\(item)",
            "mark.status_\(beltId)_\(topicKey)_\(index)_\(cleanItem)",
            
            "kmi.mark.\(beltId).\(topicTitle).\(item)",
            "kmi.mark.\(beltId).\(cleanTopic).\(cleanItem)",
            "kmi.mark.\(beltId).\(topicKey).\(cleanItem)",
            
            // מפתח קיים של מסך התרגילים לפי נושא.
            "kmi.subject.mark.\(beltId).\(topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)).\(item.trimmingCharacters(in: .whitespacesAndNewlines))"
        ]
        
        for key in directStringKeys {
            guard let raw = defaults.string(forKey: key) else {
                continue
            }
            
            let normalized = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            
            /*
             * מצב מפורש של "לא סומן" עוצר את החיפוש,
             * כדי שסימון ישן במפתח אחר לא יחזור.
             */
            if normalized == "unmarked" {
                return nil
            }
            
            if let mark = SummaryMark.fromStoredValue(raw) {
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
            guard let value = defaults.object(forKey: key),
                  CFGetTypeID(value as CFTypeRef) == CFBooleanGetTypeID(),
                  let boolValue = value as? Bool else {
                continue
            }
            
            return boolValue ? .done : .notDone
        }
        
        /*
         * לא נמצא מפתח מדויק לסימון.
         * אין להסיק סטטוס ממפתח אחר שמכיל
         * במקרה את שם התרגיל.
         */
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
    
    private func loadCoachUpdatedAt(
        topicTitle: String,
        subTopicTitle: String?,
        item: String,
        index: Int,
        statuses: Set<SummaryCoachStatus>
    ) -> [SummaryCoachStatus: Double] {
        let progress = resolvedSummaryCoachProgress(
            topicTitle: topicTitle,
            subTopicTitle: subTopicTitle,
            item: item,
            index: index
        )

        return progress.dates.filter {
            statuses.contains($0.key)
        }
    }
    
    private func resolvedSummaryCoachProgress(
        topicTitle: String,
        subTopicTitle: String?,
        item: String,
        index: Int
    ) -> (
        statuses: Set<SummaryCoachStatus>,
        dates: [SummaryCoachStatus: Double]
    ) {
        let defaults = UserDefaults.standard

        let selectable: [SummaryCoachStatus] = [
            .taught,
            .practiced,
            .needsReinforcement
        ]

        var bestStatuses = Set<SummaryCoachStatus>()
        var bestDates: [SummaryCoachStatus: Double] = [:]
        var bestTimestamp: Double = -1

        for location in summaryStorageLocations(
            topicTitle: topicTitle,
            subTopicTitle: subTopicTitle,
            item: item,
            index: index
        ) {
            let baseKey = [
                "coach_material_progress",
                belt.id,
                location.topicKey,
                location.statusID
            ]
            .joined(separator: "_")

            let hasSelectedFields = selectable.contains {
                defaults.object(
                    forKey: "\(baseKey)_\($0.rawValue)_selected"
                ) != nil
            }

            let legacyRaw = defaults.string(
                forKey: "\(baseKey)_status"
            )

            guard hasSelectedFields || legacyRaw != nil else {
                continue
            }

            var statuses = Set<SummaryCoachStatus>()
            var dates: [SummaryCoachStatus: Double] = [:]

            let legacyDate = defaults.double(
                forKey: "\(baseKey)_updated_at"
            )

            var newestTimestamp = legacyDate.isFinite
                && legacyDate > 0
                ? legacyDate
                : 0

            if hasSelectedFields {
                for status in selectable {
                    guard defaults.bool(
                        forKey:
                            "\(baseKey)_\(status.rawValue)_selected"
                    ) else {
                        continue
                    }

                    statuses.insert(status)

                    let timestamp = defaults.double(
                        forKey:
                            "\(baseKey)_\(status.rawValue)_updated_at"
                    )

                    if timestamp.isFinite,
                       timestamp > 0 {
                        dates[status] = timestamp / 1_000
                        newestTimestamp = max(
                            newestTimestamp,
                            timestamp
                        )
                    }
                }
            } else {
                let legacyStatus =
                    SummaryCoachStatus.fromStoredValue(
                        legacyRaw
                    )

                if legacyStatus != .notTaught {
                    statuses.insert(legacyStatus)

                    if legacyDate.isFinite,
                       legacyDate > 0 {
                        dates[legacyStatus] =
                            legacyDate / 1_000
                    }
                }
            }

            guard newestTimestamp > bestTimestamp else {
                continue
            }

            bestTimestamp = newestTimestamp
            bestStatuses = Set(
                selectable.filter {
                    statuses.contains($0)
                }
                .prefix(2)
            )
            bestDates = dates.filter {
                bestStatuses.contains($0.key)
            }
        }

        return (bestStatuses, bestDates)
    }

    private func loadCoachStatuses(
        topicTitle: String,
        subTopicTitle: String?,
        item: String,
        index: Int
    ) -> Set<SummaryCoachStatus> {
        resolvedSummaryCoachProgress(
            topicTitle: topicTitle,
            subTopicTitle: subTopicTitle,
            item: item,
            index: index
        ).statuses
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
                        coachStatuses,
                    coachUpdatedAt: loadCoachUpdatedAt(
                        topicTitle: topicBlock.title,
                        subTopicTitle: raw.subTopicTitle,
                        item: raw.title,
                        index: raw.indexInStatusGroup,
                        statuses: coachStatuses
                    )
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
    
    private var summaryCurrentUserID: String {
#if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid ?? ""
#else
        return ""
#endif
    }
    
    private func invalidateComparisonRequest() {
        comparisonRequestID = UUID()
        isComparisonLoading = false
        
        // בקשת קבוצות שטרם הסתיימה אינה נחשבת לנתונים טעונים.
        if !coachGroupProgressLoaded {
            coachGroupProgress = nil
            coachGroupProgressHasError = false
        }
    }
    
    private func loadCoachGroupProgress() {
        guard effectiveIsCoach, showComparisonCard else {
            return
        }
        
        let requestID = UUID()
        comparisonRequestID = requestID
        
        let requestedRoleID = summaryRoleId
        let requestedBeltID = belt.id
        let requestedUserID = summaryCurrentUserID
        
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
                            requestedBeltID
                    )
                
                await MainActor.run {
                    guard comparisonRequestID == requestID,
                          summaryRoleId == requestedRoleID,
                          belt.id == requestedBeltID,
                          summaryCurrentUserID == requestedUserID,
                          showComparisonCard else {
                        return
                    }
                    
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
                    guard comparisonRequestID == requestID,
                          summaryRoleId == requestedRoleID,
                          belt.id == requestedBeltID,
                          summaryCurrentUserID == requestedUserID,
                          showComparisonCard else {
                        return
                    }
                    
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
        
        guard !effectiveIsCoach, showComparisonCard else {
            return
        }
        
        let requestID = UUID()
        comparisonRequestID = requestID
        
        let requestedRoleID = summaryRoleId
        let requestedBeltID = belt.id
        let requestedUserID = summaryCurrentUserID
        
        let requestedKnownPercent = percentAll
        let requestedKnownCount = doneCount
        let requestedTotalCount = totalCount
        
        comparisonHasError = false
        isComparisonLoading = true
        
        Task {
            
            do {
                
                /*
                 * השמירה וההשוואה עוברות דרך
                 * UserProgressRepository בלבד.
                 */
                try await UserProgressRepository
                    .saveUserProgress(
                        beltId: requestedBeltID,
                        knownPercent: requestedKnownPercent,
                        knownCount: requestedKnownCount,
                        totalCount: requestedTotalCount
                    )
                
                guard comparisonRequestID == requestID,
                      summaryRoleId == requestedRoleID,
                      belt.id == requestedBeltID,
                      summaryCurrentUserID == requestedUserID,
                      showComparisonCard else {
                    return
                }
                
                let comparison =
                try await UserProgressRepository
                    .loadBeltComparison(
                        beltId: requestedBeltID,
                        userKnownPercent: requestedKnownPercent
                    )
                
                await MainActor.run {
                    guard comparisonRequestID == requestID,
                          summaryRoleId == requestedRoleID,
                          belt.id == requestedBeltID,
                          summaryCurrentUserID == requestedUserID,
                          showComparisonCard else {
                        return
                    }
                    
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
                    guard comparisonRequestID == requestID,
                          summaryRoleId == requestedRoleID,
                          belt.id == requestedBeltID,
                          summaryCurrentUserID == requestedUserID,
                          showComparisonCard else {
                        return
                    }
                    
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
        if isEnglish {
            return "\(beltDisplayTitleForSummary()) Summary - \(percentAll)%"
        }

        return "סיכום \(beltDisplayTitleForSummary()) - \(percentAll)%"
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
    
    @MainActor
    private func shareSummaryPDF() {
        guard !isPreparingSummaryPDF else {
            return
        }
        
        let snapshot = blocks
        
        guard snapshot.contains(where: { !$0.items.isEmpty }) else {
            showSummaryPDFError = true
            return
        }
        
        let requestID = UUID()
        let requestedUserID = summaryCurrentUserID
        let requestedRoleID = summaryRoleId
        let requestedBeltID = belt.id
        
        let english = isEnglish
        let coach = effectiveIsCoach
        let subtitle = beltDisplayTitleForSummary()
        
        summaryPDFRequestID = requestID
        isPreparingSummaryPDF = true
        showSummaryPDFError = false
        
        Task { @MainActor in
            await Task.yield()
            
            guard summaryPDFRequestID == requestID,
                  isSummaryVisible,
                  summaryCurrentUserID == requestedUserID,
                  summaryRoleId == requestedRoleID,
                  belt.id == requestedBeltID
            else {
                if summaryPDFRequestID == requestID {
                    isPreparingSummaryPDF = false
                }
                return
            }
            
            defer {
                if summaryPDFRequestID == requestID {
                    isPreparingSummaryPDF = false
                }
            }
            
            do {
                let data = try makeSummaryPDF(
                    blocks: snapshot,
                    isEnglish: english,
                    isCoach: coach,
                    subtitle: subtitle
                )
                
                let directory = FileManager.default
                    .temporaryDirectory
                    .appendingPathComponent(
                        "KmiSummaryExports",
                        isDirectory: true
                    )
                
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )
                
                let fileName = english
                ? "KMI_Summary.pdf"
                : "סיכום_קמי.pdf"
                
                let url = directory
                    .appendingPathComponent(fileName)
                
                try data.write(to: url, options: .atomic)
                
                summaryShareItems = [url]
                showSummaryShareSheet = true
            } catch {
                showSummaryPDFError = true
            }
        }
    }
    
    @MainActor
    private func makeSummaryPDF(
        blocks: [SummaryTopicBlock],
        isEnglish: Bool,
        isCoach: Bool,
        subtitle: String
    ) throws -> Data {
        struct PDFElement {
            // 0 = נושא, 1 = תת־נושא, 2 = תרגיל
            let kind: Int
            let title: String
            let status: String
            let tint: UIColor
            let number: Int
            let height: CGFloat
        }
        
        func localized(
            _ hebrew: String,
            _ english: String
        ) -> String {
            isEnglish ? english : hebrew
        }
        
        func displayTitle(_ value: String) -> String {
            KmiEnglishTitleResolver.title(
                for: value,
                isEnglish: isEnglish
            )
        }
        
        let pageRect = CGRect(
            x: 0,
            y: 0,
            width: 595,
            height: 842
        )
        
        let margin: CGFloat = 34
        let contentWidth = pageRect.width - margin * 2
        let contentTop = KmiPdfHeader.CONTENT_TOP
        let contentBottom =
        pageRect.height
        - KmiPdfFooter.CONTENT_BOTTOM_PADDING
        
        let primary = UIColor(
            KmiAppTheme.onSurface(for: .light)
        )
        let secondary = UIColor(
            KmiAppTheme.onSurfaceVariant(for: .light)
        )
        let surface = UIColor(
            KmiAppTheme.surfaceVariant(for: .light)
        )
        let border = UIColor(
            KmiAppTheme.outlineVariant(for: .light)
        )
        let accent = UIColor(
            KmiAppTheme.secondary(for: .light)
        )
        let accentContent = UIColor(
            KmiAppTheme.onSecondary(for: .light)
        )
        let headerBackground = UIColor(
            KmiAppTheme.tertiaryContainer(for: .light)
        )
        let headerContent = UIColor(
            KmiAppTheme.onTertiaryContainer(for: .light)
        )
        let success = UIColor(
            KmiAppTheme.success(for: .light)
        )
        let warning = UIColor(
            KmiAppTheme.warning(for: .light)
        )
        let error = UIColor(
            KmiAppTheme.error(for: .light)
        )
        
        func attributes(
            size: CGFloat,
            weight: UIFont.Weight,
            color: UIColor,
            centered: Bool = false
        ) -> [NSAttributedString.Key: Any] {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = centered
            ? .center
            : (isEnglish ? .left : .right)
            paragraph.baseWritingDirection = isEnglish
            ? .leftToRight
            : .rightToLeft
            paragraph.lineBreakMode = .byWordWrapping
            paragraph.lineSpacing = 2
            
            return [
                .font: UIFont.systemFont(
                    ofSize: size,
                    weight: weight
                ),
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        }
        
        func textHeight(
            _ text: String,
            width: CGFloat,
            size: CGFloat,
            weight: UIFont.Weight
        ) -> CGFloat {
            ceil(
                (text as NSString).boundingRect(
                    with: CGSize(
                        width: width,
                        height: .greatestFiniteMagnitude
                    ),
                    options: [
                        .usesLineFragmentOrigin,
                        .usesFontLeading
                    ],
                    attributes: attributes(
                        size: size,
                        weight: weight,
                        color: primary
                    ),
                    context: nil
                ).height
            )
        }
        
        func drawText(
            _ text: String,
            rect: CGRect,
            size: CGFloat,
            weight: UIFont.Weight,
            color: UIColor,
            centered: Bool = false
        ) {
            (text as NSString).draw(
                with: rect,
                options: [
                    .usesLineFragmentOrigin,
                    .usesFontLeading
                ],
                attributes: attributes(
                    size: size,
                    weight: weight,
                    color: color,
                    centered: centered
                ),
                context: nil
            )
        }
        
        func status(
            for item: SummaryRowItem
        ) -> (title: String, color: UIColor) {
            if isCoach {
                var titles: [String] = []
                
                if item.coachStatuses.contains(.taught) {
                    titles.append(
                        localized("נלמד", "Taught")
                    )
                }
                
                if item.coachStatuses.contains(.practiced) {
                    titles.append(
                        localized("תורגל", "Practiced")
                    )
                }
                
                if item.coachStatuses.contains(.needsReinforcement) {
                    titles.append(
                        localized("חיזוק", "Reinforcement")
                    )
                }
                
                let color: UIColor
                
                if item.coachStatuses.contains(.needsReinforcement) {
                    color = accent
                } else if item.coachStatuses.contains(.practiced) {
                    color = success
                } else if item.coachStatuses.contains(.taught) {
                    color = warning
                } else {
                    color = secondary
                }
                
                return (
                    titles.isEmpty
                    ? localized("לא נלמד", "Not taught")
                    : titles.joined(separator: " · "),
                    color
                )
            }
            
            switch item.mark {
            case .done:
                return (
                    localized("יודע", "Known"),
                    success
                )
                
            case .partiallyKnown:
                return (
                    localized("חלקית", "Partially known"),
                    warning
                )
                
            case .notDone:
                return (
                    localized("לא יודע", "Not known"),
                    error
                )
                
            case nil:
                return (
                    localized("לא סומן", "Unmarked"),
                    secondary
                )
            }
        }
        
        let allItems = blocks.flatMap(\.items)
        
        guard !allItems.isEmpty else {
            throw CocoaError(.fileWriteUnknown)
        }
        
        let total = allItems.count
        
        let scopeParts = [topic, subTopic].compactMap {
            value -> String? in
            
            guard let clean = value?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !clean.isEmpty
            else {
                return nil
            }
            
            return displayTitle(clean)
        }
        
        let scope = scopeParts.isEmpty
        ? localized(
            "כל נושאי החגורה",
            "All belt topics"
        )
        : scopeParts.joined(separator: " · ")
        
        var summaryLines = [
            subtitle,
            scope,
            localized(
                "סה״כ \(total) תרגילים",
                "\(total) exercises in total"
            )
        ]
        
        let marked: Int
        
        if isCoach {
            let taught = allItems.filter {
                $0.coachStatuses.contains(.taught)
            }.count
            
            let practiced = allItems.filter {
                $0.coachStatuses.contains(.practiced)
            }.count
            
            let reinforcement = allItems.filter {
                $0.coachStatuses.contains(.needsReinforcement)
            }.count
            
            marked = allItems.filter {
                !$0.coachStatuses.isEmpty
            }.count
            
            summaryLines.append(
                localized(
                    "נלמד: \(taught) · תורגל: \(practiced)",
                    "Taught: \(taught) · Practiced: \(practiced)"
                )
            )
            
            summaryLines.append(
                localized(
                    "חיזוק: \(reinforcement) · לא נלמד: \(total - marked)",
                    "Reinforcement: \(reinforcement) · Not taught: \(total - marked)"
                )
            )
        } else {
            let known = allItems.filter {
                $0.mark == .done
            }.count
            
            let partial = allItems.filter {
                $0.mark == .partiallyKnown
            }.count
            
            let unknown = allItems.filter {
                $0.mark == .notDone
            }.count
            
            marked = known + partial + unknown
            
            summaryLines.append(
                localized(
                    "יודע: \(known) · חלקית: \(partial)",
                    "Known: \(known) · Partial: \(partial)"
                )
            )
            
            summaryLines.append(
                localized(
                    "לא יודע: \(unknown) · לא סומן: \(total - marked)",
                    "Not known: \(unknown) · Unmarked: \(total - marked)"
                )
            )
            
            let knownPercent = known * 100 / total
            
            summaryLines.append(
                localized(
                    "שליטה: \(knownPercent)%",
                    "Mastery: \(knownPercent)%"
                )
            )
        }
        
        let markedPercent = marked * 100 / total
        
        summaryLines.append(
            localized(
                "סומנו \(marked) מתוך \(total) · \(markedPercent)%",
                "Marked \(marked) of \(total) · \(markedPercent)%"
            )
        )
        
        let summaryText = summaryLines.joined(separator: "\n")
        
        let summaryHeight = max(
            112,
            textHeight(
                summaryText,
                width: contentWidth - 28,
                size: 11,
                weight: .semibold
            ) + 28
        )
        
        let firstPageTop =
        contentTop + summaryHeight + 12
        
        guard firstPageTop < contentBottom else {
            throw CocoaError(.fileWriteUnknown)
        }
        
        var pages: [[PDFElement]] = [[]]
        var usedHeight: CGFloat = 0
        var runningNumber = 1
        
        func pageCapacity() -> CGFloat {
            contentBottom
            - (pages.count == 1
               ? firstPageTop
               : contentTop)
        }
        
        func appendElement(_ element: PDFElement) {
            pages[pages.count - 1].append(element)
            usedHeight += element.height
        }
        
        for block in blocks where !block.items.isEmpty {
            let completed = block.items.filter {
                isCoach
                ? !$0.coachStatuses.isEmpty
                : $0.mark == .done
            }.count
            
            let percent =
            completed * 100 / block.items.count
            
            let topicText =
            "\(displayTitle(block.title)) · \(percent)%"
            
            let topicElement = PDFElement(
                kind: 0,
                title: topicText,
                status: "",
                tint: headerBackground,
                number: 0,
                height: max(
                    44,
                    textHeight(
                        topicText,
                        width: contentWidth - 28,
                        size: 13,
                        weight: .bold
                    ) + 24
                )
            )
            
            var previousSubtopic = ""
            var isFirstInTopic = true
            
            for item in block.items {
                let cleanSubtopic = item.subTopicTitle?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                ?? ""
                
                let subtopicText = cleanSubtopic.isEmpty
                ? ""
                : displayTitle(cleanSubtopic)
                
                let subtopicElement = PDFElement(
                    kind: 1,
                    title: subtopicText,
                    status: "",
                    tint: accent,
                    number: 0,
                    height: subtopicText.isEmpty
                    ? 0
                    : max(
                        30,
                        textHeight(
                            subtopicText,
                            width: contentWidth - 48,
                            size: 10.5,
                            weight: .bold
                        ) + 18
                    )
                )
                
                let title = displayTitle(
                    ExerciseTitleFormatter.shared
                        .displayName(raw: item.title)
                )
                
                let itemStatus = status(for: item)
                
                let titleHeight = textHeight(
                    title,
                    width: contentWidth - 92,
                    size: 11.5,
                    weight: .bold
                )
                
                let statusHeight = textHeight(
                    itemStatus.title,
                    width: contentWidth - 32,
                    size: 9,
                    weight: .bold
                )
                
                let exerciseElement = PDFElement(
                    kind: 2,
                    title: title,
                    status: itemStatus.title,
                    tint: itemStatus.color,
                    number: runningNumber,
                    height: max(
                        64,
                        titleHeight + statusHeight + 26
                    ) + 8
                )
                
                var needsTopic = isFirstInTopic
                var needsSubtopic =
                !cleanSubtopic.isEmpty
                && (
                    isFirstInTopic
                    || cleanSubtopic != previousSubtopic
                )
                
                let required =
                exerciseElement.height
                + (needsTopic ? topicElement.height : 0)
                + (needsSubtopic ? subtopicElement.height : 0)
                
                if usedHeight + required > pageCapacity() {
                    if !pages[pages.count - 1].isEmpty
                        || pages.count == 1 {
                        pages.append([])
                        usedHeight = 0
                    }
                    
                    needsTopic = true
                    needsSubtopic = !cleanSubtopic.isEmpty
                }
                
                let finalRequired =
                exerciseElement.height
                + (needsTopic ? topicElement.height : 0)
                + (needsSubtopic ? subtopicElement.height : 0)
                
                guard usedHeight + finalRequired <= pageCapacity() else {
                    throw CocoaError(.fileWriteUnknown)
                }
                
                if needsTopic {
                    appendElement(topicElement)
                }
                
                if needsSubtopic {
                    appendElement(subtopicElement)
                }
                
                appendElement(exerciseElement)
                
                previousSubtopic = cleanSubtopic
                isFirstInTopic = false
                runningNumber += 1
            }
        }
        
        let generatedDate: String = {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.dateFormat = "dd/MM/yyyy"
            return formatter.string(from: Date())
        }()
        
        let renderer = UIGraphicsPDFRenderer(
            bounds: pageRect
        )
        
        return renderer.pdfData { context in
            func roundedCard(
                _ rect: CGRect,
                fill: UIColor,
                stroke: UIColor? = nil,
                radius: CGFloat = 12
            ) {
                let path = UIBezierPath(
                    roundedRect: rect,
                    cornerRadius: radius
                )
                
                fill.setFill()
                path.fill()
                
                if let stroke {
                    stroke.setStroke()
                    path.lineWidth = 0.7
                    path.stroke()
                }
            }
            
            for (pageIndex, elements) in pages.enumerated() {
                context.beginPage()
                
                KmiPdfHeader.draw(
                    context: context.cgContext,
                    pageWidth: pageRect.width,
                    isEnglish: isEnglish,
                    titleHebrew: "דו״ח סיכום חגורה",
                    titleEnglish: "Belt Summary Report",
                    subtitleHebrew: subtitle,
                    subtitleEnglish: subtitle,
                    generatedDate: generatedDate
                )
                
                var y = contentTop
                
                if pageIndex == 0 {
                    roundedCard(
                        CGRect(
                            x: margin,
                            y: y,
                            width: contentWidth,
                            height: summaryHeight
                        ),
                        fill: surface,
                        stroke: border
                    )
                    
                    drawText(
                        summaryText,
                        rect: CGRect(
                            x: margin + 14,
                            y: y + 14,
                            width: contentWidth - 28,
                            height: summaryHeight - 28
                        ),
                        size: 11,
                        weight: .semibold,
                        color: primary
                    )
                    
                    y = firstPageTop
                }
                
                for element in elements {
                    switch element.kind {
                    case 0:
                        roundedCard(
                            CGRect(
                                x: margin,
                                y: y,
                                width: contentWidth,
                                height: element.height - 8
                            ),
                            fill: headerBackground,
                            radius: 10
                        )
                        
                        drawText(
                            element.title,
                            rect: CGRect(
                                x: margin + 14,
                                y: y + 8,
                                width: contentWidth - 28,
                                height: element.height - 24
                            ),
                            size: 13,
                            weight: .bold,
                            color: headerContent
                        )
                        
                    case 1:
                        roundedCard(
                            CGRect(
                                x: margin + 10,
                                y: y,
                                width: contentWidth - 20,
                                height: element.height - 6
                            ),
                            fill: surface,
                            radius: 8
                        )
                        
                        drawText(
                            element.title,
                            rect: CGRect(
                                x: margin + 24,
                                y: y + 6,
                                width: contentWidth - 48,
                                height: element.height - 18
                            ),
                            size: 10.5,
                            weight: .bold,
                            color: accent
                        )
                        
                    default:
                        let cardHeight = element.height - 8
                        
                        roundedCard(
                            CGRect(
                                x: margin,
                                y: y,
                                width: contentWidth,
                                height: cardHeight
                            ),
                            fill: surface,
                            stroke: border
                        )
                        
                        let numberX = isEnglish
                        ? margin + 23
                        : pageRect.width - margin - 23
                        
                        let circle = CGRect(
                            x: numberX - 14,
                            y: y + 13,
                            width: 28,
                            height: 28
                        )
                        
                        accent.setFill()
                        UIBezierPath(
                            ovalIn: circle
                        ).fill()
                        
                        drawText(
                            "\(element.number)",
                            rect: CGRect(
                                x: circle.minX,
                                y: circle.midY - 7,
                                width: circle.width,
                                height: 16
                            ),
                            size: 10,
                            weight: .bold,
                            color: accentContent,
                            centered: true
                        )
                        
                        let statusHeight = textHeight(
                            element.status,
                            width: contentWidth - 32,
                            size: 9,
                            weight: .bold
                        )
                        
                        let titleX = isEnglish
                        ? margin + 48
                        : margin + 44
                        
                        drawText(
                            element.title,
                            rect: CGRect(
                                x: titleX,
                                y: y + 11,
                                width: contentWidth - 92,
                                height: cardHeight - statusHeight - 26
                            ),
                            size: 11.5,
                            weight: .bold,
                            color: primary
                        )
                        
                        drawText(
                            element.status,
                            rect: CGRect(
                                x: margin + 16,
                                y: y + cardHeight - statusHeight - 10,
                                width: contentWidth - 32,
                                height: statusHeight
                            ),
                            size: 9,
                            weight: .bold,
                            color: element.tint
                        )
                        
                        let dotX = isEnglish
                        ? pageRect.width - margin - 20
                        : margin + 20
                        
                        element.tint.setFill()
                        UIBezierPath(
                            ovalIn: CGRect(
                                x: dotX - 4,
                                y: y + 16,
                                width: 8,
                                height: 8
                            )
                        ).fill()
                    }
                    
                    y += element.height
                }
                
                KmiPdfFooter.draw(
                    context: context.cgContext,
                    pageWidth: pageRect.width,
                    pageHeight: pageRect.height,
                    pageNumber: pageIndex + 1,
                    totalPages: pages.count,
                    isEnglish: isEnglish
                )
            }
        }
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
                                    KmiAppTheme.surface(
                                        for: colorScheme
                                    ).opacity(0.98)
                                )
                            )
                            .overlay(
                                RoundedRectangle(
                                    cornerRadius: 22,
                                    style: .continuous
                                )
                                .stroke(
                                    KmiAppTheme.outlineVariant(
                                        for: colorScheme
                                    ),
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
                                                .kmiIconSize(13)
                                                .fontWeight(.black)
                                                .foregroundStyle(
                                                    summarySecondaryTextColor
                                                )
                                                .frame(width: 32, height: 32)
                                                .background(
                                                    Circle()
                                                        .fill(
                                                            KmiAppTheme.surfaceVariant(
                                                                for: colorScheme
                                                            )
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
                                    .kmiTypography(.sectionTitle)
                                    .fontWeight(.black)
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
                                    .kmiTypography(.secondary)
                                    .fontWeight(.bold)
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
                                                    KmiAppTheme.success(
                                                        for: colorScheme
                                                    )
                                            )
                                            
                                            SummaryStatusChip(
                                                title:
                                                    tr(
                                                        "תורגל: \(coachPracticedCount)",
                                                        "Practiced: \(coachPracticedCount)"
                                                    ),
                                                tint:
                                                    KmiAppTheme.warning(
                                                        for: colorScheme
                                                    )
                                            )
                                            
                                            SummaryStatusChip(
                                                title:
                                                    tr(
                                                        "חיזוק: \(coachNeedsReinforcementCount)",
                                                        "Reinforce: \(coachNeedsReinforcementCount)"
                                                    ),
                                                tint:
                                                    KmiAppTheme.error(
                                                        for: colorScheme
                                                    )
                                            )
                                            
                                            SummaryStatusChip(
                                                title:
                                                    tr(
                                                        "לא נלמד: \(coachNotTaughtCount)",
                                                        "Not taught: \(coachNotTaughtCount)"
                                                    ),
                                                tint:
                                                    KmiAppTheme.onSurfaceVariant(
                                                        for: colorScheme
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
                                                    KmiAppTheme.warning(
                                                        for: colorScheme
                                                    )
                                            )
                                            
                                            SummaryStatusChip(
                                                title:
                                                    tr(
                                                        "לא יודע: \(notDoneCount)",
                                                        "No: \(notDoneCount)"
                                                    ),
                                                tint:
                                                    KmiAppTheme.error(
                                                        for: colorScheme
                                                    )
                                            )
                                            
                                            SummaryStatusChip(
                                                title:
                                                    tr(
                                                        "לא סומן: \(remainingCount)",
                                                        "Open: \(remainingCount)"
                                                    ),
                                                tint:
                                                    KmiAppTheme.onSurfaceVariant(
                                                        for: colorScheme
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
                                    .kmiTypography(.sectionTitle)
                                    .fontWeight(.heavy)
                                    .foregroundStyle(
                                        summaryPrimaryTextColor
                                    )
                                    
                                    Text(
                                        tr(
                                            "עדיין אין תרגילים להצגה עבור החגורה הנוכחית",
                                            "There are no exercises to display for the current belt yet"
                                        )
                                    )
                                    .kmiTypography(.body)
                                    .fontWeight(.semibold)
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
                                            isEnglish,
                                        onSelectExercise: { item in
                                            selectedExercise =
                                            SummarySelectedExercise(
                                                id: item.id,
                                                topicTitle: block.title,
                                                title: item.title
                                            )
                                        },
                                        onEditNote: { item in
                                            openNoteEditor(
                                                item: item,
                                                topicTitle: block.title
                                            )
                                        }
                                    )
                                    
                                    if index < blocks.count - 1 {
                                        Color.clear
                                            .frame(height: 7)
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
                isPreparingSummaryPDF ||
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                nav.pop()
            } label: {
                Text(
                    tr(
                        "חזרה למסך הנושאים",
                        "Back to topics"
                    )
                )
                .kmiTypography(.action)
                .fontWeight(.black)
                .multilineTextAlignment(.center)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .foregroundStyle(
                    KmiAppTheme.onTertiaryContainer(
                        for: colorScheme
                    )
                )
                .background(
                    RoundedRectangle(
                        cornerRadius: 22,
                        style: .continuous
                    )
                    .fill(
                        KmiAppTheme.tertiaryContainer(
                            for: colorScheme
                        )
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 22,
                        style: .continuous
                    )
                    .strokeBorder(
                        KmiAppTheme.secondary(
                            for: colorScheme
                        ),
                        lineWidth: 1
                    )
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                KmiAppTheme.background(
                    for: colorScheme
                )
                .ignoresSafeArea(edges: .bottom)
            )
            .disabled(
                isSummaryLoading || isPreparingSummaryPDF
            )
        }
        .onAppear {
            isSummaryVisible = true
            
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
        .sheet(item: $selectedExercise) { exercise in
            ExerciseExplanationDialog(
                belt: belt,
                topic: exercise.topicTitle,
                item: exercise.title,
                branch: "",
                groupKey: "",
                isEnglish: isEnglish
            )
        }
        .sheet(
            item: $selectedNoteExercise,
            onDismiss: {
                noteDraft = ""
                noteUserID = ""
                noteExerciseID = ""
                noteBeltID = ""
                noteIdentity = nil
                noteSaveFailed = false
            }
        ) { exercise in
            ExerciseNoteSheet(
                title: exercise.title,
                noteText: $noteDraft,
                isEnglish: isEnglish,
                onSave: {
                    noteSaveFailed = false
                    
#if canImport(FirebaseAuth)
                    guard Auth.auth().currentUser?.uid == noteUserID,
                          belt.id == noteBeltID,
                          let identity = noteIdentity,
                          identity.primaryID == noteExerciseID else {
                        noteSaveFailed = true
                        return
                    }
                    
                    if case .conflict = exerciseNotes.loadCompatible(
                        userID: noteUserID,
                        beltID: noteBeltID,
                        identity: identity
                    ) {
                        noteSaveFailed = true
                        return
                    }
                    
                    exerciseNotes.save(
                        noteDraft,
                        userID: noteUserID,
                        beltID: noteBeltID,
                        exerciseID: identity.primaryID
                    )
#else
                    noteSaveFailed = true
#endif
                },
                shouldDismissAfterSave: {
                    !noteSaveFailed
                },
                accentColor: KmiBeltPalette.color(
                    for: belt
                )
            )
            .alert(
                isEnglish
                ? "Unable to save note"
                : "לא ניתן לשמור את ההערה",
                isPresented: $noteSaveFailed
            ) {
                Button(
                    isEnglish ? "OK" : "אישור",
                    role: .cancel
                ) {}
            } message: {
                Text(
                    isEnglish
                    ? "The account or belt may have changed, or different notes may exist. Your draft remains open and existing notes were not changed."
                    : "ייתכן שהחשבון או החגורה השתנו, או שקיימות הערות שונות לתרגיל. הטיוטה נשארת פתוחה וההערות הקיימות לא שונו."
                )
            }
        }
        .alert(
            isEnglish ? "Note unavailable" : "ההערה אינה זמינה",
            isPresented: $showNoteUnavailable
        ) {
            Button(isEnglish ? "OK" : "אישור", role: .cancel) {}
        } message: {
            Text(
                isEnglish
                ? "The account or belt may have changed, the exercise may be unavailable, or different notes may exist for it. Existing notes were not changed."
                : "ייתכן שהחשבון או החגורה השתנו, שהתרגיל אינו זמין או שקיימות עבורו הערות שונות. ההערות הקיימות לא שונו."
            )
        }
        .onChange(of: showComparisonCard) { _, isPresented in
            if !isPresented {
                invalidateComparisonRequest()
            }
        }
        .onDisappear {
            isSummaryVisible = false
            summaryPDFRequestID = UUID()
            isPreparingSummaryPDF = false
            invalidateComparisonRequest()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name(
                    "KMI_GLOBAL_SHARE_REQUEST"
                )
            )
        ) { notification in
            guard isSummaryVisible,
                  selectedExercise == nil,
                  selectedNoteExercise == nil,
                  let request =
                    notification.object as? NSMutableDictionary,
                  request["handled"] as? Bool != true
            else {
                return
            }
            
            request["handled"] = true
            
            guard !isSummaryLoading,
                  !isPreparingSummaryPDF,
                  !showSummaryShareSheet
            else {
                return
            }
            
            shareSummaryPDF()
        }
        .sheet(
            isPresented: $showSummaryShareSheet,
            onDismiss: {
                summaryShareItems.removeAll()
            }
        ) {
            KmiShareSheet(items: summaryShareItems)
        }
        .alert(
            tr("שיתוף הסיכום", "Share summary"),
            isPresented: $showSummaryPDFError
        ) {
            Button(tr("אישור", "OK"), role: .cancel) {}
        } message: {
            Text(
                tr(
                    "לא ניתן ליצור את קובץ הסיכום כרגע. נסה שוב.",
                    "The summary PDF could not be created. Please try again."
                )
            )
        }
        .onChange(of: percentAll) { _, _ in
            guard isSummaryVisible else {
                return
            }

            postSummaryTopTitleOverride()
        }
        .onChange(of: isEnglish) { _, _ in
            guard isSummaryVisible else {
                return
            }

            postSummaryTopTitleOverride()
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
                
                invalidateComparisonRequest()
                
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
             * בודקים את הסימונים העדכניים, אך מעדכנים
             * ושומרים רק כאשר תוכן הסיכום השתנה.
             */
            marksRevision &+= 1
            
            DispatchQueue.main.async {
                let updatedBlocks = buildSummaryBlocks()
                
                guard updatedBlocks != cachedBlocks else {
                    return
                }
                
                cachedBlocks = updatedBlocks
                
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
            KmiAppTheme.sectionHeaderBrush
        )
        .environment(
            \.layoutDirection,
            screenLayoutDirection
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
        KmiBeltPalette.color(for: belt)
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
        
        private var primaryTextColor: Color {
            KmiAppTheme.onSurface(for: colorScheme)
        }
        
        private var secondaryTextColor: Color {
            KmiAppTheme.onSurfaceVariant(for: colorScheme)
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
                        .kmiIconSize(15)
                        .fontWeight(.heavy)
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
                    .kmiTypography(.sectionTitle)
                    .fontWeight(.black)
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
                    .kmiTypography(.body)
                    .fontWeight(.semibold)
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
                    .kmiTypography(.body)
                    .fontWeight(.semibold)
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
                            .kmiTypography(.metric)
                            .fontWeight(.black)
                            .foregroundStyle(
                                primaryTextColor
                            )
                            
                            Text(
                                tr(
                                    "ידיעת החומר",
                                    "Average knowledge"
                                )
                            )
                            .kmiTypography(.caption)
                            .fontWeight(.bold)
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
                    .kmiTypography(.secondary)
                    .fontWeight(.bold)
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
                        .kmiTypography(.caption)
                        .fontWeight(.semibold)
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
                        .kmiTypography(.caption)
                        .fontWeight(.semibold)
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
                    KmiAppTheme.surface(
                        for: colorScheme
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
                .kmiTypography(.metric)
                .fontWeight(.black)
                .foregroundStyle(
                    colorScheme == .dark
                    ? KmiAppTheme.onSurface(
                        for: colorScheme
                    )
                    : tint
                )
                
                Text(
                    title
                )
                .kmiTypography(.caption)
                .fontWeight(.bold)
                .foregroundStyle(
                    KmiAppTheme.onSurfaceVariant(
                        for: colorScheme
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
            .padding(.vertical, 8)
            .frame(minHeight: 72)
            .background {
                
                RoundedRectangle(
                    cornerRadius:
                        16,
                    style:
                            .continuous
                )
                .fill(
                    KmiAppTheme.surfaceVariant(
                        for: colorScheme
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
            KmiAppTheme.onSurface(for: colorScheme)
        }
        
        private var secondaryTextColor: Color {
            KmiAppTheme.onSurfaceVariant(for: colorScheme)
        }
        
        private var messageSurfaceColor: Color {
            KmiAppTheme.surfaceVariant(for: colorScheme)
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
                            .kmiIconSize(17)
                            .fontWeight(.heavy)
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
                    .kmiTypography(.sectionTitle)
                    .fontWeight(.black)
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
                        .kmiTypography(.sectionTitle)
                        .fontWeight(.black)
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
                        .kmiTypography(.body)
                        .fontWeight(.semibold)
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
                                KmiAppTheme.outlineVariant(
                                    for: colorScheme
                                ),
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
            KmiAppTheme.onSurfaceVariant(for: colorScheme)
        }
        
        var body: some View {
            VStack(spacing: 5) {
                Text(value)
                    .kmiTypography(.metric)
                    .fontWeight(.black)
                    .foregroundStyle(tint)
                
                Text(title)
                    .kmiTypography(.secondary)
                    .fontWeight(.black)
                    .foregroundStyle(titleColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 76)
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
            KmiAppTheme.surface(for: colorScheme)
        }
        
        private var ringPrimaryTextColor: Color {
            KmiAppTheme.onSurface(for: colorScheme)
        }
        
        private var ringSecondaryTextColor: Color {
            KmiAppTheme.onSurfaceVariant(for: colorScheme)
        }
        
        private func normalizedPart(_ count: Int) -> CGFloat {
            guard totalCount > 0 else {
                return 0
            }
            
            return min(
                max(CGFloat(count) / CGFloat(totalCount), 0),
                1
            )
        }
        
        private var donePart: CGFloat {
            normalizedPart(doneCount)
        }
        
        private var partiallyKnownPart: CGFloat {
            min(
                normalizedPart(partiallyKnownCount),
                1 - donePart
            )
        }
        
        private var notDonePart: CGFloat {
            min(
                normalizedPart(notDoneCount),
                max(1 - donePart - partiallyKnownPart, 0)
            )
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
                    .stroke(
                        KmiAppTheme.outlineVariant(
                            for: colorScheme
                        ).opacity(0.78),
                        style: StrokeStyle(
                            lineWidth: 16,
                            lineCap: .round
                        )
                    )
                
                Circle()
                    .trim(
                        from:
                            0,
                        to:
                            donePart
                    )
                    .stroke(
                        KmiAppTheme.success(
                            for: colorScheme
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
                        KmiAppTheme.warning(
                            for: colorScheme
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
                        KmiAppTheme.error(
                            for: colorScheme
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
                        .kmiTypography(.metric)
                        .fontWeight(.black)
                        .foregroundStyle(ringPrimaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.80)
                    
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
                    .kmiTypography(.secondary)
                    .fontWeight(.black)
                    .foregroundStyle(
                        KmiAppTheme.success(for: colorScheme)
                    )
                    
                    Text(
                        isEnglish
                        ? "\(doneCount + partiallyKnownCount + notDoneCount) of \(totalCount)"
                        : "\(doneCount + partiallyKnownCount + notDoneCount) מתוך \(totalCount)"
                    )
                    .kmiTypography(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(ringSecondaryTextColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
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
            .kmiTypography(.caption)
            .fontWeight(.black)
            .foregroundStyle(
                tint
            )
            .multilineTextAlignment(
                .center
            )
            .lineLimit(2)
            .fixedSize(
                horizontal: false,
                vertical: true
            )
            .frame(
                maxWidth:
                        .infinity
            )
            .padding(.vertical, 6)
            .frame(minHeight: 44)
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
    
    private func openNoteEditor(
        item: SummaryRowItem,
        topicTitle: String
    ) {
#if canImport(FirebaseAuth)
        guard let userID = Auth.auth().currentUser?.uid,
              !userID.trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty,
              let resolved = ExerciseIdentityResolverIOS.resolve(
                belt: belt,
                topic: topicTitle,
                rawItem: item.title
              ) else {
            showNoteUnavailable = true
            return
        }
        
        var previousIDs = resolved.previousIDs
        
        if let previousID = exerciseNotes.knownExerciseID(
            belt: belt,
            title: item.title,
            topicKey: topicTitle
        ),
           previousID != resolved.primaryID {
            previousIDs.insert(previousID)
        }
        
        let identity = ExerciseIdentityResolverIOS.Identity(
            primaryID: resolved.primaryID,
            displayTitle: resolved.displayTitle,
            previousIDs: previousIDs
        )
        
        let loadedNote: String
        
        switch exerciseNotes.loadCompatible(
            userID: userID,
            beltID: belt.id,
            identity: identity
        ) {
        case .found(let value):
            loadedNote = value
            
        case .missing:
            loadedNote = ""
            
        case .conflict:
            showNoteUnavailable = true
            return
        }
        
        noteUserID = userID
        noteBeltID = belt.id
        noteExerciseID = identity.primaryID
        noteIdentity = identity
        noteDraft = loadedNote
        
        selectedNoteExercise = SummarySelectedExercise(
            id: item.id,
            topicTitle: topicTitle,
            title: item.title
        )
#else
        showNoteUnavailable = true
#endif
    }
    
    private struct TopicSummaryCard: View {
        let block: SummaryTopicBlock
        
        let beltAccent:
        Color
        
        let isCoach: Bool
        let isEnglish: Bool
        let onSelectExercise: (SummaryRowItem) -> Void
        let onEditNote: (SummaryRowItem) -> Void
        
        @Environment(\.colorScheme)
        private var colorScheme
        
        private var isDarkMode: Bool {
            colorScheme == .dark
        }
        
        private var primaryTextColor: Color {
            KmiAppTheme.onSurface(for: colorScheme)
        }
        
        private var cardColors: [Color] {
            let surface = KmiAppTheme.surface(
                for: colorScheme
            )

            return [
                surface,
                surface
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
                        
                        HStack(spacing: 10) {
                            Text(
                                "\(block.percent(isCoach: isCoach))%"
                            )
                            .kmiTypography(.sectionTitle)
                            .fontWeight(.black)
                            .foregroundStyle(beltAccent)
                            .monospacedDigit()
                            .fixedSize()
                            .accessibilityLabel(
                                isEnglish
                                ? "Progress: \(block.percent(isCoach: isCoach)) percent"
                                : "התקדמות: \(block.percent(isCoach: isCoach)) אחוזים"
                            )
                            
                            VStack(
                                alignment: isEnglish ? .leading : .trailing,
                                spacing: 3
                            ) {
                                Text(
                                    KmiEnglishTitleResolver.title(
                                        for: block.title,
                                        isEnglish: isEnglish
                                    )
                                )
                                .kmiTypography(.sectionTitle)
                                .fontWeight(.black)
                                .foregroundStyle(primaryTextColor)
                                .lineLimit(2)
                                .fixedSize(
                                    horizontal: false,
                                    vertical: true
                                )
                                
                                Text(
                                    isEnglish
                                    ? "\(block.totalCount) exercises"
                                    : "\(block.totalCount) תרגילים"
                                )
                                .kmiTypography(.secondary)
                                .fontWeight(.bold)
                                .foregroundStyle(
                                    KmiAppTheme.onSurfaceVariant(
                                        for: colorScheme
                                    )
                                )
                            }
                            .frame(
                                maxWidth: .infinity,
                                alignment: frameAlignment
                            )
                            .multilineTextAlignment(textAlignment)
                        }
                        .environment(
                            \.layoutDirection,
                             isEnglish ? .rightToLeft : .leftToRight
                        )
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
                                    
                                    let translatedSubtopic =
                                        KmiEnglishTitleResolver.title(
                                            for: subTopicTitle,
                                            isEnglish: isEnglish
                                        )

                                    let subTopicDisplayTitle =
                                        "\(translatedSubtopic) — \(subTopicPercent)%"
                                    
                                    Text(
                                        subTopicDisplayTitle
                                    )
                                    .kmiTypography(.subTopicTitle)
                                    .fontWeight(.heavy)
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
                                        coachUpdatedAt:
                                            item.coachUpdatedAt,
                                        isCoach:
                                            isCoach,
                                        isEnglish:
                                            isEnglish,
                                        onSelect: {
                                            onSelectExercise(item)
                                        },
                                        onEditNote: {
                                            onEditNote(item)
                                        }
                                    )
                                    
                                    if index < group.items.count - 1 {
                                        Color.clear
                                            .frame(height: 6)
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
                    KmiAppTheme.surface(
                        for: colorScheme
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                    .fill(
                        beltAccent.opacity(
                            isDarkMode ? 0.14 : 0.12
                        )
                    )
                }
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius:
                        18,
                    style:
                            .continuous
                )
                .stroke(
                    KmiAppTheme.outlineVariant(
                        for: colorScheme
                    ),
                    lineWidth: 1
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
                .kmiIconSize(15)
                .fontWeight(.black)
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
        
        let coachUpdatedAt:
        [SummaryCoachStatus: Double]
        
        let isCoach: Bool
        let isEnglish: Bool
        let onSelect: () -> Void
        let onEditNote: () -> Void
        
        @ObservedObject private var exerciseFavorites =
        ExerciseFavoritesStore.shared
        
        @Environment(\.colorScheme)
        private var colorScheme
        
        private var rowTextColor: Color {
            KmiAppTheme.onSurface(for: colorScheme)
        }
        
        private var frameAlignment: Alignment {
            isEnglish
            ? .leading
            : .trailing
        }
        
        private func coachStatusColor(
            _ status: SummaryCoachStatus
        ) -> Color {
            switch status {
            case .notTaught:
                return KmiAppTheme.onSurfaceVariant(
                    for: colorScheme
                )
            case .taught:
                return KmiAppTheme.warning(
                    for: colorScheme
                )
            case .practiced:
                return KmiAppTheme.success(
                    for: colorScheme
                )
            case .needsReinforcement:
                return KmiAppTheme.secondary(
                    for: colorScheme
                )
            }
        }
        
        private func coachStatusContentColor(
            _ status: SummaryCoachStatus
        ) -> Color {
            switch status {
            case .notTaught:
                return KmiAppTheme.surface(for: colorScheme)
            case .taught:
                return KmiAppTheme.onWarning(for: colorScheme)
            case .practiced:
                return KmiAppTheme.onSuccess(for: colorScheme)
            case .needsReinforcement:
                return KmiAppTheme.onSecondary(for: colorScheme)
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
                return KmiAppTheme.success(
                    for: colorScheme
                )
                
            case .partiallyKnown:
                return KmiAppTheme.warning(
                    for: colorScheme
                )
                
            case .notDone:
                return KmiAppTheme.error(
                    for: colorScheme
                )
                
            case nil:
                return KmiAppTheme.onSurfaceVariant(
                    for: colorScheme
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
            VStack(
                alignment: .leading,
                spacing: 10
            ) {
                Button(action: onSelect) {
                    Text(
                        KmiEnglishTitleResolver.title(
                            for: ExerciseTitleFormatter.shared
                                .displayName(raw: title),
                            isEnglish: isEnglish
                        )
                    )
                    .kmiTypography(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(rowTextColor)
                    .multilineTextAlignment(.leading)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .environment(
                    \.layoutDirection,
                     isEnglish ? .leftToRight : .rightToLeft
                )
                
                HStack(
                    alignment: .bottom,
                    spacing: 6
                ) {
                    if isCoach {
                        if orderedCoachStatuses.isEmpty {
                            coachStatusBadge(.notTaught)
                        } else {
                            ForEach(
                                orderedCoachStatuses,
                                id: \.rawValue
                            ) { status in
                                coachStatusBadge(status)
                            }
                        }
                    } else {
                        Text(traineeStatusTitle)
                            .kmiTypography(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(
                                traineeStatusColor
                            )
                            .multilineTextAlignment(.center)
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: 8,
                                    style: .continuous
                                )
                                .fill(
                                    traineeStatusColor.opacity(0.09)
                                )
                            )
                            .overlay(
                                RoundedRectangle(
                                    cornerRadius: 8,
                                    style: .continuous
                                )
                                .strokeBorder(
                                    traineeStatusColor.opacity(0.32),
                                    lineWidth: 1
                                )
                            )
                    }
                    
                    Spacer(minLength: 0)
                    
                    if exerciseFavorites.contains(title) {
                        Image(systemName: "star.fill")
                            .kmiIconSize(14)
                            .foregroundStyle(
                                KmiAppTheme.warning(
                                    for: colorScheme
                                )
                            )
                            .accessibilityLabel(
                                isEnglish
                                ? "Favorite"
                                : "מועדף"
                            )
                    }
                }
                .environment(
                    \.layoutDirection,
                     .leftToRight
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(
                maxWidth: .infinity,
                minHeight: 82,
                alignment: .topLeading
            )
            .background(
                RoundedRectangle(
                    cornerRadius: 18,
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
                    cornerRadius: 18,
                    style: .continuous
                )
                .strokeBorder(
                    KmiAppTheme.outlineVariant(
                        for: colorScheme
                    ),
                    lineWidth: 1
                )
            )
            .contextMenu {
                Button(action: onEditNote) {
                    Label(
                        isEnglish ? "Edit note" : "עריכת הערה",
                        systemImage: "note.text"
                    )
                }
                
                Button {
                    exerciseFavorites.toggle(title)
                } label: {
                    Label(
                        exerciseFavorites.contains(title)
                        ? (isEnglish
                           ? "Remove from favorites"
                           : "הסר ממועדפים")
                        : (isEnglish
                           ? "Add to favorites"
                           : "הוסף למועדפים"),
                        systemImage: exerciseFavorites.contains(title)
                        ? "star.slash"
                        : "star"
                    )
                }
            }
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
            _ status: SummaryCoachStatus
        ) -> some View {
            let color = coachStatusColor(status)
            
            let dateText: String? = {
                guard status != .notTaught,
                      let timestamp = coachUpdatedAt[status],
                      timestamp.isFinite,
                      timestamp > 0
                else {
                    return nil
                }
                
                let formatter = DateFormatter()
                formatter.calendar = Calendar(
                    identifier: .gregorian
                )
                formatter.locale = Locale(
                    identifier: isEnglish ? "en_GB" : "he_IL"
                )
                formatter.dateFormat = "dd/MM/yy"
                
                return formatter.string(
                    from: Date(
                        timeIntervalSince1970: timestamp
                    )
                )
            }()
            
            return VStack(spacing: 2) {
                Text(coachStatusTitle(status))
                    .kmiTypography(.caption)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                
                if let dateText {
                    Text(dateText)
                        .kmiTypography(.caption)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .fixedSize()
                        .environment(
                            \.layoutDirection,
                             .leftToRight
                        )
                }
            }
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
                .fill(color.opacity(0.09))
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
                .strokeBorder(
                    color.opacity(0.32),
                    lineWidth: 1
                )
            )
        }
    }
}
