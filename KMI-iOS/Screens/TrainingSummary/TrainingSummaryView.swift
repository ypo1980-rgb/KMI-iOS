import SwiftUI
import Shared

struct TrainingSummaryView: View {
    @EnvironmentObject private var nav: AppNavModel

    @StateObject private var vm: TrainingSummaryViewModel
    @ObservedObject private var demoPrivacy = DemoPrivacy.shared
    @State private var showAddExercisesSheet = false
    @State private var toastMessage: String?
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var shareErrorMessage: String?

    @State private var exerciseNotesVisibility:
        [String: Bool] = [:]

    @AppStorage("kmi_app_language")
    private var languageCode: String = "he"

    @Environment(\.colorScheme)
    private var colorScheme

    private var summaryCard: Color {
        KmiAppTheme.surface(for: colorScheme)
    }

    private var summaryCardInner: Color {
        KmiAppTheme.surfaceVariant(for: colorScheme)
    }

    private var summaryEditorBackground: Color {
        KmiAppTheme.surface(for: colorScheme)
    }

    private var summaryBorder: Color {
        KmiAppTheme.outlineVariant(for: colorScheme)
    }

    private var summaryDivider: Color {
        KmiAppTheme.outlineVariant(for: colorScheme)
    }

    private var summaryTextDark: Color {
        KmiAppTheme.onSurface(for: colorScheme)
    }

    private var summaryTextMuted: Color {
        KmiAppTheme.onSurfaceVariant(for: colorScheme)
    }

    private var summaryPrimary: Color {
        KmiAppTheme.primary(for: colorScheme)
    }

    private var summaryPurple: Color {
        KmiAppTheme.secondary(for: colorScheme)
    }

    private var isEnglish: Bool {
        let clean =
            languageCode
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

        return clean == "en" ||
            clean == "english"
    }

    private var screenDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    private var screenAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private func tr(
        _ hebrew: String,
        _ english: String
    ) -> String {
        isEnglish ? english : hebrew
    }

    init(
        ownerUid: String,
        isCoach: Bool,
        initialBelt: Belt = .green,
        pickedDateIso: String? = nil,
        initialBranchName: String = "",
        initialCoachName: String = ""
    ) {
        let role: SummaryAuthorRole = isCoach ? .coach : .trainee
        _vm = StateObject(
            wrappedValue: TrainingSummaryViewModel(
                ownerUid: ownerUid,
                ownerRole: role,
                initialBelt: initialBelt,
                pickedDateIso: pickedDateIso,
                initialBranchName: initialBranchName,
                initialCoachName: initialCoachName
            )
        )
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

            ScrollView {
                VStack(spacing: 14) {
                    trainingInfoCard
                    addExercisesCard

                    if !selectedExercises.isEmpty {
                        selectedExercisesCard
                    }

                    notesCard
                    actionsCard
                }
                .padding(12)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)

            if let toastMessage {
                VStack {
                    Spacer()
                    Text(toastMessage)
                        .kmiFont(size: 14, weight: .bold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 24)
                }
                .transition(.opacity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .environment(
            \.layoutDirection,
            screenDirection
        )
        .sheet(isPresented: $showAddExercisesSheet) {
            TrainingSummaryExercisePickerSheet(
                vm: vm,
                initialBelt: vm.state.selectedBelt
            ) {
                showAddExercisesSheet = false
            }
        }
        .sheet(isPresented: $showShareSheet) {
            KmiSystemShareSheet(
                items: shareItems
            )
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
        .onChange(of: vm.state.saveEventId) { _, _ in
            guard let msg = vm.state.lastSaveMsg else { return }
            withAnimation {
                toastMessage = msg
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    toastMessage = nil
                }
            }
        }
        .onAppear {
            let components =
                dateComponents(
                    from: vm.state.dateIso
                )

            if let year = components.year,
               let month = components.month {
                vm.loadSummaryDaysForMonth(
                    year: year,
                    month1to12: month
                )
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
                    notification.object
                        as? NSMutableDictionary else {
                return
            }

            guard request["handled"] as? Bool != true else {
                return
            }

            request["handled"] = true
            shareSummary()
        }
    }

    private var displayedCoachName: String {
        let name = vm.state.coachName
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else {
            return tr("מאמן לא ידוע", "Unknown coach")
        }

        if demoPrivacy.isEnabled {
            return tr("מאמן", "Coach")
        }

        return TrainingCatalogIOS.displayCoach(
            name,
            isEnglish: isEnglish
        )
    }

    private func displayedExerciseName(_ name: String) -> String {
        KmiEnglishTitleResolver.title(
            for: name,
            isEnglish: isEnglish
        )
    }

    private func displayedExerciseTopic(_ topic: String) -> String {
        topic
            .components(separatedBy: " · ")
            .map { part in
                KmiEnglishTitleResolver.title(
                    for: part.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                    isEnglish: isEnglish
                )
            }
            .joined(separator: " · ")
    }

    private var selectedExercises: [SelectedExerciseUi] {
        vm.state.selected.values.sorted { lhs, rhs in
            let comparison = displayedExerciseName(lhs.name)
                .localizedCaseInsensitiveCompare(
                    displayedExerciseName(rhs.name)
                )

            if comparison == .orderedSame {
                return lhs.exerciseId < rhs.exerciseId
            }

            return comparison == .orderedAscending
        }
    }

    private var validDateIso: String? {
        let cleanDate =
            vm.state.dateIso
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        guard
            !cleanDate.isEmpty,
            cleanDate != "{date}",
            cleanDate.lowercased() != "null"
        else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.locale =
            Locale(identifier: "en_US_POSIX")
        formatter.calendar =
            ShabbatHolidayCheckerIOS.calendar
        formatter.timeZone =
            ShabbatHolidayCheckerIOS.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false

        guard
            let date = formatter.date(
                from: cleanDate
            ),
            formatter.string(from: date) ==
                cleanDate
        else {
            return nil
        }

        return cleanDate
    }

    private var trainingInfoCard: some View {
        card {
            HStack(spacing: 10) {
                VStack(
                    alignment:
                        isEnglish
                        ? .leading
                        : .trailing,
                    spacing: 3
                ) {
                    Text(
                        tr(
                            "פרטי האימון",
                            "Training details"
                        )
                    )
                    .kmiFont(size: 17, weight: .heavy)
                    .foregroundStyle(summaryTextDark)

                    Text(
                        validDateIso.map {
                            formattedDate($0)
                        } ??
                        tr(
                            "יש לבחור תאריך לסיכום האימון",
                            "Choose a date for the training summary"
                        )
                    )
                    .kmiFont(
                        size: 12,
                        weight: .semibold
                    )
                    .foregroundStyle(
                        summaryTextMuted
                    )
                    .multilineTextAlignment(
                        isEnglish
                            ? .leading
                            : .trailing
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: screenAlignment
                )

                sectionHeaderIcon(
                    systemImage: "figure.martial.arts"
                )
            }

            Button {
                nav.push(
                    .monthlyTrainingBoard
                )
            } label: {
                HStack(spacing: 7) {
                    Image(
                        systemName:
                            "calendar"
                    )

                    Text(
                        validDateIso == nil
                        ? tr(
                            "בחירת תאריך לסיכום האימון",
                            "Choose training summary date"
                        )
                        : tr(
                            "שינוי תאריך האימון",
                            "Change training date"
                        )
                    )
                    .kmiFont(
                        size: 15,
                        weight: .heavy
                    )
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(summaryPurple)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            if validDateIso == nil {
                Text(
                    tr(
                        "בחר תאריך בלוח האימונים החודשי כדי להתחיל למלא את סיכום האימון.",
                        "Choose a date in the monthly training calendar to start filling out the training summary."
                    )
                )
                .kmiFont(
                    size: 14,
                    weight: .heavy
                )
                .foregroundStyle(summaryTextDark)
                .multilineTextAlignment(
                    isEnglish
                        ? .leading
                        : .trailing
                )
                .frame(
                    maxWidth: .infinity,
                    alignment:
                        isEnglish
                        ? .leading
                        : .trailing
                )
                .padding(12)
                .background(summaryCardInner)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 16,
                        style: .continuous
                    )
                )
            } else {
                VStack(spacing: 7) {
                    summaryInfoRow(
                        label:
                            tr(
                                "סניף",
                                "Branch"
                            ),
                        value:
                            vm.state.branchName.isEmpty
                            ? tr(
                                "לא נמצא סניף",
                                "Branch not found"
                            )
                            : vm.state.branchName
                    )

                    summaryInfoRow(
                        label:
                            tr(
                                "מאמן",
                                "Coach"
                            ),
                        value: displayedCoachName
                    )

                    if !vm.state.groupKey
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        .isEmpty {
                        summaryInfoRow(
                            label: tr("קבוצה", "Group"),
                            value: TrainingCatalogIOS.displayGroup(
                                vm.state.groupKey,
                                isEnglish: isEnglish
                            )
                        )
                    }
                }
                .padding(10)
                .background(summaryCardInner)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 14,
                        style: .continuous
                    )
                )
            }
        }
    }

    private func summaryInfoRow(
        label: String,
        value: String
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .kmiFont(size: 12, weight: .bold)
                .foregroundStyle(summaryTextMuted)

            Text(value)
                .kmiFont(size: 14, weight: .semibold)
                .foregroundStyle(summaryTextDark)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var addExercisesCard: some View {
        card {
            sectionHeader(
                tr(
                    "הוספת תרגילים",
                    "Add exercises"
                ),
                subtitle: tr(
                    "בחר תרגילים שבוצעו באימון",
                    "Choose exercises performed in training"
                ),
                systemImage:
                    "checklist.checked"
            )

            summarySectionDivider

            Text(
                vm.state.selected.isEmpty
                ? tr(
                    "עדיין לא נוספו תרגילים לאימון הזה",
                    "No exercises have been added to this training yet"
                )
                : tr(
                    "נוספו כבר \(vm.state.selected.count) תרגילים לאימון הזה",
                    "\(vm.state.selected.count) exercises have already been added"
                )
            )
            .kmiFont(size: 14, weight: .semibold)
            .foregroundStyle(summaryTextMuted)
            .frame(
                maxWidth: .infinity,
                alignment: screenAlignment
            )

            Button {
                showAddExercisesSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(
                        systemName:
                            "checklist.checked"
                    )

                    Text(
                        tr(
                            "הוסף תרגילים",
                            "Add exercises"
                        )
                    )
                    .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(summaryPurple)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var selectedExercisesCard: some View {
        card {
            sectionHeader(
                tr(
                    "התרגילים שנוספו לאימון",
                    "Exercises added to training"
                ),
                subtitle: tr(
                    "ניהול, עריכה והוספת דגשים לכל תרגיל",
                    "Manage, edit and add notes to each exercise"
                ),
                systemImage:
                    "figure.martial.arts"
            )

            summarySectionDivider

            HStack {
                Spacer()

                HStack(spacing: 6) {
                    Image(
                        systemName:
                            "checkmark.circle.fill"
                    )

                    Text(
                        tr(
                            "סה״כ \(selectedExercises.count) תרגילים",
                            "Total \(selectedExercises.count) exercises"
                        )
                    )
                }
                .kmiFont(size: 12, weight: .bold)
                .foregroundStyle(summaryTextDark)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    summaryPrimary.opacity(0.16)
                )
                .clipShape(Capsule())
            }

            VStack(spacing: 12) {
                ForEach(selectedExercises) { item in
                    exerciseEditor(item)
                }
            }
        }
    }

    private var notesCard: some View {
        card {
            sectionHeader(
                tr("סיכום כללי", "General summary"),
                subtitle: tr(
                    "סיכום חופשי של האימון, תחושות, דגשים ומה לשפר",
                    "Free summary, feelings, highlights and improvements"
                ),
                systemImage: "note.text"
            )

            summarySectionDivider

            ZStack(alignment: .topLeading) {
                TextEditor(
                    text: Binding(
                        get: { vm.state.notes },
                        set: { vm.setNotes($0) }
                    )
                )
                .scrollContentBackground(.hidden)
                .kmiFont(size: 16, weight: .regular)
                .foregroundStyle(summaryTextDark)
                .multilineTextAlignment(.leading)
                .frame(minHeight: 160)
                .padding(6)

                if vm.state.notes
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty {
                    Text(
                        vm.state.isCoach
                            ? tr(
                                "דגשים מקצועיים, ביצוע, מה לשפר…",
                                "Professional notes, performance, what to improve…"
                            )
                            : tr(
                                "איך היה האימון? מה הרגשת? מה לשפר…",
                                "How was the training? What did you feel? What should be improved…"
                            )
                    )
                    .kmiFont(size: 14, weight: .medium)
                    .foregroundStyle(summaryTextMuted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 15)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .background(summaryEditorBackground)
            .overlay(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .stroke(summaryDivider, lineWidth: 1)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
            )
        }
    }

    private var actionsCard: some View {
        card {
            sectionHeader(
                tr(
                    "שמירה",
                    "Save"
                ),
                subtitle: tr(
                    "שמור את הסיכום והתרגילים שנוספו לאימון הזה",
                    "Save the summary and exercises added to this training"
                ),
                systemImage:
                    "checkmark"
            )

            summarySectionDivider

            Button {
                vm.save()
            } label: {
                HStack(spacing: 8) {
                    if vm.state.isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(
                            systemName:
                                "checkmark.circle.fill"
                        )
                    }

                    Text(
                        vm.state.isSaving
                        ? tr("שומר...", "Saving...")
                        : tr(
                            "שמירת סיכום האימון",
                            "Save training summary"
                        )
                    )
                    .kmiFont(size: 17, weight: .bold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(summaryPrimary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(vm.state.isSaving)
            .opacity(
                vm.state.isSaving ? 0.72 : 1
            )
        }
    }

    private func exerciseEditor(
        _ item: SelectedExerciseUi
    ) -> some View {
        let notesOpen =
            exerciseNotesVisibility[
                item.exerciseId
            ] ?? !item.highlight
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty

        return VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Text(displayedExerciseName(item.name))
                .kmiFont(size: 18, weight: .heavy)
                .foregroundStyle(summaryTextDark)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(
                    maxWidth: .infinity,
                    alignment: screenAlignment
                )

            if !item.topic
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty {
                Text(displayedExerciseTopic(item.topic))
                    .kmiFont(size: 11.5, weight: .semibold)
                    .foregroundStyle(summaryTextMuted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(
                        maxWidth: .infinity,
                        alignment: screenAlignment
                    )
            }

            HStack(spacing: 10) {
                Button {
                    exerciseNotesVisibility[
                        item.exerciseId
                    ] = !notesOpen
                } label: {
                    Image(
                        systemName:
                            notesOpen
                            ? "note.text.badge.minus"
                            : "note.text.badge.plus"
                    )
                    .kmiFont(size: 17, weight: .bold)
                    .foregroundStyle(summaryTextDark)
                    .frame(width: 42, height: 42)
                    .background(
                        summaryPrimary.opacity(0.18)
                    )
                    .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    notesOpen
                    ? tr(
                        "סגור הערות",
                        "Close notes"
                    )
                    : tr(
                        "פתח הערות",
                        "Open notes"
                    )
                )

                Button {
                    exerciseNotesVisibility[
                        item.exerciseId
                    ] = nil

                    vm.removeExercise(
                        item.exerciseId
                    )
                } label: {
                    Image(systemName: "trash")
                        .kmiFont(size: 16, weight: .bold)
                        .foregroundStyle(
                            KmiAppTheme.onErrorContainer(
                                for: colorScheme
                            )
                        )
                        .frame(width: 42, height: 42)
                        .background(
                            KmiAppTheme.errorContainer(
                                for: colorScheme
                            )
                        )
                        .overlay {
                            Circle()
                                .stroke(
                                    KmiAppTheme.onErrorContainer(
                                        for: colorScheme
                                    )
                                    .opacity(0.35),
                                    lineWidth: 1
                                )
                        }
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    tr(
                        "מחק תרגיל",
                        "Delete exercise"
                    )
                )

                Spacer(minLength: 0)
            }
            .environment(
                \.layoutDirection,
                isEnglish
                ? .leftToRight
                : .rightToLeft
            )

            summarySectionDivider

            if !notesOpen &&
                !item.highlight
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty {
                Text(item.highlight)
                    .kmiFont(size: 14, weight: .regular)
                    .foregroundStyle(summaryTextDark)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(
                        maxWidth: .infinity,
                        alignment: screenAlignment
                    )
                    .padding(12)
                    .background(
                        summaryCard
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 14,
                            style: .continuous
                        )
                    )
            }

            if notesOpen {
                VStack(
                    alignment: .leading,
                    spacing: 6
                ) {
                    Text(
                        tr(
                            "דגשים והערות לתרגיל",
                            "Exercise notes and highlights"
                        )
                    )
                    .kmiFont(size: 12, weight: .bold)
                    .foregroundStyle(summaryTextMuted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(
                        maxWidth: .infinity,
                        alignment: screenAlignment
                    )

                    TextEditor(
                        text: Binding(
                            get: {
                                item.highlight
                            },
                            set: {
                                vm.setHighlight(
                                    item.exerciseId,
                                    highlight: $0
                                )
                            }
                        )
                    )
                    .scrollContentBackground(.hidden)
                    .kmiFont(size: 14, weight: .regular)
                    .multilineTextAlignment(.leading)
                    .frame(minHeight: 90)
                    .padding(8)
                    .foregroundStyle(summaryTextDark)
                    .background(
                        summaryEditorBackground
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: 12,
                            style: .continuous
                        )
                        .stroke(
                            summaryDivider,
                            lineWidth: 1
                        )
                    }
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 12,
                            style: .continuous
                        )
                    )
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(summaryCardInner)
        .overlay {
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .stroke(
                summaryBorder,
                lineWidth: 1
            )
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }

    @MainActor
    private func shareSummary() {
        guard !showShareSheet else {
            return
        }

        shareErrorMessage = nil
        shareItems = []

        do {
            let url = try TrainingSummaryPdfExporter.export(
                state: vm.state,
                isEnglish: isEnglish
            )

            shareItems = [url]
            showShareSheet = true
        } catch TrainingSummaryPdfExportError.invalidDate {
            shareErrorMessage = tr(
                "יש לבחור תאריך אימון תקין לפני השיתוף.",
                "Choose a valid training date before sharing."
            )
        } catch TrainingSummaryPdfExportError.unableToFitContent {
            shareErrorMessage = tr(
                "לא ניתן לסדר את תוכן הסיכום במסמך PDF.",
                "Unable to arrange the summary content in the PDF."
            )
        } catch {
            shareErrorMessage = tr(
                "לא ניתן ליצור את קובץ ה־PDF. נסה שוב.",
                "Unable to create the PDF file. Please try again."
            )
        }
    }

    private var summarySectionDivider: some View {
        Capsule()
            .fill(summaryDivider)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }

    private func card<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(
            alignment: isEnglish ? .leading : .trailing,
            spacing: 10,
            content: content
        )
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(summaryCard)
        .overlay(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .stroke(
                summaryBorder,
                lineWidth: 1
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }

    private func sectionHeader(
        _ title: String,
        subtitle: String,
        systemImage: String
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            sectionHeaderIcon(systemImage: systemImage)

            headerTextBlock(
                title: title,
                subtitle: subtitle
            )
        }
    }

    private func headerTextBlock(
        title: String,
        subtitle: String
    ) -> some View {
        VStack(
            alignment: isEnglish ? .leading : .trailing,
            spacing: 3
        ) {
            Text(title)
                .kmiFont(size: 17, weight: .heavy)
                .foregroundStyle(summaryTextDark)

            Text(subtitle)
                .kmiFont(size: 12, weight: .semibold)
                .foregroundStyle(summaryTextMuted)
        }
        .multilineTextAlignment(
            isEnglish ? .leading : .trailing
        )
        .fixedSize(horizontal: false, vertical: true)
        .frame(
            maxWidth: .infinity,
            alignment: screenAlignment
        )
    }

    private func sectionHeaderIcon(
        systemImage: String
    ) -> some View {
        Image(systemName: systemImage)
            .kmiIconSize(18)
            .foregroundStyle(
                KmiAppTheme.onPrimaryContainer(
                    for: colorScheme
                )
            )
            .padding(11)
            .background(
                Circle()
                    .fill(
                        KmiAppTheme.primaryContainer(
                            for: colorScheme
                        )
                    )
            )
            .accessibilityHidden(true)
    }

    private func summaryIsoFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = ShabbatHolidayCheckerIOS.calendar
        formatter.timeZone = ShabbatHolidayCheckerIOS.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }

    private func formattedDate(
        _ iso: String
    ) -> String {
        let input = summaryIsoFormatter()

        guard let date = input.date(from: iso),
              input.string(from: date) == iso else {
            return iso
        }

        let output = DateFormatter()
        output.locale = Locale(
            identifier: isEnglish ? "en_US" : "he_IL"
        )
        output.calendar = ShabbatHolidayCheckerIOS.calendar
        output.timeZone = ShabbatHolidayCheckerIOS.timeZone
        output.dateFormat = "EEEE, d MMM yyyy"

        return output.string(from: date)
    }

    private func dateComponents(
        from iso: String
    ) -> DateComponents {
        let formatter = summaryIsoFormatter()

        guard let date = formatter.date(from: iso),
              formatter.string(from: date) == iso else {
            return DateComponents()
        }

        return ShabbatHolidayCheckerIOS.calendar.dateComponents(
            [.year, .month, .day],
            from: date
        )
    }
}
