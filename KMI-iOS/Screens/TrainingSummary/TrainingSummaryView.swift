import SwiftUI
import Shared

struct TrainingSummaryView: View {
    @EnvironmentObject private var nav: AppNavModel

    @StateObject private var vm: TrainingSummaryViewModel
    @State private var showAddExercisesSheet = false
    @State private var toastMessage: String?
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

    @State private var exerciseNotesVisibility:
        [String: Bool] = [:]

    @AppStorage("kmi_app_language")
    private var languageCode: String = "he"

    @Environment(\.colorScheme)
    private var colorScheme

    private var summaryBgTop: Color {
        colorScheme == .dark
            ? Color(hex: 0xFF050913)
            : Color(hex: 0xFFF8FBFF)
    }

    private var summaryBgMid1: Color {
        colorScheme == .dark
            ? Color(hex: 0xFF0A1728)
            : Color(hex: 0xFFEAF4FF)
    }

    private var summaryBgMid2: Color {
        colorScheme == .dark
            ? Color(hex: 0xFF0B2942)
            : Color(hex: 0xFFB7DDF7)
    }

    private var summaryBgAccent: Color {
        colorScheme == .dark
            ? Color(hex: 0xFF0B3B62)
            : Color(hex: 0xFF1F78B4)
    }

    private var summaryBgBottom: Color {
        colorScheme == .dark
            ? Color(hex: 0xFF020B16)
            : Color(hex: 0xFF062B4A)
    }

    private var summaryCard: Color {
        colorScheme == .dark
            ? Color(hex: 0xFF111D2E)
            : Color(hex: 0xFFEAF2FF)
    }

    private var summaryCardInner: Color {
        colorScheme == .dark
            ? Color(hex: 0xFF18283D)
            : Color(hex: 0xFFDDEAFF)
    }

    private var summaryEditorBackground: Color {
        colorScheme == .dark
            ? Color(hex: 0xFF0F1B2B)
            : Color(hex: 0xFFF7FAFF)
    }

    private var summaryBorder: Color {
        colorScheme == .dark
            ? Color(hex: 0xFF35506D)
            : Color(hex: 0xFFD8E3F5)
    }

    private var summaryDivider: Color {
        colorScheme == .dark
            ? Color(hex: 0xFF2C435D)
            : Color(hex: 0xFFC7D7EE)
    }

    private var summaryTextDark: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.94)
            : Color(hex: 0xFF1E2A3D)
    }

    private var summaryTextMuted: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.68)
            : Color(hex: 0xFF5E6C80)
    }

    private var summaryPrimary: Color {
        Color(hex: 0xFF0EA5E9)
    }

    private var summaryPurple: Color {
        Color(hex: 0xFF7B57D1)
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
                colors: [
                    summaryBgTop,
                    summaryBgMid1,
                    summaryBgMid2,
                    summaryBgAccent,
                    summaryBgBottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay {
                LinearGradient(
                    colors: [
                        Color.white.opacity(
                            colorScheme == .dark
                                ? 0.06
                                : 0.16
                        ),
                        Color.clear,
                        Color.white.opacity(
                            colorScheme == .dark
                                ? 0.03
                                : 0.08
                        ),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
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
        .onChange(of: vm.state.saveEventId) { _ in
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

            request["handled"] = true
            shareSummary()
        }
    }

    private var selectedExercises: [SelectedExerciseUi] {
        vm.state.selected.values.sorted {
            $0.name.localizedCaseInsensitiveCompare(
                $1.name
            ) == .orderedAscending
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
            Calendar(identifier: .gregorian)
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

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(
                                    red: 0.55,
                                    green: 0.36,
                                    blue: 0.96
                                ),
                                Color(
                                    red: 0.19,
                                    green: 0.18,
                                    blue: 0.51
                                )
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(
                            systemName:
                                "figure.martial.arts"
                        )
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                    }
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
                        value:
                            vm.state.coachName.isEmpty
                            ? tr(
                                "מאמן לא ידוע",
                                "Unknown coach"
                            )
                            : vm.state.coachName
                    )

                    if !vm.state.groupKey.isEmpty {
                        summaryInfoRow(
                            label:
                                tr(
                                    "קבוצה",
                                    "Group"
                                ),
                            value:
                                vm.state.groupKey
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
        HStack(spacing: 8) {
            Text(value)
                .kmiFont(size: 14, weight: .semibold)
                .foregroundStyle(summaryTextDark)

            Spacer()

            Text(label)
                .kmiFont(size: 12, weight: .bold)
                .foregroundStyle(summaryTextMuted)
        }
        .frame(maxWidth: .infinity)
        .environment(
            \.layoutDirection,
            isEnglish
            ? .rightToLeft
            : .leftToRight
        )
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
                tr(
                    "סיכום כללי",
                    "General summary"
                ),
                subtitle: tr(
                    "סיכום חופשי של האימון, תחושות, דגשים ומה לשפר",
                    "Free summary, feelings, highlights and improvements"
                ),
                systemImage:
                    "note.text"
            )

            summarySectionDivider

            ZStack(
                alignment:
                    isEnglish
                    ? .topLeading
                    : .topTrailing
            ) {
                TextEditor(
                    text: Binding(
                        get: {
                            vm.state.notes
                        },
                        set: {
                            vm.setNotes($0)
                        }
                    )
                )
                .scrollContentBackground(.hidden)
                .kmiFont(
                    size: 16,
                    weight: .regular
                )
                .foregroundStyle(summaryTextDark)
                .multilineTextAlignment(
                    isEnglish
                        ? .leading
                        : .trailing
                )
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
                    .kmiFont(
                        size: 14,
                        weight: .medium
                    )
                    .foregroundStyle(
                        summaryTextMuted.opacity(0.82)
                    )
                    .multilineTextAlignment(
                        isEnglish
                            ? .leading
                            : .trailing
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 15)
                    .allowsHitTesting(false)
                }
            }
            .background(
                summaryEditorBackground
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .stroke(
                    summaryDivider,
                    lineWidth: 1
                )
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
            alignment:
                isEnglish ? .leading : .trailing,
            spacing: 10
        ) {
            Text(item.name)
                .kmiFont(size: 18, weight: .heavy)
                .foregroundStyle(summaryTextDark)
                .multilineTextAlignment(
                    isEnglish ? .leading : .trailing
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: screenAlignment
                )

            if !item.topic
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty {
                Text(item.topic)
                    .kmiFont(size: 11.5, weight: .semibold)
                    .foregroundStyle(summaryTextMuted)
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
                        .foregroundStyle(Color.red)
                        .frame(width: 42, height: 42)
                        .background(
                            Color.white.opacity(0.74)
                        )
                        .overlay {
                            Circle()
                                .stroke(
                                    Color.red.opacity(0.55),
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
                    .multilineTextAlignment(
                        isEnglish
                        ? .leading
                        : .trailing
                    )
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
                    alignment:
                        isEnglish
                        ? .leading
                        : .trailing,
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

    private func shareSummary() {
        let text = vm.state.shareText
        shareItems = [text]
        showShareSheet = true
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
            alignment:
                isEnglish ? .leading : .trailing,
            spacing: 12,
            content: content
        )
        .padding(16)
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
        .shadow(
            color: Color.black.opacity(0.08),
            radius: 8,
            x: 0,
            y: 4
        )
    }

    private func sectionHeader(
        _ title: String,
        subtitle: String,
        systemImage: String
    ) -> some View {
        HStack(
            alignment: .center,
            spacing: 10
        ) {
            if isEnglish {
                headerTextBlock(
                    title: title,
                    subtitle: subtitle
                )

                sectionHeaderIcon(
                    systemImage: systemImage
                )
            } else {
                headerTextBlock(
                    title: title,
                    subtitle: subtitle
                )

                sectionHeaderIcon(
                    systemImage: systemImage
                )
            }
        }
        .environment(
            \.layoutDirection,
            .leftToRight
        )
    }

    private func headerTextBlock(
        title: String,
        subtitle: String
    ) -> some View {
        VStack(
            alignment:
                isEnglish
                ? .leading
                : .trailing,
            spacing: 3
        ) {
            Text(title)
                .kmiFont(
                    size: 17,
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

            Text(subtitle)
                .kmiFont(
                    size: 12,
                    weight: .semibold
                )
                .foregroundStyle(summaryTextMuted)
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
        }
    }

    private func sectionHeaderIcon(
        systemImage: String
    ) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: 0xFF22D3EE),
                            Color(hex: 0xFF0EA5E9),
                            Color(hex: 0xFF1E3A8A)
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 34
                    )
                )
                .frame(
                    width: 42,
                    height: 42
                )

            Image(systemName: systemImage)
                .kmiFont(
                    size: 18,
                    weight: .black
                )
                .foregroundStyle(.white)
        }
        .shadow(
            color: summaryPrimary.opacity(0.20),
            radius: 5,
            x: 0,
            y: 3
        )
        .accessibilityHidden(true)
    }

    private func formattedDate(
        _ iso: String
    ) -> String {
        let input = DateFormatter()
        input.locale =
            Locale(identifier: "en_US_POSIX")
        input.calendar =
            Calendar(identifier: .gregorian)
        input.dateFormat = "yyyy-MM-dd"
        input.isLenient = false

        guard let date = input.date(from: iso) else {
            return iso
        }

        let output = DateFormatter()
        output.locale =
            Locale(
                identifier:
                    isEnglish
                    ? "en_US"
                    : "he_IL"
            )
        output.calendar =
            Calendar(identifier: .gregorian)
        output.dateFormat =
            "EEEE, d MMM yyyy"

        return output.string(from: date)
    }

    private func dateComponents(from iso: String) -> DateComponents {
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: iso) else { return DateComponents() }
        return Calendar.current.dateComponents([.year, .month, .day], from: date)
    }
}
