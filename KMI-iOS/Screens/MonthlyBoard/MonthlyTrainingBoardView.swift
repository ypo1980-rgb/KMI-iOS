import SwiftUI

struct MonthlyTrainingBoardView: View {
    @EnvironmentObject private var nav: AppNavModel

    @State private var visibleMonth: Date = MonthlyTrainingBoardBuilder.startOfMonth(Date())
    @State private var selectedDate: Date? = Date()

    private let calendar = MonthlyTrainingBoardBuilder.makeCalendar()

    var body: some View {
        let monthData = MonthlyTrainingBoardBuilder.buildMonth(
            for: visibleMonth,
            calendar: calendar
        )

        let selectedDay = selectedDayItem(from: monthData)
        let selectedDetails = selectedDay.flatMap {
            MonthlyTrainingBoardBuilder.details(for: $0, calendar: calendar)
        }

        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.03, blue: 0.10),
                    Color(red: 0.05, green: 0.08, blue: 0.18),
                    Color(red: 0.08, green: 0.21, blue: 0.42),
                    Color(red: 0.10, green: 0.40, blue: 0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    headerCard(monthData: monthData)

                    MonthlyBoardCalendarGrid(
                        monthData: monthData,
                        selectedDate: selectedDate
                    ) { tappedDay in
                        selectedDate = tappedDay.date
                    }
                    
                    MonthlyBoardSelectedDayCard(
                        details: selectedDetails,
                        onAddSummaryTap: selectedDetails?.trainings.isEmpty == false ? {
                            guard let selectedDate else { return }
                            nav.push(.trainingSummary(pickedDateIso: isoDate(selectedDate)))
                        } : nil
                    )

                    legendCard
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("לוח אימונים חודשי")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: visibleMonth) { newMonth in
            if let firstDay = firstSelectableDay(in: newMonth) {
                if let selectedDate {
                    if !calendar.isDate(selectedDate, equalTo: newMonth, toGranularity: .month) {
                        self.selectedDate = firstDay
                    }
                } else {
                    self.selectedDate = firstDay
                }
            } else {
                self.selectedDate = nil
            }
        }
    }

    private func headerCard(monthData: MonthlyBoardMonthData) -> some View {
        HStack(spacing: 10) {
            Button {
                visibleMonth = MonthlyTrainingBoardBuilder.nextMonth(from: visibleMonth, calendar: calendar)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Circle())
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("לוח אימונים חודשי")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))

                Text(monthData.titleHeb)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                visibleMonth = MonthlyTrainingBoardBuilder.previousMonth(from: visibleMonth, calendar: calendar)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Circle())
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var legendCard: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Text("מקרא")
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)

            legendRow(color: .blue, text: "יום עם אימון")
            legendRow(color: .red, text: "יום עם חג")
            legendRow(color: .cyan, text: "יום שנבחר")
            legendRow(color: .white, text: "היום")
        }
        .padding(14)
        .background(Color.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func legendRow(color: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color.opacity(0.95))
                .frame(width: 10, height: 10)

            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))

            Spacer()
        }
    }

    private func selectedDayItem(from monthData: MonthlyBoardMonthData) -> MonthlyBoardDayItem? {
        guard let selectedDate else { return nil }
        return monthData.dayItems.first {
            guard let date = $0.date else { return false }
            return calendar.isDate(date, inSameDayAs: selectedDate)
        }
    }

    private func firstSelectableDay(in month: Date) -> Date? {
        let data = MonthlyTrainingBoardBuilder.buildMonth(for: month, calendar: calendar)
        return data.dayItems.first(where: { $0.date != nil })?.date
    }

    private func isoDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private func isoDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}
