import SwiftUI
import Shared

private let kmiFreeBgTop = Color(red: 248 / 255, green: 251 / 255, blue: 255 / 255)
private let kmiFreeBgMid = Color(red: 234 / 255, green: 244 / 255, blue: 255 / 255)
private let kmiFreeBgBottom = Color(red: 14 / 255, green: 165 / 255, blue: 215 / 255)

private let kmiFreeCard = Color(red: 247 / 255, green: 251 / 255, blue: 255 / 255)
private let kmiFreeCardSoft = Color.white
private let kmiFreeBorder = Color(red: 191 / 255, green: 215 / 255, blue: 239 / 255)
private let kmiFreeBorderStrong = Color(red: 14 / 255, green: 165 / 255, blue: 215 / 255)

private let kmiFreeTitle = Color(red: 15 / 255, green: 23 / 255, blue: 42 / 255)
private let kmiFreeText = Color(red: 17 / 255, green: 24 / 255, blue: 39 / 255)
private let kmiFreeSubText = Color(red: 100 / 255, green: 116 / 255, blue: 139 / 255)
private let kmiFreeCyan = Color(red: 34 / 255, green: 211 / 255, blue: 238 / 255)

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
    @State private var showCreateDatePicker = false
    @State private var showCreateTimePicker = false
    
    @State private var pendingDelete: FreeSession?
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    kmiFreeBgTop,
                    kmiFreeBgMid,
                    kmiFreeBgBottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 12) {
                headerCard
                
                if vm.upcoming.isEmpty {
                    emptyState
                    
                    Spacer(minLength: 0)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(vm.upcoming) { session in
                                FreeSessionCard(
                                    session: session,
                                    canManage: vm.canManage(session),
                                    onTap: { vm.openDetails(session) },
                                    onEdit: { vm.openDetails(session) },
                                    onDelete: { pendingDelete = session }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 110)
                    }
                    .refreshable {
                        vm.bindUpcoming()
                    }
                }
            }
            .padding(.top, 14)
            
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    Button {
                        showCreateDialog = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 58, height: 58)
                            .background(kmiFreeBorderStrong)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.bottom, 28)
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
            Text("סניף: \(branch.trimmingCharacters(in: .whitespacesAndNewlines))")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(kmiFreeText)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            Text("קבוצה: \(groupKey.trimmingCharacters(in: .whitespacesAndNewlines))")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(kmiFreeSubText)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            Divider()
                .overlay(kmiFreeBorder)
            
            Text("אימונים עתידיים: \(vm.upcoming.count)")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(kmiFreeText)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(kmiFreeCard)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(kmiFreeBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 16)
    }
    
    private var emptyState: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text("אין עדיין אימונים מתוכננים")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(kmiFreeText)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            Text("אפשר ליצור אימון חדש ולשלוח הזמנה לכל המתאמנים בקבוצה.")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(kmiFreeSubText)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(16)
        .background(kmiFreeCard)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(kmiFreeBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 16)
    }
    
    private var createSheet: some View {
        ZStack {
            LinearGradient(
                colors: [
                    kmiFreeBorderStrong,
                    kmiFreeBorder,
                    kmiFreeBgTop
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 14) {
                    VStack(alignment: .trailing, spacing: 12) {
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(kmiFreeCyan)
                                .frame(width: 46, height: 46)
                                .background(Color.white.opacity(0.55))
                                .clipShape(Circle())
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("יצירת אימון חדש")
                                    .font(.system(size: 22, weight: .black))
                                    .foregroundStyle(kmiFreeTitle)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                
                                Text("בחר כותרת, מקום, תאריך ושעה לאימון החופשי")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(kmiFreeSubText)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        
                        Divider()
                            .overlay(kmiFreeBorder)
                        
                        VStack(alignment: .trailing, spacing: 8) {
                            Text("כותרת")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(kmiFreeTitle)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            
                            TextField("כותרת", text: $createTitle)
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 16, weight: .heavy))
                                .foregroundStyle(kmiFreeText)
                                .padding(14)
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(kmiFreeBorder, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        
                        VStack(alignment: .trailing, spacing: 8) {
                            Text("מקום (אופציונלי)")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(kmiFreeTitle)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            
                            HStack(spacing: 8) {
                                TextField("הקלד מקום, כתובת או עיר", text: $createLocation)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .font(.system(size: 16, weight: .heavy))
                                    .foregroundStyle(kmiFreeText)
                                
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundStyle(kmiFreeCyan)
                            }
                            .padding(14)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(kmiFreeBorder, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        
                        VStack(alignment: .trailing, spacing: 12) {
                            Text("בחירת יום ושעה")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(kmiFreeTitle)
                                .frame(maxWidth: .infinity, alignment: .trailing)

                            Button {
                                showCreateDatePicker = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.white.opacity(0.16))
                                        .clipShape(Circle())

                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("התאריך והשעה שנבחרו")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color.white.opacity(0.80))
                                            .frame(maxWidth: .infinity, alignment: .trailing)

                                        Text(fmtSelectedDateHeb(createDate))
                                            .font(.system(size: 17, weight: .black))
                                            .foregroundStyle(.white)
                                            .multilineTextAlignment(.trailing)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                                .background(kmiFreeBgBottom)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(kmiFreeBorderStrong, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            Text("לחיצה תפתח לוח שנה, ולאחר בחירת יום תיפתח בחירת שעה.")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(kmiFreeSubText)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        
                        HStack(spacing: 10) {
                            Button {
                                resetCreateForm()
                                showCreateDialog = false
                            } label: {
                                Text("ביטול")
                                    .font(.system(size: 16, weight: .heavy))
                                    .foregroundStyle(kmiFreeSubText)
                                    .frame(minWidth: 82)
                                    .padding(.vertical, 11)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
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
                            } label: {
                                Text("צור")
                                    .font(.system(size: 16, weight: .black))
                                    .foregroundStyle(Color(red: 4 / 255, green: 16 / 255, blue: 31 / 255))
                                    .frame(minWidth: 116)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 11)
                                    .background(kmiFreeCyan)
                                    .clipShape(Capsule())
                                    .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 4)
                            }
                            .buttonStyle(.plain)
                            .disabled(vm.isLoading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                    }
                    .padding(18)
                    .background(kmiFreeBgMid.opacity(0.98))
                    .overlay(
                        RoundedRectangle(cornerRadius: 33, style: .continuous)
                            .stroke(kmiFreeBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 33, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                }
            }

            if showCreateDatePicker {
                KmiAndroidStyleDatePickerDialog(
                    selectedDate: createDate,
                    onDismiss: {
                        showCreateDatePicker = false
                    },
                    onToday: {
                        createDate = mergeDateKeepingTime(Date(), timeFrom: createDate)
                        showCreateDatePicker = false

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            showCreateTimePicker = true
                        }
                    },
                    onDateSelected: { date in
                        createDate = mergeDateKeepingTime(date, timeFrom: createDate)
                        showCreateDatePicker = false

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            showCreateTimePicker = true
                        }
                    }
                )
                .environment(\.layoutDirection, .rightToLeft)
                .zIndex(20)
            }

            if showCreateTimePicker {
                KmiAndroidStyleTimePickerDialog(
                    selectedDate: createDate,
                    onDismiss: {
                        showCreateTimePicker = false
                    },
                    onConfirm: { hour, minute in
                        createDate = mergeTimeIntoDate(createDate, hour: hour, minute: minute)
                        showCreateTimePicker = false
                    }
                )
                .environment(\.layoutDirection, .rightToLeft)
                .zIndex(30)
            }
        }
    }
    
    private func resetCreateForm() {
        createTitle = ""
        createLocation = ""
        createDate = Calendar.current.date(
            byAdding: .hour,
            value: 1,
            to: Date()
        ) ?? Date().addingTimeInterval(3600)
        showCreateDatePicker = false
        showCreateTimePicker = false
    }
}

// MARK: - Card

private struct FreeSessionCard: View {
    let session: FreeSession
    let canManage: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .trailing, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(red: 125 / 255, green: 211 / 255, blue: 252 / 255))
                            .frame(width: 32, height: 32)

                        if canManage {
                            Button(action: onEdit) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(kmiFreeSubText)
                                    .frame(width: 32, height: 32)
                            }
                            .buttonStyle(.plain)

                            Button(role: .destructive, action: onDelete) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255))
                                    .frame(width: 32, height: 32)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(session.title)
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(kmiFreeText)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Text("נוצר ע״י \(session.createdByName)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(kmiFreeSubText)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }

                HStack(spacing: 10) {
                    Text(shortSessionTime(session.startsAt))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(kmiFreeSubText)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    HStack(spacing: 4) {
                        Image(systemName: "person.3.fill")
                            .foregroundStyle(kmiFreeCyan)

                        Text("\(session.totalParticipants) משתתפים")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(kmiFreeText)
                            .lineLimit(1)
                    }
                }

                if let location = session.locationName, !location.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255))

                        Text(location)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(kmiFreeText)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }

                Text("לחץ כדי לבחור סטטוס (מגיע / לא יכול / וכו׳)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(kmiFreeSubText)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                ProgressView(value: session.progressValue)
                    .progressViewStyle(.linear)
                    .tint(Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255))
                    .scaleEffect(x: 1, y: 1.6, anchor: .center)
                    .clipShape(Capsule())
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .background(Color.white.opacity(0.96))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(kmiFreeBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func shortSessionTime(_ millis: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000.0)
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "he_IL")
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.dateFormat = "EEEE · d.M.yyyy · HH:mm"
        return fmt.string(from: date)
    }
}

// MARK: - Android-style Date/Time Pickers

private struct SurfaceLikeButton<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button(action: action) {
            content()
        }
        .buttonStyle(.plain)
    }
}

private struct KmiAndroidStyleDatePickerDialog: View {
    let selectedDate: Date
    let onDismiss: () -> Void
    let onToday: () -> Void
    let onDateSelected: (Date) -> Void

    @State private var visibleMonth: Date = Date()

    private let calendar = Calendar(identifier: .gregorian)

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(alignment: .trailing, spacing: 16) {
                header

                Divider()
                    .overlay(kmiFreeBorder)

                monthSwitcher

                weekDaysRow

                daysGrid

                footer
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(kmiFreeBgMid)
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(kmiFreeBorderStrong, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .shadow(color: Color.black.opacity(0.28), radius: 18, x: 0, y: 10)
            .padding(.horizontal, 18)
            .onAppear {
                visibleMonth = firstDayOfMonth(selectedDate)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.red)
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .trailing, spacing: 6) {
                Text("בחר תאריך לאימון")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(kmiFreeSubText)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Text(dateTitle(selectedDate))
                    .font(.system(size: 27, weight: .black))
                    .foregroundStyle(kmiFreeText)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var monthSwitcher: some View {
        HStack(spacing: 14) {
            Button {
                visibleMonth = addMonth(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(kmiFreeBgBottom)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Text(monthTitle(visibleMonth))
                .font(.system(size: 25, weight: .black))
                .foregroundStyle(kmiFreeText)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            Button {
                visibleMonth = addMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(kmiFreeBgBottom)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var weekDaysRow: some View {
        HStack(spacing: 0) {
            ForEach(["א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳", "ש׳"], id: \.self) { day in
                Text(day)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(kmiFreeText)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var daysGrid: some View {
        let days = monthCells()

        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
            spacing: 10
        ) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                if let date {
                    dayCell(date)
                } else {
                    Color.clear
                        .frame(height: 34)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func dayCell(_ date: Date) -> some View {
        let selected = calendar.isDate(date, inSameDayAs: selectedDate)
        let today = calendar.isDateInToday(date)

        return Button {
            onDateSelected(date)
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(
                    selected
                    ? Color(red: 4 / 255, green: 16 / 255, blue: 31 / 255)
                    : kmiFreeText
                )
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(
                            selected
                            ? kmiFreeCyan
                            : (today ? kmiFreeCyan.opacity(0.18) : Color.clear)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Button {
                onToday()
            } label: {
                Text("היום")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color(red: 4 / 255, green: 16 / 255, blue: 31 / 255))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 13)
                    .background(kmiFreeCyan)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.12), radius: 7, x: 0, y: 5)
            }
            .buttonStyle(.plain)

            Button {
                onDismiss()
            } label: {
                Text("ביטול")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(kmiFreeSubText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
    }

    private func firstDayOfMonth(_ date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }

    private func addMonth(_ value: Int) -> Date {
        calendar.date(byAdding: .month, value: value, to: visibleMonth) ?? visibleMonth
    }

    private func monthCells() -> [Date?] {
        let start = firstDayOfMonth(visibleMonth)
        let range = calendar.range(of: .day, in: .month, for: start) ?? 1..<1
        let firstWeekday = calendar.component(.weekday, from: start)
        let leading = firstWeekday - 1

        var cells: [Date?] = Array(repeating: nil, count: leading)

        for day in range {
            var comps = calendar.dateComponents([.year, .month], from: start)
            comps.day = day
            cells.append(calendar.date(from: comps))
        }

        while cells.count % 7 != 0 {
            cells.append(nil)
        }

        return cells
    }

    private func dateTitle(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "he_IL")
        fmt.calendar = calendar
        fmt.dateFormat = "EEEE · d MMMM yyyy"
        return fmt.string(from: date)
    }

    private func monthTitle(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "he_IL")
        fmt.calendar = calendar
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: date)
    }
}

private struct KmiAndroidStyleTimePickerDialog: View {
    let selectedDate: Date
    let onDismiss: () -> Void
    let onConfirm: (_ hour: Int, _ minute: Int) -> Void

    @State private var hour: Int = 19
    @State private var minute: Int = 0

    private let hours = Array(0...23)
    private let minutes = Array(0...59)

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(alignment: .trailing, spacing: 22) {
                Text("בחר שעה לאימון")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                HStack(spacing: 10) {
                    timeBox(value: String(format: "%02d", minute), selected: false)

                    Text(":")
                        .font(.system(size: 42, weight: .black))
                        .foregroundStyle(Color.white.opacity(0.25))

                    timeBox(value: String(format: "%02d", hour), selected: true)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: 0) {
                    Picker("", selection: $minute) {
                        ForEach(minutes, id: \.self) { value in
                            Text(String(format: "%02d", value))
                                .font(.system(size: 26, weight: .black))
                                .tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()

                    Picker("", selection: $hour) {
                        ForEach(hours, id: \.self) { value in
                            Text(String(format: "%02d", value))
                                .font(.system(size: 26, weight: .black))
                                .tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
                .frame(height: 190)
                .background(Color.white.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                HStack(spacing: 26) {
                    Button {
                        onConfirm(hour, minute)
                    } label: {
                        Text("אישור")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(kmiFreeCyan)
                    }
                    .buttonStyle(.plain)

                    Button {
                        onDismiss()
                    } label: {
                        Text("ביטול")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(kmiFreeSubText)
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 28)
            .background(Color(red: 2 / 255, green: 20 / 255, blue: 43 / 255))
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .shadow(color: Color.black.opacity(0.32), radius: 18, x: 0, y: 10)
            .padding(.horizontal, 18)
            .onAppear {
                let comps = Calendar.current.dateComponents([.hour, .minute], from: selectedDate)
                hour = comps.hour ?? 19
                minute = comps.minute ?? 0
            }
        }
    }

    private func timeBox(value: String, selected: Bool) -> some View {
        Text(value)
            .font(.system(size: 48, weight: .black))
            .foregroundStyle(
                selected
                ? Color(red: 55 / 255, green: 9 / 255, blue: 110 / 255)
                : kmiFreeText
            )
            .frame(width: 96, height: 76)
            .background(
                selected
                ? Color(red: 232 / 255, green: 216 / 255, blue: 255 / 255)
                : Color.white.opacity(0.86)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

private func fmtSelectedDateHeb(_ date: Date) -> String {
    let fmt = DateFormatter()
    fmt.locale = Locale(identifier: "he_IL")
    fmt.calendar = Calendar(identifier: .gregorian)
    fmt.dateFormat = "EEEE · d.M.yyyy · HH:mm"
    return fmt.string(from: date)
}

private func mergeDateKeepingTime(_ date: Date, timeFrom source: Date) -> Date {
    let cal = Calendar(identifier: .gregorian)

    let dateComps = cal.dateComponents([.year, .month, .day], from: date)
    let timeComps = cal.dateComponents([.hour, .minute], from: source)

    var merged = DateComponents()
    merged.year = dateComps.year
    merged.month = dateComps.month
    merged.day = dateComps.day
    merged.hour = timeComps.hour
    merged.minute = timeComps.minute
    merged.second = 0

    return cal.date(from: merged) ?? date
}

private func mergeTimeIntoDate(_ date: Date, hour: Int, minute: Int) -> Date {
    let cal = Calendar(identifier: .gregorian)

    var comps = cal.dateComponents([.year, .month, .day], from: date)
    comps.hour = hour.coerceIn(0...23)
    comps.minute = minute.coerceIn(0...59)
    comps.second = 0

    return cal.date(from: comps) ?? date
}

private extension Comparable {
    func coerceIn(_ range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

