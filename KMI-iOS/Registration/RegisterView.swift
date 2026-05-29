import SwiftUI

struct RegisterView: View {

    let prefillPhone: String
    let prefillEmail: String
    let initialRole: UserRole
    let onBack: () -> Void
    let onSubmit: (RegistrationFormState) -> Void
    let onReadMoreTerms: () -> Void

    @EnvironmentObject private var auth: AuthViewModel

    @State private var isSubmitting: Bool = false
    @State private var goToTerms: Bool = false
    @State private var submittedForm: RegistrationFormState? = nil
    @State private var showCoachCodeDialog: Bool = false

    private var isEnglish: Bool {
        KmiStartupLanguage.currentFromDefaults().isEnglish
    }

    private var screenLayoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
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
    }
    
    var body: some View {
        VStack(spacing: 10) {
            RegisterFormView(
                prefillPhone: prefillPhone,
                prefillEmail: prefillEmail,
                initialRole: initialRole,
                onBack: {
                    onBack()
                },
                onSubmit: { form in
                    guard !isSubmitting else { return }

                    Task { @MainActor in
                        isSubmitting = true
                        auth.errorText = nil

                        await auth.registerAndSaveProfile(form: form)

                        isSubmitting = false

                        if auth.errorText == nil {
                            form.persistToUserDefaults()
                            submittedForm = form

                            if form.role == .coach, auth.issuedCoachCode != nil {
                                showCoachCodeDialog = true
                            } else {
                                onSubmit(form)
                            }
                        }
                    }
                },
                onReadMoreTerms: {
                    goToTerms = true
                    onReadMoreTerms()
                }
            )

            if let err = auth.errorText, !err.isEmpty {
                Text(err)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .environment(\.layoutDirection, screenLayoutDirection)
        .navigationDestination(isPresented: $goToTerms) {
            LegalView()
        }
        .alert(
            coachDialogTitle,
            isPresented: $showCoachCodeDialog,
            actions: {
                Button(tr("העתקה", "Copy")) {
                    if let code = auth.issuedCoachCode {
                        UIPasteboard.general.string = code
                    }
                }

                Button(tr("אישור", "OK")) {
                    if let form = submittedForm {
                        onSubmit(form)
                    }
                    auth.issuedCoachCode = nil
                    submittedForm = nil
                }
            },
            message: {
                Text(coachDialogMessage)
            }
        )
    }

    private var coachDialogTitle: String {
        let normalizedPhone =
            submittedForm?.phone.filter { $0.isNumber } ??
            prefillPhone.filter { $0.isNumber }

        let normalizedEmail =
            submittedForm?.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ??
            prefillEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let nameFromPhone = CoachWhitelist.allowedPhones[normalizedPhone]
        let nameFromEmail = CoachWhitelist.allowedEmails[normalizedEmail]
        let fallback = tr("מאמן", "Coach")
        let displayName = nameFromPhone ?? nameFromEmail ?? fallback

        return tr("שלום, \(displayName)", "Hello, \(displayName)")
    }

    private var coachDialogMessage: String {
        let code = auth.issuedCoachCode ?? ""

        return tr(
            "קוד המאמן שלך:\n\n\(code)\n\nעליך לשמור את קוד המאמן שהתקבל לכניסה למערכת ולפעולות מתקדמות.",
            "Your coach code is:\n\n\(code)\n\nPlease save this coach code for login and advanced actions."
        )
    }
}

