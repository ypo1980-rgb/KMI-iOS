import SwiftUI
import UIKit

private struct AttendanceMonthlyPoint:
    Identifiable,
    Equatable {

    let monthIso: String
    let attendedTrainings: Int

    var id: String {
        monthIso
    }
}

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

    @State private var monthlyPresentCount: Int = 0
    @State private var monthlyScheduledCount: Int = 0
    @State private var yearlyPresentCount: Int = 0
    @State private var yearlyScheduledCount: Int = 0

    @State private var monthlyAttendance:
        [AttendanceMonthlyPoint] = []

    @State private var showShareSheet:
        Bool = false

    @State private var shareItems:
        [Any] = []

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

            if isLoadingStats {
                AttendanceStatsLoadingRings(
                    title: tr(
                        "טוען נתוני נוכחות...",
                        "Loading attendance data..."
                    )
                )
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        heroStatsCard
                        percentCardsRow

                        if !hasRealAttendanceData {
                            emptyMemberAttendanceStatsCard
                        }

                        if !monthlyAttendance.isEmpty {
                            monthlyAttendanceChartCard
                        }

                        lastSessionsCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 120)
                }
            }
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
        .navigationTitle(
            tr(
                "סטטיסטיקת נוכחות",
                "Attendance Statistics"
            )
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(
                placement:
                    .navigationBarTrailing
            ) {
                Button {
                    shareAttendancePdf()
                } label: {
                    Image(
                        systemName:
                            "square.and.arrow.up"
                    )
                    .font(
                        .system(
                            size: 16,
                            weight: .bold
                        )
                    )
                }
                .disabled(
                    isLoadingStats ||
                    !hasRealAttendanceData
                )
                .accessibilityLabel(
                    tr(
                        "שיתוף דו״ח נוכחות",
                        "Share attendance report"
                    )
                )
            }
        }
        .sheet(
            isPresented:
                $showShareSheet
        ) {
            AttendanceStatsShareSheet(
                items: shareItems
            )
        }
        .onReceive(
            NotificationCenter.default
                .publisher(
                    for:
                        Notification.Name(
                            "KMI_GLOBAL_SHARE_REQUEST"
                        )
                )
        ) { notification in
            if let request =
                notification.object
                    as? NSMutableDictionary {
                request["handled"] = true
            }

            shareAttendancePdf()
        }
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
                title: tr(
                    "נוכחות חודשית",
                    "Monthly Attendance"
                ),
                percent: stats.monthlyPercent,
                attendedCount:
                    monthlyPresentCount,
                scheduledCount:
                    monthlyScheduledCount,
                icon: "calendar",
                gradient: [
                    Color(
                        red: 0.55,
                        green: 0.36,
                        blue: 0.96
                    ),
                    Color(
                        red: 0.93,
                        green: 0.28,
                        blue: 0.60
                    )
                ]
            )

            metricCard(
                title: tr(
                    "נוכחות שנתית",
                    "Yearly Attendance"
                ),
                percent: stats.yearlyPercent,
                attendedCount:
                    yearlyPresentCount,
                scheduledCount:
                    yearlyScheduledCount,
                icon:
                    "chart.line.uptrend.xyaxis",
                gradient: [
                    Color(
                        red: 0.13,
                        green: 0.77,
                        blue: 0.37
                    ),
                    Color(
                        red: 0.08,
                        green: 0.71,
                        blue: 0.67
                    )
                ]
            )
        }
    }

    private var monthlyAttendanceChartCard:
        some View {

        let maximumValue =
            max(
                1,
                monthlyAttendance
                    .map {
                        $0.attendedTrainings
                    }
                    .max() ?? 1
            )

        return VStack(
            alignment:
                screenHorizontalAlignment,
            spacing: 14
        ) {
            HStack(spacing: 10) {
                if isEnglish {
                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {
                        Text(
                            tr(
                                "נוכחות לפי חודשים",
                                "Monthly Attendance"
                            )
                        )
                        .font(
                            .system(
                                size: 18,
                                weight: .heavy
                            )
                        )
                        .foregroundStyle(
                            Color(
                                red: 0.07,
                                green: 0.10,
                                blue: 0.16
                            )
                        )

                        Text(
                            tr(
                                "מספר האימונים שבהם נכחת",
                                "Number of attended sessions"
                            )
                        )
                        .font(
                            .system(
                                size: 13,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(
                            Color(
                                red: 0.29,
                                green: 0.33,
                                blue: 0.39
                            )
                        )
                    }

                    Spacer()

                    monthlyChartIcon
                } else {
                    monthlyChartIcon

                    Spacer()

                    VStack(
                        alignment: .trailing,
                        spacing: 4
                    ) {
                        Text(
                            tr(
                                "נוכחות לפי חודשים",
                                "Monthly Attendance"
                            )
                        )
                        .font(
                            .system(
                                size: 18,
                                weight: .heavy
                            )
                        )
                        .foregroundStyle(
                            Color(
                                red: 0.07,
                                green: 0.10,
                                blue: 0.16
                            )
                        )

                        Text(
                            tr(
                                "מספר האימונים שבהם נכחת",
                                "Number of attended sessions"
                            )
                        )
                        .font(
                            .system(
                                size: 13,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(
                            Color(
                                red: 0.29,
                                green: 0.33,
                                blue: 0.39
                            )
                        )
                    }
                }
            }

            ScrollView(
                .horizontal,
                showsIndicators: false
            ) {
                HStack(
                    alignment: .bottom,
                    spacing: 14
                ) {
                    ForEach(
                        monthlyAttendance
                    ) { point in
                        VStack(spacing: 7) {
                            Text(
                                "\(point.attendedTrainings)"
                            )
                            .font(
                                .system(
                                    size: 12,
                                    weight: .black
                                )
                            )
                            .foregroundStyle(
                                Color(
                                    red: 0.16,
                                    green: 0.35,
                                    blue: 0.78
                                )
                            )

                            RoundedRectangle(
                                cornerRadius: 8,
                                style: .continuous
                            )
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(
                                            red: 0.13,
                                            green: 0.77,
                                            blue: 0.94
                                        ),
                                        Color(
                                            red: 0.31,
                                            green: 0.27,
                                            blue: 0.90
                                        )
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(
                                width: 28,
                                height:
                                    max(
                                        18,
                                        CGFloat(
                                            point
                                                .attendedTrainings
                                        ) /
                                        CGFloat(
                                            maximumValue
                                        ) *
                                        108
                                    )
                            )
                            .shadow(
                                color:
                                    Color.blue
                                        .opacity(0.18),
                                radius: 4,
                                x: 0,
                                y: 3
                            )

                            Text(
                                chartMonthLabel(
                                    point.monthIso
                                )
                            )
                            .font(
                                .system(
                                    size: 11,
                                    weight: .bold
                                )
                            )
                            .foregroundStyle(
                                Color(
                                    red: 0.35,
                                    green: 0.39,
                                    blue: 0.46
                                )
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .frame(width: 48)
                        }
                        .frame(
                            height: 160,
                            alignment: .bottom
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
            .environment(
                \.layoutDirection,
                .leftToRight
            )
        }
        .padding(18)
        .background(
            Color.white.opacity(0.96)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(0.18),
                lineWidth: 1
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
        )
    }

    private var monthlyChartIcon: some View {
        Image(
            systemName:
                "chart.bar.xaxis"
        )
        .font(
            .system(
                size: 18,
                weight: .heavy
            )
        )
        .foregroundStyle(
            Color(
                red: 0.31,
                green: 0.27,
                blue: 0.90
            )
        )
        .frame(
            width: 38,
            height: 38
        )
        .background(
            Color(
                red: 0.31,
                green: 0.27,
                blue: 0.90
            )
            .opacity(0.12)
        )
        .clipShape(Circle())
    }

    private func chartMonthLabel(
        _ monthIso: String
    ) -> String {
        let formatter =
            DateFormatter()

        formatter.locale =
            Locale(
                identifier:
                    "en_US_POSIX"
            )

        formatter.dateFormat =
            "yyyy-MM"

        guard let date =
            formatter.date(
                from: monthIso
            )
        else {
            return monthIso
        }

        formatter.locale =
            isEnglish
            ? Locale(
                identifier: "en_US"
            )
            : Locale(
                identifier: "he_IL"
            )

        formatter.dateFormat =
            isEnglish
            ? "MMM yy"
            : "MMM yy"

        return formatter.string(
            from: date
        )
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
    
    private func shareAttendancePdf() {
        guard
            !isLoadingStats,
            hasRealAttendanceData
        else {
            return
        }

        do {
            let pdfUrl =
                try createAttendancePdf()

            shareItems = [pdfUrl]
            showShareSheet = true
        } catch {
            print(
                "AttendanceStatsView: failed creating PDF:",
                error.localizedDescription
            )
        }
    }

    private func createAttendancePdf()
        throws -> URL {

        let pageBounds =
            CGRect(
                x: 0,
                y: 0,
                width: 595,
                height: 842
            )

        let renderer =
            UIGraphicsPDFRenderer(
                bounds: pageBounds
            )

        let pdfData =
            renderer.pdfData { context in
                context.beginPage()

                let graphics =
                    context.cgContext

                UIColor(
                    red: 0.96,
                    green: 0.98,
                    blue: 1.0,
                    alpha: 1
                )
                .setFill()

                graphics.fill(pageBounds)

                UIColor(
                    red: 0.02,
                    green: 0.17,
                    blue: 0.29,
                    alpha: 1
                )
                .setFill()

                graphics.fill(
                    CGRect(
                        x: 0,
                        y: 0,
                        width: pageBounds.width,
                        height: 112
                    )
                )

                var currentY: CGFloat = 30

                func drawText(
                    _ text: String,
                    font: UIFont,
                    color: UIColor,
                    spacingAfter: CGFloat = 8,
                    forcedAlignment:
                        NSTextAlignment? = nil
                ) {
                    let paragraph =
                        NSMutableParagraphStyle()

                    paragraph.alignment =
                        forcedAlignment ??
                        (
                            isEnglish
                            ? .left
                            : .right
                        )

                    paragraph
                        .baseWritingDirection =
                            isEnglish
                            ? .leftToRight
                            : .rightToLeft

                    let attributes:
                        [NSAttributedString.Key: Any] = [
                            .font: font,
                            .foregroundColor:
                                color,
                            .paragraphStyle:
                                paragraph
                        ]

                    let availableWidth =
                        pageBounds.width - 48

                    let measured =
                        (text as NSString)
                            .boundingRect(
                                with:
                                    CGSize(
                                        width:
                                            availableWidth,
                                        height:
                                            .greatestFiniteMagnitude
                                    ),
                                options: [
                                    .usesLineFragmentOrigin,
                                    .usesFontLeading
                                ],
                                attributes:
                                    attributes,
                                context: nil
                            )

                    let height =
                        max(
                            font.lineHeight,
                            ceil(measured.height)
                        )

                    let rect =
                        CGRect(
                            x: 24,
                            y: currentY,
                            width:
                                availableWidth,
                            height:
                                height
                        )

                    (text as NSString).draw(
                        with: rect,
                        options: [
                            .usesLineFragmentOrigin,
                            .usesFontLeading
                        ],
                        attributes:
                            attributes,
                        context: nil
                    )

                    currentY +=
                        height +
                        spacingAfter
                }

                drawText(
                    tr(
                        "דו״ח נוכחות ק.מ.י",
                        "KAMI Attendance Report"
                    ),
                    font:
                        .systemFont(
                            ofSize: 27,
                            weight: .bold
                        ),
                    color: .white,
                    spacingAfter: 8
                )

                drawText(
                    memberName.isEmpty
                    ? tr("מתאמן", "Trainee")
                    : memberName,
                    font:
                        .systemFont(
                            ofSize: 18,
                            weight: .semibold
                        ),
                    color:
                        UIColor.white
                            .withAlphaComponent(
                                0.90
                            ),
                    spacingAfter: 28
                )

                currentY = 132

                drawText(
                    tr(
                        "פרטי המתאמן",
                        "Trainee Details"
                    ),
                    font:
                        .systemFont(
                            ofSize: 19,
                            weight: .bold
                        ),
                    color:
                        UIColor(
                            red: 0.02,
                            green: 0.17,
                            blue: 0.29,
                            alpha: 1
                        ),
                    spacingAfter: 10
                )

                drawText(
                    tr(
                        "סניף: \(branchName)",
                        "Branch: \(branchName)"
                    ),
                    font:
                        .systemFont(
                            ofSize: 14,
                            weight: .medium
                        ),
                    color: .darkGray
                )

                drawText(
                    tr(
                        "קבוצה: \(groupKey)",
                        "Group: \(groupKey)"
                    ),
                    font:
                        .systemFont(
                            ofSize: 14,
                            weight: .medium
                        ),
                    color: .darkGray
                )

                drawText(
                    tr(
                        "תאריך הפקה: \(displayDateShort(isoString(Date())))",
                        "Generated: \(displayDateShort(isoString(Date())))"
                    ),
                    font:
                        .systemFont(
                            ofSize: 14,
                            weight: .medium
                        ),
                    color: .darkGray,
                    spacingAfter: 22
                )

                drawText(
                    tr(
                        "סיכום נוכחות",
                        "Attendance Summary"
                    ),
                    font:
                        .systemFont(
                            ofSize: 19,
                            weight: .bold
                        ),
                    color:
                        UIColor(
                            red: 0.02,
                            green: 0.17,
                            blue: 0.29,
                            alpha: 1
                        ),
                    spacingAfter: 10
                )

                drawText(
                    tr(
                        "נוכחות חודשית: \(stats.monthlyPercent)% — \(monthlyPresentCount) מתוך \(monthlyScheduledCount) אימונים",
                        "Monthly attendance: \(stats.monthlyPercent)% — \(monthlyPresentCount) of \(monthlyScheduledCount) sessions"
                    ),
                    font:
                        .systemFont(
                            ofSize: 15,
                            weight: .semibold
                        ),
                    color:
                        UIColor(
                            red: 0.10,
                            green: 0.38,
                            blue: 0.76,
                            alpha: 1
                        ),
                    spacingAfter: 8
                )

                drawText(
                    tr(
                        "נוכחות שנתית: \(stats.yearlyPercent)% — \(yearlyPresentCount) מתוך \(yearlyScheduledCount) אימונים",
                        "Yearly attendance: \(stats.yearlyPercent)% — \(yearlyPresentCount) of \(yearlyScheduledCount) sessions"
                    ),
                    font:
                        .systemFont(
                            ofSize: 15,
                            weight: .semibold
                        ),
                    color:
                        UIColor(
                            red: 0.05,
                            green: 0.55,
                            blue: 0.29,
                            alpha: 1
                        ),
                    spacingAfter: 22
                )

                if !monthlyAttendance.isEmpty {
                    drawText(
                        tr(
                            "נוכחות לפי חודשים",
                            "Monthly Attendance"
                        ),
                        font:
                            .systemFont(
                                ofSize: 19,
                                weight: .bold
                            ),
                        color:
                            UIColor(
                                red: 0.02,
                                green: 0.17,
                                blue: 0.29,
                                alpha: 1
                            ),
                        spacingAfter: 10
                    )

                    let monthlyLine =
                        monthlyAttendance
                            .map {
                                "\(chartMonthLabel($0.monthIso)): \($0.attendedTrainings)"
                            }
                            .joined(
                                separator: "  •  "
                            )

                    drawText(
                        monthlyLine,
                        font:
                            .systemFont(
                                ofSize: 13,
                                weight: .medium
                            ),
                        color: .darkGray,
                        spacingAfter: 22
                    )
                }

                drawText(
                    tr(
                        "5 אימונים אחרונים",
                        "Last 5 Sessions"
                    ),
                    font:
                        .systemFont(
                            ofSize: 19,
                            weight: .bold
                        ),
                    color:
                        UIColor(
                            red: 0.02,
                            green: 0.17,
                            blue: 0.29,
                            alpha: 1
                        ),
                    spacingAfter: 10
                )

                if stats.lastSessions.isEmpty {
                    drawText(
                        tr(
                            "אין עדיין נתוני אימונים.",
                            "No session data yet."
                        ),
                        font:
                            .systemFont(
                                ofSize: 14,
                                weight: .medium
                            ),
                        color: .gray
                    )
                } else {
                    for session in
                        stats.lastSessions
                            .prefix(5) {
                        drawText(
                            "• \(localizedSessionLine(session))",
                            font:
                                .systemFont(
                                    ofSize: 14,
                                    weight: .medium
                                ),
                            color: .darkGray,
                            spacingAfter: 7
                        )
                    }
                }
            }

        let safeMemberName =
            (memberName.isEmpty
             ? "trainee"
             : memberName)
                .replacingOccurrences(
                    of: "/",
                    with: "-"
                )
                .replacingOccurrences(
                    of: "\\",
                    with: "-"
                )
                .replacingOccurrences(
                    of: ":",
                    with: "-"
                )

        let fileName =
            "KAMI_Attendance_\(safeMemberName)_\(isoString(Date())).pdf"

        let fileUrl =
            FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    fileName
                )

        try pdfData.write(
            to: fileUrl,
            options: .atomic
        )

        return fileUrl
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

        let cleanBranch =
            branchName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let cleanGroup =
            groupKey.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let cleanMemberId =
            memberId.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard
            !cleanBranch.isEmpty,
            !cleanGroup.isEmpty,
            !cleanMemberId.isEmpty
        else {
            hasRealAttendanceData = false
            isLoadingStats = false
            return
        }

        isLoadingStats = true

        let repository = self.repository
        let requestedFromIso = oneYearBackIso()
        let toIso = isoString(Date())

        Task {
            do {
                let history =
                    try await repository
                    .memberAttendanceHistoryFromFirestore(
                        branchName:
                            cleanBranch,
                        groupKey:
                            cleanGroup,
                        memberId:
                            cleanMemberId,
                        memberName:
                            memberName,
                        requestedFromIso:
                            requestedFromIso,
                            toIso:
                                toIso
                        )

                let result =
                    makeStats(
                        from: history,
                        branchName: cleanBranch,
                        groupKey: cleanGroup
                    )

                stats = result.stats

                hasRealAttendanceData =
                    result.hasRealAttendanceData

                monthlyPresentCount =
                    result.monthlyPresentCount

                monthlyScheduledCount =
                    result.monthlyScheduledCount

                yearlyPresentCount =
                    result.yearlyPresentCount

                yearlyScheduledCount =
                    result.yearlyScheduledCount

                monthlyAttendance =
                    result.monthlyAttendance

                isLoadingStats = false
            } catch {
                print(
                    "AttendanceStatsView: failed loading member history:",
                    error.localizedDescription
                )

                hasRealAttendanceData =
                    stats.monthlyPercent > 0 ||
                    stats.yearlyPercent > 0 ||
                    stats.streakDays > 0 ||
                    !stats.bestDays.isEmpty ||
                    !stats.lastSessions.isEmpty

                isLoadingStats = false
            }
        }
    }

    /*
     * זהה לחישוב Android:
     *
     * המונה מבוסס על תאריכים שבהם המתאמן
     * סומן כנוכח.
     *
     * המכנה מבוסס על כל האימונים המתוכננים
     * בלוח השבועי של הקבוצה, ממועד תחילת
     * המתאמן ועד היום.
     */
    private func makeStats(
        from history:
            AttendanceMemberHistorySnapshot,
        branchName: String,
        groupKey: String
    ) -> (
        stats: AttendanceMemberStats,
        hasRealAttendanceData: Bool,
        monthlyPresentCount: Int,
        monthlyScheduledCount: Int,
        yearlyPresentCount: Int,
        yearlyScheduledCount: Int,
        monthlyAttendance:
            [AttendanceMonthlyPoint]
    ) {
        let calendar =
            Calendar(identifier: .gregorian)

        let today =
            calendar.startOfDay(for: Date())

        let todayIso =
            isoString(today)

        let currentMonthStart =
            calendar.date(
                from:
                    calendar.dateComponents(
                        [.year, .month],
                        from: today
                    )
            ) ?? today

        let currentMonthStartIso =
            isoString(currentMonthStart)

        /*
         * קוראים את ימי האימון השבועיים
         * ממקור האמת הגלובלי.
         */
        let exactGroupTrainings =
            TrainingCatalogIOS.trainingsFor(
                branch: branchName,
                group: groupKey
            )

        /*
         * גיבוי זהה לאנדרואיד:
         * אם שם הקבוצה אינו תואם בדיוק,
         * משתמשים בכל אימוני הסניף.
         */
        let catalogTrainings =
            exactGroupTrainings.isEmpty
            ? TrainingCatalogIOS.trainingsFor(
                branch: branchName,
                group: nil
            )
            : exactGroupTrainings

        let scheduledWeekdays =
            Set(
                catalogTrainings.map {
                    calendar.component(
                        .weekday,
                        from: $0.date
                    )
                }
            )

        let historySessions =
            history.sessions
                .filter {
                    $0.dateIso <= todayIso
                }
                .sorted {
                    $0.dateIso > $1.dateIso
                }

        /*
         * אם מועד יצירת המתאמן מאוחר מתחילת
         * החודש, אך קיימת לו נוכחות מוקדמת יותר
         * באותו חודש, מתחילים מתחילת החודש.
         */
        let hasSessionInCurrentMonth =
            historySessions.contains {
                $0.dateIso >= currentMonthStartIso &&
                $0.dateIso <= todayIso
            }

        let requestedStartIso: String

        if history.memberStartDateIso >
                currentMonthStartIso,
           hasSessionInCurrentMonth {
            requestedStartIso =
                currentMonthStartIso
        } else {
            requestedStartIso =
                history.memberStartDateIso
        }

        let scheduleStartDate =
            dateFromIso(requestedStartIso)
                .map {
                    calendar.startOfDay(for: $0)
                } ?? currentMonthStart

        /*
         * יצירת כל מועדי האימון המתוכננים
         * שכבר התקיימו. תאריכים עתידיים אינם
         * נכנסים למכנה.
         */
        var scheduledDateIsos = Set<String>()

        if !scheduledWeekdays.isEmpty {
            var cursor = scheduleStartDate

            while cursor <= today {
                let weekday =
                    calendar.component(
                        .weekday,
                        from: cursor
                    )

                if scheduledWeekdays.contains(
                    weekday
                ) {
                    scheduledDateIsos.insert(
                        isoString(cursor)
                    )
                }

                guard let nextDate =
                    calendar.date(
                        byAdding: .day,
                        value: 1,
                        to: cursor
                    )
                else {
                    break
                }

                cursor = nextDate
            }
        }

        let monthlyScheduledDates =
            scheduledDateIsos.filter {
                $0 >= currentMonthStartIso &&
                $0 <= todayIso
            }

        /*
         * כל תאריך נוכחות נספר פעם אחת בלבד.
         */
        let presentDateIsos =
            Set(
                historySessions
                    .filter {
                        $0.status == .present
                    }
                    .map {
                        $0.dateIso
                    }
            )

        let monthlyPresentCount =
            presentDateIsos.filter {
                $0 >= currentMonthStartIso &&
                $0 <= todayIso
            }
            .count

        let yearlyPresentCount =
            presentDateIsos.filter {
                $0 >= requestedStartIso &&
                $0 <= todayIso
            }
            .count

        let monthlyScheduledCount =
            monthlyScheduledDates.count

        let yearlyScheduledCount =
            scheduledDateIsos.count

        let monthlyPercent: Int

        if monthlyScheduledCount > 0 {
            monthlyPercent =
                min(
                    100,
                    max(
                        0,
                        Int(
                            Double(
                                monthlyPresentCount
                            ) *
                            100.0 /
                            Double(
                                monthlyScheduledCount
                            )
                        )
                    )
                )
        } else {
            monthlyPercent = 0
        }

        let yearlyPercent: Int

        if yearlyScheduledCount > 0 {
            yearlyPercent =
                min(
                    100,
                    max(
                        0,
                        Int(
                            Double(
                                yearlyPresentCount
                            ) *
                            100.0 /
                            Double(
                                yearlyScheduledCount
                            )
                        )
                    )
                )
        } else {
            yearlyPercent = 0
        }

        var streakDays = 0
        var streakIsOpen = true
        var bestDayCounts: [Int: Int] = [:]

        for session in historySessions {
            if session.status == .present {
                if streakIsOpen {
                    streakDays += 1
                }

                if let date =
                    dateFromIso(
                        session.dateIso
                    ) {
                    let weekday =
                        calendar.component(
                            .weekday,
                            from: date
                        )

                    bestDayCounts[
                        weekday,
                        default: 0
                    ] += 1
                }
            } else if session.status != .unknown {
                streakIsOpen = false
            }
        }

        let bestDays =
            bestDayCounts
                .sorted { left, right in
                    if left.value == right.value {
                        return left.key <
                            right.key
                    }

                    return left.value >
                        right.value
                }
                .prefix(6)
                .map { weekday, _ in
                    localizedWeekday(weekday)
                }

        let lastSessions =
            historySessions
                .prefix(5)
                .map { session in
                    "\(displayDateShort(session.dateIso)) – \(localizedStatus(session.status))"
                }

        /*
         * זהה לאנדרואיד:
         * בגרף מוצגים רק חודשים שבהם הייתה
         * לפחות נוכחות אחת.
         */
        var attendanceByMonth:
            [String: Int] = [:]

        for dateIso in presentDateIsos {
            guard dateIso.count >= 7 else {
                continue
            }

            let monthIso =
                String(dateIso.prefix(7))

            attendanceByMonth[
                monthIso,
                default: 0
            ] += 1
        }

        let monthlyAttendance =
            attendanceByMonth
                .map { monthIso, count in
                    AttendanceMonthlyPoint(
                        monthIso: monthIso,
                        attendedTrainings: count
                    )
                }
                .filter {
                    $0.attendedTrainings > 0
                }
                .sorted {
                    $0.monthIso < $1.monthIso
                }
                .suffix(12)

        let hasRealAttendanceData =
            !historySessions.isEmpty ||
            !scheduledDateIsos.isEmpty

        return (
            stats:
                AttendanceMemberStats(
                    monthlyPercent:
                        monthlyPercent,
                    yearlyPercent:
                        yearlyPercent,
                    streakDays:
                        streakDays,
                    bestDays:
                        Array(bestDays),
                    lastSessions:
                        lastSessions
                ),
            hasRealAttendanceData:
                hasRealAttendanceData,
            monthlyPresentCount:
                monthlyPresentCount,
            monthlyScheduledCount:
                monthlyScheduledCount,
            yearlyPresentCount:
                yearlyPresentCount,
            yearlyScheduledCount:
                yearlyScheduledCount,
            monthlyAttendance:
                Array(monthlyAttendance)
        )
    }

    private func oneYearBackIso() -> String {
        let today = Date()
        let yearBack =
            Calendar.current.date(
                byAdding: .year,
                value: -1,
                to: today
            ) ?? today

        return isoString(yearBack)
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
        attendedCount: Int,
        scheduledCount: Int,
        icon: String,
        gradient: [Color]
    ) -> some View {
        VStack(spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(
                        .system(
                            size: 13,
                            weight: .heavy
                        )
                    )

                Text(title)
                    .font(
                        .system(
                            size: 14,
                            weight: .heavy
                        )
                    )
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .multilineTextAlignment(.center)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint:
                                .topLeading,
                            endPoint:
                                .bottomTrailing
                        )
                    )
                    .frame(
                        width: 96,
                        height: 96
                    )

                Circle()
                    .fill(Color.white)
                    .frame(
                        width: 70,
                        height: 70
                    )

                Text("\(percent)%")
                    .font(
                        .system(
                            size: 20,
                            weight: .black,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        Color(
                            red: 0.07,
                            green: 0.10,
                            blue: 0.16
                        )
                    )
            }

            Text(
                tr(
                    "\(attendedCount) מתוך \(scheduledCount) אימונים",
                    "\(attendedCount) of \(scheduledCount) sessions"
                )
            )
            .font(
                .system(
                    size: 12,
                    weight: .heavy
                )
            )
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.75)

            Text(metricFeedback(percent))
                .font(
                    .system(
                        size: 12,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    Color(
                        red: 0.90,
                        green: 0.93,
                        blue: 0.98
                    )
                )
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            Color.white.opacity(0.10)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(0.16),
                lineWidth: 1
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
        )
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

    private func sessionTint(
        for line: String
    ) -> Color {
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

private struct AttendanceStatsLoadingRings: View {
    let title: String

    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                loadingRing(
                    size: 92,
                    lineWidth: 7,
                    color:
                        Color(
                            red: 0.13,
                            green: 0.83,
                            blue: 0.93
                        ),
                    trimEnd: 0.72,
                    reversed: false
                )

                loadingRing(
                    size: 66,
                    lineWidth: 6,
                    color:
                        Color(
                            red: 0.55,
                            green: 0.36,
                            blue: 0.96
                        ),
                    trimEnd: 0.62,
                    reversed: true
                )

                loadingRing(
                    size: 40,
                    lineWidth: 5,
                    color:
                        Color(
                            red: 0.13,
                            green: 0.77,
                            blue: 0.37
                        ),
                    trimEnd: 0.54,
                    reversed: false
                )
            }
            .frame(width: 100, height: 100)

            Text(title)
                .font(
                    .system(
                        size: 16,
                        weight: .heavy
                    )
                )
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .onAppear {
            rotation = 360
        }
    }

    private func loadingRing(
        size: CGFloat,
        lineWidth: CGFloat,
        color: Color,
        trimEnd: CGFloat,
        reversed: Bool
    ) -> some View {
        Circle()
            .trim(
                from: 0.08,
                to: trimEnd
            )
            .stroke(
                color,
                style:
                    StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
            )
            .frame(
                width: size,
                height: size
            )
            .rotationEffect(
                .degrees(
                    reversed
                        ? -rotation
                        : rotation
                )
            )
            .animation(
                .linear(duration: 1.15)
                    .repeatForever(
                        autoreverses: false
                    ),
                value: rotation
            )
    }
}

private struct AttendanceStatsShareSheet:
    UIViewControllerRepresentable {

    let items: [Any]

    func makeUIViewController(
        context: Context
    ) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController:
            UIActivityViewController,
        context: Context
    ) {
    }
}
