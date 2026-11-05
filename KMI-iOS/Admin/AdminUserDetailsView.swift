import SwiftUI
struct AdminUserDetailsView: View {
    let user: AdminUser
    @Environment(\.colorScheme) private var colorScheme
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
            return KmiAppTheme.primary(for: colorScheme)
        }
        if AdminUser.isCoachRole(user.role) {
            return KmiAppTheme.secondary(for: colorScheme)
        }
        return KmiAppTheme.success(for: colorScheme)
    }
    var body: some View {
        ZStack {
            KmiAppBackground()
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
                .kmiTypography(.screenTitle)
                .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)
            Text(tr("נתוני משתמש אמיתיים ממסך הניהול", "Real user data from the admin screen"))
                .kmiTypography(.secondary)
                .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)
        }
    }
    // MARK: Header
    private var headerCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .kmiIconSize(.hero)
                .foregroundStyle(roleColor)
            Text(displayNameValue(user.fullName))
                .kmiTypography(.screenTitle)
                .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if !user.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(user.email)
                    .kmiTypography(.body)
                    .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            roleBadge
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(KmiAppTheme.surface(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(KmiAppTheme.outlineVariant(for: colorScheme), lineWidth: 1)
        )
    }
    private var roleBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: roleIcon)
                .resizable()
                .scaledToFit()
                .kmiIconSize(.tiny)
            Text(roleText)
                .kmiTypography(.caption)
                .lineLimit(1)
        }
        .foregroundStyle(roleColor)
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(roleColor.opacity(0.16))
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
                .fill(KmiAppTheme.surface(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(KmiAppTheme.outlineVariant(for: colorScheme), lineWidth: 1)
        )
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
                            .kmiTypography(.cardTitle)
                            .foregroundStyle(roleColor)
                        Text(roleDescription)
                            .kmiTypography(.secondary)
                            .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(roleText)
                            .kmiTypography(.cardTitle)
                            .foregroundStyle(roleColor)
                        Text(roleDescription)
                            .kmiTypography(.secondary)
                            .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
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
                .fill(KmiAppTheme.surface(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(KmiAppTheme.outlineVariant(for: colorScheme), lineWidth: 1)
        )
    }
    private var roleCircle: some View {
        ZStack {
            Circle()
                .fill(roleColor.opacity(0.16))
                .frame(width: 48, height: 48)
            Image(systemName: roleIcon)
                .resizable()
                .scaledToFit()
                .kmiIconSize(.medium)
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
                    .resizable()
                    .scaledToFit()
                    .kmiIconSize(.small)
                    .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
                Text(title)
                    .kmiTypography(.sectionTitle)
                    .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                Text(title)
                    .kmiTypography(.sectionTitle)
                    .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .kmiIconSize(.small)
                    .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
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
                    .resizable()
                    .scaledToFit()
                    .kmiIconSize(.small)
                    .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .kmiTypography(.secondary)
                        .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                    Text(cleanValue(value))
                        .kmiTypography(.body)
                        .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(title)
                        .kmiTypography(.secondary)
                        .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                    Text(cleanValue(value))
                        .kmiTypography(.body)
                        .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                }
                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .kmiIconSize(.small)
                    .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
                    .frame(width: 22)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(KmiAppTheme.surfaceVariant(for: colorScheme))
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
