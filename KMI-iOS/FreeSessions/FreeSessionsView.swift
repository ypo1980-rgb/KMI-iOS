import SwiftUI
import Shared

struct FreeSessionsView: View {
    let branch: String
    let groupKey: String
    let currentUid: String
    let currentName: String

    @StateObject private var vm = FreeSessionsViewModel()

    @State private var showCreateDialog = false
    @State private var createTitle = ""
    @State private var createLocation = ""
    @State private var createDate = Date().addingTimeInterval(3600)
    @State private var selectedQuickTime: String? = "hour"

    @State private var pendingDelete: FreeSession?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.30, green: 0.18, blue: 0.72),
                    Color(red: 0.02, green: 0.72, blue: 0.95)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                headerCard

                if vm.upcoming.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(vm.upcoming) { session in
                                FreeSessionCard(
                                    session: session,
                                    canManage: vm.canManage(session),
                                    onTap: { vm.openDetails(session) },
                                    onDelete: { pendingDelete = session }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                    }
                    .refreshable {
                        vm.bindUpcoming()
                    }
                }
            }
            .padding(.top, 12)

            VStack {
                Spacer()

                HStack {
                    Spacer()

                    Button {
                        showCreateDialog = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.94))
                                .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)

                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .heavy))
                                .foregroundStyle(Color.black.opacity(0.72))
                        }
                        .frame(width: 58, height: 58)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.bottom, 28)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    vm.bindUpcoming()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .sheet(item: $vm.selectedSession) { session in
            FreeSessionDetailsSheet(
                vm: vm,
                session: session,
                currentUid: currentUid,
                onClose: { vm.closeDetails() }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("מחיקת אימון", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("ביטול", role: .cancel) {
                pendingDelete = nil
            }
            Button("מחק", role: .destructive) {
                if let session = pendingDelete {
                    Task { await vm.deleteSession(sessionId: session.id) }
                }
                pendingDelete = nil
            }
        } message: {
            Text("למחוק את האימון \"\(pendingDelete?.title ?? "")\"?")
        }
        .alert("שגיאה", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("סגור", role: .cancel) {
                vm.errorMessage = nil
            }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .sheet(isPresented: $showCreateDialog) {
            createSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            vm.setContext(
                branch: branch,
                groupKey: groupKey,
                myUid: currentUid,
                myName: currentName
            )
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var headerCard: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text("סניף: \(branch)")
                .font(.headline)
                .foregroundStyle(.white)

            Text("קבוצה: \(groupKey)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.85))

            Divider()
                .overlay(Color.white.opacity(0.2))

            Text("אימונים עתידיים: \(vm.upcoming.count)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(16)
        .background(Color.white.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.blue.opacity(0.55), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 16)
    }

    private var emptyState: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Text("אין עדיין אימונים מתוכננים")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(.white)

            Text("אפשר ליצור אימון חדש ולשלוח הזמנה לכל המתאמנים בקבוצה.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.86))
                .multilineTextAlignment(.trailing)

            Text("התחל עם לחיצה על כפתור הפלוס")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.68))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(18)
        .background(Color.white.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.blue.opacity(0.45), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 16)
    }

    private var createSheet: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.30, green: 0.18, blue: 0.72),
                        Color(red: 0.02, green: 0.72, blue: 0.95)
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        VStack(alignment: .trailing, spacing: 10) {
                            Text("פרטי אימון")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .trailing)

                            TextField("כותרת", text: $createTitle)
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                                .padding(14)
                                .background(Color.white.opacity(0.92))
                                .clipShape(RoundedRectangle(cornerRadius: 16))

                            TextField("מקום (אופציונלי)", text: $createLocation)
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                                .padding(14)
                                .background(Color.white.opacity(0.92))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .padding(.horizontal, 16)

                        VStack(alignment: .trailing, spacing: 10) {
                            Text("בחירת זמן מהירה")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .trailing)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                                quickTimeChip(title: "עוד שעה", key: "hour") {
                                    createDate = Date().addingTimeInterval(3600)
                                }

                                quickTimeChip(title: "עוד שעתיים", key: "two_hours") {
                                    createDate = Date().addingTimeInterval(7200)
                                }

                                quickTimeChip(title: "היום בערב", key: "evening") {
                                    createDate = quickDateTodayAt(hour: 20)
                                }

                                quickTimeChip(title: "מחר ב־18:00", key: "tomorrow") {
                                    createDate = quickDateTomorrowAt(hour: 18)
                                }
                            }

                            DatePicker(
                                "בחר תאריך ושעה",
                                selection: Binding(
                                    get: { createDate },
                                    set: { newValue in
                                        selectedQuickTime = nil
                                        createDate = newValue
                                    }
                                ),
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .environment(\.locale, Locale(identifier: "he_IL"))
                            .padding(12)
                            .background(Color.white.opacity(0.92))
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                            Text("זמן שנבחר: \(fmtTimeHeb(Int64(createDate.timeIntervalSince1970 * 1000)))")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.white.opacity(0.88))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("יצירת אימון חדש")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("ביטול") {
                        resetCreateForm()
                        showCreateDialog = false
                    }
                    .foregroundStyle(.white)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("צור") {
                        let cleanTitle = createTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !cleanTitle.isEmpty else {
                            vm.errorMessage = "נא להזין כותרת"
                            return
                        }

                        Task {
                            await vm.createSession(
                                title: cleanTitle,
                                locationName: createLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : createLocation,
                                startsAt: Int64(createDate.timeIntervalSince1970 * 1000)
                            )
                            resetCreateForm()
                            showCreateDialog = false
                        }
                    }
                    .disabled(vm.isLoading)
                    .foregroundStyle(.white)
                }
            }
        }
    }

    private func resetCreateForm() {
        createTitle = ""
        createLocation = ""
        createDate = Date().addingTimeInterval(3600)
        selectedQuickTime = "hour"
    }

    @ViewBuilder
    private func quickTimeChip(title: String, key: String, action: @escaping () -> Void) -> some View {
        Button {
            selectedQuickTime = key
            action()
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    selectedQuickTime == key
                    ? Color.white
                    : Color.white.opacity(0.14)
                )
                .foregroundStyle(
                    selectedQuickTime == key
                    ? Color.black.opacity(0.8)
                    : .white
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func quickDateTodayAt(hour: Int) -> Date {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let candidate = cal.date(
            bySettingHour: hour,
            minute: 0,
            second: 0,
            of: now
        ) ?? now.addingTimeInterval(3600)

        if candidate > now {
            return candidate
        } else {
            return cal.date(byAdding: .day, value: 1, to: candidate) ?? now.addingTimeInterval(3600)
        }
    }

    private func quickDateTomorrowAt(hour: Int) -> Date {
        let cal = Calendar(identifier: .gregorian)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return cal.date(
            bySettingHour: hour,
            minute: 0,
            second: 0,
            of: tomorrow
        ) ?? Date().addingTimeInterval(86400)
    }
}

// MARK: - Card

private struct FreeSessionCard: View {
    let session: FreeSession
    let canManage: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .trailing, spacing: 12) {

                // כותרת + מחיקה
                HStack(alignment: .top, spacing: 10) {
                    if canManage {
                        Button(role: .destructive, action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.red)
                                .frame(width: 30, height: 30)
                                .background(Color.white.opacity(0.10))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(session.title)
                            .font(.system(size: 19, weight: .heavy))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Text("נוצר ע״י \(session.createdByName)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.78))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }

                // זמן + משתתפים
                HStack(spacing: 12) {
                    miniInfoChip(
                        systemImage: "person.3.fill",
                        text: "\(session.totalParticipants) משתתפים",
                        tint: .cyan
                    )

                    Spacer(minLength: 8)

                    miniInfoChip(
                        systemImage: "calendar",
                        text: shortSessionTime(session.startsAt),
                        tint: .white
                    )
                }

                // מיקום
                if let location = session.locationName, !location.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(.white.opacity(0.86))

                        Text(location)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.90))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }

                // סטטוסים
                sessionStatusRow

                // hint
                Text("לחץ כדי לפתוח פרטים ולעדכן סטטוס")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.68))
                    .frame(maxWidth: .infinity, alignment: .trailing)

                ProgressView(value: session.progressValue)
                    .progressViewStyle(.linear)
                    .tint(.green)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.blue.opacity(0.55), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private var sessionStatusRow: some View {
        HStack(spacing: 8) {
            statusChip(title: "מגיע", count: session.goingCount, color: .green)
            statusChip(title: "בדרך", count: session.onWayCount, color: .blue)
            statusChip(title: "הגיע", count: session.arrivedCount, color: .mint)
            statusChip(title: "לא יכול", count: session.cantCount, color: .red)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func miniInfoChip(systemImage: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)

            Text(text)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.10))
        .clipShape(Capsule())
    }

    private func statusChip(title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text("\(count) \(title)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(color.opacity(0.16))
        .clipShape(Capsule())
    }

    private func shortSessionTime(_ millis: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000.0)
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "he_IL")
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.dateFormat = "d/M • HH:mm"
        return fmt.string(from: date)
    }
}

// MARK: - Helpers

private func fmtTimeHeb(_ millis: Int64) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000.0)
    let fmt = DateFormatter()
    fmt.locale = Locale(identifier: "he_IL")
    fmt.calendar = Calendar(identifier: .gregorian)
    fmt.dateFormat = "EEEE · d.M.yyyy · HH:mm"
    return fmt.string(from: date)
}
