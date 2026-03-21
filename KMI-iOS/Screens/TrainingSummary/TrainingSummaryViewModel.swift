import Foundation
import Combine
import Shared

@MainActor
final class TrainingSummaryViewModel: ObservableObject {
    @Published private(set) var state: TrainingSummaryUiState

    private let store: TrainingSummaryLocalStore

    init(
        store: TrainingSummaryLocalStore = .shared,
        ownerUid: String,
        ownerRole: SummaryAuthorRole,
        initialBelt: Belt = .green,
        pickedDateIso: String? = nil,
        initialBranchName: String = "",
        initialCoachName: String = ""
    ) {
        self.store = store
        self.state = TrainingSummaryUiState(
            isCoach: ownerRole == .coach,
            ownerUid: ownerUid,
            ownerRole: ownerRole,
            dateIso: pickedDateIso?.trimmed().nonEmpty ?? Self.todayIso(),
            branchName: initialBranchName,
            coachName: initialCoachName,
            selectedBelt: initialBelt
        )

        loadExistingSummaryForCurrentDate()
    }

    func setDateIso(_ value: String) {
        state.dateIso = value.trimmed()
        loadExistingSummaryForCurrentDate()
    }

    func setBranchName(_ value: String) {
        state.branchName = value.trimmed()
    }

    func setCoachName(_ value: String) {
        state.coachName = value.trimmed()
    }

    func setGroupKey(_ value: String) {
        state.groupKey = value.trimmed()
    }

    func setNotes(_ value: String) {
        state.notes = value
    }

    func setSearchQuery(_ value: String) {
        state.searchQuery = value
    }

    func setSelectedBelt(_ belt: Belt) {
        state.selectedBelt = belt
    }

    func loadSummaryDaysForMonth(year: Int, month1to12: Int) {
        guard
            let start = Self.makeDate(year: year, month: month1to12, day: 1),
            let end = Calendar.current.date(byAdding: .month, value: 1, to: start)
        else {
            state.summaryDaysInCalendarMonth = []
            return
        }

        state.summaryDaysInCalendarMonth = store.listDatesForOwnerBetween(
            ownerUid: state.ownerUid,
            role: state.ownerRole,
            startIso: Self.isoString(start),
            endIsoExclusive: Self.isoString(end)
        )
    }

    func toggleExercise(_ item: ExercisePickItem) {
        if state.selected[item.exerciseId] != nil {
            state.selected.removeValue(forKey: item.exerciseId)
        } else {
            state.selected[item.exerciseId] = SelectedExerciseUi(
                exerciseId: item.exerciseId,
                name: item.name,
                topic: item.topic
            )
        }
    }

    func removeExercise(_ exerciseId: String) {
        state.selected.removeValue(forKey: exerciseId)
    }

    func setDifficulty(_ exerciseId: String, difficulty: Int?) {
        guard var item = state.selected[exerciseId] else { return }
        item.difficulty = difficulty
        state.selected[exerciseId] = item
    }

    func setHighlight(_ exerciseId: String, highlight: String) {
        guard var item = state.selected[exerciseId] else { return }
        item.highlight = highlight
        state.selected[exerciseId] = item
    }

    func setHomePractice(_ exerciseId: String, homePractice: Bool) {
        guard var item = state.selected[exerciseId] else { return }
        item.homePractice = homePractice
        state.selected[exerciseId] = item
    }

    func save() {
        state.isSaving = true

        let model = TrainingSummaryEntity(
            id: state.dateIso,
            ownerUid: state.ownerUid,
            ownerRole: state.ownerRole,
            dateIso: state.dateIso,
            branchId: state.branchId,
            branchName: state.branchName,
            coachUid: state.coachUid,
            coachName: state.coachName,
            groupKey: state.groupKey,
            exercises: state.selected.values
                .sorted(by: { $0.name < $1.name })
                .map {
                    TrainingSummaryExerciseEntity(
                        exerciseId: $0.exerciseId,
                        name: $0.name,
                        topic: $0.topic,
                        difficulty: $0.difficulty,
                        highlight: $0.highlight,
                        homePractice: $0.homePractice
                    )
                },
            notes: state.notes,
            createdAtMs: 0,
            updatedAtMs: 0
        )

        store.saveForOwner(
            ownerUid: state.ownerUid,
            role: state.ownerRole,
            summary: model
        )

        state.isSaving = false
        state.lastSaveMsg = "✅ הסיכום נשמר"
        state.lastSaveWasError = false
        state.saveEventId = Int64(Date().timeIntervalSince1970 * 1000)

        let comps = Self.dateComponents(fromIso: state.dateIso)
        if let year = comps.year, let month = comps.month {
            loadSummaryDaysForMonth(year: year, month1to12: month)
        }
    }

    private func loadExistingSummaryForCurrentDate() {
        let summaryId = state.dateIso.trimmed()
        guard !summaryId.isEmpty else { return }

        if let saved = store.loadForOwner(
            ownerUid: state.ownerUid,
            role: state.ownerRole,
            summaryId: summaryId
        ) {
            state.branchId = saved.branchId
            state.branchName = saved.branchName
            state.coachUid = saved.coachUid
            state.coachName = saved.coachName
            state.groupKey = saved.groupKey
            state.notes = saved.notes
            state.selected = Dictionary(
                uniqueKeysWithValues: saved.exercises.map {
                    (
                        $0.exerciseId,
                        SelectedExerciseUi(
                            exerciseId: $0.exerciseId,
                            name: $0.name,
                            topic: $0.topic,
                            difficulty: $0.difficulty,
                            highlight: $0.highlight,
                            homePractice: $0.homePractice
                        )
                    )
                }
            )
        } else {
            state.selected = [:]
            state.notes = ""
        }
    }

    private static func todayIso() -> String {
        isoString(Date())
    }

    private static func isoString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func makeDate(year: Int, month: Int, day: Int) -> Date? {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
    }

    private static func dateComponents(fromIso iso: String) -> DateComponents {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: iso) else { return DateComponents() }
        return Calendar.current.dateComponents([.year, .month, .day], from: date)
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func trimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
