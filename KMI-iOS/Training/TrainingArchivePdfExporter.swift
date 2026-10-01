import UIKit

enum TrainingArchivePdfExportError: Error {
    case contentTooTall
}

@MainActor
enum TrainingArchivePdfExporter {

    private struct TextLine {
        let text: String
        let font: UIFont
        let color: UIColor
        let height: CGFloat
    }

    private struct PdfCard {
        let lines: [TextLine]
        let height: CGFloat
        let isCancelled: Bool
    }

    static func export(
        items: [TrainingArchiveItem],
        fromDate: Date,
        toDate: Date,
        isEnglish: Bool
    ) throws -> URL {
        let pageRect = CGRect(
            x: 0,
            y: 0,
            width: 595,
            height: 842
        )

        let margin: CGFloat = 26
        let cardWidth = pageRect.width - margin * 2
        let textWidth = cardWidth - 28
        let contentTop = KmiPdfHeader.CONTENT_TOP
        let contentBottom =
            pageRect.height - KmiPdfFooter.CONTENT_BOTTOM_PADDING
        let availableHeight = contentBottom - contentTop
        let spacing: CGFloat = 8

        let textColor = UIColor(
            red: 23 / 255.0,
            green: 32 / 255.0,
            blue: 51 / 255.0,
            alpha: 1
        )

        let secondaryColor = UIColor(
            red: 71 / 255.0,
            green: 84 / 255.0,
            blue: 103 / 255.0,
            alpha: 1
        )

        let completedColor = UIColor(
            red: 103 / 255.0,
            green: 80 / 255.0,
            blue: 164 / 255.0,
            alpha: 1
        )

        let cancelledColor = UIColor(
            red: 186 / 255.0,
            green: 26 / 255.0,
            blue: 26 / 255.0,
            alpha: 1
        )

        func paragraphStyle() -> NSMutableParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.alignment = KmiPdfDirection.textAlign(
                isEnglish: isEnglish
            )
            style.baseWritingDirection = KmiPdfDirection.textDirection(
                isEnglish: isEnglish
            )
            style.lineBreakMode = .byWordWrapping
            return style
        }

        func makeLine(
            _ text: String,
            font: UIFont,
            color: UIColor
        ) -> TextLine {
            let value = NSAttributedString(
                string: text,
                attributes: [
                    .font: font,
                    .paragraphStyle: paragraphStyle()
                ]
            )

            let bounds = value.boundingRect(
                with: CGSize(
                    width: textWidth,
                    height: .greatestFiniteMagnitude
                ),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )

            return TextLine(
                text: text,
                font: font,
                color: color,
                height: max(font.lineHeight, ceil(bounds.height)) + 2
            )
        }

        let dateFormatter = DateFormatter()
        dateFormatter.calendar = ShabbatHolidayCheckerIOS.calendar
        dateFormatter.timeZone = ShabbatHolidayCheckerIOS.timeZone
        dateFormatter.locale = Locale(
            identifier: isEnglish ? "en_US_POSIX" : "he_IL"
        )
        dateFormatter.dateFormat = "dd/MM/yyyy"

        let timeFormatter = DateFormatter()
        timeFormatter.calendar = ShabbatHolidayCheckerIOS.calendar
        timeFormatter.timeZone = ShabbatHolidayCheckerIOS.timeZone
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "HH:mm"

        let rangeText =
            "\(dateFormatter.string(from: fromDate)) – "
            + dateFormatter.string(from: toDate)

        // מצב הפרטיות נבדק מחדש ברגע הייצוא.
        let privacyEnabled = DemoPrivacy.shared.isEnabled

        let cards: [PdfCard] = items.map { item in
            let place = TrainingCatalogIOS.displayPlace(
                item.training.place,
                isEnglish: isEnglish
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

            let address = TrainingCatalogIOS.displayAddress(
                item.training.address,
                isEnglish: isEnglish
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

            let rawCoach = item.training.coach
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let displayedCoach: String
            if rawCoach.isEmpty {
                displayedCoach = ""
            } else if privacyEnabled {
                displayedCoach = isEnglish ? "Coach" : "מאמן"
            } else {
                displayedCoach = TrainingCatalogIOS.displayCoach(
                    rawCoach,
                    isEnglish: isEnglish
                )
            }

            var lines: [TextLine] = [
                makeLine(
                    place.isEmpty
                        ? (isEnglish ? "Training" : "אימון")
                        : place,
                    font: .boldSystemFont(ofSize: 14),
                    color: textColor
                ),
                makeLine(
                    "\(dateFormatter.string(from: item.effectiveStartDate)) · "
                        + "\(timeFormatter.string(from: item.effectiveStartDate)) – "
                        + timeFormatter.string(from: item.effectiveEndDate),
                    font: .systemFont(ofSize: 10.5),
                    color: secondaryColor
                )
            ]

            let locationText = [
                item.branch.trimmingCharacters(in: .whitespacesAndNewlines),
                TrainingCatalogIOS.displayGroup(
                    item.group,
                    isEnglish: isEnglish
                ),
                address
            ]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")

            if !locationText.isEmpty {
                lines.append(
                    makeLine(
                        locationText,
                        font: .systemFont(ofSize: 10.5),
                        color: secondaryColor
                    )
                )
            }

            if !displayedCoach.isEmpty {
                lines.append(
                    makeLine(
                        isEnglish
                            ? "Coach: \(displayedCoach)"
                            : "מאמן: \(displayedCoach)",
                        font: .systemFont(ofSize: 10.5),
                        color: secondaryColor
                    )
                )
            }

            lines.append(
                makeLine(
                    item.status.title(isEnglish: isEnglish),
                    font: .boldSystemFont(ofSize: 11),
                    color: item.isCancelled
                        ? cancelledColor
                        : completedColor
                )
            )

            let measuredHeight =
                lines.reduce(CGFloat.zero) { $0 + $1.height }
                + CGFloat(max(0, lines.count - 1)) * 5
                + 24

            return PdfCard(
                lines: lines,
                height: max(94, measuredHeight),
                isCancelled: item.isCancelled
            )
        }

        // חלוקת העמודים מחושבת לפי גובה הטקסט בפועל.
        var pages: [[PdfCard]] = [[]]
        var occupiedHeight: CGFloat = 0

        for card in cards {
            guard card.height <= availableHeight else {
                throw TrainingArchivePdfExportError.contentTooTall
            }

            let requiredSpacing = pages[pages.count - 1].isEmpty
                ? CGFloat.zero
                : spacing

            if occupiedHeight + requiredSpacing + card.height
                > availableHeight {
                pages.append([])
                occupiedHeight = 0
            }

            if !pages[pages.count - 1].isEmpty {
                occupiedHeight += spacing
            }

            pages[pages.count - 1].append(card)
            occupiedHeight += card.height
        }

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            for (pageIndex, pageCards) in pages.enumerated() {
                context.beginPage()
                let cg = context.cgContext

                KmiPdfHeader.draw(
                    context: cg,
                    pageWidth: pageRect.width,
                    isEnglish: isEnglish,
                    titleHebrew: "ארכיון אימונים",
                    titleEnglish: "Training Archive",
                    subtitleHebrew: rangeText,
                    subtitleEnglish: rangeText
                )

                var y = contentTop

                if pageCards.isEmpty {
                    let style = paragraphStyle()
                    style.alignment = .center

                    NSAttributedString(
                        string: isEnglish
                            ? "No trainings were found in the selected range."
                            : "לא נמצאו אימונים בטווח שנבחר.",
                        attributes: [
                            .font: UIFont.boldSystemFont(ofSize: 16),
                            .foregroundColor: textColor,
                            .paragraphStyle: style
                        ]
                    )
                    .draw(
                        in: CGRect(
                            x: margin,
                            y: y + 40,
                            width: cardWidth,
                            height: availableHeight - 40
                        )
                    )
                }

                for card in pageCards {
                    let rect = CGRect(
                        x: margin,
                        y: y,
                        width: cardWidth,
                        height: card.height
                    )

                    let path = UIBezierPath(
                        roundedRect: rect,
                        cornerRadius: 10
                    )

                    UIColor(
                        red: 248 / 255.0,
                        green: 251 / 255.0,
                        blue: 255 / 255.0,
                        alpha: 1
                    )
                    .setFill()
                    path.fill()

                    (
                        card.isCancelled
                            ? cancelledColor
                            : completedColor
                    )
                    .withAlphaComponent(0.24)
                    .setStroke()
                    path.lineWidth = 1
                    path.stroke()

                    var lineY = rect.minY + 12

                    for line in card.lines {
                        NSAttributedString(
                            string: line.text,
                            attributes: [
                                .font: line.font,
                                .foregroundColor: line.color,
                                .paragraphStyle: paragraphStyle()
                            ]
                        )
                        .draw(
                            in: CGRect(
                                x: rect.minX + 14,
                                y: lineY,
                                width: textWidth,
                                height: line.height
                            )
                        )

                        lineY += line.height + 5
                    }

                    y = rect.maxY + spacing
                }

                KmiPdfFooter.draw(
                    context: cg,
                    pageWidth: pageRect.width,
                    pageHeight: pageRect.height,
                    pageNumber: pageIndex + 1,
                    totalPages: pages.count,
                    isEnglish: isEnglish
                )
            }
        }

        let fileName = isEnglish
            ? "Training_Archive.pdf"
            : "ארכיון_אימונים.pdf"

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)

        try data.write(to: url, options: .atomic)
        return url
    }
}
