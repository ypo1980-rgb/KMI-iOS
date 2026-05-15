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

    // MARK: Language
    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"

    var isEnglish: Bool {
        let values = [
            kmiAppLanguageCode.lowercased(),
            appLanguageRaw.lowercased(),
            initialLanguageCode.lowercased()
        ]

        return values.contains("en") || values.contains("english")
    }

    var settingsLayoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    var primaryTextAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    var horizontalTextAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    func applyInterfaceLanguage(_ english: Bool) {
        kmiAppLanguageCode = english ? "en" : "he"
        appLanguageRaw = english ? "ENGLISH" : "HEBREW"
        initialLanguageCode = english ? "ENGLISH" : "HEBREW"

        toast(english ? "Language changed to English" : "השפה שונתה לעברית")
        hapticSuccess()
    }

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
    @AppStorage("calendar_sync_selected_enabled") var selectedCalendarSyncEnabled: Bool = false
    @AppStorage("calendar_sync_selected_calendar_id") var selectedCalendarIdentifier: String = ""
    @AppStorage("calendar_sync_selected_calendar_display") var selectedCalendarDisplay: String = ""

    @AppStorage("click_sounds") var clickSounds: Bool = false
    @AppStorage("haptics_on") var hapticsOn: Bool = false

    @AppStorage("voice") var cloudVoice: String = "male" // male / female

    @AppStorage("theme_mode") var themeMode: String = "system" // system / light / dark

    @AppStorage("app_lock_mode") var appLockMode: String = "none" // none / biometric

    // Legacy only:
    // SettingsBusinessHelpers עדיין מכיל פונקציות ישנות של PIN.
    // אין במסך בחירת PIN, אבל המשתנה נשאר כדי שה-Extension יתקמפל.
    @AppStorage("app_lock_pin") var appLockPin: String = ""

    @AppStorage("coach_broadcast_recents_json") var coachBroadcastRecentsJson: String = ""
    
    // MARK: UI State
    @State var isBusy: Bool = false

    // Legacy only:
    // אין Sheet פעיל ל-PIN במסך, אבל SettingsBusinessHelpers עדיין קורא למשתנים האלה.
    @State var showPinDialog: Bool = false
    @State var pin: String = ""
    @State var pinConfirm: String = ""
    @State var pinError: String? = nil

    @State var mailData: MailData? = nil
    @State var showRegistrationEdit: Bool = false

    @State private var goLegal: Bool = false
    @State private var legalInitialTab: Int = 0

    @State private var showCalendarPicker: Bool = false
    @State private var availableWritableCalendars: [EKCalendar] = []
    @State private var tempSelectedCalendarIdentifier: String = ""

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
                        .padding(.top, 12)

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .overlay {
            if isBusy { LoadingOverlay() }
        }
        .environment(\.layoutDirection, settingsLayoutDirection)
        .preferredColorScheme(colorSchemeFromThemeMode(themeMode))
        .sheet(item: $mailData) { data in
            MailComposeView(data: data)
        }
        .sheet(isPresented: $showCalendarPicker) {
            calendarPickerSheet
                .presentationDetents([.medium, .large])
        }
        .navigationDestination(isPresented: $goLegal) {
            LegalView(initialTab: legalInitialTab)
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

            if selectedCalendarSyncEnabled {
                calendarSyncEnabled = true
            }

            if !selectedCalendarIdentifier.isEmpty && selectedCalendarDisplay.isEmpty {
                let store = EKEventStore()
                if let calendar = store.calendar(withIdentifier: selectedCalendarIdentifier) {
                    selectedCalendarDisplay = "\(calendar.title) (\(calendar.source.title))"
                }
            }
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
                        if isEnglish {
                            Text(tr("הגדרות", "Settings"))
                                .font(.system(size: 30, weight: .heavy))
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)

                            closeSettingsButton
                        } else {
                            closeSettingsButton

                            Text(tr("הגדרות", "Settings"))
                                .font(.system(size: 30, weight: .heavy))
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .frame(minHeight: 48)

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

    private var closeSettingsButton: some View {
        Button {
            hapticSuccess()
            nav.pop()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tr("סגור הגדרות", "Close settings"))
    }

    private var profileCard: some View {
        HStack(spacing: 8) {
            if isEnglish {
                profileIcon
                profileTextBlock
            } else {
                profileTextBlock
                profileIcon
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var profileIcon: some View {
        Image(systemName: isCoach ? "checkmark.seal.fill" : "person.fill")
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(isCoach ? Color(hex: 0xFF6A1B9A) : Color(hex: 0xFF1565C0))
            .frame(width: 28, height: 28)
    }

    private var profileTextBlock: some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 4) {
            Text(fullName.isEmpty || fullName == "שם מלא לא מוגדר" ? tr("משתמש", "User") : fullName)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Color.black.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                .multilineTextAlignment(primaryTextAlignment)

            if !phone.isEmpty {
                Text(phone)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                    .multilineTextAlignment(primaryTextAlignment)
            }

            Text(tr("דרגה: \(settingsRankDisplayName())", "Rank: \(settingsRankDisplayName())"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: 0xFF475569))
                .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                .multilineTextAlignment(primaryTextAlignment)
        }
        .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
    }

    private func settingsRankDisplayName() -> String {
        let value = currentBeltDisplayName()
            .replacingOccurrences(of: "חגורה", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if value.isEmpty {
            return isEnglish ? "Not set" : "לא הוגדרה"
        }

        return value
    }

    // MARK: Cards
    private var settingsCards: some View {
        VStack(spacing: 16) {

            SettingsCard(
                title: tr("שפה", "Language"),
                subtitle: tr("בחר שפת ממשק לאפליקציה", "Choose the app interface language"),
                iconSystemName: "globe",
                iconTint: sectionIconTint
            ) {
                VStack(spacing: 10) {
                    Text(tr("בחר שפת ממשק", "Choose interface language"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                        .multilineTextAlignment(primaryTextAlignment)

                    Picker(
                        "",
                        selection: Binding<Int>(
                            get: { isEnglish ? 1 : 0 },
                            set: { newValue in
                                applyInterfaceLanguage(newValue == 1)
                            }
                        )
                    ) {
                        if isEnglish {
                            Text("English").tag(1)
                            Text("עברית").tag(0)
                        } else {
                            Text("עברית").tag(0)
                            Text("English").tag(1)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            // --- Training reminders
            SettingsCard(
                title: tr("תזכורות אימון", "Training reminders"),
                subtitle: tr("קבל התראה לפני תחילת אימון", "Get a reminder before training starts"),
                iconSystemName: "alarm.fill",
                iconTint: sectionIconTint
            ) {
                VStack(spacing: 8) {
                    HStack {
                        Text(
                            trainingRemindersEnabled
                            ? tr("כמה דקות לפני האימון לקבל תזכורת?", "How many minutes before training would you like a reminder?")
                            : ""
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                        .multilineTextAlignment(primaryTextAlignment)

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
                            label: { minutes in
                                isEnglish ? "\(minutes) min\nbefore" : "\(minutes) דק׳\nלפני"
                            }
                        ) { minutes in
                            trainingReminderMinutes = minutes
                            scheduleTrainingReminders(minutes: minutes)
                            feedbackTap()
                        }
                    }
                }
            }

            SettingsCard(
                title: tr("תרגיל יומי", "Daily exercise"),
                subtitle: tr(
                    "קבל כל יום תרגיל מהחגורה הבאה בשעה שתבחר",
                    "Get a daily exercise from the next belt at the time you choose"
                ),
                iconSystemName: "bell.badge.fill",
                iconTint: sectionIconTint
            ) {
                VStack(spacing: 10) {
                    HStack {
                        Text(
                            isCoach
                            ? tr(
                                "המאמן יכול להפעיל או לכבות לעצמו את התרגיל היומי",
                                "The coach can enable or disable a daily exercise for themselves"
                            )
                            : tr(
                                "שלח לי כל יום תרגיל חדש מהחגורה הבאה",
                                "Send me a daily exercise from the next belt"
                            )
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                        .multilineTextAlignment(primaryTextAlignment)

                        Toggle("", isOn: dailyReminderEnabledBinding)
                            .labelsHidden()
                    }

                    if dailyReminderEnabledBinding.wrappedValue {
                        DatePicker(
                            tr("שעת התרגיל היומי", "Daily exercise time"),
                            selection: dailyReminderTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
                        .environment(\.locale, Locale(identifier: isEnglish ? "en_US" : "he_IL"))
                        .environment(\.layoutDirection, settingsLayoutDirection)
                        .datePickerStyle(.compact)

                        Text(
                            tr(
                                "ברירת מחדל: 20:00. בשבת ובחג לא תישלח התראה.",
                                "Default: 20:00. No reminder will be sent on Shabbat or holidays."
                            )
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                        .multilineTextAlignment(primaryTextAlignment)
                    }
                }
            }
            
            // --- Free sessions reminders
            SettingsCard(
                title: tr("תזכורות אימונים חופשיים", "Free training reminders"),
                subtitle: tr(
                    "קבל התראה לפני אימון חופשי שאישרת הגעה",
                    "Get a reminder before a free training session you confirmed"
                ),
                iconSystemName: "bell.badge.fill",
                iconTint: sectionIconTint
            ) {
                HStack {
                    Text(
                        tr(
                            "התראות 30 ו-10 דקות לפני אימון חופשי שסימנת \"אני מגיע\"",
                            "Notifications 30 and 10 minutes before a free training session marked as \"I'm coming\""
                        )
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                    .multilineTextAlignment(primaryTextAlignment)

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
                title: tr("סנכרון ליומן במכשיר", "Device calendar sync"),
                subtitle: tr(
                    "בחר יומן חיצוני לסנכרון האימונים",
                    "Choose an external/device calendar for training sync"
                ),
                iconSystemName: "calendar",
                iconTint: sectionIconTint
            ) {
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        Text(tr("סנכרן ליומן חיצוני", "Sync to external calendar"))
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                            .multilineTextAlignment(primaryTextAlignment)

                        Toggle("", isOn: Binding(
                            get: { selectedCalendarSyncEnabled },
                            set: { newValue in
                                if newValue {
                                    enableSelectedCalendarSync()
                                } else {
                                    isBusy = true

                                    selectedCalendarSyncEnabled = false
                                    calendarSyncEnabled = false

                                    UserDefaults.standard.set(false, forKey: "calendar_sync_selected_enabled")

                                    removeCalendarEvents()

                                    isBusy = false
                                    feedbackTap()
                                    toast(tr("הסנכרון ליומן שבחרת בוטל", "Selected calendar sync was disabled"))
                                }
                            }
                        ))
                        .labelsHidden()
                    }

                    Text(
                        selectedCalendarIdentifier.isEmpty || selectedCalendarDisplay.isEmpty
                        ? tr("עדיין לא נבחר יומן יעד", "No target calendar selected yet")
                        : tr("יומן שנבחר: \(selectedCalendarDisplay)", "Selected calendar: \(selectedCalendarDisplay)")
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                    .multilineTextAlignment(primaryTextAlignment)

                    Button {
                        openCalendarPicker()
                        feedbackTap()
                    } label: {
                        Text(tr("בחר יומן יעד", "Choose target calendar"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.bordered)

                    if selectedCalendarSyncEnabled {
                        Text(
                            tr(
                                "האימונים יסונכרנו ליומן שבחרת.",
                                "Trainings will sync to the selected calendar."
                            )
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                        .multilineTextAlignment(primaryTextAlignment)
                    }
                }
            }
            
            // --- UX
            SettingsCard(
                title: tr("חוויית משתמש", "User experience"),
                subtitle: tr(
                    "צלילים, רטט ושיפור חוויית האינטראקציה",
                    "Sounds, haptics, and improved interaction experience"
                ),
                iconSystemName: "slider.horizontal.3",
                iconTint: sectionIconTint
            ) {
                VStack(spacing: 10) {

                    toggleRow(
                        title: tr("צליל הקשה בכפתורים", "Button tap sound"),
                        isOn: $clickSounds
                    ) { enabled in
                        clickSounds = enabled

                        if enabled {
                            playClick()
                        }
                    }

                    toggleRow(
                        title: tr("רטט קצר בעת סימון ✓/✗", "Short haptic on ✓/✗ marking"),
                        isOn: $hapticsOn
                    ) { enabled in
                        hapticsOn = enabled

                        if enabled {
                            hapticLight()
                        }
                    }
                }
            }

            // --- Voice settings
            SettingsCard(
                title: tr("הגדרות קול", "Voice settings"),
                subtitle: tr(
                    "בחירת קול גבר/אישה (אחיד לכל האפליקציה)",
                    "Choose male/female voice for the entire app"
                ),
                iconSystemName: "person.wave.2.fill",
                iconTint: sectionIconTint
            ) {
                VStack(spacing: 10) {
                    Text(tr("בחר קול להשמעה:", "Choose voice playback:"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                        .multilineTextAlignment(primaryTextAlignment)

                    KmiVoiceTabs(
                        voice: Binding<String>(
                            get: { cloudVoice },
                            set: { newValue in
                                cloudVoice = newValue
                                UserDefaults.standard.set(newValue, forKey: "kmi_tts_voice")
                                feedbackTap()
                            }
                        )
                    ) {
                        feedbackTap()
                    }

                    Text(
                        tr(
                            "הבחירה נשמרת למכשיר ותשפיע על הדיבור בעוזר הקולי.",
                            "The selection is saved on the device and affects speech in the voice assistant."
                        )
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                    .multilineTextAlignment(primaryTextAlignment)
                }
            }

            // --- Appearance
            SettingsCard(
                title: tr("נראות אפליקציה", "App appearance"),
                subtitle: tr(
                    "ברירת המחדל היא מצב בהיר",
                    "Default is light mode"
                ),
                iconSystemName: "paintpalette.fill",
                iconTint: sectionIconTint
            ) {
                VStack(spacing: 10) {
                    Text(tr("בחר מצב תצוגה:", "Choose display mode:"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                        .multilineTextAlignment(primaryTextAlignment)

                    KmiThemeTabs(themeMode: $themeMode) {
                        feedbackTap()
                    }

                    Text(
                        tr(
                            "אפשר לבחור מצב בהיר, כהה או לפי הגדרת המכשיר.",
                            "You can choose light mode, dark mode, or follow the device setting."
                        )
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                    .multilineTextAlignment(primaryTextAlignment)
                }
            }

            // --- App lock
            SettingsCard(
                title: tr("נעילת אפליקציה", "App lock"),
                subtitle: tr(
                    "בחר שיטת נעילה להגנה על האפליקציה",
                    "Choose a lock method to protect the app"
                ),
                iconSystemName: "lock.fill",
                iconTint: sectionIconTint
            ) {
                VStack(spacing: 10) {
                    Picker(
                        "",
                        selection: Binding<String>(
                            get: {
                                appLockMode == "biometric" ? "biometric" : "none"
                            },
                            set: { mode in
                                switch mode {
                                case "none":
                                    appLockMode = "none"
                                    feedbackTap()
                                    toast(tr("נעילת האפליקציה בוטלה", "App lock disabled"))

                                case "biometric":
                                    appLockMode = "biometric"
                                    authenticateBiometricIfAvailable { ok in
                                        if !ok {
                                            appLockMode = "none"
                                        }
                                        feedbackTap()
                                    }

                                default:
                                    appLockMode = "none"
                                }
                            }
                        )
                    ) {
                        Text(tr("ללא\nנעילה", "No\nlock")).tag("none")
                        Text(tr("נעילה\nבאצבע", "Biometric\nlock")).tag("biometric")
                    }
                    .pickerStyle(.segmented)

                    if !biometricAvailable() {
                        Text(
                            tr(
                                "ביומטרי לא זמין במכשיר או לא הוגדר למשתמש.",
                                "Biometric authentication is not available or not configured for this user."
                            )
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                        .multilineTextAlignment(primaryTextAlignment)
                    }
                }
            }

            // --- Stats
            SettingsCard(
                title: tr("סטטיסטיקות", "Statistics"),
                subtitle: tr("התקדמות לפי חגורות ונושאים", "Progress by belts and topics"),
                iconSystemName: "chart.bar.fill",
                iconTint: sectionIconTint
            ) {
                VStack(spacing: 10) {

                    Text(
                        tr(
                            "דרגתי הנוכחית: חגורה \(settingsRankDisplayName())",
                            "My current rank: \(settingsRankDisplayName())"
                        )
                    )
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(currentBeltTextColor())
                    .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                    .multilineTextAlignment(primaryTextAlignment)

                    BeltsProgressBarsIOS(rows: beltProgressRowsFromDefaults())
                }
            }
     
            // --- Data management
            SettingsCard(
                title: tr("ניהול נתונים", "Data management"),
                subtitle: tr("ניקוי נתונים מקומיים במכשיר", "Clear local data on the device"),
                iconSystemName: "internaldrive.fill",
                iconTint: sectionIconTint
            ) {
                VStack(spacing: 10) {
                    Button {
                        coachBroadcastRecentsJson = ""
                        toast(tr("היסטוריית השידורים נוקתה", "Broadcast history was cleared"))
                        hapticSuccess()
                    } label: {
                        Text(tr("נקה היסטוריית שידורים", "Clear broadcast history"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        isBusy = true
                        let ok = clearAppCacheIOS()
                        isBusy = false
                        toast(ok ? tr("נוקו קבצי המטמון", "Cache files cleared") : tr("ניקוי נכשל", "Clear failed"))
                        ok ? hapticSuccess() : hapticError()
                    } label: {
                        Text(tr("נקה מטמון אפליקציה", "Clear app cache"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.bordered)
                }
            }

            // --- Legal
            SettingsCard(
                title: tr("מידע משפטי", "Legal information"),
                subtitle: tr("מסמכים רשמיים ומידע חשוב", "Official documents and important information"),
                iconSystemName: "scale.3d",
                iconTint: sectionIconTint
            ) {
                VStack(spacing: 12) {
                    LegalTile(
                        title: tr("מדיניות פרטיות", "Privacy policy"),
                        subtitle: tr("איך אנחנו שומרים על הנתונים שלך", "How we protect your data"),
                        systemIcon: "lock.fill"
                    ) {
                        legalInitialTab = 1
                        goLegal = true
                        feedbackTap()
                    }

                    LegalTile(
                        title: tr("תנאי שימוש", "Terms of use"),
                        subtitle: tr("כללי שימוש והתחייבויות המשתמש", "Usage rules and user responsibilities"),
                        systemIcon: "hammer.fill"
                    ) {
                        legalInitialTab = 0
                        goLegal = true
                        feedbackTap()
                    }

                    LegalTile(
                        title: tr("הצהרת נגישות", "Accessibility statement"),
                        subtitle: tr("מידע על התאמות ונגישות באפליקציה", "Information about accessibility and adaptations in the app"),
                        systemIcon: "figure.stand"
                    ) {
                        legalInitialTab = 2
                        goLegal = true
                        feedbackTap()
                    }
                }
            }

            // --- About & Support
            SettingsCard(
                title: tr("אודות ותמיכה", "About and support"),
                subtitle: tr("ספרו לנו איך אפשר לשפר", "Tell us how we can improve"),
                iconSystemName: "headphones.circle.fill",
                iconTint: sectionIconTint
            ) {
                VStack(spacing: 10) {
                    Text(appVersionLine())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                        .multilineTextAlignment(primaryTextAlignment)

                    HStack(spacing: 10) {
                        Button {
                            sendFeedbackEmailWithSystemDetails()
                            hapticSuccess()
                        } label: {
                            Text(tr("שלח משוב", "Send feedback"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            requestReview()
                            hapticSuccess()
                        } label: {
                            Text(tr("דרג בחנות", "Rate in store"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        shareApp()
                        hapticSuccess()
                    } label: {
                        Text(tr("שתף את האפליקציה", "Share the app"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func sendFeedbackEmailWithSystemDetails() {
        let bundleId = Bundle.main.bundleIdentifier ?? "-"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        let device = UIDevice.current.model
        let systemVersion = UIDevice.current.systemVersion

        let body = """



        ---
        \(tr("פרטי מערכת (לעזרה באיתור תקלות):", "System details (for troubleshooting):"))
        \(tr("חבילה:", "Package:")) \(bundleId)
        \(tr("גרסה:", "Version:")) \(version) (\(build))
        \(tr("מכשיר:", "Device:")) \(device)
        iOS: \(systemVersion)
        """

        mailData = MailData(
            to: "support@kmi.example",
            subject: tr("משוב על האפליקציה", "App feedback"),
            body: body
        )
    }
    
    // MARK: Calendar picker

    private var calendarPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if availableWritableCalendars.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text(tr("לא נמצאו יומנים זמינים לכתיבה במכשיר.", "No writable calendars were found on this device."))
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(availableWritableCalendars, id: \.calendarIdentifier) { calendar in
                                calendarPickerRow(calendar)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle(tr("בחר יומן לסנכרון", "Choose calendar for sync"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: isEnglish ? .topBarLeading : .topBarTrailing) {
                    Button(tr("ביטול", "Cancel")) {
                        showCalendarPicker = false
                    }
                }

                ToolbarItem(placement: isEnglish ? .topBarTrailing : .topBarLeading) {
                    Button(tr("שמור", "Save")) {
                        saveSelectedCalendarFromPicker()
                    }
                    .disabled(tempSelectedCalendarIdentifier.isEmpty)
                }
            }
            .environment(\.layoutDirection, settingsLayoutDirection)
        }
    }

    private func calendarPickerRow(_ calendar: EKCalendar) -> some View {
        Button {
            tempSelectedCalendarIdentifier = calendar.calendarIdentifier
            feedbackTap()
        } label: {
            HStack(spacing: 12) {
                if isEnglish {
                    calendarPickerCheckmark(calendar)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(calendar.title.isEmpty ? tr("יומן ללא שם", "Unnamed calendar") : calendar.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(calendar.source.title)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                } else {
                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(calendar.title.isEmpty ? tr("יומן ללא שם", "Unnamed calendar") : calendar.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(calendar.source.title)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    calendarPickerCheckmark(calendar)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func calendarPickerCheckmark(_ calendar: EKCalendar) -> some View {
        Image(systemName: tempSelectedCalendarIdentifier == calendar.calendarIdentifier ? "largecircle.fill.circle" : "circle")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(tempSelectedCalendarIdentifier == calendar.calendarIdentifier ? Color.accentColor : Color.secondary)
    }
    
    private func openCalendarPicker() {
        requestCalendarAccessIfNeeded { granted in
            DispatchQueue.main.async {
                guard granted else {
                    toast(tr("אין הרשאה ליומן – לא בוצע סנכרון", "No calendar permission - sync was not performed"))
                    selectedCalendarSyncEnabled = false
                    calendarSyncEnabled = false
                    return
                }

                let store = EKEventStore()
                availableWritableCalendars = store
                    .calendars(for: .event)
                    .filter { $0.allowsContentModifications }

                tempSelectedCalendarIdentifier =
                    selectedCalendarIdentifier.isEmpty
                    ? (availableWritableCalendars.first?.calendarIdentifier ?? "")
                    : selectedCalendarIdentifier

                showCalendarPicker = true
            }
        }
    }

    private func saveSelectedCalendarFromPicker() {
        guard let selected = availableWritableCalendars.first(where: {
            $0.calendarIdentifier == tempSelectedCalendarIdentifier
        }) else {
            toast(tr("יש לבחור יומן תקין", "Please choose a valid calendar"))
            return
        }

        selectedCalendarIdentifier = selected.calendarIdentifier
        selectedCalendarDisplay = "\(selected.title) (\(selected.source.title))"

        showCalendarPicker = false
        feedbackTap()

        if selectedCalendarSyncEnabled {
            enableSelectedCalendarSync()
        } else {
            toast(tr("היומן נשמר. אפשר להפעיל סנכרון.", "Calendar saved. You can now enable sync."))
        }
    }

    private func enableSelectedCalendarSync() {
        requestCalendarAccessIfNeeded { granted in
            DispatchQueue.main.async {
                guard granted else {
                    selectedCalendarSyncEnabled = false
                    calendarSyncEnabled = false
                    toast(tr("אין הרשאה ליומן – לא בוצע סנכרון", "No calendar permission - sync was not performed"))
                    hapticError()
                    return
                }

                guard !selectedCalendarIdentifier.isEmpty else {
                    selectedCalendarSyncEnabled = false
                    calendarSyncEnabled = false
                    openCalendarPicker()
                    toast(tr("יש לבחור יומן לפני הפעלת הסנכרון", "Please choose a calendar before enabling sync"))
                    hapticError()
                    return
                }

                isBusy = true

                // שומרים את היומן הנבחר גם במפתחות גלובליים,
                // כדי שפונקציות הסנכרון הקיימות יוכלו לקרוא אותו אם הן כבר תומכות בזה.
                UserDefaults.standard.set(selectedCalendarIdentifier, forKey: "calendar_sync_selected_calendar_id")
                UserDefaults.standard.set(selectedCalendarDisplay, forKey: "calendar_sync_selected_calendar_display")
                UserDefaults.standard.set(true, forKey: "calendar_sync_selected_enabled")

                selectedCalendarSyncEnabled = true
                calendarSyncEnabled = true

                ensureCalendarPermissionsAndSync()

                isBusy = false
                feedbackTap()
                toast(tr("האימונים סונכרנו ליומן שבחרת", "Trainings were synced to the selected calendar"))
            }
        }
    }

    private func requestCalendarAccessIfNeeded(_ completion: @escaping (Bool) -> Void) {
        let store = EKEventStore()

        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized:
            completion(true)

        case .notDetermined:
            if #available(iOS 17.0, *) {
                store.requestFullAccessToEvents { granted, _ in
                    completion(granted)
                }
            } else {
                store.requestAccess(to: .event) { granted, _ in
                    completion(granted)
                }
            }

        case .denied, .restricted:
            completion(false)

        case .fullAccess:
            completion(true)

        case .writeOnly:
            completion(true)

        @unknown default:
            completion(false)
        }
    }
    
    // MARK: Action buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {
            if isEnglish {
                cancelSettingsButton
                okSettingsButton
            } else {
                okSettingsButton
                cancelSettingsButton
            }
        }
    }

    private var cancelSettingsButton: some View {
        Button {
            // ✅ מסך גלובאלי: חוזרים אחורה בנתיב
            nav.pop()
        } label: {
            Text(tr("ביטול", "Cancel"))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(.bordered)
    }

    private var okSettingsButton: some View {
        Button {
            // ✅ ההעדפות נשמרות inline; פשוט חוזרים
            nav.pop()
        } label: {
            Text(tr("אישור", "Confirm"))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(.borderedProminent)
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
