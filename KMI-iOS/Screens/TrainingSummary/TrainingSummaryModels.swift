import Foundation
import Shared

enum SummaryAuthorRole: String, Codable, CaseIterable {
    case coach = "COACH"
    case trainee = "TRAINEE"

    var heb: String {
        switch self {
        case .coach: return "מאמן"
        case .trainee: return "מתאמן"
        }
    }
}

struct TrainingSummaryExerciseEntity: Identifiable, Codable, Hashable {
    let exerciseId: String
    var name: String
    var topic: String
    var difficulty: Int?
    var highlight: String
    var homePractice: Bool

    var id: String { exerciseId }
}

struct TrainingSummaryEntity: Identifiable, Codable, Hashable {
    var id: String
    var ownerUid: String
    var ownerRole: SummaryAuthorRole

    var dateIso: String
    var branchId: String
    var branchName: String

    var coachUid: String
    var coachName: String

    var groupKey: String
    var exercises: [TrainingSummaryExerciseEntity]
    var notes: String

    var createdAtMs: Int64
    var updatedAtMs: Int64
}

struct SelectedExerciseUi: Identifiable, Hashable {
    let exerciseId: String
    let name: String
    let topic: String
    var difficulty: Int? = nil
    var highlight: String = ""
    var homePractice: Bool = false

    var id: String { exerciseId }
}

struct TrainingSummaryUiState {
    var isCoach: Bool
    var ownerUid: String
    var ownerRole: SummaryAuthorRole

    var dateIso: String
    var branchId: String = ""
    var branchName: String = ""
    var coachUid: String = ""
    var coachName: String = ""
    var groupKey: String = ""

    var selectedBelt: Belt
    var searchQuery: String = ""
    var selected: [String: SelectedExerciseUi] = [:]

    var notes: String = ""
    var isSaving: Bool = false

    var lastSaveMsg: String? = nil
    var lastSaveWasError: Bool = false
    var saveEventId: Int64 = 0

    var summaryDaysInCalendarMonth: Set<String> = []
}

struct ExercisePickItem: Identifiable, Hashable {
    let exerciseId: String
    let name: String
    let topic: String

    var id: String { exerciseId }
}

extension TrainingSummaryUiState {
    var shareText: String {
        let sortedExercises = selected.values.sorted { $0.name < $1.name }

        var lines: [String] = []
        lines.append("סיכום אימון")
        lines.append("סוג משתמש: \(ownerRole.heb)")
        lines.append("תאריך: \(dateIso)")

        if !branchName.trimmed().isEmpty {
            lines.append("סניף: \(branchName.trimmed())")
        }

        if !coachName.trimmed().isEmpty {
            lines.append("מאמן: \(coachName.trimmed())")
        }

        if !groupKey.trimmed().isEmpty {
            lines.append("קבוצה: \(groupKey.trimmed())")
        }

        lines.append("")

        if sortedExercises.isEmpty {
            lines.append("תרגילים: לא נוספו תרגילים")
        } else {
            lines.append("תרגילים:")
            for item in sortedExercises {
                lines.append("- \(item.name)")

                if !item.topic.trimmed().isEmpty {
                    lines.append("  נושא: \(item.topic)")
                }

                if let difficulty = item.difficulty {
                    lines.append("  רמת קושי: \(difficulty)")
                }

                if !item.highlight.trimmed().isEmpty {
                    lines.append("  דגשים: \(item.highlight.trimmed())")
                }

                lines.append("  עבודה בבית: \(item.homePractice ? "כן" : "לא")")
                lines.append("")
            }
        }

        let cleanNotes = notes.trimmed()
        lines.append("סיכום כללי:")
        lines.append(cleanNotes.isEmpty ? "לא נכתב סיכום כללי" : cleanNotes)

        return lines.joined(separator: "\n")
    }
}

enum TrainingSummaryCatalog {
    static let belts: [Belt] = [.white, .yellow, .orange, .green, .blue, .brown, .black]

    static let data: [Belt: [String: [String: [String]]]] = [
        .yellow: [
            "עמידות": [
                "בסיס": ["עמידת מוצא", "מעבר מעמידה לפתיחה", "שמירת מרחק"]
            ],
            "עבודת ידיים": [
                "בסיס": ["אגרוף ישר", "מגל", "סנוקרת", "מרפק"]
            ]
        ],
        .orange: [
            "הגנות": [
                "פנימיות": ["הגנה פנימית לאגרוף", "הגנה פנימית למגל"],
                "חיצוניות": ["הגנה חיצונית לאגרוף", "הגנה חיצונית למגל"]
            ],
            "שחרורים": [
                "אחיזות": ["שחרור מאחיזת יד", "שחרור מחניקה קדמית"]
            ]
        ],
        .green: [
            "בעיטות": [
                "בסיס": ["בעיטה קדמית", "בלימת בעיטה", "יציאה מקו התקפה"]
            ],
            "קרב מגע": [
                "שילובים": ["שילוב אגרוף-בעיטה", "תגובה למתקפה כפולה"]
            ]
        ],
        .blue: [
            "איומי נשק": [
                "סכין": ["איום סכין ישר", "איום סכין מהצד"],
                "מקל": ["הגנה מול מקל"]
            ]
        ],
        .brown: [
            "קרקע": [
                "בסיס": ["יציאה מהרכבה", "בעיטות מהקרקע", "קימה טקטית"]
            ]
        ],
        .black: [
            "הדרכה": [
                "מתודיקה": ["בניית שיעור", "ניהול אימון", "הדגמה ותיקון"]
            ]
        ],
        .white: [
            "כללי": [
                "בסיס": ["חימום", "קואורדינציה", "משמעת אימון"]
            ]
        ]
    ]

    static func topics(for belt: Belt) -> [String] {
        let keys = data[belt].map { Array($0.keys) } ?? []
        return keys.sorted()
    }

    static func subTopics(for belt: Belt, topic: String) -> [String] {
        let keys = data[belt]?[topic].map { Array($0.keys) } ?? []
        return keys.sorted()
    }

    static func items(for belt: Belt, topic: String, subTopic: String?) -> [String] {
        let sub = (subTopic ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if !sub.isEmpty {
            return data[belt]?[topic]?[sub] ?? []
        }

        let all = data[belt]?[topic]?.values.flatMap { $0 } ?? []
        return all
    }
}

private extension String {
    func trimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
