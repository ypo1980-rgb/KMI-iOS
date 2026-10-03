import Foundation
import Combine

@MainActor
final class AttendanceViewModel: ObservableObject {

    @Published
    private(set) var state: AttendanceUiState

    @Published
    private(set) var isReportSaved: Bool = false

    private let repository: AttendanceRepository

    private var contextLoadID = UUID()

    @Published
    private(set) var availableBranches: [String] = []

    @Published
    private(set) var availableGroups: [String] = []

    private var allAssignedBranches: [String] = []

    func setAssignedBranches(_ branches: [String]) {
        var seen = Set<String>()

        allAssignedBranches = branches
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter {
                !$0.isEmpty && seen.insert($0).inserted
            }

        refreshScheduleOptions()
        reloadCurrentContext()
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

        guard !ShabbatHolidayCheckerIOS.isBlockedDate(
            selectedDate
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
        availableBranches = allAssignedBranches.filter {
            hasScheduledTraining(branch: $0)
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

        state.groupKey =
            availableGroups.first {
                $0 == preferredGroup ||
                TrainingCatalogIOS.normalizeGroupName($0) ==
                    normalizedPreferredGroup
            }
            ?? availableGroups.first
            ?? ""
    }

    private var isEnglish: Bool {
        let defaults = UserDefaults.standard

        let values = [
            defaults.string(forKey: "kmi_app_language"),
            defaults.string(forKey: "app_language"),
            defaults.string(forKey: "initial_language_code"),
            defaults.string(forKey: "initial_language_selected_code"),
            defaults.string(forKey: "kmi.language.code")
        ]
        .compactMap { $0 }
        .map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        }

        if values.contains("en") || values.contains("english") {
            return true
        }

        if values.contains("he") || values.contains("hebrew") {
            return false
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
        repository: AttendanceRepository = .shared
    ) {
        self.repository = repository
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
        let clean = value.trimmed()

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
        let clean = value.trimmed()

        guard availableGroups.contains(clean),
              clean != state.groupKey else {
            return
        }

        state.groupKey = clean

        reloadCurrentContext()
        reloadMonthMarkers()
    }

    func setCoachName(_ value: String) {
        let clean = value.trimmed()
        state.coachName = clean
    }

    func setAttendanceStatus(memberId: String, status: AttendanceStatus) {
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

    func addMember(fullName: String, phone: String = "", notes: String = "") {
        let cleanName = fullName.trimmed()
        guard !cleanName.isEmpty else {
            publishMessage(
                tr("יש להזין שם מתאמן", "Please enter a trainee name"),
                isError: true
            )
            return
        }

        if state.members.contains(where: { $0.fullName.trimmed().lowercased() == cleanName.lowercased() }) {
            publishMessage(
                tr("המתאמן כבר קיים ברשימה", "This trainee already exists in the list"),
                isError: true
            )
            return
        }

        let member = AttendanceMember(
            fullName: cleanName,
            phone: phone.trimmed(),
            notes: notes.trimmed()
        )

        state.members.append(member)
        state.members.sort { $0.fullName < $1.fullName }

        persistMembers()

        state.newMemberName = ""
        state.newMemberPhone = ""
        state.newMemberNotes = ""

        publishMessage(
            tr("המתאמן נוסף לרשימה", "The trainee was added to the list"),
            isError: false
        )
    }

    func removeMember(memberId: String) {
        state.members.removeAll { $0.id == memberId }
        state.recordsByMemberId.removeValue(forKey: memberId)
        persistMembers()
        publishMessage(
            tr("המתאמן הוסר מהרשימה", "The trainee was removed from the list"),
            isError: false
        )
    }

    func saveReport() {
        guard !state.isSaving else {
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

        Task { @MainActor in
            defer {
                state.isSaving = false
            }

            do {
                try await repository
                    .saveAttendanceReportToFirestore(
                        state: savingState,
                        records: records
                    )

                // תוצאת השמירה שייכת לבחירה שהייתה
                // בזמן הלחיצה, גם אם המשתמש עבר יום.
                guard state.ownerUid == savingState.ownerUid,
                      state.branchName == savingState.branchName,
                      state.groupKey == savingState.groupKey,
                      state.dateIso == savingState.dateIso else {
                    return
                }

                state.recordsByMemberId = Dictionary(
                    uniqueKeysWithValues: records.map {
                        ($0.memberId, $0)
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
            } catch {
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

    func loadSummaryDaysForMonth(year: Int, month1to12: Int) {
        guard
            let start = Self.makeDate(year: year, month: month1to12, day: 1),
            let end = Calendar.current.date(byAdding: .month, value: 1, to: start)
        else {
            state.reportDaysInMonth = []
            return
        }

        state.reportDaysInMonth = repository.listReportDaysInRange(
            ownerUid: state.ownerUid,
            branchName: state.branchName,
            groupKey: state.groupKey,
            startIso: Self.isoString(start),
            endIsoExclusive: Self.isoString(end)
        )
    }

    private func reloadCurrentContext() {
        let loadID = UUID()
        contextLoadID = loadID

        let ownerUid = state.ownerUid
        let branchName = state.branchName.trimmed()
        let groupKey = state.groupKey.trimmed()
        let dateIso = state.dateIso
        let repository = self.repository

        state.members = []
        state.recordsByMemberId = [:]
        state.reportDaysInMonth = []
        isReportSaved = false

        guard !branchName.isEmpty,
              !groupKey.isEmpty,
              hasScheduledTraining(
                branch: branchName,
                group: groupKey
              ) else {
            return
        }

        Task.detached(priority: nil) {
            do {
                let realMembers =
                    try await repository.loadRealMembers(
                        ownerUid: ownerUid,
                        branchName: branchName,
                        groupKey: groupKey
                    )

                await MainActor.run {
                    guard self.contextLoadID == loadID,
                          self.state.ownerUid == ownerUid,
                          self.state.branchName == branchName,
                          self.state.groupKey == groupKey,
                          self.state.dateIso == dateIso else {
                        return
                    }

                    self.state.members =
                        realMembers.isEmpty
                            ? repository.loadMembers(
                                ownerUid: ownerUid,
                                branchName: branchName,
                                groupKey: groupKey
                            )
                            : realMembers

                    self.reloadRecordsOnly()
                    self.reloadMonthMarkers()
                }
            } catch {
                await MainActor.run {
                    guard self.contextLoadID == loadID,
                          self.state.ownerUid == ownerUid,
                          self.state.branchName == branchName,
                          self.state.groupKey == groupKey,
                          self.state.dateIso == dateIso else {
                        return
                    }

                    self.state.members =
                        repository.loadMembers(
                            ownerUid: ownerUid,
                            branchName: branchName,
                            groupKey: groupKey
                        )

                    self.reloadRecordsOnly()
                    self.reloadMonthMarkers()

                    self.publishMessage(
                        self.tr(
                            "לא ניתן לטעון את הרשימה כרגע. מוצגים נתונים מקומיים זמינים.",
                            "Unable to load the list right now. Available local data is shown."
                        ),
                        isError: true
                    )
                }
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

        state.recordsByMemberId =
            Dictionary(
                uniqueKeysWithValues:
                    loaded.map {
                        (
                            $0.memberId,
                            $0
                        )
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
        state.messageEventId = Int64(Date().timeIntervalSince1970 * 1000)
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
