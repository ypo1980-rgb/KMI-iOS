import SwiftUI

struct AdminUserDetailsView: View {

    let user: AdminUser

    @AppStorage("kmi_app_language") private var kmiAppLanguage: String = ""
    @AppStorage("app_language") private var appLanguage: String = ""
    @AppStorage("initial_language_code") private var initialLanguageCode: String = ""
    @AppStorage("selected_language_code") private var selectedLanguageCode: String = ""

    private var effectiveLanguageCode: String {
        let candidates = [
            kmiAppLanguage,
            appLanguage,
            selectedLanguageCode,
            initialLanguageCode
        ]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        return candidates.first ?? "he"
    }

    private var isEnglish: Bool {
        effectiveLanguageCode.hasPrefix("en")
    }

    private var screenLayoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    private var screenTextAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var screenFrameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private var navigationTitleText: String {
        tr("פרטי משתמש", "User details")
    }

    private var roleText: String {
        if AdminUser.isAdminRole(user.role) {
            return tr("מנהל", "Admin")
        }

        if AdminUser.isCoachRole(user.role) {
            return tr("מאמן", "Coach")
        }

        return tr("מתאמן", "Trainee")
    }

    private var roleIcon: String {
        if AdminUser.isAdminRole(user.role) {
            return "person.badge.key.fill"
        }

        if AdminUser.isCoachRole(user.role) {
            return "figure.martial.arts"
        }

        return "person.fill"
    }

    private var roleColor: Color {
        if AdminUser.isAdminRole(user.role) {
            return Color.purple.opacity(0.92)
        }

        if AdminUser.isCoachRole(user.role) {
            return Color.blue.opacity(0.92)
        }

        return Color.green.opacity(0.88)
    }

    var body: some View {

        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.04, blue: 0.11),
                    Color(red: 0.07, green: 0.12, blue: 0.22),
                    Color(red: 0.08, green: 0.30, blue: 0.55),
                    Color(red: 0.03, green: 0.64, blue: 0.89)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {

                    screenHeader

                    headerCard

                    infoCard

                    roleCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .environment(\.layoutDirection, screenLayoutDirection)
        .navigationTitle(navigationTitleText)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Screen header

    private var screenHeader: some View {

        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 5) {
            Text(tr("פרטי משתמש", "User details"))
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)

            Text(tr("נתוני משתמש אמיתיים ממסך הניהול", "Real user data from the admin screen"))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)
        }
    }

    // MARK: Header

    private var headerCard: some View {

        VStack(spacing: 12) {

            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(roleColor)

            Text(displayNameValue(user.fullName))
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Color.black.opacity(0.86))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if !user.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(user.email)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.54))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }

            roleBadge
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 5)
    }

    private var roleBadge: some View {

        HStack(spacing: 6) {
            Image(systemName: roleIcon)
                .font(.system(size: 12, weight: .black))

            Text(roleText)
                .font(.system(size: 13, weight: .black))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(roleColor)
        )
    }

    // MARK: Info

    private var infoCard: some View {

        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 12) {

            sectionTitle(
                tr("פרטים כלליים", "General details"),
                icon: "info.circle.fill"
            )

            VStack(spacing: 10) {
                infoRow(
                    title: tr("שם מלא", "Full name"),
                    value: displayNameValue(user.fullName),
                    icon: "person.fill"
                )

                infoRow(
                    title: tr("אימייל", "Email"),
                    value: user.email,
                    icon: "envelope.fill"
                )

                infoRow(
                    title: tr("טלפון", "Phone"),
                    value: user.phone,
                    icon: "phone.fill"
                )

                infoRow(
                    title: tr("סניף", "Branch"),
                    value: user.branch,
                    icon: "building.2.fill"
                )

                infoRow(
                    title: tr("קבוצה", "Group"),
                    value: user.group,
                    icon: "person.3.fill"
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    // MARK: Role

    private var roleCard: some View {

        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 12) {

            sectionTitle(
                tr("סוג משתמש", "User type"),
                icon: roleIcon
            )

            HStack(spacing: 12) {
                if isEnglish {
                    roleCircle

                    VStack(alignment: .leading, spacing: 4) {
                        Text(roleText)
                            .font(.system(size: 19, weight: .black))
                            .foregroundStyle(roleColor)

                        Text(roleDescription)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.52))
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 0)

                } else {
                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(roleText)
                            .font(.system(size: 19, weight: .black))
                            .foregroundStyle(roleColor)

                        Text(roleDescription)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.52))
                            .multilineTextAlignment(.trailing)
                    }

                    roleCircle
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(roleColor.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(roleColor.opacity(0.18), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    private var roleCircle: some View {

        ZStack {
            Circle()
                .fill(roleColor.opacity(0.16))
                .frame(width: 48, height: 48)

            Image(systemName: roleIcon)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(roleColor)
        }
    }

    private var roleDescription: String {
        if AdminUser.isAdminRole(user.role) {
            return tr(
                "משתמש עם הרשאות ניהול באפליקציה.",
                "User with admin permissions in the app."
            )
        }

        if AdminUser.isCoachRole(user.role) {
            return tr(
                "משתמש שמזוהה כמאמן ויכול להופיע במסכי מאמן.",
                "User identified as a coach and can appear in coach screens."
            )
        }

        return tr(
            "משתמש שמזוהה כמתאמן באפליקציה.",
            "User identified as a trainee in the app."
        )
    }

    // MARK: Shared UI

    private func sectionTitle(_ title: String, icon: String) -> some View {

        HStack(spacing: 8) {
            if isEnglish {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.black.opacity(0.60))

                Text(title)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Color.black.opacity(0.82))

                Spacer(minLength: 0)

            } else {
                Spacer(minLength: 0)

                Text(title)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Color.black.opacity(0.82))

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.black.opacity(0.60))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func infoRow(
        title: String,
        value: String,
        icon: String
    ) -> some View {

        HStack(spacing: 10) {
            if isEnglish {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.38))
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.46))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)

                    Text(cleanValue(value))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.78))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

            } else {
                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.46))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)

                    Text(cleanValue(value))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.78))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                }

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.38))
                    .frame(width: 22)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.035))
        )
    }

    private func displayNameValue(_ value: String) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if clean.isEmpty || clean.lowercased() == "null" || clean == "-" {
            return tr("שם מלא לא הוזן", "Full name not entered")
        }

        if clean.count >= 24 &&
            clean.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil {
            return tr("שם מלא לא הוזן", "Full name not entered")
        }

        return clean
    }

    private func cleanValue(_ value: String) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if clean.isEmpty || clean.lowercased() == "null" {
            return "-"
        }

        return clean
    }
}
