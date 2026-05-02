import SwiftUI
import FirebaseAuth
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
    
    @State private var fabOpen: Bool = false
    @StateObject private var trainingsVm = HomeTrainingsViewModel()

    @State private var goVoiceAssistant: Bool = false
    @State private var goMonthly: Bool = false
    @State private var goCard: Bool = false

    @State private var selectedTraining: TrainingData? = nil
    @State private var showNavigationSheet: Bool = false
    
    // Global search navigation
    @State private var pickedExercise: ExerciseSelection? = nil
    
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
    
    var body: some View {
        ZStack {
            KmiGradientBackground(forceTraineeStyle: false)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    
                    HomeUserCard(
                        fullName: storedFullName,
                        role: resolvedUserRole,
                        region: resolvedRegion,
                        branch: resolvedBranch,
                        group: resolvedGroup,
                        beltText: isEnglish ? beltEn(resolvedBelt) : beltHeb(resolvedBelt),
                        isEnglish: isEnglish
                    )
                    .padding(.top, 10)
                    
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
                    .padding(.top, 10)
                    
                    if isAbroadUser {
                        HomeAbroadBranchNotice(
                            region: resolvedRegion,
                            branch: resolvedBranch,
                            isEnglish: isEnglish
                        )
                        .padding(.top, 6)
                    } else if effectiveUpcomingTrainings.isEmpty {
                        if let statusMessage = effectiveStatusMessage {
                            emptyBlock(message: statusMessage)
                                .padding(.top, 6)
                        } else {
                            VStack(spacing: 14) {
                                
                                emptyBlock(
                                    message: tr(
                                        "לא נמצאו אימונים לשבוע הקרוב",
                                        "No trainings were found for the upcoming week"
                                    )
                                )
                                
                                Button {
                                    goMonthly = true
                                } label: {
                                    Label(
                                        tr("הצג לוח אימונים חודשי", "Show monthly training board"),
                                        systemImage: "calendar"
                                    )
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color.white.opacity(0.22))
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 18)
                                
                            }
                            .padding(.top, 6)
                        }
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
                    
                    Spacer(minLength: 22)
                    
                    CoachMessagesCard(
                        title: isAbroadUser
                        ? tr("עדכונים מהסניף המקומי", "Local Branch Updates")
                        : (
                            isCoachUser
                            ? tr("הודעות למאמן", "Coach Messages")
                            : tr("הודעות מהמאמן", "Messages from the Coach")
                        ),
                        message: tr("אין הודעות בשלב זה", "No messages at this time"),
                        meta: isAbroadUser
                        ? tr(
                            "עדכונים מסניפי חו״ל יוצגו כאן לאחר חיבור המאמן המקומי",
                            "Updates from international branches will appear here after the local coach is connected"
                        )
                        : tr("הודעות חדשות יוצגו כאן בהמשך", "New messages will appear here"),
                        isEnglish: isEnglish
                    )
                    .padding(.horizontal, 18)
                    
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
                    .padding(.horizontal, 18)
                    
                    Spacer(minLength: 120)
                }
            }
            
            if fabOpen {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            fabOpen = false
                        }
                    }
                
                VStack(spacing: 10) {

                    Button {
                        closeFab()
                        goVoiceAssistant = true
                    } label: {
                        FabMenuRow(
                            title: tr("עוזר קולי", "Voice Assistant"),
                            systemImage: "mic.fill",
                            isEnglish: isEnglish
                        )
                    }

                    if isAbroadUser {
                        Button {
                            closeFab()
                        } label: {
                            FabMenuRow(
                                title: tr("יש להתעדכן מול המאמן המקומי", "Check with the local coach"),
                                systemImage: "globe.europe.africa.fill",
                                isEnglish: isEnglish
                            )
                        }
                    } else {
                        Button {
                            closeFab()
                            goMonthly = true
                        } label: {
                            FabMenuRow(
                                title: tr("לוח אימונים חודשי", "Monthly Calendar"),
                                systemImage: "calendar",
                                isEnglish: isEnglish
                            )
                        }

                        Button {
                            closeFab()

                            let formatter = DateFormatter()
                            formatter.locale = Locale(identifier: "en_US_POSIX")
                            formatter.dateFormat = "yyyy-MM-dd"
                            let todayIso = formatter.string(from: Date())

                            nav.push(.trainingSummary(pickedDateIso: todayIso))
                        } label: {
                            FabMenuRow(
                                title: tr("סיכום אימון", "Training Summary"),
                                systemImage: "square.and.pencil",
                                isEnglish: isEnglish
                            )
                        }

                        Button {
                            closeFab()
                            nav.push(
                                .freeSessions(
                                    branch: freeSessionsBranch,
                                    groupKey: freeSessionsGroupKey,
                                    uid: freeSessionsUid,
                                    name: freeSessionsName
                                )
                            )
                        } label: {
                            FabMenuRow(
                                title: tr("אימונים חופשיים", "Free Sessions"),
                                systemImage: "plus",
                                isEnglish: isEnglish
                            )
                        }
                    }

                    Button {
                        closeFab()
                        goCard = true
                    } label: {
                        FabMenuRow(
                            title: isCoachUser
                            ? tr("כרטיס מאמן", "Coach Card")
                            : tr("כרטיס אישי", "My Card"),
                            systemImage: isCoachUser ? "checkmark.seal.fill" : "person.crop.circle.fill",
                            isEnglish: isEnglish
                        )
                    }

                    if isCoachUser {
                        Button {
                            closeFab()
                            nav.push(.internalExam(belt: resolvedBelt))
                        } label: {
                            FabMenuRow(
                                title: tr("מבחן פנימי", "Internal Exam"),
                                systemImage: "checklist",
                                isEnglish: isEnglish
                            )
                        }

                        if !isAbroadUser {
                            Button {
                                closeFab()
                                nav.push(.attendance)
                            } label: {
                                FabMenuRow(
                                    title: tr("דו״ח נוכחות", "Attendance Report"),
                                    systemImage: "person.text.rectangle",
                                    isEnglish: isEnglish
                                )
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: isEnglish ? .bottomLeading : .bottomTrailing
                )
                .padding(isEnglish ? .leading : .trailing, 18)
                .padding(.bottom, 88)
            }
            
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    fabOpen.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.92))
                        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.65))
                        .rotationEffect(.degrees(fabOpen ? 45 : 0))
                }
                .frame(width: 56, height: 56)
            }
            .buttonStyle(.plain)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: isEnglish ? .bottomLeading : .bottomTrailing
            )
            .padding(isEnglish ? .leading : .trailing, 26)
            .padding(.bottom, 60)
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

        private var locationLine: String {
            [
                TrainingCatalogIOS.displayRegion(region, isEnglish: isEnglish),
                TrainingCatalogIOS.displayBranch(branch, isEnglish: isEnglish),
                TrainingCatalogIOS.displayGroup(group, isEnglish: isEnglish)
            ]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
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
        
        private var roleColor: Color {
            isCoach ? Color(hex: 0xFF6A1B9A) : Color.white
        }
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: isCoach ? "checkmark.seal.fill" : "person.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(roleColor)
                    .frame(width: 34, height: 34)
                
                VStack(alignment: stackAlignment, spacing: 4) {
                    Text(displayName)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                        .multilineTextAlignment(textAlignment)
                    
                    Text(roleTitle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(roleColor.opacity(0.95))
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                        .multilineTextAlignment(textAlignment)
                    
                    if !locationLine.isEmpty {
                        Text(locationLine)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.88))
                            .frame(maxWidth: .infinity, alignment: frameAlignment)
                            .multilineTextAlignment(textAlignment)
                    }
                    
                    if !beltText.isEmpty && !isCoach {
                        Text(isEnglish ? "Belt \(beltText)" : "חגורה \(beltText)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.88))
                            .frame(maxWidth: .infinity, alignment: frameAlignment)
                            .multilineTextAlignment(textAlignment)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        isCoach
                        ? Color.black.opacity(0.40)
                        : Color.white.opacity(0.16)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isCoach
                        ? Color.red.opacity(0.35)
                        : Color.white.opacity(0.20),
                        lineWidth: 1
                    )
            )
            .padding(.horizontal, 18)
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
            return isEnglish ? "Open Exercise Library" : "מעבר לספריית התרגילים"
        }

        let next = BeltFlow.nextBeltForUser(registeredBelt: resolvedBelt)
        
        if isEnglish {
            return "Go to exercises – \(beltEn(next))"
        } else {
            return "מעבר לתרגילים – \(beltHeb(next))"
        }
    }

    private func buttonSubtitleForBelt() -> String {
        if isAbroadUser {
            return isEnglish
                ? "The training library is available for all branches"
                : "ספריית התרגילים זמינה לכל הסניפים"
        }

        return isEnglish
            ? "Practice according to your next belt"
            : "תרגול לפי החגורה הבאה שלך"
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
            #if DEBUG
            print("🌍 HOME: skip loading trainings for abroad branch")
            print("🌍 HOME: region =", resolvedRegion)
            print("🌍 HOME: branch =", resolvedBranch)
            #endif
            return
        }

        trainingsVm.loadForCurrentUser(auth: auth)
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
        VStack(
            alignment: isEnglish ? .leading : .trailing,
            spacing: 10
        ) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .frame(
                    maxWidth: .infinity,
                    alignment: isEnglish ? .leading : .trailing
                )
            
            Text(message)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.white)
                .frame(
                    maxWidth: .infinity,
                    alignment: isEnglish ? .leading : .trailing
                )
                .multilineTextAlignment(isEnglish ? .leading : .trailing)
            
            Text(
                isCoachUser
                ? tr(
                    "האימונים יוצגו כאן לפי האזור, הסניף והקבוצה של המאמן",
                    "Trainings will appear here according to the coach’s region, branch and group"
                )
                : tr(
                    "האימונים יוצגו כאן לפי הסניף והקבוצה של המשתמש",
                    "Trainings will appear here according to the user’s branch and group"
                )
            )
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.88))
            .frame(
                maxWidth: .infinity,
                alignment: isEnglish ? .leading : .trailing
            )
            .multilineTextAlignment(isEnglish ? .leading : .trailing)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isCoachUser ? Color.black.opacity(0.40) : Color.white.opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 1)
        )
        .padding(.horizontal, 18)
    }
}

private struct HomeAbroadBranchNotice: View {
    let region: String
    let branch: String
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

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private var branchLine: String {
        let cleanRegion = region.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanRegion.isEmpty && cleanBranch.isEmpty {
            return tr("סניף חו״ל", "Abroad branch")
        }

        return [
            TrainingCatalogIOS.displayRegion(cleanRegion, isEnglish: isEnglish),
            TrainingCatalogIOS.displayBranch(cleanBranch, isEnglish: isEnglish)
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " • ")
    }

    var body: some View {
        VStack(alignment: stackAlignment, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "globe.europe.africa.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text(tr("סניף חו״ל", "International Branch"))
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(.white)

                Spacer(minLength: 0)
            }
            .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)

            Text(branchLine)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .multilineTextAlignment(textAlignment)

            Text(
                tr(
                    "לסניף זה אין כרגע מידע על אימונים שבועיים באפליקציה.",
                    "This branch does not currently have a weekly training schedule in the app."
                )
            )
            .font(.system(size: 17, weight: .heavy))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .multilineTextAlignment(textAlignment)

            Text(
                tr(
                    "ניתן להתעדכן בזמני האימונים מול המאמן המקומי או הנהלת הסניף.",
                    "Please check training times with the local coach or branch management."
                )
            )
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.82))
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .multilineTextAlignment(textAlignment)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
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

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var stackAlignment: HorizontalAlignment {
        isEnglish ? .leading : .trailing
    }

    private var chevronName: String {
        isEnglish ? "chevron.right" : "chevron.left"
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.20))

                Circle()
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)

                Image(systemName: "figure.martial.arts")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: stackAlignment, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
                    .lineLimit(2)
            }

            Image(systemName: chevronName)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.white.opacity(0.92))
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.16))
                )
        }
        .environment(\.layoutDirection, rowDirection)
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.10, green: 0.52, blue: 0.98),
                                Color(red: 0.08, green: 0.76, blue: 0.86),
                                Color(red: 0.18, green: 0.36, blue: 0.94)
                            ],
                            startPoint: isEnglish ? .leading : .trailing,
                            endPoint: isEnglish ? .trailing : .leading
                        )
                    )

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.28),
                                Color.white.opacity(0.06),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(0.22),
            radius: 16,
            x: 0,
            y: 10
        )
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 74, height: 74)
                .blur(radius: 16)
                .offset(x: isEnglish ? -18 : 18, y: -28)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

// MARK: - Week Header
private struct WeekHeaderPill: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.90))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .padding(.horizontal, 18)
    }
}

private struct CoachMessagesCard: View {
    let title: String
    let message: String
    let meta: String
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

    var body: some View {
        VStack(alignment: stackAlignment, spacing: 14) {
            Text(title)
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(Color.black.opacity(0.82))
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .multilineTextAlignment(textAlignment)

            VStack(alignment: stackAlignment, spacing: 10) {
                Text(message)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
                    .padding(.top, 8)

                Text(meta)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.52))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 26)
            .frame(minHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.78))
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - FAB Menu Row
private struct FabMenuRow: View {
    let title: String
    let systemImage: String
    let isEnglish: Bool

    private let rowHeight: CGFloat = 54

    private var rowAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    var body: some View {
        GeometryReader { geo in
            let width = max(210, geo.size.width * 0.52)

            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.70))

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.80))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(width: width, height: rowHeight, alignment: rowAlignment)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
        }
        .frame(height: rowHeight)
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
