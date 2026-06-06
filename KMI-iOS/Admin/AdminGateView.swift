import SwiftUI

struct AdminGateView: View {

    @State private var isLoading = true
    @State private var isAdmin = false

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

            Group {
                if isLoading {
                    loadingCard
                } else if isAdmin {
                    AdminUsersView()
                } else {
                    blockedCard
                }
            }
        }
        .environment(\.layoutDirection, screenLayoutDirection)
        .task {
            await checkAdminAccess()
        }
    }

    private var loadingCard: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.15)

            Text(tr("בודק הרשאות מנהל...", "Checking admin permissions..."))
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(tr("רק מנהלים מורשים יכולים להיכנס למסך הזה.", "Only authorized admins can access this screen."))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.11))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .padding(.horizontal, 22)
    }

    private var blockedCard: some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 16) {
            HStack(spacing: 12) {
                if isEnglish {
                    lockIcon
                    blockedTitleTexts
                } else {
                    blockedTitleTexts
                    lockIcon
                }
            }

            Text(tr("המסך הזה זמין רק למנהלים מורשים. אם לדעתך אמורה להיות לך גישה, פנה למנהל המערכת.", "This screen is available only to authorized admins. If you believe you should have access, contact the system administrator."))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.74))
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)
                .lineSpacing(3)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.16, green: 0.03, blue: 0.08).opacity(0.76))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.red.opacity(0.32), lineWidth: 1)
        )
        .padding(.horizontal, 22)
    }

    private var lockIcon: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 26, weight: .black))
            .foregroundStyle(Color(red: 1.0, green: 0.70, blue: 0.70))
            .frame(width: 48, height: 48)
            .background(
                Circle()
                    .fill(Color.white.opacity(0.12))
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
    }

    private var blockedTitleTexts: some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 4) {
            Text(tr("אין הרשאת מנהל", "No admin access"))
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)

            Text(tr("הגישה למסך נחסמה", "Access to this screen is blocked"))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.68))
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)
        }
    }

    @MainActor
    private func checkAdminAccess() async {
        isLoading = true
        isAdmin = await AdminAccessService.isCurrentUserAdmin()
        isLoading = false
    }
}
