import SwiftUI

struct MonthlyTrainingBoardView: View {
    @EnvironmentObject private var nav: AppNavModel
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("kmi_app_language")
    private var languageCode: String = "he"

    private var isEnglish: Bool {
        let clean = languageCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return clean == "en" || clean == "english"
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    @State private var visibleMonth: Date = MonthlyTrainingBoardBuilder.startOfMonth(Date())
    @State private var selectedDate: Date? = Date()

    private let calendar = MonthlyTrainingBoardBuilder.makeCalendar()

    var body: some View {
        let builtMonth = MonthlyTrainingBoardBuilder.buildMonth(
            for: visibleMonth,
            calendar: calendar
        )

        let monthData = MonthlyBoardMonthData(
            monthDate: builtMonth.monthDate,
            titleHeb: localizedMonthTitle,
            weekdaySymbolsHeb: isEnglish
                ? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                : builtMonth.weekdaySymbolsHeb,
            dayItems: builtMonth.dayItems
        )

        let selectedDay = selectedDayItem(from: monthData)
        let selectedDetails = selectedDay.flatMap {
            MonthlyTrainingBoardBuilder.details(for: $0, calendar: calendar)
        }

        ZStack {
            LinearGradient(
                colors: KmiAppTheme.screenBackgroundColors(
                    for: colorScheme
                ),
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
        .toolbar(.hidden, for: .navigationBar)
        .environment(
            \.layoutDirection,
            isEnglish ? .leftToRight : .rightToLeft
        )
        .environment(
            \.locale,
            Locale(identifier: isEnglish ? "en_US" : "he_IL")
        )
        .environment(\.calendar, calendar)
        .environment(\.timeZone, calendar.timeZone)
        .onChange(of: visibleMonth) { _, newMonth in
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

    private var localizedMonthTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(
            identifier: isEnglish ? "en_US" : "he_IL"
        )
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: visibleMonth)
    }

    private func headerCard(
        monthData: MonthlyBoardMonthData
    ) -> some View {
        HStack(spacing: 8) {
            Button {
                visibleMonth =
                    MonthlyTrainingBoardBuilder.previousMonth(
                        from: visibleMonth,
                        calendar: calendar
                    )
            } label: {
                Image(
                    systemName: isEnglish
                        ? "chevron.left"
                        : "chevron.right"
                )
                .kmiIconSize(16)
                .fontWeight(.heavy)
                .frame(width: 44, height: 44)
                .background(
                    Circle().fill(
                        KmiAppTheme.primaryContainer(for: colorScheme)
                    )
                )
            }
            .accessibilityLabel(
                tr("החודש הקודם", "Previous month")
            )

            Text(monthData.titleHeb)
                .kmiFont(size: 18, weight: .heavy)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)

            Button {
                visibleMonth =
                    MonthlyTrainingBoardBuilder.nextMonth(
                        from: visibleMonth,
                        calendar: calendar
                    )
            } label: {
                Image(
                    systemName: isEnglish
                        ? "chevron.right"
                        : "chevron.left"
                )
                .kmiIconSize(16)
                .fontWeight(.heavy)
                .frame(width: 44, height: 44)
                .background(
                    Circle().fill(
                        KmiAppTheme.primaryContainer(for: colorScheme)
                    )
                )
            }
            .accessibilityLabel(
                tr("החודש הבא", "Next month")
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(
            KmiAppTheme.onSurface(for: colorScheme)
        )
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(KmiAppTheme.surface(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    KmiAppTheme.outlineVariant(for: colorScheme),
                    lineWidth: 1
                )
        )
    }

    private var legendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("מקרא", "Legend"))
                .kmiFont(size: 16, weight: .heavy)

            legendRow(
                color: KmiAppTheme.primary(for: colorScheme),
                text: tr("יום עם אימון", "Day with training")
            )

            legendRow(
                color: KmiAppTheme.onErrorContainer(for: colorScheme),
                text: tr("יום עם חג", "Day with a holiday")
            )

            legendRow(
                color: KmiAppTheme.primary(for: colorScheme),
                text: tr(
                    "יום שנבחר — מסגרת עבה",
                    "Selected day — thick border"
                )
            )

            legendRow(
                color: KmiAppTheme.secondary(for: colorScheme),
                text: tr("היום — מסגרת", "Today — border")
            )
        }
        .foregroundStyle(
            KmiAppTheme.onSurface(for: colorScheme)
        )
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(KmiAppTheme.surface(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    KmiAppTheme.outlineVariant(for: colorScheme),
                    lineWidth: 1
                )
        )
    }

    private func legendRow(
        color: Color,
        text: String
    ) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)

            Text(text)
                .kmiFont(size: 13, weight: .semibold)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
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
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

