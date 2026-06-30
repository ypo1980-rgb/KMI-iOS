import SwiftUI
import FirebaseAuth

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

    private func firstNonBlankProfileValue(_ values: String?...) -> String {
        values
            .map { ($0 ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
    }

    private func hasAnyNonBlankDefaultValue(_ keys: [String]) -> Bool {
        let defaults = UserDefaults.standard

        return keys.contains { key in
            let value = defaults.string(forKey: key)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            return !value.isEmpty
        }
    }

    private var shouldSkipIntroForKnownUser: Bool {
        let defaults = UserDefaults.standard

        guard let firebaseUser = Auth.auth().currentUser else {
            return false
        }

        if firebaseUser.isAnonymous {
            return false
        }

        let uid = firebaseUser.uid.trimmingCharacters(in: .whitespacesAndNewlines)

        if uid.isEmpty {
            return false
        }

        let completedUid = firstNonBlankProfileValue(
            defaults.string(forKey: "profile_completed_uid"),
            defaults.string(forKey: "uid"),
            defaults.string(forKey: "user_uid"),
            defaults.string(forKey: "firebase_uid"),
            defaults.string(forKey: "auth_uid")
        )

        let uidMatches = completedUid.isEmpty || completedUid == uid

        let email = firstNonBlankProfileValue(
            defaults.string(forKey: "email"),
            defaults.string(forKey: "user_email"),
            firebaseUser.email
        )

        let phone = firstNonBlankProfileValue(
            defaults.string(forKey: "phone"),
            defaults.string(forKey: "phone_number"),
            defaults.string(forKey: "phoneNumber"),
            defaults.string(forKey: "phoneRaw"),
            defaults.string(forKey: "user_phone"),
            defaults.string(forKey: "mobilePhone")
        )
        .filter { $0.isNumber }

        let localProfileCompleted =
            defaults.bool(forKey: "profile_completed") ||
            defaults.bool(forKey: "registration_complete")

        let hasStoredCompletedProfile =
            hasAnyNonBlankDefaultValue([
                "fullName",
                "full_name",
                "displayName",
                "display_name",
                "user_name",
                "name"
            ]) &&
            hasAnyNonBlankDefaultValue([
                "region",
                "active_region",
                "user_region"
            ]) &&
            hasAnyNonBlankDefaultValue([
                "branch",
                "active_branch",
                "activeBranch",
                "user_branch",
                "traineeBranch"
            ]) &&
            hasAnyNonBlankDefaultValue([
                "username",
                "userName",
                "user_name"
            ])

        return uidMatches &&
               (localProfileCompleted || hasStoredCompletedProfile) &&
               !email.isEmpty &&
               phone.count >= 9
    }

    private func enterAppThroughStartupLoading() {
        auth.reloadProfileIfSignedIn()
        didCompleteAuthScreen = true
        didFinishPostLoginLoading = false
        didRequestEnterApp = true
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

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    if shouldSkipIntroForKnownUser {
                        enterAppThroughStartupLoading()
                    }
                }
            }
        }
        .onChange(of: auth.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                if shouldSkipIntroForKnownUser {
                    auth.reloadProfileIfSignedIn()
                    didCompleteAuthScreen = true
                    didFinishPostLoginLoading = false
                    didRequestEnterApp = true
                } else {
                    didCompleteAuthScreen = true
                }
            } else {
                didRequestEnterApp = false
                didFinishPostLoginLoading = false
                didCompleteAuthScreen = false
                step = .intro
            }
        }
        .onChange(of: auth.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                if shouldSkipIntroForKnownUser {
                    auth.reloadProfileIfSignedIn()
                    didCompleteAuthScreen = true
                    didFinishPostLoginLoading = false
                    didRequestEnterApp = true
                } else {
                    didCompleteAuthScreen = true
                }
            } else {
                didRequestEnterApp = false
                didFinishPostLoginLoading = false
                didCompleteAuthScreen = false
                step = .intro
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
                            if auth.isSignedIn {
                                auth.reloadProfileIfSignedIn()
                                didFinishPostLoginLoading = false
                                didCompleteAuthScreen = true
                                didRequestEnterApp = true
                                return true
                            }

                            let success = await auth.signInWithGoogle(
                                expectedRole: "trainee",
                                coachCode: nil
                            )

                            if success || auth.isSignedIn {
                                didFinishPostLoginLoading = false
                                didCompleteAuthScreen = true
                                didRequestEnterApp = true
                                return true
                            }

                            return false
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

    let onGoogleLogin: () async -> Bool
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

    private var introBackgroundImage: some View {
        Group {
            if let image = UIImage(named: "intro_welcome_screen_v2") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(red: 0.03, green: 0.07, blue: 0.10)

                    Text("Missing asset:\nintro_welcome_screen_v2")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
        }
    }

    private func greetingCard(isCompactHeight: Bool) -> some View {
        Text(greeting)
            .font(
                .system(
                    size: isCompactHeight ? 22 : 26,
                    weight: .heavy,
                    design: .rounded
                )
            )
            .foregroundStyle(Color(red: 0.09, green: 0.13, blue: 0.20))
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .frame(maxWidth: .infinity)
            .frame(height: isCompactHeight ? 38 : 42)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.88))
                    .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
            )
            .padding(.horizontal, 22)
    }

    @ViewBuilder
    private func beltRow(isCompactHeight: Bool) -> some View {
        if let rank = currentRank {
            HStack(spacing: isCompactHeight ? 8 : 12) {
                Text(isEnglish ? rank.en : rank.he)
                    .font(
                        .system(
                            size: isCompactHeight ? 19 : 22,
                            weight: .heavy,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(rank.color)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                beltImageWithoutWhiteBackground(rank.imageName)
                    .frame(
                        width: isCompactHeight ? 112 : 128,
                        height: isCompactHeight ? 34 : 42
                    )
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .frame(height: isCompactHeight ? 40 : 46)
            .padding(.horizontal, 10)
        } else {
            Text(isEnglish ? "Belt has not been updated yet" : "עדיין לא עודכנה חגורה")
                .font(
                    .system(
                        size: isCompactHeight ? 13 : 15,
                        weight: .heavy,
                        design: .rounded
                    )
                )
                .foregroundStyle(Color(red: 0.09, green: 0.13, blue: 0.20))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)
                .frame(height: isCompactHeight ? 40 : 46)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.86))
                        .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
                )
                .padding(.horizontal, 22)
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
        GeometryReader { geo in
            let height = geo.size.height
            let isCompactHeight = height < 760
            let horizontalPadding: CGFloat = isCompactHeight ? 24 : 30

            ZStack {
                introBackgroundImage
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: height * 0.185)

                    greetingCard(isCompactHeight: isCompactHeight)
                        .padding(.horizontal, horizontalPadding)

                    Spacer()
                        .frame(height: height * 0.455)

                    beltRow(isCompactHeight: isCompactHeight)
                        .padding(.horizontal, horizontalPadding)

                    Spacer(minLength: 0)

                    VStack(spacing: 8) {
                        googleButton

                        regularLoginButton
                    }
                    .padding(.horizontal, horizontalPadding + 8)

                    Spacer()
                        .frame(height: isCompactHeight ? 8 : 14)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
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

    private var regularLoginButton: some View {
        Button {
            onRegularLogin()
        } label: {
            Text(isEnglish ? "Existing login / regular registration" : "כניסה / רישום בדרך הרגילה")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.09, green: 0.13, blue: 0.20))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.88))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isGoogleLoading)
    }

    private var googleButton: some View {
        Button {
            guard !isGoogleLoading else { return }

            isGoogleLoading = true

            Task { @MainActor in
                let success = await onGoogleLogin()

                if !success {
                    isGoogleLoading = false
                }
            }
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
            .frame(height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isGoogleLoading)
    }
}
