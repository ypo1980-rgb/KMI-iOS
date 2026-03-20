import Foundation
import UIKit

@MainActor
enum GlobalShareService {

    /// צילום מסך בסיסי של ה-Window הנוכחי.
    /// עובד טוב לרוב האפליקציות; אם בעתיד תרצה צילום "רק תוכן מסוים" נבנה capture ייעודי ל-View.
    static func captureScreenshot() -> UIImage? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return nil }

        // נעדיף keyWindow אם קיים
        let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first
        guard let w = window else { return nil }

        let renderer = UIGraphicsImageRenderer(size: w.bounds.size)
        return renderer.image { _ in
            // drawHierarchy נותן צילום "כמו מסך" (כולל blur/gradients וכו')
            w.drawHierarchy(in: w.bounds, afterScreenUpdates: true)
        }
    }

    /// בונה מערך פריטים לשיתוף: צילום מסך + טקסט בסיסי
    static func shareItemsForCurrentScreen(
        extraText: String? = nil
    ) -> [Any] {
        var items: [Any] = []

        if let img = captureScreenshot() {
            items.append(img)
        }

        // טקסט בסיסי (תוכל לשדרג בהמשך ל-title/route וכו')
        let baseText = "שיתוף מתוך KMI"
        if let extraText, !extraText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append("\(baseText)\n\(extraText)")
        } else {
            items.append(baseText)
        }

        return items
    }
}
