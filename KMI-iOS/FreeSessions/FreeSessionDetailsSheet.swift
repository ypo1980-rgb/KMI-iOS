import SwiftUI
import UserNotifications

struct FreeSessionDetailsSheet: View {

    @ObservedObject var vm: FreeSessionsViewModel
    let session: FreeSession
    let currentUid: String
    let onClose: () -> Void

    @State
    private var actionMessage: String?

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

    private var screenTextAlignment: TextAlignment {
        isEnglish
            ? .leading
            : .trailing
    }

    private var screenFrameAlignment: Alignment {
        isEnglish
            ? .leading
            : .trailing
    }

    private var cardColor: Color {
        isDarkMode
            ? Color(
                red: 15 / 255,
                green: 23 / 255,
                blue: 42 / 255
            )
            : Color.white.opacity(0.96)
    }

    private var elevatedColor: Color {
        isDarkMode
            ? Color(
                red: 30 / 255,
                green: 41 / 255,
                blue: 59 / 255
            )
            : Color(
                red: 247 / 255,
                green: 251 / 255,
                blue: 255 / 255
            )
    }

    private var primaryTextColor: Color {
        isDarkMode
            ? Color.white.opacity(0.94)
            : Color.black.opacity(0.86)
    }

    private var secondaryTextColor: Color {
        isDarkMode
            ? Color.white.opacity(0.66)
            : Color.black.opacity(0.56)
    }

    private var borderColor: Color {
        isDarkMode
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.09)
    }

    private var accentColor: Color {
        Color(
            red: 34 / 255,
            green: 211 / 255,
            blue: 238 / 255
        )
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
                    colors: isDarkMode
                        ? [
                            Color(
                                red: 15 / 255,
                                green: 23 / 255,
                                blue: 42 / 255
                            ),
                            Color(
                                red: 30 / 255,
                                green: 41 / 255,
                                blue: 59 / 255
                            ),
                            Color(
                                red: 3 / 255,
                                green: 105 / 255,
                                blue: 161 / 255
                            )
                        ]
                        : [
                            Color(
                                red: 248 / 255,
                                green: 251 / 255,
                                blue: 255 / 255
                            ),
                            Color(
                                red: 234 / 255,
                                green: 244 / 255,
                                blue: 255 / 255
                            ),
                            Color(
                                red: 14 / 255,
                                green: 165 / 255,
                                blue: 215 / 255
                            )
                        ],
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

            Text(
                isEnglish
                    ? "Created by \(session.createdByName)"
                    : "נוצר ע״י \(session.createdByName)"
            )
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
            if isEnglish {
                Image(systemName: icon)
                    .foregroundStyle(accent)
                    .frame(width: 22)

                Text(text)
                    .kmiFont(
                        size: 14,
                        weight: .semibold
                    )
                    .foregroundStyle(primaryTextColor)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .multilineTextAlignment(.leading)

            } else {
                Spacer(minLength: 0)

                Text(text)
                    .kmiFont(
                        size: 14,
                        weight: .semibold
                    )
                    .foregroundStyle(primaryTextColor)
                    .multilineTextAlignment(.trailing)

                Image(systemName: icon)
                    .foregroundStyle(accent)
                    .frame(width: 22)
            }
        }
        .environment(
            \.layoutDirection,
            .leftToRight
        )
        .frame(
            maxWidth: .infinity,
            alignment: screenFrameAlignment
        )
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
                    ParticipantState.allCases
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
            Task {
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
                    ForEach(vm.participants) { part in
                        participantRow(part)
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
        _ part: FreeSessionPart
    ) -> some View {
        HStack(spacing: 10) {
            if isEnglish {
                Text(part.name)
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

                Text(part.name)
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
            detailsActionButton(
                title: tr(
                    "פתח ניווט",
                    "Open navigation"
                ),
                icon: "location.fill",
                foreground: Color.white,
                background: Color.blue
            ) {
                openNavigation()
            }

            detailsActionButton(
                title: tr(
                    "שתף ב־WhatsApp",
                    "Share on WhatsApp"
                ),
                icon: "paperplane.fill",
                foreground: primaryTextColor,
                background: cardColor
            ) {
                shareSession()
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
                    foreground: Color.red,
                    background: cardColor
                ) {
                    Task {
                        await vm.deleteSession(
                            sessionId: session.id
                        )
                    }
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
                    .font(
                        .system(
                            size: 15,
                            weight: .bold
                        )
                    )

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

    private func shareSession() {
        let cleanLocation =
            session.locationName?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                ) ?? ""

        let message: String

        if isEnglish {
            message =
            """
            Israeli Krav Magen session 💪

            \(session.title)

            🕒 \(formattedSessionTime(session.startsAt))
            \(cleanLocation.isEmpty ? "" : "📍 \(cleanLocation)")

            You're invited to join!
            """

        } else {
            message =
            """
            אימון קרב מגן ישראלי 💪

            \(session.title)

            🕒 \(formattedSessionTime(session.startsAt))
            \(cleanLocation.isEmpty ? "" : "📍 \(cleanLocation)")

            מוזמנים להצטרף!
            """
        }

        var components = URLComponents(
            string: "https://wa.me/"
        )

        components?.queryItems = [
            URLQueryItem(
                name: "text",
                value: message
            )
        ]

        guard let url = components?.url else {
            actionMessage = tr(
                "לא ניתן להכין את הודעת השיתוף.",
                "The share message could not be prepared."
            )
            return
        }

        UIApplication.shared.open(
            url,
            options: [:]
        ) { opened in
            if !opened {
                DispatchQueue.main.async {
                    actionMessage = tr(
                        "לא ניתן לפתוח את WhatsApp.",
                        "WhatsApp could not be opened."
                    )
                }
            }
        }
    }
    
    private func openNavigation() {
        if let latitude = session.lat,
           let longitude = session.lng {

            let wazeURL = URL(
                string:
                    "waze://?ll=\(latitude),\(longitude)&navigate=yes"
            )

            if let wazeURL,
               UIApplication.shared.canOpenURL(
                    wazeURL
               ) {
                UIApplication.shared.open(
                    wazeURL
                )
                return
            }

            var appleComponents = URLComponents(
                string: "https://maps.apple.com/"
            )

            appleComponents?.queryItems = [
                URLQueryItem(
                    name: "ll",
                    value:
                        "\(latitude),\(longitude)"
                ),
                URLQueryItem(
                    name: "dirflg",
                    value: "d"
                )
            ]

            if let appleURL =
                appleComponents?.url {
                UIApplication.shared.open(
                    appleURL
                )
                return
            }
        }

        let cleanLocation =
            session.locationName?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                ) ?? ""

        guard !cleanLocation.isEmpty else {
            actionMessage = tr(
                "לא הוגדר מקום לאימון הזה.",
                "No location was provided for this session."
            )
            return
        }

        var searchComponents = URLComponents(
            string: "https://maps.apple.com/"
        )

        searchComponents?.queryItems = [
            URLQueryItem(
                name: "q",
                value: cleanLocation
            ),
            URLQueryItem(
                name: "dirflg",
                value: "d"
            )
        ]

        guard let searchURL =
            searchComponents?.url else {
            actionMessage = tr(
                "לא ניתן לפתוח ניווט למקום האימון.",
                "Navigation to the session could not be opened."
            )
            return
        }

        UIApplication.shared.open(
            searchURL
        )
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
