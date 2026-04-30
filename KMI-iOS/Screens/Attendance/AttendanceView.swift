import SwiftUI
import FirebaseAuth

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

    init(
        ownerUid: String,
        initialDateIso: String? = nil,
        initialBranchName: String = "",
        initialGroupKey: String = "",
        initialCoachName: String = ""
    ) {
        #if DEBUG
        print("🔵 AttendanceView.init ownerUid =", ownerUid)
        print("🔵 AttendanceView.init initialBranchName =", initialBranchName)
        print("🔵 AttendanceView.init initialGroupKey =", initialGroupKey)
        print("🔵 AttendanceView.init initialCoachName =", initialCoachName)
        #endif

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
                    Color(red: 0.04, green: 0.06, blue: 0.13),
                    Color(red: 0.08, green: 0.12, blue: 0.24),
                    Color(red: 0.09, green: 0.28, blue: 0.44)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    titleCard
                    contextCard
                    summaryCard
                    addMemberCard
                    membersCard
                    actionsCard
                }
                .padding(12)
                .padding(.bottom, 22)
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
            
        }
        .onChange(of: vm.state.messageEventId) { _ in
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

            #if DEBUG
            print("🔵 AttendanceView.onAppear auth.userFullName =", auth.userFullName)
            print("🔵 AttendanceView.onAppear auth.userBranch =", auth.userBranch)
            print("🔵 AttendanceView.onAppear auth.userGroup =", auth.userGroup)
            print("🔵 AttendanceView.onAppear storedBranch =", storedBranch)
            print("🔵 AttendanceView.onAppear storedGroup =", storedGroup)
            print("🔵 AttendanceView.onAppear vm.branchName(before) =", vm.state.branchName)
            print("🔵 AttendanceView.onAppear vm.groupKey(before) =", vm.state.groupKey)
            print("🔵 AttendanceView.onAppear vm.coachName(before) =", vm.state.coachName)
            #endif

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

            #if DEBUG
            print("🔵 AttendanceView.onAppear resolvedBranch =", resolvedBranch)
            print("🔵 AttendanceView.onAppear resolvedGroup =", resolvedGroup)
            print("🔵 AttendanceView.onAppear resolvedCoachName =", resolvedCoachName)
            #endif

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

            #if DEBUG
            print("🔵 AttendanceView.onAppear vm.branchName(after) =", vm.state.branchName)
            print("🔵 AttendanceView.onAppear vm.groupKey(after) =", vm.state.groupKey)
            print("🔵 AttendanceView.onAppear vm.coachName(after) =", vm.state.coachName)
            #endif

            let comps = dateComponents(from: vm.state.dateIso)
            if let year = comps.year, let month = comps.month {
                vm.loadSummaryDaysForMonth(year: year, month1to12: month)
            }
        }
        .onChange(of: auth.userBranch) { _, newValue in
            #if DEBUG
            print("🔵 AttendanceView.onChange auth.userBranch =", newValue)
            #endif

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

            #if DEBUG
            print("🔵 AttendanceView.onChange vm.state.branchName saving branch/group =", cleanBranch, cleanGroup)
            #endif

            auth.saveTrainingAssignment(branch: cleanBranch, group: cleanGroup)
        }
        
        .onChange(of: auth.userGroup) { _, newValue in
            #if DEBUG
            print("🔵 AttendanceView.onChange auth.userGroup =", newValue)
            #endif

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

            #if DEBUG
            print("🔵 AttendanceView.onChange vm.state.groupKey saving branch/group =", cleanBranch, cleanGroup)
            #endif

            auth.saveTrainingAssignment(branch: cleanBranch, group: cleanGroup)
        }
        
        .onChange(of: auth.userFullName) { _, newValue in
            #if DEBUG
            print("🔵 AttendanceView.onChange auth.userFullName =", newValue)
            #endif

            let clean = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if vm.state.coachName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !clean.isEmpty {
                vm.setCoachName(clean)
            }
        }
    }

    private var titleCard: some View {
        card {
            HStack {
                Circle()
                    .fill(.cyan.opacity(0.9))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: "person.text.rectangle")
                            .foregroundStyle(.white)
                    )

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("דו״ח נוכחות למאמן")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)

                    Text("ניהול נוכחות לפי יום, סניף וקבוצה")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
        }
    }

    private var contextCard: some View {
        card {
            sectionHeader("פרטי הדו״ח", subtitle: "")

            VStack(alignment: .trailing, spacing: 10) {
                HStack {
                    Text(formattedDate(vm.state.dateIso))
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Text("תאריך אימון")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.78))
                }

                VStack(spacing: 0) {
                    readonlyInfoRow(value: vm.state.branchName, placeholder: "לא נבחר סניף")
                    Divider().overlay(.white.opacity(0.10))

                    readonlyInfoRow(value: vm.state.groupKey, placeholder: "לא נבחרה קבוצה")
                    Divider().overlay(.white.opacity(0.10))

                    readonlyInfoRow(value: vm.state.coachName, placeholder: "לא נבחר מאמן")
                }
                .background(Color.white.opacity(0.96))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if !vm.state.reportDaysInMonth.isEmpty {
                Text("בחודש הנוכחי קיימים \(vm.state.reportDaysInMonth.count) ימים עם דו״ח שמור")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var summaryCard: some View {
        let summary = vm.state.summary

        return card {
            sectionHeader("סיכום נוכחות", subtitle: "נתוני היום הנוכחי")

            HStack(spacing: 10) {
                statPill(title: "סה״כ", value: "\(summary.totalMembers)")
                statPill(title: "הגיעו", value: summary.presentLabel)
                statPill(title: "מוצדק", value: summary.excusedLabel)
                statPill(title: "לא הגיעו", value: summary.absentLabel)
            }

            statPill(title: "לא סומנו", value: summary.unknownLabel)

            Text("אחוז נוכחות: \(summary.attendancePercent)%")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var addMemberCard: some View {
        card {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isAddMemberExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isAddMemberExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("הוספת מתאמן")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Text("רשימת המתאמנים נטענת לפי סניף וקבוצה")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.72))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isAddMemberExpanded {
                TextField("שם מלא", text: $newMemberName)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)

                TextField("טלפון", text: $newMemberPhone)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)

                TextField("הערות", text: $newMemberNotes)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)

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
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("הוסף מתאמן")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var membersCard: some View {
        card {
            sectionHeader("רשימת מתאמנים", subtitle: vm.state.rows.isEmpty ? "אין מתאמנים עדיין" : "סמן נוכחות לכל מתאמן")

            if vm.state.rows.isEmpty {
                Text("לא נוספו מתאמנים לסניף ולקבוצה שנבחרו.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                let uniqueRows = uniqueMembers(vm.state.rows)

                ForEach(uniqueRows) { row in
                    memberRow(row)

                    if row.id != uniqueRows.last?.id {
                        Divider().overlay(.white.opacity(0.14))
                    }
                }
            }
        }
    }

    private var actionsCard: some View {
        card {
            sectionHeader("פעולות", subtitle: "שמירה, שיתוף וסטטיסטיקה של דו״ח הנוכחות")

            HStack(spacing: 10) {
                NavigationLink {
                    AttendanceGroupStatsView(
                        ownerUid: vm.state.ownerUid,
                        initialBranchName: vm.state.branchName,
                        initialGroupKey: vm.state.groupKey
                    )
                } label: {
                    HStack {
                        Image(systemName: "chart.bar.xaxis")
                        Text("סטטיסטיקה לקבוצה")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    shareReport()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("שתף")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Button {
                vm.saveReport()
            } label: {
                Text(vm.state.isSaving ? "שומר..." : "שמירת דו״ח נוכחות")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.state.isSaving)
        }
    }

    private func memberRow(_ row: AttendanceRowUi) -> some View {
        VStack(alignment: .trailing, spacing: 10) {
            HStack {
                Button {
                    vm.removeMember(memberId: row.memberId)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {

                    NavigationLink {
                        AttendanceStatsView(
                            ownerUid: vm.state.ownerUid,
                            branchName: vm.state.branchName,
                            groupKey: vm.state.groupKey,
                            memberId: row.memberId,
                            memberName: row.memberName
                        )
                    } label: {

                        Text(row.memberName)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    
                    if !row.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(row.phone)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.78))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }

            HStack(spacing: 8) {
                statusButton(title: "הגיע", selected: row.status == .present) {
                    vm.setAttendanceStatus(memberId: row.memberId, status: .present)
                }

                statusButton(title: "מוצדק", selected: row.status == .excused) {
                    vm.setAttendanceStatus(memberId: row.memberId, status: .excused)
                }

                statusButton(title: "לא הגיע", selected: row.status == .absent) {
                    vm.setAttendanceStatus(memberId: row.memberId, status: .absent)
                }

                statusButton(title: "נקה", selected: row.status == .unknown) {
                    vm.setAttendanceStatus(memberId: row.memberId, status: .unknown)
                }
            }

            TextField(
                "הערת נוכחות",
                text: Binding(
                    get: { row.attendanceNote },
                    set: { vm.setAttendanceNote(memberId: row.memberId, note: $0) }
                ),
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statusButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? Color.cyan.opacity(0.90) : Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func readonlyInfoRow(value: String, placeholder: String) -> some View {
        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        return HStack {
            Text(cleanValue.isEmpty ? placeholder : cleanValue)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(cleanValue.isEmpty ? Color.gray : Color.black)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
    }

    private func shareReport() {
        shareItems = [vm.state.shareText]
        showShareSheet = true
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 12, content: content)
            .padding(14)
            .background(Color.white.opacity(0.09))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(title)
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func formattedDate(_ iso: String) -> String {
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd"

        let output = DateFormatter()
        output.locale = Locale(identifier: "he_IL")
        output.dateFormat = "EEEE, d MMM yyyy"

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

            let key =
                row.memberName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            if unique[key] == nil {
                unique[key] = row
            }
        }

        return unique.values.sorted {
            $0.memberName.localizedCaseInsensitiveCompare($1.memberName) == .orderedAscending
        }
    }
    
    private func bindingDate() -> Binding<Date> {
        Binding<Date>(
            get: {
                let f = DateFormatter()
                f.locale = Locale(identifier: "en_US_POSIX")
                f.dateFormat = "yyyy-MM-dd"
                return f.date(from: vm.state.dateIso) ?? Date()
            },
            set: { newDate in
                let f = DateFormatter()
                f.locale = Locale(identifier: "en_US_POSIX")
                f.dateFormat = "yyyy-MM-dd"
                vm.setDateIso(f.string(from: newDate))
            }
        )
    }
}
