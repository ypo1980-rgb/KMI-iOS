import SwiftUI
import Foundation

struct RegisterFormView: View {

    let prefillPhone: String
    let prefillEmail: String
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

    init(
        prefillPhone: String = "",
        prefillEmail: String = "",
        onBack: @escaping () -> Void,
        onSubmit: @escaping (RegistrationFormState) -> Void,
        onReadMoreTerms: @escaping () -> Void = {}
    ) {
        self.prefillPhone = prefillPhone
        self.prefillEmail = prefillEmail
        self.onBack = onBack
        self.onSubmit = onSubmit
        self.onReadMoreTerms = onReadMoreTerms

        var initial = RegistrationFormState()
        initial.phone = prefillPhone
        initial.email = prefillEmail
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
                            Text("אימות מאמן")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            field(title: "קוד מאמן", text: $s.coachCode, keyboard: .default)

                            Text("הקוד מתקבל מהמאמן הראשי/מנהל המכון. ללא קוד לא ניתן להירשם כמאמן.")
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

                        beltPicker

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
                        onSubmit(s)

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
        .onChange(of: s.region) { _, _ in
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
        return Button {
            s.role = role
        } label: {
            Text(role.rawValue)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.white.opacity(0.25) : Color.clear)
        }
        .foregroundStyle(.white)
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
                ForEach(regions, id: \.self) { Text($0) }
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

        if s.username.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 { return "שם משתמש קצר מדי" }
        if s.password.count < 6 { return "סיסמה חייבת להכיל לפחות 6 תווים" }
        if !s.acceptsTerms { return "חובה לאשר תנאי שימוש ומדיניות פרטיות" }

        if s.branches.isEmpty { return "חובה לבחור לפחות סניף אחד" }
        if s.groups.isEmpty { return "חובה לבחור לפחות קבוצה אחת" }

        if s.role == .coach {
            let code = s.coachCode.trimmingCharacters(in: .whitespacesAndNewlines)
            if code.count < 4 { return "מאמן חייב להזין קוד מאמן תקין" }
        }
        return nil
    }

    private func summarizeSet(_ set: Set<String>) -> String {
        if set.isEmpty { return "" }
        return set.joined(separator: " + ")
    }
}
