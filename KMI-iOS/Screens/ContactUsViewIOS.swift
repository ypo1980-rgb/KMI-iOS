import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UIKit

struct ContactUsViewIOS: View {
    let isEnglish: Bool
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var fullName: String = ""
    @State private var phone: String = ""
    @State private var email: String = ""
    @State private var subject: String = ""
    @State private var message: String = ""

    @State private var isSubmitting: Bool = false
    @State private var toastText: String? = nil
    @State private var didPrefill: Bool = false

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var primaryTextColor: Color {
        isDarkMode
            ? Color.white.opacity(0.94)
            : Color(hex: 0xFF1E2A3D)
    }

    private var secondaryTextColor: Color {
        isDarkMode
            ? Color.white.opacity(0.68)
            : Color(hex: 0xFF5E6C80)
    }

    private var cardColor: Color {
        isDarkMode
            ? Color(hex: 0xFF111827).opacity(0.96)
            : Color(hex: 0xFFEAF2FF)
    }

    private var fieldColor: Color {
        isDarkMode
            ? Color(hex: 0xFF1E293B).opacity(0.96)
            : Color.white
    }

    private var dividerColor: Color {
        isDarkMode
            ? Color.white.opacity(0.12)
            : Color(hex: 0xFFBFD0E8)
    }
    
    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var stackAlignment: HorizontalAlignment {
        isEnglish ? .leading : .trailing
    }

    private var isFormValid: Bool {
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: isDarkMode
                    ? [
                        Color(hex: 0xFF111827),
                        Color(hex: 0xFF0F172A),
                        Color(hex: 0xFF12395B),
                        Color(hex: 0xFF062B4A)
                    ]
                    : [
                        Color(hex: 0xFFF8FBFF),
                        Color(hex: 0xFFEAF4FF),
                        Color(hex: 0xFFB7DDF7),
                        Color(hex: 0xFF1F78B4),
                        Color(hex: 0xFF062B4A)
                    ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: stackAlignment, spacing: 16) {
                    introCard
                    formCard
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }

            if let toastText {
                Text(toastText)
                    .kmiFont(size: 13.5, weight: .bold)
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(
                                isDarkMode
                                    ? Color.black.opacity(0.90)
                                    : Color.black.opacity(0.76)
                            )
                    )
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
        .onAppear {
            guard !didPrefill else { return }
            didPrefill = true
            prefillUserDetails()
        }
    }

    private var introCard: some View {
        VStack(alignment: stackAlignment, spacing: 10) {
            Text(
                tr(
                    "השאירו פרטים ונציג העמותה יחזור אליכם",
                    "Leave your details and the association will get back to you"
                )
            )
            .kmiFont(size: 16, weight: .black)
            .foregroundStyle(primaryTextColor)
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .multilineTextAlignment(textAlignment)

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            HStack(spacing: 10) {
                if isEnglish {
                    supportIcon
                    supportText
                } else {
                    supportText
                    supportIcon
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(fieldColor)
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    isDarkMode
                        ? Color.white.opacity(0.10)
                        : Color.black.opacity(0.05),
                    lineWidth: 1
                )
        )
        .shadow(
            color: Color.black.opacity(isDarkMode ? 0.26 : 0.12),
            radius: 8,
            x: 0,
            y: 4
        )
    }

    private var supportIcon: some View {
        Image(systemName: "headphones.circle.fill")
            .font(.system(size: 24, weight: .black))
            .foregroundStyle(Color(hex: 0xFF5B35D5))
            .frame(width: 30, height: 30)
    }

    private var supportText: some View {
        Text(
            tr(
                "נציג מטעם ק.מ.י יחזור אליכם בהקדם.",
                "KAMI representative will contact you soon."
            )
        )
        .kmiFont(size: 14, weight: .bold)
        .foregroundStyle(primaryTextColor)
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .multilineTextAlignment(textAlignment)
    }

    private var formCard: some View {
        VStack(spacing: 12) {
            ContactTextFieldIOS(
                title: tr("שם מלא", "Full Name"),
                text: $fullName,
                systemImage: "person.fill",
                keyboardType: .default,
                isEnglish: isEnglish
            )

            ContactTextFieldIOS(
                title: tr("טלפון", "Phone Number"),
                text: $phone,
                systemImage: "phone.fill",
                keyboardType: .phonePad,
                isEnglish: isEnglish
            )

            ContactTextFieldIOS(
                title: tr("אימייל", "Email"),
                text: $email,
                systemImage: "envelope.fill",
                keyboardType: .emailAddress,
                isEnglish: isEnglish
            )

            ContactTextFieldIOS(
                title: tr("נושא הפנייה", "Subject"),
                text: $subject,
                systemImage: "message.fill",
                keyboardType: .default,
                isEnglish: isEnglish
            )

            messageEditor

            Button {
                submitContactRequest()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 15, weight: .black))

                    Text(isSubmitting ? tr("שולח...", "Sending...") : tr("שלח פנייה", "Send Request"))
                        .font(.system(size: 17, weight: .black))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: isFormValid && !isSubmitting
                                ? [
                                    Color(hex: 0xFF7C5CE6),
                                    Color(hex: 0xFF5B35D5)
                                ]
                                : [
                                    Color(hex: 0xFF8FA7D8),
                                    Color(hex: 0xFF6F86BD)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.42), lineWidth: 1)
                )
                .shadow(
                    color: Color.black.opacity(0.16),
                    radius: 9,
                    x: 0,
                    y: 5
                )
                .opacity(isSubmitting ? 0.72 : 1.0)
            }
            .buttonStyle(.plain)
            .allowsHitTesting(!isSubmitting)
            .padding(.top, 6)
            .padding(.bottom, 2)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(hex: 0xFFEAF2FF))
        )
        .shadow(color: Color.black.opacity(0.14), radius: 10, x: 0, y: 5)
    }

    private var messageEditor: some View {
        VStack(alignment: stackAlignment, spacing: 6) {
            Text(tr("הודעה", "Message"))
                .font(.system(size: 11.5, weight: .black))
                .foregroundStyle(Color(hex: 0xFF5E6C80))
                .frame(maxWidth: .infinity, alignment: frameAlignment)

            ZStack(alignment: isEnglish ? .topLeading : .topTrailing) {
                if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(tr("כתוב כאן את תוכן הפנייה", "Write your message here"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xFF6B778B).opacity(0.72))
                        .padding(.horizontal, 15)
                        .padding(.vertical, 16)
                        .multilineTextAlignment(textAlignment)
                }

                TextEditor(text: $message)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xFF1E2A3D))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .frame(minHeight: 118)
                    .multilineTextAlignment(textAlignment)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(hex: 0xFFD8E3F5), lineWidth: 1)
            )
        }
    }

    private func prefillUserDetails() {
        let defaults = UserDefaults.standard
        let user = Auth.auth().currentUser

        if fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fullName =
                defaults.string(forKey: "fullName") ??
                defaults.string(forKey: "full_name") ??
                defaults.string(forKey: "name") ??
                defaults.string(forKey: "displayName") ??
                user?.displayName ??
                ""
        }

        if phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            phone =
                defaults.string(forKey: "phone") ??
                defaults.string(forKey: "phoneNumber") ??
                defaults.string(forKey: "phone_number") ??
                defaults.string(forKey: "mobile") ??
                defaults.string(forKey: "mobilePhone") ??
                ""
        }

        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            email =
                defaults.string(forKey: "email") ??
                user?.email ??
                ""
        }

        guard let uid = user?.uid, !uid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        Firestore.firestore()
            .collection("users")
            .document(uid)
            .getDocument { document, _ in
                guard let data = document?.data() else {
                    return
                }

                if fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    fullName =
                        data["fullName"] as? String ??
                        data["full_name"] as? String ??
                        data["name"] as? String ??
                        data["displayName"] as? String ??
                        fullName
                }

                if phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    phone =
                        data["phone"] as? String ??
                        data["phoneNumber"] as? String ??
                        data["phone_number"] as? String ??
                        data["mobile"] as? String ??
                        data["mobilePhone"] as? String ??
                        phone
                }

                if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    email =
                        data["email"] as? String ??
                        user?.email ??
                        email
                }
            }
    }

    private func submitContactRequest() {
        guard !isSubmitting else {
            return
        }

        let cleanFullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanFullName.isEmpty,
              !cleanPhone.isEmpty,
              !cleanSubject.isEmpty,
              !cleanMessage.isEmpty else {
            showToast(tr("יש למלא שם, טלפון, נושא והודעה", "Please fill name, phone, subject and message"))
            return
        }

        isSubmitting = true

        let authUser = Auth.auth().currentUser
        let db = Firestore.firestore()
        let contactRef = db.collection("contactRequests").document()
        let notificationRef = db.collection("appNotificationQueue").document()
        let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)

        let contactData: [String: Any] = [
            "requestId": contactRef.documentID,
            "fullName": cleanFullName,
            "phone": cleanPhone,
            "email": cleanEmail,
            "subject": cleanSubject,
            "message": cleanMessage,
            "userUid": authUser?.uid ?? "",
            "userEmail": authUser?.email ?? "",
            "status": "open",
            "source": "ios_contact_us",
            "notifyEnabled": true,
            "notifyStatus": "pending",
            "notifyTargetType": "association_contact_manager",
            "notifyTargetUid": "",
            "notifyTargetEmail": "",
            "notifyTargetPhone": "",
            "notifyCreatedAtMillis": nowMillis,
            "createdAt": FieldValue.serverTimestamp(),
            "createdAtMillis": nowMillis
        ]

        let notificationData: [String: Any] = [
            "notificationId": notificationRef.documentID,
            "type": "contact_request",
            "status": "pending",
            "source": "ios_contact_us",
            "targetType": "association_contact_manager",
            "targetUid": "",
            "targetEmail": "",
            "targetPhone": "",
            "contactRequestId": contactRef.documentID,
            "relatedCollection": "contactRequests",
            "relatedDocumentId": contactRef.documentID,
            "titleHe": "פנייה חדשה מהאפליקציה",
            "titleEn": "New contact request from the app",
            "bodyHe": "התקבלה פנייה חדשה מאת \(cleanFullName) בנושא: \(cleanSubject)",
            "bodyEn": "A new contact request was received from \(cleanFullName) regarding: \(cleanSubject)",
            "fullName": cleanFullName,
            "phone": cleanPhone,
            "email": cleanEmail,
            "subject": cleanSubject,
            "messagePreview": String(cleanMessage.prefix(180)),
            "userUid": authUser?.uid ?? "",
            "userEmail": authUser?.email ?? "",
            "createdAt": FieldValue.serverTimestamp(),
            "createdAtMillis": nowMillis
        ]

        let batch = db.batch()
        batch.setData(contactData, forDocument: contactRef)
        batch.setData(notificationData, forDocument: notificationRef)

        batch.commit { error in
            isSubmitting = false

            if error != nil {
                showToast(tr("שליחת הפנייה נכשלה. נסה שוב.", "Sending failed. Please try again."))
                return
            }

            fullName = ""
            phone = ""
            email = ""
            subject = ""
            message = ""

            showToast(tr("הפנייה נשלחה בהצלחה", "Your request was sent successfully"))
        }
    }

    private func showToast(_ text: String) {
        withAnimation(.easeOut(duration: 0.18)) {
            toastText = text
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeOut(duration: 0.18)) {
                toastText = nil
            }
        }
    }
}

private struct ContactTextFieldIOS: View {
    let title: String
    @Binding var text: String
    let systemImage: String
    let keyboardType: UIKeyboardType
    let isEnglish: Bool

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    var body: some View {
        HStack(spacing: 9) {
            if isEnglish {
                icon
            }

            TextField(title, text: $text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
                .autocorrectionDisabled(true)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: 0xFF1E2A3D))
                .multilineTextAlignment(textAlignment)

            if !isEnglish {
                icon
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: 0xFFD8E3F5), lineWidth: 1)
        )
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
    }

    private var icon: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Color(hex: 0xFF6B778B))
            .frame(width: 20)
    }
}
