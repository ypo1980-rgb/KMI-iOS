import SwiftUI
import StoreKit

struct SubscriptionPlansScreen: View {

    let onBack: () -> Void
    let onOpenHome: () -> Void

    @StateObject private var repo = BillingRepository()

    @AppStorage("is_association_member") private var isAssociationMember: Bool = false

    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"

    private var isEnglish: Bool {
        let values = [
            kmiAppLanguageCode.lowercased(),
            appLanguageRaw.lowercased(),
            initialLanguageCode.lowercased()
        ]

        return values.contains("en") || values.contains("english")
    }

    private var screenLayoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    private var primaryTextAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var horizontalTextAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var horizontalStackAlignment: HorizontalAlignment {
        isEnglish ? .leading : .trailing
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private var monthlyProductId: BillingRepository.ProductId {
        BillingRepository.ProductId.resolveMonthlyProduct(
            isAssociationMember: isAssociationMember
        )
    }

    private var yearlyProductId: BillingRepository.ProductId {
        BillingRepository.ProductId.resolveYearlyProduct(
            isAssociationMember: isAssociationMember
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                plansHeroCard

                Text(
                    isAssociationMember
                    ? tr("זכאות זוהתה למחיר חבר עמותה", "Association member pricing detected")
                    : tr("בחר/י במסלול המתאים לך:", "Choose the plan that fits you:")
                )
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.82))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

                if !repo.state.connected || !repo.state.productsLoaded || repo.state.error != nil {
                    Text(
                        tr(
                            "סטטוס רכישה: מחובר=\(repo.state.connected), מוצרים נטענו=\(repo.state.productsLoaded)\n\(repo.state.error ?? "")",
                            "Billing status: connected=\(repo.state.connected), productsLoaded=\(repo.state.productsLoaded)\n\(repo.state.error ?? "")"
                        )
                    )
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.orange)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.orange.opacity(0.12))
                    )
                }

                PlanCard(
                    title: isAssociationMember
                    ? tr(
                        "מנוי חודשי לחבר עמותה\n(גישה מלאה לכל התכנים)",
                        "Monthly plan for association members\n(full access to all content)"
                    )
                    : tr(
                        "מנוי חודשי מתחדש\n(גישה מלאה לכל התכנים)",
                        "Recurring monthly subscription\n(full access to all content)"
                    ),
                    priceLine: priceLine(
                        for: monthlyProductId,
                        fallback: isAssociationMember
                        ? tr("₪20 / חודשי", "₪20 / month")
                        : tr("₪25 / חודשי", "₪25 / month")
                    ),
                    points: [
                        tr("גישה מלאה לכל התכנים באפליקציה", "Full access to all app content"),
                        tr("מתחדש אוטומטית מדי חודש", "Renews automatically every month"),
                        isAssociationMember
                        ? tr("כולל מחיר מוזל לחבר עמותה", "Includes discounted member pricing")
                        : tr("ניתן לבטל בכל עת בהתאם למדיניות החנות", "Can be canceled anytime under store policy")
                    ],
                    accent: Color.blue,
                    isLoading: repo.state.isLoading,
                    isProductLoaded: isProductLoaded(monthlyProductId),
                    isEnglish: isEnglish,
                    productIdLabel: tr("מזהה מוצר", "Product ID"),
                    productId: monthlyProductId.rawValue,
                    buyTitle: tr("רכישה חודשית", "Buy monthly"),
                    loadingTitle: tr("טוען...", "Loading..."),
                    unavailableTitle: tr("המוצר עדיין לא נטען", "Product not loaded yet"),
                    onBuy: {
                        Task {
                            await repo.purchase(productId: monthlyProductId.rawValue)
                        }
                    }
                )

                PlanCard(
                    title: isAssociationMember
                    ? tr(
                        "מנוי שנתי לחבר עמותה\n(גישה מלאה לכל התכנים)",
                        "Yearly plan for association members\n(full access to all content)"
                    )
                    : tr(
                        "מנוי שנתי\n(גישה מלאה לכל התכנים)",
                        "Recurring yearly subscription\n(full access to all content)"
                    ),
                    priceLine: priceLine(
                        for: yearlyProductId,
                        fallback: isAssociationMember
                        ? tr("₪200 / שנתי", "₪200 / year")
                        : tr("₪250 / שנתי", "₪250 / year")
                    ),
                    points: [
                        tr("תשלום חד־שנתי אחד", "One yearly payment"),
                        tr("ללא חידוש חודשי", "No monthly renewal"),
                        isAssociationMember
                        ? tr("כולל מחיר מוזל לחבר עמותה", "Includes discounted member pricing")
                        : tr("גישה לכל התכנים לאורך כל השנה", "Access to all content for the full year")
                    ],
                    accent: Color.orange,
                    isLoading: repo.state.isLoading,
                    isProductLoaded: isProductLoaded(yearlyProductId),
                    isEnglish: isEnglish,
                    productIdLabel: tr("מזהה מוצר", "Product ID"),
                    productId: yearlyProductId.rawValue,
                    buyTitle: tr("רכישה שנתית", "Buy yearly"),
                    loadingTitle: tr("טוען...", "Loading..."),
                    unavailableTitle: tr("המוצר עדיין לא נטען", "Product not loaded yet"),
                    onBuy: {
                        Task {
                            await repo.purchase(productId: yearlyProductId.rawValue)
                        }
                    }
                )

                if let error = repo.state.error, !error.isEmpty {
                    Text("\(tr("שגיאה", "Error")): \(error)")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }

                Button(action: onBack) {
                    Text(tr("חזרה למסך ניהול המנוי", "Back to subscription screen"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)

                Spacer(minLength: 24)
            }
            .padding(16)
        }
        .environment(\.layoutDirection, screenLayoutDirection)
        .task {
            repo.start()
        }
    }

    private var plansHeroCard: some View {
        VStack(spacing: 8) {
            Text(tr("תוכניות מנוי", "Subscription plans"))
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            Text(tr(
                "בחרו מנוי חודשי או שנתי וקבלו גישה מלאה לכל תכני האפליקציה.",
                "Choose a monthly or yearly plan and get full access to all app content."
            ))
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white.opacity(0.92))
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.49, green: 0.23, blue: 0.93),
                            Color(red: 0.43, green: 0.16, blue: 0.85),
                            Color(red: 0.35, green: 0.13, blue: 0.71)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 14, x: 0, y: 8)
    }

    private func isProductLoaded(_ id: BillingRepository.ProductId) -> Bool {
        repo.product(for: id.rawValue) != nil
    }

    private func priceLine(
        for id: BillingRepository.ProductId,
        fallback: String
    ) -> String {
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
            return period.value == 1
            ? tr("יום", "day")
            : tr("\(period.value) ימים", "\(period.value) days")

        case .week:
            return period.value == 1
            ? tr("שבוע", "week")
            : tr("\(period.value) שבועות", "\(period.value) weeks")

        case .month:
            return period.value == 1
            ? tr("חודשי", "month")
            : tr("\(period.value) חודשים", "\(period.value) months")

        case .year:
            return period.value == 1
            ? tr("שנתי", "year")
            : tr("\(period.value) שנים", "\(period.value) years")

        @unknown default:
            return tr("תקופה", "period")
        }
    }
}

private struct PlanCard: View {
    let title: String
    let priceLine: String
    let points: [String]
    let accent: Color
    let isLoading: Bool
    let isProductLoaded: Bool
    let isEnglish: Bool
    let productIdLabel: String
    let productId: String
    let buyTitle: String
    let loadingTitle: String
    let unavailableTitle: String
    let onBuy: () -> Void

    private var stackAlignment: HorizontalAlignment {
        isEnglish ? .leading : .trailing
    }

    private var buttonTitle: String {
        if isLoading {
            return loadingTitle
        }

        if !isProductLoaded {
            return unavailableTitle
        }

        return buyTitle
    }

    var body: some View {
        VStack(alignment: stackAlignment, spacing: 14) {
            Text(title)
                .font(.title3.weight(.heavy))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(priceLine)
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .center)

            Text("\(productIdLabel): \(productId)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(isEnglish ? .leading : .trailing)
                .frame(
                    maxWidth: .infinity,
                    alignment: isEnglish ? .leading : .trailing
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.13))
                )

            VStack(alignment: stackAlignment, spacing: 9) {
                ForEach(points, id: \.self) { line in
                    HStack(spacing: 8) {
                        if isEnglish {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white.opacity(0.95))

                            Text(line)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.92))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text(line)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.92))
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: .infinity, alignment: .trailing)

                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white.opacity(0.95))
                        }
                    }
                }
            }

            Button(action: onBuy) {
                HStack(spacing: 8) {
                    if isEnglish {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .bold))

                        Text(buttonTitle)
                            .font(.headline.weight(.heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    } else {
                        Text(buttonTitle)
                            .font(.headline.weight(.heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .foregroundStyle(accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.94))
                )
            }
            .buttonStyle(.plain)
            .disabled(isLoading || !isProductLoaded)
            .opacity((isLoading || !isProductLoaded) ? 0.70 : 1.0)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent,
                            accent.opacity(0.84),
                            accent.opacity(0.68)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: accent.opacity(0.20), radius: 14, x: 0, y: 8)
    }
}

#Preview {
    SubscriptionPlansScreen(
        onBack: {},
        onOpenHome: {}
    )
}
