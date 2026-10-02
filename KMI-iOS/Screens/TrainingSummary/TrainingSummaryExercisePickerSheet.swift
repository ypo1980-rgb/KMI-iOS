import SwiftUI
import Shared

struct TrainingSummaryExercisePickerSheet: View {
    @ObservedObject var vm: TrainingSummaryViewModel
    let initialBelt: Belt
    let onDismiss: () -> Void

    @Environment(\.colorScheme)
    private var colorScheme

    @AppStorage("kmi_app_language")
    private var languageCode = "he"

    private var isEnglish: Bool {
        let code = languageCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return code == "en" || code == "english"
    }

    private func tr(_ hebrew: String, _ english: String) -> String {
        isEnglish ? english : hebrew
    }

    @State private var selectedBelt: Belt
    @State private var topic: String = ""
    @State private var subTopic: String = ""
    @State private var manualExerciseName: String = ""

    init(
        vm: TrainingSummaryViewModel,
        initialBelt: Belt,
        onDismiss: @escaping () -> Void
    ) {
        self.vm = vm
        self.initialBelt = initialBelt
        self.onDismiss = onDismiss
        _selectedBelt = State(initialValue: initialBelt)
    }

    private var topics: [String] {
        uniqueTitles(
            TopicsEngine.shared.topicTitlesFor(
                belt: selectedBelt
            )
        )
    }

    private var subTopics: [String] {
        guard !topic.isEmpty else {
            return []
        }

        return uniqueTitles(
            ContentRepo.shared.getSubTopicsFor(
                belt: selectedBelt,
                topicTitle: topic
            )
            .map(\.title)
        )
        .filter { $0 != topic }
    }

    private var displayItems: [String] {
        guard !topic.isEmpty else {
            return []
        }

        var items = ContentRepo.shared.getAllItemsFor(
            belt: selectedBelt,
            topicTitle: topic,
            subTopicTitle: subTopic.isEmpty ? nil : subTopic
        )

        // כמו במסך החגורות: "כל תתי־הנושאים"
        // כולל גם את התרגילים שבתתי־הנושאים.
        if subTopic.isEmpty {
            for title in subTopics {
                items.append(
                    contentsOf: ContentRepo.shared.getAllItemsFor(
                        belt: selectedBelt,
                        topicTitle: topic,
                        subTopicTitle: title
                    )
                )
            }
        }

        let uniqueItems = uniqueTitles(items)
        let query = vm.state.searchQuery.trimmed()

        guard !query.isEmpty else {
            return uniqueItems
        }

        return uniqueItems.filter { item in
            item.localizedCaseInsensitiveContains(query)
                || displayTitle(item)
                    .localizedCaseInsensitiveContains(query)
        }
    }

    private func uniqueTitles(_ values: [String]) -> [String] {
        var seen = Set<String>()

        return values.compactMap { value in
            let clean = value.trimmed()

            guard !clean.isEmpty,
                  seen.insert(clean).inserted else {
                return nil
            }

            return clean
        }
    }

    private func displayTitle(_ value: String) -> String {
        KmiEnglishTitleResolver.title(
            for: value,
            isEnglish: isEnglish
        )
    }

    private func beltTitle(_ belt: Belt) -> String {
        guard isEnglish else {
            return belt.heb
        }

        switch belt {
        case .white: return "White"
        case .yellow: return "Yellow"
        case .orange: return "Orange"
        case .green: return "Green"
        case .blue: return "Blue"
        case .brown: return "Brown"
        case .black: return "Black"
        default: return belt.heb
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    sectionCard {
                        Text(tr("הוספת תרגילים", "Add exercises"))
                            .kmiFont(size: 18, weight: .heavy)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(
                            tr(
                                "בחר חגורה, נושא ותת־נושא או הוסף תרגיל ידני",
                                "Choose a belt, topic and sub-topic, or add an exercise manually"
                            )
                        )
                        .kmiFont(size: 12, weight: .regular)
                        .foregroundStyle(
                            KmiAppTheme.onSurfaceVariant(for: colorScheme)
                        )
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    sectionCard {
                        Picker(
                            tr("חגורה", "Belt"),
                            selection: $selectedBelt
                        ) {
                            ForEach(
                                TrainingSummaryCatalog.belts,
                                id: \.id
                            ) { belt in
                                Text(beltTitle(belt)).tag(belt)
                            }
                        }
                        .pickerStyle(.menu)
                        .kmiFont(size: 14, weight: .bold)
                        .onChange(of: selectedBelt) { _, newValue in
                            topic = ""
                            subTopic = ""
                            vm.setSelectedBelt(newValue)
                            vm.setSearchQuery("")
                        }

                        if !topics.isEmpty {
                            Picker(
                                tr("נושא", "Topic"),
                                selection: $topic
                            ) {
                                Text(
                                    tr("בחר נושא", "Choose a topic")
                                )
                                .tag("")

                                ForEach(topics, id: \.self) { value in
                                    Text(displayTitle(value)).tag(value)
                                }
                            }
                            .pickerStyle(.menu)
                            .kmiFont(size: 14, weight: .bold)
                            .onChange(of: topic) { _, _ in
                                subTopic = ""
                                vm.setSearchQuery("")
                            }
                        }

                        if !subTopics.isEmpty {
                            Picker(
                                tr("תת־נושא", "Sub-topic"),
                                selection: $subTopic
                            ) {
                                Text(
                                    tr(
                                        "כל תתי־הנושאים",
                                        "All sub-topics"
                                    )
                                )
                                .tag("")

                                ForEach(subTopics, id: \.self) { value in
                                    Text(displayTitle(value)).tag(value)
                                }
                            }
                            .pickerStyle(.menu)
                            .kmiFont(size: 14, weight: .bold)
                        }

                        if !topic.isEmpty {
                            TextField(
                                tr("חיפוש תרגיל", "Search exercises"),
                                text: Binding(
                                    get: { vm.state.searchQuery },
                                    set: { vm.setSearchQuery($0) }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                            .kmiFont(size: 14, weight: .regular)
                            .multilineTextAlignment(.leading)
                            .submitLabel(.search)
                        }
                    }

                    if !displayItems.isEmpty {
                        sectionCard {
                            Text(
                                tr(
                                    "תרגילים זמינים",
                                    "Available exercises"
                                )
                            )
                            .kmiFont(size: 16, weight: .bold)
                            .frame(maxWidth: .infinity, alignment: .leading)

                            ForEach(displayItems, id: \.self) { item in
                                let exerciseId = makeExerciseId(
                                    belt: selectedBelt,
                                    topic: topic,
                                    subTopic: subTopic,
                                    name: item
                                )

                                let isSelected =
                                    vm.state.selected[exerciseId] != nil

                                Button {
                                    vm.toggleExercise(
                                        ExercisePickItem(
                                            exerciseId: exerciseId,
                                            name: item,
                                            topic: subTopic.isEmpty
                                                ? topic
                                                : "\(topic) · \(subTopic)"
                                        )
                                    )
                                } label: {
                                    HStack(alignment: .center, spacing: 10) {
                                        Image(
                                            systemName: isSelected
                                                ? "checkmark.circle.fill"
                                                : "plus.circle"
                                        )
                                        .kmiIconSize(20)
                                        .foregroundStyle(
                                            KmiAppTheme.primary(
                                                for: colorScheme
                                            )
                                        )
                                        .accessibilityHidden(true)

                                        Text(displayTitle(item))
                                            .kmiFont(
                                                size: 14,
                                                weight: .semibold
                                            )
                                            .foregroundStyle(
                                                KmiAppTheme.onSurface(
                                                    for: colorScheme
                                                )
                                            )
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(
                                                horizontal: false,
                                                vertical: true
                                            )
                                            .frame(
                                                maxWidth: .infinity,
                                                alignment: .leading
                                            )
                                    }
                                    .padding(.vertical, 8)
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: .leading
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(
                                    isSelected ? [.isSelected] : []
                                )

                                Rectangle()
                                    .fill(
                                        KmiAppTheme.outlineVariant(
                                            for: colorScheme
                                        )
                                    )
                                    .frame(height: 1)
                            }
                        }
                    } else if !topic.isEmpty {
                        sectionCard {
                            Text(
                                tr(
                                    "לא נמצאו תרגילים לסינון שנבחר.",
                                    "No exercises match the selected filters."
                                )
                            )
                            .kmiFont(size: 13, weight: .semibold)
                            .foregroundStyle(
                                KmiAppTheme.onSurfaceVariant(
                                    for: colorScheme
                                )
                            )
                            .multilineTextAlignment(.leading)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                        }
                    }

                    sectionCard {
                        Text(tr("הוספה ידנית", "Add manually"))
                            .kmiFont(size: 16, weight: .bold)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        TextField(
                            tr("שם התרגיל", "Exercise name"),
                            text: $manualExerciseName
                        )
                        .textFieldStyle(.roundedBorder)
                        .kmiFont(size: 14, weight: .regular)
                        .multilineTextAlignment(.leading)

                        Button(
                            tr(
                                "הוסף תרגיל ידני",
                                "Add exercise manually"
                            )
                        ) {
                            let clean = manualExerciseName.trimmed()
                            guard !clean.isEmpty else { return }

                            let exerciseId = makeExerciseId(
                                belt: selectedBelt,
                                topic: topic.isEmpty ? "כללי" : topic,
                                subTopic: subTopic,
                                name: clean
                            )

                            if vm.state.selected[exerciseId] == nil {
                                vm.toggleExercise(
                                    ExercisePickItem(
                                        exerciseId: exerciseId,
                                        name: clean,
                                        topic: topic.isEmpty
                                            ? "כללי"
                                            : (
                                                subTopic.isEmpty
                                                    ? topic
                                                    : "\(topic) · \(subTopic)"
                                            )
                                    )
                                )
                            }

                            manualExerciseName = ""
                        }
                        .buttonStyle(.borderedProminent)
                        .kmiFont(size: 14, weight: .bold)
                        .disabled(manualExerciseName.trimmed().isEmpty)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12)
            }
            .scrollDismissesKeyboard(.interactively)
            .background {
                LinearGradient(
                    colors: KmiAppTheme.screenBackgroundColors(
                        for: colorScheme
                    ),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            .navigationTitle(tr("תרגילים", "Exercises"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("סגור", "Close")) {
                        onDismiss()
                    }
                }
            }
        }
        .environment(
            \.layoutDirection,
            isEnglish ? .leftToRight : .rightToLeft
        )
        .environment(
            \.locale,
            Locale(identifier: isEnglish ? "en_US" : "he_IL")
        )
        .tint(KmiAppTheme.primary(for: colorScheme))
        .kmiFont(size: 14, weight: .regular)
        .onAppear {
            vm.setSelectedBelt(selectedBelt)
            vm.setSearchQuery("")
        }
    }

    private func sectionCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .foregroundStyle(
                KmiAppTheme.onSurface(for: colorScheme)
            )
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        KmiAppTheme.surface(for: colorScheme)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        KmiAppTheme.outlineVariant(
                            for: colorScheme
                        ),
                        lineWidth: 1
                    )
            )
    }

    private func makeExerciseId(
        belt: Belt,
        topic: String,
        subTopic _: String,
        name: String
    ) -> String {
        "\(belt.id)|\(topic.trimmed())||\(name.trimmed())"
    }
}

private extension String {
    func trimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
