import SwiftUI
import UIKit
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
    @Environment(\.colorScheme)
    private var colorScheme
    @State private var currentStageIndex: Int = 0
    @State private var completedStagesInCycle: Int = 0
    @State private var progress: CGFloat = 0.0
    @State private var finishAlreadySent: Bool = false
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
            GeometryReader { backgroundGeometry in
                backgroundView
                    .frame(
                        width: backgroundGeometry.size.width,
                        height: backgroundGeometry.size.height
                    )
                    .clipped()
            }

            GeometryReader { geo in
                let height = geo.size.height
                let isCompactHeight = height < 760
                let isVeryCompactHeight = height < 690
                let heroTopSpace = height * (isVeryCompactHeight ? 0.145 : (isCompactHeight ? 0.155 : 0.165))
                let cardTopSpace = height * 0.55
                let cardWidth = min(
                    max(geo.size.width - 40, 0),
                    440
                )

                ScrollView(showsIndicators: false) {
                    ZStack(alignment: .top) {
                        heroCardView
                            .padding(.top, heroTopSpace)

                        loadingCardView
                            .frame(width: cardWidth)
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )
                            .padding(.top, cardTopSpace)
                            .padding(
                                .bottom,
                                max(geo.safeAreaInsets.bottom, 16)
                            )
                            .environment(
                                \.layoutDirection,
                                isEnglish ? .leftToRight : .rightToLeft
                            )
                    }
                    .frame(
                        width: geo.size.width,
                        alignment: .center
                    )
                    .frame(
                        minHeight: height,
                        alignment: .top
                    )
                }
                .environment(\.layoutDirection, .leftToRight)
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
    private func finishOnce() {
        guard !finishAlreadySent else { return }
        finishAlreadySent = true
        onFinished()
    }
    private var backgroundAssetName: String {
        colorScheme == .dark
            ? "kmi_startup_loading_bg_dark"
            : "kmi_startup_loading_bg"
    }
    private var backgroundView: some View {
        Group {
            if let image = UIImage(
                named: backgroundAssetName
            ) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                KmiAppBackground()
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
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .fill(
                videoBackgroundColor.opacity(0.96)
            )
            .frame(width: 214, height: 88)
            .overlay(
                RoundedRectangle(
                    cornerRadius: 24,
                    style: .continuous
                )
                .stroke(
                    KmiAppTheme.outlineVariant(for: colorScheme),
                    lineWidth: 1
                )
            )
            .shadow(
                color: loadingCardShadowColor,
                radius: 16,
                x: 0,
                y: 10
            )
            KmiLoopingStartupVideoView()
                .frame(width: 214, height: 88)
                .scaleEffect(1.26)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
                        .stroke(
                            KmiAppTheme.outlineVariant(for: colorScheme),
                            lineWidth: 1
                        )
                )
                .shadow(color: accentBlue.opacity(0.30), radius: 8, x: 0, y: 3)
        } else if let image = UIImage(named: "app_icon") {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            KmiAppTheme.outlineVariant(for: colorScheme),
                            lineWidth: 1
                        )
                )
                .shadow(color: accentBlue.opacity(0.30), radius: 8, x: 0, y: 3)
        } else {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            KmiAppTheme.secondaryContainer(for: colorScheme),
                            KmiAppTheme.tertiaryContainer(for: colorScheme)
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 42
                    )
                )
                .overlay(
                    Text("KMI")
                        .kmiTypography(.cardTitle)
                        .foregroundStyle(
                            KmiAppTheme.onTertiaryContainer(for: colorScheme)
                        )
                )
                .overlay(
                    Circle()
                        .stroke(
                            KmiAppTheme.outlineVariant(for: colorScheme),
                            lineWidth: 1
                        )
                )
                .shadow(color: accentBlue.opacity(0.30), radius: 8, x: 0, y: 3)
        }
    }
    private var accentBlue: Color {
        KmiAppTheme.secondary(for: colorScheme)
    }

    private var accentPurple: Color {
        KmiAppTheme.primary(for: colorScheme)
    }

    private var textPrimary: Color {
        KmiAppTheme.onSurface(for: colorScheme)
    }

    private var textSecondary: Color {
        KmiAppTheme.onSurfaceVariant(for: colorScheme)
    }

    private var progressTextColor: Color {
        KmiAppTheme.primary(for: colorScheme)
    }

    private var loadingCardBackground: Color {
        KmiAppTheme.surface(for: colorScheme)
    }

    private var loadingCardShadowColor: Color {
        KmiAppTheme.background(for: .dark)
            .opacity(colorScheme == .dark ? 0.40 : 0.14)
    }

    private var videoBackgroundColor: Color {
        KmiAppTheme.tertiaryContainer(for: colorScheme)
    }
    private var loadingCardView: some View {
        let currentStage =
            stages[currentStageIndex]
        return VStack(spacing: 0) {
            Group {
                if isEnglish {
                    HStack(spacing: 12) {
                        Image(
                            systemName:
                                currentStage.systemImage
                        )
                        .resizable()
                        .scaledToFit()
                        .kmiIconSize(.large)
                        .foregroundColor(accentColor)
                        .frame(minWidth: 30, minHeight: 30)
                        VStack(
                            alignment: .leading,
                            spacing: 3
                        ) {
                            Text("Current stage")
                                .kmiTypography(.secondary)
                                .foregroundColor(
                                    textSecondary
                                )
                            Text(currentStage.titleEn)
                                .kmiTypography(.sectionTitle)
                                .fontWeight(.black)
                                .foregroundColor(textPrimary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(
                                    horizontal: false,
                                    vertical: true
                                )
                        }
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                        Text(
                            "\(Int(progress * 100))%"
                        )
                        .kmiTypography(.metric)
                        .fontWeight(.black)
                        .foregroundColor(
                            progressTextColor
                        )
                        .frame(
                            minWidth: 48,
                            alignment: .center
                        )
                        .offset(y: -10)
                    }
                } else {
                    HStack(spacing: 12) {
                        Text(
                            "\(Int(progress * 100))%"
                        )
                        .kmiTypography(.cardTitle)
                        .foregroundColor(
                            progressTextColor
                        )
                        .frame(
                            minWidth: 48,
                            alignment: .center
                        )
                        .offset(y: -10)
                        VStack(
                            alignment: .trailing,
                            spacing: 3
                        ) {
                            Text("שלב נוכחי")
                                .kmiTypography(.secondary)
                                .foregroundColor(
                                    textSecondary
                                )
                            Text(currentStage.titleHe)
                                .kmiTypography(.sectionTitle)
                                .fontWeight(.black)
                                .foregroundColor(textPrimary)
                                .multilineTextAlignment(.trailing)
                                .fixedSize(
                                    horizontal: false,
                                    vertical: true
                                )
                        }
                        .frame(
                            maxWidth: .infinity,
                            alignment: .trailing
                        )
                        Image(
                            systemName:
                                currentStage.systemImage
                        )
                        .resizable()
                        .scaledToFit()
                        .kmiIconSize(.large)
                        .foregroundColor(accentColor)
                        .frame(minWidth: 30, minHeight: 30)
                    }
                }
            }
            .environment(
                \.layoutDirection,
                .leftToRight
            )
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
                    finishOnce()
                } label: {
                    Text(isEnglish ? "Skip" : "דלג")
                        .kmiFont(size: 19, weight: .bold)
                        .foregroundColor(progressTextColor)
                        .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(isEnglish ? "Please wait..." : "אנא המתן...")
                    .kmiFont(size: 19, weight: .bold)
                    .foregroundColor(progressTextColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
                    .frame(width: 52)
            }
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .fill(loadingCardBackground)
            .shadow(
                color: loadingCardShadowColor,
                radius: 8,
                x: 0,
                y: 5
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
    }
    
    private var progressBar: some View {
        ProgressView(value: Double(progress), total: 1)
            .progressViewStyle(.linear)
            .tint(KmiAppTheme.primary(for: colorScheme))
            .accessibilityLabel(
                Text(isEnglish ? "Loading progress" : "התקדמות הטעינה")
            )
    }
    
    private var checklistView: some View {
        VStack(spacing: 10) {
            ForEach(
                Array(stages.enumerated()),
                id: \.element.id
            ) { index, stage in
                let done =
                    index < completedStagesInCycle
                let active =
                    index == currentStageIndex
                Group {
                    if isEnglish {
                        HStack(spacing: 8) {
                            Image(
                                systemName:
                                    done
                                    ? "checkmark.circle.fill"
                                    : stage.systemImage
                            )
                            .resizable()
                            .scaledToFit()
                            .kmiIconSize(.small)
                            .foregroundColor(
                                iconColor(
                                    done: done,
                                    active: active
                                )
                            )
                            .scaleEffect(
                                done ? 1.14 : 1.0
                            )
                            .animation(
                                .easeInOut(
                                    duration: 0.22
                                ),
                                value: done
                            )
                            Text(stage.titleEn)
                                .kmiFont(size: 17, weight: active ? .bold : .semibold)
                                .multilineTextAlignment(.leading)
                                .fixedSize(
                                    horizontal: false,
                                    vertical: true
                                )
                                .foregroundColor(
                                    active || done
                                        ? textPrimary
                                        : textSecondary
                                )
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
                        }
                    } else {
                        HStack(spacing: 8) {
                            Text(stage.titleHe)
                                .kmiFont(size: 17, weight: active ? .bold : .semibold)
                                .multilineTextAlignment(.trailing)
                                .fixedSize(
                                    horizontal: false,
                                    vertical: true
                                )
                                .foregroundColor(
                                    active || done
                                        ? textPrimary
                                        : textSecondary
                                )
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .trailing
                                )
                            Image(
                                systemName:
                                    done
                                    ? "checkmark.circle.fill"
                                    : stage.systemImage
                            )
                            .resizable()
                            .scaledToFit()
                            .kmiIconSize(.small)
                            .foregroundColor(
                                iconColor(
                                    done: done,
                                    active: active
                                )
                            )
                            .scaleEffect(
                                done ? 1.14 : 1.0
                            )
                            .animation(
                                .easeInOut(
                                    duration: 0.22
                                ),
                                value: done
                            )
                        }
                    }
                }
                .environment(
                    \.layoutDirection,
                    .leftToRight
                )
                .opacity(
                    active || done
                        ? 1.0
                        : 0.48
                )
                .animation(
                    .easeInOut(
                        duration: 0.28
                    ),
                    value: currentStageIndex
                )
            }
        }
    }
    
    private var accentColor: Color {
        KmiAppTheme.success(for: colorScheme)
    }

    private func iconColor(done: Bool, active: Bool) -> Color {
        if done {
            return accentColor
        }

        if active {
            return KmiAppTheme.warning(for: colorScheme)
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
            do {
                try await Task.sleep(nanoseconds: tickNanoseconds)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }

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
            finishOnce()
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
