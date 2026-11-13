import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseFunctions

enum PaymentStatus: String, CaseIterable, Identifiable {
    case paid = "PAID"
    case unpaid = "UNPAID"
    case partial = "PARTIAL"

    var id: String { rawValue }
}

enum PaymentMethod: String, CaseIterable, Identifiable {
    case creditCard = "CREDIT_CARD"
    case cash = "CASH"
    case manual = "MANUAL"
    case bankTransfer = "BANK_TRANSFER"
    case bit = "BIT"
    case website = "WEBSITE"

    var id: String { rawValue }
}

struct PaymentReportItem: Identifiable, Equatable {
    let traineeId: String
    var fullName: String
    var branchName: String
    var phone: String
    var requiredAmount: Double
    var paidAmount: Double
    var status: PaymentStatus
    var paymentMethod: PaymentMethod
    var paymentDate: String?
    var notes: String?

    var id: String {
        "\(traineeId.utf8.count):\(traineeId)\(branchName)"
    }
}

private struct PaymentMergeBucket {
    var item: PaymentReportItem
    var uidKeys: Set<String>
    var phoneKeys: Set<String>
    var emailKeys: Set<String>
}

private func paymentNowDateText() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd/MM/yyyy"
    formatter.locale = Locale.current
    return formatter.string(from: Date())
}

private func paymentCurrentYear() -> Int {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy"
    formatter.locale = Locale.current
    return Int(formatter.string(from: Date())) ?? 0
}

private func paymentStatusFromAmount(
    paidAmount: Double,
    requiredAmount: Double
) -> PaymentStatus {
    if paidAmount <= 0 {
        return .unpaid
    }

    /*
     * אם לא הוגדר סכום נדרש במסמך התשלום
     * או במסמך המשתמש, תשלום חיובי נחשב כמלא.
     */
    if requiredAmount <= 0 {
        return .paid
    }

    if paidAmount < requiredAmount {
        return .partial
    }

    return .paid
}

private func paymentMethodFromString(_ value: String?) -> PaymentMethod {
    let clean = (value ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .uppercased()

    return PaymentMethod.allCases.first { method in
        method.rawValue.uppercased() == clean
    } ?? .manual
}

private func paymentMethodLabel(_ method: PaymentMethod, isEnglish: Bool) -> String {
    switch method {
    case .cash:
        return isEnglish ? "Cash" : "מזומן"
    case .creditCard:
        return isEnglish ? "Credit card" : "כרטיס אשראי"
    case .bankTransfer:
        return isEnglish ? "Bank transfer" : "העברה בנקאית"
    case .bit:
        return isEnglish ? "Bit" : "ביט"
    case .website:
        return isEnglish ? "Website payment" : "תשלום באתר"
    case .manual:
        return isEnglish ? "Manual" : "ידני"
    }
}

private extension DocumentSnapshot {
    var paymentData: [String: Any] {
        data() ?? [:]
    }

    func paymentString(_ keys: [String]) -> String? {
        for key in keys {
            if let value = paymentData[key] as? String {
                let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty {
                    return clean
                }
            }
        }

        return nil
    }

    func paymentDouble(_ keys: [String]) -> Double? {
        for key in keys {
            let value = paymentData[key]

            if let doubleValue = value as? Double {
                return doubleValue
            }

            if let intValue = value as? Int {
                return Double(intValue)
            }

            if let numberValue = value as? NSNumber {
                return numberValue.doubleValue
            }

            if let stringValue = value as? String {
                let clean = stringValue
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: ",", with: ".")

                if let doubleValue = Double(clean) {
                    return doubleValue
                }
            }
        }

        return nil
    }

    func paymentRequiredAmountFromAny() -> Double {
        paymentDouble(
            [
                "requiredAmount",
                "membershipRequiredAmount",
                "membershipFee",
                "annualMembershipFee",
                "feeAmount"
            ]
        ) ?? 0.0
    }

    func paymentUserName() -> String {
        paymentString(
            [
                "fullName",
                "name",
                "displayName",
                "email"
            ]
        ) ?? documentID
    }

    func paymentUserPhone() -> String {
        paymentString(["phone", "phoneNumber", "phone_number"]) ?? ""
    }

    func paymentUserBranch() -> String {
        if let activeBranch = paymentString(["activeBranch", "active_branch", "branch"]) {
            return activeBranch
        }

        if let branchesCsv = paymentString(["branchesCsv"]) {
            let first = branchesCsv
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty }

            if let first {
                return first
            }
        }

        if let branches = paymentData["branches"] as? [Any] {
            let first = branches
                .compactMap { $0 as? String }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty }

            if let first {
                return first
            }
        }

        return ""
    }

    func isPaymentRelevantTrainee() -> Bool {
        let role = (
            paymentString(["role", "userType", "type"]) ?? ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

        let statusText = (
            paymentString(["status", "active"]) ?? ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

        let isActiveFlag = paymentData["isActive"] as? Bool

        let isActive =
            isActiveFlag != false &&
            statusText != "inactive" &&
            statusText != "disabled" &&
            statusText != "blocked" &&
            statusText != "לא פעיל"

        let isTrainee =
            role.isEmpty ||
            role == "trainee" ||
            role.contains("trainee") ||
            role.contains("student") ||
            role.contains("מתאמן") ||
            role.contains("חניך")

        return isActive && isTrainee
    }
}

private enum PaymentsReportResponseError: Error {
    case invalidReport
    case invalidPayment
}

private func paymentResponseText(_ value: Any?) -> String {
    (value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
}

private func paymentResponseAmount(_ value: Any?) -> Double? {
    guard let number = value as? NSNumber else { return nil }
    let amount = number.doubleValue
    return amount.isFinite ? amount : nil
}

private func paymentResponseRow(
    identity: [String: Any],
    payment: [String: Any],
    fallbackRequiredAmount: Double = 150
) -> PaymentReportItem? {
    let traineeId = paymentResponseText(identity["traineeId"])
    let fullName = paymentResponseText(identity["fullName"])
    guard !traineeId.isEmpty, !fullName.isEmpty else { return nil }

    let rawRequired = paymentResponseAmount(payment["requiredAmount"]) ?? 0
    let required = rawRequired > 0 ? rawRequired : fallbackRequiredAmount
    let paid = max(paymentResponseAmount(payment["paidAmount"]) ?? 0, 0)

    let date = paymentResponseText(payment["paymentDate"])
    let notes = paymentResponseText(payment["notes"])

    return PaymentReportItem(
        traineeId: traineeId,
        fullName: fullName,
        branchName: paymentResponseText(payment["branchName"]),
        phone: paymentResponseText(identity["phone"]),
        requiredAmount: required,
        paidAmount: paid,
        status: paymentStatusFromAmount(paidAmount: paid, requiredAmount: required),
        paymentMethod: paymentMethodFromString(payment["paymentMethod"] as? String),
        paymentDate: date.isEmpty ? nil : date,
        notes: notes.isEmpty ? nil : notes
    )
}

private func loadRealPaymentsReportItems() async throws -> [PaymentReportItem] {
    let result = try await Functions.functions()
        .httpsCallable("loadSecurePaymentsReport")
        .call()

    guard let payload = result.data as? [String: Any],
          let rawItems = payload["items"] as? [[String: Any]] else {
        throw PaymentsReportResponseError.invalidReport
    }

    var rows: [PaymentReportItem] = []
    var seenRowIDs = Set<String>()

    for rawItem in rawItems {
        let branchPayments = (rawItem["branchPayments"] as? [[String: Any]] ?? [])
            .filter { !paymentResponseText($0["branchName"]).isEmpty }

        for payment in branchPayments.isEmpty ? [rawItem] : branchPayments {
            guard let row = paymentResponseRow(identity: rawItem, payment: payment) else {
                throw PaymentsReportResponseError.invalidReport
            }

            guard seenRowIDs.insert(row.id).inserted else {
                throw PaymentsReportResponseError.invalidReport
            }

            rows.append(row)
        }
    }

    return rows.sorted {
        if $0.branchName == $1.branchName {
            return $0.fullName.localizedCaseInsensitiveCompare($1.fullName)
                == .orderedAscending
        }

        return $0.branchName.localizedCaseInsensitiveCompare($1.branchName)
            == .orderedAscending
    }
}

private func normalizedPaymentBranch(_ name: String) -> String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "[־–—]", with: "-", options: .regularExpression)
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .lowercased()
}

private func saveManualMembershipPaymentToFirestore(
    item: PaymentReportItem,
    amountToAdd: Double,
    method: PaymentMethod,
    notes: String,
    requestId: String
) async throws -> PaymentReportItem {
    let branch = item.branchName.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !branch.isEmpty, amountToAdd.isFinite, amountToAdd > 0 else {
        throw PaymentsReportResponseError.invalidPayment
    }

    let result = try await Functions.functions()
        .httpsCallable("updateSecureMembershipPayment")
        .call([
            "traineeId": item.traineeId,
            "branchName": branch,
            "amountToAdd": amountToAdd,
            "paymentMethod": method.rawValue,
            "notes": notes.trimmingCharacters(in: .whitespacesAndNewlines),
            "requestId": requestId
        ] as [String: Any])

    guard let payload = result.data as? [String: Any],
          let rawItem = payload["item"] as? [String: Any],
          normalizedPaymentBranch(paymentResponseText(rawItem["branchName"]))
            == normalizedPaymentBranch(branch),
          let paidAmount = paymentResponseAmount(rawItem["paidAmount"]),
          paidAmount >= 0 else {
        throw PaymentsReportResponseError.invalidPayment
    }

    var updated = item
    let required = paymentResponseAmount(rawItem["requiredAmount"]) ?? 0
    if required > 0 {
        updated.requiredAmount = required
    }
    updated.paidAmount = paidAmount
    updated.status = paymentStatusFromAmount(
        paidAmount: updated.paidAmount,
        requiredAmount: updated.requiredAmount
    )
    updated.paymentMethod = paymentMethodFromString(rawItem["paymentMethod"] as? String)

    let date = paymentResponseText(rawItem["paymentDate"])
    let savedNotes = paymentResponseText(rawItem["notes"])
    updated.paymentDate = date.isEmpty ? nil : date
    updated.notes = savedNotes.isEmpty ? nil : savedNotes
    return updated
}


struct PaymentsReportView: View {
    let isEnglish: Bool
    let onClose: () -> Void
    let onOpenTrainees: () -> Void
    let onSaveManualPayment: (String, Double, PaymentMethod, String) -> Void

    @ObservedObject private var demoPrivacy = DemoPrivacy.shared

    @Environment(\.colorScheme)
    private var colorScheme

    @AppStorage("theme_mode")
    private var themeMode: String = "system"

    private var normalizedThemeMode: String {
        themeMode
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()
    }

    private var preferredScreenColorScheme: ColorScheme? {
        switch normalizedThemeMode {
        case "dark":
            return .dark

        case "light":
            return .light

        default:
            return nil
        }
    }

    private var isDarkMode: Bool {
        switch normalizedThemeMode {
        case "dark":
            return true

        case "light":
            return false

        default:
            return colorScheme == .dark
        }
    }

    /*
     * המסך כבר מקבל RTL בעברית ו־LTR באנגלית.
     * לכן leading הוא הצד הנכון בשתי השפות:
     * ימין בעברית ושמאל באנגלית.
     */
    private var screenFrameAlignment: Alignment {
        .leading
    }

    private var screenTextAlignment: TextAlignment {
        .leading
    }

    private var screenHorizontalAlignment:
        HorizontalAlignment {
        .leading
    }

    private var reportColorScheme: ColorScheme {
        preferredScreenColorScheme ?? colorScheme
    }

    private var reportBackgroundColors: [Color] {
        KmiAppTheme.screenBackgroundColors(for: reportColorScheme)
    }

    private var reportPanelColor: Color {
        KmiAppTheme.surface(for: reportColorScheme)
    }

    private var reportFieldColor: Color {
        KmiAppTheme.surfaceVariant(for: reportColorScheme)
    }

    private var reportPrimaryTextColor: Color {
        KmiAppTheme.onSurface(for: reportColorScheme)
    }

    private var reportSecondaryTextColor: Color {
        KmiAppTheme.onSurfaceVariant(for: reportColorScheme)
    }

    private var reportBorderColor: Color {
        KmiAppTheme.outlineVariant(for: reportColorScheme)
    }

    private var reportDividerColor: Color {
        reportBorderColor
    }

    private var reportAccentColor: Color {
        KmiAppTheme.primary(for: reportColorScheme)
    }

    private var reportErrorBackgroundColor: Color {
        KmiAppTheme.errorContainer(for: reportColorScheme)
    }

    private var reportErrorTextColor: Color {
        KmiAppTheme.onErrorContainer(for: reportColorScheme)
    }

    @State private var items: [PaymentReportItem]
    @State private var query: String = ""
    @State private var filter: String = "ALL"
    @State private var selectedBranch: String
    @State private var selectedManualItem: PaymentReportItem?
    @State private var manualPaymentRequestID = UUID()
    @State private var isSavingManualPayment = false
    @State private var pdfShareItem:
        PaymentsPDFShareItem?

    @State private var isCreatingPDF = false
    @State private var isLoadingPayments = true
    @State private var paymentsError: String?
    @State private var exportError: String?
    @State private var didLoadPayments = false

    init(
        isEnglish: Bool = false,
        initialItems: [PaymentReportItem] = [],
        onClose: @escaping () -> Void = {},
        onOpenTrainees: @escaping () -> Void = {},
        onSaveManualPayment: @escaping (String, Double, PaymentMethod, String) -> Void = { _, _, _, _ in }
    ) {
        self.isEnglish = isEnglish
        self.onClose = onClose
        self.onOpenTrainees = onOpenTrainees
        self.onSaveManualPayment = onSaveManualPayment

        _items = State(initialValue: initialItems)
        _selectedBranch = State(initialValue: isEnglish ? "All Branches" : "כל הסניפים")
        _isLoadingPayments = State(initialValue: initialItems.isEmpty)
    }

    private var allBranchesText: String {
        isEnglish ? "All Branches" : "כל הסניפים"
    }

    private var branchOptions: [String] {
        let realBranches = Array(
            Set(
                items
                    .map { $0.branchName.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        )
        .sorted()

        return [allBranchesText] + realBranches
    }

    private var demoNamesByTraineeID: [String: String] {
        guard demoPrivacy.isEnabled else { return [:] }

        var names: [String: String] = [:]

        for item in items where names[item.traineeId] == nil {
            names[item.traineeId] = TraineeDisplayNameMapper.displayName(
                realName: item.fullName,
                stableKey: item.traineeId,
                demoIndex: names.count,
                isEnglish: isEnglish
            )
        }

        return names
    }

    private func paymentDisplayName(
        _ item: PaymentReportItem,
        demoNames: [String: String]
    ) -> String {
        guard demoPrivacy.isEnabled else { return item.fullName }

        return demoNames[item.traineeId]
            ?? (isEnglish ? "Trainee" : "מתאמן")
    }

    private var filteredItems: [PaymentReportItem] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let demoNames = demoNamesByTraineeID

        return items.filter { item in
            let displayName = paymentDisplayName(item, demoNames: demoNames)
            let matchesQuery =
                cleanQuery.isEmpty ||
                displayName.localizedCaseInsensitiveContains(cleanQuery) ||
                (!demoPrivacy.isEnabled &&
                    item.phone.localizedCaseInsensitiveContains(cleanQuery)) ||
                item.branchName.localizedCaseInsensitiveContains(cleanQuery)

            let matchesFilter: Bool

            switch filter {
            case "PAID":
                matchesFilter =
                    item.status == .paid

            case "UNPAID":
                /*
                 * “לא שילמו” כולל גם מי שלא שילם כלל
                 * וגם מי ששילם סכום חלקי.
                 */
                matchesFilter =
                    item.status == .unpaid ||
                    item.status == .partial

            default:
                matchesFilter = true
            }

            let matchesBranch =
                selectedBranch == allBranchesText ||
                item.branchName == selectedBranch

            return matchesQuery && matchesFilter && matchesBranch
        }
    }

    private var totalRequired: Double {
        filteredItems.reduce(0) { $0 + $1.requiredAmount }
    }

    private var totalPaid: Double {
        filteredItems.reduce(0) { $0 + $1.paidAmount }
    }

    private var paidCount: Int {
        filteredItems.filter { $0.status == .paid }.count
    }

    private var unpaidCount: Int {
        filteredItems.filter {
            $0.status == .unpaid || $0.status == .partial
        }.count
    }

    private var collectionPercent: Double {
        let required = totalRequired
        guard required > 0 else { return 0 }
        return min(max((totalPaid / required) * 100, 0), 100)
    }

    var body: some View {
        ZStack {
            reportBackground

            ScrollView {
                VStack(spacing: 14) {
                    heroCard

                    HStack(spacing: 12) {
                        summaryCard(
                            title: isEnglish
                                ? "Not paid"
                                : "לא שילמו",
                            value: "\(unpaidCount)",
                            systemImage:
                                "person.crop.circle.badge.xmark",
                            baseColor: Color(red: 1.0, green: 0.48, blue: 0.35),
                            selectedColor: Color(red: 1.0, green: 0.35, blue: 0.21),
                            selected: filter == "UNPAID"
                        ) {
                            filter = "UNPAID"
                        }

                        summaryCard(
                            title: isEnglish
                                ? "Paid"
                                : "שילמו",
                            value: "\(paidCount)",
                            systemImage: "checkmark.seal.fill",
                            baseColor: Color(red: 0.13, green: 0.77, blue: 0.37),
                            selectedColor: Color(red: 0.09, green: 0.64, blue: 0.29),
                            selected: filter == "PAID"
                        ) {
                            filter = "PAID"
                        }
                    }

                    searchFilterCard

                    LazyVStack(spacing: 10) {
                        if isLoadingPayments {
                            KmiLoadingOverlay()
                                .frame(maxWidth: .infinity)
                                .frame(height: 112)
                                .accessibilityLabel(
                                    isEnglish
                                        ? "Loading payment data"
                                        : "טוען נתוני תשלומים"
                                )
                        }

                        if !isLoadingPayments, let paymentsError {
                            stateMessageCard(
                                title: paymentsError,
                                systemImage: "exclamationmark.triangle.fill",
                                background: reportErrorBackgroundColor,
                                foreground: reportErrorTextColor
                            )

                            Button {
                                Task { await loadPayments() }
                            } label: {
                                Label(
                                    isEnglish ? "Reload Payments" : "טען תשלומים מחדש",
                                    systemImage: "arrow.clockwise"
                                )
                                .kmiFont(size: 14, weight: .bold)
                            }
                            .buttonStyle(.bordered)
                            .tint(reportAccentColor)
                        }

                        if !isLoadingPayments {
                            if filteredItems.isEmpty {
                                if paymentsError == nil {
                            stateMessageCard(
                                title: isEnglish
                                    ? "No trainees matched the current filters."
                                    : "לא נמצאו מתאמנים בהתאם לסינון הנוכחי.",
                                systemImage:
                                    "person.crop.circle.badge.questionmark",
                                background: reportPanelColor,
                                foreground:
                                    reportPrimaryTextColor
                            )

                                }
                            } else {
                                let demoNames = demoNamesByTraineeID

                                ForEach(filteredItems) { item in
                                    paymentRow(
                                        item,
                                        displayName: paymentDisplayName(item, demoNames: demoNames)
                                    )
                                }
                            }
                        }

                        Color.clear.frame(height: 36)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 1) {
                Text(
                    isEnglish
                        ? "Premium payments dashboard"
                        : "דשבורד תשלומים פרימיום"
                )
                .kmiFont(size: 14, weight: .bold)
                .accessibilityAddTraits(.isHeader)

                Text(
                    isEnglish
                        ? "For trainees, coaches and managers"
                        : "למתאמנים, למאמנים ולמנהלים"
                )
                .kmiFont(size: 12, weight: .regular)
            }
            .foregroundStyle(KmiAppTheme.sectionHeaderContentColor)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(KmiAppTheme.sectionHeaderBrush)
        }
        .environment(
            \.layoutDirection,
            isEnglish ? .leftToRight : .rightToLeft
        )
        .preferredColorScheme(
            preferredScreenColorScheme
        )
        .task {
            guard !didLoadPayments else { return }
            didLoadPayments = true
            await loadPayments()
        }
        .onChange(of: allBranchesText) { previousValue, newValue in
            if selectedBranch == previousValue || selectedBranch.isEmpty {
                selectedBranch = newValue
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("KMI_PAYMENTS_REPORT_SHARE_PDF")
            )
        ) { _ in
            guard !isLoadingPayments,
                  !filteredItems.isEmpty,
                  selectedManualItem == nil,
                  pdfShareItem == nil else {
                return
            }

            createAndSharePaymentsPDF()
        }
        .sheet(item: $selectedManualItem) { item in
            ManualPaymentSheet(
                isEnglish: isEnglish,
                item: item,
                displayName: paymentDisplayName(item, demoNames: demoNamesByTraineeID),
                isSaving: isSavingManualPayment,
                onDismiss: {
                    guard !isSavingManualPayment else { return }
                    selectedManualItem = nil
                },
                onSave: { amount, method, notes in
                    Task {
                        await saveManualPayment(
                            item: item,
                            amount: amount,
                            method: method,
                            notes: notes
                        )
                    }
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(item: $pdfShareItem) { shareItem in
            KmiShareSheet(items: [shareItem.url])
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert(
            isEnglish ? "PDF Export" : "ייצוא PDF",
            isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            ),
            presenting: exportError
        ) { _ in
            Button(isEnglish ? "OK" : "אישור", role: .cancel) {
                exportError = nil
            }
        } message: { message in
            Text(message)
        }
    }

    @MainActor
    private func createAndSharePaymentsPDF() {
        guard !isCreatingPDF else {
            return
        }

        guard !filteredItems.isEmpty else {
            exportError = isEnglish
                ? "There are no payment records to export."
                : "אין רשומות תשלום לייצוא."
            return
        }

        isCreatingPDF = true

        let demoNames = demoNamesByTraineeID
        let exportItems = filteredItems.map { item in
            guard demoPrivacy.isEnabled else { return item }

            var displayItem = item
            displayItem.fullName = paymentDisplayName(item, demoNames: demoNames)
            displayItem.phone = ""
            displayItem.notes = nil
            return displayItem
        }

        do {
            let pdfURL =
                try PaymentsReportPDFGenerator
                    .create(
                        items: exportItems,
                        totalRequired: totalRequired,
                        totalPaid: totalPaid,
                        paidCount: paidCount,
                        unpaidCount: unpaidCount,
                        collectionPercent: collectionPercent,
                        selectedBranch:
                            selectedBranch,
                        isEnglish:
                            isEnglish
                    )

            pdfShareItem =
                PaymentsPDFShareItem(
                    url: pdfURL
                )

        } catch {
            exportError = isEnglish
                ? "Could not create the PDF. Please try again."
                : "לא ניתן ליצור את דוח ה־PDF. יש לנסות שוב."
        }

        isCreatingPDF = false
    }

    @MainActor
    private func loadPayments() async {
        isLoadingPayments = true
        paymentsError = nil

        do {
            let realItems = try await loadRealPaymentsReportItems()
            items = realItems
            isLoadingPayments = false

            if !branchOptions.contains(selectedBranch) {
                selectedBranch = allBranchesText
            }
        } catch {
            paymentsError = isEnglish
                ? "Unable to load payments. Please try again."
                : "לא ניתן לטעון את התשלומים. יש לנסות שוב."
            isLoadingPayments = false
        }
    }

    private var reportBackground: some View {
        LinearGradient(
            colors: reportBackgroundColors,
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var heroCard: some View {
        VStack(spacing: 10) {
            Text(
                isEnglish
                    ? "Collected ₪\(Int(totalPaid)) of ₪\(Int(totalRequired))"
                    : "נגבה \(Int(totalPaid)) ₪ מתוך \(Int(totalRequired)) ₪"
            )
            .kmiFont(size: 13, weight: .bold)
            .foregroundStyle(reportAccentColor)
            .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
            .multilineTextAlignment(screenTextAlignment)

            Button {
                createAndSharePaymentsPDF()
            } label: {
                HStack(spacing: 8) {
                    if isCreatingPDF {
                        ProgressView()
                            .tint(Color.white)
                    } else {
                        Image(
                            systemName:
                                "square.and.arrow.up"
                        )
                    }

                    Text(
                        isEnglish
                            ? "Create and share PDF"
                            : "יצירה ושיתוף דוח PDF"
                    )
                    .kmiFont(
                        size: 13,
                        weight: .bold
                    )
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(
                    .horizontal,
                    12
                )
                .padding(
                    .vertical,
                    11
                )
                .background(
                    RoundedRectangle(
                        cornerRadius: 15,
                        style: .continuous
                    )
                    .fill(reportAccentColor)
                )
            }
            .buttonStyle(.plain)
            .disabled(
                isCreatingPDF ||
                filteredItems.isEmpty
            )
            .opacity(
                filteredItems.isEmpty
                    ? 0.55
                    : 1.0
            )

            HStack(spacing: 12) {
                topMetricCard(
                    title: isEnglish
                        ? "Collection"
                        : "אחוז גבייה",
                    value:
                        "\(Int(collectionPercent.rounded()))%",
                    systemImage:
                        "chart.line.uptrend.xyaxis",
                    color: Color(
                        red: 0.11,
                        green: 0.63,
                        blue: 0.95
                    )
                )

                Button {
                    filter = "ALL"
                    onOpenTrainees()
                } label: {
                    topMetricCard(
                        title: isEnglish
                            ? "Trainees"
                            : "מתאמנים",
                        value: "\(Set(items.map(\.traineeId)).count)",
                        systemImage: "person.3.fill",
                        color: Color.purple
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(
            .horizontal,
            14
        )
        .padding(
            .vertical,
            10
        )
        .background(reportPanelColor)
        .overlay(
            RoundedRectangle(
                cornerRadius: 30,
                style: .continuous
            )
            .stroke(
                reportBorderColor,
                lineWidth: 1
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 30,
                style: .continuous
            )
        )
        .shadow(
            color: Color.black.opacity(
                isDarkMode ? 0.24 : 0.10
            ),
            radius: 8,
            x: 0,
            y: 5
        )
    }

    private var searchFilterCard: some View {
        VStack(
            alignment: screenHorizontalAlignment,
            spacing: 12
        ) {
            Text(
                isEnglish
                    ? "Search & filters"
                    : "חיפוש וסינון"
            )
            .kmiFont(size: 15, weight: .heavy)
            .foregroundStyle(reportPrimaryTextColor)
            .frame(
                maxWidth: .infinity,
                alignment: screenFrameAlignment
            )
            .multilineTextAlignment(
                screenTextAlignment
            )

            KmiPremiumDropdown(
                title: isEnglish ? "Branch" : "סניף",
                options: branchOptions,
                selectedValue: $selectedBranch,
                placeholder: allBranchesText,
                isEnglish: isEnglish,
                isEnabled: !isLoadingPayments && branchOptions.count > 1,
                labelForOption: { branch in
                    if branch == allBranchesText {
                        return branch
                    }

                    return TrainingCatalogIOS.displayBranch(
                        branch,
                        isEnglish: isEnglish
                    )
                },
                titleInsideField: true
            )

            HStack(spacing: 10) {
                Image(
                    systemName:
                        "magnifyingglass"
                )
                .foregroundStyle(
                    reportSecondaryTextColor
                )

                TextField(
                    isEnglish
                        ? "Search by name / phone / branch"
                        : "חיפוש לפי שם / טלפון / סניף",
                    text: $query
                )
                .kmiFont(
                    size: 13,
                    weight: .regular
                )
                .foregroundStyle(
                    reportPrimaryTextColor
                )
                .textInputAutocapitalization(
                    .never
                )
                .multilineTextAlignment(
                    screenTextAlignment
                )
            }
            .padding(
                .horizontal,
                14
            )
            .frame(minHeight: 56)
            .background(reportFieldColor)
            .overlay(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .stroke(
                    reportBorderColor,
                    lineWidth: 1
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
            )

            HStack(spacing: 8) {
                filterChip(
                    title: isEnglish
                        ? "All\ntrainees"
                        : "כל\nהמתאמנים",
                    key: "ALL"
                )

                filterChip(
                    title: isEnglish
                        ? "Paid"
                        : "שילמו",
                    key: "PAID"
                )

                filterChip(
                    title: isEnglish
                        ? "Not\npaid"
                        : "לא\nשילמו",
                    key: "UNPAID"
                )
            }

            Text(
                isEnglish
                    ? "Results: \(filteredItems.count)"
                    : "תוצאות: \(filteredItems.count)"
            )
            .kmiFont(size: 12, weight: .regular)
            .foregroundStyle(
                reportSecondaryTextColor
            )
            .frame(
                maxWidth: .infinity,
                alignment: screenFrameAlignment
            )
            .multilineTextAlignment(
                screenTextAlignment
            )
        }
        .padding(16)
        .background(reportPanelColor)
        .overlay(
            RoundedRectangle(
                cornerRadius: 28,
                style: .continuous
            )
            .stroke(
                reportBorderColor,
                lineWidth: 1
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 28,
                style: .continuous
            )
        )
    }

    private func topMetricCard(
        title: String,
        value: String,
        systemImage: String,
        color: Color
    ) -> some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .kmiIconSize(18)
                .foregroundStyle(Color.white)
                .accessibilityHidden(true)
                .frame(
                    width: 32,
                    height: 32
                )
                .background(
                    Color.white.opacity(0.18)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
                )

            Text(title)
                .kmiFont(size: 12, weight: .bold)
                .foregroundStyle(
                    Color.white.opacity(0.86)
                )
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(.center)

            Text(value)
                .kmiFont(size: 18, weight: .heavy)
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 96)
        .padding(
            .horizontal,
            6
        )
        .background(color)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }

    private func summaryCard(
        title: String,
        value: String,
        systemImage: String,
        baseColor: Color,
        selectedColor: Color,
        selected: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .kmiIconSize(18)
                    .foregroundStyle(Color.white)
                    .accessibilityHidden(true)
                    .frame(
                        width: 32,
                        height: 32
                    )
                    .background(
                        Color.white.opacity(
                            selected ? 0.24 : 0.17
                        )
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 12,
                            style: .continuous
                        )
                    )

                Text(title)
                    .kmiFont(size: 12, weight: .bold)
                    .foregroundStyle(
                        Color.white.opacity(0.88)
                    )
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Text(value)
                    .kmiFont(size: 18, weight: .heavy)
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 96)
            .padding(
                .horizontal,
                6
            )
            .background(
                selected
                    ? selectedColor
                    : baseColor
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 20,
                    style: .continuous
                )
            )
            .shadow(
                color: Color.black.opacity(
                    selected ? 0.22 : 0.10
                ),
                radius: selected ? 8 : 4,
                x: 0,
                y: selected ? 5 : 3
            )
        }
        .buttonStyle(.plain)
    }

    private func filterChip(
        title: String,
        key: String
    ) -> some View {
        let isSelected = filter == key

        return Button {
            filter = key
        } label: {
            Text(title)
                .kmiFont(size: 12, weight: .bold)
                .multilineTextAlignment(.center)
                .foregroundStyle(
                    isSelected
                        ? Color.white
                        : reportPrimaryTextColor
                )
                .frame(maxWidth: .infinity)
                .frame(minHeight: 54)
                .padding(
                    .horizontal,
                    5
                )
                .background(
                    isSelected
                        ? Color.purple
                        : reportFieldColor
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                    .stroke(
                        isSelected
                            ? Color.purple.opacity(0.85)
                            : reportBorderColor,
                        lineWidth: 1
                    )
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private func stateMessageCard(
        title: String,
        systemImage: String,
        background: Color,
        foreground: Color
    ) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .kmiIconSize(24)
                .accessibilityHidden(true)

            Text(title)
                .kmiFont(size: 15, weight: .bold)
                .multilineTextAlignment(.center)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(background)
        .overlay(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .stroke(
                reportBorderColor,
                lineWidth: 1
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
        )
    }

    private func paymentRow(
        _ item: PaymentReportItem,
        displayName: String
    ) -> some View {
        VStack(
            alignment:
                screenHorizontalAlignment,
            spacing: 12
        ) {
            HStack(
                alignment: .top,
                spacing: 10
            ) {
                VStack(
                    alignment:
                        screenHorizontalAlignment,
                    spacing: 4
                ) {
                    Text(displayName)
                        .kmiFont(
                            size: 17,
                            weight: .heavy
                        )
                        .foregroundStyle(
                            reportPrimaryTextColor
                        )
                        .frame(
                            maxWidth: .infinity,
                            alignment:
                                screenFrameAlignment
                        )
                        .multilineTextAlignment(
                            screenTextAlignment
                        )
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    Text(
                        demoPrivacy.isEnabled || item.phone.isEmpty
                            ? item.branchName
                            : "\(item.branchName) • \(item.phone)"
                    )
                    .kmiFont(
                        size: 13,
                        weight: .regular
                    )
                    .foregroundStyle(
                        reportSecondaryTextColor
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment:
                            screenFrameAlignment
                    )
                    .multilineTextAlignment(
                        screenTextAlignment
                    )
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
                }

                Text(
                    statusLabel(item.status)
                )
                .kmiFont(size: 11, weight: .bold)
                .foregroundStyle(
                    statusColor(item.status)
                )
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .padding(
                    .horizontal,
                    10
                )
                .padding(
                    .vertical,
                    6
                )
                .background(
                    statusColor(item.status)
                        .opacity(
                            isDarkMode
                                ? 0.20
                                : 0.13
                        )
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 14,
                        style: .continuous
                    )
                )
            }

            Divider()
                .overlay(
                    reportDividerColor
                )

            Text(
                isEnglish
                    ? "Membership fee: ₪\(Int(item.paidAmount)) / ₪\(Int(item.requiredAmount))"
                    : "דמי חבר: \(Int(item.paidAmount)) ₪ / \(Int(item.requiredAmount)) ₪"
            )
            .kmiFont(size: 15, weight: .bold)
            .foregroundStyle(
                reportPrimaryTextColor
            )
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
                    ? "Payment method: \(paymentMethodLabel(item.paymentMethod, isEnglish: isEnglish))"
                    : "אמצעי תשלום: \(paymentMethodLabel(item.paymentMethod, isEnglish: isEnglish))"
            )
            .kmiFont(size: 12, weight: .regular)
            .foregroundStyle(
                reportSecondaryTextColor
            )
            .frame(
                maxWidth: .infinity,
                alignment: screenFrameAlignment
            )
            .multilineTextAlignment(
                screenTextAlignment
            )

            if let date = item.paymentDate,
               !date.isEmpty {
                Text(
                    isEnglish
                        ? "Last update: \(date)"
                        : "עדכון אחרון: \(date)"
                )
                .kmiFont(
                    size: 12,
                    weight: .regular
                )
                .foregroundStyle(
                    reportSecondaryTextColor
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: screenFrameAlignment
                )
                .multilineTextAlignment(
                    screenTextAlignment
                )
            }

            Button {
                manualPaymentRequestID = UUID()
                selectedManualItem = item
            } label: {
                Label(
                    isEnglish
                        ? "Add Membership Payment"
                        : "הוסף דמי חבר",
                    systemImage:
                        "creditcard.and.123"
                )
                .kmiFont(size: 14, weight: .bold)
                .frame(maxWidth: .infinity)
                .padding(
                    .horizontal,
                    10
                )
                .padding(
                    .vertical,
                    11
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(reportAccentColor)
            .disabled(item.branchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .background(reportPanelColor)
        .overlay(
            RoundedRectangle(
                cornerRadius: 26,
                style: .continuous
            )
            .stroke(
                reportBorderColor,
                lineWidth: 1
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 26,
                style: .continuous
            )
        )
        .shadow(
            color: Color.black.opacity(
                isDarkMode ? 0.18 : 0.08
            ),
            radius: 6,
            x: 0,
            y: 4
        )
    }

    private func statusLabel(_ status: PaymentStatus) -> String {
        switch status {
        case .paid:
            return isEnglish ? "Paid" : "שולם"
        case .unpaid:
            return isEnglish ? "Unpaid" : "לא שולם"
        case .partial:
            return isEnglish ? "Partial" : "שולם חלקית"
        }
    }

    private func statusColor(_ status: PaymentStatus) -> Color {
        switch status {
        case .paid:
            return Color(red: 0.40, green: 0.82, blue: 0.48)
        case .unpaid:
            return Color(red: 1.0, green: 0.48, blue: 0.48)
        case .partial:
            return Color(red: 1.0, green: 0.78, blue: 0.34)
        }
    }

    @MainActor
    private func saveManualPayment(
        item: PaymentReportItem,
        amount: Double,
        method: PaymentMethod,
        notes: String
    ) async {
        guard !isSavingManualPayment else { return }

        isSavingManualPayment = true
        paymentsError = nil
        defer { isSavingManualPayment = false }

        do {
            let updatedItem = try await saveManualMembershipPaymentToFirestore(
                item: item,
                amountToAdd: amount,
                method: method,
                notes: notes,
                requestId: manualPaymentRequestID.uuidString
            )

            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index] = updatedItem
            }

            onSaveManualPayment(item.traineeId, amount, method, notes)
            selectedManualItem = nil
        } catch {
            selectedManualItem = nil
            await loadPayments()
            paymentsError = isEnglish
                ? "Could not confirm the payment. Check the branch balance before adding it again."
                : "לא ניתן לאשר את התשלום. יש לבדוק את היתרה בסניף לפני הזנה חוזרת."
        }
    }
}

private struct ManualPaymentSheet: View {
    let isEnglish: Bool
    let item: PaymentReportItem
    let displayName: String
    let isSaving: Bool
    let onDismiss: () -> Void
    let onSave: (Double, PaymentMethod, String) -> Void
    
    @Environment(\.colorScheme)
    private var colorScheme
    
    @AppStorage("theme_mode")
    private var themeMode: String = "system"
    
    private var normalizedThemeMode: String {
        themeMode
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()
    }
    
    private var preferredSheetColorScheme: ColorScheme? {
        switch normalizedThemeMode {
        case "dark":
            return .dark
            
        case "light":
            return .light
            
        default:
            return nil
        }
    }
    
    @State private var amountText: String = ""
    @State private var method: PaymentMethod = .manual
    @State private var notes: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(displayName)
                        .kmiFont(size: 17, weight: .bold)
                        .frame(
                            maxWidth: .infinity,
                            alignment:
                                isEnglish
                            ? .leading
                            : .trailing
                        )
                        .multilineTextAlignment(
                            isEnglish
                            ? .leading
                            : .trailing
                        )
                    
                    LabeledContent(isEnglish ? "Branch" : "סניף") {
                        Text(TrainingCatalogIOS.displayBranch(item.branchName, isEnglish: isEnglish))
                            .kmiFont(size: 14, weight: .semibold)
                    }

                    TextField(
                        isEnglish
                        ? "Amount"
                        : "סכום",
                        text: $amountText
                    )
                    .kmiFont(size: 15, weight: .regular)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(
                        isEnglish
                        ? .leading
                        : .trailing
                    )
                    
                    Picker(isEnglish ? "Payment Method" : "אמצעי תשלום", selection: $method) {
                        ForEach(PaymentMethod.allCases) { option in
                            Text(paymentMethodLabel(option, isEnglish: isEnglish))
                                .tag(option)
                        }
                    }
                    
                    TextField(
                        isEnglish
                        ? "Notes"
                        : "הערות",
                        text: $notes,
                        axis: .vertical
                    )
                    .kmiFont(size: 15, weight: .regular)
                    .lineLimit(3...5)
                    .multilineTextAlignment(
                        isEnglish
                        ? .leading
                        : .trailing
                    )
                }
                .disabled(isSaving)
                .interactiveDismissDisabled(isSaving)
                .environment(
                    \.layoutDirection,
                    isEnglish ? .leftToRight : .rightToLeft
                )
                .preferredColorScheme(
                    preferredSheetColorScheme
                )
                .navigationTitle(
                    isEnglish ? "Manual Payment Update" : "עדכון תשלום ידני")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(isEnglish ? "Cancel" : "ביטול", action: onDismiss)
                            .disabled(isSaving)
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isEnglish ? "Save" : "שמור") {
                            let amount = Double(
                                amountText
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                    .replacingOccurrences(of: ",", with: ".")
                            ) ?? 0
                            
                            guard !isSaving, amount.isFinite, amount > 0 else { return }

                            onSave(
                                amount,
                                method,
                                notes.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        }
                        .disabled(isSaving)
                    }
                }
            }
        }
    }
    
    #Preview {
        PaymentsReportView(isEnglish: false)
    }
}
