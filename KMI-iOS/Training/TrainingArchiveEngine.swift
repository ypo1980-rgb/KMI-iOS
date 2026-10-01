import Foundation

struct TrainingArchiveSource: Hashable {
    let training: TrainingData
    let branch: String
    let group: String
}

enum TrainingArchiveStatus: Hashable {
    case completed
    case cancelledByCoach
    case cancelledByCalendar

    var isCancelled: Bool {
        self != .completed
    }

    func title(isEnglish: Bool) -> String {
        switch self {
        case .completed:
            return isEnglish ? "Completed" : "הסתיים"

        case .cancelledByCoach:
            return isEnglish
                ? "Cancelled by coach"
                : "בוטל על ידי המאמן"

        case .cancelledByCalendar:
            return isEnglish
                ? "Cancelled due to Shabbat or holiday"
                : "בוטל עקב שבת או חג"
        }
    }
}

struct TrainingArchiveItem: Identifiable {
    let id: String
    let training: TrainingData
    let branch: String
    let group: String
    let originalStartDate: Date
    let effectiveStartDate: Date
    let effectiveEndDate: Date
    let status: TrainingArchiveStatus
    let activeOverride: TrainingOverride?

    var isCancelled: Bool {
        status.isCancelled
    }

    var isCompleted: Bool {
        status == .completed
    }
}

enum TrainingArchiveEngine {

    private static var calendar: Calendar {
        ShabbatHolidayCheckerIOS.calendar
    }

    /// משחזר מופעי עבר מהאימונים השבועיים של מסך הבית.
    /// הסינון לפי טווח מתייחס לתאריך המקורי, כמו באנדרואיד.
    static func buildItems(
        sources: [TrainingArchiveSource],
        fromDate: Date,
        toDate: Date,
        overrides: [String: TrainingOverride],
        now: Date = Date()
    ) -> [TrainingArchiveItem] {
        let rangeStart = calendar.startOfDay(for: fromDate)
        let rangeLastDay = calendar.startOfDay(for: toDate)

        guard rangeStart <= rangeLastDay,
              let rangeEnd = calendar.date(
                  byAdding: .day,
                  value: 1,
                  to: rangeLastDay
              ) else {
            return []
        }

        var seen = Set<String>()
        var result: [TrainingArchiveItem] = []

        for source in sources {
            var occurrenceDate = source.training.date

            // מאפשר גם מקור ישן יותר מהטווח המבוקש.
            var forwardSteps = 0

            while occurrenceDate < rangeStart,
                  forwardSteps < 520 {
                guard let nextDate = calendar.date(
                    byAdding: .weekOfYear,
                    value: 1,
                    to: occurrenceDate
                ),
                nextDate > occurrenceDate else {
                    break
                }

                occurrenceDate = nextDate
                forwardSteps += 1
            }

            // מגיעים למופע האחרון שנמצא לפני סוף הטווח.
            var backwardSteps = 0

            while occurrenceDate >= rangeEnd,
                  backwardSteps < 520 {
                guard let previousDate = calendar.date(
                    byAdding: .weekOfYear,
                    value: -1,
                    to: occurrenceDate
                ),
                previousDate < occurrenceDate else {
                    break
                }

                occurrenceDate = previousDate
                backwardSteps += 1
            }

            var generatedCount = 0

            while occurrenceDate >= rangeStart,
                  occurrenceDate < rangeEnd,
                  generatedCount < 520 {
                if occurrenceDate < now {
                    let training = makeOccurrence(
                        from: source.training,
                        date: occurrenceDate
                    )

                    let occurrenceKey =
                        TrainingOverrideRepository.buildOccurrenceKey(
                            training: training,
                            branch: source.branch,
                            group: source.group
                        )

                    if seen.insert(occurrenceKey).inserted {
                        let activeOverride = overrides[occurrenceKey]
                            .flatMap {
                                $0.isActive ? $0 : nil
                            }

                        let originalEndDate = endDate(
                            for: training
                        )

                        let effectiveStartDate: Date
                        let effectiveEndDate: Date

                        if let activeOverride,
                           activeOverride.hasChangedTime {
                            effectiveStartDate =
                                activeOverride.effectiveStartDate

                            effectiveEndDate =
                                activeOverride.effectiveEndDate
                        } else {
                            effectiveStartDate = training.date
                            effectiveEndDate = originalEndDate
                        }

                        let status: TrainingArchiveStatus?

                        if activeOverride?.isCancelled == true {
                            status = .cancelledByCoach
                        } else if ShabbatHolidayCheckerIOS
                            .isBlockedDate(training.date) {
                            status = .cancelledByCalendar
                        } else if effectiveEndDate <= now {
                            status = .completed
                        } else {
                            // אימון שעדיין מתקיים או הוזז לעתיד
                            // אינו מוצג כאימון שהסתיים.
                            status = nil
                        }

                        if let status {
                            result.append(
                                TrainingArchiveItem(
                                    id: occurrenceKey,
                                    training: training,
                                    branch: source.branch,
                                    group: source.group,
                                    originalStartDate: training.date,
                                    effectiveStartDate: effectiveStartDate,
                                    effectiveEndDate: effectiveEndDate,
                                    status: status,
                                    activeOverride: activeOverride
                                )
                            )
                        }
                    }
                }

                guard let previousDate = calendar.date(
                    byAdding: .weekOfYear,
                    value: -1,
                    to: occurrenceDate
                ),
                previousDate < occurrenceDate else {
                    break
                }

                occurrenceDate = previousDate
                generatedCount += 1
            }
        }

        return result.sorted { left, right in
            if left.effectiveStartDate == right.effectiveStartDate {
                return left.id < right.id
            }

            return left.effectiveStartDate > right.effectiveStartDate
        }
    }

    private static func makeOccurrence(
        from training: TrainingData,
        date: Date
    ) -> TrainingData {
        TrainingData(
            id: "\(training.id)|archive|\(Int64(date.timeIntervalSince1970 * 1000))",
            date: date,
            startText: training.startText,
            endText: training.endText,
            place: training.place,
            address: training.address,
            coach: training.coach
        )
    }

    private static func endDate(
        for training: TrainingData
    ) -> Date {
        let parts = training.endText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":")

        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return calendar.date(
                byAdding: .minute,
                value: 90,
                to: training.date
            ) ?? training.date
        }

        var components = calendar.dateComponents(
            [.year, .month, .day],
            from: training.date
        )

        components.hour = hour
        components.minute = minute
        components.second = 0
        components.timeZone = calendar.timeZone

        guard var resolvedEndDate = calendar.date(
            from: components
        ) else {
            return calendar.date(
                byAdding: .minute,
                value: 90,
                to: training.date
            ) ?? training.date
        }

        if resolvedEndDate <= training.date {
            resolvedEndDate = calendar.date(
                byAdding: .day,
                value: 1,
                to: resolvedEndDate
            ) ?? resolvedEndDate
        }

        return resolvedEndDate
    }
}
