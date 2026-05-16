import SwiftUI
import Shared

enum KmiBeltImageAsset {
    
    static func imageName(for belt: Belt) -> String {
        switch belt {
        case .white:
            return "belt_white"
        case .yellow:
            return "belt_yellow"
        case .orange:
            return "belt_orange"
        case .green:
            return "belt_green"
        case .blue:
            return "belt_blue"
        case .brown:
            return "belt_brown"
        case .black:
            return "belt_black"
        default:
            return "belt_orange"
        }
    }
}

struct KmiBeltImageView: View {
    
    let belt: Belt
    var width: CGFloat = 92
    var height: CGFloat = 34
    var showShadow: Bool = true
    
    var body: some View {
        Image(KmiBeltImageAsset.imageName(for: belt))
            .resizable()
            .scaledToFit()
            .frame(width: width, height: height)
            .shadow(
                color: showShadow ? Color.black.opacity(0.18) : Color.clear,
                radius: showShadow ? 6 : 0,
                x: 0,
                y: showShadow ? 3 : 0
            )
            .accessibilityHidden(true)
    }
}
