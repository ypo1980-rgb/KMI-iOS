import Foundation

enum MonthlyTrainingBoardBuilder {

    static func buildMonth(
        for monthDate: Date,
        calendar: Calendar = MonthlyTrainingBoardBuilder.makeCalendar()
    ) -> MonthlyBoardMonthData {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthDate) else {
            return MonthlyBoardMonthData(
                monthDate: monthDate,
                titleHeb: "",
                weekdaySymbolsHeb: hebrewWeekdaySymbols(),
                dayItems: []
            )
        }

        let trainings = MonthlyTrainingBoardDataSource.trainings(forMonth: monthDate, calendar: calendar)
        let holidays = MonthlyTrainingBoardDataSource.holidays(forMonth: monthDate, calendar: calendar)

        let trainingsByKey = Dictionary(grouping: trainings) { dateKey(for: $0.date, calendar: calendar) }
        let holidaysByKey = Dictionary(grouping: holidays) { dateKey(for: $0.date, calendar: calendar) }

        let firstDayOfMonth = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) // 1=Sunday
        let leadingEmptyCount = max(firstWeekday - 1, 0)

        var items: [MonthlyBoardDayItem] = []

        for index in 0..<leadingEmptyCount {
            items.append(.empty(id: "leading_empty_\(index)"))
        }

        var currentDate = firstDayOfMonth
        while currentDate < monthInterval.end {
            let key = dateKey(for: currentDate, calendar: calendar)
            let day = calendar.component(.day, from: currentDate)

            let existingHolidays = holidaysByKey[key] ?? []
            let isBlocked = ShabbatHolidayCheckerIOS.isBlockedDate(currentDate)

            let effectiveTrainings = (isBlocked || !existingHolidays.isEmpty)
                ? []
                : (trainingsByKey[key] ?? [])
            
            items.append(
                MonthlyBoardDayItem(
                    id: key,
                    kind: .day,
                    date: currentDate,
                    dayNumberText: "\(day)",
                    isToday: calendar.isDateInToday(currentDate),
                    isInDisplayedMonth: true,
                    trainings: effectiveTrainings,
                    holidays: existingHolidays
                )
            )

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDay
        }

        while items.count % 7 != 0 {
            items.append(.empty(id: "trailing_empty_\(items.count)"))
        }

        return MonthlyBoardMonthData(
            monthDate: monthDate,
            titleHeb: monthTitleHeb(for: monthDate, calendar: calendar),
            weekdaySymbolsHeb: hebrewWeekdaySymbols(),
            dayItems: items
        )
    }

    static func details(
        for day: MonthlyBoardDayItem,
        calendar: Calendar = MonthlyTrainingBoardBuilder.makeCalendar()
    ) -> MonthlyBoardSelectedDayDetails? {
        guard let date = day.date else { return nil }
        return MonthlyBoardSelectedDayDetails(
            date: date,
            titleHeb: fullHebrewDateString(for: date, calendar: calendar),
            trainings: day.trainings,
            holidays: day.holidays
        )
    }

    static func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "he_IL")
        calendar.timeZone = .current
        return calendar
    }

    static func nextMonth(from date: Date, calendar: Calendar = MonthlyTrainingBoardBuilder.makeCalendar()) -> Date {
        calendar.date(byAdding: .month, value: 1, to: startOfMonth(date, calendar: calendar)) ?? date
    }

    static func previousMonth(from date: Date, calendar: Calendar = MonthlyTrainingBoardBuilder.makeCalendar()) -> Date {
        calendar.date(byAdding: .month, value: -1, to: startOfMonth(date, calendar: calendar)) ?? date
    }

    static func startOfMonth(_ date: Date, calendar: Calendar = MonthlyTrainingBoardBuilder.makeCalendar()) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }

    private static func dateKey(for date: Date, calendar: Calendar) -> String {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return "\(year)_\(month)_\(day)"
    }

    private static func monthTitleHeb(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "he_IL")
        formatter.calendar = calendar
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }

    private static func fullHebrewDateString(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "he_IL")
        formatter.calendar = calendar
        formatter.dateFormat = "EEEE, d בMMMM yyyy"
        return formatter.string(from: date)
    }

    private static func hebrewWeekdaySymbols() -> [String] {
        ["א", "ב", "ג", "ד", "ה", "ו", "ש"]
    }
}
