import Foundation
import Shared

final class KmiExerciseExplanationResolverIOS {

    static let shared = KmiExerciseExplanationResolverIOS()

    private init() {}

    func get(
        belt: Belt,
        topic: String,
        item: String,
        isEnglish: Bool
    ) -> String {
        Explanations.shared.get(
            belt: belt,
            item: item
        )
    }

    func resolveId(
        belt: Belt,
        topic: String,
        item: String
    ) -> String {
        "\(belt.id)||\(topic)||\(item)"
    }
}
