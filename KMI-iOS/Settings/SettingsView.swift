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
    @AppStorage("selected_language_code") private var selectedLanguageCode: String = "he"

    var isEnglish: Bool {
        let values = [
            kmiAppLanguageCode.lowercased(),
            selectedLanguageCode.lowercased(),
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
        selectedLanguageCode = english ? "en" : "he"
        appLanguageRaw = english ? "ENGLISH" : "HEBREW"
        initialLanguageCode = english ? "ENGLISH" : "HEBREW"

        UserDefaults.standard.set(english ? "en" : "he", forKey: "kmi_app_language")
        UserDefaults.standard.set(english ? "en" : "he", forKey: "selected_language_code")
        UserDefaults.standard.set(english ? "ENGLISH" : "HEBREW", forKey: "app_language")
        UserDefaults.standard.set(english ? "ENGLISH" : "HEBREW", forKey: "initial_language_code")

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

    @State private var showClearBroadcastHistoryConfirm: Bool = false
    @State private var showClearCacheConfirm: Bool = false

    private var isCoach: Bool { userRole == "coach" }

    private enum LegalTab: Int, Identifiable {
        case terms = 0
        case privacy = 1
        case accessibility = 2
        var id: Int { rawValue }
    }

    private var supportEmailAddress: String {
        "ypo1980@gmail.com"
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

                UserDefaults.standard.set(dailyReminderHour, forKey: "daily_exercise_reminder_hour")
                UserDefaults.standard.set(dailyReminderMinute, forKey: "daily_exercise_reminder_minute")

                if dailyReminderEnabledBinding.wrappedValue {
                    DailyReminderScheduler.shared.refreshSchedule()
                }

                toast(
                    tr(
                        "שעת התרגיל היומי עודכנה ל-\(String(format: "%02d:%02d", dailyReminderHour, dailyReminderMinute))",
                        "Daily exercise time updated to \(String(format: "%02d:%02d", dailyReminderHour, dailyReminderMinute))"
                    )
                )
                feedbackTap()
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
                        .padding(.bottom, 4)

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
        .confirmationDialog(
            tr("לנקות היסטוריית שידורים?", "Clear broadcast history?"),
            isPresented: $showClearBroadcastHistoryConfirm,
            titleVisibility: .visible
        ) {
            Button(
                tr("נקה היסטוריית שידורים", "Clear broadcast history"),
                role: .destructive
            ) {
                coachBroadcastRecentsJson = ""
                UserDefaults.standard.removeObject(forKey: "coach_broadcast_recents_json")
                toast(tr("היסטוריית השידורים נוקתה", "Broadcast history was cleared"))
                hapticSuccess()
            }

            Button(tr("ביטול", "Cancel"), role: .cancel) { }
        } message: {
            Text(
                tr(
                    "הפעולה תמחק רק את רשימת השידורים האחרונים מהמכשיר.",
                    "This will only clear the recent broadcast list from this device."
                )
            )
        }
        .confirmationDialog(
            tr("לנקות מטמון אפליקציה?", "Clear app cache?"),
            isPresented: $showClearCacheConfirm,
            titleVisibility: .visible
        ) {
            Button(
                tr("נקה מטמון", "Clear cache"),
                role: .destructive
            ) {
                isBusy = true
                let ok = clearAppCacheIOS()
                isBusy = false

                toast(
                    ok
                    ? tr("נוקו קבצי המטמון", "Cache files cleared")
                    : tr("ניקוי נכשל", "Clear failed")
                )

                ok ? hapticSuccess() : hapticError()
            }

            Button(tr("ביטול", "Cancel"), role: .cancel) { }
        } message: {
            Text(
                tr(
                    "הפעולה לא מוחקת חשבון, הרשמה, מנוי או נתוני משתמש.",
                    "This does not delete the account, registration, subscription, or user data."
                )
            )
        }
        .fullScreenCover(isPresented: $showRegistrationEdit) {
            RegisterFormView(
                prefillPhone: phone,
                prefillEmail: email,
                initialRole: userRole == "coach" ? .coach : .trainee,
                onBack: {
                    showRegistrationEdit = false
                },
                onSubmit: { form in
                    saveRegistrationSnapshot(
                        fullName: "\(form.fullName)",
                        phone: "\(form.phone)",
                        email: "\(form.email)",
                        region: "\(form.region)",
                        belt: "\(form.belt)",
                        isCoach: form.role == .coach,
                        branches: Array(form.branches),
                        groups: Array(form.groups),
                        username: "\(form.username)",
                        birthDay: "\(form.birthDay)",
                        birthMonth: "\(form.birthMonth)",
                        birthYear: "\(form.birthYear)",
                        gender: "\(form.gender)",
                        password: "\(form.password)",
                        wantsSms: form.wantsSms,
                        acceptsTerms: form.acceptsTerms,
                        coachCode: "\(form.coachCode)"
                    )

                    DispatchQueue.main.async {
                        loadBranchAndGroupFromDefaults()
                        showRegistrationEdit = false
                        toast(tr("הפרטים עודכנו בהצלחה", "Details updated successfully"))
                        hapticSuccess()
                    }
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
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                if isEnglish {
                    profileIcon
                    profileTextBlock
                } else {
                    profileTextBlock
                    profileIcon
                }
            }

            HStack(spacing: 8) {
                if isEnglish {
                    SettingsHeaderChip(
                        title: settingsRoleDisplayName(),
                        systemImage: settingsRoleIconName(),
                        tint: isCoach ? Color(hex: 0xFF6A1B9A) : Color(hex: 0xFF1565C0),
                        isEnglish: isEnglish
                    )

                    SettingsHeaderChip(
                        title: tr("חגורה \(settingsRankDisplayName())", "Rank \(settingsRankDisplayName())"),
                        systemImage: "rosette",
                        tint: currentBeltTextColor(),
                        isEnglish: isEnglish
                    )

                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 0)

                    SettingsHeaderChip(
                        title: tr("חגורה \(settingsRankDisplayName())", "Rank \(settingsRankDisplayName())"),
                        systemImage: "rosette",
                        tint: currentBeltTextColor(),
                        isEnglish: isEnglish
                    )

                    SettingsHeaderChip(
                        title: settingsRoleDisplayName(),
                        systemImage: settingsRoleIconName(),
                        tint: isCoach ? Color(hex: 0xFF6A1B9A) : Color(hex: 0xFF1565C0),
                        isEnglish: isEnglish
                    )
                }
            }
            .environment(\.layoutDirection, .leftToRight)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Color.white.opacity(0.94))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.36), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
    }

    private var profileIcon: some View {
        ZStack {
            Circle()
                .fill((isCoach ? Color(hex: 0xFF6A1B9A) : Color(hex: 0xFF1565C0)).opacity(0.12))
                .frame(width: 46, height: 46)

            Image(systemName: isCoach ? "checkmark.seal.fill" : "person.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(isCoach ? Color(hex: 0xFF6A1B9A) : Color(hex: 0xFF1565C0))
        }
        .frame(width: 48, height: 48)
    }

    private var profileTextBlock: some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 5) {
            Text(settingsProfileName())
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Color.black.opacity(0.88))
                .lineLimit(2)
                .minimumScaleFactor(0.76)
                .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                .multilineTextAlignment(primaryTextAlignment)

            if !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(phone)
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.68))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                    .multilineTextAlignment(primaryTextAlignment)
            }

            if !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(email)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.54))
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
                    .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                    .multilineTextAlignment(primaryTextAlignment)
            }

            if !settingsBranchGroupLine().isEmpty {
                Text(settingsBranchGroupLine())
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: 0xFF64748B))
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
                    .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                    .multilineTextAlignment(primaryTextAlignment)
            }
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

    private func settingsBranchGroupLine() -> String {
        let cleanBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanGroup = group.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanBranch.isEmpty && cleanGroup.isEmpty {
            return ""
        }

        if cleanBranch.isEmpty {
            return tr("קבוצה: \(cleanGroup)", "Group: \(cleanGroup)")
        }

        if cleanGroup.isEmpty {
            return tr("סניף: \(cleanBranch)", "Branch: \(cleanBranch)")
        }

        return tr("סניף: \(cleanBranch) · קבוצה: \(cleanGroup)", "Branch: \(cleanBranch) · Group: \(cleanGroup)")
    }

    private func settingsRoleDisplayName() -> String {
        isCoach ? tr("מאמן", "Coach") : tr("מתאמן", "Trainee")
    }

    private func settingsRoleIconName() -> String {
        isCoach ? "checkmark.seal.fill" : "figure.martial.arts"
    }

    private func settingsProfileName() -> String {
        let clean = fullName.trimmingCharacters(in: .whitespacesAndNewlines)

        if clean.isEmpty || clean == "שם מלא לא מוגדר" {
            return tr("משתמש", "User")
        }

        return clean
    }

    // MARK: Theme helpers
    
    private func themeDisplayName() -> String {
        themeDisplayName(for: themeMode)
    }

    private func themeDisplayName(for value: String) -> String {
        switch value {
        case "light":
            return tr("בהיר", "Light")
        case "dark":
            return tr("כהה", "Dark")
        case "system":
            return tr("לפי המכשיר", "System")
        default:
            return tr("לפי המכשיר", "System")
        }
    }

    private func themeStatusIconName() -> String {
        switch themeMode {
        case "light":
            return "sun.max.fill"
        case "dark":
            return "moon.fill"
        case "system":
            return "iphone"
        default:
            return "iphone"
        }
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
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 6) {
                            Text(
                                trainingRemindersEnabled
                                ? tr("התזכורות פעילות", "Reminders are active")
                                : tr("התזכורות כבויות", "Reminders are off")
                            )
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(Color(hex: 0xFF111827))
                            .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                            .multilineTextAlignment(primaryTextAlignment)

                            Text(
                                trainingRemindersEnabled
                                ? tr("תקבל תזכורת \(trainingReminderMinutes) דקות לפני תחילת אימון.", "You will get a reminder \(trainingReminderMinutes) minutes before training starts.")
                                : tr("הפעל כדי לקבל התראה לפני אימונים קבועים.", "Enable this to get notifications before scheduled trainings.")
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                            .multilineTextAlignment(primaryTextAlignment)
                        }

                        Toggle("", isOn: Binding(
                            get: { trainingRemindersEnabled },
                            set: { newValue in
                                trainingRemindersEnabled = newValue

                                if newValue {
                                    requestNotificationPermissionIfNeeded {
                                        scheduleTrainingReminders(minutes: trainingReminderMinutes)
                                    }

                                    toast(
                                        tr(
                                            "תזכורות אימון הופעלו",
                                            "Training reminders enabled"
                                        )
                                    )
                                } else {
                                    cancelTrainingReminders()
                                    toast(
                                        tr(
                                            "תזכורות אימון בוטלו",
                                            "Training reminders disabled"
                                        )
                                    )
                                }

                                feedbackTap()
                            }
                        ))
                        .labelsHidden()
                    }

                    HStack(spacing: 8) {
                        SettingsStatusPill(
                            title: trainingRemindersEnabled ? tr("פעיל", "Active") : tr("כבוי", "Off"),
                            systemImage: trainingRemindersEnabled ? "bell.fill" : "bell.slash.fill",
                            tint: trainingRemindersEnabled ? Color.green.opacity(0.82) : Color.gray.opacity(0.82),
                            isEnglish: isEnglish
                        )

                        SettingsStatusPill(
                            title: tr("\(trainingReminderMinutes) דק׳ לפני", "\(trainingReminderMinutes) min before"),
                            systemImage: "clock.fill",
                            tint: sectionIconTint,
                            isEnglish: isEnglish
                        )

                        Spacer(minLength: 0)
                    }
                    .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)

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
                            toast(
                                tr(
                                    "התזכורת עודכנה ל-\(minutes) דקות לפני האימון",
                                    "Reminder updated to \(minutes) minutes before training"
                                )
                            )
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
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 6) {
                            Text(
                                dailyReminderEnabledBinding.wrappedValue
                                ? tr("תרגיל יומי פעיל", "Daily exercise is active")
                                : tr("תרגיל יומי כבוי", "Daily exercise is off")
                            )
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(Color(hex: 0xFF111827))
                            .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                            .multilineTextAlignment(primaryTextAlignment)

                            Text(
                                isCoach
                                ? tr(
                                    "המאמן יכול להפעיל תזכורת יומית לעצמו.",
                                    "The coach can enable a daily reminder for themselves."
                                )
                                : tr(
                                    "תקבל בכל יום תרגיל מהחגורה הבאה שלך.",
                                    "You will receive a daily exercise from your next belt."
                                )
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                            .multilineTextAlignment(primaryTextAlignment)
                        }

                        Toggle("", isOn: Binding(
                            get: { dailyReminderEnabledBinding.wrappedValue },
                            set: { newValue in
                                dailyReminderEnabledBinding.wrappedValue = newValue

                                toast(
                                    newValue
                                    ? tr("התרגיל היומי הופעל", "Daily exercise enabled")
                                    : tr("התרגיל היומי בוטל", "Daily exercise disabled")
                                )

                                feedbackTap()
                            }
                        ))
                        .labelsHidden()
                    }

                    HStack(spacing: 8) {
                        SettingsStatusPill(
                            title: dailyReminderEnabledBinding.wrappedValue ? tr("פעיל", "Active") : tr("כבוי", "Off"),
                            systemImage: dailyReminderEnabledBinding.wrappedValue ? "bell.badge.fill" : "bell.slash.fill",
                            tint: dailyReminderEnabledBinding.wrappedValue ? Color.green.opacity(0.82) : Color.gray.opacity(0.82),
                            isEnglish: isEnglish
                        )

                        SettingsStatusPill(
                            title: String(format: "%02d:%02d", dailyReminderHour, dailyReminderMinute),
                            systemImage: "clock.fill",
                            tint: sectionIconTint,
                            isEnglish: isEnglish
                        )

                        Spacer(minLength: 0)
                    }
                    .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)

                    if dailyReminderEnabledBinding.wrappedValue {
                        DatePicker(
                            tr("שעת התרגיל היומי", "Daily exercise time"),
                            selection: dailyReminderTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
                        .environment(\.locale, Locale(identifier: isEnglish ? "en_US" : "he_IL"))
                        .environment(\.layoutDirection, settingsLayoutDirection)
                        .datePickerStyle(.compact)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.92))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(sectionIconTint.opacity(0.14), lineWidth: 1)
                        )

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
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 6) {
                            Text(
                                freeSessionsRemindersEnabled
                                ? tr("תזכורות אימון חופשי פעילות", "Free training reminders are active")
                                : tr("תזכורות אימון חופשי כבויות", "Free training reminders are off")
                            )
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(Color(hex: 0xFF111827))
                            .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                            .multilineTextAlignment(primaryTextAlignment)

                            Text(
                                tr(
                                    "תקבל התראות 30 ו־10 דקות לפני אימון שסימנת אליו הגעה.",
                                    "You will receive alerts 30 and 10 minutes before a session you marked as attending."
                                )
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                            .multilineTextAlignment(primaryTextAlignment)
                        }

                        Toggle("", isOn: Binding(
                            get: { freeSessionsRemindersEnabled },
                            set: { newValue in
                                freeSessionsRemindersEnabled = newValue

                                if newValue {
                                    requestNotificationPermissionIfNeeded { }
                                }

                                toast(
                                    newValue
                                    ? tr("תזכורות אימון חופשי הופעלו", "Free training reminders enabled")
                                    : tr("תזכורות אימון חופשי בוטלו", "Free training reminders disabled")
                                )

                                feedbackTap()
                            }
                        ))
                        .labelsHidden()
                    }

                    HStack(spacing: 8) {
                        SettingsStatusPill(
                            title: freeSessionsRemindersEnabled ? tr("פעיל", "Active") : tr("כבוי", "Off"),
                            systemImage: freeSessionsRemindersEnabled ? "bell.fill" : "bell.slash.fill",
                            tint: freeSessionsRemindersEnabled ? Color.green.opacity(0.82) : Color.gray.opacity(0.82),
                            isEnglish: isEnglish
                        )

                        SettingsStatusPill(
                            title: tr("30 + 10 דק׳", "30 + 10 min"),
                            systemImage: "timer",
                            tint: sectionIconTint,
                            isEnglish: isEnglish
                        )

                        Spacer(minLength: 0)
                    }
                    .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
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
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 6) {
                            Text(
                                selectedCalendarSyncEnabled
                                ? tr("סנכרון יומן פעיל", "Calendar sync is active")
                                : tr("סנכרון יומן כבוי", "Calendar sync is off")
                            )
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(Color(hex: 0xFF111827))
                            .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                            .multilineTextAlignment(primaryTextAlignment)

                            Text(
                                selectedCalendarIdentifier.isEmpty || selectedCalendarDisplay.isEmpty
                                ? tr("בחר יומן יעד לפני הפעלת סנכרון.", "Choose a target calendar before enabling sync.")
                                : tr("יומן יעד: \(selectedCalendarDisplay)", "Target calendar: \(selectedCalendarDisplay)")
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                            .multilineTextAlignment(primaryTextAlignment)
                        }

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
                                    UserDefaults.standard.set(false, forKey: "calendar_sync_enabled")

                                    removeCalendarEvents()

                                    isBusy = false
                                    feedbackTap()
                                    toast(tr("הסנכרון ליומן שבחרת בוטל", "Selected calendar sync was disabled"))
                                }
                            }
                        ))
                        .labelsHidden()
                    }

                    HStack(spacing: 8) {
                        SettingsStatusPill(
                            title: selectedCalendarSyncEnabled ? tr("פעיל", "Active") : tr("כבוי", "Off"),
                            systemImage: selectedCalendarSyncEnabled ? "calendar.badge.checkmark" : "calendar.badge.exclamationmark",
                            tint: selectedCalendarSyncEnabled ? Color.green.opacity(0.82) : Color.gray.opacity(0.82),
                            isEnglish: isEnglish
                        )

                        if !selectedCalendarIdentifier.isEmpty {
                            SettingsStatusPill(
                                title: tr("יומן נבחר", "Calendar selected"),
                                systemImage: "checkmark.seal.fill",
                                tint: sectionIconTint,
                                isEnglish: isEnglish
                            )
                        }

                        Spacer(minLength: 0)
                    }
                    .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)

                    SettingsPickerLikeButton(
                        title: tr("בחר יומן יעד", "Choose target calendar"),
                        subtitle: selectedCalendarIdentifier.isEmpty || selectedCalendarDisplay.isEmpty
                        ? tr("עדיין לא נבחר יומן", "No calendar selected yet")
                        : selectedCalendarDisplay,
                        systemImage: "calendar.badge.plus",
                        tint: sectionIconTint,
                        isEnglish: isEnglish
                    ) {
                        openCalendarPicker()
                        feedbackTap()
                    }

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
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        SettingsStatusPill(
                            title: clickSounds ? tr("צליל פעיל", "Sound on") : tr("צליל כבוי", "Sound off"),
                            systemImage: clickSounds ? "speaker.wave.2.fill" : "speaker.slash.fill",
                            tint: clickSounds ? Color.green.opacity(0.82) : Color.gray.opacity(0.82),
                            isEnglish: isEnglish
                        )

                        SettingsStatusPill(
                            title: hapticsOn ? tr("רטט פעיל", "Haptics on") : tr("רטט כבוי", "Haptics off"),
                            systemImage: hapticsOn ? "hand.tap.fill" : "hand.raised.slash.fill",
                            tint: hapticsOn ? Color.green.opacity(0.82) : Color.gray.opacity(0.82),
                            isEnglish: isEnglish
                        )

                        Spacer(minLength: 0)
                    }
                    .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)

                    SettingsPremiumToggleRow(
                        title: tr("צליל הקשה בכפתורים", "Button tap sound"),
                        subtitle: tr("השמעת צליל קצר בעת לחיצה על כפתורים.", "Play a short sound when tapping buttons."),
                        systemImage: "speaker.wave.2.fill",
                        tint: sectionIconTint,
                        isEnglish: isEnglish,
                        isOn: $clickSounds
                    ) { enabled in
                        UserDefaults.standard.set(enabled, forKey: "click_sounds")
                        UserDefaults.standard.set(enabled, forKey: "tap_sound")

                        if enabled {
                            playClick()
                            toast(tr("צלילי הקשה הופעלו", "Button tap sound enabled"))
                        } else {
                            toast(tr("צלילי הקשה בוטלו", "Button tap sound disabled"))
                        }

                        feedbackTap()
                    }

                    SettingsPremiumToggleRow(
                        title: tr("רטט קצר בעת סימון ✓/✗", "Short haptic on ✓/✗ marking"),
                        subtitle: tr("משוב רטט קצר בפעולות סימון ואישור.", "Short haptic feedback for marking and confirmation actions."),
                        systemImage: "hand.tap.fill",
                        tint: sectionIconTint,
                        isEnglish: isEnglish,
                        isOn: $hapticsOn
                    ) { enabled in
                        UserDefaults.standard.set(enabled, forKey: "haptics_on")
                        UserDefaults.standard.set(enabled, forKey: "short_haptic")

                        if enabled {
                            hapticLight()
                            toast(tr("רטט קצר הופעל", "Short haptic enabled"))
                        } else {
                            toast(tr("רטט קצר בוטל", "Short haptic disabled"))
                        }

                        feedbackTap()
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
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        SettingsStatusPill(
                            title: cloudVoice == "female" ? tr("קול אישה", "Female voice") : tr("קול גבר", "Male voice"),
                            systemImage: "waveform",
                            tint: sectionIconTint,
                            isEnglish: isEnglish
                        )

                        Spacer(minLength: 0)
                    }
                    .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)

                    VStack(spacing: 8) {
                        Text(tr("בחר קול להשמעה:", "Choose voice playback:"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                            .multilineTextAlignment(primaryTextAlignment)

                        KmiVoiceTabs(
                            voice: Binding<String>(
                                get: { cloudVoice },
                                set: { newValue in
                                    cloudVoice = newValue
                                    UserDefaults.standard.set(newValue, forKey: "voice")
                                    UserDefaults.standard.set(newValue, forKey: "kmi_tts_voice")

                                    toast(
                                        newValue == "female"
                                        ? tr("נבחר קול אישה", "Female voice selected")
                                        : tr("נבחר קול גבר", "Male voice selected")
                                    )

                                    feedbackTap()
                                }
                            )
                        ) {
                            feedbackTap()
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.92))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(sectionIconTint.opacity(0.14), lineWidth: 1)
                    )

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
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        SettingsStatusPill(
                            title: themeDisplayName(),
                            systemImage: themeStatusIconName(),
                            tint: sectionIconTint,
                            isEnglish: isEnglish
                        )

                        Spacer(minLength: 0)
                    }
                    .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)

                    VStack(spacing: 8) {
                        Text(tr("בחר מצב תצוגה:", "Choose display mode:"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                            .multilineTextAlignment(primaryTextAlignment)

                        KmiThemeTabs(
                            themeMode: Binding<String>(
                                get: { themeMode },
                                set: { newValue in
                                    themeMode = newValue
                                    UserDefaults.standard.set(newValue, forKey: "theme_mode")

                                    toast(
                                        tr(
                                            "מצב התצוגה עודכן ל-\(themeDisplayName(for: newValue))",
                                            "Display mode updated to \(themeDisplayName(for: newValue))"
                                        )
                                    )

                                    feedbackTap()
                                }
                            )
                        ) {
                            feedbackTap()
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.92))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(sectionIconTint.opacity(0.14), lineWidth: 1)
                    )

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
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        SettingsStatusPill(
                            title: appLockMode == "biometric" ? tr("נעילה פעילה", "Lock enabled") : tr("ללא נעילה", "No lock"),
                            systemImage: appLockMode == "biometric" ? "lock.fill" : "lock.open.fill",
                            tint: appLockMode == "biometric" ? Color.green.opacity(0.82) : Color.gray.opacity(0.82),
                            isEnglish: isEnglish
                        )

                        SettingsStatusPill(
                            title: biometricAvailable() ? tr("ביומטרי זמין", "Biometric available") : tr("ביומטרי לא זמין", "Biometric unavailable"),
                            systemImage: biometricAvailable() ? "faceid" : "exclamationmark.triangle.fill",
                            tint: biometricAvailable() ? sectionIconTint : Color.orange.opacity(0.88),
                            isEnglish: isEnglish
                        )

                        Spacer(minLength: 0)
                    }
                    .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)

                    VStack(spacing: 8) {
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
                                        UserDefaults.standard.set("none", forKey: "app_lock_mode")
                                        feedbackTap()
                                        toast(tr("נעילת האפליקציה בוטלה", "App lock disabled"))

                                    case "biometric":
                                        appLockMode = "biometric"
                                        UserDefaults.standard.set("biometric", forKey: "app_lock_mode")

                                        authenticateBiometricIfAvailable { ok in
                                            if ok {
                                                toast(tr("נעילה ביומטרית הופעלה", "Biometric lock enabled"))
                                                hapticSuccess()
                                            } else {
                                                appLockMode = "none"
                                                UserDefaults.standard.set("none", forKey: "app_lock_mode")
                                                toast(tr("לא ניתן להפעיל נעילה ביומטרית", "Could not enable biometric lock"))
                                                hapticError()
                                            }

                                            feedbackTap()
                                        }

                                    default:
                                        appLockMode = "none"
                                        UserDefaults.standard.set("none", forKey: "app_lock_mode")
                                    }
                                }
                            )
                        ) {
                            Text(tr("ללא\nנעילה", "No\nlock")).tag("none")
                            Text(tr("נעילה\nביומטרית", "Biometric\nlock")).tag("biometric")
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.92))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(sectionIconTint.opacity(0.14), lineWidth: 1)
                    )

                    Text(
                        biometricAvailable()
                        ? tr(
                            "כאשר הנעילה פעילה, האפליקציה תדרוש זיהוי ביומטרי בהתאם להגדרות המכשיר.",
                            "When enabled, the app will require biometric authentication according to the device settings."
                        )
                        : tr(
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

            // --- Stats
            SettingsCard(
                title: tr("סטטיסטיקות", "Statistics"),
                subtitle: tr("התקדמות לפי חגורות ונושאים", "Progress by belts and topics"),
                iconSystemName: "chart.bar.fill",
                iconTint: sectionIconTint
            ) {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        if isEnglish {
                            SettingsStatusPill(
                                title: tr("חגורה \(settingsRankDisplayName())", "Rank \(settingsRankDisplayName())"),
                                systemImage: "rosette",
                                tint: currentBeltTextColor(),
                                isEnglish: isEnglish
                            )

                            SettingsStatusPill(
                                title: settingsRoleDisplayName(),
                                systemImage: settingsRoleIconName(),
                                tint: sectionIconTint,
                                isEnglish: isEnglish
                            )

                            Spacer(minLength: 0)
                        } else {
                            Spacer(minLength: 0)

                            SettingsStatusPill(
                                title: settingsRoleDisplayName(),
                                systemImage: settingsRoleIconName(),
                                tint: sectionIconTint,
                                isEnglish: isEnglish
                            )

                            SettingsStatusPill(
                                title: tr("חגורה \(settingsRankDisplayName())", "Rank \(settingsRankDisplayName())"),
                                systemImage: "rosette",
                                tint: currentBeltTextColor(),
                                isEnglish: isEnglish
                            )
                        }
                    }
                    .environment(\.layoutDirection, .leftToRight)

                    VStack(spacing: 10) {
                        Text(
                            tr(
                                "ההתקדמות מחושבת לפי סימוני יודע / לחזרה ששמרת במסכי החומר והתרגול.",
                                "Progress is calculated from the known / review marks saved in the material and practice screens."
                            )
                        )
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xFF64748B))
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                        .multilineTextAlignment(primaryTextAlignment)

                        BeltsProgressBarsIOS(rows: beltProgressRowsFromDefaults())
                            .padding(.top, 2)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.92))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(sectionIconTint.opacity(0.14), lineWidth: 1)
                    )
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
                    SettingsPremiumActionButton(
                        title: tr("נקה היסטוריית שידורים", "Clear broadcast history"),
                        subtitle: tr("מוחק רק רשימת שידורים אחרונים", "Clears only recent broadcasts"),
                        systemImage: "megaphone.fill",
                        tint: sectionIconTint,
                        isDestructive: false
                    ) {
                        feedbackTap()
                        showClearBroadcastHistoryConfirm = true
                    }

                    SettingsPremiumActionButton(
                        title: tr("נקה מטמון אפליקציה", "Clear app cache"),
                        subtitle: tr("לא מוחק חשבון או הרשמה", "Does not delete account or registration"),
                        systemImage: "trash.fill",
                        tint: sectionIconTint,
                        isDestructive: true
                    ) {
                        feedbackTap()
                        showClearCacheConfirm = true
                    }
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
                    HStack(spacing: 8) {
                        SettingsStatusPill(
                            title: tr("פרטיות", "Privacy"),
                            systemImage: "lock.fill",
                            tint: sectionIconTint,
                            isEnglish: isEnglish
                        )

                        SettingsStatusPill(
                            title: tr("תנאים", "Terms"),
                            systemImage: "doc.text.fill",
                            tint: sectionIconTint,
                            isEnglish: isEnglish
                        )

                        SettingsStatusPill(
                            title: tr("נגישות", "Accessibility"),
                            systemImage: "figure.stand",
                            tint: sectionIconTint,
                            isEnglish: isEnglish
                        )

                        Spacer(minLength: 0)
                    }
                    .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)

                    VStack(spacing: 10) {
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
                    .padding(.top, 2)
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
                    HStack(spacing: 8) {
                        if isEnglish {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(sectionIconTint)

                            Text(appVersionLine())
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)
                        } else {
                            Text(appVersionLine())
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .multilineTextAlignment(.trailing)

                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(sectionIconTint)
                        }
                    }
                    .environment(\.layoutDirection, .leftToRight)

                    HStack(spacing: 10) {
                        SettingsPremiumActionButton(
                            title: tr("שלח משוב", "Send feedback"),
                            subtitle: nil,
                            systemImage: "envelope.fill",
                            tint: sectionIconTint,
                            isDestructive: false
                        ) {
                            sendFeedbackEmailWithSystemDetails()
                            hapticSuccess()
                        }

                        SettingsPremiumActionButton(
                            title: tr("דרג בחנות", "Rate in store"),
                            subtitle: nil,
                            systemImage: "star.fill",
                            tint: Color.orange.opacity(0.92),
                            isDestructive: false
                        ) {
                            requestReview()
                            hapticSuccess()
                        }
                    }

                    SettingsPremiumActionButton(
                        title: tr("שתף את האפליקציה", "Share the app"),
                        subtitle: tr("שליחה לחברים או מתאמנים", "Send to friends or trainees"),
                        systemImage: "square.and.arrow.up.fill",
                        tint: sectionIconTint,
                        isDestructive: false
                    ) {
                        shareApp()
                        hapticSuccess()
                    }
                }
            }
        }
    }

    private struct SettingsHeaderChip: View {
        let title: String
        let systemImage: String
        let tint: Color
        let isEnglish: Bool

        var body: some View {
            HStack(spacing: 5) {
                if isEnglish {
                    Image(systemName: systemImage)
                        .font(.system(size: 10.5, weight: .black))

                    Text(title)
                        .font(.system(size: 11.5, weight: .black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                } else {
                    Text(title)
                        .font(.system(size: 11.5, weight: .black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Image(systemName: systemImage)
                        .font(.system(size: 10.5, weight: .black))
                }
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            )
        }
    }
    
    private struct SettingsPremiumActionButton: View {
        let title: String
        let subtitle: String?
        let systemImage: String
        let tint: Color
        let isDestructive: Bool
        let onTap: () -> Void

        @State private var pressed: Bool = false

        private var effectiveTint: Color {
            isDestructive ? Color(red: 0.70, green: 0.15, blue: 0.12) : tint
        }

        private var textAlignment: TextAlignment {
            .center
        }

        var body: some View {
            Button {
                withAnimation(.easeOut(duration: 0.10)) {
                    pressed = true
                }

                onTap()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                    withAnimation(.easeOut(duration: 0.12)) {
                        pressed = false
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .black))
                        .frame(width: 24)

                    VStack(spacing: 2) {
                        Text(title)
                            .font(.system(size: 15.5, weight: .black))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .multilineTextAlignment(textAlignment)

                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.system(size: 11.5, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.74)
                                .multilineTextAlignment(textAlignment)
                                .opacity(0.88)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(height: subtitle == nil ? 48 : 58)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(effectiveTint)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: effectiveTint.opacity(0.18), radius: 8, x: 0, y: 4)
                .scaleEffect(pressed ? 0.96 : 1.0)
            }
            .buttonStyle(.plain)
        }
    }
    
    private struct SettingsPremiumToggleRow: View {
        let title: String
        let subtitle: String
        let systemImage: String
        let tint: Color
        let isEnglish: Bool
        @Binding var isOn: Bool
        let onChange: (Bool) -> Void

        private var textAlignment: TextAlignment {
            isEnglish ? .leading : .trailing
        }

        private var frameAlignment: Alignment {
            isEnglish ? .leading : .trailing
        }

        var body: some View {
            HStack(spacing: 12) {
                if isEnglish {
                    iconBubble
                    textBlock
                    toggleView
                } else {
                    toggleView
                    textBlock
                    iconBubble
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(tint.opacity(isOn ? 0.26 : 0.14), lineWidth: 1)
            )
            .shadow(color: tint.opacity(isOn ? 0.10 : 0.05), radius: 8, x: 0, y: 4)
            .environment(\.layoutDirection, .leftToRight)
        }

        private var iconBubble: some View {
            ZStack {
                Circle()
                    .fill(tint.opacity(isOn ? 0.16 : 0.09))
                    .frame(width: 40, height: 40)

                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(tint.opacity(isOn ? 1.0 : 0.62))
            }
        }

        private var textBlock: some View {
            VStack(alignment: isEnglish ? .leading : .trailing, spacing: 4) {
                Text(title)
                    .font(.system(size: 15.5, weight: .black))
                    .foregroundStyle(Color(hex: 0xFF111827))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .multilineTextAlignment(textAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)

                Text(subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xFF64748B))
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
                    .multilineTextAlignment(textAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
        }

        private var toggleView: some View {
            Toggle(
                "",
                isOn: Binding(
                    get: { isOn },
                    set: { newValue in
                        isOn = newValue
                        onChange(newValue)
                    }
                )
            )
            .labelsHidden()
        }
    }
    
    private struct SettingsStatusPill: View {
        let title: String
        let systemImage: String
        let tint: Color
        let isEnglish: Bool

        var body: some View {
            HStack(spacing: 6) {
                if isEnglish {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .black))

                    Text(title)
                        .font(.system(size: 12, weight: .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                } else {
                    Text(title)
                        .font(.system(size: 12, weight: .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .black))
                }
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tint.opacity(0.11))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            )
            .environment(\.layoutDirection, .leftToRight)
        }
    }
    
    private struct SettingsPickerLikeButton: View {
        let title: String
        let subtitle: String?
        let systemImage: String
        let tint: Color
        let isEnglish: Bool
        let onTap: () -> Void

        @State private var pressed: Bool = false

        private var textAlignment: TextAlignment {
            isEnglish ? .leading : .trailing
        }

        private var frameAlignment: Alignment {
            isEnglish ? .leading : .trailing
        }

        var body: some View {
            Button {
                withAnimation(.easeOut(duration: 0.10)) {
                    pressed = true
                }

                onTap()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                    withAnimation(.easeOut(duration: 0.12)) {
                        pressed = false
                    }
                }
            } label: {
                HStack(spacing: 11) {
                    if isEnglish {
                        iconBubble

                        textBlock

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(tint.opacity(0.82))
                    } else {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(tint.opacity(0.82))

                        textBlock

                        iconBubble
                    }
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 58)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.94))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: tint.opacity(0.08), radius: 8, x: 0, y: 4)
                .scaleEffect(pressed ? 0.97 : 1.0)
            }
            .buttonStyle(.plain)
            .environment(\.layoutDirection, .leftToRight)
        }

        private var iconBubble: some View {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.13))
                    .frame(width: 38, height: 38)

                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(tint)
            }
        }

        private var textBlock: some View {
            VStack(alignment: isEnglish ? .leading : .trailing, spacing: 3) {
                Text(title)
                    .font(.system(size: 15.5, weight: .black))
                    .foregroundStyle(Color(hex: 0xFF111827))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .multilineTextAlignment(textAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xFF64748B))
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)
                        .multilineTextAlignment(textAlignment)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                }
            }
        }
    }
    
    private struct SettingsFooterButton: View {
        let title: String
        let systemImage: String
        let isPrimary: Bool
        let tint: Color
        let onTap: () -> Void

        @State private var pressed: Bool = false

        private var fillColor: Color {
            isPrimary ? tint : Color.white.opacity(0.96)
        }

        private var textColor: Color {
            isPrimary ? Color.white : tint
        }

        var body: some View {
            Button {
                withAnimation(.easeOut(duration: 0.10)) {
                    pressed = true
                }

                onTap()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                    withAnimation(.easeOut(duration: 0.12)) {
                        pressed = false
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .black))

                    Text(title)
                        .font(.system(size: 16, weight: .black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(fillColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isPrimary ? Color.white.opacity(0.22) : tint.opacity(0.20), lineWidth: 1)
                )
                .shadow(color: tint.opacity(isPrimary ? 0.18 : 0.08), radius: 8, x: 0, y: 4)
                .scaleEffect(pressed ? 0.96 : 1.0)
            }
            .buttonStyle(.plain)
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
            to: supportEmailAddress,
            subject: tr("משוב על האפליקציה", "App feedback"),
            body: body
        )
    }
    
    // MARK: Calendar picker

    private var calendarPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if availableWritableCalendars.isEmpty {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(sectionIconTint.opacity(0.12))
                                .frame(width: 82, height: 82)

                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(sectionIconTint)
                        }

                        Text(tr("לא נמצאו יומנים זמינים", "No calendars found"))
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(Color(hex: 0xFF111827))
                            .multilineTextAlignment(.center)

                        Text(tr("לא נמצאו יומנים זמינים לכתיבה במכשיר.", "No writable calendars were found on this device."))
                            .font(.system(size: 14, weight: .semibold))
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
        let selected = tempSelectedCalendarIdentifier == calendar.calendarIdentifier

        return Button {
            tempSelectedCalendarIdentifier = calendar.calendarIdentifier
            feedbackTap()
        } label: {
            HStack(spacing: 12) {
                if isEnglish {
                    calendarPickerCheckmark(calendar)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(calendar.title.isEmpty ? tr("יומן ללא שם", "Unnamed calendar") : calendar.title)
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(Color(hex: 0xFF111827))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Text(calendar.source.title)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xFF64748B))
                            .lineLimit(1)
                    }

                    Spacer()
                } else {
                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(calendar.title.isEmpty ? tr("יומן ללא שם", "Unnamed calendar") : calendar.title)
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(Color(hex: 0xFF111827))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Text(calendar.source.title)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xFF64748B))
                            .lineLimit(1)
                    }

                    calendarPickerCheckmark(calendar)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selected ? sectionIconTint.opacity(0.10) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selected ? sectionIconTint.opacity(0.30) : Color.clear, lineWidth: 1)
            )
            .shadow(color: selected ? sectionIconTint.opacity(0.10) : Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
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
            hapticError()
            return
        }

        selectedCalendarIdentifier = selected.calendarIdentifier
        selectedCalendarDisplay = "\(selected.title) (\(selected.source.title))"

        UserDefaults.standard.set(selectedCalendarIdentifier, forKey: "calendar_sync_selected_calendar_id")
        UserDefaults.standard.set(selectedCalendarDisplay, forKey: "calendar_sync_selected_calendar_display")

        showCalendarPicker = false
        feedbackTap()

        if selectedCalendarSyncEnabled {
            enableSelectedCalendarSync()
        } else {
            toast(tr("היומן נשמר. אפשר להפעיל סנכרון.", "Calendar saved. You can now enable sync."))
            hapticSuccess()
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
            SettingsFooterButton(
                title: tr("ביטול", "Cancel"),
                systemImage: "xmark.circle",
                isPrimary: false,
                tint: sectionIconTint
            ) {
                feedbackTap()
                nav.pop()
            }

            SettingsFooterButton(
                title: tr("אישור", "Confirm"),
                systemImage: "checkmark.circle.fill",
                isPrimary: true,
                tint: sectionIconTint
            ) {
                hapticSuccess()
                nav.pop()
            }
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
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
            defaults.string(forKey: "selected_branch") ??
            defaults.string(forKey: "current_branch") ??
            fallbackBranchFromArray
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedGroup = (
            defaults.string(forKey: "active_group") ??
            defaults.string(forKey: "group") ??
            defaults.string(forKey: "kmi.user.group") ??
            defaults.string(forKey: "groupKey") ??
            defaults.string(forKey: "group_key") ??
            defaults.string(forKey: "primaryGroup") ??
            defaults.string(forKey: "age_group") ??
            defaults.string(forKey: "ageGroup") ??
            fallbackGroupFromArray
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        branch = resolvedBranch
        group = resolvedGroup
    }
}
