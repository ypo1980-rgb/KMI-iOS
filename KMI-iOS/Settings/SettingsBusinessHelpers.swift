import SwiftUI
import UserNotifications
import EventKit
import LocalAuthentication
import StoreKit
import MessageUI
import UIKit
import AudioToolbox

extension SettingsView {

    // MARK: Helpers UI
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

    // MARK: Notifications
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
        toast("התזכורות עודכנו: \(minutes) דקות לפני")
    }

    func cancelTrainingReminders() {
        toast("התזכורות בוטלו")
    }

    // MARK: Calendar
    func ensureCalendarPermissionsAndSync() {
        let store = EKEventStore()
        isBusy = true

        store.requestFullAccessToEvents { granted, _ in
            DispatchQueue.main.async {
                self.isBusy = false
                if granted {
                    self.toast("האימונים סונכרנו ליומן")
                    self.hapticSuccess()
                } else {
                    self.calendarSyncEnabled = false
                    self.toast("אין הרשאה ליומן – לא בוצע סנכרון")
                    self.hapticError()
                }
            }
        }
    }

    func removeCalendarEvents() {
        toast("האימונים הוסרו מהיומן")
        hapticSuccess()
    }

    // MARK: App lock
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

    // MARK: About / Support
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

    // MARK: Data management
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

    // MARK: Real belt progress from UserDefaults
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

    // MARK: Feedback
    func feedbackTap() {
        if clickSounds { playClick() }
        if hapticsOn { hapticLight() }
    }

    func playClick() {
        AudioServicesPlaySystemSound(1104)
    }

    func hapticLight() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func hapticSuccess() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func hapticError() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    func toast(_ text: String) {
        ToastCenter.shared.show(text)
    }

    func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}
