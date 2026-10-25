import SwiftUI
import UserNotifications
import EventKit
import LocalAuthentication
import StoreKit
import MessageUI
import UIKit
import AudioToolbox

extension SettingsView {

    @ViewBuilder
    func toggleRow(
        title: String,
        isOn: Binding<Bool>,
        onChanged: @escaping (Bool) -> Void
    ) -> some View {
        HStack {
            if isEnglish {
                toggleRowText(title)

                toggleRowSwitch(isOn: isOn, onChanged: onChanged)
            } else {
                toggleRowSwitch(isOn: isOn, onChanged: onChanged)

                toggleRowText(title)
            }
        }
    }

    private func toggleRowText(_ title: String) -> some View {
        Text(title)
            .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
            .multilineTextAlignment(primaryTextAlignment)
    }

    private func toggleRowSwitch(
        isOn: Binding<Bool>,
        onChanged: @escaping (Bool) -> Void
    ) -> some View {
        Toggle("", isOn: Binding(
            get: { isOn.wrappedValue },
            set: { newValue in
                isOn.wrappedValue = newValue
                onChanged(newValue)
            }
        ))
        .labelsHidden()
    }

    func requestNotificationPermissionIfNeeded(
        onDenied: (() -> Void)? = nil,
        onGranted: @escaping () -> Void
    ) {
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()

            let granted: Bool

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                granted = true

            case .notDetermined:
                do {
                    granted = try await center.requestAuthorization(
                        options: [.alert, .sound, .badge]
                    )
                } catch {
                    onDenied?()
                    toast(
                        tr(
                            "לא ניתן היה לבדוק את הרשאת ההתראות. נסה שוב.",
                            "Could not check notification access. Try again."
                        )
                    )
                    hapticError()
                    return
                }

            case .denied:
                granted = false

            @unknown default:
                granted = false
            }

            guard granted else {
                onDenied?()
                toast(
                    tr(
                        "אין הרשאה להתראות. ניתן לאפשר אותן בהגדרות המכשיר.",
                        "Notifications are not allowed. You can enable them in device settings."
                    )
                )
                hapticError()
                return
            }

            onGranted()
        }
    }

    @MainActor
    private func removeLegacyTrainingReminders() async {
        let center = UNUserNotificationCenter.current()
        let requests = await center.pendingNotificationRequests()

        let identifiers = requests
            .map(\.identifier)
            .filter {
                $0 == "training_reminder" ||
                $0.hasPrefix("training_reminder_")
            }

        guard !identifiers.isEmpty else {
            return
        }

        center.removePendingNotificationRequests(
            withIdentifiers: identifiers
        )
    }

    func scheduleTrainingReminders(minutes: Int) {
        Task { @MainActor in
            await removeLegacyTrainingReminders()

            guard trainingRemindersEnabled else {
                TrainingReminderScheduler.shared.cancelAll()
                return
            }

            TrainingReminderScheduler.shared.updateLeadTime(
                minutes: minutes > 0 ? minutes : 60
            ) { outcome in
                guard trainingRemindersEnabled else {
                    return
                }

                switch outcome {
                case let .scheduled(count, failed):
                    if failed > 0 {
                        toast(
                            tr(
                                "נקבעו \(count) תזכורות; \(failed) לא נשמרו. נסה שוב.",
                                "\(count) reminders were scheduled; \(failed) could not be saved. Try again."
                            )
                        )
                        hapticError()
                    } else if count == 0 {
                        toast(
                            tr(
                                "אין כרגע אימונים עם מועד תזכורת עתידי.",
                                "No trainings currently have a future reminder time."
                            )
                        )
                    } else {
                        toast(
                            tr(
                                "נקבעו \(count) תזכורות אימון.",
                                "\(count) training reminders were scheduled."
                            )
                        )
                        hapticSuccess()
                    }

                case .permissionDenied:
                    trainingRemindersEnabled = false

                    toast(
                        tr(
                            "אין הרשאה להתראות. ניתן לאפשר אותן בהגדרות המכשיר.",
                            "Notifications are not allowed. You can enable them in device settings."
                        )
                    )
                    hapticError()

                case .permissionCheckFailed:
                    toast(
                        tr(
                            "לא ניתן היה לבדוק את הרשאת ההתראות. נסה שוב.",
                            "Could not check notification access. Try again."
                        )
                    )
                    hapticError()

                case .waitingForTrainings:
                    toast(
                        tr(
                            "זמן התזכורת נשמר. התזמון יתבצע לאחר טעינת האימונים.",
                            "Reminder time was saved. Scheduling will run after trainings load."
                        )
                    )

                case .disabled:
                    break
                }
            }
        }
    }

    func cancelTrainingReminders() {
        Task { @MainActor in
            await removeLegacyTrainingReminders()

            guard !trainingRemindersEnabled else {
                return
            }

            TrainingReminderScheduler.shared.cancelAll {
                guard !trainingRemindersEnabled else {
                    return
                }

                toast(
                    tr(
                        "תזכורות האימון כובו ונשלחה בקשה להסרת התזכורות הממתינות.",
                        "Training reminders were turned off and pending reminders were requested for removal."
                    )
                )
                hapticSuccess()
            }
        }
    }

    private var calendarOwnedEventIDsKey: String {
        "kmi_calendar_owned_event_ids_v1"
    }

    private var calendarOwnershipMarkerKey: String {
        "kmi_calendar_ownership_marker_v1"
    }

    private func requestSettingsCalendarFullAccess(
        using store: EKEventStore,
        completion: @escaping (Bool) -> Void
    ) {
        if #available(iOS 17.0, *) {
            store.requestFullAccessToEvents { granted, _ in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        } else {
            store.requestAccess(to: .event) { granted, _ in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        }
    }

    private func settingsCalendarOwnershipMarker() -> String {
        let defaults = UserDefaults.standard

        if let existing = defaults.string(
            forKey: calendarOwnershipMarkerKey
        ), !existing.isEmpty {
            return existing
        }

        let marker = "[KMI-SYNC:\(UUID().uuidString)]"

        defaults.set(
            marker,
            forKey: calendarOwnershipMarkerKey
        )

        return marker
    }

    private func stageOwnedCalendarEventRemoval(
        using store: EKEventStore
    ) throws -> [String] {
        let defaults = UserDefaults.standard

        let savedIDs = defaults.stringArray(
            forKey: calendarOwnedEventIDsKey
        ) ?? []

        guard let marker = defaults.string(
            forKey: calendarOwnershipMarkerKey
        ), !marker.isEmpty else {
            return savedIDs
        }

        var retainedIDs: [String] = []

        for identifier in Set(savedIDs) {
            guard let event = store.event(
                withIdentifier: identifier
            ) else {
                retainedIDs.append(identifier)
                continue
            }

            let hasOwnershipMarker =
                event.notes?
                    .components(separatedBy: .newlines)
                    .contains(marker) == true

            guard hasOwnershipMarker else {
                retainedIDs.append(identifier)
                continue
            }

            try store.remove(
                event,
                span: event.hasRecurrenceRules
                    ? .futureEvents
                    : .thisEvent,
                commit: false
            )
        }

        return retainedIDs
    }

    func ensureCalendarPermissionsAndSync() {
        let store = EKEventStore()

        isBusy = true

        requestSettingsCalendarFullAccess(using: store) { granted in
            defer {
                self.isBusy = false
            }

            guard granted else {
                self.calendarSyncEnabled = false
                self.selectedCalendarSyncEnabled = false
                self.toast(
                    self.tr(
                        "אין הרשאה מלאה ליומן",
                        "Full calendar access was not granted"
                    )
                )
                self.hapticError()
                return
            }

            let assignments = self.calendarSyncAssignments()

            /*
             * רק רשימה ריקה ותקינה שנשמרה במפורש
             * נחשבת להסרת כל הבחירות.
             * נתון חסר או פגום אינו מצדיק מחיקת אירועים.
             */
            let defaults = UserDefaults.standard
            let codec = RegistrationFormState.BranchAssignmentsCodec.self

            let explicitlyEmptyAssignments: Bool = {
                guard let raw = defaults.string(
                    forKey: codec.preferenceKey
                ),
                let data = raw.data(using: .utf8),
                let objects = try? JSONSerialization.jsonObject(
                    with: data
                ) as? [Any] else {
                    return false
                }

                return objects.isEmpty
            }()

            if explicitlyEmptyAssignments {
                do {
                    let retainedIDs =
                        try self.stageOwnedCalendarEventRemoval(
                            using: store
                        )

                    try store.commit()

                    defaults.set(
                        retainedIDs,
                        forKey: self.calendarOwnedEventIDsKey
                    )

                    self.calendarSyncEnabled = true
                    self.selectedCalendarSyncEnabled = true

                    self.toast(
                        self.tr(
                            "לא נבחרו אימונים. אירועי האפליקציה הקודמים הוסרו מהיומן.",
                            "No trainings selected. Previous app events were removed from the calendar."
                        )
                    )

                    self.hapticSuccess()
                } catch {
                    store.reset()

                    self.calendarSyncEnabled = false
                    self.selectedCalendarSyncEnabled = false

                    self.toast(
                        self.tr(
                            "לא ניתן היה להסיר את אירועי האפליקציה. נסה שוב.",
                            "Could not remove the app events. Try again."
                        )
                    )

                    self.hapticError()
                }

                return
            }

            guard !assignments.isEmpty,
                  assignments.allSatisfy({
                    !$0.branch.isEmpty && !$0.groups.isEmpty
                  }) else {
                self.calendarSyncEnabled = false
                self.selectedCalendarSyncEnabled = false
                self.toast(
                    self.tr(
                        "יש להשלים שיוך קבוצות לכל סניף בפרופיל. אירועים קיימים לא נמחקו.",
                        "Complete the group assignments for each branch in your profile. Existing events were not removed."
                    )
                )
                self.hapticError()
                return
            }

            guard !self.selectedCalendarIdentifier.isEmpty,
                  let targetCalendar = store.calendar(
                    withIdentifier: self.selectedCalendarIdentifier
                  ),
                  targetCalendar.allowsContentModifications else {
                self.calendarSyncEnabled = false
                self.selectedCalendarSyncEnabled = false
                self.toast(
                    self.tr(
                        "יש לבחור יומן זמין שניתן לכתוב אליו",
                        "Choose an available writable calendar"
                    )
                )
                self.hapticError()
                return
            }

            var trainings: [
                (
                    training: TrainingData,
                    branch: String,
                    group: String
                )
            ] = []

            var seenTrainings = Set<String>()

            for assignment in assignments {
                for group in assignment.groups {
                    let matches = TrainingCatalogIOS.trainingsFor(
                        branch: assignment.branch,
                        group: group
                    )

                    for training in matches {
                        /*
                         * אותה משבצת אימון עשויה להתאים
                         * ליותר מקבוצה אחת. מוסיפים אותה פעם אחת.
                         */
                        let identity = [
                            assignment.branch,
                            String(training.date.timeIntervalSince1970),
                            String(
                                self.endDate(for: training)
                                    .timeIntervalSince1970
                            ),
                            training.place,
                            training.address,
                            training.coach
                        ]

                        let encodedIdentity = try? JSONEncoder().encode(
                            identity
                        )

                        guard let encodedIdentity,
                              seenTrainings.insert(
                                encodedIdentity.base64EncodedString()
                              ).inserted else {
                            continue
                        }

                        trainings.append(
                            (
                                training: training,
                                branch: assignment.branch,
                                group: group
                            )
                        )
                    }
                }
            }

            trainings.sort {
                $0.training.date < $1.training.date
            }

            guard !trainings.isEmpty else {
                self.calendarSyncEnabled = false
                self.selectedCalendarSyncEnabled = false
                self.toast(
                    self.tr(
                        "לא נמצאו אימונים לסניף ולקבוצה שלך. אירועים קיימים לא נמחקו.",
                        "No trainings were found for your branch and group. Existing events were not removed."
                    )
                )
                self.hapticError()
                return
            }

            let marker = self.settingsCalendarOwnershipMarker()

            do {
                let now = Date()

                var calendarSeries: [
                    (
                        training: TrainingData,
                        branch: String,
                        group: String,
                        start: Date,
                        count: Int?
                    )
                ] = []

                /*
                 * מחשבים את כל הסדרות לפני מחיקת
                 * האירועים הקיימים.
                 */
                for item in trainings {
                    let segments = try self.calendarWeeklySegments(
                        for: item.training,
                        now: now
                    )

                    for segment in segments {
                        calendarSeries.append(
                            (
                                training: item.training,
                                branch: item.branch,
                                group: item.group,
                                start: segment.start,
                                count: segment.count
                            )
                        )
                    }
                }

                let retainedIDs =
                    try self.stageOwnedCalendarEventRemoval(
                        using: store
                    )

                var newEvents: [EKEvent] = []

                let reminderMinutes = min(
                    max(self.trainingReminderMinutes, 0),
                    180
                )

                for item in calendarSeries {
                    let training = item.training
                    let branch = item.branch
                    let group = item.group

                    let duration = self.endDate(
                        for: training
                    )
                    .timeIntervalSince(training.date)

                    let trainingEnd = item.start.addingTimeInterval(
                        duration
                    )

                    let event = EKEvent(eventStore: store)

                    let recurrenceEnd: EKRecurrenceEnd?

                    if let count = item.count {
                        recurrenceEnd = EKRecurrenceEnd(
                            occurrenceCount: count
                        )
                    } else {
                        recurrenceEnd = nil
                    }

                    event.addRecurrenceRule(
                        EKRecurrenceRule(
                            recurrenceWith: .weekly,
                            interval: 1,
                            end: recurrenceEnd
                        )
                    )

                    event.calendar = targetCalendar
                    event.title = self.calendarEventTitle(
                        for: training,
                        group: group
                    )
                    event.startDate = item.start
                    event.endDate = trainingEnd

                    event.addAlarm(
                        EKAlarm(
                            relativeOffset:
                                -TimeInterval(reminderMinutes * 60)
                        )
                    )

                    event.notes = [
                        self.calendarNotes(
                            for: training,
                            branch: branch,
                            group: group
                        ),
                        marker
                    ]
                    .joined(separator: "\n")
                    let address = TrainingCatalogIOS.displayAddress(
                        training.address,
                        isEnglish: self.isEnglish
                    )
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                    let place = TrainingCatalogIOS.displayPlace(
                        training.place,
                        isEnglish: self.isEnglish
                    )
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                    event.location = address.isEmpty
                        ? place
                        : address

                    event.timeZone =
                        ShabbatHolidayCheckerIOS.timeZone

                    try store.save(
                        event,
                        span: .thisEvent,
                        commit: false
                    )

                    newEvents.append(event)
                }

                try store.commit()

                let newIDs = newEvents.compactMap {
                    $0.eventIdentifier
                }

                UserDefaults.standard.set(
                    Array(Set(retainedIDs + newIDs)),
                    forKey: self.calendarOwnedEventIDsKey
                )

                self.calendarSyncEnabled = true
                self.selectedCalendarSyncEnabled = true

                self.toast(
                    self.tr(
                        "לוח האימונים השבועי סונכרן ליומן",
                        "The weekly training schedule was synced to the calendar"
                    )
                )
                self.hapticSuccess()
            } catch {
                store.reset()

                self.calendarSyncEnabled = false
                self.selectedCalendarSyncEnabled = false

                self.toast(
                    self.tr(
                        "הסנכרון לא הושלם. בדוק את הרשאת היומן ונסה שוב.",
                        "Sync did not complete. Check calendar access and try again."
                    )
                )
                self.hapticError()
            }
        }
    }

    func removeCalendarEvents() {
        let store = EKEventStore()

        isBusy = true

        requestSettingsCalendarFullAccess(using: store) { granted in
            defer {
                self.isBusy = false
            }

            guard granted else {
                self.toast(
                    self.tr(
                        "אין הרשאה מלאה ליומן — אירועים לא הוסרו",
                        "Full calendar access was not granted — events were not removed"
                    )
                )
                self.hapticError()
                return
            }

            let previousIDs = UserDefaults.standard.stringArray(
                forKey: self.calendarOwnedEventIDsKey
            ) ?? []

            do {
                let retainedIDs =
                    try self.stageOwnedCalendarEventRemoval(
                        using: store
                    )

                try store.commit()

                UserDefaults.standard.set(
                    retainedIDs,
                    forKey: self.calendarOwnedEventIDsKey
                )

                let removedCount =
                    Set(previousIDs).count - Set(retainedIDs).count

                self.calendarSyncEnabled = false
                self.selectedCalendarSyncEnabled = false

                self.toast(
                    self.tr(
                        "הוסרו \(removedCount) אירועים שסומנו כשייכים לאפליקציה. אירועים אחרים לא שונו.",
                        "\(removedCount) app-owned events were removed. Other events were not changed."
                    )
                )
                self.hapticSuccess()
            } catch {
                store.reset()

                self.toast(
                    self.tr(
                        "הסרת האירועים לא הושלמה. נסה שוב.",
                        "Event removal did not complete. Try again."
                    )
                )
                self.hapticError()
            }
        }
    }

    private func calendarWeeklySegments(
        for training: TrainingData,
        now: Date
    ) throws -> [(start: Date, count: Int?)] {
        let calendar = ShabbatHolidayCheckerIOS.calendar

        func calculationError() -> NSError {
            NSError(
                domain: "KMI.CalendarSync",
                code: 1,
                userInfo: nil
            )
        }

        guard training.date.timeIntervalSince1970 > 0,
              endDate(for: training) > training.date,
              let horizon = calendar.date(
                byAdding: .year,
                value: 3,
                to: now
              ) else {
            throw calculationError()
        }

        func followingWeek(_ date: Date) throws -> Date {
            guard let next = calendar.date(
                byAdding: .weekOfYear,
                value: 1,
                to: date
            ), next > date else {
                throw calculationError()
            }

            return next
        }

        var candidate = training.date

        /*
         * כמו Android:
         * הסדרה מתחילה במועד שטרם התחיל.
         */
        while candidate <= now {
            candidate = try followingWeek(candidate)
        }

        var segments: [(start: Date, count: Int?)] = []
        var segmentStart: Date?
        var occurrenceCount = 0

        /*
         * החרגות החגים מחושבות לשלוש שנים קדימה.
         * חיבור שבועות נעשה לפי שעון ישראל,
         * כדי לשמור על שעת האימון במעבר שעון.
         */
        while calendar.startOfDay(for: candidate)
                <= calendar.startOfDay(for: horizon) {
            if HolidayCalendarStore.isTrainingCancelled(
                on: candidate
            ) {
                if let start = segmentStart {
                    segments.append(
                        (start: start, count: occurrenceCount)
                    )
                }

                segmentStart = nil
                occurrenceCount = 0
            } else {
                if segmentStart == nil {
                    segmentStart = candidate
                }

                occurrenceCount += 1
            }

            candidate = try followingWeek(candidate)
        }

        /*
         * כמו Android, החזרה ממשיכה ללא סוף.
         * מעבר לאופק שלוש השנים אין החרגות
         * חדשות עד לביצוע סנכרון נוסף.
         */
        segments.append(
            (
                start: segmentStart ?? candidate,
                count: nil
            )
        )

        return segments
    }

    private func calendarSyncAssignments()
        -> [RegistrationFormState.BranchAssignment] {
        let defaults = UserDefaults.standard
        let codec = RegistrationFormState.BranchAssignmentsCodec.self

        /*
         * כאשר קיים שדה שיוכים, הוא מקור האמת.
         * גם רשימה ריקה אינה מאפשרת חזרה לשיוכים ישנים.
         */
        if defaults.object(forKey: codec.preferenceKey) != nil {
            return codec.decode(
                defaults.string(forKey: codec.preferenceKey)
            )
        }

        /*
         * תאימות לפרופיל ישן:
         * רשימת קבוצות שטוחה בטוחה רק בסניף יחיד.
         */
        let storedBranches =
            defaults.stringArray(forKey: "branches") ?? []

        var seenBranches = Set<String>()

        let branches = storedBranches
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
            .filter { seenBranches.insert($0).inserted }

        guard branches.count <= 1 else {
            return []
        }

        let branch = branches.first ?? resolvedCalendarBranch()

        guard !branch.isEmpty else {
            return []
        }

        let storedGroups =
            defaults.stringArray(forKey: "groups") ?? []

        var seenGroups = Set<String>()

        var groups = storedGroups
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
            .filter { seenGroups.insert($0).inserted }

        if groups.isEmpty {
            let activeGroup = resolvedCalendarGroup()

            if !activeGroup.isEmpty {
                groups = [activeGroup]
            }
        }

        return [
            RegistrationFormState.BranchAssignment(
                branch: branch,
                groups: groups
            ).sanitized()
        ]
    }

    private func resolvedCalendarBranch() -> String {
        (
            UserDefaults.standard.string(forKey: "kmi.user.branch") ??
            UserDefaults.standard.string(forKey: "active_branch") ??
            UserDefaults.standard.string(forKey: "branch") ??
            ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resolvedCalendarGroup() -> String {
        (
            UserDefaults.standard.string(forKey: "kmi.user.group") ??
            UserDefaults.standard.string(forKey: "active_group") ??
            UserDefaults.standard.string(forKey: "group") ??
            ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func calendarEventTitle(
        for training: TrainingData,
        group: String
    ) -> String {
        let place = TrainingCatalogIOS.displayPlace(
            training.place,
            isEnglish: isEnglish
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        let title = isEnglish
            ? "KMI Training"
            : "אימון ק.מ.י"

        return place.isEmpty
            ? title
            : "\(title) – \(place)"
    }

    private func calendarNotes(
        for training: TrainingData,
        branch: String,
        group: String
    ) -> String {
        let details: [(he: String, en: String, value: String)] = [
            (
                "סניף", "Branch",
                TrainingCatalogIOS.displayBranch(
                    branch,
                    isEnglish: isEnglish
                )
            ),
            (
                "קבוצה", "Group",
                TrainingCatalogIOS.displayGroup(
                    group,
                    isEnglish: isEnglish
                )
            ),
            (
                "מקום", "Place",
                TrainingCatalogIOS.displayPlace(
                    training.place,
                    isEnglish: isEnglish
                )
            ),
            (
                "כתובת", "Address",
                TrainingCatalogIOS.displayAddress(
                    training.address,
                    isEnglish: isEnglish
                )
            ),
            (
                "מאמן", "Coach",
                TrainingCatalogIOS.displayCoach(
                    training.coach,
                    isEnglish: isEnglish
                )
            )
        ]

        var parts = details.compactMap { detail -> String? in
            let value = detail.value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard !value.isEmpty else {
                return nil
            }

            let label = isEnglish ? detail.en : detail.he
            return "\(label): \(value)"
        }

        /*
         * תיאור משותף לכל מופעי הסדרה:
         * מציגים שעות בלבד, ללא תאריך המופע הראשון.
         */
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.calendar = ShabbatHolidayCheckerIOS.calendar
        timeFormatter.timeZone = ShabbatHolidayCheckerIOS.timeZone
        timeFormatter.dateFormat = "HH:mm"

        let startTime = timeFormatter.string(
            from: training.date
        )

        let endTime = timeFormatter.string(
            from: endDate(for: training)
        )

        parts.append(
            "\(isEnglish ? "Time" : "שעה"): " +
            "\(startTime) – \(endTime)"
        )

        return parts.joined(separator: "\n")
    }

    private func endDate(for training: TrainingData) -> Date {
        let fallback = training.date.addingTimeInterval(90 * 60)

        let raw = training.endText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let pieces = raw.split(separator: ":")

        guard pieces.count == 2,
              let hour = Int(pieces[0]),
              let minute = Int(pieces[1]),
              (0...23).contains(hour),
              (0...59).contains(minute),
              let timeZone = TimeZone(
                identifier: "Asia/Jerusalem"
              ) else {
            return fallback
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        guard let sameDayEnd = calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: training.date
        ) else {
            return fallback
        }

        if sameDayEnd > training.date {
            return sameDayEnd
        }

        guard sameDayEnd < training.date else {
            return fallback
        }

        return calendar.date(
            byAdding: .day,
            value: 1,
            to: sameDayEnd
        ) ?? fallback
    }

    func biometricAvailable() -> Bool {
        let ctx = LAContext()
        var err: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
    }

    func authenticateBiometricIfAvailable(completion: @escaping (Bool) -> Void) {
        guard biometricAvailable() else {
            toast(tr("ביומטרי לא זמין במכשיר", "Biometric authentication is not available on this device"))
            hapticError()
            completion(false)
            return
        }

        let ctx = LAContext()
        ctx.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: tr(
                "אימות להפעלת נעילת האפליקציה",
                "Authenticate to enable app lock"
            )
        ) { ok, _ in
            DispatchQueue.main.async {
                if ok {
                    self.toast(self.tr("זיהוי ביומטרי הופעל", "Biometric lock enabled"))
                    self.hapticSuccess()
                    completion(true)
                } else {
                    self.toast(self.tr("האימות נכשל", "Authentication failed"))
                    self.hapticError()
                    completion(false)
                }
            }
        }
    }

    func resetPinDialog() {
        pin = ""
        pinConfirm = ""
        pinError = nil
    }

    func onSavePin() {
        let cleanPin = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanConfirm = pinConfirm.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanPin.count < 4 {
            pinError = tr(
                "הסיסמה צריכה להיות לפחות 4 ספרות",
                "PIN must contain at least 4 digits"
            )
            return
        }

        if cleanPin.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) != nil {
            pinError = tr(
                "הסיסמה יכולה להכיל ספרות בלבד",
                "PIN can contain digits only"
            )
            return
        }

        if cleanPin != cleanConfirm {
            pinError = tr(
                "הסיסמאות אינן תואמות",
                "PIN codes do not match"
            )
            return
        }

        appLockPin = cleanPin
        appLockMode = "pin"
        toast(tr("נעילה באמצעות סיסמה הופעלה", "PIN lock enabled"))
        hapticSuccess()
        resetPinDialog()
        showPinDialog = false
    }

    func appVersionLine() -> String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return isEnglish ? "Version \(v) (\(b))" : "גרסה \(v) (\(b))"
    }

    func sendFeedbackEmail() {
        let body = isEnglish
        ? """

        ---
        System details for troubleshooting:
        Bundle: \(Bundle.main.bundleIdentifier ?? "?")
        \(appVersionLine())
        Device: \(UIDevice.current.model)
        iOS: \(UIDevice.current.systemVersion)
        """
        : """

        ---
        פרטי מערכת (לעזרה באיתור תקלות):
        חבילה: \(Bundle.main.bundleIdentifier ?? "?")
        \(appVersionLine())
        מכשיר: \(UIDevice.current.model)
        iOS: \(UIDevice.current.systemVersion)
        """

        let to = "support@kmi.example"
        let subject = tr("משוב על האפליקציה", "App feedback")

        if MFMailComposeViewController.canSendMail() {
            mailData = MailData(to: to, subject: subject, body: body)
        } else {
            let urlString = "mailto:\(to)?subject=\(subject.urlQueryEncoded)&body=\(body.urlQueryEncoded)"
            openURL(urlString)
        }
    }

    func requestReview() {
        guard let scene = activeWindowScene() else { return }
        AppStore.requestReview(in: scene)
    }

    func shareApp() {
        let text = tr(
            "הורידו את אפליקציית K.M.I – קרב מגן ישראלי",
            "Download the K.M.I app – Israeli Krav Maga"
        )

        ShareSheet.present(items: [text])
    }

    func clearAppCacheIOS() -> Bool {
        do {
            let fm = FileManager.default

            guard let cacheURL = fm.urls(
                for: .cachesDirectory,
                in: .userDomainMask
            ).first else {
                return false
            }

            let files = try fm.contentsOfDirectory(
                at: cacheURL,
                includingPropertiesForKeys: nil
            )
            for f in files {
                try fm.removeItem(at: f)
            }
            return true
        } catch {
            return false
        }
    }

    func currentBeltResolvedId() -> String {
        let raw = !currentBeltId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? currentBeltId
            : currentBeltIdUser

        return raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func currentBeltDisplayName() -> String {
        switch currentBeltResolvedId() {
        case "white", "לבן", "לבנה":
            return isEnglish ? "White" : "לבנה"
        case "yellow", "צהוב", "צהובה":
            return isEnglish ? "Yellow" : "צהובה"
        case "orange", "כתום", "כתומה":
            return isEnglish ? "Orange" : "כתומה"
        case "green", "ירוק", "ירוקה":
            return isEnglish ? "Green" : "ירוקה"
        case "blue", "כחול", "כחולה":
            return isEnglish ? "Blue" : "כחולה"
        case "brown", "חום", "חומה":
            return isEnglish ? "Brown" : "חומה"
        case "black", "שחור", "שחורה":
            return isEnglish ? "Black" : "שחורה"
        default:
            return isEnglish ? "White" : "לבנה"
        }
    }

    func currentBeltTextColor() -> Color {
        switch currentBeltResolvedId() {
        case "yellow", "צהוב", "צהובה":
            return .yellow
        case "orange", "כתום", "כתומה":
            return .orange
        case "green", "ירוק", "ירוקה":
            return .green
        case "blue", "כחול", "כחולה":
            return .blue
        case "brown", "חום", "חומה":
            return Color(hex: 0xFF6D4C41)
        case "black", "שחור", "שחורה":
            return Color.primary
        default:
            return Color.black.opacity(0.85)
        }
    }

    func beltProgressRowsFromDefaults() -> [BeltRow] {
        let defaults = UserDefaults.standard

        let defs: [(id: String, title: String, color: Color)] = [
            ("yellow", isEnglish ? "Belt: Yellow" : "חגורה: צהובה", .yellow),
            ("orange", isEnglish ? "Belt: Orange" : "חגורה: כתומה", .orange),
            ("green", isEnglish ? "Belt: Green" : "חגורה: ירוקה", .green),
            ("blue", isEnglish ? "Belt: Blue" : "חגורה: כחולה", .blue),
            ("brown", isEnglish ? "Belt: Brown" : "חגורה: חומה", Color(hex: 0xFF6D4C41)),
            ("black", isEnglish ? "Belt: Black" : "חגורה: שחורה", .black)
        ]

        func readPercent(for beltId: String) -> Int {
            let candidateKeys = [
                "progress_\(beltId)",
                "\(beltId)_progress",
                "\(beltId)Percent",
                "\(beltId)_percentage"
            ]

            for key in candidateKeys {
                if let number = defaults.object(forKey: key) as? NSNumber {
                    return max(0, min(100, number.intValue))
                }
            }

            return 0
        }

        return defs.map { def in
            BeltRow(
                title: def.title,
                pct: readPercent(for: def.id),
                color: def.color
            )
        }
    }

    func feedbackTap() {
        if clickSounds {
            playClick()
        }
        if hapticsOn {
            hapticLight()
        }
    }

    func playClick() {
        DispatchQueue.main.async {
            AudioServicesPlaySystemSound(1104)
        }
    }

    func hapticLight() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        }
    }

    func hapticSuccess() {
        DispatchQueue.main.async {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
    }

    func hapticError() {
        DispatchQueue.main.async {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
        }
    }

    func toast(_ text: String) {
        ToastCenter.shared.show(text)
    }

    func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}
