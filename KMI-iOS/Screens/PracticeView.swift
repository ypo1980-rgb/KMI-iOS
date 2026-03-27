import SwiftUI
import Shared
import AVFoundation
import AudioToolbox

struct PracticeView: View {
    let belt: Belt
    var topic: String? = nil

    private struct PracticeItem: Identifiable, Hashable {
        let id: String
        let rawItem: String
        let displayName: String
        let resolvedTopicTitle: String
    }

    @State private var practiceItems: [PracticeItem] = []
    @State private var currentIndex: Int = 0

    @State private var sessionStart = Date()
    @State private var completedCount: Int = 0
    @State private var showSummary: Bool = false
    @State private var isMuted: Bool = false
    @State private var didPlayHalfTimeAlert: Bool = false
    @State private var lastBeepSecond: Int? = nil

    private let speechSynth = AVSpeechSynthesizer()
    @State private var showDurationPicker = true
    @State private var practiceDuration: Int = 5
    @State private var timeRemaining: Int = 0
    @State private var timer: Timer?
    
    private var modeTitle: String {
        switch topic {
        case "__ALL__":
            return "כל התרגילים"
        case "__UNKNOWN__":
            return "לא יודע"
        case "__FAVORITES__":
            return "מועדפים"
        case .some(let topicTitle):
            return topicTitle
        case nil:
            return "תרגול"
        }
    }

    private var currentItem: PracticeItem? {
        guard practiceItems.indices.contains(currentIndex) else { return nil }
        return practiceItems[currentIndex]
    }

    var body: some View {
        ZStack {
            KmiGradientBackground()

            VStack(spacing: 0) {
                WhiteCard {
                    VStack(spacing: 6) {
                        Text("תרגול")
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundStyle(Color.black.opacity(0.84))

                        Text("חגורה: \(belt.heb)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.60))

                        Text("מצב: \(modeTitle)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.60))

                        Text("זמן נותר: \(formattedTimeRemaining)")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(Color.red.opacity(0.78))

                        Text("סה״כ תרגילים: \(practiceItems.count)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.50))
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer(minLength: 16)

                if let item = currentItem {
                    WhiteCard {
                        VStack(spacing: 18) {

                            ProgressView(
                                value: Double(currentIndex + 1),
                                total: Double(practiceItems.count)
                            )
                            .progressViewStyle(.linear)
                            .padding(.horizontal, 6)

                            Text(item.resolvedTopicTitle)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.purple.opacity(0.78))
                                .frame(maxWidth: .infinity, alignment: .center)

                            Text(item.displayName)
                                .font(.system(size: 28, weight: .heavy))
                                .foregroundStyle(Color.black.opacity(0.86))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.horizontal, 10)

                            Button {
                                isMuted.toggle()

                                if isMuted {
                                    stopSpeaking()
                                } else {
                                    speakCurrentItem()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    Text(isMuted ? "הפעל קול" : "השתק קול")
                                }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.purple.opacity(0.82))
                                )
                            }
                            .buttonStyle(.plain)

                            Text("\(currentIndex + 1) / \(practiceItems.count)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.black.opacity(0.50))
                        }
                        .padding(.vertical, 28)
                        .padding(.horizontal, 18)
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 18)

                    VStack(spacing: 12) {
                        HStack(spacing: 12) {

                            PracticeActionButton(
                                title: "סיים",
                                fill: Color.red.opacity(0.85),
                                onTap: {
                                    stopTimer()
                                    stopSpeaking()
                                    playFinishSound()
                                    showSummary = true
                                }
                            )
                            
                            PracticeActionButton(
                                title: "ערבב",
                                fill: Color.orange.opacity(0.86),
                                onTap: {
                                    shuffleItems()
                                }
                            )

                            PracticeActionButton(
                                title: "הקודם",
                                fill: Color.gray.opacity(0.72),
                                onTap: {
                                    goPrevious()
                                }
                            )

                            PracticeActionButton(
                                title: "הבא",
                                fill: Color(red: 0.44, green: 0.39, blue: 1.0),
                                onTap: {
                                    goNext()
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)

                } else {
                    Spacer()

                    WhiteCard {
                        VStack(spacing: 12) {
                            Text("אין תרגילים לתרגול")
                                .font(.system(size: 22, weight: .heavy))
                                .foregroundStyle(Color.black.opacity(0.82))

                            Text("בדוק אם יש תרגילים תואמים למסנן שבחרת")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.black.opacity(0.55))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 24)
                        .padding(.horizontal, 18)
                    }
                    .padding(.horizontal, 16)

                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showSummary) {
            PracticeSummaryView(
                duration: Date().timeIntervalSince(sessionStart),
                totalExercises: practiceItems.count,
                completedExercises: completedCount
            )
        }
        .sheet(isPresented: $showDurationPicker) {
            durationPickerView
        }
        .navigationTitle("תרגול")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            sessionStart = Date()
            completedCount = 0
            reloadPracticeItems()
        }
        .onChange(of: belt) { _, _ in
            sessionStart = Date()
            completedCount = 0
            reloadPracticeItems()
        }
        .onChange(of: topic) { _, _ in
            sessionStart = Date()
            completedCount = 0
            reloadPracticeItems()
        }
        .onChange(of: currentIndex) { _, _ in
            speakCurrentItem()
        }
        .onDisappear {
            stopTimer()
            stopSpeaking()
        }
    }

    private func reloadPracticeItems() {
        let loaded = buildPracticeItems()
        practiceItems = loaded.shuffled()
        currentIndex = 0
    }

    private func goNext() {
        guard !practiceItems.isEmpty else { return }

        completedCount += 1
        stopSpeaking()

        if currentIndex < practiceItems.count - 1 {
            currentIndex += 1
        } else {
            stopTimer()
            playFinishSound()
            showSummary = true
        }
    }
    
    private func goPrevious() {
        guard !practiceItems.isEmpty else { return }
        if currentIndex > 0 {
            currentIndex -= 1
        } else {
            currentIndex = max(practiceItems.count - 1, 0)
        }
    }

    private func shuffleItems() {
        guard !practiceItems.isEmpty else { return }
        stopSpeaking()
        practiceItems.shuffle()
        currentIndex = 0
    }

    private func buildPracticeItems() -> [PracticeItem] {
        switch topic {
        case "__UNKNOWN__":
            return buildUnknownItems()

        case "__FAVORITES__":
            return buildFavoriteItems()

        case "__ALL__":
            return buildAllItems()

        case .some(let topicTitle):
            return buildTopicItems(topicTitle: topicTitle, subTopicTitle: nil)

        case nil:
            return buildAllItems()
        }
    }

    private func buildAllItems() -> [PracticeItem] {
        let topicTitles = TopicsEngine.shared.topicTitlesFor(belt: belt)
        var out: [PracticeItem] = []
        var seen = Set<String>()

        for topicTitle in topicTitles {
            let built = buildTopicItems(topicTitle: topicTitle, subTopicTitle: nil)

            for item in built {
                if seen.insert(item.id).inserted {
                    out.append(item)
                }
            }
        }

        return out
    }

    private func buildUnknownItems() -> [PracticeItem] {
        buildAllItems().filter { item in
            UserDefaults.standard.string(forKey: "mark.\(item.id)") == "unknown"
        }
    }

    private func buildFavoriteItems() -> [PracticeItem] {
        buildAllItems().filter { item in
            UserDefaults.standard.bool(forKey: "favorite.\(item.id)")
        }
    }

    private func buildTopicItems(topicTitle: String, subTopicTitle: String?) -> [PracticeItem] {
        let rawItems = ContentRepo.shared.getAllItemsFor(
            belt: belt,
            topicTitle: topicTitle,
            subTopicTitle: subTopicTitle
        )

        var out: [PracticeItem] = []
        var seen = Set<String>()

        for raw in rawItems {
            let item = PracticeItem(
                id: canonicalId(
                    rawItem: raw,
                    resolvedTopicTitle: topicTitle,
                    resolvedSubTopicTitle: subTopicTitle
                ),
                rawItem: raw,
                displayName: displayName(
                    rawItem: raw,
                    resolvedTopicTitle: topicTitle,
                    resolvedSubTopicTitle: subTopicTitle
                ),
                resolvedTopicTitle: topicTitle
            )

            if seen.insert(item.id).inserted {
                out.append(item)
            }
        }

        return out
    }

    private func canonicalId(
        rawItem: String,
        resolvedTopicTitle: String,
        resolvedSubTopicTitle: String?
    ) -> String {
        let topic = resolvedTopicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let sub = resolvedSubTopicTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let item = rawItem.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(belt.id)||\(topic)||\(sub)||\(item)"
    }

    private func displayName(
        rawItem: String,
        resolvedTopicTitle: String,
        resolvedSubTopicTitle: String?
    ) -> String {
        var text = rawItem.trimmingCharacters(in: .whitespacesAndNewlines)

        let topic = resolvedTopicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("\(topic)::") {
            text = String(text.dropFirst("\(topic)::".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let resolvedSubTopicTitle {
            let sub = resolvedSubTopicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.hasPrefix("\(sub)::") {
                text = String(text.dropFirst("\(sub)::".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return text
    }

    private var formattedTimeRemaining: String {
        let minutes = max(timeRemaining, 0) / 60
        let seconds = max(timeRemaining, 0) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var durationPickerView: some View {
        VStack(spacing: 24) {
            Text("בחר זמן תרגול")
                .font(.system(size: 24, weight: .heavy))

            Picker("משך אימון", selection: $practiceDuration) {
                Text("3 דקות").tag(3)
                Text("5 דקות").tag(5)
                Text("10 דקות").tag(10)
                Text("15 דקות").tag(15)
            }
            .pickerStyle(.wheel)
            .frame(height: 160)

            Button {
                sessionStart = Date()
                completedCount = 0
                timeRemaining = practiceDuration * 60
                didPlayHalfTimeAlert = false
                lastBeepSecond = nil
                showDurationPicker = false
                playStartSound()
                startTimer()
                speakCurrentItem()
            } label: {
                Text("התחל אימון")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
    }

    private func startTimer() {
        stopTimer()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1

                let totalDuration = practiceDuration * 60
                let halfTimePoint = totalDuration / 2

                if !didPlayHalfTimeAlert && timeRemaining == halfTimePoint {
                    didPlayHalfTimeAlert = true
                    playHalfTimeAlert()
                }

                if timeRemaining <= 10, timeRemaining > 0 {
                    if lastBeepSecond != timeRemaining {
                        lastBeepSecond = timeRemaining
                        playCountdownBeep()
                    }
                }
            } else {
                stopTimer()
                stopSpeaking()
                playFinishSound()
                showSummary = true
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func speakCurrentItem() {
        guard !isMuted else { return }
        guard let item = currentItem else { return }
        guard !showDurationPicker else { return }

        stopSpeaking()

        let utterance = AVSpeechUtterance(string: item.displayName)
        utterance.voice = AVSpeechSynthesisVoice(language: "he-IL")
        utterance.rate = 0.45
        speechSynth.speak(utterance)
    }

    private func stopSpeaking() {
        speechSynth.stopSpeaking(at: .immediate)
    }

    private func playStartSound() {
        AudioServicesPlaySystemSound(1113)
    }

    private func playHalfTimeAlert() {
        AudioServicesPlaySystemSound(1016)
    }

    private func playCountdownBeep() {
        AudioServicesPlaySystemSound(1104)
    }

    private func playFinishSound() {
        AudioServicesPlaySystemSound(1005)
    }
}

private struct PracticeActionButton: View {
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

struct PracticeSummaryView: View {

    let duration: TimeInterval
    let totalExercises: Int
    let completedExercises: Int

    @State private var coachFeedback: String = ""

    private var minutes: Int {
        Int(duration) / 60
    }

    private var completionRate: Int {
        guard totalExercises > 0 else { return 0 }
        return Int((Double(completedExercises) / Double(totalExercises)) * 100)
    }

    var body: some View {
        VStack(spacing: 24) {

            Text("האימון הסתיים")
                .font(.system(size: 28, weight: .heavy))

            VStack(spacing: 12) {
                Text("משך אימון: \(minutes) דקות")
                Text("תרגילים בסשן: \(totalExercises)")
                Text("בוצעו: \(completedExercises)")

                Text("אחוז השלמה: \(completionRate)%")
                    .font(.system(size: 20, weight: .bold))

                Text("הערת מאמן")
                    .font(.system(size: 16, weight: .bold))
                    .padding(.top, 12)

                TextEditor(text: $coachFeedback)
                    .frame(height: 100)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3))
                    )

                Button {

                    let sessionData: [String: Any] = [
                        "duration": duration,
                        "totalExercises": totalExercises,
                        "completedExercises": completedExercises,
                        "completionRate": completionRate,
                        "coachFeedback": coachFeedback,
                        "date": Date().timeIntervalSince1970
                    ]

                    var sessions =
                        UserDefaults.standard.array(forKey: "practice_sessions") as? [[String: Any]] ?? []

                    sessions.append(sessionData)

                    UserDefaults.standard.set(sessions, forKey: "practice_sessions")

                    print("Practice session saved")

                } label: {
                    Text("שמור סיכום אימון")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 10)
            }

            Spacer()
        }
        .padding(30)
    }
}
