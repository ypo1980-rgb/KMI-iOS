import SwiftUI
import FirebaseAuth
import FirebaseFirestore

private let forumUnreadLimit: Int = 100

private func forumLastReadKey(branch: String) -> String {
    "forum_last_read_at_\(branch.trimmingCharacters(in: .whitespacesAndNewlines))"
}

// MARK: - Drawer Item Model

enum KmiDrawerRouteKey: String {
    case freeSessions
    case attendance
    case internalExam
    case coachBroadcast
    case coachTrainees
    case coachPaymentsReport
    case adminUsers
    case controlCenterLogs

    case myProfile
    case monthlyTrainingBoard
    case trainingSummary
    case aboutAvi
    case aboutNetworkCoaches
    case aboutMethod
    case demoVideos
    case formsPayments
    case contactUs
    case forum
    case editProfile
    case subscription
    case rateUs

    case toggleLanguage

    case logout
}

struct KmiDrawerItem: Identifiable {
    var id: KmiDrawerRouteKey { routeKey }

    let routeKey: KmiDrawerRouteKey
    let titleHe: String
    let titleEn: String
    let subtitleHe: String?
    let subtitleEn: String?
    let systemImage: String

    init(
        routeKey: KmiDrawerRouteKey,
        titleHe: String,
        titleEn: String,
        subtitleHe: String? = nil,
        subtitleEn: String? = nil,
        systemImage: String
    ) {
        self.routeKey = routeKey
        self.titleHe = titleHe
        self.titleEn = titleEn
        self.subtitleHe = subtitleHe
        self.subtitleEn = subtitleEn
        self.systemImage = systemImage
    }

    func title(isEnglish: Bool) -> String {
        isEnglish ? titleEn : titleHe
    }

    func subtitle(isEnglish: Bool) -> String? {
        isEnglish ? subtitleEn : subtitleHe
    }
}

// MARK: - Drawer UI

struct KmiSideDrawer: View {

    @Environment(\.colorScheme) private var colorScheme

    @EnvironmentObject private var auth: AuthViewModel

    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"

    @AppStorage("region") private var storedRegion: String = ""
    @AppStorage("branch") private var storedBranch: String = ""
    @AppStorage("active_branch") private var storedActiveBranch: String = ""
    @AppStorage("user_role") private var storedActiveUserRole: String = ""

    @Binding var isOpen: Bool

    let onClose: () -> Void
    let onSelect: (KmiDrawerItem) -> Void

    @State private var showDemoVideos: Bool = false
    @State private var showFormsPayments: Bool = false
    @State private var showFormsList: Bool = false
    @State private var openFormsListAfterDismiss = false
    @State private var openPaymentAfterDismiss = false

    @State private var forumUnreadCount: Int = 0
    @State private var forumListener: ListenerRegistration? = nil
    @State private var forumListenerRequestID = UUID()

    @State private var verifiedAdminUID: String?

    private var isEnglish: Bool {
        let values = [
            kmiAppLanguageCode,
            appLanguageRaw,
            initialLanguageCode
        ]

        for rawValue in values {
            let value = rawValue
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            switch value {
            case "en", "english":
                return true

            case "he", "hebrew", "עברית":
                return false

            default:
                continue
            }
        }

        return false
    }

    private var resolvedRegion: String {
        let authRegion = auth.userRegion
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !authRegion.isEmpty {
            return authRegion
        }

        return storedRegion
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resolvedBranch: String {
        let authBranch = auth.userBranch
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !authBranch.isEmpty {
            return authBranch
        }

        let active = storedActiveBranch
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !active.isEmpty {
            return active
        }

        return storedBranch
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isAbroadUser: Bool {
        TrainingCatalogIOS.isAbroadRegion(resolvedRegion) ||
        TrainingCatalogIOS.isAbroadBranch(resolvedBranch)
    }

    private func toggleLanguage() {
        let defaults = UserDefaults.standard

        if isEnglish {
            defaults.set("he", forKey: "kmi_app_language")
            defaults.set("HEBREW", forKey: "app_language")
            defaults.set("HEBREW", forKey: "initial_language_code")
            defaults.set("he", forKey: "selected_language_code")
        } else {
            defaults.set("en", forKey: "kmi_app_language")
            defaults.set("ENGLISH", forKey: "app_language")
            defaults.set("ENGLISH", forKey: "initial_language_code")
            defaults.set("en", forKey: "selected_language_code")
        }
    }

    private func stopForumUnreadListener() {
        forumListenerRequestID = UUID()
        forumListener?.remove()
        forumListener = nil
        forumUnreadCount = 0
    }

    private func startForumUnreadListener() {
        stopForumUnreadListener()

        let branch = resolvedBranch.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard isOpen,
              !branch.isEmpty,
              let currentUid = Auth.auth().currentUser?.uid,
              !currentUid.isEmpty else {
            return
        }

        let lastReadMillis = UserDefaults.standard.double(
            forKey: forumLastReadKey(branch: branch)
        )

        guard lastReadMillis.isFinite,
              lastReadMillis > 0 else {
            return
        }

        let requestID = UUID()
        forumListenerRequestID = requestID

        let lastReadDate = Date(
            timeIntervalSince1970: lastReadMillis / 1000
        )

        forumListener = Firestore.firestore()
            .collection("branches")
            .document(branch)
            .collection("messages")
            .whereField(
                "createdAt",
                isGreaterThan: Timestamp(date: lastReadDate)
            )
            .order(by: "createdAt", descending: true)
            .limit(to: forumUnreadLimit)
            .addSnapshotListener { snapshot, error in
                let documents = error == nil ? (snapshot?.documents ?? []) : []
                let unread = documents.filter { document in
                    let authorUid = (
                        document.get("authorUid") as? String ?? ""
                    )
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    return authorUid.isEmpty || authorUid != currentUid
                }.count

                Task { @MainActor in
                    guard forumListenerRequestID == requestID,
                          isOpen,
                          Auth.auth().currentUser?.uid == currentUid,
                          resolvedBranch.trimmingCharacters(
                            in: .whitespacesAndNewlines
                          ) == branch else {
                        return
                    }

                    forumUnreadCount = unread
                }
            }
    }

    private func normalizeRole(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func isCoachRole(_ value: String) -> Bool {
        let role = normalizeRole(value)

        return role == "coach" ||
               role == "trainer" ||
               role == "instructor" ||
               role == "מאמן" ||
               role == "coach_user" ||
               role == "kmi_coach"
    }

    private var isCoachMode: Bool {
        let storedRole = normalizeRole(storedActiveUserRole)
        let activeRole = storedRole.isEmpty
            ? normalizeRole(auth.userRole)
            : storedRole

        return isCoachRole(activeRole)
    }

    private var showsCoachArea: Bool {
        isCoachMode && (isCoachRole(auth.userRole) || isAdminUser)
    }

    private var isAdminUser: Bool {
        guard auth.isSignedIn,
              let currentUID = Auth.auth().currentUser?.uid else {
            return false
        }

        return verifiedAdminUID == currentUID
    }

    private var adminCheckUID: String? {
        guard isOpen, auth.isSignedIn else {
            return nil
        }

        return Auth.auth().currentUser?.uid
    }

    private var coachItems: [KmiDrawerItem] {
        guard showsCoachArea else {
            return []
        }

        return [
            .init(
                routeKey: .attendance,
                titleHe: "עדכון נוכחות",
                titleEn: "Mark Attendance",
                systemImage: "chart.bar.xaxis"
            ),
            .init(
                routeKey: .coachBroadcast,
                titleHe: "שליחת הודעה",
                titleEn: "Send Message",
                systemImage: "megaphone.fill"
            ),
            .init(
                routeKey: .coachTrainees,
                titleHe: "רשימת מתאמנים",
                titleEn: "Trainees List",
                systemImage: "person.3.fill"
            ),
            .init(
                routeKey: .coachPaymentsReport,
                titleHe: "דו״ח תשלומים",
                titleEn: "Payments Report",
                systemImage: "chart.bar.xaxis"
            ),
            .init(
                routeKey: .internalExam,
                titleHe: "מבחן פנימי לחגורה",
                titleEn: "Internal Belt Exam",
                systemImage: "rosette"
            )
        ]
    }
    
    private var adminItems: [KmiDrawerItem] {
        guard isAdminUser else {
            return []
        }

        return [
            .init(
                routeKey: .adminUsers,
                titleHe: "ניהול משתמשים",
                titleEn: "Manage Users",
                subtitleHe: "צפייה במתאמנים ובמאמנים הרשומים באפליקציה",
                subtitleEn: "View all app users",
                systemImage: "person.3.fill"
            ),
            .init(
                routeKey: .controlCenterLogs,
                titleHe: "מרכז בקרה ולוגים",
                titleEn: "Control Center & Logs",
                subtitleHe: "ניתוח פעילות, תקלות ושימוש באפליקציה",
                subtitleEn: "Activity, errors and app diagnostics",
                systemImage: "chart.bar.doc.horizontal"
            )
        ]
    }
    
    private var items: [KmiDrawerItem] {
        [
            .init(
                routeKey: .myProfile,
                titleHe: "הפרופיל שלי",
                titleEn: "My Profile",
                subtitleHe: "צפייה בפרטים האישיים שלך",
                subtitleEn: "View your personal K.M.I details",
                systemImage: "person.fill"
            ),
            .init(
                routeKey: .monthlyTrainingBoard,
                titleHe: "לוח אימונים חודשי",
                titleEn: "Monthly Calendar",
                subtitleHe: "אימונים, חגים וסיכומים",
                subtitleEn: "Trainings, holidays and summaries",
                systemImage: "calendar"
            ),
            .init(
                routeKey: .aboutAvi,
                titleHe: "אודות אבי אביסדון",
                titleEn: "About Avi Avisidon",
                subtitleHe: "ראש השיטה",
                subtitleEn: "Head of the method",
                systemImage: "person.fill"
            ),
            .init(
                routeKey: .aboutNetworkCoaches,
                titleHe: "אודות המאמנים ברשת",
                titleEn: "About Network Coaches",
                subtitleHe: "דרגות, ותק, הכשרות והסמכות",
                subtitleEn: "Ranks, experience and certifications",
                systemImage: "person.3.fill"
            ),
            .init(
                routeKey: .aboutMethod,
                titleHe: "אודות השיטה",
                titleEn: "About the Method",
                subtitleHe: "KAMI",
                subtitleEn: "KAMI",
                systemImage: "rosette"
            ),
            .init(
                routeKey: .demoVideos,
                titleHe: "תרגילים – הדגמה",
                titleEn: "Exercises – Demo",
                subtitleHe: "סרטוני הסבר קצרים לתרגילים",
                subtitleEn: "Short demo videos for exercises",
                systemImage: "play.fill"
            ),
            .init(
                routeKey: .formsPayments,
                titleHe: "טפסים ותשלומים",
                titleEn: "Forms & Payments",
                systemImage: "chart.bar.doc.horizontal"
            ),
            .init(
                routeKey: .trainingSummary,
                titleHe: "סיכום אימון",
                titleEn: "Training Summary",
                subtitleHe: "הוספה או צפייה בסיכום אימון",
                subtitleEn: "Add or view a training summary",
                systemImage: "doc.text"
            ),
            .init(
                routeKey: .contactUs,
                titleHe: "צור קשר",
                titleEn: "Contact Us",
                subtitleHe: "השאירו פרטים ונחזור אליכם",
                subtitleEn: "Leave details and we will get back to you",
                systemImage: "megaphone.fill"
            ),
            .init(
                routeKey: .forum,
                titleHe: "פורום הסניף",
                titleEn: "Branch Forum",
                systemImage: "person.3.fill"
            ),
            .init(
                routeKey: .toggleLanguage,
                titleHe: "שפה / Language",
                titleEn: "Language / שפה",
                systemImage: "globe"
            ),
            .init(
                routeKey: .subscription,
                titleHe: "ניהול מנוי",
                titleEn: "Manage Subscription",
                systemImage: "rosette"
            ),
            .init(
                routeKey: .rateUs,
                titleHe: "⭐ דרגו אותנו ⭐",
                titleEn: "⭐ Rate Us ⭐",
                systemImage: "rosette"
            ),
            .init(
                routeKey: .logout,
                titleHe: "התנתקות",
                titleEn: "Logout",
                systemImage: "rectangle.arrowtriangle.2.outward"
            )
        ]
    }
    
    var body: some View {
        GeometryReader { _ in
            ZStack {
                KmiAppTheme.drawerBackgroundBrush(for: colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 8) {
                    KmiDrawerHeader(
                        title: isEnglish ? "Menu" : "תפריט",
                        subtitle: isEnglish
                            ? "Quick app navigation"
                            : "ניווט מהיר באפליקציה",
                        closeAccessibilityLabel: isEnglish ? "Close menu" : "סגור תפריט",
                        onClose: onClose
                    )

                    ScrollView {
                        VStack(spacing: 14) {

                            if !coachItems.isEmpty {
                                coachAreaCard
                            }

                            if !adminItems.isEmpty {
                                adminAreaCard
                            }

                            traineeAreaCard
                            informationAreaCard
                            systemAreaCard
                            Text("© KAMI")
                                .kmiFont(
                                    size: 12,
                                    weight: .regular
                                )
                                .foregroundStyle(
                                    KmiAppTheme.onBackground(for: colorScheme)
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)
                                .padding(.horizontal, 18)
                                .padding(.bottom, 8)
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                    .id([isEnglish, showsCoachArea, isAdminUser])
                }
            }
        }
        .task(id: adminCheckUID) {
            verifiedAdminUID = nil

            guard let requestedUID = adminCheckUID else {
                return
            }

            let authorized =
                await AdminAccessService.isCurrentUserAdmin()

            guard !Task.isCancelled,
                  isOpen,
                  auth.isSignedIn,
                  Auth.auth().currentUser?.uid == requestedUID else {
                return
            }

            verifiedAdminUID = authorized
                ? requestedUID
                : nil
        }
        .onAppear {
            startForumUnreadListener()
        }
        .onChange(of: resolvedBranch) { _, _ in
            startForumUnreadListener()
        }
        .onChange(of: auth.isSignedIn) { _, _ in
            startForumUnreadListener()
        }
        .onChange(of: isOpen) { _, newValue in
            if newValue {
                startForumUnreadListener()
            } else {
                stopForumUnreadListener()
            }
        }
        .onDisappear {
            stopForumUnreadListener()
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
        .sheet(isPresented: $showDemoVideos) {
            KmiDemoVideosSheet(
                isEnglish: isEnglish,
                onCloseDrawer: onClose
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(
            isPresented: $showFormsPayments,
            onDismiss: {
                let shouldOpenForms = openFormsListAfterDismiss
                let shouldOpenPayment = openPaymentAfterDismiss

                openFormsListAfterDismiss = false
                openPaymentAfterDismiss = false

                guard isOpen else {
                    return
                }

                if shouldOpenPayment {
                    AppNavModel.sharedInstance?.push(.membershipPayment)
                    onClose()
                } else if shouldOpenForms {
                    showFormsList = true
                }
            }
        ) {
            KmiFormsPaymentsSheet(
                isEnglish: isEnglish,
                onOpenForms: {
                    openPaymentAfterDismiss = false
                    openFormsListAfterDismiss = true
                    showFormsPayments = false
                },
                onOpenPayments: {
                    openFormsListAfterDismiss = false
                    openPaymentAfterDismiss = true
                    showFormsPayments = false
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFormsList) {
            KmiFormsListSheet(
                isEnglish: isEnglish,
                onCloseDrawer: onClose
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var coachAreaCard: some View {
        drawerAreaCard(
            title: isEnglish ? "Coach area" : "אזור מאמן",
            role: .coach,
            sectionItems: coachItems
        )
    }

    private var adminAreaCard: some View {
        drawerAreaCard(
            title: isEnglish ? "Admin area" : "אזור מנהל",
            role: .manager,
            sectionItems: adminItems
        )
    }

    private var traineeAreaCard: some View {
        drawerStandardAreaCard(
            title: isEnglish ? "Trainee area" : "אזור מתאמן",
            routes: [
                .myProfile,
                .monthlyTrainingBoard,
                .trainingSummary,
                .formsPayments,
                .forum,
                .subscription
            ]
        )
    }

    private var informationAreaCard: some View {
        drawerStandardAreaCard(
            title: isEnglish ? "Information" : "מידע",
            routes: [.aboutAvi, .aboutNetworkCoaches, .aboutMethod, .demoVideos]
        )
    }

    private var systemAreaCard: some View {
        drawerStandardAreaCard(
            title: isEnglish ? "System" : "מערכת",
            routes: [.contactUs, .toggleLanguage, .rateUs, .logout]
        )
    }

    private func drawerStandardAreaCard(
        title: String,
        routes: [KmiDrawerRouteKey]
    ) -> some View {
        let availableItems = items
        let sectionItems = routes.compactMap { route in
            availableItems.first { $0.routeKey == route }
        }

        return drawerAreaCard(
            title: title,
            role: .trainee,
            sectionItems: sectionItems
        )
    }

    private func drawerAreaCard(
        title: String,
        role: KmiAppTheme.DrawerRole,
        sectionItems: [KmiDrawerItem]
    ) -> some View {
        let colors = KmiAppTheme.drawerRoleColors(for: role)

        return KmiDrawerSectionCard(title: title, colors: colors) {
            ForEach(sectionItems) { item in
                KmiDrawerActionRow(
                    title: item.title(isEnglish: isEnglish),
                    subtitle: item.subtitle(isEnglish: isEnglish),
                    systemImage: item.systemImage,
                    colors: colors,
                    isCompact: role == .coach,
                    unreadCount: item.routeKey == .forum ? forumUnreadCount : 0,
                    action: { selectDrawerItem(item) }
                )
            }
        }
    }

    private func selectDrawerItem(_ item: KmiDrawerItem) {
        switch item.routeKey {
        case .toggleLanguage:
            toggleLanguage()
            onClose()

        case .demoVideos:
            showDemoVideos = true

        case .formsPayments:
            showFormsPayments = true

        case .attendance where isAbroadUser:
            onClose()

        default:
            onSelect(item)
        }
    }
}

// MARK: - Container (wrap any screen)

struct KmiSideDrawerContainer<Content: View>: View {

    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"

    @Binding var isOpen: Bool
    let content: Content
    let onItem: (KmiDrawerItem) -> Void

    init(
        isOpen: Binding<Bool>,
        onItem: @escaping (KmiDrawerItem) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self._isOpen = isOpen
        self.onItem = onItem
        self.content = content()
    }

    private var isEnglish: Bool {
        let values = [
            kmiAppLanguageCode,
            appLanguageRaw,
            initialLanguageCode
        ]

        for rawValue in values {
            let value = rawValue
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            switch value {
            case "en", "english":
                return true

            case "he", "hebrew", "עברית":
                return false

            default:
                continue
            }
        }

        return false
    }

    private var drawerTransitionEdge: Edge {
        isEnglish ? .leading : .trailing
    }

    var body: some View {
        GeometryReader { geo in
            let drawerWidth = min(geo.size.width * 0.78, 320)

            ZStack {
                content
                    .disabled(isOpen)
                    .overlay {
                        if isOpen {
                            Color.black.opacity(0.25)
                                .ignoresSafeArea()
                                .contentShape(Rectangle())
                                .zIndex(1)
                                .onTapGesture {
                                    withAnimation(.easeOut(duration: 0.18)) {
                                        isOpen = false
                                    }
                                }
                        }
                    }
                    .simultaneousGesture(
                        edgeOpenGesture(containerWidth: geo.size.width)
                    )

                if isOpen {
                    KmiSideDrawer(
                        isOpen: $isOpen,
                        onClose: {
                            withAnimation(.easeOut(duration: 0.18)) {
                                isOpen = false
                            }
                        },
                        onSelect: { item in
                            withAnimation(.easeOut(duration: 0.18)) {
                                isOpen = false
                            }

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                                onItem(item)
                            }
                        }
                    )
                    .frame(width: drawerWidth, height: geo.size.height)
                    .shadow(
                        color: Color.black.opacity(0.28),
                        radius: 18,
                        x: -8,
                        y: 0
                    )
                    .offset(
                        x: (geo.size.width - drawerWidth) / 2 *
                            (isEnglish ? -1 : 1)
                    )
                    .transition(
                        .move(edge: drawerTransitionEdge)
                    )
                    .zIndex(2)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .environment(\.layoutDirection, .leftToRight)
            .animation(.easeOut(duration: 0.18), value: isOpen)
        }
    }
    
    private func edgeOpenGesture(containerWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 16, coordinateSpace: .local)
            .onEnded { value in
                let edgeHitWidth: CGFloat = 28
                let openDistance: CGFloat = 54
                let closeDistance: CGFloat = 54

                if isEnglish {
                    if !isOpen,
                       value.startLocation.x <= edgeHitWidth,
                       value.translation.width > openDistance {
                        isOpen = true
                    }

                    if isOpen,
                       value.translation.width < -closeDistance {
                        isOpen = false
                    }
                } else {
                    if !isOpen,
                       value.startLocation.x >= containerWidth - edgeHitWidth,
                       value.translation.width < -openDistance {
                        isOpen = true
                    }

                    if isOpen,
                       value.translation.width > closeDistance {
                        isOpen = false
                    }
                }
            }
    }
}

// MARK: - Drawer Internal Sheets

private struct KmiDemoVideo: Identifiable {
    let id: String
    let titleHe: String
    let titleEn: String
    let url: String
    let source: String

    func title(isEnglish: Bool) -> String {
        isEnglish ? titleEn : titleHe
    }
}

private let kmiDemoVideos: [KmiDemoVideo] = [
    .init(
        id: "yt_byPfByvdjQE",
        titleHe: "הגנה פנימית נגד בעיטה ישרה",
        titleEn: "Inside defense against a straight kick",
        url: "https://www.youtube.com/watch?v=byPfByvdjQE",
        source: "YouTube"
    ),
    .init(
        id: "yt_v3wY85y1b7U",
        titleHe: "הגנה כנגד שיסוף",
        titleEn: "Defense against a slash attack",
        url: "https://www.youtube.com/shorts/v3wY85y1b7U",
        source: "YouTube"
    ),
    .init(
        id: "yt_psnF4X9g0L0",
        titleHe: "הגנה כנגד מקל – צד מת",
        titleEn: "Defense against a stick attack – dead side",
        url: "https://www.youtube.com/shorts/psnF4X9g0L0",
        source: "YouTube"
    ),
    .init(
        id: "yt_YXzJxtIeSRU",
        titleHe: "מספר תוקפים",
        titleEn: "Multiple attackers",
        url: "https://www.youtube.com/shorts/YXzJxtIeSRU",
        source: "YouTube"
    )
]

private struct KmiDemoVideosSheet: View {
    let isEnglish: Bool
    let onCloseDrawer: () -> Void

    @State private var query: String = ""

    private var filtered: [KmiDemoVideo] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            return kmiDemoVideos
        }
        return kmiDemoVideos.filter { video in
            video.titleHe.localizedCaseInsensitiveContains(clean) ||
            video.titleEn.localizedCaseInsensitiveContains(clean) ||
            video.source.localizedCaseInsensitiveContains(clean)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KmiDrawerSheetBackground()

                VStack(spacing: 14) {
                    KmiDrawerSheetSearchField(
                        prompt: isEnglish ? "Search…" : "חיפוש…",
                        query: $query
                    )
                    .padding(.horizontal, 16)

                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(filtered) { video in
                                KmiDrawerSheetAction(
                                    title: video.title(isEnglish: isEnglish),
                                    subtitle: video.source,
                                    systemImage: "play.fill"
                                ) {
                                    openUrl(video.url)
                                    onCloseDrawer()
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
                .padding(.top, 16)
            }
            .navigationTitle(isEnglish ? "Exercises – Demo" : "תרגילים – הדגמה")
            .navigationBarTitleDisplayMode(.inline)
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
    }

    private func openUrl(_ raw: String) {
        guard let url = URL(string: raw) else { return }
        UIApplication.shared.open(url)
    }
}

    private struct KmiFormsPaymentsSheet: View {
        let isEnglish: Bool
        let onOpenForms: () -> Void
        let onOpenPayments: () -> Void

        var body: some View {
            ZStack {
                KmiDrawerSheetBackground()

                ScrollView {
                    VStack(spacing: 14) {
                        KmiDrawerSheetTitle(
                            title: isEnglish ? "Forms & Payments" : "טפסים ותשלומים"
                        )

                        KmiDrawerSheetActionGroup {
                            KmiDrawerSheetAction(
                                title: isEnglish ? "Forms" : "טפסים",
                                subtitle: isEnglish
                                    ? "Open the existing association registration form"
                                    : "פתיחת טופס ההרשמה הקיים לעמותה",
                                onGranite: true,
                                action: onOpenForms
                            )

                            KmiDrawerSheetAction(
                                title: isEnglish ? "Payments" : "תשלומים",
                                subtitle: isEnglish
                                    ? "Open the membership fee payment form"
                                    : "פתיחת טופס תשלום דמי חבר לעמותה",
                                onGranite: true,
                                action: onOpenPayments
                            )
                        }
                    }
                    .padding(18)
                }
            }
            .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
        }
    }


    private struct KmiFormsListSheet: View {
        let isEnglish: Bool
        let onCloseDrawer: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                KmiDrawerSheetBackground()

                ScrollView {
                    VStack(spacing: 12) {
                        formCard(
                            title: isEnglish ? "Association Registration Form" : "טופס רישום לעמותה",
                            subtitle: isEnglish
                                ? "Open the existing association registration form"
                                : "פתיחת טופס הרישום הקיים לעמותה",
                            enabled: true,
                            onTap: {
                                openUrl("https://10nokout.com/files/Kami-Register.pdf")
                                onCloseDrawer()
                            }
                        )

                        formCard(
                            title: isEnglish ? "Health Declaration" : "הצהרת בריאות",
                            subtitle: isEnglish ? "This form will be added here soon" : "טופס יוצג כאן בהמשך",
                            enabled: false,
                            onTap: {}
                        )

                        formCard(
                            title: isEnglish ? "Parental Consent" : "אישור הורים",
                            subtitle: isEnglish ? "This form will be added here soon" : "טופס יוצג כאן בהמשך",
                            enabled: false,
                            onTap: {}
                        )

                        formCard(
                            title: isEnglish ? "Waiver Form" : "כתב ויתור",
                            subtitle: isEnglish ? "This form will be added here soon" : "טופס יוצג כאן בהמשך",
                            enabled: false,
                            onTap: {}
                        )

                        formCard(
                            title: isEnglish ? "Membership Renewal Form" : "טופס חידוש חברות",
                            subtitle: isEnglish ? "This form will be added here soon" : "טופס יוצג כאן בהמשך",
                            enabled: false,
                            onTap: {}
                        )
                    }
                    .padding(16)
                }
            }
            .navigationTitle(isEnglish ? "Forms" : "טפסים")
            .navigationBarTitleDisplayMode(.inline)
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
    }

        private func formCard(
            title: String,
            subtitle: String,
            enabled: Bool,
            onTap: @escaping () -> Void
        ) -> some View {
            KmiDrawerSheetAction(
                title: title,
                subtitle: subtitle,
                isEnabled: enabled,
                action: onTap
            )
        }

    private func openUrl(_ raw: String) {
        guard let url = URL(string: raw) else { return }
        UIApplication.shared.open(url)
    }
}
