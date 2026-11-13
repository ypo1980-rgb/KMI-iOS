import SwiftUI

struct MonthlyBoardSelectedDayCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection

    @ObservedObject private var demoPrivacy = DemoPrivacy.shared

    let details: MonthlyBoardSelectedDayDetails?
    let onAddSummaryTap: (() -> Void)?
    var hasSummary = false
    var onOpenSummaryPdf: (() -> Void)? = nil

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
                let trainings = details.trainings.sorted {
                    $0.timeText.localizedStandardCompare($1.timeText) == .orderedAscending
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(
                            tr(
                                "יום נבחר: \(dateTitle(details.date, format: "EEEE d"))",
                                "Selected day: \(dateTitle(details.date, format: "EEEE d"))"
                            )
                        )
                        .kmiFont(size: 17, weight: .heavy)
                        .accessibilityAddTraits(.isHeader)

                        Text(dateTitle(details.date, format: "LLLL yyyy"))
                            .kmiFont(size: 15, weight: .bold)
                    }
                    .foregroundStyle(KmiAppTheme.onPrimaryContainer(for: colorScheme))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "calendar")
                        .kmiIconSize(21)
                        .foregroundStyle(KmiAppTheme.onPrimaryContainer(for: colorScheme))
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(KmiAppTheme.primary(for: colorScheme).opacity(0.14))
                        )
                        .accessibilityHidden(true)
                }

                if holidays.isEmpty && trainings.isEmpty {
                    Text(
                        tr(
                            "אין אירועים ביום זה.",
                            "No events on this day."
                        )
                    )
                    .kmiFont(size: 13, weight: .regular)
                    .foregroundStyle(
                        KmiAppTheme.onSurfaceVariant(for: colorScheme)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !trainings.isEmpty {
                    sectionTitle(tr("פירוט אימונים", "Training details"))

                    ForEach(trainings) { training in
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

                        if training.id != trainings.last?.id {
                            Rectangle()
                                .fill(
                                    KmiAppTheme.outlineVariant(for: colorScheme)
                                )
                                .frame(height: 1)
                        }
                    }
                }

                if !holidays.isEmpty {
                    sectionTitle(tr("חגים ומועדים", "Holidays and occasions"))

                    ForEach(holidays, id: \.self) { title in
                        infoRow(title: title, subtitle: "")
                    }
                }

                if hasSummary || !trainings.isEmpty {
                    if let onAddSummaryTap {
                        Button(action: onAddSummaryTap) {
                            HStack(spacing: 7) {
                                Image(systemName: hasSummary ? "square.and.pencil" : "doc.badge.plus")
                                    .kmiIconSize(17)
                                    .accessibilityHidden(true)

                                Text(
                                    hasSummary
                                    ? tr("ערוך סיכום", "Edit summary")
                                    : tr("הוסף סיכום אימון", "Add training summary")
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

                if hasSummary, let onOpenSummaryPdf {
                    Button(action: onOpenSummaryPdf) {
                        HStack(spacing: 7) {
                            Image(systemName: "doc.text")
                                .kmiIconSize(17)
                                .accessibilityHidden(true)

                            Text(tr("הצג סיכום", "View summary"))
                                .kmiFont(size: 15, weight: .bold)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(KmiAppTheme.primary(for: colorScheme))
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
            RoundedRectangle(cornerRadius: 26)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: KmiAppTheme.primaryContainer(for: colorScheme), location: 0),
                            .init(color: KmiAppTheme.surface(for: colorScheme), location: 0.55),
                            .init(color: KmiAppTheme.surface(for: colorScheme), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(
                    KmiAppTheme.primary(for: colorScheme).opacity(0.30),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        )
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .kmiFont(size: 14, weight: .heavy)
            .accessibilityAddTraits(.isHeader)
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

    private func dateTitle(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isEnglish ? "en_US" : "he_IL")
        formatter.calendar = ShabbatHolidayCheckerIOS.calendar
        formatter.timeZone = ShabbatHolidayCheckerIOS.timeZone
        formatter.dateFormat = format
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
