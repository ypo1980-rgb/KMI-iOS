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
        44 * max(1, displayScale)
    }
    
    private var dayCircleSize: CGFloat {
        30 * max(1, displayScale)
    }
    
    private var isFutureDay: Bool {
        guard let date = item.date else { return false }
        
        return ShabbatHolidayCheckerIOS.calendar.compare(
            date,
            to: Date(),
            toGranularity: .day
        ) == .orderedDescending
    }
    
    private var cancellationColor: Color {
        KmiAppTheme.onErrorContainer(for: colorScheme)
    }
    
    var body: some View {
        if item.kind == .empty {
            Color.clear
                .frame(height: cellHeight)
                .accessibilityHidden(true)
        } else {
            let hasHoliday = item.hasHolidays || displayHolidayTitle != nil
            let selectionColor = KmiAppTheme.primary(for: colorScheme)
            
            Button(action: onTap) {
                VStack(spacing: 1) {
                    Text(item.dayNumberText)
                        .kmiFont(
                            size: 16,
                            weight: item.isToday || isSelected ? .heavy : .bold
                        )
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(
                            isSelected
                            ? KmiAppTheme.onPrimary(for: colorScheme)
                            : KmiAppTheme.onSurface(for: colorScheme)
                                .opacity(isFutureDay ? 0.45 : 1)
                        )
                        .frame(width: dayCircleSize, height: dayCircleSize)
                        .background {
                            if isSelected {
                                Circle().fill(selectionColor)
                            }
                        }
                        .overlay {
                            if item.isToday && !isSelected {
                                Circle().strokeBorder(
                                    KmiAppTheme.secondary(for: colorScheme),
                                    lineWidth: 1.5
                                )
                            }
                        }
                    
                    HStack(spacing: 3) {
                        if item.hasTrainings {
                            Circle()
                                .fill(selectionColor)
                                .frame(width: 5, height: 5)
                        }
                        
                        if hasHoliday {
                            Circle()
                                .fill(cancellationColor)
                                .frame(width: 5, height: 5)
                        }
                        
                        if item.hasCancelledTraining {
                            RoundedRectangle(cornerRadius: 1.5)
                                .strokeBorder(cancellationColor, lineWidth: 1)
                                .frame(width: 7, height: 7)
                        }
                        
                        if item.hasSummary {
                            Image(systemName: "doc.fill")
                                .kmiIconSize(8)
                                .foregroundStyle(selectionColor)
                        }
                    }
                    .frame(height: 10 * max(1, displayScale))
                    .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity)
                .frame(height: cellHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(dayAccessibilityLabel(hasHoliday: hasHoliday)))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }
    
    private func dayAccessibilityLabel(hasHoliday: Bool) -> String {
        var labels = [item.dayNumberText]
        
        if item.isToday {
            labels.append(isEnglish ? "Today" : "היום")
        }
        
        if item.hasTrainings {
            labels.append(isEnglish ? "Training" : "אימון")
        }
        
        if hasHoliday {
            labels.append(displayHolidayTitle ?? (isEnglish ? "Holiday" : "חג או מועד"))
        }
        
        if item.hasCancelledTraining {
            labels.append(isEnglish ? "Cancelled training" : "אימון שבוטל")
        }
        
        if item.hasSummary {
            labels.append(isEnglish ? "Training summary saved" : "סיכום אימון שמור")
        }
        
        return labels.joined(separator: ", ")
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
}
