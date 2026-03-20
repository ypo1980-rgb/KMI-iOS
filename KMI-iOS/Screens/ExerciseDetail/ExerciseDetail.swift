import SwiftUI
import Shared

struct ExerciseDebugView: View {

    let item: SubjectItemsResolver.UiItem
    let belt: Belt
    let subjectTitle: String

    var body: some View {
        ZStack {
            BeltTopicsGradientBackground()

            ScrollView {
                WhiteCard {
                    VStack(alignment: .leading, spacing: 10) {

                        Text(item.displayName)
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(Color.black.opacity(0.85))

                        Text("חגורה: \(belt.heb)")
                            .font(.caption)
                            .foregroundStyle(Color.black.opacity(0.55))

                        Divider().opacity(0.2)

                        Text("subject: \(subjectTitle)")
                            .font(.caption)
                            .foregroundStyle(Color.black.opacity(0.55))

                        Text("topicTitle: \(item.topicTitle)")
                            .font(.caption)
                            .foregroundStyle(Color.black.opacity(0.55))

                        Text("subTopicTitle: \(item.subTopicTitle ?? "-")")
                            .font(.caption)
                            .foregroundStyle(Color.black.opacity(0.55))

                        Divider().opacity(0.2)

                        Text("itemKey:")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.black.opacity(0.75))
                        Text(item.itemKey)
                            .font(.caption)
                            .foregroundStyle(Color.black.opacity(0.65))
                            .textSelection(.enabled)

                        Text("canonicalId:")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.black.opacity(0.75))
                        Text(item.canonicalId)
                            .font(.caption)
                            .foregroundStyle(Color.black.opacity(0.65))
                            .textSelection(.enabled)

                        Text("rawItem:")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.black.opacity(0.75))
                        Text(item.rawItem)
                            .font(.caption)
                            .foregroundStyle(Color.black.opacity(0.65))
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 22)
            }
        }
        .navigationTitle("תרגיל")
        .navigationBarTitleDisplayMode(.inline)
    }
}
