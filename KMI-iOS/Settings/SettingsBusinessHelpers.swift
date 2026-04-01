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
            Text(title)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Toggle("", isOn: Binding(
                get: { isOn.wrappedValue },
                set: { newValue in
                    isOn.wrappedValue = newValue
                    onChanged(newValue)
                }
            ))
            .labelsHidden()
        }
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
                            toast("אין הרשאה להתראות – לא הופעלו תזכורות")
                            hapticError()
                        }
                    }
                }

            case .denied:
                DispatchQueue.main.async {
                    toast("התראות חסומות בהגדרות המכשיר")
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
        content.title = "תזכורת לאימון"
        content.body = "האימון מתחיל בעוד \(minutes) דקות"
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

        toast("התזכורת נקבעה \(minutes) דקות לפני האימון")
        hapticSuccess()
    }

    func cancelTrainingReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["training_reminder"]
        )

        toast("התזכורות בוטלו")
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
                    self.toast("אין הרשאה ליומן")
                    self.hapticError()
                    return
                }

                let branch = self.resolvedCalendarBranch()
                let group = self.resolvedCalendarGroup()

                guard !branch.isEmpty else {
                    self.calendarSyncEnabled = false
                    self.toast("לא נבחר סניף")
                    self.hapticError()
                    return
                }

                let trainings = TrainingCatalogIOS.trainingsFor(branch: branch, group: group)

                guard !trainings.isEmpty else {
                    self.calendarSyncEnabled = false
                    self.toast("לא נמצאו אימונים לסניף ולקבוצה שלך")
                    self.hapticError()
                    return
                }

                self.removeCalendarEvents(using: store)

                guard let targetCalendar = store.defaultCalendarForNewEvents else {
                    self.calendarSyncEnabled = false
                    self.toast("לא נמצא יומן ברירת מחדל")
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
                    self.toast("סונכרנו \(addedCount) אימונים ליומן")
                    self.hapticSuccess()
                } else {
                    self.calendarSyncEnabled = false
                    self.toast("לא ניתן היה להוסיף אימונים ליומן")
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
                    self.toast("אין הרשאה ליומן")
                    self.hapticError()
                    return
                }

                self.removeCalendarEvents(using: store)
                self.toast("אירועי האימונים הוסרו מהיומן")
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

        for event in events where event.title.contains("אימון ק.מ.י") || event.title.contains("KMI") {
            try? store.remove(event, span: .thisEvent)
        }
    }

    private func resolvedCalendarBranch() -> String {
        (
            UserDefaults.standard.string(forKey: "kmi.user.branch") ??
            UserDefaults.standard.string(forKey: "active_branch") ??
            ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resolvedCalendarGroup() -> String {
        (
            UserDefaults.standard.string(forKey: "kmi.user.group") ??
            UserDefaults.standard.string(forKey: "active_group") ??
            ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func calendarEventTitle(for training: TrainingData, group: String) -> String {
        let cleanGroup = group.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanGroup.isEmpty ? "אימון ק.מ.י" : "אימון ק.מ.י – \(cleanGroup)"
    }

    private func calendarNotes(for training: TrainingData, branch: String, group: String) -> String {
        var parts: [String] = []

        if !branch.isEmpty {
            parts.append("סניף: \(branch)")
        }

        if !group.isEmpty {
            parts.append("קבוצה: \(group)")
        }

        parts.append("מקום: \(training.place)")
        parts.append("כתובת: \(training.address)")
        parts.append("מאמן: \(training.coach)")
        parts.append("שעה: \(training.startText) - \(training.endText)")

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
            toast("ביומטרי לא זמין במכשיר")
            hapticError()
            completion(false)
            return
        }

        let ctx = LAContext()
        ctx.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "אימות להפעלת נעילת האפליקציה"
        ) { ok, _ in
            DispatchQueue.main.async {
                if ok {
                    self.toast("זיהוי ביומטרי הופעל")
                    self.hapticSuccess()
                    completion(true)
                } else {
                    self.toast("האימות נכשל")
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
        if pin.count < 4 {
            pinError = "הסיסמה צריכה להיות לפחות 4 תווים"
            return
        }

        if pin != pinConfirm {
            pinError = "הסיסמאות אינן תואמות"
            return
        }

        appLockPin = pin
        appLockMode = "pin"
        toast("נעילה באמצעות סיסמה הופעלה")
        hapticSuccess()
        resetPinDialog()
        showPinDialog = false
    }

    func appVersionLine() -> String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "גרסה \(v) (\(b))"
    }

    func sendFeedbackEmail() {
        let body = """

        ---
        פרטי מערכת (לעזרה באיתור תקלות):
        חבילה: \(Bundle.main.bundleIdentifier ?? "?")
        \(appVersionLine())
        מכשיר: \(UIDevice.current.model)
        iOS: \(UIDevice.current.systemVersion)
        """

        let to = "support@kmi.example"
        let subject = "משוב על האפליקציה"

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
        let text = "הורידו את KMI – ק.מ.י"
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
            return "לבנה"
        case "yellow", "צהוב", "צהובה":
            return "צהובה"
        case "orange", "כתום", "כתומה":
            return "כתומה"
        case "green", "ירוק", "ירוקה":
            return "ירוקה"
        case "blue", "כחול", "כחולה":
            return "כחולה"
        case "brown", "חום", "חומה":
            return "חומה"
        case "black", "שחור", "שחורה":
            return "שחורה"
        default:
            return "לבנה"
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
            ("yellow", "חגורה: צהובה", .yellow),
            ("orange", "חגורה: כתומה", .orange),
            ("green", "חגורה: ירוקה", .green),
            ("blue", "חגורה: כחולה", .blue),
            ("brown", "חגורה: חומה", Color(hex: 0xFF6D4C41)),
            ("black", "חגורה: שחורה", .black)
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
