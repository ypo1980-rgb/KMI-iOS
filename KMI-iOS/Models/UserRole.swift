import Foundation

enum KmiUserRole: String, CaseIterable, Identifiable {
    case coach = "coach"
    case trainee = "trainee"

    var id: String { rawValue }

    var heb: String {
        switch self {
        case .coach:
            return "מאמן"
        case .trainee:
            return "מתאמן"
        }
    }

    static func fromId(_ id: String?) -> KmiUserRole? {
        guard let normalized = id?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return nil
        }
        return KmiUserRole(rawValue: normalized)
    }
}
