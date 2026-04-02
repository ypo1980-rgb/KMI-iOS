import Foundation
import FirebaseFirestore

final class AttendanceFirestoreMembersSource: AttendanceRemoteMembersSource {

    func loadMembers(
        ownerUid: String,
        branchName: String,
        groupKey: String
    ) async throws -> [AttendanceMember] {

        let branchClean = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        let groupClean = groupKey.trimmingCharacters(in: .whitespacesAndNewlines)

#if DEBUG
print("🟣 FirestoreMembersSource.loadMembers ownerUid =", ownerUid)
print("🟣 FirestoreMembersSource.loadMembers branchName =", branchClean)
print("🟣 FirestoreMembersSource.loadMembers groupKey =", groupClean)
if branchClean.isEmpty || groupClean.isEmpty {
    print("🟣 FirestoreMembersSource no branch/group filter -> returning all trainees that match available filters")
}
#endif

let db = Firestore.firestore()

        let snap = try await db.collection("users")
            .whereField("role", isEqualTo: "trainee")
            .getDocuments()

#if DEBUG
print("🟣 FirestoreMembersSource trainee docs =", snap.documents.count)
#endif

        let members: [AttendanceMember] = snap.documents.compactMap { doc in
            let data = doc.data()

            let fullName =
                ((data["fullName"] as? String) ??
                 (data["name"] as? String) ??
                 "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let phone =
                ((data["phone"] as? String) ??
                 (data["phoneNumber"] as? String) ??
                 "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let branchesArray =
                (data["branches"] as? [String])?
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty } ?? []

            let singleBranch =
                ((data["branch"] as? String) ??
                 "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let resolvedBranches = branchesArray.isEmpty
                ? (singleBranch.isEmpty ? [] : [singleBranch])
                : branchesArray

            let groupsArray =
                (data["groups"] as? [String])?
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty } ?? []

            let singleGroup =
                ((data["group"] as? String) ??
                 (data["age_group"] as? String) ??
                 (data["ageGroup"] as? String) ??
                 "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let resolvedGroups = groupsArray.isEmpty
                ? (singleGroup.isEmpty ? [] : [singleGroup])
                : groupsArray

#if DEBUG
print("🟣 FirestoreMembersSource doc =", doc.documentID)
print("🟣   fullName =", fullName)
print("🟣   resolvedBranches =", resolvedBranches)
print("🟣   resolvedGroups =", resolvedGroups)
#endif

guard !fullName.isEmpty else {
    return nil
}

if !branchClean.isEmpty, !resolvedBranches.contains(branchClean) {
    #if DEBUG
    print("🟣   skipped by branch filter")
    #endif
    return nil
}

if !groupClean.isEmpty, !resolvedGroups.contains(groupClean) {
    #if DEBUG
    print("🟣   skipped by group filter")
    #endif
    return nil
}

#if DEBUG
print("🟣   included member")
#endif

return AttendanceMember(
                id: doc.documentID,
                fullName: fullName,
                phone: phone,
                notes: ""
            )
        }

        #if DEBUG
        print("🟣 FirestoreMembersSource final members count =", members.count)
        print("🟣 FirestoreMembersSource final members names =", members.map(\.fullName))
        #endif

        return members.sorted { $0.fullName < $1.fullName }
    }
}
