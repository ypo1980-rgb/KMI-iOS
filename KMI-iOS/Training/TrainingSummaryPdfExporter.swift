import Foundation
import UIKit
import CoreText

enum TrainingSummaryPdfExportError: Error {
    case invalidDate
    case unableToFitContent
}

@MainActor
enum TrainingSummaryPdfExporter {

    static func export(
        state: TrainingSummaryUiState,
        isEnglish: Bool
    ) throws -> URL {
        let dateIso = state.dateIso
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = ShabbatHolidayCheckerIOS.calendar
        dateFormatter.timeZone = ShabbatHolidayCheckerIOS.timeZone
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.isLenient = false

        guard let date = dateFormatter.date(from: dateIso),
              dateFormatter.string(from: date) == dateIso else {
            throw TrainingSummaryPdfExportError.invalidDate
        }

        dateFormatter.dateFormat = "dd/MM/yyyy"
        let displayDate = dateFormatter.string(from: date)

        let text = state.makeShareText(
            isEnglish: isEnglish,
            privacyEnabled: DemoPrivacy.shared.isEnabled
        )

        let paragraph = NSMutableParagraphStyle()
        paragraph.baseWritingDirection =
            isEnglish ? .leftToRight : .rightToLeft

        paragraph.alignment =
            isEnglish
            ? .left
            : .right

        paragraph.defaultTabInterval = 24
        paragraph.lineSpacing = 4
        paragraph.paragraphSpacing = 6
        paragraph.lineBreakMode = .byWordWrapping

        let attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(
                    ofSize: 12,
                    weight: .regular
                ),
                .foregroundColor: UIColor(
                    red: 23 / 255.0,
                    green: 32 / 255.0,
                    blue: 51 / 255.0,
                    alpha: 1
                ),
                .paragraphStyle: paragraph
            ]
        )

        let pageRect = CGRect(
            x: 0,
            y: 0,
            width: 595,
            height: 842
        )

        let contentRect = CGRect(
            x: 34,
            y: KmiPdfHeader.CONTENT_TOP,
            width: pageRect.width - 68,
            height:
                pageRect.height
                - KmiPdfHeader.CONTENT_TOP
                - KmiPdfFooter.CONTENT_BOTTOM_PADDING
        )

        let framesetter = CTFramesetterCreateWithAttributedString(
            attributedText as CFAttributedString
        )

        let textPath = CGPath(
            rect: CGRect(
                origin: .zero,
                size: contentRect.size
            ),
            transform: nil
        )

        var frames: [CTFrame] = []
        var location = 0

        while location < attributedText.length {
            let frame = CTFramesetterCreateFrame(
                framesetter,
                CFRange(location: location, length: 0),
                textPath,
                nil
            )

            let visibleRange = CTFrameGetVisibleStringRange(frame)

            guard visibleRange.length > 0 else {
                throw TrainingSummaryPdfExportError.unableToFitContent
            }

            frames.append(frame)
            location += visibleRange.length
        }

        let renderer = UIGraphicsPDFRenderer(
            bounds: pageRect
        )

        let data = renderer.pdfData { rendererContext in
            for (index, frame) in frames.enumerated() {
                rendererContext.beginPage()

                let context = rendererContext.cgContext

                KmiPdfHeader.draw(
                    context: context,
                    pageWidth: pageRect.width,
                    isEnglish: isEnglish,
                    titleHebrew: "סיכום אימון",
                    titleEnglish: "Training Summary",
                    subtitleHebrew: "תאריך אימון: \(displayDate)",
                    subtitleEnglish: "Training date: \(displayDate)"
                )

                context.saveGState()

                context.translateBy(
                    x: contentRect.minX,
                    y: contentRect.maxY
                )
                context.scaleBy(x: 1, y: -1)
                context.textMatrix = .identity

                CTFrameDraw(frame, context)

                context.restoreGState()

                KmiPdfFooter.draw(
                    context: context,
                    pageWidth: pageRect.width,
                    pageHeight: pageRect.height,
                    pageNumber: index + 1,
                    totalPages: frames.count,
                    isEnglish: isEnglish
                )
            }
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "shared_pdfs",
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let url = directory.appendingPathComponent(
            isEnglish
                ? "Training_Summary.pdf"
                : "סיכום_אימון.pdf"
        )

        if FileManager.default.fileExists(
            atPath: url.path
        ) {
            try FileManager.default.removeItem(
                at: url
            )
        }

        try data.write(
            to: url,
            options: .atomic
        )

        return url
    }
}
