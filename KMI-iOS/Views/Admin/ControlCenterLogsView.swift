import SwiftUI
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

    @State private var adminListener: ListenerRegistration? = nil
    @State private var googleListener: ListenerRegistration? = nil
    @State private var screensListener: ListenerRegistration? = nil

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private var allLogs: [AdminDiagnosticLog] {
        adminLogs + googleAuthLogs
    }

    private var isLoading: Bool {
        loadingAdminLogs || loadingGoogleLogs || loadingScreens
    }

    private var rangeStartMillis: TimeInterval {
        Date().timeIntervalSince1970 - Double(selectedRange.days * 24 * 60 * 60)
    }

    private var filteredLogs: [AdminDiagnosticLog] {
        allLogs.filter { log in
            let createdMillis = log.createdAt?.dateValue().timeIntervalSince1970 ?? 0
            let inRange = createdMillis >= rangeStartMillis

            let inType =
                selectedType == .all ||
                log.type.localizedCaseInsensitiveContains(selectedType.key) ||
                log.area.localizedCaseInsensitiveContains(selectedType.key) ||
                log.severity.localizedCaseInsensitiveContains(selectedType.key)

            return inRange && inType
        }
    }

    private var errorCount: Int {
        filteredLogs.filter { log in
            log.severity.localizedCaseInsensitiveContains("error") ||
            log.type.localizedCaseInsensitiveContains("error") ||
            log.type.localizedCaseInsensitiveContains("failed") ||
            log.type.localizedCaseInsensitiveContains("failure") ||
            log.message.localizedCaseInsensitiveContains("errorClass=") ||
            log.message.localizedCaseInsensitiveContains("errorMessage=") ||
            log.message.localizedCaseInsensitiveContains("apiStatusCode=")
        }
        .count
    }

    private var loginCount: Int {
        filteredLogs.filter { log in
            log.type.localizedCaseInsensitiveContains("login") ||
            log.type.localizedCaseInsensitiveContains("google_auth") ||
            log.area.localizedCaseInsensitiveContains("google_auth")
        }
        .count
    }

    private var searchNoResultsCount: Int {
        filteredLogs.filter { log in
            log.type.localizedCaseInsensitiveContains("search_no_results") ||
            (
                log.type.localizedCaseInsensitiveContains("search") &&
                log.type.localizedCaseInsensitiveContains("no")
            )
        }
        .count
    }

    private var successCount: Int {
        filteredLogs.filter { log in
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
            "errors",
            "google_auth",
            "login",
            "search",
            "screen_views",
            "other"
        ]

        let grouped = Dictionary(grouping: filteredLogs) { log in
            logGroupKey(log)
        }

        return grouped
            .map { (key: $0.key, items: $0.value) }
            .sorted { left, right in
                let leftIndex = order.firstIndex(of: left.key) ?? Int.max
                let rightIndex = order.firstIndex(of: right.key) ?? Int.max
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
                            value: "\(filteredLogs.count)",
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
                        screens: topScreens
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
    }

    private var screenBackground: some View {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.937, green: 0.984, blue: 1.0), location: 0.00),
                .init(color: Color(red: 0.741, green: 0.933, blue: 1.0), location: 0.34),
                .init(color: Color(red: 0.129, green: 0.647, blue: 0.863), location: 0.68),
                .init(color: Color(red: 0.000, green: 0.435, blue: 0.682), location: 1.00)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var introCard: some View {
        SurfaceLikeCard(
            cornerRadius: 14,
            background: Color.white.opacity(0.72),
            border: Color(red: 0.216, green: 0.718, blue: 0.910).opacity(0.45)
        ) {
            Text(
                tr(
                    "ניתוח פעילות, תקלות ושימוש באפליקציה",
                    "Activity, errors and app diagnostics"
                )
            )
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(Color(red: 0.063, green: 0.125, blue: 0.200))
            .lineSpacing(2)
            .multilineTextAlignment(isEnglish ? .leading : .trailing)
            .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
    }

    @ViewBuilder
    private var contentState: some View {
        if isLoading {
            VStack(spacing: 10) {
                ProgressView()
                    .tint(.white)

                Text(tr("טוען לוגים...", "Loading logs..."))
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 28)
        } else if let errorMessage {
            AdminStateCard(
                icon: "chart.bar.xaxis",
                title: tr("לא ניתן לטעון לוגים", "Unable to load logs"),
                message: errorMessage,
                isEnglish: isEnglish
            )
        } else if filteredLogs.isEmpty {
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
                        onClick: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                expandedLogGroupKey =
                                    expandedLogGroupKey == group.key ? nil : group.key
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
        if log.severity.localizedCaseInsensitiveContains("error") ||
            log.type.localizedCaseInsensitiveContains("error") ||
            log.type.localizedCaseInsensitiveContains("failed") ||
            log.type.localizedCaseInsensitiveContains("failure") {
            return "errors"
        }

        if log.type.localizedCaseInsensitiveContains("screen_view") ||
            log.area.localizedCaseInsensitiveContains("screen") {
            return "screen_views"
        }

        if log.type.localizedCaseInsensitiveContains("google_auth") ||
            log.area.localizedCaseInsensitiveContains("google_auth") {
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
        case "google_auth":
            return tr("אירועי כניסה עם Google", "Google sign-in events")
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
}

private struct AdminSummaryCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        SurfaceLikeCard(
            cornerRadius: 18,
            background: Color.white.opacity(0.94),
            border: color.opacity(0.55),
            shadowRadius: 2
        ) {
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(color)
                    .lineLimit(1)

                Text(title)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Color(red: 0.063, green: 0.125, blue: 0.200))
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

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    var body: some View {
        SurfaceLikeCard(
            cornerRadius: 22,
            background: Color.white.opacity(0.88),
            border: Color(red: 0.216, green: 0.718, blue: 0.910).opacity(0.55),
            shadowRadius: 3
        ) {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    if isEnglish {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Color(red: 0.008, green: 0.518, blue: 0.780))

                        Text(tr("10 המסכים הכי נצפים", "Top 10 screens"))
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Color(red: 0.063, green: 0.125, blue: 0.200))

                        Spacer()
                    } else {
                        Spacer()

                        Text(tr("10 המסכים הכי נצפים", "Top 10 screens"))
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Color(red: 0.063, green: 0.125, blue: 0.200))

                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Color(red: 0.008, green: 0.518, blue: 0.780))
                    }
                }

                if screens.isEmpty {
                    Text(
                        tr(
                            "אין עדיין נתוני צפייה במסכים.",
                            "No screen view data yet."
                        )
                    )
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Color(red: 0.278, green: 0.333, blue: 0.412))
                    .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
                    .multilineTextAlignment(isEnglish ? .leading : .trailing)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(screens.enumerated()), id: \.offset) { index, item in
                            HStack(spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundStyle(Color(red: 0.008, green: 0.518, blue: 0.780))
                                    .frame(width: 26, alignment: .center)

                                Text(item.screenName)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color(red: 0.063, green: 0.125, blue: 0.200))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)

                                Text("\(item.count)")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundStyle(Color(red: 0.086, green: 0.639, blue: 0.290))
                                    .frame(width: 52, alignment: .center)
                            }
                            .padding(.vertical, 5)

                            if index != screens.count - 1 {
                                Rectangle()
                                    .fill(Color(red: 0.796, green: 0.835, blue: 0.882).opacity(0.55))
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
                .foregroundStyle(Color(red: 0.063, green: 0.125, blue: 0.200))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(selected ? Color(red: 0.929, green: 0.894, blue: 1.0) : Color.white.opacity(0.94))
                        .overlay(
                            Capsule()
                                .stroke(
                                    selected
                                        ? Color(red: 0.486, green: 0.302, blue: 1.0)
                                        : Color(red: 0.216, green: 0.718, blue: 0.910).opacity(0.70),
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

private struct AdminLogGroupHeader: View {
    let title: String
    let count: Int
    let color: Color
    let expanded: Bool
    let isEnglish: Bool
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            SurfaceLikeCard(
                cornerRadius: 18,
                background: Color.white.opacity(0.94),
                border: color.opacity(0.45),
                shadowRadius: 2
            ) {
                HStack(spacing: 10) {
                    Text(expanded ? "⌃" : "⌄")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(color)
                        .frame(width: 28, alignment: .center)

                    VStack(alignment: isEnglish ? .leading : .trailing, spacing: 2) {
                        Text(title)
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Color(red: 0.063, green: 0.125, blue: 0.200))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)

                        Text(isEnglish ? "\(count) events" : "\(count) אירועים")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(color)
                            .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
                    }

                    CircleIcon(
                        systemName: "chart.bar.xaxis",
                        color: color
                    )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
            }
        }
        .buttonStyle(.plain)
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
            background: Color.white.opacity(0.90),
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
                        Text(log.title.isEmpty ? (log.type.isEmpty ? "Log event" : log.type) : log.title)
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(Color(red: 0.063, green: 0.125, blue: 0.200))
                            .lineLimit(2)
                            .multilineTextAlignment(isEnglish ? .leading : .trailing)
                            .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)

                        Text(formatLogTime(log.createdAt, isEnglish: isEnglish))
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Color(red: 0.278, green: 0.333, blue: 0.412))
                            .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
                    }
                }

                if !log.message.isEmpty {
                    Text(log.message)
                        .font(.system(size: 11.5, weight: .medium))
                        .lineSpacing(2)
                        .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                        .lineLimit(3)
                        .multilineTextAlignment(isEnglish ? .leading : .trailing)
                        .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
                }

                Rectangle()
                    .fill(Color(red: 0.796, green: 0.835, blue: 0.882).opacity(0.70))
                    .frame(height: 1)

                Text(metaText)
                    .font(.system(size: 10.5, weight: .semibold))
                    .lineSpacing(2)
                    .foregroundStyle(Color(red: 0.278, green: 0.333, blue: 0.412))
                    .multilineTextAlignment(isEnglish ? .leading : .trailing)
                    .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    private var metaText: String {
        var parts: [String] = []

        parts.append((isEnglish ? "Area: " : "אזור: ") + (log.area.isEmpty ? "-" : log.area))
        parts.append((isEnglish ? "Role: " : "תפקיד: ") + (log.userRole.isEmpty ? "-" : log.userRole))

        if !log.appVersion.isEmpty {
            parts.append((isEnglish ? "Version: " : "גרסה: ") + log.appVersion)
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
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(background)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(border, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(shadowRadius > 0 ? 0.10 : 0.0), radius: shadowRadius, x: 0, y: shadowRadius)
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

    let diff = Date().timeIntervalSince(date)
    let minutes = Int(diff / 60)
    let hours = Int(diff / 3600)
    let days = Int(diff / 86400)

    if minutes < 1 {
        return isEnglish ? "Now" : "עכשיו"
    }

    if minutes < 60 {
        return isEnglish ? "\(minutes) min ago" : "לפני \(minutes) דקות"
    }

    if hours < 24 {
        return isEnglish ? "\(hours) hours ago" : "לפני \(hours) שעות"
    }

    if days < 7 {
        return isEnglish ? "\(days) days ago" : "לפני \(days) ימים"
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "he_IL")
    formatter.dateFormat = "dd/MM/yyyy HH:mm"
    return formatter.string(from: date)
}
