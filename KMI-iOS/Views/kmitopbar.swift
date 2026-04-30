import SwiftUI
import FirebaseAuth
import Shared

// MARK: - Global TopBar (לא תלוי ב-HomeView)
struct KmiTopBar: View {
    let roleLabel: String
    let title: String
    let onMenu: () -> Void

    let rightText: String?

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
                if !roleLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(roleLabel)
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
                Text(title)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(titleColor)

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

                switch item.title {

                case "אימונים חופשיים":
                    nav.push(
                        .freeSessions(
                            branch: freeSessionsBranch,
                            groupKey: freeSessionsGroupKey,
                            uid: freeSessionsUid,
                            name: freeSessionsName
                        )
                    )

                case "דו״ח נוכחות":
                    nav.push(.attendance)

                case "מבחן פנימי לחגורה":
                    nav.push(.internalExam(belt: auth.registeredBelt ?? .green))

                case "שליחת הודעה":
                    nav.push(.coachBroadcast)

                case "רשימת מתאמנים":
                    nav.push(.coachTrainees)

                case "ניהול משתמשים":
                    nav.push(.adminUsers)

                case "ניהול מנוי":
                    print("🟣 SIDE_DRAWER -> subscription route")
                    nav.push(.subscription)
                    
                case "אודות הרשת":
                    nav.push(.aboutNetwork)

                case "אודות השיטה":
                    nav.push(.aboutMethod)

                case "אודות איציק ביטון":
                    nav.push(.aboutItzik)

                case "אודות אבי אביסידון":
                    nav.push(.aboutAvi)

                case "פורום הסניף":
                    nav.push(.forum)

                case "התנתקות":
                    auth.signOut()

                default:
                    break
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
            shareItems = GlobalShareService.shareItemsForCurrentScreen(extraText: title)
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
