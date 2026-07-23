import Foundation
import Combine
import Shared

final class AiAssistantLogic: ObservableObject {

    private struct FeedbackLogRecord: Codable {
        let messageID: String
        let timestamp: TimeInterval
        let mode: String
        let question: String
        let answer: String
        let feedback: String
    }

    private struct UnresolvedQuestionRecord: Codable {
        let timestamp: TimeInterval
        let mode: String
        let question: String
        let answer: String
    }

    private static let feedbackLogKey =
        "kmi.assistant.feedback_log.v1"

    private static let unresolvedQuestionsKey =
        "kmi.assistant.unresolved_questions.v1"

    private static let maximumLogRecords = 100

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

    private var isEnglish: Bool {
        let defaults = UserDefaults.standard

        let values = [
            defaults.string(forKey: "kmi_app_language") ?? "",
            defaults.string(forKey: "selected_language_code") ?? "",
            defaults.string(forKey: "app_language") ?? "",
            defaults.string(forKey: "initial_language_code") ?? ""
        ]
        .map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        }

        return values.contains("en") ||
            values.contains("english")
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private func sanitizeAssistantMarkup(_ source: String) -> String {
        var result = source

        let patterns = [
            #"(?i)\[\[\s*/?\s*RED_BOLD\s*\]\]"#,
            #"(?i)\[\s*/?\s*RED_BOLD\s*\]"#,
            #"(?i)\[\[\s*/?\s*BOLD\s*\]\]"#,
            #"(?i)\[\s*/?\s*BOLD\s*\]"#,
            #"(?i)\[\[\s*/?\s*RED\s*\]\]"#,
            #"(?i)\[\s*/?\s*RED\s*\]"#
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

        return result.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    func setMode(_ mode: AssistantMode?) {
        selectedMode = mode
        messages = []
        lastAiAnswer = nil
        isThinking = false
    }

    func setFeedback(
        messageID: UUID,
        feedback: AssistantFeedback
    ) {
        guard let index = messages.firstIndex(
            where: { $0.id == messageID }
        ) else {
            return
        }

        let current = messages[index]

        guard !current.fromUser else {
            return
        }

        let updatedFeedback: AssistantFeedback =
            current.feedback == feedback
            ? .none
            : feedback

        let updatedMessage = AiMessage(
            id: current.id,
            fromUser: current.fromUser,
            text: current.text,
            relatedQuestion: current.relatedQuestion,
            feedback: updatedFeedback
        )

        messages[index] = updatedMessage

        persistFeedback(
            for: updatedMessage
        )
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

        defer {
            isThinking = false
        }

        let preferredBelt = AssistantBeltDetector.detect(q)
        let resolvedMode = selectedMode ?? .exercise

        let rawAnswer: String

        switch resolvedMode {

        case .trainings:
            rawAnswer = AssistantTrainingKnowledge.generateAnswer(
                question: q,
                memory: memory,
                dataSource: trainingDataSource
            )

        case .exercise:
            if let exact = AssistantExerciseExplanationKnowledge.answer(
                question: q,
                preferredBelt: preferredBelt,
                searchEngine: searchEngine
            ),
               !exact.trimmingCharacters(
                    in: .whitespacesAndNewlines
               ).isEmpty {

                rawAnswer = exact

            } else if let direct = getExerciseExplanation?(q),
                      !direct.trimmingCharacters(
                        in: .whitespacesAndNewlines
                      ).isEmpty {

                rawAnswer = direct

            } else {
                rawAnswer = tr(
                    """
                    לא מצאתי כרגע הסבר מדויק לתרגיל הזה.
                    נסה לומר את שם התרגיל המדויק או לציין חגורה.
                    """,
                    """
                    I couldn't find an exact explanation for this exercise.
                    Try saying the exact exercise name or specifying a belt.
                    """
                )
            }

        case .kmiMaterial:
            /*
             * בקשה מפורשת להגנות חיצוניות עם חגורה:
             * מעדיפים את הרשימה הישירה שסופקה למסך.
             */
            if let belt = preferredBelt,
               isExternalDefenseQuestion(q),
               let externalDefenses =
                    getExternalDefenses?(belt),
               !externalDefenses.isEmpty {

                let list = externalDefenses
                    .map { "• \($0)" }
                    .joined(separator: "\n")

                let beltName =
                    AssistantBeltDetector.localizedName(
                        belt,
                        isEnglish: isEnglish
                    )

                rawAnswer = tr(
                    """
                    ההגנות החיצוניות בחגורה \(beltName):

                    \(list)
                    """,
                    """
                    External defenses for \(beltName):

                    \(list)
                    """
                )

            /*
             * אם המשתמש ביקש הסבר לתרגיל,
             * מחזירים את ההסבר הרשמי גם מתוך מצב חומר.
             */
            } else if let explanation =
                AssistantExerciseExplanationKnowledge.answer(
                    question: q,
                    preferredBelt: preferredBelt,
                    searchEngine: searchEngine
                ),
               !explanation.trimmingCharacters(
                    in: .whitespacesAndNewlines
               ).isEmpty,
               isExplanationQuestion(q) {

                rawAnswer = explanation

            /*
             * בכל בקשת חומר אחרת משתמשים במנוע
             * AssistantKmiMaterialKnowledge האמיתי.
             */
            } else if let materialResult =
                AssistantKmiMaterialKnowledge.answer(
                    question: q,
                    preferredBelt: preferredBelt,
                    searchEngine: searchEngine
                ),
               !materialResult.text.trimmingCharacters(
                    in: .whitespacesAndNewlines
               ).isEmpty {

                rawAnswer = materialResult.text

            } else if let direct =
                getExerciseExplanation?(q)?
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
               !direct.isEmpty {

                rawAnswer = direct

            } else {
                rawAnswer = tr(
                    """
                    לא מצאתי התאמה מדויקת בחומר ק.מ.י.
                    נסה לציין שם תרגיל, נושא או חגורה.
                    """,
                    """
                    I couldn't find an exact match in the KMI material.
                    Try specifying an exercise, topic, or belt.
                    """
                )
            }
        }

        let answer = sanitizeAssistantMarkup(rawAnswer)

        lastAiAnswer = answer

        messages.append(
            AiMessage(
                fromUser: false,
                text: answer,
                relatedQuestion: q
            )
        )

        if isUnresolvedAnswer(answer) {
            persistUnresolvedQuestion(
                question: q,
                answer: answer
            )
        }

        return answer
    }

    private func persistFeedback(
        for message: AiMessage
    ) {
    let defaults = UserDefaults.standard
    let messageID = message.id.uuidString

    var records: [FeedbackLogRecord] =
        decodeRecords(
            FeedbackLogRecord.self,
            key: Self.feedbackLogKey
        )

    /*
     * מסירים רשומה קודמת של אותה הודעה.
     * כך שינוי 👍 ל־👎 אינו יוצר כפילות.
     */
    records.removeAll {
        $0.messageID == messageID
    }

    if message.feedback != .none {
        let cleanQuestion =
            message.relatedQuestion?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                ) ?? ""

        let cleanAnswer =
            sanitizeAssistantMarkup(
                message.text
            )

        records.append(
            FeedbackLogRecord(
                messageID: messageID,
                timestamp:
                    Date().timeIntervalSince1970,
                mode:
                    selectedMode?.rawValue ??
                    AssistantMode.exercise.rawValue,
                question: cleanQuestion,
                answer: cleanAnswer,
                feedback:
                    message.feedback.rawValue
            )
        )
    }

    records = Array(
        records
            .sorted {
                $0.timestamp < $1.timestamp
            }
            .suffix(Self.maximumLogRecords)
    )

    if records.isEmpty {
        defaults.removeObject(
            forKey: Self.feedbackLogKey
        )
        return
    }

    guard let data = try? JSONEncoder()
        .encode(records) else {
        return
    }

    defaults.set(
        data,
        forKey: Self.feedbackLogKey
    )
}

private func persistUnresolvedQuestion(
    question: String,
    answer: String
) {
    let cleanQuestion = question
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )

    let cleanAnswer =
        sanitizeAssistantMarkup(answer)

    guard !cleanQuestion.isEmpty else {
        return
    }

    let mode =
        selectedMode?.rawValue ??
        AssistantMode.exercise.rawValue

    var records: [UnresolvedQuestionRecord] =
        decodeRecords(
            UnresolvedQuestionRecord.self,
            key: Self.unresolvedQuestionsKey
        )

    let normalizedQuestion =
        normalizedLogText(cleanQuestion)

    /*
     * אותה שאלה באותו מצב נשמרת פעם אחת בלבד.
     * הרשומה החדשה מחליפה את הישנה.
     */
    records.removeAll {
        $0.mode == mode &&
        normalizedLogText($0.question) ==
            normalizedQuestion
    }

    records.append(
        UnresolvedQuestionRecord(
            timestamp:
                Date().timeIntervalSince1970,
            mode: mode,
            question: cleanQuestion,
            answer: cleanAnswer
        )
    )

    records = Array(
        records
            .sorted {
                $0.timestamp < $1.timestamp
            }
            .suffix(Self.maximumLogRecords)
    )

    guard let data = try? JSONEncoder()
        .encode(records) else {
        return
    }

    UserDefaults.standard.set(
        data,
        forKey: Self.unresolvedQuestionsKey
    )
}

private func decodeRecords<T: Decodable>(
    _ type: T.Type,
    key: String
) -> [T] {
    guard let data = UserDefaults.standard
        .data(forKey: key),
          let records = try? JSONDecoder()
            .decode([T].self, from: data) else {
        return []
    }

    return records
}

private func isUnresolvedAnswer(
    _ answer: String
) -> Bool {
    let normalized = normalizedLogText(answer)

    let unresolvedPhrases = [
        "לא מצאתי",
        "לא הצלחתי למצוא",
        "אין כרגע הסבר",
        "לא נמצאו אימונים",
        "לא מצאתי אימון",
        "לא מצאתי התאמה",
        "i couldn't find",
        "i could not find",
        "no matching",
        "no explanation",
        "no training sessions",
        "there is currently no explanation"
    ]

    return unresolvedPhrases.contains {
        normalized.contains($0)
    }
}

    private func normalizedLogText(
        _ value: String
    ) -> String {
        value
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()
            .replacingOccurrences(of: "־", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
    }
}

private func isExplanationQuestion(
    _ question: String
) -> Bool {
    let text = question
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

    let triggers = [
        "הסבר",
        "תסביר",
        "תסבירי",
        "פירוט",
        "איך עושים",
        "איך לבצע",
        "איך מבצעים",
        "שלב שלב",
        "צעד צעד",
        "דגשים",
        "טיפים",
        "explain",
        "how do i perform",
        "how to perform",
        "step by step"
    ]

    return triggers.contains {
        text.contains($0)
    }
}

private func isExternalDefenseQuestion(
    _ question: String
) -> Bool {
    let normalized = question
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
        .replacingOccurrences(of: "־", with: "-")
        .replacingOccurrences(of: "–", with: "-")
        .replacingOccurrences(of: "—", with: "-")

    return normalized.contains("הגנות חיצוניות") ||
        normalized.contains("הגנה חיצונית") ||
        normalized.contains("external defense") ||
        normalized.contains("external defences")
}
