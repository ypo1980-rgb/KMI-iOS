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
    @State private var displayedBranchValue: String = ""
    @State private var displayedGroupValue: String = ""

    @AppStorage("active_branch") private var storedActiveBranch: String = ""
    @AppStorage("active_group") private var storedActiveGroup: String = ""

    private let israelRegions = ["השרון", "מרכז", "צפון", "דרום", "ירושלים"]

    private var regions: [String] {
        isAbroadSelection ? TrainingCatalogIOS.abroadRegions() : israelRegions
    }

    private var isCurrentRegionAbroad: Bool {
        TrainingCatalogIOS.isAbroadRegion(s.region)
    }
    
    private var branchesOptions: [String] {
        TrainingCatalogIOS.branchesFor(region: s.region)
    }

    private var groupsOptions: [String] {
        if isAbroadSelection || isCurrentRegionAbroad {
            return ["בוגרים"]
        }

        let selectedBranches = s.branches.isEmpty ? branchesOptions : Array(s.branches)

        let all = selectedBranches.flatMap { branch in
            TrainingCatalogIOS.ageGroupsByBranch[branch] ?? []
        }

        return Array(Set(all)).sorted()
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

    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"
    @AppStorage("selected_language_code") private var selectedLanguageCode: String = "he"

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
        isEnglish ? .leftToRight : .rightToLeft
    }

    private var formTextAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var formFrameAlignment: Alignment {
        isEnglish ? .leading : .trailing
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

    private var normalizedPhone: String {
        s.phone.filter { $0.isNumber }
    }

    private var normalizedEmail: String {
        s.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isGoogleAuth: Bool {
        let defaults = UserDefaults.standard

        let authProvider = defaults.string(forKey: "authProvider") ?? ""
        let googleLogin = defaults.bool(forKey: "google_login")
        let skipOtp = defaults.bool(forKey: "skip_otp")

        return authProvider == "google" &&
            googleLogin &&
            skipOtp &&
            !prefillEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var registrationFieldBorder: Color {
        Color(red: 0.824, green: 0.769, blue: 0.890) // #D2C4E3
    }

    private var registrationPrimaryPurple: Color {
        Color(red: 0.486, green: 0.302, blue: 1.0) // #7C4DFF
    }

    private var registrationLabelColor: Color {
        Color(red: 0.278, green: 0.333, blue: 0.412) // #475569
    }

    private var displayedBranchesText: String {
        let persisted = storedActiveBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        if !persisted.isEmpty { return persisted }

        let manual = s.activeBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        if !manual.isEmpty { return manual }

        let arr = s.branches
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()

        return arr.joined(separator: " + ")
    }

    private var displayedGroupsText: String {
        let persisted = storedActiveGroup.trimmingCharacters(in: .whitespacesAndNewlines)
        if !persisted.isEmpty { return persisted }

        let manual = s.activeGroup.trimmingCharacters(in: .whitespacesAndNewlines)
        if !manual.isEmpty { return manual }

        let arr = s.groups
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()

        return arr.joined(separator: " + ")
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

    private var lockToCoach: Bool {
        isWhitelistedCoach && !isSuperTester
    }

    private var lockToTrainee: Bool {
        !isWhitelistedCoach && !isSuperTester
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
                print("🧭 phone changed, role after gate =", s.role.rawValue)
            }
            .onChange(of: normalizedEmail) { _, _ in
                applyRoleGate()
                print("🧭 email changed, role after gate =", s.role.rawValue)
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
            headerBar

            roleTabs

            coachNoticeCard

            personalDetailsSection

            accountSection

            branchSection

            preferencesSection

            Spacer(minLength: 110)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
    }

    @ViewBuilder
    private var coachNoticeCard: some View {
        if s.role == .coach {
            sectionCard(title: tr("רישום מאמן מורשה", "Authorized coach registration")) {
                Text(
                    tr(
                        "לאחר השלמת הרישום יופק עבורך קוד מאמן אישי. יש לשמור אותו לצורך התחברות למערכת ולפעולות מתקדמות.",
                        "After completing registration, a personal coach code will be created for you. Keep it for login and advanced actions."
                    )
                )
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(red: 0.28, green: 0.33, blue: 0.41))
                .frame(maxWidth: .infinity, alignment: formFrameAlignment)
                .multilineTextAlignment(formTextAlignment)
            }
        }
    }

    private var personalDetailsSection: some View {
        sectionCard(title: tr("פרטים אישיים", "Personal details")) {
            field(title: tr("שם מלא", "Full name"), text: $s.fullName)
            field(title: tr("טלפון", "Phone"), text: $s.phone, keyboard: .phonePad)
            field(title: tr("מייל", "Email"), text: $s.email, keyboard: .emailAddress)

            Text(tr("מין המשתמש", "Gender"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(registrationLabelColor)
                .frame(maxWidth: .infinity, alignment: formFrameAlignment)
                .multilineTextAlignment(formTextAlignment)

            genderPicker

            Text(tr("תאריך לידה", "Date of birth"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(registrationLabelColor)
                .frame(maxWidth: .infinity, alignment: formFrameAlignment)
                .multilineTextAlignment(formTextAlignment)

            dobRow
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        if !isGoogleAuth {
            sectionCard(title: tr("חשבון משתמש", "User account")) {
                field(title: tr("שם משתמש", "Username"), text: $s.username, keyboard: .default)

                passwordField
            }
        }
    }

    private var branchSection: some View {
        sectionCard(title: tr("שיוך לסניף", "Branch assignment")) {
            branchScopePicker

            regionPicker

            multiSelectRow(
                title: isAbroadSelection
                    ? tr("סניפים בחו״ל (עד 3)", "Branches abroad (up to 3)")
                    : tr("סניפים בארץ (עד 3)", "Branches in Israel (up to 3)"),
                valueText: displayedBranchesText,
                onTap: { showBranchesSheet = true }
            )

            if !isAbroadSelection {
                multiSelectRow(
                    title: tr("קבוצות (עד 3)", "Groups (up to 3)"),
                    valueText: displayedGroupsText,
                    onTap: { showGroupsSheet = true }
                )
            }

            beltPicker
        }
    }

    private var preferencesSection: some View {
        sectionCard(title: tr("העדפות ואישורים", "Preferences and approvals")) {
            Toggle(isOn: $s.wantsSms) {
                Text(
                    tr(
                        "ארצה לקבל עדכונים בהודעות\nSMS לגבי אימונים קרובים",
                        "I would like to receive SMS updates\nabout upcoming trainings"
                    )
                )
                .frame(maxWidth: .infinity, alignment: formFrameAlignment)
                .multilineTextAlignment(formTextAlignment)
            }

            termsRow
        }
    }

    private var branchesSheet: some View {
        MultiSelectSheet(
            title: isAbroadSelection
                ? tr("בחר סניפים בחו״ל (עד 3)", "Choose branches abroad (up to 3)")
                : tr("בחר סניפים בארץ (עד 3)", "Choose branches in Israel (up to 3)"),
            options: branchesOptions,
            maxSelected: 3,
            selected: $s.branches
        )
        .presentationDetents([.medium, .large])
    }

    private var groupsSheet: some View {
        MultiSelectSheet(
            title: tr("בחר קבוצות (עד 3)", "Choose groups (up to 3)"),
            options: groupsOptions,
            maxSelected: 3,
            selected: $s.groups
        )
        .presentationDetents([.medium, .large])
    }
    
    private func handleRegionChange(oldRegion: String, newRegion: String) {
        print("🧭 region changed ->", newRegion)

        guard didFinishInitialLoad else {
            print("🧭 skip clearing branches/groups during initial load")
            return
        }

        let oldClean = oldRegion.trimmingCharacters(in: .whitespacesAndNewlines)
        let newClean = newRegion.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !oldClean.isEmpty else {
            print("🧭 skip clearing because old region is empty during initial setup")
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
            Array(newBranches).flatMap { branch in
                TrainingCatalogIOS.ageGroupsByBranch[branch] ?? []
            }
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
            if s.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                s.email = prefillEmail
            }

            if s.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                s.username = prefillEmail
            }

            if s.password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                s.password = "GOOGLE_AUTH"
            }
        }

        if s.branchType == "abroad" ||
            TrainingCatalogIOS.isAbroadRegion(s.region) ||
            s.branches.contains(where: { TrainingCatalogIOS.isAbroadBranch($0) }) {
            isAbroadSelection = true
            s.branchType = "abroad"
        } else {
            isAbroadSelection = false
            s.branchType = "israel"
        }

        let defaults = UserDefaults.standard

        let savedBranch =
            defaults.string(forKey: "active_branch") ??
            defaults.string(forKey: "branch") ??
            defaults.string(forKey: "kmi.user.branch") ??
            ""

        if !savedBranch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.branches = [savedBranch]
            s.activeBranch = savedBranch
            displayedBranchValue = savedBranch
            storedActiveBranch = savedBranch
        } else {
            displayedBranchValue = storedActiveBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let savedGroup =
            defaults.string(forKey: "active_group") ??
            defaults.string(forKey: "group") ??
            defaults.string(forKey: "kmi.user.group") ??
            ""

        if !savedGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.groups = [savedGroup]
            s.activeGroup = savedGroup
            displayedGroupValue = savedGroup
            storedActiveGroup = savedGroup
        } else {
            displayedGroupValue = storedActiveGroup.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if s.region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !regions.contains(s.region) {
            s.region = regions.first ?? ""
        }

        s.role = initialRole
        applyRoleGate()

        print("📝 RegisterFormView.onAppear")
        print("📝 region =", s.region)
        print("📝 branchType =", s.branchType)
        print("📝 gender =", s.gender)
        print("📝 belt =", s.belt)
        print("📝 branches =", Array(s.branches))
        print("📝 groups =", Array(s.groups))
        print("📝 isWhitelistedCoach =", isWhitelistedCoach)
        print("📝 isSuperTester =", isSuperTester)
        print("📝 initialRole =", initialRole.rawValue)
        print("📝 active role =", s.role.rawValue)
        print("📝 displayedBranchValue =", displayedBranchValue)
        print("📝 displayedGroupValue =", displayedGroupValue)
        print("📝 storedActiveBranch =", storedActiveBranch)
        print("📝 storedActiveGroup =", storedActiveGroup)

        DispatchQueue.main.async {
            didFinishInitialLoad = true
            print("🧭 didFinishInitialLoad = true")
        }
    }
    
    private func applyRoleGate() {
        if isSuperTester {
            print("KMI_REGISTRATION iOS: role gate bypassed for super tester")
            return
        }

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
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Spacer()

            Text(localizedScreenTitle(screenTitle))
                .font(.title2)
                .bold()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer()

            Color.clear.frame(width: 64, height: 1)
        }
        .environment(\.layoutDirection, screenLayoutDirection)
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
        .background(Color(red: 0.427, green: 0.310, blue: 0.910).opacity(0.96)) // #6D4FE8
        .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
        .shadow(color: Color.black.opacity(0.16), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 10)
    }

    private func tabButton(_ role: UserRole) -> some View {
        let isSelected = s.role == role
        let title = role == .trainee ? tr("מתאמן", "Trainee") : tr("מאמן", "Coach")

        return Button {
            if !isSuperTester {
                if role == .coach && !isWhitelistedCoach {
                    s.role = .trainee
                    print("KMI_REGISTRATION iOS: coach tab blocked - not whitelisted")
                    return
                }

                if role == .trainee && isWhitelistedCoach {
                    s.role = .coach
                    print("KMI_REGISTRATION iOS: trainee tab blocked - whitelisted coach")
                    return
                }
            }

            s.role = role
        } label: {
            ZStack(alignment: .bottom) {
                Text(title)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isSelected {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 82, height: 3)
                }
            }
            .background(isSelected ? Color.white.opacity(0.14) : Color.clear)
        }
        .buttonStyle(.plain)
    }
    
    private func card(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(spacing: 10, content: content)
            .padding(14)
            .background(Color.white.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func sectionCard(
        title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(red: 0.12, green: 0.16, blue: 0.22))
                .frame(maxWidth: .infinity, alignment: formFrameAlignment)
                .multilineTextAlignment(formTextAlignment)

            Rectangle()
                .fill(Color(red: 0.85, green: 0.80, blue: 0.91))
                .frame(height: 1)

            content()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.96, green: 0.93, blue: 0.97).opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(red: 0.85, green: 0.80, blue: 0.91), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 2)
        )
    }

    private func field(title: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        TextField(title, text: text)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .multilineTextAlignment((keyboard == .phonePad || keyboard == .emailAddress) ? .leading : .trailing)
            .environment(\.layoutDirection, (keyboard == .phonePad || keyboard == .emailAddress) ? .leftToRight : .rightToLeft)
            .padding(12)
            .frame(minHeight: 46)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 0.82, green: 0.77, blue: 0.89), lineWidth: 1)
            )
    }

    private var submitBottomBar: some View {
        VStack(spacing: 10) {
            if let err = validationError {
                Text(err)
                    .foregroundStyle(Color.red)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }

            Button {
                guard !isSubmitting, validationError == nil else { return }
                isSubmitting = true

                // ✅ snapshot מלא של הטופס לפני שליחה
                let submitted = s
                print("📝 RegisterFormView: captured snapshot before submit")
                print("📝 submitted.fullName =", submitted.fullName)
                print("📝 submitted.phone =", submitted.phone)
                print("📝 submitted.email =", submitted.email)
                print("📝 submitted.region =", submitted.region)
                print("📝 submitted.branches =", Array(submitted.branches))
                print("📝 submitted.groups =", Array(submitted.groups))

                DispatchQueue.main.async {
                    print("📝 RegisterFormView: calling onSubmit(snapshot)")
                    onSubmit(submitted)
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
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
                            ? localizedSubmitTitle(submittingTitle)
                            : localizedSubmitTitle(submitTitle)
                    )
                    .font(.system(size: 15, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
            }
            .buttonStyle(.plain)
            .foregroundStyle((validationError == nil && !isSubmitting) ? .white : .black)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill((validationError == nil && !isSubmitting)
                          ? Color(red: 0.486, green: 0.302, blue: 1.0)
                          : Color(red: 0.690, green: 0.745, blue: 0.773)) // #B0BEC5
            )
            .disabled(validationError != nil || isSubmitting)
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
        HStack(spacing: 10) {
            dobField("יום", $s.birthDay, maxLen: 2)
            dobField("חודש", $s.birthMonth, maxLen: 2)
            dobField("שנה", $s.birthYear, maxLen: 4)
        }
        .frame(minHeight: 56)
    }

    private func dobField(_ title: String, _ binding: Binding<String>, maxLen: Int) -> some View {
        TextField(title, text: Binding(
            get: { binding.wrappedValue },
            set: { newValue in
                let digits = newValue.filter { $0.isNumber }
                binding.wrappedValue = String(digits.prefix(maxLen))
            }
        ))
        .keyboardType(.numberPad)
        .multilineTextAlignment(.center)
        .font(.system(size: 17, weight: .bold))
        .foregroundStyle(.black)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(registrationFieldBorder, lineWidth: 1)
        )
    }

    private var passwordField: some View {
        HStack(spacing: 10) {
            Button {
                s.showPassword.toggle()
            } label: {
                Image(systemName: s.showPassword ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.gray)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)

            Group {
                if s.showPassword {
                    TextField("סיסמה", text: $s.password)
                } else {
                    SecureField("סיסמה", text: $s.password)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .multilineTextAlignment(.trailing)
            .environment(\.layoutDirection, .rightToLeft)
            .foregroundStyle(.black)
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(registrationFieldBorder, lineWidth: 1)
        )
    }

    private var regionPicker: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(isAbroadSelection ? "מדינה" : "אזור")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(registrationLabelColor)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Picker("", selection: $s.region) {
                Text(isAbroadSelection ? "בחר מדינה" : "בחר אזור").tag("")
                ForEach(regions, id: \.self) { region in
                    Text(region).tag(region)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 12)
            .frame(height: 52)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(registrationFieldBorder, lineWidth: 1)
            )
            .environment(\.layoutDirection, .rightToLeft)
        }
    }

    private var branchScopePicker: some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 8) {
            Text(tr("בחירת סוג סניף", "Branch type"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(red: 0.28, green: 0.33, blue: 0.41))
                .frame(maxWidth: .infinity, alignment: formFrameAlignment)
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? .white : Color(red: 0.28, green: 0.33, blue: 0.41))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Color(red: 0.486, green: 0.302, blue: 1.0) : Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    isSelected ? Color(red: 0.424, green: 0.302, blue: 1.0) : Color(red: 0.82, green: 0.77, blue: 0.89),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var genderPicker: some View {
        HStack(spacing: 12) {
            genderChip(
                title: "זכר",
                value: "male",
                selectedColor: Color(red: 0.055, green: 0.647, blue: 0.914)
            )

            genderChip(
                title: "נקבה",
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selected ? .white : Color(red: 0.28, green: 0.33, blue: 0.41))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selected ? selectedColor : Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    selected ? selectedColor : Color(red: 0.82, green: 0.77, blue: 0.89),
                                    lineWidth: selected ? 2 : 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
    }
    
    private var beltPicker: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("דרגת חגורה נוכחית (ק.מ.י)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(red: 0.28, green: 0.33, blue: 0.41))
                .frame(maxWidth: .infinity, alignment: .trailing)

            Picker("", selection: $s.belt) {
                Text("בחר דרגת חגורה").tag("")
                ForEach(belts, id: \.self) { belt in
                    Text(belt).tag(belt)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 0.82, green: 0.77, blue: 0.89), lineWidth: 1)
            )
        }
    }

    private func multiSelectRow(title: String, valueText: String, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            VStack(alignment: .trailing, spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(registrationLabelColor)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                HStack(spacing: 10) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.gray)

                    Text(valueText.isEmpty ? "בחר…" : valueText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(valueText.isEmpty ? .gray : .black)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 52)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(registrationFieldBorder, lineWidth: 1)
                )
            }
        }
        .buttonStyle(.plain)
    }

    private var termsRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Toggle("", isOn: $s.acceptsTerms)
                .labelsHidden()
                .toggleStyle(.switch)

            VStack(alignment: .trailing, spacing: 2) {
                Text("אני מאשר את תנאי השימוש ומדיניות הפרטיות")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)

                Button(action: onReadMoreTerms) {
                    Text("קרא עוד")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(red: 0.486, green: 0.302, blue: 1.0))
                        .underline()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private var validationError: String? {
        if s.fullName.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 { return "נא להזין שם מלא תקין" }
        if s.phone.filter({ $0.isNumber }).count < 9 { return "נא להזין מספר טלפון תקין" }
        if !s.email.contains("@") || !s.email.contains(".") { return "נא להזין מייל תקין" }

        if let d = Int(s.birthDay), !(1...31).contains(d) { return "יום לידה לא תקין" }
        if s.birthDay.isEmpty { return "חובה להזין יום לידה" }

        if let m = Int(s.birthMonth), !(1...12).contains(m) { return "חודש לידה לא תקין" }
        if s.birthMonth.isEmpty { return "חובה להזין חודש לידה" }

        if let y = Int(s.birthYear), !(1900...2100).contains(y) { return "שנת לידה לא תקינה" }
        if s.birthYear.count != 4 { return "חובה להזין שנת לידה (4 ספרות)" }

        if s.gender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "חובה לבחור מין" }

        if !isGoogleAuth {
            if s.username.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 { return "שם משתמש קצר מדי" }
            if s.password.count < 6 { return "סיסמה חייבת להכיל לפחות 6 תווים" }
        }

        if s.belt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "חובה לבחור דרגת חגורה"
        }

        if !s.acceptsTerms { return "חובה לאשר תנאי שימוש ומדיניות פרטיות" }

        if s.region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return isAbroadSelection ? "חובה לבחור מדינה" : "חובה לבחור אזור"
        }

        if s.branches.isEmpty {
            return isAbroadSelection ? "חובה לבחור לפחות סניף אחד בחו״ל" : "חובה לבחור לפחות סניף אחד בארץ"
        }

        if !isAbroadSelection && s.groups.isEmpty {
            return "חובה לבחור לפחות קבוצה אחת"
        }

        if s.role == .coach, !isWhitelistedCoach {
            return "הרישום כמאמן מותר רק למאמנים מורשים"
        }

        return nil
    }
    
    private func summarizeSet(_ set: Set<String>) -> String {
        let cleaned = set
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if cleaned.isEmpty {
            return ""
        }

        return cleaned.sorted().joined(separator: " + ")
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

        print("📝 loadSavedProfileIfNeeded loaded region =", s.region)
        print("📝 loadSavedProfileIfNeeded loaded branches =", Array(s.branches))
        print("📝 loadSavedProfileIfNeeded loaded groups =", Array(s.groups))
        print("📝 loadSavedProfileIfNeeded activeBranch =", s.activeBranch)
        print("📝 loadSavedProfileIfNeeded activeGroup =", s.activeGroup)
    }
}
