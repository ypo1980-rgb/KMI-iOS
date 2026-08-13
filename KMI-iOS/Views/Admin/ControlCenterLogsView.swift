import SwiftUI
import UIKit
import FirebaseFirestore

private struct AdminDiagnosticLog: Identifiable {
    let id: String
    let type: String
    let title: String
    let message: String
    let area: String
    let severity: String
    let userRole: String
    let appVersion: String
    let deviceModel: String
    let language: String
    let createdAt: Timestamp?
}

private struct AdminTopScreen: Identifiable {
    let id = UUID()
    let screenName: String
    let count: Int
}

private enum AdminDiagnosticsTheme {

    private static func adaptive(
        light: UIColor,
        dark: UIColor
    ) -> Color {
        Color(
            UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            }
        )
    }

    static let primaryText = adaptive(
        light: UIColor(
            red: 0.063,
            green: 0.125,
            blue: 0.200,
            alpha: 1
        ),
        dark: UIColor(
            red: 0.949,
            green: 0.965,
            blue: 0.988,
            alpha: 1
        )
    )

    static let secondaryText = adaptive(
        light: UIColor(
            red: 0.278,
            green: 0.333,
            blue: 0.412,
            alpha: 1
        ),
        dark: UIColor(
            red: 0.741,
            green: 0.788,
            blue: 0.855,
            alpha: 1
        )
    )

    static let bodyText = adaptive(
        light: UIColor(
            red: 0.118,
            green: 0.161,
            blue: 0.231,
            alpha: 1
        ),
        dark: UIColor(
            red: 0.875,
            green: 0.906,
            blue: 0.953,
            alpha: 1
        )
    )

    static let cardStrong = adaptive(
        light: UIColor(
            white: 1,
            alpha: 0.94
        ),
        dark: UIColor(
            red: 0.055,
            green: 0.075,
            blue: 0.120,
            alpha: 0.96
        )
    )

    static let cardMedium = adaptive(
        light: UIColor(
            white: 1,
            alpha: 0.90
        ),
        dark: UIColor(
            red: 0.071,
            green: 0.094,
            blue: 0.145,
            alpha: 0.94
        )
    )

    static let cardSoft = adaptive(
        light: UIColor(
            white: 1,
            alpha: 0.76
        ),
        dark: UIColor(
            red: 0.082,
            green: 0.110,
            blue: 0.170,
            alpha: 0.90
        )
    )

    static let selectedFilter = adaptive(
        light: UIColor(
            red: 0.929,
            green: 0.894,
            blue: 1.000,
            alpha: 1
        ),
        dark: UIColor(
            red: 0.184,
            green: 0.133,
            blue: 0.314,
            alpha: 1
        )
    )

    static let divider = adaptive(
        light: UIColor(
            red: 0.796,
            green: 0.835,
            blue: 0.882,
            alpha: 0.70
        ),
        dark: UIColor(
            red: 0.302,
            green: 0.357,
            blue: 0.443,
            alpha: 0.72
        )
    )

    static let backgroundTop = adaptive(
        light: UIColor(
            red: 0.937,
            green: 0.984,
            blue: 1.000,
            alpha: 1
        ),
        dark: UIColor(
            red: 0.020,
            green: 0.035,
            blue: 0.075,
            alpha: 1
        )
    )

    static let backgroundUpperMiddle = adaptive(
        light: UIColor(
            red: 0.741,
            green: 0.933,
            blue: 1.000,
            alpha: 1
        ),
        dark: UIColor(
            red: 0.035,
            green: 0.075,
            blue: 0.145,
            alpha: 1
        )
    )

    static let backgroundLowerMiddle = adaptive(
        light: UIColor(
            red: 0.129,
            green: 0.647,
            blue: 0.863,
            alpha: 1
        ),
        dark: UIColor(
            red: 0.035,
            green: 0.235,
            blue: 0.390,
            alpha: 1
        )
    )

    static let backgroundBottom = adaptive(
        light: UIColor(
            red: 0.000,
            green: 0.435,
            blue: 0.682,
            alpha: 1
        ),
        dark: UIColor(
            red: 0.016,
            green: 0.125,
            blue: 0.255,
            alpha: 1
        )
    )
}

private enum AdminDiagnosticsRange: CaseIterable, Hashable {
    case today
    case week
    case month

    var days: Int {
        switch self {
        case .today:
            return 1
        case .week:
            return 7
        case .month:
            return 30
        }
    }

    func title(isEnglish: Bool) -> String {
        switch self {
        case .today:
            return isEnglish ? "Today" : "היום"
        case .week:
            return isEnglish ? "7 days" : "7 ימים"
        case .month:
            return isEnglish ? "30 days" : "30 ימים"
        }
    }
}

private enum AdminDiagnosticsType: CaseIterable, Hashable {
    case all
    case errors
    case voice
    case login
    case search
    case payments
    case attendance
    case push

    var key: String {
        switch self {
        case .all:
            return "all"

        case .errors:
            return "error"

        case .voice:
            return "voice"

        case .login:
            return "login"

        case .search:
            return "search"

        case .payments:
            return "payment"

        case .attendance:
            return "attendance"

        case .push:
            return "push"
        }
    }

    func title(isEnglish: Bool) -> String {
        switch self {
        case .all:
            return isEnglish ? "All" : "הכל"

        case .errors:
            return isEnglish ? "Errors" : "שגיאות"

        case .voice:
            return isEnglish
                ? "Voice commands"
                : "פקודות קוליות"

        case .login:
            return isEnglish ? "Login" : "כניסות"

        case .search:
            return isEnglish ? "Search" : "חיפוש"

        case .payments:
            return isEnglish ? "Payments" : "תשלומים"

        case .attendance:
            return isEnglish ? "Attendance" : "נוכחות"

        case .push:
            return "Push"
        }
    }
}

struct ControlCenterLogsView: View {

    let isEnglish: Bool

    @State private var adminLogs: [AdminDiagnosticLog] = []
    @State private var googleAuthLogs: [AdminDiagnosticLog] = []
    @State private var topScreens: [AdminTopScreen] = []

    @State private var loadingAdminLogs: Bool = true
    @State private var loadingGoogleLogs: Bool = true
    @State private var loadingScreens: Bool = true

    @State private var errorMessage: String? = nil
    @State private var selectedRange: AdminDiagnosticsRange = .week
    @State private var selectedType: AdminDiagnosticsType = .all
    @State private var expandedLogGroupKey: String? = nil
    @State private var resetVersion: Int = 0

    @State private var adminListener: ListenerRegistration? = nil
    @State private var googleListener: ListenerRegistration? = nil
    @State private var screensListener: ListenerRegistration? = nil

    @State private var showPDFShareSheet: Bool = false
    @State private var pdfShareItems: [Any] = []
    @State private var pdfErrorMessage: String? = nil
    @State private var isCreatingPDF: Bool = false

    private let resetDefaultsKey = "kmi_admin_diagnostics_reset"
    private let topScreensBaselineKey = "top_screens_baseline"

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private var resetDefaults: UserDefaults {
        UserDefaults.standard
    }

    private func resetKey(for groupKey: String) -> String {
        "\(resetDefaultsKey)_reset_after_\(groupKey)"
    }

    private func resetGroup(_ groupKey: String) {
        resetDefaults.set(
            Date().timeIntervalSince1970,
            forKey: resetKey(for: groupKey)
        )

        if expandedLogGroupKey == groupKey {
            expandedLogGroupKey = nil
        }

        resetVersion += 1
    }

    private func resetDate(for groupKey: String) -> TimeInterval {
        resetDefaults.double(forKey: resetKey(for: groupKey))
    }

    private func loadTopScreensBaseline() -> [String: Int] {
        guard
            let data = resetDefaults.data(forKey: topScreensBaselineKey),
            let decoded = try? JSONDecoder().decode(
                [String: Int].self,
                from: data
            )
        else {
            return [:]
        }

        return decoded
    }

    private func resetTopScreensBaseline() {
        let baseline = Dictionary(
            topScreens.map { screen in
                (
                    normalizedScreenName(screen.screenName),
                    screen.count
                )
            },
            uniquingKeysWith: { current, incoming in
                current + incoming
            }
        )

        if let data = try? JSONEncoder().encode(baseline) {
            resetDefaults.set(
                data,
                forKey: topScreensBaselineKey
            )
        }

        resetVersion += 1
    }

    private var allLogs: [AdminDiagnosticLog] {
        adminLogs + googleAuthLogs
    }

    private var isLoading: Bool {
        loadingAdminLogs || loadingGoogleLogs || loadingScreens
    }

    private var rangeStartMillis: TimeInterval {
        Date().timeIntervalSince1970 -
            Double(selectedRange.days * 24 * 60 * 60)
    }

    private var filteredLogs: [AdminDiagnosticLog] {
        allLogs.filter { log in
            let createdMillis =
                log.createdAt?.dateValue().timeIntervalSince1970 ?? 0

            let inRange = createdMillis >= rangeStartMillis

            guard selectedType != .all else {
                return inRange
            }

            let diagnosticText = [
                log.type,
                log.area,
                log.severity,
                log.title,
                log.message
            ]
            .joined(separator: "\n")

            let inType: Bool

            switch selectedType {
            case .all:
                inType = true

            case .errors:
                inType =
                    diagnosticText.localizedCaseInsensitiveContains("error") ||
                    diagnosticText.localizedCaseInsensitiveContains("failed") ||
                    diagnosticText.localizedCaseInsensitiveContains("failure") ||
                    diagnosticText.localizedCaseInsensitiveContains("exception") ||
                    diagnosticText.localizedCaseInsensitiveContains("שגיאה") ||
                    diagnosticText.localizedCaseInsensitiveContains("תקלה") ||
                    diagnosticText.localizedCaseInsensitiveContains("כשל") ||
                    diagnosticText.localizedCaseInsensitiveContains("לא ניתן")

            case .voice:
                inType =
                    diagnosticText.localizedCaseInsensitiveContains(
                        "voice_command"
                    ) ||
                    diagnosticText.localizedCaseInsensitiveContains(
                        "voice_assistant"
                    ) ||
                    diagnosticText.localizedCaseInsensitiveContains(
                        "speech_recognition"
                    ) ||
                    diagnosticText.localizedCaseInsensitiveContains(
                        "voice"
                    )

            case .login:
                inType =
                    diagnosticText.localizedCaseInsensitiveContains("login") ||
                    diagnosticText.localizedCaseInsensitiveContains(
                        "google_auth"
                    ) ||
                    diagnosticText.localizedCaseInsensitiveContains(
                        "firebase_result_user_ready"
                    )

            case .search:
                inType =
                    diagnosticText.localizedCaseInsensitiveContains("search")

            case .payments:
                inType =
                    diagnosticText.localizedCaseInsensitiveContains("payment")

            case .attendance:
                inType =
                    diagnosticText.localizedCaseInsensitiveContains(
                        "attendance"
                    )

            case .push:
                inType =
                    diagnosticText.localizedCaseInsensitiveContains("push")
            }

            return inRange && inType
        }
    }

    private var visibleLogs: [AdminDiagnosticLog] {
        _ = resetVersion

        return filteredLogs.filter { log in
            let groupKey = logGroupKey(log)
            let resetAfter = resetDate(for: groupKey)
            let createdMillis =
                log.createdAt?.dateValue().timeIntervalSince1970 ?? 0

            return createdMillis >= resetAfter
        }
    }

    private var visibleTopScreens: [AdminTopScreen] {
        _ = resetVersion

        let baseline = loadTopScreensBaseline()

        let mergedScreens = Dictionary(
            topScreens.map { screen in
                (
                    normalizedScreenName(screen.screenName),
                    screen.count
                )
            },
            uniquingKeysWith: { current, incoming in
                current + incoming
            }
        )

        return mergedScreens
            .compactMap { screenName, count in
                let previousCount =
                    baseline[screenName] ?? 0

                let visibleCount =
                    max(count - previousCount, 0)

                guard
                    !screenName.isEmpty,
                    visibleCount > 0
                else {
                    return nil
                }

                return AdminTopScreen(
                    screenName: screenName,
                    count: visibleCount
                )
            }
            .sorted { left, right in
                if left.count == right.count {
                    return left.screenName.localizedCaseInsensitiveCompare(
                        right.screenName
                    ) == .orderedAscending
                }

                return left.count > right.count
            }
            .prefix(10)
            .map { $0 }
    }

    private func normalizedScreenName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )
    }

    private var errorCount: Int {
        visibleLogs.filter { log in
            let diagnosticText = [
                log.severity,
                log.type,
                log.title,
                log.area,
                log.message
            ]
            .joined(separator: "\n")

            return
                diagnosticText.localizedCaseInsensitiveContains("error") ||
                diagnosticText.localizedCaseInsensitiveContains("failed") ||
                diagnosticText.localizedCaseInsensitiveContains("failure") ||
                diagnosticText.localizedCaseInsensitiveContains("exception") ||
                diagnosticText.localizedCaseInsensitiveContains("errorClass=") ||
                diagnosticText.localizedCaseInsensitiveContains("errorMessage=") ||
                diagnosticText.localizedCaseInsensitiveContains("apiStatusCode=") ||
                diagnosticText.localizedCaseInsensitiveContains("שגיאה") ||
                diagnosticText.localizedCaseInsensitiveContains("תקלה") ||
                diagnosticText.localizedCaseInsensitiveContains("כשל") ||
                diagnosticText.localizedCaseInsensitiveContains("לא מוגדרת") ||
                diagnosticText.localizedCaseInsensitiveContains("אינה מוגדרת") ||
                diagnosticText.localizedCaseInsensitiveContains("לא ניתן")
        }
        .count
    }

    private var loginCount: Int {
        visibleLogs.filter { log in
            let diagnosticText = [
                log.type,
                log.area,
                log.message
            ]
            .joined(separator: "\n")

            return
                diagnosticText.localizedCaseInsensitiveContains(
                    "intro_call_on_profile_complete"
                ) ||
                diagnosticText.localizedCaseInsensitiveContains(
                    "intro_call_on_profile_missing_basic_details"
                ) ||
                diagnosticText.localizedCaseInsensitiveContains(
                    "firebase_result_user_ready"
                ) ||
                diagnosticText.localizedCaseInsensitiveContains(
                    "classic_firebase_success"
                ) ||
                diagnosticText.localizedCaseInsensitiveContains(
                    "credential_manager_firebase_success"
                )
        }
        .count
    }

    private var searchNoResultsCount: Int {
        visibleLogs.filter { log in
            log.type.localizedCaseInsensitiveContains("search_no_results") ||
            (
                log.type.localizedCaseInsensitiveContains("search") &&
                log.type.localizedCaseInsensitiveContains("no")
            )
        }
        .count
    }

    private var successCount: Int {
        visibleLogs.filter { log in
            log.severity.localizedCaseInsensitiveContains("success") ||
            log.type.localizedCaseInsensitiveContains("success") ||
            log.type.localizedCaseInsensitiveContains("saved") ||
            log.message.localizedCaseInsensitiveContains("firebase_success") ||
            log.message.localizedCaseInsensitiveContains("result_user_ready")
        }
        .count
    }

    private var groupedLogs: [(key: String, items: [AdminDiagnosticLog])] {
        let order = [
            "voice_commands",
            "errors",
            "google_auth",
            "login",
            "search",
            "screen_views",
            "other"
        ]

        let grouped = Dictionary(grouping: visibleLogs) { log in
            logGroupKey(log)
        }

        return grouped
            .map { key, items in
                (
                    key: key,
                    items: items.sorted {
                        let leftDate =
                            $0.createdAt?.dateValue() ?? .distantPast

                        let rightDate =
                            $1.createdAt?.dateValue() ?? .distantPast

                        return leftDate > rightDate
                    }
                )
            }
            .sorted { left, right in
                let leftIndex =
                    order.firstIndex(of: left.key) ?? Int.max

                let rightIndex =
                    order.firstIndex(of: right.key) ?? Int.max

                return leftIndex < rightIndex
            }
    }

    var body: some View {
        ZStack {
            screenBackground

            ScrollView {
                VStack(spacing: 10) {

                    introCard

                    HStack(spacing: 8) {
                        AdminSummaryCard(
                            title: tr("אירועים", "Events"),
                            value: "\(visibleLogs.count)",
                            color: Color(red: 0.008, green: 0.518, blue: 0.780)
                        )

                        AdminSummaryCard(
                            title: tr("שגיאות", "Errors"),
                            value: "\(errorCount)",
                            color: Color(red: 0.882, green: 0.114, blue: 0.282)
                        )
                    }

                    HStack(spacing: 8) {
                        AdminSummaryCard(
                            title: tr("כניסות", "Logins"),
                            value: "\(loginCount)",
                            color: Color(red: 0.086, green: 0.639, blue: 0.290)
                        )

                        AdminSummaryCard(
                            title: tr("חיפוש ללא תוצאה", "No results"),
                            value: "\(searchNoResultsCount)",
                            color: Color(red: 0.851, green: 0.467, blue: 0.024)
                        )
                    }

                    AdminInsightsCard(
                        isEnglish: isEnglish,
                        errorCount: errorCount,
                        loginCount: loginCount,
                        searchNoResultsCount: searchNoResultsCount,
                        successCount: successCount
                    )

                    TopScreensCard(
                        isEnglish: isEnglish,
                        screens: visibleTopScreens,
                        onReset: {
                            resetTopScreensBaseline()
                        }
                    )

                    FilterRows(
                        isEnglish: isEnglish,
                        selectedRange: selectedRange,
                        onRangeSelected: { selectedRange = $0 },
                        selectedType: selectedType,
                        onTypeSelected: { selectedType = $0 }
                    )

                    contentState

                    Spacer()
                        .frame(height: 24)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 96)
            }
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
        .onAppear {
            startListeners()
        }
        .onDisappear {
            removeListeners()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name(
                    "KMI_GLOBAL_SHARE_REQUEST"
                )
            )
        ) { notification in
            guard
                let request =
                    notification.object as? NSMutableDictionary
            else {
                return
            }

            request["handled"] = true
            createAndShareDiagnosticsPDF()
        }
        .sheet(isPresented: $showPDFShareSheet) {
            KmiShareSheet(items: pdfShareItems)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert(
            tr(
                "לא ניתן ליצור דו״ח",
                "Unable to Create Report"
            ),
            isPresented: Binding(
                get: {
                    pdfErrorMessage != nil
                },
                set: { isPresented in
                    if !isPresented {
                        pdfErrorMessage = nil
                    }
                }
            )
        ) {
            Button(
                tr("אישור", "OK"),
                role: .cancel
            ) {
                pdfErrorMessage = nil
            }
        } message: {
            Text(pdfErrorMessage ?? "")
        }
    }

    private var screenBackground: some View {
        LinearGradient(
            stops: [
                .init(
                    color: AdminDiagnosticsTheme.backgroundTop,
                    location: 0.00
                ),
                .init(
                    color: AdminDiagnosticsTheme.backgroundUpperMiddle,
                    location: 0.34
                ),
                .init(
                    color: AdminDiagnosticsTheme.backgroundLowerMiddle,
                    location: 0.68
                ),
                .init(
                    color: AdminDiagnosticsTheme.backgroundBottom,
                    location: 1.00
                )
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var introCard: some View {
        SurfaceLikeCard(
            cornerRadius: 14,
            background: AdminDiagnosticsTheme.cardSoft,
            border: Color(
                red: 0.216,
                green: 0.718,
                blue: 0.910
            )
            .opacity(0.45)
        ) {
            Text(
                tr(
                    "ניתוח פעילות, תקלות ושימוש באפליקציה",
                    "Activity, errors and app diagnostics"
                )
            )
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(AdminDiagnosticsTheme.primaryText)
            .lineSpacing(2)
            .multilineTextAlignment(
                isEnglish ? .leading : .trailing
            )
            .frame(
                maxWidth: .infinity,
                alignment: isEnglish ? .leading : .trailing
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
    }

    @ViewBuilder
    private var contentState: some View {
        if isLoading {
            AdminDiagnosticsLoadingView(
                title: tr(
                    "טוען לוגים...",
                    "Loading logs..."
                )
            )
            .frame(maxWidth: .infinity)
            .padding(.top, 28)
        } else if let errorMessage {
            AdminStateCard(
                icon: "chart.bar.xaxis",
                title: tr("לא ניתן לטעון לוגים", "Unable to load logs"),
                message: errorMessage,
                isEnglish: isEnglish
            )
        } else if visibleLogs.isEmpty {
            AdminStateCard(
                icon: "chart.bar.xaxis",
                title: tr("אין אירועים להצגה", "No events to show"),
                message: tr(
                    "לא נמצאו לוגים בטווח והסינון שנבחרו.",
                    "No logs were found for the selected range and filter."
                ),
                isEnglish: isEnglish
            )
        } else {
            VStack(spacing: 10) {
                ForEach(groupedLogs, id: \.key) { group in
                    AdminLogGroupHeader(
                        title: logGroupTitle(group.key),
                        count: group.items.count,
                        color: logGroupColor(group.key),
                        expanded: expandedLogGroupKey == group.key,
                        isEnglish: isEnglish,
                        onReset: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                resetGroup(group.key)
                            }
                        },
                        onClick: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                expandedLogGroupKey =
                                    expandedLogGroupKey == group.key
                                    ? nil
                                    : group.key
                            }
                        }
                    )

                    if expandedLogGroupKey == group.key {
                        ForEach(group.items) { log in
                            AdminLogCard(
                                log: log,
                                isEnglish: isEnglish
                            )
                        }
                    }
                }
            }
        }
    }

    private func logGroupKey(_ log: AdminDiagnosticLog) -> String {
        let diagnosticText = [
            log.type,
            log.area,
            log.title,
            log.message
        ]
        .joined(separator: "\n")

        if diagnosticText.localizedCaseInsensitiveContains("voice_command") ||
            diagnosticText.localizedCaseInsensitiveContains("voice_assistant") ||
            diagnosticText.localizedCaseInsensitiveContains("speech_recognition") {
            return "voice_commands"
        }

        if log.severity.localizedCaseInsensitiveContains("error") ||
            log.type.localizedCaseInsensitiveContains("error") ||
            log.type.localizedCaseInsensitiveContains("failed") ||
            log.type.localizedCaseInsensitiveContains("failure") {
            return "errors"
        }

        if log.type.localizedCaseInsensitiveContains("screen_view") ||
            log.area.caseInsensitiveCompare("screen") == .orderedSame {
            return "screen_views"
        }

        if log.type.localizedCaseInsensitiveContains("google_auth") ||
            log.area.caseInsensitiveCompare("google_auth") == .orderedSame {
            return "google_auth"
        }

        if log.type.localizedCaseInsensitiveContains("login") {
            return "login"
        }

        if log.type.localizedCaseInsensitiveContains("search") {
            return "search"
        }

        return "other"
    }

    private func logGroupTitle(_ key: String) -> String {
        switch key {
        case "screen_views":
            return tr("צפיות במסכים", "Screen views")

        case "voice_commands":
            return tr(
                "פקודות קוליות שלא בוצעו",
                "Unresolved voice commands"
            )

        case "google_auth":
            return tr("אירועי אבחון Google", "Google diagnostics")

        case "login":
            return tr("אירועי כניסה", "Login events")

        case "errors":
            return tr("שגיאות ותקלות", "Errors and issues")

        case "search":
            return tr("אירועי חיפוש", "Search events")

        default:
            return tr("אירועים נוספים", "Other events")
        }
    }

    private func logGroupColor(_ key: String) -> Color {
        switch key {
        case "screen_views":
            return Color(red: 0.008, green: 0.518, blue: 0.780)

        case "voice_commands":
            return Color(red: 0.918, green: 0.345, blue: 0.047)

        case "google_auth":
            return Color(red: 0.486, green: 0.227, blue: 0.929)

        case "login":
            return Color(red: 0.086, green: 0.639, blue: 0.290)

        case "errors":
            return Color(red: 0.882, green: 0.114, blue: 0.282)

        case "search":
            return Color(red: 0.851, green: 0.467, blue: 0.024)

        default:
            return Color(red: 0.278, green: 0.333, blue: 0.412)
        }
    }

    private func startListeners() {
        removeListeners()

        loadingAdminLogs = true
        loadingGoogleLogs = true
        loadingScreens = true
        errorMessage = nil

        let db = Firestore.firestore()

        adminListener = db
            .collection("adminLogs")
            .order(by: "createdAt", descending: true)
            .limit(to: 300)
            .addSnapshotListener { snapshot, error in
                loadingAdminLogs = false

                if let error {
                    errorMessage = error.localizedDescription
                    adminLogs = []
                    return
                }

                adminLogs = snapshot?.documents.map { doc in
                    AdminDiagnosticLog(
                        id: doc.documentID,
                        type: doc.get("type") as? String ?? "",
                        title: doc.get("title") as? String ?? "",
                        message: doc.get("message") as? String ?? "",
                        area: doc.get("area") as? String ?? "",
                        severity: doc.get("severity") as? String ?? "info",
                        userRole: doc.get("userRole") as? String ?? "unknown",
                        appVersion: doc.get("appVersion") as? String ?? "",
                        deviceModel: doc.get("deviceModel") as? String ?? "",
                        language: doc.get("language") as? String ?? "",
                        createdAt: doc.get("createdAt") as? Timestamp
                    )
                } ?? []
            }

        googleListener = db
            .collection("google_auth_diagnostics")
            .order(by: "createdAt", descending: true)
            .limit(to: 300)
            .addSnapshotListener { snapshot, error in
                loadingGoogleLogs = false

                if let error {
                    errorMessage = error.localizedDescription
                    googleAuthLogs = []
                    return
                }

                googleAuthLogs = snapshot?.documents.map { doc in
                    googleAuthLog(from: doc)
                } ?? []
            }

        screensListener = db
            .collection("screen_views")
            .order(by: "updatedAt", descending: true)
            .limit(to: 200)
            .addSnapshotListener { snapshot, error in
                loadingScreens = false

                if let error {
                    errorMessage = "screen_views: \(error.localizedDescription)"
                    topScreens = []
                    return
                }

                topScreens = snapshot?.documents.compactMap { doc in
                    let name =
                        doc.get("screenName") as? String ??
                        doc.get("screen") as? String ??
                        doc.get("route") as? String ??
                        doc.documentID

                    let count =
                        (doc.get("count") as? NSNumber)?.intValue ??
                        (doc.get("views") as? NSNumber)?.intValue ??
                        0

                    let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)

                    guard !cleanName.isEmpty, count > 0 else {
                        return nil
                    }

                    return AdminTopScreen(
                        screenName: cleanName,
                        count: count
                    )
                }
                .sorted { $0.count > $1.count }
                .prefix(10)
                .map { $0 } ?? []
            }
    }

    private func removeListeners() {
        adminListener?.remove()
        googleListener?.remove()
        screensListener?.remove()

        adminListener = nil
        googleListener = nil
        screensListener = nil
    }

    private func googleAuthLog(from doc: QueryDocumentSnapshot) -> AdminDiagnosticLog {
        let stage = doc.get("stage") as? String ?? ""
        let errorClass = doc.get("errorClass") as? String ?? ""
        let rawErrorMessage = doc.get("errorMessage") as? String ?? ""
        let message = doc.get("message") as? String ?? ""

        let apiStatusCode =
            (doc.get("apiStatusCode") as? NSNumber)?.intValue

        let isRealUserCancel =
            rawErrorMessage.localizedCaseInsensitiveContains("User cancelled") ||
            rawErrorMessage.localizedCaseInsensitiveContains("Cancelled by user") ||
            rawErrorMessage.localizedCaseInsensitiveContains("cancelled the selector")

        let isReauth16 =
            rawErrorMessage.localizedCaseInsensitiveContains("Account reauth failed") ||
            rawErrorMessage.localizedCaseInsensitiveContains("reauth failed") ||
            rawErrorMessage.localizedCaseInsensitiveContains("[16]")

        let isError =
            isReauth16 ||
            apiStatusCode != nil ||
            (!errorClass.isEmpty && !isRealUserCancel) ||
            (!rawErrorMessage.isEmpty && !isRealUserCancel) ||
            stage.localizedCaseInsensitiveContains("failure") ||
            stage.localizedCaseInsensitiveContains("failed") ||
            stage.localizedCaseInsensitiveContains("exception") ||
            stage.localizedCaseInsensitiveContains("no_credential") ||
            stage.localizedCaseInsensitiveContains("invalid") ||
            stage.localizedCaseInsensitiveContains("blank")

        let isSuccess =
            stage.localizedCaseInsensitiveContains("success") ||
            stage.localizedCaseInsensitiveContains("firebase_success") ||
            stage.localizedCaseInsensitiveContains("result_user_ready")

        let type: String = {
            if isError {
                return "google_auth_error"
            }

            if isSuccess {
                return "google_auth_success"
            }

            if isRealUserCancel {
                return "google_auth_cancelled"
            }

            return "google_auth_login"
        }()

        let title: String = {
            if isError {
                return tr("תקלה בכניסה עם Google", "Google sign-in issue")
            }

            if isSuccess {
                return tr("כניסה עם Google הצליחה", "Google sign-in success")
            }

            if isRealUserCancel {
                return tr("כניסה עם Google בוטלה", "Google sign-in cancelled")
            }

            return tr("אירוע כניסה עם Google", "Google sign-in event")
        }()

        let fullMessage = [
            stage.isEmpty ? nil : "stage=\(stage)",
            errorClass.isEmpty ? nil : "errorClass=\(errorClass)",
            rawErrorMessage.isEmpty ? nil : "errorMessage=\(rawErrorMessage)",
            apiStatusCode == nil ? nil : "apiStatusCode=\(apiStatusCode!)",
            message.isEmpty ? nil : message
        ]
        .compactMap { $0 }
        .joined(separator: "\n")

        let severity: String = {
            if isError {
                return "error"
            }

            if isSuccess {
                return "success"
            }

            return "info"
        }()

        return AdminDiagnosticLog(
            id: "google_\(doc.documentID)",
            type: type,
            title: title,
            message: fullMessage.isEmpty
                ? tr("אירוע אבחון של התחברות Google", "Google authentication diagnostic event")
                : fullMessage,
            area: "google_auth",
            severity: severity,
            userRole: doc.get("userRole") as? String ?? "unknown",
            appVersion: doc.get("versionName") as? String ??
                doc.get("appVersion") as? String ??
                "",
            deviceModel: doc.get("deviceModel") as? String ??
                doc.get("device") as? String ??
                "",
            language: doc.get("language") as? String ?? "",
            createdAt: doc.get("createdAt") as? Timestamp
        )
    }

    @MainActor
    private func createAndShareDiagnosticsPDF() {
        guard !isCreatingPDF else {
            return
        }

        guard !isLoading else {
            pdfErrorMessage = tr(
                "הנתונים עדיין נטענים. נסה שוב בעוד מספר שניות.",
                "The data is still loading. Try again in a few seconds."
            )
            return
        }

        isCreatingPDF = true
        pdfShareItems.removeAll()

        do {
            let pdfURL = try createDiagnosticsPDF()

            pdfShareItems = [pdfURL]
            showPDFShareSheet = true
            isCreatingPDF = false
        } catch {
            isCreatingPDF = false

            pdfErrorMessage = tr(
                "יצירת קובץ ה־PDF נכשלה: \(error.localizedDescription)",
                "Failed to create the PDF: \(error.localizedDescription)"
            )
        }
    }

    private func createDiagnosticsPDF() throws -> URL {
        let pageSize = CGSize(
            width: 595,
            height: 842
        )

        let pageBounds = CGRect(
            origin: .zero,
            size: pageSize
        )

        let horizontalMargin: CGFloat = 36
        let contentWidth =
            pageSize.width - (horizontalMargin * 2)

        let contentBottom =
            pageSize.height - 58

        let fileName =
            "KMI_Diagnostics_" +
            ISO8601DateFormatter()
                .string(from: Date())
                .replacingOccurrences(of: ":", with: "-") +
            ".pdf"

        let fileURL =
            FileManager.default.temporaryDirectory
                .appendingPathComponent(fileName)

        try? FileManager.default.removeItem(
            at: fileURL
        )

        let renderer = UIGraphicsPDFRenderer(
            bounds: pageBounds
        )

        let paragraphAlignment: NSTextAlignment =
            isEnglish ? .left : .right

        let writingDirection: NSWritingDirection =
            isEnglish ? .leftToRight : .rightToLeft

        let titleStyle = NSMutableParagraphStyle()
        titleStyle.alignment = paragraphAlignment
        titleStyle.baseWritingDirection = writingDirection

        let bodyStyle = NSMutableParagraphStyle()
        bodyStyle.alignment = paragraphAlignment
        bodyStyle.baseWritingDirection = writingDirection
        bodyStyle.lineSpacing = 2

        let centeredStyle = NSMutableParagraphStyle()
        centeredStyle.alignment = .center

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(
                ofSize: 25,
                weight: .black
            ),
            .foregroundColor: UIColor.white,
            .paragraphStyle: titleStyle
        ]

        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(
                ofSize: 12,
                weight: .semibold
            ),
            .foregroundColor: UIColor.white.withAlphaComponent(0.88),
            .paragraphStyle: titleStyle
        ]

        let sectionAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(
                ofSize: 15,
                weight: .black
            ),
            .foregroundColor: UIColor(
                red: 0.059,
                green: 0.090,
                blue: 0.165,
                alpha: 1
            ),
            .paragraphStyle: bodyStyle
        ]

        let rowTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(
                ofSize: 11,
                weight: .bold
            ),
            .foregroundColor: UIColor(
                red: 0.059,
                green: 0.090,
                blue: 0.165,
                alpha: 1
            ),
            .paragraphStyle: bodyStyle
        ]

        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(
                ofSize: 9.5,
                weight: .regular
            ),
            .foregroundColor: UIColor(
                red: 0.278,
                green: 0.333,
                blue: 0.412,
                alpha: 1
            ),
            .paragraphStyle: bodyStyle
        ]

        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(
                ofSize: 8.5,
                weight: .medium
            ),
            .foregroundColor: UIColor(
                red: 0.392,
                green: 0.455,
                blue: 0.545,
                alpha: 1
            ),
            .paragraphStyle: centeredStyle
        ]

        let navy = UIColor(
            red: 0.008,
            green: 0.169,
            blue: 0.290,
            alpha: 1
        )

        let blue = UIColor(
            red: 0.141,
            green: 0.404,
            blue: 0.620,
            alpha: 1
        )

        let lightBlue = UIColor(
            red: 0.502,
            green: 0.718,
            blue: 0.863,
            alpha: 1
        )

        let cardBackground = UIColor(
            red: 0.973,
            green: 0.980,
            blue: 0.988,
            alpha: 1
        )

        let cardBorder = UIColor(
            red: 0.796,
            green: 0.835,
            blue: 0.882,
            alpha: 1
        )

        let selectedRangeTitle =
            selectedRange.title(
                isEnglish: isEnglish
            )

        let selectedTypeTitle =
            selectedType.title(
                isEnglish: isEnglish
            )

        var pageNumber = 0
        var y: CGFloat = 0

        func drawString(
            _ value: String,
            attributes: [NSAttributedString.Key: Any],
            rect: CGRect
        ) {
            NSString(string: value).draw(
                with: rect,
                options: [
                    .usesLineFragmentOrigin,
                    .usesFontLeading,
                    .truncatesLastVisibleLine
                ],
                attributes: attributes,
                context: nil
            )
        }

        func measuredHeight(
            _ value: String,
            attributes: [NSAttributedString.Key: Any],
            width: CGFloat
        ) -> CGFloat {
            let bounds = NSString(string: value).boundingRect(
                with: CGSize(
                    width: width,
                    height: .greatestFiniteMagnitude
                ),
                options: [
                    .usesLineFragmentOrigin,
                    .usesFontLeading
                ],
                attributes: attributes,
                context: nil
            )

            return ceil(bounds.height)
        }

        func drawHeader(
            context: UIGraphicsPDFRendererContext
        ) {
            context.cgContext.setFillColor(
                UIColor.white.cgColor
            )
            context.cgContext.fill(pageBounds)

            context.cgContext.setFillColor(
                navy.cgColor
            )
            context.cgContext.fill(
                CGRect(
                    x: 0,
                    y: 0,
                    width: pageSize.width,
                    height: 122
                )
            )

            let middleStripe = UIBezierPath()
            middleStripe.move(
                to: CGPoint(x: 190, y: 122)
            )
            middleStripe.addLine(
                to: CGPoint(x: 222, y: 122)
            )
            middleStripe.addLine(
                to: CGPoint(x: 282, y: 0)
            )
            middleStripe.addLine(
                to: CGPoint(x: 250, y: 0)
            )
            middleStripe.close()

            blue.setFill()
            middleStripe.fill()

            let lightStripe = UIBezierPath()
            lightStripe.move(
                to: CGPoint(x: 222, y: 122)
            )
            lightStripe.addLine(
                to: CGPoint(x: 237, y: 122)
            )
            lightStripe.addLine(
                to: CGPoint(x: 297, y: 0)
            )
            lightStripe.addLine(
                to: CGPoint(x: 282, y: 0)
            )
            lightStripe.close()

            lightBlue.setFill()
            lightStripe.fill()

            let title = tr(
                "דו״ח בקרה ולוגים",
                "Diagnostics Report"
            )

            drawString(
                title,
                attributes: titleAttributes,
                rect: CGRect(
                    x: horizontalMargin,
                    y: 28,
                    width: contentWidth,
                    height: 34
                )
            )

            drawString(
                "\(selectedRangeTitle) • \(selectedTypeTitle)",
                attributes: subtitleAttributes,
                rect: CGRect(
                    x: horizontalMargin,
                    y: 68,
                    width: contentWidth,
                    height: 22
                )
            )

            let generatedDate = DateFormatter()
            generatedDate.locale = Locale(
                identifier: isEnglish
                    ? "en_US"
                    : "he_IL"
            )
            generatedDate.dateFormat =
                "dd/MM/yyyy HH:mm"

            let generatedText = tr(
                "תאריך הפקה: \(generatedDate.string(from: Date()))",
                "Generated: \(generatedDate.string(from: Date()))"
            )

            drawString(
                generatedText,
                attributes: bodyAttributes,
                rect: CGRect(
                    x: horizontalMargin,
                    y: 136,
                    width: contentWidth,
                    height: 18
                )
            )

            y = 174
        }

        func drawFooter() {
            let context =
                UIGraphicsGetCurrentContext()

            context?.setStrokeColor(
                cardBorder.cgColor
            )
            context?.setLineWidth(1)
            context?.move(
                to: CGPoint(
                    x: horizontalMargin,
                    y: pageSize.height - 42
                )
            )
            context?.addLine(
                to: CGPoint(
                    x: pageSize.width - horizontalMargin,
                    y: pageSize.height - 42
                )
            )
            context?.strokePath()

            drawString(
                tr(
                    "עמוד \(pageNumber) • KMI",
                    "Page \(pageNumber) • KMI"
                ),
                attributes: footerAttributes,
                rect: CGRect(
                    x: horizontalMargin,
                    y: pageSize.height - 34,
                    width: contentWidth,
                    height: 16
                )
            )
        }

        func beginPage(
            context: UIGraphicsPDFRendererContext
        ) {
            if pageNumber > 0 {
                drawFooter()
            }

            context.beginPage()
            pageNumber += 1
            drawHeader(context: context)
        }

        func ensureSpace(
            _ requiredHeight: CGFloat,
            context: UIGraphicsPDFRendererContext
        ) {
            if y + requiredHeight > contentBottom {
                beginPage(context: context)
            }
        }

        func drawSection(
            _ title: String,
            context: UIGraphicsPDFRendererContext
        ) {
            ensureSpace(30, context: context)

            drawString(
                title,
                attributes: sectionAttributes,
                rect: CGRect(
                    x: horizontalMargin,
                    y: y,
                    width: contentWidth,
                    height: 24
                )
            )

            y += 29
        }

        func drawCard(
            title: String,
            body: String,
            context: UIGraphicsPDFRendererContext
        ) {
            let cleanBody = body
                .replacingOccurrences(
                    of: "\n",
                    with: " "
                )
                .replacingOccurrences(
                    of: "\\s+",
                    with: " ",
                    options: .regularExpression
                )
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            let titleHeight = measuredHeight(
                title,
                attributes: rowTitleAttributes,
                width: contentWidth - 20
            )

            let bodyHeight = cleanBody.isEmpty
                ? 0
                : min(
                    measuredHeight(
                        cleanBody,
                        attributes: bodyAttributes,
                        width: contentWidth - 20
                    ),
                    48
                )

            let cardHeight =
                max(48, titleHeight + bodyHeight + 25)

            ensureSpace(
                cardHeight + 8,
                context: context
            )

            let cardRect = CGRect(
                x: horizontalMargin,
                y: y,
                width: contentWidth,
                height: cardHeight
            )

            let cardPath = UIBezierPath(
                roundedRect: cardRect,
                cornerRadius: 9
            )

            cardBackground.setFill()
            cardPath.fill()

            cardBorder.setStroke()
            cardPath.lineWidth = 1
            cardPath.stroke()

            drawString(
                title,
                attributes: rowTitleAttributes,
                rect: CGRect(
                    x: cardRect.minX + 10,
                    y: cardRect.minY + 8,
                    width: cardRect.width - 20,
                    height: titleHeight + 3
                )
            )

            if !cleanBody.isEmpty {
                drawString(
                    cleanBody,
                    attributes: bodyAttributes,
                    rect: CGRect(
                        x: cardRect.minX + 10,
                        y: cardRect.minY + titleHeight + 12,
                        width: cardRect.width - 20,
                        height: bodyHeight
                    )
                )
            }

            y += cardHeight + 8
        }

        try renderer.writePDF(
            to: fileURL
        ) { context in
            beginPage(context: context)

            drawSection(
                tr("סיכום", "Summary"),
                context: context
            )

            let summaryRows = [
                tr(
                    "אירועים: \(visibleLogs.count)",
                    "Events: \(visibleLogs.count)"
                ),
                tr(
                    "שגיאות: \(errorCount)",
                    "Errors: \(errorCount)"
                ),
                tr(
                    "כניסות: \(loginCount)",
                    "Logins: \(loginCount)"
                ),
                tr(
                    "חיפוש ללא תוצאה: \(searchNoResultsCount)",
                    "No-result searches: \(searchNoResultsCount)"
                ),
                tr(
                    "פעולות מוצלחות: \(successCount)",
                    "Successful actions: \(successCount)"
                )
            ]

            for row in summaryRows {
                drawCard(
                    title: row,
                    body: "",
                    context: context
                )
            }

            drawSection(
                tr(
                    "10 המסכים הכי נצפים",
                    "Top 10 Screens"
                ),
                context: context
            )

            if visibleTopScreens.isEmpty {
                drawCard(
                    title: tr(
                        "אין נתוני צפייה",
                        "No Screen Data"
                    ),
                    body: tr(
                        "אין עדיין נתוני צפייה במסכים.",
                        "No screen view data is available."
                    ),
                    context: context
                )
            } else {
                for (index, screen) in
                    visibleTopScreens.enumerated() {
                    drawCard(
                        title:
                            "\(index + 1). \(screen.screenName)",
                        body: tr(
                            "\(screen.count) צפיות",
                            "\(screen.count) views"
                        ),
                        context: context
                    )
                }
            }

            drawSection(
                tr("אירועי מערכת", "System Events"),
                context: context
            )

            if visibleLogs.isEmpty {
                drawCard(
                    title: tr(
                        "אין אירועים להצגה",
                        "No Events to Show"
                    ),
                    body: tr(
                        "לא נמצאו אירועים בטווח ובסינון שנבחרו.",
                        "No events were found for the selected range and filter."
                    ),
                    context: context
                )
            } else {
                for log in visibleLogs {
                    let logTitle =
                        log.title.isEmpty
                        ? (
                            log.type.isEmpty
                            ? tr(
                                "אירוע מערכת",
                                "System Event"
                            )
                            : log.type
                        )
                        : log.title

                    let metadata = [
                        formatLogTime(
                            log.createdAt,
                            isEnglish: isEnglish
                        ),
                        log.area.isEmpty
                            ? nil
                            : tr(
                                "אזור: \(log.area)",
                                "Area: \(log.area)"
                            ),
                        log.userRole.isEmpty
                            ? nil
                            : tr(
                                "תפקיד: \(log.userRole)",
                                "Role: \(log.userRole)"
                            ),
                        log.appVersion.isEmpty
                            ? nil
                            : tr(
                                "גרסה: \(log.appVersion)",
                                "Version: \(log.appVersion)"
                            ),
                        log.message.isEmpty
                            ? nil
                            : log.message
                    ]
                    .compactMap { $0 }
                    .joined(separator: " • ")

                    drawCard(
                        title: logTitle,
                        body: metadata,
                        context: context
                    )
                }
            }

            drawFooter()
        }

        return fileURL
    }
}

private struct AdminDiagnosticsLoadingView: View {
    let title: String

    @State private var outerRotation: Double = 0
    @State private var middleRotation: Double = 0
    @State private var innerRotation: Double = 0
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 13) {
            ZStack {
                Circle()
                    .stroke(
                        Color.white.opacity(0.13),
                        lineWidth: 4
                    )
                    .frame(width: 62, height: 62)

                Circle()
                    .trim(from: 0.05, to: 0.72)
                    .stroke(
                        Color(
                            red: 0.216,
                            green: 0.718,
                            blue: 0.910
                        ),
                        style: StrokeStyle(
                            lineWidth: 4,
                            lineCap: .round
                        )
                    )
                    .frame(width: 62, height: 62)
                    .rotationEffect(.degrees(outerRotation))

                Circle()
                    .trim(from: 0.10, to: 0.66)
                    .stroke(
                        Color(
                            red: 0.486,
                            green: 0.302,
                            blue: 1.000
                        ),
                        style: StrokeStyle(
                            lineWidth: 4,
                            lineCap: .round
                        )
                    )
                    .frame(width: 46, height: 46)
                    .rotationEffect(.degrees(middleRotation))

                Circle()
                    .trim(from: 0.02, to: 0.58)
                    .stroke(
                        Color(
                            red: 0.490,
                            green: 1.000,
                            blue: 0.702
                        ),
                        style: StrokeStyle(
                            lineWidth: 4,
                            lineCap: .round
                        )
                    )
                    .frame(width: 30, height: 30)
                    .rotationEffect(.degrees(innerRotation))

                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 7, height: 7)
                    .shadow(
                        color: Color.white.opacity(0.45),
                        radius: 5
                    )
            }
            .frame(width: 68, height: 68)
            .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .onAppear {
            guard !isAnimating else {
                return
            }

            isAnimating = true

            withAnimation(
                .linear(duration: 1.15)
                    .repeatForever(autoreverses: false)
            ) {
                outerRotation = 360
            }

            withAnimation(
                .linear(duration: 0.90)
                    .repeatForever(autoreverses: false)
            ) {
                middleRotation = -360
            }

            withAnimation(
                .linear(duration: 0.68)
                    .repeatForever(autoreverses: false)
            ) {
                innerRotation = 360
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

private struct AdminSummaryCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        SurfaceLikeCard(
            cornerRadius: 18,
            background: AdminDiagnosticsTheme.cardStrong,
            border: color.opacity(0.55),
            shadowRadius: 2
        ) {
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)

                Text(title)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(
                        AdminDiagnosticsTheme.primaryText
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }
}

private struct AdminInsightsCard: View {
    let isEnglish: Bool
    let errorCount: Int
    let loginCount: Int
    let searchNoResultsCount: Int
    let successCount: Int

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private var insights: [String] {
        [
            tr("נמצאו \(loginCount) אירועי כניסה בטווח שנבחר.", "\(loginCount) login events found."),
            tr("נמצאו \(errorCount) שגיאות או כשלונות.", "\(errorCount) errors or failures found."),
            tr(
                "נמצאו \(searchNoResultsCount) חיפושים ללא תוצאה.",
                "\(searchNoResultsCount) searches had no results."
            ),
            tr(
                "נמצאו \(successCount) פעולות שהסתיימו בהצלחה.",
                "\(successCount) successful actions found."
            )
        ]
    }

    var body: some View {
        SurfaceLikeCard(
            cornerRadius: 22,
            background: Color(red: 0.086, green: 0.208, blue: 0.141).opacity(0.58),
            border: Color(red: 0.490, green: 1.0, blue: 0.702).opacity(0.25)
        ) {
            VStack(alignment: isEnglish ? .leading : .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    if isEnglish {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Color(red: 0.490, green: 1.0, blue: 0.702))

                        Text(tr("תובנות מהירות", "Quick insights"))
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(.white)

                        Spacer()
                    } else {
                        Spacer()

                        Text(tr("תובנות מהירות", "Quick insights"))
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(.white)

                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Color(red: 0.490, green: 1.0, blue: 0.702))
                    }
                }

                VStack(alignment: isEnglish ? .leading : .trailing, spacing: 4) {
                    ForEach(insights, id: \.self) { insight in
                        Text("• \(insight)")
                            .font(.system(size: 11.5, weight: .semibold))
                            .lineSpacing(2)
                            .foregroundStyle(.white.opacity(0.84))
                            .multilineTextAlignment(isEnglish ? .leading : .trailing)
                            .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}

private struct TopScreensCard: View {
    let isEnglish: Bool
    let screens: [AdminTopScreen]
    let onReset: () -> Void

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    var body: some View {
        SurfaceLikeCard(
            cornerRadius: 22,
            background: AdminDiagnosticsTheme.cardMedium,
            border: Color(red: 0.216, green: 0.718, blue: 0.910)
                .opacity(0.55),
            shadowRadius: 3
        ) {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(
                            Color(red: 0.008, green: 0.518, blue: 0.780)
                        )

                    Text(tr("10 המסכים הכי נצפים", "Top 10 screens"))
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(
                            AdminDiagnosticsTheme.primaryText
                        )
                        .lineLimit(1)
                        .frame(
                            maxWidth: .infinity,
                            alignment: isEnglish ? .leading : .trailing
                        )

                    Button(action: onReset) {
                        Text(tr("איפוס", "Reset"))
                            .font(.system(size: 10.5, weight: .black))
                            .foregroundStyle(
                                Color(red: 0.604, green: 0.204, blue: 0.071)
                            )
                            .lineLimit(1)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(
                                        Color(
                                            red: 1.000,
                                            green: 0.969,
                                            blue: 0.929
                                        )
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                Color(
                                                    red: 0.976,
                                                    green: 0.451,
                                                    blue: 0.086
                                                )
                                                .opacity(0.45),
                                                lineWidth: 1
                                            )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }

                if screens.isEmpty {
                    Text(
                        tr(
                            "אין עדיין נתוני צפייה במסכים.",
                            "No screen view data yet."
                        )
                    )
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(
                        AdminDiagnosticsTheme.secondaryText
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: isEnglish ? .leading : .trailing
                    )
                    .multilineTextAlignment(
                        isEnglish ? .leading : .trailing
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(
                            Array(screens.enumerated()),
                            id: \.element.id
                        ) { index, item in
                            HStack(spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundStyle(
                                        Color(
                                            red: 0.008,
                                            green: 0.518,
                                            blue: 0.780
                                        )
                                    )
                                    .frame(width: 26, alignment: .center)

                                Text(item.screenName)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(
                                        AdminDiagnosticsTheme.primaryText
                                    )
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment:
                                            isEnglish ? .leading : .trailing
                                    )

                                Text("\(item.count)")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundStyle(
                                        Color(
                                            red: 0.086,
                                            green: 0.639,
                                            blue: 0.290
                                        )
                                    )
                                    .frame(width: 52, alignment: .center)
                            }
                            .padding(.vertical, 5)

                            if index != screens.count - 1 {
                                Rectangle()
                                    .fill(
                                        AdminDiagnosticsTheme.divider
                                    )
                                    .frame(height: 1)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}

private struct FilterRows: View {
    let isEnglish: Bool
    let selectedRange: AdminDiagnosticsRange
    let onRangeSelected: (AdminDiagnosticsRange) -> Void
    let selectedType: AdminDiagnosticsType
    let onTypeSelected: (AdminDiagnosticsType) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(AdminDiagnosticsRange.allCases, id: \.self) { range in
                        FilterPill(
                            title: range.title(isEnglish: isEnglish),
                            selected: selectedRange == range,
                            onTap: {
                                onRangeSelected(range)
                            }
                        )
                    }
                }
                .padding(.horizontal, 1)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(AdminDiagnosticsType.allCases, id: \.self) { type in
                        FilterPill(
                            title: type.title(isEnglish: isEnglish),
                            selected: selectedType == type,
                            onTap: {
                                onTypeSelected(type)
                            }
                        )
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
}

private struct FilterPill: View {
    let title: String
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(
                    AdminDiagnosticsTheme.primaryText
                )
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(
                            selected
                                ? AdminDiagnosticsTheme.selectedFilter
                                : AdminDiagnosticsTheme.cardStrong
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    selected
                                        ? Color(
                                            red: 0.486,
                                            green: 0.302,
                                            blue: 1.000
                                        )
                                        : Color(
                                            red: 0.216,
                                            green: 0.718,
                                            blue: 0.910
                                        )
                                        .opacity(0.70),
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(
            selected ? .isSelected : []
        )
    }
}

private struct AdminLogGroupHeader: View {
    let title: String
    let count: Int
    let color: Color
    let expanded: Bool
    let isEnglish: Bool
    let onReset: () -> Void
    let onClick: () -> Void

    var body: some View {
        SurfaceLikeCard(
            cornerRadius: 18,
            background: AdminDiagnosticsTheme.cardStrong,
            border: color.opacity(0.45),
            shadowRadius: 2
        ) {
            HStack(spacing: 10) {
                Button(action: onClick) {
                    Text(expanded ? "⌃" : "⌄")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(color)
                        .frame(width: 28, alignment: .center)
                }
                .buttonStyle(.plain)

                Button(action: onClick) {
                    VStack(
                        alignment: isEnglish ? .leading : .trailing,
                        spacing: 2
                    ) {
                        Text(title)
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(
                                AdminDiagnosticsTheme.primaryText
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(
                                maxWidth: .infinity,
                                alignment:
                                    isEnglish ? .leading : .trailing
                            )

                        Text(
                            isEnglish
                                ? "\(count) events"
                                : "\(count) אירועים"
                        )
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(color)
                        .frame(
                            maxWidth: .infinity,
                            alignment: isEnglish ? .leading : .trailing
                        )
                    }
                }
                .buttonStyle(.plain)

                Button(action: onReset) {
                    Text(isEnglish ? "Reset" : "איפוס")
                        .font(.system(size: 10.5, weight: .black))
                        .foregroundStyle(
                            Color(red: 0.604, green: 0.204, blue: 0.071)
                        )
                        .lineLimit(1)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(
                                    Color(
                                        red: 1.000,
                                        green: 0.969,
                                        blue: 0.929
                                    )
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            Color(
                                                red: 0.976,
                                                green: 0.451,
                                                blue: 0.086
                                            )
                                            .opacity(0.45),
                                            lineWidth: 1
                                        )
                                )
                        )
                }
                .buttonStyle(.plain)

                Button(action: onClick) {
                    CircleIcon(
                        systemName: "chart.bar.xaxis",
                        color: color
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
        }
    }
}

private struct AdminLogCard: View {
    let log: AdminDiagnosticLog
    let isEnglish: Bool

    private var severityColor: Color {
        if log.severity.localizedCaseInsensitiveContains("error") ||
            log.type.localizedCaseInsensitiveContains("failed") {
            return Color(red: 1.0, green: 0.541, blue: 0.541)
        }

        if log.type.localizedCaseInsensitiveContains("search") {
            return Color(red: 1.0, green: 0.820, blue: 0.400)
        }

        if log.type.localizedCaseInsensitiveContains("success") ||
            log.type.localizedCaseInsensitiveContains("saved") {
            return Color(red: 0.490, green: 1.0, blue: 0.702)
        }

        return Color(red: 0.561, green: 0.827, blue: 1.0)
    }

    var body: some View {
        SurfaceLikeCard(
            cornerRadius: 20,
            background: AdminDiagnosticsTheme.cardMedium,
            border: severityColor.opacity(0.42),
            shadowRadius: 2
        ) {
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    CircleIcon(
                        systemName: log.type.localizedCaseInsensitiveContains("search") ? "magnifyingglass" : "chart.bar.xaxis",
                        color: severityColor
                    )

                    VStack(alignment: isEnglish ? .leading : .trailing, spacing: 2) {
                        Text(
                            log.title.isEmpty
                                ? (
                                    log.type.isEmpty
                                        ? (
                                            isEnglish
                                                ? "Log event"
                                                : "אירוע מערכת"
                                        )
                                        : log.type
                                )
                                : log.title
                        )
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(
                            AdminDiagnosticsTheme.primaryText
                        )
                            .lineLimit(2)
                            .multilineTextAlignment(isEnglish ? .leading : .trailing)
                            .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)

                        Text(
                            formatLogTime(
                                log.createdAt,
                                isEnglish: isEnglish
                            )
                        )
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(
                            AdminDiagnosticsTheme.secondaryText
                        )
                            .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
                    }
                }

                if !log.message.isEmpty {
                    Text(log.message)
                        .font(.system(size: 11.5, weight: .medium))
                        .lineSpacing(2)
                        .foregroundStyle(
                            AdminDiagnosticsTheme.bodyText
                        )
                        .lineLimit(3)
                        .multilineTextAlignment(isEnglish ? .leading : .trailing)
                        .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
                }

                Rectangle()
                    .fill(AdminDiagnosticsTheme.divider)
                    .frame(height: 1)

                Text(metaText)
                    .font(.system(size: 10.5, weight: .semibold))
                    .lineSpacing(2)
                    .foregroundStyle(
                        AdminDiagnosticsTheme.secondaryText
                    )
                    .multilineTextAlignment(isEnglish ? .leading : .trailing)
                    .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    private var metaText: String {
        var parts: [String] = []

        parts.append(
            (isEnglish ? "Area: " : "אזור: ") +
            (log.area.isEmpty ? "-" : log.area)
        )

        parts.append(
            (isEnglish ? "Role: " : "תפקיד: ") +
            (log.userRole.isEmpty ? "-" : log.userRole)
        )

        if !log.appVersion.isEmpty {
            parts.append(
                (isEnglish ? "Version: " : "גרסה: ") +
                log.appVersion
            )
        }

        if !log.deviceModel.isEmpty {
            parts.append(
                (isEnglish ? "Device: " : "מכשיר: ") +
                log.deviceModel
            )
        }

        if !log.language.isEmpty {
            parts.append(
                (isEnglish ? "Language: " : "שפה: ") +
                log.language
            )
        }

        return parts.joined(separator: "  |  ")
    }
}

private struct AdminStateCard: View {
    let icon: String
    let title: String
    let message: String
    let isEnglish: Bool

    var body: some View {
        SurfaceLikeCard(
            cornerRadius: 22,
            background: Color.white.opacity(0.10),
            border: Color.white.opacity(0.18)
        ) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(.white)

                Text(title)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(18)
        }
    }
}

private struct CircleIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.18))

            Image(systemName: systemName)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(color)
        }
        .frame(width: 34, height: 34)
    }
}

private struct SurfaceLikeCard<Content: View>: View {
    let cornerRadius: CGFloat
    let background: Color
    let border: Color
    var shadowRadius: CGFloat = 0
    let content: Content

    @Environment(\.colorScheme) private var colorScheme

    init(
        cornerRadius: CGFloat,
        background: Color,
        border: Color,
        shadowRadius: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.background = background
        self.border = border
        self.shadowRadius = shadowRadius
        self.content = content()
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
                .fill(background)
                .overlay(
                    RoundedRectangle(
                        cornerRadius: cornerRadius,
                        style: .continuous
                    )
                    .stroke(border, lineWidth: 1)
                )
                .shadow(
                    color: Color.black.opacity(
                        shadowRadius > 0
                            ? (
                                colorScheme == .dark
                                    ? 0.28
                                    : 0.10
                            )
                            : 0
                    ),
                    radius: shadowRadius,
                    x: 0,
                    y: shadowRadius
                )
            )
    }
}

private func formatLogTime(
    _ timestamp: Timestamp?,
    isEnglish: Bool
) -> String {
    guard let date = timestamp?.dateValue() else {
        return isEnglish ? "Unknown time" : "זמן לא ידוע"
    }

    let difference =
        max(Date().timeIntervalSince(date), 0)

    let minutes = Int(difference / 60)
    let hours = Int(difference / 3_600)
    let days = Int(difference / 86_400)

    if minutes < 1 {
        return isEnglish ? "Now" : "עכשיו"
    }

    if minutes < 60 {
        return isEnglish
            ? "\(minutes) min ago"
            : "לפני \(minutes) דקות"
    }

    if hours < 24 {
        return isEnglish
            ? "\(hours) hours ago"
            : "לפני \(hours) שעות"
    }

    if days < 7 {
        return isEnglish
            ? "\(days) days ago"
            : "לפני \(days) ימים"
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(
        identifier: isEnglish ? "en_US" : "he_IL"
    )
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.dateFormat = "dd/MM/yyyy HH:mm"

    return formatter.string(from: date)
}
