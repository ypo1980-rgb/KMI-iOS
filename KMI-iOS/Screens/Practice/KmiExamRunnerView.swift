import SwiftUI
import Shared
import AVFoundation
import AudioToolbox

struct KmiExamRunnerView: View {

    let belt: Belt
    let title: String
    let subtitle: String
    let items: [String]
    let accent: Color
    let onFinish: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("kmi_app_language") private var languageCode = "he"

    @State private var shuffledItems: [String]
    @State private var currentIndex: Int = 0
    @State private var timeLeft: Int = 20
    @State private var isRunning: Bool = false
    @State private var isMuted: Bool = false
    @State private var examStarted: Bool = false
    @State private var isStartingCountdown: Bool = false
    @State private var showHelp: Bool = false
    @State private var timerTask: Task<Void, Never>? = nil
    @State private var letsGoPlayer: AVAudioPlayer? = nil
    @State private var tickPlayer: AVAudioPlayer? = nil
    @State private var isExiting: Bool = false

    @State private var speechSynth =
        AVSpeechSynthesizer()

    init(
        belt: Belt,
        title: String,
        subtitle: String,
        items: [String],
        accent: Color,
        onFinish: (() -> Void)? = nil
    ) {
        self.belt = belt
        self.title = title
        self.subtitle = subtitle
        self.items = items
        self.accent = accent
        self.onFinish = onFinish
        self._shuffledItems = State(
            initialValue: items.shuffled()
        )
    }

    private var isEnglish: Bool {
        let code = languageCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return code == "en" || code == "english"
    }

    private var currentItem: String {
        guard currentIndex >= 0,
              currentIndex < shuffledItems.count else {
            return ""
        }

        return shuffledItems[currentIndex]
    }

    private var currentDisplayItem: String {
        cleanExamItemForDisplay(currentItem)
    }

    private func cleanExamItemForDisplay(
        _ rawItem: String
    ) -> String {
        let clean = rawItem
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !clean.isEmpty else {
            return ""
        }

        if clean.contains("::") {
            let parts = clean
                .components(separatedBy: "::")
                .map {
                    $0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                }
                .filter { !$0.isEmpty }

            if let hebrewPart = parts.first(
                where: {
                    $0.range(
                        of: #"\p{Hebrew}"#,
                        options: .regularExpression
                    ) != nil
                }
            ) {
                return hebrewPart
            }

            return parts.last ?? clean
        }

        let lines = clean
            .components(separatedBy: .newlines)
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter { !$0.isEmpty }

        if lines.count > 1,
           lines[0].range(
                of: #"^[A-Za-z0-9_:\-]+$"#,
                options: .regularExpression
           ) != nil {
            return lines
                .dropFirst()
                .joined(separator: " ")
        }

        return clean.replacingOccurrences(
            of: #"^[A-Za-z0-9_:\-]{2,}\s+"#,
            with: "",
            options: .regularExpression
        )
    }

    private var timerColor: Color {
        KmiAppTheme.onSurfaceVariant(for: colorScheme)
    }

    private var isLastFiveSeconds: Bool {
        examStarted &&
            timeLeft > 0 &&
            timeLeft <= 5
    }

    private var isExamCompleted: Bool {
        examStarted &&
            !isRunning &&
            timeLeft == 0 &&
            currentIndex == shuffledItems.count - 1
    }

    private var canSkip: Bool {
        examStarted &&
            currentIndex < shuffledItems.count - 1
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: KmiAppTheme.screenBackgroundColors(for: colorScheme),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if shuffledItems.isEmpty {
                emptyState
            } else {
                VStack(spacing: 16) {
                    topStatusCard
                    questionCard
                    finishButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
        .navigationBarBackButtonHidden(true)
        .toolbar(
            .hidden,
            for: .navigationBar
        )
        .onAppear {
            isExiting = false
            startExam()
        }
        .onDisappear {
            stopExamFlow()
        }
        .sheet(isPresented: $showHelp) {
            KmiExamHelpSheet(
                belt: belt,
                rawItem: currentItem,
                displayItem: currentDisplayItem,
                accent: accent,
                isEnglish: isEnglish,
                onClose: {
                    showHelp = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()

            Image(systemName: "exclamationmark.circle")
                .kmiIconSize(34)
                .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
                .accessibilityHidden(true)

            Text(isEnglish ? "No exercises available" : "אין תרגילים זמינים")
                .kmiTypography(.body)
                .fontWeight(.heavy)
                .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.top, 8)

            Spacer()

            finishButton
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
        }
    }

    private var topStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subtitle)
                        .kmiTypography(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))

                    Text(
                        isEnglish
                            ? "Exercise \(min(currentIndex + 1, shuffledItems.count)) of \(shuffledItems.count)"
                            : "תרגיל \(min(currentIndex + 1, shuffledItems.count)) מתוך \(shuffledItems.count)"
                    )
                    .kmiTypography(.secondary)
                    .fontWeight(.semibold)
                    .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
                }

                Spacer()

                Text(String(format: "%02d", timeLeft))
                    .kmiFont(size: 20, weight: .heavy)
                    .monospacedDigit()
                    .foregroundStyle(timerColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        KmiAppTheme.surfaceVariant(for: colorScheme),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .scaleEffect(
                        isLastFiveSeconds
                        ? 1.18
                        : 1.0
                    )
                    .animation(
                        .easeInOut(duration: 0.25),
                        value: timeLeft
                    )
            }

            PracticeExerciseProgressDots(
                beltColor: accent,
                currentIndex: currentIndex,
                totalCount: shuffledItems.count,
                isEnglish: isEnglish
            )
            .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
        }
        .padding(16)
        .background(
            KmiAppTheme.surface(for: colorScheme),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    KmiAppTheme.outlineVariant(for: colorScheme),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        }
    }

    private var questionCard: some View {
        VStack {
            Spacer(minLength: 0)

            if isExamCompleted {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(accent)

                    Text(isEnglish ? "Exam complete" : "המבחן הסתיים")
                        .kmiFont(size: 26, weight: .black)
                        .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))

                    Text(
                        isEnglish
                            ? "You went through all the exam exercises"
                            : "עברת על כל תרגילי המבחן"
                    )
                    .kmiTypography(.secondary)
                    .fontWeight(.semibold)
                    .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
                }
                .frame(maxWidth: .infinity)
            } else if examStarted {
                Text(KmiEnglishTitleResolver.title(
                    for: currentDisplayItem,
                    isEnglish: isEnglish
                ))
                .kmiFont(size: 22, weight: .bold)
                .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)
            } else {
                VStack(spacing: 12) {
                    Text(isEnglish ? "The exam is starting" : "המבחן מתחיל")
                        .kmiFont(size: 26, weight: .bold)
                        .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
                        .multilineTextAlignment(.center)

                    Text(
                        isStartingCountdown
                            ? (isEnglish ? "Get ready..." : "התכונן...")
                            : (isEnglish ? "Loading exam..." : "טוען מבחן...")
                    )
                    .kmiTypography(.secondary)
                    .fontWeight(.semibold)
                    .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
                    .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button {
                    isMuted.toggle()

                    if isMuted {
                        stopSpeaking()
                    } else if examStarted {
                        speakCurrentItem(afterDelay: true)
                    }
                } label: {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .kmiIconSize(20)
                        .fontWeight(.bold)
                        .foregroundStyle(KmiAppTheme.onSecondaryContainer(for: colorScheme))
                        .frame(width: 50, height: 50)
                        .background(KmiAppTheme.secondaryContainer(for: colorScheme), in: Circle())
                        .accessibilityLabel(Text(
                            isMuted
                                ? (isEnglish ? "Unmute" : "הפעל שמע")
                                : (isEnglish ? "Mute" : "השתק")
                        ))
                }
                .buttonStyle(.plain)
                .disabled(!examStarted)

                Button {
                    guard examStarted else { return }
                    showHelp = true
                } label: {
                    Text(isEnglish ? "Help" : "עזרה")
                        .kmiTypography(.action)
                        .fontWeight(.heavy)
                        .foregroundStyle(KmiAppTheme.onSecondaryContainer(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(minHeight: 48)
                        .background(
                            KmiAppTheme.secondaryContainer(for: colorScheme),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .disabled(
                    !examStarted ||
                    isExamCompleted
                )
                .opacity(
                    examStarted && !isExamCompleted
                    ? 1
                    : 0.55
                )

                Button {
                    skipToNext()
                } label: {
                    Text(isEnglish ? "Skip" : "דלג")
                        .kmiTypography(.action)
                        .fontWeight(.heavy)
                        .foregroundStyle(KmiAppTheme.onPrimary(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            KmiAppTheme.primary(for: colorScheme),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSkip)
                .opacity(canSkip ? 1 : 0.55)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .background(
            KmiAppTheme.surface(for: colorScheme),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(KmiAppTheme.outlineVariant(for: colorScheme), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .contentShape(
            RoundedRectangle(
                cornerRadius: 26,
                style: .continuous
            )
        )
        .onTapGesture {
            guard examStarted,
                  !isExamCompleted else {
                return
            }

            showHelp = true
        }
    }

    private var finishButton: some View {
        Button(action: finish) {
            Text(isEnglish ? "Finish exam" : "סיום מבחן")
                .kmiTypography(.action)
                .fontWeight(.heavy)
                .foregroundStyle(KmiAppTheme.onPrimaryContainer(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    KmiAppTheme.primaryContainer(for: colorScheme),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }

    private func startExam() {
        guard !shuffledItems.isEmpty else { return }

        currentIndex = 0
        timeLeft = 20
        isRunning = false
        examStarted = false
        isStartingCountdown = true

        startTimerLoop()
        playLetsGoAndBegin()
    }

    private func startTimerLoop() {
        timerTask?.cancel()

        timerTask = Task {
            while !Task.isCancelled {
                if !isRunning {
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    continue
                }

                try? await Task.sleep(nanoseconds: 1_000_000_000)

                if Task.isCancelled { break }
                if !isRunning { continue }

                await MainActor.run {
                    if timeLeft > 0 {
                        timeLeft -= 1

                        if timeLeft <= 5 {
                            let generator = UIImpactFeedbackGenerator(style: .rigid)
                            generator.impactOccurred()

                            playTick()
                        }
                    }
                    
                    if timeLeft == 0 {
                        advanceAutomatically()
                    }
                }
            }
        }
    }

    private func playLetsGoAndBegin() {
        stopLetsGoSound()

        if let url = Bundle.main.url(forResource: "letsgo", withExtension: "mp3") ??
            Bundle.main.url(forResource: "letsgo", withExtension: "wav") ??
            Bundle.main.url(forResource: "letsgo", withExtension: "m4a") {

            do {
                let player = try AVAudioPlayer(contentsOf: url)
                letsGoPlayer = player
                player.prepareToPlay()
                player.play()

                DispatchQueue.main.asyncAfter(
                    deadline: .now() + player.duration
                ) {
                    guard !isExiting else { return }
                    beginExamNow()
                }
                return
            } catch {
                AudioServicesPlaySystemSound(1113)
            }
        } else {
            AudioServicesPlaySystemSound(1113)
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 1.2
        ) {
            guard !isExiting else { return }
            beginExamNow()
        }
    }

    private func beginExamNow() {
        guard !isExiting,
              !shuffledItems.isEmpty else {
            return
        }

        examStarted = true
        isStartingCountdown = false
        isRunning = true
        timeLeft = 20
        speakCurrentItem(afterDelay: true)
    }

    private func advanceAutomatically() {
        guard !isExiting,
              examStarted else {
            return
        }

        stopSpeaking()

        let generator =
            UIImpactFeedbackGenerator(
                style: .light
            )
        generator.impactOccurred()

        if currentIndex < shuffledItems.count - 1 {
            currentIndex += 1
            timeLeft = 20
            speakCurrentItem(afterDelay: true)
        } else {
            isRunning = false
            timeLeft = 0
            stopTickSound()
        }
    }
    
    private func skipToNext() {
        guard examStarted else { return }

        stopSpeaking()

        // ⭐️ רטט קטן
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if currentIndex < shuffledItems.count - 1 {
            currentIndex += 1
            timeLeft = 20
            speakCurrentItem(afterDelay: true)
        }
    }
    
    private func speakCurrentItem(
        afterDelay: Bool = false
    ) {
        guard !isExiting,
              !isMuted,
              currentIndex >= 0,
              currentIndex < shuffledItems.count else {
            return
        }

        let requestedIndex = currentIndex
        let text = KmiEnglishTitleResolver.title(
            for: currentDisplayItem,
            isEnglish: isEnglish
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else { return }

        let speakAction = {
            guard !isExiting,
                  !isMuted,
                  examStarted,
                  currentIndex == requestedIndex else {
                return
            }

            let utterance =
                AVSpeechUtterance(
                    string: text
                )

            let containsHebrew = text.range(
                of: #"\p{Hebrew}"#,
                options: .regularExpression
            ) != nil

            utterance.voice = AVSpeechSynthesisVoice(
                language: isEnglish && !containsHebrew ? "en-US" : "he-IL"
            )
            utterance.rate = 0.45

            speechSynth.stopSpeaking(
                at: .immediate
            )
            speechSynth.speak(utterance)
        }

        if afterDelay {
            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.3
            ) {
                speakAction()
            }
        } else {
            speakAction()
        }
    }

    private func stopSpeaking() {
        speechSynth.stopSpeaking(at: .immediate)
    }

    private func stopLetsGoSound() {
        letsGoPlayer?.stop()
        letsGoPlayer = nil
    }

    private func stopTickSound() {
        tickPlayer?.stop()
        tickPlayer = nil
    }

    private func playTick() {
        stopTickSound()

        if let url = Bundle.main.url(forResource: "tick", withExtension: "wav") ??
            Bundle.main.url(forResource: "tick", withExtension: "mp3") ??
            Bundle.main.url(forResource: "tick", withExtension: "m4a") {

            do {
                let player = try AVAudioPlayer(contentsOf: url)
                tickPlayer = player
                player.prepareToPlay()
                player.play()
            } catch {
                AudioServicesPlaySystemSound(1104)
            }
        } else {
            AudioServicesPlaySystemSound(1104)
        }
    }

    private func stopExamFlow() {
        isRunning = false
        examStarted = false
        isStartingCountdown = false
        showHelp = false
        timerTask?.cancel()
        timerTask = nil
        stopLetsGoSound()
        stopTickSound()
        stopSpeaking()
    }
    
    private func finish() {
        guard !isExiting else { return }

        isExiting = true
        stopExamFlow()

        if let onFinish {
            onFinish()
        } else {
            dismiss()
        }
    }
}

private struct KmiExamHelpSheet: View {
    @Environment(\.colorScheme) private var colorScheme

    let belt: Belt
    let rawItem: String
    let displayItem: String
    let accent: Color
    let isEnglish: Bool
    let onClose: () -> Void

    @State private var favoriteIds: Set<String> = {
        Set(
            UserDefaults.standard.stringArray(
                forKey: "practice_favorites"
            ) ?? []
        )
    }()

    private var favoriteId: String {
        rawItem
            .components(separatedBy: "::")
            .last?
            .components(separatedBy: ":")
            .last?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? displayItem
    }

    private var isFavorite: Bool {
        favoriteIds.contains(favoriteId)
    }

    private func toggleFavorite() {
        guard !favoriteId.isEmpty else { return }

        if favoriteIds.contains(favoriteId) {
            favoriteIds.remove(favoriteId)
        } else {
            favoriteIds.insert(favoriteId)
        }

        UserDefaults.standard.set(
            Array(favoriteIds).sorted(),
            forKey: "practice_favorites"
        )
    }

    private var explanation: String {
        let resolved = KmiExerciseExplanationResolverIOS
            .shared
            .get(
                belt: belt,
                topic: "",
                item: rawItem,
                isEnglish: isEnglish
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        if !resolved.isEmpty {
            return resolved
        }

        let fallback = KmiExerciseExplanationResolverIOS
            .shared
            .get(
                belt: belt,
                topic: "",
                item: displayItem,
                isEnglish: isEnglish
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return fallback.isEmpty
            ? (isEnglish ? "No explanation is available for this exercise." : "אין כרגע הסבר לתרגיל הזה.")
            : fallback
    }

    var body: some View {
        ZStack {
            KmiAppTheme.surface(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(
                                .system(
                                    size: 14,
                                    weight: .black
                                )
                            )
                            .foregroundStyle(
                                Color.black.opacity(0.68)
                            )
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.94))
                            )
                    }
                    .buttonStyle(.plain)

                    Text(KmiEnglishTitleResolver.title(
                        for: displayItem,
                        isEnglish: isEnglish
                    ))
                    .kmiFont(size: 20, weight: .black)
                    .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        toggleFavorite()
                    } label: {
                        Image(
                            systemName:
                                isFavorite
                                ? "star.fill"
                                : "star"
                        )
                        .font(
                            .system(
                                size: 18,
                                weight: .black
                            )
                        )
                        .foregroundStyle(
                            isFavorite
                            ? Color.orange
                            : Color.gray
                        )
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.94))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(
                        isFavorite
                            ? (isEnglish ? "Remove from favorites" : "הסר ממועדפים")
                            : (isEnglish ? "Add to favorites" : "הוסף למועדפים")
                    ))
                }

                Text("חגורה \(belt.heb)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .trailing
                    )

                ScrollView {
                    Text(explanation)
                        .kmiTypography(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
                        .lineSpacing(5)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            KmiAppTheme.surfaceVariant(for: colorScheme),
                            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(
                                cornerRadius: 24,
                                style: .continuous
                            )
                            .stroke(
                                accent.opacity(0.18),
                                lineWidth: 1
                            )
                        )
                }

                Spacer(minLength: 0)
            }
            .padding(18)
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
    }
}
