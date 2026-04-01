import Foundation
import Shared

final class AssistantSearchAdapter: AssistantSearchEngine {
    func search(query: String, belt: Belt?) -> [AssistantSearchHit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }

        var results: [AssistantSearchHit] = []

        let data = CatalogData().data
        let requestedBelt = belt

        for (beltKey, beltContent) in data {
            if let requestedBelt, requestedBelt != beltKey { continue }

            for topic in beltContent.topics {
                for item in topic.items {
                    if matches(query: q, topic: topic.title, item: item) {
                        results.append(
                            AssistantSearchHit(
                                belt: beltKey,
                                topic: topic.title,
                                item: item
                            )
                        )
                    }
                }

                for subTopic in topic.subTopics {
                    for item in subTopic.items {
                        if matches(query: q, topic: topic.title + " " + subTopic.title, item: item) {
                            results.append(
                                AssistantSearchHit(
                                    belt: beltKey,
                                    topic: topic.title,
                                    item: item
                                )
                            )
                        }
                    }
                }
            }
        }

        return dedupe(results)
    }

    private func matches(query: String, topic: String, item: String) -> Bool {
        let nq = HebrewNormalize.normalize(query).lowercased()
        let nt = HebrewNormalize.normalize(topic).lowercased()
        let ni = HebrewNormalize.normalize(item).lowercased()

        if ni.contains(nq) || nt.contains(nq) {
            return true
        }

        let qTokens = HebrewTokenizer.tokenize(nq)
        let haystack = "\(nt) \(ni)"
        let matched = qTokens.filter { haystack.contains($0) }
        return !qTokens.isEmpty && matched.count >= max(1, qTokens.count / 2)
    }

    private func dedupe(_ hits: [AssistantSearchHit]) -> [AssistantSearchHit] {
        var seen = Set<String>()
        return hits.filter { hit in
            let key = "\(hit.belt.id)|\(hit.topic)|\(hit.item ?? "")"
            return seen.insert(key).inserted
        }
    }
}
