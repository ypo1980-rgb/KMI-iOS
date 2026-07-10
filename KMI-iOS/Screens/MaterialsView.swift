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

    @State private var toastMessage: String? = nil
    @State private var showResetConfirmation: Bool = false

    @State private var generatedPdfURL: URL? = nil
    @State private var showPdfShareSheet: Bool = false

    @State private var speechSynth = AVSpeechSynthesizer()
    @State private var isSpeakingExplanation: Bool = false

    @State private var openedNestedSubTopic: String? = nil

    private var topicUi: String {
        let clean = topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "כללי" : clean
    }

    private var subTopicUi: String? {
        guard let subTopicTitle else { return nil }
        let clean = subTopicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    private func normalizedMaterialTitle(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{200F}", with: "")
            .replacingOccurrences(of: "\u{200E}", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "־", with: "-")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isDefenseLevelOneTitle(_ value: String) -> Bool {
        let clean = normalizedMaterialTitle(value)

        return clean == "הגנות נגד מכות" ||
        clean == "הגנות נגד בעיטות" ||
        clean == "הגנות - סכין"
    }

    private var materialRootTopic: String {
        if subTopicUi == nil && isDefenseLevelOneTitle(topicUi) {
            return "הגנות"
        }

        return topicUi
    }

    private var materialParentSubTopic: String? {
        if let subTopicUi {
            return subTopicUi
        }

        if isDefenseLevelOneTitle(topicUi) {
            return topicUi
        }

        return nil
    }

    private var nestedSubTopicTitles: [String] {
        guard let materialParentSubTopic else {
            return []
        }

        return ContentRepo.shared.getNestedSubTopicTitles(
            belt: belt,
            topicTitle: materialRootTopic.trimmingCharacters(in: .whitespacesAndNewlines),
            subTopicTitle: materialParentSubTopic.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        .map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter {
            !$0.isEmpty
        }
        .removingDuplicatesKeepingOrder()
    }

    private var isShowingNestedSubTopicPicker: Bool {
        false
    }

    private var effectiveSubTopicUi: String? {
        openedNestedSubTopic ?? materialParentSubTopic
    }

    private var topicKey: String {
        guard let materialParentSubTopic else {
            return materialRootTopic
        }

        if let openedNestedSubTopic,
           !openedNestedSubTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(materialRootTopic)__\(materialParentSubTopic)__\(openedNestedSubTopic)"
        }

        return "\(materialRootTopic)__\(materialParentSubTopic)"
    }

    private var scopeKey: String {
        "\(belt.id)||\(materialRootTopic)||\(materialParentSubTopic ?? "")||\(openedNestedSubTopic ?? "")"
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
        return "\(belt.id)||\(materialRootTopic)||\(effectiveSubTopicUi ?? "")||\(item)"
    }

    private func statusIdForStorage(index: Int, rawItem: String) -> String {
        let cleanItem = normalizeStatusPart(rawItem)
        return "status_\(belt.id)_\(topicKey)_\(index)_\(cleanItem)"
    }

    private var materialItems: [String] {
        let cleanRootTopic = materialRootTopic
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let materialParentSubTopic {
            let cleanParentSubTopic = materialParentSubTopic
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let openedNestedSubTopic,
               !openedNestedSubTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let nestedItems = ContentRepo.shared.getNestedItemsFor(
                    belt: belt,
                    topicTitle: cleanRootTopic,
                    subTopicTitle: cleanParentSubTopic,
                    nestedSubTopicTitle: openedNestedSubTopic
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                )
                .removingDuplicatesKeepingOrder()

                if !nestedItems.isEmpty {
                    return nestedItems
                }
            }

            let nestedTitles = ContentRepo.shared.getNestedSubTopicTitles(
                belt: belt,
                topicTitle: cleanRootTopic,
                subTopicTitle: cleanParentSubTopic
            )
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter {
                !$0.isEmpty
            }
            .removingDuplicatesKeepingOrder()

            if !nestedTitles.isEmpty {
                let nestedItems = nestedTitles.flatMap { nestedTitle in
                    ContentRepo.shared.getNestedItemsFor(
                        belt: belt,
                        topicTitle: cleanRootTopic,
                        subTopicTitle: cleanParentSubTopic,
                        nestedSubTopicTitle: nestedTitle
                    )
                }
                .removingDuplicatesKeepingOrder()

                if !nestedItems.isEmpty {
                    return nestedItems
                }
            }

            let parentItems = ContentRepo.shared.getAllItemsFor(
                belt: belt,
                topicTitle: cleanRootTopic,
                subTopicTitle: cleanParentSubTopic
            )
            .removingDuplicatesKeepingOrder()

            if !parentItems.isEmpty {
                return parentItems
            }

            let originalTopicItems = ContentRepo.shared.getAllItemsFor(
                belt: belt,
                topicTitle: topicUi,
                subTopicTitle: subTopicUi
            )
            .removingDuplicatesKeepingOrder()

            if !originalTopicItems.isEmpty {
                return originalTopicItems
            }

            let parentAsTopicItems = ContentRepo.shared.getAllItemsFor(
                belt: belt,
                topicTitle: cleanParentSubTopic,
                subTopicTitle: nil
            )
            .removingDuplicatesKeepingOrder()

            if !parentAsTopicItems.isEmpty {
                return parentAsTopicItems
            }
        }

        let rootItems = ContentRepo.shared.getAllItemsFor(
            belt: belt,
            topicTitle: cleanRootTopic,
            subTopicTitle: nil
        )
        .removingDuplicatesKeepingOrder()

        if !rootItems.isEmpty {
            return rootItems
        }

        return ContentRepo.shared.getAllItemsFor(
            belt: belt,
            topicTitle: topicUi,
            subTopicTitle: subTopicUi
        )
        .removingDuplicatesKeepingOrder()
    }

    private var rows: [ExerciseRow] {
        var seenStatusIds = Set<String>()

        return materialItems
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
        let topicDisplay = KmiEnglishTitleResolver.title(
            for: materialRootTopic,
            isEnglish: isEnglish
        )

        if let openedNestedSubTopic,
           !openedNestedSubTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let nestedDisplay = KmiEnglishTitleResolver.title(
                for: openedNestedSubTopic,
                isEnglish: isEnglish
            )

            if let materialParentSubTopic {
                let parentDisplay = KmiEnglishTitleResolver.title(
                    for: materialParentSubTopic,
                    isEnglish: isEnglish
                )

                return "\(parentDisplay) – \(nestedDisplay)"
            }

            return "\(topicDisplay) – \(nestedDisplay)"
        }

        if let materialParentSubTopic {
            let parentDisplay = KmiEnglishTitleResolver.title(
                for: materialParentSubTopic,
                isEnglish: isEnglish
            )

            if materialRootTopic == topicUi {
                return parentDisplay
            }

            return "\(topicDisplay) – \(parentDisplay)"
        }

        return topicDisplay
    }

    private var masteredCount: Int {
        rows.filter { currentMark(for: $0.statusId) == .mastered }.count
    }

    private var unknownCount: Int {
        rows.filter { currentMark(for: $0.statusId) == .unknown }.count
    }

    private var favoritesCount: Int {
        rows.filter { favorites.contains($0.canonicalId) }.count
    }

    private var excludedCount: Int {
        rows.filter { excluded.contains($0.canonicalId) }.count
    }

    private var notesCount: Int {
        rows.filter {
            !(notes[$0.canonicalId]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        }.count
    }
    
    var body: some View {
        ZStack {
            MaterialsScreenSoftBackground(belt: belt)

            VStack(spacing: 0) {
                MaterialsStatsHeader(
                    belt: belt,
                    count: rows.count,
                    masteredCount: masteredCount,
                    unknownCount: unknownCount,
                    favoritesCount: favoritesCount,
                    excludedCount: excludedCount,
                    notesCount: notesCount,
                    isEnglish: isEnglish
                )

                ScrollView {
                    VStack(spacing: 0) {
                        if rows.isEmpty {
                            MaterialsEmptyStateView(
                                belt: belt,
                                title: headerTitle,
                                isEnglish: isEnglish
                            )
                            .padding(.horizontal, 14)
                            .padding(.top, 18)
                            .padding(.bottom, 18)
                        } else {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                                MaterialsExerciseRow(
                                    rowNumber: idx + 1,
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
                    }
                    .padding(.top, 4)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
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
                            onPractice(belt, materialRootTopic)
                        }
                    },
                    onSummary: {
                        onSummary(belt, materialRootTopic, effectiveSubTopicUi)
                    },
                    onReset: {
                        showResetConfirmation = true
                    }
                )
            }

            if let toastMessage {
                MaterialsToastView(message: toastMessage)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 136)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .navigationBarBackButtonHidden(true)
        .environment(\.layoutDirection, screenLayoutDirection)
        .onAppear {
            loadState()
        }
        .onDisappear {
            speechSynth.stopSpeaking(at: .immediate)
            isSpeakingExplanation = false
        }
        .onChange(of: scopeKey) { _, _ in
            loadState()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("KMI_GLOBAL_SHARE_REQUEST")
            )
        ) { notification in
            guard let shareRequest = notification.object as? NSMutableDictionary else {
                return
            }

            shareRequest["handled"] = true
            createAndShareMaterialsPdf()
        }
        .confirmationDialog(
            tr("לאפס את כל הסימונים בנושא הזה?", "Reset all marks for this topic?"),
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                tr("אפס סימונים, מועדפים, החרגות והערות", "Reset marks, favorites, exclusions and notes"),
                role: .destructive
            ) {
                resetCurrentScope()
            }

            Button(
                tr("ביטול", "Cancel"),
                role: .cancel
            ) { }
        } message: {
            Text(
                tr(
                    "הפעולה תמחק את הנתונים המקומיים ששמרת עבור הנושא הנוכחי בלבד.",
                    "This will delete the local data saved for the current topic only."
                )
            )
        }
        .sheet(item: $selectedInfoRow) { row in
            MaterialsInfoSheet(
                title: row.displayName,
                text: explanationText(for: row),
                isFavorite: favorites.contains(row.canonicalId),
                isSpeaking: isSpeakingExplanation,
                isEnglish: isEnglish,
                accentColor: BeltPaletteByMaterials.color(for: belt),
                onClose: {
                    speechSynth.stopSpeaking(at: .immediate)
                    isSpeakingExplanation = false
                    selectedInfoRow = nil
                },
                onToggleFavorite: {
                    toggleFavorite(row.canonicalId)
                },
                onSpeak: {
                    toggleSpeak(explanationText(for: row))
                },
                onEditNote: {
                    speechSynth.stopSpeaking(at: .immediate)
                    isSpeakingExplanation = false

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
        .sheet(isPresented: $showPdfShareSheet) {
            if let generatedPdfURL {
                MaterialsPdfShareSheet(items: [generatedPdfURL])
            }
        }
    }

    private struct MaterialsEmptyStateView: View {
        let belt: Belt
        let title: String
        let isEnglish: Bool

        private var textAlignment: TextAlignment {
            isEnglish ? .leading : .trailing
        }

        private var frameAlignment: Alignment {
            isEnglish ? .leading : .trailing
        }

        var body: some View {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(BeltPaletteByMaterials.color(for: belt).opacity(0.14))
                        .frame(width: 72, height: 72)

                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(BeltPaletteByMaterials.color(for: belt).opacity(0.92))
                }

                VStack(spacing: 6) {
                    Text(isEnglish ? "No material found" : "לא נמצא חומר להצגה")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(Color(red: 0.12, green: 0.16, blue: 0.24))
                        .multilineTextAlignment(textAlignment)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)

                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(red: 0.30, green: 0.36, blue: 0.46))
                        .multilineTextAlignment(textAlignment)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)

                    Text(isEnglish
                         ? "This topic is connected to the real content repository, but no exercises were returned for this exact belt and topic."
                         : "המסך מחובר למאגר התוכן האמיתי, אבל לא חזרו תרגילים עבור החגורה והנושא המדויקים האלה.")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Color(red: 0.46, green: 0.52, blue: 0.62))
                        .lineSpacing(3)
                        .multilineTextAlignment(textAlignment)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white.opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(BeltPaletteByMaterials.color(for: belt).opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
            .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
        }
    }
    
    // MARK: - Helpers

    private func canonicalId(for rawItem: String) -> String {
        canonicalIdForStorage(rawItem: rawItem)
    }

    private func displayName(for rawItem: String) -> String {
        var text = rawItem.trimmingCharacters(in: .whitespacesAndNewlines)

        let prefixes = [
            materialRootTopic,
            materialParentSubTopic,
            effectiveSubTopicUi,
            topicUi,
            subTopicUi
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .removingDuplicatesKeepingOrder()

        for prefix in prefixes {
            if text.hasPrefix("\(prefix)::") {
                text = String(text.dropFirst("\(prefix)::".count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if text.hasPrefix(prefix) {
                text = String(text.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "-–—: "))
            }
        }

        let clean = text
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return KmiEnglishTitleResolver.title(for: clean, isEnglish: isEnglish)
    }

    private func explanationText(for row: ExerciseRow) -> String {
        let txt = KmiExerciseExplanationResolverIOS.shared.get(
            belt: belt,
            topic: materialRootTopic,
            item: row.rawItem,
            isEnglish: isEnglish
        )

        let clean = txt.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

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

    private func showToast(_ message: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withAnimation(.easeOut(duration: 0.18)) {
            toastMessage = message
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
            withAnimation(.easeIn(duration: 0.18)) {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }

    private func toggleFavorite(_ id: String) {
        if favorites.contains(id) {
            favorites.remove(id)
            UserDefaults.standard.set(false, forKey: favoriteKey(for: id))
            showToast(tr("הוסר מהמועדפים.", "Removed from favorites."))
        } else {
            favorites.insert(id)
            UserDefaults.standard.set(true, forKey: favoriteKey(for: id))
            showToast(tr("נוסף למועדפים.", "Added to favorites."))
        }
    }

    private func toggleExcluded(_ id: String) {
        if excluded.contains(id) {
            excluded.remove(id)
            UserDefaults.standard.set(false, forKey: excludedKey(for: id))
            showToast(tr("בוטלה ההחרגה – התרגיל יחזור לתרגול.", "Exclusion canceled. The exercise will return to practice."))
        } else {
            excluded.insert(id)
            UserDefaults.standard.set(true, forKey: excludedKey(for: id))
            showToast(tr("התרגיל הוחרג – לא יופיע בתרגול הנושא.", "Exercise excluded. It will not appear in this topic practice."))
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

            switch next {
            case .mastered:
                showToast(tr("סומן כיודע.", "Marked as known."))
            case .unknown:
                showToast(tr("סומן לחזרה.", "Marked for review."))
            }
        } else {
            UserDefaults.standard.removeObject(forKey: key)
            showToast(tr("הסימון הוסר.", "Mark removed."))
        }

        refreshToken = UUID()
    }

    private func saveNote(_ text: String, for id: String) {
        notes[id] = text
        let key = noteKey(for: id)
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if clean.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
            showToast(tr("ההערה נמחקה.", "Note deleted."))
        } else {
            UserDefaults.standard.set(clean, forKey: key)
            showToast(tr("ההערה נשמרה.", "Note saved."))
        }

        refreshToken = UUID()
    }

    private func pdfStatusText(for row: ExerciseRow) -> String {
        switch currentMark(for: row.statusId) {
        case .mastered:
            return tr("יודע", "Known")
        case .unknown:
            return tr("לא יודע", "Unknown")
        case nil:
            return tr("לא סומן", "Not marked")
        }
    }

    private func createAndShareMaterialsPdf() {
        let pdfItems = rows.enumerated().map { index, row in
            MaterialsPdfItemIOS(
                number: index + 1,
                title: row.displayName,
                status: pdfStatusText(for: row),
                isFavorite: favorites.contains(row.canonicalId),
                isExcluded: excluded.contains(row.canonicalId),
                hasNote: !(notes[row.canonicalId]?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty ?? true)
            )
        }

        do {
            generatedPdfURL = try MaterialsPdfGeneratorIOS.create(
                belt: belt,
                topicTitle: headerTitle,
                items: pdfItems,
                isEnglish: isEnglish
            )

            showPdfShareSheet = true
        } catch {
            generatedPdfURL = nil

            showToast(
                tr(
                    "לא ניתן היה ליצור את קובץ ה־PDF.",
                    "The PDF file could not be created."
                )
            )
        }
    }

    private func resetCurrentScope() {
        speechSynth.stopSpeaking(at: .immediate)

        selectedInfoRow = nil
        selectedNoteRow = nil
        noteDraft = ""

        for row in rows {
            UserDefaults.standard.removeObject(forKey: favoriteKey(for: row.canonicalId))
            UserDefaults.standard.removeObject(forKey: excludedKey(for: row.canonicalId))
            UserDefaults.standard.removeObject(forKey: markKey(for: row.statusId))
            UserDefaults.standard.removeObject(forKey: noteKey(for: row.canonicalId))
        }

        favorites.removeAll()
        excluded.removeAll()
        marks.removeAll()
        notes.removeAll()

        refreshToken = UUID()

        showToast(
            tr(
                "הנושא אופס בהצלחה.",
                "Topic reset successfully."
            )
        )
    }

    private func toggleSpeak(_ text: String) {
        if isSpeakingExplanation {
            speechSynth.stopSpeaking(at: .immediate)
            isSpeakingExplanation = false
            showToast(tr("ההקראה נעצרה.", "Speech stopped."))
            return
        }

        speechSynth.stopSpeaking(at: .immediate)

        let clean = text
            .replacingOccurrences(of: "•", with: ".")
            .replacingOccurrences(of: "/", with: ".")
            .replacingOccurrences(of: "K.M.I", with: isEnglish ? "K M I" : "קיי אם איי")
            .replacingOccurrences(of: "KMI", with: isEnglish ? "K M I" : "קיי אם איי")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !clean.isEmpty else {
            isSpeakingExplanation = false
            return
        }

        let utterance = AVSpeechUtterance(string: clean)
        utterance.voice = AVSpeechSynthesisVoice(language: isEnglish ? "en-US" : "he-IL")
        utterance.rate = isEnglish ? 0.46 : 0.43

        isSpeakingExplanation = true
        speechSynth.speak(utterance)

        let estimatedSeconds = min(max(Double(clean.count) / 10.5, 1.4), 22.0)

        DispatchQueue.main.asyncAfter(deadline: .now() + estimatedSeconds) {
            if !speechSynth.isSpeaking {
                isSpeakingExplanation = false
            }
        }
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

private struct MaterialsToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13.5, weight: .bold))
            .foregroundStyle(Color.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                Capsule()
                    .fill(Color(red: 0.12, green: 0.16, blue: 0.24).opacity(0.94))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 5)
    }
}

private struct MaterialsNestedSubTopicPicker: View {
    let titles: [String]
    let beltColor: Color
    let isEnglish: Bool
    let onSelect: (String) -> Void

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(isEnglish ? "Choose a sub-topic" : "בחר תת־נושא")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color(red: 0.12, green: 0.16, blue: 0.24))
                .multilineTextAlignment(textAlignment)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .padding(.horizontal, 4)

            ForEach(titles, id: \.self) { title in
                Button {
                    onSelect(title)
                } label: {
                    HStack(spacing: 10) {
                        if isEnglish {
                            Text(KmiEnglishTitleResolver.title(for: title, isEnglish: true))
                                .font(.system(size: 15.5, weight: .bold))
                                .foregroundStyle(Color(red: 0.08, green: 0.10, blue: 0.16))
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                                .minimumScaleFactor(0.84)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(beltColor.opacity(0.90))
                        } else {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(beltColor.opacity(0.90))

                            Text(KmiEnglishTitleResolver.title(for: title, isEnglish: false))
                                .font(.system(size: 15.5, weight: .bold))
                                .foregroundStyle(Color(red: 0.08, green: 0.10, blue: 0.16))
                                .multilineTextAlignment(.trailing)
                                .lineLimit(2)
                                .minimumScaleFactor(0.84)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 58)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.94))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(beltColor.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
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

private struct MaterialsStatsHeader: View {
    let belt: Belt
    let count: Int
    let masteredCount: Int
    let unknownCount: Int
    let favoritesCount: Int
    let excludedCount: Int
    let notesCount: Int
    let isEnglish: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(
                isEnglish
                ? "← Swipe sideways to see more stats →"
                : "→→ הזז לצד כדי לראות עוד נתונים →→"
            )
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color(red: 0.36, green: 0.39, blue: 0.45))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if isEnglish {
                        statChip(title: "Exercises", value: count, color: Color(red: 0.60, green: 0.64, blue: 0.70))
                        statChip(title: "Known", value: masteredCount, color: Color(red: 0.48, green: 0.80, blue: 0.53))
                        statChip(title: "Unknown", value: unknownCount, color: Color(red: 0.95, green: 0.66, blue: 0.48))
                        statChip(title: "Favorites", value: favoritesCount, color: Color(red: 0.91, green: 0.64, blue: 0.71))
                        statChip(title: "Excluded", value: excludedCount, color: Color(red: 0.58, green: 0.84, blue: 0.60))
                        statChip(title: "Notes", value: notesCount, color: Color(red: 0.52, green: 0.59, blue: 0.79))
                    } else {
                        statChip(title: "תרגילים", value: count, color: Color(red: 0.60, green: 0.64, blue: 0.70))
                        statChip(title: "יודע", value: masteredCount, color: Color(red: 0.48, green: 0.80, blue: 0.53))
                        statChip(title: "לא יודע", value: unknownCount, color: Color(red: 0.95, green: 0.66, blue: 0.48))
                        statChip(title: "מועדפים", value: favoritesCount, color: Color(red: 0.91, green: 0.64, blue: 0.71))
                        statChip(title: "מוחרגים", value: excludedCount, color: Color(red: 0.58, green: 0.84, blue: 0.60))
                        statChip(title: "הערות", value: notesCount, color: Color(red: 0.52, green: 0.59, blue: 0.79))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
            }
            .environment(\.layoutDirection, .leftToRight)

            Text(isEnglish ? "More cards are available off-screen" : "יש עוד כרטיסים בהמשך הגלילה")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color(red: 0.48, green: 0.51, blue: 0.57))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)
        }
        .background(MaterialsBeltLightBackground(belt: belt))
    }

    private func statChip(title: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color.white)
                .lineLimit(1)

            Text(title)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Color.white.opacity(0.94))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(minWidth: 64)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct MaterialsHeaderCard: View {

    let belt: Belt
    let title: String
    let count: Int
    let masteredCount: Int
    let unknownCount: Int
    let favoritesCount: Int
    let excludedCount: Int
    let notesCount: Int
    let isEnglish: Bool
    let onBack: () -> Void
    
    private var materialTitle: String {
        isEnglish ? "Material: \(title)" : "חומר: \(title)"
    }

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var rowDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Text(materialTitle)
                    .font(.system(size: 16.5, weight: .heavy))
                    .foregroundStyle(Color(red: 0.16, green: 0.20, blue: 0.28))
                    .multilineTextAlignment(textAlignment)
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)

                beltPill
            }

            VStack(spacing: 4) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        if isEnglish {
                            headerStat(title: "Exercises", value: count, color: Color(red: 0.60, green: 0.64, blue: 0.70))
                            headerStat(title: "Known", value: masteredCount, color: Color.green.opacity(0.80))
                            headerStat(title: "Unknown", value: unknownCount, color: Color.orange.opacity(0.78))
                            headerStat(title: "Favorites", value: favoritesCount, color: Color(red: 0.90, green: 0.64, blue: 0.70))
                            headerStat(title: "Excluded", value: excludedCount, color: Color(red: 0.58, green: 0.84, blue: 0.60))
                            headerStat(title: "Notes", value: notesCount, color: Color(red: 0.52, green: 0.59, blue: 0.79))
                        } else {
                            headerStat(title: "תרגילים", value: count, color: Color(red: 0.60, green: 0.64, blue: 0.70))
                            headerStat(title: "יודע", value: masteredCount, color: Color.green.opacity(0.80))
                            headerStat(title: "לא יודע", value: unknownCount, color: Color.orange.opacity(0.78))
                            headerStat(title: "מועדפים", value: favoritesCount, color: Color(red: 0.90, green: 0.64, blue: 0.70))
                            headerStat(title: "מוחרגים", value: excludedCount, color: Color(red: 0.58, green: 0.84, blue: 0.60))
                            headerStat(title: "הערות", value: notesCount, color: Color(red: 0.52, green: 0.59, blue: 0.79))
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .environment(\.layoutDirection, .leftToRight)

                Text(isEnglish ? "More cards are available off-screen" : "יש עוד כרטיסים בהמשך הגלילה")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color(red: 0.48, green: 0.51, blue: 0.57))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .environment(\.layoutDirection, rowDirection)
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 9)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.99),
                    BeltPaletteByMaterials.color(for: belt).opacity(0.10),
                    Color.white.opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            Rectangle()
                .fill(BeltPaletteByMaterials.color(for: belt).opacity(0.12))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func headerStat(title: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color.white)
                .lineLimit(1)

            Text(title)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Color.white.opacity(0.94))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(minWidth: 64)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.12), radius: 3, x: 0, y: 2)
    }
    
    private var beltPill: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.76))
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(BeltPaletteByMaterials.color(for: belt).opacity(0.22), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 3)

            Image(materialsBeltImageName(for: belt))
                .resizable()
                .scaledToFit()
                .frame(width: 33, height: 33)
        }
    }
}

// MARK: - Row

private struct MaterialsExerciseRow: View {
    let rowNumber: Int
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

    private var rowOpacity: Double {
        isExcluded ? 0.58 : 1.0
    }

    private var rowBorderColor: Color {
        if isExcluded {
            return Color.gray.opacity(0.24)
        }

        if mark == .mastered {
            return Color.green.opacity(0.22)
        }

        if mark == .unknown {
            return Color.red.opacity(0.20)
        }

        if isFavorite || hasNote {
            return beltColor.opacity(0.24)
        }

        return beltColor.opacity(0.14)
    }
    
    var body: some View {
        HStack(spacing: 9) {
            if isEnglish {
                menuButton
                numberBadge

                titleBlock

                markButtons
            } else {
                markButtons

                titleBlock

                numberBadge
                menuButton
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: 66)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(isExcluded ? 0.68 : 0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(rowBorderColor, lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(isExcluded ? 0.03 : 0.06),
            radius: 7,
            x: 0,
            y: 4
        )
        .padding(.vertical, 4)
        .opacity(rowOpacity)
        .contentShape(Rectangle())
    }

    private var titleBlock: some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 4) {
            Text(title)
                .font(.system(size: 15.2, weight: .semibold))
                .foregroundStyle(isExcluded ? Color.gray : Color(red: 0.07, green: 0.09, blue: 0.15))
                .multilineTextAlignment(textAlignment)
                .lineLimit(3)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: frameAlignment)

            if isFavorite || isExcluded || hasNote {
                HStack(spacing: 6) {
                    if isFavorite {
                        statusMiniLabel(
                            text: isEnglish ? "Favorite" : "מועדף",
                            systemName: "star.fill",
                            color: Color.orange.opacity(0.90)
                        )
                    }

                    if hasNote {
                        statusMiniLabel(
                            text: isEnglish ? "Note" : "הערה",
                            systemName: "note.text",
                            color: Color.blue.opacity(0.84)
                        )
                    }

                    if isExcluded {
                        statusMiniLabel(
                            text: isEnglish ? "Excluded" : "מוחרג",
                            systemName: "minus.circle.fill",
                            color: Color.gray.opacity(0.82)
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
            }
        }
    }

    private func statusMiniLabel(text: String, systemName: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: systemName)
                .font(.system(size: 8.5, weight: .black))

            Text(text)
                .font(.system(size: 9.5, weight: .heavy))
                .lineLimit(1)
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color)
        )
    }

    private var numberBadge: some View {
        Text("\(rowNumber)")
            .font(.system(size: 11.5, weight: .black))
            .foregroundStyle(Color(red: 0.18, green: 0.22, blue: 0.30))
            .frame(width: 27, height: 27)
            .background(
                Circle()
                    .fill(Color.white.opacity(0.94))
            )
            .overlay(
                Circle()
                    .stroke(beltColor.opacity(0.24), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
    
    private var menuButton: some View {
        Menu {
            Button {
                onShowInfo()
            } label: {
                Label(
                    isEnglish ? "Detailed explanation" : "הסבר מפורט",
                    systemImage: "info.circle.fill"
                )
            }

            Button {
                onToggleFavorite()
            } label: {
                Label(
                    isFavorite
                    ? (isEnglish ? "Remove from favorites" : "הסר ממועדפים")
                    : (isEnglish ? "Add to favorites" : "הוסף למועדפים"),
                    systemImage: isFavorite ? "star.slash" : "star.fill"
                )
            }

            Button {
                onEditNote()
            } label: {
                Label(
                    hasNote
                    ? (isEnglish ? "Edit / delete note" : "ערוך / מחק הערה")
                    : (isEnglish ? "Add exercise note" : "הוסף הערה לתרגיל"),
                    systemImage: "note.text"
                )
            }

            Divider()

            Button(role: isExcluded ? nil : .destructive) {
                onToggleExcluded()
            } label: {
                Label(
                    isExcluded
                    ? (isEnglish ? "Cancel exclusion" : "בטל החרגה")
                    : (isEnglish ? "Exclude from practice" : "החרג מתרגול"),
                    systemImage: isExcluded ? "arrow.uturn.backward.circle" : "minus.circle.fill"
                )
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(red: 0.38, green: 0.44, blue: 0.48))
                    .frame(width: 29, height: 29)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.24), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 2)
                
                Text("i")
                    .font(.system(size: 14.5, weight: .black))
                    .foregroundStyle(Color.white)
                    .offset(y: -0.5)
            }
            .frame(width: 31, height: 31)
            .overlay(alignment: .topTrailing) {
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
        }
        .buttonStyle(.plain)
        .frame(width: 33)
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
        .frame(width: 38)
    }
}

private struct MaterialsSingleMarkCircleButton: View {
    let mark: MaterialsView.RowMark?
    let onTap: () -> Void

    @State private var pressed: Bool = false

    private var fillColor: Color {
        switch mark {
        case .mastered:
            return Color.green.opacity(0.82)
        case .unknown:
            return Color.red.opacity(0.80)
        case nil:
            return Color.white.opacity(0.98)
        }
    }

    private var strokeColor: Color {
        switch mark {
        case .mastered:
            return Color.green.opacity(0.28)
        case .unknown:
            return Color.red.opacity(0.26)
        case nil:
            return Color.black.opacity(0.17)
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
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(strokeColor, lineWidth: 1.2)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(mark == nil ? 0.35 : 0.48), lineWidth: 0.8)
                            .padding(3)
                    )
                    .shadow(
                        color: Color.black.opacity(mark == nil ? 0.12 : 0.10),
                        radius: 5,
                        x: 0,
                        y: 3
                    )

                if let iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.white)
                } else {
                    Circle()
                        .fill(Color.black.opacity(0.16))
                        .frame(width: 5, height: 5)
                }
            }
            .scaleEffect(pressed ? 0.90 : 1.0)
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
                        title: isPracticeLocked ? "Train 🔒" : "Practice",
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
                        title: isPracticeLocked ? "תרגול 🔒" : "תרגול",
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
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(
            ZStack {
                Color.white.opacity(0.94)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.98),
                        BeltPaletteByMaterials.color(for: belt).opacity(0.12),
                        Color.white.opacity(0.96)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea(edges: .bottom)
        )
        .overlay(
            Rectangle()
                .fill(BeltPaletteByMaterials.color(for: belt).opacity(0.16))
                .frame(height: 1),
            alignment: .top
        )
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: -3)
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
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
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
    let isSpeaking: Bool
    let isEnglish: Bool
    let accentColor: Color
    let onClose: () -> Void
    let onToggleFavorite: () -> Void
    let onSpeak: () -> Void
    let onEditNote: () -> Void

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var closeIconName: String {
        "xmark"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.99),
                    accentColor.opacity(0.07),
                    Color.white.opacity(0.97)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    if isEnglish {
                        titleBlock

                        closeButton
                    } else {
                        closeButton

                        titleBlock
                    }
                }
                .environment(\.layoutDirection, .leftToRight)

                ScrollView {
                    Text(text)
                        .font(.system(size: 16.2, weight: .semibold))
                        .foregroundStyle(Color(red: 0.10, green: 0.12, blue: 0.17))
                        .lineSpacing(5)
                        .multilineTextAlignment(textAlignment)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.white.opacity(0.97))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(accentColor.opacity(0.17), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 4)
                }

                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        MaterialsInfoActionButton(
                            title: isSpeaking
                            ? (isEnglish ? "Stop" : "עצור")
                            : (isEnglish ? "Speak" : "הקראה"),
                            systemName: isSpeaking ? "stop.fill" : "speaker.wave.2.fill",
                            fill: isSpeaking
                            ? Color(red: 0.70, green: 0.15, blue: 0.12)
                            : Color(red: 0.12, green: 0.16, blue: 0.24),
                            onTap: onSpeak
                        )

                        MaterialsInfoActionButton(
                            title: isFavorite
                            ? (isEnglish ? "Favorited" : "מועדף")
                            : (isEnglish ? "Favorite" : "מועדף"),
                            systemName: isFavorite ? "star.fill" : "star",
                            fill: Color.orange.opacity(0.92),
                            onTap: onToggleFavorite
                        )
                    }

                    MaterialsInfoActionButton(
                        title: isEnglish ? "Edit / add note" : "ערוך / הוסף הערה",
                        systemName: "note.text",
                        fill: accentColor.opacity(0.94),
                        onTap: onEditNote
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
    }

    private var titleBlock: some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 7) {
            Text(title)
                .font(.system(size: 21.5, weight: .black))
                .foregroundStyle(Color(red: 0.11, green: 0.14, blue: 0.20))
                .multilineTextAlignment(textAlignment)
                .lineLimit(3)
                .minimumScaleFactor(0.76)
                .frame(maxWidth: .infinity, alignment: frameAlignment)

            HStack(spacing: 6) {
                if isEnglish {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 10.5, weight: .black))

                    Text("Detailed explanation")
                        .font(.system(size: 12.5, weight: .bold))
                } else {
                    Text("הסבר מפורט")
                        .font(.system(size: 12.5, weight: .bold))

                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 10.5, weight: .black))
                }
            }
            .foregroundStyle(Color(red: 0.39, green: 0.45, blue: 0.55))
            .frame(maxWidth: .infinity, alignment: frameAlignment)
        }
    }

    private var closeButton: some View {
        Button {
            onClose()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.90))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Circle()
                            .stroke(accentColor.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.07), radius: 5, x: 0, y: 3)

                Image(systemName: closeIconName)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color(red: 0.20, green: 0.24, blue: 0.32))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isEnglish ? "Close" : "סגור")
    }
}

private struct MaterialsInfoActionButton: View {
    let title: String
    let systemName: String
    let fill: Color
    let onTap: () -> Void

    @State private var pressed: Bool = false

    private var contentColor: Color {
        fill.luminance < 0.56 ? Color.white : Color.black
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
            HStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 14, weight: .black))

                Text(title)
                    .font(.system(size: 15, weight: .black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(contentColor)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .stroke(Color.white.opacity(0.24), lineWidth: 1)
            )
            .shadow(color: fill.opacity(0.22), radius: 7, x: 0, y: 4)
            .scaleEffect(pressed ? 0.95 : 1.0)
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

private struct MaterialsPdfItemIOS {
    let number: Int
    let title: String
    let status: String
    let isFavorite: Bool
    let isExcluded: Bool
    let hasNote: Bool
}

private enum MaterialsPdfGeneratorIOS {

    static func create(
        belt: Belt,
        topicTitle: String,
        items: [MaterialsPdfItemIOS],
        isEnglish: Bool
    ) throws -> URL {
        let pageWidth: CGFloat = 595
        let pageHeight: CGFloat = 842
        let pageBounds = CGRect(
            x: 0,
            y: 0,
            width: pageWidth,
            height: pageHeight
        )

        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        let fileName = "materials_\(Int(Date().timeIntervalSince1970)).pdf"
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)

        try renderer.writePDF(to: fileURL) { context in
            let firstPageCapacity = 6
            let nextPageCapacity = 8

            let totalPages: Int = {
                if items.count <= firstPageCapacity {
                    return 1
                }

                let remaining = items.count - firstPageCapacity
                return 1 + Int(ceil(Double(remaining) / Double(nextPageCapacity)))
            }()

            var itemIndex = 0

            for pageNumber in 1...totalPages {
                context.beginPage()

                drawHeader(
                    context: context.cgContext,
                    pageBounds: pageBounds,
                    topicTitle: topicTitle,
                    isEnglish: isEnglish
                )

                var currentY: CGFloat = 136

                if pageNumber == 1 {
                    currentY = drawSummary(
                        context: context.cgContext,
                        pageBounds: pageBounds,
                        top: currentY,
                        items: items,
                        isEnglish: isEnglish
                    )
                } else {
                    drawText(
                        isEnglish ? "Exercises list" : "רשימת תרגילים",
                        in: CGRect(
                            x: 24,
                            y: currentY,
                            width: pageWidth - 48,
                            height: 24
                        ),
                        font: .systemFont(ofSize: 17, weight: .bold),
                        color: UIColor(red: 12 / 255, green: 78 / 255, blue: 130 / 255, alpha: 1),
                        alignment: .center
                    )

                    currentY += 34
                }

                let capacity = pageNumber == 1
                    ? firstPageCapacity
                    : nextPageCapacity

                if items.isEmpty {
                    drawRoundedBox(
                        context: context.cgContext,
                        rect: CGRect(
                            x: 24,
                            y: currentY,
                            width: pageWidth - 48,
                            height: 92
                        ),
                        fill: UIColor(red: 244 / 255, green: 250 / 255, blue: 1, alpha: 1),
                        stroke: UIColor(red: 191 / 255, green: 213 / 255, blue: 232 / 255, alpha: 1)
                    )

                    drawText(
                        isEnglish
                        ? "No exercises to display"
                        : "אין תרגילים להצגה",
                        in: CGRect(
                            x: 40,
                            y: currentY + 28,
                            width: pageWidth - 80,
                            height: 32
                        ),
                        font: .systemFont(ofSize: 17, weight: .bold),
                        color: UIColor(red: 12 / 255, green: 78 / 255, blue: 130 / 255, alpha: 1),
                        alignment: .center
                    )
                } else {
                    for _ in 0..<capacity {
                        guard itemIndex < items.count else { break }

                        currentY = drawItem(
                            context: context.cgContext,
                            pageBounds: pageBounds,
                            item: items[itemIndex],
                            top: currentY,
                            isEnglish: isEnglish,
                            alternate: itemIndex.isMultiple(of: 2)
                        )

                        itemIndex += 1
                    }
                }

                drawFooter(
                    context: context.cgContext,
                    pageBounds: pageBounds,
                    pageNumber: pageNumber,
                    totalPages: totalPages,
                    isEnglish: isEnglish
                )
            }
        }

        return fileURL
    }

    private static func drawHeader(
        context: CGContext,
        pageBounds: CGRect,
        topicTitle: String,
        isEnglish: Bool
    ) {
        context.setFillColor(UIColor.white.cgColor)
        context.fill(pageBounds)

        let navy = UIColor(
            red: 2 / 255,
            green: 43 / 255,
            blue: 74 / 255,
            alpha: 1
        )

        context.setFillColor(navy.cgColor)

        let headerPath = UIBezierPath()
        headerPath.move(to: CGPoint(x: pageBounds.width, y: 0))
        headerPath.addLine(to: CGPoint(x: pageBounds.width, y: 122))
        headerPath.addLine(to: CGPoint(x: 178, y: 122))
        headerPath.addLine(to: CGPoint(x: 238, y: 0))
        headerPath.close()
        headerPath.fill()

        drawLogo(
            context: context,
            center: CGPoint(x: 78, y: 58),
            radius: 42
        )

        drawText(
            isEnglish ? "Belt exercises" : "תרגילים לפי חגורה",
            in: CGRect(
                x: 250,
                y: 28,
                width: pageBounds.width - 284,
                height: 38
            ),
            font: .systemFont(ofSize: 28, weight: .bold),
            color: .white,
            alignment: isEnglish ? .left : .right
        )

        drawText(
            String(topicTitle.prefix(52)),
            in: CGRect(
                x: 250,
                y: 68,
                width: pageBounds.width - 284,
                height: 28
            ),
            font: .systemFont(ofSize: 14, weight: .regular),
            color: .white,
            alignment: isEnglish ? .left : .right
        )

        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"

        drawText(
            "\(isEnglish ? "Generated:" : "תאריך הפקה:") \(formatter.string(from: Date()))",
            in: CGRect(
                x: 24,
                y: 130,
                width: pageBounds.width - 48,
                height: 18
            ),
            font: .systemFont(ofSize: 9),
            color: UIColor(red: 80 / 255, green: 100 / 255, blue: 120 / 255, alpha: 1),
            alignment: isEnglish ? .left : .right
        )
    }

    private static func drawSummary(
        context: CGContext,
        pageBounds: CGRect,
        top: CGFloat,
        items: [MaterialsPdfItemIOS],
        isEnglish: Bool
    ) -> CGFloat {
        let knownTitle = isEnglish ? "Known" : "יודע"
        let unknownTitle = isEnglish ? "Unknown" : "לא יודע"

        let stats: [(String, String)] = [
            ("\(items.count)", isEnglish ? "Exercises" : "תרגילים"),
            ("\(items.filter { $0.status == knownTitle }.count)", knownTitle),
            ("\(items.filter { $0.status == unknownTitle }.count)", unknownTitle),
            ("\(items.filter(\.isExcluded).count)", isEnglish ? "Excluded" : "מוחרגים"),
            ("\(items.filter(\.isFavorite).count)", isEnglish ? "Favorites" : "מועדפים"),
            ("\(items.filter(\.hasNote).count)", isEnglish ? "Notes" : "הערות")
        ]

        let container = CGRect(
            x: 24,
            y: top,
            width: pageBounds.width - 48,
            height: 120
        )

        drawRoundedBox(
            context: context,
            rect: container,
            fill: UIColor(red: 234 / 255, green: 246 / 255, blue: 1, alpha: 1),
            stroke: UIColor(red: 191 / 255, green: 213 / 255, blue: 232 / 255, alpha: 1)
        )

        drawText(
            isEnglish ? "Exercises summary" : "סיכום תרגילים",
            in: CGRect(
                x: container.minX + 18,
                y: container.minY + 12,
                width: container.width - 36,
                height: 24
            ),
            font: .systemFont(ofSize: 17, weight: .bold),
            color: UIColor(red: 12 / 255, green: 78 / 255, blue: 130 / 255, alpha: 1),
            alignment: isEnglish ? .left : .right
        )

        let boxWidth = (container.width - 38) / 3

        for (index, stat) in stats.enumerated() {
            let row = index / 3
            let column = index % 3

            let rect = CGRect(
                x: container.minX + 12 + CGFloat(column) * (boxWidth + 7),
                y: container.minY + 45 + CGFloat(row) * 34,
                width: boxWidth,
                height: 28
            )

            drawRoundedBox(
                context: context,
                rect: rect,
                fill: UIColor(red: 244 / 255, green: 250 / 255, blue: 1, alpha: 1),
                stroke: UIColor(red: 191 / 255, green: 213 / 255, blue: 232 / 255, alpha: 1),
                radius: 9
            )

            drawText(
                stat.0,
                in: CGRect(
                    x: rect.minX,
                    y: rect.minY + 2,
                    width: rect.width,
                    height: 13
                ),
                font: .systemFont(ofSize: 12, weight: .bold),
                color: UIColor(red: 2 / 255, green: 43 / 255, blue: 74 / 255, alpha: 1),
                alignment: .center
            )

            drawText(
                stat.1,
                in: CGRect(
                    x: rect.minX,
                    y: rect.minY + 14,
                    width: rect.width,
                    height: 12
                ),
                font: .systemFont(ofSize: 8.5),
                color: UIColor(red: 80 / 255, green: 100 / 255, blue: 120 / 255, alpha: 1),
                alignment: .center
            )
        }

        return top + 144
    }

    private static func drawItem(
        context: CGContext,
        pageBounds: CGRect,
        item: MaterialsPdfItemIOS,
        top: CGFloat,
        isEnglish: Bool,
        alternate: Bool
    ) -> CGFloat {
        let rect = CGRect(
            x: 24,
            y: top,
            width: pageBounds.width - 48,
            height: 74
        )

        drawRoundedBox(
            context: context,
            rect: rect,
            fill: alternate
            ? UIColor(red: 234 / 255, green: 246 / 255, blue: 1, alpha: 1)
            : UIColor(red: 244 / 255, green: 250 / 255, blue: 1, alpha: 1),
            stroke: UIColor(red: 191 / 255, green: 213 / 255, blue: 232 / 255, alpha: 1)
        )

        let numberRect = CGRect(
            x: isEnglish ? rect.minX + 18 : rect.maxX - 50,
            y: rect.minY + 20,
            width: 30,
            height: 30
        )

        context.setFillColor(
            UIColor(red: 12 / 255, green: 78 / 255, blue: 130 / 255, alpha: 1).cgColor
        )
        context.fillEllipse(in: numberRect)

        drawText(
            "\(item.number)",
            in: numberRect.offsetBy(dx: 0, dy: 6),
            font: .systemFont(ofSize: 11, weight: .bold),
            color: .white,
            alignment: .center
        )

        let textX = isEnglish
            ? numberRect.maxX + 14
            : rect.minX + 22

        let textWidth = rect.width - 90

        drawText(
            item.title,
            in: CGRect(
                x: textX,
                y: rect.minY + 12,
                width: textWidth,
                height: 30
            ),
            font: .systemFont(ofSize: 13, weight: .bold),
            color: UIColor(red: 15 / 255, green: 23 / 255, blue: 42 / 255, alpha: 1),
            alignment: isEnglish ? .left : .right
        )

        let statusColor: UIColor = {
            if item.status == (isEnglish ? "Known" : "יודע") {
                return UIColor(red: 22 / 255, green: 163 / 255, blue: 74 / 255, alpha: 1)
            }

            if item.status == (isEnglish ? "Unknown" : "לא יודע") {
                return UIColor(red: 217 / 255, green: 119 / 255, blue: 6 / 255, alpha: 1)
            }

            return UIColor(red: 80 / 255, green: 100 / 255, blue: 120 / 255, alpha: 1)
        }()

        drawText(
            item.status,
            in: CGRect(
                x: textX,
                y: rect.minY + 45,
                width: textWidth,
                height: 18
            ),
            font: .systemFont(ofSize: 10.5, weight: .bold),
            color: statusColor,
            alignment: isEnglish ? .left : .right
        )

        var tags: [String] = []

        if item.isFavorite {
            tags.append(isEnglish ? "Favorite" : "מועדף")
        }

        if item.isExcluded {
            tags.append(isEnglish ? "Excluded" : "מוחרג")
        }

        if item.hasNote {
            tags.append(isEnglish ? "Note" : "הערה")
        }

        drawText(
            tags.isEmpty ? "—" : tags.joined(separator: " · "),
            in: CGRect(
                x: rect.minX + 18,
                y: rect.minY + 48,
                width: rect.width - 36,
                height: 16
            ),
            font: .systemFont(ofSize: 9.5),
            color: item.isExcluded
            ? UIColor(red: 220 / 255, green: 38 / 255, blue: 38 / 255, alpha: 1)
            : UIColor(red: 80 / 255, green: 100 / 255, blue: 120 / 255, alpha: 1),
            alignment: isEnglish ? .right : .left
        )

        return rect.maxY + 8
    }

    private static func drawFooter(
        context: CGContext,
        pageBounds: CGRect,
        pageNumber: Int,
        totalPages: Int,
        isEnglish: Bool
    ) {
        let footerY: CGFloat = 804

        context.setStrokeColor(
            UIColor(red: 2 / 255, green: 43 / 255, blue: 74 / 255, alpha: 1).cgColor
        )
        context.setLineWidth(2)
        context.move(to: CGPoint(x: 0, y: footerY))
        context.addLine(to: CGPoint(x: pageBounds.width, y: footerY))
        context.strokePath()

        drawLogo(
            context: context,
            center: CGPoint(x: 38, y: footerY + 22),
            radius: 13
        )

        drawText(
            "Together We Protect",
            in: CGRect(
                x: 58,
                y: footerY + 14,
                width: 150,
                height: 18
            ),
            font: .systemFont(ofSize: 8.5),
            color: UIColor(red: 80 / 255, green: 100 / 255, blue: 120 / 255, alpha: 1),
            alignment: .left
        )

        drawText(
            isEnglish
            ? "Page \(pageNumber) of \(totalPages)"
            : "עמוד \(pageNumber) מתוך \(totalPages)",
            in: CGRect(
                x: 210,
                y: footerY + 14,
                width: 175,
                height: 18
            ),
            font: .systemFont(ofSize: 8.5),
            color: UIColor(red: 80 / 255, green: 100 / 255, blue: 120 / 255, alpha: 1),
            alignment: .center
        )

        drawText(
            "Krav Maga Israel\nwww.kmi.org.il",
            in: CGRect(
                x: pageBounds.width - 180,
                y: footerY + 8,
                width: 150,
                height: 30
            ),
            font: .systemFont(ofSize: 8),
            color: UIColor(red: 80 / 255, green: 100 / 255, blue: 120 / 255, alpha: 1),
            alignment: .right
        )
    }

    private static func drawLogo(
        context: CGContext,
        center: CGPoint,
        radius: CGFloat
    ) {
        let navy = UIColor(
            red: 2 / 255,
            green: 43 / 255,
            blue: 74 / 255,
            alpha: 1
        )

        context.setFillColor(navy.cgColor)
        context.fillEllipse(
            in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
        )

        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(
            in: CGRect(
                x: center.x - radius + 4,
                y: center.y - radius + 4,
                width: (radius - 4) * 2,
                height: (radius - 4) * 2
            )
        )

        drawText(
            "KAMI",
            in: CGRect(
                x: center.x - radius,
                y: center.y - radius * 0.28,
                width: radius * 2,
                height: radius * 0.60
            ),
            font: .systemFont(
                ofSize: max(radius * 0.42, 7),
                weight: .bold
            ),
            color: navy,
            alignment: .center
        )
    }

    private static func drawRoundedBox(
        context: CGContext,
        rect: CGRect,
        fill: UIColor,
        stroke: UIColor,
        radius: CGFloat = 12
    ) {
        let path = UIBezierPath(
            roundedRect: rect,
            cornerRadius: radius
        )

        fill.setFill()
        path.fill()

        stroke.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private static func drawText(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail

        (text as NSString).draw(
            with: rect,
            options: [
                .usesLineFragmentOrigin,
                .usesFontLeading
            ],
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ],
            context: nil
        )
    }
}

private struct MaterialsPdfShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(
        context: Context
    ) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {
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

private extension Array where Element: Hashable {
    func removingDuplicatesKeepingOrder() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

