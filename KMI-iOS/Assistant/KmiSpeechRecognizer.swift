
import Foundation
import Combine
import Speech
import AVFoundation

@MainActor
final class KmiSpeechRecognizer: NSObject, ObservableObject {

    @Published private(set) var transcript: String = ""
    @Published private(set) var alternatives: [String] = []
    @Published private(set) var isListening: Bool = false
    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var errorMessage: String? = nil

    private let audioEngine = AVAudioEngine()

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?

    private var onFinalResult: ((String) -> Void)?
    private var silenceWorkItem: DispatchWorkItem?
    private var forcedFinishWorkItem: DispatchWorkItem?

    private var didDeliverFinalResult = false
    private var recognitionGeneration = UUID()

    /// דומה להגדרת Android:
    /// לאחר שהמשתמש מפסיק לדבר, הטקסט נשלח אוטומטית.
    private let silenceDelay: TimeInterval = 1.55

    /// אם Apple לא מחזירה `isFinal` לאחר `endAudio`,
    /// שולחים את התמלול האחרון במקום להמתין ללחיצה ידנית.
    private let forcedFinishDelay: TimeInterval = 1.20

    override init() {
        super.init()
    }

    // MARK: - Permissions

    func requestPermissions(
        completion: @escaping (Bool) -> Void
    ) {
        SFSpeechRecognizer.requestAuthorization { [weak self] speechStatus in
            Task { @MainActor in
                guard let self else {
                    completion(false)
                    return
                }

                guard speechStatus == .authorized else {
                    self.errorMessage = self.permissionMessage(for: speechStatus)
                    completion(false)
                    return
                }

                self.requestMicrophonePermission(completion: completion)
            }
        }
    }

    private func requestMicrophonePermission(
        completion: @escaping (Bool) -> Void
    ) {
        let permissionHandler: (Bool) -> Void = { [weak self] microphoneGranted in
            Task { @MainActor in
                guard let self else {
                    completion(false)
                    return
                }

                if microphoneGranted {
                    self.errorMessage = nil
                    completion(true)
                } else {
                    self.errorMessage =
                        "לא ניתן להשתמש בעוזר הקולי ללא הרשאת מיקרופון"
                    completion(false)
                }
            }
        }

        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission(
                completionHandler: permissionHandler
            )
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission(
                permissionHandler
            )
        }
    }

    // MARK: - Recognition

    func startListening(
        localeIdentifier: String,
        onFinalResult: @escaping (String) -> Void
    ) {
        cancelCurrentRecognition(clearTranscript: true)

        transcript = ""
        alternatives = []
        errorMessage = nil
        isProcessing = false
        didDeliverFinalResult = false
        self.onFinalResult = onFinalResult

        let generation = UUID()
        recognitionGeneration = generation

        guard let recognizer = SFSpeechRecognizer(
            locale: Locale(identifier: localeIdentifier)
        ) else {
            errorMessage = localizedMessage(
                he: "זיהוי דיבור אינו זמין בשפה שנבחרה",
                en: "Speech recognition is unavailable for the selected language",
                localeIdentifier: localeIdentifier
            )
            self.onFinalResult = nil
            return
        }

        guard recognizer.isAvailable else {
            errorMessage = localizedMessage(
                he: "שירות זיהוי הדיבור אינו זמין כרגע",
                en: "Speech recognition is currently unavailable",
                localeIdentifier: localeIdentifier
            )
            self.onFinalResult = nil
            return
        }

        speechRecognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation

        if #available(iOS 13.0, *) {
            request.requiresOnDeviceRecognition = false
        }

        recognitionRequest = request

        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [
                    .duckOthers,
                    .defaultToSpeaker,
                    .allowBluetooth
                ]
            )

            try session.setActive(
                true,
                options: .notifyOthersOnDeactivation
            )
        } catch {
            errorMessage = localizedMessage(
                he: "לא ניתן להפעיל את המיקרופון",
                en: "The microphone could not be activated",
                localeIdentifier: localeIdentifier
            )
            cleanupAudio()
            self.onFinalResult = nil
            return
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0,
              recordingFormat.channelCount > 0 else {
            errorMessage = localizedMessage(
                he: "לא התקבל קלט מהמיקרופון",
                en: "No microphone input was detected",
                localeIdentifier: localeIdentifier
            )
            cleanupAudio()
            self.onFinalResult = nil
            return
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(
            onBus: 0,
            bufferSize: 1_024,
            format: recordingFormat
        ) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        recognitionTask = recognizer.recognitionTask(with: request) {
            [weak self] result,
            error in

            Task { @MainActor in
                guard let self,
                      self.recognitionGeneration == generation,
                      !self.didDeliverFinalResult else {
                    return
                }

                if let result {
                    let spokenText = result.bestTranscription
                        .formattedString
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if !spokenText.isEmpty {
                        self.transcript = spokenText
                        self.alternatives = self.uniqueAlternatives(from: result)
                        self.scheduleAutomaticFinish(
                            generation: generation
                        )
                    }

                    if result.isFinal {
                        self.deliverFinalResult(
                            spokenText,
                            generation: generation
                        )
                        return
                    }
                }

                if let error {
                    self.handleRecognitionError(
                        error,
                        localeIdentifier: localeIdentifier,
                        generation: generation
                    )
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
        } catch {
            errorMessage = localizedMessage(
                he: "לא ניתן להתחיל את ההאזנה",
                en: "Listening could not be started",
                localeIdentifier: localeIdentifier
            )
            cancelCurrentRecognition(clearTranscript: false)
        }
    }

    /// לחיצה ידנית על עצירה.
    /// אם כבר קיים טקסט, הוא יישלח אוטומטית גם אם Apple
    /// אינה מחזירה תוצאה סופית.
    func stopListening() {
        guard isListening ||
                recognitionRequest != nil ||
                recognitionTask != nil else {
            return
        }

        silenceWorkItem?.cancel()
        silenceWorkItem = nil

        isListening = false
        isProcessing = true

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()

        scheduleForcedFinish(
            generation: recognitionGeneration
        )
    }

    func cancelListening() {
        onFinalResult = nil
        didDeliverFinalResult = true
        transcript = ""
        alternatives = []
        errorMessage = nil
        isListening = false
        isProcessing = false

        cancelCurrentRecognition(clearTranscript: true)
    }

    // MARK: - Automatic submit

    private func scheduleAutomaticFinish(
        generation: UUID
    ) {
        silenceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self,
                      self.recognitionGeneration == generation,
                      !self.didDeliverFinalResult else {
                    return
                }

                let cleanText = self.transcript.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

                guard !cleanText.isEmpty else {
                    return
                }

                // מפסיקים את ההקלטה ושולחים מיד את הטקסט האחרון.
                // אין צורך בלחיצה נוספת על Enter/Send.
                if self.audioEngine.isRunning {
                    self.audioEngine.stop()
                }

                self.audioEngine.inputNode.removeTap(onBus: 0)
                self.recognitionRequest?.endAudio()

                self.deliverFinalResult(
                    cleanText,
                    generation: generation
                )
            }
        }

        silenceWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + silenceDelay,
            execute: workItem
        )
    }

    private func scheduleForcedFinish(
        generation: UUID
    ) {
        forcedFinishWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self,
                      self.recognitionGeneration == generation,
                      !self.didDeliverFinalResult else {
                    return
                }

                let cleanText = self.transcript.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

                if cleanText.isEmpty {
                    self.errorMessage = "לא הצלחתי לזהות את הבקשה"
                    self.isProcessing = false
                    self.cleanupAudio()
                } else {
                    self.deliverFinalResult(
                        cleanText,
                        generation: generation
                    )
                }
            }
        }

        forcedFinishWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + forcedFinishDelay,
            execute: workItem
        )
    }

    private func deliverFinalResult(
        _ spokenText: String,
        generation: UUID
    ) {
        guard recognitionGeneration == generation,
              !didDeliverFinalResult else {
            return
        }

        let cleanText = spokenText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleanText.isEmpty else {
            isListening = false
            isProcessing = false
            cleanupAudio()
            return
        }

        didDeliverFinalResult = true
        silenceWorkItem?.cancel()
        forcedFinishWorkItem?.cancel()
        silenceWorkItem = nil
        forcedFinishWorkItem = nil

        transcript = cleanText
        isListening = false
        isProcessing = false

        let completion = onFinalResult
        onFinalResult = nil

        cleanupAudio()
        completion?(cleanText)
    }

    // MARK: - Errors and cleanup

    private func handleRecognitionError(
        _ error: Error,
        localeIdentifier: String,
        generation: UUID
    ) {
        guard recognitionGeneration == generation,
              !didDeliverFinalResult else {
            return
        }

        let cleanText = transcript.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        // אם כבר זוהה טקסט, לא מאבדים אותו בגלל שגיאת סיום.
        if !cleanText.isEmpty {
            deliverFinalResult(
                cleanText,
                generation: generation
            )
            return
        }

        let nsError = error as NSError

        // שגיאות ביטול שנוצרו על־ידינו אינן מוצגות למשתמש.
        if nsError.domain == "kAFAssistantErrorDomain",
           nsError.code == 216 {
            isListening = false
            isProcessing = false
            cleanupAudio()
            return
        }

        errorMessage = localizedMessage(
            he: recognitionErrorMessageHe(nsError),
            en: recognitionErrorMessageEn(nsError),
            localeIdentifier: localeIdentifier
        )

        isListening = false
        isProcessing = false
        cleanupAudio()
    }

    private func cancelCurrentRecognition(
        clearTranscript: Bool
    ) {
        recognitionGeneration = UUID()

        silenceWorkItem?.cancel()
        forcedFinishWorkItem?.cancel()
        silenceWorkItem = nil
        forcedFinishWorkItem = nil

        recognitionTask?.cancel()
        cleanupAudio()

        isListening = false
        isProcessing = false

        if clearTranscript {
            transcript = ""
            alternatives = []
        }
    }

    private func cleanupAudio() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil
        speechRecognizer = nil

        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    private func uniqueAlternatives(
        from result: SFSpeechRecognitionResult
    ) -> [String] {
        var seen = Set<String>()

        return result.transcriptions
            .map {
                $0.formattedString.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0.lowercased()).inserted }
            .prefix(5)
            .map { $0 }
    }

    private func recognitionErrorMessageHe(
        _ error: NSError
    ) -> String {
        switch error.code {
        case 1101:
            return "זיהוי הדיבור אינו זמין כרגע. אפשר להקליד את הבקשה"
        case 203:
            return "לא זוהה דיבור. נסה שוב או הקלד את הבקשה"
        default:
            return "זיהוי הדיבור נכשל. נסה שוב או הקלד את הבקשה"
        }
    }

    private func recognitionErrorMessageEn(
        _ error: NSError
    ) -> String {
        switch error.code {
        case 1101:
            return "Speech recognition is currently unavailable. You can type your request"
        case 203:
            return "No speech was recognized. Try again or type your request"
        default:
            return "Speech recognition failed. Try again or type your request"
        }
    }

    private func localizedMessage(
        he: String,
        en: String,
        localeIdentifier: String
    ) -> String {
        localeIdentifier.lowercased().hasPrefix("en") ? en : he
    }

    private func permissionMessage(
        for status: SFSpeechRecognizerAuthorizationStatus
    ) -> String {
        switch status {
        case .denied:
            return "הרשאת זיהוי הדיבור נדחתה"
        case .restricted:
            return "זיהוי הדיבור מוגבל במכשיר זה"
        case .notDetermined:
            return "טרם ניתנה הרשאת זיהוי דיבור"
        case .authorized:
            return ""
        @unknown default:
            return "לא ניתן לקבל הרשאת זיהוי דיבור"
        }
    }

    deinit {
        silenceWorkItem?.cancel()
        forcedFinishWorkItem?.cancel()
        recognitionTask?.cancel()

        if audioEngine.isRunning {
            audioEngine.stop()
        }
    }
}
