import UIKit

/// כותרת גלובלית לכל מסמכי ה־PDF.
/// מיועדת לציור בתוך UIGraphicsPDFRenderer.
enum KmiPdfHeader {

    static let HEADER_BOTTOM: CGFloat = 122
    static let CONTENT_TOP: CGFloat = 146

    private static let RIGHT_MARGIN: CGFloat = 34
    private static let ENGLISH_TEXT_LEFT: CGFloat = 308

    private static let navy = UIColor(
        red: 2 / 255.0,
        green: 43 / 255.0,
        blue: 74 / 255.0,
        alpha: 1
    )

    private static let mediumBlue = UIColor(
        red: 36 / 255.0,
        green: 103 / 255.0,
        blue: 158 / 255.0,
        alpha: 1
    )

    private static let lightHeaderBlue = UIColor(
        red: 128 / 255.0,
        green: 183 / 255.0,
        blue: 220 / 255.0,
        alpha: 1
    )

    /// יש לקרוא בתחילת העמוד, לפני ציור תוכן הדוח.
    static func draw(
        context: CGContext,
        pageWidth: CGFloat,
        isEnglish: Bool,
        titleHebrew: String,
        titleEnglish: String,
        subtitleHebrew: String,
        subtitleEnglish: String,
        generatedDate: String? = nil
    ) {
        context.saveGState()
        UIGraphicsPushContext(context)

        defer {
            UIGraphicsPopContext()
            context.restoreGState()
        }

        // רקע מסמך קבוע, ללא תלות במצב התצוגה באפליקציה.
        context.setFillColor(UIColor.white.cgColor)
        context.fill(context.boundingBoxOfClipPath)

        drawBackground(
            context: context,
            pageWidth: pageWidth
        )

        drawOfficialLogo()

        let headerTextX = KmiPdfDirection.startX(
            isEnglish: isEnglish,
            left: ENGLISH_TEXT_LEFT,
            right: pageWidth - RIGHT_MARGIN
        )

        let dateText = generatedDate ?? currentDate()

        let lines: [
            (
                text: String,
                baselineY: CGFloat,
                font: UIFont,
                color: UIColor
            )
        ] = [
            (
                text: isEnglish ? titleEnglish : titleHebrew,
                baselineY: 47,
                font: .systemFont(ofSize: 29, weight: .bold),
                color: .white
            ),
            (
                text: isEnglish ? subtitleEnglish : subtitleHebrew,
                baselineY: 72,
                font: .systemFont(ofSize: 14),
                color: .white
            ),
            (
                text: isEnglish
                    ? "Generated: \(dateText)"
                    : "תאריך הפקה: \(dateText)",
                baselineY: 94,
                font: .systemFont(ofSize: 9),
                color: UIColor.white.withAlphaComponent(230 / 255.0)
            )
        ]

        for line in lines {
            let paragraph = NSMutableParagraphStyle()

            paragraph.baseWritingDirection =
                KmiPdfDirection.textDirection(
                    isEnglish: isEnglish
                )

            // נקודת ההתחלה הפיזית מחושבת בהמשך.
            paragraph.alignment = .left
            paragraph.lineBreakMode = .byClipping

            let attributes: [NSAttributedString.Key: Any] = [
                .font: line.font,
                .foregroundColor: line.color,
                .paragraphStyle: paragraph
            ]

            let text = line.text as NSString
            let width = text.size(
                withAttributes: attributes
            ).width

            let originX = isEnglish
                ? headerTextX
                : headerTextX - width

            text.draw(
                at: CGPoint(
                    x: originX,
                    y: line.baselineY - line.font.ascender
                ),
                withAttributes: attributes
            )
        }
    }

    private static func drawBackground(
        context: CGContext,
        pageWidth: CGFloat
    ) {
        context.setFillColor(navy.cgColor)
        context.beginPath()
        context.move(to: CGPoint(x: pageWidth, y: 0))
        context.addLine(
            to: CGPoint(x: pageWidth, y: HEADER_BOTTOM)
        )
        context.addLine(
            to: CGPoint(x: 178, y: HEADER_BOTTOM)
        )
        context.addLine(to: CGPoint(x: 238, y: 0))
        context.closePath()
        context.fillPath()

        context.setFillColor(mediumBlue.cgColor)
        context.beginPath()
        context.move(
            to: CGPoint(x: 208, y: HEADER_BOTTOM)
        )
        context.addLine(
            to: CGPoint(x: 224, y: HEADER_BOTTOM)
        )
        context.addLine(to: CGPoint(x: 284, y: 0))
        context.addLine(to: CGPoint(x: 268, y: 0))
        context.closePath()
        context.fillPath()

        context.setFillColor(lightHeaderBlue.cgColor)
        context.beginPath()
        context.move(
            to: CGPoint(x: 230, y: HEADER_BOTTOM)
        )
        context.addLine(
            to: CGPoint(x: 238, y: HEADER_BOTTOM)
        )
        context.addLine(to: CGPoint(x: 298, y: 0))
        context.addLine(to: CGPoint(x: 290, y: 0))
        context.closePath()
        context.fillPath()
    }

    private static func drawOfficialLogo() {
        guard let logo = UIImage(named: "kami_logo") else {
            return
        }

        logo.draw(
            in: CGRect(
                x: 25,
                y: 8,
                width: 106,
                height: 106
            )
        )
    }

    private static func currentDate() -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "dd/MM/yyyy"

        return formatter.string(from: Date())
    }
}
