import SwiftUI
import Shared

struct TopicsBySubjectListView: View {

    private let catalog = CatalogData.shared.data
    private let belts: [Belt] = [.white, .yellow, .orange, .green, .blue, .brown, .black]

    // ✅ NEW: נושאים חוצי־חגורות (מה-Shared)
    private var subjects: [SubjectTopic] {
        // אם זה לא מזהה את השם, נסה: SharedTopicsBySubjectRegistry.allSubjects()
        TopicsBySubjectRegistry.allSubjects()
    }

    private struct TopicAgg: Identifiable {
        let id: String
        let title: String
        let topicsCount: Int
        let itemsCount: Int
    }

    private var aggregated: [TopicAgg] {
        var byTitle: [String: (topics: Int, items: Int)] = [:]

        for b in belts {
            guard let beltContent = catalog[b] else { continue }
            for t in beltContent.topics {
                let items = t.items.count + t.subTopics.reduce(0) { $0 + $1.items.count }
                let cur = byTitle[t.title] ?? (0, 0)
                byTitle[t.title] = (cur.topics + 1, cur.items + items)
            }
        }

        return byTitle
            .map { (k, v) in TopicAgg(id: k, title: k, topicsCount: v.topics, itemsCount: v.items) }
            .sorted { $0.itemsCount > $1.itemsCount }
    }

    var body: some View {

        VStack(spacing: 12) {

            // ✅ NEW: נושאים חוצי־חגורות (כמו באנדרואיד “לפי נושא”)
            WhiteCard {
                VStack(alignment: .leading, spacing: 10) {

                    Text("נושאים בחגורות (חוצה־חגורות)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.black.opacity(0.82))

                    VStack(spacing: 10) {
                        ForEach(subjects, id: \.id) { s in
                            NavigationLink {
                                SubjectAcrossBeltsView(subject: s)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(s.titleHeb)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(Color.black.opacity(0.82))

                                        Text("\(s.belts.count) חגורות")
                                            .font(.caption)
                                            .foregroundStyle(Color.black.opacity(0.55))
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.left")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.black.opacity(0.35))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.92))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)

            // ✅ הקיים: קטגוריות רגילות מהקטלוג (Topic title אגגרגציה)
            WhiteCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("נושאים (קטגוריות)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.black.opacity(0.82))

                    VStack(spacing: 10) {
                        ForEach(aggregated) { a in
                            NavigationLink {
                                TopicAcrossBeltsView(topicTitle: a.title)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(a.title)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(Color.black.opacity(0.82))

                                        Text("\(a.topicsCount) חגורות • \(a.itemsCount) תרגילים")
                                            .font(.caption)
                                            .foregroundStyle(Color.black.opacity(0.55))
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.left")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.black.opacity(0.35))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.92))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
        }
    }
}
