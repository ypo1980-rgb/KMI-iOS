import SwiftUI
import Foundation
import FirebaseAuth

struct RegisterFormView: View {

    let prefillPhone: String
    let prefillEmail: String
    let initialRole: UserRole
    let screenTitle: String
    let submitTitle: String
    let submittingTitle: String
    let onBack: () -> Void
    let onSubmit: (RegistrationFormState) -> Void
    let onReadMoreTerms: () -> Void

    @State private var s: RegistrationFormState
    @State private var isSubmitting: Bool = false
    @State private var didFinishInitialLoad: Bool = false
    @State private var hasAttemptedSubmit: Bool = false
    @State private var displayedBranchValue: String = ""
    @State private var displayedGroupValue: String = ""

    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("active_branch")
    private var storedActiveBranch: String = ""

    @AppStorage("active_group")
    private var storedActiveGroup: String = ""
    private let israelRegions = [
        "השרון",
        "מרכז",
        "צפון",
        "דרום",
        "ירושלים"
    ]

    private var regions: [String] {
        if isAbroadSelection {
            return TrainingCatalogIOS.abroadRegions()
        }

        return israelRegions
    }

    private var isCurrentRegionAbroad: Bool {
        TrainingCatalogIOS.isAbroadRegion(
            s.region
        )
    }

    private var branchesOptions: [String] {
        let cleanRegion =
            s.region.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanRegion.isEmpty else {
            return []
        }

        return TrainingCatalogIOS.branchesFor(
            region: cleanRegion
        )
    }

    /*
     * כמו באנדרואיד:
     * קבוצות נטענות רק לאחר שנבחר לפחות סניף אחד.
     *
     * אין להציג מראש קבוצות מכל סניפי האזור,
     * משום שהמשתמש עלול לבחור קבוצה שאינה שייכת
     * לסניפים שבחר לאחר מכן.
     */
    private var groupsOptions: [String] {
        if isAbroadSelection ||
            isCurrentRegionAbroad ||
            s.branches.isEmpty {
            return []
        }

        let selectedBranches =
            Array(s.branches)
                .map {
                    $0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                }
                .filter {
                    !$0.isEmpty
                }

        guard !selectedBranches.isEmpty else {
            return []
        }

        return TrainingCatalogIOS.groupsFor(
            branches: selectedBranches
        )
    }

    /*
     * בורר הקבוצות מוצג רק בארץ,
     * לאחר בחירת סניף ורק כאשר נמצאו קבוצות
     * עבור אחד הסניפים שנבחרו.
     */
    private var shouldShowGroupsPicker: Bool {
        !isAbroadSelection &&
        !isCurrentRegionAbroad &&
        !s.branches.isEmpty &&
        !groupsOptions.isEmpty
    }

    private let belts = [
        "לבנה",
        "צהובה",
        "כתומה",
        "ירוקה",
        "כחולה",
        "חומה",
        "שחורה דאן 1",
        "שחורה דאן 2",
        "שחורה דאן 3",
        "שחורה דאן 4",
        "שחורה דאן 5",
        "שחורה דאן 6",
        "שחורה דאן 7",
        "שחורה דאן 8",
        "שחורה דאן 9",
        "שחורה דאן 10"
    ]

    @State private var isAbroadSelection: Bool = false
    @State private var showBranchesSheet = false
    @State private var showGroupsSheet = false

    @AppStorage("kmi_app_language")
    private var kmiAppLanguageCode: String = "he"

    @AppStorage("app_language")
    private var appLanguageRaw: String = "HEBREW"

    @AppStorage("initial_language_code")
    private var initialLanguageCode: String = "HEBREW"

    @AppStorage("selected_language_code")
    private var selectedLanguageCode: String = "he"

    private var effectiveLanguageCode: String {
        let orderedValues = [
            kmiAppLanguageCode,
            selectedLanguageCode,
            appLanguageRaw,
            initialLanguageCode
        ]

        for raw in orderedValues {
            let clean = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            if clean == "he" || clean == "hebrew" || clean == "עברית" {
                return "he"
            }

            if clean == "en" || clean == "english" {
                return "en"
            }
        }

        return "he"
    }

    private var isEnglish: Bool {
        effectiveLanguageCode == "en"
    }

    private var screenLayoutDirection: LayoutDirection {
        isEnglish
            ? .leftToRight
            : .rightToLeft
    }

    /*
     * leading הוא יישור סמנטי:
     * באנגלית הוא שמאל וב־RTL הוא ימין.
     */
    private var formTextAlignment: TextAlignment {
        .leading
    }

    private var formFrameAlignment: Alignment {
        .leading
    }

    private var formHorizontalAlignment: HorizontalAlignment {
        .leading
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private func localizedScreenTitle(_ raw: String) -> String {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isEnglish else {
            return clean
        }

        switch clean {
        case "טופס רישום":
            return "Registration Form"
        case "עריכת פרופיל":
            return "Edit Profile"
        case "רישום מתאמן":
            return "Trainee Registration"
        case "רישום מאמן":
            return "Coach Registration"
        default:
            return clean
        }
    }

    private func localizedSubmitTitle(_ raw: String) -> String {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isEnglish else {
            return clean
        }

        switch clean {
        case "סיום רישום":
            return "Complete Registration"
        case "שמירת שינויים":
            return "Save Changes"
        case "שומר...":
            return "Saving..."
        default:
            return clean
        }
    }

    private func regionDisplayName(_ raw: String) -> String {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isEnglish else {
            return clean
        }

        switch clean {
        case "השרון":
            return "Sharon"
        case "מרכז":
            return "Center"
        case "צפון":
            return "North"
        case "דרום":
            return "South"
        case "ירושלים":
            return "Jerusalem"
        default:
            return clean
        }
    }
    
    private func beltDisplayNameForRegistration(_ raw: String) -> String {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isEnglish else {
            return clean
        }

        switch clean {
        case "לבנה":
            return "White"
        case "צהובה":
            return "Yellow"
        case "כתומה":
            return "Orange"
        case "ירוקה":
            return "Green"
        case "כחולה":
            return "Blue"
        case "חומה":
            return "Brown"
        case "שחורה דאן 1":
            return "Black Dan 1"
        case "שחורה דאן 2":
            return "Black Dan 2"
        case "שחורה דאן 3":
            return "Black Dan 3"
        case "שחורה דאן 4":
            return "Black Dan 4"
        case "שחורה דאן 5":
            return "Black Dan 5"
        case "שחורה דאן 6":
            return "Black Dan 6"
        case "שחורה דאן 7":
            return "Black Dan 7"
        case "שחורה דאן 8":
            return "Black Dan 8"
        case "שחורה דאן 9":
            return "Black Dan 9"
        case "שחורה דאן 10":
            return "Black Dan 10"
        default:
            return clean
        }
    }

    private func beltColorForRegistration(_ raw: String) -> Color {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        switch clean {
        case "לבנה":
            return Color.white

        case "צהובה":
            return Color(
                red: 1.000,
                green: 0.820,
                blue: 0.180
            )

        case "כתומה":
            return Color(
                red: 1.000,
                green: 0.490,
                blue: 0.090
            )

        case "ירוקה":
            return Color(
                red: 0.110,
                green: 0.620,
                blue: 0.320
            )

        case "כחולה":
            return Color(
                red: 0.100,
                green: 0.420,
                blue: 0.850
            )

        case "חומה":
            return Color(
                red: 0.480,
                green: 0.280,
                blue: 0.150
            )

        case "שחורה דאן 1",
             "שחורה דאן 2",
             "שחורה דאן 3",
             "שחורה דאן 4",
             "שחורה דאן 5",
             "שחורה דאן 6",
             "שחורה דאן 7",
             "שחורה דאן 8",
             "שחורה דאן 9",
             "שחורה דאן 10":
            return Color.black

        default:
            return Color.gray
        }
    }

    private func beltNeedsDarkBorderForRegistration(
        _ raw: String
    ) -> Bool {
        raw.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) == "לבנה"
    }
    
    private func groupDisplayNameForRegistration(_ raw: String) -> String {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isEnglish else {
            return clean
        }

        switch clean {
        case "ילדים":
            return "Kids"
        case "נוער":
            return "Teens"
        case "בוגרים":
            return "Adults"
        case "נוער + בוגרים":
            return "Teens + Adults"
        default:
            return clean
        }
    }

    private func displayJoinedValues(
        _ values: [String],
        translateGroupNames: Bool = false
    ) -> String {
        let cleaned = values
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter {
                !$0.isEmpty
            }
            .map {
                translateGroupNames
                    ? groupDisplayNameForRegistration($0)
                    : $0
            }
            .sorted()

        if cleaned.isEmpty {
            return ""
        }

        return cleaned.joined(separator: "\n")
    }

    private var normalizedPhone: String {
        s.phone.filter { $0.isNumber }
    }

    private var normalizedEmail: String {
        s.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isGoogleAuth: Bool {
        let defaults = UserDefaults.standard

        let authProvider =
            defaults.string(forKey: "authProvider") ?? ""

        let googleLogin =
            defaults.bool(forKey: "google_login")

        let skipOtp =
            defaults.bool(forKey: "skip_otp")

        return authProvider == "google" &&
            googleLogin &&
            skipOtp &&
            !prefillEmail
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty
    }

    /*
     * Android מציג שדות חובה חסרים מיד בכניסה
     * באמצעות Google. בהרשמה רגילה הם מוצגים
     * לאחר ניסיון השליחה הראשון.
     */
    private var shouldRevealValidationErrors: Bool {
        isGoogleAuth || hasAttemptedSubmit
    }

    private var showFullNameError: Bool {
        shouldRevealValidationErrors &&
        s.fullName
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .count < 2
    }

    private var showPhoneError: Bool {
        shouldRevealValidationErrors &&
        s.phone.filter { $0.isNumber }.count < 9
    }

    private var showEmailError: Bool {
        shouldRevealValidationErrors &&
        (
            !s.email.contains("@") ||
            !s.email.contains(".")
        )
    }

    private var showUsernameError: Bool {
        shouldRevealValidationErrors &&
        !isGoogleAuth &&
        s.username
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .count < 3
    }

    private var showPasswordError: Bool {
        shouldRevealValidationErrors &&
        !isGoogleAuth &&
        s.password.count < 6
    }

    private var showGenderError: Bool {
        shouldRevealValidationErrors &&
        s.gender
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty
    }

    private var showBirthDayError: Bool {
        guard shouldRevealValidationErrors else {
            return false
        }

        guard let day = Int(s.birthDay) else {
            return true
        }

        return !(1...31).contains(day)
    }

    private var showBirthMonthError: Bool {
        guard shouldRevealValidationErrors else {
            return false
        }

        guard let month = Int(s.birthMonth) else {
            return true
        }

        return !(1...12).contains(month)
    }

    private var showBirthYearError: Bool {
        guard shouldRevealValidationErrors else {
            return false
        }

        guard
            s.birthYear.count == 4,
            let year = Int(s.birthYear)
        else {
            return true
        }

        return !(1900...2100).contains(year)
    }

    private var showRegionError: Bool {
        shouldRevealValidationErrors &&
        s.region
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty
    }

    private var showBranchesError: Bool {
        shouldRevealValidationErrors &&
        s.branches.isEmpty
    }

    private var showGroupsError: Bool {
        shouldRevealValidationErrors &&
        shouldShowGroupsPicker &&
        s.groups.isEmpty
    }

    private var showBeltError: Bool {
        shouldRevealValidationErrors &&
        s.belt
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var registrationFieldBackground: Color {
        isDarkMode
            ? Color(hex: 0xFF1E293B).opacity(0.96)
            : Color.white
    }

    private var registrationFieldTextColor: Color {
        isDarkMode
            ? Color.white.opacity(0.94)
            : Color(hex: 0xFF111827)
    }

    private var registrationFieldBorder: Color {
        isDarkMode
            ? Color.white.opacity(0.18)
            : Color(hex: 0xFFD2C4E3)
    }

    private var registrationErrorBorder: Color {
        isDarkMode
            ? Color(hex: 0xFFF87171)
            : Color(hex: 0xFFE13B3B)
    }

    private var registrationMissingBackground: Color {
        isDarkMode
            ? Color(hex: 0xFF4C1D2A).opacity(0.94)
            : Color(hex: 0xFFFFE4E6)
    }

    private var registrationPrimaryPurple: Color {
        Color(hex: 0xFF7C4DFF)
    }

    private var registrationLabelColor: Color {
        isDarkMode
            ? Color.white.opacity(0.72)
            : Color(hex: 0xFF475569)
    }

    private var displayedBranchesText: String {
        let selectedBranches = Array(s.branches)
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter {
                !$0.isEmpty
            }
            .sorted()

        if !selectedBranches.isEmpty {
            return displayJoinedValues(selectedBranches)
        }

        let manual = s.activeBranch
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !manual.isEmpty {
            return manual
        }

        let persisted = storedActiveBranch
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return persisted
    }

    private var displayedGroupsText: String {
        let selectedGroups = Array(s.groups)
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter {
                !$0.isEmpty
            }
            .sorted()

        if !selectedGroups.isEmpty {
            return displayJoinedValues(
                selectedGroups,
                translateGroupNames: true
            )
        }

        let manual = s.activeGroup
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !manual.isEmpty {
            return groupDisplayNameForRegistration(manual)
        }

        let persisted = storedActiveGroup
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !persisted.isEmpty {
            return groupDisplayNameForRegistration(persisted)
        }

        return ""
    }

    private var isWhitelistedCoach: Bool {
        CoachWhitelist.isWhitelisted(
            phone: normalizedPhone,
            email: normalizedEmail
        )
    }

    private var firebaseUid: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    private var isSuperTester: Bool {
        normalizedEmail == "ypo1980@gmail.com" ||
        normalizedPhone == "0526664660" ||
        firebaseUid == "DBoyoVVpsrVUX0ukhKwNyQlKUKY2"
    }

    /*
     * במסך עריכת פרופיל התפקיד כבר נקבע בזמן ההתחברות.
     * לכן אסור שמנגנון האישור של רישום חדש ידרוס אותו.
     */
    private var isEditingProfile: Bool {
        screenTitle == "עריכת פרופיל" ||
        screenTitle == "Edit Profile"
    }

    init(
        prefillPhone: String = "",
        prefillEmail: String = "",
        initialRole: UserRole = .trainee,
        screenTitle: String = "טופס רישום",
        submitTitle: String = "סיום רישום",
        submittingTitle: String = "שומר...",
        onBack: @escaping () -> Void,
        onSubmit: @escaping (RegistrationFormState) -> Void,
        onReadMoreTerms: @escaping () -> Void = {}
    ) {
        self.prefillPhone = prefillPhone
        self.prefillEmail = prefillEmail
        self.initialRole = initialRole
        self.screenTitle = screenTitle
        self.submitTitle = submitTitle
        self.submittingTitle = submittingTitle
        self.onBack = onBack
        self.onSubmit = onSubmit
        self.onReadMoreTerms = onReadMoreTerms

        var initial = RegistrationFormState()
        initial.phone = prefillPhone
        initial.email = prefillEmail
        initial.role = initialRole
        _s = State(initialValue: initial)
    }
    
    var body: some View {
        registerRootView
            .environment(\.layoutDirection, screenLayoutDirection)
            .sheet(isPresented: $showBranchesSheet) {
                branchesSheet
                    .environment(\.layoutDirection, screenLayoutDirection)
            }
            .sheet(isPresented: $showGroupsSheet) {
                groupsSheet
                    .environment(\.layoutDirection, screenLayoutDirection)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                submitBottomBar
            }
            .onChange(of: s.region) { oldRegion, newRegion in
                handleRegionChange(oldRegion: oldRegion, newRegion: newRegion)
            }
            .onChange(of: s.branches) { _, newBranches in
                handleBranchesChange(newBranches)
            }
            .onChange(of: s.groups) { _, newGroups in
                handleGroupsChange(newGroups)
            }
            .onAppear {
                handleInitialAppear()
            }
            .onChange(of: normalizedPhone) { _, _ in
                applyRoleGate()
            }
            .onChange(of: normalizedEmail) { _, _ in
                applyRoleGate()
            }
    }
    
    private var registerRootView: some View {
        ZStack {
            registrationBackground

            ScrollView {
                registerScrollContent
            }
        }
    }

    private var registrationBackground: some View {
        LinearGradient(
            colors: s.role == .coach
            ? [
                Color(red: 0.078, green: 0.118, blue: 0.188), // #141E30
                Color(red: 0.141, green: 0.231, blue: 0.333), // #243B55
                Color(red: 0.055, green: 0.647, blue: 0.914)  // #0EA5E9
            ]
            : [
                Color(red: 0.498, green: 0.000, blue: 1.000), // #7F00FF
                Color(red: 0.247, green: 0.318, blue: 0.710), // #3F51B5
                Color(red: 0.012, green: 0.663, blue: 0.957)  // #03A9F4
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var registerScrollContent: some View {
        VStack(spacing: 14) {
            roleTabs

            /*
             * המסך מתחיל ישירות בכרטיס הפרטים האישיים.
             * קוד המאמן עדיין נוצר ומוצג לאחר הרשמה מוצלחת.
             */
            personalDetailsSection

            accountSection

            branchSection

            preferencesSection

            Spacer(minLength: 110)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
    }

    private var personalDetailsSection: some View {
        sectionCard(
            title: tr(
                "פרטים אישיים",
                "Personal details"
            )
        ) {
            field(
                title: tr("שם מלא", "Full name"),
                text: $s.fullName,
                showError: showFullNameError
            )

            field(
                title: tr("טלפון", "Phone"),
                text: $s.phone,
                keyboard: .phonePad,
                showError: showPhoneError
            )

            field(
                title: tr("מייל", "Email"),
                text: $s.email,
                keyboard: .emailAddress,
                showError: showEmailError
            )

            Text(tr("מין המשתמש", "Gender"))
                .kmiFont(size: 14, weight: .semibold)
                .foregroundStyle(
                    showGenderError
                        ? registrationErrorBorder
                        : registrationLabelColor
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: formFrameAlignment
                )
                .multilineTextAlignment(formTextAlignment)

            genderPicker

            if showGenderError {
                Text(
                    tr(
                        "חובה לבחור מין",
                        "Please select gender"
                    )
                )
                .kmiFont(size: 12, weight: .semibold)
                .foregroundStyle(registrationErrorBorder)
                .frame(
                    maxWidth: .infinity,
                    alignment: formFrameAlignment
                )
                .multilineTextAlignment(formTextAlignment)
            }

            Text(tr("תאריך לידה", "Date of birth"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(
                    showBirthDayError ||
                    showBirthMonthError ||
                    showBirthYearError
                        ? registrationErrorBorder
                        : registrationLabelColor
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: formFrameAlignment
                )
                .multilineTextAlignment(formTextAlignment)

            dobRow
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        if !isGoogleAuth {
            sectionCard(
                title: tr(
                    "חשבון משתמש",
                    "User account"
                )
            ) {
                field(
                    title: tr(
                        "שם משתמש",
                        "Username"
                    ),
                    text: $s.username,
                    keyboard: .default,
                    showError: showUsernameError
                )

                passwordField
            }
        }
    }

    private var branchSection: some View {
        sectionCard(
            title: tr(
                "שיוך לסניף",
                "Branch assignment"
            )
        ) {
            branchScopePicker

            regionPicker

            multiSelectRow(
                title: isAbroadSelection
                    ? tr(
                        "סניפים בחו״ל",
                        "Branches abroad"
                    )
                    : tr(
                        "סניפים בארץ",
                        "Branches in Israel"
                    ),
                valueText: displayedBranchesText,
                showError: showBranchesError,
                errorMessage: isAbroadSelection
                    ? tr(
                        "חובה לבחור לפחות סניף אחד בחו״ל",
                        "Please select at least one abroad branch"
                    )
                    : tr(
                        "חובה לבחור לפחות סניף אחד",
                        "Please select at least one branch"
                    ),
                onTap: {
                    showBranchesSheet = true
                }
            )

            if shouldShowGroupsPicker {
                multiSelectRow(
                    title: tr(
                        "קבוצות",
                        "Groups"
                    ),
                    valueText: displayedGroupsText,
                    showError: showGroupsError,
                    errorMessage: tr(
                        "חובה לבחור לפחות קבוצה אחת",
                        "Please select at least one group"
                    ),
                    onTap: {
                        showGroupsSheet = true
                    }
                )
            }

            beltPicker
        }
    }

    private var preferencesSection: some View {
        sectionCard(
            title: tr(
                "העדפות ואישורים",
                "Preferences and approvals"
            )
        ) {
            smsConsentRow

            Rectangle()
                .fill(
                    registrationFieldBorder.opacity(0.65)
                )
                .frame(height: 1)

            termsRow
        }
    }

    private var smsConsentRow: some View {
        Button {
            s.wantsSms.toggle()
        } label: {
            HStack(alignment: .center, spacing: 10) {
                if isEnglish {
                    /*
                     * באנגלית הריבוע נמצא בתחילת השורה,
                     * בצד שמאל, כמו ב־Android.
                     */
                    consentCheckbox(
                        isChecked: s.wantsSms
                    )

                    smsConsentText
                } else {
                    /*
                     * בעברית הריבוע נמצא בתחילת השורה
                     * הסמנטית, בצד ימין, כמו ב־Android.
                     */
                    smsConsentText

                    consentCheckbox(
                        isChecked: s.wantsSms
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            /*
             * הסדר כבר נקבע במפורש למעלה.
             * LTR מונע מ־SwiftUI להפוך אותו פעם נוספת.
             */
            .environment(
                \.layoutDirection,
                .leftToRight
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            tr(
                "קבלת עדכונים בהודעות SMS",
                "Receive SMS updates"
            )
        )
        .accessibilityValue(
            s.wantsSms
                ? tr("מסומן", "Checked")
                : tr("לא מסומן", "Not checked")
        )
    }

    private var smsConsentText: some View {
        Text(
            tr(
                "ארצה לקבל עדכונים בהודעות\nSMS לגבי אימונים קרובים",
                "I would like to receive SMS updates\nabout upcoming trainings"
            )
        )
        .font(.system(size: 13, weight: .regular))
        .foregroundStyle(.primary)
        .frame(
            maxWidth: .infinity,
            alignment: formFrameAlignment
        )
        .multilineTextAlignment(formTextAlignment)
        .environment(
            \.layoutDirection,
            screenLayoutDirection
        )
    }

    private var branchesSheet: some View {
        MultiSelectSheet(
            title: isAbroadSelection
                ? tr("בחר סניפים בחו״ל", "Choose branches abroad")
                : tr("בחר סניפים בארץ", "Choose branches in Israel"),
            options: branchesOptions,
            maxSelected: Int.max,
            selected: $s.branches
        )
        .presentationDetents([.medium, .large])
    }

    private var groupsSheet: some View {
        MultiSelectSheet(
            title: tr("בחר קבוצות", "Choose groups"),
            options: groupsOptions,
            maxSelected: Int.max,
            selected: $s.groups
        )
        .presentationDetents([.medium, .large])
    }
    
    private func handleRegionChange(oldRegion: String, newRegion: String) {
        guard didFinishInitialLoad else {
            return
        }

        let oldClean = oldRegion.trimmingCharacters(in: .whitespacesAndNewlines)
        let newClean = newRegion.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !oldClean.isEmpty else {
            return
        }

        guard oldClean != newClean else { return }

        if TrainingCatalogIOS.isAbroadRegion(newClean) {
            isAbroadSelection = true
            s.branchType = "abroad"
        } else if israelRegions.contains(newClean) {
            isAbroadSelection = false
            s.branchType = "israel"
        }

        s.branches.removeAll()
        s.groups.removeAll()
        s.activeBranch = ""
        s.activeGroup = ""
        displayedBranchValue = ""
        displayedGroupValue = ""
        storedActiveBranch = ""
        storedActiveGroup = ""
    }

    private func handleBranchesChange(_ newBranches: Set<String>) {
        if newBranches.isEmpty {
            s.activeBranch = ""
            displayedBranchValue = ""
            storedActiveBranch = ""
            s.groups.removeAll()
            s.activeGroup = ""
            displayedGroupValue = ""
            storedActiveGroup = ""
            return
        }

        let sortedBranches = Array(newBranches)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()

        if sortedBranches.contains(where: { TrainingCatalogIOS.isAbroadBranch($0) }) {
            isAbroadSelection = true
            s.branchType = "abroad"
        } else if !isAbroadSelection {
            s.branchType = "israel"
        }

        if s.activeBranch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !sortedBranches.contains(s.activeBranch) {
            s.activeBranch = sortedBranches.first ?? ""
        }

        displayedBranchValue = s.activeBranch
        storedActiveBranch = s.activeBranch

        if isAbroadSelection || isCurrentRegionAbroad {
            s.groups = ["בוגרים"]
            s.activeGroup = "בוגרים"
            displayedGroupValue = "בוגרים"
            storedActiveGroup = "בוגרים"
            return
        }

        let validGroups = Set(
            TrainingCatalogIOS.groupsFor(
                branches: Array(newBranches)
            )
        )

        s.groups = s.groups.filter { validGroups.contains($0) }

        let sortedGroups = Array(s.groups)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()

        if s.activeGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !sortedGroups.contains(s.activeGroup) {
            s.activeGroup = sortedGroups.first ?? ""
        }

        displayedGroupValue = s.activeGroup
        storedActiveGroup = s.activeGroup
    }

    private func handleGroupsChange(_ newGroups: Set<String>) {
        let sortedGroups = Array(newGroups)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()

        if sortedGroups.isEmpty {
            s.activeGroup = ""
        } else if s.activeGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    !sortedGroups.contains(s.activeGroup) {
            s.activeGroup = sortedGroups.first ?? ""
        }

        displayedGroupValue = s.activeGroup
        storedActiveGroup = s.activeGroup
    }

    private func handleInitialAppear() {
        didFinishInitialLoad = false
        loadSavedProfileIfNeeded()

        if isGoogleAuth {
            if s.email
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty {
                s.email = prefillEmail
            }

            if s.username
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty {
                s.username = prefillEmail
            }

            if s.password
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty {
                s.password = "GOOGLE_AUTH"
            }
        }

        if s.branchType == "abroad" ||
            TrainingCatalogIOS.isAbroadRegion(s.region) ||
            s.branches.contains(
                where: {
                    TrainingCatalogIOS.isAbroadBranch($0)
                }
            ) {
            isAbroadSelection = true
            s.branchType = "abroad"
        } else {
            isAbroadSelection = false
            s.branchType = "israel"
        }

        let defaults = UserDefaults.standard

        let savedBranch = (
            defaults.string(forKey: "active_branch") ??
            defaults.string(forKey: "branch") ??
            defaults.string(forKey: "kmi.user.branch") ??
            ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        let loadedBranches = Set(
            s.branches
                .map {
                    $0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                }
                .filter {
                    !$0.isEmpty
                }
        )

        if loadedBranches.isEmpty {
            if !savedBranch.isEmpty {
                s.branches = [savedBranch]
                s.activeBranch = savedBranch
            }
        } else {
            s.branches = loadedBranches

            let currentActiveBranch = s.activeBranch
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if loadedBranches.contains(currentActiveBranch) {
                s.activeBranch = currentActiveBranch
            } else if loadedBranches.contains(savedBranch) {
                s.activeBranch = savedBranch
            } else {
                s.activeBranch = loadedBranches.sorted().first ?? ""
            }
        }

        displayedBranchValue = displayJoinedValues(
            Array(s.branches)
        )
        storedActiveBranch = s.activeBranch

        let savedGroup = (
            defaults.string(forKey: "active_group") ??
            defaults.string(forKey: "group") ??
            defaults.string(forKey: "kmi.user.group") ??
            ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        let loadedGroups = Set(
            s.groups
                .map {
                    $0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                }
                .filter {
                    !$0.isEmpty
                }
        )

        if loadedGroups.isEmpty {
            if !savedGroup.isEmpty &&
                !isAbroadSelection &&
                !isCurrentRegionAbroad {
                s.groups = [savedGroup]
                s.activeGroup = savedGroup
            }
        } else {
            s.groups = loadedGroups

            let currentActiveGroup = s.activeGroup
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if loadedGroups.contains(currentActiveGroup) {
                s.activeGroup = currentActiveGroup
            } else if loadedGroups.contains(savedGroup) {
                s.activeGroup = savedGroup
            } else {
                s.activeGroup = loadedGroups.sorted().first ?? ""
            }
        }

        displayedGroupValue = displayJoinedValues(
            Array(s.groups),
            translateGroupNames: true
        )
        storedActiveGroup = s.activeGroup

        if s.region
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty ||
            !regions.contains(s.region) {
            s.region = regions.first ?? ""
        }

        s.role = initialRole
        applyRoleGate()

        DispatchQueue.main.async {
            didFinishInitialLoad = true
        }
    }
    
    private func applyRoleGate() {
        /*
         * מנהל האפליקציה רשאי לבחור באופן חופשי
         * בין מצב מתאמן למצב מאמן, גם בעריכת פרופיל.
         */
        if isSuperTester {
            return
        }

        /*
         * אצל משתמש רגיל, בעריכת פרופיל שומרים
         * על התפקיד שהועבר מהפרופיל הפעיל.
         */
        if isEditingProfile {
            s.role = initialRole
            return
        }

        /*
         * ברישום חדש משתמש רגיל מקבל תפקיד
         * בהתאם לרשימת המאמנים המורשים.
         */
        if isWhitelistedCoach {
            s.role = .coach
        } else {
            s.role = .trainee
        }
    }
            
    private var headerBar: some View {
        HStack {
            Button(action: onBack) {
                Text(tr("חזרה", "Back"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.18))
                    .clipShape(
                        RoundedRectangle(cornerRadius: 12)
                    )
            }

            Spacer()

            Text(localizedScreenTitle(screenTitle))
                .font(.title2)
                .bold()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer()

            Color.clear
                .frame(width: 64, height: 1)
        }
        .environment(
            \.layoutDirection,
            screenLayoutDirection
        )
        .padding(.bottom, 6)
    }

    private var roleTabs: some View {
        HStack(spacing: 0) {
            tabButton(.trainee)

            Rectangle()
                .fill(Color.white.opacity(0.45))
                .frame(width: 1, height: 28)

            tabButton(.coach)
        }
        .frame(height: 46)
        .background(
            Color(
                red: 0.427,
                green: 0.310,
                blue: 0.910
            )
            .opacity(0.96)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 0,
                style: .continuous
            )
        )
        .shadow(
            color: Color.black.opacity(0.16),
            radius: 4,
            x: 0,
            y: 2
        )
        .padding(.horizontal, 10)
    }

    private func tabButton(
        _ role: UserRole
    ) -> some View {
        let isSelected = s.role == role

        let title = role == .trainee
            ? tr("מתאמן", "Trainee")
            : tr("מאמן", "Coach")

        return Button {
            /*
             * בעריכת פרופיל משתמש רגיל אינו רשאי
             * לשנות את סוג החשבון.
             * מנהל האפליקציה מוחרג מהנעילה.
             */
            if isEditingProfile && !isSuperTester {
                s.role = initialRole
                return
            }

            /*
             * מגבלת רשימת המאמנים אינה חלה
             * על מנהל האפליקציה.
             */
            if !isSuperTester {
                if role == .coach &&
                    !isWhitelistedCoach {
                    s.role = .trainee
                    return
                }

                if role == .trainee &&
                    isWhitelistedCoach {
                    s.role = .coach
                    return
                }
            }

            s.role = role
        } label: {
            ZStack(alignment: .bottom) {
                Text(title)
                    .font(
                        .system(
                            size: 15,
                            weight: .heavy
                        )
                    )
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )

                if isSelected {
                    RoundedRectangle(
                        cornerRadius: 4,
                        style: .continuous
                    )
                    .fill(Color.white)
                    .frame(width: 82, height: 3)
                }
            }
            .background(
                isSelected
                    ? Color.white.opacity(0.14)
                    : Color.clear
            )
        }
        .buttonStyle(.plain)
    }

    private func sectionCard(
        title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(
            alignment: formHorizontalAlignment,
            spacing: 10
        ) {
            Text(title)
                .kmiFont(size: 15, weight: .bold)
                .foregroundStyle(registrationFieldTextColor)
                .frame(
                    maxWidth: .infinity,
                    alignment: formFrameAlignment
                )
                .multilineTextAlignment(formTextAlignment)

            Rectangle()
                .fill(registrationFieldBorder)
                .frame(height: 1)

            content()
        }
        .frame(
            maxWidth: .infinity,
            alignment: formFrameAlignment
        )
        .environment(
            \.layoutDirection,
            screenLayoutDirection
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(
                isDarkMode
                    ? Color(hex: 0xFF172033).opacity(0.97)
                    : Color(hex: 0xFFF5EDF7).opacity(0.96)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(
                isDarkMode
                    ? Color.white.opacity(0.14)
                    : Color(hex: 0xFFD9CCE8),
                lineWidth: 1
            )
        )
        .shadow(
            color: Color.black.opacity(isDarkMode ? 0.24 : 0.10),
            radius: 4,
            x: 0,
            y: 2
        )
    }

    private func field(
        title: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        showError: Bool = false
    ) -> some View {
        let forceLtr =
            keyboard == .phonePad ||
            keyboard == .emailAddress

        return VStack(
            alignment: formHorizontalAlignment,
            spacing: 6
        ) {
            Text(title)
                .kmiFont(size: 14, weight: .semibold)
                .foregroundStyle(
                    showError
                        ? registrationErrorBorder
                        : registrationLabelColor
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: formFrameAlignment
                )
                .multilineTextAlignment(formTextAlignment)
                .environment(
                    \.layoutDirection,
                    screenLayoutDirection
                )

            TextField(
                title,
                text: text
            )
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .kmiFont(size: 15, weight: .semibold)
            .multilineTextAlignment(
                forceLtr
                    ? .leading
                    : formTextAlignment
            )
            .environment(
                \.layoutDirection,
                forceLtr
                    ? .leftToRight
                    : screenLayoutDirection
            )
            .foregroundStyle(registrationFieldTextColor)
            .tint(
                isDarkMode
                    ? Color.white.opacity(0.88)
                    : registrationPrimaryPurple
            )
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .background(
                showError
                    ? registrationMissingBackground
                    : registrationFieldBackground
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
                .stroke(
                    showError
                        ? registrationErrorBorder
                        : registrationFieldBorder,
                    lineWidth: showError ? 2 : 1
                )
            )

            if showError {
                Text(
                    fieldErrorMessage(
                        title: title,
                        keyboard: keyboard
                    )
                )
                .kmiFont(size: 12, weight: .semibold)
                .foregroundStyle(registrationErrorBorder)
                .frame(
                    maxWidth: .infinity,
                    alignment: formFrameAlignment
                )
                .multilineTextAlignment(formTextAlignment)
            }
        }
    }

    private func fieldErrorMessage(
        title: String,
        keyboard: UIKeyboardType
    ) -> String {
        if keyboard == .phonePad {
            return tr(
                "נא להזין מספר טלפון תקין",
                "Please enter a valid phone number"
            )
        }

        if keyboard == .emailAddress {
            return tr(
                "נא להזין כתובת מייל תקינה",
                "Please enter a valid email address"
            )
        }

        if title == tr("שם משתמש", "Username") {
            return tr(
                "שם המשתמש חייב להכיל לפחות 3 תווים",
                "Username must contain at least 3 characters"
            )
        }

        return tr(
            "נא להזין שם מלא תקין",
            "Please enter a valid full name"
        )
    }

    private var submitBottomBar: some View {
        let isSubmitEnabled =
            s.acceptsTerms &&
            !isSubmitting

        return VStack(spacing: 10) {
            if shouldRevealValidationErrors,
               let err = validationError {
                Text(err)
                    .foregroundStyle(registrationErrorBorder)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(
                        maxWidth: .infinity,
                        alignment: .center
                    )
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }

            Button {
                guard isSubmitEnabled else {
                    return
                }

                hasAttemptedSubmit = true

                guard validationError == nil else {
                    return
                }

                isSubmitting = true

                let submitted = s

                DispatchQueue.main.async {
                    onSubmit(submitted)
                }

                DispatchQueue.main.asyncAfter(
                    deadline: .now() + 0.8
                ) {
                    isSubmitting = false
                }
            } label: {
                HStack(spacing: 10) {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(
                        isSubmitting
                            ? localizedSubmitTitle(
                                submittingTitle
                            )
                            : localizedSubmitTitle(
                                submitTitle
                            )
                    )
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                }
                .environment(
                    \.layoutDirection,
                    screenLayoutDirection
                )
                .frame(maxWidth: .infinity)
                .frame(height: 46)
            }
            .buttonStyle(.plain)
            .foregroundStyle(
                isSubmitEnabled
                    ? Color.white
                    : Color.black
            )
            .background(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .fill(
                    isSubmitEnabled
                        ? registrationPrimaryPurple
                        : Color(
                            red: 0.690,
                            green: 0.745,
                            blue: 0.773
                        )
                )
            )
            .disabled(!isSubmitEnabled)
            .accessibilityHint(
                s.acceptsTerms
                    ? ""
                    : tr(
                        "יש לאשר את תנאי השימוש לפני סיום הרישום",
                        "Accept the Terms of Use before completing registration"
                    )
            )
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.78),
                        Color.white.opacity(0.60)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 1)
        }
    }

    private var dobRow: some View {
        HStack(alignment: .top, spacing: 8) {
            dobField(
                tr("יום", "Day"),
                binding: $s.birthDay,
                maxLength: 2,
                showError: showBirthDayError,
                errorMessage: tr(
                    "יום לא תקין",
                    "Invalid day"
                )
            )

            dobField(
                tr("חודש", "Month"),
                binding: $s.birthMonth,
                maxLength: 2,
                showError: showBirthMonthError,
                errorMessage: tr(
                    "חודש לא תקין",
                    "Invalid month"
                )
            )

            dobField(
                tr("שנה", "Year"),
                binding: $s.birthYear,
                maxLength: 4,
                showError: showBirthYearError,
                errorMessage: tr(
                    "שנה לא תקינה",
                    "Invalid year"
                )
            )
        }
        .frame(maxWidth: .infinity)
        .environment(
            \.layoutDirection,
            .leftToRight
        )
    }

    private func dobField(
        _ title: String,
        binding: Binding<String>,
        maxLength: Int,
        showError: Bool,
        errorMessage: String
    ) -> some View {
        let cleanBinding = Binding<String>(
            get: {
                String(
                    binding.wrappedValue
                        .filter { $0.isNumber }
                        .prefix(maxLength)
                )
            },
            set: { newValue in
                let digits = newValue.filter { $0.isNumber }

                binding.wrappedValue = String(
                    digits.prefix(maxLength)
                )
            }
        )

        return VStack(spacing: 6) {
            Text(title)
                .kmiFont(size: 12, weight: .semibold)
                .foregroundStyle(
                    showError
                        ? registrationErrorBorder
                        : registrationLabelColor
                )
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            TextField(
                title,
                text: cleanBinding
            )
            .keyboardType(.numberPad)
            .textContentType(.none)
            .multilineTextAlignment(.center)
            .environment(
                \.layoutDirection,
                .leftToRight
            )
            .kmiFont(size: 17, weight: .bold)
            .foregroundStyle(registrationFieldTextColor)
            .tint(
                isDarkMode
                    ? Color.white.opacity(0.88)
                    : registrationPrimaryPurple
            )
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                showError
                    ? registrationMissingBackground
                    : registrationFieldBackground
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
                    showError
                        ? registrationErrorBorder
                        : registrationFieldBorder,
                    lineWidth: showError ? 2 : 1
                )
            }

            if showError {
                Text(errorMessage)
                    .kmiFont(size: 10, weight: .semibold)
                    .foregroundStyle(registrationErrorBorder)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var passwordField: some View {
        VStack(
            alignment: formHorizontalAlignment,
            spacing: 6
        ) {
            Text(tr("סיסמה", "Password"))
                .kmiFont(size: 14, weight: .semibold)
                .foregroundStyle(
                    showPasswordError
                        ? registrationErrorBorder
                        : registrationLabelColor
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: formFrameAlignment
                )
                .multilineTextAlignment(formTextAlignment)

            HStack(spacing: 10) {
                if isEnglish {
                    passwordInput

                    Button {
                        s.showPassword.toggle()
                    } label: {
                        passwordEyeIcon
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        s.showPassword.toggle()
                    } label: {
                        passwordEyeIcon
                    }
                    .buttonStyle(.plain)

                    passwordInput
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 46)
            .background(
                showPasswordError
                    ? registrationMissingBackground
                    : registrationFieldBackground
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
                .stroke(
                    showPasswordError
                        ? registrationErrorBorder
                        : registrationFieldBorder,
                    lineWidth: showPasswordError ? 2 : 1
                )
            )
            .environment(
                \.layoutDirection,
                screenLayoutDirection
            )

            if showPasswordError {
                Text(
                    tr(
                        "הסיסמה חייבת להכיל לפחות 6 תווים",
                        "Password must contain at least 6 characters"
                    )
                )
                .kmiFont(size: 12, weight: .semibold)
                .foregroundStyle(registrationErrorBorder)
                .frame(
                    maxWidth: .infinity,
                    alignment: formFrameAlignment
                )
                .multilineTextAlignment(formTextAlignment)
            }
        }
    }

    @ViewBuilder
    private var passwordInput: some View {
        Group {
            if s.showPassword {
                TextField(
                    tr("סיסמה", "Password"),
                    text: $s.password
                )
            } else {
                SecureField(
                    tr("סיסמה", "Password"),
                    text: $s.password
                )
            }
        }
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .kmiFont(size: 15, weight: .semibold)
        .foregroundStyle(registrationFieldTextColor)
        .tint(
            isDarkMode
                ? Color.white.opacity(0.88)
                : registrationPrimaryPurple
        )
        .multilineTextAlignment(formTextAlignment)
        .frame(maxWidth: .infinity)
    }

    private var passwordEyeIcon: some View {
        Image(
            systemName:
                s.showPassword
                    ? "eye.slash.fill"
                    : "eye.fill"
        )
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(
            isDarkMode
                ? Color.white.opacity(0.68)
                : Color.gray
        )
        .frame(width: 30, height: 30)
    }

    private var regionPicker: some View {
        VStack(
            alignment: formHorizontalAlignment,
            spacing: 6
        ) {
            Text(
                isAbroadSelection
                    ? tr("מדינה", "Country")
                    : tr("אזור", "Region")
            )
            .kmiFont(size: 14, weight: .semibold)
            .foregroundStyle(
                showRegionError
                    ? Color.red
                    : registrationLabelColor
            )
            .frame(
                maxWidth: .infinity,
                alignment: formFrameAlignment
            )
            .multilineTextAlignment(formTextAlignment)

            Picker(
                "",
                selection: $s.region
            ) {
                Text(
                    isAbroadSelection
                        ? tr("בחר מדינה", "Choose country")
                        : tr("בחר אזור", "Choose region")
                )
                .tag("")

                ForEach(regions, id: \.self) { region in
                    Text(
                        regionDisplayName(region)
                    )
                    .tag(region)
                }
            }
            .pickerStyle(.menu)
            .tint(registrationFieldTextColor)
            .frame(
                maxWidth: .infinity,
                alignment: formFrameAlignment
            )
            .padding(.horizontal, 12)
            .frame(height: 52)
            .background(
                showRegionError
                    ? registrationMissingBackground
                    : registrationFieldBackground
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .stroke(
                    showRegionError
                        ? Color.red
                        : registrationFieldBorder,
                    lineWidth: showRegionError ? 2 : 1
                )
            )
            .environment(
                \.layoutDirection,
                screenLayoutDirection
            )

            if showRegionError {
                Text(
                    isAbroadSelection
                        ? tr(
                            "חובה לבחור מדינה",
                            "Country is required"
                        )
                        : tr(
                            "חובה לבחור אזור",
                            "Region is required"
                        )
                )
                .kmiFont(size: 12, weight: .semibold)
                .foregroundStyle(Color.red)
                .frame(
                    maxWidth: .infinity,
                    alignment: formFrameAlignment
                )
                .multilineTextAlignment(formTextAlignment)
            }
        }
    }

    private var branchScopePicker: some View {
        VStack(
            alignment: formHorizontalAlignment,
            spacing: 8
        ) {
            Text(tr("בחירת סוג סניף", "Branch type"))
                .kmiFont(size: 14, weight: .semibold)
                .foregroundStyle(registrationLabelColor)
                .frame(
                    maxWidth: .infinity,
                    alignment: formFrameAlignment
                )
                .multilineTextAlignment(formTextAlignment)

            HStack(spacing: 12) {
                branchTypeChip(
                    title: tr("ישראל", "Israel"),
                    isSelected: !isAbroadSelection,
                    onTap: {
                        guard isAbroadSelection else { return }

                        isAbroadSelection = false
                        s.branchType = "israel"
                        resetBranchSelectionAfterScopeChange()
                    }
                )

                branchTypeChip(
                    title: tr("חו״ל", "Abroad"),
                    isSelected: isAbroadSelection,
                    onTap: {
                        guard !isAbroadSelection else { return }

                        isAbroadSelection = true
                        s.branchType = "abroad"
                        resetBranchSelectionAfterScopeChange()
                    }
                )
            }
        }
    }

    private func branchTypeChip(
        title: String,
        isSelected: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            Text(title)
                .kmiFont(size: 14, weight: .semibold)
                .foregroundStyle(
                    isSelected
                        ? Color.white
                        : registrationFieldTextColor
                )
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
                    .fill(
                        isSelected
                            ? registrationPrimaryPurple
                            : registrationFieldBackground
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
                    .stroke(
                        isSelected
                            ? registrationPrimaryPurple
                            : registrationFieldBorder,
                        lineWidth: isSelected ? 2 : 1
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private var genderPicker: some View {
        HStack(spacing: 12) {
            genderChip(
                title: tr("זכר", "Male"),
                value: "male",
                selectedColor: Color(red: 0.055, green: 0.647, blue: 0.914)
            )

            genderChip(
                title: tr("נקבה", "Female"),
                value: "female",
                selectedColor: Color(red: 0.925, green: 0.282, blue: 0.600)
            )
        }
    }

    private func genderChip(
        title: String,
        value: String,
        selectedColor: Color
    ) -> some View {
        let selected = s.gender == value

        return Button {
            s.gender = value
        } label: {
            Text(title)
                .kmiFont(size: 14, weight: .semibold)
                .foregroundStyle(
                    selected
                        ? Color.white
                        : (
                            showGenderError
                                ? registrationErrorBorder
                                : registrationFieldTextColor
                        )
                )
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
                    .fill(
                        selected
                            ? selectedColor
                            : (
                                showGenderError
                                    ? registrationMissingBackground
                                    : registrationFieldBackground
                            )
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
                    .stroke(
                        selected
                            ? selectedColor
                            : (
                                showGenderError
                                    ? registrationErrorBorder
                                    : registrationFieldBorder
                            ),
                        lineWidth:
                            selected || showGenderError
                                ? 2
                                : 1
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private var beltPicker: some View {
        VStack(
            alignment: formHorizontalAlignment,
            spacing: 6
        ) {
            Text(
                tr(
                    "דרגת חגורה נוכחית (ק.מ.י)",
                    "Current KAMI belt rank"
                )
            )
            .kmiFont(size: 14, weight: .semibold)
            .foregroundStyle(
                showBeltError
                    ? registrationErrorBorder
                    : registrationLabelColor
            )
            .frame(
                maxWidth: .infinity,
                alignment: formFrameAlignment
            )
            .multilineTextAlignment(formTextAlignment)

            Picker(
                "",
                selection: $s.belt
            ) {
                Text(
                    tr(
                        "בחר דרגת חגורה",
                        "Choose belt rank"
                    )
                )
                .tag("")

                ForEach(belts, id: \.self) { belt in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(
                                beltColorForRegistration(belt)
                            )
                            .frame(width: 14, height: 14)
                            .overlay {
                                if beltNeedsDarkBorderForRegistration(
                                    belt
                                ) {
                                    Circle()
                                        .stroke(
                                            Color.black,
                                            lineWidth: 1.5
                                        )
                                }
                            }

                        Text(
                            beltDisplayNameForRegistration(belt)
                        )
                    }
                    .tag(belt)
                }
            }
            .pickerStyle(.menu)
            .tint(registrationFieldTextColor)
            .frame(
                maxWidth: .infinity,
                alignment: formFrameAlignment
            )
            .padding(.horizontal, 12)
            .frame(height: 52)
            .background(
                showBeltError
                    ? registrationMissingBackground
                    : registrationFieldBackground
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .stroke(
                    showBeltError
                        ? registrationErrorBorder
                        : registrationFieldBorder,
                    lineWidth: showBeltError ? 2 : 1
                )
            )
            .environment(
                \.layoutDirection,
                screenLayoutDirection
            )

            if showBeltError {
                Text(
                    tr(
                        "חובה לבחור דרגת חגורה",
                        "Belt rank is required"
                    )
                )
                .kmiFont(size: 12, weight: .semibold)
                .foregroundStyle(registrationErrorBorder)
                .frame(
                    maxWidth: .infinity,
                    alignment: formFrameAlignment
                )
                .multilineTextAlignment(formTextAlignment)
            }
        }
    }

    private func multiSelectRow(
        title: String,
        valueText: String,
        showError: Bool = false,
        errorMessage: String = "",
        onTap: @escaping () -> Void
    ) -> some View {
        let cleanValue = valueText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let displayValue = cleanValue.isEmpty
            ? tr("בחר…", "Choose…")
            : cleanValue

        return Button(action: onTap) {
            VStack(
                alignment: formHorizontalAlignment,
                spacing: 6
            ) {
                Text(title)
                    .kmiFont(size: 14, weight: .semibold)
                    .foregroundStyle(
                        showError
                            ? registrationErrorBorder
                            : registrationLabelColor
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: formFrameAlignment
                    )
                    .multilineTextAlignment(formTextAlignment)
                    .environment(
                        \.layoutDirection,
                        screenLayoutDirection
                    )

                HStack(alignment: .center, spacing: 10) {
                    if isEnglish {
                        Text(displayValue)
                            .kmiFont(size: 15, weight: .semibold)
                            .foregroundStyle(
                                cleanValue.isEmpty
                                    ? registrationLabelColor
                                    : registrationFieldTextColor
                            )
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )
                            .multilineTextAlignment(.leading)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )

                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(registrationLabelColor)
                    } else {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(registrationLabelColor)

                        Text(displayValue)
                            .kmiFont(size: 15, weight: .semibold)
                            .foregroundStyle(
                                cleanValue.isEmpty
                                    ? registrationLabelColor
                                    : registrationFieldTextColor
                            )
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )
                            .multilineTextAlignment(.trailing)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .trailing
                            )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .frame(
                    maxWidth: .infinity,
                    minHeight: 52
                )
                .background(
                    showError
                        ? registrationMissingBackground
                        : registrationFieldBackground
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 14,
                        style: .continuous
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 14,
                        style: .continuous
                    )
                    .stroke(
                        showError
                            ? registrationErrorBorder
                            : registrationFieldBorder,
                        lineWidth: showError ? 2 : 1
                    )
                )
                .environment(
                    \.layoutDirection,
                    .leftToRight
                )

                if showError && !errorMessage.isEmpty {
                    Text(errorMessage)
                        .kmiFont(size: 12, weight: .semibold)
                        .foregroundStyle(registrationErrorBorder)
                        .frame(
                            maxWidth: .infinity,
                            alignment: formFrameAlignment
                        )
                        .multilineTextAlignment(formTextAlignment)
                        .environment(
                            \.layoutDirection,
                            screenLayoutDirection
                        )
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func consentCheckbox(
        isChecked: Bool,
        showError: Bool = false
    ) -> some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: 4,
                style: .continuous
            )
            .fill(
                isChecked
                    ? registrationPrimaryPurple
                    : registrationFieldBackground
            )

            RoundedRectangle(
                cornerRadius: 4,
                style: .continuous
            )
            .stroke(
                showError
                    ? registrationErrorBorder
                    : (
                        isChecked
                            ? registrationPrimaryPurple
                            : registrationFieldBorder
                    ),
                lineWidth: showError ? 2 : 1.5
            )

            if isChecked {
                Image(systemName: "checkmark")
                    .font(
                        .system(
                            size: 13,
                            weight: .heavy
                        )
                    )
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 24, height: 24)
        .contentShape(
            RoundedRectangle(
                cornerRadius: 4,
                style: .continuous
            )
        )
    }

    private var termsRow: some View {
        HStack(alignment: .center, spacing: 10) {
            if isEnglish {
                Button {
                    s.acceptsTerms.toggle()
                } label: {
                    consentCheckbox(
                        isChecked: s.acceptsTerms,
                        showError:
                            shouldRevealValidationErrors &&
                            !s.acceptsTerms
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    tr(
                        "אישור תנאי שימוש",
                        "Accept Terms of Use"
                    )
                )

                termsConsentText
            } else {
                termsConsentText

                Button {
                    s.acceptsTerms.toggle()
                } label: {
                    consentCheckbox(
                        isChecked: s.acceptsTerms,
                        showError:
                            shouldRevealValidationErrors &&
                            !s.acceptsTerms
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    tr(
                        "אישור תנאי שימוש",
                        "Accept Terms of Use"
                    )
                )
            }
        }
        .frame(maxWidth: .infinity)
        .environment(
            \.layoutDirection,
            .leftToRight
        )
    }

    private var termsConsentText: some View {
        VStack(
            alignment: formHorizontalAlignment,
            spacing: 3
        ) {
            Button {
                s.acceptsTerms.toggle()
            } label: {
                Text(
                    tr(
                        "אני מאשר את תנאי השימוש ומדיניות הפרטיות",
                        "I approve the Terms of Use and Privacy Policy"
                    )
                )
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(
                    shouldRevealValidationErrors &&
                    !s.acceptsTerms
                        ? registrationErrorBorder
                        : Color.primary
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: formFrameAlignment
                )
                .multilineTextAlignment(formTextAlignment)
            }
            .buttonStyle(.plain)

            Button(action: onReadMoreTerms) {
                Text(tr("קרא עוד", "Read more"))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(
                        registrationPrimaryPurple
                    )
                    .underline()
                    .frame(
                        maxWidth: .infinity,
                        alignment: formFrameAlignment
                    )
                    .multilineTextAlignment(
                        formTextAlignment
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .environment(
            \.layoutDirection,
            screenLayoutDirection
        )
    }

    private var validationError: String? {
        if s.fullName.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
            return tr("נא להזין שם מלא תקין", "Please enter a valid full name")
        }

        if s.phone.filter({ $0.isNumber }).count < 9 {
            return tr("נא להזין מספר טלפון תקין", "Please enter a valid phone number")
        }

        if !s.email.contains("@") || !s.email.contains(".") {
            return tr("נא להזין מייל תקין", "Please enter a valid email")
        }

        if let d = Int(s.birthDay), !(1...31).contains(d) {
            return tr("יום לידה לא תקין", "Invalid birth day")
        }

        if s.birthDay.isEmpty {
            return tr("חובה להזין יום לידה", "Birth day is required")
        }

        if let m = Int(s.birthMonth), !(1...12).contains(m) {
            return tr("חודש לידה לא תקין", "Invalid birth month")
        }

        if s.birthMonth.isEmpty {
            return tr("חובה להזין חודש לידה", "Birth month is required")
        }

        if let y = Int(s.birthYear), !(1900...2100).contains(y) {
            return tr("שנת לידה לא תקינה", "Invalid birth year")
        }

        if s.birthYear.count != 4 {
            return tr("חובה להזין שנת לידה (4 ספרות)", "Birth year is required (4 digits)")
        }

        if s.gender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return tr("חובה לבחור מין", "Gender is required")
        }

        if !isGoogleAuth {
            if s.username.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 {
                return tr("שם משתמש קצר מדי", "Username is too short")
            }

            if s.password.count < 6 {
                return tr("סיסמה חייבת להכיל לפחות 6 תווים", "Password must contain at least 6 characters")
            }
        }

        if s.belt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return tr("חובה לבחור דרגת חגורה", "Belt rank is required")
        }

        if !s.acceptsTerms {
            return tr(
                "חובה לאשר תנאי שימוש ומדיניות פרטיות",
                "You must approve the Terms of Use and Privacy Policy"
            )
        }

        if s.region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return isAbroadSelection
                ? tr("חובה לבחור מדינה", "Country is required")
                : tr("חובה לבחור אזור", "Region is required")
        }

        if s.branches.isEmpty {
            return isAbroadSelection
                ? tr("חובה לבחור לפחות סניף אחד בחו״ל", "Please choose at least one branch abroad")
                : tr("חובה לבחור לפחות סניף אחד בארץ", "Please choose at least one branch in Israel")
        }

        if shouldShowGroupsPicker && s.groups.isEmpty {
            return tr("חובה לבחור לפחות קבוצה אחת", "Please choose at least one group")
        }

        if !isEditingProfile,
           s.role == .coach,
           !isWhitelistedCoach {
            return tr(
                "הרישום כמאמן מותר רק למאמנים מורשים",
                "Coach registration is allowed only for authorized coaches"
            )
        }

        return nil
    }
    
    private func resetBranchSelectionAfterScopeChange() {
        s.region = ""
        s.branches.removeAll()
        s.groups.removeAll()
        s.activeBranch = ""
        s.activeGroup = ""
        s.branchType = isAbroadSelection ? "abroad" : "israel"

        displayedBranchValue = ""
        displayedGroupValue = ""

        storedActiveBranch = ""
        storedActiveGroup = ""
    }

    private func loadSavedProfileIfNeeded() {
        let defaults = UserDefaults.standard

        if s.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.fullName =
                defaults.string(forKey: "fullName") ??
                defaults.string(forKey: "full_name") ??
                ""
        }

        if s.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.phone = defaults.string(forKey: "phone") ?? ""
        }

        if s.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.email = defaults.string(forKey: "email") ?? ""
        }

        if s.region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.region =
                defaults.string(forKey: "region") ??
                defaults.string(forKey: "active_region") ??
                defaults.string(forKey: "kmi.user.region") ??
                s.region
        }

        let savedBranchType = defaults.string(forKey: "branch_type") ?? ""
        if !savedBranchType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.branchType = savedBranchType
        }

        if s.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.username = defaults.string(forKey: "username") ?? ""
        }

        if s.birthDay.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.birthDay = defaults.string(forKey: "birthDay") ?? defaults.string(forKey: "birth_day") ?? ""
        }

        if s.birthMonth.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.birthMonth = defaults.string(forKey: "birthMonth") ?? defaults.string(forKey: "birth_month") ?? ""
        }

        if s.birthYear.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.birthYear = defaults.string(forKey: "birthYear") ?? defaults.string(forKey: "birth_year") ?? ""
        }

        if s.gender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.gender = defaults.string(forKey: "gender") ?? ""
        }

        if s.password.isEmpty {
            s.password = defaults.string(forKey: "password") ?? ""
        }

        // במסך רישום לא טוענים role מהכניסה האחרונה.
        // מקור האמת כאן הוא initialRole שמוגדר בזרימת האימות.

        let storedBranches = defaults.stringArray(forKey: "branches") ?? []
        if s.branches.isEmpty, !storedBranches.isEmpty {
            s.branches = Set(storedBranches)
        } else {
            let singleBranch = (
                defaults.string(forKey: "branch") ??
                defaults.string(forKey: "active_branch") ??
                defaults.string(forKey: "kmi.user.branch") ??
                ""
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

            if s.branches.isEmpty, !singleBranch.isEmpty {
                s.branches = [singleBranch]
            }
        }

        s.activeBranch = (
            defaults.string(forKey: "active_branch") ??
            defaults.string(forKey: "branch") ??
            defaults.string(forKey: "kmi.user.branch") ??
            s.branches.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .sorted()
                .first ??
            ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        let storedGroups = defaults.stringArray(forKey: "groups") ?? []
        if s.groups.isEmpty, !storedGroups.isEmpty {
            s.groups = Set(storedGroups)
        } else {
            let singleGroup = (
                defaults.string(forKey: "group") ??
                defaults.string(forKey: "active_group") ??
                defaults.string(forKey: "kmi.user.group") ??
                ""
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

            if s.groups.isEmpty, !singleGroup.isEmpty {
                s.groups = [singleGroup]
            }
        }

        s.activeGroup = (
            defaults.string(forKey: "active_group") ??
            defaults.string(forKey: "group") ??
            defaults.string(forKey: "kmi.user.group") ??
            s.groups.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .sorted()
                .first ??
            ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        let storedBelt = (
            defaults.string(forKey: "current_belt") ??
            defaults.string(forKey: "belt_current") ??
            ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        if s.belt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || s.belt == "ללא" {
            switch storedBelt.lowercased() {
            case "white", "לבן", "לבנה":
                s.belt = "לבנה"
            case "yellow", "צהוב", "צהובה":
                s.belt = "צהובה"
            case "orange", "כתום", "כתומה":
                s.belt = "כתומה"
            case "green", "ירוק", "ירוקה":
                s.belt = "ירוקה"
            case "blue", "כחול", "כחולה":
                s.belt = "כחולה"
            case "brown", "חום", "חומה":
                s.belt = "חומה"
            case "black", "black_dan_1", "שחור", "שחורה", "שחורה דאן 1":
                s.belt = "שחורה דאן 1"
            case "black_dan_2", "שחורה דאן 2":
                s.belt = "שחורה דאן 2"
            case "black_dan_3", "שחורה דאן 3":
                s.belt = "שחורה דאן 3"
            case "black_dan_4", "שחורה דאן 4":
                s.belt = "שחורה דאן 4"
            case "black_dan_5", "שחורה דאן 5":
                s.belt = "שחורה דאן 5"
            case "black_dan_6", "שחורה דאן 6":
                s.belt = "שחורה דאן 6"
            case "black_dan_7", "שחורה דאן 7":
                s.belt = "שחורה דאן 7"
            case "black_dan_8", "שחורה דאן 8":
                s.belt = "שחורה דאן 8"
            case "black_dan_9", "שחורה דאן 9":
                s.belt = "שחורה דאן 9"
            case "black_dan_10", "שחורה דאן 10":
                s.belt = "שחורה דאן 10"
            default:
                break
            }
        }

        s.wantsSms = defaults.object(forKey: "wantsSms") as? Bool ?? s.wantsSms
        s.acceptsTerms = defaults.object(forKey: "acceptsTerms") as? Bool ?? s.acceptsTerms

        if s.coachCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.coachCode =
                defaults.string(forKey: "coachCode") ??
                defaults.string(forKey: "coach_code") ??
                ""
        }
    }
}
