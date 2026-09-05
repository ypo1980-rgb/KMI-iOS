import SwiftUI
import UIKit
import Shared

private struct MainTopic: Identifiable, Hashable {
    let id: String
    let titleHeb: String
    let subjects: [SubjectTopic]
}

struct BeltQuestionsByTopicView: View {

    let belt: Belt
    var embeddedMode: Bool = false
    var onSwitchToByBelt: (() -> Void)? = nil
    var onActiveBeltChange: ((Belt) -> Void)? = nil

    var onOpenPdfMaterials: ((Belt) -> Void)? = nil

    @EnvironmentObject private var nav:
        AppNavModel

    @Environment(\.scenePhase)
    private var scenePhase

    @Environment(\.colorScheme)
    private var colorScheme

    // ContentRepo / TopicsEngine הם מקור האמת.
    @AppStorage("kmi_app_language")
    private var kmiAppLanguageCode:
        String = "he"

    @AppStorage("app_language")
    private var appLanguageRaw:
        String = "HEBREW"

    @AppStorage("initial_language_code")
    private var initialLanguageCode:
        String = "HEBREW"

    @AppStorage("selected_language_code")
    private var selectedLanguageCode:
        String = "he"

    private var effectiveLanguageCode:
        String {
        let orderedValues = [
            kmiAppLanguageCode,
            selectedLanguageCode,
            appLanguageRaw,
            initialLanguageCode
        ]

        for rawValue in orderedValues {
            let cleanValue =
                rawValue
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .lowercased()

            if cleanValue == "en" ||
                cleanValue == "english" {
                return "en"
            }

            if cleanValue == "he" ||
                cleanValue == "hebrew" ||
                cleanValue == "עברית" {
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

    private var primaryTextAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var horizontalTextAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private func exercisesCountText(
        _ count: Int
    ) -> String {
        let stats =
            KmiExerciseCountStats(
                subTopicCount: 0,
                exerciseCount: count
            )

        return KmiExerciseCountProvider
            .countText(
                stats: stats,
                isEnglish: isEnglish
            )
    }
        
    private var activeBeltFill: Color {
        beltColor(for: belt)
    }
    
    private func beltColor(for belt: Belt) -> Color {
        switch belt {
        case .white:
            return Color(red: 0.92, green: 0.92, blue: 0.92)
        case .yellow:
            return Color(red: 0.98, green: 0.85, blue: 0.18)
        case .orange:
            return Color(red: 0.98, green: 0.64, blue: 0.15)
        case .green:
            return Color(red: 0.18, green: 0.80, blue: 0.44)
        case .blue:
            return Color(red: 0.18, green: 0.52, blue: 0.95)
        case .brown:
            return Color(red: 0.55, green: 0.34, blue: 0.23)
        case .black:
            return Color(red: 0.10, green: 0.10, blue: 0.12)
        default:
            return Color(red: 0.98, green: 0.64, blue: 0.15)
        }
    }

    @State private var expandedMainTopicId: String? = nil
    @State private var pickedAcrossBeltsSubject: SubjectTopic? = nil
    @State private var pickedAcrossBeltsSubTopicTitle:
        String? = nil

    @State private var showQuickActionsDialog:
        Bool = false

    @State private var accessRefreshTick:
        Int = 0

    /*
     * Performance:
     *
     * mainTopics הוא חישוב כבד מאוד.
     * שומרים אותו ב-State במקום
     * לחשב אותו מחדש בכל body render.
     */
    @State private var cachedMainTopics:
        [MainTopic] = []

    @State private var didLoadMainTopics:
        Bool = false

    /*
     * Performance:
     *
     * טקסט הספירה של כל MainTopic
     * מחושב פעם אחת לכל:
     *
     * belt + language + topic
     */
    @State private var topicSubtitleCache:
        [String: String] = [:]

    @State private var subjectCountCache:
        [String: Int] = [:]
    
    private func buildMainTopics() -> [MainTopic] {

        let allRootSubjects =
            TopicsBySubjectRegistry
                .allSubjects()

        let allRegistrySubjects =
            TopicsBySubjectRegistry
                .all

        /*
         * חישוב visibility פעם אחת בלבד
         * לכל subject בזמן בניית ה-cache.
         */
        var visibilityCache:
            [String: Bool] = [:]

        func isVisible(
            _ subject: SubjectTopic
        ) -> Bool {

            if let cached =
                visibilityCache[
                    subject.id
                ] {

                return cached
            }

            let value =
                subjectHasVisibleContentInAnyBelt(
                    subject
                )

            visibilityCache[
                subject.id
            ] = value

            return value
        }

        let visibleRootSubjects =
            allRootSubjects.filter {
                isVisible($0)
            }

        let visibleRegistryChildren =
            allRegistrySubjects.filter {
                subject in

                subject.parentId != nil &&
                isVisible(subject)
            }

        func normalizedSubjectId(
            _ value: String
        ) -> String {

            value
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
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
                .lowercased()
        }

        func rootSubject(
            _ id: String
        ) -> SubjectTopic? {

            let cleanId =
                normalizedSubjectId(id)

            return visibleRootSubjects.first {
                normalizedSubjectId(
                    $0.id
                ) == cleanId
            }
        }

        func childSubjects(
            parentId: String
        ) -> [SubjectTopic] {

            let cleanParentId =
                normalizedSubjectId(
                    parentId
                )

            return visibleRegistryChildren.filter {
                subject in

                guard
                    let parentId =
                        subject.parentId
                else {
                    return false
                }

                return normalizedSubjectId(
                    parentId
                ) == cleanParentId
            }
        }

        var out:
            [MainTopic] = []

        let defenseSubjects =
            defenseRootSubjects

        let releaseSubjects =
            childSubjects(
                parentId:
                    "releases"
            )

        if !defenseSubjects.isEmpty {

            out.append(
                MainTopic(
                    id:
                        "defense_root",
                    titleHeb:
                        "הגנות",
                    subjects:
                        defenseSubjects
                )
            )
        }

        if !releaseSubjects.isEmpty {

            out.append(
                MainTopic(
                    id:
                        "releases",
                    titleHeb:
                        "שחרורים",
                    subjects:
                        releaseSubjects
                )
            )

        } else if
            let releasesRoot =
                rootSubject(
                    "releases"
                ) {

            out.append(
                MainTopic(
                    id:
                        "releases",
                    titleHeb:
                        releasesRoot.titleHeb,
                    subjects: [
                        releasesRoot
                    ]
                )
            )
        }

        let visibleHandsSubjects =
            childSubjects(
                parentId:
                    "hands_all"
            )

        if !visibleHandsSubjects.isEmpty {

            out.append(
                MainTopic(
                    id:
                        "hands_root",
                    titleHeb:
                        "עבודת ידיים",
                    subjects:
                        visibleHandsSubjects
                )
            )

        } else if
            let handsRoot =
                rootSubject(
                    "hands_all"
                ) {

            out.append(
                MainTopic(
                    id:
                        "hands_root",
                    titleHeb:
                        handsRoot.titleHeb,
                    subjects: [
                        handsRoot
                    ]
                )
            )
        }

        if let rollsSubject =
            rootSubject(
                "rolls_breakfalls"
            ) {

            out.append(
                MainTopic(
                    id:
                        "rolls_breakfalls",
                    titleHeb:
                        rollsSubject.titleHeb,
                    subjects: [
                        rollsSubject
                    ]
                )
            )
        }

        if let readySubject =
            rootSubject(
                "topic_ready_stance"
            ) {

            out.append(
                MainTopic(
                    id:
                        "topic_ready_stance",
                    titleHeb:
                        readySubject.titleHeb,
                    subjects: [
                        readySubject
                    ]
                )
            )
        }

        if let groundSubject =
            rootSubject(
                "topic_ground_prep"
            ) {

            out.append(
                MainTopic(
                    id:
                        "topic_ground_prep",
                    titleHeb:
                        groundSubject.titleHeb,
                    subjects: [
                        groundSubject
                    ]
                )
            )
        }

        if let kavalerSubject =
            rootSubject(
                "topic_kavaler"
            ) {

            out.append(
                MainTopic(
                    id:
                        "topic_kavaler",
                    titleHeb:
                        kavalerSubject.titleHeb,
                    subjects: [
                        kavalerSubject
                    ]
                )
            )
        }

        if let kicksSubject =
            rootSubject(
                "kicks"
            ) {

            out.append(
                MainTopic(
                    id:
                        "kicks",
                    titleHeb:
                        kicksSubject.titleHeb,
                    subjects: [
                        kicksSubject
                    ]
                )
            )
        }

        let groupedRootIds:
            Set<String> = [

                "defense_root",
                "defenses_root",
                "defenses",
                "releases",
                "hands_all",
                "hands_root",
                "rolls_breakfalls",
                "topic_breakfalls_rolls",
                "topic_ready_stance",
                "topic_ground_prep",
                "topic_kavaler",
                "kicks",
                "topic_kicks"
            ]

        var representedSubjectIds =
            Set<String>()

        for topic in out {

            representedSubjectIds.insert(
                normalizedSubjectId(
                    topic.id
                )
            )

            for subject in
                topic.subjects {

                representedSubjectIds.insert(
                    normalizedSubjectId(
                        subject.id
                    )
                )
            }
        }

        let remainingRootSubjects =
            visibleRootSubjects.filter {
                subject in

                let cleanId =
                    normalizedSubjectId(
                        subject.id
                    )

                guard !cleanId.isEmpty else {
                    return false
                }

                guard !groupedRootIds
                    .contains(
                        cleanId
                    )
                else {
                    return false
                }

                return !representedSubjectIds
                    .contains(
                        cleanId
                    )
            }

        for subject in
            remainingRootSubjects {

            let cleanId =
                normalizedSubjectId(
                    subject.id
                )

            let cleanTitle =
                subject.titleHeb
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            guard
                !cleanId.isEmpty,
                !cleanTitle.isEmpty
            else {
                continue
            }

            let visibleChildren =
                childSubjects(
                    parentId:
                        cleanId
                )

            let cardSubjects:
                [SubjectTopic]

            if visibleChildren.isEmpty {

                cardSubjects = [
                    subject
                ]

            } else {

                cardSubjects =
                    visibleChildren
            }

            out.append(
                MainTopic(
                    id:
                        cleanId,
                    titleHeb:
                        cleanTitle,
                    subjects:
                        cardSubjects
                )
            )

            representedSubjectIds.insert(
                cleanId
            )

            for child in
                visibleChildren {

                representedSubjectIds.insert(
                    normalizedSubjectId(
                        child.id
                    )
                )
            }
        }

        var seenMainTopicIds =
            Set<String>()

        return out.filter {
            topic in

            let cleanId =
                normalizedSubjectId(
                    topic.id
                )

            guard !cleanId.isEmpty else {
                return false
            }

            return seenMainTopicIds
                .insert(
                    cleanId
                )
                .inserted
        }
    }

    private var mainTopics:
        [MainTopic] {

        cachedMainTopics
    }

    private func loadMainTopicsIfNeeded(
        force: Bool = false
    ) {

        if
            didLoadMainTopics,
            !force {

            return
        }

        cachedMainTopics =
            buildMainTopics()

        didLoadMainTopics =
            true
    }

    private struct TopicRowCard: View {

        let title: String
        let accent: Color
        let subtitleTop: String?
        let subtitleBottom: String
        let isEnglish: Bool
        let symbolName: String
        let imageName: String?
        let isLocked: Bool
        let hasSubTopics: Bool
        let isExpanded: Bool

        @Environment(\.colorScheme)
        private var colorScheme

        private var titleColor: Color {

            KmiAppTheme.onSurface(
                for: colorScheme
            )
        }

        private var secondaryTextColor: Color {

            KmiAppTheme.onSurfaceVariant(
                for: colorScheme
            )
        }

        private var cardColor: Color {

            KmiAppTheme.surface(
                for: colorScheme
            )
        }

        private var borderColor: Color {

            isLocked
                ? KmiAppTheme
                    .warning(
                        for: colorScheme
                    )
                    .opacity(0.38)
                : KmiAppTheme
                    .outlineVariant(
                        for: colorScheme
                    )
        }

        private var textAlignment:
            TextAlignment {

            isEnglish
                ? .leading
                : .trailing
        }

        private var frameAlignment:
            Alignment {

            isEnglish
                ? .leading
                : .trailing
        }

        private var stackAlignment:
            HorizontalAlignment {

            isEnglish
                ? .leading
                : .trailing
        }

        private var navigationIconName:
            String {

            if hasSubTopics {

                return isExpanded
                    ? "chevron.up"
                    : "chevron.down"
            }

            return isEnglish
                ? "chevron.right"
                : "chevron.left"
        }

        var body: some View {

            HStack(spacing: 10) {

                if isEnglish {

                    accentBar
                    visualBlock
                    textBlock

                    if isLocked {
                        TopicPulsingLockBadge()
                    }

                    navigationIcon

                } else {

                    navigationIcon

                    if isLocked {
                        TopicPulsingLockBadge()
                    }

                    textBlock
                    visualBlock
                    accentBar
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
            .frame(
                maxWidth:
                    .infinity,
                minHeight:
                    54
            )
            .background {

                RoundedRectangle(
                    cornerRadius:
                        20,
                    style:
                        .continuous
                )
                .fill(
                    cardColor
                )
            }
            .overlay {

                RoundedRectangle(
                    cornerRadius:
                        20,
                    style:
                        .continuous
                )
                .stroke(
                    borderColor,
                    lineWidth:
                        1
                )
            }
        }

        private var navigationIcon:
            some View {

            Image(
                systemName:
                    navigationIconName
            )
            .kmiIconSize(
                hasSubTopics
                    ? 16
                    : 15
            )
            .foregroundStyle(
                hasSubTopics
                    ? accent
                    : secondaryTextColor
            )
            .frame(
                minWidth:
                    20
            )
            .accessibilityHidden(
                true
            )
        }

        private var textBlock:
            some View {

            VStack(
                alignment:
                    stackAlignment,
                spacing:
                    2
            ) {

                Text(title)
                    .kmiTypography(
                        .cardTitle
                    )
                    .foregroundStyle(
                        titleColor
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
                    .lineLimit(2)
                    .minimumScaleFactor(
                        0.70
                    )

                if
                    let top =
                        subtitleTop,
                    !top.isEmpty {

                    Text(top)
                        .kmiTypography(
                            .caption
                        )
                        .fontWeight(
                            .heavy
                        )
                        .foregroundStyle(
                            accent
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
                        .lineLimit(1)
                }

                Text(
                    subtitleBottom
                )
                .kmiTypography(
                    .caption
                )
                .fontWeight(
                    .bold
                )
                .foregroundStyle(
                    secondaryTextColor
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
                .lineLimit(1)
            }
        }

        @ViewBuilder
        private var visualBlock:
            some View {

            if let imageName {

                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width:
                            38,
                        height:
                            31
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius:
                                10,
                            style:
                                .continuous
                        )
                    )

            } else {

                Image(
                    systemName:
                        symbolName
                )
                .kmiIconSize(
                    18
                )
                .foregroundStyle(
                    accent
                )
                .frame(
                    width:
                        38,
                    height:
                        31
                )
            }
        }

        private var accentBar:
            some View {

            RoundedRectangle(
                cornerRadius:
                    999,
                style:
                    .continuous
            )
            .fill(accent)
            .frame(
                width:
                    3,
                height:
                    34
            )
        }
    }
    
    private func toSharedSubject(_ local: SubjectTopic) -> Shared.SubjectTopic {
        let normalizedTopicsByBelt: [Belt: [String]]

        if local.id == "punches" {
            normalizedTopicsByBelt = local.topicsByBelt.mapValues { topics in
                topics.map { $0 == "עבודת ידיים" ? "מכות ידיים" : $0 }
            }
        } else {
            normalizedTopicsByBelt = local.topicsByBelt
        }

        return Shared.SubjectTopic(
            id: local.id,
            titleHeb: local.titleHeb,
            topicsByBelt: normalizedTopicsByBelt,
            subTopicHint: local.subTopicHint,
            includeItemKeywords: local.includeItemKeywords,
            requireAllItemKeywords: local.requireAllItemKeywords,
            excludeItemKeywords: local.excludeItemKeywords
        )
    }

    private func normalizedTopicKey(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "/", with: " / ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func subjectHasVisibleContent(_ subject: SubjectTopic, for belt: Belt) -> Bool {

        let sections = SubjectItemsResolver.shared.resolveBySubject(
            belt: belt,
            subject: toSharedSubject(subject)
        )

        if sections.contains(where: { !$0.items.isEmpty }) {
            return true
        }

        guard
            let beltContent = ContentRepo.shared.data[belt],
            let mappedTopics = subject.topicsByBelt[belt],
            !mappedTopics.isEmpty
        else {
            return false
        }

        let mappedKeys = Set(mappedTopics.map(normalizedTopicKey))

        for topic in beltContent.topics {
            let topicKey = normalizedTopicKey(topic.title)

            if mappedKeys.contains(topicKey) {
                if !topic.items.isEmpty { return true }
                if topic.subTopics.contains(where: { !$0.items.isEmpty }) { return true }
            }

            for subTopic in topic.subTopics {
                let subTopicKey = normalizedTopicKey(subTopic.title)
                if mappedKeys.contains(subTopicKey), !subTopic.items.isEmpty {
                    return true
                }
            }
        }

        return false
    }

    private func subjectHasVisibleContentInAnyBelt(_ subject: SubjectTopic) -> Bool {
        let beltsToCheck: [Belt] = [.yellow, .orange, .green, .blue, .brown, .black]
        return beltsToCheck.contains { oneBelt in
            subjectHasVisibleContent(subject, for: oneBelt)
        }
    }
    
    private func syntheticSubject(
        id: String,
        titleHeb: String,
        topicsByBelt: [Belt: [String]],
        subTopicHint: String? = nil,
        includeItemKeywords: [String] = [],
        requireAllItemKeywords: [String] = [],
        excludeItemKeywords: [String] = []
    ) -> SubjectTopic {
        SubjectTopic(
            id: id,
            titleHeb: titleHeb,
            description: "",
            belts: Array(topicsByBelt.keys),
            topicsByBelt: topicsByBelt,
            subTopicHint: subTopicHint,
            includeItemKeywords: includeItemKeywords,
            requireAllItemKeywords: requireAllItemKeywords,
            excludeItemKeywords: excludeItemKeywords
        )
    }

    private var defenseRootSubjects: [SubjectTopic] {
        let candidates: [SubjectTopic] = [
            syntheticSubject(
                id: "def_internal_punch",
                titleHeb: "הגנות פנימיות",
                topicsByBelt: [
                    .yellow: ["הגנות"],
                    .orange: ["הגנות"],
                    .green: ["הגנות"],
                    .blue: ["הגנות"],
                    .brown: ["הגנות"],
                    .black: ["הגנות"]
                ]
            ),
            syntheticSubject(
                id: "def_external_punch",
                titleHeb: "הגנות חיצוניות",
                topicsByBelt: [
                    .yellow: ["הגנות"],
                    .orange: ["הגנות"],
                    .green: ["הגנות"],
                    .blue: ["הגנות"],
                    .brown: ["הגנות"],
                    .black: ["הגנות"]
                ]
            ),
            syntheticSubject(
                id: "kicks_hard",
                titleHeb: "הגנות נגד בעיטות",
                topicsByBelt: [
                    .yellow: ["הגנות"],
                    .orange: ["הגנות"],
                    .green: ["הגנות"],
                    .blue: ["הגנות"],
                    .brown: ["הגנות"],
                    .black: ["הגנות"]
                ]
            ),
            syntheticSubject(
                id: "knife_defense",
                titleHeb: "הגנות מסכין",
                topicsByBelt: [
                    .green: ["הגנות"],
                    .blue: ["הגנות"],
                    .brown: ["הגנות"],
                    .black: ["הגנות"]
                ],
                subTopicHint: "סכין",
                excludeItemKeywords: [
                    "רובה",
                    "מקל",
                    "אקדח",
                    "תמ\"ק"
                ]
            ),
            syntheticSubject(
                id: "knife_rifle_defense",
                titleHeb: "הגנות עם רובה נגד דקירות סכין",
                topicsByBelt: [
                    .black: ["הגנות"]
                ],
                subTopicHint: "סכין",
                includeItemKeywords: ["רובה"]
            ),
            syntheticSubject(
                id: "gun_threat_defense",
                titleHeb: "הגנות מאיום אקדח",
                topicsByBelt: [
                    .brown: ["הגנות"],
                    .black: ["הגנות"]
                ],
                subTopicHint: "אקדח",
                excludeItemKeywords: [
                    "סכין",
                    "מקל"
                ]
            ),
            syntheticSubject(
                id: "multiple_attackers_defense",
                titleHeb: "הגנות נגד מספר תוקפים",
                topicsByBelt: [
                    .black: ["הגנות"]
                ],
                includeItemKeywords: [
                    "1 מקל",
                    "2 תוקפים"
                ]
            ),
            syntheticSubject(
                id: "stick_defense",
                titleHeb: "הגנות נגד מקל",
                topicsByBelt: [
                    .green: ["הגנות"],
                    .brown: ["הגנות"],
                    .black: ["הגנות"]
                ],
                subTopicHint: "מקל",
                excludeItemKeywords: [
                    "סכין",
                    "אקדח",
                    "תמ\"ק"
                ]
            )
        ]

        return candidates.filter { subject in
            SubjectAcrossBeltsView.resolvedExerciseCount(
                subject: subject
            ) > 0
        }
    }
    
    private func isPremiumTopic(_ topic: MainTopic) -> Bool {
        LockedContentPolicy.isTopicRestricted(topic.titleHeb) ||
        LockedContentPolicy.isTopicRestricted(displayTitle(for: topic)) ||
        topic.id.lowercased().contains("defense") ||
        topic.id.lowercased().contains("release")
    }

    private func isTopicLocked(
        _ topic: MainTopic
    ) -> Bool {
        let _ = accessRefreshTick

        let accessMode =
            LockedContentPolicy
                .currentAccessMode()

        return LockedContentPolicy
            .shouldShowLock(
                accessMode:
                    accessMode,
            title: topic.titleHeb
        ) || (
            accessMode == .locked &&
            isPremiumTopic(topic)
        )
    }

    private func isDefenseRootTopic(
        _ topic: MainTopic
    ) -> Bool {
        let id = topic.id
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return id == "defense_root" ||
            id == "defenses_root" ||
            id == "defenses"
    }

    private func isFreeDefenseSubject(
        _ subject: SubjectTopic
    ) -> Bool {
        let id = subject.id
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let title = subject.titleHeb
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return id == "kicks_hard" ||
            title == "הגנות נגד בעיטות"
    }

    private func isInlineSubjectLocked(
        _ subject: SubjectTopic,
        in topic: MainTopic
    ) -> Bool {
        let _ = accessRefreshTick

        guard LockedContentPolicy
            .currentAccessMode() == .locked else {
            return false
        }

        if isDefenseRootTopic(topic) {
            return !isFreeDefenseSubject(subject)
        }

        return false
    }
    
    private func firstExistingImageName(_ candidates: [String]) -> String? {
        for name in candidates {
            let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)

            if !cleanName.isEmpty, UIImage(named: cleanName) != nil {
                return cleanName
            }
        }

        return nil
    }

    private func imageNameForTopic(_ topic: MainTopic) -> String? {
        let id = topic.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let title = topic.titleHeb.trimmingCharacters(in: .whitespacesAndNewlines)

        // ✅ Android parity:
        // subjectImageFor("defense_root") -> topic_defenses
        if id.contains("defense") || title.contains("הגנות") {
            return firstExistingImageName([
                "topic_defenses"
            ])
        }

        // ✅ Android parity:
        // subjectImageFor("releases") / releases_hugs -> topic_body_hug_releases
        // fallback לשם הישן שהיה ב-iOS כדי שלא יוצג ריבוע ריק.
        if id.contains("release") || title.contains("שחרור") || title.contains("שחרורים") {
            return firstExistingImageName([
                "topic_body_hug_releases",
                "topic_releases"
            ])
        }

        // ✅ Android parity:
        // subjectImageFor("hands_root") / hands_all / hands_strikes -> topic_hand_strikes
        if id.contains("hands") || id.contains("hand") || id.contains("punch") || title.contains("יד") {
            return firstExistingImageName([
                "topic_hand_strikes"
            ])
        }

        if title.contains("מרפק") || id.contains("elbow") {
            return firstExistingImageName([
                "topic_elbow_strikes",
                "topic_hand_strikes"
            ])
        }

        // ✅ Android parity:
        // subjectImageFor("kicks") / topic_kicks -> topic_kicks
        if id.contains("kick") || title.contains("בעיטות") || title.contains("בעיטה") {
            return firstExistingImageName([
                "topic_kicks"
            ])
        }

        // ✅ Android parity:
        // subjectImageFor("topic_breakfalls_rolls") -> topic_forward_roll
        // fallback לשם הישן שהיה ב-iOS.
        if id.contains("roll") || id.contains("breakfall") || title.contains("בלימות") || title.contains("גלגולים") {
            return firstExistingImageName([
                "topic_forward_roll",
                "topic_breakfalls_rolls"
            ])
        }

        // ✅ Android parity:
        // subjectImageFor("topic_ready_stance") -> topic_ready_stance
        if id.contains("stance") || title.contains("עמידת מוצא") {
            return firstExistingImageName([
                "topic_ready_stance"
            ])
        }

        // ✅ Android parity:
        // subjectImageFor("topic_ground_prep") -> topic_ground_fighting
        if id.contains("ground") || title.contains("קרקע") {
            return firstExistingImageName([
                "topic_ground_fighting"
            ])
        }

        // ✅ Android parity:
        // subjectImageFor("topic_kavaler") -> topic_kavaler
        // fallback לשם הישן שהיה ב-iOS.
        if id.contains("kawal") || id.contains("kavaler") || id.contains("cavalier") ||
            title.contains("קוואלר") || title.contains("קאוולר") || title.contains("קאוול") {
            return firstExistingImageName([
                "topic_kavaler",
                "topic_cavalier"
            ])
        }

        if title.contains("כללי") || id.contains("general") {
            return firstExistingImageName([
                "topic_general"
            ])
        }

        return nil
    }

    private func symbolForTopic(_ topic: MainTopic) -> String {
        let id = topic.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let title = topic.titleHeb.trimmingCharacters(in: .whitespacesAndNewlines)

        if id.contains("defense") || title.contains("הגנות") {
            return "shield.fill"
        }

        if id.contains("release") || title.contains("שחרור") {
            return "hand.raised.fill"
        }

        if id.contains("hand") || id.contains("punch") || title.contains("יד") || title.contains("מרפק") {
            return "hand.tap.fill"
        }

        if id.contains("kick") || title.contains("בעיטות") {
            return "figure.kickboxing"
        }

        if id.contains("roll") || title.contains("בלימות") || title.contains("גלגולים") {
            return "arrow.triangle.2.circlepath"
        }

        if id.contains("ground") || title.contains("קרקע") {
            return "figure.wrestling"
        }

        if id.contains("throw") || title.contains("הטלות") {
            return "figure.martial.arts"
        }

        if id.contains("stance") || title.contains("עמידת") {
            return "figure.stand"
        }

        return "list.bullet.rectangle.fill"
    }
    
    private func accentForTopic(_ topic: MainTopic) -> Color {
        let topicId = topic.id
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch topicId {
        case "defense_root", "defenses_root", "defenses":
            return Color(
                red: 124.0 / 255.0,
                green: 92.0 / 255.0,
                blue: 255.0 / 255.0
            )

        case "releases":
            return Color(
                red: 25.0 / 255.0,
                green: 167.0 / 255.0,
                blue: 224.0 / 255.0
            )

        case "hands_root", "hands_all":
            return Color(
                red: 22.0 / 255.0,
                green: 179.0 / 255.0,
                blue: 154.0 / 255.0
            )

        case "rolls_breakfalls", "topic_breakfalls_rolls":
            return Color(
                red: 184.0 / 255.0,
                green: 135.0 / 255.0,
                blue: 70.0 / 255.0
            )

        case "topic_ready_stance":
            return Color(
                red: 89.0 / 255.0,
                green: 185.0 / 255.0,
                blue: 111.0 / 255.0
            )

        case "topic_ground_prep":
            return Color(
                red: 208.0 / 255.0,
                green: 90.0 / 255.0,
                blue: 160.0 / 255.0
            )

        case "topic_kavaler", "kavaler":
            return Color(
                red: 240.0 / 255.0,
                green: 154.0 / 255.0,
                blue: 42.0 / 255.0
            )

        case "kicks", "topic_kicks":
            return Color(
                red: 59.0 / 255.0,
                green: 130.0 / 255.0,
                blue: 246.0 / 255.0
            )

        case "releases_hugs":
            return Color(
                red: 91.0 / 255.0,
                green: 108.0 / 255.0,
                blue: 255.0 / 255.0
            )

        default:
            break
        }

        guard let subject = topic.subjects.first else {
            return Color(
                red: 124.0 / 255.0,
                green: 92.0 / 255.0,
                blue: 255.0 / 255.0
            )
        }

        let id = subject.id
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let title = subject.titleHeb
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if id.contains("knife") || title.contains("סכין") {
            return Color.orange.opacity(0.88)
        }

        if id.contains("gun") || title.contains("אקדח") {
            return Color.red.opacity(0.82)
        }

        if id.contains("stick") || title.contains("מקל") {
            return Color.brown.opacity(0.82)
        }

        return Color(
            red: 124.0 / 255.0,
            green: 92.0 / 255.0,
            blue: 255.0 / 255.0
        )
    }

    private func displayTitle(for topic: MainTopic) -> String {
        let cleanId = topic.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = topic.titleHeb.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isEnglish else { return cleanTitle }

        switch cleanId {
        case "defense_root", "defenses_root", "defenses":
            return "Defenses"
        case "hands_root", "hands_all":
            return "Hand Techniques"
        case "releases", "releases_root":
            return "Releases"
        case "throws", "throws_root":
            return "Throws"
        case "topic_kavaler", "kavaler":
            return "Kavaler"
        case "kicks", "kicks_root", "topic_kicks":
            return "Kicks"
        case "topic_ground_prep":
            return "Groundwork Preparation"
        case "rolls_breakfalls", "topic_breakfalls_rolls":
            return "Breakfalls and Rolls"
        case "topic_ready_stance":
            return "Ready Stance"
        default:
            if let titleFromId = KmiEnglishTitleResolver.englishTitle(for: cleanId) {
                return titleFromId
            }

            return KmiEnglishTitleResolver.title(for: cleanTitle, isEnglish: true)
        }
    }

    private func itemsForSection(
        _ section: HardSectionsCatalog.Section,
        belt: Belt
    ) -> [String] {
        if !section.subSections.isEmpty {
            return section.subSections.flatMap { itemsForSection($0, belt: belt) }
        }

        return section.beltGroups
            .filter { $0.belt == belt }
            .flatMap { $0.items }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func totalItemsCountForSection(
        _ section: HardSectionsCatalog.Section
    ) -> Int {
        if !section.subSections.isEmpty {
            return section.subSections.reduce(0) { partial, child in
                partial + totalItemsCountForSection(child)
            }
        }

        return section.beltGroups.reduce(0) { partial, group in
            partial + group.items.count
        }
    }

    private func uniqueExerciseCount(
        in sections: [HardSectionsCatalog.Section]
    ) -> Int {
        func normalizedItemKey(_ raw: String) -> String {
            raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\u{200F}", with: "")
                .replacingOccurrences(of: "\u{200E}", with: "")
                .replacingOccurrences(of: "\u{00A0}", with: " ")
                .replacingOccurrences(of: "–", with: "-")
                .replacingOccurrences(of: "—", with: "-")
                .replacingOccurrences(
                    of: "\\s+",
                    with: " ",
                    options: .regularExpression
                )
                .lowercased()
        }

        func collectItems(
            from section: HardSectionsCatalog.Section
        ) -> [String] {
            if !section.subSections.isEmpty {
                return section.subSections.flatMap {
                    collectItems(from: $0)
                }
            }

            return section.beltGroups.flatMap(\.items)
        }

        let keys = sections
            .flatMap { collectItems(from: $0) }
            .map(normalizedItemKey)
            .filter { !$0.isEmpty }

        return Set(keys).count
    }

    private func resolvedSections(for subject: SubjectTopic) -> [HardSectionsCatalog.Section] {

        func clean(_ value: String) -> String {
            value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "–", with: "-")
                .replacingOccurrences(of: "—", with: "-")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        }

        func sectionAllItems(_ section: HardSectionsCatalog.Section) -> [String] {
            if !section.subSections.isEmpty {
                return section.subSections.flatMap { sectionAllItems($0) }
            }

            return section.beltGroups
                .flatMap { $0.items }
                .map { clean($0) }
                .filter { !$0.isEmpty }
        }

        func sectionMatchesSubject(_ section: HardSectionsCatalog.Section, subject: SubjectTopic) -> Bool {
            let sectionId = clean(section.id)
            let sectionTitle = clean(section.title)
            let subjectId = clean(subject.id)
            let subjectTitle = clean(subject.titleHeb)

            if sectionId == subjectId || sectionTitle == subjectTitle {
                return true
            }

            // ✅ חשוב:
            // "מכות במקל / רובה" לא אמור ליפול ל-"הגנות נגד מקל".
            // אחרת המסך לפי נושא מציג תוכן הגנות תחת עבודת ידיים.
            if subjectId == "hands_stick_rifle" {
                return false
            }

            let allText = ([sectionTitle] + sectionAllItems(section)).joined(separator: " ")

            if let hint = subject.subTopicHint?.trimmingCharacters(in: .whitespacesAndNewlines),
               !hint.isEmpty,
               allText.contains(hint) {
                let excluded = subject.excludeItemKeywords.contains { keyword in
                    let cleanKeyword = clean(keyword)
                    return !cleanKeyword.isEmpty && allText.contains(cleanKeyword)
                }

                return !excluded
            }

            if !subject.includeItemKeywords.isEmpty {
                let hasIncludedKeyword = subject.includeItemKeywords.contains { keyword in
                    let cleanKeyword = clean(keyword)
                    return !cleanKeyword.isEmpty && allText.contains(cleanKeyword)
                }

                if hasIncludedKeyword {
                    let excluded = subject.excludeItemKeywords.contains { keyword in
                        let cleanKeyword = clean(keyword)
                        return !cleanKeyword.isEmpty && allText.contains(cleanKeyword)
                    }

                    return !excluded
                }
            }

            return false
        }

        func findMatchingSections(
            in sections: [HardSectionsCatalog.Section],
            subject: SubjectTopic
        ) -> [HardSectionsCatalog.Section] {
            var out: [HardSectionsCatalog.Section] = []

            for section in sections {
                if sectionMatchesSubject(section, subject: subject) {
                    out.append(section)
                }

                out.append(contentsOf: findMatchingSections(in: section.subSections, subject: subject))
            }

            var seen = Set<String>()
            return out.filter { section in
                let key = "\(section.id)||\(section.title)"
                return seen.insert(key).inserted
            }
        }

        switch subject.id {
        case "def_internal",
             "def_internal_punch",
             "def_internal_punches",
             "def_internal_kick",
             "def_internal_kicks":
            return HardSectionsCatalog.shared.sectionsForSubject(
                subjectId: "def_internal"
            ) ?? []

        case "def_external",
             "def_external_punch",
             "def_external_punches",
             "def_external_kick",
             "def_external_kicks":
            return HardSectionsCatalog.shared.sectionsForSubject(
                subjectId: "def_external"
            ) ?? []

        default:
            break
        }

        let directSections = HardSectionsCatalog.shared.sectionsForSubject(subjectId: subject.id) ?? []

        if !directSections.isEmpty {
            return directSections
        }

        let fallbackRoots: [String] = {
            // ✅ עבודת ידיים:
            // מחפשים רק בתוך hands_all, לא בתוך defense/stick_defense.
            if subject.id == "hands_strikes" ||
                subject.id == "hands_elbows" ||
                subject.id == "hands_stick_rifle" {
                return ["hands_all"]
            }

            // ✅ נושאים שמגיעים מה-Catalog / SubjectItemsResolver.
            // כאן לא מחזירים HardSections מזויפים.
            // המסך הבא עדיין יודע למשוך אותם דרך SubjectAcrossBeltsView.
            if subject.id == "topic_ready_stance" ||
                subject.id == "topic_kavaler" ||
                subject.id == "kicks" ||
                subject.id == "topic_kicks" ||
                subject.id == "kicks_hard" {
                return []
            }

            return [
                "releases",
                "hands_all",
                "defenses",
                "defense",
                "def_internal_punch",
                "def_external_punch",
                "knife_defense",
                "gun_threat_defense",
                "stick_defense"
            ]
        }()

        for rootId in fallbackRoots {
            let rootSections = HardSectionsCatalog.shared.sectionsForSubject(subjectId: rootId) ?? []
            let matches = findMatchingSections(in: rootSections, subject: subject)

            if !matches.isEmpty {
                return matches
            }
        }

        return []
    }

    private func displayedExerciseCount(
        for subject: SubjectTopic
    ) -> Int {
        let cleanSubjectTitle =
            subject.titleHeb
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let directStats =
            KmiExerciseCountProvider
                .topicStats(
                    belt: belt,
                    topicTitle:
                        cleanSubjectTitle
                )

        if directStats.exerciseCount > 0 {
            return directStats
                .exerciseCount
        }

        let sections =
            resolvedSections(
                for: subject
            )

        if !sections.isEmpty {
            let sectionCount =
                uniqueExerciseCount(
                    in: sections
                )

            if sectionCount > 0 {
                return sectionCount
            }
        }

        let resolvedSections =
            SubjectItemsResolver.shared
                .resolveBySubject(
                    belt: belt,
                    subject:
                        toSharedSubject(
                            subject
                        )
                )

        var uniqueKeys =
            Set<String>()

        for section
            in resolvedSections {
            for item in section.items {
                let mirror =
                    Mirror(
                        reflecting: item
                    )

                let canonicalId =
                    mirror.children.first {
                        $0.label ==
                            "canonicalId"
                    }?.value as? String

                let displayName =
                    mirror.children.first {
                        $0.label ==
                            "displayName"
                    }?.value as? String

                let rawKey =
                    canonicalId
                    ?? displayName
                    ?? String(
                        describing: item
                    )

                let cleanKey =
                    rawKey
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
                            of: "–",
                            with: "-"
                        )
                        .replacingOccurrences(
                            of: "—",
                            with: "-"
                        )
                        .replacingOccurrences(
                            of: "\\s+",
                            with: " ",
                            options:
                                .regularExpression
                        )
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                        .lowercased()

                if !cleanKey.isEmpty {
                    uniqueKeys.insert(
                        cleanKey
                    )
                }
            }
        }

        return uniqueKeys.count
    }

    private func subtitleLineTop(
        for topic: MainTopic
    ) -> String? {
        nil
    }

    private func totalExercisesCount(
        for topic: MainTopic
    ) -> Int {
        let topicStats =
            KmiExerciseCountProvider
                .topicStats(
                    belt: belt,
                    topicTitle:
                        topic.titleHeb
                )

        if topicStats.exerciseCount > 0 {
            return topicStats
                .exerciseCount
        }

        var uniqueKeys =
            Set<String>()

        for subject in topic.subjects {
            let sections =
                SubjectItemsResolver.shared
                    .resolveBySubject(
                        belt: belt,
                        subject:
                            toSharedSubject(
                                subject
                            )
                    )

            for section in sections {
                for item in section.items {
                    let mirror =
                        Mirror(
                            reflecting: item
                        )

                    let canonicalId =
                        mirror.children.first {
                            $0.label ==
                                "canonicalId"
                        }?.value as? String

                    let displayName =
                        mirror.children.first {
                            $0.label ==
                                "displayName"
                        }?.value as? String

                    let rawKey =
                        canonicalId
                        ?? displayName
                        ?? String(
                            describing:
                                item
                        )

                    let cleanKey =
                        rawKey
                            .replacingOccurrences(
                                of:
                                    "\u{200F}",
                                with:
                                    ""
                            )
                            .replacingOccurrences(
                                of:
                                    "\u{200E}",
                                with:
                                    ""
                            )
                            .replacingOccurrences(
                                of:
                                    "\u{00A0}",
                                with:
                                    " "
                            )
                            .replacingOccurrences(
                                of:
                                    "–",
                                with:
                                    "-"
                            )
                            .replacingOccurrences(
                                of:
                                    "—",
                                with:
                                    "-"
                            )
                            .replacingOccurrences(
                                of:
                                    "\\s+",
                                with:
                                    " ",
                                options:
                                    .regularExpression
                            )
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )
                            .lowercased()

                    if !cleanKey.isEmpty {
                        uniqueKeys.insert(
                            cleanKey
                        )
                    }
                }
            }
        }

        if !uniqueKeys.isEmpty {
            return uniqueKeys.count
        }

        return topic.subjects.reduce(0) {
            partial,
            subject in

            partial +
                displayedExerciseCount(
                    for: subject
                )
        }
    }

    private func topicSubtitleCacheKey(
        for topic: MainTopic
    ) -> String {

        "\(belt.id)::\(effectiveLanguageCode)::\(topic.id)"
    }

    private func subjectCountCacheKey(
        for subject: SubjectTopic
    ) -> String {

        "\(belt.id)::\(subject.id)"
    }

    private func cachedDisplayedExerciseCount(
        for subject: SubjectTopic
    ) -> Int {

        let key =
            subjectCountCacheKey(
                for: subject
            )

        if let cached =
            subjectCountCache[key] {

            return cached
        }

        let count =
            displayedExerciseCount(
                for: subject
            )

        subjectCountCache[key] =
            count

        return count
    }

    private func buildSubtitleLineBottom(
        for topic: MainTopic
    ) -> String {

        let stats =
            KmiExerciseCountProvider
                .topicStats(
                    belt: belt,
                    topicTitle:
                        topic.titleHeb
                )

        let total: Int

        if stats.exerciseCount > 0 {

            total =
                stats.exerciseCount

        } else {

            /*
             * משתמשים ב-cache של ה-subjects
             * במקום לפתור את כל SubjectItemsResolver
             * בכל render.
             */
            total =
                topic.subjects.reduce(
                    0
                ) {
                    partial,
                    subject in

                    partial +
                        cachedDisplayedExerciseCount(
                            for: subject
                        )
                }
        }

        let resolvedSubTopicCount =
            max(
                stats.subTopicCount,
                topic.subjects.count
            )

        let displayStats =
            KmiExerciseCountStats(
                subTopicCount:
                    resolvedSubTopicCount > 1
                        ? resolvedSubTopicCount
                        : 0,
                exerciseCount:
                    total
            )

        return KmiExerciseCountProvider
            .combinedCountText(
                stats:
                    displayStats,
                isEnglish:
                    isEnglish
            )
    }

    private func subtitleLineBottom(
        for topic: MainTopic
    ) -> String {

        let key =
            topicSubtitleCacheKey(
                for: topic
            )

        if let cached =
            topicSubtitleCache[key] {

            return cached
        }

        return buildSubtitleLineBottom(
            for: topic
        )
    }

    private func clearTopicCountCaches() {

        topicSubtitleCache
            .removeAll(
                keepingCapacity: true
            )

        subjectCountCache
            .removeAll(
                keepingCapacity: true
            )
    }

    private func triggerTapHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    private func openTopic(_ topic: MainTopic) {
        triggerTapHaptic()

        if isTopicLocked(topic) &&
            !isDefenseRootTopic(topic) {

            nav.push(.subscriptionPlans)
            return
        }

        if topic.subjects.count > 1 {
            withAnimation(.easeInOut(duration: 0.22)) {
                expandedMainTopicId =
                    expandedMainTopicId == topic.id
                        ? nil
                        : topic.id
            }

            return
        }

        guard let subject = topic.subjects.first else {
            return
        }

        openSubjectFromInlineList(subject)
    }

    private func openSubjectFromInlineList(
        _ subject: SubjectTopic
    ) {

        triggerTapHaptic()

        let cleanSubjectTitle =
            subject.titleHeb
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let sections =
            resolvedSections(
                for:
                    subject
            )

        let forcedSectionTitle:
            String?

        if sections.count == 1 {

            forcedSectionTitle =
                sections.first?
                    .title
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

        } else {

            forcedSectionTitle =
                nil
        }

        /*
         * חשוב:
         * ניווט גלובלי בלבד.
         *
         * כך path נהיה:
         *
         * By Belt
         * -> By Topic
         * -> Subject
         *
         * ולכן Back חוזר ל-By Topic.
         */
        nav.push(
            .subjectAcrossBelts(
                subjectId:
                    subject.id,
                subjectTitle:
                    cleanSubjectTitle
            )
        )

        /*
         * אם צריך forced section,
         * נשמור אותו זמנית כדי שהיעד
         * יוכל לצרוך אותו.
         */
        if let forcedSectionTitle,
           !forcedSectionTitle.isEmpty {

            UserDefaults.standard.set(
                forcedSectionTitle,
                forKey:
                    "kmi.subject.forcedSectionTitle"
            )

        } else {

            UserDefaults.standard.removeObject(
                forKey:
                    "kmi.subject.forcedSectionTitle"
            )
        }
    }

    @ViewBuilder
    private func expandedSubTopicsBlock(
        for topic: MainTopic,
        accent: Color
    ) -> some View {

        VStack(spacing: 0) {

            ForEach(
                topic.subjects,
                id: \.id
            ) { subject in

                let rowLocked =
                    isInlineSubjectLocked(
                        subject,
                        in: topic
                    )

                Button {

                    if rowLocked {

                        triggerTapHaptic()

                        nav.push(
                            .subscriptionPlans
                        )

                    } else {

                        openSubjectFromInlineList(
                            subject
                        )
                    }

                } label: {

                    inlineSubTopicRow(
                        subject:
                            subject,
                        accent:
                            accent,
                        isLocked:
                            rowLocked
                    )
                }
                .buttonStyle(.plain)

                if
                    subject.id !=
                        topic.subjects.last?.id {

                    Rectangle()
                        .fill(
                            KmiAppTheme
                                .outlineVariant(
                                    for:
                                        colorScheme
                                )
                        )
                        .frame(
                            height:
                                0.8
                        )
                        .padding(
                            .horizontal,
                            8
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
            10
        )
        .background {

            RoundedRectangle(
                cornerRadius:
                    18,
                style:
                    .continuous
            )
            .fill(
                KmiAppTheme
                    .surfaceVariant(
                        for:
                            colorScheme
                    )
                    .opacity(
                        colorScheme == .dark
                            ? 0.55
                            : 0.75
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
                accent.opacity(
                    colorScheme == .dark
                        ? 0.30
                        : 0.22
                ),
                lineWidth:
                    1
            )
        }
        .padding(
            .horizontal,
            18
        )
        .padding(
            .top,
            2
        )
        .padding(
            .bottom,
            6
        )
        .transition(
            .move(
                edge:
                    .top
            )
            .combined(
                with:
                    .opacity
            )
        )
    }

    private func inlineSubTopicRow(
        subject: SubjectTopic,
        accent: Color,
        isLocked: Bool
    ) -> some View {
        HStack(spacing: 8) {
            if isEnglish {
                inlineSubTopicIcon(
                    subject: subject,
                    accent: accent
                )

                inlineSubTopicText(
                    subject: subject,
                    isEnglish: isEnglish
                )

                if isLocked {
                    TopicPulsingLockBadge()
                        .scaleEffect(0.72)
                        .frame(width: 20, height: 20)
                }

                Image(systemName: "chevron.right")
                    .kmiFont(
                        size: 11,
                        weight: .bold
                    )
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.white.opacity(0.54)
                            : accent.opacity(0.70)
                    )

            } else {
                Image(systemName: "chevron.left")
                    .kmiFont(
                        size: 11,
                        weight: .bold
                    )
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.white.opacity(0.54)
                            : accent.opacity(0.70)
                    )

                if isLocked {
                    TopicPulsingLockBadge()
                        .scaleEffect(0.72)
                        .frame(width: 20, height: 20)
                }

                inlineSubTopicText(
                    subject: subject,
                    isEnglish: isEnglish
                )

                inlineSubTopicIcon(
                    subject: subject,
                    accent: accent
                )
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func inlineSubTopicRow(
        subject: SubjectTopic,
        accent: Color
    ) -> some View {
        HStack(spacing: 10) {
            if isEnglish {
                inlineSubTopicIcon(
                    subject: subject,
                    accent: accent
                )

                inlineSubTopicText(
                    subject: subject,
                    isEnglish: isEnglish
                )

                Image(systemName: "chevron.right")
                    .kmiFont(
                        size: 11,
                        weight: .bold
                    )
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.white.opacity(0.54)
                            : accent.opacity(0.70)
                    )
            } else {
                Image(systemName: "chevron.left")
                    .kmiFont(
                        size: 11,
                        weight: .bold
                    )
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.white.opacity(0.54)
                            : accent.opacity(0.70)
                    )

                inlineSubTopicText(
                    subject: subject,
                    isEnglish: isEnglish
                )

                inlineSubTopicIcon(
                    subject: subject,
                    accent: accent
                )
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(
                cornerRadius: 15,
                style: .continuous
            )
            .fill(
                colorScheme == .dark
                    ? Color.white.opacity(0.07)
                    : Color.white.opacity(0.86)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 15,
                style: .continuous
            )
            .stroke(
                colorScheme == .dark
                    ? Color.white.opacity(0.12)
                    : accent.opacity(0.11),
                lineWidth: 1
            )
        )
    }

    private func inlineSubTopicText(
        subject: SubjectTopic,
        isEnglish: Bool
    ) -> some View {

        let subjectAccent =
            accentForTopicSubject(
                subject
            )

        let exerciseCount =
            cachedDisplayedExerciseCount(
                for:
                    subject
            )

        return VStack(
            alignment:
                isEnglish
                    ? .leading
                    : .trailing,
            spacing:
                2
        ) {

            Text(
                uiSubjectTitleForInline(
                    subject
                )
            )
            .kmiTypography(
                .cardTitle
            )
            .foregroundStyle(
                KmiAppTheme
                    .onSurface(
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
            .lineLimit(1)
            .minimumScaleFactor(
                0.70
            )

            Text(
                exercisesCountText(
                    exerciseCount
                )
            )
            .kmiTypography(
                .caption
            )
            .fontWeight(
                .heavy
            )
            .foregroundStyle(
                subjectAccent
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
            .lineLimit(1)
        }
    }

    private func inlineSubTopicIcon(
        subject: SubjectTopic,
        accent: Color
    ) -> some View {

        ZStack {

            RoundedRectangle(
                cornerRadius:
                    10,
                style:
                    .continuous
            )
            .fill(
                accent.opacity(
                    colorScheme == .dark
                        ? 0.16
                        : 0.10
                )
            )

            RoundedRectangle(
                cornerRadius:
                    10,
                style:
                    .continuous
            )
            .stroke(
                accent.opacity(
                    colorScheme == .dark
                        ? 0.28
                        : 0.20
                ),
                lineWidth:
                    1
            )

            Image(
                systemName:
                    symbolForSubjectInline(
                        subject
                    )
            )
            .kmiIconSize(
                16
            )
            .foregroundStyle(
                accent
            )
        }
        .frame(
            width:
                30,
            height:
                30
        )
    }

    private func uiSubjectTitleForInline(_ subject: SubjectTopic) -> String {
        let cleanId = subject.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = subject.titleHeb.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isEnglish else { return cleanTitle }

        switch cleanId {
        case "def_internal_punch", "def_internal_punches", "def_internal":
            return "Internal Defenses"
        case "def_external_punch", "def_external_punches", "def_external":
            return "External Defenses"
        case "kicks_hard":
            return "Defenses Against Kicks"
        case "knife_defense":
            return "Knife Defenses"
        case "gun_threat_defense":
            return "Gun Threat Defenses"
        case "stick_defense":
            return "Stick Defenses"
        case "releases_hands_hair_shirt":
            return "Releases from Hand / Hair / Shirt Grabs"
        case "releases_chokes":
            return "Choke Releases"
        case "releases_hugs":
            return "Hug Releases"
        case "hands_strikes":
            return "Hand Strikes"
        case "hands_elbows":
            return "Elbow Strikes"
        case "hands_stick_rifle":
            return "Stick / Rifle Strikes"
        case "topic_ready_stance":
            return "Ready Stance"
        case "topic_ground_prep":
            return "Groundwork Preparation"
        case "topic_kavaler":
            return "Kavaler"
        case "topic_breakfalls_rolls":
            return "Breakfalls and Rolls"
        default:
            if let titleFromId = KmiEnglishTitleResolver.englishTitle(for: cleanId) {
                return titleFromId
            }

            return KmiEnglishTitleResolver.title(for: cleanTitle, isEnglish: true)
        }
    }
    
    private func accentForTopicSubject(_ subject: SubjectTopic) -> Color {
        let id = subject.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let title = subject.titleHeb.trimmingCharacters(in: .whitespacesAndNewlines)

        if id.contains("internal") || title.contains("פנימ") {
            return Color.green.opacity(0.82)
        }

        if id.contains("external") || title.contains("חיצונ") {
            return Color.blue.opacity(0.82)
        }

        if id.contains("kick") || title.contains("בעיטה") {
            return Color.orange.opacity(0.85)
        }

        if id.contains("release") || title.contains("שחרור") || title.contains("חביקה") {
            return Color.blue.opacity(0.72)
        }

        if id.contains("hand") || id.contains("punch") || title.contains("יד") || title.contains("מרפק") {
            return Color.red.opacity(0.78)
        }

        return accentForTopic(
            MainTopic(
                id: subject.id,
                titleHeb: subject.titleHeb,
                subjects: [subject]
            )
        )
    }

    private func symbolForSubjectInline(_ subject: SubjectTopic) -> String {
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
    
    private func postTopicTopTitleOverride() {
        guard !embeddedMode else { return }

        NotificationCenter.default.post(
            name: Notification.Name("KMI_TOP_TITLE_OVERRIDE"),
            object: tr("תרגילים לפי נושא", "Exercises by Topic")
        )
    }
    
    private var quickViewSideRail:
        some View {

        Button {

            triggerTapHaptic()

            showQuickActionsDialog =
                true

        } label: {

            ZStack {

                UnevenRoundedRectangle(
                    topLeadingRadius:
                        isEnglish
                            ? 0
                            : 18,
                    bottomLeadingRadius:
                        isEnglish
                            ? 0
                            : 18,
                    bottomTrailingRadius:
                        isEnglish
                            ? 18
                            : 0,
                    topTrailingRadius:
                        isEnglish
                            ? 18
                            : 0,
                    style:
                        .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [
                            activeBeltFill
                                .opacity(
                                    0.84
                                ),
                            activeBeltFill,
                            activeBeltFill
                                .opacity(
                                    0.88
                                )
                        ],
                        startPoint:
                            .top,
                        endPoint:
                            .bottom
                    )
                )

                Image(
                    systemName:
                        "line.3.horizontal"
                )
                .kmiIconSize(
                    26
                )
                .foregroundStyle(
                    .white
                )
            }
            .frame(
                width:
                    38,
                height:
                    72
            )
        }
        .buttonStyle(
            .plain
        )
    }
    
    private var isQuickActionLocked: Bool {

        let _ =
            accessRefreshTick

        return LockedContentPolicy
            .currentAccessMode() ==
            .locked
    }
    
    private var quickActionsDialog: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture {
                    showQuickActionsDialog = false
                }

            VStack(spacing: 0) {
                HStack {
                    Button {
                        showQuickActionsDialog = false
                    } label: {
                        Image(systemName: "xmark")
                            .kmiFont(
                                size: 17,
                                weight: .black
                            )
                            .foregroundStyle(
                                activeBeltFill.opacity(0.86)
                            )
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(
                        tr(
                            "תפריט מהיר",
                            "Quick menu"
                        )
                    )
                    .kmiFont(
                                            size: 25,
                                            weight: .black
                                        )
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.66)
                    .foregroundStyle(
                        activeBeltFill.opacity(0.94)
                    )
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 4)

                quickActionRow(
                    title: tr("נקודות תורפה", "Weak points"),
                    icon: "exclamationmark.triangle",
                    locked: isQuickActionLocked
                ) {
                    nav.push(.weakPoints(belt: belt))
                }

                quickActionRow(
                    title: tr("תרגול", "Practice"),
                    icon: "figure.martial.arts",
                    locked: isQuickActionLocked
                ) {
                    nav.push(.practice(belt: belt, topicTitle: "__ALL__"))
                }

                quickActionRow(
                    title: tr("עוזר קולי", "Voice assistant"),
                    icon: "mic",
                    locked: isQuickActionLocked
                ) {
                    nav.push(.voiceAssistant)
                }
            }
            .padding(.bottom, 12)
            .frame(maxWidth: 330)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.98),
                                activeBeltFill.opacity(0.08),
                                Color.white.opacity(0.96)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(activeBeltFill.opacity(0.34), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 10)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .zIndex(50)
    }

    private func quickActionRow(
        title: String,
        icon: String,
        locked: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            triggerTapHaptic()
            showQuickActionsDialog = false

            if locked {
                nav.push(.subscriptionPlans)
                return
            }

            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .kmiFont(
                        size: 17,
                        weight: .black
                    )
                    .foregroundStyle(
                        activeBeltFill.opacity(0.84)
                    )
                    .frame(width: 38, height: 38)
                    .background(
                        activeBeltFill.opacity(0.12)
                    )
                    .clipShape(Circle())

                if locked {
                    Image(systemName: "lock.fill")
                        .kmiFont(
                            size: 12,
                            weight: .bold
                        )
                        .foregroundStyle(
                            activeBeltFill.opacity(0.88)
                        )
                }

                Text(title)
                    .kmiFont(
                        size: 19,
                        weight: .heavy
                    )
                    .foregroundStyle(
                        activeBeltFill.opacity(0.94)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.64)
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
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .background(Color.white.opacity(0.001))
        }
        .buttonStyle(.plain)
        .overlay(
            Rectangle()
                .fill(activeBeltFill.opacity(0.12))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var topicQuestionsModeSwitcher:
        some View {

        HStack(spacing: 0) {

            Button {
                // כבר נמצאים ב-By Topic.
            } label: {

                topicModeTab(
                    title:
                        tr(
                            "לפי נושא",
                            "By Topic"
                        ),
                    isSelected:
                        true
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

                triggerTapHaptic()

                if let onSwitchToByBelt {

                    onSwitchToByBelt()

                } else {

                    /*
                     * By Topic נפתח מעל By Belt.
                     *
                     * לא מוסיפים עוד Route.
                     * פשוט חוזרים אחורה.
                     */
                    nav.pop()
                }

            } label: {

                topicModeTab(
                    title:
                        tr(
                            "לפי חגורה",
                            "By Belt"
                        ),
                    isSelected:
                        false
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

    private func topicModeTab(
        title: String,
        isSelected: Bool
    ) -> some View {

        ZStack(
            alignment:
                .bottom
        ) {

            Text(title)
                .kmiTypography(
                    .action
                )
                .foregroundStyle(
                    KmiAppTheme
                        .sectionHeaderContentColor
                        .opacity(
                            isSelected
                                ? 1.0
                                : 0.82
                        )
                )
                .lineLimit(1)
                .minimumScaleFactor(
                    0.70
                )
                .frame(
                    maxWidth:
                        .infinity,
                    maxHeight:
                        .infinity
                )

            if isSelected {

                Rectangle()
                    .fill(
                        KmiAppTheme
                            .sectionHeaderContentColor
                    )
                    .frame(
                        maxWidth:
                            .infinity
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
            maxWidth:
                .infinity,
            maxHeight:
                .infinity
        )
        .contentShape(
            Rectangle()
        )
    }
    
    private var topicsScreenContent: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if !embeddedMode {
                    topicQuestionsModeSwitcher
                }

                topicsCardContent
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                    .frame(maxHeight: .infinity)
                    .background(
                        RoundedRectangle(
                            cornerRadius: 22,
                            style: .continuous
                        )
                        .fill(
                            colorScheme == .dark
                                ? Color(
                                    red: 0.055,
                                    green: 0.075,
                                    blue: 0.115
                                )
                                .opacity(0.97)
                                : Color.white.opacity(0.96)
                        )
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: 22,
                            style: .continuous
                        )
                        .stroke(
                            colorScheme == .dark
                                ? Color.white.opacity(0.14)
                                : Color.black.opacity(0.06),
                            lineWidth: 1
                        )
                    )
                    .shadow(
                        color: Color.black.opacity(
                            colorScheme == .dark
                                ? 0.32
                                : 0.08
                        ),
                        radius: 9,
                        x: 0,
                        y: 4
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 22,
                            style: .continuous
                        )
                    )
                    .padding(.horizontal, 18)
            }
            .frame(
                width: geometry.size.width,
                height: geometry.size.height
            )
        }
    }

    private var topicsCardContent: some View {
        VStack(
            alignment:
                isEnglish
                ? .leading
                : .trailing,
            spacing: 14
        ) {
            Text(
                tr(
                    "נושאים (קטגוריות)",
                    "Subjects (Categories)"
                )
            )
            .kmiFont(
                size: 14,
                weight: .heavy
            )
            .foregroundStyle(
                colorScheme == .dark
                    ? Color.white.opacity(0.94)
                    : Color.black.opacity(0.84)
            )
            .frame(
                maxWidth: .infinity,
                alignment: .center
            )
            .multilineTextAlignment(.center)

            topicsRowsContent
        }
    }

    private var topicsRowsContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 6) {
                ForEach(
                    mainTopics,
                    id: \.id
                ) { topic in

                    topicRowContent(
                        topic
                    )
                }

                if mainTopics.isEmpty {
                    emptyTopicsMessage
                }
            }
            .padding(.bottom, 6)
        }
    }

    private func topicRowContent(
        _ topic: MainTopic
    ) -> some View {
        let hasSubTopics =
            topic.subjects.count > 1

        let isExpanded =
            expandedMainTopicId == topic.id

        let accent =
            accentForTopic(topic)

        return VStack(spacing: 0) {
            Button {
                openTopic(topic)
            } label: {
                TopicRowCard(
                    title:
                        displayTitle(
                            for: topic
                        ),
                    accent: accent,
                    subtitleTop:
                        subtitleLineTop(
                            for: topic
                        ),
                    subtitleBottom:
                        subtitleLineBottom(
                            for: topic
                        ),
                    isEnglish: isEnglish,
                    symbolName:
                        symbolForTopic(topic),
                    imageName:
                        imageNameForTopic(topic),
                    isLocked:
                        isTopicLocked(topic),
                    hasSubTopics: hasSubTopics,
                    isExpanded: isExpanded
                )
            }
            .buttonStyle(.plain)

            if hasSubTopics && isExpanded {
                expandedSubTopicsBlock(
                    for: topic,
                    accent: accent
                )
            }
        }
    }

    private var emptyTopicsMessage: some View {
        Text(
            tr(
                "אין נושאים להצגה",
                "No topics to display"
            )
        )
        .kmiFont(
            size: 16,
            weight: .semibold
        )
        .foregroundStyle(
            colorScheme == .dark
                ? Color.white.opacity(0.62)
                : Color.black.opacity(0.55)
        )
        .multilineTextAlignment(.center)
        .frame(
            maxWidth: .infinity,
            alignment: .center
        )
        .multilineTextAlignment(.center)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var quickRailLayer:
        some View {

        if !embeddedMode {

            GeometryReader {
                geometry in

                quickViewSideRail
                    .position(
                        x:
                            isEnglish
                                ? 19
                                : geometry
                                    .size
                                    .width
                                    - 19,
                        y:
                            88 + 36
                    )
            }
            .environment(
                \.layoutDirection,
                .leftToRight
            )
            .frame(
                maxWidth:
                    .infinity,
                maxHeight:
                    .infinity
            )
            .zIndex(
                40
            )
        }
    }

    @ViewBuilder
    private var quickDialogLayer: some View {
        if !embeddedMode &&
            showQuickActionsDialog {
            quickActionsDialog
        }
    }
    var body: some View {
        ZStack {
            KmiAppBackground()
            topicsScreenContent
            quickRailLayer
            quickDialogLayer
        }
        .environment(
            \.layoutDirection,
             screenLayoutDirection
        )
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            
            loadMainTopicsIfNeeded()
            
            onActiveBeltChange?(
                belt
            )
            
            postTopicTopTitleOverride()
            
            DispatchQueue.main.async {
                
                postTopicTopTitleOverride()
            }
        }
        .onChange(
            of: belt
        ) { _, newValue in
            
            clearTopicCountCaches()
            
            expandedMainTopicId =
            nil
            
            onActiveBeltChange?(
                newValue
            )
            
            /*
             * מבנה הנושאים הראשי חוצה חגורות
             * ולכן לא צריך לבנות את Registry מחדש
             * בכל מעבר חגורה.
             */
            postTopicTopTitleOverride()
            
            DispatchQueue.main.async {
                
                postTopicTopTitleOverride()
            }
        }
        .onChange(
            of: scenePhase
        ) { _, newPhase in
            guard newPhase == .active else {
                return
            }
            
            accessRefreshTick += 1
        }
        .onReceive(
            NotificationCenter.default
                .publisher(
                    for:
                        UserDefaults
                        .didChangeNotification
                )
        ) { _ in
            accessRefreshTick += 1
        }
        
        // אין שימוש במסך הקטלוג הישן.
        
        /*
         * Android parity:
         * מסכי העומק נשארים תחת המעטפת הגלובלית,
         * כולל כותרת, סרגל אייקונים ופקודות קוליות.
         */
    }
}

private struct TopicPulsingLockBadge: View {
    @State private var pulse: Bool = false
    
    var body: some View {
        Image(systemName: "lock.fill")
            .kmiFont(
                size: 13,
                weight: .black
            )
            .foregroundStyle(
                Color.orange.opacity(0.92)
            )
            .frame(
                minWidth: 28,
                minHeight: 28
            )
            .background(
                Circle()
                    .fill(Color.orange.opacity(0.12))
            )
            .overlay(
                Circle()
                    .stroke(Color.orange.opacity(0.24), lineWidth: 1)
            )
            .scaleEffect(pulse ? 1.12 : 1.0)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.78)
                    .repeatForever(autoreverses: true)
                ) {
                    pulse = true
                }
            }
    }
}

private struct SubjectSectionsListView: View {

    let belt: Belt
    let subject: SubjectTopic
    let onPickSection: (String) -> Void

    @Environment(\.colorScheme)
    private var colorScheme

    @AppStorage("kmi_app_language")
    private var kmiAppLanguageCode: String = "he"
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

    private func exercisesCountText(_ count: Int) -> String {
        if isEnglish {
            return "exercises \(count)"
        } else {
            return "\(count) תרגילים"
        }
    }

    private func uiSubjectTitle(_ subject: SubjectTopic) -> String {
        let cleanId = subject.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = subject.titleHeb.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isEnglish else { return cleanTitle }

        switch cleanId {
        case "def_internal_punch", "def_internal_punches", "def_internal":
            return "Internal Defenses"
        case "def_external_punch", "def_external_punches", "def_external":
            return "External Defenses"
        case "kicks_hard":
            return "Defenses Against Kicks"
        case "knife_defense":
            return "Knife Defenses"
        case "gun_threat_defense":
            return "Gun Threat Defenses"
        case "stick_defense":
            return "Stick Defenses"
        case "releases_hands_hair_shirt":
            return "Releases from Hand / Hair / Shirt Grabs"
        case "releases_chokes":
            return "Choke Releases"
        case "releases_hugs":
            return "Hug Releases"
        case "hands_strikes":
            return "Hand Strikes"
        case "hands_elbows":
            return "Elbow Strikes"
        case "hands_stick_rifle":
            return "Stick / Rifle Strikes"
        case "topic_ready_stance":
            return "Ready Stance"
        case "topic_ground_prep":
            return "Groundwork Preparation"
        case "topic_kavaler":
            return "Kavaler"
        case "topic_breakfalls_rolls":
            return "Breakfalls and Rolls"
        default:
            if let titleFromId = KmiEnglishTitleResolver.englishTitle(for: cleanId) {
                return titleFromId
            }

            return KmiEnglishTitleResolver.title(for: cleanTitle, isEnglish: true)
        }
    }

    private func uiSectionTitle(_ section: HardSectionsCatalog.Section) -> String {
        let cleanId = section.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = section.title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isEnglish else { return cleanTitle }

        switch cleanId {
        case "def_internal_punch", "def_internal_punches", "def_internal":
            return "Internal Defenses"
        case "def_internal_kick", "def_internal_kicks":
            return "Internal Defenses - Kicks"
        case "def_external_punch", "def_external_punches", "def_external":
            return "External Defenses"
        case "def_external_kick", "def_external_kicks":
            return "External Defenses - Kicks"
        case "kicks_hard":
            return "Defenses Against Kicks"
        case "knife_defense":
            return "Knife Defenses"
        case "gun_threat_defense":
            return "Gun Threat Defenses"
        case "stick_defense":
            return "Stick Defenses"
        case "releases_hands_hair_shirt":
            return "Releases from Hand / Hair / Shirt Grabs"
        case "releases_chokes":
            return "Choke Releases"
        case "releases_hugs":
            return "Hug Releases"
        case "hands_strikes":
            return "Hand Strikes"
        case "hands_elbows":
            return "Elbow Strikes"
        case "hands_stick_rifle":
            return "Stick / Rifle Strikes"
        case "topic_ready_stance":
            return "Ready Stance"
        case "topic_ground_prep":
            return "Groundwork Preparation"
        case "topic_kavaler":
            return "Kavaler"
        case "topic_breakfalls_rolls":
            return "Breakfalls and Rolls"
        default:
            break
        }

        switch cleanTitle {
        case "שחרור מתפיסות ידיים / שיער / חולצה":
            return "Releases from Hand / Hair / Shirt Grabs"
        case "שחרור מחניקות":
            return "Choke Releases"
        case "שחרור מחביקות":
            return "Hug Releases"
        case "חביקות גוף":
            return "Body Hugs"
        case "חביקות צואר":
            return "Neck Hugs"
        case "חביקות זרוע":
            return "Arm Hugs"
        case "הגנות עם רובה נגד דקירות סכין":
            return "Rifle Defenses Against Knife Stabs"
        case "הגנות נגד מספר תוקפים":
            return "Multiple Attackers Defense"
        case "מכות יד":
            return "Hand Strikes"
        case "מכות מרפק":
            return "Elbow Strikes"
        case "מכות במקל / רובה":
            return "Stick / Rifle Strikes"
        case "עבודת קרקע":
            return "Groundwork Preparation"
        case "קוואלר":
            return "Kavaler"
        default:
            break
        }

        if let titleFromId = KmiEnglishTitleResolver.englishTitle(for: cleanId) {
            return titleFromId
        }

        return KmiEnglishTitleResolver.title(for: cleanTitle, isEnglish: true)
    }

    private func toSharedSubject(_ local: SubjectTopic) -> Shared.SubjectTopic {
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

    private func syntheticSubject(
        id: String,
        titleHeb: String,
        topicsByBelt: [Belt: [String]],
        subTopicHint: String? = nil,
        includeItemKeywords: [String] = [],
        requireAllItemKeywords: [String] = [],
        excludeItemKeywords: [String] = []
    ) -> SubjectTopic {
        SubjectTopic(
            id: id,
            titleHeb: titleHeb,
            description: "",
            belts: Array(topicsByBelt.keys),
            topicsByBelt: topicsByBelt,
            subTopicHint: subTopicHint,
            includeItemKeywords: includeItemKeywords,
            requireAllItemKeywords: requireAllItemKeywords,
            excludeItemKeywords: excludeItemKeywords
        )
    }
    
    private var defenseRootSubjects: [SubjectTopic] {
        let candidates: [SubjectTopic] = [
            syntheticSubject(
                id: "def_internal_punch",
                titleHeb: "הגנות פנימיות",
                topicsByBelt: [.yellow: ["הגנות"], .orange: ["הגנות"], .green: ["הגנות"], .blue: ["הגנות"], .brown: ["הגנות"], .black: ["הגנות"]]
            ),
            syntheticSubject(
                id: "def_external_punch",
                titleHeb: "הגנות חיצוניות",
                topicsByBelt: [.yellow: ["הגנות"], .orange: ["הגנות"], .green: ["הגנות"], .blue: ["הגנות"], .brown: ["הגנות"], .black: ["הגנות"]]
            ),
            syntheticSubject(
                id: "kicks_hard",
                titleHeb: "הגנות נגד בעיטות",
                topicsByBelt: [.yellow: ["הגנות"], .orange: ["הגנות"], .green: ["הגנות"], .blue: ["הגנות"], .brown: ["הגנות"], .black: ["הגנות"]]
            ),
            syntheticSubject(
                id: "knife_defense",
                titleHeb: "הגנות מסכין",
                topicsByBelt: [.green: ["הגנות"], .blue: ["הגנות"], .brown: ["הגנות"], .black: ["הגנות"]],
                subTopicHint: "סכין",
                excludeItemKeywords: ["מקל", "אקדח", "תמ\"ק"]
            ),
            syntheticSubject(
                id: "gun_threat_defense",
                titleHeb: "הגנות מאיום אקדח",
                topicsByBelt: [.green: ["הגנות"], .blue: ["הגנות"], .brown: ["הגנות"], .black: ["הגנות"]],
                subTopicHint: "אקדח",
                excludeItemKeywords: ["סכין", "מקל", "תמ\"ק"]
            ),
            syntheticSubject(
                id: "stick_defense",
                titleHeb: "הגנות נגד מקל",
                topicsByBelt: [.green: ["הגנות"], .blue: ["הגנות"], .brown: ["הגנות"], .black: ["הגנות"]],
                subTopicHint: "מקל",
                excludeItemKeywords: ["סכין", "אקדח"]
            )
        ]

        return candidates.filter { subject in
            let sections = SubjectItemsResolver.shared.resolveBySubject(
                belt: belt,
                subject: toSharedSubject(subject)
            )
            return sections.contains { !$0.items.isEmpty }
        }
    }
    
    private var sections: [HardSectionsCatalog.Section] {
        if subject.id == "def_internal_punch" {
            let punchSections = HardSectionsCatalog.shared.sectionsForSubject(subjectId: "def_internal_punch") ?? []
            let kickSections = HardSectionsCatalog.shared.sectionsForSubject(subjectId: "def_internal_kick") ?? []
            return punchSections + kickSections
        }

        if subject.id == "def_external_punch" {
            let punchSections = HardSectionsCatalog.shared.sectionsForSubject(subjectId: "def_external_punch") ?? []
            let kickSections = HardSectionsCatalog.shared.sectionsForSubject(subjectId: "def_external_kick") ?? []
            return punchSections + kickSections
        }

        return HardSectionsCatalog.shared.sectionsForSubject(subjectId: subject.id) ?? []
    }

    private func triggerTapHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    private func accentForTitle(_ title: String) -> Color {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if t.contains("פנימ") {
            return Color.green.opacity(0.82)
        }

        if t.contains("חיצונ") {
            return Color.blue.opacity(0.82)
        }

        if t.contains("סכין") {
            return Color.orange.opacity(0.88)
        }

        if t.contains("אקדח") {
            return Color.red.opacity(0.82)
        }

        if t.contains("מקל") || t.contains("רובה") {
            return Color.brown.opacity(0.82)
        }

        if t.contains("שחרורים") || t.contains("שחרור") || t.contains("חביקות") {
            return Color.blue.opacity(0.72)
        }

        if t.contains("בעיטות") || t.contains("בעיטה") {
            return Color.orange.opacity(0.85)
        }

        if t.contains("אגרופים") || t.contains("אגרוף") || t.contains("ידיים") || t.contains("יד") || t.contains("מרפק") {
            return Color.red.opacity(0.78)
        }

        if t.contains("בלימות") || t.contains("גלגולים") {
            return Color.purple.opacity(0.78)
        }

        return Color.black.opacity(0.25)
    }

    private func symbolForSection(_ section: HardSectionsCatalog.Section) -> String {
        let id = section.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let title = section.title.trimmingCharacters(in: .whitespacesAndNewlines)

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

        if id.contains("release") || title.contains("שחרור") || title.contains("חביקות") {
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
    
    private func itemsForSection(
        _ section: HardSectionsCatalog.Section,
        belt: Belt
    ) -> [String] {
        if !section.subSections.isEmpty {
            return section.subSections.flatMap { itemsForSection($0, belt: belt) }
        }

        return section.beltGroups
            .filter { $0.belt == belt }
            .flatMap { $0.items }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func totalItemsCountForSection(
        _ section: HardSectionsCatalog.Section
    ) -> Int {
        if !section.subSections.isEmpty {
            return section.subSections.reduce(0) { partial, child in
                partial + totalItemsCountForSection(child)
            }
        }

        return section.beltGroups.reduce(0) { partial, group in
            partial + group.items.count
        }
    }

    private struct SectionRowCard: View {
        let title: String
        let accent: Color
        let subtitleBottom: String
        let isEnglish: Bool
        let symbolName: String

        @Environment(\.colorScheme)
        private var colorScheme

        private var isDarkMode: Bool {
            colorScheme == .dark
        }

        private var titleColor: Color {
            isDarkMode
                ? Color.white.opacity(0.92)
                : Color.black.opacity(0.84)
        }

        private var secondaryTextColor: Color {
            isDarkMode
                ? Color.white.opacity(0.64)
                : Color.black.opacity(0.56)
        }

        private var textAlignment: TextAlignment {
            isEnglish ? .leading : .trailing
        }

        private var frameAlignment: Alignment {
            isEnglish ? .leading : .trailing
        }

        private var stackAlignment: HorizontalAlignment {
            isEnglish ? .leading : .trailing
        }

        var body: some View {
            HStack(spacing: 12) {
                if isEnglish {
                    accentBar
                    visualBlock
                    textBlock

                    Image(systemName: "chevron.right")
                        .kmiFont(
                            size: 13,
                            weight: .bold
                        )
                        .foregroundStyle(
                            isDarkMode
                                ? Color.white.opacity(0.52)
                                : Color.black.opacity(0.30)
                        )
                } else {
                    Image(systemName: "chevron.left")
                        .kmiFont(
                            size: 13,
                            weight: .bold
                        )
                        .foregroundStyle(
                            isDarkMode
                                ? Color.white.opacity(0.52)
                                : Color.black.opacity(0.30)
                        )

                    textBlock
                    visualBlock
                    accentBar
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(
                    cornerRadius: 17,
                    style: .continuous
                )
                .fill(
                    isDarkMode
                        ? Color(
                            red: 0.06,
                            green: 0.08,
                            blue: 0.12
                        )
                        : Color.white.opacity(0.94)
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 17,
                    style: .continuous
                )
                .stroke(
                    isDarkMode
                        ? Color.white.opacity(0.12)
                        : Color.black.opacity(0.05),
                    lineWidth: 1
                )
            )
            .shadow(
                color:
                    Color.black.opacity(
                        isDarkMode ? 0.26 : 0.045
                    ),
                radius: 5,
                x: 0,
                y: 2
            )
        }

        private var textBlock: some View {
            VStack(
                alignment: stackAlignment,
                spacing: 7
            ) {
                Text(title)
                    .kmiFont(
                        size: 19,
                        weight: .heavy
                    )
                    .foregroundStyle(titleColor)
                    .frame(
                        maxWidth: .infinity,
                        alignment: frameAlignment
                    )
                    .multilineTextAlignment(textAlignment)
                    .lineLimit(2)
                    .minimumScaleFactor(0.66)

                Text(subtitleBottom)
                    .kmiFont(
                        size: 12,
                        weight: .semibold
                    )
                    .foregroundStyle(secondaryTextColor)
                    .frame(
                        maxWidth: .infinity,
                        alignment: frameAlignment
                    )
                    .multilineTextAlignment(textAlignment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.64)
            }
        }

        private var visualBlock: some View {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.22),
                            accent.opacity(0.08),
                            Color.white.opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(accent.opacity(0.26), lineWidth: 1)
                )
                .overlay(
                    Image(systemName: symbolName)
                        .kmiFont(
                            size: 22,
                            weight: .heavy
                        )
                        .foregroundStyle(accent)
                )
                .frame(
                    minWidth: 62,
                    minHeight: 52
                )
        }

        private var accentBar: some View {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(accent)
                .frame(width: 6, height: 52)
        }
    }

    private var selectionHeaderTitle: some View {
        VStack(
            alignment:
                isEnglish
                ? .leading
                : .trailing,
            spacing: 3
        ) {
            Text(
                uiSubjectTitle(subject)
            )
            .kmiFont(
                size: 22,
                weight: .heavy
            )
            .foregroundStyle(
                colorScheme == .dark
                    ? Color.white.opacity(0.94)
                    : Color.black.opacity(0.84)
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
            .minimumScaleFactor(0.68)

            Text(
                tr(
                    "בחר תת נושא",
                    "Choose a sub-topic"
                )
            )
            .kmiFont(
                size: 13,
                weight: .bold
            )
            .foregroundStyle(
                colorScheme == .dark
                    ? Color.white.opacity(0.62)
                    : Color.black.opacity(0.50)
            )
            .frame(
                maxWidth: .infinity,
                alignment:
                    isEnglish
                    ? .leading
                    : .trailing
            )
        }
    }

    private var selectionHeaderIcon: some View {
        Image(
            systemName:
                "square.grid.2x2.fill"
        )
        .kmiFont(
            size: 18,
            weight: .heavy
        )
        .foregroundStyle(
            colorScheme == .dark
                ? Color.purple.opacity(0.96)
                : Color.purple.opacity(0.72)
        )
        .frame(
            minWidth: 38,
            minHeight: 38
        )
        .background(
            Color.purple.opacity(
                colorScheme == .dark
                    ? 0.18
                    : 0.10
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 13,
                style: .continuous
            )
        )
    }

    private var selectionHeader: some View {
        HStack(spacing: 10) {
            if isEnglish {
                selectionHeaderTitle
                selectionHeaderIcon
            } else {
                selectionHeaderIcon
                selectionHeaderTitle
            }
        }
        .environment(
            \.layoutDirection,
            .leftToRight
        )
    }
    
    var body: some View {
        ZStack {
            KmiAppBackground()

            ScrollView {
                VStack(
                    alignment:
                        isEnglish
                        ? .leading
                        : .trailing,
                    spacing: 14
                ) {
                    selectionHeader

                        VStack(spacing: 12) {
                            ForEach(Array(sections.enumerated()), id: \.element.id) { _, section in
                                let title = section.title.trimmingCharacters(in: .whitespacesAndNewlines)
                                let count = totalItemsCountForSection(section)

                                Button {
                                    triggerTapHaptic()
                                    onPickSection(section.id)
                                } label: {
                                    SectionRowCard(
                                        title: uiSectionTitle(section),
                                        accent: accentForTitle(title),
                                        subtitleBottom: exercisesCountText(count),
                                        isEnglish: isEnglish,
                                        symbolName: symbolForSection(section)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(
                        cornerRadius: 22,
                        style: .continuous
                    )
                    .fill(
                        colorScheme == .dark
                            ? Color(
                                red: 0.055,
                                green: 0.075,
                                blue: 0.115
                            )
                            .opacity(0.97)
                            : Color.white.opacity(0.96)
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 22,
                        style: .continuous
                    )
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.14)
                            : Color.black.opacity(0.06),
                        lineWidth: 1
                    )
                )
                .shadow(
                    color:
                        Color.black.opacity(
                            colorScheme == .dark
                                ? 0.32
                                : 0.08
                        ),
                    radius: 9,
                    x: 0,
                    y: 4
                )
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
        }
        .environment(\.layoutDirection, screenLayoutDirection)
        .navigationTitle(uiSubjectTitle(subject))
        .navigationBarTitleDisplayMode(.inline)
    }
}
