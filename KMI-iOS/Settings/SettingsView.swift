import SwiftUI
import UserNotifications
import EventKit
import LocalAuthentication
import StoreKit
import MessageUI
import UIKit
import AudioToolbox
import Shared

// MARK: - SettingsContentView (Content-only; NO local top bar / icon strip)
struct SettingsView: View {

    // ✅ Global nav (מגיע מהמסך הגלובאלי)
    @ObservedObject var nav: AppNavModel
    var onOpenRegistration: (() -> Void)? = nil

    // MARK: Stored settings (UserDefaults)
    @AppStorage("fullName") var fullName: String = "שם מלא לא מוגדר"
    @AppStorage("phone") var phone: String = ""
    @AppStorage("email") var email: String = ""
    @AppStorage("region") var region: String = ""
    @AppStorage("branch") var branch: String = ""
    @AppStorage("group") var group: String = ""

    @AppStorage("current_belt") var currentBeltId: String = ""
    @AppStorage("belt_current") var currentBeltIdUser: String = ""
    
    @AppStorage("user_role") var userRole: String = "trainee" // "coach" / "trainee"
    @AppStorage("coach_code") var coachCode: String = ""

    // Training reminders
    @AppStorage("training_reminders_enabled") var trainingRemindersEnabled: Bool = true
    @AppStorage("training_reminder_minutes") var trainingReminderMinutes: Int = 60
    @AppStorage("daily_exercise_reminder_enabled_trainee") var dailyReminderEnabledTrainee: Bool = false
    @AppStorage("daily_exercise_reminder_enabled_coach") var dailyReminderEnabledCoach: Bool = false
    @AppStorage("daily_exercise_reminder_hour") var dailyReminderHour: Int = 20
    @AppStorage("daily_exercise_reminder_minute") var dailyReminderMinute: Int = 0

    @AppStorage("free_sessions_reminders_enabled") var freeSessionsRemindersEnabled: Bool = false
    @AppStorage("calendar_sync_enabled") var calendarSyncEnabled: Bool = false

    @AppStorage("click_sounds") var clickSounds: Bool = false
    @AppStorage("haptics_on") var hapticsOn: Bool = false

    @AppStorage("voice") var cloudVoice: String = "male" // male / female

    @AppStorage("theme_mode") var themeMode: String = "light" // light / dark

    @AppStorage("app_lock_mode") var appLockMode: String = "none" // none/biometric/pin
    @AppStorage("app_lock_pin") var appLockPin: String = ""       // WARNING: store securely later

    @AppStorage("coach_broadcast_recents_json") var coachBroadcastRecentsJson: String = ""
    
    // MARK: UI State
    @State var isBusy: Bool = false
    @State var showPinDialog: Bool = false
    @State var pin: String = ""
    @State var pinConfirm: String = ""
    @State var pinError: String? = nil

    @State var mailData: MailData? = nil
    @State var showRegistrationEdit: Bool = false

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

    private var dailyReminderEnabledBinding: Binding<Bool> {
        Binding(
            get: { isCoach ? dailyReminderEnabledCoach : dailyReminderEnabledTrainee },
            set: { newValue in
                if isCoach {
                    dailyReminderEnabledCoach = newValue
                } else {
                    dailyReminderEnabledTrainee = newValue
                }

                if newValue {
                    DailyReminderScheduler.shared.requestPermissionIfNeeded { granted in
                        if granted {
                            DailyReminderScheduler.shared.refreshSchedule()
                        } else {
                            DispatchQueue.main.async {
                                if isCoach {
                                    dailyReminderEnabledCoach = false
                                } else {
                                    dailyReminderEnabledTrainee = false
                                }
                            }
                        }
                    }
                } else {
                    DailyReminderScheduler.shared.cancelAll()
                }
            }
        )
    }

    private var dailyReminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                var cal = Calendar.current
                cal.timeZone = TimeZone(identifier: "Asia/Jerusalem")!
                return cal.date(from: DateComponents(
                    hour: dailyReminderHour,
                    minute: dailyReminderMinute
                )) ?? Date()
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                dailyReminderHour = comps.hour ?? 20
                dailyReminderMinute = comps.minute ?? 0
                if dailyReminderEnabledBinding.wrappedValue {
                    DailyReminderScheduler.shared.refreshSchedule()
                }
            }
        )
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
        .fullScreenCover(isPresented: $showRegistrationEdit) {
            RegisterFormView(
                prefillPhone: phone,
                prefillEmail: email,
                initialRole: userRole == "coach" ? .coach : .trainee,
                onBack: {
                    print("⚙️ RegisterFormView: onBack tapped")
                    showRegistrationEdit = false
                    print("⚙️ RegisterFormView: showRegistrationEdit =", showRegistrationEdit)
                },
                onSubmit: { form in
                    print("⚙️ [1] onSubmit start")

                    let submittedFullName = "\(form.fullName)"
                    let submittedPhone = "\(form.phone)"
                    let submittedEmail = "\(form.email)"
                    let submittedRegion = "\(form.region)"
                    let submittedBelt = "\(form.belt)"
                    let submittedRoleIsCoach = (form.role == .coach)
                    let submittedBranches = Array(form.branches)
                    let submittedGroups = Array(form.groups)
                    let submittedUsername = "\(form.username)"
                    let submittedBirthDay = "\(form.birthDay)"
                    let submittedBirthMonth = "\(form.birthMonth)"
                    let submittedBirthYear = "\(form.birthYear)"
                    let submittedGender = "\(form.gender)"
                    let submittedPassword = "\(form.password)"
                    let submittedWantsSms = form.wantsSms
                    let submittedAcceptsTerms = form.acceptsTerms
                    let submittedCoachCode = "\(form.coachCode)"

                    saveRegistrationSnapshot(
                        fullName: submittedFullName,
                        phone: submittedPhone,
                        email: submittedEmail,
                        region: submittedRegion,
                        belt: submittedBelt,
                        isCoach: submittedRoleIsCoach,
                        branches: submittedBranches,
                        groups: submittedGroups,
                        username: submittedUsername,
                        birthDay: submittedBirthDay,
                        birthMonth: submittedBirthMonth,
                        birthYear: submittedBirthYear,
                        gender: submittedGender,
                        password: submittedPassword,
                        wantsSms: submittedWantsSms,
                        acceptsTerms: submittedAcceptsTerms,
                        coachCode: submittedCoachCode
                    )

                    print("⚙️ RegisterFormView: about to close cover")
                    DispatchQueue.main.async {
                        loadBranchAndGroupFromDefaults()
                        showRegistrationEdit = false
                    }
                    print("⚙️ RegisterFormView: showRegistrationEdit =", showRegistrationEdit)
                }
            )
        }
        .onAppear {
            loadBranchAndGroupFromDefaults()
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
                            print("⚙️ SettingsView: tap edit registration")
                            hapticSuccess()
                            if let onOpenRegistration {
                                print("⚙️ SettingsView: using external onOpenRegistration")
                                onOpenRegistration()
                            } else {
                                print("⚙️ SettingsView: opening local RegisterFormView")
                                showRegistrationEdit = true
                            }
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
                            .font(.system(size: 30, weight: .heavy))
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
        HStack(spacing: 8) {
            Image(systemName: isCoach ? "checkmark.seal.fill" : "person.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(isCoach ? Color(hex: 0xFF6A1B9A) : Color(hex: 0xFF1565C0))
                .frame(width: 28, height: 28)

            VStack(alignment: .trailing, spacing: 4) {
                Text(fullName.isEmpty ? "משתמש" : fullName)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .trailing)

                if !phone.isEmpty {
                    Text(phone)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.72))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Cards
    private var settingsCards: some View {
        VStack(spacing: 16) {

            if isCoach {
                SettingsCard(
                    title: "קוד מאמן",
                    subtitle: "הקוד האישי שלך לצירוף מתאמנים",
                    iconSystemName: "number.square.fill",
                    iconTint: sectionIconTint
                ) {
                    VStack(spacing: 10) {
                        Text(coachCode.isEmpty ? "לא נמצא קוד מאמן" : coachCode)
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)

                        Button {
                            guard !coachCode.isEmpty else { return }
                            UIPasteboard.general.string = coachCode
                            toast("קוד המאמן הועתק")
                            hapticSuccess()
                        } label: {
                            Text("העתק קוד מאמן")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(coachCode.isEmpty)
                    }
                }
            }

            // --- Training reminders
            SettingsCard(
                title: "תזכורות אימון",
                subtitle: "קבל התראה לפני תחילת אימון",
                iconSystemName: "alarm.fill",
                iconTint: sectionIconTint
            ) {
                VStack(spacing: 8) {
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

            SettingsCard(
                title: "תרגיל יומי",
                subtitle: "קבל כל יום תרגיל מהחגורה הבאה בשעה שתבחר",
                iconSystemName: "bell.badge.fill",
                iconTint: sectionIconTint
            ) {
                VStack(spacing: 10) {
                    HStack {
                        Text(
                            isCoach
                            ? "המאמן יכול להפעיל או לכבות לעצמו את התרגיל היומי"
                            : "שלח לי כל יום תרגיל חדש מהחגורה הבאה"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                        Toggle("", isOn: dailyReminderEnabledBinding)
                            .labelsHidden()
                    }

                    if dailyReminderEnabledBinding.wrappedValue {
                        DatePicker(
                            "שעת התרגיל היומי",
                            selection: dailyReminderTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
                        .environment(\.locale, Locale(identifier: "he_IL"))
                        .datePickerStyle(.compact)

                        Text("ברירת מחדל: 20:00. בשבת ובחג לא תישלח התראה.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
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
                                if newValue {
                                    calendarSyncEnabled = true
                                    ensureCalendarPermissionsAndSync()
                                } else {
                                    removeCalendarEvents()
                                    calendarSyncEnabled = false
                                }

                                if hapticsOn {
                                    hapticLight()
                                }
                            }
                        ))
                        .labelsHidden()
                    }

                    Text(calendarSyncEnabled ? "הסנכרון ליומן פעיל" : "הסנכרון ליומן כבוי")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            // --- UX
            SettingsCard(
                title: "חוויית משתמש",
                subtitle: "צלילים ורטט בפעולות באפליקציה",
                iconSystemName: "slider.horizontal.3",
                iconTint: sectionIconTint
            ) {
                VStack(spacing: 10) {

                    toggleRow(title: "צליל הקשה בכפתורים", isOn: $clickSounds) { enabled in
                        clickSounds = enabled

                        if enabled {
                            playClick()
                            toast("צליל הקשה הופעל")
                        } else {
                            toast("צליל הקשה כובה")
                        }
                    }

                    toggleRow(title: "רטט קצר בעת סימון ✓/✗", isOn: $hapticsOn) { enabled in
                        hapticsOn = enabled

                        if enabled {
                            hapticLight()
                            toast("רטט הופעל")
                        } else {
                            toast("רטט כובה")
                        }
                    }

                    HStack(spacing: 10) {

                        Button {
                            playClick()
                            toast("בדיקת צליל")
                        } label: {
                            Text("בדוק צליל")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            hapticLight()
                            toast("בדיקת רטט")
                        } label: {
                            Text("בדוק רטט")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)

                    }
                }
            }

            // --- Voice settings
            SettingsCard(
                title: "הגדרות קול",
                subtitle: "בחירת קול גבר/אישה (אחיד לכל האפליקציה)",
                iconSystemName: "person.wave.2.fill",
                iconTint: sectionIconTint
            ) {
                VStack(spacing: 10) {
                    Text("בחר קול להשמעה:")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    KmiVoiceTabs(voice: $cloudVoice) {
                        feedbackTap()
                    }

                    Text("הבחירה נשמרת למכשיר ותשפיע על הדיבור בעוזר הקולי.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
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

                    Text("הטקסט והצבעים יתאימו אוטומטית למצב שבחרת (לדוגמה: טקסט לבן על רקע כהה).")
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

                    Text("דרגתי הנוכחית: חגורה \(currentBeltDisplayName())")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(currentBeltTextColor())
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    BeltsProgressBarsIOS(rows: beltProgressRowsFromDefaults())

                    Button {
                        nav.push(.progress)
                        feedbackTap()
                    } label: {
                        Text("פתח מסך התקדמות מלא")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        nav.push(.trainingHistory)
                        feedbackTap()
                    } label: {
                        Text("היסטוריית אימונים")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
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
                iconSystemName: "doc.text.fill",
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
                iconSystemName: "person.crop.circle.badge.questionmark",
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

    // MARK: - Fix branch/group loading
    private func loadBranchAndGroupFromDefaults() {
        let defaults = UserDefaults.standard

        let fallbackBranchFromArray = defaults.stringArray(forKey: "branches")?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""

        let fallbackGroupFromArray = defaults.stringArray(forKey: "groups")?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""

        let resolvedBranch = (
            defaults.string(forKey: "active_branch") ??
            defaults.string(forKey: "branch") ??
            defaults.string(forKey: "kmi.user.branch") ??
            fallbackBranchFromArray
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedGroup = (
            defaults.string(forKey: "active_group") ??
            defaults.string(forKey: "group") ??
            defaults.string(forKey: "kmi.user.group") ??
            fallbackGroupFromArray
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        branch = resolvedBranch
        group = resolvedGroup

        print("⚙️ SettingsView loaded branch =", branch)
        print("⚙️ SettingsView loaded group =", group)
        print("⚙️ SettingsView loaded branches array =", defaults.stringArray(forKey: "branches") ?? [])
        print("⚙️ SettingsView loaded groups array =", defaults.stringArray(forKey: "groups") ?? [])
    }
}
