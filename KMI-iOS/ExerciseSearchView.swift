import SwiftUI
import Shared

struct ExerciseSearchView: View {

    @State private var query: String = ""
    @State private var selected: ExerciseHit? = nil

    private let catalog = CatalogData.shared.data
    private let belts: [Belt] = [.white, .yellow, .orange, .green, .blue, .brown, .black]

    struct ExerciseHit: Identifiable, Hashable {
        let belt: Belt
        let topic: String
        let item: String

        var key: String { "\(belt.id)|\(topic)|\(item)" }
        var id: String { key }
    }

    private func allExercises(for belt: Belt) -> [ExerciseHit] {
        guard let beltContent = catalog[belt] else { return [] }

        var out: [ExerciseHit] = []

        for topic in beltContent.topics {
            for item in topic.items {
                out.append(
                    ExerciseHit(
                        belt: belt,
                        topic: topic.title,
                        item: item
                    )
                )
            }

            for subTopic in topic.subTopics {
                for item in subTopic.items {
                    out.append(
                        ExerciseHit(
                            belt: belt,
                            topic: topic.title,
                            item: item
                        )
                    )
                }
            }
        }

        var seen = Set<String>()
        return out.filter { seen.insert($0.key).inserted }
    }

    private func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "״", with: "")
            .replacingOccurrences(of: "\"", with: "")
    }

    private var results: [ExerciseHit] {
        let q = normalize(query)
        if q.isEmpty { return [] }

        var out: [ExerciseHit] = []
        for belt in belts {
            for hit in allExercises(for: belt) {
                if normalize(hit.item).localizedCaseInsensitiveContains(q) {
                    out.append(hit)
                }
            }
        }
        return out
    }

    var body: some View {
        ZStack {
            BeltTopicsGradientBackground()

            VStack(spacing: 12) {

                WhiteCard {
                    VStack(alignment: .trailing, spacing: 10) {

                        Text("חיפוש תרגיל")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(Color.black.opacity(0.82))
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        TextField("הקלד שם תרגיל…", text: $query)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.black.opacity(0.06))
                            )

                        if query.isEmpty {
                            Text("חפש לפי שם תרגיל כדי לקבל גם הסבר, מועדפים והערה.")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.black.opacity(0.55))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)

                ScrollView {
                    VStack(spacing: 10) {

                        ForEach(results) { hit in
                            Button {
                                selected = hit
                            } label: {
                                WhiteCard {
                                    HStack(spacing: 10) {
                                        Text(hit.belt.heb)
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.black.opacity(0.55))

                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(hit.item)
                                                .font(.body.weight(.heavy))
                                                .foregroundStyle(Color.black.opacity(0.82))
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                                .lineLimit(2)

                                            Text(hit.topic)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(Color.black.opacity(0.50))
                                                .frame(maxWidth: .infinity, alignment: .trailing)

                                            Text("לחץ לפרטים")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(Color.black.opacity(0.55))
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                        }

                                        Image(systemName: "chevron.left")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Color.black.opacity(0.35))
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 12)
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 18)
                        }

                        if !query.isEmpty && results.isEmpty {
                            WhiteCard {
                                Text("לא נמצאו תוצאות")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.black.opacity(0.55))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 14)
                            }
                            .padding(.horizontal, 18)
                        }

                        Spacer(minLength: 18)
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 22)
                }
            }
        }
        .navigationTitle("חיפוש")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { hit in
            ExerciseDetailsSheet(hit: hit)
        }
    }
}

private struct ExerciseDetailsSheet: View {

    let hit: ExerciseSearchView.ExerciseHit

    @Environment(\.dismiss) private var dismiss
    @State private var noteText: String = ""
    @State private var didLoadNote = false
    @State private var favoriteRefreshToken = UUID()

    private var explanation: String {
        let text = LocalExplanations.shared.get(belt: hit.belt, item: hit.item)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "לא נמצא הסבר לתרגיל זה." : trimmed
    }

    private var noteKey: String {
        "kmi.note.\(hit.key)"
    }

    private var isFavorite: Bool {
        UserDefaults.standard.bool(forKey: favoriteKey)
    }

    private var favoriteKey: String {
        "kmi.favorite.\(hit.key)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BeltTopicsGradientBackground()

                ScrollView {
                    WhiteCard {
                        VStack(alignment: .trailing, spacing: 14) {

                            HStack(spacing: 10) {
                                Button {
                                    toggleFavorite()
                                } label: {
                                    Image(systemName: isFavorite ? "star.fill" : "star")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(isFavorite ? Color.yellow.opacity(0.95) : Color.black.opacity(0.55))
                                        .frame(width: 40, height: 40)
                                        .background(
                                            Circle()
                                                .fill(Color.black.opacity(0.06))
                                        )
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(hit.item)
                                        .font(.title3.weight(.heavy))
                                        .foregroundStyle(Color.black.opacity(0.85))
                                        .frame(maxWidth: .infinity, alignment: .trailing)

                                    Text("חגורה \(hit.belt.heb) • \(hit.topic)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.black.opacity(0.55))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                            }

                            Divider().opacity(0.2)

                            VStack(alignment: .trailing, spacing: 8) {
                                Text("הסבר על התרגיל")
                                    .font(.headline.weight(.heavy))
                                    .foregroundStyle(Color.black.opacity(0.82))
                                    .frame(maxWidth: .infinity, alignment: .trailing)

                                Text(explanation)
                                    .font(.body)
                                    .foregroundStyle(Color.black.opacity(0.82))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .multilineTextAlignment(.trailing)
                            }

                            Divider().opacity(0.2)

                            VStack(alignment: .trailing, spacing: 8) {
                                Text("הערת המתאמן:")
                                    .font(.headline.weight(.heavy))
                                    .foregroundStyle(Color.black.opacity(0.82))
                                    .frame(maxWidth: .infinity, alignment: .trailing)

                                TextEditor(text: $noteText)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 130)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color.black.opacity(0.05))
                                    )
                                    .multilineTextAlignment(.trailing)

                                HStack(spacing: 10) {
                                    Button {
                                        clearNote()
                                    } label: {
                                        Text("נקה")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(Color.black.opacity(0.70))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(Color.black.opacity(0.08))
                                            )
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        saveNote()
                                    } label: {
                                        Text("שמור הערה")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(Color.black.opacity(0.78))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 22)
                }
            }
            .navigationTitle("פרטי תרגיל")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("סגור") { dismiss() }
                }
            }
            .id(favoriteRefreshToken)
            .onAppear {
                loadNoteIfNeeded()
            }
        }
    }

    private func loadNoteIfNeeded() {
        guard !didLoadNote else { return }
        noteText = UserDefaults.standard.string(forKey: noteKey) ?? ""
        didLoadNote = true
    }

    private func saveNote() {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: noteKey)
        noteText = trimmed
    }

    private func clearNote() {
        UserDefaults.standard.removeObject(forKey: noteKey)
        noteText = ""
    }

    private func toggleFavorite() {
        let newValue = !UserDefaults.standard.bool(forKey: favoriteKey)
        UserDefaults.standard.set(newValue, forKey: favoriteKey)
        favoriteRefreshToken = UUID()
    }
}
