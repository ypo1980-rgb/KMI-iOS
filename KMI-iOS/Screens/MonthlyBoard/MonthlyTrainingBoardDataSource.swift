import Foundation

enum MonthlyTrainingBoardDataSource {

    static func weeklyTrainingTemplates() -> [MonthlyBoardTrainingTemplate] {
        [
            MonthlyBoardTrainingTemplate(
                id: "sun_kids_a",
                weekday: 1,
                title: "אימון ילדים מתחילים",
                timeText: "17:00–18:00",
                location: "אולם ספורט מרכזי",
                notes: "דגש על בסיס ועמידות מוצא"
            ),
            MonthlyBoardTrainingTemplate(
                id: "mon_teens",
                weekday: 2,
                title: "אימון נוער",
                timeText: "18:30–19:45",
                location: "סטודיו קרב מגע",
                notes: "שילוב עבודת ידיים והגנות"
            ),
            MonthlyBoardTrainingTemplate(
                id: "wed_adults",
                weekday: 4,
                title: "אימון בוגרים",
                timeText: "20:00–21:15",
                location: "אולם ספורט מרכזי",
                notes: "עבודה לפי חגורות"
            ),
            MonthlyBoardTrainingTemplate(
                id: "thu_coach",
                weekday: 5,
                title: "אימון מאמנים",
                timeText: "21:00–22:00",
                location: "חדר הדרכה",
                notes: "מבחנים, תיקונים ומתודיקה"
            )
        ]
    }

    static func trainings(forMonth monthDate: Date, calendar: Calendar) -> [MonthlyBoardTrainingItem] {
        let templates = weeklyTrainingTemplates()

        guard
            let monthInterval = calendar.dateInterval(of: .month, for: monthDate),
            let startDay = calendar.dateInterval(of: .day, for: monthInterval.start)?.start
        else {
            return []
        }

        var items: [MonthlyBoardTrainingItem] = []
        var cursor = startDay

        while cursor < monthInterval.end {
            let weekday = hebrewStyleWeekday(from: calendar.component(.weekday, from: cursor))

            for template in templates where template.weekday == weekday {
                let dateKey = compactDateKey(cursor, calendar: calendar)
                items.append(
                    MonthlyBoardTrainingItem(
                        id: "\(template.id)_\(dateKey)",
                        date: cursor,
                        title: template.title,
                        timeText: template.timeText,
                        location: template.location,
                        notes: template.notes
                    )
                )
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return items.sorted {
            if $0.date == $1.date {
                return $0.timeText < $1.timeText
            }
            return $0.date < $1.date
        }
    }

    static func holidays(forMonth monthDate: Date, calendar: Calendar) -> [MonthlyBoardHolidayItem] {
        var result: [MonthlyBoardHolidayItem] = []

        let gregorianMonth = calendar.component(.month, from: monthDate)
        let gregorianYear = calendar.component(.year, from: monthDate)

        let hebrewCalendar = Calendar(identifier: .hebrew)

        // כדי לא לפספס חודשים שחוצים שנה עברית
        let approxHebrewYear = hebrewCalendar.component(.year, from: monthDate)
        let hebrewYearsToCheck = [approxHebrewYear - 1, approxHebrewYear, approxHebrewYear + 1]

        let holidayDefinitions: [(month: Int, day: Int, title: String, isMajor: Bool)] = [
            (1, 1, "ראש השנה", true),
            (1, 2, "ראש השנה ב׳", true),
            (1, 10, "יום כיפור", true),
            (1, 15, "סוכות", true),
            (1, 22, "שמחת תורה", true),

            (3, 25, "חנוכה", false),

            (7, 15, "פסח", true),
            (7, 21, "שביעי של פסח", true),

            (9, 6, "שבועות", true),

            (5, 18, "ל״ג בעומר", false),
            (11, 5, "ט״ו בשבט", false)
        ]

        for year in hebrewYearsToCheck {
            for holiday in holidayDefinitions {
                var comps = DateComponents()
                comps.calendar = hebrewCalendar
                comps.year = year
                comps.month = holiday.month
                comps.day = holiday.day

                if let date = hebrewCalendar.date(from: comps) {
                    let month = calendar.component(.month, from: date)
                    let year = calendar.component(.year, from: date)

                    if month == gregorianMonth && year == gregorianYear {
                        let dateKey = compactDateKey(date, calendar: calendar)
                        result.append(
                            MonthlyBoardHolidayItem(
                                id: "holiday_\(holiday.title)_\(dateKey)",
                                date: date,
                                title: holiday.title,
                                isMajor: holiday.isMajor
                            )
                        )
                    }
                }
            }
        }

        return result.sorted { $0.date < $1.date }
    }

    private static func compactDateKey(_ date: Date, calendar: Calendar) -> String {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return "\(year)_\(month)_\(day)"
    }

    private static func hebrewStyleWeekday(from systemWeekday: Int) -> Int {
        // Calendar weekday: 1=Sunday ... 7=Saturday
        systemWeekday
    }
}
