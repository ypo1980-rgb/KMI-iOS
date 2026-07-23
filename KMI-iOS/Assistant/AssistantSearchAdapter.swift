import Foundation
import Shared

final class AssistantSearchAdapter: AssistantSearchEngine {

    private struct RankedHit {
        let hit: AssistantSearchHit
        let score: Int
    }

    func search(
        query: String,
        belt: Belt?
    ) -> [AssistantSearchHit] {
        let cleanQuery = cleanAssistantQuery(query)

        guard !cleanQuery.isEmpty else {
            return []
        }

        var rankedResults: [RankedHit] = []

        let data = ContentRepo.shared.data

        for (beltKey, beltContent) in data {
            if let belt, belt != beltKey {
                continue
            }

            for topic in beltContent.topics {
                let topicTitle = topic.title.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

                for item in topic.items {
                    let score = matchScore(
                        query: cleanQuery,
                        topic: topicTitle,
                        item: item
                    )

                    guard score > 0 else {
                        continue
                    }

                    rankedResults.append(
                        RankedHit(
                            hit: AssistantSearchHit(
                                belt: beltKey,
                                topic: topicTitle,
                                item: item
                            ),
                            score: score
                        )
                    )
                }

                for subTopic in topic.subTopics {
                    let subTopicTitle = subTopic.title.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                    let searchableTopic = [
                        topicTitle,
                        subTopicTitle
                    ]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")

                    for item in subTopic.items {
                        let score = matchScore(
                            query: cleanQuery,
                            topic: searchableTopic,
                            item: item
                        )

                        guard score > 0 else {
                            continue
                        }

                        rankedResults.append(
                            RankedHit(
                                hit: AssistantSearchHit(
                                    belt: beltKey,
                                    topic: topicTitle,
                                    item: item
                                ),
                                score: score
                            )
                        )
                    }
                }
            }
        }

        return dedupeAndSort(rankedResults)
            .map(\.hit)
    }

    private func cleanAssistantQuery(
        _ value: String
    ) -> String {
        var result = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let requestPrefixes = [
            "תן לי הסבר על",
            "תני לי הסבר על",
            "אפשר הסבר על",
            "אני רוצה הסבר על",
            "תסביר לי על",
            "תסביר על",
            "הסבר על",
            "הסבר לתרגיל",
            "הסבר תרגיל",
            "איך מבצעים את",
            "איך מבצעים",
            "איך עושים את",
            "איך עושים",
            "explain the exercise",
            "give me an explanation of",
            "give me an explanation for",
            "explain how to do",
            "how do i perform",
            "how to perform",
            "how do i do",
            "explain"
        ]

        for prefix in requestPrefixes {
            result = result.replacingOccurrences(
                of: prefix,
                with: " ",
                options: .caseInsensitive
            )
        }

        result = result
            .replacingOccurrences(of: "\"", with: " ")
            .replacingOccurrences(of: "'", with: " ")
            .replacingOccurrences(of: "?", with: " ")
            .replacingOccurrences(of: "!", with: " ")
            .replacingOccurrences(of: "־", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )

        return HebrewNormalize.normalize(result)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedCatalogText(
        _ value: String
    ) -> String {
        HebrewNormalize.normalize(value)
            .lowercased()
            .replacingOccurrences(of: "־", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func matchScore(
        query: String,
        topic: String,
        item: String
    ) -> Int {
        let normalizedQuery = normalizedCatalogText(query)
        let normalizedTopic = normalizedCatalogText(topic)
        let normalizedItem = normalizedCatalogText(item)

        guard !normalizedQuery.isEmpty,
              !normalizedItem.isEmpty else {
            return 0
        }

        // התאמה מלאה לשם תרגיל היא תמיד התוצאה הראשונה.
        if normalizedItem == normalizedQuery {
            return 10_000
        }

        // שם התרגיל מתחיל בביטוי שהתבקש.
        if normalizedItem.hasPrefix(normalizedQuery) {
            return 9_000 - abs(
                normalizedItem.count - normalizedQuery.count
            )
        }

        // שם התרגיל מכיל את כל הביטוי.
        if normalizedItem.contains(normalizedQuery) {
            return 8_000 - abs(
                normalizedItem.count - normalizedQuery.count
            )
        }

        // התאמה מלאה לשם הנושא או תת־הנושא.
        if normalizedTopic == normalizedQuery {
            return 7_000
        }

        if normalizedTopic.contains(normalizedQuery) {
            return 6_000 - abs(
                normalizedTopic.count - normalizedQuery.count
            )
        }

        let queryTokens = HebrewTokenizer
            .tokenize(normalizedQuery)
            .map { normalizedCatalogText($0) }
            .filter { $0.count > 1 }

        guard !queryTokens.isEmpty else {
            return 0
        }

        let itemTokens = Set(
            HebrewTokenizer
                .tokenize(normalizedItem)
                .map { normalizedCatalogText($0) }
                .filter { $0.count > 1 }
        )

        let topicTokens = Set(
            HebrewTokenizer
                .tokenize(normalizedTopic)
                .map { normalizedCatalogText($0) }
                .filter { $0.count > 1 }
        )

        let exactItemMatches = queryTokens.filter {
            itemTokens.contains($0)
        }.count

        let exactTopicMatches = queryTokens.filter {
            topicTokens.contains($0)
        }.count

        /*
         * אין יותר התאמה של מילה אחת מתוך שלוש.
         * בשם הכולל מספר מילים נדרשת התאמה של לפחות 75%.
         */
        let requiredMatches = max(
            1,
            Int(
                ceil(
                    Double(queryTokens.count) * 0.75
                )
            )
        )

        if exactItemMatches >= requiredMatches {
            return 5_000 +
                exactItemMatches * 100 -
                abs(itemTokens.count - queryTokens.count)
        }

        if exactTopicMatches >= requiredMatches {
            return 4_000 +
                exactTopicMatches * 100 -
                abs(topicTokens.count - queryTokens.count)
        }

        return 0
    }

    private func dedupeAndSort(
        _ results: [RankedHit]
    ) -> [RankedHit] {
        let sorted = results.sorted { left, right in
            if left.score != right.score {
                return left.score > right.score
            }

            let leftItem = left.hit.item ?? ""
            let rightItem = right.hit.item ?? ""

            if leftItem.count != rightItem.count {
                return leftItem.count < rightItem.count
            }

            if left.hit.topic != right.hit.topic {
                return left.hit.topic < right.hit.topic
            }

            return leftItem < rightItem
        }

        var seen = Set<String>()

        return sorted.filter { rankedHit in
            let hit = rankedHit.hit

            let key = [
                hit.belt.id,
                normalizedCatalogText(hit.topic),
                normalizedCatalogText(hit.item ?? "")
            ]
            .joined(separator: "|")

            return seen.insert(key).inserted
        }
    }
}
