import Foundation

final class AttendanceLocalStore {
    static let shared = AttendanceLocalStore()
    private init() {}

    private let defaults = UserDefaults.standard

    private let membersPrefix = "attendance_members"
    private let reportPrefix = "attendance_report"
    private let reportDaysPrefix = "attendance_report_days"

    private func normalized(_ value: String) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "_" : clean
    }

    private func membersKey(ownerUid: String, branchName: String, groupKey: String) -> String {
        "\(membersPrefix)_\(normalized(ownerUid))_\(normalized(branchName))_\(normalized(groupKey))"
    }

    private func reportKey(ownerUid: String, branchName: String, groupKey: String, dateIso: String) -> String {
        "\(reportPrefix)_\(normalized(ownerUid))_\(normalized(branchName))_\(normalized(groupKey))_\(normalized(dateIso))"
    }

    private func reportDaysKey(ownerUid: String, branchName: String, groupKey: String) -> String {
        "\(reportDaysPrefix)_\(normalized(ownerUid))_\(normalized(branchName))_\(normalized(groupKey))"
    }

    func loadMembers(
        ownerUid: String,
        branchName: String,
        groupKey: String
    ) -> [AttendanceMember] {
        guard
            let data = defaults.data(forKey: membersKey(ownerUid: ownerUid, branchName: branchName, groupKey: groupKey)),
            let decoded = try? JSONDecoder().decode([AttendanceMember].self, from: data)
        else {
            return []
        }
        return decoded
    }

    func saveMembers(
        ownerUid: String,
        branchName: String,
        groupKey: String,
        members: [AttendanceMember]
    ) {
        if let data = try? JSONEncoder().encode(members) {
            defaults.set(data, forKey: membersKey(ownerUid: ownerUid, branchName: branchName, groupKey: groupKey))
        }
    }

    func loadRecords(
        ownerUid: String,
        branchName: String,
        groupKey: String,
        dateIso: String
    ) -> [AttendanceRecord] {
        guard
            let data = defaults.data(forKey: reportKey(ownerUid: ownerUid, branchName: branchName, groupKey: groupKey, dateIso: dateIso)),
            let decoded = try? JSONDecoder().decode([AttendanceRecord].self, from: data)
        else {
            return []
        }
        return decoded
    }

    func saveRecords(
        ownerUid: String,
        branchName: String,
        groupKey: String,
        dateIso: String,
        records: [AttendanceRecord]
    ) {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: reportKey(ownerUid: ownerUid, branchName: branchName, groupKey: groupKey, dateIso: dateIso))
        }

        addReportDay(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey,
            dateIso: dateIso
        )
    }

    func deleteReport(
        ownerUid: String,
        branchName: String,
        groupKey: String,
        dateIso: String
    ) {
        defaults.removeObject(
            forKey: reportKey(ownerUid: ownerUid, branchName: branchName, groupKey: groupKey, dateIso: dateIso)
        )
    }

    func addReportDay(
        ownerUid: String,
        branchName: String,
        groupKey: String,
        dateIso: String
    ) {
        let key = reportDaysKey(ownerUid: ownerUid, branchName: branchName, groupKey: groupKey)
        var current = defaults.stringArray(forKey: key) ?? []
        let clean = dateIso.trimmingCharacters(in: .whitespacesAndNewlines)

        if !clean.isEmpty && !current.contains(clean) {
            current.append(clean)
            defaults.set(current, forKey: key)
        }
    }

    func listReportDaysInRange(
        ownerUid: String,
        branchName: String,
        groupKey: String,
        startIso: String,
        endIsoExclusive: String
    ) -> Set<String> {
        let key = reportDaysKey(ownerUid: ownerUid, branchName: branchName, groupKey: groupKey)
        let all = Set(defaults.stringArray(forKey: key) ?? [])

        return Set(
            all.filter { iso in
                iso >= startIso && iso < endIsoExclusive
            }
        )
    }
}
