import SwiftUI
import Combine

final class SideDrawerState: ObservableObject {
    static let shared = SideDrawerState()

    @Published var isOpen: Bool = false

    func open() { isOpen = true }
    func close() { isOpen = false }
    func toggle() { isOpen.toggle() }
}
