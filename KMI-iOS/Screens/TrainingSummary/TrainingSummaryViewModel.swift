import Foundation
import Combine
import FirebaseFirestore
import Shared

@MainActor
final class TrainingSummaryViewModel: ObservableObject {
    @Published private(set)
    var state: TrainingSummaryUiState

    private let store: TrainingSummaryLocalStore

    @Published private(set) var isLoadingRemoteSummary = false
    @Published private(set) var remoteSummaryLoadFailed = false

    private var editingRemoteSummary: RemoteSummary?
    private var summaryDaysLoadTask: Task<Void, Never>?

    /*
     * נתוני הסניף והמאמן שהתקבלו בעת פתיחת המסך
     * שייכים לתאריך הפתיחה בלבד.
     */
    private let initialDateIso: String
    private let initialBranchName: String
    private let initialCoachName: String

    init(
        store: TrainingSummaryLocalStore? = nil,
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

        self.store = store ?? TrainingSummaryLocalStore.shared

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

        guard !state.isSaving, state.dateIso != cleanDate else {
            return
        }

        editingRemoteSummary = nil
        isLoadingRemoteSummary = false
        remoteSummaryLoadFailed = false
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

    private static func summaryCollection(
        ownerUid: String,
        role: SummaryAuthorRole
    ) -> CollectionReference {
        Firestore.firestore()
            .collection("users")
            .document(ownerUid)
            .collection("training_summaries_\(role.rawValue)")
    }

    func loadSummaryDaysForMonth(year: Int, month1to12: Int) {
        summaryDaysLoadTask?.cancel()
        summaryDaysLoadTask = nil

        let uid = state.ownerUid.trimmed()
        let role = state.ownerRole

        guard !uid.isEmpty,
              (1...12).contains(month1to12),
              let start = Self.makeDate(
                  year: year,
                  month: month1to12,
                  day: 1
              ),
              let end = ShabbatHolidayCheckerIOS.calendar.date(
                  byAdding: .month,
                  value: 1,
                  to: start
              )
        else {
            state.summaryDaysInCalendarMonth = []
            return
        }

        let startIso = Self.isoString(start)
        let endIsoExclusive = Self.isoString(end)
        let localDates = store.listDatesForOwnerBetween(
            ownerUid: uid,
            role: role,
            startIso: startIso,
            endIsoExclusive: endIsoExclusive
        )
        state.summaryDaysInCalendarMonth = localDates

        summaryDaysLoadTask = Task { @MainActor [weak self] in
            do {
                let snapshot = try await Self.summaryCollection(
                    ownerUid: uid,
                    role: role
                )
                .whereField("dateIso", isGreaterThanOrEqualTo: startIso)
                .whereField("dateIso", isLessThan: endIsoExclusive)
                .getDocuments()

                guard !Task.isCancelled,
                      let self,
                      self.state.ownerUid.trimmed() == uid,
                      self.state.ownerRole == role else { return }

                let remoteDates = snapshot.documents.compactMap { document in
                    Self.normalizedIsoOrNil(
                        document.data()["dateIso"] as? String ?? ""
                    )
                }

                self.state.summaryDaysInCalendarMonth = localDates.union(remoteDates)
            } catch {
                // Local dates remain visible when Firestore is unavailable.
            }
        }
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

    func setIncludeExplanation(_ exerciseId: String, includeExplanation: Bool) {
        guard var item = state.selected[exerciseId] else { return }
        item.includeExplanation = includeExplanation
        state.selected[exerciseId] = item
    }

    func setHomePractice(_ exerciseId: String, homePractice: Bool) {
        guard var item = state.selected[exerciseId] else { return }
        item.homePractice = homePractice
        state.selected[exerciseId] = item
    }

    func save(onSaved: (() -> Void)? = nil) {
        guard !state.isSaving,
              !isLoadingRemoteSummary,
              !remoteSummaryLoadFailed else {
            return
        }

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
                            $0.homePractice,
                        includeExplanation:
                            $0.includeExplanation
                    )
                },
            notes:
                state.notes.trimmed(),
            createdAtMs: 0,
            updatedAtMs: 0
        )

        let existingDocument = editingRemoteSummary.flatMap { remote in
            remote.entity.dateIso == cleanDate ? remote.document : nil
        }

        Task { @MainActor in
            await saveRemoteSummary(
                model,
                existingDocument: existingDocument,
                onSaved: onSaved
            )
        }
    }

    private func saveRemoteSummary(
        _ model: TrainingSummaryEntity,
        existingDocument: DocumentReference?,
        onSaved: (() -> Void)?
    ) async {
        defer { state.isSaving = false }

        let exercises: [[String: Any]] = model.exercises.map { exercise in
            var fields: [String: Any] = [
                "exerciseId": exercise.exerciseId,
                "name": exercise.name,
                "topic": exercise.topic,
                "highlight": exercise.highlight,
                "homePractice": exercise.homePractice,
                "includeExplanation": exercise.includeExplanation ?? false
            ]

            if let difficulty = exercise.difficulty {
                fields["difficulty"] = difficulty
            }

            return fields
        }

        let now = Int64(Date().timeIntervalSince1970 * 1_000)
        var fields: [String: Any] = [
            "branchId": model.branchId,
            "branchName": model.branchName,
            "coachUid": model.coachUid,
            "coachName": model.coachName,
            "groupKey": model.groupKey,
            "exercises": exercises,
            "notes": model.notes,
            "updatedAtMs": now
        ]

        do {
            if let existingDocument {
                try await existingDocument.updateData(fields)
            } else {
                let document = Self.summaryCollection(
                    ownerUid: model.ownerUid,
                    role: model.ownerRole
                )
                .document(model.dateIso)

                fields["id"] = document.documentID
                fields["ownerUid"] = model.ownerUid
                fields["ownerRole"] = model.ownerRole.rawValue
                fields["dateIso"] = model.dateIso
                fields["createdAtMs"] = now

                try await document.setData(fields, merge: true)
            }
        } catch {
            publishSaveResult(
                message: localizedText(
                    hebrew: "לא ניתן לאשר את שמירת הסיכום. נסה שוב.",
                    english: "Could not confirm that the summary was saved. Please try again."
                ),
                isError: true
            )
            return
        }

        store.addMarkedDay(
            ownerUid: model.ownerUid,
            role: model.ownerRole,
            dateIso: model.dateIso
        )

        let components = Self.dateComponents(fromIso: model.dateIso)
        if let year = components.year, let month = components.month {
            loadSummaryDaysForMonth(year: year, month1to12: month)
        }

        publishSaveResult(
            message: localizedText(
                hebrew: "✅ הסיכום נשמר",
                english: "✅ Summary saved"
            ),
            isError: false
        )
        onSaved?()
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

    struct RemoteSummary {
        let entity: TrainingSummaryEntity
        let document: DocumentReference
    }

    func prepareSummaryForEditing(dateIso: String) async {
        guard !Task.isCancelled,
              !state.isSaving,
              dateIso == state.dateIso,
              !state.ownerUid.isEmpty else {
            return
        }

        isLoadingRemoteSummary = true
        remoteSummaryLoadFailed = false

        defer {
            if state.dateIso == dateIso, !Task.isCancelled {
                isLoadingRemoteSummary = false
            }
        }

        do {
            let remote = try await Self.loadRemoteSummary(
                ownerUid: state.ownerUid,
                ownerRole: state.ownerRole,
                dateIso: dateIso
            )

            guard !Task.isCancelled, state.dateIso == dateIso else { return }
            guard let remote else { return }

            editingRemoteSummary = remote
            applySavedSummary(remote.entity)
        } catch {
            guard !Task.isCancelled, state.dateIso == dateIso else { return }
            remoteSummaryLoadFailed = true
        }
    }

    private func applySavedSummary(_ saved: TrainingSummaryEntity) {
        state.branchId = saved.branchId
        state.branchName = saved.branchName
        state.coachUid = saved.coachUid
        state.coachName = saved.coachName
        state.groupKey = saved.groupKey
        state.notes = saved.notes
        state.selected = Dictionary(
            saved.exercises.map { exercise in
                (
                    exercise.exerciseId,
                    SelectedExerciseUi(
                        exerciseId: exercise.exerciseId,
                        name: exercise.name,
                        topic: exercise.topic,
                        difficulty: exercise.difficulty,
                        highlight: exercise.highlight,
                        homePractice: exercise.homePractice,
                        includeExplanation: exercise.includeExplanation ?? false
                    )
                )
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    static func loadRemoteSummary(
        ownerUid: String,
        ownerRole: SummaryAuthorRole,
        dateIso: String
    ) async throws -> RemoteSummary? {
        let uid = ownerUid.trimmed()
        guard !uid.isEmpty, let date = normalizedIsoOrNil(dateIso) else {
            return nil
        }

        let collection = summaryCollection(ownerUid: uid, role: ownerRole)

        let matching = try await collection
            .whereField("dateIso", isEqualTo: date)
            .getDocuments()

        var documents: [DocumentSnapshot] = matching.documents.map { $0 }
        if !documents.contains(where: { $0.documentID == date }) {
            let direct = try await collection.document(date).getDocument()
            if direct.exists {
                documents.append(direct)
            }
        }

        return documents.compactMap { document -> RemoteSummary? in
            guard let data = document.data() else { return nil }

            let storedDate = (data["dateIso"] as? String ?? "").trimmed()
            guard storedDate == date ||
                    (storedDate.isEmpty && document.documentID == date) else {
                return nil
            }

            let rawExercises = data["exercises"] as? [[String: Any]] ?? []
            var seenExerciseIDs = Set<String>()
            let exercises = rawExercises.compactMap { exercise -> TrainingSummaryExerciseEntity? in
                let id = (exercise["exerciseId"] as? String ?? "").trimmed()
                guard !id.isEmpty, seenExerciseIDs.insert(id).inserted else {
                    return nil
                }

                return TrainingSummaryExerciseEntity(
                    exerciseId: id,
                    name: exercise["name"] as? String ?? "",
                    topic: exercise["topic"] as? String ?? "",
                    difficulty: (exercise["difficulty"] as? NSNumber)?.intValue,
                    highlight: exercise["highlight"] as? String ?? "",
                    homePractice: exercise["homePractice"] as? Bool ?? false,
                    includeExplanation: exercise["includeExplanation"] as? Bool ?? false
                )
            }

            let entity = TrainingSummaryEntity(
                id: document.documentID,
                ownerUid: uid,
                ownerRole: ownerRole,
                dateIso: date,
                branchId: data["branchId"] as? String ?? "",
                branchName: data["branchName"] as? String ?? "",
                coachUid: data["coachUid"] as? String ?? "",
                coachName: data["coachName"] as? String ?? "",
                groupKey: data["groupKey"] as? String ?? "",
                exercises: exercises,
                notes: data["notes"] as? String ?? "",
                createdAtMs: (data["createdAtMs"] as? NSNumber)?.int64Value ?? 0,
                updatedAtMs: (data["updatedAtMs"] as? NSNumber)?.int64Value ?? 0
            )

            return RemoteSummary(entity: entity, document: document.reference)
        }
        .max { left, right in
            let leftRank = (
                left.entity.exercises.isEmpty ? 0 : 1,
                left.entity.notes.trimmed().isEmpty ? 0 : 1,
                left.entity.updatedAtMs
            )
            let rightRank = (
                right.entity.exercises.isEmpty ? 0 : 1,
                right.entity.notes.trimmed().isEmpty ? 0 : 1,
                right.entity.updatedAtMs
            )
            return leftRank < rightRank
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
            applySavedSummary(saved)
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
            ShabbatHolidayCheckerIOS.calendar
        formatter.timeZone =
            ShabbatHolidayCheckerIOS.timeZone
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
        isoDateFormatter().string(from: date)
    }

    private static func makeDate(
        year: Int,
        month: Int,
        day: Int
    ) -> Date? {
        ShabbatHolidayCheckerIOS.calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day
            )
        )
    }

    private static func dateComponents(
        fromIso iso: String
    ) -> DateComponents {
        guard let date = isoDateFormatter().date(from: iso) else {
            return DateComponents()
        }

        return ShabbatHolidayCheckerIOS.calendar.dateComponents(
            [.year, .month, .day],
            from: date
        )
    }

    private static func isoDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = ShabbatHolidayCheckerIOS.calendar
        formatter.timeZone = ShabbatHolidayCheckerIOS.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
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
