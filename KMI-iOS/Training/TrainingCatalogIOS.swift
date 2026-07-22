import Foundation

enum TrainingCatalogIOS {

    private struct BranchesCatalogPayload: Decodable {
        let version: Int
        let updatedAt: String
        let regions: [RegionRecord]
        let branches: [BranchRecord]
    }

    private struct RegionRecord: Decodable {
        let id: String
        let active: Bool
        let nameHe: String
        let nameEn: String
        let country: String
    }

    private struct BranchRecord: Decodable {
        let id: String
        let active: Bool
        let regionId: String
        let regionHe: String
        let regionEn: String
        let country: String
        let countryHe: String
        let countryEn: String
        let cityHe: String
        let cityEn: String
        let nameHe: String
        let nameEn: String
        let placeHe: String
        let placeEn: String
        let addressHe: String
        let addressEn: String
        let coachIds: [String]
        let trainingDays: [TrainingDayRecord]
        let notesHe: String
        let notesEn: String
    }

    private struct TrainingDayRecord: Decodable {
        let dayOfWeek: String
        let dayHe: String
        let dayEn: String
        let startTime: String
        let endTime: String
        let durationMinutes: Int
        let groupHe: String
        let groupEn: String
        let coachNameHe: String
        let coachNameEn: String
    }

    private static let branchesCatalog: BranchesCatalogPayload? = {
        guard let url = Bundle.main.url(
            forResource: "branches",
            withExtension: "json"
        ) else {
            print("TrainingCatalogIOS: branches.json was not found in the app bundle")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)

            return try JSONDecoder().decode(
                BranchesCatalogPayload.self,
                from: data
            )
        } catch {
            print("TrainingCatalogIOS: failed to decode branches.json: \(error)")
            return nil
        }
    }()

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

    private static let abroadBranchesByCountry: [String: [String]] = [
        "USA": [
            "Smithfield (RI) 🇺🇸 – Kevin Notch",
            "East Greenwich (RI) 🇺🇸 – Kevin Notch"
        ],
        "Canada": [
            "Concord – Sergey Baskin",
            "Thunder Bay – Aviran Ben Sason"
        ],
        "Australia": [
            "Perth – David Reznik"
        ],
        "Mexico": [
            "Hermosillo – Oscar Monge",
            "Guanajuato – Alberto Carrillo Moreno"
        ],
        "Poland": [
            "Szczecin – Maciej Narkiewicz-Jodko"
        ],
        "Turkey": [
            "Istanbul (Beyoglu) – Ibrahim Tokgoz",
            "Istanbul (Kartal) – Burak Korkmaz, Tugay Akay"
        ],
        "Italy": [
            "Carrara – Alessio Palagi",
            "Massa – Alessio Palagi",
            "Milan – Koren Mor",
            "Castiglione del Lago (Perugia) – Gimmy Fattoni",
            "Città della Pieve (PG) – Gimmy Fattoni",
            "Perugia – Italy CKA – Gimmy Fattoni",
            "Fabro (TR) – Futura Fitness Club – Gimmy Fattoni"
        ],
        "Ireland": [
            "Ballina – Kevin Martin"
        ],
        "Korea": [
            "Daegu – Younmin Jeong"
        ]
    ]

    private static let abroadAddressByBranch: [String: String] = [
        "Smithfield (RI) 🇺🇸 – Kevin Notch": "970 Douglas Pike, Smithfield, RI 02917, USA",
        "East Greenwich (RI) 🇺🇸 – Kevin Notch": "3725 Post Rd, East Greenwich, RI 02818, USA",
        "Concord – Sergey Baskin": "411 Confederation Pkwy Unit #12, Concord, ON L4K 0A8, Canada",
        "Thunder Bay – Aviran Ben Sason": "766 Sprague St, Thunder Bay, ON, Canada",
        "Perth – David Reznik": "Perth, Australia",
        "Hermosillo – Oscar Monge": "Hermosillo, Sonora, Mexico",
        "Guanajuato – Alberto Carrillo Moreno": "Viznagas 6, San Isidro, Guanajuato, Mexico",
        "Szczecin – Maciej Narkiewicz-Jodko": "Szczecin, Poland",
        "Istanbul (Beyoglu) – Ibrahim Tokgoz": "İstiklal Caddesi No:108 Aznavur Pasajı Kat:5, Beyoğlu, Istanbul, Turkey",
        "Istanbul (Kartal) – Burak Korkmaz, Tugay Akay": "Esentepe Mahallesi, Gülpınar Sk. No:16, Kartal, Istanbul, Turkey",
        "Carrara – Alessio Palagi": "Viale XX Settembre 177/D, Carrara, Italy",
        "Massa – Alessio Palagi": "Via Degli Unni 1, Massa, Italy",
        "Milan – Koren Mor": "Via Leopardi 24, Milan, Italy",
        "Castiglione del Lago (Perugia) – Gimmy Fattoni": "Via Piana 17/M, Castiglione del Lago, Perugia, Italy",
        "Città della Pieve (PG) – Gimmy Fattoni": "Città della Pieve, PG, Cardete, Italy",
        "Perugia – Italy CKA – Gimmy Fattoni": "Via Piccolpasso 9/13, Perugia, Italy",
        "Fabro (TR) – Futura Fitness Club – Gimmy Fattoni": "Via Monte Biaco 4, Fabro TR, Italy",
        "Ballina – Kevin Martin": "Sean Duffy Community Center, Ballina, Ireland",
        "Daegu – Younmin Jeong": "Ansim-ro, Dong-gu, Daegu, Korea"
    ]

    static func abroadRegions() -> [String] {
        [
            "USA",
            "Canada",
            "Australia",
            "Mexico",
            "Poland",
            "Turkey",
            "Italy",
            "Ireland",
            "Korea"
        ]
    }

    static func isAbroadRegion(_ region: String) -> Bool {
        abroadBranchesByCountry.keys.contains(region)
    }

    static func isAbroadBranch(_ branch: String) -> Bool {
        abroadAddressByBranch.keys.contains(branch)
    }
    
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

    static let ageGroupsByBranch: [String: [String]] = {
        var result: [String: Set<String>] = [:]

        // מקור ראשי: branches.json
        if let catalog = branchesCatalog {
            for branch in catalog.branches where branch.active {
                let branchName = branch.nameHe
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard !branchName.isEmpty else { continue }

                let groups = branch.trainingDays
                    .map {
                        $0.groupHe.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                    }
                    .filter { !$0.isEmpty }

                if !groups.isEmpty {
                    result[branchName, default: []]
                        .formUnion(groups)
                }
            }
        }

        // גיבוי: רשימת האימונים המקומית
        for slot in slots {
            let branchName = slot.branch
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let groups = slot.groups
                .map {
                    $0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                }
                .filter { !$0.isEmpty }

            guard !branchName.isEmpty else { continue }

            result[branchName, default: []]
                .formUnion(groups)
        }

        return result.mapValues {
            Array($0).sorted()
        }
    }()

    static let slots: [TrainingSlot] = [
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

    // MARK: - Display Localization
    
    static func displayRegion(_ value: String, isEnglish: Bool) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isEnglish else { return clean }

        switch clean {
        case "השרון":
            return "Hasharon"
        case "מרכז":
            return "Central Israel"
        case "ירושלים":
            return "Jerusalem"
        case "צפון":
            return "North"
        case "דרום":
            return "South"
        default:
            return clean
        }
    }

    static func displayBranch(_ value: String, isEnglish: Bool) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isEnglish else { return clean }

        switch clean {
        case "נתניה – מרכז קהילתי אופק":
            return "Netanya – Ofek Community Center"
        case "נתניה – מרכז קהילתי סוקולוב":
            return "Netanya – Sokolov Community Center"
        case "נתניה – נורדאו":
            return "Netanya – Nordau"
        case "עזריאל – מושב עזריאל":
            return "Azriel – Moshav Azriel"
        case "רעננה – מרכז קהילתי לב הפארק":
            return "Ra'anana – Lev HaPark Community Center"
        case "הרצליה – מרכז קהילתי נוף ים":
            return "Herzliya – Nof Yam Community Center"
        case "כפר סבא – היכל התרבות":
            return "Kfar Saba – Culture Hall"
        case "הוד השרון – מרכז ספורט עירוני":
            return "Hod Hasharon – Municipal Sports Center"

        case "תל אביב – מרכז קהילתי דובנוב":
            return "Tel Aviv – Dubnov Community Center"
        case "תל אביב – מרכז קהילתי יד אליהו":
            return "Tel Aviv – Yad Eliyahu Community Center"
        case "פתח תקווה – מתנ\"ס עמישב":
            return "Petah Tikva – Amishav Community Center"

        case "ירושלים – מרכז קהילתי רמות ספיר":
            return "Jerusalem – Ramot Sapir Community Center"
        case "ירושלים – מרכז קהילתי קריית יובל":
            return "Jerusalem – Kiryat Yovel Community Center"

        case "חיפה / נשר – מתנ\"ס בת לזר":
            return "Haifa / Nesher – Bat Lazar Community Center"
        case "קריית אתא – ביה\"ס אלונים":
            return "Kiryat Ata – Alonim School"
        case "קריית ביאליק – רח' דפנה 52":
            return "Kiryat Bialik – 52 Dafna St"
        case "כרמיאל – אשכול פיס":
            return "Karmiel – Eshkol Pais"
        case "עכו – אשכול פיס":
            return "Acre – Eshkol Pais"
        case "עפולה – חטיבה תשע 25":
            return "Afula – 25 Hativa Tesha"
        case "יאנוח – יאנוח":
            return "Yanuh – Yanuh"
        case "ג'וליס – ג'וליס":
            return "Julis – Julis"

        case "אשקלון – מרכז קהילתי שמשון":
            return "Ashkelon – Shimshon Community Center"
        case "באר שבע – מרכז קהילתי נווה זאב":
            return "Beer Sheva – Neve Ze'ev Community Center"
        case "אשדוד – מתנ\"ס רובע י\"ב":
            return "Ashdod – District 12 Community Center"

        default:
            return clean
        }
    }

    static func displayGroup(_ value: String, isEnglish: Bool) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isEnglish else { return clean }

        switch clean {
        case "גן חובה - כיתה א", "גן חובה - כיתה א'":
            return "Kindergarten – Grade 1"
        case "כיתה ב' - כיתה ה'":
            return "Grades 2–5"
        case "כיתה ו' - כיתה ח'":
            return "Grades 6–8"
        case "נוער + בוגרים":
            return "Youth + Adults"
        case "בוגרים":
            return "Adults"
        case "ילדים":
            return "Kids"
        case "נוער":
            return "Youth"
        case "טרום חובה וחובה":
            return "Pre-K + Kindergarten"
        case "כיתה א' - כיתה ב'":
            return "Grades 1–2"
        case "כיתה ג' - כיתה ו'":
            return "Grades 3–6"
        case "ילדים (גן חובה עד כיתה ב')":
            return "Kids: Kindergarten – Grade 2"
        case "כיתה ג' - כיתה ז'":
            return "Grades 3–7"
        default:
            return clean
        }
    }

    static func displayPlace(_ value: String, isEnglish: Bool) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isEnglish else { return clean }

        switch clean {
        case "מרכז קהילתי סוקולוב":
            return "Sokolov Community Center"
        case "מרכז קהילתי אופק":
            return "Ofek Community Center"
        case "נורדאו":
            return "Nordau"
        case "מושב עזריאל":
            return "Moshav Azriel"
        default:
            return clean
        }
    }

    static func displayAddress(_ value: String, isEnglish: Bool) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isEnglish else { return clean }

        switch clean {
        case "רחוב נחום סוקולוב 25, נתניה":
            return "25 Nahum Sokolov St, Netanya"
        case "רחוב אבא אחימאיר 6, נתניה":
            return "6 Abba Ahimeir St, Netanya"
        case "אריה לוין 3, נתניה":
            return "3 Aryeh Levin St, Netanya"
        case "מושב עזריאל, מאחורי מכולת המושב":
            return "Moshav Azriel, behind the local grocery store"
        case "רעננה – מרכז קהילתי לב הפארק":
            return "Ra'anana – Lev HaPark Community Center"
        case "הרצליה – מרכז קהילתי נוף ים":
            return "Herzliya – Nof Yam Community Center"
        case "כפר סבא – היכל התרבות":
            return "Kfar Saba – Culture Hall"
        case "הוד השרון – מרכז ספורט עירוני":
            return "Hod Hasharon – Municipal Sports Center"
        default:
            return clean
        }
    }

    static func displayCoach(_ value: String, isEnglish: Bool) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isEnglish else { return clean }

        switch clean {
        case "אדם הולצמן":
            return "Adam Holtzman"
        case "יוני מלסה":
            return "Yoni Malsa"
        case "רבקה מסיקה":
            return "Rivka Masika"
        default:
            return clean
        }
    }
    
    static func isRegionActive(_ region: String) -> Bool {
        !inactiveRegions.contains(region)
    }

    static func regionStatusMessage(_ region: String) -> String? {
        isRegionActive(region) ? nil : regionHoldMessage
    }

    static func branchesFor(region: String) -> [String] {
        if let abroadBranches = abroadBranchesByCountry[region] {
            return abroadBranches
        }

        guard isRegionActive(region) else { return [] }

        return (branchesByRegionRaw[region] ?? [])
            .filter { !inactiveBranches.contains($0) }
    }

    static func addressFor(_ branchOrAddress: String) -> String {
        let clean = branchOrAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        if let abroadAddress = abroadAddressByBranch[clean] {
            return abroadAddress
        }

        if clean.contains(",") || clean.rangeOfCharacter(from: .decimalDigits) != nil {
            return clean
        }

        return addressByBranch[clean] ?? clean
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

    private static func normalizedCatalogText(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "־", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )
            .lowercased()
    }

    private static func catalogComparableText(
        _ value: String
    ) -> String {
        normalizedCatalogText(value)
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "׳", with: "")
            .replacingOccurrences(of: "״", with: "")
    }

    private static func matchingCatalogBranchName(
        for selectedBranch: String
    ) -> String? {
        let wanted = catalogComparableText(selectedBranch)

        return ageGroupsByBranch.keys.first { branchName in
            catalogComparableText(branchName) == wanted
        }
    }

    static func groupsFor(
        branch: String
    ) -> [String] {
        let clean = branch.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !clean.isEmpty else {
            return []
        }

        if isAbroadBranch(clean) {
            return ["בוגרים"]
        }

        if let exactGroups = ageGroupsByBranch[clean],
           !exactGroups.isEmpty {
            return exactGroups
        }

        guard let matchingName = matchingCatalogBranchName(
            for: clean
        ) else {
            return []
        }

        return ageGroupsByBranch[matchingName] ?? []
    }

    static func groupsFor(
        branches: [String]
    ) -> [String] {
        let allGroups = branches.flatMap { branch in
            groupsFor(branch: branch)
        }

        return Array(Set(allGroups))
            .filter { !$0.isEmpty }
            .sorted()
    }
    
    private static func branchFromCatalog(
        matching branchName: String
    ) -> BranchRecord? {
        let wanted = normalizedCatalogText(branchName)

        return branchesCatalog?
            .branches
            .first { branch in
                guard branch.active else {
                    return false
                }

                return normalizedCatalogText(branch.nameHe) == wanted ||
                    normalizedCatalogText(branch.nameEn) == wanted ||
                    normalizedCatalogText(branch.placeHe) == wanted ||
                    normalizedCatalogText(branch.placeEn) == wanted
            }
    }

    private static func trainingDayMatchesGroup(
        _ trainingDay: TrainingDayRecord,
        selectedGroup: String?
    ) -> Bool {
        let rawSelected = selectedGroup?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !rawSelected.isEmpty else {
            return true
        }

        let selectedNormalized = normalizeGroupName(rawSelected)
        let hebrewNormalized = normalizeGroupName(trainingDay.groupHe)
        let englishNormalized = normalizedCatalogText(trainingDay.groupEn)
        let selectedTextNormalized = normalizedCatalogText(rawSelected)

        if selectedNormalized == hebrewNormalized {
            return true
        }

        if normalizedCatalogText(trainingDay.groupHe) == selectedTextNormalized {
            return true
        }

        if englishNormalized == selectedTextNormalized {
            return true
        }

        if selectedNormalized == "נוער" &&
            hebrewNormalized == "נוער + בוגרים" {
            return true
        }

        if selectedNormalized == "בוגרים" &&
            hebrewNormalized == "נוער + בוגרים" {
            return true
        }

        return false
    }

    private static func calendarWeekday(
        from rawValue: String
    ) -> Int? {
        switch rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() {

        case "SUNDAY":
            return 1

        case "MONDAY":
            return 2

        case "TUESDAY":
            return 3

        case "WEDNESDAY":
            return 4

        case "THURSDAY":
            return 5

        case "FRIDAY":
            return 6

        case "SATURDAY":
            return 7

        default:
            return nil
        }
    }

    private static func timeComponents(
        from value: String
    ) -> (hour: Int, minute: Int)? {
        let parts = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":")

        guard
            parts.count >= 2,
            let hour = Int(parts[0]),
            let minute = Int(parts[1]),
            (0...23).contains(hour),
            (0...59).contains(minute)
        else {
            return nil
        }

        return (hour, minute)
    }

    private static func nextTrainingDate(
        trainingDay: TrainingDayRecord,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        guard
            let weekday = calendarWeekday(
                from: trainingDay.dayOfWeek
            ),
            let startTime = timeComponents(
                from: trainingDay.startTime
            )
        else {
            return nil
        }

        for offset in 0..<14 {
            guard let candidateDay = calendar.date(
                byAdding: .day,
                value: offset,
                to: now
            ) else {
                continue
            }

            guard calendar.component(
                .weekday,
                from: candidateDay
            ) == weekday else {
                continue
            }

            var components = calendar.dateComponents(
                [.year, .month, .day],
                from: candidateDay
            )

            components.hour = startTime.hour
            components.minute = startTime.minute
            components.second = 0
            components.nanosecond = 0

            guard let candidateDate = calendar.date(
                from: components
            ) else {
                continue
            }

            if candidateDate > now {
                return candidateDate
            }
        }

        return nil
    }

    static func trainingsFor(
        branch: String,
        group: String?
    ) -> [TrainingData] {
        guard let catalogBranch = branchFromCatalog(
            matching: branch
        ) else {
            return []
        }

        let now = Date()
        let calendar = Calendar(identifier: .gregorian)

        let exactMatches = catalogBranch.trainingDays.filter { trainingDay in
            trainingDayMatchesGroup(
                trainingDay,
                selectedGroup: group
            )
        }

        let selectedGroup = group?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let trainingDays: [TrainingDayRecord]

        if selectedGroup.isEmpty {
            trainingDays = catalogBranch.trainingDays
        } else {
            trainingDays = exactMatches
        }

        return trainingDays.compactMap { trainingDay in
            guard let startDate = nextTrainingDate(
                trainingDay: trainingDay,
                now: now,
                calendar: calendar
            ) else {
                return nil
            }

            let durationMinutes = trainingDay.durationMinutes > 0
                ? trainingDay.durationMinutes
                : 90

            let endDate = startDate.addingTimeInterval(
                TimeInterval(durationMinutes * 60)
            )

            let startFormatter = DateFormatter()
            startFormatter.locale = Locale(identifier: "he_IL")
            startFormatter.calendar = calendar
            startFormatter.dateFormat = "dd/MM/yyyy HH:mm"

            let endFormatter = DateFormatter()
            endFormatter.locale = Locale(identifier: "he_IL")
            endFormatter.calendar = calendar
            endFormatter.dateFormat = "HH:mm"

            let stableId = [
                catalogBranch.id,
                trainingDay.dayOfWeek,
                trainingDay.startTime,
                trainingDay.groupHe,
                String(Int(startDate.timeIntervalSince1970))
            ]
            .joined(separator: "_")

            return TrainingData(
                id: stableId,
                date: startDate,
                startText: startFormatter.string(from: startDate),
                endText: endFormatter.string(from: endDate),
                place: catalogBranch.placeHe,
                address: catalogBranch.addressHe,
                coach: trainingDay.coachNameHe
            )
        }
        .sorted { left, right in
            left.date < right.date
        }
    }
    
    static func upcomingFor(
        region: String,
        branch: String,
        group: String,
        count: Int = 5
    ) -> [TrainingData] {
        let normalizedBranch = branch
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedBranch.isEmpty else {
            return []
        }

        let now = Date()
        let calendar = Calendar(identifier: .gregorian)

        let startOfToday = calendar.startOfDay(for: now)

        guard let seventhDay = calendar.date(
            byAdding: .day,
            value: 6,
            to: startOfToday
        ) else {
            return []
        }

        guard let endOfSeventhDay = calendar.date(
            byAdding: DateComponents(
                day: 1,
                second: -1
            ),
            to: seventhDay
        ) else {
            return []
        }

        let upcoming = trainingsFor(
            branch: normalizedBranch,
            group: group
        )
        .filter { training in
            training.date >= now &&
            training.date <= endOfSeventhDay
        }
        .sorted { left, right in
            left.date < right.date
        }

        return Array(upcoming.prefix(max(0, count)))
    }
}
