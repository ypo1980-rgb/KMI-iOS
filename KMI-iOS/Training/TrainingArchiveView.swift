import SwiftUI

private struct TrainingArchiveShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private enum TrainingArchiveFilter: CaseIterable {
    case all
    case completed
    case cancelled
}

private enum TrainingArchiveDateField: String, Identifiable {
    case from
    case to

    var id: String { rawValue }
}

struct TrainingArchiveView: View {
    @Environment(\.colorScheme)
    private var colorScheme

    let sources: [TrainingArchiveSource]
    let isEnglish: Bool

    // שכבת התצוגה מקבלת מיפוי פרטיות מהרכיב הגלובלי.
    let coachDisplayName: (String) -> String

    @State private var fromDate: Date
    @State private var toDate: Date
    @State private var filter: TrainingArchiveFilter = .all

    @State private var archiveItems: [TrainingArchiveItem] = []
    @State private var listener: TrainingOverrideListenerHandle?
    @State private var requestID = UUID()
    @State private var isLoading = true
    @State private var loadFailed = false

    @State private var shareItem: TrainingArchiveShareItem?
    @State private var shareErrorMessage: String?

    @State private var dateField: TrainingArchiveDateField?
    @State private var visibleCalendarMonth =
        MonthlyTrainingBoardBuilder.startOfMonth(Date())

    @State private var calendarItems: [TrainingArchiveItem] = []
    @State private var calendarListener: TrainingOverrideListenerHandle?
    @State private var calendarRequestID = UUID()
    @State private var isCalendarLoading = false
    @State private var calendarLoadFailed = false

    private var calendar: Calendar {
        ShabbatHolidayCheckerIOS.calendar
    }

    init(
        sources: [TrainingArchiveSource],
        isEnglish: Bool,
        coachDisplayName: @escaping (String) -> String
    ) {
        self.sources = sources
        self.isEnglish = isEnglish
        self.coachDisplayName = coachDisplayName

        let calendar = ShabbatHolidayCheckerIOS.calendar
        let today = calendar.startOfDay(for: Date())

        _fromDate = State(
            initialValue: calendar.date(
                byAdding: .day,
                value: -89,
                to: today
            ) ?? today
        )
        _toDate = State(initialValue: today)
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private var filteredItems: [TrainingArchiveItem] {
        switch filter {
        case .all:
            return archiveItems
        case .completed:
            return archiveItems.filter(\.isCompleted)
        case .cancelled:
            return archiveItems.filter(\.isCancelled)
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: KmiAppTheme.screenBackgroundColors(
                    for: colorScheme
                ),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Text(
                    tr(
                        "היסטוריית אימונים וטווח תאריכים",
                        "Training history and date range"
                    )
                )
                .kmiFont(size: 15, weight: .black)
                .foregroundStyle(KmiAppTheme.sectionHeaderContentColor)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 56)
                .padding(.horizontal, 16)
                .background(KmiAppTheme.sectionHeaderBrush)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        filterPanel

                        if isLoading {
                            KmiLoadingOverlay()
                                .frame(height: 180)
                        } else if loadFailed {
                            errorState
                        } else if filteredItems.isEmpty {
                            emptyState
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredItems) { item in
                                    archiveCard(item)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
        }
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
        .onAppear {
            startListening()
        }
        .onDisappear {
            stopListening()
            stopCalendarListening()
        }
        .onChange(of: fromDate) { _, newDate in
            if newDate > toDate {
                toDate = newDate
            }
            startListening()
        }
        .onChange(of: toDate) { _, newDate in
            if newDate < fromDate {
                fromDate = newDate
            }
            startListening()
        }
        .onChange(of: sources) { _, _ in
            startListening()

            if dateField != nil {
                startCalendarListening()
            }
        }
        .sheet(
            item: $dateField,
            onDismiss: {
                stopCalendarListening()
            }
        ) { field in
            archiveCalendarPanel(for: field)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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
                .onAppear {
                    startCalendarListening()
                }
                .onChange(of: visibleCalendarMonth) { _, _ in
                    startCalendarListening()
                }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name(
                    "KMI_GLOBAL_SHARE_REQUEST"
                )
            )
        ) { notification in
            guard let request =
                notification.object as? NSMutableDictionary else {
                return
            }

            guard request["handled"] as? Bool != true else {
                return
            }

            request["handled"] = true
            shareArchivePDF()
        }
        .sheet(item: $shareItem) { item in
            KmiShareSheet(items: [item.url])
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert(
            tr("לא ניתן לשתף", "Unable to Share"),
            isPresented: Binding(
                get: {
                    shareErrorMessage != nil
                },
                set: { presented in
                    if !presented {
                        shareErrorMessage = nil
                    }
                }
            )
        ) {
            Button(tr("אישור", "OK"), role: .cancel) {
                shareErrorMessage = nil
            }
        } message: {
            Text(shareErrorMessage ?? "")
        }
    }

    @MainActor
    private func shareArchivePDF() {
        guard !isLoading else {
            shareErrorMessage = tr(
                "הארכיון עדיין נטען. נסה שוב בסיום הטעינה.",
                "The archive is still loading. Try again when loading finishes."
            )
            return
        }

        guard !loadFailed else {
            shareErrorMessage = tr(
                "יש לטעון את הארכיון בהצלחה לפני יצירת PDF.",
                "Load the archive successfully before creating a PDF."
            )
            return
        }

        do {
            let url = try TrainingArchivePdfExporter.export(
                items: filteredItems,
                fromDate: fromDate,
                toDate: toDate,
                isEnglish: isEnglish
            )

            shareItem = TrainingArchiveShareItem(url: url)
        } catch TrainingArchivePdfExportError.contentTooTall {
            shareErrorMessage = tr(
                "אחד האימונים מכיל טקסט ארוך מדי לעמוד PDF.",
                "One training contains more text than a PDF page can fit."
            )
        } catch {
            shareErrorMessage = tr(
                "לא ניתן ליצור את קובץ ה־PDF. נסה שוב.",
                "Unable to create the PDF file. Please try again."
            )
        }
    }

    private var filterPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                archiveDateButton(
                    .from,
                    title: tr("מתאריך", "From date"),
                    date: fromDate
                )

                archiveDateButton(
                    .to,
                    title: tr("עד תאריך", "To date"),
                    date: toDate
                )
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    quickRangeButton(
                        days: 30,
                        title: tr("30 ימים", "30 days")
                    )
                    quickRangeButton(
                        days: 90,
                        title: tr("3 חודשים", "3 months")
                    )
                    quickRangeButton(
                        days: 180,
                        title: tr("6 חודשים", "6 months")
                    )
                    quickRangeButton(
                        days: 365,
                        title: tr("שנה", "1 year")
                    )
                    quickRangeButton(
                        days: 90,
                        title: tr("איפוס", "Reset")
                    )
                }
            }

            Rectangle()
                .fill(KmiAppTheme.outlineVariant(for: colorScheme))
                .frame(height: 1)

            HStack(spacing: 7) {
                summaryButton(
                    .all,
                    count: archiveItems.count,
                    title: tr("הכול", "All")
                )
                summaryButton(
                    .completed,
                    count: archiveItems.filter(\.isCompleted).count,
                    title: tr("הסתיימו", "Completed")
                )
                summaryButton(
                    .cancelled,
                    count: archiveItems.filter(\.isCancelled).count,
                    title: tr("בוטלו", "Cancelled")
                )
            }
            .disabled(isLoading || loadFailed)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(KmiAppTheme.surface(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    KmiAppTheme.outlineVariant(for: colorScheme),
                    lineWidth: 1
                )
        )
    }

    private func archiveDateButton(
        _ field: TrainingArchiveDateField,
        title: String,
        date: Date
    ) -> some View {
        Button {
            visibleCalendarMonth =
                MonthlyTrainingBoardBuilder.startOfMonth(
                    date,
                    calendar: calendar
                )

            dateField = field
        } label: {
            HStack(spacing: 6) {
                VStack(spacing: 2) {
                    Text(title)
                        .kmiFont(size: 11, weight: .bold)

                    Text(calendarDateText(date, format: "dd/MM/yyyy"))
                        .kmiFont(size: 13, weight: .black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity)

                Image(systemName: "calendar")
                    .kmiIconSize(17)
                    .foregroundStyle(
                        KmiAppTheme.primary(for: colorScheme)
                    )
                    .accessibilityHidden(true)
            }
            .foregroundStyle(
                KmiAppTheme.onSurface(for: colorScheme)
            )
            .padding(.horizontal, 8)
            .frame(minHeight: 58)
            .background(
                RoundedRectangle(cornerRadius: 17)
                    .fill(
                        KmiAppTheme.surfaceVariant(for: colorScheme)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 17)
                    .stroke(
                        KmiAppTheme.outlineVariant(for: colorScheme),
                        lineWidth: 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 17))
        }
        .buttonStyle(.plain)
    }

    private func calendarDateText(
        _ date: Date,
        format: String
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(
            identifier: isEnglish ? "en_US" : "he_IL"
        )
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    private var archiveCalendarMonthData: MonthlyBoardMonthData {
        let trainings = calendarItems
            .filter(\.isCompleted)
            .map { item in
                MonthlyBoardTrainingItem(
                    id: item.id,
                    date: item.originalStartDate,
                    title: tr("אימון", "Training"),
                    timeText: "",
                    location: "",
                    notes: nil
                )
            }

        let cancelledDates = Set(
            calendarItems
                .filter(\.isCancelled)
                .map(\.originalStartDate)
        )

        let month = MonthlyTrainingBoardBuilder.buildMonth(
            for: visibleCalendarMonth,
            calendar: calendar,
            archiveTrainings: trainings,
            cancelledDates: cancelledDates
        )

        return MonthlyBoardMonthData(
            monthDate: month.monthDate,
            titleHeb: calendarDateText(
                visibleCalendarMonth,
                format: "LLLL yyyy"
            ),
            weekdaySymbolsHeb: isEnglish
                ? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                : month.weekdaySymbolsHeb,
            dayItems: month.dayItems
        )
    }

    private func archiveCalendarPanel(
        for field: TrainingArchiveDateField
    ) -> some View {
        let monthData = archiveCalendarMonthData

        return ZStack {
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
                    HStack {
                        Text(
                            field == .from
                                ? tr("בחירת תאריך התחלה", "Choose start date")
                                : tr("בחירת תאריך סיום", "Choose end date")
                        )
                        .kmiFont(size: 17, weight: .black)

                        Spacer()

                        Button {
                            dateField = nil
                        } label: {
                            Image(systemName: "xmark")
                                .kmiIconSize(16)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tr("סגור", "Close"))
                    }

                    HStack(spacing: 8) {
                        Button {
                            visibleCalendarMonth =
                                MonthlyTrainingBoardBuilder.previousMonth(
                                    from: visibleCalendarMonth,
                                    calendar: calendar
                                )
                        } label: {
                            Image(
                                systemName: isEnglish
                                    ? "chevron.left"
                                    : "chevron.right"
                            )
                            .kmiIconSize(17)
                            .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(
                            tr("החודש הקודם", "Previous month")
                        )

                        Text(monthData.titleHeb)
                            .kmiFont(size: 17, weight: .black)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)

                        Button {
                            visibleCalendarMonth =
                                MonthlyTrainingBoardBuilder.nextMonth(
                                    from: visibleCalendarMonth,
                                    calendar: calendar
                                )
                        } label: {
                            Image(
                                systemName: isEnglish
                                    ? "chevron.right"
                                    : "chevron.left"
                            )
                            .kmiIconSize(17)
                            .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(
                            tr("החודש הבא", "Next month")
                        )
                    }
                    .buttonStyle(.plain)

                    if isCalendarLoading {
                        KmiLoadingOverlay()
                            .frame(height: 180)
                    } else if calendarLoadFailed {
                        VStack(spacing: 12) {
                            Text(
                                tr(
                                    "לא ניתן לטעון את נתוני החודש.",
                                    "Unable to load this month's data."
                                )
                            )
                            .kmiFont(size: 14, weight: .bold)

                            Button {
                                startCalendarListening()
                            } label: {
                                Text(tr("נסה שוב", "Try again"))
                                    .kmiFont(size: 14, weight: .bold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        MonthlyBoardCalendarGrid(
                            monthData: monthData,
                            selectedDate: field == .from
                                ? fromDate
                                : toDate
                        ) { day in
                            guard let selectedDate = day.date else {
                                return
                            }

                            let selectedDay =
                                calendar.startOfDay(for: selectedDate)

                            if field == .from {
                                fromDate = selectedDay

                                if selectedDay > toDate {
                                    toDate = selectedDay
                                }
                            } else {
                                toDate = selectedDay

                                if selectedDay < fromDate {
                                    fromDate = selectedDay
                                }
                            }

                            dateField = nil
                        }
                    }
                }
                .foregroundStyle(
                    KmiAppTheme.onSurface(for: colorScheme)
                )
                .padding(.horizontal, 12)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
        }
    }

    private func stopCalendarListening() {
        calendarRequestID = UUID()
        calendarListener?.remove()
        calendarListener = nil
    }

    private func startCalendarListening() {
        stopCalendarListening()

        let currentRequestID = calendarRequestID

        guard let monthInterval = calendar.dateInterval(
            of: .month,
            for: visibleCalendarMonth
        ),
        let lastDay = calendar.date(
            byAdding: .day,
            value: -1,
            to: monthInterval.end
        ) else {
            isCalendarLoading = false
            calendarLoadFailed = true
            return
        }

        isCalendarLoading = true
        calendarLoadFailed = false
        calendarItems = []

        let capturedSources = sources

        calendarListener =
            TrainingOverrideRepository.listenForOverridesInRange(
                fromOriginalStartMillis:
                    Int64(monthInterval.start.timeIntervalSince1970 * 1000),
                toOriginalStartMillis:
                    Int64(monthInterval.end.timeIntervalSince1970 * 1000) - 1,
                onChanged: { overrides in
                    guard calendarRequestID == currentRequestID else {
                        return
                    }

                    calendarItems = TrainingArchiveEngine.buildItems(
                        sources: capturedSources,
                        fromDate: monthInterval.start,
                        toDate: lastDay,
                        overrides: overrides
                    )

                    calendarLoadFailed = false
                    isCalendarLoading = false
                },
                onError: { _ in
                    guard calendarRequestID == currentRequestID else {
                        return
                    }

                    calendarLoadFailed = true
                    isCalendarLoading = false
                }
            )
    }

    private func quickRangeButton(
        days: Int,
        title: String
    ) -> some View {
        Button {
            let today = calendar.startOfDay(for: Date())
            fromDate = calendar.date(
                byAdding: .day,
                value: -(days - 1),
                to: today
            ) ?? today
            toDate = today
            filter = .all
        } label: {
            Text(title)
                .kmiFont(size: 11, weight: .bold)
                .foregroundStyle(
                    KmiAppTheme.onPrimaryContainer(for: colorScheme)
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            KmiAppTheme.primaryContainer(for: colorScheme)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func summaryButton(
        _ value: TrainingArchiveFilter,
        count: Int,
        title: String
    ) -> some View {
        let selected = filter == value
        let accent = value == .cancelled
            ? KmiAppTheme.onErrorContainer(for: colorScheme)
            : KmiAppTheme.primary(for: colorScheme)

        return Button {
            filter = selected ? .all : value
        } label: {
            VStack(spacing: 2) {
                Text("\(count)")
                    .kmiFont(size: 17, weight: .black)

                Text(title)
                    .kmiFont(size: 10, weight: .bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
            }
            .foregroundStyle(
                selected
                    ? accent
                    : KmiAppTheme.onSurfaceVariant(for: colorScheme)
            )
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(KmiAppTheme.surface(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(
                        selected
                            ? accent
                            : KmiAppTheme.outlineVariant(for: colorScheme),
                        lineWidth: selected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func archiveCard(
        _ item: TrainingArchiveItem
    ) -> some View {
        let accent = item.isCancelled
            ? KmiAppTheme.onErrorContainer(for: colorScheme)
            : KmiAppTheme.primary(for: colorScheme)

        let statusBackground = item.isCancelled
            ? KmiAppTheme.errorContainer(for: colorScheme)
            : KmiAppTheme.primaryContainer(for: colorScheme)

        let displayedCoach = coachDisplayName(item.training.coach)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Image(
                    systemName: item.isCancelled
                        ? "calendar"
                        : "clock.arrow.circlepath"
                )
                .kmiIconSize(14)
                .foregroundStyle(accent)
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(accent.opacity(0.10))
                )
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        TrainingCatalogIOS.displayPlace(
                            item.training.place,
                            isEnglish: isEnglish
                        )
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty
                            ? tr("אימון", "Training")
                            : TrainingCatalogIOS.displayPlace(
                                item.training.place,
                                isEnglish: isEnglish
                            )
                    )
                    .kmiFont(size: 15, weight: .black)

                    Text(dateTimeText(item))
                        .kmiFont(size: 12, weight: .bold)
                        .foregroundStyle(
                            KmiAppTheme.onSurfaceVariant(for: colorScheme)
                        )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !item.training.address.isEmpty {
                Text(
                    TrainingCatalogIOS.displayAddress(
                        item.training.address,
                        isEnglish: isEnglish
                    )
                )
                .kmiFont(size: 12, weight: .semibold)
                .fixedSize(horizontal: false, vertical: true)
            }

            if !displayedCoach.isEmpty {
                Text(
                    tr(
                        "מאמן: \(displayedCoach)",
                        "Coach: \(displayedCoach)"
                    )
                )
                .kmiFont(size: 12, weight: .semibold)
            }

            Rectangle()
                .fill(accent.opacity(0.12))
                .frame(height: 1)
                .padding(.top, 2)

            Text(item.status.title(isEnglish: isEnglish))
                .kmiFont(size: 11, weight: .black)
                .foregroundStyle(
                    item.isCancelled
                        ? KmiAppTheme.onErrorContainer(for: colorScheme)
                        : KmiAppTheme.onPrimaryContainer(for: colorScheme)
                )
                .multilineTextAlignment(.center)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(Capsule().fill(statusBackground))
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(KmiAppTheme.surface(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(accent.opacity(0.24), lineWidth: 1)
        )
    }

    private func dateTimeText(
        _ item: TrainingArchiveItem
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = calendar
        dateFormatter.timeZone = calendar.timeZone
        dateFormatter.locale = Locale(
            identifier: isEnglish ? "en_US_POSIX" : "he_IL"
        )
        dateFormatter.dateFormat = "EEEE, dd/MM/yyyy"

        let timeFormatter = DateFormatter()
        timeFormatter.calendar = calendar
        timeFormatter.timeZone = calendar.timeZone
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "HH:mm"

        return "\(dateFormatter.string(from: item.effectiveStartDate)) · "
            + "\(timeFormatter.string(from: item.effectiveStartDate)) – "
            + timeFormatter.string(from: item.effectiveEndDate)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .kmiIconSize(32)
                .foregroundStyle(KmiAppTheme.primary(for: colorScheme))

            Text(tr("אין אימונים בטווח שנבחר", "No trainings in this range"))
                .kmiFont(size: 18, weight: .bold)

            Text(
                tr(
                    "אפשר לבחור טווח תאריכים אחר או להשתמש בסינונים המהירים.",
                    "Choose another date range or use a quick filter."
                )
            )
            .kmiFont(size: 13, weight: .semibold)
            .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(KmiAppTheme.surface(for: colorScheme))
        )
    }

    private var errorState: some View {
        VStack(spacing: 12) {
            Text(
                tr(
                    "לא ניתן לטעון את שינויי האימונים. בדוק את החיבור ונסה שוב.",
                    "Unable to load training changes. Check your connection and try again."
                )
            )
            .kmiFont(size: 14, weight: .bold)
            .multilineTextAlignment(.center)

            Button {
                startListening()
            } label: {
                Text(tr("נסה שוב", "Try again"))
                    .kmiFont(size: 14, weight: .bold)
            }
        }
        .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    private func stopListening() {
        requestID = UUID()
        listener?.remove()
        listener = nil
    }

    private func startListening() {
        stopListening()

        let currentRequestID = requestID
        let start = calendar.startOfDay(for: fromDate)
        let lastDay = calendar.startOfDay(for: toDate)

        guard start <= lastDay,
              let endExclusive = calendar.date(
                  byAdding: .day,
                  value: 1,
                  to: lastDay
              ) else {
            isLoading = false
            loadFailed = true
            return
        }

        isLoading = true
        loadFailed = false

        // לא מציגים ספירות מהטווח הקודם בזמן טעינה.
        archiveItems = []

        let capturedSources = sources

        listener = TrainingOverrideRepository.listenForOverridesInRange(
            fromOriginalStartMillis:
                Int64(start.timeIntervalSince1970 * 1000),
            toOriginalStartMillis:
                Int64(endExclusive.timeIntervalSince1970 * 1000) - 1,
            onChanged: { overrides in
                guard requestID == currentRequestID else {
                    return
                }

                archiveItems = TrainingArchiveEngine.buildItems(
                    sources: capturedSources,
                    fromDate: start,
                    toDate: lastDay,
                    overrides: overrides
                )
                loadFailed = false
                isLoading = false
            },
            onError: { _ in
                guard requestID == currentRequestID else {
                    return
                }

                loadFailed = true
                isLoading = false
            }
        )
    }
}
