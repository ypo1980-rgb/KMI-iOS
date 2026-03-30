import SwiftUI
import Shared
import AVFoundation

struct MaterialsView: View {
    let belt: Belt
    let topicTitle: String
    let subTopicTitle: String?

    @Environment(\.dismiss) private var dismiss

    var onSummary: (Belt, String, String?) -> Void = { _, _, _ in }
    var onPractice: (Belt, String) -> Void = { _, _ in }

    fileprivate enum RowMark: String {
        case mastered
        case unknown
    }

    private struct ExerciseRow: Identifiable, Hashable {
        let id: String
        let rawItem: String
        let displayName: String
    }

    @State private var favorites: Set<String> = []
    @State private var excluded: Set<String> = []
    @State private var marks: [String: RowMark?] = [:]
    @State private var notes: [String: String] = [:]

    @State private var selectedInfoRow: ExerciseRow? = nil
    @State private var selectedNoteRow: ExerciseRow? = nil
    @State private var noteDraft: String = ""

    @State private var refreshToken = UUID()

    @State private var speechSynth = AVSpeechSynthesizer()

    private var scopeKey: String {
        let topic = topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let sub = subTopicTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return "\(belt.id)||\(topic)||\(sub)"
    }

    private var rows: [ExerciseRow] {
        let topic = topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let sub = subTopicTitle?.trimmingCharacters(in: .whitespacesAndNewlines)

        let all = ContentRepo.shared.getAllItemsFor(
            belt: belt,
            topicTitle: topic,
            subTopicTitle: (sub?.isEmpty == false ? sub : nil)
        )

        var seen = Set<String>()
        return all
            .map { raw in
                ExerciseRow(
                    id: canonicalId(for: raw),
                    rawItem: raw,
                    displayName: displayName(for: raw)
                )
            }
            .filter { row in
                seen.insert(row.id).inserted
            }
    }

    private var headerTitle: String {
        if let subTopicTitle, !subTopicTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(topicTitle) – \(subTopicTitle)"
        }
        return topicTitle
    }

    var body: some View {
        ZStack {
            KmiGradientBackground(forceTraineeStyle: false)

            VStack(spacing: 0) {
                MaterialsHeaderCard(
                    belt: belt,
                    title: headerTitle,
                    count: rows.count,
                    onBack: {
                        dismiss()
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)

                ScrollView {
                    WhiteCard {
                        VStack(spacing: 0) {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                                MaterialsExerciseRow(
                                    title: row.displayName,
                                    isFavorite: favorites.contains(row.id),
                                    isExcluded: excluded.contains(row.id),
                                    mark: currentMark(for: row.id),
                                    hasNote: !(notes[row.id]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
                                    onToggleFavorite: {
                                        toggleFavorite(row.id)
                                    },
                                    onToggleExcluded: {
                                        toggleExcluded(row.id)
                                    },
                                    onShowInfo: {
                                        selectedInfoRow = row
                                    },
                                    onEditNote: {
                                        noteDraft = notes[row.id] ?? ""
                                        selectedNoteRow = row
                                    },
                                    onMarkDone: {
                                        toggleMark(.mastered, for: row.id)
                                    },
                                    onMarkNotDone: {
                                        toggleMark(.unknown, for: row.id)
                                    }
                                )

                                if idx != rows.count - 1 {
                                    Divider().opacity(0.22)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                    .id(refreshToken)
                }

                MaterialsBottomBar(
                    onPractice: {
                        onPractice(belt, topicTitle)
                    },
                    onSummary: {
                        onSummary(belt, topicTitle, subTopicTitle)
                    },
                    onReset: {
                        resetCurrentScope()
                    }
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            loadState()
        }
        .sheet(item: $selectedInfoRow) { row in
            MaterialsInfoSheet(
                title: row.displayName,
                text: explanationText(for: row),
                isFavorite: favorites.contains(row.id),
                onToggleFavorite: {
                    toggleFavorite(row.id)
                },
                onSpeak: {
                    speak(explanationText(for: row))
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $selectedNoteRow) { row in
            NavigationStack {
                VStack(spacing: 16) {
                    Text(row.displayName)
                        .font(.headline)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    TextEditor(text: $noteDraft)
                        .frame(minHeight: 180)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.9))
                        )

                    HStack(spacing: 12) {
                        Button("מחק") {
                            noteDraft = ""
                            saveNote("", for: row.id)
                            selectedNoteRow = nil
                        }
                        .buttonStyle(.bordered)

                        Button("שמור") {
                            saveNote(noteDraft, for: row.id)
                            selectedNoteRow = nil
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Spacer()
                }
                .padding(16)
                .navigationTitle("הערה לתרגיל")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("סגור") {
                            selectedNoteRow = nil
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Helpers

    private func canonicalId(for rawItem: String) -> String {
        let topic = topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let sub = subTopicTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let item = rawItem.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(belt.id)||\(topic)||\(sub)||\(item)"
    }

    private func displayName(for rawItem: String) -> String {
        var text = rawItem.trimmingCharacters(in: .whitespacesAndNewlines)

        let topic = topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
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
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func explanationText(for row: ExerciseRow) -> String {
        // TODO: כשנחבר את מקור ההסברים האמיתי ב-iOS, נחליף כאן.
        return "אין כרגע הסבר זמין עבור \"\(row.displayName)\"."
    }

    private func favoriteKey(for id: String) -> String { "favorite.\(id)" }
    private func excludedKey(for id: String) -> String { "excluded.\(id)" }
    private func markKey(for id: String) -> String { "mark.\(id)" }
    private func noteKey(for id: String) -> String { "note.\(id)" }

    private func loadState() {
        var loadedFavorites = Set<String>()
        var loadedExcluded = Set<String>()
        var loadedMarks: [String: RowMark?] = [:]
        var loadedNotes: [String: String] = [:]

        for row in rows {
            if UserDefaults.standard.bool(forKey: favoriteKey(for: row.id)) {
                loadedFavorites.insert(row.id)
            }

            if UserDefaults.standard.bool(forKey: excludedKey(for: row.id)) {
                loadedExcluded.insert(row.id)
            }

            if let raw = UserDefaults.standard.string(forKey: markKey(for: row.id)) {
                loadedMarks[row.id] = RowMark(rawValue: raw)
            } else {
                loadedMarks[row.id] = nil
            }

            loadedNotes[row.id] = UserDefaults.standard.string(forKey: noteKey(for: row.id)) ?? ""
        }

        favorites = loadedFavorites
        excluded = loadedExcluded
        marks = loadedMarks
        notes = loadedNotes
    }

    private func toggleFavorite(_ id: String) {
        if favorites.contains(id) {
            favorites.remove(id)
            UserDefaults.standard.set(false, forKey: favoriteKey(for: id))
        } else {
            favorites.insert(id)
            UserDefaults.standard.set(true, forKey: favoriteKey(for: id))
        }
    }

    private func toggleExcluded(_ id: String) {
        if excluded.contains(id) {
            excluded.remove(id)
            UserDefaults.standard.set(false, forKey: excludedKey(for: id))
        } else {
            excluded.insert(id)
            UserDefaults.standard.set(true, forKey: excludedKey(for: id))
        }
    }

    private func currentMark(for id: String) -> RowMark? {
        if let value = marks[id] {
            return value
        }
        return nil
    }

    private func toggleMark(_ mark: RowMark, for id: String) {
        let next: RowMark? = (currentMark(for: id) == mark) ? nil : mark
        marks[id] = next

        let key = markKey(for: id)
        if let next {
            UserDefaults.standard.set(next.rawValue, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func saveNote(_ text: String, for id: String) {
        notes[id] = text
        let key = noteKey(for: id)

        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(text, forKey: key)
        }
    }

    private func resetCurrentScope() {
        favorites.removeAll()
        excluded.removeAll()
        marks.removeAll()
        notes.removeAll()

        for row in rows {
            UserDefaults.standard.set(false, forKey: favoriteKey(for: row.id))
            UserDefaults.standard.set(false, forKey: excludedKey(for: row.id))
            UserDefaults.standard.removeObject(forKey: markKey(for: row.id))
            UserDefaults.standard.removeObject(forKey: noteKey(for: row.id))
        }

        refreshToken = UUID()
    }

    private func speak(_ text: String) {
        speechSynth.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "he-IL")
        utterance.rate = 0.48
        speechSynth.speak(utterance)
    }
}

// MARK: - Header

private struct MaterialsHeaderCard: View {
    let belt: Belt
    let title: String
    let count: Int
    let onBack: () -> Void

    var body: some View {
        WhiteCard {
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Color.black.opacity(0.22)))
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.black.opacity(0.85))
                        .multilineTextAlignment(.center)

                    Text("\(count) תרגילים")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.black.opacity(0.60))
                }

                Spacer()

                Circle()
                    .fill(BeltPaletteByMaterials.color(for: belt))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.7), lineWidth: 2)
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Row

private struct MaterialsExerciseRow: View {
    let title: String
    let isFavorite: Bool
    let isExcluded: Bool
    let mark: MaterialsView.RowMark?
    let hasNote: Bool

    let onToggleFavorite: () -> Void
    let onToggleExcluded: () -> Void
    let onShowInfo: () -> Void
    let onEditNote: () -> Void
    let onMarkDone: () -> Void
    let onMarkNotDone: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                Button(isFavorite ? "הסר ממועדפים" : "הוסף למועדפים", action: onToggleFavorite)
                Button(isExcluded ? "בטל החרגה" : "החרג מתרגול", action: onToggleExcluded)
                Button("מידע על התרגיל", action: onShowInfo)
                Button(hasNote ? "ערוך / מחק הערה" : "הוסף הערה", action: onEditNote)
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.75))
                    .frame(width: 38, height: 38)
            }

            VStack(alignment: .trailing, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isExcluded ? Color.gray : Color.black.opacity(0.84))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                HStack(spacing: 8) {
                    if hasNote {
                        Image(systemName: "note.text")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.5))
                    }

                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.yellow)
                    }

                    if isExcluded {
                        Text("מוחרג")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.red.opacity(0.75))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            HStack(spacing: 10) {
                MaterialsMarkCircleButton(
                    systemName: "xmark",
                    isSelected: mark == .unknown,
                    selectedFill: Color.red.opacity(0.75),
                    unselectedFill: Color.red.opacity(0.18),
                    onTap: onMarkNotDone
                )

                MaterialsMarkCircleButton(
                    systemName: "checkmark",
                    isSelected: mark == .mastered,
                    selectedFill: Color.green.opacity(0.75),
                    unselectedFill: Color.green.opacity(0.18),
                    onTap: onMarkDone
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.38))
        )
        .padding(.vertical, 4)
    }
}

private struct MaterialsMarkCircleButton: View {
    let systemName: String
    let isSelected: Bool
    let selectedFill: Color
    let unselectedFill: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(isSelected ? selectedFill : unselectedFill)
                    .frame(width: 38, height: 38)

                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(isSelected ? 0.95 : 0.55))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bottom bar

private struct MaterialsBottomBar: View {
    let onPractice: () -> Void
    let onSummary: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                MaterialsActionButton(
                    title: "תרגול",
                    fill: Color(red: 0.44, green: 0.39, blue: 1.0),
                    onTap: onPractice
                )

                MaterialsActionButton(
                    title: "איפוס",
                    fill: Color.red.opacity(0.82),
                    onTap: onReset
                )
            }

            HStack(spacing: 12) {
                MaterialsActionButton(
                    title: "מסך סיכום",
                    fill: Color(red: 0.44, green: 0.39, blue: 1.0),
                    onTap: onSummary
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

private struct MaterialsActionButton: View {
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

// MARK: - Info sheet

private struct MaterialsInfoSheet: View {
    let title: String
    let text: String
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let onSpeak: () -> Void

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

                    Button("השמע") {
                        onSpeak()
                    }
                    .buttonStyle(.borderedProminent)
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

// MARK: - Palette

private enum BeltPaletteByMaterials {
    static let white  = Color(red: 0.92, green: 0.92, blue: 0.92)
    static let yellow = Color(red: 0.98, green: 0.85, blue: 0.18)
    static let orange = Color(red: 0.98, green: 0.64, blue: 0.15)
    static let green  = Color(red: 0.18, green: 0.80, blue: 0.44)
    static let blue   = Color(red: 0.18, green: 0.52, blue: 0.95)
    static let brown  = Color(red: 0.55, green: 0.34, blue: 0.23)
    static let black  = Color(red: 0.10, green: 0.10, blue: 0.12)

    static func color(for belt: Belt) -> Color {
        switch belt {
        case .white:  return white
        case .yellow: return yellow
        case .orange: return orange
        case .green:  return green
        case .blue:   return blue
        case .brown:  return brown
        case .black:  return black
        default:      return orange
        }
    }
}

#Preview {
    NavigationStack {
        MaterialsView(
            belt: .orange,
            topicTitle: "שחרורים",
            subTopicTitle: nil
        )
    }
}
