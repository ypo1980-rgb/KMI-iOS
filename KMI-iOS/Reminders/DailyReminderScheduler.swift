import Foundation
import UserNotifications
import Shared

@MainActor
final class DailyReminderScheduler {

    static let shared = DailyReminderScheduler()

    private init() {}

    private let center = UNUserNotificationCenter.current()

    static let categoryId = "KMI_DAILY_REMINDER_CATEGORY"
    static let actionFavorite = "KMI_DAILY_REMINDER_FAVORITE"
    static let actionAnother = "KMI_DAILY_REMINDER_ANOTHER"

    private let pendingPrefix = "kmi.daily.reminder."
    private let payloadKey = "daily_reminder_payload"

    func registerCategories() {
        let favorite = UNNotificationAction(
            identifier: Self.actionFavorite,
            title: "⭐ שמור",
            options: []
        )

        let another = UNNotificationAction(
            identifier: Self.actionAnother,
            title: "➕ תרגיל נוסף",
            options: [.foreground]
        )

        let category = UNNotificationCategory(
            identifier: Self.categoryId,
            actions: [favorite, another],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([category])
    }

    func requestPermissionIfNeeded(completion: ((Bool) -> Void)? = nil) {
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                completion?(true)

            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    completion?(granted)
                }

            default:
                completion?(false)
            }
        }
    }

    func refreshSchedule() {
        guard isEnabledForCurrentRole() else {
            cancelAll()
            return
        }

        requestPermissionIfNeeded { granted in
            guard granted else { return }
            Task { @MainActor in
                self.rescheduleUpcomingNotifications()
            }
        }
    }

    func cancelAll() {
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(self.pendingPrefix) }

            self.center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    func handleNotificationResponse(_ response: UNNotificationResponse) {
        guard let payload = decodePayload(from: response.notification.request.content.userInfo) else {
            return
        }

        switch response.actionIdentifier {
        case Self.actionFavorite:
            DailyReminderFavoritesStore.toggle(payload.item)

        case Self.actionAnother:
            if let next = makeAnotherPayload(from: payload) {
                DailyReminderCenter.shared.present(next)
            }

        case UNNotificationDefaultActionIdentifier:
            DailyReminderCenter.shared.present(payload)

        default:
            break
        }
    }

    func makeAnotherPayload(from payload: DailyReminderPayload) -> DailyReminderPayload? {
        guard payload.extraCount < 3 else { return nil }

        guard let targetBelt = belt(from: payload.beltId) else { return nil }
        let previous = previousBelt(forTarget: targetBelt)

        let picker = DailyExercisePicker()
        guard let picked = picker.pickNextExerciseForUser(
            registeredBelt: previous,
            lastItemKey: payload.lastItemKey
        ) else {
            return nil
        }

        let explanation = resolveExplanation(belt: picked.belt, item: picked.item)
        let lastKey = "\(picked.belt.name)|\(picked.topic)|\(picked.item)"

        return DailyReminderPayload(
            beltId: picked.belt.id,
            beltHeb: picked.belt.heb,
            topic: picked.topic,
            item: picked.item,
            explanation: explanation,
            extraCount: payload.extraCount + 1,
            lastItemKey: lastKey
        )
    }

    private func rescheduleUpcomingNotifications() {
        cancelAll()

        let defaults = UserDefaults.standard
        let hour = defaults.integer(forKey: "daily_exercise_reminder_hour").clamped(to: 0...23, fallback: 20)
        let minute = defaults.integer(forKey: "daily_exercise_reminder_minute").clamped(to: 0...59, fallback: 0)

        guard let registeredBelt = resolveRegisteredBelt() else { return }

        let picker = DailyExercisePicker()
        var lastKey: String? = defaults.string(forKey: "daily_exercise_reminder_last_item_key")
        var baseDate = Date()

        for index in 0..<30 {
            let triggerDate = ShabbatHolidayCheckerIOS.nextAllowedTriggerDate(
                preferredHour: hour,
                preferredMinute: minute,
                now: baseDate
            )

            guard let picked = picker.pickNextExerciseForUser(
                registeredBelt: registeredBelt,
                lastItemKey: lastKey
            ) else {
                continue
            }

            let lastItemKey = "\(picked.belt.name)|\(picked.topic)|\(picked.item)"
            let explanation = resolveExplanation(belt: picked.belt, item: picked.item)

            let payload = DailyReminderPayload(
                beltId: picked.belt.id,
                beltHeb: picked.belt.heb,
                topic: picked.topic,
                item: picked.item,
                explanation: explanation,
                extraCount: 0,
                lastItemKey: lastItemKey
            )

            scheduleNotification(
                payload: payload,
                triggerDate: triggerDate,
                identifier: "\(pendingPrefix)\(index)"
            )

            lastKey = lastItemKey
            baseDate = Calendar.current.date(byAdding: .minute, value: 1, to: triggerDate) ?? triggerDate
        }

        defaults.set(lastKey, forKey: "daily_exercise_reminder_last_item_key")
    }

    private func scheduleNotification(
        payload: DailyReminderPayload,
        triggerDate: Date,
        identifier: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = "התרגיל היומי שלך"
        content.body = "\(payload.beltHeb) • \(payload.item)"
        content.sound = .default
        content.categoryIdentifier = Self.categoryId

        if let encoded = encodePayload(payload) {
            content.userInfo[payloadKey] = encoded
        }

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: triggerDate
        )

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request)
    }

    private func encodePayload(_ payload: DailyReminderPayload) -> String? {
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        return data.base64EncodedString()
    }

    private func decodePayload(from userInfo: [AnyHashable: Any]) -> DailyReminderPayload? {
        guard let encoded = userInfo[payloadKey] as? String,
              let data = Data(base64Encoded: encoded),
              let payload = try? JSONDecoder().decode(DailyReminderPayload.self, from: data)
        else {
            return nil
        }
        return payload
    }

    private func isEnabledForCurrentRole() -> Bool {
        let defaults = UserDefaults.standard
        let role = resolveCurrentRole()

        if role == "coach" {
            return defaults.bool(forKey: "daily_exercise_reminder_enabled_coach")
        } else {
            return defaults.bool(forKey: "daily_exercise_reminder_enabled_trainee")
        }
    }

    private func resolveCurrentRole() -> String {
        let defaults = UserDefaults.standard

        let role = (
            defaults.string(forKey: "user_role") ??
            defaults.string(forKey: "kmi.user.role") ??
            "trainee"
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

        return role
    }

    private func resolveRegisteredBelt() -> Belt? {
        let defaults = UserDefaults.standard

        let raw = (
            defaults.string(forKey: "current_belt") ??
            defaults.string(forKey: "belt_current") ??
            defaults.string(forKey: "registered_belt") ??
            ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

        return belt(from: raw)
    }

    private func belt(from raw: String) -> Belt? {
        switch raw {
        case "white": return .white
        case "yellow": return .yellow
        case "orange": return .orange
        case "green": return .green
        case "blue": return .blue
        case "brown": return .brown
        case "black": return .black
        default: return nil
        }
    }

    private func previousBelt(forTarget belt: Belt) -> Belt {
        switch belt {
        case .yellow: return .white
        case .orange: return .yellow
        case .green: return .orange
        case .blue: return .green
        case .brown: return .blue
        case .black: return .brown
        default: return .white
        }
    }

    private func resolveExplanation(belt: Belt, item: String) -> String {
        // אם אצלך הגשר של Explanations נקרא אחרת, תחליף רק את השורה הזאת.
        if let text = Explanations.shared.get(belt: belt, item: item) as String?,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }
        return "אין כרגע הסבר לתרגיל הזה."
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>, fallback: Int) -> Int {
        if range.contains(self) { return self }
        return fallback
    }
}
