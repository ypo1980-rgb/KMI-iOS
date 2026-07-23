import SwiftUI
import Shared

// ✅ CONTENT-ONLY:
// המסך הזה נפתח מתוך ContentView שכבר עוטף אותו ב-KmiRootLayout.
// אסור לעטוף כאן שוב ב-KmiRootLayout, אחרת יופיעו פעמיים TopBar + IconStrip.
struct VoiceAssistantView: View {
    @StateObject private var logic = AiAssistantLogic(
        searchEngine: AssistantSearchAdapter(),
        trainingDataSource:
            CurrentUserAssistantTrainingDataSource()
    )

    @StateObject private var speechRecognizer =
        KmiSpeechRecognizer()

    @AppStorage("kmi_app_language")
    private var kmiAppLanguageCode: String = "he"

    @AppStorage("selected_language_code")
    private var selectedLanguageCode: String = "he"

    private let tts = AssistantTtsManager.shared

    @State private var inputText: String = ""
    @State private var didIntroSpeak: Bool = false
    @State private var lastAutomaticallySubmittedText: String = ""

    private var isEnglish: Bool {
        let languageValues = [
            kmiAppLanguageCode,
            selectedLanguageCode
        ]
        .map {
            $0.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()
        }

        return languageValues.contains("en") ||
            languageValues.contains("english")
    }

    private var speechLocaleIdentifier: String {
        isEnglish ? "en-US" : "he-IL"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.985, green: 0.985, blue: 1.0),
                    Color(red: 0.925, green: 0.945, blue: 1.0),
                    Color.white
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {
                headerCard
                    .padding(.top, 4)

                if logic.selectedMode == nil {
                    modePickerCard
                }

                messagesCard

                if logic.selectedMode != nil {
                    inputBar
                        .padding(.bottom, 4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
            .animation(
                .easeInOut(duration: 0.25),
                value: logic.selectedMode
            )
        }
        .onAppear {
            guard !didIntroSpeak else { return }
            didIntroSpeak = true
            tts.speak(
                tr(
                    "שלום, כאן יובל העוזר האישי שלך. בחר נושא כדי שנוכל להתחיל.",
                    "Hello, this is Yuval, your personal assistant. Choose a topic to begin."
                )
            )
        }
        .onChange(
            of: speechRecognizer.transcript
        ) { _, newTranscript in
            inputText = newTranscript
        }
        .onDisappear {
            tts.stop()
            speechRecognizer.cancelListening()
        }
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            if logic.selectedMode != nil {
                Button {
                    returnToAssistantHome()
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.16))
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    Color.white.opacity(0.30),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    tr(
                        "החלף נושא",
                        "Change topic"
                    )
                )
            } else {
                Color.clear
                    .frame(width: 42, height: 42)
            }

            Spacer(minLength: 4)

            Text(subtitleForMode)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Spacer(minLength: 4)

            Image(systemName: "wand.and.stars")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color.white.opacity(0.16))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(Color.white.opacity(0.34), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.34, green: 0.20, blue: 0.96),
                    Color(red: 0.55, green: 0.22, blue: 0.96),
                    Color(red: 0.08, green: 0.43, blue: 0.95)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .shadow(
            color: Color.blue.opacity(0.24),
            radius: 7,
            x: 0,
            y: 4
        )
    }

    private var subtitleForMode: String {
        guard let selectedMode =
                logic.selectedMode else {
            return tr(
                "בחר נושא כדי להתחיל",
                "Choose a topic to begin"
            )
        }

        switch selectedMode {
        case .exercise:
            return tr(
                "מצב: מידע / הסבר על תרגיל",
                "Mode: Exercise information / explanation"
            )

        case .trainings:
            return tr(
                "מצב: מידע על אימונים",
                "Mode: Training information"
            )

        case .kmiMaterial:
            return tr(
                "מצב: חומר ק.מ.י",
                "Mode: KMI material"
            )
        }
    }

    private var modePickerCard: some View {
        VStack(spacing: 12) {
            modeButton(
                title: tr("מידע על תרגיל", "Exercise information"),
                icon: "figure.martial.arts",
                mode: .exercise
            )
            modeButton(
                title: tr("מידע על אימונים", "Training information"),
                icon: "calendar",
                mode: .trainings
            )
            modeButton(
                title: tr("חומר ק.מ.י", "KMI material"),
                icon: "book.closed.fill",
                mode: .kmiMaterial
            )
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.98))
        )
        .shadow(
            color: Color.black.opacity(0.17),
            radius: 11,
            x: 0,
            y: 5
        )
    }

    private func modeButton(
        title: String,
        icon: String,
        mode: AssistantMode
    ) -> some View {
        let isSelected =
            logic.selectedMode == mode

        return Button {
            logic.setMode(mode)
            inputText = ""
            lastAutomaticallySubmittedText = ""
            speechRecognizer.cancelListening()
            tts.stop()

            switch mode {
            case .exercise:
                tts.speak(
                    tr(
                        "אוקיי. אני מוכן להסביר על תרגילים. אמור את שם התרגיל.",
                        "Okay. I am ready to explain exercises. Say the exercise name."
                    )
                )
            case .trainings:
                tts.speak(
                    tr(
                        "אוקיי. עכשיו אני מוכן לתת מידע על אימונים.",
                        "Okay. I am ready to provide training information."
                    )
                )
            case .kmiMaterial:
                tts.speak(
                    tr(
                        "מעולה. מצב חומר קמי פעיל. אמור נושא או שם תרגיל.",
                        "Great. KMI material mode is active. Say a topic or exercise name."
                    )
                )
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(
                        isSelected
                        ? .white
                        : Color(red: 0.43, green: 0.25, blue: 0.95)
                    )
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                isSelected
                                ? Color.white.opacity(0.17)
                                : Color(red: 0.95, green: 0.92, blue: 1.0)
                            )
                    )

                Text(title)
                    .font(.system(size: 19, weight: .heavy))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .environment(\.layoutDirection, .rightToLeft)
            .foregroundStyle(
                isSelected
                ? .white
                : Color(red: 0.10, green: 0.12, blue: 0.19)
            )
            .padding(.horizontal, 16)
            .frame(height: 72)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        isSelected
                        ? LinearGradient(
                            colors: [
                                Color(red: 0.49, green: 0.30, blue: 0.96),
                                Color(red: 0.37, green: 0.24, blue: 0.78)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [
                                Color.white,
                                Color(red: 0.97, green: 0.97, blue: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        isSelected
                        ? Color.white.opacity(0.20)
                        : Color(red: 0.80, green: 0.77, blue: 0.91),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(isSelected ? 0.12 : 0.15),
                radius: 7,
                x: 0,
                y: 4
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
                            Text(tr("חושב…", "Thinking…"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
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
        VStack(spacing: 12) {
            if logic.selectedMode == nil {
                assistantLogo
                    .frame(width: 108, height: 108)
                    .accessibilityLabel(
                        tr("לוגו ק.מ.י", "KMI logo")
                    )
            } else {
                Image(systemName: "sparkles")
                    .font(
                        .system(
                            size: 24,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        Color(red: 0.43, green: 0.25, blue: 0.95)
                    )
            }

            Text(emptyText)
                .font(
                    .system(
                        size: 15,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    Color(red: 0.25, green: 0.22, blue: 0.42)
                )
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)

            if !suggestedQuestions.isEmpty {
                VStack(spacing: 8) {
                    ForEach(
                        suggestedQuestions,
                        id: \.self
                    ) { question in
                        Button {
                            send(question)
                        } label: {
                            HStack(spacing: 8) {
                                Image(
                                    systemName:
                                        "sparkle.magnifyingglass"
                                )
                                .font(
                                    .system(
                                        size: 12,
                                        weight: .bold
                                    )
                                )

                                Text(question)
                                    .font(
                                        .system(
                                            size: 13,
                                            weight: .bold
                                        )
                                    )
                                    .lineLimit(2)
                                    .multilineTextAlignment(
                                        .center
                                    )
                            }
                            .foregroundStyle(
                                Color.purple.opacity(0.90)
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: 13,
                                    style: .continuous
                                )
                                .fill(
                                    Color.white.opacity(0.94)
                                )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: 430)
                .padding(.top, 4)
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: logic.selectedMode == nil ? 190 : 220
        )
    }

    private var assistantLogo: some View {
        Image("kami_logo")
            .interpolation(.high)
            .resizable()
            .scaledToFit()
    }

    private var suggestedQuestions: [String] {
        guard let selectedMode =
                logic.selectedMode else {
            return []
        }

        switch selectedMode {
        case .exercise:
            return [
                tr(
                    "תן הסבר על בעיטת מגל",
                    "Explain a roundhouse kick"
                ),
                tr(
                    "הסבר הגנה מאיום סכין",
                    "Explain a knife-threat defense"
                )
            ]

        case .trainings:
            return [
                tr(
                    "מתי האימון הבא?",
                    "When is my next training?"
                ),
                tr(
                    "איפה מתקיים האימון?",
                    "Where is the training?"
                )
            ]

        case .kmiMaterial:
            return [
                tr(
                    "תן רשימה של הגנות חיצוניות",
                    "List external defenses"
                ),
                tr(
                    "תן רשימה של תרגילי בעיטות",
                    "List kicking exercises"
                )
            ]
        }
    }

    private var emptyText: String {
        guard let selectedMode =
                logic.selectedMode else {
            return tr(
                """
                בחר אחד משלושת הנושאים למעלה.

                לאחר הבחירה אפשר לכתוב שאלה או להשתמש במיקרופון.
                """,
                """
                Choose one of the three topics above.

                After choosing, type a question or use the microphone.
                """
            )
        }

        switch selectedMode {
        case .exercise:
            return tr("""
            אפשר לבקש הסבר לתרגיל.
            למשל:
            "תן הסבר לבעיטת מגל"
            """, """
            Ask for an exercise explanation.
            For example:
            "Explain a roundhouse kick"
            """)
        case .trainings:
            return tr("""
            אפשר לשאול על אימונים.
            למשל:
            "מתי האימון הבא?"
            """, """
            Ask about training.
            For example:
            "When is the next training?"
            """)
        case .kmiMaterial:
            return tr("""
            אפשר לחפש בחומר ק.מ.י.
            למשל:
            "הגנות חיצוניות"
            """, """
            Search the KMI material.
            For example:
            "External defenses"
            """)
        }
    }

    private func messageBubble(
        _ message: AiMessage
    ) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.fromUser {
                Spacer(minLength: 34)
            }

            VStack(
                alignment:
                    message.fromUser
                    ? .trailing
                    : .leading,
                spacing: 8
            ) {
                Text(
                    sanitizeAssistantMarkup(
                        message.text
                    )
                )
                .font(
                    .system(
                        size: 15,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    message.fromUser
                    ? .white
                    : Color.black.opacity(0.84)
                )
                .multilineTextAlignment(
                    isEnglish ? .leading : .trailing
                )
                .frame(
                    maxWidth: .infinity,
                    alignment:
                        isEnglish
                        ? .leading
                        : .trailing
                )

                if !message.fromUser {
                    assistantMessageActions(message)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(
                maxWidth:
                    message.fromUser
                    ? 360
                    : 520,
                alignment:
                    message.fromUser
                    ? .trailing
                    : .leading
            )
            .background(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .fill(
                    message.fromUser
                    ? Color.purple.opacity(0.88)
                    : Color.white.opacity(0.96)
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .stroke(
                    message.fromUser
                    ? Color.white.opacity(0.12)
                    : Color.purple.opacity(0.10),
                    lineWidth: 1
                )
            )
            .shadow(
                color: Color.black.opacity(
                    message.fromUser ? 0.05 : 0.12
                ),
                radius: 5,
                x: 0,
                y: 2
            )

            if !message.fromUser {
                Spacer(minLength: 18)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func assistantMessageActions(
        _ message: AiMessage
    ) -> some View {
        VStack(spacing: 8) {
            Divider()
                .overlay(
                    Color.purple.opacity(0.12)
                )

            HStack(spacing: 8) {
                messageActionButton(
                    title: tr(
                        "הקרא שוב",
                        "Read again"
                    ),
                    icon: "speaker.wave.2.fill"
                ) {
                    let cleanText =
                        sanitizeAssistantMarkup(
                            message.text
                        )

                    guard !cleanText.isEmpty else {
                        return
                    }

                    speechRecognizer.cancelListening()
                    tts.stop()
                    tts.speak(cleanText)
                }

                messageActionButton(
                    title: tr(
                        "שאלת המשך",
                        "Follow-up"
                    ),
                    icon: "mic.fill"
                ) {
                    inputText = ""
                    lastAutomaticallySubmittedText = ""

                    tts.stop()

                    if speechRecognizer.isListening {
                        speechRecognizer.stopListening()
                    } else {
                        toggleSpeechRecognition()
                    }
                }

                Spacer(minLength: 2)

                feedbackButton(
                    message: message,
                    feedback: .like,
                    icon: "hand.thumbsup.fill",
                    accessibilityTitle: tr(
                        "תשובה מועילה",
                        "Helpful answer"
                    )
                )

                feedbackButton(
                    message: message,
                    feedback: .unlike,
                    icon: "hand.thumbsdown.fill",
                    accessibilityTitle: tr(
                        "תשובה לא מועילה",
                        "Unhelpful answer"
                    )
                )
            }
        }
    }

    private func messageActionButton(
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(
                        .system(
                            size: 11,
                            weight: .bold
                        )
                    )

                Text(title)
                    .font(
                        .system(
                            size: 11,
                            weight: .bold
                        )
                    )
                    .lineLimit(1)
            }
            .foregroundStyle(
                Color.purple.opacity(0.88)
            )
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background(
                Capsule()
                    .fill(
                        Color.purple.opacity(0.08)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func feedbackButton(
        message: AiMessage,
        feedback: AssistantFeedback,
        icon: String,
        accessibilityTitle: String
    ) -> some View {
        let isSelected =
            message.feedback == feedback

        return Button {
            logic.setFeedback(
                messageID: message.id,
                feedback: feedback
            )
        } label: {
            Image(systemName: icon)
                .font(
                    .system(
                        size: 13,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    isSelected
                    ? .white
                    : Color.purple.opacity(0.72)
                )
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(
                            isSelected
                            ? feedbackColor(feedback)
                            : Color.purple.opacity(0.08)
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            accessibilityTitle
        )
        .accessibilityAddTraits(
            isSelected ? .isSelected : []
        )
    }

    private func feedbackColor(
        _ feedback: AssistantFeedback
    ) -> Color {
        switch feedback {
        case .like:
            return Color.green.opacity(0.82)

        case .unlike:
            return Color.red.opacity(0.82)

        case .none:
            return Color.purple.opacity(0.72)
        }
    }

    private var inputBar: some View {
        VStack(spacing: 8) {
            if speechRecognizer.isListening ||
                speechRecognizer.isProcessing ||
                speechRecognizer.errorMessage != nil {
                recognitionStatus
            }

            if speechRecognizer.alternatives.count > 1 {
                alternativesRow
            }

            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(
                        Color(red: 0.43, green: 0.25, blue: 0.95)
                    )
                    .symbolEffect(
                        .variableColor.iterative,
                        isActive: speechRecognizer.isListening
                    )

                TextField(
                    tr(
                        "כתוב שאלה…",
                        "Type a question…"
                    ),
                    text: $inputText
                )
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(
                    Color(red: 0.15, green: 0.14, blue: 0.24)
                )
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .submitLabel(.send)
                .disabled(
                    speechRecognizer.isListening ||
                    speechRecognizer.isProcessing
                )
                .onSubmit {
                    send()
                }

                if !inputText
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty {
                    Button {
                        send()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 31, weight: .bold))
                            .foregroundStyle(
                                Color(
                                    red: 0.43,
                                    green: 0.25,
                                    blue: 0.95
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        tr("שלח שאלה", "Send question")
                    )
                }

                Button {
                    toggleSpeechRecognition()
                } label: {
                    Image(
                        systemName:
                            speechRecognizer.isListening
                            ? "stop.fill"
                            : "mic.fill"
                    )
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(
                        speechRecognizer.isListening
                        ? .white
                        : Color(
                            red: 0.43,
                            green: 0.25,
                            blue: 0.95
                        )
                    )
                    .frame(width: 46, height: 46)
                    .background(
                        Circle()
                            .fill(
                                speechRecognizer.isListening
                                ? Color.red.opacity(0.84)
                                : Color(
                                    red: 0.95,
                                    green: 0.93,
                                    blue: 1.0
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                Color(
                                    red: 0.76,
                                    green: 0.70,
                                    blue: 0.94
                                ),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(speechRecognizer.isProcessing)
                .accessibilityLabel(
                    speechRecognizer.isListening
                    ? tr("הפסק האזנה", "Stop listening")
                    : tr("התחל האזנה", "Start listening")
                )
            }
            .padding(.leading, 12)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(
                    cornerRadius: 27,
                    style: .continuous
                )
                .fill(Color.white.opacity(0.98))
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 27,
                    style: .continuous
                )
                .stroke(
                    Color.purple.opacity(0.20),
                    lineWidth: 1
                )
            )
            .shadow(
                color: Color.black.opacity(0.10),
                radius: 8,
                x: 0,
                y: 3
            )
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 6)
    }

    private var voiceInputStatusText: String {
        if speechRecognizer.isListening {
            return tr(
                "מקשיב… בסיום הדיבור השאלה תישלח",
                "Listening… the question will be sent automatically"
            )
        }

        if speechRecognizer.isProcessing {
            return tr(
                "מעבד את הדיבור…",
                "Processing speech…"
            )
        }

        return tr(
            "לחץ על המיקרופון ואמור את הבקשה",
            "Tap the microphone and say your request"
        )
    }

    private var recognitionStatus: some View {
        HStack(spacing: 8) {
            if speechRecognizer.isListening {
                ProgressView()
                    .tint(.white)

                Text(tr("מקשיב… בסיום הדיבור השאלה תישלח אוטומטית", "Listening… your question will be sent automatically"))
            } else if speechRecognizer.isProcessing {
                ProgressView()
                    .tint(.white)

                Text(tr("מעבד את הדיבור…", "Processing speech…"))
            } else if let error = speechRecognizer.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(error)
            }
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(
            speechRecognizer.errorMessage == nil
            ? Color(red: 0.34, green: 0.25, blue: 0.62)
            : Color.red
        )
        .frame(maxWidth: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
    }

    private var alternativesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(
                    Array(speechRecognizer.alternatives.dropFirst().prefix(3)),
                    id: \.self
                ) { alternative in
                    Button {
                        send(alternative)
                    } label: {
                        Text(alternative)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(
                                Color(red: 0.43, green: 0.25, blue: 0.95)
                            )
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(
                                        Color(red: 0.95, green: 0.93, blue: 1.0)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func toggleSpeechRecognition() {
        if speechRecognizer.isListening {
            speechRecognizer.stopListening()
            return
        }

        tts.stop()

        // מאפשר לומר שוב גם את אותה שאלה בהאזנה חדשה.
        lastAutomaticallySubmittedText = ""

        speechRecognizer.requestPermissions { granted in
            guard granted else {
                return
            }

            speechRecognizer.startListening(
                localeIdentifier:
                    speechLocaleIdentifier
            ) { recognizedText in
                let cleanText = recognizedText.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

                guard !cleanText.isEmpty,
                      cleanText != lastAutomaticallySubmittedText else {
                    return
                }

                /*
                 * המיקרופון פעיל גם לפני בחירה ידנית.
                 * במקרה כזה נבחר אוטומטית המצב המתאים לשאלה.
                 */
                if logic.selectedMode == nil {
                    logic.setMode(
                        inferredAssistantMode(
                            from: cleanText
                        )
                    )
                }

                inputText = cleanText
                lastAutomaticallySubmittedText = cleanText
                send(cleanText)
            }
        }
    }

    private func inferredAssistantMode(
        from spokenText: String
    ) -> AssistantMode {
        let normalized = spokenText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()

        let trainingKeywords = [
            "אימון",
            "אימונים",
            "מאמן",
            "מדריך",
            "שעה",
            "שעות",
            "מתי",
            "איפה",
            "כתובת",
            "training",
            "trainings",
            "coach",
            "schedule",
            "when",
            "where"
        ]

        if trainingKeywords.contains(
            where: { normalized.contains($0) }
        ) {
            return .trainings
        }

        let materialKeywords = [
            "חומר קמי",
            "חומר ק.מ.י",
            "רשימת תרגילים",
            "תרגילים בחגורה",
            "נושא",
            "תת נושא",
            "הגנות חיצוניות",
            "kmi material",
            "exercise list",
            "topic",
            "belt material"
        ]

        if materialKeywords.contains(
            where: { normalized.contains($0) }
        ) {
            return .kmiMaterial
        }

        return .exercise
    }

    private func send(
        _ explicitText: String? = nil
    ) {
        guard logic.selectedMode != nil else {
            let prompt = tr(
                "בחר קודם נושא: תרגיל, אימונים או חומר ק.מ.י.",
                "First choose a topic: exercises, training, or KMI material."
            )

            tts.stop()
            tts.speak(prompt)
            return
        }

        let trimmed = (explicitText ?? inputText)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        speechRecognizer.cancelListening()
        tts.stop()

        let answer = logic.sendQuestion(trimmed)
        inputText = ""

        let cleanAnswer = sanitizeAssistantMarkup(answer)
        if !cleanAnswer.isEmpty {
            tts.speak(cleanAnswer)
        }
    }

    private func returnToAssistantHome() {
        speechRecognizer.cancelListening()
        tts.stop()

        inputText = ""
        lastAutomaticallySubmittedText = ""

        logic.resetToModeSelection()

        tts.speak(
            tr(
                "בחר נושא חדש כדי להמשיך.",
                "Choose a new topic to continue."
            )
        )
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    /// מנקה את תגיות העיצוב הפנימיות בדיוק לפני הצגה והקראה.
    /// כך תגיות כמו `[RED_BOLD]` או `[[/BOLD]]` אינן מגיעות למשתמש.
    private func sanitizeAssistantMarkup(_ source: String) -> String {
        var result = source

        let patterns = [
            #"(?i)\[\[\s*/?\s*RED_BOLD\s*\]\]"#,
            #"(?i)\[\s*/?\s*RED_BOLD\s*\]"#,
            #"(?i)\[\[\s*/?\s*BOLD\s*\]\]"#,
            #"(?i)\[\[\s*/?\s*RED\s*\]\]"#
        ]

        for pattern in patterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }

        result = result.replacingOccurrences(
            of: #"[ \t]+\n"#,
            with: "\n",
            options: .regularExpression
        )

        result = result.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
