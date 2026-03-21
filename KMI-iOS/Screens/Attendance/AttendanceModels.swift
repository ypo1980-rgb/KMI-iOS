import Foundation

enum AttendanceStatus: String, Codable, CaseIterable, Hashable {
    case present = "PRESENT"
    case absent = "ABSENT"
    case excused = "EXCUSED"
    case unknown = "UNKNOWN"

    var heb: String {
        switch self {
        case .present: return "הגיע"
        case .absent: return "לא הגיע"
        case .excused: return "מוצדק"
        case .unknown: return "לא סומן"
        }
    }

    var sortOrder: Int {
        switch self {
        case .present: return 0
        case .excused: return 1
        case .absent: return 2
        case .unknown: return 3
        }
    }
}

struct AttendanceMember: Identifiable, Codable, Hashable {
    let id: String
    var fullName: String
    var phone: String
    var notes: String

    init(
        id: String = UUID().uuidString,
        fullName: String,
        phone: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.fullName = fullName
        self.phone = phone
        self.notes = notes
    }
}

struct AttendanceRecord: Identifiable, Codable, Hashable {
    let id: String
    let dateIso: String
    let memberId: String
    var status: AttendanceStatus
    var note: String

    init(
        id: String,
        dateIso: String,
        memberId: String,
        status: AttendanceStatus,
        note: String = ""
    ) {
        self.id = id
        self.dateIso = dateIso
        self.memberId = memberId
        self.status = status
        self.note = note
    }
}

struct AttendanceDaySummary: Hashable {
    let totalMembers: Int
    let presentCount: Int
    let absentCount: Int
    let excusedCount: Int
    let unknownCount: Int

    var attendancePercent: Int {
        guard totalMembers > 0 else { return 0 }
        return Int((Double(presentCount) / Double(totalMembers)) * 100.0)
    }

    var presentLabel: String { "\(presentCount)" }
    var absentLabel: String { "\(absentCount)" }
    var excusedLabel: String { "\(excusedCount)" }
    var unknownLabel: String { "\(unknownCount)" }
}

struct AttendanceRowUi: Identifiable, Hashable {
    let memberId: String
    var memberName: String
    var phone: String
    var memberNotes: String
    var status: AttendanceStatus
    var attendanceNote: String

    var id: String { memberId }
}

struct AttendanceUiState {
    var ownerUid: String

    var dateIso: String
    var branchName: String
    var groupKey: String
    var coachName: String

    var members: [AttendanceMember] = []
    var recordsByMemberId: [String: AttendanceRecord] = [:]

    var isSaving: Bool = false
    var lastMessage: String? = nil
    var lastMessageIsError: Bool = false
    var messageEventId: Int64 = 0

    var newMemberName: String = ""
    var newMemberPhone: String = ""
    var newMemberNotes: String = ""

    var reportDaysInMonth: Set<String> = []

    var rows: [AttendanceRowUi] {
        members
            .map { member in
                let record = recordsByMemberId[member.id]
                return AttendanceRowUi(
                    memberId: member.id,
                    memberName: member.fullName,
                    phone: member.phone,
                    memberNotes: member.notes,
                    status: record?.status ?? .unknown,
                    attendanceNote: record?.note ?? ""
                )
            }
            .sorted {
                if $0.status.sortOrder == $1.status.sortOrder {
                    return $0.memberName < $1.memberName
                }
                return $0.status.sortOrder < $1.status.sortOrder
            }
    }

    var summary: AttendanceDaySummary {
        let statuses = members.map { recordsByMemberId[$0.id]?.status ?? .unknown }

        return AttendanceDaySummary(
            totalMembers: members.count,
            presentCount: statuses.filter { $0 == .present }.count,
            absentCount: statuses.filter { $0 == .absent }.count,
            excusedCount: statuses.filter { $0 == .excused }.count,
            unknownCount: statuses.filter { $0 == .unknown }.count
        )
    }

    var shareText: String {
        var lines: [String] = []

        lines.append("דו״ח נוכחות")
        lines.append("תאריך: \(dateIso)")

        if !branchName.trimmed().isEmpty {
            lines.append("סניף: \(branchName.trimmed())")
        }

        if !groupKey.trimmed().isEmpty {
            lines.append("קבוצה: \(groupKey.trimmed())")
        }

        if !coachName.trimmed().isEmpty {
            lines.append("מאמן: \(coachName.trimmed())")
        }

        lines.append("")
        lines.append("סיכום:")
        lines.append("סה״כ מתאמנים: \(summary.totalMembers)")
        lines.append("הגיעו: \(summary.presentCount)")
        lines.append("מוצדק: \(summary.excusedCount)")
        lines.append("לא הגיעו: \(summary.absentCount)")
        lines.append("לא סומנו: \(summary.unknownCount)")
        lines.append("אחוז נוכחות: \(summary.attendancePercent)%")
        lines.append("")

        if rows.isEmpty {
            lines.append("אין מתאמנים ברשימה")
        } else {
            lines.append("פירוט:")
            for row in rows {
                lines.append("- \(row.memberName): \(row.status.heb)")

                if !row.phone.trimmed().isEmpty {
                    lines.append("  טלפון: \(row.phone.trimmed())")
                }

                if !row.attendanceNote.trimmed().isEmpty {
                    lines.append("  הערת נוכחות: \(row.attendanceNote.trimmed())")
                }
            }
        }

        return lines.joined(separator: "\n")
    }
}

private extension String {
    func trimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
