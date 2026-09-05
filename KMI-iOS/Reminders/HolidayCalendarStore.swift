import Foundation
import KosherSwift

struct HolidayFileItem: Codable {
    let date_iso: String?
    let name: String
}

struct HolidayFileRoot: Codable {
    let timezone: String?
    let items: [HolidayFileItem]
}

enum HolidayCalendarStore {

    private static let fileName = "holidays_hebrew_2024_2026"
    private static let fileExtension = "json"

    struct HolidayEntry: Hashable {
        let date: Date
        let name: String
        let nameEn: String
        let cancellationSource: String

        init(
            date: Date,
            name: String,
            nameEn: String = "",
            cancellationSource: String? = nil
        ) {
            self.date = date
            self.name = name
            self.nameEn = nameEn
            self.cancellationSource = cancellationSource ?? name
        }

        func displayName(isEnglish: Bool) -> String {
            if isEnglish {
                return nameEn.isEmpty ? name : nameEn
            }
            return name.isEmpty ? nameEn : name
        }
    }

    struct CancellationReason: Hashable {
        let he: String
        let en: String
    }

    private static let cachedEntries = loadEntries()

    private struct HolidayIdentity: Hashable {
        let date: Date
        let name: String
        let nameEn: String
        let reason: CancellationReason?
    }

    private static func uniqueEntries(
        _ entries: [HolidayEntry]
    ) -> [HolidayEntry] {
        var seen = Set<HolidayIdentity>()
        return entries.filter { entry in
            let identity = HolidayIdentity(
                date: entry.date,
                name: entry.name,
                nameEn: entry.nameEn,
                reason: cancellationReasonForSource(
                    entry.cancellationSource
                )
            )
            return seen.insert(identity).inserted
        }
    }

    static func cancellationReason(
        on date: Date
    ) -> CancellationReason? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone =
            TimeZone(identifier: "Asia/Jerusalem")
            ?? TimeZone(secondsFromGMT: 0)!

        let reasons = cachedEntries
            .filter {
                calendar.isDate($0.date, inSameDayAs: date)
            }
            .compactMap {
                cancellationReasonForSource($0.cancellationSource)
            }

        return reasons.first {
            $0.he == "צום תשעה באב"
        } ?? reasons.first
    }

    static func isTrainingCancelled(on date: Date) -> Bool {
        cancellationReason(on: date) != nil
    }

    private static func cancellationReasonForSource(
        _ source: String
    ) -> CancellationReason? {
        let clean = source
            .lowercased(with: Locale(identifier: "he_IL"))
            .replacingOccurrences(of: "׳", with: "'")
            .replacingOccurrences(of: "״", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !clean.isEmpty else {
            return nil
        }

        let isEve =
            clean.contains("ערב") ||
            clean.contains("erev")

        let tishaBeAvTokens = [
            "תשעה באב",
            "ט' באב",
            "ט באב",
            "tisha b'av",
            "tisha bav"
        ]

        if tishaBeAvTokens.contains(where: { clean.contains($0) }) {
            return CancellationReason(
                he: "צום תשעה באב",
                en: "Tisha B’Av fast"
            )
        }

        if clean.contains("ראש השנה") {
            return CancellationReason(
                he: isEve ? "ערב ראש השנה" : "ראש השנה",
                en: isEve ? "Rosh Hashanah Eve" : "Rosh Hashanah"
            )
        }

        if clean.contains("יום כיפור") ||
            clean.contains("יום הכיפורים") ||
            clean.contains("yom kippur") {
            return CancellationReason(
                he: isEve ? "ערב יום כיפור" : "יום כיפור",
                en: isEve ? "Yom Kippur Eve" : "Yom Kippur"
            )
        }

        if clean.contains("שמחת תורה") {
            return CancellationReason(
                he: isEve ? "ערב שמחת תורה" : "שמחת תורה",
                en: isEve ? "Simchat Torah Eve" : "Simchat Torah"
            )
        }

        if clean.contains("חול המועד סוכות") {
            return CancellationReason(
                he: "חול המועד סוכות",
                en: "Sukkot Intermediate Days"
            )
        }

        if clean.contains("סוכות") {
            return CancellationReason(
                he: isEve ? "ערב סוכות" : "סוכות",
                en: isEve ? "Sukkot Eve" : "Sukkot"
            )
        }

        if clean.contains("חול המועד פסח") {
            return CancellationReason(
                he: "חול המועד פסח",
                en: "Passover Intermediate Days"
            )
        }

        if clean.contains("פסח") {
            return CancellationReason(
                he: isEve ? "ערב פסח" : "פסח",
                en: isEve ? "Passover Eve" : "Passover"
            )
        }

        if clean.contains("שבועות") {
            return CancellationReason(
                he: isEve ? "ערב שבועות" : "שבועות",
                en: isEve ? "Shavuot Eve" : "Shavuot"
            )
        }

        return nil
    }

    static func loadEntries() -> [HolidayEntry] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone =
            TimeZone(identifier: "Asia/Jerusalem")
            ?? TimeZone(secondsFromGMT: 0)!

        let assetYears = 2024...2026
        let bundleEntries = loadEntriesFromBundle().filter {
            assetYears.contains(
                calendar.component(.year, from: $0.date)
            )
        }
        let fallbackEntries = generateFallbackEntries().filter {
            !assetYears.contains(
                calendar.component(.year, from: $0.date)
            )
        }
        return uniqueEntries(bundleEntries + fallbackEntries)
    }

    private static func loadEntriesFromBundle() -> [HolidayEntry] {
        guard let url = Bundle.main.url(
            forResource: fileName,
            withExtension: fileExtension
        ),
        let data = try? Data(contentsOf: url),
        let root = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }

        let rawItems: [Any]
        if let object = root as? [String: Any] {
            if let items = object["items"] as? [Any] {
                rawItems = items
            } else if let items = object["data"] as? [Any] {
                rawItems = items
            } else {
                rawItems = []
            }
        } else {
            rawItems = root as? [Any] ?? []
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone =
            TimeZone(identifier: "Asia/Jerusalem")
            ?? TimeZone(secondsFromGMT: 0)!

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false

        func value(_ item: [String: Any], _ key: String) -> String {
            (item[key] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }

        func firstNonBlank(
            _ item: [String: Any],
            keys: [String]
        ) -> String {
            keys.lazy
                .map { value(item, $0) }
                .first { !$0.isEmpty } ?? ""
        }

        func parseDate(_ text: String) -> Date? {
            let prefix = String(text.prefix(10))
            guard prefix.count == 10,
                  let date = formatter.date(from: prefix),
                  formatter.string(from: date) == prefix else {
                return nil
            }
            return date
        }

        func datesFor(_ item: [String: Any]) -> [Date] {
            if let start = parseDate(value(item, "start_iso")),
               let end = parseDate(value(item, "end_iso")),
               start <= end {
                var dates: [Date] = []
                var current = start
                while current <= end {
                    dates.append(current)
                    guard let next = calendar.date(
                        byAdding: .day,
                        value: 1,
                        to: current
                    ), next > current else {
                        break
                    }
                    current = next
                }
                return dates
            }
            guard let date = parseDate(value(item, "date_iso")) else {
                return []
            }
            return [date]
        }

        let cancellationKeys = [
            "title", "title_he", "title_en",
            "hebrew", "english", "name",
            "name_he", "name_en", "category", "subcat"
        ]
        var result: [HolidayEntry] = []

        for rawItem in rawItems {
            guard let item = rawItem as? [String: Any] else {
                continue
            }
            let nameHe = firstNonBlank(
                item,
                keys: ["title_he", "hebrew", "name_he", "name", "title"]
            )
            let nameEn = firstNonBlank(
                item,
                keys: ["title_en", "english", "name_en", "title", "name"]
            )
            let cancellationSource = cancellationKeys
                .map { value(item, $0) }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            for date in datesFor(item) {
                result.append(
                    HolidayEntry(
                        date: date,
                        name: nameHe,
                        nameEn: nameEn,
                        cancellationSource: cancellationSource
                    )
                )
            }
        }

        return uniqueEntries(result)
    }

    private static func generateFallbackEntries() -> [HolidayEntry] {
        let timeZone =
            TimeZone(identifier: "Asia/Jerusalem")
            ?? TimeZone(secondsFromGMT: 0)!
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone

        let currentYear = gregorian.component(.year, from: Date())
        let hebrewFormatter = HebrewDateFormatter()
        hebrewFormatter.hebrewFormat = true
        let englishFormatter = HebrewDateFormatter()
        englishFormatter.hebrewFormat = false

        var result: [HolidayEntry] = []
        for year in (currentYear - 2)...(currentYear + 3) {
            guard !(2024...2026).contains(year),
                  let start = gregorian.date(
                    from: DateComponents(year: year, month: 1, day: 1)
                  ),
                  let end = gregorian.date(
                    from: DateComponents(year: year + 1, month: 1, day: 1)
                  ) else {
                continue
            }

            var date = start
            while date < end {
                let jewishCalendar = JewishCalendar(
                    workingDate: date,
                    timezone: timeZone,
                    inIsrael: true,
                    useModernHolidays: true
                )
                let index = jewishCalendar.getYomTovIndex()
                if index >= 0 {
                    var nameHe = hebrewFormatter
                        .formatYomTov(jewishCalendar: jewishCalendar)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    var nameEn = englishFormatter
                        .formatYomTov(jewishCalendar: jewishCalendar)
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if !nameHe.isEmpty || !nameEn.isEmpty {
                        if index == JewishCalendar.SHEMINI_ATZERES {
                            nameHe = "שמחת תורה / שמיני עצרת"
                            nameEn = "Simchat Torah / Shemini Atzeret"
                        }
                        result.append(
                            HolidayEntry(
                                date: date,
                                name: nameHe,
                                nameEn: nameEn,
                                cancellationSource:
                                    calculatedCancellationSource(
                                        holidayIndex: index
                                    )
                            )
                        )
                    }
                }

                guard let nextDate = gregorian.date(
                    byAdding: .day,
                    value: 1,
                    to: date
                ), nextDate > date else {
                    break
                }
                date = nextDate
            }
        }
        return uniqueEntries(result)
    }

    private static func calculatedCancellationSource(
        holidayIndex: Int
    ) -> String {
        switch holidayIndex {
        case JewishCalendar.TISHA_BEAV:
            return "צום תשעה באב"
        case JewishCalendar.EREV_ROSH_HASHANA:
            return "ערב ראש השנה"
        case JewishCalendar.ROSH_HASHANA:
            return "ראש השנה"
        case JewishCalendar.EREV_YOM_KIPPUR:
            return "ערב יום כיפור"
        case JewishCalendar.YOM_KIPPUR:
            return "יום כיפור"
        case JewishCalendar.EREV_SUCCOS:
            return "ערב סוכות"
        case JewishCalendar.SUCCOS:
            return "סוכות"
        case JewishCalendar.CHOL_HAMOED_SUCCOS,
             JewishCalendar.HOSHANA_RABBA:
            return "חול המועד סוכות"
        case JewishCalendar.SHEMINI_ATZERES,
             JewishCalendar.SIMCHAS_TORAH:
            return "שמחת תורה"
        case JewishCalendar.EREV_PESACH:
            return "ערב פסח"
        case JewishCalendar.PESACH:
            return "פסח"
        case JewishCalendar.CHOL_HAMOED_PESACH:
            return "חול המועד פסח"
        case JewishCalendar.EREV_SHAVUOS:
            return "ערב שבועות"
        case JewishCalendar.SHAVUOS:
            return "שבועות"
        default:
            return ""
        }
    }

    private static func entriesForHebrewYear(
        _ year: Int,
        hebrewCalendar: Calendar
    ) -> [HolidayEntry] {
        var entries: [HolidayEntry] = []

        func add(_ month: Int, _ day: Int, _ name: String) {
            var comps = DateComponents()
            comps.calendar = hebrewCalendar
            comps.year = year
            comps.month = month
            comps.day = day

            if let date = hebrewCalendar.date(from: comps) {
                entries.append(HolidayEntry(date: date, name: name))
            }
        }

        // תשרי
        add(1, 1, "ראש השנה")
        add(1, 2, "ראש השנה")
        add(1, 9, "ערב יום כיפור")
        add(1, 10, "יום כיפור")
        add(1, 14, "ערב סוכות")
        add(1, 15, "סוכות")
        add(1, 16, "חול המועד סוכות")
        add(1, 17, "חול המועד סוכות")
        add(1, 18, "חול המועד סוכות")
        add(1, 19, "חול המועד סוכות")
        add(1, 20, "חול המועד סוכות")
        add(1, 21, "הושענא רבה")
        add(1, 22, "שמיני עצרת")
        add(1, 22, "שמחת תורה")

        // ניסן
        add(7, 14, "ערב פסח")
        add(7, 15, "פסח")
        add(7, 16, "חול המועד פסח")
        add(7, 17, "חול המועד פסח")
        add(7, 18, "חול המועד פסח")
        add(7, 19, "חול המועד פסח")
        add(7, 20, "חול המועד פסח")
        add(7, 21, "שביעי של פסח")

        // סיוון
        add(9, 5, "ערב שבועות")
        add(9, 6, "שבועות")

        return entries
    }
}
