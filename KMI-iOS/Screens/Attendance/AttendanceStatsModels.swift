import Foundation

struct AttendanceSavedReport: Identifiable, Hashable {
    let id: String
    let dateIso: String

    let totalMembers: Int
    let presentCount: Int
    let excusedCount: Int
    let absentCount: Int
    let unknownCount: Int

    var percentPresent: Int {
        guard totalMembers > 0 else { return 0 }
        return Int((Double(presentCount) / Double(totalMembers)) * 100.0)
    }
}

struct AttendanceMemberStats: Hashable {
    let monthlyPercent: Int
    let yearlyPercent: Int
    let streakDays: Int
    let bestDays: [String]
    let lastSessions: [String]
}

struct AttendanceGroupStatsSummary: Hashable {
    let averagePercent: Int
    let totalSessions: Int
    let averagePresent: Int
    let averageTotal: Int
}
