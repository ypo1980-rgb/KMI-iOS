import UIKit

/// כיוון ויישור משותפים לכל מסמכי ה־PDF.
/// ללא תלות ב־SwiftUI.
enum KmiPdfDirection {

    /// תחילת שורה: שמאל באנגלית, ימין בעברית.
    static func textAlign(
        isEnglish: Bool
    ) -> NSTextAlignment {
        isEnglish ? .left : .right
    }

    /// סוף שורה: ימין באנגלית, שמאל בעברית.
    static func endTextAlign(
        isEnglish: Bool
    ) -> NSTextAlignment {
        isEnglish ? .right : .left
    }

    static func startX(
        isEnglish: Bool,
        left: CGFloat,
        right: CGFloat
    ) -> CGFloat {
        isEnglish ? left : right
    }

    static func endX(
        isEnglish: Bool,
        left: CGFloat,
        right: CGFloat
    ) -> CGFloat {
        isEnglish ? right : left
    }

    static func startPaddingX(
        isEnglish: Bool,
        left: CGFloat,
        right: CGFloat,
        padding: CGFloat
    ) -> CGFloat {
        isEnglish ? left + padding : right - padding
    }

    static func endPaddingX(
        isEnglish: Bool,
        left: CGFloat,
        right: CGFloat,
        padding: CGFloat
    ) -> CGFloat {
        isEnglish ? right - padding : left + padding
    }

    /// יישור בהתאם לכיוון הבסיס של הפסקה.
    static func layoutAlignment(
        isEnglish _: Bool
    ) -> NSTextAlignment {
        .natural
    }

    static func textDirection(
        isEnglish: Bool
    ) -> NSWritingDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    /// סגנון פסקה משותף לציור ולמדידת טקסט ב־PDF.
    static func paragraphStyle(
        isEnglish: Bool
    ) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()

        style.alignment = layoutAlignment(
            isEnglish: isEnglish
        )

        style.baseWritingDirection = textDirection(
            isEnglish: isEnglish
        )

        style.lineBreakMode = .byWordWrapping

        return style
    }
}
