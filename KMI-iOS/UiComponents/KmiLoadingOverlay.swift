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

            VStack(spacing: 15) {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                    let seconds = context.date.timeIntervalSinceReferenceDate

                    ZStack {
                        loadingRing(
                            size: 94,
                            lineWidth: 7,
                            trimEnd: 0.72,
                            rotation: seconds * 118,
                            colors: [
                                Color(red: 0.13, green: 0.83, blue: 0.93),
                                Color(red: 0.20, green: 0.47, blue: 0.95),
                                Color(red: 0.55, green: 0.29, blue: 0.96)
                            ]
                        )

                        loadingRing(
                            size: 69,
                            lineWidth: 6,
                            trimEnd: 0.64,
                            rotation: -(seconds * 154),
                            colors: [
                                Color(red: 1.00, green: 0.75, blue: 0.20),
                                Color(red: 1.00, green: 0.40, blue: 0.28),
                                Color(red: 0.93, green: 0.25, blue: 0.60)
                            ]
                        )

                        loadingRing(
                            size: 44,
                            lineWidth: 5,
                            trimEnd: 0.58,
                            rotation: seconds * 205,
                            colors: [
                                Color(red: 0.35, green: 0.86, blue: 0.48),
                                Color(red: 0.10, green: 0.74, blue: 0.73),
                                Color(red: 0.13, green: 0.58, blue: 0.95)
                            ]
                        )
                    }
                    .frame(width: 108, height: 108)
                }
                .frame(width: 108, height: 108)

                Text(isEnglish ? "Loading…" : "טוען…")
                    .kmiFont(size: 16, weight: .black)
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.white.opacity(0.94)
                            : Color(red: 0.08, green: 0.12, blue: 0.20)
                    )
                    .lineLimit(1)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        colorScheme == .dark
                            ? Color(red: 0.06, green: 0.09, blue: 0.15).opacity(0.97)
                            : Color.white.opacity(0.97)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.72), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.28), radius: 20, x: 0, y: 10)
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
        trimEnd: CGFloat,
        rotation: Double,
        colors: [Color]
    ) -> some View {
        Circle()
            .trim(from: 0.04, to: trimEnd)
            .stroke(
                AngularGradient(
                    colors: colors + [colors.first ?? .clear],
                    center: .center
                ),
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round
                )
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation.truncatingRemainder(dividingBy: 360)))
    }
}

#Preview {
    KmiLoadingOverlay()
}
