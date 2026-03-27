import SwiftUI

struct CoachOnlyGateView<Content: View>: View {

    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var role = CoachService.shared
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        Group {
            if role.isLoading {
                ProgressView("בודק הרשאות…")
            } else if role.isCoach {
                content()
            } else {
                VStack(spacing: 12) {
                    Text("גישה למאמנים בלבד")
                        .font(.title3.weight(.heavy))

                    Text("ההרשאה נקבעת לפי תפקיד המשתמש או לפי מספר טלפון")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await role.checkCoach(userRole: auth.userRole)
        }
    }
}
