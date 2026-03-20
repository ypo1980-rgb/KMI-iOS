import SwiftUI
import FirebaseAuth

struct DeviceGateRootView<Content: View>: View {
    @StateObject private var gate = AuthDeviceGate.shared
    let content: () -> Content

    var body: some View {
        Group {
            if gate.isChecking {
                ProgressView("בודק הרשאת מכשיר...")
            } else if gate.isAuthorized {
                content()
            } else {
                BlockedDeviceView(
                    message: gate.blockMessage ?? "המכשיר הזה אינו מורשה."
                )
            }
        }
        .task {
            if Auth.auth().currentUser != nil {
                await gate.verifyCurrentSession()
            }
        }
    }
}
