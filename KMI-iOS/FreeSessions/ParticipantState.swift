import Foundation

enum ParticipantState: String, Codable, CaseIterable, Identifiable {
    case invited = "INVITED"
    case going = "GOING"
    case onWay = "ON_WAY"
    case arrived = "ARRIVED"
    case cant = "CANT"

    var id: String { rawValue }

    static func from(_ raw: String?) -> ParticipantState {
        guard let raw else { return .invited }
        return ParticipantState(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()) ?? .invited
    }

    var titleHeb: String {
        switch self {
        case .invited: return "הוזמן"
        case .going:   return "מגיע"
        case .onWay:   return "בדרך"
        case .arrived: return "הגעתי"
        case .cant:    return "לא יכול"
        }
    }

    var order: Int {
        switch self {
        case .invited: return 0
        case .going:   return 1
        case .onWay:   return 2
        case .arrived: return 3
        case .cant:    return 4
        }
    }
}
