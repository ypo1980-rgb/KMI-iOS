import SwiftUI

struct AttendanceGroupStatsView: View {
    let ownerUid: String
    let initialBranchName: String
    let initialGroupKey: String

    @State private var branchName: String
    @State private var groupKey: String

    @State private var reports: [AttendanceSavedReport] = []
    @State private var summary: AttendanceGroupStatsSummary =
        .init(averagePercent: 0, totalSessions: 0, averagePresent: 0, averageTotal: 0)

    @State private var deleteMode: Bool = false
    @State private var selectedReportIds: Set<String> = []
    @State private var showDeleteConfirm: Bool = false
    @State private var showResetConfirm: Bool = false
    @State private var isLoadingReports: Bool = false

    private let repository: AttendanceRepository

    private var isEnglish: Bool {
        let defaults = UserDefaults.standard

        let values = [
            defaults.string(forKey: "kmi_app_language"),
            defaults.string(forKey: "app_language"),
            defaults.string(forKey: "initial_language_code"),
            defaults.string(forKey: "initial_language_selected_code"),
            defaults.string(forKey: "kmi.language.code")
        ]
        .compactMap { $0 }
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

    private var screenTextAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var screenHorizontalAlignment: HorizontalAlignment {
        isEnglish ? .leading : .trailing
    }

    private var screenFrameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    init(
        ownerUid: String,
        initialBranchName: String = "",
        initialGroupKey: String = "",
        repository: AttendanceRepository = .shared
    ) {
        self.ownerUid = ownerUid
        self.initialBranchName = initialBranchName
        self.initialGroupKey = initialGroupKey
        self.repository = repository

        _branchName = State(initialValue: initialBranchName)
        _groupKey = State(initialValue: initialGroupKey)
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
                    statsHeroCard
                    summaryCard
                    reportsToolbarCard
                    reportsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 120)
            }
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
        .navigationTitle(tr("סטטיסטיקת נוכחות", "Attendance statistics"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            tr("מחיקת דו״חות", "Delete reports"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(tr("מחק נבחרים", "Delete selected"), role: .destructive) {
                deleteSelectedReports()
            }

            Button(tr("ביטול", "Cancel"), role: .cancel) { }
        } message: {
            Text(
                isEnglish
                ? "Delete \(selectedReportIds.count) selected reports?"
                : "האם למחוק \(selectedReportIds.count) דו״חות שנבחרו?"
            )
        }
        .confirmationDialog(
            tr("איפוס דו״חות", "Reset reports"),
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button(tr("איפוס הכול", "Reset all"), role: .destructive) {
                resetAllReports()
            }

            Button(tr("ביטול", "Cancel"), role: .cancel) { }
        } message: {
            Text(
                tr(
                    "האם למחוק את כל דו״חות הנוכחות עבור הקבוצה הנוכחית?",
                    "Delete all attendance reports for the current group?"
                )
            )
        }
        .onAppear {
            syncIncomingFilters()
            reload()
        }
        .onChange(of: initialBranchName) { _ in
            syncIncomingFilters()
            reload()
        }
        .onChange(of: initialGroupKey) { _ in
            syncIncomingFilters()
            reload()
        }
    }

    private var statsHeroCard: some View {
        let cleanBranch = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanGroup = groupKey.trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(alignment: screenHorizontalAlignment, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                if isEnglish {
                    statsHeroIcon

                    VStack(alignment: .leading, spacing: 5) {
                        Text(tr("סטטיסטיקת נוכחות", "Attendance statistics"))
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(tr("דו״חות אחרונים · שנה אחורה", "Recent reports · Last year"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(red: 0.86, green: 0.94, blue: 1.0))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("\(cleanBranch.isEmpty ? tr("לא נבחר סניף", "No branch selected") : cleanBranch) · \(cleanGroup.isEmpty ? tr("לא נבחרה קבוצה", "No group selected") : cleanGroup)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    statsHeroIcon

                    Spacer()

                    VStack(alignment: .trailing, spacing: 5) {
                        Text(tr("סטטיסטיקת נוכחות", "Attendance statistics"))
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Text(tr("דו״חות אחרונים · שנה אחורה", "Recent reports · Last year"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(red: 0.86, green: 0.94, blue: 1.0))
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Text("\(cleanBranch.isEmpty ? tr("לא נבחר סניף", "No branch selected") : cleanBranch) · \(cleanGroup.isEmpty ? tr("לא נבחרה קבוצה", "No group selected") : cleanGroup)")
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
                    title: tr("ממוצע", "Average"),
                    value: "\(summary.averagePercent)%",
                    tint: Color(red: 0.13, green: 0.83, blue: 0.93)
                )

                statPill(
                    title: tr("דו״חות", "Reports"),
                    value: "\(summary.totalSessions)",
                    tint: Color(red: 0.59, green: 0.70, blue: 1.0)
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

    private var statsHeroIcon: some View {
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
            .frame(width: 54, height: 54)
            .overlay(
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 23, weight: .black))
                    .foregroundStyle(.white)
            )
            .shadow(color: Color.cyan.opacity(0.35), radius: 10, x: 0, y: 4)
    }
    
    private var summaryCard: some View {
        let pct = max(0.0, min(100.0, Double(summary.averagePercent)))

        return VStack(alignment: screenHorizontalAlignment, spacing: 14) {
            HStack {
                if isEnglish {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tr("סיכום קבוצה", "Group summary"))
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(Color(red: 0.07, green: 0.10, blue: 0.16))

                        Text(tr("נתוני שנה אחרונה", "Last year data"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(red: 0.29, green: 0.33, blue: 0.39))
                    }

                    Spacer()

                    Image(systemName: "speedometer")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Color(red: 0.58, green: 0.78, blue: 1.0))
                } else {
                    Image(systemName: "speedometer")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Color(red: 0.58, green: 0.78, blue: 1.0))

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(tr("סיכום קבוצה", "Group summary"))
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(Color(red: 0.07, green: 0.10, blue: 0.16))

                        Text(tr("נתוני שנה אחרונה", "Last year data"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(red: 0.29, green: 0.33, blue: 0.39))
                    }
                }
            }

            VStack(alignment: screenHorizontalAlignment, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    if isEnglish {
                        Text(tr("ממוצע נוכחות", "Average attendance"))
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Color(red: 0.29, green: 0.33, blue: 0.39))

                        Spacer()

                        Text("\(summary.averagePercent)%")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(Color(red: 0.07, green: 0.10, blue: 0.16))
                    } else {
                        Text("\(summary.averagePercent)%")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(Color(red: 0.07, green: 0.10, blue: 0.16))

                        Spacer()

                        Text(tr("ממוצע נוכחות", "Average attendance"))
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Color(red: 0.29, green: 0.33, blue: 0.39))
                    }
                }

                ProgressView(value: pct, total: 100)
                    .progressViewStyle(.linear)
                    .tint(Color(red: 0.13, green: 0.83, blue: 0.93))
                    .background(Color(red: 0.90, green: 0.91, blue: 0.93))
                    .clipShape(Capsule())
            }
            .padding(14)
            .background(Color(red: 0.95, green: 0.96, blue: 0.98))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(red: 0.88, green: 0.90, blue: 0.94), lineWidth: 1)
            )

            HStack(spacing: 10) {
                statPill(title: tr("שיעורים", "Sessions"), value: "\(summary.totalSessions)", tint: Color(red: 0.59, green: 0.70, blue: 1.0))
                statPill(title: tr("ממוצע הגיעו", "Avg. present"), value: "\(summary.averagePresent)", tint: Color(red: 0.13, green: 0.77, blue: 0.37))
                statPill(title: tr("ממוצע סה״כ", "Avg. total"), value: "\(summary.averageTotal)", tint: Color(red: 0.96, green: 0.62, blue: 0.04))
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
    
    private var reportsToolbarCard: some View {
        VStack(alignment: screenHorizontalAlignment, spacing: 12) {
            HStack {
                if isEnglish {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(deleteMode ? tr("בחר דו״חות למחיקה", "Select reports to delete") : tr("דו״חות אחרונים", "Recent reports"))
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(Color(red: 0.07, green: 0.10, blue: 0.16))

                        Text(
                            deleteMode
                            ? (isEnglish ? "\(selectedReportIds.count) reports selected" : "נבחרו \(selectedReportIds.count) דו״חות")
                            : tr("מציג שנה אחורה", "Showing the last year")
                        )
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 0.29, green: 0.33, blue: 0.39))
                    }

                    Spacer()

                    toolbarModeIcon
                } else {
                    toolbarModeIcon

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(deleteMode ? tr("בחר דו״חות למחיקה", "Select reports to delete") : tr("דו״חות אחרונים", "Recent reports"))
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(Color(red: 0.07, green: 0.10, blue: 0.16))

                        Text(
                            deleteMode
                            ? (isEnglish ? "\(selectedReportIds.count) reports selected" : "נבחרו \(selectedReportIds.count) דו״חות")
                            : tr("מציג שנה אחורה", "Showing the last year")
                        )
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 0.29, green: 0.33, blue: 0.39))
                    }
                }
            }

            if deleteMode {
                Text(
                    selectedReportIds.isEmpty
                    ? tr("בחר דו״ח אחד או יותר מהרשימה למטה.", "Select one or more reports from the list below.")
                    : tr("לחיצה על מחיקה תמחק את הדו״חות שנבחרו.", "Tap delete to remove the selected reports.")
                )
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 0.39, green: 0.10, blue: 0.10))
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.white.opacity(0.70))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(red: 0.94, green: 0.27, blue: 0.27).opacity(0.20), lineWidth: 1)
                )
            }

            HStack(spacing: 10) {
                if isEnglish {
                    primaryDeleteToolbarButton
                    secondaryToolbarButton
                } else {
                    secondaryToolbarButton
                    primaryDeleteToolbarButton
                }
            }
        }
        .padding(18)
        .background(deleteMode ? Color(red: 1.0, green: 0.94, blue: 0.94) : Color.white.opacity(0.96))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    deleteMode
                    ? Color(red: 0.94, green: 0.27, blue: 0.27).opacity(0.36)
                    : Color.white.opacity(0.18),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var toolbarModeIcon: some View {
        Image(systemName: deleteMode ? "checklist" : "doc.text.magnifyingglass")
            .font(.system(size: 17, weight: .heavy))
            .foregroundStyle(deleteMode ? Color(red: 0.98, green: 0.45, blue: 0.45) : Color(red: 0.58, green: 0.78, blue: 1.0))
            .frame(width: 38, height: 38)
            .background(Color.white.opacity(0.10))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }

    private var primaryDeleteToolbarButton: some View {
        Button {
            if deleteMode {
                if selectedReportIds.isEmpty {
                    deleteMode = false
                } else {
                    showDeleteConfirm = true
                }
            } else {
                deleteMode = true
                selectedReportIds.removeAll()
            }
        } label: {
            secondaryActionButton(
                icon: deleteMode ? "trash.fill" : "trash",
                title: deleteMode ? tr("מחק נבחרים", "Delete selected") : tr("מחק דו״חות", "Delete reports"),
                tint: deleteMode ? Color(red: 0.94, green: 0.27, blue: 0.27) : Color.white.opacity(0.14)
            )
        }
        .buttonStyle(.plain)
    }

    private var secondaryToolbarButton: some View {
        Group {
            if deleteMode {
                Button {
                    deleteMode = false
                    selectedReportIds.removeAll()
                } label: {
                    secondaryActionButton(
                        icon: "xmark",
                        title: tr("ביטול", "Cancel"),
                        tint: Color.white.opacity(0.14)
                    )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    showResetConfirm = true
                } label: {
                    secondaryActionButton(
                        icon: "arrow.clockwise",
                        title: tr("איפוס", "Reset"),
                        tint: Color(red: 0.94, green: 0.27, blue: 0.27)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var reportsCard: some View {
        VStack(alignment: screenHorizontalAlignment, spacing: 12) {
            HStack {
                if isEnglish {
                    Text(tr("דו״חות שמורים", "Saved reports"))
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(red: 0.07, green: 0.10, blue: 0.16))

                    Spacer()

                    reportsCountLabel
                } else {
                    reportsCountLabel

                    Spacer()

                    Text(tr("דו״חות שמורים", "Saved reports"))
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(red: 0.07, green: 0.10, blue: 0.16))
                }
            }

            if reports.isEmpty {
                emptyReportsState
            } else {
                VStack(spacing: 10) {
                    ForEach(reports) { report in
                        reportRow(report)
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

    private var reportsCountLabel: some View {
        Text(
            isLoadingReports
            ? tr("טוען דו״חות...", "Loading reports...")
            : (
                reports.isEmpty
                ? tr("אין עדיין דו״חות שמורים", "No saved reports yet")
                : (isEnglish ? "Showing \(reports.count) recent reports" : "מציג \(reports.count) דו״חות אחרונים")
            )
        )
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Color(red: 0.29, green: 0.33, blue: 0.39))
    }

    private var emptyReportsState: some View {
        VStack(spacing: 10) {
            if isLoadingReports {
                ProgressView()
                    .tint(.white)
                    .frame(width: 54, height: 54)
            } else {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(Color(red: 0.06, green: 0.45, blue: 0.75))
                    .frame(width: 54, height: 54)
                    .background(Color(red: 0.90, green: 0.95, blue: 1.0))
                    .clipShape(Circle())
            }

            Text(
                isLoadingReports
                ? tr("טוען דו״חות נוכחות...", "Loading attendance reports...")
                : tr("לא נמצאו דו״חות עבור הסניף והקבוצה שנבחרו.", "No reports were found for the selected branch and group.")
            )
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color(red: 0.07, green: 0.10, blue: 0.16))
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)

            if !isLoadingReports {
                Text(tr("לאחר שמירת דו״ח נוכחות במסך הנוכחות, הוא יופיע כאן.", "After saving an attendance report, it will appear here."))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 0.42, green: 0.45, blue: 0.50))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .background(Color(red: 0.95, green: 0.96, blue: 0.98))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(red: 0.88, green: 0.90, blue: 0.94), lineWidth: 1)
        )
    }
    
    private func reportRow(_ report: AttendanceSavedReport) -> some View {
        let isSelected = selectedReportIds.contains(report.id)
        let pct = max(0.0, min(100.0, Double(report.percentPresent)))

        return VStack(alignment: screenHorizontalAlignment, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                if isEnglish {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formattedDate(report.dateIso))
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundStyle(Color(red: 0.07, green: 0.10, blue: 0.16))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(reportSummaryLine(report))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(red: 0.18, green: 0.42, blue: 0.82))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer()

                    if deleteMode {
                        selectionIcon(isSelected: isSelected)
                    }
                } else {
                    if deleteMode {
                        selectionIcon(isSelected: isSelected)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formattedDate(report.dateIso))
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundStyle(Color(red: 0.07, green: 0.10, blue: 0.16))
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Text(reportSummaryLine(report))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(red: 0.18, green: 0.42, blue: 0.82))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }

            ProgressView(value: pct, total: 100)
                .progressViewStyle(.linear)
                .tint(Color(red: 0.13, green: 0.83, blue: 0.93))
                .background(Color(red: 0.86, green: 0.89, blue: 0.94))
                .clipShape(Capsule())

            HStack(spacing: 8) {
                miniStat(title: tr("סה״כ", "Total"), value: "\(report.totalMembers)", tint: Color(red: 0.59, green: 0.70, blue: 1.0))
                miniStat(title: tr("הגיעו", "Present"), value: "\(report.presentCount)", tint: Color(red: 0.13, green: 0.77, blue: 0.37))
                miniStat(title: tr("מוצדק", "Excused"), value: "\(report.excusedCount)", tint: Color(red: 0.96, green: 0.62, blue: 0.04))
                miniStat(title: tr("לא הגיעו", "Absent"), value: "\(report.absentCount)", tint: Color(red: 0.94, green: 0.27, blue: 0.27))
                miniStat(title: tr("לא סומנו", "Unknown"), value: "\(report.unknownCount)", tint: Color.white.opacity(0.65))
            }
        }
        .padding(12)
        .background(
            isSelected
            ? Color(red: 0.88, green: 0.97, blue: 1.0)
            : Color(red: 0.95, green: 0.97, blue: 1.0)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isSelected
                    ? Color(red: 0.13, green: 0.83, blue: 0.93).opacity(0.65)
                    : Color(red: 0.82, green: 0.88, blue: 0.95),
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard deleteMode else { return }

            if isSelected {
                selectedReportIds.remove(report.id)
            } else {
                selectedReportIds.insert(report.id)
            }
        }
    }

    private func selectionIcon(isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 23, weight: .heavy))
            .foregroundStyle(
                isSelected
                ? Color(red: 0.13, green: 0.83, blue: 0.93)
                : Color(red: 0.42, green: 0.45, blue: 0.50)
            )
    }

    private func reportSummaryLine(_ report: AttendanceSavedReport) -> String {
        if isEnglish {
            return "Total \(report.totalMembers) · Present \(report.presentCount) · \(report.percentPresent)%"
        }

        return "סה״כ \(report.totalMembers) · הגיעו \(report.presentCount) · \(report.percentPresent)%"
    }
    
    private func reload() {
        let cleanBranch = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanGroup = groupKey.trimmingCharacters(in: .whitespacesAndNewlines)

        let localReports = repository.reportsLastYear(
            ownerUid: ownerUid,
            branchName: cleanBranch,
            groupKey: cleanGroup
        )

        reports = localReports
        summary = makeSummary(from: localReports)
        selectedReportIds.removeAll()

        loadRemoteReports(
            branchName: cleanBranch,
            groupKey: cleanGroup
        )
    }

    private func loadRemoteReports(
        branchName: String,
        groupKey: String
    ) {
        guard !isLoadingReports else {
            return
        }

        isLoadingReports = true

        let repository = self.repository
        let ownerUid = self.ownerUid
        let startIso = oneYearBackIso()
        let endIsoExclusive = tomorrowIso()

        Task.detached(priority: nil) {
            do {
                let days = try await repository.listReportDaysInRangeFromFirestore(
                    ownerUid: ownerUid,
                    branchName: branchName,
                    groupKey: groupKey,
                    startIso: startIso,
                    endIsoExclusive: endIsoExclusive
                )

                var remoteReports: [AttendanceSavedReport] = []

                for dateIso in days.sorted(by: >) {
                    let records = try await repository.loadRecordsFromFirestore(
                        ownerUid: ownerUid,
                        branchName: branchName,
                        groupKey: groupKey,
                        dateIso: dateIso
                    )

                    guard !records.isEmpty else {
                        continue
                    }

                    remoteReports.append(savedReport(from: records, dateIso: dateIso))
                }

                await MainActor.run {
                    self.reports = mergeReports(
                        local: self.reports,
                        remote: remoteReports
                    )
                    self.summary = makeSummary(from: self.reports)
                    self.isLoadingReports = false
                }
            } catch {
                await MainActor.run {
                    self.summary = makeSummary(from: self.reports)
                    self.isLoadingReports = false
                }
            }
        }
    }

    private func savedReport(
        from records: [AttendanceRecord],
        dateIso: String
    ) -> AttendanceSavedReport {
        let present = records.filter { $0.status == .present }.count
        let excused = records.filter { $0.status == .excused }.count
        let absent = records.filter { $0.status == .absent }.count
        let unknown = records.filter { $0.status == .unknown }.count

        return AttendanceSavedReport(
            id: dateIso,
            dateIso: dateIso,
            totalMembers: records.count,
            presentCount: present,
            excusedCount: excused,
            absentCount: absent,
            unknownCount: unknown
        )
    }

    private func mergeReports(
        local: [AttendanceSavedReport],
        remote: [AttendanceSavedReport]
    ) -> [AttendanceSavedReport] {
        var merged: [String: AttendanceSavedReport] = [:]

        for report in local {
            merged[report.dateIso] = report
        }

        for report in remote {
            merged[report.dateIso] = report
        }

        return merged.values.sorted {
            $0.dateIso > $1.dateIso
        }
    }

    private func makeSummary(from reports: [AttendanceSavedReport]) -> AttendanceGroupStatsSummary {
        guard !reports.isEmpty else {
            return AttendanceGroupStatsSummary(
                averagePercent: 0,
                totalSessions: 0,
                averagePresent: 0,
                averageTotal: 0
            )
        }

        let averagePercent = Int(
            (Double(reports.map { $0.percentPresent }.reduce(0, +)) / Double(reports.count))
                .rounded()
        )

        let averagePresent = Int(
            (Double(reports.map { $0.presentCount }.reduce(0, +)) / Double(reports.count))
                .rounded()
        )

        let averageTotal = Int(
            (Double(reports.map { $0.totalMembers }.reduce(0, +)) / Double(reports.count))
                .rounded()
        )

        return AttendanceGroupStatsSummary(
            averagePercent: averagePercent,
            totalSessions: reports.count,
            averagePresent: averagePresent,
            averageTotal: averageTotal
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

    private func deleteSelectedReports() {
        guard !selectedReportIds.isEmpty else {
            deleteMode = false
            showDeleteConfirm = false
            return
        }

        let cleanBranch = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanGroup = groupKey.trimmingCharacters(in: .whitespacesAndNewlines)

        let reportsToDelete = reports.filter { selectedReportIds.contains($0.id) }

        for report in reportsToDelete {
            repository.deleteReport(
                ownerUid: ownerUid,
                branchName: cleanBranch,
                groupKey: cleanGroup,
                dateIso: report.dateIso
            )
        }

        selectedReportIds.removeAll()
        deleteMode = false
        showDeleteConfirm = false

        reload()
    }

    private func resetAllReports() {
        let cleanBranch = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanGroup = groupKey.trimmingCharacters(in: .whitespacesAndNewlines)

        for report in reports {
            repository.deleteReport(
                ownerUid: ownerUid,
                branchName: cleanBranch,
                groupKey: cleanGroup,
                dateIso: report.dateIso
            )
        }

        selectedReportIds.removeAll()
        deleteMode = false
        showDeleteConfirm = false
        showResetConfirm = false

        reload()
    }

    private func syncIncomingFilters() {
        let cleanInitialBranch = initialBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanInitialGroup = initialGroupKey.trimmingCharacters(in: .whitespacesAndNewlines)

        let cleanCurrentBranch = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCurrentGroup = groupKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleanInitialBranch.isEmpty && cleanInitialBranch != cleanCurrentBranch {
            branchName = initialBranchName
        }

        if !cleanInitialGroup.isEmpty && cleanInitialGroup != cleanCurrentGroup {
            groupKey = initialGroupKey
        }
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

    private func miniStat(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.07, green: 0.10, blue: 0.16))

            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color(red: 0.42, green: 0.45, blue: 0.50))
                .lineLimit(1)
                .minimumScaleFactor(0.70)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(tint.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(tint.opacity(0.26), lineWidth: 1)
        )
    }

    private func secondaryActionButton(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 14, weight: .heavy))
        .foregroundStyle(
            tint == Color.white.opacity(0.14)
            ? Color(red: 0.07, green: 0.10, blue: 0.16)
            : Color.white
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            tint == Color.white.opacity(0.14)
            ? Color(red: 0.91, green: 0.94, blue: 0.98)
            : tint.opacity(0.42)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    tint == Color.white.opacity(0.14)
                    ? Color(red: 0.82, green: 0.86, blue: 0.92)
                    : tint.opacity(0.28),
                    lineWidth: 1
                )
        )
    }

    private func formattedDate(_ iso: String) -> String {
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd"

        let output = DateFormatter()
        output.locale = isEnglish ? Locale(identifier: "en_US") : Locale(identifier: "he_IL")
        output.dateFormat = isEnglish ? "EEEE, MMM d, yyyy" : "EEEE, d MMM yyyy"

        guard let date = input.date(from: iso) else { return iso }
        return output.string(from: date)
    }
}
