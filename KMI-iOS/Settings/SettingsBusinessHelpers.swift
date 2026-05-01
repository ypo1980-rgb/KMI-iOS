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

    func requestNotificationPermissionIfNeeded(onGranted: @escaping () -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async { onGranted() }

            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
                    DispatchQueue.main.async {
                        if ok {
                            onGranted()
                        } else {
                            trainingRemindersEnabled = false
                            toast(tr(
                                "אין הרשאה להתראות – לא הופעלו תזכורות",
                                "Notification permission was not granted - reminders were not enabled"
                            ))
                            hapticError()
                        }
                    }
                }

            case .denied:
                DispatchQueue.main.async {
                    toast(tr(
                        "התראות חסומות בהגדרות המכשיר",
                        "Notifications are blocked in device settings"
                    ))
                    hapticError()
                }

            @unknown default:
                DispatchQueue.main.async { onGranted() }
            }
        }
    }

    func scheduleTrainingReminders(minutes: Int) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["training_reminder"]
        )

        let content = UNMutableNotificationContent()
        content.title = tr("תזכורת לאימון ק.מ.י", "K.M.I training reminder")
        content.body = tr(
            "האימון מתחיל בעוד \(minutes) דקות",
            "Training starts in \(minutes) minutes"
        )
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(minutes * 60),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "training_reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)

        toast(tr(
            "התזכורת נקבעה \(minutes) דקות לפני האימון",
            "Reminder set \(minutes) minutes before training"
        ))
        hapticSuccess()
    }

    func cancelTrainingReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["training_reminder"]
        )

        toast(tr("התזכורות בוטלו", "Reminders were cancelled"))
        hapticSuccess()
    }

    func ensureCalendarPermissionsAndSync() {
        let store = EKEventStore()
        isBusy = true

        store.requestFullAccessToEvents { granted, _ in
            DispatchQueue.main.async {
                self.isBusy = false

                guard granted else {
                    self.calendarSyncEnabled = false
                    self.toast(self.tr("אין הרשאה ליומן", "Calendar permission was not granted"))
                    self.hapticError()
                    return
                }

                let branch = self.resolvedCalendarBranch()
                let group = self.resolvedCalendarGroup()

                guard !branch.isEmpty else {
                    self.calendarSyncEnabled = false
                    self.toast(self.tr("לא נבחר סניף", "No branch selected"))
                    self.hapticError()
                    return
                }

                let trainings = TrainingCatalogIOS.trainingsFor(branch: branch, group: group)

                guard !trainings.isEmpty else {
                    self.calendarSyncEnabled = false
                    self.toast(self.tr(
                        "לא נמצאו אימונים לסניף ולקבוצה שלך",
                        "No trainings were found for your branch and group"
                    ))
                    self.hapticError()
                    return
                }

                self.removeCalendarEvents(using: store)

                guard let targetCalendar = store.defaultCalendarForNewEvents else {
                    self.calendarSyncEnabled = false
                    self.toast(self.tr("לא נמצא יומן ברירת מחדל", "Default calendar was not found"))
                    self.hapticError()
                    return
                }

                var addedCount = 0

                for training in trainings {
                    let event = EKEvent(eventStore: store)
                    event.calendar = targetCalendar
                    event.title = self.calendarEventTitle(for: training, group: group)
                    event.startDate = training.date
                    event.endDate = self.endDate(for: training)
                    event.notes = self.calendarNotes(for: training, branch: branch, group: group)
                    event.location = training.address
                    event.timeZone = TimeZone(identifier: "Asia/Jerusalem")

                    do {
                        try store.save(event, span: .thisEvent)
                        addedCount += 1
                    } catch {
                        print("KMI calendar save error:", error.localizedDescription)
                    }
                }

                if addedCount > 0 {
                    self.toast(self.tr(
                        "סונכרנו \(addedCount) אימונים ליומן",
                        "\(addedCount) trainings were synced to the calendar"
                    ))
                    self.hapticSuccess()
                } else {
                    self.calendarSyncEnabled = false
                    self.toast(self.tr(
                        "לא ניתן היה להוסיף אימונים ליומן",
                        "Could not add trainings to the calendar"
                    ))
                    self.hapticError()
                }
            }
        }
    }

    func removeCalendarEvents() {
        let store = EKEventStore()

        store.requestFullAccessToEvents { granted, _ in
            DispatchQueue.main.async {
                guard granted else {
                    self.toast(self.tr("אין הרשאה ליומן", "Calendar permission was not granted"))
                    self.hapticError()
                    return
                }

                self.removeCalendarEvents(using: store)
                self.toast(self.tr("אירועי האימונים הוסרו מהיומן", "Training events were removed from the calendar"))
                self.hapticSuccess()
            }
        }
    }

    private func removeCalendarEvents(using store: EKEventStore) {
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let end = Calendar.current.date(byAdding: .day, value: 365, to: Date()) ?? Date()

        let predicate = store.predicateForEvents(
            withStart: start,
            end: end,
            calendars: nil
        )

        let events = store.events(matching: predicate)

        for event in events {
            let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)

            let isKmiTrainingEvent =
                title.contains("אימון ק.מ.י") ||
                title.contains("KMI") ||
                title.contains("K.M.I") ||
                title.localizedCaseInsensitiveContains("K.M.I Training")

            if isKmiTrainingEvent {
                try? store.remove(event, span: .thisEvent)
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
        let raw = training.endText.trimmingCharacters(in: .whitespacesAndNewlines)
        let pieces = raw.split(separator: ":")

        guard pieces.count == 2,
              let hour = Int(pieces[0]),
              let minute = Int(pieces[1]) else {
            return training.date.addingTimeInterval(90 * 60)
        }

        var comps = Calendar.current.dateComponents([.year, .month, .day], from: training.date)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0

        return Calendar.current.date(from: comps) ?? training.date.addingTimeInterval(90 * 60)
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
            let cacheURL = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let files = try fm.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil)
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
