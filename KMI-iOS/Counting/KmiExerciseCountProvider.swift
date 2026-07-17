import Foundation
import Shared

struct KmiExerciseCountStats:
    Hashable {
    let subTopicCount: Int
    let exerciseCount: Int
}

enum KmiExerciseCountProvider {

    static func topicStats(
        belt: Belt,
        topicTitle: String
    ) -> KmiExerciseCountStats {
        let cleanTopic =
            normalize(topicTitle)

        guard !cleanTopic.isEmpty else {
            return KmiExerciseCountStats(
                subTopicCount: 0,
                exerciseCount: 0
            )
        }

        let hardCount =
            hardSectionExerciseCount(
                topicTitle: cleanTopic
            )

        if hardCount > 0 {
            return KmiExerciseCountStats(
                subTopicCount: 0,
                exerciseCount: hardCount
            )
        }

        let allSubTopics =
            ContentRepo.shared
                .getSubTopicsFor(
                    belt: belt,
                    topicTitle: cleanTopic
                )

        let visibleSubTopics =
            allSubTopics.filter {
                subTopic in

                let cleanTitle =
                    normalize(
                        subTopic.title
                    )

                return !cleanTitle.isEmpty &&
                    cleanTitle != cleanTopic
            }

        let directItems =
            uniqueNormalizedItems(
                ContentRepo.shared
                    .getAllItemsFor(
                        belt: belt,
                        topicTitle:
                            cleanTopic,
                        subTopicTitle:
                            nil
                    )
            )

        var pendingSubTopics =
            visibleSubTopics

        var deepSubTopicItemsCount = 0

        while !pendingSubTopics.isEmpty {
            let current =
                pendingSubTopics
                    .removeFirst()

            var currentSubTopicItems =
                Set<String>()

            for item in current.items {
                let cleanItem =
                    normalizeItem(
                        item
                    )

                if !cleanItem.isEmpty {
                    currentSubTopicItems
                        .insert(
                            cleanItem
                        )
                }
            }

            /*
             * Android מבצע distinct בכל SubTopic בנפרד,
             * ולא על כל העץ יחד.
             */
            deepSubTopicItemsCount +=
                currentSubTopicItems.count

            pendingSubTopics.append(
                contentsOf:
                    current.subTopics
            )
        }

        let exerciseCount =
            deepSubTopicItemsCount > 0
                ? deepSubTopicItemsCount
                : directItems.count

        return KmiExerciseCountStats(
            subTopicCount:
                visibleSubTopics.count,
            exerciseCount:
                exerciseCount
        )
    }

    static func subTopicStats(
        belt: Belt,
        topicTitle: String,
        subTopicTitle: String
    ) -> KmiExerciseCountStats {
        let cleanTopic =
            normalize(topicTitle)

        let cleanSubTopic =
            normalize(subTopicTitle)

        guard !cleanTopic.isEmpty,
              !cleanSubTopic.isEmpty else {
            return KmiExerciseCountStats(
                subTopicCount: 0,
                exerciseCount: 0
            )
        }

        let topLevelSubTopics =
            ContentRepo.shared
                .getSubTopicsFor(
                    belt: belt,
                    topicTitle: cleanTopic
                )

        if let matchingSubTopic =
            topLevelSubTopics.first(
                where: {
                    normalize($0.title) ==
                        cleanSubTopic
                }
            ) {
            var pendingSubTopics = [
                matchingSubTopic
            ]

            var deepExerciseCount = 0

            while !pendingSubTopics
                .isEmpty {
                let current =
                    pendingSubTopics
                        .removeFirst()

                var currentSubTopicItems =
                    Set<String>()

                for item in current.items {
                    let cleanItem =
                        normalizeItem(
                            item
                        )

                    if !cleanItem.isEmpty {
                        currentSubTopicItems
                            .insert(
                                cleanItem
                            )
                    }
                }

                deepExerciseCount +=
                    currentSubTopicItems.count

                pendingSubTopics.append(
                    contentsOf:
                        current.subTopics
                )
            }

            return KmiExerciseCountStats(
                subTopicCount: 0,
                exerciseCount:
                    deepExerciseCount
            )
        }

        let items =
            uniqueNormalizedItems(
                ContentRepo.shared
                    .getAllItemsFor(
                        belt: belt,
                        topicTitle:
                            cleanTopic,
                        subTopicTitle:
                            cleanSubTopic
                    )
            )

        return KmiExerciseCountStats(
            subTopicCount: 0,
            exerciseCount:
                items.count
        )
    }

    static func countText(
        stats: KmiExerciseCountStats,
        isEnglish: Bool
    ) -> String {
        if isEnglish {
            return stats.exerciseCount == 1
                ? "1 exercise"
                : "\(stats.exerciseCount) exercises"
        }

        return stats.exerciseCount == 1
            ? "תרגיל 1"
            : "\(stats.exerciseCount) תרגילים"
    }

    static func combinedCountText(
        stats: KmiExerciseCountStats,
        isEnglish: Bool
    ) -> String {
        guard stats.subTopicCount > 0 else {
            return countText(
                stats: stats,
                isEnglish: isEnglish
            )
        }

        if isEnglish {
            let subTopicText =
                stats.subTopicCount == 1
                    ? "1 sub-topic"
                    : "\(stats.subTopicCount) sub-topics"

            return
                "\(subTopicText) · " +
                countText(
                    stats: stats,
                    isEnglish: true
                )
        }

        let subTopicText =
            stats.subTopicCount == 1
                ? "תת־נושא 1"
                : "\(stats.subTopicCount) תתי נושאים"

        return
            "\(subTopicText) · " +
            countText(
                stats: stats,
                isEnglish: false
            )
    }

    private static func hardSectionExerciseCount(
        topicTitle: String
    ) -> Int {
        let candidates =
            hardSectionCandidates(
                topicTitle
            )

        for candidate in candidates {
            let sections =
                HardSectionsCatalog.shared
                    .sectionsForSubject(
                        subjectId:
                            candidate
                    ) ?? []

            let count =
                sections.reduce(0) {
                    partial,
                    section in

                    partial +
                        hardSectionDeepCount(
                            section
                        )
                }

            if count > 0 {
                return count
            }
        }

        return 0
    }

    private static func hardSectionCandidates(
        _ topicTitle: String
    ) -> [String] {
        let clean =
            normalize(topicTitle)

        let mappedId: String?

        switch clean {
        case "עבודת קרקע",
             "topic_ground_prep":
            mappedId =
                "topic_ground_prep"

        case "עמידת מוצא",
             "topic_ready_stance":
            mappedId =
                "topic_ready_stance"

        case "קוואלר",
             "topic_kavaler",
             "kavaler":
            mappedId =
                "topic_kavaler"

        case "בלימות וגלגולים",
             "גלגולים ובלימות",
             "rolls_breakfalls",
             "topic_breakfalls_rolls":
            mappedId =
                "rolls_breakfalls"

        case "בעיטות",
             "topic_kicks",
             "kicks":
            mappedId =
                "kicks"

        default:
            mappedId = nil
        }

        var result: [String] = []

        if let mappedId {
            result.append(
                mappedId
            )
        }

        if !clean.isEmpty,
           !result.contains(clean) {
            result.append(
                clean
            )
        }

        return result
    }

    private static func hardSectionDeepCount(
        _ section:
            HardSectionsCatalog.Section
    ) -> Int {
        var ownItems =
            Set<String>()

        for group in section.beltGroups {
            for item in group.items {
                let cleanItem =
                    normalizeItem(item)

                if !cleanItem.isEmpty {
                    ownItems.insert(
                        cleanItem
                    )
                }
            }
        }

        let childCount =
            section.subSections.reduce(0) {
                partial,
                child in

                partial +
                    hardSectionDeepCount(
                        child
                    )
            }

        return
            ownItems.count +
            childCount
    }

    private static func uniqueNormalizedItems(
        _ items: [String]
    ) -> Set<String> {
        var result =
            Set<String>()

        for item in items {
            let cleanItem =
                normalizeItem(item)

            if !cleanItem.isEmpty {
                result.insert(
                    cleanItem
                )
            }
        }

        return result
    }

    private static func normalizeItem(
        _ value: String
    ) -> String {
        normalize(value)
            .lowercased()
    }

    private static func normalize(
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
                of: "–",
                with: "-"
            )
            .replacingOccurrences(
                of: "—",
                with: "-"
            )
            .replacingOccurrences(
                of: "־",
                with: "-"
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
}
