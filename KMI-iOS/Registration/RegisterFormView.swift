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
    let isSavingProfile: Bool
    let onBack: () -> Void
    let onSubmit: (RegistrationFormState) -> Void
    let onReadMoreTerms: () -> Void

    @State private var s: RegistrationFormState
    @EnvironmentObject private var auth: AuthViewModel

    private var isSubmitting: Bool {
        auth.isLoading || isSavingProfile
    }

    @State private var didFinishInitialLoad: Bool = false
    @State private var hasAttemptedSubmit: Bool = false
    @State private var missingFieldScrollRequest: Int = 0
    @FocusState private var focusedField: String?
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
    private func availableGroups(for branch: String) -> [String] {
        let cleanBranch = branch.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleanBranch.isEmpty else {
            return []
        }

        return Array(
            Set(
                TrainingCatalogIOS.groupsFor(
                    branches: [cleanBranch]
                )
                .map {
                    $0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                }
                .filter { !$0.isEmpty }
            )
        )
        .sorted()
    }

    private var groupsOptions: [String] {
        availableGroups(for: s.activeBranch)
    }

    /*
     * בורר הקבוצות מוצג רק בארץ,
     * לאחר בחירת סניף ורק כאשר נמצאו קבוצות
     * עבור אחד הסניפים שנבחרו.
     */
    private var shouldShowGroupsPicker: Bool {
        !isAbroadSelection &&
        !isCurrentRegionAbroad &&
        !s.branches.isEmpty
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
    @State private var showBeltSheet = false
    @State private var branchGroupsExpansion: [String: Bool] = [:]

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
        !(9...12).contains(
            s.phone.filter { $0.isNumber }.count
        )
    }

    private var showEmailError: Bool {
        shouldRevealValidationErrors &&
        (
            !s.email.contains("@") ||
            !s.email.contains(".")
        )
    }

    private var showUsernameError:
        Bool {

        shouldRevealValidationErrors &&
        !isEditingProfile &&
        !isGoogleAuth &&
        s.username
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .count < 3
    }

    private var showPasswordError:
        Bool {

        shouldRevealValidationErrors &&
        !isEditingProfile &&
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
        guard shouldRevealValidationErrors,
              shouldShowGroupsPicker else {
            return false
        }

        return s.branchesArray.contains { branch in
            let selectedGroups = s.branchAssignments
                .first { $0.branch == branch }?
                .groups ?? []

            let available = Set(
                availableGroups(for: branch)
            )

            return selectedGroups.isEmpty ||
                selectedGroups.contains {
                    !available.contains($0)
                }
        }
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

    private var registrationFieldBackground:
        Color {

        KmiAppTheme
            .surface(
                for:
                    colorScheme
            )
    }

    private var registrationFieldTextColor:
        Color {

        KmiAppTheme
            .onSurface(
                for:
                    colorScheme
            )
    }

    private var registrationFieldBorder:
        Color {

        KmiAppTheme
            .outlineVariant(
                for:
                    colorScheme
            )
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

    private var registrationPrimaryPurple:
        Color {

        KmiAppTheme
            .secondary(
                for:
                    colorScheme
            )
    }

    private var registrationLabelColor:
        Color {

        KmiAppTheme
            .onSurfaceVariant(
                for:
                    colorScheme
            )
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
        isSavingProfile: Bool = false,
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
        self.isSavingProfile = isSavingProfile
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
            .disabled(isSubmitting)
            .environment(\.layoutDirection, screenLayoutDirection)
            .sheet(isPresented: $showBeltSheet) {
                beltSelectionSheet
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                submitBottomBar
            }
            .overlay {
                if isSubmitting {
                    KmiLoadingOverlay()
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()

                    Button(tr("סיום", "Done")) {
                        requestMissingFieldScroll()
                    }
                    .kmiFont(size: 14, weight: .semibold)
                }
            }
            .onChange(of: s.region) { oldRegion, newRegion in
                handleRegionChange(oldRegion: oldRegion, newRegion: newRegion)
            }
            .onChange(of: s.branches) { _, newBranches in
                handleBranchesChange(newBranches)
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

            VStack(spacing: 0) {
                roleTabs

                ScrollViewReader { proxy in
                    ScrollView {
                        registerScrollContent
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(
                        of: missingFieldScrollRequest
                    ) { _, _ in
                        guard let target = firstMissingField else {
                            return
                        }

                        DispatchQueue.main.async {
                            withAnimation(
                                .easeInOut(duration: 0.25)
                            ) {
                                proxy.scrollTo(
                                    target,
                                    anchor: .top
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private func requestMissingFieldScroll() {
        focusedField = nil
        hasAttemptedSubmit = true

        if showGroupsError {
            for branch in s.branchesArray {
                let selected = groupsBinding(
                    for: branch
                ).wrappedValue

                let available = Set(
                    availableGroups(for: branch)
                )

                if selected.isEmpty ||
                    selected.contains(
                        where: { !available.contains($0) }
                    ) {
                    branchGroupsExpansion[branch] = true
                }
            }
        }

        missingFieldScrollRequest += 1
    }

    private var firstMissingField: String? {
        if showFullNameError {
            return "fullName"
        }

        if showPhoneError {
            return "phone"
        }

        if showEmailError {
            return "email"
        }

        if showGenderError {
            return "gender"
        }

        if showBirthDayError ||
            showBirthMonthError ||
            showBirthYearError {
            return "birthDate"
        }

        if showUsernameError {
            return "username"
        }

        if showPasswordError {
            return "password"
        }

        if showRegionError {
            return "region"
        }

        if showBranchesError {
            return "branches"
        }

        if showGroupsError {
            for branch in s.branchesArray {
                let selected = groupsBinding(
                    for: branch
                ).wrappedValue

                let available = Set(
                    availableGroups(for: branch)
                )

                if selected.isEmpty ||
                    selected.contains(
                        where: { !available.contains($0) }
                    ) {
                    return "group:\(branch)"
                }
            }

            return "groups"
        }

        if showBeltError {
            return "belt"
        }

        if !s.acceptsTerms {
            return "terms"
        }

        return nil
    }

    private var registrationBackground:
        some View {

        LinearGradient(
            colors:
                KmiAppTheme
                    .screenBackgroundColors(
                        for:
                            colorScheme
                    ),
            startPoint:
                .top,
            endPoint:
                .bottom
        )
        .ignoresSafeArea()
    }

    private var registerScrollContent: some View {
        VStack(spacing: 14) {
            /*
             * הטאבים קבועים מעל הגלילה.
             * התוכן מתחיל בכרטיס הפרטים האישיים.
             */
            personalDetailsSection

            accountSection

            branchSection

            preferencesSection
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
            .id("fullName")

            field(
                title: tr("טלפון", "Phone"),
                text: $s.phone,
                keyboard: .phonePad,
                showError: showPhoneError
            )
            .id("phone")

            field(
                title: tr("מייל", "Email"),
                text: $s.email,
                keyboard: .emailAddress,
                showError: showEmailError
            )
            .id("email")

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
                .id("gender")

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
                .kmiFont(size: 14, weight: .semibold)
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
                .id("birthDate")
        }
    }

    @ViewBuilder
    private var accountSection:
        some View {

        /*
         * כמו Android:
         * שם משתמש וסיסמה שייכים לרישום חדש.
         * בעריכת פרופיל לא דורשים אותם מחדש.
         */
        if !isEditingProfile &&
            !isGoogleAuth {

            sectionCard(
                title:
                    tr(
                        "חשבון משתמש",
                        "User account"
                    )
            ) {
                field(
                    title:
                        tr(
                            "שם משתמש",
                            "Username"
                        ),
                    text:
                        $s.username,
                    keyboard:
                        .default,
                    showError:
                        showUsernameError
                )
                .id("username")

                passwordField
                    .id("password")
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
                .id("region")

            VStack(spacing: 6) {
                KmiPremiumMultiSelectDropdown(
                    title: isAbroadSelection
                        ? tr("סניפים בחו״ל", "Branches abroad")
                        : tr("סניפים בארץ", "Branches in Israel"),
                    options: branchesOptions,
                    selectedValues: $s.branches,
                    placeholder: tr("בחר סניפים", "Choose branches"),
                    isEnglish: isEnglish,
                    isEnabled: !s.region
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty && !isSubmitting,
                    maxSelected: 10
                )
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            showBranchesError
                                ? registrationMissingBackground
                                : Color.clear
                        )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            showBranchesError
                                ? registrationErrorBorder
                                : Color.clear,
                            lineWidth: 2
                        )
                }

                if showBranchesError {
                    Text(
                        isAbroadSelection
                            ? tr(
                                "חובה לבחור לפחות סניף אחד בחו״ל",
                                "Please select at least one abroad branch"
                            )
                            : tr(
                                "חובה לבחור לפחות סניף אחד",
                                "Please select at least one branch"
                            )
                    )
                    .kmiFont(size: 12, weight: .semibold)
                    .foregroundStyle(registrationErrorBorder)
                    .multilineTextAlignment(formTextAlignment)
                    .frame(
                        maxWidth: .infinity,
                        alignment: formFrameAlignment
                    )
                }
            }
            .id("branches")

            if shouldShowGroupsPicker {
                branchGroupsCards
                    .id("groups")
            }

            beltPicker
                .id("belt")
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
                .id("terms")
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
        .kmiFont(size: 13, weight: .regular)
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

    private var branchGroupsCards: some View {
        VStack(
            alignment: formHorizontalAlignment,
            spacing: 8
        ) {
            Text(
                tr(
                    "בחירת קבוצות לפי סניף",
                    "Select groups by branch"
                )
            )
            .kmiTypography(.cardTitle)
            .foregroundStyle(registrationFieldTextColor)
            .frame(
                maxWidth: .infinity,
                alignment: formFrameAlignment
            )
            .multilineTextAlignment(formTextAlignment)

            Text(
                tr(
                    "פתח כל סניף ובחר את הקבוצות שלך",
                    "Open each branch and select your groups"
                )
            )
            .kmiFont(size: 12, weight: .regular)
            .foregroundStyle(registrationLabelColor)
            .frame(
                maxWidth: .infinity,
                alignment: formFrameAlignment
            )
            .multilineTextAlignment(formTextAlignment)

            ForEach(s.branchesArray, id: \.self) { branch in
                branchGroupsCard(for: branch)
            }
        }
    }

    private func branchGroupsCard(
        for branch: String
    ) -> some View {
        let selection = groupsBinding(for: branch)
        let selected = selection.wrappedValue
        let options = availableGroups(for: branch)

        let expanded =
            branchGroupsExpansion[branch] ?? true

        let missing =
            shouldRevealValidationErrors &&
            selected.isEmpty

        let borderColor =
            missing
                ? registrationErrorBorder
                : expanded
                    ? registrationPrimaryPurple
                    : registrationFieldBorder

        return VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    branchGroupsExpansion[branch] = !expanded
                }
            } label: {
                HStack(spacing: 10) {
                    VStack(
                        alignment: formHorizontalAlignment,
                        spacing: 4
                    ) {
                        Text(displayJoinedValues([branch]))
                            .kmiFont(size: 15, weight: .bold)
                            .foregroundStyle(
                                registrationFieldTextColor
                            )

                        Text(
                            selected.isEmpty
                                ? tr(
                                    "יש לבחור לפחות קבוצה אחת",
                                    "Select at least one group"
                                )
                                : tr(
                                    "נבחרו \(selected.count) קבוצות",
                                    "\(selected.count) groups selected"
                                )
                        )
                        .kmiFont(size: 12, weight: .semibold)
                        .foregroundStyle(
                            missing
                                ? registrationErrorBorder
                                : registrationLabelColor
                        )

                        if !selected.isEmpty {
                            Text(
                                displayJoinedValues(
                                    Array(selected),
                                    translateGroupNames: true
                                )
                            )
                            .kmiFont(size: 12, weight: .regular)
                            .foregroundStyle(
                                registrationLabelColor
                            )
                        }
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: formFrameAlignment
                    )
                    .multilineTextAlignment(formTextAlignment)

                    Image(
                        systemName: expanded
                            ? "chevron.up"
                            : "chevron.down"
                    )
                    .kmiFont(size: 14, weight: .bold)
                    .foregroundStyle(borderColor)
                    .accessibilityHidden(true)
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(
                expanded
                    ? tr("פתוח", "Expanded")
                    : tr("סגור", "Collapsed")
            )

            if expanded {
                Rectangle()
                    .fill(registrationFieldBorder)
                    .frame(height: 1)

                if options.isEmpty {
                    Text(
                        tr(
                            "לא נמצאו קבוצות בסניף זה",
                            "No groups were found for this branch"
                        )
                    )
                    .kmiFont(size: 12, weight: .regular)
                    .foregroundStyle(registrationLabelColor)
                    .frame(
                        maxWidth: .infinity,
                        alignment: formFrameAlignment
                    )
                    .multilineTextAlignment(formTextAlignment)
                    .padding(14)
                } else {
                    VStack(spacing: 6) {
                        ForEach(options, id: \.self) { group in
                            let checked = selected.contains(group)

                            Button {
                                branchGroupsExpansion[branch] = true

                                var updated = selection.wrappedValue

                                if updated.contains(group) {
                                    updated.remove(group)
                                } else {
                                    updated.insert(group)
                                }

                                selection.wrappedValue = updated
                            } label: {
                                HStack(spacing: 10) {
                                    consentCheckbox(
                                        isChecked: checked
                                    )
                                    .accessibilityHidden(true)

                                    Text(
                                        groupDisplayNameForRegistration(
                                            group
                                        )
                                    )
                                    .kmiFont(
                                        size: 14,
                                        weight: checked
                                            ? .semibold
                                            : .regular
                                    )
                                    .foregroundStyle(
                                        registrationFieldTextColor
                                    )
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: formFrameAlignment
                                    )
                                    .multilineTextAlignment(
                                        formTextAlignment
                                    )
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityValue(
                                checked
                                    ? tr("נבחר", "Selected")
                                    : tr("לא נבחר", "Not selected")
                            )
                        }
                    }
                    .padding(8)
                }
            }
        }
        .background(
            missing
                ? registrationMissingBackground
                : registrationFieldBackground
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 18)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    borderColor,
                    lineWidth: missing ? 1.5 : 1
                )
        )
        .environment(
            \.layoutDirection,
            screenLayoutDirection
        )
        .id("group:\(branch)")
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

        branchGroupsExpansion.removeAll()

        s.branches.removeAll()
        s.groups.removeAll()
        s.branchAssignments.removeAll()
        s.activeBranch = ""
        s.activeGroup = ""

        displayedBranchValue = ""
        displayedGroupValue = ""
        storedActiveBranch = ""
        storedActiveGroup = ""
    }

    private func groupsBinding(
        for branch: String
    ) -> Binding<Set<String>> {
        Binding(
            get: {
                Set(
                    s.branchAssignments
                        .first { $0.branch == branch }?
                        .groups ?? []
                )
            },
            set: { selectedGroups in
                guard s.branchesArray.contains(branch) else {
                    return
                }

                let allowedGroups = Set(
                    availableGroups(for: branch)
                )

                let cleanGroups = selectedGroups
                    .map {
                        $0.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                    }
                    .filter { allowedGroups.contains($0) }
                    .sorted()

                let assignment =
                    RegistrationFormState.BranchAssignment(
                        branch: branch,
                        groups: cleanGroups
                    )

                if let index = s.branchAssignments.firstIndex(
                    where: { $0.branch == branch }
                ) {
                    s.branchAssignments[index] = assignment
                } else {
                    s.branchAssignments.append(assignment)
                }

                synchronizeBranchAssignments()
            }
        )
    }

    private func synchronizeBranchAssignments() {
        let branches = s.branchesArray
        let selectedBranches = Set(branches)

        var assignments =
            RegistrationFormState.BranchAssignmentsCodec
                .sanitized(s.branchAssignments)
                .filter {
                    selectedBranches.contains($0.branch)
                }

        for branch in branches {
            if !assignments.contains(
                where: { $0.branch == branch }
            ) {
                assignments.append(
                    RegistrationFormState.BranchAssignment(
                        branch: branch,
                        groups: []
                    )
                )
            }
        }

        s.branchAssignments = assignments

        s.groups = Set(
            RegistrationFormState.BranchAssignmentsCodec
                .flattenGroups(assignments)
        )

        if !selectedBranches.contains(s.activeBranch) {
            s.activeBranch = branches.first ?? ""
        }

        let activeGroups = assignments
            .first { $0.branch == s.activeBranch }?
            .groups ?? []

        if !activeGroups.contains(s.activeGroup) {
            s.activeGroup = activeGroups.first ?? ""
        }

        displayedBranchValue = s.activeBranch
        displayedGroupValue = s.activeGroup

        storedActiveBranch = s.activeBranch
        storedActiveGroup = s.activeGroup
    }

    private func initializeBranchAssignments() {
        let codec = RegistrationFormState.BranchAssignmentsCodec.self

        if s.branchAssignments.isEmpty {
            let savedAssignments = codec.decode(
                UserDefaults.standard.string(
                    forKey: codec.preferenceKey
                )
            )

            s.branchAssignments = savedAssignments.filter {
                s.branchesArray.contains($0.branch)
            }
        }

        if s.branchAssignments.isEmpty,
           s.branchesArray.count == 1,
           let branch = s.branchesArray.first {
            s.branchAssignments = [
                RegistrationFormState.BranchAssignment(
                    branch: branch,
                    groups: s.groupsArray
                )
            ]
        }

        synchronizeBranchAssignments()
    }

    private func handleBranchesChange(
        _ newBranches: Set<String>
    ) {
        guard didFinishInitialLoad else {
            return
        }

        branchGroupsExpansion = branchGroupsExpansion.filter {
            newBranches.contains($0.key)
        }

        if newBranches.contains(
            where: { TrainingCatalogIOS.isAbroadBranch($0) }
        ) {
            isAbroadSelection = true
            s.branchType = "abroad"
        } else if !isAbroadSelection {
            s.branchType = "israel"
        }

        synchronizeBranchAssignments()
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

        /*
         * ניקוי שאריות מגרסאות ישנות.
         * אין לשמור סיסמת משתמש ב־UserDefaults.
         */
        let defaults =
            UserDefaults.standard

        defaults.removeObject(
            forKey:
                "password"
        )

        defaults.removeObject(
            forKey:
                "user_password"
        )

        defaults.removeObject(
            forKey:
                "remember_password"
        )

        loadSavedProfileIfNeeded()

        if isGoogleAuth {
            if s.email
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty {
                s.email = prefillEmail
            }

            if s.username
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .isEmpty {

                s.username =
                    prefillEmail
            }

            /*
             * Google Authentication אינו משתמש
             * בסיסמה מקומית.
             */
            s.password = ""
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

        s.role =
            initialRole

        /*
         * כמו Android:
         * משתמש שכבר נמצא בעריכת פרופיל
         * כבר עבר את שלב אישור התנאים.
         */
        if isEditingProfile {
            s.acceptsTerms =
                true
        }

        applyRoleGate()

        initializeBranchAssignments()

        DispatchQueue.main.async {
            didFinishInitialLoad =
                true
        }
    }
    
    private func applyRoleGate() {
        /*
         * בעריכת פרופיל בחירת התפקיד
         * נבדקת בזמן לחיצה על הטאב.
         */
        guard !isEditingProfile else {
            return
        }

        /*
         * כמו Android:
         * רישום חדש מתבצע במצב מתאמן.
         */
        s.role = .trainee
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

    private var roleTabs:
        some View {

        HStack(
            spacing:
                0
        ) {
            tabButton(
                .trainee
            )

            Rectangle()
                .fill(
                    Color.white.opacity(
                        0.65
                    )
                )
                .frame(
                    width:
                        1,
                    height:
                        30
                )

            tabButton(
                .coach
            )
        }
        .padding(
            .horizontal,
            34
        )
        .frame(
            maxWidth:
                .infinity
        )
        .frame(
            height:
                56
        )
        .background(
            KmiAppTheme
                .sectionHeaderBrush
        )
            /*
             * כמו Android:
             * מתאמן מימין ומאמן משמאל,
             * בעברית ובאנגלית.
             */
            .environment(
                \.layoutDirection,
                .rightToLeft
            )
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
             * כמו Android:
             * ברישום חדש לא ניתן לבחור מצב מאמן.
             */
            guard isEditingProfile else {
                s.role = .trainee
                return
            }

            /*
             * בעריכת פרופיל מעבר למתאמן
             * תמיד מותר, כמו Android.
             */
            if role == .trainee {
                s.role = .trainee
                return
            }

            /*
             * מעבר למאמן מותר רק למשתמש
             * בעל הרשאת מאמן, או למנהל.
             */
            if role == .coach &&
                !isSuperTester &&
                !isWhitelistedCoach {

                s.role = .trainee
                return
            }

            s.role = role
        } label: {
            ZStack(alignment: .bottom) {
                Text(
                    title
                )
                .kmiFont(
                    size:
                        15,
                    weight:
                        isSelected
                            ? .heavy
                            : .bold
                )
                .foregroundStyle(
                    Color.white.opacity(
                        isSelected
                            ? 1.0
                            : 0.90
                    )
                )
                .lineLimit(
                    1
                )
                .minimumScaleFactor(
                    0.82
                )
                .frame(
                    maxWidth:
                        .infinity,
                    maxHeight:
                        .infinity
                )
                .offset(
                    y:
                        -5
                )

                if isSelected {
                    RoundedRectangle(
                        cornerRadius:
                            4,
                        style:
                            .continuous
                    )
                    .fill(
                        Color.white
                    )
                    .frame(
                        width:
                            76,
                        height:
                            3
                    )
                    .offset(
                        y:
                            -11
                    )
                }
            }
        }
        .buttonStyle(
            .plain
        )
    }

    private func sectionCard(
        title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(
            alignment: formHorizontalAlignment,
            spacing: 7
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
                cornerRadius:
                    18,
                style:
                    .continuous
            )
            .fill(
                KmiAppTheme.surface(for: colorScheme)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius:
                    18,
                style:
                    .continuous
            )
            .stroke(
                KmiAppTheme
                    .outlineVariant(
                        for:
                            colorScheme
                    ),
                lineWidth:
                    1
            )
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
            .focused($focusedField, equals: "field:\(title)")
            .submitLabel(.done)
            .onSubmit {
                requestMissingFieldScroll()
            }
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
        let isSubmitEnabled = !isSubmitting

        return VStack(spacing: 10) {
            if shouldRevealValidationErrors,
               let err = validationError {
                Text(err)
                    .foregroundStyle(registrationErrorBorder)
                    .kmiFont(size: 13, weight: .semibold)
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
                    requestMissingFieldScroll()
                    return
                }

                focusedField = nil
                onSubmit(s)
            } label: {
                HStack(spacing: 10) {
                    Text(
                        isSubmitting
                            ? localizedSubmitTitle(
                                submittingTitle
                            )
                        : localizedSubmitTitle(
                            submitTitle
                        )
                )
                .kmiFont(size: 15, weight: .bold)
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
                    : registrationLabelColor
            )
            .background(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .fill(
                    isSubmitEnabled
                        ? KmiAppTheme.primary(for: colorScheme)
                        : KmiAppTheme.surfaceVariant(for: colorScheme)
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
            registrationFieldBackground
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(registrationFieldBorder)
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
            .focused($focusedField, equals: "dob:\(title)")
            .submitLabel(.done)
            .onSubmit {
                requestMissingFieldScroll()
            }
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
                .focused($focusedField, equals: "password")
            } else {
                SecureField(
                    tr("סיסמה", "Password"),
                    text: $s.password
                )
                .focused($focusedField, equals: "password")
            }
        }
        .submitLabel(.done)
        .onSubmit {
            requestMissingFieldScroll()
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
        .kmiIconSize(16)
        .fontWeight(.semibold)
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
            KmiPremiumDropdown(
                title: isAbroadSelection
                    ? tr("מדינה", "Country")
                    : tr("אזור", "Region"),
                options: regions,
                selectedValue: $s.region,
                placeholder: isAbroadSelection
                    ? tr("בחר מדינה", "Choose country")
                    : tr("בחר אזור", "Choose region"),
                isEnglish: isEnglish,
                isEnabled: !isSubmitting,
                labelForOption: { region in
                    regionDisplayName(region)
                }
            )
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        showRegionError
                            ? registrationMissingBackground
                            : Color.clear
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        showRegionError
                            ? registrationErrorBorder
                            : Color.clear,
                        lineWidth: 2
                    )
            }

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
                .foregroundStyle(registrationErrorBorder)
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

    private var beltSelectionSheet: some View {
        VStack(spacing: 0) {
            Text(tr("בחר דרגת חגורה", "Select belt rank"))
                .kmiFont(size: 17, weight: .bold)
                .foregroundStyle(registrationFieldTextColor)
                .multilineTextAlignment(formTextAlignment)
                .frame(
                    maxWidth: .infinity,
                    alignment: formFrameAlignment
                )
                .padding(16)
                .background(
                    KmiAppTheme.surfaceVariant(for: colorScheme)
                )

            Rectangle()
                .fill(registrationFieldBorder)
                .frame(height: 1)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(belts, id: \.self) { belt in
                        Button {
                            s.belt = belt
                            showBeltSheet = false
                        } label: {
                            HStack(spacing: 8) {
                                if isEnglish {
                                    beltSelectionDot(belt)
                                }

                                Text(
                                    beltDisplayNameForRegistration(belt)
                                )
                                .kmiFont(size: 16, weight: .regular)
                                .foregroundStyle(registrationFieldTextColor)
                                .multilineTextAlignment(formTextAlignment)
                                .fixedSize(
                                    horizontal: false,
                                    vertical: true
                                )
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: formFrameAlignment
                                )

                                if !isEnglish {
                                    beltSelectionDot(belt)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(
                            s.belt == belt
                                ? tr("נבחר", "Selected")
                                : tr("לא נבחר", "Not selected")
                        )
                    }
                }
            }

            Rectangle()
                .fill(registrationFieldBorder)
                .frame(height: 1)

            HStack {
                if isEnglish {
                    Spacer()
                }

                Button(tr("סגור", "Close")) {
                    showBeltSheet = false
                }
                .kmiFont(size: 14, weight: .semibold)
                .foregroundStyle(
                    KmiAppTheme.primary(for: colorScheme)
                )
                .padding(.horizontal, 12)
                .frame(minHeight: 44)

                if !isEnglish {
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                KmiAppTheme.surfaceVariant(for: colorScheme)
            )
        }
        .background(registrationFieldBackground)
        .environment(\.layoutDirection, .leftToRight)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func beltSelectionDot(_ belt: String) -> some View {
        Circle()
            .fill(beltColorForRegistration(belt))
            .frame(width: 14, height: 14)
            .overlay {
                if beltNeedsDarkBorderForRegistration(belt) {
                    Circle()
                        .stroke(
                            registrationFieldTextColor,
                            lineWidth: 1.5
                        )
                }
            }
            .accessibilityHidden(true)
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

            Button {
                focusedField = nil
                showBeltSheet = true
            } label: {
                HStack(spacing: 10) {
                    if !isEnglish {
                        Image(systemName: "chevron.down")
                            .kmiIconSize(13)
                            .fontWeight(.bold)
                            .accessibilityHidden(true)
                    }

                    Text(
                        s.belt.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                            ? tr("בחר דרגת חגורה", "Choose belt rank")
                            : beltDisplayNameForRegistration(s.belt)
                    )
                    .kmiFont(size: 15, weight: .semibold)
                    .foregroundStyle(
                        s.belt.isEmpty
                            ? registrationLabelColor
                            : registrationFieldTextColor
                    )
                    .multilineTextAlignment(formTextAlignment)
                    .frame(
                        maxWidth: .infinity,
                        alignment: formFrameAlignment
                    )

                    if isEnglish {
                        Image(systemName: "chevron.down")
                            .kmiIconSize(13)
                            .fontWeight(.bold)
                            .accessibilityHidden(true)
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
                    .kmiIconSize(13)
                    .fontWeight(.heavy)
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
                .kmiFont(size: 13, weight: .regular)
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
                    .kmiFont(size: 13, weight: .regular)
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

        if !(9...12).contains(
            s.phone.filter { $0.isNumber }.count
        ) {
            return tr(
                "נא להזין מספר טלפון תקין",
                "Please enter a valid phone number"
            )
        }

        if !s.email.contains("@") || !s.email.contains(".") {
            return tr("נא להזין מייל תקין", "Please enter a valid email")
        }

        if s.gender
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty {
            return tr(
                "חובה לבחור מין",
                "Gender is required"
            )
        }

        if s.birthDay.isEmpty {
            return tr(
                "חובה להזין יום לידה",
                "Birth day is required"
            )
        }

        guard let day = Int(s.birthDay),
              (1...31).contains(day) else {
            return tr(
                "יום לידה לא תקין",
                "Invalid birth day"
            )
        }

        if s.birthMonth.isEmpty {
            return tr(
                "חובה להזין חודש לידה",
                "Birth month is required"
            )
        }

        guard let month = Int(s.birthMonth),
              (1...12).contains(month) else {
            return tr(
                "חודש לידה לא תקין",
                "Invalid birth month"
            )
        }

        if s.birthYear.count != 4 {
            return tr(
                "חובה להזין שנת לידה (4 ספרות)",
                "Birth year is required (4 digits)"
            )
        }

        guard let year = Int(s.birthYear),
              (1900...2100).contains(year) else {
            return tr(
                "שנת לידה לא תקינה",
                "Invalid birth year"
            )
        }

        if !isEditingProfile &&
            !isGoogleAuth {

            if s.username
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .count < 3 {

                return tr(
                    "שם משתמש קצר מדי",
                    "Username is too short"
                )
            }

            if s.password.count < 6 {

                return tr(
                    "סיסמה חייבת להכיל לפחות 6 תווים",
                    "Password must contain at least 6 characters"
                )
            }
        }

        if s.belt
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .isEmpty {
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

        if !isAbroadSelection &&
            !isCurrentRegionAbroad {
            for branch in s.branchesArray {
                let selected = s.branchAssignments
                    .first { $0.branch == branch }?
                    .groups ?? []

                let displayBranch = displayJoinedValues(
                    [branch]
                )

                if selected.isEmpty {
                    return tr(
                        "יש לבחור לפחות קבוצה אחת לסניף \(displayBranch)",
                        "Choose at least one group for branch \(displayBranch)"
                    )
                }

                let available = Set(
                    availableGroups(for: branch)
                )

                if selected.contains(
                    where: { !available.contains($0) }
                ) {
                    return tr(
                        "יש לעדכן את בחירת הקבוצות בסניף \(displayBranch)",
                        "Update the selected groups for branch \(displayBranch)"
                    )
                }
            }
        }

        if !isEditingProfile,
           s.role == .coach {
            return tr(
                "הרשאת מאמן ניתנת לאחר אישור מהשרת",
                "Coach access is granted after server authorization"
            )
        }

        return nil
    }
    
    private func resetBranchSelectionAfterScopeChange() {
        branchGroupsExpansion.removeAll()

        s.region = ""
        s.branches.removeAll()
        s.groups.removeAll()
        s.branchAssignments.removeAll()
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

        if s.gender
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .isEmpty {

            s.gender =
                defaults.string(
                    forKey:
                        "gender"
                )
                ?? ""
        }

        /*
         * סיסמה אינה נטענת מאחסון מקומי.
         * ברישום חדש המשתמש מזין אותה מחדש,
         * ובעריכת פרופיל השדה כלל אינו נדרש.
         */
        s.password = ""

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

        s.wantsSms =
            defaults.object(
                forKey:
                    "subscribeSms"
            ) as? Bool
            ?? (
                defaults.object(
                    forKey:
                        "wantsSms"
                ) as? Bool
                ?? s.wantsSms
            )

        /*
         * בעריכת פרופיל תנאי השימוש כבר אושרו.
         * ברישום חדש ממשיכים לכבד את הערך
         * של תהליך הרישום.
         */
        if isEditingProfile {
            s.acceptsTerms =
                true
        } else {
            s.acceptsTerms =
                defaults.object(
                    forKey:
                        "acceptsTerms"
                ) as? Bool
                ?? s.acceptsTerms
        }

        if s.coachCode
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .isEmpty {
            s.coachCode =
                defaults.string(forKey: "coachCode") ??
                defaults.string(forKey: "coach_code") ??
                ""
        }
    }
}
