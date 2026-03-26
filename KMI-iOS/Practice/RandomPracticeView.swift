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

    // MARK: - Current item / weighted order
    @State private var weightedItems: [String] = []
    @State private var currentIndex: Int = 0

    // MARK: - Weighting
    @State private var dontKnow: Set<String> = []

    private var dontKnowStorageKey: String {
        let cleanTopic = topicTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
        return "random_practice_wrong_\(belt.id)_\(cleanTopic)"
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
    private let speaker = AVSpeechSynthesizer()

    // MARK: - Sheets
    @State private var showDurationSheet: Bool = true
    @State private var showExplanationSheet: Bool = false
    @State private var showSearchSheet: Bool = false
    @State private var searchQuery: String = ""
    @State private var pickedSearchItem: String? = nil

    private var beltColor: Color { KmiBeltPalette.color(for: belt) }

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
            .filter { $0.localizedCaseInsensitiveContains(q) }
            .prefix(50)
            .map { $0 }
    }

    private func beep() {
        // צליל מערכת פשוט (קצר) – עובד בכל iOS בלי קבצים חיצוניים
        AudioServicesPlaySystemSound(1104)
    }

    private func speak(_ text: String) {
        guard !isMuted else { return }
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "he-IL")
        u.rate = 0.48
        u.pitchMultiplier = 1.0
        speaker.stopSpeaking(at: .immediate)
        speaker.speak(u)
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
        guard !weightedItems.isEmpty else { return }

        if currentIndex < weightedItems.count - 1 {
            currentIndex += 1
        } else {
            rebuildWeightedItems(resetIndex: true)
        }

        if let currentItem {
            speak(currentItem)
        }
    }

    private func resetTimer() {
        let total = max(1, durationMinutes) * 60
        timeLeft = total
        halfAnnounced = false
    }

    private func startSession() {
        sessionStarted = true
        isRunning = false
        resetTimer()
        rebuildWeightedItems(resetIndex: true)

        if let currentItem {
            speak(currentItem)
        }

        isRunning = true
    }
    
    private func stopSession() {
        isRunning = false
        speaker.stopSpeaking(at: .immediate)
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
            speak(currentItem)
        }
    }

    private func tick() {
        guard isRunning, sessionStarted else { return }

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
                    speak("עבר חצי מזמן התרגול")
                }
            }
        }

        // זמן נגמר -> תרגיל הבא + איפוס
        if timeLeft == 0 {
            resetTimer()
            advanceToNextItem()
        }
    }

    var body: some View {
        KmiRootLayout(
            title: "תרגול",
            nav: nav,
            roleLabel: "מצב\nמתאמן",
            selectedIcon: nil,
            rightText: "\(belt.heb) • \(topicTitle)",
            titleColor: beltColor
        ) {
            ZStack {
                BeltTopicsGradientBackground()

                VStack(spacing: 14) {

                    // Timer row
                    WhiteCard {
                        HStack(spacing: 12) {
                            Text("⏳")
                                .font(.system(size: 22, weight: .heavy))

                            Text(formatTime(timeLeft))
                                .font(.system(size: 26, weight: .heavy))
                                .foregroundStyle(beltColor)

                            Spacer()

                            Button(action: togglePause) {
                                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                                    .font(.system(size: 18, weight: .heavy))
                                    .foregroundStyle(Color.black.opacity(0.75))
                                    .frame(width: 44, height: 44)
                                    .background(Circle().fill(Color.black.opacity(0.06)))
                            }
                            .buttonStyle(.plain)

                            Button {
                                showSearchSheet = true
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 18, weight: .heavy))
                                    .foregroundStyle(Color.black.opacity(0.70))
                                    .frame(width: 44, height: 44)
                                    .background(Circle().fill(Color.black.opacity(0.06)))
                            }
                            .buttonStyle(.plain)

                            Button {
                                isMuted.toggle()
                                if isMuted { speaker.stopSpeaking(at: .immediate) }
                                else if let currentItem { speak(currentItem) }
                            } label: {
                                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .font(.system(size: 18, weight: .heavy))
                                    .foregroundStyle(Color.black.opacity(0.70))
                                    .frame(width: 44, height: 44)
                                    .background(Circle().fill(Color.black.opacity(0.06)))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    WhiteCard {
                        Toggle(isOn: Binding(
                            get: { favoritesOnlyMode },
                            set: { newValue in
                                favoritesOnlyMode = newValue
                                saveFavoritesOnlyMode()
                                rebuildWeightedItems(resetIndex: true)
                            }
                        )) {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("תרגול ממועדפים בלבד")
                                    .font(.system(size: 16, weight: .heavy))
                                    .foregroundStyle(Color.black.opacity(0.82))

                                Text("אם אין מועדפים, התרגול יחזור לרשימה הרגילה")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.black.opacity(0.55))
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: beltColor.opacity(0.85)))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    .padding(.horizontal, 16)

                    // Current exercise card
                    WhiteCard {
                        VStack(spacing: 10) {
                            HStack {
                                Button {
                                    if let currentItem {
                                        toggleFavorite(currentItem)
                                    }
                                } label: {
                                    Image(systemName:
                                        (currentItem != nil && favoriteIds.contains(currentItem!))
                                        ? "star.fill" : "star"
                                    )
                                    .font(.system(size: 20, weight: .heavy))
                                    .foregroundStyle(
                                        (currentItem != nil && favoriteIds.contains(currentItem!))
                                        ? Color.yellow.opacity(0.95)
                                        : Color.black.opacity(0.55)
                                    )
                                    .frame(width: 40, height: 40)
                                    .background(Circle().fill(Color.black.opacity(0.06)))
                                }
                                .buttonStyle(.plain)
                                .disabled(currentItem == nil)

                                Spacer()
                            }

                            Text(currentItem ?? "בחר זמן והתחל")
                                .font(.system(size: 22, weight: .heavy))
                                .foregroundStyle(Color.black.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)

                            Text("לחץ כדי לראות הסבר")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.black.opacity(0.55))
                        }
                        .padding(.vertical, 18)
                        .padding(.horizontal, 14)
                    }
                    .padding(.horizontal, 16)
                    .onTapGesture {
                        guard currentItem != nil else { return }
                        showExplanationSheet = true
                    }

                    HStack(spacing: 12) {
                        Button {
                            advanceToNextItem()
                        } label: {
                            Text("דלג")
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Capsule().fill(Color.purple.opacity(0.75)))
                        }
                        .buttonStyle(.plain)

                        Button {
                            if let it = currentItem {
                                dontKnow.insert(it)
                                saveDontKnow()
                                rebuildWeightedItems(resetIndex: false)
                            }
                            advanceToNextItem()
                        } label: {
                            Text("לא יודע")
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Capsule().fill(Color.red.opacity(0.85)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 0)

                    Button {
                        stopSession()
                        dismiss()
                    } label: {
                        Text("סיום וחזרה")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(Color.black.opacity(0.80))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.92))
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
                }
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                tick()
            }
            .onAppear {
                loadDontKnow()
                loadFavorites()
                loadFavoritesOnlyMode()

                sessionStarted = false
                isRunning = false
                weightedItems = []
                currentIndex = 0
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
                    selectedMinutes: $durationMinutes,
                    alertHalfTime: $alertHalfTime,
                    beepLast10: $beepLast10,
                    onStart: {
                        showDurationSheet = false
                        DispatchQueue.main.async {
                            startSession()
                        }
                    },
                    onCancel: {
                        showDurationSheet = false
                        dismiss()
                    }
                )
                .presentationDetents([.fraction(0.46)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showExplanationSheet) {
                PracticeExplanationSheet(
                    belt: belt,
                    itemTitle: pickedSearchItem ?? currentItem ?? "",
                    onClose: {
                        loadFavorites()
                        rebuildWeightedItems(resetIndex: true)
                        showExplanationSheet = false
                        pickedSearchItem = nil
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .onDisappear {
                    loadFavorites()
                    rebuildWeightedItems(resetIndex: true)
                }
            }
            .sheet(isPresented: $showSearchSheet) {
                PracticeSearchSheet(
                    belt: belt,
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
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .onDisappear {
                stopSession()
                showDurationSheet = false
                showExplanationSheet = false
                showSearchSheet = false
            }
        }
    }
}

// MARK: - Picker Sheet (partial)

private struct PracticeDurationPickerSheet: View {

    let belt: Belt
    @Binding var selectedMinutes: Int
    @Binding var alertHalfTime: Bool
    @Binding var beepLast10: Bool

    let onStart: () -> Void
    let onCancel: () -> Void

    private var beltColor: Color { KmiBeltPalette.color(for: belt) }
    private let options: [Int] = [1, 3, 5]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {

                Text("בחר זמן תרגול")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(Color.black.opacity(0.85))
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
                                Text("דק׳")
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
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("התראה באמצע הזמן")
                                .font(.system(size: 16, weight: .heavy))
                            Text("צפצוף + הודעה קולית בחצי הזמן")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.black.opacity(0.55))
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    Toggle(isOn: $beepLast10) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("צליל ב-10 השניות האחרונות")
                                .font(.system(size: 16, weight: .heavy))
                            Text("צפצוף קצר כל שנייה עד לסיום")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.black.opacity(0.55))
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: beltColor.opacity(0.85)))
                .padding(.horizontal, 16)

                HStack(spacing: 12) {
                    Button(action: onStart) {
                        Text("התחל")
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
                        Text("בטל")
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
    let itemTitle: String
    let onClose: () -> Void

    private let favoritesKey = "practice_favorites"

    @State private var favoriteIds: Set<String> = {
        Set(UserDefaults.standard.stringArray(forKey: "practice_favorites") ?? [])
    }()

    private var beltColor: Color { KmiBeltPalette.color(for: belt) }

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
                    Text(itemTitle)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.85))
                        .multilineTextAlignment(.center)

                    Text("(\(belt.heb))")
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
                VStack(alignment: .trailing, spacing: 10) {
                    Text("הסבר לתרגיל")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.85))

                    Text(explanationText(for: belt, itemTitle: itemTitle))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.65))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
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
    @Binding var query: String
    let results: [String]
    let onPick: (String) -> Void
    let onClose: () -> Void

    private var beltColor: Color { KmiBeltPalette.color(for: belt) }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {

                Text("חיפוש תרגיל")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .padding(.top, 10)

                TextField("הקלד שם תרגיל", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 16)

                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("התחל להקליד כדי לחפש תרגיל")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.55))
                        .padding(.top, 8)
                } else if results.isEmpty {
                    Text("לא נמצאו תרגילים תואמים")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.55))
                        .padding(.top, 8)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(results, id: \.self) { result in
                            Button {
                                onPick(result)
                            } label: {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundStyle(beltColor.opacity(0.85))

                                    Spacer()

                                    Text(result)
                                        .font(.system(size: 16, weight: .heavy))
                                        .foregroundStyle(Color.black.opacity(0.82))
                                        .multilineTextAlignment(.trailing)
                                }
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
                    Text("סגור")
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

private func explanationText(for belt: Belt, itemTitle: String) -> String {
    let clean = itemTitle.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !clean.isEmpty else {
        return "לא נבחר תרגיל להצגה."
    }

    let explanations = Explanations()

    let direct = explanations.get(belt: belt, item: clean).trimmed()

    if !direct.isEmpty {
        return direct
    }

    let alt = clean
        .components(separatedBy: "::")
        .last?
        .components(separatedBy: ":")
        .last?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? clean

    let fallback = explanations.get(belt: belt, item: alt).trimmed()

    if !fallback.isEmpty {
        return fallback
    }

    return "אין כרגע הסבר לתרגיל הזה."
}

private extension String {
    func trimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
