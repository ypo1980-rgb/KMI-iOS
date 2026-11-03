import SwiftUI
import FirebaseAuth
import UIKit

struct AttendanceView: View {

    @EnvironmentObject
    private var auth: AuthViewModel

    @StateObject
    private var vm: AttendanceViewModel

    @ObservedObject
    private var demoPrivacy =
        DemoPrivacy.shared

    @State
    private var toastMessage: String?
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

    @State private var showDatePickerSheet = false
    @State private var draftAttendanceDate = Date()

    @State private var newMemberName: String = ""
    @State private var newMemberPhone: String = ""
    @State private var newMemberNotes: String = ""
    @State
    private var isAddMemberExpanded: Bool = false

    @State
    private var isEditingSavedReport: Bool = false

    @State private var reportSavedInCurrentContext = false
    @State private var attendanceContextToken = UUID()
    @State private var isAddingMember = false
    @State private var isClassSelectionExpanded = false

    @State
    private var pendingDeleteRow: AttendanceRowUi?

    private let onHomeTap: () -> Void
    private let onSearchTap: () -> Void
    private let onSettingsTap: () -> Void
    private let onAssistantTap: () -> Void
    private let showsInternalTopStrip: Bool

    @AppStorage("kmi_app_language")
    private var appLanguageCode: String = ""

    @AppStorage("selected_language_code")
    private var selectedLanguageCode: String = ""

    @AppStorage("app_language")
    private var appLanguageRaw: String = ""

    @AppStorage("initial_language_code")
    private var initialLanguageCode: String = ""

    @AppStorage("initial_language_selected_code")
    private var initialLanguageSelectedCode: String = ""

    @AppStorage("kmi.language.code")
    private var legacyLanguageCode: String = ""

    private var isEnglish: Bool {
        let values = [
            appLanguageCode,
            selectedLanguageCode,
            appLanguageRaw,
            initialLanguageCode,
            initialLanguageSelectedCode,
            legacyLanguageCode
        ]

        for rawValue in values {
            let value = rawValue
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            if value == "en" || value == "english" {
                return true
            }

            if value == "he" || value == "hebrew" || value == "עברית" {
                return false
            }
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

    @Environment(\.colorScheme)
    private var colorScheme

    private var isDarkMode: Bool {

        colorScheme == .dark
    }

    private var hasSelectedAttendanceContext: Bool {
        !vm.state.ownerUid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !vm.state.branchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !vm.state.groupKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isAttendanceReportSaved: Bool {
        vm.isReportSaved || reportSavedInCurrentContext
    }

    private var isAttendanceContextReady: Bool {
        hasSelectedAttendanceContext &&
        !vm.state.isSaving &&
        !vm.isContextLoading &&
        !vm.contextLoadFailed &&
        !isAddingMember
    }

    private var canEditAttendance: Bool {
        isAttendanceContextReady &&
        (!isAttendanceReportSaved || isEditingSavedReport)
    }

    private var primaryTextColor: Color {

        KmiAppTheme.onSurface(
            for: colorScheme
        )
    }

    private var secondaryTextColor: Color {
        KmiAppTheme.onSurfaceVariant(
            for: colorScheme
        )
    }

    private var cardSurfaceColor: Color {
        KmiAppTheme.surface(
            for: colorScheme
        )
        .opacity(0.96)
    }

    private var elevatedSurfaceColor: Color {
        KmiAppTheme.surfaceVariant(
            for: colorScheme
        )
    }

    private var cardBorderColor: Color {
        KmiAppTheme.outlineVariant(
            for: colorScheme
        )
    }

    private var fieldSurfaceColor: Color {
        KmiAppTheme.surfaceVariant(
            for: colorScheme
        )
        .opacity(
            colorScheme == .dark
                ? 0.82
                : 0.92
        )
    }

    private var fieldIconSurfaceColor: Color {
        KmiAppTheme.secondaryContainer(
            for: colorScheme
        )
    }

    private var fieldIconColor: Color {
        KmiAppTheme.onSecondaryContainer(
            for: colorScheme
        )
    }

    private func tr(
        _ he: String,
        _ en: String
    ) -> String {
        isEnglish ? en : he
    }

    init(
        ownerUid: String,
        initialDateIso: String? = nil,
        initialBranchName: String = "",
        initialGroupKey: String = "",
        initialCoachName: String = "",
        showsInternalTopStrip: Bool = false,
        onHomeTap: @escaping () -> Void = {},
        onSearchTap: @escaping () -> Void = {},
        onSettingsTap: @escaping () -> Void = {},
        onAssistantTap: @escaping () -> Void = {}
    ) {
        self.showsInternalTopStrip = showsInternalTopStrip
        self.onHomeTap = onHomeTap
        self.onSearchTap = onSearchTap
        self.onSettingsTap = onSettingsTap
        self.onAssistantTap = onAssistantTap

        _vm = StateObject(
            wrappedValue: AttendanceViewModel(
                ownerUid: ownerUid,
                initialDateIso: initialDateIso,
                initialBranchName: initialBranchName,
                initialGroupKey: initialGroupKey,
                initialCoachName: initialCoachName
            )
        )
    }

    var body: some View {

        ZStack {

            KmiAppBackground()

            VStack(spacing: 0) {
                attendanceModeTabs

                ScrollView {
                VStack(spacing: 8) {
                    attendanceHeroCard

                    if vm.contextLoadFailed {
                        attendanceLoadFailureCard
                    }

                    attendanceSummaryCard

                    if isAddMemberExpanded &&
                        !isAttendanceReportSaved {

                        addMemberCard
                    }

                    Text(
                        tr(
                            "סימון נוכחות למתאמנים",
                            "Mark trainee attendance"
                        )
                    )
                    .kmiFont(
                        size: 18,
                        weight: .heavy
                    )
                    .foregroundStyle(primaryTextColor)
                    .frame(
                        maxWidth: .infinity,
                        alignment: screenFrameAlignment
                    )
                    .multilineTextAlignment(screenTextAlignment)
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)
                    .padding(.horizontal, 2)
                    .padding(.top, 2)

                    membersCard

                    actionsCard
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 104)
            }
            .scrollDismissesKeyboard(.interactively)
            .disabled(vm.state.isSaving)
            }

            if !isAttendanceReportSaved && hasSelectedAttendanceContext {

                VStack {

                    Spacer()

                    HStack {
                        addMemberFloatingButton
                        Spacer(minLength: 0)
                    }
                    .environment(\.layoutDirection, .leftToRight)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }

            if vm.state.isSaving || vm.isContextLoading || isAddingMember {

                KmiLoadingOverlay()
                    .transition(.opacity)
                    .zIndex(100)
            }

            if let toastMessage {

                VStack {

                    Spacer()

                    Text(toastMessage)
                        .kmiFont(
                            size: 14,
                            weight: .bold
                        )
                        .foregroundStyle(primaryTextColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.74)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 24)
                }
                .transition(.opacity)
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name(
                    "KMI_GLOBAL_SHARE_REQUEST"
                )
            )
        ) { notification in
            guard let request =
                notification.object as? NSMutableDictionary,
                  request["handled"] as? Bool != true
            else {
                return
            }

            request["handled"] = true
            shareReport()
        }
        .sheet(
            isPresented: $showShareSheet,
            onDismiss: { shareItems.removeAll() }
        ) {
            AttendanceShareSheet(items: shareItems)
        }
        .sheet(isPresented: $showDatePickerSheet) {
            AttendancePremiumDatePickerSheet(
                selectedDate: $draftAttendanceDate,
                isEnglish: isEnglish,
                onCancel: {
                    showDatePickerSheet = false
                },
                onToday: {
                    guard !vm.state.isSaving,
                          !isAddingMember else { return }

                    draftAttendanceDate = Date()
                    vm.setDateIso(isoString(from: Date()))
                    showDatePickerSheet = false
                },
                onConfirm: {
                    guard !vm.state.isSaving,
                          !isAddingMember else { return }

                    vm.setDateIso(isoString(from: draftAttendanceDate))
                    showDatePickerSheet = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            tr("מחיקת מתאמן", "Delete trainee"),
            isPresented: Binding(
                get: { pendingDeleteRow != nil },
                set: { newValue in
                    if !newValue {
                        pendingDeleteRow = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(tr("מחק מתאמן", "Delete trainee"), role: .destructive) {
                guard canEditAttendance,
                      let row = pendingDeleteRow,
                      vm.state.rows.contains(where: {
                          $0.memberId == row.memberId
                      }) else {
                    pendingDeleteRow = nil
                    return
                }

                vm.removeMember(memberId: row.memberId)
                pendingDeleteRow = nil
            }

            Button(tr("ביטול", "Cancel"), role: .cancel) {
                pendingDeleteRow = nil
            }
        } message: {

            Text(
                isEnglish
                    ? "Delete \(displayName(for: pendingDeleteRow)) from the list?"
                    : "האם למחוק את \(displayName(for: pendingDeleteRow)) מהרשימה?"
            )
        }

        .onChange(
            of: vm.state.messageEventId
        ) { _, _ in

            guard let msg =
                vm.state.lastMessage
            else {
                return
            }

            let messageEventId = vm.state.messageEventId

            withAnimation {
                toastMessage = msg
            }

            DispatchQueue.main.asyncAfter(
                deadline: .now() + 2
            ) {
                /*
                 * טיימר של הודעה קודמת אינו
                 * מסתיר הודעה חדשה יותר.
                 */
                guard vm.state.messageEventId == messageEventId,
                      toastMessage == msg else {
                    return
                }

                withAnimation {
                    toastMessage = nil
                }
            }
        }

        .onChange(
            of: vm.state.dateIso
        ) { oldValue, newValue in
            resetAttendanceEditingState()

            let oldMonth = dateComponents(from: oldValue)
            let newMonth = dateComponents(from: newValue)

            if oldMonth.year != newMonth.year || oldMonth.month != newMonth.month,
               let year = newMonth.year,
               let month = newMonth.month {
                vm.loadSummaryDaysForMonth(
                    year: year,
                    month1to12: month
                )
            }
        }
        .onChange(
            of: vm.state.branchName
        ) { _, _ in
            resetAttendanceEditingState()
        }
        .onChange(
            of: vm.state.groupKey
        ) { _, _ in
            resetAttendanceEditingState()
        }

        .onAppear {
            isClassSelectionExpanded = false
            refreshAssignedAttendanceBranches()

            let resolvedCoachName =
                auth.userFullName.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            if vm.state.coachName
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty,
               !resolvedCoachName.isEmpty {
                vm.setCoachName(resolvedCoachName)
            }

            let comps = dateComponents(
                from: vm.state.dateIso
            )

            if let year = comps.year,
               let month = comps.month {
                vm.loadSummaryDaysForMonth(
                    year: year,
                    month1to12: month
                )
            }
        }
        .onChange(
            of: auth.userBranchAssignments
        ) { _, _ in
            refreshAssignedAttendanceBranches()
        }
        .onChange(of: auth.userBranch) { _, _ in
            refreshAssignedAttendanceBranches()
        }
        
        .onChange(of: auth.userFullName) { _, newValue in
            let clean = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if vm.state.coachName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !clean.isEmpty {
                vm.setCoachName(clean)
            }
        }
    }
    
    private var attendanceLoadFailureCard: some View {
        VStack(
            alignment: screenHorizontalAlignment,
            spacing: 10
        ) {
            Text(
                tr(
                    "טעינת הדוח לא הושלמה",
                    "Report loading did not complete"
                )
            )
            .kmiTypography(.cardTitle)
            .fontWeight(.bold)

            Text(
                tr(
                    "מוצגים נתונים מקומיים זמינים. יש לנסות שוב לפני עריכה או שיתוף.",
                    "Available local data is shown. Retry before editing or sharing."
                )
            )
            .kmiFont(size: 13, weight: .medium)

            Button {
                vm.retryLoadingCurrentContext()
            } label: {
                secondaryActionButton(
                    icon: "arrow.clockwise",
                    title: tr("נסה שוב", "Retry")
                )
            }
            .buttonStyle(.plain)
            .disabled(
                vm.isContextLoading ||
                vm.state.isSaving
            )
        }
        .foregroundStyle(primaryTextColor)
        .multilineTextAlignment(screenTextAlignment)
        .frame(
            maxWidth: .infinity,
            alignment: screenFrameAlignment
        )
        .padding(14)
        .background(cardSurfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(cardBorderColor, lineWidth: 1)
        }
    }

    private func resetAttendanceEditingState() {
        attendanceContextToken = UUID()
        reportSavedInCurrentContext = false
        isEditingSavedReport = false
        isAddMemberExpanded = false
        pendingDeleteRow = nil

        newMemberName = ""
        newMemberPhone = ""
        newMemberNotes = ""
    }

    private func refreshAssignedAttendanceBranches() {
        let assignedBranches =
            auth.userBranchAssignments.map(\.branch)

        let fallbackBranch =
            auth.userBranch.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        vm.setAssignedBranches(
            assignedBranches.isEmpty
                ? (
                    fallbackBranch.isEmpty
                        ? []
                        : [fallbackBranch]
                )
                : assignedBranches
        )
    }

    private var addMemberFloatingButton: some View {

        Button {
            guard canEditAttendance else { return }

            withAnimation(
                .easeInOut(duration: 0.22)
            ) {
                isAddMemberExpanded.toggle()
            }

        } label: {

            Image(
                systemName:
                    isAddMemberExpanded
                        ? "xmark"
                        : "plus"
            )
            .kmiIconSize(22)
            .fontWeight(.black)
            .accessibilityHidden(true)
            .foregroundStyle(
                KmiAppTheme.onSecondary(
                    for: colorScheme
                )
            )
            .frame(
                width: 56,
                height: 56
            )
            .background(
                KmiAppTheme.secondary(
                    for: colorScheme
                )
            )
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(
                        KmiAppTheme.onSecondary(
                            for: colorScheme
                        )
                        .opacity(0.28),
                        lineWidth: 1
                    )
            )
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canEditAttendance)
        .accessibilityLabel(
            isAddMemberExpanded
                ? tr(
                    "סגור טופס הוספת מתאמן",
                    "Close add trainee form"
                )
                : tr(
                    "הוספת מתאמן",
                    "Add trainee"
                )
        )
    }

    private var attendanceHeroCard: some View {
        let dateText = formattedDate(vm.state.dateIso)

        return VStack(
            alignment: screenHorizontalAlignment,
            spacing: 6
        ) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isClassSelectionExpanded.toggle()
                }
            } label: {
                Image(
                    systemName: isClassSelectionExpanded
                        ? "chevron.up"
                        : "chevron.down"
                )
                .resizable()
                .scaledToFit()
                .fontWeight(.semibold)
                .foregroundStyle(fieldIconColor)
                .frame(width: 72, height: 22)
                .frame(maxWidth: .infinity, minHeight: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tr("בחירת אימון", "Class selection"))
            .accessibilityValue(isClassSelectionExpanded
                ? tr("פתוח", "Expanded") : tr("סגור", "Collapsed"))

            Divider()
                .overlay(cardBorderColor)

            if isClassSelectionExpanded {
            Button {
                guard !vm.state.isSaving,
                      !isAddingMember else { return }

                draftAttendanceDate =
                    dateFromIso(vm.state.dateIso)
                    ?? Date()

                showDatePickerSheet = true
            } label: {
                premiumSelectionField(
                    label: tr(
                        "תאריך אימון",
                        "Class date"
                    ),
                    value: dateText,
                    icon: "calendar",
                    trailingIcon: "chevron.down"
                )
            }
            .buttonStyle(.plain)

            KmiPremiumDropdown(
                title: tr("סניף", "Branch"),
                options: vm.availableBranches,
                selectedValue: Binding(
                    get: { vm.state.branchName },
                    set: { value in
                        guard !vm.state.isSaving,
                              !isAddingMember,
                              vm.availableBranches.contains(value),
                              value != vm.state.branchName else { return }

                        vm.setBranchName(value)
                    }
                ),
                placeholder: tr(
                    "אין אימון בסניפים המשויכים בתאריך זה",
                    "No training at assigned branches on this date"
                ),
                isEnglish: isEnglish,
                isEnabled: !vm.availableBranches.isEmpty &&
                    !vm.state.isSaving && !isAddingMember,
                labelForOption: {
                    TrainingCatalogIOS.displayBranch(
                        $0,
                        isEnglish: isEnglish
                    )
                },
                titleInsideField: true
            )

            KmiPremiumDropdown(
                title: tr("קבוצה", "Group"),
                options: vm.availableGroups,
                selectedValue: Binding(
                    get: { vm.state.groupKey },
                    set: { value in
                        guard !vm.state.isSaving,
                              !isAddingMember,
                              vm.availableGroups.contains(value),
                              value != vm.state.groupKey else { return }

                        vm.setGroupKey(value)
                    }
                ),
                placeholder: tr(
                    "אין קבוצות עם אימון בתאריך זה",
                    "No groups with training on this date"
                ),
                isEnglish: isEnglish,
                isEnabled: !vm.availableGroups.isEmpty &&
                    !vm.state.isSaving && !isAddingMember,
                labelForOption: {
                    TrainingCatalogIOS.displayGroup(
                        $0,
                        isEnglish: isEnglish
                    )
                },
                titleInsideField: true
            )

            }
            Text(isEnglish
                ? "Attendance updated: \(attendancePercentText)%"
                : "עדכון נוכחות: \(attendancePercentText)%")
                .kmiTypography(.action)
                .foregroundStyle(KmiAppTheme.secondary(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(cardBorderColor)
                .frame(height: 1)
        }
    }
    
    private func premiumSelectionField(
        label: String,
        value: String,
        icon _: String,
        trailingIcon: String?
    ) -> some View {
        HStack(spacing: 10) {
            if !isEnglish {
                selectionChevron(trailingIcon)
            }
            VStack(alignment: isEnglish ? .leading : .trailing, spacing: 1) {
                Text(label)
                    .kmiTypography(.secondary)
                    .fontWeight(.bold)
                    .foregroundStyle(secondaryTextColor)
                Text(value.isEmpty ? "—" : value)
                    .kmiTypography(.action)
                    .foregroundStyle(primaryTextColor)
                    .multilineTextAlignment(screenTextAlignment)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
            if isEnglish {
                selectionChevron(trailingIcon)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(minHeight: 50)
        .background(fieldSurfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(cardBorderColor, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func selectionChevron(_ name: String?) -> some View {
        if let name {
            Image(systemName: name)
                .kmiIconSize(12)
                .foregroundStyle(fieldIconColor)
                .frame(width: 24, height: 24)
                .background(fieldIconSurfaceColor, in: Circle())
                .accessibilityHidden(true)
        }
    }

    private func fieldIcon(_ name: String) -> some View {
        Image(systemName: name)
            .kmiIconSize(14)
            .fontWeight(.heavy)
            .foregroundStyle(fieldIconColor)
            .frame(width: 32, height: 32)
            .background(fieldIconSurfaceColor)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(
                        fieldIconColor.opacity(0.32),
                        lineWidth: 1
                    )
            )
    }
    
    private var displayedAttendanceSummary: (
        totalMembers: Int,
        attendancePercent: Int,
        presentLabel: String,
        absentLabel: String,
        excusedLabel: String,
        unknownLabel: String
    ) {
        let rows = uniqueMembers(vm.state.rows)
        let total = rows.count

        let present = rows.filter {
            $0.status == .present
        }.count

        let absent = rows.filter {
            $0.status == .absent
        }.count

        let excused = rows.filter {
            $0.status == .excused
        }.count

        let unmarked = rows.filter {
            $0.status == .unknown
        }.count

        let percent = total > 0
            ? Int(Double(present) * 100 / Double(total))
            : 0

        return (
            totalMembers: total,
            attendancePercent: percent,
            presentLabel: String(present),
            absentLabel: String(absent),
            excusedLabel: String(excused),
            unknownLabel: String(unmarked)
        )
    }

    private var attendancePercentText: String {
        let rows = uniqueMembers(vm.state.rows)
        let present = rows.filter {
            $0.status == .present
        }.count

        let percent = rows.isEmpty
            ? 0.0
            : Double(present) * 100.0 / Double(rows.count)

        return String(
            format: "%.1f",
            locale: Locale(identifier: "en_US_POSIX"),
            percent
        )
    }

    private var attendanceSummaryCard: some View {
        let summary = displayedAttendanceSummary
        return VStack(alignment: screenHorizontalAlignment, spacing: 12) {
            Text(tr("נוכחות ממוצעת של הקבוצה בשיעור זה", "Group attendance for this class"))
                .kmiTypography(.sectionTitle)
                .fontWeight(.heavy)
                .foregroundStyle(primaryTextColor)
                .multilineTextAlignment(screenTextAlignment)
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)

            HStack(spacing: 8) {
                if isEnglish {
                    attendanceSummaryValue(title: "Total", value: String(summary.totalMembers))
                    attendanceSummaryValue(title: "Present", value: summary.presentLabel)
                    attendanceSummaryValue(title: "Absent", value: summary.absentLabel)
                } else {
                    attendanceSummaryValue(title: "נעדרו", value: summary.absentLabel)
                    attendanceSummaryValue(title: "הגיעו", value: summary.presentLabel)
                    attendanceSummaryValue(title: "סה״כ", value: String(summary.totalMembers))
                }
            }
            .environment(\.layoutDirection, .leftToRight)

            Text(
                tr(
                    "נוכחות: \(attendancePercentText)%",
                    "Attendance: \(attendancePercentText)%"
                )
            )
                .kmiTypography(.action)
                .foregroundStyle(KmiAppTheme.secondary(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(cardBorderColor)
                .frame(height: 1)
        }
    }

    private func attendanceSummaryValue(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .kmiTypography(.metric)
                .foregroundStyle(primaryTextColor)
            Text(title)
                .kmiTypography(.action)
                .foregroundStyle(secondaryTextColor)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var attendanceModeTabs: some View {
        HStack(spacing: 0) {
            NavigationLink {
                AttendanceGroupStatsView(
                    ownerUid: vm.state.ownerUid,
                    initialBranchName: vm.state.branchName,
                    initialGroupKey: vm.state.groupKey
                )
            } label: {
                Text(tr("סטטיסטיקה", "Statistics"))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isAttendanceContextReady)

            Rectangle()
                .fill(KmiAppTheme.sectionHeaderContentColor.opacity(0.5))
                .frame(width: 1, height: 28)

            Text(tr("בחירת אימון", "Class selection"))
                .frame(maxWidth: .infinity, minHeight: 56)
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(KmiAppTheme.sectionHeaderContentColor)
                        .frame(width: 64, height: 3)
                        .padding(.bottom, 4)
                }
                .accessibilityAddTraits(.isSelected)
        }
        .kmiTypography(.action)
        .foregroundStyle(KmiAppTheme.sectionHeaderContentColor)
        .environment(\.layoutDirection, .leftToRight)
        .background(KmiAppTheme.sectionHeaderBrush)
    }

    private var addMemberCard: some View {
        VStack(alignment: screenHorizontalAlignment, spacing: 12) {
            HStack {
                if isEnglish {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(
                            tr(
                                "הוספת מתאמן",
                                "Add trainee"
                            )
                        )
                        .kmiFont(
                            size: 18,
                            weight: .heavy
                        )
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.74)

                        Text(
                            tr(
                                "רשימת המתאמנים נטענת לפי סניף וקבוצה",
                                "The trainee list loads by branch and group"
                            )
                        )
                        .kmiFont(
                            size: 12,
                            weight: .semibold
                        )
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(3)
                        .minimumScaleFactor(0.74)
                    }

                    Spacer()

                    Image(systemName: "person.badge.plus")
                        .kmiIconSize(18)
                        .fontWeight(.heavy)
                        .accessibilityHidden(true)
                        .foregroundStyle(
                            KmiAppTheme.secondary(
                                for: colorScheme
                            )
                        )
                } else {
                    Image(systemName: "person.badge.plus")
                        .kmiIconSize(18)
                        .fontWeight(.heavy)
                        .accessibilityHidden(true)
                        .foregroundStyle(
                            KmiAppTheme.secondary(
                                for: colorScheme
                            )
                        )

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(
                            tr(
                                "הוספת מתאמן",
                                "Add trainee"
                            )
                        )
                        .kmiFont(
                            size: 18,
                            weight: .heavy
                        )
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.74)

                        Text(
                            tr(
                                "רשימת המתאמנים נטענת לפי סניף וקבוצה",
                                "The trainee list loads by branch and group"
                            )
                        )
                        .kmiFont(
                            size: 12,
                            weight: .semibold
                        )
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(3)
                        .minimumScaleFactor(0.74)
                    }
                }
            }
            .environment(\.layoutDirection, .leftToRight)

            attendanceTextField(tr("שם מלא", "Full name"), text: $newMemberName)

            attendanceTextField(
                tr("טלפון", "Phone"),
                text: $newMemberPhone,
                isPhone: true
            )
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            attendanceTextField(tr("הערות", "Notes"), text: $newMemberNotes)

            Button {
                guard canEditAttendance,
                      !newMemberName.trimmingCharacters(
                        in: .whitespacesAndNewlines
                      ).isEmpty else {
                    return
                }

                let submittedContextToken = attendanceContextToken
                isAddingMember = true

                vm.addMember(
                    fullName: newMemberName,
                    phone: newMemberPhone,
                    notes: newMemberNotes,
                    completion: { succeeded in
                        isAddingMember = false

                        guard attendanceContextToken == submittedContextToken,
                              succeeded else {
                            return
                        }

                        newMemberName = ""
                        newMemberPhone = ""
                        newMemberNotes = ""

                        withAnimation(
                            .easeInOut(duration: 0.22)
                        ) {
                            isAddMemberExpanded = false
                        }
                    }
                )
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .kmiIconSize(16)
                        .fontWeight(.heavy)
                        .accessibilityHidden(true)

                    Text(
                        tr(
                            "הוסף מתאמן",
                            "Add trainee"
                        )
                    )
                    .kmiFont(
                        size: 16,
                        weight: .heavy
                    )
                }
                .foregroundStyle(
                    KmiAppTheme.onSecondary(
                        for: colorScheme
                    )
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    KmiAppTheme.secondary(
                        for: colorScheme
                    )
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                )
            }
            .buttonStyle(.plain)
            .disabled(
                !canEditAttendance ||
                newMemberName
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty
            )
            .opacity(
                (
                    !canEditAttendance ||
                    newMemberName
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        .isEmpty
                )
                    ? 0.45
                    : 1.0
            )
        }
        .padding(16)
        .background(cardSurfaceColor)
        .overlay(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(
                cardBorderColor,
                lineWidth: 1
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .transition(
            .move(edge: .top)
                .combined(with: .opacity)
        )
    }

    private var membersCard: some View {
        let rows = uniqueMembers(vm.state.rows)

        return VStack(spacing: 0) {
            if rows.isEmpty {
                Text(
                    tr(
                        "אין מתאמנים בקבוצה שנבחרה",
                        "No trainees in the selected group"
                    )
                )
                .kmiTypography(.body)
                .foregroundStyle(secondaryTextColor)
                .multilineTextAlignment(screenTextAlignment)
                .frame(
                    maxWidth: .infinity,
                    alignment: screenFrameAlignment
                )
                .padding(.vertical, 16)
            } else {
                ForEach(
                    Array(rows.enumerated()),
                    id: \.element.id
                ) { index, row in
                    memberRow(row, demoIndex: index)

                    if index < rows.count - 1 {
                        Rectangle()
                            .fill(cardBorderColor)
                            .frame(height: 1)
                    }
                }
            }
        }
    }

    private var actionsCard: some View {
        VStack(alignment: screenHorizontalAlignment, spacing: 12) {
            HStack {
                if isEnglish {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(
                            tr(
                                "פעולות",
                                "Actions"
                            )
                        )
                        .kmiFont(
                            size: 18,
                            weight: .heavy
                        )
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.74)

                        Text(
                            tr(
                                "שמירה, שיתוף וסטטיסטיקה של דו״ח הנוכחות",
                                "Save, share and view attendance report statistics"
                            )
                        )
                        .kmiFont(
                            size: 12,
                            weight: .semibold
                        )
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(3)
                        .minimumScaleFactor(0.70)
                    }

                    Spacer()

                    Image(systemName: "square.and.arrow.up")
                        .kmiIconSize(17)
                        .fontWeight(.heavy)
                        .accessibilityHidden(true)
                        .foregroundStyle(
                            KmiAppTheme.secondary(
                                for: colorScheme
                            )
                        )
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .kmiIconSize(17)
                        .fontWeight(.heavy)
                        .accessibilityHidden(true)
                        .foregroundStyle(
                            KmiAppTheme.secondary(
                                for: colorScheme
                            )
                        )

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(
                            tr(
                                "פעולות",
                                "Actions"
                            )
                        )
                        .kmiFont(
                            size: 18,
                            weight: .heavy
                        )
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.74)

                        Text(
                            tr(
                                "שמירה, שיתוף וסטטיסטיקה של דו״ח הנוכחות",
                                "Save, share and view attendance report statistics"
                            )
                        )
                        .kmiFont(
                            size: 12,
                            weight: .semibold
                        )
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(3)
                        .minimumScaleFactor(0.70)
                    }
                }
            }
            .environment(\.layoutDirection, .leftToRight)

            HStack(spacing: 10) {
                NavigationLink {
                    AttendanceGroupStatsView(
                        ownerUid: vm.state.ownerUid,
                        initialBranchName: vm.state.branchName,
                        initialGroupKey: vm.state.groupKey
                    )
                } label: {
                    secondaryActionButton(icon: "chart.bar.xaxis", title: tr("סטטיסטיקה", "Stats"))
                }
                .buttonStyle(.plain)
                .disabled(!isAttendanceContextReady)

                Button {
                    shareReport()
                } label: {
                    secondaryActionButton(icon: "square.and.arrow.up", title: tr("שתף", "Share"))
                }
                .buttonStyle(.plain)
                .disabled(!isAttendanceContextReady || showShareSheet)
            }

            Button {

                guard isAttendanceContextReady else {
                    return
                }

                if isAttendanceReportSaved &&
                    !isEditingSavedReport {

                    isEditingSavedReport = true

                } else {
                    let submittedContextToken = attendanceContextToken

                    vm.saveReport(
                        onSaved: {
                            guard attendanceContextToken == submittedContextToken else {
                                return
                            }

                            reportSavedInCurrentContext = true
                            isEditingSavedReport = false
                        }
                    )
                }

            } label: {

                HStack(spacing: 8) {

                    Image(
                        systemName:
                            isAttendanceReportSaved &&
                            !isEditingSavedReport
                        ? "pencil.circle.fill"
                        : "checkmark.circle.fill"
            )
            .kmiIconSize(16)
            .fontWeight(.bold)
            .accessibilityHidden(true)

                    Text(
                        vm.state.isSaving
                            ? tr(
                                "שומר...",
                                "Saving..."
                            )
                            : (
                                isAttendanceReportSaved &&
                                !isEditingSavedReport
                                    ? tr(
                                        "עריכת דיווח",
                                        "Edit report"
                                    )
                                    : tr(
                                        "שמירת דו״ח נוכחות",
                                        "Save attendance report"
                                    )
                            )
                    )
                    .kmiFont(
                        size: 15,
                        weight: .heavy
                    )
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                }
                .foregroundStyle(
                    isAttendanceReportSaved &&
                    !isEditingSavedReport
                        ? KmiAppTheme.onSecondary(
                            for: colorScheme
                        )
                        : KmiAppTheme.onSuccess(
                            for: colorScheme
                        )
                )
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .padding(.horizontal, 12)
                .background(
                    isAttendanceReportSaved &&
                    !isEditingSavedReport
                        ? KmiAppTheme.secondary(
                            for: colorScheme
                        )
                        : KmiAppTheme.success(
                            for: colorScheme
                        )
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
                        (
                            isAttendanceReportSaved &&
                            !isEditingSavedReport
                                ? KmiAppTheme.onSecondary(
                                    for: colorScheme
                                )
                                : KmiAppTheme.onSuccess(
                                    for: colorScheme
                                )
                        )
                        .opacity(0.24),
                        lineWidth: 1
                    )
                )
            }
            .buttonStyle(.plain)
            .disabled(
                !isAttendanceContextReady
            )
            .opacity(
                (
                    !isAttendanceContextReady
                )
                    ? 0.65
                    : 1
            )
        }
        .padding(14)
        .background(cardSurfaceColor)
        .overlay(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(
                cardBorderColor,
                lineWidth: 1
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
    }

    private func toggleAttendanceStatus(

        row: AttendanceRowUi,

        targetStatus: AttendanceStatus

    ) {

        guard canEditAttendance else {
            return
        }

        let nextStatus: AttendanceStatus =
            row.status == targetStatus
                ? .unknown
                : targetStatus

        vm.setAttendanceStatus(
            memberId: row.memberId,
            status: nextStatus
        )
    }

    private func memberRow(
        _ row: AttendanceRowUi,
        demoIndex: Int
    ) -> some View {
        let mappedName = TraineeDisplayNameMapper.displayName(
            realName: row.memberName.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            stableKey: row.memberId,
            demoIndex: demoIndex,
            isEnglish: isEnglish
        )

        let name = mappedName.isEmpty
            ? tr("מתאמן ללא שם", "Unnamed trainee")
            : mappedName

        return VStack(
            alignment: screenHorizontalAlignment,
            spacing: 8
        ) {
            Text(name)
                .kmiTypography(.sectionTitle)
                .fontWeight(.heavy)
                .foregroundStyle(primaryTextColor)
                .multilineTextAlignment(screenTextAlignment)
                .fixedSize(horizontal: false, vertical: true)
                .frame(
                    maxWidth: .infinity,
                    alignment: screenFrameAlignment
                )

            HStack(alignment: .center, spacing: 12) {
                HStack(spacing: 10) {
                    NavigationLink {
                        AttendanceStatsView(
                            ownerUid: vm.state.ownerUid,
                            branchName: vm.state.branchName,
                            groupKey: vm.state.groupKey,
                            memberId: row.memberId,
                            memberName: name
                        )
                    } label: {
                        Image(systemName: "chart.bar.fill")
                            .kmiIconSize(18)
                            .foregroundStyle(
                                KmiAppTheme.tertiary(
                                    for: colorScheme
                                )
                            )
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        tr("סטטיסטיקת מתאמן", "Trainee statistics")
                    )

                    Button {
                        guard canEditAttendance else { return }
                        pendingDeleteRow = row
                    } label: {
                        Image(systemName: "trash.fill")
                            .kmiIconSize(18)
                            .foregroundStyle(
                                KmiAppTheme.warning(
                                    for: colorScheme
                                )
                            )
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canEditAttendance)
                    .accessibilityLabel(
                        tr("מחיקת מתאמן", "Delete trainee")
                    )
                }

                Spacer(minLength: 0)

                VStack(spacing: 7) {
                    attendanceRowStatusButton(
                        row: row,
                        title: tr("הגיע", "Present"),
                        status: .present,
                        color: KmiAppTheme.success(
                            for: colorScheme
                        )
                    )

                    attendanceRowStatusButton(
                        row: row,
                        title: tr("לא הגיע", "Absent"),
                        status: .absent,
                        color: KmiAppTheme.error(
                            for: colorScheme
                        )
                    )
                }
                .frame(maxWidth: 180)
            }
            .environment(\.layoutDirection, .leftToRight)
        }
        .padding(.vertical, 12)
    }

    private func attendanceRowStatusButton(
        row: AttendanceRowUi,
        title: String,
        status: AttendanceStatus,
        color: Color
    ) -> some View {
        let selected = row.status == status

        return Button {
            toggleAttendanceStatus(
                row: row,
                targetStatus: status
            )
        } label: {
            Text(title)
                .kmiTypography(.action)
                .foregroundStyle(
                    KmiAppTheme.onSurface(for: .dark)
                )
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 36)
                .background(
                    selected
                        ? color
                        : KmiAppTheme.surface(for: .dark),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .stroke(cardBorderColor, lineWidth: 1)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!canEditAttendance)
        .accessibilityLabel(title)
        .accessibilityValue(
            selected
                ? tr("נבחר", "Selected")
                : tr("לא נבחר", "Not selected")
        )
    }

    private func traineeAvatar(_ row: AttendanceRowUi) -> some View {
    let tint: Color = {
        switch row.status {
        case .present:
            return KmiAppTheme.success(
                for: colorScheme
            )

        case .absent:
            return KmiAppTheme.error(
                for: colorScheme
            )

        case .excused, .unknown:
            return KmiAppTheme.onSurfaceVariant(
                for: colorScheme
            )
        }
    }()

    return ZStack {
        Circle()
            .fill(tint.opacity(0.14))

        Image(systemName: "person.fill")
            .kmiIconSize(16)
            .fontWeight(.black)
            .foregroundStyle(tint)
            .accessibilityHidden(true)
    }
    .frame(width: 38, height: 38)
    .overlay(
        Circle()
            .stroke(
                tint.opacity(0.28),
                lineWidth: 1
            )
    )
}
    
    private func deleteMemberButton(
        _ row: AttendanceRowUi
    ) -> some View {

        Button {

            guard canEditAttendance else {
                return
            }

            pendingDeleteRow = row

        } label: {

            Image(
                systemName: "trash.fill"
            )
                .kmiIconSize(14)
                .fontWeight(.black)
                .accessibilityHidden(true)
                .foregroundStyle(
                    KmiAppTheme.error(
                        for: colorScheme
                    )
                )
                .frame(width: 42, height: 42)
                .background(
                    KmiAppTheme.errorContainer(
                        for: colorScheme
                    )
                )
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            KmiAppTheme.error(
                                for: colorScheme
                            )
                            .opacity(0.30),
                            lineWidth: 1
                        )
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(
            !canEditAttendance
        )
        .opacity(
            canEditAttendance
                ? 1
                : 0.56
        )
        .accessibilityLabel(
            tr(
                "מחיקת מתאמן",
                "Delete trainee"
            )
        )
    }

    private func statusButton(
        title: String,
        icon: String,
        selected: Bool,
        selectedColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text(title)
                    .kmiTypography(.caption)
                    .fontWeight(.heavy)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }
            .foregroundStyle(
                selected
                    ? Color.white
                    : KmiAppTheme.onSurface(for: colorScheme)
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 36)
            .background(
                selected
                    ? selectedColor
                    : KmiAppTheme.surface(for: colorScheme)
            )
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(
                        selected
                            ? Color.clear
                            : KmiAppTheme.outlineVariant(
                                for: colorScheme
                            ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(
            selected
                ? tr("נבחר", "Selected")
                : tr("לא נבחר", "Not selected")
        )
    }

    private func statPill(
        title: String,
        value: String,
        tint: Color
    ) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .kmiFont(
                    size: 18,
                    weight: .black
                )
                .foregroundStyle(
                    KmiAppTheme.onSurface(
                        for: colorScheme
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.70)

            Text(title)
                .kmiTypography(.caption)
                .fontWeight(.bold)
                .foregroundStyle(
                    KmiAppTheme.onSurfaceVariant(
                        for: colorScheme
                    )
                )
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
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

    private func attendanceTextField(
        _ placeholder: String,
        text: Binding<String>,
        isPhone: Bool = false
    ) -> some View {
        TextField(
            placeholder,
            text: text,
            axis: .vertical
        )
        .kmiFont(
            size: 15,
            weight: .semibold
        )
        .foregroundStyle(primaryTextColor)
        .accessibilityLabel(placeholder)
        .lineLimit(1...4)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(fieldSurfaceColor)
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
                cardBorderColor,
                lineWidth: 1
            )
        )
        .multilineTextAlignment(
            isPhone || isEnglish ? .leading : .trailing
        )
        .environment(\.layoutDirection, .leftToRight)
        .disabled(!canEditAttendance)
    }

    private func secondaryActionButton(
        icon: String,
        title: String
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .kmiIconSize(16)
                .fontWeight(.bold)
                .accessibilityHidden(true)

            Text(title)
                .kmiTypography(.action)
                .fontWeight(.heavy)
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
        }
        .foregroundStyle(primaryTextColor)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 48)
        .background(elevatedSurfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(
                cardBorderColor,
                lineWidth: 1
            )
        )
    }


    private func displayName(
        for row: AttendanceRowUi?
    ) -> String {

        guard let row else {
            return tr(
                "המתאמן",
                "this trainee"
            )
        }

        let uniqueRows =
            uniqueMembers(
                vm.state.rows
            )

        let demoIndex =
            uniqueRows.firstIndex {
                $0.memberId == row.memberId
            }

        let mappedName =
            TraineeDisplayNameMapper.displayName(
                realName: row.memberName,
                stableKey: row.memberId,
                demoIndex: demoIndex,
                isEnglish: isEnglish
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return mappedName.isEmpty
            ? tr(
                "המתאמן",
                "this trainee"
            )
            : mappedName
    }

    private func shareReport() {
        guard !vm.state.isSaving,
              !isAddingMember,
              !showShareSheet else {
            return
        }

        guard !vm.isContextLoading,
              !vm.contextLoadFailed else {
            withAnimation {
                toastMessage = tr(
                    "יש להשלים את טעינת הדוח לפני שיתוף",
                    "Finish loading the report before sharing"
                )
            }

            return
        }

        guard !vm.state.ownerUid
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty,
              !vm.state.branchName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty,
              !vm.state.groupKey
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty else {
            withAnimation {
                toastMessage = tr(
                    "יש לבחור סניף וקבוצה לפני שיתוף הדוח",
                    "Select a branch and group before sharing the report"
                )
            }

            return
        }

        guard let pdfUrl =
            createAttendancePDF()
        else {
            withAnimation {
                toastMessage =
                    tr(
                        "לא ניתן היה ליצור את קובץ ה־PDF",
                        "The PDF file could not be created"
                    )
            }

            return
        }

        shareItems = [
            pdfUrl
        ]

        showShareSheet = true
    }

    private func createAttendancePDF() -> URL? {

        let rows =
            uniqueMembers(
                vm.state.rows
            )

        let reportDateText =
            formattedDate(
                vm.state.dateIso
            )

        let pageRect = CGRect(
            x: 0,
            y: 0,
            width: 595,
            height: 842
        )

        let renderer =
            UIGraphicsPDFRenderer(
                bounds: pageRect
            )

        let pdfData =
            renderer.pdfData { context in

                MainActor.assumeIsolated {

                    let cg =
                        context.cgContext

                    let pageWidth =
                        pageRect.width

                    let horizontalMargin: CGFloat =
                        34

                let contentWidth =
                    pageWidth -
                    horizontalMargin * 2

                let contentBottom =
                    pageRect.height -
                    KmiPdfFooter.CONTENT_BOTTOM_PADDING

                let textAlignment: NSTextAlignment =
                    isEnglish
                        ? .left
                        : .right

                let writingDirection:
                    NSWritingDirection =
                        isEnglish
                            ? .leftToRight
                            : .rightToLeft

                var pageNumber = 0

                var currentY =
                    KmiPdfHeader.CONTENT_TOP

                func paragraphStyle(
                    alignment: NSTextAlignment
                ) -> NSMutableParagraphStyle {

                    let style =
                        NSMutableParagraphStyle()

                    style.alignment = alignment
                    style.baseWritingDirection =
                        writingDirection
                    style.lineBreakMode =
                        .byTruncatingTail

                    return style
                }

                func drawFooter() {

                    KmiPdfFooter.draw(
                        context: cg,
                        pageWidth: pageRect.width,
                        pageHeight: pageRect.height,
                        pageNumber: pageNumber,
                        isEnglish: isEnglish
                    )
                }

                func beginPage() {

                    context.beginPage()

                    pageNumber += 1

                    KmiPdfHeader.draw(
                        context: cg,
                        pageWidth: pageRect.width,
                        isEnglish: isEnglish,
                        titleHebrew: "דו״ח נוכחות",
                        titleEnglish: "Attendance Report",
                        subtitleHebrew:
                            reportDateText,
                        subtitleEnglish:
                            reportDateText
                    )

                    currentY =
                        KmiPdfHeader.CONTENT_TOP
                }

                    /*
                     * הערות ארוכות נפרסות על פני עמודים.
                     * המדידה והציור משתמשים באותם מאפייני טקסט.
                     */
                    func drawReportNote(_ text: String) {
                        let font = UIFont.systemFont(ofSize: 10)
                        let width = contentWidth - 24

                        let style = NSMutableParagraphStyle()
                        style.alignment = textAlignment
                        style.baseWritingDirection = writingDirection
                        style.lineBreakMode = .byWordWrapping

                        let attributes: [NSAttributedString.Key: Any] = [
                            .font: font,
                            .foregroundColor: UIColor(
                                red: 0.29,
                                green: 0.34,
                                blue: 0.40,
                                alpha: 1
                            ),
                            .paragraphStyle: style
                        ]

                        let options: NSStringDrawingOptions = [
                            .usesLineFragmentOrigin,
                            .usesFontLeading
                        ]

                        func measuredHeight(_ value: String) -> CGFloat {
                            ceil(
                                (value as NSString).boundingRect(
                                    with: CGSize(
                                        width: width,
                                        height: .greatestFiniteMagnitude
                                    ),
                                    options: options,
                                    attributes: attributes,
                                    context: nil
                                ).height
                            )
                        }

                        var remaining = text

                        while !remaining.isEmpty {
                            let availableHeight =
                                floor(contentBottom - currentY - 4)

                            if availableHeight < ceil(font.lineHeight) {
                                drawFooter()
                                beginPage()
                                continue
                            }

                            /*
                             * מוצאים את כמות התווים שנכנסת בעמוד.
                             * String.prefix שומר על תווים מורכבים.
                             */
                            var low = 1
                            var high = remaining.count
                            var fittingCount = 0

                            while low <= high {
                                let middle = low + (high - low) / 2
                                let candidate = String(
                                    remaining.prefix(middle)
                                )

                                if measuredHeight(candidate) <= availableHeight {
                                    fittingCount = middle
                                    low = middle + 1
                                } else {
                                    high = middle - 1
                                }
                            }

                            guard fittingCount > 0 else {
                                drawFooter()
                                beginPage()
                                continue
                            }

                            let chunk = String(
                                remaining.prefix(fittingCount)
                            )

                            let height = measuredHeight(chunk)

                            (chunk as NSString).draw(
                                with: CGRect(
                                    x: horizontalMargin + 12,
                                    y: currentY,
                                    width: width,
                                    height: height + 1
                                ),
                                options: options,
                                attributes: attributes,
                                context: nil
                            )

                            currentY += height + 4

                            remaining = String(
                                remaining.dropFirst(fittingCount)
                            )
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )

                            if !remaining.isEmpty {
                                drawFooter()
                                beginPage()
                            }
                        }
                    }

                    func drawText(
                        _ text: String,
                        in rect: CGRect,
                        font: UIFont,
                        color: UIColor,
                        alignment: NSTextAlignment
                    ) {

                    let attributes:
                        [NSAttributedString.Key: Any] = [
                            .font: font,
                            .foregroundColor: color,
                            .paragraphStyle:
                                paragraphStyle(
                                    alignment: alignment
                                )
                        ]

                    NSAttributedString(
                        string: text,
                        attributes: attributes
                    )
                    .draw(
                        with: rect,
                        options: [
                            .usesLineFragmentOrigin,
                            .usesFontLeading,
                            .truncatesLastVisibleLine
                        ],
                        context: nil
                    )
                }

                func statusText(
                    for row: AttendanceRowUi
                ) -> String {

                    switch row.status {

                    case .present:
                        return tr(
                            "הגיע",
                            "Present"
                        )

                    case .absent:
                        return tr(
                            "לא הגיע",
                            "Absent"
                        )

                    case .excused:
                        return tr(
                            "היעדרות מוצדקת",
                            "Excused absence"
                        )

                    case .unknown:
                        return tr(
                            "לא סומן",
                            "Not marked"
                        )
                    }
                }

                func statusColor(
                    for row: AttendanceRowUi
                ) -> UIColor {

                    switch row.status {

                    case .present:
                        return UIColor(
                            red: 0.03,
                            green: 0.47,
                            blue: 0.34,
                            alpha: 1
                        )

                    case .absent:
                        return UIColor(
                            red: 0.73,
                            green: 0.10,
                            blue: 0.10,
                            alpha: 1
                        )

                    case .excused, .unknown:
                        return UIColor(
                            red: 0.34,
                            green: 0.40,
                            blue: 0.47,
                            alpha: 1
                        )
                    }
                }

                beginPage()

                    let branch = TrainingCatalogIOS.displayBranch(
                        vm.state.branchName,
                        isEnglish: isEnglish
                    )
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                    let group = TrainingCatalogIOS.displayGroup(
                        vm.state.groupKey,
                        isEnglish: isEnglish
                    )
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                let branchGroupText =
                    [
                        branch.isEmpty
                            ? nil
                            : tr(
                                "סניף: \(branch)",
                                "Branch: \(branch)"
                            ),
                        group.isEmpty
                            ? nil
                            : tr(
                                "קבוצה: \(group)",
                                "Group: \(group)"
                            )
                    ]
                    .compactMap { $0 }
                    .joined(separator: " · ")

                if !branchGroupText.isEmpty {

                    drawText(
                        branchGroupText,
                        in: CGRect(
                            x: horizontalMargin,
                            y: currentY,
                            width: contentWidth,
                            height: 24
                        ),
                        font:
                            UIFont.boldSystemFont(
                                ofSize: 12
                            ),
                        color:
                            UIColor(
                                red: 0.29,
                                green: 0.34,
                                blue: 0.40,
                                alpha: 1
                            ),
                        alignment: textAlignment
                    )

                    currentY += 30
                }

                if rows.isEmpty {

                    drawText(
                        tr(
                            "אין מתאמנים להצגה בדו״ח",
                            "No trainees are available for this report"
                        ),
                        in: CGRect(
                            x: horizontalMargin,
                            y: currentY + 20,
                            width: contentWidth,
                            height: 40
                        ),
                        font:
                            UIFont.boldSystemFont(
                                ofSize: 14
                            ),
                        color:
                            UIColor(
                                red: 0.29,
                                green: 0.34,
                                blue: 0.40,
                                alpha: 1
                            ),
                        alignment: .center
                    )

                } else {

                    for (index, row)
                        in rows.enumerated() {

                        let originalNote =
                            row.attendanceNote
                                .trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                )

                        let note: String

                        if demoPrivacy.isEnabled &&
                            !originalNote.isEmpty {
                            note = tr(
                                "ההערה מוסתרת במצב הדגמה",
                                "Note hidden in demo mode"
                            )
                        } else {
                            note = originalNote
                        }

                        let rowHeight: CGFloat = 46

                        if currentY + rowHeight >
                            contentBottom {

                            drawFooter()
                            beginPage()
                        }

                        let rowRect =
                            CGRect(
                                x: horizontalMargin,
                                y: currentY,
                                width: contentWidth,
                                height: rowHeight
                            )

                        let path =
                            UIBezierPath(
                                roundedRect: rowRect,
                                cornerRadius: 10
                            )

                        UIColor(
                            red: 0.96,
                            green: 0.98,
                            blue: 1,
                            alpha: 1
                        )
                        .setFill()

                        path.fill()

                        UIColor(
                            red: 0.82,
                            green: 0.87,
                            blue: 0.91,
                            alpha: 1
                        )
                        .setStroke()

                        path.lineWidth = 1
                        path.stroke()

                        let displayName =
                            TraineeDisplayNameMapper
                                .displayName(
                                    realName:
                                        row.memberName,
                                    stableKey:
                                        row.memberId,
                                    demoIndex:
                                        index,
                                    isEnglish:
                                        isEnglish
                                )
                                .trimmingCharacters(
                                    in:
                                        .whitespacesAndNewlines
                                )

                        let safeName =
                            displayName.isEmpty
                                ? tr(
                                    "מתאמן ללא שם",
                                    "Unnamed trainee"
                                )
                                : displayName

                        let nameText =
                            "\(index + 1). \(safeName)"

                        let status =
                            statusText(
                                for: row
                            )

                        let nameWidth =
                            contentWidth * 0.66

                        let statusWidth =
                            contentWidth -
                            nameWidth -
                            24

                        let nameX =
                            isEnglish
                                ? rowRect.minX + 12
                                : rowRect.maxX -
                                    nameWidth -
                                    12

                        let statusX =
                            isEnglish
                                ? rowRect.maxX -
                                    statusWidth -
                                    12
                                : rowRect.minX + 12

                        drawText(
                            nameText,
                            in: CGRect(
                                x: nameX,
                                y: rowRect.minY + 8,
                                width: nameWidth,
                                height: 20
                            ),
                            font:
                                UIFont.boldSystemFont(
                                    ofSize: 12
                                ),
                            color:
                                UIColor(
                                    red: 0.09,
                                    green: 0.13,
                                    blue: 0.20,
                                    alpha: 1
                                ),
                            alignment:
                                textAlignment
                        )

                        drawText(
                            status,
                            in: CGRect(
                                x: statusX,
                                y: rowRect.minY + 8,
                                width: statusWidth,
                                height: 20
                            ),
                            font:
                                UIFont.boldSystemFont(
                                    ofSize: 11
                                ),
                            color:
                                statusColor(
                                    for: row
                                ),
                            alignment:
                                isEnglish
                                    ? .right
                                    : .left
                        )

                        currentY = rowRect.maxY + 4

                        if !note.isEmpty {
                            drawReportNote(
                                tr(
                                    "הערה: \(note)",
                                    "Note: \(note)"
                                )
                            )
                        }

                        currentY += 8
                    }
                }

                drawFooter()
                }
            }

        let fileName =
            isEnglish
                ? "KMI_Attendance_Report.pdf"
                : "קמי_דוח_נוכחות.pdf"

        let fileUrl =
            FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    fileName
                )

        do {

            try pdfData.write(
                to: fileUrl,
                options: .atomic
            )

            return fileUrl

        } catch {

            return nil
        }

    }

    private func formattedDate(
        _ iso: String
    ) -> String {
        let reportTimeZone =
            TimeZone(identifier: "Asia/Jerusalem") ?? .current

        let output = DateFormatter()
        output.calendar = Calendar(identifier: .gregorian)
        output.timeZone = reportTimeZone
        output.locale = Locale(
            identifier: isEnglish ? "en_US" : "he_IL"
        )
        output.dateFormat =
            isEnglish
                ? "EEE · MM/dd/yy"
                : "EEEE · d.M.yy"

        guard let date = dateFromIso(iso) else {
            return iso
        }

        return output.string(from: date)
    }

    private func dateFromIso(_ iso: String) -> Date? {
        let clean = iso.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let input = DateFormatter()
        input.calendar = ShabbatHolidayCheckerIOS.calendar
        input.timeZone = ShabbatHolidayCheckerIOS.timeZone
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd"
        input.isLenient = false

        guard let date = input.date(from: clean),
              input.string(from: date) == clean else {
            return nil
        }

        return date
    }

    private func isoString(from date: Date) -> String {
        let output = DateFormatter()
        output.calendar = ShabbatHolidayCheckerIOS.calendar
        output.timeZone = ShabbatHolidayCheckerIOS.timeZone
        output.locale = Locale(identifier: "en_US_POSIX")
        output.dateFormat = "yyyy-MM-dd"
        return output.string(from: date)
    }
    
    private func dateComponents(
        from iso: String
    ) -> DateComponents {
        guard let date = dateFromIso(iso) else {
            return DateComponents()
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone =
            TimeZone(identifier: "Asia/Jerusalem") ?? .current

        return calendar.dateComponents(
            [.year, .month, .day],
            from: date
        )
    }

    private func uniqueMembers(
        _ rows: [AttendanceRowUi]
    ) -> [AttendanceRowUi] {
        func normalizedName(_ value: String) -> String {
            value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: "־", with: "-")
                .replacingOccurrences(of: "–", with: "-")
                .replacingOccurrences(of: "—", with: "-")
                .replacingOccurrences(
                    of: #"[."'׳״,;:()\[\]{}]"#,
                    with: "",
                    options: .regularExpression
                )
                .replacingOccurrences(
                    of: #"\s+"#,
                    with: " ",
                    options: .regularExpression
                )
        }

        func isPlaceholder(_ name: String) -> Bool {
            let key = normalizedName(name)

            return key.isEmpty ||
                key == "מתאמן" ||
                key.hasPrefix("מתאמן ") ||
                key.hasPrefix("מתאמן_") ||
                key == "demo" ||
                key.hasPrefix("demo ") ||
                key.hasPrefix("test trainee") ||
                key == "trainee" ||
                key.hasPrefix("trainee ")
        }

        func normalizedPhone(_ value: String) -> String {
            var digits = value.filter { $0.isNumber }

            if digits.hasPrefix("972") {
                digits = String(digits.dropFirst(3))
            }

            if digits.hasPrefix("0") {
                digits = String(digits.dropFirst())
            }

            return digits
        }

        var seen = Set<String>()
        var result: [AttendanceRowUi] = []

        for row in rows {
            /*
             * הסינון נעשה לפי השם המקורי.
             * שמות שמוצגים באמצעות DemoPrivacy
             * אינם משמשים לסינון או לזיהוי.
             */
            guard !isPlaceholder(row.memberName) else {
                continue
            }

            let phone = normalizedPhone(row.phone)
            let name = normalizedName(row.memberName)

            let key = phone.isEmpty
                ? "name:\(name)"
                : "phone:\(phone)"

            guard seen.insert(key).inserted else {
                continue
            }

            result.append(row)
        }

        return result.sorted {
            $0.memberName.localizedCaseInsensitiveCompare(
                $1.memberName
            ) == .orderedAscending
        }
    }
}

private struct AttendancePremiumDatePickerSheet: View {
    @Binding var selectedDate: Date

    let isEnglish: Bool
    let onCancel: () -> Void
    let onToday: () -> Void
    let onConfirm: () -> Void

    @Environment(\.colorScheme)
    private var colorScheme

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var title: String {
        isEnglish
            ? "Select attendance date"
            : "בחירת תאריך אימון"
    }

    private var sheetPrimaryTextColor: Color {
        KmiAppTheme.onSurface(
            for: colorScheme
        )
    }

    private var calendarSurfaceColor: Color {
        KmiAppTheme.surface(
            for: colorScheme
        )
        .opacity(0.97)
    }

    private var secondaryButtonColor: Color {
        KmiAppTheme.surfaceVariant(
            for: colorScheme
        )
    }

    var body: some View {
        ZStack {
            KmiAppBackground()

            ScrollView {
                VStack(spacing: 18) {
                    Text(title)
                    .kmiFont(
                        size: 22,
                        weight: .black
                    )
                    .foregroundStyle(sheetPrimaryTextColor)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .padding(.top, 6)

                    DatePicker(
                        isEnglish
                            ? "Attendance date"
                            : "תאריך אימון",
                        selection: $selectedDate,
                        displayedComponents: [.date]
                    )
                    .labelsHidden()
                .datePickerStyle(.graphical)
                .tint(
                    KmiAppTheme.secondary(
                        for: colorScheme
                    )
                )
                .padding(12)
                .background(
                    RoundedRectangle(
                        cornerRadius: 24,
                        style: .continuous
                    )
                    .fill(calendarSurfaceColor)
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 24,
                        style: .continuous
                    )
                    .stroke(
                        KmiAppTheme.outlineVariant(
                            for: colorScheme
                        ),
                        lineWidth: 1
                    )
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 24,
                        style: .continuous
                    )
                )

                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text(
                            isEnglish
                                ? "Cancel"
                                : "ביטול"
                        )
                        .kmiFont(
                            size: 15,
                            weight: .heavy
                        )
                        .foregroundStyle(sheetPrimaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .background(secondaryButtonColor)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 16,
                                style: .continuous
                            )
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: onToday) {
                        Text(
                            isEnglish
                                ? "Today"
                                : "היום"
                        )
                        .kmiFont(
                            size: 15,
                            weight: .heavy
                        )
                        .foregroundStyle(
                            KmiAppTheme.onSecondaryContainer(
                                for: colorScheme
                            )
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .background(
                            KmiAppTheme.secondaryContainer(
                                for: colorScheme
                            )
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 16,
                                style: .continuous
                            )
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: onConfirm) {
                        Text(
                            isEnglish
                                ? "Apply"
                                : "אישור"
                        )
                        .kmiFont(
                            size: 15,
                            weight: .heavy
                        )
                        .foregroundStyle(
                            KmiAppTheme.onSecondary(
                                for: colorScheme
                            )
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .background(
                            KmiAppTheme.secondary(
                                for: colorScheme
                            )
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 16,
                                style: .continuous
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
        .environment(
            \.layoutDirection,
            isEnglish ? .leftToRight : .rightToLeft
        )
        .environment(
            \.locale,
            Locale(
                identifier: isEnglish ? "en_US" : "he_IL"
            )
        )
        .environment(
            \.calendar,
            ShabbatHolidayCheckerIOS.calendar
        )
        .environment(
            \.timeZone,
            ShabbatHolidayCheckerIOS.timeZone
        )
    }
}

private struct AttendanceShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
    }
}

