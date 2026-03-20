import Foundation

enum TrainingCatalogIOS {

    static let regionHoldMessage = "אין סניפים זמינים באזור זה"

    private static let branchesByRegionRaw: [String: [String]] = [
        "השרון": [
            "נתניה – מרכז קהילתי אופק",
            "נתניה – מרכז קהילתי סוקולוב",
            "נתניה – נורדאו",
            "עזריאל – מושב עזריאל",
            "רעננה – מרכז קהילתי לב הפארק",
            "הרצליה – מרכז קהילתי נוף ים",
            "כפר סבא – היכל התרבות",
            "הוד השרון – מרכז ספורט עירוני"
        ],
        "מרכז": [
            "תל אביב – מרכז קהילתי דובנוב",
            "תל אביב – מרכז קהילתי יד אליהו",
            "פתח תקווה – מתנ\"ס עמישב"
        ],
        "ירושלים": [
            "ירושלים – מרכז קהילתי רמות ספיר",
            "ירושלים – מרכז קהילתי קריית יובל"
        ],
        "צפון": [
            "חיפה / נשר – מתנ\"ס בת לזר",
            "קריית אתא – ביה\"ס אלונים",
            "קריית ביאליק – רח' דפנה 52",
            "כרמיאל – אשכול פיס",
            "עכו – אשכול פיס",
            "עפולה – חטיבה תשע 25",
            "יאנוח – יאנוח",
            "ג'וליס – ג'וליס"
        ],
        "דרום": [
            "אשקלון – מרכז קהילתי שמשון",
            "באר שבע – מרכז קהילתי נווה זאב",
            "אשדוד – מתנ\"ס רובע י\"ב"
        ]
    ]

    private static let inactiveRegions: Set<String> = [
        "מרכז",
        "ירושלים",
        "צפון",
        "דרום"
    ]

    private static let inactiveBranches: Set<String> = [
        "הרצליה – מרכז קהילתי נוף ים",
        "כפר סבא – היכל התרבות",
        "רעננה – מרכז קהילתי לב הפארק",
        "הוד השרון – מרכז ספורט עירוני"
    ]

    private static let addressByBranch: [String: String] = [
        "נתניה – מרכז קהילתי סוקולוב": "רחוב נחום סוקולוב 25, נתניה",
        "נתניה – מרכז קהילתי אופק": "רחוב אבא אחימאיר 6, נתניה",
        "נתניה – נורדאו": "אריה לוין 3, נתניה",
        "עזריאל – מושב עזריאל": "מושב עזריאל, מאחורי מכולת המושב",
        "רעננה – מרכז קהילתי לב הפארק": "רעננה – מרכז קהילתי לב הפארק",
        "הרצליה – מרכז קהילתי נוף ים": "הרצליה – מרכז קהילתי נוף ים",
        "כפר סבא – היכל התרבות": "כפר סבא – היכל התרבות",
        "הוד השרון – מרכז ספורט עירוני": "הוד השרון – מרכז ספורט עירוני"
    ]

    static let ageGroupsByBranch: [String: [String]] = [
        "נתניה – מרכז קהילתי אופק": ["גן חובה - כיתה א", "כיתה ב' - כיתה ה'", "כיתה ו' - כיתה ח'", "נוער + בוגרים", "בוגרים"],
        "נתניה – מרכז קהילתי סוקולוב": ["בוגרים", "ילדים"],
        "נתניה – נורדאו": ["טרום חובה וחובה", "כיתה א' - כיתה ב'", "כיתה ג' - כיתה ו'", "בוגרים"],
        "עזריאל – מושב עזריאל": ["ילדים (גן חובה עד כיתה ב')", "כיתה ג' - כיתה ז'", "נוער + בוגרים"],
        "רעננה – מרכז קהילתי לב הפארק": ["בוגרים"],
        "הרצליה – מרכז קהילתי נוף ים": ["בוגרים"],
        "כפר סבא – היכל התרבות": ["בוגרים"],
        "הוד השרון – מרכז ספורט עירוני": ["בוגרים"]
    ]

    private static let slots: [TrainingSlot] = [
        TrainingSlot(
            id: "sokolov_adults_sun",
            branch: "נתניה – מרכז קהילתי סוקולוב",
            groups: ["בוגרים"],
            dayOfWeek: 1,
            startHour: 20,
            startMinute: 0,
            durationMinutes: 90,
            place: "מרכז קהילתי סוקולוב",
            address: "רחוב נחום סוקולוב 25, נתניה",
            coach: "אדם הולצמן"
        ),
        TrainingSlot(
            id: "sokolov_adults_tue",
            branch: "נתניה – מרכז קהילתי סוקולוב",
            groups: ["בוגרים"],
            dayOfWeek: 3,
            startHour: 20,
            startMinute: 0,
            durationMinutes: 90,
            place: "מרכז קהילתי סוקולוב",
            address: "רחוב נחום סוקולוב 25, נתניה",
            coach: "אדם הולצמן"
        ),
        TrainingSlot(
            id: "ofek_kids_mon1",
            branch: "נתניה – מרכז קהילתי אופק",
            groups: ["גן חובה - כיתה א'"],
            dayOfWeek: 2,
            startHour: 16,
            startMinute: 45,
            durationMinutes: 30,
            place: "מרכז קהילתי אופק",
            address: "רחוב אבא אחימאיר 6, נתניה",
            coach: "יוני מלסה"
        ),
        TrainingSlot(
            id: "ofek_kids_thu1",
            branch: "נתניה – מרכז קהילתי אופק",
            groups: ["גן חובה - כיתה א'"],
            dayOfWeek: 5,
            startHour: 16,
            startMinute: 45,
            durationMinutes: 30,
            place: "מרכז קהילתי אופק",
            address: "רחוב אבא אחימאיר 6, נתניה",
            coach: "יוני מלסה"
        ),
        TrainingSlot(
            id: "ofek_teens_mon",
            branch: "נתניה – מרכז קהילתי אופק",
            groups: ["נוער + בוגרים"],
            dayOfWeek: 2,
            startHour: 19,
            startMinute: 0,
            durationMinutes: 90,
            place: "מרכז קהילתי אופק",
            address: "רחוב אבא אחימאיר 6, נתניה",
            coach: "יוני מלסה"
        ),
        TrainingSlot(
            id: "ofek_teens_thu",
            branch: "נתניה – מרכז קהילתי אופק",
            groups: ["נוער + בוגרים"],
            dayOfWeek: 5,
            startHour: 19,
            startMinute: 0,
            durationMinutes: 90,
            place: "מרכז קהילתי אופק",
            address: "רחוב אבא אחימאיר 6, נתניה",
            coach: "יוני מלסה"
        ),
        TrainingSlot(
            id: "ofek_adults_mon",
            branch: "נתניה – מרכז קהילתי אופק",
            groups: ["בוגרים"],
            dayOfWeek: 2,
            startHour: 20,
            startMinute: 30,
            durationMinutes: 90,
            place: "מרכז קהילתי אופק",
            address: "רחוב אבא אחימאיר 6, נתניה",
            coach: "יוני מלסה"
        ),
        TrainingSlot(
            id: "nordau_small_sun",
            branch: "נתניה – נורדאו",
            groups: ["טרום חובה וחובה"],
            dayOfWeek: 1,
            startHour: 16,
            startMinute: 45,
            durationMinutes: 30,
            place: "נורדאו",
            address: "אריה לוין 3, נתניה",
            coach: "רבקה מסיקה"
        ),
        TrainingSlot(
            id: "nordau_small_wed",
            branch: "נתניה – נורדאו",
            groups: ["טרום חובה וחובה"],
            dayOfWeek: 4,
            startHour: 16,
            startMinute: 45,
            durationMinutes: 30,
            place: "נורדאו",
            address: "אריה לוין 3, נתניה",
            coach: "רבקה מסיקה"
        ),
        TrainingSlot(
            id: "azriel_youth_wed",
            branch: "עזריאל – מושב עזריאל",
            groups: ["נוער + בוגרים"],
            dayOfWeek: 4,
            startHour: 18,
            startMinute: 45,
            durationMinutes: 75,
            place: "מושב עזריאל",
            address: "מושב עזריאל, מאחורי מכולת המושב",
            coach: "יוני מלסה"
        )
    ]

    static func isRegionActive(_ region: String) -> Bool {
        !inactiveRegions.contains(region)
    }

    static func regionStatusMessage(_ region: String) -> String? {
        isRegionActive(region) ? nil : regionHoldMessage
    }

    static func branchesFor(region: String) -> [String] {
        guard isRegionActive(region) else { return [] }
        return (branchesByRegionRaw[region] ?? []).filter { !inactiveBranches.contains($0) }
    }

    static func addressFor(_ branchOrAddress: String) -> String {
        if branchOrAddress.contains(",") || branchOrAddress.rangeOfCharacter(from: .decimalDigits) != nil {
            return branchOrAddress
        }
        return addressByBranch[branchOrAddress] ?? branchOrAddress
    }

    static func placeFor(_ branch: String) -> String {
        let parts = branch.components(separatedBy: " – ")
        return parts.count == 2 ? parts[1] : branch
    }

    static func normalizeGroupName(_ name: String?) -> String {
        let raw = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = raw.lowercased()

        let hasAdult = lower.contains("בוגר")
        let hasYouth = lower.contains("נוער")
        let isKids = lower.contains("ילד") || lower.contains("כיתה") || lower.contains("גן") || lower.contains("טרום")

        if hasAdult && hasYouth { return "נוער + בוגרים" }
        if hasAdult { return "בוגרים" }
        if hasYouth { return "נוער" }
        if isKids { return "ילדים" }
        return raw
    }

    static func trainingsFor(branch: String, group: String?) -> [TrainingData] {
        let wanted = normalizeGroupName(group)

        return slots
            .filter { slot in
                guard slot.branch == branch else { return false }
                guard let group, !group.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }

                return slot.groups.contains(where: { normalizeGroupName($0) == wanted || $0 == group })
            }
            .map { slot in
                nextWeekly(
                    slot: slot,
                    now: Date()
                )
            }
            .sorted { $0.date < $1.date }
    }

    static func upcomingFor(region: String, branch: String, group: String, count: Int = 3) -> [TrainingData] {
        guard isRegionActive(region) else { return [] }
        guard branchesFor(region: region).contains(branch) else { return [] }
        return Array(trainingsFor(branch: branch, group: group).prefix(count))
    }

    private static func nextWeekly(slot: TrainingSlot, now: Date) -> TrainingData {
        let calendar = Calendar(identifier: .gregorian)
        let locale = Locale(identifier: "he_IL")

        var nextDate = now
        for offset in 0..<14 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            let weekday = calendar.component(.weekday, from: candidate)
            if weekday == slot.dayOfWeek {
                var comps = calendar.dateComponents([.year, .month, .day], from: candidate)
                comps.hour = slot.startHour
                comps.minute = slot.startMinute
                comps.second = 0

                if let finalDate = calendar.date(from: comps), finalDate > now {
                    nextDate = finalDate
                    break
                }
            }
        }

        let endDate = nextDate.addingTimeInterval(TimeInterval(slot.durationMinutes * 60))

        let startFormatter = DateFormatter()
        startFormatter.locale = locale
        startFormatter.dateFormat = "dd/MM/yyyy HH:mm"

        let endFormatter = DateFormatter()
        endFormatter.locale = locale
        endFormatter.dateFormat = "HH:mm"

        return TrainingData(
            id: slot.id + "_\(Int(nextDate.timeIntervalSince1970))",
            date: nextDate,
            startText: startFormatter.string(from: nextDate),
            endText: endFormatter.string(from: endDate),
            place: slot.place,
            address: slot.address,
            coach: slot.coach
        )
    }
}
