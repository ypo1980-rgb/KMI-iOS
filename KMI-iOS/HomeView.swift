import SwiftUI
import UIKit
import FirebaseAuth
import FirebaseFirestore
import Shared

private struct HomePDFShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct HomePDFShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(
        context: Context
    ) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {
    }
}

private enum HomePDFExportError: LocalizedError {
    case noTrainings
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .noTrainings:
            return "אין אימונים זמינים ליצירת PDF"

        case .writeFailed:
            return "לא ניתן היה ליצור את קובץ ה־PDF"
        }
    }
}

private enum HomeHolidayCalendar {

    private static let blockingKeywords = [
        "ראש השנה",
        "יום כיפור",
        "כיפור",
        "סוכות",
        "שמחת תורה",
        "פסח",
        "חול המועד פסח",
        "שבועות",
        "תשעה באב"
    ]

    private static let nonBlockingKeywords = [
        "ראש חודש",
        "ספירת העומר",
        "לג בעומר",
        "ט״ו בשבט",
        "טו בשבט",
        "יום העצמאות",
        "יום הזיכרון",
        "יום השואה",
        "פורים קטן",
        "שושן פורים",
        "חנוכה",
        "צום",
        "תענית",
        "ערב"
    ]

    private static let blockedDateKeys: Set<String> = {
        guard let url = Bundle.main.url(
            forResource: "holidays_hebrew_2024_2026",
            withExtension: "json"
        ),
        let data = try? Data(contentsOf: url),
        let root = try? JSONSerialization.jsonObject(
            with: data
        ) as? [String: Any],
        let items = root["items"] as? [[String: Any]] else {
            return []
        }

        var result = Set<String>()

        for item in items {
            let titleKeys = [
                "title",
                "title_he",
                "hebrew",
                "name",
                "category",
                "subcat"
            ]

            let title = titleKeys
                .compactMap { key in
                    item[key] as? String
                }
                .joined(separator: " ")
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

            guard !title.isEmpty else {
                continue
            }

            let containsNonBlocking =
                nonBlockingKeywords.contains { keyword in
                    title.contains(keyword.lowercased())
                }

            if containsNonBlocking {
                continue
            }

            let containsBlocking =
                blockingKeywords.contains { keyword in
                    title.contains(keyword.lowercased())
                }

            guard containsBlocking,
                  let dateKey = item["date_iso"] as? String,
                  !dateKey.isEmpty else {
                continue
            }

            result.insert(dateKey)
        }

        return result
    }()

    static func isTrainingBlocked(
        on date: Date
    ) -> Bool {
        let formatter = DateFormatter()
        formatter.calendar =
            Calendar(identifier: .gregorian)
        formatter.locale =
            Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"

        return blockedDateKeys.contains(
            formatter.string(from: date)
        )
    }
}

private struct CoachHomeMessage: Identifiable, Hashable {
    let id: String
    let text: String
    let coachName: String
    let sentAt: Date?
    let branch: String
    let group: String
}

struct HomeView: View {
    
    @ObservedObject var nav: AppNavModel
    @EnvironmentObject private var auth: AuthViewModel
    
    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"
    
    @AppStorage("fullName") private var storedFullName: String = ""
    @AppStorage("user_role") private var storedUserRole: String = "trainee"
    @AppStorage("region") private var storedRegion: String = ""
    @AppStorage("branch") private var storedBranch: String = ""
    @AppStorage("active_branch") private var storedActiveBranch: String = ""
    @AppStorage("group") private var storedGroup: String = ""
    @AppStorage("active_group") private var storedActiveGroup: String = ""
    @AppStorage("phone") private var storedPhone: String = ""
    @AppStorage("phoneNumber") private var storedPhoneNumber: String = ""
    @AppStorage("phone_number") private var storedPhoneNumberSnake: String = ""
    @AppStorage("mobile") private var storedMobile: String = ""
    @AppStorage("current_belt") private var storedCurrentBelt: String = ""
    @AppStorage("belt_current") private var storedUserCurrentBelt: String = ""
    
    // Android parity: Home quick menu premium access flags
    @AppStorage("has_full_access") private var hasFullAccessFlag: Bool = false
    @AppStorage("full_access") private var fullAccessFlag: Bool = false
    @AppStorage("subscription_active") private var subscriptionActiveFlag: Bool = false
    @AppStorage("is_subscribed") private var isSubscribedFlag: Bool = false
    @AppStorage("google_subscription_verified") private var googleSubscriptionVerifiedFlag: Bool = false
    @AppStorage("sub_product") private var subscriptionProduct: String = ""
    @AppStorage("sub_access_until") private var subscriptionAccessUntil: Double = 0
    
    @StateObject private var trainingsVm = HomeTrainingsViewModel()

    @State private var goVoiceAssistant: Bool = false
    @State private var goMonthly: Bool = false
    @State private var goCard: Bool = false

    @State private var selectedTraining: TrainingData? = nil
    @State private var showNavigationSheet: Bool = false

    @State private var pdfShareItem: HomePDFShareItem? = nil
    @State private var pdfExportErrorMessage: String? = nil
    @State private var freeSessionsErrorMessage: String? = nil

    // Android parity: quick menu icon must always be visible on Home
    @State private var showHomeQuickMenu: Bool = false
    
    // Global search navigation
    @State private var pickedExercise: ExerciseSelection? = nil
    
    // Coach broadcast from Firestore — Android parity
    // Android: latest message card + recent 5 messages dialog/sheet
    @State private var recentCoachMessages: [CoachHomeMessage] = []
    @State private var showCoachMessagesSheet: Bool = false
    @State private var coachBroadcastListener: ListenerRegistration? = nil

    @AppStorage("coach_broadcast_open_dialog")
    private var openCoachMessagesFromPush: Bool = false

    @AppStorage("coach_broadcast_open_from_push")
    private var openCoachMessagesFromPushLegacy: Bool = false

    @AppStorage("coach_broadcast_push_id")
    private var pendingCoachBroadcastId: String = ""
    
    private let calendar = Calendar(identifier: .gregorian)
    
    private var isEnglish: Bool {
        let primary = kmiAppLanguageCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if primary == "he" || primary == "hebrew" || primary == "עברית" {
            return false
        }

        if primary == "en" || primary == "english" {
            return true
        }

        let secondary = appLanguageRaw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if secondary == "he" || secondary == "hebrew" || secondary == "עברית" {
            return false
        }

        if secondary == "en" || secondary == "english" {
            return true
        }

        let initial = initialLanguageCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if initial == "en" || initial == "english" {
            return true
        }

        return false
    }
    
    private var screenLayoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }
    
    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }
    
    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }
    
    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }
    
    private var fallbackUserName: String {
        isEnglish ? "User" : "משתמש"
    }
    
    private var resolvedRegion: String {
        let value = auth.userRegion.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? storedRegion.trimmingCharacters(in: .whitespacesAndNewlines) : value
    }
    
    private var resolvedBranch: String {
        let authValue = auth.userBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        if !authValue.isEmpty { return authValue }

        let active = storedActiveBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        if !active.isEmpty { return active }

        return storedBranch.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resolvedBranches: [String] {
        let defaults = UserDefaults.standard

        func splitBranches(_ raw: String) -> [String] {
            raw
                .replacingOccurrences(of: "[", with: "")
                .replacingOccurrences(of: "]", with: "")
                .split { character in
                    character == "," ||
                    character == ";" ||
                    character == "|" ||
                    character == "\n"
                }
                .map {
                    String($0)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(
                            in: CharacterSet(charactersIn: "\"")
                        )
                }
                .filter { !$0.isEmpty }
        }

        func values(for key: String) -> [String] {
            if let array = defaults.array(forKey: key) {
                return array
                    .map {
                        "\($0)".trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                    }
                    .filter { !$0.isEmpty }
            }

            if let string = defaults.string(forKey: key) {
                return splitBranches(string)
            }

            return []
        }

        var branches: [String] = [
            auth.userBranch,
            storedActiveBranch,
            storedBranch
        ]

        branches += [
            "active_branch",
            "activeBranch",
            "branch",
            "branches",
            "branches_json",
            "selected_branches",
            "branch2",
            "branch3"
        ]
        .flatMap { key in
            values(for: key)
        }

        var seen = Set<String>()

        return branches
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter { !$0.isEmpty }
            .filter { branch in
                let normalized =
                    normalizeCoachBroadcastText(branch)

                guard !seen.contains(normalized) else {
                    return false
                }

                seen.insert(normalized)
                return true
            }
    }
    
    private var resolvedGroup: String {
        let authValue = auth.userGroup.trimmingCharacters(in: .whitespacesAndNewlines)
        if !authValue.isEmpty { return authValue }

        let active = storedActiveGroup.trimmingCharacters(in: .whitespacesAndNewlines)
        if !active.isEmpty { return active }

        return storedGroup.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resolvedGroups: [String] {
        let defaults = UserDefaults.standard

        func splitGroups(_ raw: String) -> [String] {
            raw
                .replacingOccurrences(of: "[", with: "")
                .replacingOccurrences(of: "]", with: "")
                .split { character in
                    character == "," ||
                    character == ";" ||
                    character == "|" ||
                    character == "\n"
                }
                .map {
                    String($0)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(
                            in: CharacterSet(charactersIn: "\"")
                        )
                }
                .filter { !$0.isEmpty }
        }

        func values(for key: String) -> [String] {
            if let array = defaults.array(forKey: key) {
                return array
                    .map {
                        "\($0)".trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                    }
                    .filter { !$0.isEmpty }
            }

            if let string = defaults.string(forKey: key) {
                return splitGroups(string)
            }

            return []
        }

        var groups: [String] = [
            auth.userGroup,
            storedActiveGroup,
            storedGroup
        ]

        groups += [
            "groups_json",
            "selected_groups",
            "groups",
            "age_groups",
            "age_group",
            "active_group",
            "activeGroup",
            "group"
        ]
        .flatMap { key in
            values(for: key)
        }

        var seen = Set<String>()

        return groups
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter { !$0.isEmpty }
            .filter { group in
                let normalized =
                    normalizeCoachBroadcastText(group)

                guard !seen.contains(normalized) else {
                    return false
                }

                seen.insert(normalized)
                return true
            }
    }

    private var isAbroadUser: Bool {
        TrainingCatalogIOS.isAbroadRegion(resolvedRegion) ||
        TrainingCatalogIOS.isAbroadBranch(resolvedBranch)
    }
    
    private var resolvedUserRole: String {
        let value =
            storedUserRole
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

        return value.isEmpty ? "trainee" : value
    }
    
    private var isCoachUser: Bool {
        switch resolvedUserRole {
        case "coach", "trainer", "מאמן":
            return true

        default:
            return false
        }
    }
    
    private var hasFullAccess: Bool {
        let nowMillis = Date().timeIntervalSince1970 * 1000

        let hasSubscriptionFlags =
            googleSubscriptionVerifiedFlag ||
            hasFullAccessFlag ||
            fullAccessFlag ||
            subscriptionActiveFlag ||
            isSubscribedFlag ||
            !subscriptionProduct.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        // Android parity:
        // premium access is valid only when flags exist AND accessUntil is still in the future.
        // If accessUntil is missing or expired, premium actions stay locked.
        guard hasSubscriptionFlags else {
            return false
        }

        guard subscriptionAccessUntil > nowMillis else {
            return false
        }

        return true
    }
    
    private var lockSuffix: String {
        hasFullAccess ? "" : " 🔒"
    }
    
    private func clearExpiredSubscriptionFlagsIfNeeded() {
        let nowMillis = Date().timeIntervalSince1970 * 1000

        let hasSubscriptionFlags =
            googleSubscriptionVerifiedFlag ||
            hasFullAccessFlag ||
            fullAccessFlag ||
            subscriptionActiveFlag ||
            isSubscribedFlag ||
            !subscriptionProduct.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        guard hasSubscriptionFlags else { return }
        guard subscriptionAccessUntil > 0 else { return }
        guard subscriptionAccessUntil <= nowMillis else { return }

        hasFullAccessFlag = false
        fullAccessFlag = false
        subscriptionActiveFlag = false
        isSubscribedFlag = false
        googleSubscriptionVerifiedFlag = false
        subscriptionProduct = ""
        subscriptionAccessUntil = 0
    }

    private func runPremiumHomeAction(
        _ action: @escaping () -> Void
    ) {
        clearExpiredSubscriptionFlagsIfNeeded()

        withAnimation(
            .spring(
                response: 0.24,
                dampingFraction: 0.88
            )
        ) {
            showHomeQuickMenu = false
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.12
        ) {
            if hasFullAccess {
                action()
            } else {
                nav.push(.subscription)
            }
        }
    }
    
    private var freeSessionsUid: String {
        Auth.auth().currentUser?.uid
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    private var freeSessionsName: String {
        let firebaseDisplayName =
            (Auth.auth().currentUser?.displayName ?? "")
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        if !firebaseDisplayName.isEmpty {
            return firebaseDisplayName
        }

        let localFullName =
            storedFullName
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        if !localFullName.isEmpty {
            return localFullName
        }

        let defaults = UserDefaults.standard

        let additionalNameKeys = [
            "full_name",
            "name",
            "user_name"
        ]

        for key in additionalNameKeys {
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

        return fallbackUserName
    }
    
    private var freeSessionsBranch: String {
        resolvedBranches
            .first?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? ""
    }
    
    private var freeSessionsGroupKey: String {
        resolvedGroups
            .first?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? ""
    }
    
    private var resolvedBeltId: String {
        let authBeltId = (auth.registeredBelt?.id ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        
        if !authBeltId.isEmpty && authBeltId != "white" {
            return authBeltId
        }
        
        let primary = storedCurrentBelt
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if !primary.isEmpty { return primary }
        
        let secondary = storedUserCurrentBelt
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if !secondary.isEmpty { return secondary }
        
        return "white"
    }
    
    private var resolvedBelt: Belt {
        switch resolvedBeltId {
        case "yellow", "צהוב", "צהובה": return .yellow
        case "orange", "כתום", "כתומה": return .orange
        case "green", "ירוק", "ירוקה": return .green
        case "blue", "כחול", "כחולה": return .blue
        case "brown", "חום", "חומה": return .brown
        case "black", "שחור", "שחורה": return .black
        default: return .white
        }
    }
    
    private var effectiveUpcomingTrainings: [TrainingData] {
        guard !isAbroadUser else {
            return []
        }

        return Array(
            trainingsVm.upcomingTrainings
                .sorted { left, right in
                    left.date < right.date
                }
                .prefix(5)
        )
    }

    private var effectiveStatusMessage: String? {
        if isAbroadUser {
            return nil
        }

        return trainingsVm.statusMessage
    }
    
    private var latestCoachMessage: CoachHomeMessage? {
        recentCoachMessages.first
    }
    
    private var resolvedCoachBroadcastName: String {
        let clean = latestCoachMessage?.coachName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !clean.isEmpty {
            return clean
        }
        return isEnglish ? "Coach" : "המאמן"
    }
    
    private var resolvedCoachBroadcastMessage: String {
        let clean = latestCoachMessage?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        if clean.isEmpty {
            return isEnglish
                ? "No new messages right now"
                : "אין הודעות חדשות כרגע"
        }
        
        if clean.count > 115 {
            return String(clean.prefix(115)) + "..."
        }
        
        return clean
    }
    
    private var resolvedCoachBroadcastBranch: String {
        latestCoachMessage?.branch.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    private var resolvedCoachBroadcastGroup: String {
        latestCoachMessage?.group.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    private var resolvedCoachBroadcastTimeText: String {
        formatCoachMessageTime(latestCoachMessage?.sentAt)
    }
    
    private var recentCoachMessagesExtraCount: Int {
        max(0, recentCoachMessages.count - 1)
    }
    
    private func formatCoachMessageTime(_ date: Date?) -> String {
        guard let date else { return "" }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "he_IL")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "dd/MM/yyyy · HH:mm"
        return formatter.string(from: date)
    }
    
    private var homeQuickMenuItems: [HomeQuickMenuItem] {
        var items: [HomeQuickMenuItem] = []

        items.append(
            HomeQuickMenuItem(
                title: tr("עוזר קולי", "Voice Assistant") + lockSuffix,
                systemImage: "mic.fill"
            ) {
                runPremiumHomeAction {
                    goVoiceAssistant = true
                }
            }
        )

        if !isAbroadUser {
            items.append(
                HomeQuickMenuItem(
                    title: tr("לוח אימונים חודשי", "Monthly Calendar") + lockSuffix,
                    systemImage: "calendar"
                ) {
                    runPremiumHomeAction {
                        goMonthly = true
                    }
                }
            )

            items.append(
                HomeQuickMenuItem(
                    title: tr("סיכום אימון", "Training Summary") + lockSuffix,
                    systemImage: "square.and.pencil"
                ) {
                    runPremiumHomeAction {
                        let formatter = DateFormatter()
                        formatter.locale = Locale(identifier: "en_US_POSIX")
                        formatter.dateFormat = "yyyy-MM-dd"
                        let todayIso = formatter.string(from: Date())

                        nav.push(.trainingSummary(pickedDateIso: todayIso))
                    }
                }
            )

            items.append(
                HomeQuickMenuItem(
                    title: tr("אימונים חופשיים", "Free Trainings") + lockSuffix,
                    systemImage: "plus"
                ) {
                    runPremiumHomeAction {
                        let branch = freeSessionsBranch
                        let groupKey = freeSessionsGroupKey
                        let uid = freeSessionsUid
                        let name = freeSessionsName

                        guard !branch.isEmpty,
                              !groupKey.isEmpty,
                              !uid.isEmpty else {
                            freeSessionsErrorMessage =
                                tr(
                                    "חסרים סניף, קבוצה או פרטי משתמש לפתיחת אימונים חופשיים.",
                                    "Branch, group or user details are missing."
                                )
                            return
                        }

                        nav.push(
                            .freeSessions(
                                branch: branch,
                                groupKey: groupKey,
                                uid: uid,
                                name: name
                            )
                        )
                    }
                }
            )
        }

        return items
    }
    
    var body: some View {
        let baseContent = AnyView(
            ZStack {
                LinearGradient(
                colors: [
                    Color(hex: 0xFFF8FBFF),
                    Color(hex: 0xFFEAF4FF),
                    Color(hex: 0xFFB7DDF7),
                    Color(hex: 0xFF1F78B4),
                    Color(hex: 0xFF062B4A)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    
                    WeekHeaderPill(
                        title: isAbroadUser
                        ? tr("מידע על הסניף המקומי", "Local Branch Information")
                        : (
                            isCoachUser
                            ? tr("אימונים לשבוע הקרוב – מאמן", "Trainings for the upcoming week – Coach")
                            : tr("אימונים לשבוע הקרוב", "Trainings for the upcoming week")
                        ),
                        subtitle: isAbroadUser
                        ? tr("זמני האימונים מתעדכנים מול המאמן המקומי", "Training times are managed by the local coach")
                        : currentWeekSubtitle
                    )
                    .padding(.top, -2)
                    
                    if isAbroadUser {
                        HomeAbroadBranchNotice(
                            region: resolvedRegion,
                            branch: resolvedBranch,
                            isEnglish: isEnglish
                        )
                        .padding(.top, 6)
                    } else if effectiveUpcomingTrainings.isEmpty {
                        emptyBlock(
                            message: effectiveStatusMessage ??
                            tr("אין אימונים קרובים", "No upcoming trainings")
                        )
                        .padding(.top, 6)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(effectiveUpcomingTrainings) { training in
                                HomeTrainingCardAndroidStyle(
                                    training: training,
                                    isEnglish: isEnglish,
                                    onNavigateTap: {
                                        selectedTraining = training
                                        showNavigationSheet = true
                                    }
                                )
                                .padding(.horizontal, 18)
                                .transition(
                                    .move(edge: .bottom)
                                    .combined(with: .opacity)
                                )
                            }
                        }
                        .padding(.top, 6)
                        .animation(
                            .spring(response: 0.35, dampingFraction: 0.85),
                            value: effectiveUpcomingTrainings
                        )
                    }

                    Spacer(minLength: 4)

                    CoachMessagesCard(
                        title: isAbroadUser
                        ? tr("עדכונים מהסניף המקומי", "Local Branch Updates")
                        : tr("הודעות מאמן", "Coach Messages"),
                        coachName: resolvedCoachBroadcastName,
                        message: resolvedCoachBroadcastMessage,
                        branch: resolvedCoachBroadcastBranch,
                        group: resolvedCoachBroadcastGroup,
                        sentAtText: resolvedCoachBroadcastTimeText,
                        extraCount: recentCoachMessagesExtraCount,
                        hasMessages: !recentCoachMessages.isEmpty,
                        isEnglish: isEnglish,
                        onOpenRecent: {
                            showCoachMessagesSheet = true
                        }
                    )
                    .padding(.horizontal, 18)

                    Spacer(minLength: 112)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBeltSelectionButton
        }
                .overlay(
                    alignment: .topLeading
                ) {
                    quickMenuOverlay
                }
                )

        let lifecycleContent = AnyView(
            baseContent
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: Notification.Name(
                            "KMI_GLOBAL_SEARCH_PICK"
                        )
                    )
                ) { notification in
                    guard let key = notification.object as? String else {
                        return
                    }

                    pickedExercise =
                        ExerciseSelection.fromSearchKey(key)
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: Notification.Name(
                            "KMI_HOME_SHARE_PDF"
                        )
                    )
                ) { _ in
                    guard !isAbroadUser else {
                        pdfExportErrorMessage =
                            tr(
                                "יצירת PDF אינה זמינה במצב חו״ל.",
                                "PDF export is unavailable in abroad mode."
                            )
                        return
                    }

                    guard !effectiveUpcomingTrainings.isEmpty else {
                        pdfExportErrorMessage =
                            tr(
                                "אין אימונים זמינים ליצירת PDF.",
                                "There are no training sessions available for PDF export."
                            )
                        return
                    }

                    shareUpcomingTrainingsPDF()
                }
                .task {
            clearExpiredSubscriptionFlagsIfNeeded()
            reloadTrainingsIfNeeded()
        }
        .onAppear {
            clearExpiredSubscriptionFlagsIfNeeded()
            startCoachBroadcastListener()
            openPendingCoachBroadcastIfNeeded()
        }
        .onDisappear {
            stopCoachBroadcastListener()
        }
                .refreshable {
                    clearExpiredSubscriptionFlagsIfNeeded()
                    reloadTrainingsIfNeeded()
                }
                )

                let observedContent = AnyView(
                    lifecycleContent
                .onChange(of: auth.userRegion) { _, _ in
            reloadTrainingsIfNeeded()
        }
        .onChange(of: auth.userBranch) { _, _ in
            reloadTrainingsIfNeeded()
            startCoachBroadcastListener()
        }
        .onChange(of: auth.userGroup) { _, _ in
            reloadTrainingsIfNeeded()
            startCoachBroadcastListener()
        }
        .onChange(of: storedRegion) { _, _ in
            reloadTrainingsIfNeeded()
        }
        .onChange(of: storedActiveBranch) { _, _ in
            reloadTrainingsIfNeeded()
            startCoachBroadcastListener()
        }
        .onChange(of: storedBranch) { _, _ in
            reloadTrainingsIfNeeded()
            startCoachBroadcastListener()
        }
        .onChange(of: storedActiveGroup) { _, _ in
            reloadTrainingsIfNeeded()
            startCoachBroadcastListener()
        }
        .onChange(of: storedGroup) { _, _ in
            reloadTrainingsIfNeeded()
            startCoachBroadcastListener()
        }
        .onChange(of: Auth.auth().currentUser?.uid) { _, _ in
            reloadTrainingsIfNeeded()
            startCoachBroadcastListener()
        }
        .onChange(of: pendingCoachBroadcastId) { _, _ in
            openPendingCoachBroadcastIfNeeded()
        }
        .onChange(of: recentCoachMessages.count) { _, newCount in
            if newCount > 0 &&
                (openCoachMessagesFromPush ||
                 openCoachMessagesFromPushLegacy) {
                showCoachMessagesSheet = true
                clearPendingCoachBroadcast()
            }
        }
                        .onReceive(
                            NotificationCenter.default.publisher(
                                for: UIApplication.willEnterForegroundNotification
                            )
                        ) { _ in
                            clearExpiredSubscriptionFlagsIfNeeded()
                            reloadTrainingsIfNeeded()
                            startCoachBroadcastListener()
                            openPendingCoachBroadcastIfNeeded()
                        }
                        )

                        let navigationContent = AnyView(
                            observedContent
                        .navigationDestination(isPresented: $goVoiceAssistant) {
            VoiceAssistantView()
                .navigationBarBackButtonHidden(true)
        }
        .navigationDestination(isPresented: $goMonthly) {
            MonthlyTrainingBoardView()
                .navigationBarBackButtonHidden(true)
        }
        .navigationDestination(isPresented: $goCard) {
            MyProfileView()
                .navigationBarBackButtonHidden(true)
        }
                                .navigationDestination(item: $pickedExercise) { selection in
                                    ExerciseDetailView(
                                        belt: selection.belt,
                                        topicTitle: selection.topicTitle,
                                        item: selection.item
                                    )
                                }
                                )

                                let presentationContent = AnyView(
                                    navigationContent
                                .sheet(isPresented: $showNavigationSheet, onDismiss: {
            selectedTraining = nil
        }) {
            if let training = selectedTraining {
                NavigationSheet(training: training)
            }
        }
        .sheet(isPresented: $showCoachMessagesSheet) {
            CoachMessagesHistorySheet(
                messages: recentCoachMessages,
                isEnglish: isEnglish,
                formatTime: { date in
                    formatCoachMessageTime(date)
                },
                onClose: {
                    showCoachMessagesSheet = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
                                        .sheet(item: $pdfShareItem) { shareItem in
                                            HomePDFShareSheet(
                                                items: [shareItem.url]
                                            )
                                        }
                                        )

                                        return presentationContent
                                        .alert(
                                            tr("לא ניתן לשתף", "Unable to Share"),
            isPresented: Binding(
                get: {
                    pdfExportErrorMessage != nil
                },
                set: { isPresented in
                    if !isPresented {
                        pdfExportErrorMessage = nil
                    }
                }
            )
        ) {
            Button(tr("אישור", "OK"), role: .cancel) {
                pdfExportErrorMessage = nil
            }
        } message: {
            Text(pdfExportErrorMessage ?? "")
        }
        .alert(
            tr(
                "לא ניתן לפתוח אימונים חופשיים",
                "Unable to Open Free Trainings"
            ),
            isPresented: Binding(
                get: {
                    freeSessionsErrorMessage != nil
                },
                set: { isPresented in
                    if !isPresented {
                        freeSessionsErrorMessage = nil
                    }
                }
            )
        ) {
            Button(
                tr("אישור", "OK"),
                role: .cancel
            ) {
                freeSessionsErrorMessage = nil
            }
        } message: {
            Text(freeSessionsErrorMessage ?? "")
        }
        .environment(
            \.layoutDirection,
            screenLayoutDirection
        )
    }
    
    private var bottomBeltSelectionButton: some View {
        Button {
            let target = BeltFlow.nextBeltForUser(
                registeredBelt: resolvedBelt
            )

            nav.push(.beltQuestionsByBelt(belt: target))
        } label: {
            HomePremiumExerciseButton(
                title: buttonTitleForBelt(),
                subtitle: buttonSubtitleForBelt(),
                isEnglish: isEnglish
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 4)
        .background(Color.clear)
    }

    private var quickMenuOverlay: some View {
        GeometryReader { geo in
            let fabWidth: CGFloat = 46
            let panelWidth: CGFloat = 248

            // Android parity:
            // הטאב נמצא בצד שמאל פיזי של המסך גם בעברית וגם באנגלית.
            let fabX = fabWidth / 2
            let fabY: CGFloat = geo.size.height / 2 + 88

            let panelX = fabWidth + 8 + panelWidth / 2
            let panelY: CGFloat = geo.size.height / 2 + 88

            ZStack {
                if showHomeQuickMenu {
                    HomePremiumQuickMenuPanel(
                        title: tr("תפריט מהיר", "Quick Menu"),
                        isEnglish: isEnglish,
                        items: homeQuickMenuItems,
                        onClose: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                showHomeQuickMenu = false
                            }
                        }
                    )
                    .position(x: panelX, y: panelY)
                    .transition(
                        .scale(scale: 0.94)
                        .combined(with: .opacity)
                    )
                    .zIndex(51)
                }

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        showHomeQuickMenu.toggle()
                    }
                } label: {
                    ModernHomeQuickFab(
                        isOpen: showHomeQuickMenu,
                        isEnglish: isEnglish
                    )
                }
                .buttonStyle(.plain)
                .position(x: fabX, y: fabY)
                .accessibilityLabel(
                    showHomeQuickMenu
                    ? tr("סגור תפריט מהיר", "Close quick menu")
                    : tr("פתח תפריט מהיר", "Open quick menu")
                )
                .zIndex(52)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(true)
        .ignoresSafeArea(
            .keyboard,
            edges: .bottom
        )
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }
    
    // MARK: - User Header Card
    private struct HomeUserCard: View {
        let fullName: String
        let role: String
        let region: String
        let branch: String
        let group: String
        let beltText: String
        let isEnglish: Bool
        
        private var isCoach: Bool {
            let clean = role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return clean == "coach" || clean == "trainer" || clean == "מאמן"
        }
        
        private var roleTitle: String {
            if isEnglish {
                return isCoach ? "Coach" : "Trainee"
            } else {
                return isCoach ? "מאמן" : "מתאמן"
            }
        }
        
        private var displayName: String {
            let clean = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            return clean.isEmpty ? (isEnglish ? "User" : "משתמש") : clean
        }
        
        private var branchLine: String {
            [
                TrainingCatalogIOS.displayRegion(region, isEnglish: isEnglish),
                TrainingCatalogIOS.displayBranch(branch, isEnglish: isEnglish)
            ]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        }
        
        private var groupLine: String {
            let cleanGroup = TrainingCatalogIOS
                .displayGroup(group, isEnglish: isEnglish)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if cleanGroup.isEmpty {
                return ""
            }
            
            return isEnglish ? "Group: \(cleanGroup)" : "קבוצה: \(cleanGroup)"
        }
        
        private var beltLine: String {
            if isCoach {
                return ""
            }
            
            let cleanBelt = beltText.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanBelt.isEmpty {
                return ""
            }
            
            return isEnglish ? "Belt: \(cleanBelt)" : "חגורה: \(cleanBelt)"
        }
        
        private var textAlignment: TextAlignment {
            isEnglish ? .leading : .trailing
        }
        
        private var frameAlignment: Alignment {
            isEnglish ? .leading : .trailing
        }
        
        private var stackAlignment: HorizontalAlignment {
            isEnglish ? .leading : .trailing
        }
        
        private var rowDirection: LayoutDirection {
            isEnglish ? .leftToRight : .rightToLeft
        }
        
        private var accentColor: Color {
            isCoach
            ? Color(red: 0.50, green: 0.11, blue: 0.64)
            : Color(red: 0.02, green: 0.45, blue: 0.78)
        }
        
        var body: some View {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(0.22),
                                    accentColor.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Circle()
                        .stroke(accentColor.opacity(0.24), lineWidth: 1)
                    
                    Image(systemName: isCoach ? "checkmark.seal.fill" : "person.fill")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(accentColor)
                }
                .frame(width: 44, height: 44)
                
                VStack(alignment: stackAlignment, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(displayName)
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(Color.black.opacity(0.86))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity, alignment: frameAlignment)
                            .multilineTextAlignment(textAlignment)
                        
                        Text(roleTitle)
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(accentColor.opacity(0.12))
                            )
                    }
                    .environment(\.layoutDirection, rowDirection)
                    
                    if !branchLine.isEmpty {
                        Text(branchLine)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.58))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity, alignment: frameAlignment)
                            .multilineTextAlignment(textAlignment)
                    }
                    
                    if !groupLine.isEmpty {
                        Text(groupLine)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.66))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity, alignment: frameAlignment)
                            .multilineTextAlignment(textAlignment)
                    }
                    
                    if !beltLine.isEmpty {
                        Text(beltLine)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.70))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity, alignment: frameAlignment)
                            .multilineTextAlignment(textAlignment)
                    }
                }
            }
            .environment(\.layoutDirection, rowDirection)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.32), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Week Header
    
    private var currentWeekSubtitle: String {
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        
        if isEnglish {
            return "Dates: \(englishWeekdayName(from: start)) \(shortDate(start))–\(englishWeekdayName(from: end)) \(shortDate(end))"
        } else {
            return "תאריכים: \(hebrewWeekdayName(from: start)) \(shortDate(start))–\(hebrewWeekdayName(from: end)) \(shortDate(end))"
        }
    }
    
    private func startOfNext7Days(from date: Date) -> Date {
        calendar.startOfDay(for: date)
    }
    
    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isEnglish ? "en_US_POSIX" : "he_IL")
        formatter.calendar = calendar
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: date)
    }
    
    private func hebrewWeekdayName(from date: Date) -> String {
        let weekday = calendar.component(.weekday, from: date)
        switch weekday {
        case 1: return "יום ראשון"
        case 2: return "יום שני"
        case 3: return "יום שלישי"
        case 4: return "יום רביעי"
        case 5: return "יום חמישי"
        case 6: return "יום שישי"
        case 7: return "יום שבת"
        default: return ""
        }
    }
    
    private func englishWeekdayName(from date: Date) -> String {
        let weekday = calendar.component(.weekday, from: date)
        switch weekday {
        case 1: return "Sunday"
        case 2: return "Monday"
        case 3: return "Tuesday"
        case 4: return "Wednesday"
        case 5: return "Thursday"
        case 6: return "Friday"
        case 7: return "Saturday"
        default: return ""
        }
    }
    
    // MARK: - Belt CTA
    
    private func buttonTitleForBelt() -> String {
        if isAbroadUser {
            return isEnglish ? "Open exercise library" : "מעבר לספריית התרגילים"
        }

        return isEnglish ? "Go to belt selection" : "מעבר לבחירת חגורה"
    }

    private func buttonSubtitleForBelt() -> String {
        ""
    }
    
    private func beltHeb(_ belt: Belt) -> String {
        switch belt {
        case .white: return "לבנה"
        case .yellow: return "צהובה"
        case .orange: return "כתומה"
        case .green: return "ירוקה"
        case .blue: return "כחולה"
        case .brown: return "חומה"
        case .black: return "שחורה"
        default: return belt.id
        }
    }
    
    private func beltEn(_ belt: Belt) -> String {
        switch belt {
        case .white: return "White"
        case .yellow: return "Yellow"
        case .orange: return "Orange"
        case .green: return "Green"
        case .blue: return "Blue"
        case .brown: return "Brown"
        case .black: return "Black"
        default: return belt.id
        }
    }
    
    // MARK: - Helpers

    private func isTrainingCancelledByHoliday(
        _ training: TrainingData
    ) -> Bool {
        HomeHolidayCalendar
            .isTrainingBlocked(on: training.date)
    }

    @MainActor
    private func shareUpcomingTrainingsPDF() {
        guard !isAbroadUser else {
            pdfExportErrorMessage =
                tr(
                    "לסניפי חו״ל אין כרגע לוח אימונים זמין ליצירת PDF.",
                    "A PDF training schedule is not currently available for international branches."
                )
            return
        }

        guard !effectiveUpcomingTrainings.isEmpty else {
            pdfExportErrorMessage =
                tr(
                    "אין אימונים קרובים ליצירת PDF.",
                    "There are no upcoming trainings available for PDF export."
                )
            return
        }

        do {
            let url =
                try createUpcomingTrainingsPDF()

            pdfShareItem = HomePDFShareItem(
                url: url
            )
        } catch let exportError as HomePDFExportError {
            switch exportError {
            case .noTrainings:
                pdfExportErrorMessage =
                    tr(
                        "אין אימונים זמינים ליצירת PDF.",
                        "No trainings are available for PDF export."
                    )

            case .writeFailed:
                pdfExportErrorMessage =
                    tr(
                        "לא ניתן היה ליצור את קובץ ה־PDF.",
                        "The PDF file could not be created."
                    )
            }
        } catch {
            pdfExportErrorMessage =
                tr(
                    "אירעה שגיאה בעת יצירת קובץ ה־PDF.",
                    "An error occurred while creating the PDF file."
                )
        }
    }

    private func createUpcomingTrainingsPDF() throws -> URL {
        let trainings = effectiveUpcomingTrainings
            .sorted { left, right in
                left.date < right.date
            }

        guard !trainings.isEmpty else {
            throw HomePDFExportError.noTrainings
        }

        let displayedTrainings = Array(
            trainings.prefix(5)
        )

        let pageRect = CGRect(
            x: 0,
            y: 0,
            width: 595,
            height: 842
        )

        let renderer = UIGraphicsPDFRenderer(
            bounds: pageRect
        )

        let pdfData = renderer.pdfData { context in

            let cg = context.cgContext

            let navy = UIColor(
                red: 2/255,
                green: 43/255,
                blue: 74/255,
                alpha: 1
            )

            let blue = UIColor(
                red: 12/255,
                green: 78/255,
                blue: 130/255,
                alpha: 1
            )

            let lightBlue = UIColor(
                red: 234/255,
                green: 246/255,
                blue: 255/255,
                alpha: 1
            )

            let softBlue = UIColor(
                red: 244/255,
                green: 250/255,
                blue: 255/255,
                alpha: 1
            )

            let borderBlue = UIColor(
                red: 191/255,
                green: 213/255,
                blue: 232/255,
                alpha: 1
            )

            var currentY: CGFloat = 0

            func newPage() {
                context.beginPage()
                currentY = 0
            }

            newPage()

            cg.setFillColor(UIColor.white.cgColor)
            cg.fill(pageRect)

            let banner = UIBezierPath()

            banner.move(
                to: CGPoint(x: 595, y: 0)
            )

            banner.addLine(
                to: CGPoint(x: 595, y: 122)
            )

            banner.addLine(
                to: CGPoint(x: 178, y: 122)
            )

            banner.addLine(
                to: CGPoint(x: 238, y: 0)
            )

            banner.close()

            navy.setFill()

            banner.fill()

            UIColor(
                red: 36/255,
                green: 103/255,
                blue: 158/255,
                alpha: 1
            ).setFill()

            let stripeOne = UIBezierPath()

            stripeOne.move(
                to: CGPoint(x: 208, y: 122)
            )

            stripeOne.addLine(
                to: CGPoint(x: 224, y: 122)
            )

            stripeOne.addLine(
                to: CGPoint(x: 284, y: 0)
            )

            stripeOne.addLine(
                to: CGPoint(x: 268, y: 0)
            )

            stripeOne.close()

            stripeOne.fill()

            UIColor(
                red: 128/255,
                green: 183/255,
                blue: 220/255,
                alpha: 1
            ).setFill()

            let stripeTwo = UIBezierPath()

            stripeTwo.move(
                to: CGPoint(x: 230, y: 122)
            )

            stripeTwo.addLine(
                to: CGPoint(x: 238, y: 122)
            )

            stripeTwo.addLine(
                to: CGPoint(x: 298, y: 0)
            )

            stripeTwo.addLine(
                to: CGPoint(x: 290, y: 0)
            )

            stripeTwo.close()

            stripeTwo.fill()

            cg.setStrokeColor(
                navy.cgColor
            )

            cg.setLineWidth(4)

            cg.strokeEllipse(
                in: CGRect(
                    x: 36,
                    y: 18,
                    width: 84,
                    height: 84
                )
            )

            let logoAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: navy
            ]

            NSAttributedString(
                string: "KAMI",
                attributes: logoAttributes
            )
            .draw(
                in: CGRect(
                    x: 46,
                    y: 46,
                    width: 64,
                    height: 30
                )
            )

            let titleStyle = NSMutableParagraphStyle()
            titleStyle.alignment = .right

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 29),
                .foregroundColor: UIColor.white,
                .paragraphStyle: titleStyle
            ]

            let subAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.white,
                .paragraphStyle: titleStyle
            ]

            NSAttributedString(
                string: tr(
                    "מסך הבית",
                    "Home"
                ),
                attributes: titleAttributes
            )
            .draw(
                in: CGRect(
                    x: 250,
                    y: 28,
                    width: 310,
                    height: 40
                )
            )

            NSAttributedString(
                string: tr(
                    "דו״ח אימונים לשבוע הקרוב",
                    "Upcoming weekly trainings"
                ),
                attributes: subAttributes
            )
            .draw(
                in: CGRect(
                    x: 250,
                    y: 66,
                    width: 310,
                    height: 22
                )
            )

            currentY = 136

            let textDark = UIColor(
                red: 15/255,
                green: 23/255,
                blue: 42/255,
                alpha: 1
            )

            let textMuted = UIColor(
                red: 80/255,
                green: 100/255,
                blue: 120/255,
                alpha: 1
            )

            func pdfParagraphStyle(
                alignment: NSTextAlignment
            ) -> NSMutableParagraphStyle {
                let style = NSMutableParagraphStyle()
                style.alignment = alignment
                style.baseWritingDirection = isEnglish
                    ? .leftToRight
                    : .rightToLeft
                style.lineBreakMode = .byTruncatingTail
                return style
            }

            func drawRoundedRectangle(
                _ rect: CGRect,
                fillColor: UIColor,
                strokeColor: UIColor? = nil,
                cornerRadius: CGFloat = 12,
                lineWidth: CGFloat = 1.2
            ) {
                let path = UIBezierPath(
                    roundedRect: rect,
                    cornerRadius: cornerRadius
                )

                fillColor.setFill()
                path.fill()

                if let strokeColor {
                    strokeColor.setStroke()
                    path.lineWidth = lineWidth
                    path.stroke()
                }
                }

                let centeredStyle = pdfParagraphStyle(
                    alignment: .center
                )

                let generatedDateFormatter = DateFormatter()
                generatedDateFormatter.locale = Locale(
                    identifier: isEnglish
                        ? "en_US_POSIX"
                        : "he_IL"
                )
                generatedDateFormatter.calendar = calendar
                generatedDateFormatter.dateFormat = "dd/MM/yyyy"

            let generatedText = tr(
                "תאריך הפקה: \(generatedDateFormatter.string(from: Date()))",
                "Generated: \(generatedDateFormatter.string(from: Date()))"
            )

            let generatedAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(
                    ofSize: 9,
                    weight: .regular
                ),
                .foregroundColor: textMuted,
                .paragraphStyle: pdfParagraphStyle(
                    alignment: .right
                )
            ]

            NSAttributedString(
                string: generatedText,
                attributes: generatedAttributes
            )
            .draw(
                in: CGRect(
                    x: 34,
                    y: currentY,
                    width: pageRect.width - 68,
                    height: 16
                )
            )

            currentY += 22

            let summaryRect = CGRect(
                x: 24,
                y: currentY,
                width: pageRect.width - 48,
                height: 78
            )

            drawRoundedRectangle(
                summaryRect,
                fillColor: lightBlue,
                strokeColor: borderBlue
            )

            let summaryTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 17),
                .foregroundColor: blue,
                .paragraphStyle: pdfParagraphStyle(
                    alignment: .right
                )
            ]

            NSAttributedString(
                string: tr(
                    "אימונים לשבוע הקרוב",
                    "Upcoming trainings"
                ),
                attributes: summaryTitleAttributes
            )
            .draw(
                in: CGRect(
                    x: summaryRect.minX + 22,
                    y: summaryRect.minY + 17,
                    width: summaryRect.width - 44,
                    height: 24
                )
            )

            let countLabelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 10.5),
                .foregroundColor: blue,
                .paragraphStyle: pdfParagraphStyle(
                    alignment: .right
                )
            ]

            NSAttributedString(
                string: tr(
                    "מספר אימונים מוצגים:",
                    "Displayed trainings:"
                ),
                attributes: countLabelAttributes
            )
            .draw(
                in: CGRect(
                    x: summaryRect.midX,
                    y: summaryRect.minY + 46,
                    width: summaryRect.width / 2 - 22,
                    height: 18
                )
            )

            let countAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: navy,
                .paragraphStyle: pdfParagraphStyle(
                    alignment: .left
                )
            ]

            NSAttributedString(
                string: "\(displayedTrainings.count)",
                attributes: countAttributes
            )
            .draw(
                in: CGRect(
                    x: summaryRect.minX + 28,
                    y: summaryRect.minY + 32,
                    width: 90,
                    height: 34
                )
            )

            currentY = summaryRect.maxY + 22

            let detailsTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 17),
                .foregroundColor: blue,
                .paragraphStyle: centeredStyle
            ]

            NSAttributedString(
                string: tr(
                    "פירוט אימונים",
                    "Training details"
                ),
                attributes: detailsTitleAttributes
            )
            .draw(
                in: CGRect(
                    x: 24,
                    y: currentY,
                    width: pageRect.width - 48,
                    height: 24
                )
            )

            currentY += 32

            for (index, training) in displayedTrainings.enumerated() {
                let isCancelled =
                    isTrainingCancelledByHoliday(training)

                let cardHeight: CGFloat =
                    isCancelled ? 116 : 92

                let cardSpacing: CGFloat = 6

                if currentY + cardHeight > 792 {
                    break
                }

                let cardRect = CGRect(
                    x: 24,
                    y: currentY,
                    width: pageRect.width - 48,
                    height: cardHeight
                )

                drawRoundedRectangle(
                    cardRect,
                    fillColor: index.isMultiple(of: 2)
                        ? lightBlue
                        : softBlue,
                    strokeColor: borderBlue
                )

                let dividerX = cardRect.midX

                cg.saveGState()
                cg.setStrokeColor(borderBlue.cgColor)
                cg.setLineWidth(1)
                cg.move(
                    to: CGPoint(
                        x: dividerX,
                        y: cardRect.minY + 22
                    )
                )
                cg.addLine(
                    to: CGPoint(
                        x: dividerX,
                        y: cardRect.maxY - 20
                    )
                )
                cg.strokePath()
                cg.restoreGState()

                let localeIdentifier =
                    isEnglish ? "en_US_POSIX" : "he_IL"

                let dayFormatter = DateFormatter()
                dayFormatter.locale = Locale(
                    identifier: localeIdentifier
                )
                dayFormatter.calendar = calendar
                dayFormatter.dateFormat = "EEEE"

                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(
                    identifier: localeIdentifier
                )
                dateFormatter.calendar = calendar
                dateFormatter.dateFormat = "dd/MM"

                let timeFormatter = DateFormatter()
                timeFormatter.locale = Locale(
                    identifier: "en_US_POSIX"
                )
                timeFormatter.calendar = calendar
                timeFormatter.dateFormat = "HH:mm"

                let dayText = dayFormatter.string(
                    from: training.date
                )

                let dateText = dateFormatter.string(
                    from: training.date
                )

                let startTime = timeFormatter.string(
                    from: training.date
                )

                let endTime = training.endText
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                let timeText = endTime.isEmpty
                    ? startTime
                    : "\(startTime) – \(endTime)"

                let place = TrainingCatalogIOS.displayPlace(
                    training.place,
                    isEnglish: isEnglish
                )
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

                let address = TrainingCatalogIOS.displayAddress(
                    training.address,
                    isEnglish: isEnglish
                )
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

                let coach = TrainingCatalogIOS.displayCoach(
                    training.coach,
                    isEnglish: isEnglish
                )
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

                let rightColumnRect = CGRect(
                    x: dividerX + 18,
                    y: cardRect.minY + 16,
                    width: cardRect.maxX - dividerX - 40,
                    height: cardHeight - 28
                )

                let leftColumnRect = CGRect(
                    x: cardRect.minX + 22,
                    y: cardRect.minY + 16,
                    width: dividerX - cardRect.minX - 44,
                    height: cardHeight - 28
                )

                let rightAlignment: NSTextAlignment =
                    isEnglish ? .left : .right

                let leftAlignment: NSTextAlignment =
                    isEnglish ? .left : .right

                let placeAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 13.5),
                    .foregroundColor: blue,
                    .paragraphStyle: pdfParagraphStyle(
                        alignment: rightAlignment
                    )
                ]

                let labelAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 10.5),
                    .foregroundColor: blue,
                    .paragraphStyle: pdfParagraphStyle(
                        alignment: leftAlignment
                    )
                ]

                let valueAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(
                        ofSize: 12.5,
                        weight: .regular
                    ),
                    .foregroundColor: textDark,
                    .paragraphStyle: pdfParagraphStyle(
                        alignment: leftAlignment
                    )
                ]

                let boldValueAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 13),
                    .foregroundColor: textDark,
                    .paragraphStyle: pdfParagraphStyle(
                        alignment: leftAlignment
                    )
                ]

                let displayedPlace = place.isEmpty
                    ? tr(
                        "מיקום לא הוגדר",
                        "Location not set"
                    )
                    : place

                NSAttributedString(
                    string: displayedPlace,
                    attributes: placeAttributes
                )
                .draw(
                    in: CGRect(
                        x: rightColumnRect.minX,
                        y: rightColumnRect.minY,
                        width: rightColumnRect.width,
                        height: 22
                    )
                )

                let dateLabelAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 10.5),
                    .foregroundColor: blue,
                    .paragraphStyle: pdfParagraphStyle(
                        alignment: rightAlignment
                    )
                ]

                let dateValueAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 13),
                    .foregroundColor: textDark,
                    .paragraphStyle: pdfParagraphStyle(
                        alignment: rightAlignment
                    )
                ]

                NSAttributedString(
                    string: tr(
                        "תאריך ושעה:",
                        "Date and time:"
                    ),
                    attributes: dateLabelAttributes
                )
                .draw(
                    in: CGRect(
                        x: rightColumnRect.minX,
                        y: rightColumnRect.minY + 32,
                        width: rightColumnRect.width,
                        height: 16
                    )
                )

                NSAttributedString(
                    string: "\(dayText) \(dateText) · \(timeText)",
                    attributes: dateValueAttributes
                )
                .draw(
                    in: CGRect(
                        x: rightColumnRect.minX,
                        y: rightColumnRect.minY + 50,
                        width: rightColumnRect.width,
                        height: 20
                    )
                )

                NSAttributedString(
                    string: tr(
                        "כתובת:",
                        "Address:"
                    ),
                    attributes: labelAttributes
                )
                .draw(
                    in: CGRect(
                        x: leftColumnRect.minX,
                        y: leftColumnRect.minY,
                        width: leftColumnRect.width,
                        height: 16
                    )
                )

                NSAttributedString(
                    string: address.isEmpty ? "—" : address,
                    attributes: valueAttributes
                )
                .draw(
                    in: CGRect(
                        x: leftColumnRect.minX,
                        y: leftColumnRect.minY + 18,
                        width: leftColumnRect.width,
                        height: 24
                    )
                )

                NSAttributedString(
                    string: tr(
                        "מאמן:",
                        "Coach:"
                    ),
                    attributes: labelAttributes
                )
                .draw(
                    in: CGRect(
                        x: leftColumnRect.minX,
                        y: leftColumnRect.minY + 48,
                        width: leftColumnRect.width,
                        height: 16
                    )
                )

                NSAttributedString(
                    string: coach.isEmpty ? "—" : coach,
                    attributes: boldValueAttributes
                )
                .draw(
                    in: CGRect(
                        x: leftColumnRect.minX,
                        y: leftColumnRect.minY + 65,
                        width: leftColumnRect.width,
                        height: 18
                    )
                )

                if isCancelled {
                    let cancellationRect = CGRect(
                        x: cardRect.minX + 18,
                        y: cardRect.maxY - 25,
                        width: cardRect.width - 36,
                        height: 18
                    )

                    drawRoundedRectangle(
                        cancellationRect,
                        fillColor: UIColor(
                            red: 255/255,
                            green: 247/255,
                            blue: 237/255,
                            alpha: 1
                        ),
                        strokeColor: UIColor(
                            red: 249/255,
                            green: 115/255,
                            blue: 22/255,
                            alpha: 0.35
                        )
                    )

                    let cancellationStyle =
                        NSMutableParagraphStyle()

                    cancellationStyle.alignment = .center
                    cancellationStyle.baseWritingDirection =
                        isEnglish
                        ? .leftToRight
                        : .rightToLeft

                    let cancellationAttributes:
                        [NSAttributedString.Key: Any] = [
                            .font: UIFont.boldSystemFont(
                                ofSize: 10.5
                            ),
                            .foregroundColor: UIColor(
                                red: 154/255,
                                green: 52/255,
                                blue: 18/255,
                                alpha: 1
                            ),
                            .paragraphStyle:
                                cancellationStyle
                        ]

                    NSAttributedString(
                        string: tr(
                            "האימון מבוטל עקב חג",
                            "Training cancelled due to holiday"
                        ),
                        attributes: cancellationAttributes
                    )
                    .draw(
                        in: cancellationRect.insetBy(
                            dx: 5,
                            dy: 2
                        )
                    )
                }

                currentY =
                    cardRect.maxY + cardSpacing
            }

                // MARK: - PDF Footer

                let footerY: CGFloat = 804

                cg.saveGState()
                cg.setStrokeColor(navy.cgColor)
                cg.setLineWidth(2)
                cg.move(
                    to: CGPoint(
                        x: 0,
                        y: footerY
                    )
                )
                cg.addLine(
                    to: CGPoint(
                        x: pageRect.width,
                        y: footerY
                    )
                )
                cg.strokePath()
                cg.restoreGState()

                let footerLogoCenter = CGPoint(
                    x: 38,
                    y: footerY + 22
                )

                let footerLogoRadius: CGFloat = 13

                cg.saveGState()

                cg.setFillColor(navy.cgColor)
                cg.fillEllipse(
                    in: CGRect(
                        x: footerLogoCenter.x - footerLogoRadius,
                        y: footerLogoCenter.y - footerLogoRadius,
                        width: footerLogoRadius * 2,
                        height: footerLogoRadius * 2
                    )
                )

                cg.setFillColor(UIColor.white.cgColor)
                cg.fillEllipse(
                    in: CGRect(
                        x: footerLogoCenter.x - footerLogoRadius + 3,
                        y: footerLogoCenter.y - footerLogoRadius + 3,
                        width: (footerLogoRadius - 3) * 2,
                        height: (footerLogoRadius - 3) * 2
                    )
                )

                cg.restoreGState()

                let footerLogoStyle = NSMutableParagraphStyle()
                footerLogoStyle.alignment = .center

                let footerLogoAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 6.6),
                    .foregroundColor: navy,
                    .paragraphStyle: footerLogoStyle
                ]

                NSAttributedString(
                    string: "KAMI",
                    attributes: footerLogoAttributes
                )
                .draw(
                    in: CGRect(
                        x: footerLogoCenter.x - footerLogoRadius,
                        y: footerLogoCenter.y - 4,
                        width: footerLogoRadius * 2,
                        height: 10
                    )
                )

                let footerSmallFont = UIFont.systemFont(
                    ofSize: 9,
                    weight: .regular
                )

                let footerLeftStyle = NSMutableParagraphStyle()
                footerLeftStyle.alignment = .left
                footerLeftStyle.baseWritingDirection = .leftToRight

                let footerCenterStyle = NSMutableParagraphStyle()
                footerCenterStyle.alignment = .center
                footerCenterStyle.baseWritingDirection = isEnglish
                    ? .leftToRight
                    : .rightToLeft

                let footerRightStyle = NSMutableParagraphStyle()
                footerRightStyle.alignment = .right
                footerRightStyle.baseWritingDirection = .leftToRight

                let footerLeftAttributes: [NSAttributedString.Key: Any] = [
                    .font: footerSmallFont,
                    .foregroundColor: textMuted,
                    .paragraphStyle: footerLeftStyle
                ]

                let footerCenterAttributes: [NSAttributedString.Key: Any] = [
                    .font: footerSmallFont,
                    .foregroundColor: textMuted,
                    .paragraphStyle: footerCenterStyle
                ]

                let footerRightAttributes: [NSAttributedString.Key: Any] = [
                    .font: footerSmallFont,
                    .foregroundColor: textMuted,
                    .paragraphStyle: footerRightStyle
                ]

                NSAttributedString(
                    string: "Together We Protect",
                    attributes: footerLeftAttributes
                )
                .draw(
                    in: CGRect(
                        x: 62,
                        y: footerY + 16,
                        width: 150,
                        height: 16
                    )
                )

                NSAttributedString(
                    string: tr(
                        "עמוד 1 מתוך 1",
                        "Page 1 of 1"
                    ),
                    attributes: footerCenterAttributes
                )
                .draw(
                    in: CGRect(
                        x: pageRect.midX - 70,
                        y: footerY + 16,
                        width: 140,
                        height: 16
                    )
                )

                NSAttributedString(
                    string: "Krav Maga Israel",
                    attributes: footerRightAttributes
                )
                .draw(
                    in: CGRect(
                        x: pageRect.width - 190,
                        y: footerY + 10,
                        width: 124,
                        height: 14
                    )
                )

                NSAttributedString(
                    string: "www.kmi.org.il",
                    attributes: footerRightAttributes
                )
                .draw(
                    in: CGRect(
                        x: pageRect.width - 190,
                        y: footerY + 23,
                        width: 124,
                        height: 14
                    )
                )

                let flagBlue = UIColor(
                    red: 20/255,
                    green: 85/255,
                    blue: 200/255,
                    alpha: 1
                )

                cg.saveGState()
                cg.setFillColor(flagBlue.cgColor)

                cg.fill(
                    CGRect(
                        x: pageRect.width - 48,
                        y: footerY + 14,
                        width: 28,
                        height: 4
                    )
                )

                cg.fill(
                    CGRect(
                        x: pageRect.width - 48,
                        y: footerY + 28,
                        width: 28,
                        height: 4
                    )
                )

                cg.restoreGState()
                }

        let fileDateFormatter = DateFormatter()
        fileDateFormatter.locale = Locale(
            identifier: "en_US_POSIX"
        )
        fileDateFormatter.calendar = calendar
        fileDateFormatter.dateFormat = "yyyy-MM-dd"

        let dateKey = fileDateFormatter.string(
            from: Date()
        )

        let fileName =
            "KMI_Weekly_Trainings_\(dateKey).pdf"

        let destinationURL =
            FileManager.default.temporaryDirectory
                .appendingPathComponent(fileName)

        do {
            try pdfData.write(
                to: destinationURL,
                options: .atomic
            )

            return destinationURL
        } catch {
            throw HomePDFExportError.writeFailed
        }
    }

    private func reloadTrainingsIfNeeded() {
        if isAbroadUser {
            return
        }

        trainingsVm.loadForCurrentUser(auth: auth)
    }
    
    private func startCoachBroadcastListener() {
        stopCoachBroadcastListener()

        guard let firebaseUser = Auth.auth().currentUser else {
            recentCoachMessages = []
            return
        }

        let currentUid = firebaseUser.uid
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !currentUid.isEmpty else {
            recentCoachMessages = []
            return
        }

        let currentEmail = firebaseUser.email?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let currentName = freeSessionsName
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let currentPhones = [
            storedPhone,
            storedPhoneNumber,
            storedPhoneNumberSnake,
            storedMobile
        ]
        .map { normalizePhone($0) }
        .filter { !$0.isEmpty }

        let currentBranches = resolvedBranches
            .map {
                normalizeCoachBroadcastText($0)
            }
            .filter { !$0.isEmpty }

        let uniqueCurrentBranches =
            Array(Set(currentBranches))

        let currentGroups = resolvedGroups
            .flatMap { group -> [String] in
                let original =
                    normalizeCoachBroadcastText(group)

                let displayed =
                    normalizeCoachBroadcastText(
                        TrainingCatalogIOS.displayGroup(
                            group,
                            isEnglish: false
                        )
                    )

                return [original, displayed]
            }
            .filter { !$0.isEmpty }

        let uniqueCurrentGroups =
            Array(Set(currentGroups))

        coachBroadcastListener = Firestore.firestore()
            .collection("coachBroadcasts")
            .order(by: "createdAt", descending: true)
            .limit(to: 40)
            .addSnapshotListener { snapshot, error in
                if error != nil {
                    return
                }

                let docs = snapshot?.documents ?? []

                let messages = mapCoachBroadcastDocs(
                    docs: docs,
                    currentUid: currentUid,
                    currentEmail: currentEmail,
                    currentPhones: currentPhones,
                    currentName: currentName,
                    currentBranches: uniqueCurrentBranches,
                    currentGroups: uniqueCurrentGroups
                )
                .sorted { left, right in
                    let leftDate = left.sentAt ?? .distantPast
                    let rightDate = right.sentAt ?? .distantPast
                    return leftDate > rightDate
                }

                recentCoachMessages = Array(messages.prefix(5))
            }
    }
    
    private func mapCoachBroadcastDocs(
        docs: [QueryDocumentSnapshot],
        currentUid: String,
        currentEmail: String,
        currentPhones: [String],
        currentName: String,
        currentBranches: [String],
        currentGroups: [String]
    ) -> [CoachHomeMessage] {
        docs
            .filter { doc in
                docTargetsCurrentUser(
                    doc: doc,
                    currentUid: currentUid,
                    currentEmail: currentEmail,
                    currentPhones: currentPhones,
                    currentName: currentName,
                    currentBranches: currentBranches,
                    currentGroups: currentGroups
                )
            }
            .compactMap { doc in
                let text = firstString(
                    doc,
                    keys: ["text", "message", "body", "content"]
                )
                .trimmingCharacters(in: .whitespacesAndNewlines)

                guard !text.isEmpty else { return nil }

                let coachName = firstString(
                    doc,
                    keys: ["coachName", "coach_name", "senderName", "fromName"]
                )
                .trimmingCharacters(in: .whitespacesAndNewlines)

                let sentAt =
                    (doc.get("createdAt") as? Timestamp)?.dateValue() ??
                    (doc.get("sentAt") as? Timestamp)?.dateValue() ??
                    (doc.get("timestamp") as? Timestamp)?.dateValue()

                let branch = firstString(
                    doc,
                    keys: ["branch", "branchName", "branch_name", "targetBranch", "selectedBranch"]
                )

                let group = firstString(
                    doc,
                    keys: ["group", "groupKey", "group_key", "targetGroup", "selectedGroup"]
                )

                return CoachHomeMessage(
                    id: doc.documentID,
                    text: text,
                    coachName: coachName.isEmpty
                    ? (isEnglish ? "Coach" : "המאמן")
                    : coachName,
                    sentAt: sentAt,
                    branch: branch,
                    group: group
                )
            }
    }
    
    private func normalizeCoachBroadcastText(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "־", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .lowercased()
    }
    
    private func normalizePhone(_ raw: String) -> String {
        raw.filter { $0.isNumber }
    }
    
    private func valuesFromDoc(
        _ doc: QueryDocumentSnapshot,
        keys: [String]
    ) -> [String] {
        var values: [String] = []
        
        for key in keys {
            let raw = doc.get(key)
            
            if let stringValue = raw as? String {
                values += stringValue
                    .replacingOccurrences(of: "[", with: "")
                    .replacingOccurrences(of: "]", with: "")
                    .split { char in
                        char == "," || char == ";" || char == "|" || char == "\n"
                    }
                    .map {
                        String($0)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    }
                    .filter { !$0.isEmpty }
            } else if let arrayValue = raw as? [Any] {
                values += arrayValue
                    .map { "\($0)".trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        }
        
        return Array(Set(values))
    }
    
    private func firstString(
        _ doc: QueryDocumentSnapshot,
        keys: [String]
    ) -> String {
        valuesFromDoc(doc, keys: keys).first ?? ""
    }
    
    private func docTargetsCurrentUser(
        doc: QueryDocumentSnapshot,
        currentUid: String,
        currentEmail: String,
        currentPhones: [String],
        currentName: String,
        currentBranches: [String],
        currentGroups: [String]
    ) -> Bool {
        let authorUid = firstString(
            doc,
            keys: ["authorUid", "coachUid", "senderUid"]
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        if !currentUid.isEmpty && authorUid == currentUid {
            return true
        }

        let uidTargets = valuesFromDoc(
            doc,
            keys: [
                "targetUids",
                "targetUid",
                "recipientUids",
                "recipientUid",
                "uids",
                "userIds",
                "userId",
                "targetIds",
                "targetId",
                "participantIds",
                "participantId",
                "selectedUids",
                "selectedUid",
                "traineeUids",
                "traineeUid",
                "traineeIds",
                "traineeId",
                "studentUids",
                "studentUid",
                "studentIds",
                "studentId"
            ]
        )
        
        if !currentUid.isEmpty && uidTargets.contains(where: { $0 == currentUid }) {
            return true
        }
        
        let emailTargets = valuesFromDoc(
            doc,
            keys: [
                "targetEmails",
                "targetEmail",
                "recipientEmails",
                "recipientEmail",
                "emails",
                "selectedEmails"
            ]
        )
        
        if !currentEmail.isEmpty &&
            emailTargets.contains(where: { $0.caseInsensitiveCompare(currentEmail) == .orderedSame }) {
            return true
        }
        
        let phoneTargets = valuesFromDoc(
            doc,
            keys: [
                "targetPhones",
                "targetPhone",
                "recipientPhones",
                "recipientPhone",
                "phones",
                "selectedPhones"
            ]
        )
        .map { normalizePhone($0) }
        .filter { !$0.isEmpty }

        if !currentPhones.isEmpty &&
            phoneTargets.contains(where: { target in
                currentPhones.contains(target)
            }) {
            return true
        }

        let nameTargets = valuesFromDoc(
            doc,
            keys: [
                "targetNames",
                "targetName",
                "recipientNames",
                "recipientName",
                "names",
                "selectedNames"
            ]
        )

        if !currentName.isEmpty &&
            nameTargets.contains(where: { $0.caseInsensitiveCompare(currentName) == .orderedSame }) {
            return true
        }
        
        let docBranches = valuesFromDoc(
            doc,
            keys: [
                "branch",
                "branches",
                "branchName",
                "branch_name",
                "targetBranch",
                "targetBranches",
                "selectedBranch",
                "selectedBranches"
            ]
        )
        .map { normalizeCoachBroadcastText($0) }
        
        let docGroups = valuesFromDoc(
            doc,
            keys: [
                "group",
                "groups",
                "groupKey",
                "group_key",
                "targetGroup",
                "targetGroups",
                "selectedGroup",
                "selectedGroups"
            ]
        )
        .map { normalizeCoachBroadcastText($0) }
        
        let branchMatches =
            !currentBranches.isEmpty &&
            currentBranches.contains { currentBranch in
                docBranches.contains(currentBranch)
            }

        let groupMatches =
            !currentGroups.isEmpty &&
            currentGroups.contains { currentGroup in
                docGroups.contains(currentGroup)
            }

        return branchMatches && groupMatches
    }
    
    private func openPendingCoachBroadcastIfNeeded() {
        let shouldOpen =
            openCoachMessagesFromPush ||
            openCoachMessagesFromPushLegacy

        guard shouldOpen else {
            return
        }

        let broadcastId =
            pendingCoachBroadcastId
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        if broadcastId.isEmpty {
            if !recentCoachMessages.isEmpty {
                showCoachMessagesSheet = true
                clearPendingCoachBroadcast()
            }

            return
        }

        let collection =
            Firestore.firestore()
                .collection("coachBroadcasts")

        collection
            .document(broadcastId)
            .getDocument { document, _ in
                if let document,
                   document.exists,
                   let message = coachMessage(
                       from: document
                   ) {
                    presentCoachBroadcastMessage(message)
                    return
                }

                collection
                    .whereField(
                        "broadcastId",
                        isEqualTo: broadcastId
                    )
                    .limit(to: 1)
                    .getDocuments { snapshot, _ in
                        if let document =
                            snapshot?.documents.first,
                           let message = coachMessage(
                               from: document
                           ) {
                            presentCoachBroadcastMessage(message)
                            return
                        }

                        collection
                            .whereField(
                                "broadcast_id",
                                isEqualTo: broadcastId
                            )
                            .limit(to: 1)
                            .getDocuments { secondSnapshot, _ in
                                if let document =
                                    secondSnapshot?.documents.first,
                                   let message = coachMessage(
                                       from: document
                                   ) {
                                    presentCoachBroadcastMessage(
                                        message
                                    )
                                }
                            }
                    }
            }
    }

    private func coachMessage(
        from document: DocumentSnapshot
    ) -> CoachHomeMessage? {
        let data = document.data() ?? [:]

        func firstText(
            _ keys: [String]
        ) -> String {
            for key in keys {
                if let value = data[key] as? String {
                    let clean =
                        value.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )

                    if !clean.isEmpty {
                        return clean
                    }
                }
            }

            return ""
        }

        let text = firstText(
            ["text", "message", "body", "content"]
        )

        guard !text.isEmpty else {
            return nil
        }

        let coachName = firstText(
            [
                "coachName",
                "coach_name",
                "senderName",
                "fromName"
            ]
        )

        let sentAt =
            (data["createdAt"] as? Timestamp)?.dateValue() ??
            (data["sentAt"] as? Timestamp)?.dateValue() ??
            (data["timestamp"] as? Timestamp)?.dateValue()

        return CoachHomeMessage(
            id: document.documentID,
            text: text,
            coachName: coachName.isEmpty
                ? (isEnglish ? "Coach" : "המאמן")
                : coachName,
            sentAt: sentAt,
            branch: firstText(
                [
                    "branch",
                    "branchName",
                    "branch_name",
                    "targetBranch",
                    "selectedBranch"
                ]
            ),
            group: firstText(
                [
                    "group",
                    "groupKey",
                    "group_key",
                    "targetGroup",
                    "selectedGroup"
                ]
            )
        )
    }

    private func presentCoachBroadcastMessage(
        _ message: CoachHomeMessage
    ) {
        var messages = [message]

        messages += recentCoachMessages.filter {
            $0.id != message.id
        }

        recentCoachMessages =
            Array(messages.prefix(5))

        showCoachMessagesSheet = true
        clearPendingCoachBroadcast()
    }

    private func clearPendingCoachBroadcast() {
        openCoachMessagesFromPush = false
        openCoachMessagesFromPushLegacy = false
        pendingCoachBroadcastId = ""

        UserDefaults.standard.removeObject(
            forKey: "coach_broadcast_push_received_at"
        )
    }

    private func stopCoachBroadcastListener() {
        coachBroadcastListener?.remove()
        coachBroadcastListener = nil
    }
    
    private var loadingBlock: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.40))
                    .frame(height: 168)
                    .overlay {
                        ProgressView()
                            .tint(.white)
                    }
                    .padding(.horizontal, 18)
            }
        }
    }
    
    private func emptyBlock(message: String) -> some View {
        Text(message)
            .font(.system(size: 18, weight: .heavy))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.86)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 96)
            .padding(.horizontal, 22)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isCoachUser ? Color.black.opacity(0.36) : Color.white.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .padding(.horizontal, 18)
    }
}

private struct HomeAbroadBranchNotice: View {
    let region: String
    let branch: String
    let isEnglish: Bool

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    var body: some View {
        Text(
            tr(
                "אין מידע על אימונים לשבוע הקרוב בסניפי חו״ל",
                "Training schedule is not available for international branches this week"
            )
        )
        .font(.system(size: 18, weight: .heavy))
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .lineLimit(3)
        .minimumScaleFactor(0.86)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 96)
        .padding(.horizontal, 22)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .padding(.horizontal, 18)
    }
}

private struct HomeTrainingCardAndroidStyle: View {
    let training: TrainingData
    let isEnglish: Bool
    let onNavigateTap: () -> Void

    private var rowDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private func unwrapOptional(_ value: Any) -> Any? {
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .optional else {
            return value
        }

        return mirror.children.first?.value
    }

    private func reflectedString(_ labels: [String]) -> String {
        let mirror = Mirror(reflecting: training)

        for child in mirror.children {
            guard let label = child.label else { continue }
            guard labels.contains(label) else { continue }

            let unwrapped = unwrapOptional(child.value)

            if let value = unwrapped as? String {
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if let value = unwrapped {
                let text = "\(value)".trimmingCharacters(in: .whitespacesAndNewlines)
                if text != "nil" && !text.isEmpty {
                    return text
                }
            }
        }

        return ""
    }

    private func reflectedDate() -> Date? {
        let mirror = Mirror(reflecting: training)

        for child in mirror.children {
            guard let label = child.label else { continue }
            guard [
                "date",
                "startDate",
                "startTime",
                "cal",
                "time"
            ].contains(label) else {
                continue
            }

            let unwrapped = unwrapOptional(child.value)

            if let date = unwrapped as? Date {
                return date
            }

            if let timeInterval = unwrapped as? TimeInterval {
                if timeInterval > 1_000_000_000_000 {
                    return Date(
                        timeIntervalSince1970:
                            timeInterval / 1000
                    )
                }

                if timeInterval > 1_000_000_000 {
                    return Date(
                        timeIntervalSince1970:
                            timeInterval
                    )
                }
            }

            if let millis = unwrapped as? Int64 {
                return Date(
                    timeIntervalSince1970:
                        Double(millis) / 1000
                )
            }

            if let millis = unwrapped as? Int {
                return Date(
                    timeIntervalSince1970:
                        Double(millis) / 1000
                )
            }
        }

        return nil
    }

    private func reflectedDurationMinutes() -> Int {
        let acceptedLabels = [
            "durationMinutes",
            "durationMinuets",
            "duration",
            "dur"
        ]

        let mirror = Mirror(reflecting: training)

        for child in mirror.children {
            guard let label = child.label,
                  acceptedLabels.contains(label) else {
                continue
            }

            let unwrapped = unwrapOptional(child.value)

            if let value = unwrapped as? Int,
               value > 0 {
                return value
            }

            if let value = unwrapped as? Int32,
               value > 0 {
                return Int(value)
            }

            if let value = unwrapped as? Int64,
               value > 0 {
                return Int(value)
            }

            if let value = unwrapped as? Double,
               value > 0 {
                return Int(value.rounded())
            }

            if let value = unwrapped as? String,
               let minutes = Int(
                   value.trimmingCharacters(
                       in: .whitespacesAndNewlines
                   )
               ),
               minutes > 0 {
                return minutes
            }
        }

        return 90
    }

    private var branchTitle: String {
        let rawValue =
            reflectedString(
                [
                    "place",
                    "branch",
                    "branchName",
                    "title",
                    "name"
                ]
            )

        let displayedValue =
            TrainingCatalogIOS.displayPlace(
                rawValue,
                isEnglish: isEnglish
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        if !displayedValue.isEmpty {
            return displayedValue
        }

        return isEnglish
            ? "Training center"
            : "מרכז אימונים"
    }

    private var addressText: String {
        let rawValue =
            reflectedString(
                [
                    "address",
                    "location",
                    "street"
                ]
            )

        return TrainingCatalogIOS.displayAddress(
            rawValue,
            isEnglish: isEnglish
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var coachText: String {
        let rawValue =
            reflectedString(
                [
                    "coach",
                    "coachName",
                    "trainer"
                ]
            )

        return TrainingCatalogIOS.displayCoach(
            rawValue,
            isEnglish: isEnglish
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var dateLine: String {
        guard let date = reflectedDate() else {
            return ""
        }

        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: isEnglish ? "en_US_POSIX" : "he_IL")
        dayFormatter.calendar = Calendar(identifier: .gregorian)
        dayFormatter.dateFormat = "EEEE"

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: isEnglish ? "en_US_POSIX" : "he_IL")
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.dateFormat = "dd/MM"

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.calendar = Calendar(identifier: .gregorian)
        timeFormatter.dateFormat = "HH:mm"

        let durationMinutes =
            reflectedDurationMinutes()

        let endDate =
            Calendar.current.date(
                byAdding: .minute,
                value: durationMinutes,
                to: date
            ) ?? date

        let dayText =
            dayFormatter.string(from: date)

        let shortDateText =
            dateFormatter.string(from: date)

        let startTimeText =
            timeFormatter.string(from: date)

        let endTimeText =
            timeFormatter.string(from: endDate)

        return """
        \(dayText) \(shortDateText) · \(startTimeText) – \(endTimeText)
        """
        .replacingOccurrences(of: "\n", with: "")
    }

    private var isCancelledByHoliday: Bool {
        guard let date = reflectedDate() else {
            return false
        }

        return HomeHolidayCalendar
            .isTrainingBlocked(on: date)
    }

    private var holidayCancellationBanner: some View {
        Text(
            isEnglish
            ? "Training cancelled due to holiday"
            : "האימון מבוטל עקב חג"
        )
        .font(
            .system(
                size: 12,
                weight: .bold
            )
        )
        .foregroundStyle(
            Color(hex: 0xFF9A3412)
        )
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .fill(
                Color(hex: 0xFFFFF7ED)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .stroke(
                Color(hex: 0xFFF97316)
                    .opacity(0.35),
                lineWidth: 1
            )
        )
        .padding(.top, 2)
    }

    var body: some View {
        VStack(spacing: 6) {
            VStack(spacing: 2) {
                Text(branchTitle)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color(hex: 0xFF111827))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                if !dateLine.isEmpty {
                    Text(dateLine)
                        .font(.system(size: 12.4, weight: .black))
                        .foregroundStyle(Color(hex: 0xFF111827))
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                if isCancelledByHoliday {
                    holidayCancellationBanner
                }
            }

            Button {
                guard !addressText.isEmpty else {
                    return
                }

                onNavigateTap()
            } label: {
                HStack(spacing: 10) {
                    if isEnglish {
                        navigationIcon
                        navigationTextBlock
                    } else {
                        navigationTextBlock
                        navigationIcon
                    }
                }
                .environment(\.layoutDirection, rowDirection)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 54)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.92))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.10), radius: 5, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(addressText.isEmpty)
            .opacity(addressText.isEmpty ? 0.72 : 1)

            if !coachText.isEmpty {
                Text(isEnglish ? "Coach: \(coachText)" : "מאמן: \(coachText)")
                    .font(.system(size: 11.2, weight: .bold))
                    .foregroundStyle(Color(hex: 0xFF475569))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.96))
        )
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        .environment(\.layoutDirection, rowDirection)
    }

    private var navigationIcon: some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0xFFE0F2FE))
                .frame(width: 30, height: 30)

            Image(systemName: "location.fill")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color(hex: 0xFF2563EB))
        }
    }

    private var navigationTextBlock: some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 3) {
            Text(isEnglish ? "Navigate" : "ניווט")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color(hex: 0xFF0B1220))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .multilineTextAlignment(textAlignment)

            Text(addressText.isEmpty ? (isEnglish ? "No address" : "אין כתובת") : addressText)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Color(hex: 0xFF475569))
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .multilineTextAlignment(textAlignment)
        }
    }
}

private struct HomePremiumExerciseButton: View {
    let title: String
    let subtitle: String
    let isEnglish: Bool

    private var rowDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let seconds = timeline.date.timeIntervalSinceReferenceDate
            let progress = (seconds.truncatingRemainder(dividingBy: 2.6)) / 2.6
            let shineX = -120 + 320 * progress

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.50, green: 0.00, blue: 1.00),
                                Color(red: 0.25, green: 0.32, blue: 0.72),
                                Color(red: 0.02, green: 0.66, blue: 0.96)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.45),
                                Color.white.opacity(0.00)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)
                    .offset(x: shineX)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.85),
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.85)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )

                HStack(spacing: 8) {
                    if isEnglish {
                        Image(systemName: "star.fill")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(.white)
                    }

                    Text(title)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .multilineTextAlignment(.center)

                    if !isEnglish {
                        Image(systemName: "star.fill")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
                .environment(\.layoutDirection, rowDirection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 12)
            }
            .frame(height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 6)
        }
        .frame(height: 60)
        .frame(maxWidth: .infinity)
    }
}
 

// MARK: - Week Header
private struct WeekHeaderPill: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.17, blue: 0.29).opacity(0.92),
                        Color(red: 0.06, green: 0.37, blue: 0.61).opacity(0.86),
                        Color(red: 0.02, green: 0.17, blue: 0.29).opacity(0.92)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.system(size: 12.6, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(2)
                        .minimumScaleFactor(0.84)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 60)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.80),
                    Color.white.opacity(0.40),
                    Color.white.opacity(0.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CoachMessagesCard: View {
    let title: String
    let coachName: String
    let message: String
    let branch: String
    let group: String
    let sentAtText: String
    let extraCount: Int
    let hasMessages: Bool
    let isEnglish: Bool
    let onOpenRecent: () -> Void

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var stackAlignment: HorizontalAlignment {
        isEnglish ? .leading : .trailing
    }
    
    private var rowDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }
    
    private var branchGroupLine: String {
        let b = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        let g = group.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var parts: [String] = []
        
        if !b.isEmpty {
            parts.append(isEnglish ? "Branch: \(b)" : "סניף: \(b)")
        }
        
        if !g.isEmpty {
            parts.append(isEnglish ? "Group: \(g)" : "קבוצה: \(g)")
        }
        
        return parts.joined(separator: " · ")
    }
    
    private var openRecentText: String {
        if extraCount > 0 {
            return isEnglish
            ? "Open recent messages · +\(extraCount)"
            : "פתח הודעות אחרונות"
        }
        
        return isEnglish
        ? "Open recent messages"
        : "פתח הודעות אחרונות"
    }

    var body: some View {
        VStack(alignment: stackAlignment, spacing: 6) {
            Text(title)
                .font(.system(size: 14.2, weight: .heavy))
                .foregroundStyle(.white.opacity(0.96))
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .multilineTextAlignment(textAlignment)
            
            Button(action: {
                if hasMessages {
                    onOpenRecent()
                }
            }) {
                HStack(spacing: 10) {
                    if isEnglish {
                        personBubble
                    }
                    
                    VStack(alignment: stackAlignment, spacing: 5) {
                        HStack(spacing: 8) {
                            if hasMessages && isEnglish {
                                messagesBadge
                            }
                            
                            Text(coachName)
                                .font(.system(size: 17, weight: .black))
                                .foregroundStyle(Color(red: 0.04, green: 0.30, blue: 0.44))
                                .lineLimit(1)
                                .minimumScaleFactor(0.80)
                                .frame(maxWidth: .infinity, alignment: frameAlignment)
                                .multilineTextAlignment(textAlignment)
                            
                            if hasMessages && !isEnglish {
                                messagesBadge
                            }
                        }
                        .environment(\.layoutDirection, rowDirection)
                        
                        Text(message)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(red: 0.12, green: 0.16, blue: 0.23))
                            .frame(maxWidth: .infinity, alignment: frameAlignment)
                            .multilineTextAlignment(textAlignment)
                            .lineLimit(2)
                            .minimumScaleFactor(0.84)
                        
                        if !branchGroupLine.isEmpty {
                            Text(branchGroupLine)
                                .font(.system(size: 12.3, weight: .semibold))
                                .foregroundStyle(Color(red: 0.30, green: 0.34, blue: 0.40))
                                .frame(maxWidth: .infinity, alignment: frameAlignment)
                                .multilineTextAlignment(textAlignment)
                                .lineLimit(2)
                                .minimumScaleFactor(0.82)
                        }
                        
                        if !sentAtText.isEmpty || hasMessages {
                            VStack(spacing: 3) {
                                if !sentAtText.isEmpty {
                                    Text(sentAtText)
                                        .font(.system(size: 11.4, weight: .bold))
                                        .foregroundStyle(Color(red: 0.39, green: 0.45, blue: 0.55))
                                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                                        .multilineTextAlignment(textAlignment)
                                        .lineLimit(1)
                                }
                                
                                if hasMessages {
                                    Text(openRecentText)
                                        .font(.system(size: 12, weight: .black))
                                        .foregroundStyle(Color(red: 0.01, green: 0.42, blue: 0.68))
                                        .frame(
                                            maxWidth: .infinity,
                                            alignment: isEnglish ? .trailing : .leading
                                        )
                                        .multilineTextAlignment(isEnglish ? .trailing : .leading)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    
                    if !isEnglish {
                        personBubble
                    }
                }
                .environment(\.layoutDirection, rowDirection)
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.98),
                                    Color(red: 0.94, green: 0.98, blue: 1.00).opacity(0.98)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color(red: 0.36, green: 0.78, blue: 0.98), lineWidth: 1.2)
                )
                .shadow(color: Color.black.opacity(0.14), radius: 10, x: 0, y: 6)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var personBubble: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.88, green: 0.97, blue: 1.00))
            
            Image(systemName: "person.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color(red: 0.01, green: 0.41, blue: 0.63))
        }
        .frame(width: 38, height: 38)
    }
    
    private var messagesBadge: some View {
        HStack(spacing: 4) {
            Text(isEnglish ? "Messages" : "הודעות")
                .font(.system(size: 12, weight: .black))
            
            Image(systemName: "envelope.fill")
                .font(.system(size: 10, weight: .black))
        }
        .foregroundStyle(Color(red: 0.01, green: 0.42, blue: 0.68))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color(red: 0.88, green: 0.96, blue: 1.00))
        )
        .overlay(
            Capsule()
                .stroke(Color(red: 0.49, green: 0.83, blue: 0.99), lineWidth: 1)
        )
    }
}

private struct CoachMessagesHistorySheet: View {
    let messages: [CoachHomeMessage]
    let isEnglish: Bool
    let formatTime: (Date?) -> String
    let onClose: () -> Void
    
    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }
    
    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }
    
    private var stackAlignment: HorizontalAlignment {
        isEnglish ? .leading : .trailing
    }
    
    private var rowDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.95, blue: 1.00),
                        Color(red: 0.91, green: 0.98, blue: 1.00)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        if messages.isEmpty {
                            Text(isEnglish ? "No messages right now." : "אין הודעות כרגע.")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color(red: 0.39, green: 0.45, blue: 0.55))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(Color.white.opacity(0.92))
                                )
                        } else {
                            ForEach(messages) { message in
                                CoachMessageHistoryCard(
                                    message: message,
                                    timeText: formatTime(message.sentAt),
                                    isEnglish: isEnglish
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(isEnglish ? "Recent coach messages" : "הודעות אחרונות מהמאמן")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: isEnglish ? .topBarTrailing : .topBarLeading) {
                    Button(action: onClose) {
                        Text(isEnglish ? "Close" : "סגור")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Color(red: 0.36, green: 0.13, blue: 0.71))
                    }
                }
            }
            .environment(\.layoutDirection, rowDirection)
        }
    }
}

private struct CoachMessageHistoryCard: View {
    let message: CoachHomeMessage
    let timeText: String
    let isEnglish: Bool
    
    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }
    
    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }
    
    private var stackAlignment: HorizontalAlignment {
        isEnglish ? .leading : .trailing
    }
    
    private var rowDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }
    
    private var branchGroupLine: String {
        let b = message.branch.trimmingCharacters(in: .whitespacesAndNewlines)
        let g = message.group.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var parts: [String] = []
        
        if !b.isEmpty {
            parts.append(isEnglish ? "Branch: \(b)" : "סניף: \(b)")
        }
        
        if !g.isEmpty {
            parts.append(isEnglish ? "Group: \(g)" : "קבוצה: \(g)")
        }
        
        return parts.joined(separator: " · ")
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.22, green: 0.74, blue: 0.97),
                            Color(red: 0.49, green: 0.23, blue: 0.93)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 5)
            
            VStack(alignment: stackAlignment, spacing: 8) {
                HStack(spacing: 8) {
                    if isEnglish {
                        coachIcon
                    }
                    
                    Text(message.coachName.isEmpty ? (isEnglish ? "Coach" : "המאמן") : message.coachName)
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Color(red: 0.04, green: 0.37, blue: 0.56))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                        .multilineTextAlignment(textAlignment)
                    
                    if !isEnglish {
                        coachIcon
                    }
                }
                .environment(\.layoutDirection, rowDirection)
                
                Text(message.text)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(red: 0.12, green: 0.16, blue: 0.23))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
                
                if !branchGroupLine.isEmpty {
                    Text(branchGroupLine)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 0.30, green: 0.34, blue: 0.40))
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                        .multilineTextAlignment(textAlignment)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.93, green: 0.97, blue: 1.00))
                        )
                }
                
                if !timeText.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .bold))
                        
                        Text(timeText)
                            .font(.system(size: 11.5, weight: .bold))
                    }
                    .foregroundStyle(Color(red: 0.39, green: 0.45, blue: 0.55))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.95, green: 0.97, blue: 0.99))
                    )
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.99, blue: 1.00),
                            Color(red: 0.94, green: 0.97, blue: 0.99)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(red: 0.84, green: 0.90, blue: 0.94), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 9, x: 0, y: 6)
    }
    
    private var coachIcon: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.88, green: 0.97, blue: 1.00))
            
            Image(systemName: "person.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(red: 0.01, green: 0.41, blue: 0.63))
        }
        .frame(width: 30, height: 30)
    }
}

// MARK: - Home Premium Quick Menu

private struct HomeQuickMenuItem: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let action: () -> Void
    
    init(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) {
        self.id = title + systemImage
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }
}

private struct HomePremiumQuickMenuPanel: View {
    let title: String
    let isEnglish: Bool
    let items: [HomeQuickMenuItem]
    let onClose: () -> Void
    
    private var stackAlignment: HorizontalAlignment {
        isEnglish ? .leading : .trailing
    }
    
    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }
    
    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }
    
    var body: some View {
        VStack(alignment: stackAlignment, spacing: 0) {
            HStack(spacing: 8) {
                if isEnglish {
                    Text(title)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(red: 0.09, green: 0.64, blue: 0.29))
                        .lineLimit(1)
                    
                    Spacer(minLength: 0)
                    
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .heavy))
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                            .foregroundStyle(Color(red: 0.09, green: 0.64, blue: 0.29))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(title)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Color(red: 0.09, green: 0.64, blue: 0.29))
                        .lineLimit(1)
                    
                    Spacer(minLength: 0)
                    
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(Color(red: 0.09, green: 0.64, blue: 0.29))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 8)
            
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HomePremiumQuickMenuRow(
                    title: item.title,
                    systemImage: item.systemImage,
                    isEnglish: isEnglish,
                    action: item.action
                )
                
                if index != items.count - 1 {
                    Rectangle()
                        .fill(Color(red: 0.09, green: 0.64, blue: 0.29).opacity(0.18))
                        .frame(height: 0.8)
                        .padding(.horizontal, 10)
                }
            }
        }
        .padding(.bottom, 10)
        .frame(width: 248)
        .compositingGroup()
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(red: 0.97, green: 0.98, blue: 0.97))
                
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.09, green: 0.64, blue: 0.29).opacity(0.08),
                                Color.white.opacity(0.04),
                                Color(red: 0.09, green: 0.64, blue: 0.29).opacity(0.06)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(red: 0.09, green: 0.64, blue: 0.29).opacity(0.24), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 14, x: 0, y: 8)
    }
}

private struct HomePremiumQuickMenuRow: View {
    let title: String
    let systemImage: String
    let isEnglish: Bool
    let action: () -> Void
    
    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }
    
    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }
    
    private var rowDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(
                        .system(
                            size: 16,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        Color(
                            red: 0.09,
                            green: 0.64,
                            blue: 0.29
                        )
                    )
                    .frame(width: 26, height: 26)
                
                Text(title)
                    .font(
                        .system(
                            size: 14,
                            weight: .heavy
                        )
                    )
                    .foregroundStyle(
                        Color(
                            red: 0.04,
                            green: 0.19,
                            blue: 0.12
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(
                        maxWidth: .infinity,
                        alignment: frameAlignment
                    )
                    .multilineTextAlignment(
                        textAlignment
                    )
            }
            .environment(
                \.layoutDirection,
                rowDirection
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ModernHomeQuickFab: View {
    let isOpen: Bool
    let isEnglish: Bool

    var body: some View {
        ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 18,
                topTrailingRadius: 18,
                style: .continuous
            )
            .fill(fabGradient)

            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 18,
                topTrailingRadius: 18,
                style: .continuous
            )
            .stroke(Color.white.opacity(0.72), lineWidth: 1)

            Image(systemName: isOpen ? "xmark" : "line.3.horizontal")
                .font(.system(size: 23, weight: .heavy))
                .foregroundStyle(Color.white)
        }
        .frame(width: 46, height: 84)
        .shadow(
            color: Color.black.opacity(0.24),
            radius: 9,
            x: 0,
            y: 5
        )
    }

    private var fabGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.00, green: 0.91, blue: 0.64),
                Color(red: 1.00, green: 0.76, blue: 0.28),
                Color(red: 1.00, green: 0.66, blue: 0.16)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
    
private struct ExerciseSelection: Identifiable, Hashable {
    let belt: Belt
    let topicTitle: String
    let item: String

    var id: String {
        "\(belt.id)|\(topicTitle)|\(item)"
    }

    static func parseBelt(_ raw: String) -> Belt? {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "white", "לבן", "לבנה":
            return .white
        case "yellow", "צהוב", "צהובה":
            return .yellow
        case "orange", "כתום", "כתומה":
            return .orange
        case "green", "ירוק", "ירוקה":
            return .green
        case "blue", "כחול", "כחולה":
            return .blue
        case "brown", "חום", "חומה":
            return .brown
        case "black", "שחור", "שחורה":
            return .black
        default:
            return nil
        }
    }

    static func fromSearchKey(_ key: String) -> ExerciseSelection? {
        let parts = key.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3 else { return nil }
        guard let belt = parseBelt(parts[0]) else { return nil }

        return ExerciseSelection(
            belt: belt,
            topicTitle: parts[1],
            item: parts[2]
        )
    }
}

// MARK: - Preview
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HomeView(nav: AppNavModel())
                .environmentObject(AuthViewModel())
        }
    }
}
