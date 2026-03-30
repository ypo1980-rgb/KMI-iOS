import SwiftUI

struct DailyReminderRootContainer<Content: View>: View {

    @StateObject private var center = DailyReminderCenter.shared

    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ZStack {
            content()
                .environmentObject(center)

            if center.isPresented, let payload = center.currentPayload {
                DailyReminderCardView(payload: payload)
                    .environmentObject(center)
                    .transition(.opacity)
                    .zIndex(1000)
            }
        }
    }
}
