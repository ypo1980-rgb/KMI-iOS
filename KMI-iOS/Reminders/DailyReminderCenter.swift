import SwiftUI
import Combine

@MainActor
final class DailyReminderCenter: ObservableObject {
    static let shared = DailyReminderCenter()

    @Published var currentPayload: DailyReminderPayload? = nil
    @Published var isPresented: Bool = false

    private init() {}

    func present(_ payload: DailyReminderPayload) {
        currentPayload = payload
        isPresented = true
    }

    func dismiss() {
        isPresented = false
        currentPayload = nil
    }
}
