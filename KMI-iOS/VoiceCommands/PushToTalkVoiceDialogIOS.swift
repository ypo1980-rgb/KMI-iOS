import SwiftUI

// MARK: - PushToTalkVoiceDialogIOS

struct PushToTalkVoiceDialogIOS: View {

    @Environment(\.dismiss)
    private var dismiss

    @StateObject private var speechRecognizer =
        KmiSpeechRecognizer()

    @AppStorage("kmi_app_language")
    private var kmiAppLanguageCode: String = "he"

    @AppStorage("selected_language_code")
    private var selectedLanguageCode: String = "he"

    let onCommand: (
        _ command: VoiceAppCommand,
        _ spokenText: String
    ) -> Void

    @State private var didRequestInitialListening = false
    @State private var pulseAnimation = false

    private var isEnglish: Bool {
        let values = [
            kmiAppLanguageCode,
            selectedLanguageCode
        ]
        .map {
            $0.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()
        }

        return values.contains("en") ||
            values.contains("english")
    }

    private var speechLocaleIdentifier: String {
        isEnglish ? "en-US" : "he-IL"
    }

    private var statusText: String {
        if let errorMessage =
            speechRecognizer.errorMessage,
           !errorMessage.isEmpty {
            return errorMessage
        }

        if speechRecognizer.isProcessing {
            return tr(
                "מעבד את הפקודה...",
                "Processing command..."
            )
        }

        if speechRecognizer.isListening {
            return tr(
                "מקשיב לפקודה...",
                "Listening for a command..."
            )
        }

        return tr(
            "לחץ על המיקרופון ואמור פקודה",
            "Tap the microphone and say a command"
        )
    }

    private var hasError: Bool {
        guard let errorMessage =
                speechRecognizer.errorMessage else {
            return false
        }

        return !errorMessage.isEmpty
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.48)
                .ignoresSafeArea()
                .onTapGesture {
                    close()
                }

            dialogCard
                .padding(.horizontal, 22)
        }
        .environment(
            \.layoutDirection,
            isEnglish ? .leftToRight : .rightToLeft
        )
        .onAppear {
            guard !didRequestInitialListening else {
                return
            }

            didRequestInitialListening = true

            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.35
            ) {
                requestPermissionAndListen()
            }
        }
        .onDisappear {
            speechRecognizer.cancelListening()
        }
    }

    private var dialogCard: some View {
        VStack(spacing: 0) {
            closeButtonRow

            Text(
                tr(
                    "פקודות קוליות",
                    "Voice Commands"
                )
            )
            .font(
                .system(
                    size: 22,
                    weight: .black,
                    design: .rounded
                )
            )
            .foregroundStyle(
                Color(hex: 0xFF172033)
            )
            .multilineTextAlignment(.center)

            Spacer()
                .frame(height: 22)

            microphoneButton

            Spacer()
                .frame(height: 20)

            Text(statusText)
                .font(
                    .system(
                        size: 16,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    hasError
                    ? Color(hex: 0xFFDC2626)
                    : Color(hex: 0xFF334155)
                )
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            if !speechRecognizer.transcript
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty {
                transcriptCard
                    .padding(.top, 12)
            }

            Text(
                tr(
                    "לדוגמה: „פתח חגורה ירוקה” או „הסבר על בעיטת צד”",
                    "For example: “Open green belt” or “Explain side kick”"
                )
            )
            .font(
                .system(
                    size: 13,
                    weight: .medium
                )
            )
            .foregroundStyle(
                Color(hex: 0xFF64748B)
            )
            .multilineTextAlignment(.center)
            .padding(.top, 14)

            actionButton
                .padding(.top, 22)
        }
        .padding(
            EdgeInsets(
                top: 12,
                leading: 24,
                bottom: 22,
                trailing: 24
            )
        )
        .background(
            RoundedRectangle(
                cornerRadius: 30,
                style: .continuous
            )
            .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 30,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(0.45),
                lineWidth: 1
            )
        )
        .shadow(
            color: Color.black.opacity(0.24),
            radius: 18,
            x: 0,
            y: 10
        )
    }

    private var closeButtonRow: some View {
        HStack {
            Spacer()

            Button {
                close()
            } label: {
                Image(systemName: "xmark")
                    .font(
                        .system(
                            size: 15,
                            weight: .black
                        )
                    )
                    .foregroundStyle(
                        Color(hex: 0xFF475569)
                    )
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(
                                Color.black.opacity(0.06)
                            )
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                tr("סגירה", "Close")
            )
        }
    }

    private var microphoneButton: some View {
        Button {
            toggleListening()
        } label: {
            ZStack {
                if speechRecognizer.isListening {
                    Circle()
                        .fill(
                            Color(hex: 0xFF6366F1)
                                .opacity(0.20)
                        )
                        .frame(width: 132, height: 132)
                        .scaleEffect(
                            pulseAnimation ? 1.08 : 0.92
                        )
                        .opacity(
                            pulseAnimation ? 0.30 : 0.75
                        )
                }

                Circle()
                    .fill(
                        microphoneGradient
                    )
                    .frame(width: 112, height: 112)
                    .shadow(
                        color:
                            Color(hex: 0xFF6366F1)
                                .opacity(0.28),
                        radius: 12,
                        x: 0,
                        y: 7
                    )

                Image(
                    systemName:
                        speechRecognizer.isListening
                        ? "stop.fill"
                        : "mic.fill"
                )
                .font(
                    .system(
                        size: 46,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    speechRecognizer.isListening
                    ? Color.white
                    : Color(hex: 0xFF4F46E5)
                )
            }
        }
        .buttonStyle(.plain)
        .disabled(speechRecognizer.isProcessing)
        .onChange(
            of: speechRecognizer.isListening
        ) { _, isListening in
            if isListening {
                pulseAnimation = false

                withAnimation(
                    .easeInOut(duration: 0.85)
                    .repeatForever(
                        autoreverses: true
                    )
                ) {
                    pulseAnimation = true
                }
            } else {
                pulseAnimation = false
            }
        }
        .accessibilityLabel(
            speechRecognizer.isListening
            ? tr("סיים פקודה", "Finish command")
            : tr("התחל להאזין", "Start listening")
        )
    }

    private var microphoneGradient: LinearGradient {
        if speechRecognizer.isListening {
            return LinearGradient(
                colors: [
                    Color(hex: 0xFF38BDF8),
                    Color(hex: 0xFF6366F1),
                    Color(hex: 0xFF7C3AED)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color(hex: 0xFFE0F2FE),
                Color(hex: 0xFFEDE9FE)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var transcriptCard: some View {
        Text(speechRecognizer.transcript)
            .font(
                .system(
                    size: 14,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                Color(hex: 0xFF334155)
            )
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .fill(
                    Color(hex: 0xFFF1F5F9)
                )
            )
    }

    private var actionButton: some View {
        Button {
            toggleListening()
        } label: {
            HStack(spacing: 8) {
                Image(
                    systemName:
                        speechRecognizer.isListening
                        ? "stop.fill"
                        : (
                            hasError
                            ? "arrow.clockwise"
                            : "mic.fill"
                        )
                )
                .font(
                    .system(
                        size: 16,
                        weight: .bold
                    )
                )

                Text(actionButtonTitle)
                    .font(
                        .system(
                            size: 15,
                            weight: .black
                        )
                    )
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .fill(
                    Color(hex: 0xFF4F46E5)
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(speechRecognizer.isProcessing)
        .opacity(
            speechRecognizer.isProcessing
            ? 0.58
            : 1
        )
    }

    private var actionButtonTitle: String {
        if speechRecognizer.isListening {
            return tr(
                "סיים פקודה",
                "Finish Command"
            )
        }

        if hasError {
            return tr(
                "נסה שוב",
                "Try Again"
            )
        }

        return tr(
            "התחל להאזין",
            "Start Listening"
        )
    }

    private func toggleListening() {
        if speechRecognizer.isListening {
            speechRecognizer.stopListening()
            return
        }

        requestPermissionAndListen()
    }

    private func requestPermissionAndListen() {
        speechRecognizer.requestPermissions { granted in
            guard granted else {
                return
            }

            speechRecognizer.startListening(
                localeIdentifier:
                    speechLocaleIdentifier
            ) { spokenText in
                handleRecognizedText(spokenText)
            }
        }
    }

    private func handleRecognizedText(
        _ spokenText: String
    ) {
        let cleanText =
            spokenText.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanText.isEmpty else {
            return
        }

        let command =
            VoiceCommandParser.parse(cleanText)

        onCommand(
            command,
            cleanText
        )
    }

    private func close() {
        speechRecognizer.cancelListening()
        dismiss()
    }

    private func tr(
        _ hebrew: String,
        _ english: String
    ) -> String {
        isEnglish ? english : hebrew
    }
}
