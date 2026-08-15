import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

struct CoachNationalStatisticsView: View {
    let isEnglish: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var model = NationalStatisticsViewModel()

    private var rtl: Bool { !isEnglish }
    private var align: Alignment { isEnglish ? .leading : .trailing }
    private var textAlign: TextAlignment { isEnglish ? .leading : .trailing }
    private var panel: Color { colorScheme == .dark ? Color(red: 0.09, green: 0.14, blue: 0.23) : .white }
    private var primary: Color { colorScheme == .dark ? .white : Color(red: 0.08, green: 0.12, blue: 0.20) }
    private var secondary: Color { colorScheme == .dark ? .white.opacity(0.68) : .black.opacity(0.55) }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: colorScheme == .dark
                    ? [Color(red: 0.02, green: 0.05, blue: 0.12), Color(red: 0.04, green: 0.17, blue: 0.28)]
                    : [Color(red: 0.97, green: 0.99, blue: 1), Color(red: 0.87, green: 0.94, blue: 1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                content
            }
            .navigationTitle(tr("סטטיסטיקה ארצית", "National statistics"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: rtl ? .topBarTrailing : .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: rtl ? "chevron.right" : "chevron.left")
                            .font(.headline.weight(.bold))
                    }
                    .accessibilityLabel(tr("חזרה", "Back"))
                }
            }
        }
        .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
        .task { await model.load() }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            VStack(spacing: 14) {
                ProgressView().controlSize(.large).tint(.cyan)
                Text(tr("טוען נתונים ארציים…", "Loading national data…"))
                    .font(.headline)
                    .foregroundStyle(primary)
            }
        } else if let error = model.errorMessage {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 42)).foregroundStyle(.orange)
                Text(error).multilineTextAlignment(.center).foregroundStyle(primary)
                Button(tr("נסה שוב", "Try again")) { Task { await model.load() } }
                    .buttonStyle(.borderedProminent)
            }
            .padding(28)
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: rtl ? .trailing : .leading, spacing: 14) {
                    heroCard
                    filtersCard

                    if model.filteredRecords.isEmpty {
                        emptyCard
                    } else {
                        summaryGrid
                        distributionCard(
                            title: tr("התפלגות גילאים", "Age distribution"),
                            icon: "person.2.fill",
                            rows: model.ageRows(isEnglish: isEnglish)
                        )
                        distributionCard(
                            title: tr("התפלגות מגדר", "Gender distribution"),
                            icon: "figure.stand.dress.line.vertical.figure",
                            rows: model.genderRows(isEnglish: isEnglish)
                        )
                        distributionCard(
                            title: tr("התפלגות חגורות", "Belt distribution"),
                            icon: "medal.fill",
                            rows: model.beltRows
                        )
                        branchesCard
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .refreshable { await model.load() }
        }
    }

    private var heroCard: some View {
        VStack(alignment: rtl ? .trailing : .leading, spacing: 12) {
            HStack(spacing: 12) {
                if !rtl { heroIcon }
                VStack(alignment: rtl ? .trailing : .leading, spacing: 3) {
                    Text(tr("תמונה ארצית", "National overview"))
                        .font(.title2.weight(.heavy))
                    Text(tr("נתוני אמת מכל הסניפים", "Live data from all branches"))
                        .font(.subheadline.weight(.semibold)).opacity(0.82)
                }
                .frame(maxWidth: .infinity, alignment: align)
                if rtl { heroIcon }
            }

            HStack(spacing: 10) {
                heroMetric(value: "\(model.filteredRecords.count)", label: tr("מתאמנים", "Trainees"))
                heroMetric(value: "\(model.branchCounts.count)", label: tr("סניפים", "Branches"))
                heroMetric(value: "\(model.groupCount)", label: tr("קבוצות", "Groups"))
            }
        }
        .foregroundStyle(.white)
        .padding(18)
        .background(
            LinearGradient(colors: [Color.blue, Color.indigo, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .shadow(color: .blue.opacity(0.22), radius: 12, y: 6)
    }

    private var heroIcon: some View {
        Image(systemName: "chart.bar.xaxis")
            .font(.system(size: 27, weight: .black))
            .frame(width: 52, height: 52)
            .background(.white.opacity(0.18), in: Circle())
    }

    private func heroMetric(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.black))
            Text(label).font(.caption.weight(.bold)).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
    }

    private var filtersCard: some View {
        VStack(alignment: rtl ? .trailing : .leading, spacing: 12) {
            HStack {
                Text(tr("סינון וחיפוש", "Search and filters"))
                    .font(.headline.weight(.heavy)).foregroundStyle(primary)
                Spacer()
                if model.hasFilters {
                    Button(tr("איפוס", "Reset")) { model.resetFilters() }
                        .font(.subheadline.weight(.bold))
                }
            }

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(secondary)

                TextField(
                    tr(
                        "חיפוש מתאמן, סניף, קבוצה או חגורה",
                        "Search trainee, branch, group or belt"
                    ),
                    text: $model.searchQuery
                )
                .multilineTextAlignment(
                    rtl ? .trailing : .leading
                )
                .textInputAutocapitalization(.never)

                if !model.searchQuery.isEmpty {
                    Button {
                        model.searchQuery = ""
                    } label: {
                        Image(
                            systemName: "xmark.circle.fill"
                        )
                        .foregroundStyle(secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        tr(
                            "נקה חיפוש",
                            "Clear search"
                        )
                    )
                }
            }
            .padding(12)
            .background(colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))

            HStack(spacing: 8) {
                filterMenu(
                    title: model.selectedBranch ?? tr("כל הסניפים", "All branches"),
                    values: model.availableBranches,
                    selected: model.selectedBranch,
                    allTitle: tr("כל הסניפים", "All branches")
                ) { model.selectedBranch = $0 }

                filterMenu(
                    title: model.selectedGroup ?? tr("כל הקבוצות", "All groups"),
                    values: model.availableGroups,
                    selected: model.selectedGroup,
                    allTitle: tr("כל הקבוצות", "All groups")
                ) { model.selectedGroup = $0 }
            }

            HStack(spacing: 8) {
                filterMenu(
                    title:
                        model.selectedBelt ??
                        tr(
                            "כל החגורות",
                            "All belts"
                        ),
                    values: model.availableBelts,
                    selected: model.selectedBelt,
                    allTitle: tr(
                        "כל החגורות",
                        "All belts"
                    )
                ) {
                    model.selectedBelt = $0
                }

                genderFilterMenu
            }

            HStack(spacing: 8) {
                ageGroupFilterMenu

                Toggle(
                    tr(
                        "פעילים בלבד",
                        "Active only"
                    ),
                    isOn: $model.activeOnly
                )
                .font(.caption.weight(.bold))
                .toggleStyle(.switch)
                .tint(.cyan)
                .padding(.horizontal, 10)
                .frame(
                    maxWidth: .infinity,
                    minHeight: 42
                )
                .background(
                    Color.cyan.opacity(0.10),
                    in: RoundedRectangle(
                        cornerRadius: 13
                    )
                )
            }
        }
        .padding(15)
        .background(panel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.cyan.opacity(0.18)))
    }

    private func filterMenu(
        title: String,
        values: [String],
        selected: String?,
        allTitle: String,
        onSelect: @escaping (String?) -> Void
    ) -> some View {
        Menu {
            Button(allTitle) { onSelect(nil) }
            ForEach(values, id: \.self) { value in
                Button {
                    onSelect(value)
                } label: {
                    if selected == value { Label(value, systemImage: "checkmark") }
                    else { Text(value) }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(title).lineLimit(1)
                Spacer(minLength: 2)
                Image(systemName: "chevron.down").font(.caption.weight(.bold))
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(primary)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(
                Color.blue.opacity(0.09),
                in: RoundedRectangle(cornerRadius: 13)
            )
        }
    }

    private var genderFilterMenu: some View {
        Menu {
            Button {
                model.selectedGender = nil
            } label: {
                if model.selectedGender == nil {
                    Label(
                        tr(
                            "כל המגדרים",
                            "All genders"
                        ),
                        systemImage: "checkmark"
                    )
                } else {
                    Text(
                        tr(
                            "כל המגדרים",
                            "All genders"
                        )
                    )
                }
            }

            ForEach(
                NationalGender.allCases,
                id: \.self
            ) { gender in
                Button {
                    model.selectedGender = gender
                } label: {
                    if model.selectedGender == gender {
                        Label(
                            gender.title(
                                isEnglish: isEnglish
                            ),
                            systemImage: "checkmark"
                        )
                    } else {
                        Text(
                            gender.title(
                                isEnglish: isEnglish
                            )
                        )
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(
                    model.selectedGender?.title(
                        isEnglish: isEnglish
                    ) ??
                    tr(
                        "כל המגדרים",
                        "All genders"
                    )
                )
                .lineLimit(1)

                Spacer(minLength: 2)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(primary)
            .padding(.horizontal, 10)
            .frame(
                maxWidth: .infinity,
                minHeight: 42
            )
            .background(
                Color.blue.opacity(0.09),
                in: RoundedRectangle(
                    cornerRadius: 13
                )
            )
        }
    }

    private var ageGroupFilterMenu: some View {
        Menu {
            Button {
                model.selectedAgeGroup = nil
            } label: {
                if model.selectedAgeGroup == nil {
                    Label(
                        tr(
                            "כל הגילאים",
                            "All ages"
                        ),
                        systemImage: "checkmark"
                    )
                } else {
                    Text(
                        tr(
                            "כל הגילאים",
                            "All ages"
                        )
                    )
                }
            }

            ForEach(
                NationalAgeGroup.allCases,
                id: \.self
            ) { ageGroup in
                Button {
                    model.selectedAgeGroup = ageGroup
                } label: {
                    if model.selectedAgeGroup == ageGroup {
                        Label(
                            ageGroup.title(
                                isEnglish: isEnglish
                            ),
                            systemImage: "checkmark"
                        )
                    } else {
                        Text(
                            ageGroup.title(
                                isEnglish: isEnglish
                            )
                        )
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(
                    model.selectedAgeGroup?.title(
                        isEnglish: isEnglish
                    ) ??
                    tr(
                        "כל הגילאים",
                        "All ages"
                    )
                )
                .lineLimit(1)

                Spacer(minLength: 2)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(primary)
            .padding(.horizontal, 10)
            .frame(
                maxWidth: .infinity,
                minHeight: 42
            )
            .background(
                Color.blue.opacity(0.09),
                in: RoundedRectangle(
                    cornerRadius: 13
                )
            )
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            summaryTile(tr("גיל ממוצע", "Average age"), model.averageAge.map(String.init) ?? "—", "calendar")
            summaryTile(tr("נוכחות ממוצעת", "Average attendance"), model.averageAttendance.map { "\($0)%" } ?? "—", "checkmark.circle.fill")
            summaryTile(tr("סוגי חגורות", "Belt types"), "\(model.beltCounts.count)", "medal.fill")
            summaryTile(tr("וותק ממוצע", "Average seniority"), model.averageSeniority.map { String(format: "%.1f", $0) } ?? "—", "clock.fill")
        }
    }

    private func summaryTile(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: rtl ? .trailing : .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(.cyan).font(.title3.weight(.bold))
            Text(value).font(.title.weight(.black)).foregroundStyle(primary)
            Text(title).font(.caption.weight(.bold)).foregroundStyle(secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 105, alignment: align)
        .padding(14)
        .background(panel, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(colorScheme == .dark ? 0.10 : 0)))
    }

    private func distributionCard(
        title: String,
        icon: String,
        rows: [(String, Int)]
    ) -> some View {
        let total =
            max(
                rows.reduce(0) {
                    $0 + $1.1
                },
                1
            )

        return VStack(
            alignment:
                rtl
                ? .trailing
                : .leading,
            spacing: 14
        ) {
            HStack(spacing: 8) {
                if !rtl {
                    Image(systemName: icon)
                        .foregroundStyle(.cyan)
                }

                Text(title)
                    .font(
                        .headline.weight(.heavy)
                    )
                    .foregroundStyle(primary)
                    .frame(
                        maxWidth: .infinity,
                        alignment: align
                    )

                if rtl {
                    Image(systemName: icon)
                        .foregroundStyle(.cyan)
                }
            }
            .environment(
                \.layoutDirection,
                .leftToRight
            )

            ForEach(
                Array(rows.enumerated()),
                id: \.offset
            ) { _, row in
                let percentage =
                    Int(
                        (
                            Double(row.1) /
                            Double(total) *
                            100
                        )
                        .rounded()
                    )

                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Text(row.0)
                            .font(
                                .subheadline.weight(
                                    .bold
                                )
                            )
                            .foregroundStyle(primary)
                            .frame(
                                maxWidth: .infinity,
                                alignment: align
                            )

                        Text(
                            "\(row.1) • \(percentage)%"
                        )
                        .font(
                            .subheadline.weight(
                                .black
                            )
                        )
                        .foregroundStyle(.cyan)
                        .fixedSize()
                    }

                    GeometryReader { proxy in
                        ZStack(
                            alignment:
                                rtl
                                ? .trailing
                                : .leading
                        ) {
                            Capsule()
                                .fill(
                                    Color.secondary
                                        .opacity(0.14)
                                )

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(
                                                red: 0.31,
                                                green: 0.27,
                                                blue: 0.90
                                            ),
                                            Color(
                                                red: 0.02,
                                                green: 0.65,
                                                blue: 0.91
                                            )
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width:
                                        proxy.size.width *
                                        CGFloat(row.1) /
                                        CGFloat(total)
                                )
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .background(
            panel,
            in: RoundedRectangle(
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
                colorScheme == .dark
                ? Color.white.opacity(0.10)
                : Color.black.opacity(0.05),
                lineWidth: 1
            )
        )
    }

    private var branchesCard: some View {
        let maximumTrainees =
            max(
                model.branchStatistics
                    .map(\.count)
                    .max() ?? 1,
                1
            )

        return VStack(
            alignment:
                rtl
                ? .trailing
                : .leading,
            spacing: 14
        ) {
            HStack(spacing: 8) {
                if !rtl {
                    Image(
                        systemName:
                            "building.2.fill"
                    )
                    .foregroundStyle(.indigo)
                }

                Text(
                    tr(
                        "השוואה בין סניפים",
                        "Branch comparison"
                    )
                )
                .font(
                    .title3.weight(.black)
                )
                .foregroundStyle(primary)
                .frame(
                    maxWidth: .infinity,
                    alignment: align
                )

                if rtl {
                    Image(
                        systemName:
                            "building.2.fill"
                    )
                    .foregroundStyle(.indigo)
                }
            }
            .environment(
                \.layoutDirection,
                .leftToRight
            )

            ForEach(
                model.branchStatistics,
                id: \.name
            ) { branch in
                VStack(
                    alignment:
                        rtl
                        ? .trailing
                        : .leading,
                    spacing: 11
                ) {
                    HStack(spacing: 10) {
                        Image(
                            systemName:
                                "mappin.circle.fill"
                        )
                        .font(
                            .system(
                                size: 23,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(.indigo)
                        .frame(
                            width: 42,
                            height: 42
                        )
                        .background(
                            Color.indigo.opacity(0.11),
                            in: Circle()
                        )

                        VStack(
                            alignment:
                                rtl
                                ? .trailing
                                : .leading,
                            spacing: 2
                        ) {
                            Text(branch.name)
                                .font(
                                    .headline.weight(
                                        .black
                                    )
                                )
                                .foregroundStyle(
                                    primary
                                )
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: align
                                )

                            Text(
                                tr(
                                    "\(branch.count) מתאמנים",
                                    "\(branch.count) trainees"
                                )
                            )
                            .font(
                                .caption.weight(
                                    .semibold
                                )
                            )
                            .foregroundStyle(
                                secondary
                            )
                            .frame(
                                maxWidth: .infinity,
                                alignment: align
                            )
                        }

                        Text("\(branch.count)")
                            .font(
                                .title2.weight(
                                    .black
                                )
                            )
                            .foregroundStyle(
                                .indigo
                            )
                    }

                    GeometryReader { proxy in
                        ZStack(
                            alignment:
                                rtl
                                ? .trailing
                                : .leading
                        ) {
                            Capsule()
                                .fill(
                                    Color.indigo
                                        .opacity(0.12)
                                )

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .indigo,
                                            .blue
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width:
                                        proxy.size.width *
                                        CGFloat(
                                            branch.count
                                        ) /
                                        CGFloat(
                                            maximumTrainees
                                        )
                                )
                        }
                    }
                    .frame(height: 8)

                    HStack(spacing: 8) {
                        branchMiniStat(
                            title: tr(
                                "גיל ממוצע",
                                "Avg age"
                            ),
                            value:
                                branch.averageAge
                                    .map(String.init) ??
                                "—"
                        )

                        branchMiniStat(
                            title: tr(
                                "נוכחות",
                                "Attendance"
                            ),
                            value:
                                branch
                                    .averageAttendance
                                    .map {
                                        "\($0)%"
                                    } ??
                                "—"
                        )

                        branchMiniStat(
                            title: tr(
                                "חגורות",
                                "Belts"
                            ),
                            value:
                                "\(branch.beltTypes)"
                        )
                    }
                }
                .padding(14)
                .background(
                    Color.indigo.opacity(
                        colorScheme == .dark
                        ? 0.13
                        : 0.06
                    ),
                    in: RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                    .stroke(
                        Color.indigo.opacity(
                            colorScheme == .dark
                            ? 0.24
                            : 0.12
                        ),
                        lineWidth: 1
                    )
                )
            }
        }
        .padding(16)
        .background(
            panel,
            in: RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
    }

    private func branchMiniStat(
        title: String,
        value: String
    ) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(
                    .headline.weight(.black)
                )
                .foregroundStyle(primary)

            Text(title)
                .font(
                    .caption2.weight(.bold)
                )
                .foregroundStyle(secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: 54
        )
        .background(
            colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.white.opacity(0.82),
            in: RoundedRectangle(
                cornerRadius: 13,
                style: .continuous
            )
        )
    }

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.doc.horizontal").font(.system(size: 38)).foregroundStyle(.cyan)
            Text(tr("אין נתונים התואמים למסננים", "No data matches the filters"))
                .font(.headline.weight(.bold)).foregroundStyle(primary)
        }
        .frame(maxWidth: .infinity).padding(30)
        .background(panel, in: RoundedRectangle(cornerRadius: 22))
    }

    private func tr(_ he: String, _ en: String) -> String { isEnglish ? en : he }
}

@MainActor
private final class NationalStatisticsViewModel: ObservableObject {
    @Published var records: [NationalTraineeRecord] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchQuery = ""
    @Published var selectedBranch: String?
    @Published var selectedGroup: String?
    @Published var selectedBelt: String?
    @Published var selectedGender: NationalGender?
    @Published var selectedAgeGroup: NationalAgeGroup?
    @Published var activeOnly = true

    var filteredRecords: [NationalTraineeRecord] {
        let query =
            normalized(searchQuery)
                .lowercased()

        return records.filter { record in
            if activeOnly && !record.isActive {
                return false
            }

            if let selectedBranch,
               !record.branches.contains(
                    selectedBranch
               ) {
                return false
            }

            if let selectedGroup,
               !record.groups.contains(
                    selectedGroup
               ) {
                return false
            }

            if let selectedBelt,
               record.belt != selectedBelt {
                return false
            }

            if let selectedGender,
               record.gender != selectedGender {
                return false
            }

            if let selectedAgeGroup,
               !selectedAgeGroup.contains(
                    record.age
               ) {
                return false
            }

            if !query.isEmpty {
                let haystack = ([record.fullName, record.belt] + record.branches + record.groups)
                    .map { normalized($0).lowercased() }
                if !haystack.contains(where: { $0.contains(query) }) { return false }
            }
            return true
        }
        .sorted { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending }
    }

    var availableBranches: [String] { Array(Set(records.flatMap(\.branches))).sorted() }
    var availableGroups: [String] { Array(Set(records.flatMap(\.groups))).sorted() }
    var availableBelts: [String] { Array(Set(records.map(\.belt))).sorted(by: { beltOrder($0) < beltOrder($1) }) }
    var branchCounts: [String: Int] { countValues(filteredRecords.flatMap(\.branches)) }
    var groupCount: Int { Set(filteredRecords.flatMap(\.groups)).count }
    var beltCounts: [String: Int] { countValues(filteredRecords.map(\.belt)) }
    var averageAge: Int? { average(filteredRecords.compactMap(\.age)) }
    var averageAttendance: Int? { average(filteredRecords.compactMap(\.attendancePercent)) }
    var averageSeniority: Double? {
        let values = filteredRecords.compactMap(\.seniorityYears)
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
    var hasFilters: Bool {
        !searchQuery
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty ||
        selectedBranch != nil ||
        selectedGroup != nil ||
        selectedBelt != nil ||
        selectedGender != nil ||
        selectedAgeGroup != nil ||
        !activeOnly
    }

    var beltRows: [(String, Int)] { beltCounts.sorted { beltOrder($0.key) < beltOrder($1.key) } }

    var branchStatistics: [NationalBranchRow] {
        branchCounts.map { name, count in
            let items =
                filteredRecords.filter {
                    $0.branches.contains(name)
                }

            let beltTypes =
                Set(
                    items.map(\.belt)
                        .filter {
                            !$0.trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )
                            .isEmpty
                        }
                )
                .count

            return NationalBranchRow(
                name: name,
                count: count,
                averageAge:
                    average(
                        items.compactMap(\.age)
                    ),
                averageAttendance:
                    average(
                        items.compactMap(
                            \.attendancePercent
                        )
                    ),
                beltTypes: beltTypes
            )
        }
        .sorted {
            $0.count == $1.count
            ? $0.name < $1.name
            : $0.count > $1.count
        }
    }

    func ageRows(isEnglish: Bool) -> [(String, Int)] {
        let groups: [(String, ClosedRange<Int>)] = [
            (isEnglish ? "Children 0–11" : "ילדים 0–11", 0...11),
            (isEnglish ? "Teens 12–17" : "נוער 12–17", 12...17),
            (isEnglish ? "Young adults 18–25" : "צעירים 18–25", 18...25),
            (isEnglish ? "Adults 26–40" : "בוגרים 26–40", 26...40),
            (isEnglish ? "Adults 41–59" : "בוגרים 41–59", 41...59),
            (isEnglish ? "Seniors 60+" : "ותיקים 60+", 60...120)
        ]
        var result = groups.map { label, range in (label, filteredRecords.filter { $0.age.map(range.contains) ?? false }.count) }
        let unknown = filteredRecords.filter { $0.age == nil }.count
        if unknown > 0 { result.append((isEnglish ? "Unknown" : "לא ידוע", unknown)) }
        return result.filter { $0.1 > 0 }
    }

    func genderRows(isEnglish: Bool) -> [(String, Int)] {
        let counts = Dictionary(grouping: filteredRecords, by: \.gender).mapValues(\.count)
        return NationalGender.allCases.compactMap { gender in
            let count = counts[gender, default: 0]
            guard count > 0 else { return nil }
            return (gender.title(isEnglish: isEnglish), count)
        }
    }

    func resetFilters() {
        searchQuery = ""
        selectedBranch = nil
        selectedGroup = nil
        selectedBelt = nil
        selectedGender = nil
        selectedAgeGroup = nil
        activeOnly = true
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        guard Auth.auth().currentUser != nil else {
            errorMessage = "יש להתחבר מחדש כדי לצפות בסטטיסטיקה הארצית."
            return
        }
        do {
            let db = Firestore.firestore()
            var byId: [String: NationalTraineeRecord] = [:]
            var successfulQueries = 0
            var lastError: Error?
            for role in ["trainee", "student", "מתאמן"] {
                do {
                    let snapshot = try await db.collection("users").whereField("role", isEqualTo: role).getDocuments()
                    successfulQueries += 1
                    for document in snapshot.documents {
                        if let record = makeRecord(id: document.documentID, data: document.data()) { byId[record.id] = merge(byId[record.id], record) }
                    }
                } catch { lastError = error }
            }
            if successfulQueries == 0 { throw lastError ?? NationalStatsError.loadFailed }
            records = Array(byId.values)
        } catch {
            errorMessage = "לא ניתן לטעון כרגע את נתוני כל הסניפים. ודא שלחשבון יש הרשאה לצפייה ארצית."
        }
    }

    private func makeRecord(id: String, data: [String: Any]) -> NationalTraineeRecord? {
        let branches = stringSet(data, arrays: ["branches", "branchNames"], singles: ["activeBranch", "active_branch", "branch", "coachBranch"], csv: ["branchesCsv", "branches_csv"])
        guard !branches.isEmpty else { return nil }
        let groups = stringSet(data, arrays: ["groups", "groupNames"], singles: ["activeGroup", "active_group", "primaryGroup", "groupKey", "group_key", "age_group", "group"], csv: ["groupsCsv", "groups_csv"])
        let name = firstString(data, ["fullName", "name", "displayName", "full_name"])
        let age = readAge(data)
        return NationalTraineeRecord(
            id: id, fullName: name, branches: Array(branches), groups: Array(groups), age: age,
            gender: readGender(data), belt: readBelt(data), seniorityYears: readSeniority(data),
            attendancePercent: firstNumber(data, ["attendancePercent", "attendancePct", "attendance_percentage", "attendanceRate", "attendance_rate"]).map { min(max(Int($0), 0), 100) },
            isActive: readActive(data)
        )
    }

    private func merge(_ old: NationalTraineeRecord?, _ new: NationalTraineeRecord) -> NationalTraineeRecord {
        guard let old else { return new }
        let attendance = [old.attendancePercent, new.attendancePercent].compactMap { $0 }
        return NationalTraineeRecord(
            id: new.id,
            fullName: old.fullName.isEmpty ? new.fullName : old.fullName,
            branches: Array(Set(old.branches + new.branches)), groups: Array(Set(old.groups + new.groups)),
            age: old.age ?? new.age, gender: old.gender == .unknown ? new.gender : old.gender,
            belt: old.belt == "ללא דרגה" ? new.belt : old.belt,
            seniorityYears: max(old.seniorityYears ?? 0, new.seniorityYears ?? 0),
            attendancePercent: attendance.isEmpty ? nil : Int((Double(attendance.reduce(0, +)) / Double(attendance.count)).rounded()),
            isActive: old.isActive || new.isActive
        )
    }

    private func firstString(_ data: [String: Any], _ keys: [String]) -> String {
        keys.compactMap { data[$0] as? String }.map(normalized).first(where: { !$0.isEmpty }) ?? ""
    }

    private func firstNumber(_ data: [String: Any], _ keys: [String]) -> Double? {
        for key in keys {
            if let number = data[key] as? NSNumber { return number.doubleValue }
            if let text = data[key] as? String, let value = Double(text.replacingOccurrences(of: ",", with: ".")) { return value }
        }
        return nil
    }

    private func stringSet(_ data: [String: Any], arrays: [String], singles: [String], csv: [String]) -> Set<String> {
        var values: [String] = []
        for key in arrays { values += (data[key] as? [String]) ?? [] }
        for key in singles + csv { if let value = data[key] as? String { values.append(value) } }
        return Set(values.flatMap(splitValues).map(normalized).filter { !$0.isEmpty })
    }

    private func splitValues(_ value: String) -> [String] {
        value.components(separatedBy: CharacterSet(charactersIn: ",;|\n"))
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "־", with: "-").replacingOccurrences(of: "–", with: "-").replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private func readAge(_ data: [String: Any]) -> Int? {
        if let value = firstNumber(data, ["age", "currentAge", "current_age"]), (1...120).contains(Int(value)) { return Int(value) }
        guard let birth = dateValue(data, ["birthDate", "birth_date", "dateOfBirth", "date_of_birth", "birthday"]) else { return nil }
        let value = Calendar.current.dateComponents([.year], from: birth, to: Date()).year
        return value.flatMap { (1...120).contains($0) ? $0 : nil }
    }

    private func readSeniority(_ data: [String: Any]) -> Double? {
        if let value = firstNumber(data, ["seniorityYears", "trainingYears", "yearsTraining", "years_training", "experienceYears", "experience_years"]), (0...100).contains(value) { return value }
        let text = firstString(data, ["seniority", "trainingSeniority", "training_seniority", "experience", "trainingExperience"])
        if let match = text.range(of: #"\d+(?:[.,]\d+)?"#, options: .regularExpression), let value = Double(text[match].replacingOccurrences(of: ",", with: ".")), (0...100).contains(value) { return value }
        guard let start = dateValue(data, ["trainingStartDate", "training_start_date", "startTrainingDate", "startedTrainingAt"]) else { return nil }
        let months = Calendar.current.dateComponents([.month], from: start, to: Date()).month ?? 0
        let years = Double(months) / 12
        return (0...100).contains(years) ? years : nil
    }

    private func dateValue(_ data: [String: Any], _ keys: [String]) -> Date? {
        for key in keys {
            if let stamp = data[key] as? Timestamp { return stamp.dateValue() }
            if let date = data[key] as? Date { return date }
            if let number = data[key] as? NSNumber {
                let raw = number.doubleValue
                return Date(timeIntervalSince1970: raw < 10_000_000_000 ? raw : raw / 1000)
            }
            if let text = data[key] as? String {
                for format in ["yyyy-MM-dd", "dd/MM/yyyy", "d/M/yyyy", "dd-MM-yyyy", "d-M-yyyy", "dd.MM.yyyy", "d.M.yyyy"] {
                    let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = format
                    if let date = formatter.date(from: text.trimmingCharacters(in: .whitespacesAndNewlines)) { return date }
                }
            }
        }
        return nil
    }

    private func readGender(_ data: [String: Any]) -> NationalGender {
        let value = firstString(data, ["gender", "sex", "genderName", "gender_name", "מין"]).lowercased().replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
        if ["male", "man", "boy", "m", "זכר", "גבר", "נער", "ילד"].contains(value) { return .male }
        if ["female", "woman", "girl", "f", "נקבה", "אישה", "נערה", "ילדה"].contains(value) { return .female }
        if ["other", "non binary", "nonbinary", "אחר", "אחרת"].contains(value) { return .other }
        return .unknown
    }

    private func readBelt(_ data: [String: Any]) -> String {
        let value = firstString(data, ["belt", "currentBelt", "current_belt", "beltName", "belt_name", "currentBeltName", "currentBeltId", "beltId", "belt_id"]).lowercased()
        if value.contains("white") || value.contains("לבנ") { return "לבנה" }
        if value.contains("yellow") || value.contains("צהוב") { return "צהובה" }
        if value.contains("orange") || value.contains("כתומ") { return "כתומה" }
        if value.contains("green") || value.contains("ירוק") { return "ירוקה" }
        if value.contains("blue") || value.contains("כחול") { return "כחולה" }
        if value.contains("brown") || value.contains("חומ") { return "חומה" }
        if value.contains("black") || value.contains("שחור") { return "שחורה" }
        return "ללא דרגה"
    }

    private func readActive(_ data: [String: Any]) -> Bool {
        for key in ["isActive", "active", "is_active"] { if let value = data[key] as? Bool { return value } }
        let status = firstString(data, ["status", "accountStatus", "account_status", "membershipStatus"]).lowercased()
        return !["inactive", "disabled", "deleted", "suspended", "לא פעיל", "מושבת"].contains(status)
    }

    private func countValues(_ values: [String]) -> [String: Int] { Dictionary(grouping: values, by: { $0 }).mapValues(\.count) }
    private func average(_ values: [Int]) -> Int? { values.isEmpty ? nil : Int((Double(values.reduce(0, +)) / Double(values.count)).rounded()) }
    private func beltOrder(_ belt: String) -> Int { ["לבנה", "צהובה", "כתומה", "ירוקה", "כחולה", "חומה", "שחורה", "ללא דרגה"].firstIndex(of: belt) ?? 99 }
}

private struct NationalTraineeRecord {
    let id: String
    let fullName: String
    let branches: [String]
    let groups: [String]
    let age: Int?
    let gender: NationalGender
    let belt: String
    let seniorityYears: Double?
    let attendancePercent: Int?
    let isActive: Bool
}

private enum NationalGender: CaseIterable {
    case male
    case female
    case other
    case unknown

    func title(isEnglish: Bool) -> String {
        switch self {
        case .male:
            return isEnglish ? "Male" : "זכר"

        case .female:
            return isEnglish ? "Female" : "נקבה"

        case .other:
            return isEnglish ? "Other" : "אחר"

        case .unknown:
            return isEnglish ? "Unknown" : "לא ידוע"
        }
    }
}

private enum NationalAgeGroup: CaseIterable {
    case children
    case teens
    case youngAdults
    case adults
    case matureAdults
    case seniors
    case unknown

    func contains(_ age: Int?) -> Bool {
        switch self {
        case .children:
            guard let age else { return false }
            return (0...11).contains(age)

        case .teens:
            guard let age else { return false }
            return (12...17).contains(age)

        case .youngAdults:
            guard let age else { return false }
            return (18...25).contains(age)

        case .adults:
            guard let age else { return false }
            return (26...40).contains(age)

        case .matureAdults:
            guard let age else { return false }
            return (41...59).contains(age)

        case .seniors:
            guard let age else { return false }
            return age >= 60

        case .unknown:
            return age == nil || age == 0
        }
    }

    func title(isEnglish: Bool) -> String {
        switch self {
        case .children:
            return isEnglish
                ? "Children 0–11"
                : "ילדים 0–11"

        case .teens:
            return isEnglish
                ? "Teens 12–17"
                : "נוער 12–17"

        case .youngAdults:
            return isEnglish
                ? "Young adults 18–25"
                : "צעירים 18–25"

        case .adults:
            return isEnglish
                ? "Adults 26–40"
                : "בוגרים 26–40"

        case .matureAdults:
            return isEnglish
                ? "Adults 41–59"
                : "בוגרים 41–59"

        case .seniors:
            return isEnglish
                ? "Seniors 60+"
                : "ותיקים 60+"

        case .unknown:
            return isEnglish
                ? "Unknown age"
                : "גיל לא ידוע"
        }
    }
}

private struct NationalBranchRow {
    let name: String
    let count: Int
    let averageAge: Int?
    let averageAttendance: Int?
    let beltTypes: Int
}

private enum NationalStatsError: Error { case loadFailed }
