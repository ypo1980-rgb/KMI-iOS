import SwiftUI
import UIKit
import Shared
import AVFoundation

struct MaterialsView: View {
    let belt: Belt
    let topicTitle: String
    let subTopicTitle: String?

    @Environment(\.dismiss) private var dismiss

    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"
    @AppStorage("selected_language_code") private var selectedLanguageCode: String = "he"

    private var effectiveLanguageCode: String {
        let orderedValues = [
            kmiAppLanguageCode,
            selectedLanguageCode,
            appLanguageRaw,
            initialLanguageCode
        ]

        for raw in orderedValues {
            let clean = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            if clean == "he" || clean == "hebrew" || clean == "עברית" {
                return "he"
            }

            if clean == "en" || clean == "english" {
                return "en"
            }
        }

        return "he"
    }

    private var isEnglish: Bool {
        effectiveLanguageCode == "en"
    }

    private var screenLayoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    private var primaryTextAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var horizontalTextAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    var onSummary: (Belt, String, String?) -> Void = { _, _, _ in }
    var onPractice: (Belt, String) -> Void = { _, _ in }
    var onOpenSubscription: () -> Void = {}

    private var hasFullAccessForPractice: Bool {
        let defaults = UserDefaults.standard
        let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)

        let accessUntil = Int64(defaults.integer(forKey: "sub_access_until"))

        return defaults.bool(forKey: "has_full_access") ||
        defaults.bool(forKey: "full_access") ||
        defaults.bool(forKey: "subscription_active") ||
        defaults.bool(forKey: "is_subscribed") ||
        defaults.bool(forKey: "google_subscription_verified") ||
        accessUntil > nowMillis
    }

    private var isPracticeLocked: Bool {
        !hasFullAccessForPractice
    }

    fileprivate enum RowMark: String {
        case mastered
        case unknown
    }

    private struct ExerciseRow: Identifiable, Hashable {
        let id: String
        let canonicalId: String
        let statusId: String
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

    private var topicUi: String {
        let clean = topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "כללי" : clean
    }

    private var subTopicUi: String? {
        guard let subTopicTitle else { return nil }
        let clean = subTopicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    private var topicKey: String {
        if let subTopicUi {
            return "\(topicUi)__\(subTopicUi)"
        }

        return topicUi
    }

    private var scopeKey: String {
        "\(belt.id)||\(topicUi)||\(subTopicUi ?? "")"
    }

    private func normalizeStatusPart(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{200F}", with: "")
            .replacingOccurrences(of: "\u{200E}", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func canonicalIdForStorage(rawItem: String) -> String {
        let item = rawItem.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(belt.id)||\(topicUi)||\(subTopicUi ?? "")||\(item)"
    }

    private func statusIdForStorage(index: Int, rawItem: String) -> String {
        let cleanItem = normalizeStatusPart(rawItem)
        return "status_\(belt.id)_\(topicKey)_\(index)_\(cleanItem)"
    }

    private var rows: [ExerciseRow] {
        let all = ContentRepo.shared.getAllItemsFor(
            belt: belt,
            topicTitle: topicUi,
            subTopicTitle: subTopicUi
        )

        var seenStatusIds = Set<String>()

        return all
            .enumerated()
            .map { index, raw in
                let canonical = canonicalIdForStorage(rawItem: raw)
                let status = statusIdForStorage(index: index, rawItem: raw)

                return ExerciseRow(
                    id: status,
                    canonicalId: canonical,
                    statusId: status,
                    rawItem: raw,
                    displayName: displayName(for: raw)
                )
            }
            .filter { row in
                seenStatusIds.insert(row.statusId).inserted
            }
    }

    private var headerTitle: String {
        let topicDisplay = KmiEnglishTitleResolver.title(for: topicUi, isEnglish: isEnglish)

        if let subTopicUi {
            let subDisplay = KmiEnglishTitleResolver.title(for: subTopicUi, isEnglish: isEnglish)
            return "\(topicDisplay) – \(subDisplay)"
        }

        return topicDisplay
    }

    var body: some View {
        ZStack {
            MaterialsScreenSoftBackground(belt: belt)

            VStack(spacing: 0) {
                MaterialsHeaderCard(
                    belt: belt,
                    title: headerTitle,
                    count: rows.count,
                    isEnglish: isEnglish,
                    onBack: {
                        dismiss()
                    }
                )

                Divider()
                    .background(BeltPaletteByMaterials.color(for: belt).opacity(0.14))

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                            MaterialsExerciseRow(
                                title: row.displayName,
                                beltColor: BeltPaletteByMaterials.color(for: belt),
                                isFavorite: favorites.contains(row.canonicalId),
                                isExcluded: excluded.contains(row.canonicalId),
                                mark: currentMark(for: row.statusId),
                                hasNote: !(notes[row.canonicalId]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
                                isEnglish: isEnglish,
                                onToggleFavorite: {
                                    toggleFavorite(row.canonicalId)
                                },
                                onToggleExcluded: {
                                    toggleExcluded(row.canonicalId)
                                },
                                onShowInfo: {
                                    selectedInfoRow = row
                                },
                                onEditNote: {
                                    noteDraft = notes[row.canonicalId] ?? ""
                                    selectedNoteRow = row
                                },
                                onCycleMark: {
                                    cycleMark(for: row.statusId)
                                }
                            )

                            if idx != rows.count - 1 {
                                Divider()
                                    .background(BeltPaletteByMaterials.color(for: belt).opacity(0.30))
                                    .padding(.horizontal, 8)
                            }
                        }
                    }
                    .padding(.top, 4)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .id(refreshToken)
                }
                .background(MaterialsBeltLightBackground(belt: belt))

                MaterialsBottomBar(
                    belt: belt,
                    isEnglish: isEnglish,
                    isPracticeLocked: isPracticeLocked,
                    onPractice: {
                        if isPracticeLocked {
                            onOpenSubscription()
                        } else {
                            onPractice(belt, topicUi)
                        }
                    },
                    onSummary: {
                        onSummary(belt, topicUi, subTopicUi)
                    },
                    onReset: {
                        resetCurrentScope()
                    }
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .environment(\.layoutDirection, screenLayoutDirection)
        .onAppear {
            loadState()
            debugPrintCurrentMaterials()
        }
        .sheet(item: $selectedInfoRow) { row in
            MaterialsInfoSheet(
                title: row.displayName,
                text: explanationText(for: row),
                isFavorite: favorites.contains(row.canonicalId),
                isEnglish: isEnglish,
                accentColor: BeltPaletteByMaterials.color(for: belt),
                onToggleFavorite: {
                    toggleFavorite(row.canonicalId)
                },
                onSpeak: {
                    speak(explanationText(for: row))
                },
                onEditNote: {
                    noteDraft = notes[row.canonicalId] ?? ""
                    selectedInfoRow = nil

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        selectedNoteRow = row
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedNoteRow) { row in
            MaterialsPremiumNoteSheet(
                title: row.displayName,
                noteText: $noteDraft,
                isEnglish: isEnglish,
                onCancel: {
                    selectedNoteRow = nil
                },
                onSave: {
                    saveNote(noteDraft, for: row.canonicalId)
                    selectedNoteRow = nil
                },
                onDelete: {
                    noteDraft = ""
                    saveNote("", for: row.canonicalId)
                    selectedNoteRow = nil
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Helpers

    private func canonicalId(for rawItem: String) -> String {
        canonicalIdForStorage(rawItem: rawItem)
    }

    private func displayName(for rawItem: String) -> String {
        var text = rawItem.trimmingCharacters(in: .whitespacesAndNewlines)

        if text.hasPrefix("\(topicUi)::") {
            text = String(text.dropFirst("\(topicUi)::".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let subTopicUi, text.hasPrefix("\(subTopicUi)::") {
            text = String(text.dropFirst("\(subTopicUi)::".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if text.hasPrefix(topicUi) {
            text = String(text.dropFirst(topicUi.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-–—: "))
        }

        let clean = text
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return KmiEnglishTitleResolver.title(for: clean, isEnglish: isEnglish)
    }

    private func explanationText(for row: ExerciseRow) -> String {
        let txt = LocalExplanations.shared.get(
            belt: belt,
            item: row.rawItem
        )

        let clean = txt.trimmingCharacters(in: .whitespacesAndNewlines)

        if clean.isEmpty {
            return tr(
                "לא נמצא הסבר לתרגיל זה.",
                "No explanation was found for this exercise."
            )
        }

        return clean
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
            if UserDefaults.standard.bool(forKey: favoriteKey(for: row.canonicalId)) {
                loadedFavorites.insert(row.canonicalId)
            }

            if UserDefaults.standard.bool(forKey: excludedKey(for: row.canonicalId)) {
                loadedExcluded.insert(row.canonicalId)
            }

            if let raw = UserDefaults.standard.string(forKey: markKey(for: row.statusId)) {
                loadedMarks[row.statusId] = RowMark(rawValue: raw)
            } else {
                loadedMarks[row.statusId] = nil
            }

            loadedNotes[row.canonicalId] = UserDefaults.standard.string(forKey: noteKey(for: row.canonicalId)) ?? ""
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

    private func cycleMark(for id: String) {
        let next: RowMark?

        switch currentMark(for: id) {
        case nil:
            next = .mastered
        case .mastered:
            next = .unknown
        case .unknown:
            next = nil
        }

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
            UserDefaults.standard.set(false, forKey: favoriteKey(for: row.canonicalId))
            UserDefaults.standard.set(false, forKey: excludedKey(for: row.canonicalId))
            UserDefaults.standard.removeObject(forKey: markKey(for: row.statusId))
            UserDefaults.standard.removeObject(forKey: noteKey(for: row.canonicalId))
        }

        refreshToken = UUID()
    }

    private func debugPrintCurrentMaterials() {
        #if DEBUG
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📚 KMI_MATERIALS_DEBUG")
        print("isEnglish =", isEnglish)
        print("kmi_app_language =", kmiAppLanguageCode)
        print("app_language =", appLanguageRaw)
        print("initial_language_code =", initialLanguageCode)
        print("selected_language_code =", selectedLanguageCode)
        print("effectiveLanguageCode =", effectiveLanguageCode)
        print("belt =", belt.id, "|", belt.heb)
        print("topicTitle =", topicTitle)
        print("subTopicTitle =", subTopicTitle ?? "nil")
        print("rows.count =", rows.count)

        for (index, row) in rows.enumerated() {
            print("\(index + 1). raw =", row.rawItem)
            print("   display =", row.displayName)
            print("   canonicalId =", row.canonicalId)
            print("   statusId =", row.statusId)
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        #endif
    }

    private func speak(_ text: String) {
        speechSynth.stopSpeaking(at: .immediate)

        let clean = text
            .replacingOccurrences(of: "•", with: ".")
            .replacingOccurrences(of: "/", with: ".")
            .replacingOccurrences(of: "K.M.I", with: isEnglish ? "K M I" : "קיי אם איי")
            .replacingOccurrences(of: "KMI", with: isEnglish ? "K M I" : "קיי אם איי")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !clean.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: clean)
        utterance.voice = AVSpeechSynthesisVoice(language: isEnglish ? "en-US" : "he-IL")
        utterance.rate = isEnglish ? 0.46 : 0.43
        speechSynth.speak(utterance)
    }
}

private struct MaterialsScreenSoftBackground: View {
    let belt: Belt

    var body: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.98),
                BeltPaletteByMaterials.color(for: belt).opacity(0.10),
                Color.white.opacity(0.94)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private struct MaterialsBeltLightBackground: View {
    let belt: Belt

    var body: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.92),
                BeltPaletteByMaterials.color(for: belt).opacity(0.08),
                Color.white.opacity(0.90)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private func materialsBeltImageName(for belt: Belt) -> String {
    switch belt {
    case .white:
        return "belt_white"
    case .yellow:
        return "belt_yellow"
    case .orange:
        return "belt_orange"
    case .green:
        return "belt_green"
    case .blue:
        return "belt_blue"
    case .brown:
        return "belt_brown"
    case .black:
        return "belt_black"
    default:
        return "belt_orange"
    }
}

// MARK: - Header

private struct MaterialsHeaderCard: View {
    let belt: Belt
    let title: String
    let count: Int
    let isEnglish: Bool
    let onBack: () -> Void

    private var titleAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var titleFrameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var materialTitle: String {
        isEnglish ? "Material: \(title)" : "חומר: \(title)"
    }

    var body: some View {
        HStack(spacing: 10) {
            if isEnglish {
                beltBadge

                Text(materialTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 0.20, green: 0.25, blue: 0.33))
                    .multilineTextAlignment(titleAlignment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: .infinity, alignment: titleFrameAlignment)
            } else {
                Text(materialTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 0.20, green: 0.25, blue: 0.33))
                    .multilineTextAlignment(titleAlignment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: .infinity, alignment: titleFrameAlignment)

                beltBadge
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.clear)
    }

    private var beltBadge: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.70))
                .frame(width: 42, height: 42)
                .overlay(
                    Circle()
                        .stroke(BeltPaletteByMaterials.color(for: belt).opacity(0.18), lineWidth: 1)
                )

            Image(materialsBeltImageName(for: belt))
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
        }
    }
}

// MARK: - Row

private struct MaterialsExerciseRow: View {
    let title: String
    let beltColor: Color
    let isFavorite: Bool
    let isExcluded: Bool
    let mark: MaterialsView.RowMark?
    let hasNote: Bool
    let isEnglish: Bool

    let onToggleFavorite: () -> Void
    let onToggleExcluded: () -> Void
    let onShowInfo: () -> Void
    let onEditNote: () -> Void
    let onCycleMark: () -> Void

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    var body: some View {
        HStack(spacing: 8) {
            menuButton

            Text(title)
                .font(.system(size: 15.5, weight: .semibold))
                .foregroundStyle(isExcluded ? Color.gray : Color(red: 0.07, green: 0.09, blue: 0.15))
                .multilineTextAlignment(textAlignment)
                .lineLimit(4)
                .minimumScaleFactor(0.84)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .padding(.horizontal, 4)

            markButtons
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(minHeight: 58)
        .background(Color.clear)
        .contentShape(Rectangle())
    }

    private var menuButton: some View {
        Menu {
            Section {
                Text(isEnglish
                     ? "What does “Exclude” mean?\nRemoves this exercise from practice for the selected topic."
                     : "מה זה “החרג”?\nמנטרל את התרגיל מהתרגול של הנושא הנבחר.")
                .font(.caption)
            }

            Button(
                isEnglish ? "Info" : "מידע",
                action: onShowInfo
            )

            Button(
                isFavorite
                ? (isEnglish ? "Remove from favorites" : "הסר ממועדפים")
                : (isEnglish ? "Add to favorites" : "הוסף למועדפים"),
                action: onToggleFavorite
            )

            Button(
                isExcluded
                ? (isEnglish ? "Cancel exclusion" : "בטל החרגה")
                : (isEnglish ? "Exclude from practice" : "החרג (מנטרל מהתרגול)"),
                action: onToggleExcluded
            )

            Button(
                hasNote
                ? (isEnglish ? "Edit / delete note" : "ערוך / מחק הערה")
                : (isEnglish ? "Add exercise note" : "הוסף הערה לתרגיל"),
                action: onEditNote
            )
        } label: {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color(red: 0.38, green: 0.44, blue: 0.48))
                    .frame(width: 27, height: 27)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 2)

                Text("i")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.white)

                if isFavorite || isExcluded || hasNote {
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.92), lineWidth: 1)
                        )
                        .offset(x: 2, y: -2)
                }
            }
            .frame(width: 29, height: 29)
        }
        .buttonStyle(.plain)
        .frame(width: 31)
    }

    private var statusDotColor: Color {
        if isExcluded {
            return Color.red.opacity(0.88)
        }

        if hasNote {
            return Color.blue.opacity(0.88)
        }

        if isFavorite {
            return Color.orange.opacity(0.90)
        }

        return Color.clear
    }

    private var markButtons: some View {
        MaterialsSingleMarkCircleButton(
            mark: mark,
            onTap: onCycleMark
        )
        .frame(width: 44)
    }
}

private struct MaterialsSingleMarkCircleButton: View {
    let mark: MaterialsView.RowMark?
    let onTap: () -> Void

    @State private var pressed: Bool = false

    private var fillColor: Color {
        switch mark {
        case .mastered:
            return Color.green.opacity(0.76)
        case .unknown:
            return Color.red.opacity(0.76)
        case nil:
            return Color.white.opacity(0.96)
        }
    }

    private var strokeColor: Color {
        switch mark {
        case .mastered, .unknown:
            return Color.white.opacity(0.36)
        case nil:
            return Color.black.opacity(0.18)
        }
    }

    private var iconName: String? {
        switch mark {
        case .mastered:
            return "checkmark"
        case .unknown:
            return "xmark"
        case nil:
            return nil
        }
    }

    private var accessibilityTitle: String {
        switch mark {
        case .mastered:
            return "Known"
        case .unknown:
            return "Unknown"
        case nil:
            return "Not marked"
        }
    }

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.10)) {
                pressed = true
            }

            onTap()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeOut(duration: 0.12)) {
                    pressed = false
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(fillColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(strokeColor, lineWidth: 1)
                    )
                    .shadow(
                        color: Color.black.opacity(mark == nil ? 0.14 : 0.12),
                        radius: 4,
                        x: 0,
                        y: 2
                    )

                if let iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(Color.white)
                }
            }
            .scaleEffect(pressed ? 0.92 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityTitle)
    }
}

// MARK: - Premium Note Sheet

private struct MaterialsPremiumNoteSheet: View {
    let title: String
    @Binding var noteText: String
    let isEnglish: Bool
    let onCancel: () -> Void
    let onSave: () -> Void
    let onDelete: () -> Void

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var hasNote: Bool {
        !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white,
                    Color(red: 0.97, green: 0.95, blue: 1.00),
                    Color.white
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                VStack(alignment: isEnglish ? .leading : .trailing, spacing: 6) {
                    Text(isEnglish ? "Exercise Note" : "הערה על התרגיל")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(Color(red: 0.12, green: 0.16, blue: 0.24))
                        .multilineTextAlignment(textAlignment)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)

                    Text(isEnglish ? "Write a personal note that will stay attached to this exercise." : "כתוב הערה אישית שתישמר לתרגיל הזה")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 0.39, green: 0.45, blue: 0.55))
                        .multilineTextAlignment(textAlignment)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)

                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(red: 0.23, green: 0.20, blue: 0.38))
                        .multilineTextAlignment(textAlignment)
                        .lineLimit(2)
                        .padding(.top, 4)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                }

                TextEditor(text: $noteText)
                    .font(.system(size: 17, weight: .semibold))
                    .multilineTextAlignment(textAlignment)
                    .frame(minHeight: 150, maxHeight: 220)
                    .padding(12)
                    .scrollContentBackground(.hidden)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(0.96))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color(red: 0.49, green: 0.34, blue: 0.76).opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 7, x: 0, y: 4)
                    .overlay(alignment: isEnglish ? .topLeading : .topTrailing) {
                        if noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(isEnglish ? "Write a free note" : "הקלד הערה חופשית")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(red: 0.58, green: 0.64, blue: 0.72))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 20)
                                .allowsHitTesting(false)
                        }
                    }

                HStack(spacing: 12) {
                    Button {
                        onCancel()
                    } label: {
                        Text(isEnglish ? "Cancel" : "בטל")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(Color(red: 0.43, green: 0.36, blue: 0.65))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.78))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color(red: 0.49, green: 0.34, blue: 0.76).opacity(0.24), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        onSave()
                    } label: {
                        Text(isEnglish ? "Save" : "שמור")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(red: 0.36, green: 0.25, blue: 0.65))
                            )
                            .shadow(color: Color(red: 0.36, green: 0.25, blue: 0.65).opacity(0.24), radius: 8, x: 0, y: 5)
                    }
                    .buttonStyle(.plain)
                }

                if hasNote {
                    Button {
                        onDelete()
                    } label: {
                        Text(isEnglish ? "Delete note" : "מחק הערה")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color(red: 0.70, green: 0.15, blue: 0.12))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 16)
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
    }
}

// MARK: - Bottom bar

private struct MaterialsBottomBar: View {
    let belt: Belt
    let isEnglish: Bool
    let isPracticeLocked: Bool
    let onPractice: () -> Void
    let onSummary: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if isEnglish {
                    MaterialsActionButton(
                        title: isPracticeLocked ? "🔒 Practice" : "Practice",
                        fill: isPracticeLocked
                        ? Color(red: 0.60, green: 0.48, blue: 0.13)
                        : BeltPaletteByMaterials.color(for: belt).opacity(0.92),
                        systemImage: isPracticeLocked ? "lock.fill" : nil,
                        onTap: onPractice
                    )

                    MaterialsActionButton(
                        title: "Reset",
                        fill: Color(red: 0.70, green: 0.15, blue: 0.12),
                        systemImage: nil,
                        onTap: onReset
                    )
                } else {
                    MaterialsActionButton(
                        title: "איפוס",
                        fill: Color(red: 0.70, green: 0.15, blue: 0.12),
                        systemImage: nil,
                        onTap: onReset
                    )

                    MaterialsActionButton(
                        title: isPracticeLocked ? "🔒 תרגול" : "תרגול",
                        fill: isPracticeLocked
                        ? Color(red: 0.60, green: 0.48, blue: 0.13)
                        : BeltPaletteByMaterials.color(for: belt).opacity(0.92),
                        systemImage: isPracticeLocked ? "lock.fill" : nil,
                        onTap: onPractice
                    )
                }
            }
            .environment(\.layoutDirection, .leftToRight)

            MaterialsActionButton(
                title: isEnglish ? "Summary Screen" : "מסך סיכום",
                fill: Color(red: 0.12, green: 0.16, blue: 0.24),
                systemImage: nil,
                onTap: onSummary
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.96),
                    BeltPaletteByMaterials.color(for: belt).opacity(0.10),
                    Color.white.opacity(0.94)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
        .overlay(
            Rectangle()
                .fill(BeltPaletteByMaterials.color(for: belt).opacity(0.14))
                .frame(height: 1),
            alignment: .top
        )
    }
}

private struct MaterialsActionButton: View {
    let title: String
    let fill: Color
    let systemImage: String?
    let onTap: () -> Void

    @State private var pressed: Bool = false

    private var contentColor: Color {
        fill.luminance < 0.50 ? Color.white : Color.black
    }

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.10)) {
                pressed = true
            }

            onTap()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(.easeOut(duration: 0.12)) {
                    pressed = false
                }
            }
        } label: {
            HStack(spacing: 7) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .black))
                }

                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(contentColor)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.24), lineWidth: 1)
            )
            .shadow(color: fill.opacity(0.22), radius: 6, x: 0, y: 4)
            .scaleEffect(pressed ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Info sheet

private struct MaterialsInfoSheet: View {
    let title: String
    let text: String
    let isFavorite: Bool
    let isEnglish: Bool
    let accentColor: Color
    let onToggleFavorite: () -> Void
    let onSpeak: () -> Void
    let onEditNote: () -> Void

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.99),
                    accentColor.opacity(0.06),
                    Color.white.opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                VStack(alignment: isEnglish ? .leading : .trailing, spacing: 8) {
                    Text(title)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(Color(red: 0.11, green: 0.14, blue: 0.20))
                        .multilineTextAlignment(textAlignment)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)

                    Text(isEnglish ? "Detailed explanation" : "הסבר מפורט")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(red: 0.39, green: 0.45, blue: 0.55))
                        .multilineTextAlignment(textAlignment)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                }

                ScrollView {
                    Text(text)
                        .font(.system(size: 16.5, weight: .semibold))
                        .foregroundStyle(Color(red: 0.10, green: 0.12, blue: 0.17))
                        .lineSpacing(5)
                        .multilineTextAlignment(textAlignment)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.white.opacity(0.96))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(accentColor.opacity(0.16), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 4)
                }

                HStack(spacing: 10) {
                    MaterialsInfoActionButton(
                        title: isEnglish ? "Speak" : "הקראה",
                        systemName: "speaker.wave.2.fill",
                        fill: Color(red: 0.12, green: 0.16, blue: 0.24),
                        onTap: onSpeak
                    )

                    MaterialsInfoActionButton(
                        title: isFavorite
                        ? (isEnglish ? "Favorite" : "מועדף")
                        : (isEnglish ? "Favorite" : "מועדף"),
                        systemName: isFavorite ? "star.fill" : "star",
                        fill: Color.orange.opacity(0.92),
                        onTap: onToggleFavorite
                    )
                }

                MaterialsInfoActionButton(
                    title: isEnglish ? "Edit / add note" : "ערוך / הוסף הערה",
                    systemName: "note.text",
                    fill: accentColor.opacity(0.92),
                    onTap: onEditNote
                )
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 16)
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
    }
}

private struct MaterialsInfoActionButton: View {
    let title: String
    let systemName: String
    let fill: Color
    let onTap: () -> Void

    @State private var pressed: Bool = false

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.10)) {
                pressed = true
            }

            onTap()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(.easeOut(duration: 0.12)) {
                    pressed = false
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 14, weight: .black))

                Text(title)
                    .font(.system(size: 15, weight: .black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: fill.opacity(0.20), radius: 7, x: 0, y: 4)
            .scaleEffect(pressed ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
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

private extension Color {
    var luminance: Double {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return 0.2126 * Double(red) + 0.7152 * Double(green) + 0.0722 * Double(blue)
    }
}
