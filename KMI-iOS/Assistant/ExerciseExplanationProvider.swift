import Foundation
import Shared

enum ExerciseExplanationProvider {
    static func get(belt: Belt?, item: String) -> String {
        if let belt {
            return Explanations().get(belt: belt, item: item)
        }

        let beltsToTry: [Belt] = [.yellow, .orange, .green, .blue, .brown, .black]
        let fallbackPrefix = "הסבר מפורט על: "

        for belt in beltsToTry {
            let answer = Explanations().get(belt: belt, item: item)
            if !answer.hasPrefix(fallbackPrefix) {
                return answer
            }
        }

        return Explanations().get(belt: .yellow, item: item)
    }
}
