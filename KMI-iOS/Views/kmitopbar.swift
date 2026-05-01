import SwiftUI
import FirebaseAuth
import Shared

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

    static func roleLabel(_ raw: String, isEnglish: Bool) -> String {
        guard isEnglish else { return raw }

        let clean = raw
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if clean.contains("מאמן") {
            return "Coach\nMode"
        }

        if clean.contains("מנהל") {
            return "Admin\nMode"
        }

        return "Trainee\nMode"
    }

    static func screenTitle(_ raw: String, isEnglish: Bool) -> String {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isEnglish else { return clean }

        let map: [String: String] = [
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
            "התקדמות": "Progress",
            "היסטוריית אימונים": "Training History",
            "אימונים חופשיים": "Free Sessions",
            "אודות מתאמנים": "Trainees",
            "שליחת הודעה לקבוצה": "Group Message",
            "ניהול מנוי": "Subscription",
            "תוכניות מנוי": "Subscription Plans",
            "הגדרות": "Settings",
            "אודות הרשת": "About the Network",
            "אודות השיטה": "About the Method",
            "אודות איציק ביטון": "About Itzik Biton",
            "אודות אבי אביסידון": "About Avi Abisidon",
            "פורום הסניף": "Branch Forum",
            "אין הרשאה": "No Permission"
        ]

        if let translated = map[clean] {
            return translated
        }

        return KmiEnglishTitleResolver.title(for: clean, isEnglish: true)
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
    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"
    @AppStorage("selected_language_code") private var selectedLanguageCode: String = "he"

    let roleLabel: String
    let title: String
    let onMenu: () -> Void

    let rightText: String?

    private var isEnglish: Bool {
        let values = [
            kmiAppLanguageCode.lowercased(),
            appLanguageRaw.lowercased(),
            initialLanguageCode.lowercased(),
            selectedLanguageCode.lowercased()
        ]

        return values.contains("en") || values.contains("english")
    }

    private var localizedTitle: String {
        KmiGlobalText.screenTitle(title, isEnglish: isEnglish)
    }

    private var localizedRoleLabel: String {
        KmiGlobalText.roleLabel(roleLabel, isEnglish: isEnglish)
    }

    // ✅ NEW
    let titleColor: Color

    init(
        roleLabel: String,
        title: String,
        rightText: String? = nil,
        titleColor: Color = Color.black.opacity(0.85),
        onMenu: @escaping () -> Void
    ) {
        self.roleLabel = roleLabel
        self.title = title
        self.rightText = rightText
        self.titleColor = titleColor
        self.onMenu = onMenu
    }

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if !localizedRoleLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(localizedRoleLabel)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Color.black.opacity(0.75))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(red: 0.87, green: 0.80, blue: 0.98))
                        )
                } else {
                    Color.clear
                        .frame(width: 44, height: 44)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                Text(localizedTitle)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                if let rightText, !rightText.isEmpty {
                    Text(rightText)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.70))
                }
            }

            Spacer()

            Button(action: onMenu) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 21, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.74))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 2)
        .frame(height: 68)
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
    }
}

// MARK: - Global Icon Navigation (אייקון -> Route אחד לכל האפליקציה)
private enum KmiIconNav {

    /// מחזיר Route אם זה מסך ניווט, או nil אם זה פעולה / Sheet (Share/Search/Assistant וכו')
    static func route(for item: KmiIconStripItem) -> AppRoute? {
        switch item {
        case .home:
            // ✅ HomeView: חוזרים לשורש
            return nil

        case .settings:
            return .settings

        case .search:
            // ✅ חיפוש גלובאלי הוא Sheet, לא Route
            return nil

        case .share:
            return nil

        case .assistant:
            return .voiceAssistant
        }
    }

    static func handleActionIfNeeded(_ item: KmiIconStripItem) {
        switch item {
        case .share:
            print("TODO: share")
        case .assistant:
            break
        default:
            break
        }
    }
}

// MARK: - Root Layout
struct KmiRootLayout<Content: View>: View {
    @EnvironmentObject private var auth: AuthViewModel

    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"
    @AppStorage("selected_language_code") private var selectedLanguageCode: String = "he"

    private var isEnglish: Bool {
        let values = [
            kmiAppLanguageCode.lowercased(),
            appLanguageRaw.lowercased(),
            initialLanguageCode.lowercased(),
            selectedLanguageCode.lowercased()
        ]

        return values.contains("en") || values.contains("english")
    }
    
    let title: String
    let roleLabel: String
    let content: Content
    let rightText: String?
    let titleColor: Color
    let onPickSearchResult: ((String) -> Void)?
    
    @ObservedObject var nav: AppNavModel
    let selectedIcon: KmiIconStripItem?

    @State private var drawerOpen: Bool = false

    // ✅ Global Search Sheet
    @State private var showGlobalSearch: Bool = false

    // ✅ Global Share Sheet
    @State private var showShareSheet: Bool = false
    @State private var shareItems: [Any] = []

    init(
        title: String,
        nav: AppNavModel,
        roleLabel: String = "מצב\nמתאמן",
        selectedIcon: KmiIconStripItem? = nil,
        rightText: String? = nil,
        titleColor: Color = Color.black.opacity(0.85),
        onPickSearchResult: ((String) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.nav = nav
        self.roleLabel = roleLabel
        self.selectedIcon = selectedIcon
        self.rightText = rightText
        self.titleColor = titleColor
        self.onPickSearchResult = onPickSearchResult
        self.content = content()
    }
  
    private var effectiveRole: String {
        let loginRole = UserDefaults.standard.string(forKey: "user_role")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if let loginRole, !loginRole.isEmpty {
            return loginRole
        }

        return auth.userRole
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private var isCoachTheme: Bool {
        let r = effectiveRole.lowercased()
        return r.contains("coach") || r.contains("trainer") || r.contains("מאמן")
    }

    @ViewBuilder
    private var layoutBackground: some View {
        KmiGradientBackground(forceTraineeStyle: false)
    }
    
    var body: some View {
        let _ = print(
            "KMI_THEME role=\(effectiveRole) isCoachTheme=\(isCoachTheme)"
        )

        KmiSideDrawerContainer(
            isOpen: $drawerOpen,
            onItem: { item in
                print("🟣 SIDE_DRAWER tapped title =", item.title)

                let freeSessionsUid =
                    Auth.auth().currentUser?.uid ?? "demo_ios"

                let freeSessionsName: String = {
                    let rawDisplayName =
                        (Auth.auth().currentUser?.displayName ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if !rawDisplayName.isEmpty { return rawDisplayName }

                    let rawEmail =
                        (Auth.auth().currentUser?.email ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if !rawEmail.isEmpty { return rawEmail }

                    return "משתמש"
                }()

                let freeSessionsBranch: String = {
                    let clean = auth.userBranch.trimmingCharacters(in: .whitespacesAndNewlines)
                    return clean.isEmpty ? "default_branch" : clean
                }()

                let freeSessionsGroupKey: String = {
                    let clean = auth.userGroup.trimmingCharacters(in: .whitespacesAndNewlines)
                    return clean.isEmpty ? "default_group" : clean
                }()

                switch item.routeKey {

                case .freeSessions:
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
                    nav.push(.internalExam(belt: auth.registeredBelt ?? .green))

                case .coachBroadcast:
                    nav.push(.coachBroadcast)

                case .coachTrainees:
                    nav.push(.coachTrainees)

                case .adminUsers:
                    nav.push(.adminUsers)

                case .aboutAvi:
                    nav.push(.aboutAvi)

                case .aboutMethod:
                    nav.push(.aboutMethod)

                case .demoVideos:
                    break

                case .formsPayments:
                    break

                case .contactUs:
                    break

                case .forum:
                    nav.push(.forum)

                case .editProfile:
                    break

                case .subscription:
                    print("🟣 SIDE_DRAWER -> subscription route")
                    nav.push(.subscription)

                case .rateUs:
                    break

                case .toggleLanguage:
                    break

                case .logout:
                    auth.signOut()
                }
            }
        ) {
            ZStack {
                layoutBackground

                VStack(spacing: 0) {

                    VStack(spacing: 0) {
                        KmiTopBar(
                            roleLabel: roleLabel,
                            title: title,
                            rightText: rightText,
                            titleColor: titleColor,
                            onMenu: { drawerOpen = true }
                        )
                        .background(Color.white)

                        HStack {
                            Spacer()

                            KmiIconStripBar(
                                items: KmiIconStripItem.allCases,
                                selected: selectedIcon
                            ) { item in
                                onGlobalIconTap(item)
                            }
                            .frame(width: 330)

                            Spacer()
                        }
                        .padding(.top, 0)
                        .padding(.bottom, 4)
                        .background(Color.white)
                    }
                    .padding(.bottom, 12)
                    .overlay(
                        Rectangle()
                            .fill(Color.black.opacity(0.04))
                            .frame(height: 1),
                        alignment: .bottom
                    )
                    
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
        }
        
        // ✅ Sheet של חיפוש גלובאלי
        .sheet(isPresented: $showGlobalSearch) {
            GlobalExerciseSearchSheet_Legacy { hit in

                let key = "\(hit.belt.id)|\(hit.topic)|\(hit.displayTitle)"

                onPickSearchResult?(key)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }

        // ✅ Sheet של שיתוף (WhatsApp דרך Share Sheet)
        .sheet(isPresented: $showShareSheet) {
            KmiShareSheet(items: shareItems)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
    }

    // MARK: - Global handler (אחד לכל האפליקציה)
    private func onGlobalIconTap(_ item: KmiIconStripItem) {

        // ✅ HOME תמיד חייב לעבוד, גם אם הוא כבר מסומן
        if item == .home {
            nav.popToRoot()
            return
        }

        // ✅ אם לוחצים על האייקון שכבר מסומן במסך הנוכחי — לא עושים כלום
        // (אבל: חיפוש/שיתוף תמיד צריכים לעבוד גם אם כבר "נבחרו")
        if item != .search, item != .share, let selectedIcon, selectedIcon == item {
            return
        }

        // ✅ SEARCH -> open sheet
        if item == .search {
            showGlobalSearch = true
            return
        }

        // ✅ SHARE -> open share sheet with screenshot
        if item == .share {
            let shareTitle = KmiGlobalText.screenTitle(title, isEnglish: isEnglish)
            shareItems = GlobalShareService.shareItemsForCurrentScreen(extraText: shareTitle)
            showShareSheet = true
            return
        }

        // ✅ אם יש route -> navigate
        if let r = KmiIconNav.route(for: item) {
            nav.push(r)
            return
        }

        // ✅ אחרת זו פעולה (assistant וכו')
        KmiIconNav.handleActionIfNeeded(item)
    }
}
