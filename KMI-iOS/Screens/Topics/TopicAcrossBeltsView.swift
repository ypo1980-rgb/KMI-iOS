import SwiftUI
import Shared

struct TopicAcrossBeltsView: View {

    let topicTitle: String
    let subTopicTitle: String?

    init(topicTitle: String, subTopicTitle: String? = nil) {
        self.topicTitle = topicTitle
        self.subTopicTitle = subTopicTitle
    }

    private let catalog = CatalogData.shared.data
    private let belts: [Belt] = [.white, .yellow, .orange, .green, .blue, .brown, .black]

    private struct BeltTopicPack: Identifiable {
        let id: String
        let belt: Belt
        let topic: CatalogData.Topic
        let itemsFlat: [String]
    }

    private func flattenItems(_ t: CatalogData.Topic) -> [String] {
        var out: [String] = []
        out.append(contentsOf: t.items)
        for st in t.subTopics { out.append(contentsOf: st.items) }

        var seen = Set<String>()
        return out.filter { seen.insert($0).inserted }
    }

    private var packs: [BeltTopicPack] {
        var out: [BeltTopicPack] = []

        for b in belts {
            guard let beltContent = catalog[b] else { continue }
            guard let t = beltContent.topics.first(where: { $0.title == topicTitle }) else { continue }

            let flat: [String]
            if let sub = subTopicTitle,
               let subTopic = t.subTopics.first(where: { $0.title == sub }) {
                flat = subTopic.items
            } else {
                flat = flattenItems(t)
            }

            out.append(
                BeltTopicPack(
                    id: "\(b.id)::\(topicTitle)::\(subTopicTitle ?? "__ALL__")",
                    belt: b,
                    topic: t,
                    itemsFlat: flat
                )
            )
        }

        return out
    }

    private func beltHeaderColor(_ belt: Belt) -> Color {
        switch belt {
        case .white:  return Color.gray.opacity(0.55)
        case .yellow: return Color.green.opacity(0.78)   // בתמונה הכותרת הראשונה ירוקה
        case .orange: return Color.orange.opacity(0.85)
        case .green:  return Color.green.opacity(0.75)
        case .blue:   return Color.blue.opacity(0.75)
        case .brown:  return Color(red: 0.55, green: 0.34, blue: 0.23).opacity(0.85)
        case .black:  return Color.black.opacity(0.75)
        default:      return Color.blue.opacity(0.7)
        }
    }

    // MARK: - UI Blocks (like screenshot)

    private struct TopicHeaderCard: View {
        let topicTitle: String
        let subtitle: String

        var body: some View {
            VStack(spacing: 8) {
                    Text(topicTitle)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.92))
            )
        }
    }

    private struct BeltExercisesCard: View {
        let beltTitle: String
        let count: Int
        let headerColor: Color
        let items: [String]

        var body: some View {
            VStack(spacing: 0) {

                // colored header
                HStack {
                    Text("תרגילים: \(count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.white.opacity(0.92))

                    Spacer()

                    Text(beltTitle)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Color.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(headerColor)
                )
                .padding(.horizontal, 10)
                .padding(.top, 10)

                // list area (light)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, s in
                        Text("• \(s)")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.black.opacity(0.82))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.92))
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
        }
    }

    var body: some View {
        ZStack {
            TopicAcrossBeltsGradientBackground()

            ScrollView {
                VStack(spacing: 14) {

                    ForEach(packs) { p in
                        BeltExercisesCard(
                            beltTitle: "חגורה \(p.belt.heb)",
                            count: p.itemsFlat.count,
                            headerColor: beltHeaderColor(p.belt),
                            items: p.itemsFlat
                        )
                        .padding(.horizontal, 16)
                    }

                    if packs.isEmpty {
                        VStack {
                            Text("לא נמצאו חגורות שמכילות נושא בשם הזה")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.black.opacity(0.55))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 12)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.92))
                        )
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 18)
                }
                .padding(.bottom, 22)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }
}

private struct TopicAcrossBeltsGradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.06, blue: 0.25),
                Color(red: 0.20, green: 0.12, blue: 0.55),
                Color(red: 0.08, green: 0.44, blue: 0.86),
                Color(red: 0.10, green: 0.80, blue: 0.90)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
