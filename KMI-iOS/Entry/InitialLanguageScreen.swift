import SwiftUI

enum KmiStartupLanguage: String, CaseIterable {
    case hebrew = "HEBREW"
    case english = "ENGLISH"

    var isEnglish: Bool {
        self == .english
    }

    var languageCode: String {
        switch self {
        case .hebrew:
            return "he"
        case .english:
            return "en"
        }
    }

    var layoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    static func currentFromDefaults() -> KmiStartupLanguage {
        let defaults = UserDefaults.standard

        if let raw = defaults.string(forKey: "initial_language_code"),
           let lang = KmiStartupLanguage(rawValue: raw) {
            return lang
        }

        if let raw = defaults.string(forKey: "app_language"),
           let lang = KmiStartupLanguage(rawValue: raw) {
            return lang
        }

        if let raw = defaults.string(forKey: "kmi_app_language") {
            if raw.lowercased() == "en" || raw.uppercased() == "ENGLISH" {
                return .english
            }

            if raw.lowercased() == "he" || raw.uppercased() == "HEBREW" {
                return .hebrew
            }
        }

        return .hebrew
    }
}

struct InitialLanguageScreen: View {

    let onLanguageSelected: (KmiStartupLanguage) -> Void

    @AppStorage("initial_language_selected") private var selectedV1: Bool = false
    @AppStorage("initial_language_selected_v2") private var selectedV2: Bool = false
    @AppStorage("initial_language_selected_v3") private var selectedV3: Bool = false
    @AppStorage("initial_language_selected_v4") private var selectedV4: Bool = false

    @State private var clickLocked: Bool = false
    @State private var cardScale: CGFloat = 0.96
    @State private var glowOpacity: Double = 0.18

    init(
        onLanguageSelected: @escaping (KmiStartupLanguage) -> Void
    ) {
        self.onLanguageSelected = onLanguageSelected
    }

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: 0) {
                Spacer(minLength: 40)

                headerView

                Spacer()
                    .frame(height: 42)

                VStack(spacing: 18) {
                    languageButton(
                        title: "עברית",
                        subtitle: "המשך בעברית",
                        flag: "🇮🇱",
                        language: .hebrew
                    )

                    languageButton(
                        title: "English",
                        subtitle: "Continue in English",
                        flag: "🇺🇸",
                        language: .english
                    )
                }
                .padding(.horizontal, 28)

                Spacer(minLength: 44)

                footerView
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.6)
                .repeatForever(autoreverses: true)
            ) {
                cardScale = 1.02
                glowOpacity = 0.36
            }
        }
    }

    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.07, blue: 0.11),
                    Color(red: 0.06, green: 0.11, blue: 0.17),
                    Color(red: 0.02, green: 0.03, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(red: 0.08, green: 0.77, blue: 0.50).opacity(glowOpacity))
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .offset(x: 0, y: -170)

            Circle()
                .fill(Color(red: 0.18, green: 0.48, blue: 0.95).opacity(0.13))
                .frame(width: 300, height: 300)
                .blur(radius: 95)
                .offset(x: -160, y: 230)

            Circle()
                .fill(Color(red: 0.08, green: 0.77, blue: 0.50).opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 80)
                .offset(x: 160, y: 300)
        }
    }

    private var headerView: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.08, green: 0.77, blue: 0.50).opacity(0.30),
                                Color(red: 0.08, green: 0.77, blue: 0.50).opacity(0.08),
                                Color.white.opacity(0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(cardScale)
                    .blur(radius: 2)

                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 104, height: 104)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 12)

                VStack(spacing: 4) {
                    Text("K.M.I")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text("קרב מגן")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.78))
                }
            }

            VStack(spacing: 10) {
                Text("בחר שפה")
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Choose Language")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.88))
                    .multilineTextAlignment(.center)

                Text("ניתן לשנות את השפה גם בהמשך מתוך ההגדרות")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)

                Text("You can change the language later in Settings")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
        }
    }

    private var footerView: some View {
        Text("Krav Magen Israeli")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(Color.white.opacity(0.46))
            .padding(.bottom, 28)
    }

    private func languageButton(
        title: String,
        subtitle: String,
        flag: String,
        language: KmiStartupLanguage
    ) -> some View {
        Button {
            selectLanguage(language)
        } label: {
            HStack(spacing: 14) {
                Text(flag)
                    .font(.system(size: 30))

                VStack(alignment: language == .english ? .leading : .trailing, spacing: 3) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.72))
                }
                .frame(maxWidth: .infinity, alignment: language == .english ? .leading : .trailing)

                Image(systemName: language == .english ? "chevron.right" : "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.82))
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: clickLocked
                            ? [
                                Color(red: 0.25, green: 0.31, blue: 0.40),
                                Color(red: 0.18, green: 0.23, blue: 0.31)
                            ]
                            : [
                                Color(red: 0.13, green: 0.34, blue: 0.95),
                                Color(red: 0.08, green: 0.60, blue: 0.86),
                                Color(red: 0.08, green: 0.77, blue: 0.50)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(
                        color: clickLocked ? Color.clear : Color.black.opacity(0.30),
                        radius: 16,
                        x: 0,
                        y: 10
                    )
            )
            .opacity(clickLocked ? 0.65 : 1.0)
        }
        .disabled(clickLocked)
        .environment(\.layoutDirection, language.layoutDirection)
    }

    private func selectLanguage(_ language: KmiStartupLanguage) {
        guard clickLocked == false else {
            return
        }

        clickLocked = true

        selectedV1 = true
        selectedV2 = true
        selectedV3 = true
        selectedV4 = true

        let defaults = UserDefaults.standard

        defaults.set(true, forKey: "initial_language_selected")
        defaults.set(true, forKey: "initial_language_selected_v2")
        defaults.set(true, forKey: "initial_language_selected_v3")
        defaults.set(true, forKey: "initial_language_selected_v4")

        defaults.set(language.rawValue, forKey: "initial_language_code")
        defaults.set(language.rawValue, forKey: "app_language")
        defaults.set(language.languageCode, forKey: "kmi_app_language")
        defaults.set(language.languageCode, forKey: "selected_language_code")

        defaults.synchronize()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            onLanguageSelected(language)
        }
    }
}

#Preview {
    InitialLanguageScreen { _ in }
}
