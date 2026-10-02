import SwiftUI

struct MonthlyBoardSelectedDayCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection

    @ObservedObject private var demoPrivacy = DemoPrivacy.shared

    let details: MonthlyBoardSelectedDayDetails?
    let onAddSummaryTap: (() -> Void)?

    private var isEnglish: Bool {
        layoutDirection == .leftToRight
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let details {
                let holidays = holidayTitles(for: details)

                Text(dateTitle(details.date))
                    .kmiFont(size: 17, weight: .heavy)
                    .foregroundStyle(
                        KmiAppTheme.onSurface(for: colorScheme)
                    )
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if holidays.isEmpty && details.trainings.isEmpty {
                    Text(
                        tr(
                            "אין אימונים או חגים בתאריך זה.",
                            "No trainings or holidays on this date."
                        )
                    )
                    .kmiFont(size: 13, weight: .regular)
                    .foregroundStyle(
                        KmiAppTheme.onSurfaceVariant(for: colorScheme)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !holidays.isEmpty {
                    sectionTitle(tr("חגים ומועדים", "Holidays and occasions"))

                    ForEach(holidays, id: \.self) { title in
                        infoRow(title: title, subtitle: "")
                    }
                }

                if !details.trainings.isEmpty {
                    sectionTitle(tr("אימונים", "Trainings"))

                    ForEach(details.trainings) { training in
                        VStack(alignment: .leading, spacing: 6) {
                            infoRow(
                                title: TrainingCatalogIOS.displayGroup(
                                    training.title,
                                    isEnglish: isEnglish
                                ),
                                subtitle: trainingSubtitle(training)
                            )

                            // במקור הנתונים הנוכחי notes מכיל את שם המאמן.
                            if let name = training.notes?
                                .trimmingCharacters(in: .whitespacesAndNewlines),
                               !name.isEmpty {
                                Text(
                                    demoPrivacy.isEnabled
                                        ? tr("מאמן", "Coach")
                                        : tr(
                                            "מאמן: \(TrainingCatalogIOS.displayCoach(name, isEnglish: isEnglish))",
                                            "Coach: \(TrainingCatalogIOS.displayCoach(name, isEnglish: isEnglish))"
                                        )
                                )
                                .kmiFont(size: 12, weight: .semibold)
                                .foregroundStyle(
                                    KmiAppTheme.onSurfaceVariant(for: colorScheme)
                                )
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
                            }
                        }
                        .padding(.vertical, 4)

                        Rectangle()
                            .fill(
                                KmiAppTheme.outlineVariant(for: colorScheme)
                            )
                            .frame(height: 1)
                    }

                    if let onAddSummaryTap {
                        Button(action: onAddSummaryTap) {
                            HStack(spacing: 7) {
                                Image(systemName: "doc.badge.plus")
                                    .kmiIconSize(17)
                                    .accessibilityHidden(true)

                                Text(
                                    tr(
                                        "הוסף סיכום אימון",
                                        "Add training summary"
                                    )
                                )
                                .kmiFont(size: 15, weight: .bold)
                                .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(KmiAppTheme.primary(for: colorScheme))
                        .padding(.top, 4)
                    }
                }
            } else {
                Text(
                    tr(
                        "בחר תאריך בלוח כדי לראות פרטים.",
                        "Select a date in the calendar to view details."
                    )
                )
                .kmiFont(size: 13, weight: .semibold)
                .foregroundStyle(
                    KmiAppTheme.onSurfaceVariant(for: colorScheme)
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
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

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .kmiFont(size: 14, weight: .heavy)
            .foregroundStyle(
                KmiAppTheme.primary(for: colorScheme)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoRow(
        title: String,
        subtitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .kmiFont(size: 15, weight: .bold)
                .foregroundStyle(
                    KmiAppTheme.onSurface(for: colorScheme)
                )
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !subtitle.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty {
                Text(subtitle)
                    .kmiFont(size: 12, weight: .regular)
                    .foregroundStyle(
                        KmiAppTheme.onSurfaceVariant(for: colorScheme)
                    )
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 2)
    }

    private func dateTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = ShabbatHolidayCheckerIOS.calendar
        formatter.timeZone = ShabbatHolidayCheckerIOS.timeZone
        formatter.locale = Locale(
            identifier: isEnglish ? "en_US" : "he_IL"
        )
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        return formatter.string(from: date)
    }

    private func holidayTitles(
        for details: MonthlyBoardSelectedDayDetails
    ) -> [String] {
        var titles = HolidayCalendarStore.holidayNamesForDisplay(
            on: details.date,
            isEnglish: isEnglish
        )

        if titles.isEmpty {
            titles = details.holidays
                .filter { $0.title != "שבת" }
                .map(\.title)
        }

        if ShabbatHolidayCheckerIOS.calendar.component(
            .weekday,
            from: details.date
        ) == 7 {
            titles.append(tr("שבת", "Saturday"))
        }

        var seen = Set<String>()

        return titles
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter {
                !$0.isEmpty && seen.insert($0).inserted
            }
    }

    private func trainingSubtitle(
        _ training: MonthlyBoardTrainingItem
    ) -> String {
        [
            training.timeText,
            TrainingCatalogIOS.displayPlace(
                training.location,
                isEnglish: isEnglish
            )
        ]
        .map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
    }
}
