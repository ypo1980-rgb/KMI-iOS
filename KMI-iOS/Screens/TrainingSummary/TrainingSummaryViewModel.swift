import Foundation
import Combine
import Shared

@MainActor
final class TrainingSummaryViewModel: ObservableObject {
    @Published private(set)
    var state: TrainingSummaryUiState

    private let store: TrainingSummaryLocalStore

    /*
     * נתוני הסניף והמאמן שהתקבלו בעת פתיחת המסך
     * שייכים לתאריך הפתיחה בלבד.
     */
    private let initialDateIso: String
    private let initialBranchName: String
    private let initialCoachName: String

    init(
        store: TrainingSummaryLocalStore = .shared,
        ownerUid: String,
        ownerRole: SummaryAuthorRole,
        initialBelt: Belt = .green,
        pickedDateIso: String? = nil,
        initialBranchName: String = "",
        initialCoachName: String = ""
    ) {
        let resolvedDateIso =
            Self.normalizedIsoOrNil(
                pickedDateIso
            ) ?? Self.todayIso()

        let cleanBranchName =
            initialBranchName.trimmed()

        let cleanCoachName =
            initialCoachName.trimmed()

        self.store = store
        self.initialDateIso =
            resolvedDateIso
        self.initialBranchName =
            cleanBranchName
        self.initialCoachName =
            cleanCoachName

        self.state = TrainingSummaryUiState(
            isCoach:
                ownerRole == .coach,
            ownerUid:
                ownerUid.trimmed(),
            ownerRole:
                ownerRole,
            dateIso:
                resolvedDateIso,
            branchName:
                cleanBranchName,
            coachName:
                cleanCoachName,
            selectedBelt:
                initialBelt
        )

        loadExistingSummaryForCurrentDate()
        resolveTrainingContextForCurrentDate()
    }

    func setDateIso(_ value: String) {
        guard
            let cleanDate =
                Self.normalizedIsoOrNil(value)
        else {
            return
        }

        guard state.dateIso != cleanDate else {
            return
        }

        state.dateIso = cleanDate

        /*
         * מונע הצגת פרטי אימון השייכים לתאריך הקודם
         * בזמן טעינת הסיכום של התאריך החדש.
         */
        state.branchId = ""
        state.branchName = ""
        state.coachUid = ""
        state.coachName = ""
        state.groupKey = ""
        state.selected = [:]
        state.notes = ""

        loadExistingSummaryForCurrentDate()
        resolveTrainingContextForCurrentDate()
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
        guard
            let cleanDate =
                Self.normalizedIsoOrNil(
                    state.dateIso
                )
        else {
            publishSaveResult(
                message: localizedText(
                    hebrew:
                        "לא ניתן לשמור ללא תאריך אימון",
                    english:
                        "A training date is required"
                ),
                isError: true
            )
            return
        }

        guard !state.ownerUid.trimmed().isEmpty else {
            publishSaveResult(
                message: localizedText(
                    hebrew:
                        "לא ניתן לזהות את המשתמש",
                    english:
                        "The user could not be identified"
                ),
                isError: true
            )
            return
        }

        state.dateIso = cleanDate
        state.isSaving = true

        let sortedExercises =
            state.selected.values
                .sorted {
                    $0.name
                        .localizedCaseInsensitiveCompare(
                            $1.name
                        ) == .orderedAscending
                }

        let model = TrainingSummaryEntity(
            id: cleanDate,
            ownerUid:
                state.ownerUid.trimmed(),
            ownerRole:
                state.ownerRole,
            dateIso:
                cleanDate,
            branchId:
                state.branchId.trimmed(),
            branchName:
                state.branchName.trimmed(),
            coachUid:
                state.coachUid.trimmed(),
            coachName:
                state.coachName.trimmed(),
            groupKey:
                state.groupKey.trimmed(),
            exercises:
                sortedExercises.map {
                    TrainingSummaryExerciseEntity(
                        exerciseId:
                            $0.exerciseId,
                        name:
                            $0.name,
                        topic:
                            $0.topic,
                        difficulty:
                            $0.difficulty,
                        highlight:
                            $0.highlight.trimmed(),
                        homePractice:
                            $0.homePractice
                    )
                },
            notes:
                state.notes.trimmed(),
            createdAtMs: 0,
            updatedAtMs: 0
        )

        store.saveForOwner(
            ownerUid:
                state.ownerUid.trimmed(),
            role:
                state.ownerRole,
            summary:
                model
        )

        state.isSaving = false

        publishSaveResult(
            message: localizedText(
                hebrew: "✅ הסיכום נשמר",
                english: "✅ Summary saved"
            ),
            isError: false
        )

        let components =
            Self.dateComponents(
                fromIso: cleanDate
            )

        if
            let year = components.year,
            let month = components.month {
            loadSummaryDaysForMonth(
                year: year,
                month1to12: month
            )
        }
    }

    private func resolveTrainingContextForCurrentDate() {
        let defaults = UserDefaults.standard

        func clean(_ value: String?) -> String {
            value?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                ) ?? ""
        }

        func splitStoredValues(
            _ rawValue: String
        ) -> [String] {
            rawValue
                .replacingOccurrences(
                    of: "[",
                    with: ""
                )
                .replacingOccurrences(
                    of: "]",
                    with: ""
                )
                .split { character in
                    character == "," ||
                    character == ";" ||
                    character == "|" ||
                    character == "\n"
                }
                .map {
                    String($0)
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        .trimmingCharacters(
                            in: CharacterSet(
                                charactersIn: "\""
                            )
                        )
                }
                .filter { !$0.isEmpty }
        }

        func storedValues(
            for keys: [String]
        ) -> [String] {
            var result: [String] = []

            for key in keys {
                if let array =
                    defaults.array(forKey: key) {
                    result +=
                        array
                            .map {
                                "\($0)"
                                    .trimmingCharacters(
                                        in:
                                            .whitespacesAndNewlines
                                    )
                            }
                            .filter { !$0.isEmpty }
                }

                if let rawValue =
                    defaults.string(forKey: key) {
                    result +=
                        splitStoredValues(rawValue)
                }
            }

            return result
        }

        func uniqueValues(
            _ values: [String]
        ) -> [String] {
            var seen = Set<String>()

            return values
                .map {
                    $0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                }
                .filter { !$0.isEmpty }
                .filter { value in
                    let normalized =
                        value
                            .lowercased()
                            .replacingOccurrences(
                                of: "\\s+",
                                with: " ",
                                options:
                                    .regularExpression
                            )
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )

                    guard
                        !seen.contains(normalized)
                    else {
                        return false
                    }

                    seen.insert(normalized)
                    return true
                }
        }

        var preferredBranches: [String] = [
            clean(state.branchName),
            clean(initialBranchName)
        ]

        preferredBranches += storedValues(
            for: [
                "branches",
                "branches_json",
                "selected_branches",
                "active_branch",
                "activeBranch",
                "branch",
                "kmi.user.branch",
                "branch2",
                "branch3"
            ]
        )

        preferredBranches =
            uniqueValues(preferredBranches)

        var preferredGroups: [String] = [
            clean(state.groupKey)
        ]

        preferredGroups += storedValues(
            for: [
                "groups",
                "groups_json",
                "selected_groups",
                "active_group",
                "activeGroup",
                "group",
                "groupKey",
                "age_group",
                "age_groups",
                "kmi.user.group"
            ]
        )

        preferredGroups =
            uniqueValues(preferredGroups)

        guard
            !preferredBranches.isEmpty,
            let context =
                TrainingCatalogIOS
                    .trainingSummaryContext(
                        dateIso:
                            state.dateIso,
                        preferredBranches:
                            preferredBranches,
                        preferredGroups:
                            preferredGroups
                    )
        else {
            return
        }

        /*
         * מידע שכבר נשמר בסיכום קודם מקבל עדיפות.
         * הקטלוג משלים רק שדות חסרים.
         */
        if state.branchName.trimmed().isEmpty {
            state.branchName =
                context.branchName
        }

        if state.coachName.trimmed().isEmpty {
            state.coachName =
                context.coachName
        }

        if state.groupKey.trimmed().isEmpty {
            state.groupKey =
                context.groupKey
        }
    }
        
    private func publishSaveResult(
        message: String,
        isError: Bool
    ) {
        state.lastSaveMsg = message
        state.lastSaveWasError = isError
        state.saveEventId =
            Int64(
                Date()
                    .timeIntervalSince1970 *
                1_000
            )
    }

    private func localizedText(
        hebrew: String,
        english: String
    ) -> String {
        let defaults =
            UserDefaults.standard

        let candidates = [
            defaults.string(
                forKey: "kmi_app_language"
            ),
            defaults.string(
                forKey: "app_language"
            ),
            defaults.string(
                forKey: "initial_language_code"
            ),
            defaults.string(
                forKey: "selected_language_code"
            )
        ]
        .compactMap { $0 }
        .map {
            $0
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()
        }

        let isEnglish =
            candidates.contains("en") ||
            candidates.contains("english")

        return isEnglish
            ? english
            : hebrew
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
            state.branchId = ""
            state.coachUid = ""
            state.groupKey = ""
            state.selected = [:]
            state.notes = ""

            /*
             * פרטי הפתיחה תקפים רק לתאריך שעמו
             * המסך נפתח מלכתחילה.
             */
            if summaryId == initialDateIso {
                state.branchName =
                    initialBranchName
                state.coachName =
                    initialCoachName
            } else {
                state.branchName = ""
                state.coachName = ""
            }
        }
    }

    private static func todayIso() -> String {
        isoString(Date())
    }

    private static func normalizedIsoOrNil(
        _ rawValue: String?
    ) -> String? {
        let cleanValue =
            rawValue?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                ) ?? ""

        guard
            !cleanValue.isEmpty,
            cleanValue != "{date}",
            cleanValue.lowercased() != "null"
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
            let date =
                formatter.date(
                    from: cleanValue
                ),
            formatter.string(from: date) ==
                cleanValue
        else {
            return nil
        }

        return cleanValue
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
