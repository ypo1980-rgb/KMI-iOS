import Foundation
import Combine

/// מנהל פרטיות גלובלי לשכבת התצוגה ולייצוא PDF.
/// אינו משנה נתוני משתמש, Firestore או הרשאות.
@MainActor
final class DemoPrivacy: ObservableObject {

    static let shared = DemoPrivacy()

    private static let preferenceKey = "demo_privacy_enabled"

    private let defaults: UserDefaults

    @Published private(set) var isEnabled: Bool

    private init() {
        let defaults = UserDefaults.standard

        self.defaults = defaults
        self.isEnabled = defaults.bool(
            forKey: Self.preferenceKey
        )
    }

    /// מפעיל או מכבה ושומר את הבחירה במכשיר.
    func setEnabled(_ value: Bool) {
        defaults.set(
            value,
            forKey: Self.preferenceKey
        )

        guard isEnabled != value else { return }

        isEnabled = value
    }

    /// מחליף מצב ומחזיר את הערך החדש.
    @discardableResult
    func toggle() -> Bool {
        let newValue = !isEnabled
        setEnabled(newValue)
        return newValue
    }
}
