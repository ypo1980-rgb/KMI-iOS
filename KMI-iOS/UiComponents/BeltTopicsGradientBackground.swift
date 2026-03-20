import SwiftUI

struct BeltTopicsGradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.06, blue: 0.25),
                Color(red: 0.20, green: 0.12, blue: 0.55),
                Color(red: 0.08, green: 0.44, blue: 0.86),
                Color(red: 0.10, green: 0.80, blue: 0.90)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
