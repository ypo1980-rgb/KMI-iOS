import SwiftUI

struct AuthGateView: View {

    @StateObject private var auth = AuthViewModel()
    @StateObject private var nav = AppNavModel()

    @State private var didEnterAuthFlow: Bool = false
    @State private var didBootstrap: Bool = false
    @State private var didFinishInitialAuthCheck: Bool = false
    @State private var didCompleteAuthScreen: Bool = false

    private enum AuthEntryStep {
        case choice
        case loginExistingTrainee
        case loginExistingCoach
        case registerNewTrainee
        case registerNewCoach
    }

    @State private var step: AuthEntryStep = .choice

    var body: some View {
        Group {
            if !didFinishInitialAuthCheck && auth.isLoading {

                ZStack {
                    KmiGradientBackground()

                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                }

            } else if !didEnterAuthFlow {

                IntroGateView(
                    onContinue: {
                        didEnterAuthFlow = true
                        didCompleteAuthScreen = false
                        step = .loginExistingTrainee
                    }
                )

            } else if !didCompleteAuthScreen {

                authFlowStack

            } else if auth.isSignedIn {

                ContentView()
                    .onAppear {
                        #if DEBUG
                        print("✅ AuthGateView: auth.isSignedIn == true && didCompleteAuthScreen == true -> showing ContentView")
                        #endif
                    }

            } else {

                authFlowStack
            }
        }
        .environmentObject(auth)
        .onAppear {
            guard !didBootstrap else { return }
            didBootstrap = true

            didEnterAuthFlow = false
            didCompleteAuthScreen = false
            step = .loginExistingTrainee
            nav.popToRoot()
            auth.start()

            DispatchQueue.main.async {
                didFinishInitialAuthCheck = true
            }
        }
        .onChange(of: auth.isSignedIn) { _, isSignedIn in
            if didEnterAuthFlow && isSignedIn {
                didCompleteAuthScreen = true

                #if DEBUG
                print("✅ AuthGateView: detected signed-in user after auth flow -> moving to ContentView")
                #endif
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

                case .choice:
                    KmiRootLayout(
                        title: "רישום משתמש",
                        nav: nav,
                        selectedIcon: nil
                    ) {
                        RegistrationChoiceView(
                            onNewUserTrainee: { step = .registerNewTrainee },
                            onExistingUserTrainee: { step = .loginExistingTrainee },
                            onNewUserCoach: { step = .registerNewCoach },
                            onExistingUserCoach: { step = .loginExistingCoach }
                        )
                    }

                case .loginExistingTrainee:
                    LoginView(
                        initialRole: .trainee,
                        onBackToChoice: { step = .choice },
                        onGoToRegister: { step = .registerNewTrainee },
                        onLoginSuccess: {
                            didCompleteAuthScreen = true
                        }
                    )

                case .loginExistingCoach:
                    LoginView(
                        initialRole: .coach,
                        onBackToChoice: { step = .choice },
                        onGoToRegister: { step = .registerNewCoach },
                        onLoginSuccess: {
                            didCompleteAuthScreen = true
                        }
                    )

                case .registerNewTrainee:
                    RegisterView(
                        prefillPhone: "",
                        prefillEmail: "",
                        initialRole: .trainee,
                        onBack: { step = .choice },
                        onSubmit: { _ in
                            if auth.isSignedIn {
                                didCompleteAuthScreen = true
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
                        onBack: { step = .choice },
                        onSubmit: { _ in
                            if auth.isSignedIn {
                                didCompleteAuthScreen = true
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
                    EmptyView()
                }
            }
        }
    }
}

// MARK: - Intro gate

private struct IntroGateView: View {

    let onContinue: () -> Void

    var body: some View {
        ZStack {
            KmiGradientBackground(forceTraineeStyle: true)

            VStack(spacing: 16) {
                Spacer()

                Text("ק.מ.י.")
                    .font(.system(size: 48, weight: .heavy))
                    .foregroundStyle(.white)

                Text("קרב מגן ישראלי")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.92))

                Text("שלום יובל")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.95))

                Spacer()

                Button(action: onContinue) {
                    Text("מעבר למסך כניסה / רישום")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.18))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden()
    }
}
