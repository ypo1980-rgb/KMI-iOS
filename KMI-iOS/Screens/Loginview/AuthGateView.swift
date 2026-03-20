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
        case loginExisting
        case registerNew
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

                IntroView(
                    onContinue: {
                        didEnterAuthFlow = true
                        didCompleteAuthScreen = false
                        step = .loginExisting
                    }
                )

            } else if !didCompleteAuthScreen {

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
                                    onNewUser: { step = .registerNew },
                                    onExistingUser: { step = .loginExisting }
                                )
                            }

                        case .loginExisting:
                            KmiRootLayout(
                                title: "התחברות",
                                nav: nav,
                                selectedIcon: nil
                            ) {
                                LoginView(
                                    onBackToChoice: { step = .choice },
                                    onGoToRegister: { step = .registerNew },
                                    onLoginSuccess: {
                                        didCompleteAuthScreen = true
                                    }
                                )
                            }

                        case .registerNew:
                            KmiRootLayout(
                                title: "הרשמה",
                                nav: nav,
                                selectedIcon: nil
                            ) {
                                RegisterView(
                                    prefillPhone: "",
                                    prefillEmail: "",
                                    onBack: { step = .choice },
                                    onSubmit: { _ in
                                        if auth.isSignedIn {
                                            didCompleteAuthScreen = true
                                        } else {
                                            step = .loginExisting
                                        }
                                    },
                                    onReadMoreTerms: { }
                                )
                            }
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

            } else if auth.isSignedIn {

                ContentView()
                    .onAppear {
                        #if DEBUG
                        print("✅ AuthGateView: auth.isSignedIn == true && didCompleteAuthScreen == true -> showing ContentView")
                        #endif
                    }

            } else {

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
                                    onNewUser: { step = .registerNew },
                                    onExistingUser: { step = .loginExisting }
                                )
                            }

                        case .loginExisting:
                            KmiRootLayout(
                                title: "התחברות",
                                nav: nav,
                                selectedIcon: nil
                            ) {
                                LoginView(
                                    onBackToChoice: { step = .choice },
                                    onGoToRegister: { step = .registerNew },
                                    onLoginSuccess: {
                                        didCompleteAuthScreen = true
                                    }
                                )
                            }

                        case .registerNew:
                            KmiRootLayout(
                                title: "הרשמה",
                                nav: nav,
                                selectedIcon: nil
                            ) {
                                RegisterView(
                                    prefillPhone: "",
                                    prefillEmail: "",
                                    onBack: { step = .choice },
                                    onSubmit: { _ in
                                        if auth.isSignedIn {
                                            didCompleteAuthScreen = true
                                        } else {
                                            step = .loginExisting
                                        }
                                    },
                                    onReadMoreTerms: { }
                                )
                            }
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
        .environmentObject(auth)
        .onAppear {
            guard !didBootstrap else { return }
            didBootstrap = true

            didEnterAuthFlow = false
            didCompleteAuthScreen = false
            step = .loginExisting
            nav.popToRoot()
            auth.start()

            DispatchQueue.main.async {
                didFinishInitialAuthCheck = true
            }
        }
        .onChange(of: auth.isSignedIn) { isSignedIn in
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
}

// MARK: - Intro gate

private struct IntroGateView: View {

    let onContinue: () -> Void

    var body: some View {
        ZStack {
            KmiGradientBackground()

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
