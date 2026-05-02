import SwiftUI

struct MembershipPaymentPrefill {
    var traineeFirstName: String = ""
    var traineeLastName: String = ""
    var traineeIdNumber: String = ""
    var traineeBirthDate: String = ""
    var traineeEmail: String = ""
    var traineePhone: String = ""
    var traineeBranch: String = ""
    var traineeOtherBranch: String = ""
    var payerFirstName: String = ""
    var payerLastName: String = ""
    var payerEmail: String = ""
    var payerPhone: String = ""
}

struct MembershipPaymentFormData: Hashable {
    let traineeFirstName: String
    let traineeLastName: String
    let traineeIdNumber: String
    let traineeBirthDate: String
    let traineeEmail: String
    let traineePhone: String
    let traineeBranch: String
    let traineeOtherBranch: String
    let payerSameAsTrainee: Bool
    let payerFirstName: String
    let payerLastName: String
    let payerEmail: String
    let payerPhone: String
    let policyAccepted: Bool
    let amount: Double
}

struct MembershipPaymentView: View {
    let isEnglish: Bool
    let prefill: MembershipPaymentPrefill
    let onClose: () -> Void
    let onReadFullPolicy: () -> Void
    let onContinueToPayment: (MembershipPaymentFormData) -> Void

    @State private var traineeFirstName: String
    @State private var traineeLastName: String
    @State private var traineeIdNumber: String
    @State private var traineeBirthDate: String
    @State private var traineeEmail: String
    @State private var traineePhone: String
    @State private var traineeBranch: String
    @State private var traineeOtherBranch: String

    @State private var payerSameAsTrainee: Bool = true
    @State private var payerFirstName: String
    @State private var payerLastName: String
    @State private var payerEmail: String
    @State private var payerPhone: String
    @State private var policyAccepted: Bool = false

    private let amount: Double = 150.0

    private var missingBranchText: String {
        isEnglish ? "My branch is not listed" : "הסניף שלי לא מופיע"
    }

    private var branchOptions: [String] {
        [
            isEnglish ? "Ofek Community Center, Netanya" : "מרכז קהילתי אופק נתניה",
            isEnglish ? "Sokolov Community Center, Netanya" : "מרכז קהילתי סוקולוב נתניה",
            missingBranchText
        ]
    }

    private var shouldShowOtherBranch: Bool {
        traineeBranch == missingBranchText
    }

    private var isFormValid: Bool {
        !traineeFirstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !traineeLastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !traineeIdNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !traineeBirthDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !traineeEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !traineePhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !traineeBranch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (!shouldShowOtherBranch || !traineeOtherBranch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) &&
        !payerFirstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !payerLastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !payerEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !payerPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        policyAccepted
    }

    init(
        isEnglish: Bool = false,
        prefill: MembershipPaymentPrefill = MembershipPaymentPrefill(),
        onClose: @escaping () -> Void = {},
        onReadFullPolicy: @escaping () -> Void = {},
        onContinueToPayment: @escaping (MembershipPaymentFormData) -> Void = { _ in }
    ) {
        self.isEnglish = isEnglish
        self.prefill = prefill
        self.onClose = onClose
        self.onReadFullPolicy = onReadFullPolicy
        self.onContinueToPayment = onContinueToPayment

        _traineeFirstName = State(initialValue: prefill.traineeFirstName)
        _traineeLastName = State(initialValue: prefill.traineeLastName)
        _traineeIdNumber = State(initialValue: prefill.traineeIdNumber)
        _traineeBirthDate = State(initialValue: prefill.traineeBirthDate)
        _traineeEmail = State(initialValue: prefill.traineeEmail)
        _traineePhone = State(initialValue: prefill.traineePhone)

        let initialBranch = prefill.traineeBranch.isEmpty
            ? (isEnglish ? "Ofek Community Center, Netanya" : "מרכז קהילתי אופק נתניה")
            : prefill.traineeBranch

        _traineeBranch = State(initialValue: initialBranch)
        _traineeOtherBranch = State(initialValue: prefill.traineeOtherBranch)

        _payerFirstName = State(initialValue: prefill.payerFirstName.isEmpty ? prefill.traineeFirstName : prefill.payerFirstName)
        _payerLastName = State(initialValue: prefill.payerLastName.isEmpty ? prefill.traineeLastName : prefill.payerLastName)
        _payerEmail = State(initialValue: prefill.payerEmail.isEmpty ? prefill.traineeEmail : prefill.payerEmail)
        _payerPhone = State(initialValue: prefill.payerPhone.isEmpty ? prefill.traineePhone : prefill.payerPhone)
    }

    var body: some View {
        ZStack {
            paymentBackground

            ScrollView {
                VStack(spacing: 16) {
                    paymentHeader

                    productHeroCard

                    sectionCard(
                        title: isEnglish ? "Trainee Details" : "פרטי חניך",
                        systemImage: "person.crop.circle.fill"
                    ) {
                        premiumTextField(isEnglish ? "First Name" : "שם פרטי", text: $traineeFirstName, icon: "person.fill")
                        premiumTextField(isEnglish ? "Last Name" : "שם משפחה", text: $traineeLastName, icon: "person.fill")
                        premiumTextField(isEnglish ? "ID Number" : "מספר ת.ז.", text: $traineeIdNumber, icon: "person.text.rectangle.fill", keyboard: .numberPad)
                        premiumTextField(isEnglish ? "Birth Date" : "תאריך לידה", text: $traineeBirthDate, icon: "calendar", placeholder: "DD/MM/YYYY")
                        premiumTextField(isEnglish ? "Email" : "כתובת דוא״ל", text: $traineeEmail, icon: "envelope.fill", keyboard: .emailAddress)
                        premiumTextField(isEnglish ? "Mobile Phone" : "מספר טלפון נייד", text: $traineePhone, icon: "phone.fill", keyboard: .phonePad)

                        branchPicker

                        if shouldShowOtherBranch {
                            premiumTextField(
                                isEnglish ? "Other Branch Name" : "שם סניף נוסף אם חסר ברשימה",
                                text: $traineeOtherBranch,
                                icon: "building.2.fill"
                            )
                        }
                    }

                    sectionCard(
                        title: isEnglish ? "Payer Details for Invoice" : "פרטי המשלם לשליחת חשבונית",
                        systemImage: "receipt.fill"
                    ) {
                        Toggle(isOn: $payerSameAsTrainee) {
                            Label(
                                isEnglish ? "Payer is the same as trainee" : "המשלם זהה לפרטי החניך",
                                systemImage: "shield.fill"
                            )
                            .foregroundStyle(.white)
                        }
                        .tint(.purple)
                        .onChange(of: payerSameAsTrainee) { _, newValue in
                            if newValue {
                                syncPayerFromTrainee()
                            }
                        }
                        .onChange(of: traineeFirstName) { _, _ in if payerSameAsTrainee { syncPayerFromTrainee() } }
                        .onChange(of: traineeLastName) { _, _ in if payerSameAsTrainee { syncPayerFromTrainee() } }
                        .onChange(of: traineeEmail) { _, _ in if payerSameAsTrainee { syncPayerFromTrainee() } }
                        .onChange(of: traineePhone) { _, _ in if payerSameAsTrainee { syncPayerFromTrainee() } }

                        premiumTextField(isEnglish ? "First Name" : "שם פרטי", text: $payerFirstName, icon: "person.fill", disabled: payerSameAsTrainee)
                        premiumTextField(isEnglish ? "Last Name" : "שם משפחה", text: $payerLastName, icon: "person.fill", disabled: payerSameAsTrainee)
                        premiumTextField(isEnglish ? "Email Address" : "כתובת דוא״ל", text: $payerEmail, icon: "envelope.fill", keyboard: .emailAddress, disabled: payerSameAsTrainee)
                        premiumTextField(isEnglish ? "Phone Number" : "מספר טלפון", text: $payerPhone, icon: "phone.fill", keyboard: .phonePad, disabled: payerSameAsTrainee)
                    }

                    sectionCard(
                        title: isEnglish ? "Payment Summary" : "סיכום תשלום",
                        systemImage: "wallet.pass.fill"
                    ) {
                        priceRow(label: isEnglish ? "Product" : "מוצר", value: isEnglish ? "Association Membership Fee" : "דמי חבר לעמותה")
                        priceRow(label: isEnglish ? "Price" : "מחיר", value: isEnglish ? "₪150.00" : "150.00 ₪", emphasize: true)
                    }

                    sectionCard(
                        title: isEnglish ? "Cancellation & Refund Policy" : "מדיניות ביטולים והחזרים",
                        systemImage: "doc.text.fill"
                    ) {
                        Text(isEnglish
                             ? "Payment of membership fees is final after approval, except in cases such as duplicate payment or another good-faith mistake, subject to review by the association."
                             : "תשלום דמי חבר הוא סופי לאחר אישור הפעולה, למעט מקרים של תשלום כפול בטעות או טעות אחרת בתום לב, בכפוף לבדיקת העמותה.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
                            .background(Color.white.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        Button(action: onReadFullPolicy) {
                            Label(isEnglish ? "Read Full Policy" : "קרא מדיניות מלאה", systemImage: "doc.text")
                                .font(.subheadline.weight(.semibold))
                        }

                        Toggle(isOn: $policyAccepted) {
                            Text(isEnglish
                                 ? "I have read and agree to the cancellation and refund policy."
                                 : "קראתי ואני מאשר/ת את מדיניות הביטולים וההחזרים.")
                                .foregroundStyle(.white.opacity(0.92))
                                .font(.subheadline)
                        }
                        .tint(.purple)
                    }

                    Color.clear
                        .frame(height: 12)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomPaymentBar
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
    }

    private var paymentBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.09, blue: 0.19),
                Color(red: 0.12, green: 0.16, blue: 0.32),
                Color(red: 0.15, green: 0.46, blue: 0.74)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var paymentHeader: some View {
        HStack(spacing: 14) {
            VStack(alignment: isEnglish ? .leading : .trailing, spacing: 6) {
                Text(isEnglish ? "Membership Payment" : "תשלום דמי חבר")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text(isEnglish ? "Association membership fee • ₪150" : "דמי חבר לעמותה • 150 ₪")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .shadow(color: .black.opacity(0.22), radius: 10, y: 6)
    }

    private var productHeroCard: some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 12) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundStyle(Color(red: 0.74, green: 0.65, blue: 1.0))
                    .frame(width: 46, height: 46)
                    .background(Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                Spacer()

                Text(isEnglish ? "₪150" : "150 ₪")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }

            Text(isEnglish ? "Association Membership" : "חברות בעמותה")
                .font(.title3.bold())
                .foregroundStyle(.white)

            Text(isEnglish ? "Secure payment registration before continuing" : "רישום מאובטח לתשלום לפני מעבר לסליקה")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))
        }
        .padding(16)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.22), radius: 10, y: 6)
    }

    private var bottomPaymentBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            VStack(spacing: 10) {
                Button(action: continuePayment) {
                    Label(
                        isEnglish ? "Continue to Payment" : "המשך לתשלום",
                        systemImage: "creditcard.fill"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isFormValid ? Color.purple : Color.white.opacity(0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            isFormValid ? Color.purple.opacity(0.25) : Color.white.opacity(0.10),
                            lineWidth: 1
                        )
                )
                .opacity(isFormValid ? 1.0 : 0.92)
                .disabled(!isFormValid)

                if !isFormValid {
                    Text(
                        isEnglish
                        ? "Complete all required fields and approve the policy to continue."
                        : "יש למלא את כל השדות הנדרשים ולאשר את המדיניות כדי להמשיך."
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
                    .multilineTextAlignment(isEnglish ? .leading : .trailing)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .background(
                Color(red: 0.08, green: 0.12, blue: 0.24)
                    .opacity(0.96)
            )
        }
    }
    
    private var branchPicker: some View {
        Menu {
            ForEach(branchOptions, id: \.self) { option in
                Button(option) {
                    traineeBranch = option
                    if option != missingBranchText {
                        traineeOtherBranch = ""
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundStyle(.white.opacity(0.72))

                Text(traineeBranch)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.down")
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding()
            .background(Color(red: 0.14, green: 0.21, blue: 0.37))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func sectionCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(.purple)
                    .frame(width: 44, height: 44)
                    .background(Color.purple.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Spacer()
            }

            Divider()
                .background(Color.white.opacity(0.18))

            content()
        }
        .padding(18)
        .background(Color(red: 0.16, green: 0.24, blue: 0.40))
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 5)
    }

    private func premiumTextField(
        _ title: String,
        text: Binding<String>,
        icon: String,
        keyboard: UIKeyboardType = .default,
        placeholder: String = "",
        disabled: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 22)

            TextField(placeholder.isEmpty ? title : placeholder, text: text)
                .keyboardType(keyboard)
                .disabled(disabled)
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
        }
        .padding()
        .background(Color(red: 0.14, green: 0.21, blue: 0.37).opacity(disabled ? 0.55 : 1.0))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .topLeading) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 8)
                .background(Color(red: 0.14, green: 0.21, blue: 0.37))
                .offset(x: 14, y: -8)
        }
    }

    private func priceRow(label: String, value: String, emphasize: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundStyle(.white.opacity(0.76))

            Spacer()

            Text(value)
                .font(emphasize ? .headline : .body)
                .foregroundStyle(.white)
                .fontWeight(emphasize ? .bold : .regular)
        }
    }

    private func syncPayerFromTrainee() {
        payerFirstName = traineeFirstName
        payerLastName = traineeLastName
        payerEmail = traineeEmail
        payerPhone = traineePhone
    }

    private func continuePayment() {
        let data = MembershipPaymentFormData(
            traineeFirstName: traineeFirstName.trimmingCharacters(in: .whitespacesAndNewlines),
            traineeLastName: traineeLastName.trimmingCharacters(in: .whitespacesAndNewlines),
            traineeIdNumber: traineeIdNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            traineeBirthDate: traineeBirthDate.trimmingCharacters(in: .whitespacesAndNewlines),
            traineeEmail: traineeEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            traineePhone: traineePhone.trimmingCharacters(in: .whitespacesAndNewlines),
            traineeBranch: traineeBranch.trimmingCharacters(in: .whitespacesAndNewlines),
            traineeOtherBranch: traineeOtherBranch.trimmingCharacters(in: .whitespacesAndNewlines),
            payerSameAsTrainee: payerSameAsTrainee,
            payerFirstName: payerFirstName.trimmingCharacters(in: .whitespacesAndNewlines),
            payerLastName: payerLastName.trimmingCharacters(in: .whitespacesAndNewlines),
            payerEmail: payerEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            payerPhone: payerPhone.trimmingCharacters(in: .whitespacesAndNewlines),
            policyAccepted: policyAccepted,
            amount: amount
        )

        onContinueToPayment(data)
    }
}

#Preview {
    MembershipPaymentView(isEnglish: false)
}
