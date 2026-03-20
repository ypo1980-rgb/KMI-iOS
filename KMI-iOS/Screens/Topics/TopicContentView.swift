import SwiftUI
import Shared

struct TopicContentView: View {
    let belt: Belt
    let topic: CatalogData.Topic

    @State private var selectedSubIndex: Int? = nil
    @State private var selectedItem: String? = nil
    @State private var showExercise: Bool = false

    // ✅ cache מקומי למועדפים של המסך
    @State private var favoriteMap: [String: Bool] = [:]

    private var subTopics: [CatalogData.SubTopic] {
        topic.subTopics
    }

    private var filteredItems: [String] {
        guard let idx = selectedSubIndex, subTopics.indices.contains(idx) else {
            return topic.items
        }
        return subTopics[idx].items
    }

    // ✅ אותו key כמו ב-ExerciseDetailView
    private func storageKeyBase(for item: String) -> String {
        let b = belt.id
        let t = topic.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let i = item.trimmingCharacters(in: .whitespacesAndNewlines)
        return "kmi.exercise.\(b).\(t).\(i)"
    }

    private func favKey(for item: String) -> String {
        storageKeyBase(for: item) + ".fav"
    }

    private func loadBool(key: String, defaultValue: Bool) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil { return defaultValue }
        return UserDefaults.standard.bool(forKey: key)
    }

    private func saveBool(_ value: Bool, key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    private func refreshFavorites() {
        var m: [String: Bool] = [:]
        for it in filteredItems {
            m[it] = loadBool(key: favKey(for: it), defaultValue: false)
        }
        favoriteMap = m
    }

    private func toggleFavorite(for item: String) {
        let newValue = !(favoriteMap[item] ?? false)
        favoriteMap[item] = newValue
        saveBool(newValue, key: favKey(for: item))
    }

    var body: some View {
        ZStack {
            TopicGradientBackground()

            ScrollView {
                VStack(spacing: 12) {

                    WhiteCard {
                        VStack(spacing: 8) {
                            Text(topic.title)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color.black.opacity(0.85))
                                .frame(maxWidth: .infinity, alignment: .center)

                            Text("חגורה: \(belt.heb)  •  פריטים: \(filteredItems.count)")
                                .font(.caption)
                                .foregroundStyle(Color.black.opacity(0.55))
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                    }

                    if !subTopics.isEmpty {
                        WhiteCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("תתי־נושאים")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(Color.black.opacity(0.82))

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        chip(
                                            title: "הכל",
                                            selected: selectedSubIndex == nil
                                        ) {
                                            selectedSubIndex = nil
                                        }

                                        ForEach(Array(subTopics.enumerated()), id: \.offset) { idx, st in
                                            chip(
                                                title: st.title,
                                                selected: selectedSubIndex == idx
                                            ) {
                                                selectedSubIndex = idx
                                            }
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                        }
                    }

                    WhiteCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("תרגילים")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.black.opacity(0.82))

                            VStack(spacing: 10) {
                                ForEach(filteredItems, id: \.self) { item in
                                    Button {
                                        selectedItem = item
                                        showExercise = true
                                    } label: {
                                        HStack(spacing: 10) {

                                            Image(systemName: (favoriteMap[item] ?? false) ? "star.fill" : "star")
                                                .font(.system(size: 16, weight: .heavy))
                                                .foregroundStyle(
                                                    (favoriteMap[item] ?? false)
                                                    ? Color.yellow.opacity(0.95)
                                                    : Color.black.opacity(0.35)
                                                )
                                                .frame(width: 34, height: 34)
                                                .background(
                                                    Circle().fill(Color.white.opacity(0.92))
                                                )
                                                .contentShape(Circle())
                                                .onTapGesture {
                                                    toggleFavorite(for: item)
                                                }

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
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                    }

                    Spacer(minLength: 18)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 22)
            }
        }
        .navigationTitle("נושא")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showExercise) {
            if let item = selectedItem {
                ExerciseDetailView(
                    belt: belt,
                    topicTitle: topic.title,
                    item: item
                )
            } else {
                EmptyView()
            }
        }
        .onAppear {
            refreshFavorites()
        }
        .onChange(of: selectedSubIndex) {
            refreshFavorites()
        }
        .onChange(of: showExercise) {
            if !showExercise {
                refreshFavorites()
            }
        }
    }

    // MARK: - Small chip
    private func chip(title: String, selected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(selected ? Color.white : Color.black.opacity(0.75))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(selected ? Color.black.opacity(0.70) : Color.white.opacity(0.92))
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        TopicContentView(
            belt: .orange,
            topic: CatalogData.shared.data[.orange]!.topics.first!
        )
    }
}

// MARK: - Local background
private struct TopicGradientBackground: View {
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
