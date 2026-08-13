import SwiftUI

struct SubscriptionScreen: View {
    
    let onBack: () -> Void
    let onOpenPlans: () -> Void
    let onOpenHome: () -> Void
    
    @StateObject private var repo = BillingRepository()
    
    @Environment(\.colorScheme)
    private var colorScheme
    
    private var isDarkMode: Bool {
        colorScheme == .dark
    }
    
    private var screenGradientColors: [Color] {
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
    
    private var primaryTextColor: Color {
        isDarkMode
        ? Color.white.opacity(0.94)
        : Color.black.opacity(0.86)
    }
    
    private var secondaryTextColor: Color {
        isDarkMode
        ? Color.white.opacity(0.68)
        : Color.black.opacity(0.55)
    }
    
    private var dividerColor: Color {
        isDarkMode
        ? Color.white.opacity(0.12)
        : Color.black.opacity(0.10)
    }
    
    @State private var uiRefreshTick: Int = 0
    @State private var restoreMessage: String? = nil
    
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
    
    private var currentMillis: Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
    
    private var savedAccessUntil: Int64 {
        let value = UserDefaults.standard.object(forKey: "sub_access_until")
        
        if let int64 = value as? Int64 {
            return int64
        }
        
        if let int = value as? Int {
            return Int64(int)
        }
        
        if let double = value as? Double {
            return Int64(double)
        }
        
        return Int64(UserDefaults.standard.integer(forKey: "sub_access_until"))
    }
    
    private var savedProductId: String? {
        let fromDefaults = UserDefaults.standard.string(forKey: "sub_product")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let fromDefaults, !fromDefaults.isEmpty {
            return fromDefaults
        }
        
        return repo.state.productId
    }
    
    private var effectiveActive: Bool {
        let timeActive = savedAccessUntil > currentMillis
        
        let accessFlags =
        KmiAccess.hasFullAccess() ||
        UserDefaults.standard.bool(forKey: "subscription_active") ||
        UserDefaults.standard.bool(forKey: "is_subscribed") ||
        UserDefaults.standard.bool(forKey: "has_full_access") ||
        UserDefaults.standard.bool(forKey: "full_access")
        
        let hasStoredProduct =
        savedProductId?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false
        
        /*
         * כמו באנדרואיד:
         * תאריך הגישה חייב להיות בתוקף, ובנוסף צריך להיות
         * דגל גישה שמור או מזהה מוצר תקין.
         */
        return timeActive && (accessFlags || hasStoredProduct)
    }
    
    private func formatDateMillis(_ millis: Int64) -> String {
        guard millis > 0 else {
            return "-"
        }
        
        let date = Date(timeIntervalSince1970: Double(millis) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                subscriptionHeroCard
                statusCard
                
                premiumSubscriptionButton(
                    title: tr(
                        "רכוש / הארך מנוי",
                        "Buy / renew subscription"
                    ),
                    onTap: onOpenPlans
                )
                
                moreActionsCard
                
                if let restoreMessage,
                   !restoreMessage.isEmpty {
                    Text(restoreMessage)
                        .kmiFont(
                            size: 14,
                            weight: .semibold
                        )
                        .foregroundStyle(
                            isDarkMode
                            ? Color(red: 0.52, green: 0.93, blue: 0.68)
                            : Color(red: 0.08, green: 0.50, blue: 0.24)
                        )
                        .frame(
                            maxWidth: .infinity,
                            alignment: .center
                        )
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .background(
                            RoundedRectangle(
                                cornerRadius: 14,
                                style: .continuous
                            )
                            .fill(
                                Color.green.opacity(
                                    isDarkMode ? 0.18 : 0.10
                                )
                            )
                        )
                        .overlay(
                            RoundedRectangle(
                                cornerRadius: 14,
                                style: .continuous
                            )
                            .stroke(
                                Color.green.opacity(
                                    isDarkMode ? 0.30 : 0.16
                                ),
                                lineWidth: 1
                            )
                        )
                }
                
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(
            LinearGradient(
                colors: screenGradientColors,
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
            KmiAccess.ensureTrialStarted()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name(
                    "KMI_ACCESS_CHANGED"
                )
            )
        ) { _ in
            uiRefreshTick += 1
        }
    }
    
    private func restorePurchasesFromStore() async {
        restoreMessage = nil
        
        await repo.restorePurchases()
        
        uiRefreshTick += 1
        
        if let error = repo.state.error,
           !error.isEmpty {
            restoreMessage = nil
            return
        }
        
        restoreMessage = effectiveActive
        ? tr("נמצא מנוי פעיל. התכנים הנעולים פתוחים כעת.", "An active subscription was found. Locked content is now open.")
        : tr("לא נמצא מנוי פעיל לשחזור.", "No active subscription was found to restore.")
    }
    
    private var subscriptionHeroCard: some View {
        VStack(spacing: 6) {
            Text(
                tr(
                    "ניהול מנוי KAMI",
                    "KMI Subscription"
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
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            
            Text(
                tr(
                    "כאן אפשר לבדוק סטטוס מנוי, לרכוש מנוי חדש או לשחזר רכישות קיימות.",
                    "Here you can check your subscription status, purchase a new subscription, or restore previous purchases."
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
            .lineSpacing(3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 120)
        .background(
            RoundedRectangle(
                cornerRadius: 26,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.49, green: 0.23, blue: 0.93),
                        Color(red: 0.43, green: 0.16, blue: 0.85),
                        Color(red: 0.35, green: 0.13, blue: 0.71)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 26,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(0.22),
                lineWidth: 1
            )
        )
        .shadow(
            color: Color.black.opacity(
                isDarkMode ? 0.34 : 0.14
            ),
            radius: 16,
            x: 0,
            y: 8
        )
    }
    
    private func planDisplayName(_ productId: String?) -> String {
        switch productId {
        case BillingRepository.ProductId.regularMonthly.rawValue:
            return tr("מנוי חודשי רגיל", "Regular monthly subscription")
            
        case BillingRepository.ProductId.regularYearly.rawValue:
            return tr("מנוי שנתי רגיל", "Regular yearly subscription")
            
        case BillingRepository.ProductId.memberMonthly.rawValue:
            return tr("מנוי חודשי לחבר עמותה", "Association monthly subscription")
            
        case BillingRepository.ProductId.memberYearly.rawValue:
            return tr("מנוי שנתי לחבר עמותה", "Association yearly subscription")
            
        case .some(let raw) where !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty:
            return raw
            
        default:
            return "-"
        }
    }
    
    private var monthlyPriceLabel: String {
        let isMemberPlan =
        savedProductId == BillingRepository.ProductId.memberMonthly.rawValue ||
        savedProductId == BillingRepository.ProductId.memberYearly.rawValue
        
        let productId: BillingRepository.ProductId =
        isMemberPlan ? .memberMonthly : .regularMonthly
        
        return repo.getPriceForProduct(productId.rawValue) ??
        tr("טרם נטען", "Not loaded yet")
    }
    
    private var yearlyPriceLabel: String {
        let isMemberPlan =
        savedProductId == BillingRepository.ProductId.memberMonthly.rawValue ||
        savedProductId == BillingRepository.ProductId.memberYearly.rawValue
        
        let productId: BillingRepository.ProductId =
        isMemberPlan ? .memberYearly : .regularYearly
        
        return repo.getPriceForProduct(productId.rawValue) ??
        tr("טרם נטען", "Not loaded yet")
    }
    
    private func premiumSubscriptionButton(
        title: String,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if isEnglish {
                    premiumCrownBubble
                    premiumButtonTitle(title)
                    premiumChevronBubble
                } else {
                    premiumChevronBubble
                    premiumButtonTitle(title)
                    premiumCrownBubble
                }
            }
            .environment(
                \.layoutDirection,
                 .leftToRight
            )
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 78)
            .background(
                RoundedRectangle(
                    cornerRadius: 28,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.49, green: 0.23, blue: 0.93),
                            Color(red: 0.43, green: 0.16, blue: 0.85),
                            Color(red: 0.35, green: 0.13, blue: 0.71)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 28,
                    style: .continuous
                )
                .stroke(
                    Color.white.opacity(0.30),
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
        .buttonStyle(.plain)
        .contentShape(
            RoundedRectangle(
                cornerRadius: 28,
                style: .continuous
            )
        )
    }
    
    private var premiumCrownBubble: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.14))
            
            Text("👑")
                .kmiFont(
                    size: 20,
                    weight: .regular
                )
        }
        .frame(width: 36, height: 36)
    }
    
    private var premiumChevronBubble: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.13))
            
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
            .foregroundStyle(.white)
        }
        .frame(width: 36, height: 36)
    }
    
    private func premiumButtonTitle(
        _ title: String
    ) -> some View {
        Text(title)
            .kmiFont(
                size: 17,
                weight: .heavy
            )
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.78)
            .padding(.vertical, 10)
    }
    
    private func statusAccent(
        active: Bool
    ) -> Color {
        if isDarkMode {
            return active
            ? Color(red: 0.30, green: 0.88, blue: 0.52)
            : Color(red: 1.00, green: 0.38, blue: 0.38)
        }
        
        return active
        ? Color(red: 0.09, green: 0.46, blue: 0.24)
        : Color(red: 0.86, green: 0.15, blue: 0.15)
    }
    
    private func statusCardFill(
        active: Bool
    ) -> Color {
        if isDarkMode {
            return mainCardColor
        }
        
        return active
        ? Color(red: 0.94, green: 0.99, blue: 0.96)
        : Color(red: 1.00, green: 0.95, blue: 0.96)
    }
    
    private func statusIcon(
        active: Bool
    ) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: statusIconGradientColors(
                            active: active
                        ),
                        center: .center,
                        startRadius: 2,
                        endRadius: 34
                    )
                )
            
            Circle()
                .stroke(
                    statusAccent(active: active)
                        .opacity(isDarkMode ? 0.38 : 0.18),
                    lineWidth: 1
                )
            
            Image(
                systemName: active
                ? "checkmark"
                : "exclamationmark"
            )
            .font(
                .system(
                    size: 21,
                    weight: .heavy
                )
            )
            .foregroundStyle(
                statusAccent(active: active)
            )
        }
        .frame(width: 62, height: 62)
    }
    
    private func statusIconGradientColors(
        active: Bool
    ) -> [Color] {
        if isDarkMode {
            return active
            ? [
                Color(red: 0.10, green: 0.30, blue: 0.20),
                Color(red: 0.08, green: 0.20, blue: 0.15)
            ]
            : [
                Color(red: 0.34, green: 0.11, blue: 0.14),
                Color(red: 0.22, green: 0.08, blue: 0.11)
            ]
        }
        
        return active
        ? [
            Color(red: 0.82, green: 0.98, blue: 0.90),
            Color(red: 0.93, green: 0.99, blue: 0.96)
        ]
        : [
            Color(red: 1.00, green: 0.88, blue: 0.88),
            Color(red: 1.00, green: 0.95, blue: 0.96)
        ]
    }
    
    private func statusTitleBlock(
        active: Bool
    ) -> some View {
        VStack(
            alignment: horizontalStackAlignment,
            spacing: 6
        ) {
            Text(
                active
                ? tr(
                    "גישה מלאה פעילה",
                    "Full access active"
                )
                : tr(
                    "אין מנוי פעיל",
                    "No active subscription"
                )
            )
            .kmiFont(
                size: 20,
                weight: .heavy
            )
            .foregroundStyle(
                statusAccent(active: active)
            )
            .frame(
                maxWidth: .infinity,
                alignment: horizontalTextAlignment
            )
            .multilineTextAlignment(
                primaryTextAlignment
            )
            
            Text(
                active
                ? tr(
                    "כל התכנים פתוחים עבורך",
                    "All app content is available"
                )
                : tr(
                    "חלק מהתכנים דורשים מנוי",
                    "Some content requires a subscription"
                )
            )
            .kmiFont(
                size: 14,
                weight: .semibold
            )
            .foregroundStyle(secondaryTextColor)
            .frame(
                maxWidth: .infinity,
                alignment: horizontalTextAlignment
            )
            .multilineTextAlignment(
                primaryTextAlignment
            )
        }
    }
    
    private var statusCard: some View {
        let _ = uiRefreshTick
        let active = effectiveActive
        let productId = savedProductId
        let accessUntil = savedAccessUntil
        
        return VStack(
            alignment: horizontalStackAlignment,
            spacing: 14
        ) {
            HStack(spacing: 12) {
                if isEnglish {
                    statusIcon(active: active)
                    statusTitleBlock(active: active)
                } else {
                    statusTitleBlock(active: active)
                    statusIcon(active: active)
                }
            }
            .frame(
                maxWidth: .infinity,
                alignment: horizontalTextAlignment
            )
            
            Text(
                active
                ? tr(
                    "כל התכנים באפליקציה פתוחים עבורך כעת.",
                    "All app content is currently unlocked for you."
                )
                : tr(
                    "כדי לפתוח את כל התכנים, יש לבחור מסלול מנוי פעיל.",
                    "To unlock all content, choose an active subscription plan."
                )
            )
            .kmiFont(
                size: 16,
                weight: .semibold
            )
            .foregroundStyle(primaryTextColor.opacity(0.82))
            .frame(
                maxWidth: .infinity,
                alignment: horizontalTextAlignment
            )
            .multilineTextAlignment(primaryTextAlignment)
            
            Divider()
                .overlay(dividerColor)
            
            VStack(
                alignment: horizontalStackAlignment,
                spacing: 10
            ) {
                Text(
                    tr(
                        "פרטי המנוי",
                        "Subscription details"
                    )
                )
                .kmiFont(
                    size: 17,
                    weight: .heavy
                )
                .foregroundStyle(primaryTextColor)
                .frame(
                    maxWidth: .infinity,
                    alignment: horizontalTextAlignment
                )
                .multilineTextAlignment(
                    primaryTextAlignment
                )
                
                detailsRow(
                    label: tr(
                        "תאריך חידוש:",
                        "Renewal date:"
                    ),
                    value: accessUntil > 0
                    ? formatDateMillis(accessUntil)
                    : "-",
                    valueColor: primaryTextColor.opacity(0.82)
                )
                
                detailsRow(
                    label: tr(
                        "מסלול:",
                        "Plan:"
                    ),
                    value: planDisplayName(productId),
                    valueColor: primaryTextColor
                )
                
                detailsRow(
                    label: tr(
                        "מחיר חודשי:",
                        "Monthly price:"
                    ),
                    value: monthlyPriceLabel,
                    valueColor: primaryTextColor
                )
                
                detailsRow(
                    label: tr(
                        "מחיר שנתי:",
                        "Yearly price:"
                    ),
                    value: yearlyPriceLabel,
                    valueColor: primaryTextColor
                )
                
                detailsRow(
                    label: tr(
                        "מזהה מוצר:",
                        "Product ID:"
                    ),
                    value: productId ?? "-",
                    valueColor: primaryTextColor.opacity(0.82)
                )
            }
            .padding(12)
            .background(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .fill(innerCardColor)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .stroke(
                    isDarkMode
                    ? Color.white.opacity(0.08)
                    : Color.black.opacity(0.05),
                    lineWidth: 1
                )
            )
            
            Link(
                destination: URL(
                    string: "https://apps.apple.com/account/subscriptions"
                )!
            ) {
                HStack(spacing: 10) {
                    if isEnglish {
                        Image(systemName: "arrow.up.right.square")
                        manageSubscriptionTitle
                        Image(systemName: "chevron.right")
                    } else {
                        Image(systemName: "chevron.left")
                        manageSubscriptionTitle
                        Image(systemName: "arrow.up.right.square")
                    }
                }
                .foregroundStyle(
                    isDarkMode
                    ? Color(red: 0.68, green: 0.76, blue: 1.0)
                    : Color(red: 0.22, green: 0.31, blue: 0.72)
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(
                        cornerRadius: 16,
                        style: .continuous
                    )
                    .fill(innerCardColor)
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 16,
                        style: .continuous
                    )
                    .stroke(
                        isDarkMode
                        ? Color.white.opacity(0.10)
                        : Color.black.opacity(0.06),
                        lineWidth: 1
                    )
                )
            }
            .buttonStyle(.plain)
            
            if let error = repo.state.error,
               !error.isEmpty {
                Text(
                    "\(tr("שגיאה", "Error")): \(error)"
                )
                .kmiFont(
                    size: 13,
                    weight: .semibold
                )
                .foregroundStyle(
                    isDarkMode
                    ? Color(red: 1.0, green: 0.48, blue: 0.48)
                    : Color.red
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: horizontalTextAlignment
                )
                .multilineTextAlignment(
                    primaryTextAlignment
                )
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: horizontalTextAlignment
        )
        .padding(16)
        .background(
            RoundedRectangle(
                cornerRadius: 26,
                style: .continuous
            )
            .fill(statusCardFill(active: active))
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 26,
                style: .continuous
            )
            .stroke(
                statusAccent(active: active)
                    .opacity(isDarkMode ? 0.34 : 0.20),
                lineWidth: 1
            )
        )
        .shadow(
            color: Color.black.opacity(
                isDarkMode ? 0.30 : 0.07
            ),
            radius: 10,
            x: 0,
            y: 5
        )
    }
    
    private var manageSubscriptionTitle: some View {
        Text(
            tr(
                "ניהול המנוי ב־App Store",
                "Manage subscription in the App Store"
            )
        )
        .kmiFont(
            size: 15,
            weight: .semibold
        )
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }
    
    private func detailsRow(
        label: String,
        value: String,
        valueColor: Color
    ) -> some View {
        HStack(
            alignment: .firstTextBaseline,
            spacing: 10
        ) {
            if isEnglish {
                Text(label)
                    .kmiFont(
                        size: 14,
                        weight: .semibold
                    )
                    .foregroundStyle(secondaryTextColor)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .multilineTextAlignment(.leading)
                
                Text(value)
                    .kmiFont(
                        size: 14,
                        weight: .heavy
                    )
                    .foregroundStyle(valueColor)
                    .lineLimit(3)
                    .minimumScaleFactor(0.78)
                    .multilineTextAlignment(.trailing)
            } else {
                Text(value)
                    .kmiFont(
                        size: 14,
                        weight: .heavy
                    )
                    .foregroundStyle(valueColor)
                    .lineLimit(3)
                    .minimumScaleFactor(0.78)
                    .multilineTextAlignment(.leading)
                
                Text(label)
                    .kmiFont(
                        size: 14,
                        weight: .semibold
                    )
                    .foregroundStyle(secondaryTextColor)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .trailing
                    )
                    .multilineTextAlignment(.trailing)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var moreActionsCard: some View {
        VStack(spacing: 14) {
            Text(
                tr(
                    "פעולות נוספות",
                    "More actions"
                )
            )
            .kmiFont(
                size: 17,
                weight: .heavy
            )
            .foregroundStyle(primaryTextColor)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            
            Button {
                guard !repo.state.isLoading else {
                    return
                }
                
                Task {
                    await restorePurchasesFromStore()
                }
            } label: {
                HStack(spacing: 12) {
                    if isEnglish {
                        restoreIcon
                        restoreTitle
                        restoreChevron
                    } else {
                        restoreChevron
                        restoreTitle
                        restoreIcon
                    }
                }
                .environment(
                    \.layoutDirection,
                     .leftToRight
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: 56)
                .background(
                    RoundedRectangle(
                        cornerRadius: 16,
                        style: .continuous
                    )
                    .fill(innerCardColor)
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 16,
                        style: .continuous
                    )
                    .stroke(
                        isDarkMode
                        ? Color.white.opacity(0.10)
                        : Color.black.opacity(0.06),
                        lineWidth: 1
                    )
                )
                .shadow(
                    color: Color.black.opacity(
                        isDarkMode ? 0.22 : 0.07
                    ),
                    radius: 3,
                    x: 0,
                    y: 1
                )
            }
            .buttonStyle(.plain)
            .disabled(repo.state.isLoading)
            .opacity(repo.state.isLoading ? 0.76 : 1.0)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
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
                ? Color.white.opacity(0.08)
                : Color.black.opacity(0.04),
                lineWidth: 1
            )
        )
        .shadow(
            color: Color.black.opacity(
                isDarkMode ? 0.28 : 0.10
            ),
            radius: 10,
            x: 0,
            y: 5
        )
    }
    
    private var restoreIcon: some View {
        ZStack {
            Circle()
                .fill(
                    isDarkMode
                    ? Color(red: 0.22, green: 0.27, blue: 0.46)
                    : Color(red: 0.88, green: 0.91, blue: 1.0)
                )
            
            if repo.state.isLoading {
                ProgressView()
                    .tint(
                        isDarkMode
                        ? .white
                        : Color(red: 0.23, green: 0.29, blue: 0.62)
                    )
            } else {
                Image(systemName: "arrow.clockwise")
                    .font(
                        .system(
                            size: 16,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        isDarkMode
                        ? Color.white.opacity(0.92)
                        : Color(red: 0.23, green: 0.29, blue: 0.62)
                    )
            }
        }
        .frame(width: 36, height: 36)
    }
    
    private var restoreTitle: some View {
        Text(
            repo.state.isLoading
            ? tr(
                "משחזר רכישות...",
                "Restoring purchases..."
            )
            : tr(
                "שחזור רכישות",
                "Restore purchases"
            )
        )
        .kmiFont(
            size: 16,
            weight: .semibold
        )
        .foregroundStyle(primaryTextColor)
        .frame(
            maxWidth: .infinity,
            alignment: isEnglish
            ? .leading
            : .trailing
        )
        .multilineTextAlignment(
            isEnglish
            ? .leading
            : .trailing
        )
    }
    
    private var restoreChevron: some View {
        Image(
            systemName: isEnglish
            ? "chevron.right"
            : "chevron.left"
        )
        .font(
            .system(
                size: 14,
                weight: .bold
            )
        )
        .foregroundStyle(secondaryTextColor)
    }
}

#Preview {
    SubscriptionScreen(
        onBack: {},
        onOpenPlans: {},
        onOpenHome: {}
    )
}
