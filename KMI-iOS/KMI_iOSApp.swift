import SwiftUI
import FirebaseCore

@main
struct KMI_iOSApp: App {

    init() {
        // ✅ אתחול Firebase פעם אחת לכל האפליקציה
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            AuthGateView()
        }
    }
}
