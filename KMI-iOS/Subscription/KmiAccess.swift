import Foundation

private enum KmiAccessKeys {
    static let trialStartMillis = "trial_start_millis"

    static let hasFullAccess = "has_full_access"
    static let fullAccess = "full_access"
    static let subscriptionActive = "subscription_active"
    static let isSubscribed = "is_subscribed"

    static let appStoreSubscriptionVerified = "app_store_subscription_verified"
    static let googleSubscriptionVerified = "google_subscription_verified"

    static let subProduct = "sub_product"
    static let subToken = "sub_token"
    static let subPurchaseTime = "sub_purchase_time"
    static let subAccessUntil = "sub_access_until"

    static let expiredSubToken = "expired_sub_token"
    static let expiredSubAccessUntil = "expired_sub_access_until"
    static let expiredSubProduct = "expired_sub_product"

    static let lastSubToken = "last_sub_token"
    static let lastSubProduct = "last_sub_product"

    static let accessChangedAt = "access_changed_at"

    static let isAdmin = "is_admin"
    static let devUnlock = "dev_unlock"
}

// חייב להיות זהה ללוגיקת Android
private let DEV_UNLOCK_CODE = "34567@"

// אם נרצה בעתיד להחזיר ניסיון, אפשר להפעיל מחדש.
// כרגע זה מושבת כמו באנדרואיד.
private let FORCE_SUBSCRIPTION_LOCK = false

// בזמן בדיקות מנויים: אדמין לא עוקף מנוי,
// כדי שאפשר לבדוק שהמנעולים חוזרים אחרי שהמנוי פג.
private let ADMIN_BYPASSES_SUBSCRIPTION = false

enum KmiAccess {

    // MARK: - Admin

    static func setAdmin(_ value: Bool, defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: KmiAccessKeys.isAdmin)
        defaults.set(currentTimeMillis(), forKey: KmiAccessKeys.accessChangedAt)
        defaults.synchronize()

        NotificationCenter.default.post(
            name: Notification.Name("KMI_ACCESS_CHANGED"),
            object: nil
        )
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
            defaults.set(currentTimeMillis(), forKey: KmiAccessKeys.accessChangedAt)
            defaults.synchronize()

            NotificationCenter.default.post(
                name: Notification.Name("KMI_ACCESS_CHANGED"),
                object: nil
            )
        }

        return ok
    }

    static func clearDevUnlock(defaults: UserDefaults = .standard) {
        defaults.set(false, forKey: KmiAccessKeys.devUnlock)
        defaults.set(currentTimeMillis(), forKey: KmiAccessKeys.accessChangedAt)
        defaults.synchronize()

        NotificationCenter.default.post(
            name: Notification.Name("KMI_ACCESS_CHANGED"),
            object: nil
        )
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
        let nowMillis = currentTimeMillis()

        defaults.set(value, forKey: KmiAccessKeys.hasFullAccess)
        defaults.set(value, forKey: KmiAccessKeys.fullAccess)
        defaults.set(value, forKey: KmiAccessKeys.subscriptionActive)
        defaults.set(value, forKey: KmiAccessKeys.isSubscribed)
        defaults.set(nowMillis, forKey: KmiAccessKeys.accessChangedAt)

        defaults.synchronize()

        NotificationCenter.default.post(
            name: Notification.Name("KMI_ACCESS_CHANGED"),
            object: nil
        )
    }

    static func clearAllAccessFlags(defaults: UserDefaults = .standard) {
        let nowMillis = currentTimeMillis()

        defaults.set(false, forKey: KmiAccessKeys.isAdmin)
        defaults.set(false, forKey: KmiAccessKeys.devUnlock)

        defaults.set(false, forKey: KmiAccessKeys.hasFullAccess)
        defaults.set(false, forKey: KmiAccessKeys.fullAccess)
        defaults.set(false, forKey: KmiAccessKeys.subscriptionActive)
        defaults.set(false, forKey: KmiAccessKeys.isSubscribed)
        defaults.set(false, forKey: KmiAccessKeys.appStoreSubscriptionVerified)
        defaults.set(false, forKey: KmiAccessKeys.googleSubscriptionVerified)

        defaults.removeObject(forKey: KmiAccessKeys.subProduct)
        defaults.removeObject(forKey: KmiAccessKeys.subToken)
        defaults.removeObject(forKey: KmiAccessKeys.subPurchaseTime)
        defaults.removeObject(forKey: KmiAccessKeys.subAccessUntil)
        defaults.removeObject(forKey: KmiAccessKeys.trialStartMillis)

        defaults.set(nowMillis, forKey: KmiAccessKeys.accessChangedAt)
        defaults.synchronize()

        NotificationCenter.default.post(
            name: Notification.Name("KMI_ACCESS_CHANGED"),
            object: nil
        )
    }

    private static func currentTimeMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    private static func int64Value(forKey key: String, defaults: UserDefaults) -> Int64 {
        let value = defaults.object(forKey: key)

        if let int64 = value as? Int64 {
            return int64
        }

        if let int = value as? Int {
            return Int64(int)
        }

        if let double = value as? Double {
            return Int64(double)
        }

        return Int64(defaults.integer(forKey: key))
    }

    private static func hasSubscriptionFlags(defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: KmiAccessKeys.appStoreSubscriptionVerified) ||
        defaults.bool(forKey: KmiAccessKeys.googleSubscriptionVerified) ||
        defaults.bool(forKey: KmiAccessKeys.hasFullAccess) ||
        defaults.bool(forKey: KmiAccessKeys.fullAccess) ||
        defaults.bool(forKey: KmiAccessKeys.subscriptionActive) ||
        defaults.bool(forKey: KmiAccessKeys.isSubscribed) ||
        !(defaults.string(forKey: KmiAccessKeys.subProduct) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    private static func clearExpiredSubscriptionFlags(
        defaults: UserDefaults,
        until: Int64,
        now: Int64
    ) {
        defaults.set(false, forKey: KmiAccessKeys.appStoreSubscriptionVerified)
        defaults.set(false, forKey: KmiAccessKeys.googleSubscriptionVerified)
        defaults.set(false, forKey: KmiAccessKeys.hasFullAccess)
        defaults.set(false, forKey: KmiAccessKeys.fullAccess)
        defaults.set(false, forKey: KmiAccessKeys.subscriptionActive)
        defaults.set(false, forKey: KmiAccessKeys.isSubscribed)

        defaults.removeObject(forKey: KmiAccessKeys.subProduct)
        defaults.removeObject(forKey: KmiAccessKeys.subToken)
        defaults.removeObject(forKey: KmiAccessKeys.subPurchaseTime)
        defaults.removeObject(forKey: KmiAccessKeys.subAccessUntil)

        defaults.set(now, forKey: KmiAccessKeys.accessChangedAt)
        defaults.synchronize()

        NotificationCenter.default.post(
            name: Notification.Name("KMI_ACCESS_CHANGED"),
            object: nil
        )
    }

    static func hasValidTimedSubscription(defaults: UserDefaults = .standard) -> Bool {
        let now = currentTimeMillis()
        let until = int64Value(forKey: KmiAccessKeys.subAccessUntil, defaults: defaults)
        let hasFlags = hasSubscriptionFlags(defaults: defaults)

        let active = hasFlags && until > now

        if !active && hasFlags && until > 0 && until <= now {
            clearExpiredSubscriptionFlags(defaults: defaults, until: until, now: now)
        }

        return active
    }
    
    static func hasFullAccess(defaults: UserDefaults = .standard) -> Bool {
        let admin = isAdmin(defaults: defaults)
        let dev = hasDevUnlock(defaults: defaults)
        let subscription = hasValidTimedSubscription(defaults: defaults)

        if FORCE_SUBSCRIPTION_LOCK && !admin && !dev {
            return false
        }

        if ADMIN_BYPASSES_SUBSCRIPTION && admin {
            return true
        }

        return dev || subscription
    }

    // MARK: - Temporary Test Access

    static func grantTemporarySubscription(
        productId: String,
        durationMinutes: Int,
        defaults: UserDefaults = .standard
    ) {
        let nowMillis = currentTimeMillis()
        let durationMillis = Int64(durationMinutes) * 60 * 1000
        let accessUntil = nowMillis + durationMillis
        let token = "ios_test_\(productId)_\(nowMillis)"

        defaults.set(true, forKey: KmiAccessKeys.hasFullAccess)
        defaults.set(true, forKey: KmiAccessKeys.fullAccess)
        defaults.set(true, forKey: KmiAccessKeys.subscriptionActive)
        defaults.set(true, forKey: KmiAccessKeys.isSubscribed)

        defaults.set(true, forKey: KmiAccessKeys.appStoreSubscriptionVerified)
        defaults.set(false, forKey: KmiAccessKeys.googleSubscriptionVerified)

        defaults.set(productId, forKey: KmiAccessKeys.subProduct)
        defaults.set(token, forKey: KmiAccessKeys.subToken)
        defaults.set(nowMillis, forKey: KmiAccessKeys.subPurchaseTime)
        defaults.set(accessUntil, forKey: KmiAccessKeys.subAccessUntil)

        defaults.set(token, forKey: KmiAccessKeys.lastSubToken)
        defaults.set(productId, forKey: KmiAccessKeys.lastSubProduct)
        defaults.set(nowMillis, forKey: KmiAccessKeys.accessChangedAt)

        defaults.synchronize()

        NotificationCenter.default.post(
            name: Notification.Name("KMI_ACCESS_CHANGED"),
            object: nil
        )
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
