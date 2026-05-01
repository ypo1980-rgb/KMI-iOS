import SwiftUI

enum KmiEntryPhase {
    case language
    case loading
    case app
}

struct KmiAppEntryRootView<Content: View>: View {

    private let content: () -> Content

    @State private var phase: KmiEntryPhase
    @State private var selectedLanguage: KmiStartupLanguage

    init(
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content

        let defaults = UserDefaults.standard

        let hasSelectedLanguage =
            defaults.bool(forKey: "initial_language_selected") ||
            defaults.bool(forKey: "initial_language_selected_v2") ||
            defaults.bool(forKey: "initial_language_selected_v3") ||
            defaults.bool(forKey: "initial_language_selected_v4")

        let currentLanguage = KmiStartupLanguage.currentFromDefaults()

        _selectedLanguage = State(initialValue: currentLanguage)

        if hasSelectedLanguage {
            _phase = State(initialValue: .loading)
        } else {
            _phase = State(initialValue: .language)
        }
    }

    var body: some View {
        ZStack {
            switch phase {

            case .language:
                InitialLanguageScreen { language in
                    selectedLanguage = language

                    withAnimation(.easeInOut(duration: 0.25)) {
                        phase = .loading
                    }
                }

            case .loading:
                KmiStartupLoadingScreen(
                    isEnglish: selectedLanguage.isEnglish,
                    onFinished: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            phase = .app
                        }
                    }
                )

            case .app:
                content()
                    .environment(
                        \.layoutDirection,
                         selectedLanguage.isEnglish ? .leftToRight : .rightToLeft
                    )
            }
        }
        .environment(
            \.layoutDirection,
             selectedLanguage.isEnglish ? .leftToRight : .rightToLeft
        )
    }
}

#Preview {
    KmiAppEntryRootView {
        Text("App Root")
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
    }
}
