import SwiftUI
import FirebaseAuth
import Shared

struct HomeView: View {

    @ObservedObject var nav: AppNavModel
    @EnvironmentObject private var auth: AuthViewModel

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
    @State private var goMonthly: Bool = false
    @State private var goSummary: Bool = false
    @State private var goFree: Bool = false
    @State private var goCard: Bool = false
    @State private var selectedTraining: TrainingData? = nil
    @State private var showNavigationSheet: Bool = false

    private let calendar = Calendar(identifier: .gregorian)

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

        return "משתמש"
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
        TrainingCatalogIOS.upcomingFor(
            region: resolvedRegion,
            branch: resolvedBranch,
            group: resolvedGroup,
            count: 3
        )
    }

    private var effectiveUpcomingTrainings: [TrainingData] {
        trainingsVm.upcomingTrainings.isEmpty ? fallbackUpcomingTrainings : trainingsVm.upcomingTrainings
    }

    private var effectiveStatusMessage: String? {
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
                        beltText: beltHeb(resolvedBelt)
                    )
                    .padding(.top, 10)

                    WeekHeaderPill(
                        title: isCoachUser ? "אימונים לשבוע הקרוב – מאמן" : "אימונים לשבוע הקרוב",
                        subtitle: currentWeekSubtitle
                    )
                    .padding(.top, 10)

                    if effectiveUpcomingTrainings.isEmpty {
                        if let statusMessage = effectiveStatusMessage {
                            emptyBlock(message: statusMessage)
                                .padding(.top, 6)
                        } else {
                            VStack(spacing: 14) {

                                emptyBlock(message: "לא נמצאו אימונים לשבוע הקרוב")

                                Button {
                                    goMonthly = true
                                } label: {
                                    Label("הצג לוח אימונים חודשי", systemImage: "calendar")
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

                Button {
                    let target = BeltFlow.nextBeltForUser(
                        registeredBelt: resolvedBelt
                    )
                    nav.push(.beltQuestionsByBelt(belt: target))
                } label: {
                    Text(buttonTitleForBelt())
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    isCoachUser
                                    ? Color.black.opacity(0.30)
                                    : Color.white.opacity(0.18)
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(
                                    isCoachUser
                                    ? Color.red.opacity(0.30)
                                    : Color.white.opacity(0.22),
                                    lineWidth: 1
                                )
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
                        nav.push(.voiceAssistant)
                    } label: {
                        FabMenuRow(title: "עוזר קולי", systemImage: "mic.fill")
                    }

                    Button {
                        closeFab()
                        goMonthly = true
                    } label: {
                        FabMenuRow(title: "לוח אימונים חודשי", systemImage: "calendar")
                    }

                    Button {
                        closeFab()

                        let formatter = DateFormatter()
                        formatter.locale = Locale(identifier: "en_US_POSIX")
                        formatter.dateFormat = "yyyy-MM-dd"
                        let todayIso = formatter.string(from: Date())

                        nav.push(.trainingSummary(pickedDateIso: todayIso))
                    } label: {
                        FabMenuRow(title: "סיכום אימון", systemImage: "square.and.pencil")
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
                        FabMenuRow(title: "אימונים חופשיים", systemImage: "plus")
                    }

                    if isCoachUser {
                        Button {
                            closeFab()
                            nav.push(.internalExam(belt: resolvedBelt))
                        } label: {
                            FabMenuRow(title: "מבחן פנימי", systemImage: "checklist")
                        }

                        Button {
                            closeFab()
                            nav.push(.attendance)
                        } label: {
                            FabMenuRow(title: "דו״ח נוכחות", systemImage: "person.text.rectangle")
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 18)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 60)
        }
        .task {
            trainingsVm.loadForCurrentUser(auth: auth)
        }
        .refreshable {
            trainingsVm.loadForCurrentUser(auth: auth)
        }
        .onChange(of: auth.userRegion) { _, _ in
            trainingsVm.loadForCurrentUser(auth: auth)
        }
        .onChange(of: auth.userBranch) { _, _ in
            trainingsVm.loadForCurrentUser(auth: auth)
        }
        .onChange(of: auth.userGroup) { _, _ in
            trainingsVm.loadForCurrentUser(auth: auth)
        }
        .onChange(of: storedRegion) { _, _ in
            trainingsVm.loadForCurrentUser(auth: auth)
        }
        .onChange(of: storedActiveBranch) { _, _ in
            trainingsVm.loadForCurrentUser(auth: auth)
        }
        .onChange(of: storedBranch) { _, _ in
            trainingsVm.loadForCurrentUser(auth: auth)
        }
        .onChange(of: storedActiveGroup) { _, _ in
            trainingsVm.loadForCurrentUser(auth: auth)
        }
        .onChange(of: storedGroup) { _, _ in
            trainingsVm.loadForCurrentUser(auth: auth)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.willEnterForegroundNotification
            )
        ) { _ in
            trainingsVm.loadForCurrentUser(auth: auth)
        }
        .navigationDestination(isPresented: $goMonthly) {
            MonthlyTrainingBoardView()
        }
        .sheet(isPresented: $showNavigationSheet, onDismiss: {
            selectedTraining = nil
        }) {
            if let training = selectedTraining {
                NavigationSheet(training: training)
            }
        }
    }

    // MARK: - User Header Card
    private struct HomeUserCard: View {
        let fullName: String
        let role: String
        let region: String
        let branch: String
        let group: String
        let beltText: String

        private var isCoach: Bool { role.lowercased() == "coach" }

        private var roleTitle: String {
            isCoach ? "מאמן" : "מתאמן"
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

                VStack(alignment: .trailing, spacing: 4) {
                    Text(fullName.isEmpty ? "משתמש" : fullName)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Text(roleTitle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(roleColor.opacity(0.95))
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    if !region.isEmpty || !branch.isEmpty || !group.isEmpty {
                        Text([region, branch, group].filter { !$0.isEmpty }.joined(separator: " • "))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.88))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .multilineTextAlignment(.trailing)
                    }

                    if !beltText.isEmpty && !isCoach {
                        Text("חגורה \(beltText)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.88))
                            .frame(maxWidth: .infinity, alignment: .trailing)
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

        return "(תאריכים: \(hebrewWeekdayName(from: start)) \(shortDate(start))–\(hebrewWeekdayName(from: end)) \(shortDate(end)))"
    }

    private func startOfNext7Days(from date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "he_IL")
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

    // MARK: - Belt CTA

    private func buttonTitleForBelt() -> String {
        let next = BeltFlow.nextBeltForUser(registeredBelt: resolvedBelt)
        return "מעבר לתרגילים – \(beltHeb(next))"
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

    // MARK: - Helpers

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
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))

            Text(message)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(
                isCoachUser
                ? "האימונים יוצגו כאן לפי האזור, הסניף והקבוצה של המאמן"
                : "האימונים יוצגו כאן לפי הסניף והקבוצה של המשתמש"
            )
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
        }
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

// MARK: - FAB Menu Row
private struct FabMenuRow: View {
    let title: String
    let systemImage: String

    private let rowHeight: CGFloat = 54

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width * 0.52

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
            .frame(width: width, height: rowHeight, alignment: .leading)
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

// MARK: - Placeholder
private struct PlaceholderScreen: View {
    let title: String

    var body: some View {
        ZStack {
            KmiGradientBackground(forceTraineeStyle: false)

            VStack(spacing: 14) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Text(title)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(.white)

                Text("המסך הזה עדיין בשלב חיבור מצד iOS")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
            }
            .padding(24)
        }
        .navigationBarBackButtonHidden(true)
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
