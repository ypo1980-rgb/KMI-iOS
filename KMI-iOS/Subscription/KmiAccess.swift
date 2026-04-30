import Foundation

private enum KmiAccessKeys {
    static let trialStartMillis = "trial_start_millis"
    static let hasFullAccess = "has_full_access"
    static let isAdmin = "is_admin"
    static let devUnlock = "dev_unlock"
}

private let DEV_UNLOCK_CODE = "KMI-SECRET-2025"
private let TRIAL_DURATION_MILLIS: Int64 = 3 * 24 * 60 * 60 * 1000

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
        defaults.removeObject(forKey: KmiAccessKeys.devUnlock)
    }

    // MARK: - Trial

    static func ensureTrialStarted(defaults: UserDefaults = .standard) {
        guard !isAdmin(defaults: defaults) else { return }

        if defaults.object(forKey: KmiAccessKeys.trialStartMillis) == nil {
            defaults.set(currentTimeMillis(), forKey: KmiAccessKeys.trialStartMillis)
        }
    }

    static func isTrialActive(defaults: UserDefaults = .standard) -> Bool {
        if isAdmin(defaults: defaults) { return false }

        let start = defaults.object(forKey: KmiAccessKeys.trialStartMillis) as? Int64 ?? 0
        guard start > 0 else { return false }

        let now = currentTimeMillis()
        return now - start < TRIAL_DURATION_MILLIS
    }

    static func trialDaysLeft(defaults: UserDefaults = .standard) -> Int {
        if isAdmin(defaults: defaults) { return 0 }

        let start = defaults.object(forKey: KmiAccessKeys.trialStartMillis) as? Int64 ?? 0
        guard start > 0 else { return 0 }

        let now = currentTimeMillis()
        let remaining = TRIAL_DURATION_MILLIS - (now - start)
        guard remaining > 0 else { return 0 }

        let dayMillis: Int64 = 24 * 60 * 60 * 1000
        return max(Int(remaining / dayMillis), 0)
    }

    // MARK: - Full Access

    static func setFullAccess(_ value: Bool, defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: KmiAccessKeys.hasFullAccess)
    }

    static func hasFullAccess(defaults: UserDefaults = .standard) -> Bool {
        isAdmin(defaults: defaults)
        || hasDevUnlock(defaults: defaults)
        || defaults.bool(forKey: KmiAccessKeys.hasFullAccess)
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

    private static func currentTimeMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}
