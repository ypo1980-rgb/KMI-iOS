import SwiftUI

struct MonthlyBoardCalendarGrid: View {
    @Environment(\.colorScheme) private var colorScheme

    let monthData: MonthlyBoardMonthData
    let selectedDate: Date?
    let onSelectDay: (MonthlyBoardDayItem) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(monthData.weekdaySymbolsHeb.indices, id: \.self) { index in
                    Text(monthData.weekdaySymbolsHeb[index])
                        .kmiTypography(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            KmiAppTheme.onSurface(for: colorScheme)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(monthData.dayItems) { item in
                    MonthlyBoardDayCell(
                        item: item,
                        isSelected: isItemSelected(item)
                    ) {
                        if item.kind == .day {
                            onSelectDay(item)
                        }
                    }
                }
            }
        }
    }

    private func isItemSelected(_ item: MonthlyBoardDayItem) -> Bool {
        guard let selectedDate,
              let itemDate = item.date else {
            return false
        }

        return ShabbatHolidayCheckerIOS.calendar.isDate(
            selectedDate,
            inSameDayAs: itemDate
        )
    }
}
