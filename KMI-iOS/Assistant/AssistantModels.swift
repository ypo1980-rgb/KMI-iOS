import Foundation
import Shared

enum AssistantMode: String, CaseIterable, Codable {
    case exercise
    case trainings
    case kmiMaterial
}

enum AssistantFeedback: String, Codable {
    case none
    case like
    case unlike
}

struct AiMessage: Identifiable, Hashable, Codable {
    let id: UUID
    let fromUser: Bool
    let text: String
    let relatedQuestion: String?
    let feedback: AssistantFeedback

    init(
        id: UUID = UUID(),
        fromUser: Bool,
        text: String,
        relatedQuestion: String? = nil,
        feedback: AssistantFeedback = .none
    ) {
        self.id = id
        self.fromUser = fromUser
        self.text = text
        self.relatedQuestion = relatedQuestion
        self.feedback = feedback
    }
}

enum VoiceNavCommand: Hashable {
    case openHome
    case openTraining
    case openNextExercise
    case custom(raw: String)
}

enum AssistantIntent: String, Codable {
    case askSchedule
    case askNextTraining
    case askWhatToday
    case askTime
    case askCoach
    case askLocation
    case askDuration
    case askEquipment
    case askGeneral
    case askWeeklyCount
    case askSpecialWeek
    case unknown
}

struct AssistantSearchHit: Hashable {
    let belt: Belt
    let topic: String
    let item: String?
}

struct TrainingRow: Hashable, Identifiable {
    let id: UUID
    let branchName: String
    let groupName: String
    let dayName: String
    let timeRange: String
    let location: String
    let coachName: String
    let startAtMillis: Int64

    init(
        id: UUID = UUID(),
        branchName: String,
        groupName: String,
        dayName: String,
        timeRange: String,
        location: String,
        coachName: String,
        startAtMillis: Int64
    ) {
        self.id = id
        self.branchName = branchName
        self.groupName = groupName
        self.dayName = dayName
        self.timeRange = timeRange
        self.location = location
        self.coachName = coachName
        self.startAtMillis = startAtMillis
    }
}

protocol AssistantSearchEngine {
    func search(query: String, belt: Belt?) -> [AssistantSearchHit]
}

protocol AssistantTrainingDataSource {
    func allTrainings() -> [TrainingRow]
}

enum AssistantBeltDetector {

    nonisolated static func detect(
        _ text: String
    ) -> Belt? {
        let normalized = text
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

        let beltTerms: [(belt: Belt, terms: [String])] = [
            (
                .white,
                [
                    "חגורה לבנה",
                    "לבן",
                    "לבנה",
                    "white belt",
                    "belt white"
                ]
            ),
            (
                .yellow,
                [
                    "חגורה צהובה",
                    "צהוב",
                    "צהובה",
                    "yellow belt",
                    "belt yellow"
                ]
            ),
            (
                .orange,
                [
                    "חגורה כתומה",
                    "כתום",
                    "כתומה",
                    "orange belt",
                    "belt orange"
                ]
            ),
            (
                .green,
                [
                    "חגורה ירוקה",
                    "ירוק",
                    "ירוקה",
                    "green belt",
                    "belt green"
                ]
            ),
            (
                .blue,
                [
                    "חגורה כחולה",
                    "כחול",
                    "כחולה",
                    "blue belt",
                    "belt blue"
                ]
            ),
            (
                .brown,
                [
                    "חגורה חומה",
                    "חום",
                    "חומה",
                    "brown belt",
                    "belt brown"
                ]
            ),
            (
                .black,
                [
                    "חגורה שחורה",
                    "שחור",
                    "שחורה",
                    "black belt",
                    "belt black"
                ]
            )
        ]

        for entry in beltTerms {
            if entry.terms.contains(
                where: { normalized.contains($0) }
            ) {
                return entry.belt
            }
        }

        return nil
    }

    nonisolated static func hebrewName(
        _ belt: Belt
    ) -> String {
        switch belt {
        case .white:
            return "לבנה"

        case .yellow:
            return "צהובה"

        case .orange:
            return "כתומה"

        case .green:
            return "ירוקה"

        case .blue:
            return "כחולה"

        case .brown:
            return "חומה"

        case .black:
            return "שחורה"

        default:
            return ""
        }
    }

    nonisolated static func englishName(
        _ belt: Belt
    ) -> String {
        switch belt {
        case .white:
            return "White"

        case .yellow:
            return "Yellow"

        case .orange:
            return "Orange"

        case .green:
            return "Green"

        case .blue:
            return "Blue"

        case .brown:
            return "Brown"

        case .black:
            return "Black"

        default:
            return ""
        }
    }

    nonisolated static func localizedName(
        _ belt: Belt,
        isEnglish: Bool
    ) -> String {
        isEnglish
            ? englishName(belt)
            : hebrewName(belt)
    }
}

enum AssistantVoiceCommandParser {
    static func parse(_ raw: String) -> VoiceNavCommand? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if text.hasPrefix("יובל") {
            text = String(text.dropFirst("יובל".count))
                .trimmingCharacters(
                    in: CharacterSet(charactersIn: ", ").union(.whitespacesAndNewlines)
                )
        }

        if text.contains("חזור למסך הבית") ||
            text.contains("חזור לבית") ||
            text.contains("מסך הבית") {
            return .openHome
        }

        if text.contains("פתח אימון") ||
            text.contains("פתח את האימון") {
            return .openTraining
        }

        if text.contains("התרגיל הבא") ||
            text.contains("פתח תרגיל הבא") {
            return .openNextExercise
        }

        return nil
    }
}
