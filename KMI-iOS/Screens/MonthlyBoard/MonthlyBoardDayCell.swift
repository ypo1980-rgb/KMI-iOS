import SwiftUI

struct MonthlyBoardDayCell: View {
    let item: MonthlyBoardDayItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Group {
            if item.kind == .empty {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 74)
            } else {
                Button(action: onTap) {
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                if item.hasHolidays || fallbackHolidayTitle != nil {
                                    Circle()
                                        .fill(item.holidays.first?.isMajor == true ? Color.red.opacity(0.95) : Color.red.opacity(0.95))
                                        .frame(width: 8, height: 8)
                                }

                                if item.hasTrainings {
                                    Circle()
                                        .fill(trainingColor)
                                        .frame(width: 8, height: 8)
                                }
                            }

                            Spacer()

                            Text(item.dayNumberText)
                                .font(.system(size: 16, weight: item.isToday ? .heavy : .bold))
                                .foregroundStyle(textColor)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            if let holidayTitle = displayHolidayTitle {
                                Text(holidayTitle)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.red.opacity(0.95))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }

                            if let training = item.trainings.first {
                                Text(training.title)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.92))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            } else if shouldShowNoTrainingText {
                                Text("אין אימונים")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.82))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .frame(height: 74)
                    .background(backgroundView)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(borderColor, lineWidth: isSelected ? 2 : (item.isToday ? 1.6 : 1))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(backgroundColor)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.cyan.opacity(0.22)
        }
        if item.isToday {
            return Color.white.opacity(0.18)
        }
        if item.hasHolidays || fallbackHolidayTitle != nil {
            return Color.red.opacity(0.12)
        }
        if item.hasTrainings {
            return Color.blue.opacity(0.14)
        }
        return Color.white.opacity(0.08)
    }

    private var borderColor: Color {
        if isSelected { return Color.cyan.opacity(0.95) }
        if item.isToday { return Color.white.opacity(0.75) }
        return Color.white.opacity(0.16)
    }

    private var textColor: Color {
        item.isToday ? .white : .white.opacity(0.95)
    }

    private var trainingColor: Color {

        guard let training = item.trainings.first else {
            return Color.blue.opacity(0.95)
        }

        let title = training.title

        if title.contains("ילד") {
            return Color.blue.opacity(0.95)
        }

        if title.contains("נוער") {
            return Color.green.opacity(0.95)
        }

        if title.contains("בוגר") {
            return Color.purple.opacity(0.95)
        }

        return Color.blue.opacity(0.95)
    }
    private var fallbackHolidayTitle: String? {
        guard let date = item.date else { return nil }

        if let firstHoliday = ShabbatHolidayCheckerIOS.holidayNamesForDisplay(on: date).first {
            return firstHoliday
        }

        if ShabbatHolidayCheckerIOS.isBlockedDate(date) {
            return "שבת"
        }

        return nil
    }

    private var displayHolidayTitle: String? {
        if let holiday = item.holidays.first {
            return holiday.title
        }
        return fallbackHolidayTitle
    }

    private var shouldShowNoTrainingText: Bool {
        guard let date = item.date else { return false }
        return item.trainings.isEmpty && ShabbatHolidayCheckerIOS.isBlockedDate(date)
    }
}
