import SwiftUI
import Combine

// MARK: - App display size

/// גודל התצוגה שנבחר בהגדרות האפליקציה.
///
/// הבחירה משפיעה על:
/// 1. טקסטים המשתמשים ב־KmiTypography או ב־kmiFont.
/// 2. אייקונים המשתמשים ב־KmiIconSize או ב־kmiIconSize.
///
/// מפתח השמירה זהה למפתח Android:
/// font_size
enum KmiAppFontSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    static let preferenceKey = "font_size"

    var id: String {
        rawValue
    }

    var storageValue: String {
        rawValue
    }

    var scaleFactor: CGFloat {
        switch self {
        case .small:
            return 0.90

        case .medium:
            return 1.00

        case .large:
            return 1.15
        }
    }

    var hebrewTitle: String {
        switch self {
        case .small:
            return "קטן"

        case .medium:
            return "בינוני"

        case .large:
            return "גדול"
        }
    }

    var englishTitle: String {
        switch self {
        case .small:
            return "Small"

        case .medium:
            return "Medium"

        case .large:
            return "Large"
        }
    }

    func localizedTitle(isEnglish: Bool) -> String {
        isEnglish ? englishTitle : hebrewTitle
    }

    static func fromStorageValue(
        _ value: String?
    ) -> KmiAppFontSize {
        let normalized = value?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()

        switch normalized {
        case KmiAppFontSize.small.storageValue:
            return .small

        case KmiAppFontSize.large.storageValue:
            return .large

        default:
            return .medium
        }
    }
}

// MARK: - Display settings store

/// מנהל את בחירת גודל התצוגה ושומר אותה ב־UserDefaults.
///
/// יש ליצור מופע אחד בלבד בשורש האפליקציה ולהעביר אותו
/// לכל האפליקציה באמצעות environmentObject.
@MainActor
final class KmiDisplaySettings: ObservableObject {

    @Published private(set) var fontSize: KmiAppFontSize

    private let defaults: UserDefaults

    init(
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults

        self.fontSize = KmiAppFontSize.fromStorageValue(
            defaults.string(
                forKey: KmiAppFontSize.preferenceKey
            )
        )
    }

    var scaleFactor: CGFloat {
        fontSize.scaleFactor
    }

    func setFontSize(
        _ newValue: KmiAppFontSize
    ) {
        guard fontSize != newValue else {
            return
        }

        fontSize = newValue

        defaults.set(
            newValue.storageValue,
            forKey: KmiAppFontSize.preferenceKey
        )
    }

    func reloadFromDefaults() {
        let storedValue = KmiAppFontSize.fromStorageValue(
            defaults.string(
                forKey: KmiAppFontSize.preferenceKey
            )
        )

        guard fontSize != storedValue else {
            return
        }

        fontSize = storedValue
    }

    func resetToDefault() {
        setFontSize(.medium)
    }
}

// MARK: - Environment scale

private struct KmiFontScaleEnvironmentKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.00
}

extension EnvironmentValues {

    /// מקדם גודל הטקסט והאייקונים שנבחר בהגדרות.
    var kmiFontScale: CGFloat {
        get {
            self[KmiFontScaleEnvironmentKey.self]
        }

        set {
            self[KmiFontScaleEnvironmentKey.self] = newValue
        }
    }
}

// MARK: - Typography

/// מקור אמת יחיד לגדלי הבסיס של הטקסט באפליקציה.
///
/// הגדלים כאן הם הגדלים במצב בינוני.
/// מצב קטן או גדול מוחל באמצעות scale.
enum KmiTypography {

    /// כותרת המסך הראשית בסרגל העליון.
    static func screenTitle(
        scale: CGFloat
    ) -> Font {
        .system(
            size: 20 * scale,
            weight: .heavy
        )
    }

    /// כותרת של אזור מרכזי בתוך מסך.
    static func sectionTitle(
        scale: CGFloat
    ) -> Font {
        .system(
            size: 17 * scale,
            weight: .bold
        )
    }

    /// כותרת ראשית בתוך כרטיס, שורה או פריט.
    static func cardTitle(
        scale: CGFloat
    ) -> Font {
        .system(
            size: 15 * scale,
            weight: .bold
        )
    }

    /// טקסט תוכן רגיל.
    static func body(
        scale: CGFloat
    ) -> Font {
        .system(
            size: 14 * scale,
            weight: .regular
        )
    }

    /// טקסט הסבר או מידע משני.
    static func secondary(
        scale: CGFloat
    ) -> Font {
        .system(
            size: 12 * scale,
            weight: .regular
        )
    }

    /// טקסט של כפתורים, טאבים ופעולות.
    static func action(
        scale: CGFloat
    ) -> Font {
        .system(
            size: 14 * scale,
            weight: .bold
        )
    }

    /// תאריך, שעה, תגית או הערת שוליים.
    static func caption(
        scale: CGFloat
    ) -> Font {
        .system(
            size: 11 * scale,
            weight: .semibold
        )
    }

    /// מספר או נתון מרכזי בכרטיסי סיכום וסטטיסטיקה.
    static func metric(
        scale: CGFloat
    ) -> Font {
        .system(
            size: 24 * scale,
            weight: .heavy
        )
    }
}

// MARK: - Typography roles

enum KmiTypographyRole {
    case screenTitle
    case sectionTitle
    case cardTitle
    case body
    case secondary
    case action
    case caption
    case metric

    func font(
        scale: CGFloat
    ) -> Font {
        switch self {
        case .screenTitle:
            return KmiTypography.screenTitle(
                scale: scale
            )

        case .sectionTitle:
            return KmiTypography.sectionTitle(
                scale: scale
            )

        case .cardTitle:
            return KmiTypography.cardTitle(
                scale: scale
            )

        case .body:
            return KmiTypography.body(
                scale: scale
            )

        case .secondary:
            return KmiTypography.secondary(
                scale: scale
            )

        case .action:
            return KmiTypography.action(
                scale: scale
            )

        case .caption:
            return KmiTypography.caption(
                scale: scale
            )

        case .metric:
            return KmiTypography.metric(
                scale: scale
            )
        }
    }
}

// MARK: - Font modifiers

private struct KmiTypographyModifier: ViewModifier {

    @Environment(\.kmiFontScale)
    private var scale

    let role: KmiTypographyRole

    func body(
        content: Content
    ) -> some View {
        content.font(
            role.font(scale: scale)
        )
    }
}

private struct KmiScaledFontModifier: ViewModifier {

    @Environment(\.kmiFontScale)
    private var scale

    let baseSize: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    func body(
        content: Content
    ) -> some View {
        content.font(
            .system(
                size: baseSize * scale,
                weight: weight,
                design: design
            )
        )
    }
}

extension View {

    /// שימוש בטיפוגרפיה האחידה של האפליקציה.
    func kmiTypography(
        _ role: KmiTypographyRole
    ) -> some View {
        modifier(
            KmiTypographyModifier(role: role)
        )
    }

    /// שימוש בגודל מיוחד שאינו אחד מתפקידי הטיפוגרפיה.
    ///
    /// לדוגמה:
    /// Text("כותרת").kmiFont(size: 16, weight: .bold)
    func kmiFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> some View {
        modifier(
            KmiScaledFontModifier(
                baseSize: size,
                weight: weight,
                design: design
            )
        )
    }
}

// MARK: - Icon sizes

/// מקור אמת יחיד לגדלי האייקונים.
///
/// הגדלים הם גדלי הבסיס במצב בינוני.
enum KmiIconSize {

    static let tiny: CGFloat = 14
    static let small: CGFloat = 18
    static let medium: CGFloat = 22
    static let large: CGFloat = 28
    static let extraLarge: CGFloat = 36
    static let hero: CGFloat = 48
}

enum KmiIconSizeRole {
    case tiny
    case small
    case medium
    case large
    case extraLarge
    case hero

    var baseSize: CGFloat {
        switch self {
        case .tiny:
            return KmiIconSize.tiny

        case .small:
            return KmiIconSize.small

        case .medium:
            return KmiIconSize.medium

        case .large:
            return KmiIconSize.large

        case .extraLarge:
            return KmiIconSize.extraLarge

        case .hero:
            return KmiIconSize.hero
        }
    }
}

private struct KmiIconSizeModifier: ViewModifier {

    @Environment(\.kmiFontScale)
    private var scale

    let baseSize: CGFloat

    func body(
        content: Content
    ) -> some View {
        content.frame(
            width: baseSize * scale,
            height: baseSize * scale
        )
    }
}

extension View {

    /// מחיל גודל אייקון מתוך מקור האמת הגלובלי.
    func kmiIconSize(
        _ role: KmiIconSizeRole
    ) -> some View {
        modifier(
            KmiIconSizeModifier(
                baseSize: role.baseSize
            )
        )
    }

    /// מחיל גודל בסיס מיוחד על אייקון.
    func kmiIconSize(
        _ baseSize: CGFloat
    ) -> some View {
        modifier(
            KmiIconSizeModifier(
                baseSize: baseSize
            )
        )
    }
}

// MARK: - Root application modifier

private struct KmiDisplayScaleModifier: ViewModifier {

    @ObservedObject var settings: KmiDisplaySettings

    func body(
        content: Content
    ) -> some View {
        content
            .environmentObject(settings)
            .environment(
                \.kmiFontScale,
                settings.scaleFactor
            )
            .animation(
                .easeInOut(duration: 0.18),
                value: settings.fontSize
            )
    }
}

extension View {

    /// יש להפעיל פעם אחת בלבד בשורש האפליקציה.
    func kmiDisplayScale(
        _ settings: KmiDisplaySettings
    ) -> some View {
        modifier(
            KmiDisplayScaleModifier(
                settings: settings
            )
        )
    }
}
