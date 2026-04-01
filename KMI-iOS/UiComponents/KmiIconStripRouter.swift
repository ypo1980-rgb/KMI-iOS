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
            
        case .search:
            // ✅ AppRoute דורש חגורה
            // כרגע משתמשים בברירת מחדל (אפשר בעתיד להעביר belt דינמי)
            nav.push(.beltQuestionsByTopic(belt: .orange))
            
        case .assistant:
            nav.push(.voiceAssistant)
            
        case .share:
            // Share גם Action (UIActivityViewController)
            break
        }
    }
}
