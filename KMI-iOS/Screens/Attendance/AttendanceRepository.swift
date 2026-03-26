import Foundation

final class AttendanceRepository {

    static let shared = AttendanceRepository()

    private let store: AttendanceLocalStore

    init(store: AttendanceLocalStore = .shared) {
        self.store = store
    }

    // MARK: - Members

    func loadMembers(
        ownerUid: String,
        branchName: String,
        groupKey: String
    ) -> [AttendanceMember] {
        store.loadMembers(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey
        )
    }

    func saveMembers(
        ownerUid: String,
        branchName: String,
        groupKey: String,
        members: [AttendanceMember]
    ) {
        store.saveMembers(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey,
            members: members
        )
    }

    // MARK: - Records

    func loadRecords(
        ownerUid: String,
        branchName: String,
        groupKey: String,
        dateIso: String
    ) -> [AttendanceRecord] {
        store.loadRecords(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey,
            dateIso: dateIso
        )
    }

    func saveRecords(
        ownerUid: String,
        branchName: String,
        groupKey: String,
        dateIso: String,
        records: [AttendanceRecord]
    ) {
        store.saveRecords(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey,
            dateIso: dateIso,
            records: records
        )
    }

    // MARK: - Reports

    func listReportDaysInRange(
        ownerUid: String,
        branchName: String,
        groupKey: String,
        startIso: String,
        endIsoExclusive: String
    ) -> Set<String> {
        store.listReportDaysInRange(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey,
            startIso: startIso,
            endIsoExclusive: endIsoExclusive
        )
    }

    func deleteReport(
        ownerUid: String,
        branchName: String,
        groupKey: String,
        dateIso: String
    ) {
        store.deleteReport(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey,
            dateIso: dateIso
        )
    }
    
    // MARK: - Stats / Reports

    func reportsLastYear(
        ownerUid: String,
        branchName: String,
        groupKey: String,
        today: Date = Date()
    ) -> [AttendanceSavedReport] {
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .year, value: -1, to: today) else {
            return []
        }

        let startIso = Self.isoString(start)
        let endIsoExclusive = Self.isoString(calendar.date(byAdding: .day, value: 1, to: today) ?? today)

        let days = listReportDaysInRange(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey,
            startIso: startIso,
            endIsoExclusive: endIsoExclusive
        )

        let members = loadMembers(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey
        )

        return days
            .sorted(by: >)
            .map { dateIso in
                let records = loadRecords(
                    ownerUid: ownerUid,
                    branchName: branchName,
                    groupKey: groupKey,
                    dateIso: dateIso
                )

                let byMemberId = Dictionary(uniqueKeysWithValues: records.map { ($0.memberId, $0) })

                let statuses = members.map { member in
                    byMemberId[member.id]?.status ?? .unknown
                }

                let present = statuses.filter { $0 == .present }.count
                let excused = statuses.filter { $0 == .excused }.count
                let absent = statuses.filter { $0 == .absent }.count
                let unknown = statuses.filter { $0 == .unknown }.count

                return AttendanceSavedReport(
                    id: dateIso,
                    dateIso: dateIso,
                    totalMembers: members.count,
                    presentCount: present,
                    excusedCount: excused,
                    absentCount: absent,
                    unknownCount: unknown
                )
            }
    }

    func groupStatsSummary(
        ownerUid: String,
        branchName: String,
        groupKey: String,
        today: Date = Date()
    ) -> AttendanceGroupStatsSummary {
        let reports = reportsLastYear(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey,
            today: today
        )

        guard !reports.isEmpty else {
            return AttendanceGroupStatsSummary(
                averagePercent: 0,
                totalSessions: 0,
                averagePresent: 0,
                averageTotal: 0
            )
        }

        let averagePercent = Int(reports.map { $0.percentPresent }.reduce(0, +) / reports.count)
        let averagePresent = Int(reports.map { $0.presentCount }.reduce(0, +) / reports.count)
        let averageTotal = Int(reports.map { $0.totalMembers }.reduce(0, +) / reports.count)

        return AttendanceGroupStatsSummary(
            averagePercent: averagePercent,
            totalSessions: reports.count,
            averagePresent: averagePresent,
            averageTotal: averageTotal
        )
    }

    func memberStats(
        ownerUid: String,
        branchName: String,
        groupKey: String,
        memberId: String,
        today: Date = Date()
    ) -> AttendanceMemberStats {
        let calendar = Calendar.current

        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
        let yearBack = calendar.date(byAdding: .year, value: -1, to: today) ?? today

        let monthStartIso = Self.isoString(monthStart)
        let yearBackIso = Self.isoString(yearBack)
        let todayIso = Self.isoString(today)
        let endIsoExclusive = Self.isoString(calendar.date(byAdding: .day, value: 1, to: today) ?? today)

        let days = listReportDaysInRange(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey,
            startIso: yearBackIso,
            endIsoExclusive: endIsoExclusive
        ).sorted(by: >)

        var monthPresent = 0
        var monthTotal = 0
        var yearPresent = 0
        var yearTotal = 0

        var streakDays = 0
        var streakOpen = true

        var bestDayCounts: [Int: [String]] = [:]
        var lastSessions: [String] = []

        for dateIso in days {
            let records = loadRecords(
                ownerUid: ownerUid,
                branchName: branchName,
                groupKey: groupKey,
                dateIso: dateIso
            )

            guard let record = records.first(where: { $0.memberId == memberId }) else {
                continue
            }

            let isPresent = record.status == .present
            let countsInTotals = record.status != .unknown

            if dateIso >= monthStartIso && dateIso <= todayIso && countsInTotals {
                monthTotal += 1
                if isPresent { monthPresent += 1 }
            }

            if dateIso >= yearBackIso && dateIso <= todayIso && countsInTotals {
                yearTotal += 1
                if isPresent { yearPresent += 1 }
            }

            if lastSessions.count < 8 {
                lastSessions.append("\(dateIso) – \(record.status.heb)")
            }

            if isPresent {
                bestDayCounts[1, default: []].append(dateIso)

                if streakOpen {
                    streakDays += 1
                }
            } else if countsInTotals {
                streakOpen = false
            }
        }

        let monthlyPercent = monthTotal > 0 ? Int((Double(monthPresent) / Double(monthTotal)) * 100.0) : 0
        let yearlyPercent = yearTotal > 0 ? Int((Double(yearPresent) / Double(yearTotal)) * 100.0) : 0

        let bestDays = Array((bestDayCounts[1] ?? []).prefix(5))

        return AttendanceMemberStats(
            monthlyPercent: monthlyPercent,
            yearlyPercent: yearlyPercent,
            streakDays: streakDays,
            bestDays: bestDays,
            lastSessions: lastSessions
        )
    }

    private static func isoString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
