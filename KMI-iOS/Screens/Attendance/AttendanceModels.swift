import Foundation

enum AttendanceStatus: String, Codable, CaseIterable, Hashable {
    case present = "PRESENT"
    case absent = "ABSENT"
    case excused = "EXCUSED"
    case unknown = "UNKNOWN"

    var heb: String {
        localized(isEnglish: false)
    }

    var en: String {
        localized(isEnglish: true)
    }

    func localized(isEnglish: Bool) -> String {
        switch self {
        case .present:
            return isEnglish ? "Present" : "הגיע"
        case .absent:
            return isEnglish ? "Absent" : "לא הגיע"
        case .excused:
            return isEnglish ? "Excused" : "מוצדק"
        case .unknown:
            return isEnglish ? "Not marked" : "לא סומן"
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
    
    private func displayDate(_ iso: String) -> String {
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd"
        
        guard let date = input.date(from: iso) else {
            return iso
        }
        
        let output = DateFormatter()
        output.locale = isEnglish ? Locale(identifier: "en_US") : Locale(identifier: "he_IL")
        output.dateFormat = isEnglish ? "MMM d, yyyy" : "dd/MM/yyyy"
        return output.string(from: date)
    }
    
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
        
        lines.append(tr("דו״ח נוכחות", "Attendance Report"))
        lines.append("\(tr("תאריך", "Date")): \(displayDate(dateIso))")
        
        if !branchName.trimmed().isEmpty {
            lines.append("\(tr("סניף", "Branch")): \(branchName.trimmed())")
        }
        
        if !groupKey.trimmed().isEmpty {
            lines.append("\(tr("קבוצה", "Group")): \(groupKey.trimmed())")
        }
        
        if !coachName.trimmed().isEmpty {
            lines.append("\(tr("מאמן", "Coach")): \(coachName.trimmed())")
        }
        
        lines.append("")
        lines.append("\(tr("סיכום", "Summary")):")
        lines.append("\(tr("סה״כ מתאמנים", "Total trainees")): \(summary.totalMembers)")
        lines.append("\(tr("הגיעו", "Present")): \(summary.presentCount)")
        lines.append("\(tr("מוצדק", "Excused")): \(summary.excusedCount)")
        lines.append("\(tr("לא הגיעו", "Absent")): \(summary.absentCount)")
        lines.append("\(tr("לא סומנו", "Not marked")): \(summary.unknownCount)")
        lines.append("\(tr("אחוז נוכחות", "Attendance rate")): \(summary.attendancePercent)%")
        lines.append("")
        
        if rows.isEmpty {
            lines.append(tr("אין מתאמנים ברשימה", "No trainees in the list"))
        } else {
            lines.append("\(tr("פירוט", "Details")):")
            for row in rows {
                lines.append("- \(row.memberName): \(row.status.localized(isEnglish: isEnglish))")
                
                if !row.phone.trimmed().isEmpty {
                    lines.append("  \(tr("טלפון", "Phone")): \(row.phone.trimmed())")
                }
                
                if !row.attendanceNote.trimmed().isEmpty {
                    lines.append("  \(tr("הערת נוכחות", "Attendance note")): \(row.attendanceNote.trimmed())")
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
