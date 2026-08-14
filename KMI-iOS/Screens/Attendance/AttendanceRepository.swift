import Foundation
import FirebaseFirestore
import CryptoKit

protocol AttendanceRemoteMembersSource {
    func loadMembers(
        ownerUid: String,
        branchName: String,
        groupKey: String
    ) async throws -> [AttendanceMember]
}

struct AttendanceMemberHistorySession {
    let dateIso: String
    let status: AttendanceStatus
}

struct AttendanceMemberHistorySnapshot {
    let memberStartDateIso: String
    let sessions: [AttendanceMemberHistorySession]
}

struct AttendanceAndroidSavedReport:
    Identifiable,
    Equatable {

    let id: String
    let branchName: String
    let groupKey: String
    let dateIso: String
    let sessionId: Int64
    let totalMembers: Int
    let presentCount: Int
    let excusedCount: Int
    let absentCount: Int
    let percentPresent: Int
    let createdAtMillis: Int64
}

final class AttendanceRepository {

    static let shared = AttendanceRepository(
        remoteMembersSource: AttendanceFirestoreMembersSource()
    )

    private let store: AttendanceLocalStore
    private let remoteMembersSource: AttendanceRemoteMembersSource?

    init(
        store: AttendanceLocalStore = .shared,
        remoteMembersSource: AttendanceRemoteMembersSource? = nil
    ) {
        self.store = store
        self.remoteMembersSource = remoteMembersSource
    }

    /*
     * קורא את היסטוריית הנוכחות מאותו מבנה Firestore
     * המשמש את אפליקציית Android כמקור האמת.
     */
    func memberAttendanceHistoryFromFirestore(
        branchName: String,
        groupKey: String,
        memberId: String,
        requestedFromIso: String,
        toIso: String
    ) async throws -> AttendanceMemberHistorySnapshot {
        let cleanBranch =
            branchName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let cleanGroup =
            groupKey.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let cleanMemberId =
            memberId.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard
            !cleanBranch.isEmpty,
            !cleanGroup.isEmpty,
            !cleanMemberId.isEmpty,
            requestedFromIso <= toIso
        else {
            return AttendanceMemberHistorySnapshot(
                memberStartDateIso: requestedFromIso,
                sessions: []
            )
        }

        let groupId =
            androidAttendanceGroupDocumentId(
                branchName: cleanBranch,
                groupKey: cleanGroup
            )

        let groupReference =
            Firestore.firestore()
                .collection("attendanceGroups")
                .document(groupId)

        let sessionDocuments =
            try await groupReference
                .collection("sessions")
                .whereField(
                    "date",
                    isGreaterThanOrEqualTo:
                        requestedFromIso
                )
                .whereField(
                    "date",
                    isLessThanOrEqualTo:
                        toIso
                )
                .getDocuments()
                .documents

        var loadedSessions:
            [AttendanceMemberHistorySession] = []

        var earliestExplicitRecordDate: String?

        for sessionDocument in sessionDocuments {
            let data = sessionDocument.data()

            let dateIso =
                ((data["date"] as? String) ??
                 sessionDocument.documentID)
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

            guard
                !dateIso.isEmpty,
                dateIso >= requestedFromIso,
                dateIso <= toIso
            else {
                continue
            }

            let recordDocument =
                try await sessionDocument.reference
                    .collection("records")
                    .document(cleanMemberId)
                    .getDocument()

            let status: AttendanceStatus

            if recordDocument.exists,
               let recordData = recordDocument.data() {
                status =
                    attendanceStatus(
                        from:
                            recordData["status"]
                                as? String
                    )

                if earliestExplicitRecordDate == nil ||
                    dateIso <
                        earliestExplicitRecordDate! {
                    earliestExplicitRecordDate =
                        dateIso
                }
            } else {
                /*
                 * בהתאם לאנדרואיד:
                 * אימון קיים ללא רשומה מפורשת
                 * נחשב כהיעדרות.
                 */
                status = .absent
            }

            loadedSessions.append(
                AttendanceMemberHistorySession(
                    dateIso: dateIso,
                    status: status
                )
            )
        }

        let memberDocument =
            try await groupReference
                .collection("members")
                .document(cleanMemberId)
                .getDocument()

        let createdAtDateIso: String?

        if let createdAtMillis =
            memberDocument.data()?["createdAtMillis"]
                as? Int64,
           createdAtMillis > 0 {
            createdAtDateIso =
                Self.isoString(
                    Date(
                        timeIntervalSince1970:
                            TimeInterval(
                                createdAtMillis
                            ) / 1_000
                    )
                )
        } else if let createdAtNumber =
                    memberDocument
                        .data()?["createdAtMillis"]
                        as? NSNumber,
                  createdAtNumber.int64Value > 0 {
            createdAtDateIso =
                Self.isoString(
                    Date(
                        timeIntervalSince1970:
                            TimeInterval(
                                createdAtNumber
                                    .int64Value
                            ) / 1_000
                    )
                )
        } else {
            createdAtDateIso = nil
        }

        let detectedStartDate =
            [
                createdAtDateIso,
                earliestExplicitRecordDate
            ]
            .compactMap { $0 }
            .min() ?? requestedFromIso

        let memberStartDateIso =
            max(
                requestedFromIso,
                detectedStartDate
            )

        let sessions =
            loadedSessions
                .filter {
                    $0.dateIso >= memberStartDateIso
                }
                .sorted {
                    $0.dateIso > $1.dateIso
                }

        return AttendanceMemberHistorySnapshot(
            memberStartDateIso:
                memberStartDateIso,
            sessions:
                sessions
        )
    }

    /*
     * מחזיר את דו״חות הנוכחות האחרונים מאותו
     * מבנה Firestore המשמש את Android.
     */
    func recentAttendanceReportsFromFirestore(
        branchName: String,
        groupKey: String,
        limit: Int = 5
    ) async throws -> [AttendanceAndroidSavedReport] {
        let cleanBranch =
            branchName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let cleanGroup =
            groupKey.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard
            !cleanBranch.isEmpty,
            !cleanGroup.isEmpty,
            limit > 0
        else {
            return []
        }

        let groupId =
            androidAttendanceGroupDocumentId(
                branchName: cleanBranch,
                groupKey: cleanGroup
            )

        let snapshot =
            try await Firestore.firestore()
                .collection("attendanceGroups")
                .document(groupId)
                .collection("reports")
                .order(
                    by: "createdAtMillis",
                    descending: true
                )
                .limit(to: limit)
                .getDocuments()

        return snapshot.documents
            .compactMap { document in
                let data = document.data()

                let dateIso =
                    ((data["date"] as? String) ??
                     (data["dateIso"] as? String) ??
                     "")
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )

                guard !dateIso.isEmpty else {
                    return nil
                }

                let totalMembers =
                    integerValue(
                        data["totalMembers"]
                    )

                let presentCount =
                    integerValue(
                        data["presentCount"]
                    )

                let excusedCount =
                    integerValue(
                        data["excusedCount"]
                    )

                let absentCount =
                    integerValue(
                        data["absentCount"]
                    )

                let storedPercent =
                    integerValue(
                        data["percentPresent"]
                    )

                let calculatedPercent =
                    totalMembers > 0
                    ? Int(
                        Double(presentCount) *
                        100.0 /
                        Double(totalMembers)
                    )
                    : 0

                return AttendanceAndroidSavedReport(
                    id: document.documentID,
                    branchName:
                        ((data["branch"] as? String) ??
                         cleanBranch)
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            ),
                    groupKey:
                        ((data["groupKey"] as? String) ??
                         cleanGroup)
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            ),
                    dateIso:
                        dateIso,
                    sessionId:
                        int64Value(
                            data["sessionId"]
                        ),
                    totalMembers:
                        totalMembers,
                    presentCount:
                        presentCount,
                    excusedCount:
                        excusedCount,
                    absentCount:
                        absentCount,
                    percentPresent:
                        min(
                            100,
                            max(
                                0,
                                storedPercent > 0
                                ? storedPercent
                                : calculatedPercent
                            )
                        ),
                    createdAtMillis:
                        int64Value(
                            data["createdAtMillis"]
                        )
                )
            }
            .sorted { left, right in
                if left.createdAtMillis ==
                    right.createdAtMillis {
                    return left.dateIso >
                        right.dateIso
                }

                return left.createdAtMillis >
                    right.createdAtMillis
            }
    }

    private func integerValue(
        _ rawValue: Any?
    ) -> Int {
        if let value = rawValue as? Int {
            return value
        }

        if let value = rawValue as? Int64 {
            return Int(value)
        }

        if let value = rawValue as? NSNumber {
            return value.intValue
        }

        if let value = rawValue as? String {
            return Int(value) ?? 0
        }

        return 0
    }

    private func int64Value(
        _ rawValue: Any?
    ) -> Int64 {
        if let value = rawValue as? Int64 {
            return value
        }

        if let value = rawValue as? Int {
            return Int64(value)
        }

        if let value = rawValue as? NSNumber {
            return value.int64Value
        }

        if let value = rawValue as? String {
            return Int64(value) ?? 0
        }

        return 0
    }

    /*
     * Android יוצר את מזהה הקבוצה משמונת הבתים
     * הראשונים של SHA-256 ומאפס את סיבית הסימן.
     */
    private func androidAttendanceGroupDocumentId(
        branchName: String,
        groupKey: String
    ) -> String {
        let rawValue =
            "\(branchName.trimmingCharacters(in: .whitespacesAndNewlines))|\(groupKey.trimmingCharacters(in: .whitespacesAndNewlines))"
                .lowercased()

        let digest =
            SHA256.hash(
                data: Data(rawValue.utf8)
            )

        var value: UInt64 = 0

        for byte in digest.prefix(8) {
            value =
                (value << 8) |
                UInt64(byte)
        }

        let positiveValue =
            value &
            UInt64(Int64.max)

        return String(
            positiveValue == 0
                ? 1
                : positiveValue
        )
    }

    private func attendanceStatus(
        from rawValue: String?
    ) -> AttendanceStatus {
        switch rawValue?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .uppercased() {
        case "PRESENT":
            return .present

        case "EXCUSED":
            return .excused

        case "ABSENT":
            return .absent

        case "UNKNOWN":
            return .unknown

        default:
            /*
             * זהה להתנהגות Android כאשר
             * סטטוס אינו קיים או אינו תקין.
             */
            return .absent
        }
    }
    
    func loadRealMembers(
        ownerUid: String,
        branchName: String,
        groupKey: String
    ) async throws -> [AttendanceMember] {
        guard let remoteMembersSource else {
            return []
        }

        let members = try await remoteMembersSource.loadMembers(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey
        )

        return uniqueMembers(members)
    }
    
    // MARK: - Local fallback members (optional only)

    func loadMembers(
        ownerUid: String,
        branchName: String,
        groupKey: String
    ) -> [AttendanceMember] {
        uniqueMembers(
            store.loadMembers(
                ownerUid: ownerUid,
                branchName: branchName,
                groupKey: groupKey
            )
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
            members: uniqueMembers(members)
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

    func saveReport(
        state: AttendanceUiState,
        records: [AttendanceRecord]
    ) {
        store.saveRecords(
            ownerUid: state.ownerUid,
            branchName: state.branchName,
            groupKey: state.groupKey,
            dateIso: state.dateIso,
            records: records
        )

        let documentId = reportDocumentId(
            ownerUid: state.ownerUid,
            branchName: state.branchName,
            groupKey: state.groupKey,
            dateIso: state.dateIso
        )

        var data = state.firestoreReportMap
        data["recordsCount"] = records.count
        data["createdOrUpdatedAt"] = FieldValue.serverTimestamp()

        Firestore.firestore()
            .collection("attendanceReports")
            .document(documentId)
            .setData(data, merge: true)
    }

    func loadRecordsFromFirestore(
        ownerUid: String,
        branchName: String,
        groupKey: String,
        dateIso: String
    ) async throws -> [AttendanceRecord] {
        let documentId = reportDocumentId(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey,
            dateIso: dateIso
        )

        let snapshot = try await Firestore.firestore()
            .collection("attendanceReports")
            .document(documentId)
            .getDocument()

        guard let data = snapshot.data() else {
            return []
        }

        let rawRecords = data["records"] as? [[String: Any]] ?? []

        return rawRecords.compactMap { recordData in
            let recordId =
                ((recordData["id"] as? String) ??
                 (recordData["recordId"] as? String) ??
                 "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return AttendanceRecord.fromFirestore(
                id: recordId.isEmpty ? UUID().uuidString : recordId,
                data: recordData
            )
        }
    }

    func listReportDaysInRangeFromFirestore(
        ownerUid: String,
        branchName: String,
        groupKey: String,
        startIso: String,
        endIsoExclusive: String
    ) async throws -> Set<String> {
        let snapshot = try await Firestore.firestore()
            .collection("attendanceReports")
            .whereField("ownerUid", isEqualTo: ownerUid.trimmingCharacters(in: .whitespacesAndNewlines))
            .getDocuments()

        let cleanBranch = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanGroup = groupKey.trimmingCharacters(in: .whitespacesAndNewlines)

        let days = snapshot.documents.compactMap { doc -> String? in
            let data = doc.data()

            let dateIso =
                ((data["dateIso"] as? String) ??
                 (data["date"] as? String) ??
                 "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let reportBranch =
                ((data["branchName"] as? String) ??
                 (data["branch"] as? String) ??
                 "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let reportGroup =
                ((data["groupKey"] as? String) ??
                 (data["group"] as? String) ??
                 "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !dateIso.isEmpty else {
                return nil
            }

            guard dateIso >= startIso, dateIso < endIsoExclusive else {
                return nil
            }

            if !cleanBranch.isEmpty, reportBranch != cleanBranch {
                return nil
            }

            if !cleanGroup.isEmpty, reportGroup != cleanGroup {
                return nil
            }

            return dateIso
        }

        return Set(days)
    }

    private func reportDocumentId(
        ownerUid: String,
        branchName: String,
        groupKey: String,
        dateIso: String
    ) -> String {
        [
            ownerUid,
            branchName,
            groupKey,
            dateIso
        ]
        .map { safeDocumentPart($0) }
        .joined(separator: "_")
    }

    private func safeDocumentPart(_ value: String) -> String {
        let clean = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: "#", with: "-")
            .replacingOccurrences(of: "?", with: "-")
            .replacingOccurrences(of: "[", with: "-")
            .replacingOccurrences(of: "]", with: "-")
            .replacingOccurrences(of: "*", with: "-")
            .replacingOccurrences(of: " ", with: "_")

        return clean.isEmpty ? "_" : clean
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

        let documentId = reportDocumentId(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey,
            dateIso: dateIso
        )

        Firestore.firestore()
            .collection("attendanceReports")
            .document(documentId)
            .delete()
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

        return days
            .sorted(by: >)
            .map { dateIso in
                let records = loadRecords(
                    ownerUid: ownerUid,
                    branchName: branchName,
                    groupKey: groupKey,
                    dateIso: dateIso
                )

                let present = records.filter { $0.status == .present }.count
                let excused = records.filter { $0.status == .excused }.count
                let absent = records.filter { $0.status == .absent }.count
                let unknown = records.filter { $0.status == .unknown }.count
                let total = records.count

                return AttendanceSavedReport(
                    id: dateIso,
                    dateIso: dateIso,
                    totalMembers: total,
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

        let averagePercent = Int(
            (Double(reports.map { $0.percentPresent }.reduce(0, +)) / Double(reports.count))
                .rounded()
        )

        let averagePresent = Int(
            (Double(reports.map { $0.presentCount }.reduce(0, +)) / Double(reports.count))
                .rounded()
        )

        let averageTotal = Int(
            (Double(reports.map { $0.totalMembers }.reduce(0, +)) / Double(reports.count))
                .rounded()
        )

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
        let isEnglish = Self.isEnglishLanguage()

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

        var lastSessions: [String] = []
        var bestDayCounts: [Int: Int] = [:]

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

            if isPresent,
               let date = Self.date(fromIso: dateIso) {
                let weekday = calendar.component(.weekday, from: date)
                bestDayCounts[weekday, default: 0] += 1
            }

            if lastSessions.count < 8 {
                let dateText = Self.displayDateString(fromIso: dateIso, isEnglish: isEnglish)
                let statusText = Self.localizedStatus(record.status, isEnglish: isEnglish)
                lastSessions.append("\(dateText) – \(statusText)")
            }

            if isPresent {
                if streakOpen { streakDays += 1 }
            } else if countsInTotals {
                streakOpen = false
            }
        }

        let monthlyPercent = monthTotal > 0 ? Int((Double(monthPresent) / Double(monthTotal)) * 100.0) : 0
        let yearlyPercent = yearTotal > 0 ? Int((Double(yearPresent) / Double(yearTotal)) * 100.0) : 0

        let bestDays = bestDayCounts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }

                return lhs.value > rhs.value
            }
            .prefix(6)
            .map { weekday, _ in
                Self.localizedWeekday(weekday, isEnglish: isEnglish)
            }

        return AttendanceMemberStats(
            monthlyPercent: monthlyPercent,
            yearlyPercent: yearlyPercent,
            streakDays: streakDays,
            bestDays: Array(bestDays),
            lastSessions: lastSessions
        )
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

    private static func isEnglishLanguage() -> Bool {
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

    private static func localizedStatus(_ status: AttendanceStatus, isEnglish: Bool) -> String {
        switch status {
        case .present:
            return isEnglish ? "Present" : "הגיע"
        case .excused:
            return isEnglish ? "Excused" : "מוצדק"
        case .absent:
            return isEnglish ? "Absent" : "לא הגיע"
        case .unknown:
            return isEnglish ? "Not marked" : "לא סומן"
        }
    }

    private static func localizedWeekday(_ weekday: Int, isEnglish: Bool) -> String {
        switch weekday {
        case 1:
            return isEnglish ? "Sun" : "ראשון"
        case 2:
            return isEnglish ? "Mon" : "שני"
        case 3:
            return isEnglish ? "Tue" : "שלישי"
        case 4:
            return isEnglish ? "Wed" : "רביעי"
        case 5:
            return isEnglish ? "Thu" : "חמישי"
        case 6:
            return isEnglish ? "Fri" : "שישי"
        case 7:
            return isEnglish ? "Sat" : "שבת"
        default:
            return isEnglish ? "Day" : "יום"
        }
    }

    private static func date(fromIso iso: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: iso)
    }

    private static func displayDateString(fromIso iso: String, isEnglish: Bool) -> String {
        guard let date = date(fromIso: iso) else {
            return iso
        }

        let f = DateFormatter()
        f.locale = isEnglish ? Locale(identifier: "en_US") : Locale(identifier: "he_IL")
        f.dateFormat = isEnglish ? "MMM d, yyyy" : "dd/MM/yyyy"
        return f.string(from: date)
    }
    
    private static func isoString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
