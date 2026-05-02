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
                KmiBootLoadingView(
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

struct KmiBootLoadingView: View {
    var onFinished: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 16) {
                bootLogo

                ProgressView()
                    .tint(.black.opacity(0.55))
                    .padding(.top, 6)
            }
        }
        .onAppear {
            guard let onFinished else { return }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                onFinished()
            }
        }
    }

    @ViewBuilder
    private var bootLogo: some View {
        if let image = UIImage(named: "app_icon.png") {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 130, height: 130)
        } else if let image = UIImage(named: "app_icon") {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 130, height: 130)
        } else {
            Text("K.M.I")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(.black)
        }
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
