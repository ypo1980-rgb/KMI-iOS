import SwiftUI

struct MonthlyBoardDayCell: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.kmiFontScale) private var displayScale

    let item: MonthlyBoardDayItem
    let isSelected: Bool
    let onTap: () -> Void

    private var isEnglish: Bool {
        layoutDirection == .leftToRight
    }

    private var cellHeight: CGFloat {
        88 * max(1, displayScale)
    }

    private var cancellationColor: Color {
        KmiAppTheme.onErrorContainer(for: colorScheme)
    }

    var body: some View {
        Group {
            if item.kind == .empty {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        KmiAppTheme.surface(for: colorScheme)
                            .opacity(0.45)
                    )
                    .frame(height: cellHeight)
            } else {
                Button(action: onTap) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                if item.hasHolidays ||
                                    fallbackHolidayTitle != nil ||
                                    item.hasCancelledTraining {
                                    Circle()
                                        .fill(cancellationColor)
                                        .frame(width: 8, height: 8)
                                        .accessibilityLabel(
                                            item.hasCancelledTraining
                                                ? (isEnglish ? "Cancelled training" : "אימון שבוטל")
                                                : (isEnglish ? "Holiday or Saturday" : "חג או שבת")
                                        )
                                }

                                if item.hasTrainings {
                                    Circle()
                                        .fill(trainingColor)
                                        .frame(width: 8, height: 8)
                                        .accessibilityLabel(
                                            isEnglish ? "Training" : "אימון"
                                        )
                                }

                                if item.hasSummary {
                                    Image(systemName: "doc.text.fill")
                                        .kmiIconSize(9)
                                        .foregroundStyle(
                                            KmiAppTheme.secondary(for: colorScheme)
                                        )
                                        .accessibilityLabel(
                                            isEnglish ? "Training summary" : "סיכום אימון"
                                        )
                                }
                            }

                            Spacer()

                            Text(item.dayNumberText)
                                .kmiFont(
                                    size: 16,
                                    weight: item.isToday ? .heavy : .bold
                                )
                                .foregroundStyle(textColor)
                        }

                        Spacer()

                        VStack(alignment: .leading, spacing: 2) {
                            if let holidayTitle = displayHolidayTitle {
                                Text(holidayTitle)
                                    .kmiFont(size: 10, weight: .semibold)
                                    .foregroundStyle(cancellationColor)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: .leading
                                    )
                            }

                            if let training = item.trainings.first {
                                Text(
                                    TrainingCatalogIOS.displayGroup(
                                        training.title,
                                        isEnglish: isEnglish
                                    )
                                )
                                .kmiFont(size: 10, weight: .semibold)
                                .foregroundStyle(
                                    KmiAppTheme.onSurface(for: colorScheme)
                                )
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
                            } else if shouldShowNoTrainingText {
                                Text(isEnglish ? "No training" : "אין אימונים")
                                    .kmiFont(size: 10, weight: .semibold)
                                    .foregroundStyle(
                                        KmiAppTheme.onSurfaceVariant(for: colorScheme)
                                    )
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
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
        KmiAppTheme.surface(for: colorScheme)
    }

    private var borderColor: Color {
        if isSelected {
            return KmiAppTheme.primary(for: colorScheme)
        }

        if item.isToday {
            return KmiAppTheme.secondary(for: colorScheme)
        }

        return KmiAppTheme.outline(for: colorScheme)
            .opacity(0.45)
    }

    private var textColor: Color {
        KmiAppTheme.onSurface(for: colorScheme)
    }

    private var trainingColor: Color {
        KmiAppTheme.primary(for: colorScheme)
    }
    private var fallbackHolidayTitle: String? {
        guard let date = item.date else { return nil }

        if let firstHoliday = ShabbatHolidayCheckerIOS.holidayNamesForDisplay(on: date).first {
            return firstHoliday
        }

        if ShabbatHolidayCheckerIOS.calendar.component(
            .weekday,
            from: date
        ) == 7 {
            return isEnglish ? "Saturday" : "שבת"
        }

        return nil
    }

    private var displayHolidayTitle: String? {
        guard let date = item.date else {
            return nil
        }

        if let holidayName =
            HolidayCalendarStore.holidayNamesForDisplay(
                on: date,
                isEnglish: isEnglish
            ).first {
            return holidayName
        }

        if ShabbatHolidayCheckerIOS.calendar.component(
            .weekday,
            from: date
        ) == 7 {
            return isEnglish ? "Saturday" : "שבת"
        }

        return item.holidays.first?.title
    }

    private var shouldShowNoTrainingText: Bool {
        guard let date = item.date else { return false }
        return item.trainings.isEmpty && ShabbatHolidayCheckerIOS.isBlockedDate(date)
    }
}
