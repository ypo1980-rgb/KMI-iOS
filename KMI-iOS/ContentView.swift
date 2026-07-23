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

    case subjectAcrossBelts(
        subjectId: String,
        subjectTitle: String
    )

    case topicAcrossBelts(
        topicTitle: String,
        subTopicTitle: String?
    )

    case weakPoints(belt: Belt)
    case allLists(belt: Belt)
    case practice(belt: Belt, topicTitle: String)
    case summary(belt: Belt)
    case voiceAssistant
    case onboarding(manual: Bool)

    case internalExam(belt: Belt)
    case beltFinalExam(belt: Belt)
    case attendance
    case coachTrainees
    case coachBroadcast
    case progress
    case trainingHistory
    case freeSessions(
        branch: String,
        groupKey: String,
        uid: String,
        name: String
    )

    case monthlyTrainingBoard
    case trainingSummary(
        pickedDateIso: String?
    )
    
    case aboutNetwork
    case aboutMethod
    case aboutItzik
    case aboutAvi
    case aboutNetworkCoaches
    case forum
    case myProfile
    case editProfile

    case subscription
    case subscriptionPlans

    // ✅ Payments
    case membershipPayment
    case membershipCheckout(formData: MembershipPaymentFormData)
    case paymentsReport

    case settings
    case contactUs
    case exercisesMarks(belt: Belt, topic: String, subTopic: String?)

    // ⭐️ Admin
    case adminUsers
    case controlCenterLogs
}

final class AppNavModel: ObservableObject {

    static weak var sharedInstance: AppNavModel?

    @Published var path: [AppRoute] = []

    init() {
        AppNavModel.sharedInstance = self
    }

    func push(_ r: AppRoute) {
        if path.last == r {
            return
        }

        path.append(r)
    }

    func pop() {
        guard !path.isEmpty else {
            return
        }

        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }
}

// MARK: - Root (After login only)
struct ContentView: View {

    @EnvironmentObject private var auth: AuthViewModel

    @StateObject private var nav =
        AppNavModel()

    @StateObject private var voiceCommands =
        VoiceCommandsCoordinator.shared

    @State private var didEvaluateOnboarding =
        false

    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"

    private var isEnglish: Bool {
        let values = [
            kmiAppLanguageCode.lowercased(),
            appLanguageRaw.lowercased(),
            initialLanguageCode.lowercased()
        ]

        return values.contains("en") || values.contains("english")
    }

    private func beltTitleForUi(_ belt: Belt) -> String {
        switch belt {
        case .white:
            return tr("חגורה לבנה", "White Belt")
        case .yellow:
            return tr("חגורה צהובה", "Yellow Belt")
        case .orange:
            return tr("חגורה כתומה", "Orange Belt")
        case .green:
            return tr("חגורה ירוקה", "Green Belt")
        case .blue:
            return tr("חגורה כחולה", "Blue Belt")
        case .brown:
            return tr("חגורה חומה", "Brown Belt")
        case .black:
            return tr("חגורה שחורה", "Black Belt")
        default:
            return tr("חגורה", "Belt")
        }
    }
    
    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
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

    private var isCoachUser: Bool {
        isCoachRole(effectiveRole)
    }

    private var isAdminUser: Bool {
        let email = Auth.auth().currentUser?.email?.lowercased() ?? ""
        return email == "ypo1980@gmail.com"
    }

    private var membershipPaymentPrefill: MembershipPaymentPrefill {
        let defaults = UserDefaults.standard
        let firebaseUser = Auth.auth().currentUser

        let displayName = (firebaseUser?.displayName ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let storedFullName = (defaults.string(forKey: "fullName") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let authFullName = auth.userFullName
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedFullName: String = {
            if !authFullName.isEmpty { return authFullName }
            if !storedFullName.isEmpty { return storedFullName }
            if !displayName.isEmpty { return displayName }
            return ""
        }()

        let splitName = splitFullNameForPayment(resolvedFullName)

        let email = (firebaseUser?.email ?? defaults.string(forKey: "email") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let phone = firstExistingDefaultValue([
            "phone",
            "phoneNumber",
            "mobilePhone",
            "user_phone",
            "traineePhone"
        ])

        let idNumber = firstExistingDefaultValue([
            "idNumber",
            "id_number",
            "traineeIdNumber",
            "tz",
            "user_id_number"
        ])

        let birthDate = firstExistingDefaultValue([
            "birthDate",
            "birth_date",
            "traineeBirthDate",
            "dateOfBirth",
            "dob"
        ])

        let authBranch = auth.userBranch
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let storedActiveBranch = (defaults.string(forKey: "active_branch") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let storedBranch = (defaults.string(forKey: "branch") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedBranch: String = {
            if !authBranch.isEmpty { return authBranch }
            if !storedActiveBranch.isEmpty { return storedActiveBranch }
            if !storedBranch.isEmpty { return storedBranch }
            return ""
        }()

        return MembershipPaymentPrefill(
            traineeFirstName: splitName.firstName,
            traineeLastName: splitName.lastName,
            traineeIdNumber: idNumber,
            traineeBirthDate: birthDate,
            traineeEmail: email,
            traineePhone: phone,
            traineeBranch: resolvedBranch,
            traineeOtherBranch: "",
            payerFirstName: splitName.firstName,
            payerLastName: splitName.lastName,
            payerEmail: email,
            payerPhone: phone
        )
    }

    private func firstExistingDefaultValue(_ keys: [String]) -> String {
        for key in keys {
            let value = (UserDefaults.standard.string(forKey: key) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !value.isEmpty {
                return value
            }
        }

        return ""
    }

    private func splitFullNameForPayment(_ fullName: String) -> (firstName: String, lastName: String) {
        let parts = fullName
            .split(separator: " ")
            .map(String.init)

        guard !parts.isEmpty else {
            return ("", "")
        }

        if parts.count == 1 {
            return (parts[0], "")
        }

        let firstName = parts.first ?? ""
        let lastName = parts.dropFirst().joined(separator: " ")

        return (firstName, lastName)
    }

    private func beltFromVoiceQuery(
        _ query: String
    ) -> Belt? {
        let clean =
            query
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()
                .replacingOccurrences(
                    of: "חגורה",
                    with: ""
                )
                .replacingOccurrences(
                    of: "belt",
                    with: ""
                )
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        switch clean {
        case "לבנה", "לבן", "white":
            return .white

        case "צהובה", "צהוב", "yellow":
            return .yellow

        case "כתומה", "כתום", "orange":
            return .orange

        case "ירוקה", "ירוק", "green":
            return .green

        case "כחולה", "כחול", "blue":
            return .blue

        case "חומה", "חום", "brown":
            return .brown

        case "שחורה", "שחור", "black":
            return .black

        default:
            return nil
        }
    }

    private func normalizedVoiceTopic(
        _ value: String
    ) -> String {
        var clean =
            value
                .replacingOccurrences(of: "\u{200F}", with: "")
                .replacingOccurrences(of: "\u{200E}", with: "")
                .replacingOccurrences(of: "\u{00A0}", with: " ")
                .lowercased()

        let commandWords = [
            "תפתח לי",
            "פתח לי",
            "תראה לי",
            "הראה לי",
            "הצג לי",
            "תפתח",
            "פתח",
            "תראה",
            "הראה",
            "הצג",
            "עבור אל",
            "עבור ל",
            "לך אל",
            "לך ל",
            "נושא",
            "תרגילים בנושא",
            "תרגילים של",
            "open",
            "show me",
            "show",
            "go to",
            "topic",
            "exercises"
        ]

        for commandWord in commandWords {
            clean = clean.replacingOccurrences(
                of: commandWord,
                with: " "
            )
        }

        clean = clean.replacingOccurrences(
            of: #"[\u{0591}-\u{05C7}]"#,
            with: "",
            options: .regularExpression
        )

        clean = clean.replacingOccurrences(
            of: #"[^a-z0-9\u{05D0}-\u{05EA}\s]"#,
            with: " ",
            options: .regularExpression
        )

        clean = clean.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )

        return clean.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private func subjectFromVoiceQuery(
        _ query: String
    ) -> SubjectTopic? {
        let normalizedQuery =
            normalizedVoiceTopic(query)

        guard !normalizedQuery.isEmpty else {
            return nil
        }

        let subjects =
            TopicsBySubjectRegistry.allSubjects()

        // קודם כול מחפשים התאמה מלאה.
        if let exactMatch = subjects.first(
            where: { subject in
                let hebrewTitle =
                    normalizedVoiceTopic(
                        subject.titleHeb
                    )

                if normalizedQuery == hebrewTitle {
                    return true
                }

                let identifier =
                    normalizedVoiceTopic(
                        subject.id.replacingOccurrences(
                            of: "_",
                            with: " "
                        )
                    )

                if normalizedQuery == identifier {
                    return true
                }

                if let englishTitle =
                        KmiEnglishTitleResolver
                            .englishTitle(
                                for: subject.id
                            ) {
                    return normalizedQuery ==
                        normalizedVoiceTopic(
                            englishTitle
                        )
                }

                return false
            }
        ) {
            return exactMatch
        }

        // אם המשתמש אמר משפט ארוך יותר, בוחרים את
        // ההתאמה הספציפית והארוכה ביותר.
        return subjects
            .compactMap { subject -> (SubjectTopic, Int)? in
                var candidates = [
                    normalizedVoiceTopic(
                        subject.titleHeb
                    ),
                    normalizedVoiceTopic(
                        subject.id.replacingOccurrences(
                            of: "_",
                            with: " "
                        )
                    )
                ]

                if let englishTitle =
                        KmiEnglishTitleResolver
                            .englishTitle(
                                for: subject.id
                            ) {
                    candidates.append(
                        normalizedVoiceTopic(
                            englishTitle
                        )
                    )
                }

                let matchedLength =
                    candidates
                        .filter { !$0.isEmpty }
                        .filter {
                            normalizedQuery.contains($0) ||
                            $0.contains(normalizedQuery)
                        }
                        .map(\.count)
                        .max()

                guard let matchedLength else {
                    return nil
                }

                return (
                    subject,
                    matchedLength
                )
            }
            .sorted {
                $0.1 > $1.1
            }
            .first?
            .0
    }

    private func openGlobalSearch(
        query: String
    ) {
        let cleanQuery =
            query.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        NotificationCenter.default.post(
            name: Notification.Name(
                "KMI_OPEN_GLOBAL_SEARCH"
            ),
            object:
                cleanQuery.isEmpty
                    ? nil
                    : cleanQuery
        )
    }

    private func openOnboardingIfNeeded() {
        guard !didEvaluateOnboarding else {
            return
        }

        didEvaluateOnboarding = true

        guard !OnboardingPreferences.hasCompleted else {
            return
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.35
        ) {
            guard nav.path.isEmpty else {
                return
            }

            nav.push(
                .onboarding(
                    manual: false
                )
            )
        }
    }

    private func bindVoiceCommandActions() {
        voiceCommands.bind(
            actions: VoiceCommandActions(
                openHome: {
                    nav.popToRoot()
                },
                openSettings: {
                    nav.push(.settings)
                },
                openProgress: {
                    nav.push(.progress)
                },
                openTrainings: {
                    nav.push(
                        .trainingHistory
                    )
                },
                openTopics: {
                    nav.push(
                        .beltQuestionsByTopic(
                            belt:
                                auth.registeredBelt ??
                                .orange
                        )
                    )
                },
                openBelts: {
                    nav.push(
                        .beltQuestionsByBelt(
                            belt:
                                auth.registeredBelt ??
                                .orange
                        )
                    )
                },
                openSearch: {
                    openGlobalSearch(
                        query: ""
                    )
                },
                goBack: {
                    nav.pop()
                },
                openBelt: {
                    beltQuery in

                    guard let belt =
                            beltFromVoiceQuery(
                                beltQuery
                            ) else {
                        openGlobalSearch(
                            query: beltQuery
                        )
                        return
                    }

                    nav.push(
                        .beltQuestionsByBelt(
                            belt: belt
                        )
                    )
                },
                openTopic: {
                    topicQuery in

                    let cleanTopic =
                        topicQuery.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )

                    guard !cleanTopic.isEmpty else {
                        openGlobalSearch(
                            query: ""
                        )
                        return
                    }

                    if let subject =
                            subjectFromVoiceQuery(
                                cleanTopic
                            ) {
                        nav.push(
                            .subjectAcrossBelts(
                                subjectId: subject.id,
                                subjectTitle:
                                    subject.titleHeb
                            )
                        )
                        return
                    }

                    // נושא קטלוג רגיל שאינו רשום
                    // כנושא חוצה־חגורות.
                    nav.push(
                        .topicAcrossBelts(
                            topicTitle: cleanTopic,
                            subTopicTitle: nil
                        )
                    )
                },
                findAndOpen: {
                    query in

                    let cleanQuery =
                        query.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )

                    NotificationCenter.default.post(
                        name: Notification.Name(
                            "KMI_FIND_AND_OPEN_EXERCISE"
                        ),
                        object: cleanQuery
                    )
                },
                explainExercise: {
                    query in

                    let cleanQuery =
                        query.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )

                    NotificationCenter.default.post(
                        name: Notification.Name(
                            "KMI_FIND_AND_OPEN_EXERCISE"
                        ),
                        object: cleanQuery
                    )
                },
                search: {
                    query in

                    openGlobalSearch(
                        query: query
                    )
                },
                openDrawerDestination: {
                    destination in

                    openVoiceDrawerDestination(
                        destination
                    )
                },
                handleUnknown: {
                    originalText in

                    NotificationCenter.default.post(
                        name: Notification.Name(
                            "KMI_VOICE_COMMAND_UNKNOWN"
                        ),
                        object: originalText
                    )
                }
            )
        )
    }

    private func openVoiceDrawerDestination(
        _ destination: VoiceDrawerDestination
    ) {
        switch destination {
        case .myProfile:
            nav.push(.myProfile)

        case .coachAttendance:
            nav.push(.attendance)

        case .coachBroadcast:
            nav.push(.coachBroadcast)

        case .coachTrainees:
            nav.push(.coachTrainees)

        case .coachPaymentsReport:
            nav.push(.paymentsReport)

        case .coachInternalExam:
            nav.push(
                .internalExam(
                    belt:
                        auth.registeredBelt ??
                        .orange
                )
            )

        case .aboutAvi:
            nav.push(.aboutAvi)

        case .networkCoaches:
            nav.push(.aboutNetworkCoaches)

        case .aboutMethod:
            nav.push(.aboutMethod)

        case .contactUs:
            nav.push(.contactUs)

        case .branchForum:
            nav.push(.forum)

        case .manageSubscription:
            nav.push(.subscription)

        case .formsAndPayments:
            nav.push(.membershipPayment)

        case .logout:
            nav.popToRoot()
            auth.signOut()

        case .exercisesDemo,
             .language,
             .rateUs:
            /*
             * היעדים האלה אינם AppRoute רגיל כרגע.
             * נחבר אותם לפעולות הקיימות בסבב הבא.
             */
            break
        }
    }

    var body: some View {
        DeviceGateRootView {
            NavigationStack(path: $nav.path) {

                KmiRootLayout(
                    title: "מסך הבית",
                    nav: nav,
                    selectedIcon: .home,
                    onPickSearchResult: { key in
                        NotificationCenter.default.post(
                            name: Notification.Name(
                                "KMI_GLOBAL_SEARCH_PICK"
                            ),
                            object: key
                        )
                    },
                    onShare: {
                        NotificationCenter.default.post(
                            name: Notification.Name(
                                "KMI_HOME_SHARE_PDF"
                            ),
                            object: nil
                        )
                    }
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

                    case .monthlyTrainingBoard:
                        KmiRootLayout(
                            title: tr(
                                "לוח אימונים חודשי",
                                "Monthly Training Board"
                            ),
                            nav: nav,
                            selectedIcon: .home
                        ) {
                            MonthlyTrainingBoardView()
                                .navigationBarBackButtonHidden(
                                    true
                                )
                                .toolbar(
                                    .hidden,
                                    for: .navigationBar
                                )
                        }

                    case .trainingSummary(
                        let pickedDateIso
                    ):
                        KmiRootLayout(
                            title: tr(
                                "סיכום אימון",
                                "Training Summary"
                            ),
                            nav: nav,
                            selectedIcon: .home
                        ) {
                            TrainingSummaryView(
                                ownerUid:
                                    Auth.auth().currentUser?.uid ?? "",
                                isCoach: isCoachUser,
                                initialBelt:
                                    auth.registeredBelt ?? .white,
                                pickedDateIso: pickedDateIso,
                                initialBranchName:
                                    auth.userBranch
                                        .trimmingCharacters(
                                            in: .whitespacesAndNewlines
                                        ),
                                initialCoachName:
                                    auth.userFullName
                                        .trimmingCharacters(
                                            in: .whitespacesAndNewlines
                                        )
                            )
                            .navigationBarBackButtonHidden(true)
                        }
                    
                    case .coachTrainees:
                        KmiRootLayout(title: tr("רשימת המתאמנים", "Trainees list"), nav: nav, selectedIcon: .home) {
                            CoachTraineesView()
                                .navigationBarBackButtonHidden(true)
                        }
                        
                    case .coachBroadcast:
                        KmiRootLayout(
                            title: tr(
                                "שליחת הודעה לקבוצה",
                                "Send Group Message"
                            ),
                            nav: nav,
                            selectedIcon: .home
                        ) {
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

                    case .aboutNetworkCoaches:
                        KmiRootLayout(title: "אודות המאמנים ברשת", nav: nav, selectedIcon: .home) {
                            AboutNetworkCoachesView()
                                .navigationBarBackButtonHidden(true)
                        }

                    case .forum:
                        KmiRootLayout(
                            title: "פורום הסניף",
                            nav: nav,
                            selectedIcon: nil,
                            onPickSearchResult: { key in
                                NotificationCenter.default.post(
                                    name: Notification.Name("KMI_GLOBAL_SEARCH_PICK"),
                                    object: key
                                )
                            }
                        ) {
                            ForumView(onClose: { nav.pop() })
                                .navigationBarBackButtonHidden(true)
                        }

                    case .myProfile:
                        KmiRootLayout(
                            title: tr(
                                "הפרופיל שלי",
                                "My Profile"
                            ),
                            nav: nav,
                            selectedIcon: nil
                        ) {
                            MyProfileView()
                                .navigationBarBackButtonHidden(
                                    true
                                )
                        }

                    case .editProfile:
                        KmiRootLayout(
                            title: "עריכת פרופיל",
                            nav: nav,
                            selectedIcon: .settings,
                            onPickSearchResult: { key in
                                NotificationCenter.default.post(
                                    name: Notification.Name("KMI_GLOBAL_SEARCH_PICK"),
                                    object: key
                                )
                            }
                        ) {
                            RegisterFormView(
                                prefillPhone: firstExistingDefaultValue([
                                    "phone",
                                    "phoneNumber",
                                    "mobilePhone",
                                    "user_phone",
                                    "traineePhone"
                                ]),
                                prefillEmail: (
                                    Auth.auth().currentUser?.email ??
                                    UserDefaults.standard.string(forKey: "email") ??
                                    ""
                                ),
                                initialRole: isCoachUser ? .coach : .trainee,
                                screenTitle: "עריכת פרופיל",
                                submitTitle: "שמירת שינויים",
                                submittingTitle: "שומר שינויים...",
                                onBack: {
                                    nav.pop()
                                },
                                onSubmit: { formState in
                                    let defaults = UserDefaults.standard

                                    defaults.set(formState.fullName, forKey: "fullName")
                                    defaults.set(formState.phone, forKey: "phone")
                                    defaults.set(formState.email, forKey: "email")
                                    defaults.set(formState.region, forKey: "region")
                                    defaults.set(Array(formState.branches), forKey: "branches")
                                    defaults.set(Array(formState.groups), forKey: "groups")
                                    defaults.set(formState.activeBranch, forKey: "active_branch")
                                    defaults.set(formState.activeGroup, forKey: "active_group")
                                    defaults.set(formState.username, forKey: "username")
                                    defaults.set(formState.gender, forKey: "gender")
                                    defaults.set(formState.birthDay, forKey: "birthDay")
                                    defaults.set(formState.birthMonth, forKey: "birthMonth")
                                    defaults.set(formState.birthYear, forKey: "birthYear")
                                    defaults.set(formState.belt, forKey: "current_belt")
                                    defaults.set(formState.wantsSms, forKey: "wantsSms")
                                    defaults.set(formState.acceptsTerms, forKey: "acceptsTerms")

                                    let resolvedRole: String = {
                                        if formState.role == .coach {
                                            return "coach"
                                        } else {
                                            return "trainee"
                                        }
                                    }()

                                    defaults.set(resolvedRole, forKey: "user_role")
                                    defaults.set(resolvedRole, forKey: "role")
                                    defaults.set(resolvedRole, forKey: "userRole")
                                    defaults.set(resolvedRole, forKey: "profile_role")

                                    defaults.synchronize()

                                    auth.reloadProfileIfSignedIn()
                                    nav.pop()
                                },
                                onReadMoreTerms: {
                                    // אפשר לחבר בהמשך למסך תנאי שימוש / מדיניות פרטיות
                                }
                            )
                            .navigationBarBackButtonHidden(true)
                        }

                        // ✅ תרגילים לפי חגורה
                        case .beltQuestionsByBelt(let belt):
                            KmiRootLayout(
                                title: beltTitleForUi(belt),
                                nav: nav,
                                selectedIcon: .home,
                                onShare: {
                                    NotificationCenter.default.post(
                                        name: Notification.Name(
                                            "KMI_BELT_MATERIALS_SHARE_PDF"
                                        ),
                                        object: nil
                                    )
                                }
                            ) {
                                BeltQuestionsByBeltView(
                                    belt: belt
                                )
                                .navigationBarBackButtonHidden(
                                    true
                                )
                            }
                        
                        // ✅ תרגילים לפי נושא
                        case .beltQuestionsByTopic(let belt):
                            KmiRootLayout(title: beltTitleForUi(belt), nav: nav, selectedIcon: .home) {
                                BeltQuestionsByTopicView(belt: belt)
                                    .navigationBarBackButtonHidden(true)
                            }
                        
                        // ✅ נושא אמיתי לפי TopicsBySubjectRegistry
                        case .subjectAcrossBelts(
                            let subjectId,
                            let subjectTitle
                        ):
                            if let subject =
                                    TopicsBySubjectRegistry
                                        .allSubjects()
                                        .first(
                                            where: {
                                                $0.id == subjectId
                                            }
                                        ) {
                                KmiRootLayout(
                                    title: subjectTitle,
                                    nav: nav,
                                    selectedIcon: .home
                                ) {
                                    SubjectAcrossBeltsView(
                                        subject: subject
                                    )
                                    .navigationBarBackButtonHidden(
                                        true
                                    )
                                }
                            } else {
                                KmiRootLayout(
                                    title: subjectTitle,
                                    nav: nav,
                                    selectedIcon: .home
                                ) {
                                    TopicAcrossBeltsView(
                                        topicTitle: subjectTitle
                                    )
                                    .navigationBarBackButtonHidden(
                                        true
                                    )
                                }
                            }

                        // ✅ קטגוריית קטלוג חוצת חגורות
                        case .topicAcrossBelts(
                            let topicTitle,
                            let subTopicTitle
                        ):
                            KmiRootLayout(
                                title:
                                    subTopicTitle ??
                                    topicTitle,
                                nav: nav,
                                selectedIcon: .home
                            ) {
                                TopicAcrossBeltsView(
                                    topicTitle: topicTitle,
                                    subTopicTitle: subTopicTitle
                                )
                                .navigationBarBackButtonHidden(
                                    true
                                )
                            }

                        case .progress:
                        KmiRootLayout(title: "מד התקדמות", nav: nav, selectedIcon: .stats) {
                            ProgressScreenIOS(
                                onOpenCarousel: {
                                    nav.push(.beltQuestionsByBelt(belt: auth.registeredBelt ?? .orange))
                                }
                            )
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
                        
                    case .subscription:
                        KmiRootLayout(title: "ניהול מנוי", nav: nav, selectedIcon: .home) {
                            SubscriptionScreen(
                                onBack: {
                                    nav.pop()
                                },
                                onOpenPlans: {
                                    nav.push(.subscriptionPlans)
                                },
                                onOpenHome: {
                                    nav.popToRoot()
                                }
                            )
                            .navigationBarBackButtonHidden(true)
                        }

                    case .subscriptionPlans:
                        KmiRootLayout(title: "תוכניות מנוי", nav: nav, selectedIcon: .home) {
                            SubscriptionPlansScreen(
                                onBack: {
                                    nav.pop()
                                },
                                onOpenHome: {
                                    nav.popToRoot()
                                }
                            )
                            .navigationBarBackButtonHidden(true)
                        }

                        // ✅ Membership payment
                        case .membershipPayment:
                            KmiRootLayout(title: "תשלום דמי חבר", nav: nav, selectedIcon: .home) {
                                MembershipPaymentView(
                                    isEnglish: false,
                                    prefill: membershipPaymentPrefill,
                                    onClose: {
                                        nav.pop()
                                    },
                                    onReadFullPolicy: {
                                        // בשלב הבא נחבר למסך מדיניות מלא / מסמך מדיניות
                                    },
                                    onContinueToPayment: { formData in
                                        nav.push(.membershipCheckout(formData: formData))
                                    }
                                )
                                .navigationBarBackButtonHidden(true)
                            }

                        // ✅ Membership checkout
                        case .membershipCheckout(let formData):
                            KmiRootLayout(title: "פרטי תשלום", nav: nav, selectedIcon: .home) {
                                MembershipCheckoutView(
                                    isEnglish: false,
                                    formData: formData,
                                    onBack: {
                                        nav.pop()
                                    },
                                    onPaymentCompleted: {
                                        nav.popToRoot()
                                    }
                                )
                                .navigationBarBackButtonHidden(true)
                            }
                        
                    // ✅ Payments report
                    case .paymentsReport:
                        KmiRootLayout(title: "דו״ח תשלומים", nav: nav, selectedIcon: .home) {
                            PaymentsReportView(
                                isEnglish: false,
                                onClose: {
                                    nav.pop()
                                },
                                onOpenTrainees: {
                                    nav.push(.coachTrainees)
                                },
                                onSaveManualPayment: { traineeId, amount, method, notes in
                                    // בשלב הבא נחבר לשמירה אמיתית ב-Firebase / Firestore
                                }
                            )
                            .navigationBarBackButtonHidden(true)
                        }

                        // ✅ settings (אם קיים אצלך)
                        case .settings:
                            KmiRootLayout(title: "הגדרות", nav: nav, selectedIcon: .settings) {
                                SettingsView(nav: nav)
                                    .navigationBarBackButtonHidden(true)
                            }

                        case .contactUs:
                            KmiRootLayout(title: tr("צור קשר", "Contact Us"), nav: nav, selectedIcon: .home) {
                                ContactUsViewIOS(
                                    isEnglish: isEnglish,
                                    onClose: {
                                        nav.pop()
                                    }
                                )
                                .navigationBarBackButtonHidden(true)
                            }
                     
                    case .weakPoints(let belt):
                        KmiRootLayout(title: "נקודות תורפה", nav: nav, selectedIcon: .home) {
                            WeakPointsView(
                                belt: belt,
                                nav: nav
                            )
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

                    case .practice(
                        let belt,
                        let topicTitle
                    ):
                        KmiRootLayout(
                            title:
                                tr(
                                    "תרגול",
                                    "Practice"
                                ),
                            nav: nav,
                            selectedIcon: .home
                        ) {
                            RandomPracticeView(
                                nav: nav,
                                belt: belt,
                                topicTitle:
                                    topicTitle,
                                items: {
                                    let cleanToken =
                                        topicTitle
                                            .trimmingCharacters(
                                                in:
                                                    .whitespacesAndNewlines
                                            )

                                    func itemsForTopic(
                                        _ rawTopicTitle:
                                            String
                                    ) -> [String] {
                                        let cleanTitle =
                                            rawTopicTitle
                                                .trimmingCharacters(
                                                    in:
                                                        .whitespacesAndNewlines
                                                )

                                        guard !cleanTitle
                                            .isEmpty else {
                                            return []
                                        }

                                        var topicItems =
                                            ContentRepo
                                                .shared
                                                .getAllItemsFor(
                                                    belt:
                                                        belt,
                                                    topicTitle:
                                                        cleanTitle,
                                                    subTopicTitle:
                                                        nil
                                                )

                                        let details =
                                            TopicsEngine
                                                .shared
                                                .topicDetailsFor(
                                                    belt:
                                                        belt,
                                                    topicTitle:
                                                        cleanTitle
                                                )

                                        for rawSubTitle
                                            in details
                                                .subTitles {
                                            let cleanSubTitle =
                                                rawSubTitle
                                                    .trimmingCharacters(
                                                        in:
                                                            .whitespacesAndNewlines
                                                    )

                                            guard !cleanSubTitle
                                                .isEmpty,
                                                  cleanSubTitle !=
                                                    cleanTitle else {
                                                continue
                                            }

                                            topicItems.append(
                                                contentsOf:
                                                    ContentRepo
                                                        .shared
                                                        .getAllItemsFor(
                                                            belt:
                                                                belt,
                                                            topicTitle:
                                                                cleanTitle,
                                                            subTopicTitle:
                                                                cleanSubTitle
                                                        )
                                            )
                                        }

                                        return topicItems
                                    }

                                    let requestedTopics:
                                        [String]

                                    if cleanToken.isEmpty ||
                                        cleanToken ==
                                        "__ALL__" {
                                        requestedTopics =
                                            TopicsEngine
                                                .shared
                                                .topicTitlesFor(
                                                    belt:
                                                        belt
                                                )
                                    } else {
                                        requestedTopics = [
                                            cleanToken
                                        ]
                                    }

                                    var seen =
                                        Set<String>()

                                    var result:
                                        [String] = []

                                    for requestedTopic
                                        in requestedTopics {
                                        for rawItem
                                            in itemsForTopic(
                                                requestedTopic
                                            ) {
                                            let cleanItem =
                                                rawItem
                                                    .trimmingCharacters(
                                                        in:
                                                            .whitespacesAndNewlines
                                                    )

                                            guard !cleanItem
                                                .isEmpty else {
                                                continue
                                            }

                                            let normalizedKey =
                                                cleanItem
                                                    .replacingOccurrences(
                                                        of:
                                                            "\u{200F}",
                                                        with:
                                                            ""
                                                    )
                                                    .replacingOccurrences(
                                                        of:
                                                            "\u{200E}",
                                                        with:
                                                            ""
                                                    )
                                                    .replacingOccurrences(
                                                        of:
                                                            "\u{00A0}",
                                                        with:
                                                            " "
                                                    )
                                                    .lowercased()

                                            guard seen
                                                .insert(
                                                    normalizedKey
                                                )
                                                .inserted else {
                                                continue
                                            }

                                            result.append(
                                                cleanItem
                                            )
                                        }
                                    }

                                    return result
                                }()
                            )
                            .navigationBarBackButtonHidden(
                                true
                            )
                        }

                    case .summary(let belt):
                        KmiRootLayout(title: "מסך סיכום", nav: nav, selectedIcon: .home) {
                            SummaryView(belt: belt, nav: nav)
                                .navigationBarBackButtonHidden(true)
                        }

                    case .voiceAssistant:
                        KmiRootLayout(
                            title: tr(
                                "יובל – העוזר האישי",
                                "Yuval – Personal Assistant"
                            ),
                            nav: nav,
                            selectedIcon: .assistant
                        ) {
                            VoiceAssistantView()
                                .navigationBarBackButtonHidden(true)
                        }

                    case .onboarding(let manual):
                        KmiRootLayout(
                            title: tr(
                                "הדרכת האפליקציה",
                                "App Guide"
                            ),
                            nav: nav,
                            selectedIcon: .guide
                        ) {
                            OnboardingView(
                                allowSkip: true,
                                onFinish: {
                                    if !manual {
                                        OnboardingPreferences
                                            .markCompleted()
                                    }

                                    nav.pop()
                                },
                                onSkip: {
                                    if !manual {
                                        OnboardingPreferences
                                            .markCompleted()
                                    }

                                    nav.pop()
                                }
                            )
                            .navigationBarBackButtonHidden(true)
                        }
                        
                    case .beltFinalExam(let belt):
                        KmiRootLayout(title: "מבחן מסכם", nav: nav, selectedIcon: .home) {
                            BeltFinalExamView(
                                belt: belt
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
                        let resolvedAttendanceBranch: String = {
                            let authBranch = auth.userBranch.trimmingCharacters(in: .whitespacesAndNewlines)

                            if !authBranch.isEmpty {
                                return authBranch
                            }

                            let storedActiveBranch = firstExistingDefaultValue([
                                "active_branch",
                                "activeBranch",
                                "branch",
                                "user_branch",
                                "traineeBranch"
                            ])

                            return storedActiveBranch
                        }()

                        let resolvedAttendanceGroup: String = {
                            let authGroup = auth.userGroup.trimmingCharacters(in: .whitespacesAndNewlines)

                            if !authGroup.isEmpty {
                                return authGroup
                            }

                            let storedGroup = firstExistingDefaultValue([
                                "active_group",
                                "activeGroup",
                                "group",
                                "groupKey",
                                "ageGroup",
                                "user_group",
                                "traineeGroup"
                            ])

                            return storedGroup
                        }()

                        let resolvedAttendanceCoachName: String = {
                            let authName = auth.userFullName.trimmingCharacters(in: .whitespacesAndNewlines)

                            if !authName.isEmpty {
                                return authName
                            }

                            let storedName = firstExistingDefaultValue([
                                "fullName",
                                "displayName",
                                "coachName",
                                "username"
                            ])

                            return storedName
                        }()

                        KmiRootLayout(title: "נוכחות", nav: nav, selectedIcon: .home) {
                            AttendanceView(
                                ownerUid:
                                    Auth.auth().currentUser?.uid ?? "",
                                initialDateIso: nil,
                                initialBranchName: resolvedAttendanceBranch,
                                initialGroupKey: resolvedAttendanceGroup,
                                initialCoachName: resolvedAttendanceCoachName,
                                showsInternalTopStrip: false,
                                onHomeTap: {
                                    nav.popToRoot()
                                },
                                onSearchTap: {
                                    NotificationCenter.default.post(
                                        name: Notification.Name("KMI_OPEN_GLOBAL_SEARCH"),
                                        object: nil
                                    )
                                },
                                onSettingsTap: {
                                    nav.push(.settings)
                                },
                                onAssistantTap: {
                                    nav.push(.voiceAssistant)
                                }
                            )
                            .navigationBarBackButtonHidden(true)
                            .onAppear {
                                auth.reloadProfileIfSignedIn()
                            }
                        }
                        
                    case .adminUsers:
                        if isAdminUser {
                            KmiRootLayout(title: "ניהול משתמשים", nav: nav, selectedIcon: .home) {
                                AdminUsersView()
                                    .navigationBarBackButtonHidden(true)
                            }
                        } else {
                            KmiRootLayout(title: "אין הרשאה", nav: nav, selectedIcon: .home) {
                                NoAdminPermissionView(
                                    isEnglish: isEnglish,
                                    title: tr("אין הרשאה", "No Permission"),
                                    subtitle: tr(
                                        "המסך הזה פתוח רק למנהל האפליקציה",
                                        "This screen is available only to the app admin"
                                    )
                                )
                                .navigationBarBackButtonHidden(true)
                            }
                        }

                    case .controlCenterLogs:
                        if isAdminUser {
                            KmiRootLayout(
                                title: tr("מרכז בקרה ולוגים", "Control Center & Logs"),
                                nav: nav,
                                selectedIcon: .home
                            ) {
                                ControlCenterLogsView(isEnglish: isEnglish)
                                    .navigationBarBackButtonHidden(true)
                            }
                        } else {
                            KmiRootLayout(title: "אין הרשאה", nav: nav, selectedIcon: .home) {
                                NoAdminPermissionView(
                                    isEnglish: isEnglish,
                                    title: tr("אין הרשאה", "No Permission"),
                                    subtitle: tr(
                                        "המסך הזה פתוח רק למנהל האפליקציה",
                                        "This screen is available only to the app admin"
                                    )
                                )
                                .navigationBarBackButtonHidden(true)
                            }
                        }
                        
                        // ✅ fallback כדי שלא יהיה לבן
                        default:
                            ZStack {
                                KmiBackground()
                                Text("Unhandled route: \(String(describing: route))")
                                    .foregroundStyle(.white)
                                    .padding()
                            }
                    }
                }
            }
            .environmentObject(nav)
            .fullScreenCover(
                isPresented: Binding(
                    get: {
                        voiceCommands.isPresented
                    },
                    set: { isPresented in
                        if !isPresented {
                            voiceCommands.dismiss()
                        }
                    }
                )
            ) {
                PushToTalkVoiceDialogIOS {
                    command,
                    spokenText in

                    voiceCommands.handle(
                        command: command,
                        spokenText: spokenText
                    )
                }
                .presentationBackground(.clear)
            }
            .onAppear {
                auth.reloadProfileIfSignedIn()
                bindVoiceCommandActions()
                openOnboardingIfNeeded()
            }
            .onDisappear {
                voiceCommands.unbind()
            }
        }
    }
}

private struct NoAdminPermissionView: View {
    let isEnglish: Bool
    let title: String
    let subtitle: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [KmiTheme.bgTop, KmiTheme.bgMid, KmiTheme.bgBot],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(.white)

                Text(title)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
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
