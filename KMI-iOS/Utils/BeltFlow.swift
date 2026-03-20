import Foundation
import Shared

enum BeltFlow {

    static let ordered: [Belt] = [.white, .yellow, .orange, .green, .blue, .brown, .black]
    static let defaultBelt: Belt = .orange

    static func next(after belt: Belt) -> Belt {
        guard let idx = ordered.firstIndex(of: belt) else { return defaultBelt }
        let nextIdx = min(idx + 1, ordered.count - 1)
        return ordered[nextIdx]
    }

    static func nextBeltForUser(registeredBelt: Belt?) -> Belt {
        guard let b = registeredBelt else { return defaultBelt }
        return next(after: b)
    }

    // ✅ NEW: המרה מהערך שנשמר בשרת -> Belt
    // תומך ב: "orange", "ORANGE", "belt_orange", "belt:orange", "כתומה", וכו'
    static func belt(fromRaw raw: String?) -> Belt? {
        guard var s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        s = s.lowercased()
        s = s.replacingOccurrences(of: "belt", with: "")
        s = s.replacingOccurrences(of: ":", with: "_")
        s = s.replacingOccurrences(of: "__", with: "_")
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "_- "))

        switch s {
        case "white", "לבן": return .white
        case "yellow", "צהוב": return .yellow
        case "orange", "כתום", "כתומה": return .orange
        case "green", "ירוק": return .green
        case "blue", "כחול": return .blue
        case "brown", "חום": return .brown
        case "black", "שחור": return .black
        default:
            return nil
        }
    }
}
