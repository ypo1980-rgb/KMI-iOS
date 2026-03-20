import Foundation
import Combine
import Shared


// תוצאת חיפוש: belt + topic + item
// item=nil אומר "פגיעה בכותרת נושא" (לא חובה כרגע, אבל נשמר כמו באנדרואיד)
struct ExerciseSearchHit: Identifiable, Hashable {
    let id: String

    let belt: Belt
    let topic: String
    let item: String?   // nil => hit on topic title

    init(belt: Belt, topic: String, item: String?) {
        self.belt = belt
        self.topic = topic
        self.item = item
        self.id = "\(belt.name)|\(topic)|\(item ?? "")"
    }

    var displayTitle: String {
        item?.isEmpty == false ? (item ?? "") : topic
    }

    var subtitle: String {
        item?.isEmpty == false ? topic : belt.name
    }
}

// MARK: - Normalization (Hebrew-friendly)
extension String {
    /// בדומה ל-normHeb באנדרואיד: הסרת סימני RTL/LTR, ניקוד/טעמים, רווחים כפולים והקטנה
    func normHeb() -> String {
        var s = self
        s = s.replacingOccurrences(of: "\u{200F}", with: "") // RLM
        s = s.replacingOccurrences(of: "\u{200E}", with: "") // LRM
        s = s.replacingOccurrences(of: "\u{00A0}", with: " ") // nbsp

        // הסרת ניקוד וטעמים (Hebrew marks range)
        s = s.replacingOccurrences(of: "[\u{0591}-\u{05C7}]", with: "", options: .regularExpression)

        // Trim + collapse spaces
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return s.lowercased()
    }
}

// MARK: - Search Engine (builds index from CatalogData.shared.data)
@MainActor
final class GlobalExerciseSearchEngine: ObservableObject {

    static let shared = GlobalExerciseSearchEngine()

    private struct IndexedRow: Hashable {
        let belt: Belt
        let topic: String
        let item: String?          // nil = topic row
        let searchable: String     // normalized string for contains()
    }

    private let beltsOrder: [Belt] = [.white, .yellow, .orange, .green, .blue, .brown, .black]

    private var index: [IndexedRow] = []
    private var isBuilt: Bool = false

    private init() {}

    /// לבנות אינדקס פעם אחת (או שוב אם בעתיד תטען קטלוג דינמי)
    func ensureBuilt() {
        guard !isBuilt else { return }
        buildIndex()
        isBuilt = true
    }

    private func buildIndex() {
        index.removeAll(keepingCapacity: true)

        let catalog = CatalogData.shared.data

        for belt in beltsOrder {
            guard let beltContent = catalog[belt] else { continue }

            let topics = beltContent.topics
            for topic in topics {
                let topicTitle = topic.title

                // (אופציונלי) row של כותרת נושא
                let topicRow = IndexedRow(
                    belt: belt,
                    topic: topicTitle,
                    item: nil,
                    searchable: topicTitle.normHeb()
                )
                index.append(topicRow)

                // items (כולל subTopics אם קיימים)
                if !topic.subTopics.isEmpty {
                    for st in topic.subTopics {
                        for it in st.items {
                            let row = IndexedRow(
                                belt: belt,
                                topic: topicTitle,
                                item: it,
                                searchable: it.normHeb()
                            )
                            index.append(row)
                        }
                    }
                } else {
                    for it in topic.items {
                        let row = IndexedRow(
                            belt: belt,
                            topic: topicTitle,
                            item: it,
                            searchable: it.normHeb()
                        )
                        index.append(row)
                    }
                }
            }
        }
    }

    /// חיפוש "typeahead": contains על הנירמול, עם limit כדי לשמור על UX מהיר
    func search(query: String, beltFilter: Belt? = nil, limit: Int = 40) -> [ExerciseSearchHit] {
        ensureBuilt()

        let qn = query.normHeb()
        guard !qn.isEmpty else { return [] }

        var results: [ExerciseSearchHit] = []
        results.reserveCapacity(min(limit, 40))

        for row in index {
            if let beltFilter, row.belt != beltFilter { continue }
            guard row.searchable.contains(qn) else { continue }

            results.append(ExerciseSearchHit(belt: row.belt, topic: row.topic, item: row.item))
            if results.count >= limit { break }
        }

        // מיון עדין: קודם לפי displayTitle ואז topic ואז belt
        results.sort {
            if $0.displayTitle != $1.displayTitle { return $0.displayTitle < $1.displayTitle }
            if $0.topic != $1.topic { return $0.topic < $1.topic }
            return $0.belt.name < $1.belt.name
        }

        // distinct (במקרה של כפילויות קטלוג)
        var seen = Set<String>()
        return results.filter { seen.insert($0.id).inserted }
    }
}
