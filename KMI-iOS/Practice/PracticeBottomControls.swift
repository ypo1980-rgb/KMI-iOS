import SwiftUI

// MARK: - Bottom Action Card

struct PracticeBottomControls: View {
@Environment(\.colorScheme) private var colorScheme

let isEnglish: Bool
let canShowHelp: Bool
let canSkip: Bool
let onHelp: () -> Void
let onSkip: () -> Void
let onFinish: () -> Void

private func tr(_ he: String, _ en: String) -> String {
    isEnglish ? en : he
}

    var body: some View {
        HStack(spacing: 6) {
            pillButton(
                title: tr("עזרה", "Help"),
                icon: "info.circle",
                fill: KmiAppTheme.secondaryContainer(for: colorScheme),
                foreground: KmiAppTheme.onSecondaryContainer(for: colorScheme),
                action: onHelp
            )
            .disabled(!canShowHelp)
            .opacity(canShowHelp ? 1 : 0.45)

            if canSkip {
                pillButton(
                    title: tr("דלג", "Skip"),
                    icon: "play.fill",
                    fill: KmiAppTheme.primary(for: colorScheme),
                    foreground: KmiAppTheme.onPrimary(for: colorScheme),
                    action: onSkip
                )
            }

            pillButton(
                title: tr("סיום", "Finish"),
                icon: "rectangle.portrait.and.arrow.right",
                fill: KmiAppTheme.primaryContainer(for: colorScheme),
                foreground: KmiAppTheme.onPrimaryContainer(for: colorScheme),
                action: onFinish
            )
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(KmiAppTheme.surface(for: colorScheme))
        .overlay {
            Rectangle()
                .strokeBorder(
                    KmiAppTheme.outlineVariant(for: colorScheme),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
    }

    private func pillButton(
        title: String,
        icon: String,
        fill: Color,
        foreground: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .kmiTypography(.caption)
                    .fontWeight(.heavy)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Image(systemName: icon)
                    .kmiIconSize(20)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(
                fill,
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(foreground.opacity(0.20), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(.plain)
    }
}
