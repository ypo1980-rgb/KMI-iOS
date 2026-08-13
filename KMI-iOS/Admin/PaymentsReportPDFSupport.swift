import SwiftUI
import UIKit

struct PaymentsPDFShareItem: Identifiable {
    let url: URL

    var id: String {
        url.path
    }
}

struct PaymentsPDFShareSheet:
    UIViewControllerRepresentable {

    let url: URL

    func makeUIViewController(
        context: Context
    ) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {
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

    private static let topMargin:
        CGFloat = 38

    private static let bottomMargin:
        CGFloat = 42

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
        let cleanBranch = selectedBranch
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .replacingOccurrences(
                of: "/",
                with: "-"
            )
            .replacingOccurrences(
                of: "\\",
                with: "-"
            )
            .replacingOccurrences(
                of: ":",
                with: "-"
            )

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(
            identifier:
                isEnglish
                ? "en_US"
                : "he_IL"
        )
        dateFormatter.dateFormat =
            "yyyy-MM-dd_HH-mm"

        let dateSuffix =
            dateFormatter.string(
                from: Date()
            )

        let filename = [
            isEnglish
                ? "Payments_Report"
                : "דוח_תשלומים",
            cleanBranch.isEmpty
                ? nil
                : cleanBranch,
            dateSuffix
        ]
        .compactMap { $0 }
        .joined(separator: "_")
        + ".pdf"

        let fileURL =
            FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    filename
                )

        if FileManager.default
            .fileExists(
                atPath: fileURL.path
            ) {
            try FileManager.default
                .removeItem(
                    at: fileURL
                )
        }

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

        try renderer.writePDF(
            to: fileURL
        ) { context in
            var currentY: CGFloat = 0
            var pageNumber = 0

            func paragraphStyle(
                alignment:
                    NSTextAlignment
            ) -> NSMutableParagraphStyle {
                let style =
                    NSMutableParagraphStyle()

                style.alignment = alignment
                style.lineBreakMode =
                    .byWordWrapping

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
                let footerText =
                    isEnglish
                    ? "K.M.I • Page \(pageNumber)"
                    : "ק.מ.י • עמוד \(pageNumber)"

                drawText(
                    footerText,
                    rect: CGRect(
                        x: horizontalMargin,
                        y:
                            pageBounds.height -
                            bottomMargin +
                            10,
                        width: contentWidth,
                        height: 20
                    ),
                    font:
                        .systemFont(
                            ofSize: 9,
                            weight: .medium
                        ),
                    color:
                        UIColor.darkGray
                            .withAlphaComponent(
                                0.72
                            ),
                    alignment: .center
                )
            }

            func beginPage(
                continuation: Bool
            ) {
                if pageNumber > 0 {
                    drawFooter()
                }

                context.beginPage()
                pageNumber += 1
                currentY = topMargin

                let headerRect = CGRect(
                    x: horizontalMargin,
                    y: currentY,
                    width: contentWidth,
                    height:
                        continuation
                        ? 46
                        : 62
                )

                UIColor(
                    red: 0.06,
                    green: 0.16,
                    blue: 0.29,
                    alpha: 1
                )
                .setFill()

                UIBezierPath(
                    roundedRect: headerRect,
                    cornerRadius: 14
                )
                .fill()

                drawText(
                    continuation
                        ? (
                            isEnglish
                            ? "Payments Report — continued"
                            : "דו״ח תשלומים — המשך"
                        )
                        : (
                            isEnglish
                            ? "K.M.I Payments Report"
                            : "דו״ח תשלומים ק.מ.י"
                        ),
                    rect: CGRect(
                        x:
                            headerRect.minX +
                            16,
                        y:
                            headerRect.minY +
                            (
                                continuation
                                ? 12
                                : 10
                            ),
                        width:
                            headerRect.width -
                            32,
                        height:
                            continuation
                            ? 24
                            : 28
                    ),
                    font:
                        .systemFont(
                            ofSize:
                                continuation
                                ? 17
                                : 22,
                            weight: .heavy
                        ),
                    color: .white
                )

                if !continuation {
                    let generatedFormatter =
                        DateFormatter()

                    generatedFormatter.locale =
                        Locale(
                            identifier:
                                isEnglish
                                ? "en_US"
                                : "he_IL"
                        )

                    generatedFormatter.dateFormat =
                        isEnglish
                        ? "dd/MM/yyyy HH:mm"
                        : "dd/MM/yyyy HH:mm"

                    let generatedText =
                        generatedFormatter.string(
                            from: Date()
                        )

                    drawText(
                        generatedText,
                        rect: CGRect(
                            x:
                                headerRect.minX +
                                16,
                            y:
                                headerRect.minY +
                                38,
                            width:
                                headerRect.width -
                                32,
                            height: 16
                        ),
                        font:
                            .systemFont(
                                ofSize: 10,
                                weight: .medium
                            ),
                        color:
                            UIColor.white
                                .withAlphaComponent(
                                    0.76
                                )
                    )
                }

                currentY =
                    headerRect.maxY + 18
            }

            func ensureSpace(
                _ requiredHeight:
                    CGFloat
            ) {
                let availableBottom =
                    pageBounds.height -
                    bottomMargin -
                    10

                if currentY +
                    requiredHeight >
                    availableBottom {
                    beginPage(
                        continuation: true
                    )
                }
            }

            beginPage(
                continuation: false
            )

            let branchText =
                selectedBranch
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            if !branchText.isEmpty {
                drawText(
                    isEnglish
                        ? "Branch: \(branchText)"
                        : "סניף: \(branchText)",
                    rect: CGRect(
                        x: horizontalMargin,
                        y: currentY,
                        width: contentWidth,
                        height: 22
                    ),
                    font:
                        .systemFont(
                            ofSize: 13,
                            weight: .bold
                        ),
                    color:
                        UIColor(
                            red: 0.10,
                            green: 0.25,
                            blue: 0.43,
                            alpha: 1
                        )
                )

                currentY += 28
            }

            let summaryHeight: CGFloat = 84
            let summaryRect = CGRect(
                x: horizontalMargin,
                y: currentY,
                width: contentWidth,
                height: summaryHeight
            )

            UIColor(
                red: 0.94,
                green: 0.97,
                blue: 1.00,
                alpha: 1
            )
            .setFill()

            UIBezierPath(
                roundedRect: summaryRect,
                cornerRadius: 14
            )
            .fill()

            let summaryText =
                isEnglish
                ? """
                Collection: \(Int(collectionPercent.rounded()))%   •   Trainees: \(items.count)
                Paid: \(paidCount)   •   Not fully paid: \(unpaidCount)
                Collected: ₪\(Int(totalPaid)) of ₪\(Int(totalRequired))
                """
                : """
                אחוז גבייה: \(Int(collectionPercent.rounded()))%   •   מתאמנים: \(items.count)
                שילמו: \(paidCount)   •   לא שילמו מלא: \(unpaidCount)
                נגבה: \(Int(totalPaid)) ₪ מתוך \(Int(totalRequired)) ₪
                """

            drawText(
                summaryText,
                rect: CGRect(
                    x:
                        summaryRect.minX +
                        14,
                    y:
                        summaryRect.minY +
                        11,
                    width:
                        summaryRect.width -
                        28,
                    height:
                        summaryRect.height -
                        18
                ),
                font:
                    .systemFont(
                        ofSize: 13,
                        weight: .semibold
                    ),
                color:
                    UIColor(
                        red: 0.08,
                        green: 0.16,
                        blue: 0.28,
                        alpha: 1
                    )
            )

            currentY =
                summaryRect.maxY + 18

            drawText(
                isEnglish
                    ? "Payment details"
                    : "פירוט תשלומים",
                rect: CGRect(
                    x: horizontalMargin,
                    y: currentY,
                    width: contentWidth,
                    height: 26
                ),
                font:
                    .systemFont(
                        ofSize: 17,
                        weight: .heavy
                    ),
                color:
                    UIColor(
                        red: 0.08,
                        green: 0.18,
                        blue: 0.32,
                        alpha: 1
                    )
            )

            currentY += 34

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

            for (index, item)
                in items.enumerated() {
                let rowHeight: CGFloat = 96

                ensureSpace(
                    rowHeight + 10
                )

                let rowRect = CGRect(
                    x: horizontalMargin,
                    y: currentY,
                    width: contentWidth,
                    height: rowHeight
                )

                let backgroundColor =
                    index.isMultiple(of: 2)
                    ? UIColor(
                        red: 0.975,
                        green: 0.985,
                        blue: 1.00,
                        alpha: 1
                    )
                    : UIColor(
                        red: 0.94,
                        green: 0.96,
                        blue: 0.985,
                        alpha: 1
                    )

                backgroundColor.setFill()

                UIBezierPath(
                    roundedRect: rowRect,
                    cornerRadius: 11
                )
                .fill()

                let statusText:
                    String

                let statusColor:
                    UIColor

                switch item.status {
                case .paid:
                    statusText =
                        isEnglish
                        ? "Paid"
                        : "שולם"

                    statusColor =
                        UIColor(
                            red: 0.08,
                            green: 0.58,
                            blue: 0.25,
                            alpha: 1
                        )

                case .unpaid:
                    statusText =
                        isEnglish
                        ? "Unpaid"
                        : "לא שולם"

                    statusColor =
                        UIColor(
                            red: 0.78,
                            green: 0.12,
                            blue: 0.16,
                            alpha: 1
                        )

                case .partial:
                    statusText =
                        isEnglish
                        ? "Partial"
                        : "שולם חלקית"

                    statusColor =
                        UIColor(
                            red: 0.86,
                            green: 0.48,
                            blue: 0.05,
                            alpha: 1
                        )
                }

                let paymentMethodText =
                    methodLabel(
                        item.paymentMethod,
                        isEnglish:
                            isEnglish
                    )

                let titleLine =
                    "\(index + 1). \(item.fullName)"

                let detailsLine =
                    [
                        item.branchName,
                        item.phone
                    ]
                    .filter {
                        !$0.trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                        .isEmpty
                    }
                    .joined(
                        separator: " • "
                    )

                let amountLine =
                    isEnglish
                    ? "Membership fee: ₪\(Int(item.paidAmount)) / ₪\(Int(item.requiredAmount))"
                    : "דמי חבר: \(Int(item.paidAmount)) ₪ / \(Int(item.requiredAmount)) ₪"

                drawText(
                    titleLine,
                    rect: CGRect(
                        x:
                            rowRect.minX +
                            14,
                        y:
                            rowRect.minY +
                            9,
                        width:
                            rowRect.width -
                            28,
                        height: 22
                    ),
                    font:
                        .systemFont(
                            ofSize: 14,
                            weight: .bold
                        ),
                    color:
                        UIColor(
                            red: 0.07,
                            green: 0.14,
                            blue: 0.25,
                            alpha: 1
                        )
                )

                drawText(
                    detailsLine,
                    rect: CGRect(
                        x:
                            rowRect.minX +
                            14,
                        y:
                            rowRect.minY +
                            32,
                        width:
                            rowRect.width -
                            28,
                        height: 18
                    ),
                    font:
                        .systemFont(
                            ofSize: 10,
                            weight: .regular
                        ),
                    color:
                        UIColor.darkGray
                )

                drawText(
                    amountLine,
                    rect: CGRect(
                        x:
                            rowRect.minX +
                            14,
                        y:
                            rowRect.minY +
                            51,
                        width:
                            rowRect.width -
                            28,
                        height: 18
                    ),
                    font:
                        .systemFont(
                            ofSize: 11,
                            weight: .semibold
                        ),
                    color:
                        UIColor(
                            red: 0.08,
                            green: 0.18,
                            blue: 0.32,
                            alpha: 1
                        )
                )

                let bottomLine =
                    isEnglish
                    ? "\(statusText) • Payment method: \(paymentMethodText)"
                    : "\(statusText) • אמצעי תשלום: \(paymentMethodText)"

                drawText(
                    bottomLine,
                    rect: CGRect(
                        x:
                            rowRect.minX +
                            14,
                        y:
                            rowRect.minY +
                            71,
                        width:
                            rowRect.width -
                            28,
                        height: 17
                    ),
                    font:
                        .systemFont(
                            ofSize: 10,
                            weight: .bold
                        ),
                    color: statusColor
                )

                currentY =
                    rowRect.maxY + 9
            }

            drawFooter()
        }

        return fileURL
    }

    private static func methodLabel(
        _ method: PaymentMethod,
        isEnglish: Bool
    ) -> String {
        switch method {
        case .cash:
            return isEnglish
                ? "Cash"
                : "מזומן"

        case .creditCard:
            return isEnglish
                ? "Credit card"
                : "כרטיס אשראי"

        case .bankTransfer:
            return isEnglish
                ? "Bank transfer"
                : "העברה בנקאית"

        case .bit:
            return isEnglish
                ? "Bit"
                : "ביט"

        case .website:
            return isEnglish
                ? "Website payment"
                : "תשלום באתר"

        case .manual:
            return isEnglish
                ? "Manual"
                : "ידני"
        }
    }
}
