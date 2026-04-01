import Foundation
import Combine
import Shared

final class AiAssistantLogic: ObservableObject {

    @Published var messages: [AiMessage] = []
    @Published var isThinking: Bool = false
    @Published var lastAiAnswer: String? = nil
    @Published var selectedMode: AssistantMode? = nil

    let memory: AssistantMemory
    let searchEngine: AssistantSearchEngine
    let trainingDataSource: AssistantTrainingDataSource

    init(
        memory: AssistantMemory = AssistantMemory(),
        searchEngine: AssistantSearchEngine,
        trainingDataSource: AssistantTrainingDataSource
    ) {
        self.memory = memory
        self.searchEngine = searchEngine
        self.trainingDataSource = trainingDataSource
    }

    func setMode(_ mode: AssistantMode?) {
        selectedMode = mode
        messages = []
        lastAiAnswer = nil
        isThinking = false
    }

    @discardableResult
    func sendQuestion(
        _ question: String,
        contextLabel: String? = nil,
        getExternalDefenses: ((Belt) -> [String])? = nil,
        getExerciseExplanation: ((String) -> String?)? = nil
    ) -> String {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return "" }

        messages.append(
            AiMessage(
                fromUser: true,
                text: q
            )
        )

        isThinking = true

        let preferredBelt = AssistantBeltDetector.detect(q)
        let resolvedMode = selectedMode ?? .exercise

        let answer: String

        switch resolvedMode {

        case .trainings:
            answer = AssistantTrainingKnowledge.generateAnswer(
                question: q,
                memory: memory,
                dataSource: trainingDataSource
            )

        case .exercise:
            if let exact = AssistantExerciseExplanationKnowledge.answer(
                question: q,
                preferredBelt: preferredBelt,
                searchEngine: searchEngine
            ) {
                answer = exact
            } else if let direct = getExerciseExplanation?(q),
                      !direct.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                answer = direct
            } else {
                answer =
                    "לא מצאתי כרגע הסבר מדויק לתרגיל הזה.\n" +
                    "נסה לכתוב שם תרגיל מדויק יותר או לציין חגורה."
            }

        case .kmiMaterial:
            answer =
                "מצב חומר ק.מ.י פעיל.\n" +
                "כתוב נושא, תת־נושא או שם תרגיל ואני אחפש אותו בשלב הבא."
        }

        lastAiAnswer = answer

        messages.append(
            AiMessage(
                fromUser: false,
                text: answer,
                relatedQuestion: q
            )
        )

        isThinking = false
        return answer
    }
}
