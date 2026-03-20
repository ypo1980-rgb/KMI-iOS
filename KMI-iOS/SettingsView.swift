import SwiftUI
import UserNotifications
import EventKit
import LocalAuthentication
import StoreKit
import MessageUI
import UIKit
import AudioToolbox

// MARK: - SettingsContentView (Content-only; NO local top bar / icon strip)
struct SettingsView: View {

    // ✅ Global nav (מגיע מהמסך הגלובאלי)
    @ObservedObject var nav: AppNavModel

    // MARK: Stored settings (UserDefaults)
    @AppStorage("fullName") private var fullName: String = "שם מלא לא מוגדר"
    @AppStorage("phone") private var phone: String = ""
    @AppStorage("email") private var email: String = ""
    @AppStorage("region") private var region: String = ""
    @AppStorage("branch") private var branch: String = ""

    @AppStorage("user_role") private var userRole: String = "trainee" // "coach" / "trainee"

    // Training reminders
    @AppStorage("training_reminders_enabled") private var trainingRemindersEnabled: Bool = true
    @AppStorage("training_reminder_minutes") private var trainingReminderMinutes: Int = 60

    // Free sessions reminders
    @AppStorage("free_sessions_reminders_enabled") private var freeSessionsRemindersEnabled: Bool = false

    // Calendar sync
    @AppStorage("calendar_sync_enabled") private var calendarSyncEnabled: Bool = false

    // UX
    @AppStorage("click_sounds") private var clickSounds: Bool = false
    @AppStorage("haptics_on") private var hapticsOn: Bool = false

    // Theme
    @AppStorage("theme_mode") private var themeMode: String = "system" // system/light/dark

    // App lock
    @AppStorage("app_lock_mode") private var appLockMode: String = "none" // none/biometric/pin
    @AppStorage("app_lock_pin") private var appLockPin: String = ""       // WARNING: store securely later

    // Data management
    @AppStorage("coach_broadcast_recents_json") private var coachBroadcastRecentsJson: String = ""

    // MARK: UI State
    @State private var isBusy: Bool = false
    @State private var showPinDialog: Bool = false
    @State private var pin: String = ""
    @State private var pinConfirm: String = ""
    @State private var pinError: String? = nil

    @State private var mailData: MailData? = nil

    @State private var goLegal: Bool = false
    @State private var legalInitialTab: Int = 0

    private var isCoach: Bool { userRole == "coach" }

    private enum LegalTab: Int, Identifiable {
        case terms = 0
        case privacy = 1
        case accessibility = 2
        var id: Int { rawValue }
    }

    private var headerGradient: LinearGradient {
        if isCoach {
            return LinearGradient(
                colors: [Color(hex: 0xFF7B1FA2), Color(hex: 0xFF512DA8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color(hex: 0xFF1565C0), Color(hex: 0xFF26A69A)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var sectionIconTint: Color {
        isCoach ? Color(hex: 0xFF6A1B9A) : Color(hex: 0xFF1565C0)
    }

    // MARK: Body (CONTENT ONLY)
    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {

                    header
                    settingsCards

                    actionButtons
                        .padding(.top, 6)

                    Spacer(minLength: 12)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .overlay {
            if isBusy { LoadingOverlay() }
        }
        .preferredColorScheme(colorSchemeFromThemeMode(themeMode))
        .sheet(item: $mailData) { data in
            MailComposeView(data: data)
        }
        .navigationDestination(isPresented: $goLegal) {
            LegalView(initialTab: legalInitialTab)
        }
        .sheet(isPresented: $showPinDialog) {
            PinSetupSheet(
                pin: $pin,
                pinConfirm: $pinConfirm,
                pinError: $pinError,
                onCancel: { resetPinDialog(); showPinDialog = false },
                onSave: { onSavePin() }
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: Header
    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                headerGradient
                    .ignoresSafeArea(edges: .top)

                VStack(spacing: 10) {
                    HStack {
                        Button {
                            hapticSuccess()
                            // HOOK: navigate to registration/edit screen
                        } label: {
                            Text("ערוך פרטים")
                                .font(.system(size: 15, weight: .semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.accentColor.opacity(0.95))
                                .foregroundStyle(Color.white)
                                .clipShape(Capsule())
                        }

                        Spacer()

                        Text("הגדרות")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(Color.white)
                    }

                    profileCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(.top, 8)
    }

    private var profileCard: some View {
        HStack(spacing: 10) {
            Image(systemName: isCoach ? "checkmark.seal.fill" : "person.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isCoach ? Color(hex: 0xFF6A1B9A) : Color(hex: 0xFF1565C0))

            VStack(alignment: .trailing, spacing: 4) {
                Text(fullName.isEmpty ? "משתמש" : fullName)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .trailing)

                if !phone.isEmpty {
                    Text(phone)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Cards
    private var settingsCards: some View {
        VStack(spacing: 16) {

            // --- Training reminders
            SettingsCard(
                title: "תזכורות אימון",
                subtitle: "קבל התראה לפני תחילת אימון",
                iconSystemName: "alarm.fill",
                iconTint: sectionIconTint
            ) {
                VStack(spacing: 10) {
                    HStack {
                        Text(trainingRemindersEnabled ? "כמה דקות לפני האימון לקבל תזכורת?" : "")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Toggle("", isOn: Binding(
                            get: { trainingRemindersEnabled },
                            set: { newValue in
                                trainingRemindersEnabled = newValue
                                if newValue {
                                    requestNotificationPermissionIfNeeded {
                                        scheduleTrainingReminders(minutes: trainingReminderMinutes)
                                    }
                                } else {
                                    cancelTrainingReminders()
                                }
                                feedbackTap()
                            }
                        ))
                        .labelsHidden()
                    }

                    if trainingRemindersEnabled {
                        KmiSegmentedTabsInt(
                            options: [30, 60, 90],
                            selected: $trainingReminderMinutes,
                            label: { minutes in "\(minutes) דק׳\nלפני" }
                        ) { minutes in
                            trainingReminderMinutes = minutes
                            scheduleTrainingReminders(minutes: minutes)
                            feedbackTap()
                        }
                    }
                }
            }

            // --- Free sessions reminders
            SettingsCard(
                title: "תזכורות אימונים חופשיים",
                subtitle: "קבל התראה לפני אימון חופשי שאישרת הגעה",
                iconSystemName: "bell.badge.fill",
                iconTint: sectionIconTint
            ) {
                HStack {
                    Text("התראות 30 ו-10 דקות לפני אימון חופשי שסימנת \"אני מגיע\"")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Toggle("", isOn: Binding(
                        get: { freeSessionsRemindersEnabled },
                        set: { newValue in
                            freeSessionsRemindersEnabled = newValue
                            if newValue {
                                requestNotificationPermissionIfNeeded { }
                            }
                            feedbackTap()
                        }
                    ))
                    .labelsHidden()
                }
            }

            // --- Calendar sync
            SettingsCard(
                title: "סנכרון ליומן",
                subtitle: "ייווצרו/עודכנו אירועים שבועיים",
                iconSystemName: "calendar",
                iconTint: sectionIconTint
            ) {
                VStack(spacing: 10) {
                    HStack {
                        Text("סנכרן אימונים ליומן במכשיר")
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Toggle("", isOn: Binding(
                            get: { calendarSyncEnabled },
                            set: { newValue in
                                calendarSyncEnabled = newValue
                                if newValue { ensureCalendarPermissionsAndSync() }
                                else { removeCalendarEvents() }
                                feedbackTap()
                            }
                        ))
                        .labelsHidden()
                    }
                }
            }

            // --- UX
            SettingsCard(
                title: "חוויית משתמש",
                subtitle: "צלילים, רטט ושיפור חוויית האינטראקציה",
                iconSystemName: "slider.horizontal.3",
                iconTint: sectionIconTint
            ) {
                VStack(spacing: 10) {
                    toggleRow(title: "צליל הקשה בכפתורים", isOn: $clickSounds) { enabled in
                        if enabled { playClick() }
                        feedbackTap()
                    }
                    toggleRow(title: "רטט קצר בעת סימון ✓/✗", isOn: $hapticsOn) { _ in
                        feedbackTap()
                    }
                }
            }

            // --- Appearance
            SettingsCard(
                title: "נראות אפליקציה",
                subtitle: "בחר מצב מסך עם ניגודיות נוחה לעיניים",
                iconSystemName: "paintpalette.fill",
                iconTint: sectionIconTint
            ) {
                VStack(spacing: 10) {
                    Text("בחר מצב תצוגה:")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    KmiThemeTabs(themeMode: $themeMode) { feedbackTap() }

                    Text("הטקסט והצבעים יתאימו אוטומטית למצב שבחרת (כולל מצב לפי מערכת).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            // --- App lock
            SettingsCard(
                title: "נעילת אפליקציה",
                subtitle: "בחר שיטת נעילה להגנה על האפליקציה",
                iconSystemName: "lock.fill",
                iconTint: sectionIconTint
            ) {
                VStack(spacing: 10) {
                    KmiLockTabs(lockMode: $appLockMode) { mode in
                        switch mode {
                        case "none":
                            feedbackTap()

                        case "biometric":
                            authenticateBiometricIfAvailable { ok in
                                if !ok { appLockMode = "none" }
                                feedbackTap()
                            }

                        case "pin":
                            resetPinDialog()
                            showPinDialog = true

                        default:
                            break
                        }
                    }

                    if !biometricAvailable() {
                        Text("ביומטרי לא זמין במכשיר או לא הוגדר למשתמש.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }

            // --- Stats
            SettingsCard(
                title: "סטטיסטיקות",
                subtitle: "התקדמות לפי חגורות ונושאים",
                iconSystemName: "chart.bar.fill",
                iconTint: sectionIconTint
            ) {
                VStack(spacing: 10) {
                    Text("דרגתי הנוכחית: חגורה \(currentBeltHeb())")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(beltColorForText())
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    BeltsProgressBarsIOS(rows: demoBeltProgressRows())
                }
            }

            // --- Data management
            SettingsCard(
                title: "ניהול נתונים",
                subtitle: "ניקוי נתונים מקומיים במכשיר",
                iconSystemName: "externaldrive.fill",
                iconTint: sectionIconTint
            ) {
                VStack(spacing: 10) {
                    Button {
                        coachBroadcastRecentsJson = ""
                        toast("היסטוריית השידורים נוקתה")
                        hapticSuccess()
                    } label: {
                        Text("נקה היסטוריית שידורים")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        isBusy = true
                        let ok = clearAppCacheIOS()
                        isBusy = false
                        toast(ok ? "נוקו קבצי המטמון" : "ניקוי נכשל")
                        ok ? hapticSuccess() : hapticError()
                    } label: {
                        Text("נקה מטמון אפליקציה")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                }
            }

            // --- Legal
            SettingsCard(
                title: "מידע משפטי",
                subtitle: "מסמכים רשמיים ומידע חשוב",
                iconSystemName: "gavel.fill",
                iconTint: sectionIconTint
            ) {
                VStack(spacing: 12) {
                    LegalTile(
                        title: "מדיניות פרטיות",
                        subtitle: "איך אנחנו שומרים על הנתונים שלך",
                        systemIcon: "lock.fill"
                    ) {
                        legalInitialTab = 1
                        goLegal = true
                        feedbackTap()
                    }

                    LegalTile(
                        title: "תנאי שימוש",
                        subtitle: "כללי שימוש והתחייבויות המשתמש",
                        systemIcon: "doc.text.fill"
                    ) {
                        legalInitialTab = 0
                        goLegal = true
                        feedbackTap()
                    }

                    LegalTile(
                        title: "הצהרת נגישות",
                        subtitle: "מידע על התאמות ונגישות באפליקציה",
                        systemIcon: "accessibility"
                    ) {
                        legalInitialTab = 2
                        goLegal = true
                        feedbackTap()
                    }
                }
            }

            // --- About & Support
            SettingsCard(
                title: "אודות ותמיכה",
                subtitle: "ספרו לנו איך אפשר לשפר",
                iconSystemName: "person.2.fill",
                iconTint: sectionIconTint
            ) {
                VStack(spacing: 10) {
                    Text(appVersionLine())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    HStack(spacing: 10) {
                        Button {
                            sendFeedbackEmail()
                            hapticSuccess()
                        } label: {
                            Text("שלח משוב")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            requestReview()
                            hapticSuccess()
                        } label: {
                            Text("דרג בחנות")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        shareApp()
                        hapticSuccess()
                    } label: {
                        Text("שתף את האפליקציה")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: Action buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {

            Button {
                // ✅ מסך גלובאלי: חוזרים אחורה בנתיב
                nav.pop()
            } label: {
                Text("ביטול")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)

            Button {
                // ✅ ההעדפות נשמרות inline; פשוט חוזרים
                nav.pop()
            } label: {
                Text("אישור")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: Helpers UI
    @ViewBuilder
    private func toggleRow(title: String, isOn: Binding<Bool>, onChanged: @escaping (Bool) -> Void) -> some View {
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

    // MARK: Notifications (hooks)
    private func requestNotificationPermissionIfNeeded(onGranted: @escaping () -> Void) {
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

    private func scheduleTrainingReminders(minutes: Int) {
        toast("התזכורות עודכנו: \(minutes) דקות לפני")
    }

    private func cancelTrainingReminders() {
        toast("התזכורות בוטלו")
    }

    // MARK: Calendar (hooks)
    private func ensureCalendarPermissionsAndSync() {
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

    private func removeCalendarEvents() {
        toast("האימונים הוסרו מהיומן")
        hapticSuccess()
    }

    // MARK: App lock
    private func biometricAvailable() -> Bool {
        let ctx = LAContext()
        var err: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
    }

    private func authenticateBiometricIfAvailable(completion: @escaping (Bool) -> Void) {
        guard biometricAvailable() else {
            toast("ביומטרי לא זמין במכשיר")
            hapticError()
            completion(false)
            return
        }
        let ctx = LAContext()
        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "אימות להפעלת נעילת האפליקציה") { ok, _ in
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

    private func resetPinDialog() {
        pin = ""
        pinConfirm = ""
        pinError = nil
    }

    private func onSavePin() {
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
    private func appVersionLine() -> String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "גרסה \(v) (\(b))"
    }

    private func sendFeedbackEmail() {
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

    private func requestReview() {
        guard let scene = activeWindowScene() else { return }
        AppStore.requestReview(in: scene)
    }

    private func shareApp() {
        let text = "הורידו את KMI – ק.מ.י"
        ShareSheet.present(items: [text])
    }

    // MARK: Data management
    private func clearAppCacheIOS() -> Bool {
        do {
            let fm = FileManager.default
            let cacheURL = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let files = try fm.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil)
            for f in files { try fm.removeItem(at: f) }
            return true
        } catch {
            return false
        }
    }

    // MARK: Demo belt progress (hook to Shared later)
    private func currentBeltHeb() -> String {
        return "לבנה"
    }

    private func beltColorForText() -> Color {
        return Color.black.opacity(0.85)
    }

    private func demoBeltProgressRows() -> [BeltRow] {
        return [
            .init(title: "חגורה: צהובה", pct: 22, color: .yellow),
            .init(title: "חגורה: כתומה", pct: 15, color: .orange),
            .init(title: "חגורה: ירוקה", pct: 8,  color: .green),
            .init(title: "חגורה: כחולה", pct: 3,  color: .blue),
            .init(title: "חגורה: חומה",  pct: 0,  color: Color(hex: 0xFF6D4C41)),
            .init(title: "חגורה: שחורה", pct: 0,  color: .black)
        ]
    }

    // MARK: Feedback (sound/haptics/toast)
    private func feedbackTap() {
        if clickSounds { playClick() }
        if hapticsOn { hapticLight() }
    }

    private func playClick() {
        AudioServicesPlaySystemSound(1104)
    }

    private func hapticLight() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func hapticSuccess() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func hapticError() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    private func toast(_ text: String) {
        ToastCenter.shared.show(text)
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

private func activeWindowScene() -> UIWindowScene? {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first { scene in
            scene.activationState == .foregroundActive
        }
}

// MARK: - SettingsCard
struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let iconSystemName: String?
    let iconTint: Color?
    @ViewBuilder let content: Content

    init(title: String,
         subtitle: String? = nil,
         iconSystemName: String? = nil,
         iconTint: Color? = nil,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.iconSystemName = iconSystemName
        self.iconTint = iconTint
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                if let iconSystemName {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill((iconTint ?? .accentColor).opacity(0.12))
                            .frame(width: 34, height: 34)
                        Image(systemName: iconSystemName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(iconTint ?? .accentColor)
                    }
                }

                VStack(alignment: .trailing, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .lineLimit(1)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .lineLimit(2)
                    }
                }
            }

            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - KmiSegmentedTabsInt (minutes 30/60/90)
struct KmiSegmentedTabsInt: View {
    let options: [Int]
    @Binding var selected: Int
    let label: (Int) -> String
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { opt in
                let isSel = opt == selected
                Button {
                    selected = opt
                    onSelect(opt)
                } label: {
                    Text(label(opt))
                        .font(.system(size: 13, weight: isSel ? .bold : .semibold))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(isSel ? Color.white : Color.primary)
                        .background(isSel ? Color.accentColor : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(UIColor.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - KmiThemeTabs (system/light/dark)
struct KmiThemeTabs: View {
    @Binding var themeMode: String
    let onChanged: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            themeButton("system", "לפי\nמערכת")
            themeButton("light", "מצב\nבהיר")
            themeButton("dark", "מצב\nכהה")
        }
        .background(Color(UIColor.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func themeButton(_ mode: String, _ text: String) -> some View {
        let selected = themeMode == mode
        return Button {
            themeMode = mode
            onChanged()
        } label: {
            Text(text)
                .font(.system(size: 13, weight: selected ? .bold : .semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(selected ? Color.accentColor : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

private func colorSchemeFromThemeMode(_ mode: String) -> ColorScheme? {
    switch mode {
    case "light": return .light
    case "dark":  return .dark
    default:      return nil
    }
}

// MARK: - KmiLockTabs (none/biometric/pin)
struct KmiLockTabs: View {
    @Binding var lockMode: String
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            lockButton("none", "ללא\nנעילה")
            lockButton("biometric", "נעילה\nבאצבע")
            lockButton("pin", "נעילה\nבסיסמה")
        }
        .background(Color(UIColor.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func lockButton(_ mode: String, _ text: String) -> some View {
        let selected = lockMode == mode
        return Button {
            lockMode = mode
            onSelect(mode)
        } label: {
            Text(text)
                .font(.system(size: 13, weight: selected ? .bold : .semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(selected ? Color.accentColor : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - LegalTile
struct LegalTile: View {
    let title: String
    let subtitle: String
    let systemIcon: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: systemIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .trailing, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .lineLimit(2)

                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(UIColor.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - BeltsProgressBarsIOS
struct BeltRow: Identifiable {
    let id = UUID()
    let title: String
    let pct: Int
    let color: Color
}

struct BeltsProgressBarsIOS: View {
    let rows: [BeltRow]

    var body: some View {
        GeometryReader { geo in
            let barMaxWidth = geo.size.width

            VStack(spacing: 10) {
                ForEach(rows) { row in
                    VStack(spacing: 6) {
                        HStack {
                            Text("\(row.pct)%")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(row.title.contains("שחורה") ? Color.primary : row.color)

                            Spacer()

                            Text(row.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(row.title.contains("שחורה") ? Color.primary : row.color)
                        }

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 999, style: .continuous)
                                .fill(Color.black.opacity(0.08))
                                .frame(height: 12)

                            RoundedRectangle(cornerRadius: 999, style: .continuous)
                                .fill(row.color)
                                .frame(
                                    width: max(0, min(100, CGFloat(row.pct))) / 100.0 * barMaxWidth,
                                    height: 12
                                )
                        }
                    }
                }
            }
        }
        .frame(height: CGFloat(max(rows.count, 1)) * 36)
    }
}

// MARK: - LoadingOverlay
struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
            ProgressView()
                .padding(18)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

// MARK: - PinSetupSheet
struct PinSetupSheet: View {
    @Binding var pin: String
    @Binding var pinConfirm: String
    @Binding var pinError: String?

    let onCancel: () -> Void
    let onSave: () -> Void

    @State private var pinVisible: Bool = false
    @State private var pinConfirmVisible: Bool = false

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {

                Group {
                    SecureFieldWithToggle(title: "סיסמה", text: $pin, visible: $pinVisible)
                    SecureFieldWithToggle(title: "אימות סיסמה", text: $pinConfirm, visible: $pinConfirmVisible)
                }

                if let pinError, !pinError.isEmpty {
                    Text(pinError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Spacer()
            }
            .padding(16)
            .navigationTitle("הגדרת סיסמה")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("ביטול") { onCancel() } }
                ToolbarItem(placement: .topBarTrailing) { Button("שמירה") { onSave() } }
            }
        }
    }
}

struct SecureFieldWithToggle: View {
    let title: String
    @Binding var text: String
    @Binding var visible: Bool

    var body: some View {
        HStack {
            Button { visible.toggle() } label: {
                Image(systemName: visible ? "eye.slash.fill" : "eye.fill")
                    .foregroundStyle(.secondary)
            }

            if visible {
                TextField(title, text: $text)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            } else {
                SecureField(title, text: $text)
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Mail
struct MailData: Identifiable {
    let id = UUID()
    let to: String
    let subject: String
    let body: String
}

struct MailComposeView: UIViewControllerRepresentable {
    let data: MailData

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients([data.to])
        vc.setSubject(data.subject)
        vc.setMessageBody(data.body, isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) { }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - ShareSheet
enum ShareSheet {
    static func present(items: [Any]) {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }

        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        root.present(vc, animated: true)
    }
}

// MARK: - Toast
final class ToastCenter {
    static let shared = ToastCenter()

    private var window: UIWindow?
    private var label: UILabel?

    func show(_ text: String) {
        DispatchQueue.main.async {
            self.ensureWindow()
            self.label?.text = text
            self.label?.alpha = 0
            UIView.animate(withDuration: 0.2) {
                self.label?.alpha = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                UIView.animate(withDuration: 0.2) {
                    self.label?.alpha = 0
                }
            }
        }
    }

    private func ensureWindow() {
        if window != nil { return }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        let w = UIWindow(windowScene: scene)
        w.backgroundColor = .clear
        w.windowLevel = .alert + 1

        let lbl = UILabel()
        lbl.numberOfLines = 2
        lbl.textAlignment = .center
        lbl.textColor = .white
        lbl.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        lbl.layer.cornerRadius = 12
        lbl.layer.masksToBounds = true
        lbl.font = UIFont.systemFont(ofSize: 14, weight: .semibold)

        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        vc.view.addSubview(lbl)

        lbl.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            lbl.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            lbl.bottomAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            lbl.widthAnchor.constraint(lessThanOrEqualTo: vc.view.widthAnchor, multiplier: 0.85),
            lbl.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])

        w.rootViewController = vc
        w.isHidden = false

        self.window = w
        self.label = lbl
    }
}

// MARK: - Utilities
extension Color {
    init(hex: UInt32) {
        let a = Double((hex >> 24) & 0xFF) / 255.0
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a == 0 ? 1 : a)
    }
}

extension String {
    var urlQueryEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
