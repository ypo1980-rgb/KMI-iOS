import SwiftUI
import Shared
import Combine
import AVFoundation
import AudioToolbox

struct RandomPracticeView: View {

    @Environment(\.dismiss) private var dismiss

    @ObservedObject var nav: AppNavModel

    let belt: Belt
    let topicTitle: String
    let items: [String]

    // MARK: - Settings (from picker)
    @State private var durationMinutes: Int = 1
    @State private var alertHalfTime: Bool = true
    @State private var beepLast10: Bool = true

    // MARK: - Session
    @State private var timeLeft: Int = 60
    @State private var isRunning: Bool = false
    @State private var sessionStarted: Bool = false
    @State private var halfAnnounced: Bool = false
    @State private var isExiting: Bool = false

    // MARK: - Current item / weighted order
    @State private var weightedItems: [String] = []
    @State private var currentIndex: Int = 0

    // MARK: - Weighting / Status
    @State private var dontKnow: Set<String> = []
    @State private var currentPracticeStatus: Bool? = nil

    private var dontKnowStorageKey: String {
        let cleanTopic = topicTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
        return "random_practice_wrong_\(belt.id)_\(cleanTopic)"
    }

    private var practiceStatusStoragePrefix: String {
        let cleanTopic = topicTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
        return "random_practice_status_\(belt.id)_\(cleanTopic)"
    }

    private func loadPracticeSettings() {
        let defaults = UserDefaults.standard

        let savedMinutes = defaults.integer(
            forKey: "timer_minutes"
        )

        durationMinutes = savedMinutes > 0
            ? savedMinutes
            : 1

        if defaults.object(forKey: "beep_half") != nil {
            alertHalfTime = defaults.bool(
                forKey: "beep_half"
            )
        }

        if defaults.object(forKey: "beep_last10") != nil {
            beepLast10 = defaults.bool(
                forKey: "beep_last10"
            )
        }
    }

    private func savePracticeSettings() {
        UserDefaults.standard.set(
            max(1, durationMinutes),
            forKey: "timer_minutes"
        )

        UserDefaults.standard.set(
            alertHalfTime,
            forKey: "beep_half"
        )

        UserDefaults.standard.set(
            beepLast10,
            forKey: "beep_last10"
        )
    }

    private func normalizedPracticeId(_ item: String) -> String {
        item
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{200F}", with: "")
            .replacingOccurrences(of: "\u{200E}", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
    }

    private func practiceStatusKey(for item: String) -> String {
        "\(practiceStatusStoragePrefix)_\(normalizedPracticeId(item))"
    }

    // MARK: - Favorites
    @State private var favoriteIds: Set<String> = []
    @State private var favoritesOnlyMode: Bool = false

    private let favoritesKey = "practice_favorites"

    private var favoritesOnlyKey: String {
        "random_practice_favorites_only_\(belt.id)"
    }

    private func loadFavorites() {
        let saved = UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
        favoriteIds = Set(saved)
    }

    private func loadFavoritesOnlyMode() {
        favoritesOnlyMode = UserDefaults.standard.bool(forKey: favoritesOnlyKey)
    }

    private func saveFavoritesOnlyMode() {
        UserDefaults.standard.set(favoritesOnlyMode, forKey: favoritesOnlyKey)
    }

    private func toggleFavorite(_ item: String) {
        let clean = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        var updated = favoriteIds
        if updated.contains(clean) {
            updated.remove(clean)
        } else {
            updated.insert(clean)
        }

        favoriteIds = updated
        UserDefaults.standard.set(Array(updated).sorted(), forKey: favoritesKey)
    }

    // MARK: - Audio
    @State private var isMuted: Bool = false
    @State private var speaker = AVSpeechSynthesizer()

    // MARK: - Sheets
    @State private var showDurationSheet: Bool = true
    @State private var showExplanationSheet: Bool = false
    @State private var showSearchSheet: Bool = false
    @State private var searchQuery: String = ""
    @State private var pickedSearchItem: String? = nil

    @AppStorage("user_role") private var storedUserRole: String = "trainee"
    @AppStorage("user_logged_in") private var isLoggedIn: Bool = false

    @AppStorage("kmi_app_language") private var kmiAppLanguage: String = ""
    @AppStorage("app_language") private var appLanguage: String = ""
    @AppStorage("initial_language_code") private var initialLanguageCode: String = ""
    @AppStorage("selected_language_code") private var selectedLanguageCode: String = ""

    private var beltColor: Color { KmiBeltPalette.color(for: belt) }

    private var practiceBackgroundColor: Color {
        switch belt.id.lowercased() {
        case "white":
            return Color(red: 0.96, green: 0.96, blue: 0.96)
        case "yellow":
            return Color(red: 1.00, green: 0.98, blue: 0.76)
        case "orange":
            return Color(red: 1.00, green: 0.89, blue: 0.72)
        case "green":
            return Color(red: 0.84, green: 0.94, blue: 0.82)
        case "blue":
            return Color(red: 0.82, green: 0.90, blue: 1.00)
        case "brown":
            return Color(red: 0.86, green: 0.76, blue: 0.66)
        case "black":
            return Color(red: 0.14, green: 0.14, blue: 0.16)
        default:
            return beltColor.opacity(0.18)
        }
    }

    private var exerciseCardColor: Color {
        switch belt.id.lowercased() {
        case "black":
            return Color.white.opacity(0.92)
        default:
            return Color(red: 1.00, green: 0.97, blue: 0.73)
        }
    }

    private var timerAccentColor: Color {
        Color.purple.opacity(0.86)
    }

    private var effectiveLanguageCode: String {
        let candidates = [
            kmiAppLanguage,
            appLanguage,
            selectedLanguageCode,
            initialLanguageCode
        ]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        return candidates.first ?? "he"
    }

    private var isEnglish: Bool {
        effectiveLanguageCode.hasPrefix("en")
    }

    private var screenLayoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    private var practiceTextAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var practiceFrameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private func beltNameForUi(_ belt: Belt) -> String {
        guard isEnglish else { return belt.heb }

        switch belt.id.lowercased() {
        case "white":
            return "White Belt"
        case "yellow":
            return "Yellow Belt"
        case "orange":
            return "Orange Belt"
        case "green":
            return "Green Belt"
        case "blue":
            return "Blue Belt"
        case "brown":
            return "Brown Belt"
        case "black":
            return "Black Belt"
        default:
            return belt.heb
        }
    }

    private func itemTitleForUi(
        _ item: String
    ) -> String {
        let cleanItem =
            item
                .replacingOccurrences(
                    of: "\u{200F}",
                    with: ""
                )
                .replacingOccurrences(
                    of: "\u{200E}",
                    with: ""
                )
                .replacingOccurrences(
                    of: "\u{00A0}",
                    with: " "
                )
                .replacingOccurrences(
                    of: "\\s+",
                    with: " ",
                    options:
                        .regularExpression
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard !cleanItem.isEmpty else {
            return ""
        }

        return KmiEnglishTitleResolver
            .title(
                for: cleanItem,
                isEnglish: isEnglish
            )
    }

    private func topicTitleForUi(
        _ title: String
    ) -> String {
        let cleanTitle =
            title
                .replacingOccurrences(
                    of: "\u{200F}",
                    with: ""
                )
                .replacingOccurrences(
                    of: "\u{200E}",
                    with: ""
                )
                .replacingOccurrences(
                    of: "\u{00A0}",
                    with: " "
                )
                .replacingOccurrences(
                    of: "\\s+",
                    with: " ",
                    options:
                        .regularExpression
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard !cleanTitle.isEmpty else {
            return isEnglish
                ? "All Topics"
                : "כל הנושאים"
        }

        if cleanTitle == "__ALL__" {
            return isEnglish
                ? "All Topics"
                : "כל הנושאים"
        }

        return KmiEnglishTitleResolver
            .title(
                for: cleanTitle,
                isEnglish: isEnglish
            )
    }

    private var currentItem: String? {
        guard currentIndex >= 0, currentIndex < weightedItems.count else { return nil }
        return weightedItems[currentIndex]
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var searchResults: [String] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }

        return cleanItems(items)
            .filter { item in
                let raw = item.trimmingCharacters(in: .whitespacesAndNewlines)
                let ui = itemTitleForUi(raw)
                return raw.localizedCaseInsensitiveContains(q)
                    || ui.localizedCaseInsensitiveContains(q)
            }
            .prefix(50)
            .map { $0 }
    }

    private func beep() {
        // צליל מערכת פשוט (קצר) – עובד בכל iOS בלי קבצים חיצוניים
        AudioServicesPlaySystemSound(1104)
    }

    private func speak(_ text: String) {
        guard !isMuted else { return }

        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: clean)
        utterance.voice = AVSpeechSynthesisVoice(language: isEnglish ? "en-US" : "he-IL")
        utterance.rate = isEnglish ? 0.46 : 0.48
        utterance.pitchMultiplier = 1.0

        speaker.stopSpeaking(at: .immediate)
        speaker.speak(utterance)
    }

    private func cleanItems(_ arr: [String]) -> [String] {
        var seen = Set<String>()
        return arr
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }

    private func activeItems() -> [String] {
        let base = cleanItems(items)

        guard favoritesOnlyMode else { return base }

        let filtered = base.filter { favoriteIds.contains($0) }
        return filtered.isEmpty ? base : filtered
    }

    private func loadDontKnow() {
        let saved = UserDefaults.standard.stringArray(forKey: dontKnowStorageKey) ?? []
        dontKnow = Set(saved)
    }

    private func saveDontKnow() {
        UserDefaults.standard.set(Array(dontKnow).sorted(), forKey: dontKnowStorageKey)
    }

    private func loadPracticeStatus(for item: String?) -> Bool? {
        guard let item else { return nil }

        let raw = UserDefaults.standard
            .string(forKey: practiceStatusKey(for: item))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch raw {
        case "known":
            return true
        case "unknown":
            return false
        default:
            return nil
        }
    }

    private func savePracticeStatus(_ status: Bool?, for item: String?) {
        guard let item else { return }

        let key = practiceStatusKey(for: item)

        switch status {
        case true:
            UserDefaults.standard.set("known", forKey: key)
            dontKnow.remove(item)
        case false:
            UserDefaults.standard.set("unknown", forKey: key)
            dontKnow.insert(item)
        case nil:
            UserDefaults.standard.removeObject(forKey: key)
            dontKnow.remove(item)
        }

        saveDontKnow()
    }

    private func refreshCurrentPracticeStatus() {
        currentPracticeStatus = loadPracticeStatus(for: currentItem)
    }

    private func toggleCurrentPracticeStatus() {
        let nextStatus: Bool?

        switch currentPracticeStatus {
        case nil:
            nextStatus = true
        case true:
            nextStatus = false
        case false:
            nextStatus = nil
        }

        savePracticeStatus(
            nextStatus,
            for: currentItem
        )

        currentPracticeStatus = nextStatus

        /*
         * לא מערבבים את הרשימה בזמן שהמשתמש נמצא באמצע תרגול.
         * המשקל החדש ישפיע על הסבב הבא.
         */
    }

    private func weightedPool() -> [String] {
        let base = activeItems()
        guard !base.isEmpty else { return [] }

        var pool: [String] = []
        pool.reserveCapacity(base.count * 3)

        for it in base {
            pool.append(it)
            if dontKnow.contains(it) {
                pool.append(it)
                pool.append(it)
            }
        }

        return pool.shuffled()
    }

    private func rebuildWeightedItems(resetIndex: Bool) {
        weightedItems = weightedPool()

        if weightedItems.isEmpty {
            currentIndex = 0
            return
        }

        if resetIndex || currentIndex >= weightedItems.count {
            currentIndex = 0
        }
    }

    private func advanceToNextItem() {
        guard !isExiting,
              !weightedItems.isEmpty else {
            return
        }

        guard currentIndex < weightedItems.count - 1 else {
            isRunning = false
            sessionStarted = false
            timeLeft = 0
            speaker.stopSpeaking(at: .immediate)
            return
        }

        currentIndex += 1
        refreshCurrentPracticeStatus()

        if isRunning,
           let currentItem {
            speak(
                itemTitleForUi(currentItem)
            )
        }
    }

    private func resetTimer() {
        let total = max(1, durationMinutes) * 60
        timeLeft = total
        halfAnnounced = false
    }

    private func startSession() {
        isExiting = false
        sessionStarted = true
        isRunning = false

        savePracticeSettings()
        resetTimer()
        rebuildWeightedItems(resetIndex: true)
        refreshCurrentPracticeStatus()

        isRunning = true

        if let currentItem {
            speak(
                itemTitleForUi(currentItem)
            )
        }
    }

    private func stopSession() {
        isRunning = false
        sessionStarted = false
        speaker.stopSpeaking(at: .immediate)
    }

    private func finishAndDismiss() {
        guard !isExiting else { return }

        isExiting = true
        stopSession()

        showDurationSheet = false
        showExplanationSheet = false
        showSearchSheet = false
        pickedSearchItem = nil

        dismiss()
    }

    private func togglePause() {
        if !sessionStarted {
            startSession()
            return
        }

        isRunning.toggle()

        if !isRunning {
            speaker.stopSpeaking(at: .immediate)
        } else if let currentItem {
            speak(
                itemTitleForUi(currentItem)
            )
        }
    }

    private func tick() {
        guard !isExiting,
              isRunning,
              sessionStarted else {
            return
        }

        if timeLeft > 0 {
            timeLeft -= 1

            // 🔔 10 שניות אחרונות
            if beepLast10, timeLeft > 0, timeLeft <= 10 {
                beep()
            }

            // 🔔 חצי זמן
            if alertHalfTime, !halfAnnounced {
                let total = max(1, durationMinutes) * 60
                let halfPoint = total / 2
                if timeLeft == halfPoint {
                    halfAnnounced = true
                    beep()
                    speak(tr("עבר חצי מזמן התרגול", "Half of the practice time has passed"))
                }
            }
        }

        // זמן נגמר -> תרגיל הבא + איפוס
        if timeLeft == 0 {
            resetTimer()
            advanceToNextItem()
        }
    }

    private var dynamicRoleLabel: String {
        guard isLoggedIn else {
            return tr("מצב\nמתאמן", "Trainee\nMode")
        }

        let normalizedRole = storedUserRole
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if normalizedRole.contains("coach") {
            return tr("מצב\nמאמן", "Coach\nMode")
        }

        return tr("מצב\nמתאמן", "Trainee\nMode")
    }

    private var isAllTopicsPractice: Bool {
        let cleanTopic = topicTitle
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return cleanTopic.isEmpty ||
            cleanTopic == "__ALL__" ||
            cleanTopic.caseInsensitiveCompare("all") == .orderedSame ||
            cleanTopic.caseInsensitiveCompare("random") == .orderedSame ||
            cleanTopic.caseInsensitiveCompare("אקראי") == .orderedSame ||
            cleanTopic.caseInsensitiveCompare(belt.id) == .orderedSame ||
            cleanTopic.caseInsensitiveCompare(belt.heb) == .orderedSame
    }

    private var screenTitle: String {
        if isAllTopicsPractice {
            return tr(
                "תרגול אקראי – \(beltNameForUi(belt))",
                "Random Practice – \(beltNameForUi(belt))"
            )
        }

        return tr(
            "תרגול לפי נושא – \(beltNameForUi(belt))",
            "Practice by Topic – \(beltNameForUi(belt))"
        )
    }

    private var screenRightText: String {
        topicTitleForUi(topicTitle)
    }

    private var statusCircleIcon: String {
        switch currentPracticeStatus {
        case true:
            return "checkmark"
        case false:
            return "xmark"
        case nil:
            return "circle"
        }
    }

    private var statusLabel: String {
        switch currentPracticeStatus {
        case true:
            return tr("יודע", "Known")
        case false:
            return tr("לא יודע", "Don't know")
        case nil:
            return tr("לא סומן", "Not marked")
        }
    }

    private var statusLabelColor: Color {
        switch currentPracticeStatus {
        case true:
            return Color.green.opacity(0.92)
        case false:
            return Color.red.opacity(0.90)
        case nil:
            return Color(red: 0.20, green: 0.27, blue: 0.36)
        }
    }

    private var statusCircleFill: Color {
        switch currentPracticeStatus {
        case true:
            return Color(
                red: 0.13,
                green: 0.77,
                blue: 0.37
            )
        case false:
            return Color(
                red: 0.86,
                green: 0.15,
                blue: 0.15
            )
        case nil:
            return Color.white
        }
    }

    private var statusCircleBorder: Color {
        switch currentPracticeStatus {
        case true:
            return Color(
                red: 0.09,
                green: 0.64,
                blue: 0.29
            )
        case false:
            return Color(
                red: 0.72,
                green: 0.11,
                blue: 0.11
            )
        case nil:
            return beltColor.opacity(0.42)
        }
    }

    private var statusCircleIconColor: Color {
        switch currentPracticeStatus {
        case true, false:
            return Color.white
        case nil:
            return beltColor.opacity(0.72)
        }
    }
    
    var body: some View {
        ZStack {
            practiceBackgroundColor
                .ignoresSafeArea()

            LinearGradient(
                    colors: [
                        Color.white.opacity(belt.id.lowercased() == "black" ? 0.04 : 0.24),
                        practiceBackgroundColor,
                        Color.white.opacity(belt.id.lowercased() == "black" ? 0.02 : 0.18)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 14) {

                    // Timer row — נקי כמו Android, ללא כרטיס חיצוני
                    HStack(spacing: 10) {
                        Text("⏳")
                            .font(.system(size: 30, weight: .heavy))

                        Text(formatTime(timeLeft))
                            .font(.system(size: 34, weight: .black))
                            .monospacedDigit()
                            .foregroundStyle(timerAccentColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    // Current exercise card
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(exerciseCardColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(Color.white.opacity(0.70), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 7)

                        Text(
                            currentItem.map {
                                itemTitleForUi($0)
                            } ?? tr(
                                "בחר זמן והתחל",
                                "Choose duration and start"
                            )
                        )
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(Color.black.opacity(0.90))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 30)
                    }
                    .padding(.horizontal, 16)
                    .onTapGesture {
                        guard currentItem != nil else { return }
                        showExplanationSheet = true
                    }

                    HStack(spacing: 18) {
                        Button {
                            isMuted.toggle()
                            if isMuted {
                                speaker.stopSpeaking(at: .immediate)
                            } else if let currentItem {
                                speak(itemTitleForUi(currentItem))
                            }
                        } label: {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 24, weight: .heavy))
                                .foregroundStyle(isMuted ? Color.gray.opacity(0.90) : Color.purple.opacity(0.90))
                                .frame(width: 58, height: 58)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(Color.white.opacity(0.92))
                                        .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 5)
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            toggleCurrentPracticeStatus()
                        } label: {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(statusCircleFill)
                                        .frame(width: 34, height: 34)
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    statusCircleBorder,
                                                    lineWidth: 2
                                                )
                                        )

                                    Image(systemName: statusCircleIcon)
                                        .font(
                                            .system(
                                                size: 18,
                                                weight: .black
                                            )
                                        )
                                        .foregroundStyle(
                                            statusCircleIconColor
                                        )
                                }

                                Text(statusLabel)
                                    .font(
                                        .system(
                                            size: 14,
                                            weight: .heavy
                                        )
                                    )
                                    .foregroundStyle(statusLabelColor)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 52)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.90))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        beltColor.opacity(0.18),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(
                                color: Color.black.opacity(0.10),
                                radius: 8,
                                x: 0,
                                y: 5
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(currentItem == nil)
                        .opacity(currentItem == nil ? 0.45 : 1.0)

                        Button(action: togglePause) {
                            Image(systemName: isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 24, weight: .heavy))
                                .foregroundStyle(Color.black.opacity(0.82))
                                .frame(width: 58, height: 58)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(Color.white.opacity(0.92))
                                        .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 16)

                    Spacer(minLength: 0)

                    RandomPracticeBottomActionCard(
                        isEnglish: isEnglish,
                        canShowHelp: currentItem != nil,
                        onHelp: {
                            showExplanationSheet = true
                        },
                        onSkip: {
                            advanceToNextItem()
                        },
                        onFinish: {
                            finishAndDismiss()
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
                }
            }
            .environment(\.layoutDirection, screenLayoutDirection)
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                tick()
            }
            .onChange(of: currentIndex) { _, _ in
                refreshCurrentPracticeStatus()
            }
            .onChange(of: weightedItems.count) { _, _ in
                refreshCurrentPracticeStatus()
            }
            .onAppear {
                isExiting = false

                loadDontKnow()
                loadFavorites()
                loadFavoritesOnlyMode()
                loadPracticeSettings()

                sessionStarted = false
                isRunning = false
                weightedItems = []
                currentIndex = 0
                currentPracticeStatus = nil
                resetTimer()

                searchQuery = ""
                pickedSearchItem = nil
                showSearchSheet = false
                showExplanationSheet = false
                showDurationSheet = false

                if !sessionStarted {
                    DispatchQueue.main.async {
                        showDurationSheet = true
                    }
                }
            }
            .sheet(isPresented: $showDurationSheet) {
                PracticeDurationPickerSheet(
                    belt: belt,
                    isEnglish: isEnglish,
                    selectedMinutes: $durationMinutes,
                    alertHalfTime: $alertHalfTime,
                    beepLast10: $beepLast10,
                    onStart: {
                        savePracticeSettings()
                        showDurationSheet = false

                        DispatchQueue.main.async {
                            startSession()
                        }
                    },
                    onCancel: {
                        finishAndDismiss()
                    }
                )
                .environment(\.layoutDirection, screenLayoutDirection)
                .presentationDetents([.fraction(0.46)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showExplanationSheet) {
                PracticeExplanationSheet(
                    belt: belt,
                    topicTitle: topicTitle,
                    isEnglish: isEnglish,
                    itemTitle: pickedSearchItem ?? currentItem ?? "",
                    onClose: {
                        loadFavorites()
                        showExplanationSheet = false
                        pickedSearchItem = nil
                    }
                )
                .environment(\.layoutDirection, screenLayoutDirection)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .onDisappear {
                    loadFavorites()
                }
            }
            .sheet(isPresented: $showSearchSheet) {
                PracticeSearchSheet(
                    belt: belt,
                    isEnglish: isEnglish,
                    query: $searchQuery,
                    results: searchResults,
                    onPick: { picked in
                        pickedSearchItem = picked
                        showSearchSheet = false
                        DispatchQueue.main.async {
                            showExplanationSheet = true
                        }
                    },
                    onClose: {
                        showSearchSheet = false
                        searchQuery = ""
                    }
                )
                .environment(\.layoutDirection, screenLayoutDirection)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .onDisappear {
                isExiting = true
                stopSession()

                showDurationSheet = false
                showExplanationSheet = false
                showSearchSheet = false
                pickedSearchItem = nil
            }
        }
    }

    // MARK: - Bottom Action Card

private struct RandomPracticeBottomActionCard: View {

    let isEnglish: Bool
    let canShowHelp: Bool
    let onHelp: () -> Void
    let onSkip: () -> Void
    let onFinish: () -> Void

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                Button(action: onHelp) {
                    Label(tr("עזרה", "Help"), systemImage: "info.circle")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color.purple.opacity(0.92))
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.93, green: 0.90, blue: 1.00))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.62), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 5)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canShowHelp)
                .opacity(canShowHelp ? 1.0 : 0.45)

                Button(action: onSkip) {
                    Label(tr("דלג", "Skip"), systemImage: "play.fill")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(
                            Capsule()
                                .fill(Color.purple.opacity(0.80))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.42), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.14), radius: 9, x: 0, y: 6)
                        )
                }
                .buttonStyle(.plain)
            }

            Button(action: onFinish) {
                Text(tr("סיום וחזרה", "Finish and Return"))
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Color.black.opacity(0.86))
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(0.98))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 5)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.82), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.14), radius: 14, x: 0, y: 8)
        )
    }
}

// MARK: - Picker Sheet

private struct PracticeDurationPickerSheet: View {

    let belt: Belt
    let isEnglish: Bool

    @Binding var selectedMinutes: Int
    @Binding var alertHalfTime: Bool
    @Binding var beepLast10: Bool

    let onStart: () -> Void
    let onCancel: () -> Void

    private var beltColor: Color { KmiBeltPalette.color(for: belt) }
    private let options: [Int] = [1, 3, 5]

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {

                Text(tr("בחר זמן תרגול", "Choose Practice Duration"))
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)

                Text(String(format: "%02d:00", selectedMinutes))
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(beltColor)
                    .padding(.bottom, 2)

                HStack(spacing: 10) {
                    ForEach(options, id: \.self) { m in
                        let isSel = (m == selectedMinutes)

                        Button {
                            selectedMinutes = m
                        } label: {
                            VStack(spacing: 6) {
                                Text("\(m)")
                                    .font(.system(size: 20, weight: .heavy))

                                Text(tr("דק׳", "min"))
                                    .font(.system(size: 12, weight: .bold))
                                    .opacity(0.85)
                            }
                            .foregroundStyle(isSel ? Color.white : Color.black.opacity(0.80))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(isSel ? beltColor.opacity(0.85) : Color.black.opacity(0.06))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)

                VStack(spacing: 10) {
                    Toggle(isOn: $alertHalfTime) {
                        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 2) {
                            Text(tr("התראה באמצע הזמן", "Mid-time alert"))
                                .font(.system(size: 16, weight: .heavy))
                                .multilineTextAlignment(textAlignment)

                            Text(tr("צפצוף + הודעה קולית בחצי הזמן", "Beep + voice announcement at halfway point"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.black.opacity(0.55))
                                .multilineTextAlignment(textAlignment)
                        }
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                    }

                    Toggle(isOn: $beepLast10) {
                        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 2) {
                            Text(tr("צליל ב-10 השניות האחרונות", "Sound in the last 10 seconds"))
                                .font(.system(size: 16, weight: .heavy))
                                .multilineTextAlignment(textAlignment)

                            Text(tr("צפצוף קצר כל שנייה עד לסיום", "Short beep every second until the end"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.black.opacity(0.55))
                                .multilineTextAlignment(textAlignment)
                        }
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: beltColor.opacity(0.85)))
                .padding(.horizontal, 16)

                HStack(spacing: 12) {
                    Button(action: onStart) {
                        Text(tr("התחל", "Start"))
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(beltColor.opacity(0.85))
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: onCancel) {
                        Text(tr("בטל", "Cancel"))
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(Color.black.opacity(0.72))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.black.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
            .padding(.top, 6)
        }
    }
}

// MARK: - Explanation Sheet

private struct PracticeExplanationSheet: View {

    let belt: Belt
    let topicTitle: String
    let isEnglish: Bool
    let itemTitle: String
    let onClose: () -> Void

    private let favoritesKey = "practice_favorites"

    @State private var favoriteIds: Set<String> = {
        Set(UserDefaults.standard.stringArray(forKey: "practice_favorites") ?? [])
    }()

    private var beltColor: Color { KmiBeltPalette.color(for: belt) }

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private var beltNameForUi: String {
        guard isEnglish else { return belt.heb }

        switch belt.id.lowercased() {
        case "white":
            return "White Belt"
        case "yellow":
            return "Yellow Belt"
        case "orange":
            return "Orange Belt"
        case "green":
            return "Green Belt"
        case "blue":
            return "Blue Belt"
        case "brown":
            return "Brown Belt"
        case "black":
            return "Black Belt"
        default:
            return belt.heb
        }
    }

    private var favoriteId: String {
        itemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isFavorite: Bool {
        !favoriteId.isEmpty && favoriteIds.contains(favoriteId)
    }

    private func toggleFavorite() {
        guard !favoriteId.isEmpty else { return }

        var updated = favoriteIds
        if updated.contains(favoriteId) {
            updated.remove(favoriteId)
        } else {
            updated.insert(favoriteId)
        }

        favoriteIds = updated
        UserDefaults.standard.set(Array(updated).sorted(), forKey: favoritesKey)
    }

    var body: some View {
        VStack(spacing: 14) {

            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.65))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.black.opacity(0.06)))
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 4) {
                    Text(itemTitle.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.85))
                        .multilineTextAlignment(.center)

                    Text("(\(beltNameForUi))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(beltColor.opacity(0.85))
                }

                Spacer()

                Button(action: toggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(isFavorite ? Color.yellow.opacity(0.95) : Color.black.opacity(0.65))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.black.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            WhiteCard {
                VStack(alignment: isEnglish ? .leading : .trailing, spacing: 10) {
                    Text(tr("הסבר לתרגיל", "Exercise Explanation"))
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.85))
                        .multilineTextAlignment(textAlignment)

                    Text(
                        explanationText(
                            for: belt,
                            topicTitle: topicTitle,
                            itemTitle: itemTitle,
                            isEnglish: isEnglish
                        )
                    )
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.65))
                    .multilineTextAlignment(textAlignment)
                    .frame(
                        maxWidth: .infinity,
                        alignment: frameAlignment
                    )
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 14)
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 20)
        }
    }
}

private struct PracticeSearchSheet: View {

    let belt: Belt
    let isEnglish: Bool

    @Binding var query: String

    let results: [String]
    let onPick: (String) -> Void
    let onClose: () -> Void

    private var beltColor: Color { KmiBeltPalette.color(for: belt) }

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {

                Text(tr("חיפוש תרגיל", "Search Exercise"))
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)

                TextField(tr("הקלד שם תרגיל", "Type exercise name"), text: $query)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(textAlignment)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)

                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(tr("התחל להקליד כדי לחפש תרגיל", "Start typing to search for an exercise"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                } else if results.isEmpty {
                    Text(tr("לא נמצאו תרגילים תואמים", "No matching exercises found"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(results, id: \.self) { result in
                            Button {
                                onPick(result)
                            } label: {
                                HStack(spacing: 12) {
                                    if isEnglish {
                                        Image(systemName: "magnifyingglass")
                                            .foregroundStyle(beltColor.opacity(0.85))

                                        Text(result.trimmingCharacters(in: .whitespacesAndNewlines))
                                            .font(.system(size: 16, weight: .heavy))
                                            .foregroundStyle(Color.black.opacity(0.82))
                                            .multilineTextAlignment(.leading)

                                        Spacer()
                                    } else {
                                        Spacer()

                                        Text(result.trimmingCharacters(in: .whitespacesAndNewlines))
                                            .font(.system(size: 16, weight: .heavy))
                                            .foregroundStyle(Color.black.opacity(0.82))
                                            .multilineTextAlignment(.trailing)

                                        Image(systemName: "magnifyingglass")
                                            .foregroundStyle(beltColor.opacity(0.85))
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: frameAlignment)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.black.opacity(0.05))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Button(action: onClose) {
                    Text(tr("סגור", "Close"))
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.72))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.black.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
            .padding(.top, 6)
        }
    }
}

private func explanationText(
    for belt: Belt,
    topicTitle: String,
    itemTitle: String,
    isEnglish: Bool
) -> String {
    let cleanItem = itemTitle
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )

    guard !cleanItem.isEmpty else {
        return isEnglish
            ? "No exercise selected to display."
            : "לא נבחר תרגיל להצגה."
    }

    let cleanTopic = topicTitle
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )

    let resolved = KmiExerciseExplanationResolverIOS
        .shared
        .get(
            belt: belt,
            topic: cleanTopic,
            item: cleanItem,
            isEnglish: isEnglish
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )

    if !resolved.isEmpty {
        return resolved
    }

    let alternativeItem = cleanItem
        .components(separatedBy: "::")
        .last?
        .components(separatedBy: ":")
        .last?
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? cleanItem

    let fallback = KmiExerciseExplanationResolverIOS
        .shared
        .get(
            belt: belt,
            topic: cleanTopic,
            item: alternativeItem,
            isEnglish: isEnglish
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )

    if !fallback.isEmpty {
        return fallback
    }

    return isEnglish
        ? "No explanation is currently available for this exercise."
        : "אין כרגע הסבר לתרגיל הזה."
}

private extension String {
    func trimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
