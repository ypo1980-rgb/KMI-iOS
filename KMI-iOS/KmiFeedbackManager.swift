import UIKit
import AudioToolbox

final class KmiFeedbackManager {

    static let shared = KmiFeedbackManager()

    private init() {}

    private var clickSounds: Bool {
        UserDefaults.standard.bool(forKey: "click_sounds")
    }

    private var hapticsOn: Bool {
        UserDefaults.standard.bool(forKey: "haptics_on")
    }

    func tap() {

        if clickSounds {
            AudioServicesPlaySystemSound(1104)
        }

        if hapticsOn {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        }
    }

    func success() {

        if hapticsOn {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
    }

    func error() {

        if hapticsOn {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
        }
    }
}
