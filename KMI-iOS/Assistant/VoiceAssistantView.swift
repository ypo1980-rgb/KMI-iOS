import SwiftUI
import Shared

// ✅ CONTENT-ONLY:
// המסך הזה נפתח מתוך ContentView שכבר עוטף אותו ב-KmiRootLayout.
// אסור לעטוף כאן שוב ב-KmiRootLayout, אחרת יופיעו פעמיים TopBar + IconStrip.
private struct EmptyAssistantTrainingDataSource: AssistantTrainingDataSource {
    func allTrainings() -> [TrainingRow] { [] }
}

struct VoiceAssistantView: View {
    @StateObject private var logic = AiAssistantLogic(
        searchEngine: AssistantSearchAdapter(),
        trainingDataSource: EmptyAssistantTrainingDataSource()
    )

    private let tts = AssistantTtsManager.shared

    @State private var inputText: String = ""
    @State private var isListening: Bool = false
    @State private var didIntroSpeak: Bool = false

    var body: some View {
        ZStack {
            KmiGradientBackground(forceTraineeStyle: false)

            VStack(spacing: 12) {
                headerCard
                    .padding(.top, 10)

                modePickerCard

                messagesCard

                inputBar
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .onAppear {
            guard !didIntroSpeak else { return }
            didIntroSpeak = true
            tts.speak("שלום, כאן יובל העוזר האישי שלך. אנא בחר נושא מתוך הרשימה שלפניך כדי שנוכל להתחיל")
        }
        .onDisappear {
            tts.stop()
        }
    }

    private var headerCard: some View {
        VStack(spacing: 8) {
            Text("יובל – העוזר האישי")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(.white)

            Text(subtitleForMode)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var subtitleForMode: String {
        switch logic.selectedMode ?? .exercise {
        case .exercise:
            return "מצב: מידע / הסבר על תרגיל"
        case .trainings:
            return "מצב: מידע על אימונים"
        case .kmiMaterial:
            return "מצב: חומר ק.מ.י"
        }
    }

    private var modePickerCard: some View {
        VStack(spacing: 10) {
            modeButton(title: "מידע על תרגיל", mode: .exercise)
            modeButton(title: "מידע על אימונים", mode: .trainings)
            modeButton(title: "חומר ק.מ.י", mode: .kmiMaterial)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.92))
        )
    }

    private func modeButton(title: String, mode: AssistantMode) -> some View {
        let isSelected = (logic.selectedMode ?? .exercise) == mode

        return Button {
            logic.setMode(mode)
            inputText = ""

            switch mode {
            case .exercise:
                tts.speak("אוקיי. אני מוכן להסביר על תרגילים. תשאל אותי שם של תרגיל ואני אגיד את ההסבר שלו.")
            case .trainings:
                tts.speak("אוקיי. עכשיו אני מוכן לתת מידע על אימונים.")
            case .kmiMaterial:
                tts.speak("מעולה. מצב חומר קמי פעיל. תגיד נושא או שם תרגיל ואני אחפש לך במאגר.")
            }
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(isSelected ? .white : Color.black.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? Color.purple.opacity(0.85) : Color.black.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
    }

    private var messagesCard: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    if logic.messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(logic.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }

                    if logic.isThinking {
                        HStack {
                            Spacer()
                            Text("חושב…")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                }
                .padding(12)
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .onChange(of: logic.messages.count) { _, _ in
                if let last = logic.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)

            Text(emptyText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    private var emptyText: String {
        switch logic.selectedMode ?? .exercise {
        case .exercise:
            return """
            אפשר לבקש הסבר לתרגיל.
            למשל:
            "תן הסבר לבעיטת מגל"
            """
        case .trainings:
            return """
            אפשר לשאול על אימונים.
            למשל:
            "מתי האימון הבא?"
            """
        case .kmiMaterial:
            return """
            אפשר לחפש בחומר ק.מ.י.
            למשל:
            "הגנות חיצוניות"
            """
        }
    }

    private func messageBubble(_ message: AiMessage) -> some View {
        HStack {
            if message.fromUser { Spacer() }

            Text(message.text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(message.fromUser ? .white : Color.black.opacity(0.82))
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(message.fromUser ? Color.purple.opacity(0.85) : Color.white.opacity(0.94))
                )
                .frame(maxWidth: 280, alignment: message.fromUser ? .trailing : .leading)

            if !message.fromUser { Spacer() }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            Button {
                isListening.toggle()
            } label: {
                Image(systemName: isListening ? "mic.circle.fill" : "mic.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(Color.white.opacity(isListening ? 0.30 : 0.18))
                    )
            }
            .buttonStyle(.plain)

            TextField("כתוב כאן שאלה…", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
                .onSubmit {
                    send()
                }

            Button {
                send()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.78))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(Color.white.opacity(0.94))
                    )
            }
            .buttonStyle(.plain)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
        }
    }

    private func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let answer = logic.sendQuestion(trimmed)
        inputText = ""

        let cleanAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanAnswer.isEmpty {
            tts.speak(cleanAnswer)
        }
    }
}
