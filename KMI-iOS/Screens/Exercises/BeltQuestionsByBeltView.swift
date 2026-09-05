import SwiftUI
import UIKit
import Combine
import Shared

// ✅ CONTENT-ONLY: אין כאן TopBar ואין כאן IconStrip ואין כאן DrawerContainer
struct BeltQuestionsByBeltView: View {
    
    let belt: Belt
    
    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"
    @AppStorage("selected_language_code") private var selectedLanguageCode: String = "he"
    
    private var effectiveLanguageCode: String {
        let orderedValues = [
            kmiAppLanguageCode,
            selectedLanguageCode,
            appLanguageRaw,
            initialLanguageCode
        ]
        
        for raw in orderedValues {
            let clean = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            
            if clean == "he" || clean == "hebrew" || clean == "עברית" {
                return "he"
            }
            
            if clean == "en" || clean == "english" {
                return "en"
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

    private var byBeltCardSurfaceColor: Color {
        KmiAppTheme.surface(
            for: colorScheme
        )
    }

    private var byBeltCardBorderColor: Color {
        KmiAppTheme.outlineVariant(
            for: colorScheme
        )
    }

    private var byBeltTitleColor: Color {
        KmiAppTheme.onSurface(
            for: colorScheme
        )
    }

    private var byBeltSecondaryTextColor: Color {
        KmiAppTheme.onSurfaceVariant(
            for: colorScheme
        )
    }

    private var readableBeltAccent: Color {

        switch selectedBelt {

        case .black
            where colorScheme == .dark:

            return KmiAppTheme.onSurface(
                for: colorScheme
            )

        case .white
            where colorScheme == .dark:

            return KmiAppTheme.onSurface(
                for: colorScheme
            )

        case .white:

            return KmiAppTheme.onSurfaceVariant(
                for: colorScheme
            )

        case .yellow
            where colorScheme == .light:

            return Color(
                red: 201.0 / 255.0,
                green: 138.0 / 255.0,
                blue: 0.0 / 255.0
            )

        default:

            return BeltPaletteByBeltScreen
                .color(
                    for: selectedBelt
                )
        }
    }

    private var byBeltRowSubColor: Color {
        readableBeltAccent
            .opacity(0.88)
    }

    private var byBeltSubTopicsBackground: Color {
        readableBeltAccent.opacity(
            colorScheme == .dark
                ? 0.12
                : 0.10
        )
    }

    private var byBeltSubTopicsBorder: Color {
        readableBeltAccent.opacity(
            colorScheme == .dark
                ? 0.34
                : 0.38
        )
    }

    private var byBeltSubTopicDivider: Color {
        readableBeltAccent.opacity(
            colorScheme == .dark
                ? 0.28
                : 0.36
        )
    }
    
    private func uiTopicTitle(_ title: String) -> String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return KmiEnglishTitleResolver.title(for: clean, isEnglish: isEnglish)
    }
    
    private func exercisesCountText(_ count: Int) -> String {
        if isEnglish {
            return count == 1 ? "1 exercise" : "\(count) exercises"
        } else {
            return count == 1 ? "תרגיל 1" : "\(count) תרגילים"
        }
    }
    
    private func subTopicsAndExercisesText(subTopicsCount: Int, exercisesCount: Int) -> String {
        if isEnglish {
            let subText = subTopicsCount == 1 ? "1 sub-topic" : "\(subTopicsCount) sub-topics"
            return "\(subText) · \(exercisesCountText(exercisesCount))"
        } else {
            return "\(subTopicsCount) תתי נושאים · \(exercisesCountText(exercisesCount))"
        }
    }
    
    private func beltDisplayTitle(_ belt: Belt) -> String {
        if !isEnglish {
            return belt.heb
        }
        
        switch belt {
        case .white:
            return "White"
        case .yellow:
            return "Yellow"
        case .orange:
            return "Orange"
        case .green:
            return "Green"
        case .blue:
            return "Blue"
        case .brown:
            return "Brown"
        case .black:
            return "Black"
        default:
            return belt.heb
        }
    }
    
    @State private var selectedExerciseRoute: BeltTopicExerciseRoute? = nil
    @State private var selectedLinkedTopicRoute: LinkedTopicRoute? = nil
    @State private var selectedTopicSubTopicsRoute: BeltTopicSubTopicsRoute? = nil
    
    // ✅ subject-based flow כמו באנדרואיד:
    @State private var selectedSubjectForSubTopics: SubjectTopic? = nil
    @State private var selectedSubjectSectionRoute: SubjectSectionExerciseRoute? = nil
    
    // ✅ NEW: nav גלובאלי (כדי לנווט למסכים עטופים ב-KmiRootLayout)
    @EnvironmentObject private var nav: AppNavModel

    @Environment(\.colorScheme)
    private var colorScheme

    // החגורות שמוצגות בקרוסלה.
    // חגורה לבנה אינה מוצגת כאן — כמו באנדרואיד.
    private let belts: [Belt] = [
        .yellow,
        .orange,
        .green,
        .blue,
        .brown,
        .black
    ]

    // החגורה הפעילה במסך.
    @State private var selectedBelt: Belt = .orange

    // מונע אתחול חוזר של החגורה בכל onAppear.
    @State private var didInitializeSelectedBelt: Bool = false

    // מצב התפריט הצידי.
    @State private var quickMenuOpen: Bool = false
    @State private var showPracticeMenu: Bool = false
    @State private var expandedTopic: String? = nil

    @State private var accessRefreshTick: Int = 0

    /*
     * Performance:
     *
     * הנתונים של כל חגורה נבנים פעם אחת
     * ונשמרים לפי:
     *
     * belt + language
     *
     * שינוי UI כמו פתיחת נושא או Quick Menu
     * לא גורם יותר לסריקה מחדש של ContentRepo.
     */
    @State private var beltTopicsCache:
        [String: [BeltTopicUi]] = [:]
    @State private var generalNoteTitle: String = ""
    @State private var generalNoteText: String = ""
    @State private var showGeneralNote: Bool = false
    
    // Global search
    @State private var pickedExercise: ExerciseSelection? = nil

    // PDF sharing
    @State private var showPDFShareSheet: Bool = false
    @State private var pdfShareItems: [Any] = []
    @State private var pdfErrorMessage: String? = nil
    
    /*
     * מצב הגישה מתרענן באמצעות
     * KMI_ACCESS_CHANGED ו־UserDefaults.
     *
     * אין צורך בטיימר קבוע בזמן שהמסך פתוח.
     */
    private struct BeltTopicExerciseRoute:
        Identifiable,
        Hashable {
        let id: String
        let belt: Belt
        let topicTitle: String
        let forcedSubTopicTitle: String?
        
        init(belt: Belt, topicTitle: String, forcedSubTopicTitle: String? = nil) {
            self.belt = belt
            self.topicTitle = topicTitle
            self.forcedSubTopicTitle = forcedSubTopicTitle
            self.id = "\(belt.id)::\(topicTitle)::\(forcedSubTopicTitle ?? "__ALL__")"
        }
    }
    
    struct SubjectSectionExerciseRoute: Identifiable, Hashable {
        let id: String
        let belt: Belt
        let subject: SubjectTopic
        let sectionTitle: String
        
        init(belt: Belt, subject: SubjectTopic, sectionTitle: String) {
            self.belt = belt
            self.subject = subject
            self.sectionTitle = sectionTitle
            self.id = "\(belt.id)::\(subject.id)::\(sectionTitle)"
        }
    }
    
    private struct LinkedTopicRoute: Identifiable, Hashable {
        let id: String
        let title: String
        let subjects: [SubjectTopic]
        
        init(title: String, subjects: [SubjectTopic]) {
            self.title = title
            self.subjects = subjects
            self.id = "linked-topic::\(title)"
        }
    }
    
    private struct BeltTopicSubTopicsRoute: Identifiable, Hashable {
        let id: String
        let belt: Belt
        let topicTitle: String
        let linkedSubjects: [SubjectTopic]
        
        init(belt: Belt, topicTitle: String, linkedSubjects: [SubjectTopic]) {
            self.belt = belt
            self.topicTitle = topicTitle
            self.linkedSubjects = linkedSubjects
            self.id = "topic-subtopics::\(belt.id)::\(topicTitle)"
        }
    }
    
    private struct BeltTopicUi: Identifiable {

        let id: String

        let title: String

        let subtitle: String?

        let linkedSubjects: [SubjectTopic]

        /*
         * נשמרים כבר בזמן בניית ה-cache.
         *
         * כך ה-ForEach אינו קורא שוב
         * ל-ContentRepo בכל render.
         */
        let subTitles: [String]
    }
    
    private struct TopicDetailsUi {
        let itemCount: Int
        let subTitles: [String]
    }

    private func deepExerciseCount(
        belt: Belt,
        topicTitle: String
    ) -> Int {

        let cleanTopicTitle =
            topicTitle
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        var pendingSubTopics =
            ContentRepo.shared
                .getSubTopicsFor(
                    belt:
                        belt,
                    topicTitle:
                        cleanTopicTitle
                )

        var cursor = 0
        var totalCount = 0

        while cursor <
            pendingSubTopics.count {

            let current =
                pendingSubTopics[
                    cursor
                ]

            totalCount +=
                current.items.count

            pendingSubTopics.append(
                contentsOf:
                    current.subTopics
            )

            cursor += 1
        }

        return totalCount
    }

    private func topicDetailsFor(
        belt: Belt,
        topicTitle: String
    ) -> TopicDetailsUi {

        let cleanTopicTitle =
            topicTitle
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        /*
         * קריאה אחת בלבד ל-ContentRepo.
         */
        let topLevelSubTopics =
            ContentRepo.shared
                .getSubTopicsFor(
                    belt: belt,
                    topicTitle:
                        cleanTopicTitle
                )

        let cleanSubTitles =
            topLevelSubTopics
                .map {
                    $0.title
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                }
                .filter {
                    !$0.isEmpty &&
                    $0 != cleanTopicTitle
                }
                .reduce(
                    into: [String]()
                ) { result, title in

                    if !result.contains(
                        title
                    ) {
                        result.append(
                            title
                        )
                    }
                }

        /*
         * סריקת BFS ללא removeFirst().
         *
         * removeFirst() מזיז את כל המערך
         * בכל איטרציה.
         */
        var pendingSubTopics =
            topLevelSubTopics

        var cursor = 0

        var totalCount = 0

        while cursor <
            pendingSubTopics.count {

            let current =
                pendingSubTopics[
                    cursor
                ]

            totalCount +=
                current.items.count

            pendingSubTopics.append(
                contentsOf:
                    current.subTopics
            )

            cursor += 1
        }

        return TopicDetailsUi(
            itemCount:
                totalCount,
            subTitles:
                cleanSubTitles
        )
    }

    // Android parity:
    // סופרים בפועל את items בכל עץ תתי־הנושאים.
    private func topicExercisesCountForUi(
        belt: Belt,
        topicTitle: String,
        subTitles _: [String]
    ) -> Int {
        deepExerciseCount(
            belt: belt,
            topicTitle: topicTitle
        )
    }
    
    private func hasRealSubTopicsForUi(title: String, details: TopicDetailsUi) -> Bool {
        let topicTrim = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return details.subTitles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { $0 != topicTrim }
            .reduce(into: [String]()) { partial, item in
                if !partial.contains(item) {
                    partial.append(item)
                }
            }
            .isEmpty == false
    }
    
    private func topicPriorityRankForUi(
        belt: Belt,
        title: String,
        details: TopicDetailsUi
    ) -> Int {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasRealSubs = hasRealSubTopicsForUi(title: title, details: details)
        
        if clean.contains("הגנות") {
            return 0
        }
        
        if clean.contains("שחרורים") {
            return 1
        }
        
        if belt == .yellow && clean.contains("עבודת ידיים") {
            return 2
        }
        
        if hasRealSubs {
            return 3
        }
        
        return 10
    }
    
    private func beltTopicsCacheKey(
        for targetBelt: Belt
    ) -> String {

        /*
         * ה-subtitle תלוי בשפה,
         * לכן עברית ואנגלית מקבלות cache נפרד.
         */
        "\(targetBelt.id)::\(effectiveLanguageCode)"
    }

    private func buildBeltTopicsUi(
        for targetBelt: Belt
    ) -> [BeltTopicUi] {

        let rawTopicTitles =
            TopicsEngine.shared
                .topicTitlesFor(
                    belt:
                        targetBelt
                )
                .map {
                    $0.trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                }
                .filter {
                    !$0.isEmpty
                }
                .reduce(
                    into: [String]()
                ) { result, title in

                    if !result.contains(
                        title
                    ) {
                        result.append(
                            title
                        )
                    }
                }

        /*
         * topicDetailsFor נקרא בדיוק
         * פעם אחת לכל נושא בזמן בניית ה-cache.
         */
        let detailsByTitle:
            [String: TopicDetailsUi] =
                Dictionary(
                    uniqueKeysWithValues:
                        rawTopicTitles.map {
                            title in

                            (
                                title,
                                topicDetailsFor(
                                    belt:
                                        targetBelt,
                                    topicTitle:
                                        title
                                )
                            )
                        }
                )

        let orderedTopicTitles =
            rawTopicTitles
                .enumerated()
                .sorted {
                    lhs,
                    rhs in

                    let lhsDetails =
                        detailsByTitle[
                            lhs.element
                        ]
                        ?? TopicDetailsUi(
                            itemCount: 0,
                            subTitles: []
                        )

                    let rhsDetails =
                        detailsByTitle[
                            rhs.element
                        ]
                        ?? TopicDetailsUi(
                            itemCount: 0,
                            subTitles: []
                        )

                    let lhsRank =
                        topicPriorityRankForUi(
                            belt:
                                targetBelt,
                            title:
                                lhs.element,
                            details:
                                lhsDetails
                        )

                    let rhsRank =
                        topicPriorityRankForUi(
                            belt:
                                targetBelt,
                            title:
                                rhs.element,
                            details:
                                rhsDetails
                        )

                    if lhsRank != rhsRank {
                        return lhsRank <
                            rhsRank
                    }

                    return lhs.offset <
                        rhs.offset
                }
                .map {
                    $0.element
                }

        return orderedTopicTitles.map {
            title in

            let details =
                detailsByTitle[
                    title
                ]
                ?? TopicDetailsUi(
                    itemCount: 0,
                    subTitles: []
                )

            let subCount =
                details.subTitles.count

            let itemCount =
                details.itemCount

            let subtitle: String?

            if subCount > 0 {

                subtitle =
                    subTopicsAndExercisesText(
                        subTopicsCount:
                            subCount,
                        exercisesCount:
                            itemCount
                    )

            } else {

                subtitle =
                    exercisesCountText(
                        itemCount
                    )
            }

            return BeltTopicUi(
                id:
                    "belt-topic::\(targetBelt.id)::\(title)",
                title:
                    title,
                subtitle:
                    subtitle,
                linkedSubjects:
                    [],
                subTitles:
                    details.subTitles
            )
        }
    }

    private func ensureBeltTopicsCache(
        for targetBelt: Belt,
        force: Bool = false
    ) {

        let key =
            beltTopicsCacheKey(
                for:
                    targetBelt
            )

        if
            !force,
            beltTopicsCache[key] != nil {

            /*
             * כבר נטען.
             * לא נוגעים ב-ContentRepo.
             */
            return
        }

        let rows =
            buildBeltTopicsUi(
                for:
                    targetBelt
            )

        beltTopicsCache[
            key
        ] = rows
    }

    private var beltTopicsUi:
        [BeltTopicUi] {

        let key =
            beltTopicsCacheKey(
                for:
                    selectedBelt
            )

        return beltTopicsCache[
            key
        ] ?? []
    }
    
    @State private var practiceTokenFromLists: String = "__ALL__"

    private var quickMenuBelt: Belt {
        selectedBelt
    }

    private var screenTitleForMode: String {
        beltDisplayTitle(selectedBelt)
    }

    private func closeQuickMenuForNavigation() {
        withAnimation(
            .spring(
                response: 0.24,
                dampingFraction: 0.90
            )
        ) {
            quickMenuOpen = false
        }
    }

    private func runLockedQuickMenuAction(
        title: String,
        action: () -> Void
    ) {
        closeQuickMenuForNavigation()

        let accessMode =
            LockedContentPolicy.currentAccessMode()

        if LockedContentPolicy.shouldShowLock(
            accessMode: accessMode,
            title: title
        ) {
            nav.push(.subscriptionPlans)
            return
        }

        action()
    }

    private var beltScreenQuickMenuItems:
        [BeltScreenQuickMenuItem] {

        let weakPointsTitle =
            isEnglish
                ? "Weak Points"
                : "נקודות תורפה"

        let allListsTitle =
            isEnglish
                ? "All Lists"
                : "כל הרשימות"

        let practiceTitle =
            isEnglish
                ? "Practice"
                : "תרגול"

        let summaryTitle =
            isEnglish
                ? "Summary"
                : "מסך סיכום"

        let voiceTitle =
            isEnglish
                ? "Voice Assistant"
                : "עוזר קולי"

        let pdfTitle =
            isEnglish
                ? "PDF Materials"
                : "חומרי PDF"

        return [

            BeltScreenQuickMenuItem(
                title:
                    weakPointsTitle,
                systemImage:
                    "exclamationmark.triangle.fill"
            ) {

                runLockedQuickMenuAction(
                    title:
                        weakPointsTitle
                ) {

                    nav.push(
                        .weakPoints(
                            belt:
                                selectedBelt
                        )
                    )
                }
            },

            BeltScreenQuickMenuItem(
                title:
                    allListsTitle,
                systemImage:
                    "list.bullet.rectangle.fill"
            ) {

                runLockedQuickMenuAction(
                    title:
                        allListsTitle
                ) {

                    nav.push(
                        .allLists(
                            belt:
                                selectedBelt
                        )
                    )
                }
            },

            BeltScreenQuickMenuItem(
                title:
                    practiceTitle,
                systemImage:
                    "figure.martial.arts"
            ) {

                runLockedQuickMenuAction(
                    title:
                        practiceTitle
                ) {

                    showPracticeMenu =
                        true
                }
            },

            BeltScreenQuickMenuItem(
                title:
                    summaryTitle,
                systemImage:
                    "chart.bar.doc.horizontal"
            ) {

                runLockedQuickMenuAction(
                    title:
                        summaryTitle
                ) {

                    nav.push(
                        .summary(
                            belt:
                                selectedBelt,
                            topic:
                                nil,
                            subTopic:
                                nil
                        )
                    )
                }
            },

            BeltScreenQuickMenuItem(
                title:
                    voiceTitle,
                systemImage:
                    "mic.fill"
            ) {

                runLockedQuickMenuAction(
                    title:
                        voiceTitle
                ) {

                    nav.push(
                        .voiceAssistant
                    )
                }
            },

            BeltScreenQuickMenuItem(
                title:
                    pdfTitle,
                systemImage:
                    "doc.richtext.fill"
            ) {

                runLockedQuickMenuAction(
                    title:
                        pdfTitle
                ) {

                    createAndSharePDF()
                }
            }
        ]
    }
    
    private func beltFromStoredId(
        _ raw: String?
    ) -> Belt? {

        let clean =
            (raw ?? "")
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()

        guard !clean.isEmpty else {
            return nil
        }

        /*
         * Android Belt.fromAny(...)
         *
         * כל דרגות השחורה / דאן
         * ממופות לחגורה שחורה אחת
         * בקרוסלה.
         */
        if
            clean == "black" ||
            clean == "שחור" ||
            clean == "שחורה" ||
            clean == "חגורה שחורה" ||
            clean.hasPrefix("black_dan_") ||
            clean.hasPrefix("black dan ") ||
            clean.hasPrefix("black belt dan ") ||
            clean.contains("שחורה דאן") ||
            clean.contains("שחור דאן") {

            return .black
        }

        switch clean {

        case
            "white",
            "לבן",
            "לבנה",
            "חגורה לבנה":

            return .white

        case
            "yellow",
            "צהוב",
            "צהובה",
            "חגורה צהובה":

            return .yellow

        case
            "orange",
            "כתום",
            "כתומה",
            "חגורה כתומה":

            return .orange

        case
            "green",
            "ירוק",
            "ירוקה",
            "חגורה ירוקה":

            return .green

        case
            "blue",
            "כחול",
            "כחולה",
            "חגורה כחולה":

            return .blue

        case
            "brown",
            "חום",
            "חומה",
            "חגורה חומה":

            return .brown

        default:
            return nil
        }
    }

    private func nextBelt(
        after registeredBelt: Belt
    ) -> Belt {

        /*
         * Android:
         * שחורה היא התחנה האחרונה.
         *
         * חומה -> שחורה
         * שחורה / דאן -> שחורה
         */
        if registeredBelt == .black {
            return .black
        }

        /*
         * לבנה אינה מוצגת בקרוסלה.
         * הבאה אחריה היא צהובה.
         */
        if registeredBelt == .white {
            return .yellow
        }

        guard
            let registeredIndex =
                belts.firstIndex(
                    of:
                        registeredBelt
                )
        else {
            return .orange
        }

        guard
            registeredIndex >= 0,
            registeredIndex <
                belts.count - 1
        else {
            return registeredBelt
        }

        return belts[
            registeredIndex + 1
        ]
    }

    private func initialBeltLikeAndroid(
        defaults: UserDefaults = .standard
    ) -> Belt {

        /*
         * Android source of truth:
         *
         * אין חגורה רשומה -> כתומה
         *
         * לבנה   -> צהובה
         * צהובה  -> כתומה
         * כתומה  -> ירוקה
         * ירוקה  -> כחולה
         * כחולה  -> חומה
         * חומה   -> שחורה
         *
         * שחורה / דאן 1...10
         * -> שחורה
         *
         * חשוב:
         * לא משתמשים ב-selectedBelt ישן
         * ולא ב-belt שהועבר למסך
         * לקביעת נקודת הפתיחה הרגילה.
         */
        let storedRaw =
            defaults.string(
                forKey:
                    "current_belt"
            )
            ?? defaults.string(
                forKey:
                    "belt_current"
            )
            ?? defaults.string(
                forKey:
                    "currentBelt"
            )
            ?? defaults.string(
                forKey:
                    "belt"
            )

        let cleanStoredRaw =
            (storedRaw ?? "")
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        /*
         * משתמש ללא חגורה רשומה,
         * או ערך שלא ניתן לזהות:
         * Android מתחיל מכתומה.
         */
        guard
            !cleanStoredRaw.isEmpty,
            let registeredBelt =
                beltFromStoredId(
                    cleanStoredRaw
                )
        else {
            return .orange
        }

        let initialBelt =
            nextBelt(
                after:
                    registeredBelt
            )

        /*
         * הגנה נוספת:
         * הקרוסלה מציגה רק את
         * החגורות שנמצאות ב-belts.
         */
        return belts.contains(
            initialBelt
        )
            ? initialBelt
            : .orange
    }

    private func toSharedSubject(
        _ local: SubjectTopic
    ) -> Shared.SubjectTopic {
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
    
    private func allItemsForSelectedBelt() -> [(topicTitle: String, item: String)] {
        let topicTitles = TopicsEngine.shared.topicTitlesFor(belt: selectedBelt)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { partial, item in
                if !partial.contains(item) {
                    partial.append(item)
                }
            }
        
        var result: [(topicTitle: String, item: String)] = []
        
        for topicTitle in topicTitles {
            let details = topicDetailsFor(
                belt: selectedBelt,
                topicTitle: topicTitle
            )
            
            let directItems = ContentRepo.shared.getAllItemsFor(
                belt: selectedBelt,
                topicTitle: topicTitle,
                subTopicTitle: nil
            )
            
            for item in directItems {
                result.append((topicTitle, item))
            }
            
            for subTitle in details.subTitles {
                let subItems = ContentRepo.shared.getAllItemsFor(
                    belt: selectedBelt,
                    topicTitle: topicTitle,
                    subTopicTitle: subTitle
                )
                
                for item in subItems {
                    result.append((topicTitle, item))
                }
            }
        }
        
        return result
    }
    
    private func practiceItemsForCurrentToken() -> [String] {
        let token = practiceTokenFromLists.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if token.isEmpty || token == "__ALL__" {
            return allItemsForSelectedBelt().map { $0.item }
        }
        
        return ContentRepo.shared.getAllItemsFor(
            belt: selectedBelt,
            topicTitle: token,
            subTopicTitle: nil
        )
    }
    
    private func isDone(topicTitle: String, item: String) -> Bool {
        let b = selectedBelt.id
        let t = topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let i = item.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = "kmi.exercise.\(b).\(t).\(i).done"
        
        if UserDefaults.standard.object(forKey: key) == nil { return false }
        return UserDefaults.standard.bool(forKey: key)
    }
    
    private var beltProgress: (done: Int, total: Int) {
        let all = allItemsForSelectedBelt()
        let doneCount = all.filter { isDone(topicTitle: $0.topicTitle, item: $0.item) }.count
        return (doneCount, all.count)
    }
    
    private func topicAccentColor(
        _ topicTitle: String
    ) -> Color {

        _ = topicTitle

        return readableBeltAccent
    }
    
    private func topicImageName(_ topicTitle: String) -> String? {
        let clean = topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = clean.lowercased()
        
        if clean.contains("הגנות") || lower.contains("defense") || lower.contains("defenses") {
            return "topic_defenses"
        }
        
        if clean.contains("שחרור") ||
            clean.contains("שחרורים") ||
            lower.contains("release") ||
            lower.contains("releases") {
            return "topic_releases"
        }
        
        if clean.contains("עבודת ידיים") ||
            clean.contains("עבודת יד") ||
            clean.contains("מכות ידיים") ||
            clean.contains("מכות יד") ||
            lower.contains("hand") ||
            lower.contains("hands") {
            return "topic_hand_strikes"
        }
        
        if clean.contains("מכות מרפק") ||
            clean.contains("מרפק") ||
            lower.contains("elbow") ||
            lower.contains("elbows") {
            return "topic_elbow_strikes"
        }
        
        if clean.contains("בעיטה") ||
            clean.contains("בעיטות") ||
            lower.contains("kick") ||
            lower.contains("kicks") {
            return "topic_kicks"
        }
        
        if clean.contains("בלימות") ||
            clean.contains("גלגולים") ||
            clean.contains("גלגול") ||
            clean.contains("בלימה") ||
            lower.contains("breakfall") ||
            lower.contains("roll") {
            return "topic_breakfalls_rolls"
        }
        
        if selectedBelt == .yellow &&
            (
                clean.contains("מניעת התקרבות התוקף") ||
                clean.contains("מניעת התקרבות") ||
                clean.contains("התקרבות התוקף") ||
                lower.contains("prevent attacker approach") ||
                lower.contains("prevent approach")
            ) {

            return "topic_prevent_attacker_approach"
        }
        
        if clean.contains("עמידת מוצא") ||
            lower.contains("ready stance") ||
            lower.contains("stance") {
            return "topic_ready_stance"
        }
        
        if clean.contains("קרקע") ||
            lower.contains("ground") {
            return "topic_ground_fighting"
        }

        if clean.contains("מקל") ||
            clean.contains("חבטה") ||
            lower.contains("stick") ||
            lower.contains("baton") {
            return "topic_stick"
        }

        if clean.contains("קוואלר") ||
            clean.contains("קאוולר") ||
            clean.contains("קאוול") ||
            lower.contains("cavalier") ||
            lower.contains("kavaler") {
            return "topic_cavalier"
        }
        
        if clean.contains("כללי") ||
            lower.contains("general") {
            return "topic_general"
        }
        
        return nil
    }
    
    private func topicSymbolName(_ topicTitle: String) -> String {
        let clean = topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = clean.lowercased()
        
        if clean.contains("הגנות") || lower.contains("defense") {
            return "shield.fill"
        }
        
        if clean.contains("שחרור") || lower.contains("release") {
            return "hand.raised.fill"
        }
        
        if clean.contains("יד") || clean.contains("אגרוף") || clean.contains("מרפק") {
            return "hand.tap.fill"
        }
        
        if clean.contains("בעיטה") || clean.contains("בעיטות") {
            return "figure.kickboxing"
        }
        
        if clean.contains("בלימות") || clean.contains("גלגולים") {
            return "arrow.triangle.2.circlepath"
        }
        
        if clean.contains("קרקע") {
            return "figure.wrestling"
        }
        
        if clean.contains("קאוול") {
            return "list.bullet.rectangle.fill"
        }
        
        return "list.bullet.rectangle.fill"
    }
    
    private func isTopicLocked(_ topicTitle: String) -> Bool {
        let _ = accessRefreshTick
        
        let clean = topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let accessMode = LockedContentPolicy.currentAccessMode()
        
        return LockedContentPolicy.shouldShowLock(
            accessMode: accessMode,
            title: clean
        )
    }
    
    private func isDefenseTopic(
        _ topicTitle: String
    ) -> Bool {
        let clean =
            topicTitle
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        let lower =
            clean.lowercased()

        return
            clean.contains("הגנות") ||
            lower.contains("defense") ||
            lower.contains("defenses")
    }

    private func openTopicFromByBelt(
        topicTitle: String,
        hasSubs: Bool,
        isExpanded: Bool
    ) {
        let cleanTopicTitle =
            topicTitle
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        guard !cleanTopicTitle.isEmpty else {
            return
        }

        /*
         * Android parity:
         * קודם בודקים הרשאה.
         */
        if isTopicLocked(
            cleanTopicTitle
        ) {
            nav.push(
                .subscriptionPlans
            )

            return
        }

        /*
         * Android parity:
         * אם יש תתי־נושאים,
         * לא מנווטים למסך חדש.
         *
         * פותחים / סוגרים אותם
         * בתוך הכרטיס.
         */
        if hasSubs {
            withAnimation(
                .easeInOut(
                    duration: 0.22
                )
            ) {
                expandedTopic =
                    isExpanded
                        ? nil
                        : cleanTopicTitle
            }

            return
        }

        /*
         * Android parity:
         * נושא "הגנות" ללא תתי־נושאים
         * אינו נכנס ישירות ל-Materials.
         *
         * Android שולח אותו ל-
         * onOpenDefenseMenu ->
         * openSubTopics.
         *
         * ב-iOS אנחנו משתמשים במסלול
         * תתי־הנושאים הקיים.
         */
        if isDefenseTopic(
            cleanTopicTitle
        ) {
            selectedTopicSubTopicsRoute =
                BeltTopicSubTopicsRoute(
                    belt:
                        selectedBelt,
                    topicTitle:
                        cleanTopicTitle,
                    linkedSubjects:
                        []
                )

            return
        }

        /*
         * נושא רגיל ללא תתי־נושאים:
         * כניסה ישירה למסך התרגילים.
         */
        selectedExerciseRoute =
            BeltTopicExerciseRoute(
                belt:
                    selectedBelt,
                topicTitle:
                    cleanTopicTitle
            )
    }
   
    @ViewBuilder
    private func navigationChevron(
        hasSubs: Bool,
        isExpanded: Bool,
        isEnglish _: Bool
    ) -> some View {

        if hasSubs {

            Image(
                systemName:
                    isExpanded
                        ? "chevron.up"
                        : "chevron.down"
            )
            .resizable()
            .scaledToFit()
            .foregroundStyle(
                readableBeltAccent
            )
            .kmiIconSize(20)
            .accessibilityHidden(true)
        }
    }

    private func topicTextBlock(
        title: String,
        subtitle: String?,
        isEnglish: Bool
    ) -> some View {

        let cleanSubtitle =
            subtitle?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        return VStack(
            alignment:
                isEnglish
                    ? .leading
                    : .trailing,
            spacing: 1
        ) {

            Text(
                uiTopicTitle(title)
            )
            .kmiTypography(
                .cardTitle
            )
            .foregroundStyle(
                byBeltTitleColor
            )
            .frame(
                maxWidth: .infinity,
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
            .lineLimit(2)

            if !cleanSubtitle.isEmpty {

                Text(
                    cleanSubtitle
                )
                .kmiTypography(
                    .caption
                )
                .fontWeight(
                    .heavy
                )
                .foregroundStyle(
                    byBeltRowSubColor
                )
                .frame(
                    maxWidth: .infinity,
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
                .lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private func topicIconBox(
        topicTitle: String,
        accent _: Color
    ) -> some View {

        if let imageName =
            topicImageName(
                topicTitle
            ) {

            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(
                    width: 38,
                    height: 31
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    )
                )
        }
    }

    private func topicAccentStrip(
        _ accent: Color
    ) -> some View {

        RoundedRectangle(
            cornerRadius: 999,
            style: .continuous
        )
        .fill(

            LinearGradient(
                colors: [
                    accent,
                    accent.opacity(
                        colorScheme == .dark
                            ? 0.90
                            : 0.82
                    )
                ],
                startPoint:
                    .top,
                endPoint:
                    .bottom
            )
        )
        .frame(
            width: 3,
            height: 34
        )
    }
    
    private struct BeltPDFSourceRow {
        let topicTitle: String
        let rawItem: String
        let indexInsideTopic: Int
    }

    private func normalizedPDFStatusPart(
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

    private func uniquePDFItems(
        _ values: [String]
    ) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for rawValue in values {
            let cleanValue =
                rawValue.trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

            guard !cleanValue.isEmpty else {
                continue
            }

            let normalizedKey =
                normalizedPDFStatusPart(
                    cleanValue
                )
                .lowercased()

            guard seen
                .insert(
                    normalizedKey
                )
                .inserted else {
                continue
            }

            result.append(
                cleanValue
            )
        }

        return result
    }

    private func pdfSourceRows(
        for belt: Belt
    ) -> [BeltPDFSourceRow] {
        let topicTitles =
            TopicsEngine.shared
                .topicTitlesFor(
                    belt: belt
                )
                .map {
                    $0.trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                }
                .filter {
                    !$0.isEmpty
                }
                .reduce(
                    into: [String]()
                ) { result, title in
                    if !result.contains(title) {
                        result.append(title)
                    }
                }

        var result:
            [BeltPDFSourceRow] = []

        for topicTitle in topicTitles {
            let details =
                topicDetailsFor(
                    belt: belt,
                    topicTitle:
                        topicTitle
                )

            var topicItems =
                ContentRepo.shared
                    .getAllItemsFor(
                        belt: belt,
                        topicTitle:
                            topicTitle,
                        subTopicTitle:
                            nil
                    )

            for rawSubTopicTitle
                in details.subTitles {
                let cleanSubTopicTitle =
                    rawSubTopicTitle
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )

                guard !cleanSubTopicTitle
                    .isEmpty,
                      cleanSubTopicTitle !=
                        topicTitle else {
                    continue
                }

                topicItems.append(
                    contentsOf:
                        ContentRepo.shared
                            .getAllItemsFor(
                                belt: belt,
                                topicTitle:
                                    topicTitle,
                                subTopicTitle:
                                    cleanSubTopicTitle
                            )
                )
            }

            let uniqueItems =
                uniquePDFItems(
                    topicItems
                )

            for (
                index,
                rawItem
            ) in uniqueItems.enumerated() {
                result.append(
                    BeltPDFSourceRow(
                        topicTitle:
                            topicTitle,
                        rawItem:
                            rawItem,
                        indexInsideTopic:
                            index
                    )
                )
            }
        }

        return result
    }

    private func pdfStatusText(
        belt: Belt,
        sourceRow: BeltPDFSourceRow
    ) -> String {
        let cleanItem =
            normalizedPDFStatusPart(
                sourceRow.rawItem
            )

        let statusId =
            "status_\(belt.id)_" +
            "\(sourceRow.topicTitle)_" +
            "\(sourceRow.indexInsideTopic)_" +
            cleanItem

        let storedStatus =
            UserDefaults.standard
                .string(
                    forKey:
                        "mark.\(statusId)"
                )

        switch storedStatus {
        case "mastered":
            return isEnglish
                ? "Known"
                : "יודע"

        case "unknown":
            return isEnglish
                ? "Unknown"
                : "לא יודע"

        default:
            return isEnglish
                ? "Not marked"
                : "לא סומן"
        }
    }

    private func canonicalPDFId(
        belt: Belt,
        sourceRow: BeltPDFSourceRow
    ) -> String {
        let cleanItem =
            sourceRow.rawItem
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        return
            "\(belt.id)||" +
            "\(sourceRow.topicTitle)||" +
            "||\(cleanItem)"
    }

    private func pdfDisplayTitle(
        sourceRow: BeltPDFSourceRow
    ) -> String {
        let localizedTopic =
            KmiEnglishTitleResolver.title(
                for:
                    sourceRow.topicTitle,
                isEnglish:
                    isEnglish
            )

        let localizedExercise =
            KmiEnglishTitleResolver.title(
                for:
                    sourceRow.rawItem,
                isEnglish:
                    isEnglish
            )

        return
            "\(localizedTopic) — " +
            localizedExercise
    }

    private func materialsPDFItems(
        for belt: Belt
    ) -> [MaterialsPdfItemIOS] {
        let defaults =
            UserDefaults.standard

        let sourceRows =
            pdfSourceRows(
                for: belt
            )

        let practiceFavoriteKeys =
            Set(
                (
                    defaults.stringArray(
                        forKey:
                            "practice_favorites"
                    ) ?? []
                )
                .map {
                    normalizedPDFStatusPart(
                        $0
                    )
                    .lowercased()
                }
                .filter {
                    !$0.isEmpty
                }
            )

        return sourceRows
            .enumerated()
            .map {
                globalIndex,
                sourceRow in

                let canonicalId =
                    canonicalPDFId(
                        belt: belt,
                        sourceRow:
                            sourceRow
                    )

                let normalizedRawItem =
                    normalizedPDFStatusPart(
                        sourceRow.rawItem
                    )
                    .lowercased()

                let localizedItem =
                    KmiEnglishTitleResolver
                        .title(
                            for:
                                sourceRow
                                    .rawItem,
                            isEnglish:
                                isEnglish
                        )

                let normalizedLocalizedItem =
                    normalizedPDFStatusPart(
                        localizedItem
                    )
                    .lowercased()

                let isCanonicalFavorite =
                    defaults.bool(
                        forKey:
                            "favorite.\(canonicalId)"
                    )

                let isPracticeFavorite =
                    practiceFavoriteKeys
                        .contains(
                            normalizedRawItem
                        ) ||
                    practiceFavoriteKeys
                        .contains(
                            normalizedLocalizedItem
                        )

                let note =
                    defaults.string(
                        forKey:
                            "note.\(canonicalId)"
                    )?
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    ) ?? ""

                return MaterialsPdfItemIOS(
                    number:
                        globalIndex + 1,
                    title:
                        pdfDisplayTitle(
                            sourceRow:
                                sourceRow
                        ),
                    status:
                        pdfStatusText(
                            belt: belt,
                            sourceRow:
                                sourceRow
                        ),
                    isFavorite:
                        isCanonicalFavorite ||
                        isPracticeFavorite,
                    isExcluded:
                        defaults.bool(
                            forKey:
                                "excluded.\(canonicalId)"
                        ),
                    hasNote:
                        !note.isEmpty
                )
            }
    }

    private func createAndSharePDF() {
        let pdfBelt =
            quickMenuBelt

        let pdfItems =
            materialsPDFItems(
                for: pdfBelt
            )

        guard !pdfItems.isEmpty else {
            pdfShareItems.removeAll()

            pdfErrorMessage =
                isEnglish
                    ? "There are no exercises available for this belt."
                    : "אין תרגילים זמינים לחגורה זו."

            return
        }

        let pdfTitle =
            isEnglish
                ? "\(beltDisplayTitle(pdfBelt)) Belt"
                : "חגורה \(beltDisplayTitle(pdfBelt))"

        do {
            let fileURL =
                try MaterialsPdfGeneratorIOS
                    .create(
                        belt:
                            pdfBelt,
                        topicTitle:
                            pdfTitle,
                        items:
                            pdfItems,
                        isEnglish:
                            isEnglish
                    )

            pdfShareItems = [
                fileURL
            ]

            showPDFShareSheet =
                true
        } catch {
            pdfShareItems.removeAll()

            pdfErrorMessage =
                isEnglish
                    ? "The PDF file could not be created."
                    : "לא ניתן היה ליצור את קובץ ה־PDF."
        }
    }

    var body: some View {

        ZStack(
            alignment: .top
        ) {

            KmiAppBackground()

            VStack(spacing: 0) {

                beltModeTabs

                Spacer()
                    .frame(height: 4)

                byBeltContent
                    .padding(
                        .horizontal,
                        14
                    )
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .top
            )

            GeometryReader { geo in

                VStack(spacing: 0) {

                    Spacer(
                        minLength: 0
                    )

                    BeltArcPicker(
                        belts: belts,
                        selectedBelt: $selectedBelt,
                        isEnglish: isEnglish
                    )
                    .frame(
                        width: geo.size.width,
                        height: 152
                    )
                }
                .frame(
                    width: geo.size.width,
                    height: geo.size.height,
                    alignment: .bottom
                )
            }
            .zIndex(40)
            .allowsHitTesting(
                !quickMenuOpen
            )
                    
            BeltScreenSideQuickMenuOverlay(
                isPresented:
                    $quickMenuOpen,
                isEnglish:
                    isEnglish,
                accent:
                    BeltPaletteByBeltScreen
                        .color(
                            for:
                                quickMenuBelt
                        ),
                items:
                    beltScreenQuickMenuItems,
                onClose: {
                    withAnimation(
                        .spring(
                            response: 0.28,
                            dampingFraction:
                                0.86
                        )
                    ) {
                        quickMenuOpen =
                            false
                    }
                }
            )
            .zIndex(1200)
        }
        .environment(
            \.layoutDirection,
            screenLayoutDirection
        )
        .onAppear {

            quickMenuOpen =
                false

            /*
             * אם המסך כבר אותחל בעבר,
             * רק מוודאים שה-cache קיים.
             */
            if didInitializeSelectedBelt {

                ensureBeltTopicsCache(
                    for:
                        selectedBelt
                )

                NotificationCenter
                    .default
                    .post(
                        name:
                            Notification.Name(
                                "KMI_TOP_TITLE_OVERRIDE"
                            ),
                        object:
                            screenTitleForMode
                    )

                return
            }

            expandedTopic =
                nil

            selectedBelt =
                initialBeltLikeAndroid()

            /*
             * בנייה אחת בלבד של נתוני
             * החגורה הראשונה.
             */
            ensureBeltTopicsCache(
                for:
                    selectedBelt
            )

            didInitializeSelectedBelt =
                true

            NotificationCenter
                .default
                .post(
                    name:
                        Notification.Name(
                            "KMI_TOP_TITLE_OVERRIDE"
                        ),
                    object:
                        screenTitleForMode
                )
        }
        .onChange(
            of: belt
        ) { _, newBelt in

            /*
             * מאפשר לפקודה קולית או
             * לניווט גלובלי לעדכן חגורה
             * גם כאשר המסך נשאר בזיכרון.
             */
            guard
                newBelt != .white,
                belts.contains(newBelt),
                selectedBelt != newBelt
            else {
                return
            }

            selectedBelt =
                newBelt

            expandedTopic =
                nil

            quickMenuOpen =
                false
        }
        .onChange(
            of: selectedBelt
        ) { _, newValue in

            expandedTopic =
                nil

            /*
             * אם החגורה כבר נפתחה בעבר:
             * O(1), אין טעינת ContentRepo.
             *
             * אם זו הפעם הראשונה:
             * היא נבנית פעם אחת ונשמרת.
             */
            ensureBeltTopicsCache(
                for:
                    newValue
            )

            UserDefaults.standard.set(
                newValue.id,
                forKey:
                    "selected_belt"
            )

            NotificationCenter
                .default
                .post(
                    name:
                        Notification.Name(
                            "KMI_SELECTED_BELT_CHANGED"
                        ),
                    object:
                        newValue.id
                )

            if quickMenuOpen {

                withAnimation(
                    .spring(
                        response:
                            0.24,
                        dampingFraction:
                            0.92
                    )
                ) {
                    quickMenuOpen =
                        false
                }
            }

            NotificationCenter
                .default
                .post(
                    name:
                        Notification.Name(
                            "KMI_TOP_TITLE_OVERRIDE"
                        ),
                    object:
                        screenTitleForMode
                )
        }
        .onChange(
            of:
                effectiveLanguageCode
        ) { _, _ in

            /*
             * טקסטי subtitle משתנים
             * בין עברית לאנגלית.
             */
            ensureBeltTopicsCache(
                for:
                    selectedBelt,
                force:
                    true
            )
        }
        .onReceive(
            NotificationCenter
                .default
                .publisher(
                    for:
                        Notification.Name(
                            "KMI_GLOBAL_SEARCH_PICK"
                        )
                )
        ) { notif in

            guard
                let key =
                    notif.object
                        as? String
            else {
                return
            }

            pickedExercise =
                ExerciseSelection
                    .fromSearchKey(
                        key
                    )
        }
        .onReceive(
            NotificationCenter
                .default
                .publisher(
                    for:
                        Notification.Name(
                            "KMI_ACCESS_CHANGED"
                        )
                )
        ) { _ in
            accessRefreshTick += 1
        }
        .onReceive(
            NotificationCenter
                .default
                .publisher(
                    for:
                        UserDefaults
                            .didChangeNotification
                )
        ) { _ in
            accessRefreshTick += 1
        }
        .onReceive(
            NotificationCenter
                .default
                .publisher(
                    for:
                        Notification.Name(
                            "KMI_BELT_MATERIALS_SHARE_PDF"
                        )
                )
        ) { _ in
            createAndSharePDF()
        }
        .onDisappear {
            NotificationCenter
                .default
                .post(
                    name:
                        Notification.Name(
                            "KMI_TOP_TITLE_OVERRIDE"
                        ),
                    object:
                        ""
                )
        }
        .navigationDestination(item: $selectedLinkedTopicRoute) { route in
            LinkedTopicSubTopicsView(
                title: route.title,
                subjects: route.subjects,
                onPickLinkedSubject: { subject in
                    selectedSubjectForSubTopics = subject
                }
            )
        }
      
        .navigationDestination(
            item:
                $selectedTopicSubTopicsRoute
        ) { route in

            KmiRootLayout(
                title:
                    uiTopicTitle(
                        route.topicTitle
                    ),
                nav:
                    nav,
                selectedIcon:
                    .search,
                onBackOverride: {

                    selectedTopicSubTopicsRoute =
                        nil
                }
            ) {
                BeltTopicSubTopicsView(
                    belt:
                        route.belt,
                    topicTitle:
                        route.topicTitle,
                    linkedSubjects:
                        route.linkedSubjects,

                    onPickAllTopic: {
                        selectedExerciseRoute =
                            BeltTopicExerciseRoute(
                                belt:
                                    route.belt,
                                topicTitle:
                                    route.topicTitle
                            )
                    },

                    onPickSubTopic: {
                        subTopicTitle in

                        let cleanSubTopic =
                            subTopicTitle
                                .trimmingCharacters(
                                    in:
                                        .whitespacesAndNewlines
                                )

                        guard
                            !cleanSubTopic.isEmpty
                        else {
                            return
                        }

                        selectedExerciseRoute =
                            BeltTopicExerciseRoute(
                                belt:
                                    route.belt,
                                topicTitle:
                                    route.topicTitle,
                                forcedSubTopicTitle:
                                    cleanSubTopic
                            )
                    },

                    onPickLinkedSubject: {
                        subject in

                        selectedSubjectForSubTopics =
                            subject
                    }
                )
                .navigationBarBackButtonHidden(
                    true
                )
            }
        }

        .navigationDestination(
            item:
                $selectedExerciseRoute
        ) { route in

            KmiRootLayout(
                title:
                    uiTopicTitle(
                        route.forcedSubTopicTitle
                            ?? route.topicTitle
                    ),
                nav:
                    nav,
                selectedIcon:
                    .search,
                onBackOverride: {

                    selectedExerciseRoute =
                        nil
                }
            ) {
                MaterialsView(
                    belt:
                        route.belt,
                    topicTitle:
                        route.topicTitle,
                    subTopicTitle:
                        route.forcedSubTopicTitle,

                    onSummary: {
                        pickedBelt,
                        pickedTopicTitle,
                        pickedSubTopicTitle in

                        selectedBelt =
                            pickedBelt

                        let cleanTopic =
                            pickedTopicTitle
                                .trimmingCharacters(
                                    in:
                                        .whitespacesAndNewlines
                                )

                        let cleanSubTopic =
                            pickedSubTopicTitle?
                                .trimmingCharacters(
                                    in:
                                        .whitespacesAndNewlines
                                )

                        nav.push(
                            .summary(
                                belt:
                                    pickedBelt,
                                topic:
                                    cleanTopic.isEmpty
                                        ? nil
                                        : cleanTopic,
                                subTopic:
                                    cleanSubTopic?
                                        .isEmpty == false
                                        ? cleanSubTopic
                                        : nil
                            ),
                            presentationDelay:
                                0.30
                        )
                    },

                    onPractice: {
                        pickedBelt,
                        pickedTopicTitle in

                        selectedBelt =
                            pickedBelt

                        let cleanTopic =
                            pickedTopicTitle
                                .trimmingCharacters(
                                    in:
                                        .whitespacesAndNewlines
                                )

                        practiceTokenFromLists =
                            cleanTopic.isEmpty
                                ? "__ALL__"
                                : cleanTopic

                        nav.push(
                            .practice(
                                belt:
                                    pickedBelt,
                                topicTitle:
                                    cleanTopic.isEmpty
                                        ? "__ALL__"
                                        : cleanTopic
                            )
                        )
                    }
                )
                .navigationBarBackButtonHidden(
                    true
                )
            }
        }

        .navigationDestination(
            item:
                $selectedSubjectForSubTopics
        ) { subject in

            SubjectSubTopicsView(
                belt:
                    selectedBelt,
                subject:
                    subject,
                onPickSection: {
                    sectionTitle in

                    selectedSubjectSectionRoute =
                        SubjectSectionExerciseRoute(
                            belt:
                                selectedBelt,
                            subject:
                                subject,
                            sectionTitle:
                                sectionTitle
                        )
                }
            )
        }
        .navigationDestination(item: $selectedSubjectSectionRoute) { (route: BeltQuestionsByBeltView.SubjectSectionExerciseRoute) in
            SubjectExercisesView(route: route)
        }
        .navigationDestination(item: $pickedExercise) { selection in
            ExerciseDetailView(
                belt: selection.belt,
                topicTitle: selection.topicTitle,
                item: selection.item
            )
        }
        .sheet(
            isPresented:
                $showPracticeMenu
        ) {
            KmiPracticeMenuSheet(
                defaultBelt:
                    quickMenuBelt,
                canUseExtras:
                    true,
                isEnglish:
                    isEnglish,
                onRandomPractice: {
                    selectedPracticeBelt in

                    showPracticeMenu = false
                    practiceTokenFromLists =
                        "__ALL__"

                    DispatchQueue.main
                        .asyncAfter(
                            deadline:
                                .now() + 0.22
                        ) {
                            nav.push(
                                .practice(
                                    belt:
                                        selectedPracticeBelt,
                                    topicTitle:
                                        "__ALL__"
                                )
                            )
                        }
                },
                onFinalExam: {
                    selectedPracticeBelt in

                    showPracticeMenu = false

                    DispatchQueue.main
                        .asyncAfter(
                            deadline:
                                .now() + 0.22
                        ) {
                            nav.push(
                                .beltFinalExam(
                                    belt:
                                        selectedPracticeBelt
                                )
                            )
                        }
                },
                onPracticeByTopic: {
                    selectedPracticeBelt,
                    selectedTopicTitle in

                    showPracticeMenu = false
                    selectedBelt =
                        selectedPracticeBelt

                    practiceTokenFromLists =
                        selectedTopicTitle

                    DispatchQueue.main
                        .asyncAfter(
                            deadline:
                                .now() + 0.22
                        ) {
                            nav.push(
                                .practice(
                                    belt:
                                        selectedPracticeBelt,
                                    topicTitle:
                                        selectedTopicTitle
                                )
                            )
                        }
                },
                onDismiss: {
                    showPracticeMenu = false
                }
            )
            .presentationDetents([
                .medium,
                .large
            ])
            .presentationDragIndicator(
                .visible
            )
            .interactiveDismissDisabled(
                false
            )
        }
        .sheet(
            isPresented:
                $showPDFShareSheet,
            onDismiss: {
                pdfShareItems.removeAll()
            }
        ) {
            KmiShareSheet(
                items: pdfShareItems
            )
            .presentationDetents([
                .medium,
                .large
            ])
            .presentationDragIndicator(
                .visible
            )
        }
        .sheet(
            isPresented:
                $showGeneralNote,
            onDismiss: {

                generalNoteTitle =
                    ""

                generalNoteText =
                    ""
            }
        ) {

            VStack(
                spacing:
                    16
            ) {

                Capsule()
                    .fill(
                        KmiAppTheme
                            .outline(
                                for:
                                    colorScheme
                            )
                            .opacity(
                                0.45
                            )
                    )
                    .frame(
                        width:
                            42,
                        height:
                            5
                    )
                    .padding(
                        .top,
                        10
                    )

                Image(
                    systemName:
                        "info.circle.fill"
                )
                .kmiIconSize(
                    34
                )
                .foregroundStyle(
                    KmiAppTheme
                        .secondary(
                            for:
                                colorScheme
                        )
                )

                Text(
                    generalNoteTitle
                )
                .kmiTypography(
                    .sectionTitle
                )
                .foregroundStyle(
                    KmiAppTheme
                        .onSurface(
                            for:
                                colorScheme
                        )
                )
                .multilineTextAlignment(
                    .center
                )
                .frame(
                    maxWidth:
                        .infinity
                )

                ScrollView {

                    Text(
                        generalNoteText
                    )
                    .kmiTypography(
                        .body
                    )
                    .foregroundStyle(
                        KmiAppTheme
                            .onSurfaceVariant(
                                for:
                                    colorScheme
                            )
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

                Button {

                    showGeneralNote =
                        false

                } label: {

                    Text(
                        isEnglish
                            ? "Close"
                            : "סגור"
                    )
                    .kmiTypography(
                        .action
                    )
                    .foregroundStyle(
                        KmiAppTheme
                            .onPrimary(
                                for:
                                    colorScheme
                            )
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                    .frame(
                        minHeight:
                            48
                    )
                    .background {

                        RoundedRectangle(
                            cornerRadius:
                                14,
                            style:
                                .continuous
                        )
                        .fill(
                            KmiAppTheme
                                .primary(
                                    for:
                                        colorScheme
                                )
                        )
                    }
                }
                .buttonStyle(
                    .plain
                )
            }
            .padding(
                .horizontal,
                20
            )
            .padding(
                .bottom,
                18
            )
            .background(
                KmiAppTheme
                    .surface(
                        for:
                            colorScheme
                    )
            )
            .environment(
                \.layoutDirection,
                screenLayoutDirection
            )
            .presentationDetents([
                .medium,
                .large
            ])
            .presentationDragIndicator(
                .visible
            )
        }
        .alert(
            isEnglish
                ? "PDF Creation Failed"
                : "יצירת ה־PDF נכשלה",
            isPresented: Binding(
                get: {
                    pdfErrorMessage != nil
                },
                set: { isPresented in
                    if !isPresented {
                        pdfErrorMessage = nil
                    }
                }
            )
        ) {
            Button(
                isEnglish ? "OK" : "אישור",
                role: .cancel
            ) {
                pdfErrorMessage = nil
            }
        } message: {
            Text(
                pdfErrorMessage ?? ""
            )
        }
    }
    
    private func generalNoteButton(
        title: String,
        text: String
    ) -> some View {

        Button {

            generalNoteTitle =
                isEnglish
                    ? "General note: \(uiTopicTitle(title))"
                    : "הערה כללית: \(uiTopicTitle(title))"

            generalNoteText =
                text.trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

            showGeneralNote =
                true

        } label: {

            ZStack {

                Circle()
                    .fill(
                        KmiAppTheme
                            .secondaryContainer(
                                for: colorScheme
                            )
                    )

                Circle()
                    .stroke(
                        KmiAppTheme
                            .secondary(
                                for: colorScheme
                            )
                            .opacity(0.45),
                        lineWidth: 1
                    )

                Image(
                    systemName:
                        "info.circle.fill"
                )
                .resizable()
                .scaledToFit()
                .foregroundStyle(
                    KmiAppTheme
                        .onSecondaryContainer(
                            for: colorScheme
                        )
                )
                .kmiIconSize(17)
            }
            .frame(
                width: 26,
                height: 26
            )
        }
        .buttonStyle(.plain)
        .frame(
            width: 30,
            height: 30
        )
    }

    @ViewBuilder
    private func topicRowCard(
        entry: BeltTopicUi,
        topicTitle: String,
        subTitles: [String],
        hasSubs: Bool,
        isExpanded: Bool,
        locked: Bool,
        accent: Color,
        rowMinHeight: CGFloat
    ) -> some View {

        let topicGeneralNote =
            ContentRepo.shared
                .getTopicGeneralNote(
                    belt:
                        selectedBelt,
                    topicTitle:
                        topicTitle
                )?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        VStack(spacing: 0) {

            topicMainRow(
                entry:
                    entry,
                topicTitle:
                    topicTitle,
                hasSubs:
                    hasSubs,
                isExpanded:
                    isExpanded,
                locked:
                    locked,
                generalNote:
                    topicGeneralNote,
                accent:
                    accent,
                rowMinHeight:
                    rowMinHeight
            )

            if hasSubs &&
                isExpanded {

                expandedSubTopicsBlock(
                    topicTitle:
                        topicTitle,
                    subTitles:
                        subTitles,
                    accent:
                        accent
                )
            }
        }
        .frame(
            maxWidth: .infinity
        )
        .frame(
            minHeight:
                rowMinHeight
        )
        .padding(
            .horizontal,
            10
        )
        .padding(
            .vertical,
            1
        )
        .contentShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
        .onTapGesture {

            openTopicFromByBelt(
                topicTitle:
                    topicTitle,
                hasSubs:
                    hasSubs,
                isExpanded:
                    isExpanded
            )
        }
    }

    @ViewBuilder
    private func topicMainRow(
        entry: BeltTopicUi,
        topicTitle: String,
        hasSubs: Bool,
        isExpanded: Bool,
        locked: Bool,
        generalNote: String,
        accent: Color,
        rowMinHeight _: CGFloat
    ) -> some View {

        HStack(spacing: 0) {

            if isEnglish {

                topicAccentStrip(
                    accent
                )

                Spacer()
                    .frame(width: 5)

                if topicImageName(
                    topicTitle
                ) != nil {

                    topicIconBox(
                        topicTitle:
                            topicTitle,
                        accent:
                            accent
                    )

                    Spacer()
                        .frame(width: 6)
                }

                topicTextBlock(
                    title:
                        entry.title,
                    subtitle:
                        entry.subtitle,
                    isEnglish:
                        true
                )

                Spacer()
                    .frame(width: 4)

                if !generalNote.isEmpty {

                    generalNoteButton(
                        title:
                            topicTitle,
                        text:
                            generalNote
                    )
                }

                if locked {

                    Spacer()
                        .frame(width: 4)

                    PulsingLockBadge()
                        .frame(
                            width: 20,
                            height: 20
                        )
                }

                if hasSubs {

                    Spacer()
                        .frame(width: 4)

                    navigationChevron(
                        hasSubs:
                            true,
                        isExpanded:
                            isExpanded,
                        isEnglish:
                            true
                    )
                    .frame(
                        width: 20,
                        height: 20
                    )
                }

            } else {

                if hasSubs {

                    navigationChevron(
                        hasSubs:
                            true,
                        isExpanded:
                            isExpanded,
                        isEnglish:
                            false
                    )
                    .frame(
                        width: 20,
                        height: 20
                    )

                    Spacer()
                        .frame(width: 4)
                }

                if locked {

                    PulsingLockBadge()
                        .frame(
                            width: 20,
                            height: 20
                        )

                    Spacer()
                        .frame(width: 4)
                }

                if !generalNote.isEmpty {

                    generalNoteButton(
                        title:
                            topicTitle,
                        text:
                            generalNote
                    )

                    Spacer()
                        .frame(width: 4)
                }

                topicTextBlock(
                    title:
                        entry.title,
                    subtitle:
                        entry.subtitle,
                    isEnglish:
                        false
                )

                if topicImageName(
                    topicTitle
                ) != nil {

                    Spacer()
                        .frame(width: 6)

                    topicIconBox(
                        topicTitle:
                            topicTitle,
                        accent:
                            accent
                    )

                    Spacer()
                        .frame(width: 5)
                }

                topicAccentStrip(
                    accent
                )
            }
        }
        .environment(
            \.layoutDirection,
            .leftToRight
        )
        .padding(
            .horizontal,
            7
        )
        .padding(
            .vertical,
            4
        )
    }

    @ViewBuilder
    private func expandedSubTopicsBlock(
        topicTitle: String,
        subTitles: [String],
        accent: Color
    ) -> some View {

        VStack(spacing: 8) {

            ForEach(
                subTitles,
                id: \.self
            ) { sub in

                subTopicButton(
                    topicTitle:
                        topicTitle,
                    subTitle:
                        sub
                )
            }

            /*
             * Android parity:
             * כאשר נושא מורחב,
             * "פתח את כל הנושא"
             * מוצג תמיד.
             */
            fullTopicButton(
                topicTitle:
                    topicTitle,
                accent:
                    accent
            )
        }
        .padding(
            .horizontal,
            12
        )
        .padding(
            .bottom,
            12
        )
        .transition(
            .move(
                edge: .top
            )
            .combined(
                with: .opacity
            )
        )
    }

    private func subTopicExercisesCountForUi(
        belt: Belt,
        topicTitle: String,
        subTopicTitle: String
    ) -> Int {

        let cleanTopicTitle =
            topicTitle
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let cleanSubTopicTitle =
            subTopicTitle
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let topLevelSubTopics =
            ContentRepo.shared
                .getSubTopicsFor(
                    belt:
                        belt,
                    topicTitle:
                        cleanTopicTitle
                )

        guard
            let matchingSubTopic =
                topLevelSubTopics
                    .first(
                        where: {
                            $0.title
                                .trimmingCharacters(
                                    in:
                                        .whitespacesAndNewlines
                                )
                            ==
                            cleanSubTopicTitle
                        }
                    )
        else {

            return 0
        }

        /*
         * BFS עם cursor.
         *
         * אין removeFirst(),
         * ולכן אין הזזת מערך בכל איטרציה.
         */
        var pendingSubTopics = [
            matchingSubTopic
        ]

        var cursor = 0
        var totalCount = 0

        while cursor <
            pendingSubTopics.count {

            let current =
                pendingSubTopics[
                    cursor
                ]

            totalCount +=
                current.items.count

            pendingSubTopics.append(
                contentsOf:
                    current.subTopics
            )

            cursor += 1
        }

        return totalCount
    }

    @ViewBuilder

    private func subTopicButton(
        topicTitle: String,
        subTitle: String
    ) -> some View {

        let itemCount =
            subTopicExercisesCountForUi(
                belt:
                    selectedBelt,
                topicTitle:
                    topicTitle,
                subTopicTitle:
                    subTitle
            )

        let subTopicGeneralNote =
            ContentRepo.shared
                .getSubTopicGeneralNote(
                    belt:
                        selectedBelt,
                    topicTitle:
                        topicTitle,
                    subTopicTitle:
                        subTitle
                )?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        let openSubTopic = {

            if
                isTopicLocked(
                    topicTitle
                )
                ||
                isTopicLocked(
                    subTitle
                ) {

                nav.push(
                    .subscriptionPlans
                )

            } else {

                selectedExerciseRoute =
                    BeltTopicExerciseRoute(
                        belt:
                            selectedBelt,
                        topicTitle:
                            topicTitle,
                        forcedSubTopicTitle:
                            subTitle
                    )
            }
        }

        HStack(
            spacing:
                8
        ) {

            if isEnglish {

                VStack(
                    alignment:
                        .leading,
                    spacing:
                        2
                ) {

                    subTopicTitleLine(
                        subTitle
                    )

                    Text(
                        exercisesCountText(
                            itemCount
                        )
                    )
                    .kmiTypography(
                        .caption
                    )
                    .fontWeight(
                        .bold
                    )
                    .foregroundStyle(
                        readableBeltAccent
                    )
                    .frame(
                        maxWidth:
                            .infinity,
                        alignment:
                            .leading
                    )
                    .multilineTextAlignment(
                        .leading
                    )
                }

                if !subTopicGeneralNote.isEmpty {

                    generalNoteButton(
                        title:
                            subTitle,
                        text:
                            subTopicGeneralNote
                    )
                }

                Image(
                    systemName:
                        "chevron.right"
                )
                .kmiIconSize(
                    15
                )
                .foregroundStyle(
                    readableBeltAccent
                )

            } else {

                Image(
                    systemName:
                        "chevron.left"
                )
                .kmiIconSize(
                    15
                )
                .foregroundStyle(
                    readableBeltAccent
                )

                if !subTopicGeneralNote.isEmpty {

                    generalNoteButton(
                        title:
                            subTitle,
                        text:
                            subTopicGeneralNote
                    )
                }

                VStack(
                    alignment:
                        .trailing,
                    spacing:
                        2
                ) {

                    subTopicTitleLine(
                        subTitle
                    )

                    Text(
                        exercisesCountText(
                            itemCount
                        )
                    )
                    .kmiTypography(
                        .caption
                    )
                    .fontWeight(
                        .bold
                    )
                    .foregroundStyle(
                        readableBeltAccent
                    )
                    .frame(
                        maxWidth:
                            .infinity,
                        alignment:
                            .trailing
                    )
                    .multilineTextAlignment(
                        .trailing
                    )
                }
            }
        }
        .environment(
            \.layoutDirection,
            .leftToRight
        )
        .padding(
            .horizontal,
            8
        )
        .padding(
            .vertical,
            5
        )
        .frame(
            minHeight:
                48
        )
        .background(
            Color.clear
        )
        .contentShape(
            RoundedRectangle(
                cornerRadius:
                    12,
                style:
                    .continuous
            )
        )
        .onTapGesture {

            openSubTopic()
        }
    }

    @ViewBuilder

    private func subTopicTitleLine(
        _ subTitle: String
    ) -> some View {

        HStack(
            spacing:
                6
        ) {

            if isEnglish {

                Text(
                    uiTopicTitle(
                        subTitle
                    )
                )
                .kmiTypography(
                    .cardTitle
                )
                .foregroundStyle(
                    byBeltTitleColor
                )
                .lineLimit(
                    2
                )
                .minimumScaleFactor(
                    0.72
                )

                if isTopicLocked(
                    subTitle
                ) {

                    Image(
                        systemName:
                            "lock.fill"
                    )
                    .kmiIconSize(
                        12
                    )
                    .foregroundStyle(
                        KmiAppTheme
                            .warning(
                                for:
                                    colorScheme
                            )
                    )
                }

                Spacer(
                    minLength:
                        0
                )

            } else {

                Spacer(
                    minLength:
                        0
                )

                if isTopicLocked(
                    subTitle
                ) {

                    Image(
                        systemName:
                            "lock.fill"
                    )
                    .kmiIconSize(
                        12
                    )
                    .foregroundStyle(
                        KmiAppTheme
                            .warning(
                                for:
                                    colorScheme
                            )
                    )
                }

                Text(
                    uiTopicTitle(
                        subTitle
                    )
                )
                .kmiTypography(
                    .cardTitle
                )
                .foregroundStyle(
                    byBeltTitleColor
                )
                .lineLimit(
                    2
                )
                .minimumScaleFactor(
                    0.72
                )
            }
        }
        .environment(
            \.layoutDirection,
            .leftToRight
        )
        .frame(
            maxWidth:
                .infinity,
            alignment:
                isEnglish
                    ? .leading
                    : .trailing
        )
    }

    @ViewBuilder

    private func fullTopicButton(
        topicTitle: String,
        accent: Color
    ) -> some View {

        Button {

            if isTopicLocked(
                topicTitle
            ) {

                nav.push(
                    .subscriptionPlans
                )

            } else {

                selectedExerciseRoute =
                    BeltTopicExerciseRoute(
                        belt:
                            selectedBelt,
                        topicTitle:
                            topicTitle
                    )
            }

        } label: {

            HStack(
                spacing:
                    8
            ) {

                if isEnglish {

                    Image(
                        systemName:
                            "list.bullet.rectangle.fill"
                    )
                    .kmiIconSize(
                        15
                    )
                    .foregroundStyle(
                        accent
                    )

                    Text(
                        "Full topic"
                    )
                    .kmiTypography(
                        .cardTitle
                    )
                    .foregroundStyle(
                        byBeltTitleColor
                    )

                    if isTopicLocked(
                        topicTitle
                    ) {

                        Image(
                            systemName:
                                "lock.fill"
                        )
                        .kmiIconSize(
                            12
                        )
                        .foregroundStyle(
                            KmiAppTheme
                                .warning(
                                    for:
                                        colorScheme
                                )
                        )
                    }

                    Spacer(
                        minLength:
                            0
                    )

                } else {

                    Spacer(
                        minLength:
                            0
                    )

                    if isTopicLocked(
                        topicTitle
                    ) {

                        Image(
                            systemName:
                                "lock.fill"
                        )
                        .kmiIconSize(
                            12
                        )
                        .foregroundStyle(
                            KmiAppTheme
                                .warning(
                                    for:
                                        colorScheme
                                )
                        )
                    }

                    Text(
                        "כל הנושא"
                    )
                    .kmiTypography(
                        .cardTitle
                    )
                    .foregroundStyle(
                        byBeltTitleColor
                    )

                    Image(
                        systemName:
                            "list.bullet.rectangle.fill"
                    )
                    .kmiIconSize(
                        15
                    )
                    .foregroundStyle(
                        accent
                    )
                }
            }
            .environment(
                \.layoutDirection,
                .leftToRight
            )
            .padding(
                .horizontal,
                8
            )
            .padding(
                .vertical,
                5
            )
            .frame(
                minHeight:
                    48
            )
            .contentShape(
                Rectangle()
            )
        }
        .buttonStyle(
            .plain
        )
    }
   
    private var beltModeTabs: some View {

        HStack(spacing: 0) {

            Button {

                withAnimation(
                    .spring(
                        response: 0.24,
                        dampingFraction: 0.92
                    )
                ) {
                    quickMenuOpen = false
                }

                /*
                 * חשוב:
                 * ניווט אחד בלבד.
                 *
                 * לא דוחפים קודם By Belt
                 * ואז By Topic.
                 */
                nav.push(
                    .beltQuestionsByTopic(
                        belt: selectedBelt
                    )
                )

            } label: {

                beltModeTabButton(
                    title:
                        isEnglish
                            ? "By Topic"
                            : "לפי נושא",
                    selected:
                        false,
                    leadingInset:
                        38,
                    trailingInset:
                        0
                )
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(
                    KmiAppTheme
                        .sectionHeaderContentColor
                        .opacity(0.65)
                )
                .frame(
                    width: 1,
                    height: 24
                )
                .offset(y: -4)

            Button {
                // כבר נמצאים במסך By Belt.
            } label: {

                beltModeTabButton(
                    title:
                        isEnglish
                            ? "By Belt"
                            : "לפי חגורה",
                    selected:
                        true,
                    leadingInset:
                        0,
                    trailingInset:
                        38
                )
            }
            .buttonStyle(.plain)
        }
        .environment(
            \.layoutDirection,
            .leftToRight
        )
        .frame(
            maxWidth: .infinity
        )
        .frame(
            height: 48
        )
        .background(
            KmiAppTheme
                .sectionHeaderBrush
        )
        .overlay {

            Rectangle()
                .stroke(
                    KmiAppTheme
                        .sectionHeaderContentColor
                        .opacity(0.34),
                    lineWidth: 1
                )
        }
        .padding(
            .bottom,
            6
        )
    }

    private func beltModeTabButton(
        title: String,
        selected: Bool,
        leadingInset: CGFloat,
        trailingInset: CGFloat
    ) -> some View {

        ZStack(
            alignment: .bottom
        ) {

            Text(title)
                .kmiTypography(
                    .action
                )
                .foregroundStyle(
                    KmiAppTheme
                        .sectionHeaderContentColor
                        .opacity(
                            selected
                                ? 1.0
                                : 0.82
                        )
                )
                .lineLimit(1)
                .minimumScaleFactor(
                    0.70
                )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
                .padding(
                    .leading,
                    leadingInset
                )
                .padding(
                    .trailing,
                    trailingInset
                )

            if selected {

                Rectangle()
                    .fill(
                        KmiAppTheme
                            .sectionHeaderContentColor
                    )
                    .frame(
                        maxWidth: .infinity
                    )
                    .frame(
                        height: 3
                    )
                    .padding(
                        .horizontal,
                        58
                    )
                    .padding(
                        .bottom,
                        4
                    )
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .contentShape(
            Rectangle()
        )
    }
    
    @ViewBuilder
    private var byBeltContent: some View {

        let rowMinHeight: CGFloat =
            54

        let visibleRows: CGFloat =
            6

        let listHeight: CGFloat =
            rowMinHeight
            * visibleRows
            + 10

        let fabSize: CGFloat =
            120

        let fabClearance: CGFloat =
            fabSize * 0.34

        VStack(spacing: 0) {

            VStack(spacing: 0) {

                Text(
                    isEnglish
                        ? "Topics in Belt"
                        : "נושאים בחגורה"
                )
                .kmiTypography(
                    .sectionTitle
                )
                .foregroundStyle(
                    byBeltTitleColor
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .center
                )
                .multilineTextAlignment(
                    .center
                )
                .lineLimit(1)
                .padding(
                    .horizontal,
                    14
                )

                Spacer()
                    .frame(height: 2)

                if beltTopicsUi.isEmpty {

                    Text(
                        isEnglish
                            ? "No topics to display"
                            : "אין נושאים להצגה"
                    )
                    .kmiTypography(.body)
                    .foregroundStyle(
                        byBeltRowSubColor
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: .center
                    )
                    .multilineTextAlignment(
                        .center
                    )
                    .padding(20)

                } else {

                    ScrollViewReader { proxy in

                        ScrollView(
                            showsIndicators: false
                        ) {

                            VStack(spacing: 0) {

                                Color.clear
                                    .frame(height: 0)
                                    .id(
                                        "topics_top_anchor"
                                    )

                                ForEach(
                                    Array(
                                        beltTopicsUi.enumerated()
                                    ),
                                    id: \.element.id
                                ) { index, entry in

                                    let topicTitle =
                                        entry.title
                                            .trimmingCharacters(
                                                in:
                                                    .whitespacesAndNewlines
                                            )

                                    let subTitles =
                                        entry.subTitles

                                    let hasSubs =
                                        !subTitles.isEmpty

                                    let isExpanded =
                                        expandedTopic ==
                                        topicTitle

                                    let locked =
                                        isTopicLocked(
                                            topicTitle
                                        )

                                    let accent =
                                        topicAccentColor(
                                            topicTitle
                                        )

                                    topicRowCard(
                                        entry:
                                            entry,
                                        topicTitle:
                                            topicTitle,
                                        subTitles:
                                            subTitles,
                                        hasSubs:
                                            hasSubs,
                                        isExpanded:
                                            isExpanded,
                                        locked:
                                            locked,
                                        accent:
                                            accent,
                                        rowMinHeight:
                                            rowMinHeight
                                    )

                                    if index !=
                                        beltTopicsUi.count - 1 {

                                        Divider()
                                            .overlay(
                                                byBeltCardBorderColor
                                            )
                                            .padding(
                                                .horizontal,
                                                18
                                            )
                                    }
                                }
                            }
                        }
                        .frame(
                            height:
                                listHeight
                        )
                        .onChange(
                            of: selectedBelt
                        ) { _, _ in

                            proxy.scrollTo(
                                "topics_top_anchor",
                                anchor: .top
                            )
                        }
                    }
                }
            }
            .padding(
                .vertical,
                6
            )
            .background(

                RoundedRectangle(
                    cornerRadius: 24,
                    style: .continuous
                )
                .fill(
                    byBeltCardSurfaceColor
                )
            )
            .overlay {

                RoundedRectangle(
                    cornerRadius: 24,
                    style: .continuous
                )
                .stroke(
                    byBeltCardBorderColor,
                    lineWidth: 1
                )
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 24,
                    style: .continuous
                )
            )
            .padding(
                .horizontal,
                6
            )
            .padding(
                .bottom,
                fabClearance + 2
            )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .top
        )
        .zIndex(1)
        .allowsHitTesting(
            !quickMenuOpen
        )
    }
    
    // MARK: - Belt Palette + Wheel4
    // ✅ Rename to avoid "Invalid redeclaration of BeltPalette"
    private enum BeltPaletteByBeltScreen {
        static let white  = Color(red: 0.92, green: 0.92, blue: 0.92)
        static let yellow = Color(red: 0.98, green: 0.85, blue: 0.18)
        static let orange = Color(red: 0.98, green: 0.64, blue: 0.15)
        static let green  = Color(red: 0.18, green: 0.80, blue: 0.44)
        static let blue   = Color(red: 0.18, green: 0.52, blue: 0.95)
        static let brown  = Color(red: 0.55, green: 0.34, blue: 0.23)
        static let black  = Color(red: 0.10, green: 0.10, blue: 0.12)
        
        static func color(for belt: Belt) -> Color {
            switch belt {
            case .white:  return white
            case .yellow: return yellow
            case .orange: return orange
            case .green:  return green
            case .blue:   return blue
            case .brown:  return brown
            case .black:  return black
            default:      return orange
            }
        }
        
        static var ringColors: [Color] {
            [white, yellow, orange, green, blue, brown, black]
        }
    }
    
    
    // MARK: - Subject pill
    // Moved to BeltQuestionsSharedComponents.swift
    
    // MARK: - Floating quick menu overlay
    
    private struct BeltQuickMenuOverlay: View {
        @Binding var isPresented: Bool
        
        let isEnglish: Bool
        let isByTopicMode: Bool
        let beltTitle: String
        let beltFill: Color
        
        let onWeakPoints: () -> Void
        let onAllLists: () -> Void
        let onPractice: () -> Void
        let onSummary: () -> Void
        let onVoice: () -> Void
        
        let onFinalExam: () -> Void
        let onInternalExam: (() -> Void)?
        
        private var isOpen: Bool { isPresented }
        
        private func isMenuItemLocked(_ title: String) -> Bool {
            LockedContentPolicy.shouldShowLock(
                accessMode: LockedContentPolicy.currentAccessMode(),
                title: title
            )
        }
        
        var body: some View {
            ZStack(alignment: .bottom) {
                
                if isOpen {
                    Color.black.opacity(isByTopicMode ? 0.16 : 0.08)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            close()
                        }
                        .transition(.opacity)
                        .zIndex(1)
                }
                
                if isByTopicMode {
                    byTopicBottomBar
                        .zIndex(3)
                } else {
                    byBeltAndroidStyleMenu
                        .zIndex(3)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .environment(\.layoutDirection, .leftToRight)
            .animation(.spring(response: 0.28, dampingFraction: 0.90), value: isPresented)
        }
        
        // MARK: - By Belt — Android style
        
        private var byBeltAndroidStyleMenu: some View {
            GeometryReader { geo in
                let safeBottom = geo.safeAreaInsets.bottom
                let isCompactHeight = geo.size.height < 760
                
                let popupBottom: CGFloat = {
                    let base = isCompactHeight ? geo.size.height * 0.245 : geo.size.height * 0.258
                    return max(190 + safeBottom, min(226 + safeBottom, base))
                }()
                
                let fabBottom: CGFloat = {
                    let base = isCompactHeight ? geo.size.height * 0.126 : geo.size.height * 0.130
                    return max(94 + safeBottom, min(112 + safeBottom, base))
                }()
                
                ZStack {
                    if isOpen {
                        androidPopupCard
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .padding(.horizontal, isCompactHeight ? 58 : 54)
                            .padding(.bottom, popupBottom)
                            .transition(
                                .scale(scale: 0.94, anchor: .bottom)
                                .combined(with: .opacity)
                            )
                    }

                    // באנדרואיד אין כפתור סגירה ירוק נפרד בצד בזמן שהתפריט פתוח.
                    // כשהתפריט סגור מציגים רק את כפתור הפתיחה.
                    if !isOpen {
                        let fabTrailing = max(34, min(44, geo.size.width * 0.105))
                        
                        byBeltFabButton
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(.trailing, fabTrailing)
                            .padding(.bottom, fabBottom)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        
        private var androidPopupCard: some View {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Button {
                        close()
                    } label: {
                        Image(systemName: "xmark")
                            .kmiFont(
                                size: 13,
                                weight: .bold
                            )
                            .foregroundStyle(beltFill.opacity(0.86))
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(beltFill.opacity(0.10))
                            )
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Spacer(minLength: 0)
                    
                    Text(
                        isEnglish
                            ? "Quick Menu"
                            : "תפריט מהיר"
                    )
                    .kmiFont(
                        size: 19.5,
                        weight: .black
                    )
                    .foregroundStyle(
                        beltFill.opacity(0.92)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                }
                .padding(.horizontal, 15)
                .padding(.top, 9)
                .padding(.bottom, 2)
                
                VStack(spacing: 0) {
                    androidMenuRow(
                        title: isEnglish ? "Weak Points" : "נקודות תורפה",
                        systemImage: "exclamationmark.triangle",
                        showsLock: isMenuItemLocked(isEnglish ? "Weak Points" : "נקודות תורפה"),
                        action: onWeakPoints
                    )
                    
                    androidDivider
                    
                    androidMenuRow(
                        title: isEnglish ? "All Lists" : "כל הרשימות",
                        systemImage: "list.bullet",
                        showsLock: isMenuItemLocked(isEnglish ? "All Lists" : "כל הרשימות"),
                        action: onAllLists
                    )
                    
                    androidDivider
                    
                    androidMenuRow(
                        title: isEnglish ? "Practice" : "תרגול",
                        systemImage: "figure.walk",
                        showsLock: isMenuItemLocked(isEnglish ? "Practice" : "תרגול"),
                        action: onPractice
                    )
                    
                    androidDivider
                    
                    androidMenuRow(
                        title: isEnglish ? "Summary" : "מסך סיכום",
                        systemImage: "doc.text",
                        showsLock: isMenuItemLocked(isEnglish ? "Summary" : "מסך סיכום"),
                        action: onSummary
                    )
                    
                    androidDivider
                    
                    androidMenuRow(
                        title: isEnglish ? "Voice Assistant" : "עוזר קולי",
                        systemImage: "mic",
                        showsLock: false,
                        action: onVoice
                    )
                    
                    androidDivider
                    
                    androidMenuRow(
                        title: isEnglish ? "Final Exam" : "מבחן מסכם",
                        systemImage: "checkmark.seal",
                        showsLock: isMenuItemLocked(isEnglish ? "Final Exam" : "מבחן מסכם"),
                        action: onFinalExam
                    )
                    
                    if let onInternalExam {
                        androidDivider
                        
                        androidMenuRow(
                            title: isEnglish ? "Internal Exam" : "מבחן פנימי",
                            systemImage: "person.badge.key",
                            showsLock: false,
                            action: onInternalExam
                        )
                    }
                }
                .padding(.horizontal, 11)
                .padding(.bottom, 10)
            }
            .frame(maxWidth: 258)
            .background(
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(red: 0.98, green: 0.98, blue: 0.96),
                                Color.white
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .stroke(beltFill.opacity(0.42), lineWidth: 1.05)
            )
            .shadow(color: Color.black.opacity(0.20), radius: 14, x: 0, y: 8)
        }
        
        private var androidDivider: some View {
            Rectangle()
                .fill(beltFill.opacity(0.16))
                .frame(height: 1)
                .padding(.leading, 12)
                .padding(.trailing, 12)
        }
        
        private func androidMenuRow(
            title: String,
            systemImage: String,
            showsLock: Bool,
            action: @escaping () -> Void
        ) -> some View {
            Button {
                closeThen(action)
            } label: {
                HStack(spacing: 9) {
                    if isEnglish {
                        ZStack {
                            Circle()
                                .fill(beltFill.opacity(0.12))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(beltFill.opacity(0.28), lineWidth: 1)
                                )

                            Image(systemName: systemImage)
                                .kmiFont(
                                    size: 12.5,
                                    weight: .bold
                                )
                                .foregroundStyle(
                                    beltFill.opacity(0.86)
                                )
                        }

                        Text(title)
                            .kmiFont(
                                size: 18.5,
                                weight: .black
                            )
                            .foregroundStyle(
                                beltFill.opacity(0.92)
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.64)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )

                        Image(
                            systemName:
                                showsLock
                                ? "lock.fill"
                                : "chevron.right"
                        )
                        .kmiFont(
                            size:
                                showsLock
                                ? 13
                                : 12,
                            weight: .bold
                        )
                        .foregroundStyle(
                            beltFill.opacity(0.88)
                        )
                        .frame(width: 24)
                    } else {
                        Image(
                            systemName:
                                showsLock
                                ? "lock.fill"
                                : "chevron.left"
                        )
                        .kmiFont(
                            size:
                                showsLock
                                ? 13
                                : 12,
                            weight: .bold
                        )
                        .foregroundStyle(
                            beltFill.opacity(0.88)
                        )
                        .frame(width: 24)

                        Text(title)
                            .kmiFont(
                                size: 18.5,
                                weight: .black
                            )
                            .foregroundStyle(
                                beltFill.opacity(0.92)
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.64)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .trailing
                            )

                        ZStack {
                            Circle()
                                .fill(beltFill.opacity(0.12))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(beltFill.opacity(0.28), lineWidth: 1)
                                )

                            Image(systemName: systemImage)
                                .kmiFont(
                                    size: 12.5,
                                    weight: .bold
                                )
                                .foregroundStyle(
                                    beltFill.opacity(0.86)
                                )
                        }
                    }
                }
                .environment(
                    \.layoutDirection,
                    .leftToRight
                )
                .frame(minHeight: 43)
                .padding(.vertical, 2)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        
        private var byBeltFabButton: some View {
            Button {
                toggle()
            } label: {
                Image(
                    systemName:
                        isOpen
                        ? "xmark"
                        : "line.3.horizontal"
                )
                .kmiFont(
                    size: 21,
                    weight: .black
                )
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        beltFill.opacity(0.98),
                                        beltFill.opacity(0.78)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.74), lineWidth: 2.5)
                    )
                    .overlay(
                        Circle()
                            .stroke(beltFill.opacity(0.34), lineWidth: 4.5)
                            .blur(radius: 0.30)
                    )
                    .shadow(color: beltFill.opacity(0.32), radius: 8, x: 0, y: 3)
                    .shadow(color: Color.black.opacity(0.16), radius: 6, x: 0, y: 3)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        
        // MARK: - By Topic — bottom bar
        
        private var byTopicBottomBar: some View {
            GeometryReader { geo in
                let safeBottom = geo.safeAreaInsets.bottom
                let isCompactHeight = geo.size.height < 760
                let bottomPadding = max(72 + safeBottom, min(92 + safeBottom, geo.size.height * (isCompactHeight ? 0.095 : 0.105)))
                
                VStack(spacing: 12) {
                    
                    if isOpen {
                        VStack(spacing: 10) {
                            androidMenuRow(
                                title: isEnglish ? "Weak Points" : "נקודות תורפה",
                                systemImage: "exclamationmark.triangle",
                                showsLock: isMenuItemLocked(isEnglish ? "Weak Points" : "נקודות תורפה"),
                                action: onWeakPoints
                            )
                            
                            androidMenuRow(
                                title: isEnglish ? "Practice" : "תרגול",
                                systemImage: "figure.walk",
                                showsLock: isMenuItemLocked(isEnglish ? "Practice" : "תרגול"),
                                action: onPractice
                            )
                            
                            androidMenuRow(
                                title: isEnglish ? "Voice Assistant" : "עוזר קולי",
                                systemImage: "mic",
                                showsLock: false,
                                action: onVoice
                            )
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.white.opacity(0.96))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(beltFill.opacity(0.22), lineWidth: 1)
                        )
                        .padding(.horizontal, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    Button {
                        toggle()
                    } label: {
                        HStack(spacing: 10) {
                            Image(
                                systemName:
                                    isOpen
                                    ? "xmark"
                                    : "line.3.horizontal"
                            )
                            .kmiFont(
                                size: 17,
                                weight: .black
                            )
                            
                            Text(
                                isEnglish
                                    ? "Quick View"
                                    : "מבט מהיר"
                            )
                            .kmiFont(
                                size: 17,
                                weight: .black
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.70)
                        }
                        .foregroundStyle(beltFill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            beltFill.opacity(0.10),
                                            Color.white.opacity(0.98),
                                            beltFill.opacity(0.05)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(beltFill.opacity(0.22), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 18)
                    .padding(.bottom, bottomPadding)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
            }
        }
        
        // MARK: - Actions
        
        private func toggle() {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.90)) {
                isPresented.toggle()
            }
        }
        
        private func closeThen(_ action: @escaping () -> Void) {
            close()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                action()
            }
        }
        
        private func close() {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.95)) {
                isPresented = false
            }
        }
    }
    
    // MARK: - Belt topic sub-topics
    // Moved to BeltTopicSubTopicsView.swift
    
    // MARK: - Linked topic sub-topics
    // Moved to LinkedTopicSubTopicsView.swift
    
    // MARK: - Belt topic exercises
    // Moved to BeltTopicExercisesView.swift
    
    // MARK: - Belt topic exercise row
    // Moved to KmiExerciseMarkRow in BeltQuestionsSharedComponents.swift
    
    // MARK: - Belt topic mark button
    // Moved to KmiMarkCircleButton in BeltQuestionsSharedComponents.swift
    
    // MARK: - Subject sub-topics
    // Moved to SubjectSubTopicsView.swift
    
    // MARK: - Subject exercises
    // Moved to SubjectExercisesView.swift
    
    // MARK: - Subject exercise row
    // Moved to KmiExerciseMarkRow in BeltQuestionsSharedComponents.swift
    
    // MARK: - Subject mark button
    // Moved to KmiMarkCircleButton in BeltQuestionsSharedComponents.swift
    
    private struct ExerciseSelection: Identifiable, Hashable {
        let belt: Belt
        let topicTitle: String
        let item: String
        
        var id: String {
            "\(belt.id)|\(topicTitle)|\(item)"
        }
        
        private static func parseBelt(_ raw: String) -> Belt? {
            switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "white", "לבן", "לבנה":
                return .white
            case "yellow", "צהוב", "צהובה":
                return .yellow
            case "orange", "כתום", "כתומה":
                return .orange
            case "green", "ירוק", "ירוקה":
                return .green
            case "blue", "כחול", "כחולה":
                return .blue
            case "brown", "חום", "חומה":
                return .brown
            case "black", "שחור", "שחורה":
                return .black
            default:
                return nil
            }
        }
        
        static func fromSearchKey(_ key: String) -> ExerciseSelection? {
            let parts = key.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 3 else { return nil }
            guard let belt = parseBelt(parts[0]) else { return nil }
            
            return ExerciseSelection(
                belt: belt,
                topicTitle: parts[1],
                item: parts[2]
            )
        }
    }
}

private struct BeltScreenQuickMenuItem: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let action: () -> Void

    init(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) {
        self.id = title + systemImage
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }
}

private struct BeltScreenSideQuickMenuOverlay: View {

    @Binding
    var isPresented: Bool

    let isEnglish: Bool
    let accent: Color
    let items: [BeltScreenQuickMenuItem]
    let onClose: () -> Void

    var body: some View {

        GeometryReader { geometry in

            let triggerWidth: CGFloat =
                38

            let triggerHeight: CGFloat =
                72

            let panelGap: CGFloat =
                8

            let panelWidth: CGFloat =
                min(
                    248,
                    max(
                        220,
                        geometry.size.width
                            - triggerWidth
                            - 24
                    )
                )

            /*
             * Android parity:
             * הטריגר יושב קרוב לתחתית,
             * מעל אזור החגורות.
             */
            let bottomSpacing: CGFloat =
                72

            let triggerTop: CGFloat =
                max(
                    12,
                    geometry.size.height
                        - geometry.safeAreaInsets.bottom
                        - bottomSpacing
                        - triggerHeight
                )

            let startIsLeft =
                isEnglish

            let triggerX: CGFloat =
                startIsLeft
                    ? 0
                    : geometry.size.width
                        - triggerWidth

            let panelX: CGFloat =
                startIsLeft
                    ? triggerWidth
                        + panelGap
                    : geometry.size.width
                        - triggerWidth
                        - panelGap
                        - panelWidth

            /*
             * הפאנל נפתח מעל הטריגר,
             * כדי שלא ייחתך בתחתית המסך.
             */
            let panelY: CGFloat =
                max(
                    12,
                    triggerTop
                        - 220
                )

            ZStack(
                alignment:
                    .topLeading
            ) {

                if isPresented {

                    BeltScreenQuickMenuPanel(
                        title:
                            isEnglish
                                ? "Quick Menu"
                                : "תפריט מהיר",
                        isEnglish:
                            isEnglish,
                        accent:
                            accent,
                        items:
                            items,
                        onClose: {

                            withAnimation(
                                .spring(
                                    response:
                                        0.28,
                                    dampingFraction:
                                        0.86
                                )
                            ) {

                                isPresented =
                                    false
                            }

                            onClose()
                        }
                    )
                    .frame(
                        width:
                            panelWidth
                    )
                    .offset(
                        x:
                            panelX,
                        y:
                            panelY
                    )
                    .transition(
                        .move(
                            edge:
                                startIsLeft
                                    ? .leading
                                    : .trailing
                        )
                        .combined(
                            with:
                                .opacity
                        )
                    )
                    .zIndex(
                        51
                    )
                }

                Button {

                    withAnimation(
                        .spring(
                            response:
                                0.28,
                            dampingFraction:
                                0.86
                        )
                    ) {

                        isPresented
                            .toggle()
                    }

                } label: {

                    BeltScreenSideQuickFab(
                        accent:
                            accent,
                        attachedToLeftEdge:
                            startIsLeft
                    )
                }
                .buttonStyle(
                    .plain
                )
                .frame(
                    width:
                        triggerWidth,
                    height:
                        triggerHeight
                )
                .offset(
                    x:
                        triggerX,
                    y:
                        triggerTop
                )
                .zIndex(
                    52
                )
            }
            .frame(
                width:
                    geometry.size.width,
                height:
                    geometry.size.height,
                alignment:
                    .topLeading
            )
            .environment(
                \.layoutDirection,
                .leftToRight
            )
        }
        .ignoresSafeArea(
            .keyboard,
            edges:
                .bottom
        )
    }
}

private struct BeltScreenSideQuickFab: View {

    @Environment(\.colorScheme)
    private var colorScheme

    let accent: Color
    let attachedToLeftEdge: Bool

    private var triggerShape:
        UnevenRoundedRectangle {

        UnevenRoundedRectangle(
            topLeadingRadius:
                attachedToLeftEdge
                    ? 0
                    : 18,
            bottomLeadingRadius:
                attachedToLeftEdge
                    ? 0
                    : 18,
            bottomTrailingRadius:
                attachedToLeftEdge
                    ? 18
                    : 0,
            topTrailingRadius:
                attachedToLeftEdge
                    ? 18
                    : 0,
            style:
                .continuous
        )
    }

    private var iconColor: Color {

        let uiColor =
            UIColor(accent)

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getRed(
            &red,
            green: &green,
            blue: &blue,
            alpha: &alpha
        ) else {
            return .white
        }

        let luminance =
            0.2126 * red
            + 0.7152 * green
            + 0.0722 * blue

        return luminance < 0.55
            ? .white
            : .black
    }

    var body: some View {

        ZStack {

            triggerShape
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(
                                0.84
                            ),
                            accent,
                            accent.opacity(
                                0.88
                            )
                        ],
                        startPoint:
                            .top,
                        endPoint:
                            .bottom
                    )
                )

            triggerShape
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white
                                .opacity(
                                    0.22
                                ),
                            Color.clear
                        ],
                        startPoint:
                            .leading,
                        endPoint:
                            .trailing
                    )
                )

            triggerShape
                .stroke(
                    KmiAppTheme
                        .outlineVariant(
                            for:
                                colorScheme
                        )
                        .opacity(
                            0.55
                        ),
                    lineWidth:
                        0.75
                )

            Image(
                systemName:
                    "line.3.horizontal"
            )
            .kmiIconSize(
                26
            )
            .foregroundStyle(
                iconColor
            )
        }
        .frame(
            width:
                38,
            height:
                72
        )
    }
}

private struct BeltScreenQuickMenuPanel: View {
    
    @Environment(\.colorScheme)
    private var colorScheme
    
    let title: String
    let isEnglish: Bool
    let accent: Color
    let items: [BeltScreenQuickMenuItem]
    let onClose: () -> Void

    private var stackAlignment: HorizontalAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    var body: some View {
        VStack(alignment: stackAlignment, spacing: 0) {
            HStack(spacing: 8) {
                Text(title)
                    .kmiTypography(
                        .cardTitle
                    )
                    .foregroundStyle(
                        accent.opacity(0.92)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Spacer(minLength: 0)

                Button(action: onClose) {
                    Image(
                        systemName:
                            "xmark"
                    )
                    .kmiIconSize(
                        12
                    )
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 8)

            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                BeltScreenQuickMenuRow(
                    title: item.title,
                    systemImage: item.systemImage,
                    isEnglish: isEnglish,
                    accent: accent,
                    action: {
                        onClose()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            item.action()
                        }
                    }
                )
                
                if index != items.count - 1 {
                    Rectangle()
                        .fill(accent.opacity(0.18))
                        .frame(height: 0.8)
                        .padding(.horizontal, 10)
                }
            }
        }
        .padding(.bottom, 7)
        .frame(width: 196)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(red: 0.97, green: 0.98, blue: 0.97))

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.08),
                                Color.white.opacity(0.04),
                                accent.opacity(0.06)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(accent.opacity(0.24), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 14, x: 0, y: 8)
    }
}

private struct BeltScreenQuickMenuRow: View {
    let title: String
    let systemImage: String
    let isEnglish: Bool
    let accent: Color
    let action: () -> Void
    
    private var isLocked: Bool {
        LockedContentPolicy.shouldShowLock(
            accessMode: LockedContentPolicy.currentAccessMode(),
            title: title
        )
    }
    
    private var rowDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }
    
    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }
    
    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if isEnglish {
                    menuIcon
                    
                    Text(title)
                        .kmiFont(
                            size: 11.5,
                            weight: .heavy
                        )
                        .foregroundStyle(
                            Color(
                                red: 0.04,
                                green: 0.19,
                                blue: 0.12
                            )
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                        .multilineTextAlignment(.leading)
                    
                    trailingIcon
                } else {
                    trailingIcon
                    
                    Text(title)
                        .kmiFont(
                            size: 11.5,
                            weight: .heavy
                        )
                        .foregroundStyle(
                            Color(
                                red: 0.04,
                                green: 0.19,
                                blue: 0.12
                            )
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                        .frame(
                            maxWidth: .infinity,
                            alignment: .trailing
                        )
                        .multilineTextAlignment(.trailing)
                    
                    menuIcon
                }
            }
            .environment(
                \.layoutDirection,
                .leftToRight
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var menuIcon: some View {
        Image(systemName: systemImage)
            .kmiFont(
                size: 12,
                weight: .bold
            )
            .foregroundStyle(
                accent.opacity(0.92)
            )
            .frame(
                minWidth: 19,
                minHeight: 19
            )
    }
    
    private var trailingIcon: some View {
        Image(
            systemName:
                isLocked
                ? "lock.fill"
                : (
                    isEnglish
                    ? "chevron.right"
                    : "chevron.left"
                )
        )
        .kmiFont(
            size:
                isLocked
                ? 11.5
                : 10.5,
            weight: .heavy
        )
        .foregroundStyle(
            isLocked
                ? Color.orange.opacity(0.92)
                : accent.opacity(0.70)
        )
        .frame(
            minWidth: 18,
            minHeight: 18
        )
    }
}

private struct PulsingLockBadge: View {

    @Environment(\.colorScheme)
    private var colorScheme

    @State
    private var pulse = false

    var body: some View {

        Image(
            systemName:
                "lock.fill"
        )
        .resizable()
        .scaledToFit()
        .foregroundStyle(
            KmiAppTheme
                .tertiary(
                    for: colorScheme
                )
        )
        .kmiIconSize(16)
        .scaleEffect(
            pulse
                ? 1.00
                : 0.90
        )
        .onAppear {

            withAnimation(
                .linear(
                    duration: 0.90
                )
                .repeatForever(
                    autoreverses: true
                )
            ) {
                pulse = true
            }
        }
    }
}
