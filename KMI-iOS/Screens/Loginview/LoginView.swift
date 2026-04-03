import SwiftUI

struct LoginView: View {

    let initialRole: LoginRole
    let onBackToChoice: () -> Void
    let onGoToRegister: () -> Void
    let onLoginSuccess: () -> Void

    @EnvironmentObject private var auth: AuthViewModel

    enum LoginRole: String, CaseIterable, Identifiable {
        case trainee = "מתאמן"
        case coach = "מאמן"
        var id: String { rawValue }
    }

    init(
        initialRole: LoginRole = .trainee,
        onBackToChoice: @escaping () -> Void,
        onGoToRegister: @escaping () -> Void,
        onLoginSuccess: @escaping () -> Void
    ) {
        self.initialRole = initialRole
        self.onBackToChoice = onBackToChoice
        self.onGoToRegister = onGoToRegister
        self.onLoginSuccess = onLoginSuccess
        _role = State(initialValue: initialRole)
    }
    
    @State private var role: LoginRole
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var coachCode: String = ""

    @State private var rememberMe: Bool = true
    @State private var showPassword: Bool = false
    @State private var didTriggerSuccess: Bool = false

    @State private var showForgotPasswordSheet: Bool = false
    @State private var resetEmail: String = ""
    @State private var resetMessage: String? = nil

    private let savedUsernameKey = "remember_username"
    private let savedPasswordKey = "remember_password"
    private let rememberMeKey = "remember_me_login"

    var body: some View {
        ZStack {
            LoginGradientBackground()

            VStack(spacing: 0) {
                AuthTopBar(
                    title: "התחברות",
                    onBack: onBackToChoice
                )

                KmiIconStripBar(
                    items: KmiIconStripItem.allCases,
                    selected: nil
                ) { item in
                    switch item {
                    case .home:
                        onBackToChoice()

                    case .settings:
                        break

                    case .search:
                        break

                    case .share:
                        break

                    case .assistant:
                        break
                    }
                }
                .background(Color.white.opacity(0.92))

                Spacer()

                VStack(spacing: 14) {

                    RoleTabs(
                        leftTitle: "מאמן",
                        rightTitle: "מתאמן",
                        selected: (role == .coach ? .left : .right),
                        onSelect: { sel in
                            role = (sel == .left ? .coach : .trainee)
                        }
                    )

                    FormCard {
                        VStack(spacing: 14) {

                            if let err = auth.errorText, !err.isEmpty {
                                Text(err)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 10)
                            }

                            LabeledField(title: "שם משתמש") {
                                TextField("", text: $username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .multilineTextAlignment(.center)
                            }

                            LabeledField(title: "סיסמה") {
                                HStack(spacing: 10) {
                                    Button {
                                        showPassword.toggle()
                                    } label: {
                                        Image(systemName: showPassword ? "eye.slash" : "eye")
                                            .foregroundStyle(Color.black.opacity(0.65))
                                    }
                                    .buttonStyle(.plain)

                                    if showPassword {
                                        TextField("", text: $password)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled()
                                            .multilineTextAlignment(.center)
                                    } else {
                                        SecureField("", text: $password)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled()
                                            .multilineTextAlignment(.center)
                                    }
                                }
                            }

                            if role == .coach {
                                LabeledField(title: "קוד מאמן") {
                                    TextField("", text: $coachCode)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .multilineTextAlignment(.center)
                                }
                            }

                            HStack {
                                Spacer()

                                Toggle(isOn: $rememberMe) {
                                    Text("שמירה לכניסה הבאה")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color.black.opacity(0.75))
                                }
                                .toggleStyle(CheckboxToggleStyle())

                                Spacer()
                            }
                            .padding(.top, 2)

                            Button {
                                onLoginTapped()
                            } label: {
                                Text(auth.isLoading ? "מתחבר..." : "התחבר")
                                    .font(.system(size: 18, weight: .heavy))
                                    .foregroundStyle(Color.black.opacity(0.80))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.white.opacity(0.95))
                                    )
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 2)
                            .disabled(auth.isLoading)

                            Button {
                                resetEmail = UserDefaults.standard.string(forKey: "email") ?? ""
                                resetMessage = nil
                                showForgotPasswordSheet = true
                            } label: {
                                Text("שכחתי סיסמה / שם משתמש")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.black.opacity(0.75))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)

                            Button {
                                onGoToRegister()
                            } label: {
                                Text("משתמש חדש? הרשמה")
                                    .font(.system(size: 16, weight: .heavy))
                                    .foregroundStyle(Color.black.opacity(0.78))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 2)
                        }
                        .padding(.vertical, 18)
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.horizontal, 18)

                Spacer()
            }
            .overlay(alignment: .bottom) {
                FooterText()
                    .padding(.bottom, 14)
            }
        }
        .navigationBarBackButtonHidden()
        .onAppear {
            let defaults = UserDefaults.standard

            role = initialRole
            rememberMe = defaults.object(forKey: rememberMeKey) as? Bool ?? false
            username = defaults.string(forKey: savedUsernameKey) ?? defaults.string(forKey: "username") ?? ""
            password = defaults.string(forKey: savedPasswordKey) ?? defaults.string(forKey: "password") ?? ""
            coachCode = defaults.string(forKey: "coach_code") ?? ""

            didTriggerSuccess = false
        }
        .onChange(of: auth.isSignedIn) { _, isSignedIn in
            guard isSignedIn, !didTriggerSuccess else { return }
            didTriggerSuccess = true
            onLoginSuccess()
        }
        .sheet(isPresented: $showForgotPasswordSheet) {
            ForgotPasswordSheet(
                email: $resetEmail,
                isLoading: auth.isLoading,
                message: resetMessage,
                onSend: {
                    auth.sendPasswordReset(email: resetEmail) { ok, error in
                        if ok {
                            resetMessage = "נשלח מייל לאיפוס סיסמה. בדוק גם ספאם."
                        } else {
                            resetMessage = error ?? "שליחת מייל האיפוס נכשלה"
                        }
                    }
                }
            )
            .presentationDetents([.medium])
        }
    }

    private func onLoginTapped() {
        let defaults = UserDefaults.standard
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = coachCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let roleKey = (role == .coach ? "coach" : "trainee")

        defaults.set(rememberMe, forKey: rememberMeKey)

        if rememberMe {
            defaults.set(u, forKey: savedUsernameKey)
            defaults.set(p, forKey: savedPasswordKey)
        } else {
            defaults.removeObject(forKey: savedUsernameKey)
            defaults.removeObject(forKey: savedPasswordKey)
        }

        didTriggerSuccess = false

        Task { @MainActor in
            let success = await auth.signInWithUsernameOrEmail(
                identifier: u,
                password: p,
                expectedRole: roleKey,
                coachCode: role == .coach ? c : nil
            )

            if success, !didTriggerSuccess {
                didTriggerSuccess = true
                onLoginSuccess()
            }
        }
    }
}

// MARK: - UI building blocks

private struct LoginGradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.44, blue: 0.86),
                Color(red: 0.30, green: 0.18, blue: 0.72)
            ],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
        .ignoresSafeArea()
    }
}

// ✅ Auth-only bar: חזרה + כותרת (בלי המבורגר)
private struct AuthTopBar: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Color.white.opacity(0.92)

            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(Color.black.opacity(0.75))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(title)
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(Color.black.opacity(0.85))

                Spacer()

                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(height: 60)
    }
}

private struct RoleTabs: View {
    enum Selection { case left, right }

    let leftTitle: String
    let rightTitle: String
    let selected: Selection
    let onSelect: (Selection) -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.20))

            HStack(spacing: 0) {
                tabButton(title: leftTitle, isSelected: selected == .left) { onSelect(.left) }

                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 1)

                tabButton(title: rightTitle, isSelected: selected == .right) { onSelect(.right) }
            }
        }
        .frame(height: 48)
    }

    private func tabButton(title: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(red: 0.36, green: 0.20, blue: 0.78).opacity(0.95))
                                .padding(3)
                        } else {
                            Color.clear
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}

private struct FormCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

private struct LabeledField<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(title)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Color.black.opacity(0.80))
                .frame(maxWidth: .infinity, alignment: .trailing)

            content
                .font(.system(size: 18, weight: .semibold))
                .padding(.vertical, 14)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
        }
    }
}

private struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(
                        configuration.isOn
                        ? Color.blue.opacity(0.85)
                        : Color.black.opacity(0.35)
                    )
                    .font(.system(size: 20, weight: .bold))

                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}

private struct FooterText: View {
    var body: some View {
        Text("פותחת באהבה ע\"י יובל פולק ❤️")
            .font(.system(size: 16, weight: .heavy))
            .foregroundStyle(Color.white.opacity(0.92))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 10)
    }
}

private struct ForgotPasswordSheet: View {
    @Binding var email: String
    let isLoading: Bool
    let message: String?
    let onSend: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .trailing, spacing: 8) {
                    Text("איפוס סיסמה")
                        .font(.system(size: 22, weight: .heavy))
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Text("הזן את כתובת האימייל שלך ונשלח אליך קישור לאיפוס סיסמה.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                TextField("אימייל", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )

                if let message, !message.isEmpty {
                    Text(message)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(message.contains("נשלח") ? .green : .red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                Button {
                    onSend()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        }

                        Text(isLoading ? "שולח..." : "שלח קישור איפוס")
                            .font(.system(size: 17, weight: .heavy))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.blue.opacity(0.85))
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLoading)

                Spacer()
            }
            .padding(16)
        }
    }
}
