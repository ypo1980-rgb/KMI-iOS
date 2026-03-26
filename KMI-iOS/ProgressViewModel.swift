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
            let primary = (defaults.string(forKey: "current_belt") ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            if !primary.isEmpty { return primary }

            let secondary = (defaults.string(forKey: "belt_current") ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            return secondary
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
                return (0,0,0)
            }

            var total = 0
            var done = 0

            for topic in content.topics {

                for item in topic.items {
                    total += 1

                    let key = "exercise_\(belt.id)_\(item)"
                    if defaults.bool(forKey: key) {
                        done += 1
                    }
                }

                for sub in topic.subTopics {
                    for item in sub.items {
                        total += 1

                        let key = "exercise_\(belt.id)_\(item)"
                        if defaults.bool(forKey: key) {
                            done += 1
                        }
                    }
                }
            }

            let percent = total == 0 ? 0 : Int((Double(done) / Double(total)) * 100)

            return (done,total,percent)
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
