import SwiftUI

struct MembershipCheckoutView: View {
    let isEnglish: Bool
    let formData: MembershipPaymentFormData
    let onBack: () -> Void
    let onPaymentCompleted: () -> Void

    @State private var cardNumber: String = ""
    @State private var expiry: String = ""
    @State private var cvv: String = ""
    @State private var ownerId: String = ""
    @State private var isProcessing: Bool = false

    private var isFormValid: Bool {
        cardNumber.filter(\.isNumber).count >= 12 &&
        !expiry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        cvv.filter(\.isNumber).count >= 3 &&
        !ownerId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
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

            ScrollView {
                VStack(spacing: 16) {
                    headerCard

                    summaryCard

                    cardDetailsCard

                    secureNoteCard

                    Color.clear.frame(height: 110)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomPayBar
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            Button(action: onBack) {
                Image(systemName: isEnglish ? "chevron.left" : "chevron.right")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            VStack(alignment: isEnglish ? .leading : .trailing, spacing: 5) {
                Text(isEnglish ? "Payment Details" : "פרטי תשלום")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text(isEnglish ? "Association membership fee" : "תשלום דמי חבר לעמותה")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.76))
            }

            Spacer()
        }
        .padding(18)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var summaryCard: some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 12) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.purple.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 15))

                Spacer()

                Text("₪\(String(format: "%.2f", formData.amount))")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }

            Divider()
                .background(Color.white.opacity(0.18))

            paymentRow(
                title: isEnglish ? "Trainee" : "חניך",
                value: "\(formData.traineeFirstName) \(formData.traineeLastName)"
            )

            paymentRow(
                title: isEnglish ? "Product" : "מוצר",
                value: isEnglish ? "Membership Fee" : "דמי חבר לעמותה"
            )

            paymentRow(
                title: isEnglish ? "Email" : "דוא״ל",
                value: formData.payerEmail
            )
        }
        .padding(18)
        .background(Color(red: 0.16, green: 0.24, blue: 0.40))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var cardDetailsCard: some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 14) {
            Text(isEnglish ? "Credit Card Details" : "פרטי כרטיס אשראי")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)

            premiumField(
                title: isEnglish ? "Card Number" : "מספר כרטיס",
                text: $cardNumber,
                icon: "creditcard.fill",
                keyboard: .numberPad,
                placeholder: "0000 0000 0000 0000"
            )

            HStack(spacing: 12) {
                premiumField(
                    title: isEnglish ? "Expiry" : "תוקף",
                    text: $expiry,
                    icon: "calendar",
                    keyboard: .numbersAndPunctuation,
                    placeholder: "MM/YY"
                )

                premiumField(
                    title: "CVV",
                    text: $cvv,
                    icon: "lock.fill",
                    keyboard: .numberPad,
                    placeholder: "123"
                )
            }

            premiumField(
                title: isEnglish ? "Cardholder ID" : "תעודת זהות בעל הכרטיס",
                text: $ownerId,
                icon: "person.text.rectangle.fill",
                keyboard: .numberPad,
                placeholder: ""
            )
        }
        .padding(18)
        .background(Color(red: 0.16, green: 0.24, blue: 0.40))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var secureNoteCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.green)

            Text(
                isEnglish
                ? "This screen is prepared for secure payment integration. Real credit card processing should be connected through an approved payment provider."
                : "מסך זה מוכן לחיבור סליקה מאובטחת. עיבוד כרטיס אשראי אמיתי צריך להתבצע דרך ספק סליקה מאושר."
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.80))
            .multilineTextAlignment(isEnglish ? .leading : .trailing)
        }
        .padding(16)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var bottomPayBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            Button {
                isProcessing = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    isProcessing = false
                    onPaymentCompleted()
                }
            } label: {
                HStack(spacing: 8) {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "lock.fill")
                    }

                    Text(
                        isProcessing
                        ? (isEnglish ? "Processing..." : "מבצע תשלום...")
                        : (isEnglish ? "Pay ₪\(String(format: "%.2f", formData.amount))" : "שלם ₪\(String(format: "%.2f", formData.amount))")
                    )
                    .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isFormValid ? Color.purple : Color.white.opacity(0.14))
                )
            }
            .buttonStyle(.plain)
            .disabled(!isFormValid || isProcessing)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .background(
                Color(red: 0.08, green: 0.12, blue: 0.24)
                    .opacity(0.96)
            )
        }
    }

    private func premiumField(
        title: String,
        text: Binding<String>,
        icon: String,
        keyboard: UIKeyboardType,
        placeholder: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.70))
                .frame(width: 20)

            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .foregroundStyle(.white)
                .multilineTextAlignment(isEnglish ? .leading : .trailing)
        }
        .padding()
        .background(Color(red: 0.14, green: 0.21, blue: 0.37))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .topLeading) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(.white.opacity(0.62))
                .padding(.horizontal, 8)
                .background(Color(red: 0.14, green: 0.21, blue: 0.37))
                .offset(x: 14, y: -8)
        }
    }

    private func paymentRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.68))

            Spacer()

            Text(value.isEmpty ? "-" : value)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(isEnglish ? .leading : .trailing)
        }
    }
}

#Preview {
    MembershipCheckoutView(
        isEnglish: false,
        formData: MembershipPaymentFormData(
            traineeFirstName: "יובל",
            traineeLastName: "פולק",
            traineeIdNumber: "123456789",
            traineeBirthDate: "01/01/1980",
            traineeEmail: "ypo1980@gmail.com",
            traineePhone: "0526664660",
            traineeBranch: "רחוב אבא אחימאיר 6, נתניה",
            traineeOtherBranch: "",
            payerSameAsTrainee: true,
            payerFirstName: "יובל",
            payerLastName: "פולק",
            payerEmail: "ypo1980@gmail.com",
            payerPhone: "0526664660",
            policyAccepted: true,
            amount: 150
        ),
        onBack: {},
        onPaymentCompleted: {}
    )
}
