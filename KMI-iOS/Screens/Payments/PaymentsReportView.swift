import SwiftUI
import FirebaseFirestore

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

    func normalizedPhone(
        _ value: String
    ) -> String {
        var digits = value.filter {
            $0.isNumber
        }

        if digits.hasPrefix("00972") {
            digits = String(
                digits.dropFirst(5)
            )

        } else if digits.hasPrefix("972") {
            digits = String(
                digits.dropFirst(3)
            )

        } else if digits.hasPrefix("0") {
            digits = String(
                digits.dropFirst()
            )
        }

        if digits.count >= 9 {
            digits = String(
                digits.suffix(9)
            )
        }

        return digits
    }

    func normalizedEmail(
        _ value: String
    ) -> String {
        value
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()
            .replacingOccurrences(
                of: " ",
                with: ""
            )
    }

    func cleanMergeText(
        _ value: String
    ) -> String {
        value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    func preferredMergeText(
        _ first: String,
        _ second: String
    ) -> String {
        let cleanFirst =
            cleanMergeText(first)

        let cleanSecond =
            cleanMergeText(second)

        if cleanFirst.isEmpty {
            return cleanSecond
        }

        if cleanSecond.isEmpty {
            return cleanFirst
        }

        return cleanSecond.count >
            cleanFirst.count
            ? cleanSecond
            : cleanFirst
    }

    func preferredOptionalMergeText(
        _ first: String?,
        _ second: String?
    ) -> String? {
        let cleanFirst =
            cleanMergeText(first ?? "")

        let cleanSecond =
            cleanMergeText(second ?? "")

        if cleanFirst.isEmpty &&
            cleanSecond.isEmpty {
            return nil
        }

        if cleanFirst.isEmpty {
            return cleanSecond
        }

        if cleanSecond.isEmpty {
            return cleanFirst
        }

        return cleanSecond.count >
            cleanFirst.count
            ? cleanSecond
            : cleanFirst
    }

    func mergePaymentItems(
        existing: PaymentReportItem,
        incoming: PaymentReportItem
    ) -> PaymentReportItem {
        /*
         * לא מחברים סכומים, משום שאותו תשלום
         * עלול להופיע בשני מסמכים כפולים.
         */
        let mergedPaidAmount = max(
            existing.paidAmount,
            incoming.paidAmount
        )

        let mergedRequiredAmount = max(
            existing.requiredAmount,
            incoming.requiredAmount
        )

        let preferredPaymentItem =
            incoming.paidAmount >
            existing.paidAmount
            ? incoming
            : existing

        return PaymentReportItem(
            traineeId:
                existing.traineeId.isEmpty
                ? incoming.traineeId
                : existing.traineeId,

            fullName:
                preferredMergeText(
                    existing.fullName,
                    incoming.fullName
                ),

            branchName:
                preferredMergeText(
                    existing.branchName,
                    incoming.branchName
                ),

            phone:
                preferredMergeText(
                    existing.phone,
                    incoming.phone
                ),

            requiredAmount:
                mergedRequiredAmount,

            paidAmount:
                mergedPaidAmount,

            status:
                paymentStatusFromAmount(
                    paidAmount:
                        mergedPaidAmount,
                    requiredAmount:
                        mergedRequiredAmount
                ),

            paymentMethod:
                preferredPaymentItem
                    .paymentMethod,

            paymentDate:
                preferredOptionalMergeText(
                    existing.paymentDate,
                    incoming.paymentDate
                ),

            notes:
                preferredOptionalMergeText(
                    existing.notes,
                    incoming.notes
                )
        )
    }

    var mergeBuckets:
        [PaymentMergeBucket] = []

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

        let paymentRequiredAmount =
            paymentDoc?
                .paymentRequiredAmountFromAny()
            ?? 0.0

        let userRequiredAmount =
            userDoc
                .paymentRequiredAmountFromAny()

        let requiredAmount =
            paymentRequiredAmount > 0
            ? paymentRequiredAmount
            : userRequiredAmount

        let paidAmount =
            paymentDoc?.paymentDouble(
                ["paidAmount"]
            ) ??
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

        let rawUidValues: [String?] = [
            traineeId,
            userDoc.documentID,
            userDoc.paymentString(
                ["uid"]
            ),
            userDoc.paymentString(
                ["authUid"]
            ),
            paymentDoc?.documentID,
            paymentDoc?.paymentString(
                ["traineeId"]
            ),
            paymentDoc?.paymentString(
                ["userDocId"]
            ),
            paymentDoc?.paymentString(
                ["uid"]
            ),
            paymentDoc?.paymentString(
                ["authUid"]
            )
        ]

        let uidKeys = Set(
            rawUidValues
                .compactMap { $0 }
                .map { normalizedKey($0) }
                .filter { !$0.isEmpty }
        )

        let rawPhoneValues: [String?] = [
            phone,
            userDoc.paymentString(
                ["phone"]
            ),
            userDoc.paymentString(
                ["phoneNumber"]
            ),
            userDoc.paymentString(
                ["phone_number"]
            ),
            paymentDoc?.paymentString(
                ["phone"]
            ),
            paymentDoc?.paymentString(
                ["phoneNumber"]
            ),
            paymentDoc?.paymentString(
                ["phone_number"]
            )
        ]

        let phoneKeys = Set(
            rawPhoneValues
                .compactMap { $0 }
                .map { normalizedPhone($0) }
                .filter { !$0.isEmpty }
        )

        let rawEmailValues: [String?] = [
            email,
            userDoc.paymentString(
                ["email"]
            ),
            userDoc.paymentString(
                ["emailAddress"]
            ),
            userDoc.paymentString(
                ["email_address"]
            ),
            paymentDoc?.paymentString(
                ["email"]
            ),
            paymentDoc?.paymentString(
                ["emailAddress"]
            ),
            paymentDoc?.paymentString(
                ["email_address"]
            )
        ]

        let emailKeys = Set(
            rawEmailValues
                .compactMap { $0 }
                .map { normalizedEmail($0) }
                .filter { !$0.isEmpty }
        )

        var incomingBucket =
            PaymentMergeBucket(
                item: item,
                uidKeys: uidKeys,
                phoneKeys: phoneKeys,
                emailKeys: emailKeys
            )

        /*
         * משתמש חדש יכול לחבר בין יותר משתי רשומות:
         * לדוגמה, מסמך אחד עם אותו טלפון
         * ומסמך אחר עם אותו מייל.
         */
        let matchingIndexes =
            mergeBuckets.indices.filter {
                index in

                let existingBucket =
                    mergeBuckets[index]

                let sameUid =
                    !incomingBucket.uidKeys.isEmpty &&
                    !existingBucket.uidKeys
                        .isDisjoint(
                            with:
                                incomingBucket.uidKeys
                        )

                let samePhone =
                    !incomingBucket.phoneKeys.isEmpty &&
                    !existingBucket.phoneKeys
                        .isDisjoint(
                            with:
                                incomingBucket.phoneKeys
                        )

                let sameEmail =
                    !incomingBucket.emailKeys.isEmpty &&
                    !existingBucket.emailKeys
                        .isDisjoint(
                            with:
                                incomingBucket.emailKeys
                        )

                return sameUid ||
                    samePhone ||
                    sameEmail
            }

        /*
         * מוחקים מהסוף להתחלה כדי שמיקומי
         * המערך לא ישתנו בזמן האיחוד.
         */
        for index in matchingIndexes.reversed() {
            let existingBucket =
                mergeBuckets.remove(
                    at: index
                )

            incomingBucket.item =
                mergePaymentItems(
                    existing:
                        existingBucket.item,
                    incoming:
                        incomingBucket.item
                )

            incomingBucket.uidKeys
                .formUnion(
                    existingBucket.uidKeys
                )

            incomingBucket.phoneKeys
                .formUnion(
                    existingBucket.phoneKeys
                )

            incomingBucket.emailKeys
                .formUnion(
                    existingBucket.emailKeys
                )
        }

        mergeBuckets.append(
            incomingBucket
        )
        }

        return mergeBuckets
            .map(\.item)
            .sorted {
                if $0.branchName ==
                    $1.branchName {
                    return $0.fullName
                        .localizedCaseInsensitiveCompare(
                            $1.fullName
                        ) == .orderedAscending
                }

                return $0.branchName
                    .localizedCaseInsensitiveCompare(
                        $1.branchName
                    ) == .orderedAscending
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

    private var reportBackgroundColors: [Color] {
        isDarkMode
            ? [
                Color(
                    red: 0.015,
                    green: 0.035,
                    blue: 0.075
                ),
                Color(
                    red: 0.04,
                    green: 0.08,
                    blue: 0.15
                ),
                Color(
                    red: 0.06,
                    green: 0.18,
                    blue: 0.31
                ),
                Color(
                    red: 0.02,
                    green: 0.09,
                    blue: 0.18
                )
            ]
            : [
                Color(
                    red: 0.97,
                    green: 0.985,
                    blue: 1.00
                ),
                Color(
                    red: 0.92,
                    green: 0.96,
                    blue: 0.99
                ),
                Color(
                    red: 0.78,
                    green: 0.91,
                    blue: 0.98
                ),
                Color(
                    red: 0.95,
                    green: 0.98,
                    blue: 1.00
                )
            ]
    }

    private var reportPanelColor: Color {
        isDarkMode
            ? Color(
                red: 0.055,
                green: 0.085,
                blue: 0.145
            )
            : Color.white.opacity(0.96)
    }

    private var reportFieldColor: Color {
        isDarkMode
            ? Color(
                red: 0.075,
                green: 0.115,
                blue: 0.19
            )
            : Color(
                red: 0.94,
                green: 0.965,
                blue: 0.99
            )
    }

    private var reportPrimaryTextColor: Color {
        isDarkMode
            ? Color.white.opacity(0.94)
            : Color.black.opacity(0.84)
    }

    private var reportSecondaryTextColor: Color {
        isDarkMode
            ? Color.white.opacity(0.68)
            : Color.black.opacity(0.55)
    }

    private var reportBorderColor: Color {
        isDarkMode
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.09)
    }

    private var reportDividerColor: Color {
        isDarkMode
            ? Color.white.opacity(0.11)
            : Color.black.opacity(0.09)
    }

    private var reportAccentColor: Color {
        Color(
            red: 0.11,
            green: 0.63,
            blue: 0.95
        )
    }

    private var reportErrorBackgroundColor: Color {
        isDarkMode
            ? Color.red.opacity(0.17)
            : Color(
                red: 1.00,
                green: 0.89,
                blue: 0.91
            )
    }

    private var reportErrorTextColor: Color {
        isDarkMode
            ? Color(
                red: 1.00,
                green: 0.66,
                blue: 0.68
            )
            : Color(
                red: 0.60,
                green: 0.10,
                blue: 0.12
            )
    }

    @State private var items: [PaymentReportItem]
    @State private var query: String = ""
    @State private var filter: String = "ALL"
    @State private var selectedBranch: String
    @State private var selectedManualItem: PaymentReportItem?
    @State private var pdfShareItem:
        PaymentsPDFShareItem?

    @State private var isCreatingPDF = false
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
        items.reduce(0) { $0 + $1.requiredAmount }
    }

    private var totalPaid: Double {
        items.reduce(0) { $0 + $1.paidAmount }
    }

    private var paidCount: Int {
        items.filter {
            $0.status == .paid
        }
        .count
    }

    private var unpaidCount: Int {
        items.filter {
            $0.status == .unpaid ||
            $0.status == .partial
        }
        .count
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
                            stateMessageCard(
                                title: isEnglish
                                    ? "Loading real payment data..."
                                    : "טוען נתוני תשלום אמיתיים...",
                                systemImage:
                                    "clock.arrow.circlepath",
                                background: reportPanelColor,
                                foreground:
                                    reportPrimaryTextColor
                            )

                        } else if let paymentsError {
                            stateMessageCard(
                                title: isEnglish
                                    ? "Failed loading payments: \(paymentsError)"
                                    : "טעינת התשלומים נכשלה: \(paymentsError)",
                                systemImage:
                                    "exclamationmark.triangle.fill",
                                background:
                                    reportErrorBackgroundColor,
                                foreground:
                                    reportErrorTextColor
                            )

                        } else if filteredItems.isEmpty {
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
        .onChange(of: allBranchesText) { newValue in
            if selectedBranch != newValue && selectedBranch.isEmpty {
                selectedBranch = newValue
            }
        }
        .sheet(item: $selectedManualItem) { item in
            ManualPaymentSheet(
                isEnglish: isEnglish,
                item: item,
                onDismiss: {
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
            PaymentsPDFShareSheet(
                url: shareItem.url
            )
        }
    }

    @MainActor
    private func createAndSharePaymentsPDF() {
        guard !isCreatingPDF else {
            return
        }

        guard !filteredItems.isEmpty else {
            paymentsError =
                isEnglish
                ? "There are no payment records to export."
                : "אין רשומות תשלום לייצוא."
            return
        }

        isCreatingPDF = true

        do {
            let pdfURL =
                try PaymentsReportPDFGenerator
                    .create(
                        items: filteredItems,
                        totalRequired:
                            filteredItems.reduce(0) {
                                $0 + $1.requiredAmount
                            },
                        totalPaid:
                            filteredItems.reduce(0) {
                                $0 + $1.paidAmount
                            },
                        paidCount:
                            filteredItems.filter {
                                $0.status == .paid
                            }
                            .count,
                        unpaidCount:
                            filteredItems.filter {
                                $0.status == .unpaid ||
                                $0.status == .partial
                            }
                            .count,
                        collectionPercent:
                            filteredCollectionPercent,
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
            paymentsError =
                isEnglish
                ? "Creating the PDF failed: \(error.localizedDescription)"
                : "יצירת דוח ה־PDF נכשלה: \(error.localizedDescription)"
        }

        isCreatingPDF = false
    }

    private var filteredCollectionPercent:
        Double {
        let required =
            filteredItems.reduce(0) {
                $0 + $1.requiredAmount
            }

        let paid =
            filteredItems.reduce(0) {
                $0 + $1.paidAmount
            }

        guard required > 0 else {
            return 0
        }

        return min(
            max(
                (paid / required) * 100,
                0
            ),
            100
        )
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
            colors: reportBackgroundColors,
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var heroCard: some View {
        VStack(spacing: 10) {
            VStack(
                alignment: isEnglish ? .leading : .trailing,
                spacing: 3
            ) {
                Text(
                    isEnglish
                        ? "Premium payments dashboard"
                        : "דשבורד תשלומים פרימיום"
                )
                .kmiFont(size: 17, weight: .heavy)
                .foregroundStyle(reportPrimaryTextColor)
                .frame(
                    maxWidth: .infinity,
                    alignment: screenFrameAlignment
                )
                .multilineTextAlignment(
                    screenTextAlignment
                )
                .lineLimit(2)
                .minimumScaleFactor(0.78)

                Text(
                    isEnglish
                        ? "For trainees, coaches and managers"
                        : "למתאמנים, למאמנים ולמנהלים"
                )
                .kmiFont(size: 13, weight: .regular)
                .foregroundStyle(reportSecondaryTextColor)
                .frame(
                    maxWidth: .infinity,
                    alignment: screenFrameAlignment
                )
                .multilineTextAlignment(
                    screenTextAlignment
                )
                .lineLimit(2)
                .minimumScaleFactor(0.78)

                Text(
                    isEnglish
                        ? "Collected ₪\(Int(totalPaid)) of ₪\(Int(totalRequired))"
                        : "נגבה \(Int(totalPaid)) ₪ מתוך \(Int(totalRequired)) ₪"
                )
                .kmiFont(size: 13, weight: .bold)
                .foregroundStyle(reportAccentColor)
                .frame(
                    maxWidth: .infinity,
                    alignment: screenFrameAlignment
                )
                .multilineTextAlignment(
                    screenTextAlignment
                )
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            }

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
                        value: "\(items.count)",
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
            alignment: isEnglish ? .leading : .trailing,
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

            Menu {
                ForEach(
                    branchOptions,
                    id: \.self
                ) { branch in
                    Button(branch) {
                        selectedBranch = branch
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(
                        systemName:
                            "building.2.fill"
                    )
                    .foregroundStyle(
                        reportAccentColor
                    )

                    Text(selectedBranch)
                        .kmiFont(
                            size: 14,
                            weight: .bold
                        )
                        .foregroundStyle(
                            reportPrimaryTextColor
                        )
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    Spacer(minLength: 8)

                    Image(
                        systemName:
                            "chevron.down"
                    )
                    .foregroundStyle(
                        reportSecondaryTextColor
                    )
                }
                .padding(
                    .horizontal,
                    14
                )
                .frame(minHeight: 54)
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
            }

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
                .font(
                    .system(
                        size: 18,
                        weight: .bold
                    )
                )
                .foregroundStyle(Color.white)
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
                    .font(
                        .system(
                            size: 18,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(Color.white)
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
                .font(
                    .system(
                        size: 24,
                        weight: .bold
                    )
                )

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
        _ item: PaymentReportItem
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
                    Text(item.fullName)
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
                        "\(item.branchName) • \(item.phone)"
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
            .tint(Color.purple)
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
                    Text(item.fullName)
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
                .environment(
                    \.layoutDirection,
                     isEnglish
                     ? .leftToRight
                     : .rightToLeft
                )
                .preferredColorScheme(
                    preferredSheetColorScheme
                )
                .navigationTitle(
                    isEnglish ? "Manual Payment Update" : "עדכון תשלום ידני")
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
}
