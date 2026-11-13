import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import UIKit
import CoreText

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
    @State private var contactPdfShareItem: ContactPdfShareItem?

    private struct ContactPdfShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var primaryTextColor: Color {
        KmiAppTheme.onSurface(for: colorScheme)
    }

    private var secondaryTextColor: Color {
        KmiAppTheme.onSurfaceVariant(for: colorScheme)
    }

    private var cardColor: Color {
        KmiAppTheme.surfaceVariant(for: colorScheme)
    }

    private var fieldColor: Color {
        KmiAppTheme.surface(for: colorScheme)
    }

    private var dividerColor: Color {
        KmiAppTheme.outlineVariant(for: colorScheme)
    }
    
    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private var textAlignment: TextAlignment { .leading }
    private var frameAlignment: Alignment { .leading }
    private var stackAlignment: HorizontalAlignment { .leading }

    private var isFormValid: Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailPattern = #"\A[a-zA-Z0-9+._%\-]{1,256}@[a-zA-Z0-9][a-zA-Z0-9\-]{0,64}(?:\.[a-zA-Z0-9][a-zA-Z0-9\-]{0,25})+\z"#

        return !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            cleanEmail.range(of: emailPattern, options: .regularExpression) != nil &&
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

            VStack(spacing: 0) {
                Text(
                    tr(
                        "השאירו פרטים ונציג העמותה\nיחזור אליכם",
                        "Leave your details and an association representative\nwill contact you"
                    )
                )
                .kmiFont(size: 14, weight: .black)
                .foregroundStyle(KmiAppTheme.sectionHeaderContentColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(KmiAppTheme.sectionHeaderBrush)

                ScrollView(showsIndicators: false) {
                    formCard
                        .disabled(isSubmitting)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }
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
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("KMI_CONTACT_US_SHARE_PDF")
            )
        ) { _ in
            guard contactPdfShareItem == nil else { return }
            shareContactPDF()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("KMI_CONTACT_US_SHARE_PDF")
            )
        ) { _ in
            guard contactPdfShareItem == nil else { return }
            shareContactPDF()
        }
        .sheet(item: $contactPdfShareItem) { item in
            KmiShareSheet(items: [item.url])
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
                keyboardType: .default
            )

            ContactTextFieldIOS(
                title: tr("טלפון", "Phone Number"),
                text: $phone,
                systemImage: "phone.fill",
                keyboardType: .phonePad
            )

            ContactTextFieldIOS(
                title: tr("אימייל", "Email"),
                text: $email,
                systemImage: "envelope.fill",
                keyboardType: .emailAddress
            )

            ContactTextFieldIOS(
                title: tr("נושא הפנייה", "Subject"),
                text: $subject,
                systemImage: "message.fill",
                keyboardType: .default
            )

            messageEditor

            Button {
                submitContactRequest()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                        .kmiIconSize(15)
                        .accessibilityHidden(true)

                    Text(
                        isSubmitting
                            ? tr("שולח...", "Sending...")
                            : tr("שלח פנייה", "Send Request")
                    )
                    .kmiFont(size: 17, weight: .black)
                }
                .foregroundStyle(
                    isFormValid && !isSubmitting
                        ? KmiAppTheme.onPrimary(for: colorScheme)
                        : secondaryTextColor.opacity(0.62)
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            isFormValid && !isSubmitting
                                ? KmiAppTheme.primary(for: colorScheme)
                                : fieldColor
                        )
                }
            }
            .buttonStyle(.plain)
            .disabled(!isFormValid || isSubmitting)
            .padding(.top, 6)
            .padding(.bottom, 2)

            if let managementEmailURL = URL(string: "mailto:management@kami.org.il") {
                Link(destination: managementEmailURL) {
                    Text(
                        tr(
                            "מייל ליצירת קשר: management@kami.org.il",
                            "Contact email: management@kami.org.il"
                        )
                    )
                    .kmiFont(size: 14, weight: .semibold)
                    .foregroundStyle(KmiAppTheme.primary(for: colorScheme))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(dividerColor.opacity(0.5), lineWidth: 1)
        )
    }

    private var messageEditor: some View {
        VStack(alignment: stackAlignment, spacing: 6) {
            Text(tr("הודעה", "Message"))
                .kmiFont(size: 11.5, weight: .black)
                .foregroundStyle(secondaryTextColor)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .accessibilityHidden(true)

            ZStack(alignment: .topLeading) {
                if message.isEmpty {
                    Text(tr("כתוב כאן את תוכן הפנייה", "Write your message here"))
                        .kmiFont(size: 15, weight: .semibold)
                        .foregroundStyle(secondaryTextColor.opacity(0.72))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 16)
                        .multilineTextAlignment(textAlignment)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $message)
                    .kmiFont(size: 15, weight: .semibold)
                    .foregroundStyle(primaryTextColor)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 118)
                    .multilineTextAlignment(textAlignment)
                    .accessibilityLabel(tr("הודעה", "Message"))
            }
            .background(fieldColor)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(dividerColor, lineWidth: 1)
                    .allowsHitTesting(false)
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
        guard !isSubmitting, isFormValid else { return }

        let payload = [
            "fullName": fullName.trimmingCharacters(in: .whitespacesAndNewlines),
            "phone": phone.trimmingCharacters(in: .whitespacesAndNewlines),
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            "subject": subject.trimmingCharacters(in: .whitespacesAndNewlines),
            "message": message.trimmingCharacters(in: .whitespacesAndNewlines),
            "appLanguage": isEnglish ? "en" : "he"
        ]

        isSubmitting = true

        Task { @MainActor in
            defer { isSubmitting = false }

            let unconfirmedMessage = tr(
                "לא ניתן לאשר את קליטת הפנייה. יש לבדוק את מצבה לפני שליחה חוזרת.",
                "Could not confirm your request. Please check its status before sending again."
            )

            do {
                let result = try await Functions.functions(region: "europe-west1")
                    .httpsCallable("submitKamiContactRequest")
                    .call(payload)

                guard let response = result.data as? [String: Any],
                      response["accepted"] as? Bool == true,
                      let requestId = response["requestId"] as? String,
                      !requestId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    showToast(unconfirmedMessage)
                    return
                }

                fullName = ""
                phone = ""
                email = ""
                subject = ""
                message = ""

                showToast(
                    tr(
                        "הפנייה התקבלה והועברה להמשך טיפול.",
                        "Your request has been received and forwarded for further handling."
                    )
                )
            } catch {
                showToast(unconfirmedMessage)
            }
        }
    }

    @MainActor
    private func shareContactPDF() {
        do {
            let url = try makeContactPDF(
                privacyEnabled: DemoPrivacy.shared.isEnabled
            )
            contactPdfShareItem = ContactPdfShareItem(url: url)
        } catch {
            showToast(
                tr(
                    "לא ניתן היה להכין את קובץ ה־PDF.",
                    "Could not create the PDF."
                )
            )
        }
    }

    private enum ContactPdfError: Error {
        case contentDoesNotFit
    }

    @MainActor
    private func makeContactPDF(privacyEnabled: Bool) throws -> URL {
        let hidden = tr("מוסתר במצב הדגמה", "Hidden in demo mode")

        func displayValue(_ value: String) -> String {
            if privacyEnabled { return hidden }

            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return clean.isEmpty ? "—" : clean
        }

        let fields = [
            (tr("שם מלא", "Full Name"), fullName),
            (tr("טלפון", "Phone"), phone),
            (tr("אימייל", "Email"), email),
            (tr("נושא הפנייה", "Subject"), subject),
            (tr("הודעה", "Message"), message)
        ]

        let paragraph = NSMutableParagraphStyle()
        paragraph.baseWritingDirection = isEnglish ? .leftToRight : .rightToLeft
        paragraph.alignment = isEnglish ? .left : .right
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 4
        paragraph.firstLineHeadIndent = 12
        paragraph.headIndent = 12
        paragraph.tailIndent = -12

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor(KmiAppTheme.onSurface(for: .light)),
            .paragraphStyle: paragraph
        ]

        var labelAttributes = attributes
        labelAttributes[.font] = UIFont.boldSystemFont(ofSize: 13)

        var headingAttributes = attributes
        headingAttributes[.font] = UIFont.boldSystemFont(ofSize: 16)
        headingAttributes[.foregroundColor] = UIColor(
            KmiAppTheme.primary(for: .light)
        )

        let headingParagraph = NSMutableParagraphStyle()
        headingParagraph.baseWritingDirection = paragraph.baseWritingDirection
        headingParagraph.alignment = paragraph.alignment
        headingAttributes[.paragraphStyle] = headingParagraph

        let text = NSMutableAttributedString(
            string: tr("פרטי הפנייה", "Request details"),
            attributes: headingAttributes
        )
        var fieldRanges: [NSRange] = []

        for (label, value) in fields {
            if text.length > 0 {
                text.append(NSAttributedString(
                    string: "\n\n",
                    attributes: attributes
                ))
            }

            let start = text.length

            text.append(NSAttributedString(
                string: "\(label)\n",
                attributes: labelAttributes
            ))
            text.append(NSAttributedString(
                string: "\(displayValue(value))",
                attributes: attributes
            ))

            fieldRanges.append(NSRange(
                location: start,
                length: text.length - start
            ))
        }

        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let contentTop = KmiPdfHeader.CONTENT_TOP
        let content = CGRect(
            x: 34,
            y: contentTop,
            width: page.width - 68,
            height: page.height - contentTop - KmiPdfFooter.CONTENT_BOTTOM_PADDING
        )

        let path = CGPath(
            rect: CGRect(origin: .zero, size: content.size),
            transform: nil
        )
        let framesetter = CTFramesetterCreateWithAttributedString(
            text as CFAttributedString
        )

        var frames: [CTFrame] = []
        var offset = 0

        while offset < text.length {
            let frame = CTFramesetterCreateFrame(
                framesetter,
                CFRange(location: offset, length: 0),
                path,
                nil
            )
            let visible = CTFrameGetVisibleStringRange(frame)
            guard visible.location == offset,
                  visible.length > 0,
                  visible.length <= text.length - offset else {
                throw ContactPdfError.contentDoesNotFit
            }

            frames.append(frame)
            offset += visible.length
        }

        let data = UIGraphicsPDFRenderer(bounds: page).pdfData { renderer in
            for (index, frame) in frames.enumerated() {
                renderer.beginPage()
                let context = renderer.cgContext

                KmiPdfHeader.draw(
                    context: context,
                    pageWidth: page.width,
                    isEnglish: isEnglish,
                    titleHebrew: "צור קשר",
                    titleEnglish: "Contact Us",
                    subtitleHebrew: "פנייה לעמותת ק.מ.י",
                    subtitleEnglish: "KAMI Contact Request"
                )

                context.saveGState()
                context.translateBy(x: content.minX, y: content.maxY)
                context.scaleBy(x: 1, y: -1)

                if let lines = CTFrameGetLines(frame) as? [CTLine],
                   !lines.isEmpty {
                    var origins = Array(repeating: CGPoint.zero, count: lines.count)
                    origins.withUnsafeMutableBufferPointer { buffer in
                        if let baseAddress = buffer.baseAddress {
                            CTFrameGetLineOrigins(
                                frame,
                                CFRange(location: 0, length: 0),
                                baseAddress
                            )
                        }
                    }

                    let pageBounds = CGRect(origin: .zero, size: content.size)
                    let cardFill = UIColor(
                        KmiAppTheme.surfaceVariant(for: .light)
                    ).cgColor
                    let cardBorder = UIColor(
                        KmiAppTheme.outlineVariant(for: .light)
                    ).cgColor

                    context.saveGState()
                    context.clip(to: pageBounds)
                    context.setFillColor(cardFill)
                    context.setStrokeColor(cardBorder)
                    context.setLineWidth(0.75)

                    for fieldRange in fieldRanges {
                        var bounds = CGRect.null

                        for (index, line) in lines.enumerated() {
                            let range = CTLineGetStringRange(line)
                            let lineRange = NSRange(
                                location: range.location,
                                length: range.length
                            )
                            guard NSIntersectionRange(fieldRange, lineRange).length > 0 else {
                                continue
                            }

                            var ascent: CGFloat = 0
                            var descent: CGFloat = 0
                            CTLineGetTypographicBounds(line, &ascent, &descent, nil)

                            bounds = bounds.union(CGRect(
                                x: 1,
                                y: origins[index].y - descent - 4,
                                width: content.width - 2,
                                height: ascent + descent + 8
                            ))
                        }

                        let visibleBounds = bounds.intersection(
                            pageBounds.insetBy(dx: 0.5, dy: 0.5)
                        )
                        guard !visibleBounds.isEmpty else { continue }

                        let radius = min(8, visibleBounds.height / 2)
                        context.addPath(CGPath(
                            roundedRect: visibleBounds,
                            cornerWidth: radius,
                            cornerHeight: radius,
                            transform: nil
                        ))
                        context.drawPath(using: .fillStroke)
                    }

                    context.restoreGState()
                }

                context.textMatrix = .identity
                CTFrameDraw(frame, context)
                context.restoreGState()

                KmiPdfFooter.draw(
                    context: context,
                    pageWidth: page.width,
                    pageHeight: page.height,
                    pageNumber: index + 1,
                    totalPages: frames.count,
                    isEnglish: isEnglish
                )
            }
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("shared_pdfs", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let url = directory.appendingPathComponent(
            tr("צור קשר.pdf", "Contact Us.pdf")
        )
        try data.write(to: url, options: .atomic)
        return url
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

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .kmiIconSize(15)
                .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
                .frame(minWidth: 20)
                .accessibilityHidden(true)

            TextField(title, text: $text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(keyboardType == .default ? .words : .never)
                .autocorrectionDisabled(true)
                .kmiFont(size: 15, weight: .semibold)
                .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 52)
        .background(KmiAppTheme.surface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(KmiAppTheme.outlineVariant(for: colorScheme), lineWidth: 1)
                .allowsHitTesting(false)
        )
    }
}
