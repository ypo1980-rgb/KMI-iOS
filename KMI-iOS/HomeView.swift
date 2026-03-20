import SwiftUI
import Shared

struct HomeView: View {

    @ObservedObject var nav: AppNavModel
    @EnvironmentObject private var auth: AuthViewModel

    @State private var fabOpen: Bool = false
    @StateObject private var trainingsVm = HomeTrainingsViewModel()
    @State private var goVoice: Bool = false
    @State private var goMonthly: Bool = false
    @State private var goSummary: Bool = false
    @State private var goFree: Bool = false
    @State private var goCard: Bool = false
    @State private var selectedTraining: TrainingData? = nil
    @State private var showNavigationSheet: Bool = false

    private let calendar = Calendar(identifier: .gregorian)
    
    var body: some View {
        ZStack {
            HomeBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {

                    WeekHeaderPill(
                        title: "אימונים לשבוע הקרוב",
                        subtitle: currentWeekSubtitle
                    )
                    .padding(.top, 10)

                    if trainingsVm.upcomingTrainings.isEmpty {
                        if let statusMessage = trainingsVm.statusMessage {
                            emptyBlock(message: statusMessage)
                                .padding(.top, 6)
                        } else {
                            emptyBlock(message: "לא נמצאו אימונים לשבוע הקרוב")
                                .padding(.top, 6)
                        }
                    } else {
                        VStack(spacing: 12) {
                            ForEach(trainingsVm.upcomingTrainings) { training in
                                TrainingCardView(
                                    training: training,
                                    onNavigateTap: {
                                        closeFab()
                                        selectedTraining = training
                                        showNavigationSheet = true
                                    }
                                )
                                .padding(.horizontal, 18)
                            }
                        }
                        .padding(.top, 6)
                    }
                    Spacer(minLength: 22)

                    Button {
                        let target = BeltFlow.nextBeltForUser(
                            registeredBelt: auth.registeredBelt
                        )
                        nav.push(.beltQuestionsByBelt(belt: target))
                    } label: {
                        Text(buttonTitleForBelt())
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.18))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 22)

                    Spacer(minLength: 120)
                }
            }

            if fabOpen {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            fabOpen = false
                        }
                    }

                VStack(spacing: 10) {
                    Button {
                        closeFab()
                        goVoice = true
                    } label: {
                        FabMenuRow(title: "עוזר קולי", systemImage: "mic.fill")
                    }

                    Button {
                        closeFab()
                        goMonthly = true
                    } label: {
                        FabMenuRow(title: "לוח אימונים חודשי", systemImage: "calendar")
                    }

                    Button {
                        closeFab()
                        goSummary = true
                    } label: {
                        FabMenuRow(title: "סיכום אימון", systemImage: "square.and.pencil")
                    }

                    Button {
                        closeFab()
                        goFree = true
                    } label: {
                        FabMenuRow(title: "אימונים חופשיים", systemImage: "plus")
                    }

                    Button {
                        closeFab()
                        goCard = true
                    } label: {
                        FabMenuRow(title: "כרטיס", systemImage: "person.crop.circle")
                    }

                    Button {
                        closeFab()
                        nav.push(.settings)
                    } label: {
                        FabMenuRow(title: "הגדרות", systemImage: "gearshape.fill")
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 18)
                .padding(.bottom, 88)
            }

            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    fabOpen.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.92))
                        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)

                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.65))
                        .rotationEffect(.degrees(fabOpen ? 45 : 0))
                }
                .frame(width: 56, height: 56)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 22)
        }
        .task {
            trainingsVm.loadForCurrentUser(auth: auth)
        }
        .onChange(of: auth.userRegion) { _, _ in
            trainingsVm.loadForCurrentUser(auth: auth)
        }
        .onChange(of: auth.userBranch) { _, _ in
            trainingsVm.loadForCurrentUser(auth: auth)
        }
        .onChange(of: auth.userGroup) { _, _ in
            trainingsVm.loadForCurrentUser(auth: auth)
        }
        .navigationDestination(isPresented: $goVoice) {
            PlaceholderScreen(title: "עוזר קולי")
        }
        .navigationDestination(isPresented: $goMonthly) {
            PlaceholderScreen(title: "לוח אימונים חודשי")
        }
        .navigationDestination(isPresented: $goSummary) {
            PlaceholderScreen(title: "סיכום אימון")
        }
        .navigationDestination(isPresented: $goFree) {
            PlaceholderScreen(title: "אימונים חופשיים")
        }
        .navigationDestination(isPresented: $goCard) {
            PlaceholderScreen(title: "כרטיס")
        }
        .sheet(isPresented: $showNavigationSheet, onDismiss: {
            selectedTraining = nil
        }) {
            if let training = selectedTraining {
                NavigationSheet(training: training)
            }
        }
    }

    // MARK: - Week Header

    private var currentWeekSubtitle: String {
        let today = Date()
        let start = startOfWeek(for: today)
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? today

        return "(תאריכים: \(hebrewWeekdayName(from: start)) \(shortDate(start))–\(hebrewWeekdayName(from: end)) \(shortDate(end)))"
    }

    private func startOfWeek(for date: Date) -> Date {
        var cal = calendar
        cal.firstWeekday = 1 // Sunday

        let weekday = cal.component(.weekday, from: date)
        let daysFromSunday = (weekday - cal.firstWeekday + 7) % 7

        return cal.date(
            byAdding: .day,
            value: -daysFromSunday,
            to: cal.startOfDay(for: date)
        ) ?? date
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "he_IL")
        formatter.calendar = calendar
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: date)
    }

    private func hebrewWeekdayName(from date: Date) -> String {
        let weekday = calendar.component(.weekday, from: date)
        switch weekday {
        case 1: return "יום ראשון"
        case 2: return "יום שני"
        case 3: return "יום שלישי"
        case 4: return "יום רביעי"
        case 5: return "יום חמישי"
        case 6: return "יום שישי"
        case 7: return "יום שבת"
        default: return ""
        }
    }

    // MARK: - Belt CTA

    private func buttonTitleForBelt() -> String {
        let next = BeltFlow.nextBeltForUser(registeredBelt: auth.registeredBelt)
        return "מעבר לתרגילים – \(beltHeb(next))"
    }

    private func beltHeb(_ belt: Belt) -> String {
        switch belt {
        case .white: return "לבנה"
        case .yellow: return "צהובה"
        case .orange: return "כתומה"
        case .green: return "ירוקה"
        case .blue: return "כחולה"
        case .brown: return "חומה"
        case .black: return "שחורה"
        default: return belt.id
        }
    }

    // MARK: - Helpers

    private func closeFab() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            fabOpen = false
        }
    }

    private var loadingBlock: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 168)
                    .overlay {
                        ProgressView()
                            .tint(.white)
                    }
                    .padding(.horizontal, 18)
            }
        }
    }

    private func emptyBlock(message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))

            Text(message)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("האימונים יוצגו כאן לפי הסניף והקבוצה של המשתמש")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 1)
        )
        .padding(.horizontal, 18)
    }
}

// MARK: - Background
private struct HomeBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.30, green: 0.18, blue: 0.72),
                Color(red: 0.02, green: 0.72, blue: 0.95)
            ],
            startPoint: .topTrailing,
            endPoint: .bottomLeading
        )
        .ignoresSafeArea()
    }
}

// MARK: - Week Header
private struct WeekHeaderPill: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.90))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .padding(.horizontal, 18)
    }
}

// MARK: - FAB Menu Row
private struct FabMenuRow: View {
    let title: String
    let systemImage: String

    private let rowHeight: CGFloat = 54

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width * 0.52

            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.70))

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.80))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(width: width, height: rowHeight, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
        }
        .frame(height: rowHeight)
    }
}

// MARK: - Placeholder
private struct PlaceholderScreen: View {
    let title: String

    var body: some View {
        ZStack {
            HomeBackground()

            VStack(spacing: 14) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Text(title)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(.white)

                Text("המסך הזה עדיין בשלב חיבור מצד iOS")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
            }
            .padding(24)
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Preview
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HomeView(nav: AppNavModel())
                .environmentObject(AuthViewModel())
        }
    }
}
