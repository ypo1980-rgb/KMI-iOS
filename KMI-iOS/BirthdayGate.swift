import SwiftUI

struct BirthdayGate<Content: View>: View {
    private let content: Content

    @State private var showBirthday: Bool = false
    @State private var birthdayName: String = ""

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            content

            if showBirthday {
                birthdayOverlay
                    .transition(.opacity)
                    .zIndex(999)
            }
        }
        .onAppear {
            checkBirthdayIfNeeded()
        }
    }

    private var birthdayOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("מזל טוב\(birthdayName.isEmpty ? "" : " \(birthdayName)") 🎉")
                    .font(.system(size: 24, weight: .heavy))
                    .multilineTextAlignment(.center)

                Text("יום הולדת שמח! מאחלים לך המון בריאות, הצלחה ואימונים טובים בק.מ.י 💪")
                    .font(.system(size: 17, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Text("🎂 🎈 🎆")
                    .font(.system(size: 30))

                Button {
                    markBirthdayShownForToday()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showBirthday = false
                    }
                } label: {
                    Text("להתחיל באימון 🎯")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(UIColor.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 18, x: 0, y: 8)
            .padding(.horizontal, 24)
        }
    }

    private func checkBirthdayIfNeeded() {
        let defaults = UserDefaults.standard

        let userRole = defaults.string(forKey: "user_role") ?? "trainee"
        guard userRole == "trainee" else { return }

        let fullName =
            defaults.string(forKey: "fullName") ??
            defaults.string(forKey: "full_name") ??
            ""

        let birthDayString =
            defaults.string(forKey: "birthDay") ??
            defaults.string(forKey: "birth_day")

        let birthMonthString =
            defaults.string(forKey: "birthMonth") ??
            defaults.string(forKey: "birth_month")

        let day = Int(birthDayString ?? "")
        let month = Int(birthMonthString ?? "")

        let today = Date()
        let calendar = Calendar.current
        let todayDay = calendar.component(.day, from: today)
        let todayMonth = calendar.component(.month, from: today)
        let todayKey = todayKeyString(from: today)

        let lastShown =
            defaults.string(forKey: "last_birthday_shown") ??
            defaults.string(forKey: "lastBirthdayShown")

        guard let day, let month else { return }

        let isTodayBirthday = (day == todayDay && month == todayMonth)
        guard isTodayBirthday else { return }

        guard lastShown != todayKey else { return }

        birthdayName = firstName(from: fullName)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showBirthday = true
            }
        }
    }

    private func markBirthdayShownForToday() {
        let defaults = UserDefaults.standard
        let todayKey = todayKeyString(from: Date())
        defaults.set(todayKey, forKey: "last_birthday_shown")
        defaults.set(todayKey, forKey: "lastBirthdayShown")
    }

    private func todayKeyString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func firstName(from fullName: String) -> String {
        let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return trimmed.components(separatedBy: .whitespaces).first ?? trimmed
    }
}
