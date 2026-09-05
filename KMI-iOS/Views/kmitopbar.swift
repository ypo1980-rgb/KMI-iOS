import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Shared
import StoreKit
import UIKit

// MARK: - Global bilingual UI helpers

private enum KmiGlobalLanguage {

    static var isEnglish: Bool {
        let defaults = UserDefaults.standard

        let values = [
            defaults.string(forKey: "kmi_app_language")?.lowercased(),
            defaults.string(forKey: "app_language")?.lowercased(),
            defaults.string(forKey: "initial_language_code")?.lowercased(),
            defaults.string(forKey: "selected_language_code")?.lowercased()
        ]
        .compactMap { $0 }

        return values.contains("en") || values.contains("english")
    }

    static var layoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }
}

private enum KmiGlobalText {

    static func roleLabel(
        _ raw: String,
        isEnglish: Bool
    ) -> String {
        let clean = raw
            .replacingOccurrences(
                of: "\n",
                with: " "
            )
            .replacingOccurrences(
                of: "מצב",
                with: ""
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !clean.isEmpty else {
            return ""
        }

        let normalized = clean.lowercased()

        let isCoach =
            normalized == "coach" ||
            normalized == "trainer" ||
            normalized == "instructor" ||
            normalized == "coach_user" ||
            normalized == "kmi_coach" ||
            normalized == "מאמן" ||
            normalized.contains("coach") ||
            normalized.contains("מאמן")

        let isAdmin =
            normalized == "admin" ||
            normalized == "administrator" ||
            normalized == "manager" ||
            normalized == "מנהל" ||
            normalized.contains("admin") ||
            normalized.contains("מנהל")

        let isTrainee =
            normalized == "trainee" ||
            normalized == "student" ||
            normalized == "trainee_user" ||
            normalized == "kmi_trainee" ||
            normalized == "מתאמן" ||
            normalized.contains("trainee") ||
            normalized.contains("מתאמן")

        if isCoach {
            return isEnglish
                ? "Coach"
                : "מאמן"
        }

        if isAdmin {
            return isEnglish
                ? "Admin"
                : "מנהל"
        }

        if isTrainee {
            return isEnglish
                ? "Trainee"
                : "מתאמן"
        }

        return isEnglish
            ? "Trainee"
            : "מתאמן"
    }
    
    static func screenTitle(_ raw: String, isEnglish: Bool) -> String {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        let heToEn: [String: String] = [
            "מסך הבית": "Home",
            "בית": "Home",
            "תרגילים לפי חגורה": "Exercises by Belt",
            "תרגילים לפי נושא": "Exercises by Topic",
            "לפי חגורה": "By Belt",
            "לפי נושא": "By Topic",
            "נושאים בחגורה": "Belt Topics",
            "נקודות תורפה": "Weak Points",
            "כל הרשימות": "All Lists",
            "תרגול": "Practice",
            "מסך סיכום": "Summary",
            "סיכום אימון": "Training Summary",
            "עוזר קולי": "Voice Assistant",
            "מבחן מסכם": "Final Exam",
            "מבחן פנימי": "Internal Exam",
            "דו״ח נוכחות": "Attendance Report",
            "דוח נוכחות": "Attendance Report",
            "נוכחות": "Attendance",
            "התקדמות": "Progress",
            "מד התקדמות": "Progress",
            "היסטוריית אימונים": "Training History",
            "אימונים חופשיים": "Free Sessions",
            "אודות מתאמנים": "Trainees",
            "רשימת מתאמנים": "Trainee List",
            "שליחת הודעה לקבוצה": "Group Message",
            "ניהול מנוי": "Subscription",
            "תוכניות מנוי": "Subscription Plans",
            "תשלום דמי חבר": "Membership Payment",
            "פרטי תשלום": "Payment Details",
            "דוח תשלומים": "Payments Report",
            "דו״ח תשלומים": "Payments Report",
            "הגדרות": "Settings",
            "עריכת פרופיל": "Edit Profile",
            "צור קשר": "Contact Us",
            "אודות הרשת": "About the Network",
            "אודות השיטה": "About the Method",
            "אודות איציק ביטון": "About Itzik Biton",
            "אודות אבי אביסידון": "About Avi Abisidon",
            "אודות המאמנים ברשת": "Network Coaches",
            "פורום הסניף": "Branch Forum",
            "ניהול משתמשים": "User Management",
            "מרכז בקרה ולוגים": "Control Center & Logs",
            "אין הרשאה": "No Permission"
        ]
        
        let enToHe: [String: String] = [
            "Home": "בית",
            "Exercises by Belt": "תרגילים לפי חגורה",
            "Exercises by Topic": "תרגילים לפי נושא",
            "By Belt": "לפי חגורה",
            "By Topic": "לפי נושא",
            "Belt Topics": "נושאים בחגורה",
            "Weak Points": "נקודות תורפה",
            "All Lists": "כל הרשימות",
            "Practice": "תרגול",
            "Summary": "מסך סיכום",
            "Training Summary": "סיכום אימון",
            "Voice Assistant": "עוזר קולי",
            "Final Exam": "מבחן מסכם",
            "Internal Exam": "מבחן פנימי",
            "Attendance Report": "דו״ח נוכחות",
            "Attendance": "נוכחות",
            "Progress": "התקדמות",
            "Training History": "היסטוריית אימונים",
            "Free Sessions": "אימונים חופשיים",
            "Trainees": "אודות מתאמנים",
            "Trainee List": "רשימת מתאמנים",
            "Group Message": "שליחת הודעה לקבוצה",
            "Subscription": "ניהול מנוי",
            "Subscription Plans": "תוכניות מנוי",
            "Membership Payment": "תשלום דמי חבר",
            "Payment Details": "פרטי תשלום",
            "Payments Report": "דו״ח תשלומים",
            "Settings": "הגדרות",
            "Edit Profile": "עריכת פרופיל",
            "Contact Us": "צור קשר",
            "About the Network": "אודות הרשת",
            "About the Method": "אודות השיטה",
            "About Itzik Biton": "אודות איציק ביטון",
            "About Avi Abisidon": "אודות אבי אביסידון",
            "Network Coaches": "אודות המאמנים ברשת",
            "Branch Forum": "פורום הסניף",
            "User Management": "ניהול משתמשים",
            "Control Center & Logs": "מרכז בקרה ולוגים",
            "No Permission": "אין הרשאה"
        ]
        
        if isEnglish {
            if let translated = heToEn[clean] {
                return translated
            }

            return KmiEnglishTitleResolver.title(for: clean, isEnglish: true)
        } else {
            if let translated = enToHe[clean] {
                return translated
            }

            return clean
        }
    }

    static func drawerTitle(_ raw: String, isEnglish: Bool) -> String {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isEnglish else { return clean }

        let map: [String: String] = [
            "אימונים חופשיים": "Free Sessions",
            "דו״ח נוכחות": "Attendance Report",
            "דוח נוכחות": "Attendance Report",
            "מבחן פנימי לחגורה": "Internal Belt Exam",
            "שליחת הודעה": "Send Message",
            "שליחת הודעה לקבוצה": "Group Message",
            "רשימת מתאמנים": "Trainee List",
            "אודות מתאמנים": "Trainees",
            "ניהול משתמשים": "User Management",
            "מרכז בקרה ולוגים": "Control Center & Logs",
            "ניהול מנוי": "Subscription",
            "תוכניות מנוי": "Subscription Plans",
            "אודות הרשת": "About the Network",
            "אודות השיטה": "About the Method",
            "אודות איציק ביטון": "About Itzik Biton",
            "אודות אבי אביסידון": "About Avi Abisidon",
            "פורום הסניף": "Branch Forum",
            "התנתקות": "Logout"
        ]
        
        if let translated = map[clean] {
            return translated
        }

        return KmiEnglishTitleResolver.title(for: clean, isEnglish: true)
    }
}

// MARK: - Global TopBar (לא תלוי ב-HomeView)
struct KmiTopBar: View {
    @Environment(\.colorScheme)
    private var colorScheme

    @Environment(\.kmiFontScale)
    private var displayScale

    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"
    @AppStorage("selected_language_code") private var selectedLanguageCode: String = "he"

    let roleLabel: String
    let title: String
    let onMenu: () -> Void
    let onBack: (() -> Void)?
    let rightText: String?
    let topBeltImageName: String?
    let showTopBeltIcon: Bool

    private var resolvedTopBeltImageName: String? {
        let explicitName =
            topBeltImageName?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                ) ?? ""

        if !explicitName.isEmpty {
            return explicitName
        }

        let normalizedTitle =
            title
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

        if normalizedTitle.contains("לבנה") ||
            normalizedTitle.contains("white") {
            return "belt_white"
        }

        if normalizedTitle.contains("צהובה") ||
            normalizedTitle.contains("צהוב") ||
            normalizedTitle.contains("yellow") {
            return "belt_yellow"
        }

        if normalizedTitle.contains("כתומה") ||
            normalizedTitle.contains("כתום") ||
            normalizedTitle.contains("orange") {
            return "belt_orange"
        }

        if normalizedTitle.contains("ירוקה") ||
            normalizedTitle.contains("ירוק") ||
            normalizedTitle.contains("green") {
            return "belt_green"
        }

        if normalizedTitle.contains("כחולה") ||
            normalizedTitle.contains("כחול") ||
            normalizedTitle.contains("blue") {
            return "belt_blue"
        }

        if normalizedTitle.contains("חומה") ||
            normalizedTitle.contains("חום") ||
            normalizedTitle.contains("brown") {
            return "belt_brown"
        }

        if normalizedTitle.contains("שחורה") ||
            normalizedTitle.contains("שחור") ||
            normalizedTitle.contains("black") {
            return "belt_black"
        }

        return nil
    }

    private var shouldRenderTopBeltIcon: Bool {
        showTopBeltIcon ||
        resolvedTopBeltImageName != nil
    }

    private var effectiveLanguageCode: String {
        let orderedValues = [
            kmiAppLanguageCode,
            selectedLanguageCode,
            appLanguageRaw,
            initialLanguageCode
        ]
        
        for raw in orderedValues {
            let clean = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            
            if clean == "he" || clean == "hebrew" || clean == "עברית" {
                return "he"
            }
            
            if clean == "en" || clean == "english" {
                return "en"
            }
        }
        
        return "he"
    }
    
    private var isEnglish: Bool {
        effectiveLanguageCode == "en"
    }
    
    private var localizedTitle: String {
        KmiGlobalText.screenTitle(title, isEnglish: isEnglish)
    }
    
    private var localizedRoleLabel: String {
        KmiGlobalText.roleLabel(
            roleLabel,
            isEnglish: isEnglish
        )
    }

    private var isCoachRole: Bool {
        let normalizedRole =
            roleLabel
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

        return normalizedRole == "coach" ||
            normalizedRole == "instructor" ||
            normalizedRole == "מאמן" ||
            normalizedRole.contains("coach") ||
            normalizedRole.contains("מאמן")
    }
    
    let titleColor: Color?

    private var resolvedTitleColor:
        Color {

        titleColor
        ?? KmiAppTheme
            .onSurface(
                for:
                    colorScheme
            )
    }

    private var secondaryTitleColor:
        Color {

        KmiAppTheme
            .onSurfaceVariant(
                for:
                    colorScheme
            )
    }
    
    init(
        roleLabel: String,
        title: String,
        rightText: String? = nil,
        titleColor: Color? = nil,
        topBeltImageName: String? = nil,
        showTopBeltIcon: Bool = false,
        onBack: (() -> Void)? = nil,
        onMenu: @escaping () -> Void
    ) {
        self.roleLabel = roleLabel
        self.title = title
        self.rightText = rightText
        self.titleColor = titleColor
        self.topBeltImageName = topBeltImageName
        self.showTopBeltIcon = showTopBeltIcon
        self.onBack = onBack
        self.onMenu = onMenu
    }
    
    var body: some View {
        HStack(spacing: 10) {
            VStack(spacing: 23) {
                if let onBack {

                    Button {

                        onBack()

                    } label: {

                        ZStack {

                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            KmiAppTheme
                                                .primary(
                                                    for:
                                                        colorScheme
                                                )
                                                .opacity(
                                                    0.20
                                                ),
                                            KmiAppTheme
                                                .secondary(
                                                    for:
                                                        colorScheme
                                                )
                                                .opacity(
                                                    0.10
                                                ),
                                            Color.clear
                                        ],
                                        center:
                                            .center,
                                        startRadius:
                                            2,
                                        endRadius:
                                            22
                                    )
                                )
                                .frame(
                                    width:
                                        42,
                                    height:
                                        42
                                )

                            Image(
                                systemName:
                                    isEnglish
                                        ? "chevron.right"
                                        : "chevron.left"
                            )
                            .kmiIconSize(
                                16
                            )
                            .fontWeight(
                                .black
                            )
                            .foregroundStyle(
                                KmiAppTheme
                                    .primary(
                                        for:
                                            colorScheme
                                    )
                            )
                        }
                        .frame(
                            width:
                                42,
                            height:
                                42
                        )
                        .contentShape(
                            Circle()
                        )
                    }
                    .buttonStyle(
                        .plain
                    )
                    .accessibilityLabel(
                        isEnglish
                            ? "Back"
                            : "חזור"
                    )

                } else {

                    Color.clear
                        .frame(
                            width:
                                42,
                            height:
                                42
                        )
                }

                if !localizedRoleLabel
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .isEmpty {

                    Text(
                        localizedRoleLabel
                    )
                    .kmiTypography(
                        .caption
                    )
                    .fontWeight(
                        .heavy
                    )
                    .lineLimit(
                        1
                    )
                    .minimumScaleFactor(
                        0.82
                    )
                    .multilineTextAlignment(
                        .center
                    )
                    .foregroundStyle(
                        Color.white
                    )
                    .padding(
                        .horizontal,
                        8 * displayScale
                    )
                    .padding(
                        .vertical,
                        3 * displayScale
                    )
                    .background {

                        Capsule(
                            style:
                                .continuous
                        )
                        .fill(
                            isCoachRole
                                ? KmiAppTheme
                                    .primary(
                                        for:
                                            colorScheme
                                    )
                                : KmiAppTheme
                                    .secondary(
                                        for:
                                            colorScheme
                                    )
                        )
                        .opacity(
                            0.94
                        )
                    }
                    .overlay {

                        Capsule(
                            style:
                                .continuous
                        )
                        .stroke(
                            Color.white
                                .opacity(
                                    0.20
                                ),
                            lineWidth:
                                1
                        )
                    }
                    .shadow(
                        color:
                            Color.black
                                .opacity(
                                    0.08
                                ),
                        radius:
                            1,
                        x:
                            0,
                        y:
                            1
                    )
                } else {
                    Color.clear
                        .frame(width: 66, height: 17)
                }
            }
            .frame(
                width: 82,
                height: 54,
                alignment: .leading
            )

            Spacer(minLength: 4)

            HStack(spacing: 8) {
                if shouldRenderTopBeltIcon,
                   let resolvedTopBeltImageName {

                    let isYellowBelt =
                        resolvedTopBeltImageName
                            .lowercased()
                            .contains(
                                "yellow"
                            )

                    Image(
                        resolvedTopBeltImageName
                    )
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width:
                            82 * displayScale,
                        height:
                            38 * displayScale
                    )
                    .scaleEffect(
                        x:
                            isYellowBelt
                                ? 1.55
                                : 1.0,
                        y:
                            1.0
                    )
                    .rotationEffect(
                        .degrees(
                            isEnglish
                                ? 20
                                : -20
                        )
                    )
                    .accessibilityLabel(
                        isEnglish
                            ? "Belt"
                            : "חגורה"
                    )
                }

                Text(
                    localizedTitle
                )
                .kmiTypography(
                    .screenTitle
                )
                .foregroundStyle(
                    resolvedTitleColor
                )
                    .lineLimit(1)
                    .allowsTightening(true)
                    .minimumScaleFactor(0.68)
                    .multilineTextAlignment(.center)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .center
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                    .layoutPriority(1)

                if let rightText,
                   !rightText
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty {
                    Text(
                        rightText
                    )
                    .kmiTypography(
                        .cardTitle
                    )
                    .foregroundStyle(
                        secondaryTitleColor
                    )
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .frame(
                maxWidth:
                    .infinity,
                minHeight:
                    54,
                alignment:
                    .center
            )
            .layoutPriority(
                1
            )

            Spacer(minLength: 4)

            HStack(spacing: 6) {

                Button(action: onMenu) {
                    ZStack {
                        RoundedRectangle(
                            cornerRadius: 11,
                            style: .continuous
                        )
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: 0xFF8B5CF6),
                                    Color(hex: 0xFF6D4ED8),
                                    Color(hex: 0xFF3B1F82)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(
                                cornerRadius: 11,
                                style: .continuous
                            )
                            .stroke(
                                Color.white.opacity(0.28),
                                lineWidth: 1
                            )
                        )

                        VStack(
                            spacing: 4 * displayScale
                        ) {
                            ForEach(0..<3, id: \.self) { _ in
                                Capsule(style: .continuous)
                                    .fill(Color.white)
                                    .frame(
                                        width: 20 * displayScale,
                                        height: 3 * displayScale
                                    )
                            }
                        }
                    }
                    .frame(width: 38, height: 38)
                    .contentShape(
                        RoundedRectangle(
                            cornerRadius: 11,
                            style: .continuous
                        )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    isEnglish ? "Menu" : "תפריט"
                )
            }
            .frame(width: 82, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .frame(height: 84)
        .environment(
            \.layoutDirection,
            isEnglish ? .rightToLeft : .leftToRight
        )
    }
}


// MARK: - Root Layout
struct KmiRootLayout<Content: View>: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"
    @AppStorage("selected_language_code") private var selectedLanguageCode: String = "he"

    /*
     * מקור התפקיד הפעיל, בהתאם ל־user_role באנדרואיד.
     *
     * שימוש ב־AppStorage גורם לכל המעטפת להתעדכן מיד
     * כאשר המשתמש עובר בין מצב מאמן למצב מתאמן.
     */
    @AppStorage("user_role")
    private var storedActiveUserRole: String = ""

    /*
     * icon = הצגת אייקון המיקרופון
     * long_press = הפעלה בלחיצה ארוכה על החיפוש
     * both = שתי אפשרויות ההפעלה
     * off = פקודות קוליות כבויות
     */
    @AppStorage("voice_commands_activation_mode")
    private var voiceCommandsActivationMode: String = "icon"

    private var effectiveLanguageCode: String {
        let orderedValues = [
            kmiAppLanguageCode,
            selectedLanguageCode,
            appLanguageRaw,
            initialLanguageCode
        ]

        for raw in orderedValues {
            let clean = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            if clean == "he" || clean == "hebrew" || clean == "עברית" {
                return "he"
            }

            if clean == "en" || clean == "english" {
                return "en"
            }
        }

        return "he"
    }

    private var isEnglish: Bool {
        effectiveLanguageCode == "en"
    }

    private var normalizedVoiceCommandsActivationMode: String {
        voiceCommandsActivationMode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private var showVoiceCommandsIcon: Bool {
        normalizedVoiceCommandsActivationMode == "icon" ||
        normalizedVoiceCommandsActivationMode == "both"
    }

    private var enableVoiceCommandsLongPress: Bool {
        normalizedVoiceCommandsActivationMode == "long_press" ||
        normalizedVoiceCommandsActivationMode == "both"
    }
    
    let title: String
    let roleLabel: String
    let content: Content
    let rightText: String?
    let titleColor: Color?
    let onPickSearchResult: ((String) -> Void)?
    let onShare: (() -> Void)?
    /*
     * Back מקומי אופציונלי.
     *
     * מיועד למסכים שנפתחו ב-navigationDestination
     * מקומי ולא דרך AppNavModel.path.
     *
     * אם קיים override, הוא קודם ל-nav.pop().
     */
    let onBackOverride: (() -> Void)?
    
    /*
     * התאמה ל־lockSearch ול־lockHome באנדרואיד.
     */
    let lockSearch: Bool
    let lockHome: Bool
    let homeDisabledMessage: String?

    /*
     * מקביל לאפשרויות הצגת סרגל הפעולות באנדרואיד.
     */
    let showQuickActions: Bool
    let showSettingsAction: Bool
    let showGuideAction: Bool
    let showShareAction: Bool

    /*
     * מקביל ל־showRoleBadge ול־modePillIsCoach באנדרואיד.
     */
    let showRoleBadge: Bool
    let modePillIsCoach: Bool?

    /*
     * תמונת חגורה אופציונלית בכותרת.
     * כאשר לא מועבר שם, מתבצע זיהוי אוטומטי לפי הכותרת.
     */
    let topBeltImageName: String?
    let showTopBeltIcon: Bool

    /*
     * מונע פתיחת עותק נוסף של העוזר האישי
     * כאשר המשתמש כבר נמצא במסך העוזר.
     */
    let isInsideAssistant: Bool
    
    @ObservedObject var nav: AppNavModel
    let selectedIcon: KmiIconStripItem?

    @State private var drawerOpen: Bool = false
    @State private var showGlobalIconMenu: Bool = false
    @State private var titleOverride: String? = nil

    /*
     * מונע מפעולת הלחיצה הרגילה של Button לפתוח את החיפוש
     * לאחר שלחיצה ארוכה כבר פתחה את הפקודות הקוליות.
     */
    @State private var suppressNextGlobalRailTap: Bool = false
    
    // ✅ Global Search Sheet
    @State private var showGlobalSearch: Bool = false
    @State private var globalSearchInitialQuery: String = ""
    @State private var selectedGlobalSearchHit: ExerciseSearchHit? = nil

    // ✅ Global Share Sheet
    @State private var showShareSheet: Bool = false
    @State private var shareItems: [Any] = []

    // שגיאה בפעולה מתוך תפריט הצד
    @State private var drawerActionErrorMessage: String? = nil

    init(
        title: String,
        nav: AppNavModel,
        roleLabel: String = "מתאמן",
        selectedIcon: KmiIconStripItem? = nil,
        rightText: String? = nil,
        titleColor: Color? = nil,
        lockSearch: Bool = false,
        lockHome: Bool = false,
        homeDisabledMessage: String? = nil,
        showQuickActions: Bool = true,
        showSettingsAction: Bool = true,
        showGuideAction: Bool = true,
        showShareAction: Bool = true,
        showRoleBadge: Bool = true,
        modePillIsCoach: Bool? = nil,
        topBeltImageName: String? = nil,
        showTopBeltIcon: Bool = false,
        isInsideAssistant: Bool = false,
        onPickSearchResult: ((String) -> Void)? = nil,
        onShare: (() -> Void)? = nil,
        onBackOverride: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.nav = nav
        self.roleLabel = roleLabel
        self.selectedIcon = selectedIcon
        self.rightText = rightText
        self.titleColor = titleColor
        self.lockSearch = lockSearch
        self.lockHome = lockHome
        self.homeDisabledMessage = homeDisabledMessage
        self.showQuickActions = showQuickActions
        self.showSettingsAction = showSettingsAction
        self.showGuideAction = showGuideAction
        self.showShareAction = showShareAction
        self.showRoleBadge = showRoleBadge
        self.modePillIsCoach = modePillIsCoach
        self.topBeltImageName = topBeltImageName
        self.showTopBeltIcon = showTopBeltIcon
        self.isInsideAssistant = isInsideAssistant
        self.onPickSearchResult = onPickSearchResult
        self.onShare = onShare
        self.onBackOverride = onBackOverride
        self.content = content()
    }
  
    private var effectiveRole: String {
        /*
         * AuthViewModel הוא מקור האמת הראשון.
         *
         * מאחר ש־userRole הוא @Published, שינוי התפקיד
         * מרענן מיד את KmiRootLayout ואת KmiTopBar.
         */
        let authRole =
            auth.userRole
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

        if !authRole.isEmpty {
            return authRole
        }

        /*
         * user_role משמש כמקור גיבוי בזמן העלייה
         * הראשונית של האפליקציה.
         */
        let activeRole =
            storedActiveUserRole
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

        if !activeRole.isEmpty {
            return activeRole
        }

        let defaults = UserDefaults.standard

        let roleAliasKeys = [
            "role",
            "userRole",
            "profile_role"
        ]

        for key in roleAliasKeys {
            let storedRole =
                defaults.string(forKey: key)?
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .lowercased() ?? ""

            if !storedRole.isEmpty {
                return storedRole
            }
        }

        return "trainee"
    }

    private var effectiveTopBarTitle: String {
        let cleanOverride = titleOverride?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let cleanOverride, !cleanOverride.isEmpty {
            return cleanOverride
        }

        return title
    }
    
    private var resolvedBackAction:
        (() -> Void)? {

        guard
            onBackOverride != nil ||
            !nav.path.isEmpty
        else {

            return nil
        }

        return {

            showGlobalIconMenu = false
            drawerOpen = false
            showGlobalSearch = false
            showShareSheet = false
            selectedGlobalSearchHit = nil

            withAnimation(
                .easeInOut(
                    duration: 0.20
                )
            ) {

                if let onBackOverride {

                    onBackOverride()

                } else {

                    nav.pop()
                }
            }
        }
    }
    
    private var roleForGlobalBadge: String {
        if let modePillIsCoach {
            return modePillIsCoach
                ? "coach"
                : "trainee"
        }

        return effectiveRole
    }

    private var globalRoleBadgeText: String {
        guard showRoleBadge else {
            return ""
        }

        return KmiGlobalText.roleLabel(
            roleForGlobalBadge,
            isEnglish: isEnglish
        )
    }

    private var topBarSurfaceColor:
        Color {

        KmiAppTheme
            .surface(
                for:
                    colorScheme
            )
    }

    private var topBarDividerColor:
        Color {

        KmiAppTheme
            .outline(
                for:
                    colorScheme
            )
            .opacity(
                0.45
            )
    }

    @ViewBuilder
    private var layoutBackground: some View {
        KmiGradientBackground(forceTraineeStyle: false)
    }
    
    var body: some View {
        KmiSideDrawerContainer(
            isOpen: $drawerOpen,

            onItem: { item in

                drawerOpen = false
                showGlobalIconMenu = false
                showGlobalSearch = false
                showShareSheet = false
                selectedGlobalSearchHit = nil

                let defaults =
                    UserDefaults.standard

                let freeSessionsUid =
                    Auth.auth().currentUser?.uid
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ) ?? ""

                let freeSessionsName: String = {
                    let firebaseName =
                        (Auth.auth().currentUser?.displayName ?? "")
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )

                    if !firebaseName.isEmpty {
                        return firebaseName
                    }

                    let nameKeys = [
                        "fullName",
                        "full_name",
                        "name",
                        "user_name"
                    ]

                    for key in nameKeys {
                        let value =
                            defaults.string(forKey: key)?
                                .trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                ) ?? ""

                        if !value.isEmpty {
                            return value
                        }
                    }

                    let email =
                        (Auth.auth().currentUser?.email ?? "")
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )

                    if !email.isEmpty {
                        return email
                    }

                    return isEnglish
                        ? "User"
                        : "משתמש"
                }()

                let freeSessionsBranch: String = {
                    let authBranch =
                        auth.userBranch
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )

                    if !authBranch.isEmpty {
                        return authBranch
                    }

                    let branchKeys = [
                        "active_branch",
                        "activeBranch",
                        "branch"
                    ]

                    for key in branchKeys {
                        let value =
                            defaults.string(forKey: key)?
                                .trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                ) ?? ""

                        if !value.isEmpty {
                            return value
                        }
                    }

                    return ""
                }()

                let freeSessionsGroupKey: String = {
                    let authGroup =
                        auth.userGroup
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )

                    if !authGroup.isEmpty {
                        return authGroup
                    }

                    let groupKeys = [
                        "active_group",
                        "activeGroup",
                        "group",
                        "age_group"
                    ]

                    for key in groupKeys {
                        let value =
                            defaults.string(forKey: key)?
                                .trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                ) ?? ""

                        if !value.isEmpty {
                            return value
                        }
                    }

                    return ""
                }()

                switch item.routeKey {

                case .freeSessions:
                    guard !freeSessionsUid.isEmpty,
                          !freeSessionsBranch.isEmpty,
                          !freeSessionsGroupKey.isEmpty else {
                        drawerActionErrorMessage =
                            isEnglish
                            ? "Branch, group or user details are missing."
                            : "חסרים סניף, קבוצה או פרטי משתמש."
                        return
                    }

                    nav.push(
                        .freeSessions(
                            branch: freeSessionsBranch,
                            groupKey: freeSessionsGroupKey,
                            uid: freeSessionsUid,
                            name: freeSessionsName
                        )
                    )

                case .attendance:
                    nav.push(.attendance)

                case .internalExam:
                    let storedBelt =
                        (
                            defaults.string(
                                forKey: "current_belt"
                            ) ??
                            defaults.string(
                                forKey: "belt_current"
                            ) ??
                            "white"
                        )
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        .lowercased()

                    let fallbackBelt: Belt

                    switch storedBelt {
                    case "yellow", "צהוב", "צהובה":
                        fallbackBelt = .yellow

                    case "orange", "כתום", "כתומה":
                        fallbackBelt = .orange

                    case "green", "ירוק", "ירוקה":
                        fallbackBelt = .green

                    case "blue", "כחול", "כחולה":
                        fallbackBelt = .blue

                    case "brown", "חום", "חומה":
                        fallbackBelt = .brown

                    case "black", "שחור", "שחורה":
                        fallbackBelt = .black

                    default:
                        fallbackBelt = .white
                    }

                    nav.push(
                        .internalExam(
                            belt:
                                auth.registeredBelt ??
                                fallbackBelt
                        )
                    )

                case .myProfile:
                    nav.push(.editProfile)

                case .coachBroadcast:
                    nav.push(.coachBroadcast)

                case .coachTrainees:
                    nav.push(.coachTrainees)

                case .coachPaymentsReport:
                    nav.push(.paymentsReport)

                case .adminUsers:
                    nav.push(.adminUsers)

                case .controlCenterLogs:
                    nav.push(.controlCenterLogs)

                case .aboutAvi:
                    nav.push(.aboutAvi)
                    
                case .aboutNetworkCoaches:
                    nav.push(.aboutNetworkCoaches)

                case .aboutMethod:
                    nav.push(.aboutMethod)

                case .demoVideos:
                    drawerActionErrorMessage =
                        isEnglish
                        ? "The demonstration videos screen is being connected to iOS."
                        : "מסך סרטוני ההדגמה עדיין נמצא בתהליך חיבור ל־iOS."

                case .formsPayments:
                    drawerActionErrorMessage =
                        isEnglish
                        ? "The forms and payments screen is being connected to iOS."
                        : "מסך הטפסים והתשלומים עדיין נמצא בתהליך חיבור ל־iOS."

                case .contactUs:
                    nav.push(.contactUs)
                    
                case .forum:
                    nav.push(.forum)

                case .editProfile:
                    nav.push(.editProfile)

                case .subscription:
                    nav.push(.subscription)

                case .rateUs:
                    openRateUs()

                case .toggleLanguage:
                    let nextCode =
                        isEnglish ? "he" : "en"

                    let nextLegacyCode =
                        isEnglish
                        ? "HEBREW"
                        : "ENGLISH"

                    kmiAppLanguageCode = nextCode
                    selectedLanguageCode = nextCode
                    appLanguageRaw = nextLegacyCode
                    initialLanguageCode = nextLegacyCode

                    defaults.set(
                        nextCode,
                        forKey: "kmi_app_language"
                    )
                    defaults.set(
                        nextCode,
                        forKey: "selected_language_code"
                    )
                    defaults.set(
                        nextLegacyCode,
                        forKey: "app_language"
                    )
                    defaults.set(
                        nextLegacyCode,
                        forKey: "initial_language_code"
                    )

                case .logout:
                    drawerOpen = false
                    showGlobalIconMenu = false
                    showGlobalSearch = false
                    showShareSheet = false
                    selectedGlobalSearchHit = nil
                    titleOverride = nil
                    shareItems.removeAll()
                    nav.popToRoot()
                    auth.signOut()
                }
            }
        ) {
            ZStack {
                layoutBackground

                VStack(spacing: 0) {

                    KmiTopBar(
                        roleLabel: globalRoleBadgeText,
                        title: effectiveTopBarTitle,
                        rightText: rightText,
                        titleColor: titleColor,
                        topBeltImageName: topBeltImageName,
                        showTopBeltIcon: showTopBeltIcon,
                        onBack: resolvedBackAction,
                        onMenu: {
                            showGlobalIconMenu = false
                            drawerOpen = true
                        }
                    )
                    .background(topBarSurfaceColor)
                    .overlay(
                        Rectangle()
                            .fill(topBarDividerColor)
                            .frame(height: 1),
                        alignment: .bottom
                    )
                    .overlay(alignment: .top) {
                        if showQuickActions {
                            globalIconRailToggle
                        }
                    }
                    .overlay(alignment: .top) {
                        if showVoiceCommandsIcon {
                            globalVoiceCommandsToggle
                        }
                    }
                    .zIndex(20)
                    
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }

                if showQuickActions {
                    globalIconSideRailLayer
                }
            }
        }
        
        // ✅ Sheet של חיפוש גלובאלי
        .sheet(
            isPresented: $showGlobalSearch,
            onDismiss: {
                globalSearchInitialQuery = ""
            }
        ) {
            GlobalExerciseSearchSheet_Legacy(
                initialQuery: globalSearchInitialQuery
            ) { hit in
                let key =
                    "\(hit.belt.id)|\(hit.topic)|\(hit.displayTitle)"

                if let onPickSearchResult {
                    onPickSearchResult(key)
                } else {
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + 0.25
                    ) {
                        selectedGlobalSearchHit = hit
                    }
                }
            }
            .id(globalSearchInitialQuery)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedGlobalSearchHit) { hit in
            NavigationStack {
                ExerciseDetailView(
                    belt: hit.belt,
                    topicTitle: hit.topic,
                    item: hit.displayTitle
                )
            }
        }

        // ✅ Sheet של שיתוף (WhatsApp דרך Share Sheet)
        .sheet(isPresented: $showShareSheet) {
            KmiShareSheet(items: shareItems)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert(
            isEnglish
            ? "Unable to Open"
            : "לא ניתן לפתוח",
            isPresented: Binding(
                get: {
                    drawerActionErrorMessage != nil
                },
                set: { isPresented in
                    if !isPresented {
                        drawerActionErrorMessage = nil
                    }
                }
            )
        ) {
            Button(
                isEnglish ? "OK" : "אישור",
                role: .cancel
            ) {
                drawerActionErrorMessage = nil
            }
        } message: {
            Text(drawerActionErrorMessage ?? "")
        }
        .environment(
            \.layoutDirection,
            isEnglish ? .leftToRight : .rightToLeft
        )
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name(
                    "KMI_OPEN_GLOBAL_SEARCH"
                )
            )
        ) { notification in

            let receivedQuery =
                (notification.object as? String)?
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ) ?? ""

            drawerOpen = false
            showGlobalIconMenu = false
            globalSearchInitialQuery = receivedQuery
            showGlobalSearch = true
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name(
                    "KMI_FIND_AND_OPEN_EXERCISE"
                )
            )
        ) { notification in
            guard !lockSearch else {

                drawerActionErrorMessage =
                    isEnglish
                    ? "Search is not available on this screen."
                    : "החיפוש אינו זמין במסך זה."

                return
            }
            let query =
                (notification.object as? String)?
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ) ?? ""

            guard !query.isEmpty else {
                globalSearchInitialQuery = ""
                showGlobalSearch = true
                return
            }

            drawerOpen = false
            showGlobalIconMenu = false
            showGlobalSearch = false

            let engine =
                GlobalExerciseSearchEngine.shared

            engine.ensureBuilt()

            let matches =
                engine.search(
                    query: query,
                    beltFilter: nil,
                    limit: 1
                )

            if let firstMatch = matches.first {
                selectedGlobalSearchHit =
                    firstMatch
            } else {
                globalSearchInitialQuery = query
                showGlobalSearch = true
            }
        }
    }

    private func openVoiceCommandsSafely() {

        showGlobalIconMenu =
            false

        drawerOpen =
            false

        let opened =
            VoiceCommandsBridge
                .open()

        if !opened {

            drawerActionErrorMessage =
                isEnglish
                ? "Voice commands are not connected yet."
                : "הפקודות הקוליות עדיין אינן מחוברות."
        }
    }
    
    private var globalVoiceCommandsToggle: some View {
        HStack(spacing: 0) {
            globalVoiceCommandsButton
                .padding(.leading, 8)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 28)
        .offset(
            y:
                83
        )
        .environment(
            \.layoutDirection,
            .leftToRight
        )
    }

    private var globalVoiceCommandsButton:
        some View {

        Button {

            openVoiceCommandsSafely()
        } label: {

            ZStack {

                UnevenRoundedRectangle(
                    topLeadingRadius:
                        0,
                    bottomLeadingRadius:
                        18,
                    bottomTrailingRadius:
                        18,
                    topTrailingRadius:
                        0,
                    style:
                        .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [
                            Color(
                                hex:
                                    0xFFF8F7FF
                            ),
                            Color(
                                hex:
                                    0xFFF0EEFF
                            ),
                            Color(
                                hex:
                                    0xFFE6E2FF
                            )
                        ],
                        startPoint:
                            .top,
                        endPoint:
                            .bottom
                    )
                )

                UnevenRoundedRectangle(
                    topLeadingRadius:
                        0,
                    bottomLeadingRadius:
                        18,
                    bottomTrailingRadius:
                        18,
                    topTrailingRadius:
                        0,
                    style:
                        .continuous
                )
                .stroke(
                    Color(
                        hex:
                            0xFFB7AEF5
                    ),
                    lineWidth:
                        1
                )

                Rectangle()
                    .fill(
                        Color.white
                            .opacity(
                                0.40
                            )
                    )
                    .frame(
                        height:
                            1
                    )
                    .frame(
                        maxHeight:
                            .infinity,
                        alignment:
                            .top
                    )

                Image(
                    systemName:
                        "mic.fill"
                )
                .kmiIconSize(
                    16
                )
                .foregroundStyle(
                    Color(
                        hex:
                            0xFF4B478F
                    )
                )
            }
            .frame(
                width:
                    48,
                height:
                    28
            )
            .contentShape(
                UnevenRoundedRectangle(
                    topLeadingRadius:
                        0,
                    bottomLeadingRadius:
                        18,
                    bottomTrailingRadius:
                        18,
                    topTrailingRadius:
                        0,
                    style:
                        .continuous
                )
            )
        }
        .buttonStyle(
            .plain
        )
        .accessibilityLabel(
            isEnglish
                ? "Voice commands"
                : "פקודות קוליות"
        )
    }

    private var globalIconRailToggle: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            globalIconRailToggleButton
                .padding(.trailing, 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 28)
        .offset(
            y:
                83
        )
        .environment(
            \.layoutDirection,
            .leftToRight
        )
    }

    private var globalIconRailToggleButton:
        some View {

        Button {

            withAnimation(
                .spring(
                    response:
                        0.25,
                    dampingFraction:
                        0.90
                )
            ) {

                showGlobalIconMenu
                    .toggle()
            }

        } label: {

            ZStack {

                UnevenRoundedRectangle(
                    topLeadingRadius:
                        0,
                    bottomLeadingRadius:
                        18,
                    bottomTrailingRadius:
                        18,
                    topTrailingRadius:
                        0,
                    style:
                        .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [
                            Color(
                                hex:
                                    0xFFF8F7FF
                            ),
                            Color(
                                hex:
                                    0xFFF0EEFF
                            ),
                            Color(
                                hex:
                                    0xFFE6E2FF
                            )
                        ],
                        startPoint:
                            .top,
                        endPoint:
                            .bottom
                    )
                )

                UnevenRoundedRectangle(
                    topLeadingRadius:
                        0,
                    bottomLeadingRadius:
                        18,
                    bottomTrailingRadius:
                        18,
                    topTrailingRadius:
                        0,
                    style:
                        .continuous
                )
                .stroke(
                    Color(
                        hex:
                            0xFFB7AEF5
                    ),
                    lineWidth:
                        1
                )

                Rectangle()
                    .fill(
                        Color.white
                            .opacity(
                                0.40
                            )
                    )
                    .frame(
                        height:
                            1
                    )
                    .frame(
                        maxHeight:
                            .infinity,
                        alignment:
                            .top
                    )

                Image(
                    systemName:
                        "chevron.down"
                )
                .kmiIconSize(
                    16
                )
                .fontWeight(
                    .black
                )
                .foregroundStyle(
                    Color(
                        hex:
                            0xFF4B478F
                    )
                )
                .rotationEffect(
                    .degrees(
                        showGlobalIconMenu
                            ? 180
                            : 0
                    )
                )
                .animation(
                    .spring(
                        response:
                            0.26,
                        dampingFraction:
                            0.78
                    ),
                    value:
                        showGlobalIconMenu
                )
            }
            .frame(
                width:
                    48,
                height:
                    28
            )
            .contentShape(
                UnevenRoundedRectangle(
                    topLeadingRadius:
                        0,
                    bottomLeadingRadius:
                        18,
                    bottomTrailingRadius:
                        18,
                    topTrailingRadius:
                        0,
                    style:
                        .continuous
                )
            )
        }
        .buttonStyle(
            .plain
        )
        .scaleEffect(
            showGlobalIconMenu
                ? 0.97
                : 1.0
        )
        .animation(
            .spring(
                response:
                    0.22,
                dampingFraction:
                    0.78
            ),
            value:
                showGlobalIconMenu
        )
        .accessibilityLabel(
            showGlobalIconMenu
                ? (
                    isEnglish
                        ? "Close icon rail"
                        : "סגור סרגל אייקונים"
                )
                : (
                    isEnglish
                        ? "Open icon rail"
                        : "פתח סרגל אייקונים"
                )
        )
    }

    private var globalRailItems: [KmiIconStripItem] {
        var items: [KmiIconStripItem] = [
            .search,
            .home
        ]

        if showSettingsAction {
            items.append(.settings)
        }

        items.append(.stats)
        items.append(.assistant)

        if showGuideAction {
            items.append(.guide)
        }

        if showShareAction {
            items.append(.share)
        }

        return items
    }
    
    private var globalIconSideRailLayer:
        some View {

        ZStack {

            if showGlobalIconMenu {

                Color.black
                    .opacity(
                        0.001
                    )
                    .ignoresSafeArea()
                    .contentShape(
                        Rectangle()
                    )
                    .onTapGesture {

                        withAnimation(
                            .spring(
                                response:
                                    0.25,
                                dampingFraction:
                                    0.90
                            )
                        ) {

                            showGlobalIconMenu =
                                false
                        }
                    }

                globalVerticalRailPanel
                    .frame(
                        maxWidth:
                            .infinity,
                        maxHeight:
                            .infinity,
                        alignment:
                            .topTrailing
                    )
                    .padding(
                        .top,
                        120
                    )
                    .padding(
                        .trailing,
                        2
                    )
                    .environment(
                        \.layoutDirection,
                        .leftToRight
                    )
                    .transition(
                        .opacity
                            .combined(
                                with:
                                    .move(
                                        edge:
                                            .trailing
                                    )
                            )
                    )
                    .zIndex(
                        40
                    )
            }
        }
        .frame(
            maxWidth:
                .infinity,
            maxHeight:
                .infinity
        )
        .environment(
            \.layoutDirection,
            .leftToRight
        )
    }

    private var globalVerticalRailPanel:
        some View {

        VStack(
            spacing:
                5
        ) {

            ForEach(
                globalRailItems,
                id:
                    \.self
            ) { item in

                let isEnabled =
                    isGlobalRailItemEnabled(
                        item
                    )

                Button {

                    /*
                     * Home נעול עדיין מגיב ללחיצה
                     * כדי להציג את הודעת Android.
                     */
                    if item == .home,
                       lockHome {

                        onGlobalIconTap(
                            .home
                        )

                        return
                    }

                    guard
                        isEnabled
                    else {

                        return
                    }

                    if suppressNextGlobalRailTap {

                        suppressNextGlobalRailTap =
                            false

                        return
                    }

                    withAnimation(
                        .spring(
                            response:
                                0.25,
                            dampingFraction:
                                0.90
                        )
                    ) {

                        showGlobalIconMenu =
                            false
                    }

                    onGlobalIconTap(
                        item
                    )

                } label: {

                    globalRailIcon(
                        item
                    )
                    .opacity(
                        isEnabled
                            ? 1.0
                            : 0.58
                    )
                }
                .buttonStyle(
                    .plain
                )
                .disabled(
                    !isEnabled &&
                    !(item == .home && lockHome)
                )
            }
        }
        .padding(
            .horizontal,
            2
        )
        .padding(
            .vertical,
            6
        )
        .frame(
            width:
                68
        )
        .background {

            RoundedRectangle(
                cornerRadius:
                    22,
                style:
                    .continuous
            )
            .fill(
                LinearGradient(
                    colors: [
                        KmiAppTheme
                            .surface(
                                for:
                                    colorScheme
                            ),
                        KmiAppTheme
                            .surfaceVariant(
                                for:
                                    colorScheme
                            ),
                        KmiAppTheme
                            .surface(
                                for:
                                    colorScheme
                            )
                    ],
                    startPoint:
                        .top,
                    endPoint:
                        .bottom
                )
            )
        }
        .overlay {

            RoundedRectangle(
                cornerRadius:
                    22,
                style:
                    .continuous
            )
            .stroke(
                KmiAppTheme
                    .outlineVariant(
                        for:
                            colorScheme
                    ),
                lineWidth:
                    1
            )
        }
        .shadow(
            color:
                Color.black
                    .opacity(
                        0.08
                    ),
            radius:
                2,
            x:
                0,
            y:
                1
        )
    }

    private func globalRailIcon(
        _ item:
            KmiIconStripItem
    ) -> some View {

        let tint =
            globalRailIconTint(
                item
            )

        let isEnabled =
            isGlobalRailItemEnabled(
                item
            )

        return VStack(
            spacing:
                3
        ) {

            ZStack {

                Circle()
                    .fill(
                        tint.opacity(
                            isEnabled
                                ? 0.16
                                : 0.08
                        )
                    )
                    .frame(
                        width:
                            34,
                        height:
                            34
                    )

                Circle()
                    .stroke(
                        tint.opacity(
                            isEnabled
                                ? 0.24
                                : 0.12
                        ),
                        lineWidth:
                            1
                    )
                    .frame(
                        width:
                            34,
                        height:
                            34
                    )

                Image(
                    systemName:
                        globalRailSystemIcon(
                            item
                        )
                )
                .kmiIconSize(
                    17
                )
                .foregroundStyle(
                    isEnabled
                        ? tint
                        : KmiAppTheme
                            .onSurfaceVariant(
                                for:
                                    colorScheme
                            )
                            .opacity(
                                0.45
                            )
                )
            }

            Text(
                globalRailTitle(
                    item
                )
            )
            .kmiTypography(
                .caption
            )
            .fontWeight(
                .bold
            )
            .foregroundStyle(
                isEnabled
                    ? KmiAppTheme
                        .onSurface(
                            for:
                                colorScheme
                        )
                    : KmiAppTheme
                        .onSurfaceVariant(
                            for:
                                colorScheme
                        )
                        .opacity(
                            0.52
                        )
            )
            .lineLimit(
                1
            )
            .minimumScaleFactor(
                0.66
            )
        }
        .frame(
            maxWidth:
                .infinity
        )
        .padding(
            .vertical,
            2
        )
        .contentShape(
            RoundedRectangle(
                cornerRadius:
                    14,
                style:
                    .continuous
            )
        )
    }

    private func globalRailTitle(_ item: KmiIconStripItem) -> String {
        switch item {
        case .search:
            return isEnglish ? "Search" : "חיפוש"
        case .home:
            return isEnglish ? "Home" : "בית"
        case .settings:
            return isEnglish ? "Settings" : "הגדרות"
        case .stats:
            return isEnglish ? "Stats" : "סטטיסטיקה"
        case .assistant:
            return isEnglish ? "AI" : "עוזר"

        case .guide:
            return isEnglish ? "Guide" : "הדרכה"

        case .share:
            return isEnglish ? "Share" : "שתף"
        }
    }
    
    private func globalRailSystemIcon(_ item: KmiIconStripItem) -> String {
        switch item {
        case .home:
            return "house.fill"
        case .search:
            return "magnifyingglass"
        case .settings:
            return "gearshape.fill"
        case .stats:
            return "chart.bar.fill"
        case .assistant:
            return "lightbulb.fill"

        case .guide:
            return "questionmark.circle.fill"

        case .share:
            return "square.and.arrow.up.fill"
        }
    }
    
    private func globalRailIconTint(
        _ item: KmiIconStripItem
    ) -> Color {
        switch item {
        case .search:
            return Color(hex: 0xFF10B981)

        case .home:
            return Color(hex: 0xFF2563EB)

        case .settings:
            return Color(hex: 0xFFF59E0B)

        case .stats:
            return Color(hex: 0xFF0EA5E9)

        case .assistant:
            return Color(hex: 0xFF8B5CF6)

        case .guide:
            return Color(hex: 0xFF06B6D4)

        case .share:
            return Color(hex: 0xFFEC4899)
        }
    }
    
    private func isGlobalRailItemEnabled(
        _ item: KmiIconStripItem
    ) -> Bool {

        switch item {

        case .assistant:

            return
                !isInsideAssistant &&
                selectedIcon != .assistant

        case .settings,
             .stats,
             .guide:

            return selectedIcon != item

        case .search:

            return !lockSearch

        case .home:

            /*
             * כמו Android:
             * Home נשאר מוצג אבל נראה disabled
             * כאשר lockHome פעיל.
             */
            return !lockHome

        case .share:

            return true
        }
    }

    private func openContactUsEmail() {
        let email = "ypo1980@gmail.com"
        let subject = isEnglish ? "KMI App Contact" : "יצירת קשר מאפליקציית KMI"
        let body = isEnglish
        ? "\n\n---\nApp: KMI\niOS: \(UIDevice.current.systemVersion)"
        : "\n\n---\nאפליקציה: KMI\niOS: \(UIDevice.current.systemVersion)"

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let mailUrl = URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)"),
           UIApplication.shared.canOpenURL(mailUrl) {
            UIApplication.shared.open(mailUrl)
            return
        }

        if let gmailUrl = URL(string: "googlegmail://co?to=\(email)&subject=\(encodedSubject)&body=\(encodedBody)"),
           UIApplication.shared.canOpenURL(gmailUrl) {
            UIApplication.shared.open(gmailUrl)
            return
        }

        if let webUrl = URL(string: "https://mail.google.com/mail/?view=cm&fs=1&to=\(email)&su=\(encodedSubject)&body=\(encodedBody)") {
            UIApplication.shared.open(webUrl)
            return
        }

        UIPasteboard.general.string = email
    }

    private func openRateUs() {
        let defaults = UserDefaults.standard

        let appStoreId = (
            defaults.string(forKey: "app_store_id") ??
            defaults.string(forKey: "ios_app_store_id") ??
            ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        if !appStoreId.isEmpty,
           let reviewUrl = URL(string: "itms-apps://itunes.apple.com/app/id\(appStoreId)?action=write-review") {
            UIApplication.shared.open(reviewUrl)
            return
        }

        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) {
            SKStoreReviewController.requestReview(in: scene)
            return
        }

        if let fallbackUrl = URL(string: "itms-apps://itunes.apple.com") {
            UIApplication.shared.open(fallbackUrl)
        }
    }

    // MARK: - Global handler (אחד לכל האפליקציה)
    private func onGlobalIconTap(
        _ item: KmiIconStripItem
    ) {
        drawerOpen = false
        showGlobalIconMenu = false

        switch item {
        case .home:
            if lockHome {
                drawerActionErrorMessage =
                    homeDisabledMessage ??
                    (
                        isEnglish
                        ? "You are already on the home screen."
                        : "אתה כבר במסך הבית."
                    )
                return
            }

            showGlobalSearch = false
            showShareSheet = false
            selectedGlobalSearchHit = nil
            titleOverride = nil
            nav.popToRoot()

        case .search:
            guard !lockSearch else {
                return
            }

            showGlobalSearch = true

        case .settings:
            if selectedIcon != .settings {
                nav.push(.settings)
            }

        case .stats:
            if selectedIcon != .stats {
                nav.push(.progress)
            }

        case .assistant:
            guard !isInsideAssistant,
                  selectedIcon != .assistant else {
                return
            }

            nav.push(.voiceAssistant)

        case .guide:
            if selectedIcon != .guide {
                nav.push(
                    .onboarding(
                        manual: true
                    )
                )
            }

        case .share:
            performGlobalShare()
        }
    }

    private func performGlobalShare() {
        showGlobalIconMenu =
            false

        drawerOpen =
            false

        showGlobalSearch =
            false

        selectedGlobalSearchHit =
            nil
        
        if let onShare {
            onShare()
            return
        }

        let shareRequest =
            NSMutableDictionary(
                dictionary: [
                    "handled": false
                ]
            )

        NotificationCenter.default.post(
            name: Notification.Name(
                "KMI_GLOBAL_SHARE_REQUEST"
            ),
            object: shareRequest
        )

        if shareRequest["handled"] as? Bool == true {
            return
        }

        let localizedShareTitle =
            KmiGlobalText.screenTitle(
                effectiveTopBarTitle,
                isEnglish: isEnglish
            )

        shareItems =
            GlobalShareService
                .shareItemsForCurrentScreen(
                    extraText: localizedShareTitle
                )

        guard !shareItems.isEmpty else {
            drawerActionErrorMessage =
                isEnglish
                ? "There is no content available to share on this screen."
                : "אין במסך זה תוכן זמין לשיתוף."
            return
        }

        showShareSheet = true
    }
}
