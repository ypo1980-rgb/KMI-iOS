import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

struct AuthGateView: View {

    @StateObject private var auth = AuthViewModel()
    @StateObject private var nav = AppNavModel()

    @State private var didEnterAuthFlow: Bool = false
    @State private var didBootstrap: Bool = false
    @State private var didFinishInitialAuthCheck: Bool = false
    @State private var didCompleteAuthScreen: Bool = false
    @State private var didFinishPostLoginLoading: Bool = true
    @State private var didRequestEnterApp: Bool = false

    /*
     * מסך הכניסה הוא תמיד המסך הראשון.
     * טעינת נתוני השרת מתחילה רק לאחר לחיצה על "המשך".
     */
    @State private var isCheckingServerUser: Bool = false
    @State private var canContinueExistingUser: Bool

    private enum AuthEntryStep {
        case intro
        case choice
        case loginExistingTrainee
        case loginExistingCoach
        case registerNewTrainee
        case registerNewCoach
    }

    @State private var step: AuthEntryStep = .intro

    init() {
        let existingUser: User? = {
            guard FirebaseApp.app() != nil else {
                return nil
            }

            return Auth.auth().currentUser
        }()

        /*
         * משתמש מחובר מזוהה מיד כמשתמש שיכול
         * לראות את כפתור "המשך".
         *
         * אין כאן פנייה ל־Firestore ואין הצגת
         * מסך טעינת נתונים.
         */
        let hasExistingSession =
            existingUser != nil &&
            existingUser?.isAnonymous == false

        _canContinueExistingUser = State(
            initialValue: hasExistingSession
        )
    }

    var body: some View {
        ZStack {
            KmiGradientBackground(forceTraineeStyle: true)

            Group {
                if isCheckingServerUser {
                    KmiStartupLoadingScreen(
                        isEnglish: KmiStartupLanguage.currentFromDefaults().isEnglish,
                        onFinished: { }
                    )

                } else if didRequestEnterApp && !didFinishPostLoginLoading {
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
                            didFinishPostLoginLoading = true
                        }

                } else {
                    authFlowStack
                }
            }
        }
        .environmentObject(auth)
        .onAppear {
            guard !didBootstrap else {
                return
            }

            didBootstrap = true

            didEnterAuthFlow = false
            didCompleteAuthScreen = false
            didFinishInitialAuthCheck = true
            didFinishPostLoginLoading = true
            didRequestEnterApp = false
            isCheckingServerUser = false
            step = .intro

            nav.popToRoot()
            auth.start()

            let existingUser =
                FirebaseApp.app() != nil
                    ? Auth.auth().currentUser
                    : nil

            /*
             * קובעים מיד איזה כפתור יוצג במסך הכניסה.
             * לא מבצעים כאן בדיקת Firestore.
             */
            canContinueExistingUser =
                existingUser != nil &&
                existingUser?.isAnonymous == false
        }
        .onChange(of: auth.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                /*
                 * לאחר התחברות מציגים "המשך".
                 * מסך הטעינה ייפתח רק בלחיצה על הכפתור.
                 */
                canContinueExistingUser = true
                isCheckingServerUser = false
                didFinishInitialAuthCheck = true
                step = .intro
            } else {
                resetToIntro()
            }
        }
        .onDisappear {
            auth.stop()
        }
    }

    private func resetToIntro() {
        isCheckingServerUser = false
        didRequestEnterApp = false
        didFinishPostLoginLoading = true
        didCompleteAuthScreen = false
        canContinueExistingUser = false
        step = .intro
    }

    private func prepareSignedInUserForIntro() {
        isCheckingServerUser = true
        didFinishInitialAuthCheck = false

        guard FirebaseApp.app() != nil else {
            completeInitialUserCheck(
                canContinue: false
            )
            return
        }

        guard let firebaseUser =
            Auth.auth().currentUser,
              !firebaseUser.isAnonymous else {
            completeInitialUserCheck(
                canContinue: false
            )
            return
        }

        let uid = firebaseUser.uid
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !uid.isEmpty else {
            completeInitialUserCheck(
                canContinue: false
            )
            return
        }

        Task {
            do {
                let snapshot =
                    try await Firestore.firestore()
                        .collection("users")
                        .document(uid)
                        .getDocument()

                let data =
                    snapshot.data() ?? [:]

                let isComplete =
                    snapshot.exists &&
                    persistAndCheckRequiredProfile(
                        data: data,
                        firebaseUser: firebaseUser
                    )

                await MainActor.run {
                    completeInitialUserCheck(
                        canContinue: isComplete
                    )
                }
            } catch {
                await MainActor.run {
                    /*
                     * אם קיים משתמש מחובר ופרופיל מקומי
                     * שמור, לא מחליפים אותו זמנית בכפתור Google
                     * בגלל כשל רשת רגעי.
                     */
                    let hasLocalProfile =
                        hasSavedLocalUserProfile()

                    completeInitialUserCheck(
                        canContinue: hasLocalProfile
                    )
                }
            }
        }
    }

    private func completeInitialUserCheck(
        canContinue: Bool
    ) {
        canContinueExistingUser = canContinue
        didFinishInitialAuthCheck = true
        isCheckingServerUser = false
        step = .intro
    }

    private func hasSavedLocalUserProfile() -> Bool {
        let defaults = UserDefaults.standard

        let uid =
            Auth.auth().currentUser?.uid
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                ) ?? ""

        let email =
            defaults.string(forKey: "email")?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                ) ?? ""

        let fullName =
            defaults.string(forKey: "fullName")?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                ) ?? ""

        let role =
            defaults.string(forKey: "user_role")?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                ) ?? ""

        return !uid.isEmpty &&
            !email.isEmpty &&
            !fullName.isEmpty &&
            !role.isEmpty
    }

    private func firstNonEmptyString(
        in data: [String: Any],
        keys: [String]
    ) -> String? {
        keys.compactMap { key in
            (data[key] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .first { !$0.isEmpty }
    }

    private func persistAndCheckRequiredProfile(
        data: [String: Any],
        firebaseUser: User
    ) -> Bool {
        let defaults = UserDefaults.standard

        let fullName = firstNonEmptyString(
            in: data,
            keys: [
                "fullName", "full_name", "displayName",
                "display_name", "name", "user_name"
            ]
        ) ?? firebaseUser.displayName?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let beltId = firstNonEmptyString(
            in: data,
            keys: [
                "current_belt", "belt_current", "currentBelt",
                "beltId", "belt_id", "belt", "belt_id_str",
                "registeredBelt", "registered_belt", "rank"
            ]
        )

        if let fullName, !fullName.isEmpty {
            defaults.set(fullName, forKey: "fullName")
        }

        if let beltId, !beltId.isEmpty {
            defaults.set(beltId, forKey: "current_belt")
        }

        return fullName?.isEmpty == false &&
            beltId?.isEmpty == false
    }

    private func routeSignedInUserByServerDocument() {
        guard FirebaseApp.app() != nil else {
            resetToIntro()
            return
        }

        guard let firebaseUser = Auth.auth().currentUser else {
            resetToIntro()
            return
        }

        if firebaseUser.isAnonymous {
            resetToIntro()
            return
        }

        let uid = firebaseUser.uid.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !uid.isEmpty else {
            resetToIntro()
            return
        }

        isCheckingServerUser = true
        didRequestEnterApp = false
        didFinishPostLoginLoading = true

        Task {
            do {
                let snapshot = try await Firestore.firestore()
                    .collection("users")
                    .document(uid)
                    .getDocument()

                await MainActor.run {
                    isCheckingServerUser = false

                    guard snapshot.exists,
                          let data = snapshot.data(),
                          persistAndCheckRequiredProfile(
                            data: data,
                            firebaseUser: firebaseUser
                          ) else {
                        canContinueExistingUser = false
                        didRequestEnterApp = false
                        didFinishPostLoginLoading = true
                        step = .registerNewTrainee
                        return
                    }

                    canContinueExistingUser = true
                    didCompleteAuthScreen = true
                    didFinishPostLoginLoading = false
                    didRequestEnterApp = true

                    auth.reloadProfileIfSignedIn()
                }

            } catch {
                await MainActor.run {
                    isCheckingServerUser = false
                    resetToIntro()
                }
            }
        }
    }

    private var authFlowStack: some View {
        NavigationStack(path: $nav.path) {
            Group {
                switch step {

                case .intro:
                    KmiIntroGateScreen(
                        canContinueExistingUser: canContinueExistingUser,
                        onExistingUserContinue: {
                            routeSignedInUserByServerDocument()
                        },
                        onGoogleLogin: {
                            if auth.isSignedIn {
                                routeSignedInUserByServerDocument()
                                return true
                            }

                            let success = await auth.signInWithGoogle(
                                expectedRole: "trainee",
                                coachCode: nil
                            )

                            if success || auth.isSignedIn {
                                routeSignedInUserByServerDocument()
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
                            routeSignedInUserByServerDocument()
                        }
                    )

                case .loginExistingCoach:
                    LoginView(
                        initialRole: .coach,
                        onBackToChoice: { step = .intro },
                        onGoToRegister: { step = .registerNewCoach },
                        onLoginSuccess: {
                            routeSignedInUserByServerDocument()
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
                                routeSignedInUserByServerDocument()
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
                                routeSignedInUserByServerDocument()
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

    @Environment(\.colorScheme)
    private var colorScheme

    let canContinueExistingUser: Bool
    let onExistingUserContinue: () -> Void
    let onGoogleLogin: () async -> Bool
    let onRegularLogin: () -> Void

    @State private var startAnim: Bool = false
    @State private var bubbleOffset: CGFloat = -70
    @State private var isGoogleLoading: Bool = false

    private var adaptiveCardBackground: Color {
        colorScheme == .dark
            ? Color(
                red: 0.055,
                green: 0.080,
                blue: 0.130
            )
            .opacity(0.94)
            : Color.white.opacity(0.88)
    }

    private var adaptivePrimaryText: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.94)
            : Color(
                red: 0.09,
                green: 0.13,
                blue: 0.20
            )
    }

    private var adaptiveSecondaryText: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.72)
            : Color(
                red: 0.22,
                green: 0.28,
                blue: 0.36
            )
    }

    private var adaptiveCardBorder: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.14)
            : Color.black.opacity(0.06)
    }

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

    private var introBackgroundAssetName: String {
        colorScheme == .dark
            ? "intro_welcome_screen_v2_dark"
            : "intro_welcome_screen_v2"
    }

    private var introBackgroundImage: some View {
        Group {
            if let image = UIImage(
                named: introBackgroundAssetName
            ) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    colorScheme == .dark
                        ? Color.black
                        : Color.white

                    Text(
                        "Missing asset:\n\(introBackgroundAssetName)"
                    )
                    .kmiFont(
                        size: 18,
                        weight: .heavy,
                        design: .rounded
                    )
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.white
                            : adaptivePrimaryText
                    )
                    .multilineTextAlignment(.center)
                    .padding()
                }
            }
        }
    }

    private func greetingCard(
        isCompactHeight: Bool
    ) -> some View {
        Text(greeting)
            .kmiFont(
                size: isCompactHeight ? 22 : 26,
                weight: .heavy,
                design: .rounded
            )
            .foregroundStyle(
                adaptivePrimaryText
            )
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(maxWidth: .infinity)
            .frame(
                minHeight:
                    isCompactHeight ? 38 : 42
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(
                    cornerRadius: 10,
                    style: .continuous
                )
                .fill(adaptiveCardBackground)
                .shadow(
                    color: Color.black.opacity(
                        colorScheme == .dark
                            ? 0.34
                            : 0.18
                    ),
                    radius: 4,
                    x: 0,
                    y: 2
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 10,
                    style: .continuous
                )
                .stroke(
                    adaptiveCardBorder,
                    lineWidth: 1
                )
            }
            .padding(.horizontal, 22)
    }

    @ViewBuilder
    private func beltRow(
        isCompactHeight: Bool
    ) -> some View {
        let rowHeight: CGFloat =
            isCompactHeight ? 72 : 82

        let imageWidth: CGFloat =
            isCompactHeight ? 130 : 150

        let imageHeight: CGFloat =
            isCompactHeight ? 30 : 36

        if let rank = currentRank {
            VStack(
                spacing:
                    isCompactHeight ? 3 : 5
            ) {
                Text(
                    isEnglish
                        ? rank.en
                        : rank.he
                )
                .kmiFont(
                    size:
                        isCompactHeight
                        ? 23
                        : 27,
                    weight: .heavy,
                    design: .rounded
                )
                .foregroundStyle(
                    rank.id == "white"
                        ? Color(
                            red: 0.60,
                            green: 0.64,
                            blue: 0.70
                        )
                        : rank.color
                )
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .frame(maxWidth: .infinity)

                beltImageWithoutWhiteBackground(
                    rank.imageName
                )
                .frame(
                    width: imageWidth,
                    height: imageHeight
                )
                .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .frame(height: rowHeight)
        } else {
            Text(
                isEnglish
                    ? "Belt has not been updated yet"
                    : "עדיין לא עודכנה חגורה"
            )
            .kmiFont(
                size:
                    isCompactHeight
                    ? 13
                    : 15,
                weight: .heavy,
                design: .rounded
            )
            .foregroundStyle(
                adaptivePrimaryText
            )
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.76)
            .frame(maxWidth: .infinity)
            .frame(height: rowHeight)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .fill(adaptiveCardBackground)
                .shadow(
                    color: Color.black.opacity(
                        colorScheme == .dark
                            ? 0.34
                            : 0.18
                    ),
                    radius: 4,
                    x: 0,
                    y: 2
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .stroke(
                    adaptiveCardBorder,
                    lineWidth: 1
                )
            }
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
                Color(
                    colorScheme == .dark
                        ? UIColor.systemBackground
                        : UIColor.white
                )
                .ignoresSafeArea()

                introBackgroundImage
                    .frame(
                        width: geo.size.width,
                        height: geo.size.height
                    )
                    .clipped()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: height * 0.185)

                    greetingCard(isCompactHeight: isCompactHeight)
                        .padding(.horizontal, horizontalPadding)

                    Spacer()
                        .frame(height: height * 0.455)

                    beltRow(
                        isCompactHeight: isCompactHeight
                    )
                    .padding(.horizontal, horizontalPadding)
                    .offset(
                        y: -(height * 0.015)
                    )

                    Spacer(minLength: 0)

                    VStack(spacing: 8) {
                        primaryButton

                        if !canContinueExistingUser {
                            regularLoginButton
                        }
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
            Text(
                isEnglish
                    ? "Existing login / regular registration"
                    : "כניסה / רישום בדרך הרגילה"
            )
            .kmiFont(
                size: 14,
                weight: .bold,
                design: .rounded
            )
            .foregroundStyle(
                adaptivePrimaryText
            )
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.68)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 36)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(
                    cornerRadius: 20,
                    style: .continuous
                )
                .fill(adaptiveCardBackground)
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 20,
                    style: .continuous
                )
                .stroke(
                    adaptiveCardBorder,
                    lineWidth: 1
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isGoogleLoading)
    }

    private var primaryButton: some View {
        Button {
            guard !isGoogleLoading else { return }

            if canContinueExistingUser {
                onExistingUserContinue()
                return
            }

            isGoogleLoading = true

            Task { @MainActor in
                let success = await onGoogleLogin()

                if !success {
                    isGoogleLoading = false
                }
            }
        } label: {
            ZStack {
                RoundedRectangle(
                    cornerRadius: 24,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [
                            Color(
                                red: 18.0 / 255.0,
                                green: 168.0 / 255.0,
                                blue: 244.0 / 255.0
                            ),
                            Color(
                                red: 76.0 / 255.0,
                                green: 24.0 / 255.0,
                                blue: 216.0 / 255.0
                            )
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(
                    color: Color.black.opacity(0.28),
                    radius: 6,
                    x: 0,
                    y: 4
                )

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
                    Text(
                        canContinueExistingUser
                            ? (
                                isEnglish
                                    ? "Continue"
                                    : "המשך"
                            )
                            : (
                                isEnglish
                                    ? "★ Continue with Google"
                                    : "התחברות עם Google ★"
                            )
                    )
                    .kmiFont(
                        size: 18,
                        weight: .bold,
                        design: .rounded
                    )
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
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
