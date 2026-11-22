import SwiftUI
import UIKit

struct TrainingManagementUiData:
    Hashable {

    let occurrenceKey: String
    let place: String
    let branch: String
    let group: String
    let dateText: String
    let startTime: String
    let endTime: String
}

struct TrainingManagementRequest {

    let uiData: TrainingManagementUiData
    let training: TrainingData
    let branch: String
    let group: String
    let changedByName: String
    let activeOverride: TrainingOverride?

    init(
        uiData: TrainingManagementUiData,
        training: TrainingData,
        branch: String,
        group: String,
        changedByName: String,
        activeOverride: TrainingOverride? = nil
    ) {
        self.uiData = uiData
        self.training = training
        self.branch = branch
        self.group = group
        self.changedByName = changedByName
        self.activeOverride = activeOverride
    }
}

private enum TrainingManagementMode {
    case menu
    case changeTime
    case cancel
}

struct CoachTrainingOverrideSheet: View {
    @EnvironmentObject private var nav: AppNavModel
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var demoPrivacy = DemoPrivacy.shared

    @State private var trainingPDFURL: URL?
    @State private var showTrainingPDFShare = false

    let request: TrainingManagementRequest
    let isEnglish: Bool
    let onClose: () -> Void

    @State private var mode:
        TrainingManagementMode = .menu

    @State private var reason: String = ""

    @State private var changedStartDate: Date
    @State private var changedEndDate: Date

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showRestoreConfirmation = false

    @FocusState private var reasonFocused: Bool

    init(
        request: TrainingManagementRequest,
        isEnglish: Bool,
        onClose: @escaping () -> Void
    ) {
        self.request = request
        self.isEnglish = isEnglish
        self.onClose = onClose

        let startDate =
            Self.date(
                fromTimeText:
                    request.uiData.startTime,
                on: request.training.date
            )
            ?? request.training.date

        var endDate =
            Self.date(
                fromTimeText:
                    request.uiData.endTime,
                on: request.training.date
            )
            ?? Calendar.current.date(
                byAdding: .minute,
                value: 90,
                to: startDate
            )
            ?? startDate

        /*
         * אימון אמיתי שחוצה חצות.
         */
        if endDate <= startDate {
            endDate =
                Calendar.current.date(
                    byAdding: .day,
                    value: 1,
                    to: endDate
                )
                ?? endDate
        }

        _changedStartDate =
            State(initialValue: startDate)

        _changedEndDate =
            State(initialValue: endDate)
    }

    private func tr(
        _ he: String,
        _ en: String
    ) -> String {
        isEnglish ? en : he
    }

    private var layoutDirection:
        LayoutDirection {
        isEnglish
            ? .leftToRight
            : .rightToLeft
    }

    private var textAlignment:
        TextAlignment {
        isEnglish
            ? .leading
            : .trailing
    }

    private var frameAlignment:
        Alignment {
        isEnglish
            ? .leading
            : .trailing
    }

    private var accent: Color {
        switch mode {
        case .menu:
            return Color(
                red: 0.03,
                green: 0.35,
                blue: 0.52
            )

        case .changeTime:
            return Color(
                red: 0.43,
                green: 0.29,
                blue: 0.71
            )

        case .cancel:
            return Color(
                red: 0.72,
                green: 0.11,
                blue: 0.11
            )
        }
    }

    private var screenTitle: String {
        switch mode {
        case .menu:
            return tr(
                "ניהול אימון",
                "Manage training"
            )

        case .changeTime:
            return tr(
                "שינוי שעת האימון",
                "Change training time"
            )

        case .cancel:
            return tr(
                "ביטול אימון",
                "Cancel training"
            )
        }
    }

    private var canSubmit: Bool {
        guard reason
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .count >= 3 else {
            return false
        }

        switch mode {
        case .menu:
            return false

        case .cancel:
            return true

        case .changeTime:
            /*
             * שעת סיום מוקדמת משעת ההתחלה מייצגת
             * אימון שמסתיים ביום הבא.
             *
             * ההתאמה ליום הבא מתבצעת בתוך submit().
             */
            return true
        }
    }

    var body: some View {
        NavigationStack {
            KmiRootLayout(
                title: tr("ניהול אימון", "Manage training"),
                nav: nav,
                selectedIcon: .home,
                showShareAction: mode == .menu && !isSaving,
                onShare: shareTrainingPDF,
                onBackOverride: {
                    guard !isSaving else { return }

                    if mode == .menu {
                        onClose()
                    } else {
                        returnToMenu()
                    }
                }
            ) {
                VStack(spacing: 0) {
                    header

                    ScrollView {
                        VStack(spacing: 14) {
                            trainingDetailsCard
                            modeContent

                            if let errorMessage {
                                errorCard(
                                    errorMessage
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                    }
                    .scrollDismissesKeyboard(
                        .interactively
                    )

                    if mode != .menu {
                        bottomActions
                    }
                }
            }
            .environment(
                \.layoutDirection,
                layoutDirection
            )
            .interactiveDismissDisabled(
                isSaving
            )
            .sheet(isPresented: $showTrainingPDFShare, onDismiss: {
                trainingPDFURL = nil
            }) {
                if let trainingPDFURL {
                    KmiShareSheet(items: [trainingPDFURL])
                }
            }
            .confirmationDialog(
                tr(
                    "להחזיר את האימון להגדרה המקורית?",
                    "Restore the original training?"
                ),
                isPresented: $showRestoreConfirmation,
                titleVisibility: .visible
            ) {
                Button(
                    tr(
                        "שחזור האימון המקורי",
                        "Restore original training"
                    )
                ) {
                    restoreOriginalTraining()
                }

                Button(
                    tr("ביטול", "Cancel"),
                    role: .cancel
                ) {}
            } message: {
                Text(
                    tr(
                        "השינוי הפעיל יבוטל ושעת האימון המקורית תוצג שוב למתאמנים.",
                        "The active override will be removed and the original training time will be shown again."
                    )
                )
            }
        }
    }

    private var header: some View {
        let title = mode == .menu
            ? tr("ביטול / שינוי שעת אימון", "Cancel / change training time")
            : screenTitle

        return Text(title)
            .kmiTypography(.action)
            .fontWeight(.bold)
            .multilineTextAlignment(.center)
            .foregroundStyle(KmiAppTheme.sectionHeaderContentColor)
            .padding(.horizontal, 56)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: KmiAppTheme.sectionTabsHeight)
            .background(KmiAppTheme.sectionHeaderBrush)
            .accessibilityAddTraits(.isHeader)
    }

    private var trainingDetailsCard: some View {
        let data = request.uiData
        let place = data.place.trimmingCharacters(in: .whitespacesAndNewlines)
        let outline = KmiAppTheme.outline(for: colorScheme)
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        return VStack(alignment: .leading, spacing: 4) {
            Text(place.isEmpty ? data.branch : place)
                .kmiTypography(.cardTitle)
                .fontWeight(.heavy)
                .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))

            Text(tr("סניף: \(data.branch)", "Branch: \(data.branch)"))
                .kmiTypography(.body)

            Text(tr("קבוצה: \(data.group)", "Group: \(data.group)"))
                .kmiTypography(.body)

            Divider()
                .overlay(outline.opacity(0.18))
                .padding(.vertical, 2)

            Text(verbatim: "\(data.dateText) · \(data.startTime)–\(data.endTime)")
                .kmiTypography(.body)
                .fontWeight(.bold)
                .environment(\.layoutDirection, .leftToRight)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(KmiAppTheme.surface(for: colorScheme), in: shape)
        .overlay {
            shape.strokeBorder(outline.opacity(0.30), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var modeContent: some View {
        switch mode {
        case .menu:
            actionCard(
                title: tr(
                    "שינוי שעת אימון",
                    "Change training time"
                ),
                subtitle: tr(
                    "בחירת שעת התחלה וסיום חדשות",
                    "Choose new start and end times"
                ),
                systemImage: "clock",
                tint: KmiAppTheme.secondary(for: colorScheme),
                background: KmiAppTheme.surfaceVariant(for: colorScheme)
            ) {
                errorMessage = nil
                reason = ""
                mode = .changeTime
            }

            actionCard(
                title: tr(
                    "ביטול אימון",
                    "Cancel training"
                ),
                subtitle: tr(
                    "ביטול האימון ושליחת עדכון למתאמנים",
                    "Cancel and notify the trainees"
                ),
                systemImage: "xmark.circle.fill",
                tint: KmiAppTheme.error(for: colorScheme),
                background: KmiAppTheme.surfaceVariant(for: colorScheme)
            ) {
                errorMessage = nil
                reason = ""
                mode = .cancel
            }

            if let activeOverride = request.activeOverride,
               activeOverride.isActive {
                actionCard(
                    title: tr(
                        "שחזור האימון המקורי",
                        "Restore original training"
                    ),
                    subtitle:
                        activeOverride.isCancelled
                        ? tr(
                            "ביטול הביטול והחזרת האימון ללוח",
                            "Remove the cancellation and restore the training"
                        )
                        : tr(
                            "ביטול שינוי השעה וחזרה לשעה המקורית",
                            "Remove the time change and restore the original time"
                        ),
                    systemImage: "arrow.counterclockwise.circle.fill",
                    tint: Color(
                        red: 0.04,
                        green: 0.52,
                        blue: 0.32
                    ),
                    background: Color(
                        red: 0.90,
                        green: 0.98,
                        blue: 0.94
                    )
                ) {
                    errorMessage = nil
                    showRestoreConfirmation = true
                }
            }

            case .changeTime:
                timeEditor
            reasonField(
                isCancellation: false
            )

        case .cancel:
            reasonField(
                isCancellation: true
            )
        }
    }

    private var timeEditor: some View {
        HStack(spacing: 10) {
            timePickerCard(
                label: tr(
                    "התחלה",
                    "Start"
                ),
                selection:
                    $changedStartDate
            )

            timePickerCard(
                label: tr(
                    "סיום",
                    "End"
                ),
                selection:
                    $changedEndDate
            )
        }
    }

    private func timePickerCard(
        label: String,
        selection: Binding<Date>
    ) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .kmiTypography(.caption)
                .fontWeight(.bold)
                .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))

            DatePicker(
                "",
                selection: selection,
                displayedComponents:
                    .hourAndMinute
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .environment(
                \.locale,
                Locale(
                    identifier:
                        isEnglish
                        ? "en_US"
                        : "he_IL"
                )
            )
        }
        .frame(maxWidth: .infinity, minHeight: 76)
        .background(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(
                accent.opacity(0.10)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(
                accent.opacity(0.38),
                lineWidth: 1
            )
        )
    }

    private func reasonField(
        isCancellation: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(
                isCancellation
                ? tr(
                    "סיבת הביטול",
                    "Cancellation reason"
                )
                : tr(
                    "סיבת השינוי",
                    "Reason for the change"
                )
            )
            .font(
                .system(
                    size: 14,
                    weight: .heavy
                )
            )
            .foregroundStyle(accent)

            TextEditor(text: $reason)
                .focused($reasonFocused)
                .font(
                    .system(
                        size: 16,
                        weight: .semibold
                    )
                )
                .multilineTextAlignment(.leading)
                .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
                .frame(minHeight: 105, maxHeight: 150)
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(
                    KmiAppTheme.surfaceVariant(for: colorScheme),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .onChange(of: reason) {
                    _, newValue in

                    if newValue.count > 250 {
                        reason =
                            String(
                                newValue.prefix(250)
                            )
                    }

                    errorMessage = nil
                }

            HStack {
                Text(
                    tr(
                        "יש להזין לפחות 3 תווים",
                        "Enter at least 3 characters"
                    )
                )

                Spacer()

                Text("\(reason.count)/250")
            }
            .kmiTypography(.caption)
            .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
        }
        .padding(14)
        .background(
            KmiAppTheme.surface(for: colorScheme),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(
                accent.opacity(0.40),
                lineWidth: 1
            )
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.25
            ) {
                reasonFocused = true
            }
        }
    }

    private var bottomActions: some View {
        Group {
            if mode == .menu {
                Button {
                    onClose()
                } label: {
                    Text(
                        tr(
                            "סגור",
                            "Close"
                        )
                    )
                    .font(
                        .system(
                            size: 16,
                            weight: .black
                        )
                    )
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        Capsule()
                            .fill(accent)
                    )
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 10) {
                    Button {
                        guard !isSaving else {
                            return
                        }

                        returnToMenu()
                    } label: {
                        Text(
                            tr(
                                "חזרה",
                                "Back"
                            )
                        )
                        .font(
                            .system(
                                size: 15,
                                weight: .black
                            )
                        )
                        .foregroundStyle(accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(
                                cornerRadius: 16,
                                style: .continuous
                            )
                            .fill(
                                accent.opacity(0.10)
                            )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                    .frame(
                        maxWidth: .infinity
                    )

                    Button {
                        submit()
                    } label: {
                        HStack(spacing: 7) {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            }

                            Text(
                                mode == .cancel
                                ? tr(
                                    "אישור ביטול",
                                    "Confirm cancellation"
                                )
                                : tr(
                                    "שמירת שעה",
                                    "Save new time"
                                )
                            )
                            .font(
                                .system(
                                    size: 15,
                                    weight: .black
                                )
                            )
                        }
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(
                                cornerRadius: 16,
                                style: .continuous
                            )
                            .fill(
                                canSubmit
                                ? accent
                                : accent.opacity(0.35)
                            )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(
                        !canSubmit
                        || isSaving
                    )
                    .frame(
                        maxWidth: .infinity
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(KmiAppTheme.surface(for: colorScheme))
    }

    private func actionCard(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        background: Color,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 13) {
                ZStack {
                    Circle()
                        .fill(tint)
                        .frame(width: 52, height: 52)

                    Image(
                        systemName: systemImage
                    )
                    .font(
                        .system(
                            size: 21,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(Color.white)
                }

                VStack(spacing: 4) {
                    Text(title)
                        .kmiTypography(.cardTitle)
                        .fontWeight(.heavy)
                        .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))

                    Text(subtitle)
                        .kmiTypography(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
            }
            .padding(
                .horizontal,
                16
            )
            .padding(.vertical, 14)
            .frame(minHeight: 96)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(
                    cornerRadius: 20,
                    style: .continuous
                )
                .fill(background)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 20,
                    style: .continuous
                )
                .stroke(
                    tint.opacity(0.38),
                    lineWidth: 1
                )
            )
            .shadow(
                color: tint.opacity(0.12),
                radius: 5,
                x: 0,
                y: 3
            )
        }
        .buttonStyle(.plain)
    }

    private func detailPill(
        _ value: String
    ) -> some View {
        let cleanValue =
            value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return Text(
            cleanValue.isEmpty
            ? "—"
            : cleanValue
        )
        .font(
            .system(
                size: 11,
                weight: .bold
            )
        )
        .foregroundStyle(
            Color.black.opacity(0.58)
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(
                    Color.black.opacity(0.06)
                )
        )
    }

    private func errorCard(_ message: String) -> some View {
        let errorColor = KmiAppTheme.error(for: colorScheme)
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        return Text(message)
            .kmiTypography(.body)
            .fontWeight(.bold)
            .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(KmiAppTheme.surface(for: colorScheme), in: shape)
            .overlay {
                shape.strokeBorder(errorColor.opacity(0.45), lineWidth: 1)
            }
    }

    private func shareTrainingPDF() {
        guard mode == .menu, !isSaving else { return }

        errorMessage = nil

        do {
            trainingPDFURL = try makeTrainingPDF()
            showTrainingPDFShare = true
        } catch {
            errorMessage = tr(
                "לא ניתן ליצור את קובץ ה־PDF.",
                "Unable to create the PDF file."
            )
        }
    }

    private func makeTrainingPDF() throws -> URL {
        let data = request.uiData
        let titleHe = "פרטי אימון"
        let titleEn = "Training Details"
        let place = data.place.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = place.isEmpty ? data.branch : place
        let privacyLabel = tr("נתוני הדגמה", "Demo data")
        let isDemo = demoPrivacy.isEnabled

        let fields: [(label: String, value: String)] = [
            (tr("מקום", "Location"), location),
            (tr("סניף", "Branch"), data.branch),
            (tr("קבוצה", "Group"), data.group),
            (tr("תאריך", "Date"), data.dateText),
            (
                tr("שעות האימון", "Training time"),
                "\u{2066}\(data.startTime)–\(data.endTime)\u{2069}"
            )
        ]

        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 42
        let textWidth = page.width - 2 * margin
        let contentTop = KmiPdfHeader.CONTENT_TOP + 14
        let contentBottom = page.height - KmiPdfFooter.CONTENT_BOTTOM_PADDING
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = isEnglish ? .left : .right
        paragraph.baseWritingDirection = isEnglish ? .leftToRight : .rightToLeft
        paragraph.lineBreakMode = .byWordWrapping

        let measureOptions: NSStringDrawingOptions = [
            .usesLineFragmentOrigin,
            .usesFontLeading
        ]
        let labelStyle: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: UIColor(KmiAppTheme.onSurfaceVariant(for: .light)),
            .paragraphStyle: paragraph
        ]
        let valueStyle: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .bold),
            .foregroundColor: UIColor(KmiAppTheme.onSurface(for: .light)),
            .paragraphStyle: paragraph
        ]

        func textHeight(_ text: NSAttributedString) -> CGFloat {
            ceil(text.boundingRect(
                with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                options: measureOptions,
                context: nil
            ).height)
        }

        let rows = fields.map { field in
            let cleanValue = field.value.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayValue = isDemo ? privacyLabel : (cleanValue.isEmpty ? "—" : cleanValue)
            let label = NSAttributedString(string: field.label, attributes: labelStyle)
            let value = NSAttributedString(string: displayValue, attributes: valueStyle)
            return (label: label, value: value, labelHeight: textHeight(label),
                    valueHeight: textHeight(value))
        }

        let labelGap: CGFloat = 4
        let rowGap: CGFloat = 16
        guard rows.allSatisfy({
            $0.labelHeight + labelGap + $0.valueHeight <= contentBottom - contentTop
        }) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let pdf = renderer.pdfData { context in
            var pageNumber = 0
            var y = contentTop

            func drawFooter() {
                KmiPdfFooter.draw(
                    context: context.cgContext,
                    pageWidth: page.width,
                    pageHeight: page.height,
                    pageNumber: pageNumber,
                    isEnglish: isEnglish
                )
            }

            func beginPage() {
                context.beginPage()
                pageNumber += 1
                y = contentTop

                let subtitle = isDemo ? privacyLabel : location
                KmiPdfHeader.draw(
                    context: context.cgContext,
                    pageWidth: page.width,
                    isEnglish: isEnglish,
                    titleHebrew: titleHe,
                    titleEnglish: titleEn,
                    subtitleHebrew: subtitle,
                    subtitleEnglish: subtitle
                )
            }

            beginPage()

            for row in rows {
                let rowHeight = row.labelHeight + labelGap + row.valueHeight
                if y + rowHeight > contentBottom {
                    drawFooter()
                    beginPage()
                }

                row.label.draw(
                    with: CGRect(x: margin, y: y, width: textWidth, height: row.labelHeight),
                    options: measureOptions,
                    context: nil
                )
                y += row.labelHeight + labelGap

                row.value.draw(
                    with: CGRect(x: margin, y: y, width: textWidth, height: row.valueHeight),
                    options: measureOptions,
                    context: nil
                )
                y += row.valueHeight + rowGap
            }

            drawFooter()
        }

        let fileName = tr("\(titleHe).pdf", "\(titleEn).pdf")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try pdf.write(to: url, options: .atomic)
        return url
    }

    private func returnToMenu() {
        mode = .menu
        reason = ""
        errorMessage = nil
        reasonFocused = false
    }

    private func restoreOriginalTraining() {
        guard request.activeOverride?.isActive == true,
              !isSaving else {
            return
        }

        reasonFocused = false
        isSaving = true
        errorMessage = nil

        TrainingOverrideRepository
            .restoreOriginalTraining(
                training: request.training,
                branch: request.branch,
                group: request.group,
                changedByName: request.changedByName
            ) { result in
                handleSaveResult(result)
            }
    }

    private func submit() {
        guard canSubmit,
              !isSaving else {
            return
        }

        reasonFocused = false
        isSaving = true
        errorMessage = nil

        let cleanReason =
            reason.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        switch mode {
        case .menu:
            isSaving = false

        case .cancel:
            TrainingOverrideRepository
                .cancelTraining(
                    training:
                        request.training,
                    branch:
                        request.branch,
                    group:
                        request.group,
                    reason:
                        cleanReason,
                    changedByName:
                        request.changedByName
                ) { result in
                    handleSaveResult(result)
                }

        case .changeTime:
            let startMillis =
                Self.millis(
                    from:
                        changedStartDate
                )

            var endDate =
                changedEndDate

            if endDate <= changedStartDate {
                endDate =
                    Calendar.current.date(
                        byAdding: .day,
                        value: 1,
                        to: endDate
                    )
                    ?? endDate
            }

            let endMillis =
                Self.millis(
                    from: endDate
                )

            TrainingOverrideRepository
                .changeTrainingTime(
                    training:
                        request.training,
                    branch:
                        request.branch,
                    group:
                        request.group,
                    newStartMillis:
                        startMillis,
                    newEndMillis:
                        endMillis,
                    reason:
                        cleanReason,
                    changedByName:
                        request.changedByName
                ) { result in
                    handleSaveResult(result)
                }
        }
    }

    private func handleSaveResult(
        _ result: Result<Void, Error>
    ) {
        isSaving = false

        switch result {
        case .success:
            onClose()

        case .failure(let error):
            errorMessage =
                error.localizedDescription
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty
                ? tr(
                    "לא ניתן היה לשמור את השינוי.",
                    "The change could not be saved."
                )
                : error.localizedDescription
        }
    }

    private static func date(
        fromTimeText rawValue: String,
        on baseDate: Date
    ) -> Date? {
        let pattern =
            #"(?:(?:[01]\d|2[0-3])):[0-5]\d"#

        guard let range =
                rawValue.range(
                    of: pattern,
                    options: .regularExpression
                ) else {
            return nil
        }

        let cleanTime =
            String(rawValue[range])

        let parts =
            cleanTime.split(
                separator: ":"
            )

        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return nil
        }

        var components =
            Calendar.current.dateComponents(
                [
                    .year,
                    .month,
                    .day
                ],
                from: baseDate
            )

        components.hour = hour
        components.minute = minute
        components.second = 0

        return Calendar.current.date(
            from: components
        )
    }

    private static func millis(
        from date: Date
    ) -> Int64 {
        Int64(
            date.timeIntervalSince1970
            * 1000
        )
    }
}
