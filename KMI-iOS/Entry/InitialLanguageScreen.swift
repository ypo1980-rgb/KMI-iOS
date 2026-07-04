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

    init(
        onLanguageSelected: @escaping (KmiStartupLanguage) -> Void
    ) {
        self.onLanguageSelected = onLanguageSelected
    }

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: 0) {
                Text("בחר שפה\nChoose Language")
                    .font(.system(size: 28, weight: .heavy, design: .default))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Spacer()
                    .frame(height: 40)

                languageButton(
                    text: "עברית 🇮🇱",
                    language: .hebrew
                )

                Spacer()
                    .frame(height: 18)

                languageButton(
                    text: "English 🇺🇸",
                    language: .english
                )
            }
            .padding(.horizontal, 28)
        }
        .ignoresSafeArea()
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color(red: 0.0588, green: 0.0902, blue: 0.1647),
                Color(red: 0.1176, green: 0.1608, blue: 0.2314),
                Color(red: 0.0078, green: 0.0235, blue: 0.0902)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func languageButton(
        text: String,
        language: KmiStartupLanguage
    ) -> some View {
        Button {
            selectLanguage(language)
        } label: {
            Text(text)
                .font(.system(size: 17, weight: .bold, design: .default))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: clickLocked
                                ? [
                                    Color(red: 0.2784, green: 0.3333, blue: 0.4118),
                                    Color(red: 0.2, green: 0.2549, blue: 0.3333),
                                    Color(red: 0.1176, green: 0.1608, blue: 0.2314)
                                ]
                                : [
                                    Color(red: 0.3882, green: 0.4, blue: 0.9451),
                                    Color(red: 0.2314, green: 0.5098, blue: 0.9647),
                                    Color(red: 0.0235, green: 0.7137, blue: 0.8314)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(
                            color: Color.black.opacity(clickLocked ? 0.12 : 0.32),
                            radius: clickLocked ? 2 : 10,
                            x: 0,
                            y: clickLocked ? 1 : 6
                        )
                )
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!clickLocked)
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

        onLanguageSelected(language)
    }
}

#Preview {
    InitialLanguageScreen { _ in }
}
