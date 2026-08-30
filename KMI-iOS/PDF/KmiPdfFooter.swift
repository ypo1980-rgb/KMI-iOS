import UIKit

/// תחתית גלובלית לכל מסמכי ה־PDF.
enum KmiPdfFooter {

    static let FOOTER_HEIGHT: CGFloat = 38
    static let CONTENT_BOTTOM_PADDING: CGFloat = 58

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

    private static let lightBlue = UIColor(
        red: 128 / 255.0,
        green: 183 / 255.0,
        blue: 220 / 255.0,
        alpha: 1
    )

    private static let mutedText = UIColor(
        red: 80 / 255.0,
        green: 100 / 255.0,
        blue: 120 / 255.0,
        alpha: 1
    )

    static func draw(
        context: CGContext,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        pageNumber: Int,
        totalPages: Int? = nil,
        isEnglish: Bool
    ) {
        context.saveGState()
        UIGraphicsPushContext(context)

        defer {
            UIGraphicsPopContext()
            context.restoreGState()
        }

        let footerTop = pageHeight - FOOTER_HEIGHT
        let regularFont = UIFont.systemFont(ofSize: 9)

        context.setStrokeColor(navy.cgColor)
        context.setLineWidth(2)
        context.setLineCap(.butt)
        context.move(to: CGPoint(x: 0, y: footerTop))
        context.addLine(
            to: CGPoint(x: pageWidth, y: footerTop)
        )
        context.strokePath()

        drawLogo(
            context: context,
            cx: 38,
            cy: footerTop + 20,
            radius: 12
        )

        drawText(
            "Together We Protect",
            x: 58,
            baselineY: footerTop + 23,
            font: regularFont,
            color: mutedText,
            alignment: .left,
            isEnglish: true
        )

        let pageText: String

        if let totalPages {
            pageText = isEnglish
                ? "Page \(pageNumber) of \(totalPages)"
                : "עמוד \(pageNumber) מתוך \(totalPages)"
        } else {
            pageText = isEnglish
                ? "Page \(pageNumber)"
                : "עמוד \(pageNumber)"
        }

        drawText(
            pageText,
            x: pageWidth / 2,
            baselineY: footerTop + 23,
            font: regularFont,
            color: mutedText,
            alignment: .center,
            isEnglish: isEnglish
        )

        drawText(
            "Krav Magen Israel",
            x: pageWidth - 66,
            baselineY: footerTop + 17,
            font: regularFont,
            color: mutedText,
            alignment: .right,
            isEnglish: true
        )

        drawText(
            "www.kami.org.il",
            x: pageWidth - 66,
            baselineY: footerTop + 29,
            font: regularFont,
            color: mutedText,
            alignment: .right,
            isEnglish: true
        )

        drawBrandLines(
            context: context,
            pageWidth: pageWidth,
            footerTop: footerTop
        )
    }

    private static func drawLogo(
        context: CGContext,
        cx: CGFloat,
        cy: CGFloat,
        radius: CGFloat
    ) {
        context.setFillColor(navy.cgColor)
        context.fillEllipse(
            in: CGRect(
                x: cx - radius,
                y: cy - radius,
                width: radius * 2,
                height: radius * 2
            )
        )

        let innerRadius = radius - 2.5

        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(
            in: CGRect(
                x: cx - innerRadius,
                y: cy - innerRadius,
                width: innerRadius * 2,
                height: innerRadius * 2
            )
        )

        let font = UIFont.systemFont(
            ofSize: radius * 0.44,
            weight: .bold
        )

        let letters = Array("KAMI")
        let letterSpacing = radius * 0.055

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font
        ]

        let widths = letters.map { character in
            (String(character) as NSString)
                .size(withAttributes: attributes)
                .width
        }

        let completeTextWidth =
            widths.reduce(CGFloat.zero, +)
            + letterSpacing * CGFloat(letters.count - 1)

        var letterX = cx - completeTextWidth / 2

        for (index, character) in letters.enumerated() {
            drawText(
                String(character),
                x: letterX,
                baselineY: cy + radius * 0.21,
                font: font,
                color: navy,
                alignment: .left,
                isEnglish: true
            )

            letterX += widths[index] + letterSpacing
        }
    }

    private static func drawBrandLines(
        context: CGContext,
        pageWidth: CGFloat,
        footerTop: CGFloat
    ) {
        let startX = pageWidth - 42
        let endX = pageWidth - 18
        let colors = [navy, mediumBlue, lightBlue]

        context.setLineWidth(3)
        context.setLineCap(.round)

        for (index, color) in colors.enumerated() {
            let y = footerTop + 15 + CGFloat(index) * 6

            context.setStrokeColor(color.cgColor)
            context.move(to: CGPoint(x: startX, y: y))
            context.addLine(to: CGPoint(x: endX, y: y))
            context.strokePath()
        }
    }

    /// מיקום הטקסט לפי נקודת עיגון וקו בסיס,
    /// בדומה ל־Canvas.drawText ב־Android.
    private static func drawText(
        _ text: String,
        x: CGFloat,
        baselineY: CGFloat,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment,
        isEnglish: Bool
    ) {
        let paragraph = NSMutableParagraphStyle()

        paragraph.baseWritingDirection =
            KmiPdfDirection.textDirection(
                isEnglish: isEnglish
            )

        // היישור הפיזי מחושב באמצעות originX.
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byClipping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]

        let value = text as NSString
        let width = value.size(withAttributes: attributes).width

        let originX: CGFloat

        switch alignment {
        case .center:
            originX = x - width / 2
        case .right:
            originX = x - width
        default:
            originX = x
        }

        value.draw(
            at: CGPoint(
                x: originX,
                y: baselineY - font.ascender
            ),
            withAttributes: attributes
        )
    }
}
