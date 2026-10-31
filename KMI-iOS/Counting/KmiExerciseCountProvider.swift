import Foundation
import Shared

struct KmiExerciseCountStats:
    Hashable, Sendable {
    let subTopicCount: Int
    let exerciseCount: Int
}

enum KmiExerciseCountProvider {

    /// סופר תרגילים בחגורה לפי כללי הספירה של Android.
    nonisolated static func knownBeltExerciseCount(
        belt: Belt
    ) -> Int? {
        guard !Task.isCancelled else {
            return nil
        }

        let registry = ExerciseIdentityRegistry.shared

        let knownIDs = registry.allKnown()
            .filter { $0.belt == belt }
            .map {
                $0.id.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter { !$0.isEmpty }

        let knownCount = Set(knownIDs).count

        if knownCount > 0 {
            return knownCount
        }

        // תאימות ל־Android כאשר אין מזהים מוכרים לחגורה.
        func identityKey(
            rawItem: String,
            topicKey: String
        ) -> String? {
            guard !Task.isCancelled else {
                return nil
            }

            return exerciseIdentityKey(
                belt: belt,
                topicTitle: topicKey,
                rawItem: rawItem
            )
        }

        func hardSectionCandidatesForBelt(
            _ topicTitle: String
        ) -> [String] {
            hardSectionCandidates(topicTitle)
        }

        func collectHardSection(
            _ section: HardSectionsCatalog.Section,
            topic: String,
            into keys: inout Set<String>
        ) {
            guard !Task.isCancelled else {
                return
            }

            collectHardSectionExerciseKeys(
                section,
                belt: belt,
                topicTitle: topic,
                into: &keys
            )
        }

        func hardSectionKeys(
            for topic: String
        ) -> Set<String> {
            for candidate in hardSectionCandidatesForBelt(topic) {
                guard !Task.isCancelled else {
                    return []
                }

                var keys = Set<String>()

                let sections = HardSectionsCatalog.shared
                    .sectionsForSubject(subjectId: candidate) ?? []

                for section in sections {
                    collectHardSection(section, topic: topic, into: &keys)
                }

                if !keys.isEmpty {
                    return keys
                }

                if let section = HardSectionsCatalog.shared
                    .findAnySectionById(sectionId: candidate) {
                    collectHardSection(section, topic: topic, into: &keys)
                }

                if !keys.isEmpty {
                    return keys
                }
            }

            return []
        }

        func collectSubTopic(
            _ subTopic: ContentRepo.SubTopic,
            parentTopic: String,
            into keys: inout Set<String>
        ) {
            guard !Task.isCancelled else {
                return
            }

            let cleanTitle = normalize(subTopic.title)

            let topicKey = cleanTitle.isEmpty
                ? parentTopic
                : parentTopic + "__" + cleanTitle

            for item in subTopic.items {
                if let key = identityKey(
                    rawItem: item,
                    topicKey: topicKey
                ) {
                    keys.insert(key)
                }
            }

            for child in subTopic.subTopics {
                collectSubTopic(child, parentTopic: topicKey, into: &keys)
            }
        }

        var exerciseKeys = Set<String>()
        var seenTopics = Set<String>()

        for rawTopic in TopicsEngine.shared.topicTitlesFor(belt: belt) {
            guard !Task.isCancelled else {
                return nil
            }

            let topic = normalize(rawTopic)

            guard !topic.isEmpty,
                  seenTopics.insert(topic).inserted else {
                continue
            }

            let hardKeys = hardSectionKeys(for: topic)

            if !hardKeys.isEmpty {
                exerciseKeys.formUnion(hardKeys)
                continue
            }

            let directItems = ContentRepo.shared.getAllItemsFor(
                belt: belt,
                topicTitle: topic,
                subTopicTitle: nil
            )

            for item in directItems {
                if let key = identityKey(
                    rawItem: item,
                    topicKey: topic
                ) {
                    exerciseKeys.insert(key)
                }
            }

            let subTopics = ContentRepo.shared.getSubTopicsFor(
                belt: belt,
                topicTitle: topic
            )

            for subTopic in subTopics {
                collectSubTopic(
                    subTopic,
                    parentTopic: topic,
                    into: &exerciseKeys
                )
            }
        }

        guard !Task.isCancelled else {
            return nil
        }

        return exerciseKeys.count
    }

    nonisolated static func beltExerciseCountInBackground(
        beltId: String
    ) async -> Int? {
        let worker = Task.detached(priority: .userInitiated) {
            let belts: [Belt] = [
                .yellow, .orange, .green,
                .blue, .brown, .black
            ]

            guard !Task.isCancelled,
                  let belt = belts.first(where: { $0.id == beltId }) else {
                return nil as Int?
            }

            return knownBeltExerciseCount(belt: belt)
        }

        return await withTaskCancellationHandler {
            await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    private nonisolated struct StatsKey: Hashable, Sendable {
        let beltId: String
        let topicTitle: String
        let subTopicTitle: String?
    }

    private final class StatsCache: @unchecked Sendable {
        private nonisolated let lock = NSLock()

        private nonisolated(unsafe) var values:
            [StatsKey: KmiExerciseCountStats] = [:]

        nonisolated func value(
            for key: StatsKey
        ) -> KmiExerciseCountStats? {
            lock.lock()
            defer { lock.unlock() }

            return values[key]
        }

        nonisolated func store(
            _ value: KmiExerciseCountStats,
            for key: StatsKey
        ) {
            lock.lock()
            defer { lock.unlock() }

            values[key] = value
        }
    }

    private nonisolated static let statsCache = StatsCache()

    nonisolated static func topicStatsInBackground(
        beltId: String,
        topicTitle: String
    ) async -> KmiExerciseCountStats {
        let worker = Task.detached(priority: .userInitiated) {
            let belts: [Belt] = [
                .yellow, .orange, .green,
                .blue, .brown, .black
            ]

            guard
                !Task.isCancelled,
                let belt = belts.first(where: {
                    $0.id == beltId
                })
            else {
                return KmiExerciseCountStats(
                    subTopicCount: 0,
                    exerciseCount: 0
                )
            }

            return topicStats(
                belt: belt,
                topicTitle: topicTitle
            )
        }

        return await withTaskCancellationHandler {
            await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    nonisolated static func topicStats(
        belt: Belt,
        topicTitle: String
    ) -> KmiExerciseCountStats {
        let cleanTopic = normalize(topicTitle)

        guard !cleanTopic.isEmpty else {
            return KmiExerciseCountStats(
                subTopicCount: 0,
                exerciseCount: 0
            )
        }

        let key = StatsKey(
            beltId: belt.id,
            topicTitle: cleanTopic,
            subTopicTitle: nil
        )

        if let cached = statsCache.value(for: key) {
            return cached
        }

        let result = calculateTopicStats(
            belt: belt,
            topicTitle: cleanTopic
        )

        statsCache.store(result, for: key)

        return result
    }

    private nonisolated static func calculateTopicStats(
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
                belt: belt,
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

        let directItems = ContentRepo.shared
            .getAllItemsFor(
                belt: belt,
                topicTitle: cleanTopic,
                subTopicTitle: nil
            )

        var directExerciseKeys = Set<String>()

        for item in directItems {
            if let key = exerciseIdentityKey(
                belt: belt,
                topicTitle: cleanTopic,
                rawItem: item
            ) {
                directExerciseKeys.insert(key)
            }
        }

        func collectSubTopicExerciseKeys(
            _ subTopic: ContentRepo.SubTopic,
            parentTopic: String,
            into keys: inout Set<String>
        ) {
            let cleanTitle = normalize(subTopic.title)

            let topicKey = cleanTitle.isEmpty
                ? parentTopic
                : parentTopic + "__" + cleanTitle

            for item in subTopic.items {
                if let key = exerciseIdentityKey(
                    belt: belt,
                    topicTitle: topicKey,
                    rawItem: item
                ) {
                    keys.insert(key)
                }
            }

            for child in subTopic.subTopics {
                collectSubTopicExerciseKeys(
                    child,
                    parentTopic: topicKey,
                    into: &keys
                )
            }
        }

        var subTopicExerciseKeys = Set<String>()

        for subTopic in visibleSubTopics {
            collectSubTopicExerciseKeys(
                subTopic,
                parentTopic: cleanTopic,
                into: &subTopicExerciseKeys
            )
        }

        let exerciseCount = subTopicExerciseKeys.isEmpty
            ? directExerciseKeys.count
            : subTopicExerciseKeys.count

        return KmiExerciseCountStats(
            subTopicCount: visibleSubTopics.count,
            exerciseCount: exerciseCount
        )
    }

    nonisolated static func subTopicStats(
        belt: Belt,
        topicTitle: String,
        subTopicTitle: String
    ) -> KmiExerciseCountStats {
        let cleanTopic = normalize(topicTitle)
        let cleanSubTopic = normalize(subTopicTitle)

        guard !cleanTopic.isEmpty,
              !cleanSubTopic.isEmpty else {
            return KmiExerciseCountStats(
                subTopicCount: 0,
                exerciseCount: 0
            )
        }

        let key = StatsKey(
            beltId: belt.id,
            topicTitle: cleanTopic,
            subTopicTitle: cleanSubTopic
        )

        if let cached = statsCache.value(for: key) {
            return cached
        }

        let result = calculateSubTopicStats(
            belt: belt,
            topicTitle: cleanTopic,
            subTopicTitle: cleanSubTopic
        )

        statsCache.store(result, for: key)

        return result
    }

    private nonisolated static func calculateSubTopicStats(
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

    private nonisolated static func hardSectionExerciseCount(
        belt: Belt,
        topicTitle: String
    ) -> Int {
        let cleanTopic = normalize(topicTitle)
        let candidates = hardSectionCandidates(cleanTopic)

        for candidate in candidates {
            var exerciseKeys = Set<String>()

            let sections = HardSectionsCatalog.shared
                .sectionsForSubject(subjectId: candidate) ?? []

            for section in sections {
                collectHardSectionExerciseKeys(
                    section,
                    belt: belt,
                    topicTitle: cleanTopic,
                    into: &exerciseKeys
                )
            }

            if !exerciseKeys.isEmpty {
                return exerciseKeys.count
            }

            if let section = HardSectionsCatalog.shared
                .findAnySectionById(sectionId: candidate) {
                collectHardSectionExerciseKeys(
                    section,
                    belt: belt,
                    topicTitle: cleanTopic,
                    into: &exerciseKeys
                )
            }

            if !exerciseKeys.isEmpty {
                return exerciseKeys.count
            }
        }

        return 0
    }

    private nonisolated static func hardSectionCandidates(
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
             "topic_kicks":
            mappedId =
                "topic_kicks"

        case "הגנות נגד בעיטות",
             "kicks",
             "kicks_hard":
            mappedId =
                "kicks_hard"

        case "מכות יד",
             "hands_strikes":
            mappedId =
                "hands_strikes"

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

    private nonisolated static func collectHardSectionExerciseKeys(
        _ section: HardSectionsCatalog.Section,
        belt: Belt,
        topicTitle: String,
        into keys: inout Set<String>
    ) {
        guard !Task.isCancelled else {
            return
        }

        for group in section.beltGroups where group.belt == belt {
            for item in group.items {
                guard !Task.isCancelled else {
                    return
                }

                if let key = exerciseIdentityKey(
                    belt: belt,
                    topicTitle: topicTitle,
                    rawItem: item
                ) {
                    keys.insert(key)
                }
            }
        }

        for child in section.subSections {
            collectHardSectionExerciseKeys(
                child,
                belt: belt,
                topicTitle: topicTitle,
                into: &keys
            )
        }
    }

    private nonisolated static func uniqueNormalizedItems(
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

    private nonisolated static func exerciseIdentityKey(
        belt: Belt,
        topicTitle: String,
        rawItem: String
    ) -> String? {
        let cleanItem = normalizeItem(rawItem)

        guard !cleanItem.isEmpty else {
            return nil
        }

        let resolved = ExerciseIdentityRegistry.shared
            .resolve(
                belt: belt,
                hebrewTitle: cleanItem,
                topicKey: normalize(topicTitle)
            )

        let resolvedID = resolved.id
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return resolvedID.isEmpty ? cleanItem : resolvedID
    }

    private nonisolated static func normalizeItem(
        _ value: String
    ) -> String {
        let displayName = ExerciseTitleFormatter.shared
            .displayName(raw: value)

        let sourceName = displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty ? value : displayName

        return normalize(sourceName)
    }

    private nonisolated static func normalize(
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
