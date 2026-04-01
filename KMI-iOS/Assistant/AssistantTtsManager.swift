import Foundation
import AVFoundation

final class AssistantTtsManager: NSObject {
    static let shared = AssistantTtsManager()

    private let synthesizer = AVSpeechSynthesizer()

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    var onSpeechStarted: (() -> Void)?
    var onSpeechFinished: (() -> Void)?

    func speak(_ text: String) {
        let clean = normalizeForTts(text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        stop()

        let utterance = AVSpeechUtterance(string: clean)
        utterance.voice = AVSpeechSynthesisVoice(language: "he-IL")
        utterance.rate = 0.45
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private func normalizeForTts(_ text: String) -> String {
        text
            .replacingOccurrences(of: "ק.מ.י", with: "קמי")
            .replacingOccurrences(of: "ק מ י", with: "קמי")
            .replacingOccurrences(of: "K.M.I", with: "KAMI", options: .caseInsensitive)
            .replacingOccurrences(of: "K M I", with: "KAMI", options: .caseInsensitive)
            .replacingOccurrences(of: "קמי", with: "קָמִי")
    }
}

extension AssistantTtsManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        onSpeechStarted?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onSpeechFinished?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onSpeechFinished?()
    }
}
