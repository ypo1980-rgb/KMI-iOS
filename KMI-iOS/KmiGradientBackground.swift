import SwiftUI

struct KmiGradientBackground: View {

    let forceTraineeStyle: Bool

    @AppStorage("user_role") private var storedUserRole: String = "trainee"

    private var isCoach: Bool {
        if forceTraineeStyle { return false }

        return storedUserRole
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .contains("coach")
    }
    
    var body: some View {

        let _ = print("KMI_BG role=\(storedUserRole) isCoach=\(isCoach)")
        
        ZStack {

            if isCoach {

                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.04, blue: 0.06),
                        Color(red: 0.15, green: 0.02, blue: 0.03),
                        Color(red: 0.26, green: 0.03, blue: 0.05),
                        Color(red: 0.34, green: 0.03, blue: 0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.18))
                        .frame(width: 240, height: 240)
                        .blur(radius: 10)
                        .offset(x: 160, y: -180)

                    Circle()
                        .fill(Color.black.opacity(0.35))
                        .frame(width: 360, height: 360)
                        .blur(radius: 20)
                        .offset(x: -180, y: 240)
                }

            } else {

                LinearGradient(
                    colors: [
                        Color(red: 0.01, green: 0.05, blue: 0.14),
                        Color(red: 0.07, green: 0.10, blue: 0.23),
                        Color(red: 0.11, green: 0.33, blue: 0.80)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 240, height: 240)
                        .blur(radius: 2)
                        .offset(x: 140, y: -160)

                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 320, height: 320)
                        .blur(radius: 4)
                        .offset(x: -140, y: 220)
                }
            }
        }
        .ignoresSafeArea()
    }
}
