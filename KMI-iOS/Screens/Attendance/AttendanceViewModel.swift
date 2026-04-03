import Foundation
import Combine

@MainActor
final class AttendanceViewModel: ObservableObject {
    @Published private(set) var state: AttendanceUiState

    private let repository: AttendanceRepository

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
        reloadRecordsOnly()
        reloadMonthMarkers()
    }

    func setBranchName(_ value: String) {
        let clean = value.trimmed()
        state.branchName = clean

        #if DEBUG
        print("🟢 VM setBranchName =", clean)
        #endif

        reloadCurrentContext()
    }

    func setGroupKey(_ value: String) {
        let clean = value.trimmed()
        state.groupKey = clean

        #if DEBUG
        print("🟢 VM setGroupKey =", clean)
        #endif

        reloadCurrentContext()
    }

    func setCoachName(_ value: String) {
        let clean = value.trimmed()
        state.coachName = clean

        #if DEBUG
        print("🟢 VM setCoachName =", clean)
        #endif
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
            publishMessage("יש להזין שם מתאמן", isError: true)
            return
        }

        if state.members.contains(where: { $0.fullName.trimmed().lowercased() == cleanName.lowercased() }) {
            publishMessage("המתאמן כבר קיים ברשימה", isError: true)
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

        publishMessage("המתאמן נוסף לרשימה", isError: false)
    }

    func removeMember(memberId: String) {
        state.members.removeAll { $0.id == memberId }
        state.recordsByMemberId.removeValue(forKey: memberId)
        persistMembers()
        publishMessage("המתאמן הוסר מהרשימה", isError: false)
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

        repository.saveRecords(
            ownerUid: state.ownerUid,
            branchName: state.branchName,
            groupKey: state.groupKey,
            dateIso: state.dateIso,
            records: records
        )

        state.recordsByMemberId = Dictionary(uniqueKeysWithValues: records.map { ($0.memberId, $0) })
        state.isSaving = false

        reloadMonthMarkers()
        publishMessage("דו״ח הנוכחות נשמר", isError: false)
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
        let ownerUid = state.ownerUid
        let branchName = state.branchName
        let groupKey = state.groupKey
        let repository = self.repository

        #if DEBUG
        print("🟠 AttendanceVM.reloadCurrentContext ownerUid =", ownerUid)
        print("🟠 AttendanceVM.reloadCurrentContext branchName =", branchName)
        print("🟠 AttendanceVM.reloadCurrentContext groupKey =", groupKey)
        #endif

        Task.detached(priority: nil) {
            do {
                let realMembers = try await repository.loadRealMembers(
                    ownerUid: ownerUid,
                    branchName: branchName,
                    groupKey: groupKey
                )

                await MainActor.run {
                    #if DEBUG
                    print("🟠 AttendanceVM.loadRealMembers count =", realMembers.count)
                    print("🟠 AttendanceVM.loadRealMembers names =", realMembers.map(\.fullName))
                    #endif

                    if !realMembers.isEmpty {
                                          self.state.members = realMembers
                                      } else {
                                          let fallbackMembers =
                                              repository.loadMembers(
                                                  ownerUid: ownerUid,
                                                  branchName: branchName,
                                                  groupKey: groupKey
                                              )
 
                        #if DEBUG
                        print("🟠 AttendanceVM.fallbackMembers count =", fallbackMembers.count)
                        print("🟠 AttendanceVM.fallbackMembers names =", fallbackMembers.map(\.fullName))
                        #endif

                                          self.state.members = fallbackMembers
                                                              }
                    self.reloadRecordsOnly()
                    self.reloadMonthMarkers()

                    #if DEBUG
                    print("🟠 AttendanceVM.state.members final count =", self.state.members.count)
                    print("🟠 AttendanceVM.state.summary totalMembers =", self.state.summary.totalMembers)
                    #endif
                }
            } catch {
                await MainActor.run {
                    let fallbackMembers = repository.loadMembers(
                        ownerUid: ownerUid,
                        branchName: branchName,
                        groupKey: groupKey
                    )

                    #if DEBUG
                    print("🔴 AttendanceVM.loadRealMembers failed =", error.localizedDescription)
                    print("🔴 AttendanceVM.catch fallbackMembers count =", fallbackMembers.count)
                    print("🔴 AttendanceVM.catch fallbackMembers names =", fallbackMembers.map(\.fullName))
                    #endif

                    self.state.members = fallbackMembers
                    self.reloadRecordsOnly()
                    self.reloadMonthMarkers()
                    self.publishMessage("לא נטענו מתאמנים אמיתיים, נטען גיבוי מקומי", isError: true)
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

        state.recordsByMemberId = Dictionary(uniqueKeysWithValues: loaded.map { ($0.memberId, $0) })
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
