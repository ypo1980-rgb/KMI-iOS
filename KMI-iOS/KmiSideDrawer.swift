import SwiftUI
import FirebaseAuth

// MARK: - Drawer Item Model

enum KmiDrawerRouteKey: String {
    case freeSessions
    case attendance
    case internalExam
    case coachBroadcast
    case coachTrainees
    case adminUsers

    case aboutAvi
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

    let onClose: () -> Void
    let onSelect: (KmiDrawerItem) -> Void

    @State private var showDemoVideos: Bool = false
    @State private var showFormsPayments: Bool = false
    @State private var showFormsList: Bool = false

    private var isEnglish: Bool {
        let values = [
            kmiAppLanguageCode.lowercased(),
            appLanguageRaw.lowercased(),
            initialLanguageCode.lowercased()
        ]

        return values.contains("en") || values.contains("english")
    }

    private var drawerEdge: Edge {
        isEnglish ? .leading : .trailing
    }

    private var closeIconName: String {
        "xmark"
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

    private var effectiveRole: String {
        let loginRole = UserDefaults.standard.string(forKey: "user_role")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if let loginRole, !loginRole.isEmpty {
            print("DRAWER ROLE (from defaults) =", loginRole)
            return loginRole
        }

        let profileRole = auth.userRole
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        print("DRAWER ROLE (from profile) =", profileRole)
        return profileRole
    }

    private var isCoach: Bool {
        effectiveRole == "coach" || effectiveRole == "trainer" || effectiveRole == "מאמן"
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
            items.append(contentsOf: [
                .init(
                    routeKey: .attendance,
                    titleHe: "דו״ח נוכחות",
                    titleEn: "Attendance Report",
                    subtitleHe: nil,
                    subtitleEn: nil
                ),
                .init(
                    routeKey: .coachBroadcast,
                    titleHe: "שליחת הודעה",
                    titleEn: "Send Message",
                    subtitleHe: nil,
                    subtitleEn: nil
                ),
                .init(
                    routeKey: .coachTrainees,
                    titleHe: "רשימת מתאמנים",
                    titleEn: "Trainee List",
                    subtitleHe: nil,
                    subtitleEn: nil
                ),
                .init(
                    routeKey: .internalExam,
                    titleHe: "מבחן פנימי לחגורה",
                    titleEn: "Internal Belt Exam",
                    subtitleHe: nil,
                    subtitleEn: nil
                )
            ])
        }

        if isAdminUser {
            items.append(
                .init(
                    routeKey: .adminUsers,
                    titleHe: "ניהול משתמשים",
                    titleEn: "User Management",
                    subtitleHe: "צפייה בכל המשתמשים",
                    subtitleEn: "View all users"
                )
            )
        }

        return items
    }
    
    private var items: [KmiDrawerItem] {
        [
            .init(
                routeKey: .aboutAvi,
                titleHe: "אודות אבי אביסידון",
                titleEn: "About Avi Abisidon",
                subtitleHe: "ראש השיטה",
                subtitleEn: "Head of the method"
            ),
            .init(
                routeKey: .aboutMethod,
                titleHe: "אודות השיטה",
                titleEn: "About the Method",
                subtitleHe: "ק.מ.י",
                subtitleEn: "K.M.I"
            ),
            .init(
                routeKey: .demoVideos,
                titleHe: "תרגילים – הדגמה",
                titleEn: "Exercises – Demo",
                subtitleHe: "סרטוני הסבר קצרים לתרגילים",
                subtitleEn: "Short demo videos for exercises"
            ),
            .init(
                routeKey: .formsPayments,
                titleHe: "טפסים ותשלומים",
                titleEn: "Forms & Payments",
                subtitleHe: nil,
                subtitleEn: nil
            ),
            .init(
                routeKey: .contactUs,
                titleHe: "צור קשר",
                titleEn: "Contact Us",
                subtitleHe: "השאירו פרטים ונחזור אליכם",
                subtitleEn: "Leave details and we will get back to you"
            ),
            .init(
                routeKey: .forum,
                titleHe: "פורום הסניף",
                titleEn: "Branch Forum",
                subtitleHe: nil,
                subtitleEn: nil
            ),
            .init(
                routeKey: .editProfile,
                titleHe: "עריכת פרופיל",
                titleEn: "Edit Profile",
                subtitleHe: "עדכון פרטים אישיים",
                subtitleEn: "Update your personal details"
            ),
            .init(
                routeKey: .subscription,
                titleHe: "ניהול מנוי",
                titleEn: "Subscription",
                subtitleHe: nil,
                subtitleEn: nil
            ),
            .init(
                routeKey: .rateUs,
                titleHe: "⭐ דרגו אותנו ⭐",
                titleEn: "⭐ Rate Us ⭐",
                subtitleHe: nil,
                subtitleEn: nil
            ),
            .init(
                routeKey: .toggleLanguage,
                titleHe: "Language / שפה",
                titleEn: "Language / שפה",
                subtitleHe: "מעבר לאנגלית",
                subtitleEn: "Switch to Hebrew"
            ),
            .init(
                routeKey: .logout,
                titleHe: "התנתקות",
                titleEn: "Logout",
                subtitleHe: nil,
                subtitleEn: nil
            )
        ]
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.09, blue: 0.20),
                    Color(red: 0.06, green: 0.16, blue: 0.34)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    if isEnglish {
                        Text("Menu")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Spacer()

                        Button(action: onClose) {
                            Image(systemName: closeIconName)
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundStyle(.white.opacity(0.95))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: onClose) {
                            Image(systemName: closeIconName)
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundStyle(.white.opacity(0.95))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Text("תפריט")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.top, 10)
                .padding(.horizontal, 18)

                ScrollView {
                    VStack(spacing: 12) {

                        if !coachItems.isEmpty {
                            ForEach(coachItems) { it in
                                drawerButton(it, isCoachButton: true)
                            }

                            Divider()
                                .overlay(Color.white.opacity(0.22))
                                .padding(.top, 6)
                                .padding(.bottom, 10)
                        }

                        ForEach(items) { it in
                            drawerButton(it, isCoachButton: false)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 18)
                }

                Spacer(minLength: 0)
            }
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

            case .logout:
                auth.signOut()
                onSelect(it)
                return

            default:
                onSelect(it)
                return
            }

        } label: {
            VStack(
                alignment: isEnglish ? .leading : .trailing,
                spacing: 4
            ) {
                Text(it.title(isEnglish: isEnglish))
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
                    .multilineTextAlignment(isEnglish ? .leading : .trailing)

                if let sub = it.subtitle(isEnglish: isEnglish), !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
                        .multilineTextAlignment(isEnglish ? .leading : .trailing)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        isCoachButton
                        ? Color(red: 0.92, green: 0.44, blue: 0.70)
                        : Color.white.opacity(0.10)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isCoachButton
                        ? Color.white.opacity(0.00)
                        : Color.white.opacity(0.10),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
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
            let drawerWidth = min(geo.size.width * 0.82, 320)

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
                        onClose: {
                            withAnimation(.easeOut(duration: 0.18)) {
                                isOpen = false
                            }
                        },
                        onSelect: { item in
                            withAnimation(.easeOut(duration: 0.18)) {
                                isOpen = false
                            }
                            onItem(item)
                        }
                    )
                    .frame(width: drawerWidth)
                    .transition(.move(edge: drawerTransitionEdge))
                    .zIndex(2)
                }
            }
            .animation(.easeOut(duration: 0.18), value: isOpen)
        }
    }

    private func edgeOpenGesture(containerWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .onEnded { value in
                if isEnglish {
                    if !isOpen, value.startLocation.x < 18, value.translation.width > 60 {
                        isOpen = true
                    }

                    if isOpen, value.translation.width < -60 {
                        isOpen = false
                    }
                } else {
                    if !isOpen, value.startLocation.x > containerWidth - 18, value.translation.width < -60 {
                        isOpen = true
                    }

                    if isOpen, value.translation.width > 60 {
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
