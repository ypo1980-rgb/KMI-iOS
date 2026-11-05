import Foundation
import Combine
import FirebaseAuth
@MainActor
final class AttendanceViewModel: ObservableObject {
    @Published
    private(set) var state: AttendanceUiState
    @Published
    private(set) var isReportSaved: Bool = false
    private let repository: AttendanceRepository
    private var contextLoadID = UUID()
    private var contextLoadTask: Task<Void, Never>?
    private var monthLoadTask: Task<Void, Never>?
    private var monthLoadID = UUID()
    @Published
    private(set) var isContextLoading = false
    @Published
    private(set) var contextLoadFailed = false
    private var canModifyLoadedContext: Bool {
        !state.isSaving &&
        !isContextLoading &&
        !contextLoadFailed
    }
    func retryLoadingCurrentContext() {
        guard !state.isSaving else {
            return
        }
        reloadCurrentContext()
    }
    @Published
    private(set) var availableBranches: [String] = []
    @Published
    private(set) var availableGroups: [String] = []
    private var allAssignedBranches: [String] = []
    private var assignedGroupsByBranch: [String: Set<String>]?
    private var hasResolvedAssignedBranches = false
    private var pendingAssignments: (
        branches: [String],
        groupsByBranch: [String: [String]]?
    )?
    private var displayedMonthKey: [String]?
    private var needsDefaultGroupSelection = false
    private var preferredDefaultGroup = ""
    func setAssignedBranches(
        _ branches: [String],
        groupsByBranch: [String: [String]]? = nil
    ) {
        var seen = Set<String>()
        let cleanBranches = branches
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter {
                !$0.isEmpty && seen.insert($0).inserted
            }
        // nil preserves compatibility until the screen supplies full assignments.
        // An explicit empty map grants no branch/group options.
        let cleanGroups: [String: Set<String>]? = groupsByBranch.map { assignments in
            var result: [String: Set<String>] = [:]
            for (branch, groups) in assignments {
                let branchKey = branch.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !branchKey.isEmpty else { continue }
                let groupNames = groups
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                result[branchKey, default: []].formUnion(groupNames)
            }
            return result
        }
        /*
         * שינוי שיוכים שמגיע בזמן כתיבה
         * יטופל לאחר סיום הפעולה.
         */
        if state.isSaving {
            pendingAssignments = (
                branches: cleanBranches,
                groupsByBranch: groupsByBranch
            )
            return
        }
        /*
         * חזרה למסך עם אותם שיוכים אינה
         * טוענת מחדש ואינה מוחקת סימונים בעריכה.
         */
        if hasResolvedAssignedBranches,
           Set(cleanBranches) == Set(allAssignedBranches),
           cleanGroups == assignedGroupsByBranch {
            return
        }
        hasResolvedAssignedBranches = true
        allAssignedBranches = cleanBranches
        assignedGroupsByBranch = cleanGroups
        refreshScheduleOptions()
        reloadCurrentContext()
    }
    private func finishSavingOperation() {
        state.isSaving = false
        guard let pending = pendingAssignments else {
            return
        }
        pendingAssignments = nil
        setAssignedBranches(
            pending.branches,
            groupsByBranch: pending.groupsByBranch
        )
    }
    private func hasScheduledTraining(
        branch: String,
        group: String? = nil
    ) -> Bool {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = ShabbatHolidayCheckerIOS.calendar
        formatter.timeZone = ShabbatHolidayCheckerIOS.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let selectedDate = formatter.date(
            from: state.dateIso
        ) else {
            return false
        }
        guard !HolidayCalendarStore.isTrainingCancelled(
            on: selectedDate
        ) else {
            return false
        }
        return TrainingCatalogIOS.trainingSummaryContext(
            dateIso: state.dateIso,
            preferredBranches: [branch],
            preferredGroups: group.map { [$0] } ?? []
        ) != nil
    }
    private func refreshScheduleOptions() {
        availableBranches = allAssignedBranches.filter { branch in
            if let assignedGroupsByBranch {
                let groups = assignedGroupsByBranch[branch] ?? []
                return groups.contains { group in
                    hasScheduledTraining(branch: branch, group: group)
                }
            }
            return hasScheduledTraining(branch: branch)
        }
        let preferredBranch = state.branchName.trimmed()
        state.branchName =
            availableBranches.first {
                $0 == preferredBranch
            }
            ?? availableBranches.first
            ?? ""
        guard !state.branchName.isEmpty else {
            availableGroups = []
            state.groupKey = ""
            needsDefaultGroupSelection = false
            preferredDefaultGroup = ""
            return
        }
        var seenGroups = Set<String>()
        availableGroups = TrainingCatalogIOS
            .groupsFor(branch: state.branchName)
            .map { $0.trimmed() }
            .filter {
                !$0.isEmpty &&
                seenGroups.insert($0).inserted
            }
            .filter { group in
                guard let assignedGroupsByBranch else { return true }
                return assignedGroupsByBranch[state.branchName]?.contains(group) == true
            }
            .filter {
                hasScheduledTraining(
                    branch: state.branchName,
                    group: $0
                )
            }
        let preferredGroup = state.groupKey.trimmed()
        let normalizedPreferredGroup =
            TrainingCatalogIOS.normalizeGroupName(
                preferredGroup
            )
        preferredDefaultGroup = availableGroups.first {
            $0 == preferredGroup ||
            TrainingCatalogIOS.normalizeGroupName($0) == normalizedPreferredGroup
        } ?? ""
        needsDefaultGroupSelection = !availableGroups.isEmpty
        state.groupKey = ""
    }
    private var isEnglish: Bool {
        let defaults = UserDefaults.standard
        let keys = [
            "kmi_app_language",
            "selected_language_code",
            "app_language",
            "initial_language_code",
            "initial_language_selected_code",
            "kmi.language.code"
        ]
        for key in keys {
            let value = (defaults.string(forKey: key) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            switch value {
            case "en", "english":
                return true
            case "he", "hebrew", "עברית":
                return false
            default:
                continue
            }
        }
        return Locale.preferredLanguages.first?
            .lowercased()
            .hasPrefix("en") == true
    }
    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }
    init(
        ownerUid: String,
        initialDateIso: String? = nil,
        initialBranchName: String = "",
        initialGroupKey: String = "",
        initialCoachName: String = "",
        repository: AttendanceRepository? = nil
    ) {
        self.repository = repository ?? .shared
        self.state = AttendanceUiState(
            ownerUid: ownerUid,
            dateIso: initialDateIso?.trimmedNonEmpty ?? Self.todayIso(),
            branchName: initialBranchName,
            groupKey: initialGroupKey,
            coachName: initialCoachName
        )
        reloadCurrentContext()
    }
    func setDateIso(_ value: String) {
        guard !state.isSaving else {
            return
        }
        let clean = value.trimmed()
        guard Self.parsedDate(fromIso: clean) != nil else {
            publishMessage(
                tr(
                    "תאריך האימון אינו תקין",
                    "The training date is invalid"
                ),
                isError: true
            )
            return
        }
        guard !clean.isEmpty,
              clean != state.dateIso else {
            return
        }
        state.dateIso = clean
        refreshScheduleOptions()
        reloadCurrentContext()
        reloadMonthMarkers()
    }
    func setBranchName(_ value: String) {
        guard !state.isSaving else {
            return
        }
        let clean = value.trimmed()
        guard availableBranches.contains(clean),
              clean != state.branchName else {
            return
        }
        state.branchName = clean
        refreshScheduleOptions()
        reloadCurrentContext()
        reloadMonthMarkers()
    }
    func setGroupKey(_ value: String) {
        guard !state.isSaving else {
            return
        }
        let clean = value.trimmed()
        guard availableGroups.contains(clean),
              clean != state.groupKey else {
            return
        }
        needsDefaultGroupSelection = false
        state.groupKey = clean
        reloadCurrentContext()
        reloadMonthMarkers()
    }
    func setCoachName(_ value: String) {
        let clean = value.trimmed()
        state.coachName = clean
    }
    func setAttendanceStatus(memberId: String, status: AttendanceStatus) {
        guard canModifyLoadedContext,
              state.members.contains(where: {
                $0.id == memberId
              }) else {
            return
        }
        let current = state.recordsByMemberId[memberId]
        let updated = AttendanceRecord(
            id: current?.id ?? "\(state.dateIso)_\(memberId)",
            dateIso: state.dateIso,
            memberId: memberId,
            status: status,
            note: current?.note ?? ""
        )
        state.recordsByMemberId[memberId] = updated
    }
    func setAttendanceNote(memberId: String, note: String) {
        guard canModifyLoadedContext,
              state.members.contains(where: {
                $0.id == memberId
              }) else {
            return
        }
        let current = state.recordsByMemberId[memberId]
        let updated = AttendanceRecord(
            id: current?.id ?? "\(state.dateIso)_\(memberId)",
            dateIso: state.dateIso,
            memberId: memberId,
            status: current?.status ?? .unknown,
            note: note
        )
        state.recordsByMemberId[memberId] = updated
    }
    func addMember(
        fullName: String,
        phone: String = "",
        notes: String = "",
        completion: ((Bool) -> Void)? = nil
    ) {
        guard canModifyLoadedContext,
              !state.branchName.trimmed().isEmpty,
              !state.groupKey.trimmed().isEmpty else {
            completion?(false)
            return
        }
        let cleanName = fullName.trimmed()
        guard !cleanName.isEmpty else {
            publishMessage(
                tr(
                    "יש להזין שם מתאמן",
                    "Please enter a trainee name"
                ),
                isError: true
            )
            completion?(false)
            return
        }
        guard !state.members.contains(where: {
            $0.fullName.trimmed().lowercased()
                == cleanName.lowercased()
        }) else {
            publishMessage(
                tr(
                    "המתאמן כבר קיים ברשימה",
                    "This trainee already exists in the list"
                ),
                isError: true
            )
            completion?(false)
            return
        }
        let ownerUid = state.ownerUid
        let branchName = state.branchName.trimmed()
        let groupKey = state.groupKey.trimmed()
        let dateIso = state.dateIso
        let loadID = contextLoadID
        let cleanPhone = phone.trimmed()
        let cleanNotes = notes.trimmed()
        guard Auth.auth().currentUser?.uid == ownerUid else {
            completion?(false)
            return
        }
        state.isSaving = true
        Task { @MainActor in
            @MainActor
            func isCurrentContext() -> Bool {
                !Task.isCancelled &&
                self.contextLoadID == loadID &&
                self.state.ownerUid == ownerUid &&
                self.state.branchName == branchName &&
                self.state.groupKey == groupKey &&
                self.state.dateIso == dateIso &&
                Auth.auth().currentUser?.uid == ownerUid
            }
            defer {
                self.finishSavingOperation()
            }
            do {
                /*
                 * יצירת המזהה והשמירה מתבצעות
                 * ב־Repository לפי מבנה Android.
                 */
                let member = try await self.repository
                    .addManualMemberToFirestore(
                        ownerUid: ownerUid,
                        branchName: branchName,
                        groupKey: groupKey,
                        fullName: cleanName,
                        phone: cleanPhone,
                        notes: cleanNotes
                    )
                guard isCurrentContext() else {
                    completion?(false)
                    return
                }
                /*
                 * מעדכנים לפי המזהה שהשרת החזיר.
                 * אין יצירת UUID מקומי.
                 */
                if let index = self.state.members.firstIndex(
                    where: { $0.id == member.id }
                ) {
                    self.state.members[index] = member
                } else {
                    self.state.members.append(member)
                }
                self.state.members.sort {
                    $0.fullName.localizedCaseInsensitiveCompare(
                        $1.fullName
                    ) == .orderedAscending
                }
                self.persistMembers()
                self.state.newMemberName = ""
                self.state.newMemberPhone = ""
                self.state.newMemberNotes = ""
                self.publishMessage(
                    self.tr(
                        "המתאמן נשמר ונוסף לרשימה",
                        "The trainee was saved and added to the list"
                    ),
                    isError: false
                )
                completion?(true)
            } catch {
                guard isCurrentContext() else {
                    completion?(false)
                    return
                }
                /*
                 * בכישלון לא מוסיפים רשומה מקומית
                 * ולא מציגים הודעת הצלחה.
                 */
                self.publishMessage(
                    self.tr(
                        "לא ניתן להוסיף את המתאמן כרגע. בדוק את החיבור ונסה שוב.",
                        "Unable to add the trainee right now. Check your connection and try again."
                    ),
                    isError: true
                )
                completion?(false)
            }
        }
    }
    func removeMember(memberId: String) {
        guard canModifyLoadedContext,
              state.members.contains(where: {
                $0.id == memberId
              }) else {
            return
        }
        let ownerUid = state.ownerUid
        let branchName = state.branchName
        let groupKey = state.groupKey
        let dateIso = state.dateIso
        let loadID = contextLoadID
        guard Auth.auth().currentUser?.uid == ownerUid else {
            return
        }
        state.isSaving = true
        Task { @MainActor in
            @MainActor
            func isCurrentContext() -> Bool {
                !Task.isCancelled &&
                self.contextLoadID == loadID &&
                self.state.ownerUid == ownerUid &&
                self.state.branchName == branchName &&
                self.state.groupKey == groupKey &&
                self.state.dateIso == dateIso &&
                Auth.auth().currentUser?.uid == ownerUid
            }
            defer {
                self.finishSavingOperation()
            }
            do {
                try await self.repository.removeMemberFromFirestore(
                    ownerUid: ownerUid,
                    branchName: branchName,
                    groupKey: groupKey,
                    memberId: memberId
                )
                guard isCurrentContext() else {
                    return
                }
                /*
                 * מסירים מהמסך רק לאחר שהשרת
                 * אישר את השלמת המחיקה.
                 */
                self.state.members.removeAll {
                    $0.id == memberId
                }
                self.state.recordsByMemberId.removeValue(
                    forKey: memberId
                )
                self.persistMembers()
                let remainingRecords = Array(
                    self.state.recordsByMemberId.values
                )
                self.repository.saveRecords(
                    ownerUid: ownerUid,
                    branchName: branchName,
                    groupKey: groupKey,
                    dateIso: dateIso,
                    records: remainingRecords
                )
                self.reloadMonthMarkers()
                self.publishMessage(
                    self.tr(
                        "המתאמן הוסר מהקבוצה",
                        "The trainee was removed from the group"
                    ),
                    isError: false
                )
            } catch {
                guard isCurrentContext() else {
                    return
                }
                self.publishMessage(
                    self.tr(
                        "מחיקת המתאמן לא הושלמה. נסה שוב להשלמת המחיקה.",
                        "The trainee deletion did not complete. Retry to finish deleting."
                    ),
                    isError: true
                )
            }
        }
    }
    func saveReport(onSaved: (() -> Void)? = nil) {
        guard !state.isSaving else {
            return
        }
        guard !isContextLoading else {
            publishMessage(
                tr(
                    "יש להמתין לסיום טעינת הדוח",
                    "Please wait until the report finishes loading"
                ),
                isError: true
            )
            return
        }
        guard !contextLoadFailed else {
            publishMessage(
                tr(
                    "יש לטעון את הדוח מחדש לפני שמירה",
                    "Reload the report before saving"
                ),
                isError: true
            )
            return
        }
        guard !state.branchName.trimmed().isEmpty,
              !state.groupKey.trimmed().isEmpty,
              hasScheduledTraining(
                branch: state.branchName,
                group: state.groupKey
              ) else {
            publishMessage(
                tr(
                    "אין אימון מתוכנן לסניף ולקבוצה בתאריך שנבחר.",
                    "No training is scheduled for the selected branch, group and date."
                ),
                isError: true
            )
            return
        }
        state.isSaving = true
        let records = state.members.map { member -> AttendanceRecord in
            if let existing = state.recordsByMemberId[member.id] {
                return existing
            }
            return AttendanceRecord(
                id: "\(state.dateIso)_\(member.id)",
                dateIso: state.dateIso,
                memberId: member.id,
                status: .unknown,
                note: ""
            )
        }
        let savingState = state
        let savingContextID = contextLoadID
        Task { @MainActor in
            defer {
                finishSavingOperation()
            }
            do {
                try await repository
                    .saveAttendanceReportToFirestore(
                        state: savingState,
                        records: records
                    )
                // תוצאת השמירה שייכת לבחירה שהייתה
                // בזמן הלחיצה, גם אם המשתמש עבר יום.
                guard !Task.isCancelled,
                      contextLoadID == savingContextID,
                      Auth.auth().currentUser?.uid == savingState.ownerUid,
                      state.ownerUid == savingState.ownerUid,
                      state.branchName == savingState.branchName,
                      state.groupKey == savingState.groupKey,
                      state.dateIso == savingState.dateIso else {
                    return
                }
                state.recordsByMemberId = Dictionary(
                    records.map {
                        ($0.memberId, $0)
                    },
                    uniquingKeysWith: { _, latest in
                        latest
                    }
                )
                isReportSaved = true
                reloadMonthMarkers()
                publishMessage(
                    tr(
                        "דו״ח הנוכחות נשמר",
                        "The attendance report was saved"
                    ),
                    isError: false
                )
                /*
                 * המסך יסגור את העריכה רק לאחר
                 * הצלחה, ועבור אותו דוח שנשמר.
                 */
                onSaved?()
            } catch {
                guard !Task.isCancelled,
                      contextLoadID == savingContextID,
                      Auth.auth().currentUser?.uid == savingState.ownerUid,
                      state.ownerUid == savingState.ownerUid,
                      state.branchName == savingState.branchName,
                      state.groupKey == savingState.groupKey,
                      state.dateIso == savingState.dateIso else {
                    return
                }
                publishMessage(
                    tr(
                        "לא ניתן לשמור את דו״ח הנוכחות כרגע. נסה שוב.",
                        "Unable to save the attendance report right now. Please try again."
                    ),
                    isError: true
                )
            }
        }
    }
    func loadSummaryDaysForMonth(
        year: Int,
        month1to12: Int
    ) {
        monthLoadTask?.cancel()
        monthLoadTask = nil
        let requestID = UUID()
        monthLoadID = requestID
        let ownerUid = state.ownerUid
        let branchName = state.branchName.trimmed()
        let groupKey = state.groupKey.trimmed()
        let contextID = contextLoadID
        guard !branchName.isEmpty,
              !groupKey.isEmpty,
              let start = Self.makeDate(
                year: year,
                month: month1to12,
                day: 1
              ),
              let end = ShabbatHolidayCheckerIOS.calendar.date(
                byAdding: .month,
                value: 1,
                to: start
              ) else {
            state.reportDaysInMonth = []
            return
        }
        let startIso = Self.isoString(start)
        let endIso = Self.isoString(end)
        let monthKey = [
            ownerUid,
            branchName,
            groupKey,
            startIso,
            endIso
        ]
        /*
         * באותו חודש משאירים את הסימונים
         * שכבר נטענו מהשרת בזמן הרענון.
         */
        if displayedMonthKey != monthKey {
            displayedMonthKey = monthKey
            state.reportDaysInMonth =
                repository.listReportDaysInRange(
                    ownerUid: ownerUid,
                    branchName: branchName,
                    groupKey: groupKey,
                    startIso: startIso,
                    endIsoExclusive: endIso
                )
        }
        monthLoadTask = Task { @MainActor in
            @MainActor
            func isCurrentRequest() -> Bool {
                !Task.isCancelled &&
                self.monthLoadID == requestID &&
                self.contextLoadID == contextID &&
                self.state.ownerUid == ownerUid &&
                self.state.branchName == branchName &&
                self.state.groupKey == groupKey &&
                Auth.auth().currentUser?.uid == ownerUid
            }
            defer {
                if self.monthLoadID == requestID {
                    self.monthLoadTask = nil
                }
            }
            do {
                let days = try await self.repository
                    .listReportDaysInRangeFromFirestore(
                        ownerUid: ownerUid,
                        branchName: branchName,
                        groupKey: groupKey,
                        startIso: startIso,
                        endIsoExclusive: endIso
                    )
                guard isCurrentRequest() else {
                    return
                }
                /*
                 * תשובה ריקה מוצלחת מנקה סימונים
                 * מקומיים ישנים מהתצוגה.
                 */
                self.state.reportDaysInMonth = days
            } catch {
                guard isCurrentRequest() else {
                    return
                }
                /*
                 * בכשל משאירים את המידע המקומי.
                 * אין להסיק מכשל שאין דוחות.
                 */
                self.publishMessage(
                    self.tr(
                        "לא ניתן לעדכן את ימי הדוחות כרגע. מוצגים סימונים מקומיים זמינים.",
                        "Could not refresh report dates. Available local markers are shown."
                    ),
                    isError: true
                )
            }
        }
    }
    private func reloadCurrentContext(
        preloadedMembers: [AttendanceMember]? = nil
    ) {
        contextLoadTask?.cancel()
        contextLoadTask = nil
        let loadID = UUID()
        contextLoadID = loadID
        let ownerUid = state.ownerUid
        let branchName = state.branchName.trimmed()
        let groupKey = state.groupKey.trimmed()
        let dateIso = state.dateIso
        isContextLoading = false
        contextLoadFailed = false
        state.members = []
        state.recordsByMemberId = [:]
        state.reportDaysInMonth = []
        displayedMonthKey = nil
        isReportSaved = false
        if needsDefaultGroupSelection && groupKey.isEmpty && !branchName.isEmpty {
            selectDefaultGroupWithMembers(loadID: loadID)
            return
        }

        guard !branchName.isEmpty,
              !groupKey.isEmpty,
              hasScheduledTraining(
                branch: branchName,
                group: groupKey
              ) else {
            return
        }
        /*
         * מציגים מטמון בזמן הבדיקה.
         * עריכה ושמירה ייחסמו עד לסיום הטעינה.
         */
        state.members = repository.loadMembers(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey
        )
        reloadRecordsOnly()
        reloadMonthMarkers()
        isContextLoading = true
        contextLoadTask = Task { @MainActor in
            @MainActor
            func isCurrentContext() -> Bool {
                !Task.isCancelled &&
                self.contextLoadID == loadID &&
                self.state.ownerUid == ownerUid &&
                self.state.branchName == branchName &&
                self.state.groupKey == groupKey &&
                self.state.dateIso == dateIso &&
                Auth.auth().currentUser?.uid == ownerUid
            }
            defer {
                if self.contextLoadID == loadID {
                    self.isContextLoading = false
                    self.contextLoadTask = nil
                }
            }
            do {
                let members: [AttendanceMember]
                if let preloadedMembers {
                    members = preloadedMembers
                } else {
                    members = try await self.repository.loadRealMembers(
                        ownerUid: ownerUid,
                        branchName: branchName,
                        groupKey: groupKey
                    )
                }
                guard isCurrentContext() else {
                    return
                }
                let records = try await self.repository.loadRecordsFromFirestore(
                    ownerUid: ownerUid,
                    branchName: branchName,
                    groupKey: groupKey,
                    dateIso: dateIso
                )
                guard isCurrentContext() else {
                    return
                }
                let savedReport = try await self.repository.hasSavedAttendanceReport(
                    branchName: branchName,
                    groupKey: groupKey,
                    dateIso: dateIso
                )
                guard isCurrentContext() else {
                    return
                }
                /*
                 * מעדכנים את המסך לאחר שכל חלקי
                 * ההקשר נטענו בהצלחה.
                 * תשובה ריקה מוצלחת נשארת ריקה.
                 */
                self.state.members = members
                self.state.recordsByMemberId = Dictionary(
                    records.map {
                        ($0.memberId, $0)
                    },
                    uniquingKeysWith: { _, latest in
                        latest
                    }
                )
                self.isReportSaved = savedReport
                self.contextLoadFailed = false
                self.reloadMonthMarkers()
            } catch {
                guard isCurrentContext() else {
                    return
                }
                /*
                 * שגיאה אינה הוכחה שאין דוח.
                 * מציגים מטמון וחוסמים כתיבה
                 * עד לטעינה מוצלחת.
                 */
                self.state.members = self.repository.loadMembers(
                    ownerUid: ownerUid,
                    branchName: branchName,
                    groupKey: groupKey
                )
                self.reloadRecordsOnly()
                self.contextLoadFailed = true
                self.publishMessage(
                    self.tr(
                        "לא ניתן להשלים את טעינת הדוח. מוצגים נתונים מקומיים זמינים; העריכה חסומה עד לטעינה מוצלחת.",
                        "Could not finish loading the report. Available local data is shown; editing is blocked until loading succeeds."
                    ),
                    isError: true
                )
            }
        }
    }
    private func selectDefaultGroupWithMembers(loadID: UUID) {
        let ownerUid = state.ownerUid
        let branch = state.branchName
        let dateIso = state.dateIso
        let groups = availableGroups
        let preferred = preferredDefaultGroup
        let candidates = groups.contains(preferred)
            ? [preferred] + groups.filter { $0 != preferred }
            : groups

        guard !candidates.isEmpty else {
            needsDefaultGroupSelection = false
            return
        }

        isContextLoading = true
        contextLoadTask = Task { @MainActor in
            @MainActor
            func isCurrentSelection() -> Bool {
                !Task.isCancelled &&
                self.contextLoadID == loadID &&
                self.state.ownerUid == ownerUid &&
                self.state.branchName == branch &&
                self.state.dateIso == dateIso &&
                self.state.groupKey.isEmpty &&
                self.availableGroups == groups &&
                Auth.auth().currentUser?.uid == ownerUid
            }

            defer {
                if self.contextLoadID == loadID {
                    self.isContextLoading = false
                    self.contextLoadTask = nil
                }
            }

            var hadReadError = false
            for candidate in candidates {
                guard isCurrentSelection() else { return }
                do {
                    let members = try await self.repository.loadRealMembers(
                        ownerUid: ownerUid,
                        branchName: branch,
                        groupKey: candidate
                    )
                    guard isCurrentSelection() else { return }
                    guard !members.isEmpty else { continue }

                    self.needsDefaultGroupSelection = false
                    self.state.groupKey = candidate
                    // משתמשים באותה רשימה, ללא טעינה כפולה של המתאמנים.
                    self.reloadCurrentContext(preloadedMembers: members)
                    return
                } catch {
                    guard isCurrentSelection() else { return }
                    hadReadError = true
                }
            }

            guard isCurrentSelection() else { return }
            if hadReadError {
                // מאפשר לכפתור "נסה שוב" לבצע שוב את בחירת הקבוצה.
                self.contextLoadFailed = true
                self.publishMessage(
                    self.tr(
                        "לא ניתן לבדוק אילו קבוצות כוללות מתאמנים כרגע. נסה שוב.",
                        "Could not check which groups have trainees. Please try again."
                    ),
                    isError: true
                )
            } else {
                // כל הקריאות הצליחו וכל הקבוצות ריקות — אין בחירה אוטומטית.
                self.needsDefaultGroupSelection = false
            }
        }
    }

    private func reloadRecordsOnly() {
        let loaded =
            repository.loadRecords(
                ownerUid: state.ownerUid,
                branchName: state.branchName,
                groupKey: state.groupKey,
                dateIso: state.dateIso
            )
        state.recordsByMemberId = Dictionary(
            loaded.map {
                ($0.memberId, $0)
            },
            uniquingKeysWith: { _, latest in
                latest
            }
        )
        isReportSaved =
            !loaded.isEmpty
    }
    private func reloadMonthMarkers() {
        let comps = Self.dateComponents(fromIso: state.dateIso)
        if let year = comps.year, let month = comps.month {
            loadSummaryDaysForMonth(year: year, month1to12: month)
        } else {
            state.reportDaysInMonth = []
        }
    }
    private func persistMembers() {
        repository.saveMembers(
            ownerUid: state.ownerUid,
            branchName: state.branchName,
            groupKey: state.groupKey,
            members: state.members
        )
    }
    private func publishMessage(_ text: String, isError: Bool) {
        state.lastMessage = text
        state.lastMessageIsError = isError
        let now = Int64(
            Date().timeIntervalSince1970 * 1_000
        )
        state.messageEventId = max(
            now,
            state.messageEventId + 1
        )
    }
    private static func todayIso() -> String {
        isoString(Date())
    }
    private static func isoString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = ShabbatHolidayCheckerIOS.calendar
        formatter.timeZone = ShabbatHolidayCheckerIOS.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    private static func parsedDate(fromIso iso: String) -> Date? {
        let clean = iso.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = ShabbatHolidayCheckerIOS.calendar
        formatter.timeZone = ShabbatHolidayCheckerIOS.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: clean),
              formatter.string(from: date) == clean else {
            return nil
        }
        return date
    }
    private static func makeDate(
        year: Int,
        month: Int,
        day: Int
    ) -> Date? {
        let calendar = ShabbatHolidayCheckerIOS.calendar
        guard let date = calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day
            )
        ) else {
            return nil
        }
        let components = calendar.dateComponents(
            [.year, .month, .day],
            from: date
        )
        guard components.year == year,
              components.month == month,
              components.day == day else {
            return nil
        }
        return date
    }
    private static func dateComponents(
        fromIso iso: String
    ) -> DateComponents {
        guard let date = parsedDate(fromIso: iso) else {
            return DateComponents()
        }
        return ShabbatHolidayCheckerIOS.calendar.dateComponents(
            [.year, .month, .day],
            from: date
        )
    }
}
private func uniqueMembers(_ members: [AttendanceMember]) -> [AttendanceMember] {
    var unique: [String: AttendanceMember] = [:]
    for member in members {
        let key =
            member.fullName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if unique[key] == nil {
            unique[key] = member
        }
    }
    return unique.values.sorted {
        $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending
    }
}
private extension String {
    var trimmedNonEmpty: String? {
        let clean = trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }
    func trimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
