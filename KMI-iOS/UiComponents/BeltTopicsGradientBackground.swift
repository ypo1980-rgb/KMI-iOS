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

    struct DrawerSheetColors {
        let background: Color
        let content: Color

        var secondaryContent: Color { content.opacity(0.82) }
        var cardBackground: Color { content.opacity(0.10) }
        var cardBorder: Color { content.opacity(0.18) }
    }

    static func drawerSheetColors(
        for scheme: ColorScheme
    ) -> DrawerSheetColors {
        DrawerSheetColors(
            background: tertiaryContainer(for: scheme),
            content: onTertiaryContainer(for: scheme)
        )
    }

    static func drawerBackgroundBrush(
        for scheme: ColorScheme
    ) -> LinearGradient {
        let colors: [UInt32] = scheme == .dark
            ? [0x071A2A, 0x163B55, 0x344F63, 0x102F47, 0x061521]
            : [0xF1F4F7, 0xB8C4CF, 0xDDE3E9, 0x9EAFBD, 0xE9EEF2]

        return LinearGradient(
            colors: colors.map { rgb($0) },
            startPoint: UnitPoint(x: 0, y: 0),
            endPoint: UnitPoint(x: 1, y: 1)
        )
    }

    enum DrawerRole {
        case trainee
        case coach
        case manager
    }

    struct DrawerRoleColors {
        let background: LinearGradient
        let content: Color
        let border: Color
    }

    static func drawerRoleColors(
        for role: DrawerRole
    ) -> DrawerRoleColors {
        let palette: (background: [UInt32], content: UInt32, border: UInt32)

        switch role {
        case .trainee:
            palette = ([0xDCEEFF, 0x9AC7EF, 0x5A9FD6], 0x0B2942, 0x347FB8)

        case .coach:
            palette = ([0xE8DDF7, 0xC6B4E1, 0xA58FC8], 0x302044, 0x7D61A5)

        case .manager:
            palette = ([0xD9F3E4, 0x8FD3AC, 0x48A877], 0x123B27, 0x27845A)
        }

        return DrawerRoleColors(
            background: LinearGradient(
                colors: palette.background.map { rgb($0) },
                startPoint: .top,
                endPoint: .bottom
            ),
            content: rgb(palette.content),
            border: rgb(palette.border)
        )
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

    static func success(for scheme: ColorScheme) -> Color {

        scheme == .dark
            ? rgb(0x6EE7B7)
            : rgb(0x047857)
    }

    static func onSuccess(for scheme: ColorScheme) -> Color {

        scheme == .dark
            ? rgb(0x022C22)
            : .white
    }

    static func successContainer(for scheme: ColorScheme) -> Color {

        scheme == .dark
            ? rgb(0x064E3B)
            : rgb(0xECFDF5)
    }

    static func onSuccessContainer(for scheme: ColorScheme) -> Color {

        scheme == .dark
            ? rgb(0xA7F3D0)
            : rgb(0x065F46)
    }

    static func warning(for scheme: ColorScheme) -> Color {

        scheme == .dark
            ? rgb(0xFDBA74)
            : rgb(0xC2410C)
    }

    static func onWarning(for scheme: ColorScheme) -> Color {

        scheme == .dark
            ? rgb(0x422006)
            : .white
    }

    static func warningContainer(for scheme: ColorScheme) -> Color {

        scheme == .dark
            ? rgb(0x431407)
            : rgb(0xFFEDD5)
    }

    static func onWarningContainer(for scheme: ColorScheme) -> Color {

        scheme == .dark
            ? rgb(0xFFEDD5)
            : rgb(0x7C2D12)
    }

    static func error(for scheme: ColorScheme) -> Color {

        scheme == .dark
            ? rgb(0xFFB4AB)
            : rgb(0xBA1A1A)
    }

    static func onError(for scheme: ColorScheme) -> Color {

        scheme == .dark
            ? rgb(0x690005)
            : .white
    }

    static func errorContainer(for scheme: ColorScheme) -> Color {

        scheme == .dark
            ? rgb(0x93000A)
            : rgb(0xFFDAD6)
    }

    static func onErrorContainer(for scheme: ColorScheme) -> Color {

        scheme == .dark
            ? rgb(0xFFDAD6)
            : rgb(0x410002)
    }

    // צבעי קטגוריות התרגילים.
    enum ExerciseTopicAccent {
        case defenses
        case releases
        case hands
        case breakfalls
        case readyStance
        case groundPreparation
        case kavaler
        case kicks
        case hugReleases
    }

    static func exerciseTopicAccent(
        _ topic: ExerciseTopicAccent
    ) -> Color {
        switch topic {
        case .defenses:
            return rgb(0x7C5CFF)
        case .releases:
            return rgb(0x19A7E0)
        case .hands:
            return rgb(0x16B39A)
        case .breakfalls:
            return rgb(0xB88746)
        case .readyStance:
            return rgb(0x59B96F)
        case .groundPreparation:
            return rgb(0xD05AA0)
        case .kavaler:
            return rgb(0xF09A2A)
        case .kicks:
            return rgb(0x3B82F6)
        case .hugReleases:
            return rgb(0x5B6CFF)
        }
    }

    // צבעי תתי־נושאים, לפי המיפוי הקיים.
    enum ExerciseSubtopicAccent {
        case internalDefense
        case externalDefense
        case knife
        case gun
        case stick
        case releases
        case kicks
        case hands
        case breakfalls
        case fallback
    }

    static func exerciseSubtopicAccent(
        _ topic: ExerciseSubtopicAccent,
        scheme: ColorScheme
    ) -> Color {
        switch topic {
        case .internalDefense:
            return Color.green.opacity(0.82)
        case .externalDefense:
            return Color.blue.opacity(0.82)
        case .knife:
            return Color.orange.opacity(0.88)
        case .gun:
            return Color.red.opacity(0.82)
        case .stick:
            return Color.brown.opacity(0.82)
        case .releases:
            return Color.blue.opacity(0.72)
        case .kicks:
            return Color.orange.opacity(0.85)
        case .hands:
            return Color.red.opacity(0.78)
        case .breakfalls:
            return Color.purple.opacity(0.78)
        case .fallback:
            return onSurface(for: scheme).opacity(0.25)
        }
    }

    // צבעי פעולות התפריט המהיר בהתאם ל־Android.

    enum QuickAction {
        case trainingArchive
        case freeTrainings
        case stretching
    }

    struct QuickActionColors {
        let background: Color
        let content: Color
    }

    static func quickActionColors(
        for action: QuickAction,
        scheme: ColorScheme
    ) -> QuickActionColors {
        switch (scheme, action) {
        case (.dark, .trainingArchive):
            return QuickActionColors(
                background: rgb(0x312E81),
                content: rgb(0xC4B5FD)
            )

        case (.dark, .freeTrainings):
            return QuickActionColors(
                background: rgb(0x042F2E),
                content: rgb(0x5EEAD4)
            )

        case (.dark, .stretching):
            return QuickActionColors(
                background: rgb(0x172554),
                content: rgb(0x93C5FD)
            )

        case (_, .trainingArchive):
            return QuickActionColors(
                background: rgb(0xF0ECFF),
                content: rgb(0x6D4CFF)
            )

        case (_, .freeTrainings):
            return QuickActionColors(
                background: rgb(0xE0F2F1),
                content: rgb(0x00897B)
            )

        case (_, .stretching):
            return QuickActionColors(
                background: rgb(0xE3F2FD),
                content: rgb(0x1976D2)
            )
        }
    }

    private static func rgb(
        _ value: UInt32
    ) -> Color {
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

// MARK: - Shared Drawer Components

struct KmiDrawerSheetBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        KmiAppTheme.drawerSheetColors(for: colorScheme)
            .background
            .ignoresSafeArea()
    }
}

struct KmiDrawerHeader: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let subtitle: String
    let closeAccessibilityLabel: String
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .kmiTypography(.screenTitle)
                    .fontWeight(.black)
                    .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .kmiTypography(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .kmiIconSize(.medium)
                    .fontWeight(.bold)
                    .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
                    .frame(width: 38, height: 38)
                    .background(
                        KmiAppTheme.surface(for: colorScheme),
                        in: Circle()
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(
                                KmiAppTheme.outlineVariant(for: colorScheme),
                                lineWidth: 1
                            )
                            .allowsHitTesting(false)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(closeAccessibilityLabel))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(KmiAppTheme.surfaceVariant(for: colorScheme))
    }
}

struct KmiDrawerSheetTitle: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String

    var body: some View {
        Text(title)
            .kmiTypography(.screenTitle)
            .fontWeight(.black)
            .foregroundStyle(KmiAppTheme.drawerSheetColors(for: colorScheme).content)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .accessibilityAddTraits(.isHeader)
    }
}

struct KmiDrawerSectionCard<Content: View>: View {
    let title: String
    let colors: KmiAppTheme.DrawerRoleColors
    private let content: Content

    init(
        title: String,
        colors: KmiAppTheme.DrawerRoleColors,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.colors = colors
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

        VStack(spacing: 0) {
            Text(title)
                .kmiTypography(.sectionTitle)
                .fontWeight(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            Rectangle()
                .fill(colors.content.opacity(0.16))
                .frame(height: 1)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
                .accessibilityHidden(true)

            content
        }
        .foregroundStyle(colors.content)
        .padding(.vertical, 6)
        .background(colors.background, in: shape)
        .overlay {
            shape
                .strokeBorder(colors.border, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 10)
    }
}

struct KmiDrawerSheetActionGroup<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            KmiAppTheme.graniteActionBrush,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }
}

struct KmiDrawerActionRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let colors: KmiAppTheme.DrawerRoleColors
    let isCompact: Bool
    let unreadCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: isCompact ? 6 : 8) {
                KmiDrawerIconBubble(
                    systemImage: systemImage,
                    colors: colors
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .kmiTypography(.cardTitle)
                        .fontWeight(.heavy)
                        .foregroundStyle(colors.content)
                        .lineLimit(isCompact ? 2 : 1)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .kmiTypography(.secondary)
                            .fontWeight(.semibold)
                            .foregroundStyle(colors.content.opacity(0.82))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)

                if unreadCount > 0 {
                    KmiDrawerUnreadBadge(count: unreadCount)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, isCompact ? 5 : 7)
            .frame(maxWidth: .infinity, minHeight: isCompact ? 44 : 58)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(colors.content.opacity(0.10))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
    }
}

struct KmiDrawerSheetAction: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let subtitle: String
    var systemImage: String? = nil
    var isEnabled = true
    var onGranite = false
    let action: () -> Void

    var body: some View {
        let colors = onGranite
            ? KmiAppTheme.DrawerSheetColors(
                background: .clear,
                content: KmiAppTheme.sectionHeaderContentColor
            )
            : KmiAppTheme.drawerSheetColors(for: colorScheme)
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .kmiIconSize(.medium)
                        .foregroundStyle(colors.content)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .kmiTypography(.cardTitle)
                        .fontWeight(.heavy)
                        .foregroundStyle(colors.content)

                    Text(subtitle)
                        .kmiTypography(.secondary)
                        .fontWeight(.semibold)
                        .foregroundStyle(colors.secondaryContent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(colors.cardBackground, in: shape)
            .overlay {
                shape
                    .strokeBorder(colors.cardBorder, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.65)
        .disabled(!isEnabled)
    }
}

struct KmiDrawerIconBubble: View {
    let systemImage: String
    let colors: KmiAppTheme.DrawerRoleColors

    var body: some View {
        Image(systemName: systemImage)
            .kmiIconSize(.small)
            .fontWeight(.bold)
            .foregroundStyle(colors.content)
            .frame(width: 30, height: 30)
            .background(colors.content.opacity(0.10), in: Circle())
            .overlay {
                Circle()
                    .strokeBorder(colors.border.opacity(0.40), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

struct KmiDrawerSheetSearchField: View {
    let prompt: String
    @Binding var query: String

    var body: some View {
        TextField(prompt, text: $query)
            .kmiTypography(.secondary)
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.leading)
    }
}

struct KmiDrawerUnreadBadge: View {
    @Environment(\.colorScheme) private var colorScheme

    let count: Int

    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .kmiFont(size: 12, weight: .black)
            .foregroundStyle(KmiAppTheme.onSuccess(for: colorScheme))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .frame(minWidth: 24, minHeight: 24)
            .background(
                KmiAppTheme.success(for: colorScheme),
                in: Capsule()
            )
            .fixedSize(horizontal: true, vertical: false)
    }
}
