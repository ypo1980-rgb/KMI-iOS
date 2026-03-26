import Foundation

struct FreeSession: Identifiable, Codable, Hashable {
    let id: String
    let branch: String
    let groupKey: String
    let title: String
    let locationName: String?
    let lat: Double?
    let lng: Double?
    let startsAt: Int64
    let createdAt: Int64
    let createdByUid: String
    let createdByName: String
    let status: String
    let goingCount: Int
    let onWayCount: Int
    let arrivedCount: Int
    let cantCount: Int

    var totalParticipants: Int {
        goingCount + onWayCount + arrivedCount + cantCount
    }

    var progressValue: Double {
        let total = max(totalParticipants, 1)
        return Double(goingCount + onWayCount + arrivedCount) / Double(total)
    }

    var isOpen: Bool {
        status.uppercased() == "OPEN"
    }
}
