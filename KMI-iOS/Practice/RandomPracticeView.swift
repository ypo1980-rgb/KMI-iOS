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

    // MARK: - Current item
    @State private var currentItem: String? = nil

    // MARK: - Weighting
    @State private var dontKnow: Set<String> = []

    // MARK: - Audio
    @State private var isMuted: Bool = false
    private let speaker = AVSpeechSynthesizer()

    // MARK: - Sheets
    @State private var showDurationSheet: Bool = true
    @State private var showExplanationSheet: Bool = false

    private var beltColor: Color { KmiBeltPalette.color(for: belt) }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
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

    private func weightedPool() -> [String] {
        let base = cleanItems(items)
        guard !base.isEmpty else { return [] }

        var pool: [String] = []
        pool.reserveCapacity(base.count * 2)

        for it in base {
            pool.append(it)
            if dontKnow.contains(it) {
                pool.append(it)
                pool.append(it)
            }
        }
        return pool
    }

    private func pickNextItem() {
        let pool = weightedPool()
        currentItem = pool.randomElement()
        if let currentItem { speak(currentItem) }
    }

    private func resetTimer() {
        timeLeft = max(60, durationMinutes * 60)
        halfAnnounced = false
    }

    private func startSession() {
        sessionStarted = true
        isRunning = true
        resetTimer()
        pickNextItem()
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
                let total = max(60, durationMinutes * 60)
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
            pickNextItem()
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

                    // Current exercise card (tap => explanation)
                    WhiteCard {
                        VStack(spacing: 10) {
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

                    // Actions
                    HStack(spacing: 12) {

                        Button {
                            pickNextItem()
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
                            if let it = currentItem { dontKnow.insert(it) }
                            pickNextItem()
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

                    Spacer()

                    // Finish
                    Button {
                        stopSession()
                        dismiss() // ✅ הכי נכון ל-Sheet
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
                // בכל פתיחה: קודם Bottom Sheet חלקי לבחירה
                showDurationSheet = true
                sessionStarted = false
                isRunning = false
                currentItem = nil
                resetTimer()
            }
            // ✅ Bottom sheet חלקי כמו בתמונה
            .sheet(isPresented: $showDurationSheet) {
                PracticeDurationPickerSheet(
                    belt: belt,
                    selectedMinutes: $durationMinutes,
                    alertHalfTime: $alertHalfTime,
                    beepLast10: $beepLast10,
                    onStart: {
                        showDurationSheet = false
                        startSession()
                    },
                    onCancel: {
                        showDurationSheet = false
                        dismiss()
                    }
                )
                .presentationDetents([.fraction(0.46)])
                .presentationDragIndicator(.visible)
            }
            // ✅ Explanation Sheet (שדרוג #3)
            .sheet(isPresented: $showExplanationSheet) {
                PracticeExplanationSheet(
                    belt: belt,
                    itemTitle: currentItem ?? "",
                    onClose: { showExplanationSheet = false }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
        VStack(spacing: 14) {

            Text("בחר זמן תרגול")
                .font(.title2.weight(.heavy))
                .foregroundStyle(Color.black.opacity(0.85))
                .padding(.top, 10)

            Text(String(format: "%02d:00", selectedMinutes))
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(beltColor)
                .padding(.bottom, 2)

            // Segments 1/3/5
            HStack(spacing: 10) {
                ForEach(options, id: \.self) { m in
                    let isSel = (m == selectedMinutes)
                    Button { selectedMinutes = m } label: {
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

            // Toggles
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

            // Buttons
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

// MARK: - Explanation Sheet (placeholder for now)

private struct PracticeExplanationSheet: View {

    let belt: Belt
    let itemTitle: String
    let onClose: () -> Void

    private var beltColor: Color { KmiBeltPalette.color(for: belt) }

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

                // spacer for symmetry
                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            WhiteCard {
                VStack(alignment: .trailing, spacing: 10) {
                    Text("הסבר לתרגיל")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.85))

                    Text("בקרוב נוסיף כאן את ההסבר מתוך קובץ ההסברים.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.65))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 14)
            }
            .padding(.horizontal, 16)

            Spacer()
        }
    }
}
