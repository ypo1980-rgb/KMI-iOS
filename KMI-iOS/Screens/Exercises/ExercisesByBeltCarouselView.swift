import SwiftUI
import Shared

struct ExercisesByBeltCarouselView: View {

    @Binding var selectedBelt: Belt
    private let belts: [Belt] = [.white, .yellow, .orange, .green, .blue, .brown, .black]

    private let catalog = CatalogData.shared.data

    private var topics: [CatalogData.Topic] {
        catalog[selectedBelt]?.topics ?? []
    }

    var body: some View {
        VStack(spacing: 12) {

            // קרוסלת חגורות
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(belts, id: \.self) { b in
                        Button {
                            selectedBelt = b
                        } label: {
                            Text(b.heb)
                                .font(.body.weight(.bold))
                                .foregroundStyle(Color.black.opacity(0.80))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(selectedBelt == b ? Color.white.opacity(0.92) : Color.white.opacity(0.70))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
            }

            // כרטיס לבן גדול (כמו בתמונה)
            WhiteCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("נושאים בחגורה")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.black.opacity(0.82))

                    VStack(spacing: 10) {
                        ForEach(Array(topics.enumerated()), id: \.offset) { _, t in
                            let count = t.items.count + t.subTopics.reduce(0) { $0 + $1.items.count }

                            NavigationLink {
                                TopicContentView(belt: selectedBelt, topic: t)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(t.title)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(Color.black.opacity(0.82))

                                        Text("\(count) תרגילים")
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

                        if topics.isEmpty {
                            Text("אין נושאים לחגורה הזו")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.black.opacity(0.55))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 14)
                        }
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 0)
        }
    }
}
