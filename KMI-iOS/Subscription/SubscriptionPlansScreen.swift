import SwiftUI
import StoreKit

struct SubscriptionPlansScreen: View {

    let onBack: () -> Void
    let onOpenHome: () -> Void

    @StateObject private var repo = BillingRepository()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("בחר/י במסלול המתאים לך:")
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)

                    PlanCard(
                        title: "מנוי חודשי מתחדש\n(גישה מלאה לכל התכנים)",
                        priceLine: priceLine(for: .monthly, fallback: "₪25 / חודשי"),
                        points: [
                            "גישה מלאה לכל התכנים באפליקציה",
                            "מתחדש אוטומטית מדי חודש",
                            "ניתן לבטל בכל עת בהתאם למדיניות החנות"
                        ],
                        accent: Color.blue,
                        isLoading: repo.state.isLoading,
                        onBuy: {
                            Task { await repo.purchase(productId: BillingRepository.ProductId.monthly.rawValue) }
                        }
                    )

                    PlanCard(
                        title: "גישה מלאה לכל התכנים",
                        priceLine: priceLine(for: .yearly, fallback: "₪200 / שנתי"),
                        points: [
                            "תשלום חד־שנתי אחד",
                            "ללא חידוש חודשי",
                            "גישה לכל התכנים לאורך כל השנה"
                        ],
                        accent: Color.orange,
                        isLoading: repo.state.isLoading,
                        onBuy: {
                            Task { await repo.purchase(productId: BillingRepository.ProductId.yearly.rawValue) }
                        }
                    )

                    PlanCard(
                        title: "מנוי לפי חגורה",
                        priceLine: priceLine(for: .perBelt, fallback: "מחיר לפי רמת החגורה"),
                        points: [
                            "גישה לתכנים של חגורה אחת לבחירה",
                            "אפשרות שדרוג למנוי מלא בהמשך"
                        ],
                        accent: Color.purple,
                        isLoading: repo.state.isLoading,
                        onBuy: {
                            Task { await repo.purchase(productId: BillingRepository.ProductId.perBelt.rawValue) }
                        }
                    )

                    if let error = repo.state.error, !error.isEmpty {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }

                    Button(action: onBack) {
                        Text("חזרה למסך ניהול המנוי")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)

                Spacer(minLength: 24)
            }
            .padding(16)
        }
        .task {
            repo.start()
        }
    }

    private func priceLine(for id: BillingRepository.ProductId, fallback: String) -> String {
        guard let product = repo.product(for: id.rawValue) else {
            return fallback
        }

        if let sub = product.subscription {
            return "\(product.displayPrice) / \(subscriptionPeriodText(sub.subscriptionPeriod))"
        }

        return product.displayPrice
    }

    private func subscriptionPeriodText(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .day:
            return "יום"
        case .week:
            return "שבוע"
        case .month:
            return period.value == 1 ? "חודשי" : "\(period.value) חודשים"
        case .year:
            return period.value == 1 ? "שנתי" : "\(period.value) שנים"
        @unknown default:
            return "תקופה"
        }
    }
}

private struct PlanCard: View {
    let title: String
    let priceLine: String
    let points: [String]
    let accent: Color
    let isLoading: Bool
    let onBuy: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.title3.weight(.heavy))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)

            Text(priceLine)
                .font(.title3.weight(.heavy))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                ForEach(points, id: \.self) { line in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.95))
                        Spacer()
                        Text(line)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            Button(action: onBuy) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                    Text(isLoading ? "טוען..." : "רכישה מאובטחת")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(accent)
            .disabled(isLoading)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(accent)
        )
    }
}

#Preview {
    SubscriptionPlansScreen(
        onBack: {},
        onOpenHome: {}
    )
}
