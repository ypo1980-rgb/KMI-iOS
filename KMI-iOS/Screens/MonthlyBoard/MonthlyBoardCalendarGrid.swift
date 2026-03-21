import SwiftUI

struct MonthlyBoardCalendarGrid: View {
    let monthData: MonthlyBoardMonthData
    let selectedDate: Date?
    let onSelectDay: (MonthlyBoardDayItem) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(monthData.weekdaySymbolsHeb.indices, id: \.self) { index in
                    Text(monthData.weekdaySymbolsHeb[index])
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.90))
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
        guard let selectedDate, let itemDate = item.date else { return false }
        return Calendar.current.isDate(selectedDate, inSameDayAs: itemDate)
    }
}
