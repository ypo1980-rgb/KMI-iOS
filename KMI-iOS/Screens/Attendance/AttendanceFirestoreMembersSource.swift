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
         * שומרים את ערכי הסניף והקבוצה לצורך החיפוש.
         * חישוב groupId מנרמל מקפים ורווחים
         * בהתאם למימוש העדכני של Android.
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

        guard !branchStorageValue.isEmpty,
              !groupStorageValue.isEmpty else {
            throw NSError(
                domain: "AttendanceFirestoreMembersSource",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "A branch and group are required."
                ]
            )
        }

        try Task.checkCancellation()

        let db = Firestore.firestore()

        var existingMembers: [AttendanceMember] = []
        var existingMemberIDsByAuthUID: [String: String] = [:]

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

                        let member = AttendanceMember(
                            id: memberId,
                            fullName:
                                fullName.isEmpty
                                ? phone
                                : fullName,
                            phone: phone,
                            notes: readNotes(from: data)
                        )

                        let authUID =
                            (data["authUid"] as? String ?? "")
                                .trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                )

                        if !authUID.isEmpty {
                            existingMemberIDsByAuthUID[authUID] =
                                member.id
                        }

                        return member
                    }

            /*
             * שומרים את חברי הקבוצה הקיימים,
             * וממשיכים לבדוק משתמשים חסרים.
             */
            existingMembers = groupMembers
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

            let codec =
                RegistrationFormState.BranchAssignmentsCodec.self

            let matchesAssignment: Bool

            if data[codec.firestoreKey] != nil {
                /*
                 * כאשר קיים שיוך מפורש, הקבוצה
                 * חייבת להיות משויכת לאותו סניף.
                 * שדה פגום אינו מאפשר חזרה לערכים ישנים.
                 */
                guard let objects =
                    data[codec.firestoreKey] as? [Any] else {
                    return nil
                }

                let assignments = codec.fromFirestoreList(objects)

                matchesAssignment = assignments.contains {
                    assignment in

                    let branchMatches = hasSoftMatch(
                        storedValues: [
                            normalizeKey(assignment.branch)
                        ],
                        candidates: branchCandidates
                    )

                    let assignedGroups = assignment.groups.reduce(
                        into: Set<String>()
                    ) { result, group in
                        result.formUnion(groupAliases(group))
                    }

                    let groupMatches = hasSoftMatch(
                        storedValues: assignedGroups,
                        candidates: groupCandidates
                    )

                    return branchMatches && groupMatches
                }
            } else {
                /*
                 * תאימות לפרופילים ישנים שאין בהם
                 * שדה שיוכים מפורש.
                 */
                matchesAssignment =
                    hasSoftMatch(
                        storedValues: storedBranches,
                        candidates: branchCandidates
                    ) &&
                    hasSoftMatch(
                        storedValues: storedGroups,
                        candidates: groupCandidates
                    )
            }

            guard matchesAssignment else {
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

        var resolvedByID: [String: AttendanceMember] = [:]

        for member in existingMembers {
            guard let numericID = Int64(member.id),
                  numericID > 0 else {
                /*
                 * לא משנים מזהה קיים באופן אוטומטי.
                 * נדרש בירור כדי לשמור על ההיסטוריה.
                 */
                throw NSError(
                    domain: "AttendanceFirestoreMembersSource",
                    code: 2,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "An existing attendance member has an invalid identifier."
                    ]
                )
            }

            resolvedByID[member.id] = member
        }

        for candidate in uniqueMembers.values {
            try Task.checkCancellation()

            /*
             * כאן candidate.id הוא Firebase UID
             * של המשתמש שנמצא באוסף users.
             */
            if let memberID =
                existingMemberIDsByAuthUID[candidate.id],
               resolvedByID[memberID] != nil {
                continue
            }

            /*
             * ה־Repository מחפש לפי authUid ואז שם,
             * ומשתמש במזהה מספרי תואם Android.
             * אין כאן יצירת מזהים או כתיבה מקומית.
             */
            let resolvedMember = try await AttendanceRepository.shared
                .addManualMemberToFirestore(
                    ownerUid: ownerUid,
                    branchName: branchStorageValue,
                    groupKey: groupStorageValue,
                    fullName: candidate.fullName,
                    phone: candidate.phone,
                    notes: candidate.notes,
                    authUid: candidate.id
                )

            resolvedByID[resolvedMember.id] = resolvedMember
        }

        return resolvedByID.values.sorted {
            $0.fullName.localizedCaseInsensitiveCompare(
                $1.fullName
            ) == .orderedAscending
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
        func normalizedIdentity(_ value: String) -> String {
            value
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .replacingOccurrences(of: "־", with: "-")
                .replacingOccurrences(of: "–", with: "-")
                .replacingOccurrences(of: "—", with: "-")
                .replacingOccurrences(
                    of: "\u{00A0}",
                    with: " "
                )
                .replacingOccurrences(
                    of: "\\s+",
                    with: " ",
                    options: .regularExpression
                )
                .lowercased()
        }

        let branch = normalizedIdentity(branchName)
        let group = normalizedIdentity(groupKey)
        let rawValue = "\(branch)|\(group)"

        let digest = SHA256.hash(
            data: Data(rawValue.utf8)
        )

        var value: UInt64 = 0

        for byte in digest.prefix(8) {
            value = (value << 8) | UInt64(byte)
        }

        let positiveValue =
            value & UInt64(Int64.max)

        let identifier =
            positiveValue == 0 ? 1 : positiveValue

        return "g_\(identifier)"
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
        let stored = Set(
            storedValues
                .map { normalizeKey($0) }
                .filter { !$0.isEmpty }
        )

        let requested = Set(
            candidates
                .map { normalizeKey($0) }
                .filter { !$0.isEmpty }
        )

        guard !stored.isEmpty,
              !requested.isEmpty else {
            return false
        }

        return !stored.isDisjoint(with: requested)
    }
}
