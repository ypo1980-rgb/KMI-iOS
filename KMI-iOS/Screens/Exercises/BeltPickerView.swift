import SwiftUI
import Shared

struct BeltPickerView: View {

    // סדר חגורות כמו אצלך באנדרואיד
    private let belts: [Belt] = [.white, .yellow, .orange, .green, .blue, .brown, .black]

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

            ScrollView {
                VStack(spacing: 12) {
                    Text("בחירת חגורה")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.top, 16)

                    ForEach(Array(belts.enumerated()), id: \.offset) { _, belt in
                        NavigationLink {
                            BeltQuestionsByBeltView(belt: belt)
                        } label: {
                            Text("\(String(describing: belt).uppercased())")
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.white.opacity(0.18))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 18)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
    }
}
