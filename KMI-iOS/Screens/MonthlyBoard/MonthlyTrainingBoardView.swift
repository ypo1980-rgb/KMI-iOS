import SwiftUI
import QuickLook
import FirebaseFirestore

struct MonthlyTrainingBoardView: View {

    var summaryOwnerUid: String = ""
    var summaryOwnerRole: SummaryAuthorRole = .trainee

    @EnvironmentObject private var nav: AppNavModel

    @State private var summaryPdfURL: URL?
    @State private var showSummaryPdfError = false
    @State private var savedSummaryKey: SummaryLookupKey?
    @State private var loadedSummaryMonthKey: SummaryMonthKey?
    @State private var markedSummaryDays: Set<Date> = []
    @State private var firestoreSummaryMonthKey: SummaryMonthKey?
    @State private var firestoreSummaryDays: Set<Date> = []

    private struct SummaryLookupKey: Equatable {
        let ownerUid: String
        let ownerRole: SummaryAuthorRole
        let dateIso: String
    }

    private struct SummaryMonthKey: Equatable {
        let ownerUid: String
        let ownerRole: SummaryAuthorRole
        let monthStart: Date
    }
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

    private var canGoToNextMonth: Bool {
        calendar.compare(
            visibleMonth,
            to: Date(),
            toGranularity: .month
        ) == .orderedAscending
    }

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

        let dateIso = selectedDetails.map { isoDate($0.date) }
        let summaryKey = dateIso.map {
            SummaryLookupKey(
                ownerUid: summaryOwnerUid,
                ownerRole: summaryOwnerRole,
                dateIso: $0
            )
        }
        let hasSummary = summaryKey != nil && savedSummaryKey == summaryKey
        let monthKey = calendar.dateInterval(of: .month, for: monthData.monthDate).map {
            SummaryMonthKey(
                ownerUid: summaryOwnerUid.trimmingCharacters(in: .whitespacesAndNewlines),
                ownerRole: summaryOwnerRole,
                monthStart: $0.start
            )
        }
        let localSummaryDays: Set<Date> =
            monthKey != nil && loadedSummaryMonthKey == monthKey
                ? markedSummaryDays
                : []

        let remoteSummaryDays: Set<Date> =
            monthKey != nil && firestoreSummaryMonthKey == monthKey
                ? firestoreSummaryDays
                : []

        let visibleSummaryDays = localSummaryDays.union(remoteSummaryDays)
        let hasRemoteSummary = selectedDetails.map {
            remoteSummaryDays.contains(calendar.startOfDay(for: $0.date))
        } ?? false

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
                        selectedDate: selectedDate,
                        summaryDays: visibleSummaryDays
                    ) { tappedDay in
                        selectedDate = tappedDay.date
                    }

                    legendCard

                    MonthlyBoardSelectedDayCard(
                        details: selectedDetails,
                        onAddSummaryTap: (
                            hasSummary ||
                            hasRemoteSummary ||
                            selectedDetails?.trainings.isEmpty == false
                        ) ? {
                            guard let dateIso else { return }
                            nav.push(.trainingSummary(pickedDateIso: dateIso))
                        } : nil,
                        hasSummary: hasSummary || hasRemoteSummary,
                        onOpenSummaryPdf: hasSummary || hasRemoteSummary ? {
                            guard let summaryKey else { return }

                            Task {
                                await openSummaryPdf(for: summaryKey)
                            }
                        } : nil
                    )
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
        .onAppear {
            refreshSavedSummary(for: summaryKey)
            refreshSummaryDays(for: monthKey, in: monthData)
        }
        .onChange(of: summaryKey) { _, newKey in
            refreshSavedSummary(for: newKey)
        }
        .onChange(of: monthKey) { _, newKey in
            refreshSummaryDays(for: newKey, in: monthData)
        }
        .task(id: monthKey) {
            await refreshFirestoreSummaryDays(for: monthKey, in: monthData)
        }
        .quickLookPreview($summaryPdfURL)
        .alert(
            tr("לא ניתן לפתוח את הסיכום", "Could not open the summary"),
            isPresented: $showSummaryPdfError
        ) {
            Button(tr("אישור", "OK"), role: .cancel) {}
        } message: {
            Text(tr(
                "יש לוודא שהסיכום עדיין שמור ולנסות שוב.",
                "Check that the summary is still saved and try again."
            ))
        }
        .onChange(of: visibleMonth) { _, newMonth in
            if let selectedDate,
               calendar.isDate(selectedDate, equalTo: newMonth, toGranularity: .month) {
                return
            }

            selectedDate = calendar.dateInterval(of: .month, for: newMonth)?.start
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
                .kmiIconSize(12)
                .fontWeight(.heavy)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
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
                guard canGoToNextMonth else { return }

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
                .kmiIconSize(12)
                .fontWeight(.heavy)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel(
                tr("החודש הבא", "Next month")
            )
            .disabled(!canGoToNextMonth)
            .opacity(canGoToNextMonth ? 1 : 0.4)

        }
        .buttonStyle(.plain)
        .foregroundStyle(KmiAppTheme.sectionHeaderContentColor)
        .padding(.horizontal, 12)
        .frame(minHeight: 56)
        .background(KmiAppTheme.sectionHeaderBrush)
    }

    private var legendCard: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
            alignment: .leading,
            spacing: 6
        ) {
            legendRow(
                color: KmiAppTheme.primary(for: colorScheme),
                text: tr("אימון", "Training")
            )

            legendRow(
                color: KmiAppTheme.onErrorContainer(for: colorScheme),
                text: tr("חג / מועד", "Holiday")
            )

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5)
                    .strokeBorder(
                        KmiAppTheme.onErrorContainer(for: colorScheme),
                        lineWidth: 1
                    )
                    .frame(width: 7, height: 7)
                    .frame(width: 10)
                    .accessibilityHidden(true)

                Text(tr("אימון מבוטל", "Cancelled training"))
                    .kmiFont(size: 13, weight: .semibold)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Image(systemName: "doc.fill")
                    .kmiIconSize(8)
                    .foregroundStyle(KmiAppTheme.primary(for: colorScheme))
                    .frame(width: 10)
                    .accessibilityHidden(true)

                Text(tr("סיכום אימון", "Training summary"))
                    .kmiFont(size: 13, weight: .semibold)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
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

    @MainActor
    private func refreshFirestoreSummaryDays(
        for key: SummaryMonthKey?,
        in monthData: MonthlyBoardMonthData
    ) async {
        guard !Task.isCancelled else { return }

        guard let key,
              !key.ownerUid.isEmpty,
              let nextMonth = calendar.date(
                  byAdding: .month,
                  value: 1,
                  to: key.monthStart
              ) else {
            firestoreSummaryMonthKey = nil
            firestoreSummaryDays = []
            return
        }

        if firestoreSummaryMonthKey != key {
            firestoreSummaryMonthKey = nil
            firestoreSummaryDays = []
        }

        do {
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .document(key.ownerUid)
                .collection("training_summaries_\(key.ownerRole.rawValue)")
                .whereField("dateIso", isGreaterThanOrEqualTo: isoDate(key.monthStart))
                .whereField("dateIso", isLessThan: isoDate(nextMonth))
                .getDocuments()

            guard !Task.isCancelled else { return }

            let dateKeys = Set(snapshot.documents.compactMap { document -> String? in
                guard let value = document.data()["dateIso"] as? String else {
                    return nil
                }

                let dateIso = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return dateIso.isEmpty ? nil : String(dateIso.prefix(10))
            })

            firestoreSummaryDays = Set(
                monthData.dayItems.compactMap { item -> Date? in
                    guard let date = item.date, dateKeys.contains(isoDate(date)) else {
                        return nil
                    }

                    return calendar.startOfDay(for: date)
                }
            )
            firestoreSummaryMonthKey = key
        } catch {
            guard !Task.isCancelled else { return }
            #if DEBUG
            let failure = error as NSError
            print("KMI_SUMMARY_DATES_READ_FAILED \(failure.domain) code=\(failure.code)")
            #endif
        }
    }

    private func refreshSummaryDays(
        for key: SummaryMonthKey?,
        in monthData: MonthlyBoardMonthData
    ) {
        guard let key,
              !key.ownerUid.isEmpty,
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: key.monthStart)
        else {
            markedSummaryDays = []
            loadedSummaryMonthKey = nil
            return
        }

        let savedDates = TrainingSummaryLocalStore.shared.listDatesForOwnerBetween(
            ownerUid: key.ownerUid,
            role: key.ownerRole,
            startIso: isoDate(key.monthStart),
            endIsoExclusive: isoDate(nextMonth)
        )

        markedSummaryDays = Set(
            monthData.dayItems.compactMap { item -> Date? in
                guard let date = item.date, savedDates.contains(isoDate(date)) else {
                    return nil
                }

                return calendar.startOfDay(for: date)
            }
        )
        loadedSummaryMonthKey = key
    }

    private func refreshSavedSummary(for key: SummaryLookupKey?) {
        guard let key, savedSummary(for: key.dateIso) != nil else {
            savedSummaryKey = nil
            return
        }

        savedSummaryKey = key
    }

    private func savedSummary(for dateIso: String) -> TrainingSummaryEntity? {
        let uid = summaryOwnerUid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty else { return nil }

        return TrainingSummaryLocalStore.shared.loadForOwner(
            ownerUid: uid,
            role: summaryOwnerRole,
            summaryId: dateIso
        )
    }

    @MainActor
    private func openSummaryPdf(for key: SummaryLookupKey) async {
        let uid = key.ownerUid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty else { return }

        do {
            let viewModel = TrainingSummaryViewModel(
                ownerUid: uid,
                ownerRole: key.ownerRole,
                pickedDateIso: key.dateIso
            )
            var state = viewModel.state

            if savedSummary(for: key.dateIso) == nil {
                guard let remote = try await loadRemoteSummary(
                    ownerUid: uid,
                    role: key.ownerRole,
                    dateIso: key.dateIso
                ) else {
                    showSummaryPdfError = true
                    return
                }

                state.branchId = remote["branchId"] as? String ?? ""
                state.branchName = remote["branchName"] as? String ?? ""
                state.coachUid = remote["coachUid"] as? String ?? ""
                state.coachName = remote["coachName"] as? String ?? ""
                state.groupKey = remote["groupKey"] as? String ?? ""
                state.notes = remote["notes"] as? String ?? ""

                let exercises = remote["exercises"] as? [[String: Any]] ?? []
                for exercise in exercises {
                    guard let id = exercise["exerciseId"] as? String,
                          !id.isEmpty else { continue }

                    var item = SelectedExerciseUi(
                        exerciseId: id,
                        name: exercise["name"] as? String ?? "",
                        topic: exercise["topic"] as? String ?? "",
                        difficulty: (exercise["difficulty"] as? NSNumber)?.intValue,
                        highlight: exercise["highlight"] as? String ?? "",
                        homePractice: exercise["homePractice"] as? Bool ?? false
                    )
                    item.includeExplanation = exercise["includeExplanation"] as? Bool ?? false
                    state.selected[id] = item
                }
            }

            guard !Task.isCancelled,
                  summaryOwnerUid.trimmingCharacters(in: .whitespacesAndNewlines) == uid,
                  summaryOwnerRole == key.ownerRole,
                  selectedDate.map({ isoDate($0) }) == key.dateIso else {
                return
            }

            summaryPdfURL = try TrainingSummaryPdfExporter.export(
                state: state,
                isEnglish: isEnglish
            )
        } catch {
            guard !Task.isCancelled else { return }
            showSummaryPdfError = true
        }
    }

    @MainActor
    private func loadRemoteSummary(
        ownerUid: String,
        role: SummaryAuthorRole,
        dateIso: String
    ) async throws -> [String: Any]? {
        let collection = Firestore.firestore()
            .collection("users")
            .document(ownerUid)
            .collection("training_summaries_\(role.rawValue)")

        let snapshot = try await collection
            .whereField("dateIso", isEqualTo: dateIso)
            .getDocuments()

        var candidates = snapshot.documents.map { $0.data() }

        if !snapshot.documents.contains(where: { $0.documentID == dateIso }) {
            let directDocument = try await collection.document(dateIso).getDocument()
            if let data = directDocument.data() {
                candidates.append(data)
            }
        }

        func rank(_ data: [String: Any]) -> (Int, Int, Int64) {
            let hasExercises = (data["exercises"] as? [[String: Any]])?.isEmpty == false
            let notes = (data["notes"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let updatedAt = (data["updatedAtMs"] as? NSNumber)?.int64Value ?? 0
            return (hasExercises ? 1 : 0, notes.isEmpty ? 0 : 1, updatedAt)
        }

        return candidates.max { rank($0) < rank($1) }
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

