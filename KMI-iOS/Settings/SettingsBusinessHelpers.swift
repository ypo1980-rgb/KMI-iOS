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
                span: .thisEvent,
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

            let branch = self.resolvedCalendarBranch()
            let group = self.resolvedCalendarGroup()

            guard !branch.isEmpty else {
                self.calendarSyncEnabled = false
                self.selectedCalendarSyncEnabled = false
                self.toast(
                    self.tr(
                        "לא נבחר סניף",
                        "No branch selected"
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

            let trainings = TrainingCatalogIOS.trainingsFor(
                branch: branch,
                group: group
            )

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
                let retainedIDs =
                    try self.stageOwnedCalendarEventRemoval(
                        using: store
                    )

                var newEvents: [EKEvent] = []

                for training in trainings {
                    let event = EKEvent(eventStore: store)

                    event.calendar = targetCalendar
                    event.title = self.calendarEventTitle(
                        for: training,
                        group: group
                    )
                    event.startDate = training.date
                    event.endDate = self.endDate(for: training)
                    event.notes = [
                        self.calendarNotes(
                            for: training,
                            branch: branch,
                            group: group
                        ),
                        marker
                    ]
                    .joined(separator: "\n")
                    event.location = training.address
                    event.timeZone = TimeZone(
                        identifier: "Asia/Jerusalem"
                    )

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
                        "סונכרנו \(newEvents.count) אימונים ליומן",
                        "\(newEvents.count) trainings were synced to the calendar"
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

    private func calendarEventTitle(for training: TrainingData, group: String) -> String {
        let cleanGroup = group.trimmingCharacters(in: .whitespacesAndNewlines)

        if isEnglish {
            return cleanGroup.isEmpty ? "K.M.I Training" : "K.M.I Training – \(cleanGroup)"
        }

        return cleanGroup.isEmpty ? "אימון ק.מ.י" : "אימון ק.מ.י – \(cleanGroup)"
    }

    private func calendarNotes(for training: TrainingData, branch: String, group: String) -> String {
        var parts: [String] = []

        if !branch.isEmpty {
            parts.append(isEnglish ? "Branch: \(branch)" : "סניף: \(branch)")
        }

        if !group.isEmpty {
            parts.append(isEnglish ? "Group: \(group)" : "קבוצה: \(group)")
        }

        parts.append(isEnglish ? "Place: \(training.place)" : "מקום: \(training.place)")
        parts.append(isEnglish ? "Address: \(training.address)" : "כתובת: \(training.address)")
        parts.append(isEnglish ? "Coach: \(training.coach)" : "מאמן: \(training.coach)")
        parts.append(isEnglish ? "Time: \(training.startText) - \(training.endText)" : "שעה: \(training.startText) - \(training.endText)")

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
