import SwiftUI

struct OnboardingStep: Identifiable, Hashable {

    let id: String

    let titleHe: String
    let titleEn: String

    let descriptionHe: String
    let descriptionEn: String

    let imageName: String?
    let accentHex: UInt32

    var accentColor: Color {
        Color(hex: accentHex)
    }

    func title(
        isEnglish: Bool
    ) -> String {
        isEnglish ? titleEn : titleHe
    }

    func description(
        isEnglish: Bool
    ) -> String {
        isEnglish
        ? descriptionEn
        : descriptionHe
    }
}
