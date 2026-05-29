import Foundation
import Combine

@MainActor
final class AttendanceViewModel: ObservableObject {
    @Published private(set) var state: AttendanceUiState

    private let repository: AttendanceRepository

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
        state.dateIso = value.trimmed()
        reloadRecordsFromRemoteThenLocal()
        reloadMonthMarkersFromRemoteThenLocal()
    }

    func setBranchName(_ value: String) {
        let clean = value.trimmed()
        state.branchName = clean

        reloadCurrentContext()
    }

    func setGroupKey(_ value: String) {
        let clean = value.trimmed()
        state.groupKey = clean

        reloadCurrentContext()
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
        state.members = uniqueMembers(state.members)

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

        state.recordsByMemberId = Dictionary(
            uniqueKeysWithValues: records.map { ($0.memberId, $0) }
        )

        repository.saveReport(
            state: state,
            records: records
        )

        state.isSaving = false

        reloadMonthMarkersFromRemoteThenLocal()
        publishMessage(
            tr("דו״ח הנוכחות נשמר", "The attendance report was saved"),
            isError: false
        )
    }

    func loadSummaryDaysForMonth(year: Int, month1to12: Int) {
        guard
            let start = Self.makeDate(year: year, month: month1to12, day: 1),
            let end = Calendar.current.date(byAdding: .month, value: 1, to: start)
        else {
            state.reportDaysInMonth = []
            return
        }

        let startIso = Self.isoString(start)
        let endIsoExclusive = Self.isoString(end)

        state.reportDaysInMonth = repository.listReportDaysInRange(
            ownerUid: state.ownerUid,
            branchName: state.branchName,
            groupKey: state.groupKey,
            startIso: startIso,
            endIsoExclusive: endIsoExclusive
        )

        let ownerUid = state.ownerUid
        let branchName = state.branchName
        let groupKey = state.groupKey
        let repository = self.repository

        Task.detached(priority: nil) {
            do {
                let remoteDays = try await repository.listReportDaysInRangeFromFirestore(
                    ownerUid: ownerUid,
                    branchName: branchName,
                    groupKey: groupKey,
                    startIso: startIso,
                    endIsoExclusive: endIsoExclusive
                )

                await MainActor.run {
                    self.state.reportDaysInMonth.formUnion(remoteDays)
                }
            } catch {
                await MainActor.run {
                    self.state.reportDaysInMonth = self.state.reportDaysInMonth
                }
            }
        }
    }

    private func reloadCurrentContext() {
        let ownerUid = state.ownerUid
        let branchName = state.branchName
        let groupKey = state.groupKey
        let repository = self.repository

        Task.detached(priority: nil) {
            do {
                let realMembers = try await repository.loadRealMembers(
                    ownerUid: ownerUid,
                    branchName: branchName,
                    groupKey: groupKey
                )

                await MainActor.run {
                    if !realMembers.isEmpty {
                        self.state.members = uniqueMembers(realMembers)
                    } else {
                        let fallbackMembers = repository.loadMembers(
                            ownerUid: ownerUid,
                            branchName: branchName,
                            groupKey: groupKey
                        )

                        self.state.members = uniqueMembers(fallbackMembers)
                    }

                    self.reloadRecordsFromRemoteThenLocal()
                    self.reloadMonthMarkersFromRemoteThenLocal()
                }
            } catch {
                await MainActor.run {
                    let fallbackMembers = repository.loadMembers(
                        ownerUid: ownerUid,
                        branchName: branchName,
                        groupKey: groupKey
                    )

                    self.state.members = uniqueMembers(fallbackMembers)
                    self.reloadRecordsFromRemoteThenLocal()
                    self.reloadMonthMarkersFromRemoteThenLocal()
                    self.publishMessage(
                        self.tr(
                            "לא נטענו מתאמנים מהשרת, נטען גיבוי מקומי",
                            "Server trainees could not be loaded. Local backup was loaded."
                        ),
                        isError: true
                    )
                }
            }
        }
    }
    
    private func reloadRecordsOnly() {
        let loaded = repository.loadRecords(
            ownerUid: state.ownerUid,
            branchName: state.branchName,
            groupKey: state.groupKey,
            dateIso: state.dateIso
        )

        state.recordsByMemberId = Dictionary(
            uniqueKeysWithValues: loaded.map { ($0.memberId, $0) }
        )
    }

    private func reloadRecordsFromRemoteThenLocal() {
        reloadRecordsOnly()

        let ownerUid = state.ownerUid
        let branchName = state.branchName
        let groupKey = state.groupKey
        let dateIso = state.dateIso
        let repository = self.repository

        Task.detached(priority: nil) {
            do {
                let remoteRecords = try await repository.loadRecordsFromFirestore(
                    ownerUid: ownerUid,
                    branchName: branchName,
                    groupKey: groupKey,
                    dateIso: dateIso
                )

                guard !remoteRecords.isEmpty else {
                    return
                }

                await MainActor.run {
                    self.state.recordsByMemberId = Dictionary(
                        uniqueKeysWithValues: remoteRecords.map { ($0.memberId, $0) }
                    )

                    repository.saveRecords(
                        ownerUid: ownerUid,
                        branchName: branchName,
                        groupKey: groupKey,
                        dateIso: dateIso,
                        records: remoteRecords
                    )
                }
            } catch {
                await MainActor.run {
                    self.reloadRecordsOnly()
                }
            }
        }
    }

    private func reloadMonthMarkers() {
        let comps = Self.dateComponents(fromIso: state.dateIso)
        if let year = comps.year, let month = comps.month {
            loadSummaryDaysForMonth(year: year, month1to12: month)
        } else {
            state.reportDaysInMonth = []
        }
    }

    private func reloadMonthMarkersFromRemoteThenLocal() {
        reloadMonthMarkers()
    }

    private func persistMembers() {
        let cleanMembers = uniqueMembers(state.members)
        state.members = cleanMembers

        repository.saveMembers(
            ownerUid: state.ownerUid,
            branchName: state.branchName,
            groupKey: state.groupKey,
            members: cleanMembers
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
        let nameKey = member.fullName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let phoneKey = member.phone
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let key = phoneKey.isEmpty ? nameKey : "\(nameKey)|\(phoneKey)"

        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            continue
        }

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
