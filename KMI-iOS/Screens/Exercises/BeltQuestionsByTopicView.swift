import SwiftUI
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

    @State private var pickedMainTopic: MainTopic? = nil
    @State private var goSubTopics: Bool = false
    @State private var pickedSectionedSubject: SubjectTopic? = nil
    @State private var pickedAcrossBeltsSubject: SubjectTopic? = nil
    @State private var pickedAcrossBeltsSubTopicTitle: String? = nil
    
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

        // ✅ סדר כמו באנדרואיד:
        // הגנות -> עבודת ידיים -> שחרורים -> בלימות -> עמידת מוצא -> הכנה לעבודת קרקע -> קאוולר -> בעיטות -> הטלות

        if !defenseRootSubjects.isEmpty {
            out.append(
                MainTopic(id: "defenses_root", titleHeb: "הגנות", subjects: defenseRootSubjects)
            )
        }

        if !handsRootSubjects.isEmpty {
            out.append(
                MainTopic(id: "hands_root", titleHeb: "עבודת ידיים", subjects: handsRootSubjects)
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
                MainTopic(id: "topic_ground_prep", titleHeb: "הכנה לעבודת קרקע", subjects: [groundSubject])
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
            HStack(spacing: 14) {
                if isEnglish {
                    accentBar

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.30))

                    textBlock
                } else {
                    textBlock

                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.30))

                    accentBar
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color.white.opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            .scaleEffect(1.0)
        }

        private var textBlock: some View {
            VStack(alignment: stackAlignment, spacing: 7) {
                Text(title)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.84))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
                    .lineLimit(2)

                if let top = subtitleTop, !top.isEmpty {
                    Text(top)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Color.purple.opacity(0.82))
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                        .multilineTextAlignment(textAlignment)
                }

                Text(subtitleBottom)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.56))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
            }
        }

        private var accentBar: some View {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(accent)
                .frame(width: 8)
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
                guard let beltContent = catalog[oneBelt] else { return partial }

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

        if subjectId == "hands_strikes" || subjectId == "hands_elbows" || subjectId == "hands_stick_rifle" {
            let allHands = HardSectionsCatalog.shared.sectionsForSubject(subjectId: "hands_all") ?? []
            let matching = allHands.filter { $0.id == subjectId }
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

    private func subtitleLineTop(for topic: MainTopic) -> String? {
        if topic.id == "releases_root" {
            let count = (HardSectionsCatalog.shared.sectionsForSubject(subjectId: "releases") ?? []).count
            guard count > 0 else { return nil }

            if isEnglish {
                return count == 1 ? "1 sub-topic" : "\(count) sub-topics"
            } else {
                return "\(count) תתי נושאים"
            }
        }

        let count = topic.subjects.count
        guard count > 1 else { return nil }

        if isEnglish {
            return count == 1 ? "1 sub-topic" : "\(count) sub-topics"
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
            return total == 1 ? "1 exercise" : "\(total) exercises"
        } else {
            return "\(total) תרגילים"
        }
    }

    private func triggerTapHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    var body: some View {
        ZStack {
            KmiGradientBackground(forceTraineeStyle: false)

            VStack(spacing: 0) {

                SegmentedTabs(
                    leftTitle: tr("לפי נושא", "By Topic"),
                    rightTitle: tr("לפי חגורה", "By Belt"),
                    selected: .left,
                    onSelect: { sel in
                        if sel == .right {
                            if embeddedMode {
                                onSwitchToByBelt?()
                            } else {
                                nav.pop()
                            }
                        }
                    }
                )
                .padding(.horizontal, 18)
                .padding(.top, 10)

                ScrollView {
                    VStack(spacing: 14) {

                        EmptyView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 0)

                        WhiteCard {
                            VStack(alignment: isEnglish ? .leading : .trailing, spacing: 14) {

                                Text(tr("נושאים (קטגוריות)", "Topics (Categories)"))
                                    .font(.system(size: 24, weight: .heavy))
                                    .foregroundStyle(Color.black.opacity(0.84))
                                    .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                                    .multilineTextAlignment(primaryTextAlignment)

                                VStack(spacing: 11) {
                                    ForEach(Array(mainTopics.enumerated()), id: \.offset) { _, topic in
                                        Button {
                                            triggerTapHaptic()
                                            pickedMainTopic = topic

                                            if topic.id == "hands_root" || topic.subjects.count > 1 {
                                                goSubTopics = true
                                            } else if let subject = topic.subjects.first {
                                                let sections = resolvedSections(for: subject)

                                                if sections.count > 1 {
                                                    pickedSectionedSubject = subject
                                                } else {
                                                    pickedAcrossBeltsSubject = subject
                                                    pickedAcrossBeltsSubTopicTitle = nil
                                                }
                                            }
                                        } label: {
                                            TopicRowCard(
                                                title: displayTitle(for: topic),
                                                accent: accentForTopic(topic),
                                                subtitleTop: subtitleLineTop(for: topic),
                                                subtitleBottom: subtitleLineBottom(for: topic),
                                                isEnglish: isEnglish
                                            )
                                        }
                                        .buttonStyle(.plain)
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
                            }
                            .padding(.vertical, 13)
                            .padding(.horizontal, 13)
                        }
                        .padding(.horizontal, 18)

                        Spacer(minLength: 18)
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 22)
                }
            }
        }
        .environment(\.layoutDirection, screenLayoutDirection)
        .navigationBarTitleDisplayMode(.inline)

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
        .navigationDestination(isPresented: $goSubTopics) {
            if let topic = pickedMainTopic {
                SubjectSubTopicsListView(
                    belt: belt,
                    mainTopic: topic,
                    onPickSubject: { subject in
                        let sections = resolvedSections(for: subject)

                        if sections.count > 1 {
                            pickedSectionedSubject = subject
                        } else {
                            pickedAcrossBeltsSubject = subject
                            pickedAcrossBeltsSubTopicTitle = nil
                        }
                    }
                )
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
            return count == 1 ? "1 exercise" : "\(count) exercises"
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
            HStack(spacing: 14) {
                if isEnglish {
                    accentBar

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.30))

                    textBlock
                } else {
                    textBlock

                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.30))

                    accentBar
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color.white.opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }

        private var textBlock: some View {
            VStack(alignment: stackAlignment, spacing: 7) {
                Text(title)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.84))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
                    .lineLimit(2)

                Text(subtitleBottom)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.56))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
            }
        }

        private var accentBar: some View {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(accent)
                .frame(width: 8)
        }
    }

    var body: some View {
        ZStack {
            KmiGradientBackground(forceTraineeStyle: false)

            ScrollView {
                WhiteCard {
                    VStack(alignment: isEnglish ? .leading : .trailing, spacing: 12) {
                        Text(tr("תתי נושאים", "Sub-topics"))
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(Color.black.opacity(0.84))
                            .frame(
                                maxWidth: .infinity,
                                alignment: isEnglish ? .leading : .trailing
                            )
                            .multilineTextAlignment(isEnglish ? .leading : .trailing)

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
                                        isEnglish: isEnglish
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
            return count == 1 ? "1 exercise" : "\(count) exercises"
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
            HStack(spacing: 14) {
                if isEnglish {
                    accentBar

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.30))

                    textBlock
                } else {
                    textBlock

                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.30))

                    accentBar
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            .scaleEffect(1.0)
        }

        private var textBlock: some View {
            VStack(alignment: stackAlignment, spacing: 7) {
                Text(title)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.84))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
                    .lineLimit(2)

                Text(subtitleBottom)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
            }
        }

        private var accentBar: some View {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(accent)
                .frame(width: 8)
        }
    }
    
    var body: some View {
        ZStack {
            KmiGradientBackground(forceTraineeStyle: false)

            ScrollView {
                WhiteCard {
                    VStack(alignment: isEnglish ? .leading : .trailing, spacing: 12) {
                        Text(tr("תתי נושאים", "Sub-topics"))
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(Color.black.opacity(0.84))
                            .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                            .multilineTextAlignment(primaryTextAlignment)

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
                                        isEnglish: isEnglish
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
