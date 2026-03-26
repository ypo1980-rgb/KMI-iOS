import SwiftUI

struct PhoneAuthGateView<Content: View>: View {
    let allowedPhones: [String]
    let content: () -> Content

    @AppStorage("phone_gate_passed") private var phoneGatePassed: Bool = false
    @AppStorage("phone_gate_phone") private var savedPhone: String = ""

    @State private var phoneInput: String = ""
    @State private var errorText: String = ""

    init(
        allowedPhones: [String],
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.allowedPhones = allowedPhones
        self.content = content
    }

    var body: some View {
        Group {
            if phoneGatePassed {
                content()
            } else {
                gateBody
            }
        }
        .onAppear {
            if !savedPhone.isEmpty {
                phoneInput = savedPhone
            }
        }
    }

    private var gateBody: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0xFF0D47A1),
                    Color(hex: 0xFF1565C0),
                    Color(hex: 0xFF26A69A)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()

                VStack(spacing: 14) {
                    Image(systemName: "phone.badge.checkmark")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)

                    Text("כניסה לפי טלפון מורשה")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(.white)

                    Text("הזן מספר טלפון מורשה כדי להמשיך לאפליקציה")
                        .font(.system(size: 16, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.92))
                }
                .padding(.horizontal, 24)

                VStack(spacing: 14) {
                    TextField("הזן מספר טלפון", text: $phoneInput)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .multilineTextAlignment(.trailing)
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if !errorText.isEmpty {
                        Text(errorText)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(red: 1.0, green: 0.9, blue: 0.9))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    Button {
                        onContinueTap()
                    } label: {
                        Text("המשך")
                            .font(.system(size: 17, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(18)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }

    private func onContinueTap() {
        let normalizedInput = normalizePhone(phoneInput)
        let normalizedAllowed = Set(allowedPhones.map(normalizePhone))

        guard !normalizedInput.isEmpty else {
            errorText = "יש להזין מספר טלפון"
            return
        }

        guard normalizedAllowed.contains(normalizedInput) else {
            errorText = "הטלפון אינו מורשה להיכנס"
            return
        }

        savedPhone = phoneInput.trimmingCharacters(in: .whitespacesAndNewlines)
        phoneGatePassed = true
        errorText = ""
    }

    private func normalizePhone(_ value: String) -> String {
        let digits = value.filter(\.isNumber)

        if digits.hasPrefix("972") {
            let suffix = String(digits.dropFirst(3))
            return suffix.hasPrefix("0") ? suffix : "0" + suffix
        }

        if digits.hasPrefix("00") {
            return String(digits.drop { $0 == "0" })
        }

        return digits
    }
}
