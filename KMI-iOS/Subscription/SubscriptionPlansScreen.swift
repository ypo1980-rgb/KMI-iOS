import SwiftUI
import StoreKit

struct SubscriptionPlansScreen: View {

    let onBack: () -> Void
    let onOpenHome: () -> Void
    var onOpenAssociationMembership: (() -> Void)? = nil

    @StateObject private var repo = BillingRepository()

    @Environment(\.colorScheme)
    private var colorScheme

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var screenBackgroundColors: [Color] {
        if isDarkMode {
            return [
                Color(red: 0.035, green: 0.051, blue: 0.094),
                Color(red: 0.063, green: 0.094, blue: 0.153),
                Color(red: 0.075, green: 0.145, blue: 0.220)
            ]
        }

        return [
            Color(red: 0.97, green: 0.95, blue: 1.0),
            Color(red: 0.95, green: 0.97, blue: 1.0),
            Color(red: 1.0, green: 0.98, blue: 1.0)
        ]
    }

    private var primaryTextColor: Color {
        isDarkMode
            ? Color.white.opacity(0.94)
            : Color.black.opacity(0.84)
    }

    private var secondaryTextColor: Color {
        isDarkMode
            ? Color.white.opacity(0.68)
            : Color.black.opacity(0.58)
    }

    private var mainCardColor: Color {
        isDarkMode
            ? Color(red: 0.075, green: 0.102, blue: 0.165)
            : .white
    }

    private var innerCardColor: Color {
        isDarkMode
            ? Color(red: 0.105, green: 0.137, blue: 0.210)
            : Color(red: 0.973, green: 0.980, blue: 0.988)
    }

    private var loadingCardColor: Color {
        isDarkMode
            ? Color(red: 0.24, green: 0.14, blue: 0.07)
            : Color(red: 1.0, green: 0.97, blue: 0.93)
    }

    private var loadingTextColor: Color {
        isDarkMode
            ? Color(red: 1.0, green: 0.72, blue: 0.42)
            : Color(red: 0.60, green: 0.20, blue: 0.07)
    }

    @State private var purchaseMessage: String? = nil
    @State private var didStartPurchaseFlow: Bool = false
    @State private var unavailableProductMessage: String? = nil
    @State private var accessOpenedDialogMessage: String? = nil
    @State private var showPurchaseSuccessDialog: Bool = false
    @State private var purchasedProductId: String? = nil

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
                Text(
                    isAssociationMember
                        ? tr(
                            "זוהתה זכאות למחיר חבר עמותה",
                            "Association member pricing detected"
                        )
                        : tr(
                            "בחר/י במסלול המתאים לך:",
                            "Choose the plan that fits you:"
                        )
                )
                .kmiFont(
                    size: 18,
                    weight: .semibold
                )
                .foregroundStyle(primaryTextColor)
                .multilineTextAlignment(.center)
                .frame(
                    maxWidth: .infinity,
                    alignment: .center
                )

                if !repo.state.productsLoaded ||
                   repo.state.error != nil {
                    Text(
                        repo.state.error != nil
                            ? tr(
                                "הרכישות אינן זמינות כרגע. נסה שוב מאוחר יותר.",
                                "Purchases are temporarily unavailable. Please try again later."
                            )
                            : tr(
                                "טוען מחירי מנויים מ־App Store...",
                                "Loading subscription prices from the App Store..."
                            )
                    )
                    .kmiFont(
                        size: 14,
                        weight: .semibold
                    )
                    .foregroundStyle(loadingTextColor)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(
                        RoundedRectangle(
                            cornerRadius: 16,
                            style: .continuous
                        )
                        .fill(loadingCardColor)
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: 16,
                            style: .continuous
                        )
                        .stroke(
                            loadingTextColor.opacity(
                                isDarkMode ? 0.28 : 0.14
                            ),
                            lineWidth: 1
                        )
                    )
                }

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
                        ? tr("₪20 / חודש", "₪20 / month")
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
                    buyTitle: tr("רכישה מאובטחת", "Secure purchase"),
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
                        ? tr("₪220 / שנה", "₪220 / year")
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
                    buyTitle: tr("רכישה מאובטחת", "Secure purchase"),
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

                Button(action: onBack) {
                    Text(
                        tr(
                            "חזרה למסך ניהול המנוי",
                            "Back to subscription screen"
                        )
                    )
                    .kmiFont(
                        size: 16,
                        weight: .semibold
                    )
                    .foregroundStyle(primaryTextColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(
                            cornerRadius: 24,
                            style: .continuous
                        )
                        .fill(mainCardColor)
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: 24,
                            style: .continuous
                        )
                        .stroke(
                            isDarkMode
                                ? Color.white.opacity(0.14)
                                : Color.black.opacity(0.12),
                            lineWidth: 1
                        )
                    )
                }
                .buttonStyle(.plain)

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(
            LinearGradient(
                colors: screenBackgroundColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .environment(
            \.layoutDirection,
            screenLayoutDirection
        )
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
        .sheet(isPresented: $showPurchaseSuccessDialog) {
            PurchaseSuccessView(
                isEnglish: isEnglish,
                planLabel: purchasePlanLabel,
                onContinue: {
                    showPurchaseSuccessDialog = false
                    onBack()
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
    }

    private func buyPlan(
        _ productId: BillingRepository.ProductId
    ) async {
        didStartPurchaseFlow = true
        purchaseMessage = nil
        unavailableProductMessage = nil
        accessOpenedDialogMessage = nil
        purchasedProductId = productId.rawValue

        /*
         * ייתכן שהמסך נוצר לפני סיום טעינת מוצרי StoreKit.
         * לכן, אם המוצר אינו נמצא בזמן הלחיצה,
         * מבצעים טעינה חוזרת לפני שמבטלים את הרכישה.
         */
        if repo.product(
            for: productId.rawValue
        ) == nil {
            await repo.loadProducts()
        }

        guard repo.product(
            for: productId.rawValue
        ) != nil else {
            didStartPurchaseFlow = false

            let loadedIds =
                repo.state.loadedProductIds
                    .joined(separator: ", ")

            unavailableProductMessage = tr(
                """
                המוצר \(productId.rawValue) לא הוחזר מ־App Store.
                מוצרים שנטענו: \(loadedIds.isEmpty ? "לא נטענו מוצרים" : loadedIds)
                """,
                """
                Product \(productId.rawValue) was not returned by the App Store.
                Loaded products: \(loadedIds.isEmpty ? "No products loaded" : loadedIds)
                """
            )

            return
        }

        await repo.purchase(
            productId: productId.rawValue
        )

        if repo.state.active ||
           KmiAccess.hasFullAccess() {
            purchaseMessage = tr(
                "הרכישה הושלמה בהצלחה. התכנים פתוחים כעת.",
                "The purchase was completed successfully. Content is now unlocked."
            )

            showPurchaseSuccessDialog = true

            NotificationCenter.default.post(
                name: Notification.Name(
                    "KMI_ACCESS_CHANGED"
                ),
                object: nil
            )
        } else {
            didStartPurchaseFlow = false

            if let storeError =
                repo.state.error?
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
               !storeError.isEmpty {
                unavailableProductMessage =
                    storeError
            } else {
                unavailableProductMessage = tr(
                    "הרכישה לא הושלמה או שהמנוי עדיין לא אושר ב־App Store.",
                    "The purchase was not completed or the subscription has not yet been approved by the App Store."
                )
            }
        }
    }

    private var purchasePlanLabel: String {
        guard let purchasedProductId,
              let id = BillingRepository.ProductId(rawValue: purchasedProductId) else {
            return tr("המנוי", "subscription")
        }

        if id.isYearlyProduct {
            return tr("המנוי השנתי", "yearly subscription")
        }

        return tr("המנוי החודשי", "monthly subscription")
    }

    private var tariffCard: some View {
        VStack(spacing: 12) {
            Text(
                tr(
                    "תעריפון האפליקציה",
                    "App pricing"
                )
            )
            .kmiFont(
                size: 22,
                weight: .heavy
            )
            .foregroundStyle(.white)
            .frame(
                maxWidth: .infinity,
                alignment: .center
            )
            .multilineTextAlignment(.center)

            Text(
                tr(
                    "השוואת מחירים בין משתמש רגיל לבין חבר עמותת ק.מ.י",
                    "Price comparison between regular users and K.M.I. association members"
                )
            )
            .kmiFont(
                size: 14,
                weight: .semibold
            )
            .foregroundStyle(.white.opacity(0.78))
            .frame(
                maxWidth: .infinity,
                alignment: .center
            )
            .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                tariffRow(
                    label: tr(
                        "סוג משתמש",
                        "User type"
                    ),
                    monthly: tr(
                        "חודשי",
                        "Monthly"
                    ),
                    yearly: tr(
                        "שנתי",
                        "Yearly"
                    ),
                    isHeader: true,
                    highlight: false
                )

                tariffDivider

                tariffRow(
                    label: tr(
                        "משתמש רגיל",
                        "Regular user"
                    ),
                    monthly: storePrice(
                        for: .regularMonthly,
                        fallback: "₪25"
                    ),
                    yearly: storePrice(
                        for: .regularYearly,
                        fallback: "₪250"
                    ),
                    isHeader: false,
                    highlight: false
                )

                tariffDivider

                tariffRow(
                    label: tr(
                        "חבר עמותת ק.מ.י",
                        "K.M.I. member"
                    ),
                    monthly: storePrice(
                        for: .memberMonthly,
                        fallback: "₪20"
                    ),
                    yearly: storePrice(
                        for: .memberYearly,
                        fallback: "₪220"
                    ),
                    isHeader: false,
                    highlight: true
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .stroke(
                    Color.white.opacity(0.08),
                    lineWidth: 1
                )
            )

            VStack(spacing: 4) {
                Text(
                    tr(
                        "חבר עמותת ק.מ.י חוסך ₪50 בשנה",
                        "K.M.I. members save ₪50 per year"
                    )
                )
                .kmiFont(
                    size: 16,
                    weight: .bold
                )
                .foregroundStyle(
                    Color(
                        red: 0.53,
                        green: 0.94,
                        blue: 0.67
                    )
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .center
                )
                .multilineTextAlignment(.center)

                Text(
                    tr(
                        "הנחת חבר עמותה תינתן לאחר אימות סטטוס החברות.",
                        "Member pricing will be applied after membership verification."
                    )
                )
                .kmiFont(
                    size: 14,
                    weight: .semibold
                )
                .foregroundStyle(.white.opacity(0.92))
                .frame(
                    maxWidth: .infinity,
                    alignment: .center
                )
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .fill(
                    Color(
                        red: 0.02,
                        green: 0.37,
                        blue: 0.27
                    )
                    .opacity(0.32)
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .stroke(
                    Color(
                        red: 0.53,
                        green: 0.94,
                        blue: 0.67
                    )
                    .opacity(0.18),
                    lineWidth: 1
                )
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .fill(
                Color(
                    red: 0.07,
                    green: 0.09,
                    blue: 0.15
                )
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(0.14),
                lineWidth: 1
            )
        )
        .shadow(
            color: Color.black.opacity(
                isDarkMode ? 0.34 : 0.16
            ),
            radius: 12,
            x: 0,
            y: 7
        )
    }
    
    private func tariffRow(
        label: String,
        monthly: String,
        yearly: String,
        isHeader: Bool,
        highlight: Bool
    ) -> some View {
        let textColor: Color = {
            if isHeader {
                return .white
            }

            if highlight {
                return Color(
                    red: 0.53,
                    green: 0.94,
                    blue: 0.67
                )
            }

            return Color.white.opacity(0.96)
        }()

        let fontWeight: Font.Weight =
            isHeader ? .heavy : .semibold

        return HStack(spacing: 8) {
            if isEnglish {
                tariffText(
                    label,
                    color: textColor,
                    weight: fontWeight,
                    alignment: .leading,
                    width: nil
                )

                tariffText(
                    monthly,
                    color: textColor,
                    weight: fontWeight,
                    alignment: .center,
                    width: 72
                )

                tariffText(
                    yearly,
                    color: textColor,
                    weight: fontWeight,
                    alignment: .center,
                    width: 72
                )
            } else {
                tariffText(
                    yearly,
                    color: textColor,
                    weight: fontWeight,
                    alignment: .center,
                    width: 72
                )

                tariffText(
                    monthly,
                    color: textColor,
                    weight: fontWeight,
                    alignment: .center,
                    width: 72
                )

                tariffText(
                    label,
                    color: textColor,
                    weight: fontWeight,
                    alignment: .trailing,
                    width: nil
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func tariffText(
        _ text: String,
        color: Color,
        weight: Font.Weight,
        alignment: Alignment,
        width: CGFloat?
    ) -> some View {
        Text(text)
            .kmiFont(
                size: 15,
                weight: weight
            )
            .foregroundStyle(color)
            .lineLimit(2)
            .minimumScaleFactor(0.72)
            .multilineTextAlignment(
                alignment == .leading
                    ? .leading
                    : alignment == .trailing
                        ? .trailing
                        : .center
            )
            .frame(
                minWidth: width,
                maxWidth: width == nil
                    ? .infinity
                    : width,
                alignment: alignment
            )
    }

    private var tariffDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(height: 1)
    }

    private func storePrice(
        for id: BillingRepository.ProductId,
        fallback: String
    ) -> String {
        repo.product(for: id.rawValue)?.displayPrice ?? fallback
    }
    
    private var joinAssociationCard: some View {
        Button {
            onOpenAssociationMembership?()
        } label: {
            HStack(spacing: 12) {
                if isEnglish {
                    associationIcon

                    associationTextBlock(
                        title: "Join K.M.I. association",
                        subtitle: "Association members receive discounted app subscription pricing.",
                        alignment: .leading,
                        textAlignment: .leading
                    )

                    associationChevron
                } else {
                    associationChevron

                    associationTextBlock(
                        title: "הצטרפות לעמותת ק.מ.י",
                        subtitle: "חברי עמותה מקבלים מחיר מוזל למנוי האפליקציה.",
                        alignment: .trailing,
                        textAlignment: .trailing
                    )

                    associationIcon
                }
            }
            .environment(
                \.layoutDirection,
                .leftToRight
            )
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .fill(mainCardColor)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .stroke(
                    Color.purple.opacity(
                        isDarkMode ? 0.34 : 0.16
                    ),
                    lineWidth: 1
                )
            )
            .shadow(
                color: Color.black.opacity(
                    isDarkMode ? 0.28 : 0.08
                ),
                radius: 10,
                x: 0,
                y: 5
            )
        }
        .buttonStyle(.plain)
    }

    private func associationTextBlock(
        title: String,
        subtitle: String,
        alignment: HorizontalAlignment,
        textAlignment: TextAlignment
    ) -> some View {
        VStack(
            alignment: alignment,
            spacing: 5
        ) {
            Text(title)
                .kmiFont(
                    size: 17,
                    weight: .heavy
                )
                .foregroundStyle(primaryTextColor)
                .frame(
                    maxWidth: .infinity,
                    alignment: textAlignment == .leading
                        ? .leading
                        : .trailing
                )
                .multilineTextAlignment(textAlignment)

            Text(subtitle)
                .kmiFont(
                    size: 14,
                    weight: .semibold
                )
                .foregroundStyle(secondaryTextColor)
                .frame(
                    maxWidth: .infinity,
                    alignment: textAlignment == .leading
                        ? .leading
                        : .trailing
                )
                .multilineTextAlignment(textAlignment)
        }
    }

    private var associationChevron: some View {
        Image(
            systemName: isEnglish
                ? "chevron.right"
                : "chevron.left"
        )
        .font(
            .system(
                size: 15,
                weight: .heavy
            )
        )
        .foregroundStyle(
            isDarkMode
                ? Color.purple.opacity(0.94)
                : Color.purple.opacity(0.72)
        )
        .frame(width: 24)
    }
    
    private var associationIcon: some View {
        ZStack {
            Circle()
                .fill(
                    Color.purple.opacity(
                        isDarkMode ? 0.26 : 0.12
                    )
                )

            Text("👑")
                .kmiFont(
                    size: 20,
                    weight: .regular
                )
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

private struct PurchaseSuccessView: View {
    let isEnglish: Bool
    let planLabel: String
    let onContinue: () -> Void

    @State private var pulse = false

    private var layoutDirection: LayoutDirection {
        isEnglish
            ? .leftToRight
            : .rightToLeft
    }

    private var goldColor: Color {
        Color(
            red: 1.0,
            green: 0.85,
            blue: 0.47
        )
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(
                        red: 0.02,
                        green: 0.07,
                        blue: 0.12
                    ),
                    Color(
                        red: 0.04,
                        green: 0.09,
                        blue: 0.16
                    ),
                    Color(
                        red: 0.02,
                        green: 0.04,
                        blue: 0.08
                    )
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    Spacer(minLength: 12)

                    Text("✦   ✧   ✦   ✧")
                        .kmiFont(
                            size: 18,
                            weight: .bold
                        )
                        .foregroundStyle(
                            goldColor.opacity(0.70)
                        )
                        .multilineTextAlignment(.center)

                    Text("👑")
                        .kmiFont(
                            size: 42,
                            weight: .regular
                        )
                        .frame(
                            width: 82,
                            height: 82
                        )
                        .background(
                            RadialGradient(
                                colors: [
                                    Color(
                                        red: 1.0,
                                        green: 0.95,
                                        blue: 0.72
                                    ),
                                    Color(
                                        red: 0.91,
                                        green: 0.72,
                                        blue: 0.29
                                    ),
                                    Color(
                                        red: 0.47,
                                        green: 0.31,
                                        blue: 0.05
                                    )
                                ],
                                center: .center,
                                startRadius: 2,
                                endRadius: 46
                            )
                        )
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    goldColor.opacity(0.45),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: goldColor.opacity(0.28),
                            radius: 18,
                            x: 0,
                            y: 8
                        )
                        .scaleEffect(
                            pulse ? 1.07 : 1.0
                        )

                    HStack(spacing: 10) {
                        if isEnglish {
                            purchaseApprovedTitle
                            purchaseApprovedIcon
                        } else {
                            purchaseApprovedIcon
                            purchaseApprovedTitle
                        }
                    }
                    .environment(
                        \.layoutDirection,
                        .leftToRight
                    )
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [
                                .purple,
                                .blue,
                                .cyan
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(
                                Color.white.opacity(0.24),
                                lineWidth: 1
                            )
                    )

                    Text(
                        isEnglish
                            ? "Congratulations!"
                            : "ברכות!"
                    )
                    .kmiFont(
                        size: 34,
                        weight: .heavy
                    )
                    .foregroundStyle(goldColor)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.78)

                    Text(
                        isEnglish
                            ? "Your \(planLabel) purchase was completed successfully. You can now continue to the content."
                            : "הרכישה של \(planLabel) בוצעה בהצלחה. כעת ניתן להמשיך לתוכן."
                    )
                    .kmiFont(
                        size: 19,
                        weight: .bold
                    )
                    .foregroundStyle(
                        .white.opacity(0.93)
                    )
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity)

                    Button(action: onContinue) {
                        Text(
                            isEnglish
                                ? "Continue to content"
                                : "המשך לתוכן"
                        )
                        .kmiFont(
                            size: 19,
                            weight: .heavy
                        )
                        .foregroundStyle(
                            Color(
                                red: 0.07,
                                green: 0.10,
                                blue: 0.15
                            )
                        )
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 58)
                        .padding(.horizontal, 14)
                        .background(goldColor)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 25,
                                style: .continuous
                            )
                        )
                        .overlay(
                            RoundedRectangle(
                                cornerRadius: 25,
                                style: .continuous
                            )
                            .stroke(
                                Color.white.opacity(0.24),
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .overlay(
                            goldColor.opacity(0.30)
                        )

                    Text(
                        isEnglish
                            ? "🛡️ Secure purchase • Full content access"
                            : "🛡️ רכישה מאובטחת • גישה מלאה לתכנים"
                    )
                    .kmiFont(
                        size: 15,
                        weight: .bold
                    )
                    .foregroundStyle(goldColor)
                    .multilineTextAlignment(.center)

                    Spacer(minLength: 18)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 26)
                .frame(
                    maxWidth: 620,
                    alignment: .center
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .center
                )
            }
        }
        .environment(
            \.layoutDirection,
            layoutDirection
        )
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.4)
                    .repeatForever(
                        autoreverses: true
                    )
            ) {
                pulse = true
            }
        }
    }

    private var purchaseApprovedTitle: some View {
        Text(
            isEnglish
                ? "Purchase approved"
                : "רכישה אושרה"
        )
        .kmiFont(
            size: 20,
            weight: .heavy
        )
        .lineLimit(2)
        .minimumScaleFactor(0.76)
        .multilineTextAlignment(.center)
    }

    private var purchaseApprovedIcon: some View {
        Image(
            systemName: "checkmark.circle.fill"
        )
        .font(
            .system(
                size: 21,
                weight: .heavy
            )
        )
        .accessibilityHidden(true)
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
    let buyTitle: String
    let loadingTitle: String
    let unavailableTitle: String
    let unavailableMessage: String
    let onUnavailable: (String) -> Void
    let onBuy: () -> Void

    @Environment(\.colorScheme)
    private var colorScheme

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var stackAlignment: HorizontalAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var buttonTitle: String {
        if isLoading {
            return loadingTitle
        }

        /*
         * גם כשהמוצר טרם נטען, הלחיצה תנסה לטעון
         * מחדש את קטלוג המוצרים מה־App Store.
         */
        return buyTitle
    }

    private var buttonOpacity: Double {
        isLoading ? 0.70 : 1.0
    }

    var body: some View {
        VStack(
            alignment: stackAlignment,
            spacing: 14
        ) {
            Text(title)
                .kmiFont(
                    size: 19,
                    weight: .heavy
                )
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .frame(
                    maxWidth: .infinity,
                    alignment: .center
                )
                .lineSpacing(3)

            Text(priceLine)
                .kmiFont(
                    size: 23,
                    weight: .heavy
                )
                .foregroundStyle(.white)
                .frame(
                    maxWidth: .infinity,
                    alignment: .center
                )
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.76)

            VStack(
                alignment: stackAlignment,
                spacing: 9
            ) {
                ForEach(
                    points,
                    id: \.self
                ) { line in
                    planPointRow(line)
                }
            }
            .frame(
                maxWidth: .infinity,
                alignment: frameAlignment
            )

            Button {
                guard !isLoading else {
                    return
                }

                /*
                 * מסך האב מבצע טעינה חוזרת של מוצרי StoreKit
                 * לפני ניסיון הרכישה. אין לעצור את הזרימה כאן
                 * לפי ערך isProductLoaded שנקבע בזמן יצירת הכרטיס.
                 */
                onBuy()
            } label: {
                HStack(spacing: 8) {
                    if isEnglish {
                        purchaseLockIcon
                        purchaseButtonTitle
                    } else {
                        purchaseButtonTitle
                        purchaseLockIcon
                    }
                }
                .environment(
                    \.layoutDirection,
                    .leftToRight
                )
                .foregroundStyle(accent)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                    .fill(Color.white.opacity(0.94))
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                    .stroke(
                        Color.white.opacity(0.36),
                        lineWidth: 1
                    )
                )
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .opacity(buttonOpacity)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(
                cornerRadius: 26,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [
                        accent,
                        accent.opacity(
                            isDarkMode ? 0.78 : 0.84
                        ),
                        accent.opacity(
                            isDarkMode ? 0.58 : 0.68
                        )
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 26,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(
                    isDarkMode ? 0.28 : 0.22
                ),
                lineWidth: 1
            )
        )
        .shadow(
            color: accent.opacity(
                isDarkMode ? 0.34 : 0.20
            ),
            radius: 14,
            x: 0,
            y: 8
        )
    }

    private func planPointRow(
        _ line: String
    ) -> some View {
        HStack(
            alignment: .firstTextBaseline,
            spacing: 8
        ) {
            if isEnglish {
                pointCheckIcon

                Text(line)
                    .kmiFont(
                        size: 15,
                        weight: .semibold
                    )
                    .foregroundStyle(
                        .white.opacity(0.92)
                    )
                    .multilineTextAlignment(.leading)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
            } else {
                Text(line)
                    .kmiFont(
                        size: 15,
                        weight: .semibold
                    )
                    .foregroundStyle(
                        .white.opacity(0.92)
                    )
                    .multilineTextAlignment(.trailing)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .trailing
                    )

                pointCheckIcon
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: frameAlignment
        )
    }

    private var pointCheckIcon: some View {
        Image(
            systemName: "checkmark.circle.fill"
        )
        .font(
            .system(
                size: 16,
                weight: .bold
            )
        )
        .foregroundStyle(.white.opacity(0.95))
        .accessibilityHidden(true)
    }

    private var purchaseLockIcon: some View {
        Image(systemName: "lock.fill")
            .font(
                .system(
                    size: 14,
                    weight: .bold
                )
            )
            .accessibilityHidden(true)
    }

    private var purchaseButtonTitle: some View {
        Text(buttonTitle)
            .kmiFont(
                size: 16,
                weight: .heavy
            )
            .lineLimit(2)
            .minimumScaleFactor(0.76)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

#Preview {
    SubscriptionPlansScreen(
        onBack: {},
        onOpenHome: {},
        onOpenAssociationMembership: {}
    )
}
