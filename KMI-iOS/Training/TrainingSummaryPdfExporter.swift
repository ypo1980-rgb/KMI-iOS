import Foundation
import SwiftUI
import UIKit
import CoreText
import Shared

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

        dateFormatter.dateFormat = isEnglish ? "MM/dd/yyyy" : "dd/MM/yyyy"
        let displayDate = dateFormatter.string(from: date)

        dateFormatter.dateFormat = "dd-MM-yyyy"
        let fileDate = dateFormatter.string(from: date)

        let branch = state.branchName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let group = state.groupKey
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let privacyEnabled = DemoPrivacy.shared.isEnabled
        let subtitle = [
            "\u{2066}\(displayDate)\u{2069}",
            privacyEnabled || branch.isEmpty
                ? ""
                : TrainingCatalogIOS.displayBranch(branch, isEnglish: isEnglish),
            privacyEnabled || group.isEmpty
                ? ""
                : TrainingCatalogIOS.displayGroup(group, isEnglish: isEnglish)
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " · ")

        var sectionHeadings: [NSRange] = []
        var beltHeadings: [(belt: Belt?, range: NSRange)] = []

        let text = state.makeShareText(
            isEnglish: isEnglish,
            privacyEnabled: privacyEnabled,
            onSectionHeading: { range in
                sectionHeadings.append(range)
            },
            onBeltHeading: { belt, range in
                beltHeadings.append((belt: belt, range: range))
            }
        )

        let paragraph = NSMutableParagraphStyle()
        paragraph.baseWritingDirection = KmiPdfDirection.textDirection(
            isEnglish: isEnglish
        )
        paragraph.alignment = KmiPdfDirection.textAlign(
            isEnglish: isEnglish
        )
        paragraph.defaultTabInterval = 24
        paragraph.lineSpacing = 4
        paragraph.paragraphSpacing = 6
        paragraph.lineBreakMode = .byWordWrapping

        let attributedText = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(
                    ofSize: 13,
                    weight: .regular
                ),
                .foregroundColor: UIColor(
                    KmiAppTheme.onSurface(for: .light)
                ),
                .paragraphStyle: paragraph
            ]
        )

        for range in sectionHeadings {
            attributedText.addAttributes(
                [
                    .font: UIFont.systemFont(ofSize: 17, weight: .bold),
                    .foregroundColor: UIColor(KmiAppTheme.primary(for: .light))
                ],
                range: range
            )
        }

        for heading in beltHeadings {
            let accent = heading.belt.map { KmiBeltPalette.color(for: $0) }
                ?? KmiAppTheme.outline(for: .light)

            attributedText.addAttributes(
                [
                    .font: UIFont.systemFont(ofSize: 15, weight: .bold),
                    .backgroundColor: UIColor(accent).withAlphaComponent(0.22)
                ],
                range: heading.range
            )
        }

        let pageRect = CGRect(
            x: 0,
            y: 0,
            width: 595,
            height: 842
        )

        let horizontalMargin: CGFloat = 40
        let contentRect = CGRect(
            x: horizontalMargin,
            y: KmiPdfHeader.CONTENT_TOP,
            width: pageRect.width - horizontalMargin * 2,
            height:
                pageRect.height
                - KmiPdfHeader.CONTENT_TOP
                - KmiPdfFooter.CONTENT_BOTTOM_PADDING
        )

        var beltHeadingBackgrounds: [(range: NSRange, color: UIColor)] = []

        attributedText.enumerateAttribute(
            .backgroundColor,
            in: NSRange(location: 0, length: attributedText.length)
        ) { value, range, _ in
            if let color = value as? UIColor {
                beltHeadingBackgrounds.append((range: range, color: color))
            }
        }

        for heading in beltHeadingBackgrounds {
            attributedText.removeAttribute(
                .backgroundColor,
                range: heading.range
            )
        }

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

        let headingStarts = beltHeadings.map { heading in
            let headingEnd = NSMaxRange(heading.range)
            let remainingText = (text as NSString).substring(from: headingEnd)
            let firstContent = (remainingText as NSString).rangeOfCharacter(
                from: CharacterSet.whitespacesAndNewlines.inverted
            )

            return (
                start: heading.range.location,
                firstContent: firstContent.location == NSNotFound
                    ? attributedText.length
                    : headingEnd + firstContent.location
            )
        }

        var frames: [CTFrame] = []
        var location = 0

        while location < attributedText.length {
            var frame = CTFramesetterCreateFrame(
                framesetter,
                CFRange(location: location, length: 0),
                textPath,
                nil
            )

            var visibleRange = CTFrameGetVisibleStringRange(frame)

            guard visibleRange.length > 0 else {
                throw TrainingSummaryPdfExportError.unableToFitContent
            }

            let pageEnd = visibleRange.location + visibleRange.length

            if let heading = headingStarts.first(where: {
                $0.start > location &&
                $0.start < pageEnd &&
                $0.firstContent >= pageEnd
            }) {
                let shortenedFrame = CTFramesetterCreateFrame(
                    framesetter,
                    CFRange(location: location, length: heading.start - location),
                    textPath,
                    nil
                )
                let shortenedRange = CTFrameGetVisibleStringRange(shortenedFrame)

                if shortenedRange.length > 0 {
                    frame = shortenedFrame
                    visibleRange = shortenedRange
                }
            }

            frames.append(frame)
            location = visibleRange.location + visibleRange.length
        }

        func drawBeltHeadingBackgrounds(
            in frame: CTFrame,
            context: CGContext
        ) {
            let visibleRange = CTFrameGetVisibleStringRange(frame)
            let pageRange = NSRange(
                location: visibleRange.location,
                length: visibleRange.length
            )
            let headingsOnPage = beltHeadingBackgrounds.filter {
                NSIntersectionRange($0.range, pageRange).length > 0
            }

            guard !headingsOnPage.isEmpty else { return }

            guard let lines = CTFrameGetLines(frame) as? [CTLine],
                  !lines.isEmpty else {
                return
            }

            var origins = Array(repeating: CGPoint.zero, count: lines.count)
            origins.withUnsafeMutableBufferPointer { buffer in
                if let baseAddress = buffer.baseAddress {
                    CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), baseAddress)
                }
            }

            for heading in headingsOnPage {
                var headingBounds = CGRect.null

                for (index, line) in lines.enumerated() {
                    let range = CTLineGetStringRange(line)
                    let lineRange = NSRange(location: range.location, length: range.length)
                    guard NSIntersectionRange(lineRange, heading.range).length > 0 else {
                        continue
                    }

                    var ascent: CGFloat = 0
                    var descent: CGFloat = 0
                    CTLineGetTypographicBounds(line, &ascent, &descent, nil)

                    let lineBounds = CGRect(
                        x: 0,
                        y: origins[index].y - descent - 2,
                        width: contentRect.width,
                        height: ascent + descent + 4
                    )
                    headingBounds = headingBounds.union(lineBounds)
                }

                let visibleBounds = headingBounds.intersection(
                    CGRect(origin: .zero, size: contentRect.size)
                )
                guard !visibleBounds.isEmpty else { continue }

                let borderWidth: CGFloat = 1.6
                let bounds = visibleBounds.insetBy(
                    dx: borderWidth / 2,
                    dy: borderWidth / 2
                )
                guard !bounds.isEmpty else { continue }

                let cornerRadius = min(12, bounds.height / 2)
                let path = CGPath(
                    roundedRect: bounds,
                    cornerWidth: cornerRadius,
                    cornerHeight: cornerRadius,
                    transform: nil
                )

                context.setFillColor(
                    heading.color.withAlphaComponent(0.11).cgColor
                )
                context.setStrokeColor(
                    heading.color.withAlphaComponent(1).cgColor
                )
                context.setLineWidth(borderWidth)
                context.addPath(path)
                context.drawPath(using: .fillStroke)
            }
        }

        func drawSectionDividers(in frame: CTFrame, context: CGContext) {
            guard !sectionHeadings.isEmpty,
                  let lines = CTFrameGetLines(frame) as? [CTLine],
                  !lines.isEmpty else { return }

            var origins = Array(repeating: CGPoint.zero, count: lines.count)
            origins.withUnsafeMutableBufferPointer { buffer in
                if let baseAddress = buffer.baseAddress {
                    CTFrameGetLineOrigins(
                        frame,
                        CFRange(location: 0, length: 0),
                        baseAddress
                    )
                }
            }

            context.setStrokeColor(
                UIColor(KmiAppTheme.outlineVariant(for: .light)).cgColor
            )
            context.setLineWidth(1)

            for (index, line) in lines.enumerated() {
                let range = CTLineGetStringRange(line)
                let lineEnd = range.location + range.length

                guard sectionHeadings.contains(where: { heading in
                    let end = NSMaxRange(heading)
                    return end > range.location && end <= lineEnd
                }) else { continue }

                var descent: CGFloat = 0
                CTLineGetTypographicBounds(line, nil, &descent, nil)

                let y = origins[index].y - descent - 2
                guard y >= 1 else { continue }

                context.move(to: CGPoint(x: 0, y: y))
                context.addLine(to: CGPoint(x: contentRect.width, y: y))
                context.strokePath()
            }
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
                    subtitleHebrew: subtitle,
                    subtitleEnglish: subtitle
                )

                context.saveGState()

                context.translateBy(
                    x: contentRect.minX,
                    y: contentRect.maxY
                )
                context.scaleBy(x: 1, y: -1)

                context.saveGState()
                drawBeltHeadingBackgrounds(in: frame, context: context)
                drawSectionDividers(in: frame, context: context)
                context.restoreGState()
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
                ? "KMI_Training_Summary_\(fileDate).pdf"
                : "סיכום_אימון_קמי_\(fileDate).pdf"
        )

        try data.write(
            to: url,
            options: .atomic
        )

        return url
    }
}
