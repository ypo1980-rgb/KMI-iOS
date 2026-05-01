import SwiftUI

private struct KmiLoadingStage: Identifiable {
    let id = UUID()
    let titleHe: String
    let titleEn: String
    let systemImage: String
}

struct KmiStartupLoadingScreen: View {

    let isEnglish: Bool
    let onFinished: () -> Void

    @State private var currentStageIndex: Int = 0
    @State private var completedStagesInCycle: Int = 0
    @State private var progress: CGFloat = 0.0

    @State private var pulseScale: CGFloat = 0.96
    @State private var glowOpacity: Double = 0.18
    @State private var scanOffset: CGFloat = -1.2

    private let stages: [KmiLoadingStage] = [
        KmiLoadingStage(
            titleHe: "טעינת נתוני משתמש",
            titleEn: "Loading user data",
            systemImage: "person.fill"
        ),
        KmiLoadingStage(
            titleHe: "טעינת נתוני מערכת",
            titleEn: "Loading system data",
            systemImage: "gearshape.fill"
        ),
        KmiLoadingStage(
            titleHe: "בדיקת הרשאות ואבטחה",
            titleEn: "Checking permissions and security",
            systemImage: "shield.fill"
        ),
        KmiLoadingStage(
            titleHe: "סנכרון נתוני אימון",
            titleEn: "Syncing training data",
            systemImage: "arrow.triangle.2.circlepath"
        ),
        KmiLoadingStage(
            titleHe: "הכנת סביבת האימון",
            titleEn: "Preparing training environment",
            systemImage: "checkmark.seal.fill"
        )
    ]

    init(
        isEnglish: Bool,
        onFinished: @escaping () -> Void
    ) {
        self.isEnglish = isEnglish
        self.onFinished = onFinished
    }

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 42)

                heroCardView

                Spacer()
                    .frame(height: 18)

                titleView

                Spacer()
                    .frame(height: 28)

                loadingCardView
                    .padding(.horizontal, 24)

                Spacer()
                    .frame(height: 18)

                Text(isEnglish ? "Please wait a few seconds..." : "אנא המתן מספר שניות...")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.66))
                    .multilineTextAlignment(.center)

                Spacer(minLength: 30)
            }

            skipButton
        }
        .ignoresSafeArea()
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
        .onAppear {
            startVisualAnimations()
        }
        .task {
            await runLoadingSequence()
        }
    }

    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.06, blue: 0.10),
                    Color(red: 0.05, green: 0.10, blue: 0.15),
                    Color(red: 0.06, green: 0.12, blue: 0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(Color(red: 0.08, green: 0.77, blue: 0.50).opacity(0.18))
                .frame(width: 430, height: 430)
                .blur(radius: 110)
                .offset(y: -210)

            Circle()
                .fill(Color(red: 0.08, green: 0.77, blue: 0.50).opacity(0.10))
                .frame(width: 320, height: 320)
                .blur(radius: 92)
                .offset(x: 180, y: 260)

            Circle()
                .fill(Color(red: 0.18, green: 0.45, blue: 0.95).opacity(0.10))
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(x: -170, y: 310)
        }
    }

    private var heroCardView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.34),
                            accentColor.opacity(0.12),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 392, height: 248)
                .scaleEffect(pulseScale)
                .opacity(glowOpacity)

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color(red: 0.06, green: 0.10, blue: 0.15).opacity(0.94))
                .frame(width: 320, height: 185)
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.38), radius: 18, x: 0, y: 12)

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.18))
                        .frame(width: 86, height: 86)
                        .blur(radius: 3)

                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 76, height: 76)
                        .overlay(
                            Circle()
                                .stroke(accentColor.opacity(0.40), lineWidth: 1)
                        )

                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(accentColor)
                }

                VStack(spacing: 4) {
                    Text("K.M.I")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text(isEnglish ? "Krav Magen Israeli" : "קרב מגן ישראלי")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.70))
                }
            }

            GeometryReader { geo in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                accentColor.opacity(0.10),
                                Color(red: 0.19, green: 0.84, blue: 0.63).opacity(0.14),
                                accentColor.opacity(0.10),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 56)
                    .offset(x: geo.size.width * scanOffset)
            }
            .frame(width: 320, height: 185)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    private var titleView: some View {
        VStack(spacing: 10) {
            Text(isEnglish ? "Krav Magen Israeli" : "קרב מגן ישראלי")
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text(isEnglish ? "Initializing premium training environment" : "מאתחל סביבת אימון מתקדמת")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundColor(Color.white.opacity(0.70))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
    }

    private var loadingCardView: some View {
        let currentStage = stages[currentStageIndex]

        return VStack(spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: currentStage.systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(accentColor)
                    .frame(width: 28, height: 28)

                VStack(
                    alignment: isEnglish ? .leading : .trailing,
                    spacing: 3
                ) {
                    Text(isEnglish ? "Current stage" : "שלב נוכחי")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.62))

                    Text(isEnglish ? currentStage.titleEn : currentStage.titleHe)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 0.19, green: 0.84, blue: 0.63))
            }

            progressBar

            checklistView
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.07, green: 0.13, blue: 0.19).opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.30), radius: 16, x: 0, y: 10)
        )
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: isEnglish ? .leading : .trailing) {
                Capsule()
                    .fill(Color.white.opacity(0.10))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor,
                                Color(red: 0.19, green: 0.84, blue: 0.63)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: 10)
    }

    private var checklistView: some View {
        VStack(spacing: 10) {
            ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                let done = index < completedStagesInCycle
                let active = index == currentStageIndex

                HStack(spacing: 10) {
                    Image(systemName: done ? "checkmark.circle.fill" : stage.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(iconColor(done: done, active: active))
                        .scaleEffect(done ? 1.12 : 1.0)
                        .animation(.easeInOut(duration: 0.22), value: done)

                    Text(isEnglish ? stage.titleEn : stage.titleHe)
                        .font(.system(size: 15, weight: active ? .bold : .medium, design: .rounded))
                        .foregroundColor(active || done ? .white : Color.white.opacity(0.58))
                        .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
                }
                .opacity(active || done ? 1.0 : 0.55)
                .animation(.easeInOut(duration: 0.28), value: currentStageIndex)
            }
        }
    }

    private var skipButton: some View {
        VStack {
            Spacer()

            HStack {
                if isEnglish {
                    Spacer()
                }

                Button {
                    onFinished()
                } label: {
                    Text(isEnglish ? "Skip" : "דלג")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.20))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                )
                        )
                }

                if !isEnglish {
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 48)
        }
    }

    private var accentColor: Color {
        Color(red: 0.08, green: 0.77, blue: 0.50)
    }

    private func iconColor(done: Bool, active: Bool) -> Color {
        if done {
            return accentColor
        }

        if active {
            return Color(red: 1.0, green: 0.82, blue: 0.40)
        }

        return Color.white.opacity(0.58)
    }

    private func startVisualAnimations() {
        withAnimation(
            .easeInOut(duration: 1.4)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.06
        }

        withAnimation(
            .easeInOut(duration: 1.6)
            .repeatForever(autoreverses: true)
        ) {
            glowOpacity = 0.42
        }

        withAnimation(
            .linear(duration: 2.0)
            .repeatForever(autoreverses: false)
        ) {
            scanOffset = 1.2
        }
    }

    private func runLoadingSequence() async {
        let totalDurationNanoseconds: UInt64 = 10_000_000_000
        let tickNanoseconds: UInt64 = 100_000_000
        let totalSteps = Int(totalDurationNanoseconds / tickNanoseconds)

        for step in 0..<totalSteps {
            if Task.isCancelled {
                return
            }

            try? await Task.sleep(nanoseconds: tickNanoseconds)

            let nextProgress = CGFloat(step + 1) / CGFloat(totalSteps)
            let stageProgress = nextProgress * CGFloat(stages.count)
            let safeIndex = min(Int(stageProgress), stages.count - 1)

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) {
                    progress = nextProgress
                    currentStageIndex = safeIndex
                    completedStagesInCycle = safeIndex
                }
            }
        }

        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.20)) {
                currentStageIndex = stages.count - 1
                completedStagesInCycle = stages.count
                progress = 1.0
            }

            onFinished()
        }
    }
}

#Preview {
    KmiStartupLoadingScreen(isEnglish: false) {}
}
