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
    var includeExplanation: Bool? = nil

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
    var includeExplanation: Bool = false

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
    @MainActor
    var shareText: String {
        let language = UserDefaults.standard
            .string(forKey: "kmi_app_language")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return makeShareText(
            isEnglish: language == "en" || language == "english",
            privacyEnabled: DemoPrivacy.shared.isEnabled
        )
    }

    private func exportableExerciseDescription(
        for name: String,
        isEnglish: Bool
    ) -> String? {
        switch name.trimmed() {
        case "חימום":
            return isEnglish
                ? "Gradually increase your movement at a comfortable pace before the main session."
                : "הגבירו את התנועה בהדרגה ובקצב נוח לפני החלק העיקרי של האימון."

        case "קואורדינציה":
            return isEnglish
                ? "Practice simple movement sequences at a steady pace, focusing on rhythm and balance."
                : "תרגלו רצפי תנועה פשוטים בקצב אחיד, תוך תשומת לב לקצב ולשיווי המשקל."

        default:
            return nil
        }
    }

    func makeShareText(
        isEnglish: Bool,
        privacyEnabled: Bool,
        onBeltHeading: ((Belt?, NSRange) -> Void)? = nil
    ) -> String {
        func tr(_ hebrew: String, _ english: String) -> String {
            isEnglish ? english : hebrew
        }

        let belts = TrainingSummaryCatalog.belts

        func beltIndex(for exerciseId: String) -> Int {
            let beltId = exerciseId
                .split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let beltId else {
                return belts.count
            }

            return belts.firstIndex {
                $0.id.caseInsensitiveCompare(beltId) == .orderedSame
            } ?? belts.count
        }

        let sortedExercises = selected.values
            .map { item in
                (item: item, beltIndex: beltIndex(for: item.exerciseId))
            }
            .sorted { left, right in
                if left.beltIndex != right.beltIndex {
                    return left.beltIndex < right.beltIndex
                }

                let nameOrder = left.item.name.localizedCaseInsensitiveCompare(
                    right.item.name
                )

                if nameOrder == .orderedSame {
                    return left.item.exerciseId < right.item.exerciseId
                }

                return nameOrder == .orderedAscending
            }

        let role = ownerRole == .coach
            ? tr("מאמן", "Coach")
            : tr("מתאמן", "Trainee")

        var lines: [String] = [
            tr("סיכום אימון", "Training summary"),
            tr("סוג משתמש: \(role)", "Author role: \(role)"),
            tr("תאריך: \(dateIso)", "Date: \(dateIso)")
        ]

        let cleanBranch = branchName.trimmed()

        if !cleanBranch.isEmpty {
            lines.append(
                tr(
                    "סניף: \(cleanBranch)",
                    "Branch: \(cleanBranch)"
                )
            )
        }

        let cleanCoach = coachName.trimmed()

        if !cleanCoach.isEmpty {
            let displayedCoach = privacyEnabled
                ? tr("מאמן", "Coach")
                : TrainingCatalogIOS.displayCoach(
                    cleanCoach,
                    isEnglish: isEnglish
                )

            lines.append(
                tr(
                    "מאמן: \(displayedCoach)",
                    "Coach: \(displayedCoach)"
                )
            )
        }

        let cleanGroup = groupKey.trimmed()

        if !cleanGroup.isEmpty {
            let displayedGroup = TrainingCatalogIOS.displayGroup(
                cleanGroup,
                isEnglish: isEnglish
            )

            lines.append(
                tr(
                    "קבוצה: \(displayedGroup)",
                    "Group: \(displayedGroup)"
                )
            )
        }

        lines.append("")

        if sortedExercises.isEmpty {
            lines.append(
                tr(
                    "תרגילים: לא נוספו תרגילים",
                    "Exercises: No exercises added"
                )
            )
        } else {
            lines.append(tr("תרגילים:", "Exercises:"))

            var previousBeltIndex: Int?

            for entry in sortedExercises {
                let item = entry.item

                if entry.beltIndex != previousBeltIndex {
                    let belt = belts.indices.contains(entry.beltIndex)
                        ? belts[entry.beltIndex]
                        : nil

                    let heading = belt.map { isEnglish ? $0.en : $0.heb }
                        ?? tr("ללא חגורה", "No belt")

                    if let onBeltHeading {
                        let headingStart = lines.reduce(0) { offset, line in
                            offset + line.utf16.count + 1
                        }

                        onBeltHeading(
                            belt,
                            NSRange(location: headingStart, length: heading.utf16.count)
                        )
                    }

                    lines.append(heading)
                    previousBeltIndex = entry.beltIndex
                }

                lines.append("- \(item.name)")

                let topic = item.topic.trimmed()

                if !topic.isEmpty {
                    lines.append(
                        tr(
                            "  נושא: \(topic)",
                            "  Topic: \(topic)"
                        )
                    )
                }

                if let difficulty = item.difficulty {
                    lines.append(
                        tr(
                            "  רמת קושי: \(difficulty)",
                            "  Difficulty: \(difficulty)"
                        )
                    )
                }

                if item.includeExplanation,
                   let description = exportableExerciseDescription(
                       for: item.name,
                       isEnglish: isEnglish
                   ) {
                    lines.append(
                        tr(
                            "  הסבר: \(description)",
                            "  Explanation: \(description)"
                        )
                    )
                }

                let highlight = item.highlight.trimmed()

                if !highlight.isEmpty {
                    lines.append(
                        tr(
                            "  דגשים: \(highlight)",
                            "  Highlights: \(highlight)"
                        )
                    )
                }

                let homePractice = item.homePractice
                    ? tr("כן", "Yes")
                    : tr("לא", "No")

                lines.append(
                    tr(
                        "  עבודה בבית: \(homePractice)",
                        "  Home practice: \(homePractice)"
                    )
                )
                lines.append("")
            }
        }

        let cleanNotes = notes.trimmed()

        lines.append(tr("סיכום כללי:", "General summary:"))
        lines.append(
            cleanNotes.isEmpty
                ? tr(
                    "לא נכתב סיכום כללי",
                    "No general summary provided"
                )
                : cleanNotes
        )

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
