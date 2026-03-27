import SwiftUI
import Shared
import Combine
import FirebaseAuth

// MARK: - Theme (סטייל בסיסי דומה לאנדרואיד)
private enum KmiTheme {
    static let bgTop = Color(red: 0.01, green: 0.05, blue: 0.14)     // כהה
    static let bgMid = Color(red: 0.07, green: 0.10, blue: 0.23)
    static let bgBot = Color(red: 0.11, green: 0.33, blue: 0.80)     // כחול
    static let card = Color.white.opacity(0.08)
    static let cardStroke = Color.white.opacity(0.12)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.75)
    static let accent = Color(red: 0.13, green: 0.83, blue: 0.93)    // טורקיז
}

private struct KmiBackground: View {

    @EnvironmentObject private var auth: AuthViewModel

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

    private var isCoach: Bool {
        effectiveRole == "coach" || effectiveRole == "trainer" || effectiveRole == "מאמן"
    }

    var body: some View {

        if isCoach {

            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.03, blue: 0.03),
                    Color(red: 0.22, green: 0.05, blue: 0.05),
                    Color(red: 0.42, green: 0.08, blue: 0.08),
                    Color(red: 0.62, green: 0.11, blue: 0.11)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

        } else {

            LinearGradient(
                colors: [KmiTheme.bgTop, KmiTheme.bgMid, KmiTheme.bgBot],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

        }
    }
}

private struct CoachModeBanner: View {

    @EnvironmentObject private var auth: AuthViewModel

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

    private var isCoach: Bool {
        effectiveRole == "coach" || effectiveRole == "trainer" || effectiveRole == "מאמן"
    }

    var body: some View {

        if isCoach {

            HStack(spacing: 8) {

                Image(systemName: "person.badge.shield.checkmark")
                    .font(.system(size: 14, weight: .bold))

                Text("מצב מאמן")
                    .font(.system(size: 14, weight: .bold))

                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.62, green: 0.11, blue: 0.11),
                        Color(red: 0.32, green: 0.06, blue: 0.06)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }
}

private struct KmiCard<Content: View>: View {
    let title: String?
    let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title, !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(KmiTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(KmiTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(KmiTheme.cardStroke, lineWidth: 1)
        )
    }
}

// MARK: - Router (מינימלי)
enum AppRoute: Hashable {
    case beltQuestionsByBelt(belt: Belt)
    case beltQuestionsByTopic(belt: Belt)
    case beltTopics(belt: Belt)

    case topicDetail(topic: CatalogData.Topic)
    case topicAcrossBelts(topicTitle: String, subTopicTitle: String?)

    case weakPoints(belt: Belt)
    case allLists(belt: Belt)
    case practice(belt: Belt, topicTitle: String)
    case summary(belt: Belt)
    case voiceAssistant
    case pdfExport(belt: Belt)

    case internalExam(belt: Belt)
    case beltFinalExam(belt: Belt)
    case attendance
    case coachTrainees
    case coachBroadcast
    case progress
    case trainingHistory
    case freeSessions(branch: String, groupKey: String, uid: String, name: String)

    case trainingSummary(pickedDateIso: String?)
    
    case aboutNetwork
    case aboutMethod
    case aboutItzik
    case aboutAvi
    case forum

    case settings
    case exercisesMarks(belt: Belt, topic: String, subTopic: String?)
    // ⭐️ Admin
    case adminUsers
}

final class AppNavModel: ObservableObject {

    static weak var sharedInstance: AppNavModel?

    @Published var path: [AppRoute] = [] {
        didSet {
            print("🧭 AppNavModel.path =", path)
        }
    }

    init() {
        AppNavModel.sharedInstance = self
    }

    func push(_ r: AppRoute) {
        print("🧭 PUSH request:", r)
        if path.last == r {
            print("🧭 PUSH skipped (same as last):", r)
            return
        }
        path.append(r)
        print("🧭 PUSH done:", r)
    }

    func pop() {
        print("🧭 POP request. current path =", path)
        guard !path.isEmpty else {
            print("🧭 POP skipped (empty path)")
            return
        }
        let removed = path.popLast()
        print("🧭 POP done. removed =", String(describing: removed), "new path =", path)
    }

    func popToRoot() {
        print("🧭 POP TO ROOT. old path =", path)
        path.removeAll()
        print("🧭 POP TO ROOT done. new path =", path)
    }
}

// MARK: - Root (After login only)
struct ContentView: View {

    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var nav = AppNavModel()

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

    private var isCoachUser: Bool {
        effectiveRole == "coach" || effectiveRole == "trainer" || effectiveRole == "מאמן"
    }

    private var isAdminUser: Bool {
        let email = Auth.auth().currentUser?.email?.lowercased() ?? ""
        return email == "ypo1980@gmail.com"
    }
    
    private var freeSessionsUid: String {
        Auth.auth().currentUser?.uid ?? "demo_ios"
    }

    private var freeSessionsName: String {
        let rawDisplayName =
            (Auth.auth().currentUser?.displayName ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !rawDisplayName.isEmpty { return rawDisplayName }

        let rawEmail =
            (Auth.auth().currentUser?.email ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !rawEmail.isEmpty { return rawEmail }

        return "משתמש"
    }

    private var freeSessionsBranch: String {
        let clean = auth.userBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "default_branch" : clean
    }

    private var freeSessionsGroupKey: String {
        let clean = auth.userGroup.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "default_group" : clean
    }

    var body: some View {
        DeviceGateRootView {
            NavigationStack(path: $nav.path) {

                KmiRootLayout(
                    title: "מסך הבית",
                    nav: nav,
                    selectedIcon: .home
                ) {
                    HomeView(nav: nav)
                }
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {

                    // ✅ Side Drawer destinations
                    case .aboutNetwork:
                        AboutNetworkView(onClose: { nav.pop() })
                            .navigationBarBackButtonHidden(true)
                            .toolbar(.hidden, for: .navigationBar)

                    case .trainingSummary(let pickedDateIso):
                        KmiRootLayout(title: "סיכום אימון", nav: nav, selectedIcon: .home) {
                            TrainingSummaryView(
                                ownerUid: Auth.auth().currentUser?.uid ?? "demo_ios",
                                isCoach: isCoachUser,
                                initialBelt: .green,
                                pickedDateIso: pickedDateIso,
                                initialBranchName: "",
                                initialCoachName: ""
                            )
                            .navigationBarBackButtonHidden(true)
                        }
                    
                    case .coachTrainees:
                        KmiRootLayout(title: "אודות מתאמנים", nav: nav, selectedIcon: .home) {
                            CoachTraineesView()
                                .navigationBarBackButtonHidden(true)
                        }
                  
                    case .coachBroadcast:
                        KmiRootLayout(title: "שליחת הודעה לקבוצה", nav: nav, selectedIcon: .home) {
                            CoachBroadcastView()
                                .navigationBarBackButtonHidden(true)
                        }
                        
                    case .aboutMethod:
                        AboutMethodView(onClose: { nav.pop() })
                            .navigationBarBackButtonHidden(true)
                            .toolbar(.hidden, for: .navigationBar)

                    case .aboutItzik:
                        AboutItzikBitonView(onClose: { nav.pop() })
                            .navigationBarBackButtonHidden(true)
                            .toolbar(.hidden, for: .navigationBar)

                    case .aboutAvi:
                        AboutAviAbisidonView(onClose: { nav.pop() })
                            .navigationBarBackButtonHidden(true)
                            .toolbar(.hidden, for: .navigationBar)

                    case .forum:
                        ForumView(onClose: { nav.pop() })
                            .navigationBarBackButtonHidden(true)
                            .toolbar(.hidden, for: .navigationBar)

                // ✅ תרגילים לפי חגורה
                case .beltQuestionsByBelt(let belt):
                    KmiRootLayout(title: "תרגילים לפי חגורה", nav: nav, selectedIcon: .home) {
                        BeltQuestionsByBeltView(belt: belt)
                            .navigationBarBackButtonHidden(true)
                    }

                    // ✅ תרגילים לפי נושא
                    case .beltQuestionsByTopic(let belt):
                        KmiRootLayout(title: "תרגילים לפי נושא", nav: nav, selectedIcon: .home) {
                            BeltQuestionsByTopicView(belt: belt)
                                .navigationBarBackButtonHidden(true)
                        }

                    // ✅ נושא חוצה חגורות
                    case .topicAcrossBelts(let topicTitle, let subTopicTitle):
                        KmiRootLayout(title: topicTitle, nav: nav, selectedIcon: .home) {
                            TopicAcrossBeltsView(
                                topicTitle: topicTitle,
                                subTopicTitle: subTopicTitle
                            )
                            .navigationBarBackButtonHidden(true)
                        }

                    case .progress:
                        KmiRootLayout(title: "התקדמות", nav: nav, selectedIcon: .home) {
                            ProgressScreenIOS()
                                .navigationBarBackButtonHidden(true)
                        }

                    case .trainingHistory:
                        KmiRootLayout(title: "היסטוריית אימונים", nav: nav, selectedIcon: .home) {
                            TrainingHistoryView()
                                .navigationBarBackButtonHidden(true)
                        }

                    case .freeSessions(let branch, let groupKey, let uid, let name):
                        KmiRootLayout(title: "אימונים חופשיים", nav: nav, selectedIcon: .home) {
                            FreeSessionsView(
                                branch: branch,
                                groupKey: groupKey,
                                currentUid: uid,
                                currentName: name
                            )
                            .navigationBarBackButtonHidden(true)
                        }
                        
                    // ✅ settings (אם קיים אצלך)
                    case .settings:
                        KmiRootLayout(title: "הגדרות", nav: nav, selectedIcon: .settings) {
                            SettingsView(nav: nav)
                                .navigationBarBackButtonHidden(true)
                        }
                     
                    case .weakPoints(let belt):
                        KmiRootLayout(title: "נקודות תורפה", nav: nav, selectedIcon: .home) {
                            FavoritesByBeltView(belt: belt)
                                .navigationBarBackButtonHidden(true)
                        }

                    case .allLists(let belt):
                        KmiRootLayout(title: "כל הרשימות", nav: nav, selectedIcon: .home) {
                            ExercisesTabsView(
                                belt: belt,
                                topicTitle: "__ALL__",
                                subTopicTitle: nil,
                                onPractice: { pickedBelt, topicTitle in
                                    nav.push(.practice(belt: pickedBelt, topicTitle: topicTitle))
                                },
                                onHome: {
                                    nav.popToRoot()
                                }
                            )
                            .navigationBarBackButtonHidden(true)
                        }

                    case .practice(let belt, let topicTitle):
                        KmiRootLayout(title: "תרגול", nav: nav, selectedIcon: .home) {
                            RandomPracticeView(
                                nav: nav,
                                belt: belt,
                                topicTitle: topicTitle,
                                items: {
                                    let cleanToken = topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)

                                    if cleanToken.isEmpty || cleanToken == "__ALL__" {
                                        let catalog = CatalogData.shared.data
                                        let topics = catalog[belt]?.topics ?? []

                                        var result: [String] = []
                                        for t in topics {
                                            result.append(contentsOf: t.items)
                                            for st in t.subTopics {
                                                result.append(contentsOf: st.items)
                                            }
                                        }
                                        return result
                                    }

                                    return ContentRepo.shared.getAllItemsFor(
                                        belt: belt,
                                        topicTitle: cleanToken,
                                        subTopicTitle: nil
                                    )
                                }()
                            )
                            .navigationBarBackButtonHidden(true)
                        }

                    case .summary(let belt):
                        KmiRootLayout(title: "מסך סיכום", nav: nav, selectedIcon: .home) {
                            SummaryView(belt: belt, nav: nav)
                                .navigationBarBackButtonHidden(true)
                        }

                    case .voiceAssistant:
                        KmiRootLayout(title: "עוזר קולי", nav: nav, selectedIcon: .home) {
                            VoiceAssistantView()
                                .navigationBarBackButtonHidden(true)
                        }

                    case .pdfExport(let belt):
                        KmiRootLayout(title: "PDF", nav: nav, selectedIcon: .home) {
                            PdfExportView(belt: belt)
                                .navigationBarBackButtonHidden(true)
                        }
                        
                    case .beltFinalExam(let belt):
                        KmiRootLayout(title: "מבחן מסכם", nav: nav, selectedIcon: .home) {
                            CoachPlaceholderView(
                                title: "מבחן מסכם",
                                subtitle: "חגורה: \(belt.heb)"
                            )
                            .navigationBarBackButtonHidden(true)
                        }

                    case .internalExam(let belt):
                        KmiRootLayout(title: "מבחן פנימי", nav: nav, selectedIcon: .home) {
                            InternalExamView(
                                belt: belt
                            )
                            .navigationBarBackButtonHidden(true)
                        }
                        
                    case .attendance:
                        KmiRootLayout(title: "דו״ח נוכחות", nav: nav, selectedIcon: .home) {
                            AttendanceView(
                                ownerUid: Auth.auth().currentUser?.uid ?? "demo_ios",
                                initialDateIso: nil,
                                initialBranchName: "",
                                initialGroupKey: "",
                                initialCoachName: ""
                            )
                            .navigationBarBackButtonHidden(true)
                        }
                        
                    case .adminUsers:
                        if isAdminUser {
                            KmiRootLayout(title: "ניהול משתמשים", nav: nav, selectedIcon: .home) {
                                AdminUsersView()
                                    .navigationBarBackButtonHidden(true)
                            }
                        } else {
                            KmiRootLayout(title: "אין הרשאה", nav: nav, selectedIcon: .home) {
                                VStack(spacing: 12) {
                                    Spacer()

                                    Text("אין הרשאה")
                                        .font(.system(size: 28, weight: .heavy))
                                        .foregroundStyle(.white)

                                    Text("המסך הזה פתוח רק למנהל האפליקציה")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.75))

                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(
                                    LinearGradient(
                                        colors: [KmiTheme.bgTop, KmiTheme.bgMid, KmiTheme.bgBot],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .ignoresSafeArea()
                                )
                                .navigationBarBackButtonHidden(true)
                            }
                        }
                        
                // ✅ fallback כדי שלא יהיה לבן
                default:
                    ZStack {
                        Color.white.ignoresSafeArea()
                        Text("Unhandled route: \(String(describing: route))")
                            .foregroundStyle(.black)
                            .padding()
                    }
                    }
                }
            }
            .environmentObject(nav)
        }
    }
}

// MARK: - (אופציונלי) Home UI דמו - נשאר אצלך בקובץ
private struct KmiHomeView: View {

    let onOpenBeltQuestionsByBelt: (Belt) -> Void
    let onOpenBeltQuestionsByTopic: () -> Void
    let onOpenBeltTopics: (Belt) -> Void
    let onOpenSettings: () -> Void

    private let belts: [Belt] = [
        Belt.white, Belt.yellow, Belt.orange, Belt.green, Belt.blue, Belt.brown, Belt.black
    ]

    private let catalog = CatalogData.shared.data

    var body: some View {
        ZStack {
            KmiBackground()

            ScrollView {
                VStack(spacing: 14) {

                    VStack(spacing: 6) {
                        Text("✅ iOS App is running")
                            .foregroundStyle(KmiTheme.textPrimary)
                            .font(.headline)

                        Text("Belts from Shared: \(belts.count)")
                            .foregroundStyle(KmiTheme.textSecondary)
                            .font(.footnote)
                    }
                    .padding(.top, 8)

                    KmiCard(title: "הגדרות") {
                        Button {
                            onOpenSettings()
                        } label: {
                            HStack {
                                Text("SettingsView")
                                    .foregroundStyle(KmiTheme.textPrimary)
                                    .font(.body.weight(.semibold))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(KmiTheme.textSecondary)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }

                    KmiCard(title: "נושאים (לפי נושא)") {
                        Button {
                            onOpenBeltQuestionsByTopic()
                        } label: {
                            HStack {
                                Text("BeltQuestionsByTopicView")
                                    .foregroundStyle(KmiTheme.textPrimary)
                                    .font(.body.weight(.semibold))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(KmiTheme.textSecondary)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }

                    KmiCard(title: "מסך חגורות (Android-like)") {
                        VStack(spacing: 10) {
                            ForEach(belts, id: \.self) { b in
                                Button {
                                    onOpenBeltQuestionsByBelt(b)
                                } label: {
                                    KmiBeltRow(
                                        title: b.heb,
                                        subtitle: "id: \(b.id)"
                                    )
                                }
                                .buttonStyle(.plain)

                                Divider()
                                    .overlay(Color.white.opacity(0.10))
                            }
                        }
                    }

                    KmiCard(title: "קטלוג – סיכום מהיר") {
                        VStack(spacing: 10) {
                            ForEach(belts, id: \.self) { b in
                                let topicsCount = catalog[b]?.topics.count ?? 0

                                Button {
                                    onOpenBeltTopics(b)
                                } label: {
                                    HStack {
                                        Text(b.heb)
                                            .foregroundStyle(KmiTheme.textPrimary)
                                        Spacer()
                                        Text("נושאים: \(topicsCount)")
                                            .font(.caption)
                                            .foregroundStyle(KmiTheme.textSecondary)
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(KmiTheme.textSecondary)
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)

                                Divider()
                                    .overlay(Color.white.opacity(0.10))
                            }
                        }
                    }

                    Spacer(minLength: 18)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 22)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("מסך הבית")
                    .font(.headline)
                    .foregroundStyle(KmiTheme.textPrimary)
            }
        }
    }
}

// MARK: - Belt Row UI (דומה לרשומת קומפוז)
private struct KmiBeltRow: View {
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(KmiTheme.accent.opacity(0.22))
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(KmiTheme.accent)
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(KmiTheme.textPrimary)
                    .font(.body.weight(.semibold))

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .foregroundStyle(KmiTheme.textSecondary)
                        .font(.caption)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(KmiTheme.textSecondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Belt Topics Screen (קטלוג)
struct BeltTopicsView: View {
    let belt: Belt
    let catalog: [Belt: CatalogData.BeltContent]

    var body: some View {
        let topics = catalog[belt]?.topics ?? []

        ZStack {
            KmiBackground()

            ScrollView {
                VStack(spacing: 14) {

                    KmiCard(title: "חגורה: \(belt.heb)") {
                        HStack {
                            Text("מספר נושאים: \(topics.count)")
                                .foregroundStyle(KmiTheme.textSecondary)
                                .font(.footnote)
                            Spacer()
                        }
                    }

                    ForEach(Array(topics.enumerated()), id: \.offset) { _, t in
                        NavigationLink {
                            TopicDetailView(topic: t)
                        } label: {
                            KmiCard {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(t.title)
                                        .foregroundStyle(KmiTheme.textPrimary)
                                        .font(.headline)

                                    Text("פריטים: \(t.items.count) • תתי-נושאים: \(t.subTopics.count)")
                                        .foregroundStyle(KmiTheme.textSecondary)
                                        .font(.caption)

                                    HStack {
                                        Spacer()
                                        Text("כניסה")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(KmiTheme.accent)
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(KmiTheme.accent)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 18)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 22)
            }
        }
        .navigationTitle(belt.heb)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Topic Detail Screen
struct TopicDetailView: View {
    let topic: CatalogData.Topic

    var body: some View {
        ZStack {
            KmiBackground()

            ScrollView {
                VStack(spacing: 14) {

                    KmiCard(title: topic.title) {
                        Text("פריטים: \(topic.items.count) • תתי-נושאים: \(topic.subTopics.count)")
                            .foregroundStyle(KmiTheme.textSecondary)
                            .font(.footnote)
                    }

                    if !topic.items.isEmpty {
                        KmiCard(title: "תרגילים") {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(topic.items.enumerated()), id: \.offset) { _, item in
                                    Text(item)
                                        .foregroundStyle(KmiTheme.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Divider().overlay(Color.white.opacity(0.10))
                                }
                            }
                        }
                    }

                    if !topic.subTopics.isEmpty {
                        ForEach(Array(topic.subTopics.enumerated()), id: \.offset) { _, sub in
                            KmiCard(title: sub.title) {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(Array(sub.items.enumerated()), id: \.offset) { _, s in
                                        Text("• \(s)")
                                            .foregroundStyle(KmiTheme.textPrimary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .opacity(0.95)
                                    }
                                }
                            }
                        }
                    }

                    Spacer(minLength: 18)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 22)
            }
        }
        .navigationTitle("נושא")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CoachPlaceholderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        ZStack {
            KmiBackground()

            VStack(spacing: 14) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(KmiTheme.accent)

                Text(title)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(KmiTheme.textPrimary)

                Text(subtitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(KmiTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(24)
        }
    }
}

#Preview {
    ContentView()
}
