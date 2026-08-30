import SwiftUI

struct KmiLoadingOverlay: View {
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("kmi_app_language")
    private var languageCode: String = "he"

    private var isEnglish: Bool {
        let clean = languageCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return clean == "en" || clean == "english"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(colorScheme == .dark ? 0.46 : 0.30)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                TimelineView(
                    .animation(minimumInterval: 1.0 / 60.0)
                ) { context in
                    let seconds =
                        context.date.timeIntervalSinceReferenceDate

                    ZStack {
                        loadingRing(
                            size: 76,
                            lineWidth: 5,
                            rotation: seconds
                                .truncatingRemainder(dividingBy: 1.35)
                                / 1.35 * 360,
                            colors: [
                                .clear,
                                Color(
                                    red: 167.0 / 255,
                                    green: 139.0 / 255,
                                    blue: 250.0 / 255
                                ),
                                Color(
                                    red: 56.0 / 255,
                                    green: 189.0 / 255,
                                    blue: 248.0 / 255
                                ),
                                .clear
                            ]
                        )

                        loadingRing(
                            size: 62,
                            lineWidth: 4,
                            rotation: -seconds
                                .truncatingRemainder(dividingBy: 1.65)
                                / 1.65 * 360,
                            colors: [
                                .clear,
                                Color(
                                    red: 56.0 / 255,
                                    green: 189.0 / 255,
                                    blue: 248.0 / 255
                                ),
                                Color(
                                    red: 167.0 / 255,
                                    green: 139.0 / 255,
                                    blue: 250.0 / 255
                                ),
                                .clear
                            ]
                        )

                        loadingRing(
                            size: 48,
                            lineWidth: 3.5,
                            rotation: seconds
                                .truncatingRemainder(dividingBy: 2.05)
                                / 2.05 * 360,
                            colors: [
                                .clear,
                                Color(
                                    red: 245.0 / 255,
                                    green: 158.0 / 255,
                                    blue: 11.0 / 255
                                ),
                                Color(
                                    red: 34.0 / 255,
                                    green: 197.0 / 255,
                                    blue: 94.0 / 255
                                ),
                                .clear
                            ]
                        )

                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        KmiAppTheme.surface(
                                            for: colorScheme
                                        ),
                                        KmiAppTheme.primaryContainer(
                                            for: colorScheme
                                        ),
                                        KmiAppTheme.surfaceVariant(
                                            for: colorScheme
                                        )
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 12.5
                                )
                            )
                            .overlay {
                                Circle()
                                    .strokeBorder(
                                        KmiAppTheme.primary(
                                            for: colorScheme
                                        )
                                        .opacity(0.32),
                                        lineWidth: 1
                                    )
                            }
                            .overlay {
                                Text("✓")
                                    .kmiFont(size: 12, weight: .black)
                                    .foregroundStyle(
                                        KmiAppTheme.primary(
                                            for: colorScheme
                                        )
                                    )
                            }
                            .frame(width: 25, height: 25)
                    }
                    .frame(width: 82, height: 82)
                }
                .frame(width: 82, height: 82)
                .accessibilityHidden(true)

                Text(isEnglish ? "Loading…" : "טוען…")
                    .kmiFont(size: 16, weight: .black)
                    .foregroundStyle(
                        KmiAppTheme.onBackground(for: colorScheme)
                    )
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(
                    cornerRadius: 26,
                    style: .continuous
                )
                .fill(KmiAppTheme.surface(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 26,
                    style: .continuous
                )
                .strokeBorder(
                    KmiAppTheme.outlineVariant(for: colorScheme),
                    lineWidth: 1
                )
            )
        }
        .transition(.opacity)
        .zIndex(10_000)
        .allowsHitTesting(true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isEnglish ? "Loading" : "טוען")
    }

    private func loadingRing(
        size: CGFloat,
        lineWidth: CGFloat,
        rotation: Double,
        colors: [Color]
    ) -> some View {
        Circle()
            .strokeBorder(
                AngularGradient(
                    colors: colors,
                    center: .center
                ),
                lineWidth: lineWidth
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
    }
}

#Preview {
    KmiLoadingOverlay()
}
