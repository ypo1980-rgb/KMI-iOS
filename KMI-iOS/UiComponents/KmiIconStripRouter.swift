import SwiftUI
import Shared

/// Router גלובלי לאייקונים העליונים.
enum KmiIconStripRouter {
    
    static func handle(
        _ item: KmiIconStripItem,
        nav: AppNavModel
    ) {
        switch item {
        case .home:
            nav.popToRoot()

        case .settings:
            nav.push(.settings)

        case .stats:
            nav.push(.progress)

        case .search:
            /*
             * החיפוש הגלובלי נפתח באמצעות ההתראה
             * שאליה KmiRootLayout כבר מאזין.
             */
            NotificationCenter.default.post(
                name: Notification.Name(
                    "KMI_OPEN_GLOBAL_SEARCH"
                ),
                object: nil
            )

        case .assistant:
            nav.push(.voiceAssistant)

        case .guide:
            nav.push(
                .onboarding(
                    manual: true
                )
            )

        case .share:
            /*
             * השיתוף תלוי בתוכן של המסך הפעיל,
             * ולכן מטופל ב-KmiRootLayout.
             */
            break
        }
    }
}
