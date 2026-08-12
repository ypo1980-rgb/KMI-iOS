import SwiftUI
import FirebaseAuth
import UIKit

struct AttendanceView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var vm: AttendanceViewModel

    @State private var toastMessage: String?
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

    @State private var showDatePickerSheet = false
    @State private var draftAttendanceDate = Date()

    @State private var newMemberName: String = ""
    @State private var newMemberPhone: String = ""
    @State private var newMemberNotes: String = ""
    @State private var isAddMemberExpanded: Bool = false

    @State private var pendingDeleteRow: AttendanceRowUi? = nil

    private let onHomeTap: () -> Void
    private let onSearchTap: () -> Void
    private let onSettingsTap: () -> Void
    private let onAssistantTap: () -> Void
    private let showsInternalTopStrip: Bool

    private var isEnglish: Bool {
        let defaults = UserDefaults.standard

        let keys = [
            "kmi_app_language",
            "app_language",
            "initial_language_code",
            "initial_language_selected_code",
            "kmi.language.code"
        ]

        for key in keys {
            let value = (defaults.string(forKey: key) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            if value == "en" || value == "english" {
                return true
            }

            if value == "he" || value == "hebrew" {
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

    private var primaryTextColor: Color {
        isDarkMode
            ? Color.white.opacity(0.94)
            : Color(red: 0.12, green: 0.16, blue: 0.24)
    }

    private var secondaryTextColor: Color {
        isDarkMode
            ? Color.white.opacity(0.68)
            : Color(red: 0.32, green: 0.38, blue: 0.48)
    }

    private var cardSurfaceColor: Color {
        isDarkMode
            ? Color(red: 0.06, green: 0.09, blue: 0.15).opacity(0.96)
            : Color.white.opacity(0.96)
    }

    private var elevatedSurfaceColor: Color {
        isDarkMode
            ? Color(red: 0.09, green: 0.13, blue: 0.21)
            : Color(red: 0.95, green: 0.97, blue: 1.0)
    }

    private var cardBorderColor: Color {
        isDarkMode
            ? Color.white.opacity(0.14)
            : Color.black.opacity(0.08)
    }

    private var fieldSurfaceColor: Color {
        isDarkMode
            ? Color.white.opacity(0.08)
            : Color.white.opacity(0.88)
    }

    private var fieldIconSurfaceColor: Color {
        isDarkMode
            ? Color(red: 0.10, green: 0.29, blue: 0.44)
            : Color(red: 0.88, green: 0.96, blue: 1.0)
    }

    private var fieldIconColor: Color {
        isDarkMode
            ? Color(red: 0.35, green: 0.83, blue: 0.96)
            : Color(red: 0.07, green: 0.45, blue: 0.72)
    }

    private func tr(_ he: String, _ en: String) -> String {
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
            LinearGradient(
                colors:
                    isDarkMode
                    ? [
                        Color(red: 0.008, green: 0.024, blue: 0.090),
                        Color(red: 0.067, green: 0.094, blue: 0.153),
                        Color(red: 0.063, green: 0.141, blue: 0.227),
                        Color(red: 0.039, green: 0.212, blue: 0.341),
                        Color(red: 0.016, green: 0.118, blue: 0.200)
                    ]
                    : [
                        Color(red: 0.96, green: 0.94, blue: 1.0),
                        Color(red: 0.91, green: 0.96, blue: 1.0),
                        Color(red: 0.82, green: 0.94, blue: 1.0),
                        Color(red: 0.69, green: 0.88, blue: 0.96)
                    ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 10) {
                    attendanceHeroCard
                    attendanceSummaryCard

                    if isAddMemberExpanded {
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

            VStack {
                Spacer()

                HStack {
                    if isEnglish {
                        addMemberFloatingButton

                        Spacer()
                    } else {
                        Spacer()

                        addMemberFloatingButton
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
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
        .sheet(isPresented: $showShareSheet) {
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
                    draftAttendanceDate = Date()
                    vm.setDateIso(isoString(from: Date()))
                    showDatePickerSheet = false
                },
                onConfirm: {
                    vm.setDateIso(isoString(from: draftAttendanceDate))
                    showDatePickerSheet = false
                }
            )
            .presentationDetents([.medium])
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
                guard let row = pendingDeleteRow else { return }
                vm.removeMember(memberId: row.memberId)
                pendingDeleteRow = nil
            }

            Button(tr("ביטול", "Cancel"), role: .cancel) {
                pendingDeleteRow = nil
            }
        } message: {
            Text(
                isEnglish
                ? "Delete \(pendingDeleteRow?.memberName ?? "this trainee") from the list?"
                : "האם למחוק את \(pendingDeleteRow?.memberName ?? "המתאמן") מהרשימה?"
            )
        }
        .onChange(of: vm.state.messageEventId) { _, _ in
            guard let msg = vm.state.lastMessage else { return }
            withAnimation {
                toastMessage = msg
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    toastMessage = nil
                }
            }
        }
        .onAppear {
            let storedBranch = UserDefaults.standard.string(forKey: "kmi.user.branch") ?? ""
            let storedGroup = UserDefaults.standard.string(forKey: "kmi.user.group") ?? ""
            let resolvedBranch =
                auth.userBranch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? storedBranch
                : auth.userBranch

            let resolvedGroup =
                auth.userGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? storedGroup
                : auth.userGroup

            let resolvedCoachName =
                auth.userFullName.trimmingCharacters(in: .whitespacesAndNewlines)

            if vm.state.branchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !resolvedBranch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                vm.setBranchName(resolvedBranch)
            }

            if vm.state.groupKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !resolvedGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                vm.setGroupKey(resolvedGroup)
            }

            if vm.state.coachName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !resolvedCoachName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                vm.setCoachName(resolvedCoachName)
            }

            let comps = dateComponents(from: vm.state.dateIso)
            if let year = comps.year, let month = comps.month {
                vm.loadSummaryDaysForMonth(year: year, month1to12: month)
            }
        }
        .onChange(of: auth.userBranch) { _, newValue in
            let clean = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if vm.state.branchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !clean.isEmpty {
                vm.setBranchName(clean)
            }
        }
        .onChange(of: vm.state.branchName) { _, newValue in
            let cleanBranch = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanGroup = vm.state.groupKey.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !cleanBranch.isEmpty, !cleanGroup.isEmpty else { return }
            guard cleanBranch != auth.userBranch || cleanGroup != auth.userGroup else { return }

            auth.saveTrainingAssignment(branch: cleanBranch, group: cleanGroup)
        }
        
        .onChange(of: auth.userGroup) { _, newValue in
            let clean = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if vm.state.groupKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !clean.isEmpty {
                vm.setGroupKey(clean)
            }
        }
        .onChange(of: vm.state.groupKey) { _, newValue in
            let cleanGroup = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanBranch = vm.state.branchName.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !cleanBranch.isEmpty, !cleanGroup.isEmpty else { return }
            guard cleanBranch != auth.userBranch || cleanGroup != auth.userGroup else { return }

            auth.saveTrainingAssignment(branch: cleanBranch, group: cleanGroup)
        }
        
        .onChange(of: auth.userFullName) { _, newValue in
            let clean = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if vm.state.coachName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !clean.isEmpty {
                vm.setCoachName(clean)
            }
        }
    }
    
    private var addMemberFloatingButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                isAddMemberExpanded.toggle()
            }
        } label: {
            Image(systemName: isAddMemberExpanded ? "xmark" : "plus")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(Color(red: 0.06, green: 0.65, blue: 0.91))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.24), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.28), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tr("הוספת מתאמן", "Add trainee"))
    }
    
    private var attendanceHeroCard: some View {
        let branch =
            vm.state.branchName
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        let group =
            vm.state.groupKey
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        let dateText = formattedDate(vm.state.dateIso)
        let total = vm.state.summary.totalMembers

        return VStack(
            alignment: screenHorizontalAlignment,
            spacing: 12
        ) {
            Text(
                tr(
                    "בחירת אימון לנוכחות",
                    "Select attendance class"
                )
            )
            .kmiFont(
                size: 20,
                weight: .black
            )
            .foregroundStyle(primaryTextColor)
            .frame(
                maxWidth: .infinity,
                alignment: .center
            )
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.74)

            Button {
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

            premiumSelectionField(
                label: tr("סניף", "Branch"),
                value:
                    branch.isEmpty
                    ? tr(
                        "לא נבחר סניף",
                        "No branch selected"
                    )
                    : branch,
                icon: "mappin.and.ellipse",
                trailingIcon: nil
            )

            premiumSelectionField(
                label: tr("קבוצה", "Group"),
                value:
                    group.isEmpty
                    ? tr(
                        "לא נבחרה קבוצה",
                        "No group selected"
                    )
                    : group,
                icon: "person.3.fill",
                trailingIcon: nil
            )

            Text(
                isEnglish
                ? "The list loads by date + branch + group · trainees in class: \(total)"
                : "הרשימה נטענת לפי תאריך + סניף + קבוצה · מתאמנים בשיעור: \(total)"
            )
            .kmiFont(
                size: 12,
                weight: .bold
            )
            .foregroundStyle(secondaryTextColor)
            .frame(
                maxWidth: .infinity,
                alignment: screenFrameAlignment
            )
            .multilineTextAlignment(
                screenTextAlignment
            )
            .lineLimit(3)
            .minimumScaleFactor(0.74)
            .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .fill(cardSurfaceColor)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .stroke(
                cardBorderColor,
                lineWidth: 1
            )
        )
        .shadow(
            color: Color.black.opacity(
                isDarkMode ? 0.28 : 0.14
            ),
            radius: 10,
            x: 0,
            y: 6
        )
    }
    
    private func premiumSelectionField(
        label: String,
        value: String,
        icon: String,
        trailingIcon: String?
    ) -> some View {
        HStack(spacing: 10) {
            if isEnglish {
                fieldIcon(icon)

                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .kmiFont(
                            size: 11,
                            weight: .bold
                        )
                        .foregroundStyle(secondaryTextColor)

                    Text(value.isEmpty ? "—" : value)
                        .kmiFont(
                            size: 14,
                            weight: .black
                        )
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let trailingIcon {
                    Image(systemName: trailingIcon)
                        .font(
                            .system(
                                size: 13,
                                weight: .black
                            )
                        )
                        .foregroundStyle(fieldIconColor)
                }
            } else {
                if let trailingIcon {
                    Image(systemName: trailingIcon)
                        .font(
                            .system(
                                size: 13,
                                weight: .black
                            )
                        )
                        .foregroundStyle(fieldIconColor)
                }

                VStack(alignment: .trailing, spacing: 3) {
                    Text(label)
                        .kmiFont(
                            size: 11,
                            weight: .bold
                        )
                        .foregroundStyle(secondaryTextColor)

                    Text(value.isEmpty ? "—" : value)
                        .kmiFont(
                            size: 14,
                            weight: .black
                        )
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.74)
                        .multilineTextAlignment(.trailing)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                fieldIcon(icon)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(fieldSurfaceColor)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 17,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 17,
                style: .continuous
            )
            .stroke(
                cardBorderColor,
                lineWidth: 1
            )
        )
    }

    private func fieldIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(
                .system(
                    size: 14,
                    weight: .heavy
                )
            )
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
    
    private var attendanceSummaryCard: some View {
        let summary = vm.state.summary
        let pct = max(0.0, min(100.0, Double(summary.attendancePercent)))

        return VStack(alignment: screenHorizontalAlignment, spacing: 14) {
            HStack {
                if isEnglish {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(
                            tr(
                                "סיכום נוכחות",
                                "Attendance summary"
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
                                "נתוני היום הנוכחי",
                                "Current class data"
                            )
                        )
                        .kmiFont(
                            size: 12,
                            weight: .semibold
                        )
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.74)
                    }

                    Spacer()

                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Color(red: 0.58, green: 0.78, blue: 1.0))
                } else {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Color(red: 0.58, green: 0.78, blue: 1.0))

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(
                            tr(
                                "סיכום נוכחות",
                                "Attendance summary"
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
                                "נתוני היום הנוכחי",
                                "Current class data"
                            )
                        )
                        .kmiFont(
                            size: 12,
                            weight: .semibold
                        )
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.74)
                    }
                }
            }

            VStack(alignment: screenHorizontalAlignment, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    if isEnglish {
                        Text(
                            tr(
                                "אחוז נוכחות",
                                "Attendance rate"
                            )
                        )
                        .kmiFont(
                            size: 13,
                            weight: .heavy
                        )
                        .foregroundStyle(
                            isDarkMode
                                ? Color(red: 0.68, green: 0.88, blue: 1.0)
                                : Color(red: 0.10, green: 0.38, blue: 0.66)
                        )

                        Spacer()

                        Text("\(summary.attendancePercent)%")
                            .kmiFont(
                                size: 28,
                                weight: .black
                            )
                            .foregroundStyle(primaryTextColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    } else {
                        Text("\(summary.attendancePercent)%")
                            .kmiFont(
                                size: 28,
                                weight: .black
                            )
                            .foregroundStyle(primaryTextColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Spacer()

                        Text(
                            tr(
                                "אחוז נוכחות",
                                "Attendance rate"
                            )
                        )
                        .kmiFont(
                            size: 13,
                            weight: .heavy
                        )
                        .foregroundStyle(
                            isDarkMode
                                ? Color(
                                    red: 0.68,
                                    green: 0.88,
                                    blue: 1.0
                                )
                                : Color(
                                    red: 0.10,
                                    green: 0.38,
                                    blue: 0.66
                                )
                        )
                    }
                }

                ProgressView(
                    value: pct,
                    total: 100
                )
                .progressViewStyle(.linear)
                .tint(
                    Color(
                        red: 0.13,
                        green: 0.83,
                        blue: 0.93
                    )
                )
                .background(
                    isDarkMode
                        ? Color.white.opacity(0.14)
                        : Color.black.opacity(0.10)
                )
                .clipShape(Capsule())
            }
            .padding(14)
            .background(elevatedSurfaceColor)
            .clipShape(
                RoundedRectangle(
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
                    cardBorderColor,
                    lineWidth: 1
                )
            )

            HStack(spacing: 10) {
                statPill(title: tr("סה״כ", "Total"), value: "\(summary.totalMembers)", tint: Color(red: 0.59, green: 0.70, blue: 1.0))
                statPill(title: tr("הגיעו", "Present"), value: summary.presentLabel, tint: Color(red: 0.13, green: 0.77, blue: 0.37))
                statPill(title: tr("מוצדק", "Excused"), value: summary.excusedLabel, tint: Color(red: 0.96, green: 0.62, blue: 0.04))
                statPill(title: tr("לא הגיעו", "Absent"), value: summary.absentLabel, tint: Color(red: 0.94, green: 0.27, blue: 0.27))
            }

            statPill(
                title: tr("לא סומנו", "Not marked"),
                value: summary.unknownLabel,
                tint: Color.white.opacity(0.65)
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
        .shadow(
            color: Color.black.opacity(
                isDarkMode ? 0.24 : 0.10
            ),
            radius: 8,
            x: 0,
            y: 4
        )
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
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(red: 0.58, green: 0.78, blue: 1.0))
                } else {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(red: 0.58, green: 0.78, blue: 1.0))

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

            attendanceTextField(tr("שם מלא", "Full name"), text: $newMemberName)
            attendanceTextField(tr("טלפון", "Phone"), text: $newMemberPhone)
            attendanceTextField(tr("הערות", "Notes"), text: $newMemberNotes)

            Button {
                vm.addMember(
                    fullName: newMemberName,
                    phone: newMemberPhone,
                    notes: newMemberNotes
                )

                newMemberName = ""
                newMemberPhone = ""
                newMemberNotes = ""

                withAnimation(.easeInOut(duration: 0.22)) {
                    isAddMemberExpanded = false
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")

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
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color(red: 0.06, green: 0.65, blue: 0.91))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(newMemberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(newMemberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1.0)
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
        .shadow(
            color: Color.black.opacity(
                isDarkMode ? 0.24 : 0.10
            ),
            radius: 8,
            x: 0,
            y: 4
        )
        .transition(
            .move(edge: .top)
                .combined(with: .opacity)
        )
    }
    
    private var membersCard: some View {
        VStack(alignment: screenHorizontalAlignment, spacing: 12) {
            HStack {
                if isEnglish {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(
                            tr(
                                "רשימת מתאמנים",
                                "Trainee list"
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
                            vm.state.rows.isEmpty
                                ? tr(
                                    "אין מתאמנים עדיין",
                                    "No trainees yet"
                                )
                                : tr(
                                    "סמן נוכחות לכל מתאמן",
                                    "Mark attendance for each trainee"
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

                    Image(systemName: "person.3.fill")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Color(red: 0.58, green: 0.78, blue: 1.0))
                } else {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Color(red: 0.58, green: 0.78, blue: 1.0))

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(
                            tr(
                                "רשימת מתאמנים",
                                "Trainee list"
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
                            vm.state.rows.isEmpty
                                ? tr(
                                    "אין מתאמנים עדיין",
                                    "No trainees yet"
                                )
                                : tr(
                                    "סמן נוכחות לכל מתאמן",
                                    "Mark attendance for each trainee"
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

            if vm.state.rows.isEmpty {
                Text(
                    tr(
                        "לא נוספו מתאמנים לסניף ולקבוצה שנבחרו.",
                        "No trainees were added for the selected branch and group."
                    )
                )
                .kmiFont(
                    size: 14,
                    weight: .semibold
                )
                .foregroundStyle(secondaryTextColor)
                .frame(
                    maxWidth: .infinity,
                    alignment: screenFrameAlignment
                )
                .multilineTextAlignment(screenTextAlignment)
                .lineLimit(4)
                .minimumScaleFactor(0.74)
                .padding(.vertical, 10)
            } else {
                let uniqueRows = uniqueMembers(vm.state.rows)

                VStack(spacing: 10) {
                    ForEach(uniqueRows) { row in
                        memberRow(row)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .fill(cardSurfaceColor)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .stroke(
                cardBorderColor,
                lineWidth: 1
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
        )
        .shadow(
            color: Color.black.opacity(
                isDarkMode ? 0.24 : 0.10
            ),
            radius: 8,
            x: 0,
            y: 4
        )
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
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Color(red: 0.58, green: 0.78, blue: 1.0))
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Color(red: 0.58, green: 0.78, blue: 1.0))

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

                Button {
                    shareReport()
                } label: {
                    secondaryActionButton(icon: "square.and.arrow.up", title: tr("שתף", "Share"))
                }
                .buttonStyle(.plain)
            }

            Button {
                vm.saveReport()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")

                    Text(
                        vm.state.isSaving
                            ? tr(
                                "שומר...",
                                "Saving..."
                            )
                            : tr(
                                "שמירת דו״ח נוכחות",
                                "Save attendance report"
                            )
                    )
                    .kmiFont(
                        size: 15,
                        weight: .heavy
                    )
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.06, green: 0.65, blue: 0.91),
                            Color(red: 0.13, green: 0.83, blue: 0.93)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: Color.cyan.opacity(0.22), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(vm.state.isSaving)
            .opacity(vm.state.isSaving ? 0.65 : 1.0)
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
        .shadow(
            color: Color.black.opacity(
                isDarkMode ? 0.24 : 0.10
            ),
            radius: 8,
            x: 0,
            y: 4
        )
    }
    
    private func toggleAttendanceStatus(
        row: AttendanceRowUi,
        targetStatus: AttendanceStatus
    ) {
        let nextStatus: AttendanceStatus = row.status == targetStatus ? .unknown : targetStatus
        vm.setAttendanceStatus(memberId: row.memberId, status: nextStatus)
    }

    private func memberRow(_ row: AttendanceRowUi) -> some View {
        let cleanName = row.memberName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPhone = row.phone.trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(alignment: screenHorizontalAlignment, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                if isEnglish {
                    traineeAvatar(row)

                    NavigationLink {
                        AttendanceStatsView(
                            ownerUid: vm.state.ownerUid,
                            branchName: vm.state.branchName,
                            groupKey: vm.state.groupKey,
                            memberId: row.memberId,
                            memberName: row.memberName
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(
                                cleanName.isEmpty
                                    ? tr(
                                        "מתאמן ללא שם",
                                        "Unnamed trainee"
                                    )
                                    : cleanName
                            )
                            .kmiFont(
                                size: 16,
                                weight: .black
                            )
                            .foregroundStyle(primaryTextColor)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if !cleanPhone.isEmpty {
                                Text(cleanPhone)
                                    .kmiFont(
                                        size: 11.5,
                                        weight: .semibold
                                    )
                                    .foregroundStyle(secondaryTextColor)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.74)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text(
                                    tr(
                                        "לחץ לפתיחת סטטיסטיקה",
                                        "Tap for statistics"
                                    )
                                )
                                .kmiFont(
                                    size: 11.5,
                                    weight: .semibold
                                )
                                .foregroundStyle(secondaryTextColor)
                                .lineLimit(2)
                                .minimumScaleFactor(0.72)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    deleteMemberButton(row)
                } else {
                    deleteMemberButton(row)

                    NavigationLink {
                        AttendanceStatsView(
                            ownerUid: vm.state.ownerUid,
                            branchName: vm.state.branchName,
                            groupKey: vm.state.groupKey,
                            memberId: row.memberId,
                            memberName: row.memberName
                        )
                    } label: {
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(
                                cleanName.isEmpty
                                    ? tr(
                                        "מתאמן ללא שם",
                                        "Unnamed trainee"
                                    )
                                    : cleanName
                            )
                            .kmiFont(
                                size: 16,
                                weight: .black
                            )
                            .foregroundStyle(primaryTextColor)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .trailing
                            )

                            if !cleanPhone.isEmpty {
                                Text(cleanPhone)
                                    .kmiFont(
                                        size: 11.5,
                                        weight: .semibold
                                    )
                                    .foregroundStyle(secondaryTextColor)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.74)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            } else {
                                Text(
                                    tr(
                                        "לחץ לפתיחת סטטיסטיקה",
                                        "Tap for statistics"
                                    )
                                )
                                .kmiFont(
                                    size: 11.5,
                                    weight: .semibold
                                )
                                .foregroundStyle(secondaryTextColor)
                                .lineLimit(2)
                                .minimumScaleFactor(0.72)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    traineeAvatar(row)
                }
            }

            HStack(spacing: 6) {
                statusButton(
                    title: tr("הגיע", "Present"),
                    icon: "checkmark.circle.fill",
                    selected: row.status == .present,
                    selectedColor: Color(red: 0.13, green: 0.77, blue: 0.37)
                ) {
                    toggleAttendanceStatus(row: row, targetStatus: .present)
                }

                statusButton(
                    title: tr("מוצדק", "Excused"),
                    icon: "clock.badge.checkmark",
                    selected: row.status == .excused,
                    selectedColor: Color(red: 0.96, green: 0.62, blue: 0.04)
                ) {
                    toggleAttendanceStatus(row: row, targetStatus: .excused)
                }

                statusButton(
                    title: tr("לא הגיע", "Absent"),
                    icon: "xmark.circle.fill",
                    selected: row.status == .absent,
                    selectedColor: Color(red: 0.94, green: 0.27, blue: 0.27)
                ) {
                    toggleAttendanceStatus(row: row, targetStatus: .absent)
                }

                statusButton(
                    title: tr("נקה", "Clear"),
                    icon: "minus.circle.fill",
                    selected: row.status == .unknown,
                    selectedColor: Color(red: 0.38, green: 0.45, blue: 0.55)
                ) {
                    vm.setAttendanceStatus(memberId: row.memberId, status: .unknown)
                }
            }

            TextField(
                tr(
                    "הערת נוכחות",
                    "Attendance note"
                ),
                text: Binding(
                    get: {
                        row.attendanceNote
                    },
                    set: {
                        vm.setAttendanceNote(
                            memberId: row.memberId,
                            note: $0
                        )
                    }
                ),
                axis: .vertical
            )
            .kmiFont(
                size: 12.5,
                weight: .semibold
            )
            .foregroundStyle(primaryTextColor)
            .lineLimit(1...4)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(fieldSurfaceColor)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 13,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 13,
                    style: .continuous
                )
                .stroke(
                    cardBorderColor,
                    lineWidth: 1
                )
            )
            .multilineTextAlignment(screenTextAlignment)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .fill(elevatedSurfaceColor)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(
                isDarkMode
                    ? Color(red: 0.35, green: 0.72, blue: 0.94)
                        .opacity(0.32)
                    : Color(red: 0.55, green: 0.82, blue: 0.96),
                lineWidth: 1
            )
        )
        .shadow(
            color: Color.black.opacity(
                isDarkMode ? 0.24 : 0.12
            ),
            radius: 8,
            x: 0,
            y: 5
        )
    }
    
    private func traineeAvatar(_ row: AttendanceRowUi) -> some View {
        let tint: Color = {
            switch row.status {
            case .present:
                return Color(red: 0.13, green: 0.77, blue: 0.37)
            case .excused:
                return Color(red: 0.96, green: 0.62, blue: 0.04)
            case .absent:
                return Color(red: 0.94, green: 0.27, blue: 0.27)
            default:
                return Color(red: 0.38, green: 0.45, blue: 0.55)
            }
        }()

        return ZStack {
            Circle()
                .fill(tint.opacity(0.14))

            Image(systemName: "person.fill")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(tint)
        }
        .frame(width: 38, height: 38)
        .overlay(
            Circle()
                .stroke(tint.opacity(0.28), lineWidth: 1)
        )
    }
    
    private func deleteMemberButton(
        _ row: AttendanceRowUi
    ) -> some View {
        Button {
            pendingDeleteRow = row
        } label: {
            Image(systemName: "trash.fill")
                .font(
                    .system(
                        size: 14,
                        weight: .black
                    )
                )
                .foregroundStyle(
                    isDarkMode
                        ? Color(red: 1.0, green: 0.48, blue: 0.48)
                        : Color(red: 0.86, green: 0.12, blue: 0.12)
                )
                .frame(width: 42, height: 42)
                .background(
                    isDarkMode
                        ? Color.red.opacity(0.16)
                        : Color(red: 1.0, green: 0.93, blue: 0.93)
                )
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            Color.red.opacity(
                                isDarkMode ? 0.34 : 0.24
                            ),
                            lineWidth: 1
                        )
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
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
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(
                        .system(
                            size: 14,
                            weight: .black
                        )
                    )

                Text(title)
                    .kmiFont(
                        size: 10.5,
                        weight: .black
                    )
                    .lineLimit(2)
                    .minimumScaleFactor(0.66)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(
                selected
                    ? Color.white
                    : selectedColor
            )
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .background(
                selected
                    ? selectedColor
                    : selectedColor.opacity(
                        isDarkMode ? 0.18 : 0.10
                    )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 13,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 13,
                    style: .continuous
                )
                .stroke(
                    selected
                        ? selectedColor.opacity(0.62)
                        : selectedColor.opacity(
                            isDarkMode ? 0.42 : 0.22
                        ),
                    lineWidth: 1
                )
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: 13,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
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
                    isDarkMode
                        ? Color.white
                        : primaryTextColor
                )
                .lineLimit(1)
                .minimumScaleFactor(0.70)

            Text(title)
                .kmiFont(
                    size: 11,
                    weight: .bold
                )
                .foregroundStyle(
                    isDarkMode
                        ? Color.white.opacity(0.78)
                        : secondaryTextColor
                )
                .lineLimit(2)
                .minimumScaleFactor(0.70)
                .multilineTextAlignment(.center)
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
        text: Binding<String>
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
        .multilineTextAlignment(screenTextAlignment)
    }

    private func secondaryActionButton(
        icon: String,
        title: String
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)

            Text(title)
                .kmiFont(
                    size: 14,
                    weight: .heavy
                )
                .lineLimit(2)
                .minimumScaleFactor(0.72)
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


    private func shareReport() {
        shareItems = [vm.state.shareText]
        showShareSheet = true
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

    private func dateFromIso(_ iso: String) -> Date? {
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd"
        return input.date(from: iso)
    }

    private func isoString(from date: Date) -> String {
        let output = DateFormatter()
        output.locale = Locale(identifier: "en_US_POSIX")
        output.dateFormat = "yyyy-MM-dd"
        return output.string(from: date)
    }
    
    private func dateComponents(from iso: String) -> DateComponents {
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: iso) else { return DateComponents() }
        return Calendar.current.dateComponents([.year, .month, .day], from: date)
    }

    private func uniqueMembers(_ rows: [AttendanceRowUi]) -> [AttendanceRowUi] {
        var unique: [String: AttendanceRowUi] = [:]

        for row in rows {
            let cleanPhone = row.phone
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .filter { $0.isNumber }

            let cleanName = row.memberName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            let key = cleanPhone.isEmpty ? cleanName : cleanPhone

            guard !key.isEmpty else {
                continue
            }

            if unique[key] == nil {
                unique[key] = row
            }
        }

        return unique.values.sorted {
            $0.memberName.localizedCaseInsensitiveCompare($1.memberName) == .orderedAscending
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
        isDarkMode
            ? Color.white.opacity(0.94)
            : Color(red: 0.10, green: 0.14, blue: 0.22)
    }

    private var calendarSurfaceColor: Color {
        isDarkMode
            ? Color(red: 0.08, green: 0.12, blue: 0.19)
            : Color.white.opacity(0.97)
    }

    private var secondaryButtonColor: Color {
        isDarkMode
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.07)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors:
                    isDarkMode
                    ? [
                        Color(red: 0.03, green: 0.07, blue: 0.14),
                        Color(red: 0.03, green: 0.18, blue: 0.30)
                    ]
                    : [
                        Color(red: 0.94, green: 0.96, blue: 1.0),
                        Color(red: 0.82, green: 0.93, blue: 0.98)
                    ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

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
                    "",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .tint(
                    Color(
                        red: 0.13,
                        green: 0.83,
                        blue: 0.93
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
                        isDarkMode
                            ? Color.white.opacity(0.14)
                            : Color.black.opacity(0.08),
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
                            Color(
                                red: 0.03,
                                green: 0.09,
                                blue: 0.18
                            )
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .background(
                            Color(
                                red: 0.13,
                                green: 0.83,
                                blue: 0.93
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
                            isDarkMode
                                ? Color(red: 0.03, green: 0.09, blue: 0.18)
                                : Color.white
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .background(
                            isDarkMode
                                ? Color.white
                                : Color(
                                    red: 0.17,
                                    green: 0.36,
                                    blue: 0.72
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
            .padding(.bottom, 16)
        }
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

