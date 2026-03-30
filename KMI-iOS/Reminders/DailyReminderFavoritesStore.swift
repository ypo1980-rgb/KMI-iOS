import Foundation

enum DailyReminderFavoritesStore {

    private static let key = "daily_reminder_favorites_ios"

    static func all() -> Set<String> {
        let arr = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(arr)
    }

    static func contains(_ item: String) -> Bool {
        all().contains(item)
    }

    static func toggle(_ item: String) {
        var current = all()
        if current.contains(item) {
            current.remove(item)
        } else {
            current.insert(item)
        }
        UserDefaults.standard.set(Array(current), forKey: key)
    }

    static func set(_ item: String, favorite: Bool) {
        var current = all()
        if favorite {
            current.insert(item)
        } else {
            current.remove(item)
        }
        UserDefaults.standard.set(Array(current), forKey: key)
    }
}
