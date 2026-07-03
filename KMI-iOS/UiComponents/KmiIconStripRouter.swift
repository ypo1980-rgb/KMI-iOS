import SwiftUI
import Shared

/// Router גלובאלי לאייקונים העליונים
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
            // ✅ AppRoute רגורה דרים
            // כרגע משתמשים בברירת מחדל
            nav.push(.beltQuestionsByTopic(belt: .orange))

        case .assistant:
            nav.push(.voiceAssistant)

        case .share:
            // Share גם Action
            break
        }
    }
}
