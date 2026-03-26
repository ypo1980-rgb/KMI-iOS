import Foundation

struct FreeSessionPart: Identifiable, Codable, Hashable {
    let uid: String
    let name: String
    let state: ParticipantState
    let updatedAt: Int64

    var id: String { uid }
}
