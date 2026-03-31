import SwiftUI
import AVFoundation
import AudioToolbox

struct KmiExamRunnerView: View {

    let title: String
    let subtitle: String
    let items: [String]
    let accent: Color
    let onFinish: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var shuffledItems: [String]
    @State private var currentIndex: Int = 0
    @State private var timeLeft: Int = 20
    @State private var isRunning: Bool = false
    @State private var isMuted: Bool = false
    @State private var examStarted: Bool = false
    @State private var isStartingCountdown: Bool = false
    @State private var timerTask: Task<Void, Never>? = nil
    @State private var letsGoPlayer: AVAudioPlayer? = nil
    @State private var tickPlayer: AVAudioPlayer? = nil
    @State private var showLetsGo = true
    
    private let speechSynth = AVSpeechSynthesizer()

    init(
        title: String,
        subtitle: String,
        items: [String],
        accent: Color,
        onFinish: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.items = items
        self.accent = accent
        self.onFinish = onFinish
        self._shuffledItems = State(initialValue: items.shuffled())
    }

    private var total: Int {
        max(shuffledItems.count, 1)
    }

    private var progress: Double {
        guard !shuffledItems.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(total)
    }

    private var currentItem: String {
        guard currentIndex >= 0, currentIndex < shuffledItems.count else {
            return ""
        }
        return shuffledItems[currentIndex]
    }

    private var timerColor: Color {
        switch timeLeft {
        case 11...20:
            return .green
        case 6...10:
            return .orange
        default:
            return .red
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.95, blue: 1.00),
                    Color(red: 0.93, green: 0.89, blue: 1.00),
                    Color(red: 0.89, green: 0.95, blue: 1.00)
                ],
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
        .navigationTitle(title)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    finish()
                } label: {
                    Image(systemName: "chevron.backward")
                }
            }
        }
        .onAppear {
            startExam()
        }
        .onDisappear {
            stopExamFlow()
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()

            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("אין תרגילים זמינים")
                .font(.title3.weight(.heavy))
                .foregroundStyle(Color.black.opacity(0.75))
                .padding(.top, 8)

            Spacer()

            Button {
                finish()
            } label: {
                Text("סיום מבחן")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Color.black.opacity(0.78))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.88))
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    private var topStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subtitle)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.black.opacity(0.82))

                    Text("תרגיל \(min(currentIndex + 1, shuffledItems.count)) מתוך \(shuffledItems.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.gray)
                }

                Spacer()

                Text(String(format: "%02d", timeLeft))
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(timerColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.92))
                    )
                    .scaleEffect(timeLeft <= 5 ? 1.25 : 1.0)
                    .animation(.easeInOut(duration: 0.25), value: timeLeft)
            }

            ProgressView(value: progress)
                .tint(accent)
                .scaleEffect(x: 1, y: 1.3, anchor: .center)
                .animation(.easeInOut(duration: 0.25), value: progress)
            
            HStack(spacing: 6) {
                ForEach(Array(shuffledItems.indices), id: \.self) { idx in
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(idx == currentIndex ? accent : accent.opacity(0.25))
                        .frame(maxWidth: .infinity)
                        .frame(height: 6)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(accent.opacity(0.10))
        )
    }

    private var questionCard: some View {
        VStack {
            Spacer(minLength: 0)

            if examStarted {
                Text(currentItem)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.84))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)
            } else {
                VStack(spacing: 12) {
                    Text("המבחן מתחיל")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.82))

                    Text(isStartingCountdown ? "התכונן..." : "טוען מבחן...")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.gray)
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
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(accent)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle().fill(Color.white)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!examStarted)

                Button {
                    skipToNext()
                } label: {
                    Text("דלג")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(accent.opacity(0.92))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!examStarted)
                .opacity(examStarted ? 1 : 0.55)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white)
        )
    }

    private var finishButton: some View {
        Button {
            finish()
        } label: {
            Text("סיום מבחן")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Color.black.opacity(0.78))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.90))
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

                DispatchQueue.main.asyncAfter(deadline: .now() + player.duration) {
                    beginExamNow()
                }
                return
            } catch {
                AudioServicesPlaySystemSound(1113)
            }
        } else {
            AudioServicesPlaySystemSound(1113)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            beginExamNow()
        }
    }

    private func beginExamNow() {
        guard !shuffledItems.isEmpty else { return }

        examStarted = true
        isStartingCountdown = false
        isRunning = true
        timeLeft = 20
        speakCurrentItem(afterDelay: true)
    }

    private func advanceAutomatically() {
        guard examStarted else { return }

        stopSpeaking()

        // ⭐️ רטט קטן במעבר שאלה
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if currentIndex < shuffledItems.count - 1 {
            currentIndex += 1
            timeLeft = 20
            speakCurrentItem(afterDelay: true)
        } else {
            finish()
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
    
    private func speakCurrentItem(afterDelay: Bool = false) {
        guard !isMuted else { return }
        guard currentIndex >= 0, currentIndex < shuffledItems.count else { return }

        let text = shuffledItems[currentIndex]
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let speakAction = {
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "he-IL")
            utterance.rate = 0.45
            speechSynth.stopSpeaking(at: .immediate)
            speechSynth.speak(utterance)
        }

        if afterDelay {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
        timerTask?.cancel()
        timerTask = nil
        stopLetsGoSound()
        stopTickSound()
        stopSpeaking()
    }
    
    private func finish() {
        stopExamFlow()

        if let onFinish {
            onFinish()
        } else {
            dismiss()
        }
    }
}
