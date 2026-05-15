import SwiftUI

struct SubscriptionScreen: View {

    let onBack: () -> Void
    let onOpenPlans: () -> Void
    let onOpenHome: () -> Void

    @StateObject private var repo = BillingRepository()

    @State private var isAdmin: Bool = KmiAccess.isAdmin()
    @State private var showDevDialog = false
    @State private var devCode = ""
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

        return timeActive && accessFlags
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
                    title: tr("רכוש / הארך מנוי", "Buy / renew subscription"),
                    onTap: onOpenPlans
                )

                Button {
                    Task {
                        await restorePurchasesFromStore()
                    }
                } label: {
                    Text(repo.state.isLoading ? tr("טוען...", "Loading...") : tr("שחזור רכישות", "Restore purchases"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .disabled(repo.state.isLoading)

                if let restoreMessage, !restoreMessage.isEmpty {
                    Text(restoreMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.green)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.green.opacity(0.10))
                        )
                }

                Button(action: {
                    showDevDialog = true
                }) {
                    Text(tr("כניסת מנהל / קוד מפתח", "Admin / tester access code"))
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                Spacer(minLength: 8)

                Button(action: onOpenHome) {
                Text(tr("חזרה למסך הבית", "Back to home"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)

                Button(action: onBack) {
                    Text(tr("סגור", "Close"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .environment(\.layoutDirection, screenLayoutDirection)
        .task {
            isAdmin = KmiAccess.isAdmin()
            KmiAccess.ensureTrialStarted()
            repo.start()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("KMI_ACCESS_CHANGED"))) { _ in
            uiRefreshTick += 1
            isAdmin = KmiAccess.isAdmin()
        }
        .alert(tr("קוד גישה", "Access code"), isPresented: $showDevDialog) {
            SecureField(tr("קוד גישה", "Access code"), text: $devCode)

            Button(tr("אישור", "Confirm")) {
                let code = devCode.trimmingCharacters(in: .whitespacesAndNewlines)

                if KmiAccess.tryDevUnlock(code: code) {
                    // גישת מפתח מלאה בלי להפוך את המשתמש למנהל.
                    isAdmin = KmiAccess.isAdmin()
                    uiRefreshTick += 1
                    repo.start()
                }

                devCode = ""
            }

            Button(tr("בטל", "Cancel"), role: .cancel) {
                devCode = ""
            }
        } message: {
            Text(tr(
                "ניתן להזין קוד גישה לבודקים כדי לפתוח את האפליקציה ללא מנוי.",
                "Enter a tester access code to unlock the app without a subscription."
            ))
        }
    }

    private func restorePurchasesFromStore() async {
        restoreMessage = nil

        await repo.restorePurchases()

        uiRefreshTick += 1
        isAdmin = KmiAccess.isAdmin()

        if let error = repo.state.error, !error.isEmpty {
            restoreMessage = nil
            return
        }

        restoreMessage = effectiveActive
        ? tr("נמצא מנוי פעיל. התכנים הנעולים פתוחים כעת.", "An active subscription was found. Locked content is now open.")
        : tr("לא נמצא מנוי פעיל לשחזור.", "No active subscription was found to restore.")
    }
    
    private var subscriptionHeroCard: some View {
        VStack(spacing: 8) {
            Text(tr("מנוי KMI", "KMI Subscription"))
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            Text(tr(
                "כאן אפשר לבדוק סטטוס מנוי, לרכוש מנוי חדש או לשחזר רכישות קיימות.",
                "Here you can check your subscription status, purchase a new subscription, or restore previous purchases."
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

    private var hasEffectiveFullAccess: Bool {
        KmiAccess.hasFullAccess()
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
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
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
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.30), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 12, x: 0, y: 7)
        }
        .buttonStyle(.plain)
    }

    private var premiumCrownBubble: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.14))

            Text("👑")
                .font(.system(size: 18))
        }
        .frame(width: 34, height: 34)
    }

    private var premiumChevronBubble: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.13))

            Image(systemName: isEnglish ? "chevron.right" : "chevron.left")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.white)
        }
        .frame(width: 34, height: 34)
    }

    private func premiumButtonTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline.weight(.heavy))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }

    private func statusAccent(active: Bool) -> Color {
        active
        ? Color(red: 0.09, green: 0.46, blue: 0.24)
        : Color(red: 0.86, green: 0.15, blue: 0.15)
    }

    private func statusCardFill(active: Bool) -> Color {
        active
        ? Color(red: 0.94, green: 0.99, blue: 0.96)
        : Color(red: 1.00, green: 0.95, blue: 0.96)
    }

    private func statusIcon(active: Bool) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: active
                        ? [
                            Color(red: 0.82, green: 0.98, blue: 0.90),
                            Color(red: 0.93, green: 0.99, blue: 0.96)
                        ]
                        : [
                            Color(red: 1.00, green: 0.88, blue: 0.88),
                            Color(red: 1.00, green: 0.95, blue: 0.96)
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 34
                    )
                )

            Text(active ? "✓" : "!")
                .font(.title2.weight(.heavy))
                .foregroundStyle(statusAccent(active: active))
        }
        .frame(width: 58, height: 58)
    }

    private func statusTitleBlock(active: Bool) -> some View {
        VStack(alignment: horizontalStackAlignment, spacing: 4) {
            Text(active ? tr("גישה מלאה פעילה", "Full access active") : tr("אין מנוי פעיל", "No active subscription"))
                .font(.title3.weight(.heavy))
                .foregroundStyle(Color.black.opacity(0.86))
                .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                .multilineTextAlignment(primaryTextAlignment)

            Text(active ? tr("כל התכנים פתוחים עבורך", "All app content is available") : tr("חלק מהתכנים דורשים מנוי", "Some content requires a subscription"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.55))
                .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                .multilineTextAlignment(primaryTextAlignment)
        }
    }

    private var statusCard: some View {
        let _ = uiRefreshTick
        let active = effectiveActive
        let productId = savedProductId
        let accessUntil = savedAccessUntil

        return VStack(alignment: horizontalStackAlignment, spacing: 14) {
            HStack(spacing: 12) {
                if isEnglish {
                    statusIcon(active: active)
                    statusTitleBlock(active: active)
                } else {
                    statusTitleBlock(active: active)
                    statusIcon(active: active)
                }
            }
            .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)

            Text(
                active
                ? tr("כל התכנים באפליקציה פתוחים עבורך כעת.", "All app content is currently unlocked for you.")
                : tr("כדי לפתוח את כל התכנים, יש לבחור מסלול מנוי פעיל.", "To unlock all content, choose an active subscription plan.")
            )
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.black.opacity(0.70))
            .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
            .multilineTextAlignment(primaryTextAlignment)

            Divider()

            VStack(alignment: horizontalStackAlignment, spacing: 10) {
                Text(tr("פרטי המנוי", "Subscription details"))
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Color.black.opacity(0.80))
                    .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                    .multilineTextAlignment(primaryTextAlignment)

                detailsRow(
                    label: tr("סטטוס", "Status"),
                    value: active ? tr("פעיל", "Active") : tr("לא פעיל", "Inactive"),
                    valueColor: active ? Color.green : Color.red
                )

                detailsRow(
                    label: tr("מסלול", "Plan"),
                    value: planDisplayName(productId),
                    valueColor: Color.black.opacity(0.82)
                )

                detailsRow(
                    label: tr("מזהה מוצר", "Product ID"),
                    value: productId ?? "-",
                    valueColor: Color.black.opacity(0.66)
                )

                detailsRow(
                    label: tr("תוקף עד", "Valid until"),
                    value: accessUntil > 0 ? formatDateMillis(accessUntil) : "-",
                    valueColor: Color.black.opacity(0.66)
                )

                if let token = repo.state.purchaseToken, !token.isEmpty {
                    detailsRow(
                        label: tr("מזהה רכישה", "Purchase ID"),
                        value: token,
                        valueColor: Color.black.opacity(0.55)
                    )
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.62))
            )

            if KmiAccess.hasDevUnlock() {
                Button(action: {
                    KmiAccess.clearDevUnlock()
                    uiRefreshTick += 1
                    repo.start()
                }) {
                    Text(tr("בטל גישת בודק", "Disable tester access"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }

            if let error = repo.state.error, !error.isEmpty {
                Text("\(tr("שגיאה", "Error")): \(error)")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                    .multilineTextAlignment(primaryTextAlignment)
            }
        }
        .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(statusCardFill(active: active))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(statusAccent(active: active).opacity(0.20), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.07), radius: 10, x: 0, y: 5)
    }

    private func detailsRow(
        label: String,
        value: String,
        valueColor: Color
    ) -> some View {
        HStack(spacing: 10) {
            if isEnglish {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.50))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(value)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(valueColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .multilineTextAlignment(.trailing)
            } else {
                Text(value)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(valueColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .multilineTextAlignment(.leading)

                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.50))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
    
    private var adminCard: some View {
        VStack(alignment: horizontalStackAlignment, spacing: 12) {
            Text(tr("מצב מנוי: מנהל מערכת", "Subscription status: administrator"))
                .font(.title3.weight(.heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                .multilineTextAlignment(primaryTextAlignment)

            Text(tr(
                "כמנהל מערכת כל התכנים באפליקציה פתוחים עבורך ואין צורך ברכישת מנוי.",
                "As an administrator, all app content is open for you and no subscription purchase is required."
            ))
            .font(.body.weight(.semibold))
            .foregroundStyle(.white.opacity(0.92))
            .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
            .multilineTextAlignment(primaryTextAlignment)

            Button(action: {
                KmiAccess.setAdmin(false)
                isAdmin = false
            }) {
                Text(tr("יציאה ממצב מנהל", "Exit administrator mode"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
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
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 12, x: 0, y: 7)
    }
}

#Preview {
    SubscriptionScreen(
        onBack: {},
        onOpenPlans: {},
        onOpenHome: {}
    )
}
