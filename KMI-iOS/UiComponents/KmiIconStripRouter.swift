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
            // אין Route בשם assistant -> זה Action (פתיחת עוזר קולי/Sheet/Modal)
            // תטפל בזה במסך עצמו (לדוגמה: toggle ל-sheet / ניווט פנימי אחר)
            break
            
        case .share:
            // Share גם Action (UIActivityViewController)
            break
        }
    }
}
