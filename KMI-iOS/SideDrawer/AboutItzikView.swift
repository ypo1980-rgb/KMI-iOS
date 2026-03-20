import SwiftUI

struct AboutItzikView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 12) {
                Text("אודות איציק ביטון")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(.white)

                Text("נכניס כאן את הטקסט מהאנדרואיד בקובץ הבא.")
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .padding(18)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.01, green: 0.05, blue: 0.14),
                    Color(red: 0.07, green: 0.10, blue: 0.23),
                    Color(red: 0.11, green: 0.33, blue: 0.80)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}
