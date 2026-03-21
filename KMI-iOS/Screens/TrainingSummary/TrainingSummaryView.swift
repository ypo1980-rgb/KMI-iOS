import SwiftUI
import Shared

struct TrainingSummaryView: View {
    @StateObject private var vm: TrainingSummaryViewModel
    @State private var showAddExercisesSheet = false
    @State private var toastMessage: String?
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

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
                    Color(red: 0.03, green: 0.06, blue: 0.12),
                    Color(red: 0.07, green: 0.13, blue: 0.24),
                    Color(red: 0.10, green: 0.22, blue: 0.39)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    titleCard
                    trainingInfoCard
                    addExercisesCard

                    if !selectedExercises.isEmpty {
                        selectedExercisesCard
                    }

                    notesCard
                    actionsCard
                }
                .padding(12)
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
        .navigationTitle("סיכום אימון")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddExercisesSheet) {
            TrainingSummaryExercisePickerSheet(
                vm: vm,
                initialBelt: vm.state.selectedBelt
            ) {
                showAddExercisesSheet = false
            }
        }
        .sheet(isPresented: $showShareSheet) {
            KmiSystemShareSheet(items: shareItems)
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
            let comps = dateComponents(from: vm.state.dateIso)
            if let year = comps.year, let month = comps.month {
                vm.loadSummaryDaysForMonth(year: year, month1to12: month)
            }
        }
    }

    private var selectedExercises: [SelectedExerciseUi] {
        vm.state.selected.values.sorted { $0.name < $1.name }
    }

    private var titleCard: some View {
        card {
            HStack {
                Circle()
                    .fill(.cyan.opacity(0.9))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: "note.text")
                            .foregroundStyle(.white)
                    )

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("סיכום אימון")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)

                    Text(vm.state.isCoach ? "מצב מאמן" : "מצב מתאמן")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
        }
    }

    private var trainingInfoCard: some View {
        card {
            sectionHeader("פרטי האימון", subtitle: formattedDate(vm.state.dateIso))

            TextField("תאריך (yyyy-MM-dd)", text: Binding(
                get: { vm.state.dateIso },
                set: { vm.setDateIso($0) }
            ))
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)

            TextField("סניף", text: Binding(
                get: { vm.state.branchName },
                set: { vm.setBranchName($0) }
            ))
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)

            TextField("מאמן", text: Binding(
                get: { vm.state.coachName },
                set: { vm.setCoachName($0) }
            ))
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)

            TextField("קבוצה", text: Binding(
                get: { vm.state.groupKey },
                set: { vm.setGroupKey($0) }
            ))
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)

            if !vm.state.summaryDaysInCalendarMonth.isEmpty {
                Text("בחודש הנוכחי קיימים \(vm.state.summaryDaysInCalendarMonth.count) ימים עם סיכום שמור")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var addExercisesCard: some View {
        card {
            sectionHeader("הוספת תרגילים", subtitle: "בחר תרגילים שבוצעו באימון")

            HStack {
                Text(vm.state.selectedBelt.heb)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)

                Spacer()

                Text("חגורה")
                    .foregroundStyle(.white.opacity(0.78))
            }

            Text(
                vm.state.selected.isEmpty
                ? "עדיין לא נוספו תרגילים לאימון הזה"
                : "נוספו כבר \(vm.state.selected.count) תרגילים"
            )
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.78))
            .frame(maxWidth: .infinity, alignment: .trailing)

            Button {
                showAddExercisesSheet = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("הוסף תרגילים")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var selectedExercisesCard: some View {
        card {
            sectionHeader("התרגילים שנוספו", subtitle: "ניהול, הערות ועבודה בבית")

            ForEach(selectedExercises) { item in
                exerciseEditor(item)
                if item.id != selectedExercises.last?.id {
                    Divider().overlay(.white.opacity(0.15))
                }
            }
        }
    }

    private var notesCard: some View {
        card {
            sectionHeader(
                "סיכום כללי",
                subtitle: vm.state.isCoach
                    ? "דגשים מקצועיים, ביצוע ומה לשפר"
                    : "איך היה האימון, תחושות ומה לשפר"
            )

            TextEditor(text: Binding(
                get: { vm.state.notes },
                set: { vm.setNotes($0) }
            ))
            .frame(minHeight: 160)
            .padding(8)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(.white)
        }
    }

    private var actionsCard: some View {
        card {
            sectionHeader("פעולות", subtitle: "שמירה ושיתוף של סיכום האימון")

            HStack(spacing: 10) {
                Button {
                    shareSummary()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("שתף")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    vm.save()
                } label: {
                    Text(vm.state.isSaving ? "שומר..." : "שמירת סיכום האימון")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.state.isSaving)
            }
        }
    }

    private func exerciseEditor(_ item: SelectedExerciseUi) -> some View {
        VStack(alignment: .trailing, spacing: 10) {
            HStack {
                Button {
                    vm.removeExercise(item.exerciseId)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(item.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Text(item.topic)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            VStack(alignment: .trailing, spacing: 8) {
                Text("רמת קושי")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(0...10, id: \.self) { value in
                            Button {
                                vm.setDifficulty(
                                    item.exerciseId,
                                    difficulty: item.difficulty == value ? nil : value
                                )
                            } label: {
                                Text("\(value)")
                                    .font(.system(size: 13, weight: .bold))
                                    .frame(width: 34, height: 34)
                                    .background(item.difficulty == value ? Color.cyan.opacity(0.9) : Color.white.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Toggle(
                isOn: Binding(
                    get: { item.homePractice },
                    set: { vm.setHomePractice(item.exerciseId, homePractice: $0) }
                )
            ) {
                Text("סמן לעבודה בבית")
                    .foregroundStyle(.white)
            }
            .tint(.cyan)

            TextField(
                "דגשים והערות לתרגיל",
                text: Binding(
                    get: { item.highlight },
                    set: { vm.setHighlight(item.exerciseId, highlight: $0) }
                ),
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func shareSummary() {
        let text = vm.state.shareText
        shareItems = [text]
        showShareSheet = true
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 12, content: content)
            .padding(14)
            .background(Color.white.opacity(0.09))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(title)
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .trailing)
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
