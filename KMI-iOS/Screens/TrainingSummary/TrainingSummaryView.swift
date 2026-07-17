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

    private let summaryBgTop =
        Color(red: 0.97, green: 0.98, blue: 1.00)

    private let summaryBgMiddle =
        Color(red: 0.72, green: 0.87, blue: 0.97)

    private let summaryBgBottom =
        Color(red: 0.02, green: 0.17, blue: 0.29)

    private let summaryCard =
        Color(red: 0.92, green: 0.95, blue: 1.00)

    private let summaryCardInner =
        Color(red: 0.87, green: 0.92, blue: 1.00)

    private let summaryBorder =
        Color(red: 0.85, green: 0.89, blue: 0.96)

    private let summaryDivider =
        Color(red: 0.78, green: 0.84, blue: 0.93)

    private let summaryTextDark =
        Color(red: 0.12, green: 0.16, blue: 0.24)

    private let summaryTextMuted =
        Color(red: 0.37, green: 0.42, blue: 0.50)

    private let summaryPrimary =
        Color(red: 0.05, green: 0.65, blue: 0.91)

    private let summaryPurple =
        Color(red: 0.48, green: 0.34, blue: 0.82)

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
                    summaryBgMiddle,
                    Color(red: 0.12, green: 0.47, blue: 0.71),
                    summaryBgBottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.16),
                        Color.clear,
                        Color.white.opacity(0.08),
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
                        .font(.subheadline.weight(.bold))
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
        vm.state.selected.values.sorted { $0.name < $1.name }
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
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(summaryTextDark)

                    Text(
                        formattedDate(
                            vm.state.dateIso
                        )
                    )
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(summaryTextMuted)
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
                        tr(
                            "שינוי תאריך האימון",
                            "Change training date"
                        )
                    )
                    .font(.subheadline.weight(.heavy))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(summaryPurple)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            VStack(spacing: 7) {
                summaryInfoRow(
                    label: tr("סניף", "Branch"),
                    value:
                        vm.state.branchName.isEmpty
                        ? tr(
                            "לא נמצא סניף",
                            "Branch not found"
                        )
                        : vm.state.branchName
                )

                summaryInfoRow(
                    label: tr("מאמן", "Coach"),
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
                        label: tr(
                            "קבוצה",
                            "Group"
                        ),
                        value: vm.state.groupKey
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

    private func summaryInfoRow(
        label: String,
        value: String
    ) -> some View {
        HStack(spacing: 8) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(summaryTextDark)

            Spacer()

            Text(label)
                .font(.caption.weight(.bold))
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
                tr("הוספת תרגילים", "Add exercises"),
                subtitle: tr(
                    "בחר תרגילים שבוצעו באימון",
                    "Choose exercises performed in training"
                )
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
            .font(.subheadline.weight(.semibold))
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
                )
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
                .font(.caption.weight(.bold))
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
                )
            )

            summarySectionDivider

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
            .frame(minHeight: 160)
            .padding(10)
            .foregroundStyle(summaryTextDark)
            .background(
                Color(
                    red: 0.97,
                    green: 0.98,
                    blue: 1.00
                )
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
                tr("שמירה", "Save"),
                subtitle: tr(
                    "שמור את הסיכום והתרגילים שנוספו לאימון הזה",
                    "Save the summary and exercises added to this training"
                )
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
                    .font(.headline.weight(.bold))
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
                .font(.title3.weight(.heavy))
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
                    .font(.caption.weight(.semibold))
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
                    .font(.system(size: 17, weight: .bold))
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
                        .font(.system(size: 16, weight: .bold))
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
                    .font(.subheadline)
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
                    .font(.caption.weight(.bold))
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
                        Color(
                            red: 0.97,
                            green: 0.98,
                            blue: 1.00
                        )
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
        subtitle: String
    ) -> some View {
        VStack(
            alignment:
                isEnglish ? .leading : .trailing,
            spacing: 4
        ) {
            Text(title)
                .font(.headline.weight(.heavy))
                .foregroundStyle(summaryTextDark)
                .frame(
                    maxWidth: .infinity,
                    alignment: screenAlignment
                )

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(summaryTextMuted)
                .frame(
                    maxWidth: .infinity,
                    alignment: screenAlignment
                )
        }
    }

    private func formattedDate(_ iso: String) -> String {
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd"

        let output = DateFormatter()
        output.locale = Locale(identifier: "he_IL")
        output.dateFormat = "EEEE, d MMM yyyy"

        guard let date = input.date(from: iso) else { return iso }
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
