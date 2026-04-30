import SwiftUI

struct SubscriptionScreen: View {

    let onBack: () -> Void
    let onOpenPlans: () -> Void
    let onOpenHome: () -> Void

    @StateObject private var repo = BillingRepository()

    @AppStorage("is_manager") private var isManager: Bool = false
    @State private var showDevDialog = false
    @State private var devCode = ""

    var body: some View {
        VStack(spacing: 16) {
            if isManager {
                adminCard
            } else {
                statusCard

                    Button(action: onOpenPlans) {
                        Text("רכוש / הארך מנוי")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: {
                        Task { await repo.restorePurchases() }
                    }) {
                        Text("שחזור רכישות")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .disabled(repo.state.isLoading || !repo.state.connected)

                    Button(action: {
                        showDevDialog = true
                    }) {
                        Text("כניסת מנהל / קוד מפתח")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }

                Spacer()

                Button(action: onOpenHome) {
                    Text("חזרה למסך הבית")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)

            Button(action: onBack) {
                Text("סגור")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .task {
            KmiAccess.ensureTrialStarted()
            repo.start()
        }
        .alert("כניסת מנהל", isPresented: $showDevDialog) {
            SecureField("קוד מנהל", text: $devCode)

            Button("אישור") {
                if devCode == "123456" {
                    isManager = true
                    KmiAccess.setAdmin(true)
                } else if KmiAccess.tryDevUnlock(code: devCode) {
                    // גישת מפתח מלאה בלי מצב מנהל
                }
                devCode = ""
            }

            Button("בטל", role: .cancel) {
                devCode = ""
            }
        } message: {
            Text("הכנס קוד מנהל להפעלת גישה מלאה ללא מנוי.")
        }
    }

    private var statusCard: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Text(repo.state.active ? "המנוי פעיל" : "אין מנוי פעיל")
                .font(.title3.weight(.bold))

            if KmiAccess.hasFullAccess() {
                Text("גישה מלאה: פעילה")
                    .font(.body.weight(.semibold))
            } else if KmiAccess.isTrialActive() {
                Text("ניסיון פעיל: \(KmiAccess.trialDaysLeft()) ימים נותרו")
                    .font(.body.weight(.semibold))
            } else {
                Text("גישה מלאה: כבויה")
                    .font(.body.weight(.semibold))
            }

            Text("מוצר: \(repo.state.productId ?? "-")")
                .font(.body)

            if let token = repo.state.purchaseToken, !token.isEmpty {
                Text("מזהה רכישה: \(token)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let error = repo.state.error, !error.isEmpty {
                Text("שגיאה: \(error)")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var adminCard: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Text("מצב מנוי: מנהל מערכת")
                .font(.title3.weight(.bold))

            Text("כמנהל מערכת כל התכנים באפליקציה פתוחים עבורך ואין צורך ברכישת מנוי.")
                .font(.body)

            Button(action: {
                isManager = false
                KmiAccess.setAdmin(false)
            }) {
                Text("יציאה ממצב מנהל")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    SubscriptionScreen(
        onBack: {},
        onOpenPlans: {},
        onOpenHome: {}
    )
}
