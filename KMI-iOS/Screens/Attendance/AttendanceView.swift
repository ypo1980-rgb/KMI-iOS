import SwiftUI
import FirebaseAuth
import UIKit

struct AttendanceView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var vm: AttendanceViewModel

    @State private var toastMessage: String?
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

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
                    if showsInternalTopStrip {
                        attendanceTopStrip
                    }

                    attendanceHeroCard
                    attendanceSummaryCard

                    if isAddMemberExpanded {
                        addMemberCard
                    }

                    Text(tr("סימון נוכחות למתאמנים", "Mark trainee attendance"))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(red: 0.93, green: 1.0, blue: 1.0))
                        .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                        .multilineTextAlignment(screenTextAlignment)
                        .padding(.horizontal, 2)
                        .padding(.top, 2)

                    membersCard

                    actionsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 130)
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
                        .font(.subheadline.weight(.bold))
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
            Text(deleteConfirmationMessage)
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

    private var deleteConfirmationMessage: String {
        let fallback = tr("המתאמן", "this trainee")
        let name = pendingDeleteRow?.memberName.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = (name?.isEmpty == false) ? (name ?? fallback) : fallback

        return isEnglish
            ? "Delete \(displayName) from the list?"
            : "האם למחוק את \(displayName) מהרשימה?"
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
    private var attendanceTopStrip: some View {
        VStack(spacing: 10) {
            KmiIconStripBar(
                items: [.share, .assistant, .settings, .home, .search],
                selected: nil
            ) { item in
                switch item {
                case .share:
                    shareReport()

                case .assistant:
                    onAssistantTap()

                case .settings:
                    onSettingsTap()

                case .home:
                    onHomeTap()

                case .search:
                    onSearchTap()
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 5)

            HStack(spacing: 10) {
                if isEnglish {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tr("ניהול נוכחות", "Attendance management"))
                            .font(.system(size: 21, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text(tr("סימון, שמירה ושיתוף דו״ח נוכחות", "Mark, save and share an attendance report"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.74))
                    }

                    Spacer()

                    Image(systemName: "checklist")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.13))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                } else {
                    Image(systemName: "checklist")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.13))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(tr("ניהול נוכחות", "Attendance management"))
                            .font(.system(size: 21, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text(tr("סימון, שמירה ושיתוף דו״ח נוכחות", "Mark, save and share an attendance report"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.74))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 2)
        }
    }
    
    private var attendanceHeroCard: some View {
        let summary = vm.state.summary
        let branch = vm.state.branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        let group = vm.state.groupKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let dateText = formattedDate(vm.state.dateIso)

        return VStack(alignment: screenHorizontalAlignment, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                if isEnglish {
                    heroIcon

                    VStack(alignment: .leading, spacing: 5) {
                        Text(tr("נוכחות", "Attendance"))
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(dateText)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(red: 0.86, green: 0.94, blue: 1.0))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("\(branch.isEmpty ? tr("לא נבחר סניף", "No branch selected") : branch) · \(group.isEmpty ? tr("לא נבחרה קבוצה", "No group selected") : group)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    heroIcon

                    Spacer()

                    VStack(alignment: .trailing, spacing: 5) {
                        Text(tr("נוכחות", "Attendance"))
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Text(dateText)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(red: 0.86, green: 0.94, blue: 1.0))
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Text("\(branch.isEmpty ? tr("לא נבחר סניף", "No branch selected") : branch) · \(group.isEmpty ? tr("לא נבחרה קבוצה", "No group selected") : group)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }

            HStack(spacing: 10) {
                VStack(spacing: 4) {
                    Text("\(summary.totalMembers)")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text(tr("מתאמנים", "Trainees"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(spacing: 4) {
                    Text("\(summary.attendancePercent)%")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text(tr("נוכחות", "Attendance"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.06, green: 0.65, blue: 0.91).opacity(0.85),
                            Color(red: 0.13, green: 0.83, blue: 0.93).opacity(0.75)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if !vm.state.reportDaysInMonth.isEmpty {
                Text(
                    isEnglish
                    ? "This month has \(vm.state.reportDaysInMonth.count) saved report days"
                    : "בחודש הנוכחי קיימים \(vm.state.reportDaysInMonth.count) ימים עם דו״ח שמור"
                )
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)
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

    private var heroIcon: some View {
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
            .frame(width: 52, height: 52)
            .overlay(
                Image(systemName: "person.3.fill")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(.white)
            )
            .shadow(color: Color.cyan.opacity(0.35), radius: 10, x: 0, y: 4)
    }
    
    private var attendanceSummaryCard: some View {
        let summary = vm.state.summary
        let pct = max(0.0, min(100.0, Double(summary.attendancePercent)))

        return VStack(alignment: screenHorizontalAlignment, spacing: 14) {
            HStack {
                if isEnglish {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tr("סיכום נוכחות", "Attendance summary"))
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(.white)

                        Text(tr("נתוני היום הנוכחי", "Current class data"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.68))
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
                        Text(tr("סיכום נוכחות", "Attendance summary"))
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(.white)

                        Text(tr("נתוני היום הנוכחי", "Current class data"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.68))
                    }
                }
            }

            VStack(alignment: screenHorizontalAlignment, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    if isEnglish {
                        Text(tr("אחוז נוכחות", "Attendance rate"))
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Color(red: 0.86, green: 0.94, blue: 1.0))

                        Spacer()

                        Text("\(summary.attendancePercent)%")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    } else {
                        Text("\(summary.attendancePercent)%")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Spacer()

                        Text(tr("אחוז נוכחות", "Attendance rate"))
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Color(red: 0.86, green: 0.94, blue: 1.0))
                    }
                }

                ProgressView(value: pct, total: 100)
                    .progressViewStyle(.linear)
                    .tint(Color(red: 0.13, green: 0.83, blue: 0.93))
                    .background(Color.white.opacity(0.14))
                    .clipShape(Capsule())
            }
            .padding(14)
            .background(Color.white.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
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
        .background(Color.white.opacity(0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    
    private var addMemberCard: some View {
        VStack(alignment: screenHorizontalAlignment, spacing: 12) {
            HStack {
                if isEnglish {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tr("הוספת מתאמן", "Add trainee"))
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(.white)

                        Text(tr("רשימת המתאמנים נטענת לפי סניף וקבוצה", "The trainee list loads by branch and group"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.68))
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
                        Text(tr("הוספת מתאמן", "Add trainee"))
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(.white)

                        Text(tr("רשימת המתאמנים נטענת לפי סניף וקבוצה", "The trainee list loads by branch and group"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.68))
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
                    Text(tr("הוסף מתאמן", "Add trainee"))
                }
                .font(.system(size: 16, weight: .heavy))
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
        .background(Color.white.opacity(0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    private var membersCard: some View {
        VStack(alignment: screenHorizontalAlignment, spacing: 12) {
            HStack {
                if isEnglish {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tr("רשימת מתאמנים", "Trainee list"))
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(.white)

                        Text(vm.state.rows.isEmpty ? tr("אין מתאמנים עדיין", "No trainees yet") : tr("סמן נוכחות לכל מתאמן", "Mark attendance for each trainee"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.68))
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
                        Text(tr("רשימת מתאמנים", "Trainee list"))
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(.white)

                        Text(vm.state.rows.isEmpty ? tr("אין מתאמנים עדיין", "No trainees yet") : tr("סמן נוכחות לכל מתאמן", "Mark attendance for each trainee"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.68))
                    }
                }
            }

            if vm.state.rows.isEmpty {
                Text(tr("לא נוספו מתאמנים לסניף ולקבוצה שנבחרו.", "No trainees were added for the selected branch and group."))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                    .multilineTextAlignment(screenTextAlignment)
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
        .padding(16)
        .background(Color.white.opacity(0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    
    private var actionsCard: some View {
        VStack(alignment: screenHorizontalAlignment, spacing: 12) {
            HStack {
                if isEnglish {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tr("פעולות", "Actions"))
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(.white)

                        Text(tr("שמירה, שיתוף וסטטיסטיקה של דו״ח הנוכחות", "Save, share and view attendance report statistics"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.68))
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
                        Text(tr("פעולות", "Actions"))
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(.white)

                        Text(tr("שמירה, שיתוף וסטטיסטיקה של דו״ח הנוכחות", "Save, share and view attendance report statistics"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.68))
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
                    Text(vm.state.isSaving ? tr("שומר...", "Saving...") : tr("שמירת דו״ח נוכחות", "Save attendance report"))
                }
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
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
        .padding(16)
        .background(Color.white.opacity(0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    
    private func memberRow(_ row: AttendanceRowUi) -> some View {
        VStack(alignment: screenHorizontalAlignment, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                if isEnglish {
                    NavigationLink {
                        AttendanceStatsView(
                            ownerUid: vm.state.ownerUid,
                            branchName: vm.state.branchName,
                            groupKey: vm.state.groupKey,
                            memberId: row.memberId,
                            memberName: row.memberName
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.memberName.isEmpty ? tr("מתאמן ללא שם", "Unnamed trainee") : row.memberName)
                                .font(.system(size: 17, weight: .heavy))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if !row.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(row.phone)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.72))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    deleteMemberButton(row)
                } else {
                    deleteMemberButton(row)

                    Spacer()

                    NavigationLink {
                        AttendanceStatsView(
                            ownerUid: vm.state.ownerUid,
                            branchName: vm.state.branchName,
                            groupKey: vm.state.groupKey,
                            memberId: row.memberId,
                            memberName: row.memberName
                        )
                    } label: {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(row.memberName.isEmpty ? tr("מתאמן ללא שם", "Unnamed trainee") : row.memberName)
                                .font(.system(size: 17, weight: .heavy))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                                .frame(maxWidth: .infinity, alignment: .trailing)

                            if !row.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(row.phone)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.72))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                statusButton(
                    title: tr("הגיע", "Present"),
                    selected: row.status == .present,
                    selectedColor: Color(red: 0.13, green: 0.77, blue: 0.37)
                ) {
                    vm.setAttendanceStatus(memberId: row.memberId, status: .present)
                }

                statusButton(
                    title: tr("מוצדק", "Excused"),
                    selected: row.status == .excused,
                    selectedColor: Color(red: 0.96, green: 0.62, blue: 0.04)
                ) {
                    vm.setAttendanceStatus(memberId: row.memberId, status: .excused)
                }

                statusButton(
                    title: tr("לא הגיע", "Absent"),
                    selected: row.status == .absent,
                    selectedColor: Color(red: 0.94, green: 0.27, blue: 0.27)
                ) {
                    vm.setAttendanceStatus(memberId: row.memberId, status: .absent)
                }

                statusButton(
                    title: tr("נקה", "Clear"),
                    selected: row.status == .unknown,
                    selectedColor: Color(red: 0.38, green: 0.45, blue: 0.55)
                ) {
                    vm.setAttendanceStatus(memberId: row.memberId, status: .unknown)
                }
            }

            TextField(
                tr("הערת נוכחות", "Attendance note"),
                text: Binding(
                    get: { row.attendanceNote },
                    set: { vm.setAttendanceNote(memberId: row.memberId, note: $0) }
                ),
                axis: .vertical
            )
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .multilineTextAlignment(screenTextAlignment)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func deleteMemberButton(_ row: AttendanceRowUi) -> some View {
        Button {
            pendingDeleteRow = row
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(red: 0.98, green: 0.45, blue: 0.45))
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.10))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    private func statusButton(
        title: String,
        selected: Bool,
        selectedColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? selectedColor : Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(selected ? Color.white.opacity(0.28) : Color.white.opacity(0.10), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
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

    private func attendanceTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text, axis: .vertical)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.11))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .multilineTextAlignment(screenTextAlignment)
    }

    private func secondaryActionButton(icon: String, title: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 14, weight: .heavy))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
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
            let nameKey = row.memberName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            let phoneKey = row.phone
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            let key = phoneKey.isEmpty ? nameKey : "\(nameKey)|\(phoneKey)"

            guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
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

