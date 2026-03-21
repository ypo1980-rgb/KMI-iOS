import SwiftUI
import Shared

struct ExercisesTabsView: View {
    let belt: Belt
    let topicTitle: String
    let subTopicTitle: String?
    let onPractice: (Belt, String) -> Void
    let onHome: () -> Void

    private enum TabKind: Int, CaseIterable {
        case all = 0
        case unknown = 1
        case favorites = 2

        var title: String {
            switch self {
            case .all: return "הכל"
            case .unknown: return "לא יודע"
            case .favorites: return "מועדפים"
            }
        }
    }

    private struct ExerciseItem: Identifiable, Hashable {
        let id: String
        let rawItem: String
        let displayName: String
        let resolvedTopicTitle: String
    }

    @State private var selectedTab: TabKind = .all
    @State private var selectedInfoItem: ExerciseItem? = nil

    private var allItems: [ExerciseItem] {
        var built: [ExerciseItem] = []
        var seen = Set<String>()

        if topicTitle == "__ALL__" {
            let topicTitles = TopicsEngine.shared.topicTitlesFor(belt: belt)

            for tp in topicTitles {
                let rawItems = ContentRepo.shared.getAllItemsFor(
                    belt: belt,
                    topicTitle: tp,
                    subTopicTitle: nil
                )

                for raw in rawItems {
                    let item = ExerciseItem(
                        id: canonicalId(for: raw, resolvedTopicTitle: tp),
                        rawItem: raw,
                        displayName: displayName(for: raw, resolvedTopicTitle: tp),
                        resolvedTopicTitle: tp
                    )

                    if seen.insert(item.id).inserted {
                        built.append(item)
                    }
                }
            }

            return built
        }

        let rawItems = ContentRepo.shared.getAllItemsFor(
            belt: belt,
            topicTitle: topicTitle,
            subTopicTitle: subTopicTitle
        )

        for raw in rawItems {
            let item = ExerciseItem(
                id: canonicalId(for: raw, resolvedTopicTitle: topicTitle),
                rawItem: raw,
                displayName: displayName(for: raw, resolvedTopicTitle: topicTitle),
                resolvedTopicTitle: topicTitle
            )

            if seen.insert(item.id).inserted {
                built.append(item)
            }
        }

        return built
    }

    private var unknownIds: Set<String> {
        Set(allItems.compactMap { item in
            let raw = UserDefaults.standard.string(forKey: "mark.\(item.id)")
            return raw == "unknown" ? item.id : nil
        })
    }

    private var favoriteIds: Set<String> {
        Set(allItems.compactMap { item in
            UserDefaults.standard.bool(forKey: "favorite.\(item.id)") ? item.id : nil
        })
    }

    private var filteredItems: [ExerciseItem] {
        switch selectedTab {
        case .all:
            return allItems
        case .unknown:
            return allItems.filter { unknownIds.contains($0.id) }
        case .favorites:
            return allItems.filter { favoriteIds.contains($0.id) }
        }
    }

    var body: some View {
        ZStack {
            KmiGradientBackground()

            VStack(spacing: 0) {
                WhiteCard {
                    HStack(spacing: 0) {
                        tabCard(.all, count: allItems.count)
                        tabCard(.unknown, count: unknownIds.count)
                        tabCard(.favorites, count: favoriteIds.count)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                ScrollView {
                    WhiteCard {
                        VStack(spacing: 0) {
                            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { idx, item in
                                HStack(spacing: 12) {
                                    Button {
                                        selectedInfoItem = item
                                    } label: {
                                        Image(systemName: "info.circle.fill")
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(Color.black.opacity(0.72))
                                    }
                                    .buttonStyle(.plain)

                                    Text(item.displayName)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Color.black.opacity(0.84))
                                        .multilineTextAlignment(.trailing)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                                .padding(.vertical, 10)

                                if idx != filteredItems.count - 1 {
                                    Divider().opacity(0.22)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        ExercisesTabsActionButton(
                            title: "תרגול",
                            fill: Color(red: 0.44, green: 0.39, blue: 1.0),
                            onTap: {
                                let practiceToken: String
                                switch selectedTab {
                                case .all:
                                    practiceToken = topicTitle
                                case .unknown:
                                    practiceToken = "__UNKNOWN__"
                                case .favorites:
                                    practiceToken = "__FAVORITES__"
                                }
                                onPractice(belt, practiceToken)
                            }
                        )

                        ExercisesTabsActionButton(
                            title: "בית",
                            fill: Color.red.opacity(0.82),
                            onTap: onHome
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 18)
                .background(
                    RoundedRectangle(cornerRadius: 0, style: .continuous)
                        .fill(Color(white: 0.88))
                        .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        .navigationTitle("כרטיסיות תרגילים")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedInfoItem) { item in
            ExercisesTabsInfoSheet(
                title: item.displayName,
                text: explanationText(for: item),
                isFavorite: UserDefaults.standard.bool(forKey: "favorite.\(item.id)"),
                onToggleFavorite: {
                    let key = "favorite.\(item.id)"
                    let current = UserDefaults.standard.bool(forKey: key)
                    UserDefaults.standard.set(!current, forKey: key)
                }
            )
            .presentationDetents([PresentationDetent.medium, PresentationDetent.large])
        }
    }

    @ViewBuilder
    private func tabCard(_ tab: TabKind, count: Int) -> some View {
        let isSelected = selectedTab == tab

        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Text(tab.title)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.88))

                Text("\(count)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.66))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(
                isSelected
                ? Color.purple.opacity(0.18)
                : Color.black.opacity(0.06)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 0, style: .continuous)
                    .stroke(
                        isSelected
                        ? Color.purple.opacity(0.55)
                        : Color.black.opacity(0.08),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func canonicalId(for rawItem: String, resolvedTopicTitle: String) -> String {
        let topic = resolvedTopicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let sub = subTopicTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let item = rawItem.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(belt.id)||\(topic)||\(sub)||\(item)"
    }

    private func displayName(for rawItem: String, resolvedTopicTitle: String) -> String {
        var text = rawItem.trimmingCharacters(in: .whitespacesAndNewlines)

        let topic = resolvedTopicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("\(topic)::") {
            text = String(text.dropFirst("\(topic)::".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let subTopicTitle {
            let sub = subTopicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.hasPrefix("\(sub)::") {
                text = String(text.dropFirst("\(sub)::".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return text
    }

    private func explanationText(for item: ExerciseItem) -> String {
        "אין כרגע הסבר זמין עבור \"\(item.displayName)\"."
    }
}

private struct ExercisesTabsActionButton: View {
    let title: String
    let fill: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(fill)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct ExercisesTabsInfoSheet: View {
    let title: String
    let text: String
    let isFavorite: Bool
    let onToggleFavorite: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                ScrollView {
                    Text(text)
                        .font(.body)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                HStack(spacing: 12) {
                    Button(isFavorite ? "הסר ממועדפים" : "הוסף למועדפים") {
                        onToggleFavorite()
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding(16)
            .navigationTitle("מידע על התרגיל")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("סגור") {
                        dismiss()
                    }
                }
            }
        }
    }
}
