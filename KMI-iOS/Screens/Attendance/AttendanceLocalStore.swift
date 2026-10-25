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

    private func hasValidContext(
        ownerUid: String,
        branchName: String,
        groupKey: String
    ) -> Bool {
        [ownerUid, branchName, groupKey].allSatisfy {
            !$0.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
        }
    }

    private func validDateIso(_ value: String) -> String? {
        let clean = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let formatter = DateFormatter()
        formatter.calendar = ShabbatHolidayCheckerIOS.calendar
        formatter.timeZone = ShabbatHolidayCheckerIOS.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false

        guard let date = formatter.date(from: clean),
              formatter.string(from: date) == clean else {
            return nil
        }

        return clean
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
        guard hasValidContext(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey
        ) else {
            return []
        }

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
        guard hasValidContext(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey
        ) else {
            return
        }

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
        guard hasValidContext(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey
        ),
        let cleanDate = validDateIso(dateIso) else {
            return []
        }

        let key = reportKey(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey,
            dateIso: cleanDate
        )

        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(
                [AttendanceRecord].self,
                from: data
              ) else {
            return []
        }

        return decoded.filter {
            $0.dateIso == cleanDate &&
            !$0.memberId.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
        }
    }

    func saveRecords(
        ownerUid: String,
        branchName: String,
        groupKey: String,
        dateIso: String,
        records: [AttendanceRecord]
    ) {
        guard hasValidContext(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey
        ),
        let cleanDate = validDateIso(dateIso),
        records.allSatisfy({
            $0.dateIso == cleanDate &&
            !$0.memberId.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
        }),
        Set(records.map(\.memberId)).count == records.count else {
            return
        }

        let key = reportKey(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey,
            dateIso: cleanDate
        )

        if records.isEmpty {
            defaults.removeObject(forKey: key)
            removeReportDay(
                ownerUid: ownerUid,
                branchName: branchName,
                groupKey: groupKey,
                dateIso: dateIso
            )
            return
        }

        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: key)

            addReportDay(
                ownerUid: ownerUid,
                branchName: branchName,
                groupKey: groupKey,
                dateIso: dateIso
            )
        }
    }

    func deleteReport(
        ownerUid: String,
        branchName: String,
        groupKey: String,
        dateIso: String
    ) {
        guard hasValidContext(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey
        ),
        let cleanDate = validDateIso(dateIso) else {
            return
        }

        defaults.removeObject(
            forKey: reportKey(
                ownerUid: ownerUid,
                branchName: branchName,
                groupKey: groupKey,
                dateIso: cleanDate
            )
        )

        removeReportDay(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey,
            dateIso: cleanDate
        )
    }

    func addReportDay(
        ownerUid: String,
        branchName: String,
        groupKey: String,
        dateIso: String
    ) {
        guard hasValidContext(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey
        ),
        let cleanDate = validDateIso(dateIso) else {
            return
        }

        let key = reportDaysKey(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey
        )

        var days = Set(
            (defaults.stringArray(forKey: key) ?? [])
                .compactMap { validDateIso($0) }
        )

        days.insert(cleanDate)

        defaults.set(
            days.sorted(),
            forKey: key
        )
    }

    private func removeReportDay(
        ownerUid: String,
        branchName: String,
        groupKey: String,
        dateIso: String
    ) {
        guard hasValidContext(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey
        ),
        let cleanDate = validDateIso(dateIso) else {
            return
        }

        let key = reportDaysKey(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey
        )

        var days = Set(
            (defaults.stringArray(forKey: key) ?? [])
                .compactMap { validDateIso($0) }
        )

        days.remove(cleanDate)

        if days.isEmpty {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(
                days.sorted(),
                forKey: key
            )
        }
    }

    func listReportDaysInRange(
        ownerUid: String,
        branchName: String,
        groupKey: String,
        startIso: String,
        endIsoExclusive: String
    ) -> Set<String> {
        guard hasValidContext(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey
        ),
        let start = validDateIso(startIso),
        let end = validDateIso(endIsoExclusive),
        start < end else {
            return []
        }

        let key = reportDaysKey(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey
        )

        let days = (defaults.stringArray(forKey: key) ?? [])
            .compactMap { validDateIso($0) }

        return Set(
            days.filter {
                $0 >= start && $0 < end
            }
        )
    }
}
