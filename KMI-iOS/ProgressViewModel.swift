import Foundation
import Combine
import SwiftUI
import Shared

final class ProgressViewModel: ObservableObject {

    struct BeltProgress: Identifiable {
        let id = UUID()
        let belt: Belt
        let title: String
        let percent: Int
        let done: Int
        let total: Int
        let color: Color
        let isCurrentBelt: Bool
    }

    struct MissingExercise: Identifiable {
        let id = UUID()
        let topicTitle: String
        let subTopicTitle: String?
        let itemTitle: String
    }

    @Published var rows: [BeltProgress] = []
    @Published var currentBeltTitle: String = "לבנה"

    var averagePercent: Int {
        guard !rows.isEmpty else { return 0 }
        let sum = rows.reduce(0) { $0 + $1.percent }
        return Int(round(Double(sum) / Double(rows.count)))
    }

    private func normalizedProgressText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{200F}", with: "")
            .replacingOccurrences(of: "\u{200E}", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "־", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )
            .lowercased()
    }

    private func progressKeySafePart(_ value: String) -> String {
        normalizedProgressText(value)
    }

    private func isMarkedDoneInDefaults(
        defaults: UserDefaults,
        belt: Belt,
        topicTitle: String,
        subTopicTitle: String?,
        itemTitle: String,
        index: Int
    ) -> Bool {
        let beltId = belt.id
        let cleanTopic = progressKeySafePart(topicTitle)
        let cleanSubTopic = subTopicTitle.map(progressKeySafePart) ?? ""
        let cleanItem = progressKeySafePart(itemTitle)

        let topicKey = cleanSubTopic.isEmpty
            ? cleanTopic
            : "\(cleanTopic)__\(cleanSubTopic)"

        let directKeys = [
            "exercise_\(beltId)_\(itemTitle)",
            "exercise_\(beltId)_\(cleanItem)",

            "status_\(beltId)_\(topicTitle)_\(index)_\(itemTitle)",
            "status_\(beltId)_\(topicTitle)_\(index)_\(cleanItem)",

            "status_\(beltId)_\(topicKey)_\(index)_\(itemTitle)",
            "status_\(beltId)_\(topicKey)_\(index)_\(cleanItem)",

            "\(beltId)_\(topicTitle)_\(itemTitle)",
            "\(beltId)_\(topicKey)_\(itemTitle)",
            "\(beltId)_\(cleanTopic)_\(cleanItem)",
            "\(beltId)_\(topicKey)_\(cleanItem)"
        ]

        for key in directKeys {
            if defaults.bool(forKey: key) {
                return true
            }
        }

        let allValues = defaults.dictionaryRepresentation()

        for entry in allValues {
            guard let isDone = entry.value as? Bool, isDone == true else {
                continue
            }

            let normalizedKey = progressKeySafePart(entry.key)

            let containsBelt = normalizedKey.contains(beltId)
            let containsItem = normalizedKey.contains(cleanItem)

            if containsBelt && containsItem {
                return true
            }
        }

        return false
    }
    
    func loadProgress() {
        let defaults = UserDefaults.standard
        let catalog = CatalogData.shared.data
        
        let defs: [(belt: Belt, id: String, title: String, color: Color)] = [
            (.yellow, "yellow", "חגורה: צהובה", .yellow),
            (.orange, "orange", "חגורה: כתומה", .orange),
            (.green,  "green",  "חגורה: ירוקה", .green),
            (.blue,   "blue",   "חגורה: כחולה", .blue),
            (.brown,  "brown",  "חגורה: חומה",  Color(red: 0.43, green: 0.30, blue: 0.20)),
            (.black,  "black",  "חגורה: שחורה", .black)
        ]

        func resolvedCurrentBeltId() -> String {
            let candidates = [
                defaults.string(forKey: "current_belt"),
                defaults.string(forKey: "belt_current"),
                defaults.string(forKey: "belt"),
                defaults.string(forKey: "registered_belt"),
                defaults.string(forKey: "user_belt")
            ]

            for candidate in candidates {
                let clean = normalizedProgressText(candidate ?? "")

                switch clean {
                case "white", "לבן", "לבנה":
                    return "white"
                case "yellow", "צהוב", "צהובה":
                    return "yellow"
                case "orange", "כתום", "כתומה":
                    return "orange"
                case "green", "ירוק", "ירוקה":
                    return "green"
                case "blue", "כחול", "כחולה":
                    return "blue"
                case "brown", "חום", "חומה":
                    return "brown"
                case "black", "שחור", "שחורה":
                    return "black"
                default:
                    continue
                }
            }

            return "white"
        }
        
        func displayName(for beltId: String) -> String {
            switch beltId {
            case "yellow", "צהוב", "צהובה": return "צהובה"
            case "orange", "כתום", "כתומה": return "כתומה"
            case "green", "ירוק", "ירוקה": return "ירוקה"
            case "blue", "כחול", "כחולה": return "כחולה"
            case "brown", "חום", "חומה": return "חומה"
            case "black", "שחור", "שחורה": return "שחורה"
            default: return "לבנה"
            }
        }

        func readStats(for belt: Belt) -> (done: Int, total: Int, percent: Int) {

            guard let content = catalog[belt] else {
                return (0, 0, 0)
            }

            var total = 0
            var done = 0
            var countedItems = Set<String>()

            func countItem(
                topicTitle: String,
                subTopicTitle: String?,
                itemTitle: String,
                index: Int
            ) {
                let uniqueKey = [
                    belt.id,
                    progressKeySafePart(topicTitle),
                    subTopicTitle.map(progressKeySafePart) ?? "",
                    progressKeySafePart(itemTitle)
                ]
                .joined(separator: "::")

                guard !countedItems.contains(uniqueKey) else {
                    return
                }

                countedItems.insert(uniqueKey)
                total += 1

                if isMarkedDoneInDefaults(
                    defaults: defaults,
                    belt: belt,
                    topicTitle: topicTitle,
                    subTopicTitle: subTopicTitle,
                    itemTitle: itemTitle,
                    index: index
                ) {
                    done += 1
                }
            }

            func countSubTopics(
                topicTitle: String,
                subTopics: [CatalogData.SubTopic]
            ) {
                for subTopic in subTopics {
                    for itemIndex in subTopic.items.indices {
                        countItem(
                            topicTitle: topicTitle,
                            subTopicTitle: subTopic.title,
                            itemTitle: subTopic.items[itemIndex],
                            index: itemIndex
                        )
                    }
                }
            }
            
            for topic in content.topics {
                for itemIndex in topic.items.indices {
                    countItem(
                        topicTitle: topic.title,
                        subTopicTitle: nil,
                        itemTitle: topic.items[itemIndex],
                        index: itemIndex
                    )
                }

                countSubTopics(
                    topicTitle: topic.title,
                    subTopics: topic.subTopics
                )
            }

            let percent = total == 0
                ? 0
                : Int((Double(done) / Double(total)) * 100).clamped(to: 0...100)

            return (done, total, percent)
        }
        
        let currentBeltId = resolvedCurrentBeltId()

        let mapped = defs.map { def -> BeltProgress in

            let stats = readStats(for: def.belt)

            return BeltProgress(
                belt: def.belt,
                title: def.title,
                percent: stats.percent,
                done: stats.done,
                total: stats.total,
                color: def.color,
                isCurrentBelt: def.id == currentBeltId
            )
        }
        
        DispatchQueue.main.async {
            self.currentBeltTitle = displayName(for: currentBeltId)
            self.rows = mapped
        }
    }
    
    func shareText() -> String {
        let lines = rows.map { row in
            "\(row.title) – \(row.done)/\(row.total) • \(row.percent)%"
        }

        let header = "התקדמות כללית: \(averagePercent)%"
        let beltLine = "החגורה הנוכחית שלי: \(currentBeltTitle)"

        return ([header, beltLine, ""] + lines).joined(separator: "\n")
    }

    func missingExercises(for belt: Belt) -> [MissingExercise] {
        let defaults = UserDefaults.standard
        let catalog = CatalogData.shared.data

        guard let content = catalog[belt] else { return [] }

        var result: [MissingExercise] = []

        for topic in content.topics {
            for item in topic.items {
                let key = "exercise_\(belt.id)_\(item)"
                if !defaults.bool(forKey: key) {
                    result.append(
                        MissingExercise(
                            topicTitle: topic.title,
                            subTopicTitle: nil,
                            itemTitle: item
                        )
                    )
                }
            }

            for sub in topic.subTopics {
                for item in sub.items {
                    let key = "exercise_\(belt.id)_\(item)"
                    if !defaults.bool(forKey: key) {
                        result.append(
                            MissingExercise(
                                topicTitle: topic.title,
                                subTopicTitle: sub.title,
                                itemTitle: item
                            )
                        )
                    }
                }
            }
        }

        return result
    }

    func beltRow(for belt: Belt) -> BeltProgress? {
        rows.first(where: { $0.belt == belt })
    }

    func isExerciseDone(belt: Belt, itemTitle: String) -> Bool {
        let defaults = UserDefaults.standard
        let key = "exercise_\(belt.id)_\(itemTitle)"
        return defaults.bool(forKey: key)
    }

    func setExerciseDone(belt: Belt, itemTitle: String, done: Bool) {
        let defaults = UserDefaults.standard
        let key = "exercise_\(belt.id)_\(itemTitle)"
        defaults.set(done, forKey: key)
        loadProgress()
    }

    func toggleExerciseDone(belt: Belt, itemTitle: String) {
        let current = isExerciseDone(belt: belt, itemTitle: itemTitle)
        setExerciseDone(belt: belt, itemTitle: itemTitle, done: !current)
    }

    func allExercises(for belt: Belt) -> [MissingExercise] {
        let catalog = CatalogData.shared.data
        guard let content = catalog[belt] else { return [] }

        var result: [MissingExercise] = []

        for topic in content.topics {
            for item in topic.items {
                result.append(
                    MissingExercise(
                        topicTitle: topic.title,
                        subTopicTitle: nil,
                        itemTitle: item
                    )
                )
            }

            for sub in topic.subTopics {
                for item in sub.items {
                    result.append(
                        MissingExercise(
                            topicTitle: topic.title,
                            subTopicTitle: sub.title,
                            itemTitle: item
                        )
                    )
                }
            }
        }

        return result
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

