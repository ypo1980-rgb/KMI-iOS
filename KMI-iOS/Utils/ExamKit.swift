import SwiftUI
import AVFoundation
import Combine
import Shared

enum ExamDataSource {

    static func itemsForBelt(_ belt: Belt) -> [String] {
        let catalog = CatalogData.shared.data
        guard let beltContent = catalog[belt] else { return [] }

        var out: [String] = []

        for t in beltContent.topics {
            out.append(contentsOf: t.items)
            for st in t.subTopics {
                out.append(contentsOf: st.items)
            }
        }

        // unique keep order
        var seen = Set<String>()
        return out
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }
}

@MainActor
final class ExamTts: ObservableObject {

    private let synth = AVSpeechSynthesizer()

    func speak(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }

        synth.stopSpeaking(at: .immediate)

        let u = AVSpeechUtterance(string: t)
        u.rate = 0.48
        u.pitchMultiplier = 0.95
        u.voice = AVSpeechSynthesisVoice(language: "he-IL")

        synth.speak(u)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
    }
}

struct ExamRunnerView: View {

    let title: String
    let subtitle: String
    let items: [String]
    let accent: Color

    @StateObject private var tts = ExamTts()

    @State private var started: Bool = false
    @State private var isMuted: Bool = false
    @State private var currentIndex: Int = 0
    @State private var timeLeft: Int = 20

    @State private var timerTask: Task<Void, Never>? = nil

    private var total: Int { max(items.count, 1) }
    private var progress: Double { Double(currentIndex + 1) / Double(total) }

    var body: some View {
        ZStack {
            // רקע בהיר כמו באנדרואיד
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.95, blue: 1.00),
                    Color(red: 0.93, green: 0.90, blue: 1.00),
                    Color(red: 0.89, green: 0.95, blue: 1.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if items.isEmpty {
                VStack(spacing: 10) {
                    Text("אין תרגילים זמינים")
                        .font(.title3.weight(.heavy))
                    Text("לא נמצאו פריטים בחגורה הזו")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else {
                ScrollView {
                    VStack(spacing: 14) {

                        // כרטיס סטטוס עליון
                        VStack(spacing: 12) {

                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(title)
                                        .font(.headline.weight(.heavy))
                                        .foregroundStyle(Color.black.opacity(0.85))
                                    Text(subtitle)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.black.opacity(0.55))
                                }

                                Spacer()

                                // טיימר
                                Text(String(format: "%02d", timeLeft))
                                    .font(.title3.weight(.heavy))
                                    .foregroundStyle(accent)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(accent.opacity(0.12))
                                    )
                            }

                            ProgressView(value: progress)
                                .tint(accent)
                                .scaleEffect(x: 1, y: 2.0, anchor: .center)

                            HStack {
                                Text("תרגיל \(currentIndex + 1) מתוך \(items.count)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.black.opacity(0.55))
                                Spacer()
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(accent.opacity(0.18))
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                        // כרטיס שאלה
                        VStack(spacing: 16) {

                            Text(items[currentIndex])
                                .font(.system(size: 22, weight: .heavy))
                                .foregroundStyle(Color.black.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)

                            HStack(spacing: 12) {

                                Button {
                                    isMuted.toggle()
                                    if isMuted { tts.stop() }
                                    else { tts.speak(items[currentIndex]) }
                                } label: {
                                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(accent)
                                        .frame(width: 50, height: 50)
                                        .background(
                                            Circle().fill(Color.white)
                                        )
                                        .shadow(radius: 6, y: 2)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    skip()
                                } label: {
                                    Text("דלג")
                                        .font(.system(size: 18, weight: .heavy))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(accent)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.white.opacity(0.92))
                        )
                        .shadow(radius: 6, y: 2)
                        .padding(.horizontal, 16)

                        // סיום
                        Button {
                            stopAll()
                        } label: {
                            Text("סיום מבחן")
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundStyle(Color.black.opacity(0.82))
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color(red: 0.93, green: 0.93, blue: 0.93))
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .onAppear {
            startIfNeeded()
        }
        .onChange(of: currentIndex) { _, _ in
            onExerciseChanged()
        }
        .onDisappear {
            stopAll()
        }
    }

    private func startIfNeeded() {
        guard !started else { return }
        started = true
        currentIndex = 0
        timeLeft = 20
        onExerciseChanged()
        startTimerLoop()
    }

    private func onExerciseChanged() {
        timeLeft = 20
        if !isMuted {
            tts.speak(items[currentIndex])
        }
    }

    private func startTimerLoop() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                if items.isEmpty { continue }

                if timeLeft > 0 {
                    timeLeft -= 1
                }

                if timeLeft == 0 {
                    await MainActor.run { advanceIfPossible() }
                }
            }
        }
    }

    private func advanceIfPossible() {
        if currentIndex < items.count - 1 {
            currentIndex += 1
        }
    }

    private func skip() {
        tts.stop()
        advanceIfPossible()
    }

    private func stopAll() {
        tts.stop()
        timerTask?.cancel()
        timerTask = nil
    }
}

private extension Belt {
    var accentColor: Color {
        switch self {
        case .white:  return Color.gray.opacity(0.55)
        case .yellow: return Color.green.opacity(0.78)
        case .orange: return Color.orange.opacity(0.90)
        case .green:  return Color.green.opacity(0.75)
        case .blue:   return Color.blue.opacity(0.82)
        case .brown:  return Color(red: 0.55, green: 0.34, blue: 0.23).opacity(0.85)
        case .black:  return Color.black.opacity(0.75)
        default:      return Color.blue.opacity(0.75)
        }
    }
}
