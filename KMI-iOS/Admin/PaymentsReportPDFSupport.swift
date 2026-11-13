import SwiftUI
import UIKit

struct PaymentsPDFShareItem: Identifiable {
    let url: URL

    var id: String {
        url.path
    }
}

enum PaymentsReportPDFGenerator {
    
    private static let pageBounds = CGRect(
        x: 0,
        y: 0,
        width: 595,
        height: 842
    )
    
    private static let horizontalMargin:
    CGFloat = 40
    
    private static var contentBottom: CGFloat {
        pageBounds.height - KmiPdfFooter.CONTENT_BOTTOM_PADDING
    }
    
    private static var contentWidth: CGFloat {
        pageBounds.width -
        (horizontalMargin * 2)
    }
    
    static func create(
        items: [PaymentReportItem],
        totalRequired: Double,
        totalPaid: Double,
        paidCount: Int,
        unpaidCount: Int,
        collectionPercent: Double,
        selectedBranch: String,
        isEnglish: Bool
    ) throws -> URL {
        let branch = selectedBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        let branchLabel = branch.isEmpty
        ? (isEnglish ? "All Branches" : "כל הסניפים")
        : branch
        
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("shared_pdfs", isDirectory: true)
        
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        let fileURL = directory.appendingPathComponent(
            isEnglish ? "Payments Report.pdf" : "דוח תשלומים.pdf"
        )
        
        let format =
        UIGraphicsPDFRendererFormat()
        
        let metadata: [String: Any] = [
            kCGPDFContextTitle as String:
                isEnglish
            ? "Payments Report"
            : "דו״ח תשלומים",
            
            kCGPDFContextAuthor as String:
                "K.M.I",
            
            kCGPDFContextCreator as String:
                "KMI iOS"
        ]
        
        format.documentInfo = metadata
        
        let renderer =
        UIGraphicsPDFRenderer(
            bounds: pageBounds,
            format: format
        )
        
        let summaryHeight: CGFloat = 84
        let summarySpacing: CGFloat = 18
        let detailsHeadingHeight: CGFloat = 62
        let rowHeight: CGFloat = 30
        let rowSpacing: CGFloat = 4
        let rowStep = rowHeight + rowSpacing
        
        let continuationBodyTop = KmiPdfHeader.CONTENT_TOP + detailsHeadingHeight
        let firstPageBodyTop = continuationBodyTop + summaryHeight + summarySpacing
        
        func rowCapacity(from bodyTop: CGFloat) -> Int {
            let availableHeight = contentBottom - bodyTop
            return max(0, Int((availableHeight + rowSpacing) / rowStep))
        }
        
        let firstPageCapacity = rowCapacity(from: firstPageBodyTop)
        let continuationCapacity = max(1, rowCapacity(from: continuationBodyTop))
        let remainingRows = max(0, items.count - firstPageCapacity)
        let totalPages = 1 + (remainingRows + continuationCapacity - 1) / continuationCapacity
        
        let data = renderer.pdfData { context in
            var currentY: CGFloat = 0
            var pageNumber = 0
            
            func paragraphStyle(
                alignment:
                NSTextAlignment
            ) -> NSMutableParagraphStyle {
                let style =
                NSMutableParagraphStyle()
                
                style.alignment = alignment
                style.baseWritingDirection = isEnglish ? .leftToRight : .rightToLeft
                style.lineBreakMode = .byWordWrapping
                return style
            }
            
            func textAlignment()
            -> NSTextAlignment {
                isEnglish
                ? .left
                : .right
            }
            
            func drawText(
                _ text: String,
                rect: CGRect,
                font: UIFont,
                color: UIColor,
                alignment:
                NSTextAlignment? = nil
            ) {
                let style =
                paragraphStyle(
                    alignment:
                        alignment ??
                    textAlignment()
                )
                
                let attributes:
                [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: style
                ]
                
                (text as NSString).draw(
                    in: rect,
                    withAttributes:
                        attributes
                )
            }
            
            func drawFooter() {
                KmiPdfFooter.draw(
                    context: context.cgContext,
                    pageWidth: pageBounds.width,
                    pageHeight: pageBounds.height,
                    pageNumber: pageNumber,
                    totalPages: totalPages,
                    isEnglish: isEnglish
                )
            }
            
            func beginPage() {
                if pageNumber > 0 {
                    drawFooter()
                }
                
                context.beginPage()
                pageNumber += 1
                
                KmiPdfHeader.draw(
                    context: context.cgContext,
                    pageWidth: pageBounds.width,
                    isEnglish: isEnglish,
                    titleHebrew: "דו״ח תשלומים",
                    titleEnglish: "Payments Report",
                    subtitleHebrew: "סניף: \(branchLabel)",
                    subtitleEnglish: "Branch: \(branchLabel)"
                )
                
                currentY = KmiPdfHeader.CONTENT_TOP
            }
            
            let tableWidths: [CGFloat] = [0.23, 0.25, 0.12, 0.12, 0.14, 0.14]
            
            func tableCell(_ index: Int, y: CGFloat, height: CGFloat) -> CGRect {
                let offset = tableWidths.prefix(index).reduce(0, +) * contentWidth
                let width = tableWidths[index] * contentWidth
                let x = isEnglish
                ? horizontalMargin + offset
                : pageBounds.width - horizontalMargin - offset - width
                
                return CGRect(x: x + 5, y: y, width: width - 10, height: height)
            }
            
            func drawTableCell(
                _ value: String,
                index: Int,
                y: CGFloat,
                font: UIFont,
                color: UIColor,
                alignment: NSTextAlignment? = nil
            ) {
                let style = paragraphStyle(alignment: alignment ?? textAlignment())
                style.lineBreakMode = .byTruncatingTail
                
                (value as NSString).draw(
                    in: tableCell(index, y: y, height: ceil(font.lineHeight) + 1),
                    withAttributes: [
                        .font: font,
                        .foregroundColor: color,
                        .paragraphStyle: style
                    ]
                )
            }
            
            func drawDetailsHeading() {
                let title = pageNumber == 1
                ? (isEnglish ? "Payment details" : "פירוט תשלומים")
                : (isEnglish ? "Payment details — continued" : "פירוט תשלומים — המשך")
                
                drawText(
                    title,
                    rect: CGRect(
                        x: horizontalMargin,
                        y: currentY,
                        width: contentWidth,
                        height: 26
                    ),
                    font: .systemFont(ofSize: 17, weight: .heavy),
                    color: UIColor(KmiAppTheme.primary(for: .light))
                )
                
                let tableHeaderY = currentY + 28
                let headerRect = CGRect(
                    x: horizontalMargin,
                    y: tableHeaderY,
                    width: contentWidth,
                    height: 28
                )
                
                UIColor(KmiAppTheme.primary(for: .light)).setFill()
                UIBezierPath(roundedRect: headerRect, cornerRadius: 8).fill()
                
                let titles = isEnglish
                ? ["Name", "Branch", "Required", "Paid", "Status", "Phone"]
                : ["שם", "סניף", "נדרש", "שולם", "סטטוס", "טלפון"]
                
                for (index, title) in titles.enumerated() {
                    drawTableCell(
                        title,
                        index: index,
                        y: tableHeaderY + 7,
                        font: .systemFont(ofSize: 9, weight: .bold),
                        color: UIColor(KmiAppTheme.onPrimary(for: .light))
                    )
                }
                
                currentY += detailsHeadingHeight
            }
            
            beginPage()
            
            drawText(
                isEnglish ? "Collection Summary" : "סיכום גבייה",
                rect: CGRect(
                    x: horizontalMargin,
                    y: currentY,
                    width: contentWidth,
                    height: 22
                ),
                font: .systemFont(ofSize: 16, weight: .bold),
                color: UIColor(KmiAppTheme.primary(for: .light))
            )
            
            let summaryTiles = [
                (isEnglish ? "Collection" : "גבייה",
                 String(format: "%.0f%%", collectionPercent)),
                (isEnglish ? "Paid / Required" : "נגבה / נדרש",
                 String(format: "₪%.0f / ₪%.0f", totalPaid, totalRequired)),
                (isEnglish ? "Paid branch records" : "רשומות סניף ששולמו",
                 String(paidCount)),
                (isEnglish ? "Unpaid branch records" : "רשומות סניף שלא שולמו במלואן",
                 String(unpaidCount))
            ]
            
            let tileGap: CGFloat = 8
            let tileWidth = (contentWidth - 3 * tileGap) / 4
            
            for (index, tile) in summaryTiles.enumerated() {
                let column = isEnglish ? index : summaryTiles.count - 1 - index
                let rect = CGRect(
                    x: horizontalMargin + CGFloat(column) * (tileWidth + tileGap),
                    y: currentY + 26,
                    width: tileWidth,
                    height: 58
                )
                
                let tilePath = UIBezierPath(roundedRect: rect, cornerRadius: 10)
                UIColor(KmiAppTheme.surfaceVariant(for: .light)).setFill()
                tilePath.fill()
                UIColor(KmiAppTheme.outlineVariant(for: .light)).setStroke()
                tilePath.lineWidth = 0.75
                tilePath.stroke()
                
                drawText(
                    tile.1,
                    rect: CGRect(x: rect.minX + 4, y: rect.minY + 8,
                                 width: rect.width - 8, height: 18),
                    font: .systemFont(ofSize: 12, weight: .bold),
                    color: UIColor(KmiAppTheme.onSurface(for: .light)),
                    alignment: .center
                )
                drawText(
                    tile.0,
                    rect: CGRect(x: rect.minX + 4, y: rect.minY + 29,
                                 width: rect.width - 8, height: 26),
                    font: .systemFont(ofSize: 8.5, weight: .medium),
                    color: UIColor(KmiAppTheme.onSurfaceVariant(for: .light)),
                    alignment: .center
                )
            }
            
            currentY += summaryHeight + summarySpacing
            drawDetailsHeading()
            
            if items.isEmpty {
                drawText(
                    isEnglish
                    ? "No trainees matched the selected filters."
                    : "לא נמצאו מתאמנים בהתאם לסינון שנבחר.",
                    rect: CGRect(
                        x: horizontalMargin,
                        y: currentY,
                        width: contentWidth,
                        height: 44
                    ),
                    font:
                            .systemFont(
                                ofSize: 14,
                                weight: .semibold
                            ),
                    color: .darkGray,
                    alignment: .center
                )
                
                currentY += 50
            }
            
            for (index, item) in items.enumerated() {
                if index >= firstPageCapacity,
                   (index - firstPageCapacity).isMultiple(of: continuationCapacity) {
                    beginPage()
                    drawDetailsHeading()
                }
                
                let rowRect = CGRect(
                    x: horizontalMargin,
                    y: currentY,
                    width: contentWidth,
                    height: rowHeight
                )
                
                let rowColor = index.isMultiple(of: 2)
                ? KmiAppTheme.surface(for: .light)
                : KmiAppTheme.surfaceVariant(for: .light)
                
                UIColor(rowColor).setFill()
                UIBezierPath(roundedRect: rowRect, cornerRadius: 6).fill()
                
                let statusText: String
                let statusColor: UIColor
                
                switch item.status {
                case .paid:
                    statusText = isEnglish ? "Paid" : "שולם"
                    statusColor = UIColor(KmiAppTheme.success(for: .light))
                case .unpaid:
                    statusText = isEnglish ? "Unpaid" : "לא שולם"
                    statusColor = UIColor(KmiAppTheme.error(for: .light))
                case .partial:
                    statusText = isEnglish ? "Partial" : "שולם חלקית"
                    statusColor = UIColor(KmiAppTheme.warning(for: .light))
                }
                
                let branch = item.branchName.trimmingCharacters(in: .whitespacesAndNewlines)
                let phone = item.phone.trimmingCharacters(in: .whitespacesAndNewlines)
                let values = [
                    item.fullName,
                    branch.isEmpty ? "—" : branch,
                    String(format: "₪%.0f", item.requiredAmount),
                    String(format: "₪%.0f", item.paidAmount),
                    statusText,
                    phone.isEmpty ? "—" : phone
                ]
                
                for (column, value) in values.enumerated() {
                    drawTableCell(
                        value,
                        index: column,
                        y: currentY + 8,
                        font: .systemFont(ofSize: 9, weight: column == 4 ? .bold : .regular),
                        color: column == 4
                        ? statusColor
                        : UIColor(KmiAppTheme.onSurface(for: .light)),
                        alignment: [2, 3, 5].contains(column) ? .left : nil
                    )
                }
                
                currentY = rowRect.maxY + rowSpacing
            }
            
            drawFooter()
        }
        
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
    
}
