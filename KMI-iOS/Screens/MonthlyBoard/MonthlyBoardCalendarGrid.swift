import SwiftUI

struct MonthlyBoardCalendarGrid: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.calendar) private var calendar
    @Environment(\.layoutDirection) private var layoutDirection

    let monthData: MonthlyBoardMonthData
    let selectedDate: Date?
    var summaryDays: Set<Date> = []
    let onSelectDay: (MonthlyBoardDayItem) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        VStack(spacing: 6) {

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(monthData.weekdaySymbolsHeb.indices, id: \.self) { index in
                    Text(monthData.weekdaySymbolsHeb[index])
                        .kmiTypography(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            KmiAppTheme.onSurface(for: colorScheme)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }
            }
            .padding(.horizontal, 6)
            .background(
                Capsule()
                    .fill(KmiAppTheme.surfaceVariant(for: colorScheme))
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        KmiAppTheme.outlineVariant(for: colorScheme),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            )

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(monthData.dayItems) { item in
                    let needsSummaryMarker = item.kind == .day &&
                        !item.hasSummary &&
                        (item.date.map {
                            summaryDays.contains(calendar.startOfDay(for: $0))
                        } ?? false)

                    MonthlyBoardDayCell(
                        item: item,
                        isSelected: isItemSelected(item)
                    ) {
                        if item.kind == .day {
                            onSelectDay(item)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if needsSummaryMarker {
                            Image(systemName: "doc.fill")
                                .kmiIconSize(8)
                                .foregroundStyle(
                                    KmiAppTheme.primary(for: colorScheme)
                                )
                                .padding(3)
                                .accessibilityHidden(true)
                                .allowsHitTesting(false)
                        }
                    }
                    .accessibilityHint(
                        needsSummaryMarker
                            ? Text(layoutDirection == .rightToLeft
                                   ? "סיכום אימון שמור"
                                   : "Training summary saved")
                            : Text("")
                    )
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(KmiAppTheme.surface(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(
                        KmiAppTheme.outlineVariant(for: colorScheme),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            )
        }
    }

    private func isItemSelected(_ item: MonthlyBoardDayItem) -> Bool {
        guard let selectedDate,
              let itemDate = item.date else {
            return false
        }

        return calendar.isDate(
            selectedDate,
            inSameDayAs: itemDate
        )
    }
}
