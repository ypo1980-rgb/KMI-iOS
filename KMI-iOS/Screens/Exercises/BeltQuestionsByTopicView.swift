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

    @EnvironmentObject private var nav: AppNavModel
    private let catalog = CatalogData.shared.data

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
            return count == 1 ? "1 exercise" : "\(count) exercises"
        } else {
            return count == 1 ? "תרגיל 1" : "\(count) תרגילים"
        }
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
    @State private var pickedAcrossBeltsSubTopicTitle: String? = nil
    @State private var showQuickActionsDialog: Bool = false
    
    private var mainTopics: [MainTopic] {

        let allSubjects = TopicsBySubjectRegistry.allSubjects()

        let visibleSubjects = allSubjects.filter { subject in
            subjectHasVisibleContentInAnyBelt(subject)
        }

        func firstVisible(
            ids: [String] = [],
            exactTitles: [String] = [],
            titleContains: [String] = []
        ) -> SubjectTopic? {
            let normalizedIds = ids.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }

            if let exactIdMatch = visibleSubjects.first(where: { subject in
                normalizedIds.contains(
                    subject.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                )
            }) {
                return exactIdMatch
            }

            if let exactTitleMatch = visibleSubjects.first(where: { subject in
                exactTitles.contains(
                    subject.titleHeb.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }) {
                return exactTitleMatch
            }

            return visibleSubjects.first { subject in
                let subjectTitle = subject.titleHeb.trimmingCharacters(in: .whitespacesAndNewlines)
                return titleContains.contains { fragment in
                    subjectTitle.contains(fragment)
                }
            }
        }

        var out: [MainTopic] = []

        // ✅ בלימות וגלגולים
        let rollsSubject =
            firstVisible(
                ids: ["topic_breakfalls_rolls"],
                exactTitles: ["בלימות וגלגולים"],
                titleContains: []
            )
            ?? syntheticSubject(
                id: "topic_breakfalls_rolls",
                titleHeb: "בלימות וגלגולים",
                topicsByBelt: [
                    .yellow: ["בלימות וגלגולים"],
                    .orange: ["בלימות וגלגולים"],
                    .green: ["בלימות וגלגולים"],
                    .blue: ["בלימות וגלגולים"],
                    .brown: ["בלימות וגלגולים"]
                ]
            )

        // ✅ עמידת מוצא
        let readySubject =
            firstVisible(
                ids: ["topic_ready_stance", "ready_stance", "stance_ready"],
                exactTitles: ["עמידת מוצא"],
                titleContains: ["עמידת מוצא"]
            )
            ?? syntheticSubject(
                id: "topic_ready_stance",
                titleHeb: "עמידת מוצא",
                topicsByBelt: [
                    .yellow: ["עמידת מוצא"],
                    .orange: ["עמידת מוצא"],
                    .green: ["עמידת מוצא"],
                    .blue: ["עמידת מוצא"],
                    .brown: ["עמידת מוצא"],
                    .black: ["עמידת מוצא"]
                ]
            )

        // ✅ הכנה לקרקע
        let groundSubject =
            firstVisible(
                ids: ["topic_ground_prep", "ground_prep", "ground_preparation"],
                exactTitles: ["הכנה לעבודת קרקע"],
                titleContains: ["הכנה לעבודת", "קרקע"]
            )
            ?? syntheticSubject(
                id: "topic_ground_prep",
                titleHeb: "הכנה לעבודת קרקע",
                topicsByBelt: [
                    .orange: ["הכנה לעבודת קרקע"],
                    .green: ["הכנה לעבודת קרקע"],
                    .blue: ["הכנה לעבודת קרקע"],
                    .brown: ["הכנה לעבודת קרקע"],
                    .black: ["הכנה לעבודת קרקע"]
                ]
            )

        // ✅ קאוולר
        let kawalSubject =
            firstVisible(
                ids: ["topic_kawalr", "topic_kawal", "kawalr", "kawal"],
                exactTitles: ["קאוולר", "קאוול"],
                titleContains: ["קאוול", "קאוולר"]
            )
            ?? syntheticSubject(
                id: "topic_kawalr",
                titleHeb: "קאוולר",
                topicsByBelt: [
                    .green: ["קאוולר", "קאוול"],
                    .blue: ["קאוולר", "קאוול"],
                    .brown: ["קאוולר", "קאוול"],
                    .black: ["קאוולר", "קאוול"]
                ]
            )

        // ✅ שחרורים
        let releasesSubjects = releasesRootSubjects
        
        // ✅ בעיטות
        let kicksSubject =
            firstVisible(
                ids: ["kicks_hard", "kicks", "topic_kicks"],
                exactTitles: ["בעיטות"],
                titleContains: []
            )
            ?? syntheticSubject(
                id: "kicks_hard",
                titleHeb: "בעיטות",
                topicsByBelt: [
                    .yellow: ["בעיטות"],
                    .orange: ["בעיטות"],
                    .green: ["בעיטות"],
                    .blue: ["בעיטות"],
                    .brown: ["בעיטות"],
                    .black: ["בעיטות"]
                ]
            )
        
        // ✅ הטלות
        let throwsSubjects = visibleSubjects.filter {
            $0.titleHeb.contains("הטלה") ||
            $0.titleHeb.contains("הטלות")
        }

        // ✅ סדר כמו Android:
        // הגנות -> שחרורים -> עבודת ידיים -> בלימות -> עמידת מוצא -> עבודת קרקע -> קאוולר -> בעיטות -> הטלות

        if !defenseRootSubjects.isEmpty {
            out.append(
                MainTopic(id: "defenses_root", titleHeb: "הגנות", subjects: defenseRootSubjects)
            )
        }

        if !releasesSubjects.isEmpty {
            out.append(
                MainTopic(
                    id: "releases_root",
                    titleHeb: "שחרורים",
                    subjects: releasesSubjects
                )
            )
        }

        if !handsRootSubjects.isEmpty {
            out.append(
                MainTopic(id: "hands_root", titleHeb: "עבודת ידיים", subjects: handsRootSubjects)
            )
        }

        if subjectHasVisibleContentInAnyBelt(rollsSubject) {
            out.append(
                MainTopic(id: "topic_breakfalls_rolls", titleHeb: "בלימות וגלגולים", subjects: [rollsSubject])
            )
        }

        if subjectHasVisibleContentInAnyBelt(readySubject) {
            out.append(
                MainTopic(id: "topic_ready_stance", titleHeb: "עמידת מוצא", subjects: [readySubject])
            )
        }

        if subjectHasVisibleContentInAnyBelt(groundSubject) {
            out.append(
                MainTopic(id: "topic_ground_prep", titleHeb: "עבודת קרקע", subjects: [groundSubject])
            )
        }

        if subjectHasVisibleContentInAnyBelt(kawalSubject) {
            out.append(
                MainTopic(id: "topic_kawalr", titleHeb: "קאוולר", subjects: [kawalSubject])
            )
        }

        if subjectHasVisibleContentInAnyBelt(kicksSubject) {
            out.append(
                MainTopic(id: "kicks_root", titleHeb: "בעיטות", subjects: [kicksSubject])
            )
        }

        if !throwsSubjects.isEmpty {
            out.append(
                MainTopic(id: "throws_root", titleHeb: "הטלות", subjects: throwsSubjects)
            )
        }

        return out
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
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color.white.opacity(0.94))
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
            VStack(alignment: stackAlignment, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.84))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
                    .lineLimit(2)

                if let top = subtitleTop, !top.isEmpty {
                    Text(top)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(accent.opacity(0.86))
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                        .multilineTextAlignment(textAlignment)
                        .lineLimit(1)
                }

                Text(subtitleBottom)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.56))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
                    .lineLimit(1)
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
                        .frame(width: 54, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(Color.white.opacity(0.72), lineWidth: 1)
                        )
                } else {
                    Image(systemName: symbolName)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: 58, height: 46)
        }

        private var accentBar: some View {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(accent)
                .frame(width: 4, height: 38)
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
            let beltContent = catalog[belt],
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
                excludeItemKeywords: ["מקל", "אקדח", "תמ\"ק"]
            ),
            syntheticSubject(
                id: "gun_threat_defense",
                titleHeb: "הגנות מאיום אקדח",
                topicsByBelt: [
                    .green: ["הגנות"],
                    .blue: ["הגנות"],
                    .brown: ["הגנות"],
                    .black: ["הגנות"]
                ],
                subTopicHint: "אקדח",
                excludeItemKeywords: ["סכין", "מקל", "תמ\"ק"]
            ),
            syntheticSubject(
                id: "stick_defense",
                titleHeb: "הגנות נגד מקל",
                topicsByBelt: [
                    .green: ["הגנות"],
                    .blue: ["הגנות"],
                    .brown: ["הגנות"],
                    .black: ["הגנות"]
                ],
                subTopicHint: "מקל",
                excludeItemKeywords: ["סכין", "אקדח"]
            )
        ]

        return candidates.filter { subject in
            totalExercisesCountForSubjectId(subject.id) > 0
        }
    }
    
    private func isPremiumTopic(_ topic: MainTopic) -> Bool {
        LockedContentPolicy.isTopicRestricted(topic.titleHeb) ||
        LockedContentPolicy.isTopicRestricted(displayTitle(for: topic)) ||
        topic.id.lowercased().contains("defense") ||
        topic.id.lowercased().contains("release")
    }

    private func isTopicLocked(_ topic: MainTopic) -> Bool {
        let accessMode = LockedContentPolicy.currentAccessMode()
        return LockedContentPolicy.shouldShowLock(
            accessMode: accessMode,
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
        case "topic_kawalr":
            return "Cavalier"
        case "kicks_root":
            return "Kicks"
        case "topic_ground_prep":
            return "Groundwork"
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

    private func totalExercisesCountForSubjectId(_ subjectId: String) -> Int {
        func countSections(_ sections: [HardSectionsCatalog.Section]) -> Int {
            sections.reduce(0) { partial, section in
                partial + totalItemsCountForSection(section)
            }
        }

        func countFromCatalog(topicTitles: [String]) -> Int {
            let normalizedTitles = Set(topicTitles.map(normalizedTopicKey))
            let beltsToCheck: [Belt] = [.yellow, .orange, .green, .blue, .brown, .black]

            return beltsToCheck.reduce(0) { partial, oneBelt in
                guard let beltContent = catalog[oneBelt] else {
                    return partial
                }

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

        if subjectId == "def_internal_punch" {
            let punchSections = HardSectionsCatalog.shared.sectionsForSubject(subjectId: "def_internal_punch") ?? []
            let kickSections = HardSectionsCatalog.shared.sectionsForSubject(subjectId: "def_internal_kick") ?? []
            let total = countSections(punchSections) + countSections(kickSections)

            if total > 0 {
                return total
            }
        }

        if subjectId == "def_external_punch" {
            let punchSections = HardSectionsCatalog.shared.sectionsForSubject(subjectId: "def_external_punch") ?? []
            let kickSections = HardSectionsCatalog.shared.sectionsForSubject(subjectId: "def_external_kick") ?? []
            let total = countSections(punchSections) + countSections(kickSections)

            if total > 0 {
                return total
            }
        }

        let directSections = HardSectionsCatalog.shared.sectionsForSubject(subjectId: subjectId) ?? []
        let directCount = countSections(directSections)

        if directCount > 0 {
            return directCount
        }

        if subjectId == "hands_strikes" ||
            subjectId == "hands_elbows" ||
            subjectId == "hands_stick_rifle" {
            let allHands = HardSectionsCatalog.shared.sectionsForSubject(subjectId: "hands_all") ?? []
            let matching = allHands.filter { section in
                section.id == subjectId
            }
            let handsCount = countSections(matching)

            if handsCount > 0 {
                return handsCount
            }
        }

        let catalogTitlesBySubjectId: [String: [String]] = [
            "topic_ready_stance": ["עמידת מוצא"],
            "topic_kawalr": ["קאוולר", "קאוול"],
            "topic_kicks": ["בעיטות"],
            "kicks_hard": ["בעיטות"],
            "topic_breakfalls_rolls": ["בלימות וגלגולים"],
            "topic_ground_prep": ["הכנה לעבודת קרקע"]
        ]

        if let topicTitles = catalogTitlesBySubjectId[subjectId] {
            let catalogCount = countFromCatalog(topicTitles: topicTitles)

            if catalogCount > 0 {
                return catalogCount
            }
        }

        return 0
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
                subject.id == "topic_kawalr" ||
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

    private func subtitleLineTop(for topic: MainTopic) -> String? {
        if topic.id == "releases_root" {
            let count = (HardSectionsCatalog.shared.sectionsForSubject(subjectId: "releases") ?? []).count
            guard count > 0 else { return nil }

            if isEnglish {
                return "sub-topics \(count)"
            } else {
                return "\(count) תתי נושאים"
            }
        }

        let count = topic.subjects.count
        guard count > 1 else { return nil }

        if isEnglish {
            return "sub-topics \(count)"
        } else {
            return "\(count) תתי נושאים"
        }
    }

    private func totalExercisesCount(for topic: MainTopic) -> Int {
        return topic.subjects.reduce(0) { partial, subject in
            partial + totalExercisesCountForSubjectId(subject.id)
        }
    }

    private func subtitleLineBottom(for topic: MainTopic) -> String {
        let total = totalExercisesCount(for: topic)

        if isEnglish {
            return "exercises \(total)"
        } else {
            return "\(total) תרגילים"
        }
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
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
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
                .font(.system(size: 15.5, weight: .heavy))
                .foregroundStyle(Color.black.opacity(0.84))
                .frame(
                    maxWidth: .infinity,
                    alignment: isEnglish ? .leading : .trailing
                )
                .multilineTextAlignment(isEnglish ? .leading : .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(exercisesCountText(totalExercisesCountForSubjectId(subject.id)))
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(accentForTopicSubject(subject).opacity(0.90))
                .frame(
                    maxWidth: .infinity,
                    alignment: isEnglish ? .leading : .trailing
                )
                .multilineTextAlignment(isEnglish ? .leading : .trailing)
                .lineLimit(1)
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
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(accent.opacity(0.86))
        }
        .frame(width: 34, height: 34)
    }

    private func uiSubjectTitleForInline(_ subject: SubjectTopic) -> String {
        let cleanId = subject.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = subject.titleHeb.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isEnglish else { return cleanTitle }

        switch cleanId {
        case "def_internal_punch":
            return "Internal Defenses"
        case "def_external_punch":
            return "External Defenses"
        case "kicks_hard":
            return "Kick Defenses"
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
        NotificationCenter.default.post(
            name: Notification.Name("KMI_TOP_TITLE_OVERRIDE"),
            object: tr("תרגילים לפי נושא", "Exercises by Topic")
        )
    }
    
    private var quickViewButton: some View {
        Button {
            triggerTapHaptic()
            showQuickActionsDialog = true
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .black))

                Text(tr("מבט מהיר", "Quick View"))
                    .font(.system(size: 18, weight: .black))
            }
            .foregroundStyle(activeBeltFill)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                activeBeltFill.opacity(0.10),
                                Color.white.opacity(0.98),
                                activeBeltFill.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(activeBeltFill.opacity(0.24), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
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
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(activeBeltFill.opacity(0.86))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(tr("תפריט מהיר", "Quick menu"))
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(activeBeltFill.opacity(0.94))
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 4)

                quickActionRow(
                    title: tr("נקודות תורפה", "Weak points"),
                    icon: "exclamationmark.triangle",
                    locked: true
                ) {
                    nav.push(.weakPoints(belt: belt))
                }

                quickActionRow(
                    title: tr("תרגול", "Practice"),
                    icon: "figure.martial.arts",
                    locked: true
                ) {
                    nav.push(.practice(belt: belt, topicTitle: "__ALL__"))
                }

                quickActionRow(
                    title: tr("עוזר קולי", "Voice assistant"),
                    icon: "mic",
                    locked: true
                ) {
                    nav.push(.voiceAssistant)
                }
            }
            .padding(.bottom, 10)
            .frame(width: 270)
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
            } else {
                action()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(activeBeltFill.opacity(0.84))
                    .frame(width: 28, height: 28)
                    .background(activeBeltFill.opacity(0.12))
                    .clipShape(Circle())

                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(activeBeltFill.opacity(0.88))
                }

                Text(title)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(activeBeltFill.opacity(0.94))
                    .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
                    .multilineTextAlignment(isEnglish ? .leading : .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
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
    
    private var topicModeTabs: some View {
        HStack(spacing: 8) {
            topicModeTabButton(
                title: tr("לפי נושא", "By Topic"),
                selected: true
            ) {
                // כבר נמצאים במסך לפי נושא
            }

            topicModeTabButton(
                title: tr("לפי חגורה", "By Belt"),
                selected: false
            ) {
                if embeddedMode {
                    onSwitchToByBelt?()
                } else {
                    nav.pop()
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .frame(maxWidth: .infinity)
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.42), lineWidth: 1)
        )
    }

    private func topicModeTabButton(
        title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(
                    selected
                    ? Color.white
                    : Color(red: 0.28, green: 0.22, blue: 0.56)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            selected
                            ? LinearGradient(
                                colors: [
                                    Color(red: 0.50, green: 0.00, blue: 1.00),
                                    Color(red: 0.25, green: 0.32, blue: 0.72)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color.white.opacity(0.96),
                                    Color.white.opacity(0.86)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            selected
                            ? Color.white.opacity(0.42)
                            : Color(red: 0.50, green: 0.00, blue: 1.00).opacity(0.22),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: selected ? Color.black.opacity(0.16) : Color.black.opacity(0.06),
                    radius: selected ? 8 : 4,
                    x: 0,
                    y: selected ? 5 : 2
                )
        }
        .buttonStyle(.plain)
    }
    
    var body: some View {
        ZStack {
            KmiAppBackground()

            VStack(spacing: 0) {
                
                topicModeTabs
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                GeometryReader { geo in
                    let reservedBottomForQuickView: CGFloat = embeddedMode ? 18 : 112
                    let cardHeight = max(360, geo.size.height - reservedBottomForQuickView)

                    WhiteCard {
                        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 14) {

                            Text(tr("נושאים (קטגוריות)", "Topics (Categories)"))
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundStyle(Color.black.opacity(0.84))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)

                            ScrollView(showsIndicators: false) {
                                VStack(spacing: 5) {
                                    ForEach(Array(mainTopics.enumerated()), id: \.offset) { _, topic in
                                        let hasSubTopics = topic.subjects.count > 1
                                        let isExpanded = expandedMainTopicId == topic.id
                                        let accent = accentForTopic(topic)

                                        VStack(spacing: 0) {
                                            Button {
                                                openTopic(topic)
                                            } label: {
                                                TopicRowCard(
                                                    title: displayTitle(for: topic),
                                                    accent: accent,
                                                    subtitleTop: subtitleLineTop(for: topic),
                                                    subtitleBottom: subtitleLineBottom(for: topic),
                                                    isEnglish: isEnglish,
                                                    symbolName: symbolForTopic(topic),
                                                    imageName: imageNameForTopic(topic),
                                                    isLocked: isTopicLocked(topic),
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
                                    
                                    if mainTopics.isEmpty {
                                        Text(tr("אין נושאים להצגה", "No topics to display"))
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(Color.black.opacity(0.55))
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .multilineTextAlignment(.center)
                                            .padding(.vertical, 14)
                                    }
                                }
                                .padding(.bottom, 6)
                            }
                        }
                        .padding(.vertical, 13)
                        .padding(.horizontal, 13)
                    }
                    .frame(height: cardHeight)
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                }

                if !embeddedMode {
                    quickViewButton
                        .padding(.horizontal, 18)
                        .padding(.top, 8)
                        .padding(.bottom, 14)
                }
            }

            if !embeddedMode && showQuickActionsDialog {
                quickActionsDialog
            }
        }
        .environment(\.layoutDirection, screenLayoutDirection)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            onActiveBeltChange?(belt)

            postTopicTopTitleOverride()

            DispatchQueue.main.async {
                postTopicTopTitleOverride()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                postTopicTopTitleOverride()
            }
        }
        .onChange(of: belt) { _, newValue in
            onActiveBeltChange?(newValue)

            postTopicTopTitleOverride()

            DispatchQueue.main.async {
                postTopicTopTitleOverride()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                postTopicTopTitleOverride()
            }
        }
        
        // navigation לקטלוג הוסר – אין שימוש במסך "כל התרגילים"

        .navigationDestination(item: $pickedAcrossBeltsSubject) { subject in
            SubjectAcrossBeltsView(
                subject: subject,
                forcedSectionTitle: pickedAcrossBeltsSubTopicTitle
            )
        }
        .navigationDestination(item: $pickedSectionedSubject) { subject in
            SubjectSectionsListView(
                belt: belt,
                subject: subject,
                onPickSection: { section in
                    pickedAcrossBeltsSubject = subject
                    pickedAcrossBeltsSubTopicTitle = section
                }
            )
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

#Preview {
    NavigationStack {
        BeltQuestionsByTopicView(belt: .orange)
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

        switch cleanId {
        case "def_internal_punch":
            return "Internal Defenses"
        case "def_external_punch":
            return "External Defenses"
        case "kicks_hard":
            return "Kick Defenses"
        case "releases_hands_hair_shirt":
            return "Releases from Hand / Hair / Shirt Grabs"
        case "releases_chokes":
            return "Choke Releases"
        case "releases_hugs":
            return "Hug Releases"
        default:
            if let titleFromId = KmiEnglishTitleResolver.englishTitle(for: cleanId) {
                return titleFromId
            }

            return KmiEnglishTitleResolver.title(for: cleanTitle, isEnglish: true)
        }
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
        case "topic_kawalr":
            return "Cavalier"
        case "kicks_root":
            return "Kicks"
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
                guard let beltContent = CatalogData.shared.data[oneBelt] else { return partial }

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
            VStack(alignment: stackAlignment, spacing: 7) {
                Text(title)
                    .font(.system(size: 16, weight: .heavy))
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
        case "def_internal_punch":
            return "Internal Defenses"
        case "def_external_punch":
            return "External Defenses"
        case "kicks_hard":
            return "Kick Defenses"
        case "releases_hands_hair_shirt":
            return "Releases from Hand / Hair / Shirt Grabs"
        case "releases_chokes":
            return "Choke Releases"
        case "releases_hugs":
            return "Hug Releases"
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
