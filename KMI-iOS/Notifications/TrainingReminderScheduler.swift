import Foundation
import UserNotifications

@MainActor
final class TrainingReminderScheduler {

    static let shared = TrainingReminderScheduler()

    private init() {}

    private let center = UNUserNotificationCenter.current()
    private let pendingPrefix = "kmi.training.reminder."
    private var lastTrainings: [TrainingData] = []

    func refresh(
        trainings: [TrainingData],
        leadMinutes: Int? = nil
    ) {
        lastTrainings = trainings

        let defaults = UserDefaults.standard

        let remindersEnabled: Bool = {
            if defaults.object(
                forKey: "training_reminders_enabled"
            ) == nil {
                return true
            }

            return defaults.bool(
                forKey: "training_reminders_enabled"
            )
        }()

        guard remindersEnabled else {
            cancelAll()
            return
        }

        let storedLead =
            defaults.integer(
                forKey: "training_reminder_minutes"
            )

        let resolvedLead = max(
            1,
            leadMinutes
                ?? (storedLead > 0 ? storedLead : 60)
        )

        center.getNotificationSettings { [weak self] settings in
            guard let self else {
                return
            }

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                Task { @MainActor in
                    self.replacePendingReminders(
                        trainings: trainings,
                        leadMinutes: resolvedLead
                    )
                }

            case .notDetermined:
                self.center.requestAuthorization(
                    options: [.alert, .sound, .badge]
                ) { granted, _ in
                    guard granted else {
                        return
                    }

                    Task { @MainActor in
                        self.replacePendingReminders(
                            trainings: trainings,
                            leadMinutes: resolvedLead
                        )
                    }
                }

            case .denied:
                break

            @unknown default:
                break
            }
        }
    }

    func cancelAll() {
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else {
                return
            }

            let identifiers = requests
                .map(\.identifier)
                .filter {
                    $0.hasPrefix(self.pendingPrefix)
                }

            self.center.removePendingNotificationRequests(
                withIdentifiers: identifiers
            )
        }
    }

    func updateLeadTime(minutes: Int) {
        let safeMinutes = max(1, minutes)

        UserDefaults.standard.set(
            safeMinutes,
            forKey: "training_reminder_minutes"
        )

        refresh(
            trainings: lastTrainings,
            leadMinutes: safeMinutes
        )
    }

    private func replacePendingReminders(
        trainings: [TrainingData],
        leadMinutes: Int
    ) {
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else {
                return
            }

            let oldIdentifiers = requests
                .map(\.identifier)
                .filter {
                    $0.hasPrefix(self.pendingPrefix)
                }

            self.center.removePendingNotificationRequests(
                withIdentifiers: oldIdentifiers
            )

            let now = Date()
            var seen = Set<String>()

            let upcoming = trainings
                .sorted { $0.date < $1.date }
                .filter { $0.date > now }
                .filter { training in
                    let key = self.trainingKey(training)

                    guard !seen.contains(key) else {
                        return false
                    }

                    seen.insert(key)
                    return true
                }
                .prefix(50)

            for training in upcoming {
                self.schedule(
                    training: training,
                    leadMinutes: leadMinutes,
                    now: now
                )
            }
        }
    }

    private func schedule(
        training: TrainingData,
        leadMinutes: Int,
        now: Date
    ) {
        guard let reminderDate = Calendar(identifier: .gregorian)
            .date(
                byAdding: .minute,
                value: -leadMinutes,
                to: training.date
            ),
            reminderDate > now else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = localized(
            he: "האימון שלך מתחיל בקרוב",
            en: "Your training starts soon"
        )

        let timeText = timeFormatter.string(
            from: training.date
        )

        let cleanPlace = training.place
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        content.body = cleanPlace.isEmpty
            ? localized(
                he: "האימון מתחיל בשעה \(timeText)",
                en: "Training starts at \(timeText)"
            )
            : localized(
                he: "האימון ב־\(cleanPlace) מתחיל בשעה \(timeText)",
                en: "Training at \(cleanPlace) starts at \(timeText)"
            )

        content.sound = .default
        content.userInfo = [
            "route": "home",
            "type": "training_reminder",
            "trainingStartMillis": Int64(
                training.date.timeIntervalSince1970 * 1000
            ),
            "place": cleanPlace,
            "address": training.address
        ]

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(
            identifier: "Asia/Jerusalem"
        ) ?? .current

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier:
                pendingPrefix + trainingKey(training),
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    private func trainingKey(
        _ training: TrainingData
    ) -> String {
        let minute = Int(
            training.date.timeIntervalSince1970 / 60
        )

        let raw = [
            String(minute),
            training.place,
            training.address
        ]
        .joined(separator: "|")
        .lowercased()

        let safe = raw
            .replacingOccurrences(
                of: "[^a-z0-9א-ת]+",
                with: "_",
                options: .regularExpression
            )
            .trimmingCharacters(
                in: CharacterSet(charactersIn: "_")
            )

        return safe.isEmpty
            ? String(minute)
            : safe
    }

    private func localized(
        he: String,
        en: String
    ) -> String {
        let values = [
            UserDefaults.standard.string(
                forKey: "kmi_app_language"
            ),
            UserDefaults.standard.string(
                forKey: "app_language"
            )
        ]
        .compactMap { $0?.lowercased() }

        let isEnglish = values.contains("en")
            || values.contains("english")

        return isEnglish ? en : he
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(
            identifier: "he_IL"
        )
        formatter.timeZone = TimeZone(
            identifier: "Asia/Jerusalem"
        )
        formatter.dateFormat = "HH:mm"
        return formatter
    }
}

@MainActor
func scheduleTrainingReminders(minutes: Int) {
    TrainingReminderScheduler.shared
        .updateLeadTime(minutes: minutes)
}

@MainActor
func cancelTrainingReminders() {
    TrainingReminderScheduler.shared.cancelAll()
}
