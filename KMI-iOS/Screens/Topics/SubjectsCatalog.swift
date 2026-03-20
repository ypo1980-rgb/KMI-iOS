import Foundation
import Shared

enum DefenseKind: String {
    case internalKind
    case externalKind
    case none

    static func fromId(_ id: String) -> DefenseKind {
        if id.hasPrefix("def_internal") { return .internalKind }
        if id.hasPrefix("def_external") { return .externalKind }
        return .none
    }
}

struct SubjectTopic: Identifiable, Hashable {
    let id: String
    let titleHeb: String
    let description: String
    let belts: [Belt]
    let topicsByBelt: [Belt: [String]]
    let subTopicHint: String?

    // OR
    let includeItemKeywords: [String]
    // AND
    let requireAllItemKeywords: [String]
    let excludeItemKeywords: [String]

    var defenseKind: DefenseKind {
        DefenseKind.fromId(id)
    }

    init(
        id: String,
        titleHeb: String,
        description: String = "",
        belts: [Belt],
        topicsByBelt: [Belt: [String]],
        subTopicHint: String? = nil,
        includeItemKeywords: [String] = [],
        requireAllItemKeywords: [String] = [],
        excludeItemKeywords: [String] = []
    ) {
        self.id = id
        self.titleHeb = titleHeb
        self.description = description
        self.belts = belts
        self.topicsByBelt = topicsByBelt
        self.subTopicHint = subTopicHint
        self.includeItemKeywords = includeItemKeywords
        self.requireAllItemKeywords = requireAllItemKeywords
        self.excludeItemKeywords = excludeItemKeywords
    }
}

enum TopicsBySubjectRegistry {

    static let all: [SubjectTopic] = [

        // ================== בלימות וגלגולים ==================
        SubjectTopic(
            id: "topic_breakfalls_rolls",
            titleHeb: "בלימות וגלגולים",
            description: "בלימות וגלגולים בסיסיים ומתקדמים לעבודה בטוחה.",
            belts: [.yellow, .orange, .green, .blue, .brown],
            topicsByBelt: [
                .yellow: ["בלימות וגלגולים"],
                .orange: ["בלימות וגלגולים"],
                .green:  ["בלימות וגלגולים"],
                .blue:   ["בלימות וגלגולים"],
                .brown:  ["בלימות וגלגולים"]
            ]
        ),

        // ================== עמידת מוצא ==================
        SubjectTopic(
            id: "topic_ready_stance",
            titleHeb: "עמידת מוצא",
            description: "עמידת מוצא, תנועה בסיסית והכנת הגוף לעבודה.",
            belts: [.yellow, .orange, .green, .blue, .brown, .black],
            topicsByBelt: [
                .yellow: ["עמידת מוצא"],
                .orange: ["עמידת מוצא"],
                .green:  ["עמידת מוצא"],
                .blue:   ["עמידת מוצא"],
                .brown:  ["עמידת מוצא"],
                .black:  ["עמידת מוצא"]
            ]
        ),

        // ================== הכנה לעבודת קרקע ==================
        SubjectTopic(
            id: "topic_ground_prep",
            titleHeb: "הכנה לעבודת קרקע",
            description: "מעברים, הכנה בסיסית ושליטה ראשונית לעבודת קרקע.",
            belts: [.orange, .green, .blue, .brown, .black],
            topicsByBelt: [
                .orange: ["הכנה לעבודת קרקע"],
                .green:  ["הכנה לעבודת קרקע"],
                .blue:   ["הכנה לעבודת קרקע"],
                .brown:  ["הכנה לעבודת קרקע"],
                .black:  ["הכנה לעבודת קרקע"]
            ]
        ),

        // ================== קוואליר ==================
        SubjectTopic(
            id: "topic_kawalr",
            titleHeb: "קוואליר",
            description: "עקרונות קוואליר ותרגול תנועות/כניסות רלוונטיות.",
            belts: [.orange, .green, .blue, .brown, .black],
            topicsByBelt: [
                .orange: ["קוואליר"],
                .green:  ["קוואליר"],
                .blue:   ["קוואליר"],
                .brown:  ["קוואליר"],
                .black:  ["קוואליר"]
            ]
        ),

        // ================== הגנות פנימיות – אגרופים ==================
        SubjectTopic(
            id: "def_internal_punches",
            titleHeb: "הגנות פנימיות – אגרופים",
            description: "הגנות פנימיות נגד אגרופים.",
            belts: [.yellow, .orange, .green, .blue, .brown, .black],
            topicsByBelt: [
                .yellow: ["הגנות"],
                .orange: ["הגנות"],
                .green:  ["הגנות"],
                .blue:   ["הגנות"],
                .brown:  ["הגנות"],
                .black:  ["הגנות"]
            ],
            includeItemKeywords: ["def:internal:punch"]
        ),

        // ================== הגנות פנימיות – בעיטות ==================
        SubjectTopic(
            id: "def_internal_kicks",
            titleHeb: "הגנות פנימיות – בעיטות",
            description: "הגנות פנימיות נגד בעיטות.",
            belts: [.yellow, .orange, .green, .blue, .brown, .black],
            topicsByBelt: [
                .yellow: ["הגנות"],
                .orange: ["הגנות"],
                .green:  ["הגנות"],
                .blue:   ["הגנות"],
                .brown:  ["הגנות"],
                .black:  ["הגנות"]
            ],
            includeItemKeywords: ["def:internal:kick"]
        ),

        // ================== הגנות חיצוניות – אגרופים ==================
        SubjectTopic(
            id: "def_external_punches",
            titleHeb: "הגנות חיצוניות – אגרופים",
            description: "הגנות חיצוניות נגד אגרופים.",
            belts: [.yellow, .orange, .green, .blue, .brown, .black],
            topicsByBelt: [
                .yellow: ["הגנות"],
                .orange: ["הגנות"],
                .green:  ["הגנות"],
                .blue:   ["הגנות"],
                .brown:  ["הגנות"],
                .black:  ["הגנות"]
            ],
            includeItemKeywords: ["def:external:punch"]
        ),

        // ================== הגנות חיצוניות – בעיטות ==================
        SubjectTopic(
            id: "def_external_kicks",
            titleHeb: "הגנות חיצוניות – בעיטות",
            description: "הגנות חיצוניות נגד בעיטות.",
            belts: [.yellow, .orange, .green, .blue, .brown, .black],
            topicsByBelt: [
                .yellow: ["הגנות"],
                .orange: ["הגנות"],
                .green:  ["הגנות"],
                .blue:   ["הגנות"],
                .brown:  ["הגנות"],
                .black:  ["הגנות"]
            ],
            includeItemKeywords: ["def:external:kick"]
        ),

        // ================== בעיטות ==================
        SubjectTopic(
            id: "kicks",
            titleHeb: "בעיטות",
            description: "בעיטות בסיסיות ומתקדמות – קדמית, עגולה, צד, בניתור ועוד.",
            belts: [.yellow, .orange, .green, .blue, .brown, .black],
            topicsByBelt: [
                .yellow: ["בעיטות"],
                .orange: ["בעיטות"],
                .green:  ["בעיטות"],
                .blue:   ["בעיטות"],
                .brown:  ["בעיטות"],
                .black:  ["בעיטות"]
            ]
        ),

        // ================== חביקות גוף ==================
        SubjectTopic(
            id: "body_hugs",
            titleHeb: "חביקות גוף",
            description: "שחרורים ותגובות מול חביקות גוף – מלפנים/מאחור, ידיים חופשיות/נעולות ועוד.",
            belts: [.yellow, .orange, .green, .blue, .brown, .black],
            topicsByBelt: [
                .yellow: ["שחרורים"],
                .orange: ["שחרורים"],
                .green:  ["שחרורים"],
                .blue:   ["שחרורים"],
                .brown:  ["שחרורים"],
                .black:  ["שחרורים"]
            ],
            includeItemKeywords: ["חביק", "חיבוק", "חיבוקים", "חביקות"]
        ),

        // ================== שחרורים ==================
        SubjectTopic(
            id: "releases",
            titleHeb: "שחרורים",
            description: "שחרורים מתפיסות ידיים, חניקות וחביקות בכל רמות החגורות.",
            belts: [.yellow, .orange, .green, .blue, .brown, .black],
            topicsByBelt: [
                .yellow: ["שחרורים"],
                .orange: ["שחרורים"],
                .green:  ["שחרורים"],
                .blue:   ["שחרורים"],
                .brown:  ["שחרורים"],
                .black:  ["שחרורים"]
            ]
        ),

        // ================== עבודת ידיים ==================
        SubjectTopic(
            id: "punches",
            titleHeb: "עבודת ידיים",
            description: "עבודת אגרופים ומכות יד – ישרים, מגל, פיסת יד ועוד.",
            belts: [.yellow, .orange],
            topicsByBelt: [
                .yellow: ["עבודת ידיים"],
                .orange: ["עבודת ידיים"]
            ]
        ),

        // ================== הגנות סכין ==================
        SubjectTopic(
            id: "knife_defense",
            titleHeb: "הגנות סכין",
            description: "עקרונות עבודה והגנות מול איום ודקירות בסכין.",
            belts: [.green, .blue, .brown, .black],
            topicsByBelt: [
                .green: ["הגנות סכין"],
                .blue:  ["הגנות סכין"],
                .brown: ["הגנות סכין"],
                .black: ["הגנות סכין"]
            ]
        ),

        // ================== הגנות מאיום אקדח ==================
        SubjectTopic(
            id: "gun_threat_defense",
            titleHeb: "הגנות מאיום אקדח",
            description: "הגנות ואילוצים כנגד איומי אקדח במצבי עמידה שונים.",
            belts: [.brown, .black],
            topicsByBelt: [
                .brown: ["הגנות"],
                .black: ["הגנות"]
            ],
            subTopicHint: "אקדח"
        ),

        // ================== הגנות נגד מקל ==================
        SubjectTopic(
            id: "stick_defense",
            titleHeb: "הגנות נגד מקל",
            description: "עבודה מול תקיפות במקל – בלימות, כניסות וניטרול.",
            belts: [.green, .brown, .black],
            topicsByBelt: [
                .green: ["הגנות"],
                .brown: ["הגנות"],
                .black: ["הגנות"]
            ]
        )
    ]

    static func allSubjects() -> [SubjectTopic] { all }

    static func subjectById(_ id: String) -> SubjectTopic? {
        all.first { $0.id == id }
    }

    static func subjectsForBelt(_ belt: Belt) -> [SubjectTopic] {
        all.filter { $0.belts.contains(belt) }
    }
}
