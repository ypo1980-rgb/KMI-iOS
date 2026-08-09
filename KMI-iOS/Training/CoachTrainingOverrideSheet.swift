import SwiftUI

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
            ZStack {
                LinearGradient(
                    colors: [
                        Color(
                            red: 0.97,
                            green: 0.98,
                            blue: 1
                        ),
                        accent.opacity(0.08),
                        Color.white
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    ScrollView {
                        VStack(spacing: 14) {
                            trainingDetailsCard

                            Text(
                                tr(
                                    "בחר את הפעולה שברצונך לבצע",
                                    "Choose the action you want to perform"
                                )
                            )
                            .font(
                                .system(
                                    size: 18,
                                    weight: .heavy
                                )
                            )
                            .foregroundStyle(
                                Color.black.opacity(0.80)
                            )
                            .frame(
                                maxWidth: .infinity,
                                alignment: frameAlignment
                            )
                            .multilineTextAlignment(
                                textAlignment
                            )

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

                    bottomActions
                }
            }
            .environment(
                \.layoutDirection,
                layoutDirection
            )
            .interactiveDismissDisabled(
                isSaving
            )
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
        HStack(spacing: 10) {
            Button {
                guard !isSaving else {
                    return
                }

                if mode == .menu {
                    onClose()
                } else {
                    returnToMenu()
                }
            } label: {
                Image(
                    systemName:
                        mode == .menu
                        ? "xmark"
                        : (
                            isEnglish
                            ? "chevron.left"
                            : "chevron.right"
                        )
                )
                .font(
                    .system(
                        size: 15,
                        weight: .black
                    )
                )
                .foregroundStyle(
                    Color.white
                )
                .frame(
                    width: 38,
                    height: 38
                )
                .background(
                    Circle()
                        .fill(
                            Color.white.opacity(0.16)
                        )
                )
            }
            .buttonStyle(.plain)

            Text(screenTitle)
                .font(
                    .system(
                        size: 21,
                        weight: .black
                    )
                )
                .foregroundStyle(Color.white)
                .frame(
                    maxWidth: .infinity,
                    alignment: .center
                )

            Color.clear
                .frame(
                    width: 38,
                    height: 38
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [
                    accent,
                    accent.opacity(0.78)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    private var trainingDetailsCard:
        some View {
        VStack(spacing: 9) {
            Image(
                systemName:
                    "figure.martial.arts"
            )
            .font(
                .system(
                    size: 24,
                    weight: .bold
                )
            )
            .foregroundStyle(accent)

            Text(
                request.uiData.place
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty
                ? request.uiData.branch
                : request.uiData.place
            )
            .font(
                .system(
                    size: 20,
                    weight: .black
                )
            )
            .foregroundStyle(
                Color.black.opacity(0.84)
            )
            .multilineTextAlignment(.center)

            Text(
                request.uiData.dateText
            )
            .font(
                .system(
                    size: 15,
                    weight: .bold
                )
            )
            .foregroundStyle(
                Color.black.opacity(0.62)
            )

            Text(
                "\(request.uiData.startTime) – "
                + request.uiData.endTime
            )
            .font(
                .system(
                    size: 17,
                    weight: .black
                )
            )
            .foregroundStyle(accent)

            HStack(spacing: 8) {
                detailPill(
                    request.uiData.branch
                )

                detailPill(
                    request.uiData.group
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(
                accent.opacity(0.22),
                lineWidth: 1
            )
        )
        .shadow(
            color: Color.black.opacity(0.07),
            radius: 8,
            x: 0,
            y: 4
        )
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
                systemImage: "clock.fill",
                tint: Color(
                    red: 0.43,
                    green: 0.29,
                    blue: 0.71
                ),
                background:
                    Color(
                        red: 0.94,
                        green: 0.92,
                        blue: 1
                    )
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
                systemImage:
                    "xmark.circle.fill",
                tint: Color(
                    red: 0.78,
                    green: 0.12,
                    blue: 0.12
                ),
                background:
                    Color(
                        red: 1,
                        green: 0.93,
                        blue: 0.93
                    )
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
                .font(
                    .system(
                        size: 12,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    Color.black.opacity(0.56)
                )

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
        .frame(maxWidth: .infinity)
        .frame(height: 76)
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
        VStack(
            alignment:
                isEnglish
                ? .leading
                : .trailing,
            spacing: 7
        ) {
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
                .multilineTextAlignment(
                    textAlignment
                )
                .frame(
                    minHeight: 105,
                    maxHeight: 150
                )
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(Color.white)
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
            .font(
                .system(
                    size: 11,
                    weight: .medium
                )
            )
            .foregroundStyle(
                Color.black.opacity(0.48)
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(Color.white)
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
        .background(
            Color.white.opacity(0.96)
        )
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
                        .frame(
                            width: 48,
                            height: 48
                        )

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
                        .font(
                            .system(
                                size: 20,
                                weight: .black
                            )
                        )
                        .foregroundStyle(tint)

                    Text(subtitle)
                        .font(
                            .system(
                                size: 13,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(
                            tint.opacity(0.78)
                        )
                        .multilineTextAlignment(
                            .center
                        )
                }
                .frame(maxWidth: .infinity)
            }
            .padding(
                .horizontal,
                16
            )
            .padding(
                .vertical,
                14
            )
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

    private func errorCard(
        _ message: String
    ) -> some View {
        Text(message)
            .font(
                .system(
                    size: 14,
                    weight: .bold
                )
            )
            .foregroundStyle(
                Color(
                    red: 0.65,
                    green: 0.08,
                    blue: 0.08
                )
            )
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .fill(
                    Color(
                        red: 1,
                        green: 0.92,
                        blue: 0.92
                    )
                )
            )
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
