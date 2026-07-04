import Foundation
import Shared

final class LocalExplanations {

    static let shared = LocalExplanations()
    private init() {}

    func get(
        belt: Belt,
        item: String,
        isEnglish: Bool
    ) -> String {
        if isEnglish {
            return "Detailed explanation for: \(item)"
        }

        return get(
            belt: belt,
            item: item
        )
    }

    func get(
        belt: Belt,
        item: String
    ) -> String {
        return "הסבר מפורט על: \(item)"
    }
}
