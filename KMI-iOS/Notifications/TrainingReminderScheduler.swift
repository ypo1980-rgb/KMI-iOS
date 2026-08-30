import Foundation
import UserNotifications

@MainActor
final class TrainingReminderScheduler {

    static let shared = TrainingReminderScheduler()

    private init() {}

    private let center = UNUserNotificationCenter.current()
    private let pendingPrefix = "kmi.training.reminder."
    private var lastTrainings: [TrainingData] = []
    private var hasReceivedTrainings = false

    private var activeRunID = UUID()
    private var reminderTask: Task<Void, Never>?

    enum RefreshOutcome {
        case scheduled(count: Int, failed: Int)
        case disabled
        case permissionDenied
        case permissionCheckFailed
        case waitingForTrainings
    }

    func refresh(
        trainings: [TrainingData],
        leadMinutes: Int? = nil,
        completion: ((RefreshOutcome) -> Void)? = nil
    ) {
        lastTrainings = trainings
        hasReceivedTrainings = true

        let defaults = UserDefaults.standard

        let remindersEnabled =
            defaults.object(
                forKey: "training_reminders_enabled"
            ) == nil ||
            defaults.bool(
                forKey: "training_reminders_enabled"
            )

        guard remindersEnabled else {
            cancelAll {
                completion?(.disabled)
            }
            return
        }

        let storedLead = defaults.integer(
            forKey: "training_reminder_minutes"
        )

        let resolvedLead = max(
            1,
            leadMinutes ?? (storedLead > 0 ? storedLead : 60)
        )

        reminderTask?.cancel()

        let runID = UUID()
        activeRunID = runID

        reminderTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            let settings = await self.center.notificationSettings()

            guard self.isCurrentRun(runID) else {
                return
            }

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                break

            case .notDetermined:
                do {
                    let granted =
                        try await self.center.requestAuthorization(
                            options: [.alert, .sound, .badge]
                        )

                    guard self.isCurrentRun(runID) else {
                        return
                    }

                    guard granted else {
                        completion?(.permissionDenied)
                        return
                    }
                } catch {
                    guard self.isCurrentRun(runID) else {
                        return
                    }

                    completion?(.permissionCheckFailed)
                    return
                }

            case .denied:
                completion?(.permissionDenied)
                return

            @unknown default:
                completion?(.permissionCheckFailed)
                return
            }

            let outcome = await self.replacePendingReminders(
                trainings: trainings,
                leadMinutes: resolvedLead,
                runID: runID
            )

            guard self.isCurrentRun(runID),
                  let outcome else {
                return
            }

            completion?(outcome)
        }
    }

    func cancelAll(
        completion: (() -> Void)? = nil
    ) {
        reminderTask?.cancel()

        let runID = UUID()
        activeRunID = runID

        reminderTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            let requests =
                await self.center.pendingNotificationRequests()

            guard self.isCurrentRun(runID) else {
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

            completion?()
        }
    }

    func resetForSignedOutUser() {
        lastTrainings = []
        hasReceivedTrainings = false

        cancelAll()
    }

    func updateLeadTime(
        minutes: Int,
        completion: ((RefreshOutcome) -> Void)? = nil
    ) {
        let safeMinutes = max(1, minutes)

        UserDefaults.standard.set(
            safeMinutes,
            forKey: "training_reminder_minutes"
        )

        guard hasReceivedTrainings else {
            completion?(.waitingForTrainings)
            return
        }

        refresh(
            trainings: lastTrainings,
            leadMinutes: safeMinutes,
            completion: completion
        )
    }

    private func isCurrentRun(_ runID: UUID) -> Bool {
        activeRunID == runID && !Task.isCancelled
    }

    private func replacePendingReminders(
        trainings: [TrainingData],
        leadMinutes: Int,
        runID: UUID
    ) async -> RefreshOutcome? {
        let pendingRequests =
            await center.pendingNotificationRequests()

        guard isCurrentRun(runID) else {
            return nil
        }

        let oldIdentifiers = pendingRequests
            .map(\.identifier)
            .filter {
                $0.hasPrefix(pendingPrefix)
            }

        center.removePendingNotificationRequests(
            withIdentifiers: oldIdentifiers
        )

        let now = Date()
        var seen = Set<String>()
        var requests: [UNNotificationRequest] = []

        for training in trainings.sorted(by: { $0.date < $1.date }) {
            guard requests.count < 50 else {
                break
            }

            guard training.date > now else {
                continue
            }

            let key = trainingKey(training)

            guard seen.insert(key).inserted else {
                continue
            }

            if let request = makeRequest(
                training: training,
                leadMinutes: leadMinutes,
                now: now,
                runID: runID
            ) {
                requests.append(request)
            }
        }

        let currentIdentifiers = requests.map(\.identifier)
        var scheduledCount = 0
        var failedCount = 0

        for request in requests {
            guard isCurrentRun(runID) else {
                center.removePendingNotificationRequests(
                    withIdentifiers: currentIdentifiers
                )
                return nil
            }

            do {
                try await center.add(request)
                scheduledCount += 1
            } catch {
                failedCount += 1
            }

            guard isCurrentRun(runID) else {
                center.removePendingNotificationRequests(
                    withIdentifiers: currentIdentifiers
                )
                return nil
            }
        }

        return .scheduled(
            count: scheduledCount,
            failed: failedCount
        )
    }

    private func makeRequest(
        training: TrainingData,
        leadMinutes: Int,
        now: Date,
        runID: UUID
    ) -> UNNotificationRequest? {
        guard let reminderDate = Calendar(identifier: .gregorian)
            .date(
                byAdding: .minute,
                value: -leadMinutes,
                to: training.date
            ),
            reminderDate > now else {
            return nil
        }

        let content = UNMutableNotificationContent()

        content.title = localized(
            he: "האימון שלך מתחיל בקרוב",
            en: "Your training starts soon"
        )

        let timeText = timeFormatter.string(from: training.date)

        let cleanPlace = training.place.trimmingCharacters(
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

        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: reminderDate
        )

        components.timeZone = calendar.timeZone

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )

        return UNNotificationRequest(
            identifier:
                pendingPrefix +
                runID.uuidString +
                "." +
                trainingKey(training),
            content: content,
            trigger: trigger
        )
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
        let defaults = UserDefaults.standard

        for key in ["kmi_app_language", "app_language"] {
            guard let value = defaults.string(forKey: key) else {
                continue
            }

            switch value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() {
            case "he", "hebrew":
                return he

            case "en", "english":
                return en

            default:
                continue
            }
        }

        return he
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
