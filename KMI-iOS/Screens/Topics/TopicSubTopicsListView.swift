import SwiftUI
import Shared

struct TopicSubTopicsListView: View {

    let belt: Belt
    let topic: CatalogData.Topic
    let onPickSubTopic: (String) -> Void

    @EnvironmentObject private var nav: AppNavModel

    private func accentFor(_ title: String) -> Color {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.contains("פנימ") { return Color.green.opacity(0.75) }
        if t.contains("חיצונ") { return Color.blue.opacity(0.75) }
        if t.contains("סכין") { return Color.orange.opacity(0.85) }
        return Color.purple.opacity(0.75)
    }

    var body: some View {
        KmiRootLayout(
            title: topic.title,
            nav: nav,
            roleLabel: "מצב\nמתאמן",
            selectedIcon: nil,
            rightText: "תתי נושאים • \(topic.subTopics.count)",
            titleColor: KmiBeltPalette.color(for: belt)
        ) {
            ZStack {
                BeltTopicsGradientBackground()

                ScrollView {
                    VStack(spacing: 12) {

                        WhiteCard {
                            VStack(alignment: .trailing, spacing: 10) {
                                Text("תתי נושאים")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(Color.black.opacity(0.82))
                                    .frame(maxWidth: .infinity, alignment: .trailing)

                                VStack(spacing: 10) {
                                    ForEach(Array(topic.subTopics.enumerated()), id: \.offset) { _, st in
                                        Button {
                                            onPickSubTopic(st.title)
                                        } label: {
                                            HStack(spacing: 12) {
                                                VStack(alignment: .trailing, spacing: 6) {
                                                    Text(st.title)
                                                        .font(.body.weight(.heavy))
                                                        .foregroundStyle(Color.black.opacity(0.82))
                                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                                        .lineLimit(1)

                                                    Text("\(st.items.count) תרגילים")
                                                        .font(.subheadline.weight(.semibold))
                                                        .foregroundStyle(Color.black.opacity(0.55))
                                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                                }

                                                Image(systemName: "chevron.left")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(Color.black.opacity(0.35))

                                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                    .fill(accentFor(st.title))
                                                    .frame(width: 6)
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .fill(Color.white.opacity(0.92))
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                        }
                        .padding(.horizontal, 18)

                        Spacer(minLength: 18)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 22)
                }
            }
        }
    }
}
