import Foundation
import KosherSwift

enum ShabbatHolidayCheckerIOS {

    static let timeZone = TimeZone(identifier: "Asia/Jerusalem")!

    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal
    }()

    static func isBlockedDate(_ date: Date) -> Bool {
        isSaturday(date) || isHolidayBlocked(date)
    }

    static func isAdjustedEarlyDate(_ date: Date) -> Bool {
        isFriday(date) || isErevHoliday(date)
    }

    static func holidayNamesForDisplay(
        on date: Date,
        isEnglish: Bool = false
    ) -> [String] {
        HolidayCalendarStore.holidayNamesForDisplay(
            on: date,
            isEnglish: isEnglish
        )
    }

    private static let jerusalemLocation = GeoLocation(
        locationName: "Jerusalem, Israel",
        latitude: 31.778,
        longitude: 35.235,
        timeZone: timeZone
    )

    private static func zmanim(
        for date: Date
    ) -> (
        jewish: JewishCalendar,
        candleLighting: Date?,
        tzais: Date?
    ) {
        let midday = calendar.date(
            bySettingHour: 12,
            minute: 0,
            second: 0,
            of: date
        ) ?? date

        let jewish = JewishCalendar(
            workingDate: midday,
            timezone: timeZone,
            inIsrael: true,
            useModernHolidays: true
        )

        let zmanimCalendar = ComplexZmanimCalendar(
            location: jerusalemLocation
        )

        zmanimCalendar.workingDate = midday

        return (
            jewish: jewish,
            candleLighting: jewish.hasCandleLighting()
                ? zmanimCalendar.getCandleLighting()
                : nil,
            tzais: zmanimCalendar.getTzais()
        )
    }

    private static func isBlockedAt(
        _ date: Date,
        dayData: (
            jewish: JewishCalendar,
            candleLighting: Date?,
            tzais: Date?
        )
    ) -> Bool {

        if dayData.jewish.isAssurBemelacha() {
            guard let tzais = dayData.tzais else {
                return true
            }

            return date < tzais
        }

        if let candleLighting = dayData.candleLighting {
            return date >= candleLighting
        }

        return false
    }

    static func nextAllowedTriggerDate(
        preferredHour: Int,
        preferredMinute: Int,
        now: Date = Date()
    ) -> Date {

        let hour = min(max(preferredHour, 0), 23)
        let minute = min(max(preferredMinute, 0), 59)

        var candidateDay = now

        var preferredCandidate = setTime(
            on: candidateDay,
            hour: hour,
            minute: minute
        )

        if preferredCandidate <= now {
            guard let nextDay = calendar.date(
                byAdding: .day,
                value: 1,
                to: candidateDay
            ) else {
                return .distantFuture
            }

            candidateDay = nextDay
        }

        for _ in 0..<370 {

            let dayData = zmanim(for: candidateDay)

            preferredCandidate = setTime(
                on: candidateDay,
                hour: hour,
                minute: minute
            )

            var adjustedCandidate = preferredCandidate

            if let candleLighting = dayData.candleLighting {
                adjustedCandidate = candleLighting
                    .addingTimeInterval(-60 * 60)
            }

            if adjustedCandidate > now,
               !isBlockedAt(
                    adjustedCandidate,
                    dayData: dayData
               ) {
                return adjustedCandidate
            }

            guard let nextDay = calendar.date(
                byAdding: .day,
                value: 1,
                to: candidateDay
            ) else {
                return .distantFuture
            }

            candidateDay = nextDay
        }

        // אם לא נמצא מועד מותר, לא מחזירים
        // מועד שעלול ליפול בתוך שבת או חג.
        return .distantFuture
    }

    private static func isFriday(_ date: Date) -> Bool {
        calendar.component(.weekday, from: date) == 6
    }

    private static func isSaturday(_ date: Date) -> Bool {
        calendar.component(.weekday, from: date) == 7
    }

    private static func isHolidayBlocked(_ date: Date) -> Bool {
        HolidayCalendarStore.isTrainingCancelled(on: date)
    }

    private static func isErevHoliday(_ date: Date) -> Bool {

        holidayNames(on: date).contains { name in
            isBlockingErevHolidayName(name)
        }

    }

    private static func holidayNames(on date: Date) -> [String] {
        holidayNamesForDisplay(on: date)
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
