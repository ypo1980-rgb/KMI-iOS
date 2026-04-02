import Foundation

protocol AttendanceMembersProvider {
    func loadMembers(
        ownerUid: String,
        branchName: String,
        groupKey: String
    ) async throws -> [AttendanceMember]
}
