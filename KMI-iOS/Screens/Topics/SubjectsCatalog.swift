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
    let parentId: String?
    let subTopics: [String]

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
        parentId: String? = nil,
        subTopics: [String] = [],
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
        self.parentId = parentId
        self.subTopics = subTopics
        self.includeItemKeywords = includeItemKeywords
        self.requireAllItemKeywords = requireAllItemKeywords
        self.excludeItemKeywords = excludeItemKeywords
    }
}

enum TopicsBySubjectRegistry {

    private static let orderedTrainingBelts: [Belt] = [
        .yellow,
        .orange,
        .green,
        .blue,
        .brown,
        .black
    ]

    private static let releasesBelts: [Belt] = {
        let releaseSections =
            HardSectionsCatalog.shared.sectionsForSubject(
                subjectId: "releases"
            ) ?? []

        var usedBelts = Set<Belt>()

        func collectBelts(
            from section: HardSectionsCatalog.Section
        ) {
            for group in section.beltGroups where !group.items.isEmpty {
                usedBelts.insert(group.belt)
            }

            for child in section.subSections {
                collectBelts(from: child)
            }
        }

        releaseSections.forEach(collectBelts)

        return orderedTrainingBelts.filter {
            usedBelts.contains($0)
        }
    }()

    private static let releasesTopicsByBelt: [Belt: [String]] = {
        Dictionary(
            uniqueKeysWithValues: releasesBelts.map {
                ($0, ["שחרורים"])
            }
        )
    }()

    static let all: [SubjectTopic] = [

        // ================== עבודת ידיים ==================
        SubjectTopic(
            id: "hands_all",
            titleHeb: "עבודת ידיים",
            description: "מכות יד + מכות מרפק + מכות במקל / רובה",
            belts: [
                .yellow,
                .orange,
                .green,
                .black
            ],
            topicsByBelt: [
                .yellow: [
                    "עבודת ידיים",
                    "מכות ידיים",
                    "מכות יד"
                ],
                .orange: [
                    "עבודת ידיים",
                    "מכות יד",
                    "מכות ידיים"
                ],
                .green: [
                    "מכות מרפק",
                    "מכות במקל / רובה"
                ],
                .black: [
                    "מכות במקל / רובה",
                    "מכות במקל קצר"
                ]
            ],
            subTopics: [
                "מכות יד",
                "מכות מרפק",
                "מכות במקל / רובה"
            ]
        ),

        // ================== עבודת ידיים – מכות יד ==================
        SubjectTopic(
            id: "hands_strikes",
            titleHeb: "מכות יד",
            description: "תרגילי מכות יד מתוך עבודת ידיים",
            belts: [
                .yellow,
                .orange
            ],
            topicsByBelt: [
                .yellow: [
                    "עבודת ידיים",
                    "מכות ידיים",
                    "מכות יד"
                ],
                .orange: [
                    "עבודת ידיים",
                    "מכות יד",
                    "מכות ידיים"
                ]
            ],
            subTopicHint: "מכות יד",
            parentId: "hands_all"
        ),

        // ================== עבודת ידיים – מכות מרפק ==================
        SubjectTopic(
            id: "hands_elbows",
            titleHeb: "מכות מרפק",
            description: "תרגילי מכות מרפק מתוך עבודת ידיים",
            belts: [
                .green
            ],
            topicsByBelt: [
                .green: [
                    "מכות מרפק"
                ]
            ],
            subTopicHint: "מרפק",
            parentId: "hands_all"
        ),

        // ================== עבודת ידיים – מכות במקל / רובה ==================
        SubjectTopic(
            id: "hands_stick_rifle",
            titleHeb: "מכות במקל / רובה",
            description: "תרגילי מכות במקל וברובה מתוך עבודת ידיים",
            belts: [
                .green,
                .black
            ],
            topicsByBelt: [
                .green: [
                    "מכות במקל / רובה"
                ],
                .black: [
                    "מכות במקל / רובה",
                    "מכות במקל קצר"
                ]
            ],
            subTopicHint: "מקל",
            parentId: "hands_all"
        ),

        // ================== בלימות וגלגולים ==================
        SubjectTopic(
            id: "rolls_breakfalls",
            titleHeb: "בלימות וגלגולים",
            belts: [
                .yellow,
                .orange,
                .green,
                .blue
            ],
            topicsByBelt: [
                .yellow: ["כללי"],
                .orange: ["כללי"],
                .green: ["בלימות וגלגולים"],
                .blue: ["בלימות וגלגולים"]
            ],
            includeItemKeywords: [
                "בלימ",
                "גלגול"
            ]
        ),

        // ================== עמידת מוצא ==================
        SubjectTopic(
            id: "topic_ready_stance",
            titleHeb: "עמידת מוצא",
            description: "עמידות מוצא בסיסיות",
            belts: [
                .yellow
            ],
            topicsByBelt: [
                .yellow: ["עמידת מוצא"]
            ]
        ),

        // ================== עבודת קרקע ==================
        SubjectTopic(
            id: "topic_ground_prep",
            titleHeb: "עבודת קרקע",
            description: "הוצאת אגן, הרמת אגן ומוצא לעבודת קרקע",
            belts: [
                .yellow
            ],
            topicsByBelt: [
                .yellow: ["עבודת קרקע"]
            ]
        ),

        // ================== קוואלר ==================
        SubjectTopic(
            id: "topic_kavaler",
            titleHeb: "קוואלר",
            description: "תרגילי קוואלר",
            belts: [
                .green
            ],
            topicsByBelt: [
                .green: ["קוואלר"]
            ]
        ),

        // ================== הגנות – נושא אב ==================
        SubjectTopic(
            id: "defenses",
            titleHeb: "הגנות",
            description: "הגנות פנימיות, חיצוניות, בעיטות, סכין, אקדח, מקל ומספר תוקפים",
            belts: [
                .yellow,
                .orange,
                .green,
                .blue,
                .brown,
                .black
            ],
            topicsByBelt: [
                .yellow: ["הגנות"],
                .orange: ["הגנות"],
                .green: ["הגנות"],
                .blue: ["הגנות"],
                .brown: ["הגנות"],
                .black: ["הגנות"]
            ]
        ),

        // ================== הגנות פנימיות – אגרופים ==================
        SubjectTopic(
            id: "def_internal_punches",
            titleHeb: "הגנות פנימיות – אגרופים",
            description: "הגנות פנימיות נגד אגרופים.",
            belts: [
                .yellow,
                .orange,
                .green,
                .blue,
                .brown,
                .black
            ],
            topicsByBelt: [
                .yellow: ["הגנות"],
                .orange: ["הגנות"],
                .green: ["הגנות"],
                .blue: ["הגנות"],
                .brown: ["הגנות"],
                .black: ["הגנות"]
            ],
            parentId: "defenses",
            requireAllItemKeywords: [
                "def:internal:punch"
            ]
        ),

        // ================== הגנות פנימיות – בעיטות ==================
        SubjectTopic(
            id: "def_internal_kicks",
            titleHeb: "הגנות פנימיות – בעיטות",
            description: "הגנות פנימיות נגד בעיטות.",
            belts: [
                .yellow,
                .orange,
                .green,
                .blue,
                .brown,
                .black
            ],
            topicsByBelt: [
                .yellow: ["הגנות"],
                .orange: ["הגנות"],
                .green: ["הגנות"],
                .blue: ["הגנות"],
                .brown: ["הגנות"],
                .black: ["הגנות"]
            ],
            parentId: "defenses",
            requireAllItemKeywords: [
                "def:internal:kick"
            ]
        ),

        // ================== הגנות חיצוניות – אגרופים ==================
        SubjectTopic(
            id: "def_external_punches",
            titleHeb: "הגנות חיצוניות – אגרופים",
            description: "הגנות חיצוניות נגד אגרופים.",
            belts: [
                .yellow,
                .orange,
                .green,
                .blue,
                .brown,
                .black
            ],
            topicsByBelt: [
                .yellow: ["הגנות"],
                .orange: ["הגנות"],
                .green: ["הגנות"],
                .blue: ["הגנות"],
                .brown: ["הגנות"],
                .black: ["הגנות"]
            ],
            parentId: "defenses",
            requireAllItemKeywords: [
                "def:external:punch"
            ]
        ),

        // ================== הגנות חיצוניות – בעיטות ==================
        SubjectTopic(
            id: "def_external_kicks",
            titleHeb: "הגנות חיצוניות – בעיטות",
            description: "הגנות חיצוניות נגד בעיטות.",
            belts: [
                .yellow,
                .orange,
                .green,
                .blue,
                .brown,
                .black
            ],
            topicsByBelt: [
                .yellow: ["הגנות"],
                .orange: ["הגנות"],
                .green: ["הגנות"],
                .blue: ["הגנות"],
                .brown: ["הגנות"],
                .black: ["הגנות"]
            ],
            parentId: "defenses",
            requireAllItemKeywords: [
                "def:external:kick"
            ]
        ),

        // ================== בעיטות ==================
        SubjectTopic(
            id: "kicks",
            titleHeb: "בעיטות",
            description: "מגל, הגנה, בניתור, צד",
            belts: [
                .yellow,
                .orange,
                .green,
                .blue,
                .brown,
                .black
            ],
            topicsByBelt: [
                .yellow: ["בעיטות"],
                .orange: ["בעיטות"],
                .green: ["בעיטות"],
                .blue: ["בעיטות"],
                .brown: ["בעיטות"],
                .black: ["בעיטות"]
            ]
        ),

        // ================== שחרורים – נושא אב ==================
        SubjectTopic(
            id: "releases",
            titleHeb: "שחרורים",
            description: "מתפיסות ידיים, מחניקות ומחביקות",
            belts: releasesBelts,
            topicsByBelt: releasesTopicsByBelt,
            subTopics: [
                "שחרור מתפיסות ידיים / שיער / חולצה",
                "שחרור מחניקות",
                "שחרור מחביקות"
            ]
        ),

        // ================== שחרור מתפיסות ==================
        SubjectTopic(
            id: "releases_hands_hair_shirt",
            titleHeb: "שחרור מתפיסות ידיים / שיער / חולצה",
            description: "תפיסות ידיים, תפיסות שיער ואחיזות חולצה",
            belts: releasesBelts,
            topicsByBelt: releasesTopicsByBelt,
            parentId: "releases",
            includeItemKeywords: [
                "תפיס",
                "אחיז",
                "אוחז",
                "חולצ",
                "חולצה",
                "שיער"
            ],
            excludeItemKeywords: [
                "חניק",
                "חביק",
                "אקדח",
                "סכין",
                "מקל"
            ]
        ),

        // ================== שחרור מחניקות ==================
        SubjectTopic(
            id: "releases_chokes",
            titleHeb: "שחרור מחניקות",
            description: "חניקות צואר מלפנים/מאחור",
            belts: releasesBelts,
            topicsByBelt: releasesTopicsByBelt,
            parentId: "releases",
            includeItemKeywords: [
                "חניק",
                "חניקה",
                "חניקות",
                "צואר"
            ],
            excludeItemKeywords: [
                "תפיס",
                "אחיז",
                "חביק",
                "חולצ",
                "שיער"
            ]
        ),

        // ================== שחרור מחביקות ==================
        SubjectTopic(
            id: "releases_hugs",
            titleHeb: "שחרור מחביקות",
            description: "חביקות גוף / צואר / זרוע",
            belts: releasesBelts,
            topicsByBelt: releasesTopicsByBelt,
            parentId: "releases",
            subTopics: [
                "חביקות גוף",
                "חביקות צואר",
                "חביקות זרוע"
            ],
            includeItemKeywords: [
                "חביק",
                "חיבוק",
                "חיבוקים",
                "חביקות"
            ],
            excludeItemKeywords: [
                "חניק",
                "תפיס",
                "אחיז",
                "חולצ",
                "שיער"
            ]
        ),

        // ================== עבודת ידיים – תאימות קיימת ==================
        SubjectTopic(
            id: "punches",
            titleHeb: "עבודת ידיים",
            description: "עבודת אגרופים ומכות יד – ישרים, מגל, פיסת יד ועוד.",
            belts: [
                .yellow,
                .orange
            ],
            topicsByBelt: [
                .yellow: ["עבודת ידיים"],
                .orange: ["עבודת ידיים"]
            ],
            includeItemKeywords: [
                "אגרוף",
                "פיסת",
                "מגל",
                "סנוקרת"
            ]
        ),

        // ================== הגנות סכין ==================
        SubjectTopic(
            id: "knife_defense",
            titleHeb: "הגנות סכין",
            description: "עקרונות עבודה והגנות מול איום ודקירות בסכין.",
            belts: [
                .green,
                .blue,
                .brown,
                .black
            ],
            topicsByBelt: [
                .green: ["הגנות"],
                .blue: ["הגנות"],
                .brown: ["הגנות"],
                .black: ["הגנות"]
            ],
            subTopicHint: "סכין",
            parentId: "defenses",
            excludeItemKeywords: [
                "מקל",
                "אקדח",
                "תמ\"ק"
            ]
        ),

        // ================== הגנות עם רובה נגד סכין ==================
        SubjectTopic(
            id: "knife_rifle_defense",
            titleHeb: "הגנות עם רובה נגד דקירות סכין",
            belts: [
                .black
            ],
            topicsByBelt: [
                .black: ["הגנות"]
            ],
            subTopicHint: "סכין",
            parentId: "defenses",
            includeItemKeywords: [
                "רובה"
            ]
        ),

        // ================== מספר תוקפים ==================
        SubjectTopic(
            id: "multiple_attackers_defense",
            titleHeb: "הגנות נגד מספר תוקפים",
            belts: [
                .black
            ],
            topicsByBelt: [
                .black: ["הגנות"]
            ],
            parentId: "defenses",
            includeItemKeywords: [
                "1 מקל",
                "2 תוקפים"
            ]
        ),

        // ================== איום אקדח ==================
        SubjectTopic(
            id: "gun_threat_defense",
            titleHeb: "הגנות מאיום אקדח",
            belts: [
                .brown,
                .black
            ],
            topicsByBelt: [
                .brown: ["הגנות"],
                .black: ["הגנות"]
            ],
            subTopicHint: "אקדח",
            parentId: "defenses",
            includeItemKeywords: [
                "אקדח",
                "תמ\"ק"
            ],
            excludeItemKeywords: [
                "סכין",
                "מקל"
            ]
        ),

        // ================== הגנות נגד מקל ==================
        SubjectTopic(
            id: "stick_defense",
            titleHeb: "הגנות נגד מקל",
            belts: [
                .green,
                .brown,
                .black
            ],
            topicsByBelt: [
                .green: ["הגנות"],
                .brown: ["הגנות"],
                .black: ["הגנות"]
            ],
            subTopicHint: "מקל",
            parentId: "defenses",
            excludeItemKeywords: [
                "סכין",
                "אקדח",
                "תמ\"ק"
            ]
        )
    ]

    static func allSubjects() -> [SubjectTopic] {
        all.filter { $0.parentId == nil }
    }

    static func subjectById(_ id: String) -> SubjectTopic? {
        let cleanId = id.trimmingCharacters(in: .whitespacesAndNewlines)

        return all.first {
            $0.id.trimmingCharacters(in: .whitespacesAndNewlines) == cleanId
        }
    }

    static func subjectsForBelt(_ belt: Belt) -> [SubjectTopic] {
        all.filter {
            $0.parentId == nil &&
            $0.belts.contains(belt)
        }
    }

    static func subSubjectsFor(
        parentId: String,
        belt: Belt
    ) -> [SubjectTopic] {
        let cleanParentId = parentId.trimmingCharacters(in: .whitespacesAndNewlines)

        return all.filter {
            $0.parentId?.trimmingCharacters(in: .whitespacesAndNewlines) == cleanParentId &&
            $0.belts.contains(belt)
        }
    }
}
