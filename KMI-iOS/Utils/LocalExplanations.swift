import Foundation
import Shared

/// ✅ Temporary iOS-only explanations provider.
/// Later we will replace this with the Shared(KMP) Explanations object.
final class LocalExplanations {

    static let shared = LocalExplanations()
    private init() {}

    func get(belt: Belt, item: String) -> String {
        // TEMP: until we build/export Explanations from KMP.
        return "הסבר מפורט על: \(item)"
    }
}
