import Foundation
import Combine
import Speech
import AVFoundation

@MainActor
final class KmiSpeechRecognizer: NSObject, ObservableObject {

    @Published private(set) var transcript: String = ""
    @Published private(set) var isListening: Bool = false
    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var errorMessage: String? = nil

    private let audioEngine = AVAudioEngine()

    private var recognitionRequest:
        SFSpeechAudioBufferRecognitionRequest?

    private var recognitionTask:
        SFSpeechRecognitionTask?

    private var speechRecognizer:
        SFSpeechRecognizer?

    private var onFinalResult: ((String) -> Void)?

    override init() {
        super.init()
    }

    func requestPermissions(
        completion: @escaping (Bool) -> Void
    ) {
        SFSpeechRecognizer
            .requestAuthorization { speechStatus in
                guard speechStatus == .authorized else {
                    Task { @MainActor in
                        self.errorMessage =
                            self.permissionMessage(
                                for: speechStatus
                            )

                        completion(false)
                    }
                    return
                }

                self.requestMicrophonePermission(
                    completion: completion
                )
            }
    }

    private nonisolated func requestMicrophonePermission(
        completion: @escaping (Bool) -> Void
    ) {
        let permissionHandler: (Bool) -> Void = {
            microphoneGranted in

            Task { @MainActor in
                if microphoneGranted {
                    self.errorMessage = nil
                    completion(true)
                } else {
                    self.errorMessage =
                        "לא ניתן להשתמש בפקודות קוליות ללא הרשאת מיקרופון"

                    completion(false)
                }
            }
        }

        if #available(iOS 17.0, *) {
            AVAudioApplication
                .requestRecordPermission(
                    completionHandler:
                        permissionHandler
                )
        } else {
            AVAudioSession.sharedInstance()
                .requestRecordPermission(
                    permissionHandler
                )
        }
    }

    func startListening(
        localeIdentifier: String,
        onFinalResult: @escaping (String) -> Void
    ) {
        stopListening()

        transcript = ""
        errorMessage = nil
        isProcessing = false
        self.onFinalResult = onFinalResult

        guard let recognizer =
                SFSpeechRecognizer(
                    locale: Locale(
                        identifier: localeIdentifier
                    )
                ) else {
            errorMessage =
                "זיהוי דיבור אינו זמין בשפה שנבחרה"
            return
        }

        guard recognizer.isAvailable else {
            errorMessage =
                "שירות זיהוי הדיבור אינו זמין כרגע"
            return
        }

        speechRecognizer = recognizer

        let request =
            SFSpeechAudioBufferRecognitionRequest()

        request.shouldReportPartialResults = true

        if #available(iOS 13.0, *) {
            request.requiresOnDeviceRecognition = false
        }

        recognitionRequest = request

        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(
                .record,
                mode: .measurement,
                options: [
                    .duckOthers
                ]
            )

            try session.setActive(
                true,
                options: .notifyOthersOnDeactivation
            )
        } catch {
            errorMessage =
                "לא ניתן להפעיל את המיקרופון"
            cleanupAudio()
            return
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat =
            inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0 else {
            errorMessage =
                "לא התקבל קלט מהמיקרופון"
            cleanupAudio()
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

        recognitionTask =
            recognizer.recognitionTask(
                with: request
            ) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else {
                        return
                    }

                    if let result {
                        let spokenText =
                            result.bestTranscription
                                .formattedString
                                .trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                )

                        self.transcript = spokenText

                        if result.isFinal {
                            self.finishRecognition(
                                with: spokenText
                            )
                            return
                        }
                    }

                    if error != nil {
                        if self.transcript.isEmpty {
                            self.errorMessage =
                                "לא הצלחתי לזהות את הפקודה"
                        }

                        self.finishRecognition(
                            with: self.transcript
                        )
                    }
                }
            }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
        } catch {
            errorMessage =
                "לא ניתן להתחיל את ההאזנה"
            cleanupAudio()
        }
    }

    func stopListening() {
        guard isListening ||
                recognitionRequest != nil ||
                recognitionTask != nil else {
            return
        }

        isListening = false
        isProcessing = true

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
    }

    func cancelListening() {
        onFinalResult = nil
        transcript = ""
        isListening = false
        isProcessing = false

        recognitionTask?.cancel()
        cleanupAudio()
    }

    private func finishRecognition(
        with spokenText: String
    ) {
        let cleanText =
            spokenText.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        isListening = false
        isProcessing = false

        let completion = onFinalResult
        onFinalResult = nil

        cleanupAudio()

        guard !cleanText.isEmpty else {
            return
        }

        completion?(cleanText)
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

    private func permissionMessage(
        for status: SFSpeechRecognizerAuthorizationStatus
    ) -> String {
        switch status {
        case .denied:
            return "הרשאת זיהוי הדיבור נדחתה"

        case .restricted:
            return "זיהוי דיבור מוגבל במכשיר זה"

        case .notDetermined:
            return "טרם ניתנה הרשאת זיהוי דיבור"

        case .authorized:
            return ""

        @unknown default:
            return "לא ניתן לקבל הרשאת זיהוי דיבור"
        }
    }

    deinit {
        recognitionTask?.cancel()

        if audioEngine.isRunning {
            audioEngine.stop()
        }
    }
}
