import SwiftUI

enum KmiAppTheme {
    static func screenBackgroundColors(
        for colorScheme: ColorScheme
    ) -> [Color] {
        switch colorScheme {
        case .dark:
            return [
                background(for: colorScheme),
                surfaceVariant(for: colorScheme),
                primaryContainer(for: colorScheme),
                background(for: colorScheme)
            ]

        default:
            return [
                background(for: colorScheme),
                surfaceVariant(for: colorScheme),
                secondaryContainer(for: colorScheme),
                secondary(for: colorScheme),
                tertiaryContainer(for: colorScheme)
            ]
        }
    }

    static var sectionHeaderBrush: LinearGradient {
        LinearGradient(
            colors: [
                rgb(0x062B4A),
                rgb(0x0F5E9C),
                rgb(0x062B4A)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var sectionHeaderContentColor: Color {
        .white
    }

    static var graniteActionBrush: LinearGradient {
        LinearGradient(
            colors: [
                rgb(0x7F00FF),
                rgb(0x3F51B5),
                rgb(0x03A9F4)
            ],
            startPoint: UnitPoint(x: 0, y: 0),
            endPoint: UnitPoint(x: 1, y: 1)
        )
    }

    static var graniteActionHighlightColor: Color {
        Color.white.opacity(0.45)
    }

    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? rgb(0x06111C) : rgb(0xF8FBFF)
    }

    static func onBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? rgb(0xF1F5F9) : rgb(0x172033)
    }

    static func surface(for scheme: ColorScheme) -> Color {
        scheme == .dark ? rgb(0x101B27) : .white
    }

    static func onSurface(for scheme: ColorScheme) -> Color {
        scheme == .dark ? rgb(0xF1F5F9) : rgb(0x172033)
    }

    static func surfaceVariant(for scheme: ColorScheme) -> Color {
        scheme == .dark ? rgb(0x192A38) : rgb(0xEAF4FF)
    }

    static func onSurfaceVariant(for scheme: ColorScheme) -> Color {
        scheme == .dark ? rgb(0xBCC9D4) : rgb(0x475467)
    }

    static func outline(for scheme: ColorScheme) -> Color {
        scheme == .dark ? rgb(0x718392) : rgb(0x7A8995)
    }

    static func outlineVariant(for scheme: ColorScheme) -> Color {
        scheme == .dark ? rgb(0x344957) : rgb(0xD5DEE5)
    }

    static func primary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? rgb(0xB69CFF) : rgb(0x6750A4)
    }

    static func onPrimary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? rgb(0x241052) : .white
    }

    static func primaryContainer(for scheme: ColorScheme) -> Color {
        scheme == .dark ? rgb(0x4F378B) : rgb(0xE8DEFF)
    }

    static func onPrimaryContainer(for scheme: ColorScheme) -> Color {
        scheme == .dark ? rgb(0xEADDFF) : rgb(0x241052)
    }

    static func secondary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? rgb(0x67D9F3) : rgb(0x1F78B4)
    }

    static func onSecondary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? rgb(0x002F3A) : .white
    }

    static func secondaryContainer(for scheme: ColorScheme) -> Color {
        scheme == .dark ? rgb(0x0A3657) : rgb(0xB7DDF7)
    }

    static func onSecondaryContainer(for scheme: ColorScheme) -> Color {
        scheme == .dark ? rgb(0xD5F2FF) : rgb(0x062B4A)
    }

    static func tertiary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? rgb(0x7DD3FC) : rgb(0x087E9B)
    }

    static func onTertiary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? rgb(0x003548) : .white
    }

    static func tertiaryContainer(for scheme: ColorScheme) -> Color {
        scheme == .dark ? rgb(0x041E33) : rgb(0x062B4A)
    }

    static func onTertiaryContainer(for scheme: ColorScheme) -> Color {
        scheme == .dark ? rgb(0xD5F2FF) : .white
    }

    static func error(for scheme: ColorScheme) -> Color {
        scheme == .dark ? rgb(0xFFB4AB) : rgb(0xBA1A1A)
    }

    static func onError(for scheme: ColorScheme) -> Color {
        scheme == .dark ? rgb(0x690005) : .white
    }

    private static func rgb(_ value: UInt32) -> Color {
        Color(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}

struct BeltTopicsGradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: KmiAppTheme.screenBackgroundColors(
                for: colorScheme
            ),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
