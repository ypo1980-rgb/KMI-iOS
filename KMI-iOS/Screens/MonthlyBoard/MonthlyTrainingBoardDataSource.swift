import Foundation

enum MonthlyTrainingBoardDataSource {

    static func trainings(forMonth monthDate: Date, calendar: Calendar) -> [MonthlyBoardTrainingItem] {

        guard
            let monthInterval = calendar.dateInterval(of: .month, for: monthDate),
            let startDay = calendar.dateInterval(of: .day, for: monthInterval.start)?.start
        else {
            return []
        }

        var items: [MonthlyBoardTrainingItem] = []
        var cursor = startDay

        while cursor < monthInterval.end {

            if !ShabbatHolidayCheckerIOS.isBlockedDate(cursor) {

                let weekday = calendar.component(.weekday, from: cursor)

                let branch = UserDefaults.standard.string(forKey: "kmi.user.branch") ?? ""
                let group = UserDefaults.standard.string(forKey: "kmi.user.group") ?? ""

                let normalizedBranch = branch
                    .replacingOccurrences(of: "-", with: "–")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                let normalizedGroup = TrainingCatalogIOS.normalizeGroupName(group)

                let slots = TrainingCatalogIOS.slots.filter { slot in

                    let slotBranch = slot.branch
                        .replacingOccurrences(of: "-", with: "–")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if slot.dayOfWeek != weekday { return false }

                    if !normalizedBranch.isEmpty && slotBranch != normalizedBranch {
                        return false
                    }

                    if normalizedGroup.isEmpty {
                        return true
                    }

                    return slot.groups.contains {
                        TrainingCatalogIOS.normalizeGroupName($0) == normalizedGroup
                    }
                }
                
                for slot in slots {

                    let startDate = buildStartDate(
                        day: cursor,
                        hour: slot.startHour,
                        minute: slot.startMinute,
                        calendar: calendar
                    )

                    let endDate = startDate.addingTimeInterval(
                        TimeInterval(slot.durationMinutes * 60)
                    )

                    let startFormatter = DateFormatter()
                    startFormatter.locale = Locale(identifier: "he_IL")
                    startFormatter.dateFormat = "HH:mm"

                    let endFormatter = DateFormatter()
                    endFormatter.locale = Locale(identifier: "he_IL")
                    endFormatter.dateFormat = "HH:mm"

                    items.append(
                        MonthlyBoardTrainingItem(
                            id: slot.id + "_\(compactDateKey(cursor, calendar: calendar))",
                            date: startDate,
                            title: slot.groups.first ?? "אימון",
                            timeText: "\(startFormatter.string(from: startDate))–\(endFormatter.string(from: endDate))",
                            location: slot.place,
                            notes: slot.coach
                        )
                    )
                }
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return items.sorted { $0.date < $1.date }
    }

    static func holidays(forMonth monthDate: Date, calendar: Calendar) -> [MonthlyBoardHolidayItem] {

        guard
            let monthInterval = calendar.dateInterval(of: .month, for: monthDate),
            let startDay = calendar.dateInterval(of: .day, for: monthInterval.start)?.start
        else {
            return []
        }

        var result: [MonthlyBoardHolidayItem] = []
        var cursor = startDay

        while cursor < monthInterval.end {

            let names = ShabbatHolidayCheckerIOS.holidayNamesForDisplay(on: cursor)

            for name in names {
                result.append(
                    MonthlyBoardHolidayItem(
                        id: "holiday_\(name)_\(compactDateKey(cursor, calendar: calendar))",
                        date: cursor,
                        title: name,
                        isMajor: true
                    )
                )
            }

            if calendar.component(.weekday, from: cursor) == 7 {
                result.append(
                    MonthlyBoardHolidayItem(
                        id: "holiday_shabbat_\(compactDateKey(cursor, calendar: calendar))",
                        date: cursor,
                        title: "שבת",
                        isMajor: true
                    )
                )
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return result
    }

    private static func buildStartDate(
        day: Date,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date {

        var comps = calendar.dateComponents([.year,.month,.day], from: day)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0

        return calendar.date(from: comps) ?? day
    }

    private static func compactDateKey(_ date: Date, calendar: Calendar) -> String {
        let y = calendar.component(.year, from: date)
        let m = calendar.component(.month, from: date)
        let d = calendar.component(.day, from: date)
        return "\(y)_\(m)_\(d)"
    }
}
