import Foundation

enum AccessMode {
    case locked
    case open
}

enum AccessModeResolver {

    static func resolve(
        hasManagerAccess: Bool
    ) -> AccessMode {
        hasManagerAccess ? .open : .locked
    }
}

enum LockedContentPolicy {

    static func isTopicRestricted(_ title: String) -> Bool {
        let t = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return t.contains("הגנות") ||
               t.contains("הגנה") ||
               t.contains("שחרור") ||
               t.contains("שחרורים") ||
               t.contains("defense") ||
               t.contains("defence") ||
               t.contains("release") ||
               t.contains("releases")
    }

    static func shouldShowLock(
        accessMode: AccessMode,
        title: String
    ) -> Bool {
        if accessMode == .open {
            return false
        }

        return isTopicRestricted(title)
    }

    static func canOpenTopic(
        accessMode: AccessMode,
        title: String
    ) -> Bool {
        if accessMode == .open {
            return true
        }

        return !isTopicRestricted(title)
    }

    static func currentAccessMode(
        defaults: UserDefaults = .standard
    ) -> AccessMode {
        AccessModeResolver.resolve(
            hasManagerAccess: KmiAccess.hasFullAccess(defaults: defaults)
        )
    }
}
