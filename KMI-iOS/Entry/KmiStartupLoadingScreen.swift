import SwiftUI
import AVKit

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

            GeometryReader { geo in
                let height = geo.size.height
                let isCompactHeight = height < 760
                let isVeryCompactHeight = height < 690

                let heroTopSpace = height * (isVeryCompactHeight ? 0.145 : (isCompactHeight ? 0.155 : 0.165))
                let cardTopSpace = height * 0.580

                let cardWidth = min(geo.size.width * 0.84, 368)

                ZStack(alignment: .top) {
                    heroCardView
                        .padding(.top, heroTopSpace)

                    loadingCardView
                        .frame(width: cardWidth)
                        .fixedSize(horizontal: false, vertical: true)
                        .position(
                            x: geo.size.width / 2,
                            y: cardTopSpace + 122
                        )
                        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
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
        Group {
            if let image = UIImage(named: "kmi_startup_loading_bg") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.white

                    Text("Missing asset:\nkmi_startup_loading_bg")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(red: 0.09, green: 0.13, blue: 0.20))
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
        }
        .ignoresSafeArea()
    }

    private var heroCardView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accentBlue.opacity(0.28),
                            accentBlue.opacity(0.10),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 238, height: 96)
                .scaleEffect(pulseScale)
                .opacity(glowOpacity)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.06, green: 0.10, blue: 0.15).opacity(0.96))
                .frame(width: 214, height: 88)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.30), radius: 16, x: 0, y: 10)

            KmiLoopingStartupVideoView()
                .frame(width: 214, height: 88)
                .scaleEffect(1.18)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .opacity(0.92)

            startupLogoBadge
                .frame(width: 76, height: 76)

            GeometryReader { geo in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                accentBlue.opacity(0.10),
                                accentPurple.opacity(0.16),
                                accentBlue.opacity(0.10),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 46)
                    .offset(x: geo.size.width * scanOffset)
            }
            .frame(width: 214, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 98)
    }
    
    @ViewBuilder
    private var startupLogoBadge: some View {
        if let image = UIImage(named: "app_icon.png") {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.24), lineWidth: 1)
                )
                .shadow(color: accentBlue.opacity(0.30), radius: 8, x: 0, y: 3)

        } else if let image = UIImage(named: "app_icon") {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.24), lineWidth: 1)
                )
                .shadow(color: accentBlue.opacity(0.30), radius: 8, x: 0, y: 3)

        } else {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color(red: 0.04, green: 0.10, blue: 0.16).opacity(0.94)
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 42
                    )
                )
                .overlay(
                    Text("KMI")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.24), lineWidth: 1)
                )
                .shadow(color: accentBlue.opacity(0.30), radius: 8, x: 0, y: 3)
        }
    }
    
    private var accentBlue: Color {
        Color(red: 0.09, green: 0.55, blue: 1.0)
    }

    private var accentPurple: Color {
        Color(red: 0.36, green: 0.21, blue: 0.96)
    }

    private var textPrimary: Color {
        Color(red: 0.09, green: 0.13, blue: 0.20)
    }

    private var textSecondary: Color {
        Color(red: 0.40, green: 0.44, blue: 0.52)
    }

    private var loadingCardView: some View {
        let currentStage = stages[currentStageIndex]

        return VStack(spacing: 0) {
            Group {
                if isEnglish {
                    HStack(spacing: 12) {
                        Image(systemName: currentStage.systemImage)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(accentColor)
                            .frame(width: 30, height: 30)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Current stage")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(textSecondary)

                            Text(currentStage.titleEn)
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundColor(textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.80)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundColor(Color(red: 0.07, green: 0.24, blue: 0.49))
                            .frame(width: 48, alignment: .center)
                            .offset(y: -10)
                    }
                } else {
                    HStack(spacing: 12) {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundColor(Color(red: 0.07, green: 0.24, blue: 0.49))
                            .frame(width: 48, alignment: .center)
                            .offset(y: -10)

                        VStack(alignment: .trailing, spacing: 3) {
                            Text("שלב נוכחי")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(textSecondary)

                            Text(currentStage.titleHe)
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundColor(textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.80)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)

                        Image(systemName: currentStage.systemImage)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(accentColor)
                            .frame(width: 30, height: 30)
                    }
                }
            }
            .environment(\.layoutDirection, .leftToRight)

            Spacer()
                .frame(height: 7)

            progressBar
                .offset(y: -4)

            Spacer()
                .frame(height: 5)

            checklistView

            Spacer()
                .frame(height: 2)

            HStack {
                Button {
                    onFinished()
                } label: {
                    Text(isEnglish ? "Skip" : "דלג")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(Color(red: 0.07, green: 0.24, blue: 0.49))
                }
                .buttonStyle(.plain)

                Spacer()

                Text(isEnglish ? "Please wait..." : "אנא המתן...")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(red: 0.07, green: 0.24, blue: 0.49))

                Spacer()
                    .frame(width: 52)
            }
            .frame(height: 34)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(red: 0.90, green: 0.91, blue: 0.93))

                Capsule()
                    .fill(Color(red: 0.06, green: 0.64, blue: 0.42))
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: 8)
    }

    private var checklistView: some View {
        VStack(spacing: 5) {
            ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                let done = index < completedStagesInCycle
                let active = index == currentStageIndex

                Group {
                    if isEnglish {
                        HStack(spacing: 8) {
                            Image(systemName: done ? "checkmark.circle.fill" : stage.systemImage)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(iconColor(done: done, active: active))
                                .scaleEffect(done ? 1.14 : 1.0)
                                .animation(.easeInOut(duration: 0.22), value: done)

                            Text(stage.titleEn)
                                .font(.system(size: 13.2, weight: active ? .bold : .semibold, design: .rounded))
                                .lineLimit(1)
                                .foregroundColor(active || done ? textPrimary : textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Text(stage.titleHe)
                                .font(.system(size: 13.2, weight: active ? .bold : .semibold, design: .rounded))
                                .lineLimit(1)
                                .foregroundColor(active || done ? textPrimary : textSecondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)

                            Image(systemName: done ? "checkmark.circle.fill" : stage.systemImage)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(iconColor(done: done, active: active))
                                .scaleEffect(done ? 1.14 : 1.0)
                                .animation(.easeInOut(duration: 0.22), value: done)
                        }
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
                .opacity(active || done ? 1.0 : 0.48)
                .animation(.easeInOut(duration: 0.28), value: currentStageIndex)
            }
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

        return textSecondary
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
        let totalDurationNanoseconds: UInt64 = 6_500_000_000
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

private struct KmiLoopingStartupVideoView: UIViewRepresentable {

    final class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.videoGravity = .resizeAspectFill

        guard let url = Bundle.main.url(forResource: "kmi_startup_animation", withExtension: "mp4") else {
            return view
        }

        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.isMuted = true

        context.coordinator.player = player
        context.coordinator.looper = AVPlayerLooper(player: player, templateItem: item)

        view.playerLayer.player = player
        player.play()

        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        context.coordinator.player?.play()
    }

    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: Coordinator) {
        coordinator.player?.pause()
        coordinator.player = nil
        coordinator.looper = nil
        uiView.playerLayer.player = nil
    }

    final class PlayerContainerView: UIView {
        override static var layerClass: AnyClass {
            AVPlayerLayer.self
        }

        var playerLayer: AVPlayerLayer {
            layer as! AVPlayerLayer
        }
    }
}

#Preview {
    KmiStartupLoadingScreen(isEnglish: false) {}
}
