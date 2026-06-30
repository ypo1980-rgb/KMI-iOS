import SwiftUI

struct AttendanceStatsView: View {

    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"
    @AppStorage("initial_language_selected_code") private var initialLanguageSelectedCode: String = "he"
    @AppStorage("kmi.language.code") private var kmiLanguageCode: String = "he"

    let ownerUid: String
    let branchName: String
    let groupKey: String
    let memberId: String
    let memberName: String

    @State private var stats = AttendanceMemberStats(
        monthlyPercent: 0,
        yearlyPercent: 0,
        streakDays: 0,
        bestDays: [],
        lastSessions: []
    )

    @State private var isLoadingStats: Bool = false
    @State private var hasRealAttendanceData: Bool = false

    private let repository: AttendanceRepository

    private var isEnglish: Bool {
        let values = [
            kmiAppLanguageCode,
            appLanguageRaw,
            initialLanguageCode,
            initialLanguageSelectedCode,
            kmiLanguageCode
        ]
        .map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        }

        if values.contains("en") || values.contains("english") {
            return true
        }

        if values.contains("he") || values.contains("hebrew") || values.contains("עברית") {
            return false
        }

        return Locale.preferredLanguages.first?
            .lowercased()
            .hasPrefix("en") == true
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private var screenAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var screenTextAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var screenHorizontalAlignment: HorizontalAlignment {
        isEnglish ? .leading : .trailing
    }

    init(
        ownerUid: String,
        branchName: String,
        groupKey: String,
        memberId: String,
        memberName: String,
        repository: AttendanceRepository = .shared
    ) {
        self.ownerUid = ownerUid
        self.branchName = branchName
        self.groupKey = groupKey
        self.memberId = memberId
        self.memberName = memberName
        self.repository = repository
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.008, green: 0.024, blue: 0.090), // #020617
                    Color(red: 0.067, green: 0.094, blue: 0.153), // #111827
                    Color(red: 0.114, green: 0.306, blue: 0.847), // #1D4ED8
                    Color(red: 0.133, green: 0.827, blue: 0.933)  // #22D3EE
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    heroStatsCard
                    percentCardsRow

                    if !hasRealAttendanceData {
                        emptyMemberAttendanceStatsCard
                    }

                    streakCard
                    bestDaysCard
                    lastSessionsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 120)
            }
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
        .navigationTitle(tr("סטטיסטיקת נוכחות", "Attendance Statistics"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !isLoadingStats else {
                return
            }

            loadStats()
        }
    }

    private var heroStatsCard: some View {
        VStack(alignment: screenHorizontalAlignment, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                if isEnglish {
                    personalStatsIcon

                    VStack(alignment: .leading, spacing: 5) {
                        Text(memberName.isEmpty ? tr("מתאמן", "Trainee") : memberName)
                            .font(.system(size: 25, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(
                            isLoadingStats
                            ? tr("טוען נתוני נוכחות...", "Loading attendance data...")
                            : tr("סטטיסטיקת נוכחות אישית", "Personal Attendance Statistics")
                        )
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(red: 0.86, green: 0.94, blue: 1.0))
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(groupContextLine)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    personalStatsIcon

                    Spacer()

                    VStack(alignment: .trailing, spacing: 5) {
                        Text(memberName.isEmpty ? tr("מתאמן", "Trainee") : memberName)
                            .font(.system(size: 25, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Text(
                            isLoadingStats
                            ? tr("טוען נתוני נוכחות...", "Loading attendance data...")
                            : tr("סטטיסטיקת נוכחות אישית", "Personal Attendance Statistics")
                        )
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(red: 0.86, green: 0.94, blue: 1.0))
                        .frame(maxWidth: .infinity, alignment: .trailing)

                        Text(groupContextLine)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }

            HStack(spacing: 10) {
                statPill(
                    title: tr("חודש", "Month"),
                    value: "\(stats.monthlyPercent)%",
                    tint: Color(red: 0.55, green: 0.36, blue: 0.96)
                )

                statPill(
                    title: tr("שנה", "Year"),
                    value: "\(stats.yearlyPercent)%",
                    tint: Color(red: 0.13, green: 0.77, blue: 0.37)
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.16),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)
    }

    private var personalStatsIcon: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.65, blue: 0.91),
                        Color(red: 0.13, green: 0.83, blue: 0.93)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 56, height: 56)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)
            )
            .shadow(color: Color.cyan.opacity(0.35), radius: 10, x: 0, y: 4)
    }

    private var groupContextLine: String {
        let cleanBranch = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanGroup = groupKey.trimmingCharacters(in: .whitespacesAndNewlines)

        let branch = cleanBranch.isEmpty ? tr("לא נבחר סניף", "No branch selected") : cleanBranch
        let group = cleanGroup.isEmpty ? tr("לא נבחרה קבוצה", "No group selected") : cleanGroup

        return "\(branch) · \(group)"
    }
    
    private var percentCardsRow: some View {
        HStack(spacing: 12) {
            metricCard(
                title: tr("נוכחות חודשית", "Monthly Attendance"),
                percent: stats.monthlyPercent,
                icon: "calendar",
                gradient: [
                    Color(red: 0.55, green: 0.36, blue: 0.96),
                    Color(red: 0.93, green: 0.28, blue: 0.60)
                ]
            )

            metricCard(
                title: tr("נוכחות שנתית", "Yearly Attendance"),
                percent: stats.yearlyPercent,
                icon: "chart.line.uptrend.xyaxis",
                gradient: [
                    Color(red: 0.13, green: 0.77, blue: 0.37),
                    Color(red: 0.08, green: 0.71, blue: 0.67)
                ]
            )
        }
    }

    private var emptyMemberAttendanceStatsCard: some View {
        VStack(alignment: screenHorizontalAlignment, spacing: 8) {
            Text(tr("אין עדיין נתוני נוכחות למתאמן", "No attendance data for this trainee yet"))
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: screenAlignment)
                .multilineTextAlignment(screenTextAlignment)

            Text(
                tr(
                    "המסך מחובר לשרת. לאחר סימון ושמירת נוכחות במסך הנוכחות, הנתונים של \(memberName.isEmpty ? tr("המתאמן", "the trainee") : memberName) יופיעו כאן.",
                    "This screen is connected to the server. After attendance is marked and saved, \(memberName.isEmpty ? "the trainee" : memberName)'s data will appear here."
                )
            )
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color(red: 0.75, green: 0.86, blue: 1.0))
            .frame(maxWidth: .infinity, alignment: screenAlignment)
            .multilineTextAlignment(screenTextAlignment)

            Text(groupContextLine)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(red: 0.88, green: 0.96, blue: 1.0))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: screenAlignment)
                .multilineTextAlignment(screenTextAlignment)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color(red: 0.11, green: 0.31, blue: 0.85).opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var streakCard: some View {
        let progress = max(0.0, min(1.0, Double(stats.streakDays) / 10.0))

        return VStack(alignment: screenHorizontalAlignment, spacing: 12) {
            HStack {
                if isEnglish {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tr("רצף נוכחות", "Attendance Streak"))
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(Color(red: 0.07, green: 0.10, blue: 0.16))

                        Text(isEnglish ? "\(stats.streakDays) sessions in a row 👏" : "\(stats.streakDays) אימונים ברצף 👏")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(red: 0.29, green: 0.33, blue: 0.39))
                    }

                    Spacer()

                    Image(systemName: "clock.fill")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(red: 0.39, green: 0.40, blue: 0.95))
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())
                } else {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(red: 0.39, green: 0.40, blue: 0.95))
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(tr("רצף נוכחות", "Attendance Streak"))
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(Color(red: 0.07, green: 0.10, blue: 0.16))

                        Text(isEnglish ? "\(stats.streakDays) sessions in a row 👏" : "\(stats.streakDays) אימונים ברצף 👏")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(red: 0.29, green: 0.33, blue: 0.39))
                    }
                }
            }

            ProgressView(value: progress, total: 1)
                .progressViewStyle(.linear)
                .tint(Color(red: 0.39, green: 0.40, blue: 0.95))
                .background(Color(red: 0.90, green: 0.91, blue: 0.93))
                .clipShape(Capsule())

            Text(tr("יעד חודשי: 10 אימונים", "Monthly goal: 10 sessions"))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(red: 0.39, green: 0.40, blue: 0.95))
                .frame(maxWidth: .infinity, alignment: screenAlignment)
                .multilineTextAlignment(screenTextAlignment)
        }
        .padding(18)
        .background(Color.white.opacity(0.96))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    
    private var bestDaysCard: some View {
        VStack(alignment: screenHorizontalAlignment, spacing: 12) {
            HStack {
                if isEnglish {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tr("ימים חזקים", "Strong Days"))
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(Color(red: 0.07, green: 0.10, blue: 0.16))

                        Text(bestDaysSubtitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(red: 0.29, green: 0.33, blue: 0.39))
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                    }

                    Spacer()

                    Image(systemName: "list.star")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(red: 0.06, green: 0.65, blue: 0.91))
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())
                } else {
                    Image(systemName: "list.star")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(red: 0.06, green: 0.65, blue: 0.91))
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(tr("ימים חזקים", "Strong Days"))
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(Color(red: 0.07, green: 0.10, blue: 0.16))

                        Text(bestDaysSubtitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(red: 0.29, green: 0.33, blue: 0.39))
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                    }
                }
            }

            if stats.bestDays.isEmpty {
                emptyStateCard(
                    icon: "calendar.badge.exclamationmark",
                    title: tr("אין נתונים", "No data"),
                    subtitle: tr("לאחר שמירת מספר דו״חות נוכחות, יוצגו כאן הימים החזקים.", "After saving several attendance reports, strong days will appear here.")
                )
            } else {
                HStack(spacing: 8) {
                    ForEach(stats.bestDays.prefix(6), id: \.self) { day in
                        Text(localizedDayName(day))
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Color(red: 0.31, green: 0.27, blue: 0.90))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(red: 0.31, green: 0.27, blue: 0.90).opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 999, style: .continuous))
                    }
                }
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.96))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var bestDaysSubtitle: String {
        if isEnglish {
            return "The days \(memberName.isEmpty ? "the trainee" : memberName) attends most"
        }

        return "הימים שבהם \(memberName.isEmpty ? "המתאמן" : memberName) מגיע הכי הרבה"
    }
    
    private var lastSessionsCard: some View {
        VStack(alignment: screenHorizontalAlignment, spacing: 12) {
            HStack {
                if isEnglish {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tr("5 אימונים אחרונים", "Last 5 Sessions"))
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(Color(red: 0.07, green: 0.10, blue: 0.16))

                        Text(tr("דינמי לפי רשומות נוכחות", "Based on saved attendance records"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(red: 0.29, green: 0.33, blue: 0.39))
                    }

                    Spacer()

                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(red: 0.58, green: 0.78, blue: 1.0))
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())
                } else {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(red: 0.58, green: 0.78, blue: 1.0))
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(tr("5 אימונים אחרונים", "Last 5 Sessions"))
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(Color(red: 0.07, green: 0.10, blue: 0.16))

                        Text(tr("דינמי לפי רשומות נוכחות", "Based on saved attendance records"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(red: 0.29, green: 0.33, blue: 0.39))
                    }
                }
            }

            if stats.lastSessions.isEmpty {
                emptyStateCard(
                    icon: "calendar.badge.clock",
                    title: tr("אין נתונים", "No data"),
                    subtitle: tr("האימונים האחרונים יוצגו כאן לאחר שמירת דו״חות נוכחות.", "Recent sessions will appear here after attendance reports are saved.")
                )
            } else {
                VStack(spacing: 9) {
                    ForEach(stats.lastSessions.prefix(5), id: \.self) { line in
                        sessionRow(line)
                    }
                }
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.96))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    
    private func loadStats() {
        stats = repository.memberStats(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey,
            memberId: memberId
        )

        hasRealAttendanceData =
            stats.monthlyPercent > 0 ||
            stats.yearlyPercent > 0 ||
            stats.streakDays > 0 ||
            !stats.bestDays.isEmpty ||
            !stats.lastSessions.isEmpty

        loadRemoteStats()
    }

    private func loadRemoteStats() {
        guard !isLoadingStats else {
            return
        }

        isLoadingStats = true

        let repository = self.repository
        let ownerUid = self.ownerUid
        let branchName = self.branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        let groupKey = self.groupKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let memberId = self.memberId
        let startIso = oneYearBackIso()
        let endIsoExclusive = tomorrowIso()

        Task {
            do {
                let days = try await repository.listReportDaysInRangeFromFirestore(
                    ownerUid: ownerUid,
                    branchName: branchName,
                    groupKey: groupKey,
                    startIso: startIso,
                    endIsoExclusive: endIsoExclusive
                )

                var recordsByDate: [(dateIso: String, record: AttendanceRecord)] = []

                for dateIso in days.sorted(by: >) {
                    let records = try await repository.loadRecordsFromFirestore(
                        ownerUid: ownerUid,
                        branchName: branchName,
                        groupKey: groupKey,
                        dateIso: dateIso
                    )

                    if let record = records.first(where: { $0.memberId == memberId }) {
                        recordsByDate.append((dateIso: dateIso, record: record))
                    }
                }

                hasRealAttendanceData = !recordsByDate.isEmpty

                if !recordsByDate.isEmpty {
                    stats = makeStats(from: recordsByDate)
                }

                isLoadingStats = false
            } catch {
                isLoadingStats = false
            }
        }
    }

    private func makeStats(
        from recordsByDate: [(dateIso: String, record: AttendanceRecord)]
    ) -> AttendanceMemberStats {
        let calendar = Calendar.current
        let today = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
        let yearBack = calendar.date(byAdding: .year, value: -1, to: today) ?? today

        let monthStartIso = isoString(monthStart)
        let yearBackIso = isoString(yearBack)
        let todayIso = isoString(today)

        var monthPresent = 0
        var monthTotal = 0
        var yearPresent = 0
        var yearTotal = 0

        var streakDays = 0
        var streakOpen = true

        var lastSessions: [String] = []
        var bestDayCounts: [Int: Int] = [:]

        for item in recordsByDate.sorted(by: { $0.dateIso > $1.dateIso }) {
            let dateIso = item.dateIso
            let record = item.record

            let isPresent = record.status == .present
            let countsInTotals = record.status != .unknown

            if dateIso >= monthStartIso && dateIso <= todayIso && countsInTotals {
                monthTotal += 1
                if isPresent {
                    monthPresent += 1
                }
            }

            if dateIso >= yearBackIso && dateIso <= todayIso && countsInTotals {
                yearTotal += 1
                if isPresent {
                    yearPresent += 1
                }
            }

            if isPresent,
               let date = dateFromIso(dateIso) {
                let weekday = calendar.component(.weekday, from: date)
                bestDayCounts[weekday, default: 0] += 1
            }

            if lastSessions.count < 8 {
                lastSessions.append("\(displayDateShort(dateIso)) – \(localizedStatus(record.status))")
            }

            if isPresent {
                if streakOpen {
                    streakDays += 1
                }
            } else if countsInTotals {
                streakOpen = false
            }
        }

        let monthlyPercent = monthTotal > 0 ? Int((Double(monthPresent) / Double(monthTotal)) * 100.0) : 0
        let yearlyPercent = yearTotal > 0 ? Int((Double(yearPresent) / Double(yearTotal)) * 100.0) : 0

        let bestDays = bestDayCounts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }

                return lhs.value > rhs.value
            }
            .prefix(6)
            .map { weekday, _ in
                localizedWeekday(weekday)
            }

        return AttendanceMemberStats(
            monthlyPercent: monthlyPercent,
            yearlyPercent: yearlyPercent,
            streakDays: streakDays,
            bestDays: Array(bestDays),
            lastSessions: lastSessions
        )
    }

    private func oneYearBackIso() -> String {
        let today = Date()
        let yearBack = Calendar.current.date(byAdding: .year, value: -1, to: today) ?? today
        return isoString(yearBack)
    }

    private func tomorrowIso() -> String {
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        return isoString(tomorrow)
    }

    private func isoString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func dateFromIso(_ iso: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: iso)
    }

    private func displayDateShort(_ iso: String) -> String {
        guard let date = dateFromIso(iso) else {
            return iso
        }

        let formatter = DateFormatter()
        formatter.locale = isEnglish ? Locale(identifier: "en_US") : Locale(identifier: "he_IL")
        formatter.dateFormat = isEnglish ? "MMM d, yyyy" : "dd/MM/yyyy"
        return formatter.string(from: date)
    }

    private func localizedStatus(_ status: AttendanceStatus) -> String {
        status.localized(isEnglish: isEnglish)
    }

    private func localizedWeekday(_ weekday: Int) -> String {
        switch weekday {
        case 1:
            return isEnglish ? "Sun" : "ראשון"
        case 2:
            return isEnglish ? "Mon" : "שני"
        case 3:
            return isEnglish ? "Tue" : "שלישי"
        case 4:
            return isEnglish ? "Wed" : "רביעי"
        case 5:
            return isEnglish ? "Thu" : "חמישי"
        case 6:
            return isEnglish ? "Fri" : "שישי"
        case 7:
            return isEnglish ? "Sat" : "שבת"
        default:
            return isEnglish ? "Day" : "יום"
        }
    }

    private func metricFeedback(_ percent: Int) -> String {
        if percent >= 85 {
            return tr("מצוין 💜", "Excellent 💜")
        }

        if percent >= 70 {
            return tr("טוב מאוד", "Very good")
        }

        return tr("אפשר לשפר", "Can improve")
    }

    private func metricCard(
        title: String,
        percent: Int,
        icon: String,
        gradient: [Color]
    ) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)

                Circle()
                    .fill(Color.white)
                    .frame(width: 70, height: 70)

                Text("\(percent)%")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.07, green: 0.10, blue: 0.16))
            }

            Text(metricFeedback(percent))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(red: 0.90, green: 0.93, blue: 0.98))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func statPill(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(tint.opacity(0.24))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.32), lineWidth: 1)
        )
    }

    private func emptyStateCard(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(Color(red: 0.06, green: 0.45, blue: 0.75))
                .frame(width: 50, height: 50)
                .background(Color(red: 0.90, green: 0.95, blue: 1.0))
                .clipShape(Circle())

            Text(title)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(Color(red: 0.07, green: 0.10, blue: 0.16))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 0.42, green: 0.45, blue: 0.50))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 14)
        .background(Color(red: 0.95, green: 0.96, blue: 0.98))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func sessionRow(_ line: String) -> some View {
        HStack(spacing: 10) {
            if isEnglish {
                Text(localizedSessionLine(line))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.22, green: 0.25, blue: 0.32))
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Circle()
                    .fill(sessionTint(for: line))
                    .frame(width: 12, height: 12)
            } else {
                Circle()
                    .fill(sessionTint(for: line))
                    .frame(width: 12, height: 12)

                Text(localizedSessionLine(line))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.22, green: 0.25, blue: 0.32))
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func localizedSessionLine(_ line: String) -> String {
        guard isEnglish else { return line }

        return line
            .replacingOccurrences(of: "לא הגיע", with: "Absent")
            .replacingOccurrences(of: "לא סומן", with: "Not marked")
            .replacingOccurrences(of: "מוצדק", with: "Excused")
            .replacingOccurrences(of: "הגיע", with: "Present")
            .replacingOccurrences(of: "סה״כ", with: "Total")
    }

    private func localizedDayName(_ day: String) -> String {
        guard isEnglish else { return day }

        switch day.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "ראשון", "יום ראשון":
            return "Sun"
        case "שני", "יום שני":
            return "Mon"
        case "שלישי", "יום שלישי":
            return "Tue"
        case "רביעי", "יום רביעי":
            return "Wed"
        case "חמישי", "יום חמישי":
            return "Thu"
        case "שישי", "יום שישי":
            return "Fri"
        case "שבת", "יום שבת":
            return "Sat"
        default:
            return day
        }
    }

    private func sessionTint(for line: String) -> Color {
        let lower = line.lowercased()

        if line.contains("מוצדק") || lower.contains("excused") {
            return Color(red: 0.96, green: 0.62, blue: 0.04)
        }

        if line.contains("לא הגיע") || lower.contains("absent") {
            return Color(red: 0.94, green: 0.27, blue: 0.27)
        }

        if line.contains("לא סומן") || lower.contains("not marked") || lower.contains("unknown") {
            return Color.white.opacity(0.65)
        }

        if line.contains("הגיע") || lower.contains("present") {
            return Color(red: 0.13, green: 0.77, blue: 0.37)
        }

        return Color(red: 0.94, green: 0.27, blue: 0.27)
    }
}
