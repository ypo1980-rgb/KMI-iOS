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
                        LazyVStack(spacing: 12) {
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
                }
            }
            .padding(.top, 12)
        }
            .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateDialog = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22, weight: .bold))
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
        VStack(alignment: .trailing, spacing: 8) {
            Text("אין עדיין אימונים מתוכננים")
                .font(.headline)
                .foregroundStyle(.white)

            Text("אפשר ליצור אימון חדש ולשלוח הזמנה לכל המתאמנים בקבוצה.")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.85))
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(16)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 16)
    }

    private var createSheet: some View {
        NavigationStack {
            Form {
                Section("פרטי אימון") {
                    TextField("כותרת", text: $createTitle)
                        .multilineTextAlignment(.trailing)

                    TextField("מקום (אופציונלי)", text: $createLocation)
                        .multilineTextAlignment(.trailing)
                }

                Section("זמן") {
                    DatePicker(
                        "בחר תאריך ושעה",
                        selection: $createDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .environment(\.locale, Locale(identifier: "he_IL"))

                    Text("זמן שנבחר: \(fmtTimeHeb(Int64(createDate.timeIntervalSince1970 * 1000)))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
                }
            }
        }
    }

    private func resetCreateForm() {
        createTitle = ""
        createLocation = ""
        createDate = Date().addingTimeInterval(3600)
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
            VStack(alignment: .trailing, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    if canManage {
                        Button(role: .destructive, action: onDelete) {
                            Image(systemName: "trash")
                                .foregroundStyle(Color.red.opacity(0.9))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(session.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Text("נוצר ע״י \(session.createdByName)")
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }

                HStack(spacing: 14) {
                    participantRow
                    Spacer()
                    Label(fmtTimeHeb(session.startsAt), systemImage: "calendar")
                        .foregroundStyle(Color.white.opacity(0.9))
                        .font(.subheadline.weight(.semibold))
                }

                if let location = session.locationName, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .foregroundStyle(Color.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Text("לחץ כדי לבחור סטטוס")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .trailing)

                ProgressView(value: session.progressValue)
                    .tint(.green)
            }
            .padding(14)
            .background(Color.white.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.blue.opacity(0.7), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private var participantRow: some View {
        HStack(spacing: 6) {
            Text("\(session.totalParticipants) משתתפים")
                .foregroundStyle(Color.white.opacity(0.9))
                .font(.subheadline)
            Image(systemName: "person.3.fill")
                .foregroundStyle(.cyan)
        }
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
