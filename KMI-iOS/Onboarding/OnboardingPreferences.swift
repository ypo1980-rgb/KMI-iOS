import Foundation

enum OnboardingPreferences {

    private static let completedVersionKey =
        "completed_onboarding_version"

    /*
     * העלאת המספר בעתיד תאפשר להציג שוב
     * הדרכה מעודכנת לאחר שינוי משמעותי.
     */
    private static let currentVersion = 1

    static var hasCompleted: Bool {
        UserDefaults.standard.integer(
            forKey: completedVersionKey
        ) >= currentVersion
    }

    static func markCompleted() {
        UserDefaults.standard.set(
            currentVersion,
            forKey: completedVersionKey
        )
    }

    static func reset() {
        UserDefaults.standard.removeObject(
            forKey: completedVersionKey
        )
    }
}
