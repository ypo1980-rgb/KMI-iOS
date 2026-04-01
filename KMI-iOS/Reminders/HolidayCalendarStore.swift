import Foundation

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
    }

    static func loadEntries() -> [HolidayEntry] {
        let bundleEntries = loadEntriesFromBundle()
        if !bundleEntries.isEmpty {
            return bundleEntries
        }

        return generateFallbackEntries()
    }

    private static func loadEntriesFromBundle() -> [HolidayEntry] {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension),
              let data = try? Data(contentsOf: url),
              let root = try? JSONDecoder().decode(HolidayFileRoot.self, from: data)
        else {
            return []
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Jerusalem")
        formatter.dateFormat = "yyyy-MM-dd"

        return root.items.compactMap { item in
            let cleanName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !cleanName.isEmpty,
                  let iso = item.date_iso,
                  let date = formatter.date(from: iso)
            else {
                return nil
            }

            return HolidayEntry(date: date, name: cleanName)
        }
        .sorted { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.name < rhs.name
            }
            return lhs.date < rhs.date
        }
    }

    private static func generateFallbackEntries() -> [HolidayEntry] {
        let hebrewCalendar = Calendar(identifier: .hebrew)
        let gregorian = Calendar(identifier: .gregorian)

        let currentGregorianYear = gregorian.component(.year, from: Date())
        let years = Array((currentGregorianYear - 2)...(currentGregorianYear + 3))

        var result: [HolidayEntry] = []

        for gregorianYear in years {
            guard let approxDate = gregorian.date(from: DateComponents(year: gregorianYear, month: 6, day: 1)) else {
                continue
            }

            let hebrewYear = hebrewCalendar.component(.year, from: approxDate)

            for y in [hebrewYear - 1, hebrewYear, hebrewYear + 1] {
                result.append(contentsOf: entriesForHebrewYear(y, hebrewCalendar: hebrewCalendar))
            }
        }

        let unique = Dictionary(grouping: result) { "\($0.name)|\($0.date.timeIntervalSince1970)" }
            .compactMap { $0.value.first }

        return unique.sorted {
            if $0.date == $1.date {
                return $0.name < $1.name
            }
            return $0.date < $1.date
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
