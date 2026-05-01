import Foundation

private enum KmiAccessKeys {
    static let trialStartMillis = "trial_start_millis"
    static let hasFullAccess = "has_full_access"
    static let isAdmin = "is_admin"
    static let devUnlock = "dev_unlock"
}

// חייב להיות זהה ללוגיקת Android
private let DEV_UNLOCK_CODE = "34567"

// אם נרצה בעתיד להחזיר ניסיון, אפשר להפעיל מחדש.
// כרגע זה מושבת כמו באנדרואיד.
private let FORCE_SUBSCRIPTION_LOCK = false

enum KmiAccess {

    // MARK: - Admin

    static func setAdmin(_ value: Bool, defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: KmiAccessKeys.isAdmin)
    }

    static func isAdmin(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: KmiAccessKeys.isAdmin)
    }

    // MARK: - Dev Unlock

    static func hasDevUnlock(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: KmiAccessKeys.devUnlock)
    }

    @discardableResult
    static func tryDevUnlock(code: String, defaults: UserDefaults = .standard) -> Bool {
        let ok = code.trimmingCharacters(in: .whitespacesAndNewlines) == DEV_UNLOCK_CODE
        if ok {
            defaults.set(true, forKey: KmiAccessKeys.devUnlock)
        }
        return ok
    }

    static func clearDevUnlock(defaults: UserDefaults = .standard) {
        defaults.set(false, forKey: KmiAccessKeys.devUnlock)
    }

    // MARK: - Trial

    static func ensureTrialStarted(defaults: UserDefaults = .standard) {
        // מושבת זמנית כמו באנדרואיד.
        // משאירים את הפונקציה כדי לא לשבור קריאות קיימות.
    }

    static func isTrialActive(defaults: UserDefaults = .standard) -> Bool {
        // כרגע אין תקופת ניסיון פעילה.
        return false
    }

    static func trialDaysLeft(defaults: UserDefaults = .standard) -> Int {
        // כרגע אין תקופת ניסיון פעילה.
        return 0
    }

    // MARK: - Full Access

    static func setFullAccess(_ value: Bool, defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: KmiAccessKeys.hasFullAccess)
    }

    static func clearAllAccessFlags(defaults: UserDefaults = .standard) {
        defaults.set(false, forKey: KmiAccessKeys.isAdmin)
        defaults.set(false, forKey: KmiAccessKeys.devUnlock)
        defaults.set(false, forKey: KmiAccessKeys.hasFullAccess)
        defaults.removeObject(forKey: KmiAccessKeys.trialStartMillis)
    }

    static func hasFullAccess(defaults: UserDefaults = .standard) -> Bool {
        let admin = isAdmin(defaults: defaults)
        let dev = hasDevUnlock(defaults: defaults)
        let full = defaults.bool(forKey: KmiAccessKeys.hasFullAccess)

        if FORCE_SUBSCRIPTION_LOCK && !admin && !dev {
            return false
        }

        return admin || dev || full
    }

    // MARK: - Permissions

    static func canUseTraining(defaults: UserDefaults = .standard) -> Bool {
        hasFullAccess(defaults: defaults) || isTrialActive(defaults: defaults)
    }

    static func canUseExtras(defaults: UserDefaults = .standard) -> Bool {
        hasFullAccess(defaults: defaults)
    }

    static func canUseForum(defaults: UserDefaults = .standard) -> Bool {
        hasFullAccess(defaults: defaults)
    }

    // MARK: - Helpers
}
