import SwiftUI

struct AttendanceStatsView: View {

    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"

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

    private let repository: AttendanceRepository

    private var isEnglish: Bool {
        let values = [
            kmiAppLanguageCode.lowercased(),
            appLanguageRaw.lowercased(),
            initialLanguageCode.lowercased()
        ]

        return values.contains("en") || values.contains("english")
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

                        Text(tr("סטטיסטיקת נוכחות אישית", "Personal Attendance Statistics"))
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

                        Text(tr("סטטיסטיקת נוכחות אישית", "Personal Attendance Statistics"))
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

    private var streakCard: some View {
        let progress = max(0.0, min(1.0, Double(stats.streakDays) / 10.0))

        return VStack(alignment: screenHorizontalAlignment, spacing: 12) {
            HStack {
                if isEnglish {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tr("רצף נוכחות", "Attendance Streak"))
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(.white)

                        Text(isEnglish ? "\(stats.streakDays) sessions in a row 👏" : "\(stats.streakDays) אימונים ברצף 👏")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
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
                            .foregroundStyle(.white)

                        Text(isEnglish ? "\(stats.streakDays) sessions in a row 👏" : "\(stats.streakDays) אימונים ברצף 👏")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
            }

            ProgressView(value: progress, total: 1)
                .progressViewStyle(.linear)
                .tint(Color(red: 0.39, green: 0.40, blue: 0.95))
                .background(Color.white.opacity(0.14))
                .clipShape(Capsule())

            Text(tr("יעד חודשי: 10 אימונים", "Monthly goal: 10 sessions"))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(red: 0.70, green: 0.78, blue: 1.0))
                .frame(maxWidth: .infinity, alignment: screenAlignment)
                .multilineTextAlignment(screenTextAlignment)
        }
        .padding(16)
        .background(Color.white.opacity(0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    
    private var bestDaysCard: some View {
        VStack(alignment: screenHorizontalAlignment, spacing: 12) {
            HStack {
                if isEnglish {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tr("ימים חזקים", "Strong Days"))
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(.white)

                        Text(bestDaysSubtitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.72))
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
                            .foregroundStyle(.white)

                        Text(bestDaysSubtitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.72))
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
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(red: 0.06, green: 0.65, blue: 0.91).opacity(0.28))
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                            )
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
                        Text(tr("אימונים אחרונים", "Recent Sessions"))
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(.white)

                        Text(tr("8 האחרונים", "Last 8"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.72))
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
                        Text(tr("אימונים אחרונים", "Recent Sessions"))
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(.white)

                        Text(tr("8 האחרונים", "Last 8"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.72))
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
                    ForEach(stats.lastSessions.prefix(8), id: \.self) { line in
                        sessionRow(line)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    
    private func loadStats() {

        stats = repository.memberStats(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey,
            memberId: memberId
        )
    }

    private func metricCard(
        title: String,
        percent: Int,
        icon: String,
        gradient: [Color]
    ) -> some View {
        VStack(alignment: .trailing, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.92))

                Spacer()

                Text(title)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
            }

            Text("\(percent)%")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)

            ProgressView(value: Double(max(0, min(100, percent))), total: 100)
                .progressViewStyle(.linear)
                .tint(.white)
                .background(Color.white.opacity(0.18))
                .clipShape(Capsule())
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.92)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 5)
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
                .foregroundStyle(Color(red: 0.58, green: 0.78, blue: 1.0))
                .frame(width: 50, height: 50)
                .background(Color.white.opacity(0.10))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            Text(title)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.white.opacity(0.88))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.64))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.075))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func sessionRow(_ line: String) -> some View {
        HStack(spacing: 10) {
            if isEnglish {
                Text(localizedSessionLine(line))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Circle()
                    .fill(sessionTint(for: line))
                    .frame(width: 10, height: 10)
            } else {
                Circle()
                    .fill(sessionTint(for: line))
                    .frame(width: 10, height: 10)

                Text(localizedSessionLine(line))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func localizedSessionLine(_ line: String) -> String {
        guard isEnglish else { return line }

        return line
            .replacingOccurrences(of: "הגיע", with: "Present")
            .replacingOccurrences(of: "מוצדק", with: "Excused")
            .replacingOccurrences(of: "לא הגיע", with: "Absent")
            .replacingOccurrences(of: "לא סומן", with: "Not marked")
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
