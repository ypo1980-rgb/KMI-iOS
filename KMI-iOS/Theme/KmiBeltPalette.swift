import SwiftUI
import Shared

enum KmiBeltPalette {

    static func color(for belt: Belt) -> Color {
        switch belt {
        case .white:
            return Color.black.opacity(0.80)

        case .yellow:
            return Color(red: 0.86, green: 0.68, blue: 0.10)

        case .orange:
            return Color(red: 0.95, green: 0.46, blue: 0.10)

        case .green:
            return Color(red: 0.12, green: 0.62, blue: 0.26)

        case .blue:
            return Color(red: 0.14, green: 0.40, blue: 0.88)

        case .brown:
            return Color(red: 0.45, green: 0.27, blue: 0.16)

        case .black:
            return Color.black.opacity(0.90)

        default:
            return Color.black.opacity(0.85)
        }
    }
}
