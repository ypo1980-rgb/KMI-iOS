import SwiftUI
import UIKit
import Combine
import Shared

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

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

            return KmiAppTheme.warning(
                for: colorScheme
            )

        default:

            return KmiBeltPalette.color(
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
        KmiExerciseCountProvider.countText(
            stats: KmiExerciseCountStats(
                subTopicCount: 0,
                exerciseCount: count
            ),
            isEnglish: isEnglish
        )
    }
    
    private func subTopicsAndExercisesText(
        subTopicsCount: Int,
        exercisesCount: Int
    ) -> String {
        KmiExerciseCountProvider.combinedCountText(
            stats: KmiExerciseCountStats(
                subTopicCount: subTopicsCount,
                exerciseCount: exercisesCount
            ),
            isEnglish: isEnglish
        )
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
    // נשמר ריק בכוונה - המיקום מחושב דרך topicFrames
    @State private var topicsScrollOffset: CGFloat = 0
    @State private var topicFrames:
        [String: CGFloat] = [:]
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

    @State private var isPreparingPDF = false
    @State private var pdfRequestID = UUID()
    @State private var isPDFScreenActive = false
    
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

        let generalNote: String
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
                    in:
                        .whitespacesAndNewlines
                )

        let stats =
            KmiExerciseCountProvider.topicStats(
                belt: belt,
                topicTitle: cleanTopicTitle
            )

        let subTitles =
            ContentRepo.shared
                .getSubTopicsFor(
                    belt: belt,
                    topicTitle: cleanTopicTitle
                )
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
                    if !result.contains(title) {
                        result.append(title)
                    }
                }

        return TopicDetailsUi(
            itemCount:
                stats.exerciseCount,
            subTitles:
                subTitles
        )
    }

    // Android parity:
    // סופרים בפועל את items בכל עץ תתי־הנושאים.
    private func topicExercisesCountForUi(
        belt: Belt,
        topicTitle: String,
        subTitles _: [String]
    ) -> Int {

        KmiExerciseCountProvider
            .topicStats(
                belt: belt,
                topicTitle: topicTitle
            )
            .exerciseCount
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
                    details.subTitles,
                generalNote:
                    ContentRepo.shared
                        .getTopicGeneralNote(
                            belt: targetBelt,
                            topicTitle: title
                        )?
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ) ?? ""
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
        KmiFeedbackManager.shared.tap()

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

                if isExpanded {
                    topicFrames.removeValue(
                        forKey: cleanTopicTitle
                    )
                }
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
            .kmiTypography(.topicTitle)
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
            .fixedSize(
                horizontal: false,
                vertical: true
            )

            if !cleanSubtitle.isEmpty {

                Text(
                    cleanSubtitle
                )
                .kmiTypography(.topicCount)
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
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
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
    
    private struct BeltPDFStorageContext: Hashable {
        let topicKey: String
        let subTopicTitle: String?
        let nestedSubTopicTitle: String?
        let indexInsideScope: Int
    }

    private struct BeltPDFSourceRow {
        let topicTitle: String
        let rawItem: String
        let indexInsideTopic: Int
        let storageContexts: [BeltPDFStorageContext]
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

        return values.filter {
            seen.insert($0).inserted
        }
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
                        topicTitle: topicTitle,
                        subTopicTitle: nil
                    )

            var contextsByItem:
                [String: [BeltPDFStorageContext]] = [:]

            func recordContexts(
                items: [String],
                subTopicTitle: String? = nil,
                nestedSubTopicTitle: String? = nil
            ) {
                var scopeParts = [topicTitle]

                if let subTopicTitle {
                    scopeParts.append(subTopicTitle)
                }

                if let nestedSubTopicTitle {
                    scopeParts.append(nestedSubTopicTitle)
                }

                let scopeKey = scopeParts.joined(separator: "__")

                for (index, rawItem) in
                    uniquePDFItems(items).enumerated() {

                    let context = BeltPDFStorageContext(
                        topicKey: scopeKey,
                        subTopicTitle: subTopicTitle,
                        nestedSubTopicTitle: nestedSubTopicTitle,
                        indexInsideScope: index
                    )

                    if !contextsByItem[rawItem, default: []]
                        .contains(context) {
                        contextsByItem[rawItem, default: []]
                            .append(context)
                    }
                }
            }

            recordContexts(items: topicItems)

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

                let nestedTitles = uniquePDFItems(
                    ContentRepo.shared
                        .getNestedSubTopicTitles(
                            belt: belt,
                            topicTitle: topicTitle,
                            subTopicTitle: cleanSubTopicTitle
                        )
                        .map {
                            $0.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                        }
                        .filter { !$0.isEmpty }
                )

                var nestedItems: [String] = []

                for nestedTitle in nestedTitles {
                    let items = uniquePDFItems(
                        ContentRepo.shared.getNestedItemsFor(
                            belt: belt,
                            topicTitle: topicTitle,
                            subTopicTitle: cleanSubTopicTitle,
                            nestedSubTopicTitle: nestedTitle
                        )
                    )

                    recordContexts(
                        items: items,
                        subTopicTitle: cleanSubTopicTitle,
                        nestedSubTopicTitle: nestedTitle
                    )

                    nestedItems.append(contentsOf: items)
                }

                let combinedNestedItems =
                    uniquePDFItems(nestedItems)

                let subTopicItems: [String]

                if !combinedNestedItems.isEmpty {
                    subTopicItems = combinedNestedItems
                } else {
                    subTopicItems = uniquePDFItems(
                        ContentRepo.shared.getAllItemsFor(
                            belt: belt,
                            topicTitle: topicTitle,
                            subTopicTitle: cleanSubTopicTitle
                        )
                    )
                }

                recordContexts(
                    items: subTopicItems,
                    subTopicTitle: cleanSubTopicTitle
                )

                topicItems.append(contentsOf: subTopicItems)
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
                        topicTitle: topicTitle,
                        rawItem: rawItem,
                        indexInsideTopic: index,
                        storageContexts:
                            contextsByItem[rawItem] ?? []
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
        let cleanItem = normalizedPDFStatusPart(
            sourceRow.rawItem
        )

        let defaults = UserDefaults.standard

        var savedMarks:
            [(value: String, updatedAt: Double)] = []

        for context in sourceRow.storageContexts {
            let statusID =
                "status_\(belt.id)_\(context.topicKey)_" +
                "\(context.indexInsideScope)_\(cleanItem)"

            guard let value = defaults.string(
                forKey: "mark.\(statusID)"
            ) else {
                continue
            }

            let updatedAtKey =
                "trainee_material_updated_at_" +
                "\(belt.id)_\(context.topicKey)_\(statusID)"

            let storedTime = defaults.double(
                forKey: updatedAtKey
            )

            savedMarks.append(
                (
                    value: value,
                    updatedAt: storedTime.isFinite
                        ? max(0, storedTime)
                        : 0
                )
            )
        }

        let latestTime = savedMarks
            .map(\.updatedAt)
            .max()

        let latestValues = Set(
            savedMarks
                .filter { $0.updatedAt == latestTime }
                .map(\.value)
        )

        if latestValues.count > 1 {
            return isEnglish
                ? "Conflicting marks"
                : "סימונים סותרים"
        }

        let storedStatus = latestValues.first

        switch storedStatus {
        case "mastered":
            return isEnglish
                ? "Known"
                : "יודע"

        case "partiallyKnown":
            return isEnglish
                ? "Partially known"
                : "יודע חלקית"

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
        sourceRow: BeltPDFSourceRow,
        context: BeltPDFStorageContext? = nil
    ) -> String {
        let cleanItem = sourceRow.rawItem
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let subTopicTitle =
            context?.nestedSubTopicTitle
            ?? context?.subTopicTitle
            ?? ""

        return "\(belt.id)||\(sourceRow.topicTitle)||\(subTopicTitle)||\(cleanItem)"
    }

    private func canonicalPDFIds(
        belt: Belt,
        sourceRow: BeltPDFSourceRow
    ) -> [String] {
        guard !sourceRow.storageContexts.isEmpty else {
            return [
                canonicalPDFId(
                    belt: belt,
                    sourceRow: sourceRow
                )
            ]
        }

        var seen = Set<String>()

        return sourceRow.storageContexts.compactMap { context in
            let id = canonicalPDFId(
                belt: belt,
                sourceRow: sourceRow,
                context: context
            )

            return seen.insert(id).inserted ? id : nil
        }
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

        let formattedExercise = ExerciseTitleFormatter.shared
            .displayName(raw: sourceRow.rawItem)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let exerciseTitle = formattedExercise.isEmpty
            ? sourceRow.rawItem
            : formattedExercise

        let localizedExercise =
            KmiEnglishTitleResolver.title(
                for: exerciseTitle,
                isEnglish: isEnglish
            )

        return
            "\(localizedTopic) — " +
            localizedExercise
    }

    private func currentPDFNoteUserID() -> String? {
        #if canImport(FirebaseAuth)
        let userID = Auth.auth().currentUser?.uid
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""

        return userID.isEmpty ? nil : userID
        #else
        return nil
        #endif
    }

    private func pdfHasStoredNote(
        belt: Belt,
        sourceRow: BeltPDFSourceRow,
        userID: String?
    ) -> Bool {
        guard let userID else {
            return false
        }

        let notesStore = ExerciseNotesStore.shared

        let localNoteIDs = canonicalPDFIds(
            belt: belt,
            sourceRow: sourceRow
        )
        .map { "materials-local:\($0)" }

        let previousNoteIDs: Set<String>

        if let knownID = notesStore.knownExerciseID(
            belt: belt,
            title: sourceRow.rawItem,
            topicKey: sourceRow.topicTitle
        ) {
            previousNoteIDs = [knownID]
        } else {
            previousNoteIDs = Set(localNoteIDs)
        }

        guard let resolved = ExerciseIdentityResolverIOS.resolve(
            belt: belt,
            topic: sourceRow.topicTitle,
            rawItem: sourceRow.rawItem
        ) else {
            var storedValues = Set<String>()

            for exerciseID in previousNoteIDs {
                guard notesStore.hasStoredValue(
                    userID: userID,
                    beltID: belt.id,
                    exerciseID: exerciseID
                ) else {
                    continue
                }

                storedValues.insert(
                    notesStore.load(
                        userID: userID,
                        beltID: belt.id,
                        exerciseID: exerciseID
                    )
                )
            }

            guard storedValues.count == 1,
                  let value = storedValues.first else {
                return false
            }

            return !value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        }

        var previousIDs = resolved.previousIDs

        previousIDs.formUnion(
            previousNoteIDs.filter {
                $0 != resolved.primaryID
            }
        )

        let identity = ExerciseIdentityResolverIOS.Identity(
            primaryID: resolved.primaryID,
            displayTitle: resolved.displayTitle,
            previousIDs: previousIDs
        )

        switch notesStore.loadCompatible(
            userID: userID,
            beltID: belt.id,
            identity: identity
        ) {
        case .found(let value):
            return !value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty

        case .missing:
            return false

        case .conflict:
            // אין לבחור גרסת הערה באופן אוטומטי בזמן ייצוא.
            return false
        }
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

        let favoritesStore = ExerciseFavoritesStore.shared
        let noteUserID = currentPDFNoteUserID()

        return sourceRows
            .enumerated()
            .map {
                globalIndex,
                sourceRow in

                let canonicalIDs = canonicalPDFIds(
                    belt: belt,
                    sourceRow: sourceRow
                )

                let isGlobalFavorite =
                    favoritesStore.contains(
                        sourceRow.rawItem
                    )

                let hasStoredNote = pdfHasStoredNote(
                    belt: belt,
                    sourceRow: sourceRow,
                    userID: noteUserID
                )

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
                        isGlobalFavorite,
                    isExcluded:
                        canonicalIDs.contains { id in
                            defaults.bool(
                                forKey: "excluded.\(id)"
                            )
                        },
                    hasNote:
                        hasStoredNote
                )
            }
    }

    private func invalidatePDFRequest() {
        pdfRequestID = UUID()
        isPreparingPDF = false
    }

    @MainActor
    private func createAndSharePDF() {
        guard isPDFScreenActive,
              !isPreparingPDF,
              !showPDFShareSheet
        else {
            return
        }

        let requestID = UUID()
        let requestedBelt = quickMenuBelt
        let requestedLanguage = isEnglish
        let requestedUserID = currentPDFNoteUserID()

        let title = requestedLanguage
            ? "\(beltDisplayTitle(requestedBelt)) Belt"
            : "חגורה \(beltDisplayTitle(requestedBelt))"

        pdfRequestID = requestID
        pdfErrorMessage = nil
        pdfShareItems.removeAll()
        quickMenuOpen = false
        isPreparingPDF = true

        Task { @MainActor in
            await Task.yield()

            guard pdfRequestID == requestID,
                  isPDFScreenActive,
                  quickMenuBelt.id == requestedBelt.id,
                  isEnglish == requestedLanguage,
                  currentPDFNoteUserID() == requestedUserID
            else {
                if pdfRequestID == requestID {
                    isPreparingPDF = false
                }
                return
            }

            defer {
                if pdfRequestID == requestID {
                    isPreparingPDF = false
                }
            }

            let items = materialsPDFItems(
                for: requestedBelt
            )

            guard !items.isEmpty else {
                pdfErrorMessage = requestedLanguage
                    ? "There are no exercises available for this belt."
                    : "אין תרגילים זמינים לחגורה זו."
                return
            }

            do {
                let fileURL = try MaterialsPdfGeneratorIOS.create(
                    belt: requestedBelt,
                    topicTitle: title,
                    items: items,
                    isEnglish: requestedLanguage
                )

                guard pdfRequestID == requestID,
                      isPDFScreenActive
                else {
                    return
                }

                pdfShareItems = [fileURL]
                showPDFShareSheet = true
            } catch {
                pdfErrorMessage = requestedLanguage
                    ? "The PDF file could not be created. Please try again."
                    : "לא ניתן היה ליצור את קובץ ה־PDF. נסה שוב."
            }
        }
    }

    var body: some View {

        ZStack(
            alignment: .top
        ) {

            KmiAppBackground()

            stickyHeaderOverlay

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
                    KmiBeltPalette.color(
                        for: quickMenuBelt
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
        .overlay {
            if isPreparingPDF {
                KmiLoadingOverlay()
            }
        }
        .onChange(of: isEnglish) { _, _ in
            invalidatePDFRequest()
        }
        .onAppear {
            isPDFScreenActive = true

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

            invalidatePDFRequest()

            expandedTopic =
                nil

            topicFrames.removeAll()

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
            of: effectiveLanguageCode
        ) { _, _ in
            topicFrames.removeAll()
            expandedTopic = nil
            quickMenuOpen = false

            ensureBeltTopicsCache(
                for: selectedBelt
            )

            NotificationCenter.default.post(
                name: Notification.Name(
                    "KMI_TOP_TITLE_OVERRIDE"
                ),
                object: screenTitleForMode
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
            isPDFScreenActive = false
            invalidatePDFRequest()

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
        .sheet(item: $pickedExercise) { selection in
            ExerciseExplanationDialog(
                belt: selection.belt,
                topic: selection.topicTitle,
                item: selection.item,
                branch: "",
                groupKey: "",
                isEnglish: isEnglish
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
            isPresented: $showGeneralNote,
            onDismiss: {
                generalNoteTitle = ""
                generalNoteText = ""
            }
        ) {
            MaterialsGeneralNoteSheet(
                title: generalNoteTitle,
                note: generalNoteText,
                isEnglish: isEnglish,
                accentColor: readableBeltAccent,
                onClose: {
                    showGeneralNote = false
                }
            )
            .environment(
                \.layoutDirection,
                screenLayoutDirection
            )
            .presentationDetents([
                .medium,
                .large
            ])
            .presentationDragIndicator(.visible)
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

        let topicGeneralNote = entry.generalNote

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
        .background {
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .fill(byBeltSubTopicsBackground)
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .stroke(
                byBeltSubTopicsBorder,
                lineWidth: 0.7
            )
        }
        .padding(
            .horizontal,
            10
        )
        .padding(
            .vertical,
            3
        )
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
        rowMinHeight: CGFloat
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
        .frame(minHeight: rowMinHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            openTopicFromByBelt(
                topicTitle: topicTitle,
                hasSubs: hasSubs,
                isExpanded: isExpanded
            )
        }
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

        KmiExerciseCountProvider
            .subTopicStats(
                belt: belt,
                topicTitle: topicTitle,
                subTopicTitle: subTopicTitle
            )
            .exerciseCount
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
                    .kmiTypography(.topicCount)
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
                    .kmiTypography(.topicCount)
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
                56
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
                .kmiTypography(.subTopicTitle)
                .foregroundStyle(
                    byBeltTitleColor
                )
                .multilineTextAlignment(
                    isEnglish ? .leading : .trailing
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
                .kmiTypography(.subTopicTitle)
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
                    .kmiTypography(.subTopicTitle)
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
                    .kmiTypography(.subTopicTitle)
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
            height: 56
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
                .kmiTypography(.action)
                .fontWeight(.heavy)
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
        GeometryReader { geometry in
            let rowMinHeight: CGFloat = 64

            let wheelClearance: CGFloat = 112
            let cardHeaderAllowance: CGFloat = 40

            let listHeight = max(
                0,
                geometry.size.height
                    - wheelClearance
                    - cardHeaderAllowance
            )

            VStack(spacing: 0) {

            VStack(spacing: 0) {

                Text(
                    isEnglish
                        ? "Topics in Belt"
                        : "נושאים בחגורה"
                )
                .kmiTypography(.sectionTitle)
                .fontWeight(.heavy)
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

                                GeometryReader { geo in
                                    Color.clear
                                        .preference(
                                            key: BeltTopicsScrollOffsetKey.self,
                                            value:
                                                geo.frame(
                                                    in: .named("beltTopicsScroll")
                                                ).minY
                                        )
                                }
                                .frame(height: 0)

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
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.preference(
                                                key: BeltTopicFrameKey.self,
                                                value: [
                                                    topicTitle:
                                                        geo.frame(
                                                            in: .named(
                                                                "beltTopicsScroll"
                                                            )
                                                        ).minY
                                                ]
                                            )
                                        }
                                    )

                                    if index !=
                                        beltTopicsUi.count - 1 {
                                        Spacer()
                                            .frame(height: 2)
                                    }
                                }
                            }
                        }
                        .frame(
                            height:
                                listHeight
                        )
                        .coordinateSpace(
                            name: "beltTopicsScroll"
                        )
                        .onChange(
                            of: selectedBelt
                        ) { _, _ in
                            proxy.scrollTo(
                                "topics_top_anchor",
                                anchor: .top
                            )
                        }
                        .onChange(
                            of: effectiveLanguageCode
                        ) { _, _ in
                            proxy.scrollTo(
                                "topics_top_anchor",
                                anchor: .top
                            )
                        }
                        .onPreferenceChange(
                            BeltTopicsScrollOffsetKey.self
                        ) { value in
                            topicsScrollOffset = value
                        }
                        .onPreferenceChange(
                            BeltTopicFrameKey.self
                        ) { value in
                            topicFrames = value
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
    }
   
    private var stickyHeaderOverlay: some View {

        expandedTopicStickyHeader
            .padding(.top, 52)
            .zIndex(200)
    }

    private var expandedTopicStickyHeader: some View {

        Group {
            if let expandedTopic,
               let topicOffset = topicFrames[expandedTopic],
               topicOffset < 0 {

                HStack(spacing: 8) {

                    RoundedRectangle(
                        cornerRadius: 999,
                        style: .continuous
                    )
                    .fill(
                        readableBeltAccent
                    )
                    .frame(
                        width: 4,
                        height: 24
                    )

                    Text(
                        uiTopicTitle(expandedTopic)
                    )
                    .kmiTypography(
                        .cardTitle
                    )
                    .foregroundStyle(
                        byBeltTitleColor
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(
                        maxWidth: .infinity,
                        alignment:
                            isEnglish
                                ? .leading
                                : .trailing
                    )

                    Image(
                        systemName:
                            "chevron.up"
                    )
                    .kmiIconSize(13)
                    .foregroundStyle(
                        readableBeltAccent
                    )
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(
                    KmiAppTheme.surface(
                        for: colorScheme
                    )
                )
                .overlay(
                    Rectangle()
                        .fill(
                            readableBeltAccent.opacity(0.35)
                        )
                        .frame(height: 2),
                    alignment: .bottom
                )
                .transition(
                    .move(edge: .top)
                    .combined(
                        with: .opacity
                    )
                )
            }
        }
    }
    
    // MARK: - Subject pill
    // Moved to BeltQuestionsSharedComponents.swift
     
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

private struct BeltTopicsScrollOffsetKey: PreferenceKey {

    static var defaultValue: CGFloat = 0

    static func reduce(
        value: inout CGFloat,
        nextValue: () -> CGFloat
    ) {
        value = nextValue()
    }
}

private struct BeltTopicFrameKey: PreferenceKey {

    static var defaultValue:
        [String: CGFloat] = [:]

    static func reduce(
        value: inout [String: CGFloat],
        nextValue: () -> [String: CGFloat]
    ) {
        value.merge(
            nextValue()
        ) { _, new in
            new
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

    @AppStorage("kmi.belt.quickMenu.bottomOffset")
    private var savedBottomOffset: Double = -1

    @State private var dragBottomOffset: CGFloat?
    @State private var dragStartBottomOffset: CGFloat?

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

            let panelWidth: CGFloat =
                min(
                    60,
                    geometry.size.width
                )

            /*
             * ערך ברירת המחדל ממקם את הידית קרוב
             * לתחתית. המיקום מוגבל לגבולות המסך.
             */
            let minimumBottom: CGFloat = 12

            let maximumBottom: CGFloat =
                max(
                    minimumBottom,
                    geometry.size.height
                        - geometry.safeAreaInsets.bottom
                        - triggerHeight
                        - 12
                )

            let storedBottom: CGFloat =
                savedBottomOffset >= 0
                    ? CGFloat(savedBottomOffset)
                    : 72

            let bottomSpacing =
                min(
                    maximumBottom,
                    max(
                        minimumBottom,
                        dragBottomOffset ?? storedBottom
                    )
                )

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
                    ? 0
                    : geometry.size.width
                        - panelWidth

            /*
             * הפאנל נפתח מעל הטריגר,
             * כדי שלא ייחתך בתחתית המסך.
             */
            /*
             * שומרים מקום לידית בתחתית ולשוליים העליונים.
             * כאשר אין מספיק גובה, רשימת הפעולות תגלול.
             */
            let actionsMaxHeight: CGFloat =
                max(
                    0,
                    min(
                        280,
                        triggerTop + triggerHeight - 12 - 65
                    )
                )

            let panelY: CGFloat =
                max(
                    12,
                    triggerTop + triggerHeight
                        - actionsMaxHeight
                        - 65
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
                        actionsMaxHeight:
                            actionsMaxHeight,
                        onDragChanged: { translation in
                            if dragStartBottomOffset == nil {
                                dragStartBottomOffset = bottomSpacing
                            }

                            let start =
                                dragStartBottomOffset ?? bottomSpacing

                            let proposed = start - translation

                            dragBottomOffset =
                                min(
                                    maximumBottom,
                                    max(minimumBottom, proposed)
                                )
                        },
                        onDragEnded: {
                            if let finalOffset = dragBottomOffset {
                                savedBottomOffset = Double(finalOffset)
                            }

                            dragBottomOffset = nil
                            dragStartBottomOffset = nil
                        },
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

                BeltScreenSideQuickFab(
                    accent: accent,
                    attachedToLeftEdge: startIsLeft
                )
                .frame(
                    width: triggerWidth,
                    height: triggerHeight
                )
                .contentShape(Rectangle())
                .overlay {
                    BeltQuickMenuGestureView(
                        onTap: {
                            withAnimation(
                                .spring(
                                    response: 0.28,
                                    dampingFraction: 0.86
                                )
                            ) {
                                isPresented.toggle()
                            }
                        },
                        onDragChanged: { translation in
                            if dragStartBottomOffset == nil {
                                dragStartBottomOffset = bottomSpacing
                            }

                            let start =
                                dragStartBottomOffset ?? bottomSpacing

                            dragBottomOffset =
                                min(
                                    maximumBottom,
                                    max(
                                        minimumBottom,
                                        start - translation
                                    )
                                )
                        },
                        onDragEnded: {
                            if let finalOffset = dragBottomOffset {
                                savedBottomOffset = Double(finalOffset)
                            }

                            dragBottomOffset = nil
                            dragStartBottomOffset = nil
                        }
                    )
                }
                .accessibilityElement()
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(
                    isEnglish
                        ? "Open quick menu"
                        : "פתח תפריט מהיר"
                )
                .accessibilityAction {
                    withAnimation(
                        .spring(
                            response: 0.28,
                            dampingFraction: 0.86
                        )
                    ) {
                        isPresented.toggle()
                    }
                }
                .offset(
                    x:
                        triggerX,
                    y:
                        triggerTop
                )
                .opacity(isPresented ? 0 : 1)
                .allowsHitTesting(!isPresented)
                .accessibilityHidden(isPresented)
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

/*
 * מזהה לחיצה קצרה או לחיצה ארוכה וגרירה.
 * הגרירה נמדדת בקואורדינטות המסך כדי שהזזת
 * הידית עצמה לא תשנה את נקודת המדידה.
 */
struct BeltQuickMenuGestureView: UIViewRepresentable {
    let onTap: () -> Void
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isAccessibilityElement = false

        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.45
        longPress.allowableMovement = 10

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )

        tap.require(toFail: longPress)

        view.addGestureRecognizer(longPress)
        view.addGestureRecognizer(tap)

        return view
    }

    func updateUIView(
        _ uiView: UIView,
        context: Context
    ) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject {
        var parent: BeltQuickMenuGestureView
        private var startY: CGFloat?

        init(parent: BeltQuickMenuGestureView) {
            self.parent = parent
        }

        @objc func handleTap(
            _ recognizer: UITapGestureRecognizer
        ) {
            guard recognizer.state == .ended else {
                return
            }

            parent.onTap()
        }

        @objc func handleLongPress(
            _ recognizer: UILongPressGestureRecognizer
        ) {
            let currentY = recognizer.location(in: nil).y

            switch recognizer.state {
            case .began:
                startY = currentY
                parent.onDragChanged(0)

            case .changed:
                guard let startY else {
                    return
                }

                parent.onDragChanged(currentY - startY)

            case .ended, .cancelled:
                if startY != nil {
                    parent.onDragEnded()
                }

                startY = nil

            case .failed:
                startY = nil

            default:
                break
            }
        }
    }
}

private struct BeltScreenQuickMenuPanel: View {
    
    @Environment(\.colorScheme)
    private var colorScheme
    
    let title: String
    let isEnglish: Bool
    let accent: Color
    let items: [BeltScreenQuickMenuItem]
    let actionsMaxHeight: CGFloat
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: () -> Void
    let onClose: () -> Void

    @State private var handlePressStartedAt: Date?
    @State private var handleIsDragging = false

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
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    ForEach(
                        Array(items.enumerated()),
                        id: \.element.id
                    ) { index, item in
                        BeltScreenQuickMenuRow(
                            title: item.title,
                            systemImage: item.systemImage,
                            isEnglish: isEnglish,
                            accent: accent,
                            action: {
                                onClose()

                                DispatchQueue.main.asyncAfter(
                                    deadline: .now() + 0.05
                                ) {
                                    item.action()
                                }
                            }
                        )

                        if index != items.count - 1 {
                            Rectangle()
                                .fill(Color.white.opacity(0.45))
                                .frame(height: 0.8)
                                .padding(.horizontal, 6)
                        }
                    }
                }
            }
            .frame(maxHeight: actionsMaxHeight)

            Rectangle()
                .fill(Color.white.opacity(0.45))
                .frame(height: 0.8)
                .padding(.horizontal, 6)

            Image(systemName: "line.3.horizontal")
                .kmiIconSize(16)
                .foregroundStyle(Color.white)
                .frame(
                    maxWidth: .infinity,
                    minHeight: 58
                )
                .contentShape(Rectangle())
                .overlay {
                    BeltQuickMenuGestureView(
                        onTap: onClose,
                        onDragChanged: onDragChanged,
                        onDragEnded: onDragEnded
                    )
                }
                .accessibilityElement()
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(
                    isEnglish
                        ? "Close quick menu"
                        : "סגור תפריט מהיר"
                )
                .accessibilityAction {
                    onClose()
                }
        }
        .padding(.bottom, 7)
        .frame(width: 60)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(accent.opacity(0.96))

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
            VStack(spacing: 2) {
                menuIcon
                    .frame(width: 27, height: 27)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.92))
                    )

                Text(title)
                    .kmiTypography(.caption)
                    .fontWeight(.heavy)
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                    .frame(maxWidth: .infinity)

                if isLocked {
                    Image(systemName: "lock.fill")
                        .kmiIconSize(9)
                        .foregroundStyle(Color.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 3)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
    
    private var menuIcon: some View {
        Image(systemName: systemImage)
            .kmiIconSize(12)
            .fontWeight(.bold)
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
        .kmiIconSize(isLocked ? 11.5 : 10.5)
        .fontWeight(.heavy)
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
