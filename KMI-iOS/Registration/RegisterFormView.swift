import SwiftUI
import Foundation

struct RegisterFormView: View {

    let prefillPhone: String
    let prefillEmail: String
    let initialRole: UserRole
    let onBack: () -> Void
    let onSubmit: (RegistrationFormState) -> Void
    let onReadMoreTerms: () -> Void

    @State private var s: RegistrationFormState
    @State private var isSubmitting: Bool = false

    private let regions = ["השרון", "מרכז", "צפון", "דרום", "ירושלים"]
    
    private var branchesOptions: [String] {
        TrainingCatalogIOS.branchesFor(region: s.region)
    }

    private var groupsOptions: [String] {
        let selectedBranches = s.branches.isEmpty ? branchesOptions : Array(s.branches)

        let all = selectedBranches.flatMap { branch in
            TrainingCatalogIOS.ageGroupsByBranch[branch] ?? []
        }

        return Array(Set(all)).sorted()
    }

    private let belts = ["ללא", "צהובה", "כתומה", "ירוקה", "כחולה", "חומה", "שחורה"]

    @State private var showBranchesSheet = false
    @State private var showGroupsSheet = false

    private var normalizedPhone: String {
        s.phone.filter { $0.isNumber }
    }

    private var normalizedEmail: String {
        s.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isWhitelistedCoach: Bool {
        CoachWhitelist.isWhitelisted(
            phone: normalizedPhone,
            email: normalizedEmail
        )
    }

    private var lockToCoach: Bool {
        isWhitelistedCoach
    }

    private var lockToTrainee: Bool {
        !isWhitelistedCoach
    }

    init(
        prefillPhone: String = "",
        prefillEmail: String = "",
        initialRole: UserRole = .trainee,
        onBack: @escaping () -> Void,
        onSubmit: @escaping (RegistrationFormState) -> Void,
        onReadMoreTerms: @escaping () -> Void = {}
    ) {
        self.prefillPhone = prefillPhone
        self.prefillEmail = prefillEmail
        self.initialRole = initialRole
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
        ZStack {
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.85),
                    Color.blue.opacity(0.75),
                    Color.cyan.opacity(0.45)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {

                    headerBar

                    roleTabs

                    if s.role == .coach {
                        card {
                            Text("רישום מאמן מורשה")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("לאחר השלמת הרישום יופק עבורך קוד מאמן אישי. יש לשמור אותו לצורך התחברות למערכת.")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    card {
                        field(title: "שם מלא", text: $s.fullName)
                        field(title: "טלפון", text: $s.phone, keyboard: .phonePad)
                        field(title: "מייל", text: $s.email, keyboard: .emailAddress)
                    }

                    card {
                        Text("תאריך לידה")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        dobRow

                        genderPicker

                        field(title: "שם משתמש", text: $s.username, keyboard: .default)

                        passwordField
                        regionPicker
                    }
                    
                    card {
                        multiSelectRow(
                            title: "סניפים (עד 3)",
                            valueText: summarizeSet(s.branches),
                            onTap: { showBranchesSheet = true }
                        )

                        multiSelectRow(
                            title: "קבוצות (עד 3)",
                            valueText: summarizeSet(s.groups),
                            onTap: { showGroupsSheet = true }
                        )

                        if s.role != .coach {
                            beltPicker
                        }

                        Toggle(isOn: $s.wantsSms) {
                            Text("ארצה לקבל עדכונים בהודעות\nSMS לגבי אימונים קרובים")
                        }

                        termsRow
                    }

                    if let err = validationError {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            }

                            Text(isSubmitting ? "שומר..." : "סיום רישום")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.purple.opacity(0.9))
                    .disabled(validationError != nil || isSubmitting)

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
            }
        }
        .sheet(isPresented: $showBranchesSheet) {
            MultiSelectSheet(
                title: "בחר סניפים (עד 3)",
                options: branchesOptions,
                maxSelected: 3,
                selected: $s.branches
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showGroupsSheet) {
            MultiSelectSheet(
                title: "בחר קבוצות (עד 3)",
                options: groupsOptions,
                maxSelected: 3,
                selected: $s.groups
            )
            .presentationDetents([.medium, .large])
        }
        .onChange(of: s.region) { _, newRegion in
            print("🧭 region changed ->", newRegion)

            s.branches.removeAll()
            s.groups.removeAll()
        }
        .onChange(of: s.branches) { _, newBranches in
            if newBranches.isEmpty {
                s.groups.removeAll()
                return
            }

            let validGroups = Set(
                Array(newBranches).flatMap { branch in
                    TrainingCatalogIOS.ageGroupsByBranch[branch] ?? []
                }
            )

            s.groups = s.groups.filter { validGroups.contains($0) }
        }
        .onAppear {
            loadSavedProfileIfNeeded()

            // ✅ לוודא שה-region תמיד חוקי עבור ה-Picker
            if s.region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !regions.contains(s.region) {

                s.region = regions.first ?? ""
            }

            // ✅ נעילה אוטומטית 1:1 כמו באנדרואיד
            s.role = lockToCoach ? .coach : .trainee

            print("📝 RegisterFormView.onAppear")
            print("📝 region =", s.region)
            print("📝 gender =", s.gender)
            print("📝 belt =", s.belt)
            print("📝 branches =", Array(s.branches))
            print("📝 groups =", Array(s.groups))
            print("📝 isWhitelistedCoach =", isWhitelistedCoach)
            print("📝 lockedRole =", s.role.rawValue)
        }
        .onChange(of: normalizedPhone) { _, _ in
            let forcedRole: UserRole = lockToCoach ? .coach : .trainee
            if s.role != forcedRole {
                s.role = forcedRole
            }
        }
        .onChange(of: normalizedEmail) { _, _ in
            let forcedRole: UserRole = lockToCoach ? .coach : .trainee
            if s.role != forcedRole {
                s.role = forcedRole
            }
        }
    }
        
    private var headerBar: some View {
        HStack {
            Button(action: onBack) {
                Text("חזרה")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Spacer()
            Text("טופס רישום")
                .font(.title2).bold()
                .foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 64, height: 1)
        }
        .padding(.bottom, 6)
    }

    private var roleTabs: some View {
        HStack(spacing: 0) {
            tabButton(.coach)
            tabButton(.trainee)
        }
        .background(Color.white.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func tabButton(_ role: UserRole) -> some View {
        let isSelected = s.role == role
        let isLocked = (role == .coach && lockToTrainee) || (role == .trainee && lockToCoach)

        return Button {
            if isLocked { return }
            s.role = role
        } label: {
            VStack(spacing: 4) {
                Text(role.rawValue)
                    .font(.headline)

                if role == .coach && lockToTrainee {
                    Text("מורשים בלבד")
                        .font(.caption2.bold())
                }

                if role == .trainee && lockToCoach {
                    Text("מאמן בלבד")
                        .font(.caption2.bold())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.white.opacity(0.25) : Color.clear)
        }
        .foregroundStyle(.white.opacity(isLocked ? 0.65 : 1))
        .disabled(isLocked)
    }
    
    private func card(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(spacing: 10, content: content)
            .padding(14)
            .background(Color.white.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func field(title: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        TextField(title, text: text)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(12)
            .background(Color.black.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var dobRow: some View {
        HStack(spacing: 10) {
            dobField("יום", $s.birthDay, maxLen: 2)
            dobField("חודש", $s.birthMonth, maxLen: 2)
            dobField("שנה", $s.birthYear, maxLen: 4)
        }
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
        .padding(12)
        .background(Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var passwordField: some View {
        HStack {
            Group {
                if s.showPassword {
                    TextField("סיסמה", text: $s.password)
                } else {
                    SecureField("סיסמה", text: $s.password)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            Button {
                s.showPassword.toggle()
            } label: {
                Image(systemName: s.showPassword ? "eye.slash" : "eye")
                    .foregroundStyle(.gray)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var regionPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("אזור")
                .font(.subheadline)
                .foregroundStyle(.gray)

            Picker("", selection: $s.region) {
                Text("בחר אזור").tag("")
                ForEach(regions, id: \.self) { region in
                    Text(region).tag(region)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.black.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var genderPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("מין")
                .font(.subheadline)
                .foregroundStyle(.gray)

            Picker("", selection: $s.gender) {
                Text("בחר").tag("")
                Text("זכר").tag("male")
                Text("נקבה").tag("female")
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.black.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var beltPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("דרגת חגורה נוכחית (ק.מ.י)")
                .font(.subheadline)
                .foregroundStyle(.gray)

            Picker("", selection: $s.belt) {
                ForEach(belts, id: \.self) { Text($0) }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.black.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func multiSelectRow(title: String, valueText: String, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.gray)

                HStack {
                    Text(valueText.isEmpty ? "בחר…" : valueText)
                        .foregroundStyle(valueText.isEmpty ? .gray : .primary)
                        .lineLimit(2)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .foregroundStyle(.gray)
                }
                .padding(12)
                .background(Color.black.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .buttonStyle(.plain)
    }

    private var termsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $s.acceptsTerms) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("אני מאשר את תנאי השימוש\nומדיניות הפרטיות")
                    Button("קרא עוד") { onReadMoreTerms() }
                        .font(.subheadline)
                }
            }
        }
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

        if s.username.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 { return "שם משתמש קצר מדי" }
        if s.password.count < 6 { return "סיסמה חייבת להכיל לפחות 6 תווים" }
        if !s.acceptsTerms { return "חובה לאשר תנאי שימוש ומדיניות פרטיות" }

        if s.region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "חובה לבחור אזור" }
        if s.branches.isEmpty { return "חובה לבחור לפחות סניף אחד" }
        if s.groups.isEmpty { return "חובה לבחור לפחות קבוצה אחת" }

        if lockToCoach && s.role != .coach {
            return "מאמן מורשה חייב להירשם כמאמן בלבד"
        }

        if lockToTrainee && s.role != .trainee {
            return "ההרשמה כמאמן מותרת רק למאמנים מורשים"
        }

        if lockToCoach && s.role != .coach {
            return "מאמן מורשה חייב להירשם כמאמן בלבד"
        }

        if lockToTrainee && s.role != .trainee {
            return "ההרשמה כמאמן מותרת רק למאמנים מורשים"
        }

        if s.role == .coach {
            if !isWhitelistedCoach { return "הרישום כמאמן מותר רק למאמנים מורשים" }
        }

        return nil
    }
    
    private func summarizeSet(_ set: Set<String>) -> String {
        if set.isEmpty { return "" }
        return set.joined(separator: " + ")
    }

    private func loadSavedProfileIfNeeded() {
        let defaults = UserDefaults.standard

        if s.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.fullName = defaults.string(forKey: "fullName") ?? ""
        }

        if s.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.phone = defaults.string(forKey: "phone") ?? ""
        }

        if s.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.email = defaults.string(forKey: "email") ?? ""
        }

        if s.region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.region = defaults.string(forKey: "region") ?? s.region
        }

        if s.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.username = defaults.string(forKey: "username") ?? ""
        }

        if s.birthDay.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.birthDay = defaults.string(forKey: "birthDay") ?? ""
        }

        if s.birthMonth.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.birthMonth = defaults.string(forKey: "birthMonth") ?? ""
        }

        if s.birthYear.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.birthYear = defaults.string(forKey: "birthYear") ?? ""
        }

        if s.gender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.gender = defaults.string(forKey: "gender") ?? ""
        }

        if s.password.isEmpty {
            s.password = defaults.string(forKey: "password") ?? ""
        }

        let storedRole = (defaults.string(forKey: "user_role") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if storedRole == "coach" {
            s.role = .coach
        } else if storedRole == "trainee" {
            s.role = .trainee
        }

        let storedBranches = defaults.stringArray(forKey: "branches") ?? []
        if s.branches.isEmpty, !storedBranches.isEmpty {
            s.branches = Set(storedBranches)
        } else {
            let singleBranch = (defaults.string(forKey: "branch") ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if s.branches.isEmpty, !singleBranch.isEmpty {
                s.branches = [singleBranch]
            }
        }

        let storedGroups = defaults.stringArray(forKey: "groups") ?? []
        if s.groups.isEmpty, !storedGroups.isEmpty {
            s.groups = Set(storedGroups)
        } else {
            let singleGroup = (defaults.string(forKey: "group") ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if s.groups.isEmpty, !singleGroup.isEmpty {
                s.groups = [singleGroup]
            }
        }

        let storedBelt = (defaults.string(forKey: "current_belt") ?? defaults.string(forKey: "belt_current") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if s.belt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || s.belt == "ללא" {
            switch storedBelt.lowercased() {
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
            case "black", "שחור", "שחורה":
                s.belt = "שחורה"
            default:
                break
            }
        }

        s.wantsSms = defaults.object(forKey: "wantsSms") as? Bool ?? s.wantsSms
        s.acceptsTerms = defaults.object(forKey: "acceptsTerms") as? Bool ?? s.acceptsTerms

        if s.coachCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.coachCode = defaults.string(forKey: "coachCode") ?? ""
        }
    }
}
