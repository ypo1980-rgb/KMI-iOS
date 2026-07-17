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

    @EnvironmentObject private var nav:
        AppNavModel

    @Environment(\.scenePhase)
    private var scenePhase

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

    @State private var pickedMainTopic: MainTopic? = nil
    @State private var expandedMainTopicId: String? = nil
    @State private var pickedSectionedSubject: SubjectTopic? = nil
    @State private var pickedAcrossBeltsSubject: SubjectTopic? = nil
    @State private var pickedAcrossBeltsSubTopicTitle:
        String? = nil

    @State private var showQuickActionsDialog:
        Bool = false

    @State private var accessRefreshTick:
        Int = 0

    private var mainTopics: [MainTopic] {

        let visibleRootSubjects =
            TopicsBySubjectRegistry
                .allSubjects()
                .filter { subjectHasVisibleContentInAnyBelt($0) }

        let visibleRegistryChildren =
            TopicsBySubjectRegistry
                .all
                .filter { subject in
                    subject.parentId != nil &&
                    subjectHasVisibleContentInAnyBelt(subject)
                }

        func rootSubject(_ id: String) -> SubjectTopic? {
            let cleanId = id
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            return visibleRootSubjects.first { subject in
                subject.id
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased() == cleanId
            }
        }

        func childSubjects(parentId: String) -> [SubjectTopic] {
            let cleanParentId = parentId
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            return visibleRegistryChildren.filter { subject in
                subject.parentId?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased() == cleanParentId
            }
        }

        var out: [MainTopic] = []

        let defenseSubjects = defenseRootSubjects
        let releaseSubjects = childSubjects(parentId: "releases")

        if !defenseSubjects.isEmpty {
            out.append(
                MainTopic(
                    id: "defense_root",
                    titleHeb: "הגנות",
                    subjects: defenseSubjects
                )
            )
        }

        if !releaseSubjects.isEmpty {
            out.append(
                MainTopic(
                    id: "releases",
                    titleHeb: "שחרורים",
                    subjects:
                        releaseSubjects
                )
            )
        } else if let releasesRoot =
                    rootSubject(
                        "releases"
                    ) {
            out.append(
                MainTopic(
                    id: "releases",
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
                    id: "hands_root",
                    titleHeb: "עבודת ידיים",
                    subjects: visibleHandsSubjects
                )
            )
        } else if let handsRoot = rootSubject("hands_all") {
            out.append(
                MainTopic(
                    id: "hands_root",
                    titleHeb: handsRoot.titleHeb,
                    subjects: [handsRoot]
                )
            )
        }

        if let rollsSubject = rootSubject("rolls_breakfalls") {
            out.append(
                MainTopic(
                    id: "rolls_breakfalls",
                    titleHeb: rollsSubject.titleHeb,
                    subjects: [rollsSubject]
                )
            )
        }

        if let readySubject = rootSubject("topic_ready_stance") {
            out.append(
                MainTopic(
                    id: "topic_ready_stance",
                    titleHeb: readySubject.titleHeb,
                    subjects: [readySubject]
                )
            )
        }

        if let groundSubject = rootSubject("topic_ground_prep") {
            out.append(
                MainTopic(
                    id: "topic_ground_prep",
                    titleHeb: groundSubject.titleHeb,
                    subjects: [groundSubject]
                )
            )
        }

        if let kavalerSubject = rootSubject("topic_kavaler") {
            out.append(
                MainTopic(
                    id: "topic_kavaler",
                    titleHeb: kavalerSubject.titleHeb,
                    subjects: [kavalerSubject]
                )
            )
        }

        if let kicksSubject =
            rootSubject(
                "kicks"
            ) {
            out.append(
                MainTopic(
                    id: "kicks",
                    titleHeb:
                        kicksSubject
                            .titleHeb,
                    subjects: [
                        kicksSubject
                    ]
                )
            )
        }

        /*
         * Android מציג גם נושאי Root נוספים שמגיעים
         * מה-Registry ואינם חלק מהכרטיסים המאוחדים
         * הגנות / שחרורים / עבודת ידיים.
         *
         * הרשימה הבאה אינה מקור תוכן נוסף. היא כוללת
         * רק מזהי קבוצות שכבר נבנו למעלה, כדי למנוע
         * הצגה כפולה של אותם נושאים.
         */
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

        var representedSubjectIds =
            Set<String>()

        for topic in out {
            representedSubjectIds.insert(
                normalizedSubjectId(
                    topic.id
                )
            )

            for subject
                in topic.subjects {
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
                    ) else {
                    return false
                }

                return !representedSubjectIds
                    .contains(
                        cleanId
                    )
            }

        for subject
            in remainingRootSubjects {
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

            guard !cleanId.isEmpty,
                  !cleanTitle.isEmpty else {
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
                    id: cleanId,
                    titleHeb:
                        cleanTitle,
                    subjects:
                        cardSubjects
                )
            )

            representedSubjectIds.insert(
                cleanId
            )

            for child
                in visibleChildren {
                representedSubjectIds.insert(
                    normalizedSubjectId(
                        child.id
                    )
                )
            }
        }

        /*
         * הגנה נוספת מפני כפילות אם ה-Registry מחזיר
         * בעתיד אותו Root יותר מפעם אחת.
         */
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

        private var textAlignment: TextAlignment {
            isEnglish ? .leading : .trailing
        }

        private var frameAlignment: Alignment {
            isEnglish ? .leading : .trailing
        }

        private var stackAlignment: HorizontalAlignment {
            isEnglish ? .leading : .trailing
        }

        private var navigationIconName: String {
            if hasSubTopics {
                return isExpanded ? "chevron.up" : "chevron.down"
            }

            return isEnglish ? "chevron.right" : "chevron.left"
        }

        var body: some View {
            HStack(spacing: 12) {
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
            .environment(\.layoutDirection, .leftToRight)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.18),
                                accent.opacity(0.08),
                                Color.white.opacity(0.92)
                            ],
                            startPoint: .trailing,
                            endPoint: .leading
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(isLocked ? Color.orange.opacity(0.38) : Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.045), radius: 5, x: 0, y: 2)
        }

        private var navigationIcon: some View {
            Image(systemName: navigationIconName)
                .font(.system(size: hasSubTopics ? 14 : 13, weight: .bold))
                .foregroundStyle(
                    hasSubTopics
                    ? accent.opacity(0.82)
                    : Color.black.opacity(0.30)
                )
                .frame(width: 18)
        }

        private var textBlock: some View {
            VStack(alignment: stackAlignment, spacing: 3) {
                Text(title)
                    .font(.system(size: 13.5, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.84))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                
                if let top = subtitleTop, !top.isEmpty {
                    Text(top)
                        .font(.system(size: 10.5, weight: .heavy))
                        .foregroundStyle(accent.opacity(0.86))
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                        .multilineTextAlignment(textAlignment)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Text(subtitleBottom)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.56))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }

        private var visualBlock: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.16),
                                Color.white.opacity(0.98),
                                accent.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(accent.opacity(0.26), lineWidth: 1)
                    )

                if let imageName {
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 54, height: 39)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(Color.white.opacity(0.72), lineWidth: 1)
                        )
                } else {
                    Image(systemName: symbolName)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: 58, height: 50)
        }

        private var accentBar: some View {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(accent)
                .frame(width: 5, height: 50)
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

    private func catalogSubjectExerciseCount(
        _ subject: SubjectTopic
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

        func itemPasses(
            _ item: String,
            subTopicTitle: String?
        ) -> Bool {
            let combined = normalizedItemKey(
                "\(subTopicTitle ?? "") \(item)"
            )

            if let hint = subject.subTopicHint?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !hint.isEmpty,
               !combined.contains(normalizedItemKey(hint)) {
                return false
            }

            let excluded = subject.excludeItemKeywords.contains { keyword in
                let cleanKeyword = normalizedItemKey(keyword)
                return !cleanKeyword.isEmpty &&
                    combined.contains(cleanKeyword)
            }

            if excluded {
                return false
            }

            let requiredKeywords = subject.requireAllItemKeywords
                .map(normalizedItemKey)
                .filter { !$0.isEmpty }

            if !requiredKeywords.isEmpty,
               !requiredKeywords.allSatisfy({ combined.contains($0) }) {
                return false
            }

            let includedKeywords = subject.includeItemKeywords
                .map(normalizedItemKey)
                .filter { !$0.isEmpty }

            if !includedKeywords.isEmpty,
               !includedKeywords.contains(where: { combined.contains($0) }) {
                return false
            }

            return true
        }

        var uniqueItems = Set<String>()

        for oneBelt in subject.belts {
            guard
                let beltContent = ContentRepo.shared.data[oneBelt],
                let mappedTopicTitles = subject.topicsByBelt[oneBelt],
                !mappedTopicTitles.isEmpty
            else {
                continue
            }

            let mappedKeys = Set(
                mappedTopicTitles.map(normalizedTopicKey)
            )

            for topic in beltContent.topics {
                let topicKey = normalizedTopicKey(topic.title)
                let topicIsMapped = mappedKeys.contains(topicKey)

                if topicIsMapped {
                    for item in topic.items {
                        let itemKey = normalizedItemKey(item)

                        if !itemKey.isEmpty {
                            let catalogKey = [
                                oneBelt.id,
                                topicKey,
                                "__topic_items__",
                                itemKey
                            ].joined(separator: "||")

                            uniqueItems.insert(catalogKey)
                        }
                    }
                }

                for subTopic in topic.subTopics {
                    let subTopicKey = normalizedTopicKey(subTopic.title)

                    guard topicIsMapped || mappedKeys.contains(subTopicKey) else {
                        continue
                    }

                    for item in subTopic.items {
                        let itemKey = normalizedItemKey(item)

                        if !itemKey.isEmpty {
                            let catalogKey = [
                                oneBelt.id,
                                topicKey,
                                subTopicKey,
                                itemKey
                            ].joined(separator: "||")

                            uniqueItems.insert(catalogKey)
                        }
                    }
                }
            }
        }

        return uniqueItems.count
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

    // ===============================
    // שחרורים – תתי נושאים
    // ===============================

    private var releasesRootSubjects: [SubjectTopic] {

        [
            syntheticSubject(
                id: "releases_hands_hair_shirt",
                titleHeb: "שחרור מתפיסות ידיים / שיער / חולצה",
                topicsByBelt: [
                    .yellow: ["שחרורים"],
                    .orange: ["שחרורים"],
                    .green: ["שחרורים"]
                ],
                subTopicHint: "שחרור"
            ),

            syntheticSubject(
                id: "releases_chokes",
                titleHeb: "שחרור מחניקות",
                topicsByBelt: [
                    .yellow: ["שחרורים"],
                    .orange: ["שחרורים"],
                    .blue: ["שחרורים"]
                ],
                subTopicHint: "חניקה"
            ),

            syntheticSubject(
                id: "releases_hugs",
                titleHeb: "שחרור מחביקות",
                topicsByBelt: [
                    .yellow: ["שחרורים"],
                    .orange: ["שחרורים"],
                    .green: ["שחרורים"],
                    .black: ["שחרורים"]
                ],
                subTopicHint: "חביקה"
            )
        ]
    }
    
    private var handsRootSubjects: [SubjectTopic] {
        [
            syntheticSubject(
                id: "hands_strikes",
                titleHeb: "מכות יד",
                topicsByBelt: [
                    .yellow: ["עבודת ידיים", "מכות ידיים", "מכות יד"],
                    .orange: ["עבודת ידיים", "מכות יד", "מכות ידיים"]
                ],
                subTopicHint: "מכות יד"
            ),
            syntheticSubject(
                id: "hands_elbows",
                titleHeb: "מכות מרפק",
                topicsByBelt: [
                    .yellow: ["מכות מרפק"],
                    .green: ["מכות מרפק"]
                ],
                subTopicHint: "מרפק"
            ),
            syntheticSubject(
                id: "hands_stick_rifle",
                titleHeb: "מכות במקל / רובה",
                topicsByBelt: [
                    .green: ["מכות במקל / רובה"],
                    .black: ["מכות במקל / רובה", "מכות במקל קצר"]
                ],
                subTopicHint: "מקל"
            )
        ]
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
        guard let subject = topic.subjects.first else {
            return Color.black.opacity(0.25)
        }

        let id = subject.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = subject.titleHeb.trimmingCharacters(in: .whitespacesAndNewlines)

        if id.contains("def_internal") {
            return Color.green.opacity(0.82)
        }

        if id.contains("def_external") {
            return Color.blue.opacity(0.82)
        }

        if id.contains("knife") || title.contains("סכין") {
            return Color.orange.opacity(0.88)
        }

        if id.contains("gun") || title.contains("אקדח") {
            return Color.red.opacity(0.82)
        }

        if id.contains("stick") || title.contains("מקל") {
            return Color.brown.opacity(0.82)
        }

        if id.contains("release") || title.contains("שחרור") {
            return Color.blue.opacity(0.72)
        }

        if id.contains("kick") || title.contains("בעיטות") {
            return Color.orange.opacity(0.85)
        }

        if id.contains("hand") || id.contains("punch") || title.contains("יד") || title.contains("אגרוף") || title.contains("מרפק") {
            return Color.red.opacity(0.78)
        }

        if id.contains("roll") || title.contains("בלימות") || title.contains("גלגולים") {
            return Color.purple.opacity(0.78)
        }

        return Color.black.opacity(0.25)
    }

    private func displayTitle(for topic: MainTopic) -> String {
        let cleanId = topic.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = topic.titleHeb.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isEnglish else { return cleanTitle }

        switch cleanId {
        case "defenses_root":
            return "Defenses"
        case "hands_root":
            return "Hand Techniques"
        case "releases_root":
            return "Releases"
        case "throws_root":
            return "Throws"
        case "topic_kavaler":
            return "Kavaler"
        case "kicks_root":
            return "Kicks"
        case "topic_ground_prep":
            return "Groundwork Preparation"
        case "topic_breakfalls_rolls":
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

    private func releaseSection(
        withId sectionId: String
    ) -> HardSectionsCatalog.Section? {
        let roots =
            HardSectionsCatalog.shared.sectionsForSubject(
                subjectId: "releases"
            ) ?? []

        func find(
            in sections: [HardSectionsCatalog.Section]
        ) -> HardSectionsCatalog.Section? {
            for section in sections {
                if section.id
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    == sectionId {
                    return section
                }

                if let child = find(in: section.subSections) {
                    return child
                }
            }

            return nil
        }

        return find(in: roots)
    }

    private func releaseSectionCount(
        sectionId: String,
        currentBelt: Belt
    ) -> Int {
        guard let section = releaseSection(withId: sectionId) else {
            return 0
        }

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

        func countForCurrentBelt(
            _ currentSection: HardSectionsCatalog.Section
        ) -> Int {
            if !currentSection.subSections.isEmpty {
                return currentSection.subSections.reduce(0) { partial, child in
                    partial + countForCurrentBelt(child)
                }
            }

            let keys = currentSection.beltGroups
                .filter { $0.belt == currentBelt }
                .flatMap { $0.items }
                .map(normalizedItemKey)
                .filter { !$0.isEmpty }

            return Set(keys).count
        }

        func countForAllBelts(
            _ currentSection: HardSectionsCatalog.Section
        ) -> Int {
            if !currentSection.subSections.isEmpty {
                return currentSection.subSections.reduce(0) { partial, child in
                    partial + countForAllBelts(child)
                }
            }

            let keys = currentSection.beltGroups
                .flatMap { $0.items }
                .map(normalizedItemKey)
                .filter { !$0.isEmpty }

            return Set(keys).count
        }

        let currentBeltCount = countForCurrentBelt(section)

        return currentBeltCount > 0
            ? currentBeltCount
            : countForAllBelts(section)
    }

    private func handsSectionExerciseKeys(
        sectionId: String
    ) -> Set<String> {
        let roots =
            HardSectionsCatalog.shared.sectionsForSubject(
                subjectId: "hands_all"
            ) ?? []

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

        func findSection(
            in sections: [HardSectionsCatalog.Section]
        ) -> HardSectionsCatalog.Section? {
            for section in sections {
                let cleanSectionId = section.id
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if cleanSectionId == sectionId {
                    return section
                }

                if let found = findSection(in: section.subSections) {
                    return found
                }
            }

            return nil
        }

        func collectKeys(
            from section: HardSectionsCatalog.Section
        ) -> Set<String> {
            if !section.subSections.isEmpty {
                return section.subSections.reduce(into: Set<String>()) {
                    partial, child in

                    partial.formUnion(
                        collectKeys(from: child)
                    )
                }
            }

            let keys = section.beltGroups
                .flatMap { $0.items }
                .map(normalizedItemKey)
                .filter { !$0.isEmpty }

            return Set(keys)
        }

        guard let section = findSection(in: roots) else {
            return []
        }

        return collectKeys(from: section)
    }

    private func subjectForCounting(
        _ subjectId: String
    ) -> SubjectTopic? {
        let cleanSubjectId = subjectId
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let registrySubject =
            TopicsBySubjectRegistry.subjectById(cleanSubjectId) {
            return registrySubject
        }

        return handsRootSubjects.first { subject in
            subject.id
                .trimmingCharacters(in: .whitespacesAndNewlines)
                == cleanSubjectId
        }
    }

    private func exerciseKeys(
        for subject: SubjectTopic,
        beltsToResolve: [Belt]? = nil
    ) -> Set<String> {
        let resolvedBelts = beltsToResolve ?? [
            .yellow,
            .orange,
            .green,
            .blue,
            .brown,
            .black
        ]

        var uniqueExerciseKeys = Set<String>()

        for oneBelt in resolvedBelts {
            let sections = SubjectItemsResolver.shared.resolveBySubject(
                belt: oneBelt,
                subject: toSharedSubject(subject)
            )

            for section in sections {
                for item in section.items {
                    let mirror = Mirror(reflecting: item)

                    let canonicalId =
                        mirror.children.first {
                            $0.label == "canonicalId"
                        }?.value as? String

                    let displayName =
                        mirror.children.first {
                            $0.label == "displayName"
                        }?.value as? String

                    let rawKey =
                        canonicalId
                        ?? displayName
                        ?? String(describing: item)

                    let normalizedKey = rawKey
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

                    if !normalizedKey.isEmpty {
                        uniqueExerciseKeys.insert(normalizedKey)
                    }
                }
            }
        }

        return uniqueExerciseKeys
    }

    private func totalExercisesCountForSubjectId(
        _ subjectId: String
    ) -> Int {
        let cleanSubjectId = subjectId
            .trimmingCharacters(in: .whitespacesAndNewlines)

        switch cleanSubjectId {
        case "releases_hands_hair_shirt":
            return releaseSectionCount(
                sectionId: "releases_hands_hair_shirt",
                currentBelt: belt
            )

        case "releases_chokes":
            return releaseSectionCount(
                sectionId: "releases_chokes",
                currentBelt: belt
            )

        case "releases_hugs":
            return releaseSectionCount(
                sectionId: "releases_hugs",
                currentBelt: belt
            )

        case "hands_strikes",
             "hands_elbows",
             "hands_stick_rifle":
            guard let subject = subjectForCounting(cleanSubjectId) else {
                return 0
            }

            return SubjectAcrossBeltsView.resolvedExerciseCount(
                subject: subject
            )

        default:
            break
        }

        guard let subject = subjectForCounting(cleanSubjectId) else {
            return 0
        }

        if cleanSubjectId == "rolls_breakfalls" {
            return exerciseKeys(
                for: subject,
                beltsToResolve: [belt]
            ).count
        }

        return exerciseKeys(for: subject).count
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

    private func subtitleLineBottom(
        for topic: MainTopic
    ) -> String {
        let stats =
            KmiExerciseCountProvider
                .topicStats(
                    belt: belt,
                    topicTitle:
                        topic.titleHeb
                )

        let total =
            stats.exerciseCount > 0
                ? stats.exerciseCount
                : totalExercisesCount(
                    for: topic
                )

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
                stats: displayStats,
                isEnglish: isEnglish
            )
    }

    private func triggerTapHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    private func openTopic(_ topic: MainTopic) {
        triggerTapHaptic()

        if isTopicLocked(topic) {
            nav.push(.subscriptionPlans)
            return
        }

        pickedMainTopic = topic

        if topic.subjects.count > 1 {
            withAnimation(.easeInOut(duration: 0.22)) {
                expandedMainTopicId = expandedMainTopicId == topic.id ? nil : topic.id
            }
            return
        }

        guard let subject = topic.subjects.first else {
            return
        }

        openSubjectFromInlineList(subject)
    }

    private func openSubjectFromInlineList(_ subject: SubjectTopic) {
        triggerTapHaptic()

        let sections = resolvedSections(for: subject)

        if sections.count == 1 {
            pickedAcrossBeltsSubject = subject
            pickedAcrossBeltsSubTopicTitle = sections.first?.title
        } else {
            // Android parity:
            // אחרי בחירת תת־נושא מתוך "לפי נושא" פותחים את מסך התרגילים,
            // ולא מסך ביניים נוסף של תתי־נושאים.
            pickedAcrossBeltsSubject = subject
            pickedAcrossBeltsSubTopicTitle = nil
        }
    }

    @ViewBuilder
    private func expandedSubTopicsBlock(
        for topic: MainTopic,
        accent: Color
    ) -> some View {
        VStack(spacing: 7) {
            ForEach(Array(topic.subjects.enumerated()), id: \.offset) { _, subject in
                Button {
                    openSubjectFromInlineList(subject)
                } label: {
                    inlineSubTopicRow(
                        subject: subject,
                        accent: accent
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 11)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.10),
                            Color.white.opacity(0.74),
                            accent.opacity(0.06)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func inlineSubTopicRow(
        subject: SubjectTopic,
        accent: Color
    ) -> some View {
        HStack(spacing: 10) {
            if isEnglish {
                inlineSubTopicIcon(subject: subject, accent: accent)

                inlineSubTopicText(subject: subject, isEnglish: isEnglish)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accent.opacity(0.70))
            } else {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accent.opacity(0.70))

                inlineSubTopicText(subject: subject, isEnglish: isEnglish)

                inlineSubTopicIcon(subject: subject, accent: accent)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(0.86))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(accent.opacity(0.11), lineWidth: 1)
        )
    }

    private func inlineSubTopicText(
        subject: SubjectTopic,
        isEnglish: Bool
    ) -> some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 2) {
            Text(uiSubjectTitleForInline(subject))
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Color.black.opacity(0.84))
                .frame(
                    maxWidth: .infinity,
                    alignment: isEnglish ? .leading : .trailing
                )
                .multilineTextAlignment(isEnglish ? .leading : .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.80)

            Text(
                exercisesCountText(
                    displayedExerciseCount(
                        for: subject
                    )
                )
            )
                .font(.system(size: 10.5, weight: .black))
                .foregroundStyle(accentForTopicSubject(subject).opacity(0.90))
                .frame(
                    maxWidth: .infinity,
                    alignment: isEnglish ? .leading : .trailing
                )
                .multilineTextAlignment(isEnglish ? .leading : .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
    }

    private func inlineSubTopicIcon(
        subject: SubjectTopic,
        accent: Color
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accent.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(accent.opacity(0.18), lineWidth: 1)
                )

            Image(systemName: symbolForSubjectInline(subject))
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(accent.opacity(0.86))
        }
        .frame(width: 30, height: 30)
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
    
    private var quickViewSideRail: some View {
        Button {
            triggerTapHaptic()
            showQuickActionsDialog = true
        } label: {
            VStack(spacing: 9) {
                Image(systemName: "line.3.horizontal")
                    .font(
                        .system(
                            size: 19,
                            weight: .black
                        )
                    )

                Text(tr("מהיר", "Quick"))
                    .font(
                        .system(
                            size: 13,
                            weight: .black
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .rotationEffect(.degrees(90))
                    .frame(width: 54, height: 20)
            }
            .foregroundStyle(Color.white)
            .frame(width: 46, height: 126)
            .background(
                RoundedRectangle(cornerRadius: 0, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                activeBeltFill.opacity(0.95),
                                activeBeltFill.opacity(0.72)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 18,
                    bottomLeadingRadius: 18,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                )
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 16,
                    topTrailingRadius: 16
                )
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(0.22),
                radius: 8,
                x: -2,
                y: 4
            )
        }
        .buttonStyle(.plain)
    }
   
    private var isQuickActionLocked:
        Bool {
        let _ = accessRefreshTick

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
                            .font(
                                .system(
                                    size: 17,
                                    weight: .bold
                                )
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
                    .font(
                        .system(
                            size: 25,
                            weight: .heavy
                        )
                    )
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
                    .font(
                        .system(
                            size: 17,
                            weight: .bold
                        )
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
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(activeBeltFill.opacity(0.88))
                }

                Text(title)
                    .font(
                        .system(
                            size: 19,
                            weight: .heavy
                        )
                    )
                    .foregroundStyle(
                        activeBeltFill.opacity(0.94)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
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

    private var topicsScreenContent: some View {
        GeometryReader { geometry in
            let availableHeight =
                geometry.size.height - 10

            let cardHeight =
                max(
                    CGFloat(360),
                    availableHeight
                )

            WhiteCard {
                topicsCardContent
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
            }
            .frame(height: cardHeight)
            .padding(.horizontal, 18)
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
            .font(
                .system(
                    size: 14,
                    weight: .heavy
                )
            )
            .foregroundStyle(
                Color.black.opacity(0.84)
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
                    Array(
                        mainTopics.enumerated()
                    ),
                    id: \.offset
                ) { _, topic in
                    topicRowContent(topic)
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
        .font(
            .system(
                size: 16,
                weight: .semibold
            )
        )
        .foregroundStyle(
            Color.black.opacity(0.55)
        )
        .frame(
            maxWidth: .infinity,
            alignment: .center
        )
        .multilineTextAlignment(.center)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var quickRailLayer: some View {
        if !embeddedMode {
            GeometryReader { geometry in
                quickViewSideRail
                    .position(
                        x:
                            UIScreen.main.bounds.width -
                            23,
                        y:
                            geometry.size.height / 2
                    )
            }
            .environment(
                \.layoutDirection,
                .leftToRight
            )
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
            .zIndex(40)
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
            onActiveBeltChange?(belt)

            postTopicTopTitleOverride()

            DispatchQueue.main.async {
                postTopicTopTitleOverride()
            }

            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.12
            ) {
                postTopicTopTitleOverride()
            }
        }
        .onChange(
            of: belt
        ) { _, newValue in
            onActiveBeltChange?(
                newValue
            )

            postTopicTopTitleOverride()

            DispatchQueue.main.async {
                postTopicTopTitleOverride()
            }

            DispatchQueue.main
                .asyncAfter(
                    deadline:
                        .now() + 0.12
                ) {
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
                        Notification.Name(
                            "KMI_ACCESS_CHANGED"
                        )
                )
        ) { _ in
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
        .navigationDestination(
            item: $pickedAcrossBeltsSubject
        ) { subject in
            let sectionTitle =
                pickedAcrossBeltsSubTopicTitle?
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

            let subjectTitle =
                uiSubjectTitleForInline(subject)
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

            let destinationTitle: String = {
                if let sectionTitle,
                   !sectionTitle.isEmpty {
                    return sectionTitle
                }

                if !subjectTitle.isEmpty {
                    return subjectTitle
                }

                return tr(
                    "תרגילים לפי נושא",
                    "Exercises by Topic"
                )
            }()

            KmiRootLayout(
                title: destinationTitle,
                nav: nav,
                selectedIcon: .home
            ) {
                SubjectAcrossBeltsView(
                    subject: subject,
                    forcedSectionTitle:
                        pickedAcrossBeltsSubTopicTitle
                )
                .navigationBarBackButtonHidden(true)
            }
        }
        .navigationDestination(
            item: $pickedSectionedSubject
        ) { subject in
            let subjectTitle =
                uiSubjectTitleForInline(subject)
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

            let destinationTitle =
                subjectTitle.isEmpty
                ? tr(
                    "תרגילים לפי נושא",
                    "Exercises by Topic"
                )
                : subjectTitle

            KmiRootLayout(
                title: destinationTitle,
                nav: nav,
                selectedIcon: .home
            ) {
                SubjectSectionsListView(
                    belt: belt,
                    subject: subject,
                    onPickSection: { section in
                        pickedAcrossBeltsSubject =
                            subject

                        pickedAcrossBeltsSubTopicTitle =
                            section
                    }
                )
                .navigationBarBackButtonHidden(true)
            }
        }
    }
}

private struct TopicPulsingLockBadge: View {
    @State private var pulse: Bool = false
    
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 13, weight: .black))
            .foregroundStyle(Color.orange.opacity(0.92))
            .frame(width: 28, height: 28)
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

private struct SubjectSubTopicsListView: View {

    let belt: Belt
    let mainTopic: MainTopic
    let onPickSubject: (SubjectTopic) -> Void

    @Environment(\.dismiss) private var dismiss

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

        if let titleFromId = KmiEnglishTitleResolver.englishTitle(for: cleanId) {
            return titleFromId
        }

        return KmiEnglishTitleResolver.title(for: cleanTitle, isEnglish: true)
    }

    private func uiMainTopicTitle(_ topic: MainTopic) -> String {
        let cleanId = topic.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = topic.titleHeb.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isEnglish else { return cleanTitle }

        switch cleanId {
        case "defenses_root":
            return "Defenses"
        case "hands_root":
            return "Hand Techniques"
        case "releases_root":
            return "Releases"
        case "throws_root":
            return "Throws"
        case "topic_kavaler":
            return "Kavaler"
        case "kicks_root":
            return "Kicks"
        case "topic_ground_prep":
            return "Groundwork Preparation"
        case "topic_breakfalls_rolls":
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

    private func triggerTapHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    private func accentForTitle(_ title: String) -> Color {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if t.contains("פנימ") { return Color.green.opacity(0.82) }
        if t.contains("חיצונ") { return Color.blue.opacity(0.82) }
        if t.contains("סכין") { return Color.orange.opacity(0.88) }
        if t.contains("אקדח") { return Color.red.opacity(0.82) }
        if t.contains("מקל") || t.contains("רובה") { return Color.brown.opacity(0.82) }
        if t.contains("שחרור") || t.contains("חביקות") { return Color.blue.opacity(0.72) }
        if t.contains("בעיטה") { return Color.orange.opacity(0.85) }
        if t.contains("אגרוף") || t.contains("יד") || t.contains("מרפק") { return Color.red.opacity(0.78) }
        if t.contains("בלימות") || t.contains("גלגולים") { return Color.purple.opacity(0.78) }

        return Color.black.opacity(0.25)
    }

    private func symbolForSubject(_ subject: SubjectTopic) -> String {
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

    private func totalExercisesCount(for subject: SubjectTopic) -> Int {
        func countSections(_ sections: [HardSectionsCatalog.Section]) -> Int {
            sections.reduce(0) { partial, section in
                partial + totalItemsCountForSection(section)
            }
        }

        func findMatchingSections(
            in sections: [HardSectionsCatalog.Section],
            subject: SubjectTopic
        ) -> [HardSectionsCatalog.Section] {
            var out: [HardSectionsCatalog.Section] = []

            for section in sections {
                let sameId =
                    section.id.trimmingCharacters(in: .whitespacesAndNewlines)
                    == subject.id.trimmingCharacters(in: .whitespacesAndNewlines)

                let sameTitle =
                    section.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    == subject.titleHeb.trimmingCharacters(in: .whitespacesAndNewlines)

                if sameId || sameTitle {
                    out.append(section)
                }

                out.append(contentsOf: findMatchingSections(in: section.subSections, subject: subject))
            }

            return out
        }

        func countFromCatalog(topicTitles: [String]) -> Int {
            let normalizedTitles = Set(topicTitles.map { normalizedTopicKey($0) })

            let beltsToCheck: [Belt] = [.yellow, .orange, .green, .blue, .brown, .black]

            return beltsToCheck.reduce(0) { partial, oneBelt in
                guard let beltContent = ContentRepo.shared.data[oneBelt] else { return partial }

                let topicCount = beltContent.topics.reduce(0) { topicPartial, topic in
                    let topicKey = normalizedTopicKey(topic.title)

                    if normalizedTitles.contains(topicKey) {
                        return topicPartial
                            + topic.items.count
                            + topic.subTopics.reduce(0) { $0 + $1.items.count }
                    }

                    let matchingSubTopicsCount = topic.subTopics.reduce(0) { subPartial, subTopic in
                        let subTopicKey = normalizedTopicKey(subTopic.title)
                        return subPartial + (normalizedTitles.contains(subTopicKey) ? subTopic.items.count : 0)
                    }

                    return topicPartial + matchingSubTopicsCount
                }

                return partial + topicCount
            }
        }

        if subject.id == "def_internal_punch" {
            let punchSections = HardSectionsCatalog.shared.sectionsForSubject(subjectId: "def_internal_punch") ?? []
            let kickSections = HardSectionsCatalog.shared.sectionsForSubject(subjectId: "def_internal_kick") ?? []
            let total = countSections(punchSections) + countSections(kickSections)

            if total > 0 {
                return total
            }
        }

        if subject.id == "def_external_punch" {
            let punchSections = HardSectionsCatalog.shared.sectionsForSubject(subjectId: "def_external_punch") ?? []
            let kickSections = HardSectionsCatalog.shared.sectionsForSubject(subjectId: "def_external_kick") ?? []
            let total = countSections(punchSections) + countSections(kickSections)

            if total > 0 {
                return total
            }
        }

        let directSections =
            HardSectionsCatalog.shared.sectionsForSubject(subjectId: subject.id) ?? []

        let directCount = countSections(directSections)
        if directCount > 0 {
            return directCount
        }

        if subject.id == "hands_strikes" || subject.id == "hands_elbows" || subject.id == "hands_stick_rifle" {
            let allHands =
                HardSectionsCatalog.shared.sectionsForSubject(subjectId: "hands_all") ?? []

            let matching = findMatchingSections(in: allHands, subject: subject)
            let handsCount = countSections(matching)

            if handsCount > 0 {
                return handsCount
            }
        }

        let catalogTitlesBySubjectId: [String: [String]] = [
            "hands_stick_rifle": ["מכות במקל / רובה", "מכות במקל קצר"]
        ]

        if let topicTitles = catalogTitlesBySubjectId[subject.id] {
            let catalogCount = countFromCatalog(topicTitles: topicTitles)

            if catalogCount > 0 {
                return catalogCount
            }
        }

        return 0
    }
    
    private struct SubTopicRowCard: View {
        let title: String
        let accent: Color
        let subtitleBottom: String
        let isEnglish: Bool
        let symbolName: String

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
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.30))
                } else {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.30))

                    textBlock
                    visualBlock
                    accentBar
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color.white.opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.045), radius: 5, x: 0, y: 2)
        }

        private var textBlock: some View {
            VStack(alignment: stackAlignment, spacing: 5) {
                Text(title)
                    .font(.system(size: 14.5, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.84))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                
                Text(subtitleBottom)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.56))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
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
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(accent)
                )
                .frame(width: 62, height: 52)
        }

        private var accentBar: some View {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(accent)
                .frame(width: 6, height: 52)
        }
    }

    var body: some View {
        ZStack {
            KmiAppBackground()

            ScrollView {
                WhiteCard {
                    VStack(alignment: isEnglish ? .leading : .trailing, spacing: 9) {
                        HStack(spacing: 10) {
                            if isEnglish {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(uiMainTopicTitle(mainTopic))
                                        .font(.system(size: 22, weight: .heavy))
                                        .foregroundStyle(Color.black.opacity(0.84))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .multilineTextAlignment(.leading)

                                    Text(tr("בחר תת נושא", "Choose a sub-topic"))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Color.black.opacity(0.50))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                Image(systemName: "square.grid.2x2.fill")
                                    .font(.system(size: 18, weight: .heavy))
                                    .foregroundStyle(Color.purple.opacity(0.72))
                                    .frame(width: 38, height: 38)
                                    .background(Color.purple.opacity(0.10))
                                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            } else {
                                Image(systemName: "square.grid.2x2.fill")
                                    .font(.system(size: 18, weight: .heavy))
                                    .foregroundStyle(Color.purple.opacity(0.72))
                                    .frame(width: 38, height: 38)
                                    .background(Color.purple.opacity(0.10))
                                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(uiMainTopicTitle(mainTopic))
                                        .font(.system(size: 22, weight: .heavy))
                                        .foregroundStyle(Color.black.opacity(0.84))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .multilineTextAlignment(.trailing)

                                    Text(tr("בחר תת נושא", "Choose a sub-topic"))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Color.black.opacity(0.50))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                            }
                        }

                        VStack(spacing: 12) {
                            ForEach(Array(mainTopic.subjects.enumerated()), id: \.offset) { _, subject in
                                Button {
                                    triggerTapHaptic()
                                    dismiss()

                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        onPickSubject(subject)
                                    }
                                } label: {
                                    SubTopicRowCard(
                                        title: uiSubjectTitle(subject),
                                        accent: accentForTitle(subject.titleHeb),
                                        subtitleBottom: exercisesCountText(totalExercisesCount(for: subject)),
                                        isEnglish: isEnglish,
                                        symbolName: symbolForSubject(subject)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 14)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
        }
        .environment(\.layoutDirection, screenLayoutDirection)
        .navigationTitle(uiMainTopicTitle(mainTopic))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SubjectSectionsListView: View {

    let belt: Belt
    let subject: SubjectTopic
    let onPickSection: (String) -> Void

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

    private var handsRootSubjects: [SubjectTopic] {
        [
            syntheticSubject(
                id: "hands_strikes",
                titleHeb: "מכות יד",
                topicsByBelt: [
                    .yellow: ["עבודת ידיים", "מכות ידיים", "מכות יד"],
                    .orange: ["עבודת ידיים", "מכות יד", "מכות ידיים"]
                ],
                subTopicHint: "מכות יד"
            ),
            syntheticSubject(
                id: "hands_elbows",
                titleHeb: "מכות מרפק",
                topicsByBelt: [
                    .yellow: ["מכות מרפק"],
                    .green: ["מכות מרפק"]
                ],
                subTopicHint: "מרפק"
            ),
            syntheticSubject(
                id: "hands_stick_rifle",
                titleHeb: "מכות במקל / רובה",
                topicsByBelt: [
                    .green: ["מכות במקל / רובה"],
                    .black: ["מכות במקל / רובה", "מכות במקל קצר"]
                ],
                subTopicHint: "מקל"
            )
        ]
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
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.30))
                } else {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.30))

                    textBlock
                    visualBlock
                    accentBar
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color.white.opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.045), radius: 5, x: 0, y: 2)
        }

        private var textBlock: some View {
            VStack(alignment: stackAlignment, spacing: 7) {
                Text(title)
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.84))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
                    .lineLimit(2)

                Text(subtitleBottom)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.56))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
                    .lineLimit(1)
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
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(accent)
                )
                .frame(width: 62, height: 52)
        }

        private var accentBar: some View {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(accent)
                .frame(width: 6, height: 52)
        }
    }
    
    var body: some View {
        ZStack {
            KmiAppBackground()

            ScrollView {
                WhiteCard {
                    VStack(alignment: isEnglish ? .leading : .trailing, spacing: 14) {
                        HStack(spacing: 10) {
                            if isEnglish {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(uiSubjectTitle(subject))
                                        .font(.system(size: 22, weight: .heavy))
                                        .foregroundStyle(Color.black.opacity(0.84))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .multilineTextAlignment(.leading)

                                    Text(tr("בחר תת נושא", "Choose a sub-topic"))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Color.black.opacity(0.50))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                Image(systemName: "square.grid.2x2.fill")
                                    .font(.system(size: 18, weight: .heavy))
                                    .foregroundStyle(Color.purple.opacity(0.72))
                                    .frame(width: 38, height: 38)
                                    .background(Color.purple.opacity(0.10))
                                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            } else {
                                Image(systemName: "square.grid.2x2.fill")
                                    .font(.system(size: 18, weight: .heavy))
                                    .foregroundStyle(Color.purple.opacity(0.72))
                                    .frame(width: 38, height: 38)
                                    .background(Color.purple.opacity(0.10))
                                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(uiSubjectTitle(subject))
                                        .font(.system(size: 22, weight: .heavy))
                                        .foregroundStyle(Color.black.opacity(0.84))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .multilineTextAlignment(.trailing)

                                    Text(tr("בחר תת נושא", "Choose a sub-topic"))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Color.black.opacity(0.50))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                            }
                        }

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
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
        }
        .environment(\.layoutDirection, screenLayoutDirection)
        .navigationTitle(uiSubjectTitle(subject))
        .navigationBarTitleDisplayMode(.inline)
    }
}
