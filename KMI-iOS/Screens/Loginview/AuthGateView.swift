import SwiftUI

struct AuthGateView: View {

    @StateObject private var auth = AuthViewModel()
    @StateObject private var nav = AppNavModel()

    @State private var didEnterAuthFlow: Bool = false
    @State private var didBootstrap: Bool = false
    @State private var didFinishInitialAuthCheck: Bool = false
    @State private var didCompleteAuthScreen: Bool = false
    @State private var didFinishPostLoginLoading: Bool = false
    @State private var didRequestEnterApp: Bool = false

    private enum AuthEntryStep {
        case intro
        case choice
        case loginExistingTrainee
        case loginExistingCoach
        case registerNewTrainee
        case registerNewCoach
    }

    @State private var step: AuthEntryStep = .intro

    var body: some View {
        ZStack {
            KmiGradientBackground(forceTraineeStyle: true)

            Group {
                if didRequestEnterApp && !didFinishPostLoginLoading {

                    KmiStartupLoadingScreen(
                        isEnglish: KmiStartupLanguage.currentFromDefaults().isEnglish,
                        onFinished: {
                            didFinishPostLoginLoading = true
                        }
                    )

                } else if didRequestEnterApp {

                    ContentView()
                        .onAppear {
                            didCompleteAuthScreen = true
                        }
                } else {

                    authFlowStack
                }
            }
        }
        .environmentObject(auth)
        .onAppear {
            guard !didBootstrap else { return }
            didBootstrap = true

            didEnterAuthFlow = false
            didCompleteAuthScreen = false
            didFinishInitialAuthCheck = false
            didFinishPostLoginLoading = false
            didRequestEnterApp = false
            step = .intro
            nav.popToRoot()

            // נותן ל-SwiftUI לצייר קודם את מסך הכניסה/הרקע,
            // ורק אחרי זה מתחיל בדיקות Auth/Firebase.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                auth.start()
            }
        }
        .onChange(of: auth.isLoading) { _, isLoading in
            if !isLoading {
                didFinishInitialAuthCheck = true
            }
        }
        .onChange(of: auth.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                didCompleteAuthScreen = true
            }
        }
        
        .onDisappear {
            auth.stop()
        }
    }

    private var authFlowStack: some View {
        NavigationStack(path: $nav.path) {
            Group {
                switch step {

                case .intro:
                    KmiIntroGateScreen(
                        onGoogleLogin: {
                            Task { @MainActor in
                                let success = await auth.signInWithGoogle(
                                    expectedRole: "trainee",
                                    coachCode: nil
                                )

                                if success || auth.isSignedIn {
                                    didFinishPostLoginLoading = false
                                    didCompleteAuthScreen = true
                                    didRequestEnterApp = true
                                }
                            }
                        },
                        onRegularLogin: {
                            didEnterAuthFlow = true
                            didCompleteAuthScreen = false
                            step = .loginExistingTrainee
                        }
                    )

                case .choice:
                    KmiRootLayout(
                        title: "רישום משתמש",
                        nav: nav,
                        selectedIcon: nil
                    ) {
                        RegistrationChoiceView(
                            onNewUser: { step = .registerNewTrainee },
                            onExistingUser: { step = .loginExistingTrainee }
                        )
                    }

                case .loginExistingTrainee:
                    LoginView(
                        initialRole: .trainee,
                        onBackToChoice: { step = .intro },
                        onGoToRegister: { step = .registerNewTrainee },
                        onLoginSuccess: {
                            didCompleteAuthScreen = true
                            didFinishPostLoginLoading = false
                            didRequestEnterApp = true
                        }
                    )

                case .loginExistingCoach:
                    LoginView(
                        initialRole: .coach,
                        onBackToChoice: { step = .intro },
                        onGoToRegister: { step = .registerNewCoach },
                        onLoginSuccess: {
                            didCompleteAuthScreen = true
                            didFinishPostLoginLoading = false
                            didRequestEnterApp = true
                        }
                    )

                case .registerNewTrainee:
                    RegisterView(
                        prefillPhone: "",
                        prefillEmail: "",
                        initialRole: .trainee,
                        onBack: { step = .intro },
                        onSubmit: { _ in
                            if auth.isSignedIn {
                                didCompleteAuthScreen = true
                                didFinishPostLoginLoading = false
                                didRequestEnterApp = true
                            } else {
                                step = .loginExistingTrainee
                            }
                        },
                        onReadMoreTerms: { }
                    )

                case .registerNewCoach:
                    RegisterView(
                        prefillPhone: "",
                        prefillEmail: "",
                        initialRole: .coach,
                        onBack: { step = .intro },
                        onSubmit: { _ in
                            if auth.isSignedIn {
                                didCompleteAuthScreen = true
                                didFinishPostLoginLoading = false
                                didRequestEnterApp = true
                            } else {
                                step = .loginExistingCoach
                            }
                        },
                        onReadMoreTerms: { }
                    )
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .settings:
                    KmiRootLayout(
                        title: "הגדרות",
                        nav: nav,
                        selectedIcon: .settings
                    ) {
                        SettingsView(nav: nav)
                    }

                default:
                    ZStack {
                        KmiGradientBackground(forceTraineeStyle: true)

                        Text("Route לא נתמך עדיין")
                            .foregroundStyle(.white)
                            .font(.system(size: 18, weight: .bold))
                    }
                }
            }
        }
    }
}

private struct KmiIntroGateScreen: View {

    let onGoogleLogin: () -> Void
    let onRegularLogin: () -> Void

    @State private var startAnim: Bool = false
    @State private var bubbleOffset: CGFloat = -70
    @State private var isGoogleLoading: Bool = false

    private var isEnglish: Bool {
        KmiStartupLanguage.currentFromDefaults().isEnglish
    }

    private var firstName: String {
        let defaults = UserDefaults.standard

        let raw = [
            defaults.string(forKey: "fullName"),
            defaults.string(forKey: "full_name"),
            defaults.string(forKey: "displayName"),
            defaults.string(forKey: "display_name"),
            defaults.string(forKey: "user_name"),
            defaults.string(forKey: "name"),
            defaults.string(forKey: "firstName"),
            defaults.string(forKey: "first_name")
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty } ?? ""

        return raw
            .split(separator: " ", maxSplits: 1)
            .first
            .map(String.init) ?? raw
    }

    private struct IntroRankDisplay {
        let id: String
        let he: String
        let en: String
        let color: Color
        let imageName: String
    }

    private var currentRank: IntroRankDisplay? {
        let defaults = UserDefaults.standard

        let raw = [
            defaults.string(forKey: "current_belt"),
            defaults.string(forKey: "belt_current"),
            defaults.string(forKey: "currentBelt"),
            defaults.string(forKey: "beltId"),
            defaults.string(forKey: "belt_id"),
            defaults.string(forKey: "belt"),
            defaults.string(forKey: "belt_id_str")
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }

        guard let raw else { return nil }

        let clean = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch clean {
        case "white", "לבן", "לבנה", "חגורה לבנה":
            return IntroRankDisplay(
                id: "white",
                he: "לבנה",
                en: "White belt",
                color: Color(red: 0.88, green: 0.88, blue: 0.88),
                imageName: "belt_white"
            )
        case "yellow", "צהוב", "צהובה", "חגורה צהובה":
            return IntroRankDisplay(
                id: "yellow",
                he: "צהובה",
                en: "Yellow belt",
                color: Color(red: 1.00, green: 0.92, blue: 0.23),
                imageName: "belt_yellow"
            )
        case "orange", "כתום", "כתומה", "חגורה כתומה":
            return IntroRankDisplay(
                id: "orange",
                he: "כתומה",
                en: "Orange belt",
                color: Color(red: 1.00, green: 0.60, blue: 0.00),
                imageName: "belt_orange"
            )
        case "green", "ירוק", "ירוקה", "חגורה ירוקה":
            return IntroRankDisplay(
                id: "green",
                he: "ירוקה",
                en: "Green belt",
                color: Color(red: 0.30, green: 0.69, blue: 0.31),
                imageName: "belt_green"
            )
        case "blue", "כחול", "כחולה", "חגורה כחולה":
            return IntroRankDisplay(
                id: "blue",
                he: "כחולה",
                en: "Blue belt",
                color: Color(red: 0.13, green: 0.59, blue: 0.95),
                imageName: "belt_blue"
            )
        case "brown", "חום", "חומה", "חגורה חומה":
            return IntroRankDisplay(
                id: "brown",
                he: "חומה",
                en: "Brown belt",
                color: Color(red: 0.43, green: 0.30, blue: 0.22),
                imageName: "belt_brown"
            )
        case "black", "שחור", "שחורה", "חגורה שחורה", "שחורה דאן 1", "black_dan_1":
            return IntroRankDisplay(
                id: "black",
                he: "שחורה דאן 1",
                en: "Black belt Dan 1",
                color: Color(red: 0.08, green: 0.08, blue: 0.08),
                imageName: "belt_black"
            )
        case "black_dan_2":
            return IntroRankDisplay(
                id: "black_dan_2",
                he: "שחורה דאן 2",
                en: "Black belt Dan 2",
                color: Color(red: 0.08, green: 0.08, blue: 0.08),
                imageName: "belt_black"
            )
        case "black_dan_3":
            return IntroRankDisplay(
                id: "black_dan_3",
                he: "שחורה דאן 3",
                en: "Black belt Dan 3",
                color: Color(red: 0.08, green: 0.08, blue: 0.08),
                imageName: "belt_black"
            )
        case "black_dan_4":
            return IntroRankDisplay(
                id: "black_dan_4",
                he: "שחורה דאן 4",
                en: "Black belt Dan 4",
                color: Color(red: 0.08, green: 0.08, blue: 0.08),
                imageName: "belt_black"
            )
        case "black_dan_5":
            return IntroRankDisplay(
                id: "black_dan_5",
                he: "שחורה דאן 5",
                en: "Black belt Dan 5",
                color: Color(red: 0.08, green: 0.08, blue: 0.08),
                imageName: "belt_black"
            )
        case "black_dan_6":
            return IntroRankDisplay(
                id: "black_dan_6",
                he: "שחורה דאן 6",
                en: "Black belt Dan 6",
                color: Color(red: 0.08, green: 0.08, blue: 0.08),
                imageName: "belt_black"
            )
        case "black_dan_7":
            return IntroRankDisplay(
                id: "black_dan_7",
                he: "שחורה דאן 7",
                en: "Black belt Dan 7",
                color: Color(red: 0.08, green: 0.08, blue: 0.08),
                imageName: "belt_black"
            )
        case "black_dan_8":
            return IntroRankDisplay(
                id: "black_dan_8",
                he: "שחורה דאן 8",
                en: "Black belt Dan 8",
                color: Color(red: 0.08, green: 0.08, blue: 0.08),
                imageName: "belt_black"
            )
        case "black_dan_9":
            return IntroRankDisplay(
                id: "black_dan_9",
                he: "שחורה דאן 9",
                en: "Black belt Dan 9",
                color: Color(red: 0.08, green: 0.08, blue: 0.08),
                imageName: "belt_black"
            )
        case "black_dan_10":
            return IntroRankDisplay(
                id: "black_dan_10",
                he: "שחורה דאן 10",
                en: "Black belt Dan 10",
                color: Color(red: 0.08, green: 0.08, blue: 0.08),
                imageName: "belt_black"
            )
        default:
            return IntroRankDisplay(
                id: raw,
                he: raw,
                en: raw,
                color: Color.white.opacity(0.92),
                imageName: "belt_black"
            )
        }
    }

    private var greeting: String {
        if isEnglish {
            return firstName.isEmpty ? "Hello" : "Hello, \(firstName)"
        } else {
            return firstName.isEmpty ? "שלום" : "שלום \(firstName)"
        }
    }

    @ViewBuilder
    private var beltBadge: some View {
        if let rank = currentRank {
            VStack(spacing: 8) {
                Text(isEnglish ? rank.en : rank.he)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(rank.color)

                beltImageWithoutWhiteBackground(rank.imageName)
                    .frame(width: 112, height: 42)
                    .shadow(
                        color: rank.color.opacity(0.42),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
            }
        }
    }

    @ViewBuilder
    private func beltImageWithoutWhiteBackground(_ imageName: String) -> some View {
        Image(imageName)
            .resizable()
            .renderingMode(.original)
            .interpolation(.high)
            .scaledToFit()
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.07, blue: 0.10),
                    Color(red: 0.03, green: 0.22, blue: 0.18),
                    Color(red: 0.05, green: 0.11, blue: 0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(red: 0.09, green: 0.77, blue: 0.50).opacity(0.16),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 520
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 12)

                Text(isEnglish ? "K.M.I" : "ק.מ.י")
                    .font(.system(size: 58, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .scaleEffect(startAnim ? 1.0 : 0.72)
                    .opacity(startAnim ? 1.0 : 0.0)

                Text(isEnglish ? "Israeli Krav Magen" : "קרב מגן ישראלי")
                    .font(.system(size: isEnglish ? 22 : 30, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.90))
                    .lineLimit(1)
                    .scaleEffect(startAnim ? 1.0 : 0.72)
                    .opacity(startAnim ? 1.0 : 0.0)

                Text(greeting)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .padding(.top, 4)
                    .scaleEffect(startAnim ? 1.0 : 0.72)
                    .opacity(startAnim ? 1.0 : 0.0)

                beltBadge
                    .padding(.top, 2)
                    .offset(y: 14)
                    .scaleEffect(startAnim ? 1.0 : 0.72)
                    .opacity(startAnim ? 1.0 : 0.0)

                Spacer(minLength: 10)

                introImage
                    .frame(maxWidth: .infinity)
                    .frame(height: 250)
                    .padding(.horizontal, 8)
                    .scaleEffect(startAnim ? 1.0 : 0.86)
                    .opacity(startAnim ? 1.0 : 0.0)

                Spacer(minLength: 8)

                VStack(spacing: 4) {
                    googleButton

                    regularLoginButton
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
            }
            .padding(.top, 6)
            .padding(.bottom, 8)
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
        .onAppear {
            withAnimation(.easeOut(duration: 1.1)) {
                startAnim = true
            }

            withAnimation(
                .linear(duration: 2.2)
                .repeatForever(autoreverses: true)
            ) {
                bubbleOffset = 70
            }
        }
    }

    private var introImage: some View {
        Group {
            if let image = UIImage(named: "fighters_transparent") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if let image = UIImage(named: "fighters") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if let image = UIImage(named: "fighters_blackbelt") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "figure.martial.arts")
                    .font(.system(size: 96, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var regularLoginButton: some View {
        Button {
            onRegularLogin()
        } label: {
            Text(isEnglish ? "Use existing login / sign up screen" : "כניסה / רישום בדרך הרגילה")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.90))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.86)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isGoogleLoading)
    }

    private var googleButton: some View {
        Button {
            guard !isGoogleLoading else { return }
            isGoogleLoading = true
            onGoogleLogin()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.13, green: 0.53, blue: 0.93),
                                Color(red: 0.36, green: 0.20, blue: 0.72)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.28), radius: 10, x: 0, y: 8)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.40),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 74
                        )
                    )
                    .frame(width: 150, height: 150)
                    .offset(x: bubbleOffset)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                if isGoogleLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 16, weight: .bold))

                        Text(isEnglish ? "Continue with Google" : "התחברות עם Google")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isGoogleLoading)
    }
}
