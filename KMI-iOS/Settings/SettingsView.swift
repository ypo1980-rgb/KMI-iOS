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

    // MARK: Global display settings
    @EnvironmentObject
    private var displaySettings: KmiDisplaySettings

    @Environment(\.colorScheme)
    private var colorScheme

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var settingsPrimaryTextColor: Color {
        KmiAppTheme.onSurface(for: colorScheme)
    }

    private var settingsSecondaryTextColor: Color {
        KmiAppTheme.onSurfaceVariant(for: colorScheme)
    }

    // MARK: Language
    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"
    @AppStorage("selected_language_code") private var selectedLanguageCode: String = "he"

    var isEnglish: Bool {
        let primary = kmiAppLanguageCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if primary == "he" || primary == "hebrew" {
            return false
        }

        if primary == "en" || primary == "english" {
            return true
        }

        let selected = selectedLanguageCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if selected == "he" || selected == "hebrew" {
            return false
        }

        if selected == "en" || selected == "english" {
            return true
        }

        let raw = appLanguageRaw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if raw == "he" || raw == "hebrew" {
            return false
        }

        if raw == "en" || raw == "english" {
            return true
        }

        let initial = initialLanguageCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if initial == "en" || initial == "english" {
            return true
        }

        return false
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
    @State private var registrationSaveError: String?
    @State private var goLegal: Bool = false
    @State private var legalInitialTab: Int = 0

    @State private var showCalendarPicker: Bool = false
    @State private var availableWritableCalendars: [EKCalendar] = []
    @State private var tempSelectedCalendarIdentifier: String = ""

    @State private var showClearBroadcastHistoryConfirm: Bool = false
    @State private var showClearCacheConfirm: Bool = false

    @State private var showTrainingLeadPicker: Bool = false
    @State private var tempTrainingLeadHours: Int = 1
    @State private var tempTrainingLeadMinutes: Int = 0
    
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
        KmiAppTheme.primary(for: colorScheme)
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

    private var dailyReminderCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone =
            TimeZone(identifier: "Asia/Jerusalem") ?? .current
        return calendar
    }

    private var dailyReminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                dailyReminderCalendar.date(
                    bySettingHour: dailyReminderHour,
                    minute: dailyReminderMinute,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { newValue in
                let comps = dailyReminderCalendar.dateComponents(
                    [.hour, .minute],
                    from: newValue
                )

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
            BeltTopicsGradientBackground()

            ScrollView {
                VStack(spacing: 12) {
                    settingsCards

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 16)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionButtons
        }
        .disabled(isBusy)
        .overlay {
            if isBusy {
                KmiLoadingOverlay()
            }
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
        .sheet(isPresented: $showTrainingLeadPicker) {
            trainingLeadPickerSheet
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
                    guard !isBusy else { return }

                    registrationSaveError = nil
                    showRegistrationEdit = false
                },
                onSubmit: { form in
                    guard !isBusy else { return }

                    isBusy = true
                    registrationSaveError = nil

                    Task { @MainActor in
                        defer {
                            isBusy = false
                        }

                        do {
                            try await saveEditedRegistration(form)

                            loadBranchAndGroupFromDefaults()
                            showRegistrationEdit = false

                            toast(
                                tr(
                                    "הפרטים עודכנו בהצלחה",
                                    "Details updated successfully"
                                )
                            )

                            hapticSuccess()
                        } catch is CancellationError {
                            // הפעולה בוטלה או שהמשתמש המחובר השתנה.
                            // אין להציג הודעת הצלחה.
                        } catch {
                            registrationSaveError = tr(
                                "לא ניתן היה להשלים את השמירה. הפרטים שהזנת נשארו בטופס. בדוק את החיבור ונסה שוב.",
                                "Could not complete the save. Your entries remain in the form. Check your connection and try again."
                            )
                        }
                    }
                }
            )
            .disabled(isBusy)
            .overlay {
                if isBusy {
                    KmiLoadingOverlay()
                }
            }
            .interactiveDismissDisabled(isBusy)
            .alert(
                tr(
                    "השמירה לא הושלמה",
                    "Save unsuccessful"
                ),
                isPresented: Binding(
                    get: {
                        registrationSaveError != nil
                    },
                    set: { isPresented in
                        if !isPresented {
                            registrationSaveError = nil
                        }
                    }
                )
            ) {
                Button(
                    tr("אישור", "OK"),
                    role: .cancel
                ) {
                    registrationSaveError = nil
                }
            } message: {
                Text(registrationSaveError ?? "")
            }
        }
        .onAppear {
            normalizeSettingsLanguageDefaults()
            loadBranchAndGroupFromDefaults()

            if selectedCalendarSyncEnabled {
                calendarSyncEnabled = true
            }

            if !selectedCalendarIdentifier.isEmpty
                && selectedCalendarDisplay.isEmpty {
                let store = EKEventStore()

                if let calendar = store.calendar(
                    withIdentifier: selectedCalendarIdentifier
                ) {
                    selectedCalendarDisplay =
                        "\(calendar.title) (\(calendar.source.title))"
                }
            }
        }
    }

    private func normalizeSettingsLanguageDefaults() {
        let primary = kmiAppLanguageCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let selected = selectedLanguageCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let resolvedIsEnglish: Bool = {
            if primary == "he" || primary == "hebrew" { return false }
            if primary == "en" || primary == "english" { return true }
            if selected == "he" || selected == "hebrew" { return false }
            if selected == "en" || selected == "english" { return true }
            return false
        }()

        kmiAppLanguageCode = resolvedIsEnglish ? "en" : "he"
        selectedLanguageCode = resolvedIsEnglish ? "en" : "he"
        appLanguageRaw = resolvedIsEnglish ? "ENGLISH" : "HEBREW"
        initialLanguageCode = resolvedIsEnglish ? "ENGLISH" : "HEBREW"

        UserDefaults.standard.set(resolvedIsEnglish ? "en" : "he", forKey: "kmi_app_language")
        UserDefaults.standard.set(resolvedIsEnglish ? "en" : "he", forKey: "selected_language_code")
        UserDefaults.standard.set(resolvedIsEnglish ? "ENGLISH" : "HEBREW", forKey: "app_language")
        UserDefaults.standard.set(resolvedIsEnglish ? "ENGLISH" : "HEBREW", forKey: "initial_language_code")
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
                                .kmiFont(
                                    size: 30,
                                    weight: .heavy
                                )
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)

                            closeSettingsButton
                        } else {
                            closeSettingsButton

                            Text(tr("הגדרות", "Settings"))
                                .kmiFont(
                                    size: 30,
                                    weight: .heavy
                                )
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
            saveAllSettingsAndExit()
        } label: {
            
            Image(systemName: "xmark")
                .kmiFont(
                    size: 20,
                    weight: .bold
                )
                .foregroundStyle(Color.white)
                .frame(
                    minWidth: 48,
                    minHeight: 48
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            tr(
                "סגור הגדרות",
                "Close settings"
            )
        )
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
        .background(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(KmiAppTheme.surface(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .strokeBorder(
                KmiAppTheme.outlineVariant(for: colorScheme),
                lineWidth: 1
            )
        )
    }

    private var profileIcon: some View {
        ZStack {
            Circle()
                .fill(
                    (
                        isCoach
                            ? Color(hex: 0xFF6A1B9A)
                            : Color(hex: 0xFF1565C0)
                    )
                    .opacity(
                        isDarkMode ? 0.20 : 0.12
                    )
                )
                .frame(
                    width: 46,
                    height: 46
                )

            Image(
                systemName:
                    isCoach
                    ? "checkmark.seal.fill"
                    : "person.fill"
            )
            .kmiFont(
                size: 24,
                weight: .semibold
            )
            .foregroundStyle(
                isCoach
                    ? Color(hex: 0xFF6A1B9A)
                    : Color(hex: 0xFF1565C0)
            )
        }
        .frame(
            minWidth: 48,
            minHeight: 48
        )
    }

    private var profileTextBlock: some View {
        VStack(
            alignment:
                isEnglish
                ? .leading
                : .trailing,
            spacing: 5
        ) {
            Text(settingsProfileName())
                .kmiFont(
                    size: 22,
                    weight: .heavy
                )
                .foregroundStyle(
                    isDarkMode
                        ? Color.white.opacity(0.94)
                        : Color.black.opacity(0.88)
                )
                .lineLimit(2)
                .minimumScaleFactor(0.68)
                .frame(
                    maxWidth: .infinity,
                    alignment: horizontalTextAlignment
                )
                .multilineTextAlignment(
                    primaryTextAlignment
                )

            if !phone
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty {

                Text(phone)
                    .kmiFont(
                        size: 15.5,
                        weight: .semibold
                    )
                    .foregroundStyle(
                        isDarkMode
                            ? Color.white.opacity(0.76)
                            : Color.black.opacity(0.68)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .frame(
                        maxWidth: .infinity,
                        alignment: horizontalTextAlignment
                    )
                    .multilineTextAlignment(
                        primaryTextAlignment
                    )
            }

            if !email
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty {

                Text(email)
                    .kmiFont(
                        size: 13.5,
                        weight: .semibold
                    )
                    .foregroundStyle(
                        isDarkMode
                            ? Color.white.opacity(0.64)
                            : Color.black.opacity(0.54)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.66)
                    .frame(
                        maxWidth: .infinity,
                        alignment: horizontalTextAlignment
                    )
                    .multilineTextAlignment(
                        primaryTextAlignment
                    )
            }

            if !settingsBranchGroupLine().isEmpty {
                Text(
                    settingsBranchGroupLine()
                )
                .kmiFont(
                    size: 13,
                    weight: .bold
                )
                .foregroundStyle(settingsSecondaryTextColor)
                .lineLimit(2)
                .minimumScaleFactor(0.66)
                .frame(
                    maxWidth: .infinity,
                    alignment: horizontalTextAlignment
                )
                .multilineTextAlignment(
                    primaryTextAlignment
                )
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: horizontalTextAlignment
        )
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
        VStack(spacing: 12) {

            SettingsListSection(
                title: tr("כללי ותזכורות", "General and reminders"),
                subtitle: tr(
                    "שפה, גודל תצוגה, תזכורות אימון והגדרות שימוש יומי",
                    "Language, display size, training reminders and daily usage settings"
                ),
                systemImage: "slider.horizontal.3",
                tint: sectionIconTint,
                isEnglish: isEnglish
            ) {
                SettingsListItem(
                    title: tr("שפה", "Language"),
                    value: isEnglish ? "English" : "עברית",
                    systemImage: "globe",
                    tint: Color(hex: 0xFF2A78E4),
                    isEnglish: isEnglish,
                    topRounded: true
                ) {
                    VStack(spacing: 8) {
                        Text(
                            tr(
                                "בחר שפת ממשק",
                                "Choose interface language"
                            )
                        )
                        .kmiFont(
                            size: 11,
                            weight: .semibold
                        )
                        .foregroundStyle(settingsSecondaryTextColor)
                        .frame(
                            maxWidth: .infinity,
                            alignment: horizontalTextAlignment
                        )
                        .multilineTextAlignment(
                            primaryTextAlignment
                        )

                        Picker(
                            "",
                            selection: Binding<Int>(
                                get: {
                                    isEnglish ? 1 : 0
                                },
                                set: { newValue in
                                    applyInterfaceLanguage(
                                        newValue == 1
                                    )
                                }
                            )
                        ) {
                            Text("עברית").tag(0)
                            Text("English").tag(1)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                SettingsListDivider()

                SettingsListItem(
                    title: tr(
                        "גודל כתב ואייקונים",
                        "Text and icon size"
                    ),
                    value: displaySettings.fontSize.localizedTitle(
                        isEnglish: isEnglish
                    ),
                    systemImage: "textformat.size",
                    tint: Color(hex: 0xFF0F9D8A),
                    isEnglish: isEnglish
                ) {
                    VStack(spacing: 10) {
                        Text(
                            tr(
                                "בחר את גודל הכתב והאייקונים באפליקציה",
                                "Choose the text and icon size in the app"
                            )
                        )
                        .kmiFont(
                            size: 11,
                            weight: .semibold
                        )
                        .foregroundStyle(settingsSecondaryTextColor)
                        .frame(
                            maxWidth: .infinity,
                            alignment: horizontalTextAlignment
                        )
                        .multilineTextAlignment(
                            primaryTextAlignment
                        )

                        Picker(
                            "",
                            selection: Binding<KmiAppFontSize>(
                                get: {
                                    displaySettings.fontSize
                                },
                                set: { newValue in
                                    displaySettings.setFontSize(
                                        newValue
                                    )

                                    feedbackTap()

                                    toast(
                                        tr(
                                            "גודל התצוגה שונה ל־\(newValue.localizedTitle(isEnglish: false))",
                                            "Display size changed to \(newValue.localizedTitle(isEnglish: true))"
                                        )
                                    )
                                }
                            )
                        ) {
                            ForEach(
                                KmiAppFontSize.allCases
                            ) { option in
                                Text(
                                    option.localizedTitle(
                                        isEnglish: isEnglish
                                    )
                                )
                                .tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel(
                            tr(
                                "בחירת גודל כתב ואייקונים",
                                "Choose text and icon size"
                            )
                        )

                        HStack(spacing: 8) {
                            Image(systemName: "textformat")
                                .kmiFont(
                                    size: KmiIconSize.tiny,
                                    weight: .bold
                                )
                                .accessibilityHidden(true)

                            Text(
                                tr(
                                    "תצוגה מקדימה של גודל הכתב",
                                    "Text size preview"
                                )
                            )
                            .kmiFont(
                                size: 14,
                                weight: .bold
                            )

                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(
                            isDarkMode
                                ? Color(
                                    red: 0.42,
                                    green: 0.68,
                                    blue: 1.00
                                )
                                : Color(hex: 0xFF123C7C)
                        )
                        .padding(.horizontal, 12)
                        .frame(minHeight: 46)
                        .background(
                            isDarkMode
                                ? Color.blue.opacity(0.12)
                                : Color(hex: 0xFFF3F7FF)
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 14,
                                style: .continuous
                            )
                        )
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: 14,
                                style: .continuous
                            )
                            .stroke(
                                Color(hex: 0xFF2A78E4)
                                    .opacity(0.16),
                                lineWidth: 1
                            )
                        }
                        .environment(
                            \.layoutDirection,
                            settingsLayoutDirection
                        )
                    }
                }

                SettingsListDivider()

                SettingsListItem(
                    title: tr(
                        "תזכורות אימון",
                        "Training reminders"
                    ),
                    value: trainingRemindersEnabled
                        ? formatTrainingLeadTime(
                            trainingReminderMinutes
                        )
                        : tr("כבוי", "Off"),
                    systemImage: "alarm.fill",
                    tint: Color(hex: 0xFF7B61D9),
                    isEnglish: isEnglish,
                    bottomRounded: true
                ) {
                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            Text(
                                trainingRemindersEnabled
                                ? tr(
                                    "בחר כמה זמן לפני האימון לקבל התראה",
                                    "Choose exactly how long before training to receive a reminder"
                                )
                                : tr(
                                    "הפעל תזכורות לפני אימונים",
                                    "Enable reminders before training sessions"
                                )
                            )
                            .kmiFont(
                                size: 11,
                                weight: .semibold
                            )
                            .foregroundStyle(settingsSecondaryTextColor)
                            .frame(
                                maxWidth: .infinity,
                                alignment: horizontalTextAlignment
                            )
                            .multilineTextAlignment(
                                primaryTextAlignment
                            )

                            Toggle("", isOn: Binding(
                                get: { trainingRemindersEnabled },
                                set: { newValue in
                                    trainingRemindersEnabled = newValue

                                    if newValue {
                                        requestNotificationPermissionIfNeeded(
                                            onDenied: {
                                                trainingRemindersEnabled = false
                                            },
                                            onGranted: {
                                                guard trainingRemindersEnabled else {
                                                    return
                                                }

                                                scheduleTrainingReminders(
                                                    minutes: trainingReminderMinutes
                                                )
                                            }
                                        )
                                    } else {
                                        cancelTrainingReminders()
                                    }

                                    feedbackTap()
                                }
                            ))
                            .labelsHidden()
                        }

                        if trainingRemindersEnabled {
                            VStack(spacing: 9) {
                                Text(
                                    formatTrainingLeadTime(
                                        trainingReminderMinutes
                                    )
                                )
                                .kmiFont(
                                    size: 14,
                                    weight: .black
                                )
                                .foregroundStyle(
                                    isDarkMode
                                        ? Color(
                                            red: 0.42,
                                            green: 0.68,
                                            blue: 1.00
                                        )
                                        : Color(hex: 0xFF123C7C)
                                )
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: horizontalTextAlignment
                                )
                                .multilineTextAlignment(
                                    primaryTextAlignment
                                )

                                Text(
                                    tr(
                                        "ברירת המחדל היא 60 דקות אם לא נבחר זמן אחר.",
                                        "Default is 60 minutes if no other time is selected."
                                    )
                                )
                                .kmiFont(
                                    size: 10.5,
                                    weight: .semibold
                                )
                                .foregroundStyle(settingsSecondaryTextColor)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: horizontalTextAlignment
                                )
                                .multilineTextAlignment(
                                    primaryTextAlignment
                                )

                                SettingsPickerLikeButton(
                                    title: tr("בחר זמן מדויק", "Choose exact time"),
                                    subtitle: formatTrainingLeadTime(trainingReminderMinutes),
                                    systemImage: "clock.badge.checkmark",
                                    tint: Color(hex: 0xFF7B61D9),
                                    isEnglish: isEnglish
                                ) {
                                    openTrainingLeadPicker()
                                    feedbackTap()
                                }
                            }
                        }
                    }
                }
            }

            SettingsListSection(
                title: tr("התראות וסנכרון", "Notifications and sync"),
                subtitle: tr(
                    "תרגיל יומי, אימונים חופשיים וסנכרון ליומן",
                    "Daily exercise, free training reminders and calendar sync"
                ),
                systemImage: "bell.badge.fill",
                tint: sectionIconTint,
                isEnglish: isEnglish
            ) {
                SettingsListItem(
                    title: tr("תרגיל יומי", "Daily exercise"),
                    value: dailyReminderEnabledBinding.wrappedValue
                    ? String(format: "%02d:%02d", dailyReminderHour, dailyReminderMinute)
                    : tr("כבוי", "Off"),
                    systemImage: "bell.badge.fill",
                    tint: Color(hex: 0xFF2A78E4),
                    isEnglish: isEnglish,
                    topRounded: true
                ) {
                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            Text(
                                isCoach
                                ? tr(
                                    "המאמן יכול לכבות או להפעיל תרגיל יומי לעצמו",
                                    "The coach can enable or disable a daily exercise for themselves"
                                )
                                : tr(
                                    "שלח לי בכל יום תרגיל מהחגורה הבאה",
                                    "Send me a daily exercise from the next belt"
                                )
                            )
                            .kmiFont(
                                size: 11,
                                weight: .semibold
                            )
                            .foregroundStyle(settingsSecondaryTextColor)
                            .frame(
                                maxWidth: .infinity,
                                alignment: horizontalTextAlignment
                            )
                            .multilineTextAlignment(
                                primaryTextAlignment
                            )

                            Toggle(
                                tr(
                                    "תזכורות אימונים חופשיים",
                                    "Free training reminders"
                                ),
                                isOn: Binding(
                                    get: { freeSessionsRemindersEnabled },
                                    set: { newValue in
                                        freeSessionsRemindersEnabled = newValue

                                        if newValue {
                                            requestNotificationPermissionIfNeeded(
                                                onDenied: {
                                                    freeSessionsRemindersEnabled = false
                                                },
                                                onGranted: {
                                                    guard freeSessionsRemindersEnabled else {
                                                        return
                                                    }

                                                    toast(
                                                        tr(
                                                            "העדפת תזכורות האימון החופשי נשמרה.",
                                                            "Free training reminder preference was saved."
                                                        )
                                                    )
                                                }
                                            )
                                        } else {
                                            toast(
                                                tr(
                                                    "העדפת תזכורות האימון החופשי כובתה.",
                                                    "Free training reminder preference was turned off."
                                                )
                                            )
                                        }

                                        feedbackTap()
                                    }
                                )
                            )
                            .labelsHidden()
                            .tint(KmiAppTheme.primary(for: colorScheme))
                        }

                        if dailyReminderEnabledBinding.wrappedValue {
                            DatePicker(
                                tr("שעת התזכורת: \(String(format: "%02d:%02d", dailyReminderHour, dailyReminderMinute))",
                                   "Reminder time: \(String(format: "%02d:%02d", dailyReminderHour, dailyReminderMinute))"),
                                selection: dailyReminderTimeBinding,
                                displayedComponents: .hourAndMinute
                            )
                            .environment(
                                \.calendar,
                                dailyReminderCalendar
                            )
                            .environment(
                                \.timeZone,
                                dailyReminderCalendar.timeZone
                            )
                            .environment(
                                \.locale,
                                Locale(
                                    identifier: isEnglish ? "en_US" : "he_IL"
                                )
                            )
                            .environment(
                                \.layoutDirection,
                                settingsLayoutDirection
                            )
                            .datePickerStyle(.compact)

                            Text(
                                tr(
                                    "תקבל התראה יומית עם אפשרות לפתוח כרטיס תרגיל, לשמור למועדפים ולקבל תרגיל נוסף.",
                                    "You will receive a daily reminder with options to open the exercise card, save it to favorites, and get another exercise."
                                )
                            )
                            .kmiFont(
                                size: 10.5,
                                weight: .semibold
                            )
                            .foregroundStyle(settingsSecondaryTextColor)
                            .frame(
                                maxWidth: .infinity,
                                alignment: horizontalTextAlignment
                            )
                            .multilineTextAlignment(
                                primaryTextAlignment
                            )
                        }
                    }
                }

                SettingsListDivider()

                SettingsListItem(
                    title: tr("תזכורות אימונים חופשיים", "Free training reminders"),
                    value: freeSessionsRemindersEnabled ? tr("פעיל", "On") : tr("כבוי", "Off"),
                    systemImage: "bell.fill",
                    tint: Color(hex: 0xFF16A34A),
                    isEnglish: isEnglish
                ) {
                    HStack(spacing: 12) {
                        Text(
                            tr(
                                "הפעל או כבה תזכורות לאימונים חופשיים.",
                                "Enable or disable free training reminders."
                            )
                        )
                        .kmiFont(
                            size: 11,
                            weight: .semibold
                        )
                        .foregroundStyle(settingsSecondaryTextColor)
                        .frame(
                            maxWidth: .infinity,
                            alignment: horizontalTextAlignment
                        )
                        .multilineTextAlignment(
                            primaryTextAlignment
                        )

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
                }

                SettingsListDivider()

                SettingsListItem(
                    title: tr("סנכרון ליומן במכשיר", "Device calendar sync"),
                    value: selectedCalendarSyncEnabled
                    ? (
                        selectedCalendarDisplay.isEmpty
                        ? tr("מסוכרן", "Synced")
                        : tr("מסוכרן: \(selectedCalendarDisplay)", "Synced: \(selectedCalendarDisplay)")
                    )
                    : tr("לא מסוכרן", "Not synced"),
                    systemImage: "calendar",
                    tint: Color(hex: 0xFF0284C7),
                    isEnglish: isEnglish,
                    bottomRounded: true
                ) {
                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            Text(
                                tr(
                                    "סנכרן ליומן חיצוני",
                                    "Sync to external calendar"
                                )
                            )
                            .kmiFont(
                                size: 12.5,
                                weight: .heavy
                            )
                            .foregroundStyle(
                                settingsPrimaryTextColor
                            )
                            .frame(
                                maxWidth: .infinity,
                                alignment: horizontalTextAlignment
                            )
                            .multilineTextAlignment(
                                primaryTextAlignment
                            )

                            Toggle(
                                tr(
                                    "סנכרון ליומן במכשיר",
                                    "Device calendar sync"
                                ),
                                isOn: Binding(
                                    get: { selectedCalendarSyncEnabled },
                                    set: { newValue in
                                        guard !isBusy else {
                                            return
                                        }

                                        if newValue {
                                            enableSelectedCalendarSync()
                                        } else {
                                            feedbackTap()
                                            removeCalendarEvents()
                                        }
                                    }
                                )
                            )
                            .labelsHidden()
                            .tint(
                                KmiAppTheme.primary(for: colorScheme)
                            )
                            .disabled(isBusy)
                        }

                        Text(
                            tr(
                                "בחר יומן יעד לסנכרון האימונים במכשיר.",
                                "Choose a target calendar for syncing training sessions on this device."
                            )
                        )
                        .kmiFont(
                            size: 10.5,
                            weight: .semibold
                        )
                        .foregroundStyle(settingsSecondaryTextColor)
                        .frame(
                            maxWidth: .infinity,
                            alignment: horizontalTextAlignment
                        )
                        .multilineTextAlignment(
                            primaryTextAlignment
                        )

                        SettingsPickerLikeButton(
                            title: tr("בחר יומן יעד", "Choose target calendar"),
                            subtitle: selectedCalendarIdentifier.isEmpty || selectedCalendarDisplay.isEmpty
                            ? tr("עדיין לא נבחר יומן", "No calendar selected yet")
                            : selectedCalendarDisplay,
                            systemImage: "calendar.badge.plus",
                            tint: Color(hex: 0xFF0284C7),
                            isEnglish: isEnglish
                        ) {
                            openCalendarPicker()
                            feedbackTap()
                        }
                    }
                }
            }

            SettingsListSection(
                title: tr("ממשק, קול ואבטחה", "Interface, voice and security"),
                subtitle: tr(
                    "חוויית משתמש, קול, נראות ונעילת אפליקציה",
                    "User experience, voice, appearance and app lock"
                ),
                systemImage: "paintpalette.fill",
                tint: sectionIconTint,
                isEnglish: isEnglish
            ) {
                SettingsListItem(
                    title: tr("חוויית משתמש", "User experience"),
                    value: tr("צלילים ורטט", "Sounds and haptics"),
                    systemImage: "slider.horizontal.3",
                    tint: Color(hex: 0xFF7C3AED),
                    isEnglish: isEnglish,
                    topRounded: true
                ) {
                    VStack(spacing: 10) {
                        SettingsPremiumToggleRow(
                            title: tr("צליל הקשה בכפתורים", "Button tap sound"),
                            subtitle: tr("השמעת צליל קצר בעת לחיצה על כפתורים.", "Play a short sound when tapping buttons."),
                            systemImage: "speaker.wave.2.fill",
                            tint: Color(hex: 0xFF7C3AED),
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
                            tint: Color(hex: 0xFF7C3AED),
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

                SettingsListDivider()

                SettingsListItem(
                    title: tr("הגדרות קול", "Voice settings"),
                    value: cloudVoice == "female" ? tr("קול אישה", "Female voice") : tr("קול גבר", "Male voice"),
                    systemImage: "person.wave.2.fill",
                    tint: Color(hex: 0xFF0284C7),
                    isEnglish: isEnglish
                ) {
                    VStack(spacing: 8) {
                        Text(tr("בחר קול להשמעה:", "Choose voice playback:"))
                            .kmiFont(size: 11, weight: .semibold)
                            .foregroundStyle(settingsSecondaryTextColor)
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

                        Text(
                            tr(
                                "הבחירה נשמרת למכשיר ותשפיע על הדיבור בעוזר הקולי.",
                                "The selection is saved on the device and affects speech in the voice assistant."
                            )
                        )
                        .kmiFont(size: 10.5, weight: .semibold)
                        .foregroundStyle(settingsSecondaryTextColor)
                        .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                        .multilineTextAlignment(primaryTextAlignment)
                    }
                }

                SettingsListDivider()

                SettingsListItem(
                    title: tr("נראות אפליקציה", "App appearance"),
                    value: themeDisplayName(),
                    systemImage: "paintpalette.fill",
                    tint: Color(hex: 0xFFD97706),
                    isEnglish: isEnglish
                ) {
                    VStack(spacing: 8) {
                        Text(tr("בחר מצב תצוגה:", "Choose display mode:"))
                            .kmiFont(size: 11, weight: .semibold)
                            .foregroundStyle(settingsSecondaryTextColor)
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
                }

                SettingsListDivider()

                SettingsListItem(
                    title: tr("נעילת אפליקציה", "App lock"),
                    value: appLockMode == "biometric" ? tr("נעילה ביומטרית", "Biometric lock") : tr("ללא נעילה", "No lock"),
                    systemImage: "lock.fill",
                    tint: Color(hex: 0xFFE11D48),
                    isEnglish: isEnglish,
                    bottomRounded: true
                ) {
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

                        if !biometricAvailable() {
                            Text(
                                tr(
                                    "ביומטרי לא זמין במכשיר או לא הוגדר למשתמש.",
                                    "Biometric authentication is not available or not configured for this user."
                                )
                            )
                            .kmiFont(size: 10.5, weight: .semibold)
                            .foregroundStyle(settingsSecondaryTextColor)
                            .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                            .multilineTextAlignment(primaryTextAlignment)
                        }
                    }
                }
            }

            SettingsListSection(
                title: tr("מידע וניהול", "Info and management"),
                subtitle: tr(
                    "נתונים, מסמכים משפטיים, גרסה ותמיכה",
                    "Data, legal documents, version and support"
                ),
                systemImage: "internaldrive.fill",
                tint: sectionIconTint,
                isEnglish: isEnglish
            ) {
                SettingsListItem(
                    title: tr("סטטיסטיקות", "Statistics"),
                    value: tr("התקדמות לפי חגורות ונושאים", "Progress by belts and topics"),
                    systemImage: "chart.bar.fill",
                    tint: Color(hex: 0xFF0F766E),
                    isEnglish: isEnglish,
                    topRounded: true
                ) {
                    VStack(spacing: 10) {
                        Text(
                            tr(
                                "ההתקדמות מחושבת לפי סימוני יודע / לחזרה ששמרת במסכי החומר והתרגול.",
                                "Progress is calculated from the known / review marks saved in the material and practice screens."
                            )
                        )
                        .kmiFont(size: 10.5, weight: .semibold)
                        .foregroundStyle(settingsSecondaryTextColor)
                        .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                        .multilineTextAlignment(primaryTextAlignment)

                        BeltsProgressBarsIOS(rows: beltProgressRowsFromDefaults())
                    }
                }

                SettingsListDivider()

                SettingsListItem(
                    title: tr("ניהול נתונים", "Data management"),
                    value: tr("מטמון והיסטוריית שידורים", "Cache and broadcast history"),
                    systemImage: "internaldrive.fill",
                    tint: Color(hex: 0xFF0F766E),
                    isEnglish: isEnglish
                ) {
                    VStack(spacing: 8) {
                        SettingsPremiumActionButton(
                            title: tr("נקה היסטוריית שידורים", "Clear broadcast history"),
                            subtitle: tr("מוחק רק רשימת שידורים אחרונים", "Clears only recent broadcasts"),
                            systemImage: "megaphone.fill",
                            tint: Color(hex: 0xFF0F766E),
                            isDestructive: false
                        ) {
                            feedbackTap()
                            showClearBroadcastHistoryConfirm = true
                        }

                        SettingsPremiumActionButton(
                            title: tr("נקה מטמון אפליקציה", "Clear app cache"),
                            subtitle: tr("לא מוחק חשבון או הרשמה", "Does not delete account or registration"),
                            systemImage: "trash.fill",
                            tint: Color(hex: 0xFFE11D48),
                            isDestructive: true
                        ) {
                            feedbackTap()
                            showClearCacheConfirm = true
                        }
                    }
                }

                SettingsListDivider()

                SettingsListItem(
                    title: tr("מידע משפטי", "Legal information"),
                    value: tr("פרטיות, תנאים ונגישות", "Privacy, terms and accessibility"),
                    systemImage: "scale.3d",
                    tint: Color(hex: 0xFF7C3AED),
                    isEnglish: isEnglish
                ) {
                    VStack(spacing: 8) {
                        SettingsPremiumActionButton(
                            title: tr("מדיניות פרטיות", "Privacy policy"),
                            subtitle: nil,
                            systemImage: "lock.fill",
                            tint: Color(hex: 0xFF7C3AED),
                            isDestructive: false
                        ) {
                            legalInitialTab = 1
                            goLegal = true
                            feedbackTap()
                        }

                        SettingsPremiumActionButton(
                            title: tr("תנאי שימוש", "Terms of use"),
                            subtitle: nil,
                            systemImage: "hammer.fill",
                            tint: Color(hex: 0xFF7C3AED),
                            isDestructive: false
                        ) {
                            legalInitialTab = 0
                            goLegal = true
                            feedbackTap()
                        }

                        SettingsPremiumActionButton(
                            title: tr("הצהרת נגישות", "Accessibility statement"),
                            subtitle: nil,
                            systemImage: "figure.stand",
                            tint: Color(hex: 0xFF7C3AED),
                            isDestructive: false
                        ) {
                            legalInitialTab = 2
                            goLegal = true
                            feedbackTap()
                        }
                    }
                }

                SettingsListDivider()

                SettingsListItem(
                    title: tr("אודות ותמיכה", "About and support"),
                    value: tr("גרסה, משוב ושיתוף", "Version, feedback and sharing"),
                    systemImage: "headphones.circle.fill",
                    tint: Color(hex: 0xFF0284C7),
                    isEnglish: isEnglish,
                    bottomRounded: true
                ) {
                    VStack(spacing: 8) {
                        Text(appVersionLine())
                            .kmiFont(size: 10.5, weight: .semibold)
                            .foregroundStyle(settingsSecondaryTextColor)
                            .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                            .multilineTextAlignment(primaryTextAlignment)

                        HStack(spacing: 8) {
                            SettingsPremiumActionButton(
                                title: tr("שלח משוב", "Send feedback"),
                                subtitle: nil,
                                systemImage: "envelope.fill",
                                tint: Color(hex: 0xFF0284C7),
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
                            tint: Color(hex: 0xFF0284C7),
                            isDestructive: false
                        ) {
                            shareApp()
                            hapticSuccess()
                        }
                    }
                }
            }
        }
    }

    private struct SettingsListSection<Content: View>: View {
        let title: String
        let subtitle: String?
        let systemImage: String
        let tint: Color
        let isEnglish: Bool
        @ViewBuilder let content: () -> Content

        @Environment(\.colorScheme) private var colorScheme

        private var isDarkMode: Bool {
            colorScheme == .dark
        }

        private var primaryTextColor: Color {
            KmiAppTheme.onSurface(for: colorScheme)
        }

        private var secondaryTextColor: Color {
            KmiAppTheme.onSurfaceVariant(for: colorScheme)
        }

        private var textAlignment: TextAlignment {
            isEnglish ? .leading : .trailing
        }

        private var frameAlignment: Alignment {
            isEnglish ? .leading : .trailing
        }

        var body: some View {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    if isEnglish {
                        iconBubble
                        titleBlock
                    } else {
                        titleBlock
                        iconBubble
                    }
                }
                .environment(\.layoutDirection, .leftToRight)

                VStack(spacing: 0) {
                    content()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(KmiAppTheme.surface(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        KmiAppTheme.outlineVariant(for: colorScheme),
                        lineWidth: 1
                    )
            )
        }

        private var iconBubble: some View {
            Image(systemName: systemImage)
                .kmiFont(size: KmiIconSize.small, weight: .black)
                .foregroundStyle(tint)
                .frame(minWidth: 34, minHeight: 34)
                .background(
                    RoundedRectangle(
                        cornerRadius: 13,
                        style: .continuous
                    )
                    .fill(
                        KmiAppTheme.primary(for: colorScheme)
                            .opacity(0.12)
                    )
                )
                .accessibilityHidden(true)
        }

        private var titleBlock: some View {
            VStack(
                alignment: isEnglish ? .leading : .trailing,
                spacing: 3
            ) {
                Text(title)
                    .kmiTypography(.cardTitle)
                    .foregroundStyle(primaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .kmiTypography(.secondary)
                        .foregroundStyle(secondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                        .multilineTextAlignment(textAlignment)
                }
            }
        }
    }

    private struct SettingsListDivider: View {
        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            Rectangle()
                .fill(
                    KmiAppTheme.outlineVariant(for: colorScheme)
                )
                .frame(height: 0.7)
                .padding(.horizontal, 12)
        }
    }

    private struct SettingsListItem<Content: View>: View {
        let title: String
        let value: String
        let systemImage: String
        let tint: Color
        let isEnglish: Bool
        var topRounded: Bool = false
        var bottomRounded: Bool = false
        @ViewBuilder let content: () -> Content

        @Environment(\.colorScheme) private var colorScheme
        @State private var expanded: Bool = false

        private var isDarkMode: Bool {
            colorScheme == .dark
        }

        private var primaryTextColor: Color {
            KmiAppTheme.onSurface(for: colorScheme)
        }

        private var secondaryTextColor: Color {
            KmiAppTheme.onSurfaceVariant(for: colorScheme)
        }

        private var rowShape: RoundedRectangle {
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        }

        private var effectiveRowShape: UnevenRoundedRectangle {
            UnevenRoundedRectangle(
                topLeadingRadius: topRounded ? 18 : 0,
                bottomLeadingRadius: (!expanded && bottomRounded) ? 18 : 0,
                bottomTrailingRadius: (!expanded && bottomRounded) ? 18 : 0,
                topTrailingRadius: topRounded ? 18 : 0,
                style: .continuous
            )
        }

        private var expandedShape: UnevenRoundedRectangle {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: bottomRounded ? 18 : 0,
                bottomTrailingRadius: bottomRounded ? 18 : 0,
                topTrailingRadius: 0,
                style: .continuous
            )
        }

        private var textAlignment: TextAlignment {
            isEnglish ? .leading : .trailing
        }

        private var frameAlignment: Alignment {
            isEnglish ? .leading : .trailing
        }

        var body: some View {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        expanded.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        if isEnglish {
                            iconBubble
                            textBlock

                            Image(
                                systemName: expanded
                                    ? "chevron.up"
                                    : "chevron.down"
                            )
                            .kmiFont(
                                size: KmiIconSize.tiny,
                                weight: .black
                            )
                            .foregroundStyle(
                                KmiAppTheme.onSurfaceVariant(
                                    for: colorScheme
                                )
                            )
                            .frame(minWidth: 20)
                            .accessibilityHidden(true)
                        } else {
                            Image(
                                systemName: expanded
                                    ? "chevron.up"
                                    : "chevron.down"
                            )
                            .kmiFont(
                                size: KmiIconSize.tiny,
                                weight: .black
                            )
                            .foregroundStyle(
                                KmiAppTheme.onSurfaceVariant(
                                    for: colorScheme
                                )
                            )
                            .frame(minWidth: 20)
                            .accessibilityHidden(true)

                            textBlock
                            iconBubble
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        KmiAppTheme.surfaceVariant(for: colorScheme)
                    )
                    .clipShape(effectiveRowShape)
                }
                .buttonStyle(.plain)
                .environment(\.layoutDirection, .leftToRight)

                if expanded {
                    Rectangle()
                        .fill(
                            KmiAppTheme.outlineVariant(for: colorScheme)
                        )
                        .frame(height: 0.7)
                        .padding(.horizontal, 18)

                    VStack(spacing: 9) {
                        content()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity)
                    .background(
                        KmiAppTheme.surface(for: colorScheme)
                    )
                    .clipShape(expandedShape)
                }
            }
        }

        private var iconBubble: some View {
            Image(systemName: systemImage)
                .kmiFont(size: KmiIconSize.small, weight: .black)
                .foregroundStyle(tint)
                .frame(minWidth: 34, minHeight: 34)
                .background(
                    RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
                    .fill(
                        KmiAppTheme.primary(for: colorScheme)
                            .opacity(0.12)
                    )
                )
                .accessibilityHidden(true)
        }

        private var textBlock: some View {
            VStack(
                alignment: isEnglish ? .leading : .trailing,
                spacing: 3
            ) {
                Text(title)
                    .kmiTypography(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(primaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)

                if !value.isEmpty {
                    Text(value)
                        .kmiTypography(.caption)
                        .foregroundStyle(secondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                        .multilineTextAlignment(textAlignment)
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
                        .kmiFont(size: KmiIconSize.tiny, weight: .black)

                    Text(title)
                        .kmiFont(size: 11.5, weight: .black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                } else {
                    Text(title)
                        .kmiFont(size: 11.5, weight: .black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Image(systemName: systemImage)
                        .kmiFont(size: KmiIconSize.tiny, weight: .black)
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

        @Environment(\.colorScheme)
        private var colorScheme

        private var effectiveTint: Color {
            isDestructive
                ? KmiAppTheme.error(for: colorScheme)
                : tint
        }

        private var contentColor: Color {
            isDestructive
                ? KmiAppTheme.onError(for: colorScheme)
                : .white
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
                        .kmiFont(
                            size: KmiIconSize.small,
                            weight: .black
                        )
                        .frame(minWidth: 24)
                        .accessibilityHidden(true)

                    VStack(spacing: 3) {
                        Text(title)
                            .kmiTypography(.action)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(textAlignment)

                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .kmiTypography(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(textAlignment)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .foregroundStyle(contentColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(
                    maxWidth: .infinity,
                    minHeight: subtitle == nil ? 48 : 58
                )
                .background(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                    .fill(effectiveTint)
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                    .strokeBorder(
                        contentColor.opacity(0.22),
                        lineWidth: 1
                    )
                )
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

        @Environment(\.colorScheme) private var colorScheme

        private var isDarkMode: Bool {
            colorScheme == .dark
        }

        private var primaryTextColor: Color {
            isDarkMode
                ? Color.white.opacity(0.94)
                : Color(hex: 0xFF111827)
        }

        private var secondaryTextColor: Color {
            isDarkMode
                ? Color.white.opacity(0.64)
                : Color(hex: 0xFF64748B)
        }

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
                    .fill(KmiAppTheme.surface(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isOn
                            ? KmiAppTheme.primary(for: colorScheme)
                                .opacity(0.45)
                            : KmiAppTheme.outlineVariant(for: colorScheme),
                        lineWidth: 1
                    )
            )
            .environment(\.layoutDirection, .leftToRight)
        }

        private var iconBubble: some View {
            ZStack {
                Circle()
                    .fill(tint.opacity(isOn ? 0.16 : 0.09))
                    .frame(width: 40, height: 40)

                Image(systemName: systemImage)
                    .kmiFont(size: KmiIconSize.small, weight: .black)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
        }

        private var textBlock: some View {
            VStack(alignment: isEnglish ? .leading : .trailing, spacing: 4) {
                Text(title)
                    .kmiFont(size: 15.5, weight: .black)
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .multilineTextAlignment(textAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)

                Text(subtitle)
                    .kmiTypography(.secondary)
                    .foregroundStyle(secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(textAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
        }

        private var toggleView: some View {
            Toggle(
                title,
                isOn: Binding(
                    get: { isOn },
                    set: { newValue in
                        isOn = newValue
                        onChange(newValue)
                    }
                )
            )
            .labelsHidden()
            .tint(KmiAppTheme.primary(for: colorScheme))
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
                        .kmiFont(size: KmiIconSize.tiny, weight: .black)

                    Text(title)
                        .kmiFont(size: 12, weight: .heavy)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                } else {
                    Text(title)
                        .kmiFont(size: 12, weight: .heavy)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Image(systemName: systemImage)
                        .kmiFont(size: KmiIconSize.tiny, weight: .black)
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

        @Environment(\.colorScheme) private var colorScheme
        @State private var pressed: Bool = false

        private var isDarkMode: Bool {
            colorScheme == .dark
        }

        private var primaryTextColor: Color {
            isDarkMode
                ? Color.white.opacity(0.94)
                : Color(hex: 0xFF111827)
        }

        private var secondaryTextColor: Color {
            isDarkMode
                ? Color.white.opacity(0.64)
                : Color(hex: 0xFF64748B)
        }

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
                            .kmiFont(size: KmiIconSize.tiny, weight: .black)
                            .foregroundStyle(
                                KmiAppTheme.onSurfaceVariant(for: colorScheme)
                            )
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: "chevron.left")
                            .kmiFont(size: KmiIconSize.tiny, weight: .black)
                            .foregroundStyle(
                                KmiAppTheme.onSurfaceVariant(for: colorScheme)
                            )
                            .accessibilityHidden(true)

                        textBlock

                        iconBubble
                    }
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 58)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            isDarkMode
                                ? Color(hex: 0xFF1E293B).opacity(0.94)
                                : Color.white.opacity(0.94)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(0.18), lineWidth: 1)
                )
                .shadow(
                    color: isDarkMode
                        ? Color.black.opacity(0.22)
                        : tint.opacity(0.08),
                    radius: 8,
                    x: 0,
                    y: 4
                )
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
                    .kmiFont(size: KmiIconSize.small, weight: .black)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
        }

        private var textBlock: some View {
            VStack(alignment: isEnglish ? .leading : .trailing, spacing: 3) {
                Text(title)
                    .kmiTypography(.cardTitle)
                    .foregroundStyle(primaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(textAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .kmiTypography(.secondary)
                        .foregroundStyle(secondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
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

        @Environment(\.colorScheme) private var colorScheme
        @State private var pressed: Bool = false

        private var fillColor: Color {
            isPrimary
                ? KmiAppTheme.primary(for: colorScheme)
                : KmiAppTheme.surfaceVariant(for: colorScheme)
        }

        private var textColor: Color {
            isPrimary
                ? KmiAppTheme.onPrimary(for: colorScheme)
                : KmiAppTheme.primary(for: colorScheme)
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
                        .kmiFont(
                            size: KmiIconSize.tiny,
                            weight: .black
                        )
                        .accessibilityHidden(true)

                    Text(title)
                        .kmiTypography(.action)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(textColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                    .fill(fillColor)
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                    .strokeBorder(
                        KmiAppTheme.outlineVariant(for: colorScheme),
                        lineWidth: 1
                    )
                )
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
    
    private func formatTrainingLeadTime(_ totalMinutes: Int) -> String {
        let safeMinutes = totalMinutes > 0 ? totalMinutes : 60
        let hours = safeMinutes / 60
        let minutes = safeMinutes % 60

        if isEnglish {
            if hours > 0 && minutes > 0 {
                return "\(hours) h \(minutes) min before training"
            }

            if hours > 0 {
                return "\(hours) h before training"
            }

            return "\(minutes) min before training"
        }

        if hours > 0 && minutes > 0 {
            return "\(hours) שעה ו־\(minutes) דקות לפני האימון"
        }

        if hours > 0 {
            return "\(hours) שעה לפני האימון"
        }

        return "\(minutes) דקות לפני האימון"
    }

    private func openTrainingLeadPicker() {
        let safeMinutes = trainingReminderMinutes > 0 ? trainingReminderMinutes : 60
        tempTrainingLeadHours = min(max(safeMinutes / 60, 0), 6)
        tempTrainingLeadMinutes = min(max(safeMinutes % 60, 0), 59)
        showTrainingLeadPicker = true
    }

    private func saveTrainingLeadFromPicker() {
        let totalMinutes = (min(max(tempTrainingLeadHours, 0), 6) * 60) + min(max(tempTrainingLeadMinutes, 0), 59)
        let lead = totalMinutes > 0 ? totalMinutes : 60

        trainingReminderMinutes = lead
        UserDefaults.standard.set(lead, forKey: "training_reminder_minutes")
        UserDefaults.standard.set(lead, forKey: "lead_minutes")

        scheduleTrainingReminders(minutes: lead)

        showTrainingLeadPicker = false
        toast(
            tr(
                "זמן התזכורת נשמר: \(formatTrainingLeadTime(lead))",
                "Reminder time saved: \(formatTrainingLeadTime(lead))"
            )
        )
        feedbackTap()
    }

    private var trainingLeadPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text(
                            tr(
                                "בחירת זמן לפני האימון",
                                "Choose reminder time before training"
                            )
                        )
                        .kmiTypography(.sectionTitle)
                        .fixedSize(horizontal: false, vertical: true)

                        Text(
                            tr(
                                "בחר שעות ודקות. לדוגמה: שעה ו־18 דקות.",
                                "Choose hours and minutes. For example: 1 hour and 18 minutes."
                            )
                        )
                        .kmiTypography(.body)
                        .fixedSize(horizontal: false, vertical: true)

                        Text(
                            formatTrainingLeadTime(
                                (tempTrainingLeadHours * 60)
                                    + tempTrainingLeadMinutes
                            )
                        )
                        .kmiTypography(.cardTitle)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(
                        KmiAppTheme.sectionHeaderContentColor
                    )
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(KmiAppTheme.sectionHeaderBrush)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 20,
                            style: .continuous
                        )
                    )

                    HStack(spacing: 12) {
                        trainingLeadWheel(
                            title: tr("שעות", "Hours"),
                            range: 0...6,
                            selection: $tempTrainingLeadHours
                        )

                        trainingLeadWheel(
                            title: tr("דקות", "Minutes"),
                            range: 0...59,
                            selection: $tempTrainingLeadMinutes
                        )
                    }
                }
                .padding(16)
            }
            .background(BeltTopicsGradientBackground())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack(spacing: 12) {
                    Button {
                        showTrainingLeadPicker = false
                    } label: {
                        Text(tr("ביטול", "Cancel"))
                            .kmiTypography(.action)
                            .foregroundStyle(
                                KmiAppTheme.primary(for: colorScheme)
                            )
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: 16,
                                    style: .continuous
                                )
                                .fill(
                                    KmiAppTheme.surfaceVariant(
                                        for: colorScheme
                                    )
                                )
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        saveTrainingLeadFromPicker()
                    } label: {
                        Text(tr("שמירה", "Save"))
                            .kmiTypography(.action)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: 16,
                                    style: .continuous
                                )
                                .fill(KmiAppTheme.graniteActionBrush)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    KmiAppTheme.surface(for: colorScheme)
                        .ignoresSafeArea(edges: .bottom)
                )
            }
            .environment(
                \.layoutDirection,
                settingsLayoutDirection
            )
        }
    }

    private func trainingLeadWheel(
        title: String,
        range: ClosedRange<Int>,
        selection: Binding<Int>
    ) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .kmiFont(size: 15, weight: .black)
                .foregroundStyle(settingsPrimaryTextColor)

            Picker(title, selection: selection) {
                ForEach(Array(range), id: \.self) { value in
                    Text("\(value)")
                        .kmiFont(size: 17, weight: .semibold)
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)
            .clipped()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .fill(KmiAppTheme.surface(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .strokeBorder(
                KmiAppTheme.outlineVariant(for: colorScheme),
                lineWidth: 1
            )
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
                                .kmiFont(
                                    size: KmiIconSize.extraLarge,
                                    weight: .bold
                                )
                                .foregroundStyle(sectionIconTint)
                                .accessibilityHidden(true)
                        }

                        Text(tr("לא נמצאו יומנים זמינים", "No calendars found"))
                            .kmiFont(size: 20, weight: .black)
                            .foregroundStyle(settingsPrimaryTextColor)
                            .multilineTextAlignment(.center)

                        Text(tr("לא נמצאו יומנים זמינים לכתיבה במכשיר.", "No writable calendars were found on this device."))
                            .kmiFont(size: 14, weight: .semibold)
                            .foregroundStyle(settingsSecondaryTextColor)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BeltTopicsGradientBackground())
            .navigationTitle(
                tr("בחר יומן לסנכרון", "Choose calendar for sync")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("ביטול", "Cancel")) {
                        showCalendarPicker = false
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("שמור", "Save")) {
                        saveSelectedCalendarFromPicker()
                    }
                    .disabled(
                        !availableWritableCalendars.contains {
                            $0.calendarIdentifier
                                == tempSelectedCalendarIdentifier
                        }
                    )
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
                calendarPickerCheckmark(calendar)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        calendar.title.isEmpty
                            ? tr("יומן ללא שם", "Unnamed calendar")
                            : calendar.title
                    )
                    .kmiFont(size: 16, weight: .heavy)
                    .foregroundStyle(settingsPrimaryTextColor)

                    Text(calendar.source.title)
                        .kmiFont(size: 12.5, weight: .semibold)
                        .foregroundStyle(settingsSecondaryTextColor)
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        selected
                            ? KmiAppTheme.surfaceVariant(for: colorScheme)
                            : KmiAppTheme.surface(for: colorScheme)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        selected
                            ? KmiAppTheme.primary(for: colorScheme)
                            : KmiAppTheme.outlineVariant(for: colorScheme),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func calendarPickerCheckmark(_ calendar: EKCalendar) -> some View {
        let isSelected =
            tempSelectedCalendarIdentifier == calendar.calendarIdentifier

        return Image(
            systemName: isSelected
                ? "largecircle.fill.circle"
                : "circle"
        )
        .kmiFont(
            size: KmiIconSize.medium,
            weight: .semibold
        )
        .foregroundStyle(
            isSelected
                ? KmiAppTheme.primary(for: colorScheme)
                : KmiAppTheme.onSurfaceVariant(for: colorScheme)
        )
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

                let savedCalendarIsAvailable =
                    availableWritableCalendars.contains {
                        $0.calendarIdentifier == selectedCalendarIdentifier
                    }

                tempSelectedCalendarIdentifier =
                    savedCalendarIsAvailable
                    ? selectedCalendarIdentifier
                    : (availableWritableCalendars.first?.calendarIdentifier ?? "")

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
                feedbackTap()

                ensureCalendarPermissionsAndSync()
            }
        }
    }

    private func requestCalendarAccessIfNeeded(
        _ completion: @escaping (Bool) -> Void
    ) {
        let store = EKEventStore()
        let status = EKEventStore.authorizationStatus(for: .event)

        if #available(iOS 17.0, *) {
            switch status {
            case .fullAccess:
                completion(true)

            case .notDetermined, .writeOnly:
                store.requestFullAccessToEvents { granted, _ in
                    DispatchQueue.main.async {
                        completion(granted)
                    }
                }

            default:
                completion(false)
            }
        } else {
            switch status {
            case .authorized:
                completion(true)

            case .notDetermined:
                store.requestAccess(to: .event) { granted, _ in
                    DispatchQueue.main.async {
                        completion(granted)
                    }
                }

            default:
                completion(false)
            }
        }
    }
    
    private func saveAllSettingsAndExit() {
        guard !isBusy else { return }

        UserDefaults.standard.set(kmiAppLanguageCode, forKey: "kmi_app_language")
        UserDefaults.standard.set(selectedLanguageCode, forKey: "selected_language_code")
        UserDefaults.standard.set(appLanguageRaw, forKey: "app_language")
        UserDefaults.standard.set(initialLanguageCode, forKey: "initial_language_code")

        UserDefaults.standard.set(trainingRemindersEnabled, forKey: "training_reminders_enabled")
        UserDefaults.standard.set(trainingReminderMinutes, forKey: "training_reminder_minutes")
        UserDefaults.standard.set(trainingReminderMinutes, forKey: "lead_minutes")

        UserDefaults.standard.set(dailyReminderEnabledTrainee, forKey: "daily_exercise_reminder_enabled_trainee")
        UserDefaults.standard.set(dailyReminderEnabledCoach, forKey: "daily_exercise_reminder_enabled_coach")
        UserDefaults.standard.set(dailyReminderHour, forKey: "daily_exercise_reminder_hour")
        UserDefaults.standard.set(dailyReminderMinute, forKey: "daily_exercise_reminder_minute")

        UserDefaults.standard.set(freeSessionsRemindersEnabled, forKey: "free_sessions_reminders_enabled")
        UserDefaults.standard.set(calendarSyncEnabled, forKey: "calendar_sync_enabled")
        UserDefaults.standard.set(selectedCalendarSyncEnabled, forKey: "calendar_sync_selected_enabled")
        UserDefaults.standard.set(selectedCalendarIdentifier, forKey: "calendar_sync_selected_calendar_id")
        UserDefaults.standard.set(selectedCalendarDisplay, forKey: "calendar_sync_selected_calendar_display")

        UserDefaults.standard.set(clickSounds, forKey: "click_sounds")
        UserDefaults.standard.set(clickSounds, forKey: "tap_sound")
        UserDefaults.standard.set(hapticsOn, forKey: "haptics_on")
        UserDefaults.standard.set(hapticsOn, forKey: "short_haptic")

        UserDefaults.standard.set(cloudVoice, forKey: "voice")
        UserDefaults.standard.set(cloudVoice, forKey: "kmi_tts_voice")

        UserDefaults.standard.set(themeMode, forKey: "theme_mode")
        UserDefaults.standard.set(appLockMode, forKey: "app_lock_mode")

        UserDefaults.standard.synchronize()

        if trainingRemindersEnabled {
            scheduleTrainingReminders(minutes: trainingReminderMinutes)
        } else {
            cancelTrainingReminders()
        }

        if dailyReminderEnabledBinding.wrappedValue {
            DailyReminderScheduler.shared.refreshSchedule()
        } else {
            DailyReminderScheduler.shared.cancelAll()
        }

        hapticSuccess()
        nav.pop()
    }
    
    // MARK: Action buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                guard !isBusy else { return }

                feedbackTap()
                nav.pop()
            } label: {
                Text(tr("סגירה", "Close"))
                    .kmiTypography(.action)
                    .foregroundStyle(
                        KmiAppTheme.primary(for: colorScheme)
                    )
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(
                            cornerRadius: 16,
                            style: .continuous
                        )
                        .fill(
                            KmiAppTheme.surfaceVariant(
                                for: colorScheme
                            )
                        )
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: 16,
                            style: .continuous
                        )
                        .strokeBorder(
                            KmiAppTheme.outlineVariant(
                                for: colorScheme
                            ),
                            lineWidth: 1
                        )
                    )
            }
            .buttonStyle(.plain)

            Button {
                saveAllSettingsAndExit()
            } label: {
                Text(tr("אישור", "Confirm"))
                    .kmiTypography(.action)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(
                            cornerRadius: 16,
                            style: .continuous
                        )
                        .fill(KmiAppTheme.graniteActionBrush)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            KmiAppTheme.surface(for: colorScheme)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(
                    KmiAppTheme.outlineVariant(for: colorScheme)
                )
                .frame(height: 1)
        }
        .environment(
            \.layoutDirection,
            isEnglish ? .leftToRight : .rightToLeft
        )
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
