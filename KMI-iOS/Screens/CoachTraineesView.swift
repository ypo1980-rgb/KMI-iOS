import SwiftUI
import UIKit
import FirebaseFirestore
import FirebaseAuth

private struct CoachPDFShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct CoachActivityShareView:
    UIViewControllerRepresentable {

    let activityItems: [Any]

    func makeUIViewController(
        context: Context
    ) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {
    }
}

struct CoachTraineesView: View {

    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var trainees: [CoachTraineeProfile] = []
    @State private var selectedId: String? = nil
    @State private var searchText: String = ""
    @State private var selectedBeltFilter: String = ""
    @State private var coachNotes: [String: String] = [:]

    /*
     * לכל חגורה נשמרים בנפרד:
     * תאריך הקבלה ותיאור חופשי של המאמן.
     */
    @State private var beltAwardDates: [String: [String: String]] = [:]
    @State private var beltAwardDescriptions: [String: [String: String]] = [:]

    @State private var seminarDates: [String: [String: CoachDateEntry]] = [:]
    @State private var campDates: [String: [String: CoachDateEntry]] = [:]
    @State private var certificationDates: [String: [String: CoachDateEntry]] = [:]

    @State private var isLoading = true
    @State private var isLoadingAttendance = false
    @State private var isSavingNotes = false
    @State private var isSavingBeltDates = false
    @State private var savingCoachDateSectionKey: String? = nil

    @State private var alertText: String?
    @State private var showAlert = false
    @State private var showGroupStatsSheet = false
    @State private var pdfShareItem: CoachPDFShareItem?
    @State private var isTopStatsExpanded: Bool = false
    @State private var isTraineePickerExpanded: Bool = true

    /*
     * אקורדיון פרטי המתאמן:
     * רק סעיף אחד יכול להיות פתוח בכל רגע.
     */
    @State private var expandedCoachSection: String? = nil

    private let beltDatesSectionKey = "belt_dates"
    private let seminarsSectionKey = "seminars"
    private let campsSectionKey = "camps"
    private let certificationsSectionKey = "certifications"
    private let notesSectionKey = "coach_notes"

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

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var cardSurfaceColor: Color {
        isDarkMode
        ? Color(red: 0.09, green: 0.13, blue: 0.21)
        : Color(red: 0.985, green: 0.99, blue: 1.0)
    }

    private var elevatedCardColor: Color {
        isDarkMode
        ? Color(red: 0.12, green: 0.17, blue: 0.27)
        : Color.white
    }

    private var fieldSurfaceColor: Color {
        isDarkMode
        ? Color.white.opacity(0.075)
        : Color.black.opacity(0.035)
    }

    private var primaryCardTextColor: Color {
        isDarkMode
        ? Color.white.opacity(0.94)
        : Color.black.opacity(0.86)
    }

    private var secondaryCardTextColor: Color {
        isDarkMode
        ? Color.white.opacity(0.62)
        : Color.black.opacity(0.52)
    }

    private var subtleCardBorderColor: Color {
        isDarkMode
        ? Color.white.opacity(0.12)
        : Color.black.opacity(0.07)
    }

    private var selectedTraineeRowColor: Color {
        isDarkMode
        ? Color.blue.opacity(0.20)
        : Color(red: 0.88, green: 0.97, blue: 1.0)
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    /*
     * יוצר Binding עבור סעיף באקורדיון.
     * פתיחת סעיף סוגרת אוטומטית את הסעיף הקודם.
     */
    private func coachSectionBinding(
        for key: String
    ) -> Binding<Bool> {
        Binding(
            get: {
                expandedCoachSection == key
            },
            set: { shouldExpand in
                withAnimation(
                    .easeInOut(duration: 0.22)
                ) {
                    expandedCoachSection =
                        shouldExpand ? key : nil
                }
            }
        )
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

        let avgAgeValues =
            statsSource
                .map(\.age)
                .filter { $0 > 0 }

        let avgAge =
            avgAgeValues.isEmpty
            ? 0
            : avgAgeValues.reduce(0, +) / avgAgeValues.count

        /*
         * אפס הוא אחוז נוכחות חוקי ולכן אסור לסנן אותו.
         * אם הרשימה ריקה בלבד, הממוצע יהיה אפס.
         */
        let avgAttendanceValues =
            statsSource.map(\.attendancePct)

        let avgAttendance =
            avgAttendanceValues.isEmpty
            ? 0
            : Int(
                (
                    Double(avgAttendanceValues.reduce(0, +)) /
                    Double(avgAttendanceValues.count)
                )
                .rounded()
            )

        let highAttendanceCount =
            statsSource
                .filter { $0.attendancePct >= 80 }
                .count

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
                                .transition(
                                    .opacity.combined(
                                        with: .move(edge: .top)
                                    )
                                )
                        }

                        traineePickerCard

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
        .sheet(item: $pdfShareItem) { item in
            CoachActivityShareView(
                activityItems: [item.url]
            )
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name(
                    "KMI_GLOBAL_SHARE_REQUEST"
                )
            )
        ) { notification in
            guard
                let request =
                    notification.object
                    as? NSMutableDictionary
            else {
                return
            }

            /*
             * הסימון מתבצע מיד ובאופן סינכרוני.
             * כך הסרגל הגלובלי לא יפתח במקביל
             * את חלון השיתוף הכללי שלו.
             */
            request["handled"] = true

            guard let trainee = selectedTrainee else {
                alertText = tr(
                    "יש לבחור מתאמן לפני יצירת קובץ PDF.",
                    "Select a trainee before creating a PDF file."
                )
                showAlert = true
                return
            }

            createAndSharePDF(
                for: trainee
            )
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
        .onChange(of: selectedId) { _, _ in
            /*
             * במעבר למתאמן אחר מתחילים מכרטיס נקי,
             * ללא סעיף שנשאר פתוח מהמתאמן הקודם.
             */
            expandedCoachSection = nil
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
                    value: "\(groupStats.avgAttendance)%",
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
            HStack(spacing: 10) {
                if isEnglish {
                    Image(systemName: "chart.bar.xaxis")
                        .font(
                            .system(
                                size: 17,
                                weight: .black
                            )
                        )

                    Text("Group statistics")
                        .font(
                            .system(
                                size: 16,
                                weight: .heavy
                            )
                        )

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(
                            .system(
                                size: 14,
                                weight: .black
                            )
                        )

                } else {
                    Image(systemName: "chevron.left")
                        .font(
                            .system(
                                size: 14,
                                weight: .black
                            )
                        )

                    Spacer(minLength: 8)

                    Text("סטטיסטיקה לקבוצה")
                        .font(
                            .system(
                                size: 16,
                                weight: .heavy
                            )
                        )
                        .multilineTextAlignment(.trailing)

                    Image(systemName: "chart.bar.xaxis")
                        .font(
                            .system(
                                size: 17,
                                weight: .black
                            )
                        )
                }
            }
            /*
             * הסדר בתוך השורה נבנה ידנית לכל שפה,
             * ולכן אין לאפשר ל־RTL להפוך אותו שוב.
             */
            .environment(
                \.layoutDirection,
                .leftToRight
            )
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [
                            Color(
                                red: 0.17,
                                green: 0.36,
                                blue: 0.92
                            ),
                            Color(
                                red: 0.05,
                                green: 0.70,
                                blue: 0.88
                            )
                        ],
                        startPoint:
                            isEnglish
                            ? .leading
                            : .trailing,
                        endPoint:
                            isEnglish
                            ? .trailing
                            : .leading
                    )
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .stroke(
                    Color.white.opacity(0.22),
                    lineWidth: 1
                )
            )
            .shadow(
                color: Color.black.opacity(0.16),
                radius: 9,
                x: 0,
                y: 5
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            tr(
                "פתיחת סטטיסטיקה לקבוצה",
                "Open group statistics"
            )
        )
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

    /*
     * כרטיס בחירת המתאמן תואם למבנה Android:
     * במצב סגור מוצג המתאמן הנבחר בלבד.
     * פתיחת הכרטיס חושפת את החיפוש ואת הרשימה.
     */
    private var traineePickerCard: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isTraineePickerExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    if isEnglish {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(Color.blue.opacity(0.90))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(
                                selectedTrainee?.fullName ??
                                tr("בחר מתאמן", "Select trainee")
                            )
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundStyle(primaryCardTextColor)
                            .multilineTextAlignment(.leading)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )

                            Text(
                                tr(
                                    "\(visibleTrainees.count) מתאמנים ברשימה",
                                    "\(visibleTrainees.count) trainees in list"
                                )
                            )
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.50))
                            .multilineTextAlignment(.leading)
                        }

                        if isLoadingAttendance {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.blue)
                        }

                        Image(
                            systemName:
                                isTraineePickerExpanded
                                ? "chevron.up"
                                : "chevron.down"
                        )
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.black.opacity(0.48))

                    } else {
                        Image(
                            systemName:
                                isTraineePickerExpanded
                                ? "chevron.up"
                                : "chevron.down"
                        )
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.black.opacity(0.48))

                        if isLoadingAttendance {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.blue)
                        }

                        VStack(alignment: .trailing, spacing: 3) {
                            Text(
                                selectedTrainee?.fullName ??
                                tr("בחר מתאמן", "Select trainee")
                            )
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundStyle(primaryCardTextColor)
                            .multilineTextAlignment(.trailing)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .trailing
                            )

                            Text(
                                tr(
                                    "\(visibleTrainees.count) מתאמנים ברשימה",
                                    "\(visibleTrainees.count) trainees in list"
                                )
                            )
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(secondaryCardTextColor)
                            .multilineTextAlignment(.trailing)
                        }

                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(Color.blue.opacity(0.90))
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isTraineePickerExpanded {
                Divider()
                    .padding(.horizontal, 12)

                VStack(spacing: 10) {
                    searchCard

                    traineeListCard
                }
                .padding(10)
                .transition(
                    .opacity.combined(
                        with: .move(edge: .top)
                    )
                )
            }
        }
        .background(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .fill(cardSurfaceColor)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .stroke(
                subtleCardBorderColor,
                lineWidth: 1
            )
        )
        .shadow(
            color:
                Color.black.opacity(
                    isDarkMode ? 0.20 : 0.08
                ),
            radius: 8,
            x: 0,
            y: 4
        )
    }
    
    private var searchCard: some View {
        HStack(spacing: 10) {
            if !searchText
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty {

                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(
                            .system(
                                size: 18,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(
                            secondaryCardTextColor
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    tr("נקה חיפוש", "Clear search")
                )
            }

            TextField(
                tr("חיפוש מתאמן", "Search trainee"),
                text: $searchText
            )
            .font(
                .system(
                    size: 16,
                    weight: .semibold
                )
            )
            .foregroundStyle(primaryCardTextColor)
            .tint(.blue)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
            .multilineTextAlignment(screenTextAlignment)
            .frame(
                maxWidth: .infinity,
                alignment: screenFrameAlignment
            )

            Image(systemName: "magnifyingglass")
                .font(
                    .system(
                        size: 16,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    secondaryCardTextColor
                )
        }
        .environment(
            \.layoutDirection,
            isEnglish
            ? .leftToRight
            : .rightToLeft
        )
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .fill(fieldSurfaceColor)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .stroke(
                subtleCardBorderColor,
                lineWidth: 1
            )
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
        .background(Color.clear)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
    }

    private func traineeRow(
        _ trainee: CoachTraineeProfile
    ) -> some View {
        let isSelected = selectedId == trainee.id

        return Button {
            selectedId = trainee.id
            searchText = ""

            withAnimation(.easeInOut(duration: 0.22)) {
                isTraineePickerExpanded = false
            }
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
            .environment(
                \.layoutDirection,
                .leftToRight
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .fill(
                    isSelected
                    ? selectedTraineeRowColor
                    : Color.clear
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .stroke(
                    isSelected
                    ? Color.blue.opacity(0.26)
                    : Color.clear,
                    lineWidth: 1
                )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    private func traineeRowTexts(
        _ trainee: CoachTraineeProfile
    ) -> some View {
        VStack(
            alignment:
                isEnglish
                ? .leading
                : .trailing,
            spacing: 7
        ) {
            Text(trainee.fullName)
                .font(
                    .system(
                        size: 17,
                        weight: .heavy
                    )
                )
                .foregroundStyle(primaryCardTextColor)
                .multilineTextAlignment(
                    screenTextAlignment
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: screenFrameAlignment
                )
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

            let meta =
                trainee.metaLine(
                    isEnglish: isEnglish
                )

            if !meta.isEmpty {
                Text(meta)
                    .font(
                        .system(
                            size: 12,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        secondaryCardTextColor
                    )
                    .multilineTextAlignment(
                        screenTextAlignment
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: screenFrameAlignment
                    )
                    .lineLimit(3)
                    .minimumScaleFactor(0.82)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }

            traineeMiniStatsRow(trainee)
        }
    }

    private func traineeMiniStatsRow(
        _ trainee: CoachTraineeProfile
    ) -> some View {
        let ageText =
            trainee.age > 0
            ? "\(trainee.age)"
            : "—"

        let beltText =
            beltNameForUi(trainee.belt)

        let attendanceText =
            "\(trainee.attendancePct)%"

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
                    title: tr(
                        "נוכחות",
                        "Attendance"
                    ),
                    value: attendanceText,
                    systemImage:
                        "checkmark.circle.fill"
                )

                Spacer(minLength: 0)

            } else {
                Spacer(minLength: 0)

                miniStatChip(
                    title: tr(
                        "נוכחות",
                        "Attendance"
                    ),
                    value: attendanceText,
                    systemImage:
                        "checkmark.circle.fill"
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
        /*
         * סדר הפריטים כבר נבנה ידנית בהתאם לשפה.
         * לכן מונעים היפוך RTL נוסף של ה־HStack.
         */
        .environment(
            \.layoutDirection,
            .leftToRight
        )
        .frame(
            maxWidth: .infinity,
            alignment: screenFrameAlignment
        )
        .fixedSize(
            horizontal: false,
            vertical: true
        )
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
        .foregroundStyle(primaryCardTextColor.opacity(0.78))
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(fieldSurfaceColor)
        )
        .overlay(
            Capsule()
                .stroke(
                    subtleCardBorderColor,
                    lineWidth: 1
                )
        )
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
                    isExpanded: coachSectionBinding(
                        for: beltDatesSectionKey
                    ),
                    dates: Binding(
                        get: {
                            beltAwardDates[trainee.id] ??
                            trainee.beltAwardDates
                        },
                        set: { newValue in
                            beltAwardDates[trainee.id] =
                                newValue
                        }
                    ),
                    descriptions: Binding(
                        get: {
                            beltAwardDescriptions[trainee.id] ??
                            trainee.beltAwardDescriptions
                        },
                        set: { newValue in
                            beltAwardDescriptions[trainee.id] =
                                newValue
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
                    isExpanded: coachSectionBinding(
                        for: seminarsSectionKey
                    ),
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
                    isExpanded: coachSectionBinding(
                        for: campsSectionKey
                    ),
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
                    isExpanded: coachSectionBinding(
                        for: certificationsSectionKey
                    ),
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

                coachNotesCard(
                    for: trainee,
                    isExpanded: coachSectionBinding(
                        for: notesSectionKey
                    )
                )

            } else {
                Text(tr("בחר מתאמן מהרשימה למעלה", "Select a trainee from the list above"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .fill(cardSurfaceColor)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(
                subtleCardBorderColor,
                lineWidth: 1
            )
        )
        .shadow(
            color:
                Color.black.opacity(
                    isDarkMode ? 0.18 : 0.07
                ),
            radius: 8,
            x: 0,
            y: 4
        )
    }

    private func traineeProfileHeaderCard(
        for trainee: CoachTraineeProfile
    ) -> some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 10) {
            HStack(spacing: 12) {
                if isEnglish {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(Color.blue.opacity(0.88))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(trainee.fullName)
                            .font(.system(size: 25, weight: .black))
                            .foregroundStyle(primaryCardTextColor)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )
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
                            .foregroundStyle(primaryCardTextColor)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )
                        Text(tr("כרטיס מתאמן", "Trainee profile"))
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Color.black.opacity(0.50))
                    }

                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(Color.blue.opacity(0.88))
                }
            }
            .environment(
                \.layoutDirection,
                .leftToRight
            )

            if !trainee.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !trainee.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

                VStack(
                    alignment: isEnglish ? .leading : .trailing,
                    spacing: 6
                ) {
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
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .fill(
                isDarkMode
                ? Color.blue.opacity(0.10)
                : Color(
                    red: 0.95,
                    green: 0.98,
                    blue: 1.0
                )
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .stroke(
                Color.blue.opacity(
                    isDarkMode ? 0.28 : 0.14
                ),
                lineWidth: 1
            )
        )
    }

    private func contactLine(
        icon: String,
        value: String
    ) -> some View {
        HStack(spacing: 8) {
            if isEnglish {
                Image(systemName: icon)
                    .font(
                        .system(
                            size: 12,
                            weight: .heavy
                        )
                    )
                    .foregroundStyle(
                        Color.blue.opacity(0.82)
                    )

                Text(value)
                    .font(
                        .system(
                            size: 13,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        secondaryCardTextColor
                    )
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )

            } else {
                Spacer(minLength: 0)

                Text(value)
                    .font(
                        .system(
                            size: 13,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        secondaryCardTextColor
                    )
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .frame(
                        alignment: .trailing
                    )
                    .environment(
                        \.layoutDirection,
                        .leftToRight
                    )

                Image(systemName: icon)
                    .font(
                        .system(
                            size: 12,
                            weight: .heavy
                        )
                    )
                    .foregroundStyle(
                        Color.blue.opacity(0.82)
                    )
            }
        }
        .environment(
            \.layoutDirection,
            .leftToRight
        )
        .frame(
            maxWidth: .infinity,
            alignment: screenFrameAlignment
        )
    }

    private func traineeQuickInfoGrid(
        for trainee: CoachTraineeProfile
    ) -> some View {
        let columns = [
            GridItem(
                .flexible(minimum: 0),
                spacing: 10
            ),
            GridItem(
                .flexible(minimum: 0),
                spacing: 10
            )
        ]

        return LazyVGrid(
            columns: columns,
            alignment: .center,
            spacing: 10
        ) {
            quickInfoTile(
                title: tr("גיל", "Age"),
                value:
                    trainee.age > 0
                    ? "\(trainee.age)"
                    : "—",
                icon: "calendar"
            )

            quickInfoTile(
                title: tr("דרגה", "Rank"),
                value: beltNameForUi(trainee.belt),
                icon: "seal.fill"
            )

            quickInfoTile(
                title: tr("ותק", "Seniority"),
                value:
                    trainee.seniority.isEmpty
                    ? "—"
                    : trainee.seniority,
                icon: "clock.fill"
            )

            quickInfoTile(
                title:
                    tr(
                        "נוכחות 60 יום",
                        "60-day attendance"
                    ),
                value:
                    trainee.attendancePct >= 0
                    ? "\(trainee.attendancePct)%"
                    : "—",
                icon: "checkmark.circle.fill"
            )

            quickInfoTile(
                title: tr("סניף", "Branch"),
                value:
                    trainee.branch.isEmpty
                    ? "—"
                    : trainee.branch,
                icon: "mappin.and.ellipse"
            )

            quickInfoTile(
                title: tr("קבוצה", "Group"),
                value:
                    trainee.groupKey.isEmpty
                    ? "—"
                    : trainee.groupKey,
                icon: "person.3.fill"
            )
        }
        .environment(
            \.layoutDirection,
            isEnglish
            ? .leftToRight
            : .rightToLeft
        )
    }

    private func quickInfoTile(
        title: String,
        value: String,
        icon: String
    ) -> some View {
        VStack(
            alignment:
                isEnglish
                ? .leading
                : .trailing,
            spacing: 6
        ) {
            HStack(spacing: 6) {
                if isEnglish {
                    Image(systemName: icon)
                        .font(
                            .system(
                                size: 12,
                                weight: .heavy
                            )
                        )
                        .foregroundStyle(
                            Color.blue.opacity(0.78)
                        )

                    Text(title)
                        .font(
                            .system(
                                size: 11,
                                weight: .heavy
                            )
                        )
                        .foregroundStyle(
                            secondaryCardTextColor
                        )
                        .multilineTextAlignment(
                            .leading
                        )
                        .lineLimit(2)

                    Spacer(minLength: 0)

                } else {
                    Spacer(minLength: 0)

                    Text(title)
                        .font(
                            .system(
                                size: 11,
                                weight: .heavy
                            )
                        )
                        .foregroundStyle(
                            secondaryCardTextColor
                        )
                        .multilineTextAlignment(
                            .trailing
                        )
                        .lineLimit(2)

                    Image(systemName: icon)
                        .font(
                            .system(
                                size: 12,
                                weight: .heavy
                            )
                        )
                        .foregroundStyle(
                            Color.blue.opacity(0.78)
                        )
                }
            }
            /*
             * מונע היפוך נוסף של סדר האייקון
             * והכותרת במצב עברית.
             */
            .environment(
                \.layoutDirection,
                .leftToRight
            )
            .frame(
                maxWidth: .infinity,
                alignment: screenFrameAlignment
            )

            Text(value)
                .font(
                    .system(
                        size: 15,
                        weight: .black
                    )
                )
                .foregroundStyle(
                    primaryCardTextColor
                )
                .multilineTextAlignment(
                    screenTextAlignment
                )
                .lineLimit(3)
                .minimumScaleFactor(0.76)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
                .frame(
                    maxWidth: .infinity,
                    minHeight: 38,
                    alignment: screenFrameAlignment
                )
        }
        .frame(
            maxWidth: .infinity,
            alignment: screenFrameAlignment
        )
        .padding(12)
        .background(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .fill(fieldSurfaceColor)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .stroke(
                subtleCardBorderColor,
                lineWidth: 1
            )
        )
    }

    private func coachNotesCard(
        for trainee: CoachTraineeProfile,
        isExpanded: Binding<Bool>
    ) -> some View {
        VStack(
            alignment:
                isEnglish
                ? .leading
                : .trailing,
            spacing: 10
        ) {
            Button {
                isExpanded.wrappedValue.toggle()
            } label: {
                HStack(spacing: 10) {
                    if isEnglish {
                        Image(systemName: "note.text")
                            .font(
                                .system(
                                    size: 20,
                                    weight: .heavy
                                )
                            )
                            .foregroundStyle(Color.orange)

                        VStack(
                            alignment: .leading,
                            spacing: 3
                        ) {
                            Text(
                                tr(
                                    "הערות מאמן",
                                    "Coach notes"
                                )
                            )
                            .font(
                                .system(
                                    size: 16,
                                    weight: .heavy
                                )
                            )
                            .foregroundStyle(
                                Color.black.opacity(0.88)
                            )

                            Text(
                                isExpanded.wrappedValue
                                ? tr(
                                    "כתיבה ועדכון של הערות המאמן",
                                    "Write and update coach notes"
                                )
                                : tr(
                                    "לחצו לפתיחת הערות המאמן",
                                    "Tap to open coach notes"
                                )
                            )
                            .font(
                                .system(
                                    size: 12,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(
                                Color.black.opacity(0.55)
                            )
                        }

                        Spacer(minLength: 0)

                        Image(
                            systemName:
                                isExpanded.wrappedValue
                                ? "chevron.up"
                                : "chevron.down"
                        )
                        .font(
                            .system(
                                size: 14,
                                weight: .heavy
                            )
                        )
                        .foregroundStyle(
                            Color.black.opacity(0.55)
                        )

                    } else {
                        Image(
                            systemName:
                                isExpanded.wrappedValue
                                ? "chevron.up"
                                : "chevron.down"
                        )
                        .font(
                            .system(
                                size: 14,
                                weight: .heavy
                            )
                        )
                        .foregroundStyle(
                            Color.black.opacity(0.55)
                        )

                        Spacer(minLength: 0)

                        VStack(
                            alignment: .trailing,
                            spacing: 3
                        ) {
                            Text(
                                tr(
                                    "הערות מאמן",
                                    "Coach notes"
                                )
                            )
                            .font(
                                .system(
                                    size: 16,
                                    weight: .heavy
                                )
                            )
                            .foregroundStyle(
                                Color.black.opacity(0.88)
                            )
                            .multilineTextAlignment(.trailing)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .trailing
                            )

                            Text(
                                isExpanded.wrappedValue
                                ? tr(
                                    "כתיבה ועדכון של הערות המאמן",
                                    "Write and update coach notes"
                                )
                                : tr(
                                    "לחצו לפתיחת הערות המאמן",
                                    "Tap to open coach notes"
                                )
                            )
                            .font(
                                .system(
                                    size: 12,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(
                                Color.black.opacity(0.55)
                            )
                            .multilineTextAlignment(.trailing)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .trailing
                            )
                        }

                        Image(systemName: "note.text")
                            .font(
                                .system(
                                    size: 20,
                                    weight: .heavy
                                )
                            )
                            .foregroundStyle(Color.orange)
                    }
                }
                .environment(
                    \.layoutDirection,
                    .leftToRight
                )
                .padding(14)
                .background(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                    .fill(Color.orange.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                    .stroke(
                        Color.orange.opacity(0.24),
                        lineWidth: 1
                    )
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                VStack(
                    alignment:
                        isEnglish
                        ? .leading
                        : .trailing,
                    spacing: 9
                ) {
                    Text(
                        tr(
                            "טקסט ההערה",
                            "Note text"
                        )
                    )
                    .font(
                        .system(
                            size: 13,
                            weight: .heavy
                        )
                    )
                    .foregroundStyle(Color.orange)
                    .multilineTextAlignment(
                        screenTextAlignment
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: screenFrameAlignment
                    )

                    TextEditor(
                        text: Binding(
                            get: {
                                coachNotes[trainee.id] ??
                                trainee.coachNotes
                            },
                            set: { newValue in
                                coachNotes[trainee.id] =
                                    newValue
                            }
                        )
                    )
                    .frame(minHeight: 110)
                    .scrollContentBackground(.hidden)
                    .padding(9)
                    .background(
                        Color(
                            red: 0.98,
                            green: 0.985,
                            blue: 1.0
                        )
                    )
                    .foregroundStyle(
                        Color.black.opacity(0.88)
                    )
                    .multilineTextAlignment(
                        screenTextAlignment
                    )
                    .environment(
                        \.layoutDirection,
                        screenLayoutDirection
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 14,
                            style: .continuous
                        )
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: 14,
                            style: .continuous
                        )
                        .stroke(
                            Color.orange.opacity(0.30),
                            lineWidth: 1
                        )
                    )

                    Button {
                        saveCoachNotes(for: trainee)
                    } label: {
                        HStack(spacing: 8) {
                            if isSavingNotes {
                                ProgressView()
                                    .tint(.white)
                            }

                            Text(
                                isSavingNotes
                                ? tr(
                                    "שומר...",
                                    "Saving..."
                                )
                                : tr(
                                    "שמור הערות",
                                    "Save notes"
                                )
                            )
                            .font(
                                .system(
                                    size: 15,
                                    weight: .heavy
                                )
                            )
                            .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(
                                cornerRadius: 16,
                                style: .continuous
                            )
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.orange,
                                        Color(
                                            red: 0.93,
                                            green: 0.36,
                                            blue: 0.10
                                        )
                                    ],
                                    startPoint:
                                        isEnglish
                                        ? .leading
                                        : .trailing,
                                    endPoint:
                                        isEnglish
                                        ? .trailing
                                        : .leading
                                )
                            )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSavingNotes)
                    .opacity(
                        isSavingNotes ? 0.55 : 1.0
                    )
                }
                .padding(10)
                .background(
                    RoundedRectangle(
                        cornerRadius: 16,
                        style: .continuous
                    )
                    .fill(Color.black.opacity(0.035))
                )
                .transition(
                    .opacity.combined(
                        with: .move(edge: .top)
                    )
                )
            }
        }
    }

    private func labeledField(
        _ label: String,
        _ value: String
    ) -> some View {

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

    private func clampedPercent(
        _ value: Int
    ) -> Int {
        min(100, max(0, value))
    }

    /*
     * שם מנורמל לצורך זיהוי רשומות כפולות.
     * מסיר סימני פיסוק, גרשיים, מקפים ורווחים כפולים.
     */
    private func normalizedMergeName(
        _ value: String
    ) -> String {
        normalize(value)
            .folding(
                options: [
                    .diacriticInsensitive,
                    .widthInsensitive
                ],
                locale: Locale(identifier: "he_IL")
            )
            .replacingOccurrences(
                of: #"[\."'\u05F3\u05F4,;:()\[\]{}_\-]"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()
    }

    private func normalizedMergeEmail(
        _ value: String
    ) -> String {
        value
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()
            .replacingOccurrences(
                of: " ",
                with: ""
            )
    }

    private func normalizedMergePhone(
        _ value: String
    ) -> String {
        var digits =
            value.filter(\.isNumber)

        guard !digits.isEmpty else {
            return ""
        }

        /*
         * מאחד:
         * 97252... עם 052...
         * 0097252... עם 052...
         */
        if digits.hasPrefix("00972") {
            digits =
                String(digits.dropFirst(5))
        } else if digits.hasPrefix("972") {
            digits =
                String(digits.dropFirst(3))
        }

        while
            digits.count > 10,
            digits.hasPrefix("0") {
            digits.removeFirst()
        }

        if digits.count == 9,
           !digits.hasPrefix("0") {
            digits = "0" + digits
        }

        return digits
    }

    private func areSameTrainee(
        _ lhs: CoachTraineeProfile,
        _ rhs: CoachTraineeProfile
    ) -> Bool {
        let lhsEmail =
            normalizedMergeEmail(lhs.email)

        let rhsEmail =
            normalizedMergeEmail(rhs.email)

        let lhsPhone =
            normalizedMergePhone(lhs.phone)

        let rhsPhone =
            normalizedMergePhone(rhs.phone)

        let lhsName =
            normalizedMergeName(lhs.fullName)

        let rhsName =
            normalizedMergeName(rhs.fullName)

        /*
         * התאמת מייל היא ההתאמה החזקה ביותר.
         */
        if !lhsEmail.isEmpty,
           lhsEmail == rhsEmail {
            return true
        }

        /*
         * לאחר נרמול קידומת ישראל, התאמת טלפון
         * נחשבת גם היא לזיהוי חד־משמעי.
         */
        if !lhsPhone.isEmpty,
           lhsPhone == rhsPhone {
            return true
        }

        let bothHaveComparableEmails =
            !lhsEmail.isEmpty &&
            !rhsEmail.isEmpty

        let bothHaveComparablePhones =
            !lhsPhone.isEmpty &&
            !rhsPhone.isEmpty

        /*
         * אם קיימים אצל שתי הרשומות פרטי קשר
         * מאותו סוג והם שונים, לא מאחדים רק בגלל שם זהה.
         * כך נמנעת מחיקה של שני אנשים שונים בעלי אותו שם.
         */
        if bothHaveComparableEmails ||
            bothHaveComparablePhones {
            return false
        }

        /*
         * שם משמש כגיבוי כאשר באחת הרשומות
         * חסרים פרטי קשר.
         */
        return
            !lhsName.isEmpty &&
            lhsName == rhsName
    }

    private func traineeProfileRichness(
        _ profile: CoachTraineeProfile
    ) -> Int {
        var score = 0

        if !profile.userDocId.isEmpty {
            score += 20
        }

        if !profile.email.isEmpty {
            score += 8
        }

        if !profile.phone.isEmpty {
            score += 8
        }

        if !profile.belt.isEmpty {
            score += 5
        }

        if !profile.seniority.isEmpty {
            score += 4
        }

        if profile.age > 0 {
            score += 4
        }

        if profile.attendancePct > 0 {
            score += 4
        }

        if !profile.branch.isEmpty {
            score += 3
        }

        if !profile.groupKey.isEmpty {
            score += 3
        }

        if !profile.coachNotes.isEmpty {
            score += 3
        }

        score += profile.beltAwardDates.count
        score += profile.beltAwardDescriptions.count
        score += profile.seminarDates.count
        score += profile.campDates.count
        score += profile.certificationDates.count

        return score
    }

    private func preferredNonEmpty(
        _ primary: String,
        _ secondary: String
    ) -> String {
        let first =
            primary.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        if !first.isEmpty {
            return first
        }

        return secondary.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private func mergedStringMap(
        primary: [String: String],
        secondary: [String: String]
    ) -> [String: String] {
        var result = secondary

        for entry in primary {
            let value =
                entry.value.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            if !value.isEmpty {
                result[entry.key] = value
            }
        }

        return result
    }

    private func mergedDateEntryMap(
        primary: [String: CoachDateEntry],
        secondary: [String: CoachDateEntry]
    ) -> [String: CoachDateEntry] {
        var result = secondary

        for entry in primary {
            let primaryDate =
                entry.value.date.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            let primaryDescription =
                entry.value.description
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

            if let secondaryEntry = result[entry.key] {
                result[entry.key] =
                    CoachDateEntry(
                        date:
                            primaryDate.isEmpty
                            ? secondaryEntry.date
                            : primaryDate,
                        description:
                            primaryDescription.isEmpty
                            ? secondaryEntry.description
                            : primaryDescription
                    )
            } else {
                result[entry.key] =
                    CoachDateEntry(
                        date: primaryDate,
                        description: primaryDescription
                    )
            }
        }

        return result
    }

    private func mergeTraineeProfiles(
        _ first: CoachTraineeProfile,
        _ second: CoachTraineeProfile
    ) -> CoachTraineeProfile {
        /*
         * הרשומה העשירה יותר משמשת כרשומה הראשית,
         * כדי שהשמירה תתבצע למסמך Firestore המתאים ביותר.
         */
        let firstScore =
            traineeProfileRichness(first)

        let secondScore =
            traineeProfileRichness(second)

        let primary =
            firstScore >= secondScore
            ? first
            : second

        let secondary =
            firstScore >= secondScore
            ? second
            : first

        return CoachTraineeProfile(
            id: primary.id,
            userDocId: preferredNonEmpty(
                primary.userDocId,
                secondary.userDocId
            ),
            fullName: preferredNonEmpty(
                primary.fullName,
                secondary.fullName
            ),
            email: preferredNonEmpty(
                primary.email,
                secondary.email
            ),
            phone: preferredNonEmpty(
                primary.phone,
                secondary.phone
            ),
            belt: preferredNonEmpty(
                primary.belt,
                secondary.belt
            ),
            seniority: preferredNonEmpty(
                primary.seniority,
                secondary.seniority
            ),
            age:
                primary.age > 0
                ? primary.age
                : secondary.age,
            attendancePct:
                max(
                    primary.attendancePct,
                    secondary.attendancePct
                ),
            branch: preferredNonEmpty(
                primary.branch,
                secondary.branch
            ),
            groupKey: preferredNonEmpty(
                primary.groupKey,
                secondary.groupKey
            ),
            coachNotes: preferredNonEmpty(
                primary.coachNotes,
                secondary.coachNotes
            ),
            beltAwardDates:
                mergedStringMap(
                    primary: primary.beltAwardDates,
                    secondary: secondary.beltAwardDates
                ),
            beltAwardDescriptions:
                mergedStringMap(
                    primary:
                        primary.beltAwardDescriptions,
                    secondary:
                        secondary.beltAwardDescriptions
                ),
            seminarDates:
                mergedDateEntryMap(
                    primary: primary.seminarDates,
                    secondary: secondary.seminarDates
                ),
            campDates:
                mergedDateEntryMap(
                    primary: primary.campDates,
                    secondary: secondary.campDates
                ),
            certificationDates:
                mergedDateEntryMap(
                    primary:
                        primary.certificationDates,
                    secondary:
                        secondary.certificationDates
                )
        )
    }

    private func mergeDuplicateTrainees(
        _ source: [CoachTraineeProfile]
    ) -> [CoachTraineeProfile] {
        var merged: [CoachTraineeProfile] = []

        for incoming in source {
            if let existingIndex =
                merged.firstIndex(
                    where: {
                        areSameTrainee(
                            $0,
                            incoming
                        )
                    }
                ) {

                merged[existingIndex] =
                    mergeTraineeProfiles(
                        merged[existingIndex],
                        incoming
                    )

            } else {
                merged.append(incoming)
            }
        }

        return merged.sorted {
            $0.fullName.localizedCaseInsensitiveCompare(
                $1.fullName
            ) == .orderedAscending
        }
    }

    private func createAndSharePDF(
        for trainee: CoachTraineeProfile
    ) {
        do {
            let url = try createTraineePDF(
                for: trainee
            )

            pdfShareItem = CoachPDFShareItem(
                url: url
            )

        } catch {
            alertText = tr(
                "לא ניתן היה ליצור את קובץ ה־PDF.",
                "The PDF file could not be created."
            )
            showAlert = true
        }
    }

    private func createTraineePDF(
        for trainee: CoachTraineeProfile
    ) throws -> URL {
        let pageWidth: CGFloat = 595
        let pageHeight: CGFloat = 842
        let horizontalPadding: CGFloat = 44
        let contentWidth =
            pageWidth - horizontalPadding * 2

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            "Creator":
                "K.M.I",
            "Title":
                tr(
                    "כרטיס מתאמן - \(trainee.fullName)",
                    "Trainee profile - \(trainee.fullName)"
                )
        ]

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(
                x: 0,
                y: 0,
                width: pageWidth,
                height: pageHeight
            ),
            format: format
        )

        let currentBeltDates =
            beltAwardDates[trainee.id] ??
            trainee.beltAwardDates

        let currentBeltDescriptions =
            beltAwardDescriptions[trainee.id] ??
            trainee.beltAwardDescriptions

        let currentSeminars =
            seminarDates[trainee.id] ??
            trainee.seminarDates

        let currentCamps =
            campDates[trainee.id] ??
            trainee.campDates

        let currentCertifications =
            certificationDates[trainee.id] ??
            trainee.certificationDates

        let currentNotes =
            coachNotes[trainee.id] ??
            trainee.coachNotes

        let data = renderer.pdfData { context in
            let navy = UIColor(
                red: 2 / 255,
                green: 43 / 255,
                blue: 74 / 255,
                alpha: 1
            )

            let brandBlue = UIColor(
                red: 36 / 255,
                green: 103 / 255,
                blue: 158 / 255,
                alpha: 1
            )

            let lightBrandBlue = UIColor(
                red: 128 / 255,
                green: 183 / 255,
                blue: 220 / 255,
                alpha: 1
            )

            let sectionBackground = UIColor(
                red: 234 / 255,
                green: 246 / 255,
                blue: 255 / 255,
                alpha: 1
            )

            let sectionBorder = UIColor(
                red: 191 / 255,
                green: 213 / 255,
                blue: 232 / 255,
                alpha: 1
            )

            var y: CGFloat = 145

            func beginPage() {
                context.beginPage()

                let cg = context.cgContext

                cg.setFillColor(
                    UIColor.white.cgColor
                )
                cg.fill(
                    CGRect(
                        x: 0,
                        y: 0,
                        width: pageWidth,
                        height: pageHeight
                    )
                )

                /*
                 * כותרת אלכסונית זהה לשפת העיצוב
                 * של קובץ ה־PDF במסך הבית.
                 */
                let banner = UIBezierPath()

                banner.move(
                    to: CGPoint(
                        x: pageWidth,
                        y: 0
                    )
                )
                banner.addLine(
                    to: CGPoint(
                        x: pageWidth,
                        y: 122
                    )
                )
                banner.addLine(
                    to: CGPoint(
                        x: 178,
                        y: 122
                    )
                )
                banner.addLine(
                    to: CGPoint(
                        x: 238,
                        y: 0
                    )
                )
                banner.close()

                navy.setFill()
                banner.fill()

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

                brandBlue.setFill()
                stripeOne.fill()

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

                lightBrandBlue.setFill()
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

                let logoParagraph =
                    NSMutableParagraphStyle()
                logoParagraph.alignment = .center

                NSAttributedString(
                    string: "KAMI",
                    attributes: [
                        .font:
                            UIFont.boldSystemFont(
                                ofSize: 23
                            ),
                        .foregroundColor: navy,
                        .paragraphStyle: logoParagraph
                    ]
                )
                .draw(
                    in: CGRect(
                        x: 42,
                        y: 46,
                        width: 72,
                        height: 30
                    )
                )

                let headerParagraph =
                    NSMutableParagraphStyle()

                headerParagraph.alignment =
                    isEnglish ? .left : .right

                headerParagraph.baseWritingDirection =
                    isEnglish
                    ? .leftToRight
                    : .rightToLeft

                NSAttributedString(
                    string: tr(
                        "כרטיס מתאמן",
                        "Trainee Profile"
                    ),
                    attributes: [
                        .font:
                            UIFont.boldSystemFont(
                                ofSize: 27
                            ),
                        .foregroundColor:
                            UIColor.white,
                        .paragraphStyle:
                            headerParagraph
                    ]
                )
                .draw(
                    in: CGRect(
                        x: 285,
                        y: 28,
                        width: 270,
                        height: 38
                    )
                )

                NSAttributedString(
                    string: trainee.fullName,
                    attributes: [
                        .font:
                            UIFont.systemFont(
                                ofSize: 15,
                                weight: .semibold
                            ),
                        .foregroundColor:
                            UIColor.white
                                .withAlphaComponent(0.88),
                        .paragraphStyle:
                            headerParagraph
                    ]
                )
                .draw(
                    in: CGRect(
                        x: 285,
                        y: 70,
                        width: 270,
                        height: 30
                    )
                )

                y = 145
            }

            func drawText(
                _ text: String,
                font: UIFont,
                color: UIColor = .label,
                spacingAfter: CGFloat = 8
            ) {
                guard !text.isEmpty else {
                    return
                }

                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment =
                    isEnglish ? .left : .right
                paragraph.baseWritingDirection =
                    isEnglish ? .leftToRight : .rightToLeft
                paragraph.lineBreakMode = .byWordWrapping
                paragraph.lineSpacing = 2

                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: paragraph
                ]

                let calculatedRect =
                    (text as NSString).boundingRect(
                        with: CGSize(
                            width: contentWidth,
                            height: .greatestFiniteMagnitude
                        ),
                        options: [
                            .usesLineFragmentOrigin,
                            .usesFontLeading
                        ],
                        attributes: attributes,
                        context: nil
                    )

                let textHeight =
                    ceil(calculatedRect.height) + 4

                if y + textHeight >
                    pageHeight - 48 {
                    beginPage()
                }

                let rect = CGRect(
                    x: horizontalPadding,
                    y: y,
                    width: contentWidth,
                    height: textHeight
                )

                (text as NSString).draw(
                    with: rect,
                    options: [
                        .usesLineFragmentOrigin,
                        .usesFontLeading
                    ],
                    attributes: attributes,
                    context: nil
                )

                y += textHeight + spacingAfter
            }

            func drawDivider() {
                if y + 18 > pageHeight - 48 {
                    beginPage()
                }

                let path = UIBezierPath()
                path.move(
                    to: CGPoint(
                        x: horizontalPadding,
                        y: y + 5
                    )
                )
                path.addLine(
                    to: CGPoint(
                        x: pageWidth - horizontalPadding,
                        y: y + 5
                    )
                )

                UIColor.systemBlue
                    .withAlphaComponent(0.24)
                    .setStroke()

                path.lineWidth = 1
                path.stroke()

                y += 18
            }

            func drawSectionTitle(
                _ title: String
            ) {
                if y + 48 > pageHeight - 48 {
                    beginPage()
                }

                let cardRect = CGRect(
                    x: horizontalPadding,
                    y: y,
                    width: contentWidth,
                    height: 40
                )

                let cardPath = UIBezierPath(
                    roundedRect: cardRect,
                    cornerRadius: 10
                )

                sectionBackground.setFill()
                cardPath.fill()

                sectionBorder.setStroke()
                cardPath.lineWidth = 1
                cardPath.stroke()

                let paragraph =
                    NSMutableParagraphStyle()

                paragraph.alignment =
                    isEnglish ? .left : .right

                paragraph.baseWritingDirection =
                    isEnglish
                    ? .leftToRight
                    : .rightToLeft

                NSAttributedString(
                    string: title,
                    attributes: [
                        .font:
                            UIFont.systemFont(
                                ofSize: 17,
                                weight: .bold
                            ),
                        .foregroundColor: navy,
                        .paragraphStyle: paragraph
                    ]
                )
                .draw(
                    in: CGRect(
                        x: horizontalPadding + 12,
                        y: y + 9,
                        width: contentWidth - 24,
                        height: 24
                    )
                )

                y += 50
            }

            func drawDateEntries(
                title: String,
                entries: [String: CoachDateEntry]
            ) {
                let populatedEntries =
                    entries
                        .filter { _, entry in
                            !entry.date
                                .trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                )
                                .isEmpty ||
                            !entry.description
                                .trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                )
                                .isEmpty
                        }
                        .sorted {
                            $0.key.localizedStandardCompare(
                                $1.key
                            ) == .orderedAscending
                        }

                guard !populatedEntries.isEmpty else {
                    return
                }

                drawSectionTitle(title)

                for entry in populatedEntries {
                    let cleanDate =
                        entry.value.date
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )

                    let cleanDescription =
                        entry.value.description
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )

                    let value = [
                        entry.key,
                        cleanDate,
                        cleanDescription
                    ]
                    .filter { !$0.isEmpty }
                    .joined(separator: " — ")

                    drawText(
                        value,
                        font: .systemFont(
                            ofSize: 13,
                            weight: .regular
                        )
                    )
                }
            }

            beginPage()

            drawText(
                tr(
                    "סניף: \(trainee.branch.isEmpty ? branchLabel : trainee.branch)",
                    "Branch: \(trainee.branch.isEmpty ? branchLabel : trainee.branch)"
                ),
                font: .systemFont(
                    ofSize: 14,
                    weight: .semibold
                )
            )

            drawText(
                tr(
                    "קבוצה: \(trainee.groupKey.isEmpty ? groupLabel : trainee.groupKey)",
                    "Group: \(trainee.groupKey.isEmpty ? groupLabel : trainee.groupKey)"
                ),
                font: .systemFont(
                    ofSize: 14,
                    weight: .semibold
                )
            )

            drawSectionTitle(
                tr("פרטים אישיים", "Personal details")
            )

            let personalLines = [
                tr(
                    "דוא״ל: \(trainee.email.isEmpty ? "—" : trainee.email)",
                    "Email: \(trainee.email.isEmpty ? "—" : trainee.email)"
                ),
                tr(
                    "טלפון: \(trainee.phone.isEmpty ? "—" : trainee.phone)",
                    "Phone: \(trainee.phone.isEmpty ? "—" : trainee.phone)"
                ),
                tr(
                    "גיל: \(trainee.age > 0 ? String(trainee.age) : "—")",
                    "Age: \(trainee.age > 0 ? String(trainee.age) : "—")"
                ),
                tr(
                    "חגורה: \(beltNameForUi(trainee.belt))",
                    "Belt: \(beltNameForUi(trainee.belt))"
                ),
                tr(
                    "ותק: \(trainee.seniority.isEmpty ? "—" : trainee.seniority)",
                    "Seniority: \(trainee.seniority.isEmpty ? "—" : trainee.seniority)"
                ),
                tr(
                    "נוכחות: \(trainee.attendancePct)%",
                    "Attendance: \(trainee.attendancePct)%"
                )
            ]

            for line in personalLines {
                drawText(
                    line,
                    font: .systemFont(
                        ofSize: 14,
                        weight: .regular
                    )
                )
            }

            let populatedBelts =
                beltDateOrder.filter { belt in
                    let date =
                        currentBeltDates[belt]?
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ) ?? ""

                    let description =
                        currentBeltDescriptions[belt]?
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ) ?? ""

                    return !date.isEmpty ||
                        !description.isEmpty
                }

            if !populatedBelts.isEmpty {
                drawSectionTitle(
                    tr(
                        "תאריכי קבלת חגורות",
                        "Belt award dates"
                    )
                )

                for belt in populatedBelts {
                    let date =
                        currentBeltDates[belt]?
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ) ?? ""

                    let description =
                        currentBeltDescriptions[belt]?
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ) ?? ""

                    let value = [
                        beltNameForUi(belt),
                        date,
                        description
                    ]
                    .filter { !$0.isEmpty }
                    .joined(separator: " — ")

                    drawText(
                        value,
                        font: .systemFont(
                            ofSize: 13,
                            weight: .regular
                        )
                    )
                }
            }

            drawDateEntries(
                title: tr(
                    "השתלמויות",
                    "Seminars"
                ),
                entries: currentSeminars
            )

            drawDateEntries(
                title: tr(
                    "מחנות אימונים",
                    "Training camps"
                ),
                entries: currentCamps
            )

            drawDateEntries(
                title: tr(
                    "הסמכות",
                    "Certifications"
                ),
                entries: currentCertifications
            )

            if !currentNotes
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty {

                drawSectionTitle(
                    tr(
                        "הערות מאמן",
                        "Coach notes"
                    )
                )

                drawText(
                    currentNotes,
                    font: .systemFont(
                        ofSize: 14,
                        weight: .regular
                    )
                )
            }

            drawDivider()

            drawText(
                tr(
                    "הופק באמצעות אפליקציית ק.מ.י",
                    "Generated by the K.M.I application"
                ),
                font: .systemFont(
                    ofSize: 11,
                    weight: .medium
                ),
                color: .secondaryLabel
            )
        }

        let cleanName =
            trainee.fullName
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .components(
                    separatedBy:
                        CharacterSet
                            .alphanumerics
                            .inverted
                )
                .filter { !$0.isEmpty }
                .joined(separator: "_")

        let fileName =
            cleanName.isEmpty
            ? "KMI_Trainee.pdf"
            : "KMI_\(cleanName).pdf"

        let fileURL =
            FileManager.default
                .temporaryDirectory
                .appendingPathComponent(fileName)

        try data.write(
            to: fileURL,
            options: .atomic
        )

        return fileURL
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

                    let rawBeltDates =
                        data["beltAwardDates"] as? [String: Any] ?? [:]

                    let parsedBeltDates =
                        rawBeltDates.reduce(
                            into: [String: String]()
                        ) { result, entry in
                            let key =
                                entry.key.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                )

                            let value =
                                "\(entry.value)"
                                    .trimmingCharacters(
                                        in: .whitespacesAndNewlines
                                    )

                            guard
                                !key.isEmpty,
                                !value.isEmpty
                            else {
                                return
                            }

                            result[key] = value
                        }

                    let rawBeltDescriptions =
                        data["beltAwardDescriptions"]
                            as? [String: Any] ?? [:]

                    let parsedBeltDescriptions =
                        rawBeltDescriptions.reduce(
                            into: [String: String]()
                        ) { result, entry in
                            let key =
                                entry.key.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                )

                            let value =
                                "\(entry.value)"
                                    .trimmingCharacters(
                                        in: .whitespacesAndNewlines
                                    )

                            guard
                                !key.isEmpty,
                                !value.isEmpty,
                                value.lowercased() != "null"
                            else {
                                return
                            }

                            result[key] = value
                        }

                    let parsedSeminarDates =
                        readCoachDateEntryMap(
                            from: data["seminarDates"]
                        )

                    let parsedCampDates =
                        readCoachDateEntryMap(
                            from: data["campDates"]
                        )

                    let parsedCertificationDates =
                        readCoachDateEntryMap(
                            from: data["certificationDates"]
                        )

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
                        beltAwardDescriptions: parsedBeltDescriptions,
                        seminarDates: parsedSeminarDates,
                        campDates: parsedCampDates,
                        certificationDates: parsedCertificationDates
                    )
                }
                .sorted { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending }

                /*
                 * איחוד רשומות כפולות:
                 * מייל זהה, טלפון זהה או שם מנורמל זהה
                 * כאשר אין פרטי קשר סותרים.
                 */
                let unique =
                    mergeDuplicateTrainees(rows)

                trainees = unique

                for trainee in unique {
                    if coachNotes[trainee.id] == nil {
                        coachNotes[trainee.id] = trainee.coachNotes
                    }

                    if beltAwardDates[trainee.id] == nil {
                        beltAwardDates[trainee.id] =
                            trainee.beltAwardDates
                    }

                    if beltAwardDescriptions[trainee.id] == nil {
                        beltAwardDescriptions[trainee.id] =
                            trainee.beltAwardDescriptions
                    }

                    if seminarDates[trainee.id] == nil {
                        seminarDates[trainee.id] =
                            trainee.seminarDates
                    }

                    if campDates[trainee.id] == nil {
                        campDates[trainee.id] = trainee.campDates
                    }

                    if certificationDates[trainee.id] == nil {
                        certificationDates[trainee.id] =
                            trainee.certificationDates
                    }
                }

                syncSelectedTrainee()

                /*
                 * Firestore users מספק את פרטי הפרופיל.
                 * רשומות הנוכחות הן מקור האמת לאחוזי הנוכחות,
                 * בדיוק כמו במסך Android.
                 */
                loadRealAttendancePercentages(
                    for: unique,
                    fallbackBranch: branchPrimary,
                    fallbackGroup: groupKey
                )
            }
    }

    private func loadRealAttendancePercentages(
        for profiles: [CoachTraineeProfile],
        fallbackBranch: String,
        fallbackGroup: String
    ) {
        guard !profiles.isEmpty else {
            isLoadingAttendance = false
            return
        }

        isLoadingAttendance = true

        let calendar = Calendar.current
        let today = Date()

        let fromDate =
            calendar.date(
                byAdding: .day,
                value: -59,
                to: today
            ) ?? today

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let fromIso = formatter.string(from: fromDate)
        let toIso = formatter.string(from: today)

        Task {
            var updatedProfiles = profiles

            for index in updatedProfiles.indices {
                let profile = updatedProfiles[index]

                let branchName: String = {
                    let profileBranch = normalize(profile.branch)
                    return profileBranch.isEmpty
                        ? normalize(fallbackBranch)
                        : profileBranch
                }()

                let groupName: String = {
                    let profileGroup = normalize(profile.groupKey)
                    return profileGroup.isEmpty
                        ? normalize(fallbackGroup)
                        : profileGroup
                }()

                guard
                    !branchName.isEmpty,
                    !groupName.isEmpty
                else {
                    continue
                }

                do {
                    let history =
                        try await AttendanceRepository.shared
                            .memberAttendanceHistoryFromFirestore(
                                branchName: branchName,
                                groupKey: groupName,
                                memberId: profile.id,
                                memberName: profile.fullName,
                                requestedFromIso: fromIso,
                                toIso: toIso
                            )

                    /*
                     * סטטוס unknown אינו נחשב כאימון שנערך.
                     * כך הוא לא מוריד את אחוז הנוכחות.
                     */
                    let countedSessions =
                        history.sessions.filter {
                            $0.status != .unknown
                        }

                    guard !countedSessions.isEmpty else {
                        continue
                    }

                    let presentCount =
                        countedSessions.filter {
                            $0.status == .present
                        }
                        .count

                    let percentage =
                        Int(
                            (
                                Double(presentCount) /
                                Double(countedSessions.count) *
                                100.0
                            )
                            .rounded()
                        )

                    updatedProfiles[index].attendancePct =
                        clampedPercent(percentage)

                } catch {
                    /*
                     * במקרה שרשומות הנוכחות אינן זמינות,
                     * נשמר ערך הגיבוי שנקרא ממסמך המשתמש.
                     */
                    continue
                }
            }

            await MainActor.run {
                /*
                 * מבצעים איחוד נוסף לאחר העשרת נתוני הנוכחות,
                 * כדי שגם רענון אסינכרוני לא יחזיר כפילויות למסך.
                 */
                trainees =
                    mergeDuplicateTrainees(
                        updatedProfiles
                    )

                isLoadingAttendance = false
                syncSelectedTrainee()
            }
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

    private func saveBeltAwardDates(
        for trainee: CoachTraineeProfile
    ) {
        guard !isSavingBeltDates else {
            return
        }

        let userDocId =
            trainee.userDocId.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !userDocId.isEmpty else {
            showMessage(
                tr(
                    "לא נמצא מזהה משתמש לשמירת נתוני החגורות",
                    "Missing user ID for saving belt data"
                )
            )
            return
        }

        let dates =
            beltAwardDates[trainee.id] ??
            trainee.beltAwardDates

        let descriptions =
            beltAwardDescriptions[trainee.id] ??
            trainee.beltAwardDescriptions

        let cleanedDates =
            dates.reduce(
                into: [String: String]()
            ) { result, entry in
                let key =
                    entry.key.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                let value =
                    entry.value.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                guard
                    !key.isEmpty,
                    !value.isEmpty
                else {
                    return
                }

                result[key] = value
            }

        let cleanedDescriptions =
            descriptions.reduce(
                into: [String: String]()
            ) { result, entry in
                let key =
                    entry.key.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                let value =
                    entry.value.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                guard
                    !key.isEmpty,
                    !value.isEmpty
                else {
                    return
                }

                result[key] = value
            }

        guard
            !cleanedDates.isEmpty ||
            !cleanedDescriptions.isEmpty
        else {
            showMessage(
                tr(
                    "אין נתוני חגורות לשמירה",
                    "No belt data to save"
                )
            )
            return
        }

        var updates: [String: Any] = [:]

        for entry in cleanedDates {
            updates[
                "beltAwardDates.\(entry.key)"
            ] = entry.value
        }

        for entry in cleanedDescriptions {
            updates[
                "beltAwardDescriptions.\(entry.key)"
            ] = entry.value
        }

        isSavingBeltDates = true

        Firestore.firestore()
            .collection("users")
            .document(userDocId)
            .updateData(updates) { error in
                isSavingBeltDates = false

                if let error {
                    showMessage(
                        tr(
                            "שמירת נתוני החגורות נכשלה: \(error.localizedDescription)",
                            "Saving belt data failed: \(error.localizedDescription)"
                        )
                    )
                } else {
                    showMessage(
                        tr(
                            "נתוני החגורות נשמרו",
                            "Belt data saved"
                        )
                    )
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

        let cleanedEntries =
            entries.reduce(
                into: [String: CoachDateEntry]()
            ) { result, entry in
                let key =
                    entry.key.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                let date =
                    entry.value.date.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                let description =
                    entry.value.description.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

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

    @Binding var isExpanded: Bool
    @Binding var entries: [String: CoachDateEntry]

    let isSaving: Bool
    let onSave: () -> Void

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
                isExpanded.toggle()

                if !isExpanded {
                    expandedItem = nil
                    datePickerItem = nil
                }
            } label: {
                HStack(spacing: 10) {
                    if isEnglish {
                        Text(sectionKind.icon)
                            .font(.system(size: 24))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(
                                sectionKind.title(
                                    isEnglish: isEnglish
                                )
                            )
                            .font(
                                .system(
                                    size: 16,
                                    weight: .heavy
                                )
                            )
                            .foregroundStyle(
                                Color(uiColor: .label)
                            )
                            .multilineTextAlignment(.leading)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )

                            Text(
                                sectionKind.subtitle(
                                    isEnglish: isEnglish,
                                    isExpanded: isExpanded
                                )
                            )
                            .font(
                                .system(
                                    size: 12,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(
                                Color(
                                    uiColor: .secondaryLabel
                                )
                            )
                            .multilineTextAlignment(.leading)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )
                        }

                        Image(
                            systemName:
                                isExpanded
                                ? "chevron.up"
                                : "chevron.down"
                        )
                        .font(
                            .system(
                                size: 14,
                                weight: .heavy
                            )
                        )
                        .foregroundStyle(sectionKind.accent)

                    } else {
                        Image(
                            systemName:
                                isExpanded
                                ? "chevron.up"
                                : "chevron.down"
                        )
                        .font(
                            .system(
                                size: 14,
                                weight: .heavy
                            )
                        )
                        .foregroundStyle(sectionKind.accent)

                        VStack(alignment: .trailing, spacing: 3) {
                            Text(
                                sectionKind.title(
                                    isEnglish: isEnglish
                                )
                            )
                            .font(
                                .system(
                                    size: 16,
                                    weight: .heavy
                                )
                            )
                            .foregroundStyle(
                                Color(uiColor: .label)
                            )
                            .multilineTextAlignment(.trailing)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .trailing
                            )
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )

                            Text(
                                sectionKind.subtitle(
                                    isEnglish: isEnglish,
                                    isExpanded: isExpanded
                                )
                            )
                            .font(
                                .system(
                                    size: 12,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(
                                Color(
                                    uiColor: .secondaryLabel
                                )
                            )
                            .multilineTextAlignment(.trailing)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .trailing
                            )
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )
                        }

                        Text(sectionKind.icon)
                            .font(.system(size: 24))
                    }
                }
                .environment(
                    \.layoutDirection,
                    .leftToRight
                )
                .padding(14)
                .background(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                    .fill(
                        Color(
                            uiColor:
                                .secondarySystemBackground
                        )
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                    .stroke(
                        sectionKind.accent.opacity(0.32),
                        lineWidth: 1
                    )
                )
                .contentShape(Rectangle())
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
                                .environment(
                                    \.layoutDirection,
                                    .leftToRight
                                )
                                .padding(12)
                                .background(
                                    RoundedRectangle(
                                        cornerRadius: 16,
                                        style: .continuous
                                    )
                                    .fill(
                                        Color(
                                            uiColor:
                                                .secondarySystemBackground
                                        )
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(
                                        cornerRadius: 16,
                                        style: .continuous
                                    )
                                    .stroke(
                                        isItemExpanded
                                        ? sectionKind.accent.opacity(0.60)
                                        : sectionKind.accent.opacity(0.22),
                                        lineWidth:
                                            isItemExpanded ? 1.3 : 1
                                    )
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

                                            Text(
                                                entry.date.isEmpty
                                                ? tr(
                                                    "בחר תאריך מלוח השנה",
                                                    "Choose a date from calendar"
                                                )
                                                : entry.date
                                            )
                                            .font(
                                                .system(
                                                    size: 16,
                                                    weight: .heavy
                                                )
                                            )
                                            .environment(
                                                \.layoutDirection,
                                                .leftToRight
                                            )
                                            .foregroundStyle(
                                                entry.date.isEmpty
                                                ? Color(uiColor: .secondaryLabel)
                                                : Color(uiColor: .label)
                                            )
                                            .multilineTextAlignment(textAlignment)
                                            .frame(
                                                maxWidth: .infinity,
                                                alignment: frameAlignment
                                            )
                                            }
                                            .padding(12)
                                            .background(
                                                RoundedRectangle(
                                                    cornerRadius: 16,
                                                    style: .continuous
                                                )
                                            .fill(
                                                Color(
                                                    uiColor:
                                                        .tertiarySystemBackground
                                                )
                                            )
                                        )
                                        .overlay(
                                            RoundedRectangle(
                                                cornerRadius: 16,
                                                style: .continuous
                                            )
                                            .stroke(
                                                sectionKind.accent.opacity(0.58),
                                                lineWidth: 1
                                            )
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
                                        .scrollContentBackground(.hidden)
                                        .background(
                                            Color(
                                                uiColor:
                                                    .secondarySystemBackground
                                            )
                                        )
                                        .foregroundStyle(
                                            Color(
                                                uiColor: .label
                                            )
                                        )
                                        .multilineTextAlignment(
                                            textAlignment
                                        )
                                        .environment(
                                            \.layoutDirection,
                                            isEnglish
                                            ? .leftToRight
                                            : .rightToLeft
                                        )
                                        .clipShape(
                                            RoundedRectangle(
                                                cornerRadius: 14,
                                                style: .continuous
                                            )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                                        )
                                    }
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(
                                        cornerRadius: 16,
                                        style: .continuous
                                    )
                                    .fill(
                                        Color(
                                            uiColor:
                                                .tertiarySystemBackground
                                        )
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(
                                        cornerRadius: 16,
                                        style: .continuous
                                    )
                                    .stroke(
                                        sectionKind.accent.opacity(0.16),
                                        lineWidth: 1
                                    )
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

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.colorScheme)
    private var colorScheme

    @State
    private var showNationalStatistics = false

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var layoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    private var panelColor: Color {
        isDarkMode
        ? Color(
            red: 0.09,
            green: 0.14,
            blue: 0.23
        )
        : Color.white.opacity(0.96)
    }

    private var primaryTextColor: Color {
        isDarkMode
        ? Color.white.opacity(0.95)
        : Color.black.opacity(0.86)
    }

    private var secondaryTextColor: Color {
        isDarkMode
        ? Color.white.opacity(0.66)
        : Color.black.opacity(0.54)
    }

    private var borderColor: Color {
        isDarkMode
        ? Color.white.opacity(0.13)
        : Color.black.opacity(0.08)
    }

    private func tr(
        _ he: String,
        _ en: String
    ) -> String {
        isEnglish ? en : he
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(
                            red: 0.06,
                            green: 0.10,
                            blue: 0.18
                        ),
                        Color(
                            red: 0.08,
                            green: 0.25,
                            blue: 0.39
                        ),
                        Color(
                            red: 0.04,
                            green: 0.52,
                            blue: 0.78
                        )
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(
                    showsIndicators: false
                ) {
                    VStack(
                        alignment:
                            isEnglish
                            ? .leading
                            : .trailing,
                        spacing: 14
                    ) {
                        headerCard

                        nationalStatisticsCard

                        VStack(spacing: 10) {
                            statRow(
                                title: tr(
                                    "סה״כ מתאמנים",
                                    "Total trainees"
                                ),
                                value: "\(stats.total)",
                                icon: "person.3.fill"
                            )

                            statRow(
                                title: tr(
                                    "מתאמנים מסוננים",
                                    "Filtered trainees"
                                ),
                                value: "\(stats.filtered)",
                                icon:
                                    "line.3.horizontal.decrease.circle.fill"
                            )

                            statRow(
                                title: tr(
                                    "גיל ממוצע",
                                    "Average age"
                                ),
                                value:
                                    stats.avgAge > 0
                                    ? "\(stats.avgAge)"
                                    : "—",
                                icon: "calendar"
                            )

                            statRow(
                                title: tr(
                                    "נוכחות ממוצעת",
                                    "Average attendance"
                                ),
                                value:
                                    "\(stats.avgAttendance)%",
                                icon:
                                    "checkmark.circle.fill"
                            )

                            statRow(
                                title: tr(
                                    "נוכחות גבוהה",
                                    "High attendance"
                                ),
                                value:
                                    "\(stats.highAttendance)",
                                icon: "star.circle.fill"
                            )
                        }

                        beltDistributionCard
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(
                tr(
                    "סטטיסטיקה",
                    "Statistics"
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement:
                        isEnglish
                        ? .topBarLeading
                        : .topBarTrailing
                ) {
                    Button {
                        dismiss()
                    } label: {
                        Image(
                            systemName:
                                "xmark.circle.fill"
                        )
                        .font(
                            .system(
                                size: 22,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(
                            Color.white.opacity(0.92)
                        )
                    }
                    .accessibilityLabel(
                        tr("סגור", "Close")
                    )
                }
            }
        }
        .environment(
            \.layoutDirection,
            layoutDirection
        )
        .fullScreenCover(
            isPresented: $showNationalStatistics
        ) {
            CoachNationalStatisticsView(
                isEnglish: isEnglish
            )
        }
    }

    private var nationalStatisticsCard: some View {
        Button {
            showNationalStatistics = true
        } label: {
            HStack(spacing: 14) {
                if isEnglish {
                    nationalStatisticsIcon

                    nationalStatisticsText

                    Spacer(minLength: 8)

                    Image(
                        systemName: "chevron.right"
                    )
                    .font(
                        .system(
                            size: 16,
                            weight: .black
                        )
                    )
                    .foregroundStyle(
                        Color.white.opacity(0.90)
                    )

                } else {
                    Image(
                        systemName: "chevron.left"
                    )
                    .font(
                        .system(
                            size: 16,
                            weight: .black
                        )
                    )
                    .foregroundStyle(
                        Color.white.opacity(0.90)
                    )

                    Spacer(minLength: 8)

                    nationalStatisticsText

                    nationalStatisticsIcon
                }
            }
            .environment(
                \.layoutDirection,
                .leftToRight
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(
                maxWidth: .infinity
            )
            .background(
                LinearGradient(
                    colors: [
                        Color(
                            red: 0.10,
                            green: 0.48,
                            blue: 0.96
                        ),
                        Color(
                            red: 0.15,
                            green: 0.69,
                            blue: 0.93
                        )
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 19,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 19,
                    style: .continuous
                )
                .stroke(
                    Color.white.opacity(0.22),
                    lineWidth: 1
                )
            )
            .shadow(
                color: Color.blue.opacity(
                    isDarkMode ? 0.28 : 0.18
                ),
                radius: 9,
                x: 0,
                y: 5
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            tr(
                "פתיחת סטטיסטיקה ארצית",
                "Open national statistics"
            )
        )
    }

    private var nationalStatisticsText: some View {
        VStack(
            alignment:
                isEnglish
                ? .leading
                : .trailing,
            spacing: 3
        ) {
            Text(
                tr(
                    "סטטיסטיקה ארצית",
                    "National statistics"
                )
            )
            .font(
                .system(
                    size: 18,
                    weight: .black
                )
            )
            .foregroundStyle(.white)
            .multilineTextAlignment(
                textAlignment
            )
            .frame(
                maxWidth: .infinity,
                alignment: frameAlignment
            )

            Text(
                tr(
                    "השוואת נתונים בין כל הסניפים",
                    "Compare data across all branches"
                )
            )
            .font(
                .system(
                    size: 12,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                Color.white.opacity(0.78)
            )
            .multilineTextAlignment(
                textAlignment
            )
            .frame(
                maxWidth: .infinity,
                alignment: frameAlignment
            )
        }
    }

    private var nationalStatisticsIcon: some View {
        Image(
            systemName: "chart.bar.xaxis"
        )
        .font(
            .system(
                size: 23,
                weight: .black
            )
        )
        .foregroundStyle(.white)
        .frame(
            width: 48,
            height: 48
        )
        .background(
            Circle()
                .fill(
                    Color.white.opacity(0.17)
                )
        )
        .overlay(
            Circle()
                .stroke(
                    Color.white.opacity(0.20),
                    lineWidth: 1
                )
        )
    }

    private var headerCard: some View {
        VStack(
            alignment:
                isEnglish
                ? .leading
                : .trailing,
            spacing: 8
        ) {
            HStack(spacing: 10) {
                if isEnglish {
                    Image(
                        systemName:
                            "chart.bar.xaxis"
                    )
                    .font(
                        .system(
                            size: 25,
                            weight: .black
                        )
                    )
                    .foregroundStyle(.cyan)

                    Text("Group statistics")
                        .font(
                            .system(
                                size: 25,
                                weight: .black
                            )
                        )
                        .foregroundStyle(.white)

                    Spacer(minLength: 0)

                } else {
                    Spacer(minLength: 0)

                    Text("סטטיסטיקה לקבוצה")
                        .font(
                            .system(
                                size: 25,
                                weight: .black
                            )
                        )
                        .foregroundStyle(.white)
                        .multilineTextAlignment(
                            .trailing
                        )

                    Image(
                        systemName:
                            "chart.bar.xaxis"
                    )
                    .font(
                        .system(
                            size: 25,
                            weight: .black
                        )
                    )
                    .foregroundStyle(.cyan)
                }
            }
            .environment(
                \.layoutDirection,
                .leftToRight
            )

            Text(
                tr(
                    "סניף: \(branchLabel)",
                    "Branch: \(branchLabel)"
                )
            )
            .font(
                .system(
                    size: 13,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                .white.opacity(0.80)
            )
            .multilineTextAlignment(
                textAlignment
            )
            .frame(
                maxWidth: .infinity,
                alignment: frameAlignment
            )

            Text(
                tr(
                    "קבוצה: \(groupLabel)",
                    "Group: \(groupLabel)"
                )
            )
            .font(
                .system(
                    size: 13,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                .white.opacity(0.80)
            )
            .multilineTextAlignment(
                textAlignment
            )
            .frame(
                maxWidth: .infinity,
                alignment: frameAlignment
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .fill(Color.black.opacity(0.22))
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(0.15),
                lineWidth: 1
            )
        )
    }

    private var beltDistributionCard:
        some View {

        VStack(
            alignment:
                isEnglish
                ? .leading
                : .trailing,
            spacing: 10
        ) {
            Text(
                tr(
                    "חלוקה לפי חגורות",
                    "Belt distribution"
                )
            )
            .font(
                .system(
                    size: 18,
                    weight: .black
                )
            )
            .foregroundStyle(.white)
            .multilineTextAlignment(
                textAlignment
            )
            .frame(
                maxWidth: .infinity,
                alignment: frameAlignment
            )

            if stats.beltCounts.isEmpty {
                Text(
                    tr(
                        "אין נתוני חגורות להצגה",
                        "No belt data to show"
                    )
                )
                .font(
                    .system(
                        size: 14,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    .white.opacity(0.72)
                )
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(18)

            } else {
                VStack(spacing: 8) {
                    ForEach(
                        stats.beltCounts
                    ) { belt in
                        statRow(
                            title: belt.title,
                            value: "\(belt.count)",
                            icon: "circle.fill",
                            accent:
                                statsAccentColor(
                                    for: belt.title
                                )
                        )
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .fill(Color.black.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(0.14),
                lineWidth: 1
            )
        )
    }

    private func statsAccentColor(
        for beltTitle: String
    ) -> Color {
        let value =
            beltTitle
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

        if value.contains("yellow") ||
            value.contains("צהוב") {
            return Color(
                red: 0.95,
                green: 0.72,
                blue: 0.08
            )
        }

        if value.contains("orange") ||
            value.contains("כתומ") {
            return .orange
        }

        if value.contains("green") ||
            value.contains("ירוק") {
            return .green
        }

        if value.contains("blue") ||
            value.contains("כחול") {
            return .blue
        }

        if value.contains("brown") ||
            value.contains("חומ") {
            return .brown
        }

        if value.contains("black") ||
            value.contains("שחור") {
            return isDarkMode
            ? Color.white.opacity(0.90)
            : Color.black.opacity(0.88)
        }

        if value.contains("white") ||
            value.contains("לבנ") {
            return isDarkMode
            ? Color.white.opacity(0.76)
            : Color.gray
        }

        return .blue
    }

    private func statRow(
        title: String,
        value: String,
        icon: String,
        accent: Color = .blue
    ) -> some View {
        HStack(spacing: 12) {
            if isEnglish {
                Image(systemName: icon)
                    .font(
                        .system(
                            size: 18,
                            weight: .heavy
                        )
                    )
                    .foregroundStyle(accent)

                Text(title)
                    .font(
                        .system(
                            size: 15,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        primaryTextColor
                    )
                    .multilineTextAlignment(
                        .leading
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                Spacer(minLength: 8)

                Text(value)
                    .font(
                        .system(
                            size: 18,
                            weight: .black
                        )
                    )
                    .foregroundStyle(
                        primaryTextColor
                    )

            } else {
                Text(value)
                    .font(
                        .system(
                            size: 18,
                            weight: .black
                        )
                    )
                    .foregroundStyle(
                        primaryTextColor
                    )

                Spacer(minLength: 8)

                Text(title)
                    .font(
                        .system(
                            size: 15,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        primaryTextColor
                    )
                    .multilineTextAlignment(
                        .trailing
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                Image(systemName: icon)
                    .font(
                        .system(
                            size: 18,
                            weight: .heavy
                        )
                    )
                    .foregroundStyle(accent)
            }
        }
        .environment(
            \.layoutDirection,
            .leftToRight
        )
        .padding(14)
        .background(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(panelColor)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(
                accent.opacity(
                    isDarkMode ? 0.30 : 0.18
                ),
                lineWidth: 1
            )
        )
        .shadow(
            color:
                Color.black.opacity(
                    isDarkMode ? 0.16 : 0.06
                ),
            radius: 5,
            x: 0,
            y: 3
        )
    }
}

private struct CoachBeltAwardDatesSection: View {

    @Environment(\.colorScheme) private var colorScheme

    let isEnglish: Bool
    let beltOrder: [String]

    @Binding var isExpanded: Bool
    @Binding var dates: [String: String]
    @Binding var descriptions: [String: String]

    let isSaving: Bool
    let onSave: () -> Void

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
            /*
             * במצב כהה שחור טהור נעלם על הכרטיס.
             * משתמשים בגוון בהיר, אך רק לצורכי התצוגה.
             */
            return colorScheme == .dark
                ? Color.white.opacity(0.88)
                : Color.black

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
                isExpanded.toggle()

                if !isExpanded {
                    expandedBelt = nil
                    datePickerBelt = nil
                }
            } label: {
                HStack(spacing: 10) {
                    if isEnglish {
                        Text("📅")
                            .font(.system(size: 24))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(tr("תאריכי קבלת חגורות", "Belt award dates"))
                                .font(.system(size: 16, weight: .heavy))
                                .foregroundStyle(Color(uiColor: .label))

                            Text(isExpanded ? tr("עדכון תאריכים לפי חגורה", "Update dates by belt") : tr("לחצו לפתיחת רשימת החגורות", "Tap to open the belt list"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color(uiColor: .secondaryLabel))
                        }

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Color(uiColor: .secondaryLabel))

                    } else {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Color(uiColor: .secondaryLabel))

                        Spacer()

                        VStack(alignment: .trailing, spacing: 3) {
                            Text(tr("תאריכי קבלת חגורות", "Belt award dates"))
                                .font(.system(size: 16, weight: .heavy))
                                .foregroundStyle(Color(uiColor: .label))

                            Text(isExpanded ? tr("עדכון תאריכים לפי חגורה", "Update dates by belt") : tr("לחצו לפתיחת רשימת החגורות", "Tap to open the belt list"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color(uiColor: .secondaryLabel))
                        }

                        Text("📅")
                            .font(.system(size: 24))
                    }
                }
                .environment(
                    \.layoutDirection,
                    .leftToRight
                )
                .padding(14)
                .background(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                    .fill(
                        Color(
                            uiColor:
                                .secondarySystemBackground
                        )
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                    .stroke(
                        Color.purple.opacity(0.30),
                        lineWidth: 1
                    )
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 10) {
                    ForEach(beltOrder, id: \.self) { belt in
                        let currentDate =
                            dates[belt, default: ""]

                        let currentDescription =
                            descriptions[belt, default: ""]

                        let hasDate =
                            !currentDate
                                .trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                )
                                .isEmpty

                        let hasDescription =
                            !currentDescription
                                .trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                )
                                .isEmpty

                        let hasData =
                            hasDate || hasDescription

                        let accent =
                            accentColor(for: belt)

                        let isBeltExpanded =
                            expandedBelt == belt

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
                                                .foregroundStyle(Color(uiColor: .label))

                                            Text(hasDate ? tr("תאריך קבלה: \(currentDate)", "Award date: \(currentDate)") : tr("אין תאריך קבלה", "No award date"))
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(hasDate ? Color.green.opacity(0.86) : Color.gray.opacity(0.78))
                                        }

                                        Spacer()

                                        Image(
                                            systemName:
                                                hasData
                                                ? "checkmark.circle.fill"
                                                : "xmark.circle.fill"
                                        )
                                        .foregroundStyle(
                                            hasData
                                            ? Color.green
                                            : Color.red.opacity(0.82)
                                        )

                                        Image(systemName: isBeltExpanded ? "chevron.up" : "chevron.down")
                                            .foregroundStyle(Color.gray)

                                    } else {
                                        Image(systemName: isBeltExpanded ? "chevron.up" : "chevron.down")
                                            .foregroundStyle(Color.gray)

                                        Image(
                                            systemName:
                                                hasData
                                                ? "checkmark.circle.fill"
                                                : "xmark.circle.fill"
                                        )
                                        .foregroundStyle(
                                            hasData
                                            ? Color.green
                                            : Color.red.opacity(0.82)
                                        )

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 3) {
                                            Text(beltNameForUi(belt))
                                                .font(.system(size: 15, weight: .heavy))
                                                .foregroundStyle(Color(uiColor: .label))

                                            Text(hasDate ? tr("תאריך קבלה: \(currentDate)", "Award date: \(currentDate)") : tr("אין תאריך קבלה", "No award date"))
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(hasDate ? Color.green.opacity(0.86) : Color.gray.opacity(0.78))
                                        }

                                        Circle()
                                            .fill(accent)
                                            .frame(width: 10, height: 10)
                                    }
                                }
                                .environment(
                                    \.layoutDirection,
                                    .leftToRight
                                )
                                .padding(12)
                                .background(
                                    RoundedRectangle(
                                        cornerRadius: 16,
                                        style: .continuous
                                    )
                                    .fill(
                                        Color(
                                            uiColor:
                                                .secondarySystemBackground
                                        )
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(
                                        cornerRadius: 16,
                                        style: .continuous
                                    )
                                    .stroke(
                                        isBeltExpanded
                                        ? accent.opacity(0.62)
                                        : accent.opacity(0.24),
                                        lineWidth:
                                            isBeltExpanded ? 1.3 : 1
                                    )
                                )
                            }
                            .buttonStyle(.plain)

                            if isBeltExpanded {
                                VStack(
                                    alignment:
                                        isEnglish
                                        ? .leading
                                        : .trailing,
                                    spacing: 10
                                ) {
                                            Button {
                                                pendingDate =
                                                    dateFromText(currentDate)

                                                datePickerBelt = belt
                                            } label: {
                                                VStack(
                                                    alignment:
                                                        isEnglish
                                                        ? .leading
                                                        : .trailing,
                                                    spacing: 4
                                                ) {
                                                    Text(
                                                        tr(
                                                            "תאריך קבלה",
                                                            "Award date"
                                                        )
                                                    )
                                                    .font(
                                                        .system(
                                                            size: 12,
                                                            weight: .heavy
                                                        )
                                                    )
                                                    .foregroundStyle(accent)
                                                    .multilineTextAlignment(
                                                        textAlignment
                                                    )
                                                    .frame(
                                                        maxWidth: .infinity,
                                                        alignment: frameAlignment
                                                    )

                                                    Text(
                                                        hasDate
                                                        ? currentDate
                                                        : tr(
                                                            "בחר תאריך מלוח השנה",
                                                            "Choose a date from calendar"
                                                        )
                                                    )
                                                    .font(
                                                        .system(
                                                            size: 16,
                                                            weight: .heavy
                                                        )
                                                    )
                                                    .environment(
                                                        \.layoutDirection,
                                                        .leftToRight
                                                    )
                                                    .foregroundStyle(
                                                        hasDate
                                                        ? Color(uiColor: .label)
                                                        : Color(uiColor: .secondaryLabel)
                                                    )
                                                    .multilineTextAlignment(
                                                        textAlignment
                                                    )
                                                    .frame(
                                                        maxWidth: .infinity,
                                                        alignment: frameAlignment
                                                    )
                                                }
                                                .padding(12)
                                                .background(
                                                    RoundedRectangle(
                                                        cornerRadius: 16,
                                                        style: .continuous
                                                    )
                                                    .fill(
                                                        Color(
                                                            uiColor:
                                                                .tertiarySystemBackground
                                                        )
                                                    )
                                                )
                                                .overlay(
                                                    RoundedRectangle(
                                                        cornerRadius: 16,
                                                        style: .continuous
                                                    )
                                                    .stroke(
                                                        accent.opacity(0.70),
                                                        lineWidth: 1
                                                    )
                                                )
                                            }
                                            .buttonStyle(.plain)

                                            VStack(
                                                alignment:
                                                    isEnglish
                                                    ? .leading
                                                    : .trailing,
                                                spacing: 5
                                            ) {
                                                Text(
                                                    tr(
                                                        "תיאור / הערת מאמן",
                                                        "Description / coach note"
                                                    )
                                                )
                                                .font(
                                                    .system(
                                                        size: 12,
                                                        weight: .heavy
                                                    )
                                                )
                                                .foregroundStyle(accent)
                                                .multilineTextAlignment(
                                                    textAlignment
                                                )
                                                .frame(
                                                    maxWidth: .infinity,
                                                    alignment: frameAlignment
                                                )

                                                TextEditor(
                                                    text: Binding(
                                                        get: {
                                                            descriptions[
                                                                belt,
                                                                default: ""
                                                            ]
                                                        },
                                                        set: { newValue in
                                                            descriptions[belt] =
                                                                newValue
                                                        }
                                                    )
                                                )
                                                .frame(minHeight: 82)
                                                .scrollContentBackground(.hidden)
                                                .padding(8)
                                                .background(
                                                    Color(
                                                        uiColor:
                                                            .secondarySystemBackground
                                                    )
                                                )
                                                .foregroundStyle(
                                                    Color(uiColor: .label)
                                                )
                                                .multilineTextAlignment(
                                                    textAlignment
                                                )
                                                .environment(
                                                    \.layoutDirection,
                                                    isEnglish
                                                    ? .leftToRight
                                                    : .rightToLeft
                                                )
                                                .clipShape(
                                                    RoundedRectangle(
                                                        cornerRadius: 14,
                                                        style: .continuous
                                                    )
                                                )
                                                .overlay(
                                                    RoundedRectangle(
                                                        cornerRadius: 14,
                                                        style: .continuous
                                                    )
                                                    .stroke(
                                                        accent.opacity(0.28),
                                                        lineWidth: 1
                                                    )
                                                )
                                            }
                                        }
                                .padding(10)
                                .background(
                                    RoundedRectangle(
                                        cornerRadius: 16,
                                        style: .continuous
                                    )
                                    .fill(
                                        Color(
                                            uiColor:
                                                .tertiarySystemBackground
                                        )
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(
                                        cornerRadius: 16,
                                        style: .continuous
                                    )
                                    .stroke(
                                        accent.opacity(0.16),
                                        lineWidth: 1
                                    )
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

                            Text(
                                isSaving
                                ? tr("שומר...", "Saving...")
                                : tr(
                                    "שמור נתוני חגורות",
                                    "Save belt data"
                                )
                            )
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

    /*
     * מתחיל מנתוני Firestore שבמסמך המשתמש,
     * ולאחר מכן מתעדכן מנתוני הנוכחות האמיתיים.
     */
    var attendancePct: Int

    let branch: String
    let groupKey: String
    let coachNotes: String

    let beltAwardDates: [String: String]
    let beltAwardDescriptions: [String: String]

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
