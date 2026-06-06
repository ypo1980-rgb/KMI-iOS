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

    case myProfile
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
    let id = UUID()
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

    @EnvironmentObject private var auth: AuthViewModel

    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"

    @AppStorage("region") private var storedRegion: String = ""
    @AppStorage("branch") private var storedBranch: String = ""
    @AppStorage("active_branch") private var storedActiveBranch: String = ""

    @Binding var isOpen: Bool

    let onClose: () -> Void
    let onSelect: (KmiDrawerItem) -> Void

    @State private var showDemoVideos: Bool = false
    @State private var showFormsPayments: Bool = false
    @State private var showFormsList: Bool = false

    @State private var forumUnreadCount: Int = 0
    @State private var forumListener: ListenerRegistration? = nil

    private var isEnglish: Bool {
        let values = [
            kmiAppLanguageCode.lowercased(),
            appLanguageRaw.lowercased(),
            initialLanguageCode.lowercased()
        ]

        return values.contains("en") || values.contains("english")
    }

    private var closeIconName: String {
        "xmark"
    }

    private func titleSize(for item: KmiDrawerItem, isCoachButton: Bool) -> CGFloat {
        if isCoachButton {
            return 15
        }

        switch item.routeKey {
        case .aboutAvi, .aboutNetworkCoaches:
            return 14
        default:
            return 15
        }
    }

    private func titleWeight(for item: KmiDrawerItem, isCoachButton: Bool) -> Font.Weight {
        isCoachButton ? .heavy : .heavy
    }

    private func rowHorizontalPadding(isCoachButton: Bool) -> EdgeInsets {
        if isCoachButton {
            return EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        }

        if isEnglish {
            return EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 16)
        } else {
            return EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        }
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

        defaults.synchronize()
    }

    private func startForumUnreadListener() {
        forumListener?.remove()
        forumListener = nil
        forumUnreadCount = 0

        let branch = resolvedBranch.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !branch.isEmpty else {
            return
        }

        let lastReadMillis = UserDefaults.standard.double(forKey: forumLastReadKey(branch: branch))

        guard lastReadMillis > 0 else {
            return
        }

        let lastReadDate = Date(timeIntervalSince1970: lastReadMillis / 1000.0)
        let currentUid = Auth.auth().currentUser?.uid ?? ""

        forumListener = Firestore.firestore()
            .collection("branches")
            .document(branch)
            .collection("messages")
            .whereField("createdAt", isGreaterThan: Timestamp(date: lastReadDate))
            .order(by: "createdAt", descending: true)
            .limit(to: forumUnreadLimit)
            .addSnapshotListener { snapshot, error in
                if error != nil {
                    forumUnreadCount = 0
                    return
                }

                let unread = snapshot?.documents.filter { doc in
                    let authorUid = doc.get("authorUid") as? String
                    return authorUid == nil || authorUid?.isEmpty == true || authorUid != currentUid
                }.count ?? 0

                forumUnreadCount = unread
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

    private var effectiveRole: String {
        let defaults = UserDefaults.standard

        let profileRole = normalizeRole(auth.userRole)

        let storedCandidates = [
            defaults.string(forKey: "user_role"),
            defaults.string(forKey: "role"),
            defaults.string(forKey: "userRole"),
            defaults.string(forKey: "profile_role")
        ]
        .compactMap { $0 }
        .map { normalizeRole($0) }
        .filter { !$0.isEmpty }

        // חשוב: אם אחד המקורות אומר מאמן — נעדיף מאמן ולא ניתקע על trainee ישן.
        if isCoachRole(profileRole) {
            return profileRole
        }

        if let coachStoredRole = storedCandidates.first(where: { isCoachRole($0) }) {
            return coachStoredRole
        }

        if let firstStoredRole = storedCandidates.first {
            return firstStoredRole
        }

        return profileRole
    }

    private var isCoach: Bool {
        isCoachRole(effectiveRole)
    }

    private var isAdminUser: Bool {
        let email = Auth.auth().currentUser?.email?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        return email == "ypo1980@gmail.com"
    }

    private var coachItems: [KmiDrawerItem] {
        var items: [KmiDrawerItem] = []

        if isCoach {
            if !isAbroadUser {
                items.append(
                    .init(
                        routeKey: .attendance,
                        titleHe: "דו״ח נוכחות",
                        titleEn: "Attendance Report",
                        systemImage: "chart.bar.xaxis"
                    )
                )
            }

            items.append(contentsOf: [
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
            ])
        }

        return items
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
                subtitleHe: "צפייה בכל המשתמשים באפליקציה",
                subtitleEn: "View all app users",
                systemImage: "person.3.sequence.fill"
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
                routeKey: .aboutAvi,
                titleHe: "אודות אבי אביסידון",
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
                subtitleHe: "K.M.I",
                subtitleEn: "K.M.I",
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
                subtitleHe: "מעבר לאנגלית",
                subtitleEn: "Switch to Hebrew",
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
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.055, green: 0.086, blue: 0.188), // #0E1630
                        Color(red: 0.122, green: 0.165, blue: 0.322), // #1F2A52
                        Color(red: 0.145, green: 0.459, blue: 0.737)  // #2575BC
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 8) {
                    HStack {
                        Text(isEnglish ? "Menu" : "תפריט")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                        Spacer()

                        Button {
                            withAnimation(.easeOut(duration: 0.18)) {
                                isOpen = false
                            }
                        } label: {
                            Image(systemName: closeIconName)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(height: 48)
                    .padding(.horizontal, 18)
                    .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)

                ScrollView {
                    VStack(spacing: 14) {

                        if !coachItems.isEmpty {
                            coachAreaCard
                        }

                        if !adminItems.isEmpty {
                            adminAreaCard
                        }

                        traineeAreaCard

                        Text("© K.M.I")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color(red: 0.72, green: 0.77, blue: 0.85)) // #B8C4DA
                            .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
                            .padding(.horizontal, 18)
                            .padding(.top, 0)
                            .padding(.bottom, 8)
                    }
                    .padding(.horizontal, 0)
                    .padding(.top, 8)
                    .padding(.bottom, 18)
                }

                    Spacer(minLength: 0)
                }
                .padding(.top, 42)
            }
        }
        .onAppear {
            startForumUnreadListener()
        }
        .onDisappear {
            forumListener?.remove()
            forumListener = nil
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
        .sheet(isPresented: $showFormsPayments) {
            KmiFormsPaymentsSheet(
                isEnglish: isEnglish,
                onOpenForms: {
                    showFormsPayments = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        showFormsList = true
                    }
                },
                onOpenPayments: {
                    showFormsPayments = false
                    onClose()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                        AppNavModel.sharedInstance?.push(.membershipPayment)
                    }
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

    private func drawerSectionCard(
        titleHe: String,
        titleEn: String,
        items sectionItems: [KmiDrawerItem],
        colors: [Color],
        borderColor: Color,
        isCoachButton: Bool
    ) -> some View {
        VStack(spacing: 0) {
            Text(isEnglish ? titleEn : titleHe)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(
                    maxWidth: .infinity,
                    alignment: isEnglish ? .leading : .trailing
                )
                .multilineTextAlignment(isEnglish ? .leading : .trailing)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Rectangle()
                .fill(Color.white.opacity(0.16))
                .frame(height: 1)
                .padding(.horizontal, 16)
                .padding(.bottom, 2)

            ForEach(sectionItems) { it in
                drawerButton(it, isCoachButton: isCoachButton)
            }
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: colors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(borderColor.opacity(0.28), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 10)
    }

    private var coachAreaCard: some View {
        drawerSectionCard(
            titleHe: "אזור מאמן",
            titleEn: "Coach area",
            items: coachItems,
            colors: [
                Color(red: 0.118, green: 0.106, blue: 0.294).opacity(0.94), // #1E1B4B
                Color(red: 0.192, green: 0.180, blue: 0.506).opacity(0.82), // #312E81
                Color(red: 0.114, green: 0.306, blue: 0.847).opacity(0.42)  // #1D4ED8
            ],
            borderColor: Color(red: 1.0, green: 0.54, blue: 0.85),
            isCoachButton: true
        )
    }

    private var adminAreaCard: some View {
        drawerSectionCard(
            titleHe: "אזור מנהל",
            titleEn: "Admin area",
            items: adminItems,
            colors: [
                Color(red: 0.031, green: 0.322, blue: 0.255).opacity(0.94), // #085241
                Color(red: 0.047, green: 0.443, blue: 0.345).opacity(0.82), // #0C7158
                Color(red: 0.027, green: 0.624, blue: 0.420).opacity(0.34)  // #079F6B
            ],
            borderColor: Color(red: 0.251, green: 0.878, blue: 0.659),
            isCoachButton: false
        )
    }

    private var traineeAreaCard: some View {
        drawerSectionCard(
            titleHe: "אזור מתאמן",
            titleEn: "Trainee area",
            items: items,
            colors: [
                Color(red: 0.055, green: 0.180, blue: 0.345).opacity(0.96), // #0E2E58
                Color(red: 0.082, green: 0.294, blue: 0.525).opacity(0.84), // #154B86
                Color(red: 0.145, green: 0.459, blue: 0.737).opacity(0.48)  // #2575BC
            ],
            borderColor: Color(red: 0.310, green: 0.650, blue: 1.0),
            isCoachButton: false
        )
    }

    private func drawerButton(_ it: KmiDrawerItem, isCoachButton: Bool) -> some View {
        Button {

            switch it.routeKey {

            case .toggleLanguage:
                toggleLanguage()
                onClose()
                return

            case .demoVideos:
                showDemoVideos = true
                return

            case .formsPayments:
                showFormsPayments = true
                return

            case .attendance:
                guard !isAbroadUser else {
                    onClose()
                    return
                }

                onSelect(it)
                return

            case .myProfile:
                onClose()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                    AppNavModel.sharedInstance?.push(.editProfile)
                }
                return

            case .editProfile:
                onClose()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                    AppNavModel.sharedInstance?.push(.editProfile)
                }
                return

            case .logout:
                auth.signOut()
                onSelect(it)
                return

            default:
                onSelect(it)
                return
            }

        } label: {
            HStack(spacing: isCoachButton ? 10 : 8) {
                DrawerIconBubble(systemImage: it.systemImage, isCoachButton: isCoachButton)

                VStack(
                    alignment: isEnglish ? .leading : .trailing,
                    spacing: 2
                ) {
                    Text(it.title(isEnglish: isEnglish))
                        .font(.system(size: titleSize(for: it, isCoachButton: isCoachButton), weight: titleWeight(for: it, isCoachButton: isCoachButton)))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                        .tracking(it.routeKey == .aboutAvi || it.routeKey == .aboutNetworkCoaches ? -0.2 : 0)
                        .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
                        .multilineTextAlignment(isEnglish ? .leading : .trailing)

                    if let sub = it.subtitle(isEnglish: isEnglish), !sub.isEmpty {
                        Text(sub)
                            .font(.system(size: isCoachButton ? 11 : 12, weight: isCoachButton ? .medium : .semibold))
                            .foregroundStyle(.white.opacity(isCoachButton ? 0.82 : 0.72))
                            .lineLimit(2)
                            .minimumScaleFactor(0.86)
                            .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
                            .multilineTextAlignment(isEnglish ? .leading : .trailing)
                    }
                }

                if it.routeKey == .forum {
                    DrawerUnreadBadge(count: forumUnreadCount)
                }
            }
            .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
            .padding(rowHorizontalPadding(isCoachButton: isCoachButton))
            .padding(.vertical, isCoachButton ? 7 : 6)
            .frame(maxWidth: .infinity)
            .background(
                Rectangle()
                    .fill(Color.white.opacity(0.001))
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.white.opacity(isCoachButton ? 0.12 : 0.10))
                    .frame(height: 1)
                    .padding(.horizontal, isCoachButton ? 16 : 18)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Drawer Icon Bubble

private struct DrawerIconBubble: View {
    let systemImage: String
    let isCoachButton: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(isCoachButton ? 0.16 : 0.12))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isCoachButton ? 0.24 : 0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.16), radius: 2, x: 0, y: 1)

            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(isCoachButton ? Color(red: 1.0, green: 0.54, blue: 0.85) : .white)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: 30, height: 30)
    }
}

private struct DrawerUnreadBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .frame(minWidth: 24, minHeight: 24)
                .background(
                    Capsule()
                        .fill(Color(red: 0.145, green: 0.827, blue: 0.400)) // #25D366
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.55), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.22), radius: 4, x: 0, y: 2)
                )
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
            kmiAppLanguageCode.lowercased(),
            appLanguageRaw.lowercased(),
            initialLanguageCode.lowercased()
        ]

        return values.contains("en") || values.contains("english")
    }

    private var drawerAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var drawerTransitionEdge: Edge {
        isEnglish ? .leading : .trailing
    }

    var body: some View {
        GeometryReader { geo in
            let drawerWidth = min(geo.size.width * 0.82, 336)

            ZStack(alignment: drawerAlignment) {
                content
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
                    .simultaneousGesture(edgeOpenGesture(containerWidth: geo.size.width))
                    .disabled(isOpen)

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
                    .frame(width: drawerWidth)
                    .frame(maxHeight: .infinity)
                    .ignoresSafeArea()
                    .shadow(
                        color: Color.black.opacity(0.28),
                        radius: 18,
                        x: isEnglish ? 8 : -8,
                        y: 0
                    )
                    .transition(.move(edge: drawerTransitionEdge))
                    .zIndex(2)
                }
            }
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
        titleEn: "Internal Defense Against a Straight Kick",
        url: "https://www.youtube.com/watch?v=byPfByvdjQE",
        source: "YouTube"
    ),
    .init(
        id: "yt_v3wY85y1b7U",
        titleHe: "הגנה כנגד שיסוף",
        titleEn: "Defense Against a Slash",
        url: "https://www.youtube.com/shorts/v3wY85y1b7U",
        source: "YouTube"
    ),
    .init(
        id: "yt_psnF4X9g0L0",
        titleHe: "הגנה כנגד מקל – צד מת",
        titleEn: "Defense Against a Stick – Blind Side",
        url: "https://www.youtube.com/shorts/psnF4X9g0L0",
        source: "YouTube"
    ),
    .init(
        id: "yt_YXzJxtIeSRU",
        titleHe: "מספר תוקפים",
        titleEn: "Multiple Attackers",
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

        return kmiDemoVideos.filter {
            $0.title(isEnglish: isEnglish).localizedCaseInsensitiveContains(clean) ||
            $0.source.localizedCaseInsensitiveContains(clean)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.09, blue: 0.18)
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    TextField(
                        isEnglish ? "Search…" : "חיפוש…",
                        text: $query
                    )
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 16)
                    .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)

                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(filtered) { video in
                                Button {
                                    openUrl(video.url)
                                    onCloseDrawer()
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 34, height: 34)
                                            .background(Circle().fill(Color.white.opacity(0.14)))

                                        VStack(
                                            alignment: isEnglish ? .leading : .trailing,
                                            spacing: 4
                                        ) {
                                            Text(video.title(isEnglish: isEnglish))
                                                .font(.system(size: 16, weight: .heavy))
                                                .foregroundStyle(.white)
                                                .lineLimit(2)
                                                .multilineTextAlignment(isEnglish ? .leading : .trailing)

                                            Text(video.source)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(.white.opacity(0.68))
                                        }
                                        .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
                                    }
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color.white.opacity(0.10))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
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
            Color(red: 0.05, green: 0.09, blue: 0.18)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text(isEnglish ? "Forms & Payments" : "טפסים ותשלומים")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)

                drawerSheetCard(
                    title: isEnglish ? "Forms" : "טפסים",
                    subtitle: isEnglish
                        ? "Open the existing association registration form"
                        : "פתיחת טופס ההרשמה הקיים לעמותה",
                    onTap: onOpenForms
                )

                drawerSheetCard(
                    title: isEnglish ? "Payments" : "תשלומים",
                    subtitle: isEnglish
                        ? "Open the membership fee payment form"
                        : "פתיחת טופס תשלום דמי חבר לעמותה",
                    onTap: onOpenPayments
                )

                Spacer()
            }
            .padding(18)
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
    }

    private func drawerSheetCard(
        title: String,
        subtitle: String,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            VStack(
                alignment: isEnglish ? .leading : .trailing,
                spacing: 5
            ) {
                Text(title)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(isEnglish ? .leading : .trailing)
            }
            .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private struct DrawerIconBubble: View {
        let systemImage: String
        let isCoachButton: Bool
        
        var body: some View {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(isCoachButton ? 0.16 : 0.12))
                
                Circle()
                    .stroke(Color.white.opacity(isCoachButton ? 0.20 : 0.16), lineWidth: 1)
                
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 30, height: 30)
        }
    }
}

private struct KmiFormsListSheet: View {
    let isEnglish: Bool
    let onCloseDrawer: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.09, blue: 0.18)
                    .ignoresSafeArea()

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
        Button(action: {
            if enabled {
                onTap()
            }
        }) {
            VStack(
                alignment: isEnglish ? .leading : .trailing,
                spacing: 5
            ) {
                Text(title)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(enabled ? .white : .white.opacity(0.62))

                Text(subtitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(enabled ? .white.opacity(0.72) : .white.opacity(0.50))
                    .multilineTextAlignment(isEnglish ? .leading : .trailing)
            }
            .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(enabled ? 0.10 : 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(enabled ? 0.12 : 0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func openUrl(_ raw: String) {
        guard let url = URL(string: raw) else { return }
        UIApplication.shared.open(url)
    }
}
