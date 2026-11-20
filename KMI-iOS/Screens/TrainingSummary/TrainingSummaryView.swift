import SwiftUI
import Shared

struct TrainingSummaryView: View {
    @EnvironmentObject private var nav: AppNavModel
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var vm: TrainingSummaryViewModel

    @State private var preparedSummaryDate: String?
    @State private var summaryReloadCount = 0

    private var canEditSummary: Bool {
        guard let date = validDateIso else { return false }

        return preparedSummaryDate == date &&
            !vm.isLoadingRemoteSummary &&
            !vm.remoteSummaryLoadFailed &&
            !vm.state.isSaving
    }

    @ObservedObject private var demoPrivacy = DemoPrivacy.shared

    @AppStorage("kmi_app_language")
    private var languageCode: String = "he"

    @State private var showAddExercisesSheet = false
    @State private var exercisesExpanded = false
    @State private var exerciseNotesVisibility: [String: Bool] = [:]
    @State private var toastMessage: String?
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var shareErrorMessage: String?

    private var summaryCard: Color {
        KmiAppTheme.surface(for: colorScheme)
    }

    private var summaryCardInner: Color {
        KmiAppTheme.surfaceVariant(for: colorScheme)
    }

    private var summaryBorder: Color {
        KmiAppTheme.outlineVariant(for: colorScheme)
    }

    private var summaryDivider: Color {
        summaryBorder.opacity(0.72)
    }

    private var summaryText: Color {
        KmiAppTheme.onSurface(for: colorScheme)
    }

    private var summaryTextMuted: Color {
        KmiAppTheme.onSurfaceVariant(for: colorScheme)
    }

    private var summaryPrimary: Color {
        KmiAppTheme.primary(for: colorScheme)
    }

    private var summaryOnPrimary: Color {
        KmiAppTheme.onPrimary(for: colorScheme)
    }

    private var isEnglish: Bool {
        let clean = languageCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return clean == "en" || clean == "english"
    }

    private var screenDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
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
            KmiAppBackground()

            ScrollView {
                VStack(spacing: 12) {
                    if validDateIso != nil && vm.remoteSummaryLoadFailed {
                        VStack(spacing: 8) {
                            Text(tr(
                                "לא ניתן היה לטעון את הסיכום.",
                                "Could not load the summary."
                            ))
                            .kmiTypography(.secondary)
                            .multilineTextAlignment(.center)

                            Button {
                                preparedSummaryDate = nil
                                summaryReloadCount += 1
                            } label: {
                                Text(tr("נסה שוב", "Try Again"))
                                    .kmiTypography(.action)
                            }
                            .buttonStyle(.bordered)
                            .tint(summaryPrimary)
                        }
                    }

                    trainingInfoCard
                        .disabled(vm.state.isSaving)

                    VStack(spacing: 12) {
                        exercisesCard
                        notesCard
                        actionsCard
                    }
                    .disabled(!canEditSummary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            if vm.state.isSaving ||
                (validDateIso != nil &&
                    !vm.remoteSummaryLoadFailed &&
                    (preparedSummaryDate != validDateIso || vm.isLoadingRemoteSummary)) {
                KmiLoadingOverlay()
                    .allowsHitTesting(vm.state.isSaving)
                    .accessibilityLabel(
                        vm.state.isSaving
                            ? tr("שומר את סיכום האימון", "Saving training summary")
                            : tr("טוען סיכום אימון", "Loading training summary")
                    )
            }

            if let toastMessage {
                VStack {
                    Spacer()

                    Text(toastMessage)
                        .kmiTypography(.secondary)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.layoutDirection, screenDirection)
        .sheet(isPresented: $showAddExercisesSheet) {
            TrainingSummaryExercisePickerSheet(
                vm: vm,
                initialBelt: vm.state.selectedBelt
            ) {
                showAddExercisesSheet = false
            }
            .environment(\.layoutDirection, screenDirection)
        }
        .sheet(isPresented: $showShareSheet) {
            KmiSystemShareSheet(items: shareItems)
        }
        .alert(
            tr("לא ניתן לשתף", "Unable to Share"),
            isPresented: Binding(
                get: { shareErrorMessage != nil },
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
        .onChange(of: vm.state.dateIso) { _, _ in
            exercisesExpanded = false
            exerciseNotesVisibility.removeAll()
        }
        .onChange(of: vm.state.selected.isEmpty) { _, isEmpty in
            if isEmpty {
                exercisesExpanded = false
            }
        }
        .onChange(of: vm.state.saveEventId) { _, _ in
            guard let message = vm.state.lastSaveMsg else {
                return
            }

            withAnimation {
                toastMessage = message
            }
        }
        .task(id: "\(vm.state.dateIso)|\(summaryReloadCount)") {
            preparedSummaryDate = nil
            guard let date = validDateIso else { return }

            await vm.prepareSummaryForEditing(dateIso: date)

            guard !Task.isCancelled,
                  validDateIso == date,
                  !vm.remoteSummaryLoadFailed else { return }

            preparedSummaryDate = date
        }
        .task(id: vm.state.saveEventId) {
            guard toastMessage != nil else {
                return
            }

            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }

            withAnimation {
                toastMessage = nil
            }
        }
        .onAppear {
            let components = dateComponents(from: vm.state.dateIso)

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
                for: Notification.Name("KMI_GLOBAL_SHARE_REQUEST")
            )
        ) { notification in
            guard let request = notification.object as? NSMutableDictionary,
                  request["handled"] as? Bool != true else {
                return
            }

            request["handled"] = true
            shareSummary()
        }
    }

    // MARK: - Display values

    private func tr(_ hebrew: String, _ english: String) -> String {
        isEnglish ? english : hebrew
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
                    for: part.trimmingCharacters(in: .whitespacesAndNewlines),
                    isEnglish: isEnglish
                )
            }
            .joined(separator: " · ")
    }

    private var selectedExercises: [SelectedExerciseUi] {
        vm.state.selected.values.sorted { lhs, rhs in
            let comparison = displayedExerciseName(lhs.name)
                .localizedCaseInsensitiveCompare(displayedExerciseName(rhs.name))

            if comparison == .orderedSame {
                return lhs.exerciseId < rhs.exerciseId
            }

            return comparison == .orderedAscending
        }
    }

    private var validDateIso: String? {
        let cleanDate = vm.state.dateIso
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanDate.isEmpty,
              cleanDate != "{date}",
              cleanDate.lowercased() != "null" else {
            return nil
        }

        let formatter = summaryIsoFormatter()

        guard let date = formatter.date(from: cleanDate),
              formatter.string(from: date) == cleanDate else {
            return nil
        }

        return cleanDate
    }

    // MARK: - Training details

    private var trainingInfoCard: some View {
        let dateIso = validDateIso

        return card {
            sectionHeader(
                tr("פרטי האימון", "Training details"),
                subtitle: dateIso.map { formattedDate($0) } ??
                    tr(
                        "יש לבחור תאריך לסיכום האימון",
                        "Choose a date for the training summary"
                    ),
                systemImage: "figure.martial.arts"
            )

            summarySectionDivider

            Button {
                nav.push(.monthlyTrainingBoard)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "calendar")
                        .kmiIconSize(.small)
                        .accessibilityHidden(true)

                    Text(
                        dateIso == nil
                            ? tr(
                                "בחירת תאריך לסיכום האימון",
                                "Choose training summary date"
                            )
                            : tr(
                                "שינוי תאריך האימון",
                                "Change training date"
                            )
                    )
                    .kmiTypography(.action)
                    .fontWeight(.heavy)
                }
                .foregroundStyle(summaryOnPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(summaryPrimary, in: Capsule())
            }
            .buttonStyle(.plain)

            if dateIso == nil {
                Text(
                    tr(
                        "בחר תאריך בלוח האימונים החודשי כדי להתחיל למלא את סיכום האימון.",
                        "Choose a date in the monthly training calendar to start filling out the training summary."
                    )
                )
                .kmiTypography(.body)
                .fontWeight(.heavy)
                .foregroundStyle(summaryText)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    summaryCardInner,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            } else {
                VStack(spacing: 7) {
                    summaryInfoRow(
                        label: tr("סניף", "Branch"),
                        value: vm.state.branchName.isEmpty
                            ? tr("לא נמצא סניף", "Branch not found")
                            : vm.state.branchName
                    )

                    summaryInfoRow(
                        label: tr("מאמן", "Coach"),
                        value: displayedCoachName
                    )

                    if !vm.state.groupKey
                        .trimmingCharacters(in: .whitespacesAndNewlines)
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
                .background(
                    summaryCardInner,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
        }
    }

    private func summaryInfoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .kmiTypography(.caption)
                .fontWeight(.bold)
                .foregroundStyle(summaryTextMuted)

            Text(value)
                .kmiTypography(.body)
                .fontWeight(.heavy)
                .foregroundStyle(summaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Exercises

    private var exercisesCard: some View {
        let exerciseCount = vm.state.selected.count
        let canEditExercises = exerciseCount > 0

        return card {
            sectionHeader(
                tr("תרגילים באימון", "Training exercises"),
                subtitle: tr(
                    "הוסף תרגילים חדשים או ערוך תרגילים שכבר נוספו",
                    "Add new exercises or edit exercises already added"
                ),
                systemImage: "checklist.checked"
            )

            summarySectionDivider

            Text(
                canEditExercises
                    ? tr(
                        "נוספו \(exerciseCount) תרגילים לאימון הזה",
                        "\(exerciseCount) exercises have been added to this training"
                    )
                    : tr(
                        "עדיין לא נוספו תרגילים לאימון הזה",
                        "No exercises have been added to this training yet"
                    )
            )
            .kmiTypography(.secondary)
            .fontWeight(.semibold)
            .foregroundStyle(summaryTextMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)

            Button {
                showAddExercisesSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checklist.checked")
                        .kmiIconSize(.small)
                        .accessibilityHidden(true)

                    Text(tr("הוסף תרגילים", "Add exercises"))
                        .kmiTypography(.action)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(summaryOnPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(summaryPrimary, in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                exercisesExpanded.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "dumbbell.fill")
                        .kmiIconSize(.small)
                        .accessibilityHidden(true)

                    Text(
                        exercisesExpanded
                            ? tr("סגור עריכת תרגילים", "Close exercise editing")
                            : tr(
                                "פתח / ערוך תרגילים קיימים",
                                "Open / edit existing exercises"
                            )
                    )
                    .kmiTypography(.action)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(canEditExercises ? summaryText : summaryTextMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(
                    canEditExercises
                        ? summaryPrimary.opacity(0.14)
                        : summaryCardInner,
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)
            .disabled(!canEditExercises)

            if exercisesExpanded && canEditExercises {
                summarySectionDivider

                VStack(spacing: 12) {
                    ForEach(selectedExercises) { item in
                        exerciseEditor(item)
                    }
                }
            }
        }
    }

    private func exerciseEditor(_ item: SelectedExerciseUi) -> some View {
        let highlight = item.highlight
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let notesOpen = exerciseNotesVisibility[item.exerciseId] ?? !highlight.isEmpty
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        return VStack(alignment: .leading, spacing: 10) {
            Text(displayedExerciseName(item.name))
                .kmiTypography(.cardTitle)
                .fontWeight(.heavy)
                .foregroundStyle(summaryText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !item.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(displayedExerciseTopic(item.topic))
                    .kmiTypography(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(summaryTextMuted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                Button {
                    exerciseNotesVisibility[item.exerciseId] = !notesOpen
                } label: {
                    Image(
                        systemName: notesOpen
                            ? "note.text.badge.minus"
                            : "note.text.badge.plus"
                    )
                    .kmiIconSize(.medium)
                    .foregroundStyle(summaryText)
                    .frame(width: 44, height: 44)
                    .background(summaryPrimary.opacity(0.18), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    Text(
                        notesOpen
                            ? tr("סגור הערות", "Close notes")
                            : tr("פתח הערות", "Open notes")
                    )
                )

                Button {
                    exerciseNotesVisibility[item.exerciseId] = nil
                    vm.removeExercise(item.exerciseId)
                } label: {
                    Image(systemName: "trash")
                        .kmiIconSize(.medium)
                        .foregroundStyle(KmiAppTheme.onErrorContainer(for: colorScheme))
                        .frame(width: 44, height: 44)
                        .background(
                            KmiAppTheme.errorContainer(for: colorScheme),
                            in: Circle()
                        )
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    KmiAppTheme.onErrorContainer(for: colorScheme)
                                        .opacity(0.35),
                                    lineWidth: 1
                                )
                                .allowsHitTesting(false)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(tr("מחק תרגיל", "Delete exercise")))

                Spacer(minLength: 0)
            }

            summarySectionDivider

            Toggle(
                isOn: Binding(
                    get: {
                        vm.state.selected[item.exerciseId]?.includeExplanation ?? false
                    },
                    set: { isIncluded in
                        vm.setIncludeExplanation(
                            item.exerciseId,
                            includeExplanation: isIncluded
                        )
                    }
                )
            ) {
                Text(
                    tr(
                        "כלול הסבר לתרגיל ב־PDF",
                        "Include exercise explanation in PDF"
                    )
                )
                .kmiTypography(.secondary)
                .fontWeight(.semibold)
                .foregroundStyle(summaryText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            }
            .tint(summaryPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background(
                summaryCard,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )

            if notesOpen {
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("דגשים והערות לתרגיל", "Exercise notes and highlights"))
                        .kmiTypography(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(summaryTextMuted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextEditor(
                        text: Binding(
                            get: {
                                vm.state.selected[item.exerciseId]?.highlight ??
                                    item.highlight
                            },
                            set: {
                                vm.setHighlight(item.exerciseId, highlight: $0)
                            }
                        )
                    )
                    .scrollContentBackground(.hidden)
                    .kmiTypography(.body)
                    .fontWeight(.regular)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(summaryText)
                    .frame(minHeight: 90)
                    .padding(8)
                    .background(
                        summaryCard,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(summaryDivider, lineWidth: 1)
                            .allowsHitTesting(false)
                    }
                    .accessibilityLabel(
                        Text(tr("דגשים והערות לתרגיל", "Exercise notes and highlights"))
                    )
                }
            } else if !highlight.isEmpty {
                Text(item.highlight)
                    .kmiTypography(.body)
                    .fontWeight(.regular)
                    .foregroundStyle(summaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        summaryCard,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(summaryCardInner, in: shape)
        .overlay {
            shape
                .strokeBorder(summaryBorder, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    // MARK: - General notes and save

    private var notesCard: some View {
        let prompt = vm.state.isCoach
            ? tr(
                "דגשים מקצועיים, ביצוע, מה לשפר…",
                "Professional notes, performance, what to improve…"
            )
            : tr(
                "איך היה האימון? מה הרגשת? מה לשפר…",
                "How was the training? What did you feel? What should be improved…"
            )
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        return card {
            sectionHeader(
                tr("סיכום כללי", "General summary"),
                subtitle: tr(
                    "סיכום חופשי של האימון, תחושות, דגשים ומה לשפר",
                    "Free summary of the training, feelings, highlights, and what to improve"
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
                .kmiTypography(.body)
                .fontWeight(.regular)
                .foregroundStyle(summaryText)
                .multilineTextAlignment(.leading)
                .frame(minHeight: 145)
                .padding(6)
                .accessibilityLabel(Text(tr("סיכום כללי", "General summary")))
                .accessibilityHint(Text(prompt))

                if vm.state.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(prompt)
                        .kmiTypography(.secondary)
                        .fontWeight(.medium)
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
            .background(summaryCard, in: shape)
            .overlay {
                shape
                    .strokeBorder(summaryDivider, lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
    }

    private var actionsCard: some View {
        card {
            sectionHeader(
                tr("שמירה", "Save"),
                subtitle: tr(
                    "שמור את הסיכום והתרגילים שנוספו לאימון הזה",
                    "Save the summary and exercises added to this training"
                ),
                systemImage: "checkmark"
            )

            summarySectionDivider

            Button {
                vm.save(onSaved: {
                    nav.pop()
                })
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .kmiIconSize(.medium)
                        .accessibilityHidden(true)

                    Text(
                        vm.state.isSaving
                            ? tr("שומר...", "Saving...")
                        : tr("שמירת סיכום האימון", "Save training summary")
                )
                .kmiTypography(.action)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                }
                .foregroundStyle(summaryOnPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(summaryPrimary, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(vm.state.isSaving)
            .opacity(vm.state.isSaving ? 0.72 : 1)
        }
    }

    // MARK: - PDF sharing

    @MainActor
    private func shareSummary() {
        guard canEditSummary else { return }
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

    // MARK: - Card layout

    private var summarySectionDivider: some View {
        Capsule()
            .fill(summaryDivider)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    private func card<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

        return VStack(alignment: .leading, spacing: 12, content: content)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(summaryCard, in: shape)
            .overlay {
                shape
                    .strokeBorder(summaryBorder, lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }

    private func sectionHeader(
        _ title: String,
        subtitle: String,
        systemImage: String
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .kmiTypography(.cardTitle)
                    .fontWeight(.heavy)
                    .foregroundStyle(KmiAppTheme.sectionHeaderContentColor)
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .kmiTypography(.secondary)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        KmiAppTheme.sectionHeaderContentColor.opacity(0.85)
                    )
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: systemImage)
                .kmiIconSize(.small)
                .foregroundStyle(KmiAppTheme.onPrimaryContainer(for: colorScheme))
                .frame(width: 42, height: 42)
                .background(KmiAppTheme.primaryContainer(for: colorScheme), in: Circle())
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            KmiAppTheme.sectionHeaderBrush,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    // MARK: - Dates

    private func summaryIsoFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = ShabbatHolidayCheckerIOS.calendar
        formatter.timeZone = ShabbatHolidayCheckerIOS.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }

    private func formattedDate(_ iso: String) -> String {
        let input = summaryIsoFormatter()

        guard let date = input.date(from: iso),
              input.string(from: date) == iso else {
            return iso
        }

        let output = DateFormatter()
        output.locale = Locale(identifier: isEnglish ? "en_US" : "he_IL")
        output.calendar = ShabbatHolidayCheckerIOS.calendar
        output.timeZone = ShabbatHolidayCheckerIOS.timeZone
        output.dateFormat = "EEEE, d MMM yyyy"

        return output.string(from: date)
    }

    private func dateComponents(from iso: String) -> DateComponents {
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
