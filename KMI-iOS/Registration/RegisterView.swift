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

                        #if DEBUG
                        print("🟡 RegisterView: submit tapped email=\(form.emailTrimmed)")
                        #endif

                        await auth.registerAndSaveProfile(form: form)

                        isSubmitting = false

                        #if DEBUG
                        print("🟡 RegisterView: register finished error=\(auth.errorText ?? "nil") isSignedIn=\(auth.isSignedIn)")
                        #endif

                        if auth.errorText == nil {
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
        .navigationDestination(isPresented: $goToTerms) {
            LegalView()
        }
        .alert(
            coachDialogTitle,
            isPresented: $showCoachCodeDialog,
            actions: {
                Button("העתקה") {
                    if let code = auth.issuedCoachCode {
                        UIPasteboard.general.string = code
                    }
                }

                Button("אישור") {
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
        let normalizedPhone = prefillPhone.filter { $0.isNumber }
        let normalizedEmail = prefillEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let nameFromPhone = CoachWhitelist.allowedPhones[normalizedPhone]
        let nameFromEmail = CoachWhitelist.allowedEmails[normalizedEmail]

        return "שלום, \(nameFromPhone ?? nameFromEmail ?? "מאמן")"
    }

    private var coachDialogMessage: String {
        let code = auth.issuedCoachCode ?? ""
        return "קוד המאמן שלך:\n\n\(code)\n\nעליך לשמור את קוד המאמן שהתקבל לכניסה למערכת ולפעולות מתקדמות."
    }
}

private struct LegalTermsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("תנאי שימוש")
                .font(.title2).bold()

            Text("כאן תציג את מסך התנאים המשפטיים שבנית.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(16)
        .navigationTitle("תנאים משפטיים")
        .navigationBarTitleDisplayMode(.inline)
    }
}
