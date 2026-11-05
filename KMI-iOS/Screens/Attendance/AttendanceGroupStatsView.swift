import SwiftUI

@MainActor
struct AttendanceGroupStatsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("kmi_app_language") private var appLanguageCode = "he"
    @State private var reportsTask: Task<Void, Never>?
    @State private var deletionTask: Task<Void, Never>?
    @State private var isDeletingReports = false
    @State private var showDeleteError = false
    @State private var requestID = UUID()
    @State private var didFailLoading = false
    @State private var expandedMonths: Set<String> = []

    private var surface: Color { KmiAppTheme.surface(for: colorScheme) }
    private var secondarySurface: Color { KmiAppTheme.surfaceVariant(for: colorScheme) }
    private var titleColor: Color { KmiAppTheme.onSurface(for: colorScheme) }
    private var secondaryTextColor: Color { KmiAppTheme.onSurfaceVariant(for: colorScheme) }
    private var borderColor: Color { KmiAppTheme.outlineVariant(for: colorScheme) }
    private var accent: Color { KmiAppTheme.secondary(for: colorScheme) }

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
            appLanguageCode,
            defaults.string(forKey: "selected_language_code"),
            defaults.string(forKey: "app_language"),
            defaults.string(forKey: "initial_language_code")
        ]
        for value in values.compactMap({ $0 }) {
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "en", "english": return true
            case "he", "hebrew", "עברית": return false
            default: continue
            }
        }
        return false
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
        repository: AttendanceRepository? = nil
    ) {
        self.ownerUid = ownerUid
        self.initialBranchName = initialBranchName
        self.initialGroupKey = initialGroupKey
        self.repository = repository ?? .shared
        _branchName = State(initialValue: initialBranchName)
        _groupKey = State(initialValue: initialGroupKey)
    }
    var body: some View {
        ZStack {
            KmiAppBackground()
            ScrollView {
                VStack(spacing: 12) {
                    statsHeroCard
                        .environment(\.layoutDirection, .leftToRight)
                    summaryCard
                        .environment(\.layoutDirection, .leftToRight)
                    reportsToolbarCard
                        .environment(\.layoutDirection, .leftToRight)
                        .disabled(isLoadingReports || isDeletingReports || didFailLoading || reports.isEmpty)
                    if didFailLoading {
                        loadingErrorCard
                            .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
                    }
                    reportsCard
                        .disabled(isDeletingReports)
                        .environment(\.layoutDirection, .leftToRight)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 24)
                .safeAreaPadding(.bottom, 12)
            }
        }
        .overlay {
            if isLoadingReports || isDeletingReports {
                KmiLoadingOverlay()
            }
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
        .multilineTextAlignment(screenTextAlignment)
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
        .alert(
            tr("מחיקת הדו״חות לא הושלמה", "Report deletion was not completed"),
            isPresented: $showDeleteError
        ) {
            Button(tr("אישור", "OK"), role: .cancel) { }
        } message: {
            Text(tr(
                "ייתכן שחלק מהדו״חות נמחקו. הרשימה נטענת מחדש; בדוק אותה לפני ניסיון נוסף.",
                "Some reports may have been deleted. The list is being refreshed; review it before trying again."
            ))
        }
        .onAppear {
            syncIncomingFilters()
            reload()
        }
        .onDisappear {
            deletionTask?.cancel()
            isDeletingReports = false
            reportsTask?.cancel()
            requestID = UUID()
            isLoadingReports = false
        }
        .onChange(of: ownerUid) { _, _ in
            syncIncomingFilters()
            reload()
        }
        .onChange(of: initialBranchName) { _, _ in
            syncIncomingFilters()
            reload()
        }
        .onChange(of: initialGroupKey) { _, _ in
            syncIncomingFilters()
            reload()
        }
    }
    private var statsHeroCard: some View {
        VStack(alignment: screenHorizontalAlignment, spacing: 8) {
            Text(tr("סטטיסטיקת נוכחות", "Attendance statistics"))
                .kmiTypography(.sectionTitle)
                .foregroundStyle(titleColor)
            Text("\(branchName.isEmpty ? tr("לא נבחר סניף", "No branch selected") : branchName) · \(groupKey.isEmpty ? tr("לא נבחרה קבוצה", "No group selected") : groupKey)")
                .kmiTypography(.secondary)
                .foregroundStyle(secondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
            Text(tr("דו״חות אחרונים · שנה אחורה", "Recent reports · Last year"))
                .kmiTypography(.caption)
                .foregroundStyle(secondaryTextColor)
        }
        .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
        .padding(14)
        .background(surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(borderColor, lineWidth: 1))
    }

    private var summaryCard: some View {
        let pct = max(0.0, min(100.0, Double(summary.averagePercent)))
        return VStack(alignment: screenHorizontalAlignment, spacing: 14) {
            HStack {
                if isEnglish {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tr("סיכום קבוצה", "Group summary"))
                            .kmiFont(size: 18, weight: .heavy)
                            .foregroundStyle(titleColor)
                        Text(tr("נתוני שנה אחרונה", "Last year data"))
                            .kmiFont(size: 12, weight: .semibold)
                            .foregroundStyle(secondaryTextColor)
                    }
                    Spacer()
                    Image(systemName: "speedometer")
                        .kmiIconSize(17)
                        .foregroundStyle(accent)
                } else {
                    Image(systemName: "speedometer")
                        .kmiIconSize(17)
                        .foregroundStyle(accent)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(tr("סיכום קבוצה", "Group summary"))
                            .kmiFont(size: 18, weight: .heavy)
                            .foregroundStyle(titleColor)
                        Text(tr("נתוני שנה אחרונה", "Last year data"))
                            .kmiFont(size: 12, weight: .semibold)
                            .foregroundStyle(secondaryTextColor)
                    }
                }
            }
            VStack(alignment: screenHorizontalAlignment, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    if isEnglish {
                        Text(tr("ממוצע נוכחות", "Average attendance"))
                            .kmiFont(size: 13, weight: .heavy)
                            .foregroundStyle(secondaryTextColor)
                        Spacer()
                        Text("\(summary.averagePercent)%")
                            .kmiFont(size: 28, weight: .black, design: .rounded)
                            .foregroundStyle(titleColor)
                    } else {
                        Text("\(summary.averagePercent)%")
                            .kmiFont(size: 28, weight: .black, design: .rounded)
                            .foregroundStyle(titleColor)
                        Spacer()
                        Text(tr("ממוצע נוכחות", "Average attendance"))
                            .kmiFont(size: 13, weight: .heavy)
                            .foregroundStyle(secondaryTextColor)
                    }
                }
                ProgressView(value: pct, total: 100)
                    .progressViewStyle(.linear)
                    .tint(accent)
                    .background(borderColor)
                    .clipShape(Capsule())
            }
            .padding(14)
            .background(secondarySurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            HStack(spacing: 10) {
                statPill(title: tr("שיעורים", "Sessions"), value: "\(summary.totalSessions)", tint: Color(red: 0.59, green: 0.70, blue: 1.0))
                statPill(title: tr("ממוצע הגיעו", "Avg. present"), value: "\(summary.averagePresent)", tint: Color(red: 0.13, green: 0.77, blue: 0.37))
                statPill(title: tr("ממוצע סה״כ", "Avg. total"), value: "\(summary.averageTotal)", tint: Color(red: 0.96, green: 0.62, blue: 0.04))
            }
        }
        .padding(18)
        .background(surface)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    private var reportsToolbarCard: some View {
        VStack(alignment: screenHorizontalAlignment, spacing: 12) {
            HStack {
                if isEnglish {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(deleteMode ? tr("בחר דו״חות למחיקה", "Select reports to delete") : tr("דו״חות אחרונים", "Recent reports"))
                            .kmiFont(size: 18, weight: .heavy)
                            .foregroundStyle(titleColor)
                        Text(
                            deleteMode
                            ? (isEnglish ? "\(selectedReportIds.count) reports selected" : "נבחרו \(selectedReportIds.count) דו״חות")
                            : tr("מציג שנה אחורה", "Showing the last year")
                        )
                        .kmiFont(size: 12, weight: .semibold)
                        .foregroundStyle(secondaryTextColor)
                    }
                    Spacer()
                    toolbarModeIcon
                } else {
                    toolbarModeIcon
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(deleteMode ? tr("בחר דו״חות למחיקה", "Select reports to delete") : tr("דו״חות אחרונים", "Recent reports"))
                            .kmiFont(size: 18, weight: .heavy)
                            .foregroundStyle(titleColor)
                        Text(
                            deleteMode
                            ? (isEnglish ? "\(selectedReportIds.count) reports selected" : "נבחרו \(selectedReportIds.count) דו״חות")
                            : tr("מציג שנה אחורה", "Showing the last year")
                        )
                        .kmiFont(size: 12, weight: .semibold)
                        .foregroundStyle(secondaryTextColor)
                    }
                }
            }
            if deleteMode {
                Text(
                    selectedReportIds.isEmpty
                    ? tr("בחר דו״ח אחד או יותר מהרשימה למטה.", "Select one or more reports from the list below.")
                    : tr("לחיצה על מחיקה תמחק את הדו״חות שנבחרו.", "Tap delete to remove the selected reports.")
                )
                .kmiFont(size: 12, weight: .semibold)
                .foregroundStyle(KmiAppTheme.error(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(surface)
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
        .background(deleteMode ? KmiAppTheme.errorContainer(for: colorScheme) : surface)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    deleteMode
                    ? Color(red: 0.94, green: 0.27, blue: 0.27).opacity(0.36)
                    : borderColor,
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    private var toolbarModeIcon: some View {
        Image(systemName: deleteMode ? "checklist" : "doc.text.magnifyingglass")
            .kmiIconSize(17)
            .foregroundStyle(deleteMode ? Color(red: 0.98, green: 0.45, blue: 0.45) : accent)
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
                        .kmiFont(size: 18, weight: .heavy)
                        .foregroundStyle(titleColor)
                    Spacer()
                    reportsCountLabel
                } else {
                    reportsCountLabel
                    Spacer()
                    Text(tr("דו״חות שמורים", "Saved reports"))
                        .kmiFont(size: 18, weight: .heavy)
                        .foregroundStyle(titleColor)
                }
            }
            if reports.isEmpty {
                if !didFailLoading { emptyReportsState }
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(reportMonths, id: \.self) { month in
                        monthSection(month)
                    }
                }
            }
        }
        .padding(18)
        .background(surface)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    private var loadingErrorCard: some View {
        VStack(spacing: 10) {
            Text(tr("טעינת הדו״חות לא הושלמה", "Reports could not be loaded"))
                .kmiTypography(.cardTitle)
            Text(reports.isEmpty
                 ? tr("נסה שוב כדי לטעון את נתוני הקבוצה.", "Try again to load the group data.")
                 : tr("מוצגים נתונים זמינים. נסה שוב לעדכון.", "Showing available data. Try again to refresh."))
                .kmiTypography(.secondary)
            Button(tr("נסה שוב", "Try again")) { reload() }
                .kmiTypography(.action)
                .foregroundStyle(accent)
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(titleColor)
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(borderColor, lineWidth: 1))
    }

    private var reportMonths: [String] {
        Array(Set(reports.map { String($0.dateIso.prefix(7)) })).sorted(by: >)
    }

    private func monthSection(_ month: String) -> some View {
        let monthReports = reports.filter { String($0.dateIso.prefix(7)) == month }
        let isExpanded = expandedMonths.contains(month)
        return VStack(spacing: 10) {
            Button {
                if isExpanded { expandedMonths.remove(month) }
                else { expandedMonths.insert(month) }
            } label: {
                HStack {
                    if !isEnglish {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .kmiIconSize(22)
                    }
                    VStack(alignment: screenHorizontalAlignment, spacing: 4) {
                        Text(monthTitle(month))
                            .kmiTypography(.cardTitle)
                            .foregroundStyle(titleColor)
                        Text(isEnglish ? "\(monthReports.count) reports" : "\(monthReports.count) דו״חות")
                            .kmiTypography(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                    if isEnglish {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .kmiIconSize(22)
                    }
                }
                .foregroundStyle(accent)
                .padding(12)
                .background(secondarySurface, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(borderColor, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isExpanded ? tr("פתוח", "Expanded") : tr("סגור", "Collapsed"))
            if isExpanded {
                ForEach(monthReports) { report in
                    reportRow(report)
                }
            }
        }
    }

    private func monthTitle(_ month: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = ShabbatHolidayCheckerIOS.calendar
        formatter.timeZone = ShabbatHolidayCheckerIOS.calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: "\(month)-01") else { return month }
        formatter.locale = Locale(identifier: isEnglish ? "en_US" : "he_IL")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private var reportsCountLabel: some View {
        Text(
            isLoadingReports
            ? tr("טוען דו״חות...", "Loading reports...")
            : (
                didFailLoading
                ? tr("הנתונים לא עודכנו", "Data could not be refreshed")
                : reports.isEmpty
                ? tr("אין עדיין דו״חות שמורים", "No saved reports yet")
                : (isEnglish ? "Showing \(reports.count) recent reports" : "מציג \(reports.count) דו״חות אחרונים")
            )
        )
        .kmiFont(size: 12, weight: .semibold)
        .foregroundStyle(secondaryTextColor)
    }
    private var emptyReportsState: some View {
        VStack(spacing: 10) {
            if isLoadingReports {
                Color.clear
                    .frame(height: 24)
            } else {
                Image(systemName: "doc.text.magnifyingglass")
                    .kmiIconSize(28)
                    .foregroundStyle(accent)
                    .frame(width: 54, height: 54)
                    .background(secondarySurface)
                    .clipShape(Circle())
            }
            Text(
                isLoadingReports
                ? tr("טוען דו״חות נוכחות...", "Loading attendance reports...")
                : tr("לא נמצאו דו״חות עבור הסניף והקבוצה שנבחרו.", "No reports were found for the selected branch and group.")
            )
            .kmiFont(size: 14, weight: .bold)
            .foregroundStyle(titleColor)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            if !isLoadingReports {
                Text(tr("לאחר שמירת דו״ח נוכחות במסך הנוכחות, הוא יופיע כאן.", "After saving an attendance report, it will appear here."))
                    .kmiFont(size: 12, weight: .semibold)
                    .foregroundStyle(secondaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .background(secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
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
                            .kmiFont(size: 17, weight: .heavy)
                            .foregroundStyle(titleColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(reportSummaryLine(report))
                            .kmiFont(size: 12, weight: .bold)
                            .foregroundStyle(accent)
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
                            .kmiFont(size: 17, weight: .heavy)
                            .foregroundStyle(titleColor)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        Text(reportSummaryLine(report))
                            .kmiFont(size: 12, weight: .bold)
                            .foregroundStyle(accent)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            ProgressView(value: pct, total: 100)
                .progressViewStyle(.linear)
                .tint(accent)
                .background(borderColor)
                .clipShape(Capsule())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                miniStat(title: tr("סה״כ", "Total"), value: "\(report.totalMembers)", tint: Color(red: 0.59, green: 0.70, blue: 1.0))
                miniStat(title: tr("הגיעו", "Present"), value: "\(report.presentCount)", tint: Color(red: 0.13, green: 0.77, blue: 0.37))
                miniStat(title: tr("מוצדק", "Excused"), value: "\(report.excusedCount)", tint: Color(red: 0.96, green: 0.62, blue: 0.04))
                miniStat(title: tr("לא הגיעו", "Absent"), value: "\(report.absentCount)", tint: Color(red: 0.94, green: 0.27, blue: 0.27))
                miniStat(title: tr("לא סומנו", "Unknown"), value: "\(report.unknownCount)", tint: secondaryTextColor)
            }
        }
        .padding(12)
        .background(
            isSelected
            ? KmiAppTheme.secondaryContainer(for: colorScheme)
            : secondarySurface
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isSelected
                    ? accent.opacity(0.65)
                    : borderColor,
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
            .kmiIconSize(23)
            .foregroundStyle(
                isSelected
                ? accent
                : secondaryTextColor
            )
    }
    private func reportSummaryLine(_ report: AttendanceSavedReport) -> String {
        if isEnglish {
            return "Total \(report.totalMembers) · Present \(report.presentCount) · \(report.percentPresent)%"
        }
        return "סה״כ \(report.totalMembers) · הגיעו \(report.presentCount) · \(report.percentPresent)%"
    }
    private func reload() {
        deletionTask?.cancel()
        isDeletingReports = false
        reportsTask?.cancel()
        let currentRequest = UUID()
        requestID = currentRequest
        let cleanBranch = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanGroup = groupKey.trimmingCharacters(in: .whitespacesAndNewlines)
        selectedReportIds.removeAll()
        expandedMonths.removeAll()
        deleteMode = false
        showDeleteConfirm = false
        showResetConfirm = false
        didFailLoading = false
        isLoadingReports = false
        guard !ownerUid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !cleanBranch.isEmpty, !cleanGroup.isEmpty else {
            reports = []
            summary = makeSummary(from: [])
            return
        }
        let localReports = repository.reportsLastYear(
            ownerUid: ownerUid,
            branchName: cleanBranch,
            groupKey: cleanGroup
        )
        reports = localReports
        summary = makeSummary(from: localReports)
        isLoadingReports = true
        let requestOwner = ownerUid
        let startIso = oneYearBackIso()
        let endIsoExclusive = tomorrowIso()
        reportsTask = Task { @MainActor in
            do {
                let days = try await repository.listReportDaysInRangeFromFirestore(
                    ownerUid: requestOwner,
                    branchName: cleanBranch,
                    groupKey: cleanGroup,
                    startIso: startIso,
                    endIsoExclusive: endIsoExclusive
                )
                var remoteReports: [AttendanceSavedReport] = []
                for dateIso in days.sorted(by: >) {
                    try Task.checkCancellation()
                    let records = try await repository.loadRecordsFromFirestore(
                        ownerUid: requestOwner,
                        branchName: cleanBranch,
                        groupKey: cleanGroup,
                        dateIso: dateIso
                    )
                    guard !records.isEmpty else {
                        continue
                    }
                    remoteReports.append(savedReport(from: records, dateIso: dateIso))
                }
                try Task.checkCancellation()
                guard requestID == currentRequest else { return }
                // A successful query defines which saved reports still exist.
                // Do not resurrect remotely deleted reports from the local cache.
                reports = mergeReports(
                    local: localReports.filter { days.contains($0.dateIso) },
                    remote: remoteReports
                )
                summary = makeSummary(from: reports)
                isLoadingReports = false
            } catch {
                guard requestID == currentRequest, !Task.isCancelled else { return }
                didFailLoading = true
                isLoadingReports = false
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
        )
        let averagePresent = Int(
            (Double(reports.map { $0.presentCount }.reduce(0, +)) / Double(reports.count))
        )
        let averageTotal = Int(
            (Double(reports.map { $0.totalMembers }.reduce(0, +)) / Double(reports.count))
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
        let yearBack = ShabbatHolidayCheckerIOS.calendar.date(byAdding: .year, value: -1, to: today) ?? today
        return isoString(yearBack)
    }
    private func tomorrowIso() -> String {
        let today = Date()
        let tomorrow = ShabbatHolidayCheckerIOS.calendar.date(byAdding: .day, value: 1, to: today) ?? today
        return isoString(tomorrow)
    }
    private func isoString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = ShabbatHolidayCheckerIOS.calendar
        formatter.timeZone = ShabbatHolidayCheckerIOS.calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    private func deleteSelectedReports() {
        guard !isLoadingReports, !isDeletingReports, !didFailLoading else { return }
        let dates = reports
            .filter { selectedReportIds.contains($0.id) }
            .map { $0.dateIso }
        guard !dates.isEmpty else {
            deleteMode = false
            showDeleteConfirm = false
            return
        }

        let requestOwner = ownerUid
        let requestBranch = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestGroup = groupKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let deletionRequest = requestID
        let deletedDates = Set(dates)
        showDeleteConfirm = false
        showDeleteError = false
        isDeletingReports = true

        deletionTask = Task { @MainActor in
            do {
                try await repository.deleteSavedReportsFromFirestore(
                    ownerUid: requestOwner,
                    branchName: requestBranch,
                    groupKey: requestGroup,
                    dateIsos: dates
                )
                try Task.checkCancellation()
                guard requestID == deletionRequest else { return }

                // Update visible totals only after Firestore confirms deletion.
                reports.removeAll { deletedDates.contains($0.dateIso) }
                summary = makeSummary(from: reports)
                selectedReportIds.removeAll()
                deleteMode = false
                isDeletingReports = false
                deletionTask = nil
                reload()
            } catch {
                guard requestID == deletionRequest, !Task.isCancelled else { return }
                isDeletingReports = false
                deletionTask = nil
                reload()
                showDeleteError = true
            }
        }
    }
    private func resetAllReports() {
        guard !isLoadingReports, !isDeletingReports, !didFailLoading else { return }
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
        branchName = initialBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
        groupKey = initialGroupKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private func statPill(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .kmiFont(size: 18, weight: .black, design: .rounded)
                .foregroundStyle(titleColor)
            Text(title)
                .kmiFont(size: 11, weight: .bold)
                .foregroundStyle(secondaryTextColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
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
                .kmiFont(size: 13, weight: .black, design: .rounded)
                .foregroundStyle(titleColor)
            Text(title)
                .kmiTypography(.caption)
                .foregroundStyle(secondaryTextColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
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
                .kmiIconSize(18)
            Text(title)
        }
        .kmiFont(size: 14, weight: .heavy)
        .foregroundStyle(
            tint == Color.white.opacity(0.14)
            ? titleColor
            : Color.white
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            tint == Color.white.opacity(0.14)
            ? secondarySurface
            : tint
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    tint == Color.white.opacity(0.14)
                    ? borderColor
                    : tint.opacity(0.28),
                    lineWidth: 1
                )
        )
    }
    private func formattedDate(_ iso: String) -> String {
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.calendar = ShabbatHolidayCheckerIOS.calendar
        input.timeZone = ShabbatHolidayCheckerIOS.calendar.timeZone
        input.dateFormat = "yyyy-MM-dd"
        let output = DateFormatter()
        output.calendar = ShabbatHolidayCheckerIOS.calendar
        output.timeZone = ShabbatHolidayCheckerIOS.calendar.timeZone
        output.locale = isEnglish ? Locale(identifier: "en_US") : Locale(identifier: "he_IL")
        output.dateFormat = isEnglish ? "EEEE, MMM d, yyyy" : "EEEE, d MMM yyyy"
        guard let date = input.date(from: iso) else { return iso }
        return output.string(from: date)
    }
}
