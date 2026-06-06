import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct CoachTraineesView: View {

    @EnvironmentObject private var auth: AuthViewModel

    @State private var trainees: [CoachTraineeProfile] = []
    @State private var selectedId: String? = nil
    @State private var searchText: String = ""
    @State private var selectedBeltFilter: String = ""
    @State private var coachNotes: [String: String] = [:]
    @State private var beltAwardDates: [String: [String: String]] = [:]

    @State private var seminarDates: [String: [String: CoachDateEntry]] = [:]
    @State private var campDates: [String: [String: CoachDateEntry]] = [:]
    @State private var certificationDates: [String: [String: CoachDateEntry]] = [:]

    @State private var isLoading = true
    @State private var isSavingNotes = false
    @State private var isSavingBeltDates = false
    @State private var savingCoachDateSectionKey: String? = nil

    @State private var alertText: String?
    @State private var showAlert = false
    @State private var showGroupStatsSheet = false
    @State private var isTopStatsExpanded: Bool = true

    @AppStorage("kmi_app_language") private var kmiAppLanguage: String = ""
    @AppStorage("app_language") private var appLanguage: String = ""
    @AppStorage("initial_language_code") private var initialLanguageCode: String = ""
    @AppStorage("selected_language_code") private var selectedLanguageCode: String = ""

    private var effectiveLanguageCode: String {
        let candidates = [
            kmiAppLanguage,
            appLanguage,
            selectedLanguageCode,
            initialLanguageCode
        ]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        return candidates.first ?? "he"
    }

    private var isEnglish: Bool {
        effectiveLanguageCode.hasPrefix("en")
    }

    private var screenLayoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    private var screenTextAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var screenFrameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "־", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private func normalizeKey(_ value: String) -> String {
        normalize(value).lowercased()
    }

    private func isCoachRole(_ value: String) -> Bool {
        let role = normalizeKey(value)

        return role == "coach" ||
               role == "trainer" ||
               role == "instructor" ||
               role == "מאמן" ||
               role == "מדריך" ||
               role.contains("coach") ||
               role.contains("trainer") ||
               role.contains("instructor") ||
               role.contains("מאמן") ||
               role.contains("מדריך")
    }

    private var isCoach: Bool {
        let defaults = UserDefaults.standard

        let candidates = [
            defaults.string(forKey: "user_role"),
            defaults.string(forKey: "role"),
            defaults.string(forKey: "userRole"),
            defaults.string(forKey: "profile_role"),
            auth.userRole
        ]
            .compactMap { $0 }
            .map { normalizeKey($0) }
            .filter { !$0.isEmpty }

        return candidates.contains { isCoachRole($0) }
    }

    private var visibleTrainees: [CoachTraineeProfile] {
        let query = normalizeKey(searchText)
        let beltFilter = normalizeKey(selectedBeltFilter)

        return trainees.filter { trainee in
            let matchesQuery = query.isEmpty || trainee.matchesSearch(query)
            let matchesBelt = beltFilter.isEmpty || normalizeKey(beltNameForUi(trainee.belt)) == beltFilter

            return matchesQuery && matchesBelt
        }
    }

    private var availableBeltFilters: [String] {
        let beltOrderForUi = isEnglish
            ? ["White", "Yellow", "Orange", "Green", "Blue", "Brown", "Black"]
            : ["לבנה", "צהובה", "כתומה", "ירוקה", "כחולה", "חומה", "שחורה"]

        let belts = Set(
            trainees
                .map { beltNameForUi($0.belt) }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && $0 != "—" }
        )

        return Array(belts).sorted { lhs, rhs in
            let lhsIndex = beltOrderForUi.firstIndex(of: lhs) ?? Int.max
            let rhsIndex = beltOrderForUi.firstIndex(of: rhs) ?? Int.max

            if lhsIndex == rhsIndex {
                return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }

            return lhsIndex < rhsIndex
        }
    }

    private var selectedTrainee: CoachTraineeProfile? {
        visibleTrainees.first(where: { $0.id == selectedId }) ??
        visibleTrainees.first ??
        trainees.first(where: { $0.id == selectedId }) ??
        trainees.first
    }

    private var effectiveBranch: String {
        let defaults = UserDefaults.standard

        let candidates = [
            auth.userBranch,
            defaults.string(forKey: "active_branch"),
            defaults.string(forKey: "activeBranch"),
            defaults.string(forKey: "branch"),
            defaults.string(forKey: "branchesCsv"),
            defaults.string(forKey: "coach_branch"),
            defaults.string(forKey: "selected_branch"),
            defaults.string(forKey: "current_branch")
        ]
            .compactMap { $0 }
            .map { normalize($0) }
            .filter { !$0.isEmpty }

        return candidates.first ?? ""
    }

    private var effectiveGroupKey: String {
        let defaults = UserDefaults.standard

        let candidates = [
            auth.userGroup,
            defaults.string(forKey: "active_group"),
            defaults.string(forKey: "activeGroup"),
            defaults.string(forKey: "primaryGroup"),
            defaults.string(forKey: "groupKey"),
            defaults.string(forKey: "group_key"),
            defaults.string(forKey: "age_group"),
            defaults.string(forKey: "group"),
            defaults.string(forKey: "coach_groupKey"),
            defaults.string(forKey: "selected_groupKey"),
            defaults.string(forKey: "current_groupKey")
        ]
            .compactMap { $0 }
            .map { normalize($0) }
            .filter { !$0.isEmpty }

        return candidates.first ?? ""
    }

    private var effectiveBranchPrimary: String {
        effectiveBranch
            .split(whereSeparator: { char in
                char == "," || char == "•" || char == "|"
            })
            .map { normalize(String($0)) }
            .first(where: { !$0.isEmpty }) ?? effectiveBranch
    }

    private var branchLabel: String {
        effectiveBranch.isEmpty ? tr("לא ידוע", "Unknown") : effectiveBranch
    }

    private var groupLabel: String {
        effectiveGroupKey.isEmpty ? tr("לא ידוע", "Unknown") : effectiveGroupKey
    }

    private var groupStats: CoachGroupStats {
        let statsSource = visibleTrainees
        let totalCount = trainees.count
        let filteredCount = statsSource.count

        let avgAgeValues = statsSource.map(\.age).filter { $0 > 0 }
        let avgAge = avgAgeValues.isEmpty ? 0 : avgAgeValues.reduce(0, +) / avgAgeValues.count

        let avgAttendanceValues = statsSource.map(\.attendancePct).filter { $0 > 0 }
        let avgAttendance = avgAttendanceValues.isEmpty ? 0 : avgAttendanceValues.reduce(0, +) / avgAttendanceValues.count

        let highAttendanceCount = statsSource.filter { $0.attendancePct >= 80 }.count

        let beltOrderForUi = isEnglish
            ? ["White", "Yellow", "Orange", "Green", "Blue", "Brown", "Black"]
            : ["לבנה", "צהובה", "כתומה", "ירוקה", "כחולה", "חומה", "שחורה"]

        let groupedBelts = Dictionary(grouping: statsSource) { trainee in
            beltNameForUi(trainee.belt)
        }

        let beltCounts = groupedBelts
            .map { entry in
                CoachBeltCount(
                    id: entry.key,
                    title: entry.key,
                    count: entry.value.count
                )
            }
            .sorted { lhs, rhs in
                let lhsIndex = beltOrderForUi.firstIndex(of: lhs.title) ?? Int.max
                let rhsIndex = beltOrderForUi.firstIndex(of: rhs.title) ?? Int.max

                if lhsIndex == rhsIndex {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }

                return lhsIndex < rhsIndex
            }

        return CoachGroupStats(
            total: totalCount,
            filtered: filteredCount,
            avgAge: avgAge,
            avgAttendance: avgAttendance,
            highAttendance: highAttendanceCount,
            beltCounts: beltCounts
        )
    }

    private var beltDateOrder: [String] {
        [
            "צהובה",
            "כתומה",
            "ירוקה",
            "כחולה",
            "חומה",
            "שחורה"
        ]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.12, blue: 0.19),
                    Color(red: 0.12, green: 0.23, blue: 0.33),
                    Color(red: 0.05, green: 0.47, blue: 0.73)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if !isCoach {
                coachOnlyView

            } else if isLoading {
                loadingView

            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        contextCard

                        if isTopStatsExpanded {
                            statsCard
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        searchCard

                        beltFilterCard

                        traineeListCard

                        traineeDetailsCard

                        groupStatisticsButton
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
        }
        .environment(\.layoutDirection, screenLayoutDirection)
        .sheet(isPresented: $showGroupStatsSheet) {
            CoachGroupStatsSheet(
                isEnglish: isEnglish,
                branchLabel: branchLabel,
                groupLabel: groupLabel,
                stats: groupStats
            )
            .environment(\.layoutDirection, screenLayoutDirection)
        }
        .onAppear {
            loadTrainees()
        }
        .onChange(of: auth.userBranch) { _, _ in
            loadTrainees()
        }
        .onChange(of: auth.userGroup) { _, _ in
            loadTrainees()
        }
        .onChange(of: trainees.map(\.id)) { _, _ in
            syncSelectedTrainee()
        }
        .onChange(of: searchText) { _, _ in
            syncSelectedTrainee()
        }
        .onChange(of: selectedBeltFilter) { _, _ in
            syncSelectedTrainee()
        }
        .alert(tr("הודעה", "Message"), isPresented: $showAlert) {
            Button(tr("סגור", "Close"), role: .cancel) { }
        } message: {
            Text(alertText ?? "")
        }
    }
    
    private var coachOnlyView: some View {
        VStack(spacing: 12) {
            Spacer()

            Text(tr("המסך זמין למאמנים בלבד", "This screen is available for coaches only"))
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(24)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.white)

            Text(tr("טוען מתאמנים מהשרת...", "Loading trainees from the server..."))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    private var contextCard: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                isTopStatsExpanded.toggle()
            }
        } label: {
            VStack(alignment: isEnglish ? .leading : .trailing, spacing: 9) {
                HStack(spacing: 10) {
                    if isEnglish {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(tr("רשימת המתאמנים", "Trainees list"))
                                .font(.system(size: 22, weight: .black))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.76)

                            Text(tr("ניהול מתאמנים, חגורות, נוכחות והערות מאמן", "Manage trainees, belts, attendance and coach notes"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.72))
                                .lineLimit(2)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: isTopStatsExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(.white.opacity(0.82))
                    } else {
                        Image(systemName: isTopStatsExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(.white.opacity(0.82))

                        Spacer(minLength: 0)

                        VStack(alignment: .trailing, spacing: 3) {
                            Text(tr("רשימת המתאמנים", "Trainees list"))
                                .font(.system(size: 22, weight: .black))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.76)

                            Text(tr("ניהול מתאמנים, חגורות, נוכחות והערות מאמן", "Manage trainees, belts, attendance and coach notes"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.72))
                                .lineLimit(2)
                                .multilineTextAlignment(.trailing)
                        }

                        Image(systemName: "person.3.fill")
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
                .environment(\.layoutDirection, .leftToRight)

                VStack(alignment: isEnglish ? .leading : .trailing, spacing: 4) {
                    Text(tr("סניף: \(branchLabel)", "Branch: \(branchLabel)"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(screenTextAlignment)
                        .frame(maxWidth: .infinity, alignment: screenFrameAlignment)

                    Text(tr("קבוצה: \(groupLabel)", "Group: \(groupLabel)"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(screenTextAlignment)
                        .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.20))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var statsCard: some View {
        VStack(spacing: 9) {
            HStack(spacing: 9) {
                statItem(
                    title: tr("מתאמנים", "Trainees"),
                    value: "\(groupStats.total)",
                    icon: "person.3.fill"
                )

                statItem(
                    title: tr("מסוננים", "Filtered"),
                    value: "\(groupStats.filtered)",
                    icon: "line.3.horizontal.decrease.circle.fill"
                )

                statItem(
                    title: tr("גיל ממוצע", "Avg age"),
                    value: groupStats.avgAge > 0 ? "\(groupStats.avgAge)" : "—",
                    icon: "calendar"
                )
            }

            HStack(spacing: 9) {
                statItem(
                    title: tr("נוכחות", "Attendance"),
                    value: groupStats.avgAttendance > 0 ? "\(groupStats.avgAttendance)%" : "—",
                    icon: "checkmark.circle.fill"
                )

                statItem(
                    title: tr("נוכחות גבוהה", "High attendance"),
                    value: "\(groupStats.highAttendance)",
                    icon: "star.circle.fill"
                )

                statItem(
                    title: tr("חגורות", "Belts"),
                    value: "\(groupStats.beltCounts.count)",
                    icon: "seal.fill"
                )
            }
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var groupStatisticsButton: some View {
        Button {
            showGroupStatsSheet = true
        } label: {
            HStack(spacing: 9) {
                if isEnglish {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 16, weight: .black))

                    Text(tr("סטטיסטיקה לקבוצה", "Group statistics"))
                        .font(.system(size: 15, weight: .heavy))

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .black))
                } else {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .black))

                    Spacer(minLength: 0)

                    Text(tr("סטטיסטיקה לקבוצה", "Group statistics"))
                        .font(.system(size: 15, weight: .heavy))

                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 16, weight: .black))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.17, green: 0.36, blue: 0.92),
                                Color(red: 0.05, green: 0.70, blue: 0.88)
                            ],
                            startPoint: isEnglish ? .leading : .trailing,
                            endPoint: isEnglish ? .trailing : .leading
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 9, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }

    private func statItem(
        title: String,
        value: String,
        icon: String
    ) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.white.opacity(0.86))

            Text(value)
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 82)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
    
    private var searchCard: some View {
        HStack(spacing: 10) {
            if isEnglish {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.45))

                TextField(tr("חיפוש מתאמן", "Search trainee"), text: $searchText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .multilineTextAlignment(.leading)

                if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.38))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.38))
                    }
                    .buttonStyle(.plain)
                }

                TextField(tr("חיפוש מתאמן", "Search trainee"), text: $searchText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .multilineTextAlignment(.trailing)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.45))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color.white.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var beltFilterCard: some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 10) {
            Text(tr("סינון לפי חגורה", "Filter by belt"))
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(screenTextAlignment)
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    beltFilterChip(
                        title: tr("הכל", "All"),
                        value: ""
                    )

                    ForEach(availableBeltFilters, id: \.self) { belt in
                        beltFilterChip(
                            title: belt,
                            value: belt
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
                .padding(.horizontal, 2)
            }
            .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
        }
        .padding(12)
        .background(Color.black.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func beltFilterChip(title: String, value: String) -> some View {
        let isSelected = normalizeKey(selectedBeltFilter) == normalizeKey(value)

        return Button {
            selectedBeltFilter = value
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(isSelected ? Color.black.opacity(0.86) : Color.white.opacity(0.86))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.white.opacity(0.92) : Color.white.opacity(0.14))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.white.opacity(0.95) : Color.white.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var traineeListCard: some View {
        VStack(spacing: 0) {
            Divider()

            if trainees.isEmpty {
                VStack(spacing: 8) {
                    if effectiveBranch.isEmpty || effectiveGroupKey.isEmpty {
                        Text(tr("לא אותרו סניף או קבוצה עבור המאמן.", "No branch or group was found for this coach."))
                        Text(tr("מוצגת רשימת כל המתאמנים.", "Showing all trainees."))
                    } else {
                        Text(tr("לא נמצאו מתאמנים פעילים לסניף ולקבוצה שנבחרו.", "No active trainees were found for the selected branch and group."))
                    }
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.62))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(20)

            } else if visibleTrainees.isEmpty {
                VStack(spacing: 8) {
                    Text(tr("לא נמצאו מתאמנים שתואמים לסינון", "No trainees match this filter"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.68))

                    Text(tr("נסה לשנות חיפוש, חגורה, שם, טלפון, מייל, סניף או קבוצה", "Try changing the search, belt, name, phone, email, branch, or group"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.50))

                    Button {
                        searchText = ""
                        selectedBeltFilter = ""
                    } label: {
                        Text(tr("נקה סינון", "Clear filters"))
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.88))
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(20)

            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(visibleTrainees) { trainee in
                            traineeRow(trainee)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 230)
            }
        }
        .background(Color.white.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func traineeRow(_ trainee: CoachTraineeProfile) -> some View {
        let isSelected = selectedId == trainee.id

        return Button {
            selectedId = trainee.id
        } label: {
            HStack {
                if isEnglish {
                    VStack(alignment: .leading, spacing: 4) {
                        traineeRowTexts(trainee)
                    }

                    Spacer()

                    if isSelected {
                        Text(tr("נבחר", "Selected"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.blue)
                    }
                } else {
                    if isSelected {
                        Text(tr("נבחר", "Selected"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.blue)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        traineeRowTexts(trainee)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color(red: 0.88, green: 0.97, blue: 1.0) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func traineeRowTexts(_ trainee: CoachTraineeProfile) -> some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 7) {
            Text(trainee.fullName)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(.black)
                .multilineTextAlignment(screenTextAlignment)
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)

            let meta = trainee.metaLine(isEnglish: isEnglish)

            if !meta.isEmpty {
                Text(meta)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.50))
                    .multilineTextAlignment(screenTextAlignment)
                    .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                    .lineLimit(2)
            }

            traineeMiniStatsRow(trainee)
        }
    }

    private func traineeMiniStatsRow(_ trainee: CoachTraineeProfile) -> some View {
        let ageText = trainee.age > 0 ? "\(trainee.age)" : "—"
        let beltText = beltNameForUi(trainee.belt)
        let attendanceText = trainee.attendancePct > 0 ? "\(trainee.attendancePct)%" : "—"

        return HStack(spacing: 6) {
            if isEnglish {
                miniStatChip(
                    title: tr("גיל", "Age"),
                    value: ageText,
                    systemImage: "calendar"
                )

                miniStatChip(
                    title: tr("חגורה", "Belt"),
                    value: beltText,
                    systemImage: "seal.fill"
                )

                miniStatChip(
                    title: tr("נוכחות", "Attendance"),
                    value: attendanceText,
                    systemImage: "checkmark.circle.fill"
                )

                Spacer(minLength: 0)

            } else {
                Spacer(minLength: 0)

                miniStatChip(
                    title: tr("נוכחות", "Attendance"),
                    value: attendanceText,
                    systemImage: "checkmark.circle.fill"
                )

                miniStatChip(
                    title: tr("חגורה", "Belt"),
                    value: beltText,
                    systemImage: "seal.fill"
                )

                miniStatChip(
                    title: tr("גיל", "Age"),
                    value: ageText,
                    systemImage: "calendar"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
    }

    private func miniStatChip(
        title: String,
        value: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .heavy))

            Text("\(title): \(value)")
                .font(.system(size: 10, weight: .heavy))
                .lineLimit(1)
        }
        .foregroundStyle(Color.black.opacity(0.66))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.055))
        .clipShape(Capsule())
    }

    private var traineeDetailsCard: some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 12) {
            if let trainee = selectedTrainee {

                traineeProfileHeaderCard(for: trainee)

                traineeQuickInfoGrid(for: trainee)

                Divider()

                CoachBeltAwardDatesSection(
                    isEnglish: isEnglish,
                    beltOrder: beltDateOrder,
                    dates: Binding(
                        get: {
                            beltAwardDates[trainee.id] ?? trainee.beltAwardDates
                        },
                        set: { newValue in
                            beltAwardDates[trainee.id] = newValue
                        }
                    ),
                    isSaving: isSavingBeltDates,
                    onSave: {
                        saveBeltAwardDates(for: trainee)
                    }
                )

                CoachDateEntriesSection(
                    isEnglish: isEnglish,
                    sectionKind: .seminars,
                    entries: Binding(
                        get: {
                            seminarDates[trainee.id] ?? trainee.seminarDates
                        },
                        set: { newValue in
                            seminarDates[trainee.id] = newValue
                        }
                    ),
                    isSaving: savingCoachDateSectionKey == "seminarDates",
                    onSave: {
                        saveCoachDateEntries(
                            for: trainee,
                            firestoreFieldName: "seminarDates",
                            entries: seminarDates[trainee.id] ?? trainee.seminarDates
                        )
                    }
                )

                CoachDateEntriesSection(
                    isEnglish: isEnglish,
                    sectionKind: .camps,
                    entries: Binding(
                        get: {
                            campDates[trainee.id] ?? trainee.campDates
                        },
                        set: { newValue in
                            campDates[trainee.id] = newValue
                        }
                    ),
                    isSaving: savingCoachDateSectionKey == "campDates",
                    onSave: {
                        saveCoachDateEntries(
                            for: trainee,
                            firestoreFieldName: "campDates",
                            entries: campDates[trainee.id] ?? trainee.campDates
                        )
                    }
                )

                CoachDateEntriesSection(
                    isEnglish: isEnglish,
                    sectionKind: .certifications,
                    entries: Binding(
                        get: {
                            certificationDates[trainee.id] ?? trainee.certificationDates
                        },
                        set: { newValue in
                            certificationDates[trainee.id] = newValue
                        }
                    ),
                    isSaving: savingCoachDateSectionKey == "certificationDates",
                    onSave: {
                        saveCoachDateEntries(
                            for: trainee,
                            firestoreFieldName: "certificationDates",
                            entries: certificationDates[trainee.id] ?? trainee.certificationDates
                        )
                    }
                )

                coachNotesCard(for: trainee)

            } else {
                Text(tr("בחר מתאמן מהרשימה למעלה", "Select a trainee from the list above"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func traineeProfileHeaderCard(for trainee: CoachTraineeProfile) -> some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 10) {
            HStack(spacing: 12) {
                if isEnglish {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(Color.blue.opacity(0.88))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(trainee.fullName)
                            .font(.system(size: 25, weight: .black))
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        Text(tr("כרטיס מתאמן", "Trainee profile"))
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Color.black.opacity(0.50))
                    }

                    Spacer(minLength: 0)

                } else {
                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(trainee.fullName)
                            .font(.system(size: 25, weight: .black))
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)

                        Text(tr("כרטיס מתאמן", "Trainee profile"))
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Color.black.opacity(0.50))
                    }

                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(Color.blue.opacity(0.88))
                }
            }

            if !trainee.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !trainee.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

                VStack(alignment: isEnglish ? .leading : .trailing, spacing: 6) {
                    if !trainee.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        contactLine(
                            icon: "envelope.fill",
                            value: trainee.email
                        )
                    }

                    if !trainee.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        contactLine(
                            icon: "phone.fill",
                            value: trainee.phone
                        )
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.95, green: 0.98, blue: 1.0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.blue.opacity(0.14), lineWidth: 1)
        )
    }

    private func contactLine(
        icon: String,
        value: String
    ) -> some View {
        HStack(spacing: 8) {
            if isEnglish {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Color.blue.opacity(0.78))

                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.62))
                    .lineLimit(1)

                Spacer(minLength: 0)

            } else {
                Spacer(minLength: 0)

                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.62))
                    .lineLimit(1)

                Image(systemName: icon)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Color.blue.opacity(0.78))
            }
        }
        .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
    }

    private func traineeQuickInfoGrid(for trainee: CoachTraineeProfile) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                quickInfoTile(
                    title: tr("גיל", "Age"),
                    value: trainee.age > 0 ? "\(trainee.age)" : "—",
                    icon: "calendar"
                )

                quickInfoTile(
                    title: tr("דרגה", "Rank"),
                    value: beltNameForUi(trainee.belt),
                    icon: "seal.fill"
                )
            }

            HStack(spacing: 10) {
                quickInfoTile(
                    title: tr("ותק", "Seniority"),
                    value: trainee.seniority.isEmpty ? "—" : trainee.seniority,
                    icon: "clock.fill"
                )

                quickInfoTile(
                    title: tr("נוכחות 60 יום", "60-day attendance"),
                    value: trainee.attendancePct > 0 ? "\(trainee.attendancePct)%" : "—",
                    icon: "checkmark.circle.fill"
                )
            }

            HStack(spacing: 10) {
                quickInfoTile(
                    title: tr("סניף", "Branch"),
                    value: trainee.branch.isEmpty ? "—" : trainee.branch,
                    icon: "mappin.and.ellipse"
                )

                quickInfoTile(
                    title: tr("קבוצה", "Group"),
                    value: trainee.groupKey.isEmpty ? "—" : trainee.groupKey,
                    icon: "person.3.fill"
                )
            }
        }
    }

    private func quickInfoTile(
        title: String,
        value: String,
        icon: String
    ) -> some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 6) {
            HStack(spacing: 6) {
                if isEnglish {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Color.blue.opacity(0.78))

                    Text(title)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.48))
                        .lineLimit(1)

                    Spacer(minLength: 0)

                } else {
                    Spacer(minLength: 0)

                    Text(title)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.48))
                        .lineLimit(1)

                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Color.blue.opacity(0.78))
                }
            }

            Text(value)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Color.black.opacity(0.84))
                .multilineTextAlignment(screenTextAlignment)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.black.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.055), lineWidth: 1)
        )
    }

    private func coachNotesCard(for trainee: CoachTraineeProfile) -> some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 8) {
            Text(tr("הערות מאמן", "Coach notes"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.gray)
                .multilineTextAlignment(screenTextAlignment)
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)

            TextEditor(
                text: Binding(
                    get: { coachNotes[trainee.id] ?? trainee.coachNotes },
                    set: { coachNotes[trainee.id] = $0 }
                )
            )
            .frame(minHeight: 100)
            .padding(8)
            .background(Color.white)
            .foregroundStyle(.black)
            .multilineTextAlignment(screenTextAlignment)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            )

            Button {
                saveCoachNotes(for: trainee)
            } label: {
                HStack(spacing: 8) {
                    if isSavingNotes {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(isSavingNotes ? tr("שומר...", "Saving...") : tr("שמור הערות", "Save notes"))
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.blue.opacity(0.88))
                )
            }
            .buttonStyle(.plain)
            .disabled(isSavingNotes)
            .opacity(isSavingNotes ? 0.55 : 1.0)
        }
    }

    private func labeledField(_ label: String, _ value: String) -> some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 4) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.gray)
                .multilineTextAlignment(screenTextAlignment)
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)

            Text(value)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.black)
                .multilineTextAlignment(screenTextAlignment)
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
        }
    }

    private func userStringValue(
        from data: [String: Any],
        keys: [String]
    ) -> String {
        for key in keys {
            if let value = data[key] as? String {
                let clean = normalize(value)
                if !clean.isEmpty {
                    return clean
                }
            }

            if let value = data[key], !(value is NSNull) {
                let clean = normalize("\(value)")
                if !clean.isEmpty && clean.lowercased() != "null" {
                    return clean
                }
            }
        }

        return ""
    }

    private func userBoolValue(
        from data: [String: Any],
        keys: [String]
    ) -> Bool {
        for key in keys {
            if let value = data[key] as? Bool {
                return value
            }

            if let value = data[key] as? String {
                let clean = normalizeKey(value)
                if clean == "true" || clean == "1" || clean == "yes" {
                    return true
                }
            }

            if let value = data[key] as? Int {
                return value == 1
            }

            if let value = data[key] as? Double {
                return value == 1
            }
        }

        return false
    }

    private func userRoleValue(from data: [String: Any]) -> String {
        userStringValue(
            from: data,
            keys: [
                "role",
                "userRole",
                "user_role",
                "profile_role",
                "accountRole",
                "userType",
                "type"
            ]
        )
    }

    private func isAdminRole(_ value: String) -> Bool {
        let role = normalizeKey(value)

        return role == "admin" ||
               role == "administrator" ||
               role == "manager" ||
               role.contains("admin") ||
               role.contains("administrator") ||
               role.contains("manager") ||
               role.contains("מנהל") ||
               role.contains("אדמין")
    }

    private func isTraineeRole(_ value: String) -> Bool {
        let role = normalizeKey(value)

        if role.isEmpty {
            return true
        }

        if isAdminRole(role) || isCoachRole(role) {
            return false
        }

        return role == "trainee" ||
               role == "student" ||
               role.contains("trainee") ||
               role.contains("student") ||
               role.contains("מתאמן") ||
               role.contains("חניך")
    }

    private func isTraineeUserDocument(_ data: [String: Any]) -> Bool {
        let role = userRoleValue(from: data)

        if userBoolValue(
            from: data,
            keys: [
                "isAdmin",
                "admin",
                "isManager",
                "manager"
            ]
        ) {
            return false
        }

        if userBoolValue(
            from: data,
            keys: [
                "isCoach",
                "coach",
                "isTrainer",
                "trainer",
                "isInstructor",
                "instructor"
            ]
        ) {
            return false
        }

        if isAdminRole(role) || isCoachRole(role) {
            return false
        }

        return isTraineeRole(role)
    }

    private func readCoachDateEntryMap(from rawValue: Any?) -> [String: CoachDateEntry] {
        let raw = rawValue as? [String: Any] ?? [:]

        return raw.reduce(into: [String: CoachDateEntry]()) { result, entry in
            let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { return }

            if let map = entry.value as? [String: Any] {
                let date = ((map["date"] as? String) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                let description = ((map["description"] as? String) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                result[key] = CoachDateEntry(
                    date: date,
                    description: description
                )
            } else if let dateString = entry.value as? String {
                let date = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
                result[key] = CoachDateEntry(
                    date: date,
                    description: ""
                )
            }
        }
    }

    private func readAttendancePct(from data: [String: Any]) -> Int {
        let directKeys = [
            "attendancePct",
            "attendancePercent",
            "attendancePercentage",
            "attendanceRate",
            "last60AttendancePct",
            "last60DaysAttendancePct",
            "attendanceLast60Days",
            "attendanceLast60DaysPct"
        ]

        for key in directKeys {
            if let value = percentIntValue(from: data[key]) {
                return value
            }
        }

        let nestedKeys = [
            "attendanceStats",
            "attendanceSummary",
            "attendance",
            "stats"
        ]

        let nestedPercentKeys = [
            "pct",
            "percent",
            "percentage",
            "rate",
            "last60Pct",
            "last60Percent",
            "last60DaysPct",
            "last60DaysPercent",
            "last60DaysAttendancePct"
        ]

        for nestedKey in nestedKeys {
            guard let nestedMap = data[nestedKey] as? [String: Any] else {
                continue
            }

            for percentKey in nestedPercentKeys {
                if let value = percentIntValue(from: nestedMap[percentKey]) {
                    return value
                }
            }

            if let attended = numericDoubleValue(from: nestedMap["attended"]),
               let total = numericDoubleValue(from: nestedMap["total"]),
               total > 0 {
                return clampedPercent(Int((attended / total * 100.0).rounded()))
            }

            if let present = numericDoubleValue(from: nestedMap["present"]),
               let total = numericDoubleValue(from: nestedMap["total"]),
               total > 0 {
                return clampedPercent(Int((present / total * 100.0).rounded()))
            }
        }

        if let attended = numericDoubleValue(from: data["attendanceAttended"]),
           let total = numericDoubleValue(from: data["attendanceTotal"]),
           total > 0 {
            return clampedPercent(Int((attended / total * 100.0).rounded()))
        }

        if let present = numericDoubleValue(from: data["presentTrainings"]),
           let total = numericDoubleValue(from: data["totalTrainings"]),
           total > 0 {
            return clampedPercent(Int((present / total * 100.0).rounded()))
        }

        return 0
    }

    private func percentIntValue(from rawValue: Any?) -> Int? {
        guard let value = numericDoubleValue(from: rawValue) else {
            return nil
        }

        if value > 0, value <= 1 {
            return clampedPercent(Int((value * 100.0).rounded()))
        }

        return clampedPercent(Int(value.rounded()))
    }

    private func numericDoubleValue(from rawValue: Any?) -> Double? {
        if let value = rawValue as? Double {
            return value
        }

        if let value = rawValue as? Float {
            return Double(value)
        }

        if let value = rawValue as? Int {
            return Double(value)
        }

        if let value = rawValue as? Int64 {
            return Double(value)
        }

        if let value = rawValue as? NSNumber {
            return value.doubleValue
        }

        if let value = rawValue as? String {
            let cleaned = value
                .replacingOccurrences(of: "%", with: "")
                .replacingOccurrences(of: ",", with: ".")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return Double(cleaned)
        }

        return nil
    }

    private func clampedPercent(_ value: Int) -> Int {
        min(100, max(0, value))
    }

    private func loadTrainees() {
        guard isCoach else {
            isLoading = false
            return
        }

        isLoading = true

        let branchPrimary = normalize(effectiveBranchPrimary)
        let groupKey = normalize(effectiveGroupKey)

        Firestore.firestore()
            .collection("users")
            .getDocuments { snapshot, error in
                isLoading = false

                if let error {
                    trainees = []
                    showMessage(tr(
                        "טעינת המתאמנים נכשלה: \(error.localizedDescription)",
                        "Loading trainees failed: \(error.localizedDescription)"
                    ))
                    return
                }

                guard let docs = snapshot?.documents else {
                    trainees = []
                    return
                }

                let rows: [CoachTraineeProfile] = docs.compactMap { doc in
                    let data = doc.data()

                    guard isTraineeUserDocument(data) else {
                        return nil
                    }

                    guard userMatchesBranchAndGroup(
                        data: data,
                        branchPrimary: branchPrimary,
                        groupKey: groupKey
                    ) else {
                        return nil
                    }

                    let fullName = userStringValue(
                        from: data,
                        keys: [
                            "fullName",
                            "full_name",
                            "name",
                            "displayName",
                            "userName",
                            "username"
                        ]
                    )

                    let email = userStringValue(
                        from: data,
                        keys: [
                            "email"
                        ]
                    )

                    let phone = userStringValue(
                        from: data,
                        keys: [
                            "phone",
                            "phoneNumber",
                            "phone_number"
                        ]
                    )

                    guard !fullName.isEmpty || !email.isEmpty || !phone.isEmpty else {
                        return nil
                    }

                    let beltRaw = userStringValue(
                        from: data,
                        keys: [
                            "belt",
                            "beltId",
                            "currentBeltId",
                            "currentBelt",
                            "belt_current"
                        ]
                    )

                    let seniority = userStringValue(
                        from: data,
                        keys: [
                            "seniority",
                            "trainingSeniority",
                            "yearsTraining"
                        ]
                    )

                    let resolvedBranch = firstBranchValue(from: data)
                    let resolvedGroup = firstGroupValue(from: data)
                    let age = ageFromBirthDate(data["birthDate"] as? String)
                    let attendancePct = readAttendancePct(from: data)

                    let notes = userStringValue(
                        from: data,
                        keys: [
                            "coachNotes",
                            "attendanceNotes",
                            "notes"
                        ]
                    )

                    let rawBeltDates = data["beltAwardDates"] as? [String: Any] ?? [:]
                    let parsedBeltDates = rawBeltDates.reduce(into: [String: String]()) { result, entry in
                        let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
                        let value = "\(entry.value)".trimmingCharacters(in: .whitespacesAndNewlines)

                        guard !key.isEmpty, !value.isEmpty else { return }
                        result[key] = value
                    }

                    let parsedSeminarDates = readCoachDateEntryMap(from: data["seminarDates"])
                    let parsedCampDates = readCoachDateEntryMap(from: data["campDates"])
                    let parsedCertificationDates = readCoachDateEntryMap(from: data["certificationDates"])

                    return CoachTraineeProfile(
                        id: doc.documentID,
                        userDocId: doc.documentID,
                        fullName: fullName.isEmpty ? (email.isEmpty ? phone : email) : fullName,
                        email: email,
                        phone: phone,
                        belt: beltRaw,
                        seniority: seniority,
                        age: age,
                        attendancePct: attendancePct,
                        branch: resolvedBranch,
                        groupKey: resolvedGroup,
                        coachNotes: notes,
                        beltAwardDates: parsedBeltDates,
                        seminarDates: parsedSeminarDates,
                        campDates: parsedCampDates,
                        certificationDates: parsedCertificationDates
                    )
                }
                .sorted { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending }

                let unique = Dictionary(grouping: rows, by: { $0.id })
                    .compactMap { $0.value.first }
                    .sorted { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending }

                trainees = unique

                for trainee in unique {
                    if coachNotes[trainee.id] == nil {
                        coachNotes[trainee.id] = trainee.coachNotes
                    }

                    if beltAwardDates[trainee.id] == nil {
                        beltAwardDates[trainee.id] = trainee.beltAwardDates
                    }

                    if seminarDates[trainee.id] == nil {
                        seminarDates[trainee.id] = trainee.seminarDates
                    }

                    if campDates[trainee.id] == nil {
                        campDates[trainee.id] = trainee.campDates
                    }

                    if certificationDates[trainee.id] == nil {
                        certificationDates[trainee.id] = trainee.certificationDates
                    }
                }

                syncSelectedTrainee()
            }
    }

    private func userMatchesBranchAndGroup(
        data: [String: Any],
        branchPrimary: String,
        groupKey: String
    ) -> Bool {
        let isActive = data["isActive"] as? Bool ?? true
        guard isActive else { return false }

        let branchCandidates = branchAliases(branchPrimary)
        let groupCandidates = groupAliases(groupKey)

        let storedBranches = branchValues(from: data)
        let storedGroups = groupValues(from: data)

        let branchMatches =
            branchCandidates.isEmpty ||
            hasSoftMatch(storedValues: storedBranches, candidates: branchCandidates)

        let groupMatches =
            groupCandidates.isEmpty ||
            hasSoftMatch(storedValues: storedGroups, candidates: groupCandidates)

        return branchMatches && groupMatches
    }

    private func splitTokens(_ value: String) -> [String] {
        value
            .replacingOccurrences(of: " • ", with: ",")
            .replacingOccurrences(of: "|", with: ",")
            .replacingOccurrences(of: "\n", with: ",")
            .split(whereSeparator: { char in
                char == "," || char == ";" || char == "；"
            })
            .map { normalize(String($0)) }
            .filter { !$0.isEmpty }
    }

    private func branchAliases(_ value: String) -> Set<String> {
        let clean = normalize(value)
        guard !clean.isEmpty else { return [] }

        return Set([
            clean,
            clean.replacingOccurrences(of: "-", with: "–"),
            clean.replacingOccurrences(of: "-", with: "—"),
            clean.replacingOccurrences(of: "-", with: "־"),
            clean.replacingOccurrences(of: "–", with: "-"),
            clean.replacingOccurrences(of: "—", with: "-"),
            clean.replacingOccurrences(of: "־", with: "-")
        ].map { normalizeKey($0) }.filter { !$0.isEmpty })
    }

    private func groupAliases(_ value: String) -> Set<String> {
        let clean = normalize(value)
        var aliases = Set<String>()

        if !clean.isEmpty {
            aliases.insert(clean)
        }

        for token in splitTokens(clean) {
            aliases.insert(token)
        }

        if clean.contains("נוער") && clean.contains("בוגרים") {
            aliases.insert("נוער")
            aliases.insert("בוגרים")
            aliases.insert("נוער ובוגרים")
            aliases.insert("נוער + בוגרים")
        }

        if clean.localizedCaseInsensitiveContains("children") ||
            clean.localizedCaseInsensitiveContains("kids") {
            aliases.insert("ילדים")
        }

        if clean.localizedCaseInsensitiveContains("youth") {
            aliases.insert("נוער")
        }

        if clean.localizedCaseInsensitiveContains("adult") ||
            clean.localizedCaseInsensitiveContains("adults") {
            aliases.insert("בוגרים")
        }

        return Set(aliases.map { normalizeKey($0) }.filter { !$0.isEmpty })
    }

    private func branchValues(from data: [String: Any]) -> Set<String> {
        var values = Set<String>()

        let keys = [
            "branch",
            "activeBranch",
            "active_branch",
            "branchesCsv"
        ]

        for key in keys {
            let raw = ((data[key] as? String) ?? "")
            if splitTokens(raw).isEmpty, !normalize(raw).isEmpty {
                values.insert(normalizeKey(raw))
            } else {
                for token in splitTokens(raw) {
                    values.insert(normalizeKey(token))
                }
            }
        }

        let branches = (data["branches"] as? [String]) ?? []
        for value in branches {
            values.insert(normalizeKey(value))
        }

        return values
    }

    private func groupValues(from data: [String: Any]) -> Set<String> {
        var values = Set<String>()

        let keys = [
            "primaryGroup",
            "activeGroup",
            "active_group",
            "groupKey",
            "group_key",
            "group",
            "groupName",
            "groupsCsv",
            "groupCsv",
            "age_group"
        ]

        for key in keys {
            let raw = ((data[key] as? String) ?? "")
            if splitTokens(raw).isEmpty, !normalize(raw).isEmpty {
                values.formUnion(groupAliases(raw))
            } else {
                for token in splitTokens(raw) {
                    values.formUnion(groupAliases(token))
                }
            }
        }

        let groups = (data["groups"] as? [String]) ?? []
        for value in groups {
            values.formUnion(groupAliases(value))
        }

        return values
    }

    private func hasSoftMatch(
        storedValues: Set<String>,
        candidates: Set<String>
    ) -> Bool {
        if candidates.isEmpty {
            return true
        }

        if !storedValues.isDisjoint(with: candidates) {
            return true
        }

        for stored in storedValues {
            for candidate in candidates {
                if stored.count >= 2,
                   candidate.count >= 2,
                   stored.contains(candidate) || candidate.contains(stored) {
                    return true
                }
            }
        }

        return false
    }

    private func firstBranchValue(from data: [String: Any]) -> String {
        let branches = (data["branches"] as? [String]) ?? []
        let firstArray = branches
            .map { normalize($0) }
            .first(where: { !$0.isEmpty })

        if let firstArray {
            return firstArray
        }

        let keys = ["activeBranch", "active_branch", "branch", "branchesCsv"]

        for key in keys {
            let value = normalize(((data[key] as? String) ?? ""))
            if !value.isEmpty {
                return value
            }
        }

        return ""
    }

    private func firstGroupValue(from data: [String: Any]) -> String {
        let groups = (data["groups"] as? [String]) ?? []
        let firstArray = groups
            .map { normalize($0) }
            .first(where: { !$0.isEmpty })

        if let firstArray {
            return firstArray
        }

        let keys = [
            "primaryGroup",
            "activeGroup",
            "active_group",
            "groupKey",
            "group_key",
            "group",
            "age_group"
        ]

        for key in keys {
            let value = normalize(((data[key] as? String) ?? ""))
            if !value.isEmpty {
                return value
            }
        }

        return ""
    }

    private func saveBeltAwardDates(for trainee: CoachTraineeProfile) {
        guard !isSavingBeltDates else { return }

        let userDocId = trainee.userDocId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userDocId.isEmpty else {
            showMessage(tr("לא נמצא מזהה משתמש לשמירת תאריכים", "Missing user ID for saving dates"))
            return
        }

        let dates = beltAwardDates[trainee.id] ?? [:]
        let cleanedDates = dates
            .mapValues { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.value.isEmpty }

        guard !cleanedDates.isEmpty else {
            showMessage(tr("אין תאריכים לשמירה", "No dates to save"))
            return
        }

        let updates = cleanedDates.reduce(into: [String: Any]()) { result, entry in
            result["beltAwardDates.\(entry.key)"] = entry.value
        }

        isSavingBeltDates = true

        Firestore.firestore()
            .collection("users")
            .document(userDocId)
            .updateData(updates) { error in
                isSavingBeltDates = false

                if let error {
                    showMessage(tr(
                        "שמירת תאריכי החגורות נכשלה: \(error.localizedDescription)",
                        "Saving belt dates failed: \(error.localizedDescription)"
                    ))
                } else {
                    showMessage(tr("תאריכי החגורות נשמרו", "Belt dates saved"))
                }
            }
    }

    private func saveCoachDateEntries(
        for trainee: CoachTraineeProfile,
        firestoreFieldName: String,
        entries: [String: CoachDateEntry]
    ) {
        guard savingCoachDateSectionKey == nil else { return }

        let userDocId = trainee.userDocId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userDocId.isEmpty else {
            showMessage(tr("לא נמצא מזהה משתמש לשמירה", "Missing user ID for saving"))
            return
        }

        let cleanedEntries = entries.reduce(into: [String: CoachDateEntry]()) { result, entry in
            let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let date = entry.value.date.trimmingCharacters(in: .whitespacesAndNewlines)
            let description = entry.value.description.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !key.isEmpty, !date.isEmpty || !description.isEmpty else { return }

            result[key] = CoachDateEntry(
                date: date,
                description: description
            )
        }

        guard !cleanedEntries.isEmpty else {
            showMessage(tr("אין פריטים לשמירה", "No items to save"))
            return
        }

        let updates = cleanedEntries.reduce(into: [String: Any]()) { result, entry in
            result["\(firestoreFieldName).\(entry.key)"] = [
                "date": entry.value.date,
                "description": entry.value.description
            ]
        }

        savingCoachDateSectionKey = firestoreFieldName

        Firestore.firestore()
            .collection("users")
            .document(userDocId)
            .updateData(updates) { error in
                savingCoachDateSectionKey = nil

                if let error {
                    showMessage(tr(
                        "השמירה נכשלה: \(error.localizedDescription)",
                        "Saving failed: \(error.localizedDescription)"
                    ))
                } else {
                    showMessage(tr("הנתונים נשמרו", "Data saved"))
                }
            }
    }

    private func saveCoachNotes(for trainee: CoachTraineeProfile) {
        guard !isSavingNotes else { return }

        let userDocId = trainee.userDocId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userDocId.isEmpty else {
            showMessage(tr("לא נמצא מזהה משתמש לשמירת הערות", "Missing user ID for saving notes"))
            return
        }

        let note = (coachNotes[trainee.id] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        isSavingNotes = true

        Firestore.firestore()
            .collection("users")
            .document(userDocId)
            .updateData([
                "coachNotes": note,
                "coachNotesUpdatedAtMillis": Int64(Date().timeIntervalSince1970 * 1000)
            ]) { error in
                isSavingNotes = false

                if let error {
                    showMessage(tr(
                        "שמירת ההערות נכשלה: \(error.localizedDescription)",
                        "Saving notes failed: \(error.localizedDescription)"
                    ))
                } else {
                    showMessage(tr("הערות המאמן נשמרו", "Coach notes saved"))
                }
            }
    }

    private func syncSelectedTrainee() {
        let source = visibleTrainees.isEmpty ? trainees : visibleTrainees

        if selectedId == nil && !source.isEmpty {
            selectedId = source.first?.id
        } else if let selectedId, !source.contains(where: { $0.id == selectedId }) {
            self.selectedId = source.first?.id
        }
    }

    private func showMessage(_ text: String) {
        alertText = text
        showAlert = true
    }

    private func beltNameForUi(_ raw: String) -> String {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = clean
            .lowercased()
            .replacingOccurrences(of: "חגורה", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if isEnglish {
            switch normalized {
            case "white", "לבנה":
                return "White"
            case "yellow", "צהובה":
                return "Yellow"
            case "orange", "כתומה":
                return "Orange"
            case "green", "ירוקה":
                return "Green"
            case "blue", "כחולה":
                return "Blue"
            case "brown", "חומה":
                return "Brown"
            case "black", "שחורה":
                return "Black"
            case "":
                return "—"
            default:
                return clean.isEmpty ? "—" : clean
            }
        }

        switch normalized {
        case "white", "לבנה":
            return "לבנה"
        case "yellow", "צהובה":
            return "צהובה"
        case "orange", "כתומה":
            return "כתומה"
        case "green", "ירוקה":
            return "ירוקה"
        case "blue", "כחולה":
            return "כחולה"
        case "brown", "חומה":
            return "חומה"
        case "black", "שחורה":
            return "שחורה"
        case "":
            return "—"
        default:
            return clean.isEmpty ? "—" : clean
        }
    }

    private func ageFromBirthDate(_ birthDate: String?) -> Int {
        guard let birthDate, !birthDate.isEmpty else { return 0 }

        guard let date = ISO8601DateFormatter().date(from: birthDate + "T00:00:00Z")
                ?? DateFormatter.kmiBirthFormatter.date(from: birthDate) else {
            return 0
        }

        let components = Calendar.current.dateComponents([.year], from: date, to: Date())
        return components.year ?? 0
    }
}

private struct CoachDateEntry: Equatable {
    var date: String = ""
    var description: String = ""
}

private enum CoachDateSectionKind {
    case seminars
    case camps
    case certifications

    var firestoreFieldName: String {
        switch self {
        case .seminars:
            return "seminarDates"
        case .camps:
            return "campDates"
        case .certifications:
            return "certificationDates"
        }
    }

    func title(isEnglish: Bool) -> String {
        switch self {
        case .seminars:
            return isEnglish ? "Seminars" : "השתלמויות"
        case .camps:
            return isEnglish ? "Training camps" : "מחנות אימונים"
        case .certifications:
            return isEnglish ? "Certifications" : "הסמכות"
        }
    }

    func subtitle(isEnglish: Bool, isExpanded: Bool) -> String {
        if isExpanded {
            switch self {
            case .seminars:
                return isEnglish ? "Update seminar dates and notes" : "עדכון תאריכי השתלמויות ותיאור"
            case .camps:
                return isEnglish ? "Update training camp dates and notes" : "עדכון תאריכי מחנות אימונים ותיאור"
            case .certifications:
                return isEnglish ? "Update certification dates and notes" : "עדכון תאריכי הסמכות ותיאור"
            }
        }

        switch self {
        case .seminars:
            return isEnglish ? "Tap to open seminars" : "לחצו לפתיחת השתלמויות"
        case .camps:
            return isEnglish ? "Tap to open training camps" : "לחצו לפתיחת מחנות אימונים"
        case .certifications:
            return isEnglish ? "Tap to open certifications" : "לחצו לפתיחת הסמכות"
        }
    }

    var icon: String {
        switch self {
        case .seminars:
            return "🎓"
        case .camps:
            return "👥"
        case .certifications:
            return "🏅"
        }
    }

    var accent: Color {
        switch self {
        case .seminars:
            return Color.purple
        case .camps:
            return Color.blue
        case .certifications:
            return Color.cyan
        }
    }

    func itemTitle(index: Int, isEnglish: Bool) -> String {
        switch self {
        case .seminars:
            return isEnglish ? "Seminar \(index)" : "השתלמות \(index)"
        case .camps:
            return isEnglish ? "Training camp \(index)" : "מחנה אימונים \(index)"
        case .certifications:
            return isEnglish ? "Certification \(index)" : "הסמכה \(index)"
        }
    }

    func storageKey(index: Int) -> String {
        switch self {
        case .seminars:
            return "השתלמות \(index)"
        case .camps:
            return "מחנה אימונים \(index)"
        case .certifications:
            return "הסמכה \(index)"
        }
    }
}

private struct CoachDateEntriesSection: View {

    let isEnglish: Bool
    let sectionKind: CoachDateSectionKind

    @Binding var entries: [String: CoachDateEntry]

    let isSaving: Bool
    let onSave: () -> Void

    @State private var isExpanded: Bool = false
    @State private var expandedItem: String? = nil
    @State private var datePickerItem: String? = nil
    @State private var pendingDate: Date = Date()

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private func dateText(from date: Date) -> String {
        CoachDateFormatter.iso.string(from: date)
    }

    private func dateFromText(_ value: String) -> Date {
        CoachDateFormatter.iso.date(from: value) ?? Date()
    }

    var body: some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    if isEnglish {
                        Text(sectionKind.icon)
                            .font(.system(size: 24))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(sectionKind.title(isEnglish: isEnglish))
                                .font(.system(size: 16, weight: .heavy))
                                .foregroundStyle(Color.black.opacity(0.88))

                            Text(sectionKind.subtitle(isEnglish: isEnglish, isExpanded: isExpanded))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.black.opacity(0.55))
                        }

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Color.black.opacity(0.55))

                    } else {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Color.black.opacity(0.55))

                        Spacer()

                        VStack(alignment: .trailing, spacing: 3) {
                            Text(sectionKind.title(isEnglish: isEnglish))
                                .font(.system(size: 16, weight: .heavy))
                                .foregroundStyle(Color.black.opacity(0.88))

                            Text(sectionKind.subtitle(isEnglish: isEnglish, isExpanded: isExpanded))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.black.opacity(0.55))
                        }

                        Text(sectionKind.icon)
                            .font(.system(size: 24))
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(sectionKind.accent.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(sectionKind.accent.opacity(0.22), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 10) {
                    ForEach(1...5, id: \.self) { index in
                        let key = sectionKind.storageKey(index: index)
                        let entry = entries[key] ?? CoachDateEntry()
                        let hasData = !entry.date.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            !entry.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        let isItemExpanded = expandedItem == key

                        VStack(spacing: 8) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedItem = isItemExpanded ? nil : key
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    if isEnglish {
                                        Circle()
                                            .fill(sectionKind.accent)
                                            .frame(width: 10, height: 10)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(sectionKind.itemTitle(index: index, isEnglish: isEnglish))
                                                .font(.system(size: 15, weight: .heavy))
                                                .foregroundStyle(Color.black.opacity(0.85))

                                            Text(entry.date.isEmpty ? tr("אין תאריך", "No date") : entry.date)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(entry.date.isEmpty ? Color.gray.opacity(0.78) : Color.green.opacity(0.86))
                                        }

                                        Spacer()

                                        Image(systemName: hasData ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundStyle(hasData ? Color.green : Color.red.opacity(0.82))

                                        Image(systemName: isItemExpanded ? "chevron.up" : "chevron.down")
                                            .foregroundStyle(Color.gray)

                                    } else {
                                        Image(systemName: isItemExpanded ? "chevron.up" : "chevron.down")
                                            .foregroundStyle(Color.gray)

                                        Image(systemName: hasData ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundStyle(hasData ? Color.green : Color.red.opacity(0.82))

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 3) {
                                            Text(sectionKind.itemTitle(index: index, isEnglish: isEnglish))
                                                .font(.system(size: 15, weight: .heavy))
                                                .foregroundStyle(Color.black.opacity(0.85))

                                            Text(entry.date.isEmpty ? tr("אין תאריך", "No date") : entry.date)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(entry.date.isEmpty ? Color.gray.opacity(0.78) : Color.green.opacity(0.86))
                                        }

                                        Circle()
                                            .fill(sectionKind.accent)
                                            .frame(width: 10, height: 10)
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(sectionKind.accent.opacity(0.22), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            if isItemExpanded {
                                VStack(alignment: isEnglish ? .leading : .trailing, spacing: 8) {
                                    Button {
                                        pendingDate = dateFromText(entry.date)
                                        datePickerItem = key
                                    } label: {
                                        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 4) {
                                            Text(tr("תאריך", "Date"))
                                                .font(.system(size: 12, weight: .heavy))
                                                .foregroundStyle(sectionKind.accent)
                                                .multilineTextAlignment(textAlignment)
                                                .frame(maxWidth: .infinity, alignment: frameAlignment)

                                            Text(entry.date.isEmpty ? tr("בחר תאריך מלוח השנה", "Choose a date from calendar") : entry.date)
                                                .font(.system(size: 16, weight: .heavy))
                                                .foregroundStyle(entry.date.isEmpty ? Color.gray : Color.black.opacity(0.86))
                                                .multilineTextAlignment(textAlignment)
                                                .frame(maxWidth: .infinity, alignment: frameAlignment)
                                        }
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(Color(red: 0.97, green: 0.98, blue: 1.0))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(sectionKind.accent.opacity(0.70), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    VStack(alignment: isEnglish ? .leading : .trailing, spacing: 4) {
                                        Text(tr("תיאור", "Description"))
                                            .font(.system(size: 12, weight: .heavy))
                                            .foregroundStyle(Color.gray)
                                            .multilineTextAlignment(textAlignment)
                                            .frame(maxWidth: .infinity, alignment: frameAlignment)

                                        TextEditor(
                                            text: Binding(
                                                get: {
                                                    entries[key, default: CoachDateEntry()].description
                                                },
                                                set: { newValue in
                                                    var current = entries[key] ?? CoachDateEntry()
                                                    current.description = newValue
                                                    entries[key] = current
                                                }
                                            )
                                        )
                                        .frame(minHeight: 80)
                                        .padding(8)
                                        .background(Color.white)
                                        .foregroundStyle(.black)
                                        .multilineTextAlignment(textAlignment)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                                        )
                                    }
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.black.opacity(0.035))
                                )
                            }
                        }
                    }

                    Button(action: onSave) {
                        HStack(spacing: 8) {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            }

                            Text(isSaving ? tr("שומר...", "Saving...") : tr("שמור", "Save"))
                                .font(.system(size: 15, weight: .heavy))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(sectionKind.accent.opacity(0.88))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                    .opacity(isSaving ? 0.55 : 1.0)
                }
            }
        }
        .sheet(item: Binding(
            get: {
                datePickerItem.map { CoachDatePickerTarget(id: $0) }
            },
            set: { newValue in
                datePickerItem = newValue?.id
            }
        )) { target in
            NavigationStack {
                DatePicker(
                    tr("בחר תאריך", "Choose date"),
                    selection: $pendingDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle(target.id)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(tr("ביטול", "Cancel")) {
                            datePickerItem = nil
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button(tr("אישור", "OK")) {
                            var current = entries[target.id] ?? CoachDateEntry()
                            current.date = dateText(from: pendingDate)
                            entries[target.id] = current
                            datePickerItem = nil
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

private struct CoachDatePickerTarget: Identifiable {
    let id: String
}

private struct CoachGroupStatsSheet: View {

    let isEnglish: Bool
    let branchLabel: String
    let groupLabel: String
    let stats: CoachGroupStats

    @Environment(\.dismiss) private var dismiss

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.12, blue: 0.19),
                        Color(red: 0.10, green: 0.25, blue: 0.36),
                        Color(red: 0.05, green: 0.47, blue: 0.73)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: isEnglish ? .leading : .trailing, spacing: 14) {
                        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 6) {
                            Text(tr("סטטיסטיקה לקבוצה", "Group statistics"))
                                .font(.system(size: 26, weight: .black))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(textAlignment)
                                .frame(maxWidth: .infinity, alignment: frameAlignment)

                            Text(tr("סניף: \(branchLabel)", "Branch: \(branchLabel)"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.78))
                                .multilineTextAlignment(textAlignment)
                                .frame(maxWidth: .infinity, alignment: frameAlignment)

                            Text(tr("קבוצה: \(groupLabel)", "Group: \(groupLabel)"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.78))
                                .multilineTextAlignment(textAlignment)
                                .frame(maxWidth: .infinity, alignment: frameAlignment)
                        }
                        .padding(16)
                        .background(Color.black.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )

                        VStack(spacing: 10) {
                            statRow(
                                title: tr("סה״כ מתאמנים", "Total trainees"),
                                value: "\(stats.total)",
                                icon: "person.3.fill"
                            )

                            statRow(
                                title: tr("מתאמנים מסוננים", "Filtered trainees"),
                                value: "\(stats.filtered)",
                                icon: "line.3.horizontal.decrease.circle.fill"
                            )

                            statRow(
                                title: tr("גיל ממוצע", "Average age"),
                                value: stats.avgAge > 0 ? "\(stats.avgAge)" : "—",
                                icon: "calendar"
                            )

                            statRow(
                                title: tr("נוכחות ממוצעת", "Average attendance"),
                                value: stats.avgAttendance > 0 ? "\(stats.avgAttendance)%" : "—",
                                icon: "checkmark.circle.fill"
                            )

                            statRow(
                                title: tr("נוכחות גבוהה", "High attendance"),
                                value: "\(stats.highAttendance)",
                                icon: "star.circle.fill"
                            )
                        }

                        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 10) {
                            Text(tr("חלוקה לפי חגורות", "Belt distribution"))
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(textAlignment)
                                .frame(maxWidth: .infinity, alignment: frameAlignment)

                            if stats.beltCounts.isEmpty {
                                Text(tr("אין נתוני חגורות להצגה", "No belt data to show"))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.72))
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .padding(16)
                                    .background(Color.white.opacity(0.10))
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(stats.beltCounts) { belt in
                                        statRow(
                                            title: belt.title,
                                            value: "\(belt.count)",
                                            icon: "circle.fill"
                                        )
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .background(Color.black.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                    }
                    .padding(14)
                }
            }
            .navigationTitle(tr("סטטיסטיקה", "Statistics"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("סגור", "Close")) {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                }
            }
        }
    }

    private func statRow(
        title: String,
        value: String,
        icon: String
    ) -> some View {
        HStack(spacing: 12) {
            if isEnglish {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.blue)

                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.78))
                    .multilineTextAlignment(.leading)

                Spacer()

                Text(value)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.black.opacity(0.88))
            } else {
                Text(value)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.black.opacity(0.88))

                Spacer()

                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.78))
                    .multilineTextAlignment(.trailing)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.blue)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
        )
    }
}

private struct CoachBeltAwardDatesSection: View {

    let isEnglish: Bool
    let beltOrder: [String]

    @Binding var dates: [String: String]

    let isSaving: Bool
    let onSave: () -> Void

    @State private var isExpanded: Bool = false
    @State private var expandedBelt: String? = nil
    @State private var datePickerBelt: String? = nil
    @State private var pendingDate: Date = Date()

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private func beltNameForUi(_ belt: String) -> String {
        guard isEnglish else {
            return "חגורה \(belt)"
        }

        switch belt {
        case "צהובה":
            return "Yellow"
        case "כתומה":
            return "Orange"
        case "ירוקה":
            return "Green"
        case "כחולה":
            return "Blue"
        case "חומה":
            return "Brown"
        case "שחורה":
            return "Black"
        default:
            return belt
        }
    }

    private func accentColor(for belt: String) -> Color {
        switch belt {
        case "צהובה":
            return Color(red: 0.95, green: 0.72, blue: 0.08)
        case "כתומה":
            return Color.orange
        case "ירוקה":
            return Color.green
        case "כחולה":
            return Color.blue
        case "חומה":
            return Color.brown
        case "שחורה":
            return Color.black
        default:
            return Color.purple
        }
    }

    private func dateText(from date: Date) -> String {
        CoachDateFormatter.iso.string(from: date)
    }

    private func dateFromText(_ value: String) -> Date {
        CoachDateFormatter.iso.date(from: value) ?? Date()
    }

    var body: some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    if isEnglish {
                        Text("📅")
                            .font(.system(size: 24))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(tr("תאריכי קבלת חגורות", "Belt award dates"))
                                .font(.system(size: 16, weight: .heavy))
                                .foregroundStyle(Color.black.opacity(0.88))

                            Text(isExpanded ? tr("עדכון תאריכים לפי חגורה", "Update dates by belt") : tr("לחצו לפתיחת רשימת החגורות", "Tap to open the belt list"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.black.opacity(0.55))
                        }

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Color.black.opacity(0.55))

                    } else {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Color.black.opacity(0.55))

                        Spacer()

                        VStack(alignment: .trailing, spacing: 3) {
                            Text(tr("תאריכי קבלת חגורות", "Belt award dates"))
                                .font(.system(size: 16, weight: .heavy))
                                .foregroundStyle(Color.black.opacity(0.88))

                            Text(isExpanded ? tr("עדכון תאריכים לפי חגורה", "Update dates by belt") : tr("לחצו לפתיחת רשימת החגורות", "Tap to open the belt list"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.black.opacity(0.55))
                        }

                        Text("📅")
                            .font(.system(size: 24))
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.96, green: 0.96, blue: 1.0))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.purple.opacity(0.18), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 10) {
                    ForEach(beltOrder, id: \.self) { belt in
                        let currentDate = dates[belt, default: ""]
                        let hasDate = !currentDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        let accent = accentColor(for: belt)
                        let isBeltExpanded = expandedBelt == belt

                        VStack(spacing: 8) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedBelt = isBeltExpanded ? nil : belt
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    if isEnglish {
                                        Circle()
                                            .fill(accent)
                                            .frame(width: 10, height: 10)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(beltNameForUi(belt))
                                                .font(.system(size: 15, weight: .heavy))
                                                .foregroundStyle(Color.black.opacity(0.85))

                                            Text(hasDate ? tr("תאריך קבלה: \(currentDate)", "Award date: \(currentDate)") : tr("אין תאריך קבלה", "No award date"))
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(hasDate ? Color.green.opacity(0.86) : Color.gray.opacity(0.78))
                                        }

                                        Spacer()

                                        Image(systemName: hasDate ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundStyle(hasDate ? Color.green : Color.red.opacity(0.82))

                                        Image(systemName: isBeltExpanded ? "chevron.up" : "chevron.down")
                                            .foregroundStyle(Color.gray)

                                    } else {
                                        Image(systemName: isBeltExpanded ? "chevron.up" : "chevron.down")
                                            .foregroundStyle(Color.gray)

                                        Image(systemName: hasDate ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundStyle(hasDate ? Color.green : Color.red.opacity(0.82))

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 3) {
                                            Text(beltNameForUi(belt))
                                                .font(.system(size: 15, weight: .heavy))
                                                .foregroundStyle(Color.black.opacity(0.85))

                                            Text(hasDate ? tr("תאריך קבלה: \(currentDate)", "Award date: \(currentDate)") : tr("אין תאריך קבלה", "No award date"))
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(hasDate ? Color.green.opacity(0.86) : Color.gray.opacity(0.78))
                                        }

                                        Circle()
                                            .fill(accent)
                                            .frame(width: 10, height: 10)
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(accent.opacity(0.22), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            if isBeltExpanded {
                                Button {
                                    pendingDate = dateFromText(currentDate)
                                    datePickerBelt = belt
                                } label: {
                                    VStack(alignment: isEnglish ? .leading : .trailing, spacing: 4) {
                                        Text(tr("תאריך קבלה", "Award date"))
                                            .font(.system(size: 12, weight: .heavy))
                                            .foregroundStyle(accent)
                                            .multilineTextAlignment(textAlignment)
                                            .frame(maxWidth: .infinity, alignment: frameAlignment)

                                        Text(hasDate ? currentDate : tr("בחר תאריך מלוח השנה", "Choose a date from calendar"))
                                            .font(.system(size: 16, weight: .heavy))
                                            .foregroundStyle(hasDate ? Color.black.opacity(0.86) : Color.gray)
                                            .multilineTextAlignment(textAlignment)
                                            .frame(maxWidth: .infinity, alignment: frameAlignment)
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color(red: 0.97, green: 0.98, blue: 1.0))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(accent.opacity(0.70), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Button(action: onSave) {
                        HStack(spacing: 8) {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            }

                            Text(isSaving ? tr("שומר...", "Saving...") : tr("שמור תאריכי חגורות", "Save belt dates"))
                                .font(.system(size: 15, weight: .heavy))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.purple,
                                            Color.blue
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                    .opacity(isSaving ? 0.55 : 1.0)
                }
            }
        }
        .sheet(item: Binding(
            get: {
                datePickerBelt.map { CoachBeltPickerTarget(id: $0) }
            },
            set: { newValue in
                datePickerBelt = newValue?.id
            }
        )) { target in
            NavigationStack {
                DatePicker(
                    tr("בחר תאריך קבלת חגורה", "Choose belt award date"),
                    selection: $pendingDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle(beltNameForUi(target.id))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(tr("ביטול", "Cancel")) {
                            datePickerBelt = nil
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button(tr("אישור", "OK")) {
                            dates[target.id] = dateText(from: pendingDate)
                            datePickerBelt = nil
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

private struct CoachBeltPickerTarget: Identifiable {
    let id: String
}

private struct CoachBeltCount: Identifiable {
    let id: String
    let title: String
    let count: Int
}

private struct CoachGroupStats {
    let total: Int
    let filtered: Int
    let avgAge: Int
    let avgAttendance: Int
    let highAttendance: Int
    let beltCounts: [CoachBeltCount]
}

private struct CoachTraineeProfile: Identifiable {
    let id: String
    let userDocId: String
    let fullName: String
    let email: String
    let phone: String
    let belt: String
    let seniority: String
    let age: Int
    let attendancePct: Int
    let branch: String
    let groupKey: String
    let coachNotes: String
    let beltAwardDates: [String: String]
    let seminarDates: [String: CoachDateEntry]
    let campDates: [String: CoachDateEntry]
    let certificationDates: [String: CoachDateEntry]

    func metaLine(isEnglish: Bool) -> String {
        var parts: [String] = []

        let cleanBelt = belt.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanGroup = groupKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleanBelt.isEmpty {
            parts.append(cleanBelt)
        }

        if !cleanBranch.isEmpty {
            parts.append(isEnglish ? "Branch: \(cleanBranch)" : "סניף: \(cleanBranch)")
        }

        if !cleanGroup.isEmpty {
            parts.append(isEnglish ? "Group: \(cleanGroup)" : "קבוצה: \(cleanGroup)")
        }

        return parts.joined(separator: " • ")
    }

    func matchesSearch(_ normalizedQuery: String) -> Bool {
        guard !normalizedQuery.isEmpty else {
            return true
        }

        let searchableValues = [
            fullName,
            email,
            phone,
            belt,
            seniority,
            branch,
            groupKey,
            "\(age)",
            "\(attendancePct)"
        ]

        return searchableValues.contains { value in
            value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .contains(normalizedQuery)
        }
    }
}

private enum CoachDateFormatter {
    static let iso: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}

private extension DateFormatter {
    static let kmiBirthFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}
