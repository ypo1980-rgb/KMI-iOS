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
        let clean = raw
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "מצב", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if isEnglish {
            if clean.contains("מאמן") || clean.lowercased().contains("coach") {
                return "Coach"
            }

            if clean.contains("מנהל") || clean.lowercased().contains("admin") {
                return "Admin"
            }

            return "Trainee"
        } else {
            if clean.contains("מאמן") {
                return "מאמן"
            }

            if clean.contains("מנהל") {
                return "מנהל"
            }

            return "מתאמן"
        }
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

        let enToHe: [String: String] = [
            "Home": "בית",
            "Subscription Plans": "תוכניות מנוי",
            "Subscription": "ניהול מנוי",
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
            "Progress": "התקדמות",
            "Training History": "היסטוריית אימונים",
            "Free Sessions": "אימונים חופשיים",
            "Trainees": "אודות מתאמנים",
            "Group Message": "שליחת הודעה לקבוצה",
            "Settings": "הגדרות",
            "About the Network": "אודות הרשת",
            "About the Method": "אודות השיטה",
            "About Itzik Biton": "אודות איציק ביטון",
            "About Avi Abisidon": "אודות אבי אביסידון",
            "Branch Forum": "פורום הסניף",
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
                        .font(.system(size: 10.5, weight: .black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(red: 0.17, green: 0.12, blue: 0.35))
                        )
                } else {
                    Color.clear
                        .frame(width: 50, height: 32)
                }
            }
            .frame(width: 62, alignment: .leading)
            
            Spacer(minLength: 8)
            
            HStack(spacing: 8) {
                Text(localizedTitle)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                
                if let rightText, !rightText.isEmpty {
                    Text(rightText)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.70))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            Spacer(minLength: 8)
            
            Button(action: onMenu) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.55, green: 0.32, blue: 0.96),
                                    Color(red: 0.35, green: 0.24, blue: 0.78)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(.white)
                }
                .frame(width: 42, height: 42)
                .shadow(color: Color(red: 0.35, green: 0.24, blue: 0.78).opacity(0.28), radius: 7, x: 0, y: 4)
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .frame(width: 62, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 2)
        .frame(height: 68)
        .environment(\.layoutDirection, .leftToRight)
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
            break
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
    
    let title: String
    let roleLabel: String
    let content: Content
    let rightText: String?
    let titleColor: Color
    let onPickSearchResult: ((String) -> Void)?
    
    @ObservedObject var nav: AppNavModel
    let selectedIcon: KmiIconStripItem?

    @State private var drawerOpen: Bool = false
    @State private var showGlobalIconMenu: Bool = false

    // ✅ Global Search Sheet
    @State private var showGlobalSearch: Bool = false

    // ✅ Global Share Sheet
    @State private var showShareSheet: Bool = false
    @State private var shareItems: [Any] = []

    init(
        title: String,
        nav: AppNavModel,
        roleLabel: String = "מתאמן",
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

    private var globalRoleBadgeText: String {
        let r = effectiveRole.lowercased()

        if isEnglish {
            if r.contains("coach") || r.contains("trainer") || r.contains("מאמן") {
                return "Coach"
            }

            if r.contains("admin") || r.contains("מנהל") {
                return "Admin"
            }

            return "Trainee"
        } else {
            if r.contains("coach") || r.contains("trainer") || r.contains("מאמן") {
                return "מאמן"
            }

            if r.contains("admin") || r.contains("מנהל") {
                return "מנהל"
            }

            return "מתאמן"
        }
    }

    @ViewBuilder
    private var layoutBackground: some View {
        KmiGradientBackground(forceTraineeStyle: false)
    }
    
    var body: some View {
        KmiSideDrawerContainer(
            isOpen: $drawerOpen,
            onItem: { item in
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

                case .aboutAvi:
                    nav.push(.aboutAvi)

                case .aboutNetworkCoaches:
                    nav.push(.aboutNetworkCoaches)

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

                    KmiTopBar(
                        roleLabel: globalRoleBadgeText,
                        title: title,
                        rightText: rightText,
                        titleColor: titleColor,
                        onMenu: { drawerOpen = true }
                    )
                    .background(Color.white)
                    .overlay(
                        Rectangle()
                            .fill(Color.black.opacity(0.04))
                            .frame(height: 1),
                        alignment: .bottom
                    )
                    .overlay(
                        globalIconRailToggle,
                        alignment: .top
                    )
                    .zIndex(20)
                    
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }

                globalIconSideRailLayer
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

    private var globalIconRailToggle: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            globalIconRailToggleButton
        }
        .frame(maxWidth: .infinity)
        .frame(height: 30)
        .offset(y: 68)
        .environment(\.layoutDirection, .leftToRight)
    }

    private var globalIconRailToggleButton: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                showGlobalIconMenu.toggle()
            }
        } label: {
            ZStack {
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 18,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .fill(Color.white)

                Image(systemName: showGlobalIconMenu ? "chevron.up" : "chevron.down")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Color(red: 0.31, green: 0.27, blue: 0.78))
                    .offset(x: -7, y: -1)
            }
            .frame(width: 58, height: 30)
            .clipped()
            .contentShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 18,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
    }

    private var globalRailItems: [KmiIconStripItem] {
        [
            .search,
            .home,
            .settings,
            .assistant,
            .share
        ]
    }

    private var globalIconSideRailLayer: some View {
        ZStack {
            if showGlobalIconMenu {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            showGlobalIconMenu = false
                        }
                    }

                globalVerticalRailPanel
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .topTrailing
                    )
                    .padding(.top, 104)
                    .padding(.trailing, 0)
                    .environment(\.layoutDirection, .leftToRight)
                    .transition(
                        .opacity
                            .combined(with: .move(edge: .trailing))
                    )
                    .zIndex(40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.layoutDirection, .leftToRight)
    }

    private var globalVerticalRailPanel: some View {
        VStack(spacing: 6) {
            ForEach(globalRailItems, id: \.self) { item in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        showGlobalIconMenu = false
                    }

                    onGlobalIconTap(item)
                } label: {
                    globalRailIcon(item)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 5)
    }

    private func globalRailIcon(_ item: KmiIconStripItem) -> some View {
        let isSelected = selectedIcon == item

        return VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(
                        isSelected
                        ? Color(red: 0.31, green: 0.27, blue: 0.78).opacity(0.18)
                        : Color(red: 0.94, green: 0.95, blue: 0.98)
                    )

                Image(systemName: globalRailSystemIcon(item))
                    .font(.system(size: 16.5, weight: .black))
                    .foregroundStyle(
                        isSelected
                        ? Color(red: 0.31, green: 0.27, blue: 0.78)
                        : globalRailIconTint(item)
                    )
            }
            .frame(width: 34, height: 34)
            .overlay(
                Circle()
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )

            Text(globalRailTitle(item))
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Color(red: 0.12, green: 0.15, blue: 0.22))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(.center)
                .frame(width: 52)
        }
        .frame(width: 58, height: 52)
        .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private func globalRailTitle(_ item: KmiIconStripItem) -> String {
        switch item {
        case .search:
            return isEnglish ? "Search" : "חיפוש"
        case .home:
            return isEnglish ? "Home" : "בית"
        case .settings:
            return isEnglish ? "Settings" : "הגדרות"
        case .assistant:
            return isEnglish ? "Helper" : "עוזר"
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
        case .assistant:
            return "lightbulb.fill"
        case .share:
            return "square.and.arrow.up.fill"
        }
    }

    private func globalRailIconTint(_ item: KmiIconStripItem) -> Color {
        switch item {
        case .search:
            return Color(red: 0.05, green: 0.63, blue: 0.45)
        case .home:
            return Color(red: 0.29, green: 0.27, blue: 0.78)
        case .settings:
            return Color(red: 0.95, green: 0.57, blue: 0.06)
        case .assistant:
            return Color(red: 0.48, green: 0.36, blue: 0.88)
        case .share:
            return Color(red: 0.94, green: 0.22, blue: 0.58)
        }
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
