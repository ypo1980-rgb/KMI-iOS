import SwiftUI
import Shared

struct TrainingSummaryExercisePickerSheet: View {
    @ObservedObject var vm: TrainingSummaryViewModel
    let initialBelt: Belt
    let onDismiss: () -> Void

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
        TrainingSummaryCatalog.topics(for: selectedBelt)
    }

    private var subTopics: [String] {
        TrainingSummaryCatalog.subTopics(for: selectedBelt, topic: topic)
    }

    private var displayItems: [String] {
        let base = TrainingSummaryCatalog.items(
            for: selectedBelt,
            topic: topic,
            subTopic: subTopic.isEmpty ? nil : subTopic
        )

        let q = vm.state.searchQuery.trimmed()
        if q.isEmpty { return base }
        return base.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    sectionCard {
                        Text("הוספת תרגילים")
                            .font(.title3.weight(.heavy))
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Text("בחר חגורה, נושא ותת־נושא או הוסף תרגיל ידני")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    sectionCard {
                        Picker("חגורה", selection: $selectedBelt) {
                            ForEach(TrainingSummaryCatalog.belts, id: \.id) { belt in
                                Text(belt.heb).tag(belt)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedBelt) { newValue in
                            topic = ""
                            subTopic = ""
                            vm.setSelectedBelt(newValue)
                            vm.setSearchQuery("")
                        }

                        if !topics.isEmpty {
                            Picker("נושא", selection: $topic) {
                                Text("בחר נושא").tag("")
                                ForEach(topics, id: \.self) { value in
                                    Text(value).tag(value)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: topic) { _ in
                                subTopic = ""
                                vm.setSearchQuery("")
                            }
                        }

                        if !subTopics.isEmpty {
                            Picker("תת-נושא", selection: $subTopic) {
                                Text("בחר תת-נושא").tag("")
                                ForEach(subTopics, id: \.self) { value in
                                    Text(value).tag(value)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        if !topic.isEmpty {
                            TextField("חיפוש תרגיל", text: Binding(
                                get: { vm.state.searchQuery },
                                set: { vm.setSearchQuery($0) }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                        }
                    }

                    if !displayItems.isEmpty {
                        sectionCard {
                            Text("תרגילים זמינים")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity, alignment: .trailing)

                            ForEach(displayItems, id: \.self) { item in
                                Button {
                                    let exerciseId = makeExerciseId(
                                        belt: selectedBelt,
                                        topic: topic,
                                        subTopic: subTopic,
                                        name: item
                                    )
                                    vm.toggleExercise(
                                        ExercisePickItem(
                                            exerciseId: exerciseId,
                                            name: item,
                                            topic: subTopic.isEmpty ? topic : "\(topic) · \(subTopic)"
                                        )
                                    )
                                } label: {
                                    HStack {
                                        if vm.state.selected[makeExerciseId(
                                            belt: selectedBelt,
                                            topic: topic,
                                            subTopic: subTopic,
                                            name: item
                                        )] != nil {
                                            Image(systemName: "checkmark.circle.fill")
                                        } else {
                                            Image(systemName: "plus.circle")
                                        }

                                        Spacer()

                                        Text(item)
                                            .foregroundStyle(.primary)
                                            .multilineTextAlignment(.trailing)
                                    }
                                }
                                .buttonStyle(.plain)

                                Divider()
                            }
                        }
                    }

                    sectionCard {
                        Text("הוספה ידנית")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        TextField("שם התרגיל", text: $manualExerciseName)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)

                        Button("הוסף תרגיל ידני") {
                            let clean = manualExerciseName.trimmed()
                            guard !clean.isEmpty else { return }

                            let exerciseId = makeExerciseId(
                                belt: selectedBelt,
                                topic: topic.isEmpty ? "כללי" : topic,
                                subTopic: subTopic,
                                name: clean
                            )

                            vm.toggleExercise(
                                ExercisePickItem(
                                    exerciseId: exerciseId,
                                    name: clean,
                                    topic: topic.isEmpty ? "כללי" : (subTopic.isEmpty ? topic : "\(topic) · \(subTopic)")
                                )
                            )

                            manualExerciseName = ""
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("תרגילים")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("סגור") {
                        onDismiss()
                    }
                }
            }
        }
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 10, content: content)
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func makeExerciseId(
        belt: Belt,
        topic: String,
        subTopic: String,
        name: String
    ) -> String {
        "\(belt.id)|\(topic)|\(subTopic)|\(name)"
    }
}

private extension String {
    func trimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
