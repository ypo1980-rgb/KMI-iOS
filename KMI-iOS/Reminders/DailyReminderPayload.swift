import Foundation

struct DailyReminderPayload: Codable, Hashable, Identifiable {
    let id: String
    let beltId: String
    let beltHeb: String
    let topic: String
    let item: String
    let explanation: String
    let extraCount: Int
    let lastItemKey: String

    init(
        id: String = UUID().uuidString,
        beltId: String,
        beltHeb: String,
        topic: String,
        item: String,
        explanation: String,
        extraCount: Int,
        lastItemKey: String
    ) {
        self.id = id
        self.beltId = beltId
        self.beltHeb = beltHeb
        self.topic = topic
        self.item = item
        self.explanation = explanation
        self.extraCount = extraCount
        self.lastItemKey = lastItemKey
    }
}
