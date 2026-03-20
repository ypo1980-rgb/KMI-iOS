import Foundation

struct TrainingData: Identifiable, Hashable {
    let id: String
    let date: Date
    let startText: String
    let endText: String
    let place: String
    let address: String
    let coach: String

    var startMillis: Int64 {
        Int64(date.timeIntervalSince1970 * 1000)
    }

    func isPast(now: Date = Date(), graceMinutes: Int = 0) -> Bool {
        let cutoff = now.addingTimeInterval(TimeInterval(-graceMinutes * 60))
        return date < cutoff
    }
}

struct TrainingSlot: Identifiable, Hashable {
    let id: String
    let branch: String
    let groups: [String]
    let dayOfWeek: Int   // 1=Sunday ... 7=Saturday
    let startHour: Int
    let startMinute: Int
    let durationMinutes: Int
    let place: String
    let address: String
    let coach: String
}
