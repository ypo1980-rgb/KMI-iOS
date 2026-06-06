import SwiftUI
import FirebaseFirestore

private let membershipRequiredAmount: Double = 150.0

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

    var id: String { traineeId }
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
    requiredAmount: Double = membershipRequiredAmount
) -> PaymentStatus {
    if paidAmount <= 0 {
        return .unpaid
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

    func paymentUserName() -> String {
        paymentString(["fullName", "name", "displayName", "email"]) ?? documentID
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

private func loadRealPaymentsReportItems() async throws -> [PaymentReportItem] {
    let db = Firestore.firestore()

    let usersSnapshot = try await db
        .collection("users")
        .getDocuments()

    let usersDocs = usersSnapshot.documents
        .filter { $0.isPaymentRelevantTrainee() }

    let paymentsSnapshot = try await db
        .collection("membershipPayments")
        .getDocuments()

    var paymentDocsByTraineeId: [String: QueryDocumentSnapshot] = [:]

    for doc in paymentsSnapshot.documents {
        let keys = [
            doc.documentID,
            doc.paymentString(["traineeId"]),
            doc.paymentString(["userDocId"]),
            doc.paymentString(["uid"]),
            doc.paymentString(["authUid"])
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        for key in Set(keys) {
            paymentDocsByTraineeId[key] = doc
        }
    }

    func normalizedKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
    }

    func looksLikeUid(_ value: String) -> Bool {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !clean.isEmpty else {
            return true
        }

        if clean.contains("@") {
            return false
        }

        if clean.range(of: #"^[A-Za-z0-9_-]{18,}$"#, options: .regularExpression) != nil {
            return true
        }

        if clean.range(of: #"^[0-9a-fA-F]{20,}$"#, options: .regularExpression) != nil {
            return true
        }

        return false
    }

    func bestHumanName(userDoc: QueryDocumentSnapshot, paymentDoc: QueryDocumentSnapshot?) -> String? {
        let candidates = [
            paymentDoc?.paymentString(["fullName"]),
            userDoc.paymentString(["fullName"]),
            userDoc.paymentString(["name"]),
            userDoc.paymentString(["displayName"])
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .filter { !looksLikeUid($0) }

        return candidates.first
    }

    func bestPhone(userDoc: QueryDocumentSnapshot, paymentDoc: QueryDocumentSnapshot?) -> String {
        paymentDoc?.paymentString(["phone"]) ??
        userDoc.paymentUserPhone()
    }

    func bestEmail(userDoc: QueryDocumentSnapshot, paymentDoc: QueryDocumentSnapshot?) -> String {
        paymentDoc?.paymentString(["email"]) ??
        userDoc.paymentString(["email"]) ??
        ""
    }

    func bestBranch(userDoc: QueryDocumentSnapshot, paymentDoc: QueryDocumentSnapshot?) -> String {
        paymentDoc?.paymentString(["branchName"]) ??
        userDoc.paymentUserBranch()
    }

    func dedupeKey(
        traineeId: String,
        fullName: String,
        phone: String,
        email: String,
        branchName: String
    ) -> String {
        let cleanEmail = normalizedKey(email)
        if !cleanEmail.isEmpty {
            return "email:\(cleanEmail)"
        }

        let cleanPhone = normalizedKey(phone)
        if !cleanPhone.isEmpty {
            return "phone:\(cleanPhone)"
        }

        let cleanName = normalizedKey(fullName)
        let cleanBranch = normalizedKey(branchName)

        if !cleanName.isEmpty {
            return "name:\(cleanName)|branch:\(cleanBranch)"
        }

        return "trainee:\(normalizedKey(traineeId))"
    }

    func betterPaymentItem(_ current: PaymentReportItem, than existing: PaymentReportItem) -> Bool {
        if current.paidAmount != existing.paidAmount {
            return current.paidAmount > existing.paidAmount
        }

        if current.paymentDate?.isEmpty == false && existing.paymentDate?.isEmpty != false {
            return true
        }

        if !current.phone.isEmpty && existing.phone.isEmpty {
            return true
        }

        if !current.branchName.isEmpty && existing.branchName.isEmpty {
            return true
        }

        return current.fullName.count > existing.fullName.count
    }

    var uniqueItemsByKey: [String: PaymentReportItem] = [:]

    for userDoc in usersDocs {
        let traineeId =
            userDoc.paymentString(["uid", "authUid"]) ??
            userDoc.documentID

        let paymentDoc =
            paymentDocsByTraineeId[traineeId] ??
            paymentDocsByTraineeId[userDoc.documentID]

        guard let fullName = bestHumanName(userDoc: userDoc, paymentDoc: paymentDoc) else {
            continue
        }

        let branchName = bestBranch(userDoc: userDoc, paymentDoc: paymentDoc)
        let phone = bestPhone(userDoc: userDoc, paymentDoc: paymentDoc)
        let email = bestEmail(userDoc: userDoc, paymentDoc: paymentDoc)

        let requiredAmount =
            paymentDoc?.paymentDouble(["requiredAmount"]) ??
            membershipRequiredAmount

        let paidAmount =
            paymentDoc?.paymentDouble(["paidAmount"]) ??
            0.0

        let status = paymentStatusFromAmount(
            paidAmount: paidAmount,
            requiredAmount: requiredAmount
        )

        let method = paymentMethodFromString(
            paymentDoc?.paymentString(["paymentMethod"])
        )

        let item = PaymentReportItem(
            traineeId: traineeId,
            fullName: fullName,
            branchName: branchName,
            phone: phone,
            requiredAmount: requiredAmount,
            paidAmount: paidAmount,
            status: status,
            paymentMethod: method,
            paymentDate: paymentDoc?.paymentString(["paymentDate"]),
            notes: paymentDoc?.paymentString(["notes"])
        )

        let key = dedupeKey(
            traineeId: traineeId,
            fullName: fullName,
            phone: phone,
            email: email,
            branchName: branchName
        )

        if let existing = uniqueItemsByKey[key] {
            if betterPaymentItem(item, than: existing) {
                uniqueItemsByKey[key] = item
            }
        } else {
            uniqueItemsByKey[key] = item
        }
    }

    return Array(uniqueItemsByKey.values)
        .sorted {
            if $0.branchName == $1.branchName {
                return $0.fullName < $1.fullName
            }

            return $0.branchName < $1.branchName
        }
}

private func saveManualMembershipPaymentToFirestore(
    item: PaymentReportItem,
    amountToAdd: Double,
    method: PaymentMethod,
    notes: String
) async throws -> PaymentReportItem {
    let db = Firestore.firestore()

    let newPaidAmount = item.paidAmount + amountToAdd
    let newStatus = paymentStatusFromAmount(
        paidAmount: newPaidAmount,
        requiredAmount: item.requiredAmount
    )

    let paymentDate = paymentNowDateText()

    var updatedItem = item
    updatedItem.paidAmount = newPaidAmount
    updatedItem.status = newStatus
    updatedItem.paymentMethod = method
    updatedItem.paymentDate = paymentDate
    updatedItem.notes = notes

    let data: [String: Any] = [
        "traineeId": updatedItem.traineeId,
        "userDocId": updatedItem.traineeId,
        "fullName": updatedItem.fullName,
        "branchName": updatedItem.branchName,
        "phone": updatedItem.phone,
        "requiredAmount": updatedItem.requiredAmount,
        "paidAmount": updatedItem.paidAmount,
        "status": updatedItem.status.rawValue,
        "paymentMethod": method.rawValue,
        "paymentDate": paymentDate,
        "paymentYear": paymentCurrentYear(),
        "lastPaymentAmount": amountToAdd,
        "notes": notes,
        "updatedAt": FieldValue.serverTimestamp(),
        "updatedAtMillis": Int64(Date().timeIntervalSince1970 * 1000),
        "source": "ios_payments_report"
    ]

    let paymentDocRef = db
        .collection("membershipPayments")
        .document(updatedItem.traineeId)

    try await paymentDocRef.setData(data, merge: true)

    let historyData: [String: Any] = [
        "traineeId": updatedItem.traineeId,
        "fullName": updatedItem.fullName,
        "branchName": updatedItem.branchName,
        "amount": amountToAdd,
        "paidAmountAfterUpdate": updatedItem.paidAmount,
        "requiredAmount": updatedItem.requiredAmount,
        "statusAfterUpdate": updatedItem.status.rawValue,
        "paymentMethod": method.rawValue,
        "paymentDate": paymentDate,
        "paymentYear": paymentCurrentYear(),
        "notes": notes,
        "createdAt": FieldValue.serverTimestamp(),
        "createdAtMillis": Int64(Date().timeIntervalSince1970 * 1000),
        "source": "ios_payments_report_history"
    ]

    _ = try await paymentDocRef
        .collection("history")
        .addDocument(data: historyData)

    return updatedItem
}

struct PaymentsReportView: View {
    let isEnglish: Bool
    let onClose: () -> Void
    let onOpenTrainees: () -> Void
    let onSaveManualPayment: (String, Double, PaymentMethod, String) -> Void

    @State private var items: [PaymentReportItem]
    @State private var query: String = ""
    @State private var filter: String = "ALL"
    @State private var selectedBranch: String
    @State private var selectedManualItem: PaymentReportItem?

    @State private var isLoadingPayments = true
    @State private var paymentsError: String?
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

    private var filteredItems: [PaymentReportItem] {
        items.filter { item in
            let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

            let matchesQuery =
                cleanQuery.isEmpty ||
                item.fullName.localizedCaseInsensitiveContains(cleanQuery) ||
                item.phone.localizedCaseInsensitiveContains(cleanQuery) ||
                item.branchName.localizedCaseInsensitiveContains(cleanQuery)

            let matchesFilter: Bool
            switch filter {
            case "PAID":
                matchesFilter = item.paidAmount >= item.requiredAmount
            case "UNPAID":
                matchesFilter = item.paidAmount < item.requiredAmount
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
        items.reduce(0) { $0 + $1.requiredAmount }
    }

    private var totalPaid: Double {
        items.reduce(0) { $0 + $1.paidAmount }
    }

    private var paidCount: Int {
        items.filter { $0.paidAmount >= $0.requiredAmount }.count
    }

    private var unpaidCount: Int {
        items.filter { $0.paidAmount < $0.requiredAmount }.count
    }

    private var collectionPercent: Double {
        guard totalRequired > 0 else { return 0 }
        return min(max((totalPaid / totalRequired) * 100, 0), 100)
    }

    var body: some View {
        ZStack {
            reportBackground

            ScrollView {
                VStack(spacing: 14) {
                    heroCard

                    HStack(spacing: 12) {
                        summaryCard(
                            title: isEnglish ? "Not paid 150" : "לא שילמו",
                            value: "\(unpaidCount)",
                            systemImage: "person.crop.circle.badge.xmark",
                            baseColor: Color(red: 1.0, green: 0.48, blue: 0.35),
                            selectedColor: Color(red: 1.0, green: 0.35, blue: 0.21),
                            selected: filter == "UNPAID"
                        ) {
                            filter = "UNPAID"
                        }

                        summaryCard(
                            title: isEnglish ? "Paid 150" : "שילמו",
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
                            stateMessageCard(
                                title: isEnglish ? "Loading real payment data..." : "טוען נתוני תשלום אמיתיים...",
                                systemImage: "clock.arrow.circlepath",
                                background: Color.white.opacity(0.94),
                                foreground: Color(red: 0.12, green: 0.17, blue: 0.32)
                            )
                        } else if let paymentsError {
                            stateMessageCard(
                                title: isEnglish
                                ? "Failed loading payments: \(paymentsError)"
                                : "טעינת התשלומים נכשלה: \(paymentsError)",
                                systemImage: "exclamationmark.triangle.fill",
                                background: Color(red: 1.0, green: 0.89, blue: 0.91),
                                foreground: Color(red: 0.60, green: 0.10, blue: 0.12)
                            )
                        } else if filteredItems.isEmpty {
                            stateMessageCard(
                                title: isEnglish
                                ? "No trainees matched the current filters."
                                : "לא נמצאו מתאמנים בהתאם לסינון הנוכחי.",
                                systemImage: "person.crop.circle.badge.questionmark",
                                background: Color.white.opacity(0.94),
                                foreground: Color(red: 0.12, green: 0.17, blue: 0.32)
                            )
                        } else {
                            ForEach(filteredItems) { item in
                                paymentRow(item)
                            }
                        }

                        Color.clear.frame(height: 36)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
        .task {
            guard !didLoadPayments else { return }
            didLoadPayments = true
            await loadPayments()
        }
        .onChange(of: allBranchesText) { newValue in
            if selectedBranch != newValue && selectedBranch.isEmpty {
                selectedBranch = newValue
            }
        }
        .sheet(item: $selectedManualItem) { item in
            ManualPaymentSheet(
                isEnglish: isEnglish,
                item: item,
                onDismiss: { selectedManualItem = nil },
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
            paymentsError = error.localizedDescription
            isLoadingPayments = false
        }
    }

    private var reportBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.09, blue: 0.19),
                Color(red: 0.12, green: 0.16, blue: 0.32),
                Color(red: 0.15, green: 0.46, blue: 0.74)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var heroCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: isEnglish ? .leading : .trailing, spacing: 8) {
                    Text(isEnglish ? "Payments Report" : "דו״ח תשלומים")
                        .font(.title.bold())
                        .foregroundStyle(.white)

                    Text(isEnglish ? "Premium payments dashboard for coaches and admins" : "דשבורד תשלומים פרימיום למאמנים ולמנהלים")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.80))

                    Text(isEnglish
                         ? "Collected ₪\(Int(totalPaid)) of ₪\(Int(totalRequired))"
                         : "נגבה \(Int(totalPaid)) ₪ מתוך \(Int(totalRequired)) ₪")
                        .font(.headline)
                        .foregroundStyle(.white)
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Color.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            HStack(spacing: 12) {
                topMetricCard(
                    title: isEnglish ? "Collection" : "אחוז גבייה",
                    value: "\(Int(collectionPercent.rounded()))%",
                    systemImage: "chart.line.uptrend.xyaxis",
                    color: Color(red: 0.11, green: 0.63, blue: 0.95)
                )

                Button {
                    filter = "ALL"
                    onOpenTrainees()
                } label: {
                    topMetricCard(
                        title: isEnglish ? "Trainees" : "מתאמנים",
                        value: "\(items.count)",
                        systemImage: "person.3.fill",
                        color: Color.purple
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(Color(red: 0.17, green: 0.26, blue: 0.45))
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .shadow(color: .black.opacity(0.22), radius: 10, y: 6)
    }

    private var searchFilterCard: some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 12) {
            Text(isEnglish ? "Search & filters" : "חיפוש וסינון")
                .font(.headline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)

            Menu {
                ForEach(branchOptions, id: \.self) { branch in
                    Button(branch) {
                        selectedBranch = branch
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "building.2.fill")

                    Text(selectedBranch)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.down")
                }
                .foregroundStyle(.white)
                .padding()
                .background(Color(red: 0.14, green: 0.21, blue: 0.37))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.70))

                TextField(
                    isEnglish ? "Search by name / phone / branch" : "חיפוש לפי שם / טלפון / סניף",
                    text: $query
                )
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .multilineTextAlignment(isEnglish ? .leading : .trailing)
            }
            .padding()
            .background(Color(red: 0.14, green: 0.21, blue: 0.37))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            HStack(spacing: 8) {
                filterChip(title: isEnglish ? "All\ntrainees" : "כל\nהמתאמנים", key: "ALL")
                filterChip(title: isEnglish ? "Paid\n150" : "שילמו\n150", key: "PAID")
                filterChip(title: isEnglish ? "Not\npaid" : "לא\nשילמו", key: "UNPAID")
            }

            Text(isEnglish ? "Results: \(filteredItems.count)" : "תוצאות: \(filteredItems.count)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.80))
                .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
        }
        .padding(16)
        .background(Color(red: 0.14, green: 0.23, blue: 0.40))
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    private func topMetricCard(title: String, value: String, systemImage: String, color: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 16))

            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)

            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 132)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 24))
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
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(selected ? 0.22 : 0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)

                Text(value)
                    .font(.title.bold())
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 138)
            .background(selected ? selectedColor : baseColor)
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .shadow(color: .black.opacity(selected ? 0.24 : 0.14), radius: selected ? 10 : 6, y: selected ? 6 : 4)
        }
        .buttonStyle(.plain)
    }

    private func filterChip(title: String, key: String) -> some View {
        Button {
            filter = key
        } label: {
            Text(title)
                .font(.caption.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(filter == key ? Color.purple : Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 20))
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
                .font(.title2.bold())

            Text(title)
                .font(.headline.bold())
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func paymentRow(_ item: PaymentReportItem) -> some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: isEnglish ? .leading : .trailing, spacing: 4) {
                    Text(item.fullName)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)

                    Text("\(item.branchName) • \(item.phone)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.74))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
                }

                Spacer(minLength: 10)

                Text(statusLabel(item.status))
                    .font(.caption.bold())
                    .foregroundStyle(statusColor(item.status))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusColor(item.status).opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Divider()
                .background(Color.white.opacity(0.10))

            Text(isEnglish
                 ? "Membership fee: ₪\(Int(item.paidAmount)) / ₪\(Int(item.requiredAmount))"
                 : "דמי חבר: \(Int(item.paidAmount)) ₪ / \(Int(item.requiredAmount)) ₪")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)

            Text(isEnglish
                 ? "Payment method: \(paymentMethodLabel(item.paymentMethod, isEnglish: isEnglish))"
                 : "אמצעי תשלום: \(paymentMethodLabel(item.paymentMethod, isEnglish: isEnglish))")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.70))
                .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)

            if let date = item.paymentDate, !date.isEmpty {
                Text(isEnglish ? "Last update: \(date)" : "עדכון אחרון: \(date)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
                    .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
            }

            Button {
                selectedManualItem = item
            } label: {
                Label(isEnglish ? "Add Membership Payment" : "הוסף דמי חבר", systemImage: "creditcard.and.123")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .padding(16)
        .background(Color(red: 0.16, green: 0.24, blue: 0.40))
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .shadow(color: .black.opacity(0.14), radius: 6, y: 4)
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
        paymentsError = nil

        do {
            let updatedItem = try await saveManualMembershipPaymentToFirestore(
                item: item,
                amountToAdd: amount,
                method: method,
                notes: notes
            )

            items = items.map { current in
                current.traineeId == item.traineeId ? updatedItem : current
            }

            onSaveManualPayment(item.traineeId, amount, method, notes)

            selectedManualItem = nil
        } catch {
            paymentsError = error.localizedDescription
            selectedManualItem = nil
        }
    }
}

private struct ManualPaymentSheet: View {
    let isEnglish: Bool
    let item: PaymentReportItem
    let onDismiss: () -> Void
    let onSave: (Double, PaymentMethod, String) -> Void

    @State private var amountText: String = ""
    @State private var method: PaymentMethod = .manual
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(item.fullName)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)

                    TextField(isEnglish ? "Amount" : "סכום", text: $amountText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(isEnglish ? .leading : .trailing)

                    Picker(isEnglish ? "Payment Method" : "אמצעי תשלום", selection: $method) {
                        ForEach(PaymentMethod.allCases) { option in
                            Text(paymentMethodLabel(option, isEnglish: isEnglish))
                                .tag(option)
                        }
                    }

                    TextField(isEnglish ? "Notes" : "הערות", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                        .multilineTextAlignment(isEnglish ? .leading : .trailing)
                }
            }
            .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
            .navigationTitle(isEnglish ? "Manual Payment Update" : "עדכון תשלום ידני")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isEnglish ? "Cancel" : "ביטול", action: onDismiss)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEnglish ? "Save" : "שמור") {
                        let amount = Double(
                            amountText
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .replacingOccurrences(of: ",", with: ".")
                        ) ?? 0

                        guard amount > 0 else { return }

                        onSave(
                            amount,
                            method,
                            notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    PaymentsReportView(isEnglish: false)
}
