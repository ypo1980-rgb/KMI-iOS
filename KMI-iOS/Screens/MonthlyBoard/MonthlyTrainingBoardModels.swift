import Foundation

enum MonthlyBoardCellKind: Equatable {
    case empty
    case day
}

struct MonthlyBoardTrainingTemplate: Identifiable, Hashable {
    let id: String
    let weekday: Int   // 1=Sunday ... 7=Saturday (Hebrew locale style)
    let title: String
    let timeText: String
    let location: String
    let notes: String?
}

struct MonthlyBoardTrainingItem: Identifiable, Hashable {
    let id: String
    let date: Date
    let title: String
    let timeText: String
    let location: String
    let notes: String?
}

struct MonthlyBoardHolidayItem: Identifiable, Hashable {
    let id: String
    let date: Date
    let title: String
    let isMajor: Bool
}

struct MonthlyBoardDayItem: Identifiable, Hashable {
    let id: String
    let kind: MonthlyBoardCellKind
    let date: Date?
    let dayNumberText: String
    let isToday: Bool
    let isInDisplayedMonth: Bool
    let trainings: [MonthlyBoardTrainingItem]
    let holidays: [MonthlyBoardHolidayItem]

    var hasTrainings: Bool { !trainings.isEmpty }
    var hasHolidays: Bool { !holidays.isEmpty }

    static func empty(id: String) -> MonthlyBoardDayItem {
        MonthlyBoardDayItem(
            id: id,
            kind: .empty,
            date: nil,
            dayNumberText: "",
            isToday: false,
            isInDisplayedMonth: false,
            trainings: [],
            holidays: []
        )
    }
}

struct MonthlyBoardMonthData: Hashable {
    let monthDate: Date
    let titleHeb: String
    let weekdaySymbolsHeb: [String]
    let dayItems: [MonthlyBoardDayItem]
}

struct MonthlyBoardSelectedDayDetails: Hashable {
    let date: Date
    let titleHeb: String
    let trainings: [MonthlyBoardTrainingItem]
    let holidays: [MonthlyBoardHolidayItem]
}
