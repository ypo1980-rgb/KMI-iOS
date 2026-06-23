import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Shared

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

    // Android parity: quick menu icon must always be visible on Home
    @State private var showHomeQuickMenu: Bool = false
    
    // Global search navigation
    @State private var pickedExercise: ExerciseSelection? = nil
    
    // Coach broadcast from Firestore — Android parity
    // Android: latest message card + recent 5 messages dialog/sheet
    @State private var recentCoachMessages: [CoachHomeMessage] = []
    @State private var showCoachMessagesSheet: Bool = false
    @State private var coachBroadcastListener: ListenerRegistration? = nil
    
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
    
    private var resolvedGroup: String {
        let authValue = auth.userGroup.trimmingCharacters(in: .whitespacesAndNewlines)
        if !authValue.isEmpty { return authValue }
        let active = storedActiveGroup.trimmingCharacters(in: .whitespacesAndNewlines)
        if !active.isEmpty { return active }
        return storedGroup.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isAbroadUser: Bool {
        TrainingCatalogIOS.isAbroadRegion(resolvedRegion) ||
        TrainingCatalogIOS.isAbroadBranch(resolvedBranch)
    }
    
    private var resolvedUserRole: String {
        let value = storedUserRole.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.isEmpty ? "trainee" : value
    }
    
    private var isCoachUser: Bool {
        resolvedUserRole == "coach"
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

    private func runPremiumHomeAction(_ action: @escaping () -> Void) {
        clearExpiredSubscriptionFlagsIfNeeded()

        if hasFullAccess {
            action()
        } else {
            nav.push(.subscription)
        }
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
        
        let fallbackName = storedFullName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fallbackName.isEmpty { return fallbackName }
        
        return fallbackUserName
    }
    
    private var freeSessionsBranch: String {
        let clean = resolvedBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "default_branch" : clean
    }
    
    private var freeSessionsGroupKey: String {
        let clean = resolvedGroup.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "default_group" : clean
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
    
    // ✅ fallback ישיר לפי הנתונים שכבר מוצגים בכרטיס העליון
    private var fallbackUpcomingTrainings: [TrainingData] {
        if isAbroadUser {
            return []
        }

        return TrainingCatalogIOS.upcomingFor(
            region: resolvedRegion,
            branch: resolvedBranch,
            group: resolvedGroup,
            count: 3
        )
    }
    
    private var effectiveUpcomingTrainings: [TrainingData] {
        if isAbroadUser {
            return []
        }

        return trainingsVm.upcomingTrainings.isEmpty
            ? fallbackUpcomingTrainings
            : trainingsVm.upcomingTrainings
    }
    
    private var effectiveStatusMessage: String? {
        if isAbroadUser {
            return nil
        }

        if !trainingsVm.upcomingTrainings.isEmpty {
            return trainingsVm.statusMessage
        }
        
        if !fallbackUpcomingTrainings.isEmpty {
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
                    title: tr("אימונים חופשיים", "Free Sessions") + lockSuffix,
                    systemImage: "plus"
                ) {
                    runPremiumHomeAction {
                        nav.push(
                            .freeSessions(
                                branch: freeSessionsBranch,
                                groupKey: freeSessionsGroupKey,
                                uid: freeSessionsUid,
                                name: freeSessionsName
                            )
                        )
                    }
                }
            )
        }

        return items
    }
    
    var body: some View {
        ZStack {
            KmiAppBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    
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
                    .padding(.top, 8)

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
                                TrainingCardView(
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
                        : (
                            isCoachUser
                            ? tr("הודעות למאמן", "Coach Messages")
                            : tr("הודעות מהמאמן", "Messages from the Coach")
                        ),
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

                    Button {
                        // Android parity:
                        // במסך לפי חגורה פותחים את החגורה הבאה אחרי החגורה הרשומה.
                        // אם המשתמש לבנה / לא מוגדרת חגורה — מתחילים מכתומה.
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
                        .frame(height: 42)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 0)

                    Spacer(minLength: 96)
                }
            }
        }
        .overlay {
            quickMenuOverlay
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("KMI_GLOBAL_SEARCH_PICK")
            )
        ) { notif in
            guard let key = notif.object as? String else { return }
            pickedExercise = ExerciseSelection.fromSearchKey(key)
        }
        .task {
            clearExpiredSubscriptionFlagsIfNeeded()
            reloadTrainingsIfNeeded()
        }
        .onAppear {
            clearExpiredSubscriptionFlagsIfNeeded()
            startCoachBroadcastListener()
        }
        .onDisappear {
            stopCoachBroadcastListener()
        }
        .refreshable {
            clearExpiredSubscriptionFlagsIfNeeded()
            reloadTrainingsIfNeeded()
        }
        .onChange(of: auth.userRegion) { _, _ in
            reloadTrainingsIfNeeded()
        }
        .onChange(of: auth.userBranch) { _, _ in
            reloadTrainingsIfNeeded()
        }
        .onChange(of: auth.userGroup) { _, _ in
            reloadTrainingsIfNeeded()
        }
        .onChange(of: storedRegion) { _, _ in
            reloadTrainingsIfNeeded()
        }
        .onChange(of: storedActiveBranch) { _, _ in
            reloadTrainingsIfNeeded()
        }
        .onChange(of: storedBranch) { _, _ in
            reloadTrainingsIfNeeded()
        }
        .onChange(of: storedActiveGroup) { _, _ in
            reloadTrainingsIfNeeded()
        }
        .onChange(of: storedGroup) { _, _ in
            reloadTrainingsIfNeeded()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.willEnterForegroundNotification
            )
        ) { _ in
            clearExpiredSubscriptionFlagsIfNeeded()
            reloadTrainingsIfNeeded()
            startCoachBroadcastListener()
        }
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
        .environment(\.layoutDirection, screenLayoutDirection)
    }
    
    private var quickMenuOverlay: some View {
        GeometryReader { geo in
            let fabWidth: CGFloat = 44
            let panelWidth: CGFloat = 196

            // עברית: צד ימין כמו Android.
            // אנגלית: צד שמאל.
            let fabX = isEnglish
                ? (fabWidth / 2)
                : (geo.size.width - fabWidth / 2)

            // Android parity: side quick menu tab near the upper content area.
            let fabY: CGFloat = 132

            let panelX = isEnglish
                ? (fabWidth + 8 + panelWidth / 2)
                : (geo.size.width - fabWidth - 8 - panelWidth / 2)

            let panelY: CGFloat = 188

            ZStack {
                if showHomeQuickMenu {
                    HomePremiumQuickMenuPanel(
                        title: tr("קיצורי דרך", "Quick Actions"),
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
                    ? tr("סגור קיצורי דרך", "Close quick actions")
                    : tr("פתח קיצורי דרך", "Open quick actions")
                )
                .zIndex(52)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(true)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .zIndex(50)
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

    private func reloadTrainingsIfNeeded() {
        if isAbroadUser {
            return
        }

        trainingsVm.loadForCurrentUser(auth: auth)
    }
    
    private func startCoachBroadcastListener() {
        stopCoachBroadcastListener()

        let currentUid = Auth.auth().currentUser?.uid
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let currentEmail = Auth.auth().currentUser?.email?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let currentName = freeSessionsName
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let currentBranch = normalizeCoachBroadcastText(resolvedBranch)

        let currentGroup = normalizeCoachBroadcastText(
            TrainingCatalogIOS.displayGroup(
                resolvedGroup,
                isEnglish: false
            )
        )

        guard !currentUid.isEmpty ||
                !currentEmail.isEmpty ||
                !currentName.isEmpty ||
                !currentBranch.isEmpty ||
                !currentGroup.isEmpty else {
            recentCoachMessages = []
            return
        }

        // Android parity:
        // first try direct targeting by UID, which is the source-of-truth path on Android.
        // iOS then still filters defensively, because old documents may contain branch/group/name targets.
        let baseQuery: Query

        if !currentUid.isEmpty {
            baseQuery = Firestore.firestore()
                .collection("coachBroadcasts")
                .whereField("targetUids", arrayContains: currentUid)
                .order(by: "createdAt", descending: true)
                .limit(to: 20)
        } else {
            baseQuery = Firestore.firestore()
                .collection("coachBroadcasts")
                .order(by: "createdAt", descending: true)
                .limit(to: 40)
        }

        coachBroadcastListener = baseQuery.addSnapshotListener { snapshot, error in
            if let error {
                // Do not clear existing messages on listener error.
                // This matches the Android behavior where a transient listener error should not erase the card.
                return
            }

            let docs = snapshot?.documents ?? []

            let directMessages = mapCoachBroadcastDocs(
                docs: docs,
                currentUid: currentUid,
                currentEmail: currentEmail,
                currentName: currentName,
                currentBranch: currentBranch,
                currentGroup: currentGroup
            )

            if !directMessages.isEmpty {
                recentCoachMessages = Array(directMessages.prefix(5))
                return
            }

            // Fallback for older broadcast documents that were not saved with targetUids.
            Firestore.firestore()
                .collection("coachBroadcasts")
                .order(by: "createdAt", descending: true)
                .limit(to: 40)
                .getDocuments { fallbackSnapshot, fallbackError in
                    if fallbackError != nil {
                        return
                    }

                    let fallbackDocs = fallbackSnapshot?.documents ?? []

                    let fallbackMessages = mapCoachBroadcastDocs(
                        docs: fallbackDocs,
                        currentUid: currentUid,
                        currentEmail: currentEmail,
                        currentName: currentName,
                        currentBranch: currentBranch,
                        currentGroup: currentGroup
                    )

                    recentCoachMessages = Array(fallbackMessages.prefix(5))
                }
        }
    }
    
    private func mapCoachBroadcastDocs(
        docs: [QueryDocumentSnapshot],
        currentUid: String,
        currentEmail: String,
        currentName: String,
        currentBranch: String,
        currentGroup: String
    ) -> [CoachHomeMessage] {
        docs
            .filter { doc in
                docTargetsCurrentUser(
                    doc: doc,
                    currentUid: currentUid,
                    currentEmail: currentEmail,
                    currentName: currentName,
                    currentBranch: currentBranch,
                    currentGroup: currentGroup
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
        currentName: String,
        currentBranch: String,
        currentGroup: String
    ) -> Bool {
        let uidTargets = valuesFromDoc(
            doc,
            keys: [
                "targetUids",
                "targetUid",
                "recipientUids",
                "recipientUid",
                "uids",
                "userIds",
                "participantIds",
                "selectedUids"
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
        !currentBranch.isEmpty &&
        docBranches.contains(currentBranch)
        
        let groupMatches =
        !currentGroup.isEmpty &&
        docGroups.contains(currentGroup)
        
        return branchMatches && groupMatches
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
            let progress = (seconds.truncatingRemainder(dividingBy: 2.7)) / 2.7
            
            GeometryReader { geo in
                let shineX = -120 + (geo.size.width + 220) * progress
                
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.58, green: 0.00, blue: 1.00),
                                    Color(red: 0.33, green: 0.27, blue: 0.90),
                                    Color(red: 0.02, green: 0.66, blue: 0.98)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    Color.white.opacity(0.00)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 42
                            )
                        )
                        .frame(width: 76, height: 76)
                        .offset(x: shineX - geo.size.width / 2)
                    
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                    
                    HStack(spacing: 6) {
                        if isEnglish {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(.white)
                        }
                        
                        Text(title)
                            .font(.system(size: 13.5, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.80)
                            .multilineTextAlignment(.center)
                        
                        if !isEnglish {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(.white)
                        }
                    }
                    .environment(\.layoutDirection, rowDirection)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 10)
                }
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .shadow(color: Color.black.opacity(0.13), radius: 6, x: 0, y: 4)
            }
        }
        .frame(height: 36)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Week Header
private struct WeekHeaderPill: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.86)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(2)
                .minimumScaleFactor(0.84)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .padding(.horizontal, 16)
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
        VStack(alignment: stackAlignment, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .heavy))
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
                            .font(.system(size: 16, weight: .semibold))
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
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
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
        .frame(width: 40, height: 40)
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
        .padding(.bottom, 7)
        .frame(width: 196)
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
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(red: 0.09, green: 0.64, blue: 0.29))
                    .frame(width: 19, height: 19)
                
                Text(title)
                    .font(.system(size: 11.5, weight: .heavy))
                    .foregroundStyle(Color(red: 0.04, green: 0.19, blue: 0.12))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
            }
            .environment(\.layoutDirection, rowDirection)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
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
            if isEnglish {
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
                .stroke(Color.white.opacity(0.58), lineWidth: 1)
            } else {
                UnevenRoundedRectangle(
                    topLeadingRadius: 18,
                    bottomLeadingRadius: 18,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .fill(fabGradient)

                UnevenRoundedRectangle(
                    topLeadingRadius: 18,
                    bottomLeadingRadius: 18,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .stroke(Color.white.opacity(0.58), lineWidth: 1)
            }

            Image(systemName: isOpen ? "xmark" : "line.3.horizontal")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Color.white)
        }
        .frame(width: 44, height: 68)
        .shadow(color: Color.black.opacity(0.24), radius: 9, x: 0, y: 5)
    }

    private var fabGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.50, green: 0.00, blue: 1.00),
                Color(red: 0.25, green: 0.32, blue: 0.72),
                Color(red: 0.02, green: 0.66, blue: 0.96)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
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
