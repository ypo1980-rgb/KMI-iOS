import SwiftUI
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
        ZStack {
            Color.white.opacity(0.92)

            HStack(spacing: 10) {
                Text(roleLabel)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Color.black.opacity(0.75))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(red: 0.87, green: 0.80, blue: 0.98))
                    )

                Spacer()

                HStack(spacing: 10) {
                    Text(title)
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(titleColor)

                    if let rightText, !rightText.isEmpty {
                        Text(rightText)
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(Color.black.opacity(0.70))
                    }
                }

                Spacer()

                Button(action: onMenu) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.black.opacity(0.70))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(height: 60)
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
            return nil
        }
    }

    static func handleActionIfNeeded(_ item: KmiIconStripItem) {
        switch item {
        case .share:
            print("TODO: share")
        case .assistant:
            print("TODO: assistant")
        default:
            break
        }
    }
}

// MARK: - Root Layout
struct KmiRootLayout<Content: View>: View {

    let title: String
    let roleLabel: String
    let content: Content
    let rightText: String?
    let titleColor: Color
    
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
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.nav = nav
        self.roleLabel = roleLabel
        self.selectedIcon = selectedIcon
        self.rightText = rightText
        self.titleColor = titleColor
        self.content = content()
    }
    
    var body: some View {
        KmiSideDrawerContainer(isOpen: $drawerOpen, onItem: { item in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                switch item.title {

                case "אודות אבי אביסידון":
                    print("before push aboutAvi:", nav.path)
                    nav.push(.aboutAvi)
                    print("after push aboutAvi:", nav.path)

                case "אודות איציק ביטון":
                    print("before push aboutItzik:", nav.path)
                    nav.push(.aboutItzik)
                    print("after push aboutItzik:", nav.path)
                    
                case "אודות הרשת":
                    nav.push(.aboutNetwork)

                case "אודות השיטה":
                    nav.push(.aboutMethod)

                case "פורום הסניף":
                    nav.push(.forum)

                case "הגדרות":
                    nav.push(.settings)

                default:
                    break
                }
            }
        }) {
            VStack(spacing: 0) {

                KmiTopBar(
                    roleLabel: roleLabel,
                    title: title,
                    rightText: rightText,
                    titleColor: titleColor,
                    onMenu: { drawerOpen = true }
                )
                
                VStack(spacing: 0) {
                    KmiIconStripBar(
                        items: KmiIconStripItem.allCases,
                        selected: selectedIcon
                    ) { item in
                        onGlobalIconTap(item)
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 8)

                    Divider()
                        .opacity(0.18)
                }
                .background(Color.white.opacity(0.92))
                .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)

                content
            }
        }
        // ✅ Sheet של חיפוש גלובאלי
        .sheet(isPresented: $showGlobalSearch) {
            GlobalExerciseSearchSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        // ✅ Sheet של שיתוף (WhatsApp דרך Share Sheet)
        .sheet(isPresented: $showShareSheet) {
            KmiShareSheet(items: shareItems)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        
        // ✅ זה מוריד את החץ חזור מכל מסך שמשתמש ב-KmiRootLayout
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Global handler (אחד לכל האפליקציה)
    private func onGlobalIconTap(_ item: KmiIconStripItem) {

        // ✅ אם לוחצים על האייקון שכבר מסומן במסך הנוכחי — לא עושים כלום
        // (אבל: חיפוש/שיתוף תמיד צריכים לעבוד גם אם כבר "נבחרו")
        if item != .search, item != .share, let selectedIcon, selectedIcon == item {
            return
        }

        // ✅ HOME -> popToRoot
        if item == .home {
            nav.popToRoot()
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
