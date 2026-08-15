import Foundation
import FirebaseFirestore
import CryptoKit

final class AttendanceFirestoreMembersSource: AttendanceRemoteMembersSource {

    func loadMembers(
        ownerUid: String,
        branchName: String,
        groupKey: String
    ) async throws -> [AttendanceMember] {

        /*
         * לחישוב groupId חייבים להשתמש בערכים
         * המקוריים בדיוק כפי ש־Android שומר אותם.
         * אסור להחליף סוגי מקפים לפני החישוב.
         */
        let branchStorageValue =
            branchName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let groupStorageValue =
            groupKey.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        /*
         * הערכים המנורמלים משמשים רק לחיפוש
         * הגיבוי באוסף users.
         */
        let branchClean =
            normalize(branchStorageValue)

        let groupClean =
            normalize(groupStorageValue)

        let db = Firestore.firestore()

        /*
         * מקור האמת המשותף ל־Android ול־iOS.
         *
         * מזהה המסמך כאן הוא אותו memberId
         * שמשמש במסמכי records של הנוכחות.
         */
        if !branchStorageValue.isEmpty,
           !groupStorageValue.isEmpty {
            let groupDocumentId =
                androidAttendanceGroupDocumentId(
                    branchName:
                        branchStorageValue,
                    groupKey:
                        groupStorageValue
                )

            let groupMembersSnapshot =
                try await db
                    .collection(
                        "attendanceGroups"
                    )
                    .document(
                        groupDocumentId
                    )
                    .collection("members")
                    .getDocuments()

            let groupMembers =
                groupMembersSnapshot.documents
                    .compactMap {
                        document
                            -> AttendanceMember? in

                        let data =
                            document.data()

                        let isActive =
                            data["isActive"]
                                as? Bool ?? true

                        guard isActive else {
                            return nil
                        }

                        let fullName =
                            ((data["displayName"]
                                as? String) ??
                             (data["fullName"]
                                as? String) ??
                             (data["name"]
                                as? String) ??
                             "")
                                .trimmingCharacters(
                                    in:
                                        .whitespacesAndNewlines
                                )

                        let phone =
                            ((data["phone"]
                                as? String) ??
                             (data["phoneNumber"]
                                as? String) ??
                             "")
                                .trimmingCharacters(
                                    in:
                                        .whitespacesAndNewlines
                                )

                        guard
                            !fullName.isEmpty ||
                            !phone.isEmpty
                        else {
                            return nil
                        }

                        let memberId =
                            firestoreIdentifier(
                                data["id"]
                            ) ??
                            document.documentID

                        return AttendanceMember(
                            id: memberId,
                            fullName:
                                fullName.isEmpty
                                ? phone
                                : fullName,
                            phone: phone,
                            notes:
                                readNotes(
                                    from: data
                                )
                        )
                    }

            /*
             * אם קיימים חברים במבנה Android,
             * לא מערבבים אותם עם משתמשים מהאוסף
             * הישן כדי למנוע מזהים כפולים ושגויים.
             */
            if !groupMembers.isEmpty {
                return groupMembers.sorted {
                    $0.fullName
                        .localizedCaseInsensitiveCompare(
                            $1.fullName
                        ) == .orderedAscending
                }
            }
        }

        /*
         * גיבוי למידע ישן שטרם הועבר למבנה
         * attendanceGroups.
         */
        let snap =
            try await db
                .collection("users")
                .whereField(
                    "role",
                    isEqualTo: "trainee"
                )
                .getDocuments()

        let branchCandidates = branchAliases(branchClean)
        let groupCandidates = groupAliases(groupClean)

        let rawMembers: [(key: String, member: AttendanceMember)] = snap.documents.compactMap { doc in
            let data = doc.data()

            let isActive = data["isActive"] as? Bool ?? true
            guard isActive else {
                return nil
            }

            let fullName =
                ((data["fullName"] as? String) ??
                 (data["name"] as? String) ??
                 (data["displayName"] as? String) ??
                 "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let email =
                ((data["email"] as? String) ??
                 (data["emailLower"] as? String) ??
                 "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            let phone =
                ((data["phone"] as? String) ??
                 (data["phoneNumber"] as? String) ??
                 (data["phone_number"] as? String) ??
                 "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !fullName.isEmpty || !email.isEmpty || !phone.isEmpty else {
                return nil
            }

            let storedBranches = branchValues(from: data)
            let storedGroups = groupValues(from: data)

            let branchMatches =
                branchCandidates.isEmpty ||
                hasSoftMatch(storedValues: storedBranches, candidates: branchCandidates)

            let groupMatches =
                groupCandidates.isEmpty ||
                hasSoftMatch(storedValues: storedGroups, candidates: groupCandidates)

            guard branchMatches && groupMatches else {
                return nil
            }

            let normalizedPhone = phone.filter { $0.isNumber }

            let uniqueKey: String = {
                if !email.isEmpty {
                    return "email:\(email)"
                }

                if !normalizedPhone.isEmpty {
                    return "phone:\(normalizedPhone)"
                }

                return "name:\(fullName.lowercased())"
            }()

            return (
                key: uniqueKey,
                member: AttendanceMember(
                    id: doc.documentID,
                    fullName: fullName.isEmpty ? (email.isEmpty ? phone : email) : fullName,
                    phone: phone,
                    notes: readNotes(from: data)
                )
            )
        }

        var uniqueMembers: [String: AttendanceMember] = [:]

        for item in rawMembers {
            if let existing = uniqueMembers[item.key] {
                let existingPhone = existing.phone.trimmingCharacters(in: .whitespacesAndNewlines)
                let incomingPhone = item.member.phone.trimmingCharacters(in: .whitespacesAndNewlines)

                if existingPhone.isEmpty && !incomingPhone.isEmpty {
                    uniqueMembers[item.key] = item.member
                }
            } else {
                uniqueMembers[item.key] = item.member
            }
        }

        return uniqueMembers.values.sorted {
            $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending
        }
    }

    private func firestoreIdentifier(
        _ rawValue: Any?
    ) -> String? {
        if let value = rawValue as? String {
            let clean =
                value.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            return clean.isEmpty
                ? nil
                : clean
        }

        if let value = rawValue as? Int {
            return String(value)
        }

        if let value = rawValue as? Int64 {
            return String(value)
        }

        if let value = rawValue as? NSNumber {
            return value.stringValue
        }

        return nil
    }

    /*
     * העתק מדויק של stablePositiveLong
     * המשמש את Android ליצירת groupId.
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

    private func readNotes(from data: [String: Any]) -> String {
        ((data["attendanceNotes"] as? String) ??
         (data["coachNotes"] as? String) ??
         (data["notes"] as? String) ??
         "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "־", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private func normalizeKey(_ value: String) -> String {
        normalize(value).lowercased()
    }

    private func splitTokens(_ value: String) -> [String] {
        value
            .replacingOccurrences(of: " • ", with: ",")
            .replacingOccurrences(of: "|", with: ",")
            .replacingOccurrences(of: "\n", with: ",")
            .split(whereSeparator: { char in
                char == "," || char == ";" || char == "；"
            })
            .map { normalize(String($0)) }
            .filter { !$0.isEmpty }
    }

    private func branchAliases(_ value: String) -> Set<String> {
        let clean = normalize(value)
        guard !clean.isEmpty else { return [] }

        return Set([
            clean,
            clean.replacingOccurrences(of: "-", with: "–"),
            clean.replacingOccurrences(of: "-", with: "—"),
            clean.replacingOccurrences(of: "-", with: "־"),
            clean.replacingOccurrences(of: "–", with: "-"),
            clean.replacingOccurrences(of: "—", with: "-"),
            clean.replacingOccurrences(of: "־", with: "-")
        ].map { normalizeKey($0) }.filter { !$0.isEmpty })
    }

    private func groupAliases(_ value: String) -> Set<String> {
        let clean = normalize(value)
        var aliases = Set<String>()

        if !clean.isEmpty {
            aliases.insert(clean)
        }

        for token in splitTokens(clean) {
            aliases.insert(token)
        }

        if clean.contains("נוער") && clean.contains("בוגרים") {
            aliases.insert("נוער")
            aliases.insert("בוגרים")
            aliases.insert("נוער ובוגרים")
            aliases.insert("נוער + בוגרים")
        }

        if clean.localizedCaseInsensitiveContains("children") ||
            clean.localizedCaseInsensitiveContains("kids") {
            aliases.insert("ילדים")
        }

        if clean.localizedCaseInsensitiveContains("youth") {
            aliases.insert("נוער")
        }

        if clean.localizedCaseInsensitiveContains("adult") ||
            clean.localizedCaseInsensitiveContains("adults") {
            aliases.insert("בוגרים")
        }

        return Set(aliases.map { normalizeKey($0) }.filter { !$0.isEmpty })
    }

    private func branchValues(from data: [String: Any]) -> Set<String> {
        var values = Set<String>()

        let keys = [
            "branch",
            "activeBranch",
            "active_branch",
            "branchesCsv",
            "coach_branch",
            "selected_branch",
            "current_branch"
        ]

        for key in keys {
            let raw = ((data[key] as? String) ?? "")
            if splitTokens(raw).isEmpty, !normalize(raw).isEmpty {
                values.insert(normalizeKey(raw))
            } else {
                for token in splitTokens(raw) {
                    values.insert(normalizeKey(token))
                }
            }
        }

        let branches = (data["branches"] as? [String]) ?? []
        for value in branches {
            values.insert(normalizeKey(value))
        }

        return values
    }

    private func groupValues(from data: [String: Any]) -> Set<String> {
        var values = Set<String>()

        let keys = [
            "primaryGroup",
            "activeGroup",
            "active_group",
            "groupKey",
            "group_key",
            "group",
            "groupName",
            "groupsCsv",
            "groupCsv",
            "age_group",
            "ageGroup",
            "coach_groupKey",
            "selected_groupKey",
            "current_groupKey"
        ]

        for key in keys {
            let raw = ((data[key] as? String) ?? "")
            if splitTokens(raw).isEmpty, !normalize(raw).isEmpty {
                values.formUnion(groupAliases(raw))
            } else {
                for token in splitTokens(raw) {
                    values.formUnion(groupAliases(token))
                }
            }
        }

        let groups = (data["groups"] as? [String]) ?? []
        for value in groups {
            values.formUnion(groupAliases(value))
        }

        return values
    }

    private func hasSoftMatch(
        storedValues: Set<String>,
        candidates: Set<String>
    ) -> Bool {
        if candidates.isEmpty {
            return true
        }

        if !storedValues.isDisjoint(with: candidates) {
            return true
        }

        for stored in storedValues {
            for candidate in candidates {
                if stored.count >= 2,
                   candidate.count >= 2,
                   stored.contains(candidate) || candidate.contains(stored) {
                    return true
                }
            }
        }

        return false
    }
}
