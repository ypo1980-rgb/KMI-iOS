import SwiftUI

enum PaymentStatus: String, CaseIterable, Identifiable {
    case paid
    case unpaid
    case partial

    var id: String { rawValue }
}

enum PaymentMethod: String, CaseIterable, Identifiable {
    case creditCard = "CREDIT_CARD"
    case cash = "CASH"
    case manual = "MANUAL"
    case bankTransfer = "BANK_TRANSFER"
    case bit = "BIT"

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

    init(
        isEnglish: Bool = false,
        initialItems: [PaymentReportItem] = PaymentsReportView.demoItems(),
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
    }

    private var allBranchesText: String {
        isEnglish ? "All Branches" : "כל הסניפים"
    }

    private var branchOptions: [String] {
        [allBranchesText] + Array(Set(items.map(\.branchName))).sorted()
    }

    private var filteredItems: [PaymentReportItem] {
        items.filter { item in
            let matchesQuery =
                query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                item.fullName.localizedCaseInsensitiveContains(query) ||
                item.phone.localizedCaseInsensitiveContains(query) ||
                item.branchName.localizedCaseInsensitiveContains(query)

            let matchesFilter: Bool
            switch filter {
            case "PAID":
                matchesFilter = item.paidAmount >= 150
            case "UNPAID":
                matchesFilter = item.paidAmount < 150
            default:
                matchesFilter = true
            }

            let matchesBranch = selectedBranch == allBranchesText || item.branchName == selectedBranch

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
        items.filter { $0.paidAmount >= 150 }.count
    }

    private var unpaidCount: Int {
        items.filter { $0.paidAmount < 150 }.count
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
                        ForEach(filteredItems) { item in
                            paymentRow(item)
                        }

                        Color.clear.frame(height: 36)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
        .sheet(item: $selectedManualItem) { item in
            ManualPaymentSheet(
                isEnglish: isEnglish,
                item: item,
                onDismiss: { selectedManualItem = nil },
                onSave: { amount, method, notes in
                    saveManualPayment(item: item, amount: amount, method: method, notes: notes)
                }
            )
            .presentationDetents([.medium])
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
                         ? "Collected ₪\(Int(totalPaid)) / ₪\(Int(totalRequired))"
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

                Button(action: onOpenTrainees) {
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

    private func paymentRow(_ item: PaymentReportItem) -> some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: isEnglish ? .leading : .trailing, spacing: 4) {
                    Text(item.fullName)
                        .font(.title3.bold())
                        .foregroundStyle(.white)

                    Text("\(item.branchName) • \(item.phone)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.74))
                        .lineLimit(2)
                }

                Spacer()

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

            if let date = item.paymentDate, !date.isEmpty {
                Text(isEnglish ? "Last update: \(date)" : "עדכון אחרון: \(date)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
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
            return isEnglish ? "Not paid" : "לא שולם"
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

    private func saveManualPayment(item: PaymentReportItem, amount: Double, method: PaymentMethod, notes: String) {
        let newPaidAmount = item.paidAmount + amount

        let newStatus: PaymentStatus
        if newPaidAmount <= 0 {
            newStatus = .unpaid
        } else if newPaidAmount < item.requiredAmount {
            newStatus = .partial
        } else {
            newStatus = .paid
        }

        items = items.map { current in
            guard current.traineeId == item.traineeId else { return current }

            var updated = current
            updated.paidAmount = newPaidAmount
            updated.status = newStatus
            updated.paymentMethod = method
            updated.paymentDate = "10/04/2026"
            updated.notes = notes
            return updated
        }

        onSaveManualPayment(item.traineeId, amount, method, notes)
        selectedManualItem = nil
    }

    static func demoItems() -> [PaymentReportItem] {
        [
            PaymentReportItem(
                traineeId: "1",
                fullName: "יובל פולק",
                branchName: "מרכז קהילתי אופק נתניה",
                phone: "050-000001",
                requiredAmount: 150,
                paidAmount: 150,
                status: .paid,
                paymentMethod: .creditCard,
                paymentDate: "10/04/2026",
                notes: nil
            ),
            PaymentReportItem(
                traineeId: "2",
                fullName: "אריאל הרשקו",
                branchName: "מרכז קהילתי סוקולוב נתניה",
                phone: "050-000002",
                requiredAmount: 150,
                paidAmount: 80,
                status: .partial,
                paymentMethod: .cash,
                paymentDate: "10/04/2026",
                notes: "Partial payment"
            ),
            PaymentReportItem(
                traineeId: "3",
                fullName: "מתן כהן",
                branchName: "מרכז קהילתי אופק נתניה",
                phone: "050-000003",
                requiredAmount: 150,
                paidAmount: 0,
                status: .unpaid,
                paymentMethod: .manual,
                paymentDate: nil,
                notes: nil
            )
        ]
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

                    TextField(isEnglish ? "Amount" : "סכום", text: $amountText)
                        .keyboardType(.decimalPad)

                    Picker(isEnglish ? "Payment Method" : "אמצעי תשלום", selection: $method) {
                        ForEach(PaymentMethod.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }

                    TextField(isEnglish ? "Notes" : "הערות", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle(isEnglish ? "Manual Payment Update" : "עדכון תשלום ידני")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isEnglish ? "Cancel" : "ביטול", action: onDismiss)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEnglish ? "Save" : "שמור") {
                        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
                        guard amount > 0 else { return }
                        onSave(amount, method, notes.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
            }
        }
    }
}

#Preview {
    PaymentsReportView(isEnglish: false)
}
