import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Shared

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
    
    @State private var fabOpen: Bool = false
    @State private var showQuickFab: Bool = false
    @StateObject private var trainingsVm = HomeTrainingsViewModel()

    @State private var goVoiceAssistant: Bool = false
    @State private var goMonthly: Bool = false

    @State private var selectedTraining: TrainingData? = nil
    @State private var showNavigationSheet: Bool = false
    
    // Global search navigation
    @State private var pickedExercise: ExerciseSelection? = nil
    
    // Coach broadcast from Firestore — Android parity
    @State private var lastCoachMessage: String = ""
    @State private var lastCoachFrom: String = ""
    @State private var lastCoachSentAt: Date? = nil
    @State private var coachBroadcastListener: ListenerRegistration? = nil
    
    private let calendar = Calendar(identifier: .gregorian)
    
    private var isEnglish: Bool {
        let values = [
            kmiAppLanguageCode.lowercased(),
            appLanguageRaw.lowercased(),
            initialLanguageCode.lowercased()
        ]
        
        return values.contains("en") || values.contains("english")
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
        
        // Same idea as Android HomeScreen:
        // subscription flags open premium actions only while access time is valid.
        if hasSubscriptionFlags && subscriptionAccessUntil > nowMillis {
            return true
        }
        
        return false
    }
    
    private var lockSuffix: String {
        hasFullAccess ? "" : " 🔒"
    }
    
    private func runPremiumHomeAction(_ action: @escaping () -> Void) {
        closeFab()
        
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
    
    private var resolvedCoachBroadcastName: String {
        let clean = lastCoachFrom.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty {
            return clean
        }
        return isEnglish ? "Coach" : "המאמן"
    }
    
    private var resolvedCoachBroadcastMessage: String {
        let clean = lastCoachMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if clean.isEmpty {
            return isEnglish
                ? "No new messages right now"
                : "אין הודעות חדשות כרגע"
        }
        
        if clean.count > 140 {
            return String(clean.prefix(140)) + "..."
        }
        
        return clean
    }
    
    private var resolvedCoachBroadcastTimeText: String {
        guard let lastCoachSentAt else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "he_IL")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: lastCoachSentAt)
    }
    
    private var homeQuickMenuItems: [HomeQuickMenuItem] {
        [
            HomeQuickMenuItem(
                title: tr("עוזר קולי", "Voice Assistant") + lockSuffix,
                systemImage: "mic.fill"
            ) {
                runPremiumHomeAction {
                    goVoiceAssistant = true
                }
            },
            
            HomeQuickMenuItem(
                title: tr("לוח אימונים חודשי", "Monthly Calendar") + lockSuffix,
                systemImage: "calendar"
            ) {
                runPremiumHomeAction {
                    goMonthly = true
                }
            },
            
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
            },
            
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
        ]
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: isCoachUser
                ? [
                    Color(red: 0.08, green: 0.12, blue: 0.19),
                    Color(red: 0.14, green: 0.23, blue: 0.33),
                    Color(red: 0.05, green: 0.65, blue: 0.91)
                ]
                : [
                    Color(red: 0.50, green: 0.00, blue: 1.00),
                    Color(red: 0.25, green: 0.32, blue: 0.71),
                    Color(red: 0.01, green: 0.66, blue: 0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    
                    Color.clear
                        .frame(height: 0)
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(
                                        key: HomeScrollOffsetPreferenceKey.self,
                                        value: geo.frame(in: .named("homeScroll")).minY
                                    )
                            }
                        )
                    
                    WeekHeaderPill(
                        title: isAbroadUser
                        ? tr("מידע על הסניף המקומי", "Local Branch Information")
                        : tr("אימונים לשבוע הקרוב", "Trainings for the upcoming week"),
                        subtitle: isAbroadUser
                        ? tr("זמני האימונים מתעדכנים מול המאמן המקומי", "Training times are managed by the local coach")
                        : currentWeekSubtitle
                    )
                    .padding(.top, 4)
                    
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
                                        closeFab()
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
                    
                    Spacer(minLength: 10)
                    
                    CoachMessagesCard(
                        title: isAbroadUser
                        ? tr("עדכונים מהסניף המקומי", "Local Branch Updates")
                        : tr("הודעות מהמאמן", "Messages from the Coach"),
                        coachName: resolvedCoachBroadcastName,
                        message: resolvedCoachBroadcastMessage,
                        sentAtText: resolvedCoachBroadcastTimeText,
                        isEnglish: isEnglish
                    )
                    .padding(.horizontal, 18)
                    
                    Spacer(minLength: 132)
                }
            }
            .coordinateSpace(name: "homeScroll")
            .onPreferenceChange(HomeScrollOffsetPreferenceKey.self) { value in
                let shouldShow = value < -24
                if shouldShow != showQuickFab {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showQuickFab = shouldShow
                    }
                }
            }
            
            VStack {
                Spacer()
                
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
                .frame(width: 276)
                .padding(.bottom, 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .zIndex(12)
            
            if fabOpen {
                Color.black.opacity(0.24)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        closeFab()
                    }
                
                HomePremiumQuickMenuPanel(
                    title: tr("תפריט מהיר", "Quick Menu"),
                    isEnglish: isEnglish,
                    items: homeQuickMenuItems,
                    onClose: {
                        closeFab()
                    }
                )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: isEnglish ? .bottomLeading : .bottomTrailing
                )
                .padding(isEnglish ? .leading : .trailing, 16)
                .padding(.bottom, 152)
                .transition(
                    .move(edge: .bottom)
                    .combined(with: .opacity)
                    .combined(with: .scale(scale: 0.96))
                )
            }
            
#if targetEnvironment(simulator)
let shouldShowHomeFab = true
#else
let shouldShowHomeFab = showQuickFab || fabOpen
#endif

if shouldShowHomeFab {
    Button {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            fabOpen.toggle()
        }
    } label: {
        ModernHomeQuickFab(isOpen: fabOpen)
    }
    .buttonStyle(.plain)
    .frame(
        maxWidth: .infinity,
        maxHeight: .infinity,
        alignment: isEnglish ? .bottomTrailing : .bottomLeading
    )
    .padding(isEnglish ? .trailing : .leading, 22)
    .padding(.bottom, 86)
    .transition(.opacity.combined(with: .scale(scale: 0.92)))
    .zIndex(20)
}
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
            reloadTrainingsIfNeeded()
        }
        .onAppear {
            startCoachBroadcastListener()
        }
        .onDisappear {
            stopCoachBroadcastListener()
        }
        .refreshable {
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
            reloadTrainingsIfNeeded()
        }
        .navigationDestination(isPresented: $goVoiceAssistant) {
            VoiceAssistantView()
                .navigationBarBackButtonHidden(true)
        }
        .navigationDestination(isPresented: $goMonthly) {
            MonthlyTrainingBoardView()
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
        .environment(\.layoutDirection, screenLayoutDirection)
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
            return directionalText(
                "Dates: \(englishWeekdayName(from: start)) \(shortDate(start)) – \(englishWeekdayName(from: end)) \(shortDate(end))"
            )
        } else {
            return directionalText(
                "תאריכים: \(hebrewWeekdayName(from: start)) \(shortDate(start)) – \(hebrewWeekdayName(from: end)) \(shortDate(end))"
            )
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
        if isEnglish {
            return "Go to Belt Selection"
        } else {
            return "מעבר לבחירת חגורה"
        }
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

    private func directionalText(_ text: String) -> String {
        if isEnglish {
            return "\u{200E}\(text)\u{200E}"
        } else {
            return "\u{200F}\(text)\u{200F}"
        }
    }
    
    private func reloadTrainingsIfNeeded() {
        if isAbroadUser {
            #if DEBUG
            print("🌍 HOME: skip loading trainings for abroad branch")
            print("🌍 HOME: region =", resolvedRegion)
            print("🌍 HOME: branch =", resolvedBranch)
            #endif
            return
        }

        trainingsVm.loadForCurrentUser(auth: auth)
    }
    
    private func startCoachBroadcastListener() {
        stopCoachBroadcastListener()
        
        guard let currentUid = Auth.auth().currentUser?.uid else {
            lastCoachMessage = ""
            lastCoachFrom = ""
            lastCoachSentAt = nil
            return
        }
        
        coachBroadcastListener = Firestore.firestore()
            .collection("coachBroadcasts")
            .whereField("targetUids", arrayContains: currentUid)
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .addSnapshotListener { snapshot, error in
                if let error {
                    #if DEBUG
                    print("❌ KMI_HOME_BROADCAST iOS listener failed:", error.localizedDescription)
                    #endif
                    return
                }
                
                guard let doc = snapshot?.documents.first else {
                    lastCoachMessage = ""
                    lastCoachFrom = ""
                    lastCoachSentAt = nil
                    return
                }
                
                lastCoachMessage =
                    (doc.get("text") as? String) ??
                    (doc.get("message") as? String) ??
                    ""
                
                lastCoachFrom =
                    (doc.get("coachName") as? String) ??
                    (doc.get("coach_name") as? String) ??
                    (isEnglish ? "Coach" : "המאמן")
                
                if let timestamp = doc.get("createdAt") as? Timestamp {
                    lastCoachSentAt = timestamp.dateValue()
                } else {
                    lastCoachSentAt = nil
                }
                
                #if DEBUG
                print("✅ KMI_HOME_BROADCAST iOS latest:", doc.documentID, lastCoachMessage)
                #endif
            }
    }
    
    private func stopCoachBroadcastListener() {
        coachBroadcastListener?.remove()
        coachBroadcastListener = nil
    }
    
    private func closeFab() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            fabOpen = false
        }
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
            let progress = (seconds.truncatingRemainder(dividingBy: 2.9)) / 2.9

            GeometryReader { geo in
                let bubbleX = -48 + (geo.size.width + 96) * progress

                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.50, green: 0.00, blue: 1.00),
                                    Color(red: 0.25, green: 0.32, blue: 0.71),
                                    Color(red: 0.01, green: 0.66, blue: 0.96)
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
                                    Color.white.opacity(0.07),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 34
                            )
                        )
                        .frame(width: 72, height: 72)
                        .offset(x: bubbleX - geo.size.width / 2)

                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12.5, weight: .heavy))
                            .foregroundStyle(.white)

                        Text(title)
                            .font(.system(size: 14.5, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)
                    }
                    .environment(\.layoutDirection, rowDirection)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.horizontal, 12)
                }
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(Color.white.opacity(0.56), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.13), radius: 6, x: 0, y: 3)
            }
        }
        .frame(height: 38)
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
                .frame(maxWidth: .infinity, alignment: .center)
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
    let sentAtText: String
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

    var body: some View {
        VStack(alignment: stackAlignment, spacing: 10) {
            Text(title)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.white.opacity(0.96))
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .multilineTextAlignment(textAlignment)
            
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.88, green: 0.97, blue: 1.00))
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(red: 0.01, green: 0.41, blue: 0.63))
                }
                .frame(width: 40, height: 40)
                
                VStack(alignment: stackAlignment, spacing: 5) {
                    Text(coachName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(red: 0.05, green: 0.29, blue: 0.43))
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                        .multilineTextAlignment(textAlignment)
                    
                    Text(message)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(red: 0.12, green: 0.16, blue: 0.23))
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                        .multilineTextAlignment(textAlignment)
                        .lineLimit(4)
                    
                    if !sentAtText.isEmpty {
                        Text(sentAtText)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(red: 0.39, green: 0.45, blue: 0.55))
                            .frame(maxWidth: .infinity, alignment: frameAlignment)
                            .multilineTextAlignment(textAlignment)
                    }
                }
            }
            .environment(\.layoutDirection, rowDirection)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(red: 0.49, green: 0.83, blue: 0.99), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 5)
        }
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
    
    private var rowDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }
    
    var body: some View {
        VStack(alignment: stackAlignment, spacing: 0) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Color(red: 0.09, green: 0.64, blue: 0.29))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
                
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color(red: 0.09, green: 0.64, blue: 0.29))
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color(red: 0.09, green: 0.64, blue: 0.29).opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
            }
            .environment(\.layoutDirection, rowDirection)
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
        .frame(width: 270)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.09, green: 0.64, blue: 0.29).opacity(0.14),
                                Color.white,
                                Color(red: 0.97, green: 0.98, blue: 0.97),
                                Color(red: 0.09, green: 0.64, blue: 0.29).opacity(0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(red: 0.09, green: 0.64, blue: 0.29).opacity(0.34), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
    }
}

private struct HomePremiumQuickMenuRow: View {
    let title: String
    let systemImage: String
    let isEnglish: Bool
    let action: () -> Void
    
    private var isLocked: Bool {
        title.hasSuffix(" 🔒")
    }
    
    private var cleanTitle: String {
        isLocked ? String(title.dropLast(2)).trimmingCharacters(in: .whitespacesAndNewlines) : title
    }
    
    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }
    
    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }
    
    private var iconBubble: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.09, green: 0.64, blue: 0.29).opacity(0.10))
            
            Circle()
                .stroke(Color(red: 0.09, green: 0.64, blue: 0.29).opacity(0.24), lineWidth: 1)
            
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color(red: 0.09, green: 0.64, blue: 0.29))
        }
        .frame(width: 24, height: 24)
    }
    
    private var lockIcon: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 14, weight: .black))
            .foregroundStyle(Color(red: 0.96, green: 0.62, blue: 0.04))
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isEnglish {
                    iconBubble
                    
                    Text(cleanTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(red: 0.04, green: 0.19, blue: 0.12))
                        .lineLimit(1)
                        .minimumScaleFactor(0.80)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                        .multilineTextAlignment(textAlignment)
                    
                    if isLocked {
                        lockIcon
                    }
                } else {
                    if isLocked {
                        lockIcon
                    }
                    
                    Text(cleanTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(red: 0.04, green: 0.19, blue: 0.12))
                        .lineLimit(1)
                        .minimumScaleFactor(0.80)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                        .multilineTextAlignment(textAlignment)
                    
                    iconBubble
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ModernHomeQuickFab: View {
    let isOpen: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.09, green: 0.64, blue: 0.29),
                            Color(red: 0.16, green: 0.72, blue: 0.38)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.22), radius: 12, x: 0, y: 7)
            
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.92), lineWidth: 2)
            
            Image(systemName: isOpen ? "xmark" : "line.3.horizontal")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Color.white)
                .rotationEffect(.degrees(0))
        }
        .frame(width: 56, height: 56)
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

private struct HomeScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
