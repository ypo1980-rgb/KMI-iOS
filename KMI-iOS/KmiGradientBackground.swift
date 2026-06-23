import SwiftUI

struct KmiGradientBackground: View {
    // נשאר בפרמטר כדי לא לשבור מסכים קיימים שקוראים עם forceTraineeStyle / isCoach.
    // בפועל מתעלמים ממנו כדי שכל האפליקציה תקבל רקע אחיד כמו Android.
    var forceTraineeStyle: Bool = false
    var isCoach: Bool? = nil

    var body: some View {
        KmiAppBackground()
    }
}

struct KmiAppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.973, green: 0.984, blue: 1.000), // F8FBFF
                Color(red: 0.918, green: 0.957, blue: 1.000), // EAF4FF
                Color(red: 0.718, green: 0.867, blue: 0.969), // B7DDF7
                Color(red: 0.122, green: 0.471, blue: 0.706), // 1F78B4
                Color(red: 0.024, green: 0.169, blue: 0.290)  // 062B4A
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
