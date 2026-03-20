import SwiftUI
import Shared

struct FavoritesByBeltView: View {
    let belt: Belt

    private let catalog = CatalogData.shared.data

    // TopicTitle -> (topicItems + subTopic blocks)
    @State private var grouped: [TopicBlock] = []

    private struct TopicBlock: Identifiable {
        let id = UUID()
        let topicTitle: String
        let topicItems: [String]                 // מועדפים מתוך topic.items
        let subBlocks: [SubBlock]                // מועדפים מתוך subTopics
    }

    private struct SubBlock: Identifiable {
        let id = UUID()
        let subTitle: String
        let items: [String]
    }
    
    @State private var totalCount: Int = 0

    @State private var selectedTopicTitle: String? = nil
    @State private var selectedItem: String? = nil
    @State private var showExercise: Bool = false

    var body: some View {
        ZStack {
            FavoritesGradientBackground()
            
            ScrollView {
                VStack(spacing: 12) {

                    WhiteCard {
                        VStack(spacing: 8) {
                            Text("מועדפים")
                                .font(.title3.weight(.heavy))
                                .foregroundStyle(Color.black.opacity(0.85))
                                .frame(maxWidth: .infinity, alignment: .center)

                            Text("חגורה: \(belt.heb)  •  \(totalCount) תרגילים")
                                .font(.caption)
                                .foregroundStyle(Color.black.opacity(0.55))
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                    }

                    if totalCount == 0 {
                        WhiteCard {
                            VStack(spacing: 10) {
                                Image(systemName: "star.slash")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(Color.black.opacity(0.45))

                                Text("אין מועדפים בחגורה הזו עדיין")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(Color.black.opacity(0.80))

                                Text("כנס לנושא → תרגיל → לחץ ⭐ כדי להוסיף למועדפים.")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.black.opacity(0.60))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 12)
                        }

                        Spacer(minLength: 18)
                    } else {
                        ForEach(grouped) { block in
                            WhiteCard {
                                VStack(alignment: .leading, spacing: 12) {

                                    Text(block.topicTitle)
                                        .font(.headline.weight(.heavy))
                                        .foregroundStyle(Color.black.opacity(0.82))

                                    // ✅ מועדפים "ברמת נושא"
                                    if !block.topicItems.isEmpty {
                                        VStack(spacing: 10) {
                                            ForEach(Array(block.topicItems.enumerated()), id: \.offset) { _, item in
                                                favoriteRow(topicTitle: block.topicTitle, item: item)
                                            }
                                        }
                                    }

                                    // ✅ מועדפים מתתי־נושאים
                                    ForEach(block.subBlocks) { sb in
                                        if !sb.items.isEmpty {
                                            VStack(alignment: .leading, spacing: 8) {

                                                Text(sb.subTitle)
                                                    .font(.subheadline.weight(.heavy))
                                                    .foregroundStyle(Color.black.opacity(0.70))
                                                    .padding(.top, 4)

                                                VStack(spacing: 10) {
                                                    ForEach(Array(sb.items.enumerated()), id: \.offset) { _, item in
                                                        favoriteRow(topicTitle: block.topicTitle, item: item)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                            }
                        }

                        Spacer(minLength: 18)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 22)
            }
        }
        .navigationTitle("מועדפים")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            reload()
        }
        .navigationDestination(isPresented: $showExercise) {
            if let item = selectedItem, let t = selectedTopicTitle {
                ExerciseDetailView(
                    belt: belt,
                    topicTitle: t,
                    item: item
                )
            } else {
                EmptyView()
            }
        }
    }

    private func favoriteRow(topicTitle: String, item: String) -> some View {
        Button {
            selectedTopicTitle = topicTitle
            selectedItem = item
            showExercise = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Color.yellow.opacity(0.95))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.white.opacity(0.92)))

                Text(item)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.40))
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
    
    // MARK: - Build favorites list

    private func reload() {
        let topics = catalog[belt]?.topics ?? []

        var blocks: [TopicBlock] = []
        var count = 0

        for t in topics {

            let favTopicItems = t.items.filter { isFavorite(item: $0, topicTitle: t.title) }
            count += favTopicItems.count

            var subBlocks: [SubBlock] = []
            for st in t.subTopics {
                let favSubItems = st.items.filter { isFavorite(item: $0, topicTitle: t.title) }
                if !favSubItems.isEmpty {
                    subBlocks.append(SubBlock(subTitle: st.title, items: favSubItems))
                    count += favSubItems.count
                }
            }

            if !favTopicItems.isEmpty || !subBlocks.isEmpty {
                blocks.append(
                    TopicBlock(
                        topicTitle: t.title,
                        topicItems: favTopicItems,
                        subBlocks: subBlocks
                    )
                )
            }
        }

        grouped = blocks
        totalCount = count
    }

    private func isFavorite(item: String, topicTitle: String) -> Bool {
        let key = favKey(for: item, topicTitle: topicTitle)
        if UserDefaults.standard.object(forKey: key) == nil { return false }
        return UserDefaults.standard.bool(forKey: key)
    }

    // בדיוק אותו key כמו ב-ExerciseDetailView
    private func storageKeyBase(for item: String, topicTitle: String) -> String {
        let b = belt.id
        let t = topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let i = item.trimmingCharacters(in: .whitespacesAndNewlines)
        return "kmi.exercise.\(b).\(t).\(i)"
    }

    private func favKey(for item: String, topicTitle: String) -> String {
        storageKeyBase(for: item, topicTitle: topicTitle) + ".fav"
    }
}

#Preview {
    NavigationStack {
        FavoritesByBeltView(belt: .orange)
    }
}

// MARK: - Local background (no dependency on other files)
private struct FavoritesGradientBackground: View {
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
