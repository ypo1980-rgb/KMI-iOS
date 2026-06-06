import SwiftUI
import FirebaseFirestore

struct AdminUsersView: View {

    @State private var users: [AdminUser] = []
    @State private var filteredUsers: [AdminUser] = []

    @State private var searchText: String = ""
    @State private var selectedRole: UserRoleFilter = .all

    @State private var selectedGender: AdminGenderFilter = .all
    @State private var selectedRegion: String? = nil
    @State private var selectedBelt: String? = nil
    @State private var selectedAgeBucket: String? = nil

    @State private var loading = true
    @State private var errorMessage: String? = nil
    @State private var unlikeQuestions: [AssistantFeedbackQuestion] = []

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

    private var rowChevronName: String {
        isEnglish ? "chevron.right" : "chevron.left"
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private func roleTextForUi(_ role: String) -> String {
        if AdminUser.isAdminRole(role) {
            return tr("מנהל", "Admin")
        }

        if AdminUser.isCoachRole(role) {
            return tr("מאמן", "Coach")
        }

        return tr("מתאמן", "Trainee")
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var allRegionsForFilter: [String] {
        users
            .map { $0.region.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter {
                $0.caseInsensitiveCompare("לא ידוע") != .orderedSame &&
                $0.caseInsensitiveCompare("unknown") != .orderedSame &&
                $0.caseInsensitiveCompare("null") != .orderedSame &&
                $0 != "—"
            }
            .uniqueCaseInsensitiveSorted()
    }

    private var allBeltsForFilter: [String] {
        users
            .map { beltLabel($0.currentBeltId) }
            .filter { !$0.isEmpty }
            .uniqueCaseInsensitiveSorted()
    }

    private var allAgeBucketsForFilter: [String] {
        users
            .map { $0.ageBucket }
            .filter { $0 != "לא ידוע" }
            .uniqueCaseInsensitiveSorted()
            .sorted { ageBucketSortIndex($0) < ageBucketSortIndex($1) }
    }

    var body: some View {

        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.04, blue: 0.11),
                    Color(red: 0.07, green: 0.12, blue: 0.22),
                    Color(red: 0.08, green: 0.30, blue: 0.55),
                    Color(red: 0.03, green: 0.64, blue: 0.89)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {

                    screenHeader

                    headerStats

                    advancedFiltersPanel

                    distributionsDashboard

                    searchBar

                    if let errorMessage, !errorMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        errorMessageCard(errorMessage)
                    }

                    if loading {
                        loadingUsersState

                    } else if filteredUsers.isEmpty {
                        emptyUsersState

                    } else {
                        usersSectionsList
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .environment(\.layoutDirection, screenLayoutDirection)
        .onAppear {
            loadUsers()
        }
        .onChange(of: searchText) { _, _ in
            applyFilter()
        }
    }

    private var loadingUsersState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.white)

            Text(tr("טוען משתמשים מהשרת...", "Loading users from the server..."))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.88))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.bottom, 40)
    }

    private var emptyUsersState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))

            Text(tr("לא נמצאו משתמשים תואמים", "No matching users found"))
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(tr("נסה לשנות חיפוש או סינון", "Try changing the search or filters"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)

            Button {
                clearAllFilters()
            } label: {
                Text(tr("נקה סינון", "Clear filters"))
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.88))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.94))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.24), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.top, 46)
        .padding(.bottom, 36)
    }
 
    // MARK: Users sections

    private var usersSectionsList: some View {

        let adminUsers = filteredUsers.filter { AdminUser.isAdminRole($0.role) }

        let coachUsers = filteredUsers.filter { user in
            !AdminUser.isAdminRole(user.role) &&
            (user.isCoach || AdminUser.isCoachRole(user.role))
        }

        let traineeUsers = filteredUsers.filter { user in
            !AdminUser.isAdminRole(user.role) &&
            !(user.isCoach || AdminUser.isCoachRole(user.role))
        }

        return VStack(spacing: 12) {

            userSectionCard(
                title: tr("משתמשים – מתאמנים (\(traineeUsers.count))", "Users – trainees (\(traineeUsers.count))"),
                users: traineeUsers,
                emptyMessage: tr("אין מתאמנים מתאימים לפילטרים.", "No trainees match the selected filters.")
            )

            userSectionCard(
                title: tr("משתמשים – מאמנים (\(coachUsers.count))", "Users – coaches (\(coachUsers.count))"),
                users: coachUsers,
                emptyMessage: tr("אין מאמנים מתאימים לפילטרים.", "No coaches match the selected filters.")
            )

            if !adminUsers.isEmpty {
                userSectionCard(
                    title: tr("משתמשים – מנהלים (\(adminUsers.count))", "Users – admins (\(adminUsers.count))"),
                    users: adminUsers,
                    emptyMessage: tr("אין מנהלים מתאימים לפילטרים.", "No admins match the selected filters.")
                )
            }

            if !unlikeQuestions.isEmpty {
                unlikeQuestionsCard
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
        .padding(.bottom, 10)
    }

    private func userSectionCard(
        title: String,
        users: [AdminUser],
        emptyMessage: String
    ) -> some View {

        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 10) {

            Text(title)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Color(red: 0.89, green: 0.94, blue: 1.0))
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)

            if users.isEmpty {
                Text(emptyMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                    .multilineTextAlignment(screenTextAlignment)
                    .padding(.vertical, 8)

            } else {
                VStack(spacing: 8) {
                    ForEach(users) { user in
                        NavigationLink {
                            AdminUserDetailsView(user: user)
                        } label: {
                            userRow(user)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.04, green: 0.07, blue: 0.13).opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var unlikeQuestionsCard: some View {

        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 10) {

            Text(tr("שאלות לסקירה (UNLIKE)", "Questions for review (UNLIKE)"))
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Color(red: 0.89, green: 0.94, blue: 1.0))
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)

            Text(tr(
                "רשימת שאלות שהעוזר לא ענה עליהן טוב – לסקירה ולשיפור מאגר התכנים.",
                "Questions where the assistant response was marked as not helpful — for review and content improvement."
            ))
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.66))
            .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
            .multilineTextAlignment(screenTextAlignment)
            .lineSpacing(2)

            VStack(spacing: 8) {
                ForEach(unlikeQuestions.prefix(20)) { item in
                    unlikeQuestionRow(item)
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.01, green: 0.03, blue: 0.09).opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(red: 0.22, green: 0.74, blue: 0.97).opacity(0.36), lineWidth: 1)
        )
    }

    private func unlikeQuestionRow(_ item: AssistantFeedbackQuestion) -> some View {

        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 4) {
            Text("• \(item.question)")
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.90))
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)
                .lineLimit(3)

            let meta = item.metaLine(isEnglish: isEnglish)

            if !meta.isEmpty {
                Text(meta)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.52))
                    .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                    .multilineTextAlignment(screenTextAlignment)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.02, green: 0.06, blue: 0.14).opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: Screen header

    private var screenHeader: some View {

        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 5) {
            Text(tr("ניהול משתמשים", "User management"))
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)

            Text(tr("משתמשים אמיתיים מ־Firestore", "Real users from Firestore"))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private func errorMessageCard(_ message: String) -> some View {

        HStack(spacing: 10) {
            if isEnglish {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Color(red: 1.0, green: 0.70, blue: 0.70))

                Text(message)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.82))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)

            } else {
                Text(message)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.82))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Color(red: 1.0, green: 0.70, blue: 0.70))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.35, green: 0.04, blue: 0.08).opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.red.opacity(0.26), lineWidth: 1)
        )
        .padding(.horizontal, 14)
    }

    // MARK: Header stats

    private var headerStats: some View {

        let totalUsers = users.count

        let branchCount = Set(
            users.flatMap { user in
                var values: [String] = []

                let singleBranch = user.branch.trimmingCharacters(in: .whitespacesAndNewlines)

                if !singleBranch.isEmpty {
                    values.append(singleBranch)
                }

                values.append(
                    contentsOf: user.branches
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                )

                return values
            }
            .map { $0.lowercased() }
        )
        .count

        let avgAge = users
            .compactMap { $0.age }
            .averageValue

        let totalAppOpens = users.reduce(0) { $0 + $1.appOpenCount }
        let activeUsers = users.filter { $0.appOpenCount > 0 }.count

        let avgAppOpens: Double? = totalUsers > 0
            ? Double(totalAppOpens) / Double(totalUsers)
            : nil

        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                statItem(
                    tr("משתמשים", "Users"),
                    loading ? "…" : "\(totalUsers)",
                    icon: "person.3.fill"
                )

                statItem(
                    tr("סניפים", "Branches"),
                    loading ? "…" : "\(branchCount)",
                    icon: "building.2.fill"
                )

                statItem(
                    tr("גיל ממוצע", "Avg. age"),
                    loading ? "…" : avgAge.map { String(format: "%.1f", $0) } ?? "-",
                    icon: "calendar"
                )
            }

            HStack(spacing: 8) {
                statItem(
                    tr("שימושים", "App opens"),
                    loading ? "…" : "\(totalAppOpens)",
                    icon: "iphone.gen3"
                )

                statItem(
                    tr("פעילים", "Active"),
                    loading ? "…" : "\(activeUsers)",
                    icon: "bolt.fill"
                )

                statItem(
                    tr("ממוצע שימוש", "Avg. opens"),
                    loading ? "…" : avgAppOpens.map { String(format: "%.1f", $0) } ?? "-",
                    icon: "chart.line.uptrend.xyaxis"
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
    }

    private func statItem(
        _ title: String,
        _ value: String,
        icon: String
    ) -> some View {

        VStack(spacing: 5) {

            Image(systemName: icon)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(Color(red: 0.72, green: 0.91, blue: 1.0))

            Text(value)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(title)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 82)
        .padding(.horizontal, 6)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.02, green: 0.06, blue: 0.14).opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(red: 0.22, green: 0.74, blue: 0.97).opacity(0.32), lineWidth: 1)
        )
    }

    // MARK: Advanced filters

    private var advancedFiltersPanel: some View {

        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 10) {

            Text(tr("סינון משתמשים", "User filters"))
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.white.opacity(0.92))
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)

            filterScrollRow {
                filterChip(
                    title: tr("כולם", "All"),
                    isSelected: selectedRole == .all
                ) {
                    selectedRole = .all
                    applyFilter()
                }

                filterChip(
                    title: tr("מאמנים", "Coaches"),
                    isSelected: selectedRole == .coach
                ) {
                    selectedRole = .coach
                    applyFilter()
                }

                filterChip(
                    title: tr("מתאמנים", "Trainees"),
                    isSelected: selectedRole == .trainee
                ) {
                    selectedRole = .trainee
                    applyFilter()
                }
            }

            filterScrollRow {
                filterChip(
                    title: tr("כל המינים", "All genders"),
                    isSelected: selectedGender == .all
                ) {
                    selectedGender = .all
                    applyFilter()
                }

                filterChip(
                    title: tr("זכר", "Male"),
                    isSelected: selectedGender == .male
                ) {
                    selectedGender = .male
                    applyFilter()
                }

                filterChip(
                    title: tr("נקבה", "Female"),
                    isSelected: selectedGender == .female
                ) {
                    selectedGender = .female
                    applyFilter()
                }
            }

            filterScrollRow {
                filterChip(
                    title: tr("כל האזורים", "All regions"),
                    isSelected: selectedRegion == nil
                ) {
                    selectedRegion = nil
                    applyFilter()
                }

                ForEach(allRegionsForFilter, id: \.self) { region in
                    filterChip(
                        title: region,
                        isSelected: selectedRegion == region
                    ) {
                        selectedRegion = region
                        applyFilter()
                    }
                }
            }

            filterScrollRow {
                filterChip(
                    title: tr("כל החגורות", "All belts"),
                    isSelected: selectedBelt == nil
                ) {
                    selectedBelt = nil
                    applyFilter()
                }

                ForEach(allBeltsForFilter, id: \.self) { belt in
                    filterChip(
                        title: belt,
                        isSelected: selectedBelt == belt
                    ) {
                        selectedBelt = belt
                        applyFilter()
                    }
                }
            }

            filterScrollRow {
                filterChip(
                    title: tr("כל הגילאים", "All ages"),
                    isSelected: selectedAgeBucket == nil
                ) {
                    selectedAgeBucket = nil
                    applyFilter()
                }

                ForEach(allAgeBucketsForFilter, id: \.self) { bucket in
                    filterChip(
                        title: ageBucketLabel(bucket),
                        isSelected: selectedAgeBucket == bucket
                    ) {
                        selectedAgeBucket = bucket
                        applyFilter()
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.02, green: 0.06, blue: 0.14).opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .padding(.horizontal, 14)
    }

    private func filterScrollRow<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
        }
        .environment(\.layoutDirection, screenLayoutDirection)
    }

    private func filterChip(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {

        let textColor: Color = isSelected
            ? Color.black.opacity(0.90)
            : Color.white.opacity(0.92)

        let backgroundColor: Color = isSelected
            ? Color(red: 0.87, green: 0.96, blue: 1.0).opacity(0.98)
            : Color.white.opacity(0.12)

        let borderColor: Color = isSelected
            ? Color.white.opacity(0.32)
            : Color.white.opacity(0.16)

        return Button(action: action) {
            Text(title)
                .font(.system(size: 12.5, weight: .heavy))
                .foregroundColor(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(backgroundColor)
                )
                .overlay(
                    Capsule()
                        .stroke(borderColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Admin dashboard distributions

    private var distributionsDashboard: some View {

        VStack(spacing: 12) {
            genderDistributionCard
            beltDistributionCard
        }
        .padding(.horizontal, 14)
    }

    private var genderDistributionCard: some View {

        let maleCount = users.filter { isMaleGender($0.gender) }.count
        let femaleCount = users.filter { isFemaleGender($0.gender) }.count
        let unknownCount = max(0, users.count - maleCount - femaleCount)
        let maxValue = max(maleCount, femaleCount, unknownCount, 1)

        return VStack(alignment: isEnglish ? .leading : .trailing, spacing: 10) {

            Text(tr("חלוקה לפי מין", "Gender distribution"))
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Color(red: 0.90, green: 0.95, blue: 1.0))
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)

            HStack(spacing: 8) {
                distributionBarItem(
                    title: tr("זכר", "Male"),
                    value: loading ? nil : maleCount,
                    maxValue: maxValue,
                    accent: Color(red: 0.22, green: 0.74, blue: 0.97)
                )

                distributionBarItem(
                    title: tr("נקבה", "Female"),
                    value: loading ? nil : femaleCount,
                    maxValue: maxValue,
                    accent: Color(red: 0.90, green: 0.44, blue: 0.78)
                )

                distributionBarItem(
                    title: tr("לא ידוע", "Unknown"),
                    value: loading ? nil : unknownCount,
                    maxValue: maxValue,
                    accent: Color(red: 0.62, green: 0.68, blue: 0.78)
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.01, green: 0.03, blue: 0.09).opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var beltDistributionCard: some View {

        let beltItems = beltDistributionItems
        let maxValue = max(beltItems.map { $0.count }.max() ?? 0, 1)

        return VStack(alignment: isEnglish ? .leading : .trailing, spacing: 10) {

            Text(tr("חלוקה לפי חגורה", "Belt distribution"))
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Color(red: 0.90, green: 0.95, blue: 1.0))
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(beltItems) { item in
                        beltDistributionItem(
                            item: item,
                            maxValue: maxValue
                        )
                    }
                }
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
            }
            .environment(\.layoutDirection, screenLayoutDirection)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.01, green: 0.03, blue: 0.09).opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func distributionBarItem(
        title: String,
        value: Int?,
        maxValue: Int,
        accent: Color
    ) -> some View {

        let safeValue = value ?? 0
        let ratio = CGFloat(safeValue) / CGFloat(max(maxValue, 1))
        let barHeight = max(8, 58 * ratio)

        return VStack(spacing: 5) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color(red: 0.11, green: 0.16, blue: 0.25).opacity(0.92))
                    .frame(height: 58)

                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(accent.opacity(0.92))
                    .frame(height: value == nil ? 18 : barHeight)
            }
            .frame(maxWidth: .infinity)

            Text(value.map { "\($0)" } ?? "…")
                .font(.system(size: 12.5, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(title)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
    }

    private func beltDistributionItem(
        item: BeltDistributionItem,
        maxValue: Int
    ) -> some View {

        let ratio = CGFloat(item.count) / CGFloat(max(maxValue, 1))
        let beltWidth = max(30, 68 * ratio)

        return VStack(spacing: 5) {

            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(item.color.opacity(0.94))
                .frame(width: loading ? 42 : beltWidth, height: 34)
                .overlay(
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )

            Text(loading ? "…" : "\(item.count)")
                .font(.system(size: 11.5, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(item.label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(width: 76)
    }

    // MARK: Search

    private var searchBar: some View {

        HStack(spacing: 10) {
            if isEnglish {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.black.opacity(0.35))

                TextField(tr("חיפוש משתמש...", "Search user..."), text: $searchText)
                    .foregroundStyle(Color.black.opacity(0.82))
                    .multilineTextAlignment(.leading)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

            } else {
                TextField(tr("חיפוש משתמש...", "Search user..."), text: $searchText)
                    .foregroundStyle(Color.black.opacity(0.82))
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.black.opacity(0.35))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 1)
        )
        .padding(.horizontal, 14)
    }

    // MARK: Row

    private func userRow(_ user: AdminUser) -> some View {

        HStack(spacing: 12) {

            if isEnglish {
                VStack(alignment: .leading, spacing: 6) {
                    userTexts(user)
                }

                Spacer(minLength: 0)

                Image(systemName: rowChevronName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.28))

            } else {
                Image(systemName: rowChevronName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.28))

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 6) {
                    userTexts(user)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)
    }

    private func userTexts(_ user: AdminUser) -> some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 6) {

            if isEnglish {
                HStack(spacing: 8) {
                    Text(user.fullName)
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.84))
                        .lineLimit(1)

                    roleBadge(user.role)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

            } else {
                HStack(spacing: 8) {
                    Spacer(minLength: 0)

                    roleBadge(user.role)

                    Text(user.fullName)
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.84))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if !user.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(user.email)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.52))
                    .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                    .multilineTextAlignment(screenTextAlignment)
                    .lineLimit(1)
            }

            if !user.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(isEnglish ? "Phone: \(user.phone)" : "טלפון: \(user.phone)")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.50))
                    .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                    .multilineTextAlignment(screenTextAlignment)
                    .lineLimit(1)
            }

            Text(user.branchGroupLine(isEnglish: isEnglish))
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.50))
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)
                .lineLimit(2)

            Text(userMetaLine(user))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.46))
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)
                .lineLimit(2)
        }
    }

    private func roleBadge(_ role: String) -> some View {

        HStack(spacing: 5) {
            Image(systemName: roleIcon(role))
                .font(.system(size: 10, weight: .black))

            Text(roleTextForUi(role))
                .font(.system(size: 11, weight: .black))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(roleColor(role))
        )
    }

    private func roleIcon(_ role: String) -> String {
        if AdminUser.isAdminRole(role) {
            return "person.badge.key.fill"
        }

        if AdminUser.isCoachRole(role) {
            return "figure.martial.arts"
        }

        return "person.fill"
    }

    private func roleColor(_ role: String) -> Color {
        if AdminUser.isAdminRole(role) {
            return Color.purple.opacity(0.92)
        }

        if AdminUser.isCoachRole(role) {
            return Color.blue.opacity(0.92)
        }

        return Color.green.opacity(0.88)
    }

    private func userMetaLine(_ user: AdminUser) -> String {
        var parts: [String] = []

        let belt = beltLabel(user.currentBeltId)

        if !belt.isEmpty {
            parts.append(isEnglish ? "Belt: \(belt)" : "חגורה: \(belt)")
        }

        if let age = user.age {
            parts.append(isEnglish ? "Age: \(age)" : "גיל: \(age)")
        }

        let region = user.region.trimmingCharacters(in: .whitespacesAndNewlines)

        if !region.isEmpty {
            parts.append(isEnglish ? "Region: \(region)" : "אזור: \(region)")
        }

        if user.appOpenCount > 0 {
            parts.append(isEnglish ? "Opens: \(user.appOpenCount)" : "שימושים: \(user.appOpenCount)")
        }

        if parts.isEmpty {
            return isEnglish ? "No additional details" : "אין פרטים נוספים"
        }

        return parts.joined(separator: " • ")
    }

    private func genderLabel(_ raw: String) -> String {
        if isMaleGender(raw) {
            return tr("זכר", "Male")
        }

        if isFemaleGender(raw) {
            return tr("נקבה", "Female")
        }

        return tr("לא ידוע", "Unknown")
    }

    private func isMaleGender(_ raw: String) -> Bool {
        let clean = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return clean == "m" ||
            clean == "male" ||
            clean == "זכר" ||
            clean.hasPrefix("m")
    }

    private func isFemaleGender(_ raw: String) -> Bool {
        let clean = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return clean == "f" ||
            clean == "female" ||
            clean == "נקבה" ||
            clean.hasPrefix("f")
    }

    private var beltDistributionItems: [BeltDistributionItem] {
        let orderedIds = [
            "",
            "white",
            "yellow",
            "orange",
            "green",
            "blue",
            "brown",
            "black",
            "black_dan_2",
            "black_dan_3",
            "black_dan_4",
            "black_dan_5",
            "black_dan_6",
            "black_dan_7",
            "black_dan_8",
            "black_dan_9",
            "black_dan_10"
        ]

        let rawCounts = Dictionary(
            grouping: users,
            by: { $0.currentBeltId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        )
        .mapValues { $0.count }

        return orderedIds.compactMap { rawId in
            let label = rawId.isEmpty
                ? tr("ללא חגורה", "No belt")
                : beltLabel(rawId)

            guard !label.isEmpty else {
                return nil
            }

            let count: Int

            if rawId.isEmpty {
                count = users.filter {
                    $0.currentBeltId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }.count
            } else {
                count = rawCounts[rawId] ?? 0
            }

            if count == 0 && rawId != "" {
                return nil
            }

            return BeltDistributionItem(
                id: rawId.isEmpty ? "no_belt" : rawId,
                label: label,
                count: count,
                color: beltColor(rawId)
            )
        }
    }

    private func beltLabel(_ rawId: String) -> String {
        let clean = rawId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch clean {
        case "white":
            return tr("לבנה", "White")
        case "yellow":
            return tr("צהובה", "Yellow")
        case "orange":
            return tr("כתומה", "Orange")
        case "green":
            return tr("ירוקה", "Green")
        case "blue":
            return tr("כחולה", "Blue")
        case "brown":
            return tr("חומה", "Brown")
        case "black", "שחורה", "שחורה דאן 1":
            return tr("שחורה דאן 1", "Black Dan 1")
        case "black_dan_2":
            return tr("שחורה דאן 2", "Black Dan 2")
        case "black_dan_3":
            return tr("שחורה דאן 3", "Black Dan 3")
        case "black_dan_4":
            return tr("שחורה דאן 4", "Black Dan 4")
        case "black_dan_5":
            return tr("שחורה דאן 5", "Black Dan 5")
        case "black_dan_6":
            return tr("שחורה דאן 6", "Black Dan 6")
        case "black_dan_7":
            return tr("שחורה דאן 7", "Black Dan 7")
        case "black_dan_8":
            return tr("שחורה דאן 8", "Black Dan 8")
        case "black_dan_9":
            return tr("שחורה דאן 9", "Black Dan 9")
        case "black_dan_10":
            return tr("שחורה דאן 10", "Black Dan 10")
        default:
            return ""
        }
    }

    private func beltColor(_ rawId: String) -> Color {
        let clean = rawId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch clean {
        case "white", "":
            return Color.white.opacity(0.92)
        case "yellow":
            return Color.yellow.opacity(0.92)
        case "orange":
            return Color.orange.opacity(0.92)
        case "green":
            return Color.green.opacity(0.88)
        case "blue":
            return Color.blue.opacity(0.92)
        case "brown":
            return Color(red: 0.50, green: 0.27, blue: 0.12).opacity(0.94)
        default:
            return Color.black.opacity(0.92)
        }
    }

    private func ageBucketLabel(_ bucket: String) -> String {
        if bucket == "לא ידוע" {
            return tr("לא ידוע", "Unknown")
        }

        return bucket
    }

    private func ageBucketSortIndex(_ bucket: String) -> Int {
        switch bucket {
        case "0–12":
            return 0
        case "13–17":
            return 1
        case "18–25":
            return 2
        case "26–40":
            return 3
        case "41–60":
            return 4
        case "60+":
            return 5
        default:
            return 99
        }
    }

    // MARK: Firestore

    private func loadUsers() {

        loading = true
        errorMessage = nil
        loadUnlikeQuestions()

        Firestore.firestore()
            .collection("users")
            .getDocuments { snapshot, error in

                loading = false

                if let error {
                    let rawMessage = error.localizedDescription

                    if rawMessage.uppercased().contains("PERMISSION_DENIED") {
                        errorMessage = tr(
                            "אין לך הרשאה לצפות ברשימת המשתמשים. בדוק את הרשאות Firestore או פנה למנהל המערכת.",
                            "You do not have permission to view the users list. Check Firestore permissions or contact the system administrator."
                        )
                    } else {
                        errorMessage = rawMessage.isEmpty
                            ? tr("שגיאה בטעינת המשתמשים", "Error loading users")
                            : rawMessage
                    }

                    users = []
                    filteredUsers = []
                    return
                }

                guard let docs = snapshot?.documents else {
                    errorMessage = tr("לא התקבלו נתוני משתמשים מהשרת", "No user data was received from the server")
                    users = []
                    filteredUsers = []
                    return
                }

                let rawUsers = docs
                    .compactMap { doc in
                        AdminUser.from(
                            id: doc.documentID,
                            map: doc.data()
                        )
                    }
                    .filter { user in
                        user.hasRealAdminListContent
                    }

                var uniqueByKey: [String: AdminUser] = [:]

                for user in rawUsers {
                    let key = user.uniqueMergeKey
                    guard !key.isEmpty else { continue }

                    if let existing = uniqueByKey[key] {
                        uniqueByKey[key] = AdminUser.merged(existing: existing, incoming: user)
                    } else {
                        uniqueByKey[key] = user
                    }
                }

                users = uniqueByKey.values.sorted {
                    $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending
                }

                errorMessage = nil
                applyFilter()
            }
    }

    private func loadUnlikeQuestions() {

        Firestore.firestore()
            .collection("assistantFeedback")
            .whereField("liked", isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments { snapshot, _ in

                guard let docs = snapshot?.documents else {
                    unlikeQuestions = []
                    return
                }

                unlikeQuestions = docs.compactMap { doc in
                    AssistantFeedbackQuestion.from(
                        id: doc.documentID,
                        map: doc.data()
                    )
                }
            }
    }

    // MARK: Filter logic

    private func applyFilter() {

        var result = users

        if selectedRole == .coach {
            result = result.filter { $0.isCoach || AdminUser.isCoachRole($0.role) }
        }

        if selectedRole == .trainee {
            result = result.filter {
                !$0.isCoach &&
                !AdminUser.isAdminRole($0.role)
            }
        }

        if selectedGender != .all {
            result = result.filter { user in
                let cleanGender = user.gender
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()

                switch selectedGender {
                case .all:
                    return true

                case .male:
                    return cleanGender == "m" ||
                        cleanGender == "male" ||
                        cleanGender == "זכר" ||
                        cleanGender.hasPrefix("m")

                case .female:
                    return cleanGender == "f" ||
                        cleanGender == "female" ||
                        cleanGender == "נקבה" ||
                        cleanGender.hasPrefix("f")
                }
            }
        }

        if let selectedRegion {
            result = result.filter { user in
                user.region.caseInsensitiveCompare(selectedRegion) == .orderedSame
            }
        }

        if let selectedBelt {
            result = result.filter { user in
                beltLabel(user.currentBeltId).caseInsensitiveCompare(selectedBelt) == .orderedSame
            }
        }

        if let selectedAgeBucket {
            result = result.filter { user in
                user.ageBucket == selectedAgeBucket
            }
        }

        let query = normalizedSearchText

        if !query.isEmpty {

            result = result.filter { user in
                user.fullName.localizedCaseInsensitiveContains(query) ||
                user.email.localizedCaseInsensitiveContains(query) ||
                user.phone.localizedCaseInsensitiveContains(query) ||
                user.region.localizedCaseInsensitiveContains(query) ||
                user.branch.localizedCaseInsensitiveContains(query) ||
                user.branches.joined(separator: " ").localizedCaseInsensitiveContains(query) ||
                user.group.localizedCaseInsensitiveContains(query) ||
                user.groups.joined(separator: " ").localizedCaseInsensitiveContains(query) ||
                user.currentBeltId.localizedCaseInsensitiveContains(query) ||
                beltLabel(user.currentBeltId).localizedCaseInsensitiveContains(query) ||
                user.role.localizedCaseInsensitiveContains(query) ||
                roleTextForUi(user.role).localizedCaseInsensitiveContains(query) ||
                user.branchGroupLine(isEnglish: isEnglish).localizedCaseInsensitiveContains(query)
            }
        }

        filteredUsers = result
    }

    private func clearAllFilters() {
        searchText = ""
        selectedRole = .all
        selectedGender = .all
        selectedRegion = nil
        selectedBelt = nil
        selectedAgeBucket = nil
        applyFilter()
    }
}

enum UserRoleFilter {
    case all
    case coach
    case trainee
}

struct AdminUser: Identifiable {

    let id: String

    let uidField: String
    let fullName: String
    let email: String
    let phone: String

    let gender: String
    let birthDay: Int?
    let birthMonth: Int?
    let birthYear: Int?

    let region: String
    let branch: String
    let branches: [String]

    let group: String
    let groups: [String]

    let currentBeltId: String
    let role: String
    let isCoachFlag: Bool

    let createdAtMillis: Int64?
    let appOpenCount: Int
    let lastSeenAtMillis: Int64?

    var age: Int? {
        guard let birthYear else {
            return nil
        }

        let currentYear = Calendar.current.component(.year, from: Date())
        let roughAge = currentYear - birthYear

        return (0...120).contains(roughAge) ? roughAge : nil
    }

    var ageBucket: String {
        guard let age else {
            return "לא ידוע"
        }

        switch age {
        case 0...12:
            return "0–12"
        case 13...17:
            return "13–17"
        case 18...25:
            return "18–25"
        case 26...40:
            return "26–40"
        case 41...60:
            return "41–60"
        default:
            return "60+"
        }
    }

    var isCoach: Bool {
        if isCoachFlag {
            return true
        }

        if AdminUser.isCoachRole(role) {
            return true
        }

        let groupsText = groups.joined(separator: " ").lowercased()

        return groupsText.contains("מאמן") ||
            groupsText.contains("מאמנים") ||
            groupsText.contains("coach") ||
            groupsText.contains("coaches") ||
            groupsText.contains("trainer")
    }

    static func from(id: String, map: [String: Any]) -> AdminUser? {

        func stringValue(_ keys: String...) -> String {
            for key in keys {
                if let value = map[key] as? String {
                    let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !clean.isEmpty {
                        return clean
                    }
                }

                if let value = map[key], !(value is NSNull) {
                    let clean = "\(value)".trimmingCharacters(in: .whitespacesAndNewlines)
                    if !clean.isEmpty && clean.lowercased() != "null" {
                        return clean
                    }
                }
            }

            return ""
        }

        func intValue(_ keys: String...) -> Int? {
            for key in keys {
                if let value = map[key] as? Int {
                    return value
                }

                if let value = map[key] as? Int64 {
                    return Int(value)
                }

                if let value = map[key] as? Double {
                    return Int(value)
                }

                if let value = map[key] as? String {
                    let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let intValue = Int(clean) {
                        return intValue
                    }
                }
            }

            return nil
        }

        func boolValue(_ keys: String...) -> Bool {
            for key in keys {
                if let value = map[key] as? Bool {
                    return value
                }

                if let value = map[key] as? String {
                    let clean = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if clean == "true" || clean == "1" || clean == "yes" {
                        return true
                    }

                    if clean == "false" || clean == "0" || clean == "no" {
                        return false
                    }
                }

                if let value = map[key] as? Int {
                    return value == 1
                }

                if let value = map[key] as? Double {
                    return value == 1
                }
            }

            return false
        }

        func millisValue(_ keys: String...) -> Int64? {
            for key in keys {
                let value = map[key]

                let rawMillis: Int64?

                if let timestamp = value as? Timestamp {
                    rawMillis = Int64(timestamp.dateValue().timeIntervalSince1970 * 1000)
                } else if let value = value as? Int64 {
                    rawMillis = value
                } else if let value = value as? Int {
                    rawMillis = Int64(value)
                } else if let value = value as? Double {
                    rawMillis = Int64(value)
                } else if let value = value as? String {
                    rawMillis = Int64(value.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    rawMillis = nil
                }

                guard let rawMillis else {
                    continue
                }

                let millis: Int64

                if rawMillis >= 1_000_000_000 && rawMillis <= 9_999_999_999 {
                    millis = rawMillis * 1000
                } else {
                    millis = rawMillis
                }

                let minReasonableMillis: Int64 = 1_577_836_800_000
                let maxReasonableMillis: Int64 = Int64(Date().addingTimeInterval(7 * 24 * 60 * 60).timeIntervalSince1970 * 1000)

                if millis >= minReasonableMillis && millis <= maxReasonableMillis {
                    return millis
                }
            }

            return nil
        }

        func stringListValue(_ keys: String...) -> [String] {
            for key in keys {
                if let list = map[key] as? [String] {
                    let cleanList = list
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }

                    if !cleanList.isEmpty {
                        return cleanList
                    }
                }

                if let list = map[key] as? [Any] {
                    let cleanList = list
                        .map { "\($0)".trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty && $0.lowercased() != "null" }

                    if !cleanList.isEmpty {
                        return cleanList
                    }
                }

                if let value = map[key] as? String {
                    let cleanList = value
                        .split { char in
                            char == "," || char == "•" || char == "|" || char == ";"
                        }
                        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }

                    if !cleanList.isEmpty {
                        return cleanList
                    }
                }
            }

            return []
        }

        let fullName = stringValue(
            "fullName",
            "full_name",
            "name",
            "displayName",
            "userName",
            "username"
        )

        let email = stringValue("email")

        let phone = stringValue(
            "phone",
            "phoneNumber",
            "phone_number"
        )

        let uidField = stringValue(
            "uid",
            "userId"
        )

        let branchesArray = stringListValue(
            "branches",
            "branchNames",
            "selectedBranches",
            "selectedBranchNames",
            "trainingBranches",
            "trainingBranchNames",
            "clubs",
            "dojos"
        )

        let groupsArray = stringListValue(
            "groups",
            "groupNames",
            "groupsCsv",
            "groupCsv",
            "selectedGroups",
            "selectedGroupNames"
        )

        let singleRegion = stringValue(
            "region",
            "area",
            "selectedRegion",
            "trainingRegion"
        )

        let singleBranch = stringValue(
            "activeBranch",
            "active_branch",
            "branch",
            "branchName",
            "selectedBranch",
            "selectedBranchName",
            "trainingBranch",
            "trainingBranchName",
            "club",
            "dojo",
            "branchesCsv"
        )

        let singleGroup = stringValue(
            "primaryGroup",
            "activeGroup",
            "active_group",
            "groupKey",
            "group_key",
            "group",
            "groupName",
            "age_group",
            "ageGroup"
        )

        let resolvedBranch = branchesArray.first ?? singleBranch
        let resolvedGroup = groupsArray.first ?? singleGroup

        let rawRole = stringValue(
            "role",
            "userRole",
            "user_role",
            "profile_role",
            "accountRole",
            "userType",
            "type"
        )

        let isCoachFlag = boolValue(
            "isCoach",
            "coach",
            "isTrainer",
            "trainer",
            "isInstructor",
            "instructor"
        )

        let resolvedRole: String

        if !rawRole.isEmpty {
            resolvedRole = rawRole
        } else if boolValue("isAdmin", "admin", "isManager", "manager") {
            resolvedRole = "admin"
        } else if isCoachFlag {
            resolvedRole = "coach"
        } else {
            let groupsText = groupsArray.joined(separator: " ").lowercased()

            if groupsText.contains("מאמן") ||
                groupsText.contains("מאמנים") ||
                groupsText.contains("coach") ||
                groupsText.contains("coaches") ||
                groupsText.contains("trainer") {
                resolvedRole = "coach"
            } else {
                resolvedRole = "trainee"
            }
        }

        var birthYear = intValue("birthYear")
        var birthMonth = intValue("birthMonth")
        var birthDay = intValue("birthDay")

        let birthDate = stringValue("birthDate")

        if !birthDate.isEmpty {
            let parts = birthDate.split(separator: "-").map { String($0) }

            if parts.count == 3 {
                if birthYear == nil {
                    birthYear = Int(parts[0])
                }

                if birthMonth == nil {
                    birthMonth = Int(parts[1])
                }

                if birthDay == nil {
                    birthDay = Int(parts[2])
                }
            }
        }

        let fallbackName: String

        if !fullName.isEmpty {
            fallbackName = fullName
        } else if !email.isEmpty {
            fallbackName = email
        } else if !phone.isEmpty {
            fallbackName = phone
        } else {
            fallbackName = ""
        }

        let currentBeltId = stringValue(
            "currentBeltId",
            "currentBelt",
            "belt_current",
            "beltId",
            "belt"
        )

        let cleanDisplayName = fallbackName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPhoneDigits = phone.filter { $0.isNumber }

        let hasHumanIdentifier =
            !cleanDisplayName.isEmpty ||
            !cleanEmail.isEmpty ||
            !cleanPhoneDigits.isEmpty

        guard hasHumanIdentifier else {
            return nil
        }

        return AdminUser(
            id: id,
            uidField: uidField,
            fullName: cleanDisplayName.isEmpty ? "-" : cleanDisplayName,
            email: email,
            phone: phone,
            gender: stringValue("gender", "sex"),
            birthDay: birthDay,
            birthMonth: birthMonth,
            birthYear: birthYear,
            region: singleRegion,
            branch: resolvedBranch,
            branches: branchesArray,
            group: resolvedGroup,
            groups: groupsArray,
            currentBeltId: currentBeltId,
            role: resolvedRole,
            isCoachFlag: isCoachFlag,
            createdAtMillis: millisValue("createdAtMillis", "createdAt"),
            appOpenCount: intValue("appOpenCount") ?? 0,
            lastSeenAtMillis: millisValue("lastSeenAtMillis", "lastSeenAt")
        )
    }

    static func merged(existing: AdminUser, incoming: AdminUser) -> AdminUser {
        AdminUser(
            id: existing.id,
            uidField: betterText(existing.uidField, incoming.uidField),
            fullName: betterText(existing.fullName, incoming.fullName),
            email: betterText(existing.email, incoming.email),
            phone: betterText(existing.phone, incoming.phone),
            gender: betterText(existing.gender, incoming.gender),
            birthDay: existing.birthDay ?? incoming.birthDay,
            birthMonth: existing.birthMonth ?? incoming.birthMonth,
            birthYear: existing.birthYear ?? incoming.birthYear,
            region: betterText(existing.region, incoming.region),
            branch: betterText(existing.branch, incoming.branch),
            branches: betterList(existing.branches, incoming.branches),
            group: betterText(existing.group, incoming.group),
            groups: betterList(existing.groups, incoming.groups),
            currentBeltId: betterText(existing.currentBeltId, incoming.currentBeltId),
            role: betterRole(existing.role, incoming.role),
            isCoachFlag: existing.isCoachFlag || incoming.isCoachFlag,
            createdAtMillis: newerMillis(existing.createdAtMillis, incoming.createdAtMillis),
            appOpenCount: max(existing.appOpenCount, incoming.appOpenCount),
            lastSeenAtMillis: newerMillis(existing.lastSeenAtMillis, incoming.lastSeenAtMillis)
        )
    }

    func branchGroupLine(isEnglish: Bool) -> String {
        let branchText = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        let groupText = group.trimmingCharacters(in: .whitespacesAndNewlines)

        if branchText.isEmpty && groupText.isEmpty {
            return isEnglish ? "No branch or group" : "ללא סניף או קבוצה"
        }

        if branchText.isEmpty {
            return isEnglish ? "Group: \(groupText)" : "קבוצה: \(groupText)"
        }

        if groupText.isEmpty {
            return isEnglish ? "Branch: \(branchText)" : "סניף: \(branchText)"
        }

        return isEnglish
            ? "Branch: \(branchText) • Group: \(groupText)"
            : "\(branchText) • \(groupText)"
    }

    var uniqueMergeKey: String {
        let emailKey = email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if !emailKey.isEmpty {
            return "email:\(emailKey)"
        }

        let phoneKey = phone
            .filter { $0.isNumber }

        if !phoneKey.isEmpty {
            return "phone:\(phoneKey)"
        }

        let nameKey = AdminUser.normalizedHumanNameKey(fullName)

        if !nameKey.isEmpty {
            return "name:\(nameKey)"
        }

        let uidKey = uidField
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return uidKey.isEmpty ? "" : "uid:\(uidKey)"
    }

    static func isAdminRole(_ role: String) -> Bool {
        let clean = role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return clean == "admin" ||
            clean == "administrator" ||
            clean == "manager" ||
            clean.contains("admin") ||
            clean.contains("administrator") ||
            clean.contains("manager") ||
            clean.contains("מנהל") ||
            clean.contains("אדמין")
    }

    static func isCoachRole(_ role: String) -> Bool {
        let clean = role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return clean == "coach" ||
            clean.contains("coach") ||
            clean.contains("trainer") ||
            clean.contains("instructor") ||
            clean.contains("מאמן") ||
            clean.contains("מדריך")
    }

    static func isTraineeRole(_ role: String) -> Bool {
        let clean = role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if isAdminRole(clean) || isCoachRole(clean) {
            return false
        }

        return clean.isEmpty ||
            clean == "trainee" ||
            clean.contains("trainee") ||
            clean.contains("student") ||
            clean.contains("מתאמן") ||
            clean.contains("חניך")
    }

    var hasRealAdminListContent: Bool {
        let cleanName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPhoneDigits = phone.filter { $0.isNumber }

        if cleanName.isEmpty || cleanName == "-" {
            return !cleanEmail.isEmpty || !cleanPhoneDigits.isEmpty
        }

        if cleanName.lowercased().hasPrefix("unknown user") &&
            cleanEmail.isEmpty &&
            cleanPhoneDigits.isEmpty {
            return false
        }

        if AdminUser.normalizedHumanNameKey(cleanName).isEmpty &&
            cleanEmail.isEmpty &&
            cleanPhoneDigits.isEmpty {
            return false
        }

        return true
    }

    private static func betterText(_ first: String, _ second: String) -> String {
        let cleanFirst = first.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSecond = second.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanFirst.isEmpty || cleanFirst == "-" {
            return cleanSecond
        }

        if cleanSecond.isEmpty || cleanSecond == "-" {
            return cleanFirst
        }

        let firstLooksLikeUid = normalizedHumanNameKey(cleanFirst).isEmpty
        let secondLooksLikeUid = normalizedHumanNameKey(cleanSecond).isEmpty

        if firstLooksLikeUid && !secondLooksLikeUid {
            return cleanSecond
        }

        if secondLooksLikeUid && !firstLooksLikeUid {
            return cleanFirst
        }

        return cleanSecond.count > cleanFirst.count ? cleanSecond : cleanFirst
    }

    private static func betterList(_ first: [String], _ second: [String]) -> [String] {
        var result: [String] = []

        for item in first + second {
            let clean = item.trimmingCharacters(in: .whitespacesAndNewlines)

            if !clean.isEmpty &&
                !result.contains(where: { $0.caseInsensitiveCompare(clean) == .orderedSame }) {
                result.append(clean)
            }
        }

        return result
    }

    private static func newerMillis(_ first: Int64?, _ second: Int64?) -> Int64? {
        guard let first else {
            return second
        }

        guard let second else {
            return first
        }

        return max(first, second)
    }

    private static func betterRole(_ first: String, _ second: String) -> String {
        let cleanFirst = first.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanSecond = second.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if isAdminRole(cleanFirst) || isAdminRole(cleanSecond) {
            return "admin"
        }

        if isCoachRole(cleanFirst) || isCoachRole(cleanSecond) {
            return "coach"
        }

        if isTraineeRole(cleanFirst) || isTraineeRole(cleanSecond) {
            return "trainee"
        }

        return cleanSecond.isEmpty ? cleanFirst : cleanSecond
    }

    private static func normalizedHumanNameKey(_ raw: String) -> String {
        let clean = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !clean.isEmpty && clean != "-" else {
            return ""
        }

        if clean.hasPrefix("unknown user") {
            return ""
        }

        if clean.contains("@") {
            return ""
        }

        let lettersOnly = clean.filter { $0.isLetter }

        guard lettersOnly.count >= 2 else {
            return ""
        }

        let uidLikePattern = #"^[a-z0-9_-]{20,}$"#

        if clean.range(of: uidLikePattern, options: .regularExpression) != nil {
            return ""
        }

        return clean
            .replacingOccurrences(of: #"[\s\-_.]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Array where Element == Int {

    var averageValue: Double? {
        guard !isEmpty else {
            return nil
        }

        let total = reduce(0, +)
        return Double(total) / Double(count)
    }
}

enum AdminGenderFilter {
    case all
    case male
    case female
}

struct BeltDistributionItem: Identifiable {
    let id: String
    let label: String
    let count: Int
    let color: Color
}

struct AssistantFeedbackQuestion: Identifiable {

    let id: String
    let question: String
    let answer: String
    let createdAtMillis: Int64?
    let userName: String
    let userUid: String

    static func from(id: String, map: [String: Any]) -> AssistantFeedbackQuestion? {

        func stringValue(_ keys: String...) -> String {
            for key in keys {
                if let value = map[key] as? String {
                    let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !clean.isEmpty {
                        return clean
                    }
                }

                if let value = map[key], !(value is NSNull) {
                    let clean = "\(value)".trimmingCharacters(in: .whitespacesAndNewlines)
                    if !clean.isEmpty && clean.lowercased() != "null" {
                        return clean
                    }
                }
            }

            return ""
        }

        func millisValue(_ keys: String...) -> Int64? {
            for key in keys {
                let value = map[key]

                let rawMillis: Int64?

                if let timestamp = value as? Timestamp {
                    rawMillis = Int64(timestamp.dateValue().timeIntervalSince1970 * 1000)
                } else if let value = value as? Int64 {
                    rawMillis = value
                } else if let value = value as? Int {
                    rawMillis = Int64(value)
                } else if let value = value as? Double {
                    rawMillis = Int64(value)
                } else if let value = value as? String {
                    rawMillis = Int64(value.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    rawMillis = nil
                }

                guard let rawMillis else {
                    continue
                }

                if rawMillis >= 1_000_000_000 && rawMillis <= 9_999_999_999 {
                    return rawMillis * 1000
                }

                return rawMillis
            }

            return nil
        }

        let question = stringValue("question", "prompt", "text")

        guard !question.isEmpty else {
            return nil
        }

        return AssistantFeedbackQuestion(
            id: id,
            question: question,
            answer: stringValue("answer", "response"),
            createdAtMillis: millisValue("createdAt", "createdAtMillis", "ts"),
            userName: stringValue("userName", "displayName", "name"),
            userUid: stringValue("userUid", "uid", "userId")
        )
    }

    func metaLine(isEnglish: Bool) -> String {
        var parts: [String] = []

        let cleanUserName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUserUid = userUid.trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleanUserName.isEmpty {
            parts.append(cleanUserName)
        }

        if !cleanUserUid.isEmpty {
            parts.append(isEnglish ? "UID: \(cleanUserUid)" : "UID: \(cleanUserUid)")
        }

        return parts.joined(separator: " • ")
    }
}

private extension Array where Element == String {

    func uniqueCaseInsensitiveSorted() -> [String] {
        var result: [String] = []

        for item in self {
            let clean = item.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !clean.isEmpty else {
                continue
            }

            if !result.contains(where: { $0.caseInsensitiveCompare(clean) == .orderedSame }) {
                result.append(clean)
            }
        }

        return result.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }
}

