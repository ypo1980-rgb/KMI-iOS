import SwiftUI
import StoreKit

struct SubscriptionPlansScreen: View {

    let onBack: () -> Void
    let onOpenHome: () -> Void
    var onOpenAssociationMembership: (() -> Void)? = nil

    @StateObject private var repo = BillingRepository()

    @State private var purchaseMessage: String? = nil
    @State private var didStartPurchaseFlow: Bool = false
    @State private var unavailableProductMessage: String? = nil
    @State private var accessOpenedDialogMessage: String? = nil

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

                Text(
                    tr(
                        "מצב בדיקות זמני: עד חיבור Apple StoreKit, רכישה חודשית תפתח את האפליקציה ל־30 דקות ורכישה שנתית תפתח את האפליקציה לשעה.",
                        "Temporary testing mode: until Apple StoreKit is connected, monthly access opens the app for 30 minutes and yearly access opens it for 1 hour."
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

                tariffCard

                if !isAssociationMember {
                    joinAssociationCard
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
                    isLoading: false,
                    isProductLoaded: true,
                    isEnglish: isEnglish,
                    productIdLabel: tr("מזהה מוצר", "Product ID"),
                    productId: monthlyProductId.rawValue,
                    buyTitle: tr("פתיחה ל־30 דקות", "Open for 30 minutes"),
                    loadingTitle: tr("טוען...", "Loading..."),
                    unavailableTitle: tr("המוצר עדיין לא נטען", "Product not loaded yet"),
                    unavailableMessage: tr(
                        "המנוי החודשי עדיין לא זמין לבודק הזה. ודא שהמוצר מוגדר ב-App Store Connect או בקובץ StoreKit Configuration.",
                        "The monthly subscription is not available for this tester yet. Make sure the product is configured in App Store Connect or in the StoreKit Configuration file."
                    ),
                    onUnavailable: { message in
                        unavailableProductMessage = message
                    },
                    onBuy: {
                        Task {
                            await buyPlan(monthlyProductId)
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
                    isLoading: false,
                    isProductLoaded: true,
                    isEnglish: isEnglish,
                    productIdLabel: tr("מזהה מוצר", "Product ID"),
                    productId: yearlyProductId.rawValue,
                    buyTitle: tr("פתיחה לשעה", "Open for 1 hour"),
                    loadingTitle: tr("טוען...", "Loading..."),
                    unavailableTitle: tr("המוצר עדיין לא נטען", "Product not loaded yet"),
                    unavailableMessage: tr(
                        "המנוי השנתי עדיין לא זמין לבודק הזה. ודא שהמוצר מוגדר ב-App Store Connect או בקובץ StoreKit Configuration.",
                        "The yearly subscription is not available for this tester yet. Make sure the product is configured in App Store Connect or in the StoreKit Configuration file."
                    ),
                    onUnavailable: { message in
                        unavailableProductMessage = message
                    },
                    onBuy: {
                        Task {
                            await buyPlan(yearlyProductId)
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

                if let purchaseMessage, !purchaseMessage.isEmpty {
                    Text(purchaseMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.green)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.green.opacity(0.12))
                        )
                }

                Button {
                    Task {
                        await restorePurchases()
                    }
                } label: {
                    Text(tr("שחזור רכישות", "Restore purchases"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(repo.state.isLoading)

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
        .navigationTitle(tr("תוכניות מנוי", "Subscription Plans"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            repo.start()
        }
        .alert(
            tr("המוצר לא זמין", "Product unavailable"),
            isPresented: Binding(
                get: { unavailableProductMessage != nil },
                set: { if !$0 { unavailableProductMessage = nil } }
            )
        ) {
            Button(tr("אישור", "Confirm")) {
                unavailableProductMessage = nil
            }
        } message: {
            Text(unavailableProductMessage ?? "")
        }
        .alert(
            tr("התוכן נפתח", "Content unlocked"),
            isPresented: Binding(
                get: { accessOpenedDialogMessage != nil },
                set: { if !$0 { accessOpenedDialogMessage = nil } }
            )
        ) {
            Button(tr("הבנתי", "Got it")) {
                accessOpenedDialogMessage = nil
            }
        } message: {
            Text(accessOpenedDialogMessage ?? "")
        }
    }

    private func buyPlan(_ productId: BillingRepository.ProductId) async {
        didStartPurchaseFlow = true
        purchaseMessage = nil
        unavailableProductMessage = nil
        accessOpenedDialogMessage = nil

        let durationMinutes = productId.isYearlyProduct ? 60 : 30

        KmiAccess.grantTemporarySubscription(
            productId: productId.rawValue,
            durationMinutes: durationMinutes
        )

        let openedMessage = productId.isYearlyProduct
        ? tr(
            "גישה מלאה נפתחה לשעה לצורך בדיקות. לאחר שעה המנעולים יחזרו אוטומטית.",
            "Full access is open for 1 hour for testing. After 1 hour, the locks will return automatically."
        )
        : tr(
            "גישה מלאה נפתחה ל־30 דקות לצורך בדיקות. לאחר 30 דקות המנעולים יחזרו אוטומטית.",
            "Full access is open for 30 minutes for testing. After 30 minutes, the locks will return automatically."
        )

        purchaseMessage = openedMessage
        accessOpenedDialogMessage = openedMessage
    }

    private func restorePurchases() async {
        didStartPurchaseFlow = false
        purchaseMessage = nil

        await repo.restorePurchases()

        if let error = repo.state.error, !error.isEmpty {
            purchaseMessage = nil
            return
        }

        let active =
            UserDefaults.standard.bool(forKey: "has_full_access") ||
            UserDefaults.standard.bool(forKey: "full_access") ||
            UserDefaults.standard.bool(forKey: "subscription_active") ||
            UserDefaults.standard.bool(forKey: "is_subscribed")

        purchaseMessage = active
        ? tr(
            "נמצא מנוי פעיל. התכנים הנעולים פתוחים כעת.",
            "An active subscription was found. Locked content is now open."
        )
        : tr(
            "לא נמצא מנוי פעיל לשחזור.",
            "No active subscription was found to restore."
        )
    }
    
    private var tariffCard: some View {
        VStack(spacing: 12) {
            Text(tr("תעריפון האפליקציה", "App pricing"))
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            Text(
                tr(
                    "השוואת מחירים בין משתמש רגיל לבין חבר עמותת ק.מ.י",
                    "Price comparison between regular users and K.M.I. association members"
                )
            )
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white.opacity(0.78))
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                tariffRow(
                    label: tr("סוג משתמש", "User type"),
                    monthly: tr("חודשי", "Monthly"),
                    yearly: tr("שנתי", "Yearly"),
                    isHeader: true,
                    highlight: false
                )

                tariffDivider

                tariffRow(
                    label: tr("משתמש רגיל", "Regular user"),
                    monthly: "₪25",
                    yearly: "₪250",
                    isHeader: false,
                    highlight: false
                )

                tariffDivider

                tariffRow(
                    label: tr("חבר עמותת ק.מ.י", "K.M.I. member"),
                    monthly: "₪20",
                    yearly: "₪200",
                    isHeader: false,
                    highlight: true
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )

            VStack(spacing: 4) {
                Text(tr("חבר עמותת ק.מ.י חוסך ₪50 בשנה", "K.M.I. members save ₪50 per year"))
                    .font(.body.weight(.bold))
                    .foregroundStyle(Color(red: 0.53, green: 0.94, blue: 0.67))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)

                Text(
                    tr(
                        "הנחת חבר עמותה תינתן לאחר אימות סטטוס החברות.",
                        "Member pricing will be applied after membership verification."
                    )
                )
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.02, green: 0.37, blue: 0.27).opacity(0.32))
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.07, green: 0.09, blue: 0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 12, x: 0, y: 7)
    }

    private func tariffRow(
        label: String,
        monthly: String,
        yearly: String,
        isHeader: Bool,
        highlight: Bool
    ) -> some View {
        let textColor: Color = {
            if isHeader { return .white }
            if highlight { return Color(red: 0.53, green: 0.94, blue: 0.67) }
            return Color.white.opacity(0.96)
        }()

        let fontWeight: Font.Weight = isHeader ? .heavy : .semibold

        return HStack(spacing: 10) {
            if isEnglish {
                Text(label)
                    .font(.body.weight(fontWeight))
                    .foregroundStyle(textColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(monthly)
                    .font(.body.weight(fontWeight))
                    .foregroundStyle(textColor)
                    .frame(width: 72, alignment: .center)

                Text(yearly)
                    .font(.body.weight(fontWeight))
                    .foregroundStyle(textColor)
                    .frame(width: 72, alignment: .center)
            } else {
                Text(yearly)
                    .font(.body.weight(fontWeight))
                    .foregroundStyle(textColor)
                    .frame(width: 72, alignment: .center)

                Text(monthly)
                    .font(.body.weight(fontWeight))
                    .foregroundStyle(textColor)
                    .frame(width: 72, alignment: .center)

                Text(label)
                    .font(.body.weight(fontWeight))
                    .foregroundStyle(textColor)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var tariffDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(height: 1)
    }
    
    private var joinAssociationCard: some View {
        Button {
            onOpenAssociationMembership?()
        } label: {
            HStack(spacing: 12) {
                if isEnglish {
                    associationIcon

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Join K.M.I. association")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(Color.black.opacity(0.86))

                        Text("Association members receive discounted app subscription pricing.")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.black.opacity(0.58))
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Color.purple.opacity(0.72))
                } else {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Color.purple.opacity(0.72))

                    Spacer()

                    VStack(alignment: .trailing, spacing: 5) {
                        Text("הצטרפות לעמותת ק.מ.י")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(Color.black.opacity(0.86))

                        Text("חברי עמותה מקבלים מחיר מוזל למנוי האפליקציה.")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.black.opacity(0.58))
                            .multilineTextAlignment(.trailing)
                    }

                    associationIcon
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.purple.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }

    private var associationIcon: some View {
        ZStack {
            Circle()
                .fill(Color.purple.opacity(0.12))

            Text("👑")
                .font(.system(size: 20))
        }
        .frame(width: 44, height: 44)
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
    let unavailableMessage: String
    let onUnavailable: (String) -> Void
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

    private var buttonOpacity: Double {
        isLoading ? 0.70 : 1.0
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

            Button {
                if !isProductLoaded {
                    onUnavailable(unavailableMessage)
                    return
                }

                onBuy()
            } label: {
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
            .disabled(isLoading)
            .opacity(buttonOpacity)
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
        onOpenHome: {},
        onOpenAssociationMembership: {}
    )
}
