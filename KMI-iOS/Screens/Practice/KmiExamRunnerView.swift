import SwiftUI
import AVFoundation
import AudioToolbox

struct KmiExamRunnerView: View {

    let title: String
    let subtitle: String
    let items: [String]
    let accent: Color

    /// אופציונלי: אם רוצים לבצע פעולה מיוחדת בסיום (למשל nav.pop())
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

    private var total: Int { max(shuffledItems.count, 1) }

    private var progress: Double {
        guard !shuffledItems.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(total)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.95, blue: 1.0),
                    Color(red: 0.93, green: 0.96, blue: 1.0),
                    Color(red: 0.89, green: 0.95, blue: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if shuffledItems.isEmpty {
                VStack {
                    Spacer()

                    Text("אין תרגילים זמינים")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(Color.black.opacity(0.75))

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
            } else {
                VStack(spacing: 16) {

                    // כרטיס עליון – מצב המבחן
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(subtitle)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(Color.black.opacity(0.82))

                                Text("תרגיל \(currentIndex + 1) מתוך \(shuffledItems.count)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.gray)
                            }

                            Spacer()

                            Text(String(format: "%02d", timeLeft))
                                .font(.title3.weight(.heavy))
                                .foregroundStyle(accent)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.white.opacity(0.92))
                                )
                        }

                        ProgressView(value: progress)
                            .tint(accent)
                            .scaleEffect(x: 1, y: 1.3, anchor: .center)

                        HStack(spacing: 6) {
                            ForEach(Array(shuffledItems.indices), id: \.self) { idx in
                                RoundedRectangle(cornerRadius: 999, style: .continuous)
                                    .fill(
                                        idx == currentIndex
                                        ? AnyShapeStyle(accent)
                                        : AnyShapeStyle(accent.opacity(0.25))
                                    )
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
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    // כרטיס שאלה
                    VStack {
                        Spacer(minLength: 0)

                        if examStarted {
                            Text(shuffledItems[currentIndex])
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
                                    speakCurrentItem()
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
                    .padding(.horizontal, 16)

                    // כפתור סיום
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
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startExam()
        }
        .onDisappear {
            stopExamFlow()
        }
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
                    }

                    if timeLeft == 0 {
                        advanceAutomatically()
                    }
                }
            }
        }
    }
    
    private func playLetsGoAndBegin() {
        AudioServicesPlaySystemSound(1113)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)

            guard !shuffledItems.isEmpty else { return }

            examStarted = true
            isStartingCountdown = false
            isRunning = true
            speakCurrentItem()
        }
    }

    private func advanceAutomatically() {
        guard examStarted else { return }

        stopSpeaking()

        if currentIndex < shuffledItems.count - 1 {
            currentIndex += 1
            timeLeft = 20
            speakCurrentItem()
        } else {
            finish()
        }
    }

    private func skipToNext() {
        guard examStarted else { return }

        stopSpeaking()

        if currentIndex < shuffledItems.count - 1 {
            currentIndex += 1
            timeLeft = 20
            speakCurrentItem()
        }
    }

    private func speakCurrentItem() {
        guard !isMuted else { return }
        guard currentIndex >= 0, currentIndex < shuffledItems.count else { return }

        let utterance = AVSpeechUtterance(string: shuffledItems[currentIndex])
        utterance.voice = AVSpeechSynthesisVoice(language: "he-IL")
        utterance.rate = 0.45

        speechSynth.stopSpeaking(at: .immediate)
        speechSynth.speak(utterance)
    }

    private func stopSpeaking() {
        speechSynth.stopSpeaking(at: .immediate)
    }

    private func stopExamFlow() {
        isRunning = false
        examStarted = false
        isStartingCountdown = false
        timerTask?.cancel()
        timerTask = nil
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
