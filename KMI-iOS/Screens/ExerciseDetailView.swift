import SwiftUI
import Shared
import AVFoundation
import Combine

struct ExerciseDetailView: View {
    let belt: Belt
    let topicTitle: String
    let item: String

    @State private var isFavorite: Bool = false
    @State private var isCompleted: Bool = false
    @State private var showShare: Bool = false
    @State private var noteText: String = ""
    @State private var lastSavedNoteText: String = ""
    @State private var didLoadNote: Bool = false
    @State private var saveMessage: String? = nil
    @State private var saveMessageToken: UUID? = nil
    @StateObject private var speechController = ExerciseSpeechController()

    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"

    private var isEnglish: Bool {
        let values = [
            kmiAppLanguageCode.lowercased(),
            appLanguageRaw.lowercased(),
            initialLanguageCode.lowercased()
        ]

        return values.contains("en") || values.contains("english")
    }

    private var screenLayoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    private var primaryTextAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var horizontalTextAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var horizontalStackAlignment: HorizontalAlignment {
        isEnglish ? .leading : .trailing
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private func displayTopicPathTitle(_ raw: String) -> String {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isEnglish else { return clean }

        let parts = clean
            .components(separatedBy: "/")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !parts.isEmpty else {
            return KmiEnglishTitleResolver.title(for: clean, isEnglish: true)
        }

        return parts
            .map { displayTopicPartTitle($0) }
            .joined(separator: " / ")
    }

    private func displayTopicPartTitle(_ raw: String) -> String {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        switch clean {
        case "def_internal_punch", "def_internal_punches":
            return "Internal Defenses - Punches"

        case "def_internal_kick", "def_internal_kicks":
            return "Internal Defenses - Kicks"

        case "def_external_punch", "def_external_punches":
            return "External Defenses - Punches"

        case "def_external_kick", "def_external_kicks":
            return "External Defenses - Kicks"

        case "knife_defense":
            return "Knife Defense"

        case "gun_threat_defense":
            return "Gun Threat Defense"

        case "stick_defense":
            return "Stick Defense"

        case "hands_strikes":
            return "Hand Strikes"

        case "hands_elbows":
            return "Elbow Strikes"

        case "hands_stick_rifle":
            return "Stick / Rifle Strikes"

        case "hands_all":
            return "Hand Techniques"

        case "releases":
            return "Releases"

        case "topic_breakfalls_rolls", "rolls_breakfalls":
            return "Breakfalls and Rolls"

        case "kicks", "topic_kicks", "kicks_hard":
            return "Kicks"

        default:
            return KmiEnglishTitleResolver.title(for: clean, isEnglish: true)
        }
    }

    private var displayItemTitle: String {
        KmiEnglishTitleResolver.title(for: item, isEnglish: isEnglish)
    }

    private var displayTopicTitle: String {
        displayTopicPathTitle(topicTitle)
    }

    private var displayBeltTitle: String {
        beltTitleText(belt)
    }

    private var storageKeyBase: String {
        // מפתח יציב מקומי (בהמשך נחליף למזהה קנוני מה-Shared)
        // שומר לפי belt + topicTitle + item
        let b = belt.id
        let t = topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let i = item.trimmingCharacters(in: .whitespacesAndNewlines)
        return "kmi.exercise.\(b).\(t).\(i)"
    }

    private var favKey: String { storageKeyBase + ".fav" }
    private var doneKey: String { storageKeyBase + ".done" }
    private var noteKey: String { storageKeyBase + ".note" }

    private var explanationText: String {
        let txt = LocalExplanations.shared.get(belt: belt, item: item)
        let clean = txt.trimmingCharacters(in: .whitespacesAndNewlines)

        if clean.isEmpty {
            return tr(
                "לא נמצא הסבר לתרגיל זה.",
                "No explanation was found for this exercise."
            )
        }

        return clean
    }

    var shareText: String {
        "\(displayItemTitle)\n\(displayBeltTitle) • \(displayTopicTitle)\n\nKMI"
    }

    var body: some View {
        ZStack {
            ExerciseGradientBackground()

            ScrollView {
                VStack(spacing: 12) {

                    WhiteCard {
                        VStack(spacing: 10) {

                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(beltAccent(belt))
                                .frame(width: 54, height: 6)
                                .opacity(0.95)

                            Text(displayItemTitle)
                                .font(.title3.weight(.heavy))
                                .foregroundStyle(Color.black.opacity(0.86))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)

                            Text("\(displayBeltTitle)  •  \(displayTopicTitle)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.black.opacity(0.56))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                    }

                    WhiteCard {
                        VStack(alignment: horizontalStackAlignment, spacing: 10) {
                            Text(tr("פעולות מהירות", "Quick actions"))
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.black.opacity(0.82))
                                .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                                .multilineTextAlignment(primaryTextAlignment)

                            VStack(spacing: 10) {
                                HStack(spacing: 10) {
                                    if isEnglish {
                                        favoriteActionPill
                                        playActionPill
                                        Spacer(minLength: 0)
                                    } else {
                                        Spacer(minLength: 0)
                                        playActionPill
                                        favoriteActionPill
                                    }
                                }

                                HStack(spacing: 10) {
                                    if isEnglish {
                                        completedActionPill
                                        shareActionPill
                                        Spacer(minLength: 0)
                                    } else {
                                        Spacer(minLength: 0)
                                        shareActionPill
                                        completedActionPill
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                    }

                    WhiteCard {
                        VStack(alignment: horizontalStackAlignment, spacing: 8) {
                            sectionHeader(
                                title: tr("הסבר על התרגיל", "Exercise explanation"),
                                system: "doc.text.fill",
                                accent: beltAccent(belt)
                            )

                            Text(explanationText)
                                .font(.system(size: 16, weight: .regular))
                                .lineSpacing(5)
                                .foregroundStyle(Color.black.opacity(0.72))
                                .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                                .multilineTextAlignment(primaryTextAlignment)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.black.opacity(0.035))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.black.opacity(0.055), lineWidth: 1)
                                )
                                .padding(.top, 2)

                            Divider()
                                .opacity(0.14)
                                .padding(.vertical, 4)

                            sectionHeader(
                                title: tr("הערת המתאמן:", "Trainee note:"),
                                system: "square.and.pencil",
                                accent: beltAccent(belt)
                            )

                            ZStack(alignment: isEnglish ? .topLeading : .topTrailing) {
                                TextEditor(text: $noteText)
                                    .scrollContentBackground(.hidden)
                                    .multilineTextAlignment(primaryTextAlignment)
                                    .environment(\.layoutDirection, screenLayoutDirection)
                                    .frame(minHeight: 130)
                                    .padding(10)

                                if noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(tr(
                                        "כתוב כאן הערה אישית על התרגיל...",
                                        "Write a personal note about this exercise..."
                                    ))
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color.black.opacity(0.34))
                                    .multilineTextAlignment(primaryTextAlignment)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 18)
                                    .allowsHitTesting(false)
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.black.opacity(0.045))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(beltAccent(belt).opacity(0.22), lineWidth: 1)
                            )

                            HStack(spacing: 10) {
                                if isEnglish {
                                    Button {
                                        saveNote()
                                    } label: {
                                        Text(tr("שמור הערה", "Save note"))
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(Color.black.opacity(0.80))
                                            )
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        clearNote()
                                    } label: {
                                        Text(tr("נקה", "Clear"))
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.black.opacity(0.80))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(Color.white.opacity(0.92))
                                            )
                                    }
                                    .buttonStyle(.plain)

                                    Spacer()
                                } else {
                                    Spacer()

                                    Button {
                                        clearNote()
                                    } label: {
                                        Text(tr("נקה", "Clear"))
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.black.opacity(0.80))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(Color.white.opacity(0.92))
                                            )
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        saveNote()
                                    } label: {
                                        Text(tr("שמור הערה", "Save note"))
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(Color.black.opacity(0.80))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                    }

                    Spacer(minLength: 18)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 22)
            }

            if let saveMessage {
                VStack {
                    Spacer()

                    Text(saveMessage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.black.opacity(0.82))
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
                        .padding(.bottom, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .padding(.horizontal, 16)
            }
        }
        .environment(\.layoutDirection, screenLayoutDirection)
        .navigationTitle(tr("תרגיל", "Exercise"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) {
            ActivityView(activityItems: [shareText])
        }
        .onAppear {
            // ✅ טעינה אמיתית מהאחסון המקומי
            isFavorite = loadBool(key: favKey, defaultValue: false)
            isCompleted = loadBool(key: doneKey, defaultValue: false)
            loadNoteIfNeeded()
        }
        .onDisappear {
            autosaveNoteIfNeeded()
            stopSpeech(showMessage: false)
        }
    }

    private var favoriteActionPill: some View {
        actionPill(
            title: isFavorite
            ? tr("מועדף", "Favorite")
            : tr("הוסף למועדפים", "Add favorite"),
            system: isFavorite ? "star.fill" : "star",
            accent: isFavorite ? Color.yellow.opacity(0.95) : Color.black.opacity(0.75)
        ) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                isFavorite.toggle()
                saveBool(isFavorite, key: favKey)
            }

            showTemporaryMessage(
                isFavorite
                ? tr("נוסף למועדפים", "Added to favorites")
                : tr("הוסר מהמועדפים", "Removed from favorites")
            )
        }
    }

    private var playActionPill: some View {
        actionPill(
            title: speechController.isSpeaking
            ? tr("עצור", "Stop")
            : tr("השמעה", "Play"),
            system: speechController.isSpeaking ? "stop.fill" : "speaker.wave.2.fill",
            accent: speechController.isSpeaking ? Color.red.opacity(0.90) : Color.black.opacity(0.75)
        ) {
            toggleSpeech()
        }
    }

    private var completedActionPill: some View {
        actionPill(
            title: isCompleted
            ? tr("בוצע", "Done")
            : tr("סמן כבוצע", "Mark done"),
            system: isCompleted ? "checkmark.circle.fill" : "checkmark.circle",
            accent: isCompleted ? Color.green.opacity(0.95) : Color.black.opacity(0.75)
        ) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                isCompleted.toggle()
                saveBool(isCompleted, key: doneKey)
            }

            showTemporaryMessage(
                isCompleted
                ? tr("התרגיל סומן כבוצע", "Exercise marked as done")
                : tr("סימון הביצוע הוסר", "Done mark removed")
            )
        }
    }

    private var shareActionPill: some View {
        actionPill(
            title: tr("שתף", "Share"),
            system: "square.and.arrow.up",
            accent: Color.black.opacity(0.75)
        ) {
            showShare = true

            showTemporaryMessage(
                tr("פותח שיתוף", "Opening share")
            )
        }
    }

    // MARK: - Local storage (UserDefaults) – בהמשך נחליף ל-Shared

    private func loadBool(key: String, defaultValue: Bool) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil { return defaultValue }
        return UserDefaults.standard.bool(forKey: key)
    }

    private func saveBool(_ value: Bool, key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    private func loadNoteIfNeeded() {
        guard !didLoadNote else { return }

        let storedNote = UserDefaults.standard.string(forKey: noteKey) ?? ""
        noteText = storedNote
        lastSavedNoteText = storedNote
        didLoadNote = true
    }

    private func saveNote() {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: noteKey)
        noteText = trimmed
        lastSavedNoteText = trimmed

        showTemporaryMessage(
            tr("ההערה נשמרה", "Note saved")
        )
    }

    private func autosaveNoteIfNeeded() {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed != lastSavedNoteText else { return }

        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: noteKey)
        } else {
            UserDefaults.standard.set(trimmed, forKey: noteKey)
        }

        noteText = trimmed
        lastSavedNoteText = trimmed
    }

    private func clearNote() {
        UserDefaults.standard.removeObject(forKey: noteKey)
        noteText = ""
        lastSavedNoteText = ""

        showTemporaryMessage(
            tr("ההערה נמחקה", "Note cleared")
        )
    }

    private func speechCleanText(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "•", with: ".")
            .replacingOccurrences(of: "/", with: ".")
            .replacingOccurrences(of: "K.M.I", with: isEnglish ? "K M I" : "קיי אם איי")
            .replacingOccurrences(of: "KMI", with: isEnglish ? "K M I" : "קיי אם איי")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func firstMeaningfulSentence(
        from raw: String,
        maxCharacters: Int
    ) -> String {
        let clean = raw
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !clean.isEmpty else { return "" }

        if clean == tr(
            "לא נמצא הסבר לתרגיל זה.",
            "No explanation was found for this exercise."
        ) {
            return ""
        }

        let separators = CharacterSet(charactersIn: ".!?؟")
        let firstPart = clean
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? clean

        if firstPart.count <= maxCharacters {
            return firstPart
        }

        let index = firstPart.index(
            firstPart.startIndex,
            offsetBy: maxCharacters,
            limitedBy: firstPart.endIndex
        ) ?? firstPart.endIndex

        return String(firstPart[..<index])
            .trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private func toggleSpeech() {
        if speechController.isSpeaking {
            stopSpeech()
            return
        }

        speakExercise()
    }

    private func speechPreviewText() -> String {
        let shortExplanation = firstMeaningfulSentence(
            from: explanationText,
            maxCharacters: isEnglish ? 180 : 150
        )

        let parts = [
            displayItemTitle,
            displayBeltTitle,
            displayTopicTitle,
            shortExplanation
        ]

        return parts
            .map { speechCleanText($0) }
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
    }

    private func speakExercise() {
        let textToSpeak = speechPreviewText()

        guard !textToSpeak.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showTemporaryMessage(
                tr("אין טקסט להשמעה", "There is no text to play")
            )
            return
        }

        speechController.speak(
            text: textToSpeak,
            languageCode: isEnglish ? "en-US" : "he-IL",
            rate: isEnglish ? 0.46 : 0.43
        )

        showTemporaryMessage(
            tr("מתחיל להשמיע", "Playing")
        )
    }

    private func stopSpeech(showMessage: Bool = true) {
        speechController.stop()

        guard showMessage else { return }

        showTemporaryMessage(
            tr("ההשמעה נעצרה", "Playback stopped")
        )
    }

    private func showTemporaryMessage(_ message: String) {
        let token = UUID()

        saveMessageToken = token

        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            saveMessage = message
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            guard saveMessageToken == token else { return }

            withAnimation(.easeInOut(duration: 0.22)) {
                saveMessage = nil
                saveMessageToken = nil
            }
        }
    }

    // MARK: - UI helpers

    private func sectionHeader(
        title: String,
        system: String,
        accent: Color
    ) -> some View {
        HStack(spacing: 8) {
            if isEnglish {
                Image(systemName: system)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accent)

                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)

                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .multilineTextAlignment(.trailing)

                Image(systemName: system)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accent)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func beltTitleText(_ belt: Belt) -> String {
        switch belt {
        case .white:
            return isEnglish ? "White Belt" : "חגורה לבנה"
        case .yellow:
            return isEnglish ? "Yellow Belt" : "חגורה צהובה"
        case .orange:
            return isEnglish ? "Orange Belt" : "חגורה כתומה"
        case .green:
            return isEnglish ? "Green Belt" : "חגורה ירוקה"
        case .blue:
            return isEnglish ? "Blue Belt" : "חגורה כחולה"
        case .brown:
            return isEnglish ? "Brown Belt" : "חגורה חומה"
        case .black:
            return isEnglish ? "Black Belt" : "חגורה שחורה"
        default:
            return isEnglish ? "Belt" : "חגורה"
        }
    }

    private func beltAccent(_ belt: Belt) -> Color {
        switch belt {
        case .yellow:
            return Color(red: 0.95, green: 0.82, blue: 0.18)
        case .orange:
            return Color(red: 0.96, green: 0.62, blue: 0.16)
        case .green:
            return Color(red: 0.22, green: 0.76, blue: 0.35)
        case .blue:
            return Color(red: 0.22, green: 0.52, blue: 0.92)
        case .brown:
            return Color(red: 0.57, green: 0.38, blue: 0.24)
        case .black:
            return Color(red: 0.42, green: 0.42, blue: 0.46)
        default:
            return Color.black.opacity(0.25)
        }
    }

    private func actionPill(
        title: String,
        system: String,
        accent: Color,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                if isEnglish {
                    Image(systemName: system)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(accent)

                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.black.opacity(0.80))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                } else {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.black.opacity(0.80))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Image(systemName: system)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(accent)
                }
            }
            .frame(minWidth: 112)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.92))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Hebrew") {
    NavigationStack {
        ExerciseDetailView(
            belt: .orange,
            topicTitle: "בעיטות",
            item: "בעיטה ישרה"
        )
    }
}

#Preview("English path") {
    NavigationStack {
        ExerciseDetailView(
            belt: .orange,
            topicTitle: "הגנות / def_internal_kick",
            item: "בעיטת הגנה לפנים"
        )
    }
}

// MARK: - Local background (no dependency on other files)
private struct ExerciseGradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.06, blue: 0.25),
                Color(red: 0.20, green: 0.12, blue: 0.55),
                Color(red: 0.08, green: 0.44, blue: 0.86),
                Color(red: 0.10, green: 0.80, blue: 0.90)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Share sheet
private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Speech controller

private final class ExerciseSpeechController: NSObject, ObservableObject {

    @Published var isSpeaking: Bool = false

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(
        text: String,
        languageCode: String,
        rate: Float
    ) {
        stop()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }

        isSpeaking = false
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}

extension ExerciseSpeechController: AVSpeechSynthesizerDelegate {}
