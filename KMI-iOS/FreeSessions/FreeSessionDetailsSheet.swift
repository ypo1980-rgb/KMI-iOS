import SwiftUI
import UserNotifications

struct FreeSessionDetailsSheet: View {

    @ObservedObject var vm: FreeSessionsViewModel
    @ObservedObject private var demoPrivacy = DemoPrivacy.shared

    let session: FreeSession
    let currentUid: String
    let onClose: () -> Void

    @State
    private var actionMessage: String?

    @State private var showDeleteConfirmation = false
    @State private var isDeletingSession = false
    @State private var isUpdatingStatus = false

    @State private var locationShareMessage = ""
    @State private var showLocationShare = false

    @Environment(\.colorScheme)
    private var colorScheme

    @AppStorage("kmi_app_language")
    private var kmiAppLanguage: String = ""

    @AppStorage("app_language")
    private var appLanguage: String = ""

    @AppStorage("initial_language_code")
    private var initialLanguageCode: String = ""

    @AppStorage("selected_language_code")
    private var selectedLanguageCode: String = ""

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var effectiveLanguageCode: String {
        let candidates = [
            kmiAppLanguage,
            appLanguage,
            selectedLanguageCode,
            initialLanguageCode
        ]
        .map {
            $0
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()
        }
        .filter { !$0.isEmpty }

        return candidates.first ?? "he"
    }

    private var isEnglish: Bool {
        effectiveLanguageCode.hasPrefix("en")
    }

    private var screenLayoutDirection: LayoutDirection {
        isEnglish
            ? .leftToRight
            : .rightToLeft
    }

    private var screenTextAlignment: TextAlignment { .leading }

    private var screenFrameAlignment: Alignment { .leading }

    private var cardColor: Color {
        KmiAppTheme.surface(for: colorScheme)
    }

    private var elevatedColor: Color {
        KmiAppTheme.surfaceVariant(for: colorScheme)
    }

    private var primaryTextColor: Color {
        KmiAppTheme.onSurface(for: colorScheme)
    }

    private var secondaryTextColor: Color {
        KmiAppTheme.onSurfaceVariant(for: colorScheme)
    }

    private var borderColor: Color {
        KmiAppTheme.outlineVariant(for: colorScheme)
    }

    private var accentColor: Color {
        KmiAppTheme.primary(for: colorScheme)
    }

    private var myState: ParticipantState? {
        vm.myState(in: session.id)
    }

    private func tr(
        _ he: String,
        _ en: String
    ) -> String {
        isEnglish ? en : he
    }

    private func stateTitle(
        _ state: ParticipantState
    ) -> String {
        switch state {
        case .invited:
            return tr("הוזמן", "Invited")

        case .going:
            return tr("מגיע", "Going")

        case .onWay:
            return tr("בדרך", "On the way")

        case .arrived:
            return tr("הגיע", "Arrived")

        case .cant:
            return tr("לא יכול", "Can't attend")
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: KmiAppTheme.screenBackgroundColors(for: colorScheme),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(
                    showsIndicators: false
                ) {
                    LazyVStack(spacing: 14) {
                        sessionInfoCard
                        statusSelector
                        participantsList
                        actionButtons
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle(
                tr(
                    "פרטי אימון",
                    "Session details"
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .topBarLeading
                ) {
                    Button {
                        onClose()
                    } label: {
                        Text(
                            tr(
                                "סגור",
                                "Close"
                            )
                        )
                        .kmiFont(
                            size: 15,
                            weight: .heavy
                        )
                        .foregroundStyle(accentColor)
                    }
                }
            }
        }
        .environment(
            \.layoutDirection,
            screenLayoutDirection
        )
        .sheet(isPresented: $showLocationShare) {
            KmiShareSheet(items: [locationShareMessage])
        }
        .alert(
            tr("מחיקת אימון", "Delete session"),
            isPresented: $showDeleteConfirmation
        ) {
            Button(tr("ביטול", "Cancel"), role: .cancel) {}

            Button(tr("מחק", "Delete"), role: .destructive) {
                guard vm.canManage(session), !isDeletingSession else { return }

                isDeletingSession = true

                Task { @MainActor in
                    defer { isDeletingSession = false }
                    await vm.deleteSession(sessionId: session.id)
                }
            }
        } message: {
            Text(tr(
                "למחוק את האימון ״\(session.title)״?",
                "Delete the session “\(session.title)”?"
            ))
        }
        .alert(
            tr(
                "עדכון",
                "Update"
            ),
            isPresented: Binding(
                get: {
                    actionMessage != nil
                },
                set: {
                    if !$0 {
                        actionMessage = nil
                    }
                }
            )
        ) {
            Button(
                tr(
                    "סגור",
                    "Close"
                ),
                role: .cancel
            ) {
                actionMessage = nil
            }
        } message: {
            Text(actionMessage ?? "")
        }
    }
}

extension FreeSessionDetailsSheet {

    private var sessionInfoCard: some View {
        VStack(
            alignment: isEnglish ? .leading : .trailing,
            spacing: 10
        ) {
            Text(session.title)
                .kmiFont(size: 21, weight: .black)
                .foregroundStyle(primaryTextColor)
                .frame(
                    maxWidth: .infinity,
                    alignment: screenFrameAlignment
                )
                .multilineTextAlignment(
                    screenTextAlignment
                )
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

            let creatorName = demoPrivacy.isEnabled
                ? tr("משתמש", "User")
                : session.createdByName

            Text(tr("נוצר ע״י \(creatorName)", "Created by \(creatorName)"))
            .kmiFont(size: 13, weight: .bold)
            .foregroundStyle(secondaryTextColor)
            .frame(
                maxWidth: .infinity,
                alignment: screenFrameAlignment
            )
            .multilineTextAlignment(
                screenTextAlignment
            )

            infoRow(
                text: formattedSessionTime(
                    session.startsAt
                ),
                icon: "calendar",
                accent: accentColor
            )

            if let location = session.locationName,
               !location
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty {

                infoRow(
                    text: location,
                    icon: "mappin.and.ellipse",
                    accent: Color.orange
                )
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: screenFrameAlignment
        )
        .padding(16)
        .background(cardColor)
        .overlay(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .stroke(
                borderColor,
                lineWidth: 1
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
        .shadow(
            color: Color.black.opacity(
                isDarkMode ? 0.18 : 0.07
            ),
            radius: 7,
            x: 0,
            y: 3
        )
    }

    private func infoRow(
        text: String,
        icon: String,
        accent: Color
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .kmiIconSize(16)
                .foregroundStyle(accent)
                .frame(minWidth: 22)
                .accessibilityHidden(true)

            Text(text)
                .kmiFont(size: 14, weight: .semibold)
                .foregroundStyle(primaryTextColor)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statusSelector: some View {
        VStack(
            alignment: isEnglish ? .leading : .trailing,
            spacing: 12
        ) {
            Text(
                tr(
                    "הסטטוס שלי",
                    "My status"
                )
            )
            .kmiFont(size: 17, weight: .black)
            .foregroundStyle(primaryTextColor)
            .frame(
                maxWidth: .infinity,
                alignment: screenFrameAlignment
            )
            .multilineTextAlignment(
                screenTextAlignment
            )

            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: 105),
                        spacing: 8
                    )
                ],
                spacing: 8
            ) {
                ForEach(
                    [ParticipantState.going, .onWay, .arrived, .cant]
                ) { state in
                    statusButton(state)
                }
            }
        }
        .padding(16)
        .background(cardColor)
        .overlay(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .stroke(
                borderColor,
                lineWidth: 1
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }

    private func statusButton(
        _ state: ParticipantState
    ) -> some View {
        let isSelected = myState == state
        let color = stateColor(state)

        return Button {
            guard !isSelected, !isUpdatingStatus, !isDeletingSession else { return }

            isUpdatingStatus = true

            Task { @MainActor in
                defer { isUpdatingStatus = false }
                await vm.setMyState(
                    sessionId: session.id,
                    state: state
                )
            }
        } label: {
            Text(stateTitle(state))
                .kmiFont(size: 14, weight: .heavy)
                .foregroundStyle(
                    isSelected
                        ? Color.white
                        : primaryTextColor
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.vertical, 11)
                .background(
                    isSelected
                        ? color
                        : elevatedColor
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected
                                ? color
                                : borderColor,
                            lineWidth: 1
                        )
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isUpdatingStatus || isDeletingSession)
        .accessibilityAddTraits(
            isSelected ? .isSelected : []
        )
    }

    private var participantsList: some View {
        VStack(
            alignment: isEnglish ? .leading : .trailing,
            spacing: 10
        ) {
            Text(
                tr(
                    "משתתפים",
                    "Participants"
                )
            )
            .kmiFont(size: 17, weight: .black)
            .foregroundStyle(primaryTextColor)
            .frame(
                maxWidth: .infinity,
                alignment: screenFrameAlignment
            )
            .multilineTextAlignment(
                screenTextAlignment
            )

            if vm.participants.isEmpty {
                Text(
                    tr(
                        "אין עדיין משתתפים",
                        "There are no participants yet"
                    )
                )
                .kmiFont(
                    size: 14,
                    weight: .semibold
                )
                .foregroundStyle(secondaryTextColor)
                .frame(
                    maxWidth: .infinity,
                    alignment: screenFrameAlignment
                )
                .multilineTextAlignment(
                    screenTextAlignment
                )
                .padding(.vertical, 8)

            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(vm.participants.enumerated()), id: \.element.id) { entry in
                        participantRow(entry.element, demoIndex: entry.offset)
                    }
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: screenFrameAlignment
        )
        .padding(16)
        .background(cardColor)
        .overlay(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .stroke(
                borderColor,
                lineWidth: 1
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }

    private func participantRow(
        _ part: FreeSessionPart,
        demoIndex: Int
    ) -> some View {
        HStack(spacing: 10) {
            if isEnglish {
                Text(
                    TraineeDisplayNameMapper.displayName(
                        realName: part.name,
                        stableKey: part.uid,
                        demoIndex: demoIndex,
                        isEnglish: isEnglish
                    )
                )
                    .kmiFont(
                        size: 15,
                        weight: .semibold
                    )
                    .foregroundStyle(primaryTextColor)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .multilineTextAlignment(.leading)

                participantStateBadge(
                    part.state
                )

            } else {
                participantStateBadge(
                    part.state
                )

                Text(
                    TraineeDisplayNameMapper.displayName(
                        realName: part.name,
                        stableKey: part.uid,
                        demoIndex: demoIndex,
                        isEnglish: isEnglish
                    )
                )
                    .kmiFont(
                        size: 15,
                        weight: .semibold
                    )
                    .foregroundStyle(primaryTextColor)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .trailing
                    )
                    .multilineTextAlignment(.trailing)
            }
        }
        .environment(
            \.layoutDirection,
            .leftToRight
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(elevatedColor)
        .overlay(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .stroke(
                borderColor,
                lineWidth: 1
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
        )
    }

    private func participantStateBadge(
        _ state: ParticipantState
    ) -> some View {
        let color = stateColor(state)

        return Text(stateTitle(state))
            .kmiFont(size: 12, weight: .bold)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                color.opacity(
                    isDarkMode ? 0.20 : 0.13
                )
            )
            .overlay(
                Capsule()
                    .stroke(
                        color.opacity(0.36),
                        lineWidth: 1
                    )
            )
            .clipShape(Capsule())
            .fixedSize(
                horizontal: true,
                vertical: false
            )
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if let url = wazeURL {
                detailsActionButton(
                    title: tr("שתף מיקום לקבוצה", "Share location with group"),
                    icon: "square.and.arrow.up",
                    foreground: primaryTextColor,
                    background: cardColor
                ) {
                    shareLocation(url)
                }

                detailsActionButton(
                    title: tr("פתח בוויז", "Open in Waze"),
                    icon: "location.fill",
                    foreground: KmiAppTheme.onPrimary(for: colorScheme),
                    background: accentColor
                ) {
                    openWaze(url)
                }
            }

            detailsActionButton(
                title: tr(
                    "תזכורת לאימון",
                    "Session reminder"
                ),
                icon: "bell.fill",
                foreground: primaryTextColor,
                background: cardColor
            ) {
                scheduleReminder()
            }

            if vm.canManage(session) {
                detailsActionButton(
                    title: tr(
                        "מחק אימון",
                        "Delete session"
                    ),
                    icon: "trash.fill",
                    foreground: KmiAppTheme.error(for: colorScheme),
                    background: cardColor
                ) {
                    guard !isDeletingSession, !isUpdatingStatus else { return }
                    showDeleteConfirmation = true
                }
            }
        }
    }

    private func detailsActionButton(
        title: String,
        icon: String,
        foreground: Color,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .kmiIconSize(15)
                    .accessibilityHidden(true)

                Text(title)
                    .kmiFont(
                        size: 15,
                        weight: .heavy
                    )
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(background)
            .overlay(
                Capsule()
                    .stroke(
                        borderColor,
                        lineWidth: 1
                    )
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

extension FreeSessionDetailsSheet {

    private var cleanLocationName: String {
        session.locationName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var wazeURL: URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "waze.com"
        components.path = "/ul"

        let destination: URLQueryItem

        if let latitude = session.lat,
           let longitude = session.lng,
           (-90.0...90.0).contains(latitude),
           (-180.0...180.0).contains(longitude) {
            destination = URLQueryItem(name: "ll", value: "\(latitude),\(longitude)")
        } else if !cleanLocationName.isEmpty {
            destination = URLQueryItem(name: "q", value: cleanLocationName)
        } else {
            return nil
        }

        components.queryItems = [
            destination,
            URLQueryItem(name: "navigate", value: "true")
        ]
        return components.url
    }

    private func openWaze(_ url: URL) {
        UIApplication.shared.open(url, options: [:]) { opened in
            guard !opened else { return }

            DispatchQueue.main.async {
                actionMessage = tr(
                    "לא ניתן לפתוח את הקישור ל־Waze.",
                    "Could not open the Waze link."
                )
            }
        }
    }

    private func shareLocation(_ url: URL) {
        var lines: [String] = []

        if !cleanLocationName.isEmpty {
            lines.append(tr(
                "מיקום לאימון: \(cleanLocationName)",
                "Training location: \(cleanLocationName)"
            ))
        }

        let title = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            lines.append(tr("אימון: \(title)", "Session: \(title)"))
        }

        lines.append("Waze: \(url.absoluteString)")
        locationShareMessage = lines.joined(separator: "\n")
        showLocationShare = true
    }


    private func scheduleReminder() {
        let sessionDate = Date(
            timeIntervalSince1970:
                TimeInterval(session.startsAt) / 1000.0
        )

        let timeUntilSession =
            sessionDate.timeIntervalSinceNow

        guard timeUntilSession > 0 else {
            actionMessage = tr(
                "האימון כבר התחיל או הסתיים ולכן לא ניתן לקבוע עבורו תזכורת.",
                "The session has already started or ended, so a reminder cannot be scheduled."
            )
            return
        }

        let center =
            UNUserNotificationCenter.current()

        center.requestAuthorization(
            options: [
                .alert,
                .sound,
                .badge
            ]
        ) { granted, error in
            if let error {
                DispatchQueue.main.async {
                    actionMessage = tr(
                        "לא ניתן לבקש הרשאת התראות: \(error.localizedDescription)",
                        "Notification permission could not be requested: \(error.localizedDescription)"
                    )
                }
                return
            }

            guard granted else {
                DispatchQueue.main.async {
                    actionMessage = tr(
                        "כדי לקבל תזכורת יש לאפשר התראות בהגדרות המכשיר.",
                        "Enable notifications in the device settings to receive a reminder."
                    )
                }
                return
            }

            /*
             * ברירת המחדל היא חצי שעה לפני האימון.
             * אם נותרה פחות מחצי שעה, ההתראה תופיע
             * בתוך מספר שניות במקום ליצור זמן שלילי.
             */
            let preferredFireDate =
                sessionDate.addingTimeInterval(
                    -1800
                )

            let triggerInterval = max(
                5,
                preferredFireDate
                    .timeIntervalSinceNow
            )

            let content =
                UNMutableNotificationContent()

            content.title = tr(
                "אימון קרב מגן ישראלי",
                "Israeli Krav Magen session"
            )

            content.body = session.title
            content.sound = .default

            content.userInfo = [
                "free_session_id": session.id,
                "starts_at": session.startsAt
            ]

            let trigger =
                UNTimeIntervalNotificationTrigger(
                    timeInterval: triggerInterval,
                    repeats: false
                )

            let request =
                UNNotificationRequest(
                    identifier:
                        "free-session-reminder-\(session.id)",
                    content: content,
                    trigger: trigger
                )

            center.add(request) { error in
                DispatchQueue.main.async {
                    if let error {
                        actionMessage = tr(
                            "לא ניתן לקבוע את התזכורת: \(error.localizedDescription)",
                            "The reminder could not be scheduled: \(error.localizedDescription)"
                        )
                    } else {
                        actionMessage = tr(
                            triggerInterval <= 5
                                ? "האימון מתחיל בעוד פחות מחצי שעה. התזכורת תופיע בעוד מספר שניות."
                                : "התזכורת נקבעה לחצי שעה לפני האימון.",
                            triggerInterval <= 5
                                ? "The session starts in less than 30 minutes. The reminder will appear in a few seconds."
                                : "The reminder was scheduled for 30 minutes before the session."
                        )
                    }
                }
            }
        }
    }

    private func formattedSessionTime(
        _ millis: Int64
    ) -> String {
        let date = Date(
            timeIntervalSince1970:
                TimeInterval(millis) / 1000.0
        )

        let formatter = DateFormatter()
        formatter.locale = Locale(
            identifier:
                isEnglish
                ? "en_US"
                : "he_IL"
        )
        formatter.calendar = Calendar(
            identifier: .gregorian
        )
        formatter.dateFormat =
            isEnglish
            ? "EEEE · MMM d, yyyy · HH:mm"
            : "EEEE · d.M.yyyy · HH:mm"

        return formatter.string(
            from: date
        )
    }

    private func stateColor(
        _ state: ParticipantState
    ) -> Color {
        switch state {
        case .invited: return .gray
        case .going:   return .green
        case .onWay:   return .blue
        case .arrived: return .mint
        case .cant:    return .red
        }
    }
}
