import Foundation

enum ShabbatHolidayCheckerIOS {

    static let timeZone = TimeZone(identifier: "Asia/Jerusalem")!

    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal
    }()

    private static let entries = HolidayCalendarStore.loadEntries()

    static func isBlockedDate(_ date: Date) -> Bool {
        isSaturday(date) || isHolidayBlocked(date)
    }

    static func isAdjustedEarlyDate(_ date: Date) -> Bool {
        isFriday(date) || isErevHoliday(date)
    }

    static func holidayNamesForDisplay(on date: Date) -> [String] {
        entries
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .map(\.name)
    }

    static func nextAllowedTriggerDate(
        preferredHour: Int,
        preferredMinute: Int,
        now: Date = Date()
    ) -> Date {
        var candidate = setTime(
            on: now,
            hour: preferredHour,
            minute: preferredMinute
        )

        if candidate <= now {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
            candidate = setTime(on: candidate, hour: preferredHour, minute: preferredMinute)
        }

        for _ in 0..<60 {
            if isBlockedDate(candidate) {
                candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
                candidate = setTime(on: candidate, hour: preferredHour, minute: preferredMinute)
                continue
            }

            if isAdjustedEarlyDate(candidate) {
                candidate = setTime(on: candidate, hour: 13, minute: 0)

                if candidate <= now {
                    candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
                    candidate = setTime(on: candidate, hour: preferredHour, minute: preferredMinute)
                    continue
                }
            }

            return candidate
        }

        return candidate
    }

    private static func isFriday(_ date: Date) -> Bool {
        calendar.component(.weekday, from: date) == 6
    }

    private static func isSaturday(_ date: Date) -> Bool {
        calendar.component(.weekday, from: date) == 7
    }

    private static func isHolidayBlocked(_ date: Date) -> Bool {
        holidayNames(on: date).contains(where: isBlockingHolidayName)
    }

    private static func isErevHoliday(_ date: Date) -> Bool {
        holidayNames(on: date).contains(where: isBlockingErevHolidayName)
    }

    private static func holidayNames(on date: Date) -> [String] {
        holidayNamesForDisplay(on: date)
    }

    private static func isBlockingHolidayName(_ name: String) -> Bool {
        let normalized = normalize(name)

        let blockedTokens = [
            "ראש השנה",
            "יום כיפור",
            "פסח",
            "חול המועד פסח",
            "שביעי של פסח",
            "שבועות",
            "סוכות",
            "חול המועד סוכות",
            "הושענא רבה",
            "שמיני עצרת",
            "שמחת תורה"
        ]

        return blockedTokens.contains { normalized.contains(normalize($0)) }
    }

    private static func isBlockingErevHolidayName(_ name: String) -> Bool {
        let normalized = normalize(name)

        let blockedTokens = [
            "ערב ראש השנה",
            "ערב יום כיפור",
            "ערב פסח",
            "ערב שבועות",
            "ערב סוכות"
        ]

        return blockedTokens.contains { normalized.contains(normalize($0)) }
    }

    private static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "׳", with: "'")
            .replacingOccurrences(of: "״", with: "\"")
            .replacingOccurrences(of: "–", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func setTime(on date: Date, hour: Int, minute: Int) -> Date {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)

        return calendar.date(from: DateComponents(
            timeZone: timeZone,
            year: comps.year,
            month: comps.month,
            day: comps.day,
            hour: hour,
            minute: minute,
            second: 0
        )) ?? date
    }
}
